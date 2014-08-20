use strict;
use warnings;
use Bio::EnsEMBL::Registry;

# set up Registry using public MySQL databases
print "Loading registry\n";
Bio::EnsEMBL::Registry->load_registry_from_db(
											 -USER => 'anonymous',
											 -HOST => 'mysql-eg-publicsql.ebi.ac.uk',
											 -PORT => 4157 );

# gene to look for
my $gene_name = 'DEAR3';
# species to look for
my $species = 'arabidopsis_thaliana';
# compara database to search in
my $compara = 'plants';

print "Finding gene $gene_name from $species\n";
# get an adaptor to work with genes in the species database
my $dba =
  Bio::EnsEMBL::Registry->get_adaptor( $species, 'core', 'gene' );
# find the gene with the specified name
my ($gene_obj) = @{ $dba->fetch_all_by_external_name($gene_name) };

# get an adaptor to work with genes in compara
my $gene_member_adaptor =
  Bio::EnsEMBL::Registry->get_adaptor( $compara, 'compara',
									   'GeneMember' );

# find the corresponding gene in compara
my $gene_member =
  $gene_member_adaptor->fetch_by_source_stable_id( 'ENSEMBLGENE',
											   $gene_obj->stable_id() );

print "Finding compara homologues\n";
# get an adaptor to work with homologues in compara
my $homology_adaptor =
  Bio::EnsEMBL::Registry->get_adaptor( $compara, 'compara',
									   'Homology' );
# find all homologues involving the gene in question
my @homologies =
  @{ $homology_adaptor->fetch_all_by_Member($gene_member) };

# filter out homologues based on taxonomy and type
@homologies = grep {
  $_->taxonomy_level() eq 'Tracheophyta' &&
	$_->description() =~ m/ortholog/
} @homologies;
foreach my $homology (@homologies) {

  # get the protein from the target
  my $target      = $homology->get_all_Members()->[1];
  my $translation = $target->get_Translation();

  # print some information
  print $target->genome_db()->name() .
	' orthologue ' . $translation->stable_id() . "\n";
	
  # find all the GO terms for this translation
  for my $go_term ( @{ $translation->get_all_DBEntries('GO') } ) {
	# print some information about each GO annotation
	print $go_term->primary_id() . ' ' . $go_term->description();
	# print the evidence for the GO annotation
	print ' (Evidence: ' .
	  ( join ',', map { $_->[0] } @{ $go_term->get_all_linkage_info } )
	  . ")\n";
  }
}

