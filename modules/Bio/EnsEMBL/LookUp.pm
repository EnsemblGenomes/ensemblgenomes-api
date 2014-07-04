
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

=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::LookUp

=head1 SYNOPSIS

# default creation using latest public release of Ensembl Genomes
my $lookup = Bio::EnsEMBL::LookUp->new();

=head1 DESCRIPTION

This module is a helper that provides additional methods to aid navigating a registry of >6000 species across >25 databases. 
It does not replace the Registry but provides some additional methods for finding species e.g. by searching for species that 
have an alias that match a regular expression, or species which are derived from a specific ENA/INSDC accession, or species
that belong to a particular part of the taxonomy. 

There are a number of ways of creating a lookup but the simplest is to use the default setting of the latest publicly 
available Ensembl Genomes databases: 

	my $lookup = Bio::EnsEMBL::LookUp->new();

Once a lookup has been created, there are various methods to retreive DBAdaptors for species of interest:

1. To find species by name - all DBAdaptors for species with a name or alias matching the supplied string:

	$dbas = $lookup->get_by_name_exact('Escherichia coli str. K-12 substr. MG1655');

2. To find species by name pattern - all DBAdaptors for species with a name or alias matching the supplied regexp:

	$dbas = $lookup->get_by_name_exact('Escherichia coli .*);

3. To find species with the supplied taxonomy ID:

	$dbas = $lookup->get_all_by_taxon_id(388919);
	
4. In coordination with a taxonomy node adaptor to get DBAs for all descendants of a node:

	my $node = $node_adaptor->fetch_by_taxon_id(511145);
	for my $child (@{$node_adaptor->fetch_descendants($node)}) {
		my $dbas = $lookup->get_all_by_taxon_id($node->taxon_id())
		if(defined $dbas) {
			for my $dba (@{$dbas}) {
				# do something with the $dba
			}
		}
	}

The retrieved DBAdaptors can then be used as normal e.g.

	for my $gene (@{$dba->get_GeneAdaptor()->fetch_all_by_biotype('protein_coding')}) {
		print $gene->external_name."\n";
	}

Once retrieved, the arguments needed for constructing a DBAdaptor directly can be dumped for later use e.g.

	my $args = $lookup->dba_to_args($dba);
	... store and retrieve $args for use in another script ... 
	my $resurrected_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(@$args);

=head2 Local implementation

The default implementation of LookUp is a remoting implementation that uses a MySQL database backend
to look up genome information. The previous implementation loaded an internal hash from either a JSON file
(remote or local) or by processing the contents of the Registry. 

This implementation is still available, but has been renamed Bio::EnsEMBL::LookUp::LocalLookUp and should
be constructed directly.
  
=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$

=cut

package Bio::EnsEMBL::LookUp;

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use DBI;
use JSON;
use LWP::Simple;
use Carp;
use Data::Dumper;
use Bio::EnsEMBL::LookUp::LocalLookUp;
use Bio::EnsEMBL::LookUp::RemoteLookUp;
my $default_cache_file = qw/lookup_cache.json/;

=head1 SUBROUTINES/METHODS

=head2 new

  Description       : Creates a new instance of LookUp, by default using Bio::EnsEMBL::LookUp::RemoteLookUp
  Returntype        : Instance of lookup
  Status            : Stable

  Example       	: 
  my $lookup = Bio::EnsEMBL::LookUp->new();
=cut

sub new {
  my ($class, @args) = @_;
  my $self = bless({}, ref($class) || $class);
  ($self->{lookup}, $self->{lookup}, $self->{registry},
   $self->{url},    $self->{file}
  ) = rearrange([qw(lookup registry url file)], @args);
  if (defined $self->{url} ||
	  defined $self->{registry} ||
	  defined $self->{file})
  {
	warning(
q/Direct construction of local or url\/file-based LookUp deprecated.  
  	Use Bio::EnsEMBL::LookUp->new() for new remoting implementation or
  	use Bio::EnsEMBL::LookUp::LocalLookUp->new() directly for previous implementation/
	);
	$self->{lookup} =
	  Bio::EnsEMBL::LookUp::LocalLookUp->new(@args);
  }
  if (!defined $self->{lookup}) {
	$self->{lookup} = Bio::EnsEMBL::LookUp::RemoteLookUp->new(@args);
  }
  return $self;
}

sub register_all_dbs {
  my ($class, $host, $port, $user, $pass, $regexp) = @_;
  warning(
	q/register_all_dbs is now part of Bio::EnsEMBL::LookUp::LocalLookUp 
  and should be invoked directly/);
  Bio::EnsEMBL::LookUp::LocalLookUp->register_all_dbs($host, $port,
												 $user, $pass, $regexp);
  return;
}

use vars '$AUTOLOAD';
sub AUTOLOAD {
   my ( $self, @args ) = @_;
   (my $method = $AUTOLOAD) =~ s/^.*::(\w+)$/$1/ ;
   return $self->{lookup}->$method(@args);
}
sub DESTROY { }    # required due to AUTOLOAD

1;

