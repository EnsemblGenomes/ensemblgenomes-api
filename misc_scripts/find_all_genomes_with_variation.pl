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
to find and print information about genomes with variation data in the latest release of Ensembl Genomes

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut	

use strict;
use warnings;

use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;

# create an adaptor to work with genomes
my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->build_adaptor();

# find and iterate over all genomes
for my $genome (@{$gdba->fetch_all_with_variation()}) {
	print $genome->name()."\n";
}