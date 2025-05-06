#!/bin/bash

# Source config script
source arguments_param
source config.parameters

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

# Step 2: FastQC on raw data
# -- Run FastQC on raw data to assess data quality before trimming.
# CORE PARAMETERS: modules, rawdir, qcdir, log
# INPUT: rawdir
# WORK: qcdir
# OUTPUT: null
# PROCESS - FastQC raw data
# qcfiles=${rawdir}
# export qcfilesi
sbatch -d singleton --error="${log}/2-rawqc_%J.err" --output="${log}/2-rawqc_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/2-fastqc_array.sh"

# Step 3: Fastp trimming
# -- Trim adapters and low-quality bases from raw data using Fastp.
# CORE PARAMETERS: modules, rawdir, trimdir, qcdir, log
# INPUT: rawdir
# WORK: trimdir, qcdir
# OUTPUT: null
# PROCESS - trim
sbatch -d singleton --error="${log}/3-fastp_%J.err" --output="${log}/3-fastp_%J.out" --"array=1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/3-fastp_array.sh"  

# Step 4: FastQC on trimmed data
# -- Run FastQC on raw data to assess data quality before trimming.
# CORE PARAMETERS: modules, rawdir, qcdir, log
# INPUT: rawdir
# WORK: qcdir
# OUTPUT: null
# PROCESS - FastQC raw data
# qcfiles=${rawdir}
# export qcfilesi
sbatch -d singleton --error="${log}/4-trimqc_%J.err" --output="${log}/4-trimqc_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/4-fastqc-trim.sh"

# Step 5: kraken
# Map reads to database.
# CORE PARAMETERS: modules, scripts rawdir, trimdir, log
# INPUT: rawdir, trimdir
# WORK: krackendir
# OUTPUT: null
# PROCESS - map raw reads against database for biodiversoty classification
# export 
sbatch -d singleton --error="${log}/5A-krakendb_%J.err" --output="${log}/5A-krakendb_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/5A-krakendownload.sh"

sbatch -d singleton --error="${log}/5B-kraken_%J.err" --output="${log}/5B-kraken_%J.out" --array="1-${sample_number}%2" --job-name=${NAME} --partition=${PART} "${moduledir}/5B-kraken_array.sh"

sbatch -d singleton --error="${log}/5C-kraken_merge_%J.err" --output="${log}/5D-kraken_merge_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/5C-kraken_merge.sh"

# Step 6: Bracken
# Normalise kraken read counts
# CORE PARAMETERS: modules, rawdir, trimdir, log
# INPUT: kraken output, krakendb, read length, taxonomy level
# WORK: brackendir
# OUTPUT: null
# PROCESS - Normalise kraken read counts
# export
sbatch -d singleton --error="${log}/6A-bracken_%J.err" --output="${log}/6A-bracken_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/6A-bracken_array.sh"

sbatch -d singleton --error="${log}/6B-bracken_merge_%J.err" --output="${log}/6B-bracken_merge_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/6B-bracken_merge.sh"

# Step 7: krona plots creation
# Normalise kraken read counts
# CORE PARAMETERS: modules, scripts, rawdir, trimdir, log
# INPUT: kraken output,
# WORK: kronadir
# OUTPUT: html
# PROCESS - Intercation krona diversity plaot
# export
sbatch -d singleton --error="${log}/7A-krona_%J.err" --output="${log}/7A-krona_%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/7A-krona_array_kraken.sh"

sbatch -d singleton --error="${log}/7B-krona_output_%J.err" --output="${log}/7B-krona_output_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/7B-krona_output.sh"

# Step 8: MetaPhlAn
# Map reads to database.
# CORE PARAMETERS: modules, scripts rawdir, trimdir, log
# INPUT: rawdir, trimdir
# WORK: metaphlandir, metaphladbdir
# OUTPUT: null
# PROCESS - map raw reads against database for biodiversoty classification
# export
sbatch -d singleton --error="${log}/8A-metaphlandb_%J.err" --output="${log}/8A-metaphlandb_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/8A-metaphlandb_download.sh"

sbatch -d singleton --error="${log}/8B-metaphlan_%J.err" --output="${log}/8B-metaphlan_%J.out" --array="1-${sample_number}%8" --job-name=${NAME} --partition=${PART} "${moduledir}/8B-metaphlan_array.sh"

sbatch -d singleton --error="${log}/8C-metaphlan_post_%J.err" --output="${log}/8C-metaphlan_post_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/8C-metaphan_post.sh"

# Step 9: krona plots creation
# Normalise kraken read counts
# CORE PARAMETERS: modules, scripts, rawdir, trimdir, log
# INPUT: kraken output,
# WORK: kronadir
# OUTPUT: html
# PROCESS - Intercation krona diversity plaot
# export
sbatch -d singleton --error="${log}/9A-krona_metaphlan%J.err" --output="${log}/9A-krona_metaphlan%J.out" --array="1-${sample_number}%20" --job-name=${NAME} --partition=${PART} "${moduledir}/9A-krona_array_metaphlan.sh"

sbatch -d singleton --error="${log}/9B-krona_output_%J.err" --output="${log}/9B-krona_output_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/9B-krona_output.sh"

# Step X: MultiQC report
# -- Generate a MultiQC report to summarize the results of all previous steps.
# CORE PARAMETERS: modules, workdir, multiqc
# INPUT: workdir
# WORK: multiqc
# OUTPUT: multiqc
# PROCESS - multiqc
sbatch -d singleton --error="${log}/multiqc_%J.err" --output="${log}/multiqc_%J.out" --job-name=${NAME} --partition=${PART} "${moduledir}/X-multiqc.sh"

