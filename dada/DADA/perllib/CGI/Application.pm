package CGI::Application;
use Carp;
use strict;
use Class::ISA;

$CGI::Application::VERSION = '4.50';

my %INSTALLED_CALLBACKS = (
#	hook name          package                 sub
	init      => { 'CGI::Application' => [ 'cgiapp_init'    ] },
	prerun    => { 'CGI::Application' => [ 'cgiapp_prerun'  ] },
	postrun   => { 'CGI::Application' => [ 'cgiapp_postrun' ] },
	teardown  => { 'CGI::Application' => [ 'teardown'       ] },
	load_tmpl => { },
	error     => { },
);

###################################
####  INSTANCE SCRIPT METHODS  ####
###################################

sub new {
	my $class = shift;

	my @args = @_;

	if (ref($class)) {
		# No copy constructor yet!
		$class = ref($class);
	}

	# Create our object!
	my $self = {};
	bless($self, $class);

	### SET UP DEFAULT VALUES ###
	#
	# We set them up here and not in the setup() because a subclass
	# which implements setup() still needs default values!
	
	$self->header_type('header');
	$self->mode_param('rm');
	$self->start_mode('start');

	# Process optional new() parameters
	my $rprops;
	if (ref($args[0]) eq 'HASH') {
		$rprops = $self->_cap_hash($args[0]);
	} else {
		$rprops = $self->_cap_hash({ @args });
	}

	# Set tmpl_path()
	if (exists($rprops->{TMPL_PATH})) {
		$self->tmpl_path($rprops->{TMPL_PATH});
	}

	# Set CGI query object
	if (exists($rprops->{QUERY})) {
		$self->query($rprops->{QUERY});
	}

	# Set up init param() values
	if (exists($rprops->{PARAMS})) {
		croak("PARAMS is not a hash ref") unless (ref($rprops->{PARAMS}) eq 'HASH');
		my $rparams = $rprops->{PARAMS};
		while (my ($k, $v) = each(%$rparams)) {
			$self->param($k, $v);
		}
	}

	# Lock prerun_mode from being changed until cgiapp_prerun()
	$self->{__PRERUN_MODE_LOCKED} = 1;

	# Call cgiapp_init() method, which may be implemented in the sub-class.
	# Pass all constructor args forward.  This will allow flexible usage
	# down the line.
	$self->call_hook('init', @args);

	# Call setup() method, which should be implemented in the sub-class!
	$self->setup();

	return $self;
}

sub __get_runmode {
	my $self     = shift;
	my $rm_param = shift;

	my $rm;
	# Support call-back instead of CGI mode param
	if (ref($rm_param) eq 'CODE') {
		# Get run mode from subref
		$rm = $rm_param->($self);
	}
	# support setting run mode from PATH_INFO
	elsif (ref($rm_param) eq 'HASH') {
		$rm = $rm_param->{run_mode};
	}
	# Get run mode from CGI param
	else {
		$rm = $self->query->param($rm_param);
	}

	# If $rm undefined, use default (start) mode
	$rm = $self->start_mode unless defined($rm) && length($rm);

	return $rm;
}

sub __get_runmeth {
	my $self = shift;
	my $rm   = shift;

	my $rmeth;

    my $is_autoload = 0;

	my %rmodes = ($self->run_modes());
	if (exists($rmodes{$rm})) {
		$rmeth = $rmodes{$rm};
	}
    else {
		# Look for run mode "AUTOLOAD" before dieing
		unless (exists($rmodes{'AUTOLOAD'})) {
			croak("No such run mode '$rm'");
		}
		$rmeth = $rmodes{'AUTOLOAD'};
        $is_autoload = 1;
	}

	return ($rmeth, $is_autoload);
}

sub __get_body {
	my $self  = shift;
	my $rm    = shift;

	my ($rmeth, $is_autoload) = $self->__get_runmeth($rm);

	my $body;
	eval {
        $body = $is_autoload ? $self->$rmeth($rm) : $self->$rmeth();
	};
	if ($@) {
		my $error = $@;
		$self->call_hook('error', $error);
		if (my $em = $self->error_mode) {
			$body = $self->$em( $error );
		} else {
			croak("Error executing run mode '$rm': $error");
		}
	}

	# Make sure that $body is not undefined (suppress 'uninitialized value'
	# warnings)
	return defined $body ? $body : '';
}


sub run {
	my $self = shift;
	my $q = $self->query();

	my $rm_param = $self->mode_param();

	my $rm = $self->__get_runmode($rm_param);

	# Set get_current_runmode() for access by user later
	$self->{__CURRENT_RUNMODE} = $rm;

	# Allow prerun_mode to be changed
	delete($self->{__PRERUN_MODE_LOCKED});

	# Call PRE-RUN hook, now that we know the run mode
	# This hook can be used to provide run mode specific behaviors
	# before the run mode actually runs.
 	$self->call_hook('prerun', $rm);

	# Lock prerun_mode from being changed after cgiapp_prerun()
	$self->{__PRERUN_MODE_LOCKED} = 1;

	# If prerun_mode has been set, use it!
	my $prerun_mode = $self->prerun_mode();
	if (length($prerun_mode)) {
		$rm = $prerun_mode;
		$self->{__CURRENT_RUNMODE} = $rm;
	}

	# Process run mode!
	my $body = $self->__get_body($rm);

	# Support scalar-ref for body return
	$body = $$body if ref $body eq 'SCALAR';

	# Call cgiapp_postrun() hook
	$self->call_hook('postrun', \$body);

    my $return_value;
    if ($self->{__IS_PSGI}) {
        my ($status, $headers) = $self->_send_psgi_headers();
        $return_value = [ $status, $headers, [ $body ]];
    }
    else {
        # Set up HTTP headers non-PSGI responses
        my $headers = $self->_send_headers();

        # Build up total output
        $return_value  = $headers.$body;
        print $return_value unless $ENV{CGI_APP_RETURN_ONLY};
    }

	# clean up operations
	$self->call_hook('teardown');

	return $return_value;
}


sub psgi_app {
    my $class = shift;
    my $args_to_new = shift;

    return sub {
        my $env = shift;

        if (not defined $args_to_new->{QUERY}) {
            require CGI::PSGI;
            $args_to_new->{QUERY} = CGI::PSGI->new($env);
        }

        my $webapp = $class->new($args_to_new);
        return $webapp->run_as_psgi;
    }
}

sub run_as_psgi {
    my $self = shift;
    $self->{__IS_PSGI} = 1;

    # Run doesn't officially support any args, but pass them through in case some sub-class uses them.
    return $self->run(@_);
}


############################
####  OVERRIDE METHODS  ####
############################

sub cgiapp_get_query {
	my $self = shift;

	# Include CGI.pm and related modules
	require CGI;

	# Get the query object
	my $q = CGI->new();

	return $q;
}


sub cgiapp_init {
	my $self = shift;
	my @args = (@_);

	# Nothing to init, yet!
}


sub cgiapp_prerun {
	my $self = shift;
	my $rm = shift;

	# Nothing to prerun, yet!
}


sub cgiapp_postrun {
	my $self = shift;
	my $bodyref = shift;

	# Nothing to postrun, yet!
}


sub setup {
	my $self = shift;
}


sub teardown {
	my $self = shift;

	# Nothing to shut down, yet!
}




######################################
####  APPLICATION MODULE METHODS  ####
######################################

sub dump {
	my $self = shift;
	my $output = '';

	# Dump run mode
	my $current_runmode = $self->get_current_runmode();
	$current_runmode = "" unless (defined($current_runmode));
	$output .= "Current Run mode: '$current_runmode'\n";

	# Dump Params
	$output .= "\nQuery Parameters:\n";
	my @params = $self->query->param();
	foreach my $p (sort(@params)) {
		my @data = $self->query->param($p);
		my $data_str = "'".join("', '", @data)."'";
		$output .= "\t$p => $data_str\n";
	}

	# Dump ENV
	$output .= "\nQuery Environment:\n";
	foreach my $ek (sort(keys(%ENV))) {
		$output .= "\t$ek => '".$ENV{$ek}."'\n";
	}

	return $output;
}


sub dump_html {
	my $self   = shift;
	my $query  = $self->query();
	my $output = '';

	# Dump run-mode
	my $current_runmode = $self->get_current_runmode();
	$output .= "<p>Current Run-mode:
'<strong>$current_runmode</strong>'</p>\n";

	# Dump Params
	$output .= "<p>Query Parameters:</p>\n";
	$output .= $query->Dump;

	# Dump ENV
	$output .= "<p>Query Environment:</p>\n<ol>\n";
	foreach my $ek ( sort( keys( %ENV ) ) ) {
		$output .= sprintf(
			"<li> %s => '<strong>%s</strong>'</li>\n",
			$query->escapeHTML( $ek ),
			$query->escapeHTML( $ENV{$ek} )
		);
	}
	$output .= "</ol>\n";

	return $output;
}


sub header_add {
	my $self = shift;
	return $self->_header_props_update(\@_,add=>1);
}

sub header_props {
	my $self = shift;
	return $self->_header_props_update(\@_,add=>0);
}

