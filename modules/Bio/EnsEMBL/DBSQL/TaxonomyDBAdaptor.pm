
=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor

=head1 DESCRIPTION

Specialised DBAdaptor for connecting to the ncbi_taxonomy MySQL database

=cut

package Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;

use strict;
use warnings;

use base qw ( Bio::EnsEMBL::DBSQL::DBAdaptor );

sub get_available_adaptors {
    return {'TaxonomyNode' => 'Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor' };
}

sub new_public {
    return Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor->new(
                  -user   => 'anonymous',
                  -dbname => 'ncbi_taxonomy',
                  -host   => 'mysql-eg-ena-publicsql.ebi.ac.uk',
                  -port   => 4364 );
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor

=head1 SYNOPSIS

#create an adaptor (Registry cannot be used currently)
my $tax_dba =  Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor->new(
									  -user   => $tax_user,
									  -pass   => $tax_pass,
									  -dbname => $tax_db,
									  -host   => $tax_host,
									  -port   => $tax_port);	
my $node_adaptor = $tax_dba->get_TaxonomyNodeAdaptor();
									  
=head DESCRIPTION

A specialised DBAdaptor allowing connection to an ncbi_taxonomy database. 
Can be used to retrieve an instance of Bio::EnsEMBL::DBSQL::TaxonomyAdaptor.

=head1 SUBROUTINES/METHODS

=head2 get_available_adaptors	

	Description	: Retrieve all adaptors supported by this database
	Returns		: Hash of adaptor modules by name
	
=head2 get_TaxonomyNodeAdaptor
	
	Description	: Retrieve an adaptor for working with the taxonomy database referred to by this instance. 
	Returns		: Instance of Bio::EnsEMBL::DBSQL::TaxonomyAdaptor
	Note		: Method invoked by AUTOLOAD method on Bio::EnsEMBL::DBSQL::DBAdaptor

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut							  
