
=pod
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
 
=cut

package Bio::EnsEMBL::LookUp;

use warnings;
use strict;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Scalar::Util qw(weaken);    #Used to not hold a strong ref to DBConnection
use DBI;
use JSON;
use LWP::Simple;
use Carp;
use Data::Dumper;
my $default_cache_file = qw/.ena_registry_cache.json/;

sub new {
	my ( $class, @args ) = @_;
	my ( $reg, $url, $file, $nocache, $cache_file, $clear_cache ) =
	  rearrange( [qw(registry url file no_cache cache_file clear_cache)],
				 @args );
	if ( !defined $reg ) { $reg = 'Bio::EnsEMBL::Registry' }
	my $self = bless( {}, ref($class) || $class );
	$self->{registry}      = $reg;
	$self->{dbas_by_taxid} = {};
	$self->{dbas_by_name}  = {};
	$self->{dbas_by_acc}   = {};
	$self->{dbas_by_vacc}  = {};
	$self->{dbas_by_gc}    = {};
	$self->{dbas_by_vgc}   = {};
	$self->{dbas}          = [];
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
	} elsif ( defined $url ) {
		$self->load_registry_from_url($url);
	} else {
		$self->update_from_registry();
	}
	if ( !$nocache && !-e $cache_file ) {
		$self->write_registry_to_file($cache_file);
	}
	return $self;
} ## end sub new

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

sub cache_file {
	my ( $self, $cache_file ) = @_;
	if ( defined $cache_file ) {
		$self->{cache_file} = $cache_file;
	}
	return $self->{cache_file};
}

sub update_from_registry {
	my ($self) = @_;
	$self->_intern_db_connections();
	for
	  my $dba ( @{ $self->registry()->get_all_DBAdaptors( -group => 'core' ) } )
	{
		$self->_hash_dba($dba);
	}
	return;
}

sub _register_dba {
	my ( $self, $species, $dba ) = @_;
	$self->registry()->add_DBAdaptor( $species, "core", $dba );
	$self->_hash_dba($dba);
	return;
}

sub _hash_dba {
	my ( $self, $dba ) = @_;
	my $meta       = $dba->get_MetaContainer();
	my $taxid      = $meta->get_taxonomy_id();
	my $aliases    = $meta->list_value_by_key('species.alias');
	my $vgc        = $meta->single_value_by_key('assembly.accession');
	my $sa         = $dba->get_SliceAdaptor();
	my $accessions = [];
	for my $slice ( @{ $sa->fetch_all("seqlevel") } ) {
		my $acc = $slice->seq_region_name();
		push( @{$accessions}, $acc );
	}
	$self->_hash_dba_from_values( $dba, [$taxid], $aliases, $accessions, $vgc );
	return;
}

