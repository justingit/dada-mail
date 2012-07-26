#!/usr/bin/perl

##++
##     CGI Lite v2.02
##     Last modified: 18 Aug 2003 (Smylers - see CHANGES)
##
##     Copyright (c) 1995, 1996, 1997 by Shishir Gundavaram
##     All Rights Reserved
##
##     Permission  to  use,  copy, and distribute is hereby granted,
##     providing that the above copyright notice and this permission
##     appear in all copies and in supporting documentation.
##--

###############################################################################

=head1 NAME

CGI::Lite - Process and decode WWW forms and cookies

=head1 SYNOPSIS

    use CGI::Lite;

    $cgi = new CGI::Lite;

    $cgi->set_platform ($platform);
    
        where $platform can be one of (case insensitive):
        Unix, Windows, Windows95, DOS, NT, PC, Mac or Macintosh

    $cgi->set_file_type ('handle' or 'file');
    $cgi->add_timestamp (0, 1 or 2);	

        where 0 = no timestamp
              1 = timestamp all files (default)
              2 = timestamp only if file exists

    $cgi->filter_filename (\&subroutine);

    $size = $cgi->set_buffer_size ($some_buffer_size);

    $status = $cgi->set_directory ('/some/dir');
    $cgi->set_directory ('/some/dir') || die "Directory doesn't exist.\n";

    $cgi->close_all_files;

    $cgi->add_mime_type ('application/mac-binhex40');
    $status = $cgi->remove_mime_type ('application/mac-binhex40');
    @list = $cgi->get_mime_types;

    $form = $cgi->parse_form_data;
    %form = $cgi->parse_form_data;

    or

    $form = $cgi->parse_form_data ('GET', 'HEAD' or 'POST');

    $cookies = $cgi->parse_cookies;
    %cookies = $cgi->parse_cookies;

    $status  = $cgi->is_error;
    $message = $cgi->get_error_message;

    $cgi->return_error ('error 1', 'error 2', ...);

    $keys = $cgi->get_ordered_keys;
    @keys = $cgi->get_ordered_keys;

    $cgi->print_data;

    $cgi->print_form_data;   (deprecated as of v1.8)
    $cgi->print_cookie_data; (deprecated as of v1.8)

    $new_string = $cgi->wrap_textarea ($string, $length);

    @all_values = $cgi->get_multiple_values ($reference);

    $cgi->create_variables (\%form);
    $cgi->create_variables ($form);

    $escaped_string = browser_escape ($string);

    $encoded_string = url_encode ($string);
    $decoded_string = url_decode ($string);

    $status = is_dangerous ($string);
    $safe_string = escape_dangerous_chars ($string); # ***use is discouraged***

=head1 DESCRIPTION

You can use this module to decode form and query information,
including file uploads, as well as cookies in a very simple 
manner; you need not concern yourself with the actual details 
behind the decoding process. 

=head1 METHODS

Here are the methods you can use to process your forms and cookies:

=over 4

=item B<parse_form_data>

This will handle the following types of requests: GET, HEAD and POST.
By default, CGI::Lite uses the environment variable REQUEST_METHOD to 
determine the manner in which the query/form information should be 
decoded. However, as of v1.8, you are allowed to pass a valid request 
method to this function to force CGI::Lite to decode the information in 
a specific manner. 

For multipart/form-data, uploaded files are stored in the user selected 
directory (see B<set_directory>). If timestamp mode is on (see 
B<add_timestamp>), the files are named in the following format:

    timestamp__filename

where the filename is specified in the "Content-disposition" header.
I<NOTE:>, the browser URL encodes the name of the file. This module
makes I<no> effort to decode the information for security reasons.
However, you can do so by creating a subroutine and then using
the B<filter_filename> method.

I<Return Value>

Returns either a hash or a reference to the hash, which contains
all of the key/value pairs. For fields that contain file information,
the value contains either the path to the file, or the filehandle 
(see the B<set_file_type> method).

=item B<parse_new_form_data>

As for parse_form_data, but clears the CGI object state before processing 
the request. This is useful in persistant application (e.g. FCGI), where
the CGI object is reused for multiple requests. e.g.

	$CGI = new CGI::Lite;
	while (FCGI::accept > 0)
	{
		$Query = $CGI->parse_new_form_data();
		<process query>
	}

