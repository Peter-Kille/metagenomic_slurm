#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=8      #   
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

module load ${metaphlan_module}
module load ${r_module}

python ${scriptdir}/merge_metaphlan_tables.py ${metaphlandir}/*.metagenome.txt > ${metaphlandir}/${NAME}_merged_abundance_table.txt

#alpha diversity shannon, richness simpson, gini
Rscript modules/scripts/calculate_diversity.R -f ${NAME}_merged_abundance_table.txt -d alpha -m shannon
Rscript modules/scripts/calculate_diversity.R -f ${NAME}_merged_abundance_table.txt -d alpha -m simpson
Rscript modules/scripts/calculate_diversity.R -f ${NAME}_merged_abundance_table.txt -d alpha -m richness
Rscript modules/scripts/calculate_diversity.R -f ${NAME}_merged_abundance_table.txt -d alpha -m gini

#beta diversity
#these are not working

mkdir ${outdir}/metaphlan
#rm ${metaphlandir}/*.bowtie2.bz2
cp ${metaphlandir}/* ${outdir}/metaphlan/
cp -R ${metaphlandir}/diversity_analysis ${outdir}/metaphlan/
