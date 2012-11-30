
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

print "Connecting to taxonomy DB\n";
my $tax_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(-user    => 'anonymous',
												  -dbname  => 'ncbi_taxonomy',
												  -host    => 'mysql-eg-ena-publicsql.ebi.ac.uk',
												  -port    => 4364,
												  -group   => 'taxonomy',
												  -species => 'ena');

my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new($tax_dba);

my $species_set = {};
my $species_list = [];

my $branch = "archaea";

for my $file ("/scratch/pan_$branch.txt","/scratch/reference_$branch.txt","/scratch/cited_$branch.txt") {
	open my $in, "<", $file;
	while(<$in>) {
		chomp;
		  my $leaf = $node_adaptor->fetch_by_taxon_id($_);
 		 my $species = $node_adaptor->fetch_ancestor_by_rank($leaf, 'species');
 		 if(!defined $species_set->{$species->taxon_id()}) {
 		 	$species_set->{$species->taxon_id()} = $species;
 		 	push @$species_list,$species;
 		 }
	}
	close $in;
}

my $citation_count = {};
	open my $in, "<", "/scratch/${branch}_citation_count.txt";
	while(<$in>) {
		chomp;
		my ($taxid,$cnt) = split "\t";
		$citation_count->{$taxid} = $cnt;
	}
	close $in;

open my $out, ">", "/scratch/combined_$branch.txt";
for my $species (sort {$citation_count->{$b->taxon_id()} <=> $citation_count->{$a->taxon_id()}} @{$species_list}) {
	my $cnt = $citation_count->{$species->taxon_id()} || -1;
	print $out join("\t",$species->name(),$species->taxon_id(),$cnt)."\n";
}
close $out;