
=head1 LICENSE

Copyright [1999-2014] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor

=head1 SYNOPSIS

my $dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
-USER=>'anonymous',
-PORT=>4157,
-HOST=>'mysql.ebi.ac.uk',
-DBNAME=>'genome_info_21');
my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(-DBC=>$dbc);
my $md = $gdba->fetch_by_species("arabidopsis_thaliana");

=head1 DESCRIPTION

Adaptor for storing and retrieving GenomeInfo objects from MySQL genome_info database

=head1 Author

Dan Staines

=cut

package Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;

use strict;
use warnings;
use Carp qw(cluck croak);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::MetaData::GenomeInfo;
use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Data::Dumper;
use List::MoreUtils qw/natatime/;
use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Utils::EGPublicMySQLServer
  qw/eg_user eg_host eg_pass eg_port/;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

use constant PUBLIC_DBNAME => 'ensemblgenomes_info_';

=head1 CONSTRUCTORS
=head2 new
  Arg        : Bio::EnsEMBL::DBSQL::DBConnection - info database to use
  Example    : $adaptor = Bio::EnsEMBL::Utils::MetaData::GenomeInfoAdaptor->new(...);
  Description: Creates a new adaptor object
  Returntype : Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ($proto, @args) = @_;
  my $self = bless {}, $proto;
  ($self->{dbc}, $self->{taxonomy_adaptor}) =
	rearrange(['DBC', 'TAXONOMY_ADAPTOR'], @args);
  return $self;
}

=head2 build_adaptor
  Arg  : (optional) Ensembl Genomes release (e.g. 21)
  Example    : $info = Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->build_adaptor();
  Description: Creates a new adaptor using the Ensembl Genomes public MySQL instance (using the latest release if specified)
  Returntype : Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : croaks if suitable database cannot be found
  Caller     : general
  Status     : Stable
=cut

sub build_adaptor {
  my ($self, $release) = @_;
  my $dbname;
  if (defined $release) {
	$dbname = PUBLIC_DBNAME . $release;
  }
  else {
	# get the latest release
	my $dbc =
	  Bio::EnsEMBL::DBSQL::DBConnection->new(-user => eg_user(),
											 -host => eg_host(),
											 -port => eg_port());

	my $dbs = $dbc->sql_helper()->execute(
	  -SQL => q/select schema_name, 
      cast(replace(schema_name,'ensemblgenomes_info_','') as unsigned int ) as rel
      from information_schema.SCHEMATA 
      where schema_name like 'ensemblgenomes_info_%' order by rel desc/
	);
	$dbc->disconnect_if_idle();

	if (scalar(@$dbs) == 0) {
	  croak(
		"No suitable database found on " . eg_host() . ":" . eg_port());
	}

	$dbname = $dbs->[0][0];

  }

  return
	Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(
								 Bio::EnsEMBL::DBSQL::DBConnection->new(
													 -user => eg_user(),
													 -host => eg_host(),
													 -port => eg_port(),
													 -dbname => $dbname)
	);
} ## end sub build_adaptor

=head1 METHODS

=head2 store
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the supplied object and all associated child objects (includes other genomes attached by compara if not already stored)
  Returntype : None
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub store {
  my ($self, $genome) = @_;
  return if defined $genome->dbID();
  $self->{dbc}->sql_helper()->execute_update(
	-SQL =>
q/insert into genome(name,species,strain,serotype,division,taxonomy_id,
assembly_id,assembly_name,assembly_level,base_count,
genebuild,dbname,species_id,has_pan_compara,has_variations,has_peptide_compara,
has_genome_alignments,has_synteny,has_other_alignments)
		values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)/,
	-PARAMS => [$genome->name(),
				$genome->species(),
				$genome->strain(),
				$genome->serotype(),
				$genome->division(),
				$genome->taxonomy_id(),
				$genome->assembly_id(),
				$genome->assembly_name(),
				$genome->assembly_level(),
				$genome->base_count(),
				$genome->genebuild(),
				$genome->dbname(),
				$genome->species_id(),
				$genome->has_pan_compara(),
				$genome->has_variations(),
				$genome->has_peptide_compara(),
				$genome->has_genome_alignments(),
				$genome->has_synteny(),
				$genome->has_other_alignments()],
	-CALLBACK => sub {
	  my ($sth, $dbh, $rv) = @_;
	  $genome->dbID($dbh->{mysql_insertid});
	});
  $genome->adaptor($self);
  $self->_store_aliases($genome);
  $self->_store_sequences($genome);
  $self->_store_annotations($genome);
  $self->_store_features($genome);
  $self->_store_variations($genome);
  $self->_store_alignments($genome);
  if (defined $genome->compara()) {

	for my $compara (@{$genome->compara()}) {
	  $self->_store_compara($compara);
	}
  }
  return;
} ## end sub store

