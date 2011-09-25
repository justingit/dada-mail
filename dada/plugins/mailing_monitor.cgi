#!/usr/bin/perl -w

package mailing_monitor;
use strict; 

$|++; 

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

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use DADA::Mail::MailOut;
use CGI;
my $q = new CGI;
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);



my $Plugin_Config = {}; 
   $Plugin_Config->{Plugin_Name}         = 'Mailing Monitor';
   $Plugin_Config->{Plugin_URL}          = $q->url;
   $Plugin_Config->{Allow_Manual_Run}    = 1;
   $Plugin_Config->{Manual_Run_Passcode} = undef; 

use Getopt::Long;

my $verbose = 1; 
my $admin_list = undef; 
my $root_login = undef; 
my $list       = undef; 



GetOptions(
    "verbose"    => \$verbose
);

&init_vars; 

run()
	unless caller();
	
sub init_vars { 

    # DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

     while ( my $key = each %$Plugin_Config ) {

        if(exists($DADA::Config::PLUGIN_CONFIGS->{Mailing_Monitor}->{$key})){ 

            if(defined($DADA::Config::PLUGIN_CONFIGS->{Mailing_Monitor}->{$key})){ 

                $Plugin_Config->{$key} = $DADA::Config::PLUGIN_CONFIGS->{Mailing_Monitor}->{$key};

            }
        }
     }
}

sub run {

    if ( !$ENV{GATEWAY_INTERFACE} ) {
	
		DADA::Mail::MailOut::monitor_mailout( { -verbose => $verbose } );
        # this (hopefully) means we're running on the cl...

    }
    else {

		
        if (   keys %{ $q->Vars }
            && $q->param('run')
            && xss_filter( $q->param('run') ) == 1
            && $Plugin_Config->{Allow_Manual_Run} == 1 )
        {
			print $q->header(); 
			if($verbose == 1){ 
				print '<pre>'; 
			}
            DADA::Mail::MailOut::monitor_mailout( { -verbose => $verbose } );
			if($verbose == 1){ 
				print '</pre>'; 
			}


        }
        else {

            ( $admin_list, $root_login ) = check_list_security(
                -cgi_obj  => $q,
                -Function => 'mailing_monitor'
            );
			$list = $admin_list; 


	      my $flavor = $q->param('flavor') || 'cgi_default';
	        my %Mode = ( 

	        'cgi_default'             => \&cgi_default, 
			'mailing_monitor_results' => \&mailing_monitor_results, 
	        ); 

	        if(exists($Mode{$flavor})) { 
	            $Mode{$flavor}->();  #call the correct subroutine 
	        }else{
	            &cgi_default;
	        }			
        }
    }
}

sub cgi_default { 
	
	my $tmpl = default_tmpl(); 

	my $curl_location = `which curl`;
       $curl_location = strip( make_safer($curl_location) );
    

	require DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
						{ 
							-data => \$tmpl, 
							-with           => 'admin', 
							-wrapper_params => { 
								-Root_Login => $root_login,
								-List       => $list,  
							},
							-vars => { 
								Plugin_Name              => $Plugin_Config->{Plugin_Name},
								Plugin_URL               => $Plugin_Config->{Plugin_URL}, 
								Manual_Run_Passcode      => $Plugin_Config->{Manual_Run_Passcode}, 
								Allow_Manual_Run         => $Plugin_Config->{Allow_Manual_Run}, 
								curl_location            => $curl_location, 
								root_login               => $root_login, 
								},
								-list_settings_vars_param => {
				                    -list   => $list,
				                    -dot_it => 1,
				                },
						}
					);
	e_print($scrn);	
}

sub mailing_monitor_results {
	
	if($root_login == 1){ 
		my (
			$r, 
			$total_mailouts,
			$active_mailouts,
			$paused_mailouts,
			$queued_mailouts,
			$inactive_mailouts
		) = DADA::Mail::MailOut::monitor_mailout( { -verbose => 0 } );
		print $q->header(); 
		print '<pre>'; 
		e_print($r); 
		print '</pre>';
	} 
	else { 
		my (
			$r, 
			$total_mailouts,
			$active_mailouts,
			$paused_mailouts,
			$queued_mailouts,
			$inactive_mailouts
		) = DADA::Mail::MailOut::monitor_mailout( { -verbose => 0, -list => $list } );		
		print $q->header(); 
		print '<pre>'; 
		e_print($r); 
		print '</pre>';
	}


}

