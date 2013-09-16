package DadaMailInstaller; 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1;}
#FindBin
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
  if $BootstrapConfig::NPH == 1;
my $q;
$q = CGI->new;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);


# These are script-wide variables
#
# $Self_URL may need not be set manually - but I'm hoping not. 
# If the script doesn't post properly, go ahead and configure it manually
#
my $Self_URL            = self_url();

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
	bridge                        => {installed => 0, loc => '../plugins/bridge.cgi'}, 
	bounce_handler                => {installed => 0, loc => '../plugins/bounce_handler.cgi'}, 
	scheduled_mailings            => {installed => 0, loc => '../plugins/scheduled_mailings.pl'}, 
	multiple_subscribe            => {installed => 0, loc => '../extensions/multiple_subscribe.cgi'}, 
	blog_index                    => {installed => 0, loc => '../extensions/blog_index.cgi'}, 
	mailing_monitor               => {installed => 0, loc => '../plugins/mailing_monitor.cgi'}, 
	default_mass_mailing_messages => {installed => 0, loc => '../plugins/default_mass_mailing_messages.cgi'}, 
	password_protect_directories  => {installed => 0, loc => '../plugins/password_protect_directories.cgi'}, 
	change_list_shortname         => {installed => 0, loc => '../plugins/change_list_shortname.cgi'},  
	global_config                 => {installed => 0, loc => '../plugins/global_config.cgi'},   
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

$plugins_extensions->{bridge}->{code} = 
q{#					{
#					-Title      => 'Bridge',
#					-Title_URL  => $PLUGIN_URL."/bridge.cgi",
#					-Function   => 'bridge',
#					-Activated  => 1,
#					},};

$plugins_extensions->{bounce_handler}->{code} = 
q{#					{
#					-Title      => 'Bounce Handler',
#					-Title_URL  => $PLUGIN_URL."/bounce_handler.cgi",
#					-Function   => 'bounce_handler',
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

$plugins_extensions->{global_config}->{code} =
q{#					{
#					-Title      => 'Global Configuration',
#					-Title_URL  => $PLUGIN_URL."/global_config.cgi",
#					-Function   => 'global_config',
#					-Activated  => 0,
#					},};

my $advanced_config_params = {
    show_profiles                       => 1,
    show_global_template_options        => 1,
    show_security_options               => 1,
    show_captcha_options                => 1, 
    show_global_mass_mailing_options    => 1,
    show_cache_options                  => 1,
    show_debugging_options              => 1,
    show_amazon_ses_options             => 1,
    show_annoying_whiny_pro_dada_notice => 0,
};

# An unconfigured Dada Mail won't have these exactly handy to use. 
$DADA::Config::PROGRAM_URL   = program_url_guess();
$DADA::Config::S_PROGRAM_URL = program_url_guess();

use DADA::Config 6.0.0;


    # $DADA::Config::USER_TEMPLATE = '';
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
            screen                   => \&screen,
            cgi_test_sql_connection  => \&cgi_test_sql_connection,
            cgi_test_pop3_connection => \&cgi_test_pop3_connection,
			cgi_test_user_template   => \&cgi_test_user_template, 
            cgi_test_amazon_ses_configuration =>
              \&cgi_test_amazon_ses_configuration,
			cgi_test_CAPTCHA_reCAPTCHA => \&cgi_test_CAPTCHA_reCAPTCHA,
			#cgi_test_CAPTCHA_reCAPTCHA_iframe => \&cgi_test_CAPTCHA_reCAPTCHA_iframe, 
			cgi_test_default_CAPTCHA => \&cgi_test_default_CAPTCHA, 
			cgi_test_captcha_reCAPTCHA_Mailhide => \&cgi_test_captcha_reCAPTCHA_Mailhide,  
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
		'upgrading!',
        'if_dada_files_already_exists=s',
        'program_url=s',
		'support_files_dir_path=s',
		'support_files_dir_url=s',
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
		'install_plugins=s@', 
		'install_wysiwyg_editors!',
		'wysiwyg_editor_install_ckeditor!',
		'wysiwyg_editor_install_tiny_mce!',
		'wysiwyg_editor_install_fckeditor!',
		'file_browser_install_kcfinder!',
		'help',
    );

#	use Data::Dumper; 
#	die Dumper({%h}); 
	
	if(exists($h{upgrading})){ 
		if($h{upgrading} == 1) { 
			$q->param('install_type', 'upgrade');
			$q->param('if_dada_files_already_exists', 'keep_dir_create_new_config');
			$q->param('current_dada_files_parent_location', $h{dada_files_loc}); 
			$q->param('dada_pass_use_orig', 1); 
			$q = grab_former_config_vals($q);
		}
	}
	
	if(exists($h{install_plugins})){ 
	my @install_plugins	 = split(/,/,join(',',@{$h{install_plugins}}));
		for(@install_plugins){ 
			$q->param('install_' . $_, 1); 
		}
		delete $h{install_plugins};
	}

 	# This is very lazy of me - $q->param() is being used as a stash for persistance 
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
		$q->param('dada_pass_use_orig', 0); 
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
	e_print(DADA::Template::Widgets::screen(
        {
            -screen => 'cl_quickhelp_scrn.tmpl',
            -vars => {

            },
        }
    ));	
}

sub cl_help { 
	
	e_print( DADA::Template::Widgets::screen(
        {
            -screen => 'cl_help_scrn.tmpl',
            -vars => {

            },
        }
    ));	
}




sub install_or_upgrade { 
	
	eval { 
		require DADA::App::ScreenCache; 
		my $c = DADA::App::ScreenCache->new; 
		   $c->flush;
	};
	
#	 my $dada_files_parent_dir = $DADA::Config::CONFIG_FILE;
	my $dada_files_parent_dir = BootstrapConfig::guess_config_file(); 
	
	   $dada_files_parent_dir =~ s/\/$Dada_Files_Dir_Name\/\.configs\/\.dada_config//;
	my $found_existing_dada_files_dir = test_complete_dada_files_dir_structure_exists($dada_files_parent_dir);

   my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'install_or_upgrade.tmpl',
			-with   => 'list', 
            -vars => {
				# These are tricky.... 
				SUPPORT_FILES_URL               => $Self_URL . '?f=screen&screen=',


				dada_files_parent_dir               => $dada_files_parent_dir, 
				Dada_Files_Dir_Name                 => $Dada_Files_Dir_Name, 
				found_existing_dada_files_dir       => $found_existing_dada_files_dir ,
				current_dada_files_parent_location  => $q->param('current_dada_files_parent_location'), 
				error_cant_find_dada_files_location => $q->param('error_cant_find_dada_files_location'), 
				Self_URL                            => $Self_URL, 
				
				
			},
		}
	); 
	
	# Let's get some fancy js stuff!
    $scrn = hack_in_js($scrn);
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
	my $install_type                       = $q->param('install_type'); 
	
	if($install_type eq 'upgrade'
	 && -e $current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name .'/.configs/.dada_config'
	){ 
		BootstrapConfig::config_import(make_safer($current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name .'/.configs/.dada_config')); 
	}
	
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
		$q->param('install_blog_index', 1); 
		$q->param('install_default_mass_mailing_messages', 1); 
		$q->param('install_change_list_shortname', 1); 
		$q->param('global_config', 0); 		
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
		if(test_can_create_dada_files_dir(auto_dada_files_dir()) == 0 ){ 
			$q->param('dada_files_loc', auto_dada_files_dir()); 
			$q->param('dada_files_dir_setup', 'manual');  
		}	
	}
	
	my $configured_dada_config_file; 
	my $configured_dada_files_loc; 
	my $original_dada_root_pass = undef; 
	
	my $param_vals_from_former_config = undef; 
	if($install_type eq 'upgrade'){ 
		$configured_dada_config_file = $current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name .'/.configs/.dada_config'; 
		$configured_dada_files_loc   = $current_dada_files_parent_location; 
		$original_dada_root_pass = $BootstrapConfig::PROGRAM_ROOT_PASSWORD; # Why is this here, instead of grab_...
		
	}
	else { 
	   $configured_dada_config_file = $DADA::Config::CONFIG_FILE; # This may also be strange, although if this is an install, it'll just give you the default guess, anyways
	   $configured_dada_files_loc = $configured_dada_config_file;
		$configured_dada_files_loc =~ s/\/$Dada_Files_Dir_Name\/\.configs\/\.dada_config//;
	}
	
	my $DOC_VER = $DADA::Config::VER; # I guess this one's fine. 
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
	
				%$advanced_config_params, 
				
				# These are tricky.... 
				SUPPORT_FILES_URL               => $Self_URL . '?f=screen&screen=',
				
				install_type                => $install_type, 
				current_dada_files_parent_location => $current_dada_files_parent_location, 
				
                program_url_guess              => program_url_guess(),
                can_use_DBI                    => test_can_use_DBI(),
				can_use_MySQL                  => test_can_use_MySQL(), 
				can_use_Pg                     => test_can_use_Pg(), 
				can_use_SQLite                 => test_can_use_SQLite(), 
				can_use_GD                     => test_can_use_GD(), 	
				can_use_CAPTCHA_reCAPTCHA      => test_can_use_CAPTCHA_reCAPTCHA(), 							
				can_use_CAPTCHA_reCAPTCHA_Mailhide => test_can_use_CAPTCHA_reCAPTCHA_Mailhide(), 							

                error_cant_read_config_dot_pm  => test_can_read_config_dot_pm(),
                error_cant_write_config_dot_pm => test_can_write_config_dot_pm(),
				home_dir_guess                 => guess_home_dir(),
				install_dada_files_dir_at      => install_dada_files_dir_at_from_params(),
			    test_complete_dada_files_dir_structure_exists 
											   => test_complete_dada_files_dir_structure_exists(install_dada_files_dir_at_from_params()), 
				dada_files_dir_setup           => $q->param('dada_files_dir_setup') || '', 
                dada_files_loc                 => $q->param('dada_files_loc') || '',
				error_create_dada_mail_support_files_dir  
											   => $q->param('error_create_dada_mail_support_files_dir') || 0,
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
				#lists_available                => $lists_available, 
				configured_dada_config_file    => $configured_dada_config_file,
				configured_dada_files_loc      => $configured_dada_files_loc, 
				DOC_VER                        => $DOC_VER, 
				DOC_URL                        => 'http://dadamailproject.com/support/documentation-' . $DOC_VER, 
				
				original_dada_root_pass        => $original_dada_root_pass, 
				
				support_files_dir_path         => support_files_dir_path_guess(),
				support_files_dir_url         => support_files_dir_url_guess(),
				Support_Files_Dir_Name        => $Support_Files_Dir_Name,
				
				amazon_ses_requirements_widget => DADA::Template::Widgets::amazon_ses_requirements_widget(), 
				
				Big_Pile_Of_Errors             => $Big_Pile_Of_Errors,
				Trace                          => $Trace, 
				

            },
        }
    );

    # Let's get some fancy js stuff!
    $scrn = hack_in_js($scrn);
	# Uh, do are darnest to get the $PROGRAM_URL stuff working correctly, 
	$scrn = hack_program_url($scrn); 

        require HTML::FillInForm::Lite;
        my $h = HTML::FillInForm::Lite->new();
		if(
			$install_type eq 'upgrade' 
		&& -e $configured_dada_config_file
		&& !defined($q->param('errors'))
		
		){ 
			$q = grab_former_config_vals($q);
		}

        $scrn = $h->fill( \$scrn, $q );

    e_print($scrn);

}

