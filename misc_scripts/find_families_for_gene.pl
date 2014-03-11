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

  Questions may also be sent to the Ensembl Genomes help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is an example of how to use the Ensembl Bacteria compara database to find which family a gene belongs to

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut	

use strict;
use warnings;
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
print "Building helper\n";
my $helper = Bio::EnsEMBL::LookUp->new(-URL      => "http://bacteria.ensembl.org/registry.json",
									   -NO_CACHE => 1);

my $nom = 'escherichia_coli_str_k_12_substr_mg1655';
print "Getting DBA for $nom\n";
my ($dba) = @{$helper->get_by_name_exact($nom)};  

my $gene = $dba->get_GeneAdaptor()->fetch_by_stable_id('b0344');
print "Found gene " . $gene->external_name() . "\n";

# load compara adaptor
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_17_70');
# find the corresponding member
my $member = $compara_dba->get_GeneMemberAdaptor()->fetch_by_source_stable_id('ENSEMBLGENE',$gene->stable_id());
# find families involving this member
for my $family (@{$compara_dba->get_FamilyAdaptor()->fetch_all_by_Member($member)}) {
	print "Family ".$family->stable_id()."\n";	
}
