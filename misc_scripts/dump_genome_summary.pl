#!/usr/bin/env perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is used to generate a summary of key metadata for ENA bacteria in JSON and XML.

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::LookUp;
use Carp;
use XML::Simple;
use JSON;
use Log::Log4perl qw(:easy);
use Pod::Usage;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = $cli_helper->get_dba_opts('ena');
push( @{$optsd}, "nocache" );
push( @{$optsd}, "url:s" );

my $opts = $cli_helper->process_args( $optsd, \&pod2usage );

my $helper;
if ( defined $opts->{url} ) {
    $helper = Bio::EnsEMBL::LookUp->new(
                      -URL => $opts->{url}, -NO_CACHE => $opts->{nocache} );
} else {
    Bio::EnsEMBL::LookUp->register_all_dbs(
                           $opts->{enahost}, $opts->{enaport}, $opts->{enauser},
                           $opts->{enapass}, $opts->{enapattern} );
    $helper = Bio::EnsEMBL::LookUp->new(
                                                -NO_CACHE => $opts->{nocache} );
}

my $metadata; # arrayref
my $n=0;
for my $dba ( @{ $helper->get_all() } ) {
	
	$logger->info("Processing ".$dba->species());
	
	# get metadata container
	my $meta = $dba->get_MetaContainer();
	my $md = {
	    species => $dba->species(),
	    species_id=>$dba->species_id(),
	    name=>$meta->get_scientific_name(),
	    taxonomy_id=>$meta->get_taxonomy_id(),
	    assembly_id=>$meta->single_value_by_key('assembly.accession'),
	    assembly_name=>$meta->single_value_by_key('assembly.name'),
	    dbname=>$dba->dbc()->dbname()
	};
	
	# get list of seqlevel contigs
	my $slice_adaptor = $dba->get_SliceAdaptor();
	for my $contig (@{$slice_adaptor->fetch_all("contig")}) {
	    push @{$md->{accession}}, $contig->seq_region_name();
	}
	push @{$metadata->{genome}},$md; 
}

# emit XML
my $xml_filename = 'ena_metadata.xml';
$logger->info("Writing XML to $xml_filename");
open(my $xml_file, '>', $xml_filename) || croak "Could not write to $xml_filename";
print $xml_file XML::Simple->new()->XMLout($metadata,
                      RootName=>'genomes',);
close $xml_file;

# emit JSON
my $json_filename = 'ena_metadata.json';
$logger->info("Writing JSON to $json_filename");
open(my $json_file, '>', $json_filename) || croak "Could not write to $json_filename";
print $json_file to_json($metadata, {pretty => 1});
close $json_file;