=head2 _store_compara
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Description: Stores the supplied object and all associated  genomes (if not already stored)
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_compara {
  my ($self, $compara) = @_;
  return if !defined $compara || defined $compara->dbID();
  $self->{dbc}->sql_helper()->execute_update(
	-SQL =>
	  q/insert into compara_analysis(method,division,set_name,dbname)
		values(?,?,?,?)/,
	-PARAMS => [$compara->method(),   $compara->division(),
				$compara->set_name(), $compara->dbname()],
	-CALLBACK => sub {
	  my ($sth, $dbh, $rv) = @_;
	  $compara->dbID($dbh->{mysql_insertid});
	});
  for my $genome (@{$compara->genomes()}) {
	$self->store($genome);
	$self->{dbc}->sql_helper()->execute_update(
	  -SQL =>
q/insert into genome_compara_analysis(genome_id,compara_analysis_id)
		values(?,?)/,
	  -PARAMS => [$genome->dbID(), $compara->dbID()]);
  }
  return;
}

=head2 _store_aliases
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the aliases for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_aliases {
  my ($self, $genome) = @_;
  for my $alias (@{$genome->aliases()}) {
	$self->{dbc}->sql_helper()->execute_update(
	  -SQL => q/insert into genome_alias(genome_id,alias)
		values(?,?)/,
	  -PARAMS => [$genome->dbID(), $alias]);
  }
  return;
}

=head2 _store_sequences
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the sequences for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_sequences {
  my ($self, $genome) = @_;
  my $it = natatime 1000, @{$genome->sequences()};
  while (my @vals = $it->()) {
	my $sql =
	  'insert ignore into genome_sequence(genome_id,name,acc) values '
	  . join(
	  ',',
	  map {
		'(' . $genome->dbID() . ',"' . $_->{name} . '",' .
		  ($_->{acc} ? ('"' . $_->{acc} . '"') : ('NULL')) . ')'
	  } @vals);
	$self->{dbc}->sql_helper()->execute_update(-SQL => $sql);
  }
  return;
}

=head2 _store_features
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the features for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_features {
  my ($self, $genome) = @_;
  while (my ($type, $f) = each %{$genome->features()}) {
	while (my ($analysis, $count) = each %$f) {
	  $self->{dbc}->sql_helper()->execute_update(
		-SQL =>
		  q/insert into genome_feature(genome_id,type,analysis,count)
		values(?,?,?,?)/,
		-PARAMS => [$genome->dbID(), $type, $analysis, $count]);
	}
  }
  return;
}

=head2 _store_annotations
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the annotations for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_annotations {
  my ($self, $genome) = @_;
  while (my ($type, $count) = each %{$genome->annotations()}) {
	$self->{dbc}->sql_helper()->execute_update(
	  -SQL => q/insert into genome_annotation(genome_id,type,count)
		values(?,?,?)/,
	  -PARAMS => [$genome->dbID(), $type, $count]);
  }
  return;
}

=head2 _store_variations
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the variations for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_variations {
  my ($self, $genome) = @_;
  while (my ($type, $f) = each %{$genome->variations()}) {
	while (my ($key, $count) = each %$f) {
	  $self->{dbc}->sql_helper()->execute_update(
		-SQL =>
		  q/insert into genome_variation(genome_id,type,name,count)
		values(?,?,?,?)/,
		-PARAMS => [$genome->dbID(), $type, $key, $count]);
	}
  }
  return;
}

=head2 _store_alignments
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Stores the alignments for the supplied object
  Returntype : None
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_alignments {
  my ($self, $genome) = @_;
  while (my ($type, $f) = each %{$genome->other_alignments()}) {
	while (my ($key, $count) = each %$f) {
	  $self->{dbc}->sql_helper()->execute_update(
		-SQL =>
		  q/insert into genome_alignment(genome_id,type,name,count)
		values(?,?,?,?)/,
		-PARAMS => [$genome->dbID(), $type, $key, $count]);
	}
  }
  return;
}

