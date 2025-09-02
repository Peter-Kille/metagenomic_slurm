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

module load ${krona_module}
module load ${python_module}

file=$(ls "${rawdir}"/*_1.fastq.gz | sed -n ${SLURM_ARRAY_TASK_ID}p)

R1=$(basename $file | cut -f1 -d.)
base=$(echo $R1 | sed 's/_1$//')

python ${scriptdir}/kreport2krona.py -r ${krakendir}/${base}.kraken.report -o ${kronadir}/${base}_kraken.krona
ktImportText ${kronadir}/${base}_kraken.krona -o ${kronadir}/${base}_kraken.krona.html

##generate mpa reports
python ${scriptdir}/kreport2mpa.py -r ${krakendir}/${base}.kraken.report -o ${krakendir}/${base}_kraken_MPA_count.txt
python ${scriptdir}/kreport2mpa.py --percentages -r ${krakendir}/${base}.kraken.report -o ${krakendir}/${base}_kraken_MPA_per.txt
 
