use strict;
use warnings;

use JSON;
use HTTP::Tiny;
use Data::Dumper;

# create an HTTP client
my $http   = HTTP::Tiny->new();
my $server = 'http://beta.rest.ensemblgenomes.org';

# function for invoking endpoint
sub call_endpoint {
  my ($url) = @_;R
  print "Invoking $url\n";
  my $response = $http->get($url,
							{ headers =>
								{ 'Content-type' => 'application/json' }
							} );
  die 'Failed to retrieve homologues: ' .
	( $response->{error} || "unknown error" )
	unless ( $response->{success} && length $response->{content} );
  return decode_json( $response->{content} );
}

# call endpoint to find homologues of A. thaliana DEAR3
# gene to look for
my $gene = 'DEAR3';
# species to look for
my $species = 'arabidopsis_thaliana';
# compara database to search in
my $compara = 'plants';
# construct URL
my $url =
"$server/homology/symbol/$species/$gene?content-type=application/json&compara=plants";

# call url endpoint and get a hash back
my $homologue_data = call_endpoint($url);
# parse the homologue list from the response
my @homologues = @{ $homologue_data->{data}[0]{homologies} };

# filter homologues to orthologues with tracheophytes
@homologues = grep {
  $_->{taxonomy_level} eq 'Tracheophyta' &&
	$_->{type} =~ m/ortholog/
} @homologues;

# iterate over orthologues
for my $homologue (@homologues) {
  my $target_species = $homologue->{target}{species};
  my $target_id      = $homologue->{target}{protein_id};
  print "$target_species orthologue $target_id\n";
  # get GO terms
  $url =
"$server/xrefs/id/$target_id?content-type=application/json;external_db=GO;all_levels=1";
  my $go_data = call_endpoint($url);
  for my $go (@{$go_data}) {
	print $go->{display_id} .
	  ' ' . $go->{description} . ' (Evidence: ' .
	  join( ',', @{ $go->{linkage_types} } ) . ")\n";
  }
}

