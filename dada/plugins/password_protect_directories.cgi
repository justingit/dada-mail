#!/usr/bin/perl
use strict; 

$|++;

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

use lib qw(
	../ 
	../DADA/perllib
);

use CGI::Carp "fatalsToBrowser";
use DADA::Config 5.0.0 qw(!:DEFAULT);
use DADA::App::Guts; 
use DADA::MailingList::Settings;

# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);
my $verbose = $q->param('verbose') || 1; 

my $Plugin_Config                = {}; 
   $Plugin_Config->{Plugin_Name} = 'Password Protect Directories'; 
   $Plugin_Config->{Plugin_URL}  = $q->url; 
	$Plugin_Config->{Allow_Manual_Run} = 1; 


&init_vars; 

run()
	unless caller();

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{htpasswd_Manager}->{$key} ) ) {

            if ( defined( $DADA::Config::PLUGIN_CONFIGS->{htpasswd_Manager}->{$key} ) ) {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{htpasswd_Manager}->{$key};

            }
        }
    }
}

my $list       = undef;
my $root_login = 0;
my $ls; 

sub run {
	
	if ( !$ENV{GATEWAY_INTERFACE} ) {
	
		DADA::Mail::MailOut::refresh_directories( { -verbose => $verbose } );
        # this (hopefully) means we're running on the cl...
    }
	elsif (   keys %{ $q->Vars }
        && $q->param('run')
        && xss_filter( $q->param('run') ) == 1
        && $Plugin_Config->{Allow_Manual_Run} == 1 )
    {
		print $q->header(); 
		print '<pre>'
		if $verbose; 
		refresh_directories( { -verbose => $verbose } );
           print '</pre>'
		 if $verbose; 
	}
	else { 
		my $admin_list; 
		( $admin_list, $root_login ) = check_list_security(
		    -cgi_obj  => $q,
		    -Function => 'password_protect_directories'
		);
		$list = $admin_list;
		$ls   = DADA::MailingList::Settings->new( { -list => $list } );
	
		my $f = $q->param('f') || undef;
		my %Mode = (
		    'default'                    => \&default,
			'edit_dir'                   => \&default, 
			'process_edit_dir'           => \&process_edit_dir, 
			'new_dir'                    => \&new_dir, 
			'delete_dir'                 => \&delete_dir, 
			'cgi_refresh_directories'    => \&cgi_refresh_directories, 
		);
		if ($f) {
		    if ( exists( $Mode{$f} ) ) {
		        $Mode{$f}->();    #call the correct subroutine
		    }
		    else {
		        &default;
		    }
		}
		else {
		    &default;
		}
	}
}

sub cgi_refresh_directories { 
	$verbose = 0; 
	refresh_directories(); 
	print $q->redirect(-uri => $Plugin_Config->{Plugin_URL} . '?done=1'); 
}
sub refresh_directories {
	print "Starting...\n"
	 if $verbose; 
	foreach my $list(available_lists()) { 
		print "List: $list\n"
			 if $verbose; 
		my $htp     = htpasswdWriter->new({-list => $list});
		for my $id(@{$htp->get_all_ids}) {  
			print "id: $id\n"
				 if $verbose; 
			$htp->setup_directory({-id => $id});
		}
	}
	print "Done.\n"
		if $verbose;
}

