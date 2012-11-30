use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::LookUp;

my $helper = Bio::EnsEMBL::LookUp->new(-FILE=>"reg.json",-NO_CACHE=>1);
ok(defined $helper, "Helper object from file exists");

my $dbas = $helper->get_all();
my $dbas2 = $helper->registry()->get_all_DBAdaptors();
ok(scalar @$dbas == scalar @$dbas2,"Expected number of DBAs in registry and helper");
my $taxid= 388919;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found ".scalar @$dbas);
is($dbas->[0]->get_MetaContainer()->get_taxonomy_id(),$taxid,"Taxonomy ID $taxid match");

my $pattern = "Escherichia.*";
$dbas = $helper->get_all_by_name_pattern($pattern);
diag("Found ".scalar @$dbas);
ok($dbas->[0]->species()=~m/$pattern/i,"Name $pattern match");

$helper->write_registry_to_file("reg2.json");
diag("Wrote to file");

done_testing;