sub taxonomy_adaptor {
  my ($self, $adaptor) = @_;
  if (defined $adaptor) {
	$self->{taxonomy_adaptor} = $adaptor;
  }
  elsif (!defined $self->{taxonomy_adaptor}) {
	$self->{taxonomy_adaptor} =
	  Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new_public();
  }
  return $self->{taxonomy_adaptor};
}

=head2 list_divisions
  Description: Get list of all Ensembl Genomes divisions for which information is available
  Returntype : Arrayref of strings
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub list_divisions {
  my ($self) = @_;
  return $self->{dbc}->sql_helper()
	->execute_simple(-SQL =>
	   q/select distinct division from genome where division<>'Ensembl'/
	);
}

my $base_fetch_sql = q/
select 
genome_id as dbID,species,name,strain,serotype,division,taxonomy_id,
assembly_id,assembly_name,assembly_level,base_count,
genebuild,dbname,species_id,
has_pan_compara,has_variations,has_peptide_compara,
has_genome_alignments,has_other_alignments
from genome
/;

=head2 fetch_all
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all {
  my ($self, $keen) = @_;
  return $self->_fetch_generic_with_args({}, $keen);
}

=head2 fetch_by_dbID
  Arg	     : ID of genome info
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified ID
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub fetch_by_dbID {
  my ($self, $id, $keen) = @_;
  return
	_first_element($self->_fetch_generic_with_args({'genome_id', $id}),
				   $keen);
}

=head2 fetch_all_by_sequence_accession
  Arg	     : INSDC sequence accession e.g. U00096.1
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession {
  my ($self, $id, $keen) = @_;
  return
	$self->_fetch_generic(
	$base_fetch_sql .
' where genome_id in (select distinct(genome_id) from genome_sequence where acc=? or name=?)',
	[$id, $id],
	$keen);
}

=head2 fetch_all_by_sequence_accession_unversioned
  Arg	     : INSDC sequence accession e.g. U00096
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified sequence accession
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_sequence_accession_unversioned {
  my ($self, $id, $keen) = @_;
  return
	$self->_fetch_generic(
	$base_fetch_sql .
' where genome_id in (select distinct(genome_id) from genome_sequence where acc like ? or name like ?)',
	[$id . '.%', $id . '.%'],
	$keen);
}

=head2 fetch_by_assembly_id
  Arg	     : INSDC assembly accession
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly ID
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_id {
  my ($self, $id, $keen) = @_;
  return _first_element(
		  $self->_fetch_generic_with_args({'assembly_id', $id}, $keen));
}

=head2 fetch_by_assembly_id_unversioned
  Arg	     : INSDC assembly set chain (unversioned accession)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified assembly set chain
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_assembly_id_unversioned {
  my ($self, $id, $keen) = @_;
  return
	_first_element($self->_fetch_generic(
						  $base_fetch_sql . ' where assembly_id like ?',
						  [$id . '.%'], $keen));
}

=head2 fetch_by_taxonomy_id
  Arg	     : Taxonomy ID
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified taxonomy node
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_id {
  my ($self, $id, $keen) = @_;
  return $self->_fetch_generic_with_args({'taxonomy_id', $id}, $keen);
}

=head2 fetch_all_by_taxonomy_branch
  Arg	     : Bio::EnsEMBL::TaxonomyNode
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified taxonomy node and its children
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_taxonomy_branch {
  my ($self, $root, $keen) = @_;
  if (ref($root) ne 'Bio::EnsEMBL::TaxonomyNode') {
	if (looks_like_number($root)) {
	  $root = $self->taxonomy_adaptor()->fetch_by_taxon_id($root);
	}
	else {
	  $root = $self->taxonomy_adaptor()->fetch_by_name($root);
	}
  }
  my @genomes = @{$self->fetch_all_by_taxonomy_id($root->taxon_id())};
  for my $node (@{$root->adaptor()->fetch_descendants($root)}) {
	@genomes = (@genomes,
				@{$self->fetch_all_by_taxonomy_id($node->taxon_id(), $keen)}
	);
  }
  return \@genomes;
}

=head2 fetch_all_by_division
  Arg	     : Name of division
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome infos for specified division
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_division {
  my ($self, $division, $keen) = @_;
  return $self->_fetch_generic_with_args({'division', $division},
										 $keen);
}

=head2 fetch_by_species
  Arg	     : Name of species
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_species {
  my ($self, $species, $keen) = @_;
  return _first_element(
		 $self->_fetch_generic_with_args({'species', $species}, $keen));
}

