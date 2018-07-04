#!/usr/bin/perl 


BEGIN {
        open( STDERR, ">>./errors.txt" );
}





package DadaMailInstaller;
use base 'CGI::Application';

#use CGI::Application::Plugin::DebugScreen;

use Carp qw(carp croak);

BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1; }

#FindBin
use lib qw(
  ../../
  ../../DADA/perllib
);

use strict;

use Encode qw(encode decode);


BEGIN {
    if ( $] > 5.008 ) {
        require Errno;
        require Config;
    }
}

# These are script-wide variables
#
# $Self_URL may need not be set manually - but I'm hoping not.
# If the script doesn't post properly, go ahead and configure it manually
#
my $Self_URL;    #           = $self->self_url(); # this gunna work?!

# You'll normally not want to change this, but I leave it to you to decide
#
my $Dada_Files_Dir_Name = '.dada_files';

# It irritates me to use a weird, relative path - I may want to try to make this
# an abs. path via File::Spec (or, whatever)
#
my $Config_LOC             = '../DADA/Config.pm';
my $Support_Files_Dir_Name = 'dada_mail_support_files';
my $File_Upload_Dir        = 'file_uploads';
my $Server_TMP_dir          = $ENV{TMP} // '/tmp';

# Save the errors this creates in a variable
#
my $Big_Pile_Of_Errors = undef;

# Show these errors in the web browser?
#
my $Trace = 0;

# These are strings we look for in the dada_config.tmpl file which
# we need to remove.

