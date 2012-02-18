#!/usr/bin/perl -w 

use lib qw(
	../ 
	../DADA/perllib 
);


use CGI::Carp "fatalsToBrowser"; 


use strict;

# For testing, set $Debug to 1
my $Debug = 0; 

# These are HTML::Template templates. More information: 
#
# http://search.cpan.org/~samtregar/HTML-Template/Template.pm

my $Default_Screen = q{ 

<!-- tmpl_set name="title" value="Subscribe/Unsubscribe to Multiple Lists" --> 

<!-- tmpl_if error_invalid_email --> 
	<p class="error">
	 The email you submitted is invalid.
	</p>
<!--/tmpl_if-->

<!-- tmpl_var subscription_form --> 

<h1>
 Available Lists:
</h1>

<!-- tmpl_loop lists -->
    
    <h2>
     <a href="<!-- tmpl_var PROGRAM_URL -->/list/<!-- tmpl_var uri_escaped_list -->/">
      <!-- tmpl_var list_name -->
     </a>
     </h2>
    <p>
     <!-- tmpl_var html_info -->
   </p>
    
   <!-- tmpl_if show_archives -->
        
        <!-- tmpl_if newest_archive_blurb -->
            
            <blockquote>
             <p>
              <strong>
               <a href="<!-- tmpl_var PROGRAM_URL -->/archive/<!-- tmpl_var uri_escaped_list -->/newest/">
                Last Message: <!-- tmpl_var newest_archive_subject -->
               </a>
              </strong>
             </p>
             <p>
              <em>
               <!-- tmpl_var newest_archive_blurb -->...
              </em>
             </p>
             <p style="text-align:right">
              <a href="<!-- tmpl_var PROGRAM_URL -->/archive/<!-- tmpl_var uri_escaped_list -->/newest/">
               More...
              </a>
             </p>
            </blockquote>
            
        <!--/tmpl_if-->
    
    <!--/tmpl_if-->

<!--/tmpl_loop-->

};




my $Subscription_Confirmation = q{ 

<!-- tmpl_set name="title" value="Subscribe to Multiple Lists" --> 

<h1>

 <!-- tmpl_if subscribing --> 
    Subscription
 <!-- tmpl_else --> 
    Unsubsubscription
 <!--/tmpl_if--> 


Results: 

</h1>


<!-- tmpl_loop lists_worked_on --> 

    <h2><!-- tmpl_var list_name --></h2>
    
    <!-- tmpl_if status --> 
    
        <p>
         Your request was successful!
        </p> 
    
    <!-- tmpl_else --> 
    
        <h3>Looks like there were problems:</h3>
        
        <ul>
        <!-- tmpl_loop errors --> 
            <li>
             <p class="error">
              <!-- tmpl_var error -->
             </p>
            </li>
         <!--/tmpl_loop --> 
        </ul>
        
        
    <!-- /tmpl_if --> 
    
<!-- /tmpl_loop --> 

    
<!-- tmpl_if debug --> 

    <!-- tmpl_var debug_info --> 

<!-- /tmpl_if --> 

};












use DADA::Config 5.0.0;
use DADA::App::Guts; 

#---------------------------------------------------------------------#

use CGI qw(:standard html3); 

use DADA::App::Guts; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::Template::HTML;
use DADA::Template::Widgets; 
use DADA::App::Messages; 


#---------------------------------------------------------------------#





my $q = CGI->new(); 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);


my $email             = $q->param('email');
   $email             = $q->param('e') unless ($email); 

my $flavor            = $q->param('flavor'); 
   $flavor            = $q->param('f') unless($flavor); 
   

my @unfiltered_lists  = $q->param('list');

my $redirect_url      = $q->param('redirect_url'); 
 
my @available_lists = DADA::App::Guts::available_lists(); 

    my $labels = {}; 
    foreach my $alist( @available_lists ){
        my $als = DADA::MailingList::Settings->new({-list => $alist}); 
        my $ali = $als->get; 
        next if $ali->{hide_list} == 1; 
        $labels->{$alist} = $ali->{list_name};
    }
   @available_lists = sort { uc($labels->{$a}) cmp uc($labels->{$b}) } keys %$labels;





my %list_names; 

my $ht_lists = []; 

my @lists; 
foreach(@unfiltered_lists){ 
	next if ! $_;
	next if $_ eq '';
	push(@lists, $_); 
}

