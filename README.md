## Smooth analysis

Here I share scripts I made for the analysis of microbiome data. The scripts allows the user to perform the following tasks: 
* (1) Data adquisition : fastq-dl is used to download fastq files from ENA
* (2) Data quality control and host decontamination : kneaddata is used
* (3) Community profiling : The biobakery is used to generate the taxonomic (metaphlan) and functional (HUMAnN) microbiome profiles.
* (4) Pathways annotation : Omixer is used to generate annotation of GBMs, pathways involved in the synthesis and degradation of neuroactive compounds.

## Requirements

The scipts assume micromamba is used to manage different software and the following environments are available to the user:

* (1) fastq-dl
* (2) kneaddata
* (3) metaphlan
* (4) HUMAnN
* (5) R

The environments can be created from the files provided in the `envs` folder as follows:
```CODE```

## Usage

We look at the help message of the software

```
Usage: wgs_smooth_biobakery.sh -s|--study_folder <STUDY_FOLDER> --host_genome <PATH/TO/GENOME/INDEX> [-n|--accession_number ACCESSION_NUMBER]
        [-r|--run_all] [--run_download] [--run_kneaddata] [--run_profiling] [--run_modules] [-h|--help]

Required arguemnts:
  -s, --study_folder       Specify the name for the study included in this meta-analysis.

Workflow arguments:
  -r, --run_all            Run all steps of the workflow.
  --run_download           Run data download [uses fastq-dl].
  --run_kneaddata          Run reads quality check and alignment [uses kneaddata].
  --run_profiling          Run taxonomic and functional profilling [uses Metaphlan and HUMAnN].
  --run_modules            Run module abundance and coverage calculation [uses OmixerRpm in R].

Optional arguments:
  --library_layout         Sequencing library layout [valid values: PE/SE, DEFAULT: PE].
  -n, --accession_number   Specify the accession number of the raw data at the ENA. (Needed if --run_all or --run_download are used)
  --host_genome            Path to folder with bowtie2 index of host genome. (Needed if --run_kneaddata is used)
  -h, --help               Display this help message.
```

We could run the analysis of the following microbiome dataset
```
bash wgs_smooth_biobakery.sh -s franzosaibd --run_all -n PRJNA400072 --library_layout PE --host_genome path/to/host-genome/index
```
This will create a folder called franzosaibd with a defined structure (see output section below), download the data associated with the provided accession code, decontaminate it of host-associated sequences, generate the taxonomic and functional profiles of the microbiome (bacterial) community and then annotate functional pathways


If we already have fastq files because we are working with our own data (not available in ENA yet) we could run the analysis from an existing directory
```
bash wgs_smooth_biobakery.sh -s franzosaibd --run_kneaddata --run_profiling --run_modules --library_layout PE --host_genome path/to/host-genome/index
```
This assumes that the folder franzosaibd exists, and that the fastq files are within the subfolder `franzosaibd/00.rawdata/*.fastq.gz`


Each step described in the 'Smooth analysis section' is modular, and can be run independently. If the alignments of DNA to reference microbiome genomes is available, we could just run the community profiling
```CODE```

## Output

Below is a schematic of the folder produced after a full run of the software is completed. The software generates the directories and subdirectories to ensure the strucutre is preserved. Only folders relevant for each step of the analysis that was run are generated.

```
STUDY_FOLDER
	|
	|-- 00.rawdata
	|
	|-- 01.cleandata
	|	|
	|	|-- host
	|	|
	|	|-- non-host
	|	|
	|	|-- microbiome
	|
	|-- 02.annotations
	|	|
	|	|-- taxonomy
	|	|
	|	|-- functional
	|	|
	|	|-- temp_results
	|	|
	|	|-- logs
	|
	|-- 03.modules
		|
		|-- stratified modules coverages
                |
                |-- stratified modules abundances
                |
                |-- unstratified modules coverage
                |
                |-- unstratified modules abundances
 ```

### Description of directories and sub-directories

## To do list

* (1) Add references and links to this readme.
* (2) Complete the documentation of sections with < > brackets.
* (3) Path to trimmomatic is hard coded. Make the software to look at path.
* (4) Path to sub scripts is hard coded. Think of best way to handle that. 