my $admin_menu_begin_cut = quotemeta(
    q{# start cut for list control panel menu
=cut}
);
my $admin_menu_end_cut = quotemeta(
    q{=cut
# end cut for list control panel menu}
);

my $plugins_extensions = {
    change_root_password          => { installed => 0, loc => '../plugins/change_root_password' },
    screen_cache                  => { installed => 0, loc => '../plugins/screen_cache' },
    log_viewer                    => { installed => 0, loc => '../plugins/log_viewer' },
    tracker                       => { installed => 0, loc => '../plugins/tracker' },
    bridge                        => { installed => 0, loc => '../plugins/bridge' },
    bounce_handler                => { installed => 0, loc => '../plugins/bounce_handler' },
    password_protect_directories  => { installed => 0, loc => '../plugins/password_protect_directories' },
    change_list_shortname         => { installed => 0, loc => '../plugins/change_list_shortname' },
    global_config                 => { installed => 0, loc => '../plugins/global_config' },
    multiple_subscribe            => { installed => 0, loc => '../extensions/multiple_subscribe.cgi' },
    blog_index                    => { installed => 0, loc => '../extensions/blog_index.cgi' },
	usage_log_to_consent_activity => { installed => 0, loc => '../plugins/usage_log_to_consent_activity' },
};
$plugins_extensions->{change_root_password}->{code} = q{#					{
#					-Title      => 'Change the Program Root Password',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/change_root_password",
#					-Function   => 'change_root_password',
#					-Activated  => 0,
#					},};

$plugins_extensions->{screen_cache}->{code} = q{#					{
#					-Title      => 'Screen Cache',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/screen_cache",
#					-Function   => 'screen_cache',
#					-Activated  => 0,
#					},};

$plugins_extensions->{log_viewer}->{code} = q{#					{
#					-Title      => 'View Logs',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/log_viewer",
#					-Function   => 'log_viewer',
#					-Activated  => 1,
#					},};

$plugins_extensions->{tracker}->{code} = q{#					{
#					-Title      => 'Tracker',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/tracker",
#					-Function   => 'tracker',
#					-Activated  => 1,
#					},};

$plugins_extensions->{bridge}->{code} = q{#					{
#					-Title      => 'Bridge',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/bridge",
#					-Function   => 'bridge',
#					-Activated  => 1,
#					},};

$plugins_extensions->{bounce_handler}->{code} = q{#					{
#					-Title      => 'Bounce Handler',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/bounce_handler",
#					-Function   => 'bounce_handler',
#					-Activated  => 1,
#					},};

$plugins_extensions->{password_protect_directories}->{code} = q{#					{
#					-Title      => 'Password Protect Directories',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/password_protect_directories",
#					-Function   => 'password_protect_directories',
#					-Activated  => 1,
#					},};

$plugins_extensions->{change_list_shortname}->{code} = q{#					{
#					-Title      => 'Change Your List Short Name',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/change_list_shortname",
#					-Function   => 'change_list_shortname',
#					-Activated  => 0,
#					},};

$plugins_extensions->{global_config}->{code} = q{#					{
#					-Title      => 'Global Configuration',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/global_config",
#					-Function   => 'global_config',
#					-Activated  => 0,
#					},};

$plugins_extensions->{multiple_subscribe}->{code} = q{#					{
#					-Title      => 'Multiple Subscribe',
#					-Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
#					-Function   => 'multiple_subscribe',
#					-Activated  => 1,
#					},};

$plugins_extensions->{blog_index}->{code} = q{#					{
#					-Title      => 'Archive Blog Index',
#					-Title_URL  => $EXT_URL."/blog_index.cgi?mode=html&list=<!-- tmpl_var list_settings.list -->",
#					-Function   => 'blog_index',
#					-Activated  => 1,
#					},};

$plugins_extensions->{usage_log_to_consent_activity}->{code} = q{#					{
#					-Title      => 'usage_log_to_consent_activity',
#					-Title_URL  => $S_PROGRAM_URL."/plugins/usage_log_to_consent_activity",
#					-Function   => 'usage_log_to_consent_activity',
#					-Activated  => 0,
#					},};


my $advanced_config_params = {
show_scheduled_jobs_options         => 1,
show_deployment_options             => 1,
show_profiles                       => 1,
show_global_template_options        => 1,
show_security_options               => 1,
show_captcha_options                => 1,
show_global_mailing_list_options    => 1,
show_global_mass_mailing_options    => 1,
show_cache_options                  => 1,
show_debugging_options              => 1,
show_confirmation_token_options     => 1,
show_amazon_ses_options             => 1,
show_program_name_options           => 1,
show_s_program_url_options          => 0,
show_annoying_whiny_pro_dada_notice => 0,
};

# Address isn't in here.
my %bounce_handler_plugin_configs = (
    Server                   => { default => '',     if_blank => 'undef' },
    Username                 => { default => '',     if_blank => 'undef' },
    Password                 => { default => '',     if_blank => 'undef' },
    Port                     => { default => 'AUTO', if_blank => 'AUTO' },
    USESSL                   => { default => 0,      if_blank => 0 },
	starttls                 => { default => 0,      if_blank => 0 },
    SSL_verify_mode          => { default => 0,      if_blank => 0 },
	AUTH_MODE                => { default => 'POP', if_blank => 'POP' },
    MessagesAtOnce           => { default => '100',  if_blank => '100' },
    Enable_POP3_File_Locking => { default => 1,      if_blank => 0 },
);

my %bridge_plugin_configs = (
    MessagesAtOnce                      => { default => 1,       if_blank => 1 },         # Don't want, "0", you know?
    Room_For_One_More_Check             => { default => 1,       if_blank => 0 },
    Enable_POP3_File_Locking            => { default => 1,       if_blank => 0 },
    Check_List_Owner_Return_Path_Header => { default => 0,       if_blank => 0 },
    Check_Multiple_Return_Path_Headers  => { default => 0,       if_blank => 0 },
);

my @Debug_Option_Names = qw(
  DADA_App_BounceHandler
  DADA_App_DBIHandle
  DADA_App_FormatMessages
  DADA_App_Subscriptions
  DADA_App_WebServices
  DADA_Logging_Clickthrough
  DADA_Mail_MailOut
  DADA_Mail_Send
  DADA_MailingList
  DADA_MailingList_MessageDrafts
  DADA_Profile
  DADA_Profile_Fields
  DADA_Profile_Session
  DBI
  HTML_TEMPLATE
  MIME_LITE_HTML
  NET_POP3
  NET_SMTP
);

my @Plugin_Names = qw(
  boilerplate_plugin
  tracker
  bounce_handler
  bridge
  change_root_password
  change_list_shortname
  password_protect_directories
  log_viewer
  screen_cache
  global_config
  view_list_settings
  usage_log_to_consent_activity
);
my @Extension_Names = qw(
    blog_index
    multiple_subscribe
); 

# An unconfigured Dada Mail won't have these exactly handy to use.
$DADA::Config::PROGRAM_URL   = program_url_guess();
$DADA::Config::S_PROGRAM_URL = $DADA::Config::PROGRAM_URL; #program_url_guess();

use DADA::Config 11.0.0;
use DADA::App::Guts;
use DADA::Template::Widgets;
use DADA::Template::HTML;

sub setup {

    my $self = shift;

    $Self_URL = $self->self_url();

    $self->start_mode('install_or_upgrade');
    $self->mode_param('flavor');
    $self->run_modes(
        install_or_upgrade                => \&install_or_upgrade,
        check_install_or_upgrade          => \&check_install_or_upgrade,
        install_dada                      => \&install_dada,
        scrn_configure_dada_mail          => \&scrn_configure_dada_mail,
        check                             => \&check,
        move_installer_dir_ajax           => \&move_installer_dir_ajax,
        show_current_dada_config          => \&show_current_dada_config,
        screen                            => \&screen,
        cgi_test_sql_connection           => \&cgi_test_sql_connection,
        cgi_test_pop3_connection          => \&cgi_test_pop3_connection,
        cgi_test_user_template            => \&cgi_test_user_template,
        cgi_test_magic_template           => \&cgi_test_magic_template, 
        cgi_test_magic_template_diag_box => \&cgi_test_magic_template_diag_box, 
        cgi_test_amazon_ses_configuration => \&cgi_test_amazon_ses_configuration,
        cgi_test_CAPTCHA_Google_reCAPTCHA => \&cgi_test_CAPTCHA_Google_reCAPTCHA,
        cgi_test_captcha_reCAPTCHA_Mailhide => \&cgi_test_captcha_reCAPTCHA_Mailhide,
        #cgi_test_FastCGI                    => \&cgi_test_FastCGI,
        cl_run                               => \&cl_run, 
    );
    
    if ( !$ENV{GATEWAY_INTERFACE} ) {
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
            'install_wysiwyg_editors=s@',
            'install_file_browser=s',
            'deployment_running_under=s',
            'scheduled_jobs_flavor=s', 
            'amazon_ses_AWSAccessKeyId=s',
            'amazon_ses_AWSSecretKey=s',
            'amazon_ses_AWS_endpoint=s',
            'amazon_ses_Allowed_Sending_Quota_Percentage=s',
			'mime_tools_options_tmp_to_core=s',
			'mime_tools_options_tmp_dir=s',
            'help', 
        );
        
        $self->param('cl_params', \%h); 
        $self->start_mode('cl_run');
    
    }
}

sub cl_run {

    my $self = shift;
    my $r; 
    
    my $cl_params = $self->param('cl_params'); 

    if ( scalar( keys %$cl_params ) == 0 ) {
        return $self->cl_quickhelp();
        exit;
    }
    elsif ( $cl_params->{cl_params} == 1 ) {
        return $self->cl_help();
        exit;
    }
    
   # require Data::Dumper; 
   # $r .= "Passed Params:\n\n" . Data::Dumper::Dumper($cl_params); 
    
    my $dash_opts = {};
    foreach ( keys %$cl_params ) {
        $dash_opts->{ '-' . $_ } = $cl_params->{$_};
    }
    
    # Shortcut, so we don't have to pass two params: 
    if(exists($cl_params->{deployment_running_under})){ 
        $dash_opts->{-configure_deployment}                 = 1;
        # Welp, already doing that. 
        # $dash_opts->{-deployment_running_under} = $cl_params->{deployment_running_under};
    }
    
    $dash_opts->{-current_dada_files_parent_location} = $cl_params->{dada_files_loc};
    
    # UPGRADING? 
    if ( exists( $cl_params->{upgrading} ) ) {
        if ( $dash_opts->{-upgrading} == 1 ) {
            $dash_opts->{-install_type}                       = 'upgrade';
            $dash_opts->{-if_dada_files_already_exists}       = 'keep_dir_create_new_config';
            $dash_opts->{-dada_pass_use_orig}                 = 1;

            my $former_opts = $self->grab_former_config_vals();
            $dash_opts = _fold_hashref( $dash_opts, $former_opts );
            
          #  $r .= 'scheduled_jobs_flavor' . $dash_opts->{-scheduled_jobs_flavor}; 
            
            #require Data::Dumper; 
            #$r .= 'Previous Params: ' . Data::Dumper::Dumper($dash_opts); 
        }
    }

    $dash_opts->{-configure_scheduled_jobs} = 1; 
    if ( exists( $cl_params->{scheduled_jobs_flavor} ) ) {
    }
    else { 
        $dash_opts->{-scheduled_jobs_flavor} = '_sched' . uc( substr( DADA::App::Guts::generate_rand_string_md5(), 0, 16 ) );   
    }

    # PLUGINS!
    if ( exists( $cl_params->{install_plugins} ) ) {
        my @install_plugins = split( /,/, join( ',', @{ $cl_params->{install_plugins} } ) );
        for (@install_plugins) {
            $dash_opts->{ '-install_' . $_ } = 1;
        }
		# why is this then deleted? 
        delete $dash_opts->{-install_plugins};
    }

    # SQLite needs "-sql_database" set to the name of the file you want the 
    # database saved as, but it's not required you explicitly set that name: 
    if(exists($cl_params->{backend})){ 
        if($cl_params->{backend} eq 'SQLite') { 
            if(!exists($dash_opts->{-sql_database})){ 
                $dash_opts->{-sql_database} = 'dadamail';
            }
        }
    }
    
    # Amazon SES: 
    if(exists($cl_params->{amazon_ses_AWSAccessKeyId})
    && exists($cl_params->{amazon_ses_AWSSecretKey})
    ){ 
        $dash_opts->{-configure_amazon_ses} = 1; 
    }

    # Dada Root Pass - no need to retype it on the CL
    if ( exists( $dash_opts->{-dada_root_pass} ) ) {
        $dash_opts->{-dada_pass_use_orig}   = 0;
        $dash_opts->{-dada_root_pass_again} = $dash_opts->{-dada_root_pass};
    }

    my $install_dada_files_loc = $self->install_dada_files_dir_at_from_params(
         {
             -install_type                       => $dash_opts->{-install_type},
             -current_dada_files_parent_location => $dash_opts->{-current_dada_files_parent_location},
             -dada_files_dir_setup               => $dash_opts->{-dada_files_dir_setup},
             -dada_files_loc                     => $dash_opts->{-dada_files_loc},  
         }
     ); 
     $dash_opts->{-install_dada_files_loc} = $install_dada_files_loc;
     $self->param( 'install_params', $dash_opts );
    



     
     $r .= "Checking Setup...\n";
    
    my ( $check_status, $check_errors, $check_r ) = $self->check_setup();
    $r .= $check_r; 
    if ( $check_status == 0 ) {
        $r .= "Problems were found:\n\n";
        for ( keys %$check_errors ) {
            if ( $check_errors->{$_} == 1 ) {
                $r .= "Error: $_\n";
            }
        }
        $r .= "\n" . $Big_Pile_Of_Errors . "\n";
        return $r; 
    }
    else {
         $r .= "Paramaters passed look great! Configuring...\n";
        my ( $install_log, $install_status, $install_errors ) = $self->install_dada_mail();

         $r .= $install_log . "\n";
        if ( $install_status == 0 ) {
             $r .= "Problems with configuration:\n\n";

            for ( keys %$install_errors ) {
                 $r .= $_ . " => " . $install_errors->{$_} . "\n";
            }
        }
        else {
             $r .= "Moving and Disabling, \"installer\" directory\n";
            my ( $new_dir, $eval_errors ) = $self->move_installer_dir();
            if ($eval_errors) {
                 $r .= "Problems with moving installer directory: \n $eval_errors\n\n";
            }
            else {
                 $r .= "Installer directory moved to, \"$new_dir\"\n";
                 $r .= "Installation and Configuration Complete.\n\n\n";
            }
        }
    }
    
    my $ip   = $self->param('install_params');
    my $sched_flavor = $ip->{'-scheduled_jobs_flavor'} || '_schedules';
    my $curl_location = `which curl` || '/cannot/find/curl';
    chomp($curl_location); 
    
    $r .= "Cronjob Example:\n\n"; 
    $r .= $curl_location . ' -s --get --url ' . $dash_opts->{'-program_url'} . '/' . $sched_flavor . '/_all/_all/_silent/' . "\n\n";
    
    $self->header_type('none');
    
    return $r; 
}

sub _fold_hashref {
    
    my $orig_d = shift || {};
    my $new_d  = shift || {};

    foreach my $key2 ( keys %{$new_d} ) {
        if ( exists $orig_d->{$key2} ) {

            #  warn "Key [$key2] is in both hashes!";

            if ( length( $new_d->{$key2} ) > 0 ) {
                $orig_d->{$key2} = $new_d->{$key2};
            }
            else {
                # warn "keeping old value.";
            }
        }
        else {
            $orig_d->{$key2} = $new_d->{$key2};
        }
    }

    #use Data::Dumper;
    # warn 'diag now looks like this: ' . Dumper($orig_d);
    return $orig_d;

}

sub cl_quickhelp {
    my $self = shift; 
    
    return 
        DADA::Template::Widgets::screen(
            {
                -screen => 'cl_quickhelp_scrn.tmpl',
                -vars   => {

                },
            }
        )

}

sub cl_help {
    my $self = shift; 

    return 
        DADA::Template::Widgets::screen(
            {
                -screen => 'cl_help_scrn.tmpl',
                -vars   => {

                },
            }
        );
}

sub install_or_upgrade {

    my $self = shift;
    my $q    = $self->query();

    eval {
        require DADA::App::ScreenCache;
        my $c = DADA::App::ScreenCache->new;
        $c->flush;
    };

    my $dada_files_parent_dir = BootstrapConfig::guess_config_file();
    $dada_files_parent_dir =~ s/\/$Dada_Files_Dir_Name\/\.configs\/\.dada_config//;
    my $found_existing_dada_files_dir = $self->test_complete_dada_files_dir_structure_exists($dada_files_parent_dir);

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'install_or_upgrade.tmpl',
            -with   => 'list',
            -wrapper_params => {
                -Use_Custom => 0,
            },
            -vars   => {

                # These are tricky....
                SUPPORT_FILES_URL                   => $Self_URL . '?flavor=screen&screen=',
                dada_files_parent_dir               => $dada_files_parent_dir,
                Dada_Files_Dir_Name                 => $Dada_Files_Dir_Name,
                found_existing_dada_files_dir       => $found_existing_dada_files_dir,
                current_dada_files_parent_location  => scalar $q->param('current_dada_files_parent_location'),
                error_cant_find_dada_files_location => scalar $q->param('error_cant_find_dada_files_location'),
                Self_URL                            => $Self_URL,
            },
        }
    );

    # Let's get some fancy js stuff!
    $scrn = hack_in_js($scrn);

    # Uh, do are darnest to get the $PROGRAM_URL stuff working correctly,
    $scrn = hack_program_url($scrn);

    if ( $q->param('error_cant_find_dada_files_location') == 1 ) {
        require HTML::FillInForm::Lite;
        my $h = HTML::FillInForm::Lite->new();
        $scrn = $h->fill( \$scrn, $q );
    }

    return $scrn;
}

sub check_install_or_upgrade {

    my $self = shift;
    my $q    = $self->query();
    if ( $q->param('install_type') eq 'install' ) {
        return $self->scrn_configure_dada_mail();
    }
    elsif ( $q->param('install_type') eq 'upgrade' ) {

        my $current_dada_files_parent_location = '';
        if ( $q->param('current_dada_files_parent_location') eq 'auto' ) {
            $current_dada_files_parent_location = $self->auto_dada_files_dir();
            $q->param( 'current_dada_files_parent_location', $current_dada_files_parent_location );
        }
        else {
            $current_dada_files_parent_location = $q->param('current_dada_files_parent_location');
        }

        if ( $self->test_complete_dada_files_dir_structure_exists($current_dada_files_parent_location) == 1 ) {
            return $self->scrn_configure_dada_mail;
        }
        else {
            $q->param( 'error_cant_find_dada_files_location', 1 );
            return $self->install_or_upgrade;
        }
    }
    else {
        die 'unknown upgrade type! ' . $q->param('install_type');
    }
}

sub scrn_configure_dada_mail {

    my $self = shift;
    my $q    = $self->query();

    my $current_dada_files_parent_location = $q->param('current_dada_files_parent_location');
    my $install_type                       = $q->param('install_type');

    if ( $install_type eq 'upgrade'
        && -e $current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config' )
    {
        BootstrapConfig::config_import(
            make_safer( $current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config' ) );
    }

    $q->delete( 'current_dada_files_parent_location', 'install_type', 'flavor', 'submitbutton' );

    # Have we've been here, before?
    my %params = $q->Vars;

    if ( !keys %params ) {

        # well, then place some defaults:
        $q->param( 'install_change_root_password',  1 );
        $q->param( 'install_screen_cache',          1 );
        $q->param( 'install_log_viewer',            1 );
        $q->param( 'install_tracker',               1 );
        $q->param( 'install_multiple_subscribe',    1 );
        $q->param( 'install_blog_index',            1 );
        $q->param( 'install_bridge',                1 );
        $q->param( 'install_bounce_handler',        0 );
        $q->param( 'install_change_list_shortname', 1 );
        $q->param( 'install_global_config',         1 );

        for my $d (
            qw(
            MessagesAtOnce
            Allow_Manual_Run
            Room_For_One_More_Check
            Enable_POP3_File_Locking
            Check_List_Owner_Return_Path_Header
            )
          )
        {
            $q->param( 'bridge_' . $d, $bridge_plugin_configs{$d}->{default} );
        }
        for my $d (
            qw(
            Port
            AUTH_MODE
            MessagesAtOnce
            Allow_Manual_Run
            Enable_POP3_File_Locking
            )
          )
        {
            $q->param( 'bounce_handler_' . $d, $bounce_handler_plugin_configs{$d}->{default} );
        }

    }

    # This is a test to see if the, "auto" placement will work for us - or
    # for example, there's something in the way.
    # First, let's see if there's any errors:
    if ( defined( $q->param('errors') ) ) {

        # No? Good -
    }
    else {
        if ( $self->test_can_create_dada_files_dir( $self->auto_dada_files_dir() ) == 0 ) {
            $q->param( 'dada_files_loc',       $self->auto_dada_files_dir() );
            $q->param( 'dada_files_dir_setup', 'manual' );
        }
    }

    my $configured_dada_config_file;
    my $configured_dada_files_loc;
    my $original_dada_root_pass = undef;

    my $param_vals_from_former_config = undef;

    if ( $install_type eq 'upgrade' ) {

        $configured_dada_config_file =
          $current_dada_files_parent_location . '/' . $Dada_Files_Dir_Name . '/' . '.configs/.dada_config';

        $configured_dada_files_loc = $current_dada_files_parent_location;

        $original_dada_root_pass = $BootstrapConfig::PROGRAM_ROOT_PASSWORD;    # Why is this here, instead of grab_...

    }
    else {

        $configured_dada_config_file = $DADA::Config::CONFIG_FILE
          ;   # This may also be strange, although if this is an install, it'll just give you the default guess, anyways
        $configured_dada_files_loc = $configured_dada_config_file;
        $configured_dada_files_loc =~ s/\/$Dada_Files_Dir_Name\/\.configs\/\.dada_config//;
    }

    my $DOC_VER = $DADA::Config::VER;    # I guess this one's fine.
    $DOC_VER =~ s/\s(.*?)$//;
    $DOC_VER =~ s/\./\_/g;

    # I'm going to fill this back in:
    $q->param( 'install_type',                       $install_type );
    $q->param( 'current_dada_files_parent_location', $current_dada_files_parent_location );
	
	require HTML::Menu::Select; 
    my $amazon_ses_Allowed_Sending_Quota_Percentage_popup_menu = HTML::Menu::Select::popup_menu(
        { 
			name    => 'amazon_ses_Allowed_Sending_Quota_Percentage',
	        id      => 'amazon_ses_Allowed_Sending_Quota_Percentage',
	        values  => [ reverse( ( 1 .. 100 ) ) ],
	        default => $DADA::Config::AMAZON_SES_OPTIONS->{Allowed_Sending_Quota_Percentage},
		}
    );

    my $install_dada_files_dir_at = $self->install_dada_files_dir_at_from_params(
        {
            -install_type                       => scalar $q->param('install_type'),
            -current_dada_files_parent_location => scalar $q->param('current_dada_files_parent_location'),
            -dada_files_dir_setup               => scalar $q->param('dada_files_dir_setup'),
            -dada_files_loc                     => scalar $q->param('dada_files_loc'),  

        }
    );
	
	my $AT_INC = []; 
	for(sort @INC){ 
		push(@$AT_INC, {name => $_})
	};

    #die '$install_dada_files_dir_at ' . $install_dada_files_dir_at;

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'installer_configure_dada_mail_scrn.tmpl',
            -with   => 'list',
            -expr   => 1,
            -wrapper_params => {
                -Use_Custom => 0,
            },
            -vars   => {
                %$advanced_config_params,

                # These are tricky....
                SUPPORT_FILES_URL                  => $Self_URL . '?flavor=screen&screen=',
                Self_URL                           => $Self_URL,
                install_type                       => $install_type,
                current_dada_files_parent_location => $current_dada_files_parent_location,
                program_url_guess                  => scalar program_url_guess(),
                can_use_DBI                        => scalar test_can_use_DBI(),
                can_use_MySQL                      => scalar test_can_use_MySQL(),
                can_use_Pg                         => scalar test_can_use_Pg(),
                can_use_SQLite                     => scalar test_can_use_SQLite(),
                can_use_CAPTCHA_Google_reCAPTCHA   => scalar test_can_use_CAPTCHA_Google_reCAPTCHA(),

                can_use_CAPTCHA_reCAPTCHA_Mailhide => scalar test_can_use_CAPTCHA_reCAPTCHA_Mailhide(),
                can_use_HTML_Tree                  => scalar can_use_HTML_Tree(), 
                error_cant_read_config_dot_pm      => scalar $self->test_can_read_config_dot_pm(),
                error_cant_write_config_dot_pm     => scalar $self->test_can_write_config_dot_pm(),
                cgi_test_FastCGI                   => scalar $self->cgi_test_FastCGI,
                home_dir_guess                     => scalar $self->guess_home_dir(),
                install_dada_files_dir_at          => scalar $install_dada_files_dir_at,
                test_complete_dada_files_dir_structure_exists => scalar $self->test_complete_dada_files_dir_structure_exists($install_dada_files_dir_at),
                dada_files_dir_setup                     => scalar $q->param('dada_files_dir_setup')                     || '',
                dada_files_loc                           => scalar $q->param('dada_files_loc')                           || '',
                error_create_dada_mail_support_files_dir => scalar $q->param('error_create_dada_mail_support_files_dir') || 0,
                error_root_pass_is_blank                 => scalar $q->param('error_root_pass_is_blank')                 || 0,
                error_pass_no_match                      => scalar $q->param('error_pass_no_match')                      || 0,
                error_program_url_is_blank               => scalar $q->param('error_program_url_is_blank')               || 0,
                error_create_dada_files_dir              => scalar $q->param('error_create_dada_files_dir')              || 0,
                error_dada_files_dir_exists              => scalar $q->param('error_dada_files_dir_exists')              || 0,
                error_sql_connection                     => scalar $q->param('error_sql_connection')                     || 0,
                error_sql_table_populated                => scalar $q->param('error_sql_table_populated')                || 0,
                skip_configure_SQL                       => scalar $q->param('skip_configure_SQL')                       || 0,
                errors                                   => scalar $q->param('errors')                                   || [],
                PROGRAM_URL                              => scalar program_url_guess(),
                S_PROGRAM_URL                            => scalar program_url_guess(),
                Dada_Files_Dir_Name                      => $Dada_Files_Dir_Name,
                configured_dada_config_file              => $configured_dada_config_file,
                configured_dada_files_loc                => $configured_dada_files_loc,
                DOC_VER                                  => $DOC_VER,
                DOC_URL                                  => 'http://dadamailproject.com/support/documentation-' . $DOC_VER,
                original_dada_root_pass                  => $original_dada_root_pass,
                support_files_dir_path                   => scalar $self->support_files_dir_path_guess(),
                support_files_dir_url                    => scalar $self->support_files_dir_url_guess(),
                Support_Files_Dir_Name                   => $Support_Files_Dir_Name,
                amazon_ses_requirements_widget           => scalar DADA::Template::Widgets::amazon_ses_requirements_widget(),

                amazon_ses_Allowed_Sending_Quota_Percentage_popup_menu =>
                  $amazon_ses_Allowed_Sending_Quota_Percentage_popup_menu,
				Server_TMP_dir => $Server_TMP_dir, 
                
				AT_INC => $AT_INC, 
				
				Big_Pile_Of_Errors => $Big_Pile_Of_Errors,
                Trace              => $Trace,
				
				
            },
        }
    );

    # Let's get some fancy js stuff!
    $scrn = hack_in_js($scrn);

    # Uh, do are darnest to get the $PROGRAM_URL stuff working correctly,
    $scrn = hack_program_url($scrn);

    my $q = $self->query;
    require HTML::FillInForm::Lite;
    my $h = HTML::FillInForm::Lite->new();
    if (
           $install_type eq 'upgrade'
        && -e $configured_dada_config_file
        && !defined( $q->param('errors') )

      )
    {
        my $former_opts = $self->grab_former_config_vals();        
        for ( keys %$former_opts ) {
            my $n = $_;
            $n =~ s/^\-//;
            $q->param( $n, $former_opts->{$_} );
        }
    }
    $scrn = $h->fill( \$scrn, $q );

    return $scrn;

}

sub grab_former_config_vals {

    my $self = shift;
    my $opt  = {};

    # $PROGRAM_URL
    $opt->{'program_url'} = $BootstrapConfig::PROGRAM_URL;

    # $SUPPORT_FILES
    my $support_files_dir_path;
    if ( defined( $BootstrapConfig::SUPPORT_FILES->{dir} ) ) {
        ($support_files_dir_path) = $BootstrapConfig::SUPPORT_FILES->{dir} =~ m/^(.*?)\/$Support_Files_Dir_Name$/;
        $opt->{'support_files_dir_path'} = $support_files_dir_path;
    }
    else {
        # in v5, there was no $SUPPORT_FILES var, but we're using the same dir as KCFinder, so we can look there:
        ($support_files_dir_path) = $BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{upload_dir} =~
          m/^(.*?)\/$Support_Files_Dir_Name\/$File_Upload_Dir$/;
        $opt->{'support_files_dir_path'} = $support_files_dir_path;
    }
    my $support_files_dir_url;
    if ( defined( $BootstrapConfig::SUPPORT_FILES->{url} ) ) {
        ($support_files_dir_url) = $BootstrapConfig::SUPPORT_FILES->{url} =~ m/^(.*?)\/$Support_Files_Dir_Name$/;
        $opt->{'support_files_dir_url'} = $support_files_dir_url;
    }
    else {
        # in v5, there was no $SUPPORT_FILES var, but we're using the same dir as KCFinder, so we can look there:
        ($support_files_dir_url) = $BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{upload_url} =~
          m/^(.*?)\/$Support_Files_Dir_Name\/$File_Upload_Dir$/;
        $opt->{'support_files_dir_url'} = $support_files_dir_url;
    }

    # $PROGRAM_ROOT_PASSWORD
    $opt->{'original_dada_root_pass'}              = $BootstrapConfig::PROGRAM_ROOT_PASSWORD;
    $opt->{'original_dada_root_pass_is_encrypted'} = $BootstrapConfig::ROOT_PASS_IS_ENCRYPTED;

    $opt->{'backend'}      = $BootstrapConfig::SQL_PARAMS{dbtype};
    $opt->{'sql_server'}   = $BootstrapConfig::SQL_PARAMS{dbserver};
    $opt->{'sql_database'} = $BootstrapConfig::SQL_PARAMS{database};
    $opt->{'sql_port'}     = $BootstrapConfig::SQL_PARAMS{port};
    $opt->{'sql_username'} = $BootstrapConfig::SQL_PARAMS{user};
    $opt->{'sql_password'} = $BootstrapConfig::SQL_PARAMS{pass};


    my @plugin_exts = (
        qw(
          multiple_subscribe
          blog_index
          )
    );

    if ( keys %$BootstrapConfig::PLUGINS_ENABLED ) {
        for ( keys %$BootstrapConfig::PLUGINS_ENABLED ) {
            if ( $BootstrapConfig::PLUGINS_ENABLED->{$_} == 1 ) {
                $opt->{ 'install_' . $_ } = 1;
            }
            else {
                $opt->{ 'install_' . $_ } = 0;
            }
        }
    }
    else {
        # else, we'll look for it, in the admin menu.
        push(
            @plugin_exts, qw(
              change_root_password
              screen_cache
              log_viewer
              tracker
              bridge
              bounce_handler
              change_list_shortname
              global_config
              password_protect_directories
              )
        );
    }

    # Plugins/Extensions 
    for my $plugin_ext (@plugin_exts) {

        if ( admin_menu_item_used($plugin_ext) == 1 ) {
            $opt->{ 'install_' . $plugin_ext } = 1;
        }
        else {
            $opt->{ 'install_' . $plugin_ext } = 0;
        }
    }

    # in ver. < 6, these were called something different...
    if ( admin_menu_item_used('dada_bounce_handler') == 1 ) {
        $opt->{'install_bounce_handler'} = 1;
    }
    if ( admin_menu_item_used('dada_bridge') == 1 ) {
        $opt->{'install_bridge'} = 1;
    }
    if ( admin_menu_item_used('clickthrough_tracking') == 1 ) {
        $opt->{'install_tracker'} = 1;
    }

    # Bridge
    if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Bridge} ) ) {
        for my $config ( keys %bridge_plugin_configs ) {
            if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{$config} ) ) {
                if ( defined( $BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{$config} ) ) {
                    $opt->{ 'bridge_' . $config } = $BootstrapConfig::PLUGIN_CONFIGS->{Bridge}->{$config};
                }
                else {
                    $opt->{ 'bridge_' . $config } = $bridge_plugin_configs{$config}->{default};
                }
            }
            else {
                $opt->{ 'bridge_' . $config } = $bridge_plugin_configs{$config}->{default};
            }
        }
    }

    # Bounce Handler
    if ( exists( $BootstrapConfig::LIST_SETUP_INCLUDE{admin_email} ) ) {
        $opt->{'bounce_handler_Address'} = $BootstrapConfig::LIST_SETUP_INCLUDE{admin_email};
    }
    if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler} ) ) {
        for my $config ( keys %bounce_handler_plugin_configs ) {
            if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{$config} ) ) {
                if ( defined( $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{$config} ) ) {
                    $opt->{ 'bounce_handler_' . $config } =
                      $BootstrapConfig::PLUGIN_CONFIGS->{Bounce_Handler}->{$config};
                }
                else {
                    $opt->{ 'bounce_handler_' . $config } = $bounce_handler_plugin_configs{$config}->{default};
                }
            }
            else {
                $opt->{ 'bounce_handler_' . $config } = $bounce_handler_plugin_configs{$config}->{default};
            }
        }
    }

    # "Bounce_Handler" could also be, "Mystery_Girl" (change made in v4.9.0)
    elsif ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl} ) ) {
        if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Server} ) ) {
            $opt->{'bounce_handler_Server'} = $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Server};
        }
        if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Username} ) ) {
            $opt->{'bounce_handler_Username'} = $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Username};
        }
        if ( exists( $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Password} ) ) {
            $opt->{'bounce_handler_Password'} = $BootstrapConfig::PLUGIN_CONFIGS->{Mystery_Girl}->{Password};
        }
    }

    # WYSIWYG Editors
    # Kinda gotta guess on this one,
    if (   $BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{ckeditor}->{enabled} == 1
        || $BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{tiny_mce}->{enabled} == 1
        || $BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} == 1
        || $BootstrapConfig::FILE_BROWSER_OPTIONS->{core5_filemanager}->{enabled} == 1
        || $BootstrapConfig::FILE_BROWSER_OPTIONS->{rich_filemanager}->{enabled} == 1 )
    {
        $opt->{'install_wysiwyg_editors'} = 1;
    }
    else {
        $opt->{'install_wysiwyg_editors'} = 0;
    }

    for my $editor (qw(ckeditor tiny_mce)) {

        # And then, individual:
        if ( $BootstrapConfig::WYSIWYG_EDITOR_OPTIONS->{$editor}->{enabled} == 1 ) {
            $opt->{ 'wysiwyg_editor_install_' . $editor } = 1;
        }
        else {
            $opt->{ 'wysiwyg_editor_install_' . $editor } = 0;
        }
    }
    if ( $BootstrapConfig::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} == 1 ) {
        $opt->{'install_file_browser'} = 'kcfinder';
    }
    elsif ( $BootstrapConfig::FILE_BROWSER_OPTIONS->{core5_filemanager}->{enabled} == 1 ) {
        $opt->{'install_file_browser'} = 'core5_filemanager';
        $opt->{'core5_filemanager_connector'} =
          $BootstrapConfig::FILE_BROWSER_OPTIONS->{core5_filemanager}->{connector};
    }
    elsif ( $BootstrapConfig::FILE_BROWSER_OPTIONS->{rich_filemanager}->{enabled} == 1 ) {
        $opt->{'install_file_browser'} = 'rich_filemanager';
	}

    if ( defined($BootstrapConfig::MAILOUT_STALE_AFTER) 
	||   defined($BootstrapConfig::MAILOUT_AT_ONCE_LIMIT)) { 
        $opt->{'configure_mass_mailing'} = 1;
        $opt->{'mass_mailing_MAILOUT_STALE_AFTER'} = $BootstrapConfig::MAILOUT_STALE_AFTER;
        $opt->{'mass_mailing_MAILOUT_AT_ONCE_LIMIT'} = $BootstrapConfig::MAILOUT_AT_ONCE_LIMIT;
	}


    # $SCHEDULED_JOBS_OPTIONS
    if ( keys( %{$BootstrapConfig::SCHEDULED_JOBS_OPTIONS} ) ) {
        $opt->{'configure_scheduled_jobs'} = 1;
        if ( !exists( $BootstrapConfig::SCHEDULED_JOBS_OPTIONS->{scheduled_jobs_flavor} ) ) {
            my $ran_str = '_sched' . uc( substr( DADA::App::Guts::generate_rand_string_md5(), 0, 16 ) );
            $BootstrapConfig::SCHEDULED_JOBS_OPTIONS->{scheduled_jobs_flavor} = $ran_str;
        }
        $opt->{'scheduled_jobs_flavor'}         = $BootstrapConfig::SCHEDULED_JOBS_OPTIONS->{scheduled_jobs_flavor};
        $opt->{'scheduled_jobs_log'}            = $BootstrapConfig::SCHEDULED_JOBS_OPTIONS->{log};
        $opt->{'scheduled_jobs_run_at_teardown'} = $BootstrapConfig::SCHEDULED_JOBS_OPTIONS->{run_at_teardown};
		
    }
    else {
        # Kind of a weird place to find this:
        my $ran_str = '_sched' . uc( substr( DADA::App::Guts::generate_rand_string_md5(), 0, 16 ) );
        $opt->{'scheduled_jobs_flavor'} = $ran_str;
    }

    # CGI/FastCGI/PSGI
    if ( defined($BootstrapConfig::RUNNING_UNDER) 
		&& $BootstrapConfig::RUNNING_UNDER 
		=~ m/^(CGI|FastCGI|PSGI)$/ 
	) {
        $opt->{'configure_deployment'}                 = 1;
        $opt->{'deployment_running_under'}             = $BootstrapConfig::RUNNING_UNDER;
    }

		
	
	if($BootstrapConfig::ADDITIONAL_PERLLIBS->[0]){ 
        $opt->{'configure_perl_env'} = 1;
		$opt->{'additional_perllibs'} = join("\n", @$BootstrapConfig::ADDITIONAL_PERLLIBS);
	}
	
	
	
	

    # Profiles
    if ( exists( $BootstrapConfig::PROFILE_OPTIONS->{enabled} ) ) {

        $opt->{'configure_profiles'} = 1;

        for (qw(
			enabled
			profile_email
			profile_host_list
			enable_captcha
		)) {
            if ( exists( $BootstrapConfig::PROFILE_OPTIONS->{$_} ) ) {
                $opt->{ 'profiles_' . $_ } = $BootstrapConfig::PROFILE_OPTIONS->{$_};
            }
        }

        # Features

        for (
            qw(
            register
            password_reset
            profile_fields
            mailing_list_subscriptions
            protected_directories
            update_email_address
            change_password
            delete_profile
            )
          )
        {

            if ( exists( $BootstrapConfig::PROFILE_OPTIONS->{features}->{$_} ) ) {
                $opt->{ 'profiles_' . $_ } = $BootstrapConfig::PROFILE_OPTIONS->{features}->{$_};
            }
        }

    }

    # Global Template Options
    if ( keys %$BootstrapConfig::TEMPLATE_OPTIONS
        && $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{mode} =~ m/manual|magic/) {
        # for qw(all these options...){ 
        $opt->{'configure_templates'}                   = 1;
        $opt->{'template_options_enabled'}              = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{enabled};
        $opt->{'template_options_mode'}                 = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{mode};
        $opt->{'template_options_manual_template_url'}  = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{manual_options}->{template_url};
        
        $opt->{'template_options_magic_template_url'}   = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{template_url};
        $opt->{'template_options_add_base_href'}        = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{add_base_href};
        $opt->{'template_options_base_href_url'}        = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{base_href_url};
        $opt->{'template_options_replace_content_from'} = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{replace_content_from};
        $opt->{'template_options_replace_id'}           = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{replace_id};
        $opt->{'template_options_replace_class'}        = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{replace_class};
        $opt->{'template_options_add_app_css'}          = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{add_app_css};
        $opt->{'template_options_add_custom_css'}       = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{add_custom_css};
        $opt->{'template_options_custom_css_url'}       = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{custom_css_url}; 
        $opt->{'template_options_include_jquery_lib'}   = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{include_jquery_lib}; 
        $opt->{'template_options_include_app_user_js'}  = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{include_app_user_js}; 
        $opt->{'template_options_head_content_added_by'}  = $BootstrapConfig::TEMPLATE_OPTIONS->{user}->{magic_options}->{head_content_added_by}; 
        
    }
    elsif(defined($BootstrapConfig::USER_TEMPLATE)) {
        # Backwards compat. 
        $opt->{'configure_templates'}                   = 1;
        $opt->{'template_options_enabled'}              = 1;
        $opt->{'template_options_mode'}                 = 'manual';
        $opt->{'template_options_manual_template_url'}  = $BootstrapConfig::USER_TEMPLATE; 
    }
    else { 
        # ... 
    }

    # Caching Options
    if ( defined($BootstrapConfig::SCREEN_CACHE) || defined($BootstrapConfig::DATA_CACHE) ) {
        $opt->{'configure_cache'} = 1;

        # Watch this, now:
        if ( defined($BootstrapConfig::SCREEN_CACHE) ) {
            if ( $BootstrapConfig::SCREEN_CACHE ne '1' ) {
                $opt->{'cache_options_SCREEN_CACHE'} = 0;
            }
            else {
                $opt->{'cache_options_SCREEN_CACHE'} = 1;
            }
        }
        if ( defined($BootstrapConfig::DATA_CACHE) ) {
            if ( $BootstrapConfig::DATA_CACHE ne '1' ) {
                $opt->{'cache_options_DATA_CACHE'} = 0;
            }
            else {
                $opt->{'cache_options_DATA_CACHE'} = 1;
            }
        }
    }
    else {
        # Defaul to, "1". Better way?
        $opt->{'cache_options_SCREEN_CACHE'} = 1;
        $opt->{'cache_options_DATA_CACHE'}   = 1;
    }

    # Debugging Options
    if ( defined($BootstrapConfig::DEBUG_TRACE) || keys %BootstrapConfig::CPAN_DEBUG_SETTINGS ) {
        $opt->{'configure_debugging'} = 1;
        foreach ( keys %{$BootstrapConfig::DEBUG_TRACE} ) {
            $opt->{ 'debugging_options_' . $_ } = $BootstrapConfig::DEBUG_TRACE->{$_};
        }
        foreach ( keys %BootstrapConfig::CPAN_DEBUG_SETTINGS ) {
            $opt->{ 'debugging_options_' . $_ } = $BootstrapConfig::CPAN_DEBUG_SETTINGS{$_};
        }

    }

    # Configure Security Options
    if (   defined($BootstrapConfig::SHOW_ADMIN_LINK)
        || defined($BootstrapConfig::DISABLE_OUTSIDE_LOGINS)
        || defined($BootstrapConfig::ADMIN_FLAVOR_NAME)
        || defined($BootstrapConfig::SIGN_IN_FLAVOR_NAME) 
		|| keys    %$BootstrapConfig::CP_SESSION_PARAMS
        || defined($BootstrapConfig::RATE_LIMITING) 
		|| defined($BootstrapConfig::FILE_CHMOD)
		|| defined($BootstrapConfig::DIR_CHMOD) 
	)
    {
        $opt->{'configure_security'} = 1;
        if ( $BootstrapConfig::SHOW_ADMIN_LINK == 2 ) {
            $opt->{'security_no_show_admin_link'} = 1;
        }
        else {
            $opt->{'security_no_show_admin_link'} = 0;
        }
        $opt->{'security_DISABLE_OUTSIDE_LOGINS'} = $BootstrapConfig::DISABLE_OUTSIDE_LOGINS;
        $opt->{'security_ADMIN_FLAVOR_NAME'}      = $BootstrapConfig::ADMIN_FLAVOR_NAME;
        $opt->{'security_SIGN_IN_FLAVOR_NAME'}    = $BootstrapConfig::SIGN_IN_FLAVOR_NAME;
		
		if(keys    %$BootstrapConfig::CP_SESSION_PARAMS) { 
			$opt->{'security_session_params_check_matching_ip_addresses'} 
				= $BootstrapConfig::CP_SESSION_PARAMS->{security_session_params_check_matching_ip_addresses};
		}
		if(keys    %$BootstrapConfig::RATE_LIMITING) { 
			$opt->{'security_rate_limiting_enabled'} = $BootstrapConfig::RATE_LIMITING->{enabled};
			$opt->{'security_rate_limiting_max_hits'} = $BootstrapConfig::RATE_LIMITING->{max_hits};
			$opt->{'security_rate_limiting_timeframe'} = $BootstrapConfig::RATE_LIMITING->{timeframe};
		}
		
        if ( defined($BootstrapConfig::FILE_CHMOD) ) {
			$opt->{'security_default_file_permissions'} 	 = int(sprintf("%o", $BootstrapConfig::FILE_CHMOD)); 
			#0755 turns into, 755
		}
        if ( defined($BootstrapConfig::DIR_CHMOD) ) {
			$opt->{'security_default_directory_permissions'} = int(sprintf("%o", $BootstrapConfig::DIR_CHMOD));
		}

	#	use Data::Dumper; 
	#	die Dumper($opt)

    }

    # Configure CAPTCHA
    if (   defined($BootstrapConfig::CAPTCHA_TYPE)
        || keys %{$BootstrapConfig::RECAPTCHA_PARAMS}
        || keys %{$BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS} )
    {
        $opt->{'configure_captcha'} = 1;
		
		$opt->{'captcha_type'} = 'Google_reCAPTCHA';


        if ( defined( $BootstrapConfig::RECAPTCHA_PARAMS->{public_key} ) ) {
            $opt->{'captcha_reCAPTCHA_public_key'} = $BootstrapConfig::RECAPTCHA_PARAMS->{public_key};
        }
        if ( defined( $BootstrapConfig::RECAPTCHA_PARAMS->{private_key} ) ) {
            $opt->{'captcha_reCAPTCHA_private_key'} = $BootstrapConfig::RECAPTCHA_PARAMS->{private_key};
        }
        if ( defined( $BootstrapConfig::RECAPTCHA_PARAMS->{on_subscribe_form} ) ) {
            $opt->{'captcha_on_subscribe_form'} = $BootstrapConfig::RECAPTCHA_PARAMS->{on_subscribe_form};
        }

        if ( defined( $BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS->{public_key} ) ) {
            $opt->{'captcha_reCAPTCHA_Mailhide_public_key'} = $BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS->{public_key};
        }
        if ( defined( $BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS->{private_key} ) ) {
            $opt->{'captcha_reCAPTCHA_Mailhide_private_key'} =
              $BootstrapConfig::RECAPTHCA_MAILHIDE_PARAMS->{private_key};
        }
    }

    # Global Mailing List Options
    if (   defined($BootstrapConfig::GLOBAL_UNSUBSCRIBE)
        || defined($BootstrapConfig::GLOBAL_BLACK_LIST) )
    {
        $opt->{'configure_global_mailing_list_options'} = 1;
        if ( defined($BootstrapConfig::GLOBAL_UNSUBSCRIBE) ) {
            $opt->{'global_mailing_list_options_GLOBAL_UNSUBSCRIBE'} = $BootstrapConfig::GLOBAL_UNSUBSCRIBE;
        }
        if ( defined($BootstrapConfig::GLOBAL_BLACK_LIST) ) {
            $opt->{'global_mailing_list_options_GLOBAL_BLACK_LIST'} = $BootstrapConfig::GLOBAL_BLACK_LIST;
        }
    }

    # $CONFIRMATION_TOKEN_OPTIONS
    if ( keys %{$BootstrapConfig::CONFIRMATION_TOKEN_OPTIONS} ) {
        $opt->{'configure_confirmation_token'} = 1;
        $opt->{'confirmation_token_expires'}   = $BootstrapConfig::CONFIRMATION_TOKEN_OPTIONS->{expires};
    }


