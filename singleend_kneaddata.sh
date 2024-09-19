#!/bin/bash

input_folder=$1 #Determined in the main workflow
output_folder=$2

DB="/data/databases/genomes/human_CHM13-Ychr/"

# activate conda environment
eval "$(micromamba shell hook --shell bash)" ; micromamba activate kneaddata

echo "kneaddata START"


# for each sample
for file in ${input_folder}/*.fastq.gz; do

	# sample name as prefix
	sample_name=$(basename -s .fastq.gz ${file})
	echo "sample_name : $sample_name"
	# path to log files
	log=${output_folder}/${sample_name}.log
	echo "log_name : $log"

	echo "PROCESSING SAMPLE : ${sample_name}"

	# run knead data
	# previous line was--bowtie2-options="--very-sensitive"
	kneaddata --unpaired ${file} \
		-o ${output_folder} \
		-db ${DB} \
		--log ${log} \
		--output-prefix ${sample_name} \
		-t 20 \
		-p 10 \
		--max-memory 10000m \
		--trimmomatic /home/miniconda/miniconda3/envs/kneaddata/share/trimmomatic-0.39-2 \
		--trimmomatic-options="SLIDINGWINDOW:5:25 MINLEN:60 LEADING:3 TRAILING:3"  \
		--remove-intermediate-output \
		--reorder \
		--run-trf \
		--bypass-trf \
		--bowtie2-options="--very-sensitive --seed 1021997"

	# Compress fastq files as they are created
	pigz -f -p 20 ${output_folder}/*.fastq

	for file in ${output_folder}/*.fastq.gz; do
	    # Move human-alike alignments
	    if [[ -f ${file} ]] && [[ ${file} =~ (.*_chm13-ychr_.*) ]]; then
	            mv ${file} ${output_folder}/human/

            elif [[ -f ${file} ]] && [[ ${file} =~ (.*trimmed.*) ]]; then
	            mv ${file} ${output_folder}/other_outputs/

	    # Move bacteria-alike alignments
	    elif [[ -f ${file} ]]; then
	            mv ${file} ${output_folder}/non-human/
	    fi
	done

done
micromamba deactivate

echo "kneaddata FINISHED"
