package Text::FrontMatter::YAML;

use warnings;
use strict;

use 5.10.1;

use Data::Dumper;
use Carp;
use YAML::Tiny qw/Load/;

=head1 NAME

Text::FrontMatter::YAML - read the "YAML front matter" format

=cut
our $VERSION = '0.07';


=head1 SYNOPSIS

    use File::Slurp;
    use Text::FrontMatter::YAML;

    # READING
    my $text_with_frontmatter = read_file("filename.md");
    my $tfm = Text::FrontMatter::YAML->new(
        document_string => $text_with_frontmatter
    );

    my $hashref  = $tfm->frontmatter_hashref;
    my $mumble   = $hashref->{'mumble'};
    my $data     = $tfm->data_text;

    # or also

    my $fh = $tfm->data_fh();
    while (defined(my $line = <$fh>)) {
        # do something with the file data
    }

    # WRITING
    my $tfm = Text::FrontMatter::YAML->new(
        frontmatter_hashref => {
            title => 'The first sentence of the "Gettysburg Address"',
            author => 'Abraham Lincoln',
            date => 18631119
        },
        data_text => "Four score and seven years ago...",
    );

    write_file("gettysburg.md", $tfm->document_string);


=head1 DESCRIPTION

Text::FrontMatter::YAML reads and writes files with so-called "YAML front
matter", such as are found on GitHub (and used in Jekyll, and various
other programs). It's a way of associating metadata with a file by marking
off the metadata into a YAML section at the top of the file. (See L</The
Structure of files with front matter> for more.)

You can create an object from a string containing a full document (say,
the contents of a file), or from a hashref (to turn into the YAML front
matter) and a string (for the rest of the file data). The object can't be
altered once it's created.

=head2 The Structure of files with front matter

Files with a block at the beginning like the following are considered to
have "front matter":

    ---
    author: Aaron Hall
    email:  ahall@vitahall.org
    module: Text::FrontMatter::YAML
    version: 0.50
    ---
    This is the rest of the file data, and isn't part of
    the front matter block. This section of the file is not
    interpreted in any way by Text::FrontMatter::YAML.

It is not an error to open or create documents that have no front matter
block, nor those that have no data block.

Triple-dashed lines (C<---\n>) mark the beginning of the two sections.
The first triple-dashed line marks the beginning of the front matter. The
second such line marks the beginning of the data section. Thus the
following is a valid document:

    ---
    ---

That defines a document with defined but empty front matter and data
sections. The triple-dashed lines are stripped when the front matter or
data are returned as text.

If the input has front matter, a triple-dashed line must be the first line
of the file. If not, the file is considered to have no front matter; it's
all data. frontmatter_text() and frontmatter_hashref() will return
undef in this case.

In input with a front matter block, the first line following the next
triple-dashed line begins the data section. If there I<is> no second
triple-dashed line the file is considered to have no data section, and
data_text() and data_fh() will return undef.

Creating an object with C<frontmatter_hashref> and C<data_text> works
in reverse, except that there's no way to specify an empty (as opposed
to non-existent) YAML front matter section.

=head1 METHODS

Except for new(), none of these methods take parameters.

=head2 new

new() creates a new Text::FrontMatter::YAML object. You can pass either
C<document_string> with the full text of a document (see L<The Structure
of files with front matter>) or one or both of C<frontmatter_hashref>
and C<data_text>.

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self => $class;

    my %args = @_;

    # disallow passing incompatible arguments
    unless (
        ($args{'document_string'})
          xor
        ($args{'frontmatter_hashref'} or $args{'data_text'})
    ) {
        croak "you must pass either 'document_string', "
            . "or 'frontmatter_hashref' and/or 'data_text'";
    }

    # initialize from whatever we've got
    if ($args{'document_string'}) {
        $self->_init_from_string($args{'document_string'});
    }
    elsif ($args{'frontmatter_hashref'} or $args{'data_text'}) {
        $self->_init_from_sections($args{'frontmatter_hashref'}, $args{'data_text'});
    }
    else {
        die "internal error: didn't get any valid init arg"
    }

    return $self;
}



sub _init_from_sections {
    my $self    = shift;
    my $hashref = shift;
    my $data    = shift;

    $self->{'yaml'} = YAML::Tiny::Dump($hashref);
    $self->{'data'} = $data;

    if (defined $hashref) {
        # YAML::Tiny prefixes the '---' so we don't need to
        $self->{'document'} = $self->{'yaml'};
        $self->{'document'} .= "---\n" if defined($data);
    }

    if (defined $data) {
        $self->{'document'} .= $data;
    }
}


