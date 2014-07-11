
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

Bio::EnsEMBL::Utils::EGPublicMySQLServer

=head1 SYNOPSIS

  use Bio::EnsEMBL::Utils::EGPublicMySQLServer;

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Utils::EGPublicMySQLServer;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(warning);

use Exporter;

use base qw( Exporter );

our @EXPORT = qw(eg_host eg_port eg_user eg_pass eg_args);

use constant PUBLIC_HOST => 'mysql.ebi.ac.uk';
use constant PUBLIC_USER => 'anonymous';
use constant PUBLIC_PASS => '';
use constant PUBLIC_PORT => 4157;

sub eg_host {
  return PUBLIC_HOST;
}

sub eg_port {
  return PUBLIC_PORT;
}

sub eg_user {
  return PUBLIC_USER;
}

sub eg_pass {
  return PUBLIC_PASS;
}

sub eg_args {
  return {-USER => PUBLIC_USER,
		  -PASS => PUBLIC_PASS,
		  -HOST => PUBLIC_HOST,
		  -PORT => PUBLIC_PORT};
}

1;