=head2 fetch_by_name
  Arg	     : Display name of genome 
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_name {
  my ($self, $name, $keen) = @_;
  return _first_element(
			   $self->_fetch_generic_with_args({'name', $name}, $keen));
}

=head2 fetch_any_by_name
  Arg	     : Name of genome (display, species, alias etc)
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_any_name {
  my ($self, $name, $keen) = @_;
  my $dba = $self->fetch_by_name($name, $keen);
  if (!defined $dba) {
	$dba = $self->fetch_by_species($name, $keen);
  }
  if (!defined $dba) {
	$dba = $self->fetch_by_alias($name, $keen);
  }
  return $dba;
}

=head2 fetch_all_by_dbname
  Arg	     : Name of database
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified database
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_dbname {
  my ($self, $name, $keen) = @_;
  return $self->_fetch_generic_with_args({'dbname', $name}, $keen);
}

=head2 fetch_all_by_name_pattern
  Arg	     : Regular expression matching of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_by_name_pattern {
  my ($self, $name, $keen) = @_;
  return
	$self->_fetch_generic(
		 $base_fetch_sql . q/ where species REGEXP ? or name REGEXP ? /,
		 [$name, $name], $keen);
}

=head2 fetch_by_alias
  Arg	     : Alias of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_alias {
  my ($self, $name, $keen) = @_;
  return
	_first_element(
			  $self->_fetch_generic(
				$base_fetch_sql .
				  q/ join genome_alias using (genome_id) where alias=?/,
				[$name],
				$keen));
}

=head2 fetch_with_variation
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have variation data
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_variation {
  my ($self, $keen) = @_;
  return $self->_fetch_generic_with_args({'has_variations' => '1'},
										 $keen);
}

=head2 fetch_with_peptide_compara
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have peptide compara data
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_peptide_compara {
  my ($self, $keen) = @_;
  return
	$self->_fetch_generic_with_args({'has_peptide_compara' => '1'},
									$keen);
}

=head2 fetch_with_pan_compara
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have pan comapra data
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_pan_compara {
  my ($self, $keen) = @_;
  return $self->_fetch_generic_with_args({'has_pan_compara' => '1'},
										 $keen);
}

=head2 fetch_with_genome_alignments
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have whole genome alignment data
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_genome_alignments {
  my ($self, $keen) = @_;
  return
	$self->_fetch_generic_with_args({'has_genome_alignments' => '1'},
									$keen);
}

=head2 fetch_with_other_alignments
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have other alignment data
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_with_other_alignments {
  my ($self, $keen) = @_;
  return
	$self->_fetch_generic_with_args({'has_other_alignments' => '1'},
									$keen);
}

=head2 _fetch_variations
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add variations to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_variations {
  my ($self, $genome) = @_;
  croak
"Cannot fetch variations for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $variations = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
	  'select type,name,count from genome_variation where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $variations->{$row[0]}->{$row[1]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->variations($variations);
  $genome->has_variations();
  return;
}

=head2 _fetch_other_alignments
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add other_alignments to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_other_alignments {
  my ($self, $genome) = @_;
  croak
"Cannot fetch alignments for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $alignments = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
	  'select type,name,count from genome_alignment where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $alignments->{$row[0]}->{$row[1]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->other_alignments($alignments);
  $genome->has_other_alignments();
  return;
}

=head2 _fetch_annotations
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add annotations to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_annotations {
  my ($self, $genome) = @_;
  croak
"Cannot fetch annotations for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $annotations = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
	  'select type,count from genome_annotation where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $annotations->{$row[0]} = $row[1];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->annotations($annotations);
  return;
}

=head2 _fetch_features
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add features to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_features {
  my ($self, $genome) = @_;
  croak
"Cannot fetch features  for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $features = {};
  $self->{dbc}->sql_helper()->execute_no_return(
	-SQL =>
'select type,analysis,count from genome_feature where genome_id=?',
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  $features->{$row[0]}->{$row[1]} = $row[2];
	  return;
	},
	-PARAMS => [$genome->dbID()]);
  $genome->features($features);
  return;
}

=head2 _fetch_publications
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add publications to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_publications {
  my ($self, $genome) = @_;
  croak
"Cannot fetch publications for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $pubs =
	$self->{dbc}->sql_helper()->execute_simple(
	   -SQL =>
		 'select publication from genome_publication where genome_id=?',
	   -PARAMS => [$genome->dbID()]);
  $genome->publications($pubs);
  return;
}

