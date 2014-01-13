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

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

$conf = $conf->{ena};
diag("Loading dbs into registry");
Bio::EnsEMBL::LookUp->register_all_dbs( $conf->{host},
	   $conf->{port}, $conf->{user}, $conf->{pass}, $conf->{db});
	   
diag("Creating helper");
print localtime."\n";

my $helper = Bio::EnsEMBL::LookUp->new(-CLEAR_CACHE => 1);
print localtime."\n";
ok(defined $helper, "Helper object exists");
ok(-e $helper->cache_file(),"Checking for cache");
print localtime."\n";
#my $dbas = $helper->registry()->get_all_DBAdaptors();
my $dbas = $helper->get_all();
diag("Found ".scalar @$dbas);

my $taxid= 511145;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found ".scalar @$dbas);
is($dbas->[0]->get_MetaContainer()->get_taxonomy_id(),$taxid,"Taxonomy ID $taxid match");

my $pattern = "Escherichia.*";
$dbas = $helper->get_all_by_name_pattern($pattern);
diag("Found ".scalar @$dbas);
ok($dbas->[0]->species()=~m/$pattern/i,"Name $pattern match");

diag("Creating new helper from cache");
$helper->registry()->clear();
$helper = Bio::EnsEMBL::LookUp->new();
print localtime."\n";
ok(defined $helper, "Helper object exists");
diag("Clearing cache");
$helper->clear_cache();

$dbas = $helper->registry()->get_all_DBAdaptors();
diag("Found ".scalar @$dbas);

$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found ".scalar @$dbas);
is($dbas->[0]->get_MetaContainer()->get_taxonomy_id(),$taxid,"Taxonomy ID $taxid match");

$dbas = $helper->get_all_by_name_pattern($pattern);
diag("Found ".scalar @$dbas);
ok($dbas->[0]->species()=~m/$pattern/i,"Name $pattern match");

$pattern = "escherichia_coli_str_k_12_substr_mg1655";
$dbas = $helper->get_by_name_exact($pattern);
diag("Found ".scalar @$dbas);
ok($dbas->[0]->species()=~m/$pattern/i,"Name $pattern match");

my $acc = "U00096";
my ($dba) = $helper->get_all_by_accession($acc);
ok(defined $dba,"Accession $acc match");

$acc = "GCA_000005845";
$dba = $helper->get_by_assembly_accession($acc);
ok(defined $dba,"Accession $acc match");

my $taxids = $helper->get_all_taxon_ids();
isa_ok( $taxids, 'ARRAY' );
ok(scalar(@$taxids)>4000,"Taxids found");

my $accs = $helper->get_all_accessions();
isa_ok( $accs, 'ARRAY' );
ok(scalar(@$accs)>100000,"Accessions found");
my $vaccs = $helper->get_all_versioned_accessions();
isa_ok( $vaccs, 'ARRAY' );
ok(scalar(@$vaccs)>100000,"Versioned ccessions found");

my $gcs = $helper->get_all_assemblies();
isa_ok( $gcs, 'ARRAY' );
ok(scalar(@$gcs)>4000,"Assemblies found");
my $vgcs = $helper->get_all_versioned_assemblies();
isa_ok( $vgcs, 'ARRAY' );
ok(scalar(@$vgcs)>4000,"Versioned assemblies found");

$helper->write_registry_to_file("reg.json");

done_testing;