=cut
    # S_PROGRAM URL
    if ( defined($BootstrapConfig::S_PROGRAM_URL) ) {
        if ( $BootstrapConfig::S_PROGRAM_URL ne $BootstrapConfig::PROGRAM_URL ) {
            $opt->{'configure_s_program_url'}     = 1;
            $opt->{'s_program_url_S_PROGRAM_URL'} = $BootstrapConfig::S_PROGRAM_URL;
        }
    }
=cut 
	
    # PROGRAM NAME
    if ( defined($BootstrapConfig::PROGRAM_NAME) ) {
        $opt->{'configure_program_name'}    = 1;
        $opt->{'program_name_PROGRAM_NAME'} = $BootstrapConfig::PROGRAM_NAME;
    }

    # $AMAZON_SES_OPTIONS
    if (   defined( $BootstrapConfig::AMAZON_SES_OPTIONS->{AWSAccessKeyId} )
        && defined( $BootstrapConfig::AMAZON_SES_OPTIONS->{AWSSecretKey} ) )
    {
        $opt->{'configure_amazon_ses'}      = 1;
        $opt->{'amazon_ses_AWSAccessKeyId'} = $BootstrapConfig::AMAZON_SES_OPTIONS->{AWSAccessKeyId};
        $opt->{'amazon_ses_AWSSecretKey'}   = $BootstrapConfig::AMAZON_SES_OPTIONS->{AWSSecretKey};

        if ( exists( $BootstrapConfig::AMAZON_SES_OPTIONS->{AWS_endpoint} ) ) {
            $opt->{'amazon_ses_AWS_endpoint'} = $BootstrapConfig::AMAZON_SES_OPTIONS->{AWS_endpoint};
        }

        if ( exists( $BootstrapConfig::AMAZON_SES_OPTIONS->{Allowed_Sending_Quota_Percentage} ) ) {
            $opt->{'amazon_ses_Allowed_Sending_Quota_Percentage'} =
              $BootstrapConfig::AMAZON_SES_OPTIONS->{Allowed_Sending_Quota_Percentage};
        }
    }
	
	if(keys %$BootstrapConfig::MIME_TOOLS_PARAMS){ 
		
		$opt->{'configure_mime_tools'} = 1; 
        $opt->{'mime_tools_options_tmp_to_core'} 
			= $BootstrapConfig::MIME_TOOLS_PARAMS->{tmp_to_core};

        $opt->{'mime_tools_options_tmp_dir_'} 
			= $BootstrapConfig::MIME_TOOLS_PARAMS->{tmp_dir_};
	}

	
    my $dash_opt = {};
    for ( keys %$opt ) {
        $dash_opt->{ '-' . $_ } = $opt->{$_};
    }
    return $dash_opt;
}

