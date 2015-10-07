
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

Bio::EnsEMBL::Utils::MetaData::GenomeInfo

=head1 SYNOPSIS

  my $genome = Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
	  -species    => $dba->species(),
	  -species_id => $dba->species_id(),
	  -division   => $meta->get_division() || 'Ensembl',
	  -dbname     => $dbname);
	  
  print Dumper($genome->to_hash());

=head1 DESCRIPTION

Object encapsulating meta information about a genome in Ensembl Genomes. 

Can be used to render information about a genome e.g.

print $genome->name()." (".$genome->species.")\n";
print "Sequences: ".scalar(@{$genome->sequences()})."\n";
if($genome->has_variations()) {
	print "Variations: \n";
	# variations is a hash with type as the key
	while(my ($type,$value) = each %{$genome->variations()}) {
		print "- $type\n";
	}
}
print "Compara analyses: ".scalar(@{$genome->compara()})."\n";

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::Utils::MetaData::GenomeInfo;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use strict;
use warnings;

=head1 CONSTRUCTOR
=head2 new
  Arg [-NAME]  : 
       string - human readable version of the name of the genome
  Arg [-SPECIES]    : 
       string - computable version of the name of the genome (lower case, no spaces)
  Arg [-DBNAME] : 
       string - name of the core database in which the genome can be found
  Arg [-SPECIES_ID]  : 
       int - identifier of the species within the core database for this genome
  Arg [-TAXONOMY_ID] :
        string - NCBI taxonomy identifier
  Arg [-SPECIES_TAXONOMY_ID] :
        string - NCBI taxonomy identifier of species to which this genome belongs
  Arg [-ASSEMBLY_NAME] :
        string - name of the assembly
  Arg [-ASSEMBLY_ID] :
        string - INSDC assembly accession
  Arg [-ASSEMBLY_LEVEL] :
        string - highest assembly level (chromosome, supercontig etc.)
  Arg [-GENEBUILD]:
        string - identifier for genebuild
  Arg [-DIVISION]:
        string - name of Ensembl Genomes division (e.g. EnsemblBacteria, EnsemblPlants)
  Arg [-STRAIN]:
        string - name of strain to which genome belongs
  Arg [-SEROTYPE]:
        string - name of serotype to which genome belongs
  Arg [-IS_REFERENCE]:
        bool - 1 if this genome is the reference for its species

  Example    : $info = Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(...);
  Description: Creates a new info object
  Returntype : Bio::EnsEMBL::Utils::MetaData::GenomeInfo
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub new {
	my ( $proto, @args ) = @_;
	my $class = ref($proto) || $proto;
	my $self = bless( {}, $class );
	(
		$self->{name},           $self->{species},
		$self->{dbname},         $self->{species_id},
		$self->{taxonomy_id},    $self->{species_taxonomy_id},
		$self->{assembly_name},  $self->{assembly_id},
		$self->{assembly_level}, $self->{genebuild},
		$self->{division},       $self->{strain},
		$self->{serotype},       $self->{is_reference}
	  )
	  = rearrange(
		[
			'NAME',           'SPECIES',
			'DBNAME',         'SPECIES_ID',
			'TAXONOMY_ID',    'SPECIES_TAXONOMY_ID',
			'ASSEMBLY_NAME',  'ASSEMBLY_ID',
			'ASSEMBLY_LEVEL', 'GENEBUILD',
			'DIVISION',       'STRAIN',
			'SEROTYPE',       'IS_REFERENCE'
		],
		@args
	  );
	$self->{is_reference} ||= 0;
	return $self;
}

=head1 ATTRIBUTE METHODS
=head2 species
  Arg        : (optional) species to set
  Description: Gets/sets species (computationally safe name for species)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species {
	my ( $self, $species ) = @_;
	$self->{species} = $species if ( defined $species );
	return $self->{species};
}

=head2 strain
  Arg        : (optional) strain to set
  Description: Gets/sets strain of genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub strain {
	my ( $self, $arg ) = @_;
	$self->{strain} = $arg if ( defined $arg );
	return $self->{strain};
}

