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

my $node = $node_adaptor->fetch_by_taxon_id( $conf->{taxon_id} )
  || die "Could not retrieve node $conf->{taxon_id}: $@";
ok( defined $node,
	"Checking if the node node $conf->{taxon_id} could be retrieved" );
is ($node->taxon_id(),$conf->{taxon_id},'Checking node ID is as expected');

# get lineage
my @lineage = @{$node_adaptor->fetch_ancestors($node)};
ok ((scalar @lineage)>1,'Checking lineage is found');

# get descendants
my @desc = @{$node_adaptor->fetch_descendants($node)};
ok ((scalar @desc)>0,'Checking descendants are found');
# get leaf nodes
my @leaves = @{$node_adaptor->fetch_leaf_nodes($node)};
ok ((scalar @leaves)>0,'Checking leaves are found');

done_testing;