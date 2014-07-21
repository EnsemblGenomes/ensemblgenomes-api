
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

Bio::EnsEMBL::LookUp::LocalLookUp

=head1 SYNOPSIS

# creation from a database server
Bio::EnsEMBL::LookUp::LocalLookUp->register_all_dbs( $conf->{host},
	   $conf->{port}, $conf->{user}, $conf->{pass}, $conf->{db});
my $lookup = Bio::EnsEMBL::LookUp::LocalLookUp->new();
my $dbas = $lookup->registry()->get_all();
$dbas = $lookup->get_all_by_taxon_id(388919);
$dbas = $lookup->get_by_name_pattern("Escherichia.*");

# creation from a URL
my $lookup = Bio::EnsEMBL::LookUp::::LocalLookUp->new(-URL=>'http://bacteria.ensembl.org/registry.json');

=head1 DESCRIPTION

This module is an implementation of Bio::EnsEMBL::LookUp that uses a local hash to store information about available Ensembl Genomes data. 
It can be constructed in a number of different ways:

A remote cache file containing a JSON representation of the hash can be supplied:

	my $lookup = Bio::EnsEMBL::LookUp::LocalLookUp->new(-URL=>'http://bacteria.ensembl.org/registry.json');

Alternatively, a local file containing the required JSON can be specified instead:

	my $lookup = Bio::EnsEMBL::LookUp::LocalLookUp->new(-FILE=>"/path/to/reg.json");

Finally, a Registry already loaded with core databases can be supplied:

	my $lookup = Bio::EnsEMBL::LookUp::LocalLookUp->new(-REGISTRY=>'Bio::EnsEMBL::Registry');

If the standard Registry is used, the argument can be omitted completely:

	my $lookup = Bio::EnsEMBL::LookUp::LocalLookUp->new();

To populate the registry with just the Ensembl Genomes databases for the current software 
release on a specified server, the following method can be used:

	Bio::EnsEMBL::LookUp::LocalLookUp->register_all_dbs( $host,
	   $port, $user, $pass);

Once a lookup has been created, it can be used as specified in Bio::EnsEMBL::LookUp

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$

=cut

package Bio::EnsEMBL::LookUp::LocalLookUp;

use warnings;
use strict;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
use List::MoreUtils qw(uniq);
use Scalar::Util qw(looks_like_number);
use DBI;
use JSON;
use LWP::Simple;
use Carp;

my $default_cache_file = qw/lookup_cache.json/;

=head1 SUBROUTINES/METHODS

=head2 new

  Description       : Creates a new instance of this object. 
  Arg [-REGISTRY]   : (optional) Registry module to use (default is Bio::EnsEMBL::Registry)
  Arg [-NO_CACHE]   : (optional) int 1
               This option will turn off the use of a local cache file for storing species details
  Arg [-CACHE_FILE] : (optional) String (default lookup_cache.json)
  				This option allows use of a user specified local cache file
  Arg [-URL]		: (optional) 
              This option allows the use of a remote resource supplying species details in JSON format. This is not used if a local cache exists and -NO_CACHE is not set
  Arg [-FILE]		: (optional) 
              This option allows the use of a file supplying species details in JSON format. This is not used if a local cache exists and -NO_CACHE is not set
  Returntype        : Instance of lookup
  Status            : Stable

  Example       	: 
  my $lookup = Bio::EnsEMBL::LookUp::LocalLookUp->new(
                                        -REGISTRY => $reg);
