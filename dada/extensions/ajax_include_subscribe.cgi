#!/usr/bin/perl -T
use strict; 


# DEV: TODO: Create a way to embed this in a webpage with Javascript

$ENV{PATH} = "/bin:/usr/bin"; 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

use lib qw(
	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);

BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}



use CGI::Carp qw(fatalsToBrowser); 

use DADA::Config 5.0.0 qw(!:DEFAULT);
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings;
use DADA::Template::Widgets; 
use DADA::App::Messages; 
use DADA::App::Guts; 
use DADA::App::ScreenCache; 


use CGI; 
my   $q   = new CGI;  


my $Plugin_Config = {}; 
# Also see the Config.pm variable, "$PLUGIN_CONFIGS" to set these plugin variables 
# in the Config.pm file itself, or, in the outside config file (.dada_config)


# Change! What is this script's URL? 
# Something like: 
# my $url = 'http://example.com/cgi-bin/dada/extensions/ajax_include_subscribe.cgi'
# DEV: TODO: This should be a config variable that can be set in the Config
$Plugin_Config->{Plugin_URL} = $q->url; 

# DEV: TODO: Should have some mechansim to have a default list shown (or at least a way to pass one, via query string) 


use CGI::Ajax; 
my   $pjx = new CGI::Ajax( 'external' => $Plugin_Config->{Plugin_URL});
    #$pjx->JSDEBUG(1); 
    #$pjx->DEBUG(1); 


# Is there a specific list you want to have the subscription form use? 
# Enter the listshortname in the below variable: 
# 
$Plugin_Config->{Default_List}  = undef; 

#
# If left blank, a popup selection form widget will be shown instead. 


# Subscription Descriptions
# Change the messages created when somsone attempts to subscribe to a list. 
# 
my %Subscription_Descriptions = ( 

    ok                            => 'Your Subscription Request was Successful!', 
        
    invalid_email                 => 'Your email address isn\'t valid!', 
    
    subscribed                    => 'Your email address is already subscribed!', 

    invite_only_list              => 'This mailing list can currently by subscribed by invitation only.', 

    closed_list                   => 'This mailing list is currently closed to future subscribers!', 
    
    mx_lookup_failed              => 'Your email address doesn\'t appear to be from a valid host!', 
    
    black_listed                   => 'That email address is currently not allowed to subscribe to this list!', 
    
    not_white_listed              => 'You currently aren\'t allowed to subscribe to this mailing list!', 
    
    over_subscription_quota       => 'This mailing list has reached its subscription quota!', 
    
    already_sent_sub_confirmation => 'Check your email - we\'ve already sent you a subscription confirmation email!', 
    
    settings_possibly_corrupted   => 'There\s an internal problem - sorry!', 
    

); 

# Subscription redirects
# Would you rather have specific errors redirect to the main program, instead of showing the results inline? If so, 
# list them here: 


# subscribed
# black_listed
my @Subscription_Redirect_This = qw(


); 


# Unsubscription Descriptions
# Change the messages created when somsone attempts to unsubscribe to a list. 
# 
my %Unsubscription_Descriptions = ( 

    ok                            => 'Your Unsubscription Request was Successful!', 

    no_list                       => 'The list you\re trying to subscribe to doesn\'t exist!', 

    invalid_email                 => 'Your email address isn\'t valid!', 

    not_subscribed                => 'Your email address isn\'t currently subscribed!', 

    already_sent_unsub_confirmation => 'Check your email - we\'ve already sent you a unsubscription confirmation email!', 

    settings_possibly_corrupted   => 'There\s an internal problem - sorry!', 


);

# Unsubscription redirects
# Would you rather have specific errors redirect to the main program, instead of showing the results inline? If so, 
# list them here: 


#not_subscribed
my @Unsubscription_Redirect_This = qw(


); 


# Change various things about the loading message.
my %Loading = (
    
    orig_bg_color => '#fff', 
    bg_color      => '#ccc',
    
    message  => '<p>One Second Please...</p>', 
); 


