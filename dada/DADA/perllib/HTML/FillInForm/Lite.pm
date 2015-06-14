package HTML::FillInForm::Lite;
use 5.008_001; # 5.8.1

use strict;
use warnings;

our $VERSION  = '1.13';

use Exporter ();
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(fillinform);

#use Smart::Comments '####';
use Carp ();
use Scalar::Util ();

# Regexp for HTML tags

my $form     = q{[fF][oO][rR][mM]};
my $input    = q{[iI][nN][pP][uU][tT]};
my $select   = q{[sS][eE][lL][eE][cC][tT] };
my $option   = q{[oO][pP][tT][iI][oO][nN] };
my $textarea = q{[tT][eE][xX][tT][aA][rR][eE][aA]};

my $checked  = q{[cC][hH][eE][cC][kK][eE][dD]};
my $selected = q{[sS][eE][lL][eE][cC][tT][eE][dD]};
my $multiple = q{[mM][uU][lL][tT][iI][pP][lL][eE]};

my $id       = q{[iI][dD]};
my $type     = q{[tT][yY][pP][eE]};
my $name     = q{[nN][aA][mM][eE]};
my $value    = q{[vV][aA][lL][uU][eE]};

my $SPACE        =  q{\s};
my $ATTR_NAME    =  q{[\w\-]+};
my $ATTR_VALUE   =  q{(?:" [^"]* " | ' [^']* ' | [^'"/>\s]+ | [\w\-]+ )};
my $ATTR         = qq{(?: $SPACE+ (?: $ATTR_NAME (?: = $ATTR_VALUE )? ) )};

my $FORM         = qq{(?: <$form     $ATTR+ $SPACE*  > )}; # <form>
my $INPUT        = qq{(?: <$input    $ATTR+ $SPACE*/?> )}; # <input>
my $SELECT       = qq{(?: <$select   $ATTR+ $SPACE*  > )}; # <select>
my $OPTION       = qq{(?: <$option   $ATTR* $SPACE*  > )}; # <option>
my $TEXTAREA     = qq{(?: <$textarea $ATTR+ $SPACE*  > )}; # <textarea>

my $END_FORM     = qq{(?: </$form>     )};
my $END_SELECT   = qq{(?: </$select>   )};
my $END_OPTION   = qq{(?: </$option>   )};
my $END_TEXTAREA = qq{(?: </$textarea> )};

my $CHECKED      = qq{(?:
    $checked  (?: = (?: "$checked " | '$checked'  | $checked  ) )?
)};
my $SELECTED     = qq{(?:
    $selected (?: = (?: "$selected" | '$selected' | $selected ) )?
)};
my $MULTIPLE     = qq{(?:
    $multiple (?: = (?: "$multiple" | '$multiple' | $multiple ) )?
)};

#my $DISABLED = q{(?: disabled = (?: "disabled" | 'disabled' | disabled ) )};

#sub _extract{ # for debugging only
#    my $s = shift;
#    my %f = (input => [], select => [], textarea => []);
#    @{$f{input}}    = $s =~ m{($INPUT)}gxmsi;
#    @{$f{select}}   = $s =~ m{($SELECT.*?$END_SELECT)}gxmsi;
#    @{$f{textarea}} = $s =~ m{($TEXTAREA.*?$END_TEXTAREA)}gxmsi;
#
#    return \%f;
#}


sub fillinform { # function interface to fill()
    if(@_ == 1) {
        my($data) = @_;
        my $fif = __PACKAGE__->new();
        return sub {
            my($form) = @_;
            return $fif->fill(\$form, $data);
        }
    }
    else {
        my($form, $data) = @_;
        return __PACKAGE__->fill(\$form, $data);
    }
}