=item B<parse_cookies>

Decodes and parses cookies passed by the browser. This method works in 
much the same manner as B<parse_form_data>. 

=item B<is_error>

As of v1.8, errors in parsing are handled differently. You can use this
method to check for any potential errors after you've called either
B<parse_form_data> or B<parse_cookies>.

I<Return Value>

    0 Success
    1 Failure

=item B<get_error_message>

If an error occurs when parsing form/query information or cookies, you
can use this method to retrieve the error message. Remember, you can
check for errors by calling the B<is_error> method.

I<Return Value>

The error message.

=item B<return_error>

You can use this method to return errors to the browser and exit. 

=item B<set_platform>

You can use this method to set the platform on which your Web server
is running. CGI::Lite uses this information to translate end-of-line 
(EOL) characters for uploaded files (see the B<add_mime_type> and
B<remove_mime_type> methods) so that they display properly on that
platform.

You can specify either (case insensitive):

    Unix                                  EOL: \012      = \n
    Windows, Windows95, DOS, NT, PC       EOL: \015\012  = \r\n
    Mac or Macintosh                      EOL: \015      = \r

"Unix" is the default.

=item B<set_directory>

Used to set the directory where the uploaded files will be stored 
(only applies to the I<multipart/form-data> encoding scheme).

This function should be called I<before> you call B<parse_form_data>, 
or else the directory defaults to "/tmp". If the application cannot 
write to the directory for whatever reason, an error status is returned.

I<Return Value>

    0  Failure
    1  Success

=item B<close_all_files>

All uploaded files that are opened as a result of calling B<set_file_type>
with the "handle" argument can be closed in one shot by calling this
method.

=item B<add_mime_type>

By default, EOL characters are translated for all uploaded files
with specific MIME types (i.e text/plain, text/html, etc.). You
can use this method to add to the list of MIME types. For example,
if you want CGI::Lite to translate EOL characters for uploaded
files of I<application/mac-binhex40>, then you would do this:

    $cgi->add_mime_type ('application/mac-binhex40');

=item B<remove_mime_type>

This method is the converse of B<add_mime_type>. It allows you to 
remove a particular MIME type. For example, if you do not want 
CGI::Lite to translate EOL characters for uploaded files of I<text/html>, 
then you would do this:

    $cgi->remove_mime_type ('text/html');

I<Return Value>

    0  Failure
    1  Success

=item B<get_mime_types>

Returns the list, either as a reference or an actual list, of the 
MIME types for which EOL translation is performed.

=item B<set_file_type>

The I<names> of uploaded files are returned by default, when you call
the B<parse_form_data> method. But,  if pass the string "handle" to this 
method, the I<handles> to the files are returned. However, the name
of the handle corresponds to the filename.

This function should be called I<before> you call B<parse_form_data>, or 
else it will not work.

=item B<add_timestamp>

By default, a timestamp is added to the front of uploaded files. 
However, you have the option of completely turning off timestamp mode
(value 0), or adding a timestamp only for existing files (value 2).

=item B<filter_filename>

You can use this method to change the manner in which uploaded
files are named. For example, if you want uploaded filenames
to be all upper case, you can use the following code:

    $cgi->filter_filename (\&make_uppercase);
    $cgi->parse_form_data;

    .
    .
    .

    sub make_uppercase
    {
        my $file = shift;

        $file =~ tr/a-z/A-Z/;
        return $file;
    }

=item B<set_buffer_size>

This method allows you to set the buffer size when dealing with multipart 
form data. However, the I<actual> buffer size that the algorithm uses 
I<can> be up to 3x the value you specify. This ensures that boundary 
strings are not "split" between multiple reads. So, take this into 
consideration when setting the buffer size.

You cannot set a buffer size below 256 bytes and above the total amount 
of multipart form data. The default value is 1024 bytes. 

I<Return Value>

The buffer size.

=item B<get_ordered_keys>

Returns either a reference to an array or an array itself consisting
of the form fields/cookies in the order they were parsed.

I<Return Value>

Ordered keys.

=item B<print_data>

Displays all the key/value pairs (either form data or cookie information)
in a ordered fashion. The methods B<print_form_data> and B<print_cookie_data>
are deprecated as of version v1.8, and will be removed in future versions.