# This is the default subcription form shown, 
# if no subscription request is given: 

my $JS_Code = <<EOF

<!-- tmpl_var ajax_code --> 

function need_redirect() { 
    var do_redirect = arguments[0];
    var url         = arguments[1];

    if(do_redirect == 'redirect'){ 
       //alert('I\'m redirecting to: ' + url);
       window.location = url;
    }
    else { 
        document.getElementById('resultdiv').innerHTML = do_redirect;
    }

}

pjx.prototype.pjxInitialized = function(el){
	el = 'resultdiv'; 
	document.getElementById(el).innerHTML = '<!-- tmpl_var loading_message -->';
	document.getElementById(el).style.backgroundColor = '<!-- tmpl_var loading_bg_color -->';
}

pjx.prototype.pjxCompleted = function(el){
    el = 'resultdiv'; 
    document.getElementById(el).style.backgroundColor = '<!-- tmpl_var orig_bg_color -->';

}


EOF
;


my $Form_Code = <<EOF

<!-- tmpl_var subscription_form --> 

<div id="resultdiv"></div>

EOF
;


# This is the HTML that will be put inside the resultdiv: 
# 
my $Process_Screen = <<EOF

<!-- tmpl_if subscribing --> 

    <!-- tmpl_if errors --> 

        <p>
         There were problems with your subscription request!
        </p>
        
        <ul> 
            <!-- tmpl_loop errors --> 
                <li><p><!-- tmpl_var error --></p></li>
            <!-- /tmpl_loop --> 
        </ul> 
        
    <!-- tmpl_else --> 
    
        <p>
         <!-- tmpl_var subscription_successful --> 
        </p>
        
    <!--/tmpl_if --> 
    
<!-- tmpl_else --> 

    <!-- tmpl_if errors --> 

        <p>
         There were problems with your unsubscription request!
        </p>
        
        <ul> 
            <!-- tmpl_loop errors --> 
                <li><p><!-- tmpl_var error --></p></li>
            <!-- /tmpl_loop --> 
        </ul> 
        
    <!-- tmpl_else --> 
    
        <p>
         <!-- tmpl_var unsubscription_successful --> 
        </p>
        
    <!--/tmpl_if --> 
    
<!-- /tmpl_if --> 


EOF
; 

#----------------------------------------------------------------------------#
# That's the end of any user-configurable parts of this script. 
&init_vars; 


my $f; 

if($q->param('f_s')){ 
        $f = xss_filter($q->param('f_s')); 
}
else { 
        $f = xss_filter($q->param('f_u')); 

}
$q->param('f', $f); 

my $l     = xss_filter($q->param('list'))  || undef; 
my $email = xss_filter($q->param('email')) || undef; 
my $list  = xss_filter($q->param('list'))  || undef; 
my $mode  = xss_filter($q->param('mode'))  || 'js'; 
$q->delete('mode'); 
$q->delete('list'); 


main(); 



sub init_vars { 

    # DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

     while ( my $key = each %$Plugin_Config ) {
        
        if(exists($DADA::Config::PLUGIN_CONFIGS->{ajax_include_subscribe}->{$key})){ 
        
            if(defined($DADA::Config::PLUGIN_CONFIGS->{ajax_include_subscribe}->{$key})){ 
                    
                $Plugin_Config->{$key} = $DADA::Config::PLUGIN_CONFIGS->{ajax_include_subscribe}->{$key};
        
            }
        }
     }
}




sub main { 
	
	if(defined($list)){ 
        if(check_if_list_exists(-List => $list ) == 0){ 
            die "'list' param is not configured correctly."; 
         }		
	}
    elsif(defined($Plugin_Config->{Default_List})){ 
        if(check_if_list_exists(-List => $Plugin_Config->{Default_List} ) == 0){ 
            die "\$Plugin_Config->{Default_List} is not configured correctly."; 
         }
    }
    
    if(! keys %{$q->Vars}){ 
    
        default(); 
    
    } else { 
    
        process(); 
        
    }

}


