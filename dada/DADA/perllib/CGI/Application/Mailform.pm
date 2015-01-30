
package CGI::Application::Mailform;

# Always use strict!
use strict;


# This is a CGI::Application module
use CGI::Application;
@CGI::Application::Mailform::ISA = qw/CGI::Application/;


# Required, but not enforced by Makefile.PL!
use Net::SMTP;
use Carp;



#############################################
##  OVERRIDE METHODS
##

# Run when new() is called
sub setup {
	my $self = shift;

	$self->mode_param('rm');
	$self->start_mode('showform');

	# Set up run-mode table.  In a typical CGI::Application module, this would
	# contain multiple run-modes -- one for each think your app can do.
	# We're using sub-ref instead of name-ref to display more intuitive errors.
	#
	$self->run_modes(
		'showform'   => \&redirect_to_mailform,
		'submitform' => \&submitform_and_sendmail,
	);
}


# Called when run() is called.
sub cgiapp_prerun {
	my $self = shift;
	my $runmode = shift;

	# Make sure the instance script is correct
	$self->validate_runtime();
}



#############################################
##  RUN-MODE METHODS
##

sub redirect_to_mailform {
	my $self = shift;

	# Set up the HTTP redirect
	my $redirect_url = $self->param('HTMLFORM_REDIRECT_URL');

	return $self->do_redirect($redirect_url);
}


sub submitform_and_sendmail {
	my $self = shift;

	# Actually send out the email message
	$self->sendmail();

	# Set up the HTTP redirect
	my $redirect_url = $self->param('SUCCESS_REDIRECT_URL');

	return $self->do_redirect($redirect_url);
}



#############################################
##  PRIVATE METHODS
##

# Perform an HTTP redirect
sub do_redirect {
	my $self = shift;
	my $redirect_url = shift;

	$self->header_type( 'redirect' );
	$self->header_props( -url => $redirect_url );

	# Return HTML to the web browser
	my $redirect_html = "Continue: <a href=\"$redirect_url\">$redirect_url</a>";
	return $redirect_html;
}


# This method is to verify that the instance script (i.e., "mailform.cgi")
# contains the correct configuration parameters.
sub validate_runtime {
	my $self = shift;

	## CHECK REQUIRED PARAMETERS
	#
	my $req_failed = 0;

	my @required_params = qw/
		MAIL_FROM 
		MAIL_TO 
		HTMLFORM_REDIRECT_URL 
		SUCCESS_REDIRECT_URL 
		FORM_FIELDS
	/;

	foreach my $req_param (@required_params) {
		# Check each req param to verify that it is there
		unless ( defined($self->param($req_param)) && length($self->param($req_param)) ) {
			$req_failed++;
			carp("Required parameter '$req_param' not specified");
		} else {
			# Especially check that FORM_FIELDS is an array-ref
			if (($req_param eq 'FORM_FIELDS') && (ref($self->param('FORM_FIELDS')) ne 'ARRAY')) {
				$req_failed++;
				carp("Required parameter 'FORM_FIELDS' is not an array reference");
			}
		}

	}

	# Die if we have an invalid run-time configuration
	croak("Missing or invalid required parameters") if ($req_failed);


	## CHECK OPTIONAL PARAMETERS / SET DEFAULT VALUES
	#
	my $opt_failed = 0;

	## ENV_FIELDS
	# If undefined, define as null
	$self->param('ENV_FIELDS', []) unless (defined($self->param('ENV_FIELDS')));

	# Now, check for validity
	unless (ref($self->param('ENV_FIELDS')) eq 'ARRAY') {
		$opt_failed++;
		carp("Parameter 'ENV_FIELDS' is not an array reference");
	}

	## SUBJECT
	my $subject = $self->param('SUBJECT');
	unless (defined($subject) && length($subject)) {
		$subject = 'Form submission from ' . ($ENV{HTTP_REFERER} || $ENV{SCRIPT_NAME});
		$self->param('SUBJECT', $subject);
	}

	## SMTP_HOST
	$self->param('SMTP_HOST', '') unless (defined($self->param('SMTP_HOST')));
	# Expect a scalar for SMTP_HOST.  Other values will be deemed errors, 
	# to prevent problems when interfacing with Net::SMTP.
	unless (ref($self->param('SMTP_HOST')) eq '') {
		$opt_failed++;
		carp("Parameter 'SMTP_HOST' is not a scalar");
	}

	# Die if we have an invalid run-time configuration
	croak("Invalid optional parameters") if ($opt_failed);
}


