require 5.004;
use strict;

package HTML::FromText;
use Carp;
use Exporter;
use Text::Tabs 'expand';
use vars qw($RCSID $VERSION $QUIET @EXPORT @ISA);

@ISA = qw(Exporter);
@EXPORT = qw(text2html);
$RCSID = q$Id: FromText.pm,v 1.14 1999/10/06 10:53:37 garethr Exp $;
$VERSION = '1.005';
$QUIET = 0;

# This list of protocols is taken from RFC 1630: "Universal Resource
# Identifiers in WWW".  The protocol "file" is omitted because
# experience suggests that it results in many false positives; "https"
# postdates RFC 1630.  The protocol "mailto" is handled separately, by
# the email address matching code.

my $protocol = join '|',
  qw(afs cid ftp gopher http https mid news nntp prospero telnet wais);

# The regular expressions matching email addresses use the following
# syntax elements from RFC 822.  I can't use the full details of
# structured field bodies, because that would give too many false
# positives.  (See Tom Christiansen's ckaddr.gz for a full
# implementation of the RFC 822.)
#
#   addr-spec   =  local-part "@" domain
#   local-part  =  word *("." word)
#   word        =  atom
#   domain      =  sub-domain *("." sub-domain)
#   sub-domain  =  domain-ref
#   domain-ref  =  atom
#   atom        =  1*<any CHAR except specials, SPACE and CTLs>
#   specials    =  "(" / ")" / "<" / ">" / "@" /  "," / ";" / ":" / "\"
#   		   / <"> /  "." / "[" / "]"
#
# I have ignored quoting, domain literals and comments.
#
# Note that '&' can legally appear in email addresses (for example,
# 'fred&barney@stonehenge.com').  If the 'metachars' option is passed to
# text2html then I must use '&amp;' to recognize '&'.  Thus the regular
# expression $atom[0] recognizes an atom in the case where the option
# 'metachars' is false; $atom[1] recognizes an atom in the case where
# 'metachars' is true.  Similarly for the regular expressions $email[0]
# and $email[1], which recognize email addresses.

my @atom =
  ( '[!#$%&\'*+\\-/0123456789=?ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`abcdefghijklmnopqrstuvwxyz{|}~]+',
    '(?:&amp;|[!#$%\'*+\\-/0123456789=?ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`abcdefghijklmnopqrstuvwxyz{|}~])+' );

my @email = ( "$atom[0](\\.$atom[0])*\@$atom[0](\\.$atom[0])*",
	      "$atom[1](\\.$atom[1])*\@$atom[1](\\.$atom[1])*" );

my @alignments = ( '', '', ' ALIGN="RIGHT"', ' ALIGN="CENTER"' );

sub string2html ($$) {
  my $options = $_[1];
  for ($_[0]) {			# Modify in-place.

    # METACHARS: mark up HTML metacharacters as corresponding entities.
    if ($options->{metachars}) {
      s/&/&amp;/g;
      s/</&lt;/g;
      s/>/&gt;/g;
      s/\"/&quot;/g;
    }

    # EMAIL, URLS: spot electronic mail addresses and turn them into
    # links.  Note (1) if `urls' is set but not `email', then only
    # addresses prefixed by `mailto:' will be marked up; (2) that we leave
    # the `mailto:' prefix in the anchor text.
    if ($options->{email} or $options->{urls}) {
      s|((?:mailto:)?)($email[$options->{metachars}?1:0])|
	($options->{email} or $1)
	  ? "<TT><A HREF=\"mailto:$2\">$1$2</A></TT>" : $2|gex;
    }

    # URLS: mark up URLs as links (note that `mailto' links are handled
    # above).
    if ($options->{urls}) {
      s|\b((?:$protocol):\S+[\w/])|<TT><A HREF="$1">$1</A></TT>|g;
    }

    # BOLD: mark up words in *asterisks* as bold.
    if ($options->{bold}) {
      s#(^|\s)\*([^*]+)\*(?=\s|$)#$1<B>$2</B>#g;
    }

    # UNDERLINE: mark up words in _underscores_ as underlined.
    if ($options->{underline}) {
      s#(^|\s)_([^_]+?)_(?=\s|$)#$1<U>$2</U>#g;
    }
  }

  return $_[0];
}

