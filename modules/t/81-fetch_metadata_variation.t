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
use Bio::EnsEMBL::Test::MultiTestDB;

my $multi     = Bio::EnsEMBL::Test::MultiTestDB->new('eg');
my $gdba = $multi->get_DBAdaptor('info');
my $tax = $multi->get_DBAdaptor('tax');
$gdba->taxonomy_adaptor($tax);
ok(defined $gdba, "GenomeInfoAdaptor exists");

diag("Fetching all genome info");
my $mds = $gdba->fetch_all_with_variation();
my $nAll = scalar @$mds;
diag("Fetched $nAll GenomeInfo");
ok($nAll>0, "At least 1 GenomeInfo found");

my $md = $mds->[0];
ok($md->has_variations() == 1, "has_variations set to 1");
# check expansion
ok(!defined $md->{variations}, "variations not yet expanded");
ok(defined $md->variations() && ref $md->variations() eq 'HASH', "variations now expanded");
ok(scalar(keys %{$md->variations()})>0,"variations is a hashref with at least one key");

done_testing;
