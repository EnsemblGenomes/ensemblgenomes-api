
=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
use Bio::EnsEMBL::Utils::EGPublicMySQLServer;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

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
	Bio::EnsEMBL::DBSQL::TaxonomyDBAdaptor->new(
											 -user   => eg_user(),
											 -pass   => eg_pass(),
											 -dbname => 'ncbi_taxonomy',
											 -host   => eg_host(),
											 -port   => eg_port()
	);
}

sub get_TaxonomyNodeAdaptor {
	my ($self) = @_;
	return Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($self); 
}

1;