sub admin_menu_item_used {
    my $function = shift;
    foreach my $menu (@$BootstrapConfig::ADMIN_MENU) {
        if ( $menu->{-Title} =~ m/Plugins|Extensions/ ) {
            my $submenu = $menu->{-Submenu};
            foreach my $item (@$submenu) {

                #	warn q{$item->{-Function} } . $item->{-Function};
                #	warn q{$function} . $function;
                if ( $item->{-Function} eq $function ) {

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
    my $dbtype   = shift;
    my $dbserver = shift;
    my $port     = shift;
    my $database = shift;
    my $user     = shift;
    my $pass     = shift;
    my $data_source;

    if ( $dbtype eq 'SQLite' ) {

        require DADA::Security::Password;

        # I doubt that's going to work for everything...
        $data_source =
          'dbi:' . $dbtype . ':' . '/tmp' . '/' . 'dadamail' . DADA::Security::Password::generate_rand_string();
    }
    else {
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

    #    Oh, so check_setup uses $q->param too, great.

    my $self = shift;
    my $q    = $self->query;

    $self->query_params_to_install_params();

    my ( $status, $errors, $check_r ) = $self->check_setup();

    #require Data::Dumper; 
    #die Data::Dumper::Dumper($errors); 
    
    if ( $status == 0 ) {
        my $ht_errors = [];

        for ( keys %$errors ) {
            if ( $errors->{$_} == 1 ) {
                push( @$ht_errors, { error => $_ } );
                $q->param( 'error_' . $_, 1 );
            }
        }
        $q->param( 'errors', $ht_errors );
        $self->scrn_configure_dada_mail();
    }
    else {
        $self->scrn_install_dada_mail();
    }

}

sub scrn_install_dada_mail {

    my $self = shift;
    my $q    = $self->query();

    # THis is sort of awkward - but we need to do the switcheroo:
    if ( $q->param('deployment_running_under') eq 'FastCGI' ) {
        my $purl = $q->param('program_url');
        if ( $purl =~ m/mail\.cgi$/ ) {
            $purl =~ s/mail\.cgi$/mail\.fcgi/;
            $q->param( 'program_url', $purl );
        }
    }
    elsif ( $q->param('deployment_running_under') eq 'PSGI' ) {
        my $purl = $q->param('program_url');
        if ( $purl =~ m/mail\.cgi$/ ) {
            $purl =~ s/mail\.cgi$/app\.psgi/;
            $q->param( 'program_url', $purl );
        }    
    }
    else {
        # This is sorta weird. 
        my $purl = $q->param('program_url');
        if ( $purl =~ m/mail\.fcgi$/ ) {
            $purl =~ s/mail\.fcgi$/mail\.cgi/;
            $q->param( 'program_url', $purl );
        }
    }
	
    if ( $q->param('configure_security') == 1 ) {

		my $file_perms = $q->param('security_default_file_permissions') // 644; 
		$file_perms = '0' . $file_perms;
		my $dir_perms = $q->param('security_default_directory_permissions') // 755;
		$dir_perms = '0' . $dir_perms;
		
			$DADA::Config::FILE_CHMOD = oct($file_perms);
			$DADA::Config::DIR_CHMOD  = oct($dir_perms); 
			
#			use Data::Dumper; 
#			die Dumper([$DADA::Config::FILE_CHMOD, $DADA::Config::DIR_CHMOD]); 
			
	}
	

	# This is also very awkward - we have to feed the new file/directory permissions that we may have also set! 
	# 


    my ( $log, $status, $errors ) = $self->install_dada_mail();

    my $sched_flavor = $q->param('scheduled_jobs_flavor') || '_schedules';
    my $curl_location = `which curl`;

    my $install_dada_files_loc = $self->install_dada_files_dir_at_from_params(
        {
            -install_type                       => scalar $q->param('install_type'),
            -current_dada_files_parent_location => scalar $q->param('current_dada_files_parent_location'),
            -dada_files_dir_setup               => scalar $q->param('dada_files_dir_setup'),
            -dada_files_loc                     => scalar $q->param('dada_files_loc'),  

        }
    );

	my $ip   = $self->param('install_params');

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'installer_install_dada_mail_scrn.tmpl',
            -with   => 'list',
            -wrapper_params => {
                -Use_Custom => 0,
            },
            -vars   => {

                # These are tricky....
                SUPPORT_FILES_URL => $Self_URL . '?flavor=screen&screen=',

                install_log            => plaintext_to_html( { -str => $log } ),
                status                 => $status,
                install_dada_files_loc => $install_dada_files_loc,
                Dada_Files_Dir_Name    => $Dada_Files_Dir_Name,
                error_cant_edit_config_dot_pm => $errors->{cant_edit_config_dot_pm} || 0,
                Big_Pile_Of_Errors            => $Big_Pile_Of_Errors,
                Trace                         => $Trace,
                PROGRAM_URL                   => program_url_guess(),
                S_PROGRAM_URL                 => program_url_guess(),
                submitted_PROGRAM_URL         => scalar $q->param('program_url'),
                Self_URL                      => $Self_URL,
                scheduled_jobs_flavor         => $sched_flavor,
                curl_location                 => $curl_location,
				
				security_default_file_permissions => $ip->{-security_default_file_permissions}

            }
        }
    );
    $scrn = hack_in_js($scrn);

    # Uh, do are darnest to get the $PROGRAM_URL stuff working correctly,
    $scrn = hack_program_url($scrn);

    return $scrn;

}

sub query_params_to_install_params {

    my $self = shift;
    my $q    = $self->query();

    my $install_dada_files_loc = $self->install_dada_files_dir_at_from_params(
        {
            -install_type                       => scalar $q->param('install_type'),
            -current_dada_files_parent_location => scalar $q->param('current_dada_files_parent_location'),
            -dada_files_dir_setup               => scalar $q->param('dada_files_dir_setup'),
            -dada_files_loc                     => scalar $q->param('dada_files_loc'),  

        }
    );

    my $ip = {};
       $ip->{-install_dada_files_loc} = $install_dada_files_loc;

    my @install_param_names = qw(

      install_type
      current_dada_files_parent_location
      dada_files_dir_setup

      if_dada_files_already_exists

      program_url
      dada_root_pass
      dada_root_pass_again
      original_dada_root_pass
      original_dada_root_pass_is_encrypted
    
      skip_configure_SQL
      support_files_dir_path
      support_files_dir_url
      backend

      sql_server
      sql_port
      sql_database
      sql_username
      sql_password

      install_wysiwyg_editors
      wysiwyg_editor_install_ckeditor
      wysiwyg_editor_install_tiny_mce
      install_file_browser
      core5_filemanager_connector


      dada_pass_use_orig

      configure_deployment
      deployment_running_under

	  configure_perl_env
	  additional_perllibs

      scheduled_jobs_flavor
      configure_scheduled_jobs
      scheduled_jobs_flavor
      scheduled_jobs_log
	  scheduled_jobs_run_at_teardown
	  

      configure_profiles
      profiles_enabled
      profiles_profile_email
      profiles_profile_host_list
      profiles_enable_captcha
      profiles_register
      profiles_password_reset
      profiles_profile_fields
      profiles_mailing_list_subscriptions
      profiles_protected_directories
      profiles_update_email_address
      profiles_change_password
      profiles_delete_profile

      configure_templates
      template_options_enabled
      template_options_mode
      template_options_manual_template_url
      template_options_magic_template_url
      template_options_add_base_href
      template_options_base_href_url
      template_options_replace_content_from
      template_options_replace_id
      template_options_replace_class
      template_options_add_app_css
      template_options_add_custom_css
      template_options_custom_css_url
      template_options_include_jquery_lib
      template_options_include_app_user_js
      template_options_head_content_added_by

      configure_cache
      cache_options_SCREEN_CACHE
      cache_options_DATA_CACHE

      configure_security
      security_no_show_admin_link
      security_DISABLE_OUTSIDE_LOGINS
      security_ADMIN_FLAVOR_NAME
      security_SIGN_IN_FLAVOR_NAME	  
	  security_session_params_check_matching_ip_addresses
	  security_rate_limiting_enabled
	  security_rate_limiting_max_hits
	  security_rate_limiting_timeframe
	  
	  security_default_file_permissions
	  security_default_directory_permissions

	  configure_mime_tools
	  mime_tools_options_tmp_to_core
	  mime_tools_options_tmp_dir
	  
      configure_captcha
      captcha_type
	  captcha_on_subscribe_form
      captcha_reCAPTCHA_public_key
      captcha_reCAPTCHA_private_key
      captcha_reCAPTCHA_Mailhide_public_key
      captcha_reCAPTCHA_Mailhide_private_key

      configure_global_mailing_list_options
      global_mailing_list_options_GLOBAL_UNSUBSCRIBE
      global_mailing_list_options_GLOBAL_BLACK_LIST

      configure_mass_mailing
      mass_mailing_MAILOUT_STALE_AFTER
      mass_mailing_MAILOUT_AT_ONCE_LIMIT

      configure_confirmation_token
      confirmation_token_expires

      configure_s_program_url

      configure_program_name
      program_name_PROGRAM_NAME

      configure_amazon_ses
      amazon_ses_AWS_endpoint
      amazon_ses_AWSAccessKeyId
      amazon_ses_AWSSecretKey
      amazon_ses_Allowed_Sending_Quota_Percentage
    );
	#       s_program_url_S_PROGRAM_URL

    for (@Debug_Option_Names) {
        push( @install_param_names, 'debugging_options_' . $_ );
    }
    for (@Plugin_Names) {
        push( @install_param_names, 'install_' . $_ );
    }
    for ( keys %bounce_handler_plugin_configs ) {
        push( @install_param_names, 'bounce_handler_' . $_ );
    }
    push( @install_param_names, 'bounce_handler_' . 'Address' );
    for (@Extension_Names) {
        push( @install_param_names, 'install_' . $_ );
    }

    for ( keys %bridge_plugin_configs ) {
        push( @install_param_names, 'bridge_' . $_ );
    }


    for (@install_param_names) {
		my $val = $q->param($_) // undef;
        $ip->{ '-' . $_ } = $val;
    }


    $self->param( 'install_params', $ip );

}

sub install_dada_mail {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $log    = undef;
    my $errors = {};
    my $status = 1;

    if ( $ip->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config' ) {
        $log .= "* Backing up current configuration file\n";
        eval { $self->backup_current_config_file(); };
        if ($@) {
            $log .= "* Problems backing up config file: $@\n";
            $errors->{cant_backup_orig_config_file} = 1;
        }
        else {
            $log .= "* Success!\n";
        }
    }

    if ( $ip->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' ) {
        $log .= "* Skipping configuration of directory creation, config file and backend options\n";
    }
    else {
        $log .=
            "* Attempting to make $DADA::Config::PROGRAM_NAME Files at, "
          . $ip->{-install_dada_files_loc} . '/'
          . $Dada_Files_Dir_Name . "\n";

        if ( $ip->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config' ) {
            $log .= "* Skipping directory creation\n";
        }
        else {
            # Making the .dada_files structure
            if ( $self->create_dada_files_dir_structure() == 1 ) {
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
        my $create_dada_config_file = 0; 
        eval { 
            $create_dada_config_file = $self->create_dada_config_file();
        }; 
        if ($@) {
            $log .= "* Problems creating .dada_config file: $@\n";
            $errors->{cant_create_dada_config} = 1;
            $status = 0;
            # $create_dada_config_file = 0;
            return ( $log, $status, $errors );
        }
        else {
            if ($create_dada_config_file  == 1 ) {
                $log .= "* Success!\n";
            }
            else {
                $log .= "* Problems Creating .dada_config file! STOPPING!\n";
                $errors->{cant_create_dada_config} = 1;
                $status = 0;
                return ( $log, $status, $errors );
            }
        }
       

        if ( $ip->{-skip_configure_SQL} == 1 ) {
            $log .= "* Skipping the creation of the SQL Tables...\n";
        }
        else {

            $log .= "* Attempting to create SQL Tables...\n";
            my $sql_ok = $self->create_sql_tables();
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
	
	$log .= "* Clearing Session Data...\n";
	my $sess_ok = $self->clear_sessions();
    if ( $sess_ok == 1 ) {
        $log .= "* Success!\n";
    }
    else {
        $log .= "* Problems removing session data.\n";
    }
	

    # Editing the Config.pm file

    if ( $self->test_can_read_config_dot_pm() == 1 ) {
        $log .= "* WARNING: Cannot read, $Config_LOC!\n";
        $errors->{cant_read_config_dot_pm} = 1;

        # $status = 0; ?
    }

    $log .= "* Attempting to backup original $Config_LOC file...\n";
    eval { $self->backup_config_dot_pm(); };
    if ($@) {
        $Big_Pile_Of_Errors .= $@;
        $log .= "* WARNING: Could not backup, $Config_LOC! (<code>$@</code>)\n";
        $errors->{cant_backup_dada_dot_config} = 1;
    }
    else {
        $log .= "* Success!\n";
    }

    $log .= "* Attempting to edit $Config_LOC file...\n";
    if ( $self->test_can_write_config_dot_pm() == 1 ) {
        $log .= "* WARNING: Cannot write to, $Config_LOC!\n";
        $errors->{cant_edit_config_dot_pm} = 1;

        # $status = 0; ?
    }
    else {

        if ( $self->edit_config_dot_pm() == 1 ) {
            $log .= "* Success!\n";
        }
        else {
            $log .= "* WARNING: Cannot edit $Config_LOC!\n";
            $errors->{cant_edit_dada_dot_config} = 1;
        }

    }
    $log .= "* Setting up Support Files Directory...\n";
    eval { $self->setup_support_files_dir(); };
    if ($@) {
        $log .= "* WARNING: Couldn't set up support files directory! $@\n";
        $errors->{cant_set_up_support_files_directory} = 1;
        $status = 0;

    }
    else {
        $log .= "* Success!\n";
    }

    $log .= "* Installing plugins/extensions...\n";
    eval { $self->edit_config_file_for_plugins(); };
    if ($@) {
        $log .= "* WARNING: Couldn't complete installing plugins/extensions! $@\n";
        $errors->{cant_install_plugins_extensions} = 1;
    }
    else {
        $log .= "* Success!\n";
    }

    if ( $ip->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' ) {
        $log .= "* Skipping WYSIWYG setup...\n";
    }
    else {
        $log .= "* Installing WYSIWYG Editors...\n";
        eval { $self->install_wysiwyg_editors(); };
        if ($@) {
            $log .= "* WARNING: Couldn't complete installing WYSIWYG editors! $@\n";
            $errors->{cant_install_wysiwyg_editors} = 1;
        }
        else {
            $log .= "* Success!\n";
        }
    }

    $log .= "* Setting up CGI/FastCGI/PSGI Deployment...\n";
    eval { $self->setup_deployment(); };
    if ($@) {
        $log .= "* Problems setting up CGI/FastCGI Support: $@\n";
        # $errors->{cant_setup_fast_cgi} = 1;
    }
    else {
        $log .= "* Done!\n";
    }

    $log .= "* Checking for needed CPAN modules to install...\n";
    eval { $self->install_missing_CPAN_modules(); };
    if ($@) {
        $log .= "* Problems installing missing CPAN modules - skipping: $@\n";

        # $errors->{cant_install_plugins_extensions} = 1;
    }
    else {
        $log .= "* Done!\n";
    }

    $log .= "* Removing old Screen Cache...\n";
    eval { $self->remove_old_screen_cache(); };
    if ($@) {
        $log .= "* WARNING: Couldn't remove old screen cache - you may have to do this manually: $@\n";
    }
    else {
        $log .= "* Success!\n";
    }

    # That's it.
    $log .= "* Installation and Configuration Complete!\n";
    return ( $log, $status, $errors );
}

sub remove_old_screen_cache {
    my $self = shift;
    my $ip   = $self->param('install_params');

    my $screen_cache_dir = $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/_screen_cache';

    if ( -d $screen_cache_dir ) {
        my $f;
        opendir( CACHE, make_safer($screen_cache_dir) )
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

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $search  = qr/\$PROGRAM_CONFIG_FILE_DIR \= \'(.*?)\'\;/;
    my $search2 = qr/\$PROGRAM_ERROR_LOG \= (.*?)\;/;

    my $replace_with =
      q{$PROGRAM_CONFIG_FILE_DIR = '} . $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . q{/.configs';};

    my $replace_with2 =
      q{$PROGRAM_ERROR_LOG = '} . $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . q{/.logs/errors.txt';};
    $Config_LOC = make_safer($Config_LOC);

    my $config = slurp($Config_LOC);

    # "auto" usually does the job,
    if ( $ip->{-dada_files_dir_setup} ne 'auto' ) {
        $config =~ s/$search/$replace_with/;
    }

    # (what about the error log? )
    $config =~ s/$search2/$replace_with2/;

    # Why 0777?
    installer_chmod( 0777, make_safer('../DADA') );
    installer_rm($Config_LOC);

    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $Config_LOC
      or warn $!;
    print $config_fh $config or warn $!;
    close $config_fh or warn $!;

    installer_chmod( $DADA::Config::FILE_CHMOD, $Config_LOC );
    installer_chmod( $DADA::Config::DIR_CHMOD,  make_safer('../DADA') );

    return 1;

}

sub backup_config_dot_pm {

    my $self = shift;

    # Why 0777?
    installer_chmod( 0777, '../DADA' );

    my $config     = slurp($Config_LOC);
    my $backup_loc = make_safer( $Config_LOC . '-backup.' . time );
    open my $backup, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $backup_loc
      or croak $!;
    print $backup $config
      or croak $!;
    close $backup
      or croak $!;

    installer_chmod( $DADA::Config::DIR_CHMOD, $backup_loc );
    installer_chmod( $DADA::Config::DIR_CHMOD, '../DADA' );
}

sub backup_current_config_file {

    my $self = shift;
    my $ip   = $self->param('install_params');
    if ( !exists( $ip->{-install_dada_files_loc} ) ) {
        croak "something's wrong: -install_dada_files_loc should be set.";
    }

    my $dot_configs_file_loc =
      make_safer( $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config' );
    my $config_file = slurp($dot_configs_file_loc);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $timestamp = sprintf( "%4d-%02d-%02d", $year + 1900, $mon + 1, $mday ) . '-' . time;
    my $new_loc = make_safer(
        $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config-backup-' . $timestamp );
    open my $config_backup, '>', $new_loc or croak $!;
    print $config_backup $config_file;
    close($config_backup) or croak $!;
    unlink($dot_configs_file_loc);

}

sub create_dada_files_dir_structure {

    my $self = shift;
    my $ip   = $self->param('install_params');
    my $loc  = $ip->{-install_dada_files_loc};

    #warn '$loc ' . $loc; 
    
    # Not sure this is needed, anymore: 
    if ( $loc eq 'auto' ) {
        $loc = $self->auto_dada_files_dir();
    }

    $loc = make_safer( $loc . '/' . $Dada_Files_Dir_Name );

    eval {

        $self->installer_mkdir( $loc, $DADA::Config::DIR_CHMOD );
        $self->create_htaccess_deny_from_all_file($loc);
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
            $self->installer_mkdir( $sub_dir, $DADA::Config::DIR_CHMOD );
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

# DEV: create_dada_config_file uses a lot of vars from $q - not too comfortable with that.

sub create_dada_config_file {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $loc = $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name;

    # eval {
    if ( !-e $loc . '/.configs' ) {
        croak "'" . $loc . '/.configs' . "' does not exist! Stopping!";
    }

    require DADA::Security::Password;
    my $pass;
    if ( $ip->{-dada_pass_use_orig} == 1 ) {
        $pass = $ip->{-original_dada_root_pass};
        if ( $ip->{-original_dada_root_pass_is_encrypted} == 0 ) {
            $pass = DADA::Security::Password::encrypt_passwd($pass);
        }
    }
    else {
        $pass = DADA::Security::Password::encrypt_passwd( $ip->{-dada_root_pass} );
    }

    # Cripes, why wouldn't we pass a program url?
    if ( !exists( $ip->{-program_url} ) ) {
        my $prog_url = $DADA::Config::PROGRAM_URL;
        $prog_url =~ s{installer\/install\.cgi}{mail\.cgi};
        $ip->{-program_url} = $prog_url;
        $self->param( 'install_params', $ip );    # awkward.
    }
    if ( $ip->{-deployment_options_run_under_fastcgi} == 1 ) {
        $ip->{-program_url} =~ s/mail\.cgi$/mail\.fcgi/;
    }
    else {
        $ip->{-program_url} =~ s/mail\.fcgi$/mail\.cgi/;
    }

    my $SQL_params = {};
  
    $SQL_params->{configure_SQL} = 1;

    for (
        qw(
        -sql_server
        -sql_port
        -sql_database
        -sql_username
        -sql_password
        )
      )
    {
        $ip->{$_} = strip( xss_filter( $ip->{$_} ) );
    }

    $SQL_params->{backend}      = $ip->{-backend};
    $SQL_params->{sql_server}   = $ip->{-sql_server};
    $SQL_params->{sql_database} = clean_up_var( $ip->{-sql_database} );
    $SQL_params->{sql_port}     = $self->sql_port_from_params(
									$ip->{-backend}, 
									$ip->{-sql_port},
								  );
    $SQL_params->{sql_username} = clean_up_var( $ip->{-sql_username} );
    $SQL_params->{sql_password} = clean_up_var( $ip->{-sql_password} );


    if ( $ip->{-backend} eq 'SQLite' ) {
        $ip->{-sql_server}   = '';
        $ip->{-sql_database} = 'dadamail';
        $ip->{-sql_port}     = '';
        $ip->{-sql_username} = '';
        $ip->{-sql_password} = '';
    }

    my $scheduled_jobs_params = {};
    if ( $ip->{-scheduled_jobs_flavor} ne '_schedules' ) {
        $ip->{-configure_scheduled_jobs} = 1;
    }
    if ( $ip->{-configure_scheduled_jobs} == 1 ) {
        $scheduled_jobs_params->{configure_scheduled_jobs} = 1;
        $scheduled_jobs_params->{scheduled_jobs_flavor}          = $ip->{-scheduled_jobs_flavor} || '_schedules';
        $scheduled_jobs_params->{scheduled_jobs_log}             = $ip->{-scheduled_jobs_log} || 0;
        $scheduled_jobs_params->{scheduled_jobs_run_at_teardown} = $ip->{-scheduled_jobs_run_at_teardown} || 0;
		
    }
    my $deployment_params = {};
    if ( $ip->{-configure_deployment} == 1 ) {
            $deployment_params->{deployment_running_under} = $ip->{-deployment_running_under} || 'CGI'; 
    }


    my $deployment_params = {};
    if ( $ip->{-configure_deployment} == 1 ) {
            $deployment_params->{deployment_running_under} = $ip->{-deployment_running_under} || 'CGI'; 
    }
	my $perl_env_params = {}; 
    if ( $ip->{-configure_perl_env} == 1 ) {
		$perl_env_params->{configure_perl_env} = 1; 
		$perl_env_params->{additional_perllibs} = $self->ht_vars_perllibs;
	}
  
  
    my $profiles_params = {};
    if ( $ip->{-configure_profiles} == 1 ) {
        $profiles_params->{configure_profiles} = 1;
        for (
            qw(
            enabled
            profile_email
            profile_host_list
            enable_captcha
            login
            register
            password_reset
            profile_fields
            mailing_list_subscriptions
            protected_directories
            update_email_address
            change_password
            delete_profile
            )
          )
        {

            if (   $_ ne 'profile_email'
                && $_ ne 'profile_host_list' )
            {
                $profiles_params->{ 'profiles_' . $_ } = $ip->{ '-profiles_' . $_ } || 0;
            }
            else {
                $profiles_params->{ 'profiles_' . $_ } = $ip->{ '-profiles_' . $_ } || '';
            }
            $profiles_params->{ 'profiles_' . $_ } = clean_up_var( $profiles_params->{ 'profiles_' . $_ } );
        }
    }

    my $plugins_params = {};
    for (@Plugin_Names) {
        if ( $ip->{ '-install_' . $_ } == 1 ) {
            $plugins_params->{ 'install_' . $_ } = 1;
        }
        else {
            $plugins_params->{ 'install_' . $_ } = 0;
        }
    }
    my $extensions_params = {};
    for (@Extension_Names) {
        if ( $ip->{ '-install_' . $_ } == 1 ) {
            $extensions_params->{ 'install_' . $_ } = 1;
        }
        else {
            $extensions_params->{ 'install_' . $_ } = 0;
        }
    }
    
    my $cut_tag_params = {
        cut_list_settings_default => 1,
        cut_plugin_configs        => 1,
    };

    my $template_options_params = {};        
    if ( $ip->{-configure_templates} == 1 ) {
        $template_options_params->{configure_templates} = 1; 
        for (qw( 
            template_options_enabled
            template_options_mode
            template_options_manual_template_url
            template_options_magic_template_url
            template_options_add_base_href
            template_options_base_href_url
            template_options_replace_content_from
            template_options_replace_id
            template_options_replace_class
            template_options_add_app_css
            template_options_add_custom_css
            template_options_custom_css_url
            template_options_include_jquery_lib
            template_options_include_app_user_js
            template_options_head_content_added_by
            )
        ) { 
            $template_options_params->{$_} = $ip->{'-' . $_};
        }
    }

    my $cache_options_params = {};
    if ( $ip->{-configure_cache} == 1 ) {
        $cache_options_params->{configure_cache} = 1;
        if ( clean_up_var( $ip->{-cache_options_SCREEN_CACHE} ) == 1 ) {
            $cache_options_params->{cache_options_SCREEN_CACHE} = 1;
        }
        else {
            $cache_options_params->{cache_options_SCREEN_CACHE} = 2;
        }
        if ( clean_up_var( $ip->{-cache_options_DATA_CACHE} ) == 1 ) {
            $cache_options_params->{cache_options_DATA_CACHE} = 1;
        }
        else {
            $cache_options_params->{cache_options_DATA_CACHE} = 2;
        }
    }

    my $debugging_options_params = {};
    if ( $ip->{-configure_debugging} == 1 ) {
        $debugging_options_params->{configure_debugging} = 1;
        for my $debug_option (@Debug_Option_Names) {
            $debugging_options_params->{ 'debugging_options_' . $debug_option } =
              clean_up_var( $ip->{ '-debugging_options_' . $debug_option } ) || 0;
        }

    }

    my $security_params = {};
    if ( $ip->{-configure_security} == 1 ) {
        $security_params->{configure_security} = 1;
		# Switcheroo
        if ( $ip->{-security_no_show_admin_link} == 1 ) {
            $security_params->{security_SHOW_ADMIN_LINK} = 0;
        }
        else {
            $security_params->{security_SHOW_ADMIN_LINK} = 1;
        }
        $security_params->{security_DISABLE_OUTSIDE_LOGINS} =
          clean_up_var( $ip->{-security_DISABLE_OUTSIDE_LOGINS} );
        if ( length( $ip->{-security_ADMIN_FLAVOR_NAME} ) > 0 ) {
            $security_params->{security_ADMIN_FLAVOR_NAME} = clean_up_var( $ip->{-security_ADMIN_FLAVOR_NAME} );
        }
        if ( length( $ip->{-security_SIGN_IN_FLAVOR_NAME} ) > 0 ) {
            $security_params->{security_SIGN_IN_FLAVOR_NAME} =
              clean_up_var( $ip->{-security_SIGN_IN_FLAVOR_NAME} );
        }
		
        if ( length( $ip->{-security_session_params_check_matching_ip_addresses} ) > 0 ) {
            $security_params->{security_session_params_check_matching_ip_addresses} =
              clean_up_var( $ip->{-security_session_params_check_matching_ip_addresses} );
        }
		
        $security_params->{security_rate_limiting_enabled} = clean_up_var( $ip->{-security_rate_limiting_enabled} ) || 0;
        $security_params->{security_rate_limiting_max_hits} = clean_up_var( $ip->{-security_rate_limiting_max_hits} ) || 0;
        $security_params->{security_rate_limiting_timeframe} = clean_up_var( $ip->{-security_rate_limiting_timeframe} ) || 0;

        $security_params->{security_default_file_permissions}      = '0' . clean_up_var( $ip->{-security_default_file_permissions} ) || undef;
        $security_params->{security_default_directory_permissions} = '0' . clean_up_var( $ip->{-security_default_directory_permissions} ) || undef;
		
    }

    my $captcha_params = {};
    if ( $ip->{-configure_captcha} == 1 ) {
        $captcha_params->{configure_captcha}             = 1;
        $captcha_params->{captcha_type}                  = 'Google_reCAPTCHA';
        $captcha_params->{captcha_on_subscribe_form}     = clean_up_var( $ip->{-captcha_on_subscribe_form} );

		$captcha_params->{captcha_reCAPTCHA_remote_addr} = clean_up_var( $ip->{-captcha_reCAPTCHA_remote_addr} );
        $captcha_params->{captcha_reCAPTCHA_public_key}  = clean_up_var( $ip->{-captcha_reCAPTCHA_public_key} );
        $captcha_params->{captcha_reCAPTCHA_private_key} = clean_up_var( $ip->{-captcha_reCAPTCHA_private_key} );
        $captcha_params->{captcha_reCAPTCHA_Mailhide_public_key} =
          clean_up_var( $ip->{-captcha_reCAPTCHA_Mailhide_public_key} );
        $captcha_params->{captcha_reCAPTCHA_Mailhide_private_key} =
          clean_up_var( $ip->{-captcha_reCAPTCHA_Mailhide_private_key} );
    }
	
	
	my $mime_tools_params = {}; 
	if($ip->{-configure_mime_tools} == 1) { 
        $mime_tools_params->{configure_mime_tools}           = 1;
		$mime_tools_params->{mime_tools_options_tmp_to_core} = $ip->{-mime_tools_options_tmp_to_core};
		$mime_tools_params->{mime_tools_options_tmp_dir}     = $ip->{-mime_tools_options_tmp_dir};
	}
  
    my $global_mailing_list_options = {};
    if ( $ip->{-configure_global_mailing_list_options} == 1 ) {
        $global_mailing_list_options->{configure_global_mailing_list_options} = 1;
        $global_mailing_list_options->{global_mailing_list_options_GLOBAL_UNSUBSCRIBE} =
          strip( $ip->{-global_mailing_list_options_GLOBAL_UNSUBSCRIBE} );
        $global_mailing_list_options->{global_mailing_list_options_GLOBAL_BLACK_LIST} =
          strip( $ip->{-global_mailing_list_options_GLOBAL_BLACK_LIST} );
    }

    my $mass_mailing_params = {};
    if ( $ip->{-configure_mass_mailing} == 1 ) {
        $mass_mailing_params->{configure_mass_mailing} = 1;
        $mass_mailing_params->{mass_mailing_MAILOUT_AT_ONCE_LIMIT} =
          clean_up_var( $ip->{-mass_mailing_MAILOUT_AT_ONCE_LIMIT} );
        $mass_mailing_params->{mass_mailing_MAILOUT_STALE_AFTER} =
          clean_up_var( $ip->{-mass_mailing_MAILOUT_STALE_AFTER} );
    }

    my $confirmation_token_params = {};
    if ( $ip->{-configure_confirmation_token} == 1 ) {
        $confirmation_token_params->{configure_confirmation_token} = 1;
        $confirmation_token_params->{confirmation_token_expires}   = strip( $ip->{-confirmation_token_expires} );
    }

=cut	
    my $s_program_url_params = {};
    if ( $ip->{-configure_s_program_url} == 1 ) {
        $s_program_url_params->{configure_s_program_url} = 1;
        $s_program_url_params->{s_program_url_S_PROGRAM_URL} =
          clean_up_var( strip( $ip->{'-s_program_url_S_PROGRAM_URL'} ) );
    }
=cut
	
    my $program_name_params = {};
    if ( $ip->{-configure_program_name} == 1 ) {
        $program_name_params->{configure_program_name} = 1;
        $program_name_params->{program_name_PROGRAM_NAME} =
          clean_up_var( strip( $ip->{-program_name_PROGRAM_NAME} ) );
    }

    my $amazon_ses_params = {};
    if ( $ip->{-configure_amazon_ses} == 1 ) {
        $amazon_ses_params->{configure_amazon_ses} = 1;
        $amazon_ses_params->{AWS_endpoint}         = strip( $ip->{-amazon_ses_AWS_endpoint} );
        $amazon_ses_params->{AWSAccessKeyId}       = strip( $ip->{-amazon_ses_AWSAccessKeyId} );
        $amazon_ses_params->{AWSSecretKey}         = strip( $ip->{-amazon_ses_AWSSecretKey} );
        $amazon_ses_params->{Allowed_Sending_Quota_Percentage} =
          strip( $ip->{-amazon_ses_Allowed_Sending_Quota_Percentage} );
    }
    my $bounce_handler_params = {};
    if ( $ip->{-install_bounce_handler} == 1 ) {
        $cut_tag_params->{cut_list_settings_default} = 0;
        $cut_tag_params->{cut_plugin_configs}        = 0;
        foreach my $config ( keys %bounce_handler_plugin_configs ) {
            if ( defined( $ip->{ '-bounce_handler_' . $config } ) && $ip->{ '-bounce_handler_' . $config } ne '' ) {
                $bounce_handler_params->{ 'bounce_handler_' . $config } =
                  _sq( strip( $ip->{ '-bounce_handler_' . $config } ) );
            }
            else {
                $bounce_handler_params->{ 'bounce_handler_' . $config } =
                  _sq( $bounce_handler_plugin_configs{$config}->{if_blank} );
            }
        }

        # This one's special:
        $bounce_handler_params->{'bounce_handler_Address'} = strip( $ip->{-bounce_handler_Address} );

    }
    my $bridge_params = {};
    if ( $ip->{-install_bridge} == 1 ) {
        $cut_tag_params->{cut_plugin_configs} = 0;
        foreach my $config ( keys %bridge_plugin_configs ) {
            if ( defined( $ip->{ '-bridge_' . $config } ) && ( $ip->{ '-bridge_' . $config } ne '' ) ) {
                $bridge_params->{ 'bridge_' . $config } = _sq( strip( $ip->{ '-bridge_' . $config } ) );
            }
            else {
                $bridge_params->{ 'bridge_' . $config } = _sq( $bridge_plugin_configs{$config}->{if_blank} );
            }
        }
    }

    #use Data::Dumper;
    #die Dumper($bridge_params);

    my $outside_config_file = DADA::Template::Widgets::screen(
        {
            -screen => 'dada_config.tmpl',
            -vars   => {

                PROGRAM_URL            => $ip->{-program_url},
                ROOT_PASSWORD          => $pass,
                ROOT_PASS_IS_ENCRYPTED => 1,
                dada_files_dir         => $loc,
                support_files_dir_path => $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name,
                support_files_dir_url  => $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name,
                Big_Pile_Of_Errors     => $Big_Pile_Of_Errors,
                Trace                  => $Trace,
                %{$SQL_params},
                %{$cache_options_params},
                %{$debugging_options_params},
                %{$template_options_params},
                %{$scheduled_jobs_params},
                %{$deployment_params},
				%{$perl_env_params},
                %{$plugins_params},
                %{$extensions_params}, 
                %{$profiles_params},
                %{$security_params},
                %{$captcha_params},
				%{$mime_tools_params},
                %{$global_mailing_list_options},
                %{$mass_mailing_params},
                %{$confirmation_token_params},
                %{$program_name_params},
                %{$amazon_ses_params},
                %{$bounce_handler_params},
                %{$bridge_params},
				
            }
        }
    );
	#                %{$s_program_url_params},

    open my $dada_config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      make_safer( $loc . '/.configs/.dada_config' )
      or croak $!;
    print $dada_config_fh $outside_config_file or croak $!;
    close $dada_config_fh or croak $!;

    # };
    # if ($@) {
    #	carp $@;
    #   $Big_Pile_Of_Errors .= $Big_Pile_Of_Errors;
    #		return 0;
    #    }
    #   else {
    #       return 1;
    #   }

}

sub create_sql_tables {
    my $self = shift;
    my $ip   = $self->param('install_params');

    my $sql_file = '';
    if ( $ip->{-backend} eq 'mysql' ) {
        $sql_file = 'mysql_schema.sql';
    }
    elsif ( $ip->{-backend} eq 'Pg' ) {
        $sql_file = 'postgres_schema.sql';
    }
    elsif ( $ip->{-backend} eq 'SQLite' ) {
        $sql_file = 'sqlite_schema.sql';
    }

    eval {

        require DBI;

        my $dbtype   = strip( xss_filter( $ip->{-backend} ) );
        my $dbserver = strip( xss_filter( $ip->{-sql_server} ) );
       # my $port     = strip( xss_filter( $ip->{-sql_port} ) );
	   
       my $port = $self->sql_port_from_params(
	   		$ip->{-backend}, 
			$ip->{-sql_port},
		  );

        my $database = strip( xss_filter( $ip->{-sql_database} ) );
        my $user     = strip( xss_filter( $ip->{-sql_username} ) );
        my $pass     = strip( xss_filter( $ip->{-sql_password} ) );

        my $data_source = '';
        my $dbh         = undef;
        if ( $dbtype eq 'SQLite' ) {
            $data_source = 'dbi:'
              . $dbtype . ':'
              . $ip->{-install_dada_files_loc} . '/'
              . $Dada_Files_Dir_Name
              . '/.lists/'
              . 'dadamail';
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
				
				if($_ =~ m/CREATE INDEX/) {
					# Basically, I don't want this to fail, because 
					# an index couldn't be made. 
	                my $sth = $dbh->prepare($_);
	                $sth->execute
	                  or carp "cannot do statement! $DBI::errstr\n";
				
				}
				else {
					# I DO want this to fail,
					# if a table can't be made.  
	                my $sth = $dbh->prepare($_);
	                $sth->execute
	                  or croak "cannot do statement! $DBI::errstr\n";
				 }
			}
        }

    };
    if ($@) {
        carp $!;
        $Big_Pile_Of_Errors .= $@;
        return 0;
    }
    else {
        return 1;

    }
}



sub clear_sessions {
    my $self = shift;
    my $ip   = $self->param('install_params');
	my $r = undef; 
	
    my $sql_file = '';
    if ( $ip->{-backend} eq 'mysql' ) {
        $sql_file = 'mysql_schema.sql';
    }
    elsif ( $ip->{-backend} eq 'Pg' ) {
        $sql_file = 'postgres_schema.sql';
    }
    elsif ( $ip->{-backend} eq 'SQLite' ) {
        $sql_file = 'sqlite_schema.sql';
    }

	
    eval {

        require DBI;

        my $dbtype   = strip( xss_filter( $ip->{-backend} ) );
        my $dbserver = strip( xss_filter( $ip->{-sql_server} ) );
       # my $port     = strip( xss_filter( $ip->{-sql_port} ) );
	   
       my $port = $self->sql_port_from_params(
	   		$ip->{-backend}, 
			$ip->{-sql_port},
		  );

        my $database = strip( xss_filter( $ip->{-sql_database} ) );
        my $user     = strip( xss_filter( $ip->{-sql_username} ) );
        my $pass     = strip( xss_filter( $ip->{-sql_password} ) );

        my $data_source = '';
        my $dbh         = undef;
        if ( $dbtype eq 'SQLite' ) {
            $data_source = 'dbi:'
              . $dbtype . ':'
              . $ip->{-install_dada_files_loc} . '/'
              . $Dada_Files_Dir_Name
              . '/.lists/'
              . 'dadamail';
            $dbh = DBI->connect( $data_source, "", "" );
        }
        else {
            $data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";
		
			
            $dbh = DBI->connect( "$data_source", $user, $pass );
        }

		my $query = 'TRUNCATE ' . 'dada_sessions'; # <---- HARD CODED!
		
		warn '$query:' . $query; 
		
		my $sth   = $dbh->prepare($query);
		$sth->execute or croak "cannot do statement! $DBI::errstr\n";
		
		my $php_sess_dir = make_safer($ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions');
		if(-d $php_sess_dir){ 
		    my $f;
		    opendir( PHPSESSDIR, $php_sess_dir ) or die $!;
		    while ( defined( $f = readdir PHPSESSDIR ) ) {

		        #don't read '.' or '..'
		        next if $f =~ /^\.\.?$/;
				
		        $f =~ s(^.*/)();
				next unless $f =~ m/^sess/;
				my $n = unlink( make_safer( $php_sess_dir. '/' . $f ) );
		    }
		    closedir(PHPSESSDIR);
		}
    };
    if ($@) {
        carp $!;
        $Big_Pile_Of_Errors .= $@;
        return 0;
    }
    else {
        return 1;

    }
}


sub sql_port_from_params {

    my $self = shift;
    #my $ip   = $self->param('install_params');

	my $backend = shift; 
    my $port    = shift; #$ip->{-sql_port};
	
    if ( $port eq 'auto' ) {
        if ( $backend =~ /mysql/i ) {
            $port = '3306';
        }
        elsif ( $backend =~ /Pg/i ) {
            $port = '5432';
        }
        elsif ( $backend =~ /SQLite/i ) {
            $port = '';
        }
        else {
            # well, we don't change this...
        }
    }
    return $port;
}

sub check_setup {

    my $self = shift;
    my $r = ''; 
    
    my $q  = $self->query;
    my $ip = $self->param('install_params');
    # require Data::Dumper; 
    #warn 'at check_setup: ' .  Data::Dumper::Dumper($ip); 

    my $install_dada_files_loc = undef; 
	if(exists($ip->{-install_dada_files_loc})){ 
		$install_dada_files_loc = $ip->{-install_dada_files_loc};
	}
	else {	
	    $install_dada_files_loc = $self->install_dada_files_dir_at_from_params(
	        {
	            -install_type                       => $ip->{-install_type},
	            -current_dada_files_parent_location => $ip->{-current_dada_files_parent_location},
	            -dada_files_dir_setup               => $ip->{-dada_files_dir_setup},
	            -dada_files_loc                     => $ip->{-dada_files_loc},  

	        }
	    );
		$ip->{-install_dada_files_loc} = $install_dada_files_loc;
	}

    my $errors = {};
    if (
           $ip->{-if_dada_files_already_exists} eq 'skip_configure_dada_files'
        && $self->test_complete_dada_files_dir_structure_exists( $install_dada_files_loc ) ==
        1    # This still has to check out,
      )
    {

        # Skip a lot of the tests!
        # croak "Skipping!";
    }
    else {

        if ( test_str_is_blank( $ip->{-program_url} ) == 1 ) {
            $errors->{program_url_is_blank} = 1;
        }
        else {
            $errors->{program_url_is_blank} = 0;
        }

        if ( $ip->{-dada_pass_use_orig} == 1 ) {

            # Hopefully, original_dada_root_pass has been set.
        }
        else {
            if ( test_str_is_blank( $ip->{-dada_root_pass} ) == 1 ) {
                $errors->{root_pass_is_blank} = 1;

            }
            else {
                $errors->{root_pass_is_blank} = 0;
            }
            if ( test_pass_match( $ip->{-dada_root_pass}, $ip->{-dada_root_pass_again} ) == 1 ) {
                $errors->{pass_no_match} = 1;
            }
            else {
                $errors->{pass_no_match} = 0;
            }
        }

#        $r .= '$ip->{-backend}: ' . $ip->{-backend} . "\n";
        
        if ( $ip->{-backend} eq 'default' || $ip->{-backend} eq '' ) {
            $errors->{sql_connection} = 0;
        }
        else {
            my ( $sql_test, $sql_test_details ) = $self->test_sql_connection(
                $ip->{-backend}, 
                $ip->{-sql_server}, 
                'auto',
                $ip->{-sql_database},
                $ip->{-sql_username},
                $ip->{-sql_password},
            );
            #$r .= '$sql_test_details: ' . $sql_test_details . "\n";
            
            if ( $sql_test == 0 ) {
                $errors->{sql_connection} = 1;

            }
            else {
                $errors->{sql_connection} = 0;

                if (
                    test_database_has_all_needed_tables(
                        $ip->{-backend},      
						$ip->{-sql_server},   
						$self->sql_port_from_params(
							$ip->{-backend}, 
							$ip->{-sql_port},
						),
                        $ip->{-sql_database}, 
						$ip->{-sql_username}, 
						$ip->{-sql_password},
                    ) == 1
                  )
                {
                    if ( $ip->{-install_type} eq 'install' ) {
                        $errors->{sql_table_populated} = 1;
                    }
                    else {
                        # else, no problemo, right?
                        $errors->{sql_table_populated} = 0;
                        $q->param( 'skip_configure_SQL', 1 );    # eeeeeeeh.

                        $ip->{-skip_configure_SQL} = 1;
                        $self->param( 'install_params', $ip );    # updating

                    }
                }
                else {
                    $errors->{sql_table_populated} = 0;
                }

            }
        }
        my $install_dada_files_dir_at = $install_dada_files_loc;
        if ( test_dada_files_dir_no_exists($install_dada_files_dir_at) == 1 ) {
            $errors->{dada_files_dir_exists} = 0;
        }
        else {

            if (
                   $ip->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config'
                && $self->test_complete_dada_files_dir_structure_exists($install_dada_files_loc) ==
                1    # This still has to check out,
              )
            {
                # skip this test, basically,
                $errors->{dada_files_dir_exists} = 0;
            }
            else {
                $errors->{dada_files_dir_exists} = 1;
            }
        }

        if (
               $ip->{-if_dada_files_already_exists} eq 'keep_dir_create_new_config'
            && $self->test_complete_dada_files_dir_structure_exists($install_dada_files_loc) ==
            1    # This still has to check out,
          )
        {

            # Skip.
            $errors->{create_dada_files_dir} = 0;
        }
        else {

            if ( $self->test_can_create_dada_files_dir($install_dada_files_dir_at) == 0 ) {
                $errors->{create_dada_files_dir} = 1;
            }
            else {
                $errors->{create_dada_files_dir} = 0;
            }
        }

        if ( $self->test_can_create_dada_mail_support_files_dir( $ip->{-support_files_dir_path} ) == 0 ) {
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
                && $ip->{-skip_configure_SQL} == 1 )
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
    return ( $status, $errors, $r );

}

sub install_dada_files_dir_at_from_params {

    my $self   = shift;
    my ($args) = @_;
    my $ip     = $self->param('install_params');

    my $r;

    #require Data::Dumper;
    #warn '$args at install_dada_files_dir_at_from_params: ' . Data::Dumper::Dumper($args);

    my $install_dada_files_dir_at = undef;

    if ( $args->{-install_type} eq 'upgrade' ) {
        $install_dada_files_dir_at = $args->{-current_dada_files_parent_location};
    }
    else {
        if ( $args->{-dada_files_dir_setup} eq 'auto' ) {
            $install_dada_files_dir_at = $self->auto_dada_files_dir();
        }
        else {
            $install_dada_files_dir_at = $args->{-dada_files_loc};
        }
    }

    #warn "\n" . '$install_dada_files_dir_at set to:' . $install_dada_files_dir_at;

    # Take off that last slash - goodness, will that annoy me:
    $install_dada_files_dir_at =~ s/\/$//;

    #die $r;
    return $install_dada_files_dir_at;

}

sub edit_config_file_for_plugins {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $dot_configs_file_loc =
      make_safer( $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config' );

    my $config_file = slurp($dot_configs_file_loc);

    # Get those pesky cut tags out of the way...
    $config_file =~ s/$admin_menu_begin_cut//;
    $config_file =~ s/$admin_menu_end_cut//;

    for my $plugins_data (%$plugins_extensions) {
        warn 'working on: ' . $plugins_data; 
        if ( exists( $plugins_extensions->{$plugins_data}->{code} ) ) {
            if ( $ip->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' ) {

                # If we can already find the entry, we'll change the permissions of the
                # plugin/extension
                my $orig_code        = $plugins_extensions->{$plugins_data}->{code};
                my $uncommented_code = quotemeta( uncomment_admin_menu_entry($orig_code) );
                if ( $config_file =~ m/$uncommented_code/ ) {
                    my $installer_successful =
                      installer_chmod( $DADA::Config::DIR_CHMOD,
                        make_safer( $plugins_extensions->{$plugins_data}->{loc} ) );
                }
                else { 
                    
                }   
            }
            else {
                if ( $ip->{ '-install_' . $plugins_data } == 1 ) {
                    my $orig_code        = $plugins_extensions->{$plugins_data}->{code};
                    my $uncommented_code = uncomment_admin_menu_entry($orig_code);
                    $orig_code = quotemeta($orig_code);
                    $config_file =~ s/$orig_code/$uncommented_code/;
                    
                    # we don't need to chmod plugins, anymore: 
                    if($plugins_data =~ m/multiple_subscribe|blog_index/) { 
                        my $installer_successful =
                          installer_chmod( $DADA::Config::DIR_CHMOD,
                            make_safer( $plugins_extensions->{$plugins_data}->{loc} ) );
                    }
                }
            }
        }
    }

    if ( $ip->{-if_dada_files_already_exists} eq 'skip_configure_dada_files' ) {

        # ...
    }
    else {
        # write it back?
        # Why 0777?
        installer_chmod( 0777, $dot_configs_file_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($dot_configs_file_loc)
          or croak $!;
        print $config_fh $config_file or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $dot_configs_file_loc );
    }
    return 1;

}

sub setup_support_files_dir {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $support_files_dir_path = $ip->{-support_files_dir_path};
    if ( !-d $support_files_dir_path ) {
        croak "Can't install set up Support Files Directory: '$support_files_dir_path' does not exist!";
    }
    if ( !-d $support_files_dir_path . '/' . $Support_Files_Dir_Name ) {
        $self->installer_mkdir( make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name ),
            $DADA::Config::DIR_CHMOD );
    }

	if(! -e $support_files_dir_path . '/' . $Support_Files_Dir_Name . '/.htaccess'){ 
		$self->create_htaccess_no_directory_index(
			make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name)
		);			
	}
	if(! -e $support_files_dir_path . '/' . $Support_Files_Dir_Name . '/index.html'){ 
		$self->create_blank_index_file(
			make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name)
		);			
		
	}

    my $install_path = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name;

    my $source_package = make_safer('../static');
    my $target_loc     = make_safer( $install_path . '/static' );
    if ( -d $target_loc ) {
        backup_dir($target_loc);
    }
    installer_dircopy( $source_package, $target_loc );
    unlink( make_safer( $target_loc . '/README.txt' ) );


    my $theme_source_package = make_safer('../extras/packages/themes');
    my $theme_target_loc     = make_safer( $install_path . '/themes' );
    if ( -d $theme_target_loc ) {
        backup_dir($theme_target_loc);
    }
    installer_dircopy( $theme_source_package, $theme_target_loc );
	
	
    unlink( make_safer( $target_loc . '/README.txt' ) );
	
    return 1;
}

sub setup_deployment {

    my $self = shift;
    my $ip   = $self->param('install_params');

    require DADA::Security::Password;
    my $ran_str      = DADA::Security::Password::generate_rand_string() . '.' . time;
    
    my $run = { 
        cgi => {
            enabled   => '../mail.cgi', 
            disabled  => '../mail.cgi-' . $ran_str,
            tmpl      => './templates/mail.cgi.tmpl', 
        }, 
        fastcgi => {
            enabled   => '../mail.fcgi', 
            disabled  => '../mail.fcgi-' . $ran_str,
            tmpl      => './templates/mail.fcgi.tmpl', 
            
        }, 
        psgi    => {
            enabled   => '../app.psgi', 
            disabled  => '../app.psgi-' . $ran_str ,
            tmpl      => './templates/app.psgi.tmpl', 
            
        }, 
    };
    
    # This is basically for everyone: 
    for(qw(cgi fastcgi psgi)) { 
        if ( -e  make_safer($run->{$_}->{enabled}) ) {
            installer_chmod( $DADA::Config::FILE_CHMOD, make_safer($run->{$_}->{enabled}) );
            installer_mv( make_safer($run->{$_}->{enabled}), make_safer($run->{$_}->{disabled}) );
        }
    }

    
    if ( $ip->{-deployment_running_under} eq 'FastCGI' ) {
        installer_cp( make_safer($run->{fastcgi}->{tmpl}), make_safer($run->{fastcgi}->{enabled}) );
        installer_chmod( 0755, make_safer($run->{fastcgi}->{enabled}) );
        
        $self->create_htaccess_fastcgi('../');
        
        return 1;
    }
    elsif($ip->{-deployment_running_under} eq 'PSGI' ) {
        #installer_cp( make_safer($run->{psgi}->{tmpl}), make_safer($run->{psgi}->{enabled}) );
        my $psgi_app  = DADA::Template::Widgets::screen(
            {
                -screen => 'app.psgi.tmpl',
                -vars   => {
                    support_files_dir_path => $ip->{-support_files_dir_path}, 
                    Support_Files_Dir_Name => $Support_Files_Dir_Name, 
                }
            }
        );
        
        open my $app_psgi_script, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($run->{psgi}->{enabled})
            or croak $!;
        print $app_psgi_script $psgi_app or croak $!;
        close $app_psgi_script or croak $!;
        installer_chmod( 0755, make_safer($run->{psgi}->{enabled}) );
        
        return 1;        
    }
    else {
				
		my $additional_perllibs = $self->ht_vars_perllibs;
        my $cgi_app  = DADA::Template::Widgets::screen(
            {
                -screen => 'mail.cgi.tmpl',
                -vars   => {
					additional_perllibs => $additional_perllibs, 
                }
            }
        );
    
        open my $cgi_script, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($run->{cgi}->{enabled})
            or croak $!;
        print $cgi_script $cgi_app or croak $!;
        close $cgi_script or croak $!;
        installer_chmod( 0755, make_safer($run->{cgi}->{enabled}) );
    
        return 1;        
		
   	 }
}

sub install_wysiwyg_editors {

    my $self = shift;
    my $ip   = $self->param('install_params');

    #warn 'install_wysiwyg_editors ' . $ip->{-install_wysiwyg_editors};

    my $install = $ip->{-install_wysiwyg_editors} || 0;

    if ( $install != 1 ) {
        return 1;
    }

    my $dot_configs_file_loc =
      make_safer( $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config' );

    my $config_file = slurp($dot_configs_file_loc);

    my $support_files_dir_path = $ip->{-support_files_dir_path};

    if ( !-d $support_files_dir_path ) {
        croak "Can't install WYSIWYG Editors, Directory, '$support_files_dir_path' does not exist!";
    }

    my %tmpl_vars = ();

    if ( !-d $support_files_dir_path . '/' . $Support_Files_Dir_Name ) {
        $self->installer_mkdir( make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name ),
            $DADA::Config::DIR_CHMOD );
    }

    if ( $ip->{-wysiwyg_editor_install_ckeditor} == 1 ) {
        $self->install_and_configure_ckeditor();
        $tmpl_vars{i_ckeditor_enabled} = 1;
        $tmpl_vars{i_ckeditor_url}     = $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/ckeditor';
    }
    if ( $ip->{-wysiwyg_editor_install_tiny_mce} == 1 ) {
        $self->install_and_configure_tiny_mce();
        $tmpl_vars{i_tiny_mce_enabled} = 1;
        $tmpl_vars{i_tiny_mce_url}     = $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/tinymce';
    }

    if ( $ip->{-install_file_browser} eq 'kcfinder' ) {
        $self->install_and_configure_kcfinder();
        $tmpl_vars{i_kcfinder_enabled} = 1;
        $tmpl_vars{i_kcfinder_url}     = $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/kcfinder';

        my $upload_dir = make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir );
        $tmpl_vars{i_kcfinder_upload_dir} = $upload_dir;
        $tmpl_vars{i_kcfinder_upload_url} =
          $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir;

        $tmpl_vars{i_kcfinder_session_dir} = $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions';

        if ( !-d $upload_dir ) {

            # No need to backup this.
            $self->installer_mkdir( $upload_dir, $DADA::Config::DIR_CHMOD );
            create_htaccess_no_script_execution($upload_dir);
        }
        else {
            if ( !-e $upload_dir . '/.htaccess' ) {
                create_htaccess_no_script_execution($upload_dir);
            }
        }
    }
    elsif ( $ip->{-install_file_browser} eq 'core5_filemanager' ) {
        $self->install_and_configure_core5_filemanager();

        my $upload_dir = make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir );
        $tmpl_vars{i_core5_filemanager_enabled} = 1;
        $tmpl_vars{i_core5_filemanager_url}     = $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/core5_filemanager';
        $tmpl_vars{i_core5_filemanager_connector} = $ip->{-core5_filemanager_connector};
        my $upload_dir = make_safer( $support_files_dir_path . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir );
        $tmpl_vars{i_core5_filemanager_upload_dir} = $upload_dir;
        $tmpl_vars{i_core5_filemanager_upload_url} =
          $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir;

        if ( !-d $upload_dir ) {
            # No need to backup this.
            $self->installer_mkdir( $upload_dir, $DADA::Config::DIR_CHMOD );
        }
    }
    elsif ( $ip->{-install_file_browser} eq 'rich_filemanager' ) {
        $self->install_and_configure_rich_filemanager();

        my $upload_dir = make_safer( 
			$support_files_dir_path 
			. '/' 
			. $Support_Files_Dir_Name 
			. '/' 
			. $File_Upload_Dir
		);
        $tmpl_vars{i_rich_filemanager_enabled} = 1;
        $tmpl_vars{i_rich_filemanager_url}     = 
			$ip->{-support_files_dir_url} 
			. '/' 
			. $Support_Files_Dir_Name 
			. '/RichFilemanager';
			# aways php
		#$tmpl_vars{i_rich_filemanager_connector} = $ip->{-rich_filemanager_connector};
        
        $tmpl_vars{i_rich_filemanager_session_dir} = $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions';
		
		
		my $upload_dir = make_safer( 
			$support_files_dir_path . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir 
		);
        $tmpl_vars{i_rich_filemanager_upload_dir} = $upload_dir;
        $tmpl_vars{i_rich_filemanager_upload_url} =
          $ip->{-support_files_dir_url} 
		  . '/' 
		  . $Support_Files_Dir_Name 
		  . '/' . $File_Upload_Dir;

        if ( !-d $upload_dir ) {
            # No need to backup this.
            $self->installer_mkdir( $upload_dir, $DADA::Config::DIR_CHMOD );
        }
    }
	
	
	

    my $wysiwyg_options_snippet = DADA::Template::Widgets::screen(
        {
            -screen => 'wysiwyg_options_snippet.tmpl',
            -vars   => {%tmpl_vars}
        }
    );

    my $sm = quotemeta('# start cut for WYSIWYG Editor Options');
    my $em = quotemeta('# end cut for WYSIWYG Editor Options');

    $config_file =~ s/($sm)(.*?)($em)/$wysiwyg_options_snippet/sm;

    # write it back?
    installer_chmod( 0777, $dot_configs_file_loc );
    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', make_safer($dot_configs_file_loc)
      or croak $!;
    print $config_fh $config_file or croak $!;
    close $config_fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $dot_configs_file_loc );

    return 1;
}

sub install_missing_CPAN_modules {
	
	my $self = shift; 

    my $has_JSON = 1;
    eval { require JSON; };
    if ($@) {
        $has_JSON = 0;
    }

    if ( $has_JSON == 0 ) {
    
		my $JSON_dir              = make_safer('../DADA/perllib/JSON');
		my $JSON_mv_dir           = make_safer('../DADA/perllib/JSON-move_contents_to_install');
        my $JSON_pm               = make_safer('../DADA/perllib/JSON.pm');
        my $JSON_pm_removed_file  = make_safer('../DADA/perllib/JSON.pm-remove_to_install');


        if ( -d $JSON_dir) {
			
			# This should already be around, 
			if(! -e $JSON_dir) { 
				$self->installer_mkdir( $JSON_dir, $DADA::Config::DIR_CHMOD );
			}
			if(! -e $JSON_mv_dir) { 
				$self->installer_mkdir( $JSON_mv_dir, $DADA::Config::DIR_CHMOD );
			}
			
			for(qw(
					backportPP
					backportPP.pm
					PP
					PP.pm
				)
			) { 
				if(!-e $JSON_dir     . '/' . $_) {
					installer_mv( 
						make_safer($JSON_mv_dir  . '/' . $_), 
						make_safer($JSON_dir     . '/' . $_)
					);
				}
			}
		}
			
		if(! -e $JSON_pm ) { 
            installer_mv( $JSON_pm_removed_file,  $JSON_pm );

            if ( -d $JSON_dir && -e $JSON_pm ) {
                return 1;
            }
            else {
                return;
            }
        }
    }
    else {
        return 1;
    }

}

sub install_and_configure_ckeditor {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $install_path   = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name;
    my $source_package = make_safer('../extras/packages/ckeditor');
    my $target_loc     = make_safer( $install_path . '/ckeditor' );
    if ( -d $target_loc ) {
        backup_dir($target_loc);
    }
    installer_dircopy( $source_package, $target_loc );
    
    # We may not have to do it ourselves, if one of the file managers are also being installed: 
   
    my $create_ckeditor_config_file = 0; 
    if(!exists($ip->{-install_file_browser})){ 
       $create_ckeditor_config_file = 1;  
    }
    elsif(
        $ip->{-install_file_browser} ne 'kcfinder' 
	 && $ip->{-install_file_browser} ne 'rich_filemanager' 
     && $ip->{-install_file_browser} ne 'core5_filemanager'
     ){ 
        $create_ckeditor_config_file = 1;  
    }
    if($create_ckeditor_config_file == 1) { 
        my $ckeditor_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'ckeditor_config_js.tmpl',
                -vars   => {
                    configure_file_browser => 0, 
					PROGRAM_URL            => $ip->{-program_url}, 
					S_PROGRAM_URL          => $ip->{-program_url}, 
                }
            }
        );

        install_write_file(
            $ckeditor_config_js,
            $target_loc . '/dada_mail_config.js',
            $DADA::Config::FILE_CHMOD
            );
    }

}

sub install_and_configure_rich_filemanager { 

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $install_path   = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name;
    my $source_package = make_safer('../extras/packages/RichFilemanager');
    my $target_loc     = make_safer( $install_path . '/RichFilemanager' );
    if ( -d $target_loc ) {
        backup_dir($target_loc);
    }
    installer_dircopy( $source_package, $target_loc );
    my $support_files_dir_url = $ip->{-support_files_dir_url};

    if ( $ip->{-wysiwyg_editor_install_ckeditor} == 1 ) {

        my $support_files_dir_url = $ip->{-support_files_dir_url};

        my $ckeditor_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'ckeditor_config_js.tmpl',
                -vars   => {
                    configure_file_browser  => 1, 
                    file_manager_browse_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/RichFilemanager/index.html',
                    file_manager_upload_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/RichFilemanager/index.html',
                    support_files_dir_url  => $support_files_dir_url,
                    Support_Files_Dir_Name => $Support_Files_Dir_Name,
					
					PROGRAM_URL            => $ip->{-program_url}, 
					S_PROGRAM_URL          => $ip->{-program_url}, 
					
					
                }
            }
        );
        my $ckeditor_config_loc = make_safer( $install_path . '/ckeditor/dada_mail_config.js' );
        installer_chmod( 0777, $ckeditor_config_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $ckeditor_config_loc or croak "$ckeditor_config_loc :" . $!;
        print $config_fh $ckeditor_config_js or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $ckeditor_config_loc );
        undef $config_fh;

    }

    if ( $ip->{-wysiwyg_editor_install_tiny_mce} == 1 ) {

        my $kcfinder_enabled = 0;

        my $support_files_dir_url = $ip->{-support_files_dir_url};

        my $tinymce_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'tinymce_config_js.tmpl',
                -vars   => {
                    file_manager_browse_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/RichFilemanager/index.html',
                    support_files_dir_url     => $support_files_dir_url,
                    Support_Files_Dir_Name    => $Support_Files_Dir_Name,
                    core5_filemanager_enabled => 1,
                }
            }
        );
        my $tinymce_config_loc = make_safer( $install_path . '/tinymce/dada_mail_config.js' );
        installer_chmod( 0777, $tinymce_config_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $tinymce_config_loc or croak $!;
        print $config_fh $tinymce_config_js or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $tinymce_config_loc );
        undef $config_fh;

    }

    my $sess_dir = make_safer( $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions' );
    if ( !-d $sess_dir ) {
        $self->installer_mkdir( $sess_dir, $DADA::Config::DIR_CHMOD );
    }
    

    # pl config:
    my $uploads_directory = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir;
    my $url_path          = $uploads_directory;
    my $doc_root          = $ENV{DOCUMENT_ROOT};

    my $rich_filemanager_connector_config = DADA::Template::Widgets::screen(
        {
            -screen => 'rich_filemanager_connector_config_local.tmpl',
            -vars   => {
                uploads_directory => $uploads_directory,
                url_path          => $url_path,
            }
        }
    );
    my $rich_filemanager_config_loc =
      make_safer( $install_path . '/RichFilemanager/connectors/php/vendor/servocoder/richfilemanager-php/src/config/config.local.php' );
    installer_chmod( 0777, $rich_filemanager_config_loc );
    
	open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $rich_filemanager_config_loc or croak "$rich_filemanager_config_loc :" . $!;
    print $config_fh $rich_filemanager_connector_config or croak $!;
    close $config_fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $rich_filemanager_config_loc );
    undef $config_fh;

    # js config:
    my $rich_filemanager_config_js = DADA::Template::Widgets::screen(
        {
            -screen => 'rich_filemanager_filemanager-config-json.tmpl',
            -vars   => {
                previewUrl => $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir . '/',
               # lang     => $ip->{-core5_filemanager_connector},
            }
        }
    );
    my $rich_filemanager_config_js_loc =
      make_safer( $install_path . '/RichFilemanager/config/filemanager.config.json' );
    installer_chmod( 0777, $rich_filemanager_config_js_loc );
    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $rich_filemanager_config_js_loc or croak "$rich_filemanager_config_js_loc : " . $!;
    print $config_fh $rich_filemanager_config_js or croak $!;
    close $config_fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $rich_filemanager_config_js_loc );
    undef $config_fh;




    # filemanager.php:
    my $rich_filemanager_php = DADA::Template::Widgets::screen(
        {
            -screen => 'rich_filemanager-filemanager-php.tmpl',
            -vars   => {
                i_rich_filemanager_session_dir => $sess_dir,
            }
        }
    );
    my $rich_filemanager_php_loc =
      make_safer(
      	$install_path . '/RichFilemanager/connectors/php/filemanager.php'
      );
	  
	if ( -d $rich_filemanager_php_loc ) {
		backup_dir($rich_filemanager_php_loc);
	}
	  
    installer_chmod( 0777, $rich_filemanager_php_loc );
    open my $rich_filemanager_php_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $rich_filemanager_php_loc 
		or croak $!;
    print $rich_filemanager_php_fh $rich_filemanager_php 
		or croak $!;
    close $rich_filemanager_php_fh 
		or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $rich_filemanager_php_loc );
    undef $rich_filemanager_php_fh;

	
}

