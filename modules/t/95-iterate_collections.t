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