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

my $dbas = $helper->registry()->get_all();
diag("Found ".scalar @$dbas);
my $taxid= 388919;
$dbas = $helper->get_all_by_taxon_id($taxid);
diag("Found ".scalar @$dbas);
my $dba = $dbas->[0];
is($dba->get_MetaContainer()->get_taxonomy_id(),$taxid,"Taxonomy ID $taxid match");
 
my $args = $helper->dba_to_args($dba);
my $dba2 = Bio::EnsEMBL::DBSQL::DBAdaptor->new(@$args);
is($dba->species(),$dba2->species(),"Species match");
is($dba->species_id(),$dba2->species_id(),"Species ID match");
is($dba2->get_MetaContainer()->get_taxonomy_id(),$taxid,"Taxonomy ID $taxid match");

$dba = $helper->get_by_accession("U00096");
ok(defined $dba,"DBA found for U00096");

$dba = $helper->get_by_assembly_accession("GCA_000005845.1");
ok(defined $dba,"DBA found for GCA_000005845.1");

done_testing;