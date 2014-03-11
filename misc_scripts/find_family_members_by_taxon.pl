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
  <helpdesk@ensemblgenomes.org>.

=head1 DESCRIPTION

This script is an example of how to use the Ensembl Bacteria compara database to find which genes are in a particular family and restrict to part of the taxonomy

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
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;

print "Building helper\n";
my $helper = Bio::EnsEMBL::LookUp->new(-URL      => "http://bacteria.ensembl.org/registry.json",
									   -NO_CACHE => 1);

print "Connecting to taxonomy DB\n";
my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new(Bio::EnsEMBL::DBSQL::DBAdaptor->new(-user    => 'anonymous',
																									 -dbname  => 'ncbi_taxonomy',
																									 -host    => 'mysql.ebi.ac.uk',
																									 -port    => 4157,
																									 -group   => 'taxonomy',
																									 -species => 'ena'));

# find the taxids of all descendants of a specified node to use as a filter
my $taxid = 1219;
print "Finding taxonomy node for " . $taxid . "\n";
my $root = $node_adaptor->fetch_by_taxon_id($taxid);
my %taxids = map { $_->taxon_id() => 1 } @{$node_adaptor->fetch_descendants($root)};

# load compara adaptor
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_17_70');
# find the corresponding member
my $family = $compara_dba->get_FamilyAdaptor()->fetch_by_stable_id('MF_00395');
print "Family " . $family->stable_id() . "\n";
for my $member (@{$family->get_all_Members()}) {
  my $genome_db = $member->genome_db();
  # filter by taxon
  if (defined $taxids{$genome_db->taxon_id()}) {
	my ($member_dba) = @{$helper->get_by_name_exact($genome_db->name())};
	if (defined $member_dba) {
	  my $gene = $member_dba->get_GeneAdaptor()->fetch_by_stable_id($member->stable_id());
	  print $member_dba->species() . " " . $gene->external_name . "\n";
	}
  }
}
