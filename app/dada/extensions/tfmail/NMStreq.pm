package NMStreq;
use strict;

use CGI;
use Carp;
use IO::File;
use File::Basename;
use POSIX qw(locale_h strftime);
use NMSCharset;

use vars qw($VERSION);
$VERSION = substr q$Revision: 1.1 $, 10, -1;

=head1 NAME

NMStreq - CGI request object with output templating

=head1 SYNOPSIS

  use IO::File;
  use NMStreq;

  my $treq = NMStreq->new( ConfigRoot => '/my/config/root' );

  ....

  my $sendmail = IO::File->new('| /usr/lib/sendmail -oi -t');
  defined $sendmail or die "open sendmail pipe: $!";
  $sendmail->print($mailheader, "\n");
  $treq->process_template(
      $treq->config('email_body_template', 'main_email'),
      'email',
      $sendmail
  );
  $sendmail->close or die "close sendmail pipe: $!";

  ....

  print "Content-type: text/html; charset=iso-8859-1\n\n";

  $treq->process_template(
      $treq->config('success_page_template', 'spage'),
      'html',
      \*STDOUT
  );

  ....

=head1 DESCRIPTION

An object of the C<NMStreq> class encapsulates a CGI
request who's handing depends on a configuration file
identified by the C<_config> CGI parameter.  A
simplistic templating mechanism is provided, to ease
end user customization of the output HTML and the
bodies of any emails sent.

=head1 CONSTRUCTORS

=over

=item new ( [OPTIONS] )

Creates a new C<NMStreq> object and populates it with
data pertinent to the current CGI request.  The CGI
parameter C<_config> will be used to identify the
correct configuration file for this request.  The
OPTIONS must consist of matching name/value pairs,
and the following options are recognized:

=over

=item C<ConfigRoot>

The filesystem path to the directory that holds the
configuration files and templates.  Defaults to
F</usr/local/nmstreq/config>.

=item C<MaxDepth>

The depth to which configuration files and templates
can be placed in subdirectories of the C<ConfigRoot>.
Defaults to 0, meaning that all configuration files
must reside directly in the C<ConfigRoot> directory.

=item C<ConfigExt>

The extension that configuration files are expected to
have.  Defaults to C<.trc>.

=item C<TemplateExt>

The extension that template files are expected to have.
Defaults to C<.trt>.

=item C<DateFormat>

The default date format string that will be used to
resolve the C<date> template directive if no C<date_fmt>
configuration setting is found.  Defaults to
C<%A, %B %d, %Y at %H:%M:%S>.

=item C<EnableUploads>

Unless this is set true, file uploads will be disabled in
C<CGI.pm>.  Defaults to false.

=item C<CGIMaxPost>

The maximum total size of post data.  Defaults to 1000000
bytes.

=item C<Charset>

The name of the character set to be used for input and
output text, used to initialise an C<NMSCharset> object,
see L<NMSCharset>.  Defaults to C<iso-8859-1>.

=back

Any other options set will be ignored by this module,
but can be interpolated into templates via the C<opt>
template directive if desired.

=back

=cut

sub new
{
   my $pkg = shift;

   my $self = bless {}, ref $pkg || $pkg;

   $self->{r}{opt} = $self->{opt} = {
      ConfigRoot    => '/usr/local/nmstreq/config',
      MaxDepth      => 0,
      ConfigExt     => '.trc',
      TemplateExt   => '.trt',
      DateFormat    => '%A, %B %d, %Y at %H:%M:%S',
      EnableUploads => 0,
      CGIPostMAx    => 1000000,
      Charset       => 'iso-8859-1',
      @_
   };

   $CGI::DISABLE_UPLOADS = ($self->{opt}{EnableUploads} ? 0 : 1);
   $CGI::POST_MAX        = $self->{opt}{CGIPostMax};

   my $charset = NMSCharset->new($self->{opt}{Charset});
   $self->{strip_nonprint} = $charset->strip_nonprint_coderef;
   $self->{escape_html}    = $charset->escape_html_coderef;

   my $cgi = CGI->new;
   $self->{cgi} = $cgi;

   my $cfg_name = $cgi->param('_config');
   defined $cfg_name or $cfg_name = 'default';
   $self->{r}{config} = $self->_read_config_file($cfg_name);

   # cache location of the config file to find the templates
   
   $self->{r}{config_path} 
                      = dirname($self->{opt}{ConfigRoot} . "/" . $cfg_name);

   $self->{r}{param} = {};
   my @param_list = ();
   foreach my $param ($cgi->param)
   {
      my $key = $self->strip_nonprintable($param);
      push @param_list, $key unless exists $self->{r}{param}{$key};

      my $val = join ' ',
                map {$self->strip_nonprintable($_)}
                $cgi->param($param);
      $self->{r}{param}{$key} = $val;
   }
   $self->{param_list} = \@param_list;

   foreach my $envval (keys %ENV)
   {
      my $key = $self->strip_nonprintable($envval);
      my $val = $self->strip_nonprintable($ENV{$envval});
      $self->{r}{env}{$key} = $val;
   }

   $self->{r}{date}         = \&_interpolate_date;

   return $self;
}

