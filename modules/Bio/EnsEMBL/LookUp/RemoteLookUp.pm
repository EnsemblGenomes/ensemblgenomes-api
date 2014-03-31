
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

# creation of default implementation

my $lookup = Bio::EnsEMBL::RemoteLookUp->new();
my $dbas = $lookup->registry()->get_all();
$dbas = $lookup->get_all_by_taxon_id(388919);
$dbas = $lookup->get_by_name_pattern("Escherichia.*");

=head1 DESCRIPTION

This module is an implementation of Bio::EnsEMBL::LookUp that uses Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor to
access a MySQL database containing information about Ensembl Genomes contents.

The default constructor uses the public MySQL server and creates an info adaptor using the latest Ensembl Genomes release

	my $lookup = Bio::EnsEMBL::LookUp::RemoteLookUp->new();
	
Alternatively, a different server and adaptor can be specified:

	my $lookup = Bio::EnsEMBL::LookUp::RemoteLookUp->new(-USER=>$user, -HOST=>$host, -PORT=>$port, -ADAPTOR=>$adaptor);

Once constructed, the LookUp instance can be used as documented in Bio::EnsEMBL::LookUp.
  
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
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::Utils::EGPublicMySQLServer
  qw/eg_user eg_host eg_pass eg_port/;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Carp;
use List::MoreUtils qw(uniq);

=head1 SUBROUTINES/METHODS

=head2 new

  Description       : Creates a new instance of this object. 
  Returntype        : Instance of lookup
  Status            : Stable

  Example       	: 
  my $lookup = Bio::EnsEMBL::RemoteLookUp->new();
=cut

sub new {
  my ($class, @args) = @_;
  my $self = bless({}, ref($class) || $class);
  ($self->{_adaptor}, $self->{registry}, $self->{user},
   $self->{pass},     $self->{host},     $self->{port})
	= rearrange(['ADAPTOR', 'REGISTRY', 'USER', 'PASS', 'HOST', 'PORT'],
				@args);
  $self->{dba_cache} = {};
  $self->{user}     ||= eg_user();
  $self->{pass}     ||= eg_pass();
  $self->{host}     ||= eg_host();
  $self->{port}     ||= eg_port();
  $self->{registry} ||= q/Bio::EnsEMBL::Registry/;

  if (!defined $self->{_adaptor}) {
	$self->{_adaptor} =
	  Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
	  ->build_adaptor();
  }
  return $self;
}

sub _cache {
  my ($self) = @_;
  return $self->{dba_cache};
}

sub _adaptor {
  my ($self) = @_;
  return $self->{_adaptor};
}

=head2 genome_to_dba
	Description : Build a Bio::EnsEMBL::DBSQL::DBAdaptor instance with the supplied info object
	Argument    : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DBAdaptor
=cut

sub genome_to_dba {
  my ($self, $genome_info) = @_;
  my $dba;
  if (defined $genome_info) {
	assert_ref($genome_info,
			   'Bio::EnsEMBL::Utils::MetaData::GenomeInfo');
	$dba = $self->_cache()->{$genome_info->dbname()};
	if (!defined $dba) {
	  $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
		-USER       => $self->{user},
		-PASS       => $self->{pass},
		-HOST       => $self->{host},
		-PORT       => $self->{port},
		-DBNAME     => $genome_info->dbname(),
		-SPECIES    => $genome_info->species(),
		-SPECIES_ID => $genome_info->species_id(),
		-MULTISPECIES_DB => $genome_info->dbname() =~ m/_collection_/ ?
		  1 :
		  0,
		-GROUP => 'core');
	  $self->_cache()->{$genome_info->dbname()} = $dba;
	}
  }
  return $dba;
} ## end sub genome_to_dba

=head2 genomes_to_dbas
	Description : Build a set of Bio::EnsEMBL::DBSQL::DBAdaptor instances with the supplied info objects
	Argument    : array ref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
	Exceptions  : None
	Return type : array ref of Bio::EnsEMBL::DBSQL::DBAdaptor
=cut

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

=head2 compara_to_dba
	Description : Build a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor instance with the supplied info object
	Argument    : Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
	Exceptions  : None
	Return type : Arrayref of strings
=cut

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
	Description : Return database adaptor that has the supplied string as an alias/name
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_name_exact {
  my ($self, $name) = @_;
  return $self->genome_to_dba(
						   $self->{_adaptor}->fetch_by_any_name($name));
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
  return [
	   uniq(map { $_->taxonomy_id() } @{$self->{_adaptor}->fetch_all()})
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
	 uniq(
	   map { $_->assembly_id() || '' } @{$self->{_adaptor}->fetch_all()}
	 )];
}

1;