=item B<print_form_data>

Deprecated as of v1.8, see B<print_data>.

=item B<print_cookie_data> (deprecated as of v1.8)

Deprecated as of v1.8, see B<print_data>.

=item B<wrap_textarea>

You can use this function to "wrap" a long string into one that is 
separated by a combination of carriage return and newline (see 
B<set_platform>) at fixed lengths.  The two arguments that you need to 
pass to this method are the string and the length at which you want the 
line separator added.

I<Return Value>

The modified string.

=item B<get_multiple_values>

One of the major changes to this module as of v1.7 is that multiple
values for a single key are returned as an reference to an array, and 
I<not> as a string delimited by the null character ("\0"). You can use 
this function to return the actual array. And if you pass a scalar 
value to this method, it will simply return that value.

There was no way I could make this backward compatible with versions
older than 1.7. I apologize!

I<Return Value>

Array consisting of the multiple values.

=item B<create_variables>

Sometimes, it is convenient to have scalar variables that represent
the various keys in a hash. You can use this method to do just that.
Say you have a hash like the following:

    %form = ('name'   => 'shishir gundavaram',
	     'sport'  => 'track and field',
	     'events' => '100m');

If you call this method in the following manner:

    $cgi->create_variables (\%hash);

it will create three scalar variables: $name, $sport and $events. 
Convenient, huh? 

=item B<browser_escape>

Certain characters have special significance to the browser. These
characters include: "<" and ">". If you want to display these "special"
characters, you need to escape them using the following notation:

    &#ascii;

This method does just that.

I<Return Value>

Escaped string.

=item B<url_encode>

This method will URL encode a string that you pass it. You can use this
to encode any data that you wish to pass as a query string to a CGI
application.

I<Return Value>

URL encoded string.

=item B<url_decode>

You can use this method to URL decode a string. 

I<Return Value>

URL decoded string.

=item B<is_dangerous>

This method checks for the existence of dangerous meta-characters.

I<Return Value>

    0 Safe
    1 Dangerous

=item B<escape_dangerous_chars>

You can use this method to "escape" any dangerous meta-characters. The
use of this function is strongly discouraged. See
http://use.perl.org/~cbrooks/journal/10542 and
http://msgs.securepoint.com/cgi-bin/get/bugtraq0302/94.html for an
advisory by Ronald F. Guilmette. Ronald's patch to make this function
more safe is applied, but as has been pointed out on the bugtraq
mailing list, it is still much better to run no external shell at all
when executing commands. Please read the advisory and the WWW security
FAQ.

I<Return Value>

Escaped string.

=back

=head1 SEE ALSO

If you're looking for more comprehensive CGI modules, you can either 
use the CGI::* modules or CGI.pm. Both are maintained by Dr. Lincoln
Stein I<(lstein@genome.wi.mit.edu)> and can be found at your local
CPAN mirror and at his Web site:

I<http://www-genome.wi.mit.edu/WWW/tools/scripting>

=head1 MAINTAINER

Maintenance of this module has now been taken over by Smylers
<smylers@cpan.org>.

=head1 ACKNOWLEDGMENTS

The author thanks the following for finding bugs and offering suggestions:

=over 4

=item Eric D. Friedman (friedman@uci.edu)   

=item Thomas Winzig (tsw@pvo.com)

=item Len Charest (len@cogent.net)

=item Achim Bohnet (ach@rosat.mpe-garching.mpg.de)

=item John E. Townsend (John.E.Townsend@BST.BLS.com)

=item Andrew McRae (mcrae@internet.com)

=item Dennis Grant (dg50@chrysler.com)

=item Scott Neufeld (scott.neufeld@mis.ussurg.com)

=item Raul Almquist (imrs@ShadowMAC.org)

=item and many others!

=back

=head1 COPYRIGHT INFORMATION
    
     Copyright (c) 1995, 1996, 1997 by Shishir Gundavaram
                     All Rights Reserved

 Permission to use, copy, and  distribute  is  hereby granted,
 providing that the above copyright notice and this permission
 appear in all copies and in supporting documentation.

=cut

###############################################################################

package CGI::Lite;
require 5.002;
require Exporter;

@ISA    =    (Exporter);
@EXPORT = qw (browser_escape
              url_encode
              url_decode
              is_dangerous
              escape_dangerous_chars);