# Establish SMTP connection
sub connect_smtp {
	my $self = shift;

	my $smtp_host = $self->param('SMTP_HOST');

	my $smtp_connection;

	if (length($smtp_host)) {
		# Use provided host
		$smtp_connection = Net::SMTP->new($smtp_host);
		croak("Unable to connect to '$smtp_host'")
			unless (defined($smtp_connection));
	} else {
		# Use default host
		$smtp_connection = Net::SMTP->new();
		croak("Unable to establish SMTP connection")
			unless (defined($smtp_connection));
	}

	return $smtp_connection;
}


# This method actually generates and sends the email message via 
# SMTP, or die()s  trying.
sub sendmail {
	my $self = shift;

	# Get the CGI query object
	my $q = $self->query();

	my $mailfrom = $self->param('MAIL_FROM');
	my $mailto = $self->param('MAIL_TO');
	my $subject = $self->param('SUBJECT');

	# Get the message body
	my $msgbody = $self->build_msgbody();

	# Connect to SMTP server
	my $smtp_connection = $self->connect_smtp();

	# Here's where we "do the deed"...
	$smtp_connection->mail($mailfrom);
	$smtp_connection->to($mailto);

	# Enter data mode
	$smtp_connection->data();

	# Send the message content (header + body)
	$smtp_connection->datasend("From: $mailfrom\n");
	$smtp_connection->datasend("To: $mailto\n");
	$smtp_connection->datasend("Subject: $subject\n");
	$smtp_connection->datasend("\n");
	$smtp_connection->datasend($msgbody);
	$smtp_connection->datasend("\n");

	# Exit data mode
	$smtp_connection->dataend();


	# Be polite -- disconnect from the server!
	$smtp_connection->quit();
}


# Here's where the majority of the work gets done.
# Based on the settings in the instance script and
# the CGI form data, an email message body is created.
sub build_msgbody {
	my $self = shift;

	# Get the CGI query object
	my $q = $self->query();

	# The longest journey begins with a single step...
	my $msgbody = '';

	## Populate message body with form data
	#
	my $form_fields = $self->param('FORM_FIELDS');
	my $ff_count = 1;
	$msgbody .= "The following data has been submitted:\n\n";
	foreach my $field (@$form_fields) {
		$msgbody .= "$ff_count\. $field\:\n" . $self->clean_data($q->param($field)). "\n\n\n";
		$ff_count++;
	}
	$msgbody .= "\n";

	## Populate message body with environment data
	#
	my $env_fields = $self->param('ENV_FIELDS');
	# Do we actually have any env data requested?
	if (@$env_fields) {
		my $ef_count = 1;
		$msgbody .= "Form environment data:\n\n";
		foreach my $field (@$env_fields) {
			$msgbody .= "$ef_count\. $field\:\n" . $self->clean_data($ENV{$field}). "\n\n\n";
			$ef_count++;
		}
	}

	# Send back the complete message body
	return $msgbody;
}


# This method cleans up data for inclusion into the email message
sub clean_data {
	my $self = shift;
	my $field_data = shift;

	# Set undef strings to a null string
	$field_data = '' unless (defined($field_data));

	# Strip leading & trailing white space
	$field_data =~ s/^\s*//;
	$field_data =~ s/\s$//;

	# If we have no answer, put "[n/a]" in there.
	$field_data = '[n/a]' unless (length($field_data));

	return $field_data;
}





#############################################
##  POD
##

=pod

=head1 NAME

CGI::Application::Mailform -
A simple HTML form to email system


