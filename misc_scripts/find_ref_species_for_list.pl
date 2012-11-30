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

This script is used to generate a text summary of all the genomes loaded into ENA Bacteria.

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut

use strict;
use warnings;

use Pod::Usage;
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use Bio::EnsEMBL::DBSQL::CiteExploreAdaptor;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

open my $species_file, '<','/scratch/reference_prokaryotes.txt';
my $tax_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(-user    => 'anonymous',
												  -dbname  => 'ncbi_taxonomy',
												  -host    => 'mysql-eg-ena-publicsql.ebi.ac.uk',
												  -port    => 4364,
												  -group   => 'taxonomy',
												  -species => 'ena');

my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($tax_dba);
my $species_lookup = {};
while(<$species_file>) {
	chomp;
	my $taxon = $node_adaptor->fetch_by_taxon_id($_);
	
	if($taxon->rank() eq 'species') {
		$species_lookup->{$taxon->taxon_id()} = $taxon->taxon_id();
	} else {
		my $species = $node_adaptor->fetch_ancestor_by_rank($taxon, 'species');
		$species_lookup->{$species->taxon_id()} = $taxon->taxon_id();
	}
}
close $species_file;

open my $top_file_in, '<', '/scratch/archaea_species_10.txt';
open my $top_file_out, '>', '/scratch/archaea_species_10_ref.txt';
while(<$top_file_in>) {
	chomp;
	my ($name,$taxid,$cnt) = split "\t";
	my $ref_id = $species_lookup->{$taxid}||"-1";
	print $top_file_out join("\t",$name,$taxid,$ref_id)."\n";
}
close $top_file_in;
close $top_file_out;
