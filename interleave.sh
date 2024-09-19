#!/bin/bash

input_folder=$1

for forward_reads in $input_folder/*_1.fastq.gz ; do

	# get name of reverse reads
	reverse_reads="${forward_reads/_1/_2}"

	# name of the file with merged reads
	merged_reads="${forward_reads/_1/}"

	# merge files
	zcat $forward_reads $reverse_reads | pigz --quiet --best --processes 80 > $merged_reads

	# remove forward and reverse files
	rm $forward_reads $reverse_reads

done