=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $reg, $url, $file, $nocache, $cache_file, $clear_cache, $skip_configs ) =
	rearrange( [qw(registry url file no_cache cache_file clear_cache skip_contigs)],
			   @args );
  if ( !defined $reg ) { $reg = 'Bio::EnsEMBL::Registry' }
  $self->{registry}      = $reg;
  $self->{dbas_by_taxid} = {};
  $self->{dbas_by_name}  = {};
  $self->{dbas_by_acc}   = {};
  $self->{dbas_by_vacc}  = {};
  $self->{dbas_by_gc}    = {};
  $self->{dbas_by_vgc}   = {};
  $self->{dbas}          = {};
  $self->{dbc_meta}      = {};
  $self->{skip_contigs}  = $skip_contigs;
  $cache_file ||= $default_cache_file;
  $self->cache_file($cache_file);

  if ( defined $clear_cache && $clear_cache == 1 ) {
	$self->clear_cache();
  }
  if ( !$nocache && !defined $file && -e $cache_file ) {
	$file = $cache_file;
  }
  if ( defined $file ) {
	$self->load_registry_from_file($file);
  }
  elsif ( defined $url ) {
	$self->load_registry_from_url($url);
  }
  else {
	$self->update_from_registry();
  }
  if ( !$nocache && !-e $cache_file ) {
	$self->write_registry_to_file($cache_file);
  }
  return $self;
} ## end sub new

=head2 registry

  Arg [1]     : Registry module to use (default is Bio::EnsEMBL::Registry)
  Description : Sets and retrieves the Registry 
  Returntype  : Registry if set; otherwise undef
  Exceptions  : if an attempt is made to set the value more than once
  Status      : Stable
=cut

sub registry {
  my ( $self, $registry ) = @_;
  if ( defined $registry ) {
	if ( exists $self->{registry} ) {
	  throw('Cannot reset the Registry object; already defined ');
	}
	$self->{registry} = $registry;
	$self->update_from_registry();
  }
  return $self->{registry};
}

=head2 cache_file
  Arg [1]     : File to use for local caching
  Description : Sets and retrieves the local cache file 
  Returntype  : File name if set; otherwise undef
  Status      : Stable
=cut

sub cache_file {
  my ( $self, $cache_file ) = @_;
  if ( defined $cache_file ) {
	$self->{cache_file} = $cache_file;
  }
  return $self->{cache_file};
}

=head2  update_from_registry
	Description : Update internal hashes of database adaptors by name/taxids from the registry. Invoke when registry has been updated independently.
	Argument 	: (optional) If set to 1, do not update from a DBAdaptor if already processed (allows updates of an existing LookUp instance)
	Exceptions  : None
=cut

sub update_from_registry {
  my ( $self, $update_only ) = @_;
  $self->_intern_db_connections();
  for my $dba (
		@{ $self->registry()->get_all_DBAdaptors( -group => 'core' ) } )
  {
	$self->_hash_dba( $dba, $update_only );
  }
  return;
}

sub taxonomy_adaptor {
  my ( $self, $adaptor ) = @_;
  if ( defined $adaptor ) {
	$self->{taxonomy_adaptor} = $adaptor;
  }
  elsif ( !defined $self->{taxonomy_adaptor} ) {
	$self->{taxonomy_adaptor} =
	  Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new_public();
  }
  return $self->{taxonomy_adaptor};
}

=head2 _register_dba
	Description	: Add a single DBAdaptor to the registry and the internal hashes of details
	Argument	: Bio::EnsEMBL::DBAdaptor
	Return		: None
=cut

sub _register_dba {
  my ( $self, $species, $dba ) = @_;
  $self->registry()->add_DBAdaptor( $species, "core", $dba );
  $self->_hash_dba($dba);
  return;
}

sub _dba_id {
  my ( $self, $dba ) = @_;
  return $dba->dbc()->dbname() . '/' . $dba->species_id();
}