##++
## Global Variables
##--

$CGI::Lite::VERSION = '2.02';

##++
##  Start
##--

sub new
{
    my $self;

    $self = {
	        multipart_dir    =>    undef,
	        default_dir      =>    '/tmp',
	        file_type        =>    'name',
	        platform         =>    'Unix',
	        buffer_size      =>    1024,
	        timestamp        =>    1,
		filter           =>    undef,
	        web_data         =>    {},
		ordered_keys     =>    [],
		all_handles      =>    [],
	        error_status     =>    0,
	        error_message    =>    undef,
		file_size_limit	 =>    2097152,
	    };

    $self->{convert} = { 
	                   'text/html'    => 1,
	                   'text/plain'   => 1
	               };

    $self->{file} = { Unix => '/',    Mac => ':',    PC => '\\'       };
    $self->{eol}  = { Unix => "\012", Mac => "\015", PC => "\015\012" };

    bless $self;
    return $self;
}

sub Version 
{ 
    return $VERSION;
}

sub set_directory
{
    my ($self, $directory) = @_;

    stat ($directory);

    if ( (-d _) && (-e _) && (-r _) && (-w _) ) {
	$self->{multipart_dir} = $directory;
	return (1);

    } else {
	return (0);
    }
}

sub add_mime_type
{
    my ($self, $mime_type) = @_;

    $self->{convert}->{$mime_type} = 1 if ($mime_type);
}

sub remove_mime_type
{
    my ($self, $mime_type) = @_;

    if ($self->{convert}->{$mime_type}) {
	delete $self->{convert}->{$mime_type};
	return (1);

    } else {
	return (0);
    }
}

sub get_mime_types
{
    my $self = shift;

    return (sort keys %{ $self->{convert} });
}

sub set_platform
{
    my ($self, $platform) = @_;

    if ($platform =~ /(?:PC|NT|Windows(?:95)?|DOS)/i) {
        $self->{platform} = 'PC';

    } elsif ($platform =~ /Mac(?:intosh)?/i) {

	## Should I check for NeXT here :-)

        $self->{platform} = 'Mac';

    } else {
	$self->{platform} = 'Unix';
    }
}

sub set_file_type
{
    my ($self, $type) = @_;

    if ($type =~ /^handle$/i) {
	$self->{file_type} = 'handle';
    } else {
	$self->{file_type} = 'name';
    }
}

sub add_timestamp
{
    my ($self, $value) = @_;

    if ( ($value < 0) || ($value > 2) ) {
	$self->{timestamp} = 1;
    } else {
	$self->{timestamp} = $value;
    }
}

sub filter_filename
{
    my ($self, $subroutine) = @_;

    $self->{filter} = $subroutine;
}

sub set_buffer_size
{
    my ($self, $buffer_size) = @_;
    my $content_length;

    $content_length = $ENV{CONTENT_LENGTH} || return (0);

    if ($buffer_size < 256) {
	$self->{buffer_size} = 256;
    } elsif ($buffer_size > $content_length) {
	$self->{buffer_size} = $content_length;
    } else {
	$self->{buffer_size} = $buffer_size;
    }

    return ($self->{buffer_size});
}

sub parse_new_form_data
# Reset state before parsing (for persistant CGI objects, e.g. under FastCGI) 
# BDL
{
	my ($self, @param) = @_;

	# close files (should happen anyway when 'all_handles' is cleared...)
	$self->close_all_files();

	$self->{web_data}	= {};
	$self->{ordered_keys} 	= [];
	$self->{all_handles} 	= [];
	$self->{error_status} 	= 0;
	$self->{error_message} 	= undef;

	$self->parse_form_data(@param);
}

