#!/bin/bash
# Pipeline launcher / driver.
#  - Run normally, it validates the configuration and then re-submits ITSELF as one small Slurm "driver" job,
#    so nothing has to stay alive on the head node.
#  - The driver submits ONE stage at a time with `sbatch --wait` and only moves on if that stage succeeded,
#    so the queue holds one stage (plus the driver) rather than the whole pipeline.
#  - Finished stages leave a marker in ${workdir}/.done_<stage>; a rerun skips them
#    (delete the markers - or use a new -w / -n - to force a stage to rerun).
#  - Use -F/--foreground to run the driver in the current shell (e.g. inside tmux/screen) instead.

# Source config script (this also validates the arguments and checks the modules on the login node)
source config/arguments
source config/folders
source config/programs

# ---- hand over to a driver job ----
if [[ -z "${PIPELINE_DRIVER}" && "${foreground}" != "yes" ]]; then
    driver_id=$(sbatch --parsable \
        --job-name="${NAME}_driver" --partition=${driver_part} \
        --time="${driver_time}" --nodes=1 --ntasks=1 --cpus-per-task=1 --mem=1G \
        --output="${log}/0_driver_%J.out" --error="${log}/0_driver_%J.err" \
        --export=ALL,PIPELINE_DRIVER=1 \
        --wrap "cd '$(pwd -P)' && bash ${CMDLINE}")
    echo "Driver job submitted: ${driver_id} (partition ${driver_part}, walltime ${driver_time})"
    echo "  progress: tail -f ${log}/0_driver_${driver_id}.out"
    echo "  cancel:   scancel ${driver_id}   (then scancel any running stage: squeue -u \$USER -n ${NAME})"
    exit 0
fi

# ---- driver: below here runs inside the driver job (or the foreground shell) ----
# the child sbatch calls must not inherit the driver's own memory request (conflicts with --mem-per-cpu in the modules)
unset SLURM_MEM_PER_NODE SLURM_MEM_PER_CPU SLURM_MEM_PER_GPU

# run <sbatch args...> <module script>: submit one stage, wait for it, stop the pipeline if it failed
run() {
    local script="${@: -1}"
    local step
    step=$(basename "${script}" .sh)
    if [[ -e "${workdir}/.done_${step}" ]]; then
        echo "$(date '+%F %T') SKIP   ${step} (done marker found)"
        return 0
    fi
    echo "$(date '+%F %T') SUBMIT ${step}"
    if sbatch --wait "$@"; then
        touch "${workdir}/.done_${step}"
        echo "$(date '+%F %T') DONE   ${step}"
    else
        echo "$(date '+%F %T') FAILED ${step} - stopping the pipeline (see ${log}/)" >&2
        exit 1
    fi
}
# Step 1: Rename and count file
# -- Copy raw data files from sourcedir to rawdir.
# CORE PARAMETERS: sourcedir, rawdir
# INPUT: 
# WORK: rawdir
# OUTPUT: null
# PROCESS - File transfer
run --error="${log}/1-rename_count_%J.err" --output="${log}/1-rename_count_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/1-rename.sh"

# Get number of samples (step 1 has finished by now, because run() waits)
sample_number=$(find "${rawdir}" -maxdepth 1 -name "*_1.fastq.gz" | wc -l)

# Check for zero files
if [[ "$sample_number" -eq 0 ]]; then
    echo "Error: No *_1.fastq.gz files found in ${rawdir}"
    exit 1
fi

# Step 2: QC data
# Purpose: Run fastqc on raw, fastp to trim, fastqc on trim.
# Modules: rawdir, qcdir, log
# INPUT: rawdir
# WORK: qcdir
# OUTPUT: null
# PROCESS - FastQC raw data
# qcfiles=${rawdir}
# export qcfilesi
# Step 2 + database downloads: run CONCURRENTLY, then wait for ALL of them.
# QC/trimming (2A->2B->2C), the kraken database (3A) and the metaphlan database (5A) run side by side;
# the kraken (3B) and metaphlan (5B/5C) searches below only start if every one of them succeeded.
# (each branch is a background subshell: a failing stage ends its own branch with a non-zero status)
prep_pids=()
(
run --error="${log}/2A-rawqc_%J.err" --output="${log}/2A-rawqc_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2A-fastqc_array.sh"
run --error="${log}/2B-fastp_%J.err" --output="${log}/2B-fastp_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2B-fastp_array.sh"
run --error="${log}/2C-trimqc_%J.err" --output="${log}/2C-trimqc_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2C-fastqc-trim.sh"
) &
prep_pids+=($!)

