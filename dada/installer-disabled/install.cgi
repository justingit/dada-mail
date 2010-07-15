#!/usr/bin/perl -T
use strict;

# -T flag stuff. 
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

# Gimme some errors in my browser for debugging
use Carp qw(croak carp);
$Carp::Verbose = 1;
use CGI::Carp qw(fatalsToBrowser);


$|++;

package installer;
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
  ..//DADA/perllib
);

# Init my CGI obj. 
use CGI;
CGI->nph(1)
  if $DADA::Config::NPH == 1;
my $q;
$q = CGI->new;
$q = decode_cgi_obj($q);


# These are script-wide variables
# $Self_URL may need ot be set manually - but I'm hoping not. 
# If the script doesn't post properly, go ahead and configure it manually
my $Self_URL            = $q->url;
# You'll normally not want to change this, but I leave it to you to decide
my $Dada_Files_Dir_Name = '.dada_files';
# It irritates me to use a weird, relative path - I may want to try to make this 
# an abs. path via File::Spec (or, whatever) 
my $Config_LOC          = '../DADA/Config.pm';
# Save the errors this creates in a variable
my $Big_Pile_Of_Errors  = undef; 
# Show these errors in the web browser? 
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
	
	# Old-school switcheroo
    my %Mode = (

        install_dada             => \&install_dada,
        scrn_upgrade_dada        => \&scrn_upgrade_dada,
        scrn_configure_dada_mail => \&scrn_configure_dada_mail,
        check                    => \&check,

    );
    my $flavor = $q->param('f');
    if ($flavor) {
        if ( exists( $Mode{$flavor} ) ) {
            $Mode{$flavor}->();    #call the correct subroutine
        }
        else {
            &scrn_default;
        }
    }
    else {
        &scrn_default;
    }
}


sub scrn_default {
	
    my $scrn = '';
    $scrn .= list_template(
        -Part  => "header",
        -Title => "Install/Upgrade $DADA::Config::PROGRAM_NAME",
        -vars  => { show_profile_widget => 0,
	        PROGRAM_URL         => program_url_guess(),
            S_PROGRAM_URL       => program_url_guess(),
 		}
    );
    $scrn .= DADA::Template::Widgets::screen(
		{ 
			-screen => 'installer_default.tmpl',
			-vars => { 
				
				Big_Pile_Of_Errors     => $Big_Pile_Of_Errors,
				Trace                  => $Trace, 
			} } );

    $scrn .= list_template( -Part => "footer", );
    print $scrn;

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
            -screen => 'installer_scrn_configure_dada_mail.tmpl',
            -vars => {
                program_url_guess              => program_url_guess(),
                can_use_DBI                    => test_can_use_DBI(),
                error_cant_read_config_dot_pm  => test_can_read_config_dot_pm(),
                error_cant_write_config_dot_pm => test_can_write_config_dot_pm(),
				dada_files_dir_setup           => $q->param('dada_files_dir_setup'), 
                dada_files_loc                 => $q->param('dada_files_loc'),
			    install_dada_files_dir_at      => install_dada_files_dir_at_from_params(),
                error_root_pass_is_blank       => $q->param('error_root_pass_is_blank')|| 0,
                error_pass_no_match            => $q->param('error_pass_no_match') || 0,
                error_program_url_is_blank     =>$q->param('error_program_url_is_blank') || 0,
                error_create_dada_files_dir    => $q->param('error_create_dada_files_dir')  || 0,
                error_dada_files_dir_exists    =>  $q->param('error_dada_files_dir_exists') || 0,
                error_sql_connection           => $q->param('error_sql_connection') || 0,
                error_sql_table_populated      => $q->param('error_sql_table_populated') || 0,
                home_dir_guess                 => guess_home_dir(),
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
    if ( $q->param('errors') ) {
        require HTML::FillInForm::Lite;
        my $h = HTML::FillInForm::Lite->new();
        $scrn = $h->fill( \$scrn, $q );
    }
    print $scrn;

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
            -program_url            => $q->param('program_url'),
            -dada_root_pass         => $q->param('dada_root_pass'),
            #-dada_files_loc        => $q->param('dada_files_loc'),
			-dada_files_dir_setup   => $q->param('dada_files_dir_setup'), 
			-install_dada_files_loc => $install_dada_files_loc, 
            -backend                => $q->param('backend'),
            -sql_dbtype             => $q->param('backend'),
            -sql_server             => $q->param('sql_server'),
            -sql_port               => sql_port_from_params(),
            -sql_database           => $q->param('sql_database'),
            -sql_username           => $q->param('sql_username'),
            -sql_password           => $q->param('sql_password'),
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
            -screen => 'installer_scrn_install_dada_mail.tmpl',
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
			
	 		}
        }
    );



    $scrn .= list_template(
        -Part => "footer",
        -vars => { show_profile_widget => 0, }
    );

    $scrn = hack_in_scriptalicious($scrn);

    print $scrn;

}

