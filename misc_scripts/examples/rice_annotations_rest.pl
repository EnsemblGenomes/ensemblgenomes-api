use strict;
use warnings;

use JSON;
use HTTP::Tiny;
use Data::Dumper;

# create an HTTP client
my $http   = HTTP::Tiny->new();
my $server = 'http://beta.rest.ensemblgenomes.org';

# call the endpoint to get a list of species
my $response = $http->get($server .
							'/info/species?division=EnsemblPlants',
						  {headers =>
							 {'Content-type' => 'application/json'}});
die "Failed to retrieve species: ".$response->{error}
  unless ($response->{success} && length $response->{content});

# parse the result from the HTTP response
my $species_hash = decode_json($response->{content});
# collate a list of genomes from the result hash
my @genomes =
  grep { m/arabidopsis_.*/ }
  map  { $_->{name} } @{$species_hash->{species}};

for my $genome (@genomes) {
  # process each species
  print "Processing $genome\n";
  my $gene_name = 'PAD4';
  # call the endpoint to get a list of species
  $response = $http->get(
	$server . '/lookup/symbol/' . $genome . '/' . $gene_name,
	{
	  headers => {'Content-type' => 'application/json'}});
print Dumper($response);
  die "Failed to retrieve genes\n"
	unless ($response->{success} && length $response->{content});

  # parse the result from the HTTP response
  my $gene_hash = decode_json($response->{content});
print Dumper($gene_hash);
}
