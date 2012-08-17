package DadaMailInstaller; 

use lib qw(
  ../../
  ../../DADA/perllib
);
# Gimme some errors in my browser for debugging
use Carp qw(croak carp);
use CGI::Carp qw(fatalsToBrowser);


$|++;
use strict;
use 5.008_001;
use Encode qw(encode decode);
# A weird fix.
BEGIN {
    if ( $] > 5.008 ) {
        require Errno;
        require Config;
    }
}


# Init my CGI obj. 
use CGI;
CGI->nph(1)
  if $DADA::Config::NPH == 1;
my $q;
$q = CGI->new;
$q = decode_cgi_obj($q);


# These are script-wide variables
#
# $Self_URL may need not be set manually - but I'm hoping not. 
# If the script doesn't post properly, go ahead and configure it manually
#
my $Self_URL            = $q->url;

# You'll normally not want to change this, but I leave it to you to decide
#
my $Dada_Files_Dir_Name = '.dada_files';

# It irritates me to use a weird, relative path - I may want to try to make this 
# an abs. path via File::Spec (or, whatever) 
#
my $Config_LOC          = '../DADA/Config.pm';

my $Support_Files_Dir_Name  = 'dada_mail_support_files'; 

my $File_Upload_Dir         = 'file_uploads';

# Save the errors this creates in a variable
#
my $Big_Pile_Of_Errors  = undef; 

# Show these errors in the web browser? 
#
my $Trace               = 0; 

