#!/usr/bin/perl -T
use strict;
$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

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

use CGI;
CGI->nph(1)
  if $DADA::Config::NPH == 1;
my $q;
$q = CGI->new;
$q = decode_cgi_obj($q);

my $Self_URL = $q->url;

use Carp qw(croak carp);
use CGI::Carp qw(fatalsToBrowser);
use DADA::Config 4.0.0;
use DADA::App::Guts;
use DADA::Template::Widgets;

__PACKAGE__->run()
  unless caller();

sub run {
    my %Mode = (

        install_dada        => \&install_dada,
        upgrade_dada        => \&upgrade_dada,
        scrn_dada_files_dir => \&scrn_dada_files_dir,
        check               => \&check,

    );

    my $flavor = $q->param('f');
    if ($flavor) {
        if ( exists( $Mode{$flavor} ) ) {
            $Mode{$flavor}->();    #call the correct subroutine
        }
        else {
            &default;
        }
    }
    else {
        &default;
    }
}

sub default {

    my $tmpl = q{ 
<h1>Welcome to the Dada Mail Installer!</h1> 
		<ul>
		<li>
		<p>
		<a href="<!-- tmpl_var Self_URL -->?f=install_dada">
			This is a NEW installation of Dada Mail!
		</a>
		</p>
		</li> 
		<li>
		<p>
			<a href="<!-- tmpl_var Self_URL -->?f=upgrade_dada">
				I'm upgrading from a previous installation!
			</a>
			
		</p>
		</li>
		</ul>
	
};
    print $q->header();
    print DADA::Template::Widgets::screen( { -data => \$tmpl, } );

}

sub install_dada {
    &scrn_dada_files_dir;
}

sub upgrade_dada {
    print $q->header();
    print "Upgrading Dada Mail!";
}

sub scrn_dada_files_dir {
    my $tmpl = q{ 
		
	<!-- tmpl_if errors --> 
		<h1>
			Thar be errors.
		</h1> 
	<!-- /tmpl_if --> 
	<!-- tmpl_loop errors --> 
		<p>Error <!-- tmpl_var error --> 
	<!-- /tmpl_loop --> 
	<form action="<!-- tmpl_var Self_URL -->" method="post"> 
	<h1>Setup!</h1> 

	<h2>
		Dada Mail Root Password
	</h2> 
	<p>What would you like the Dada Mail Root Password set to? </p> 
	<p><input type="text" name="dada_root_pass" /></p> 
	<p>Again:<br /> 
	<input type="text" name="dada_root_pass_again" /></p> 
	<hr /> 
	
	<h2>
		Dada Mail Directory
	</h2>
	
	<p>Where would you like the Dada Mail Files be installed? (absolute path)</p>
	<p>Save my Dada Mail files at: 
	<br /> 
	<input type="text" name="dada_files_loc" value="<!-- tmpl_var home_dir_guess -->/.dada_files" /> 
	</p> 
	
	<h2>Backend!</h2> 
	
	<p>What type of backend would you like to use?</p>
	<p>
		<select name="backend"> 
			<option value="default">Default Backend</option>
			<option value="mysql">MySQL (recommended)</option> 
			<option value="Pg">PostgreSQL</option> 			
		</select>
	</p>
	
	<h3>SQL Information</h3> 
	<p>Server: <input type="text" name="sql_server" /><br />
	<p>Database: <input type="text" name="sql_database" /><br />
	<p>Username: <input type="text" name="sql_username" /><br />
	<p>Password: <input type="text" name="sql_password" /><br />
	
	<hr />
	<input type="hidden" name="f" value="check" /> 
	
	<input type="submit" value="OK, Go!" /> 
	
	</form> 
	};
    print $q->header();

    my $scrn = DADA::Template::Widgets::screen(
        {
            -data => \$tmpl,
            -vars => {
                home_dir_guess => guess_home_dir(),
                errors         => $q->param('errors') || [],
            },
        }
    );

    # Refil in all the stuff we just had;
    if ( $q->param('errors') ) {
        require HTML::FillInForm::Lite;
        my $h = HTML::FillInForm::Lite->new();
        $scrn = $h->fill( \$scrn, $q );
    }

    print $scrn;

}

sub test_pass_match {

    my $pass        = shift;
    my $retype_pass = shift;

    if ( $pass eq $retype_pass ) {

        #return (1, undef);
        return 1;
    }
    else {

        #return (0, "passwords do not match");
        return 0;
    }
}

sub test_dada_files_dir_no_exists {
    my $dada_files_dir = shift;
    if ( -e $dada_files_dir ) {

        #return (1, undef);
        return 0;
    }
    else {

        #return (0, "directory doesn't exist!");
        return 1;
    }
}

sub can_create_dada_files_dir {

    my $dada_files_dir = shift;
    $dada_files_dir = make_safer($dada_files_dir);

    if ( test_dada_files_dir_no_exists() == 0 ) {
        return 0;

        #return (0, 'directory already exists!');
    }

    # `mkdir $dada_files_dir`;
    if ( mkdir( $dada_files_dir, $DADA::Config::DIR_CHMOD ) ) {
        if ( -e $dada_files_dir ) {
            rmdir($dada_files_dir);
            return 1;
        }
        else {

            return 0;

            #return (0, "$dada_files_dir cannot be created!");
        }
    }
    else {
        return 0;

        #return (0, $!);
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

        # ... well, port is whatever you set it as
    }
    my $data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";

    require DBI;
    if ( DBI->connect( "$data_source", $user, $pass ) ) {

        #	return (1, undef);
        return 1;
    }
    else {

        #return (0, $!);
        return 0;
    }

}

sub check {
    my ( $status, $errors ) = check_setup();
    use Data::Dumper;

    if ( $status == 0 ) {
        my $ht_errors = [];
        foreach ( keys %$errors ) {
            if ( $errors->{$_} == 0 ) {
                push( @$ht_errors, { error => $_ } );
            }
        }
        $q->param( 'errors', $ht_errors );
        scrn_dada_files_dir();
    }
    else {
        print $q->header();
        print "Good to Go!";
    }

}

sub check_setup {
    my $errors = {};

    $errors->{pass_no_match} = test_pass_match( $q->param('dada_root_pass'),
        $q->param('dada_root_pass_again') );

    if ( test_dada_files_dir_no_exists( $q->param('dada_files_loc') ) == 0 ) {
        $errors->{dada_files_dir_exists} = 1;
    }

    $errors->{create_dada_files_dir} =
      can_create_dada_files_dir( $q->param('dada_files_loc') );

    if ( $q->param('backend') eq 'default' ) {
        $errors->{sql_connection} = 1;
    }
    else {
        $errors->{sql_connection} = test_sql_connection(
            $q->param('backend'),      $q->param('sql_server'),
            $q->param('sql_database'), 'auto',
            $q->param('sql_username'), $q->param('sql_password'),
        );
    }

    my $status = 1;
    foreach ( keys %$errors ) {
        if ( $errors->{$_} == 0 ) {
            $status = 0;
            last;
        }
    }
    return ( $status, $errors );

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
        $home_dir_guess =~ s/\/$pub_html_dir$//g;
    }
    return $home_dir_guess;

}
