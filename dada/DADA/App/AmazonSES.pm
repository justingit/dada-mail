package DADA::App::AmazonSES; 

use lib qw(
	../../ 
	../../DADA/perllib
);

use vars qw($AUTOLOAD); 
use Carp qw(croak carp);

my %allowed = (); 

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my %args = (@_); 
		
   $self->_init(\%args); 
   return $self;
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init { 

	my $self = shift; 
		
}

sub verify_sender { 
	my $self = shift; 
	my ($args) = @_; 
	
	require Net::Amazon::SES; 
	my $ses_obj = Net::Amazon::SES->new( $DADA::Config::AMAZON_SES_OPTIONS ); 

	my ($status, $result) = $ses_obj->verify_sender($args);
	
	return ($status, $result);
}




sub get_stats {
    my $self = shift;
	my ($args) = @_; 
	
	if(! exists($args->{AWSAccessKeyId}) || ! exists($args->{AWSSecretKey})) { 
		$args = $DADA::Config::AMAZON_SES_OPTIONS, 
	}
	require Net::Amazon::SES; 
	my $ses_obj = Net::Amazon::SES->new( $args ); 

	my ($status, $result) = $ses_obj->get_stats();
	
	if($status != 200) { 
		return ($status, undef, undef, undef); 
	}
	else { 
	    my ( $label, $data ) = split( "\n", $result );
	    my ( $SentLast24Hours, $Max24HourSend, $MaxSendRate ) =
	      split( /\s+/, $data );

	    return ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
	}
}

1;