sub _get_dbc_meta {
  my ( $self, $dbc ) = @_;
  my $name = $dbc->dbname();
  if ( !defined $self->{dbc_meta}{$name} ) {
	# load metadata in batch for the whole database
	$self->{dbc_meta}{$name} = {};
	# taxid

	$dbc->sql_helper()->execute(
	  -SQL =>
q/select species_id,meta_value from meta where meta_key='species.taxonomy_id'/,
	  -PARAMS   => [],
	  -CALLBACK => sub {
		my $row = shift @_;
		$self->{dbc_meta}{$name}{ $row->[0] }{taxid} = $row->[1];
	  } );
	# aliases
	$dbc->sql_helper()->execute(
	  -SQL =>
'select species_id,meta_value from meta where meta_key=\'species.alias\'',
	  -PARAMS   => [],
	  -CALLBACK => sub {
		my @row = @{ shift @_ };
		push @{ $self->{dbc_meta}{$name}{ $row[0] }{aliases} }, $row[1];
	  } );
	# assembly.accession
	$dbc->sql_helper()->execute(
	  -SQL =>
'select species_id,meta_value from meta where meta_key=\'assembly.accession\'',
	  -PARAMS   => [],
	  -CALLBACK => sub {
		my @row = @{ shift @_ };
		$self->{dbc_meta}{$name}{ $row[0] }{assembly_accession} =
		  $row[1];
	  } );

        if(!defined $self->{skip_contigs}) {
	# seq_region_names and synonyms
	$dbc->sql_helper()->execute(
	  -SQL =>
		q/select cs.species_id,sr.name,ss.synonym from coord_system cs 
	  join seq_region sr using (coord_system_id) 
	  left join seq_region_synonym ss using (seq_region_id)/,
	  -PARAMS   => [],
	  -CALLBACK => sub {
		my @row = @{ shift @_ };
		push @{ $self->{dbc_meta}{$name}{ $row[0] }{accessions} },
		  $row[1];
		if ( defined $row[2] ) {
		  push @{ $self->{dbc_meta}{$name}{ $row[0] }{accessions} },
			$row[2];
		}
	  } );
        }
  } ## end if ( !defined $self->{...})
  return $self->{dbc_meta}{$name};
} ## end sub _get_dbc_meta

=head2 _hash_dba
	Description : Add details from a DBAdaptor to the internal hashes of details
	Argument	: Bio::EnsEMBL::DBAdaptor
	Argument 	: (optional) If set to 1, do not update from a DBAdaptor if already processed (allows updates of an existing LookUp instance)
=cut

sub _hash_dba {
  my ( $self, $dba, $update_only ) = @_;
  my $nom = $self->_dba_id($dba);
  if ( !defined $update_only || !defined $self->{dbas}{$nom} ) {
	my $dbc_meta = $self->_get_dbc_meta( $dba->dbc() );
	my $dba_meta = $dbc_meta->{ $dba->species_id() };
	$self->_hash_dba_from_values( $dba,
								  [ $dba_meta->{taxid} ],
								  $dba_meta->{aliases},
								  $dba_meta->{accessions},
								  $dba_meta->{assembly_accession} );
  }
  return;
}

=head2 _hash_dba_from_values
	Description : Add supplied details to the internal hashes of details
	Argument	: Bio::EnsEMBL::DBAdaptor to hash
	Argument	: Arrayref of taxonomy IDs to use as keys
	Argument	: Arrayref of aliases to use as keys
	Argument	: Arrayref of ENA accessions to use as keys
=cut

sub _hash_dba_from_values {
  my ( $self, $dba, $taxids, $aliases, $accessions, $vgc ) = @_;

  for my $taxid ( @{$taxids} ) {
	if ( defined $taxid ) {
	  push @{ $self->{dbas_by_taxid}{$taxid} }, $dba;
	}
  }
  for my $name ( uniq( @{$aliases} ) ) {
	push @{ $self->{dbas_by_name}{$name} }, $dba;
  }
  for my $acc ( uniq( @{$accessions} ) ) {
	push @{ $self->{dbas_by_vacc}{$acc} }, $dba;
	$acc =~ s/\.[0-9]+$//x;
	push @{ $self->{dbas_by_acc}{$acc} }, $dba;
  }
  if ( defined $vgc ) {
	if ( defined $self->{dbas_by_vgc}{$vgc} ) {
	  croak "DBA with GC accession $vgc already registered";
	}
	$self->{dbas_by_vgc}{$vgc} = $dba;
	$vgc =~ s/\.[0-9]+$//x;
	if ( defined $self->{dbas_by_gc}{$vgc} ) {
	  croak "DBA with GC set chain $vgc already registered";
	}
	$self->{dbas_by_gc}{$vgc} = $dba;
  }
  $self->{dbas}{ $self->_dba_id($dba) } = $dba;
  return;
} ## end sub _hash_dba_from_values