sub install_and_configure_tiny_mce {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $install_path   = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name;
    my $source_package = make_safer('../extras/packages/tinymce');
    my $target_loc     = make_safer( $install_path . '/tinymce' );
    if ( -d $target_loc ) {
        backup_dir($target_loc);
    }
    installer_dircopy( $source_package, $target_loc );
    
    
    my $create_tiny_mce_config_file = 0; 
    if(!exists($ip->{-install_file_browser})){ 
       $create_tiny_mce_config_file = 1;  
    }
    elsif(
        $ip->{-install_file_browser} ne 'kcfinder' 
     && $ip->{-install_file_browser} ne 'core5_filemanager'
     ){ 
        $create_tiny_mce_config_file = 1;  
    }
    if($create_tiny_mce_config_file == 1) { 
        my $tinymce_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'tinymce_config_js.tmpl',
                -vars   => {}, # no vars. 
            }
        );
        install_write_file(
            $tinymce_config_js,
            $target_loc . '/dada_mail_config.js',
            $DADA::Config::FILE_CHMOD
            );
    }    
}

sub install_and_configure_kcfinder {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $install_path   = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name;
    my $source_package = make_safer('../extras/packages/kcfinder');
    my $target_loc     = make_safer( $install_path . '/kcfinder' );
    if ( -d $target_loc ) {
        backup_dir($target_loc);
    }
    installer_dircopy( $source_package, $target_loc );

    my $support_files_dir_url = $ip->{-support_files_dir_url};

    if ( $ip->{-wysiwyg_editor_install_ckeditor} == 1 ) {

        # http://docs.cksource.com/CKEditor_3.x/Developers_Guide/Setting_Configurations
        # The best way to set the CKEditor configuration is in-page, when creating editor instances.
        # This method lets you avoid modifying the original distribution files in the CKEditor
        # installation folder, making the upgrade task easier.

        my $support_files_dir_url = $ip->{-support_files_dir_url};

        my $ckeditor_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'ckeditor_config_js.tmpl',
                -vars   => {
                    configure_file_browser => 1, 
                    file_manager_browse_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/kcfinder/browse.php',
                    file_manager_upload_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/kcfinder/upload.php',
                    support_files_dir_url  => $support_files_dir_url,
                    Support_Files_Dir_Name => $Support_Files_Dir_Name,
					
					PROGRAM_URL            => $ip->{-program_url}, 
					S_PROGRAM_URL          => $ip->{-program_url}, 
					
                }
            }
        );
        my $ckeditor_config_loc = make_safer( $install_path . '/ckeditor/dada_mail_config.js' );
        installer_chmod( 0777, $ckeditor_config_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $ckeditor_config_loc or croak $!;
        print $config_fh $ckeditor_config_js or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $ckeditor_config_loc );
        undef $config_fh;

    }

    if ( $ip->{-wysiwyg_editor_install_tiny_mce} == 1 ) {

        my $kcfinder_enabled = 0;

        $kcfinder_enabled = 1;    # we're in a sub called, "isntall_and_configure_kcfinder", so...
                                  #if($q->param('install_file_browser') eq 'kcfinder') {
                                  #	$kcfinder_enabled = 1;
                                  #}

        my $support_files_dir_url = $ip->{-support_files_dir_url};

        my $tinymce_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'tinymce_config_js.tmpl',
                -vars   => {
                    file_manager_browse_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/kcfinder/browse.php',
                    support_files_dir_url  => $support_files_dir_url,
                    Support_Files_Dir_Name => $Support_Files_Dir_Name,
                    kcfinder_enabled       => $kcfinder_enabled,
                }
            }
        );
        my $tinymce_config_loc = make_safer( $install_path . '/tinymce/dada_mail_config.js' );
        installer_chmod( 0777, $tinymce_config_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $tinymce_config_loc or croak $!;
        print $config_fh $tinymce_config_js or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $tinymce_config_loc );
        undef $config_fh;

    }

    my $sess_dir = make_safer( $ip->{-install_dada_files_loc} . '/' . $Dada_Files_Dir_Name . '/.tmp/php_sessions' );
    if ( !-d $sess_dir ) {
        $self->installer_mkdir( $sess_dir, $DADA::Config::DIR_CHMOD );
    }
    my $kcfinder_config_php = DADA::Template::Widgets::screen(
        {
            -screen => 'kcfinder_config_php.tmpl',
            -vars   => {
                i_tinyMCEPath => $ip->{-support_files_dir_url} . '/' . $Support_Files_Dir_Name . '/tinymce',
                i_sessionDir  => $sess_dir,
            }
        }
    );
    my $kcfinder_config_loc = make_safer( $install_path . '/kcfinder/conf/config.php' );
    installer_chmod( 0777, $kcfinder_config_loc );
    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $kcfinder_config_loc or croak $!;
    print $config_fh $kcfinder_config_php or croak $!;
    close $config_fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $kcfinder_config_loc );
    undef $config_fh;

}