# utilities for getting HTML attributes
sub _unquote{
    $_[0] =~ /(['"]) (.*) \1/xms ? $2 : $_[0]; # ' for poor editors
}
sub _get_id{
    $_[0] =~ /$id    = ($ATTR_VALUE)/xms ? _unquote($1) : undef;
}
sub _get_type{
    $_[0] =~ /$type  = ($ATTR_VALUE)/xms ? _unquote($1) : undef;
}
sub _get_name{
    $_[0] =~ /$name  = ($ATTR_VALUE)/xms ? _unquote($1) : undef;
}
sub _get_value{
    $_[0] =~ /$value = ($ATTR_VALUE)/xms ? _unquote($1) : undef;
}

#use macro
#    _unquote   => \&_unquote,
#    _get_id    => \&_get_id,
#    _get_type  => \&_get_type,
#    _get_name  => \&_get_name,
#    _get_value => \&_get_value,
#;

sub new :method{
    my $class = shift;
    return $class->_parse_option(@_);
}

sub _parse_option{
    my $self = shift;

    if(ref $self and not @_){ # as instance method with no option
        return $self;
    }

    my %context = (
        ignore_types => {
            button   => 1,
            submit   => 1,
            reset    => 1,
            password => 1,
            image    => 1,
            file     => 1,
        },

        escape        => \&_escape_html,
        decode_entity => \&_noop,
        layer         => '',
    );

    # merge if needed
    if(ref $self){
        while(my($key, $val) = each %{$self}){
            $context{$key} = ref($val) eq 'HASH' ? { %{$val} } : $val;
        }
    }

    # parse options
    while(my($opt, $val) = splice @_, 0, 2){
        next unless defined $val;

        if(       $opt eq 'ignore_fields'
            or $opt eq 'disable_fields' ){
            @{ $context{$opt} ||= {} }{ @{$val} }
                = (1) x @{$val};
        }
        elsif($opt eq 'fill_password'){
            $context{ignore_types}{password} = !$val;
        }
        elsif($opt eq 'target'){
            $context{target} = $val;
        }
        elsif($opt eq 'escape'){
            if($val){
                $context{escape} = ref($val) eq 'CODE'
                    ? $val
                    : \&_escape_html;
            }
            else{
                $context{escape} = \&_noop;
            }
        }
        elsif($opt eq 'layer'){
            $context{layer} = $val;
        }
        elsif($opt eq 'decode_entity'){
            if($val){
                $context{decode_entity} = ref($val) eq 'CODE'
                    ? $val
                    : \&_decode_entity;
            }
            else{
                $context{decode_entity} = \&_noop;
            }
        }
        else{
            Carp::croak("Unknown option '$opt' supplied");
        }
    }

    return bless \%context => ref($self) || $self;
}

sub fill :method{
    my($self, $src, $q, @opt) = @_;

    defined $src or Carp::croak('No source supplied');
    defined $q   or Carp::croak('No data supplied');

    my $context = $self->_parse_option(@opt);

    ### $context

    # HTML source to a scalar
    my $content;
    if(ref($src) eq 'SCALAR'){
        $content = ${$src}; # copy
    }
    elsif(ref($src) eq 'ARRAY'){
        $content = join q{}, @{$src};
    }
    else{
        my $is_fh = Scalar::Util::openhandle($src);

        if($is_fh or !ref($src)) {
            if(!$is_fh){
                open my($in), '<'.$context->{layer}, $src
                    or Carp::croak("Cannot open '$src': $!");
                $src = $in;
            }
            local $/;
            $content = readline($src); # slurp
        }
        else {
            $content = ${$src};
        }
    }

    # if $content is utf8-flagged, params should be utf8-encoded
    local $context->{utf8} = utf8::is_utf8($content);

    # param object converted from data or object
    local $context->{data} =  _to_form_object($q);

    # param storage for multi-text fields
    local $context->{params} = {};

    # Fill in contents
    if(defined $context->{target}){

        $content =~ s{ ($FORM) (.*?) ($END_FORM) }
                     {
                my($beg, $content, $end) = ($1, $2, $3);

                my $id = _get_id($beg);
                (defined($id) and $context->{target} eq $id)
                    ? $beg . _fill($context, $content) . $end
                    : $beg .                 $content  . $end
        }gexms;

        return $content;
    }
    else{
        return _fill($context, $content);
    }

}

sub _fill{
    my($context, $content) = @_;
    $content =~ s{($INPUT)}
             { _fill_input($context, $1)                  }gexms;

    $content =~ s{($SELECT) (.*?) ($END_SELECT) }
             { $1 . _fill_select($context, $1, $2) . $3   }gexms;

    $content =~ s{($TEXTAREA) (.*?) ($END_TEXTAREA) }
             { $1 . _fill_textarea($context, $1, $2) . $3 }gexms;

    return $content;
}


sub _fill_input{
    my($context, $tag) = @_;

    ### $tag

    my $type = _get_type($tag) || 'text';
    if($context->{ignore_types}{ $type }){
        return $tag;
    }

    my $values_ref = $context->_get_param( _get_name($tag) )
        or return $tag;

    if($type eq 'checkbox' or $type eq 'radio'){
        my $value = _get_value($tag);

        if(not defined $value){
            $value = 'on';
        }
        else{
            $value = $context->{decode_entity}->($value);
        }

        if(grep { $value eq $_ } @{$values_ref}){
            $tag =~ /$CHECKED/xms
                or $tag =~ s{$SPACE* (/?) > \z}
                        { checked="checked" $1>}xms;
        }
        else{
            $tag =~ s/$SPACE+$CHECKED//gxms;
        }
    }
    else{
        my $new_value = $context->{escape}->(shift @{$values_ref});

        $tag =~ s{$value = $ATTR_VALUE}{value="$new_value"}xms
            or $tag =~ s{$SPACE* (/?) > \z}
                    { value="$new_value" $1>}xms;
    }
    return $tag;
}
sub _fill_select{
    my($context, $tag, $content) = @_;

    my $values_ref = $context->_get_param( _get_name($tag) )
        or return $content;

    if($tag !~ /$MULTIPLE/oxms){
        $values_ref = [ shift @{ $values_ref } ]; # in select-one
    }

    $content =~ s{($OPTION) (.*?) ($END_OPTION)}
             { _fill_option($context, $values_ref, $1, $2) . $2 . $3 }gexms;
    return $content;
}
sub _fill_option{
    my($context, $values_ref, $tag, $content) = @_;

    my $value = _get_value($tag);
    unless( defined $value ){
        $value = $content;
        $value =~ s{\A $SPACE+   } {}xms;
        $value =~ s{   $SPACE{2,}}{ }xms;
        $value =~ s{   $SPACE+ \z} {}xms;
    }

    $value = $context->{decode_entity}->($value);

    ### @_
    if(grep{ $value eq $_ }  @{$values_ref}){
        $tag =~ /$SELECTED/oxms
            or $tag =~ s{ $SPACE* > \z}
                    { selected="selected">}xms;
    }
    else{
        $tag =~ s/$SPACE+$SELECTED//gxms;
    }
    return $tag;
}

sub _fill_textarea{
    my($context, $tag, $content) = @_;

    my $values_ref = $context->_get_param( _get_name($tag) )
        or return $content;

    return $context->{escape}->(shift @{$values_ref});
}

# utilities

sub _get_param{
    my($context, $name) = @_;

    return if not defined $name or $context->{ignore_fields}{$name};

    my $ref = $context->{params}{$name};

    if(not defined $ref){
        $ref = $context->{params}{$name}
            = [ $context->{data}->param($name) ];

        if($context->{utf8}){
            for my $datum( @{$ref} ){
                utf8::decode($datum) unless utf8::is_utf8($datum);
            }
        }
    }

    return @{$ref} ? $ref : undef;
}

sub _noop{
    return $_[0];
}
sub _escape_html{
    my $s = shift;
#    return '' unless defined $s;

    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g; # " for poor editors
    return $s;
}


sub _decode_entity{
    my $s = shift;

    our %entity2char;
    unless(%entity2char){
        # load the HTML entity data
        local $/ = "__END__\n";
        local($@, $!);
        open my $data_in, '<', __FILE__ or die $!; # should be success
        readline $data_in; # discard the first segment
        eval scalar readline($data_in) or die $@;
    }

    $s =~ s{&(\w+);}{ $entity2char{$1} || "&$1;" }egxms;

    $s =~ s{&\#(\d+)          ;}{ chr     $1 }egxms;
    $s =~ s{&\#x([0-9a-fA-F]+);}{ chr hex $1 }egxms;
    return $s;
}

#sub _disable{
#    my $context = shift;
#    my $name   = shift;
#
#    if($context->{disable_fields}{$name}){
#        $_[0] =~ /$DISABLED/xmsi
#            or $_[0] =~ s{$SPACE* /? > \z}
#                    { disabled="disabled" />}xmsi;
#    }
#    return;
#}

sub _to_form_object{
    my($ref) = @_;

    my $wrapper;
    my $type;

    if(!Scalar::Util::blessed($ref)){
        $type = ref $ref;
        if($type eq 'HASH'){
            $wrapper = {};
            @{$wrapper}{ keys %{$ref} }
                = map{
                      ref($_) eq 'ARRAY' ?  $_
                    : defined($_)        ? [$_]
                    :                      [  ];
                } values %{$ref};
        }
        elsif($type eq 'ARRAY'){
            $wrapper = [];
            @{$wrapper} = map{ _to_form_object($_) } @{$ref};
        }
        elsif($type eq 'CODE'){
            $wrapper = \$ref;
        }
        else{
            Carp::croak("Cannot use '$ref' as form data");
        }
    }
    elsif($ref->can('param')){ # a request object like CGI.pm
        return $ref;
    }
    else{
        # any object is ok
        $wrapper = \$ref;
        $type    = 'Object';
    }

    return bless $wrapper => __PACKAGE__ . q{::} . $type;
}
sub HTML::FillInForm::Lite::HASH::param{
    my($hash_ref, $key) = @_;

    my $value = $hash_ref->{$key} or return;

    return @{ $value };
}

sub HTML::FillInForm::Lite::ARRAY::param{
    my($ary_ref, $key) = @_;

    return map{ $_->param($key) } @{$ary_ref};
}

sub HTML::FillInForm::Lite::CODE::param{
    my($ref_to_code_ref, $key) = @_;

    return ${$ref_to_code_ref}->($key);
}
sub HTML::FillInForm::Lite::Object::param{
    my($ref_to_object, $key) = @_;
    my $method = ${$ref_to_object}->can($key)  or return;
    my(@values) = ${$ref_to_object}->$method();

    return @values == 1 && !defined($values[0]) ? () : @values;
}

1;

__END__

our %entity2char = (
    quot   => chr(34),
    amp    => chr(38),
    apos   => chr(39),
    lt     => chr(60),
    gt     => chr(62),

    AElig    => chr(198),    Aacute    => chr(193),
    Acirc    => chr(194),    Agrave    => chr(192),
    Aring    => chr(197),    Atilde    => chr(195),
    Auml    => chr(196),    Ccedil    => chr(199),
    ETH        => chr(208),    Eacute    => chr(201),
    Ecirc    => chr(202),    Egrave    => chr(200),
    Euml    => chr(203),    Iacute    => chr(205),
    Icirc    => chr(206),    Igrave    => chr(204),
    Iuml    => chr(207),    Ntilde    => chr(209),
    Oacute    => chr(211),    Ocirc    => chr(212),
    Ograve    => chr(210),    Oslash    => chr(216),
    Otilde    => chr(213),    Ouml    => chr(214),
    THORN    => chr(222),    Uacute    => chr(218),
    Ucirc    => chr(219),    Ugrave    => chr(217),
    Uuml    => chr(220),    Yacute    => chr(221),
    aacute    => chr(225),    acirc    => chr(226),
    aelig    => chr(230),    agrave    => chr(224),
    aring    => chr(229),    atilde    => chr(227),
    auml    => chr(228),    ccedil    => chr(231),
    eacute    => chr(233),    ecirc    => chr(234),
    egrave    => chr(232),    eth        => chr(240),
    euml    => chr(235),    iacute    => chr(237),
    icirc    => chr(238),    igrave    => chr(236),
    iuml    => chr(239),    ntilde    => chr(241),
    oacute    => chr(243),    ocirc    => chr(244),
    ograve    => chr(242),    oslash    => chr(248),
    otilde    => chr(245),    ouml    => chr(246),
    szlig    => chr(223),    thorn    => chr(254),
    uacute    => chr(250),    ucirc    => chr(251),
    ugrave    => chr(249),    uuml    => chr(252),
    yacute    => chr(253),    yuml    => chr(255),

    copy   => chr(169),    reg    => chr(174),
    nbsp   => chr(160),

    iexcl  => chr(161),    cent   => chr(162),
    pound  => chr(163),    curren => chr(164),
    yen    => chr(165),    brvbar => chr(166),
    sect   => chr(167),    uml    => chr(168),
    ordf   => chr(170),    laquo  => chr(171),
    not    => chr(172),    shy    => chr(173),
    macr   => chr(175),    deg    => chr(176),
    plusmn => chr(177),    sup1   => chr(185),
    sup2   => chr(178),    sup3   => chr(179),
    acute  => chr(180),    micro  => chr(181),
    para   => chr(182),    middot => chr(183),
    cedil  => chr(184),    ordm   => chr(186),
    raquo  => chr(187),    frac14 => chr(188),
    frac12 => chr(189),    frac34 => chr(190),
    iquest => chr(191),    times  => chr(215),
    divide => chr(247),

    OElig    => chr(338),    oelig    => chr(339),
    Scaron   => chr(352),    scaron   => chr(353),
    Yuml     => chr(376),    fnof     => chr(402),
    circ     => chr(710),    tilde    => chr(732),
    Alpha    => chr(913),    Beta     => chr(914),
    Gamma    => chr(915),    Delta    => chr(916),
    Epsilon  => chr(917),    Zeta     => chr(918),
    Eta      => chr(919),    Theta    => chr(920),
    Iota     => chr(921),    Kappa    => chr(922),
    Lambda   => chr(923),    Mu       => chr(924),
    Nu       => chr(925),    Xi       => chr(926),
    Omicron  => chr(927),    Pi       => chr(928),
    Rho      => chr(929),    Sigma    => chr(931),
    Tau      => chr(932),    Upsilon  => chr(933),
    Phi      => chr(934),    Chi      => chr(935),
    Psi      => chr(936),    Omega    => chr(937),
    alpha    => chr(945),    beta     => chr(946),
    gamma    => chr(947),    delta    => chr(948),
    epsilon  => chr(949),    zeta     => chr(950),
    eta      => chr(951),    theta    => chr(952),
    iota     => chr(953),    kappa    => chr(954),
    lambda   => chr(955),    mu       => chr(956),
    nu       => chr(957),    xi       => chr(958),
    omicron  => chr(959),    pi       => chr(960),
    rho      => chr(961),    sigmaf   => chr(962),
    sigma    => chr(963),    tau      => chr(964),
    upsilon  => chr(965),    phi      => chr(966),
    chi      => chr(967),    psi      => chr(968),
    omega    => chr(969),    thetasym => chr(977),
    upsih    => chr(978),    piv      => chr(982),

    ensp     => chr(8194),    emsp     => chr(8195),
    thinsp   => chr(8201),    zwnj     => chr(8204),
    zwj      => chr(8205),    lrm      => chr(8206),
    rlm      => chr(8207),    ndash    => chr(8211),
    mdash    => chr(8212),    lsquo    => chr(8216),
    rsquo    => chr(8217),    sbquo    => chr(8218),
    ldquo    => chr(8220),    rdquo    => chr(8221),
    bdquo    => chr(8222),    dagger   => chr(8224),
    Dagger   => chr(8225),    bull     => chr(8226),
    hellip   => chr(8230),    permil   => chr(8240),
    prime    => chr(8242),    Prime    => chr(8243),
    lsaquo   => chr(8249),    rsaquo   => chr(8250),
    oline    => chr(8254),    frasl    => chr(8260),
    euro     => chr(8364),    image    => chr(8465),
    weierp   => chr(8472),    real     => chr(8476),
    trade    => chr(8482),    alefsym  => chr(8501),
    larr     => chr(8592),    uarr     => chr(8593),
    rarr     => chr(8594),    darr     => chr(8595),
    harr     => chr(8596),    crarr    => chr(8629),
    lArr     => chr(8656),    uArr     => chr(8657),
    rArr     => chr(8658),    dArr     => chr(8659),
    hArr     => chr(8660),    forall   => chr(8704),
    part     => chr(8706),    exist    => chr(8707),
    empty    => chr(8709),    nabla    => chr(8711),
    isin     => chr(8712),    notin    => chr(8713),
    ni       => chr(8715),    prod     => chr(8719),
    sum      => chr(8721),    minus    => chr(8722),
    lowast   => chr(8727),    radic    => chr(8730),
    prop     => chr(8733),    infin    => chr(8734),
    ang      => chr(8736),    and      => chr(8743),
    or       => chr(8744),    cap      => chr(8745),
    cup      => chr(8746),    int      => chr(8747),
    there4   => chr(8756),    sim      => chr(8764),
    cong     => chr(8773),    asymp    => chr(8776),
    ne       => chr(8800),    equiv    => chr(8801),
    le       => chr(8804),    ge       => chr(8805),
    sub      => chr(8834),    sup      => chr(8835),
    nsub     => chr(8836),    sube     => chr(8838),
    supe     => chr(8839),    oplus    => chr(8853),
    otimes   => chr(8855),    perp     => chr(8869),
    sdot     => chr(8901),    lceil    => chr(8968),
    rceil    => chr(8969),    lfloor   => chr(8970),
    rfloor   => chr(8971),    lang     => chr(9001),
    rang     => chr(9002),    loz      => chr(9674),
    spades   => chr(9824),    clubs    => chr(9827),
    hearts   => chr(9829),    diams    => chr(9830),
);
1;

__END__

=encoding utf-8

=for stopwords fillinform bool iolayer fill_scalarref scalarref

=head1 NAME

HTML::FillInForm::Lite - Lightweight FillInForm module in Pure Perl

=head1 VERSION

The document describes HTML::FillInForm::Lite version 1.13

=head1 SYNOPSIS

    use HTML::FillInForm::Lite;
    use CGI;

    my $q = CGI->new();
    my $h = HTML::FillInForm::Lite->new();

    $output = $h->fill(\$html,    $q);
    $output = $h->fill(\@html,    \%data);
    $output = $h->fill(\*HTML,    \&my_param);
    $output = $h->fill('t.html', [$q, \%default]);

    # or as a class method with options
    $output = HTML::FillInForm::Lite->fill(\$html, $q,
        fill_password => 0, # it is default
        ignore_fields => ['foo', 'bar'],
        target        => $form_id,
    );

    # Moreover, it accepts any object as form data
    # (these classes come form Class::DBI's SYNOPSIS)

    my $artist = Music::Artist->insert({ id => 1, name => 'U2' });
    $output = $h->fill(\$html, $artist);

    my $cd = Music::CD->retrieve(1);
    $output = $h->fill(\$html, $cd);

    # simple function interface
    use HTML::FillInForm::Lite qw(fillinform);

    # the same as HTML::FillInForm::Lite->fill(...)
    $output = fillinform(\$html, $q);

=head1 DESCRIPTION

This module fills in HTML forms with Perl data,
which re-implements C<HTML::FillInForm> using regexp-based parser,
not using C<HTML::Parser>.

The difference in the parsers makes C<HTML::FillInForm::Lite> about 2
times faster than C<HTML::FillInForm>.

=head1 FUNCTIONS

=head2 fillinform(source, form_data)

Simple interface to the C<fill()> method, accepting only a string.
If you pass a single argument to this function, it is interpreted as
I<form_data>, and returns a function that accepts I<source>.

    my $fillinform = fillinform($query);
    $fillinform->($html); # the same as fillinform($html, $query)

This function is exportable.

=head1 METHODS

=head2 new(options...)

Creates C<HTML::FillInForm::Lite> processor with I<options>.

There are several options. All the options are disabled when C<undef> is
supplied.

Acceptable options are as follows:

=over 4

=item fill_password => I<bool>

To enable passwords to be filled in, set the option true.

Note that the effect of the option is the same as that of C<HTML::FillInForm>,
but by default C<HTML::FillInForm::Lite> ignores password fields.

=item ignore_fields => I<array_ref_of_fields>

To ignore some fields from filling.

=item target => I<form_id>

To fill in just the form identified by I<form_id>.

=item escape => I<bool> | I<ref>

If true is provided (or by default), values filled in text fields will be
HTML-escaped, e.g. C<< <tag> >> to be C<< &lt;tag&gt; >>.

If the values are already HTML-escaped, set the option false.

You can supply a subroutine reference to escape the values.

Note that it is not implemented in C<HTML::FillInForm>.

=item decode_entity => I<bool> | I<ref>

If true is provided , HTML entities in state fields
(namely, C<radio>, C<checkbox> and C<select>) will be decoded,
but normally it is not needed.

You can also supply a subroutine reference to decode HTML entities.

Note that C<HTML::FillInForm> always decodes HTML entities in state fields,
but not supports this option.

=item layer => I<:iolayer>

To read a file with I<:iolayer>. It is used when a file name is supplied as
I<source>.

For example:

    # To read a file encoded in UTF-8
    $fif = HTML::FillInForm::Lite->new(layer => ':utf8');
    $output = $fif->fill($utf8_file, $fdat);

    # To read a file encoded in EUC-JP
    $fif = HTML::FillInForm::Lite->new(layer => ':encoding(euc-jp)');
    $output = $fif->fill($eucjp_file, $fdat);

Note that it is not implemented in C<HTML::FillInForm>.

=back

=head2 fill(source, form_data [, options...])

Fills in I<source> with I<form_data>. If I<source> or I<form_data> is not
supplied, it will cause C<die>.

I<options> are the same as C<new()>'s.

You can use this method as a both class or instance method,
but you make multiple calls to C<fill()> with the B<same>
options, it is a little faster to call C<new()> and store the instance.

I<source> may be a scalar reference, an array reference of strings, or
a file name.

I<form_data> may be a hash reference, an object with C<param()> method,
an object with accessors, a code reference, or an array reference of
those above mentioned.

If I<form_data> is based on procedures (i.e. not a hash reference),
the procedures will be called in the list context.
Therefore, to leave some fields untouched, it must return a null list C<()>,
not C<undef>.

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 NOTES

=head2 Compatibility with C<HTML::FillInForm>

This module implements only the new syntax of C<HTML::FillInForm>
version 2. However, C<HTML::FillInForm::Lite::Compat> provides
an interface compatible with C<HTML::FillInForm>.

=head2 Compatibility with legacy HTML

This module is designed to process XHTML 1.x.

And it also supporting a good part of HTML 4.x , but there are some
limitations. First, it doesn't understand HTML-attributes that the name is
omitted.

For example:

    <INPUT TYPE=checkbox NAME=foo CHECKED> -- NG.
    <INPUT TYPE=checkbox NAME=foo CHECKED=checked> - OK, but obsolete.
    <input type="checkbox" name="foo" checked="checked" /> - OK, valid XHTML

Then, it always treats the values of attributes case-sensitively.
In the example above, the value of C<type> must be lower-case.

Moreover, it doesn't recognize omitted closing tags, like:

    <select name="foo">
        <option>bar
        <option>baz
    </select>

When you can't get what you want, try to give your source to a HTML lint.

=head2 Comment handling

This module processes all the processable, not knowing comments
nor something that shouldn't be processed.

It may cause problems. Suppose there is a code like:

    <script> document.write("<input name='foo' />") </script>

C<HTML::FillInForm::Lite> will break the code:

    <script> document.write("<input name='foo' value="bar" />") </script>

To avoid such problems, you can use the C<ignore_fields> option.

=head1 BUGS

No bugs have been reported.

Please report any bug or feature request to E<lt>gfuji(at)cpan.orgE<gt>,
or through the RT L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<HTML::FillInForm>.

L<HTML::FillInForm::Lite::JA> - the document in Japanese.

L<HTML::FillInForm::Lite::Compat> - HTML::FillInForm compatibility layer

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008-2010 Goro Fuji, Some rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

