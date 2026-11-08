#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=8      #   
#SBATCH --mem=64000     # in megabytes, unless unit explicitly stated

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

# viral (VSC) profiling needs its own alignment + SAM output; separate mapout from 5B so they do not collide
rm -f ${metaphlandir}/${base}.vsc.bowtie2.bz2 ${metaphlandir}/${base}.sam.bz2

metaphlan ${trimdir}/${base}_trim_1.fastq.gz,${trimdir}/${base}_trim_2.fastq.gz \
        --db_dir ${metaphlandbdir} \
        --index ${metaphlandb} \
        --mapout ${metaphlandir}/${base}.vsc.bowtie2.bz2 \
        -s ${metaphlandir}/${base}.sam.bz2 \
        --nproc ${SLURM_CPUS_PER_TASK} \
        --input_type fastq \
        --profile_vsc \
        --vsc_out ${metaphlandir}/${base}_vsc.txt \
        --vsc_breadth 0.75 \
        -o ${metaphlandir}/${base}.metavirus.txt

# MetaPhlAn writes one -o format per run, so make the biom as a second, cheap pass over the same alignment.
# (unverified: that --profile_vsc is honoured when re-profiling from a mapout - see fallback below)
metaphlan ${metaphlandir}/${base}.vsc.bowtie2.bz2 \
        --db_dir ${metaphlandbdir} \
        --index ${metaphlandb} \
        --nproc ${SLURM_CPUS_PER_TASK} \
        --input_type mapout \
        --profile_vsc \
        --vsc_out ${metaphlandir}/${base}_vsc_biompass.txt \
        --vsc_breadth 0.75 \
        --biom_format_output \
        -o ${metaphlandir}/${base}.metavirus.biom \
|| {
    echo "WARNING: biom pass from mapout failed - repeating the full alignment to write the biom" >&2
    rm -f ${metaphlandir}/${base}.vsc2.bowtie2.bz2 ${metaphlandir}/${base}.vsc2.sam.bz2
    metaphlan ${trimdir}/${base}_trim_1.fastq.gz,${trimdir}/${base}_trim_2.fastq.gz \
        --db_dir ${metaphlandbdir} \
        --index ${metaphlandb} \
        --mapout ${metaphlandir}/${base}.vsc2.bowtie2.bz2 \
        -s ${metaphlandir}/${base}.vsc2.sam.bz2 \
        --nproc ${SLURM_CPUS_PER_TASK} \
        --input_type fastq \
        --profile_vsc \
        --vsc_out ${metaphlandir}/${base}_vsc_biompass.txt \
        --vsc_breadth 0.75 \
        --biom_format_output \
        -o ${metaphlandir}/${base}.metavirus.biom
}

# the krona step (6C) depends on this biom - flag a problem here rather than silently downstream
if [[ ! -s ${metaphlandir}/${base}.metavirus.biom ]]; then
    echo "WARNING: ${base}.metavirus.biom missing or empty - no viral krona plot can be made" >&2
fi