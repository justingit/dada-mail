# !!! This module has been changed from the CPAN version of ver2.51 - 
#
# The, "use YAML::Syck;" line has been commented out, so as not to be needed to be loaded. 
#
# !!!

package HTML::TextToHTML;
use 5.8.1;
use strict;
#------------------------------------------------------------------------

=head1 NAME

HTML::TextToHTML - convert plain text file to HTML.

=head1 VERSION

This describes version B<2.51> of HTML::TextToHTML.

=cut

our $VERSION = '2.51';

=head1 SYNOPSIS

  From the command line:

    txt2html I<arguments>

  From Scripts:

    use HTML::TextToHTML;
 
    # create a new object
    my $conv = new HTML::TextToHTML();

    # convert a file
    $conv->txt2html(infile=>[$text_file],
                     outfile=>$html_file,
		     title=>"Wonderful Things",
		     mail=>1,
      ]);

    # reset arguments
    $conv->args(infile=>[], mail=>0);

    # convert a string
    $newstring = $conv->process_chunk($mystring)

=head1 DESCRIPTION

HTML::TextToHTML converts plain text files to HTML. The txt2html script
uses this module to do the same from the command-line.

It supports headings, tables, lists, simple character markup, and
hyperlinking, and is highly customizable. It recognizes some of the
apparent structure of the source document (mostly whitespace and
typographic layout), and attempts to mark that structure explicitly
using HTML. The purpose for this tool is to provide an easier way of
converting existing text documents to HTML format, giving something nicer
than just whapping the text into a big PRE block.

=head2 History

