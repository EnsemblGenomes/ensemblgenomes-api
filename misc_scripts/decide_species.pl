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

my $pan_species = {};
open my $in, "<", "/scratch/matrix_${branch}.txt";
my $genera = {};
while (<$in>) {
  chomp;
  next if m/#/;
  my ($name, $species_id, $cnt, $uniprot, $pan) = split "\t";
  my ($genus) = split(" ", $name);
  push @{$genera->{$genus}}, {name => $name, tax_id => $species_id, cnt => $cnt, uniprot => $uniprot, pan => $pan};
}
close $in;

# get genera by
my $final_list = [];
while (my ($genus, $species_list) = each %$genera) {
  my @sl = sort { $b->{pan} <=> $a->{pan} || $b->{uniprot} <=> $a->{uniprot} || $b->{cnt} <=> $a->{cnt} } @$species_list;
  push @$final_list, $sl[0];
  #	for my $species (@species_list) {
  #		print join ("\t",$species->{name},$species->{tax_id},$species->{cnt},$species->{uniprot},$species->{pan})	."\n";
  #	}
}

open my $out, ">", "/scratch/filtered_${branch}.txt";
print $out "#".join("\t",qw/name tax_id citations uniprot_strain pan_strain/)."\n";
for my $species (sort { $b->{pan} <=> $a->{pan} || $b->{uniprot} <=> $a->{uniprot} || $b->{cnt} <=> $a->{cnt} } grep { $_->{cnt} > 99 || $_->{uniprot}!=-1 || $_->{pan}!=-1 } @{$final_list}) {	
  print $out join("\t", $species->{name}, $species->{tax_id}, $species->{cnt}, $species->{uniprot}, $species->{pan}) . "\n";
}
close $out;

