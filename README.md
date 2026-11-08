# Metagenomic Community Analysis
A SLURM pipeline designed for comprehensive commmunity analysis based on classification of paired end illumina data (pe 150bp) using [kraken2](https://github.com/DerrickWood/kraken2) and [metaphlan](http://segatalab.cibio.unitn.it/tools/metaphlan/index.html). The processes includes quality assessment, pre-processing, kraken, bracken, metaphylan with alpha diversity metrics being calculated and krona plots being generated. This pipeline is optimised explicitly for deployment on high-performance computing (HPC) clusters and executed _via_ Slurm Workload Manager.

## Key Features

- **Read Quality Assessment**: Ensures high-quality data processing with integrated quality checks.
- **Pre-processing**: Streamlines the handling of PE 150bp metagenomic data.
- **Community analysis**: Read clasification via kraken (bracken) and metaphylan.
- **Alpha Diversity Metrics**: Calculates Alpha Diversity metrics for both pipeline.
- **Interactive krona plots**: Generates nteractive krona plots to explore your data.


## Installation

1. Install the metagenome_slurm resources into your HPC cluster directory in which you will be performing the assembly:  

```
git clone https://github.com/Peter-Kille/metagenomic_slurm.git
```

2. Put the raw reads in `raw_data` folder.  

3. Run the pipeline using `./deploy.sh -p [slurm queue / partition] -n [unique name for run]`  

4. you can you './deploy.sh -h' for help (see below)

## Available displayed arguments:
```
./deploy.sh -h

Usage: ./deploy.sh -n NAME -p PARTITION [-c "0.0 0.1 0.2 0.5"] [-g 2] [-w work] [-k k2_standard_08gb_20250402] [-m mpa_vJun23_CHOCOPhlAnSGB_202403]

Options:
  -n, --name          REQUIRED: Run name or deployment name - should be unique
  -p, --partition     REQUIRED: Avalible partition / hpc queue (epyc, defq, epyc_ssd, epyc_bigram; pin a node with e.g. "epyc_bigram -w c1-11" or "epyc_bigram -w c1-35")
  -w, --work          Optional: working dir - default is current dir /work/
  -k, --krakendb      Optional: [Krakendb](https://benlangmead.github.io/aws-indexes/k2) - default is "k2_standard_08gb_20250402" - **DO NOT INCLUDE .tar.gz** 
  -m, --metaphlandb   Optional: [Metaphlandb](http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases/) - default is "mpa_vJan25_CHOCOPhlAnSGB_202503" - ** DO NOT INCLUDE .tar**
  -c, --confidence    Optional: kraken2 --confidence levels, quoted list - default "0.0 0.1 0.2 0.5"
  -g, --hitgroups     Optional: kraken2 --minimum-hit-groups - default 2
  -h, --help          Show this help message

```
 **Note:**
- You can run the pipeline multiple times simultaneously with different raw reads, simply repeat the installation process in a different directory and `./deploy` with a different run names identifier name.
- You can manually reconfigure slurm parameters as per your HPC system (e.g memory, CPUs) by going through indivudal scripts in `modules` directory.
- All the relevent outputs will be stored in `outdir` folder, and outputs for every individual steps in the pipeline can be found in `workdir`.

Prof Peter Kille - kille@cardiff.cf.ac.uk
## Stringency levels
Kraken2 is run once per `--confidence` level (`-c`), and bracken, krona and diversity outputs are produced for each level in `conf<level>/` subfolders (e.g. `outdir/bracken/conf0.2/`). `3D` writes `<NAME>_kraken_stringency_summary.tsv` (classification rate, reads resolved to species/genus, richness, domain composition and species-set similarity to the least stringent level, per sample and level) to help choose a level. Choose levels with a blank/mock community in mind: the best level is the one where blank-derived taxa disappear while expected taxa are retained.
## Running as a driver job
`./deploy.sh` validates the arguments and then submits itself as one small Slurm "driver" job (`<NAME>_driver`, 1 CPU, 1 GB; partition `-D`, default `epyc_long`; walltime `-T`, default 7 days - it must not exceed the partition limit, e.g. `-D epyc -T 3-00:00:00`). The driver submits one stage at a time with `sbatch --wait` and stops if a stage fails, so only one stage is ever in the queue. Progress: `tail -f work/0-log/0_driver_<jobid>.out`. Use `-F` to run the driver in your current shell (e.g. inside tmux) instead.

Finished stages leave `work/.done_<stage>` markers, so after fixing a failure you simply run the same `deploy.sh` command again and it resumes at the failed stage. Delete the markers (or use a new `-n`/`-w`) to force stages to rerun, e.g. after changing `-c` or `-k`. `scancel <driver id>` stops the driver; cancel any running stage separately.
