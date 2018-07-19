package Text::Markdown;
require 5.008_000;
use strict;
use warnings;
use re 'eval';

use Digest::MD5 qw(md5_hex);
use Encode      qw();
use Carp        qw(croak);
use base        'Exporter';

our $VERSION   = '1.000031'; # 1.0.31
$VERSION = eval $VERSION;
our @EXPORT_OK = qw(markdown);

=head1 NAME

Text::Markdown - Convert Markdown syntax to (X)HTML

=head1 SYNOPSIS

    use Text::Markdown 'markdown';
    my $html = markdown($text);

    use Text::Markdown 'markdown';
    my $html = markdown( $text, {
        empty_element_suffix => '>',
        tab_width => 2,
    } );

    use Text::Markdown;
    my $m = Text::Markdown->new;
    my $html = $m->markdown($text);

    use Text::Markdown;
    my $m = Text::MultiMarkdown->new(
        empty_element_suffix => '>',
        tab_width => 2,
    );
    my $html = $m->markdown( $text );

=head1 DESCRIPTION

Markdown is a text-to-HTML filter; it translates an easy-to-read /
easy-to-write structured text format into HTML. Markdown's text format
is most similar to that of plain text email, and supports features such
as headers, *emphasis*, code blocks, blockquotes, and links.

Markdown's syntax is designed not as a generic markup language, but
specifically to serve as a front-end to (X)HTML. You can use span-level
HTML tags anywhere in a Markdown document, and you can use block level
HTML tags (like <div> and <table> as well).

=head1 SYNTAX

This module implements the 'original' Markdown markdown syntax from:

    http://daringfireball.net/projects/markdown/

Note that L<Text::Markdown> ensures that the output always ends with
B<one> newline. The fact that multiple newlines are collapsed into one
makes sense, because this is the behavior of HTML towards whispace. The
fact that there's always a newline at the end makes sense again, given
that the output will always be nested in a B<block>-level element (as
opposed to an inline element). That block element can be a C<< <p> >>
(most often), or a C<< <table> >>.

Markdown is B<not> interpreted in HTML block-level elements, in order for
chunks of pasted HTML (e.g. JavaScript widgets, web counters) to not be
magically (mis)interpreted. For selective processing of Markdown in some,
but not other, HTML block elements, add a C<markdown> attribute to the block
element and set its value to C<1>, C<on> or C<yes>:

    <div markdown="1" class="navbar">
    * Home
    * About
    * Contact
    <div>

The extra C<markdown> attribute will be stripped when generating the output.

=head1 OPTIONS

Text::Markdown supports a number of options to its processor which control
the behaviour of the output document.

These options can be supplied to the constructor, or in a hash within
individual calls to the L</markdown> method. See the SYNOPSIS for examples
of both styles.

The options for the processor are:

=over

=item empty_element_suffix

This option controls the end of empty element tags:

    '/>' for XHTML (default)
    '>' for HTML

=item tab_width

Controls indent width in the generated markup. Defaults to 4.

=item trust_list_start_value

If true, ordered lists will use the first number as the starting point for
numbering.  This will let you pick up where you left off by writing:

  1. foo
  2. bar

  some paragraph

  3. baz
  6. quux

(Note that in the above, quux will be numbered 4.)

=back

=cut

# Regex to match balanced [brackets]. See Friedl's
# "Mastering Regular Expressions", 2nd Ed., pp. 328-331.
our ($g_nested_brackets, $g_nested_parens);
$g_nested_brackets = qr{
    (?>                                 # Atomic matching
       [^\[\]]+                         # Anything other than brackets
     |
       \[
         (??{ $g_nested_brackets })     # Recursive set of nested brackets
       \]
    )*
}x;
# Doesn't allow for whitespace, because we're using it to match URLs:
$g_nested_parens = qr{
    (?>                                 # Atomic matching
       [^()\s]+                            # Anything other than parens or whitespace
     |
       \(
         (??{ $g_nested_parens })        # Recursive set of nested brackets
       \)
    )*
}x;

# Table of hash values for escaped characters:
our %g_escape_table;
foreach my $char (split //, '\\`*_{}[]()>#+-.!') {
    $g_escape_table{$char} = md5_hex($char);
}

=head1 METHODS

=head2 new

A simple constructor, see the SYNTAX and OPTIONS sections for more information.

=cut

sub new {
    my ($class, %p) = @_;

    $p{base_url} ||= ''; # This is the base URL to be used for WikiLinks

    $p{tab_width} = 4 unless (defined $p{tab_width} and $p{tab_width} =~ m/^\d+$/);

    $p{empty_element_suffix} ||= ' />'; # Change to ">" for HTML output

    $p{trust_list_start_value} = $p{trust_list_start_value} ? 1 : 0;

    my $self = { params => \%p };
    bless $self, ref($class) || $class;
    return $self;
}

=head2 markdown

The main function as far as the outside world is concerned. See the SYNOPSIS
for details on use.

=cut

sub markdown {
    my ( $self, $text, $options ) = @_;

    # Detect functional mode, and create an instance for this run
    unless (ref $self) {
        if ( $self ne __PACKAGE__ ) {
            my $ob = __PACKAGE__->new();
                                # $self is text, $text is options
            return $ob->markdown($self, $text);
        }
        else {
            croak('Calling ' . $self . '->markdown (as a class method) is not supported.');
        }
    }

    $options ||= {};

    %$self = (%{ $self->{params} }, %$options, params => $self->{params});

    $self->_CleanUpRunData($options);

    return $self->_Markdown($text);
}

sub _CleanUpRunData {
    my ($self, $options) = @_;
    # Clear the global hashes. If we don't clear these, you get conflicts
    # from other articles when generating a page which contains more than
    # one article (e.g. an index page that shows the N most recent
    # articles).
    $self->{_urls}        = $options->{urls} ? $options->{urls} : {}; # FIXME - document passing this option (tested in 05options.t).
    $self->{_titles}      = {};
    $self->{_html_blocks} = {};
    # Used to track when we're inside an ordered or unordered list
    # (see _ProcessListItems() for details)
    $self->{_list_level} = 0;

}

sub _Markdown {
#
# Main function. The order in which other subs are called here is
# essential. Link and image substitutions need to happen before
# _EscapeSpecialChars(), so that any *'s or _'s in the <a>
# and <img> tags get encoded.
#
    my ($self, $text, $options) = @_;

    $text = $self->_CleanUpDoc($text);

    # Turn block-level HTML elements into hash entries, and interpret markdown in them if they have a 'markdown="1"' attribute
    $text = $self->_HashHTMLBlocks($text, {interpret_markdown_on_attribute => 1});

    $text = $self->_StripLinkDefinitions($text);

    $text = $self->_RunBlockGamut($text, {wrap_in_p_tags => 1});

    $text = $self->_UnescapeSpecialChars($text);

    $text = $self->_ConvertCopyright($text);

    return $text . "\n";
}

