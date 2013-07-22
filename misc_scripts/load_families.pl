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
  
=head1 SYNOPSIS

load_families.pl [arguments]

  --user=user                      username for the core databases

  --pass=pass                      password for the core databases

  --host=host                      server for the core databases

  --port=port                      port for the core databases

  --pattern=pattern                      pattern for the core databases
  
   --comparauser=user                     username for the compara database

  --comparapass=pass                     password for compara database

  --comparahost=host                     server where the compara database is stored

  --comparaport=port                     port for compara database
  
  --comparadbname=dbname                 name of compara database to process
  
  --nocache                          do not use cached database lookup service (optional)

  --logic_name						 logic name of analysis to use to build families (default is hamap)

  --help                              print help (this message)

=head1 DESCRIPTION

This script is used to populate the family portion of an Ensembl Compara database using protein features (e.g. HAMAP)

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
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Utils::CliHelper;
use Data::Dumper;
use Carp;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [ @{ $cli_helper->get_dba_opts() },
              @{ $cli_helper->get_dba_opts('compara') } ];
# add the print option
push( @{$optsd}, "logic_name:s@" );
push( @{$optsd}, "nocache" );
# process the command line with the supplied options plus a help subroutine
my $opts = $cli_helper->process_args( $optsd, \&pod2usage );
$opts->{logic_name} ||= ['hamap','panther'];

if (    !$opts->{user}
     || !$opts->{pass}
     || !$opts->{host}
     || !$opts->{port}
     || !$opts->{comparauser}
     || !$opts->{comparapass}
     || !$opts->{comparahost}
     || !$opts->{comparaport}
     || !$opts->{comparadbname} )
{
    pod2usage(1);
}

my $logic_names = join (',',map{"'$_'"} @{$opts->{logic_name}});

# logicname to use
my $sql = qq/SELECT g.stable_id,g.description,pf.hit_name,pf.external_data FROM gene g
JOIN seq_region sr USING (seq_region_id)
JOIN coord_system cs USING (coord_system_id)
JOIN transcript USING (gene_id)
JOIN translation USING (transcript_id)
JOIN protein_feature pf USING (translation_id)
JOIN analysis pfa ON (pf.analysis_id=pfa.analysis_id)
WHERE pfa.logic_name in ($logic_names) AND cs.species_id=?/;

my $compara_url = sprintf( 'mysql://%s:%s@%s:%d/%s',
                           $opts->{comparauser}, $opts->{comparapass},
                           $opts->{comparahost}, $opts->{comparaport},
                           $opts->{comparadbname} );

$logger->info("Registering databases");
Bio::EnsEMBL::LookUp->register_all_dbs(
                           $opts->{host}, $opts->{port}, $opts->{user},
                           $opts->{pass}, $opts->{pattern} );
$logger->info("Building helper");
my $helper =
  Bio::EnsEMBL::LookUp->new( -NO_CACHE => $opts->{nocache} );



$logger->info("Getting compara DBA");
# get a compara dba
my $compara_dba =
  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url     => $compara_url,
                                                -species => 'Multi' );
my $genome_dba = $compara_dba->get_GenomeDBAdaptor();
my $member_dba = $compara_dba->get_MemberAdaptor();
my $family_dba = $compara_dba->get_FamilyAdaptor();

my $genome_dbs;  # arrayref
my $families;    # hashref keyed by feature logic name - contains set of members
my $family_descriptions = {};

for my $dba ( @{ $helper->get_all() } ) {
    $logger->info( "Processing " . $dba->species() );
    # create a genomedb and store it
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();
    my $meta      = $dba->get_MetaContainer();
    $genome_db->name( $dba->species() );
    $genome_db->assembly( $meta->single_value_by_key('assembly.name') );
    $genome_db->taxon_id( $meta->get_taxonomy_id() );
    $genome_db->genebuild( $meta->single_value_by_key('genebuild.version') );
    $genome_dba->store($genome_db);
    push @$genome_dbs, $genome_db;
# get the genes with the feature we're interested in and create a member for each (use a mapper for this)
    $dba->dbc()->sql_helper()->execute_no_return(
        -SQL      => $sql,
        -CALLBACK => sub {
            my @row = @{ shift @_ };
            # create the member and add to the families hash
            my $member =
              Bio::EnsEMBL::Compara::AlignedMember->new(
                                            -STABLE_ID   => $row[0],
                                            -DESCRIPTION => $row[1],
                                            -SOURCE_NAME => 'ENSEMBLGENE',
                                            -TAXON_ID => $genome_db->taxon_id(),
                                            -GENOME_DB_ID => $genome_db->dbID(),
              );
            $member_dba->store($member);
            push @{ $families->{ $row[2] } }, $member;
            $family_descriptions->{$row[2]} = $row[3];
            return;
        },
        -PARAMS => [ $dba->species_id() ] );
} ## end for my $dba ( @{ $helper...})

croak "No core DBAs found" if !defined $genome_dbs;

# create and store MLSS
my $mlss =
  Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
          -method =>
            Bio::EnsEMBL::Compara::Method->new( -type  => 'FAMILY',
                                                -class => 'Family.family' ),
          -species_set_obj =>
            Bio::EnsEMBL::Compara::SpeciesSet->new( -GENOME_DBS => $genome_dbs )
  );
  $compara_dba->get_MethodLinkSpeciesSetAdaptor()->store($mlss);

# iterate over families and store families
while ( my ( $feature_id, $members ) = each(%$families) ) {
    $logger->info(
               "Storing $feature_id with " . scalar(@$members) . " members\n" );
               # TODO may need to get a better description here - unclear best place to retrieve this from
    my $family = Bio::EnsEMBL::Compara::Family->new(
                    -STABLE_ID                  => $feature_id,
                    -DESCRIPTION                  => $family_descriptions->{$feature_id},
                    -VERSION                    => 1,
                    -METHOD_LINK_SPECIES_SET_ID => $mlss->dbID() );
    for my $member (@$members) {
        $family->add_Member($member);
    }
    $family_dba->store($family);
}