=head1 METHODS

=over

=item process_template ( TEMPLATE, CONTEXT, DEST )

Reads in the template TEMPLATE, which can either be an inline
template as a multiline string or the path to a template file,
relative to the configuration root and without the file
extension.  Data is substituted for any template directives
in the template, and the resulting document is passed out to
DEST.

CONTEXT is a string describing the context of the output
document, and must be either C<html> or C<email>.  If CONTEXT
is C<html> then all HTML metacharacters in interpolated
values will be escaped.  If CONTEXT is C<email> then space
characters will be inserted at a couple of points, to reduce
the scope for malicious input values to make mail software do
bad things.

DEST can be a coderef, a file glob, an object with a
print() method, or undef.

On failure, invokes the non-returning error() method.

If DEST is undef, then all template output is accumulated
into a string, which becomes the return value.

=cut

sub process_template
{
   my ($self, $template, $context, $dest) = @_;

   my ($ret, $coderef);
   if (defined $dest)
   {
      $ret = 1;
      $coderef = $self->_dest_to_coderef($dest);
   }
   else
   {
      $ret = '';
      $coderef = sub { $ret .= $_[0] };
   }

   my $complied = $self->_compile_template($template, $context);
   $self->_run_template($complied, $context, $coderef);

   return $ret;
}

=item install_directive ( NAME, VALUE )

Installs an extra directive into the data tree used for
interpolating values into templates.  NAME must be a
string consisting of word characters only.  VALUE can
be any of:

=over

=item C<a string>

If VALUE is a string then that string will be substituted
for the NAME template directive.

=item C<a reference to a string>

If VALUE is a scalar reference then the referenced string
will be substituted for the NAME template directive, without
any context dependent processing.  The string goes directly to
the output document, without HTML metacharacter escaping in
an html context or sanitisation in an email context.

Use this only for trusted data or data that has already been
carefully filtered for HTML or other malicious constructs. 

=item C<a coderef>

If VALUE is a coderef then it will be called to produce the
substitute text whenever the NAME directive is encountered.
It will be passed a reference to the C<NMStreq> object as
its first argument, the context string ("html" or "email")
as its second argument, and a destination coderef as its
third argument.  The VALUE coderef can pass output direct
to the destination coderef, and/or return some output as
a string.

=item C<a hashref>

In this case a new tree of two-part directives is defined,
with the sub-directives corresponding to the keys in the
hash.  The values in the hash must be strings, coderefs
or further hashrefs.

=back

=cut

sub install_directive
{
   my ($self, $name, $value) = @_;

   $self->{r}{$name} = $value;
}

=item uninstall_directive ( NAME )

Removes a directive previously installed with the
install_directive() method, or disables one of the builtin
directives.

Returns a value which will reinstall the directive if passed
to the install_directive() method.

=cut

sub uninstall_directive
{
   my ($self, $name) = @_;

   my $save = $self->{r}{$name};
   delete $self->{r}{$name};
   return $save;
}

=item install_foreach ( NAME, VALUES )

Installs data to support a FOREACH directive in templates.
NAME should be the name to appear in the FOREACH directive,
and VALUES must be a ref to an array of hashes, with each
hash defining values for local variables for one iteration
of the FOREACH loop.  For example, this code:

  $treq->install_foreach( 'foobar', [
    { foo => 'foo1', bar => 'bar7' },
    { foo => 'foo2', bar => 'bar4' },
    { foo => 'foo3', bar => 'bar9' },
  ]);

would cause this template segment:

  {= FOREACH foobar =}
  The foo is {= foo =}, but the bar is {= bar =}!
  {= END =}

to produce the output:

  The foo is foo1, but the bar is bar7!
  The foo is foo2, but the bar is bar4!
  The foo is foo3, but the bar is bar9!