=head2 serotype
  Arg        : (optional) serotype to set
  Description: Gets/sets serotype
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub serotype {
	my ( $self, $arg ) = @_;
	$self->{serotype} = $arg if ( defined $arg );
	return $self->{serotype};
}

=head2 name
  Arg        : (optional) name to set
  Description: Gets/sets readable display name for genome
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub name {
	my ( $self, $arg ) = @_;
	$self->{name} = $arg if ( defined $arg );
	return $self->{name};
}

=head2 dbname
  Arg        : (optional) dbname to set
  Description: Gets/sets name of core database from which genome comes
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub dbname {
	my ( $self, $dbname ) = @_;
	$self->{dbname} = $dbname if ( defined $dbname );
	return $self->{dbname};
}

=head2 species_id
  Arg        : (optional) species_id to set
  Description: Gets/sets species_id of genome within core database
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_id {
	my ( $self, $species_id ) = @_;
	$self->{species_id} = $species_id if ( defined $species_id );
	return $self->{species_id};
}

=head2 taxonomy_id
  Arg        : (optional) taxonomy_id to set
  Description: Gets/sets NCBI taxonomy ID
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub taxonomy_id {
	my ( $self, $taxonomy_id ) = @_;
	$self->{taxonomy_id} = $taxonomy_id if ( defined $taxonomy_id );
	return $self->{taxonomy_id};
}

=head2 species_taxonomy_id
  Arg        : (optional) taxonomy_id to set
  Description: Gets/sets NCBI taxonomy ID of species to which this belongs
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub species_taxonomy_id {
	my ( $self, $taxonomy_id ) = @_;
	$self->{species_taxonomy_id} = $taxonomy_id if ( defined $taxonomy_id );
	return $self->{species_taxonomy_id};
}

=head2 assembly_name
  Arg        : (optional) assembly_name to set
  Description: Gets/sets name of assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_name {
	my ( $self, $assembly_name ) = @_;
	$self->{assembly_name} = $assembly_name if ( defined $assembly_name );
	return $self->{assembly_name};
}

=head2 assembly_id
  Arg        : (optional) assembly_id to set
  Description: Gets/sets INSDC accession for assembly
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_id {
	my ( $self, $assembly_id ) = @_;
	$self->{assembly_id} = $assembly_id if ( defined $assembly_id );
	return $self->{assembly_id};
}

=head2 assembly_level
  Arg        : (optional) assembly_level to set
  Description: Gets/sets highest level of assembly (chromosome, supercontig etc.)
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub assembly_level {
	my ( $self, $assembly_level ) = @_;
	$self->{assembly_level} = $assembly_level
	  if ( defined $assembly_level );
	return $self->{assembly_level};
}

=head2 genebuild
  Arg        : (optional) genebuild to set
  Description: Gets/sets identifier for genebuild
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub genebuild {
	my ( $self, $genebuild ) = @_;
	$self->{genebuild} = $genebuild if ( defined $genebuild );
	return $self->{genebuild};
}

=head2 division
  Arg        : (optional) division to set
  Description: Gets/sets Ensembl Genomes division
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub division {
	my ( $self, $division ) = @_;
	$self->{division} = $division if ( defined $division );
	return $self->{division};
}

=head2 is_reference
  Arg        : (optional) value of is_reference
  Description: Gets/sets whether this is a reference for the species
  Returntype : bool
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub is_reference {
	my ( $self, $is_ref ) = @_;
	$self->{is_reference} = $is_ref if ( defined $is_ref );
	return $self->{is_reference};
}

=head2 db_size
  Arg        : (optional) db_size to set
  Description: Gets/sets size of database containing core
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub db_size {
	my ( $self, $arg ) = @_;
	$self->{db_size} = $arg if ( defined $arg );
	return $self->{db_size};
}

=head2 dbID
  Arg        : (optional) base_count to set
  Description: Gets/sets total number of bases in assembled genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub base_count {
	my ( $self, $base_count ) = @_;
	$self->{base_count} = $base_count if ( defined $base_count );
	return $self->{base_count};
}