# used by header_props and header_add to update the headers
sub _header_props_update {
	my $self     = shift;
	my $data_ref = shift;
	my %in       = @_;

	my @data = @$data_ref;

	# First use?  Create new __HEADER_PROPS!
	$self->{__HEADER_PROPS} = {} unless (exists($self->{__HEADER_PROPS}));

	my $props;

	# If data is provided, set it!
	if (scalar(@data)) {
        if ($self->header_type eq 'none') {
		    warn "header_props called while header_type set to 'none', headers will NOT be sent!" 
        }
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy
			%$props = %{$data[0]};
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$props = @data;
		} else {
			my $meth = $in{add} ? 'add' : 'props';
			croak("Odd number of elements passed to header_$meth().  Not a valid hash")
		}

		# merge in new headers, appending new values passed as array refs
		if ($in{add}) {
			for my $key_set_to_aref (grep { ref $props->{$_} eq 'ARRAY'} keys %$props) {
				my $existing_val = $self->{__HEADER_PROPS}->{$key_set_to_aref};
				next unless defined $existing_val;
				my @existing_val_array = (ref $existing_val eq 'ARRAY') ? @$existing_val : ($existing_val);
				$props->{$key_set_to_aref} = [ @existing_val_array, @{ $props->{$key_set_to_aref} } ];
			}
			$self->{__HEADER_PROPS} = { %{ $self->{__HEADER_PROPS} }, %$props };
		}
		# Set new headers, clobbering existing values
		else {
			$self->{__HEADER_PROPS} = $props;
		}

	}

	# If we've gotten this far, return the value!
	return (%{ $self->{__HEADER_PROPS}});
}


sub header_type {
	my $self = shift;
	my ($header_type) = @_;

	my @allowed_header_types = qw(header redirect none);

	# First use?  Create new __HEADER_TYPE!
	$self->{__HEADER_TYPE} = 'header' unless (exists($self->{__HEADER_TYPE}));

	# If data is provided, set it!
	if (defined($header_type)) {
		$header_type = lc($header_type);
		croak("Invalid header_type '$header_type'")
			unless(grep { $_ eq $header_type } @allowed_header_types);
		$self->{__HEADER_TYPE} = $header_type;
	}

	# If we've gotten this far, return the value!
	return $self->{__HEADER_TYPE};
}


sub param {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __PARAMS!
	$self->{__PARAMS} = {} unless (exists($self->{__PARAMS}));

	my $rp = $self->{__PARAMS};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rp = (%$rp, %{$data[0]});
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rp = (%$rp, @data);
		} elsif (scalar(@data) > 1) {
			croak("Odd number of elements passed to param().  Not a valid hash");
		}
	} else {
		# Return the list of param keys if no param is specified.
		return (keys(%$rp));
	}

	# If exactly one parameter was sent to param(), return the value
	if (scalar(@data) <= 2) {
		my $param = $data[0];
		return $rp->{$param};
	}
	return;  # Otherwise, return undef
}


sub delete {
	my $self = shift;
	my ($param) = @_;

	# return undef it the param name isn't given
	return undef unless defined $param;

	#simply delete this param from $self->{__PARAMS}
	delete $self->{__PARAMS}->{$param};
}


sub query {
	my $self = shift;
	my ($query) = @_;

	# If data is provided, set it!  Otherwise, create a new one.
	if (defined($query)) {
		$self->{__QUERY_OBJ} = $query;
	} else {
		# We're only allowed to create a new query object if one does not yet exist!
		unless (exists($self->{__QUERY_OBJ})) {
			$self->{__QUERY_OBJ} = $self->cgiapp_get_query();
		}
	}

	return $self->{__QUERY_OBJ};
}


sub run_modes {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __RUN_MODES!
    $self->{__RUN_MODES} = { 'start' => 'dump_html' } unless (exists($self->{__RUN_MODES}));

	my $rr_m = $self->{__RUN_MODES};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, hash-ref, or array-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rr_m = (%$rr_m, %{$data[0]});
		} elsif (ref($data[0]) eq 'ARRAY') {
			# Convert array-ref into hash table
			foreach my $rm (@{$data[0]}) {
				$rr_m->{$rm} = $rm;
			}
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rr_m = (%$rr_m, @data);
		} else {
			croak("Odd number of elements passed to run_modes().  Not a valid hash");
		}
	}

	# If we've gotten this far, return the value!
	return (%$rr_m);
}


sub start_mode {
	my $self = shift;
	my ($start_mode) = @_;

	# First use?  Create new __START_MODE
	$self->{__START_MODE} = 'start' unless (exists($self->{__START_MODE}));

	# If data is provided, set it
	if (defined($start_mode)) {
		$self->{__START_MODE} = $start_mode;
	}

	return $self->{__START_MODE};
}


sub error_mode {
	my $self = shift;
	my ($error_mode) = @_;

	# First use?  Create new __ERROR_MODE
	$self->{__ERROR_MODE} = undef unless (exists($self->{__ERROR_MODE}));

	# If data is provided, set it.
	if (defined($error_mode)) {
		$self->{__ERROR_MODE} = $error_mode;
	}

	return $self->{__ERROR_MODE};
}


sub tmpl_path {
	my $self = shift;
	my ($tmpl_path) = @_;

	# First use?  Create new __TMPL_PATH!
	$self->{__TMPL_PATH} = '' unless (exists($self->{__TMPL_PATH}));

	# If data is provided, set it!
	if (defined($tmpl_path)) {
		$self->{__TMPL_PATH} = $tmpl_path;
	}

	# If we've gotten this far, return the value!
	return $self->{__TMPL_PATH};
}


sub prerun_mode {
	my $self = shift;
	my ($prerun_mode) = @_;

	# First use?  Create new __PRERUN_MODE
	$self->{__PRERUN_MODE} = '' unless (exists($self->{__PRERUN_MODE}));

	# Was data provided?
	if (defined($prerun_mode)) {
		# Are we allowed to set prerun_mode?
		if (exists($self->{__PRERUN_MODE_LOCKED})) {
			# Not allowed!  Throw an exception.
			croak("prerun_mode() can only be called within cgiapp_prerun()!  Error");
		} else {
			# If data is provided, set it!
			$self->{__PRERUN_MODE} = $prerun_mode;
		}
	}

	# If we've gotten this far, return the value!
	return $self->{__PRERUN_MODE};
}


sub get_current_runmode {
	my $self = shift;

	# It's OK if we return undef if this method is called too early
	return $self->{__CURRENT_RUNMODE};
}





###########################
####  PRIVATE METHODS  ####
###########################


# return headers as a string
sub _send_headers {
	my $self = shift;
	my $q    = $self->query;
	my $type = $self->header_type;

    return
        $type eq 'redirect' ? $q->redirect( $self->header_props )
      : $type eq 'header'   ? $q->header  ( $self->header_props )
      : $type eq 'none'     ? ''
      : croak "Invalid header_type '$type'"
}

# return a 2 element array modeling the first PSGI redirect values: status code and arrayref of header pairs
sub _send_psgi_headers {
	my $self = shift;
	my $q    = $self->query;
	my $type = $self->header_type;

    return
        $type eq 'redirect' ? $q->psgi_redirect( $self->header_props )
      : $type eq 'header'   ? $q->psgi_header  ( $self->header_props )
      : $type eq 'none'     ? ''
      : croak "Invalid header_type '$type'"

}


# Make all hash keys CAPITAL
# although this method is internal, some other extensions
# have come to rely on it, so any changes here should be
# made with great care or avoided. 
sub _cap_hash {
	my $self = shift;
	my $rhash = shift;
	my %hash = map {
		my $k = $_;
		my $v = $rhash->{$k};
		$k =~ tr/a-z/A-Z/;
		$k => $v;
	} keys(%{$rhash});
	return \%hash;
}



1;




=pod

=head1 NAME

CGI::Application - Framework for building reusable web-applications

=head1 SYNOPSIS

  # In "WebApp.pm"...
  package WebApp;
  use base 'CGI::Application';

  # ( setup() can even be skipped for common cases. See docs below. )
  sub setup {
	my $self = shift;
	$self->start_mode('mode1');
	$self->mode_param('rm');
	$self->run_modes(
		'mode1' => 'do_stuff',
		'mode2' => 'do_more_stuff',
		'mode3' => 'do_something_else'
	);
  }
  sub do_stuff { ... }
  sub do_more_stuff { ... }
  sub do_something_else { ... }
  1;


  ### In "webapp.cgi"...
  use WebApp;
  my $webapp = WebApp->new();
  $webapp->run();

  ### Or, in a PSGI file, webapp.psgi
  use WebApp;
  WebApp->psgi_app();

=head1 INTRODUCTION

CGI::Application makes it easier to create sophisticated, high-performance,
reusable web-based applications.  CGI::Application helps makes your web
applications easier to design, write, and evolve.

CGI::Application judiciously avoids employing technologies and techniques which
would bind a developer to any one set of tools, operating system or web server.

It is lightweight in terms of memory usage, making it suitable for common CGI
environments, and a high performance choice in persistent environments like
FastCGI or mod_perl.

By adding L<PLUG-INS> as your needs grow, you can add advanced and complex
features when you need them. 

First released in 2000 and used and expanded by a number of professional
website developers, CGI::Application is a stable, reliable choice. 

=head1 USAGE EXAMPLE

Imagine you have to write an application to search through a database
of widgets.  Your application has three screens:

   1. Search form
   2. List of results
   3. Detail of a single record

To write this application using CGI::Application you will create two files:

   1. WidgetView.pm -- Your "Application Module"
   2. widgetview.cgi -- Your "Instance Script"