sub text2html {
  local $_ = shift;		# Take a copy; don't modify in-place.
  return $_ unless $_;

  my %options = ( metachars => 1, @_ );

  # Check options for sanity.
  unless ($QUIET) {
    carp "text2html: `spaces' will be ignored since `lines' is not specified"
      if $options{spaces} and not $options{lines};
    if ($options{paras}) {
      if ($options{blockparas}) {
	foreach my $o (qw(blockquotes blockcode)) {
	  carp "text2html: `$o' will be ignored since `blockparas' is specified" if $options{$o};
	}
      } elsif ($options{blockcode} and $options{blockquotes}) {
	carp "text2html: `blockquotes' will be ignored since `blockcode' is specified";
      }
    } else {
      foreach my $o (qw(bullets numbers blockquotes blockparas blockcode
		        title headings tables)) {
	carp "text2html: `$o' will be ignored since `paras' is not specified"
	  if $options{$o};
      }
    }
  }

  # Expand tabs.
  $_ = join "\n", expand(split /\r?\n/);

  # PRE: put text in <PRE> element.
  if ($options{pre}) {
    string2html($_, \%options);
    s|^|<PRE>|;
    s|$|</PRE>|;
  }

  # LINES: preserve line breaks from original text.
  elsif ($options{lines}) {
    string2html($_, \%options);
    s/\n/<BR>\n/gm;

    # SPACES: preserve spaces from original text.
    s/ /&nbsp;/g if $options{spaces};
  }

  # PARAS: treat text as sequence of paragraphs.
  elsif ($options{paras}) {
    my @paras;

    # Remove initial and final blank lines.
    s/^(?:\s*?\n)+//;
    s/(?:\n\s*?)+$//;

    # Split on a different regexp depending on what kinds of paragraphs
    # will be recognised later.  The idea is that bulleted lists like
    # this:
    #
    #     * item 1
    #     * item 2
    #
    # will be recognised as multiple paragraphs if the 'bullets' option
    # is supplied, but as a single paragraph otherwise.  (Similarly for
    # numbered lists).
    if ($options{bullets} and $options{numbers}) {
      @paras = split
	/(?:\s*\n)+                  # (0 or more blank lines, followed by LF)
         (?:\s*\n                    # Either 1 or more blank lines, or
          |(?=\s*[*-]\s+             #   bulleted item follows, or
            |\s*(?:\d+)[.\)\]]?\s+)) #   numbered item follows
        /x;
    } elsif ($options{bullets}) {
      @paras = split
	/(?:\s*\n)+                  # (0 or more blank lines, followed by LF)
         (?:\s*\n                    # Either 1 or more blank lines, or
          |(?=\s*[*-]\s+))           #   bulleted item follows.
        /x;
    } elsif ($options{numbers}) {
      @paras = split
	/(?:\s*\n)+                  # (0 or more blank lines, followed by LF)
         (?:\s*\n                    # Either 1 or more blank lines, or
         |(?=\s*(?:\d+)[.\)\]]?\s+)) #   numbered item follows.
        /x;
    } else {
      @paras = split
	/\s*\n(?:\s*\n)+	     # 1 or more blank lines.
        /x;
    }

    my $last = '';		# List type (OL/UL) of last paragraph
    my $this;			# List type (OL/UL) of this paragraph
    my $first = 1;		# True if this is first paragraph

    foreach (@paras) {
      my (@rows,@starts,@ends);
      $this = '';

      # TITLE: mark up first paragraph as level-1 heading.
      if ($options{title} and $first) {
	string2html($_,\%options);
	s|^|<H1>|;
	s|$|</H1>|;
      }

      # HEADINGS: mark up paragraphs with numbers at the start of the
      # first line as headings.
      elsif ($options{headings} and /^(\d+(\.\d+)*)\.?\s/) {
	my $number = $1;
	my $level = 1 + ($number =~ tr/././);
	$level = 6 if $level > 6;
	string2html($_,\%options);
	s|^|<H$level>|;
	s|$|</H$level>|;
      }

      # BULLETS: mark up paragraphs starting with bullets as items in an
      # unnumbered list.
      elsif ($options{bullets} and /^\s*[*-]\s+/) {
	string2html($_,\%options);
        s/^\s*[*-]\s+/<LI><P>/;
	s|$|</P>|;
	$this = 'UL';
      }

      # NUMBERS: mark up paragraphs starting with numbers as items in a
      # numbered list.
      elsif ($options{numbers} and /^\s*(\d+)[.\)\]]?\s+/) {
	string2html($_,\%options);
        s/^\s*(\d+)[.\)\]]?\s+/<LI VALUE="$1"><P>/;
	s|$|</P>|;
	$this = 'OL';
      }

      # TABLES: spot and mark up tables.  We combine the lines of the
      # paragraph using the string bitwise or (|) operator, the result
      # being in $spaces.  A character in $spaces is a space only if
      # there was a space at that position in every line of the
      # paragraph.  $space can be used to search for contiguous spaces
      # that occur on all lines of the paragraph.  If this results in at
      # least two columns, the paragraph is identified as a table.
      #
      # Note that this option appears before the various 'blockquotes'
      # options because a table may well have whitespace to the left, in
      # which case it must not be incorrectly recognised as a
      # blockquote.
      elsif ($options{tables} and do {
	@rows = split /\n/, $_;
	my $spaces;
	my $max = 0;
	my $min = length;
	foreach my $row (@rows) {
	  ($spaces |= $row) =~ tr/ /\xff/c;
	  $min = length $row if length $row < $min;
	  $max = length $row if $max < length $row;
	}
	$spaces = substr $spaces, 0, $min;
	push(@starts, 0) unless $spaces =~ /^ /;
	while ($spaces =~ /((?:^| ) +)(?=[^ ])/g) {
	  push @ends, pos($spaces) - length $1;
	  push @starts, pos($spaces);
	}
	shift(@ends) if $spaces =~ /^ /;
	push(@ends, $max);

	# Two or more rows and two or more columns indicate a table.
	2 <= @rows and 2 <= @starts
      }) {
	# For each column, guess whether it should be left, centre or
	# right aligned by examining all cells in that column for space
        # to the left or the right.  A simple majority among those cells
        # that actually have space to one side or another decides (if no
        # alignment gets a majority, left alignment wins by default).

	my @align;
	foreach my $col (0 .. $#starts) {
	  my @count = (0, 0, 0, 0);
          foreach my $row (@rows) {
	    my $width = $ends[$col] - $starts[$col];
	    my $cell = substr $row, $starts[$col], $width;
	    ++ $count[($cell =~ /^ / ? 2 : 0)
		      + ($cell =~ / $/ || length($cell) < $width ? 1 : 0)];
	  }
	  $align[$col] = 0;
	  my $population = $count[1] + $count[2] + $count[3];
	  foreach (1 .. 3) {
	    if ($count[$_] * 2 > $population) {
	      $align[$col] = $_;
	      last;
	    }
	  }
        }

	foreach my $row (@rows) {
	  $row = join '', '<TR>', (map {
	    my $cell = substr $row, $starts[$_], $ends[$_] - $starts[$_];
	    $cell =~ s/^ +//;
	    $cell =~ s/ +$//;
            string2html($cell,\%options);
	    ('<TD', $alignments[$align[$_]], '>', $cell, '</TD>')
	  } 0 .. $#starts), '</TR>';
	}
	my $tag = $starts[0] == 0 ? 'P' : 'BLOCKQUOTE';
	$_ = join "\n", "<$tag><TABLE>", @rows, "</TABLE></$tag>";
      }

      # BLOCKPARAS, BLOCKCODE, BLOCKQUOTES: mark up indented paragraphs
      # as block quotes of various kinds.
      elsif (($options{blockparas} or $options{blockquotes}
		or $options{blockcode}) and /^(\s+).*(?:\n\1.*)*$/) {
	string2html($_,\%options);

	# Every line in the paragraph starts with at white space, the common
	# whitespace being in $1.  Remove the common initial whitespace,
	s/^$1//gm;

	# BLOCKPARAS: treat as a paragraph.
	if ($options{blockparas}) {
          s|^|<P>|;
          s|$|</P>|;
	}

	# BLOCKCODE, BLOCKQUOTES: preserve line breaks.
	else {
	  s/\n/<BR>\n/gm;

	  # BLOCKCODE: preserve spaces, use fixed-width font.
	  if ($options{blockcode}) {
	    s| |&nbsp;|g;
            s|^|<TT>|;
	    s|$|</TT>|;
	  }
	}
        s|^|<BLOCKQUOTE>|;
        s|$|</BLOCKQUOTE>|;
      }

      # Didn't match any of the above, so just an ordinary paragraph.
      else {
        string2html($_,\%options);
	s|^|<P>|;
	s|$|</P>|;
      }

      # Insert <UL>, </UL>, <OL> or </OL> if this paragraph belongs to a
      # different list type than the previous one.
      if ($this ne $last) {
	s|^|<$this>| if ($this ne '');
	s|^|</$last>| if ($last ne '');
      }
      $last = $this;
      $first = 0;
    }
    if ($this ne '') {
      push @paras, "</$this>";
    }
    $_ = join "\n", @paras;
  }

  # None of PRE, LINES, PARAS specified: apply basic transformations.
  else {
    string2html($_,\%options);
  }
  return $_;
}

