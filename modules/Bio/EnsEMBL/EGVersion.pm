=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::EGVersion

=head1 SYNOPSIS

  use Bio::EnsEMBL::EGVersion;

  printf( "The Ensembl Genomes version used is %s\n", eg_version() );

=head1 DESCRIPTION

The module exports the eg_version() subroutine which returns the
release version of the Ensembl Genomes dataset. The version is based on 
the names of the core databases found by the Registry.

=cut

package Bio::EnsEMBL::EGVersion;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(warning);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;

use Exporter;

use base qw( Exporter );

our @EXPORT = qw(eg_version eg_version_for_dbname);

my $eg_version;

sub eg_version {
    if(!defined $eg_version) {
        for my $dbname (sort map{$_->dbc()->dbname()} @{Bio::EnsEMBL::Registry->get_all_DBAdaptors( '-GROUP' => 'core' ) }) {            
            if(!defined $eg_version) {
                $eg_version = eg_version_for_dbname($dbname);
            } else {
                if($eg_version != eg_version_for_dbname($dbname)) {
                    warning("Database $dbname does not match $eg_version");
                }
            }
        }
    }
    return $eg_version;
}

sub eg_version_for_dbname {
    my ($name) = @_;
    my ($eg_version) = $name =~ m/.+_core_([0-9]+)_[0-9]+_[0-9]+/;
    return $eg_version;
}

1;
