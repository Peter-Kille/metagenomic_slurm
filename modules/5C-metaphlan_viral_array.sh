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

# NB: --profile_vsc only ADDS the viral-cluster table (${base}_vsc.txt). The -o profile and the biom are still the
# full community profile (bacteria, archaea, eukaryotes and viruses), so the viral-only files are made below by
# keeping just the k__Viruses rows.

# viral (VSC) profiling needs its own alignment + SAM output; separate mapout from 5B so they do not collide
rm -f ${metaphlandir}/${base}.vsc.bowtie2.bz2 ${metaphlandir}/${base}.sam.bz2

# 1. align and profile; -o here is the FULL profile, kept for reference
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
        -o ${metaphlandir}/${base}.vsc_fullprofile.txt || exit 1

# 2. full-profile biom from the same alignment (cheap; the VSC options are not needed for this)
rm -f ${metaphlandir}/${base}.vsc_fullprofile.biom
metaphlan ${metaphlandir}/${base}.vsc.bowtie2.bz2 \
        --db_dir ${metaphlandbdir} \
        --index ${metaphlandb} \
        --nproc ${SLURM_CPUS_PER_TASK} \
        --input_type mapout \
        --biom_format_output \
        -o ${metaphlandir}/${base}.vsc_fullprofile.biom || exit 1

# 3. viral-only text profile: keep the comment/header lines and the k__Viruses rows
awk '/^#/ || /^k__Viruses/' ${metaphlandir}/${base}.vsc_fullprofile.txt > ${metaphlandir}/${base}.metavirus.txt
nviral=$(grep -c '^k__Viruses' ${metaphlandir}/${base}.metavirus.txt)
echo "${base}: ${nviral} viral clade rows in ${base}.metavirus.txt"

# 4. viral-only biom: list the viral observation ids from the full biom, then subset the table to them
module load ${qiime_module}

rm -f ${metaphlandir}/${base}.metavirus.biom
biom convert -i ${metaphlandir}/${base}.vsc_fullprofile.biom -o ${metaphlandir}/${base}.vsc_fullprofile.tsv \
        --to-tsv --header-key taxonomy
awk -F'\t' '!/^#/ && $NF ~ /k__Viruses/ {print $1}' ${metaphlandir}/${base}.vsc_fullprofile.tsv > ${metaphlandir}/${base}.viral_ids.txt

if [[ -s ${metaphlandir}/${base}.viral_ids.txt ]]; then
    biom subset-table -i ${metaphlandir}/${base}.vsc_fullprofile.biom -a observation \
            -s ${metaphlandir}/${base}.viral_ids.txt -o ${metaphlandir}/${base}.metavirus.biom
else
    echo "WARNING: no k__Viruses rows for ${base} - no viral biom or viral krona plot will be made" >&2
fi

# the krona step (6C) depends on this biom - flag a problem here rather than silently downstream
if [[ -e ${metaphlandir}/${base}.metavirus.biom && ! -s ${metaphlandir}/${base}.metavirus.biom ]]; then
    echo "WARNING: ${base}.metavirus.biom is empty - no viral krona plot can be made" >&2
fi
