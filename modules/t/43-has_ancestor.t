use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::TaxonomyNode;
use Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

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

my $n2 = $node_adaptor->fetch_by_taxon_id( 8 )
  || die "Could not retrieve node 8: $@";
ok( defined $n2,
	"Checking if the node 8 could be retrieved" );
is ($n2->taxon_id(),8,'Checking node ID is as expected');
diag($n2->to_string());

ok($n1->has_ancestor($n2)==1,"Checking that ".$n1->to_string()." has ancestor ".$n2->to_string());
ok($n2->has_ancestor($n1)==0),"Checking that ".$n2->to_string()." does not have ancestor ".$n1->to_string();

done_testing;
