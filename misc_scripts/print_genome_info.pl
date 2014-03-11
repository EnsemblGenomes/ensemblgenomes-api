#!/usr/bin/env perl

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is an example of how to use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor
to find and print basic information about a given genome in release 21 of Ensembl Genomes

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut	

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;

# open connection to desired database
my $dbc =
  Bio::EnsEMBL::DBSQL::DBConnection->new(-user   => 'anonymous',
										 -dbname => 'ensemblgenomes_info_21',
										 -host   => 'mysql.ebi.ac.uk',
										 -port   => 4157);

# create an adaptor to work with genomes
my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new($dbc);

# get the genome of interest and print some information
my $genome = $gdba->fetch_by_species('arabidopsis_thaliana');
print $genome->name()." (".$genome->species.")\n";
print "Sequences: ".scalar(@{$genome->sequences()})."\n";
if($genome->has_variations()) {
	print "Variations: \n";
	# variations is a hash with type as the key
	while(my ($type,$value) = each %{$genome->variations()}) {
		print "- $type\n";
	}
}
print "Compara analyses: ".scalar(@{$genome->compara()})."\n";