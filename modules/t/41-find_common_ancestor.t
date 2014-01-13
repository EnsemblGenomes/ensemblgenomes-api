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
		
ok( defined $node_adaptor, 'Checking if the node adaptor is defined' );

my $n1 = $node_adaptor->fetch_by_taxon_id( 10 )
  || die "Could not retrieve node 10: $@";
ok( defined $n1,
	"Checking if the node 10 could be retrieved" );
is ($n1->taxon_id(),10,'Checking node ID is as expected');
diag($n1->to_string());

my $an1 = $node_adaptor->fetch_ancestor_by_rank($n1,"species");
diag("Species ancestor: ".$an1->to_string());

my $n2 = $node_adaptor->fetch_by_taxon_id( 11 )
  || die "Could not retrieve node 11: $@";
ok( defined $n2,
	"Checking if the node 11 could be retrieved" );
is ($n2->taxon_id(),11,'Checking node ID is as expected');
diag($n2->to_string());

my $n3 = $node_adaptor->fetch_by_taxon_id( 12 )
  || die "Could not retrieve node 12: $@";
ok( defined $n3,
	"Checking if the node 12 could be retrieved" );
is ($n3->taxon_id(),12,'Checking node ID is as expected');
diag($n3->to_string());

my $a1s = $node_adaptor->fetch_all_common_ancestors($n1,$n2);
diag "Common ancestors of ".$n1->to_string()." and ".$n2->to_string();
for my $a (@$a1s) {
	diag($a->to_string());
}
diag "Common ancestor of ".$n1->to_string()." and ".$n2->to_string();
my $a1 = $node_adaptor->fetch_common_ancestor($n1,$n2);
diag($a1->to_string());

my $a2s = $node_adaptor->fetch_all_common_ancestors($n2,$n3);
diag "Common ancestors of ".$n2->to_string()." and ".$n3->to_string();
for my $a (@$a2s) {
	diag($a->to_string());
}
diag "Common ancestor of ".$n2->to_string()." and ".$n3->to_string();
my $a2 = $node_adaptor->fetch_common_ancestor($n2,$n3);
diag($a2->to_string());

done_testing;
