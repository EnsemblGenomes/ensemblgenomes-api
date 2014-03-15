
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
that belong to a particular part of the bacterial taxonomy. 

There are a number of ways of creating a lookup. The simplest and fastest is to supply a URL for a JSON resource that contains all the details
needed to connect to the public Ensembl Genomes bacterial databases e.g.

	my $lookup = Bio::EnsEMBL::LookUp->new(-URL=>'http://bacteria.ensembl.org/registry.json');

Alternatively, a local file containing the required JSON can be specified instead:

	my $lookup = Bio::EnsEMBL::LookUp->new(-FILE=>"/path/to/reg.json");

Finally, a Registry already loaded with the ENA core databases can be supplied:

	my $lookup = Bio::EnsEMBL::LookUp->new(-REGISTRY=>'Bio::EnsEMBL::Registry');

If the standard Registry is used, the argument can be omitted completely:

	my $lookup = Bio::EnsEMBL::LookUp->new();

To populate the registry with just the Ensembl Bacteria databases for the current software release on a specified server, the following method can be used:

	Bio::EnsEMBL::LookUp->register_all_dbs( $host,
	   $port, $user, $pass);

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

package Bio::EnsEMBL::LookUp::RemoteLookUp;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::Utils::EGPublicMySQLServer
  qw/eg_user eg_host eg_pass eg_port/;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Carp;
use Data::Dumper;

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
  ($self->{genome_info_adaptor},
   $self->{registry}, $self->{user}, $self->{pass}, $self->{host},
   $self->{port})
	= rearrange(['ADAPTOR', 'REGISTRY', 'USER', 'PASS', 'HOST', 'PORT'],
				@args);
  $self->{dba_cache} = {};
  $self->{user}     ||= eg_user();
  $self->{pass}     ||= eg_pass();
  $self->{host}     ||= eg_host();
  $self->{port}     ||= eg_port();
  $self->{registry} ||= q/Bio::EnsEMBL::Registry/;

  if (!defined $self->{adaptor}) {
	$self->{adaptor} =
	  Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->build();
  }
  return $self;
}

sub _cache {
  my ($self) = @_;
  return $self->{dba_cache};
}

sub _adaptor {
  my ($self) = @_;
  return $self->{genome_info_adaptor};
}

sub genome_to_dba {
  my ($self, $genome_info) = @_;
  my $dba;
  if (defined $genome_info) {
	assert_ref($genome_info,
			   'Bio::EnsEMBL::Utils::MetaData::GenomeInfo');
	$dba = $self->_cache($genome_info->dbname());
	if (!defined $dba) {
	  $dba =
		Bio::EnsEMBL::DBSQL::DBAdaptor->new(
									-USER    => $self->{user},
									-PASS    => $self->{pass},
									-HOST    => $self->{host},
									-PORT    => $self->{port},
									-DBNAME  => $genome_info->dbname(),
									-SPECIES => $genome_info->species(),
									-GROUP   => 'core');
	}
  }
  return $dba;
}

sub genomes_to_dbas {
  my ($self, $genomes) = @_;
  my $dbas = [];
  if (defined $genomes) {
	for my $genome (@{$genomes}) {
	  push @$dbas, $self->genome_to_dba($genome);
	}
  }
  return $dbas;
}

sub compara_to_dba {
  my ($self, $genome_info) = @_;
  assert_ref($genome_info,
			 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo');
  my $dba = $self->_cache($genome_info->dbname());
  if (!defined $dba) {
	$dba =
	  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
								   -USER    => $self->{user},
								   -PASS    => $self->{pass},
								   -HOST    => $self->{host},
								   -PORT    => $self->{port},
								   -DBNAME  => $genome_info->dbname(),
								   -SPECIES => $genome_info->division(),
								   -GROUP   => 'compara');
  }
  return $dba;
}

=head2 get_all_dbnames
	Description : Return all database names used by the DBAs retrieved from the registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_dbnames {
  my ($self) = @_;
  return [uniq(map { $_->dbname() } @{$self->{_adaptor}})];
}

=head2 get_all
	Description : Return all database adaptors that have been retrieved from registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all {
  my ($self) = @_;
  return $self->genomes_to_dbas($self->{_adaptor}->fetch_all());
}

sub get_all_by_taxon_branch {
  my ($self, $taxid) = @_;
  return $self->genomes_to_dbas(
			   $self->{_adaptor}->fetch_all_by_taxonomy_branch($taxid));
}

=head2 get_all_by_taxon_id
	Description : Returns all database adaptors that have the supplied taxonomy ID
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_taxon_id {
  my ($self, $taxid) = @_;
  return $self->genomes_to_dbas(
				   $self->{_adaptor}->fetch_all_by_taxonomy_id($taxid));
}

=head2 get_by_name_exact
	Description : Return all database adaptors that have the supplied string as an alias/name
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_name_exact {
  my ($self, $name) = @_;
  return $self->genome_to_dba($self->{_adaptor}->fetch_by_name($name));
}

=head2 get_all_by_accession
	Description : Returns the database adaptor(s) that contains a seq_region with the supplied INSDC accession (or other seq_region name)
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_accession {
  my ($self, $acc) = @_;
  my $genomes =
	$self->{_adaptor}->fetch_all_by_sequence_accession($acc);
  if (!defined $genomes || scalar(@$genomes) == 0) {
	$genomes = $self->{_adaptor}
	  ->fetch_all_by_sequence_accession_unversioned($acc);
  }
  return $self->genomes_to_dbas($genomes);
}

=head2 get_by_assembly_accession
	Description : Returns the database adaptor that contains the assembly with the supplied INSDC assembly accession
	Argument    : Int
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_assembly_accession {
  my ($self, $acc) = @_;
  my $genome = $self->{_adaptor}->fetch_by_assembly_id($acc);
  if (!defined $genome) {
	$genome = $self->{_adaptor}->fetch_by_assembly_id_unversioned($acc);
  }
  return $self->genome_to_dba($genome);
}

=head2 get_all_by_name_pattern
	Description : Return all database adaptors that have an alias/name that match the supplied regexp
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_name_pattern {
  my ($self, $name) = @_;
  return $self->genomes_to_dbas(
				   $self->{_adaptor}->fetch_all_by_name_pattern($name));
}

=head2 get_all_by_dbname
	Description : Returns all database adaptors that have the supplied dbname
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_dbname {
  my ($self, $name) = @_;
  return $self->genomes_to_dbas(
						 $self->{_adaptor}->fetch_all_by_dbname($name));
}

=head2 get_all_taxon_ids
	Description : Return list of all taxon IDs registered with the helper
	Exceptions  : None
	Return type : Arrayref of integers
=cut

sub get_all_taxon_ids {
  my ($self) = @_;
  return [uniq(map { $_->taxon_id() } @{$self->{_adaptor}->fetch_all()})
  ];
}

=head2 get_all_names
	Description : Return list of all species names registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_names {
  my ($self) = @_;
  return [map { $_->name() } @{$self->{_adaptor}->fetch_all()}];
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
  my ($self) = @_;
  return [map { s/\.[0-9]+$// }
		  @{$self->get_all_versioned_assemblies()}];
}

=head2 get_all_versioned_assemblies
	Description : Return list of all versioned INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_assemblies {
  my ($self) = @_;
  return [
	   uniq(map { $_->assembly_id() } @{$self->{_adaptor}->fetch_all()})
  ];
}

1;

