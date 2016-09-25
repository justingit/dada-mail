package DADA::App::FormatMessages::Filters::BodyContentOnly;
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
use HTML::Parser; 

my $t = 0; 
my $body            = undef;


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
	
	if(exists($args->{-html_msg})){ 
		my $tmp = $args->{-html_msg}; 
		
		if($tmp =~ m/<(.*?)body(.*?)\>/) {
		
			$tmp = $self->body_content_only($tmp);
			return $tmp; 
		}
		else { 
		
			warn 'HTML doc passed with no body tag?!';
			return $tmp; 
		}
	}
	else { 
		croak "you MUST pass your HTML message in, 'html_msg'!"; 
	}
}

sub body_content_only {
    my $self            = shift;
    my $html            = shift;
   
    my $has_HTML_Parser = 1;
	
    try {
        require HTML::Parser;
    }
    catch {
        $has_HTML_Parser = 0;
    };

    if ( $has_HTML_Parser == 0 ) {
		return $self->naive_body_only($html); 
    }
    else {
        my $p = HTML::Parser->new( api_version => 3 );
        $p->handler( 
			start => \&start_handler, 
			"self,tagname,attr" 
		);
        $p->parse($html); 
		
		if ( !defined($body) ) {
			return $self->naive_body_only($html); 
		}
		else {
			my $r = $body; 
			undef($body);
		    return $r;
		}
    }
}


sub start_handler {

    my $hself    = shift;
    my $tagname = shift;
    my $attr    = shift;
    my $text    = shift;

    return unless ( $tagname eq 'body' );


    $hself->handler( start   => sub { $body .= shift }, "text" );
    $hself->handler( text    => sub { $body .= shift }, "text" );
    $hself->handler( default => sub { $body .= shift }, "text" );
    $hself->handler( comment => sub { $body .= shift }, "text" );
    $hself->handler(
        end => sub {
            my ( $endtagname, $hself, $text ) = @_;
            if ( $endtagname eq $tagname ) {
                $hself->eof;
            }
            else {
                $body .= $text;
            }
        },
        "tagname,self,text"
    );
	
	
	
}


sub naive_body_only { 
	my $self = shift; 
	my $html = shift; 
	
    $html =~ s/\n//g;
    if ( $html =~ m/\<(.*?)body(.*?)\>(.*?)\<\/body\>/m
	 ) {
        $body = $3;
    }
	my $r = $body; 
	my $body = undef; 
    return $r;
	
}


sub DESTORY { 
	undef $body; 
}

1;
