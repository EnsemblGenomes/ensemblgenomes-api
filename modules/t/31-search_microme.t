use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::TaxonomyNode;
use Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

$conf = $conf->{tax};

my $dba =  Bio::EnsEMBL::DBSQL::DBAdaptor->new(
									  -user   => $conf->{user},
									  -pass   => $conf->{pass},
									  -dbname => $conf->{db},
									  -host   => $conf->{host},
									  -port   => $conf->{port},
									  -driver => $conf->{driver});
									  
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);
		
ok( defined $node_adaptor, 'Checking if the node adaptor is defined' );

# get matching names
my @nodes = @{$node_adaptor->fetch_all_by_name('%K-12%')};
cmp_ok(scalar(@nodes), ">=", 22, "Get named taxons");

# get descendants
@nodes = @{$node_adaptor->fetch_descendants(511145)};
cmp_ok(scalar(@nodes), ">=", 20, "Get descendants");

# get cousins
@nodes = @{$node_adaptor->fetch_descendants_offset(511145,2)};
cmp_ok(scalar(@nodes), ">=", 804, "Get descendants using offset");

done_testing;