
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
 
=cut

package Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw( throw );
use Bio::EnsEMBL::Utils::Scalar qw( assert_ref );
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::TaxonomyNode;
use Data::Dumper;

use base qw( Bio::EnsEMBL::DBSQL::BaseAdaptor );

sub helper {
	my ($self) = @_;
	if ( !defined $self->{helper} ) {
		$self->{helper} =
		  Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->dbc() );
	}
	return $self->{helper};
}

sub mapper {
	my ($self) = @_;
	if ( !defined $self->{mapper} ) {
		$self->{mapper} = sub {
			my @row   = @{ shift @_ };
			my $value = shift;
			if ( !$value ) {
				$value =
				  Bio::EnsEMBL::TaxonomyNode->new( -TAXON_ID    => $row[0],
														-PARENT_ID   => $row[1],
														-RANK        => $row[2],
														-ROOT_ID     => $row[3],
														-LEFT_INDEX  => $row[4],
														-RIGHT_INDEX => $row[5],
														-ADAPTOR     => $self );
			}
			push @{ $value->names()->{ $row[6] } }, $row[7];
			return $value;
		};
	}
	return $self->{mapper};
}

my $base_sql =
q{select n.taxon_id, n.parent_id, n.rank, n.root_id, n.left_index, n.right_index,
   na.name_class, na.name
   from ncbi_taxa_node n 
   join ncbi_taxa_name na using (taxon_id)};

sub fetch_by_coredbadaptor {
	my ( $self, $core_dba ) = @_;
	# get taxid from core
	my $taxid = $core_dba->get_MetaContainer()->get_taxonomy_id();
	if ( !defined $taxid ) {
		throw(
			"Could not find taxonomy ID for database " . $core_dba->species() );
	}
	my $node = $self->fetch_by_taxon_id($taxid);
	if ($node) {
		push @{$node->dba()},$core_dba;
	}
	return $node;
}

sub fetch_by_taxon_id {
	my ( $self, $taxon_id ) = @_;
	my $node =
	  $self->helper()->execute_into_hash(
									 -SQL => $base_sql . q{ where taxon_id = ?},
									 -CALLBACK => $self->mapper(),
									 -PARAMS   => [$taxon_id] );
	return $node->{$taxon_id};
}

sub fetch_all_by_taxon_ids {
	my ( $self, $taxon_ids ) = @_;
	my $list = join ',', @$taxon_ids;
	my $node =
	  $self->helper()->execute_into_hash(
							 -SQL => $base_sql . qq{ where taxon_id in ($list)},
							 -CALLBACK => $self->mapper() );
	return [ values %{$node} ];
}

sub fetch_all_by_rank {
	my ( $self, $rank ) = @_;
	my $node =
	  $self->helper()->execute_into_hash(-SQL => $base_sql . q{ where rank = ?},
										 -CALLBACK => $self->mapper(),
										 -PARAMS   => [$rank] );
	return [ values %{$node} ];
}

sub fetch_all_by_name {
	my ( $self, $name ) = @_;
	my $node =
	  $self->helper()->execute_into_hash(
		 -SQL => $base_sql
		   . q{ join ncbi_taxa_name nan using (taxon_id) where nan.name like ?},
		 -CALLBACK => $self->mapper(),
		 -PARAMS   => [$name] );
	return [ values %{$node} ];
}

sub fetch_all_by_name_and_class {
	my ( $self, $name, $class ) = @_;
	my $node =
	  $self->helper()->execute_into_hash(
		-SQL => $base_sql
		  . q{ join ncbi_taxa_name nan using (taxon_id) where nan.name like ? and nan.name_class like ?},
		-CALLBACK => $self->mapper(),
		-PARAMS   => [ $name, $class ] );
	return [ values %{$node} ];
}

sub fetch_all_by_name_and_rank {
	my ( $self, $name, $rank ) = @_;
	my $node =
	  $self->helper()->execute_into_hash(
		-SQL => $base_sql
		  . q{ join ncbi_taxa_name nan using (taxon_id) where nan.name like ? and n.rank = ?},
		-CALLBACK => $self->mapper(),
		-PARAMS   => [ $name, $rank ] );
	return [ values %{$node} ];
}

