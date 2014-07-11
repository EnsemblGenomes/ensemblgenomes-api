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
use Bio::EnsEMBL::LookUp;

diag("Creating default adaptor");
# test using default LookUp constructor
my $helper =
  Bio::EnsEMBL::LookUp->new();

ok(defined $helper, "Helper object exists");
isa_ok($helper,'Bio::EnsEMBL::LookUp');

# test basic functionality
my $dbas = $helper->get_all();
diag("Found " . scalar @$dbas);

my $taxid = 511145;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found " . scalar @$dbas. " DBAs with taxid $taxid");
is($dbas->[0]->get_MetaContainer()->get_taxonomy_id(),
   $taxid, "Taxonomy ID $taxid match");

my $pattern = "Escherichia.*";
$dbas = $helper->get_all_by_name_pattern($pattern);
diag("Found " . scalar @$dbas);
ok($dbas->[0]->species() =~ m/$pattern/i, "Name $pattern match");


$pattern = "escherichia_coli_str_k_12_substr_mg1655";
my $dba    = $helper->get_by_name_exact($pattern);
is($dba->species(), $pattern, "Name $pattern match");

my $acc = "U00096";
($dba) = $helper->get_all_by_accession($acc);
ok(defined $dba, "Accession $acc match");

$acc = "GCA_000005845";
$dba = $helper->get_by_assembly_accession($acc);
ok(defined $dba, "Accession $acc match");

my $taxids = $helper->get_all_taxon_ids();
isa_ok($taxids, 'ARRAY');
ok(scalar(@$taxids) > 4000, "Taxids found");

my $gcs = $helper->get_all_assemblies();
isa_ok($gcs, 'ARRAY');
ok(scalar(@$gcs) > 4000, "Assemblies found");
my $vgcs = $helper->get_all_versioned_assemblies();
isa_ok($vgcs, 'ARRAY');
ok(scalar(@$vgcs) > 4000, "Versioned assemblies found");

done_testing;
