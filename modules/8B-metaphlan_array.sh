#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=16      #   
#SBATCH --mem=32000     # in megabytes, unless unit explicitly stated

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

metaphlan ${trimdir}/${base}_trim_1.fastq.gz,${trimdir}/${base}_trim_2.fastq.gz \
	--bowtie2out ${metaphlandir}/${base}.bowtie2.bz2 \
	--bowtie2db ${metaphlandbdir} \
	--biom ${metaphlandir}/${base}.biom \
	--nproc ${SLURM_CPUS_PER_TASK} \
	--input_type fastq \
	--profile_vsc \
	--vsc_out ${metaphlandir}/${base}_viral.svc.txt \
	-o ${metaphlandir}/${base}.metagenome.txt

