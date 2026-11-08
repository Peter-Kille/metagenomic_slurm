#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=8      #   
#SBATCH --mem=140000            # in megabytes; k2_pluspf is ~116 GB (hash.k2d) + ~20% headroom - resize if you change database

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

module load ${kraken_module}

file=$(ls "${rawdir}"/*_1.fastq.gz | sed -n ${SLURM_ARRAY_TASK_ID}p)

R1=$(basename $file | cut -f1 -d.)
base=$(echo $R1 | sed 's/_1$//')

# One kraken2 run per stringency level (--confidence); outputs go to ${krakendir}/conf<level>/
for conf in ${conf_levels}; do
    outsub="${krakendir}/conf${conf}"
    mkdir -p "${outsub}"

    # --memory-mapping: database is mmap'd rather than copied into private RAM, so array tasks
    # on the same node share one page-cache copy and later confidence levels reuse the warm cache
    kraken2 --db ${krakendbdir} \
            --memory-mapping \
            --paired ${trimdir}/${base}_trim_1.fastq.gz ${trimdir}/${base}_trim_2.fastq.gz \
            --threads ${SLURM_CPUS_PER_TASK} \
            --confidence ${conf} \
            --minimum-hit-groups ${hit_groups} \
            --report ${outsub}/${base}.kraken.report \
            --output ${outsub}/${base}.kraken.raw

    gzip -f ${outsub}/${base}.kraken.raw
done