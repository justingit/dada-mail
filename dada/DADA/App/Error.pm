package DADA::App::Error;


=pod

=head1 NAME 

DADA::App::Error

=head1 SYNOPSIS

	use DADA::App::Error

This module basically has error messages in HTML and spits 'em back at ya.

=cut


use lib qw(../../ ../perllib); 

use DADA::Config;  
use DADA::App::Guts; 
use DADA::Template::HTML;

require Exporter; 
@ISA = qw(Exporter); 
@EXPORT = qw(cgi_user_error);
use strict; 
use vars qw(@EXPORT);
my %error;

require CGI;
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);

	
my $Referer = uriescape($q->referer); 


if(($DADA::Config::PROGRAM_URL eq "") || ($DADA::Config::PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi')){ 
			$DADA::Config::PROGRAM_URL =  $ENV{SCRIPT_URI} || $q->url();
			
}			

if(($DADA::Config::S_PROGRAM_URL eq "") || ($DADA::Config::S_PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi')){ 
			$DADA::Config::S_PROGRAM_URL =  $ENV{SCRIPT_URI} || $q->url();
}


=pod

=head1 SUBROUTINES

=head2 cgi_user_error

 print cgi_user_error(-List  => 'my_list', 
                      -Error => 'some_error', 
                      -Email => 'some@email.com'); 

Gives back an HTML friendly error message.

=cut


sub cgi_user_error { 
	my %args = (
		-List             => undef, 
     	-Error            => undef, 
   		-Email            => undef, 
		-Error_Message    => undef, 
		-Wrapper_Template => 'list', 
   		@_
	);

	require DADA::Template::Widgets; 
	
	my  $available_lists_ref; 
	my $li              = {}; 
	my $list_login_form = ""; 
	my $list_exists     = 0; 
	
	if($args{-Error} !~ /unreadable_db_files|sql_connect_error|bad_setup/){
		$list_exists = check_if_list_exists( -List=> $args{-List}, -Dont_Die  => 1) || 0;
	}
	
	if($list_exists > 0) { 
		require  DADA::MailingList::Settings; 
		my $ls = DADA::MailingList::Settings->new({-list => $args{-List}}); 
		   $li = $ls->get(); 
	}
	
	# What a weird idea...
	my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
	my $auth_code = DADA::App::Guts::make_pin(-Email => $month . '.' . $day . '.' . $args{-Email}, -List => $args{-List}, );

	if($args{-Error} !~ /unreadable_db_files|sql_connect_error|bad_setup/){
		if($DADA::Config::LOGIN_WIDGET eq 'popup_menu'){ 
			$list_login_form =  DADA::Template::Widgets::list_popup_login_form();
		} 
		elsif($DADA::Config::LOGIN_WIDGET eq 'text_box') { 
			$list_login_form = DADA::Template::Widgets::screen({-screen => 'text_box_login_form.tmpl', -expr => 1});	
		}
		else{ 
			warn "'$DADA::Config::LOGIN_WIDGET' misconfigured!"
		}
	}

	my $subscription_form; 
    my $unsubscription_form;
    
	if($args{-Error} !~ /unreadable_db_files|sql_connect_error|bad_setup|bad_SQL_setup|install_dir_still_around/){
		
   	 if($args{-List}){ 
			$subscription_form    = DADA::Template::Widgets::subscription_form({ -list => $args{-List}, -email => $args{-Email}, -give_props => 0 }); 
	    	$unsubscription_form  = DADA::Template::Widgets::subscription_form({ -list => $args{-List}, -email => $args{-Email}, -flavor_is => 'u', -give_props => 0} ); 
	    }else{ 
	    	$subscription_form   = DADA::Template::Widgets::subscription_form({-email => $args{-Email}, -give_props => 0}); # -show_hidden =>1 ?!?!?!
	    	$unsubscription_form = DADA::Template::Widgets::subscription_form({-email => $args{-Email}, -flavor_is => 'u', -give_props => 0}); # -show_hidden => 1?!?!?!
	    }
	}

	my $unknown_dirs = []; 
	if($args{-Error} eq 'bad_setup'){ 
		my @tests = ($DADA::Config::FILES, $DADA::Config::TEMPLATES , $DADA::Config::TMP );
		
		# Your guess is as good as mine for what this was all about... 
		#if($DADA::Config::OS){ 
		#	push(@tests, $DADA::Config::OS);
		#}
		my %sift; 
		for(@tests){$sift{$_}++}
		@tests = keys %sift; 
		
		for my $test_dir(@tests){ 
			
			if(! -d $test_dir){ 
				push(@$unknown_dirs, {dir => $test_dir}); 
			}
			elsif(!-e $test_dir){ 
				push(@$unknown_dirs, {dir => $test_dir}); 
			}
			else { 
				# ... 
			}
		}
	}



	my $screen = ''; 
	my $r      = ''; 
	
	eval { 
	$screen =  DADA::Template::Widgets::wrap_screen(
				{
					-screen => 'error_' . $args{-Error} . '_screen.tmpl',  
					($args{-Wrapper_Template} eq 'admin' ? 
					(
						-with           => 'admin', 
						-wrapper_params => { 
							#-Root_Login => $root_login,
							-List       => $args{-List},  
						},
						
					)
					:
					(
						-with           => 'list', 
					)
					),
					-vars => { 
							subscription_form     => $subscription_form, 
							unsubscription_form   => $unsubscription_form, 
							list_login_form       => $list_login_form, 
							email                 => $args{-Email},
							auth_code             => $auth_code,
							unknown_dirs          => $unknown_dirs, 
							PROGRAM_URL           => $DADA::Config::PROGRAM_URL, 
							S_PROGRAM_URL         => $DADA::Config::S_PROGRAM_URL, 
							error_message         => $args{-Error_Message},    
				
			
					},
		
					-list_settings_vars       => $li, 
					-list_settings_vars_param => {-dot_it => 1}, 
					-subscriber_vars          => {'subscriber.email' => $args{-Email}}, 			
				}
			); 
       	
		}; 
	
    if($@){ 
		if(defined($args{-Error_Message})){ 
			
			die "Problems showing error message? - $@, \n\n\nOriginal error message: $args{-Error_Message}";
		}
		else { 
			die "Problems showing error message? - $@";
		} 
	}else { 
		$r = $screen; 		
	}
	
	return $r;

}



=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 


1;