=head1 SYNOPSIS

  ## In "mailform.cgi" --
  use CGI::Application::Mailform;

  # Create a new Mailform instance...
  my $mf = CGI::Application::Mailform->new();

  # Configure your mailform
  $mf->param('MAIL_FROM'   => 'webmaster@your.domain');
  $mf->param('MAIL_TO'     => 'form_recipient@your.domain');
  $mf->param('HTMLFORM_REDIRECT_URL' => '/uri/or/url/to/mailform.html');
  $mf->param('SUCCESS_REDIRECT_URL'  => '/uri/or/url/to/thankyou.html');
  $mf->param('FORM_FIELDS' => [qw/name address comments etc/]);

  # Optional variables
  $mf->param('SMTP_HOST'   => 'mail.your.domain');
  $mf->param('SUBJECT'     => 'New form submission');
  $mf->param('ENV_FIELDS'  => [qw/REMOTE_ADDR HTTP_USER_AGENT/]);

  # Now run...
  $mf->run();
  exit(0);


 
  ## In "mailform.html" --
  <form action="mailform.cgi">
  <input type="hidden" name="rm" value="submitform">
  <!-- Your HTML form input fields here -->
  <input type="submit" name="submit">
  </form>



  ## In "thankyou.html" --
  <html><body>
    <h1>Thanks for your submission!  It has been sent.</h1>
  </body></html>



=head1 DESCRIPTION

CGI::Application::Mailform is a reusable and customizable mailform
for the web.  It is intentionally simple, and provides very few facilities.
What it does do is provide an easy-to-use, secure system for taking the contents 
of a HTML form submission and sending it, via email, to a specified recipient.

This module was created as an example of how to use CGI::Application, a 
framework for creating reusable web-based applications.  In addition to 
providing a simple example of CGI::Application's usage, 
CGI::Application::Mailform is also a fully functional application, 
capable of running in a production environment.

Just as is the case with any web-application built upon CGI::Application, 
CGI::Application::Mailform will run on any web server and operating system
which supports the Common Gateway Interface (CGI).  It will run equally
well on Apache as it runs on IIS or the iPlanet server.  It will run
perfectly well on UNIX, Linux, Solaris or Windows NT.  It will take full
advantage of the advanced capabilities of MOD_PERL.  It will probably
even run under FastCGI (although the author has not personally tested it
in that environment).



=head2 USAGE

Once CGI::Application::Mailform has been installed, you must complete the 
following steps to create a custom mailform on your website:

  1. Create 'mailform.html'
  2. Create 'thankyou.html'
  3. Create 'mailform.cgi'

Examples of these files are provided in the directory "Examples" 
which can be found in the installation tar file for CGI::Application.


=head2 Create 'mailform.html'

The file 'mailform.html' is simply an HTML file which contains your web form.  
This is the form whose contents will be sent, via CGI::Application::Mailform,
to the specified recipient's email address.

This file need only contain the basic HTML form.  There are two requirements
for this form.  First, the "action" attribute of the <form> element must refer to the 
CGI instance script ('mailform.cgi') you are about to create.  Second, 
the form must set a "hidden" form field with the name "rm" and the value "submitform".
This hidden parameter is what tells the CGI::Application::Mailform application to send the
email message, as opposed to send the user to the HTML form.

For example:

    <form action="mailform.cgi">
    <input type="hidden" name="rm" value="submitform">
    <!-- Your HTML form input fields go here -->
    </form>

Your 'mailform.html' may also contain JavaScript to provide form validation.
The CGI::Application::Mailform does not (currently) have any internal form 
validation capabilities.  As described earlier, this is a very simple system.
If it is necessary to enforce any fields as "required", it is recommended that
JavaScript be used.

NOTE:  It is not necessary that your HTML file be called 'mailform.html'.  
You may name this file anything you like.  The only naming limitation is that the name of this
file should be correctly referenced in your 'mailform.cgi', in the variable 'HTMLFORM_REDIRECT_URL'.




=head2 Create 'thankyou.html'

