#!perl
use Test::More;

BEGIN {
	use_ok( 'Bio::EnsEMBL::TaxonomyNode' );
	use_ok( 'Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor' );
	use_ok( 'Bio::EnsEMBL::LookUp' );
}

diag( "Testing EGEna $EGEna::VERSION, Perl $], $^X" );
done_testing;