sub _init_from_fh {
    my $self = shift;
    my $fh   = shift;

    my $yaml_marker_re = qr/^---\s*$/;

    LINE: while (my $line = <$fh>) {
        if ($. == 1) {
            # first line: determine if we've got YAML or not
            if ($line =~ $yaml_marker_re) {
                # found opening marker, read YAML front matter
                $self->{'yaml'} = '';
                next LINE;
            }
            else {
                # the whole thing's data, slurp it and go
                local $/;
                $self->{'data'} = $line . <$fh>;
                last LINE;
            }
        }
        else {
            # subsequent lines
            if ($line =~ $yaml_marker_re) {
                # found closing marker, so slurp the rest of the data
                local $/;
                $self->{'data'} = '' . <$fh>; # '' so we always define data here
                last LINE;
            }
            $self->{'yaml'} .= $line;
        }
    }
}


sub _init_from_string {
    my $self   = shift;
    my $string = shift;

    open my $fh, '<:encoding(UTF-8)', \$string
      or die "internal error: cannot open filehandle on string, $!";

    $self->_init_from_fh($fh);
    $self->{'document'} = $string;

    close $fh;
}


=head2 frontmatter_hashref

frontmatter_hashref() loads the YAML in the front matter using L<YAML::Tiny>
and returns a reference to the resulting hash.

If there is no front matter block, it returns undef.

=cut

sub frontmatter_hashref {
    my $self = shift;
    croak("you can't call frontmatter_hashref as a setter") if @_;

    if (! defined($self->{'yaml'})) {
        return;
    }

    if (! $self->{'yaml_hashref'}) {
        my $href = Load($self->{'yaml'});
        $self->{'yaml_hashref'} = $href;
    }

    return $self->{'yaml_hashref'};
}

=head2 frontmatter_text

frontmatter_text() returns the text found the front matter block,
if any. The trailing triple-dash line (C<--->), if any, is removed.

If there is no front matter block, it returns undef.

=cut

sub frontmatter_text {
    my $self = shift;
    croak("you can't call frontmatter_text as a setter") if @_;

    return $self->{'yaml'};
}


=head2 data_fh

data_fh() returns a filehandle whose contents are the data section of the
file. The filehandle will be ready for reading from the beginning. A new
filehandle will be returned each time data_fh() is called.

If there is no data section, it returns undef.

=cut

sub data_fh {
    my $self = shift;
    croak("you can't call data_fh as a setter") if @_;

    if (! defined($self->{'data'})) {
        return;
    }

    my $data = $self->{'data'};
    open my $fh, '<', \$data
      or die "internal error: cannot open filehandle on string, $!";

    return $fh;
}


=head2 data_text

data_text() returns a string contaning the data section of the file.

If there is no data section, it returns undef.

=cut

sub data_text {
    my $self = shift;
    croak("you can't call data_text as a setter") if @_;

    return $self->{'data'};
}

=head2 document_string

document_string() returns the complete, joined front matter and data
sections, suitable for writing to a file.

=cut

sub document_string {
    my $self = shift;
    croak("you can't call document_string as a setter") if @_;

    return $self->{'document'};
}

=head1 DIAGNOSTICS

=over 4

=item cannot pass 'document_string' with either 'frontmatter_hashref' or 'data_text'

When calling new(), you can't both pass in a complete document string I<and>
the individual hashref and data sections.

=item you can't call <method> as a setter

Once you create the object, you can't change it.

=item internal error: ...

Something went wrong that wasn't supposed to, and points to a bug. Please
report it to me at C<bug-text-frontmatter-yaml@rt.cpan.org>. Thanks!

=back


=head1 BUGS & CAVEATS

=over 4

=item *

If you create an object from a string with C<document_string>, and then
pull the string back out with document_string(), don't rely on hash keys
in the YAML to be ordered the same way.

=item *

Errors in the YAML will only be detected upon calling frontmatter_hashref(),
because that's the only time that L<YAML::Tiny> is called to parse the YAML.

=back

Please report bugs to me at C<bug-text-frontmatter-yaml@rt.cpan.org> or
use the web interface at:

L<https://rt.cpan.org/Public/Bug/Report.html?Queue=Text-FrontMatter-YAML>.

I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.


=head1 SEE ALSO

Jekyll - L<https://github.com/mojombo/jekyll/wiki/yaml-front-matter>

L<YAML>

L<YAML::Tiny>

=head1 AUTHOR

Aaron Hall, C<vitahall@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2013-2014 Aaron Hall.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.1.

See L<http://dev.perl.org/licenses/> for more information.

=cut

1; # End of Text::FrontMatter::YAML