1;

__END__

=head1 NAME

HTML::FromText - mark up text as HTML

=head1 SYNOPSIS

    use HTML::FromText;
    print text2html($text, urls => 1, paras => 1, headings => 1);

=head1 DESCRIPTION

The C<text2html> function marks up plain text as HTML.  By default it
expands tabs and converts HTML metacharacters into the corresponding
entities.  More complicated transformations, such as splitting the text
into paragraphs or marking up bulleted lists, can be carried out by
setting the appropriate options.

=head1 SUMMARY OF OPTIONS

These options always apply:

    metachars    Convert HTML metacharacters to entity references
    urls         Convert URLs to links
    email        Convert email addresses to links
    bold         Mark up words with *asterisks* in bold
    underline    Mark up words with _underscores_ as underlined

You can then choose to treat the text according to one of these options:

    pre          Treat text as preformatted
    lines        Treat text as line-oriented
    paras        Treat text as paragraph-oriented

(If more than one of these is specified, C<pre> takes precedence over
C<lines> which takes precedence over C<paras>.)  The following option
applies when the C<lines> option is specified:

    spaces       Preserve spaces from the original text

The following options apply when the C<paras> option is specified:

    blockparas   Mark up indented paragraphs as block quote
    blockquotes  Ditto, also preserve lines from original
    blockcode    Ditto, also preserve spaces from original
    bullets      Mark up bulleted paragraphs as unordered list
    headings     Mark up headings
    numbers      Mark up numbered paragraphs as ordered list
    tables       Mark up tables
    title        Mark up first paragraph as level 1 heading

