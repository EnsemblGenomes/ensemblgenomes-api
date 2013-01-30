
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

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut		

package Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor;

use strict;
use warnings;

use base qw ( Bio::EnsEMBL::DBSQL::DBAdaptor );

=head1 SUBROUTINES/METHODS

=head2 get_available_adaptors	

	Description	: Retrieve all adaptors supported by this database
	Returns		: Hash of adaptor modules by name
=cut

sub get_available_adaptors {
  return {'TaxonomyNode' => 'Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor'};
}

=head2 new_public	

	Description	: Build a new adaptor from the public database
	Returns		: Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor
=cut

sub new_public {
  return
	Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor->new(-user   => 'anonymous',
												-dbname => 'ncbi_taxonomy',
												-host   => 'mysql.ebi.ac.uk',
												-port   => 4157);
}

1;

