# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Test::More;

use Bio::EnsEMBL::TaxonomyNode;
use Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

$conf = $conf->{tax};

my $dba =
  Bio::EnsEMBL::DBSQL::DBAdaptor->new( -user   => $conf->{user},
									   -pass   => $conf->{pass},
									   -dbname => $conf->{db},
									   -host   => $conf->{host},
									   -port   => $conf->{port},
									   -driver => $conf->{driver} );

my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);
ok( defined $node_adaptor, 'Checking if the node adaptor is defined' );

## try simple leaf node for a species
my $leaves = $node_adaptor->fetch_all_by_taxon_ids( [511145] );

my $root = $node_adaptor->fetch_by_taxon_id(2);

# try all nodes for Ensembl bacteria
my $taxids = [];
open my $taxids_file, '<', 'taxids.txt';
while (<$taxids_file>) {
	chomp;
	push @$taxids, $_;
}
diag( "Taxids to check for: " . scalar @$taxids );
$leaves = $node_adaptor->fetch_all_by_taxon_ids($taxids);
for my $leaf (@{$leaves}) {
	$leaf->{dba} = [1];
}
diag( "Leaves found : " . scalar @$leaves );
$root = $node_adaptor->fetch_by_taxon_id(1);
$node_adaptor->build_pruned_tree( $root, $leaves );
diag( "Tree after:\n", $root->to_tree_string() );
my $sub = sub {
	my ( $node, $depth ) = @_;
	for ( my $i = 0; $i < scalar @$leaves; $i++ ) {
		if ( defined $leaves->[$i]
			 && $leaves->[$i]->taxon_id() == $node->taxon_id() )
		{
			delete $leaves->[$i];
			last;
		}
	}
	return;
};
$root->traverse_tree($sub);
is( scalar( grep { defined } @$leaves ), 0, "All expected found" );
diag( "Expected not found: ",
	  join( ' ', map { $_->taxon_id() } grep { defined } @$leaves ) );
my $cnt = 0;
for (1..10) {
	$node_adaptor->collapse_tree($root);
	#diag( "Tree collapse:\n", $root->to_tree_string() );
	if($cnt>0) {
		ok($cnt == $root->num_descendants(), "Retained same number of descendants");
	}
	$cnt = $root->num_descendants();
	print $cnt."/".$root->count_leaves()."\n";
}
done_testing;