=head2 aliases
  Arg        : (optional) arrayref of aliases to set
  Description: Gets/sets aliases by which the genome is also known 
  Returntype : Arrayref of aliases
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub aliases {
	my ( $self, $aliases ) = @_;
	if ( defined $aliases ) {
		$self->{aliases} = $aliases;
	}
	elsif ( !defined $self->{aliases} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_aliases($self);
	}
	return $self->{aliases};
}

=head2 compara
  Arg        : (optional) arrayref of GenomeComparaInfo objects to set
  Description: Gets/sets GenomeComparaInfo describing comparative analyses applied to the genome
  Returntype : Arrayref of Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub compara {
	my ( $self, $compara ) = @_;
	if ( defined $compara ) {
		$self->{compara}               = $compara;
		$self->{has_peptide_compara}   = undef;
		$self->{has_synteny}           = undef;
		$self->{has_genome_alignments} = undef;
		$self->{has_pan_compara}       = undef;
	}
	elsif ( !defined $self->{compara} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_comparas($self);
	}
	return $self->{compara};
}

=head2 sequences
  Arg        : (optional) arrayref of sequences to set
  Description: Gets/sets array of hashrefs describing sequences from the assembly. Elements are hashrefs with name and acc as keys
  Returntype : Arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub sequences {
	my ( $self, $sequences ) = @_;
	if ( defined $sequences ) {
		$self->{sequences} = $sequences;
	}
	elsif ( !defined $self->{sequences} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_sequences($self);
	}
	return $self->{sequences};
}

=head2 publications
  Arg        : (optional) arrayref of pubmed IDs to set
  Description: Gets/sets PubMed IDs for publications associated with the genome
  Returntype : Arrayref of PubMed IDs
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub publications {
	my ( $self, $publications ) = @_;
	if ( defined $publications ) {
		$self->{publications} = $publications;
	}
	elsif ( !defined $self->{publications} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_publications($self);
	}
	return $self->{publications};
}

=head2 variations
  Arg        : (optional) variations to set
  Description: Gets/sets variations associated with genomes as hashref 
  			   (variations,structural variations,genotypes,phenotypes), 
  			   further broken down into counts by type/source
  Returntype : Arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub variations {
	my ( $self, $variations ) = @_;
	if ( defined $variations ) {
		$self->{variations}     = $variations;
		$self->{has_variations} = undef;
	}
	elsif ( !defined $self->{variations} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_variations($self);
	}
	return $self->{variations};
}

=head2 features
  Arg        : (optional) features to set
  Description: Gets/sets general genomic features associated with the genome as hashref
  			   keyed by type (e.g. repeatFeatures,simpleFeatures), further broken down into
  			   counts by analysis
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub features {
	my ( $self, $features ) = @_;
	if ( defined $features ) {
		$self->{features} = $features;
	}
	elsif ( !defined $self->{features} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_features($self);
	}
	return $self->{features};
}

=head2 annotations
  Arg        : (optional) annotations to set
  Description: Gets/sets summary information about gene annotation as hashref, with
  			   annotation type as key and count as value
  Returntype : hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub annotations {
	my ( $self, $annotation ) = @_;
	if ( defined $annotation ) {
		$self->{annotations} = $annotation;
	}
	elsif ( !defined $self->{annotations} && defined $self->adaptor() ) {
		$self->adaptor()->_fetch_annotations($self);
	}
	return $self->{annotations};
}

=head2 other_alignments
  Arg        : (optional) other alignments to set
  Description: Gets/sets other alignments as hashref, keyed by type (dnaAlignFeatures,proteinAlignFeatures)
  			   with values as logic_name-count pairs 
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub other_alignments {
	my ( $self, $other_alignments ) = @_;
	if ( defined $other_alignments ) {
		$self->{other_alignments}     = $other_alignments;
		$self->{has_other_alignments} = undef;
	}
	elsif ( !defined $self->{other_alignments}
		&& defined $self->adaptor() )
	{
		$self->adaptor()->_fetch_other_alignments($self);
	}
	return $self->{other_alignments} || 0;
}

=head1 utility methods
=head2 has_variations
  Arg        : (optional) 1/0 to set if genome has variation
  Description: Boolean-style method, returns 1 if genome has variation, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_variations {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{has_variations} = $arg;
	}
	elsif ( !defined( $self->{has_variations} ) ) {
		$self->{has_variations} = $self->count_variation() > 0 ? 1 : 0;
	}
	return $self->{has_variations};
}