The Application Module contains all the code specific to your
application functionality, and it exists outside of your web server's
document root, somewhere in the Perl library search path.

The Instance Script is what is actually called by your web server.  It is
a very small, simple file which simply creates an instance of your
application and calls an inherited method, run().  Following is the
entirety of "widgetview.cgi":

   #!/usr/bin/perl -w
   use WidgetView;
   my $webapp = WidgetView->new();
   $webapp->run();

As you can see, widgetview.cgi simply "uses" your Application module
(which implements a Perl package called "WidgetView").  Your Application Module,
"WidgetView.pm", is somewhat more lengthy:

   package WidgetView;
   use base 'CGI::Application';
   use strict;

   # Needed for our database connection
   use CGI::Application::Plugin::DBH;

   sub setup {
	my $self = shift;
	$self->start_mode('mode1');
	$self->run_modes(
		'mode1' => 'showform',
		'mode2' => 'showlist',
		'mode3' => 'showdetail'
	);

	# Connect to DBI database, with the same args as DBI->connect();
     $self->dbh_config();
   }

   sub teardown {
	my $self = shift;

	# Disconnect when we're done, (Although DBI usually does this automatically)
	$self->dbh->disconnect();
   }

   sub showform {
	my $self = shift;

	# Get CGI query object
	my $q = $self->query();

	my $output = '';
	$output .= $q->start_html(-title => 'Widget Search Form');
	$output .= $q->start_form();
	$output .= $q->textfield(-name => 'widgetcode');
	$output .= $q->hidden(-name => 'rm', -value => 'mode2');
	$output .= $q->submit();
	$output .= $q->end_form();
	$output .= $q->end_html();

	return $output;
   }

   sub showlist {
	my $self = shift;

	# Get our database connection
	my $dbh = $self->dbh();

	# Get CGI query object
	my $q = $self->query();
	my $widgetcode = $q->param("widgetcode");

	my $output = '';
	$output .= $q->start_html(-title => 'List of Matching Widgets');

	## Do a bunch of stuff to select "widgets" from a DBI-connected
	## database which match the user-supplied value of "widgetcode"
	## which has been supplied from the previous HTML form via a
	## CGI.pm query object.
	##
	## Each row will contain a link to a "Widget Detail" which
	## provides an anchor tag, as follows:
	##
	##   "widgetview.cgi?rm=mode3&widgetid=XXX"
	##
	##  ...Where "XXX" is a unique value referencing the ID of
	## the particular "widget" upon which the user has clicked.

	$output .= $q->end_html();

	return $output;
   }

   sub showdetail {
	my $self = shift;

	# Get our database connection
	my $dbh = $self->dbh();

	# Get CGI query object
	my $q = $self->query();
	my $widgetid = $q->param("widgetid");

	my $output = '';
	$output .= $q->start_html(-title => 'Widget Detail');

	## Do a bunch of things to select all the properties of
	## the particular "widget" upon which the user has
	## clicked.  The key id value of this widget is provided
	## via the "widgetid" property, accessed via the CGI.pm
	## query object.

	$output .= $q->end_html();

	return $output;
   }

   1;  # Perl requires this at the end of all modules


CGI::Application takes care of implementing the new() and the run()
methods.  Notice that at no point do you call print() to send any
output to STDOUT.  Instead, all output is returned as a scalar.

CGI::Application's most significant contribution is in managing
the application state.  Notice that all which is needed to push
the application forward is to set the value of a HTML form
parameter 'rm' to the value of the "run mode" you wish to handle
the form submission.  This is the key to CGI::Application.


=head1 ABSTRACT

