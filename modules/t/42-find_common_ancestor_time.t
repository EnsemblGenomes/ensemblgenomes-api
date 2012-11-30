use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::TaxonomyNode;
use Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::DBSQL::TimeTreeAdaptor;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

$conf = $conf->{tax_test};
my $dba =  Bio::EnsEMBL::DBSQL::DBAdaptor->new(
									  -user   => $conf->{user},
									  -pass   => $conf->{pass},
									  -dbname => $conf->{db},
									  -host   => $conf->{host},
									  -port   => $conf->{port},
									  -driver => $conf->{driver});
									  
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);
		
ok( defined $node_adaptor, 'Checking if the node adaptor is defined' );

my $n1 = $node_adaptor->fetch_by_taxon_id( 10 )
  || die "Could not retrieve node 10: $@";
ok( defined $n1,
	"Checking if the node 10 could be retrieved" );
is ($n1->taxon_id(),10,'Checking node ID is as expected');
diag($n1->to_string());
$n1 = $node_adaptor->fetch_ancestor_by_rank($n1,"species");
diag($n1->to_string());

my $n2 = $node_adaptor->fetch_by_taxon_id( 11 )
  || die "Could not retrieve node 11: $@";
ok( defined $n2,
	"Checking if the node 11 could be retrieved" );
is ($n2->taxon_id(),11,'Checking node ID is as expected');
diag($n2->to_string());
$n2 = $node_adaptor->fetch_ancestor_by_rank($n2,"species");
diag($n2->to_string());

my $time_tree = Bio::EnsEMBL::DBSQL::TimeTreeAdaptor->new();
my $x = $time_tree->get_time($n1,$n2);
diag $x;

done_testing;