=head2 _fetch_aliases
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add aliases to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_aliases {
  my ($self, $genome) = @_;
  croak
"Cannot fetch aliases for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $aliases =
	$self->{dbc}->sql_helper()->execute_simple(
			 -SQL => 'select alias from genome_alias where genome_id=?',
			 -PARAMS => [$genome->dbID()]);
  $genome->aliases($aliases);
  return;
}

=head2 _fetch_sequences
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add sequences to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_sequences {
  my ($self, $genome) = @_;
  croak
"Cannot fetch sequences for a GenomeInfo object that has not been stored"
	if !defined $genome->dbID();
  my $sequences =
	$self->{dbc}->sql_helper()->execute(
	   -USE_HASHREFS => 1,
	   -SQL => 'select name,acc from genome_sequence where genome_id=?',
	   -PARAMS => [$genome->dbID()]);
  $genome->sequences($sequences);
  return;
}

=head2 _fetch_comparas
  Arg	     : Bio::EnsEMBL::Utils::MetaData::GenomeInfo 
  Description: Add compara info to supplied object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_comparas {
  my ($self, $genome) = @_;
  my $comparas = [];
  for my $id (
	@{$self->{dbc}->sql_helper()->execute_simple(
		-SQL =>
		  q/select distinct compara_analysis_id from compara_analysis 
  join genome_compara_analysis using (compara_analysis_id)
  where genome_id=? and method in ('BLASTZ_NET','LASTZ_NET','TRANSLATED_BLAT_NET', 'PROTEIN_TREES')/,
		-PARAMS => [$genome->dbID()])})
  {
	push @$comparas, $self->fetch_compara_by_dbID($id);
  }
  $genome->compara($comparas);
  $genome->has_pan_compara();
  $genome->has_genome_alignments();
  $genome->has_peptide_compara();
  return;
}

=head2 fetch_all_comparas
  Description: Fetch all compara analyses
  Returntype : array ref of Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_comparas {
  my ($self, $id) = @_;
  return $self->_fetch_compara_with_args();
}

=head2 fetch_compara_by_dbID
  Arg	     : ID of compara analysis to retrieve
  Description: Fetch compara specified compara analysis
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_compara_by_dbID {
  my ($self, $id) = @_;
  return _first_element(
		 $self->_fetch_compara_with_args({compara_analysis_id => $id}));
}

=head2 fetch_all_compara_by_division
  Arg	     : Division of compara analyses to retrieve
  Description: Fetch compara specified compara analysis
  Returntype : array ref of Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_compara_by_division {
  my ($self, $division) = @_;
  return $self->_fetch_compara_with_args({division => $division});
}

=head2 fetch_all_compara_by_method
  Arg	     : Method of compara analyses to retrieve
  Description: Fetch compara specified compara analysis
  Returntype : array ref of  Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_all_compara_by_method {
  my ($self, $method) = @_;
  return $self->_fetch_compara_with_args({method => $method});
}

my $base_compara_fetch_sql =
q/select compara_analysis_id, division, method, set_name, dbname from compara_analysis/;

=head2 _fetch_compara_with_args
  Arg	     : hashref of arguments by column
  Description: Fetch compara analyses by column value pairs
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_compara_with_args {
  my ($self, $args) = @_;
  my $sql    = $base_compara_fetch_sql;
  my $params = [values %$args];
  my $clause = join(',', map { $_ . '=?' } keys %$args);
  if ($clause ne '') {
	$sql .= ' where ' . $clause;
  }
  return $self->_fetch_compara_generic($sql, $params);
}

=head2 _fetch_compara_generic
  Arg	     : SQL
  Arg	     : array ref of bind params
  Description: Fetch compara analyses using supplied SQL
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_compara_generic {
  my ($self, $sql, $params) = @_;
  # check to see if we've cached this already

  # build the main object first
  my $comparas = $self->{dbc}->sql_helper()->execute(
	-SQL      => $sql,
	-PARAMS   => $params,
	-CALLBACK => sub {
	  my @row = @{shift @_};
	  my $id  = $row[0];
	  my $c = $self->_get_cached_obj(
					 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo',
					 $id);
	  if (!defined $c) {
		$c = Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new();
		$c->dbID($id);
		$c->division($row[1]);
		$c->method($row[2]);
		$c->set_name($row[3]);
		$c->dbname($row[4]);
		# cache the completed compara object
		$c->adaptor($self);
		$self->_store_cached_obj(
					 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo',
					 $c);
	  }
	  return $c;
	});
  for my $compara (@$comparas) {
# add genomes on one by one (don't nest the fetch here as could run of connections)
	if (!defined $compara->{genomes}) {
	  my $genomes = [];
	  for my $genome_id (
		@{$self->{dbc}->sql_helper()->execute_simple(
			-SQL =>
q/select distinct(genome_id) from genome_compara_analysis where compara_analysis_id=?/,
			-PARAMS => [$compara->dbID()]);
		})
	  {
		push @$genomes, $self->fetch_by_dbID($genome_id);
	  }
	  $compara->genomes($genomes);
	}
  }
  return $comparas;
} ## end sub _fetch_compara_generic

