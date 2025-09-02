#!/bin/bash

# Source config script
source config/arguments
source config/folders
source config/programs

# Step 1: Rename and count file
# -- Copy raw data files from sourcedir to rawdir.
# CORE PARAMETERS: sourcedir, rawdir
# INPUT: 
# WORK: rawdir
# OUTPUT: null
# PROCESS - File transfer
sbatch -d singleton --error="${log}/1-rename_count_%J.err" --output="${log}/1-rename_count_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/1-rename.sh"

# Get number of samples
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
sbatch -d singleton --error="${log}/2A-rawqc_%J.err" --output="${log}/2A-rawqc_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2A-fastqc_array.sh"

sbatch -d singleton --error="${log}/2B-fastp_%J.err" --output="${log}/2B-fastp_%J.out" --"array=1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2B-fastp_array.sh"

sbatch -d singleton --error="${log}/2C-trimqc_%J.err" --output="${log}/2C-trimqc_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2C-fastqc-trim.sh"

# Step 3: kraken
# Map reads to database.
# CORE PARAMETERS: modules, scripts rawdir, trimdir, log
# INPUT: rawdir, trimdir
# WORK: krackendir
# OUTPUT: null
# PROCESS - map raw reads against database for biodiversoty classification
# export 
sbatch -d singleton --error="${log}/3A-krakendb_%J.err" --output="${log}/3A-krakendb_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/3A-krakendownload.sh"

sbatch -d singleton --error="${log}/3B-kraken_%J.err" --output="${log}/3B-kraken_%J.out" --array="1-${sample_number}%2" --job-name=${NAME} --partition=${PART} "${moduledir}/3B-kraken_array.sh"

sbatch -d singleton --error="${log}/3C-kraken_merge_%J.err" --output="${log}/3D-kraken_merge_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/3C-kraken_merge.sh"

# Step 4: Bracken
# Normalise kraken read counts
# CORE PARAMETERS: modules, rawdir, trimdir, log
# INPUT: kraken output, krakendb, read length, taxonomy level
# WORK: brackendir
# OUTPUT: null
# PROCESS - Normalise kraken read counts
# export
sbatch -d singleton --error="${log}/4A-bracken_%J.err" --output="${log}/4A-bracken_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/4A-bracken_array.sh"

sbatch -d singleton --error="${log}/4B-bracken_merge_%J.err" --output="${log}/4B-bracken_merge_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/4B-bracken_merge.sh"

# Step 5: MetaPhlAn
# Map reads to database.
# CORE PARAMETERS: modules, scripts rawdir, trimdir, log
# INPUT: rawdir, trimdir
# WORK: metaphlandir, metaphladbdir
# OUTPUT: null
# PROCESS - map raw reads against database for biodiversoty classification
# export
sbatch -d singleton --error="${log}/5A-metaphlandb_%J.err" --output="${log}/5A-metaphlandb_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/5A-metaphlandb_download.sh"

sbatch -d singleton --error="${log}/5B-metaphlan_%J.err" --output="${log}/5B-metaphlan_%J.out" --array="1-${sample_number}%8" --job-name=${NAME} --partition=${PART} "${moduledir}/5B-metaphlan_array.sh"

sbatch -d singleton --error="${log}/5C-metaphlan_post_%J.err" --output="${log}/5C-metaphlan_post_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/5C-metaphan_post.sh"

# Step 6: krona plots creation
# Normalise kraken read counts
# CORE PARAMETERS: modules, scripts, rawdir, trimdir, log
# INPUT: kraken output,
# WORK: kronadir
# OUTPUT: html
# PROCESS - Intercation krona diversity plaot
# export
sbatch -d singleton --error="${log}/6A-krona_%J.err" --output="${log}/6A-krona_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/6A-krona_array_kraken.sh"

sbatch -d singleton --error="${log}/6B-krona_output_%J.err" --output="${log}/6B-krona_output_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/6B-krona_kraken_output.sh"

sbatch -d singleton --error="${log}/6C-krona_metaphlan%J.err" --output="${log}/6C-krona_metaphlan%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/6C-krona_array_metaphlan.sh"

sbatch -d singleton --error="${log}/6D-krona_metaphylan_output_%J.err" --output="${log}/6D-krona_metaphylan_output_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/6D-krona_metaphlan_output.sh"

# Step X: MultiQC report
# -- Generate a MultiQC report to summarize the results of all previous steps.
# CORE PARAMETERS: modules, workdir, multiqc
# INPUT: workdir
# WORK: multiqc
# OUTPUT: multiqc
# PROCESS - multiqc
sbatch -d singleton --error="${log}/multiqc_%J.err" --output="${log}/multiqc_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/X-multiqc.sh"