The next file you need to create is your 'thankyou.html' file.  This file is the 
simplest of all.  This is the file to which users will be redirected once they have 
successfully submitted their form data.  The purpose of this screen is to inform
and assure the user that their form data submission has been successfully received
and processed.

For example:

    <html>
    <head>
        <title>Thank you!</title>
    </head>
    <body>
        <p><h1>Thanks for your submission!</h1></p>
        <p>We have received your form, and
        we will get back to you shortly.</p>
    </body>
    </html>

NOTE:  It is not necessary that your HTML file be called 'thankyou.html'.  You may name
this file anything you like.  The only naming limitation is that the name of this
file should be correctly referenced in your 'mailform.cgi', in the variable 'SUCCESS_REDIRECT_URL'.




=head2 Create 'mailform.cgi'

The file 'mailform.cgi' is where all the functionality of CGI::Application::Mailform
is configured.  This file is referred to as a "CGI instance script" because it 
creates an "instance" of your form.  A single website may have as many instance 
scripts as needed.  All of these instance scripts may use CGI::Application::Mailform.  
They may each use a different form (with different fields, etc.) if desired.  
The ability to create multiple instances of a single
application, each with a different configuration is one of the benefits
of building web-based applications using the CGI::Application framework.

Your instance script, 'mailform.cgi', must be created in such a way that it is 
treated by your web server as an executable CGI application (as opposed to a 
document).  Generally (on UNIX), this entails setting the "execute bit" on the file and 
configuring your web server to treat files ending ".cgi" as CGI applications.
Please refer to your particular web server's manual for configuration details.

Your instance script 'mailform.cgi' must start with the following:

    #!/usr/bin/perl -w
    use CGI::Application::Mailform;
    my $mf = CGI::Application::Mailform->new();

These lines invoke the Perl interpreter, include the CGI::Application::Mailform
module, and instantiate a Mailform object, respectively.  (The
author assumes your Perl binary is located at "/usr/bin/perl".  If it is not, 
change the first line to refer to the correct location of your Perl binary.)

Once you have a Mailform object ($mf), you have to configure the Mailform for your 
particular application.  This is done by using the param() method to set a number of 
variables.  These variables are specified as follows.



B<REQUIRED VARIABLES>


=over 4


=item MAIL_FROM

  $mf->param('MAIL_FROM' => 'webmaster@your.domain');

This variable specifies the email address from which the email created by this 
mailform will appear to be sent.  This can be any address you like.
Typically, this will be "webmaster@your.domain".  Keep in mind, this is
the address to which a bounce or a reply will be sent if one is generated
as a result of the mailform email.  The MAIL_FROM can also be useful for 
assisting the recipient of these email messages in automatically filtering 
and organizing the submissions they receive.

This variable is required.  If not specified, CGI::Application::Mailform
will die() with appropriate errors.


=item MAIL_TO

  $mf->param('MAIL_TO' => 'form_recipient@your.domain');

This variable specifies the email address to which the email created by this 
mailform should be sent.  This should be the email address of the person to
whom the form contents should be emailed.  This person will receive a 
reasonably formatted message every time this mailform is submitted.

This variable is required.  If not specified, CGI::Application::Mailform
will die() with appropriate errors.


=item HTMLFORM_REDIRECT_URL

  $mf->param('HTMLFORM_REDIRECT_URL' => '/uri/or/url/to/mailform.html');

This variable specifies the URL (or URI) to which the web user should be
redirected before they have submitted the mailform.  This should be the 
HTML form which the user fills out, the contents of which will be
emailed once they are submitted.

This variable is required.  If not specified, CGI::Application::Mailform
will die() with appropriate errors.


=item SUCCESS_REDIRECT_URL

  $mf->param('SUCCESS_REDIRECT_URL' => '/uri/or/url/to/thankyou.html');

This variable specifies the URL (or URI) to which the web user should be
redirected once they have submitted the mailform.  Typically, this would be 
a "thank you" screen which assures the user that their form submission has 
been received and processed.

