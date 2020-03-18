package Google::reCAPTCHA::v3;

use warnings; 
use strict;

use Carp qw(croak carp);
use Try::Tiny;
use LWP; 
use HTTP::Request::Common qw(POST);
use JSON qw( decode_json );

use vars qw($AUTOLOAD);
my %allowed = ( 
	request_url => 'https://www.google.com/recaptcha/api/siteverify',
	secret      => undef, 
	test        => 0, 
);

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;

    $self->_init($args);
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    # return if(substr($AUTOLOAD, -7) eq 'DESTROY');

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {
    my $self = shift;
    my ($args) = @_;
	
	if(exists($args->{-secret})){ 
		$self->secret($args->{-secret}); 
	}
	else {
		carp "You'll need to pass the Google reCAPTCHA v3 secret key to new()";
	}
	
}

sub request { 
	my $self = shift; 
	my ($args) = @_; 
	
	
	my $ua = LWP::UserAgent->new;
	
	if(!exists($args->{-response})){ 
		carp 'you will need to pass your response in -response to request()';
		return undef; 
	}
	
	my $req_params = { 
		response => $args->{-response},
	};
	
	if(exists($args->{-remoteip})){ 
    	$req_params->{remoteip} = $args->{-remoteip}; 
	}
	if(defined($self->secret)){ 
		$req_params->{secret} = $self->secret; 
	}
	my $req = POST $self->request_url(), [%{$req_params}];
	
	#return $ua->request($req)->as_string;
	
	my $json = JSON->new->allow_nonref;
	
	return $json->decode(
		$ua->request($req)->decoded_content
	);
	
	#$decoded_json
	
}

	
1;