sub default_tmpl {

    my $tmpl = q{ 

<!-- tmpl_set name="title" value="Password Protect Directories" --> 
<div id="screentitle"> 
	<div id="screentitlepadding">
		<!-- tmpl_var title --> 
	</div>
	<!-- tmpl_include help_link_widget.tmpl -->
</div>
<!-- tmpl_if done --> 
	<!-- tmpl_include changes_saved_dialog_box_widget.tmpl  -->
<!-- /tmpl_if --> 

<!-- tmpl_if problems --> 
	<div class="badweatherbox">

	<p><strong>Problems were found with the information you just submitted:</strong></p> 
	<ul>
	<!-- tmpl_loop errors --> 
		<li><!-- tmpl_var error --></li>
	<!-- /tmpl_loop --> 
	</ul>
	</div>
<!-- /tmpl_if --> 

<!-- tmpl_unless edit --> 

	<!-- tmpl_if entries --> 

		<fieldset> 
			<legend>Current Password Protected Directories</legend> 
		
				<!-- tmpl_loop entries --> 
		
				<fieldset> 
				<legend><!-- tmpl_var name --></legend>
			
				<table class="stripedtable">
		
				<!--  <tr> 
					<td><strong>ID</strong></td> <td><!-- tmpl_var id --></td> 
					</tr>
		 
						<tr> 
						<td><strong>Name</strong></td><td><!-- tmpl_var name --></td>
						</tr>
		
				--> 
		
		
				 	<tr> 
					<td><strong>Path</strong></td><td><!-- tmpl_var path --></td>
					</tr>
				 	<tr> 

					<td><strong>url</strong></td><td><!-- tmpl_var url --></td>
					</tr>
				 	<tr> 

					<td><strong>use_custom_error_page</strong></td><td><!-- tmpl_var use_custom_error_page --></td>
					</tr>
				 	<tr> 

					<td><strong>custom_error_page</strong></td><td><!-- tmpl_var custom_error_page --></td>
					</tr>
				<!--  	
				<tr> 

					<td><strong>default_password</strong></td><td><!-- tmpl_var default_password --></td>
				</tr>
				--> 
			</table> 
			<div class="buttonfloat">
		
				<form action="<!-- tmpl_var Plugin_URL -->" method="post" accept-charset="<!-- tmpl_var HTML_CHARSET -->"> 
					<input type="hidden" name="f" value="edit_dir" /> 
					<input type="hidden" name="id" value="<!-- tmpl_var id -->" /> 
					<input type="submit" class="processing" value="Edit " />
	
		
				</form>
			
			
			<form action="<!-- tmpl_var Plugin_URL -->" method="post" accept-charset="<!-- tmpl_var HTML_CHARSET -->"> 
				<input type="hidden" name="f" value="delete_dir" /> 
				<input type="hidden" name="id" value="<!-- tmpl_var id -->" /> 
		
				<input type="submit" class="alertive" value="Delete " />
					</form> 
			
					</div>
				<div class="floatclear"></div>
				
	
			</fieldset> 
	
			<!-- /tmpl_loop --> 
		</fieldset> 

	<!-- /tmpl_if --> 
<!-- /tmpl_unless --> 


<fieldset> 
<!-- tmpl_unless edit --> 
	<legend>New Password Protected Directory</legend> 
<!-- tmpl_else --> 
	<legend>Edit Password Protected Directory</legend> 
<!-- /tmpl_unless --> 

<form action="<!-- tmpl_var Plugin_URL -->" method="post" accept-charset="<!-- tmpl_var HTML_CHARSET -->"> 
<table class="stripedtable">
<tr>
	<td width="200px">
	 <label>
	  Name
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="name" value="" class="full" />
	</td>
</tr>
<tr>
<td width="200px">
	 <label>
	  Path
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="path" value="" class="full" />
	</td>
</tr>
<tr>
<td width="200px">
	 <label>
	  URL
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="url" value="" class="full" />
	</td>
</tr>
<tr>
<td width="200px">
	 <label>
	  Use a Custom Error Page? 
	 </label>
	</td>
	<td align="left">
	 <input type="checkbox" name="use_custom_error_page" value="1" />
	</td>
</tr>

<tr>
<td width="200px">
	 <label>
	  Custom Error Page:
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="custom_error_page" value="" class="full" />
	</td>
</tr>

<!-- tmpl_unless edit --> 

	<tr>
	<td width="200px">
		 <label>
		  Default Password
		 </label>
		</td>
		<td align="left">
		 <input type="text" name="default_password" value="" class="full" />
		</td>
	</tr>

<!-- /tmpl_unless --> 


</table>

<!-- tmpl_unless edit --> 
	<input type="hidden" name="f" value="new_dir" /> 
<!-- tmpl_else --> 
	<input type="hidden" name="id" value="<!-- tmpl_var id -->" /> 
	<input type="hidden" name="f" value="process_edit_dir" /> 
<!-- /tmpl_unless --> 

<div class="buttonfloat">
 <input type="reset"  class="cautionary" value="Clear All Changes" />
 <input type="submit" class="processing" value="Save All Changes" />
</div>
<div class="floatclear"></div>

</form> 

</fieldset> 


};

	return $tmpl;

}




