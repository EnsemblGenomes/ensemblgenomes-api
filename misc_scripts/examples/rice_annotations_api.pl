use warnings;
use strict;
use Bio::EnsEMBL::Registry;

# set up Registry using public MySQL databases
print "Loading registry\n";
Bio::EnsEMBL::Registry->load_registry_from_db(
											 -USER => 'anonymous',
											 -HOST => 'mysql-eg-publicsql.ebi.ac.uk',
											 -PORT => 4157);

# find species where the name matches 'oryza'
print "Finding rice genomes\n";
my @genomes =
  grep { m/^oryza_.*/ } @{Bio::EnsEMBL::Registry->get_all_species()};

# process each rice genome
for my $genome (@genomes) {

  print "Processing $genome\n";

  # get a Gene adaptor for the species
  my $gene_adaptor =
	Bio::EnsEMBL::Registry->get_adaptor($genome, 'core', 'Gene');

  # get an adaptor for use with external references
  my $dbentry_adaptor =
	Bio::EnsEMBL::Registry->get_adaptor($genome, 'core',
										'DBEntry');
										
  # find genes with ftsZ in the description
  my @genes = 	@{$gene_adaptor->fetch_all_by_description('%ftsZ%')};								

  for my $gene (@genes) {

	# print the name or identifer of each gene
	print "- " . ($gene->external_name() || $gene->stable_id()) .
	  " " . $gene->description() . "\n";

	# GO terms are attached to translations
	# which are attached to transcripts
	for my $transcript (@{$gene->get_all_Transcripts()}) {

	  # find the translation for this transcript
	  my $translation = $transcript->translation();
	  if (defined $translation) {

		# find all the GO terms for this translation
		for my $go_term (
			  @{$dbentry_adaptor->fetch_all_by_Translation($translation,
														   'GO')})
		{

		  # print some information about each GO annotation
		  print "-- " . $go_term->primary_id() .
			" " . $go_term->description() . "\n";

		  # print the evidence for the GO annotation
		  for my $linkage_info (@{$go_term->get_all_linkage_info}) {
			# linkage info is a pair of the evidence code
			# and the source cross-reference
			print "--- Evidence: " . $linkage_info->[0] .
			  " from " . $linkage_info->[1]->dbname() .
			  ":" . $linkage_info->[1]->display_id() . "\n";
		  }
		}
	  }
	} ## end for my $transcript (@{$gene...})
  } ## end for my $gene (@{$gene_adaptor...})
} ## end for my $genome (@genomes)
