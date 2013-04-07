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
Bio::EnsEMBL::LookUp::get_by_accession to retrieve a 
DBAdaptor instance for the ENA Bacteria genome containing the supplied 
INSDC accession, using a specified set of databases to build the helper
(rather than the recalculated JSON file provided)

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
print "Loading registry\n";
Bio::EnsEMBL::LookUp->register_all_dbs( "mysql.ebi.ac.uk", 4157, "anonymous","",'bacteria_[0-9]+_collection_core_17_70_1');
print "Building helper\n";
my $helper =
  Bio::EnsEMBL::LookUp->new();
my $acc = 'U00096';
print "Getting DBA for $acc\n";
my $dba   = $helper->fetch_all_by_accession($acc);
my $genes = $dba->get_GeneAdaptor()->fetch_all();
print "Found " . scalar @$genes . " genes for " . $dba->species() . "\n";
