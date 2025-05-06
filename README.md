# Metagenomic Community Analysis
A SLURM pipeline designed for comprehensive commmunity analysis based on classification of paired end illumina data (pe 150bp) using [kraken2](https://github.com/DerrickWood/kraken2) and [metaphlan](http://segatalab.cibio.unitn.it/tools/metaphlan/index.html). The processes includes quality assessment, pre-processing, kraken, bracken, metaphylan with alpha diversity metrics being calculated and krona plots being generated. This pipeline is optimised explicitly for deployment on high-performance computing (HPC) clusters and executed _via_ Slurm Workload Manager.

## Key Features

- **Transcriptome Quality Assessment**: Ensures high-quality data processing with integrated quality checks.
- **Pre-processing**: Streamlines the handling of PE 150bp metagenomic data.
- **Community analysis**: Read clasification via kraken (bracken) and metaphylan.
- **Alpha Diversity Metrics**: Calculates Alpha Diversity metrics for both pipeline.
- **Interactive krona plots**: Generates nteractive krona plots to explore your data.


## Installation

1. Install the metagenome_slurm resources into your HPC cluster directory in which you will be performing the assembly:  

```
git clone git@github.com:Peter-Kille/metagenomic_slurm.git
```

2. Put the raw reads in `raw_data` folder.  

3. Run the pipeline using `./deploy.sh -p [slurm queue / partition] -n [unique name for run]`  

4. you can you './deploy.sh -h' for help (see below)

## Available displayed arguments:
```
./deploy.sh -h

Usage: ./deploy.sh --name NAME [--env ENV] [--partition PARTITION]

Options:
  -n, --name          REQUIRED: Run name or deployment name - should be unique
  -w, --work          Optional: working dir - default is current dir /work/
  -p, --partition     Optional: Avalible partition / hpc queue (epyc, defq, jumbo, epyc_ssd)
  -k, --kraken        Optional: Krakendb - default is "k2_standard_08gb_20250402" - **DO NOT INCLUDE .tar.gz** 
  -h, --help          Show this help message

```
 **Note:**
- You can run the pipeline multiple times simultaneously with different raw reads, simply repeat the installation process in a different directory and `./deploy` with a different run names identifier name.
- You can manually reconfigure slurm parameters as per your HPC system (e.g memory, CPUs) by going through indivudal scripts in `modules` directory.
- All the relevent outputs will be stored in `outdir` folder, and outputs for every individual steps in the pipeline can be found in `workdir`.

Prof Peter Kille - kille@cardiff.cf.ac.uk
