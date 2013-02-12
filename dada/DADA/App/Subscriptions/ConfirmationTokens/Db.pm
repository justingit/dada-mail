package DADA::App::Subscriptions::ConfirmationTokens::Db;
use lib qw(
  ../../../../
  ../../../../perllib
);

use Carp qw(croak carp);
use base qw(DADA::App::GenericDBFile);

sub new {
	my $class = shift;
	
	my ($args) = @_; 	

    my $self = SUPER::new $class (
    							  function => 'confirmation_tokens',
    							 );  
	
	$self->_init($args); 

	return $self;
}

sub _init { 
	my $self   = shift; 
	my ($args) = @_;
}

sub _backend_specific_save { 

	my $self   = shift; 
	my $token  = shift; 
	my $frozen = shift; 
	
	$self->_open_db; 
        $self->{DB_HASH}->{$token} = $frozen;
    $self->_close_db; 
}


sub fetch {
    my $self  = shift;
    my $token = shift;

	$self->_open_db; 
    my $frozen_data = $self->{DB_HASH}->{$token};
    $self->_close_db; 

    my $data = $self->_thaw($frozen_data);

    return $data;

}



sub remove_by_token {

    my $self  = shift;
    my $token = shift;

	$self->_open_db; 
    delete($self->{DB_HASH}->{$token});
    $self->_close_db; 

    return 1;

}

sub exists {
    my $self  = shift;
    my $token = shift;
	my $r = 0; 
	
	$self->_open_db; 
    if(exists($self->{DB_HASH}->{$token})) { 
		$r = 1; 
	}
    $self->_close_db; 
    return $r;
	
}


sub _remove_expired_tokens {
	return 1; 
}

DESTROY {}


1;