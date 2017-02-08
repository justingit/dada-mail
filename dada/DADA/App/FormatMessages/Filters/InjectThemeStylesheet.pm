package DADA::App::FormatMessages::Filters::InjectThemeStylesheet;
use strict; 

use lib qw(
	../../../../
	../../../../DADA/perllib
); 

use vars qw($AUTOLOAD); 
use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts; 

use Carp qw(croak carp); 
use Try::Tiny; 
use CSS::Inliner; 

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


sub filter { 
	my $self   = shift; 
	my ($args) = @_; 
	my $html;
	
	if(exists($args->{-html_msg})){ 
		$html = $args->{-html_msg};		
		$html = $self->inject_stylesheet({
			-str => $html, 
			-list => $args->{-list}, 
		}); 		
		return $html; 
	}
	else { 
		croak "you MUST pass your HTML message in, 'html_msg'!"; 
	}
}


sub inject_stylesheet { 
	my $self = shift; 
	
	my ($args) = @_; 
	
	my $html = $args->{-str};
	
	my $css = $self->grab_css($args->{-list}); 
	
	$css = qq{ 
		<!-- start injected css -->
		<style type="text/css"> 
			$css
		</style> 
		<!-- end injected css -->
	};
	
	# NAIVE:
	# Well, does it have a body?  
	if($html =~ m/\<body/i){ 
		$html =~ s/\<body/\n$css\n<body/i;
	}
	else { 
		$html = qq{

			<!-- no body was found ?! -->
			<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
			"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

			<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
			    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
			    <meta name="viewport" content="width=device-width">
			  </head>
			  $css
			    <!-- body from InjectThemeStylesheet -->
				<body>
			  	$html
			  </body>
			 </html> 
		};
	}
	
	return $html;

}




sub grab_css { 
	my $self = shift;
	my $list = shift; 
	require  DADA::App::EmailThemes; 
	my $em = DADA::App::EmailThemes->new(
		{ 
			-list   => $list,
		}
	);
	
	return $em->app_css();

}
1;
