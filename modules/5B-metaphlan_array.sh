#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=16      #   
#SBATCH --mem=128000     # in megabytes, unless unit explicitly stated

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

file=$(ls "${rawdir}"/*_1.fastq.gz | sed -n ${SLURM_ARRAY_TASK_ID}p)

R1=$(basename $file | cut -f1 -d.)
base=$(echo $R1 | sed 's/_1$//')

# database is installed once in 5A - do not install here (parallel array tasks would collide)
# MetaPhlAn refuses to overwrite an existing --mapout, so clear leftovers from a previous run
rm -f ${metaphlandir}/${base}.bowtie2.bz2

metaphlan ${trimdir}/${base}_trim_1.fastq.gz,${trimdir}/${base}_trim_2.fastq.gz \
	--db_dir ${metaphlandbdir} \
	--index ${metaphlandb} \
	--mapout ${metaphlandir}/${base}.bowtie2.bz2 \
	--nproc ${SLURM_CPUS_PER_TASK} \
	--input_type fastq \
	-o ${metaphlandir}/${base}.metagenome.txt

metaphlan ${metaphlandir}/${base}.bowtie2.bz2 \
	--db_dir ${metaphlandbdir} \
	--index ${metaphlandb} \
	--nproc ${SLURM_CPUS_PER_TASK} \
	--input_type mapout \
	--biom_format_output \
	-o ${metaphlandir}/${base}.biom