sub fetch_parent {
	my ( $self, $child ) = @_;
	$child = $self->_get_node($child);
	my $node =
	  $self->helper()->execute_into_hash(
									 -SQL => $base_sql . q{ where taxon_id = ?},
									 -CALLBACK => $self->mapper(),
									 -PARAMS   => [ $child->parent_id() ] );
	return $node->{ $child->parent_id() };
}

sub fetch_root {
	my ( $self, $child ) = @_;
	$child = $self->_get_node($child);
	my $node =
	  $self->helper()->execute_into_hash(
									 -SQL => $base_sql . q{ where taxon_id = ?},
									 -CALLBACK => $self->mapper(),
									 -PARAMS   => [ $child->root_id() ] );
	return $node->{ $child->root_id() };
}

sub fetch_children {
	my ( $self, $parent ) = @_;
	my $node =
	  $self->helper()->execute_into_hash(
									-SQL => $base_sql . q{ where parent_id = ?},
									-CALLBACK => $self->mapper(),
									-PARAMS   => [ _get_node_id($parent)  ] );
	return [ sort { $a->num_descendants() <=> $b->num_descendants() }
			 values %{$node} ];
}

sub fetch_all_common_ancestors {
	my ($self,$n1,$n2) = @_;
	my $anc = $self->fetch_ancestors($n1);
	my %n1h = map {$_->taxon_id() => $_} @$anc;
	my $common_ancestors = [];
	for my $n2n (@{$self->fetch_ancestors($n2)}) {
		if(defined $n1h{$n2n->taxon_id()}) {
			push @$common_ancestors, $n2n;
		}
	}	
	return [ sort { $a->num_descendants() <=> $b->num_descendants() } @{$common_ancestors} ];
}

sub fetch_common_ancestor {
	my ($self,$n1,$n2) = @_;
	my $anc = $self->fetch_all_common_ancestors($n1,$n2);
	return scalar(@$anc)>0?$anc->[0]:undef;
}

sub fetch_ancestor_by_rank {
	my ($self,$n1,$rank) = @_;
	return $n1 if($n1->rank() eq $rank);
	my $anc;
	for my $a (@{$self->fetch_ancestors($n1)}) {
		if($a->rank() eq $rank) {
			$anc = $a;
			last;
		}
	}
	return $anc;
}

sub _get_node {
   my ($self,$node) = @_;
	if(ref($node) eq 'Bio::EnsEMBL::TaxonomyNode') {
	    return $node;
	} else {
	    return $self->fetch_by_taxon_id($node);
	} 
}

sub _get_node_id {
    my ($node) = @_;
    my $node_id;
	if(ref($node) eq 'Bio::EnsEMBL::TaxonomyNode') {
	    return $node->taxon_id();
	} else {
	    return $node;
	}
}

sub fetch_descendants {
	my ( $self, $node ) = @_;
	
	my $nodes = $self->helper()->execute_into_hash(
		-SQL => $base_sql . q{ join ncbi_taxa_node parent 
		  	on (n.left_index between parent.left_index and parent.right_index and n.taxon_id<>parent.taxon_id)
			where parent.taxon_id=?},
		-CALLBACK => $self->mapper(),
		-PARAMS   => [ _get_node_id($node) ] );
	return [ sort { $a->num_descendants() <=> $b->num_descendants() }
			 values %{$nodes} ];
}

sub fetch_leaf_nodes {
	my ( $self, $node ) = @_;
	my $nodes = $self->helper()->execute_into_hash(
		-SQL => $base_sql . q{ join ncbi_taxa_node parent 
		  	on (n.left_index between parent.left_index and parent.right_index and n.taxon_id<>parent.taxon_id)
			where parent.taxon_id=? and n.right_index=n.left_index+1},
		-CALLBACK => $self->mapper(),
		-PARAMS   => [ _get_node_id($node) ] );
	return [ values %{$nodes} ];
}

sub fetch_ancestors {
	my ( $self, $node ) = @_;
	my $nodes = $self->helper()->execute_into_hash(
		-SQL => $base_sql . q{ join ncbi_taxa_node child
									 		on (child.left_index between n.left_index and n.right_index and n.taxon_id<>child.taxon_id)
											where child.taxon_id=?},
		-CALLBACK => $self->mapper(),
		-PARAMS   => [ _get_node_id($node)  ] );
	return [ sort {$a->num_descendants() <=> $b->num_descendants() }
			 values %{$nodes} ];
}

