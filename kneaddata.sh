#!/bin/bash

input_folder=$1 #Determined in the main workflow
output_folder=$2

host_genome=$3
genome_basename=$(basename $host_genome)
genome_tag="${genome_basename/*_/}"

# activate conda environment
echo "kneaddata START"
eval "$(micromamba shell hook --shell bash)" ; micromamba activate kneaddata


# for each sample
for forward_read in ${input_folder}/*_1.fastq.gz; do

	# sample name as prefix
	sample_name=$(basename -s _1.fastq.gz ${forward_read})

	# path to reverse reads
	reverse_read=${input_folder}/${sample_name}_2.fastq.gz

	# path to log files
	log=${output_folder}/${sample_name}.log

	echo "PROCESSING SAMPLE : ${sample_name}"

	# run knead data
	# previous line was--bowtie2-options="--very-sensitive"
	kneaddata --input1 ${forward_read} \
		--input2 ${reverse_read} \
		-o ${output_folder} \
		-db ${host_genome} \
		--log ${log} \
		--output-prefix ${sample_name} \
		-t 20 \
		-p 10 \
		--max-memory 10000m \
		--trimmomatic /home/micromamba/micromamba/envs/kneaddata/share/trimmomatic-0.39-2 \
		--trimmomatic-options="SLIDINGWINDOW:5:25 MINLEN:60 LEADING:3 TRAILING:3"  \
		--remove-intermediate-output \
		--reorder \
                --bypass-trf \
		--bowtie2-options="--very-sensitive --seed 1021997"

	# Compress fastq files as they are created
	pigz -f -p 20 ${output_folder}/*.fastq

	for file in ${output_folder}/*.fastq.gz; do
	    # Move human-alike alignments
	    if [[ -f ${file} ]] && [[ ${file} =~ (.*"$genome_tag".*) ]]; then
	        if [[ ${file} =~ _paired_ ]]; then
	            mv ${file} ${output_folder}/human/
	        else
	            mv ${file} ${output_folder}/other_outputs/
	        fi

	    # Move bacteria-alike alignments
	    elif [[ -f ${file} ]] && [[ ${file} =~ _paired_ ]]; then
	            mv ${file} ${output_folder}/non-human/
	    else
        	    mv ${file} ${output_folder}/other_outputs/
	    fi
	done

done
micromamba deactivate

echo "kneaddata FINISHED"
