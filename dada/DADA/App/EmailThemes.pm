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
my $t = 0;

my %allowed = ( 
    list      =>  undef, 
	name      => 'default',
	theme_dir => '', 
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

    $self->_init( $args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

	return if(substr($AUTOLOAD, -7) eq 'DESTROY');

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

	if(exists($args->{-list})){ 
		$self->list($args->{-list}); 
	}
	if(exists($args->{-name})){ 
		$self->name($args->{-name}); 
	}
	if(exists($args->{-theme_dir})){ 
		$self->theme_dir($args->{-theme_dir}); 
	}
}

sub fetch { 
	my $self = shift; 
	my $fn   = shift; 
	
	my $pt_file   = make_safer($self->theme_dir . '/' . $self->name . '/dist/' . $fn . '.txt');
	my $html_file = make_safer($self->theme_dir . '/' . $self->name . '/dist/' . $fn . '.html');
	
	my $pt   = undef; 
	my $html = undef; 
	
	if(-e $pt_file) {
		$pt = $self->slurp($pt_file);
	}
	if(-e $html_file) {
		$html = $self->slurp($html_file); 
		if(defined($self->list)){ 
			$html = $self->munge_logo_img($html);
		}
	}
	
	my $subject; 
	if(length($pt) > 0){
		my $yaml = {};
		($yaml, $pt) = $self->strip_and_return_yaml($pt); 
		$subject = $yaml->{subject};
	}
	if(length($html) > 0){
		$subject = $self->subject_from_title_tag($html); 
	}
		
	warn '$subject' . $subject; 
	
	my $r = { 
		html      => $html, 
		plaintext => $pt, 
		subject   => $subject, 
	};
	
	use Data::Dumper; 
	warn Dumper($r);
	
	return $r; 
}


sub strip_and_return_yaml { 
	
	require Text::FrontMatter::YAML;
	my $self = shift; 
	my $str  = shift; 
	
	return ({}, $str) 
		if $str !~ m/$\-\-\-/; 
		
	try {
		my $tfm = Text::FrontMatter::YAML->new(
			document_string => $str,
		);
		my @r = (
			$tfm->frontmatter_hashref, 
			$tfm->data_text,
		);
		return @r; 
	} catch { 
		warn $_; 
		return (undef, $str);
	}
}




sub munge_logo_img { 
	my $self = shift; 
	my $html = shift; 
	# This is cheating: 
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->list } );
	my $tag       = quotemeta('<!-- tmpl_var list_settings.logo_image_url -->');
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

sub subject_from_title_tag {

    my $self = shift;
    my $html = shift; 

    try {
        
        require HTML::Element;
        require HTML::TreeBuilder;
        
        my $root = HTML::TreeBuilder->new(
            ignore_unknown      => 0,
            no_space_compacting => 1,
            store_comments      => 1,
        );
        
        $root->parse($html);
        $root->eof();
        $root->elementify();

        my $title_ele = $root->find_by_tag_name('title');
        return $title_ele->as_text;
    }
    catch {
		warn 'fallack to regex: ' . $_; 
        # aaaaaand if that does work, regex to the rescue!
        my ($title) = $html =~ m/<title>([a-zA-Z\/][^>]+)<\/title>/si;
        if ( defined($title) ) {
            return $title;
        }
        else {
            return undef;
        }
    };
}




sub app_css { 
	my $self = shift; 
	return $self->slurp($self->theme_dir . '/' . $self->name . '/dist/css/app.css');
}



1; 