sub parse_form_data
{
    my ($self, $user_request) = @_;
    my ($request_method, $content_length, $content_type, $query_string,
	$boundary, $post_data, @query_input);

    $request_method = $user_request || $ENV{REQUEST_METHOD} || '';
    $content_length = $ENV{CONTENT_LENGTH};
    $content_type   = $ENV{CONTENT_TYPE};

    if ($request_method =~ /^(get|head)$/i) {

	$query_string = $ENV{QUERY_STRING};
	$self->_decode_url_encoded_data (\$query_string, 'form');

	return wantarray ?
	    %{ $self->{web_data} } : $self->{web_data};

    } elsif ($request_method =~ /^post$/i) {

	if (!$content_type || 
	    ($content_type eq 'application/x-www-form-urlencoded')) {

	    local $^W = 0;

	    read (STDIN, $post_data, $content_length);
	    $self->_decode_url_encoded_data (\$post_data, 'form');

	    return wantarray ? 
		%{ $self->{web_data} } : $self->{web_data};

	} elsif ($content_type =~ /multipart\/form-data/) {
	    ($boundary) = $content_type =~ /boundary=(\S+)$/;
	    $self->_parse_multipart_data ($content_length, $boundary);

	    return wantarray ? 
		%{ $self->{web_data} } : $self->{web_data};

	} else {
	    $self->_error ('Invalid content type!');
	}

    } else {

	##++
	##  Got the idea of interactive debugging from CGI.pm, though it's
        ##  handled a bit differently here. Thanks Lincoln!
	##--

	print "[ Reading query from standard input. Press ^D to stop! ]\n";

	@query_input = <>;
	chomp (@query_input);

	$query_string = join ('&', @query_input);
	$query_string =~ s/\\(.)/sprintf ('%%%02X', ord ($1))/eg;
 
	$self->_decode_url_encoded_data (\$query_string, 'form');

	return wantarray ?
	    %{ $self->{web_data} } : $self->{web_data};
    }
}

sub parse_cookies
{
    my $self = shift;
    my $cookies;

    $cookies = $ENV{HTTP_COOKIE} || return;

    $self->_decode_url_encoded_data (\$cookies, 'cookies');

    return wantarray ? 
        %{ $self->{web_data} } : $self->{web_data};
}

sub get_ordered_keys
{
    my $self = shift;

    return wantarray ?
	@{ $self->{ordered_keys} } : $self->{ordered_keys};
}

sub print_data
{
    my $self = shift;
    my ($key, $value, $eol);

    $eol = $self->{eol}->{$self->{platform}};

    foreach $key (@{ $self->{ordered_keys} }) {
	$value = $self->{web_data}->{$key};

	if (ref $value) {
	    print "$key = @$value$eol";
	} else {
	    print "$key = $value$eol";
	}
    }
}

sub print_mime_type
{
    my ($self, $field) = @_;

    return($self->{'mime_types'}->{$field});
}

*print_form_data = *print_cookie_data = \&print_data;

sub wrap_textarea
{
    my ($self, $string, $length) = @_;
    my ($new_string, $platform, $eol);

    $length     = 70 unless ($length);
    $platform   = $self->{platform};
    $eol        = $self->{eol}->{$platform};
    $new_string = $string || return;
	
    $new_string =~ s/[\0\r]\n?/ /sg;
    $new_string =~ s/(.{0,$length})\s/$1$eol/sg;

    return $new_string;
}

sub get_multiple_values
{
    my ($self, $array) = @_;

    return (ref $array) ? (@$array) : $array;
}

sub create_variables
{
    my ($self, $hash) = @_;
    my ($package, $key, $value);
    
    $package = $self->_determine_package;

    while (($key, $value) = each %$hash) {
	${"$package\:\:$key"} = $value;
    }
}

sub is_error
{
    my $self = shift;

    if ($self->{error_status}) {
	return (1);
    } else {
	return (0);
    }
}

sub get_error_message
{
    my $self = shift;

    return $self->{error_message} if ($self->{error_message});
}

sub return_error
{
    my ($self, @messages) = @_;

    print "@messages\n";

    exit (1);
}

##++
##  Exported Subroutines
##--

