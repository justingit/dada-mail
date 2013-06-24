#!/usr/bin/perl
package global_config_helper;
use strict;

use File::Copy; 

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";
BEGIN { 
	my $b__dir = ( getpwuid($>) )[7].'/perl';
    push @INC,$b__dir.'5/lib/perl5',$b__dir.'5/lib/perl5/x86_64-linux-thread-multi',$b__dir.'lib',map { $b__dir . $_ } @INC;
}

# use some of those Modules
use DADA::Config 6.0.0;
use DADA::Template::HTML;
use DADA::App::Guts;
use DADA::MailingList::Settings;

# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);
use CGI::Carp qw(fatalsToBrowser);

run()
  unless caller();

sub run { 
	cgi_main(); 
}

my $admin_list; 
my $root_login; 
my $list; 

sub cgi_main {

    ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'bounce_handler'
    );

    $list = $admin_list;

    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get();

    my $flavor = $q->param('f') || 'cgi_default';
    my %Mode = (

        'cgi_default'                => \&cgi_default,
'reconfigure'                => \&reconfigure, 

    );

    if ( exists( $Mode{$flavor} ) ) {
        $Mode{$flavor}->();    #call the correct subroutine
    }
    else {
        &cgi_default;
    }
}



sub cgi_default {

    # This will take care of all out security woes
    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'global_config_helper'
    );
    my $list = $admin_list;

    # get the list information
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    my $data = '';
    if ( !$q->param('process') ) {

	    require DADA::Template::Widgets;
	    my $scrn = DADA::Template::Widgets::wrap_screen(
	        {
	            -screen         => 'plugins/global_config_helper/default.tmpl',
	            -with           => 'admin',
	            -expr           => 1,
	            -wrapper_params => {
	                -Root_Login => $root_login,
	                -List       => $list,
	            },
	            -vars => {

	            },
	            -list_settings_vars_param => {
	                -list   => $list,
	                -dot_it => 1,
	            },
	        }
	    );
	    e_print($scrn);


    }
}

sub reconfigure { 
	print $q->header(); 
	print '<pre>'; 
	print "reconfiguring!\n\n"; 

	my $installer_dir; 
	if($installer_dir = installer_dir()) { 
		print "Found installer dir at $installer_dir\n";
	}
	else { 
		print "no such luck.\n"; 
		return; 
	}
	
	if(move_installer_dir_back($installer_dir) == 1){ 
		print "Moved installer dir back!\n"; 
	}
	else { 
		print "couldn't move installer dir back!\n"; 
		return; 
	}
	
	if(chmod_installer_script()) { 
		print "chmod'd 755 installer script!"; 
	}
	else { 
		print "couldn't chmod back installer script!\n"; 
		return; 	
	}
	
	my $installer_url = installer_url(); 
	
	print '</pre>'; 
	
	print '<p><a href="' . $installer_url . '">Reconfigure!</a></p>';  
	
	return; 
}

sub installer_dir { 
	# installer-disabled.
	  #  my $dirs = []; 
		my $looking_for = qr/^installer\-disabled\./; 
		my $dada_dir = $FindBin::Bin . '/../';
		my $f;
	    opendir( DADADIR, $dada_dir )
	      or croak
	"$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open '" . $dada_dir . "' to read because: $!";
	
	    while ( defined( $f = readdir DADADIR ) ) {
		#	print $q->p($f); 
			
	        ##don't read '.' or '..'
	        next if $f =~ /^\.\.?$/;
			#
	        $f =~ s(^.*/)();
	
			next unless -d $dada_dir . '/' . $f; 
	
			if($f =~ m/$looking_for/) { 
			#	push(@$dirs, $f); 
				return $f; 
			}
	    }

	    closedir(DADADIR);
}

sub move_installer_dir_back { 
	my $installer_dir = shift; 
	my $current_installer_dir_abs = make_safer($FindBin::Bin . '/../' . $installer_dir); 
	my $future_installer_dir_abs  = make_safer($FindBin::Bin . '/../' . 'installer'); 
	if(move($current_installer_dir_abs, $future_installer_dir_abs)) { 
		return 1; 
	}
	else { 
		return undef; 
	}
}

sub chmod_installer_script { 
	my $install_script  = make_safer($FindBin::Bin . '/../' . 'installer/install.cgi'); 
	
	if(chmod(0755, $install_script)) { 
		return 1; 
	}
	else { 
		return undef; 
	}
}

sub installer_url { 
	my $installer_url = $DADA::Config::PROGRAM_URL; 
       $installer_url =~ s{mail\.cgi}{installer\/install\.cgi};
	$installer_url .= '?install_type=upgrade&f=check_install_or_upgrade&current_dada_files_parent_location=' 
					. uriescape(current_dada_files_parent_loc()); 	
	return $installer_url; 
}

sub current_dada_files_parent_loc { 
	my $config_dir = $DADA::Config::PROGRAM_CONFIG_FILE_DIR;
	   $config_dir =~ s{\/.dada_files/\.configs$}{}; 
	return $config_dir; 
}
