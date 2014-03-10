
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
use Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo;
use Data::Dumper;
use List::MoreUtils qw/natatime/;

=head1 CONSTRUCTOR
=head2 new
  Arg [-DIVISION]  : 
       string - Compara division e.g. plants, pan_homology
  Arg [-METHOD]    : 
       string - compara method e.g. PROTEIN_TREES, LASTZ_NET
  Arg [-DBNAME] : 
       string - name of the compara database in which the analysis can be found
  Arg [-GENOMES]  : 
       arrayref - list of genomes involved in analysis

  Example    : $info = Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
  my ($proto, @args) = @_;
  my $self = bless {}, $proto;
  ($self->{dbc}) = rearrange(['DBC'], @args);
  return $self;
}

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
genebuild,dbname,species_id,has_pan_compara,has_variation,has_peptide_compara,
has_genome_alignments,has_other_alignments)
		values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)/,
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
	-SQL => q/insert into compara_analysis(method,division,dbname)
		values(?,?,?)/,
	-PARAMS =>
	  [$compara->method(), $compara->division(), $compara->dbname()],
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
has_pan_compara,has_variation,has_peptide_compara,
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

=head2 fetch_by_species
  Arg	     : Name of species
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
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

=head2 fetch_by_division
  Arg	     : Name of division
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome infos for specified division
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_division {
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
  Arg	     : Name of genome
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

=head2 fetch_by_name_pattern
  Arg	     : Regular expression matching of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_name_pattern {
  my ($self, $name, $keen) = @_;
  return
	$self->_fetch_generic($base_fetch_sql . q/ where name REGEXP ?/,
						  [$name], $keen);
}

=head2 fetch_by_alias
  Arg	     : Alias of genome
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch genome info for specified species
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_by_alias {
  my ($self, $name, $keen) = @_;
  return
	$self->_fetch_generic(
				$base_fetch_sql .
				  q/ join genome_alias using (genome_id) where alias=?/,
				[$name],
				$keen);
}

=head2 fetch_with_variation
  Arg        : (optional) if 1, expand children of genome info
  Description: Fetch all genome info that have variation data
  Returntype : arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub fetch_with_variation {
  my ($self, $keen) = @_;
  return $self->_fetch_generic_with_args({'has_variation' => '1'},
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

sub fetch_with_peptide_compara {
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

sub fetch_with_pan_compara {
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

sub fetch_with_genome_alignments {
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

sub fetch_with_other_alignments {
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
	push @$comparas, $self->_fetch_compara($id);
  }
  $genome->compara($comparas);
  $genome->has_pan_compara();
  $genome->has_genome_alignments();
  $genome->has_peptide_compara();
  return;
}

=head2 _fetch_compara
  Arg	     : ID of GenomeComparaInfo 
  Description: Fetch compara analyses by ID
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub _fetch_compara {
  my ($self, $id) = @_;
  # check to see if we've cached this already
  my $compara =
	$self->_get_cached_obj(
					 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo',
					 $id);
  if (!defined $compara) {
	# generate from a query
	# build the main object first
	($compara) = @{
	  $self->{dbc}->sql_helper()->execute(
		-SQL =>
q/select compara_analysis_id, division, method, dbname from compara_analysis where compara_analysis_id=?/,
		-PARAMS   => [$id],
		-CALLBACK => sub {
		  my @row = @{shift @_};
		  my $c =
			Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo->new();
		  $c->dbID($row[0]);
		  $c->division($row[1]);
		  $c->method($row[2]);
		  $c->dbname($row[3]);
		  return $c;
		});
	};
	$compara->adaptor($self);
# add genomes on one by one (don't nest the fetch here as could run of connections)
	my $genomes = [];
	for my $genome_id (
	  @{$self->{dbc}->sql_helper()->execute_simple(
		  -SQL =>
q/select distinct(genome_id) from genome_compara_analysis where compara_analysis_id=?/,
		  -PARAMS => [$id]);
	  })
	{
	  push @$genomes, $self->fetch_by_dbID($genome_id);
	}
	$compara->genomes($genomes);
	# cache the completed compara object
	$self->_store_cached_obj(
					 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo',
					 $compara);
  } ## end if (!defined $compara)
  return $compara;
} ## end sub _fetch_compara

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
