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

module load ${python_module}

for conf in ${conf_levels}; do
    outsub="${krakendir}/conf${conf}"
    # run inside the level folder: kraken2_long_to_wide.py writes kraken_unclassifieds.csv to the cwd
    ( cd ${outsub} && python ${scriptdir}/kraken2_long_to_wide.py -i ${outsub}/*.report -o ${outsub}/${NAME}_kraken_analytic_matrix.csv )
done

# copy per-level results (not the database folder)
mkdir -p ${outdir}/kraken
for conf in ${conf_levels}; do
    cp -r ${krakendir}/conf${conf} ${outdir}/kraken/
done