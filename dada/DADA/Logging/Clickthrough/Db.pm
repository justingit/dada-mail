package DADA::Logging::Clickthrough::Db;

use lib qw(../../../ ../../../DADA/perllib);

use base "DADA::App::GenericDBFile";

use strict;

use AnyDBM_File;
use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB);
use Carp qw(croak carp);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;    # For now, my dear.

sub new {

    my $class = shift;

    my ($args) = @_;

    my $self = SUPER::new $class ( function => 'clickthrough', );

    $self->{new_list} = $args->{ -new_list };
    $self->_init($args);

    return $self;
}

sub add {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url = shift;
    my $key = $self->random_key();

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    my $value = $self->encode_value( $mid, $url );

    if ($value) {
        $self->_open_db;
        $self->{DB_HASH}->{$key} = $value;
        $self->_close_db;
    }
    return $key;

}


sub encode_value {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url   = shift;
    my $value = undef;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    if ( $csv->combine( $mid, $url ) ) {
        $value = $csv->string;
    }
    else {

        croak "combine() failed on argument: ", $csv->error_input, "\n";

    }

    return $value;

}

sub decode_value {

    my $self  = shift;
    my $value = shift;

    die "no saved information! " if !defined $value;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    if ( $csv->parse($value) ) {
        my @fields = $csv->fields;
        return ( $fields[0], $fields[1] );

    }
    else {
        croak $DADA::Config::PROGRAM_NAME
          . " Error: CSV parsing error: parse() failed on argument: "
          . $csv->error_input() . ' '
          . $csv->error_diag();
        return ( undef, undef );
    }
}


sub reuse_key {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url = shift;

    my $value = $self->encode_value( $mid, $url );

    $self->_open_db;

    while ( my ( $k, $v ) = each( %{ $self->{DB_HASH} } ) ) {
        if ( $v eq $value ) {
            $self->_close_db;
            return $k;
        }
    }

    $self->_close_db;
    return undef;

}

sub fetch {

    my $self = shift;
    my $key  = shift;
    die "no key! " if !defined $key;

    my $mid;
    my $url;
    my $saved_info;

    $self->_open_db;
    if ( exists( $self->{DB_HASH}->{$key} ) ) {
        $saved_info = $self->{DB_HASH}->{$key};
        $self->_close_db;
    }
    else {
        $self->_close_db;
        warn "No saved information for: $key";
        return ( undef, undef );

        # ...
    }

    my ( $r_mid, $r_url ) = $self->decode_value($saved_info);

    return ( $r_mid, $r_url );
}


sub key_exists { 
		
	my $self = shift; 
	my ($args) = @_; 
	my $key = $args->{ -key }; 
	
	$self->_open_db;
    if(exists($self->{DB_HASH}->{$key})){ 
		$self->_close_db;
		return 1; 
	}
	else { 
		$self->_close_db;
		return 0; 
	}

}

sub _raw_db_hash {
    my $self = shift;
    $self->_lock_db;
    $self->_open_db;
    my %RAW_DB_HASH = %{ $self->{DB_HASH} };
    $self->{RAW_DB_HASH} = {%RAW_DB_HASH};
    $self->_close_db;
    $self->_unlock_db;
}

1;

=pod

=head1 NAME

DADA::MailingList::Clickthrough::Db

=head1 VERSION

Fill me in!
 
=head1 SYNOPSIS

Fill me in!

=head1 DESCRIPTION

Fill me in !
 
=head1 SUBROUTINES/METHODS 

Fill me in!

=head1 DIAGNOSTICS

Fill me in!

=head1 CONFIGURATION AND ENVIRONMENT

Fill me in!

=head1 DEPENDENCIES


Fill me in!


=head1 INCOMPATIBILITIES

Fill me in!

=head1 BUGS AND LIMITATIONS

Fill me in!

=head1 AUTHOR

Fill me in!

=head1 LICENCE AND COPYRIGHT

Fill me in!

=cut