sub _invert_dba_hash {
  my ($hash) = @_;
  my $inv_hash;
  while ( my ( $item, $dbas ) = each( %{$hash} ) ) {
	if ( ref $dbas ne 'ARRAY' ) {
	  $dbas = [$dbas];
	}
	for my $dba ( @{$dbas} ) {
	  my $dba_loc = _dba_to_locator($dba);
	  push @{ $inv_hash->{$dba_loc} }, $item;
	}
  }
  return $inv_hash;
}

=head2 _registry_to_hash
	Description	: Generate a hash array structure for the current registry and species details for turning to JSON
	Returns		: Arrayref of hashes
=cut

sub _registry_to_hash {
  my ($self) = @_;
  # hash dbcs and dbas by locators
  my $dbc_hash;
  my $dba_hash;
  for my $dba ( values %{ $self->{dbas} } ) {
	my $dbc_loc = _dbc_to_locator( $dba->dbc() );
	$dbc_hash->{$dbc_loc} = $dba->dbc();
	push @{ $dba_hash->{$dbc_loc} }, $dba;
  }
  # create auxillary hashes
  my $acc_hash   = _invert_dba_hash( $self->{dbas_by_vacc} );
  my $name_hash  = _invert_dba_hash( $self->{dbas_by_name} );
  my $taxid_hash = _invert_dba_hash( $self->{dbas_by_taxid} );
  my $gc_hash    = _invert_dba_hash( $self->{dbas_by_vgc} );
  # create array of hashes
  my $out_arr;
  while ( my ( $dbc_loc, $dbconn ) = each( %{$dbc_hash} ) ) {
	my $dbc_h = { driver   => $dbconn->driver(),
				  host     => $dbconn->host(),
				  port     => $dbconn->port(),
				  username => $dbconn->username(),
				  password => $dbconn->password(),
				  dbname   => $dbconn->dbname(),
				  species  => [] };
	for my $dba ( @{ $dba_hash->{$dbc_loc} } ) {
	  my $dba_loc = _dba_to_locator($dba);
	  my $gc      = $gc_hash->{$dba_loc};
	  if ( ref $gc eq 'ARRAY' ) {
		$gc = $gc->[0];
	  }
	  push @{ $dbc_h->{species} },
		{ species_id => $dba->species_id(),
		  species    => $dba->species(),
		  taxids     => $taxid_hash->{$dba_loc},
		  aliases    => $name_hash->{$dba_loc},
		  accessions => $acc_hash->{$dba_loc},
		  gc         => $gc };
	}
	push @{$out_arr}, $dbc_h;
  }
  return $out_arr;
} ## end sub _registry_to_hash

sub _registry_to_json {
  my ($self) = @_;
  my $out_arr = $self->_registry_to_hash();
  my $json;
  if ($out_arr) {
	$json = encode_json($out_arr);
  }
  else {
	carp('No DBAs found');
  }
  return $json;
}

=head2 write_registry_to_file
	Description	: Write the contents of the registry and species lists to a JSON file
	Argument	: File name
	Return		: None
=cut

sub write_registry_to_file {
  my ( $self, $file ) = @_;
  my $json = $self->_registry_to_json();
  if ($json) {
	open( my $fh, '>', $file ) ||
	  croak "Cannot open '${file}' for writing: $!";
	print $fh $json;
	close($fh);
  }
  return;
}

sub clear_cache {
  my ($self) = @_;
  if ( defined $self->cache_file() && -e $self->cache_file() ) {
	unlink $self->cache_file();
  }
  return;
}

=head2 _load_registry_from_json
	Description	: load the registry from the supplied JSON string
	Argument	: JSON string
=cut

