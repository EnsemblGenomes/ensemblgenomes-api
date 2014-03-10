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
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;

my $conf_file = 'db.conf';
my $conf = do $conf_file ||
  die "Could not load configuration from " . $conf_file;
my $tconf = $conf->{genome_info};

diag("Connecting to genome info database");
my $dba =
  Bio::EnsEMBL::DBSQL::DBConnection->new(-user   => $tconf->{user},
										 -pass   => $tconf->{pass},
										 -dbname => $tconf->{db},
										 -host   => $tconf->{host},
										 -port   => $tconf->{port},
										 -driver => $tconf->{driver},);

my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new($dba);
ok(defined $gdba, "GenomeInfoAdaptor exists");

diag("Fetching all genome info");
my $mds = $gdba->fetch_all();
my $nAll = scalar @$mds;
diag("Fetched $nAll GenomeInfo");
ok($nAll>0, "At least 1 GenomeInfo found");

# get first division
my $division = $mds->[0]->division();
diag("Fetching division $division");
$mds = $gdba->fetch_by_division($division);
my $nDiv = scalar @$mds;
diag("Fetched $nDiv GenomeInfo for $division");
ok($nDiv>0, "At least 1 GenomeInfo found for $division");
ok($mds->[0]->division() eq $division, "Checking division matches $division");

# get first species
my $species = $mds->[0]->species();
diag("Fetching species $species");
my $md = $gdba->fetch_by_species($species);
ok($md->species() eq $species, "Checking species matches $species");

# retrieve by taxid
my $taxid = $mds->[0]->taxonomy_id();
diag("Fetching taxonomy id $taxid");
$mds = $gdba->fetch_by_taxonomy_id($taxid);
ok($mds->[0]->taxonomy_id() eq $taxid, "Checking taxonomy id matches $taxid");

# retrieve by assembly ID
my $ass_id = $mds->[0]->assembly_id();
diag("Fetching assembly ID $ass_id");
$md = $gdba->fetch_by_assembly_id($ass_id);
ok($md->assembly_id() eq $ass_id, "Checking assembly_id matches $ass_id");

done_testing;
