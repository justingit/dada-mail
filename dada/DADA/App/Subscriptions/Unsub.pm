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
use DADA::App::Subscriptions::ConfirmationTokens; 

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
            croak "You MUST pass the, " . $_ . " parameter!";
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

	$self->{ct} = DADA::App::Subscriptions::ConfirmationTokens->new();


}


sub unsub_link {
	
    my $self = shift;
    my ($args) = @_;

    for ( '-mid', '-email' ) {
        if ( !exists( $args->{$_} ) ) {
            croak "You MUST pass the, " . $_ . " parameter!";
        }
    }

	my $token = $self->{ct}->save(
		{
			-email => $args->{-email},
			-data  => {
				list        => $self->{name}, 
				type        => 'list', 
				flavor      => 'unsub_confirm', 
				 mid        => $args->{-mid},
#				remote_addr => $ENV{REMOTE_ADDR}, 
				email_hint  => DADA::App::Guts::anonystar_address_encode($args->{-email}),
			},
#			-reset_previous_timestamp => 1, 
		}
	);

	return $DADA::Config::PROGRAM_URL . '/t/' . $token . '/'; 

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