C<text2html> will issue a warning if it is passed nonsensical options,
for example C<headings> but not C<paras>.  These warnings can be
supressed by setting $HTML::FromText::QUIET to true.

=head1 OPTIONS

=over 4

=item blockparas

=item blockquotes

=item blockcode

These options cause to C<text2html> to spot paragraphs where every line
begins with whitespace, and mark them up as block quotes.  If more than
one of these options is specified, C<blockparas> takes precedence over
C<blockcode>, which takes precedence over C<blockquotes>.  All three
options are ignored unless the C<paras> option is also set.

The C<blockparas> option marks up the paragraph as a block quote with no
other changes.  For example,

    Turing wrote,

        I propose to consider the question,
        "Can machines think?"

becomes

    <P>Turing wrote,</P>
    <BLOCKQUOTE>I propose to consider the question,
    &quot;Can machines think?&quot;</BLOCKQUOTE>

The C<blockquotes> option preserves line breaks in the original text.
For example,

    From "The Waste Land":

        Phlebas the Phoenecian, a fortnight dead,
        Forgot the cry of gulls, and the deep sea swell

becomes

    <P>From &quot;The Waste Land&quot;:</P>
    <BLOCKQUOTE>Phlebas the Phoenecian, a fortnight dead,<BR>
    Forgot the cry of gulls, and the deep sea swell</BLOCKQUOTE>

