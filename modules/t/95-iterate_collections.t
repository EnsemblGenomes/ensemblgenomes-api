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
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Data::Dumper;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

my $helper = Bio::EnsEMBL::LookUp->new(-URL=>$conf->{ena_url},-NO_CACHE=>1);

ok(defined $helper, "Helper object from url exists");

my $dbnames = $helper->get_all_dbnames();
cmp_ok(scalar @$dbnames, ">", 1, "get_all_dbnames");

my $dbas = $helper->get_all_by_dbname($dbnames->[0]);
cmp_ok(scalar @$dbas, ">", 1, "get_all_by_dbname");

done_testing;