sub process { 

print $q->header(); 


    if($f){ 

        my $lh = DADA::MailingList::Subscribers->new({-list    => $l}); 

        my $ls = DADA::MailingList::Settings->new({-list => $l}); 
        my $li = $ls->get; 
                    
        if($f =~ /^s/i){ 
           
           
            my ($status, $errors) = $lh->subscription_check(
										{
											-email => $email
										}
									);
            
            foreach(@Subscription_Redirect_This){ 
                if($errors->{$_} && $errors->{$_} == 1){
                    print $q->header();
                    print 'redirect' . '__pjx__' .  $DADA::Config::PROGRAM_URL . '?list=' . $l . '&email=' . $email . '&f=subscribe'; 
                    exit; 
                } elsif ($status == 1 && $_ eq 'ok'){ 
                    print $q->header();
                    print 'redirect' . '__pjx__' .  $DADA::Config::PROGRAM_URL . '?list=' . $l . '&email=' . $email . '&f=subscribe'; 
                    exit;
                }
            }
            # Or....
             if($status == 1){ 
				$q->param('list', $l); 
                require DADA::App::Subscriptions; 
                 my $das = DADA::App::Subscriptions->new; 
                    $das->subscribe(
                    {
                        
                        -cgi_obj     => $q, 
                        -html_output => 0,
                        
                    }
                );  
             }
             
             my $tmp_errors = []; 
             foreach(keys %$errors){
             
                next if $errors->{$_} != 1; 
                if($Subscription_Descriptions{$_}){ 
                    push(@$tmp_errors, {key => $_, error => $Subscription_Descriptions{$_} }); 
                } else { 
                    push(@$tmp_errors, {key => $_, error => $_ }); 
                }
             }
             my $scr = DADA::Template::Widgets::screen({
                -data => \$Process_Screen,
                -vars => 
                    { 
                        subscribing             => 1, 
                        errors                  => $tmp_errors, 
                        subscription_successful => $Subscription_Descriptions{ok}, 
                    
                    },
                }); 
                
             print $scr; 
             exit; 

        } 
        elsif($f =~ /^u/i){ 
          
          my ($status, $errors) = $lh->unsubscription_check(
								      {
									  	-email => $email,
									  },
								  );
            
            foreach(@Unsubscription_Redirect_This){ 
                if($errors->{$_} && $errors->{$_} == 1){
                    print $q->header();
                    print 'redirect' . '__pjx__' .  $DADA::Config::PROGRAM_URL . '?list=' . $l . '&email=' . $email . '&f=u'; 
                    exit; 
                } elsif ($status == 1 && $_ eq 'ok'){ 
                    print $q->header();
                    print 'redirect' . '__pjx__' .  $DADA::Config::PROGRAM_URL . '?list=' . $l . '&email=' . $email . '&f=u'; 
                    exit;
                }
            }
            # Or....
             if($status == 1){ 
				$q->param('list', $l); 
				require DADA::App::Subscriptions; 
                 my $das = DADA::App::Subscriptions->new; 
                    $das->unsubscribe(
                    {
                        
                        -cgi_obj     => $q, 
                        -html_output => 0,
                        
                    }
                ); 
             }
             
             my $tmp_errors = []; 
             foreach(keys %$errors){
             
                next if $errors->{$_} != 1; 
                if($Unsubscription_Descriptions{$_}){ 
                    push(@$tmp_errors, {key => $_, error => $Unsubscription_Descriptions{$_} }); 
                } else { 
                    push(@$tmp_errors, {key => $_, error => $_ }); 
                }
             }
             my $scr = DADA::Template::Widgets::screen({
                -data => \$Process_Screen,
                -vars => 
                    { 
                        subscribing             => 0, 
                        errors                  => $tmp_errors, 
                        unsubscription_successful => $Unsubscription_Descriptions{ok}, 
                    
                    },
                }); 
                
             print $scr; 
             exit; 
           
        }

    }
    else { 
        print " I got no data for, 'f' 'f_s': " . $q->param('f_s') . 'f_u:' . $q->param('f_u'); 
    }
}