sub _hash_dba_from_values {
	my ( $self, $dba, $taxids, $aliases, $accessions, $vgc ) = @_;

	for my $taxid ( @{$taxids} ) {
		push @{ $self->{dbas_by_taxid}{$taxid} }, $dba;
	}
	for my $name ( @{$aliases} ) {
		push @{ $self->{dbas_by_name}{$name} }, $dba;
	}
	for my $acc ( @{$accessions} ) {
		if ( defined $self->{dbas_by_vacc}{$acc} ) {
			croak "DBA with INSDC accession $acc already registered";
		}
		$self->{dbas_by_vacc}{$acc} = $dba;
		$acc =~ s/\.[0-9]+$//x;
		if ( defined $self->{dbas_by_acc}{$acc} ) {
			croak "DBA with INSDC accession $acc already registered";
		}
		$self->{dbas_by_acc}{$acc} = $dba;
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
	push @{ $self->{dbas} }, $dba;
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

sub _registry_to_hash {
	my ($self) = @_;
	# hash dbcs and dbas by locators
	my $dbc_hash;
	my $dba_hash;
	for my $dba ( @{ $self->{dbas} } ) {
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
			my $gc = $gc_hash->{$dba_loc};
			if(ref $gc eq 'ARRAY') {
				$gc = $gc->[0];
			}
			push @{ $dbc_h->{species} }, {
				species_id => $dba->species_id(),
				species    => $dba->species(),
				taxids     => $taxid_hash->{$dba_loc},
				aliases    => $name_hash->{$dba_loc},
				accessions => $acc_hash->{$dba_loc},
				gc         => $gc};
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
	} else {
		carp('No DBAs found');
	}
	return $json;
}

sub write_registry_to_file {
	my ( $self, $file ) = @_;
	my $json = $self->_registry_to_json();
	if ($json) {
		open( my $fh, '>', $file )
		  || croak "Cannot open '${file}' for writing: $!";
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

sub _load_registry_from_json {
	my ( $self, $json ) = @_;
	my $reg_arr = decode_json($json);
	for my $dbc_h ( @{$reg_arr} ) {
		my $dbc =
		  Bio::EnsEMBL::DBSQL::DBConnection->new(
												-driver   => $dbc_h->{driver},
												-host     => $dbc_h->{host},
												-port     => $dbc_h->{port},
												-user     => $dbc_h->{username},
												-password => $dbc_h->{password},
												-dbname   => $dbc_h->{dbname} );
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
			if ( ref $gc eq 'ARRAY' ) { $gc = $gc->[0]; };
			$self->_hash_dba_from_values( $dba, $species->{taxids},
									$species->{aliases}, $species->{accessions},
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
				 -password        => $dbc->password(),
				 -driver          => $dbc->driver(),
				 -dbname          => $dbc->dbname() ];
	return $args;
}

sub _dba_to_locator {
	my ($dba) = @_;
	confess("Argument must be Bio::EnsEMBL::DBSQL::DBAdaptor not " . ref($dba) )
	  unless ref($dba) eq "Bio::EnsEMBL::DBSQL::DBAdaptor";
	my $locator =
	  join( q{!-!}, $dba->species_id(), _dbc_to_locator( $dba->dbc() ) );
	return $locator;
}

sub _dbc_to_locator {
	my ($dbc) = @_;
	my $locator = join( q{!-!},
						$dbc->host(), $dbc->dbname(), $dbc->driver(),
						$dbc->port(), $dbc->username() );
	return $locator;
}

sub _intern_db_connections {
	my ($self) = @_;
	my $adaptors = $self->registry()->get_all_DBAdaptors();
	my %dbc_intern;
	foreach my $dba ( @{$adaptors} ) {
		my $dbc     = $dba->dbc();
		my $locator = _dbc_to_locator($dbc);
		if ( exists $dbc_intern{$locator} ) {
			$dba->dbc( $dbc_intern{$locator} );
		} else {
			$dbc_intern{$locator} = $dba->dbc();
		}
	}
	return;
}

sub get_all_DBConnections {
	my ($self) = @_;
	my $adaptors = $self->registry()->get_all_DBAdaptors();
	my %dbcs;
	foreach my $dba ( @{$adaptors} ) {
		my $dbc     = $dba->dbc();
		$dbcs{_dbc_to_locator($dbc)} = $dbc;
	}
	return [values %dbcs];
}

sub get_all {
	my ($self) = @_;
	return $self->{dbas};
}

sub get_all_by_taxon_id {
	my ( $self, $id ) = @_;
	return $self->{dbas_by_taxid}{$id}||[];
}

sub get_by_name_exact {
	my ( $self, $name ) = @_;
	return $self->{dbas_by_name}{$name};
}

sub get_by_accession {
	my ( $self, $acc ) = @_;
	my $dba = $self->{dbas_by_vacc}{$acc};
	if ( !defined $dba ) {
		$acc =~ s/\.[0-9]+$//x;
		$dba = $self->{dbas_by_acc}{$acc};
	}
	return $dba;
}

sub get_by_assembly_accession {
	my ( $self, $acc ) = @_;
	my $dba = $self->{dbas_by_vgc}{$acc};
	if ( !defined $dba ) {
		$acc =~ s/\.[0-9]+$//x;
		$dba = $self->{dbas_by_gc}{$acc};
	}
	return $dba;
}

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

sub get_all_taxon_ids {
	my ( $self  ) = @_;
	return [keys(%{$self->{dbas_by_taxid}})];
}

sub get_all_names {
	my ( $self  ) = @_;
	return [keys(%{$self->{dbas_by_name}})];
}

sub get_all_accessions {
	my ( $self  ) = @_;
	return [keys(%{ $self->{dbas_by_acc}})];
}

sub get_all_versioned_accessions {
	my ( $self  ) = @_;
	return [keys(%{ $self->{dbas_by_vacc}})];
}

sub get_all_assemblies {
	my ( $self  ) = @_;
	return [keys(%{ $self->{dbas_by_gc}})];
}

sub get_all_versioned_assemblies {
	my ( $self  ) = @_;
	return [keys(%{$self->{dbas_by_vgc}})];
}


sub register_all_dbs {
	my ( $class, $host, $port, $user, $pass, $regexp ) = @_;
	if ( !$regexp ) {
		$regexp =
		  '_core_[0-9]+_' . software_version() . '_[0-9]+';
	}
	my $str = "DBI:mysql:host=$host;port=$port";
	my $dbh = DBI->connect( $str, $user, $pass );

	my @dbnames =
	  grep { m/$regexp/xi }
	  map  { $_->[0] } @{ $dbh->selectall_arrayref('SHOW DATABASES') };

	for my $db (@dbnames) {
		_register_multispecies_core( $host, $port, $user, $pass, $db );
	}
	return;
}

sub _register_multispecies_core {
	return _register_multispecies_x(
		'Bio::EnsEMBL::DBSQL::DBAdaptor',
		sub {
			my %args = @_;
			return Bio::EnsEMBL::DBSQL::DBAdaptor->new(%args);
		},
		@_ );
}

sub _register_multispecies_x {

	my ( $adaptor, $closure, $host, $port, $user, $pass, $instance, $species,
		 $alias_arr_ref, $disconnect_when_idle )
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
		} else {
			$sql =
'select distinct meta_value, species_id from meta where meta_key =? and species_id is not null';
		}
		my $sth = $dbh->prepare($sql);
		$sth->execute(@params);
		while ( my $row = $sth->fetchrow_arrayref() ) {
			my ( $species_name, $species_id ) = @{$row};
			push( @species_array, {
					 '-SPECIES'    => $species_name,
					 '-SPECIES_ID' => $species_id } );
		}
		$sth->finish();
	};
	throw("Error detected: $@") if $@;
	return \@species_array;
} ## end sub _query_multispecies_db

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

sub _runtime_include {
	my ($full_module) = @_;
	## no critic (ProhibitStringyEval)
	eval "use ${full_module}"
	  || throw("Cannot import module '${full_module}': $@")
	  if $@;
	## use critic
	return;
}
#Throws a wobbly if the db name is longer than 64 characters
sub _check_name {
	my ($name) = @_;
	my $length = length($name);
	throw(
"Invalid length for database name used. Max is 64. The name ${name}- was ${length}"
	) if $length > 64;
	return;
}

sub _login_hash {
	my ( $host, $port, $user, $pass ) = @_;
	my %details = ( -HOST => $host, -PORT => $port, -USER => $user );
	$details{-PASS} = $pass if defined $pass;
	return %details;
}

1;

__END__

=pod

=head1 NAME

Bio::EnsEMBL::LookUp

=head1 SYNOPSIS

# creation from a database server
Bio::EnsEMBL::LookUp->register_all_dbs( $conf->{host},
	   $conf->{port}, $conf->{user}, $conf->{pass}, $conf->{db});
my $helper = Bio::EnsEMBL::LookUp->new();
my $dbas = $helper->registry()->get_all();
$dbas = $helper->get_all_by_taxon_id(388919);
$dbas = $helper->get_by_name_pattern("Escherichia.*");

# creation from a URL
my $helper = Bio::EnsEMBL::LookUp->new(-URL=>'http://www.ebi.ac.uk/ena/ena_genomes_registry.json');

=head1 DESCRIPTION

This module is a helper that provides additional methods to aid navigating a registry of >2000 species across >10 databases. 
It does not replace the Registry but provides some additional methods for finding species e.g. by searching for species that 
have an alias that match a regular expression, or species which are derived from a specific ENA/INSDC accession, or species
that belong to a particular part of the bacterial taxonomy. 

There are a number of ways of creating a helper. The simplest and fastest is to supply a URL for a JSON resource that contains all the details
needed to connect to the public ENA databases e.g.

	my $helper = Bio::EnsEMBL::LookUp->new(-URL=>'http://www.ebi.ac.uk/ena/ena_genomes_registry.json');

Alternatively, a local file containing the required JSON can be specified instead:

	my $helper = Bio::EnsEMBL::LookUp->new(-FILE=>"/path/to/reg.json");

Finally, a Registry already loaded with the ENA core databases can be supplied:

	my $helper = Bio::EnsEMBL::LookUp->new(-REGISTRY=>'Bio::EnsEMBL::Registry');

If the standard Registry is used, the argument can be omitted completely:

	my $helper = Bio::EnsEMBL::LookUp->new();

To populate the registry with just the ENA databases for the current software release on a specified server, the following method can be used:

	Bio::EnsEMBL::LookUp->register_all_dbs( $host,
	   $port, $user, $pass);

Once a helper has been created, there are various methods to retreive DBAdaptors for species of interest:

1. To find species by name - all DBAdaptors for species with a name or alias matching the supplied string:

	$dbas = $helper->get_by_name_exact('Escherichia coli str. K-12 substr. MG1655');

2. To find species by name pattern - all DBAdaptors for species with a name or alias matching the supplied regexp:

	$dbas = $helper->get_by_name_exact('Escherichia coli .*);

3. To find species with the supplied taxonomy ID:

	$dbas = $helper->get_all_by_taxon_id(388919);
	
4. In coordination with a taxonomy node adaptor to get DBAs for all descendants of a node:

	my $node = $node_adaptor->fetch_by_taxon_id(511145);
	for my $child (@{$node_adaptor->fetch_descendants($node)}) {
		my $dbas = $helper->get_all_by_taxon_id($node->taxon_id())
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

	my $args = $helper->dba_to_args($dba);
	... store and retrieve $args for use in another script ... 
	my $resurrected_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(@$args);

=head1 ATTRIBUTES

=head2 registry

  Arg [1]     : Registry module to use (default is Bio::EnsEMBL::Registry)
  Description : Sets and retrieves the Registry 
  Returntype  : Registry if set; otherwise undef
  Exceptions  : if an attempt is made to set the value more than once
  Status      : Stable

=head2 cache_file
  Arg [1]     : File to use for local caching
  Description : Sets and retrieves the local cache file 
  Returntype  : File name if set; otherwise undef
  Status      : Stable

=head1 SUBROUTINES/METHODS

=head2 new

  Description       : Creates a new instance of this object. 
  Arg [-REGISTRY]   : (optional) Registry module to use (default is Bio::EnsEMBL::Registry)
  Arg [-NO_CACHE]   : (optional) int 1
               This option will turn off the use of a local cache file for storing species details
  Arg [-CACHE_FILE] : (optional) String (default .ena_registry_cache.json)
  				This option allows use of a user specified local cache file
  Arg [-URL]		: (optional) 
              This option allows the use of a remote resource supplying species details in JSON format. This is not used if a local cache exists and -NO_CACHE is not set
  Arg [-FILE]		: (optional) 
              This option allows the use of a file supplying species details in JSON format. This is not used if a local cache exists and -NO_CACHE is not set
  Returntype        : Instance of helper
  Status            : Stable

  Example       	: 
  my $helper = Bio::EnsEMBL::LookUp->new(
                                        -REGISTRY => $reg);

=head2 get_all
	Description : Return all database adaptors that have been retrieved from registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor

=head2 get_all_DBConnections
	Description : Return all database connections used by the DBAs retrieved from the registry
	Argument    : None
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DBConnection

=head2 get_by_accession
	Description : Returns the database adaptor that contains a seq_region with the supplied INSDC accession
	Argument    : Int
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DatabaseAdaptor
	
=head2 get_by_assembly_accession
	Description : Returns the database adaptor that contains the assembly with the supplied INSDC assembly accession
	Argument    : Int
	Exceptions  : None
	Return type : Bio::EnsEMBL::DBSQL::DatabaseAdaptor

=head2 get_all_by_taxon_id
	Description : Returns all database adaptors that have the supplied taxonomy ID
	Argument    : Int
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor

=head2 get_by_name_exact
	Description : Return all database adaptors that have the supplied string as an alias/name
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor

=head2 get_by_name_pattern
	Description : Return all database adaptors that have an alias/name that match the supplied regexp
	Argument    : String
	Exceptions  : None
	Return type : Arrayref of Bio::EnsEMBL::DBSQL::DatabaseAdaptor
	
=head2 get_all_taxon_ids
	Description : Return list of all taxon IDs registered with the helper
	Exceptions  : None
	Return type : Arrayref of integers

=head2 get_all_names
	Description : Return list of all species names registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings

=head2 get_all_accessions
	Description : Return list of all INSDC sequence accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings

=head2 get_all_versioned_accessions
	Description : Return list of all versioned INSDC sequence accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings

=head2 get_all_assemblies
	Description : Return list of all INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings

=head2 get_all_versioned_assemblies
	Description : Return list of all versioned INSDC assembly accessions registered with the helper
	Exceptions  : None
	Return type : Arrayref of strings
	
=head2 register_all_dbs
	Description : Helper method to load the registry with all ENA databases on the supplied server
	Argument    : Host
	Argument    : Port
	Argument    : User
	Argument    : Password
	Argument    : (optional) String with ENA database regexp (default is ena_[0-9]+_collection_core_.*)
	Exceptions  : None
	Return type : None

=head2  update_from_registry
	Description : Update internal hashes of database adaptors by name/taxids from the registry. Invoke when registry has been updated independently.
	Exceptions  : None

=head2 register_dba
	Description	: Add a single DBAdaptor to the registry and the internal hashes of details
	Argument	: Bio::EnsEMBL::DBAdaptor
	Return		: None

=head2 write_registry_to_file
	Description	: Write the contents of the registry and species lists to a JSON file
	Argument	: File name
	Return		: None

=head2 dba_to_args
	Description	: Dump the arguments needed for contructing a DBA
	Argument	: Bio::EnsEMBL::DBAdaptor
	Return		: Arrayref of args

=head1 INTERNAL METHODS

=head2 _hash_dba
	Description : Add details from a DBAdaptor to the internal hashes of details
	Argument	: Bio::EnsEMBL::DBAdaptor

=head2 _hash_dba_from_values
	Description : Add supplied details to the internal hashes of details
	Argument	: Bio::EnsEMBL::DBAdaptor to hash
	Argument	: Arrayref of taxonomy IDs to use as keys
	Argument	: Arrayref of aliases to use as keys
	Argument	: Arrayref of ENA accessions to use as keys

=head2 _registry_to_hash
	Description	: Generate a hash array structure for the current registry and species details for turning to JSON
	Returns		: Arrayref of hashes

=head2 _load_registry_from_json
	Description	: load the registry from the supplied JSON string
	Argument	: JSON string

=head2 _dba_to_locator
	Description : return a hash key for a DBAdaptor
	Argument	: Bio::EnsEMBL::DBAdaptor

=head2 _dbc_to_locator
	Description : return a hash key for a DBConnection
	Argument	: Bio::EnsEMBL::DBConnection

=head2 _register_multispecies_core
	Description : Register core dbas for all species in the supplied database

=head2 _register_multispecies_x
	Description : Register specified dba type for all species in the supplied database

=head2 _query_multispecies_db
	Description : Find all species in the multispecies database

=head2 _add_aliases
	Description : Registry all aliases
	Argument	: Species name
	Argument	: Arrayref of alias strings

=head2 _runtime_include
	Description : Load the specified module (usually a DatabaseAdaptor)
	Argument 	: Module name

=head2 _check_name
	Description : Check that the name is not longer than 64 characters
	Argument	: Name to check

=head2 _login_hash
	Description : Generate dbadaptor login hash from supplied arguments
	Argument	: Host
	Argument	: Port
	Argument	: User
	Argument	: Password

=head2 _intern_db_connections()
  Description : Go through all available DBAdaptors of registry and ensure they use the same
                DBConnection instance.
  Exceptions  : None
  Status      : At Risk
  
=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$

=cut
