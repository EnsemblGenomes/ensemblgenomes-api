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
my $dba =  Bio::EnsEMBL::DBSQL::DBAdaptor->new(
									  -user   => $conf->{user},
									  -pass   => $conf->{pass},
									  -dbname => $conf->{db},
									  -host   => $conf->{host},
									  -port   => $conf->{port},
									  -driver => $conf->{driver});
									  
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);
		
ok( defined $node_adaptor, 'Checking if the node adaptor is defined' );

my $node1 = $node_adaptor->fetch_by_taxon_id(208964); 
ok( defined $node1, 'Checking if the node for 208964 is defined' );
my $node2 = $node_adaptor->fetch_by_taxon_id(83331);
ok( defined $node2, 'Checking if the node for 83331 is defined' );

my $d1 = $node_adaptor->distance_between_nodes($node1, $node2);
is( $d1, 18, 'Checking distance between taxons is as expected');

my $d2 = $node_adaptor->distance_between_nodes($node2, $node1);
is( $d2, 18, 'Checking distance between taxons in reverse is as expected');

my $d3 = $node_adaptor->distance_between_nodes($node2, $node2);
is( $d3, 0, 'Checking distance between same taxons is as expected');

$d1 = $node1->distance_to_node($node2);
is( $d1, 18, 'Checking distance between taxons is as expected using the object method');

$d2 = $node2->distance_to_node($node1);
is( $d2, 18, 'Checking distance between taxons in reverse is as expected using the object method');

$d3 = $node2->distance_to_node($node2);
is( $d3, 0, 'Checking distance between same taxons is as expected using the object method');

done_testing;