# These are strings we look for in the example_dada_config.tmpl file which 
# we need to remove. 
my $sql_begin_cut = quotemeta(
    q{# start cut for SQL Backend
=cut}
);
my $sql_end_cut = quotemeta(
    q{=cut
# end cut for SQL Backend
}
);
my $plugins_config_begin_cut = quotemeta(
q{# start cut for plugin configs
=cut}
); 
	my $plugins_config_end_cut = quotemeta(
q{=cut
# end cut for plugin configs}
); 

my $admin_menu_begin_cut = quotemeta(
q{# start cut for list control panel menu
=cut}); 
my $admin_menu_end_cut = quotemeta(
q{=cut
# end cut for list control panel menu}	
); 

my $list_settings_defaults_begin_cut = quotemeta(
q{# start cut for list settings defaults
=cut}
);
my $list_settings_defaults_end_cut = quotemeta(
q{=cut
# end cut for list settings defaults}
); 

my $plugins_extensions = { 
	change_root_password          => {installed => 0, loc => '../plugins/change_root_password.cgi'}, 
	screen_cache                  => {installed => 0, loc => '../plugins/screen_cache.cgi'}, 
	log_viewer                    => {installed => 0, loc => '../plugins/log_viewer.cgi'}, 
	tracker                       => {installed => 0, loc => '../plugins/tracker.cgi'}, 
	dada_bridge                   => {installed => 0, loc => '../plugins/dada_bridge.pl'}, 
	dada_bounce_handler           => {installed => 0, loc => '../plugins/dada_bounce_handler.pl'}, 
	scheduled_mailings            => {installed => 0, loc => '../plugins/scheduled_mailings.pl'}, 
	multiple_subscribe            => {installed => 0, loc => '../extensions/multiple_subscribe.cgi'}, 
	ajax_include_subscribe        => {installed => 0, loc => '../extensions/ajax_include_subscribe.cgi'}, 	
	blog_index                    => {installed => 0, loc => '../extensions/blog_index.cgi'}, 
	mailing_monitor               => {installed => 0, loc => '../plugins/mailing_monitor.cgi'}, 
	default_mass_mailing_messages => {installed => 0, loc => '../plugins/default_mass_mailing_messages.cgi'}, 
	password_protect_directories  => {installed => 0, loc => '../plugins/password_protect_directories.cgi'}, 
	change_list_shortname         => {installed => 0, loc => '../plugins/change_list_shortname.cgi'},  
};
$plugins_extensions->{change_root_password}->{code} = 
q{#					{
#					-Title      => 'Change the Program Root Password',
#					-Title_URL  => $PLUGIN_URL."/change_root_password.cgi",
#					-Function   => 'change_root_password',
#					-Activated  => 0,
#					},};

$plugins_extensions->{screen_cache}->{code} = 
q{#					{
#					-Title      => 'Screen Cache',
#					-Title_URL  => $PLUGIN_URL."/screen_cache.cgi",
#					-Function   => 'screen_cache',
#					-Activated  => 0,
#					},};

$plugins_extensions->{log_viewer}->{code} = 
q{#					{
#					-Title      => 'View Logs',
#					-Title_URL  => $PLUGIN_URL."/log_viewer.cgi",
#					-Function   => 'log_viewer',
#					-Activated  => 1,
#					},};

$plugins_extensions->{tracker}->{code} = 
q{#					{
#					-Title      => 'Tracker',
#					-Title_URL  => $PLUGIN_URL."/tracker.cgi",
#					-Function   => 'tracker',
#					-Activated  => 1,
#					},};

$plugins_extensions->{dada_bridge}->{code} = 
q{#					{
#					-Title      => 'Discussion Lists',
#					-Title_URL  => $PLUGIN_URL."/dada_bridge.pl",
#					-Function   => 'dada_bridge',
#					-Activated  => 1,
#					},};

$plugins_extensions->{dada_bounce_handler}->{code} = 
q{#					{
#					-Title      => 'Bounce Handler',
#					-Title_URL  => $PLUGIN_URL."/dada_bounce_handler.pl",
#					-Function   => 'dada_bounce_handler',
#					-Activated  => 1,
#					},};

$plugins_extensions->{scheduled_mailings}->{code} = 
q{#					{-Title      => 'Scheduled Mailings',
#					 -Title_URL  => $PLUGIN_URL."/scheduled_mailings.pl",
#					 -Function   => 'scheduled_mailings',
#					 -Activated  => 1,
#					},};

$plugins_extensions->{multiple_subscribe}->{code} = 
q{#					{
#					-Title      => 'Multiple Subscribe',
#					-Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
#					-Function   => 'multiple_subscribe',
#					-Activated  => 1,
#					},};

$plugins_extensions->{ajax_include_subscribe}->{code} = 
q{#					{
#					-Title      => 'Ajax\'d Subscription Form',
#					-Title_URL  => $EXT_URL."/ajax_include_subscribe.cgi?mode=html",
#					-Function   => 'ajax_include_subscribe',
#					-Activated  => 1,
#					},};

$plugins_extensions->{blog_index}->{code} = 
q{#					{
#					-Title      => 'Archive Blog Index',
#					-Title_URL  => $EXT_URL."/blog_index.cgi?mode=html&list=<!-- tmpl_var list_settings.list -->",
#					-Function   => 'blog_index',
#					-Activated  => 1,
#					},};

$plugins_extensions->{mailing_monitor}->{code} = 
q{#					{
#					-Title      => 'Mailing Monitor',
#					-Title_URL  => $PLUGIN_URL."/mailing_monitor.cgi",
#					-Function   => 'mailing_monitor',
#					-Activated  => 0,
#					},};

$plugins_extensions->{password_protect_directories}->{code} =
q{#					{
#					-Title      => 'Password Protect Directories',
#					-Title_URL  => $PLUGIN_URL."/password_protect_directories.cgi",
#					-Function   => 'password_protect_directories',
#					-Activated  => 1,
#					},};

$plugins_extensions->{default_mass_mailing_messages}->{code} =
q{#					{
#					-Title      => 'Default Mass Mailing Messages',
#					-Title_URL  => $PLUGIN_URL."/default_mass_mailing_messages.cgi",
#					-Function   => 'default_mass_mailing_messages',
#					-Activated  => 1,
#					},};

$plugins_extensions->{change_list_shortname}->{code} =
q{#					{
#					-Title      => 'Change Your List Short Name',
#					-Title_URL  => $PLUGIN_URL."/change_list_shortname.cgi",
#					-Function   => 'change_list_shortname',
#					-Activated  => 0,
#					},};


# An unconfigured Dada Mail won't have these exactly handy to use. 
$DADA::Config::PROGRAM_URL   = program_url_guess();
$DADA::Config::S_PROGRAM_URL = program_url_guess();

use DADA::Config 5.0.0;
    $DADA::Config::USER_TEMPLATE = '';
use DADA::App::Guts;
use DADA::Template::Widgets;
use DADA::Template::HTML;

# So we may test the sub. in unit tests, etc. 
__PACKAGE__->run()
  unless caller();

sub run {
    if ( !$ENV{GATEWAY_INTERFACE} ) {
        &cl_run();
    }
    else {

        # Old-school switcheroo
        my %Mode = (

			install_or_upgrade       => \&install_or_upgrade, 
            check_install_or_upgrade => \&check_install_or_upgrade, 
			install_dada             => \&install_dada,
            scrn_configure_dada_mail => \&scrn_configure_dada_mail,
            check                    => \&check,
            move_installer_dir_ajax  => \&move_installer_dir_ajax,
			show_current_dada_config => \&show_current_dada_config, 

        );
        my $flavor = $q->param('f');
        if ($flavor) {
            if ( exists( $Mode{$flavor} ) ) {
                $Mode{$flavor}->();    #call the correct subroutine
            }
            else {
                &install_or_upgrade;
            }
        }
        else {
            &install_or_upgrade;
        }

    }
}
sub cl_run { 

	require Getopt::Long;
    my %h = ();
    Getopt::Long::GetOptions(
        \%h,
        'if_dada_files_already_exists=s',
        'program_url=s',
        'dada_root_pass=s',
        'dada_files_loc=s', 
		'dada_files_dir_setup=s',
        'backend=s',
        'skip_configure_SQL=s',
        'sql_server=s',
        'sql_port=s',
        'sql_database=s',
        'sql_username=s',
        'sql_password=s',
		'help',
    );

 
	for(keys %h){ 
		$q->param($_, $h{$_});
	}
	if(scalar(keys %h) == 0){ 
		cl_quickhelp(); 
		exit;
	}
	elsif($h{help} == 1){ 
		cl_help(); 
		exit;
	}
		

	# Uh, so we don't have to re-type this on the cl: 
	if(exists($h{'dada_root_pass'})){ 
		$q->param('dada_root_pass_again',$h{dada_root_pass}); 
	}
	my ( $check_status, $check_errors ) = check_setup();
    print "Checking Setup...\n"; 
	if($check_status == 0){ 		
		print "Problems were found:\n\n";
		print "Uh, TODO - make these a little more intelligent:\n"; 
		
	    for(keys %$check_errors){ 
			if($check_errors->{$_} == 1){ 
				print "Error: $_\n"; 
			}
		}
		print "\n" . $Big_Pile_Of_Errors . "\n";
		exit;
			
	}
	else { 
		print "Paramaters passed look great! Configuring...\n"; 
	   my $install_dada_files_loc = install_dada_files_dir_at_from_params(); 
	   my ( $install_log, $install_status, $install_errors ) = install_dada_mail(
	        {
	            -program_url                   => $q->param('program_url') || '',
	            -dada_root_pass                => $q->param('dada_root_pass') || '',
				-dada_files_dir_setup          => $q->param('dada_files_dir_setup') || 'manual', 
	            -backend                       => $q->param('backend') || 'default',
	            -sql_server                    => $q->param('sql_server') || '',
	            -sql_database                  => $q->param('sql_database') || '',
	            -sql_username                  => $q->param('sql_username') || '',
	            -sql_password                  => $q->param('sql_password') || '',
		        -sql_port                      => sql_port_from_params(),
				-install_dada_files_loc        => $install_dada_files_loc, 			
				-skip_configure_SQL            => $q->param('skip_configure_SQL') || 0, 
				-if_dada_files_already_exists  => $q->param('if_dada_files_already_exists') || undef,
	        }
	    );

		print $install_log . "\n"; 
		if($install_status == 0){ 
			print "Problems with configuration:\n\n"; 
			
			for(keys %$install_errors){ 
				print $_ . " => " . $install_errors->{$_} . "\n"; 
			}
		}
		else { 
			print "Moving and Disabling, \"installer\" directory\n"; 
			my ($new_dir, $eval_errors) = move_installer_dir(); 
			if($eval_errors){ 
				print "Problems with moving installer directory: \n $eval_errors\n\n"; 
			}
			else{ 
				print "Installer directory moved to, \"$new_dir\"\n";
				print "Installation and Configuration Complete.\n\n\n";
			}
		}
	
	}
}

sub cl_quickhelp { 	
	print DADA::Template::Widgets::screen(
        {
            -screen => 'cl_quickhelp_scrn.tmpl',
            -vars => {

            },
        }
    );	
}

sub cl_help { 
	
	print DADA::Template::Widgets::screen(
        {
            -screen => 'cl_help_scrn.tmpl',
            -vars => {

            },
        }
    );	
}




sub install_or_upgrade { 
	
	my $dada_files_parent_dir = $DADA::Config::CONFIG_FILE;
	   $dada_files_parent_dir =~ s/\/$Dada_Files_Dir_Name\/\.configs\/\.dada_config//;
	my $found_existing_dada_files_dir = test_complete_dada_files_dir_structure_exists($dada_files_parent_dir);
	
   my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'install_or_upgrade.tmpl',
			-with   => 'list', 
            -vars => {
				dada_files_parent_dir               => $dada_files_parent_dir, 
				Dada_Files_Dir_Name                 => $Dada_Files_Dir_Name, 
				found_existing_dada_files_dir       => $found_existing_dada_files_dir ,
				current_dada_files_parent_location  => $q->param('current_dada_files_parent_location'), 
				error_cant_find_dada_files_location => $q->param('error_cant_find_dada_files_location'), 
			},
		}
	); 
	
	# Let's get some fancy js stuff!
    $scrn = hack_in_scriptalicious($scrn);
	# Uh, do are darnest to get the $PROGRAM_URL stuff working correctly, 
	$scrn = hack_program_url($scrn); 
    
	if($q->param('error_cant_find_dada_files_location') == 1){ 
	    require HTML::FillInForm::Lite;
	    my $h = HTML::FillInForm::Lite->new();
	    $scrn = $h->fill( \$scrn, $q );
	}

	print $scrn; 
}



sub check_install_or_upgrade { 
	if($q->param('install_type') eq 'install'){ 
		&scrn_configure_dada_mail; 
		return;
	}
	else { 
		my $current_dada_files_parent_location = $q->param('current_dada_files_parent_location'); 	
		if(test_complete_dada_files_dir_structure_exists($current_dada_files_parent_location) == 1){ 
			&scrn_configure_dada_mail; 
			return;			
		}
		else { 
			$q->param('error_cant_find_dada_files_location', 1); 
			&install_or_upgrade; 
			return; 
		}
	}
}		



sub scrn_configure_dada_mail {
	
	my $current_dada_files_parent_location = $q->param('current_dada_files_parent_location'); 	
	my $install_type                      = $q->param('install_type'); 
	$q->delete('current_dada_files_parent_location', 'install_type', 'f', 'submitbutton');

	
	# Have we've been here, before? 
	my %params = $q->Vars;
	if(! keys %params){ 
		# well, then place some defaults: 
		$q->param('install_mailing_monitor', 1); 
		$q->param('install_change_root_password', 1); 
		$q->param('install_screen_cache', 1); 
		$q->param('install_log_viewer', 1); 
		$q->param('install_tracker', 1); 
		$q->param('install_multiple_subscribe', 1); 
		$q->param('install_ajax_include_subscribe', 1); 
		$q->param('install_blog_index', 1); 
		$q->param('install_default_mass_mailing_messages', 1); 
		# $q->param('install_password_protect_directories', 1); 
		$q->param('install_change_list_shortname', 1); 
		
	}

=cut	
	# Is there some stuff happenin already? 
	my @lists = DADA::App::Guts::available_lists(-Dont_Die => 1); 
	my $lists_available = 0; 
	if(exists($lists[0])){
		$lists_available = 1; 
	}
=cut

	# This is a test to see if the, "auto" placement will work for us - or 
	# for example, there's something in the way. 
	# First, let's see if there's any errors: 
	if ( defined( $q->param('errors') )) {
    	# No? Good - 
	}
	else { 
		if(test_can_create_dada_files_dir(auto_dada_files_dir()) == 1 ){ 
			# HTML::FillInForm::Lite will pick up on this 
			$q->param('dada_files_loc', auto_dada_files_dir()); 
			$q->param('dada_files_dir_setup', 'manual');  
		}	
	}
	
	my $configured_dada_config_file; 
	my $configured_dada_files_loc; 
	
	if($install_type eq 'upgrade'){ 
		$configured_dada_config_file = $current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name .'/.configs/.dada_config'; 
		$configured_dada_files_loc = $current_dada_files_parent_location; 
		
	}
	else { 
	   $configured_dada_config_file = $DADA::Config::CONFIG_FILE;
	   $configured_dada_files_loc = $configured_dada_config_file;
		$configured_dada_files_loc =~ s/\/$Dada_Files_Dir_Name\/\.configs\/\.dada_config//;
	}
	
	my $DOC_VER = $DADA::Config::VER; 
	   $DOC_VER =~ s/\s(.*?)$//;
	   $DOC_VER =~ s/\./\_/g;

	# I'm going to fill this back in: 
	$q->param('install_type', $install_type); 
	$q->param('current_dada_files_parent_location', $current_dada_files_parent_location); 
	
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'installer_configure_dada_mail_scrn.tmpl',
			-with   => 'list', 
			-expr   => 1, 
            -vars => {
				
				install_type                => $install_type, 
				current_dada_files_parent_location => $current_dada_files_parent_location, 
				
                program_url_guess              => program_url_guess(),
                can_use_DBI                    => test_can_use_DBI(),
				can_use_MySQL                  => test_can_use_MySQL(), 
				can_use_Pg                     => test_can_use_Pg(), 
				can_use_SQLite                 => test_can_use_SQLite(), 								
                error_cant_read_config_dot_pm  => test_can_read_config_dot_pm(),
                error_cant_write_config_dot_pm => test_can_write_config_dot_pm(),
				home_dir_guess                 => guess_home_dir(),
				install_dada_files_dir_at      => install_dada_files_dir_at_from_params(),
			    test_complete_dada_files_dir_structure_exists 
											   => test_complete_dada_files_dir_structure_exists(install_dada_files_dir_at_from_params()), 
				dada_files_dir_setup           => $q->param('dada_files_dir_setup') || '', 
                dada_files_loc                 => $q->param('dada_files_loc') || '',
                error_root_pass_is_blank       => $q->param('error_root_pass_is_blank')|| 0,
                error_pass_no_match            => $q->param('error_pass_no_match') || 0,
                error_program_url_is_blank     => $q->param('error_program_url_is_blank') || 0,
                error_create_dada_files_dir    => $q->param('error_create_dada_files_dir')  || 0,
                error_dada_files_dir_exists    => $q->param('error_dada_files_dir_exists') || 0,
                error_sql_connection           => $q->param('error_sql_connection') || 0,
                error_sql_table_populated      => $q->param('error_sql_table_populated') || 0,
                skip_configure_SQL             => $q->param('skip_configure_SQL') || 0, 
                errors                         => $q->param('errors') || [],
                PROGRAM_URL                    => program_url_guess(),
                S_PROGRAM_URL                  => program_url_guess(),
                Dada_Files_Dir_Name            => $Dada_Files_Dir_Name,
				Big_Pile_Of_Errors             => $Big_Pile_Of_Errors,
				Trace                          => $Trace, 
				#lists_available                => $lists_available, 
				configured_dada_config_file    => $configured_dada_config_file,
				configured_dada_files_loc      => $configured_dada_files_loc, 
				DOC_VER                        => $DOC_VER, 
				DOC_URL                        => 'http://dadamailproject.com/support/documentation-' . $DOC_VER, 
				
				support_files_dir_path         => support_files_dir_path_guess(),
				support_files_dir_url         => support_files_dir_url_guess(),
				Support_Files_Dir_Name        => $Support_Files_Dir_Name
				

            },
        }
    );

    # Let's get some fancy js stuff!
    $scrn = hack_in_scriptalicious($scrn);
	# Uh, do are darnest to get the $PROGRAM_URL stuff working correctly, 
	$scrn = hack_program_url($scrn); 

#    # Refill in all the stuff we just had;
#    if ( defined($q->param('errors')) ) {
        require HTML::FillInForm::Lite;
        my $h = HTML::FillInForm::Lite->new();
        $scrn = $h->fill( \$scrn, $q );
#   }
    e_print($scrn);

}



sub connectdb {
    my $dbtype      = shift;
    my $dbserver    = shift;
    my $port        = shift;
    my $database    = shift;
    my $user        = shift;
    my $pass        = shift;
    my $data_source;

	if($dbtype eq 'SQLite'){ 
		
		require DADA::Security::Password; 
		# I doubt that's going to work for everything... 
		 $data_source = 'dbi:' . $dbtype . ':' . '/tmp' . '/' . 'dadamail' . DADA::Security::Password::generate_rand_string();
	} else {
		$data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";
	}
	
    require DBI;
    my $dbh;
    my $that_didnt_work = 1;
    $dbh = DBI->connect( "$data_source", $user, $pass )
      || croak "can't connect to db: '$data_source' '$DBI::errstr'";
    return $dbh;
}

sub check {
    my ( $status, $errors ) = check_setup();

    if ( $status == 0 ) {
        my $ht_errors = [];

        for ( keys %$errors ) {
            if ( $errors->{$_} == 1 ) {
                push( @$ht_errors, { error => $_ } );
                $q->param( 'error_' . $_, 1 );
            }
        }
        $q->param( 'errors', $ht_errors );
		scrn_configure_dada_mail();
    }
    else {
        scrn_install_dada_mail();
    }

}

sub scrn_install_dada_mail {
	my $install_dada_files_loc = install_dada_files_dir_at_from_params(); 
    my ( $log, $status, $errors ) = install_dada_mail(
        {
			-if_dada_files_already_exists  => $q->param('if_dada_files_already_exists') || undef,
            -program_url                   => $q->param('program_url'),
            -dada_root_pass                => $q->param('dada_root_pass'),
			-dada_files_dir_setup          => $q->param('dada_files_dir_setup'), 
			-install_dada_files_loc        => $install_dada_files_loc, 
            -backend                       => $q->param('backend'),
			-skip_configure_SQL            => $q->param('skip_configure_SQL') || 0, 
            -sql_server                    => $q->param('sql_server'),
            -sql_port                      => sql_port_from_params(),
            -sql_database                  => $q->param('sql_database'),
            -sql_username                  => $q->param('sql_username'),
            -sql_password                  => $q->param('sql_password'),
        }
    );

  my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'installer_install_dada_mail_scrn.tmpl',
			-with   => 'list', 
            -vars => { 
			 install_log                  => webify_plain_text({-str =>$log}), 
			 status                       => $status, 
			install_dada_files_loc        => $install_dada_files_loc,
			Dada_Files_Dir_Name           => $Dada_Files_Dir_Name, 
			error_cant_edit_config_dot_pm => $errors->{cant_edit_config_dot_pm} || 0, 
			Big_Pile_Of_Errors            => $Big_Pile_Of_Errors,
			Trace                         => $Trace, 
			PROGRAM_URL                   => program_url_guess(),
            S_PROGRAM_URL                 => program_url_guess(),
			submitted_PROGRAM_URL         => $q->param('program_url'),

			
	 		}
        }
    );
    $scrn = hack_in_scriptalicious($scrn);

	# Uh, do are darnest to get the $PROGRAM_URL stuff working correctly, 
	$scrn = hack_program_url($scrn); 

    e_print($scrn);

}

sub install_dada_mail {
    my ($args) = @_;
    my $log    = undef;
    my $errors = {};
    my $status = 1;


	if($args->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config'){ 
		$log .= "* Backing up current configuration file\n";
		eval { 
			backup_current_config_file($args); 
		}; 
		if($@){ 
			$log .= "* Problems backing up config file: $@\n"; 
			$errors->{cant_backup_orig_config_file} = 1;
		}
		else { 
			$log .= "* Success!\n"; 
		}	
	}

	
	if(	$args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' || $args->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config'){ 
	
		$log .= "* Removing old screen cache files...\n"; 
		eval { 
			require DADA::App::ScreenCache; 
			my $c = DADA::App::ScreenCache->new; 
			   $c->flush;
		};
		if($@){ 
			$log .="* Problems with removing old screen cache files: $@\n"; 
		}
		else { 
			$log .="* Success!\n"; 
		}
	}

	
	if($args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files'){ 
		$log .= "* Skipping configuration of directory creation, config file and backend options\n"; 
	}
	else { 
    	$log .=
	        "* Attempting to make $DADA::Config::PROGRAM_NAME Files at, "
	      . $args->{-install_dada_files_loc} . '/'
	      . $Dada_Files_Dir_Name . "\n";

		if($args->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config'){ 
			$log .= "* Skipping directory creation\n"; 
		}
		else { 			
		    # Making the .dada_files structure
		    if ( create_dada_files_dir_structure( $args->{-install_dada_files_loc} ) == 1 ) {
		        $log .= "* Success!\n";
		    }
		    else {
		        $log .= "* Problems Creating Directory Structure! STOPPING!\n";
		        $errors->{cant_create_dada_files} = 1;
		        $status = 0;
		        return ( $log, $status, $errors );
		    }
		}

	    # Making the .dada_config file
	    $log .= "* Attempting to create .dada_config file...\n";
	    if ( create_dada_config_file($args) == 1 ) {
	        $log .= "* Success!\n";
	    }
	    else {
	        $log .= "* Problems Creating .dada_config file! STOPPING!\n";
	        $errors->{cant_create_dada_config} = 1;
	        $status = 0;
	        return ( $log, $status, $errors );
	    }

	    # Creating the needed SQL tables
	    if ( $args->{-backend} eq 'default' || $args->{-backend} eq '' ) {
	        # ...
	    }
	    else {
	        if($args->{-skip_configure_SQL} == 1){ 
				$log .= "* Skipping the creation of the SQL Tables...\n";
			}
			else { 
			
				$log .= "* Attempting to create SQL Tables...\n";
		        my $sql_ok = create_sql_tables($args);
		        if ( $sql_ok == 1 ) {
		            $log .= "* Success!\n";
		        }
		        else {
		            $log .= "* Problems Creating SQL Tables! STOPPING!\n";
		            $errors->{cant_create_sql_tables} = 1;
		            $status = 0;
		            return ( $log, $status, $errors );
		        }
			}
	    }
	}
	
    # Editing the Config.pm file

    if ( test_can_read_config_dot_pm() == 1 ) {
        $log .= "* WARNING: Cannot read, $Config_LOC!\n";
        $errors->{cant_read_config_dot_pm} = 1;
		# $status = 0; ?
    }

    $log .= "* Attempting to backup original $Config_LOC file...\n";
    eval { backup_config_dot_pm(); };
    if ($@) {
        $Big_Pile_Of_Errors .= $@; 
		$log .= "* WARNING: Could not backup, $Config_LOC! (<code>$@</code>)\n";
        $errors->{cant_backup_dada_dot_config} = 1;
    }
    else {
        $log .= "* Success!\n";
    }

    $log .= "* Attempting to edit $Config_LOC file...\n";
    if ( test_can_write_config_dot_pm() == 1) {
       $log .= "* WARNING: Cannot write to, $Config_LOC!\n";
        $errors->{cant_edit_config_dot_pm} = 1;
	# $status = 0; ?
    }
   else {
		if(
			$args->{-install_dada_files_loc} eq auto_dada_files_dir() && 
			$args->{-dada_files_dir_setup}   eq 'auto'
		){ 
			$log .= "* No need to edit $Config_LOC file - you've set the $Dada_Files_Dir_Name location to, 'auto!'\n";
		}
		else { 	
	        if ( edit_config_dot_pm( $args->{-install_dada_files_loc} ) == 1 ) {
	            $log .= "* Success!\n";
	        }
	        else {
	            $log .= "* WARNING: Cannot edit $Config_LOC!\n";
	            $errors->{cant_edit_dada_dot_config} = 1;
	        }
		}
    }

	$log .= "* Installing plugins/extensions...\n";
	eval {edit_config_file_for_plugins($args);}; 
	if($@){ 
        $log .= "* WARNING: Couldn't complete installing plugins/extensions! $@\n";
        $errors->{cant_install_plugins_extensions} = 1;
	}
	else { 
        $log .= "* Success!\n";		
	} 
	
	if($args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files') { 
		$log .= "* Skipping WYSIWYG setup...\n";	
	}
	else { 
		$log .= "* Installing WYSIWYG Editors...\n";
		eval {install_wysiwyg_editors($args);}; 
		if($@){ 
	        $log .= "* WARNING: Couldn't complete installing WYSIWYG editors! $@\n";
	        $errors->{cant_install_wysiwyg_editors} = 1;
		}
		else { 
	        $log .= "* Success!\n";		
		} 
	}

    # That's it.
    $log .= "* Installation and Configuration Complete!\n";
    return ( $log, $status, $errors );
}


sub edit_config_dot_pm {
    my $loc          = shift;
    my $search       = qr/\$PROGRAM_CONFIG_FILE_DIR \= \'(.*?)\'\;/;
	my $search2      = qr/\$PROGRAM_ERROR_LOG \= (.*?)\;/;
	
	if($loc eq 'auto') { 
		carp "\$loc has been set to, 'auto' - nothing to edit!"; 
		return 1; 
	}
	else { 
		
	    my $replace_with  = q{$PROGRAM_CONFIG_FILE_DIR = '} . $loc . '/' . $Dada_Files_Dir_Name . q{/.configs';};
		my $replace_with2 = q{$PROGRAM_ERROR_LOG = '}       . $loc . '/' . $Dada_Files_Dir_Name . q{/.logs/errors.txt';};
	    #eval {
			$Config_LOC = make_safer($Config_LOC); 
		 
	        my $config = slurp($Config_LOC);
	     
	
		   # I really only have that one thing to edit - 
	       $config =~ s/$search/$replace_with/;
			
			# (what about the error log? ) 
			$config =~ s/$search2/$replace_with2/; 
			
			installer_chmod(0777, make_safer('../DADA'));
			installer_rm($Config_LOC); 
			
	        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $Config_LOC or croak $!;
	        print $config_fh $config or croak $!;
	        close $config_fh or croak $!;
	
			installer_chmod(0755, $Config_LOC);
			installer_chmod(0755, make_safer('../DADA'));
	        return 1;
	}
}

sub backup_config_dot_pm {

    installer_chmod( 0777, '../DADA' );

    my $config     = slurp($Config_LOC);
    my $backup_loc = make_safer( $Config_LOC . '-backup.' . time );
    open my $backup, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      $backup_loc
      or croak $!;
    print $backup $config
      or croak $!;
    close $backup
      or croak $!;

    installer_chmod( 0755, $backup_loc );
    installer_chmod( 0755, '../DADA' );
}




sub backup_current_config_file { 
	my ($args) = @_; 
	
	my $dot_configs_file_loc = make_safer(
		$args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config'
	);
	my $config_file = slurp(
		$dot_configs_file_loc
	);
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

	my $timestamp = sprintf("%4d-%02d-%02d", $year+1900,$mon+1,$mday) . '-' . time;
	
	my $new_loc = make_safer(
		$args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config-backup-' . $timestamp
	); 
	
	open my $config_backup, '>', $new_loc or croak $!; 
	print $config_backup $config_file; 
	close($config_backup) or croak $!; 
	
	unlink($dot_configs_file_loc); 
	
}

sub create_dada_files_dir_structure {
    my $loc = shift;
    $loc = auto_dada_files_dir() if $loc eq 'auto';
    $loc = make_safer( $loc . '/' . $Dada_Files_Dir_Name );

    eval {

        installer_mkdir( $loc, $DADA::Config::DIR_CHMOD );
		create_htaccess_deny_from_all_file($loc); 
        for (
            qw(
            .archives
            .backups
            .configs
            .lists
            .logs
            .templates
            .tmp
            )
          )
        {
            my $sub_dir = make_safer( $loc . '/' . $_ );
            installer_mkdir( $sub_dir, $DADA::Config::DIR_CHMOD );
        }
    };
    if ($@) {
        carp $@;
        $Big_Pile_Of_Errors .= $@; 
		return 0;
    }
    else {
        return 1;
    }
}

sub create_dada_config_file {
    my ($args) = @_;

    my $loc = $args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name;

     eval {
    if ( !-e $loc . '/.configs' ) {
        croak "$loc does not exist! Stopping!";
    }

    require DADA::Security::Password;
    my $pass =
      DADA::Security::Password::encrypt_passwd( $args->{-dada_root_pass} );

	if(!exists($args->{-program_url})){ 
		
	    my $prog_url = $DADA::Config::PROGRAM_URL;
	    $prog_url =~ s{installer\/install\.cgi}{mail\.cgi};
		$args->{-program_url} = $prog_url;
	}

	if($args->{-backend} eq 'SQLite'){ 
		$args->{-sql_server} = ''; 
        $args->{-sql_database} = 'dadamail';  
        $args->{-sql_port} = ''; 
        $args->{-sql_username} = ''; 
        $args->{-sql_password} = ''; 
	}
	
    my $outside_config_file = DADA::Template::Widgets::screen(
        {
            -screen => 'example_dada_config.tmpl',
            -vars   => {

                PROGRAM_URL            => $args->{-program_url},
                ROOT_PASSWORD          => $pass,
                ROOT_PASS_IS_ENCRYPTED => 1,
                dada_files_dir         => $loc,
				Big_Pile_Of_Errors     => $Big_Pile_Of_Errors, 
				Trace                  => $Trace, 
                ( $args->{-backend} ne 'default' || $args->{-backend} eq '' )
                ? (
                    backend      => $args->{-backend},
                    sql_server   => $args->{-sql_server},
                    sql_database => clean_up_var($args->{-sql_database}),
                    sql_port     => clean_up_var($args->{-sql_port}),
                    sql_username => clean_up_var($args->{-sql_username}),
                    sql_password => clean_up_var($args->{-sql_password}),
                  )
                : ()
            }
        }
    );

    # SQL Stuff.
    if ( $args->{-backend} eq 'default' || $args->{-backend} eq '' ) {

        # ...
    }
    else {
        $outside_config_file =~ s/$sql_begin_cut//;
        $outside_config_file =~ s/$sql_end_cut//;
    }

    open my $dada_config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer( $loc . '/.configs/.dada_config' )
      or croak $!;
    print $dada_config_fh $outside_config_file or croak $!;
    close $dada_config_fh or croak $!;

	
     };
     if ($@) {
		carp $@; 
        $Big_Pile_Of_Errors .= $Big_Pile_Of_Errors; 
		return 0;
    }
    else {
        return 1;
    }

}

sub create_sql_tables {
    my ($args) = @_;

    my $sql_file = '';
    if ( $args->{-backend} eq 'mysql' ) {
        $sql_file = 'mysql_schema.sql';
    }
    elsif ( $args->{-backend} eq 'Pg' ) {
	}
	elsif ( $args->{-backend} eq 'SQLite' ) {
        $sql_file = 'sqlite_schema.sql';
    }


    eval {

    require DBI;

    my $dbtype   = $args->{-backend};
    my $dbserver = $args->{-sql_server};
    my $port     = $args->{-sql_port};
    my $database = $args->{-sql_database};
    my $user     = $args->{-sql_username};
    my $pass     = $args->{-sql_password};
	
	my $data_source = ''; 
	my $dbh         = undef; 
	if($dbtype eq 'SQLite'){ 
		$data_source = 'dbi:' . $dbtype . ':' . $args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.lists/' . 'dadamail';
		$dbh = DBI->connect( $data_source, "", "" );
	}
	else { 
		$data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";
		$dbh = DBI->connect( "$data_source", $user, $pass );
	}

    my $schema = slurp( make_safer( '../extras/SQL/' . $sql_file ) );
    my @statements = split( ';', $schema );

    for (@statements) {
        if ( length($_) > 10 ) {

            # print "\nquery:\n" . $_;
            my $sth = $dbh->prepare($_);
            $sth->execute
              or croak "cannot do statement! $DBI::errstr\n";
        }
    }

    	};
    	if($@){
    		carp $!;
    		$Big_Pile_Of_Errors .= $@; 
			return 0;
    	}
    	else {
    return 1;

    	}
}

sub sql_port_from_params {
    my $port = $q->param('sql_port'); 
	if ( $q->param('sql_port') eq 'auto' ) {
        if ( $q->param('backend') =~ /mysql/i ) {
            $port = 3306;
        }
        elsif ( $q->param('backend') =~ /Pg/i ) {
            $port = 5432;
        }
        elsif ( $q->param('backend') =~ /SQLite/i ) {
            $port = '';
        }
		else { 
			# well, we don't change this... 
		}
    }
	return $port; 
}

sub check_setup {
    my $errors = {};
    if (
        $q->param('if_dada_files_already_exists') eq 'skip_configure_dada_files'
        && test_complete_dada_files_dir_structure_exists(
            install_dada_files_dir_at_from_params()
        ) == 1    # This still has to check out,
      )
    {

        # Skip a lot of the tests!
        # croak "Skipping!";
    }
    else {

        if ( test_str_is_blank( $q->param('program_url') ) == 1 ) {
            $errors->{program_url_is_blank} = 1;
        }
        else {
            $errors->{program_url_is_blank} = 0;
        }

        if ( test_str_is_blank( $q->param('dada_root_pass') ) == 1 ) {
            $errors->{root_pass_is_blank} = 1;

        }
        else {
            $errors->{root_pass_is_blank} = 0;
        }
        if (
            test_pass_match(
                $q->param('dada_root_pass'),
                $q->param('dada_root_pass_again')
            ) == 1
          )
        {
            $errors->{pass_no_match} = 1;
        }
        else {
            $errors->{pass_no_match} = 0;
        }

        if ( $q->param('backend') eq 'default' || $q->param('backend') eq '' ) {
            $errors->{sql_connection} = 0;
        }
        else {
            if (
                test_sql_connection(
                    $q->param('backend'),      $q->param('sql_server'),
                    'auto',                    $q->param('sql_database'),
                    $q->param('sql_username'), $q->param('sql_password'),
                ) == 0
              )
            {
                $errors->{sql_connection} = 1;

            }
            else {
                $errors->{sql_connection} = 0;

                if (
                    test_database_has_all_needed_tables(
                        $q->param('backend'),      $q->param('sql_server'),
                        sql_port_from_params(),    $q->param('sql_database'),
                        $q->param('sql_username'), $q->param('sql_password'),
                    ) == 1
                  )
                {
					if($q->param('install_type') eq 'install'){ 
                    	$errors->{sql_table_populated} = 1;
					}
					else { 
						# else, no problemo, right?
						$errors->{sql_table_populated} = 0;
						$q->param('skip_configure_SQL', 1); 
					}
                }
                else {
                    $errors->{sql_table_populated} = 0;
                }

            }
        }
        my $install_dada_files_dir_at = install_dada_files_dir_at_from_params();
        if ( test_dada_files_dir_no_exists($install_dada_files_dir_at) == 1 ) {
            $errors->{dada_files_dir_exists} = 0;
        }
        else {
	
			if (
		        $q->param('if_dada_files_already_exists') eq 'keep_dir_create_new_config'
		        && test_complete_dada_files_dir_structure_exists(
		            install_dada_files_dir_at_from_params()
		        ) == 1    # This still has to check out,
		      ) { 
				# skip this test, basically, 
				$errors->{dada_files_dir_exists} = 0;
			}
			else { 
            	$errors->{dada_files_dir_exists} = 1;
        	}
		}
		
		if (
	        $q->param('if_dada_files_already_exists') eq 'keep_dir_create_new_config'
	        && test_complete_dada_files_dir_structure_exists(
	            install_dada_files_dir_at_from_params()
	        ) == 1    # This still has to check out,
	      ) {
		
			# Skip.
			$errors->{create_dada_files_dir} = 0;
		}
		else { 
			
			if ( test_can_create_dada_files_dir($install_dada_files_dir_at) == 1 ) {
	            $errors->{create_dada_files_dir} = 1;
	        }
	        else {
	            $errors->{create_dada_files_dir} = 0;
	        }			
		}
    }

    my $status = 1;
    for ( keys %$errors ) {
        if ( $errors->{$_} == 1 ) {

            # I guess there's exceptions to every rule:
            if (   $_ eq 'sql_table_populated'
                && $q->param('skip_configure_SQL') == 1 )
            {

                # Skip!
            }
            else {
                $status = 0;
                last;
            }
        }
    }
   # require Data::Dumper;
    #croak Data::Dumper::Dumper( $status, $errors );
    return ( $status, $errors );

}


sub install_dada_files_dir_at_from_params { 
	
	# None of the calls to this sub pass any variables. ?  
	my $install_dada_files_dir_at = undef;
	 
	if($q->param('install_type') eq 'upgrade'){ 
		$install_dada_files_dir_at = $q->param('current_dada_files_parent_location'); 
	}
	else { 
		
		if($q->param('dada_files_dir_setup') eq 'auto'){ 
			$install_dada_files_dir_at = auto_dada_files_dir(); 
		}
		else { 
			$install_dada_files_dir_at = $q->param('dada_files_loc'); 
		}
	}
	
	# Take off that last slash - goodness, will that annoy me: 
	$install_dada_files_dir_at =~ s/\/$//; 
	return $install_dada_files_dir_at; 

}


sub edit_config_file_for_plugins { 

	my ($args) = @_;

    my $dot_configs_file_loc = make_safer(
		$args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config'
	);
	
	my $config_file = slurp($dot_configs_file_loc);

	# Get those pesky cut tags out of the way... 
	$config_file =~ s/$admin_menu_begin_cut//; 
	$config_file =~ s/$admin_menu_end_cut//; 	 
	
	for my $plugins_data(%$plugins_extensions){ 
		if(exists($plugins_extensions->{$plugins_data}->{code})){
			if($args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files') { 
				# If we can already find the entry, we'll change the permissions of the 
				# plugin/extension
				my $orig_code = $plugins_extensions->{$plugins_data}->{code}; 
				my $uncommented_code = quotemeta(uncomment_admin_menu_entry($orig_code));
				if($config_file =~ m/$uncommented_code/){ 
					my $installer_successful = installer_chmod(0755, make_safer($plugins_extensions->{$plugins_data}->{loc}));
				}
			}
			else { 
				if($q->param('install_' . $plugins_data) == 1){ 
					my $orig_code = $plugins_extensions->{$plugins_data}->{code}; 
					my $uncommented_code = uncomment_admin_menu_entry($orig_code);
			 		$orig_code = quotemeta($orig_code); 
					$config_file =~ s/$orig_code/$uncommented_code/;

					# Fancy stuff for bounce handler, 
					if($plugins_data eq 'dada_bounce_handler'){ 
						# uncomment the plugins config, 
						$config_file =~ s/$plugins_config_begin_cut//; 
						$config_file =~ s/$plugins_config_end_cut//; 
					 	# then, we have to fill in all the stuff in.
					 	# Not a fav. tecnique!
					my $plugins_config_dada_bounce_handler_orig = quotemeta(
q|	Bounce_Handler => {
		Server                      => undef,
		Username                    => undef,
		Password                    => undef,|
					);
					my $dada_bounce_handler_address  = clean_up_var($q->param('dada_bounce_handler_address')); 
					my $dada_bounce_handler_server   = clean_up_var($q->param('dada_bounce_handler_server'));
					my $dada_bounce_handler_username = clean_up_var($q->param('dada_bounce_handler_username')); 
					my $dada_bounce_handler_password = clean_up_var($q->param('dada_bounce_handler_password')); 

					my $plugins_config_dada_bounce_handler_replace_with = 
"	Bounce_Handler => {
		Server                      => '$dada_bounce_handler_server',
		Username                    => '$dada_bounce_handler_username',
		Password                    => '$dada_bounce_handler_password',";
					$config_file =~ s/$plugins_config_dada_bounce_handler_orig/$plugins_config_dada_bounce_handler_replace_with/; 
					# Now, do the same for list settings defaults: 
					$config_file =~ s/$list_settings_defaults_begin_cut//; 
					$config_file =~ s/$list_settings_defaults_end_cut//; 

					# Now replace out the default code, with the config'd code: 
					my $plugins_config_list_settings_default_orig = quotemeta(
q|%LIST_SETUP_INCLUDE = (
	set_smtp_sender              => 1, # For SMTP
	add_sendmail_f_flag          => 1, # For Sendmail Command
	admin_email                  => 'bounces@example.com',
);|
					); 
					# Now replace out the default code, with the config'd code: 
					my $plugins_config_list_settings_default_replace_with =
qq|\%LIST_SETUP_INCLUDE = (
	set_smtp_sender              => 1, # For SMTP
	add_sendmail_f_flag          => 1, # For Sendmail Command
	admin_email                  => '$dada_bounce_handler_address',
);|; 
						$config_file =~ s/$plugins_config_list_settings_default_orig/$plugins_config_list_settings_default_replace_with/;
					}
					my $installer_successful = installer_chmod(0755, make_safer($plugins_extensions->{$plugins_data}->{loc}));
				}
			}
		}
	}
	
	if($args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files') { 

	}
	else { 
		# write it back? 
		installer_chmod(0777, $dot_configs_file_loc); 
		open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($dot_configs_file_loc) or croak $!;
		print $config_fh $config_file or croak $!;
		close $config_fh or croak $!;
		installer_chmod(0644, $dot_configs_file_loc);	
	}
	return 1; 
	

}
sub install_wysiwyg_editors { 
	my ($args) = @_;
	
	my $install = $q->param('install_wysiwyg_editors') || 0; 
	if($install != 1){ 
		return 1; 
	}
	
    my $dot_configs_file_loc = make_safer(
		$args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config'
	);
	
	my $config_file = slurp($dot_configs_file_loc);
	
	my $support_files_dir_path = $q->param('support_files_dir_path'); 
	
	
	if(! -d $support_files_dir_path) { 
		croak "Can't install WYSIWYG Editors, Directory, '$support_files_dir_path' does not exist!"; 
	}

	my %tmpl_vars = (
		fckeditor_enabled => 0, 
		fckeditor_url     => '', 
		
		ckeditor_enabled  => 0, 
		ckeditor_url      => '', 
		
		tiny_mce_enabled  => 0, 
		tiny_mce_url      => '', 
		
		kcfinder_enabled  => 0, 
		kcfinder_url      => '', 

	); 
	if(! -d $support_files_dir_path . '/' . $Support_Files_Dir_Name){ 
		installer_mkdir(make_safer($support_files_dir_path . '/' . $Support_Files_Dir_Name), $DADA::Config::DIR_CHMOD);
	}
	
	if($q->param('wysiwyg_editor_install_fckeditor') == 1){ 
		install_and_configure_fckeditor($args); 
		$tmpl_vars{i_fckeditor_enabled} = 1; 
		$tmpl_vars{i_fckeditor_url}     = $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name . '/fckeditor';
	}
	if($q->param('wysiwyg_editor_install_ckeditor') == 1){ 
		install_and_configure_ckeditor($args); 
		$tmpl_vars{i_ckeditor_enabled} = 1; 
		$tmpl_vars{i_ckeditor_url}     = $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name . '/ckeditor';
	}
	if($q->param('wysiwyg_editor_install_tiny_mce') == 1){ 
		install_and_configure_tiny_mce($args); 
		$tmpl_vars{i_tiny_mce_enabled} = 1; 
		$tmpl_vars{i_tiny_mce_url}     = $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name .'/tiny_mce';
	}
	if($q->param('file_browser_install_kcfinder') == 1){ 
		install_and_configure_kcfinder($args); 
		$tmpl_vars{i_kcfinder_enabled} = 1; 
		$tmpl_vars{i_kcfinder_url}     = $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name . '/kcfinder';

		my $upload_dir = make_safer($support_files_dir_path . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir); 
		$tmpl_vars{i_kcfinder_upload_dir} = $upload_dir; 
		$tmpl_vars{i_kcfinder_upload_url} = $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir;
		
		$tmpl_vars{i_session_dir} = $args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions';
		
		if(! -d  $upload_dir){ 
			# No need to backup this.
			installer_mkdir( $upload_dir, $DADA::Config::DIR_CHMOD );
		}
		
	}
	
	my $wysiwyg_options_snippet = DADA::Template::Widgets::screen(
        {
            -screen => 'wysiwyg_options_snippet.tmpl',
            -vars   => {
				%tmpl_vars
            }
        }
    );
	
    my $sm = quotemeta('# start cut for WYSIWYG Editor Options'); 
    my $em = quotemeta('# end cut for WYSIWYG Editor Options');
 

    $config_file =~ s/($sm)(.*?)($em)/$wysiwyg_options_snippet/sm; 

	# write it back? 
	installer_chmod(0777, $dot_configs_file_loc); 
	open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($dot_configs_file_loc) or croak $!;
	print $config_fh $config_file or croak $!;
	close $config_fh or croak $!;
	installer_chmod(0644, $dot_configs_file_loc);	
	
	return 1; 
}


sub install_and_configure_fckeditor { 
	my ($args) = @_; 
	my $install_path = $q->param('support_files_dir_path') . '/' . $Support_Files_Dir_Name; 
	my $source_package = make_safer('../extras/packages/fckeditor'); 
	my $target_loc     = make_safer($install_path . '/fckeditor');
	if(-d $target_loc){
		backup_dir($target_loc);	
	}
	installer_dircopy($source_package, $target_loc); 
}
sub install_and_configure_ckeditor { 
	my ($args) = @_; 
	my $install_path = $q->param('support_files_dir_path') . '/' . $Support_Files_Dir_Name; 
	my $source_package = make_safer('../extras/packages/ckeditor'); 
	my $target_loc     = make_safer($install_path . '/ckeditor');
	if(-d $target_loc){
		backup_dir($target_loc);	
	}
	installer_dircopy($source_package, $target_loc); 	
}
sub install_and_configure_tiny_mce { 
	my ($args) = @_; 
	my $install_path = $q->param('support_files_dir_path') . '/' . $Support_Files_Dir_Name; 
	my $source_package = make_safer('../extras/packages/tiny_mce'); 
	my $target_loc     = make_safer($install_path . '/tiny_mce');
	if(-d $target_loc){
		backup_dir($target_loc);	
	}
	installer_dircopy($source_package, $target_loc); 	
}
sub install_and_configure_kcfinder { 
	my ($args) = @_; 
	my $install_path = $q->param('support_files_dir_path') . '/' . $Support_Files_Dir_Name; 
	my $source_package = make_safer('../extras/packages/kcfinder'); 
	my $target_loc     = make_safer($install_path . '/kcfinder');
	if(-d $target_loc){
		backup_dir($target_loc);	
	}
	installer_dircopy($source_package, $target_loc); 	

	if($q->param('wysiwyg_editor_install_fckeditor') == 1){ 
		my $fckeditor_config_js = DADA::Template::Widgets::screen(
	        {
	            -screen => 'fckconfig_js.tmpl',
	            -vars   => {
	            	support_files_dir_url  => $q->param('support_files_dir_url'), 
					Support_Files_Dir_Name => $Support_Files_Dir_Name, 
				}
	        }
	    );
		my $fckeditor_config_loc = make_safer($install_path . '/fckeditor/dada_mail_config.js'); 
		installer_chmod(0777, $fckeditor_config_loc); 
		open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $fckeditor_config_loc or croak $!;
		print $config_fh $fckeditor_config_js or croak $!;
		close $config_fh or croak $!;
		installer_chmod(0644, $fckeditor_config_loc);
		undef $config_fh;
	}
	

	if($q->param('wysiwyg_editor_install_ckeditor') == 1){ 
		
		# http://docs.cksource.com/CKEditor_3.x/Developers_Guide/Setting_Configurations
		# The best way to set the CKEditor configuration is in-page, when creating editor instances. 
		# This method lets you avoid modifying the original distribution files in the CKEditor 
		# installation folder, making the upgrade task easier. 
		
		my $ckeditor_config_js = DADA::Template::Widgets::screen(
	        {
	            -screen => 'ckeditor_config_js.tmpl',
	            -vars   => {
	            	support_files_dir_url  => $q->param('support_files_dir_url'), 
					Support_Files_Dir_Name => $Support_Files_Dir_Name, 
				}
	        }
	    );
		my $ckeditor_config_loc = make_safer($install_path . '/ckeditor/dada_mail_config.js'); 
		installer_chmod(0777, $ckeditor_config_loc); 
		open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $ckeditor_config_loc or croak $!;
		print $config_fh $ckeditor_config_js or croak $!;
		close $config_fh or croak $!;
		installer_chmod(0644, $ckeditor_config_loc);
		undef $config_fh;
		
	}
	
	if($q->param('wysiwyg_editor_install_tiny_mce') == 1){ 
		
		my $tiny_mce_config_js = DADA::Template::Widgets::screen(
	        {
	            -screen => 'tiny_mce_config_js.tmpl',
	            -vars   => {
	            	support_files_dir_url  => $q->param('support_files_dir_url'), 
					Support_Files_Dir_Name => $Support_Files_Dir_Name, 
					kcfinder_enabled       => $q->param('file_browser_install_kcfinder'), 
				}
	        }
	    );
		my $tiny_mce_config_loc = make_safer($install_path . '/tiny_mce/dada_mail_config.js'); 
		installer_chmod(0777, $tiny_mce_config_loc); 
		open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $tiny_mce_config_loc or croak $!;
		print $config_fh $tiny_mce_config_js or croak $!;
		close $config_fh or croak $!;
		installer_chmod(0644, $tiny_mce_config_loc);
		undef $config_fh;
		
	}
	
	my $sess_dir = make_safer($args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions'); 
	if(! -d $sess_dir){ 
		installer_mkdir( $sess_dir, $DADA::Config::DIR_CHMOD )
	}
	my $kcfinder_config_php = DADA::Template::Widgets::screen(
        {
            -screen => 'kcfinder_config_php.tmpl',
            -vars   => {
				i_tinyMCEPath => $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name . '/tiny_mce',
				i_sessionDir  => $sess_dir,
			}
        }
    );
	my $kcfinder_config_loc = make_safer($install_path . '/kcfinder/config.php'); 
	installer_chmod(0777, $kcfinder_config_loc); 
	open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $kcfinder_config_loc or croak $!;
	print $config_fh $kcfinder_config_php or croak $!;
	close $config_fh or croak $!;
	installer_chmod(0644, $kcfinder_config_loc);
	undef $config_fh;
	
}


sub uncomment_admin_menu_entry { 

	my $str = shift; 
	$str =~ s/\#//g; 
	return $str; 	
}






sub program_url_guess {
    my $program_url = $Self_URL;
    $program_url =~ s{installer\/install\.cgi}{mail.cgi};
    return $program_url;
}


sub support_files_dir_path_guess { 
	return $ENV{DOCUMENT_ROOT}; 
}

sub support_files_dir_url_guess { 
	return $q->url(-base => 1);
}

sub hack_in_scriptalicious {
    my $scrn = shift;

    my $js = DADA::Template::Widgets::screen(
        {
            -screen => 'installer_extra_javascript_widget.tmpl',
            -vars => { my_S_PROGRAM_URL => program_url_guess(), Self_URL => $Self_URL }
        }
    );
    $scrn =~ s/\<head\>/\<head\>$js/;

    #/ Hackity Hack!

    return $scrn;
}




sub hack_program_url {
    my $scrn = shift;
    my $bad_program_url =
      quotemeta('http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi');
    my $better_prog_url = program_url_guess();
    $scrn =~ s/$bad_program_url/$better_prog_url/g;

    return $scrn;

}



sub test_can_create_dada_files_dir {

    my $dada_files_dir = shift;
	# blank?!
	if($dada_files_dir eq ''){ 
		return 1; 
	}
    $dada_files_dir =
      make_safer( $dada_files_dir . '/' . $Dada_Files_Dir_Name );

    if ( installer_mkdir( $dada_files_dir, $DADA::Config::DIR_CHMOD ) ) {
        if ( -e $dada_files_dir ) {
            installer_rmdir($dada_files_dir);
            return 0;
        }
        else {
            return 1;

        }
    }
    else {
        return 1;
    }

}




sub test_can_use_DBI {

    eval { require DBI; };
    if ($@) {
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
        return 0;
    }
    else {
        return 1;
    }
}

sub test_can_use_MySQL {
	
    eval { require DBD::mysql; };
    if ($@) {
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
        return 0;
    }
    else {
        return 1;
    }
}
sub test_can_use_Pg {
	
    eval { require DBD::Pg; };
    if ($@) {
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
        return 0;
    }
    else {
        return 1;
    }
}
sub test_can_use_SQLite {
	
    eval { require DBD::SQLite; };
    if ($@) {
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
        return 0;
    }
    else {
        return 1;
    }
}



sub test_str_is_blank {
	
    my $str = shift;
    if ( !defined($str) ) {
        return 1;
    }
    if ( $str eq "" ) {
        return 1;
    }
    return 0;
}

sub test_pass_match {

    my $pass        = shift;
    my $retype_pass = shift;

    if ( $pass eq $retype_pass ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub test_dada_files_dir_no_exists {
    my $dada_files_dir = shift;
    if ( -e $dada_files_dir . '/' . $Dada_Files_Dir_Name) {
        return 0;
    }
    else {

        return 1;
    }
}

sub test_complete_dada_files_dir_structure_exists {

    my $dada_files_dir = shift;
    if ( -e $dada_files_dir . '/' . $Dada_Files_Dir_Name ) {
        for (
            qw(
            .archives
            .backups
            .configs
            .lists
            .logs
            .templates
            .tmp
            )
          )
        {

            if ( !-e $dada_files_dir . '/' . $Dada_Files_Dir_Name . '/' . $_ ) {
                return 0;
            }

        }
    }
    else {
        return 0;
    }

    if (  -e $dada_files_dir . '/'
        . $Dada_Files_Dir_Name
        . '/.configs/.dada_config' )
    {
		# Seems to be all there! 
        return 1;
    }

}




sub test_sql_connection {
	
#	use Data::Dumper; 
#	croak Dumper([@_]);
    my $dbtype   = shift;
    my $dbserver = shift;
    my $port     = shift;
    my $database = shift;
    my $user     = shift;
    my $pass     = shift;

    if ( $port eq 'auto' ) {
        if ( $dbtype =~ /mysql/i ) {
            $port = 3306;
        }
        elsif ( $dbtype =~ /Pg/i ) {
            $port = 5432;
        }
    }
    else {
    }

    eval {
        my $dbh =
          connectdb( $dbtype, $dbserver, $port, $database, $user, $pass, );
    };
    if ($@) {
		carp $@; 
        $Big_Pile_Of_Errors .= $@; 
		return 0;
    }
    else {
        return 1;
    }

}


sub test_can_read_config_dot_pm {
    eval {
        my $config = slurp($Config_LOC);
        if ( length($config) > 0 ) {
            return 0;
        }
        else {
            return 1;
        }
    };
    if ($@) {
		carp $@; 
        $Big_Pile_Of_Errors .= $@; 
		return 1;
    }
}

sub test_can_write_config_dot_pm {

	if( -w  $Config_LOC){ 
			return 0; 
	}
	else { 
		return 1; # Returns 1 if can't. Flag is raised. 
	}
}

sub test_database_has_all_needed_tables {

    my $default_table_names = {
        dada_subscribers                   => 1,
        dada_profiles                      => 1,
        dada_profile_fields                => 1,
        dada_profile_fields_attributes     => 1,
        dada_archives                      => 1,
        dada_settings                      => 1,
        dada_sessions                      => 1,
        dada_bounce_scores                 => 1,
        dada_clickthrough_urls             => 1,
        dada_clickthrough_url_log          => 1,
        dada_mass_mailing_event_log        => 1,
#       dada_password_protect_directories  =>  1, # maybe? This is created by Dada Mail o first run, anyways. 
    };
    my $dbh;

    eval { $dbh = connectdb(@_); };
    if ($@) {
        carp $@;
        $Big_Pile_Of_Errors .= $@;
        return 0;
    }

    my @tables = $dbh->tables;
    my $checks = 0;

    #	use Data::Dumper;
    #	croak Dumper([@tables]);
    for my $table (@tables) {

        # Not sure why this is so non-standard between different setups...
        $table =~ s/`//g;
        $table =~
          s/^(.*?)\.//;    #This removes something like, "database_name.table"

        if ( exists( $default_table_names->{$table} ) ) {
            $checks++;
        }
    }

    if ( $checks >= 9 ) {
        return 1;
    }
    else {
        return 0;
    }

}

sub test_database_empty {
    my $dbh = undef;

    eval { $dbh = connectdb(@_); };
    if ($@) { 
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
		return 0;
	 }

    my @tables = $dbh->tables;
    if ( exists( $tables[0] ) ) {
        return 0;
    }
    else {
        return 1;
    }

}

sub test_current_dada_dot_config_file_validates { 
	my $config_file = shift; 
	
}

sub move_installer_dir_ajax { 

	my ($new_dir_name, $eval_errors) = move_installer_dir(); 
	e_print($q->header()); 	 
		e_print("
		<fieldset> 
		<legend>
			Move Results
		</legend> 
	
	"); 
	my $installer_moved = 0; 
	if(-e '../installer'){ 
		# ... 
	}elsif(-e $new_dir_name){ 
		$installer_moved = 1; 
	}
	
	if($eval_errors || $installer_moved == 0){ 
		e_print("<p class=\"errors\">Problems! <code>$eval_errors</code></p><p>You'll have to manually move the, <em>dada/<strong>installer</strong></em>  directory."); 
	}
	else {
		
		e_print("
		<ul><li><p>installer directory moved to <em>$new_dir_name</em>,</p></li><li> <p>Installer disabled!</p></li></ul>");
	}
	e_print("</fieldset>"); 
	
}



sub show_current_dada_config { 
	print $q->header('text/plain'); 
    my $config_file_loc = $q->param('config_file'); 
        my $config_file_contents =
          DADA::Template::Widgets::_slurp($config_file_loc);
	print e_print($config_file_contents);
}

sub move_installer_dir { 
	
	my $time = time;
	require DADA::Security::Password; 
	my $ran_str = DADA::Security::Password::generate_rand_string(); 
	my $new_dir_name = make_safer("../installer-disabled.$ran_str.$time"); 
	eval { 
		#`mv ../installer $new_dir_name`;
		installer_mv(make_safer('../installer'), $new_dir_name); 
		installer_chmod(0644, make_safer('install.cgi')); 
	};
	my $errors = undef; 
	if($@){ 
		$errors = $@; 
	}
	
	return ($new_dir_name, $@); 
		
}

sub slurp {

    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open( F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      || croak "open $file: $!";
    @r = <F>;
    close(F) || croak "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}

# The bummer is that I may need to cp this to the uncompress_dada.cgi file - ugh!

sub installer_cp { 
	require File::Copy; 
	my ($to, $from) = @_; 
	my $r = File::Copy::copy($to,$from);# or croak "Copy failed: $!";
	return $r; 
}

sub installer_mv { 
	require File::Copy; 
	my ($to, $from) = @_; 
	my $r = File::Copy::move($to,$from);# or croak "Copy failed: $!";
	return $r; 
}

sub installer_rm { 
	my $file = shift; 
	my $count = unlink($file); 
	return $count; 
}

sub installer_chmod { 
	my ($octet, $file) = @_; 
	my $r = chmod($octet, $file);
	return $r; 
}
sub installer_mkdir { 
	my ($dir, $chmod) = @_; 
	my $r = mkdir($dir, $chmod); 
	return $r; 
}
sub installer_rmdir { 
	my $dir = shift; 
	my $r = rmdir($dir); 	
	return $r; 
}

sub installer_dircopy { 
	my ($source, $target) = @_; 
	require File::Copy::Recursive; 
	File::Copy::Recursive::dircopy($source, $target) 
		or die "can't copy directory from, '$source' to, '$target' because: $!";
}
sub backup_dir { 
	my $source = shift; 
	   $source =~ s/\/$//;
	my $target = undef; 
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $timestamp = sprintf("%4d-%02d-%02d", $year+1900,$mon+1,$mday) . '-' . time;
	
	my $target = make_safer(
		$source . '-backup-' . $timestamp
	); 
	
	require File::Copy::Recursive; 
	File::Copy::Recursive::dirmove($source, $target) 
		or die $!;
}

sub auto_dada_files_dir {
    return guess_home_dir();
}

sub create_htaccess_deny_from_all_file { 
	my $loc = shift; 
	my $htaccess_file = make_safer($loc . '/.htaccess');
	open my $htaccess, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $htaccess_file or croak $!;
	print   $htaccess "deny from all\n" or croak $!;
	close   $htaccess or croak $!;
	installer_chmod(0644, $htaccess_file); 
}

sub guess_home_dir {
	
	my $home_dir = undef; 
	eval { 
		require File::HomeDir; 
	};
	if($@){ 
		$Big_Pile_Of_Errors .= $@; 
		carp 'File::HomeDir not installed? ' . $@; 
		$home_dir = guess_home_dir_via_getpwuid_call(); 
	}
	else { 
		$home_dir = guess_home_dir_via_FileHomeDir(); 
		if(!defined($home_dir)){ 
			$home_dir = guess_home_dir_via_getpwuid_call(); 
		}
	}

	return $home_dir;
}

sub guess_home_dir_via_FileHomeDir { 
	# Needs IPC::Run3 and File::Which and File::Temp - 
	# http://deps.cpantesters.org/?module=File%3A%3AHomeDir&perl=5.8.1&os=any+OS
	
	require File::HomeDir; 
	my $home_dir =  File::HomeDir->my_data; 
	return $home_dir; 


}



sub guess_home_dir_via_getpwuid_call{ 
 
	# I hate this. 
    my $home_dir_guess = undef;
    my $doc_root     = $ENV{DOCUMENT_ROOT};
    my $pub_html_dir = $doc_root;
    $pub_html_dir =~ s(^.*/)();
    my $getpwuid_call;
    eval { $getpwuid_call = ( getpwuid $> )[7] };
    if ( !$@ ) {
        $home_dir_guess = $getpwuid_call;
    }
    else {
		$Big_Pile_Of_Errors .= $@; 
        $home_dir_guess =~ s/\/$pub_html_dir$//g;
    }
    return $home_dir_guess;	
}




sub clean_up_var { 
	my $var = shift; 
	   $var =~ s/\'/\\\'/g; 
	return $var; 
}




1;