foreach(@available_lists){ 
	my $ls = DADA::MailingList::Settings->new({-list => $_}); 
	my $li = $ls->get; 
	
	
    if($li->{hide_list} ne "1"){ # should we do this here, or in the template?          


    my $tmpl_list_information = {};

    $list_names{$_} = $li->{list_name};	        
        
       # $l_count++; 
        
        
            
        my $html_info = $li->{info};
           $html_info = webify_plain_text({-str => $html_info});
    
        # Just trying this out...
    
        for($li->{list_owner_email}, 
            $li->{admin_email},
            $li->{discussion_pop_email},
        ){  
            if($_){ 
                my $look_e      = quotemeta($_);
                my $protected_e = spam_me_not_encode($_); 					
                   $html_info   =~ s/$look_e/$protected_e/g;
            }
        }
        #/ end that...		

            
           $tmpl_list_information->{uri_escaped_list}     = uriescape($li->{list});
           $tmpl_list_information->{list_name}            = $li->{list_name};
           $tmpl_list_information->{info}                 = $li->{info};
           $tmpl_list_information->{html_info}            = $html_info;
        
	
	
		push(@$ht_lists, {PROGRAM_URL => $DADA::Config::PROGRAM_URL, list => $_, list_name => $li->{list_name}, info => $li->{list_name}, %$tmpl_list_information}); 

	
	
	}
	
}



&main; 


#---------------------------------------------------------------------#


sub main { 
	if($lists[0]){
		subscribe_emails(); 
	}else{ 
		subscription_form(); 
	}
}



sub subscription_form {

    my $scrn =  DADA::Template::Widgets::wrap_screen(
        {
            -data => \$Default_Screen,
            -with => 'list',
            -vars => {
                lists             => $ht_lists,
                email             => $email,
                f                 => $flavor,
                subscription_form => DADA::Template::Widgets::subscription_form(
                    {
                        -multiple_lists => 1,
                        -script_url     => $q->self_url(),
                        -give_props     => 0
                    }
                ),
                error_invalid_email => $q->param('invalid_email'),

            }
        }
    );
	e_print($scrn); 

}


sub subscribe_emails {


	my @lists_worked_on = (); 
	my $debug_info      = ''; 
	
	#--- debug! --- #



    if(DADA::App::Guts::check_for_valid_email($email) == 1){
        print $q->redirect(-uri => $q->self_url . '?invalid_email=1'); 
        return; 
    }

      my $subscribing   = 0; 
      my $unsubscribing = 0; 
      
		if($flavor eq 'u' || $flavor eq 'unsubscribe'){ 
			
      	$unsubscribing   = 1;
		}
		else { 
			$subscribing = 1;
		}
		
	if($subscribing == 1) { 
	
		$debug_info .= "Attempting to Subscribe..."
			if $Debug == 1; 

		foreach my $this_list(@lists){ 
			my $lh = DADA::MailingList::Subscribers->new({-list => $this_list}); 
			my $ls = DADA::MailingList::Settings->new({-list => $this_list}); 
			my $li = $ls->get; 
			
			my ($status, $errors) = $lh->subscription_check(
										{
											-email => $email,
		                                    ($li->{email_your_subscribed_msg} == 1) ? 
		                                    (
		                                    -skip  => ['subscribed'], 
		                                    ) : (),
											
										},
									);
			
			my $error_report = [];
			foreach(keys %$errors){ 
			    push(@$error_report, {error => $_}) if $errors->{$_} == 1;  
			}
			
			#--- debug! --- #
			$debug_info .= $q->h1("List: '" . $this_list ."', Email: $email, Status: " . $q->b($status)) 
				if $Debug == 1; 
			
			if($status == 1){ 
			
			    my $local_q = new CGI; 
			       $local_q->delete_all();
			       $local_q->param('list', $this_list); 
			       $local_q->param('email', $email);
			       $local_q->param('f', 's'); 
			       
			       # Hmm. This should take care of that. 
			       foreach(@{$lh->subscriber_fields}){ 
			            $local_q->param($_, $q->param($_)); 
			       }
			       
			       require DADA::App::Subscriptions; 
			       my $das = DADA::App::Subscriptions->new; 
			       
			       $das->subscribe(
			             {
			                -html_output => 0,
			                -cgi_obj     => $local_q, 
			             }
			       ); 
			}
			
			push(
				@lists_worked_on, 
				{
						list        => $this_list, 
						list_name   => $li->{list_name}, 
						status      => $status, 
						errors      => $error_report, 
						PROGRAM_URL => $DADA::Config::PROGRAM_URL
				}
			); 			
			
			#}else{ 
				#--- debug! --- #
				if($Debug == 1){ 
					$debug_info .= $q->h3("Details..."); 
					$debug_info .= '<ul>';
					foreach my $error(keys %$errors){ 
						$debug_info .= $q->li($error); 
					}
					$debug_info .= '</ul>';
				}else{ 
					# nothing.	
				}
			#}	
		}
	}else{ 
		
		$debug_info .= "<p>Attempting to Unubscribe...</p>"
			if $Debug == 1; 
			
		
		foreach my $this_list(@lists){ 

			my $lh = DADA::MailingList::Subscribers->new({-list => $this_list}); 
			
			my $ls = DADA::MailingList::Settings->new({-list => $this_list}); 
			my $li = $ls->get; 
			
			
			my ($status, $errors) = $lh->unsubscription_check(
										{
											-email => $email,
											($li->{email_you_are_not_subscribed_msg} == 1) ? 
		                                    (
		                                    -skip  => ['not_subscribed'], 
		                                    ) : (),
										}
									); 
			#--- debug! --- #
			
			my $error_report = [];
			foreach(keys %$errors){ 
			    push(@$error_report, {error => $_}) if $errors->{$_} == 1;  
			}
			
			
			$debug_info .= $q->h1("List: '" . $this_list ."', Email: $email, Status: " . $q->b($status)) 
				if $Debug == 1; 
			
			
			push(@lists_worked_on, {list_name => $li->{list_name}, status => $status, errors => $error_report, PROGRAM_URL => $DADA::Config::PROGRAM_URL}); 
			   
		    if($status == 1){ 		
		    
		    
                my $local_q = new CGI; 
                   $local_q->delete_all();
                   $local_q->param('list', $this_list); 
                   $local_q->param('email', $email);
                   $local_q->param('f', 'u'); 
                
                require DADA::App::Subscriptions; 
                my $das = DADA::App::Subscriptions->new; 
                
                $das->unsubscribe(
                    {
                        -html_output => 0,
                        -cgi_obj     => $local_q, 
                    }
                ); 
            }
            
            #}else{ 
		
				#--- debug! --- #	
				if($Debug == 1){ 
					$debug_info .= $q->h3("Details..."); 
					$debug_info .= '<ul>';
					foreach my $error(keys %$errors){ 
						$debug_info .= $q->li($error); 
					}
					$debug_info .= '</ul>';
				}else{ 
					# nothing.	
				}
			#}	
		}
	}
		
		
		if($redirect_url){ 
			$debug_info .= $q->redirect(-uri => $redirect_url); 
			
			print $q->redirect(-url => $redirect_url); 
			return; 
			
		}else{ 

        my $scrn = DADA::Template::Widgets::wrap_screen(
					{
                     	-data => \$Subscription_Confirmation, 
						-with => 'list', 
						-vars => { 
							lists_worked_on => \@lists_worked_on, 
							subscribing     => $subscribing, 
							unsubscribing   => $unsubscribing, 
							email           => $email, 
							f               => $flavor, 
							debug_info      => $debug_info, 
							debug           => $Debug ? 1 : 0,	
							
						},
			}
		); 
		e_print($scrn);
		
			   
		}
	}			   


