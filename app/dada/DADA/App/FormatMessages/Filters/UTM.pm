package DADA::App::FormatMessages::Filters::UTM;

use lib qw(
  ../../../../
  ../../../../DADA/perllib
);

use v5.10;

use URI::URL;
use URI::QueryParam;
use URI::Find;
use Try::Tiny;

require Exporter;

#@ISA    = qw(Exporter);
#@EXPORT = qw();
use vars qw(@EXPORT $AUTOLOAD);

use Carp qw(carp croak);
use strict;
my %allowed = (
    domains => undef,
    utm     => {
        source   => undef,
        medium   => undef,
        campaign => undef,
        term     => undef,
        content  => undef,
    },
);

my $t = 0;

sub new {

    warn 'new' if $t;

    my $that = shift;

    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;
    my ($args) = @_;

    #use Data::Dumper;
    #warn Dumper($args);

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

    warn 'init' if $t;

    my $self = shift;
    my ($args) = @_;

    $self->utm( $args->{-utm} );
    $self->domains( $args->{-domains} );
}

sub filter {

    warn 'filter' if $t;
    my $self = shift;
    my ($args) = @_;

    if ( $args->{-type} =~ m/html/ ) {

        warn 'HTML!' if $t;

        return $self->add_utm_html( $args->{-data} );
    }
    else {
        warn 'Text!' if $t;

        return $self->add_utm_text( $args->{-data} );
    }
}

sub add_utm_html {

    my $self = shift;
    my $s    = shift;

    require HTML::Tree;
    require HTML::Element;
    require HTML::TreeBuilder;

    my $tree = HTML::TreeBuilder->new(
        ignore_unknown      => 0,
        no_space_compacting => 1,
        store_comments      => 1,
        no_expand_entities  => 1,

        # ignore_ignorable_whitespace
        # no_space_compacting
    );

    $tree->parse($s);
    $tree->eof();

    #$tree->elementify();

    my @a_tags = $tree->look_down( '_tag', 'a' );
    for my $t (@a_tags) {

        my %attrs = $t->all_attr();

        next if $attrs{href} =~ m/\<\!\-\-/;
        next if $attrs{href} =~ m/\<\?/;

        # print $attrs{href} . "\n";

        # warn '$t->as_text' . $t->as_text;
        my %utms = ( term => $self->strip( $t->as_text ), );

        for (qw(source medium campaign term content)) {
            if ( exists( $attrs{ 'data-utm_' . $_ } ) ) {
                $utms{$_} = $attrs{ 'data-utm_' . $_ };
            }
        }

        # Slight sanity check:
        for ( keys %utms ) {
            if ( length( $utms{$_} ) > 1024 ) {
                $utms{$_} = substr( $utms{$_}, 0, 1023 );
            }
        }

        my $utmd = $self->add_utm_to_url(
            {
                -url => $attrs{href},
                -utm => {%utms}
            }
        );

        $t->attr( 'href', $utmd );
    }

    $s = $tree->as_HTML( undef, '  ' );
    $tree->delete;

    return $s;

}

sub add_utm_text {

    my $self = shift;
    my $s    = shift;

    #require DADA::Security::Password;

    # Find me the URLs in this string!
    my @uris;
    my $finder = URI::Find->new(
        sub {
            my ($uri) = shift;
            push( @uris, $uri->as_string );
            warn '$uri: ' . $uri
              if $t;
            return $uri;
        }
    );
    $finder->find( \$s );

    my $links = [];

    # Get only unique URLS:
    my %seen;
    my @unique_uris = grep { !$seen{$_}++ } @uris;

    # Sort by longest, to shortest:
    @unique_uris = sort { length $b <=> length $a } @unique_uris;

    for my $specific_url (@unique_uris) {

        push(
            @$links,
            {
                orig  => $specific_url,
                utmd  => $self->add_utm_to_url( { -url => $specific_url } ),
                regex => quotemeta($specific_url),
            },
        );

    }

    # Switch 'em out so my regex is...somewhat simple:
    my %out_of_the_way;

    # DADA::Security::Password::
    for my $l (@$links) {
        my $key = '_UTM_TMP_'
          . $self->generate_rand_string( '1234567890abcdefghijklmnopqestuvwxyz',
            16 )
          . '_UTM_TMP_';
        $out_of_the_way{$key} = $l;
        my $qm_l = $l->{regex};
        $s =~ s/$qm_l/$key/g;
    }

    for ( keys %out_of_the_way ) {
        my $str = $out_of_the_way{$_}->{utmd};
        $s =~ s/$_/$str/g;
    }

    return $s;

}

sub generate_rand_string {

    my $self = shift;

    my $chars = shift
      || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    my $num = shift || 8;

    my @chars = split '', $chars;
    my $password;
    for ( 1 .. $num ) {
        $password .= $chars[ rand @chars ];
    }
    return $password;
}

sub add_utm_to_url {

    warn 'add_utm_to_url'
      if $t;

    my $self = shift;
    my ($args) = @_;

    my $og_url   = $args->{-url};
    my $alt_utms = $args->{-utm};

    my @domains = ();
    my $domains = {};

    if ( defined( $self->domains() ) ) {
        @domains = split( /\s+/, $self->domains() );
        for (@domains) {
            next if $_ eq '';
            next if length($_) <= 3;
            $domains->{$_} = 1;
        }
    }

    my $url = new URI::URL $og_url;

    if ( keys %$domains ) {
        return $og_url if !exists( $domains->{ $url->host } );
    }
    else {
        # everything should work!
    }

    my $default_utm = $allowed{utm};
    my $custom_utm  = $self->utm();

    for ( keys %{$custom_utm} ) {
        if ( exists $alt_utms->{$_} ) {
            $custom_utm->{$_} = $alt_utms->{$_};
        }
    }

    if ( $og_url =~ m/\?/ ) {
        for my $key ( $url->query_param ) {

            my $lu_key = $key;
            $lu_key =~ s/^utm_//;

            if ( exists( $custom_utm->{$lu_key} ) ) {
                $custom_utm->{$lu_key} = $url->query_param($key);
            }

        }
    }

    for ( keys %{$custom_utm} ) {
        next
          if !defined( $custom_utm->{$_} );
        next
          if length( $custom_utm->{$_} ) <= 0;
        $url->query_param( 'utm_' . $_, $custom_utm->{$_} );
    }
    my $custom_url = $url->abs->as_string;
    undef $url;
    return $custom_url;

}

sub strip {
    my $self   = shift;
    my $string = shift;
    if ( defined($string) ) {
        $string =~ s/^\s+//o;
        $string =~ s/\s+$//o;
        return $string;
    }
    else {
        return undef;
    }
}

sub DESTROY { }
1;
