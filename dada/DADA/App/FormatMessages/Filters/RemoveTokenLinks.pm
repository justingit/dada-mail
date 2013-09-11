package DADA::App::FormatMessages::Filters::RemoveTokenLinks;
use strict; 

use lib qw(
	../../../../
	../../../../DADA/perllib
); 

use vars qw($AUTOLOAD); 
use DADA::Config qw(!:DEFAULT);

use Carp qw(croak carp);  

use DADA::App::Guts; 

my $t = 0; 

my %allowed = (

);

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my $args = (@_); 
    
   $self->_init($args); 
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





sub _init  {

	my $self    = shift; 
	my ($args)  = @_;
	
}


sub filter { 
	my $self   = shift; 
	my ($args) = @_; 
	my $html;
	
	if(exists($args->{-data})){ 
		$args->{-html_msg} = $self->remove_unsub_links($args->{-data}); 
		return $args->{-html_msg}; 
	}
	else { 
		croak "you MUST pass your HTML message in, 'html_msg'!"; 
	}

}


sub remove_unsub_links { 
	my $self = shift; 
	my $str  = shift; 
	# list mid hash
	
	# This is for a hint
	$str =~ s{$DADA::Config::PROGRAM_URL/t/([a-zA-Z0-9_]*?)/}{$DADA::Config::PROGRAM_URL/t/REMOVED/}g;
	
	
	return $str; 
	
}




1;