sub install_and_configure_core5_filemanager {

    my $self = shift;
    my $ip   = $self->param('install_params');

    my $install_path   = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name;
    my $source_package = make_safer('../extras/packages/core5_filemanager');
    my $target_loc     = make_safer( $install_path . '/core5_filemanager' );
    if ( -d $target_loc ) {
        backup_dir($target_loc);
    }
    installer_dircopy( $source_package, $target_loc );
    my $support_files_dir_url = $ip->{-support_files_dir_url};

    if ( $ip->{-wysiwyg_editor_install_ckeditor} == 1 ) {

        # http://docs.cksource.com/CKEditor_3.x/Developers_Guide/Setting_Configurations
        # The best way to set the CKEditor configuration is in-page, when creating editor instances.
        # This method lets you avoid modifying the original distribution files in the CKEditor
        # installation folder, making the upgrade task easier.

        my $support_files_dir_url = $ip->{-support_files_dir_url};

        my $ckeditor_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'ckeditor_config_js.tmpl',
                -vars   => {
                    configure_file_browser  => 1, 
                    file_manager_browse_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/core5_filemanager/index.html',
                    file_manager_upload_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/core5_filemanager/index.html',
                    support_files_dir_url  => $support_files_dir_url,
                    Support_Files_Dir_Name => $Support_Files_Dir_Name,
                }
            }
        );
        my $ckeditor_config_loc = make_safer( $install_path . '/ckeditor/dada_mail_config.js' );
        installer_chmod( 0777, $ckeditor_config_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $ckeditor_config_loc or croak $!;
        print $config_fh $ckeditor_config_js or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $ckeditor_config_loc );
        undef $config_fh;

    }

    if ( $ip->{-wysiwyg_editor_install_tiny_mce} == 1 ) {

        my $kcfinder_enabled = 0;

        my $support_files_dir_url = $ip->{-support_files_dir_url};

        my $tinymce_config_js = DADA::Template::Widgets::screen(
            {
                -screen => 'tinymce_config_js.tmpl',
                -vars   => {
                    file_manager_browse_url => $support_files_dir_url . '/'
                      . $Support_Files_Dir_Name
                      . '/core5_filemanager/index.html',
                    support_files_dir_url     => $support_files_dir_url,
                    Support_Files_Dir_Name    => $Support_Files_Dir_Name,
                    core5_filemanager_enabled => 1,
                }
            }
        );
        my $tinymce_config_loc = make_safer( $install_path . '/tinymce/dada_mail_config.js' );
        installer_chmod( 0777, $tinymce_config_loc );
        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $tinymce_config_loc or croak $!;
        print $config_fh $tinymce_config_js or croak $!;
        close $config_fh or croak $!;
        installer_chmod( $DADA::Config::FILE_CHMOD, $tinymce_config_loc );
        undef $config_fh;

    }

    # No Session Dir for Core5 Filemanager

    # pl config:

    my $uploads_directory = $ip->{-support_files_dir_path} . '/' . $Support_Files_Dir_Name . '/' . $File_Upload_Dir;
    my $url_path          = $uploads_directory;
    my $doc_root          = $ENV{DOCUMENT_ROOT};
    $url_path =~ s/^$doc_root//;    # We use $url_path for the js config, too.

    my $core5_filemanager_config_pl = DADA::Template::Widgets::screen(
        {
            -screen => 'core5_filemanager_config_pl.tmpl',
            -vars   => {
                uploads_directory => $uploads_directory,
                url_path          => $url_path,
            }
        }
    );
    my $core5_filemanager_config_loc =
      make_safer( $install_path . '/core5_filemanager/connectors/pl/filemanager_config.pl' );
    installer_chmod( 0777, $core5_filemanager_config_loc );
    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $core5_filemanager_config_loc or croak $!;
    print $config_fh $core5_filemanager_config_pl or croak $!;
    close $config_fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $core5_filemanager_config_loc );
    undef $config_fh;
	
	

    # js config:
    my $core5_filemanager_config_js = DADA::Template::Widgets::screen(
        {
            -screen => 'core5_filemanager_config_js.tmpl',
            -vars   => {
                fileRoot => $url_path . '/',                       # slash on the end, there.
                lang     => $ip->{-core5_filemanager_connector},
            }
        }
    );
    my $core5_filemanager_config_js_loc =
      make_safer( $install_path . '/core5_filemanager/scripts/filemanager.config.js' );
    installer_chmod( 0777, $core5_filemanager_config_js_loc );
    open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $core5_filemanager_config_js_loc or croak $!;
    print $config_fh $core5_filemanager_config_js or croak $!;
    close $config_fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $core5_filemanager_config_js_loc );
    undef $config_fh;

    if ( $ip->{-core5_filemanager_connector} eq 'pl' ) {

        my $core5_filemanager_connector_loc =
          make_safer( $install_path . '/core5_filemanager/connectors/pl/filemanager.pl' );

		my $additional_perllibs = $self->ht_vars_perllibs;

		if(scalar(@$additional_perllibs) > 0){ 
		
		
		    my $core5_filemanager_pl = DADA::Template::Widgets::screen(
		        {
		            -screen => 'core5_filemanager-filemanager_pl.tmpl',
		            -vars   => {
						additional_perllibs => $additional_perllibs, 
		            }
		        }
		    );

		    installer_chmod( 0777, $core5_filemanager_connector_loc );
		    open my $core5_filemanager_connector_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $core5_filemanager_connector_loc or croak $!;
		    print $core5_filemanager_connector_fh $core5_filemanager_pl or croak $!;
		    close $core5_filemanager_connector_fh or croak $!;
		    # installer_chmod( $DADA::Config::FILE_CHMOD, $core5_filemanager_connector_loc );
		    undef $config_fh;
			
		}

        installer_chmod( $DADA::Config::DIR_CHMOD, $core5_filemanager_connector_loc );
        installer_chmod( $DADA::Config::DIR_CHMOD, $core5_filemanager_config_loc );

    }


}

