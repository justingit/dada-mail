package DADA::App::FormatMessages::Filters::HTMLMinifier;
use strict; 


warn 'in DADA::App::FormatMessages::Filters::HTMLMinifier';

use lib qw(
	../../../../
	../../../../DADA/perllib
); 

use vars qw($AUTOLOAD); 
use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts; 

use Carp qw(croak carp); 
use Try::Tiny; 


# Need to ship with: 
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

	return if(substr($AUTOLOAD, -7) eq 'DESTROY');
   	
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

sub can_use_filter { 
	my $self = shift;
	try { 
		require HTML::Packer; 
	} catch { 
		warn 'cannot use HTML::Packer:' . $_; 
		return 0;
	};
	return 1; 
}

sub can_use_CSS_Packer { 
	my $self = shift;
	try { 
		require CSS::Packer; 
	} catch { 
		return 0;
	};
	return 1; 
}

sub filter { 
	my $self   = shift; 
	my ($args) = @_; 
	my $html;
	
	if(exists($args->{-html_msg})){ 
		$html = $args->{-html_msg};		
		
		return $html 
			if ! $self->can_use_filter;
			
		require HTML::Packer; 
		
		my $p  = HTML::Packer->init;
		my $minified; 
		if($self->can_use_CSS_Packer) {
			$minified = $p->minify( \$html, {
			    remove_comments => 0,
			    remove_newlines => 1,
			    do_stylesheet   => 'minify',
			});
		}
		else { 
			if($self->can_use_CSS_Packer) {
				$minified = $p->minify( \$html, {
				    remove_comments => 0,
				    remove_newlines => 1,
				   # do_stylesheet   => 'minify',
				});
			}
				
		}
		# warn '$minified' . $minified; 
		return $minified; 
			
	}
	else { 
		croak "you MUST pass your HTML message in, 'html_msg'!"; 
	}
}




1;
