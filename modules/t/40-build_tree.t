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

$conf = $conf->{tax_test};
my $dba =  Bio::EnsEMBL::DBSQL::DBAdaptor->new(
									  -user   => $conf->{user},
									  -pass   => $conf->{pass},
									  -dbname => $conf->{db},
									  -host   => $conf->{host},
									  -port   => $conf->{port},
									  -driver => $conf->{driver});
									  
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);

$conf->{taxon_id}=1;
		
ok( defined $node_adaptor, 'Checking if the node adaptor is defined' );
my $node = $node_adaptor->fetch_by_taxon_id( $conf->{taxon_id} )
  || die "Could not retrieve node $conf->{taxon_id}: $@";
ok( defined $node,
	"Checking if the node node $conf->{taxon_id} could be retrieved" );
#printf "Node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
is ($node->taxon_id(),$conf->{taxon_id},'Checking node ID is as expected');
diag($node->to_string());

# add descendants
$node_adaptor->add_descendants($node);
my $str = $node->to_tree_string();
diag($str);
ok(defined $str, "Testing string returned by tree traversal");
$node_adaptor->add_descendants($node);
my $str2 =  $node->to_tree_string();
diag($str2);
ok($str2 eq $str, "Testing string returned by tree traversal is still the same");

$node_adaptor->set_num_descendants($node);
$node->traverse_tree(sub {
	my ($node,$depth) = @_;
	print $node->to_string()." n=".$node->num_descendants()."\n";
	return;
});

is($node->num_descendants(),11,"Expected descendants");
is($node->count_leaves(),5,"Expected leaves");

done_testing;
