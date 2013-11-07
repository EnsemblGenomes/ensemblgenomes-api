
=pod
=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.
 
__END__

=pod

=head1 NAME

Bio::EnsEMBL::TaxonomyNode

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

An object representing a node of the NCBI taxonomy, (most often) created by
Bio::EnsEMBL::DBSQL::TaxonomyAdaptor.

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$

=cut

package Bio::EnsEMBL::TaxonomyNode;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw( rearrange );

use base qw( Bio::EnsEMBL::Storable );

=head1 SUBROUTINES/METHODS

=head2 new

  Arg [-TAXON_ID]	: Int
                      The ID of the taxonomy node.
  Arg [-PARENT_ID]	: Int
                      ID of the parent of this node
  Arg [-ROOT_ID]	: Int
                      ID of the root node of this node
  Arg [-RANK]		: String
                      Rank of this node           
  Arg [-NAMES]		: Hash
                      Hash of names for this node
  Arg [-LEFT_INDEX]	: Int
                      Left index of this node in tree
  Arg [-RIGHT_INDEX]: Int
                      Right index of this node in tree
  Arg               : Further arguments required for parent class
                      Bio::EnsEMBL::Storable.

  Description   : Creates a taxonomy node object.

  Example       : 

				my $node =
				  Bio::EnsEMBL::TaxonomyNode->new( -TAXON_ID  => 83333,
														-PARENT_ID => 500585,
														-RANK      => 'species',
														-ROOT_ID   => 1,
														-LEFT_INDEX => 1092,
														-RIGHT_INDEX => 1093,
														-ADAPTOR   => $tna );

  Return type   : Bio::EnsEMBL::TaxonomyNode
=cut

sub new {
  my ($proto, @args) = @_;
  my $self = $proto->SUPER::new(@args);
  my ($tax_id, $parent_id, $rank, $names, $root_id, $left_index, $right_index, $dba) = rearrange(['TAXON_ID', 'PARENT_ID', 'RANK', 'NAMES', 'ROOT_ID', 'LEFT_INDEX', 'RIGHT_INDEX', 'DBA'], @args);

  $self->{'taxon_id'}  = $tax_id;
  $self->{'parent_id'} = $parent_id;
  $self->{'rank'}      = $rank;
  $names ||= {};
  $self->{'names'}           = $names;
  $self->{'root_id'}         = $root_id;
  $self->{'left_index'}      = $left_index;
  $self->{'right_index'}     = $right_index;
  $self->{'dba'}             = $dba || [];
  $self->{'num_descendants'} = $right_index - $left_index - 1;
  return $self;
}

=head2 taxon_id

Description : Taxon ID of this node
Return type : Int
=cut

sub taxon_id {
  my ($self) = @_;
  return $self->{'taxon_id'};
}
=head2 parent_id

Taxon ID of the parent of this node
Return type : Int
=cut

sub parent_id {
  my ($self) = @_;
  return $self->{'parent_id'};
}
=head2 root_id

Description : Taxon ID of the root node for the taxonomy.
Return type : Int
=cut

sub root_id {
  my ($self) = @_;
  return $self->{'root_id'};
}
=head2 names 

Description : Hashref of names for this node. Hash keys are the class of name, and values are arrays of names (as you can have more than one name for each class)
Return type : hashref
=cut
sub names {
  my ($self) = @_;
  return $self->{'names'};
}

sub name {
  my ($self, $name_class) = @_;
  $name_class ||= 'scientific name';
  return $self->names()->{$name_class}->[0];
}
=head2 rank

Description : Taxonomic rank
Return type : String
=cut
sub rank {
  my ($self) = @_;
  return $self->{'rank'};
}
=head2 num_descendants

Description : Total number of descendants in the tree
Return type : Int
=cut

sub num_descendants {
  my ($self) = @_;
  return $self->{num_descendants};
}


=head2 dba

Description : Getter/setter for core database adaptor for this node
Argument    : (optional) Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor
Return type : Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor
=cut

sub dba {
  my ($self, $dba) = @_;
  if (defined $dba) {
	$self->{dba} = $dba;
  }
  return $self->{dba};
}

=head2 root

Description	  : Getter/setter for root node for this node (fetched lazily using adaptor)
Argument    : (optional) Bio::EnsEMBL::TaxonomyNode
Return type   : Bio::EnsEMBL::TaxonomyNode
=cut
sub root {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{root} = $arg;
  }
  if (!defined $self->{root}) {
	$self->{root} = $self->adaptor()->fetch_root($self);
  }
  return $self->{root};
}

=head2 parent

Description	  : Getter/setter for parent node for this node (fetched lazily using adaptor)
Argument      : (optional) Bio::EnsEMBL::TaxonomyNode
Return type   : Bio::EnsEMBL::TaxonomyNode
=cut

