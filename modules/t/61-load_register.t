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
use Bio::EnsEMBL::LookUp::LocalLookUp;

my $helper = Bio::EnsEMBL::LookUp::LocalLookUp->new(-FILE=>"reg.json",-NO_CACHE=>1);
ok(defined $helper, "Helper object from file exists");

my $dbas = $helper->get_all();
diag("Found ".scalar @$dbas);
my $dbas2 = $helper->registry()->get_all_DBAdaptors();
ok(scalar @$dbas == scalar @$dbas2,"Expected number of DBAs in registry and helper");
my $taxid= 388919;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found ".scalar @$dbas);
is($dbas->[0]->get_MetaContainer()->get_taxonomy_id(),$taxid,"Taxonomy ID $taxid match");

my $pattern = "Escherichia.*";
$dbas = $helper->get_all_by_name_pattern($pattern);
diag("Found ".scalar @$dbas);
ok($dbas->[0]->species()=~m/$pattern/i,"Name $pattern match");

$helper->write_registry_to_file("reg2.json");
diag("Wrote to file");

done_testing;
