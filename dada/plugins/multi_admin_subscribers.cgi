#!/usr/bin/perl
use strict; 

# make sure the DADA lib is in the lib paths!
use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
); 
use DADA::Config 5.0.0;
# use some of those Modules
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 
use DADA::MailingList::Subscribers; 



use CGI::Carp qw(fatalsToBrowser); 
use CGI; 

my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);




my $Url = $q->url; 




my %Global_Template_Options = (
		#debug             => 1, 		
		path              => [$DADA::Config::TEMPLATES],
		die_on_bad_params => 0,									

        (
            ($DADA::Config::CPAN_DEBUG_SETTINGS{HTML_TEMPLATE} == 1) ? 
                (debug => 1, ) :
                ()
        ), 
);

use HTML::Template; 



my $Default_Template = q{


<!-- tmpl_set name="title" value="Multi List Sub/Unsub Check" -->
	
<h1>Search All Lists for a Particular Subscriber:</h1>

<form action="<!-- tmpl_var Plugin_URL -->" method="post"> 
 <p>
  <input type="text" name="query" value="<!-- tmpl_var query -->" /> 

  <input type="submit" value="Search..." /> 

</p>
  <input type="hidden" name="process" value="1" /> 
  <input type="hidden" name="f" value="search" /> 
</form> 


};


my $Search_Results = qq{

<!-- tmpl_set name="title" value="Multi List Sub/Unsub Check" -->

<h1>Search Results for: <!-- tmpl_var query --></h1>

<form action="<!-- tmpl_var Plugin_URL -->" method="post"> 

<table> 

<tr> 
 <td> 
  <strong>
   List Name
  </strong> 
 </td> 
 <td> 
 </td> 
 <td>
 <strong> 
  Action
 </strong>
 </td>
 <td> 
  <strong> 
   Errors
  </strong> 
 </td> 
</tr> 

   
<!-- tmpl_loop results --> 


 
 
    <!-- tmpl_if subscribed --> 

        <tr style="background-color:#CCFFCC">
         <td>
          <!-- tmpl_var list_name --> (<!-- tmpl_var list -->)  
         </td> 
         <td>
          <input type="checkbox" name="u" value="<!-- tmpl_var list -->+<!-- tmpl_var query -->" <!-- tmpl_unless status -->disabled="disabled" <!-- /tmpl_unless -->/>
         </td> 
         <td>
          Remove 
         </td> 
         
    <!-- tmpl_else --> 
    
    <tr style="background-color:#fcc">
     <td>
      <!-- tmpl_var list_name --> (<!-- tmpl_var list -->)  
     </td> 
     <td>
      <input type="checkbox" name="s" value="<!-- tmpl_var list -->+<!-- tmpl_var query -->" <!-- tmpl_unless status -->disabled="disabled" <!-- /tmpl_unless --> />
     </td> 
     <td>
      Add
     </td> 

    <!-- /tmpl_if --> 
   
    <!-- tmpl_if status --> 
    
      <td> 
        &nbsp;
      </td> 
      
    <!-- tmpl_else --> 
    
      
      <td> 
       <p>
        <ul> 
       
        <!-- tmpl_loop errors --> 

            <li> 
             <!-- tmpl_var error -->
            </li>
       
       <!-- /tmpl_loop --> 
       
      </ul>
     </td> 
        
    <!-- /tmpl_if --> 
    
   </tr> 
    
<!-- /tmpl_loop --> 

</table> 

<input type="hidden" name="query" value="<!-- tmpl_var query -->">
<input type="hidden" name="f"     value="process">

<div class="buttonfloat"> 

 <input type="reset" class="cautionary" value="Reset" />
 <input type="submit" class="processing" value="Process!" />

</div> 

<div class="floatclear"></div> 

</form> 



<hr /> 


$Default_Template <!-- For real? -->

};



# This will take care of all out security woes
my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q, 
                                                    -Function => 'multi_admin_subscribers');
my $list = $admin_list; 

# get the list information
my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 
                             




my $f = $q->param('f') || undef; 
my $query = lc_email( strip ( xss_filter( $q->param( 'query' ) ) ) ); 
if($query eq ''){ 
    $f = 'default'; 
}   

my %Mode = ( 
'default'  => \&default, 
'search'   => \&search, 
'process'  => \&process, 

); 

if($f){ 
	if(exists($Mode{$f})) { 
		$Mode{$f}->();  #call the correct subroutine 
	}else{
		&default;
	}
}else{ 
	&default;
}
            
sub default {
	
	require DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
		{ 
			-data           => \$Default_Template,
			-with           => 'admin', 
			-wrapper_params => { 
				-Root_Login => $root_login,
				-List       => $list,  
			},
			-vars => { 
				Plugin_URL => $Url,  
			},
		}
	); 
	e_print($scrn); 
}