The C<blockcode> option preserves line breaks and spaces in the original
text and renders the paragraph in a fixed-width font.  For example:

    Here's how to output numbers with commas:

        sub commify {
          local $_ = shift;
          1 while s/^(-?\d+)(\d{3})/$1,$2/;
          $_;
        }

becomes

    <P>Here's how to output numbers with commas:</P>
    <BLOCKQUOTE><TT>sub&nbsp;commify&nbsp;{<BR>
    &nbsp;&nbsp;local&nbsp;$_&nbsp;=&nbsp;shift;<BR>
    &nbsp;&nbsp;1&nbsp;while&nbsp;s/^(-?\d+)(\d{3})/$1,$2/;<BR>
    &nbsp;&nbsp;$_;<BR>
    }</TT></BLOCKQUOTE>

=item bold

Words surrounded with asterisks are marked up in bold, so C<*abc*>
becomes C<E<lt>BE<gt>abcE<lt>/BE<gt>>.

=item bullets

Spots bulleted paragraphs (beginning with optional whitespace, an
asterisk or hyphen, and whitespace) and marks them up as an unordered
list.  Bulleted paragraphs don't have to be separated by blank lines.
For example,

    Shopping list:

      * apples
      * pears

becomes

    <P>Shopping list:</P>
    <UL><LI><P>apples</P>
    <LI><P>pears</P>
    </UL>

This option is ignored unless the C<paras> option is set.

=item email

Spots email addresses in the text and converts them to links.  For example

    Mail me at web@perl.com.

becomes

    Mail me at <TT><A HREF="mailto:web@perl.com">web@perl.com</A></TT>.

=item headings

Spots headings (paragraphs starting with numbers) and marks them up as
headings of the appropriate level.  For example,

    1. Introduction

    1.1 Background

    1.1.1 Previous work

    2. Conclusion

becomes

    <H1>1. Introduction</H1>
    <H2>1.1 Background</H2>
    <H3>1.1.1 Previous work</H3>
    <H1>2. Conclusion</H1>

This option is ignored unless the C<paras> option is set.

=item lines

Formats the text so as to preserve line breaks.  For example,

    Line 1
    Line 2

becomes

    Line 1<BR>
    Line 2

If two or more of the options C<pre>, C<lines> and C<paras> are set,
then C<pre> takes precedence over C<lines>, which takes precedence over
C<paras>.

=item metachars

