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
use Data::Dumper;

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

my $gdba =
  Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new($dba);
ok(defined $gdba, "GenomeInfoAdaptor exists");

diag("Fetching all genome info with peptide compara");
my $mds  = $gdba->fetch_all_with_peptide_compara();
my $nAll = scalar @$mds;
diag("Fetched $nAll GenomeInfo");
ok($nAll > 0, "At least 1 GenomeInfo found");

my $md = $mds->[0];
diag("Found " . $md->species());
ok($md->has_peptide_compara() == 1, "has_peptide_compara set to 1");
# check expansion
ok(!defined $md->{compara}, "compara not yet expanded");
ok(defined $md->compara() && ref $md->compara() eq 'ARRAY',
   "compara now expanded");
my @comparas = grep {
  $_->method eq 'PROTEIN_TREES' &&
	$_->division() ne 'EnsemblPan'
} @{$md->compara()};
my $nComp = scalar(@comparas);
diag("Found $nComp protein_tree comparas");
is($nComp, 1, "numbers of compara");
my $is_found = 0;

for my $cmd (@{$comparas[0]->genomes()}) {
  if ($cmd eq $md) {
	$is_found = 1;
	last;
  }
}
is($is_found,
   1,
   "metadata " . $md->species() . " found in compara " .
	 $comparas[0]->method() . "/" . $comparas[0]->division());
	 
my $compara = $gdba->fetch_compara_by_dbID($comparas[0]->dbID());
is($compara->dbID(), $comparas[0]->dbID(), "Retrieval by dbID worked");

my $division = $compara->division();
my $method   = $compara->method();
$is_found = 0;
for my $c (@{$gdba->fetch_all_compara_by_division($division)}) {
  is($c->division(), $division, "Division $division retrieval correct");
  if ($c->dbID() == $compara->dbID()) {
	$is_found = 1;
  }
}
is($is_found, 1,
   "Retrieval by division $division found original entry");

$is_found = 0;
for my $c (@{$gdba->fetch_all_compara_by_method($method)}) {
  is($c->method(), $method, "Method $method retrieval correct");
  if ($c->dbID() == $compara->dbID()) {
	$is_found = 1;
  }
}
is($is_found, 1, "Retrieval by method $method found original entry");	 

diag("Fetching all genome info with pan compara");
my @mds = grep { $_->division() ne 'Ensembl' }
  @{$gdba->fetch_all_with_pan_compara()};
$nAll = scalar @mds;
diag("Fetched $nAll GenomeInfo");
ok($nAll > 0, "At least 1 GenomeInfo found");

$md = $mds[0];
diag("Found " . $md->species());
ok($md->has_pan_compara() == 1, "has_pan_compara set to 1");
ok(defined $md->compara() && ref $md->compara() eq 'ARRAY',
   "compara now expanded");
@comparas = grep {
  $_->method eq 'PROTEIN_TREES' &&
	$_->division() eq 'EnsemblPan'
} @{$md->compara()};
$nComp = scalar(@comparas);
diag("Found $nComp pan comparas");
is($nComp, 1, "numbers of compara");
$is_found = 0;

for my $cmd (@{$comparas[0]->genomes()}) {
  if ($cmd eq $md) {
	$is_found = 1;
	last;
  }
}
is($is_found,
   1,
   "metadata " . $md->species() . " found in compara " .
	 $comparas[0]->method() . "/" . $comparas[0]->division());

diag("Fetching all genome info with any compara");
$mds  = $gdba->fetch_all_with_compara();
$nAll = scalar @$mds;
diag("Fetched $nAll GenomeInfo");
ok($nAll > 0, "At least 1 GenomeInfo found");

$md = $mds->[0];
diag("Found " . $md->species());
ok(($md->has_peptide_compara() == 1 || $md->has_pan_compara() == 1 || $md->has_whole_genome_alignments()), "has_*_compara set to 1");


done_testing;
