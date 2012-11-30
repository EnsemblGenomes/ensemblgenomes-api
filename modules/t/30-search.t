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

# get matching names
my @nodes = @{$node_adaptor->fetch_all_by_name($conf->{name})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name matches found');

@nodes = @{$node_adaptor->fetch_all_by_name_and_class($conf->{name},$conf->{name_class})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name/class matches found');

@nodes = @{$node_adaptor->fetch_all_by_rank($conf->{rank})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name/rank matches found');

@nodes = @{$node_adaptor->fetch_all_by_name_and_rank($conf->{name},$conf->{rank})};
#for my $node (@nodes) {
#    printf "Matching node %d is %s %s\n",$node->taxon_id(),$node->rank(),$node->names()->{'scientific name'}->[0];
#}
ok ((scalar @nodes)>0,'Checking name/rank matches found');

done_testing;
