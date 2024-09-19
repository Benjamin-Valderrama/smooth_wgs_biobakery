#!/bin/bash

# activate humann environment
eval "$(micromamba shell hook --shell bash)"
micromamba activate humann

input_folder=$1 #01.cleandata
output_folder=$2 #02.annotation

# run HUMAnN on each sample of the folder
for sample in $input_folder/* ; do

	if [ -f $sample ] && [[ "$sample" == *.fastq.gz ]]; then

		echo "Analysing : $(basename $sample)"

		# run HUMAnN
		humann --input $sample \
			--output $output_folder/temp_results/ \
			--verbose \
			--threads 80 \
			--bowtie-options "--very-sensitive --seed 1021997 --threads 80" \
			--minpath off
	fi

	# remove part of temp files. We only keep .log files and taxonomic annotation
	rm $output_folder/temp_results/*/*bowtie*
	rm $output_folder/temp_results/*/*diamond*
	rm $output_folder/temp_results/*/*chocophlan*

done


# merge functional profiles
humann_join_tables --input $output_folder/temp_results/ --file_name genefamilies --output $output_folder/functional/uniref_functional_profile.tsv

# split functional profile into unstratified and stratified
humann_split_stratified_table --input $output_folder/functional/uniref_functional_profile.tsv --output $output_folder/functional/

# map uniref90 to ECs
humann_regroup_table --input $output_folder/functional/uniref_functional_profile_unstratified.tsv --group uniref90_level4ec --output $output_folder/functional/ec_functional_profile_unstratified.tsv
humann_regroup_table --input $output_folder/functional/uniref_functional_profile_stratified.tsv --group uniref90_level4ec --output $output_folder/functional/ec_functional_profile_stratified.tsv



# merge taxonomic profiles
eval "$(micromamba shell hook --shell bash)"
micromamba deactivate # deactivate env with HUMAnN
micromamba activate mpa # activate env with Metaphlan

merge_metaphlan_tables.py $output_folder/temp_results/*/*bugs_list.tsv > $output_folder/taxonomy/taxonomic_profile.tsv

micromamba deactivate



# put all log files together
mv $output_folder/temp_results/*/*.log $output_folder/logs/