sub grab_former_config_vals { 
	my $local_q = shift; 
	
	# $PROGRAM_URL
	$local_q->param('program_url', $BootstrapConfig::PROGRAM_URL); 
	
	# $SUPPORT_FILES
	my $support_files_dir_path;
	if(defined($BootstrapConfig::SUPPORT_FILES->{dir})) { 
		($support_files_dir_path) =  $BootstrapConfig::SUPPORT_FILES->{dir} =~ m/^(.*?)\/$Support_Files_Dir_Name$/; 
		$local_q->param('support_files_dir_path', $support_files_dir_path);  
	}
	else { 
		# in v5, there was no $SUPPORT_FILES var, but we're using the same dir as KCFinder, so we can look there: 
		($support_files_dir_path) = $BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{upload_dir} =~ m/^(.*?)\/$Support_Files_Dir_Name\/$File_Upload_Dir$/; 
		$local_q->param('support_files_dir_path', $support_files_dir_path);  
	}
	my $support_files_dir_url; 
	if(defined($BootstrapConfig::SUPPORT_FILES->{url})){ 
		($support_files_dir_url)  =  $BootstrapConfig::SUPPORT_FILES->{url} =~ m/^(.*?)\/$Support_Files_Dir_Name$/; 
		$local_q->param('support_files_dir_url', $support_files_dir_url);  
	}
	else { 
		# in v5, there was no $SUPPORT_FILES var, but we're using the same dir as KCFinder, so we can look there: 
		($support_files_dir_url) = $BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{upload_url} =~ m/^(.*?)\/$Support_Files_Dir_Name\/$File_Upload_Dir$/; 
		$local_q->param('support_files_dir_url', $support_files_dir_url);  
	}
	
	
	# $PROGRAM_ROOT_PASSWORD
	$local_q->param('original_dada_root_pass',              $BootstrapConfig::PROGRAM_ROOT_PASSWORD); 
	$local_q->param('original_dada_root_pass_is_encrypted', $BootstrapConfig::ROOT_PASS_IS_ENCRYPTED);
	
	# BACKEND
	# In v5 and earlier, there was no $BACKEND_DB, so we'll see what we have, 
	if(
	(  $BootstrapConfig::SUBSCRIBER_DB_TYPE       eq 'SQL' 
	&& $BootstrapConfig::ARCHIVE_DB_TYPE          eq 'SQL' 
	&& $BootstrapConfig::SETTINGS_DB_TYPE         eq 'SQL' 
	&& $BootstrapConfig::SESSION_DB_TYPE          eq 'SQL'
	&& $BootstrapConfig::BOUNCE_SCORECARD_DB_TYPE eq 'SQL'
	&& $BootstrapConfig::CLICKTHROUGH_DB_TYPE     eq 'SQL'
	) 
	|| 
	($BootstrapConfig::BACKEND_DB_TYPE eq 'SQL')
	){ 
		# That means, we have an SQL backend. 
		#%SQL_PARAMS; 
		$local_q->param('backend',      $BootstrapConfig::SQL_PARAMS{dbtype});  
		$local_q->param('sql_server',   $BootstrapConfig::SQL_PARAMS{dbserver}); 	
		$local_q->param('sql_database', $BootstrapConfig::SQL_PARAMS{database}); 	
		$local_q->param('sql_port',     $BootstrapConfig::SQL_PARAMS{port}); 	
		$local_q->param('sql_username', $BootstrapConfig::SQL_PARAMS{user}); 	
		$local_q->param('sql_password', $BootstrapConfig::SQL_PARAMS{pass});
		
	}
	elsif($BootstrapConfig::BACKEND_DB_TYPE eq 'Default') { 
		$local_q->param('backend', 'default'); 
	}
	elsif(
			$BootstrapConfig::SUBSCRIBER_DB_TYPE eq 'Default'
		 || $BootstrapConfig::SETTINGS_DB_TYPE   eq 'Default' 
	) { 
		$local_q->param('backend', 'default'); 
	}
		
	# Plugins/Extensions
	for my $plugin_ext(qw(
		mailing_monitor
		change_root_password
		screen_cache
		log_viewer
		tracker
		bridge
		bounce_handler
		scheduled_mailings
		multiple_subscribe
		blog_index
		default_mass_mailing_messages
		change_list_shortname
		global_config
		password_protect_directories
		)){ 
		if(admin_menu_item_used($plugin_ext) == 1){ 
			$local_q->param('install_' . $plugin_ext, 1); 
		}
		else { 
			$local_q->param('install_' . $plugin_ext, 0); 			
		}
	}
	# in ver. < 6, these were called something different... 
	if(admin_menu_item_used('dada_bounce_handler') == 1){ 
		$local_q->param('install_bounce_handler', 1); 
	}
	if(admin_menu_item_used('dada_bridge') == 1){ 
		$local_q->param('install_bridge', 1); 
	}
	if(admin_menu_item_used('auto_pickup') == 1){ 
		$local_q->param('install_mailing_monitor', 1); 
	}
	if(admin_menu_item_used('clickthrough_tracking') == 1){ 
		$local_q->param('install_tracker', 1); 
	}
	
	# Bridge
	if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bridge})) { 
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{MessagesAtOnce})){ 
			$local_q->param('bridge_MessagesAtOnce', $BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{MessagesAtOnce}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{Soft_Max_Size_Of_Any_Message})){ 
			$local_q->param('bridge_Soft_Max_Size_Of_Any_Message', $BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{Soft_Max_Size_Of_Any_Message}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{Max_Size_Of_Any_Message})){ 
			$local_q->param('bridge_Max_Size_Of_Any_Message', $BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{Max_Size_Of_Any_Message}); 
		}
	}
	
	# Bounce Handler
	if(exists($BootstrapConfig::LIST_SETUP_INCLUDE{admin_email})){ 
		$local_q->param('bounce_handler_address', $BootstrapConfig::LIST_SETUP_INCLUDE{admin_email});
	}
	if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler})) { 
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{Server})){ 
			$local_q->param('bounce_handler_server', $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{Server}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{Username})){ 
			$local_q->param('bounce_handler_username', $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{Username}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{Password})){ 
			$local_q->param('bounce_handler_password', $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{Password}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{USESSL})){ 
			$local_q->param('bounce_handler_USESSL', $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{USESSL}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{AUTH_MODE})){ 
			$local_q->param('bounce_handler_AUTH_MODE', $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{AUTH_MODE}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{MessagesAtOnce})){ 
			$local_q->param('bounce_handler_MessagesAtOnce', $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{MessagesAtOnce}); 
		}
	}
	# "Bounce_Handler" could also be, "Mystery_Girl" (change made in v4.9.0)
	elsif(exists($BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl})) { 
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Server})){ 
			$local_q->param('bounce_handler_server', $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Server}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Username})){ 
			$local_q->param('bounce_handler_username', $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Username}); 
		}
		if(exists($BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Password})){ 
			$local_q->param('bounce_handler_password', $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Password}); 
		}		
	}
	
	# WYSIWYG Editors 
	# Kinda gotta guess on this one, 
	if($BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{fckeditor}->{enabled} == 1 
	|| $BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{enabled} == 1 
	|| $BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{enabled} == 1 
	){ 
		$local_q->param('install_wysiwyg_editors', 1); 
	}
	else { 
		$local_q->param('install_wysiwyg_editors', 0); 
	}
		
	for my $editor(qw(ckeditor fckeditor tiny_mce)){ 
		# And then, individual: 
		if($BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{$editor}->{enabled} == 1){ 
			$local_q->param('wysiwyg_editor_install_' . $editor, 1); 
		}
		else { 
			$local_q->param('wysiwyg_editor_install_' . $editor, 0); 		
		}
	}
	if($BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} == 1){ 
		$local_q->param('file_browser_install_kcfinder', 1);
	}	
	else { 
		$local_q->param('file_browser_install_kcfinder', 0);
	}
	
	# Profiles
	if(exists($BootstrapConfig::PROFILE_OPTIONS->{enabled})) { 
		
		$local_q->param('configure_profiles', 1);
		
		for(qw(enabled profile_email enable_captcha enable_magic_subscription_forms)){ 
			if(exists($BootstrapConfig::PROFILE_OPTIONS->{$_})){ 
				$local_q->param('profiles_' . $_, $BootstrapConfig::PROFILE_OPTIONS->{$_}); 
			}
		}
		# Features 
		
		for(qw(
			help                      
			login                     
			register                  
			password_reset            
			profile_fields            
			mailing_list_subscriptions
			protected_directories     
			update_email_address      
			change_password
			delete_profile  
		)) { 
			if(exists($BootstrapConfig::PROFILE_OPTIONS->{features}->{$_})){ 
				$local_q->param('profiles_' . $_, $BootstrapConfig::PROFILE_OPTIONS->{features}->{$_}); 
			}			
		}          

	}
	
	# Global Template Options 
	if(defined($BootstrapConfig::USER_TEMPLATE)) { 
		$local_q->param('configure_templates', 1); 
		$local_q->param('configure_user_template', 1); 
		$local_q->param('template_options_USER_TEMPLATE', $BootstrapConfig::USER_TEMPLATE); 		
	}

	# Caching Options 
	if(defined($BootstrapConfig::SCREEN_CACHE) || defined($BootstrapConfig::DATA_CACHE)) { 
		$local_q->param('configure_cache', 1); 
		# Watch this, now: 
		if(defined($BootstrapConfig::SCREEN_CACHE)) {
			if($BootstrapConfig::SCREEN_CACHE ne '1') {				
				$local_q->param('cache_options_SCREEN_CACHE', 0); 	
			}
			else { 
				$local_q->param('cache_options_SCREEN_CACHE', 1); 	
			}		
		}
		if(defined($BootstrapConfig::DATA_CACHE)) { 
			if($BootstrapConfig::DATA_CACHE ne '1') {
				$local_q->param('cache_options_DATA_CACHE', 0); 			
			}
			else {
				$local_q->param('cache_options_DATA_CACHE', 1); 	
			}
		}
	}
	else { 
		# Defaul to, "1". Better way? 
		$local_q->param('cache_options_SCREEN_CACHE', 1); 	
		$local_q->param('cache_options_DATA_CACHE', 1); 			
	}


	# Debugging Options 
	if(defined($BootstrapConfig::DEBUG_TRACE) || defined(%BootstrapConfig::CPAN_DEBUG_SETTINGS)) { 
		$local_q->param('configure_debugging', 1); 
		foreach(keys %{$BootstrapConfig::DEBUG_TRACE}) { 
			$local_q->param(
				'debugging_options_' . $_,
				$BootstrapConfig::DEBUG_TRACE->{$_}
			);
		}
		foreach(keys %BootstrapConfig::CPAN_DEBUG_SETTINGS) { 
			$local_q->param(
				'debugging_options_' . $_,
				$BootstrapConfig::CPAN_DEBUG_SETTINGS{$_}
			);
		}

	}
	# Configure CAPTCHA
	if(
		defined($BootstrapConfig::CAPTCHA_TYPE) || 
		keys %{$BootstrapConfig::RECAPTCHA_PARAMS} || 
		keys %{$BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS}
	) { 
		$local_q->param('configure_captcha', 1);
		
		if($BootstrapConfig::CAPTCHA_TYPE eq 'Default'){ 
			$local_q->param('captcha_type', 'Default');
		}
		elsif($BootstrapConfig::CAPTCHA_TYPE eq 'reCAPTCHA'){
			$local_q->param('captcha_type', 'reCAPTCHA');
		}
		
		if(defined($BootstrapConfig::RECAPTCHA_PARAMS->{remote_address})){ 
			$q->param('captcha_reCAPTCHA_remote_addr', $BootstrapConfig::RECAPTCHA_PARAMS->{remote_address}); 
		}
		if(defined($BootstrapConfig::RECAPTCHA_PARAMS->{public_key})){ 
			$q->param('captcha_reCAPTCHA_public_key', $BootstrapConfig::RECAPTCHA_PARAMS->{public_key}); 
		}
		if(defined($BootstrapConfig::RECAPTCHA_PARAMS->{private_key})){ 
			$q->param('captcha_reCAPTCHA_private_key', $BootstrapConfig::RECAPTCHA_PARAMS->{private_key}); 
		}
		
		if(defined($BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS->{public_key})){ 
			$q->param('captcha_reCAPTCHA_Mailhide_public_key', $BootstrapConfig::RECAPTCHA_PARAMS->{public_key}); 
		}
		if(defined($BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS->{private_key})){ 
			$q->param('captcha_reCAPTCHA_Mailhide_private_key', $BootstrapConfig::RECAPTCHA_PARAMS->{private_key}); 
		}
	}

	# Configure Security Options
	if(
		defined($BootstrapConfig::SHOW_ADMIN_LINK)
	||  defined($BootstrapConfig::DISABLE_OUTSIDE_LOGINS)
	||  defined($BootstrapConfig::ADMIN_FLAVOR_NAME)
	||  defined($BootstrapConfig::SIGN_IN_FLAVOR_NAME)
	) { 
		$local_q->param('configure_security', 1);
		if($BootstrapConfig::SHOW_ADMIN_LINK == 2){ 
			$local_q->param('security_no_show_admin_link', 1);
		}
		else { 
			$local_q->param('security_no_show_admin_link', 0);
		}
	}

	
	
	
	# Mass Mailing Options
	if(
		defined($BootstrapConfig::MAILOUT_AT_ONCE_LIMIT)
	||  defined($BootstrapConfig::MULTIPLE_LIST_SENDING)
	||  defined($BootstrapConfig::MAILOUT_STALE_AFTER)
		
	){ 
		$local_q->param('configure_mass_mailing', 1); 
		$local_q->param('mass_mailing_MAILOUT_AT_ONCE_LIMIT', $BootstrapConfig::MAILOUT_AT_ONCE_LIMIT);	
		$local_q->param('mass_mailing_MULTIPLE_LIST_SENDING', $BootstrapConfig::MULTIPLE_LIST_SENDING);	
		$local_q->param('mass_mailing_MAILOUT_STALE_AFTER',   $BootstrapConfig::MAILOUT_STALE_AFTER);		
	}
	
	# $AMAZON_SES_OPTIONS
	if(defined($BootstrapConfig::AMAZON_SES_OPTIONS->{AWSAccessKeyId})
	&& defined($BootstrapConfig::AMAZON_SES_OPTIONS->{AWSSecretKey}) 
	){ 
		$local_q->param('configure_amazon_ses', 1);
		$local_q->param('amazon_ses_AWSAccessKeyId', $BootstrapConfig::AMAZON_SES_OPTIONS->{AWSAccessKeyId});
		$local_q->param('amazon_ses_AWSSecretKey',   $BootstrapConfig::AMAZON_SES_OPTIONS->{AWSSecretKey});
	}
			
	
	return $local_q; 
	
}


