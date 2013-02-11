package DADA::App::Subscriptions::ConfirmationTokens;

use lib qw(
	../../../ 
	../../../perllib
);

use Carp qw(croak carp); 
use Try::Tiny; 

use base qw(DADA::App::Subscriptions::ConfirmationTokens::baseSQL); 


sub new {
	
	my $class = shift;	
	my ($args) = @_; 
	
	my $self = {};			
	bless $self, $class;

	$self->_init($args); 
	$self->_sql_init(); 

	return $self;
}

sub _init  { 
    my $self   = shift; 
	my ($args) = @_; 
}

sub token { 
	my $self = shift; 
	
	require DADA::Security::Password; 
	my $str = DADA::Security::Password::generate_rand_string(undef, 40);
	try { 
		# Entirely unneeded: 
		require Digest::SHA1;
		$str = Digest::SHA1->new->add('blob '.length($str)."\0".$str)->hexdigest(), "\n";
	}
	return $str; 
}



1; 