sub _load_registry_from_json {
  my ( $self, $json ) = @_;
  my $reg_arr = decode_json($json);
  for my $dbc_h ( @{$reg_arr} ) {
	my $dbc =
	  Bio::EnsEMBL::DBSQL::DBConnection->new(
											-driver => $dbc_h->{driver},
											-host   => $dbc_h->{host},
											-port   => $dbc_h->{port},
											-user => $dbc_h->{username},
											-pass => $dbc_h->{password},
											-dbname => $dbc_h->{dbname}
	  );
	for my $species ( @{ $dbc_h->{species} } ) {
	  my $dba =
		Bio::EnsEMBL::DBSQL::DBAdaptor->new(
								  -DBCONN     => $dbc,
								  -species    => $species->{species},
								  -species_id => $species->{species_id},
								  -multispecies_db => 1,
								  -group           => 'core', );
	  # no need to register - found automagically
	  my $gc = $species->{gc};
	  if ( ref $gc eq 'ARRAY' ) { $gc = $gc->[0]; }
	  $self->_hash_dba_from_values( $dba,
									$species->{taxids},
									$species->{aliases},
									$species->{accessions},
									$species->{gc} );
	}
  } ## end for my $dbc_h ( @{$reg_arr...})
  $self->_intern_db_connections();
  return;
} ## end sub _load_registry_from_json

sub load_registry_from_file {
  my ( $self, $file ) = @_;
  open( my $fh, '<', $file ) or croak "Cannot open file $file: $!";
  my $data = do { local $/ = undef; <$fh> };
  close($fh);
  if ( defined $data && $data ne '' ) {
	$self->_load_registry_from_json($data);
  }
  return;
}

sub load_registry_from_url {
  my ( $self, $url ) = @_;
  my $json = get($url);
  croak "Could not retrieve JSON from $url: $@" unless defined $json;
  $self->_load_registry_from_json($json);
  return;
}

=head2 dba_to_args
	Description	: Dump the arguments needed for contructing a DBA
	Argument	: Bio::EnsEMBL::DBAdaptor
	Return		: Arrayref of args
=cut

sub dba_to_args {
  my ( $self, $dba ) = @_;
  my $dbc = $dba->dbc();
  my $args = [ -species         => $dba->species(),
			   -multispecies_db => $dba->is_multispecies(),
			   -species_id      => $dba->species_id(),
			   -group           => $dba->group(),
			   -host            => $dbc->host(),
			   -port            => $dbc->port(),
			   -user            => $dbc->username(),
			   -pass            => $dbc->password(),
			   -driver          => $dbc->driver(),
			   -dbname          => $dbc->dbname() ];
  return $args;
}

=head2 _dba_to_locator
	Description : return a hash key for a DBAdaptor
	Argument	: Bio::EnsEMBL::DBAdaptor
=cut

sub _dba_to_locator {
  my ($dba) = @_;
  confess(
	"Argument must be Bio::EnsEMBL::DBSQL::DBAdaptor not " . ref($dba) )
	unless ref($dba) eq "Bio::EnsEMBL::DBSQL::DBAdaptor";
  my $locator =
	join( q{!-!}, $dba->species_id(), _dbc_to_locator( $dba->dbc() ) );
  return $locator;
}

=head2 _dbc_to_locator
	Description : return a hash key for a DBConnection
	Argument	: Bio::EnsEMBL::DBConnection
=cut

sub _dbc_to_locator {
  my ($dbc) = @_;
  my $locator = join( q{!-!},
					  $dbc->host(),   $dbc->dbname(),
					  $dbc->driver(), $dbc->port(),
					  $dbc->username() );
  return $locator;
}

=head2 _intern_db_connections()
  Description : Go through all available DBAdaptors of registry and ensure they use the same
                DBConnection instance.
  Exceptions  : None
  Status      : At Risk
=cut

sub _intern_db_connections {
  my ($self) = @_;
  my $adaptors = $self->registry()->get_all_DBAdaptors();
  my %dbc_intern;
  foreach my $dba ( @{$adaptors} ) {
	my $dbc     = $dba->dbc();
	my $locator = _dbc_to_locator($dbc);
	if ( exists $dbc_intern{$locator} ) {
	  $dba->dbc( $dbc_intern{$locator} );
	}
	else {
	  $dbc_intern{$locator} = $dba->dbc();
	}
  }
  return;
}

=head2 get_all_DBConnections
	Description : Return all database connections used by the DBAs retrieved from the registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DBConnection
