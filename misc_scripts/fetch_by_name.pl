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

This script is an example of how to use 
Bio::EnsEMBL::LookUp::get_by_assembly_accession to retrieve all 
DBAdaptor instances for ENA Bacteria genomes which have the supplied name (can be production_name or a unique alias)

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
print "Building helper\n";
my $helper = Bio::EnsEMBL::LookUp->new(-URL=>"http://demo2.ensemblgenomes.org/registry.json",-NO_CACHE=>1);

my $nom = 'escherichia_coli_str_k_12_substr_mg1655';
print "Getting DBA for $nom\n";
my ($dba) = @{$helper->get_by_name_exact($nom)};   

# work with DBA as normal
my $genes = $dba->get_GeneAdaptor()->fetch_all();
print "Found ".scalar @$genes." genes for ".$dba->species()."\n";