sub install_dada_mail {
    my ($args) = @_;
    my $log    = undef;
    my $errors = {};
    my $status = 1;

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
    if ( $args->{-backend} eq 'default' ) {
        # ...
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
    if ( test_can_write_config_dot_pm() == 0 ) {
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
	    eval {
			$Config_LOC = make_safer($Config_LOC); 
		 
	        my $config = slurp($Config_LOC);
	     
	
		   # I really only have that one thing to edit - 
	       $config =~ s/$search/$replace_with/;
			
			# (what about the error log? ) 
			$config =~ s/$search2/$replace_with2/; 
			
			chmod(0777, make_safer('../DADA'));
			unlink($Config_LOC); 
		
	        open my $config_fh, '>', $Config_LOC or die $!;
	        print $config_fh $config or die $!;
	        close $config_fh or die $!;
			chmod(0775, $Config_LOC);

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
}

sub backup_config_dot_pm {
	chmod(0777, '../DADA');
    my $config = slurp($Config_LOC);
	my $backup_loc = make_safer($Config_LOC . '-backup.' . time); 
    open my $backup, '>', $backup_loc or die $!;
    print $backup $config or die $!;
    close $backup or die $!;

	chmod(0775, $backup_loc);

}

sub create_dada_files_dir_structure {
    my $loc = shift;
    $loc = auto_dada_files_dir() if $loc eq 'auto';
    $loc = make_safer( $loc . '/' . $Dada_Files_Dir_Name );

    eval {

        mkdir( $loc, $DADA::Config::DIR_CHMOD );
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
            mkdir( $sub_dir, $DADA::Config::DIR_CHMOD );
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

    my $prog_url = $DADA::Config::PROGRAM_URL;
    $prog_url =~ s{installer\/install\.cgi}{mail\.cgi};

    my $outside_config_file = DADA::Template::Widgets::screen(
        {
            -screen => 'example_dada_config.tmpl',
            -vars   => {

                PROGRAM_URL            => $prog_url,
                ROOT_PASSWORD          => $pass,
                ROOT_PASS_IS_ENCRYPTED => 1,
                dada_files_dir         => $loc,
				Big_Pile_Of_Errors     => $Big_Pile_Of_Errors, 
				Trace                  => $Trace, 
                ( $args->{-backend} ne 'default' )
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
    if ( $args->{-backend} eq 'default' ) {

        # ...
    }
    else {
        $outside_config_file =~ s/$sql_begin_cut//;
        $outside_config_file =~ s/$sql_end_cut//;
    }

    open my $dada_config_fh, '>', make_safer( $loc . '/.configs/.dada_config' )
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
        test_pass_match( $q->param('dada_root_pass'),
            $q->param('dada_root_pass_again') ) == 1
      )
    {
        $errors->{pass_no_match} = 1;
    }
    else {
        $errors->{pass_no_match} = 0;
    }


	my $install_dada_files_dir_at = install_dada_files_dir_at_from_params(); 
	if ( test_dada_files_dir_no_exists($install_dada_files_dir_at) == 1 ) {
		$errors->{dada_files_dir_exists} = 0;
	}
	else  {
		$errors->{dada_files_dir_exists} = 1;
	}

    if ( test_can_create_dada_files_dir($install_dada_files_dir_at) == 1 ) {
        $errors->{create_dada_files_dir} = 1;
    }
    else {
        $errors->{create_dada_files_dir} = 0;
    }
    if ( $q->param('backend') eq 'default' ) {
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
                test_database_empty(
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

    my $status = 1;
    foreach ( keys %$errors ) {
        if ( $errors->{$_} == 1 ) {
            $status = 0;
            last;
        }
    }
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
	return $install_dada_files_dir_at; 

}





sub auto_dada_files_dir {
    return guess_home_dir();
}

sub guess_home_dir {

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

sub program_url_guess {
    my $program_url = $Self_URL;
    $program_url =~ s/install\/installer\.cgi/mail.cgi/;
    return $program_url;
}

sub hack_in_scriptalicious {
    my $scrn = shift;
    my $js = DADA::Template::Widgets::screen(
        {
            -screen => 'installer_extra_javascript.tmpl',
            -vars => { my_S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL }
        }
    );
    $scrn =~ s/\<head\>/\<head\>$js/;

    #/ Hackity Hack!

    return $scrn;
}



sub test_can_create_dada_files_dir {

    my $dada_files_dir = shift;
    $dada_files_dir =
      make_safer( $dada_files_dir . '/' . $Dada_Files_Dir_Name );

    if ( mkdir( $dada_files_dir, $DADA::Config::DIR_CHMOD ) ) {
        if ( -e $dada_files_dir ) {
            rmdir($dada_files_dir);
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
    my $problem = 0;
    eval {
        open my $backup, '>>', $Config_LOC or $problem == 1;
        if($problem != 0){ 
			#close $backup or die $!;
    	}
	};
    if ($@) {
        warn $@;
        $Big_Pile_Of_Errors .= $@; 
		return 1;
    }
    return $problem;
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