=head2 urls

Returns a reference to a hash with the key being the markdown reference
and the value being the URL.

Useful for building scripts which preprocess a list of links before the
main content. See F<t/05options.t> for an example of this hashref being
passed back into the markdown method to create links.

=cut

sub urls {
    my ( $self ) = @_;

    return $self->{_urls};
}

sub _CleanUpDoc {
    my ($self, $text) = @_;

    # Standardize line endings:
    $text =~ s{\r\n}{\n}g;  # DOS to Unix
    $text =~ s{\r}{\n}g;    # Mac to Unix

    # Make sure $text ends with a couple of newlines:
    $text .= "\n\n";

    # Convert all tabs to spaces.
    $text = $self->_Detab($text);

    # Strip any lines consisting only of spaces and tabs.
    # This makes subsequent regexen easier to write, because we can
    # match consecutive blank lines with /\n+/ instead of something
    # contorted like /[ \t]*\n+/ .
    $text =~ s/^[ \t]+$//mg;

    return $text;
}

sub _StripLinkDefinitions {
#
# Strips link definitions from text, stores the URLs and titles in
# hash references.
#
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # Link defs are in the form: ^[id]: url "optional title"
    while ($text =~ s{
            ^[ ]{0,$less_than_tab}\[(.+)\]: # id = \$1
              [ \t]*
              \n?               # maybe *one* newline
              [ \t]*
            <?(\S+?)>?          # url = \$2
              [ \t]*
              \n?               # maybe one newline
              [ \t]*
            (?:
                (?<=\s)         # lookbehind for whitespace
                ["(]
                (.+?)           # title = \$3
                [")]
                [ \t]*
            )?  # title is optional
            (?:\n+|\Z)
        }{}omx) {
        $self->{_urls}{lc $1} = $self->_EncodeAmpsAndAngles( $2 );    # Link IDs are case-insensitive
        if ($3) {
            $self->{_titles}{lc $1} = $3;
            $self->{_titles}{lc $1} =~ s/"/&quot;/g;
        }

    }

    return $text;
}

sub _md5_utf8 {
    # Internal function used to safely MD5sum chunks of the input, which might be Unicode in Perl's internal representation.
    my $input = shift;
    return unless defined $input;
    if (Encode::is_utf8 $input) {
        return md5_hex(Encode::encode('utf8', $input));
    }
    else {
        return md5_hex($input);
    }
}

sub _HashHTMLBlocks {
    my ($self, $text, $options) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # Hashify HTML blocks (protect from further interpretation by encoding to an md5):
    # We only want to do this for block-level HTML tags, such as headers,
    # lists, and tables. That's because we still want to wrap <p>s around
    # "paragraphs" that are wrapped in non-block-level tags, such as anchors,
    # phrase emphasis, and spans. The list of tags we're looking for is
    # hard-coded:
    my $block_tags = qr{
          (?:
            p         |  div     |  h[1-6]  |  blockquote  |  pre       |  table  |
            dl        |  ol      |  ul      |  script      |  noscript  |  form   |
            fieldset  |  iframe  |  math    |  ins         |  del
          )
        }x;

    my $tag_attrs = qr{
                        (?:                 # Match one attr name/value pair
                            \s+             # There needs to be at least some whitespace
                                            # before each attribute name.
                            [\w.:_-]+       # Attribute name
                            \s*=\s*
                            (?:
                                ".+?"       # "Attribute value"
                             |
                                '.+?'       # 'Attribute value'
                             |
                                [^\s]+?      # AttributeValue (HTML5)
                            )
                        )*                  # Zero or more
                    }x;

    my $empty_tag = qr{< \w+ $tag_attrs \s* />}oxms;
    my $open_tag =  qr{< $block_tags $tag_attrs \s* >}oxms;
    my $close_tag = undef;       # let Text::Balanced handle this
    my $prefix_pattern = undef;  # Text::Balanced
    my $markdown_attr = qr{ \s* markdown \s* = \s* (['"]) (.*?) \1 }xs;

    use Text::Balanced qw(gen_extract_tagged);
    my $extract_block = gen_extract_tagged($open_tag, $close_tag, $prefix_pattern, { ignore => [$empty_tag] });

    my @chunks;
    # parse each line, looking for block-level HTML tags
    while ($text =~ s{^(([ ]{0,$less_than_tab}<)?.*\n)}{}m) {
        my $cur_line = $1;
        if (defined $2) {
            # current line could be start of code block

            my ($tag, $remainder, $prefix, $opening_tag, $text_in_tag, $closing_tag) = $extract_block->($cur_line . $text);
            if ($tag) {
                if ($options->{interpret_markdown_on_attribute} and $opening_tag =~ s/$markdown_attr//i) {
                    my $markdown = $2;
                    if ($markdown =~ /^(1|on|yes)$/) {
                        # interpret markdown and reconstruct $tag to include the interpreted $text_in_tag
                        my $wrap_in_p_tags = $opening_tag =~ /^<(div|iframe)/;
                        $tag = $prefix . $opening_tag . "\n"
                          . $self->_RunBlockGamut($text_in_tag, {wrap_in_p_tags => $wrap_in_p_tags})
                          . "\n" . $closing_tag
                        ;
                    } else {
                        # just remove the markdown="0" attribute
                        $tag = $prefix . $opening_tag . $text_in_tag . $closing_tag;
                    }
                }
                my $key = _md5_utf8($tag);
                $self->{_html_blocks}{$key} = $tag;
                push @chunks, "\n\n" . $key . "\n\n";
                $text = $remainder;
            }
            else {
                # No tag match, so toss $cur_line into @chunks
                push @chunks, $cur_line;
            }
        }
        else {
            # current line could NOT be start of code block
            push @chunks, $cur_line;
        }

    }
    push @chunks, $text;  # whatever is left

    $text = join '', @chunks;

    return $text;
}

sub _HashHR {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    $text =~ s{
                (?:
                    (?<=\n\n)        # Starting after a blank line
                    |                # or
                    \A\n?            # the beginning of the doc
                )
                (                        # save in $1
                    [ ]{0,$less_than_tab}
                    <(hr)                # start tag = $2
                    \b                    # word break
                    ([^<>])*?            #
                    /?>                    # the matching end tag
                    [ \t]*
                    (?=\n{2,}|\Z)        # followed by a blank line or end of document
                )
    }{
        my $key = _md5_utf8($1);
        $self->{_html_blocks}{$key} = $1;
        "\n\n" . $key . "\n\n";
    }egx;

    return $text;
}

sub _HashHTMLComments {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # Special case for standalone HTML comments:
    $text =~ s{
                (?:
                    (?<=\n\n)        # Starting after a blank line
                    |                # or
                    \A\n?            # the beginning of the doc
                )
                (                        # save in $1
                    [ ]{0,$less_than_tab}
                    (?s:
                        <!
                        (--.*?--\s*)+
                        >
                    )
                    [ \t]*
                    (?=\n{2,}|\Z)        # followed by a blank line or end of document
                )
    }{
        my $key = _md5_utf8($1);
        $self->{_html_blocks}{$key} = $1;
        "\n\n" . $key . "\n\n";
    }egx;

    return $text;
}

sub _HashPHPASPBlocks {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # PHP and ASP-style processor instructions (<?…?> and <%…%>)
    $text =~ s{
                (?:
                    (?<=\n\n)        # Starting after a blank line
                    |                # or
                    \A\n?            # the beginning of the doc
                )
                (                        # save in $1
                    [ ]{0,$less_than_tab}
                    (?s:
                        <([?%])            # $2
                        .*?
                        \2>
                    )
                    [ \t]*
                    (?=\n{2,}|\Z)        # followed by a blank line or end of document
                )
            }{
                my $key = _md5_utf8($1);
                $self->{_html_blocks}{$key} = $1;
                "\n\n" . $key . "\n\n";
            }egx;
    return $text;
}

sub _RunBlockGamut {
#
# These are all the transformations that form block-level
# tags like paragraphs, headers, and list items.
#
    my ($self, $text, $options) = @_;

    # Do headers first, as these populate cross-refs
    $text = $self->_DoHeaders($text);

    # Do Horizontal Rules:
    my $less_than_tab = $self->{tab_width} - 1;
    $text =~ s{^[ ]{0,$less_than_tab}(\*[ ]?){3,}[ \t]*$}{\n<hr$self->{empty_element_suffix}\n}gmx;
    $text =~ s{^[ ]{0,$less_than_tab}(-[ ]?){3,}[ \t]*$}{\n<hr$self->{empty_element_suffix}\n}gmx;
    $text =~ s{^[ ]{0,$less_than_tab}(_[ ]?){3,}[ \t]*$}{\n<hr$self->{empty_element_suffix}\n}gmx;

    $text = $self->_DoLists($text);

    $text = $self->_DoCodeBlocks($text);

    $text = $self->_DoBlockQuotes($text);

    # We already ran _HashHTMLBlocks() before, in Markdown(), but that
    # was to escape raw HTML in the original Markdown source. This time,
    # we're escaping the markup we've just created, so that we don't wrap
    # <p> tags around block-level tags.
    $text = $self->_HashHTMLBlocks($text);

    # Special case just for <hr />. It was easier to make a special case than
    # to make the other regex more complicated.
    $text = $self->_HashHR($text);

    $text = $self->_HashHTMLComments($text);

    $text = $self->_HashPHPASPBlocks($text);

    $text = $self->_FormParagraphs($text, {wrap_in_p_tags => $options->{wrap_in_p_tags}});

    return $text;
}

sub _RunSpanGamut {
#
# These are all the transformations that occur *within* block-level
# tags like paragraphs, headers, and list items.
#
    my ($self, $text) = @_;

    $text = $self->_DoCodeSpans($text);
    $text = $self->_EscapeSpecialCharsWithinTagAttributes($text);
    $text = $self->_EscapeSpecialChars($text);

    # Process anchor and image tags. Images must come first,
    # because ![foo][f] looks like an anchor.
    $text = $self->_DoImages($text);
    $text = $self->_DoAnchors($text);

    # Make links out of things like `<http://example.com/>`
    # Must come after _DoAnchors(), because you can use < and >
    # delimiters in inline links like [this](<url>).
    $text = $self->_DoAutoLinks($text);

    $text = $self->_EncodeAmpsAndAngles($text);

    $text = $self->_DoItalicsAndBold($text);

    # FIXME - Is hard coding space here sane, or does this want to be related to tab width?
    # Do hard breaks:
    $text =~ s/ {2,}\n/ <br$self->{empty_element_suffix}\n/g;

    return $text;
}

sub _EscapeSpecialChars {
    my ($self, $text) = @_;
    my $tokens ||= $self->_TokenizeHTML($text);

    $text = '';   # rebuild $text from the tokens
#   my $in_pre = 0;  # Keep track of when we're inside <pre> or <code> tags.
#   my $tags_to_skip = qr!<(/?)(?:pre|code|kbd|script|math)[\s>]!;

    foreach my $cur_token (@$tokens) {
        if ($cur_token->[0] eq "tag") {
            # Within tags, encode * and _ so they don't conflict
            # with their use in Markdown for italics and strong.
            # We're replacing each such character with its
            # corresponding MD5 checksum value; this is likely
            # overkill, but it should prevent us from colliding
            # with the escape values by accident.
            $cur_token->[1] =~  s! \* !$g_escape_table{'*'}!ogx;
            $cur_token->[1] =~  s! _  !$g_escape_table{'_'}!ogx;
            $text .= $cur_token->[1];
        } else {
            my $t = $cur_token->[1];
            $t = $self->_EncodeBackslashEscapes($t);
            $text .= $t;
        }
    }
    return $text;
}

sub _EscapeSpecialCharsWithinTagAttributes {
#
# Within tags -- meaning between < and > -- encode [\ ` * _] so they
# don't conflict with their use in Markdown for code, italics and strong.
# We're replacing each such character with its corresponding MD5 checksum
# value; this is likely overkill, but it should prevent us from colliding
# with the escape values by accident.
#
    my ($self, $text) = @_;
    my $tokens ||= $self->_TokenizeHTML($text);
    $text = '';   # rebuild $text from the tokens

    foreach my $cur_token (@$tokens) {
        if ($cur_token->[0] eq "tag") {
            $cur_token->[1] =~  s! \\ !$g_escape_table{'\\'}!gox;
            $cur_token->[1] =~  s{ (?<=.)</?code>(?=.)  }{$g_escape_table{'`'}}gox;
            $cur_token->[1] =~  s! \* !$g_escape_table{'*'}!gox;
            $cur_token->[1] =~  s! _  !$g_escape_table{'_'}!gox;
        }
        $text .= $cur_token->[1];
    }
    return $text;
}

sub _DoAnchors {
#
# Turn Markdown link shortcuts into XHTML <a> tags.
#
    my ($self, $text) = @_;

    #
    # First, handle reference-style links: [link text] [id]
    #
    $text =~ s{
        (                   # wrap whole match in $1
          \[
            ($g_nested_brackets)    # link text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
            (.*?)       # id = $3
          \]
        )
    }{
        my $whole_match = $1;
        my $link_text   = $2;
        my $link_id     = lc $3;

        if ($link_id eq "") {
            $link_id = lc $link_text;   # for shortcut links like [this][].
        }

        $link_id =~ s{[ ]*\n}{ }g; # turn embedded newlines into spaces

        $self->_GenerateAnchor($whole_match, $link_text, $link_id);
    }xsge;

    #
    # Next, inline-style links: [link text](url "optional title")
    #
    $text =~ s{
        (               # wrap whole match in $1
          \[
            ($g_nested_brackets)    # link text = $2
          \]
          \(            # literal paren
            [ \t]*
            ($g_nested_parens)   # href = $3
            [ \t]*
            (           # $4
              (['"])    # quote char = $5
              (.*?)     # Title = $6
              \5        # matching quote
              [ \t]*    # ignore any spaces/tabs between closing quote and )
            )?          # title is optional
          \)
        )
    }{
        my $result;
        my $whole_match = $1;
        my $link_text   = $2;
        my $url         = $3;
        my $title       = $6;

        $self->_GenerateAnchor($whole_match, $link_text, undef, $url, $title);
    }xsge;

    #
    # Last, handle reference-style shortcuts: [link text]
    # These must come last in case you've also got [link test][1]
    # or [link test](/foo)
    #
    $text =~ s{
        (                    # wrap whole match in $1
          \[
            ([^\[\]]+)        # link text = $2; can't contain '[' or ']'
          \]
        )
    }{
        my $result;
        my $whole_match = $1;
        my $link_text   = $2;
        (my $link_id = lc $2) =~ s{[ ]*\n}{ }g; # lower-case and turn embedded newlines into spaces

        $self->_GenerateAnchor($whole_match, $link_text, $link_id);
    }xsge;

    return $text;
}

sub _GenerateAnchor {
    # FIXME - Fugly, change to named params?
    my ($self, $whole_match, $link_text, $link_id, $url, $title, $attributes) = @_;

    my $result;

    $attributes = '' unless defined $attributes;

    if ( !defined $url && defined $self->{_urls}{$link_id}) {
        $url = $self->{_urls}{$link_id};
    }

    if (!defined $url) {
        return $whole_match;
    }

    $url =~ s! \* !$g_escape_table{'*'}!gox;    # We've got to encode these to avoid
    $url =~ s!  _ !$g_escape_table{'_'}!gox;    # conflicting with italics/bold.
    $url =~ s{^<(.*)>$}{$1};                    # Remove <>'s surrounding URL, if present

    $result = qq{<a href="$url"};

    if ( !defined $title && defined $link_id && defined $self->{_titles}{$link_id} ) {
        $title = $self->{_titles}{$link_id};
    }

    if ( defined $title ) {
        $title =~ s/"/&quot;/g;
        $title =~ s! \* !$g_escape_table{'*'}!gox;
        $title =~ s!  _ !$g_escape_table{'_'}!gox;
        $result .=  qq{ title="$title"};
    }

    $result .= "$attributes>$link_text</a>";

    return $result;
}

sub _DoImages {
#
# Turn Markdown image shortcuts into <img> tags.
#
    my ($self, $text) = @_;

    #
    # First, handle reference-style labeled images: ![alt text][id]
    #
    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
            (.*?)       # id = $3
          \]

        )
    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;
        my $link_id     = lc $3;

        if ($link_id eq '') {
            $link_id = lc $alt_text;     # for shortcut links like ![this][].
        }

        $self->_GenerateImage($whole_match, $alt_text, $link_id);
    }xsge;

    #
    # Next, handle inline images:  ![alt text](url "optional title")
    # Don't forget: encode * and _

    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]
          \(            # literal paren
            [ \t]*
            ($g_nested_parens)  # src url - href = $3
            [ \t]*
            (           # $4
              (['"])    # quote char = $5
              (.*?)     # title = $6
              \5        # matching quote
              [ \t]*
            )?          # title is optional
          \)
        )
    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;
        my $url         = $3;
        my $title       = '';
        if (defined($6)) {
            $title      = $6;
        }

        $self->_GenerateImage($whole_match, $alt_text, undef, $url, $title);
    }xsge;

    return $text;
}

sub _GenerateImage {
    # FIXME - Fugly, change to named params?
    my ($self, $whole_match, $alt_text, $link_id, $url, $title, $attributes) = @_;

    my $result;

    $attributes = '' unless defined $attributes;

    $alt_text ||= '';
    $alt_text =~ s/"/&quot;/g;
    # FIXME - how about >

    if ( !defined $url && defined $self->{_urls}{$link_id}) {
        $url = $self->{_urls}{$link_id};
    }

    # If there's no such link ID, leave intact:
    return $whole_match unless defined $url;

    $url =~ s! \* !$g_escape_table{'*'}!ogx;     # We've got to encode these to avoid
    $url =~ s!  _ !$g_escape_table{'_'}!ogx;     # conflicting with italics/bold.
    $url =~ s{^<(.*)>$}{$1};                    # Remove <>'s surrounding URL, if present

    if (!defined $title && length $link_id && defined $self->{_titles}{$link_id} && length $self->{_titles}{$link_id}) {
        $title = $self->{_titles}{$link_id};
    }

    $result = qq{<img src="$url" alt="$alt_text"};
    if (defined $title && length $title) {
        $title =~ s! \* !$g_escape_table{'*'}!ogx;
        $title =~ s!  _ !$g_escape_table{'_'}!ogx;
        $title    =~ s/"/&quot;/g;
        $result .=  qq{ title="$title"};
    }
    $result .= $attributes . $self->{empty_element_suffix};

    return $result;
}

sub _DoHeaders {
    my ($self, $text) = @_;

    # Setext-style headers:
    #     Header 1
    #     ========
    #
    #     Header 2
    #     --------
    #
    $text =~ s{ ^(.+)[ \t]*\n=+[ \t]*\n+ }{
        $self->_GenerateHeader('1', $1);
    }egmx;

    $text =~ s{ ^(.+)[ \t]*\n-+[ \t]*\n+ }{
        $self->_GenerateHeader('2', $1);
    }egmx;


    # atx-style headers:
    #   # Header 1
    #   ## Header 2
    #   ## Header 2 with closing hashes ##
    #   ...
    #   ###### Header 6
    #
    my $l;
    $text =~ s{
            ^(\#{1,6})  # $1 = string of #'s
            [ \t]*
            (.+?)       # $2 = Header text
            [ \t]*
            \#*         # optional closing #'s (not counted)
            \n+
        }{
            my $h_level = length($1);
            $self->_GenerateHeader($h_level, $2);
        }egmx;

    return $text;
}

sub _GenerateHeader {
    my ($self, $level, $id) = @_;

    return "<h$level>"  .  $self->_RunSpanGamut($id)  .  "</h$level>\n\n";
}

sub _DoLists {
#
# Form HTML ordered (numbered) and unordered (bulleted) lists.
#
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    # Re-usable patterns to match list item bullets and number markers:
    my $marker_ul  = qr/[*+-]/;
    my $marker_ol  = qr/\d+[.]/;
    my $marker_any = qr/(?:$marker_ul|$marker_ol)/;

    # Re-usable pattern to match any entirel ul or ol list:
    my $whole_list = qr{
        (                               # $1 = whole list
          (                             # $2
            [ ]{0,$less_than_tab}
            (${marker_any})             # $3 = first list item marker
            [ \t]+
          )
          (?s:.+?)
          (                             # $4
              \z
            |
              \n{2,}
              (?=\S)
              (?!                       # Negative lookahead for another list item marker
                [ \t]*
                ${marker_any}[ \t]+
              )
          )
        )
    }mx;

    # We use a different prefix before nested lists than top-level lists.
    # See extended comment in _ProcessListItems().
    #
    # Note: There's a bit of duplication here. My original implementation
    # created a scalar regex pattern as the conditional result of the test on
    # $self->{_list_level}, and then only ran the $text =~ s{...}{...}egmx
    # substitution once, using the scalar as the pattern. This worked,
    # everywhere except when running under MT on my hosting account at Pair
    # Networks. There, this caused all rebuilds to be killed by the reaper (or
    # perhaps they crashed, but that seems incredibly unlikely given that the
    # same script on the same server ran fine *except* under MT. I've spent
    # more time trying to figure out why this is happening than I'd like to
    # admit. My only guess, backed up by the fact that this workaround works,
    # is that Perl optimizes the substition when it can figure out that the
    # pattern will never change, and when this optimization isn't on, we run
    # afoul of the reaper. Thus, the slightly redundant code to that uses two
    # static s/// patterns rather than one conditional pattern.

    if ($self->{_list_level}) {
        $text =~ s{
                ^
                $whole_list
            }{
                my $list = $1;
                my $marker = $3;
                my $list_type = ($marker =~ m/$marker_ul/) ? "ul" : "ol";
                # Turn double returns into triple returns, so that we can make a
                # paragraph for the last item in a list, if necessary:
                $list =~ s/\n{2,}/\n\n\n/g;
                my $result = ( $list_type eq 'ul' ) ?
                    $self->_ProcessListItemsUL($list, $marker_ul)
                  : $self->_ProcessListItemsOL($list, $marker_ol);

                $result = $self->_MakeList($list_type, $result, $marker);
                $result;
            }egmx;
    }
    else {
        $text =~ s{
                (?:(?<=\n\n)|\A\n?)
                $whole_list
            }{
                my $list = $1;
                my $marker = $3;
                my $list_type = ($marker =~ m/$marker_ul/) ? "ul" : "ol";
                # Turn double returns into triple returns, so that we can make a
                # paragraph for the last item in a list, if necessary:
                $list =~ s/\n{2,}/\n\n\n/g;
                my $result = ( $list_type eq 'ul' ) ?
                    $self->_ProcessListItemsUL($list, $marker_ul)
                  : $self->_ProcessListItemsOL($list, $marker_ol);
                $result = $self->_MakeList($list_type, $result, $marker);
                $result;
            }egmx;
    }


    return $text;
}

sub _MakeList {
  my ($self, $list_type, $content, $marker) = @_;

  if ($list_type eq 'ol' and $self->{trust_list_start_value}) {
    my ($num) = $marker =~ /^(\d+)[.]/;
    return "<ol start='$num'>\n" . $content . "</ol>\n";
  }

  return "<$list_type>\n" . $content . "</$list_type>\n";
}

sub _ProcessListItemsOL {
#
#   Process the contents of a single ordered list, splitting it
#   into individual list items.
#

    my ($self, $list_str, $marker_any) = @_;


    # The $self->{_list_level} global keeps track of when we're inside a list.
    # Each time we enter a list, we increment it; when we leave a list,
    # we decrement. If it's zero, we're not in a list anymore.
    #
    # We do this because when we're not inside a list, we want to treat
    # something like this:
    #
    #       I recommend upgrading to version
    #       8. Oops, now this line is treated
    #       as a sub-list.
    #
    # As a single paragraph, despite the fact that the second line starts
    # with a digit-period-space sequence.
    #
    # Whereas when we're inside a list (or sub-list), that line will be
    # treated as the start of a sub-list. What a kludge, huh? This is
    # an aspect of Markdown's syntax that's hard to parse perfectly
    # without resorting to mind-reading. Perhaps the solution is to
    # change the syntax rules such that sub-lists must start with a
    # starting cardinal number; e.g. "1." or "a.".

    $self->{_list_level}++;

    # trim trailing blank lines:
    $list_str =~ s/\n{2,}\z/\n/;


    $list_str =~ s{
        (\n)?                           # leading line = $1
        (^[ \t]*)                       # leading whitespace = $2
        ($marker_any) [ \t]+            # list marker = $3
        ((?s:.+?)                       # list item text   = $4
        (\n{1,2}))
        (?= \n* (\z | \2 ($marker_any) [ \t]+))
    }{
        my $item = $4;
        my $leading_line = $1;
        my $leading_space = $2;

        if ($leading_line or ($item =~ m/\n{2,}/)) {
            $item = $self->_RunBlockGamut($self->_Outdent($item), {wrap_in_p_tags => 1});
        }
        else {
            # Recursion for sub-lists:
            $item = $self->_DoLists($self->_Outdent($item));
            chomp $item;
            $item = $self->_RunSpanGamut($item);
        }

        "<li>" . $item . "</li>\n";
    }egmxo;

    $self->{_list_level}--;
    return $list_str;
}

sub _ProcessListItemsUL {
#
#   Process the contents of a single unordered list, splitting it
#   into individual list items.
#

    my ($self, $list_str, $marker_any) = @_;


    # The $self->{_list_level} global keeps track of when we're inside a list.
    # Each time we enter a list, we increment it; when we leave a list,
    # we decrement. If it's zero, we're not in a list anymore.
    #
    # We do this because when we're not inside a list, we want to treat
    # something like this:
    #
    #       I recommend upgrading to version
    #       8. Oops, now this line is treated
    #       as a sub-list.
    #
    # As a single paragraph, despite the fact that the second line starts
    # with a digit-period-space sequence.
    #
    # Whereas when we're inside a list (or sub-list), that line will be
    # treated as the start of a sub-list. What a kludge, huh? This is
    # an aspect of Markdown's syntax that's hard to parse perfectly
    # without resorting to mind-reading. Perhaps the solution is to
    # change the syntax rules such that sub-lists must start with a
    # starting cardinal number; e.g. "1." or "a.".

    $self->{_list_level}++;

    # trim trailing blank lines:
    $list_str =~ s/\n{2,}\z/\n/;


    $list_str =~ s{
        (\n)?                           # leading line = $1
        (^[ \t]*)                       # leading whitespace = $2
        ($marker_any) [ \t]+            # list marker = $3
        ((?s:.+?)                       # list item text   = $4
        (\n{1,2}))
        (?= \n* (\z | \2 ($marker_any) [ \t]+))
    }{
        my $item = $4;
        my $leading_line = $1;
        my $leading_space = $2;

        if ($leading_line or ($item =~ m/\n{2,}/)) {
            $item = $self->_RunBlockGamut($self->_Outdent($item), {wrap_in_p_tags => 1});
        }
        else {
            # Recursion for sub-lists:
            $item = $self->_DoLists($self->_Outdent($item));
            chomp $item;
            $item = $self->_RunSpanGamut($item);
        }

        "<li>" . $item . "</li>\n";
    }egmxo;

    $self->{_list_level}--;
    return $list_str;
}

sub _DoCodeBlocks {
#
# Process Markdown code blocks (indented with 4 spaces or 1 tab):
# * outdent the spaces/tab
# * encode <, >, & into HTML entities
# * escape Markdown special characters into MD5 hashes
# * trim leading and trailing newlines
#

    my ($self, $text) = @_;

     $text =~ s{
        (?:\n\n|\A)
        (                # $1 = the code block -- one or more lines, starting with a space/tab
          (?:
            (?:[ ]{$self->{tab_width}} | \t)   # Lines must start with a tab or a tab-width of spaces
            .*\n+
          )+
        )
        ((?=^[ ]{0,$self->{tab_width}}\S)|\Z)    # Lookahead for non-space at line-start, or end of doc
    }{
        my $codeblock = $1;
        my $result;  # return value

        $codeblock = $self->_EncodeCode($self->_Outdent($codeblock));
        $codeblock = $self->_Detab($codeblock);
        $codeblock =~ s/\A\n+//;  # trim leading newlines
        $codeblock =~ s/\n+\z//;  # trim trailing newlines

        $result = "\n\n<pre><code>" . $codeblock . "\n</code></pre>\n\n";

        $result;
    }egmx;

    return $text;
}

sub _DoCodeSpans {
#
#   *   Backtick quotes are used for <code></code> spans.
#
#   *   You can use multiple backticks as the delimiters if you want to
#       include literal backticks in the code span. So, this input:
#
#         Just type ``foo `bar` baz`` at the prompt.
#
#       Will translate to:
#
#         <p>Just type <code>foo `bar` baz</code> at the prompt.</p>
#
#       There's no arbitrary limit to the number of backticks you
#       can use as delimters. If you need three consecutive backticks
#       in your code, use four for delimiters, etc.
#
#   *   You can use spaces to get literal backticks at the edges:
#
#         ... type `` `bar` `` ...
#
#       Turns to:
#
#         ... type <code>`bar`</code> ...
#

    my ($self, $text) = @_;

    $text =~ s@
            (?<!\\)        # Character before opening ` can't be a backslash
            (`+)        # $1 = Opening run of `
            (.+?)        # $2 = The code block
            (?<!`)
            \1            # Matching closer
            (?!`)
        @
             my $c = "$2";
             $c =~ s/^[ \t]*//g; # leading whitespace
             $c =~ s/[ \t]*$//g; # trailing whitespace
             $c = $self->_EncodeCode($c);
            "<code>$c</code>";
        @egsx;

    return $text;
}

sub _EncodeCode {
#
# Encode/escape certain characters inside Markdown code runs.
# The point is that in code, these characters are literals,
# and lose their special Markdown meanings.
#
    my $self = shift;
    local $_ = shift;

    # Encode all ampersands; HTML entities are not
    # entities within a Markdown code span.
    s/&/&amp;/g;

    # Encode $'s, but only if we're running under Blosxom.
    # (Blosxom interpolates Perl variables in article bodies.)
    {
        no warnings 'once';
        if (defined($blosxom::version)) {
            s/\$/&#036;/g;
        }
    }


    # Do the angle bracket song and dance:
    s! <  !&lt;!gx;
    s! >  !&gt;!gx;

    # Now, escape characters that are magic in Markdown:
    s! \* !$g_escape_table{'*'}!ogx;
    s! _  !$g_escape_table{'_'}!ogx;
    s! {  !$g_escape_table{'{'}!ogx;
    s! }  !$g_escape_table{'}'}!ogx;
    s! \[ !$g_escape_table{'['}!ogx;
    s! \] !$g_escape_table{']'}!ogx;
    s! \\ !$g_escape_table{'\\'}!ogx;

    return $_;
}

sub _DoItalicsAndBold {
    my ($self, $text) = @_;

    # Handle at beginning of lines:
    $text =~ s{ ^(\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ ^(\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    # <strong> must go first:
    $text =~ s{ (?<=\W) (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ (?<=\W) (\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    # And now, a second pass to catch nested strong and emphasis special cases
    $text =~ s{ (?<=\W) (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ (?<=\W) (\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    return $text;
}

sub _DoBlockQuotes {
    my ($self, $text) = @_;

    $text =~ s{
          (                             # Wrap whole match in $1
            (
              ^[ \t]*>[ \t]?            # '>' at the start of a line
                .+\n                    # rest of the first line
              (.+\n)*                   # subsequent consecutive lines
              \n*                       # blanks
            )+
          )
        }{
            my $bq = $1;
            $bq =~ s/^[ \t]*>[ \t]?//gm;    # trim one level of quoting
            $bq =~ s/^[ \t]+$//mg;          # trim whitespace-only lines
            $bq = $self->_RunBlockGamut($bq, {wrap_in_p_tags => 1});      # recurse

            $bq =~ s/^/  /mg;
            # These leading spaces screw with <pre> content, so we need to fix that:
            $bq =~ s{
                    (\s*<pre>.+?</pre>)
                }{
                    my $pre = $1;
                    $pre =~ s/^  //mg;
                    $pre;
                }egsx;

            "<blockquote>\n$bq\n</blockquote>\n\n";
        }egmx;


    return $text;
}

sub _FormParagraphs {
#
#   Params:
#       $text - string to process with html <p> tags
#
    my ($self, $text, $options) = @_;

    # Strip leading and trailing lines:
    $text =~ s/\A\n+//;
    $text =~ s/\n+\z//;

    my @grafs = split(/\n{2,}/, $text);

    #
    # Wrap <p> tags.
    #
    foreach (@grafs) {
        unless (defined( $self->{_html_blocks}{$_} )) {
            $_ = $self->_RunSpanGamut($_);
            if ($options->{wrap_in_p_tags}) {
                s/^([ \t]*)/<p>/;
                $_ .= "</p>";
            }
        }
    }

    #
    # Unhashify HTML blocks
    #
    foreach (@grafs) {
        if (defined( $self->{_html_blocks}{$_} )) {
            $_ = $self->{_html_blocks}{$_};
        }
    }

    return join "\n\n", @grafs;
}

sub _EncodeAmpsAndAngles {
# Smart processing for ampersands and angle brackets that need to be encoded.

    my ($self, $text) = @_;
    return '' if (!defined $text or !length $text);

    # Ampersand-encoding based entirely on Nat Irons's Amputator MT plugin:
    #   http://bumppo.net/projects/amputator/
    $text =~ s/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/&amp;/g;

    # Encode naked <'s
    $text =~ s{<(?![a-z/?\$!])}{&lt;}gi;

    # And >'s - added by Fletcher Penney
#   $text =~ s{>(?![a-z/?\$!])}{&gt;}gi;
#   Causes problems...

    # Remove encoding inside comments
    $text =~ s{
        (?<=<!--) # Begin comment
        (.*?)     # Anything inside
        (?=-->)   # End comments
    }{
        my $t = $1;
        $t =~ s/&amp;/&/g;
        $t =~ s/&lt;/</g;
        $t;
    }egsx;

    return $text;
}

sub _EncodeBackslashEscapes {
#
#   Parameter:  String.
#   Returns:    The string, with after processing the following backslash
#               escape sequences.
#
    my $self = shift;
    local $_ = shift;

    s! \\\\  !$g_escape_table{'\\'}!ogx;     # Must process escaped backslashes first.
    s! \\`   !$g_escape_table{'`'}!ogx;
    s! \\\*  !$g_escape_table{'*'}!ogx;
    s! \\_   !$g_escape_table{'_'}!ogx;
    s! \\\{  !$g_escape_table{'{'}!ogx;
    s! \\\}  !$g_escape_table{'}'}!ogx;
    s! \\\[  !$g_escape_table{'['}!ogx;
    s! \\\]  !$g_escape_table{']'}!ogx;
    s! \\\(  !$g_escape_table{'('}!ogx;
    s! \\\)  !$g_escape_table{')'}!ogx;
    s! \\>   !$g_escape_table{'>'}!ogx;
    s! \\\#  !$g_escape_table{'#'}!ogx;
    s! \\\+  !$g_escape_table{'+'}!ogx;
    s! \\\-  !$g_escape_table{'-'}!ogx;
    s! \\\.  !$g_escape_table{'.'}!ogx;
    s{ \\!  }{$g_escape_table{'!'}}ogx;

    return $_;
}

sub _DoAutoLinks {
    my ($self, $text) = @_;

    $text =~ s{<((https?|ftp):[^'">\s]+)>}{<a href="$1">$1</a>}gi;

    # Email addresses: <address@domain.foo>
    $text =~ s{
        <
        (?:mailto:)?
        (
            [-.\w\+]+
            \@
            [-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+
        )
        >
    }{
        $self->_EncodeEmailAddress( $self->_UnescapeSpecialChars($1) );
    }egix;

    return $text;
}

sub _EncodeEmailAddress {
#
#   Input: an email address, e.g. "foo@example.com"
#
#   Output: the email address as a mailto link, with each character
#       of the address encoded as either a decimal or hex entity, in
#       the hopes of foiling most address harvesting spam bots. E.g.:
#
#     <a href="&#x6D;&#97;&#105;&#108;&#x74;&#111;:&#102;&#111;&#111;&#64;&#101;
#       x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;">&#102;&#111;&#111;
#       &#64;&#101;x&#x61;&#109;&#x70;&#108;&#x65;&#x2E;&#99;&#111;&#109;</a>
#
#   Based on a filter by Matthew Wickline, posted to the BBEdit-Talk
#   mailing list: <http://tinyurl.com/yu7ue>
#

    my ($self, $addr) = @_;

    my @encode = (
        sub { '&#' .                 ord(shift)   . ';' },
        sub { '&#x' . sprintf( "%X", ord(shift) ) . ';' },
        sub {                            shift          },
    );

    $addr = "mailto:" . $addr;

    $addr =~ s{(.)}{
        my $char = $1;
        if ( $char eq '@' ) {
            # this *must* be encoded. I insist.
            $char = $encode[int rand 1]->($char);
        }
        elsif ( $char ne ':' ) {
            # leave ':' alone (to spot mailto: later)
            my $r = rand;
            # roughly 10% raw, 45% hex, 45% dec
            $char = (
                $r > .9   ?  $encode[2]->($char)  :
                $r < .45  ?  $encode[1]->($char)  :
                             $encode[0]->($char)
            );
        }
        $char;
    }gex;

    $addr = qq{<a href="$addr">$addr</a>};
    $addr =~ s{">.+?:}{">}; # strip the mailto: from the visible part

    return $addr;
}

sub _UnescapeSpecialChars {
#
# Swap back in all the special characters we've hidden.
#
    my ($self, $text) = @_;

    while( my($char, $hash) = each(%g_escape_table) ) {
        $text =~ s/$hash/$char/g;
    }
    return $text;
}

sub _TokenizeHTML {
#
#   Parameter:  String containing HTML markup.
#   Returns:    Reference to an array of the tokens comprising the input
#               string. Each token is either a tag (possibly with nested,
#               tags contained therein, such as <a href="<MTFoo>">, or a
#               run of text between tags. Each element of the array is a
#               two-element array; the first is either 'tag' or 'text';
#               the second is the actual value.
#
#
#   Derived from the _tokenize() subroutine from Brad Choate's MTRegex plugin.
#       <http://www.bradchoate.com/past/mtregex.php>
#

    my ($self, $str) = @_;
    my $pos = 0;
    my $len = length $str;
    my @tokens;

    my $depth = 6;
    my $nested_tags = join('|', ('(?:<[a-z/!$](?:[^<>]') x $depth) . (')*>)' x  $depth);
    my $match = qr/(?s: <! ( -- .*? -- \s* )+ > ) |  # comment
                   (?s: <\? .*? \?> ) |              # processing instruction
                   $nested_tags/iox;                   # nested tags

    while ($str =~ m/($match)/og) {
        my $whole_tag = $1;
        my $sec_start = pos $str;
        my $tag_start = $sec_start - length $whole_tag;
        if ($pos < $tag_start) {
            push @tokens, ['text', substr($str, $pos, $tag_start - $pos)];
        }
        push @tokens, ['tag', $whole_tag];
        $pos = pos $str;
    }
    push @tokens, ['text', substr($str, $pos, $len - $pos)] if $pos < $len;
    \@tokens;
}

sub _Outdent {
#
# Remove one level of line-leading tabs or spaces
#
    my ($self, $text) = @_;

    $text =~ s/^(\t|[ ]{1,$self->{tab_width}})//gm;
    return $text;
}

sub _Detab {
#
# Cribbed from a post by Bart Lateur:
# <http://www.nntp.perl.org/group/perl.macperl.anyperl/154>
#
    my ($self, $text) = @_;

    # FIXME - Better anchor/regex would be quicker.

    # Original:
    #$text =~ s{(.*?)\t}{$1.(' ' x ($self->{tab_width} - length($1) % $self->{tab_width}))}ge;

    # Much swifter, but pretty hateful:
    do {} while ($text =~ s{^(.*?)\t}{$1.(' ' x ($self->{tab_width} - length($1) % $self->{tab_width}))}mge);
    return $text;
}

sub _ConvertCopyright {
    my ($self, $text) = @_;
    # Convert to an XML compatible form of copyright symbol

    $text =~ s/&copy;/&#xA9;/gi;

    return $text;
}

1;

__END__

=head1 OTHER IMPLEMENTATIONS

Markdown has been re-implemented in a number of languages, and with a number of additions.

Those that I have found are listed below:

=over

=item C - <http://www.pell.portland.or.us/~orc/Code/discount>

Discount - Original Markdown, but in C. Fastest implementation available, and passes MDTest.
Adds its own set of custom features.

=item python - <http://www.freewisdom.org/projects/python-markdown/>

Python Markdown which is mostly compatible with the original, with an interesting extension API.

=item ruby (maruku) - <http://maruku.rubyforge.org/>

One of the nicest implementations out there. Builds a parse tree internally so very flexible.

=item php - <http://michelf.com/projects/php-markdown/>

A direct port of Markdown.pl, also has a separately maintained 'extra' version,
which adds a number of features that were borrowed by MultiMarkdown.

=item lua - <http://www.frykholm.se/files/markdown.lua>

Port to lua. Simple and lightweight (as lua is).

=item haskell - <http://johnmacfarlane.net/pandoc/>

Pandoc is a more general library, supporting Markdown, reStructuredText, LaTeX and more.

=item javascript - <http://www.attacklab.net/showdown-gui.html>

Direct(ish) port of Markdown.pl to JavaScript

=back

=head1 BUGS

To file bug reports or feature requests please send email to:

    bug-Text-Markdown@rt.cpan.org

Please include with your report: (1) the example input; (2) the output
you expected; (3) the output Markdown actually produced.

=head1 VERSION HISTORY

See the Changes file for detailed release notes for this version.

=head1 AUTHOR

    John Gruber
    http://daringfireball.net/

    PHP port and other contributions by Michel Fortin
    http://michelf.com/

    MultiMarkdown changes by Fletcher Penney
    http://fletcher.freeshell.org/

    CPAN Module Text::MultiMarkdown (based on Text::Markdown by Sebastian
    Riedel) originally by Darren Kulp (http://kulp.ch/)
    
    Support for markdown="1" by Dan Dascalescu (http://dandascalescu.com)

    This module is maintained by: Tomas Doran http://www.bobtfish.net/

=head1 THIS DISTRIBUTION

Please note that this distribution is a fork of John Gruber's original Markdown project,
and it *is not* in any way blessed by him.

Whilst this code aims to be compatible with the original Markdown.pl (and incorporates
and passes the Markdown test suite) whilst fixing a number of bugs in the original -
there may be differences between the behaviour of this module and Markdown.pl. If you find
any differences where you believe Text::Markdown behaves contrary to the Markdown spec,
please report them as bugs.

Text::Markdown *does not* extend the markdown dialect in any way from that which is documented at
daringfireball. If you want additional features, you should look at L<Text::MultiMarkdown>.

=head1 SOURCE CODE

You can find the source code repository for L<Text::Markdown> and L<Text::MultiMarkdown>
on GitHub at <http://github.com/bobtfish/text-markdown>.

=head1 COPYRIGHT AND LICENSE

Original Code Copyright (c) 2003-2004 John Gruber
<http://daringfireball.net/>
All rights reserved.

MultiMarkdown changes Copyright (c) 2005-2006 Fletcher T. Penney
<http://fletcher.freeshell.org/>
All rights reserved.

Text::MultiMarkdown changes Copyright (c) 2006-2009 Darren Kulp
<http://kulp.ch> and Tomas Doran <http://www.bobtfish.net>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name "Markdown" nor the names of its contributors may
  be used to endorse or promote products derived from this software
  without specific prior written permission.

This software is provided by the copyright holders and contributors "as
is" and any express or implied warranties, including, but not limited
to, the implied warranties of merchantability and fitness for a
particular purpose are disclaimed. In no event shall the copyright owner
or contributors be liable for any direct, indirect, incidental, special,
exemplary, or consequential damages (including, but not limited to,
procurement of substitute goods or services; loss of use, data, or
profits; or business interruption) however caused and on any theory of
liability, whether in contract, strict liability, or tort (including
negligence or otherwise) arising in any way out of the use of this
software, even if advised of the possibility of such damage.

=cut