sub browser_escape
{
    my $string = shift;

    $string =~ s/([<&"#%>])/sprintf ('&#%d;', ord ($1))/ge;

    return $string;
}

sub url_encode
{
    my $string = shift;

    $string =~ s/([^-.\w ])/sprintf('%%%02X', ord $1)/ge;
    $string =~ tr/ /+/;

    return $string;
}

sub url_decode
{
    my $string = shift;

    $string =~ tr/+/ /;
    $string =~ s/%([\da-fA-F]{2})/chr (hex ($1))/eg;

    return $string;
}

sub is_dangerous
{
    my $string = shift;

    if ($string =~ /[;<>\*\|`&\$!#\(\)\[\]\{\}:'"]/) {
        return (1);
    } else {
        return (0);
    }
}

sub escape_dangerous_chars
{
    my $string = shift;

    warn "escape_dangerous_chars() possibly dangerous. Its use is discouraged";
    $string =~ s/([;<>\*\|`&\$!#\(\)\[\]\{\}:'"\\\?\~\^\r\n])/\\$1/g;

    return $string;
}

##++
##  Internal Methods
##--

sub _error
{
    my ($self, $message) = @_;

    $self->{error_status}  = 1;
    $self->{error_message} = $message;
}

sub _determine_package
{
    my $self = shift;
    my ($frame, $this_package, $find_package);

    $frame = -1;
    ($this_package) = split (/=/, $self);

    do {
	$find_package = caller (++$frame);
    } until ($find_package !~ /^$this_package/);

    return ($find_package);
}   

##++
##  Decode URL encoded data
##--

sub _decode_url_encoded_data
{
    my ($self, $reference_data, $type) = @_;
    my $code;

    $code = <<'End_of_URL_Decode';

    my (@key_value_pairs, $delimiter, $key_value, $key, $value);

    @key_value_pairs = ();

    return unless ($$reference_data);

    if ($type eq 'cookies') {
	$delimiter = ';\s+';
    } else {
	$delimiter = '&';
    }

    @key_value_pairs = split (/$delimiter/, $$reference_data);
		
    foreach $key_value (@key_value_pairs) {
	($key, $value) = split (/=/, $key_value, 2);

	$value = '' unless defined $value;	# avoid 'undef' warnings for "key=" BDL Jan/99

	$key   = url_decode($key);
	$value = url_decode($value);
	
	if ( defined ($self->{web_data}->{$key}) ) {
	    $self->{web_data}->{$key} = [$self->{web_data}->{$key}] 
	        unless ( ref $self->{web_data}->{$key} );

	    push (@{ $self->{web_data}->{$key} }, $value);
	} else {
	    $self->{web_data}->{$key} = $value;
	    push (@{ $self->{ordered_keys} }, $key);
	}
    }

End_of_URL_Decode

    eval ($code);
    $self->_error ($@) if $@;
}

##++
##  Methods dealing with multipart data
##--

sub _parse_multipart_data
{
    my ($self, $total_bytes, $boundary) = @_;
    my ($code, $files);

    local $^W = 0;
    $files    = {};

    $code = <<'End_of_Multipart';

    my ($seen, $buffer_size, $byte_count, $platform, $eol, $handle, 
	$directory, $bytes_left, $buffer_size, $new_data, $old_data, 
	$current_buffer, $changed, $store, $disposition, $headers, 
        $mime_type, $convert, $field, $file, $new_name, $full_path);

    $seen        = {};
    $buffer_size = $self->{buffer_size};
    $byte_count  = 0;
    $platform    = $self->{platform};
    $eol         = $self->{eol}->{$platform};
    $handle      = 'CL00';
    $directory   = $self->{multipart_dir} || $self->{default_dir};

    while (1) {
	if ( ($byte_count < $total_bytes) &&
	     (length ($current_buffer) < ($buffer_size * 2)) ) {

	    $bytes_left  = $total_bytes - $byte_count;
	    $buffer_size = $bytes_left if ($bytes_left < $buffer_size);

	    read (STDIN, $new_data, $buffer_size);
            $self->_error ("Oh, Oh! I'm upset! Can't read what I want.")
		if (length ($new_data) != $buffer_size);

	    $byte_count += $buffer_size;

	    if ($old_data) {
		$current_buffer = join ('', $old_data, $new_data);
	    } else {
		$current_buffer = $new_data;
	    }

	} elsif ($old_data) {
	    $current_buffer = $old_data;
	    $old_data = undef;

	} else {
	    last;
	}

	$changed = 0;

	##++
	##  When Netscape Navigator creates a random boundary string, you
	##  would expect it to pass that _same_ value in the environment
	##  variable CONTENT_TYPE, but it does not! Instead, it passes a
	##  value that has the first two characters ("--") missing.
	##--

	if ($current_buffer =~ 
            /(.*?)(?:\015?\012)?-*$boundary-*[\015\012]*(?=(.*))/os) {

	    ($store, $old_data) = ($1, $2);

            if ($current_buffer =~ 
             /[Cc]ontent-[Dd]isposition: ([^\015\012]+)\015?\012  # Disposition
              (?:([A-Za-z].*?)(?:\015?\012){2})?                  # Headers
              (?:\015?\012)?                                      # End
              (?=(.*))                                            # Other Data
             /xs) {

		($disposition, $headers, $current_buffer) = ($1, $2, $3);
		$old_data = $current_buffer;

		($mime_type) = $headers =~ /[Cc]ontent-[Tt]ype: (\S+)/;

		$self->_store ($platform, $file, $convert, $handle, $eol, 
			       $field, \$store, $seen);

		close ($handle) if (fileno ($handle));

		if ($mime_type && $self->{convert}->{$mime_type}) {
		    $convert = 1;
		} else {
		    $convert = 0;
		}

		$changed = 1;

		($field) = $disposition =~ /name="([^"]+)"/;
		++$seen->{$field};

		$self->{'mime_types'}->{$field} = $mime_type;

                if ($seen->{$field} > 1) {
                    $self->{web_data}->{$field} = [$self->{web_data}->{$field}]
                        unless (ref $self->{web_data}->{$field});
                } else {
                    push (@{ $self->{ordered_keys} }, $field);
                }

                if (($file) = $disposition =~ /filename="(.*)"/) {
                    $file =~ s|.*[:/\\](.*)|$1|;

                    $new_name = $self->_get_file_name ($platform,
                                                       $directory, $file);

                    $self->{web_data}->{$field} = $new_name;

                    $full_path = join ($self->{file}->{$platform}, 
                                       $directory, $new_name);

                    open (++$handle, ">$full_path") 
	                || $self->_error ("Can't create file: $full_path!");

                    $files->{$new_name} = $full_path;
                } 
            }

	} elsif ($old_data) {
            $store    = $old_data;
            $old_data = $new_data;

	} else {
	    $store          = $current_buffer;
            $current_buffer = $new_data;
        }

        unless ($changed) {
           $self->_store ($platform, $file, $convert, $handle, $eol, 
                          $field, \$store, $seen);
        }
    }

    close ($handle) if (fileno ($handle));

End_of_Multipart

    eval ($code);
    $self->_error ($@) if $@;

    $self->_create_handles ($files) if ($self->{file_type} eq 'handle');
}

sub _store
{
    my ($self, $platform, $file, $convert, $handle, $eol, $field, 
	$info, $seen) = @_;

    if ($file) {
	if ($convert) {
	    $$info =~ s/\015\012/$eol/og  if ($platform ne 'PC');
	    $$info =~ s/\015/$eol/og      if ($platform ne 'Mac');
	    $$info =~ s/\012/$eol/og      if ($platform ne 'Unix');
	}

    	print $handle $$info;

    } elsif ($field) {
	if ($seen->{$field} > 1) {
	    $self->{web_data}->{$field}->[$seen->{$field}-1] .= $$info;
	} else {
	    $self->{web_data}->{$field} .= $$info;
        }
    }
}

sub _get_file_name
{
    my ($self, $platform, $directory, $file) = @_;
    my ($filtered_name, $filename, $timestamp, $path);

    $filtered_name = &{ $self->{filter} }($file)
        if (ref ($self->{filter}) eq 'CODE');

    $filename  = $filtered_name || $file;
    $timestamp = time . '__' . $filename;

    if (!$self->{timestamp}) {
	return $filename;

    } elsif ($self->{timestamp} == 1) {
	return $timestamp;
	
    } elsif ($self->{timestamp} == 2) {
	$path = join ($self->{file}->{$platform}, $directory, $filename);
	
	return (-e $path) ? $timestamp : $filename;
    }
}

sub _create_handles
{
    my ($self, $files) = @_;
    my ($package, $handle, $name, $path);

    $package = $self->_determine_package;

    while (($name, $path) = each %$files) {
	$handle = "$package\:\:$name";
	open ($handle, "<$path")
            || $self->_error ("Can't read file: $path!");

	push (@{ $self->{all_handles} }, $handle);
    }
}

sub close_all_files
{
    my $self = shift;
    my $handle;

    foreach $handle (@{ $self->{all_handles} }) {
	close $handle;
    }
}

1;

