#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=8      #   
#SBATCH --mem-per-cpu=4000     # in megabytes, unless unit explicitly stated

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

module load ${bracken_module}

file=$(ls "${rawdir}"/*_1.fastq.gz | sed -n ${SLURM_ARRAY_TASK_ID}p)

R1=$(basename $file | cut -f1 -d.)
base=$(echo $R1 | sed 's/_1$//')

for conf in ${conf_levels}; do
    outsub="${brackendir}/conf${conf}"
    mkdir -p "${outsub}"

    # NB: bracken -t is the minimum-read threshold (not threads)
    for lvl in S:species G:genus F:family; do
        bracken -d ${krakendbdir} \
                -t ${bracken_min_reads} \
                -r ${read_len} \
                -i ${krakendir}/conf${conf}/${base}.kraken.report \
                -l ${lvl%%:*} \
                -o ${outsub}/${base}_${lvl##*:}.bracken.tsv
    done
done