sub default {
	
	my $htp     = htpasswdWriter->new({-list => $list});
	my $entries = $htp->get_all_entries; 
	
	my $problems = $q->param('problems') || 0; 
	my $edit     = 0; 
	my $f        = $q->param('f'); 
	my $id       = undef; 
	if($f eq 'edit_dir'){ 
		$id = $q->param('id') || undef; 
		my $htp = htpasswdWriter->new({-list => $list});
		my $entry = $htp->get({-id => $id });
		$edit = 1; 
		$q->param('name', $entry->{name});
		$q->param('path', $entry->{path});
		$q->param('url', $entry->{url});
		
		$q->param('use_custom_error_page', $entry->{use_custom_error_page});
		$q->param('custom_error_page', $entry->{custom_error_page});
		$q->param('f', 'process_edit_dir'); 
	}
	my $errors = [];
	if($problems == 1){ 
		my %params = $q->Vars;
		for(keys %params){ 
			if($_ =~ m/^error_/){
				push(@$errors, {error => $_}); 
			}
		}
	}
    my $tmpl = default_tmpl();
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $ls->param('list'),
            },
            -vars => {
                done                             => $q->param('done') || 0,
				Plugin_URL                       => $Plugin_Config->{Plugin_URL}, 
				entries                          => $entries, 
				problems                         => $problems, 
				errors                           => $errors, 
				edit                             => $edit, 
				id                               => $id, 
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );

	if($problems == 1 || $edit == 1){ 
		require HTML::FillInForm::Lite;
		my $h = HTML::FillInForm::Lite->new();
		$scrn = $h->fill( \$scrn, $q );
	}
	
	
    e_print($scrn);

}


sub new_dir { 
    my $name = xss_filter( $q->param('name') ) || "Untitled";
    my $path = xss_filter( $q->param('path') ) || undef;
    my $url  = xss_filter( $q->param('url') )  || undef;
    my $use_custom_error_page = xss_filter( $q->param('use_custom_error_page') ) || 0;
    my $custom_error_page = xss_filter( $q->param('custom_error_page') )|| undef;
    my $default_password = xss_filter( $q->param('default_password') ) || undef;
	
	
	my $htp = htpasswdWriter->new({-list => $list});
	
	my ($status, $errors) = $htp->validate_protected_dir(
		{ 
			-fields => { 
		        -name                  => $name,
		        -path                  => $path ,
				-url                   => $url,
				-use_custom_error_page => $use_custom_error_page,
				-custom_error_page     => $custom_error_page,
				-default_password      => $default_password,
			}, 
		}		
	); 
	if($status == 1){ 
	
		   $htp->create(
				{ 
			        -name                  => $name,
			        -path                  => $path ,
					-url                   => $url,
					-use_custom_error_page => $use_custom_error_page,
					-custom_error_page     => $custom_error_page,
					-default_password      => $default_password,
				}
			);
		print $q->redirect(-uri => $Plugin_Config->{Plugin_URL} . '?done=1'); 
	}
	else { 
		for(keys %$errors){ 
			$q->param('error_' . $_, $errors->{$_}); 
		}
		$q->param('problems', 1); 
		&default; 
		return; 
	}
}

sub process_edit_dir { 
	
	my $name = xss_filter( $q->param('name') ) || "Untitled";
    my $path = xss_filter( $q->param('path') ) || undef;
    my $url  = xss_filter( $q->param('url') )  || undef;
    my $use_custom_error_page = xss_filter( $q->param('use_custom_error_page') ) || 0;
    my $custom_error_page = xss_filter( $q->param('custom_error_page') )|| undef;
    my $default_password = xss_filter( $q->param('default_password') ) || undef;
	my $id               = xss_filter( $q->param('id') ) || undef;
	
	my $htp = htpasswdWriter->new({-list => $list});
	
	my ($status, $errors) = $htp->validate_protected_dir(
		{ 
			-fields => { 
		        -name                  => $name,
		        -path                  => $path ,
				-url                   => $url,
				-use_custom_error_page => $use_custom_error_page,
				-custom_error_page     => $custom_error_page,
				-default_password      => $default_password,
			}, 
		}		
	);
	if($status == 1){ 

	
		   $htp->update(
				{ 
					-id                    => $id, 
			        -name                  => $name,
			        -path                  => $path ,
					-url                   => $url,
					-use_custom_error_page => $use_custom_error_page,
					-custom_error_page     => $custom_error_page,
					-default_password      => $default_password,
				}
			);
		print $q->redirect(-uri => $Plugin_Config->{Plugin_URL} . '?done=1'); 
	}
	else { 
		for(keys %$errors){ 
			$q->param('error_' . $_, $errors->{$_}); 
		}
		$q->param('problems', 1); 
		$q->param('f', 'edit_dir');
		&default;  
		return; 
	}	
		
}

