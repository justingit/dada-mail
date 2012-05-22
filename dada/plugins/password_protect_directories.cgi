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
use DADA::Profile::Htpasswd;

# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);
my $verbose = $q->param('verbose') || 0; 

my $Plugin_Config                = {}; 
   $Plugin_Config->{Plugin_Name} = 'Password Protect Directories'; 
   $Plugin_Config->{Plugin_URL}  = $q->url; 
   $Plugin_Config->{Allow_Manual_Run} = 1; 
   $Plugin_Config->{Manual_Run_Passcode} = undef; 
   $Plugin_Config->{Base_Absolute_Path}  = $ENV{DOCUMENT_ROOT} . '/';
   $Plugin_Config->{Base_URL} = 'http://' . $ENV{HTTP_HOST} . '/'; 

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
	
		refresh_directories( { -verbose => $verbose } );
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
		my $htp     = DADA::Profile::Htpasswd->new({-list => $list});
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

		<script type="text/javascript">
		//<![CDATA[

		function show_change_default_password_form(){ 
			Effect.BlindUp('change_default_password_button');
			Effect.BlindDown('change_default_password_form');	
		}

	//]]>
	</script>		
		
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
		<li>
		<!-- tmpl_if expr="(error eq 'error_missing_name')" -->
			<strong>Name</strong> is missing.
		<!-- /tmpl_if --> 
		<!-- tmpl_if expr="(error eq 'error_missing_url')" -->
			<strong>URL</strong> is missing.
		<!-- /tmpl_if --> 
		<!-- tmpl_if expr="(error eq 'error_url_no_exists')" -->
			<strong>URL</strong> does not look like a valid URL.
		<!-- /tmpl_if --> 
		<!-- tmpl_if expr="(error eq 'error_missing_path')" -->
			<strong>Path</strong> is missing.
		<!-- /tmpl_if --> 
		<!-- tmpl_if expr="(error eq 'error_path_no_exists')" -->
			<strong>Path</strong> does not look like a valid Server Path.
		<!-- /tmpl_if --> 
		<!-- tmpl_if expr="(error eq 'error_use_custom_error_page_set_funny')" -->
			"Use a Custom Error Page" Isn't a 1 or a 0
		<!-- /tmpl_if --> 
		</li>
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
				 	<tr class="alt"> 
					<td width="200px">
					<strong>Protected URL</strong></td><td><a href="<!-- tmpl_var url -->" target="_blank"><!-- tmpl_var url --></a></td>
					</tr>
				
				 	<tr> 
					<td width="200px">
					<strong>Corresponding Server Path</strong></td><td><!-- tmpl_var path --></td>
					</tr>
				 	
					<tr class="alt"> 
					<td><strong>Using a Custom Error Page?</strong></td><td><!-- tmpl_if use_custom_error_page -->Yes.<!-- tmpl_else -->No.<!-- /tmpl_if --></td>
					</tr>
				 
					<tr>
					<td width="200px">
					<strong>Custom Error Page (Path)</strong></td><td><!-- tmpl_var custom_error_page --></td>
					</tr>
					
					<tr class="alt"> 
					<td width="200px">
					<strong>Default Password</strong></td><td><!-- tmpl_if default_password --><em>********</em><!-- tmpl_else --><em>(None Set)</em><!-- /tmpl_if --></td>
				</tr>
			</table> 
			<div class="buttonfloat">
		
				<form action="<!-- tmpl_var Plugin_URL -->" method="post" accept-charset="<!-- tmpl_var HTML_CHARSET -->" style="display: inline; margin: 0;"> 
					<input type="hidden" name="f" value="edit_dir" /> 
					<input type="hidden" name="id" value="<!-- tmpl_var id -->" /> 
					<input type="submit" class="processing" value="Edit " />
				</form>
			
			
			<form action="<!-- tmpl_var Plugin_URL -->" method="post" accept-charset="<!-- tmpl_var HTML_CHARSET -->" style="display: inline; margin: 0;"> 
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
<tr class="alt">
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
	  Protected URL
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="url" value="<!-- tmpl_var Base_URL -->" class="full" />
	</td>
</tr>

<tr class="alt">
<td width="200px">
	 <label>
	  Corresponding Server Path
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="path" value="<!-- tmpl_var Base_Absolute_Path -->" class="full" />
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

<tr class="alt">
<td width="200px">
	 <label>
Custom Error Page (Path):
	 </label>
	</td>
	<td align="left">
	 <input type="text" name="custom_error_page" value="" class="full" />
	</td>
</tr>

<!-- tmpl_if edit --> 

<tr>
<td width="200px">
	 <label>
	  Default Password (if any):
	 </label>
	</td>
	<td align="left">
			<div id="change_default_password_button">
				<input type="button" value="Click to Change Default Password..." class="cautionary" onclick="show_change_default_password_form();" />
			</div> 
			<div id="change_default_password_form" style="display:none">
						<input type="password" name="default_password" value="" />
			</div>
	</td>
</tr>


<!-- tmpl_else --> 

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

<!-- /tmpl_if --> 


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