sub fetch_descendants_offset {
    my ( $self, $node, $offset ) = @_;
    $offset ||= 1;
    $node = $self->_get_node($node);
    while($offset-- > 0) {
        $node = $self->fetch_parent($node);
        throw "No parent found for offset query" unless (defined $node);
    }
    return $self->fetch_descendants($node);
}

sub add_descendants {
	my ( $self, $node ) = @_;
	# hash nodes
	$self->associate_nodes( [ $node, @{ $self->fetch_descendants($node) } ] );
	return;
}

sub associate_nodes {
	my ( $self, $nodes ) = @_;
	# sort by left index
	my @nodes     = sort { $a->{left_index} <=> $b->{left_index} } @$nodes;
	my $root      = $nodes[0];
	my $last_node = undef;
	# walk through them finding parents which enclose them
	# reset parent/child relationships
	for my $node (@nodes) {
		$node->{parent_id} = 0;
		$node->{parent}    = undef;
		$node->{children}  = [];
		if ( defined $last_node ) {
			my $parent = $self->_get_parent_by_index( $node, $last_node );
			if ( defined $parent ) {
				$node->{parent_id} = $parent->taxon_id();
				$node->{parent}    = $parent;
				push @{ $parent->{children} }, $node;
			}
		}
		$node->{root_id} = $root->taxon_id();
		$node->{root}    = $root;
		$last_node       = $node;
	}
	$self->set_num_descendants($root);
	return $root;
} ## end sub associate_nodes

sub set_num_descendants {
	my ( $self, $node ) = @_;
	$node->{num_descendants} = 0;
	for my $child ( @{ $node->children() } ) {
		$node->{num_descendants} += 1 + $self->set_num_descendants($child);
	}
	return $node->num_descendants();
}

sub _get_parent_by_index {
	my ( $self, $leaf_node, $node ) = @_;
	my $parent;
	if (    $node->{left_index} < $leaf_node->{left_index}
		 && $node->{right_index} > $leaf_node->{right_index} )
	{
		$parent = $node;
	} elsif ( defined $node->{parent} ) {
		$parent = $self->_get_parent_by_index( $leaf_node, $node->{parent} );
	}
	return $parent;
}

sub build_pruned_tree {
	my ( $self, $root, $leaf_nodes ) = @_;
	# get the test set and winnow
	my @nodes =
	  grep { $_->taxon_id() != $root->taxon_id() }
	  @{ $self->_restrict_set( $leaf_nodes, $self->fetch_descendants($root) ) };
	$self->associate_nodes( [ $root, @nodes ] );
	return;
}

sub collapse_tree {
	my ( $self, $root, $check ) = @_;
	my @nodes;
	$check ||= sub {
		my ($node) = @_;
		return (    $node->taxon_id() eq $root->taxon_id()
				 || ($node->dba() && scalar(@{$node->dba()}) > 0)
				 || scalar(@{$node->children()})!=1
				 || scalar( @{ $node->parent()->children() })>1 );
	};
	$root->traverse_tree(
		sub {
			my ( $node, $depth ) = @_;
			if ( $check->($node) ) {
				push @nodes, $node;
			}
			return;
		} );
	$self->associate_nodes( [ $root, @nodes ] );
	return;
}

sub _build_node_array {
	my ( $self, $leaf_nodes ) = @_;
	my $array;
	my $lmin = 0;
	my $rmax = 0;
	for my $node (@$leaf_nodes) {
		if ( !$node->{left_index} || !$node->{right_index} ) {
			print Dumper($node);
			throw "Indices not set for " . $node->to_string();
		}
		$array->[ $node->{left_index} ]  = 1;
		$array->[ $node->{right_index} ] = 1;
		$lmin =
		  ( $lmin == 0 || $node->{left_index} < $lmin )
		  ? $node->{left_index}
		  : $lmin;
		$rmax = ( $rmax < $node->{right_index} ) ? $node->{right_index} : $rmax;
	}
	return [ $array, $lmin, $rmax ];
}