sub delete_dir { 
	my $id = $q->param('id'); 
	my $htp     = htpasswdWriter->new({-list => $list});
	   $htp->remove({-id => $id});
	print $q->redirect(-uri => $Plugin_Config->{Plugin_URL} . '?done=1'); 
	
}








package htpasswdWriter;
use DADA::App::Guts; 
use Carp qw(croak carp); 
my $t = 0; 

my %fields;

my $dbi_obj;

my $default_pass = 'test'; 


sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
    return $self;

}

sub _init {

    my $self = shift;

    my ($args) = @_;

    #$self->{'log'} = new DADA::Logging::Usage;

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    if ( $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ ) {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $self->{dbh} = $dbi_obj->dbh_obj;
    }
	if(!exists($args->{-list})){ 
		die "no list!";
	}
	else { 
		$self->{list} = $args->{-list}; 
	}
}
sub hello { 
	my $self = shift; 
	print "hello!\n"; 
}


sub validate_protected_dir { 
	my $self = shift; 
	my ($args) = @_; 
	
	my $status = 1; 
	my $errors = {}; 
	
	if(!exists($args->{-fields})){ 
		carp "you need to pass the fields in, -fields"; 
		return (0, $errors); 
	}
	if(!exists($args->{-fields}->{-name}) || !defined($args->{-fields}->{-name})) { 
		$errors->{missing_name} = 1;
		$status = 0; 
	}
	if(!exists($args->{-fields}->{-path}) || !defined($args->{-fields}->{-path})) { 
		$errors->{missing_path} = 1;
		$status = 0; 
	}
	if(! -d $args->{-fields}->{-path}){ 
		$errors->{path_no_exists} = 1; 
		$status = 0; 		
	} 
	if(!exists($args->{-fields}->{-url}) || !defined($args->{-fields}->{-url})) { 
		$errors->{missing_url} = 1; 
		$status = 0; 
	}
	
	if(! isa_url($args->{-fields}->{-url})){ 
		$errors->{url_no_exists} = 1; 
		$status = 0; 		
	}
	if($args->{-fields}->{-use_custom_error_page} !~ m/1|0/) { 
		$errors->{use_custom_error_page_set_funny} = 1; 
		$status = 0; 		
	}
	
	return ($status, $errors);
	
	#-name                  => $name,
    #-path                  => $path ,
	#-url                   => $url,
	#-use_custom_error_page => $use_custom_error_page,
	#-custom_error_page     => $custom_error_page,
	#-default_password      => $default_password,
		
}
sub create { 
	my $self  = shift; 
	my ($args) = @_; 
	# A bunch of data testing... 
	$self->insert($args);
}

sub insert {
	my $self = shift; 
	my ($args) = @_; 

	my $query =
      'INSERT INTO '
      . 'dada_password_protected_directories'
      . '(list, name, path, url, use_custom_error_page, custom_error_page, default_password) VALUES (?, ?, ?, ?, ?, ?, ?)';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute(
		$self->{list}, 
        $args->{ -name },
        $args->{ -path },
		$args->{ -url },
		$args->{ -use_custom_error_page },
		$args->{ -custom_error_page },
		DADA::Security::Password::encrypt_passwd($args->{ -default_password } ), 
      )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

	
}


sub update {
	my $self = shift; 
	my ($args) = @_; 
	my $query =
      'UPDATE '
      . 'dada_password_protected_directories'
      . ' SET name = ?, path = ?, url = ?, use_custom_error_page = ?, custom_error_page = ? where id = ?';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute(
        $args->{ -name },
        $args->{ -path },
		$args->{ -url },
		$args->{ -use_custom_error_page },
		$args->{ -custom_error_page },
		$args->{ -id }, 
      )
      or croak "cannot do statement (at insert)! $DBI::errstr\n";
    $sth->finish;

	
}




