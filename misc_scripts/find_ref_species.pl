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
my $helper = Bio::EnsEMBL::LookUp->new(-URL => "http://demo2.ensemblgenomes.org/registry.json", -NO_CACHE => 1);

open my $species_file, '<','/scratch/reference_prokaryotes.txt';
my $tax_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(-user    => 'anonymous',
												  -dbname  => 'ncbi_taxonomy',
												  -host    => 'mysql-eg-ena-publicsql.ebi.ac.uk',
												  -port    => 4364,
												  -group   => 'taxonomy',
												  -species => 'ena');

my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($tax_dba);
my $n=0;
my $x=0;
while(<$species_file>) {
	$x++;
	chomp;
	my $taxon = $node_adaptor->fetch_by_taxon_id($_);
	my ($dba) = @{$helper->get_all_by_taxon_id($taxon->taxon_id())};
	if(defined $dba) {
		print $dba->species."\n";
	} else {
		print "Cannot find DBA for ".$taxon->name." (taxid ".$taxon->taxon_id().")\n";
		my $is_found = 0;
		for my $kid (@{$node_adaptor->fetch_descendants($taxon)}) {
			($dba) = @{$helper->get_all_by_taxon_id($kid->taxon_id())};
			if(defined $dba) {
				$is_found++;
			}
		}
		if($is_found==0) {
			$n++;
		} else {
			print "Found $is_found matches\n";
		}
	}
}
print "Could not find $n out of $x\n";
