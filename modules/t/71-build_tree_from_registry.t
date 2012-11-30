use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::TaxonomyNode;
use Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::LookUp;

my $conf_file = 'db.conf';

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;

my $tconf = $conf->{tax};
$tconf->{db} = "ncbi_taxonomy";

my $dba =
  Bio::EnsEMBL::DBSQL::DBAdaptor->new( -user    => $tconf->{user},
									   -pass    => $tconf->{pass},
									   -dbname  => $tconf->{db},
									   -host    => $tconf->{host},
									   -port    => $tconf->{port},
									   -driver  => $tconf->{driver},
									   -group   => 'taxonomy',
									   -species => 'ena' );

my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($dba);
ok( defined $node_adaptor, "Taxonomy Node Adaptor exists" );

my $econf = $conf->{ena};

Bio::EnsEMBL::LookUp->register_all_dbs(
								 $econf->{host}, $econf->{port}, $econf->{user},
								 $econf->{pass}, $econf->{db} );
my $helper = Bio::EnsEMBL::LookUp->new(-CLEAR_CACHE => 1);
ok( defined $helper, "Helper object exists" );

# build array of dbas
my $dbas = $helper->get_all();
diag( "Found " . scalar @$dbas . " dbas" );

my @leaf_nodes;
for my $dba (@$dbas) {
    my $node = $node_adaptor->fetch_by_coredbadaptor($dba);
    if ( defined $node ) {
        push @leaf_nodes, $node;
    } else {
        print "Could not find node for dba "
          . $dba->dbc()->dbname() . "/"
          . $dba->species_id() . "\n";
    }
}

my $root = shift(@{$node_adaptor->fetch_all_by_name_and_class('cellular organisms', 'scientific name')});

diag "building pruned tree";
$node_adaptor->build_pruned_tree($root, \@leaf_nodes); 

done_testing;
