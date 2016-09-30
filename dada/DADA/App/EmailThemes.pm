package DADA::App::EmailThemes;

use lib qw(
  ../../.
  ../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

use Carp qw(carp croak);
use Try::Tiny;

use vars qw($AUTOLOAD);
use strict;
my $t = 1;

my %allowed = (
    list      => undef,
    name      => 'default',
	theme_dir => $DADA::Config::SUPPORT_FILES->{dir} . '/themes/email', 
	name      => 'default',
	cache     => 0,
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

    return if ( substr( $AUTOLOAD, -7 ) eq 'DESTROY' );

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

    if ( exists( $args->{-list} ) ) {
        $self->list( $args->{-list} );
    }
    if ( exists( $args->{-name} ) ) {
        $self->name( $args->{-name} );
    }
    if ( exists( $args->{-theme_dir} ) ) {
        $self->theme_dir( $args->{-theme_dir} );
    }
    if ( exists( $args->{-cache} ) ) {
        $self->cache( $args->{-cache} );
    }
	
	$self->{tmp_store} = {}; 
	
}

sub fetch {
    my $self = shift;
    my $fn   = shift;
	
	if(!defined($fn)) { 
		warn 'you need to pass the name of the theme file you want returned';
		return {};
	}
	
	if($self->cache() == 1 && exists($self->{tmp_store}->{$fn})){ 
		return $self->{tmp_store}->{$fn};
	}
	else { 
	
	    my $pt_file = make_safer(
	        $self->theme_dir . '/' . $self->name . '/dist/' . $fn . '.txt' );
	    my $html_file = make_safer(
	        $self->theme_dir . '/' . $self->name . '/dist/' . $fn . '.html' );

	    my $pt   = undef;
	    my $html = undef;

	    if ( -e $pt_file ) {
	        $pt = $self->slurp($pt_file);
	    }
	    else {
	        warn '$pt_file does not exist at, ' . $pt_file;
	    }
	    if ( -e $html_file ) {
	        $html = $self->slurp($html_file);
	        if ( defined( $self->list ) ) {
	            $html = $self->munge_logo_img($html);
	        }
	    }
	    else {
	        warn '$html_file does not exist at, ' . $html_file;
	    }

	    my $vars = {};
	    if ( length($pt) > 0 ) {
	        ( $vars, $pt ) = $self->strip_and_return_vars($pt);
	    }

	    my $r = {
	        html      => $html,
	        plaintext => $pt,
	        vars      => $vars,
	    };

		if($self->cache() == 1){ 
			$self->{tmp_store}->{$fn} = $r; 
		}
		return $r;
	}
}

sub strip_and_return_vars {

    require Text::FrontMatter::YAML;
    my $self = shift;
    my $str  = shift;

    return ( {}, $str )
      if $str !~ m/$\-\-\-/;

    try {
        my $tfm = Text::FrontMatter::YAML->new( document_string => $str, );
        my @r = ( $tfm->frontmatter_hashref, $tfm->data_text, );
        return @r;
    }
    catch {
        warn $_;
        return ( undef, $str );
    }
}

sub munge_logo_img {
    my $self = shift;
    my $html = shift;

    # This is cheating:
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->list } );
    my $tag = quotemeta('<!-- tmpl_var list_settings.logo_image_url -->');
    my $tag_value = $ls->param('logo_image_url');
    $html =~ s/$tag/$tag_value/g;
    return $html;
}

sub slurp {

    my $self = shift;
    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open( F, '<:encoding(UTF-8)', $file )
      || croak "open $file: $!";
    @r = <F>;
    close(F) || croak "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}




sub app_css {
    my $self = shift;
    return $self->slurp(
        $self->theme_dir . '/' . $self->name . '/dist/css/app.css' );
}

1;
