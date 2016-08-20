package DADA::App::FormatMessages::Filters::CSSInliner;
use strict; 

use lib qw(
	../../../../
	../../../../DADA/perllib
); 

use vars qw($AUTOLOAD); 
use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts; 

use Carp qw(croak carp); 
#use Try::Tiny; 
use CSS::Inliner; 

# Need to ship with: 
use DADA::App::Guts; 

my $t = 1; 

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
		#warn '$html.0' . $html; 
		
		$html = $self->inject_stylesheet($html); 
		#warn '$html.1' . $html; 
		
	#	try{ 
	#		require CSS::Inliner; 
		my $inliner = CSS::Inliner->new(
			{
				leave_style => 0,
				relaxed     => 1
			}
		);
		$inliner->read(
			{
				html => $html,
			}
		);
		$html = $inliner->inlinify();
		$html = $self->only_body($html); 
		
	#	}
	#	catch { 
	#		carp 'Problems using CSS::Inliner: ' . $_; 
	#		return $args->{-html_msg};
	#	};
	
	# Soon. Soon!
	#use HTML::Packer;
	#use CSS::Packer;
	#my $minified = $PACKER->minify( \$inlined, {
	#    remove_comments => 1,
	#    remove_newlines => 1,
	#    do_stylesheet   => 'minify', # needs CSS::Packer
	#});
	
		#$html =~ m/body(.*?)>(.*?)<\/body>/;
		#my $body = $2; 
		#warn 'BODY:' . $body; 
	
		return $html; 
	}
	else { 
		croak "you MUST pass your HTML message in, 'html_msg'!"; 
	}
}


sub inject_stylesheet { 
	my $self = shift; 
	my $html = shift;
	
	my $css = $self->grab_css(); 
	
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
			<html> 
				<head> 
					$css
				</head>
				<body>
					$html
				</body 
			</html> 
		};
	}
	
	return $html;

}




sub grab_css { 
	my $self = shift;
	
	require  DADA::App::EmailThemes; 
	my $em = DADA::App::EmailThemes->new(
		{ 
			-name => 'default',
			-theme_dir => $DADA::Config::SUPPORT_FILES->{dir} . '/themes/email',
		}
	);
	
	return $em->app_css();

}




sub only_body { 
	
	my $self = shift; 
	my $html = shift; 
	
	try {
		require HTML::Parser; 
	}
	catch { 
		warn 'HTML::Parser not present? ' . $_;
		return $self->only_body_naive($html);
	};
	
	my $body = undef; 
	my $p = HTML::Parser->new( api_version => 3 );
	$p->handler( start => \&start_handler, "self,tagname,attr" );
	$p->parse($html);
	sub start_handler {
	    my $self = shift;
	    my $tagname  = shift;
	    my $attr = shift;
	    my $text = shift;
	    return unless ( $tagname eq 'body' );
	    $self->handler( start => sub { $body .= shift }, "text" );
	    $self->handler( text =>  sub { $body .= shift }, "text" );
	    $self->handler( default =>  sub { $body .= shift }, "text" );
	    $self->handler( comment =>  sub { $body .= shift }, "text" );
	    $self->handler( end  => sub {
	    my ($endtagname, $self, $text) = @_;
	         if($endtagname eq $tagname) {
	         $self->eof;
	         } else {
	              $body .= $text;
	        }
	    }, "tagname,self,text");
	 }
	 
	 if(! defined($body)){ 
		 warn "couldn't find body!";
		 return $html; 
	 }
	 else {
		 return $body; 
	 }
}

sub only_body_naive { 

	my $self = shift; 
	my $html = shift; 

	my $result = '';

	$html =~ s/\n//g; 
	if (
		$html =~ m/\<(.*?)body(.*?)\>(.*?)\<\/body\>/m
	) {
	    $result = $3;
	}
	$html = $result; 
	
	return $result; 

}




1;