The values can be references to strings rather than strings, to
prevent context dependent processing, as in install_directive()
above.  Use this feature only with trusted or already filtered
data, since it bypasses HTML metacharacter escaping and could
lead to XSS vulnerabilities if misapplied.
 
=cut

sub install_foreach
{
   my ($self, $name, $values) = @_;

   $self->{'foreach'}{$name} = $values;
}

=item uninstall_foreach ( NAME )

Removes a foreach data set previously installed with
the install_foreach() method.

Returns a value which will reinstall the foreach data
if passed to the install_foreach() method.

=cut

sub uninstall_foreach
{
   my ($self, $name) = @_;

   my $save = $self->{'foreach'}{$name};
   delete $self->{'foreach'}{$name};
   return $save;
}

=item config ( SETTING_NAME, DEFAULT )

Returns the value of the configuration setting SETTING_NAME
set in the configuration file for this request, or DEFAULT
if no value for SETTING_NAME has been set.

=cut

sub config
{
   my ($self, $setting_name, $default) = @_;

   my $val = $self->{r}{config}{$setting_name};
   defined $val ? $val : $default;
}

=item param ( PARAM_NAME )

Returns the value of the CGI parameter PARAM_NAME, with
runs of nonprintable characters replaced with spaces.
If the same CGI parameter appears several times then all
the values of that parameter are joined together, using
a single space character as a separator.

Returns the empty string if no such parameter is set.

=cut

sub param
{
   my ($self, $param_name) = @_;

   my $val = $self->{r}{param}{$param_name};
   defined $val ? $val : '';
}

=item param_list ()

Returns a list of the names of all CGI parameters.  The
parameter names are returned in the order in which each
parameter first occurs in the request.  There will be no
duplicates in the list returned.

Runs of nonprintable characters in parameter names are
replaced with spaces, both in the list returned by this
method and in the parameter names recognized by the
param() method.

=cut

sub param_list
{
   my ($self) = @_;

   return @{ $self->{param_list} };
}

=item cgi ()

Returns a reference to the C<CGI> object that this modules
uses to access the CGI parameter list.

=cut

sub cgi
{
   my ($self) = @_;

   return $self->{cgi};
}

=back

=head1 METHODS TO OVERRIDE

Subclasses may override any of the following methods in
order to alter the class's behavior.

=over

=item error ( MESSAGE )

A non-returning method used to handle fatal errors.  The
MESSAGE string may contain unsafe and potentially malicious
data and so must be handled with care.

This method must not return.

The default implementation calls croak().

=cut

sub error
{
   my ($self, $message) = @_;

   croak $message;
}

=item strip_nonprintable ( STRING )

Returns a copy of STRING with runs of non-printable
characters replaced with space.  The default implementation
uses the coderef provided by the C<NMSCharset> module, see
L<NMSCharset>.

=cut

sub strip_nonprintable
{
   my ($self, $string) = @_;

   &{ $self->{strip_nonprint} }( $string );
}

=item escape_html ( STRING )

Returns a copy of STRING with any HTML metacharacters escaped.
The default implementation uses the coderef provided by the
C<NMSCharset> module, see L<NMSCharset>.

=cut

sub escape_html
{
   my ($self, $string) = @_;

   &{ $self->{escape_html} }( $string );
}

=back

=head1 INTERNAL METHODS

None of these methods should be accessed from outside this
module.

=over

=item _compile_template ( TEMPLATE, CONTEXT )

Reads in a template for context CONTEXT from TEMPLATE
(which can be either a template filename relative to the
configuration root or an inline template as a multiline
string) and compiles it to the following internal
representation:

The compiled template is an array ref, each element of
which is one of:

=over

=item C<a scalar>

Some literal text from the template

=item C<a scalar reference>

The referenced string is the contents of a template
directive other than a control structure.

=item C<a hash reference>

The referenced hash represents a control structure.  The
C<ctl> value is a string that defines the type of control
structure (C<FOREACH> and C<IF>/C<ELSE> are defined).  The
C<sub> value is an array reference, holding the control
structure body as a compiled template.  The C<arg> value
is the argument string (if any) that appeared in the control
directive.  In the case of an C<IF> directive with an
C<ELSE> block, the compiled template for the else block is
stored as C<esub>.

=back

For example, this template:

  %% NMS email template file %%
  Today is {= date =}, you are {= env.REMOTE_USER =} and
  your inputs were:
  {= FOREACH input_field =}
  {= name =}: {= value =}
  {= END =}
  {= IF param.hello =}Hello!{= ELSE =}Goodbye!{= END =}
  ----

