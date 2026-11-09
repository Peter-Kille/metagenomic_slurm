#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=4      #   
#SBATCH --mem-per-cpu=2000     # in megabytes, unless unit explicitly stated

echo "Some Usable Environment Variables:"
echo "================================="
echo "hostname=$(hostname)"
echo "\$SLURM_JOB_ID=${SLURM_JOB_ID}"
echo "\$SLURM_NTASKS=${SLURM_NTASKS}"
echo "\$SLURM_NTASKS_PER_NODE=${SLURM_NTASKS_PER_NODE}"
echo "\$SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK}"
echo "\$SLURM_JOB_CPUS_PER_NODE=${SLURM_JOB_CPUS_PER_NODE}"
echo "\$SLURM_MEM_PER_CPU=${SLURM_MEM_PER_CPU}"

# Write jobscript to output file (good for reproducibility)
cat $0

# Is this database already in the shared resources folder?  (<resources_dir>/kraken/<version name>/)
shared_db="${resources_dir}/kraken/${krakendb}"

if [[ -s "${shared_db}/hash.k2d" && -s "${shared_db}/opts.k2d" && -s "${shared_db}/taxo.k2d" ]]; then
    # YES: link each file/folder into the work db folder instead of copying ~100 GB
    echo "Found ${krakendb} in ${shared_db} - linking, not downloading"
    for item in "${shared_db}"/*; do
        ln -sfn "${item}" "${krakendbdir}/$(basename "${item}")"
    done
    if [[ ! -e "${shared_db}/database150mers.kmer_distrib" ]]; then
        echo "WARNING: no database150mers.kmer_distrib in ${shared_db} - bracken (4A) will fail for 150 bp reads" >&2
    fi
else
    # NO: download from the Langmead indexes as before
    echo "${krakendb} not found in ${shared_db} - downloading"
    wget -P ${krakendbdir}/ https://genome-idx.s3.amazonaws.com/kraken/${krakendb}.tar.gz
    tar -xvzf ${krakendbdir}/${krakendb}.tar.gz -C ${krakendbdir}/
    rm ${krakendbdir}/${krakendb}.tar.gz
fi
