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

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('eg');
my $gdba  = $multi->get_DBAdaptor('info');
my $tax   = $multi->get_DBAdaptor('tax');
$gdba->taxonomy_adaptor($tax);

ok( defined $gdba, "GenomeInfoAdaptor exists" );

diag("Fetching all genome info");
my $mds  = $gdba->fetch_all();
my $nAll = scalar @$mds;
diag("Fetched $nAll GenomeInfo");
ok( $nAll > 0, "At least 1 GenomeInfo found" );

# get first division
my $division = $mds->[0]->division();
diag("Fetching division $division");
$mds = $gdba->fetch_all_by_division($division);
my $nDiv = scalar @$mds;
diag("Fetched $nDiv GenomeInfo for $division");
ok( $nDiv > 0, "At least 1 GenomeInfo found for $division" );
is( $mds->[0]->division(), $division, "Division matches $division" );

# get first species
my $species = $mds->[0]->species();
diag("Fetching species $species");
my $md = $gdba->fetch_by_species($species);
is( $md->species(), $species, "Species matches $species" );

# retrieve by taxid
my $taxid = $mds->[0]->taxonomy_id();
diag("Fetching taxonomy id $taxid");
$mds = $gdba->fetch_all_by_taxonomy_id($taxid);
is( $mds->[0]->taxonomy_id(), $taxid, "Taxonomy id matches $taxid" );

# retrieve by assembly ID
my $ass_id = $mds->[0]->assembly_id();
diag("Fetching assembly ID $ass_id");
$md = $gdba->fetch_by_assembly_id($ass_id);
is( $md->assembly_id(), $ass_id, "Assembly_id matches $ass_id" );

# check some fundamentals
diag("Checking for sequences");
ok( scalar( @{ $md->sequences() } ) > 0, "At least one sequence" );

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
ok(defined $genome->dbID(), "GenomeInfo has ID" );

diag("Retrieving a new GenomeInfo object");
my $genome2 = $gdba->fetch_by_name($genome->name()); 
ok($genome->dbID() eq $genome2->dbID(), "GenomeInfos have same ID" );

done_testing;