=cut

sub get_all_DBConnections {
  my ($self) = @_;
  my $adaptors = $self->registry()->get_all_DBAdaptors();
  my %dbcs;
  foreach my $dba ( values %{ $self->{dbas} } ) {
	my $dbc = $dba->dbc();
	$dbcs{ _dbc_to_locator($dbc) } = $dbc;
  }
  return [ values %dbcs ];
}

=head2 get_all_dbnames
	Description : Return all database names used by the DBAs retrieved from the registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_dbnames {
  my ($self) = @_;
  my %dbnames;
  foreach my $dba ( values %{ $self->{dbas} } ) {
	my $dbc = $dba->dbc();
	$dbnames{ $dbc->dbname }++;
  }
  return [ keys %dbnames ];
}

=head2 get_all
	Description : Return all database adaptors that have been retrieved from registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all {
  my ($self) = @_;
  return [ values %{ $self->{dbas} } ];
}

sub get_all_by_taxon_branch {
  my ( $self, $root ) = @_;
  if ( ref($root) ne 'Bio::EnsEMBL::TaxonomyNode' ) {
	if ( looks_like_number($root) ) {
	  $root = $self->taxonomy_adaptor()->fetch_by_taxon_id($root);
	}
	else {
	  ($root) =
		@{ $self->taxonomy_adaptor()->fetch_all_by_name($root) };
	}
  }
  if ( !defined $root ) {
	return [];
  }
  my @genomes = @{ $self->get_all_by_taxon_id( $root->taxon_id() ) };
  for my $node ( @{ $root->adaptor()->fetch_descendants($root) } ) {
	@genomes = ( @genomes,
				 @{ $self->get_all_by_taxon_id( $node->taxon_id() ) } );
  }
  return \@genomes;
}

=head2 get_all_by_taxon_id
	Description : Returns all database adaptors that have the supplied taxonomy ID
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_taxon_id {
  my ( $self, $id ) = @_;
  return $self->{dbas_by_taxid}{$id} || [];
}

=head2 get_by_name_exact
	Description : Return all database adaptors that have the supplied string as an alias/name
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_name_exact {
  my ( $self, $name ) = @_;
  return $self->{dbas_by_name}{$name};
}

=head2 get_all_by_accession
	Description : Returns the database adaptor(s) that contains a seq_region with the supplied INSDC accession (or other seq_region name)
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_accession {
  my ( $self, $acc ) = @_;
  my $dba = $self->{dbas_by_vacc}{$acc};
  if ( !defined $dba ) {
	$acc =~ s/\.[0-9]+$//x;
	$dba = $self->{dbas_by_acc}{$acc};
  }
  return $dba;
}

=head2 get_by_assembly_accession
	Description : Returns the database adaptor that contains the assembly with the supplied INSDC assembly accession
	Argument    : Int
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_by_assembly_accession {
  my ( $self, $acc ) = @_;
  my $dba = $self->{dbas_by_vgc}{$acc};
  if ( !defined $dba ) {
	$acc =~ s/\.[0-9]+$//x;
	$dba = $self->{dbas_by_gc}{$acc};
  }
  return $dba;
}

=head2 get_all_by_name_pattern
	Description : Return all database adaptors that have an alias/name that match the supplied regexp
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut	

sub get_all_by_name_pattern {
  my ( $self, $pattern ) = @_;
  my %dbas;
  for my $name ( keys %{ $self->{dbas_by_name} } ) {
	if ( $name =~ m/$pattern/x ) {
	  for my $dba ( @{ $self->{dbas_by_name}{$name} } ) {
		my $key = _dba_to_locator($dba);
		$dbas{$key} = $dba;
	  }
	}
  }
  return [ values(%dbas) ];
}

=head2 get_all_by_dbname
	Description : Returns all database adaptors that have the supplied dbname
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
=cut

sub get_all_by_dbname {
  my ( $self, $dbname ) = @_;

  my @filtered_dbas;

  my $all = $self->get_all();
  foreach my $dba ( values %{ $self->{dbas} } ) {
	if ( $dba->dbc->dbname eq $dbname ) {
	  push @filtered_dbas, $dba;
	}
  }

  return \@filtered_dbas;
}

