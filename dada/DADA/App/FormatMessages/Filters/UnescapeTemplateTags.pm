package DADA::App::FormatMessages::Filters::UnescapeTemplateTags;
use strict; 

use lib qw(
	../../../../
	../../../../DADA/perllib
); 

use vars qw($AUTOLOAD); 
use DADA::Config qw(!:DEFAULT);

use Carp qw(croak carp); 
use HTML::LinkExtor; 
use URI::file; 
use URI; 

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
		$args->{-html_msg} = $self->unescape_template_tags($args->{-html_msg}); 
		$args->{-html_msg} = $self->remove_ckeditor_strangeness($args->{-html_msg}); 
		return $args->{-html_msg}; 
	}
	else { 
		croak "you MUST pass your HTML message in, 'html_msg'!"; 
	}

}
sub unescape_template_tags { 
	my $self = shift; 
	my $str  = shift; 

	# Regular
	# Start Tags
	$str =~ s/(&lt;!--(\s+)tmpl_)(.*?)(--&gt;)/<!-- tmpl_$3-->/g;
	$str =~ s/(&lt;!--(\s+)TMPL_)(.*?)(--&gt;)/<!-- TMPL_$3-->/g;

	# End Tags
	$str =~ s/(&lt;!--(\s+)\/tmpl_)(.*?)(--&gt;)/<!-- \/tmpl_$3-->/g;
	$str =~ s/(&lt;!--(\s+)\/TMPL_)(.*?)(--&gt;)/<!-- \/TMPL_$3-->/g;
	

	# Consice
	# Start Tags
	$str =~ s/(&lt;tmpl_)(.*?)&gt;/<tmpl_$2>/g;
	$str =~ s/(&lt;TMPL_)(.*?)&gt;/<TMPL_$2>/g;

	# End Tags
	$str =~ s/(&lt;\/tmpl_)(.*?)&gt;/<\/tmpl_$2>/g;
	$str =~ s/(&lt;\/TMPL_)(.*?)&gt;/<\/TMPL_$2>/g;
	
	return $str; 
	
}

sub remove_ckeditor_strangeness { 
	my $self = shift; 
	my $str  = shift; 
	
	# Brute force attack! 
	$str =~ s/href\=(\"|\')((\{C\})+)/href\=$1/g; 

# Oh oh! But there's more! 
my $empty_body = 
quotemeta(q|<body id="cke_pastebin" style="position: absolute; top: 116px; width: 1px; height: 1px; overflow: hidden; left: -1000px; ">

</body>|);

	$str =~ s/$empty_body//;
	
	return $str; 
}




1;
