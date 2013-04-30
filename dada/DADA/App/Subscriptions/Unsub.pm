package DADA::App::Subscriptions::Unsub;
use strict;

use lib qw(
  ../../../
  ../../../perllib
);

use Carp qw(carp croak);

use DADA::Config qw(!:DEFAULT);
use DADA::Security::Password;
use DADA::MailingList::Settings;
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions};

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;

    $self->_init($args);
    return $self;
}

sub _init {
    my $self = shift;
    my ($args) = @_;

    for ('-list') {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " paramater!";
        }
    }

    croak "List doesn't exist!"
      if $self->_list_name_check( $args->{-list} ) == 0;

    if ( exists( $args->{-ls_obj} ) ) {
        $self->{ls} = $args->{-ls_obj};
    }
    else {
        $self->{ls} =
          DADA::MailingList::Settings->new( { -list => $self->{name} } );
    }
    $self->{begin_uu_str} = "begin 644 uuencode.uu\n";
    $self->{end_uu_str}   = "`\nend\n";

}

sub unsub_link {
    my $self = shift;
    my ($args) = @_;

    for ( '-mid', '-email' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " paramater!";
        }
    }

    my $hash = $self->make_unsub_hash($args);

    my $unsub_link = 
        $DADA::Config::PROGRAM_URL . '/' . 'u' . '/'
      . $self->{name} . '/'
      . $args->{-mid} . '/'
      . $hash . '/';
	if($self->{ls}->param('unsub_show_email_hint')){ 
		$unsub_link .= $self->unsub_hint({-email => $args->{-email}}) 
		. '/'; 
	}
}


sub unsub_hint { 
	my $self = shift; 
	my ($args) = @_; 
	for ('-email' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " paramater!";
        }
	}
    my ($n, $d) = split('@', $args->{-email}); 

	if(length($n) == 1){ 
		return '*/'. $d; 
	}
	else { 
		return 
		$self->perl_hex(substr($n, 0,1) 
		. '*' 
		. int((length($n) -1))) 
		. '/' 
		. 
		$self->perl_hex($d);  
	}
}

sub make_unsub_hash {
    my $self = shift;
    my ($args) = @_;

    for ( '-mid', '-email' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " paramater!";
        }
    }

    my $str = join( '.', $self->{name}, $args->{-mid}, $args->{-email}, );

    my $md5 = $self->md5hash( \$str );

    my $c_e = DADA::Security::Password::cipher_encrypt(
        $self->{ls}->param('cipher_key'), $md5 );

    my $begin_uu = $self->{begin_uu_str};
    my $end_uu   = $self->{end_uu_str};

    $c_e =~ s/^$begin_uu//;
    $c_e =~ s/$end_uu$//;

    # What could possible go wrong?
    $c_e =~ s/\n/\\n/g;

    my $hexed = $self->perl_hex($c_e);

    return $hexed;

}

sub validate_unsub {
    my $self = shift;
    my ($args) = @_;

    for ( '-mid', '-email', '-unsub_hash' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " paramater!";
        }
    }

    warn '$args->{-unsub_hash} ' . $args->{-unsub_hash}
      if $t;
    my $begin_uu = $self->{begin_uu_str};
    my $end_uu   = $self->{end_uu_str};

    my $str = $self->perl_dehex( $args->{-unsub_hash} );

    warn '$str ' . $str if $t;

    $str =~ s/\\n/\n/g;
    $str = $begin_uu . $str . $end_uu;

    warn '$str ' . $str if $t;

    $str = DADA::Security::Password::cipher_decrypt(
        $self->{ls}->param('cipher_key'), $str );

    warn '$str ' . $str if $t;

    my $s_str = join( '.', $self->{name}, $args->{-mid}, $args->{-email} );

    warn '$s_str ' . $s_str if $t;

    if ( $self->md5hash( \$s_str ) eq $str ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub md5hash {
    my $self = shift;
    my $data = shift;
    use Digest::MD5 qw(md5_hex);
    require Encode;
    my $cs = md5_hex($$data);
    return $cs;
}

# These are probably better handled by modules,
sub perl_hex {
    my $self = shift;
    my $s    = shift;
    $s =~ s/(.)/sprintf("%X",ord($1))/eg;
    return $s;
}

sub perl_dehex {
    my $self = shift;
    my $s    = shift;
    $s =~ s/([a-fA-F0-9][a-fA-F0-9])/chr(hex($1))/eg;
    return $s;
}

sub _list_name_check {
    my ( $self, $n ) = @_;
    $n = strip($n);
    return 0 if !$n;
    return 0 if $self->_list_exists($n) == 0;
    $self->{name} = $n;
    return 1;
}

sub _list_exists {
    my ( $self, $n ) = @_;
    return DADA::App::Guts::check_if_list_exists( -List => $n );
}

sub DESTROY { }

1;
