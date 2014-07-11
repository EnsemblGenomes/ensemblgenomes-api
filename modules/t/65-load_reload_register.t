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
use Bio::EnsEMBL::Registry;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

my $helper = Bio::EnsEMBL::LookUp::LocalLookUp->new(-URL=>$conf->{ena_url},-NO_CACHE=>1);

ok(defined $helper, "Helper object from url exists");

my $dbas = $helper->get_all();
diag("Found ".scalar @$dbas);

    Bio::EnsEMBL::Registry->load_registry_from_db(
      -host    => $conf->{ena}{host},
      -user    => $conf->{ena}{user},
      -port    => $conf->{ena}{port},
      -db_version=>70

    );

my $dbas3 = $helper->registry()->get_all_DBAdaptors();
diag("Found ".scalar @$dbas3);

$helper->update_from_registry(1);

my $dbas2 = $helper->get_all();
diag("Found ".scalar @$dbas2);

done_testing;