__END__


=pod

=head1 NAME multiple_subscribe.cgi

=head1 INSTALLING

upload this script in plaintext, or ASCII, mode into the same directory as 
mail.cgi. chmod 755 the multiple_subscribe.cgi script.

You are good to go. 

View this script in a web browser, if everything is installed correctly, you 
should see a simple subscription form. 

=head1 Making an HTML form

This script takes three! different arguments; B<lists>, B<s> and B<email>. Thusly, you have to 
make an HTML form that will supply this script with these three! arguments: 

	<form action="multiple_subscribe.cgi" method="post"> 
	 <p>Lists:</p> 
	  <input type="checkbox" name="list" value="first_list" /> My first list<br/>
	  <input type="checkbox" name="list" value="second_list" /> My second list<br/>
	  <input type="checkbox" name="list" value="third_list" /> My third list<br/>
	 <p>Your email:<br /> 
	  <input type="text" name="email" />
	 </p>
	 <p>
	 <input type="checkbox" name="f" value="s"> Subscribe!<br /> 
	 <input type="checkbox" name="f" value="u"> Unsubscribe!</p> 
	 </p>
	 <p>
	 <input type="submit" value="Subscribe Me" /> 
	 </p>
	</form> 

You can also view the source of the initial screen of multiple_subscribe.cgi 
and copy and paste the form it creates. 

This script also takes an optional argument, B<redirect_url> that you may 
set to any URL where you'd like this script to redirect, once it's done:

	<input type='hidden' name='redirect_url' value='http://mysite.com/thanks.html'>

=head1 DEBUGGING

This script has one variable on top of the script, called B<$Debug>.
You may set this variable to '1' to gain a better insight on what exactly is
happening behind the curtains. 

=head1 COPYRIGHT 

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

To contact info, please see: 

L<http://dadamailproject.com/contact/>

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