=head2 get_all_taxon_ids
	Description : Return list of all taxon IDs registered with the helper
	Exceptions  : None
	Return type : Arrayref of integers
=cut

sub get_all_taxon_ids {
  my ($self) = @_;
  return [ keys( %{ $self->{dbas_by_taxid} } ) ];
}

=head2 get_all_names
	Description : Return list of all species names registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_names {
  my ($self) = @_;
  return [ keys( %{ $self->{dbas_by_name} } ) ];
}

=head2 get_all_accessions
	Description : Return list of all INSDC sequence accessions (or other seq_region names) registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_accessions {
  my ($self) = @_;
  return [ keys( %{ $self->{dbas_by_acc} } ) ];
}

=head2 get_all_versioned_accessions
	Description : Return list of all versioned INSDC sequence accessions (or other seq_region names) registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_accessions {
  my ($self) = @_;
  return [ keys( %{ $self->{dbas_by_vacc} } ) ];
}

=head2 get_all_assemblies
	Description : Return list of all INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_assemblies {
  my ($self) = @_;
  return [ keys( %{ $self->{dbas_by_gc} } ) ];
}

=head2 get_all_versioned_assemblies
	Description : Return list of all versioned INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
=cut

sub get_all_versioned_assemblies {
  my ($self) = @_;
  return [ keys( %{ $self->{dbas_by_vgc} } ) ];
}

=head2 register_all_dbs
	Description : Helper method to load the registry with all multispecies core databases on the supplied server
	Argument    : Host
	Argument    : Port
	Argument    : User
	Argument    : Password
	Argument    : (optional) String with database regexp (default is _collection_core_[0-9]_eVersion_[0-9]+)
	Exceptions  : None
	Return type : None
=cut

sub register_all_dbs {
  my ( $class, $host, $port, $user, $pass, $regexp ) = @_;

  if ( !$regexp ) {
	$regexp = '_core_[0-9]+_' . software_version() . '_[0-9]+';
  }

  if ( !defined $host ) {
	croak "Host must be supplied for registration of databases";
  }

  if ( !defined $port ) {
	croak
"Port must be supplied for registration of databases on host $host";
  }

  my $str = "DBI:mysql:host=$host;port=$port";
  my $dbh = DBI->connect( $str, $user, $pass ) ||
	croak "Could not connect to database $str (user=$user, pass=$pass)";

  my @dbnames =
	grep { m/$regexp/xi }
	map  { $_->[0] } @{ $dbh->selectall_arrayref('SHOW DATABASES') };

  for my $db (@dbnames) {
	if ( $db =~ m/.*_collection_core_.*/ ) {
	  _register_multispecies_core( $host, $port, $user, $pass, $db );
	}
	else {
	  _register_singlespecies_core( $host, $port, $user, $pass, $db );
	}
  }
  return;
} ## end sub register_all_dbs

=head2 _register_singlespecies_core
	Description : Register core dbas for all species in the supplied database
=cut

sub _register_singlespecies_core {
  my ( $host, $port, $user, $pass, $db ) = @_;
  my ( $species, $num ) = (
	$db =~ /(^[a-z]+_[a-z0-9]+(?:_[a-z0-9]+)?)  # species name
                     _
                     core                   # type
                     _
                     (?:\d+_)?               # optional endbit for ensembl genomes
                     (\d+)                   # databases release
                     _
                      /x );
  return
	Bio::EnsEMBL::DBSQL::DBAdaptor->new( -HOST    => $host,
										 -PORT    => $port,
										 -USER    => $user,
										 -PASS    => $pass,
										 -DBNAME  => $db,
										 -SPECIES => $species );
}

=head2 _register_multispecies_core
	Description : Register core dbas for all species in the supplied database
=cut

sub _register_multispecies_core {
  return _register_multispecies_x(
	'Bio::EnsEMBL::DBSQL::DBAdaptor',
	sub {
	  my %args = @_;
	  return Bio::EnsEMBL::DBSQL::DBAdaptor->new(%args);
	},
	@_ );
}