sub _restrict_set {
	my ( $self, $leaf_nodes, $input_set ) = @_;
	# build sparse array
	my ( $node_array, $lmin, $rmax ) =
	  @{ $self->_build_node_array($leaf_nodes) };
	# hash leaf nodes by taxon_id to allow replacement
	my %leaves = map { $_->taxon_id() => $_ } @$leaf_nodes;
	my @output_set;
	# iterate over everything in the min/max range
	for my $node (
		grep {
			     $_->{right_index} >= $lmin
			  || $_->{left_index} <= $rmax
		} @$input_set )
	{
		my $leaf = $leaves{ $node->taxon_id() };
		if ( defined $leaf ) {
			push @output_set, $leaf;
		} else {
			for ( my $i = $node->{left_index};
				  $i <= $node->{right_index}; $i++ )
			{
				if ( $node_array->[$i] ) {
					push @output_set, $node;
					last;
				}
			}
		}
	}
	return \@output_set;
} ## end sub _restrict_set

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor

=head1 SYNOPSIS

#create an adaptor (Registry cannot be used currently)
my $tax_dba =  Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor->new(
									  -user   => $tax_user,
									  -pass   => $tax_pass,
									  -dbname => $tax_db,
									  -host   => $tax_host,
									  -port   => $tax_port);									  
my $node_adaptor = $tax_dba->get_TaxonomyNodeAdaptor();
# get a node for an ID
my $node = $node_adaptor->fetch_by_taxon_id(511145);
# print some info
printf "Node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
# Finding ancestors
my @lineage = @{$node_adaptor->fetch_ancestors($node)};
for my $node (@lineage) {
    printf "Node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
}

=head1 DESCRIPTION

A database adaptor allowing access to the nodes of the NCBI taxonomy. It is currently managed independently of the registry:
my $tax_dba =  Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor->new(
									  -user   => $tax_user,
									  -pass   => $tax_pass,
									  -dbname => $tax_db,
									  -host   => $tax_host,
									  -port   => $tax_port);
									  									  
my $node_adaptor = $tax_dba->get_TaxonomyNodeAdaptor();
# or alternatively
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($tax_dba);

The TaxonomyNodeAdaptor handles TaxonomyNode objects, which represent nodes in the NCBI taxonomy

There are two main practical uses for the :
1. Accessing the taxonomy database to find species of interest and to then find those within the ENA databases e.g. to find all 
descendants of the node representing Escherichia coli:
	my $node = $node_adaptor->fetch_by_taxon_id(562);
	for my $child (@{$node_adaptor->fetch_descendants($node)}) {
		my $dbas = $helper->get_all_by_taxon_id($node->taxon_id())
		if(defined $dbas) {
			for my $dba (@{$dbas}) {
				# do something with the $dba
			}
		}
	}

2. Placing ENA species into a taxonomic hierarchy and manipulating that hierarchy (mainly for use in the web interface)
	# iterate over all dbas from a registry or ENARegistryHelper
	for my $dba (@{$helper->get_all_DBAdaptors()}) {
		my $node = $node_adaptor->fetch_by_coredbadaptor($dba);
		# add the node to a hash set of leaf nodes if not already there
		if ( $leaf_nodes->{ $node->taxon_id() } ) {
			$node = $leaf_nodes->{ $node->taxon_id() };
		} else {
			$leaf_nodes->{ $node->taxon_id() } = $node;
		}
		# attach the DBA to the node
		push @{$node->dba()}, $dba;
	}
	my @leaf_nodes = values(%$leaf_nodes);
	# get the root of the tree
	my $root = $node_adaptor->fetch_by_taxon_id(1);
	# get rid of all branches of the taxonomy that don't involve a node from the dba
	$node_adaptor->build_pruned_tree( $root, \@leaf_nodes );
	# collapse 
	$node_adaptor->collapse_tree($root);

Common tasks involve

=head1 ATTRIBUTES

=head2 helper

=head2 mapper

=head1 SUBROUTINES/METHODS

=head2 fetch_by_taxon_id

Description : Fetch a single node corresponding to the supplied taxon ID.
Argument    : Int
Return type : Bio::EnsEMBL::TaxonomyNode

=head2 fetch_by_coredbadaptor