sub parent {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{parent} = $arg;
  }
  if (!defined $self->{parent}) {
	$self->{parent} = $self->adaptor()->fetch_parent($self);
  }
  return $self->{parent};
}

=head2 children

Description	  : Getter/setter for arrayref of child nodes for this node (fetched lazily using adaptor)
Argument      : (optional) Arrayref of Bio::EnsEMBL::TaxonomyNode
Return type   : Arrayref of Bio::EnsEMBL::TaxonomyNode
=cut

sub children {
  my ($self, $arg) = @_;
  if (defined $arg) {
	$self->{children} = $arg;
  }
  if (!defined $self->{children}) {
	$self->{children} = $self->adaptor()->fetch_children($self);
  }
  return $self->{children};
}

=head2 is_root

Description		: Returns 1 if this is a root node with no parents
Return type     : Int
=cut

sub is_root {
  my ($self) = @_;
  return $self->{root_id} == $self->{taxon_id};
}

=head2 is_leaf

Description		: Returns 1 if this is a leaf node with no children
Return type     : Int
=cut

sub is_leaf {
  my ($self) = @_;
  return $self->{num_descendants} == 0;
}

=head2 is_branch

Description		: Returns 1 if this is a branch node with more than one direct child
Return type     : Int
=cut

sub is_branch {
  my ($self) = @_;
  if (!defined $self->{is_branch}) {
	$self->{is_branch} = scalar(@{$self->children()}) > 1 ? 1 : 0;
  }
  return $self->{is_branch};
}

=head2 add_all_descendants 
Description		: Uses database to fetch all descendants for this node from database and assemble them into a tree
Return type     : None
=cut

sub add_all_descendants {
  my ($self, $child) = @_;
  $self->{children} = $self->adaptor()->add_descendants($self);
  return;
}

=head2 add_child 
Description		: Add child node (if not already present)
Argument        : Arrayref of Bio::EnsEMBL::TaxonomyNode
Return type     : None
=cut

sub add_child {
  my ($self, $child) = @_;
  if (!grep { $_->taxon_id() == $child->taxon_id() } @{$self->{children}}) {
	push @{$self->{children}}, $child;
  }
  return;
}

=head2 traverse_tree
Description 	: Walk the tree recursively, invoking the supplied subroutine on each node
Argument 		: Subroutine reference, accepting current node and depth
=cut

sub traverse_tree {
  my ($self, $closure, $depth) = @_;
  $depth ||= 0;
  $closure->($self, $depth);
  for my $child (@{$self->children()}) {
	$child->traverse_tree($closure, $depth + 1);
  }
  return;
}

=head2 count_leaves  
Description		: Counts all leaf or DBA nodes below this node
Argument        : (Optional) closure checking whether to count a node or not
Return type     : Int
=cut 

sub count_leaves {
  my ($self, $sub) = @_;
  $sub ||= sub {
	my ($node) = @_;
	return ($node->is_leaf() || (defined $node->dba() && scalar(@{$node->dba()}) > 0));
  };
  my $n = 0;
  $self->traverse_tree(
	sub {
	  my ($node, $depth) = @_;
	  $n += $sub->($node) ? 1 : 0;
	  return;
	});
  return $n;
}

=head2 distance_to_node
Description 	: Calculate the distance between this and the supplied node in steps via the closest common ancestor
Argument 		: Bio::EnsEMBL::TaxonomyNode
Return type		: Int
=cut

sub distance_to_node {
  my ($self, $node) = @_;
  return $self->adaptor()->distance_between_nodes($self, $node);
}

=head2 has_ancestor
Description : Test if the ancestors of this node include the supplied node
Argument : Putative ancestor
Return: 1 if the supplied node is an ancestor of this node
=cut

sub has_ancestor {
  my ($self,$node) = @_;
#	my $has_ancestor = 0;
#	if(!defined $self->{ancestors}) {
#		$self->{ancestors} = $self->adaptor()->fetch_ancestors($self);
#	}
#	for my $ancestor (@{$self->{ancestors}}) {
#		if($ancestor->taxon_id eq $node->taxon_id()) {
#			$has_ancestor = 1;
#			last;
#		}
#	}
#  return $has_ancestor;
#  
  return $self->adaptor()->node_has_ancestor($self,$node);
}

=head2 to_string
Description : Return simple string representation of node
Argument : (Optional) name_class to display (default is 'scientific name')
=cut

sub to_string {
  my ($self, $name_class) = @_;
  $name_class ||= 'scientific name';
  return $self->taxon_id() . '[' . $self->name() . ']';
}

=head2 to_tree_string
Description: Render tree as a string
=cut

sub to_tree_string {
  my ($self) = @_;
  my $str;
  $self->traverse_tree(
	sub {
	  my ($node, $depth) = @_;
	  $str .= ("." x $depth) . $node->to_string() . "\n";
	  return;
	});
  return $str;
}


1;

