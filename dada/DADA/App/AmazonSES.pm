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

sub get_stats {
    my $self = shift;

    my $get_stats_script =
      $DADA::Config::AMAZON_SES_OPTIONS->{ses_get_stats_script};
    my $aws_credentials_file =
      $DADA::Config::AMAZON_SES_OPTIONS->{aws_credentials_file};

    my $result = `$get_stats_script -k $aws_credentials_file -q`;

    my ( $label, $data ) = split( "\n", $result );
    my ( $SentLast24Hours, $Max24HourSend, $MaxSendRate ) =
      split( /\s+/, $data );

    return ( $SentLast24Hours, $Max24HourSend, $MaxSendRate );

}

1;