run --error="${log}/3A-krakendb_%J.err" --output="${log}/3A-krakendb_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/3A-krakendownload.sh" &
prep_pids+=($!)

run --error="${log}/5A-metaphlandb_%J.err" --output="${log}/5A-metaphlandb_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/5A-metaphlandb_download.sh" &
prep_pids+=($!)

prep_failed=0
for pid in "${prep_pids[@]}"; do
    wait "$pid" || prep_failed=1
done
if [[ "$prep_failed" -ne 0 ]]; then
    echo "$(date '+%F %T') QC / database stage failed - NOT starting kraken or metaphlan (stages that did finish keep their done markers)" >&2
    exit 1
fi
# Step 3: kraken
# Map reads to database.
# CORE PARAMETERS: modules, scripts rawdir, trimdir, log
# INPUT: rawdir, trimdir
# WORK: krackendir
# OUTPUT: null
# PROCESS - map raw reads against database for biodiversoty classification
# export 
run --error="${log}/3B-kraken_%J.err" --output="${log}/3B-kraken_%J.out" --array="1-${sample_number}%4" --job-name=${NAME} --partition=${PART} "${moduledir}/3B-kraken_array.sh"

run --error="${log}/3C-kraken_merge_%J.err" --output="${log}/3C-kraken_merge_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/3C-kraken_merge.sh"

# Step 3D: stringency summary across confidence levels (see README: choosing a stringency)
run --error="${log}/3D-kraken_stringency_%J.err" --output="${log}/3D-kraken_stringency_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/3D-kraken_stringency_summary.sh"

# Step 4: Bracken
# Normalise kraken read counts
# CORE PARAMETERS: modules, rawdir, trimdir, log
# INPUT: kraken output, krakendb, read length, taxonomy level
# WORK: brackendir
# OUTPUT: null
# PROCESS - Normalise kraken read counts
# export
run --error="${log}/4A-bracken_%J.err" --output="${log}/4A-bracken_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/4A-bracken_array.sh"

run --error="${log}/4B-bracken_merge_%J.err" --output="${log}/4B-bracken_merge_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/4B-bracken_merge.sh"

# Step 5: MetaPhlAn (database already installed by 5A in the concurrent block above)
# Map reads to database.
# CORE PARAMETERS: modules, scripts rawdir, trimdir, log
# INPUT: rawdir, trimdir
# WORK: metaphlandir, metaphladbdir
# OUTPUT: null
# PROCESS - map raw reads against database for biodiversoty classification
# export
run --error="${log}/5B-metaphlan_%J.err" --output="${log}/5B-metaphlan_%J.out" --array="1-${sample_number}%8" --job-name=${NAME} --partition=${PART} "${moduledir}/5B-metaphlan_array.sh"

run --error="${log}/5C-metaphlan_viral_%J.err" --output="${log}/5C-metaphlan_viral_%J.out" --array="1-${sample_number}%8" --job-name=${NAME} --partition=${PART} "${moduledir}/5C-metaphlan_viral_array.sh"

run --error="${log}/5D-metaphlan_post_%J.err" --output="${log}/5D-metaphlan_post_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/5D-metaphlan_post.sh"

# Step 6: krona plots creation
# Normalise kraken read counts
# CORE PARAMETERS: modules, scripts, rawdir, trimdir, log
# INPUT: kraken output,
# WORK: kronadir
# OUTPUT: html
# PROCESS - Intercation krona diversity plaot
# export
run --error="${log}/6A-krona_%J.err" --output="${log}/6A-krona_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/6A-krona_array_kraken.sh"

run --error="${log}/6B-krona_output_%J.err" --output="${log}/6B-krona_output_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/6B-krona_kraken_output.sh"

run --error="${log}/6C-krona_metaphlan%J.err" --output="${log}/6C-krona_metaphlan%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/6C-krona_array_metaphlan.sh"

run --error="${log}/6D-krona_metaphylan_output_%J.err" --output="${log}/6D-krona_metaphylan_output_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/6D-krona_metaphlan_output.sh"

# Step X: MultiQC report
# -- Generate a MultiQC report to summarize the results of all previous steps.
# CORE PARAMETERS: modules, workdir, multiqc
# INPUT: workdir
# WORK: multiqc
# OUTPUT: multiqc
# PROCESS - multiqc
run --error="${log}/multiqc_%J.err" --output="${log}/multiqc_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/X-multiqc.sh"