This variable is required.  If not specified, CGI::Application::Mailform
will die() with appropriate errors.


=item FORM_FIELDS

  $mf->param('FORM_FIELDS' => [qw/name address comments etc/]);

This variable specifies the list of HTML form fields which will be 
processed and sent via email to the specified recipient.  Only the 
form fields specified in this list will be put in the email message
which is generated by this mailform and sent to the specified 
recipient.

The value of this variable must be an array reference.  
This variable is required.  If not specified, CGI::Application::Mailform
will die() with appropriate errors.



=back


B<OPTIONAL VARIABLES>


=over 4


=item SMTP_HOST

  $mf->param('SMTP_HOST' => 'mail.your.domain');

This variable specifies the Internet host name  (or IP address) of the
server which provides Simple Mail Transfer Protocol (SMTP) services.
CGI::Application::Mailform sends all mail via SMTP using Net::SMTP.

If SMTP_HOST is unspecified, Net::SMTP will use the default host
which was specified when Net::SMTP was installed.  If 
CGI::Application::Mailform is unable to make an SMTP connection,
or successfully send mail via the SMTP host, it will die() with 
appropriate errors.


=item SUBJECT

  $mf->param('SUBJECT' => 'New form submission');

This variable specifies the subject line of the email message which is 
created by this mailform.  The subject is useful to the mailform recipient
in easily recognizing (and possibly filtering) form submissions.

This variable is optional.  If not supplied, CGI::Application::Mailform will
set the subject to a reasonable default.


=item ENV_FIELDS

  $mf->param('ENV_FIELDS'  => [qw/REMOTE_ADDR HTTP_USER_AGENT/]);

This variable specifies the list of "environment" variables which will be 
processed and sent via email to the specified recipient.  Only the 
environment variables specified in this list will be put in the email message
which is generated by this mailform and sent to the specified 
recipient.

Any environment variable which is present in the CGI
environment may be included.  Typical variables might be:

        AUTH_TYPE
        CONTENT_LENGTH
        CONTENT_TYPE
        GATEWAY_INTERFACE
        HTTP_ACCEPT
        HTTP_USER_AGENT
        PATH_INFO
        PATH_TRANSLATED
        QUERY_STRING
        REMOTE_ADDR
        REMOTE_HOST
        REMOTE_IDENT
        REMOTE_USER
        REQUEST_METHOD
        SCRIPT_NAME
        SERVER_NAME
        SERVER_PORT
        SERVER_PROTOCOL
        SERVER_SOFTWARE

See your web server documentation for a complete list and descriptions 
of the available environment variables.  The list of environment variables 
specified by the CGI protocol can be found at the following URL:

    http://hoohoo.ncsa.uiuc.edu/cgi/env.html

The value of this variable must be an array reference.  This variable 
is optional.  If not specified, no environment variables will be included
in the mailform email message.

=back


Finally, you must actually cause your Mailform to be executed by calling the run() 
method.  Your instance script 'mailform.cgi' should end with the following lines:

    $mf->run();
    exit(0);

These lines cause your configured Mailform ($mf) to be executed, and for the program to 
cleanly exit, respectively.

NOTE:  It is not necessary that your HTML file be called 'mailform.cgi'.  You may name 
this file anything you like.  The only naming limitations are that this file should be 
named so that your web server recognizes it as an executable CGI, and that your 
'mailform.html' file specifies your instance script in the "action" attribute of the 
<form> element.


All things considered, your CGI instance script will be a very small, simple file.  Unlike 
other reusable "mailform" scripts, the instance scripts are specifically intended to be
very easy to work with.  Essentially, these instance scripts are "configuration files" for
your web-based application.  The structure of instance scripts is a benefit of
building applications based on the CGI::Application framework.



=head1 SEE ALSO

L<CGI::Application>


=head1 AUTHOR

Jesse Erlbaum <jesse@erlbaum.net>


=head1 LICENSE

Copyright (c) 2001, 2002, Jesse Erlbaum <jesse@erlbaum.net>.

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.




=cut




1;