<!-- tmpl_unless edit --> 

	<!-- tmpl_if root_login --> 

		<fieldset> 
		 <legend>Manually Run <!-- tmpl_var Plugin_Name --></legend>

		<p>
		 <label for="cronjob_url">Manual Run URL:</label><br /> 
		<input type="text" class="full" id="cronjob_url" value="<!-- tmpl_var Plugin_URL -->?run=1&verbose=1&passcode=<!-- tmpl_var Manual_Run_Passcode -->" />
		</p>
		<!-- tmpl_unless Allow_Manual_Run --> 
		    <span class="error">(Currently disabled)</a>
		<!-- /tmpl_unless -->


		<p> <label for="cronjob_command">curl command example (for a cronjob):</label><br /> 
		<input type="text" class="full" id="cronjob_command" value="<!-- tmpl_var name="curl_location" default="/cannot/find/curl" -->  -s --get --data run=1\;passcode=<!-- tmpl_var Manual_Run_Passcode -->\;verbose=0  --url <!-- tmpl_var Plugin_URL -->" />
		<!-- tmpl_unless curl_location --> 
			<span class="error">Can't find the location to curl!</span><br />
		<!-- /tmpl_unless --> 

		<!-- tmpl_unless Allow_Manual_Run --> 
		    <span class="error">(Currently disabled)</a>
		<!-- /tmpl_unless --> 

		</p>
		</li>
		</ul> 
		</fieldset>

	<!-- /tmpl_if --> 
<!-- /tmpl_unless --> 



};

	return $tmpl;

}




sub default {
	
	my $htp     = DADA::Profile::Htpasswd->new({-list => $list});
	my $entries = $htp->get_all_entries; 
	
	my $problems = $q->param('problems') || 0; 
	my $edit     = 0; 
	my $f        = $q->param('f'); 
	my $id       = undef; 
	if($f eq 'edit_dir'){ 
		$id = $q->param('id') || undef; 
		my $htp = DADA::Profile::Htpasswd->new({-list => $list});
		my $entry = $htp->get({-id => $id });
		$edit = 1; 
		$q->param('name', $entry->{name});
		$q->param('url', $entry->{url});
		$q->param('path', $entry->{path});
		
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
	
	my $curl_location = `which curl`;
       $curl_location = strip( make_safer($curl_location) );

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
			-expr => 1, 
            -vars => {
                done                             => $q->param('done') || 0,
				Plugin_URL                       => $Plugin_Config->{Plugin_URL}, 
				entries                          => $entries, 
				problems                         => $problems, 
				errors                           => $errors, 
				edit                             => $edit, 
				id                               => $id, 
				curl_location                    => $curl_location, 
				root_login                       => $root_login, 
				
				Allow_Manual_Run => $Plugin_Config->{Allow_Manual_Run},
			   Manual_Run_Passcode => $Plugin_Config->{Manual_Run_Passcode},
			   Base_Absolute_Path => $Plugin_Config->{Base_Absolute_Path},
			   Base_URL  => $Plugin_Config->{Base_URL},
			
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
    my $name = xss_filter( $q->param('name') ) || undef;
    my $url  = xss_filter( $q->param('url') )  || undef;
    my $path = xss_filter( $q->param('path') ) || undef;
    my $use_custom_error_page = xss_filter( $q->param('use_custom_error_page') ) || 0;
    my $custom_error_page = xss_filter( $q->param('custom_error_page') )|| undef;
    my $default_password = xss_filter( $q->param('default_password') ) || undef;
	
	
	my $htp = DADA::Profile::Htpasswd->new({-list => $list});
	
	my ($status, $errors) = $htp->validate_protected_dir(
		{ 
			-fields => { 
		        -name                  => $name,
				-url                   => $url,
		        -path                  => $path ,
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
				-url                   => $url,
		        -path                  => $path ,
				-use_custom_error_page => $use_custom_error_page,
				-custom_error_page     => $custom_error_page,
				-default_password      => $default_password,
			}
		);
		for my $id2(@{$htp->get_all_ids}) {  
			$htp->setup_directory({-id => $id2});
		}			
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
	
	my $name = xss_filter( $q->param('name') ) || undef;
    my $url  = xss_filter( $q->param('url') )  || undef;
    my $path = xss_filter( $q->param('path') ) || undef;
    my $use_custom_error_page = xss_filter( $q->param('use_custom_error_page') ) || 0;
    my $custom_error_page = xss_filter( $q->param('custom_error_page') )|| undef;
    my $default_password = xss_filter( $q->param('default_password') ) || undef;
	my $id               = xss_filter( $q->param('id') ) || undef;
	
	my $htp = DADA::Profile::Htpasswd->new({-list => $list});
	
	my ($status, $errors) = $htp->validate_protected_dir(
		{ 
			-fields => { 
		        -name                  => $name,
				-url                   => $url,
		        -path                  => $path ,
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
					-url                   => $url,
			        -path                  => $path ,
					-use_custom_error_page => $use_custom_error_page,
					-custom_error_page     => $custom_error_page,
					-default_password      => $default_password,
				}
			);
			my $htp     = DADA::Profile::Htpasswd->new({-list => $list});
			   $htp->setup_directory({-id => $id});
			
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
	my $htp     = DADA::Profile::Htpasswd->new({-list => $list});
	   $htp->remove_directory_files({-id => $id}); 
	   $htp->remove({-id => $id});
	print $q->redirect(-uri => $Plugin_Config->{Plugin_URL} . '?done=1'); 
	
}