sub search { 
    
    my @lists = available_lists(-In_Order => 1); 

    my $results = []; 
    
    for my $l_list(@lists){ 
            
        my $l_ls = DADA::MailingList::Settings->new({-list => $l_list}); 
        my $l_li = $l_ls->get; 
        my $l_lh = DADA::MailingList::Subscribers->new({-list => $l_list});
        
        my $status; 
        my $errors; 
        my $report_errors = [];
        
        my $found =  $l_lh->check_for_double_email(
            -Email => $query, 
            -Type  => 'list'
        );
        
        if($found){ 
            ($status, $errors) = $l_lh->unsubscription_check(
									{
										-email => $query, 
										-type  => 'list', 
										-skip => ['already_sent_unsub_confirmation', 'not_subscribed', 'closed_list']
									}
								); 
            for(keys %$errors){ 
                push(@$report_errors, {error => $_})
            }    
        } 
        else { 
        
            ($status, $errors) = $l_lh->subscription_check(
										{
											-email => $query, 
											-type  => 'list', 
											-skip => ['already_sent_sub_confirmation', 'subscribed', 'invite_only_list', 'closed_list']
										}
									); 
             for(keys %$errors){ 
                push(@$report_errors, {error => $_})
            }
        }
        
        push(@$results,  {
            subscribed => $found,
            list_name  => $l_li->{list_name}, 
            list       => $l_list,
            query      => $query, 
            status     => $status, 
            errors     => $report_errors, 
            
        }); 
    }

	require DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
		{ 
			-data           => \$Search_Results,
			-with           => 'admin', 
			-wrapper_params => { 
				-Root_Login => $root_login,
				-List       => $list,  
			},
			-vars => { 
		        query      => $query,
		        results    => $results,
		        Plugin_URL => $Url, 
			},
		}
	); 
	e_print($scrn);

}




sub process { 

    my @u = $q->param('u'); 
    my @s = $q->param('s'); 
    
    for(@u){ 
        
        my ($l_list, $l_email) = split(/\+/, $_, 2);
        
        my $l_lh = DADA::MailingList::Subscribers->new({-list => $l_list}); 
		   $l_lh->remove_subscriber(
				{ 
					-email => $l_email, 
					-type  => 'list',
				}
			);
    
    }

    for(@s){ 
        
        my ($l_list, $l_email) = split(/\+/, $_, 2);

        my $l_lh = DADA::MailingList::Subscribers->new({-list => $l_list}); 
           $l_lh->add_subscriber(
				{
					-email => $l_email, 
					-type  => 'list', 
				}
			);
    
    }
    

    print $q->redirect(-uri => $Url . '?f=search&query=' . $query); 

}



=head1 NAME

Multi List Sub/Unsub Check   

A Plugin to allow you to administrate subscriptions/unsubscriptions for multiple lists at one time. 

=head1 USAGE

This script is a Dada Mail plugin. Once configured, you should be able to log into your list and access this plugin under the, B<Plugins> menu. 

B<Note>, that by default, this plugin can only be accessed if you log into a list using the B<Dada Mail Root Password>.

=head1 DESCRIPTION

If you are administrating many lists that may have a similar group of subscribers, it may become tiring to keep track on who's on which list and time-consuming to search through each list separately and then switch back to the list you were working on, make the changes, switch back... etc. 

This plugin attempts to make all that much easier by allowing you to firstly, search through all your lists at once for a particular subscriber and then one one screen, Add/Remove the address from multiple lists at one time. 

This  plugin is also smart enough to understand the per-list preferences.

For example, if an address is black listed on only one list, it can still be added to any of the lists availabled, except that one list it's black listed from. 

If another list has reached its quota, only that list will not be allowed to subscribe any address. 


These are all good things. 

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Upload B<multi_admin_subscribers.cgi> into the plugins directory

We're assuming your cgi-bin looks like this: 

 /home/account/cgi-bin/dada

and inside the I<dada> directory is the I<mail.cgi> file and the I<DADA> (uppercase) directory. Good! Make a B<new> directory in the I<dada> directory called, B<plugins>. 

Upload your tweaked copy of I<multi_admin_subscribers.cgi> into that B<plugins> directory. chmod 755 change_root_password.cgi

=head2 Configure the Config.pm file

This plugin will give you a new menu item in your list control panel. Tell Dada Mail to make this menu item by tweaking the Config.pm file. Find this line (or the line(s) similar) in Config.pm file: 

 #					{-Title      => 'Multi List Sub/Unsub Check',
 #					 -Title_URL  => $PLUGIN_URL."/multi_admin_subscribers.cgi",
 #					 -Function   => 'multi_admin_subscribers',
 #					 -Activated  => 1,
 #					},

Uncomment it (take off the "#"'s) 

Save the Config.pm file. 

=head1 DEPENDENCIES

You'll most likely want to use the version of this plugin with the version of Dada Mail is comes with. 

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=cut

 
 

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