=head2 has_genome_alignments
  Arg        : (optional) 1/0 to set if genome has genome alignments
  Description: Boolean-style method, returns 1 if genome has genome alignments, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_genome_alignments {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{has_genome_alignments} = $arg;
	}
	elsif ( !defined( $self->{has_genome_alignments} )
		&& defined $self->compara() )
	{
		$self->{has_genome_alignments} = 0;
		for my $compara ( @{ $self->compara() } ) {
			if ( $compara->is_dna_compara() ) {
				$self->{has_genome_alignments} = 1;
				last;
			}
		}
	}
	return $self->{has_genome_alignments} || 0;
}

=head2 has_synteny
  Arg        : (optional) 1/0 to set if genome has synteny
  Description: Boolean-style method, returns 1 if genome has synteny, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_synteny {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{has_synteny} = $arg;
	}
	elsif ( !defined( $self->{has_synteny} ) && defined $self->compara() ) {
		$self->{has_synteny} = 0;
		for my $compara ( @{ $self->compara() } ) {
			if ( $compara->is_synteny() ) {
				$self->{has_synteny} = 1;
				last;
			}
		}
	}
	return $self->{has_synteny} || 0;
}

=head2 has_peptide_compara
  Arg        : (optional) 1/0 to set if genome has peptide compara
  Description: Boolean-style method, returns 1 if genome has peptide, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_peptide_compara {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{has_peptide_compara} = $arg;
	}
	elsif ( !defined( $self->{has_peptide_compara} )
		&& defined $self->compara() )
	{
		$self->{has_peptide_compara} = 0;
		for my $compara ( @{ $self->compara() } ) {
			if ( $compara->is_peptide_compara() && !$compara->is_pan_compara() )
			{
				$self->{has_peptide_compara} = 1;
				last;
			}
		}
	}
	return $self->{has_peptide_compara} || 0;
}

=head2 has_pan_compara
  Arg        : (optional) 1/0 to set if genome is included in pan compara
  Description: Boolean-style method, returns 1 if genome is in pan compara, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_pan_compara {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{has_pan_compara} = $arg;
	}
	elsif ( !defined( $self->{has_pan_compara} )
		&& defined $self->compara() )
	{
		$self->{has_pan_compara} = 0;
		for my $compara ( @{ $self->compara() } ) {
			if ( $compara->is_pan_compara() ) {
				$self->{has_pan_compara} = 1;
				last;
			}
		}
	}
	return $self->{has_pan_compara} || 0;
}

=head2 has_other_alignments
  Arg        : (optional) 1/0 to set if genome has other alignments
  Description: Boolean-style method, returns 1 if genome has other alignments, 0 if not
  Returntype : 1 or 0
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub has_other_alignments {
	my ( $self, $arg ) = @_;
	if ( defined $arg ) {
		$self->{has_other_alignments} = $arg;
	}
	elsif ( !defined( $self->{has_other_alignments} ) ) {
		$self->{has_other_alignments} = $self->count_alignments() > 0 ? 1 : 0;
	}
	return $self->{has_other_alignments} || 0;
}

=head2 count_variation
  Description: Returns total number of variations and structural variations mapped to genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub count_variation {
	my ($self) = @_;
	return $self->count_hash_values( $self->{variations}{variations} ) +
	  $self->count_hash_values( $self->{variations}{structural_variations} );
}

=head2 count_alignments
  Description: Returns total number of alignments to genome
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub count_alignments {
	my ($self) = @_;
	return $self->count_hash_values( $self->{other_alignments}{bam} ) +
	  $self->count_hash_values(
		$self->{other_alignments}{proteinAlignFeatures} ) +
	  $self->count_hash_values( $self->{other_alignments}{dnaAlignFeatures} );
}

=head2 get_uniprot_coverage
  Description: Get % of protein coding genes with a UniProt cross-reference
  Returntype : uniprot coverage as percentage
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub get_uniprot_coverage {
	my ($self) = @_;
	return 100.0 *
	  ( $self->annotations()->{nProteinCodingUniProtKB} ) /
	  $self->annotations()->{nProteinCoding};
}

