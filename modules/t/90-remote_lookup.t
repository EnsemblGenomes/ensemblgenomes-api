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

use Bio::EnsEMBL::Test::MultiTestDB;

my $multi     = Bio::EnsEMBL::Test::MultiTestDB->new('eg');
my $gdba = $multi->get_DBAdaptor('info');
my $tax = $multi->get_DBAdaptor('tax');
$gdba->taxonomy_adaptor($tax);

ok( defined $gdba, "Adaptor object exists" );

my $helper = Bio::EnsEMBL::LookUp::RemoteLookUp->new(
							 -USER    => $gdba->{dbc}->user(),
							 -PASS    => $gdba->{dbc}->pass(),
							 -PORT    => $gdba->{dbc}->port(),
							 -HOST    => $gdba->{dbc}->host(),
							 -ADAPTOR => $gdba );

ok( defined $helper, "Helper object exists" );
isa_ok( $helper, 'Bio::EnsEMBL::LookUp::RemoteLookUp' );

diag("Loading a new core");
# try to add a new GenomeInfo object and retrieve it again
my $ecoli = Bio::EnsEMBL::Test::MultiTestDB->new('escherichia_coli');
my $dba   = $ecoli->get_DBAdaptor('core');
ok( defined $dba, "DBAdaptor exists" );

diag("Creating a new GenomeInfo object");
my $genome =
  Bio::EnsEMBL::Utils::MetaData::GenomeInfo->new(
  -name    => $dba->species(),
  -species    => $dba->species(),
  -species_id => $dba->species_id(),
  -taxonomy_id => $dba->get_MetaContainer()->get_taxonomy_id(),
  -division   => $dba->get_MetaContainer()->get_division() || 'Ensembl',
  -assembly_name   => $dba->get_MetaContainer()->single_value_by_key('assembly.name'),
  -assembly_level   => 'spirit',
  -genebuild => $dba->get_MetaContainer()->single_value_by_key('genebuild.version'),
  -dbname     => $dba->dbc()->dbname() );
  $genome->base_count(1664);
ok( defined $genome, "GenomeInfo exists" );
ok(! defined $genome->dbID(), "GenomeInfo has no ID" );
  
diag("Storing a new GenomeInfo object");
$gdba->store($genome);

# test basic functionality

my $name = $dba->species();
my $info = $gdba->fetch_by_species($name);
ok( defined $info, "genome info found for $name" );
isa_ok( $info, 'Bio::EnsEMBL::Utils::MetaData::GenomeInfo' );
$dba = $helper->genome_to_dba($info);
ok( defined $dba, "DBAdaptor built for $name" );
isa_ok( $dba, 'Bio::EnsEMBL::DBSQL::DBAdaptor' );

is( $info->species_id(), $dba->species_id(),    "Same species ID" );
is( $info->dbname(),     $dba->dbc()->dbname(), "Same database" );

my $dbas = $helper->get_all();
diag( "Found " . scalar @$dbas );

my $taxid = 511145;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag( "Found " . scalar @$dbas );
is( $dbas->[0]->get_MetaContainer()->get_taxonomy_id(),
	$taxid, "Taxonomy ID $taxid match" );

my $pattern = "Escherichia.*";
$dbas = $helper->get_all_by_name_pattern($pattern);
diag( "Found " . scalar @$dbas );
ok( $dbas->[0]->species() =~ m/$pattern/i, "Name $pattern match" );

$pattern = "escherichia_coli_str_k_12_substr_mg1655";
$dba     = $helper->get_by_name_exact($pattern);
is( $dba->species(), $pattern, "Name $pattern match" );

my $acc = "U00096";
($dba) = $helper->get_all_by_accession($acc);
ok( defined $dba, "Accession $acc match" );

$acc = "GCA_000005845";
$dba = $helper->get_by_assembly_accession($acc);
ok( defined $dba, "Accession $acc match" );

my $taxids = $helper->get_all_taxon_ids();
isa_ok( $taxids, 'ARRAY' );
ok( scalar(@$taxids) > 1000, "Taxids found" );

my $gcs = $helper->get_all_assemblies();
isa_ok( $gcs, 'ARRAY' );
ok( scalar(@$gcs) > 1000, "Assemblies found" );
my $vgcs = $helper->get_all_versioned_assemblies();
isa_ok( $vgcs, 'ARRAY' );
ok( scalar(@$vgcs) > 1000, "Versioned assemblies found" );

done_testing;