Converts HTML metacharacters into their corresponding entity references.
Ampersand (C<E<amp>>) becomes C<E<amp>amp;>, less than (C<E<lt>>)
becomes C<E<amp>lt;>, greater than (C<E<gt>>) becomes C<E<amp>gt;>, and
quote (") becomes C<E<amp>quot;>.  This option is 1 by default.

=item numbers

Spots numbered paragraphs (beginning with whitespace, digits, an
optional period/parenthesis/bracket, and whitespace) and marks them up
as an ordered list.  Numbered paragraphs don't have to be separated by
blank lines.  For example,

    To do:

       1. Write thesis
       2. Submit it
       3. Celebrate

becomes

    <P>To do:</P>
    <OL><LI VALUE="1"><P>Write thesis</P>
    <LI VALUE="2"><P>Submit it</P>
    <LI VALUE="3"><P>Celebrate</P>
    </OL>

This option is ignored unless the C<paras> option is set.

=item paras

Format the text into paragraphs.  Paragraphs are separated by one or
more blank lines.  For example,

    Paragraph 1

    Paragraph 2

becomes

    <P>Paragraph 1</P>
    <P>Paragraph 2</P>

If two or more of the options C<pre>, C<lines> and C<paras> are set,
then C<pre> takes precedence over C<lines>, which takes precedence over
C<paras>.

=item pre

Wrap the whole input in a C<E<lt>PREE<gt>> element.  For example,

    preformatted
    text

becomes

    <PRE>preformatted
    text</PRE>

If two or more of the options C<pre>, C<lines> and C<paras> are set,
then C<pre> takes precedence over C<lines>, which takes precedence over
C<paras>.

=item spaces

Preserves spaces throughout the text.  For example,

    Line 1
     Line  2
      Line   3

becomes

    Line 1<BR>
    &nbsp;Line&nbsp;&nbsp;2<BR>
    &nbsp;&nbsp;Line&nbsp;&nbsp;&nbsp;3

This option is ignored unless the C<lines> option is set.

=item tables

Spots tables and marks them up appropriately.  Columns must be separated
by two or more spaces (this prevents accidental incorrect recognition of
a paragraph where interword spaces happen to line up).  If there are two
or more rows in a paragraph and all rows share the same set of (two or
more) columns, the paragraph is assumed to be a table.  For example

    -e  File exists.
    -z  File has zero size.
    -s  File has nonzero size (returns size).

becomes

    <P><TABLE>
    <TR><TD>-e</TD><TD>File exists.</TD></TR>
    <TR><TD>-z</TD><TD>File has zero size.</TD></TR>
    <TR><TD>-s</TD><TD>File has nonzero size (returns size).</TD></TR>
    </TABLE></P>

C<text2html> guesses for each column whether it is intended to be left,
centre or right aligned.

This option is ignored unless the C<paras> option is set.

=item title

Formats the first paragraph of the text as a first-level heading.
For example,

    Paragraph 1

    Paragraph 2

becomes

    <H1>Paragraph 1</H1>
    <P>Paragraph 2</P>

This option is ignored unless the C<paras> option is set.

=item underline

Words surrounded with underscores are marked up with underline, so C<_abc_>
becomes C<E<lt>UE<gt>abcE<lt>/UE<gt>>.

=item urls

Spots Uniform Resource Locators (URLs) in the text and converts them
to links.  For example

    See https://perl.com/.

becomes

    See <TT><A HREF="https://perl.com/">https://perl.com/</A></TT>.

=back

=head1 SEE ALSO

The C<HTML::Entities> module (part of the LWP package) provides
functions for encoding and decoding HTML entities.

Tom Christiansen has a complete implementation of RFC 822 structured
field bodies.  See
C<http://www.perl.com/CPAN/authors/Tom_Christiansen/scripts/ckaddr.gz>.

Seth Golub's C<txt2html> utility does everything that C<HTML::FromText>
does, and a few things that it would like to do.  See
C<http://www.thehouse.org/txt2html/>.

RFC 822: "Standard for the Format of ARPA Internet Text Messages"
describes the syntax of email addresses (the more esoteric features of
structured field bodies, in particular quoted-strings, domain literals
and comments, are not recognized by C<HTML::FromText>).  See
C<ftp://src.doc.ic.ac.uk/rfc/rfc822.txt>.

RFC 1630: "Universal Resource Identifiers in WWW" lists the protocols
that may appear in URLs.  C<HTML::FromText> also recognizes "https:",
but ignores "file:" because experience suggests that it results in too
many false positives.  See C<ftp://src.doc.ic.ac.uk/rfc/rfc1630.txt>.

=head1 AUTHOR

Gareth Rees C<E<lt>garethr@cre.canon.co.ukE<gt>>.

=head1 COPYRIGHT

Copyright (c) 1999 Canon Research Centre Europe. All rights reserved.
This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