=head2 _fetch_children
  Arg	     : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Description: Fetch all children of specified genome info object
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_children {
  my ($self, $md) = @_;
  $self->_fetch_variations($md);
  $self->_fetch_sequences($md);
  $self->_fetch_aliases($md);
  $self->_fetch_publications($md);
  $self->_fetch_annotations($md);
  $self->_fetch_other_alignments($md);
  $self->_fetch_comparas($md);
  return;
}

=head2 _fetch_generic_with_args
  Arg	     : hashref of arguments by column
  Arg        : (optional) if set to 1, all children will be fetched
  Description: Instantiate a GenomeInfo from the database using a 
               generic method, with the supplied arguments
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_generic_with_args {
  my ($self, $args, $keen) = @_;
  my $sql    = $base_fetch_sql;
  my $params = [values %$args];
  my $clause = join(',', map { $_ . '=?' } keys %$args);
  if ($clause ne '') {
	$sql .= ' where ' . $clause;
  }
  return $self->_fetch_generic($sql, $params, $keen);
}

=head2 _fetch_generic
  Arg	     : SQL to use to fetch object
  Arg	     : arrayref of bind parameters
  Arg        : (optional) if set to 1, all children will be fetched
  Description: Instantiate a GenomeInfo from the database using the specified SQL
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_generic {
  my ($self, $sql, $params, $keen) = @_;
  my $mds = $self->{dbc}->sql_helper()->execute(
	-SQL          => $sql,
	-USE_HASHREFS => 1,
	-CALLBACK     => sub {
	  my $row = shift @_;
	  my $md =
		$self->_get_cached_obj(
							'Bio::EnsEMBL::Utils::MetaData::GenomeInfo',
							$row->{dbID});
	  if (!defined $md) {
		$md = bless $row, 'Bio::EnsEMBL::Utils::MetaData::GenomeInfo';
		$md->adaptor($self);
		$self->_store_cached_obj(
							'Bio::EnsEMBL::Utils::MetaData::GenomeInfo',
							$md);
	  }
	  return $md;
	},
	-PARAMS => $params);
  if (defined $keen && $keen == 1) {
	for my $md (@{$mds}) {
	  $self->_fetch_children($md);
	}
  }
  return $mds;
} ## end sub _fetch_generic

=head2 _cache
  Arg	     : type of object for cache
  Description: Return internal cache for given type
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _cache {
  my ($self, $type) = @_;
  if (!defined $self->{cache} || !defined $self->{cache}{$type}) {
	$self->{cache}{$type} = {};
  }
  return $self->{cache}{$type};
}

=head2 _clear_cache
  Arg	     : (optional) type of object to clear
  Description: Clear internal cache (optionally just one type)
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _clear_cache {
  my ($self, $type) = @_;
  if (defined $type) {
	$self->{cache}{$type} = {};
  }
  else {
	$self->{cache} = {};
  }
  return;
}

=head2 _get_cached_obj
  Arg	     : type of object to retrieve
  Arg	     : ID of object to retrieve
  Description: Retrieve object from internal cache
  Returntype : object
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _get_cached_obj {
  my ($self, $type, $id) = @_;
  return $self->_cache($type)->{$id};
}

=head2 _store_cached_obj
  Arg	     : type of object to store
  Arg	     : object to store
  Description: Store object in internal cache
  Returntype : none
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _store_cached_obj {
  my ($self, $type, $obj) = @_;
  $self->_cache($type)->{$obj->dbID()} = $obj;
  return;
}

=head2 _first_element
  Arg	     : arrayref
  Description: Utility method to return the first element in a list, undef if empty
  Returntype : arrayref element
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _first_element {
  my ($arr) = @_;
  if (defined $arr && scalar(@$arr) > 0) {
	return $arr->[0];
  }
  else {
	return undef;
  }
}

1;
