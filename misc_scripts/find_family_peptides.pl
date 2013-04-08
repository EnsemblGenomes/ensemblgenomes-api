#!/usr/bin/env perl

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

=head1 DESCRIPTION

This script is an example of how to use the Ensembl Bacteria compara database to find which genes are in a particular family and dump their peptides

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
use Bio::SeqIO;
print "Building helper\n";
my $helper = Bio::EnsEMBL::LookUp->new(-URL      => "http://bacteria.ensembl.org/registry.json",
									   -NO_CACHE => 1);

# load compara adaptor
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_17_70');

# find the corresponding member
my $family  = $compara_dba->get_FamilyAdaptor()->fetch_by_stable_id('MF_00395');

# create a file to write to
my $outfile = ">" . $family->stable_id . ".fa";
my $seq_out = Bio::SeqIO->new(-file   => $outfile,
							  -format => "fasta",);
print "Writing family " . $family->stable_id() . " to $outfile\n";

# loop over members
for my $member (@{$family->get_all_Members()}) {
  my $genome_db = $member->genome_db();
  my ($member_dba) = @{$helper->get_by_name_exact($genome_db->name())};
  if (defined $member_dba) {
	my $gene = $member_dba->get_GeneAdaptor()->fetch_by_stable_id($member->stable_id());
	print "Writing sequence for " . $member->stable_id() . "\n";
	my $s = $gene->canonical_transcript()->translate();
	$seq_out->write_seq($s);
  }
}
