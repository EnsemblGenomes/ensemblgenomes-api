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

# get matching names
my @nodes = @{$node_adaptor->fetch_all_by_name($conf->{name})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name matches found');

@nodes = @{$node_adaptor->fetch_all_by_name_and_class($conf->{name},$conf->{name_class})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name/class matches found');

@nodes = @{$node_adaptor->fetch_all_by_rank($conf->{rank})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name/rank matches found');

@nodes = @{$node_adaptor->fetch_all_by_name_and_rank($conf->{name},$conf->{rank})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name/rank matches found');

done_testing;
