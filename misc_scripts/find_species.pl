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
my $branch = "archaea";
my $species_set = {};
my $n           = 0;
print "Getting species...\n";
open my $taxids, '<', "/scratch/${branch}_ids.txt";
while (<$taxids>) {
  chomp;
  $n++;
  my $leaf = $node_adaptor->fetch_by_taxon_id($_);
  my $species = $node_adaptor->fetch_ancestor_by_rank($leaf, 'species');
  if (defined $species) {
	$species_set->{$species->taxon_id()} = $species;
  }
}
close $taxids;

print "$n leaves, " . scalar(keys %{$species_set}) . " species\n";
my $cea = Bio::EnsEMBL::DBSQL::CiteExploreAdaptor->new();
my @counts;
for my $species (values %{$species_set}) {
  my $names = $species->names();
  my @query_names = ();
  for my $name_class ("scientific name","synonym") {
  	for my $name (@{$names->{$name_class}}) {
  		$name =~ s/ and / /ig;
  		$name =~ s/&/ /ig;
  		$name =~ s/ or / /ig;
  		$name =~ s/["']/ /ig;
  		push @query_names,"\"$name\"";
  	}
  }
  my $queryStr = join(" OR ",@query_names);
  $logger->info($queryStr);
  my $cnt = $cea->get_citation_count($queryStr);
  push @counts, [$species, $cnt];
}

print "Sorting:\n";
open my $out, '>', "/scratch/${branch}_citation_count.txt";
my $genera = {};
for my $s (sort { $b->[1] <=> $a->[1] } @counts) {
#  my ($genus) = split " ",$s->[0]->name();
#  if (!defined $genera->{$genus}) {
#	$genera->{$genus} = 1;#
#	print $out join("\t", ($s->[0]->name(), $s->[0]->taxon_id, $s->[1])) . "\n";
#  }
	print $out $s->[0]->taxon_id()."\t".$s->[1]."\n";
}
close $out;