Description : Fetch a single node corresponding to the taxonomy ID found in the supplied Ensembl DBAdaptor
Argument    : Bio::EnsEMBL::DBSQL::DBAdaptor
Return type : Bio::EnsEMBL::TaxonomyNode

=head2 fetch_all_by_taxon_ids

Description : Fetch an array of nodes corresponding to the supplied taxonomy IDs
Argument    : Arrayref of Int
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_all_by_name

Description : Fetch an array of nodes which have a name LIKE the supplied String
Argument    : Name as String (can contain SQL wildcards)
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_all_by_name_and_class

Description : Fetch an array of nodes which have a name and name class LIKE the supplied Strings
Argument    : Name as String (can contain SQL wildcards)
Argument    : Name class as String (can contain SQL wildcards)
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_all_by_rank

Description : Fetch an array of nodes which have the supplied rank
Argument    : String
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_all_by_name_and_rank

Description : Fetch an array of nodes which have the supplied rank and a name LIKE the supplied String
Argument    : Name as String (can contain SQL wildcards)
Argument    : Rank as String
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_parent
 
Description : Fetch a single node corresponding to the parent of the node
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Return type : Bio::EnsEMBL::TaxonomyNode

=head2 fetch_root

Description : Fetch a single node corresponding to the root of the supplied node
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Return type : Bio::EnsEMBL::TaxonomyNode

=head2 fetch_children

Description : Fetch an array of nodes for which the parent is the supplied node
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_descendants

Description : Fetch an array of nodes below the supplied node on the tree
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_descendants_offset

Description : Fetch an array of nodes below the node the specified number of levels on the tree above the specified node
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Argument    : offset (number of rows to move up tree before getting descendants - default is 1)
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_leaf_nodes

Description : Fetch an array of nodes which are the leaves below the supplied node on the tree
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 fetch_ancestors

Description : Fetch an array of nodes which are above the supplied node on the tree (ordered ascending up the tree)
Argument    : Bio::EnsEMBL::TaxonomyNode or ID of desired node
Return type : Arrayref of Bio::EnsEMBL::TaxonomyNode

=head2 add_descendants

Description : Fetch descendants for the supplied node and assemble into a tree
Argument    : Bio::EnsEMBL::TaxonomyNode
Return type : None

=head2 associate_nodes

Description : Associate the supplied nodes into a tree based on left/right indices and return the root node
Argument    : Arrayref of Bio::EnsEMBL::TaxonomyNode
Return type : Bio::EnsEMBL::TaxonomyNode

=head2 set_num_descendants

Description : Traverse the supplied tree setting number of descendants based on current tree structure
Argument    : Bio::EnsEMBL::TaxonomyNode
Return type : None

=head2 build_pruned_tree
Description : Restrict supplied tree by list of key leaf nodes
Argument    : Bio::EnsEMBL::TaxonomyNode
Argument    : Array ref of Bio::EnsEMBL::TaxonomyNode
Return type : None

=head2 collapse_tree
Description : Remove all nodes from tree that do not fit the required criteria. By default, these are not branch points, the root node, leaf nodes or nodes with database adaptors.
Argument    : Bio::EnsEMBL::TaxonomyNode
Argument    : Array ref of Bio::EnsEMBL::TaxonomyNode
Argument    : (Optional) Subroutine reference which is used to define whether to retain a node
Return type : None

=head1 INTERNAL METHODS

=head2 _get_parent_by_index
Description: Find the parent of a node, initially based on left/right index to find direct parent, and then by recursion through parents to work back to the closest common ancestor.
Argument: Current node
Argument: Prospective parent
Return type: Bio::EnsEMBL::TaxonomyNode

=head2 _build_node_array
Description: Build a sparse array based on left/right indices of a set of nodes to allow speedy lookup
Argument: Arrayref of Bio::EnsEMBL::TaxonomyNode
Return type: Arrayref containing arrayref of 1/0 by left/right, min left index, max right index

=head2 _restrict_set
Description: Restrict the input set to those needed to build a tree including all members of the leaf set
Argument: Arrayref of Bio::EnsEMBL::TaxonomyNode (leaf set)
Argument: Arrayref of Bio::EnsEMBL::TaxonomyNode (input set)
Return: Arrayref of Bio::EnsEMBL::TaxonomyNode

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut
