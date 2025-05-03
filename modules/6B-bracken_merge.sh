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

python ${scriptdir}/combine_bracken_outputs.py --files ${brackendir}/*_species.bracken.tsv -o ${brackendir}/${NAME}_bracken_analytic_matrix_species.csv

python ${scriptdir}/combine_bracken_outputs.py --files ${brackendir}/*_genus.bracken.tsv -o ${brackendir}/${NAME}_bracken_analytic_matrix_genus.csv

python ${scriptdir}/combine_bracken_outputs.py --files ${brackendir}/*_family.bracken.tsv -o ${brackendir}/${NAME}_bracken_analytic_matrix_family.csv

for div in Sh BP Si ISi F; do touch ${brackendir}/${div}_diversity.txt; done

for file in "${rawdir}"/*_1.fastq.gz 
do

R1=$(basename $file | cut -f1 -d.)
base=$(echo $R1 | sed 's/_1$//')

for div in Sh BP Si ISi F; do

printf "${base}\t" >> ${brackendir}/${div}_diversity.txt

python modules/scripts/KrakenTools/KrakenTools/DiversityTools/alpha_diversity.py -f ${brackendir}/${base}_species.bracken.tsv -a ${div} >> ${brackendir}/${div}_diversity.txt

printf "\n" >> ${div}_diversity.txt

done

done

mkdir ${outdir}/bracken
cp ${brackendir}/* ${outdir}/bracken/