sub id_exists {
	
    my $self  = shift;
    my ($args) = @_;

	# This is saying, if we don't have a dbh handle, we don't have a proper 
	# "handle" on a profile. 
	
	if(! exists($self->{dbh})){ 
		return 0; 
	}
    my $query =
      'SELECT COUNT(*) FROM '
      . 'dada_password_protected_directories'
      . ' WHERE id = ?';

    my $sth = $self->{dbh}->prepare($query);

    warn 'QUERY: ' . $query
		if $t; 

    $sth->execute($args->{-id} )
      or croak "cannot do statement (at exists)! $DBI::errstr\n";
    my @row = $sth->fetchrow_array();
    $sth->finish;

	# autoviv?
    if($row[0]){ 
		return 1; 
	}
	else { 
		return 0; 
	}

}


sub get {

    my $self = shift;
    my ($args) = @_;

	if(! $self->id_exists( { -id => $args->{-id} } ) ){ 
		return undef; 
		# die "blah blah blah"; 
	}

    my $query =
      'SELECT * FROM '
      . 'dada_password_protected_directories'
      . " WHERE id = ?";

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-id} )
      or croak "cannot do statement (at get)! $DBI::errstr\n";

    my $info = {};
    my $hashref      = {};

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $info = $hashref;
        last FETCH;
    }

	return $info; 
	
}


sub remove {
	
    my $self = shift;
    my ($args) = @_;
	
	if(!exists($args->{-id})){ 
		croak "Cannot use this method without passing the '-id' param "; 
	}

    my $query =
      'DELETE  from '
      . 'dada_password_protected_directories'
      . ' WHERE id = ? ';

	warn 'QUERY: ' . $query
		if $t;

    my $sth = $self->{dbh}->prepare($query);

	my $rv = $sth->execute( $args->{ -id } )
      or croak "cannot do statment (at remove)! $DBI::errstr\n";

    $sth->finish;

    return $rv;

}

sub get_all_ids { 

	my $self = shift; 
	my ($args) = @_;
	my $query = 'SELECT id FROM ' . 'dada_password_protected_directories' . ' WHERE list = ? GROUP BY id ORDER BY id DESC;';
    my $ids = $self->{dbh}->selectcol_arrayref($query, {}, ($self->{list}));
	return $ids; 
}

sub get_all_entries { 
	my $self    = shift; 
	my $entries = []; 
	for my $id(@{$self->get_all_ids}){ 
		push(@$entries, $self->get({-id => $id})); 
	}
	return $entries; 
}

sub setup_directory { 
	my $self = shift; 
	my ($args) = @_; 
	$self->write_htaccess($args);
	$self->write_htpasswd($args);
	return 1; 
}
sub write_htaccess { 
	
	my $self = shift;
	my ($args) = @_; 
	
	my $entry = $self->get({-id => $args->{-id}}); 
	
	open my $htaccess, '>', $entry->{path} . '/' . '.htaccess' or die $! ;
	print $htaccess "
AuthType Basic
AuthName \"" . $entry->{name} . "\"
AuthUserFile " . $entry->{path} . "/.htpasswd
Require valid-user
";
if($entry->{use_custom_error_page} == 1 && defined($entry->{custom_error_page})){ 
	print $htaccess "ErrorDocument 401 " . $entry->{custom_error_page} . "\n";
}
else { 
	print $htaccess "ErrorDocument 401 /dada/mail.cgi?f=profile&error_profile_login=1\n";
}

	close $htaccess; 
}

sub write_htpasswd { 
	my $self = shift;
	my ($args) = @_; 
	
	my $entry = $self->get({-id => $args->{-id}}); 
	open my $htpasswd, '>', $entry->{path} . '/' . '.htpasswd' or die $! ;
	my $pt = $DADA::Config::SQL_PARAMS{profile_table}; 
	my $st = $DADA::Config::SQL_PARAMS{subscriber_table};
	
	my $query = qq{SELECT $st.email, $pt.password 
	FROM $st 
	LEFT JOIN $pt 
	ON $st.email = $pt.email 
	WHERE  $st.list_type = 'list'  AND $st.list = ? AND $st.list_status = 1};
	
	my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statment! $DBI::errstr\n";

	 while ( my ( $email, $password ) = $sth->fetchrow_array ) {
		
		if(defined($password)){ 
			print $htpasswd $email . ':' . $password . "\n";
		}
		else { 
			print $htpasswd $email . ':' . $entry->{default_password} . "\n";
		}
	}

	close $htpasswd; 
	
	$sth->finish;
    
	return 1; 
};

1;