=head2 to_hash
  Description: Render genome as plain hash suitable for export as JSON/XML
  Argument   : (optional) if set to 1, force expansion of children
  Returntype : Hashref
  Exceptions : none
  Caller     : general
  Status     : Stable
=cut

sub to_hash {
	my ( $in, $keen ) = @_;
	my $out;
	my $type = ref $in;
	if (   defined $keen
		&& $keen == 1
		&& $type eq 'Bio::EnsEMBL::Utils::MetaData::GenomeInfo' )
	{
		$in->_preload();
	}
	if ( $type eq 'ARRAY' ) {
		$out = [];
		for my $item ( @{$in} ) {
			push @{$out}, to_hash( $item, $keen );
		}
	}
	elsif ($type eq 'HASH'
		|| $type eq 'Bio::EnsEMBL::Utils::MetaData::GenomeInfo' )
	{
		$out = {};
		while ( my ( $key, $val ) = each %$in ) {
			if ( $key ne 'dbID' && $key ne 'adaptor' && $key ne 'logger' ) {

# deal with keys starting with numbers, which are not valid element names in XML
				if ( $key =~ m/^[0-9].*/ ) {
					$key = '_' . $key;
				}
				$out->{$key} = to_hash( $val, $keen );
			}

		}
	}
	elsif ( $type eq 'Bio::EnsEMBL::Utils::MetaData::GenomeComparaInfo' ) {
		$out = $in->to_hash();
	}
	else {
		$out = $in;
	}

	return $out;
} ## end sub to_hash

=head1 INTERNAL METHODS
=head2 count_hash_values
  Description: Sums values found in hash
  Arg		 : hashref
  Returntype : integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub count_hash_values {
	my ( $self, $hash ) = @_;
	my $tot = 0;
	if ( defined $hash ) {
		for my $v ( values %{$hash} ) {
			$tot += $v;
		}
	}
	return $tot;
}

=head2 count_hash_lengths
  Description: Sums sizes of arrays found in hash as values
  Arg		 : hashref
  Returntype : integer
  Exceptions : none
  Caller     : internal
  Status     : Stable
=cut

sub count_hash_lengths {
	my ( $self, $hash ) = @_;
	my $tot = 0;
	if ( defined $hash ) {
		for my $v ( values %{$hash} ) {
			$tot += scalar(@$v);
		}
	}
	return $tot;
}

=head2 dbID
  Arg        : (optional) dbID to set set
  Description: Gets/sets internal genome_id used as database primary key
  Returntype : dbID string
  Exceptions : none
  Caller     : Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
  Status     : Stable
=cut

sub dbID {
	my ( $self, $id ) = @_;
	$self->{dbID} = $id if ( defined $id );
	return $self->{dbID};
}

=head2 adaptor
  Arg        : (optional) adaptor to set set
  Description: Gets/sets GenomeInfoAdaptor
  Returntype : Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut

sub adaptor {
	my ( $self, $adaptor ) = @_;
	$self->{adaptor} = $adaptor if ( defined $adaptor );
	return $self->{adaptor};
}

=head2 _preload
  Description: Ensure all children are loaded (used for hash transformation)
  Returntype : none
  Exceptions : none
  Caller     : Internal
  Status     : Stable
=cut

sub _preload {
	my ($self) = @_;
	$self->aliases();
	$self->annotations();
	$self->compara();
	$self->features();
	$self->other_alignments();
	$self->publications();
	$self->sequences();
	$self->variations();
	return;
}

=head2 _preload
  Description: Remove all children (used after hash transformation to ensure object is minimised)
  Returntype : none
  Exceptions : none
  Caller     : dump_metadata.pl
  Status     : Stable
=cut

sub _unload {
	my ($self) = @_;
	$self->{aliases}          = undef;
	$self->{annotations}      = undef;
	$self->{compara}          = undef;
	$self->{features}         = undef;
	$self->{other_alignments} = undef;
	$self->{publications}     = undef;
	$self->{sequences}        = undef;
	$self->{variations}       = undef;
	return;
}

1;