=head2 _register_multispecies_x
	Description : Register specified dba type for all species in the supplied database
=cut

sub _register_multispecies_x {

  my ( $adaptor, $closure, $host, $port, $user, $pass, $instance,
	   $species, $alias_arr_ref, $disconnect_when_idle )
	= @_;
  _runtime_include($adaptor);
  _check_name($instance);
  my %args =
	( _login_hash( $host, $port, $user, $pass ), '-DBNAME', $instance );
  my @species_array = @{ _query_multispecies_db( $species, %args ) };
  my @dbas;
  foreach my $species_args (@species_array) {
	my %new_args = ( %args, %{$species_args}, '-MULTISPECIES_DB' => 1 );
	$new_args{-DISCONNECT_WHEN_INACTIVE} = 1 if $disconnect_when_idle;
	my $dba = $closure->(%new_args);
	if ( defined $species && defined $alias_arr_ref ) {
	  _add_aliases( $species, $alias_arr_ref );
	}
	push( @dbas, $dba );
  }
  return \@dbas;
}

=head2 _query_multispecies_db
	Description : Find all species in the multispecies database
=cut

sub _query_multispecies_db {
  my ( $species, %db_args ) = @_;
  my @species_array;
  eval {
	my $dbh = Bio::EnsEMBL::DBSQL::DBConnection->new(%db_args);
	my $sql;
	my @params = ('species.db_name');

	if ( defined $species ) {
	  $sql =
'select meta_value, species_id from meta where meta_key =? and meta_value =?';
	  push( @params, $species );
	}
	else {
	  $sql =
'select distinct meta_value, species_id from meta where meta_key =? and species_id is not null';
	}
	my $sth = $dbh->prepare($sql);
	$sth->execute(@params);
	while ( my $row = $sth->fetchrow_arrayref() ) {
	  my ( $species_name, $species_id ) = @{$row};
	  push( @species_array,
			{ '-SPECIES'    => $species_name,
			  '-SPECIES_ID' => $species_id } );
	}
	$sth->finish();
  };
  throw("Error detected: $@") if $@;
  return \@species_array;
} ## end sub _query_multispecies_db

=head2 _add_aliases
	Description : Registry all aliases
	Argument	: Species name
	Argument	: Arrayref of alias strings
=cut

sub _add_aliases {
  my ( $species_name, $alias_ref ) = @_;
  if ( defined $alias_ref ) {
	if ( ref($alias_ref) ne 'ARRAY' ) {
	  $alias_ref = [$alias_ref];
	}

	if ( scalar( @{$alias_ref} ) > 0 ) {
	  Bio::EnsEMBL::Utils::ConfigRegistry->add_alias(
											  -species => $species_name,
											  -alias   => $alias_ref );
	}
  }
  return;
}

=head2 _runtime_include
	Description : Load the specified module (usually a DatabaseAdaptor)
	Argument 	: Module name
=cut

sub _runtime_include {
  my ($full_module) = @_;
  ## no critic (ProhibitStringyEval)
  eval "use ${full_module}" ||
	throw("Cannot import module '${full_module}': $@")
	if $@;
  ## use critic
  return;
}

=head2 _check_name
	Description : Check that the name is not longer than 64 characters
	Argument	: Name to check
=cut

sub _check_name {
  #Throws a wobbly if the db name is longer than 64 characters
  my ($name) = @_;
  my $length = length($name);
  throw(
"Invalid length for database name used. Max is 64. The name ${name}- was ${length}"
  ) if $length > 64;
  return;
}

=head2 _login_hash
	Description : Generate dbadaptor login hash from supplied arguments
	Argument	: Host
	Argument	: Port
	Argument	: User
	Argument	: Password
=cut

sub _login_hash {
  my ( $host, $port, $user, $pass ) = @_;
  my %details = ( -HOST => $host, -PORT => $port, -USER => $user );
  $details{-PASS} = $pass if defined $pass;
  return %details;
}

1;

