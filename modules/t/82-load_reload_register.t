use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::Registry;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

my $helper = Bio::EnsEMBL::LookUp->new(-URL=>$conf->{ena_url},-NO_CACHE=>1);

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