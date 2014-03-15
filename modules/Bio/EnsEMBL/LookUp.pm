=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::LookUp

=head1 SYNOPSIS

# creation from a database server
Bio::EnsEMBL::LookUp->register_all_dbs( $conf->{host},
	   $conf->{port}, $conf->{user}, $conf->{pass}, $conf->{db});
my $lookup = Bio::EnsEMBL::LookUp->new();
my $dbas = $lookup->registry()->get_all();
$dbas = $lookup->get_all_by_taxon_id(388919);
$dbas = $lookup->get_by_name_pattern("Escherichia.*");

# creation from a URL
my $lookup = Bio::EnsEMBL::LookUp->new(-URL=>'http://bacteria.ensembl.org/registry.json');

=head1 DESCRIPTION

This module is a helper that provides additional methods to aid navigating a registry of >6000 species across >25 databases. 
It does not replace the Registry but provides some additional methods for finding species e.g. by searching for species that 
have an alias that match a regular expression, or species which are derived from a specific ENA/INSDC accession, or species
that belong to a particular part of the taxonomy. 

There are a number of ways of creating a lookup but the simplest is to use the default setting of the latest publicly 
available Ensembl Genomes databases: 

	my $lookup = Bio::EnsEMBL::LookUp->new();

Once a lookup has been created, there are various methods to retreive DBAdaptors for species of interest:

1. To find species by name - all DBAdaptors for species with a name or alias matching the supplied string:

	$dbas = $lookup->get_by_name_exact('Escherichia coli str. K-12 substr. MG1655');

2. To find species by name pattern - all DBAdaptors for species with a name or alias matching the supplied regexp:

	$dbas = $lookup->get_by_name_exact('Escherichia coli .*);

3. To find species with the supplied taxonomy ID:

	$dbas = $lookup->get_all_by_taxon_id(388919);
	
4. In coordination with a taxonomy node adaptor to get DBAs for all descendants of a node:

	my $node = $node_adaptor->fetch_by_taxon_id(511145);
	for my $child (@{$node_adaptor->fetch_descendants($node)}) {
		my $dbas = $lookup->get_all_by_taxon_id($node->taxon_id())
		if(defined $dbas) {
			for my $dba (@{$dbas}) {
				# do something with the $dba
			}
		}
	}

The retrieved DBAdaptors can then be used as normal e.g.

	for my $gene (@{$dba->get_GeneAdaptor()->fetch_all_by_biotype('protein_coding')}) {
		print $gene->external_name."\n";
	}

Once retrieved, the arguments needed for constructing a DBAdaptor directly can be dumped for later use e.g.

	my $args = $lookup->dba_to_args($dba);
	... store and retrieve $args for use in another script ... 
	my $resurrected_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(@$args);
  
=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$

=cut

package Bio::EnsEMBL::LookUp;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use DBI;
use JSON;
use LWP::Simple;
use Carp;
use Data::Dumper;
my $default_cache_file = qw/lookup_cache.json/;

=head1 SUBROUTINES/METHODS

=head2 new

  Description       : Creates a new instance of this object. 
  Returntype        : Instance of lookup
  Status            : Stable

  Example       	: 
  my $lookup = Bio::EnsEMBL::LookUp->new();
=cut

sub new {
  my ($class, @args) = @_;
  my $self = bless({}, ref($class) || $class);
  return $self;
} ## end sub new


=head2 get_all_dbnames
	Description : Return all database names used by the DBAs retrieved from the registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_dbnames {
	throw "Unimplemented method";
}

=head2 get_all
	Description : Return all database adaptors that have been retrieved from registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all {
	throw "Unimplemented method";
}

sub get_all_by_taxon_branch {
	throw "Unimplemented method";
}

=head2 get_all_by_taxon_id
	Description : Returns all database adaptors that have the supplied taxonomy ID
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_taxon_id {
	throw "Unimplemented method";
}

=head2 get_by_name_exact
	Description : Return all database adaptors that have the supplied string as an alias/name
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_name_exact {
	throw "Unimplemented method";
}

=head2 get_all_by_accession
	Description : Returns the database adaptor(s) that contains a seq_region with the supplied INSDC accession (or other seq_region name)
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_accession {
	throw "Unimplemented method";
}

=head2 get_by_assembly_accession
	Description : Returns the database adaptor that contains the assembly with the supplied INSDC assembly accession
	Argument    : Int
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_assembly_accession {
	throw "Unimplemented method";
}

=head2 get_all_by_name_pattern
	Description : Return all database adaptors that have an alias/name that match the supplied regexp
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_name_pattern {
	throw "Unimplemented method";
}

=head2 get_all_by_dbname
	Description : Returns all database adaptors that have the supplied dbname
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_dbname {
	throw "Unimplemented method";
}

=head2 get_all_taxon_ids
	Description : Return list of all taxon IDs registered with the helper
	Exceptions  : None
	Return type : Arrayref of integers
=cut

sub get_all_taxon_ids {
	throw "Unimplemented method";
}

=head2 get_all_names
	Description : Return list of all species names registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_names {
	throw "Unimplemented method";
}

=head2 get_all_accessions
	Description : Return list of all INSDC sequence accessions (or other seq_region names) registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_accessions {
	throw "Unimplemented method";
}

=head2 get_all_versioned_accessions
	Description : Return list of all versioned INSDC sequence accessions (or other seq_region names) registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_accessions {
	throw "Unimplemented method";
}

=head2 get_all_assemblies
	Description : Return list of all INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut
sub get_all_assemblies {
	throw "Unimplemented method";
}

=head2 get_all_versioned_assemblies
	Description : Return list of all versioned INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_assemblies {
	throw "Unimplemented method";
}

1;