sub default { 
    
    use     DADA::App::ScreenCache; 
    my $c = DADA::App::ScreenCache->new; 

    $pjx->cgi( $q );    
    my   $ajax_code = $pjx; 

 #   my $scrn; # .= $q->header(); 
  
     my $js = DADA::Template::Widgets::screen(
		{
        -data => \$JS_Code, 
        -vars => { 
			ajax_code         => $ajax_code, 
            loading_message   => $Loading{message},
            loading_bg_color  => $Loading{bg_color},
            orig_bg_color     => $Loading{orig_bg_color}, 
        }
    
    }); 

	my $subscription_form = ''; 
	if(defined($list)){ 
		$subscription_form = DADA::Template::Widgets::subscription_form(
			{
				-ajax_subscribe_extension => 1, 
				-list                     => $list,
			}
		); 
        
	}elsif(defined($Plugin_Config->{Default_List})){ 
		$subscription_form = DADA::Template::Widgets::subscription_form(
			{
				-ajax_subscribe_extension => 1, 
				-list                     => $Plugin_Config->{Default_List},
			}
		);		
	}
	else { 
		$subscription_form =  DADA::Template::Widgets::subscription_form(
			{
				-ajax_subscribe_extension => 1
			}
		);
		
	}

     my $form = DADA::Template::Widgets::screen(
		{
        	-data => \$Form_Code, 
	        -vars => { 
					subscription_form => $subscription_form,	
        		}
			}
     	);

	if($mode eq 'js'){ 
		
		print $q->header('text/javascript'); 		
		$js =~ s/\<script type\=\"text\/javascript\"\>//; 
		$js =~ s/\<\/script\>//;
	    print $js;
	    print "document.write('" .  js_enc($form) . "');"; 
	}
	elsif($mode eq 'html'){ 
		print $q->header(); 		
		$js =~ s/\<script type\=\"text\/javascript\"\>//; 
		$js =~ s/\<\/script\>//;
	    print '<script type="text/javascript">'; 
		print $js;
		print '</script>'; 
	    print $form; 
	}

}


__END__

=pod

=head1 NAME

ajax_include_subscribe.cgi - An AJAX'd subscription form

=head1 USAGE

=over

=item * Use it like a cgi script. 

Put it in your, B<extensions> directory (ala: cgi-bin/dada/extensions), chmod 755, visit it in your web browser. 

=back

=head1 DESCRIPTION

This small extension script is an exampe of a Dada Mail subscription form with AJAX hooks. Highly customizable, it is meant to be used in one of two ways: 

=head2 As a Javascript Library

To add this form to your HTML page, just add a line that looks like this: 
	
	<script type="text/javascript" src="http://example.com/cgi-bin/dada/extensions/ajax_include_subscribe.cgi"></script> 

=head2 As a Server Side Include

You can also call it as a server side include, like this: 

  <!--#include virtual="/cgi-bin/dada/ajax_subscribe.cgi?mode=html" -->

Make sure to add the query string, C<mode=html>

=head2 By Itself

Not really a method, but you can view the HTML and Javascript produced by visiting the extension in your web browser, with the same query string you use for the Server Side Include: 

L<http://example.com/cgi-bin/dada/ajax_subscribe.cgi?mode=html>

=head2 By Copying the HTML/Javascript

You could also try just copying the source that this script produces from the URL above, and paste it into a page/script/etc that you'd like. 

Probably not the best idea, but I'll throw that idea for ya. 

=head1 Optional Query String Paramaters

=head3 mode

C<mode> can either be set to C<js> to return javascript code, or C<html> to output HTML. If not set, javascript code will be returned. 

