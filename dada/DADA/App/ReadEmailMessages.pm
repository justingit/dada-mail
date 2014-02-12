package DADA::App::ReadEmailMessages;

use lib qw(
  ../../.
  ../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use DADA::Template::Widgets;

use Carp qw(carp croak);
use Try::Tiny;
use Email::Address;
use MIME::Parser;

use vars qw($AUTOLOAD);
use strict;
my $t = 0;    # $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions};

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

    $self->_init( \%args );

    my $parser = new MIME::Parser;
    $parser = optimize_mime_parser($parser);

    $self->{parser} = $parser;

    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

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

sub _init { }

sub read_message {

    my $self = shift;
    my $tmpl = shift;

    my $entity = undef;
    my $eml = DADA::Template::Widgets::_raw_screen( { -screen => 'email/' . $tmpl } );

    if(! defined $eml) { 
        carp "can't find tmpl: 'email/$tmpl'!"; 
        return {}; 
    }
    
    eval { $entity = $self->{parser}->parse_data($eml); };
    if ($@) {
        warn "Trouble parsing $tmpl: $@";
        return {};
    }

    # This is highly simplistic, once we support more things, we'll make this
    # a little more sophisticated. 
    # 
    my $to_address = $entity->head->get( 'To', 0 );
    chomp($to_address);
    my $to_phrase = ( Email::Address->parse($to_address) )[0]->phrase;

    my $from_address = $entity->head->get( 'From', 0 );
    chomp($from_address);

    my $from_phrase = ( Email::Address->parse($from_address) )[0]->phrase;

    my $subject = $entity->head->get( 'Subject', 0 );
    chomp($subject);


    # So, for example, we won't assume PT is the first part, and HTML is the second
    
    my @parts          = $entity->parts;
    my $plaintext_body = $parts[0]->bodyhandle->as_string;
    my $html_body      = $parts[1]->bodyhandle->as_string;

    return {
        to_phrase      => $to_phrase,
        from_phrase    => $from_phrase,
        subject        => $subject,
        plaintext_body => $plaintext_body,
        html_body      => $html_body,
    };

}

1;
