#!/bin/bash
#SBATCH --nodes=1              # number of nodes to use
#SBATCH --tasks-per-node=1     #
#SBATCH --cpus-per-task=4      #   
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

# Is this database already in the shared resources folder?  (<resources_dir>/metaphlan/<version name>/)
shared_db="${resources_dir}/metaphlan/${metaphlandb}"

if ls "${shared_db}/${metaphlandb}"* > /dev/null 2>&1; then
    # YES: link each file into the work db folder instead of copying
    echo "Found ${metaphlandb} in ${shared_db} - linking, not installing"
    for item in "${shared_db}"/*; do
        ln -sfn "${item}" "${metaphlandbdir}/$(basename "${item}")"
    done
else
    # NO: download/build with MetaPhlAn as before
    echo "${metaphlandb} not found in ${shared_db} - installing"
    metaphlan --install --index ${metaphlandb} --db_dir ${metaphlandbdir}
fi

# sanity check: viral (VSC) files needed by 5C
if ! ls ${metaphlandbdir} | grep -qi vsg; then
    echo "WARNING: no *VSG* file found in ${metaphlandbdir} - viral profiling (5C) will fail" >&2
fi