sub default_tmpl { 
	
	return q{ 



	<!-- tmpl_set name="title" value="Mailing Monitor" --> 

		<script type="text/javascript">
		    //<![CDATA[
			Event.observe(window, 'load', function() {
			  mailing_monitor();				
			});

			 function mailing_monitor(){ 

				new Ajax.Updater(
					'mailing_monitor_results', '<!-- tmpl_var Plugin_URL -->', 
					{ 
					    method: 'post', 
						parameters: {
							flavor:       'mailing_monitor_results'

						},
					onCreate: 	 function() {
						Form.Element.setValue('mailing_monitor_button', 'Parsing...');
						$('mailing_monitor_results').hide();
						$('mailing_monitor_results_loading').show();
					},
					onComplete: 	 function() {

						$('mailing_monitor_results_loading').hide();
						Effect.BlindDown('mailing_monitor_results');
						Form.Element.setValue('mailing_monitor_button', 'Refresh Monitor');
					}	
					});
			}
		    //]]>
		</script>





<fieldset> 
<legend><!-- tmpl_var Plugin_Name --></legend>
<form name="some_form" id="some_form"> 
	<input type="button" value="Refresh Monitor" id="mailing_monitor_button" class="processing" onClick="mailing_monitor();" /> 
</form>

	<div id="mailing_monitor_results_loading" style="display:none;"> 
		<p class="alert">Loading...</p>
	</div> 
	<div id="mailing_monitor_results">
	</div> 


</fieldset> 
		 

	<!-- tmpl_if root_login --> 

		<fieldset> 
		 <legend>Manually Run <!-- tmpl_var Plugin_Name --></legend>

		<p>
		 <label for="cronjob_url">Manual Run URL:</label><br /> 
		<input type="text" class="full" id="cronjob_url" value="<!-- tmpl_var Plugin_URL -->?run=1&verbose=1&passcode=<!-- tmpl_var Manual_Run_Passcode -->" />
		</p>
		<!-- tmpl_unless Allow_Manual_Run --> 
		    <span class="error">(Currently disabled)</a>
		<!-- /tmpl_unless -->


		<p> <label for="cronjob_command">curl command example (for a cronjob):</label><br /> 
		<input type="text" class="full" id="cronjob_command" value="<!-- tmpl_var name="curl_location" default="/cannot/find/curl" -->  -s --get --data run=1\;passcode=<!-- tmpl_var Manual_Run_Passcode -->\;verbose=0  --url <!-- tmpl_var Plugin_URL -->" />
		<!-- tmpl_unless curl_location --> 
			<span class="error">Can't find the location to curl!</span><br />
		<!-- /tmpl_unless --> 

		<!-- tmpl_unless Allow_Manual_Run --> 
		    <span class="error">(Currently disabled)</a>
		<!-- /tmpl_unless --> 

		</p>
		</li>
		</ul> 
		</fieldset>

	<!-- /tmpl_if --> 
		
		
};
}

=head1 Mailing Monitor Plugin

The Mailing Monitor plugin is used to monitor the health of mass mailings as they go out. Since mass mailings take a potentially a long time to finish, this plugin can help monitor a mass mailing, but more importantly, can help in restarting a mailing that has been, "B<dropped>". 

Mass Mailings can also be monitored in Dada Mail's list control panel under, B<Mass Mailing - Monitor Your Mailings> and done so in a much more  interactive way, so the power of this plugin is when it's run as a cron job, "behind the scenes". This also allows you to not have your list control panel open in a browser, until your mass mailing is finished. 

Mass Mailings B<drop> because a mass mailing process may need to run longer than is allowed by your hosting environment - especially if you are on a shared hosting environment with limited and shared resources. 

=head1 Installation 

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin manually.

If you install the plugin using the Dada Mail installer, you will still have set the cronjob manually, which is covered below.

=head2 Change permissions of "mailing_monitor.cgi" to 755

The, C<mailing_monitor.cgi> plugin will be located in your, I<dada/plugins> diretory. Change the script to, C<755>

=head2 Configure your .dada_config file

Now, edit your C<.dada_config> file, so that it shows the plugin in the left-hand menu, under the, B<Plugins> heading: 

First, see if the following lines are present in your C<.dada_config> file: 

 # start cut for list control panel menu
 =cut

 =cut
 # end cut for list control panel menu

If they are, remove them. 

Then, find these lines: 

 #					{
 #					-Title      => 'Mailing Monitor',
 #					-Title_URL  => $PLUGIN_URL."/mailing_monitor.cgi",
 #					-Function   => 'mailing_monitor',
 #					-Activated  => 0,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{
 					-Title      => 'Mailing Monitor',
 					-Title_URL  => $PLUGIN_URL."/mailing_monitor.cgi",
 					-Function   => 'mailing_monitor',
 					-Activated  => 0,
 					},

Save your C<.dada_config> file.

=head2 Setting the cronjob

Generally, setting the cronjob to have this plugin run automatically just means that you have to have a cronjob access a specific URL. The URL looks something like this:

 http://example.com/cgi-bin/dada/plugins/mailing_monitor.cgi?run=1&verbose=1

Where, I<http://example.com/cgi-bin/dada/plugins/mailing_monitor.cgi> is the URL to your copy of this plugin. 

A B<Best Guess> at what the entire cronjob that's needed (using the, C<curl> command to access the actual URL) to be set manually will appear in this plugin's list control panel under the fieldset labled, B<Manually Run Mailing Monitor> in the textbox labeled, B<curl command example (for a cronjob):>. It'll look something like this: 

 /usr/bin/curl  -s --get --data run=1\;passcode=\;verbose=0  --url http://example.com/cgi-bin/dada/plugins/mailing_monitor.cgi

Where, I<http://example.com/cgi-bin/dada/plugins/mailing_monitor.cgi> is the URL to this plugin. We suggest running this cronjob every 5 to 15 minutes. A complete cronjob, with the time set for, "every 5 minutes" would look like this: 

 */5 * * * * /usr/bin/curl  -s --get --data run=1\;passcode=\;verbose=0  --url http://example.com/cgi-bin/dada/plugins/mailing_monitor.cgi

=head1 BUGS AND LIMITATIONS

Please, let me know if you find any bugs.

=head1 SEE ALSO

The Mailing List Sending FAQ has a whole lot of information about Dada Mail's Mailing Monitor, plugin features and Batch Sending:

L<http://dadamailproject.com/support/documentation/FAQ-mailing_list_sending.pod.html>

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999 - 2011 Justin Simoni All rights reserved. 

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