The original txt2html script was written by Seth Golub (see
http://www.aigeek.com/txt2html/), and converted to a perl module by
Kathryn Andersen (see http://www.katspace.com/tools/text_to_html/) and
made into a sourceforge project by Sun Tong (see
http://sourceforge.net/projects/txt2html/).  Earlier versions of the
HTML::TextToHTML module called the included script texthyper so as not
to clash with the original txt2html script, but now the projects have
all been merged.

=head1 OPTIONS

All arguments can be set when the object is created, and further options
can be set when calling the actual txt2html method. Arguments
to methods can take a hash of arguments.

Note that all option-names must match exactly -- no abbreviations are
allowed.  The argument-keys are expected to have values matching those
required for that argument -- whether that be a boolean, a string, a
reference to an array or a reference to a hash.  These will replace any
value for that argument that might have been there before.

=over

=item append_file

    append_file=>I<filename>

If you want something appended by default, put the filename here.
The appended text will not be processed at all, so make sure it's
plain text or correct HTML.  i.e. do not have things like:
    Mary Andersen E<lt>kitty@example.comE<gt>
but instead, have:
    Mary Andersen &lt;kitty@example.com&gt;

(default: nothing)

=item append_head

    append_head=>I<filename>

If you want something appended to the head by default, put the filename here.
The appended text will not be processed at all, so make sure it's
plain text or correct HTML.  i.e. do not have things like:
    Mary Andersen E<lt>kitty@example.comE<gt>
but instead, have:
    Mary Andersen &lt;kitty@example.com&gt;

(default: nothing)

=item body_deco

    body_deco=>I<string>

Body decoration string: a string to be added to the BODY tag so that
one can set attributes to the BODY (such as class, style, bgcolor etc)
For example, "class='withimage'".

=item bold_delimiter

    bold_delimiter=>I<string>

This defines what character (or string) is taken to be the delimiter of
text which is to be interpreted as bold (that is, to be given a STRONG
tag).  If this is empty, then no bolding of text will be done.
(default: #)

=item bullets

    bullets=>I<string>

This defines what single characters are taken to be "bullet" characters
for unordered lists.  Note that because this is used as a character
class, if you use '-' it must come first.
(default:-=o*\267)

=item bullets_ordered

    bullets_ordered=>I<string>

This defines what single characters are taken to be "bullet" placeholder
characters for ordered lists.  Ordered lists are normally marked by
a number or letter followed by '.' or ')' or ']' or ':'.  If an ordered
bullet is used, then it simply indicates that this is an ordered list,
without giving explicit numbers.

Note that because this is used as a character class, if you use '-' it
must come first.
(default:nothing)

=item caps_tag

    caps_tag=>I<tag>

Tag to put around all-caps lines
(default: STRONG)
If an empty tag is given, then no tag will be put around all-caps lines.

=item custom_heading_regexp

    custom_heading_regexp=>\@custom_headings

Add patterns for headings.  Header levels are assigned by regexp in the
order seen in the input text. When a line matches a custom header
regexp, it is tagged as a header.  If it's the first time that
particular regexp has matched, the next available header level is
associated with it and applied to the line.  Any later matches of that
regexp will use the same header level.  Therefore, if you want to match
numbered header lines, you could use something like this:

    my @custom_headings = ('^ *\d+\. \w+',
			   '^ *\d+\.\d+\. \w+',
			   '^ *\d+\.\d+\.\d+\. \w+');

    ...
	custom_heading_regexp=>\@custom_headings,
    ...

Then lines like

                " 1. Examples "
                " 1.1. Things"
            and " 4.2.5. Cold Fusion"

Would be marked as H1, H2, and H3 (assuming they were found in that
order, and that no other header styles were encountered).
If you prefer that the first one specified always be H1, the second
always be H2, the third H3, etc, then use the "explicit_headings"
option.

This expects a reference to an array of strings.

(default: none)

=item default_link_dict

    default_link_dict=>I<filename>

The name of the default "user" link dictionary.
(default: "$ENV{'HOME'}/.txt2html.dict" -- this is the same as for
the txt2html script.  If there is no $ENV{HOME} then it is just '.txt2html.dict')

=item demoronize

    demoronize=>1

Convert Microsoft-generated character codes that are non-ISO codes into
something more reasonable.
(default:true)

=item doctype

    doctype=>I<doctype>

This gets put in the DOCTYPE field at the top of the document, unless it's
empty.

Default :
'-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd'

If B<xhtml> is true, the contents of this is ignored, unless it's
empty, in which case no DOCTYPE declaration is output.

=item eight_bit_clean

    eight_bit_clean=>1

If false, convert Latin-1 characters to HTML entities.
If true, this conversion is disabled; also "demoronize" is set to
false, since this also changes 8-bit characters.
(default: false)

=item escape_HTML_chars

    escape_HTML_chars=>1

turn & E<lt> E<gt> into &amp; &gt; &lt;
(default: true)

=item explicit_headings

    explicit_headings=>1

Don't try to find any headings except the ones specified in the
--custom_heading_regexp option.
Also, the custom headings will not be assigned levels in the order they
are encountered in the document, but in the order they are specified on
the custom_heading_regexp option.
(default: false)

=item extract

    extract=>1

Extract Mode; don't put HTML headers or footers on the result, just
the plain HTML (thus making the result suitable for inserting into
another document (or as part of the output of a CGI script).
(default: false)

=item hrule_min

    hrule_min=>I<n>

Min number of ---s for an HRule.
(default: 4)

=item indent_width

    indent_width=>I<n>

Indents this many spaces for each level of a list.
(default: 2)

=item indent_par_break

    indent_par_break=>1

Treat paragraphs marked solely by indents as breaks with indents.
That is, instead of taking a three-space indent as a new paragraph,
put in a <BR> and three non-breaking spaces instead.
(see also --preserve_indent)
(default: false)

=item infile

    infile=>\@my_files
    infile=>['chapter1.txt', 'chapter2.txt']

The name of the input file(s).  
This expects a reference to an array of filenames.

The special filename '-' designates STDIN.

See also L</inhandle> and L</instring>.

(default:-)

=item inhandle

    inhandle=>\@my_handles
    inhandle=>[\*MYINHANDLE, \*STDIN]

An array of input filehandles; use this instead of
L</infile> or L</instring> to use a filehandle or filehandles
as input.

=item instring

    instring=>\@my_strings
    instring=>[$string1, $string2]

An array of input strings; use this instead of
L</infile> or L</inhandle> to use a string or strings
as input.

=item italic_delimiter

    italic_delimiter=>I<string>

This defines what character (or string) is taken to be the delimiter of
text which is to be interpreted as italic (that is, to be given a EM
tag).  If this is empty, no italicising of text will be done.
(default: *)

=item underline_delimiter

    underline_delimiter=>I<string>

This defines what character (or string) is taken to be the delimiter of
text which is to be interpreted as underlined (that is, to be given a U
tag).  If this is empty, no underlining of text will be done.
(default: _)

=item links_dictionaries

    links_dictionaries=>\@my_link_dicts
    links_dictionaries=>['url_links.dict', 'format_links.dict']

File(s) to use as a link-dictionary.  There can be more than one of
these.  These are in addition to the Global Link Dictionary and the User
Link Dictionary.  This expects a reference to an array of filenames.

=item link_only

    link_only=>1

Do no escaping or marking up at all, except for processing the links
dictionary file and applying it.  This is useful if you want to use
the linking feature on an HTML document.  If the HTML is a
complete document (includes HTML,HEAD,BODY tags, etc) then you'll
probably want to use the --extract option also.
(default: false)

=item lower_case_tags

     lower_case_tags=>1

Force all tags to be in lower-case.

=item mailmode

    mailmode=>1

Deal with mail headers & quoted text.  The mail header paragraph is
given the class 'mail_header', and mail-quoted text is given the class
'quote_mail'.
(default: false)

=item make_anchors

    make_anchors=>0

Should we try to make anchors in headings?
(default: true)

=item make_links

    make_links=>0

Should we try to build links?  If this is false, then the links
dictionaries are not consulted and only structural text-to-HTML
conversion is done.  (default: true)

=item make_tables

    make_tables=>1

Should we try to build tables?  If true, spots tables and marks them up
appropriately.  See L</Input File Format> for information on how tables
should be formatted.

This overrides the detection of lists; if something looks like a table,
it is taken as a table, and list-checking is not done for that
paragraph.

(default: false)

=item min_caps_length

    min_caps_length=>I<n>

min sequential CAPS for an all-caps line
(default: 3)

=item outfile

    outfile=>I<filename>

The name of the output file.  If it is "-" then the output goes
to Standard Output.
(default: - )

=item outhandle

The output filehandle; if this is given then the output goes
to this filehandle instead of to the file given in L</outfile>.

=item par_indent

    par_indent=>I<n>

Minumum number of spaces indented in first lines of paragraphs.
  Only used when there's no blank line
preceding the new paragraph.
(default: 2)

=item preformat_trigger_lines

    preformat_trigger_lines=>I<n>

How many lines of preformatted-looking text are needed to switch to <PRE>
          <= 0 : Preformat entire document
             1 : one line triggers
          >= 2 : two lines trigger

(default: 2)

=item endpreformat_trigger_lines

    endpreformat_trigger_lines=>I<n>

How many lines of unpreformatted-looking text are needed to switch from <PRE>
           <= 0 : Never preformat within document
              1 : one line triggers
           >= 2 : two lines trigger
(default: 2)

NOTE for preformat_trigger_lines and endpreformat_trigger_lines:
A zero takes precedence.  If one is zero, the other is ignored.
If both are zero, entire document is preformatted.

=item preformat_start_marker

    preformat_start_marker=>I<regexp>

What flags the start of a preformatted section if --use_preformat_marker
is true.

(default: "^(:?(:?&lt;)|<)PRE(:?(:?&gt;)|>)\$")

=item preformat_end_marker

    preformat_end_marker=>I<regexp>

What flags the end of a preformatted section if --use_preformat_marker
is true.

(default: "^(:?(:?&lt;)|<)/PRE(:?(:?&gt;)|>)\$")

=item preformat_whitespace_min

    preformat_whitespace_min=>I<n>

Minimum number of consecutive whitespace characters to trigger
normal preformatting. 
NOTE: Tabs are expanded to spaces before this check is made.
That means if B<tab_width> is 8 and this is 5, then one tab may be
expanded to 8 spaces, which is enough to trigger preformatting.
(default: 5)

=item prepend_file

    prepend_file=>I<filename>

If you want something prepended to the processed body text, put the
filename here.  The prepended text will not be processed at all, so make
sure it's plain text or correct HTML.

(default: nothing)

=item preserve_indent

    preserve_indent=>1

Preserve the first-line indentation of paragraphs marked with indents
by replacing the spaces of the first line with non-breaking spaces.
(default: false)

=item short_line_length

    short_line_length=>I<n>

Lines this short (or shorter) must be intentionally broken and are kept
that short.
(default: 40)

=item style_url

    style_url=>I<url>

This gives the URL of a stylesheet; a LINK tag will be added to the
output.

=item tab_width

    tab_width=>I<n>

How many spaces equal a tab?
(default: 8)

=item table_type
    
    table_type=>{ ALIGN=>0, PGSQL=>0, BORDER=>1, DELIM=>0 }

This determines which types of tables will be recognised when "make_tables"
is true.  The possible types are ALIGN, PGSQL, BORDER and DELIM.
(default: all types are true)

=item title

    title=>I<title>

You can specify a title.  Otherwise it will use a blank one.
(default: nothing)

=item titlefirst

    titlefirst=>1

Use the first non-blank line as the title. (See also "title")

=item underline_length_tolerance

    underline_length_tolerance=>I<n>

How much longer or shorter can underlines be and still be underlines?
(default: 1)

=item underline_offset_tolerance

    underline_offset_tolerance=>I<n>

How far offset can underlines be and still be underlines?
(default: 1)

=item unhyphenation

    unhyphenation=>0

Enables unhyphenation of text.
(default: true)

=item use_mosaic_header

    use_mosaic_header=>1

Use this option if you want to force the heading styles to match what Mosaic
outputs.  (Underlined with "***"s is H1,
with "==="s is H2, with "+++" is H3, with "---" is H4, with "~~~" is H5
and with "..." is H6)
This was the behavior of txt2html up to version 1.10.
(default: false)

=item use_preformat_marker

    use_preformat_marker=>1

Turn on preformatting when encountering "<PRE>" on a line by itself, and turn
it off when there's a line containing only "</PRE>".
When such preformatted text is detected, the PRE tag will be given the
class 'quote_explicit'.
(default: off)

=item xhtml

    xhtml=>1

Try to make the output conform to the XHTML standard, including
closing all open tags and marking empty tags correctly.  This
turns on --lower_case_tags and overrides the --doctype option.
Note that if you add a header or a footer file, it is up to you
to make it conform; the header/footer isn't touched by this.
Likewise, if you make link-dictionary entries that break XHTML,
then this won't fix them, except to the degree of putting all tags
into lower-case.

(default: true)

=back

=head1 DEBUGGING

There are global variables for setting types and levels
of debugging.  These should only be used by developers.

=over

=item $HTML::TextToHTML::Debug

$HTML::TextToHTML::Debug = 1;
    
Enable copious debugging output.
(default: false)

=item $HTML::TextToHTML::DictDebug

    $HTML::TextToHTML::DictDebug = I<n>;

Debug mode for link dictionaries. Bitwise-Or what you want to see:

          1: The parsing of the dictionary
          2: The code that will make the links
          4: When each rule matches something
          8: When each tag is created

(default: 0)

=back

=cut

our $Debug = 0;
our $DictDebug = 0;

=head1 METHODS

=cut

#------------------------------------------------------------------------
# use YAML::Syck;

our $PROG = 'HTML::TextToHTML';

#------------------------------------------------------------------------

########################################
# Definitions  (Don't change these)
#

# These are just constants I use for making bit vectors to keep track
# of what modes I'm in and what actions I've taken on the current and
# previous lines.

our $NONE         = 0;
our $LIST         = 1;
our $HRULE        = 2;
our $PAR          = 4;
our $PRE          = 8;
our $END          = 16;
our $BREAK        = 32;
our $HEADER       = 64;
our $MAILHEADER   = 128;
our $MAILQUOTE    = 256;
our $CAPS         = 512;
our $LINK         = 1024;
our $PRE_EXPLICIT = 2048;
our $TABLE        = 4096;
our $IND_BREAK    = 8192;
our $LIST_START   = 16384;
our $LIST_ITEM    = 32768;

# Constants for Link-processing
# bit-vectors for what to do with a particular link-dictionary entry
our $LINK_NOCASE    = 1;
our $LINK_EVAL      = 2;
our $LINK_HTML      = 4;
our $LINK_ONCE      = 8;
our $LINK_SECT_ONCE = 16;

# Constants for Ordered Lists and Unordered Lists.
# And Definition Lists.
# I use this in the list stack to keep track of what's what.

our $OL = 1;
our $UL = 2;
our $DL = 3;

# Constants for table types
our $TAB_ALIGN  = 1;
our $TAB_PGSQL  = 2;
our $TAB_BORDER = 3;
our $TAB_DELIM  = 4;

# Constants for tags
use constant {
    TAG_START	=> 1,
    TAG_END	=> 2,
    TAG_EMPTY	=> 3,
};

# Character entity names
# characters to replace with entities
our %char_entities = (
    "\241", "&iexcl;",  "\242", "&cent;",   "\243", "&pound;",
    "\244", "&curren;", "\245", "&yen;",    "\246", "&brvbar;",
    "\247", "&sect;",   "\250", "&uml;",    "\251", "&copy;",
    "\252", "&ordf;",   "\253", "&laquo;",  "\254", "&not;",
    "\255", "&shy;",    "\256", "&reg;",    "\257", "&hibar;",
    "\260", "&deg;",    "\261", "&plusmn;", "\262", "&sup2;",
    "\263", "&sup3;",   "\264", "&acute;",  "\265", "&micro;",
    "\266", "&para;",   "\270", "&cedil;",  "\271", "&sup1;",
    "\272", "&ordm;",   "\273", "&raquo;",  "\274", "&frac14;",
    "\275", "&frac12;", "\276", "&frac34;", "\277", "&iquest;",
    "\300", "&Agrave;", "\301", "&Aacute;", "\302", "&Acirc;",
    "\303", "&Atilde;", "\304", "&Auml;",   "\305", "&Aring;",
    "\306", "&AElig;",  "\307", "&Ccedil;", "\310", "&Egrave;",
    "\311", "&Eacute;", "\312", "&Ecirc;",  "\313", "&Euml;",
    "\314", "&Igrave;", "\315", "&Iacute;", "\316", "&Icirc;",
    "\317", "&Iuml;",   "\320", "&ETH;",    "\321", "&Ntilde;",
    "\322", "&Ograve;", "\323", "&Oacute;", "\324", "&Ocirc;",
    "\325", "&Otilde;", "\326", "&Ouml;",   "\327", "&times;",
    "\330", "&Oslash;", "\331", "&Ugrave;", "\332", "&Uacute;",
    "\333", "&Ucirc;",  "\334", "&Uuml;",   "\335", "&Yacute;",
    "\336", "&THORN;",  "\337", "&szlig;",  "\340", "&agrave;",
    "\341", "&aacute;", "\342", "&acirc;",  "\343", "&atilde;",
    "\344", "&auml;",   "\345", "&aring;",  "\346", "&aelig;",
    "\347", "&ccedil;", "\350", "&egrave;", "\351", "&eacute;",
    "\352", "&ecirc;",  "\353", "&euml;",   "\354", "&igrave;",
    "\355", "&iacute;", "\356", "&icirc;",  "\357", "&iuml;",
    "\360", "&eth;",    "\361", "&ntilde;", "\362", "&ograve;",
    "\363", "&oacute;", "\364", "&ocirc;",  "\365", "&otilde;",
    "\366", "&ouml;",   "\367", "&divide;", "\370", "&oslash;",
    "\371", "&ugrave;", "\372", "&uacute;", "\373", "&ucirc;",
    "\374", "&uuml;",   "\375", "&yacute;", "\376", "&thorn;",
    "\377", "&yuml;",   "\267", "&middot;",
);

# alignments for tables
our @alignments    = ('', '', ' ALIGN="RIGHT"', ' ALIGN="CENTER"');
our @lc_alignments = ('', '', ' align="right"', ' align="center"');
our @xhtml_alignments =
  ('', '', ' style="text-align: right;"', ' style="text-align: center;"');

#---------------------------------------------------------------#
# Object interface
#---------------------------------------------------------------#

=head2 new

    $conv = new HTML::TextToHTML()

    $conv = new HTML::TextToHTML(titlefirst=>1,
	...
    );

Create a new object with new. If arguments are given, these arguments
will be used in invocations of other methods.

See L</OPTIONS> for the possible values of the arguments.

=cut

sub new
{
    my $invocant = shift;
    my $self     = {};

    my $class = ref($invocant) || $invocant;    # Object or class name
    init_our_data($self);

    # bless self
    bless($self, $class);

    $self->args(@_);

    return $self;
}    # new

=head2 args

    $conv->args(short_line_length=>60,
	titlefirst=>1,
	....
    );

Updates the current arguments/options of the HTML::TextToHTML object.
Takes hash of arguments, which will be used in invocations of other
methods.
See L</OPTIONS> for the possible values of the arguments.

=cut

sub args
{
    my $self      = shift;
    my %args = @_;

    if (%args)
    {
        if ($Debug)
        {
            print STDERR "========args(hash)========\n";
            print STDERR Dump(%args);
        }
	my $arg;
	my $val;
	while (($arg, $val) = each %args)
        {
            if (defined $val)
            {
                if ($arg =~ /^-/)
                {
                    $arg =~ s/^-//;    # get rid of first dash
                    $arg =~ s/^-//;    # get rid of possible second dash
                }
                if ($Debug)
                {
                    print STDERR "--", $arg;
                }
                $self->{$arg} = $val;
                if ($Debug)
                {
                    print STDERR " ", $val, "\n";
                }
            }
        }
    }
    $self->deal_with_options();
    if ($Debug)
    {
        print STDERR Dump($self);
    }

    return 1;
}    # args

=head2 process_chunk

$newstring = $conv->process_chunk($mystring);

Convert a string to a HTML fragment.  This assumes that this string is
at the least, a single paragraph, but it can contain more than that.
This returns the processed string.  If you want to pass arguments to
alter the behaviour of this conversion, you need to do that earlier,
either when you create the object, or with the L</args> method.

    $newstring = $conv->process_chunk($mystring,
			    close_tags=>0);

If there are open tags (such as lists) in the input string,
process_chunk will automatically close them, unless you specify not
to, with the close_tags option.

    $newstring = $conv->process_chunk($mystring,
			    is_fragment=>1);

If you want this string to be treated as a fragment, and not assumed to
be a paragraph, set is_fragment to true.  If there is more than one
paragraph in the string (ie it contains blank lines) then this option
will be ignored.

=cut

sub process_chunk ($$;%)
{
    my $self  = shift;
    my $chunk = shift;
    my %args  = (
        close_tags  => 1,
        is_fragment => 0,
        @_
    );

    my $ret_str = '';
    my @paras   = split(/\r?\n\r?\n/, $chunk);
    my $ind     = 0;
    if (@paras == 1)    # just one paragraph
    {
        $ret_str .= $self->process_para(
            $chunk,
            close_tags  => $args{close_tags},
            is_fragment => $args{is_fragment}
        );
    }
    else
    {
        my $ind = 0;
        foreach my $para (@paras)
        {
            # if the paragraph doesn't end with a newline, add one
            $para .= "\n" if ($para !~ /\n$/);
            if ($ind == @paras - 1)    # last one
            {
                $ret_str .= $self->process_para(
                    $para,
                    close_tags  => $args{close_tags},
                    is_fragment => 0
                );
            }
            else
            {
                $ret_str .= $self->process_para(
                    $para,
                    close_tags  => 0,
                    is_fragment => 0
                );
            }
            $ind++;
        }
    }
    $ret_str;
}    # process_chunk

=head2 process_para

$newstring = $conv->process_para($mystring);

Convert a string to a HTML fragment.  This assumes that this string is
at the most a single paragraph, with no blank lines in it.  If you don't
know whether your string will contain blank lines or not, use the
L</process_chunk> method instead.

This returns the processed string.  If you want to pass arguments to
alter the behaviour of this conversion, you need to do that earlier,
either when you create the object, or with the L</args> method.

    $newstring = $conv->process_para($mystring,
			    close_tags=>0);

If there are open tags (such as lists) in the input string, process_para
will automatically close them, unless you specify not to, with the
close_tags option.

    $newstring = $conv->process_para($mystring,
			    is_fragment=>1);

If you want this string to be treated as a fragment, and not assumed to be
a paragraph, set is_fragment to true.

=cut

sub process_para ($$;%)
{
    my $self = shift;
    my $para = shift;
    my %args = (
        close_tags  => 1,
        is_fragment => 0,
        @_
    );

    # if this is an external call, do certain initializations
    $self->do_init_call();

    my $para_action = $NONE;

    # tables and mailheaders don't carry over from one para to the next
    if ($self->{__mode} & $TABLE)
    {
        $self->{__mode} ^= $TABLE;
    }
    if ($self->{__mode} & $MAILHEADER)
    {
        $self->{__mode} ^= $MAILHEADER;
    }

    # convert Microsoft character codes into sensible characters
    if ($self->{demoronize})
    {
        demoronize_char($para);
    }

    # if we are not just linking, we are discerning structure
    if (!$self->{link_only})
    {

        # Chop trailing whitespace and DOS CRs
        $para =~ s/[ \011]*\015$//;
        # Chop leading whitespace and DOS CRs
        $para =~ s/^[ \011]*\015//;
        $para =~ s/\r//g;             # remove any stray carriage returns

        my @done_lines = ();          # lines which have been processed

        # The PRE_EXPLICIT structure can carry over from one
        # paragraph to the next, but it is ended with the
        # explicit end-tag designated for it.
        # Therefore we can shortcut for this by checking
        # for the end of the PRE_EXPLICIT and chomping off
        # the preformatted string part of this para before
        # we have to split it into lines.
        # Note that after this check, we could *still* be
        # in PRE_EXPLICIT mode.
        if ($self->{__mode} & $PRE_EXPLICIT)
        {
            my $pre_str =
              $self->split_end_explicit_preformat(para_ref => \$para);
            if ($pre_str)
            {
                push @done_lines, $pre_str;
            }
        }

        if (defined $para && $para ne "")
        {
            #
            # Now we split the paragraph into lines
            #
            my $para_len         = length($para);
            my @para_lines       = split(/^/, $para);
            my @para_line_len    = ();
            my @para_line_indent = ();
            my @para_line_action = ();
            my $i                = 0;
            foreach my $line (@para_lines)
            {
                # Change all tabs to spaces
                while ($line =~ /\011/)
                {
                    my $tw = $self->{tab_width};
                    $line =~ s/\011/" " x ($tw - (length($`) % $tw))/e;
                }
                push @para_line_len, length($line);
                if ($line =~ /^\s*$/)
                {
                    # if the line is blank, use the previous indent
                    # if there is one
                    push @para_line_indent,
                      ($i == 0 ? 0 : $para_line_indent[$i - 1]);
                }
                else
                {
                    # count the number of leading spaces
                    my ($ws) = $line =~ /^( *)[^ ]/;
                    push @para_line_indent, length($ws);
                }
                push @para_line_action, $NONE;
                $i++;
            }

            # There are two more structures which carry over from one
            # paragraph to the next: LIST, PRE
            # There are also certain things which will immediately end
            # multi-paragraph LIST and PRE, if found at the start
            # of a paragraph:
            # A list will be ended by
            # TABLE, MAILHEADER, HEADER, custom-header
            # A PRE will be ended by
            # TABLE, MAILHEADER and non-pre text

            my $is_table         = 0;
            my $table_type       = 0;
            my $is_mailheader    = 0;
            my $is_header        = 0;
            my $is_custom_header = 0;
            if (@{$self->{custom_heading_regexp}})
            {
                $is_custom_header =
                  $self->is_custom_heading(line => $para_lines[0]);
            }
            if (   $self->{make_tables}
                && @para_lines > 1)
            {
                $table_type = $self->get_table_type(
                    rows_ref => \@para_lines,
                    para_len => $para_len
                );
                $is_table = ($table_type != 0);
            }
            if (   !$self->{explicit_headings}
                && @para_lines > 1
                && !$is_table)
            {
                $is_header = $self->is_heading(
                    line_ref => \$para_lines[0],
                    next_ref => \$para_lines[1]
                );
            }
            # Note that it is concievable that someone has
            # partially disabled mailmode by making a custom header
            # which matches the start of mail.
            # This is stupid, but allowable, so we check.
            if (   $self->{mailmode}
                && !$is_table
                && !$is_custom_header)
            {
                $is_mailheader = $self->is_mailheader(rows_ref => \@para_lines);
            }

            # end the list if we can end it
            if (
                ($self->{__mode} & $LIST)
                && (   $is_table
                    || $is_mailheader
                    || $is_header
                    || $is_custom_header)
              )
            {
                my $list_end = '';
                my $action   = 0;
                $self->endlist(
                    num_lists       => $self->{__listnum},
                    prev_ref        => \$list_end,
                    line_action_ref => \$action
                );
                push @done_lines, $list_end;
                $self->{__prev_para_action} |= $END;
            }

            # end the PRE if we can end it
            if (
                   ($self->{__mode} & $PRE)
                && !($self->{__mode} & $PRE_EXPLICIT)
                && (   $is_table
                    || $is_mailheader
                    || !$self->is_preformatted($para_lines[0]))
                && ($self->{preformat_trigger_lines} != 0)
              )
            {
                my $pre_end = '';
                my $tag     = $self->close_tag('pre');
                $pre_end = "${tag}\n";
                $self->{__mode} ^= ($PRE & $self->{__mode});
                push @done_lines, $pre_end;
                $self->{__prev_para_action} |= $END;
            }

            # The PRE and PRE_EXPLICIT structure can carry over
            # from one paragraph to the next, but because we don't
            # want trailing newlines, such newlines would have been
            # gotten rid of in the previous call.  However, with
            # a preformatted text, we do want the blank lines in it
            # to be preserved, so let's add a blank line in here.
            if ($self->{__mode} & $PRE)
            {
                push @done_lines, "\n";
            }

            # Now, we do certain things which are only found at the
            # start of a paragraph:
            # HEADER, custom-header, TABLE and MAILHEADER
            # These could concievably eat the rest of the paragraph.

            if ($is_custom_header)
            {
                # custom header eats the first line
                my $header = shift @para_lines;
                shift @para_line_len;
                shift @para_line_indent;
                shift @para_line_action;
                $self->custom_heading(line_ref => \$header);
                push @done_lines, $header;
                $self->{__prev_para_action} |= $HEADER;
            }
            elsif ($is_header)
            {
                # normal header eats the first two lines
                my $header = shift @para_lines;
                shift @para_line_len;
                shift @para_line_indent;
                shift @para_line_action;
                my $underline = shift @para_lines;
                shift @para_line_len;
                shift @para_line_indent;
                shift @para_line_action;
                $self->heading(
                    line_ref => \$header,
                    next_ref => \$underline
                );
                push @done_lines, $header;
                $self->{__prev_para_action} |= $HEADER;
            }

            # do the table stuff on the array of lines
            if ($self->{make_tables} && $is_table)
            {
                if (
                    $self->tablestuff(
                        table_type => $table_type,
                        rows_ref   => \@para_lines,
                        para_len   => $para_len
                    )
                  )
                {
                    # this has used up all the lines
                    push @done_lines, @para_lines;
                    @para_lines = ();
                }
            }

            # check of this para is a mail-header
            if (   $is_mailheader
                && !($self->{__mode} & $TABLE)
                && @para_lines)
            {
                $self->mailheader(rows_ref => \@para_lines);
                # this has used up all the lines
                push @done_lines, @para_lines;
                @para_lines = ();
            }

            #
            # Now go through the paragraph lines one at a time
            # Note that we won't have TABLE, MAILHEADER, HEADER modes
            # because they would have eaten the lines
            #
            my $prev        = '';
            my $prev_action = $self->{__prev_para_action};
            for (my $i = 0; $i < @para_lines; $i++)
            {
                my $prev_ref;
                my $prev_action_ref;
                my $prev_line_indent;
                my $prev_line_len;
                if ($i == 0)
                {
                    $prev_ref         = \$prev;
                    $prev_action_ref  = \$prev_action;
                    $prev_line_indent = 0;
                    $prev_line_len    = 0;
                }
                else
                {
                    $prev_ref         = \$para_lines[$i - 1];
                    $prev_action_ref  = \$para_line_action[$i - 1];
                    $prev_line_indent = $para_line_indent[$i - 1];
                    $prev_line_len    = $para_line_len[$i - 1];
                }
                my $next_ref;
                if ($i == $#para_lines)
                {
                    $next_ref = undef;
                }
                else
                {
                    $next_ref = \$para_lines[$i + 1];
                }

                $para_lines[$i] = escape($para_lines[$i])
                  if ($self->{escape_HTML_chars});

                if ($self->{mailmode}
                    && !($self->{__mode} & ($PRE_EXPLICIT)))
                {
                    $self->mailquote(
                        line_ref        => \$para_lines[$i],
                        line_action_ref => \$para_line_action[$i],
                        prev_ref        => $prev_ref,
                        prev_action_ref => $prev_action_ref,
                        next_ref        => $next_ref
                    );
                }

                if (   ($self->{__mode} & $PRE)
                    && ($self->{preformat_trigger_lines} != 0))
                {
                    $self->endpreformat(
                        para_lines_ref  => \@para_lines,
                        para_action_ref => \@para_line_action,
                        ind             => $i,
                        prev_ref        => $prev_ref
                    );
                }

                if (!($self->{__mode} & $PRE))
                {
                    $self->hrule(
                        para_lines_ref  => \@para_lines,
                        para_action_ref => \@para_line_action,
                        ind             => $i
                    );
                }
                if (!($self->{__mode} & ($PRE))
                    && ($para_lines[$i] !~ /^\s*$/))
                {
                    $self->liststuff(
                        para_lines_ref       => \@para_lines,
                        para_action_ref      => \@para_line_action,
                        para_line_indent_ref => \@para_line_indent,
                        ind                  => $i,
                        prev_ref             => $prev_ref
                    );
                }
                if (   !($para_line_action[$i] & ($HEADER | $LIST))
                    && !($self->{__mode} & ($LIST | $PRE))
                    && $self->{__preformat_enabled})
                {
                    $self->preformat(
                        mode_ref        => \$self->{__mode},
                        line_ref        => \$para_lines[$i],
                        line_action_ref => \$para_line_action[$i],
                        prev_ref        => $prev_ref,
                        next_ref        => $next_ref,
                        prev_action_ref => $prev_action_ref
                    );
                }
                if (!($self->{__mode} & ($PRE)))
                {
                    $self->paragraph(
                        line_ref        => \$para_lines[$i],
                        line_action_ref => \$para_line_action[$i],
                        prev_ref        => $prev_ref,
                        prev_action_ref => $prev_action_ref,
                        line_indent     => $para_line_indent[$i],
                        prev_indent     => $prev_line_indent,
                        is_fragment     => $args{is_fragment},
                        ind             => $i,
                    );
                }
                if (!($self->{__mode} & ($PRE | $LIST)))
                {
                    $self->shortline(
                        line_ref        => \$para_lines[$i],
                        line_action_ref => \$para_line_action[$i],
                        prev_ref        => $prev_ref,
                        prev_action_ref => $prev_action_ref,
                        prev_line_len   => $prev_line_len
                    );
                }
                if (!($self->{__mode} & ($PRE)))
                {
                    $self->caps(
                        line_ref        => \$para_lines[$i],
                        line_action_ref => \$para_line_action[$i]
                    );
                }

                # put the "prev" line in front of the first line
                $para_lines[$i] = $prev . $para_lines[$i]
                  if ($i == 0 && ($prev !~ /^\s*$/));
            }

            # para action is the action of the last line of the para
            $para_action = $para_line_action[$#para_line_action];
            $para_action = $NONE if (!defined $para_action);

            # push them on the done lines
            push @done_lines, @para_lines;
            @para_lines = ();

        }
        # now put the para back together as one string
        $para = join('', @done_lines);

        # if this is a paragraph, and we are in XHTML mode,
        # close an open paragraph.
        if ($self->{xhtml})
        {
            my $open_tag = @{$self->{__tags}}[$#{$self->{__tags}}];
            if (defined $open_tag && $open_tag eq 'p')
            {
                $para .= $self->close_tag('p');
            }
        }

        if (
            $self->{unhyphenation}

            # ends in hyphen & next line starts w/letters
            && ($para =~ /[^\W\d_]\-\n\s*[^\W\d_]/s) && !(
                $self->{__mode} &
                ($PRE | $HEADER | $MAILHEADER | $TABLE | $BREAK)
            )
          )
        {
            $self->unhyphenate_para(\$para);
        }
        # chop trailing newlines for continuing lists and PRE
        if (   $self->{__mode} & $LIST
            || $self->{__mode} & $PRE)
        {
            $para =~ s/\n$//g;
        }
    }

    # apply links and bold/italic/underline formatting
    if ($para !~ /^\s*$/)
    {
        $self->apply_links(
            para_ref        => \$para,
            para_action_ref => \$para_action
        );
    }

    # close any open lists if required to
    if (   $args{close_tags}
        && $self->{__mode} & $LIST)    # End all lists
    {
        $self->endlist(
            num_lists       => $self->{__listnum},
            prev_ref        => \$para,
            line_action_ref => \$para_action
        );
    }
    # close any open tags
    if ($args{close_tags} && $self->{xhtml})
    {
        while (@{$self->{__tags}})
        {
            $para .= $self->close_tag('');
        }
    }

    # convert remaining Microsoft character codes into sensible HTML
    if ($self->{demoronize} && !$self->{eight_bit_clean})
    {
        $para = demoronize_code($para);
    }
    # All the matching and formatting is done.  Now we can
    # replace non-ASCII characters with character entities.
    if (!$self->{eight_bit_clean})
    {
        my @chars = split(//, $para);
        foreach $_ (@chars)
        {
            $_ = $char_entities{$_} if defined($char_entities{$_});
        }
        $para = join('', @chars);
    }

    $self->{__prev_para_action} = $para_action;

    return $para;
}    # process_para

=head2 txt2html

    $conv->txt2html(%args);

Convert a text file to HTML.  Takes a hash of arguments.  See
L</OPTIONS> for the possible values of the arguments.  Arguments which
have already been set with B<new> or B<args> will remain as they are,
unless they are overridden.

=cut

sub txt2html ($;$)
{
    my $self = shift;

    if (@_)
    {
        $self->args(@_);
    }

    $self->do_init_call();

    my $outhandle;
    my $outhandle_needs_closing;

    # set up the output
    if ($self->{outhandle})
    {
        $outhandle               = $self->{outhandle};
        $outhandle_needs_closing = 1;
    }
    elsif ($self->{outfile} eq "-")
    {
        $outhandle               = *STDOUT;
        $outhandle_needs_closing = 0;
    }
    else
    {
        open($outhandle, "> " . $self->{outfile})
          || die "Error: unable to open ", $self->{outfile}, ": $!\n";
        $outhandle_needs_closing = 1;
    }

    # slurp up a paragraph at a time, a file at a time
    local $/ = "";
    my $para        = '';
    my $count       = 0;
    my $print_count = 0;
    my @sources     = ();
    my $source_type;
    if ($self->{infile} and @{$self->{infile}})
    {
        @sources     = @{$self->{infile}};
        $source_type = 'file';
    }
    elsif ($self->{inhandle} and @{$self->{inhandle}})
    {
        @sources     = @{$self->{inhandle}};
        $source_type = 'filehandle';
    }
    elsif ($self->{instring} and @{$self->{instring}})
    {
        @sources     = @{$self->{instring}};
        $source_type = 'string';
    }
    my $inhandle;
    my $inhandle_needs_closing = 0;
    foreach my $source (@sources)
    {
        $inhandle = undef;
        if ($source_type eq 'file')
        {
            if (!$source or $source eq '-')
            {
                $inhandle               = *STDIN;
                $inhandle_needs_closing = 0;
            }
            else
            {
                if (-f $source && open($inhandle, $source))
                {
                    $inhandle_needs_closing = 1;
                }
                else    # error
                {
                    warn "Could not open $source\n";
                    next;
                }
            }
        }
        elsif ($source_type eq 'filehandle')
        {
            $inhandle               = $source;
            $inhandle_needs_closing = 1;
        }
        if ($source_type eq 'string')
        {
            # process the string
            $para = $_;
            $para =~ s/\n$//;    # trim the endline
            if ($count == 0)
            {
                $self->do_file_start($outhandle, $para);
            }
            $self->{__done_with_sect_link} = [];
            $para = $self->process_chunk($para, close_tags => 0);
            print $outhandle $para, "\n";
            $print_count++;
            $count++;
        }
        else                     # file or filehandle
        {
            while (<$inhandle>)
            {
                $para = $_;
                $para =~ s/\n$//;    # trim the endline
                if ($count == 0)
                {
                    $self->do_file_start($outhandle, $para);
                }
                $self->{__done_with_sect_link} = [];
                $para = $self->process_chunk($para, close_tags => 0);
                print $outhandle $para, "\n";
                $print_count++;
                $count++;
            }
            if ($inhandle_needs_closing)
            {
                close($inhandle);
            }
        }
    }    # for each file

    $self->{__prev} = "";
    if ($self->{__mode} & $LIST)    # End all lists
    {
        $self->endlist(
            num_lists       => $self->{__listnum},
            prev_ref        => \$self->{__prev},
            line_action_ref => \$self->{__line_action}
        );
    }
    print $outhandle $self->{__prev};

    # end open preformats
    if ($self->{__mode} & $PRE)
    {
        my $tag = $self->close_tag('pre');
        print $outhandle $tag;
    }

    # close all open tags
    if (   $self->{xhtml}
        && !$self->{extract}
        && @{$self->{__tags}})
    {
        if ($DictDebug & 8)
        {
            print STDERR "closing all tags at end\n";
        }
        # close any open tags (until we get to the body)
        my $open_tag = @{$self->{__tags}}[$#{$self->{__tags}}];
        while (@{$self->{__tags}}
            && $open_tag ne 'body'
            && $open_tag ne 'html')
        {
            print $outhandle $self->close_tag('');
            $open_tag = @{$self->{__tags}}[$#{$self->{__tags}}];
        }
        print $outhandle "\n";
    }

    if ($self->{append_file})
    {
        if (-r $self->{append_file})
        {
            open(APPEND, $self->{append_file});
            while (<APPEND>)
            {
                print $outhandle $_;
                $print_count++;
            }
            close(APPEND);
        }
        else
        {
            print STDERR "Can't find or read file ", $self->{append_file},
              " to append.\n";
        }
    }

    # print the closing tags (if we have printed stuff at all)
    if ($print_count && !$self->{extract})
    {
        print $outhandle $self->close_tag('body'), "\n";
        print $outhandle $self->close_tag('html'), "\n";
    }
    if ($outhandle_needs_closing)
    {
        close($outhandle);
    }
    return 1;
}

=head1 PRIVATE METHODS

These are methods used internally, only of interest to developers.

=cut

#---------------------------------------------------------------#
# Init-related subroutines

=head2 init_our_data

$self->init_our_data();

Initializes the internal object data.

=cut
sub init_our_data ($)
{
    my $self = shift;

    #
    # All the options, in alphabetical order
    #
    $self->{append_file}           = '';
    $self->{append_head}           = '';
    $self->{body_deco}             = '';
    $self->{bullets}               = '-=o*\267';
    $self->{bullets_ordered}       = '';
    $self->{bold_delimiter}        = '#';
    $self->{caps_tag}              = 'STRONG';
    $self->{custom_heading_regexp} = [];
    $self->{default_link_dict}     =
      ($ENV{HOME} ? "$ENV{HOME}/.txt2html.dict" : '.txt2html.dict');
    $self->{doctype}                    = '-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd';
    $self->{demoronize}                 = 1;
    $self->{eight_bit_clean}            = 0;
    $self->{escape_HTML_chars}          = 1;
    $self->{explicit_headings}          = 0;
    $self->{extract}                    = 0;
    $self->{hrule_min}                  = 4;
    $self->{indent_width}               = 2;
    $self->{indent_par_break}           = 0;
    $self->{infile}                     = [];
    $self->{inhandle}                   = [];
    $self->{instring}                   = [];
    $self->{italic_delimiter}           = '*';
    $self->{links_dictionaries}         = [];
    $self->{link_only}                  = 0;
    $self->{lower_case_tags}            = 0;
    $self->{mailmode}                   = 0;
    $self->{make_anchors}               = 1;
    $self->{make_links}                 = 1;
    $self->{make_tables}                = 0;
    $self->{min_caps_length}            = 3;
    $self->{outfile}                    = '-';
    $self->{par_indent}                 = 2;
    $self->{preformat_trigger_lines}    = 2;
    $self->{endpreformat_trigger_lines} = 2;
    $self->{preformat_start_marker}     = "^(:?(:?&lt;)|<)PRE(:?(:?&gt;)|>)\$";
    $self->{preformat_end_marker}       = "^(:?(:?&lt;)|<)/PRE(:?(:?&gt;)|>)\$";
    $self->{preformat_whitespace_min}   = 5;
    $self->{prepend_file}               = '';
    $self->{preserve_indent}            = 0;
    $self->{short_line_length}          = 40;
    $self->{style_url}                  = '';
    $self->{tab_width}                  = 8;
    $self->{table_type}                 = {
        ALIGN  => 1,
        PGSQL  => 1,
        BORDER => 1,
        DELIM  => 1,
    };
    $self->{title}                      = '';
    $self->{titlefirst}                 = 0;
    $self->{underline_delimiter}        = '_';
    $self->{underline_length_tolerance} = 1;
    $self->{underline_offset_tolerance} = 1;
    $self->{unhyphenation}              = 1;
    $self->{use_mosaic_header}          = 0;
    $self->{use_preformat_marker}       = 0;
    $self->{xhtml}                      = 1;

    # accumulation variables
    $self->{__file}               = "";    # Current file being processed
    $self->{__heading_styles}     = {};
    $self->{__num_heading_styles} = 0;
    $self->{__links_table}        = {};
    $self->{__links_table_order}  = [];
    $self->{__links_table_patterns} = {};
    $self->{__search_patterns}    = [];
    $self->{__repl_code}          = [];
    $self->{__prev_para_action}   = 0;
    $self->{__non_header_anchor}  = 0;
    $self->{__mode}               = 0;
    $self->{__listnum}            = 0;
    $self->{__list_nice_indent}   = "";
    $self->{__list_indent}        = [];

    $self->{__call_init_done} = 0;

    #
    # The global links data
    #
    my $system_dict = <<'EOT';
#
# Global links dictionary file for HTML::TextToHTML
# http://www.katspace.com/tools/text_to_html
# http://txt2html.sourceforge.net/
# based on links dictionary for Seth Golub's txt2html
# http://www.aigeek.com/txt2html/
#
# This dictionary contains some patterns for converting obvious URLs,
# ftp sites, hostnames, email addresses and the like to hrefs.
#
# Original adapted from the html.pl package by Oscar Nierstrasz in
# the Software Archive of the Software Composition Group
# http://iamwww.unibe.ch/~scg/Src/
#

# Some people even like to mark the URL label explicitly <URL:foo:label>
/&lt;URL:([-\w\.\/:~_\@]+):([a-zA-Z0-9'() ]+)&gt;/ -h-> <A HREF="$1">$2</A>

# Some people like to mark URLs explicitly <URL:foo>
/&lt;URL:\s*(\S+?)\s*&gt;/ -h-> <A HREF="$1">$1</A>

#  <http://site>
/&lt;(http:\S+?)\s*&gt;/ -h-> &lt;<A HREF="$1">$1</A>&gt;

# Urls: <service>:<rest-of-url>

|snews:[\w\.]+|        -> $&
|news:[\w\.]+|         -> $&
|nntp:[\w/\.:+\-]+|    -> $&
|http:[\w/\.:\@+\-~\%#?=&;,]+[\w/]|  -> $&
|shttp:[\w/\.:+\-~\%#?=&;,]+| -> $&
|https:[\w/\.:+\-~\%#?=&;,]+| -> $&
|file:[\w/\.:+\-]+|     -> $&
|ftp:[\w/\.:+\-]+|      -> $&
|wais:[\w/\.:+\-]+|     -> $&
|gopher:[\w/\.:+\-]+|   -> $&
|telnet:[\w/\@\.:+\-]+|   -> $&


# catch some newsgroups to avoid confusion with sites:
|([^\w\-/\.:\@>])(alt\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(bionet\.[\w\.+\-]+[\w+\-]+)| -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(bit\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(biz\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(clari\.[\w\.+\-]+[\w+\-]+)|  -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(comp\.[\w\.+\-]+[\w+\-]+)|   -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(gnu\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(humanities\.[\w\.+\-]+[\w+\-]+)| 
          -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(k12\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(misc\.[\w\.+\-]+[\w+\-]+)|   -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(news\.[\w\.+\-]+[\w+\-]+)|   -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(rec\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(soc\.[\w\.+\-]+[\w+\-]+)|    -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(talk\.[\w\.+\-]+[\w+\-]+)|   -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(us\.[\w\.+\-]+[\w+\-]+)|     -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(ch\.[\w\.+\-]+[\w+\-]+)|     -h-> $1<A HREF="news:$2">$2</A>
|([^\w\-/\.:\@>])(de\.[\w\.+\-]+[\w+\-]+)|     -h-> $1<A HREF="news:$2">$2</A>

# FTP locations (with directory):
# anonymous@<site>:<path>
|(anonymous\@)([[:alpha:]][\w\.+\-]+\.[[:alpha:]]{2,}):(\s*)([\w\d+\-/\.]+)|
  -h-> $1<A HREF="ftp://$2/$4">$2:$4</A>$3

# ftp@<site>:<path>
|(ftp\@)([[:alpha:]][\w\.+\-]+\.[[:alpha:]]{2,}):(\s*)([\w\d+\-/\.]+)|
  -h-> $1<A HREF="ftp://$2/$4">$2:$4</A>$3

# Email address
|[[:alnum:]_\+\-\.]+\@([[:alnum:]][\w\.+\-]+\.[[:alpha:]]{2,})|
  -> mailto:$&

# <site>:<path>
|([^\w\-/\.:\@>])([[:alpha:]][\w\.+\-]+\.[[:alpha:]]{2,}):(\s*)([\w\d+\-/\.]+)|
  -h-> $1<A HREF="ftp://$2/$4">$2:$4</A>$3

# NB: don't confuse an http server with a port number for
# an FTP location!
# internet number version: <internet-num>:<path>
|([^\w\-/\.:\@])(\d{2,}\.\d{2,}\.\d+\.\d+):([\w\d+\-/\.]+)|
  -h-> $1<A HREF="ftp://$2/$3">$2:$3</A>

# telnet <site> <port>
|telnet ([[:alpha:]][\w+\-]+(\.[\w\.+\-]+)+\.[[:alpha:]]{2,})\s+(\d{2,4})|
  -h-> telnet <A HREF="telnet://$1:$3/">$1 $3</A>

# ftp <site>
|ftp ([[:alpha:]][\w+\-]+(\.[\w\.+\-]+)+\.[[:alpha:]]{2,})|
  -h-> ftp <A HREF="ftp://$1/">$1</A>

# host with "ftp" in the machine name
|\b([[:alpha:]][\w])*ftp[\w]*(\.[\w+\-]+){2,}| -h-> ftp <A HREF="ftp://$&/">$&</A>

# ftp.foo.net/blah/
|ftp(\.[\w\@:-]+)+/\S+| -> ftp://$&

# www.thehouse.org/txt2html/
|www(\.[\w\@:-]+)+/\S+| -> http://$&

# host with "www" in the machine name
|\b([[:alpha:]][\w])*www[\w]*(\.[\w+\-]+){2,}| -> http://$&/

# <site> <port>
|([[:alpha:]][\w+\-]+\.[\w+\-]+\.[[:alpha:]]{2,})\s+(\d{2,4})|
  -h-> <A HREF="telnet://$1:$2/">$1 $2</A>

# just internet numbers with port:
|([^\w\-/\.:\@])(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(\d{1,4})|
  -h-> $1<A HREF="telnet://$2:$3">$2 $3</A>

# just internet numbers:
|([^\w\-/\.:\@])(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})|
  -h-> $1<A HREF="telnet://$2">$2</A>

# RFCs
/RFC ?(\d+)/ -i-> http://www.cis.ohio-state.edu/rfc/rfc$1.txt

# Mark _underlined stuff_ as <U>underlined stuff</U>
# Don't mistake variable names for underlines, and
# take account of possible trailing punctuation
#/([ \t\n])_([[:alpha:]][[:alnum:]\s-]*[[:alpha:]])_([\s\.;:,\!\?])/ -h-> $1<U>$2</U>$3

# Seth and his amazing conversion program    :-)

"Seth Golub"  -o-> http://www.aigeek.com/
"txt2html"    -o-> http://txt2html.sourceforge.net/

# Kathryn and her amazing modules 8-)
"Kathryn Andersen"  -o-> http://www.katspace.com/
"HTML::TextToHTML"  -o-> http://www.katspace.com/tools/text_to_html/
"hypertoc"          -o-> http://www.katspace.com/tools/hypertoc/
"HTML::GenToc"      -o-> http://www.katspace.com/tools/hypertoc/

# End of global dictionary
EOT

    # pre-parse the above data by removing unwanted lines
    # skip lines that start with '#'
    $system_dict =~ s/^\#.*$//mg;
    # skip lines that end with unescaped ':'
    $system_dict =~ s/^.*[^\\]:\s*$//mg;

    $self->{__global_links_data} = $system_dict;

}    # init_our_data

#---------------------------------------------------------------#
# txt2html-related subroutines

=head2 deal_with_options

$self->deal_with_options();

do extra processing related to particular options

=cut
sub deal_with_options ($)
{
    my $self = shift;

    if (!$self->{make_links})
    {
        $self->{'links_dictionaries'} = 0;
    }
    if ($self->{append_file})
    {
        if (!-r $self->{append_file})
        {
            print STDERR "Can't find or read ", $self->{append_file}, "\n";
            $self->{append_file} = '';
        }
    }
    if ($self->{prepend_file})
    {
        if (!-r $self->{prepend_file})
        {
            print STDERR "Can't find or read ", $self->{prepend_file}, "\n";
            $self->{'prepend_file'} = '';
        }
    }
    if ($self->{append_head})
    {
        if (!-r $self->{append_head})
        {
            print STDERR "Can't find or read ", $self->{append_head}, "\n";
            $self->{'append_head'} = '';
        }
    }

    if (!$self->{outfile})
    {
        $self->{'outfile'} = "-";
    }

    $self->{'preformat_trigger_lines'} = 0
      if ($self->{preformat_trigger_lines} < 0);
    $self->{'preformat_trigger_lines'} = 2
      if ($self->{preformat_trigger_lines} > 2);

    $self->{'endpreformat_trigger_lines'} = 1
      if ($self->{preformat_trigger_lines} == 0);
    $self->{'endpreformat_trigger_lines'} = 0
      if ($self->{endpreformat_trigger_lines} < 0);
    $self->{'endpreformat_trigger_lines'} = 2
      if ($self->{endpreformat_trigger_lines} > 2);

    $self->{__preformat_enabled} =
      (($self->{endpreformat_trigger_lines} != 0)
          || $self->{use_preformat_marker});

    if ($self->{use_mosaic_header})
    {
        my $num_heading_styles = 0;
        my %heading_styles     = ();
        $heading_styles{"*"}          = ++$num_heading_styles;
        $heading_styles{"="}          = ++$num_heading_styles;
        $heading_styles{"+"}          = ++$num_heading_styles;
        $heading_styles{"-"}          = ++$num_heading_styles;
        $heading_styles{"~"}          = ++$num_heading_styles;
        $heading_styles{"."}          = ++$num_heading_styles;
        $self->{__heading_styles}     = \%heading_styles;
        $self->{__num_heading_styles} = $num_heading_styles;
    }
    # XHTML implies lower case
    $self->{'lower_case_tags'} = 1 if ($self->{xhtml});
}

=head2 escape

$newtext = escape($text);

Escape & < and >

=cut
sub escape ($)
{
    my ($text) = @_;
    $text =~ s/&/&amp;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/</&lt;/g;
    return $text;
}

=head2 demoronize_char

$newtext = demoronize_char($text);

Convert Microsoft character entities into characters.

Added by Alan Jackson, alan at ajackson dot org, and based
on the demoronize script by John Walker, http://www.fourmilab.ch/

=cut
sub demoronize_char($)
{
    my $s = shift;
    #   Map strategically incompatible non-ISO characters in the
    #   range 0x82 -- 0x9F into plausible substitutes where
    #   possible.

    $s =~ s/\x82/,/g;
    $s =~ s/\x84/,,/g;
    $s =~ s/\x85/.../g;

    $s =~ s/\x88/^/g;

    $s =~ s/\x8B/</g;
    $s =~ s/\x8C/Oe/g;

    $s =~ s/\x91/`/g;
    $s =~ s/\x92/'/g;
    $s =~ s/\x93/"/g;
    $s =~ s/\x94/"/g;
    $s =~ s/\x95/*/g;
    $s =~ s/\x96/-/g;
    $s =~ s/\x97/--/g;

    $s =~ s/\x9B/>/g;
    $s =~ s/\x9C/oe/g;

    return $s;
}

=head2 demoronize_code

$newtext = demoronize_code($text);

convert Microsoft character entities into HTML code

=cut
sub demoronize_code($)
{
    my $s = shift;
    #   Map strategically incompatible non-ISO characters in the
    #   range 0x82 -- 0x9F into plausible substitutes where
    #   possible.

    $s =~ s-\x83-<em>f</em>-g;

    $s =~ s-\x98-<sup>~</sup>-g;
    $s =~ s-\x99-<sup>TM</sup>-g;

    return $s;
}

=head2 get_tag

$tag = $self->get_tag($in_tag);

$tag = $self->get_tag($in_tag,
	tag_type=>TAG_START,
	inside_tag=>'');

output the tag wanted (add the <> and the / if necessary)
- output in lower or upper case
- do tag-related processing
options:
  tag_type=>TAG_START | tag_type=>TAG_END | tag_type=>TAG_EMPTY
  (default start)
  inside_tag=>string (default empty)

=cut
sub get_tag ($$;%)
{
    my $self   = shift;
    my $in_tag = shift;
    my %args   = (
        tag_type   => TAG_START,
        inside_tag => '',
        @_
    );
    my $inside_tag = $args{inside_tag};

    my $open_tag = @{$self->{__tags}}[$#{$self->{__tags}}];
    if (!defined $open_tag)
    {
        $open_tag = '';
    }
    # close any open tags that need closing
    # Note that we only have to check for the structural tags we make,
    # not every possible HTML tag
    my $tag_prefix = '';
    if ($self->{xhtml})
    {
        if (    $open_tag eq 'p'
            and $in_tag eq 'p'
            and $args{tag_type} != TAG_END)
        {
            $tag_prefix = $self->close_tag('p');
        }
        elsif ( $open_tag eq 'p'
            and $in_tag =~ /^(hr|ul|ol|dl|pre|table|h)/)
        {
            $tag_prefix = $self->close_tag('p');
        }
        elsif ( $open_tag eq 'li'
            and $in_tag eq 'li'
            and $args{tag_type} != TAG_END)
        {
            # close a LI before the next LI
            $tag_prefix = $self->close_tag('li');
        }
        elsif ( $open_tag eq 'li'
            and $in_tag =~ /^(ul|ol)$/
            and $args{tag_type} == TAG_END)
        {
            # close the LI before the list closes
            $tag_prefix = $self->close_tag('li');
        }
        elsif ( $open_tag eq 'dt'
            and $in_tag eq 'dd'
            and $args{tag_type} != TAG_END)
        {
            # close a DT before the next DD
            $tag_prefix = $self->close_tag('dt');
        }
        elsif ( $open_tag eq 'dd'
            and $in_tag eq 'dt'
            and $args{tag_type} != TAG_END)
        {
            # close a DD before the next DT
            $tag_prefix = $self->close_tag('dd');
        }
        elsif ( $open_tag eq 'dd'
            and $in_tag         eq 'dl'
            and $args{tag_type} == TAG_END)
        {
            # close the DD before the list closes
            $tag_prefix = $self->close_tag('dd');
        }
    }

    my $out_tag = $in_tag;
    if ($args{tag_type} == TAG_END)
    {
        $out_tag = $self->close_tag($in_tag);
    }
    else
    {
        if ($self->{lower_case_tags})
        {
            $out_tag =~ tr/A-Z/a-z/;
        }
        else    # upper case
        {
            $out_tag =~ tr/a-z/A-Z/;
        }
        if ($args{tag_type} == TAG_EMPTY)
        {
            if ($self->{xhtml})
            {
                $out_tag = "<${out_tag}${inside_tag}/>";
            }
            else
            {
                $out_tag = "<${out_tag}${inside_tag}>";
            }
        }
        else
        {
            push @{$self->{__tags}}, $in_tag;
            $out_tag = "<${out_tag}${inside_tag}>";
        }
    }
    $out_tag = $tag_prefix . $out_tag if $tag_prefix;
    if ($DictDebug & 8)
    {
        print STDERR
          "open_tag = '${open_tag}', in_tag = '${in_tag}', tag_type = ",
          $args{tag_type},
          ", inside_tag = '${inside_tag}', out_tag = '$out_tag'\n";
    }

    return $out_tag;
}    # get_tag

=head2 close_tag

$tag = $self->close_tag($in_tag);

close the open tag

=cut
sub close_tag ($$)
{
    my $self   = shift;
    my $in_tag = shift;

    my $open_tag = pop @{$self->{__tags}};
    $in_tag ||= $open_tag;
    # put the open tag back on the stack if the in-tag is not the same
    if (defined $open_tag && $open_tag ne $in_tag)
    {
        push @{$self->{__tags}}, $open_tag;
    }
    my $out_tag = $in_tag;
    if ($self->{lower_case_tags})
    {
        $out_tag =~ tr/A-Z/a-z/;
    }
    else    # upper case
    {
        $out_tag =~ tr/a-z/A-Z/;
    }
    $out_tag = "<\/${out_tag}>";
    if ($DictDebug & 8)
    {
        print STDERR
"close_tag: open_tag = '${open_tag}', in_tag = '${in_tag}', out_tag = '$out_tag'\n";
    }

    return $out_tag;
}

=head2 hrule

   $self->hrule(para_lines_ref=>$para_lines,
	     para_action_ref=>$para_action,
	     ind=>0);

Deal with horizontal rules.

=cut
sub hrule ($%)
{
    my $self = shift;
    my %args = (
        para_lines_ref  => undef,
        para_action_ref => undef,
        ind             => 0,
        @_
    );
    my $para_lines_ref  = $args{para_lines_ref};
    my $para_action_ref = $args{para_action_ref};
    my $ind             = $args{ind};

    my $hrmin = $self->{hrule_min};
    if ($para_lines_ref->[$ind] =~ /^\s*([-_~=\*]\s*){$hrmin,}$/)
    {
        my $tag = $self->get_tag("hr", tag_type => TAG_EMPTY);
        $para_lines_ref->[$ind] = "$tag\n";
        $para_action_ref->[$ind] |= $HRULE;
    }
    elsif ($para_lines_ref->[$ind] =~ /\014/)
    {
        # Linefeeds become horizontal rules
        $para_action_ref->[$ind] |= $HRULE;
        my $tag = $self->get_tag("hr", tag_type => TAG_EMPTY);
        $para_lines_ref->[$ind] =~ s/\014/\n${tag}\n/g;
    }
}

=head2 shortline

    $self->shortline(line_ref=>$line_ref,
		     line_action_ref=>$line_action_ref,
		     prev_ref=>$prev_ref,
		     prev_action_ref=>$prev_action_ref,
		     prev_line_len=>$prev_line_len);

Deal with short lines.

=cut
sub shortline ($%)
{
    my $self = shift;
    my %args = (
        line_ref        => undef,
        line_action_ref => undef,
        prev_ref        => undef,
        prev_action_ref => undef,
        prev_line_len   => 0,
        @_
    );
    my $mode_ref        = $args{mode_ref};
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};
    my $prev_ref        = $args{prev_ref};
    my $prev_action_ref = $args{prev_action_ref};
    my $prev_line_len   = $args{prev_line_len};

    # Short lines should be broken even on list item lines iff the
    # following line is more text.  I haven't figured out how to do
    # that yet.  For now, I'll just not break on short lines in lists.
    # (sorry)

    my $tag = $self->get_tag('br', tag_type => TAG_EMPTY);
    if (
           ${$line_ref} !~ /^\s*$/
        && ${$prev_ref} !~ /^\s*$/
        && ($prev_line_len < $self->{short_line_length})
        && !(
            ${$line_action_ref} &
            ($END | $HEADER | $HRULE | $LIST | $IND_BREAK | $PAR)
        )
        && !(${$prev_action_ref} & ($HEADER | $HRULE | $BREAK | $IND_BREAK))
      )
    {
        ${$prev_ref} .= $tag . chop(${$prev_ref});
        ${$prev_action_ref} |= $BREAK;
    }
}

=head2 is_mailheader

    if ($self->is_mailheader(rows_ref=>$rows_ref))
    {
	...
    }

Is this a mailheader line?

=cut
sub is_mailheader ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        @_
    );
    my $rows_ref = $args{rows_ref};

    # a mail header is assumed to be the whole
    # paragraph which starts with a From , From: or Newsgroups: line

    if ($rows_ref->[0] =~ /^(From:?)|(Newsgroups:) /)
    {
        return 1;
    }
    return 0;

}    # is_mailheader

=head2 mailheader

    $self->mailheader(rows_ref=>$rows_ref);

Deal with a mailheader.

=cut
sub mailheader ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        @_
    );
    my $rows_ref = $args{rows_ref};

    # a mail header is assumed to be the whole
    # paragraph which starts with a From: or Newsgroups: line
    my $tag  = '';
    my @rows = @{$rows_ref};

    if ($self->is_mailheader(%args))
    {
        $self->{__mode} |= $MAILHEADER;
        if ($self->{escape_HTML_chars})
        {
            $rows[0] = escape($rows[0]);
        }
        $self->anchor_mail(\$rows[0]);
        chomp ${rows}[0];
        $tag = $self->get_tag('p', inside_tag => " class='mail_header'");
        my $tag2 = $self->get_tag('br', tag_type => TAG_EMPTY);
        $rows[0] =
          join('', "<!-- New Message -->\n", $tag, $rows[0], $tag2, "\n");
        # now put breaks on the rest of the paragraph
        # apart from the last line
        for (my $rn = 1; $rn < @rows; $rn++)
        {
            if ($self->{escape_HTML_chars})
            {
                $rows[$rn] = escape($rows[$rn]);
            }
            if ($rn != (@rows - 1))
            {
                $tag = $self->get_tag('br', tag_type => TAG_EMPTY);
                chomp $rows[$rn];
                $rows[$rn] =~ s/$/${tag}\n/;
            }
        }
    }
    @{$rows_ref} = @rows;

}    # mailheader

=head2 mailquote

    $self->mailquote(line_ref=>$line_ref,
		     line_action_ref=>$line_action_ref,
		     prev_ref=>$prev_ref,
		     prev_action_ref=>$prev_action_ref,
		     next_ref=>$next_ref);

Deal with quoted mail.

=cut
sub mailquote ($%)
{
    my $self = shift;
    my %args = (
        line_ref        => undef,
        line_action_ref => undef,
        prev_ref        => undef,
        prev_action_ref => undef,
        next_ref        => undef,
        @_
    );
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};
    my $prev_ref        = $args{prev_ref};
    my $prev_action_ref = $args{prev_action_ref};
    my $next_ref        = $args{next_ref};

    my $tag = '';
    if (
        (
            (${$line_ref} =~ /^\w*&gt/)    # Handle "FF> Werewolves."
            || (${$line_ref} =~ /^[\|:]/)
        )                                  # Handle "[|:] There wolves."
        && defined($next_ref) && (${$next_ref} !~ /^\s*$/)
      )
    {
        $tag = $self->get_tag('br', tag_type => TAG_EMPTY);
        ${$line_ref} =~ s/$/${tag}/;
        ${$line_action_ref} |= ($BREAK | $MAILQUOTE);
        if (!(${$prev_action_ref} & ($BREAK | $MAILQUOTE)))
        {
            $tag = $self->get_tag('p', inside_tag => " class='quote_mail'");
            ${$prev_ref} .= $tag;
            ${$line_action_ref} |= $PAR;
        }
    }
}

=head2 subtract_modes
    
    $newvector = subtract_modes($vector, $mask);

Subtracts modes listed in $mask from $vector.

=cut
sub subtract_modes ($$)
{
    my ($vector, $mask) = @_;
    return ($vector | $mask) - $mask;
}

=head2 paragraph

    $self->paragraph(line_ref=>$line_ref,
		     line_action_ref=>$line_action_ref,
		     prev_ref=>$prev_ref,
		     prev_action_ref=>$prev_action_ref,
		     line_indent=>$line_indent,
		     prev_indent=>$prev_indent,
		     is_fragment=>$is_fragment,
		     ind=>$ind);

Detect paragraph indentation.

=cut
sub paragraph ($%)
{
    my $self = shift;
    my %args = (
        line_ref        => undef,
        line_action_ref => undef,
        prev_ref        => undef,
        prev_action_ref => undef,
        line_indent     => 0,
        prev_indent     => 0,
        is_fragment     => 0,
        ind             => 0,
        @_
    );
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};
    my $prev_ref        = $args{prev_ref};
    my $prev_action_ref = $args{prev_action_ref};
    my $line_indent     = $args{line_indent};
    my $prev_indent     = $args{prev_indent};
    my $is_fragment     = $args{is_fragment};
    my $line_no         = $args{ind};

    my $tag = '';
    if (
        ${$line_ref} !~ /^\s*$/
        && !subtract_modes(
            ${$line_action_ref}, $END | $MAILQUOTE | $CAPS | $BREAK
        )
        && (   ${$prev_ref} =~ /^\s*$/
            || (${$line_action_ref} & $END)
            || ($line_indent > $prev_indent + $self->{par_indent}))
        && !($is_fragment && $line_no == 0)
      )
    {

        if (   $self->{indent_par_break}
            && ${$prev_ref} !~ /^\s*$/
            && !(${$line_action_ref} & $END)
            && ($line_indent > $prev_indent + $self->{par_indent}))
        {
            $tag = $self->get_tag('br', tag_type => TAG_EMPTY);
            ${$prev_ref} .= $tag;
            ${$prev_ref} .= "&nbsp;" x $line_indent;
            ${$line_ref} =~ s/^ {$line_indent}//;
            ${$prev_action_ref} |= $BREAK;
            ${$line_action_ref} |= $IND_BREAK;
        }
        elsif ($self->{preserve_indent})
        {
            $tag = $self->get_tag('p');
            ${$prev_ref} .= $tag;
            ${$prev_ref} .= "&nbsp;" x $line_indent;
            ${$line_ref} =~ s/^ {$line_indent}//;
            ${$line_action_ref} |= $PAR;
        }
        else
        {
            $tag = $self->get_tag('p');
            ${$prev_ref} .= $tag;
            ${$line_action_ref} |= $PAR;
        }
    }
    # detect also a continuing indentation at the same level
    elsif ($self->{indent_par_break}
        && !($self->{__mode} & ($PRE | $TABLE | $LIST))
        && ${$prev_ref} !~ /^\s*$/
        && !(${$line_action_ref} & $END)
        && (${$prev_action_ref} & ($IND_BREAK | $PAR))
        && !subtract_modes(${$line_action_ref}, $END | $MAILQUOTE | $CAPS)
        && ($line_indent > $self->{par_indent})
        && ($line_indent == $prev_indent))
    {
        $tag = $self->get_tag('br', tag_type => TAG_EMPTY);
        ${$prev_ref} .= $tag;
        ${$prev_ref} .= "&nbsp;" x $line_indent;
        ${$line_ref} =~ s/^ {$line_indent}//;
        ${$prev_action_ref} |= $BREAK;
        ${$line_action_ref} |= $IND_BREAK;
    }
}

=head2 listprefix

    ($prefix, $number, $rawprefix, $term) = $self->listprefix($line);

Detect and parse a list item.

=cut
sub listprefix ($$)
{
    my $self = shift;
    my $line = shift;

    my ($prefix, $number, $rawprefix, $term);

    my $bullets         = $self->{bullets};
    my $bullets_ordered = $self->{bullets_ordered};
    my $number_match    = '(\d+|[^\W\d])';
    if ($bullets_ordered)
    {
        $number_match = '(\d+|[[:alpha:]]|[' . "${bullets_ordered}])";
    }
    $self->{__number_match} = $number_match;
    my $term_match = '(\w\w+)';
    $self->{__term_match} = $term_match;
    return (0, 0, 0, 0)
      if ( !($line =~ /^\s*[${bullets}]\s+\S/)
        && !($line =~ /^\s*${number_match}[\.\)\]:]\s+\S/)
        && !($line =~ /^\s*${term_match}:$/));

    ($term)   = $line =~ /^\s*${term_match}:$/;
    ($number) = $line =~ /^\s*${number_match}\S\s+\S/;
    $number = 0 unless defined($number);
    if (   $bullets_ordered
        && $number =~ /[${bullets_ordered}]/)
    {
        $number = 1;
    }

    # That slippery exception of "o" as a bullet
    # (This ought to be determined using the context of what lists
    #  we have in progress, but this will probably work well enough.)
    if ($bullets =~ /o/ && $line =~ /^\s*o\s/)
    {
        $number = 0;
    }

    if ($term)
    {
        ($rawprefix) = $line =~ /^(\s*${term_match}.)$/;
        $prefix = $rawprefix;
        $prefix =~ s/${term_match}//;    # Take the term out
    }
    elsif ($number)
    {
        ($rawprefix) = $line =~ /^(\s*${number_match}.)/;
        $prefix = $rawprefix;
        $prefix =~ s/${number_match}//;    # Take the number out
    }
    else
    {
        ($rawprefix) = $line =~ /^(\s*[${bullets}].)/;
        $prefix = $rawprefix;
    }
    ($prefix, $number, $rawprefix, $term);
}    # listprefix

=head2 startlist

    $self->startlist(prefix=>$prefix,
		     number=>0,
		     rawprefix=>$rawprefix,
		     term=>$term,
		     para_lines_ref=>$para_lines_ref,
		     para_action_ref=>$para_action_ref,
		     ind=>0,
		     prev_ref=>$prev_ref,
		     total_prefix=>$total_prefix);

Start a list.

=cut
sub startlist ($%)
{
    my $self = shift;
    my %args = (
        prefix          => '',
        number          => 0,
        rawprefix       => '',
        term            => '',
        para_lines_ref  => undef,
        para_action_ref => undef,
        ind             => 0,
        prev_ref        => undef,
        total_prefix    => '',
        @_
    );
    my $prefix          = $args{prefix};
    my $number          = $args{number};
    my $rawprefix       = $args{rawprefix};
    my $term            = $args{term};
    my $para_lines_ref  = $args{para_lines_ref};
    my $para_action_ref = $args{para_action_ref};
    my $ind             = $args{ind};
    my $prev_ref        = $args{prev_ref};

    my $tag = '';
    $self->{__listprefix}->[$self->{__listnum}] = $prefix;
    if ($number)
    {

        # It doesn't start with 1,a,A.  Let's not screw with it.
        if (($number ne "1") && ($number ne "a") && ($number ne "A"))
        {
            return 0;
        }
        $tag = $self->get_tag('ol');
        ${$prev_ref} .= join('', $self->{__list_nice_indent}, $tag, "\n");
        $self->{__list}->[$self->{__listnum}] = $OL;
    }
    elsif ($term)
    {
        $tag = $self->get_tag('dl');
        ${$prev_ref} .= join('', $self->{__list_nice_indent}, $tag, "\n");
        $self->{__list}->[$self->{__listnum}] = $DL;
    }
    else
    {
        $tag = $self->get_tag('ul');
        ${$prev_ref} .= join('', $self->{__list_nice_indent}, $tag, "\n");
        $self->{__list}->[$self->{__listnum}] = $UL;
    }

    $self->{__list_indent}->[$self->{__listnum}] = length($args{total_prefix});
    $self->{__listnum}++;
    $self->{__list_nice_indent} =
      " " x $self->{__listnum} x $self->{indent_width};
    $para_action_ref->[$ind] |= $LIST;
    $para_action_ref->[$ind] |= $LIST_START;
    $self->{__mode}          |= $LIST;
    1;
}    # startlist

=head2 endlist

    $self->endlist(num_lists=>0,
	prev_ref=>$prev_ref,
	line_action_ref=>$line_action_ref);

End N lists

=cut
sub endlist ($%)
{
    my $self = shift;
    my %args = (
        num_lists       => 0,
        prev_ref        => undef,
        line_action_ref => undef,
        @_
    );
    my $n               = $args{num_lists};
    my $prev_ref        = $args{prev_ref};
    my $line_action_ref = $args{line_action_ref};

    my $tag = '';
    for (; $n > 0; $n--, $self->{__listnum}--)
    {
        $self->{__list_nice_indent} =
          " " x ($self->{__listnum} - 1) x $self->{indent_width};
        if ($self->{__list}->[$self->{__listnum} - 1] == $UL)
        {
            $tag = $self->get_tag('ul', tag_type => TAG_END);
            ${$prev_ref} .= join('', $self->{__list_nice_indent}, $tag, "\n");
            pop @{$self->{__list_indent}};
        }
        elsif ($self->{__list}->[$self->{__listnum} - 1] == $OL)
        {
            $tag = $self->get_tag('ol', tag_type => TAG_END);
            ${$prev_ref} .= join('', $self->{__list_nice_indent}, $tag, "\n");
            pop @{$self->{__list_indent}};
        }
        elsif ($self->{__list}->[$self->{__listnum} - 1] == $DL)
        {
            $tag = $self->get_tag('dl', tag_type => TAG_END);
            ${$prev_ref} .= join('', $self->{__list_nice_indent}, $tag, "\n");
            pop @{$self->{__list_indent}};
        }
        else
        {
            print STDERR "Encountered list of unknown type\n";
        }
    }
    ${$line_action_ref} |= $END;
    $self->{__mode} ^= $LIST if (!$self->{__listnum});
}    # endlist

=head2 continuelist

    $self->continuelist(para_lines_ref=>$para_lines_ref,
			para_action_ref=>$para_action_ref,
			ind=>0,
			term=>$term);

Continue a list.

=cut
sub continuelist ($%)
{
    my $self = shift;
    my %args = (
        para_lines_ref  => undef,
        para_action_ref => undef,
        ind             => 0,
        term            => '',
        @_
    );
    my $para_lines_ref  = $args{para_lines_ref};
    my $para_action_ref = $args{para_action_ref};
    my $ind             = $args{ind};
    my $term            = $args{term};

    my $list_indent = $self->{__list_nice_indent};
    my $bullets     = $self->{bullets};
    my $num_match   = $self->{__number_match};
    my $term_match  = $self->{__term_match};
    my $tag         = '';
    if (   $self->{__list}->[$self->{__listnum} - 1] == $UL
        && $para_lines_ref->[$ind] =~ /^\s*[${bullets}]\s*/)
    {
        $tag = $self->get_tag('li');
        $para_lines_ref->[$ind] =~ s/^\s*[${bullets}]\s*/${list_indent}${tag}/;
        $para_action_ref->[$ind] |= $LIST_ITEM;
    }
    if ($self->{__list}->[$self->{__listnum} - 1] == $OL)
    {
        $tag = $self->get_tag('li');
        $para_lines_ref->[$ind] =~ s/^\s*${num_match}.\s*/${list_indent}${tag}/;
        $para_action_ref->[$ind] |= $LIST_ITEM;
    }
    if (   $self->{__list}->[$self->{__listnum} - 1] == $DL
        && $term)
    {
        $tag = $self->get_tag('dt');
        my $tag2 = $self->get_tag('dt', tag_type => TAG_END);
        $term =~ s/_/ /g;    # underscores are now spaces in the term
        $para_lines_ref->[$ind] =~
          s/^\s*${term_match}.$/${list_indent}${tag}${term}${tag2}/;
        $tag = $self->get_tag('dd');
        $para_lines_ref->[$ind] .= ${tag};
        $para_action_ref->[$ind] |= $LIST_ITEM;
    }
    $para_action_ref->[$ind] |= $LIST;
}    # continuelist

=head2 liststuff

    $self->liststuff(para_lines_ref=>$para_lines_ref,
		     para_action_ref=>$para_action_ref,
		     para_line_indent_ref=>$para_line_indent_ref,
		     ind=>0,
		     prev_ref=>$prev_ref);

Process a list (higher-level method).

=cut
sub liststuff ($%)
{
    my $self = shift;
    my %args = (
        para_lines_ref       => undef,
        para_action_ref      => undef,
        para_line_indent_ref => undef,
        ind                  => 0,
        prev_ref             => undef,
        @_
    );
    my $para_lines_ref       = $args{para_lines_ref};
    my $para_action_ref      = $args{para_action_ref};
    my $para_line_indent_ref = $args{para_line_indent_ref};
    my $ind                  = $args{ind};
    my $prev_ref             = $args{prev_ref};

    my $i;

    my ($prefix, $number, $rawprefix, $term) =
      $self->listprefix($para_lines_ref->[$ind]);

    if (!$prefix)
    {
        # if the previous line is not blank
        if ($ind > 0 && $para_lines_ref->[$ind - 1] !~ /^\s*$/)
        {
            # inside a list item
            return;
        }
        # This might be a new paragraph within an existing list item;
        # It will be the first line, and have the same indentation
        # as the list's indentation.
        if (   $ind == 0
            && $self->{__listnum}
            && $para_line_indent_ref->[$ind] ==
            $self->{__list_indent}->[$self->{__listnum} - 1])
        {
            # start a paragraph
            my $tag = $self->get_tag('p');
            ${$prev_ref} .= $tag;
            $para_action_ref->[$ind] |= $PAR;
            return;
        }
        # This ain't no list.  We'll want to end all of them.
        if ($self->{__listnum})
        {
            $self->endlist(
                num_lists       => $self->{__listnum},
                prev_ref        => $prev_ref,
                line_action_ref => \$para_action_ref->[$ind]
            );
        }
        return;
    }

    # If numbers with more than one digit grow to the left instead of
    # to the right, the prefix will shrink and we'll fail to match the
    # right list.  We need to account for this.
    my $prefix_alternate;
    if (length("" . $number) > 1)
    {
        $prefix_alternate = (" " x (length("" . $number) - 1)) . $prefix;
    }

    # Maybe we're going back up to a previous list
    for (
        $i = $self->{__listnum} - 1;
        ($i >= 0) && ($prefix ne $self->{__listprefix}->[$i]);
        $i--
      )
    {
        if (length("" . $number) > 1)
        {
            last if $prefix_alternate eq $self->{__listprefix}->[$i];
        }
    }

    my $islist;

    # Measure the indent from where the text starts, not where the
    # prefix starts.  This won't screw anything up, and if we don't do
    # it, the next line might appear to be indented relative to this
    # line, and get tagged as a new paragraph.
    my $bullets         = $self->{bullets};
    my $bullets_ordered = $self->{bullets_ordered};
    my $term_match      = $self->{__term_match};
    my ($total_prefix)  =
      $para_lines_ref->[$ind] =~ /^(\s*[${bullets}${bullets_ordered}\w]+.\s*)/;
    # a DL indent starts from the edge of the term, plus indent_width
    if ($term)
    {
        ($total_prefix) = $para_lines_ref->[$ind] =~ /^(\s*)${term_match}.$/;
        $total_prefix .= " " x $self->{indent_width};
    }

    # Of course, we only use it if it really turns out to be a list.

    $islist = 1;
    $i++;
    if (($i > 0) && ($i != $self->{__listnum}))
    {
        $self->endlist(
            num_lists       => $self->{__listnum} - $i,
            prev_ref        => $prev_ref,
            line_action_ref => \$para_action_ref->[$ind]
        );
        $islist = 0;
    }
    elsif (!$self->{__listnum} || ($i != $self->{__listnum}))
    {
        if (
               ($para_line_indent_ref->[$ind] > 0)
            || $ind == 0
            || ($ind > 0 && ($para_lines_ref->[$ind - 1] =~ /^\s*$/))
            || (   $ind > 0
                && $para_action_ref->[$ind - 1] & ($BREAK | $HEADER | $CAPS))
          )
        {
            $islist = $self->startlist(
                prefix          => $prefix,
                number          => $number,
                rawprefix       => $rawprefix,
                term            => $term,
                para_lines_ref  => $para_lines_ref,
                para_action_ref => $para_action_ref,
                ind             => $ind,
                prev_ref        => $prev_ref,
                total_prefix    => $total_prefix
            );
        }
        else
        {

            # We have something like this: "- foo" which usually
            # turns out not to be a list.
            return;
        }
    }

    $self->continuelist(
        para_lines_ref  => $para_lines_ref,
        para_action_ref => $para_action_ref,
        ind             => $ind,
        term            => $term
      )
      if ($self->{__mode} & $LIST);
    $para_line_indent_ref->[$ind] = length($total_prefix) if $islist;
}    # liststuff

=head2 get_table_type

    $table_type = $self->get_table_type(rows_ref=>$rows_ref,
					para_len=>0);

Figure out the table type of this table, if any

=cut
sub get_table_type ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $table_type = 0;
    if (   $self->{table_type}->{DELIM}
        && $self->is_delim_table(%args))
    {
        $table_type = $TAB_DELIM;
    }
    elsif ($self->{table_type}->{ALIGN}
        && $self->is_aligned_table(%args))
    {
        $table_type = $TAB_ALIGN;
    }
    elsif ($self->{table_type}->{PGSQL}
        && $self->is_pgsql_table(%args))
    {
        $table_type = $TAB_PGSQL;
    }
    elsif ($self->{table_type}->{BORDER}
        && $self->is_border_table(%args))
    {
        $table_type = $TAB_BORDER;
    }

    return $table_type;
}

=head2 is_aligned_table

    if ($self->is_aligned_table(rows_ref=>$rows_ref, para_len=>0))
    {
	...
    }

Check if the given paragraph-array is an aligned table

=cut
sub is_aligned_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # TABLES: spot and mark up tables.  We combine the lines of the
    # paragraph using the string bitwise or (|) operator, the result
    # being in $spaces.  A character in $spaces is a space only if
    # there was a space at that position in every line of the
    # paragraph.  $space can be used to search for contiguous spaces
    # that occur on all lines of the paragraph.  If this results in at
    # least two columns, the paragraph is identified as a table.

    # Note that this sub must be called before checking for preformatted
    # lines because a table may well have whitespace to the left, in
    # which case it must not be incorrectly recognised as a preformat.
    my @rows = @{$rows_ref};
    my @starts;
    my $spaces = '';
    my $max    = 0;
    my $min    = $para_len;
    foreach my $row (@rows)
    {
        ($spaces |= $row) =~ tr/ /\xff/c;
        $min = length $row if length $row < $min;
        $max = length $row if $max < length $row;
    }
    $spaces = substr $spaces, 0, $min;
    push(@starts, 0) unless $spaces =~ /^ /;
    while ($spaces =~ /((?:^| ) +)(?=[^ ])/g)
    {
        push @starts, pos($spaces);
    }

    if (2 <= @rows and 2 <= @starts)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}

=head2 is_pgsql_table

    if ($self->is_pgsql_table(rows_ref=>$rows_ref, para_len=>0))
    {
	...
    }

Check if the given paragraph-array is a Postgresql table
(the ascii format produced by Postgresql)

A PGSQL table can start with an optional table-caption,

    then it has a row of column headings separated by |
    then it has a row of ------+-----
    then it has one or more rows of column values separated by |
    then it has a row-count (N rows)

=cut
sub is_pgsql_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # A PGSQL table must have at least 4 rows (see above).
    if (@{$rows_ref} < 4)
    {
        return 0;
    }

    my @rows = @{$rows_ref};
    if ($rows[0] !~ /\|/ && $rows[0] =~ /^\s*\w+/)    # possible caption
    {
        shift @rows;
    }
    if (@rows < 4)
    {
        return 0;
    }
    if ($rows[0] !~ /^\s*\w+\s+\|\s+/)                # Colname |
    {
        return 0;
    }
    if ($rows[1] !~ /^\s*[-]+[+][-]+/)                # ----+----
    {
        return 0;
    }
    if ($rows[2] !~ /^\s*[^|]*\s+\|\s+/)              # value |
    {
        return 0;
    }
    # check the last row for rowcount
    if ($rows[$#rows] !~ /\(\d+\s+rows\)/)
    {
        return 0;
    }

    return 1;
}

=head2 is_border_table

    if ($self->is_border_table(rows_ref=>$rows_ref, para_len=>0))
    {
	...
    }

Check if the given paragraph-array is a Border table.

A BORDER table can start with an optional table-caption,

    then it has a row of +------+-----+
    then it has a row of column headings separated by |
    then it has a row of +------+-----+
    then it has one or more rows of column values separated by |
    then it has a row of +------+-----+

=cut
sub is_border_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # A BORDER table must have at least 5 rows (see above)
    # And note that it could be indented with spaces
    if (@{$rows_ref} < 5)
    {
        return 0;
    }

    my @rows = @{$rows_ref};
    if ($rows[0] !~ /\|/ && $rows[0] =~ /^\s*\w+/)    # possible caption
    {
        shift @rows;
    }
    if (@rows < 5)
    {
        return 0;
    }
    if ($rows[0] !~ /^\s*[+][-]+[+][-]+[+][-+]*$/)    # +----+----+
    {
        return 0;
    }
    if ($rows[1] !~ /^\s*\|\s*\w+\s+\|\s+.*\|$/)      # | Colname |
    {
        return 0;
    }
    if ($rows[2] !~ /^\s*[+][-]+[+][-]+[+][-+]*$/)    # +----+----+
    {
        return 0;
    }
    if ($rows[3] !~ /^\s*\|\s*[^|]*\s+\|\s+.*\|$/)    # | value |
    {
        return 0;
    }
    # check the last row for +------+------+
    if ($rows[$#rows] !~ /^\s*[+][-]+[+][-]+[+][-+]*$/)    # +----+----+
    {
        return 0;
    }

    return 1;
}    # is_border_table

=head2 is_delim_table

    if ($self->is_delim_table(rows_ref=>$rows_ref, para_len=>0))
    {
	...
    }

Check if the given paragraph-array is a Delimited table.

A DELIM table can start with an optional table-caption,
then it has at least two rows which start and end and are
punctuated by a non-alphanumeric delimiter.

    | val1 | val2 |
    | val3 | val4 |

=cut
sub is_delim_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    #
    # And note that it could be indented with spaces
    if (@{$rows_ref} < 2)
    {
        return 0;
    }

    my @rows = @{$rows_ref};
    if ($rows[0] !~ /[^\w\s]/ && $rows[0] =~ /^\s*\w+/)    # possible caption
    {
        shift @rows;
    }
    if (@rows < 2)
    {
        return 0;
    }
    # figure out if the row starts with a possible delimiter
    my $delim = '';
    if ($rows[0] =~ /^\s*([^[:alnum:]])/)
    {
        $delim = $1;
        # have to get rid of ^ and [] and \
        $delim =~ s/\^//g;
        $delim =~ s/\[//g;
        $delim =~ s/\]//g;
        $delim =~ s/\\//g;
        if (!$delim)    # no delimiter after all
        {
            return 0;
        }
    }
    else
    {
        return 0;
    }
    # There needs to be at least three delimiters in the row
    my @all_delims = ($rows[0] =~ /[${delim}]/g);
    my $total_num_delims = @all_delims;
    if ($total_num_delims < 3)
    {
        return 0;
    }
    # All rows must start and end with the delimiter
    # and have $total_num_delims number of them
    foreach my $row (@rows)
    {
        if ($row !~ /^\s*[${delim}]/)
        {
            return 0;
        }
        if ($row !~ /[${delim}]\s*$/)
        {
            return 0;
        }
        @all_delims = ($row =~ /[${delim}]/g);
        if (@all_delims != $total_num_delims)
        {
            return 0;
        }
    }

    return 1;
}    # is_delim_table

=head2 tablestuff

    $self->tablestuff(table_type=>0,
		      rows_ref=>$rows_ref,
		      para_len=>0);

Process a table.

=cut
sub tablestuff ($%)
{
    my $self = shift;
    my %args = (
        table_type => 0,
        rows_ref   => undef,
        para_len   => 0,
        @_
    );
    my $table_type = $args{table_type};
    if ($table_type eq $TAB_ALIGN)
    {
        return $self->make_aligned_table(%args);
    }
    if ($table_type eq $TAB_PGSQL)
    {
        return $self->make_pgsql_table(%args);
    }
    if ($table_type eq $TAB_BORDER)
    {
        return $self->make_border_table(%args);
    }
    if ($table_type eq $TAB_DELIM)
    {
        return $self->make_delim_table(%args);
    }
}    # tablestuff

=head2 make_aligned_table

    $self->make_aligned_table(rows_ref=>$rows_ref,
			      para_len=>0);

Make an Aligned table.

=cut
sub make_aligned_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # TABLES: spot and mark up tables.  We combine the lines of the
    # paragraph using the string bitwise or (|) operator, the result
    # being in $spaces.  A character in $spaces is a space only if
    # there was a space at that position in every line of the
    # paragraph.  $space can be used to search for contiguous spaces
    # that occur on all lines of the paragraph.  If this results in at
    # least two columns, the paragraph is identified as a table.

    # Note that this sub must be called before checking for preformatted
    # lines because a table may well have whitespace to the left, in
    # which case it must not be incorrectly recognised as a preformat.
    my @rows = @{$rows_ref};
    my @starts;
    my @ends;
    my $spaces;
    my $max = 0;
    my $min = $para_len;
    foreach my $row (@rows)
    {
        ($spaces |= $row) =~ tr/ /\xff/c;
        $min = length $row if length $row < $min;
        $max = length $row if $max < length $row;
    }
    $spaces = substr $spaces, 0, $min;
    push(@starts, 0) unless $spaces =~ /^ /;
    while ($spaces =~ /((?:^| ) +)(?=[^ ])/g)
    {
        push @ends,   pos($spaces) - length $1;
        push @starts, pos($spaces);
    }
    shift(@ends) if $spaces =~ /^ /;
    push(@ends, $max);

    # Two or more rows and two or more columns indicate a table.
    if (2 <= @rows and 2 <= @starts)
    {
        $self->{__mode} |= $TABLE;

        # For each column, guess whether it should be left, centre or
        # right aligned by examining all cells in that column for space
        # to the left or the right.  A simple majority among those cells
        # that actually have space to one side or another decides (if no
        # alignment gets a majority, left alignment wins by default).
        my @align;
        my $cell = '';
        foreach my $col (0 .. $#starts)
        {
            my @count = (0, 0, 0, 0);
            foreach my $row (@rows)
            {
                my $width = $ends[$col] - $starts[$col];
                $cell = substr $row, $starts[$col], $width;
                ++$count[($cell =~ /^ / ? 2 : 0) +
                  ($cell =~ / $/ || length($cell) < $width ? 1 : 0)];
            }
            $align[$col] = 0;
            my $population = $count[1] + $count[2] + $count[3];
            foreach (1 .. 3)
            {
                if ($count[$_] * 2 > $population)
                {
                    $align[$col] = $_;
                    last;
                }
            }
        }

        foreach my $row (@rows)
        {
            $row = join '', $self->get_tag('tr'), (
                map {
                    $cell = substr $row, $starts[$_], $ends[$_] - $starts[$_];
                    $cell =~ s/^ +//;
                    $cell =~ s/ +$//;

                    if ($self->{escape_HTML_chars})
                    {
                        $cell = escape($cell);
                    }

                    (
                        $self->get_tag(
                            'td',
                            inside_tag => (
                                $self->{xhtml} ? $xhtml_alignments[$align[$_]]
                                : (
                                      $self->{lower_case_tags}
                                    ? $lc_alignments[$align[$_]]
                                    : $alignments[$align[$_]]
                                )
                            )
                        ),
                        $cell,
                        $self->close_tag('td')
                    );
                  } 0 .. $#starts
              ),
              $self->close_tag('tr');
        }

        # put the <TABLE> around the rows
        my $tag;
        if ($self->{xhtml})
        {
            $tag = $self->get_tag('table', inside_tag => ' summary=""');
        }
        else
        {
            $tag = $self->get_tag('table');
        }
        $rows[0] = join("\n", $tag, $rows[0]);
        $tag = $self->close_tag('table', tag_type => TAG_END);
        $rows[$#rows] .= "\n${tag}";
        @{$rows_ref} = @rows;
        return 1;
    }
    else
    {
        return 0;
    }
}    # make_aligned_table

=head2 make_pgsql_table

    $self->make_pgsql_table(rows_ref=>$rows_ref,
			      para_len=>0);

Make a PGSQL table.

=cut
sub make_pgsql_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # a PGSQL table can start with an optional table-caption,
    # then it has a row of column headings separated by |
    # then it has a row of ------+-----
    # then it has one or more rows of column values separated by |
    # then it has a row-count (N rows)
    # Thus it must have at least 4 rows.
    my @rows    = @{$rows_ref};
    my $caption = '';
    if ($rows[0] !~ /\|/ && $rows[0] =~ /^\s*\w+/)    # possible caption
    {
        $caption = shift @rows;
    }
    my @headings = split(/\s+\|\s+/, shift @rows);
    # skip the ----+--- line
    shift @rows;
    # grab the N rows line
    my $n_rows = pop @rows;

    # now start making the table
    my @tab_lines = ();
    my $tag;
    my $tag2;
    if ($self->{xhtml})
    {
        $tag = $self->get_tag('table', inside_tag => ' border="1" summary=""');
    }
    else
    {
        $tag = $self->get_tag('table', inside_tag => ' border="1"');
    }
    push @tab_lines, "$tag\n";
    if ($caption)
    {
        $caption =~ s/^\s+//;
        $caption =~ s/\s+$//;
        $tag     = $self->get_tag('caption');
        $tag2    = $self->close_tag('caption');
        $caption = join('', $tag, $caption, $tag2, "\n");
        push @tab_lines, $caption;
    }
    # table header
    my $thead = '';
    $tag = $self->get_tag('thead');
    $thead .= $tag;
    $tag = $self->get_tag('tr');
    $thead .= $tag;
    foreach my $col (@headings)
    {
        $col =~ s/^\s+//;
        $col =~ s/\s+$//;
        $tag  = $self->get_tag('th');
        $tag2 = $self->close_tag('th');
        $thead .= join('', $tag, $col, $tag2);
    }
    $tag = $self->close_tag('tr');
    $thead .= $tag;
    $tag = $self->close_tag('thead');
    $thead .= $tag;
    push @tab_lines, "${thead}\n";
    $tag = $self->get_tag('tbody');
    push @tab_lines, "$tag\n";

    # each row
    foreach my $row (@rows)
    {
        my $this_row = '';
        $tag = $self->get_tag('tr');
        $this_row .= $tag;
        my @cols = split(/\|/, $row);
        foreach my $cell (@cols)
        {
            $cell =~ s/^\s+//;
            $cell =~ s/\s+$//;
            if ($self->{escape_HTML_chars})
            {
                $cell = escape($cell);
            }
            if (!$cell)
            {
                $cell = '&nbsp;';
            }
            $tag  = $self->get_tag('td');
            $tag2 = $self->close_tag('td');
            $this_row .= join('', $tag, $cell, $tag2);
        }
        $tag = $self->close_tag('tr');
        $this_row .= $tag;
        push @tab_lines, "${this_row}\n";
    }

    # end the table
    $tag = $self->close_tag('tbody');
    push @tab_lines, "$tag\n";
    $tag = $self->get_tag('table', tag_type => TAG_END);
    push @tab_lines, "$tag\n";

    # and add the N rows line
    $tag = $self->get_tag('p');
    push @tab_lines, "${tag}${n_rows}\n";
    if ($self->{xhtml})
    {
        $tag = $self->get_tag('p', tag_type => TAG_END);
        $tab_lines[$#tab_lines] =~ s/\n/${tag}\n/;
    }

    # replace the rows
    @{$rows_ref} = @tab_lines;
}    # make_pgsql_table

=head2 make_border_table

    $self->make_border_table(rows_ref=>$rows_ref,
			     para_len=>0);

Make a BORDER table.

=cut
sub make_border_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # a BORDER table can start with an optional table-caption,
    # then it has a row of +------+-----+
    # then it has a row of column headings separated by |
    # then it has a row of +------+-----+
    # then it has one or more rows of column values separated by |
    # then it has a row of +------+-----+
    my @rows    = @{$rows_ref};
    my $caption = '';
    if ($rows[0] !~ /\|/ && $rows[0] =~ /^\s*\w+/)    # possible caption
    {
        $caption = shift @rows;
    }
    # skip the +----+---+ line
    shift @rows;
    # get the head row and cut off the start and end |
    my $head_row = shift @rows;
    $head_row =~ s/^\s*\|//;
    $head_row =~ s/\|$//;
    my @headings = split(/\s+\|\s+/, $head_row);
    # skip the +----+---+ line
    shift @rows;
    # skip the last +----+---+ line
    pop @rows;

    # now start making the table
    my @tab_lines = ();
    my $tag;
    if ($self->{xhtml})
    {
        $tag = $self->get_tag('table', inside_tag => ' border="1" summary=""');
    }
    else
    {
        $tag = $self->get_tag('table', inside_tag => ' border="1"');
    }
    push @tab_lines, "$tag\n";
    if ($caption)
    {
        $caption =~ s/^\s+//;
        $caption =~ s/\s+$//;
        $tag     = $self->get_tag('caption');
        $caption = $tag . $caption;
        $tag     = $self->close_tag('caption');
        $caption .= $tag;
        push @tab_lines, "$caption\n";
    }
    # table header
    my $thead = '';
    $tag = $self->get_tag('thead');
    $thead .= $tag;
    $tag = $self->get_tag('tr');
    $thead .= $tag;
    foreach my $col (@headings)
    {
        $col =~ s/^\s+//;
        $col =~ s/\s+$//;
        $tag = $self->get_tag('th');
        $thead .= $tag;
        $thead .= $col;
        $tag = $self->close_tag('th');
        $thead .= $tag;
    }
    $tag = $self->close_tag('tr');
    $thead .= $tag;
    $tag = $self->close_tag('thead');
    $thead .= $tag;
    push @tab_lines, "${thead}\n";
    $tag = $self->get_tag('tbody');
    push @tab_lines, "$tag\n";

    # each row
    foreach my $row (@rows)
    {
        # cut off the start and end |
        $row =~ s/^\s*\|//;
        $row =~ s/\|$//;
        my $this_row = '';
        $tag = $self->get_tag('tr');
        $this_row .= $tag;
        my @cols = split(/\|/, $row);
        foreach my $cell (@cols)
        {
            $cell =~ s/^\s+//;
            $cell =~ s/\s+$//;
            if ($self->{escape_HTML_chars})
            {
                $cell = escape($cell);
            }
            if (!$cell)
            {
                $cell = '&nbsp;';
            }
            $tag = $self->get_tag('td');
            $this_row .= $tag;
            $this_row .= $cell;
            $tag = $self->close_tag('td');
            $this_row .= $tag;
        }
        $tag = $self->close_tag('tr');
        $this_row .= $tag;
        push @tab_lines, "${this_row}\n";
    }

    # end the table
    $tag = $self->close_tag('tbody');
    push @tab_lines, "$tag\n";
    $tag = $self->get_tag('table', tag_type => TAG_END);
    push @tab_lines, "$tag\n";

    # replace the rows
    @{$rows_ref} = @tab_lines;
}    # make_border_table

=head2 make_delim_table

    $self->make_delim_table(rows_ref=>$rows_ref,
			    para_len=>0);

Make a Delimited table.

=cut
sub make_delim_table ($%)
{
    my $self = shift;
    my %args = (
        rows_ref => undef,
        para_len => 0,
        @_
    );
    my $rows_ref = $args{rows_ref};
    my $para_len = $args{para_len};

    # a DELIM table can start with an optional table-caption,
    # then it has at least two rows which start and end and are
    # punctuated by a non-alphanumeric delimiter.
    # A DELIM table has no table-header.
    my @rows    = @{$rows_ref};
    my $caption = '';
    if ($rows[0] !~ /\|/ && $rows[0] =~ /^\s*\w+/)    # possible caption
    {
        $caption = shift @rows;
    }
    # figure out the delimiter
    my $delim = '';
    if ($rows[0] =~ /^\s*([^[:alnum:]])/)
    {
        $delim = $1;
    }
    else
    {
        return 0;
    }

    # now start making the table
    my @tab_lines = ();
    my $tag;
    if ($self->{xhtml})
    {
        $tag = $self->get_tag('table', inside_tag => ' border="1" summary=""');
    }
    else
    {
        $tag = $self->get_tag('table', inside_tag => ' border="1"');
    }
    push @tab_lines, "$tag\n";
    if ($caption)
    {
        $caption =~ s/^\s+//;
        $caption =~ s/\s+$//;
        $tag     = $self->get_tag('caption');
        $caption = $tag . $caption;
        $tag     = $self->close_tag('caption');
        $caption .= $tag;
        push @tab_lines, "$caption\n";
    }

    # each row
    foreach my $row (@rows)
    {
        # cut off the start and end delimiter
        $row =~ s/^\s*[${delim}]//;
        $row =~ s/[${delim}]$//;
        my $this_row = '';
        $tag = $self->get_tag('tr');
        $this_row .= $tag;
        my @cols = split(/[${delim}]/, $row);
        foreach my $cell (@cols)
        {
            $cell =~ s/^\s+//;
            $cell =~ s/\s+$//;
            if ($self->{escape_HTML_chars})
            {
                $cell = escape($cell);
            }
            if (!$cell)
            {
                $cell = '&nbsp;';
            }
            $tag = $self->get_tag('td');
            $this_row .= $tag;
            $this_row .= $cell;
            $tag = $self->close_tag('td');
            $this_row .= $tag;
        }
        $tag = $self->close_tag('tr');
        $this_row .= $tag;
        push @tab_lines, "${this_row}\n";
    }

    # end the table
    $tag = $self->get_tag('table', tag_type => TAG_END);
    push @tab_lines, "$tag\n";

    # replace the rows
    @{$rows_ref} = @tab_lines;
}    # make_delim_table

=head2 is_preformatted

    if ($self->is_preformatted($line))
    {
	...
    }

Returns true if the passed string is considered to be preformatted.

=cut
sub is_preformatted ($$)
{
    my $self = shift;
    my $line = shift;

    my $pre_white_min = $self->{preformat_whitespace_min};
    my $result        = (
        ($line =~ /\s{$pre_white_min,}\S+/o)    # whitespaces
          || ($line =~ /\.{$pre_white_min,}\S+/o)
    );                                          # dots
    return $result;
}

=head2 split_end_explicit_preformat

    $front = $self->split_end_explicit_preformat(para_ref=>$para_ref);

Modifies the given string, and returns the front preformatted part.

=cut
sub split_end_explicit_preformat ($%)
{
    my $self = shift;
    my %args = (
        para_ref => undef,
        @_
    );
    my $para_ref = $args{para_ref};

    my $tag      = '';
    my $pre_str  = '';
    my $post_str = '';
    if ($self->{__mode} & $PRE_EXPLICIT)
    {
        my $pe_mark = $self->{preformat_end_marker};
        if (${para_ref} =~ /$pe_mark/io)
        {
            ($pre_str, $post_str) = split(/$pe_mark/, ${$para_ref}, 2);
            if ($self->{escape_HTML_chars})
            {
                $pre_str = escape($pre_str);
            }
            $tag = $self->close_tag('pre');
            $pre_str .= "${tag}\n";
            $self->{__mode} ^= (($PRE | $PRE_EXPLICIT) & $self->{__mode});
        }
        else    # no end -- the whole thing is preformatted
        {
            $pre_str = ${$para_ref};
            if ($self->{escape_HTML_chars})
            {
                $pre_str = escape($pre_str);
            }
            ${$para_ref} = '';
        }
    }
    return $pre_str;
}    # split_end_explicit_preformat

=head2 endpreformat

    $self->endpreformat(para_lines_ref=>$para_lines_ref,
			para_action_ref=>$para_action_ref,
			ind=>0,
			prev_ref=>$prev_ref);

End a preformatted section.

=cut
sub endpreformat ($%)
{
    my $self = shift;
    my %args = (
        para_lines_ref  => undef,
        para_action_ref => undef,
        ind             => 0,
        prev_ref        => undef,
        @_
    );
    my $para_lines_ref  = $args{para_lines_ref};
    my $para_action_ref = $args{para_action_ref};
    my $ind             = $args{ind};
    my $prev_ref        = $args{prev_ref};

    my $tag = '';
    if ($self->{__mode} & $PRE_EXPLICIT)
    {
        my $pe_mark = $self->{preformat_end_marker};
        if ($para_lines_ref->[$ind] =~ /$pe_mark/io)
        {
            if ($ind == 0)
            {
                $tag = $self->close_tag('pre');
                $para_lines_ref->[$ind] = "${tag}\n";
            }
            else
            {
                $tag = $self->close_tag('pre');
                $para_lines_ref->[$ind - 1] .= "${tag}\n";
                $para_lines_ref->[$ind] = "";
            }
            $self->{__mode} ^= (($PRE | $PRE_EXPLICIT) & $self->{__mode});
            $para_action_ref->[$ind] |= $END;
        }
        return;
    }

    if (
        !$self->is_preformatted($para_lines_ref->[$ind])
        && (
            $self->{endpreformat_trigger_lines} == 1
            || ($ind + 1 < @{$para_lines_ref}
                && !$self->is_preformatted($para_lines_ref->[$ind + 1]))
            || $ind + 1 >= @{$para_lines_ref}    # last line of para
        )
      )
    {
        if ($ind == 0)
        {
            $tag = $self->close_tag('pre');
            ${$prev_ref} = "${tag}\n";
        }
        else
        {
            $tag = $self->close_tag('pre');
            $para_lines_ref->[$ind - 1] .= "${tag}\n";
        }
        $self->{__mode} ^= ($PRE & $self->{__mode});
        $para_action_ref->[$ind] |= $END;
    }
}    # endpreformat

=head2 preformat

    $self->preformat(mode_ref=>$mode_ref,
		     line_ref=>$line_ref,
		     line_action_ref=>$line_action_ref,
		     prev_ref=>$prev_ref,
		     next_ref=>$next_ref,
		     prev_action_ref);

Detect and process a preformatted section.

=cut
sub preformat ($%)
{
    my $self = shift;
    my %args = (
        mode_ref        => undef,
        line_ref        => undef,
        line_action_ref => undef,
        prev_ref        => undef,
        next_ref        => undef,
        prev_action_ref => undef,
        @_
    );
    my $mode_ref        = $args{mode_ref};
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};
    my $prev_ref        = $args{prev_ref};
    my $next_ref        = $args{next_ref};
    my $prev_action_ref = $args{prev_action_ref};

    my $tag = '';
    if ($self->{use_preformat_marker})
    {
        my $pstart = $self->{preformat_start_marker};
        if (${$line_ref} =~ /$pstart/io)
        {
            if (${$prev_ref} =~ s/<p>$//)
            {
                pop @{$self->{__tags}};
            }
            $tag =
              $self->get_tag('pre', inside_tag => " class='quote_explicit'");
            ${$line_ref} = "${tag}\n";
            ${$mode_ref}        |= $PRE | $PRE_EXPLICIT;
            ${$line_action_ref} |= $PRE;
            return;
        }
    }

    if (
           !(${$line_action_ref} & $MAILQUOTE)
        && !(${$prev_action_ref} & $MAILQUOTE)
        && (
            $self->{preformat_trigger_lines} == 0
            || (
                $self->is_preformatted(${$line_ref})
                && (
                    $self->{preformat_trigger_lines} == 1
                    || (defined $next_ref
                        && $self->is_preformatted(${$next_ref}))
                )
            )
        )
      )
    {
        if (${$prev_ref} =~ s/<p>$//)
        {
            pop @{$self->{__tags}};
        }
        $tag = $self->get_tag('pre');
        ${$line_ref} =~ s/^/${tag}\n/;
        ${$mode_ref}        |= $PRE;
        ${$line_action_ref} |= $PRE;
    }
}    # preformat

=head2 make_new_anchor

    $anchor = $self->make_new_anchor($heading_level);

Make a new anchor.

=cut
sub make_new_anchor ($$)
{
    my $self          = shift;
    my $heading_level = shift;

    my ($anchor, $i);

    return sprintf("%d", $self->{__non_header_anchor}++) if (!$heading_level);

    $anchor = "section";
    $self->{__heading_count}->[$heading_level - 1]++;

    # Reset lower order counters
    for ($i = @{$self->{__heading_count}}; $i > $heading_level; $i--)
    {
        $self->{__heading_count}->[$i - 1] = 0;
    }

    for ($i = 0; $i < $heading_level; $i++)
    {
        $self->{__heading_count}->[$i] = 1
          if !$self->{__heading_count}->[$i];    # In case they skip any
        $anchor .= sprintf("_%d", $self->{__heading_count}->[$i]);
    }
    chomp($anchor);
    $anchor;
}    # make_new_anchor

=head2 anchor_mail

    $self->anchor_mail($line_ref);

Make an anchor for a mail section.

=cut
sub anchor_mail ($$)
{
    my $self     = shift;
    my $line_ref = shift;

    if ($self->{make_anchors})
    {
        my ($anchor) = $self->make_new_anchor(0);
        if ($self->{lower_case_tags})
        {
            ${$line_ref} =~ s/([^ ]*)/<a name="$anchor">$1<\/a>/;
        }
        else
        {
            ${$line_ref} =~ s/([^ ]*)/<A NAME="$anchor">$1<\/A>/;
        }
    }
}    # anchor_mail

=head2 anchor_heading

    $self->anchor_heading($heading_level, $line_ref);

Make an anchor for a heading.

=cut
sub anchor_heading ($$$)
{
    my $self     = shift;
    my $level    = shift;
    my $line_ref = shift;

    if ($DictDebug & 8)
    {
        print STDERR "anchor_heading: ", ${$line_ref}, "\n";
    }
    if ($self->{make_anchors})
    {
        my ($anchor) = $self->make_new_anchor($level);
        if ($self->{lower_case_tags})
        {
            ${$line_ref} =~ s/(<h.>)(.*)(<\/h.>)/$1<a name="$anchor">$2<\/a>$3/;
        }
        else
        {
            ${$line_ref} =~ s/(<H.>)(.*)(<\/H.>)/$1<A NAME="$anchor">$2<\/A>$3/;
        }
    }
    if ($DictDebug & 8)
    {
        print STDERR "anchor_heading(after): ", ${$line_ref}, "\n";
    }
}    # anchor_heading

=head2 heading_level

    $self->heading_level($style);

Add a new heading style if this is a new heading style.

=cut
sub heading_level ($$)
{
    my $self = shift;

    my ($style) = @_;
    $self->{__heading_styles}->{$style} = ++$self->{__num_heading_styles}
      if !$self->{__heading_styles}->{$style};
    $self->{__heading_styles}->{$style};
}    # heading_level

=head2 is_ul_list_line

    if ($self->is_ul_list_line($line))
    {
	...
    }

Tests if this line starts a UL list item.

=cut
sub is_ul_list_line ($%)
{
    my $self = shift;
    my %args = (
        line => undef,
        @_
    );
    my $line = $args{line};

    my ($prefix, $number, $rawprefix, $term) = $self->listprefix($line);
    if ($prefix && !$number)
    {
        return 1;
    }
    return 0;
}

=head2 is_heading

    if ($self->is_heading(line_ref=>$line_ref, next_ref=>$next_ref))
    {
	...
    }

Tests if this line is a heading.  Needs to take account of the
next line, because a standard heading is defined by "underlining"
the text of the heading.

=cut
sub is_heading ($%)
{
    my $self = shift;
    my %args = (
        line_ref => undef,
        next_ref => undef,
        @_
    );
    my $line_ref = $args{line_ref};
    my $next_ref = $args{next_ref};

    if (   ${$line_ref} !~ /^\s*$/
        && !$self->is_ul_list_line(line => ${$line_ref})
        && defined $next_ref
        && ${$next_ref} =~ /^\s*[-=*.~+]+\s*$/)
    {
        my ($hoffset, $heading) = ${$line_ref} =~ /^(\s*)(.+)$/;
        $hoffset = "" unless defined($hoffset);
        $heading = "" unless defined($heading);
        # Unescape chars so we get an accurate length
        $heading =~ s/&[^;]+;/X/g;
        my ($uoffset, $underline) = ${$next_ref} =~ /^(\s*)(\S+)\s*$/;
        $uoffset   = "" unless defined($uoffset);
        $underline = "" unless defined($underline);
        my ($lendiff, $offsetdiff);
        $lendiff = length($heading) - length($underline);
        $lendiff *= -1 if $lendiff < 0;

        $offsetdiff = length($hoffset) - length($uoffset);
        $offsetdiff *= -1 if $offsetdiff < 0;
        if (   ($lendiff <= $self->{underline_length_tolerance})
            || ($offsetdiff <= $self->{underline_offset_tolerance}))
        {
            return 1;
        }
    }

    return 0;

}    # is_heading

=head2 heading
    
    $self->heading(line_ref=>$line_ref,
	next_ref=>$next_ref);

Make a heading.
Assumes is_heading is true.

=cut
sub heading ($%)
{
    my $self = shift;
    my %args = (
        line_ref => undef,
        next_ref => undef,
        @_
    );
    my $line_ref = $args{line_ref};
    my $next_ref = $args{next_ref};

    my ($hoffset, $heading) = ${$line_ref} =~ /^(\s*)(.+)$/;
    $hoffset = "" unless defined($hoffset);
    $heading = "" unless defined($heading);
    $heading =~ s/&[^;]+;/X/g;    # Unescape chars so we get an accurate length
    my ($uoffset, $underline) = ${$next_ref} =~ /^(\s*)(\S+)\s*$/;
    $uoffset   = "" unless defined($uoffset);
    $underline = "" unless defined($underline);

    $underline = substr($underline, 0, 1);

    # Call it a different style if the heading is in all caps.
    $underline .= "C" if $self->iscaps(${$line_ref});
    ${$next_ref} = " ";           # Eat the underline
    $self->{__heading_level} = $self->heading_level($underline);
    if ($self->{escape_HTML_chars})
    {
        ${$line_ref} = escape(${$line_ref});
    }
    $self->tagline("H" . $self->{__heading_level}, $line_ref);
    $self->anchor_heading($self->{__heading_level}, $line_ref);
}    # heading

=head2 is_custom_heading

    if ($self->is_custom_heading($line))
    {
	...
    }

Check if the given line matches a custom heading.

=cut
sub is_custom_heading ($%)
{
    my $self = shift;
    my %args = (
        line => undef,
        @_
    );
    my $line = $args{line};

    foreach my $reg (@{$self->{custom_heading_regexp}})
    {
        return 1 if ($line =~ /$reg/);
    }
    return 0;
}    # is_custom_heading

=head2 custom_heading

    $self->custom_heading(line_ref=>$line_ref);

Make a custom heading.  Assumes is_custom_heading is true.

=cut
sub custom_heading ($%)
{
    my $self = shift;
    my %args = (
        line_ref => undef,
        @_
    );
    my $line_ref = $args{line_ref};

    my $level;
    my $i = 0;
    foreach my $reg (@{$self->{custom_heading_regexp}})
    {
        if (${$line_ref} =~ /$reg/)
        {
            if ($self->{explicit_headings})
            {
                $level = $i + 1;
            }
            else
            {
                $level = $self->heading_level("Cust" . $i);
            }
            if ($self->{escape_HTML_chars})
            {
                ${$line_ref} = escape(${$line_ref});
            }
            $self->tagline("H" . $level, $line_ref);
            $self->anchor_heading($level, $line_ref);
            last;
        }
        $i++;
    }
}    # custom_heading

=head2 unhyphenate_para

    $self->unhyphenate_para($para_ref);

Join up hyphenated words that are split across lines.

=cut
sub unhyphenate_para ($$)
{
    my $self     = shift;
    my $para_ref = shift;

    # Treating this whole paragraph as one string, look for
    # 1 - whitespace
    # 2 - a word (ending in a hyphen, followed by a newline)
    # 3 - whitespace (starting on the next line)
    # 4 - a word with its punctuation
    # Substitute this with
    # 1-whitespace 2-word 4-word newline 3-whitespace
    # We preserve the 3-whitespace because we don't want to mess up
    # our existing indentation.
    ${$para_ref} =~
      /(\s*)([^\W\d_]*)\-\n(\s*)([^\W\d_]+[\)\}\]\.,:;\'\"\>]*\s*)/s;
    ${$para_ref} =~
s/(\s*)([^\W\d_]*)\-\n(\s*)([^\W\d_]+[\)\}\]\.,:;\'\"\>]*\s*)/$1$2$4\n$3/gs;
}    # unhyphenate_para

=head2 tagline

    $self->tagline($tag, $line_ref);

Put the given tag around the given line.

=cut
sub tagline ($$$)
{
    my $self     = shift;
    my $tag      = shift;
    my $line_ref = shift;

    chomp ${$line_ref};    # Drop newline
    my $tag1 = $self->get_tag($tag);
    my $tag2 = $self->close_tag($tag);
    ${$line_ref} =~ s/^\s*(.*)$/${tag1}$1${tag2}\n/;
}    # tagline

=head2 iscaps

    if ($self->iscaps($line))
    {
	...
    }

Check if a line is all capitals.

=cut
sub iscaps
{
    my $self = shift;
    local ($_) = @_;

    my $min_caps_len = $self->{min_caps_length};

    /^[^[:lower:]<]*[[:upper:]]{$min_caps_len,}[^[:lower:]<]*$/;
}    # iscaps

=head2 caps

    $self->caps(line_ref=>$line_ref,
		line_action_ref=>$line_action_ref);

Detect and deal with an all-caps line.

=cut
sub caps
{
    my $self = shift;
    my %args = (
        line_ref        => undef,
        line_action_ref => undef,
        @_
    );
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};

    if (   $self->{caps_tag}
        && $self->iscaps(${$line_ref}))
    {
        $self->tagline($self->{caps_tag}, $line_ref);
        ${$line_action_ref} |= $CAPS;
    }
}    # caps

=head2 do_delim

    $self->do_delim(line_ref=>$line_ref,
		    line_action_ref=>$line_action_ref,
		    delim=>'*',
		    tag=>'STRONG');

Deal with a line which has words delimited by the given delimiter;
this is used to deal with italics, bold and underline formatting.

=cut
sub do_delim
{
    my $self = shift;
    my %args = (
        line_ref        => undef,
        line_action_ref => undef,
        delim           => '*',
        tag             => 'STRONG',
        @_
    );
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};
    my $delim           = $args{delim};
    my $tag             = $args{tag};

    if ($delim eq '#')  
    {
        if (${$line_ref} =~ m/\B#([[:alpha:]])#\B/s)
	{
	    ${$line_ref} =~ s/\B#([[:alpha:]])#\B/<${tag}>$1<\/${tag}>/gs;
	}
	# special treatment of # for the #num case and the #link case
	if (${$line_ref} !~ m/<[aA]/)
	{
	    ${$line_ref} =~
s/#([^\d#](?![^#]*(?:<li>|<LI>|<P>|<p>))[^#]*[^# \t\n])#/<${tag}>$1<\/${tag}>/gs;
	}
	else
	{
	    my $line_with_links = '';
	    my $linkme = '';
	    my $unmatched = ${$line_ref};
	    while ($unmatched =~ 
		   m/#([^\d#](?![^#]*(?:<li>|<LI>|<P>|<p>))[^#]*[^# \t\n])#/s)
	    {
		$line_with_links .= $`;
		$linkme = $&;
		$unmatched = $';
		if (!$self->in_link_context($linkme, $line_with_links))
		{
		    $linkme =~
			s/#([^\d#](?![^#]*(?:<li>|<LI>|<P>|<p>))[^#]*[^# \t\n])#/<${tag}>$1<\/${tag}>/gs;
		}
		$line_with_links .= $linkme;
	    }
	    ${$line_ref} = $line_with_links . $unmatched;
	}
    }
    elsif ($delim eq '^')
    {
        ${$line_ref} =~
s/\^((?![^^]*(?:<li>|<LI>|<p>|<P>))(\w|["'<>])[^^]*)\^/<${tag}>$1<\/${tag}>/gs;
        ${$line_ref} =~ s/\B\^([[:alpha:]])\^\B/<${tag}>$1<\/${tag}>/gs;
    }
    elsif ($delim eq '_')
    {
        if (${$line_ref} =~ m/\B_([[:alpha:]])_\B/s)
	{
	    ${$line_ref} =~ s/\B_([[:alpha:]])_\B/<${tag}>$1<\/${tag}>/gs;
	    ${$line_ref} =~
		s#(?<![_[:alnum:]])_([^_]+?[[:alnum:]"'\.\?\&;:<>])_#<${tag}>$1</${tag}>#gs;
	}
	else
	{
	    # make sure we don't wallop links that have underscores
	    # need to make sure that _ delimiters are not mistaken for
	    # a_variable_name
	    my $line_with_links = '';
	    my $linkme = '';
	    my $unmatched = ${$line_ref};
	    while ($unmatched =~ 
			m#(?<![_[:alnum:]])_([^_]+?[[:alnum:]"'\.\?\&;:<>])_#s)
	    {
		$line_with_links .= $`;
		$linkme = $&;
		$unmatched = $';
		if (!$self->in_link_context($linkme, $line_with_links))
		{
		    $linkme =~
			s#(?<![_[:alnum:]])_([^_]+?[[:alnum:]"'\.\?\&;:<>])_#<${tag}>$1</${tag}>#gs;
		}
		$line_with_links .= $linkme;
	    }
	    ${$line_ref} = $line_with_links . $unmatched;
	}
    }
    elsif (length($delim) eq 1)    # one-character, general
    {
        if (${$line_ref} =~ m/\B[${delim}]([[:alpha:]])[${delim}]\B/s)
	{
	    ${$line_ref} =~ s/\B[${delim}]([[:alpha:]])[${delim}]\B/<${tag}>$1<\/${tag}>/gs;
	}
        ${$line_ref} =~
	    s#(?<![${delim}])[${delim}]([^${delim}]+?[[:alnum:][:punct:]\&<>])[${delim}]#<${tag}>$1</${tag}>#gs;
    }
    else
    {
        ${$line_ref} =~
s/(?<!${delim})${delim}((\w|["'])(\w|[-\s[:punct:]])*[^\s])${delim}/<${tag}>$1<\/${tag}>/gs;
        ${$line_ref} =~ s/${delim}]([[:alpha:]])${delim}/<${tag}>$1<\/${tag}>/gs;
    }
}    # do_delim

=head2 glob2regexp

    $regexp = glob2regexp($glob);

Convert very simple globs to regexps

=cut
sub glob2regexp
{
    my ($glob) = @_;

    # Escape funky chars
    $glob =~ s/[^\w\[\]\*\?\|\\]/\\$&/g;
    my ($regexp, $i, $len, $escaped) = ("", 0, length($glob), 0);

    for (; $i < $len; $i++)
    {
        my $char = substr($glob, $i, 1);
        if ($escaped)
        {
            $escaped = 0;
            $regexp .= $char;
            next;
        }
        if ($char eq "\\")
        {
            $escaped = 1;
            next;
            $regexp .= $char;
        }
        if ($char eq "?")
        {
            $regexp .= ".";
            next;
        }
        if ($char eq "*")
        {
            $regexp .= ".*";
            next;
        }
        $regexp .= $char;    # Normal character
    }
    join('', "\\b", $regexp, "\\b");
}    # glob2regexp

=head2 add_regexp_to_links_table

    $self->add_regexp_to_links_table(label=>$label,
				     pattern=>$pattern,
				     url=>$url,
				     switches=>$switches);

Add the given regexp "link definition" to the links table.

=cut
sub add_regexp_to_links_table ($%)
{
    my $self = shift;
    my %args = (
        label => undef,
        pattern => undef,
        url => undef,
        switches => undef,
        @_
    );
    my $label = $args{label};
    my $pattern = $args{pattern};
    my $URL = $args{url};
    my $switches = $args{switches};

    # No sense adding a second one if it's already in there.
    # It would never get used.
    if (!$self->{__links_table}->{$label})
    {

        # Keep track of the order they were added so we can
        # look for matches in the same order
        push(@{$self->{__links_table_order}}, ($label));

	$self->{__links_table_patterns}->{$label} = $pattern;
        $self->{__links_table}->{$label}        = $URL;      # Put it in The Table
        $self->{__links_switch_table}->{$label} = $switches;
        my $ind = @{$self->{__links_table_order}} - 1;
        print STDERR " (", $ind,
          ")\tLABEL: $label \tPATTERN: $pattern\n\tVALUE: $URL\n\tSWITCHES: $switches\n\n"
          if ($DictDebug & 1);
    }
    else
    {
        if ($DictDebug & 1)
        {
            print STDERR " Skipping entry.  Key already in table.\n";
            print STDERR "\tLABEL: $label \tPATTERN: $pattern\n\tVALUE: $URL\n\n";
        }
    }
}    # add_regexp_to_links_table

=head2 add_literal_to_links_table

    $self->add_literal_to_links_table(label=>$label,
				      pattern=>$pattern,
				      url=>$url,
				      switches=>$switches);

Add the given literal "link definition" to the links table.

=cut
sub add_literal_to_links_table ($%)
{
    my $self = shift;
    my %args = (
        label => undef,
        pattern => undef,
        url => undef,
        switches => undef,
        @_
    );
    my $label = $args{label};
    my $pattern = $args{pattern};
    my $URL = $args{url};
    my $switches = $args{switches};

    $pattern =~ s/(\W)/\\$1/g;    # Escape non-alphanumeric chars
    $pattern = "\\b$pattern\\b";      # Make a regexp out of it
    $self->add_regexp_to_links_table(label=>$label, pattern=>$pattern, url=>$URL, switches=>$switches);
}    # add_literal_to_links_table

=head2 add_glob_to_links_table

    $self->add_glob_to_links_table(label=>$label,
				   pattern=>$pattern,
				   url=>$url,
				   switches=>$switches);

Add the given glob "link definition" to the links table.

=cut
sub add_glob_to_links_table ($%)
{
    my $self = shift;
    my %args = (
        label => undef,
        pattern => undef,
        url => undef,
        switches => undef,
        @_
    );
    my $label = $args{label};
    my $pattern = $args{pattern};
    my $URL = $args{url};
    my $switches = $args{switches};

    $self->add_regexp_to_links_table(pattern=>glob2regexp($pattern),
	label=>$label,
	url=>$URL, switches=>$switches);
}    # add_glob_to_links_table

=head2 parse_dict
    
    $self->parse_dict($dictfile, $dict);

Parse the dictionary file.
(see also load_dictionary_links, for things that were stripped)

=cut
sub parse_dict ($$$)
{
    my $self = shift;

    my ($dictfile, $dict) = @_;

    print STDERR "Parsing dictionary file $dictfile\n"
      if ($DictDebug & 1);

    if ($dict =~ /->\s*->/)
    {
        my $message = "Two consecutive '->'s found in $dictfile\n";
        my $near;

        # Print out any useful context so they can find it.
        ($near) = $dict =~ /([\S ]*\s*->\s*->\s*\S*)/;
        $message .= "\n$near\n" if $near =~ /\S/;
        die $message;
    }

    my ($key, $URL, $switches, $options);
    while ($dict =~ /\s*(.+)\s+\-+([iehos]+\-+)?\>\s*(.*\S+)\s*\n/ig)
    {
        $key      = $1;
        $options  = $2;
        $options  = "" unless defined($options);
        $URL      = $3;
        $switches = 0;
        # Case insensitivity
        $switches += $LINK_NOCASE if $options =~ /i/i;
        # Evaluate as Perl code
        $switches += $LINK_EVAL if $options =~ /e/i;
        # provides HTML, not just URL
        $switches += $LINK_HTML if $options =~ /h/i;
        # Only do this link once
        $switches += $LINK_ONCE if $options =~ /o/i;
        # Only do this link once per section
        $switches += $LINK_SECT_ONCE if $options =~ /s/i;

        $key =~ s/\s*$//;    # Chop trailing whitespace

        if ($key =~ m|^/|)   # Regexp
        {
            $key = substr($key, 1);
            $key =~ s|/$||;    # Allow them to forget the closing /
            $self->add_regexp_to_links_table(pattern=>$key, label=>$key, url=>$URL, switches=>$switches);
        }
        elsif ($key =~ /^\|/)    # alternate regexp format
        {
            $key = substr($key, 1);
            $key =~ s/\|$//;      # Allow them to forget the closing |
            $key =~ s|/|\\/|g;    # Escape all slashes
            $self->add_regexp_to_links_table(pattern=>$key, label=>$key, url=>$URL, switches=>$switches);
        }
        elsif ($key =~ /\"/)
        {
            $key = substr($key, 1);
            $key =~ s/\"$//;      # Allow them to forget the closing "
            $self->add_literal_to_links_table(pattern=>$key, label=>$key, url=>$URL, switches=>$switches);
        }
        else
        {
            $self->add_glob_to_links_table(pattern=>$key, label=>$key, url=>$URL, switches=>$switches);
        }
    }

}    # parse_dict

=head2 setup_dict_checking

    $self->setup_dict_checking();

Set up the dictionary checking.

=cut
sub setup_dict_checking ($)
{
    my $self = shift;

    # now create the replace funcs and precomile the regexes
    my ($URL, $switches, $pattern, $options, $tag1, $tag2);
    my ($href, $r_sw);
    my @subs;
    my $i = 0;
    foreach my $label (@{$self->{__links_table_order}})
    {
        $switches = $self->{__links_switch_table}->{$label};
        $pattern = $self->{__links_table_patterns}->{$label};

        $href = $self->{__links_table}->{$label};

        if (!($switches & $LINK_HTML))
        {
            $href =~ s#/#\\/#g;
            $href = (
                $self->{lower_case_tags}
                ? join('', '<a href="', $href, '">$&<\\/a>')
                : join('', '<A HREF="', $href, '">$&<\\/A>')
            );
        }
        else
        {
            # change the uppercase tags to lower case
            if ($self->{lower_case_tags})
            {
                $href =~ s#(</)([A-Z]*)(>)#${1}\L${2}${3}#g;
                $href =~ s/(<)([A-Z]*)(>)/${1}\L${2}${3}/g;
                # and the anchors
                $href =~ s/(<)(A\s*HREF)([^>]*>)/$1\L$2$3/g;
            }
            $href =~ s#/#\\/#g;
        }

        $r_sw = "s";    # Options for replacing
        $r_sw .= "i" if ($switches & $LINK_NOCASE);
        $r_sw .= "e" if ($switches & $LINK_EVAL);

        # Generate code for replacements.
        # Create an anonymous subroutine for each replacement,
        # and store its reference in an array.
        # We need to do an "eval" to create these because we need to
        # be able to treat the *contents* of the $href variable
        # as if it were perl code, because sometimes the $href
        # contains things which need to be evaluated, such as $& or $1,
        # not just those cases where we have a "e" switch.
        my $code = <<EOT;
\$self->{__repl_code}->[$i] =
sub {
my \$al = shift;
\$al =~ s/$pattern/$href/$r_sw;
return \$al;
};
EOT
        print STDERR $code if ($DictDebug & 2);
        push @subs, $code;

        # compile searching pattern
        if ($switches & $LINK_NOCASE)    # i
        {
            $self->{__search_patterns}->[$i] = qr/$pattern/si;
        }
        else
        {
            $self->{__search_patterns}->[$i] = qr/$pattern/s;
        }
        $i++;
    }
    # now eval the replacements code string
    my $codes = join('', @subs);
    eval "$codes";
}    # setup_dict_checking

=head2 in_link_context

    if ($self->in_link_context($match, $before))
    {
	...
    }

Check if we are inside a link (<a ...>); certain kinds of substitution are
not allowed here.

=cut
sub in_link_context ($$$)
{
    my $self = shift;
    my ($match, $before) = @_;
    return 1 if $match =~ m@</?A>@i;    # No links allowed inside match

    my ($final_open, $final_close);
    if ($self->{lower_case_tags})
    {
        $final_open  = rindex($before, "<a ") - $[;
        $final_close = rindex($before, "</a>") - $[;
    }
    else
    {
        $final_open  = rindex($before, "<A ") - $[;
        $final_close = rindex($before, "</A>") - $[;
    }

    return 1 if ($final_open >= 0)    # Link opened
      && (
        ($final_close < 0)            # and not closed    or
        || ($final_open > $final_close)
      );                              # one opened after last close

    # Now check to see if we're inside a tag, matching a tag name,
    # or attribute name or value
    $final_open  = rindex($before, "<") - $[;
    $final_close = rindex($before, ">") - $[;
    ($final_open >= 0)                # Tag opened
      && (
        ($final_close < 0)            # and not closed    or
        || ($final_open > $final_close)
      );                              # one opened after last close
}    # in_link_context

=head2 apply_links

    $self->apply_links(para_ref=>$para_ref,
		       para_action_ref=>$para_action_ref);

Apply links and formatting to this paragraph.

=cut
sub apply_links ($%)
{
    my $self = shift;
    my %args = (
        para_ref        => undef,
        para_action_ref => undef,
        @_
    );
    my $para_ref        = $args{para_ref};
    my $para_action_ref = $args{para_action_ref};

    if ($self->{make_links}
        && @{$self->{__links_table_order}})
    {
        $self->check_dictionary_links(
            line_ref        => $para_ref,
            line_action_ref => $para_action_ref
        );
    }
    if ($self->{bold_delimiter})
    {
        my $tag = ($self->{lower_case_tags} ? 'strong' : 'STRONG');
        $self->do_delim(
            line_ref        => $para_ref,
            line_action_ref => $para_action_ref,
            delim           => $self->{bold_delimiter},
            tag             => $tag
        );
    }
    if ($self->{italic_delimiter})
    {
        my $tag = ($self->{lower_case_tags} ? 'em' : 'EM');
        $self->do_delim(
            line_ref        => $para_ref,
            line_action_ref => $para_action_ref,
            delim           => $self->{italic_delimiter},
            tag             => $tag
        );
    }
    if ($self->{underline_delimiter})
    {
        my $tag = ($self->{lower_case_tags} ? 'u' : 'U');
        $self->do_delim(
            line_ref        => $para_ref,
            line_action_ref => $para_action_ref,
            delim           => $self->{underline_delimiter},
            tag             => $tag
        );
    }

}    # apply_links

=head2 check_dictionary_links

    $self->check_dictionary_links(line_ref=>$line_ref,
				  line_action_ref=>$line_action_ref);

Check (and alter if need be) the bits in this line matching
the patterns in the link dictionary.

=cut
sub check_dictionary_links ($%)
{
    my $self = shift;
    my %args = (
        line_ref        => undef,
        line_action_ref => undef,
        @_
    );
    my $line_ref        = $args{line_ref};
    my $line_action_ref = $args{line_action_ref};

    my ($switches, $pattern, $options, $repl_func);
    my ($linkme, $line_with_links);

    # for each pattern, check and alter the line
    my $i = 0;
    foreach my $label (@{$self->{__links_table_order}})
    {
        $switches = $self->{__links_switch_table}->{$label};
        $pattern = $self->{__links_table_patterns}->{$label};

        # check the pattern
        if ($switches & $LINK_ONCE)    # Do link only once
        {
            $line_with_links = '';
            if (!$self->{__done_with_link}->[$i]
                && ${$line_ref} =~ $self->{__search_patterns}->[$i])
            {
                $self->{__done_with_link}->[$i] = 1;
                $line_with_links .= $`;
                $linkme = $&;

                ${$line_ref} = $';
                if (!$self->in_link_context($linkme, $line_with_links))
                {
                    print STDERR "Link rule $i matches $linkme\n"
                      if ($DictDebug & 4);

                    # call the special subroutine already created to do
                    # this replacement
                    $repl_func = $self->{__repl_code}->[$i];
                    $linkme    = &$repl_func($linkme);
                }
                $line_with_links .= $linkme;
            }
            ${$line_ref} = $line_with_links . ${$line_ref};
        }
        elsif ($switches & $LINK_SECT_ONCE)    # Do link only once per section
        {
            $line_with_links = '';
            if (!$self->{__done_with_sect_link}->[$i]
                && ${$line_ref} =~ $self->{__search_patterns}->[$i])
            {
                $self->{__done_with_sect_link}->[$i] = 1;
                $line_with_links .= $`;
                $linkme = $&;

                ${$line_ref} = $';
                if (!$self->in_link_context($linkme, $line_with_links))
                {
                    print STDERR "Link rule $i matches $linkme\n"
                      if ($DictDebug & 4);

                    # call the special subroutine already created to do
                    # this replacement
                    $repl_func = $self->{__repl_code}->[$i];
                    $linkme    = &$repl_func($linkme);
                }
                $line_with_links .= $linkme;
            }
            ${$line_ref} = $line_with_links . ${$line_ref};
        }
        else
        {
            $line_with_links = '';
            while (${$line_ref} =~ $self->{__search_patterns}->[$i])
            {
                $line_with_links .= $`;
                $linkme = $&;

                ${$line_ref} = $';
                if (!$self->in_link_context($linkme, $line_with_links))
                {
                    print STDERR "Link rule $i matches $linkme\n"
                      if ($DictDebug & 4);

                    # call the special subroutine already created to do
                    # this replacement
                    $repl_func = $self->{__repl_code}->[$i];
                    $linkme    = &$repl_func($linkme);
                }
                $line_with_links .= $linkme;
            }
            ${$line_ref} = $line_with_links . ${$line_ref};
        }
        $i++;
    }
    ${$line_action_ref} |= $LINK;
}    # check_dictionary_links

=head2 load_dictionary_links

    $self->load_dictionary_links();

Load the dictionary links.

=cut
sub load_dictionary_links ($)
{
    my $self = shift;

    @{$self->{__links_table_order}} = ();
    %{$self->{__links_table}}       = ();

    my $dict;
    foreach $dict (@{$self->{links_dictionaries}})
    {
        next unless $dict;
        open(DICT, "$dict") || die "Can't open Dictionary file $dict\n";

        my @lines = ();
        while (<DICT>)
        {
            # skip lines that start with '#'
            next if /^\#/;
            # skip lines that end with unescaped ':'
            next if /^.*[^\\]:\s*$/;
            push @lines, $_;
        }
        close(DICT);
        my $contents = join('', @lines);
        $self->parse_dict($dict, $contents);
    }
    # last of all, do the system dictionary, already read in from DATA
    if ($self->{__global_links_data})
    {
        $self->parse_dict("DATA", $self->{__global_links_data});
    }

    $self->setup_dict_checking();
}    # load_dictionary_links

=head2 do_file_start

    $self->do_file_start($outhandle, $para);

Extra stuff needed for the beginning:
HTML headers, and prepending a file if desired.

=cut
sub do_file_start ($$$)
{
    my $self      = shift;
    my $outhandle = shift;
    my $para      = shift;

    if (!$self->{extract})
    {
        my @para_lines = split(/\n/, $para);
        my $first_line = $para_lines[0];

        if ($self->{doctype})
        {
            if ($self->{xhtml})
            {
                print $outhandle
'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"',
                  "\n";
                print $outhandle
		  '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
                  "\n";
		print $outhandle $self->get_tag('html',
		    inside_tag => ' xmlns="http://www.w3.org/1999/xhtml"'), "\n";
            }
            else
            {
                print $outhandle '<!DOCTYPE HTML PUBLIC "', $self->{doctype},
                  "\">\n";
		print $outhandle $self->get_tag('html'), "\n";
            }
        }
        print $outhandle $self->get_tag('head'), "\n";

        # if --titlefirst is set and --title isn't, use the first line
        # as the title.
        if ($self->{titlefirst} && !$self->{title})
        {
            my ($tit) = $first_line =~ /^ *(.*)/;    # grab first line
            $tit =~ s/ *$//;                         # strip trailing whitespace
            $tit = escape($tit) if $self->{escape_HTML_chars};
            $self->{'title'} = $tit;
        }
        if (!$self->{title})
        {
            $self->{'title'} = "";
        }
        print $outhandle $self->get_tag('title'), $self->{title},
          $self->close_tag('title'), "\n";

        if ($self->{append_head})
        {
            open(APPEND, $self->{append_head})
              || die "Failed to open ", $self->{append_head}, "\n";
            while (<APPEND>)
            {
                print $outhandle $_;
            }
            close(APPEND);
        }

        if ($self->{lower_case_tags})
        {
            print $outhandle $self->get_tag(
                'meta',
                tag_type   => TAG_EMPTY,
                inside_tag => " name=\"generator\" content=\"$PROG v$VERSION\""
              ),
              "\n";
        }
        else
        {
            print $outhandle $self->get_tag(
                'meta',
                tag_type   => TAG_EMPTY,
                inside_tag => " NAME=\"generator\" CONTENT=\"$PROG v$VERSION\""
              ),
              "\n";
        }
        if ($self->{style_url})
        {
            my $style_url = $self->{style_url};
            if ($self->{lower_case_tags})
            {
                print $outhandle $self->get_tag(
                    'link',
                    tag_type   => TAG_EMPTY,
                    inside_tag =>
" rel=\"stylesheet\" type=\"text/css\" href=\"$style_url\""
                  ),
                  "\n";
            }
            else
            {
                print $outhandle $self->get_tag(
                    'link',
                    tag_type   => TAG_EMPTY,
                    inside_tag =>
" REL=\"stylesheet\" TYPE=\"text/css\" HREF=\"$style_url\""
                  ),
                  "\n";
            }
        }
        print $outhandle $self->close_tag('head'), "\n";
        if ($self->{body_deco})
        {
            print $outhandle $self->get_tag('body',
                inside_tag => $self->{body_deco}), "\n";
        }
        else
        {
            print $outhandle $self->get_tag('body'), "\n";
        }
    }

    if ($self->{prepend_file})
    {
        if (-r $self->{prepend_file})
        {
            open(PREPEND, $self->{prepend_file});
            while (<PREPEND>)
            {
                print $outhandle $_;
            }
            close(PREPEND);
        }
        else
        {
            print STDERR "Can't find or read file ", $self->{prepend_file},
              " to prepend.\n";
        }
    }
}    # do_file_start

=head2 do_init_call

    $self->do_init_call();

Certain things, like reading link dictionaries, need to be done only
once.

=cut
sub do_init_call ($)
{
    my $self = shift;

    if (!$self->{__call_init_done})
    {
        push(@{$self->{links_dictionaries}}, ($self->{default_link_dict}))
          if ($self->{make_links} && (-f $self->{default_link_dict}));
	if ($self->{links_dictionaries})
	{
	    # only put into the links dictionaries files which are readable
	    my @dict_files = @{$self->{links_dictionaries}};
	    $self->args(links_dictionaries => []);

	    foreach my $ld (@dict_files)
	    {
		if (-r $ld)
		{
		    $self->{'make_links'} = 1;
		    $self->args(['--links_dictionaries', $ld]);
		}
		else
		{
		    print STDERR "Can't find or read link-file $ld\n";
		}
	    }
	}
        if ($self->{make_links})
        {
            $self->load_dictionary_links();
        }

        # various initializations
        $self->{__non_header_anchor} = 0;
        $self->{__mode}              = 0;
        $self->{__listnum}           = 0;
        $self->{__list_nice_indent}  = '';
        $self->{__list_indent}       = [];
        $self->{__tags}              = [];

        $self->{__call_init_done} = 1;
    }
}    # do_init_call

=head1 FILE FORMATS

There are two files which are used which can affect the outcome of the
conversion.  One is the link dictionary, which contains patterns (of how
to recognise http links and other things) and how to convert them. The
other is, naturally, the format of the input file itself.

=head2 Link Dictionary

A link dictionary file contains patterns to match, and what to convert
them to.  It is called a "link" dictionary because it was intended to be
something which defined what a href link was, but it can be used for
more than that.  However, if you wish to define your own links, it is
strongly advised to read up on regular expressions (regexes) because
this relies heavily on them.

The file consists of comments (which are lines starting with #)
and blank lines, and link entries.
Each entry consists of a regular expression, a -> separator (with
optional flags), and a link "result".

In the simplest case, with no flags, the regular expression
defines the pattern to look for, and the result says what part
of the regular expression is the actual link, and the link which
is generated has the href as the link, and the whole matched pattern
as the visible part of the link.  The first character of the regular
expression is taken to be the separator for the regex, so one
could either use the traditional / separator, or something else
such as | (which can be helpful with URLs which are full of / characters).

So, for example, an ftp URL might be defined as:

    |ftp:[\w/\.:+\-]+|      -> $&

This takes the whole pattern as the href, and the resultant link
has the same thing in the href as in the contents of the anchor.

But sometimes the href isn't the whole pattern.

    /&lt;URL:\s*(\S+?)\s*&gt;/ --> $1

With the above regex, a () grouping marks the first subexpression,
which is represented as $1 (rather than $& the whole expression).
This entry matches a URL which was marked explicity as a URL
with the pattern <URL:foo>  (note the &lt; is shown as the
entity, not the actual character.  This is because by the
time the links dictionary is checked, all such things have
already been converted to their HTML entity forms, unless, of course,
the escape_HTML_chars option was turned off)
This would give us a link in the form
<A HREF="foo">&lt;URL:foo&gt;</A>

B<The h flag>

However, if we want more control over the way the link is constructed,
we can construct it ourself.  If one gives the h flag, then the
"result" part of the entry is taken not to contain the href part of
the link, but the whole link.

For example, the entry:

    /&lt;URL:\s*(\S+?)\s*&gt;/ -h-> <A HREF="$1">$1</A>

will take <URL:foo> and give us <A HREF="foo">foo</A>

However, this is a very powerful mechanism, because it
can be used to construct custom tags which aren't links at all.
For example, to flag *italicised words* the following
entry will surround the words with EM tags.

    /\B\*([a-z][a-z -]*[a-z])\*\B/ -hi-> <EM>$1</EM>

B<The i flag>

This turns on ignore case in the pattern matching.

B<The e flag>

This turns on execute in the pattern substitution.  This really
only makes sense if h is turned on too.  In that case, the "result"
part of the entry is taken as perl code to be executed, and the
result of that code is what replaces the pattern.

B<The o flag>

This marks the entry as a once-only link.  This will convert the
first instance of a matching pattern, and ignore any others
further on.

For example, the following pattern will take the first mention
of HTML::TextToHTML and convert it to a link to the module's home page.

    "HTML::TextToHTML"  -io-> http://www.katspace.com/tools/text_to_html/

=head2 Input File Format

For the most part, this module tries to use intuitive conventions for
determining the structure of the text input.  Unordered lists are
marked by bullets; ordered lists are marked by numbers or letters;
in either case, an increase in indentation marks a sub-list contained
in the outer list.

Headers (apart from custom headers) are distinguished by "underlines"
underneath them; headers in all-capitals are distinguished from
those in mixed case.  All headers, both normal and custom headers,
are expected to start at the first line in a "paragraph".

In other words, the following is a header:

    I am Head Man
    -------------

But the following does not have a header:

    I am not a head Man, man
    I am Head Man
    -------------

Tables require a more rigid convention.  A table must be marked as a
separate paragraph, that is, it must be surrounded by blank lines.
Tables come in different types.  For a table to be parsed, its
--table_type option must be on, and the --make_tables option must be true.

B<ALIGN Table Type>

Columns must be separated by two or more spaces (this prevents
accidental incorrect recognition of a paragraph where interword spaces
happen to line up).  If there are two or more rows in a paragraph and
all rows share the same set of (two or more) columns, the paragraph is
assumed to be a table.  For example

    -e  File exists.
    -z  File has zero size.
    -s  File has nonzero size (returns size).

becomes

    <table>
    <tr><td>-e</td><td>File exists.</td></tr>
    <tr><td>-z</td><td>File has zero size.</td></tr>
    <tr><td>-s</td><td>File has nonzero size (returns size).</td></tr>
    </table>

This guesses for each column whether it is intended to be left,
centre or right aligned.

B<BORDER Table Type>

This table type has nice borders around it, and will be rendered
with a border, like so:

    +---------+---------+
    | Column1 | Column2 |
    +---------+---------+
    | val1    | val2    |
    | val3    | val3    |
    +---------+---------+

The above becomes

    <table border="1">
    <thead><tr><th>Column1</th><th>Column2</th></tr></thead>
    <tbody>
    <tr><td>val1</td><td>val2</td></tr>
    <tr><td>val3</td><td>val3</td></tr>
    </tbody>
    </table>

It can also have an optional caption at the start.

         My Caption
    +---------+---------+
    | Column1 | Column2 |
    +---------+---------+
    | val1    | val2    |
    | val3    | val3    |
    +---------+---------+

B<PGSQL Table Type>

This format of table is what one gets from the output of a Postgresql
query.

     Column1 | Column2
    ---------+---------
     val1    | val2
     val3    | val3
    (2 rows)

This can also have an optional caption at the start.
This table is also rendered with a border and table-headers like
the BORDER type.

B<DELIM Table Type>

This table type is delimited by non-alphanumeric characters, and has to
have at least two rows and two columns before it's recognised as a table.

This one is delimited by the '| character:

    | val1  | val2  |
    | val3  | val3  |

But one can use almost any suitable character such as : # $ % + and so on.
This is clever enough to figure out what you are using as the delimiter
if you have your data set up like a table.  Note that the line has to
both begin and end with the delimiter, as well as using it to separate
values.

This can also have an optional caption at the start.

=head1 EXAMPLES

    use HTML::TextToHTML;
 
=head2 Create a new object

    my $conv = new HTML::TextToHTML();

    my $conv = new HTML::TextToHTML(title=>"Wonderful Things",
			    default_link_dict=>$my_link_file,
      );

=head2 Add further arguments

    $conv->args(short_line_length=>60,
	       preformat_trigger_lines=>4,
	       caps_tag=>"strong",
      );

=head2 Convert a file

    $conv->txt2html(infile=>[$text_file],
                     outfile=>$html_file,
		     title=>"Wonderful Things",
		     mail=>1
      );

=head2 Make a pipleline

    open(IN, "ls |") or die "could not open!";
    $conv->txt2html(inhandle=>[\*IN],
                     outfile=>'-',
      );

=head1 NOTES

=over

=item *

If the underline used to mark a header is off by more than 1, then 
that part of the text will not be picked up as a header unless you
change the value of --underline_length_tolerance and/or
--underline_offset_tolerance.  People tend to forget this.

=back

=head1 REQUIRES

HTML::TextToHTML requires Perl 5.8.1 or later.

For installation, it needs:

    Module::Build

The txt2html script needs:

    Getopt::Long
    Getopt::ArgvFile
    Pod::Usage
    File::Basename

For testing, it also needs:

    Test::More

For debugging, it also needs:

    YAML::Syck

=head1 INSTALLATION

Make sure you have the dependencies installed first!
(see REQUIRES above)

Some of those modules come standard with more recent versions of perl,
but I thought I'd mention them anyway, just in case you may not have
them.

If you don't know how to install these, try using the CPAN module, an
easy way of auto-installing modules from the Comprehensive Perl Archive
Network, where the above modules reside.
Do "perldoc perlmodinstall" or "perldoc CPAN" for more information.

To install this module type the following:

   perl Build.PL
   ./Build
   ./Build test
   ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

In order to install somewhere other than the default, such as
in a directory under your home directory, like "/home/fred/perl"
go

   perl Build.PL --install_base /home/fred/perl

as the first step instead.

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules, and the PATH variable to find the script.

Therefore you will need to change:
your path, to include /home/fred/perl/script (where the script will be)

	PATH=/home/fred/perl/script:${PATH}

the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

Note that the system links dictionary will be installed as
"/home/fred/perl/share/txt2html/txt2html.dict"

If you want to install in a temporary install directory (such as
if you are building a package) then instead of going

   perl Build install

go

   perl Build install destdir=/my/temp/dir

and it will be installed there, with a directory structure under
/my/temp/dir the same as it would be if it were installed plain.
Note that this is NOT the same as setting --install_base, because
certain things are done at build-time which use the install_base info.

See "perldoc perlrun" for more information on PERL5LIB, and
see "perldoc Module::Build" for more information on
installation options.

=head1 BUGS

Tell me about them.

=head1 SEE ALSO

perl
L<txt2html>.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http//www.katspace.com/

based on txt2html by Seth Golub

=head1 COPYRIGHT AND LICENSE

Original txt2html script copyright (c) 1994-2000 Seth Golub <seth AT aigeek.com>

Copyright (c) 2002-2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

#------------------------------------------------------------------------
1;