Would compile to the array ref:

  [
    "Today is ",
    \'date',
    ", you are ",
    \'env.REMOTE_USER',
    " and\n",
    "your inputs were:\n",
    {
      'ctl' => 'FOREACH'
      'arg' => 'input_field',
      'sub' => [ \'name', ": ", \'value', "\n" ],
    },
    "----\n",
    {
      'ctl'  => 'IF',
      'arg'  => 'param.hello',
      'sub'  => [ 'Hello!' ],
      'esub' => [ 'Goodbye!' ],
    },
  ]

Returns the compiled template as an array ref, or dies on
error.

=cut

sub _compile_template
{
   my ($self, $template, $context) = @_;

   my @lines;
   if ($template =~ /%/)
   {
      # An inline template as a string
      @lines = map { /^%(.*)/ ? ("$1\n") : () } split /\n/, $template;
   }
   else
   {
      # The name of a template in an external file
      my $fh = $self->_open_file($template, "$context template");
      @lines = <$fh>;
      $fh->close;
   }

   my $compiled = [];
   my @stack = ($compiled);

   local $_;
   foreach(@lines)
   {
      # Ditch trailing whitespace, in particular get rid of the spare \r
      # if the template had \r\n line termination.
      s#\s+$#\n#;

      # Produce no output for a control directive alone on a line
      s#^ \s* (\{\= \s*[A-Z]+\s*[\s\w\-\.]+ \=\}) \n#$1#x;

      while ( s#(.*?) \{\= \s* (.*?) \s* \=\} ##x )
      {
         my ($pre, $directive) = ($1, $2);
         push @{ $stack[0] }, $pre if length $pre;
         if ($directive =~ s/^(FOREACH|IF)\s*//)
         {
            my $sub = [];
            push @{ $stack[0] }, { 'ctl' => $1,
                                   'arg' => $directive,
                                   'sub' => $sub
                                 };
            unshift @stack, $sub;
         }
         elsif ($directive =~ /^END$/i)
         {
            shift @stack;
            die 'misplaced END directive' unless scalar @stack;
         }
         elsif ($directive =~ /^ELSE$/i)
         {
            shift @stack;
            die 'misplaced ELSE directive' unless scalar @stack;

            my $if = ${ $stack[0] }[-1];
            die 'ELSE outside IF' unless $if->{ctl} eq 'IF';
            die 'only one ELSE per IF' if exists $if->{esub};

            my $esub = [];
            $if->{esub} = $esub;
            unshift @stack, $esub;
         }
         else
         {
            push @{ $stack[0] }, \$directive;
         }
      }

      push @{ $stack[0] }, $_ if length;
   }

   return $compiled;
}

=item _run_template ( TEMPLATE, CONTEXT, CODEREF )

Runs a pre-compiled template, and dies on error.

The TEMPLATE parameter must be a compiled template, as
returned by the _compile_template() method.  CONTEXT is
the context string and CODEREF is the output destination
coderef.

=cut

sub _run_template
{
   my ($self, $template, $context, $coderef) = @_;

   foreach my $part (@$template)
   {
      if (ref $part eq 'HASH')
      {
         if ($part->{ctl} eq 'FOREACH')
         {
            my $vals = $self->{'foreach'}{$part->{arg}};
            defined $vals or die "[$part->{arg}] cannot be used in a FOREACH directive";
   
            foreach my $val (@$vals)
            {
               foreach my $k (keys %$val)
               {
                  $self->install_directive($k, $val->{$k});
               }
               $self->_run_template($part->{'sub'}, $context, $coderef);
               foreach my $k (keys %$val)
               {
                  $self->uninstall_directive($k);
               }
            }
         }
         elsif ($part->{ctl} eq 'IF')
         {
            my $val = '';
            my $callback = sub { $val .= $_[0] };
            $self->_interpolate($part->{arg}, $context, $callback);
            if ($val)
            {
               $self->_run_template($part->{'sub'}, $context, $coderef);
            }
            elsif (exists $part->{'esub'})
            {
               $self->_run_template($part->{'esub'}, $context, $coderef);
            }
         }
         else
         {
            die "[$part->{ctl}] unsupported";
         }
      }
      elsif (ref $part eq 'SCALAR')
      {
         $self->_interpolate($$part, $context, $coderef);
      }
      elsif (length $part)
      {
         &{ $coderef }($part);
      }
   }
}

=item _interpolate ( DIRECTIVE, CONTEXT, CODEREF )

Resolves a single template directive in context CONTEXT
and outputs the result via the coderef CODEREF.  DIRECTIVE
is the string found between the template directive
delimiters, with leading and trailing whitespace removed.

=cut

sub _interpolate
{
   my ($self, $directive, $context, $coderef) = @_;

   my $data_src = $self->{r};
   while ($directive =~ s#^(\w+)\.##)
   {
      $data_src = $data_src->{$1};
      defined $data_src or return;
      ref $data_src eq 'HASH' or return;
   }

   my $value = $data_src->{$directive};
   defined $value or return;

   if (ref $value eq 'CODE')
   {
      $value = &{ $value }($self, $context, $coderef);
   }

   if (ref $value)
   {
      return unless ref $value eq 'SCALAR';
      # reference to value means don't munge value, see install_directive()
      $value = $$value;
   }
   else
   {
      if ($context eq 'html')
      {
         $value = $self->escape_html($value);
      }
      elsif ($context eq 'email')
      {
         # Disable HTML tags with minimum impact
         $value =~ s#<([a-z])#< $1#gi;
   
         # Don't allow multiline inputs to control the first
         # character of the line.
         $value =~ s#(\r|\n)(\S)#$1 $2#g;
   
         # Could be trying to fake a MIME boundary.
         $value =~ s/------/ ------/g;
      }
      else
      {
         $self->error("unknown template context [$context]");
      }
   }

   &{ $coderef }($value) if length $value;
   return;
}

=item _interpolate_date ( CONTEXT, CODEREF )

Resolves a C<date> template directive. Will use the date_fmt config to
determine the format of the date and locale item if present to localize
appropriate parts of the date string.

=cut

sub _interpolate_date
{
   my ($self, $context, $coderef) = @_;

   my $date_fmt = $self->{r}{'config'}{date_fmt};
   
   my $old_locale;

   
   if ( my $locale = $self->config('locale') )
   {
      $old_locale = POSIX::setlocale( LC_TIME );
      POSIX::setlocale(LC_TIME, $locale );
   }

   defined $date_fmt or $date_fmt = $self->{opt}{DateFormat};

   my $date = strftime $date_fmt, localtime;

   if ( $self->config('locale',0) )
   {
      POSIX::setlocale(LC_TIME, $old_locale);
   }
    
   # cache so that all date directives in a single request get the
   # same date.
   $self->{r}{date} = $date;

   return $date;
}

=item _dest_to_coderef ( DEST )

Converts a template output destination (which can be a
coderef, a file glob or an object reference) into a
coderef.

=cut

sub _dest_to_coderef
{
   my ($self, $dest) = @_;

   if (ref $dest eq 'CODE')
   {
      return $dest;
   }
   elsif (ref $dest eq 'GLOB')
   {
      return sub { print $dest $_[0] or $self->error("write failed: $!") };
   }
   else
   {
      return sub { $dest->print($_[0]) or $self->error("print failed: $!") };
   }
}

=item _read_config_file ( CONFIG_FILE )

Reads in and interprets the configuration file CONFIG_FILE,
which must be the path to a config file, relative to
the configuration root and without the file extension.

On success, returns a reference to a hash of configuration
settings.

On failure, invokes the non-returning error() method.

=cut

sub _read_config_file
{
   my ($self, $cfg_file) = @_;

   my $fh = $self->_open_file($cfg_file, 'configuration');

   my %config = ();
   my $key = '**NOKEY**';
   local $_;
   while(<$fh>)
   {
      next if m%^\s*(#|$)%;
      $key = $1 if s#^(\w+):##;
      s#^\s*##;
      s#\s*$##;
      next unless length;
      $config{$key} = (defined $config{$key} ? "$config{$key}\n$_" : $_);
   }
   delete $config{'**NOKEY**'};

   $fh->close;
   return \%config;
}

=item _open_file ( FILENAME, FILETYPE )

Checks that FILENAME is a valid relative file path without
file extension for a template or configuration file, opens
the file, checks that it has the correct header line and
returns an C<IO::File> object from which the remainder of
the file can be read.

The FILETYPE parameter should be one of the following
strings: "configuration", "S<html template>" or
"S<email template>".

Calls the non-returning error() method if anything goes
wrong.

=cut

sub _open_file
{
   my ($self, $filename, $filetype) = @_;


   unless ( $filename =~ m#^[a-zA-Z0-9]# and
            $filename =~ m#[a-zA-Z0-9]$# and
            $filename =~ m#^([/a-zA-Z0-9_]{1,100})$# )
   {
      $self->error("Invalid character in filename [$filename]");
   }
   $filename = $1;

   $filename =~ s#/+#/#g;
   my $slashcount = $filename =~ tr#/##;

   if ($slashcount > $self->{opt}{MaxDepth})
   {
      $self->error("$filetype filename [$filename] contains too many '/' characters");
   }

   my $ext;
   if ( $filetype eq 'configuration' )
   {
      $ext = $self->{opt}{ConfigExt};
   }
   elsif ( $filetype =~ / template$/ )
   {
      $ext = $self->{opt}{TemplateExt};
   }
   else
   {
      error("bad file type [$filetype]");
   }

   my $path = "$self->{opt}{ConfigRoot}/$filename$ext";

   my $file_exists = -f $path;

   if ( $filetype =~ / template$/ and ! $file_exists)
   {
      $path = "$self->{r}{config_path}/$filename$ext";
      $file_exists = -f $path; 
   }

   if ( !$file_exists)
   {
      $self->error("$filetype file not found: [$filename]");
   }

   my $fh = IO::File->new("<$path");
   unless (defined $fh)
   {
      $self->error("failed to open $filetype file [$filename] ($!)");
   }

   my $header = <$fh>;
   unless (defined $header and
           $header =~ m#^\%\% NMS \Q$filetype\E file \%\%\s*$#)
   {
      $self->error("$filetype file [$filename]: invalid header line [$header]");
   }

   return $fh;
}

=back

=cut

1;

__END__

=head1 CONFIGURATION FILE SYNTAX

Each configuration file sets values for a set of named keys.

The key names can consist of word characters only.  The
values can contain any character, but whitespace sequences
at the start and end of each line will be discarded when
the configuration file is parsed.

The first line of the template file must be the exact text:

  %% NMS configuration file %%

Lines starting with '#' are ignored.  Whitespace can
precede the '#' character.

Any set of one or more word characters followed by a ':'
character at the start of a line introduces a new key.  All
text until another key is introduced becomes the value for
that key.

If a key appears more than once then the values will be
joined using a space character as a delimiter.

For example:

  %% NMS configuration file %%
  #
  # This is an example of a configuration file.  It assigns
  # the value "one two three four" to key 'foo' and the value
  # "1   2 3 4" to key 'bar'.
  #

  foo: one two
       # This is an indented comment
       three

  bar: 1   2
  bar:3 4

  foo:
       four

=head1 TEMPLATE FILE SYNTAX

The first line of any template file must be either:

  %% NMS html template file %%

or

  %% NMS email template file %%

depending on the context in which the template is to be used.

All other lines in the template will be copied to the output
with template directives replaced by the corresponding data
values.  Template directives consist of the string "{=",
optional whitespace, the directive name, optional whitespace,
and the string "=}".  The directive names can be simple words
such as "date" or constructs such as "param.foo".

Template directives may not be split over multiple lines.

Here is an example of an HTML template:

  %% NMS html template file %%
  <?xml version="1.0" encoding="iso-8859-1"?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml">
   <head>
    <title>{= config.html_title =}</title>
   </head>
   <body>
    <h1>{= config.html_title =}</h1>
    <p>
     Hello, the date is {= date =} and your user agent is
     <i>{= env.HTTP_USER_AGENT =}</i>.
    </p>
    <p>
     You put <b>{= param.foo =}</b> in the <b>foo</b> input.
    </p>
   </body>
  </html>

The directives that can be used are:

=over

=item C<config.*>

The C<config.html_title> directive draws the title for the
document from a value set in the configuration file, allowing
different configuration files to use this template with
different titles.  Any configuration value can be substituted
in this way.

=item C<opt.*>

The C<opt.*> directive (not used in this example) substitutes
values passed to the C<NMStreq> object's constructor into
the output document.

=item C<env.*>

The C<env.*> directive substitutes the values of environment
variables.  Any non-printable characters will be removed
from the values using the strip_nonprintable() method.

=item C<param.*>

The C<param.*> directive substitutes the values of CGI
parameters.  Any non-printable characters will be removed
from the values using the strip_nonprintable() method.

=item C<date>

The C<date> directive outputs the current date, formatted
according to the C<date_fmt> configuration setting.

=back

=head1 SEE ALSO

L<NMSCharset>, L<CGI>

=head1 MAINTAINERS

The NMS project, E<lt>http://nms-cgi.sourceforge.net/E<gt>

To request support or report bugs, please email
E<lt>nms-cgi-support@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2002 - 2004 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