sub admin_menu_item_used { 
	my $function = shift; 
	foreach my $menu(@$BootstrapConfig::ADMIN_MENU){ 
		if($menu->{-Title} =~ m/Plugins|Extensions/){ 
			my $submenu = $menu->{-Submenu}; 
			foreach my $item(@$submenu) { 
			#	warn q{$item->{-Function} } . $item->{-Function}; 
			#	warn q{$function} . $function; 
				if($item->{-Function} eq $function){ 
		#			warn $function . 'is returning 1'; 
					return 1; 
				}
			}
		}
	}
#	warn $function . ' is returning 0'; 
	return 0; 
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
	
			# These are tricky.... 
			SUPPORT_FILES_URL               => $Self_URL . '?f=screen&screen=',
			
			
			 install_log                  => plaintext_to_html({-str =>$log}), 
			 status                       => $status, 
			install_dada_files_loc        => $install_dada_files_loc,
			Dada_Files_Dir_Name           => $Dada_Files_Dir_Name, 
			error_cant_edit_config_dot_pm => $errors->{cant_edit_config_dot_pm} || 0, 
			Big_Pile_Of_Errors            => $Big_Pile_Of_Errors,
			Trace                         => $Trace, 
			PROGRAM_URL                   => program_url_guess(),
            S_PROGRAM_URL                 => program_url_guess(),
			submitted_PROGRAM_URL         => $q->param('program_url'),
			Self_URL                      => $Self_URL, 
			
	 		}
        }
    );
    $scrn = hack_in_js($scrn);

	# Uh, do are darnest to get the $PROGRAM_URL stuff working correctly, 
	$scrn = hack_program_url($scrn); 

    e_print($scrn);

}