=head3 list

C<list> can be passed in the query string, if you want to have the form for a specific list: 

 L<http://example.com/cgi-bin/dada/ajax_subscribe.cgi?list=mylistshortname>

Instead of a popup menu for all lists. It will override anything set in, C<$Plugin_Config->{Default_List}>

=head1 CONFIGURATION

There's no configuration that you are B<required> to do, but there's many things that you B<can> do. We'll try to cover everything: 

=head2 $Plugin_Config->{Default_List} 

By default, this subscription form shows a popup menu containing every available list, so a visitor may select which list to subscribe to. 

If you would like to have this form work for only one list, you may set the B<list short name> in the B<$Plugin_Config->{Default_List} > variable: 

 $Plugin_Config->{Default_List}  = 'mylistshortname';

If you've configured this variable incorrectly, you'll most likely receive an error in your web browser, so take care in setting it correctly. 

=head2 %Subscription_Descriptions

B<%Subscription_Descriptions> holds the many possible messages that are displayed, when a successful request for a subscription was handled. The keys to the key/value pairs correspond to the various internal codes used by Dada Mail. See also: 

L<http://dadamailproject.com/support/documentation/MailingList_Subscribers.pm.html#subscription_check>

=head2 @Subscription_Redirect_This

The whole idea of having an AJAX'd subscription form is to not have to refresh the page and redirect your visitor to Dada Mail itslef when requesting a subscripiton. 

If you would B<like> a redirection to take place, all you need to do is list the internal key code into the B<@Subscription_Redirect_This> array. The possible keys available are also the keys listed in B<%Subscription_Descriptions>

=head2 %Unsubscription_Descriptions

B<%Unsubscription_Descriptions> holds the many possible messages that are displayed, when a successful request for an unsubscription was handled. The keys to the key/value pairs correspond to the various internal codes used by Dada Mail. See also: 

L<http://dadamailproject.com/support/documentation/MailingList_Subscribers.pm.html#unsubscription_check>

For a description of these various key/value pairs. 

=head2 @Unsubscription_Redirect_This

The whole idea of having an AJAX'd subscription form is to not have to refresh the page and redirect your visitor to Dada Mail itslef when requesting a subscripiton. 

If you would B<like> a redirection to take place for an unsubscription request, all you need to do is list the internal key code into the B<@Unsubscription_Redirect_This> array. The possible keys available are also the keys listed in B<%Unsubscription_Descriptions>

=head2 %Loading

The B<%Loading> hash contains a few variables you can set to customize the B<"Loading..."> message displayed as this extension goes about its business with your request. 

=head2 $JS_Code

B<$JS_Code> holds the Javascript template that's shown when you initially visit the form. It's written in the HTML::Template templating language.  

=head2 $Form

B<$Form> holds the HTML template that's shown when you initially visit the form. It's written in the HTML::Template templating language.

=head2 $Process_Screen

B<$Process_Screen> holds the HTML template that's shown in the HTML element of the B<$Default_Screen> that has an id of, B<resultdiv>


=head1 SEE ALSO

=head2 Dada Mail Docs

See the Subscription Cookbook on an explanation on how the subscription code works: 

http://dadamailproject.com/support/documentation/COOKBOOK-subscriptions.pod.html

also see DADA::MailingList::Subscribers for the nitty-gritty stuff. 

http://dadamailproject.com/support/documentation/MailingList_Subscribers.pm.html

=head2 CPAN Perl Modules

The AJAX'y stuff is created using CGI::Ajax: 

http://search.cpan.org/~bct/CGI-Ajax/lib/CGI/Ajax.pm

The HTML templates are using a templating language called, HTML::Template: 

http://search.cpan.org/~samtregar/HTML-Template/Template.pm

=head1 DEMO

Yes! 

See: 

http://dadamailproject.com/cgi-bin/dada/extensions/ajax_include_subscribe.cgi


=head1 DIAGNOSTICS

None, really.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

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

