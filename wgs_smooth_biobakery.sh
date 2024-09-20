#!/bin/bash

# Default values
# required
current_wd="`pwd`"
study_folder=""

# workflow args
run_all=false
run_download=false
run_kneaddata=false
run_profiling=false
run_modules=false

# optional args
library_layout="PE"
accession_number=""
host_genome=""


# Function to display script usage
function display_usage() {
    echo "Usage: $0 -s|--study_folder <STUDY_FOLDER> --host_genome <PATH/TO/GENOME/INDEX> [-n|--accession_number ACCESSION_NUMBER]"
    echo "	[-r|--run_all] [--run_download] [--run_kneaddata] [--run_profiling] [--run_modules] [-h|--help]"
    echo ""
    echo "Required arguemnts:"
    echo "  -s, --study_folder       Specify the name for the study included in this meta-analysis."
    echo ""
    echo "Workflow arguments:"
    echo "  -r, --run_all            Run all steps of the workflow."
    echo "  --run_download           Run data download [uses fastq-dl]."
    echo "  --run_kneaddata          Run reads quality check and alignment [uses kneaddata]."
    echo "  --run_profiling          Run taxonomic and functional profilling [uses Metaphlan and HUMAnN]."
    echo "  --run_modules            Run module abundance and coverage calculation [uses OmixerRpm in R]."
    echo ""
    echo "Optional arguments:"
    echo "  --library_layout         Sequencing library layout [valid values: PE/SE, DEFAULT: PE]."
    echo "  -n, --accession_number   Specify the accession number of the raw data at the ENA. (Needed if --run_all or --run_download are used)"
    echo "  --host_genome            Path to folder with bowtie2 index of host genome. (Needed if --run_kneaddata is used)"
    echo "  -h, --help               Display this help message."
    echo ""
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -s|--study_folder)
            study_folder="$2"
            shift
            shift
            ;;
        -r|--run_all)
            run_all=true
            shift
            ;;
        -n|--accession_number)
            accession_number="$2"
            shift
            shift
            ;;
	--library_layout)
	    library_layout="$2"
	    shift
	    shift
	    ;;
        --host_genome)
            host_genome="$2"
            shift
            shift
            ;;
        --run_download)
            run_download=true
            shift
            ;;
        --run_kneaddata)
            run_kneaddata=true
            shift
            ;;
        --run_profiling)
            run_profiling=true
            shift
            ;;
        --run_modules)
            run_modules=true
            shift
            ;;
        -h|--help)
            display_usage
            ;;
        *)
            echo "Unknown option: $1"
            display_usage
            ;;
    esac
done

# Check if required flags is provided correctly
if [ -z "$study_folder" ]; then
    echo ""
    echo "Study folder (-s) is required."
    echo ""
    display_usage
fi


# -1. setting up the study folder
if [ ! -d ${study_folder} ]; then
	echo "PROGRESS -- Creating study folder : ${study_folder}"

	mkdir ${study_folder}
	mkdir ${study_folder}/00.rawdata
	mkdir ${study_folder}/nohups
else
	echo "PROGRESS -- The folder '${study_folder}' already exists. Moving to the next step ..."
fi

# 0. fastq-dl: download data from ENA.
if [ "$run_all" = true ] || [ "$run_download" = true ]; then
    if [ -z "$accession_number" ]; then
        echo "Accession number is required for downloading raw data."
        exit 1
    fi

    # DOWNLOAD DATA
    echo "PROGRESS -- Download raw data from ENA. Project accession number : ${accession_number}."
    bash /home/bvalderrama/scripts/biobakery_wgs/fastqdl.sh "${current_wd}/${study_folder}" "${accession_number}" &> "${study_folder}/nohups/download.out"
fi


# 1. kneaddata: quality check, filter, trim and alignment to bacterial and human genomes.
if [ "$run_all" = true ] || [ "$run_kneaddata" = true ]; then
    mkdir ${study_folder}/01.cleandata
    mkdir ${study_folder}/01.cleandata/human
    mkdir ${study_folder}/01.cleandata/non-human
    mkdir ${study_folder}/01.cleandata/other_outputs

    # check correct library_layout
    if [ "$library_layout" != "PE" ] && [ "$library_layout" != "SE" ]; then
	echo ""
	echo "Library layout (--library_layout) can be either 'PE' or 'SE'."
	echo ""
	display_usage
    fi

    # check that --host_genome is not empty
    if [ -z "$host_genome" ]; then
	echo ""
	echo "Path to host genome index (--host_genome) is required."
	echo ""
	display_usage
    fi

    # run kneaddata according to library layout
    if [[ $library_layout == "PE" ]]; then
        echo "PROGRESS -- Filter and trim of raw PE sequences. Decontaminating host-aligned reads."
        bash /home/bvalderrama/scripts/biobakery_wgs/kneaddata.sh ${current_wd}/${study_folder}/00.rawdata ${current_wd}/${study_folder}/01.cleandata $host_genome &> "${study_folder}/nohups/kneaddata.out"

    elif [[ $library_layout == "SE" ]]; then
	echo "PROGRESS -- Filter and trim of raw SE sequences. Decontaminating host-aligned reads."
        bash /home/bvalderrama/scripts/biobakery_wgs/singleend_kneaddata.sh ${current_wd}/${study_folder}/00.rawdata ${current_wd}/${study_folder}/01.cleandata $host_genome &> "${study_folder}/nohups/kneaddata.out"
    fi

fi


# 2. metaphlan & humann: taxonmic and functional annotations using close-reference database
if [ "$run_all" = true ] || [ "$run_profiling" = true ]; then
    # RUN WOLTKA TO ANNOTATE THE SAMPLES USING THE ALIGNMENTS PRODUCED IN THE PREVIOUS STEP
    echo "PROGRESS -- Performing taxonomic and functional (Uniref90 & EC) profiling."
    mkdir ${study_folder}/02.annotations
    mkdir ${study_folder}/02.annotations/taxonomy
    mkdir ${study_folder}/02.annotations/functional
    mkdir ${study_folder}/02.annotations/logs

    # interleave forward and reverse reads before community profiling
    if [[ $library_layout == "PE" ]]; then
	bash /home/bvalderrama/scripts/biobakery_wgs/interleave.sh ${study_folder}/01.cleandata/non-human/
    fi

    # run metaphlan for taxonomic annotation and humann for functional
    bash /home/bvalderrama/scripts/biobakery_wgs/community_profiling.sh ${study_folder}/01.cleandata/non-human ${study_folder}/02.annotations &> "${study_folder}/nohups/profiling.out"
fi


# 3. OmixerRpm: calculate modules
if [ "$run_all" = true ] || [ "$run_modules" = true ]; then
    # CALCULATE THE GBMs USING THE FUNCTIONAL ANNOTATION GENERATED ABOVE
    echo "PROGRESS -- Calculating modules using the EC-based functional profiling."
    mkdir ${study_folder}/03.modules

    bash /home/bvalderrama/scripts/biobakery_wgs/run_modules.sh ${current_wd}/${study_folder}/02.annotations/functional ${current_wd}/${study_folder}/03.modules -m GIMs &> "${study_folder}/nohups/omixer.out"
fi

echo "PROGRESS -- WGS primary analysis finished."
