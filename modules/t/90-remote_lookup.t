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
use Bio::EnsEMBL::LookUp::RemoteLookUp;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Data::Dumper;

my $conf_file = 'db.conf';

my $conf = do $conf_file ||
  die "Could not load configuration from " . $conf_file;

$conf = $conf->{genome_info};

diag("Creating adaptor");
my $dbc =
  Bio::EnsEMBL::DBSQL::DBConnection->new(-USER   => $conf->{user},
										 -PORT   => $conf->{port},
										 -HOST   => $conf->{host},
										 -DBNAME => $conf->{db});
ok(defined $dbc, "Connection object exists");
isa_ok($dbc,'Bio::EnsEMBL::DBSQL::DBConnection');

my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(
														  -DBC => $dbc);
ok(defined $gdba, "Adaptor object exists");
isa_ok($gdba,'Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor');

diag("Creating helper");
print localtime . "\n";

my $helper =
  Bio::EnsEMBL::LookUp::RemoteLookUp->new(-USER    => $conf->{user},
										  -PORT    => $conf->{port},
										  -HOST    => $conf->{host},
										  -ADAPTOR => $gdba);

ok(defined $helper, "Helper object exists");
isa_ok($helper,'Bio::EnsEMBL::LookUp::RemoteLookUp');

# test basic functionality

my $name = "escherichia_coli_str_k_12_substr_mg1655";
my $info = $gdba->fetch_by_species($name);
ok(defined $info, "genome info found for $name");
isa_ok($info,'Bio::EnsEMBL::Utils::MetaData::GenomeInfo');
my $dba = $helper->genome_to_dba($info);
ok(defined $dba, "DBAdaptor built for $name");
isa_ok($dba,'Bio::EnsEMBL::DBSQL::DBAdaptor');

is($info->species_id(),$dba->species_id(),"Same species ID");
is($info->dbname(),$dba->dbc()->dbname(),"Same database");

my $dbas = $helper->get_all();
diag("Found " . scalar @$dbas);

my $taxid = 511145;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found " . scalar @$dbas);
is($dbas->[0]->get_MetaContainer()->get_taxonomy_id(),
   $taxid, "Taxonomy ID $taxid match");

my $pattern = "Escherichia.*";
$dbas = $helper->get_all_by_name_pattern($pattern);
diag("Found " . scalar @$dbas);
ok($dbas->[0]->species() =~ m/$pattern/i, "Name $pattern match");


$pattern = "escherichia_coli_str_k_12_substr_mg1655";
$dba    = $helper->get_by_name_exact($pattern);
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