The guiding philosophy behind CGI::Application is that a web-based
application can be organized into a specific set of "Run Modes."
Each Run Mode is roughly analogous to a single screen (a form, some
output, etc.).  All the Run Modes are managed by a single "Application
Module" which is a Perl module.  In your web server's document space
there is an "Instance Script" which is called by the web server as a
CGI (or an Apache::Registry script if you're using Apache + mod_perl).

This methodology is an inversion of the "Embedded" philosophy (ASP, JSP,
EmbPerl, Mason, etc.) in which there are "pages" for each state of the
application, and the page drives functionality.  In CGI::Application,
form follows function -- the Application Module drives pages, and the
code for a single application is in one place; not spread out over
multiple "pages".  If you feel that Embedded architectures are
confusing, unorganized, difficult to design and difficult to manage,
CGI::Application is the methodology for you!

Apache is NOT a requirement for CGI::Application.  Web applications based on
CGI::Application will run equally well on NT/IIS or any other
CGI-compatible environment.  CGI::Application-based projects
are, however, ripe for use on Apache/mod_perl servers, as they
naturally encourage Good Programming Practices and will often work
in persistent environments without modification. 

For more information on using CGI::Application with mod_perl, please see our
website at http://www.cgi-app.org/, as well as
L<CGI::Application::Plugin::Apache>, which integrates with L<Apache::Request>.

=head1 DESCRIPTION

It is intended that your Application Module will be implemented as a sub-class
of CGI::Application. This is done simply as follows:

    package My::App; 
    use base 'CGI::Application';

B<Notation and Conventions>

For the purpose of this document, we will refer to the
following conventions:

  WebApp.pm   The Perl module which implements your Application Module class.
  WebApp      Your Application Module class; a sub-class of CGI::Application.
  webapp.cgi  The Instance Script which implements your Application Module.
  $webapp     An instance (object) of your Application Module class.
  $c          Same as $webapp, used in instance methods to pass around the
              current object. (Sometimes referred as "$self" in other code)




=head2 Instance Script Methods

By inheriting from CGI::Application you have access to a
number of built-in methods.  The following are those which
are expected to be called from your Instance Script.

=head3 new()

The new() method is the constructor for a CGI::Application.  It returns
a blessed reference to your Application Module package (class).  Optionally,
new() may take a set of parameters as key => value pairs:

    my $webapp = WebApp->new(
		TMPL_PATH => 'App/',
		PARAMS => {
			'custom_thing_1' => 'some val',
			'another_custom_thing' => [qw/123 456/]
		}
    );

This method may take some specific parameters:

B<TMPL_PATH> - This optional parameter defines a path to a directory of templates.
This is used by the load_tmpl() method (specified below), and may also be used
for the same purpose by other template plugins.  This run-time parameter allows
you to further encapsulate instantiating templates, providing potential for
more re-usability.  It can be either a scalar or an array reference of multiple
paths.

B<QUERY> - This optional parameter allows you to specify an
already-created CGI.pm query object.  Under normal use,
CGI::Application will instantiate its own CGI.pm query object.
Under certain conditions, it might be useful to be able to use
one which has already been created.

B<PARAMS> - This parameter, if used, allows you to set a number
of custom parameters at run-time.  By passing in different
values in different instance scripts which use the same application
module you can achieve a higher level of re-usability.  For instance,
imagine an application module, "Mailform.pm".  The application takes
the contents of a HTML form and emails it to a specified recipient.
You could have multiple instance scripts throughout your site which
all use this "Mailform.pm" module, but which set different recipients
or different forms.

One common use of instance scripts is to provide a path to a config file.  This
design allows you to define project wide configuration objects used by many
several instance scripts. There are several plugins which simplify the syntax
for this and provide lazy loading. Here's an example using
L<CGI::Application::Plugin::ConfigAuto>, which uses L<Config::Auto> to support
many configuration file formats. 

 my $app = WebApp->new(PARAMS => { cfg_file => 'config.pl' });

 # Later in your app:
 my %cfg = $self->cfg()
 # or ... $self->cfg('HTML_ROOT_DIR');

See the list of of plugins below for more config file integration solutions.

=head3 run()

The run() method is called upon your Application Module object, from
your Instance Script.  When called, it executes the functionality
in your Application Module.

    my $webapp = WebApp->new();
    $webapp->run();

This method first determines the application state by looking at the
value of the CGI parameter specified by mode_param() (defaults to
'rm' for "Run Mode"), which is expected to contain the name of the mode of
operation.  If not specified, the state defaults to the value
of start_mode().

Once the mode has been determined, run() looks at the dispatch
table stored in run_modes() and finds the function pointer which
is keyed from the mode name.  If found, the function is called and the
data returned is print()'ed to STDOUT and to the browser.  If
the specified mode is not found in the run_modes() table, run() will
croak().

=head2 PSGI support

CGI::Application offers native L<PSGI> support. The default query object
for this is L<CGI::PSGI>, which simply wrappers CGI.pm to provide PSGI
support to it.

=head3 psgi_app()

 $psgi_coderef = WebApp->psgi_app({ ... args to new() ... });

The simplest way to create and return a PSGI-compatible coderef. Pass in
arguments to a hashref just as would to new. This returns a PSGI-compatible
coderef, using L<CGI:::PSGI> as the query object. To use a different query
object, construct your own object using C<< run_as_psgi() >>, as shown below.

It's possible that we'll change from CGI::PSGI to a different-but-compatible
query object for PSGI support in the future, perhaps if CGI.pm adds native
PSGI support.

=head3 run_as_psgi()

 my $psgi_aref = $webapp->run_as_psgi;

Just like C<< run >>, but prints no output and returns the data structure
required by the L<PSGI> specification. Use this if you want to run the
application on top of a PSGI-compatible handler, such as L<Plack> provides.

If you are just getting started, just use C<< run() >>. It's easy to switch to using
C<< run_as_psgi >> later.

Why use C<< run_as_psgi() >>? There are already solutions to run
CGI::Application-based projects on several web servers with dozens of plugins.
Running as a PSGI-compatible application provides the ability to run on
additional PSGI-compatible servers, as well as providing access to all of the
"Middleware" solutions available through the L<Plack> project.

The structure returned is an arrayref, containing the status code, an arrayref
of header key/values and an arrayref containing the body.

 [ 200, [ 'Content-Type' => 'text/html' ], [ $body ] ]

By default the body is a single scalar, but plugins may modify this to return
other value PSGI values.  See L<PSGI/"The Response"> for details about the
response format.

Note that calling C<< run_as_psgi >> only handles the I<output> portion of the
PSGI spec. to handle the input, you need to use a CGI.pm-like query object that
is PSGI-compliant, such as L<CGI::PSGI>. This query object must provide L<psgi_header>
and L<psgi_redirect> methods.

The final result might look like this:

    use WebApp;
    use CGI::PSGI;

    my $handler = sub {
        my $env = shift;
        my $webapp = WebApp->new({ QUERY => CGI::PSGI->new($env) });
        $webapp->run_as_psgi;
    };


=head2 Methods to possibly override

CGI::Application implements some methods which are expected to be overridden
by implementing them in your sub-class module.  These methods are as follows:

=head3 setup()

This method is called by the inherited new() constructor method.  The
setup() method should be used to define the following property/methods:

    mode_param() - set the name of the run mode CGI param.
    start_mode() - text scalar containing the default run mode.
    error_mode() - text scalar containing the error mode.
    run_modes() - hash table containing mode => function mappings.
    tmpl_path() - text scalar or array reference containing path(s) to template files.

Your setup() method may call any of the instance methods of your application.
This function is a good place to define properties specific to your application
via the $webapp->param() method.

Your setup() method might be implemented something like this:

	sub setup {
		my $self = shift;
		$self->tmpl_path('/path/to/my/templates/');
		$self->start_mode('putform');
		$self->error_mode('my_error_rm');
		$self->run_modes({
			'putform'  => 'my_putform_func',
			'postdata' => 'my_data_func'
		});
		$self->param('myprop1');
		$self->param('myprop2', 'prop2value');
		$self->param('myprop3', ['p3v1', 'p3v2', 'p3v3']);
	}

However, often times all that needs to be in setup() is defining your run modes
and your start mode. L<CGI::Application::Plugin::AutoRunmode> allows you to do  
this with a simple syntax, using run mode attributes:

 use CGI::Application::Plugin::AutoRunmode;

 sub show_first : StartRunmode { ... };
 sub do_next : Runmode { ... }

=head3 teardown()

If implemented, this method is called automatically after your application runs.  It
can be used to clean up after your operations.  A typical use of the
teardown() function is to disconnect a database connection which was
established in the setup() function.  You could also use the teardown()
method to store state information about the application to the server.


=head3 cgiapp_init()

If implemented, this method is called automatically right before the
setup() method is called.  This method provides an optional initialization
hook, which improves the object-oriented characteristics of
CGI::Application.  The cgiapp_init() method receives, as its parameters,
all the arguments which were sent to the new() method.

An example of the benefits provided by utilizing this hook is
creating a custom "application super-class" from which all
your web applications would inherit, instead of CGI::Application.

Consider the following:

  # In MySuperclass.pm:
  package MySuperclass;
  use base 'CGI::Application';
  sub cgiapp_init {
	my $self = shift;
	# Perform some project-specific init behavior
	# such as to load settings from a database or file.
  }


  # In MyApplication.pm:
  package MyApplication;
  use base 'MySuperclass';
  sub setup { ... }
  sub teardown { ... }
  # The rest of your CGI::Application-based follows...


By using CGI::Application and the cgiapp_init() method as illustrated,
a suite of applications could be designed to share certain
characteristics.  This has the potential for much cleaner code
built on object-oriented inheritance.


=head3 cgiapp_prerun()

If implemented, this method is called automatically right before the
selected run mode method is called.  This method provides an optional
pre-runmode hook, which permits functionality to be added at the point
right before the run mode method is called.  To further leverage this
hook, the value of the run mode is passed into cgiapp_prerun().

Another benefit provided by utilizing this hook is
creating a custom "application super-class" from which all
your web applications would inherit, instead of CGI::Application.

Consider the following:

  # In MySuperclass.pm:
  package MySuperclass;
  use base 'CGI::Application';
  sub cgiapp_prerun {
	my $self = shift;
	# Perform some project-specific init behavior
	# such as to implement run mode specific
	# authorization functions.
  }


  # In MyApplication.pm:
  package MyApplication;
  use base 'MySuperclass';
  sub setup { ... }
  sub teardown { ... }
  # The rest of your CGI::Application-based follows...


By using CGI::Application and the cgiapp_prerun() method as illustrated,
a suite of applications could be designed to share certain
characteristics.  This has the potential for much cleaner code
built on object-oriented inheritance.

It is also possible, within your cgiapp_prerun() method, to change the
run mode of your application.  This can be done via the prerun_mode()
method, which is discussed elsewhere in this POD.

=head3 cgiapp_postrun()

If implemented, this hook will be called after the run mode method
has returned its output, but before HTTP headers are generated.  This
will give you an opportunity to modify the body and headers before they
are returned to the web browser.

A typical use for this hook is pipelining the output of a CGI-Application
through a series of "filter" processors.  For example:

  * You want to enclose the output of all your CGI-Applications in
    an HTML table in a larger page.

  * Your run modes return structured data (such as XML), which you
    want to transform using a standard mechanism (such as XSLT).

  * You want to post-process CGI-App output through another system,
    such as HTML::Mason.

  * You want to modify HTTP headers in a particular way across all
    run modes, based on particular criteria.

The cgiapp_postrun() hook receives a reference to the output from
your run mode method, in addition to the CGI-App object.  A typical
cgiapp_postrun() method might be implemented as follows:

  sub cgiapp_postrun {
    my $self = shift;
    my $output_ref = shift;

    # Enclose output HTML table
    my $new_output = "<table border=1>";
    $new_output .= "<tr><td> Hello, World! </td></tr>";
    $new_output .= "<tr><td>". $$output_ref ."</td></tr>";
    $new_output .= "</table>";

    # Replace old output with new output
    $$output_ref = $new_output;
  }


Obviously, with access to the CGI-App object you have full access to use all
the methods normally available in a run mode.  You could, for example, use
C<load_tmpl()> to replace the static HTML in this example with HTML::Template.
You could change the HTTP headers (via C<header_type()> and C<header_props()>
methods) to set up a redirect.  You could also use the objects properties
to apply changes only under certain circumstance, such as a in only certain run
modes, and when a C<param()> is a particular value.


=head3 cgiapp_get_query()

 my $q = $webapp->cgiapp_get_query;

Override this method to retrieve the query object if you wish to use a
different query interface instead of CGI.pm.  

CGI.pm is only loaded if it is used on a given request.

If you can use an alternative to CGI.pm, it needs to have some compatibility
with the CGI.pm API. For normal use, just having a compatible C<param> method
should be sufficient. 

If you use the C<path_info> option to the mode_param() method, then we will call
the C<path_info()> method on the query object.

If you use the C<Dump> method in CGI::Application, we will call the C<Dump> and
C<escapeHTML> methods on the query object. 

=head2 Essential Application Methods

The following methods are inherited from CGI::Application, and are
available to be called by your application within your Application
Module. They are called essential because you will use all are most
of them to get any application up and running.  These functions are listed in alphabetical order.

=head3 load_tmpl()

    my $tmpl_obj = $webapp->load_tmpl;
    my $tmpl_obj = $webapp->load_tmpl('some.html');
    my $tmpl_obj = $webapp->load_tmpl( \$template_content );
    my $tmpl_obj = $webapp->load_tmpl( FILEHANDLE );

This method takes the name of a template file, a reference to template data
or a FILEHANDLE and returns an HTML::Template object. If the filename is undefined or missing, CGI::Application will default to trying to use the current run mode name, plus the extension ".html". 

If you use the default template naming system, you should also use
L<CGI::Application::Plugin::Forward>, which simply helps to keep the current
name accurate when you pass control from one run mode to another.

( For integration with other template systems
and automated template names, see "Alternatives to load_tmpl() below. )

When you pass in a filename, the HTML::Template->new_file() constructor
is used for create the object.  When you pass in a reference to the template
content, the HTML::Template->new_scalar_ref() constructor is used and
when you pass in a filehandle, the HTML::Template->new_filehandle()
constructor is used.

Refer to L<HTML::Template> for specific usage of HTML::Template.

If tmpl_path() has been specified, load_tmpl() will set the
HTML::Template C<path> option to the path(s) provided.  This further
assists in encapsulating template usage.

The load_tmpl() method will pass any extra parameters sent to it directly to
HTML::Template->new_file() (or new_scalar_ref() or new_filehandle()).
This will allow the HTML::Template object to be further customized:

    my $tmpl_obj = $webapp->load_tmpl('some_other.html',
         die_on_bad_params => 0,
         cache => 1
    );

Note that if you want to pass extra arguments but use the default template
name, you still need to provide a name of C<undef>:

    my $tmpl_obj = $webapp->load_tmpl(undef,
         die_on_bad_params => 0,
         cache => 1
    );

B<Alternatives to load_tmpl()>

If your application requires more specialized behavior than this, you can
always replace it by overriding load_tmpl() by implementing your own
load_tmpl() in your CGI::Application sub-class application module.

First, you may want to check out the template related plugins. 

L<CGI::Application::Plugin::TT> focuses just on Template Toolkit integration,
and features pre-and-post features, singleton support and more.

L<CGI::Application::Plugin::Stream> can help if you want to return a stream and
not a file. It features a simple syntax and MIME-type detection. 

B<specifying the template class with html_tmpl_class()>

You may specify an API-compatible alternative to L<HTML::Template> by setting
a new C<html_tmpl_class()>:

  $self->html_tmpl_class('HTML::Template::Dumper');

The default is "HTML::Template". The alternate class should
provide at least the following parts of the HTML::Template API:

 $t = $class->new( scalarref => ... );  # If you use scalarref templates
 $t = $class->new( filehandle => ... ); # If you use filehandle templates
 $t = $class->new( filename => ... );
 $t->param(...); 

Here's an example case allowing you to precisely test what's sent to your
templates:

    $ENV{CGI_APP_RETURN_ONLY} = 1;
    my $webapp = WebApp->new;
       $webapp->html_tmpl_class('HTML::Template::Dumper'); 
    my $out_str = $webapp->run;
    my $tmpl_href = eval "$out_str";

    # Now Precisely test what would be set to the template
    is ($tmpl_href->{pet_name}, 'Daisy', "Daisy is sent template");

This is a powerful technique because HTML::Template::Dumper loads and considers
the template file that would actually be used. If the 'pet_name' token was missing
in the template, the above test would fail. So, you are testing both your code
and your templates in a much more precise way than using simple regular
expressions to see if the string "Daisy" appeared somewhere on the page.

B<The load_tmpl() callback>

Plugin authors will be interested to know that you can register a callback that
will be executed just before load_tmpl() returns:

  $self->add_callback('load_tmpl',\&your_method);

When C<your_method()> is executed, it will be passed three arguments: 

 1. A hash reference of the extra params passed into C<load_tmpl>
 2. Followed by a hash reference to template parameters. 
    With both of these, you can modify them by reference to affect 
    values that are actually passed to the new() and param() methods of the
    template object.
 3. The name of the template file.    

Here's an example stub for a load_tmpl() callback: 

    sub my_load_tmpl_callback {
        my ($c, $ht_params, $tmpl_params, $tmpl_file) = @_
        # modify $ht_params or $tmpl_params by reference...    
    }

=head3 param()

    $webapp->param('pname', $somevalue);

The param() method provides a facility through which you may set
application instance properties which are accessible throughout
your application.

The param() method may be used in two basic ways.  First, you may use it
to get or set the value of a parameter:

    $webapp->param('scalar_param', '123');
    my $scalar_param_values = $webapp->param('some_param');

Second, when called in the context of an array, with no parameter name
specified, param() returns an array containing all the parameters which
currently exist:

    my @all_params = $webapp->param();

The param() method also allows you to set a bunch of parameters at once
by passing in a hash (or hashref):

    $webapp->param(
        'key1' => 'val1',
        'key2' => 'val2',
        'key3' => 'val3',
    );

The param() method enables a very valuable system for
customizing your applications on a per-instance basis.
One Application Module might be instantiated by different
Instance Scripts.  Each Instance Script might set different values for a
set of parameters.  This allows similar applications to share a common
code-base, but behave differently.  For example, imagine a mail form
application with a single Application Module, but multiple Instance
Scripts.  Each Instance Script might specify a different recipient.
Another example would be a web bulletin boards system.  There could be
multiple boards, each with a different topic and set of administrators.

The new() method provides a shortcut for specifying a number of run-time
parameters at once.  Internally, CGI::Application calls the param()
method to set these properties.  The param() method is a powerful tool for
greatly increasing your application's re-usability.

=head3 query()

    my $q = $webapp->query();
    my $remote_user = $q->remote_user();

This method retrieves the CGI.pm query object which has been created
by instantiating your Application Module.  For details on usage of this
query object, refer to L<CGI>.  CGI::Application is built on the CGI
module.  Generally speaking, you will want to become very familiar
with CGI.pm, as you will use the query object whenever you want to
interact with form data.

When the new() method is called, a CGI query object is automatically created.
If, for some reason, you want to use your own CGI query object, the new()
method supports passing in your existing query object on construction using
the QUERY attribute.

There are a few rare situations where you want your own query object to be 
used after your Application Module has already been constructed. In that case 
you can pass it to c<query()> like this:

    $webapp->query($new_query_object);
    my $q = $webapp->query(); # now uses $new_query_object

=head3 run_modes()

    # The common usage: an arrayref of run mode names that exactly match subroutine names
    $webapp->run_modes([qw/
        form_display
        form_process
    /]);

   # With a hashref, use a different name or a code ref
   $webapp->run_modes(
           'mode1' => 'some_sub_by_name', 
           'mode2' => \&some_other_sub_by_ref
    );

This accessor/mutator specifies the dispatch table for the
application states, using the syntax examples above. It returns 
the dispatch table as a hash. 

The run_modes() method may be called more than once.  Additional values passed
into run_modes() will be added to the run modes table.  In the case that an
existing run mode is re-defined, the new value will override the existing value.
This behavior might be useful for applications which are created via inheritance
from another application, or some advanced application which modifies its
own capabilities based on user input.

The run() method uses the data in this table to send the application to the
correct function as determined by reading the CGI parameter specified by
mode_param() (defaults to 'rm' for "Run Mode").  These functions are referred
to as "run mode methods".

The hash table set by this method is expected to contain the mode
name as a key.  The value should be either a hard reference (a subref)
to the run mode method which you want to be called when the application enters
the specified run mode, or the name of the run mode method to be called:

    'mode_name_by_ref'  => \&mode_function
    'mode_name_by_name' => 'mode_function'

The run mode method specified is expected to return a block of text (e.g.:
HTML) which will eventually be sent back to the web browser.  The run mode
method may return its block of text as a scalar or a scalar-ref.

An advantage of specifying your run mode methods by name instead of
by reference is that you can more easily create derivative applications
using inheritance.  For instance, if you have a new application which is
exactly the same as an existing application with the exception of one
run mode, you could simply inherit from that other application and override
the run mode method which is different.  If you specified your run mode
method by reference, your child class would still use the function
from the parent class.

An advantage of specifying your run mode methods by reference instead of by name
is performance.  Dereferencing a subref is faster than eval()-ing
a code block.  If run-time performance is a critical issue, specify
your run mode methods by reference and not by name.  The speed differences
are generally small, however, so specifying by name is preferred.

Specifying the run modes by array reference:

    $webapp->run_modes([ 'mode1', 'mode2', 'mode3' ]);

Is is the same as using a hash, with keys equal to values

    $webapp->run_modes(
        'mode1' => 'mode1',
        'mode2' => 'mode2',
        'mode3' => 'mode3'
    );

Often, it makes good organizational sense to have your run modes map to
methods of the same name.  The array-ref interface provides a shortcut
to that behavior while reducing verbosity of your code.

Note that another importance of specifying your run modes in either a
hash or array-ref is to assure that only those Perl methods which are
specifically designated may be called via your application.  Application
environments which don't specify allowed methods and disallow all others
are insecure, potentially opening the door to allowing execution of
arbitrary code.  CGI::Application maintains a strict "default-deny" stance
on all method invocation, thereby allowing secure applications
to be built upon it.

B<IMPORTANT NOTE ABOUT RUN MODE METHODS>

Your application should *NEVER* print() to STDOUT.
Using print() to send output to STDOUT (including HTTP headers) is
exclusively the domain of the inherited run() method.  Breaking this
rule is a common source of errors.  If your program is erroneously
sending content before your HTTP header, you are probably breaking this rule.


B<THE RUN MODE OF LAST RESORT: "AUTOLOAD">

If CGI::Application is asked to go to a run mode which doesn't exist
it will usually croak() with errors.  If this is not your desired
behavior, it is possible to catch this exception by implementing
a run mode with the reserved name "AUTOLOAD":

  $self->run_modes(
	"AUTOLOAD" => \&catch_my_exception
  );

Before CGI::Application calls croak() it will check for the existence
of a run mode called "AUTOLOAD".  If specified, this run mode will in
invoked just like a regular run mode, with one exception:  It will
receive, as an argument, the name of the run mode which invoked it:

  sub catch_my_exception {
	my $self = shift;
	my $intended_runmode = shift;

	my $output = "Looking for '$intended_runmode', but found 'AUTOLOAD' instead";
	return $output;
  }

This functionality could be used for a simple human-readable error
screen, or for more sophisticated application behaviors.


=head3 start_mode()

    $webapp->start_mode('mode1');

The start_mode contains the name of the mode as specified in the run_modes()
table.  Default mode is "start".  The mode key specified here will be used
whenever the value of the CGI form parameter specified by mode_param() is
not defined.  Generally, this is the first time your application is executed.

=head3 tmpl_path()

    $webapp->tmpl_path('/path/to/some/templates/');

This access/mutator method sets the file path to the directory (or directories)
where the templates are stored.  It is used by load_tmpl() to find the template
files, using HTML::Template's C<path> option. To set the path you can either
pass in a text scalar or an array reference of multiple paths.



=head2 More Application Methods

You can skip this section if you are just getting started. 

The following additional methods are inherited from CGI::Application, and are
available to be called by your application within your Application Module.
These functions are listed in alphabetical order.

=head3 delete()

    $webapp->delete('my_param');

The delete() method is used to delete a parameter that was previously
stored inside of your application either by using the PARAMS hash that
was passed in your call to new() or by a call to the param() method.
This is similar to the delete() method of CGI.pm. It is useful if your
application makes decisions based on the existence of certain params that
may have been removed in previous sections of your app or simply to
clean-up your param()s.


=head3 dump()

    print STDERR $webapp->dump();

The dump() method is a debugging function which will return a
chunk of text which contains all the environment and web form
data of the request, formatted nicely for human readability.
Useful for outputting to STDERR.


=head3 dump_html()

    my $output = $webapp->dump_html();

The dump_html() method is a debugging function which will return
a chunk of text which contains all the environment and web form
data of the request, formatted nicely for human readability via
a web browser.  Useful for outputting to a browser.

=head3 error_mode()

    $webapp->error_mode('my_error_rm');

If the runmode dies for whatever reason, C<run() will> see if you have set a
value for C<error_mode()>. If you have, C<run()> will call that method
as a run mode, passing $@ as the only parameter.

Plugins authors will be interested to know that just before C<error_mode()> is
called, the C<error> hook will be executed, with the error message passed in as
the only parameter. 

No C<error_mode> is defined by default.  The death of your C<error_mode()> run
mode is not trapped, so you can also use it to die in your own special way.

For a complete integrated logging solution, check out L<CGI::Application::Plugin::LogDispatch>.

=head3 get_current_runmode()

    $webapp->get_current_runmode();

The C<get_current_runmode()> method will return a text scalar containing
the name of the run mode which is currently being executed.  If the
run mode has not yet been determined, such as during setup(), this method
will return undef.

=head3 header_add()

    # add or replace the 'type' header
    $webapp->header_add( -type => 'image/png' );

    - or -

    # add an additional cookie
    $webapp->header_add(-cookie=>[$extra_cookie]);

The C<header_add()> method is used to add one or more headers to the outgoing
response headers.  The parameters will eventually be passed on to the CGI.pm
header() method, so refer to the L<CGI> docs for exact usage details.

Unlike calling C<header_props()>, C<header_add()> will preserve any existing
headers. If a scalar value is passed to C<header_add()> it will replace
the existing value for that key.

If an array reference is passed as a value to C<header_add()>, values in
that array ref will be appended to any existing values values for that key.
This is primarily useful for setting an additional cookie after one has already
been set.

=head3 header_props()

    # Set a complete set of headers
    %set_headers = $webapp->header_props(-type=>'image/gif',-expires=>'+3d');

    # clobber / reset all headers
    %set_headers = $webapp->header_props({});

    # Just retrieve the headers 
    %set_headers = $webapp->header_props(); 

The C<header_props()> method expects a hash of CGI.pm-compatible
HTTP header properties.  These properties will be passed directly
to the C<header()> or C<redirect()> methods of the query() object. Refer
to the docs of your query object for details. (Be default, it's L<CGI>.pm).

Calling header_props with an empty hashref clobber any existing headers that have
previously set.

C<header_props()> returns a hash of all the headers that have currently been
set. It can be called with no arguments just to get the hash current headers
back.

To add additional headers later without clobbering the old ones,
see C<header_add()>.

B<IMPORTANT NOTE REGARDING HTTP HEADERS>

It is through the C<header_props()> and C<header_add()> method that you may modify the outgoing
HTTP headers.  This is necessary when you want to set a cookie, set the mime
type to something other than "text/html", or perform a redirect.  The
header_props() method works in conjunction with the header_type() method.
The value contained in header_type() determines if we use CGI::header() or
CGI::redirect().  The content of header_props() is passed as an argument to
whichever CGI.pm function is called.

Understanding this relationship is important if you wish to manipulate
the HTTP header properly.

=head3 header_type()

    $webapp->header_type('redirect');
    $webapp->header_type('none');

This method used to declare that you are setting a redirection header,
or that you want no header to be returned by the framework. 

The value of 'header' is almost never used, as it is the default. 

B<Example of redirecting>:

  sub some_redirect_mode {
    my $self = shift;
    # do stuff here.... 
    $self->header_type('redirect');
    $self->header_props(-url=>  "http://site/path/doc.html" );
  }

To simplify that further, use L<CGI::Application::Plugin::Redirect>:

    return $self->redirect('http://www.example.com/');

Setting the header to 'none' may be useful if you are streaming content.
In other contexts, it may be more useful to set C<$ENV{CGI_APP_RETURN_ONLY} = 1;>,
which supresses all printing, including headers, and returns the output instead.

That's commonly used for testing, or when using L<CGI::Application> as a controller
for a cron script!

=cut

sub html_tmpl_class { 
    my $self = shift;
    my $tmpl_class = shift;

	# First use?  Create new __ERROR_MODE
	$self->{__HTML_TMPL_CLASS} = 'HTML::Template' unless (exists($self->{__HTML_TMPL_CLASS}));

    if (defined $tmpl_class) {
        $self->{__HTML_TMPL_CLASS} = $tmpl_class;
    }

    return $self->{__HTML_TMPL_CLASS};
}

sub load_tmpl {
	my $self = shift;
	my ($tmpl_file, @extra_params) = @_;

	# add tmpl_path to path array if one is set, otherwise add a path arg
	if (my $tmpl_path = $self->tmpl_path) {
		my @tmpl_paths = (ref $tmpl_path eq 'ARRAY') ? @$tmpl_path : $tmpl_path;
		my $found = 0;
		for( my $x = 0; $x < @extra_params; $x += 2 ) {
			if ($extra_params[$x] eq 'path' and
			ref $extra_params[$x+1] eq 'ARRAY') {
				unshift @{$extra_params[$x+1]}, @tmpl_paths;
				$found = 1;
				last;
			}
		}
		push(@extra_params, path => [ @tmpl_paths ]) unless $found;
	}

    my %tmpl_params = ();
    my %ht_params = @extra_params;
    %ht_params = () unless keys %ht_params;

    # Define our extension if doesn't already exist;
    $self->{__CURRENT_TMPL_EXTENSION} = '.html' unless defined $self->{__CURRENT_TMPL_EXTENSION};

    # Define a default template name based on the current run mode
    unless (defined $tmpl_file) {
        $tmpl_file = $self->get_current_runmode . $self->{__CURRENT_TMPL_EXTENSION};    
    }

    $self->call_hook('load_tmpl', \%ht_params, \%tmpl_params, $tmpl_file);

    my $ht_class = $self->html_tmpl_class;
     eval "require $ht_class;" || die "require $ht_class failed: $@";

    # let's check $tmpl_file and see what kind of parameter it is - we
    # now support 3 options: scalar (filename), ref to scalar (the
    # actual html/template content) and reference to FILEHANDLE
    my $t = undef;
    if ( ref $tmpl_file eq 'SCALAR' ) {
        $t = $ht_class->new( scalarref => $tmpl_file, %ht_params );
    } elsif ( ref $tmpl_file eq 'GLOB' ) {
        $t = $ht_class->new( filehandle => $tmpl_file, %ht_params );
    } else {
        $t = $ht_class->new( filename => $tmpl_file, %ht_params);
    }

    if (keys %tmpl_params) {
        $t->param(%tmpl_params);
    }

	return $t;
}

=pod

=head3 mode_param()

 # Name the CGI form parameter that contains the run mode name.
 # This is the the default behavior, and is often sufficient.
 $webapp->mode_param('rm');

 # Set the run mode name directly from a code ref
 $webapp->mode_param(\&some_method);

 # Alternate interface, which allows you to set the run
 # mode name directly from $ENV{PATH_INFO}.
 $webapp->mode_param(
 	path_info=> 1,
 	param =>'rm'
 );

This accessor/mutator method is generally called in the setup() method.
It is used to help determine the run mode to call. There are three options for calling it.

 $webapp->mode_param('rm');

Here, a CGI form parameter is named that will contain the name of the run mode
to use. This is the default behavior, with 'rm' being the parameter named used.

 $webapp->mode_param(\&some_method);

Here a code reference is provided. It will return the name of the run mode
to use directly. Example:

 sub some_method {
   my $self = shift;
   return 'run_mode_x';
 }

This would allow you to programmatically set the run mode based on arbitrary logic.

 $webapp->mode_param(
 	path_info=> 1,
 	param =>'rm'
 );

This syntax allows you to easily set the run mode from $ENV{PATH_INFO}.  It
will try to set the run mode from the first part of $ENV{PATH_INFO} (before the
first "/"). To specify that you would rather get the run mode name from the 2nd
part of $ENV{PATH_INFO}:

 $webapp->mode_param( path_info=> 2 );

This also demonstrates that you don't need to pass in the C<param> hash key. It will
still default to C<rm>.

You can also set C<path_info> to a negative value. This works just like a negative
list index: if it is -1 the run mode name will be taken from the last part of 
$ENV{PATH_INFO}, if it is -2, the one before that, and so on.


If no run mode is found in $ENV{PATH_INFO}, it will fall back to looking in the
value of a the CGI form field defined with 'param', as described above.  This
allows you to use the convenient $ENV{PATH_INFO} trick most of the time, but
also supports the edge cases, such as when you don't know what the run mode
will be ahead of time and want to define it with JavaScript.

B<More about $ENV{PATH_INFO}>.

Using $ENV{PATH_INFO} to name your run mode creates a clean separation between
the form variables you submit and how you determine the processing run mode. It
also creates URLs that are more search engine friendly. Let's look at an
example form submission using this syntax:

	<form action="/cgi-bin/instance.cgi/edit_form" method=post>
		<input type="hidden" name="breed_id" value="4">
	
Here the run mode would be set to "edit_form". Here's another example with a
query string:

	/cgi-bin/instance.cgi/edit_form?breed_id=2

This demonstrates that you can use $ENV{PATH_INFO} and a query string together
without problems. $ENV{PATH_INFO} is defined as part of the CGI specification
should be supported by any web server that supports CGI scripts.

=cut

sub mode_param {
	my $self = shift;
	my $mode_param;

	# First use?  Create new __MODE_PARAM
	$self->{__MODE_PARAM} = 'rm' unless (exists($self->{__MODE_PARAM}));

	my %p;
	# expecting a scalar or code ref
	if ((scalar @_) == 1) {
		$mode_param = $_[0];
	}
	# expecting hash style params
	else {
		croak("CGI::Application->mode_param() : You gave me an odd number of parameters to mode_param()!")
		unless ((@_ % 2) == 0);
		%p = @_;
		$mode_param = $p{param};

		if ( $p{path_info} && $self->query->path_info() ) {
			my $pi = $self->query->path_info();

			my $idx = $p{path_info};
			# two cases: negative or positive index
			# negative index counts from the end of path_info
			# positive index needs to be fixed because 
			#    computer scientists like to start counting from zero.
			$idx -= 1 if ($idx > 0) ;	

			# remove the leading slash
			$pi =~ s!^/!!;

			# grab the requested field location
			$pi = (split q'/', $pi)[$idx] || '';

			$mode_param = (length $pi) ?  { run_mode => $pi } : $mode_param;
		}

	}

	# If data is provided, set it
	if (defined $mode_param and length $mode_param) {
		$self->{__MODE_PARAM} = $mode_param;
	}

	return $self->{__MODE_PARAM};
}


=head3 prerun_mode()

    $webapp->prerun_mode('new_run_mode');

The prerun_mode() method is an accessor/mutator which can be used within
your cgiapp_prerun() method to change the run mode which is about to be executed.
For example, consider:

  # In WebApp.pm:
  package WebApp;
  use base 'CGI::Application';
  sub cgiapp_prerun {
	my $self = shift;

	# Get the web user name, if any
	my $q = $self->query();
	my $user = $q->remote_user();

	# Redirect to login, if necessary
	unless ($user) {
		$self->prerun_mode('login');
	}
  }


In this example, the web user will be forced into the "login" run mode
unless they have already logged in.  The prerun_mode() method permits
a scalar text string to be set which overrides whatever the run mode
would otherwise be.

The use of prerun_mode() within cgiapp_prerun() differs from setting
mode_param() to use a call-back via subroutine reference.  It differs
because cgiapp_prerun() allows you to selectively set the run mode based
on some logic in your cgiapp_prerun() method.  The call-back facility of
mode_param() forces you to entirely replace CGI::Application's mechanism
for determining the run mode with your own method.  The prerun_mode()
method should be used in cases where you want to use CGI::Application's
normal run mode switching facility, but you want to make selective
changes to the mode under specific conditions.

B<Note:>  The prerun_mode() method may ONLY be called in the context of
a cgiapp_prerun() method.  Your application will die() if you call
prerun_mode() elsewhere, such as in setup() or a run mode method.

=head2 Dispatching Clean URIs to run modes

Modern web frameworks dispense with cruft in URIs, providing in clean
URIs instead. Instead of: 

 /cgi-bin/item.cgi?rm=view&id=15

A clean URI to describe the same resource might be:

 /item/15/view

The process of mapping these URIs to run modes is called dispatching and is
handled by L<CGI::Application::Dispatch>. Dispatching is not required and is a
layer you can fairly easily add to an application later.

=head2 Offline website development

You can work on your CGI::Application project on your desktop or laptop without
installing a full-featured web-server like Apache. Instead, install 
L<CGI::Application::Server> from CPAN. After a few minutes of setup, you'll
have your own private application server up and running. 

=head2 Automated Testing

There a couple of testing modules specifically made for CGI::Application.

L<Test::WWW::Mechanize::CGIApp> allows functional testing of a CGI::App-based project
without starting a web server. L<Test::WWW::Mechanize> could be used to test the app
through a real web server. 

L<Test::WWW::Selenium::CGIApp> is similar, but uses Selenium for the testing,
meaning that a local web-browser would be used, allowing testing of websites
that contain JavaScript.

Direct testing is also easy. CGI::Application will normally print the output of it's
run modes directly to STDOUT. This can be suppressed with an enviroment variable, 
CGI_APP_RETURN_ONLY. For example:

  $ENV{CGI_APP_RETURN_ONLY} = 1;
  $output = $webapp->run();
  like($output, qr/good/, "output is good");

Examples of this style can be seen in our own test suite. 

=head1 PLUG-INS

CGI::Application has a plug-in architecture that is easy to use and easy
to develop new plug-ins for.

=head2 Recommended Plug-ins

The following plugins are recommended for general purpose web/db development:  

=over 4

=item * 

L<CGI::Application::Plugin::Redirect> - is a simple plugin to provide a shorter syntax for executing a redirect. 

=item *

L<CGI::Application::Plugin::ConfigAuto> - Keeping your config details in a separate file is recommended for every project. This one integrates with L<Config::Auto>. Several more config plugin options are listed below.  

=item *

L<CGI::Application::Plugin::DBH> - Provides easy management of one or more database handles and can delay making the database connection until the moment it is actually used. 

=item *

L<CGI::Application::Plugin::FillInForm> - makes it a breeze to fill in an HTML form from data originating from a CGI query or a database record. 

=item *

L<CGI::Application::Plugin::Session> - For a project that requires session
management, this plugin provides a useful wrapper around L<CGI::Session> 

=item *

L<CGI::Application::Plugin::ValidateRM> - Integration with Data::FormValidator and HTML::FillInForm

=back

=head2 More plug-ins

Many more plugins are available as alternatives and for specific uses. For a
current complete list, please consult CPAN:

http://search.cpan.org/search?m=dist&q=CGI%2DApplication%2DPlugin

=over 4

=item *

L<CGI::Application::Plugin::AnyTemplate> - Use any templating system from within CGI::Application using a unified interface

=item *

L<CGI::Application::Plugin::Apache> - Use Apache::* modules without interference

=item * 

L<CGI::Application::Plugin::AutoRunmode> - Automatically register runmodes 


=item *

L<CGI::Application::Plugin::Config::Context> - Integration with L<Config::Context>.

=item *

L<CGI::Application::Plugin::Config::General> - Integration with L<Config::General>.

=item *

L<CGI::Application::Plugin::Config::Simple> - Integration with L<Config::Simple>.

=item * 

L<CGI::Application::Plugin::CompressGzip> - Add Gzip compression


=item *

L<CGI::Application::Plugin::LogDispatch> - Integration with L<Log::Dispatch>

=item *

L<CGI::Application::Plugin::Stream> - Help stream files to the browser

=item *

L<CGI::Application::Plugin::TemplateRunner> - Allows for more of an ASP-style
code structure, with the difference that code and HTML for each screen are in
separate files. 

=item *

L<CGI::Application::Plugin::TT> - Use L<Template::Toolkit> as an alternative to HTML::Template.


=back



Consult each plug-in for the exact usage syntax.

=head2 Writing Plug-ins

Writing plug-ins is simple. Simply create a new package, and export the
methods that you want to become part of a CGI::Application project. See
L<CGI::Application::Plugin::ValidateRM> for an example.

In order to avoid namespace conflicts within a CGI::Application object,
plugin developers are recommended to use a unique prefix, such as the
name of plugin package, when storing information. For instance:

 $app->{__PARAM} = 'foo'; # BAD! Could conflict.
 $app->{'MyPlugin::Module::__PARAM'} = 'foo'; # Good.
 $app->{'MyPlugin::Module'}{__PARAM} = 'foo'; # Good.

=head2 Writing Advanced Plug-ins - Using callbacks

When writing a plug-in, you may want some action to happen automatically at a
particular stage, such as setting up a database connection or initializing a
session. By using these 'callback' methods, you can register a subroutine
to run at a particular phase, accomplishing this goal.

B<Callback Examples>

  # register a callback to the standard CGI::Application hooks
  #   one of 'init', 'prerun', 'postrun', 'teardown' or 'load_tmpl'
  # As a plug-in author, this is probably the only method you need.

  # Class-based: callback will persist for all runs of the application
  $class->add_callback('init', \&some_other_method);

  # Object-based: callback will only last for lifetime of this object
  $self->add_callback('prerun', \&some_method);

  # If you want to create a new hook location in your application,
  # You'll need to know about the following two methods to create
  # the hook and call it.

  # Create a new hook
  $self->new_hook('pretemplate');

  # Then later execute all the callbacks registered at this hook
  $self->call_hook('pretemplate');

B<Callback Methods>

=head3 add_callback()

	$self->add_callback ('teardown', \&callback);
	$class->add_callback('teardown', 'method');

The add_callback method allows you to register a callback
function that is to be called at the given stage of execution.
Valid hooks include 'init', 'prerun', 'postrun' and 'teardown',
'load_tmpl', and any other hooks defined using the C<new_hook>
method.

The callback should be a reference to a subroutine or the name of a
method.

If multiple callbacks are added to the same hook, they will all be
executed one after the other.  The exact order depends on which class
installed each callback, as described below under B<Callback Ordering>.

Callbacks can either be I<object-based> or I<class-based>, depending
upon whether you call C<add_callback> as an object method or a class
method:

	# add object-based callback
	$self->add_callback('teardown', \&callback);

	# add class-based callbacks
	$class->add_callback('teardown', \&callback);
	My::Project->add_callback('teardown', \&callback);

Object-based callbacks are stored in your web application's C<$c>
object; at the end of the request when the C<$c> object goes out of
scope, the callbacks are gone too.

Object-based callbacks are useful for one-time tasks that apply only to
the current running application.  For instance you could install a
C<teardown> callback to trigger a long-running process to execute at the
end of the current request, after all the HTML has been sent to the
browser.

Class-based callbacks survive for the duration of the running Perl
process.  (In a persistent environment such as C<mod_perl> or
C<PersistentPerl>, a single Perl process can serve many web requests.)

Class-based callbacks are useful for plugins to add features to all web
applications.

Another feature of class-based callbacks is that your plugin can create
hooks and add callbacks at any time - even before the web application's
C<$c> object has been initialized.  A good place to do this is in
your plugin's C<import> subroutine:

	package CGI::Application::Plugin::MyPlugin;
	use base 'Exporter';
	sub import {
		my $caller = scalar(caller);
		$caller->add_callback('init', 'my_setup');
		goto &Exporter::import;
	}

Notice that C<< $caller->add_callback >> installs the callback
on behalf of the module that contained the line:

	use CGI::Application::Plugin::MyPlugin;

=cut

sub add_callback {
	my ($c_or_class, $hook, $callback) = @_;

	$hook = lc $hook;

	die "no callback provided when calling add_callback" unless $callback;
	die "Unknown hook ($hook)"                           unless exists $INSTALLED_CALLBACKS{$hook};

	if (ref $c_or_class) {
		# Install in object
		my $self = $c_or_class;
		push @{ $self->{__INSTALLED_CALLBACKS}{$hook} }, $callback;
	}
	else {
		# Install in class
		my $class = $c_or_class;
		push @{ $INSTALLED_CALLBACKS{$hook}{$class} }, $callback;
	}

}

=head3 new_hook(HOOK)

    $self->new_hook('pretemplate');

The C<new_hook()> method can be used to create a new location for developers to
register callbacks.  It takes one argument, a hook name. The hook location is
created if it does not already exist. A true value is always returned.

For an example, L<CGI::Application::Plugin::TT> adds hooks before and after every
template is processed.

See C<call_hook(HOOK)> for more details about how hooks are called.

=cut

sub new_hook {
	my ($class, $hook) = @_;
	$INSTALLED_CALLBACKS{$hook} ||= {};
	return 1;
}

=head3 call_hook(HOOK)

    $self->call_hook('pretemplate', @args);

The C<call_hook> method is used to executed the callbacks that have been registered
at the given hook.  It is used in conjunction with the C<new_hook> method which
allows you to create a new hook location.

The first argument to C<call_hook> is the hook name. Any remaining arguments
are passed to every callback executed at the hook location. So, a stub for a 
callback at the 'pretemplate' hook would look like this:

 sub my_hook {
    my ($c,@args) = @_;
    # ....
 }

Note that hooks are semi-public locations. Calling a hook means executing
callbacks that were registered to that hook by the current object and also
those registered by any of the current object's parent classes.  See below for
the exact ordering.

=cut

sub call_hook {
	my $self      = shift;
	my $app_class = ref $self || $self;
	my $hook      = lc shift;
	my @args      = @_;

	die "Unknown hook ($hook)" unless exists $INSTALLED_CALLBACKS{$hook};

	my %executed_callback;

	# First, run callbacks installed in the object
	foreach my $callback (@{ $self->{__INSTALLED_CALLBACKS}{$hook} }) {
		next if $executed_callback{$callback};
		eval { $self->$callback(@args); };
		$executed_callback{$callback} = 1;
		die "Error executing object callback in $hook stage: $@" if $@;
	}

	# Next, run callbacks installed in class hierarchy

	# Cache this value as a performance boost
	$self->{__CALLBACK_CLASSES} ||=  [ Class::ISA::self_and_super_path($app_class) ];

	# Get list of classes that the current app inherits from
	foreach my $class (@{ $self->{__CALLBACK_CLASSES} }) {

		# skip those classes that contain no callbacks
		next unless exists $INSTALLED_CALLBACKS{$hook}{$class};

		# call all of the callbacks in the class
		foreach my $callback (@{ $INSTALLED_CALLBACKS{$hook}{$class} }) {
			next if $executed_callback{$callback};
			eval { $self->$callback(@args); };
			$executed_callback{$callback} = 1;
			die "Error executing class callback in $hook stage: $@" if $@;
		}
	}

}

=pod

B<Callback Ordering>

Object-based callbacks are run before class-based callbacks.

The order of class-based callbacks is determined by the inheritance tree of the
running application. The built-in methods of C<cgiapp_init>, C<cgiapp_prerun>,
C<cgiapp_postrun>, and C<teardown> are also executed this way, according to the
ordering below.

In a persistent environment, there might be a lot of applications
in memory at the same time.  For instance:

	CGI::Application
	  Other::Project   # uses CGI::Application::Plugin::Baz
		 Other::App    # uses CGI::Application::Plugin::Bam

	  My::Project      # uses CGI::Application::Plugin::Foo
		 My::App       # uses CGI::Application::Plugin::Bar

Suppose that each of the above plugins each added a callback to be run
at the 'init' stage:

	Plugin                           init callback
	------                           -------------
	CGI::Application::Plugin::Baz    baz_startup
	CGI::Application::Plugin::Bam    bam_startup

	CGI::Application::Plugin::Foo    foo_startup
	CGI::Application::Plugin::Bar    bar_startup

When C<My::App> runs, only C<foo_callback> and C<bar_callback> will
run.  The other callbacks are skipped.

The C<@ISA> list of C<My::App> is:

	My::App
	My::Project
	CGI::Application

This order determines the order of callbacks run.

When C<call_hook('init')> is run on a C<My::App> application, callbacks
installed by these modules are run in order, resulting in:
C<bar_startup>, C<foo_startup>, and then finally C<cgiapp_init>.

If a single class installs more than one callback at the same hook, then
these callbacks are run in the order they were registered (FIFO).



=cut


=head1 COMMUNITY

Therese are primary resources available for those who wish to learn more
about CGI::Application and discuss it with others.

B<Wiki>

This is a community built and maintained resource that anyone is welcome to
contribute to. It contains a number of articles of its own and links
to many other CGI::Application related pages:

L<http://www.cgi-app.org>

B<Support Mailing List>

If you have any questions, comments, bug reports or feature suggestions,
post them to the support mailing list!  To join the mailing list, simply
send a blank message to "cgiapp-subscribe@lists.erlbaum.net".

B<IRC>

You can also drop by C<#cgiapp> on C<irc.perl.org> with a good chance of finding 
some people involved with the project there. 

B<Source Code>

This project is managed using git and is available on Github:

    https://github.com/markstos/CGI--Application

=head1 SEE ALSO

=over 4

=item o 

L<CGI>

=item o 

L<HTML::Template>

=item o

B<CGI::Application::Framework> - A full-featured web application based on
CGI::Application.  http://www.cafweb.org/

=back

=head1 MORE READING

If you're interested in finding out more about CGI::Application, the
following articles are available on Perl.com:

    Using CGI::Application
    http://www.perl.com/pub/a/2001/06/05/cgi.html

    Rapid Website Development with CGI::Application
    http://www.perl.com/pub/a/2006/10/19/cgi_application.html

Thanks to O'Reilly for publishing these articles, and for the incredible value
they provide to the Perl community!

=head1 AUTHOR

Jesse Erlbaum <jesse@erlbaum.net>

Mark Stosberg has served as a co-maintainer since version 3.2, with the help of
the numerous contributors documented in the Changes file.

=head1 CREDITS

CGI::Application was originally developed by The Erlbaum Group, a software
engineering and consulting firm in New York City. 

Thanks to Vanguard Media (http://www.vm.com) for funding the initial
development of this library and for encouraging Jesse Erlbaum to release it to
the world.

Many thanks to Sam Tregar (author of the most excellent
HTML::Template module!) for his innumerable contributions
to this module over the years, and most of all for getting
me off my ass to finally get this thing up on CPAN!

Many other people have contributed specific suggestions or patches,
which are documented in the C<Changes> file.

Thanks also to all the members of the CGI-App mailing list!
Your ideas, suggestions, insights (and criticism!) have helped
shape this module immeasurably.  (To join the mailing list, simply
send a blank message to "cgiapp-subscribe@lists.erlbaum.net".)

=head1 LICENSE

CGI::Application : Framework for building reusable web-applications
Copyright (C) 2000-2003 Jesse Erlbaum <jesse@erlbaum.net>

This module is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version,

or

b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA


=cut

