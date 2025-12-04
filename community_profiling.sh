#!/bin/bash

# activate humann environment
eval "$(micromamba shell hook --shell bash)"
micromamba activate humann

input_folder=$1 #01.cleandata
output_folder=$2 #02.annotations

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
			--nucleotide-database /data/databases/biobakery/chocophlan \
			--metaphlan-options "-t rel_ab_w_read_stats" \
			--minpath off
	fi

	# remove part of temp files. We only keep .log files and taxonomic annotation
	rm $output_folder/temp_results/*/*bowtie*
	rm $output_folder/temp_results/*/*diamond*
	rm $output_folder/temp_results/*/*chocophlan*

done

# get counts for each taxa (only possible thanks to the flag '-t rel_ab_w_read_stats')
for bug_list in $output_folder/temp_results/*/*bugs_list.tsv ; do

        estimated_counts="${bug_list/bugs_list/estimated_counts}"

        # redirect taxonomy, ncbi id and estimated counts to a the
        # estimated counts file
        cat $bug_list | cut -f1,2,5 > $estimated_counts

        # Rename the colnames from: 'estimated_number_of_reads_from_the_clade' to 'relative_abundance'
        sed -i 's/estimated_number_of_reads_from_the_clade/relative_abundance/' $estimated_counts
done

# merge taxonomic profiles (counts)
merge_metaphlan_tables.py $output_folder/temp_results/*/*estimated_counts.tsv > $output_folder/taxonomy/taxonomic_profile_counts.tsv
# merge taxonomic profiles (relative abundances)
merge_metaphlan_tables.py $output_folder/temp_results/*/*bugs_list.tsv > $output_folder/taxonomy/taxonomic_profile_rel_abund.tsv


# merge functional profiles
humann_join_tables --input $output_folder/temp_results/ --file_name genefamilies --output $output_folder/functional/uniref_functional_profile.tsv

# split functional profile into unstratified and stratified
humann_split_stratified_table --input $output_folder/functional/uniref_functional_profile.tsv --output $output_folder/functional/

# map uniref90 to ECs
humann_regroup_table --input $output_folder/functional/uniref_functional_profile_unstratified.tsv --group uniref90_level4ec --output $output_folder/functional/ec_functional_profile_unstratified.tsv
humann_regroup_table --input $output_folder/functional/uniref_functional_profile_stratified.tsv --group uniref90_level4ec --output $output_folder/functional/ec_functional_profile_stratified.tsv

# map uniref90 to KOs
humann_regroup_table --input $output_folder/functional/uniref_functional_profile_unstratified.tsv --group uniref90_ko --output $output_folder/functional/ko_functional_profile_unstratified.tsv
humann_regroup_table --input $output_folder/functional/uniref_functional_profile_stratified.tsv --group uniref90_ko --output $output_folder/functional/ko_functional_profile_stratified.tsv


micromamba deactivate

# put all log files together
mv $output_folder/temp_results/*/*.log $output_folder/logs/
