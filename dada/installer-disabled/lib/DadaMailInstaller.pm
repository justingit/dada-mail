package DadaMailInstaller; 

# Gimme some errors in my browser for debugging
use Carp qw(croak carp);
$Carp::Verbose = 1;
use CGI::Carp qw(fatalsToBrowser);


$|++;
use strict;
use 5.8.1;
use Encode qw(encode decode);
# A weird fix.
BEGIN {
    if ( $] > 5.008 ) {
        require Errno;
        require Config;
    }
}
use lib qw(
  ../
  ../DADA/perllib
);

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

use DADA::Config 4.0.0;
	$DADA::Config::USER_TEMPLATE = '';
	
# An unconfigured Dada Mail won't have these exactly handy to use. 
$DADA::Config::PROGRAM_URL   = program_url_guess();
$DADA::Config::S_PROGRAM_URL = program_url_guess();

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

            install_dada             => \&install_dada,
            scrn_configure_dada_mail => \&scrn_configure_dada_mail,
            check                    => \&check,
            move_installer_dir_ajax  => \&move_installer_dir_ajax,

        );
        my $flavor = $q->param('f');
        if ($flavor) {
            if ( exists( $Mode{$flavor} ) ) {
                $Mode{$flavor}->();    #call the correct subroutine
            }
            else {
                &scrn_configure_dada_mail;
            }
        }
        else {
            &scrn_configure_dada_mail;
        }

    }
}
sub cl_run { 

	require Getopt::Long;
    my %h = ();
    Getopt::Long::GetOptions(
        \%h,
        'skip_configure_dada_files=i',
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

 
	foreach(keys %h){ 
		$q->param($_, $h{$_});
	}
	if($h{help} == 1 || scalar(keys %h) == 0){ 
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
	    foreach(keys %$check_errors){ 
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
	            -program_url                => $q->param('program_url') || '',
	            -dada_root_pass             => $q->param('dada_root_pass') || '',
				-dada_files_dir_setup       => $q->param('dada_files_dir_setup') || 'manual', 
	            -backend                    => $q->param('backend') || 'default',
	            -sql_server                 => $q->param('sql_server') || '',
	            -sql_database               => $q->param('sql_database') || '',
	            -sql_username               => $q->param('sql_username') || '',
	            -sql_password               => $q->param('sql_password') || '',
	
		        -sql_port                   => sql_port_from_params(),
	    
				-install_dada_files_loc     => $install_dada_files_loc, 			
				-skip_configure_SQL         => $q->param('skip_configure_SQL') || 0, 
				-skip_configure_dada_files  => $q->param('skip_configure_dada_files') || 0,
	        }
	    );

		print $install_log . "\n"; 
		if($install_status == 0){ 
			print "Problems with configuration:\n\n"; 
			foreach(keys %$install_errors){ 
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

sub cl_help { 
	
	print DADA::Template::Widgets::screen(
        {
            -screen => 'cl_help_scrn.tmpl',
            -vars => {

            },
        }
    );
	
}



sub scrn_upgrade_dada {
 
	# This.. doesn't do anything. 
    print $q->header();
    print "Upgrading $DADA::Config::PROGRAM_NAME!";
}

sub scrn_configure_dada_mail {
	
	
	# Is there some stuff happenin already? 
	my @lists = DADA::App::Guts::available_lists(-Dont_Die => 1); 
	my $lists_available = 0; 
	if(exists($lists[0])){
		$lists_available = 1; 
	}
	# This is a test to see if the, "auto" placement will work for us - or 
	# for example, there's somethign in the way. 
	# First, let's see if there's any errors: 
	if ( defined( $q->param('errors') )) {
    	# No? Good - 
	}
	else { 
		if(test_can_create_dada_files_dir(auto_dada_files_dir()) == 1 ){ 
			# Failed the test. 
			#$q->param('errors', [{dada_files_dir_exists => 1}]);
			#$q->param('error_dada_files_dir_exists', 1);
			# HTML::FillInForm::Lite will pick up on this 
			$q->param('dada_files_loc', auto_dada_files_dir()); 
			$q->param('dada_files_dir_setup', 'manual');  
		}	
	}
	
	
	
    my $scrn = '';
    $scrn .= list_template(
        -Part  => "header",
        -Title => "Install $DADA::Config::PROGRAM_NAME",
        -vars  => {
            show_profile_widget => 0,
            PROGRAM_URL         => program_url_guess(),
            S_PROGRAM_URL       => program_url_guess(),
        }
    );
    $scrn .= DADA::Template::Widgets::screen(
        {
            -screen => 'installer_configure_dada_mail_scrn.tmpl',
            -vars => {
                program_url_guess              => program_url_guess(),
                can_use_DBI                    => test_can_use_DBI(),
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
                error_program_url_is_blank     =>$q->param('error_program_url_is_blank') || 0,
                error_create_dada_files_dir    => $q->param('error_create_dada_files_dir')  || 0,
                error_dada_files_dir_exists    =>  $q->param('error_dada_files_dir_exists') || 0,
                error_sql_connection           => $q->param('error_sql_connection') || 0,
                error_sql_table_populated      => $q->param('error_sql_table_populated') || 0,
                skip_configure_SQL             => $q->param('skip_configure_SQL') || 0, 
                errors                         => $q->param('errors') || [],
                PROGRAM_URL                    => program_url_guess(),
                S_PROGRAM_URL                  => program_url_guess(),
                Dada_Files_Dir_Name            => $Dada_Files_Dir_Name,
				Big_Pile_Of_Errors             => $Big_Pile_Of_Errors,
				Trace                          => $Trace, 
				lists_available                => $lists_available, 

            },
        }
    );
    $scrn .= list_template( -Part => "footer", );

    # Let's get some fancy js stuff!
    $scrn = hack_in_scriptalicious($scrn);

    # Refill in all the stuff we just had;
    if ( defined($q->param('errors')) ) {
        require HTML::FillInForm::Lite;
        my $h = HTML::FillInForm::Lite->new();
        $scrn = $h->fill( \$scrn, $q );
    }
    e_print($scrn);

}



sub connectdb {
    my $dbtype      = shift;
    my $dbserver    = shift;
    my $port        = shift;
    my $database    = shift;
    my $user        = shift;
    my $pass        = shift;
    my $data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";
    require DBI;
    my $dbh;
    my $that_didnt_work = 1;
    $dbh = DBI->connect( "$data_source", $user, $pass )
      || die("can't connect to db: $!");
    return $dbh;
}

sub check {
    my ( $status, $errors ) = check_setup();

    if ( $status == 0 ) {
        my $ht_errors = [];

        foreach ( keys %$errors ) {
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
			-skip_configure_dada_files  => $q->param('skip_configure_dada_files') || 0,
            -program_url                => $q->param('program_url'),
            -dada_root_pass             => $q->param('dada_root_pass'),
			-dada_files_dir_setup       => $q->param('dada_files_dir_setup'), 
			-install_dada_files_loc     => $install_dada_files_loc, 
            -backend                    => $q->param('backend'),
			-skip_configure_SQL         => $q->param('skip_configure_SQL') || 0, 
            -sql_server                 => $q->param('sql_server'),
            -sql_port                   => sql_port_from_params(),
            -sql_database               => $q->param('sql_database'),
            -sql_username               => $q->param('sql_username'),
            -sql_password               => $q->param('sql_password'),
        }
    );

    my $scrn = '';
    $scrn .= list_template(
        -Part  => "header",
        -Title => "Installing/Configuring $DADA::Config::PROGRAM_NAME",
        -vars  => { show_profile_widget => 0,
	        PROGRAM_URL         => program_url_guess(),
            S_PROGRAM_URL       => program_url_guess(),
 }
    );

  $scrn .= DADA::Template::Widgets::screen(
        {
            -screen => 'installer_install_dada_mail_scrn.tmpl',
            -vars => { 
			 install_log                  => webify_plain_text($log), 
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



    $scrn .= list_template(
        -Part => "footer",
        -vars => { show_profile_widget => 0, }
    );

    $scrn = hack_in_scriptalicious($scrn);

    e_print($scrn);

}

sub install_dada_mail {
    my ($args) = @_;
    my $log    = undef;
    my $errors = {};
    my $status = 1;


	if($args->{-skip_configure_dada_files} == 1){ 
		$log .= "* Skipping configuration of directory creation, config file and backend options\n"; 
	}
	else { 
    	$log .=
	        "* Attempting to make $DADA::Config::PROGRAM_NAME Files at, "
	      . $args->{-install_dada_files_loc} . '/'
	      . $Dada_Files_Dir_Name . "\n";

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
			$log .= "* No need to edit $Config_LOC file - you've set the .dada_files location to, 'auto!'\n";
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

    # That's it.
    $log .= "* Installation and Configuration Complete! Yeah!\n";
    return ( $log, $status, $errors );
}


sub edit_config_dot_pm {
    my $loc          = shift;
    my $search       = quotemeta(q{$PROGRAM_CONFIG_FILE_DIR = 'auto';});
	my $search2      = quotemeta(q{$PROGRAM_ERROR_LOG = undef;});
	
	if($loc eq 'auto') { 
		warn "\$loc has been set to, 'auto' - nothing to edit!"; 
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
			
			#chmod(0777, make_safer('../DADA'));
			installer_chmod(0777, make_safer('../DADA'));
			#unlink($Config_LOC); 
			installer_rm($Config_LOC); 
			
	        open my $config_fh, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $Config_LOC or die $!;
	        print $config_fh $config or die $!;
	        close $config_fh or die $!;
			#chmod(0775, $Config_LOC);
			installer_chmod(0775, $Config_LOC);
			
	    #};

	    #if ($@) {
		#	warn $@; 
		#	$Big_Pile_Of_Errors .= $@; 
	     #   return 0;
	    #}
	    #else {
	        return 1;
	    #}
	}
}

sub backup_config_dot_pm {
	#chmod(0777, '../DADA');
    installer_chmod(0777, '../DADA');
	
	my $config = slurp($Config_LOC);
	my $backup_loc = make_safer($Config_LOC . '-backup.' . time); 
    open my $backup, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $backup_loc or die $!;
    print $backup $config or die $!;
    close $backup or die $!;

	#chmod(0775, $backup_loc);
	installer_chmod(0775, $backup_loc);

}

sub create_dada_files_dir_structure {
    my $loc = shift;
    $loc = auto_dada_files_dir() if $loc eq 'auto';
    $loc = make_safer( $loc . '/' . $Dada_Files_Dir_Name );

    eval {

        installer_mkdir( $loc, $DADA::Config::DIR_CHMOD );
        foreach (
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
        warn $@;
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
        die "$loc does not exist! Stopping!";
    }

    require DADA::Security::Password;
    my $pass =
      DADA::Security::Password::encrypt_passwd( $args->{-dada_root_pass} );

	if(!exists($args->{-program_url})){ 
		
	    my $prog_url = $DADA::Config::PROGRAM_URL;
	    $prog_url =~ s{installer\/install\.cgi}{mail\.cgi};
		$args->{-program_url} = $prog_url;
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
                    sql_database => $args->{-sql_database},
                    sql_port     => $args->{-sql_port},
                    sql_username => $args->{-sql_username},
                    sql_password => $args->{-sql_password},

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
      or die $!;
    print $dada_config_fh $outside_config_file or die $!;
    close $dada_config_fh or die $!;

     };
     if ($@) {
		warn $@; 
        $Big_Pile_Of_Errors .= $Big_Pile_Of_Errors; 
		return 0;
    }
    else {
        return 1;
    }

}

sub create_sql_tables {
    my ($args) = shift;

    my $sql_file = '';
    if ( $args->{-backend} eq 'mysql' ) {
        $sql_file = 'mysql_schema.sql';
    }
    elsif ( $args->{-backend} eq 'Pg' ) {
        $sql_file = 'postgres_schema.sql';
    }

    eval {

    require DBI;

    my $dbtype   = $args->{-backend};
    my $dbserver = $args->{-sql_server};
    my $port     = $args->{-sql_port};
    my $database = $args->{-sql_database};
    my $user     = $args->{-sql_username};
    my $pass     = $args->{-sql_password};

    my $data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";
    my $dbh = DBI->connect( "$data_source", $user, $pass );

    my $schema = slurp( make_safer( '../extras/SQL/' . $sql_file ) );
    my @statements = split( ';', $schema );

    foreach (@statements) {
        if ( length($_) > 10 ) {

            # print "\nquery:\n" . $_;
            my $sth = $dbh->prepare($_);
            $sth->execute
              or die "cannot do statement! $DBI::errstr\n";
        }
    }

    	};
    	if($@){
    		warn $!;
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
        elsif ( $q->param('backend') =~ /pg/i ) {
            $port = 5432;
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
        $q->param('skip_configure_dada_files') == 1
        && test_complete_dada_files_dir_structure_exists(
            install_dada_files_dir_at_from_params()
        ) == 1    # This still has to check out,
      )
    {

        # Skip a lot of the tests!
        # die "Skipping!";
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
                        'auto',                    $q->param('sql_database'),
                        $q->param('sql_username'), $q->param('sql_password'),
                    ) == 1
                  )
                {
                    $errors->{sql_table_populated} = 0;

                }
                else {
                    $errors->{sql_table_populated} = 1;
                }

            }
        }
        my $install_dada_files_dir_at = install_dada_files_dir_at_from_params();
        if ( test_dada_files_dir_no_exists($install_dada_files_dir_at) == 1 ) {
            $errors->{dada_files_dir_exists} = 0;
        }
        else {
            $errors->{dada_files_dir_exists} = 1;
        }

        if ( test_can_create_dada_files_dir($install_dada_files_dir_at) == 1 ) {
            $errors->{create_dada_files_dir} = 1;
        }
        else {
            $errors->{create_dada_files_dir} = 0;
        }

    }

    my $status = 1;
    foreach ( keys %$errors ) {
        if ( $errors->{$_} == 1 ) {

            # I guess there's exceptions to every rule:
            if (   $_ eq 'sql_table_populated'
                && $q->param('skip_configure_SQL') == 1 )
            {

                # Skip!
            }

#	elsif($_ eq 'dada_files_dir_exists' && $q->param('skip_configure_dada_files') == 1){
#		# Skip!
#	}
            else {
                $status = 0;
                last;
            }
        }
    }
   # require Data::Dumper;
    #die Data::Dumper::Dumper( $status, $errors );
    return ( $status, $errors );

}


sub install_dada_files_dir_at_from_params() { 
	 
	my $install_dada_files_dir_at = undef; 
	if($q->param('dada_files_dir_setup') eq 'auto'){ 
		$install_dada_files_dir_at = auto_dada_files_dir(); 
	}
	else { 
		$install_dada_files_dir_at = $q->param('dada_files_loc'); 
	}
	
	# Take off that last slash - goodness, will that annoy me: 
	$install_dada_files_dir_at =~ s/\/$//; 
	return $install_dada_files_dir_at; 

}






sub program_url_guess {
    my $program_url = $Self_URL;
    $program_url =~ s{installer\/install\.cgi}{mail.cgi};
    return $program_url;
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
		warn $@; 
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
        foreach (
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
        elsif ( $dbtype =~ /pg/i ) {
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
		warn $@; 
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
		warn $@; 
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
#	my $dbtype   = shift;
#    my $dbserver = shift;
#    my $port     = shift;
#    my $database = shift;
#    my $user     = shift;
#    my $pass     = shift;
	
	my $default_table_names = {
	    dada_subscribers => 1,
	    dada_profiles => 1, 
	    dada_profile_fields => 1, 
	    dada_profile_fields_attributes => 1,
	    dada_archives => 1, 
	    dada_settings => 1, 
	    dada_sessions => 1, 
	    dada_bounce_scores => 1, 
	    dada_clickthrough_urls => 1,
	}; 
	my $dbh; 
	
    eval { $dbh = connectdb(@_); };
    if ($@) { 
		warn $@; 
		$Big_Pile_Of_Errors .= $@; 
		return 0;
	 }

    my @tables = $dbh->tables;
	my $checks = 0; 
	
	foreach my $table(@tables){ 
		
		# Not sure why this is so non-standard between different setups...
		$table =~ s/`//g; 
		$table =~ s/^(.*?)\.//; #This removes something like, "database_name.table"
		
		if(exists($default_table_names->{$table})){ 
			$checks++;	
		}
	}
	
	
	if($checks == 9){ 
		return 0; 
	}
	else { 
		return 1; 
	}
	
	
	
}
sub test_database_empty {
    my $dbh = undef;

    eval { $dbh = connectdb(@_); };
    if ($@) { 
		warn $@; 
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
      || die "open $file: $!";
    @r = <F>;
    close(F) || die "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}

# The bummer is that I may need to cp this to the uncompress_dada.cgi file - ugh!

sub installer_cp { 
	require File::Copy; 
	my ($to, $from) = @_; 
	my $r = File::Copy::copy($to,$from);# or die "Copy failed: $!";
	return $r; 
}

sub installer_mv { 
	require File::Copy; 
	my ($to, $from) = @_; 
	my $r = File::Copy::move($to,$from);# or die "Copy failed: $!";
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


sub auto_dada_files_dir {
    return guess_home_dir();
}

sub guess_home_dir {
	
	my $home_dir = undef; 
	eval { 
		require File::HomeDir; 
	};
	if($@){ 
		$Big_Pile_Of_Errors .= $@; 
		warn 'File::HomeDir not installed? ' . $@; 
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




1;