sub uncomment_admin_menu_entry {

    my $str = shift;
    $str =~ s/\#//g;
    return $str;

}

sub self_url {

    my $self = shift;
    my $q    = $self->query();

    my $self_url = $q->url;
    if ( $self_url eq 'http://' . $ENV{HTTP_HOST} ) {
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

    my $self = shift;
    return $ENV{DOCUMENT_ROOT};
}

sub support_files_dir_url_guess {
    my $self = shift;
    my $q    = $self->query();
    return $q->url( -base => 1 );
}


sub ht_vars_perllibs { 
	
	    my $self = shift;
	    my $ip   = $self->param('install_params');
		
		my $additional_perllibs = []; 
		
		my @perllibs = split(/\n|\r/, $ip->{-additional_perllibs});
		for(@perllibs){ 
			next unless length($_) > 0; 
			push(
				@{$additional_perllibs}, 
				{
					name => clean_up_var($_)
				}
			);
		}
		
		return $additional_perllibs;
		
}

sub hack_in_js {
    my $scrn = shift;

    my $js = DADA::Template::Widgets::screen(
        {
            -screen => 'installer_extra_javascript_widget.tmpl',
            -vars   => { my_S_PROGRAM_URL => program_url_guess(), Self_URL => $Self_URL }
        }
    );

    my $dm_js = '/static/javascripts/jquery.dadamail.js"></script>';
    my $dm_js_qm = '\/static\/javascripts\/jquery\.dadamail\.js(.*?)\"\>\<\/script\>'; 
    
    $scrn =~ s/$dm_js_qm/$dm_js\n$js/;

    #/ Hackity Hack!

    return $scrn;
}

sub hack_program_url {
    my $scrn            = shift;
    my $bad_program_url = quotemeta('http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi');
    my $better_prog_url = program_url_guess();
    $scrn =~ s/$bad_program_url/$better_prog_url/g;

    return $scrn;

}

sub test_can_create_dada_files_dir {

    my $self                  = shift;
    my $dada_files_parent_dir = shift;

    #warn 'passed: ' . $dada_files_parent_dir; 
    
    # blank?!
    if ( $dada_files_parent_dir eq '' ) {
        return 0;
    }
    my $dada_files_dir = make_safer( $dada_files_parent_dir . '/' . $Dada_Files_Dir_Name );

    if ( $self->installer_mkdir( $dada_files_dir, $DADA::Config::DIR_CHMOD ) ) {
        if ( -e $dada_files_dir ) {
            $self->installer_rmdir($dada_files_dir);
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

    my $self                     = shift;
    my $support_files_parent_dir = shift;

    # blank?!
    if ( $support_files_parent_dir eq '' ) {
        return 0;
    }
    my $support_files_dir = make_safer( $support_files_parent_dir . '/' . $Support_Files_Dir_Name );
    my $already_exists    = 0;

    # That's.. OK, it can exist.
    if ( -e $support_files_dir && -d _ ) {

        # Guess, we'll just skip that one.
        $already_exists = 1;
    }
    else {
        # Let's try making it,
        if ( $self->installer_mkdir( $support_files_dir, $DADA::Config::DIR_CHMOD ) ) {

            # And let's see if it's around,
            if ( -e $support_files_dir && -d _ ) {

                # And, let's see if we can't write into it.

                my $time = time;
                require DADA::Security::Password;
                my $ran_str       = DADA::Security::Password::generate_rand_string();
                my $ran_file_name = make_safer( $support_files_dir . "/test_file.$ran_str.$time.txt" );
                my $file_worked   = 1;

                open( TEST_FILE, ">$ran_file_name" ) or $file_worked = 0;
                print TEST_FILE "test" or $file_worked = 0;
                close(TEST_FILE)       or $file_worked = 0;

                if ( $file_worked == 1 ) {

                    # DEV: And then, perhaps try to get it via HTTP
                    #
                    installer_rm($ran_file_name);
                    if ( $already_exists != 1 ) {
                        $self->installer_rmdir($support_files_dir);
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




sub test_can_use_CAPTCHA_Google_reCAPTCHA {
    eval { require Google::reCAPTCHA; };
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
    if ( -e $dada_files_dir . '/' . $Dada_Files_Dir_Name ) {
        return 0;
    }
    else {

        return 1;
    }
}

sub test_complete_dada_files_dir_structure_exists {

    my $self = shift;

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

    if ( -e $dada_files_dir . '/' . $Dada_Files_Dir_Name . '/.configs/.dada_config' ) {

        # Seems to be all there!
        return 1;
    }

}

sub cgi_test_sql_connection {

    my $self = shift;
    my $q    = $self->query();
    my $r;

    my $dbtype   = strip( xss_filter( scalar $q->param('backend') ) );
    my $dbserver = strip( xss_filter( scalar $q->param('sql_server') ) );
   # my $port     = strip( xss_filter( scalar $q->param('sql_port') ) );
   
   
	my $port     = $self->sql_port_from_params(
								$q->param('backend'),
								$q->param('sql_port'),
							  );
   
    my $database = strip( xss_filter( scalar $q->param('sql_database') ) );
    my $user     = strip( xss_filter( scalar $q->param('sql_username') ) );
    my $pass     = strip( xss_filter( scalar $q->param('sql_password') ) );

    my ( $status, $details ) = $self->test_sql_connection( $dbtype, $dbserver, $port, $database, $user, $pass, );

    if ( $status == 1 ) {
        $r .= '<p>Connection Successful!</p>';
    }
    else {
        $r .= '<p>Connection is NOT Successful. Details:</p>';
        $r .= '<code>' . $details . '</code>';
    }
    return $r;
}

sub cgi_test_pop3_connection {

    my $self = shift;
    my $q    = $self->query();

    my $bounce_handler_server          = $q->param('bounce_handler_Server')                  || undef;
    my $bounce_handler_username        = $q->param('bounce_handler_Username')                || undef;
    my $bounce_handler_password        = $q->param('bounce_handler_Password')                || undef;
    my $bounce_handler_USESSL          = $q->param('bounce_handler_USESSL')                  || 0;
    my $bounce_handler_starttls        = $q->param('bounce_handler_starttls')                || 0;
    my $bounce_handler_SSL_verify_mode = $q->param('bounce_handler_SSL_verify_mode')         || 0; 
	my $bounce_handler_AUTH_MODE       = $q->param('bounce_handler_AUTH_MODE')               || 'POP';
    my $bounce_handler_Port            = $q->param('bounce_handler_Port')                    || 'AUTO';

    #	my $bounce_handler_MessagesAtOnce = $q->param('bounce_handler_MessagesAtOnce') || 100;

    $bounce_handler_server   = make_safer($bounce_handler_server);
    $bounce_handler_username = make_safer($bounce_handler_username);
    $bounce_handler_password = make_safer($bounce_handler_password);

    my ( $pop3_obj, $pop3_status, $pop3_log ) = test_pop3_connection(
        {
            Server          => $bounce_handler_server,
            Username        => $bounce_handler_username,
            Password        => $bounce_handler_password,
            USESSL          => $bounce_handler_USESSL,
			starttls        => $bounce_handler_starttls,
			SSL_verify_mode => $bounce_handler_SSL_verify_mode,
            AUTH_MODE       => $bounce_handler_AUTH_MODE,
            Port            => $bounce_handler_Port,
        }
    );

    #use Data::Dumper;
    #print $q->header('text/plain');
    #print Dumper([$pop3_status, $pop3_log]);

    my $r;

    if ( $pop3_status == 1 ) {
        $r .= '<p>Connection is Successful!</p>';
    }
    else {
        $r .= '<p>Connection is NOT Successful.</p>';
    }
    $r .= '<pre>' . $pop3_log . '</pre>';

    return $r;

}

sub cgi_test_user_template {

    my $self = shift;
    my $q    = $self->query();

    my $template_options_manual_template_url = $q->param('template_options_manual_template_url');
    my $can_get_content                = 0;
    my $can_use_lwp_simple             = DADA::App::Guts::can_use_LWP_Simple;
    my $isa_url                        = isa_url($template_options_manual_template_url);
    if ($isa_url) {
        if ( DADA::Template::HTML::can_grab_url({-url => $template_options_manual_template_url})  == 1) {
            $can_get_content = 1;
        }
    }
    else {
        if ( -e $template_options_manual_template_url ) {
            $can_get_content = 1;
        }
    }

    require DADA::Template::Widgets;
    my $r = DADA::Template::Widgets::screen(
        {
            -screen => 'test_user_template.tmpl',
            -expr   => 1,
            -vars   => {
                template_options_USER_TEMPLATE => $template_options_manual_template_url,
                can_use_lwp_simple             => $can_use_lwp_simple,
                isa_url                        => $isa_url,
                can_get_content                => $can_get_content,
            }
        }
    );
    return $r;

}
sub cgi_test_amazon_ses_configuration {

    my $self = shift;
    my $q    = $self->query();

    my $amazon_ses_AWSAccessKeyId                   = strip( scalar $q->param('amazon_ses_AWSAccessKeyId') );
    my $amazon_ses_AWSSecretKey                     = strip( scalar $q->param('amazon_ses_AWSSecretKey') );
    my $amazon_ses_AWS_endpoint                     = strip( scalar $q->param('amazon_ses_AWS_endpoint') );
    my $amazon_ses_Allowed_Sending_Quota_Percentage = strip( scalar $q->param('amazon_ses_Allowed_Sending_Quota_Percentage') );

    my ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );

    eval {
        require DADA::App::AmazonSES;
        my $ses = DADA::App::AmazonSES->new;
        ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $ses->get_stats(
            {
                AWS_endpoint                     => $amazon_ses_AWS_endpoint,
                AWSAccessKeyId                   => $amazon_ses_AWSAccessKeyId,
                AWSSecretKey                     => $amazon_ses_AWSSecretKey,
                Allowed_Sending_Quota_Percentage => $amazon_ses_Allowed_Sending_Quota_Percentage,
            }
        );
    };

    require DADA::Template::Widgets;
    my $r = DADA::Template::Widgets::screen(
        {
            -screen => 'amazon_ses_get_stats_widget.tmpl',
            -expr   => 1,
            -vars   => {
                using_ses                        => 1,
                has_ses_options                  => 1,
                status                           => $status,
                MaxSendRate                      => $MaxSendRate,
                Max24HourSend                    => $Max24HourSend,
                SentLast24Hours                  => $SentLast24Hours,
                allowed_sending_quota_percentage => $amazon_ses_Allowed_Sending_Quota_Percentage,

            }
        }
    );
    return $r;
}




sub cgi_test_CAPTCHA_Google_reCAPTCHA {

    my $self = shift;
    my $q    = $self->query();

    my $captcha_reCAPTCHA_public_key  = $q->param('captcha_reCAPTCHA_public_key');
    my $captcha_reCAPTCHA_private_key = $q->param('captcha_reCAPTCHA_private_key');


    my $captcha = '';
    my $errors  = undef;
    eval {
        require Google::reCAPTCHA;
        my $c = Google::reCAPTCHA->new(
			secret => $captcha_reCAPTCHA_private_key
		);
    };
    if ($@) {
        $errors = $@;
    }
    my $r;

    require DADA::Template::Widgets;
    $r = DADA::Template::Widgets::screen(
        {
            -screen => 'captcha_google_recaptcha_test_widget.tmpl',
            -expr   => 1,
            -vars   => {
                errors                       => $errors,
                Self_URL                     => $Self_URL,
                captcha                      => $captcha,
                captcha_reCAPTCHA_public_key => $captcha_reCAPTCHA_public_key,
            }
        }
    );

    return $r;

}


sub cgi_test_FastCGI {
    my $self = shift;
    my $q    = $self->query();

    my $errors = undef;

    eval {
        require CGI::Fast;
        my $fastcgi_q = new CGI::Fast;
    };
    if ($@) {
        $errors = $@;
    }
    my $r;

    require DADA::Template::Widgets;
    $r = DADA::Template::Widgets::screen(
        {
            -screen => 'fast_cgi_test_widget.tmpl',
            -expr   => 1,
            -vars   => {
                errors   => $errors,
                Self_URL => $Self_URL,
            }
        }
    );
    return $r;
}

sub cgi_test_captcha_reCAPTCHA_Mailhide {

    my $self = shift;
    my $q    = $self->query();

    my $captcha_reCAPTCHA_Mailhide_public_key  = $q->param('captcha_reCAPTCHA_Mailhide_public_key');
    my $captcha_reCAPTCHA_Mailhide_private_key = $q->param('captcha_reCAPTCHA_Mailhide_private_key');

    my $captcha = '';
    my $errors  = undef;
    eval {
        require Captcha::reCAPTCHA::Mailhide;
        my $c = Captcha::reCAPTCHA::Mailhide->new;
        $captcha = $c->mailhide_html(
            $captcha_reCAPTCHA_Mailhide_public_key,
            $captcha_reCAPTCHA_Mailhide_private_key,
            'test@example.com'
        );
    };
    if ($@) {
        $errors = $@;
    }

    my $r;
    require DADA::Template::Widgets;
    $r = DADA::Template::Widgets::screen(
        {
            -screen => 'captcha_recaptcha_mailhide_test_widget.tmpl',
            -expr   => 1,
            -vars   => {
                errors  => $errors,
                captcha => $captcha,
            }
        }
    );

    return $r;

}

sub cgi_test_magic_template_diag_box {
    my $self = shift; 
    my $q    = $self->query();
    my ($t_status, $t_errors, $t_tmpl) = $self->cgi_test_magic_template(1);
    
    my $ht_errors = [];
    for(%$t_errors){ 
        push(@$ht_errors, {error => $_}); 
    }
    
    require DADA::Template::Widgets;
    my $r = DADA::Template::Widgets::screen(
        {
            -screen => 'test_magic_template.tmpl',
            -expr   => 1,
            -vars   => {
                template_url         => scalar $q->param('template_options_template_url'),
                status               => $t_status, 
                errors               => $ht_errors, 
            }
        }
    );
    return $r;
    
}



sub cgi_test_magic_template {
    my $self = shift;
    my $just_return = shift || 0;

    my $q = $self->query();

    my $template_args = {
        template_url          => scalar $q->param('template_options_template_url'),
        add_base_href         => scalar $q->param('template_options_add_base_href'),
        base_href_url         => scalar $q->param('template_options_base_href_url'),
        replace_content_from  => scalar $q->param('template_options_replace_content_from'),
        replace_id            => scalar $q->param('template_options_replace_id'),
        replace_class         => scalar $q->param('template_options_replace_class'),
        add_app_css           => scalar $q->param('template_options_add_app_css'),
        add_custom_css        => scalar $q->param('template_options_add_custom_css'),
        custom_css_url        => scalar $q->param('template_options_custom_css_url'),
        include_jquery_lib    => scalar $q->param('template_options_include_jquery_lib'),
        include_app_user_js   => scalar $q->param('template_options_include_app_user_js'),
        head_content_added_by => scalar $q->param('template_options_head_content_added_by'),
    };

    require DADA::Template::HTML;
    my ( $t_status, $t_errors, $t_tmpl ) = DADA::Template::HTML::template_from_magic($template_args);

    if ( $just_return == 0 ) {

        my $content = DADA::Template::Widgets::_raw_screen(
            {
                -screen => 'installer-magic_template_content.tmpl',
            }
        );

        return DADA::Template::Widgets::screen(
            {
                -data => \$t_tmpl,
                -vars => {
                    content           => $content,
                    SUPPORT_FILES_URL => $Self_URL . '?flavor=screen&screen=',
                    %{$template_args},

                },
            }
        );
    }
    else {
        return ( $t_status, $t_errors, $t_tmpl );
    }
}

sub test_pop3_connection {

    #	my $self = shift;
    #    my $q    = $self->query();

    my ($args) = @_;
	
	if(length($args->{Server}) <= 1){ # do not understand why this is 1, and not 0 
		return ( undef, 0, 'Mail Server will need to be filled out.');
	}
	if(length($args->{Username}) <= 1){ # do not understand why this is 1, and not 0 
		return ( undef, 0, 'Username will need to be filled out.');
	}
	
    require DADA::App::POP3Tools;
    my ( $pop3_obj, $pop3_status, $pop3_log ) = DADA::App::POP3Tools::net_pop3_login(
        {
            server          => $args->{Server},
            username        => $args->{Username},
            password        => $args->{Password},
            port            => $args->{Port},
            USESSL          => $args->{USESSL},
			starttls        => $args->{starttls},
			SSL_verify_mode => $args->{SSL_verify_mode},
            AUTH_MODE       => $args->{AUTH_MODE},
        }
    );
    if ( defined($pop3_obj) ) {
		$pop3_obj->quit();
    }

    return ( $pop3_obj, $pop3_status, $pop3_log );

}

sub test_sql_connection {

    my $self = shift;

    #	use Data::Dumper;
    #	croak Dumper([@_]);
    my $dbtype   = shift;
    my $dbserver = shift;
    my $port     = shift;
    my $database = shift;
    my $user     = shift;
    my $pass     = shift;

    my $dbtype   = strip( xss_filter( $dbtype ) );
    my $dbserver = strip( xss_filter ($dbserver ) );
    my $port     = strip( xss_filter( $port ) );
    my $database = strip( xss_filter( $database ) );
    my $user     = strip( xss_filter( $user ) );
    my $pass     = strip( xss_filter( $pass ) );

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

    eval { my $dbh = connectdb( $dbtype, $dbserver, $port, $database, $user, $pass, ); };
    if ($@) {
        carp $@;
        $Big_Pile_Of_Errors .= $@;
        return ( 0, $@ );
    }
    else {
        return ( 1, '' );
    }

}

sub test_can_read_config_dot_pm {

    my $self = shift;

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
    my $self = shift;

    if ( -w $Config_LOC ) {
        return 0;
    }
    else {
        return 1;    # Returns 1 if can't. Flag is raised.
    }
}

sub test_database_has_all_needed_tables {

    my $default_table_names = {
        dada_subscribers               => 1,
        dada_profiles                  => 1,
        dada_profile_fields            => 1,
        dada_profile_fields_attributes => 1,
        dada_archives                  => 1,
        dada_settings                  => 1,
        dada_sessions                  => 1,
        dada_bounce_scores             => 1,
        dada_clickthrough_urls         => 1,
        dada_clickthrough_url_log      => 1,
        dada_mass_mailing_event_log    => 1,

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
        $table =~ s/^(.*?)\.//;    #This removes something like, "database_name.table"

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

    # DEV: This HTML should be moved into a template.
    my $self = shift;
    my $q    = $self->query();
    my $r;
	
	my $file_chmod = $q->param('file_chmod');
	if(
		   $file_chmod != 600
		&& $file_chmod != 644 
		&& $file_chmod != 666 
	){ 
		$file_chmod = 644;
	}

    my ( $new_dir_name, $eval_errors ) = $self->move_installer_dir($file_chmod);

    $r .= '
		<fieldset> 
		<legend>
			Move Results
		</legend> 
	';

    my $installer_moved = 0;
    if ( -e '../installer' ) {

        # ...
    }
    elsif ( -e $new_dir_name ) {
        $installer_moved = 1;
    }

    if ( $eval_errors || $installer_moved == 0 ) {
        $r .=
"<p class=\"errors\">Problems! <code>$eval_errors</code></p><p>You'll have to manually move the, <em>dada/<strong>installer</strong></em>  directory.";
    }
    else {
        $r .=
            '<ul><li><p>installer directory moved to <em>'
          . $new_dir_name
          . '</em>,</p></li><li> <p>Installer disabled!</p></li></ul>';
    }
    $r .= "</fieldset>";
    return $r;

}

sub show_current_dada_config {

    my $self = shift;
    my $q    = $self->query();

    my $config_file_loc      = $q->param('config_file');
    my $config_file_contents = DADA::Template::Widgets::_slurp($config_file_loc);
    my $r                    = $config_file_contents;

    $self->header_props( { -type => 'text/plain' } );
    return $r;
}

sub screen {

    my $self = shift;
    my $q    = $self->query();

    my $screen = $q->param('screen');
	my $s_params = { 
		-encoding => 0, 
	};
	
    if ( $screen =~ m/static\/css/ ) {
        $self->header_props( { -type => 'text/css' } );
	}
	elsif ( $screen =~ m/static\/javascripts/ ) {
        $self->header_props( { -type => 'text/javascript' } );
	}
	elsif ( $screen =~ /static\/images/ ) {
        
		if ( $screen =~ /\.png/ ) {
	        $self->header_props( { -type => 'image/png' } );
		}
		elsif ( $screen =~ /\.jpg/ ) {
	        $self->header_props( { -type => 'image/jpg' } );
		}
		elsif ( $screen =~ /\.gif/ ) {
	        $self->header_props( { -type => 'image/gif' } );
		}
		
	}
	

	$screen =~ s/^\///;
    $screen =~ s/\?(.*?)$//; 
	
	my $t = DADA::Template::Widgets::_raw_screen(
        {
            -screen => $screen,
        	%$s_params,
		}
    );
	
	
	return $t; 
		
}

sub move_installer_dir {

    my $self = shift;
	my $file_chmod = shift || 644; 
	if(
		   $file_chmod != 600
		&& $file_chmod != 644 
		&& $file_chmod != 666 
	){ 
		$file_chmod = 644;
	}
	
    my $time = time;
    require DADA::Security::Password;
    my $ran_str      = DADA::Security::Password::generate_rand_string();
    my $new_dir_name = make_safer("../installer-disabled.$ran_str.$time");
    eval {
        #`mv ../installer $new_dir_name`;
        installer_mv( make_safer('../installer'), $new_dir_name );
        installer_chmod( oct("0" . $file_chmod), make_safer('install.cgi') );
    };
    my $errors = undef;
    if ($@) {
        $errors = $@;
    }

    return ( $new_dir_name, $@ );

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

sub install_write_file { 

    my ($str, $fn, $chmod) = @_;

    $fn = make_safer( $fn );

    open my $fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $fn or croak $!;
    print   $fh $str or croak $!;
    close   $fh or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $fn );
    undef   $fh;
    return 1; 
    
}

sub installer_cp {
    require File::Copy;
    my ( $to, $from ) = @_;
    my $r = File::Copy::copy( $to, $from );    # or croak "Copy failed: $!";
    return $r;
}

sub installer_mv {
    require File::Copy;
    my ( $to, $from ) = @_;
    my $r = File::Copy::move( $to, $from ) or croak "Copy failed to:'$to', from:'$from': $!";
    return $r;
}

sub installer_rm {
    my $file  = shift;
    my $count = unlink($file);
    return $count;
}

sub installer_chmod {
	

    my ( $octet, $file ) = @_;

	warn 'installer_chmod $octet:' . $octet . ', $file:'  . $file;




    my $r = chmod( $octet, $file );
    return $r;
}

sub installer_mkdir {

    my $self = shift;

    my ( $dir, $chmod ) = @_;
    my $r = mkdir( $dir, $chmod );
    if(!$r){ 
        warn 'mkdir didn\'t succeed at: ' . $dir . ' because:' . $!; 
    }
    return $r;
}

sub installer_rmdir {
    my $self = shift;
    my $dir  = shift;
    my $r    = rmdir($dir);
    return $r;
}

sub installer_dircopy {
    my ( $source, $target ) = @_;
    require File::Copy::Recursive;
    File::Copy::Recursive::dircopy( $source, $target )
      or die "can't copy directory from, '$source' to, '$target' because: $!";
}

sub backup_dir {
    my $source = shift;
    $source =~ s/\/$//;
    my $target = undef;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $timestamp = sprintf( "%4d-%02d-%02d", $year + 1900, $mon + 1, $mday ) . '-' . time;

    my $target = make_safer( $source . '-backup-' . $timestamp );

    require File::Copy::Recursive;
    File::Copy::Recursive::dirmove( $source, $target )
      or die $!;
}

sub auto_dada_files_dir {
    my $self = shift;
    return $self->guess_home_dir();
}

sub create_htaccess_fastcgi {

    my $self = shift;

    my $loc           = shift;
    my $htaccess_file = make_safer( $loc . '/.htaccess' );
    open my $htaccess, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $htaccess_file or croak $!;
    print $htaccess 'AddHandler fcgid-script .fcgi' . "\n" or croak $!;
    close $htaccess or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $htaccess_file );
}

sub create_htaccess_deny_from_all_file {

    my $self = shift;

    my $loc           = shift;
    my $htaccess_file = make_safer( $loc . '/.htaccess' );
    open my $htaccess, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $htaccess_file or croak $!;
    print $htaccess "deny from all\n" or croak $!;
    close $htaccess or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $htaccess_file );
}

sub create_htaccess_no_script_execution {
    my $loc           = shift;
    my $htaccess_file = make_safer( $loc . '/.htaccess' );
    open my $htaccess, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $htaccess_file or croak $!;
    print $htaccess q|Options -ExecCGI
AddType text/plain .php .phtml .php3 .pl .cgi| or croak $!;
    close $htaccess or croak $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $htaccess_file );
}

sub create_htaccess_no_directory_index {
	
	my $self = shift; 
    my $loc           = shift;
    my $htaccess_file = make_safer( $loc . '/.htaccess' );
    open my $htaccess, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $htaccess_file or warn $!;
    print $htaccess q|Options -Indexes| or warn $!;
    close $htaccess or warn $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $htaccess_file );
	
}

sub create_blank_index_file { 
	my $self = shift; 
    my $loc           = shift;
    my $index_file = make_safer( $loc . '/index.html' );
    open my $index, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $index_file or warn $!;
    print $index '' or warn $!;
    close $index    or warn $!;
    installer_chmod( $DADA::Config::FILE_CHMOD, $index_file );
}

sub guess_home_dir {

    my $self = shift;

    my $home_dir = undef;
    eval { require File::HomeDir; };
    if ($@) {
        $Big_Pile_Of_Errors .= $@;
        carp 'File::HomeDir not installed? ' . $@;
        $home_dir = $self->guess_home_dir_via_getpwuid_call();
    }
    else {
        $home_dir = $self->guess_home_dir_via_FileHomeDir();
        if ( !defined($home_dir) ) {
            $home_dir = $self->guess_home_dir_via_getpwuid_call();
        }
    }

    return $home_dir;
}

sub guess_home_dir_via_FileHomeDir {

    my $self = shift;

    # Needs IPC::Run3 and File::Which and File::Temp -
    # http://deps.cpantesters.org/?module=File%3A%3AHomeDir&perl=5.8.1&os=any+OS

    require File::HomeDir;
    my $home_dir = File::HomeDir->my_data;
    return $home_dir;

}

sub guess_home_dir_via_getpwuid_call {

    my $self = shift;

    # I hate this.
    my $home_dir_guess = undef;
    my $doc_root       = $ENV{DOCUMENT_ROOT};
    my $pub_html_dir   = $doc_root;
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

sub _sq {
    my $str = shift;
    return if $str eq 'undef';    # literally, "undef";

    #    return if $str == 0;
    #    return if $str == 1;
    return $str if $str eq '0';
    return $str if $str eq '1';

    $str =~ s/\'/\\\'./g;
    return "'" . $str . "'";
}

package BootstrapConfig;
no strict;

BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1; }
use DADA::Config;

my $VER;
my $PROGRAM_CONFIG_FILE_DIR = 'auto';
my $OS                      = $^O;
my $CONFIG_FILE;

config_import();

sub config_import {

    $CONFIG_FILE = shift || guess_config_file();

    # Keep this as, 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'
    # What we're doing is, seeing if you've actually changed the variable from
    # it's default, and if not, we take a best guess.

    if ( -e $CONFIG_FILE && -f $CONFIG_FILE && -s $CONFIG_FILE ) {
        open( CONFIG, '<:encoding(UTF-8)', $CONFIG_FILE )
          or warn "could not open outside config file, '$CONFIG_FILE' because: $!";
        my $conf;
        $conf = do { local $/; <CONFIG> };

        # shooting again,
        $conf =~ m/(.*)/ms;
        $conf = $1;
        eval $conf;
        if ($@) {

            # Well, that's gonna suck.
            #die "$PROGRAM_NAME $VER ERROR - Outside config file '$CONFIG_FILE' contains errors:\n\n$@\n\n";
        }

    }
}

sub guess_config_file {
    my $CONFIG_FILE_DIR = undef;

    # $PROGRAM_CONFIG_FILE_DIR

    if ( defined($OS) !~ m/^Win|^MSWin/i ) {
        if (   $DADA::Config::PROGRAM_CONFIG_FILE_DIR ne 'auto'
            && -e $DADA::Config::PROGRAM_CONFIG_FILE_DIR
            && -d $DADA::Config::PROGRAM_CONFIG_FILE_DIR )
        {
            $CONFIG_FILE_DIR = $DADA::Config::PROGRAM_CONFIG_FILE_DIR;
        }
        else {

            my $getpwuid_call;
            my $good_getpwuid;
            eval { $getpwuid_call = ( getpwuid $> )[7]; };
            if ( !$@ ) {
                $good_getpwuid = $getpwuid_call;
            }
            if ( $PROGRAM_CONFIG_FILE_DIR eq 'auto' ) {
                $good_getpwuid =~ s/\/$//;
                $CONFIG_FILE_DIR = $good_getpwuid . '/.dada_files/.configs';
            }
            else {
                $CONFIG_FILE_DIR = $PROGRAM_CONFIG_FILE_DIR;
            }
        }
    }

    $CONFIG_FILE = $CONFIG_FILE_DIR . '/.dada_config';

    # yes, shooting yourself in the foot, RTM
    $CONFIG_FILE =~ /(.*)/;
    $CONFIG_FILE = $1;

    return $CONFIG_FILE;
}

1;