sub install_dada_mail {
    my ($args) = @_;
    my $log    = undef;
    my $errors = {};
    my $status = 1;

    if (
        $args->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config' )
    {
        $log .= "* Backing up current configuration file\n";
        eval { backup_current_config_file($args); };
        if ($@) {
            $log .= "* Problems backing up config file: $@\n";
            $errors->{cant_backup_orig_config_file} = 1;
        }
        else {
            $log .= "* Success!\n";
        }
    }

    if ( $args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' )
    {
        $log .=
"* Skipping configuration of directory creation, config file and backend options\n";
    }
    else {
        $log .=
            "* Attempting to make $DADA::Config::PROGRAM_NAME Files at, "
          . $args->{-install_dada_files_loc} . '/'
          . $Dada_Files_Dir_Name . "\n";

        if ( $args->{-if_dada_files_already_exists} eq
            'keep_dir_create_new_config' )
        {
            $log .= "* Skipping directory creation\n";
        }
        else {
            # Making the .dada_files structure
            if (
                create_dada_files_dir_structure(
                    $args->{-install_dada_files_loc}
                ) == 1
              )
            {
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
            if ( $args->{-skip_configure_SQL} == 1 ) {
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
    if ( test_can_write_config_dot_pm() == 1 ) {
        $log .= "* WARNING: Cannot write to, $Config_LOC!\n";
        $errors->{cant_edit_config_dot_pm} = 1;

        # $status = 0; ?
    }
    else {

        if ( edit_config_dot_pm($args) == 1 ) {
            $log .= "* Success!\n";
        }
        else {
            $log .= "* WARNING: Cannot edit $Config_LOC!\n";
            $errors->{cant_edit_dada_dot_config} = 1;
        }

    }
    $log .= "* Setting up Support Files Directory...\n";
    eval { setup_support_files_dir($args); };
    if ($@) {
        $log .= "* WARNING: Couldn't set up support files directory! $@\n";
        $errors->{cant_set_up_support_files_directory} = 1;
        $status = 0;

    }
    else {
        $log .= "* Success!\n";
    }

    $log .= "* Installing plugins/extensions...\n";
    eval { edit_config_file_for_plugins($args); };
    if ($@) {
        $log .=
          "* WARNING: Couldn't complete installing plugins/extensions! $@\n";
        $errors->{cant_install_plugins_extensions} = 1;
    }
    else {
        $log .= "* Success!\n";
    }

    if ( $args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' )
    {
        $log .= "* Skipping WYSIWYG setup...\n";
    }
    else {
        $log .= "* Installing WYSIWYG Editors...\n";
        eval { install_wysiwyg_editors($args); };
        if ($@) {
            $log .=
              "* WARNING: Couldn't complete installing WYSIWYG editors! $@\n";
            $errors->{cant_install_wysiwyg_editors} = 1;
        }
        else {
            $log .= "* Success!\n";
        }
    }


    $log .= "* Checking for needed CPAN modules to install...\n";
    eval { install_missing_CPAN_modules(); };
    if ($@) {
        $log .=
          "* Problems installing missing CPAN modules - skipping: $@\n";
        # $errors->{cant_install_plugins_extensions} = 1;
    }
    else {
        $log .= "* Done!\n";
    }




    $log .= "* Removing old Screen Cache...\n";
    eval { remove_old_screen_cache($args); };
    if ($@) {
        $log .=
"* WARNING: Couldn't remove old screen cache - you may have to do this manually: $@\n";
    }
    else {
        $log .= "* Success!\n";
    }

    # That's it.
    $log .= "* Installation and Configuration Complete!\n";
    return ( $log, $status, $errors );
}



sub remove_old_screen_cache { 
	my ($args) = @_; 
	my $screen_cache_dir = $args->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/_screen_cache'; 

	if(-d  $screen_cache_dir){ 
		    my $f;
		    opendir( CACHE, make_safer($screen_cache_dir))
				or croak "Can't open '" . $screen_cache_dir . "' to read because: $!";
		    while ( defined( $f = readdir CACHE ) ) {
        		#don't read '.' or '..'
		        next if $f =~ /^\.\.?$/;
		        $f =~ s(^.*/)();
		        my $n = unlink( make_safer( $screen_cache_dir . '/' . $f ) );
		        carp make_safer( $screen_cache_dir . '/' . $f ) . ' didn\'t go quietly'
		          if $n == 0;
		    }
		    closedir(CACHE);
			return 1; 
	}
	else { 
		return 1; 
	}

}


sub edit_config_dot_pm {

    my ($args) = @_;
	
    my $search  = qr/\$PROGRAM_CONFIG_FILE_DIR \= \'(.*?)\'\;/;
    my $search2 = qr/\$PROGRAM_ERROR_LOG \= (.*?)\;/;

    my $replace_with =
        q{$PROGRAM_CONFIG_FILE_DIR = '}
      . $args->{-install_dada_files_loc} . '/'
      . $Dada_Files_Dir_Name
      . q{/.configs';};

    my $replace_with2 =
        q{$PROGRAM_ERROR_LOG = '}
      . $args->{-install_dada_files_loc} . '/'
      . $Dada_Files_Dir_Name
      . q{/.logs/errors.txt';};
    $Config_LOC = make_safer($Config_LOC);

    my $config = slurp($Config_LOC);

	# "auto" usually does the job, 
    if ( $args->{-dada_files_dir_setup} ne 'auto' ) {
        $config =~ s/$search/$replace_with/;
    }

    # (what about the error log? )
    $config =~ s/$search2/$replace_with2/;

    # Why 0777?
    installer_chmod( 0777, make_safer('../DADA') );
    installer_rm($Config_LOC);

    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      $Config_LOC
      or croak $!;
    print $config_fh $config or croak $!;
    close $config_fh or croak $!;

    installer_chmod( $DADA::Config::FILE_CHMOD, $Config_LOC );
    installer_chmod( $DADA::Config::DIR_CHMOD,  make_safer('../DADA') );
    return 1;

}

sub backup_config_dot_pm {
	
	# Why 0777? 	
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

    installer_chmod( $DADA::Config::DIR_CHMOD, $backup_loc );
    installer_chmod( $DADA::Config::DIR_CHMOD, '../DADA' );
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
        croak "'" . $loc . '/.configs' . "' does not exist! Stopping!";
    }
	
    require DADA::Security::Password;
	my $pass; 
	if($q->param('dada_pass_use_orig') == 1){ 
		$pass = $q->param('original_dada_root_pass'); 
		if($q->param('original_dada_root_pass_is_encrypted') == 0){ 
			$pass = DADA::Security::Password::encrypt_passwd( $pass );
		}
	}
	else { 
		$pass = DADA::Security::Password::encrypt_passwd( $args->{-dada_root_pass} );
	}

	# Cripes, why wouldn't we pass a program url? 
	if(!exists($args->{-program_url})){ 
	    my $prog_url = $DADA::Config::PROGRAM_URL;
	    $prog_url =~ s{installer\/install\.cgi}{mail\.cgi};
		$args->{-program_url} = $prog_url;
	}


	my $SQL_params = {};
    if ( $args->{-backend} ne 'default' && $args->{-backend} ne '' ) {
		$SQL_params->{configure_SQL} = 1; 
		$SQL_params->{backend}       = $args->{-backend};
        $SQL_params->{sql_server}    = $args->{-sql_server};
        $SQL_params->{sql_database}  = clean_up_var($args->{-sql_database});
        $SQL_params->{sql_port}      = clean_up_var($args->{-sql_port});
        $SQL_params->{sql_username}  = clean_up_var($args->{-sql_username});
        $SQL_params->{sql_password}  = clean_up_var($args->{-sql_password});
    }

	if($args->{-backend} eq 'SQLite'){ 
		$args->{-sql_server} = ''; 
        $args->{-sql_database} = 'dadamail';  
        $args->{-sql_port} = ''; 
        $args->{-sql_username} = ''; 
        $args->{-sql_password} = ''; 
	}
	
	my $profiles_params = {}; 
	if($q->param('configure_profiles') == 1){ 
		$profiles_params->{configure_profiles} = 1; 
		for(qw(
			enabled
			profile_email
			enable_captcha	
			enable_magic_subscription_forms			
			help                      			
			login                     			
			register                  			
			password_reset            			
			profile_fields            			
			mailing_list_subscriptions			
			protected_directories     			
			update_email_address      			
			change_password           			
			delete_profile            					
			)){ 
				if($_ ne 'profile_email'){ 
					$profiles_params->{'profiles_' . $_} = $q->param('profiles_' . $_) || 0;
				}
				else { 
					$profiles_params->{'profiles_' . $_} = $q->param('profiles_' . $_) || '';					
				}
				$profiles_params->{'profiles_' . $_} = clean_up_var($profiles_params->{'profiles_' . $_});  
		}
	}
	
	my $template_options_params = {};
	if($q->param('configure_templates') == 1 &&  $q->param('configure_user_template') == 1){ 
		$template_options_params->{template_options_USER_TEMPLATE} = clean_up_var($q->param('template_options_USER_TEMPLATE'));	
		$template_options_params->{configure_templates} = 1;
	}

	my $cache_options_params = {};
	if($q->param('configure_cache') == 1){ 
		$cache_options_params->{configure_cache} = 1;
		if(clean_up_var($q->param('cache_options_SCREEN_CACHE')) == 1){ 
			$cache_options_params->{cache_options_SCREEN_CACHE} = 1;
		}
		else { 
			$cache_options_params->{cache_options_SCREEN_CACHE} = 2;
		}
		if(clean_up_var($q->param('cache_options_DATA_CACHE')) == 1){ 
			$cache_options_params->{cache_options_DATA_CACHE} = 1;
		}
		else { 
			$cache_options_params->{cache_options_DATA_CACHE} = 2;
		}
	}
	
	
	
	
	my $debugging_options_params = {};
	if($q->param('configure_debugging') == 1){ 
		$debugging_options_params->{configure_debugging} = 1;
		my @debug_options = qw(
			DADA_App_DBIHandle
			DADA_App_Subscriptions
			DADA_Logging_Clickthrough
			DADA_Profile
			DADA_Profile_Fields
			DADA_Profile_Session
			DADA_Mail_MailOut
			DADA_Mail_Send
			DADA_App_BounceHandler_ScoreKeeper
			DADA_MailingList_baseSQL

			DBI
			HTML_TEMPLATE
			MIME_LITE_HTML
			MAIL_POP3CLIENT
			NET_SMTP

		);

		for my $debug_option(@debug_options) { 
			$debugging_options_params->{'debugging_options_' . $debug_option} = clean_up_var($q->param('debugging_options_' . $debug_option)) || 0; 
		}
		
	}
	
	my $security_params = {};
	if($q->param('configure_security') == 1){ 
		$security_params->{configure_security} = 1; 
		if($q->param('security_no_show_admin_link') == 1){ 
			$security_params->{security_SHOW_ADMIN_LINK} = 2; 
		}
		else { 
			$security_params->{security_SHOW_ADMIN_LINK} = 0; 			
		}
		$security_params->{security_DISABLE_OUTSIDE_LOGINS} = clean_up_var($q->param('security_DISABLE_OUTSIDE_LOGINS')); 
		if(length($q->param('security_ADMIN_FLAVOR_NAME')) > 0) { 
			$security_params->{security_ADMIN_FLAVOR_NAME} = clean_up_var($q->param('security_ADMIN_FLAVOR_NAME')); 
		}
		if(length($q->param('security_SIGN_IN_FLAVOR_NAME')) > 0) { 
			$security_params->{security_SIGN_IN_FLAVOR_NAME} = clean_up_var($q->param('security_SIGN_IN_FLAVOR_NAME')); 
		}
	}
	
	
	my $captcha_params = {};
	if($q->param('configure_captcha') == 1){ 
		$captcha_params->{configure_captcha} = 1; 
		$captcha_params->{captcha_type}  = clean_up_var($q->param('captcha_type')); 
		$captcha_params->{captcha_reCAPTCHA_remote_addr} = clean_up_var($q->param('captcha_reCAPTCHA_remote_addr')); 
		$captcha_params->{captcha_reCAPTCHA_public_key} = clean_up_var($q->param('captcha_reCAPTCHA_public_key')); 
		$captcha_params->{captcha_reCAPTCHA_private_key} = clean_up_var($q->param('captcha_reCAPTCHA_private_key')); 
		$captcha_params->{captcha_reCAPTCHA_Mailhide_public_key} = clean_up_var($q->param('captcha_reCAPTCHA_Mailhide_public_key')); 
		$captcha_params->{captcha_reCAPTCHA_Mailhide_private_key} = clean_up_var($q->param('captcha_reCAPTCHA_Mailhide_private_key')); 
	}
	
	
	
	my $mass_mailing_params = {}; 
	if($q->param('configure_mass_mailing') == 1){ 
		$mass_mailing_params->{configure_mass_mailing} = 1; 
		$mass_mailing_params->{mass_mailing_MAILOUT_AT_ONCE_LIMIT} = clean_up_var($q->param('mass_mailing_MAILOUT_AT_ONCE_LIMIT')); 
		$mass_mailing_params->{mass_mailing_MULTIPLE_LIST_SENDING} = clean_up_var($q->param('mass_mailing_MULTIPLE_LIST_SENDING')); 
		$mass_mailing_params->{mass_mailing_MAILOUT_STALE_AFTER}   = clean_up_var($q->param('mass_mailing_MAILOUT_STALE_AFTER')); 
	}
	
	my $amazon_ses_params = {}; 
	if($q->param('configure_amazon_ses') == 1){ 
		$amazon_ses_params->{configure_amazon_ses} = 1; 
		$amazon_ses_params->{AWSAccessKeyId} = $q->param('amazon_ses_AWSAccessKeyId');
		$amazon_ses_params->{AWSSecretKey} = $q->param('amazon_ses_AWSSecretKey'); 
	}
	
	
    my $outside_config_file = DADA::Template::Widgets::screen(
        {
            -screen => 'example_dada_config.tmpl',
            -vars   => {

                PROGRAM_URL            => $args->{-program_url},
                ROOT_PASSWORD          => $pass,
                ROOT_PASS_IS_ENCRYPTED => 1,
                dada_files_dir         => $loc,
				support_files_dir_path => $q->param('support_files_dir_path') . '/' . $Support_Files_Dir_Name, 
				support_files_dir_url  => $q->param('support_files_dir_url') . '/' . $Support_Files_Dir_Name, 
				Big_Pile_Of_Errors     => $Big_Pile_Of_Errors, 
				Trace                  => $Trace, 
				%{$SQL_params},
				%{$cache_options_params},
				%{$debugging_options_params}, 
			    %{$template_options_params},
				%{$profiles_params},
				%{$security_params},
				%{$captcha_params}, 
				%{$mass_mailing_params}, 
				%{$amazon_ses_params},
            }
        }
    );	

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

		if($q->param('dada_pass_use_orig') == 1){ 
			# Hopefully, original_dada_root_pass has been set. 
		}
		else { 
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
		}


        if ( $q->param('backend') eq 'default' || $q->param('backend') eq '' ) {
            $errors->{sql_connection} = 0;
        }
        else {
			my ($sql_test, $sql_test_details) = test_sql_connection(
                $q->param('backend'),      
				$q->param('sql_server'),
                'auto',                    
				$q->param('sql_database'),
                $q->param('sql_username'), 
				$q->param('sql_password')
			); 
            if ($sql_test == 0)
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
			
			if ( test_can_create_dada_files_dir($install_dada_files_dir_at) == 0 ) {
	            $errors->{create_dada_files_dir} = 1;
	        }
	        else {
	            $errors->{create_dada_files_dir} = 0;
	        }			
		}
		
		
		if(test_can_create_dada_mail_support_files_dir($q->param('support_files_dir_path')) == 0){ 
            $errors->{create_dada_mail_support_files_dir} = 1;
        }
        else {
            $errors->{create_dada_mail_support_files_dir} = 0;	        
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
					my $installer_successful = installer_chmod($DADA::Config::DIR_CHMOD, make_safer($plugins_extensions->{$plugins_data}->{loc}));
				}
			}
			else { 
				if($q->param('install_' . $plugins_data) == 1){ 
					my $orig_code = $plugins_extensions->{$plugins_data}->{code}; 
					my $uncommented_code = uncomment_admin_menu_entry($orig_code);
			 		$orig_code = quotemeta($orig_code); 
					$config_file =~ s/$orig_code/$uncommented_code/;

					# Fancy stuff for Bridge, 
					if($plugins_data eq 'bridge'){ 
						# uncomment the plugins config, 
						$config_file =~ s/$plugins_config_begin_cut//; 
						$config_file =~ s/$plugins_config_end_cut//; 
					 	# then, we have to fill in all the stuff in.
					 	# Not a fav. tecnique!

						my $plugins_config_bridge_orig = quotemeta(
q|	Bridge => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Allow_Manual_Run                    => undef,
		Manual_Run_Passcode                 => undef,
		MessagesAtOnce                      => undef,
		Soft_Max_Size_Of_Any_Message        => undef,
		Max_Size_Of_Any_Message             => undef,
		Allow_Open_Discussion_List          => undef,
		Room_For_One_More_Check             => undef,
		Enable_POP3_File_Locking            => undef,
		Check_List_Owner_Return_Path_Header => undef,
		Check_Multiple_Return_Path_Headers  => undef,
|);
						my $bridge_MessagesAtOnce               = clean_up_var($q->param('bridge_MessagesAtOnce')); 
						my $bridge_Soft_Max_Size_Of_Any_Message = clean_up_var($q->param('bridge_Soft_Max_Size_Of_Any_Message')); 
						my $bridge_Max_Size_Of_Any_Message = clean_up_var($q->param('bridge_Max_Size_Of_Any_Message')); 


						my $plugins_config_bridge_replace_with = 
"	Bridge => {

		Plugin_Name                         => undef,
		Plugin_URL                          => undef,
		Allow_Manual_Run                    => undef,
		Manual_Run_Passcode                 => undef,
		MessagesAtOnce                      => '$bridge_MessagesAtOnce',
		Soft_Max_Size_Of_Any_Message        => '$bridge_Soft_Max_Size_Of_Any_Message',
		Max_Size_Of_Any_Message             => '$bridge_Max_Size_Of_Any_Message',
		Allow_Open_Discussion_List          => undef,
		Room_For_One_More_Check             => undef,
		Enable_POP3_File_Locking            => undef,
		Check_List_Owner_Return_Path_Header => undef,
		Check_Multiple_Return_Path_Headers  => undef,
";
						$config_file =~ s/$plugins_config_bridge_orig/$plugins_config_bridge_replace_with/; 
						 
					}

					# Fancy stuff for Bounce Handler, 
					if($plugins_data eq 'bounce_handler'){ 
						# uncomment the plugins config, 
						$config_file =~ s/$plugins_config_begin_cut//; 
						$config_file =~ s/$plugins_config_end_cut//; 
					 	# then, we have to fill in all the stuff in.
					 	# Not a fav. tecnique!
					my $plugins_config_bounce_handler_orig = quotemeta(
q|	Bounce_Handler => {
		Server                      => undef,
		Username                    => undef,
		Password                    => undef,
		Port                        => undef,
		USESSL                      => undef,
		AUTH_MODE                   => undef,
		Plugin_Name                 => undef,
		Plugin_URL                  => undef,
		Allow_Manual_Run            => undef,
		Manual_Run_Passcode         => undef,
		Enable_POP3_File_Locking    => undef, 
		Log                         => undef,
		MessagesAtOnce              => undef,
		Max_Size_Of_Any_Message     => undef,
		Rules                       => undef,|
					);
					my $bounce_handler_address        = clean_up_var($q->param('bounce_handler_address')); 
					my $bounce_handler_server         = clean_up_var($q->param('bounce_handler_server'));
					my $bounce_handler_username       = clean_up_var($q->param('bounce_handler_username')); 
					my $bounce_handler_password       = clean_up_var($q->param('bounce_handler_password')); 
					my $bounce_handler_USESSL         = clean_up_var($q->param('bounce_handler_USESSL')); 
					my $bounce_handler_AUTH_MODE      = clean_up_var($q->param('bounce_handler_AUTH_MODE')); 
					my $bounce_handler_MessagesAtOnce = clean_up_var($q->param('bounce_handler_MessagesAtOnce')); 


					my $plugins_config_bounce_handler_replace_with = 
"	Bounce_Handler => {
		Server                      => '$bounce_handler_server',
		Username                    => '$bounce_handler_username',
		Password                    => '$bounce_handler_password',
		Port                        => undef,
		USESSL                      => '$bounce_handler_USESSL',
		AUTH_MODE                   => '$bounce_handler_AUTH_MODE',
		Plugin_Name                 => undef,
		Plugin_URL                  => undef,
		Allow_Manual_Run            => undef,
		Manual_Run_Passcode         => undef,
		Enable_POP3_File_Locking    => undef, 
		Log                         => undef,
		MessagesAtOnce              => '$bounce_handler_MessagesAtOnce',
		Max_Size_Of_Any_Message     => undef,
		Rules                       => undef,";

					$config_file =~ s/$plugins_config_bounce_handler_orig/$plugins_config_bounce_handler_replace_with/; 
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
	admin_email                  => '$bounce_handler_address',
);|; 
						$config_file =~ s/$plugins_config_list_settings_default_orig/$plugins_config_list_settings_default_replace_with/;
					}
					my $installer_successful = installer_chmod($DADA::Config::DIR_CHMOD, make_safer($plugins_extensions->{$plugins_data}->{loc}));
				}
			}
		}
	}
	
	if($args->{-if_dada_files_already_exists} eq 'skip_configure_dada_files') { 

	}
	else { 
		# write it back? 
		# Why 0777? 
		installer_chmod(0777, $dot_configs_file_loc); 
		open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($dot_configs_file_loc) or croak $!;
		print $config_fh $config_file or croak $!;
		close $config_fh or croak $!;
		installer_chmod($DADA::Config::FILE_CHMOD, $dot_configs_file_loc);	
	}
	return 1; 
	

}


sub setup_support_files_dir { 
	my ($args) = @_;
		
	my $support_files_dir_path = $q->param('support_files_dir_path'); 
	if(! -d $support_files_dir_path) { 
		croak "Can't install set up Support Files Directory: '$support_files_dir_path' does not exist!"; 
	}
	if(! -d $support_files_dir_path . '/' . $Support_Files_Dir_Name){ 
		installer_mkdir(make_safer($support_files_dir_path . '/' . $Support_Files_Dir_Name), $DADA::Config::DIR_CHMOD);
	}
	
	my $install_path = $q->param('support_files_dir_path') . '/' . $Support_Files_Dir_Name; 
	
	my $source_package = make_safer('../static'); 
	my $target_loc     = make_safer($install_path . '/static');
	if(-d $target_loc){
		backup_dir($target_loc);	
	}
	installer_dircopy($source_package, $target_loc); 
	unlink(make_safer($target_loc . '/README.txt')); 
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
	installer_chmod($DADA::Config::FILE_CHMOD, $dot_configs_file_loc);	
	
	return 1; 
}



sub install_missing_CPAN_modules { 
	my $has_JSON = 1;
	eval { 
		require JSON; 
	};
	if($@) { 
		$has_JSON = 0; 
	}
	eval { 
		require JSON::PP; 
	};
	if($@) { 
		$has_JSON = 0; 
	}
	
	if($has_JSON == 0) {
		my $JSON_pm  = make_safer('../DADA/perllib/JSON.pm-remove_to_install');  
		my $JSON_dir = make_safer('../DADA/perllib/JSON-remove_to_install'); 
		
		if(-d $JSON_dir && -e $JSON_pm){ 
			my $JSON_dir_new = $JSON_dir; 
			   $JSON_dir_new =~ s/\-remove_to_install$//; 
			   $JSON_dir_new = make_safer($JSON_dir_new); 
			
			my $JSON_pm_new = $JSON_pm; 
			   $JSON_pm_new =~ s/\-remove_to_install$//; 
			   $JSON_pm_new = make_safer($JSON_pm_new); 

			installer_mv($JSON_dir, $JSON_dir_new); 
			installer_mv($JSON_pm,  $JSON_pm_new);

			if(-d $JSON_dir_new && -e $JSON_pm_new){ 
				return 1;
			}
			else { 
				return ; 
			}
		}
	}
	else { 
		return 1; 
	}
		
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
		# Why 0777? 
		installer_chmod(0777, $fckeditor_config_loc); 
		open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $fckeditor_config_loc or croak $!;
		print $config_fh $fckeditor_config_js or croak $!;
		close $config_fh or croak $!;
		installer_chmod($DADA::Config::FILE_CHMOD, $fckeditor_config_loc);
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
		installer_chmod($DADA::Config::FILE_CHMOD, $ckeditor_config_loc);
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
		installer_chmod($DADA::Config::FILE_CHMOD, $tiny_mce_config_loc);
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
	installer_chmod($DADA::Config::FILE_CHMOD, $kcfinder_config_loc);
	undef $config_fh;
	
}


sub uncomment_admin_menu_entry { 

	my $str = shift; 
	$str =~ s/\#//g; 
	return $str; 	
}





sub self_url { 
	my $self_url = $q->url; 
	if($self_url eq 'http://' . $ENV{HTTP_HOST}){ 
		$self_url = $ENV{SCRIPT_URI};
	}
	return $self_url; 	
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

sub hack_in_js {
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

    my $dada_files_parent_dir = shift;
	# blank?!
	if($dada_files_parent_dir eq ''){ 
		return 0; 
	}
    my $dada_files_dir =
      make_safer( $dada_files_parent_dir . '/' . $Dada_Files_Dir_Name );

    if ( installer_mkdir( $dada_files_dir, $DADA::Config::DIR_CHMOD ) ) {
        if ( -e $dada_files_dir ) {
            installer_rmdir($dada_files_dir);
            return 1;
        }
        else {
            return 0;

        }
    }
    else {
        return 0;
    }

}

sub test_can_create_dada_mail_support_files_dir {

    my $support_files_parent_dir = shift;
	# blank?!
	if($support_files_parent_dir eq ''){ 
		return 0; 
	}
    my $support_files_dir =
      make_safer( $support_files_parent_dir . '/' . $Support_Files_Dir_Name );
	my $already_exists = 0; 
	

	# That's.. OK, it can exist. 
	if(-e $support_files_dir && -d _) { 
		# Guess, we'll just skip that one. 
		$already_exists = 1; 
	}
	else { 
	  # Let's try making it, 
	  if ( installer_mkdir( $support_files_dir, $DADA::Config::DIR_CHMOD ) ) {
			# And let's see if it's around, 
	        if ( -e $support_files_dir && -d _) {
				# And, let's see if we can't write into it. 

				my $time = time;
				require DADA::Security::Password; 
				my $ran_str = DADA::Security::Password::generate_rand_string(); 
				my $ran_file_name = make_safer($support_files_dir . "/test_file.$ran_str.$time.txt"); 
				my $file_worked = 1; 
				
				open(TEST_FILE, ">$ran_file_name") or $file_worked = 0; 
				print TEST_FILE "test" or $file_worked             = 0; 
				close(TEST_FILE) or $file_worked                   = 0; 
				
				if($file_worked == 1){
					
					# DEV: And then, perhaps try to get it via HTTP
					#
					installer_rm($ran_file_name); 
					if($already_exists != 1) { 
		            	installer_rmdir($support_files_dir);
		            }
					
					# Yes! Yes, it works. 
					return 1;
				}
	        }
	        else {
	            return 0;

	        }
	    }
	    else {
	        return 0;
	    }	
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
sub test_can_use_CAPTCHA_reCAPTCHA {
    eval { require Captcha::reCAPTCHA; };
    if ($@) {
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
        return 0;
    }
    else {
        return 1;
    }
}
sub test_can_use_CAPTCHA_reCAPTCHA_Mailhide {
    eval { require Captcha::reCAPTCHA::Mailhide; };
    if ($@) {
		carp $@; 
		$Big_Pile_Of_Errors .= $@; 
        return 0;
    }
    else {
        return 1;
    }
}
sub test_can_use_GD {
    eval { require GD; };
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



sub cgi_test_sql_connection { 
	    my $dbtype   = strip(xss_filter($q->param('backend')));
	    my $dbserver = strip(xss_filter($q->param('sql_server')));
	    my $port     = strip(xss_filter($q->param('sql_port')));
	    my $database = strip(xss_filter($q->param('sql_database')));
	    my $user     = strip(xss_filter($q->param('sql_username')));
	    my $pass     = strip(xss_filter($q->param('sql_password')));
	
		my ($status, $details) = test_sql_connection(
			$dbtype,
			$dbserver,
			$port,    
			$database,
			$user,    
			$pass,    
		);
	print $q->header(); 
	#use Data::Dumper; 
	#print Dumper([$status, $details]);
	if($status == 1){ 
		print '<p>Connection Successful!</p>';
	}
	else { 
		print '<p>Connection is NOT Successful. Details:</p>'; 
		print '<code>' . $details . '</code>'; 
	}
		
}
sub cgi_test_pop3_connection { 
	
	my $bounce_handler_server         = $q->param('bounce_handler_server'); 
	my $bounce_handler_username       = $q->param('bounce_handler_username'); 
	my $bounce_handler_password       = $q->param('bounce_handler_password'); 
	my $bounce_handler_USESSL         = $q->param('bounce_handler_USESSL') || 0; 
	my $bounce_handler_AUTH_MODE      = $q->param('bounce_handler_AUTH_MODE') || 'BEST'; 
#	my $bounce_handler_MessagesAtOnce = $q->param('bounce_handler_MessagesAtOnce') || 100; 
	
	$bounce_handler_server   = make_safer($bounce_handler_server); 
	$bounce_handler_username = make_safer($bounce_handler_username); 	
	$bounce_handler_password = make_safer($bounce_handler_password);
	
	my ( $pop3_obj, $pop3_status, $pop3_log ) = test_pop3_connection({ 
        Server    => $bounce_handler_server, 
        Username  => $bounce_handler_username,
        Password  => $bounce_handler_password,
		USESSL    => $bounce_handler_USESSL,
		AUTH_MODE => $bounce_handler_AUTH_MODE,
	}); 
	#use Data::Dumper; 
	#print $q->header('text/plain');
	#print Dumper([$pop3_status, $pop3_log]);  
    print $q->header(); 
	if($pop3_status == 1){ 
		print '<p>Connection is Successful!</p>'; 
	}
	else { 
		print '<p>Connection is NOT Successful.</p>'; 
	}
	print '<pre>'  . $pop3_log . '</pre>'; 
}

sub cgi_test_user_template { 
	my $template_options_USER_TEMPLATE = $q->param('template_options_USER_TEMPLATE'); 
	my $can_get_content = 0; 
	my $can_use_lwp_simple = DADA::App::Guts::can_use_LWP_Simple; 
	my $isa_url = isa_url($template_options_USER_TEMPLATE); 
	if($isa_url) { 
		if(grab_url($template_options_USER_TEMPLATE)) { 
			$can_get_content = 1; 
		} 
	}
	else { 
		if(-e $template_options_USER_TEMPLATE){ 
			$can_get_content = 1; 
		}
	}

	
	print $q->header(); 
	require DADA::Template::Widgets;
	e_print(DADA::Template::Widgets::screen(
		{
			-screen => 'test_user_template.tmpl',
			-expr   => 1, 
			-vars   => {
				template_options_USER_TEMPLATE => $template_options_USER_TEMPLATE, 
				can_use_lwp_simple             => $can_use_lwp_simple, 
				isa_url                        => $isa_url, 
				can_get_content                => $can_get_content,
			}
		}
	));
	
	
}

sub cgi_test_amazon_ses_configuration { 
	
	my $amazon_ses_AWSAccessKeyId = $q->param('amazon_ses_AWSAccessKeyId'); 
	my $amazon_ses_AWSSecretKey   = $q->param('amazon_ses_AWSSecretKey'); 
	my ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ); 
	
	eval { 
		require DADA::App::AmazonSES; 
		my $ses = DADA::App::AmazonSES->new; 
		($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $ses->get_stats(
			{ 
				AWSAccessKeyId => $amazon_ses_AWSAccessKeyId, 
				AWSSecretKey    => $amazon_ses_AWSSecretKey, 
			}
		); 
	};
	print $q->header(); 
	require DADA::Template::Widgets;
	e_print(DADA::Template::Widgets::screen(
		{
			-screen => 'amazon_ses_get_stats_widget.tmpl',
			-expr   => 1, 
			-vars   => {
				has_ses_options            => 1, 
				status                     => $status,
				MaxSendRate                => $MaxSendRate,
				Max24HourSend              => $Max24HourSend,
				SentLast24Hours            => $SentLast24Hours,
			}
		}
	));
}


sub cgi_test_default_CAPTCHA { 
	
	my $captcha = ''; 
	my $errors  = undef; 
	my $captcha = undef; 

	eval { 
		
		$DADA::Config::TMP = './';
		
	    require DADA::Security::AuthenCAPTCHA::Default;
	    my $c = DADA::Security::AuthenCAPTCHA::Default->new;
	
	    require DADA::Security::Password; 
	    my $secret_phrase = DADA::Security::Password::generate_rand_string(
			$DADA::Config::GD_SECURITYIMAGE_PARAMS->{rand_string_from}, 
			$DADA::Config::GD_SECURITYIMAGE_PARAMS->{rand_string_size}
		);
	    my $auth_string   = $c->_create_CAPTCHA_auth_string($secret_phrase); 
	
	    $captcha = $c->inline_img_data($secret_phrase, $auth_string);
	
	};
	if($@){ 
		$errors = $@; 
	}	
	
	print $q->header(); 
	require DADA::Template::Widgets;
	e_print(DADA::Template::Widgets::screen(
		{
			-screen => 'captcha_default_test_widget.tmpl',
			-expr   => 1, 
			-vars   => {
				errors  => $errors, 
				captcha => $captcha, 
			}
		}
	));
	
}
sub cgi_test_CAPTCHA_reCAPTCHA { 
	my $captcha_reCAPTCHA_public_key = $q->param('captcha_reCAPTCHA_public_key'); 
	
	my $captcha = ''; 
	my $errors  = undef; 
	eval { 
	    require Captcha::reCAPTCHA;
	    my $c = Captcha::reCAPTCHA->new;
	     $captcha = $c->get_html( $captcha_reCAPTCHA_public_key );
	};
	if($@){ 
		$errors = $@; 
	}
		
	print $q->header(); 
	require DADA::Template::Widgets;
	e_print(DADA::Template::Widgets::screen(
		{
			-screen => 'captcha_recaptcha_test_widget.tmpl',
			-expr   => 1, 
			-vars   => {
				errors   => $errors, 
				Self_URL => $Self_URL, 
				captcha  => $captcha, 
				captcha_reCAPTCHA_public_key => $captcha_reCAPTCHA_public_key, 
			}
		}
	));
}

             
sub cgi_test_captcha_reCAPTCHA_Mailhide {
	 
	my $captcha_reCAPTCHA_Mailhide_public_key  = $q->param('captcha_reCAPTCHA_Mailhide_public_key'); 
	my $captcha_reCAPTCHA_Mailhide_private_key = $q->param('captcha_reCAPTCHA_Mailhide_private_key'); 
	
	my $captcha = ''; 
	my $errors  = undef; 
	eval { 
	    require Captcha::reCAPTCHA::Mailhide;
	    my $c = Captcha::reCAPTCHA::Mailhide->new;
	     $captcha = $c->mailhide_html($captcha_reCAPTCHA_Mailhide_public_key,  $captcha_reCAPTCHA_Mailhide_private_key, 'test@example.com' );
	};
	if($@){ 
		$errors = $@; 
	}
		
	print $q->header(); 
	require DADA::Template::Widgets;
	e_print(DADA::Template::Widgets::screen(
		{
			-screen => 'captcha_recaptcha_mailhide_test_widget.tmpl',
			-expr   => 1, 
			-vars   => {
				errors   => $errors, 
				captcha  => $captcha, 
			}
		}
	));
}



sub test_pop3_connection { 
	
		my ($args) = @_;
	    require DADA::App::POP3Tools;
	    my ( $pop3_obj, $pop3_status, $pop3_log ) =
	      DADA::App::POP3Tools::mail_pop3client_login(
	        {
	            server    => $args->{Server},
	            username  => $args->{Username},
	            password  => $args->{Password},
#	            port      => $args->{Port},
	            USESSL    => $args->{USESSL},
	            AUTH_MODE => $args->{AUTH_MODE},
	        }
	      );
	    if ( defined($pop3_obj) ) {
	        $pop3_obj->Close();
	    }

	   return ( $pop3_obj, $pop3_status, $pop3_log );
	
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
		return (0, $@);
    }
    else {
        return (1, '');
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
sub screen { 
	my $screen = $q->param('screen'); 
	
	if($screen eq '/static/css/dada_mail.css'){ 
		print $q->header('text/css');
		my $t = DADA::Template::Widgets::screen(
	        {
	            -screen => 'installer-dada_mail.css',
	            -vars => {

	            },
	        }
	    );	
		my $hack_css_url = quotemeta(q{url('../images/header_bg.gif')}); 
		my $r            = q{url('} . $Self_URL . q{?f=screen&screen=/images/installer-header_bg.gif')}; 
		   $t =~ s/$hack_css_url/$r/g;
		print $t; 
	}
	elsif($screen eq '/static/images/dada_mail_logo.png'){ 
		print $q->header('image/png');
		print DADA::Template::Widgets::_raw_screen(
            {
                -screen   => 'installer-dada_mail_logo.png',
                -encoding => 0,
            }
        ); 		
	}
	elsif($screen eq '/images/installer-header_bg.gif'){ 
		print $q->header('image/gif');
		print DADA::Template::Widgets::_raw_screen(
            {
                -screen   => 'installer-header_bg.gif',
                -encoding => 0,
            }
        ); 		
		
		
	}
	elsif(
		$screen eq 'installer-dada_mail.js' 
	 || $screen eq 'installer-dada_mail.installer.js' 
	 || $screen =~ m/installer\-jquery/ 
	 || $screen =~ m/installer\-jquery\-ui/
	){ 
		print $q->header('text/javascript');
		e_print(DADA::Template::Widgets::screen(
	        {
	            -screen => make_safer($screen),
	        }
	    ));	
	}
	elsif($screen =~ /^\/static/) {
		print $q->header('text/plain');
	}
	elsif($screen eq 'upgrade_to_pro_dada.jpg'){ 
		print $q->header('image/jpg');
		print DADA::Template::Widgets::_raw_screen(
            {
                -screen   => 'upgrade_to_pro_dada.jpg',
                -encoding => 0,
            }
        );
		 
	}
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

package BootstrapConfig;
no strict; 

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1;}
use DADA::Config; 

my $PROGRAM_NAME; 
my $VER; 
my $PROGRAM_CONFIG_FILE_DIR = 'auto'; 
my $OS = $^O;
my $CONFIG_FILE; 

config_import(); 

sub config_import { 

	$CONFIG_FILE = shift || guess_config_file(); 
	
	# Keep this as, 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'
	# What we're doing is, seeing if you've actually changed the variable from
	# it's default, and if not, we take a best guess.	
	
	
	if(-e $CONFIG_FILE && -f $CONFIG_FILE && -s $CONFIG_FILE){ 
		open(CONFIG, '<:encoding(UTF-8)',  $CONFIG_FILE) 
			or warn "could not open outside config file, '$CONFIG_FILE' because: $!"; 
		my $conf;
		   $conf = do{ local $/; <CONFIG> }; 

		# shooting again, 
		$conf =~ m/(.*)/ms;
		$conf = $1;	
		eval  $conf;
		if ($@) { 
			# Well, that's gonna suck. 
			#die "$PROGRAM_NAME $VER ERROR - Outside config file '$CONFIG_FILE' contains errors:\n\n$@\n\n";
		}	

	}
}

sub guess_config_file { 
	my $CONFIG_FILE_DIR = undef; 
	
	# $PROGRAM_CONFIG_FILE_DIR
	
	
	if(defined($OS) !~ m/^Win|^MSWin/i){ 
		if($DADA::Config::PROGRAM_CONFIG_FILE_DIR ne 'auto' 
		&& -e $DADA::Config::PROGRAM_CONFIG_FILE_DIR
		&& -d $DADA::Config::PROGRAM_CONFIG_FILE_DIR
		) { 
			$CONFIG_FILE_DIR =  $DADA::Config::PROGRAM_CONFIG_FILE_DIR; 
		}
		else { 
							
			my $getpwuid_call; 
			my $good_getpwuid;
			eval { 
				$getpwuid_call = ( getpwuid $> )[7];
			};
			if(!$@){ 
				$good_getpwuid = $getpwuid_call;
			}
			if($PROGRAM_CONFIG_FILE_DIR eq 'auto'){
				$good_getpwuid =~ s/\/$//; 
				$CONFIG_FILE_DIR = $good_getpwuid . '/.dada_files/.configs';
			}
			else { 
				$CONFIG_FILE_DIR = $PROGRAM_CONFIG_FILE_DIR;
			}
		}
	}
	
	$CONFIG_FILE = $CONFIG_FILE_DIR.'/.dada_config';
	
	# yes, shooting yourself in the foot, RTM
	$CONFIG_FILE =~ /(.*)/; 
	$CONFIG_FILE = $1;
	
	return $CONFIG_FILE; 
}







1;