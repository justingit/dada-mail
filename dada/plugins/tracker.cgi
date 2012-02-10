#!/usr/bin/perl
package tracker; 
use strict;

$|++;

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

use lib qw(
	../ 
	../DADA/perllib
);

use CGI::Carp "fatalsToBrowser";
use DADA::Config 4.0.0 qw(!:DEFAULT);
use DADA::Template::HTML;
use DADA::App::Guts;
use DADA::MailingList::Settings;
use DADA::Logging::Clickthrough;
use DADA::MailingList::Archives;


# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);


my $Plugin_Config             = {}; 
$Plugin_Config->{Plugin_Name} = 'Tracker'; 
$Plugin_Config->{Plugin_URL}  = $q->url; 
$Plugin_Config->{Geo_IP_Db}   = '../DADA/data/GeoIP.dat'; 



&init_vars; 

run()
	unless caller();

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{Tracker}->{$key} ) ) {

            if ( defined( $DADA::Config::PLUGIN_CONFIGS->{Tracker}->{$key} ) ) {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{Tracker}->{$key};

            }
        }
    }
}

my $list       = undef;
my $ls         = undef;
my $rd         = undef;
my $mja        = undef;
my $root_login = 0;




sub run {
	
	my $admin_list; 
	( $admin_list, $root_login ) = check_list_security(
	    -cgi_obj  => $q,
	    -Function => 'tracker'
	);
	$list = $admin_list;
	$ls   = DADA::MailingList::Settings->new( { -list => $list } );
	$rd   = DADA::Logging::Clickthrough->new( { -list => $list } );
	$mja  = DADA::MailingList::Archives->new( { -list => $list } );
	
	my $f = $q->param('f') || undef;
	my %Mode = (
	    'default'                    => \&default,
	    'm'                          => \&message_report,
	    'url'                        => \&url_report,
	    'edit_prefs'                 => \&edit_prefs,
	    'download_logs'              => \&download_logs,
	    'ajax_delete_log'            => \&ajax_delete_log,
		'clickthrough_table'         => \&clickthrough_table, 
		'subscriber_history_img'     => \&subscriber_history_img, 
		'download_clickthrough_logs' => \&download_clickthrough_logs, 
		'download_activity_logs'     => \&download_activity_logs, 
		'domain_breakdown_img'       => \&domain_breakdown_img, 
		'country_geoip_chart'        => \&country_geoip_chart, 
		'data_ot_img'                  => \&data_ot_img, 
	);
	if ($f) {
	    if ( exists( $Mode{$f} ) ) {
	        $Mode{$f}->();    #call the correct subroutine
	    }
	    else {
	        &default;
	    }
	}
	else {
	    &default;
	}
}




sub default_tmpl {

    my $tmpl = q{ 

<!-- tmpl_set name="title" value="Tracker" --> 
<div id="screentitle"> 
	<div id="screentitlepadding">
		<!-- tmpl_var title --> 
	</div>
	<!-- tmpl_include help_link_widget.tmpl -->
</div>

<!-- tmpl_if done --> 
	<p class="positive"><!-- tmpl_var GOOD_JOB_MESSAGE --></p>
<!-- /tmpl_if --> 
	

	<script type="text/javascript">
	    //<![CDATA[
		Event.observe(window, 'load', function() {
		  show_table();	
		  subscriber_history_img(); 
		  domain_breakdown_img(); 
					
		});
		
		 function show_table(){ 
			
			new Ajax.Updater(
				'show_table_results', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'clickthrough_table',
						page:   $F('page')
					},
				onCreate: 	 function() {
					$('show_table_results_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {

					$('show_table_results_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('show_table_results');
				}	
				});
		}
		
		function turn_page(page_to_turn_to) { 
			Form.Element.setValue('page', page_to_turn_to) ; 
			show_table();
			subscriber_history_img();
		}
		
		function subscriber_history_img(){ 
			
			new Ajax.Updater(
				'subscriber_history_img', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'subscriber_history_img',
						page:   $F('page')
					},
				onCreate: 	 function() {
					$('subscriber_history_img_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('subscriber_history_img_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('subscriber_history_img');
				}	
				});
		}
		function domain_breakdown_img(){ 

			new Ajax.Updater(
				'domain_breakdown_img', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'domain_breakdown_img',
					},
				onCreate: 	 function() {
					$('domain_breakdown_img_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('domain_breakdown_img_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('domain_breakdown_img');
				}	
				});
		}
		function purge_log(){ 
			
			var confirm_msg =  "Are you sure you want to delete this log? ";
			    confirm_msg += "There is no way to undo this deletion.";
			if(confirm(confirm_msg)){
					new Ajax.Request(
					  '<!-- tmpl_var Plugin_URL -->', 
					{
					  method: 'post',
					 	parameters: {
							f: 'ajax_delete_log', 
					  },
					  onSuccess: function() {
						show_table();
						subscriber_history_img();						
					  }, 
					onFailure: function() { 
						alert('Warning! Something went wrong when attempting to remove the log file.'); 
					}
					}
					);
			}
			else { 
				alert('Log deletion canceled.'); 
			}
		}
	    //]]>
	</script>
	<form> 
	 <input type="hidden" name="page" value="1" id="page" /> 
	</form> 

<fieldset> 
	<legend>
	 Tracker Summaries
	</legend>

	<div id="show_table_results_loading">
		<p class="alert">Loading...</p>
	</div>	
	
	<div id="show_table_results">
	</div>
	
	
	<div id="subscriber_history_img_loading">
	</div>
	<div id="subscriber_history_img"> 
	</div> 

</fieldset> 

<fieldset> 
 <legend>Export Logs</legend> 
 <table> 
  <tr> 
   <td> 
  <form action="<!-- tmpl_var Plugin_URL -->" method="post">
   <input type="hidden" name="f" value="download_logs" /> 
   <input type="hidden" name="log_type" value="clickthrough" /> 
   <input type="submit" value="Download Clickthrough Logs (.csv)" class="processing" />
  </form> 
 </td> 
<td> 
<form action="<!-- tmpl_var Plugin_URL -->" method="post">
 <input type="hidden" name="f" value="download_logs" /> 
 <input type="hidden" name="log_type" value="activity" /> 
 <input type="submit" value="Download Mass Mailing Event Logs (.csv)" class="processing" />
</form>
</td> 
<td> 
<form action="<!-- tmpl_var Plugin_URL -->" method="post">
 <input type="button" value="Purge ALL Clickthrough Logs" class="alertive" onclick="purge_log();"/>
</form> 
</td> 
</tr> 
</table> 
</fieldset> 



<fieldset>
<legend> 
 Current Subscribers by Email Address Domain
</legend>  
<div id="domain_breakdown_img_loading">
</div>
<div id="domain_breakdown_img"> 
</div> 

</fieldset> 


<fieldset> 
<legend>
 Preferences
</legend> 

<form method="post"> 
<input type="hidden" name="f" value="edit_prefs" /> 
<table border="0"> 
 <tr> 
  <td> 
   <p>
    <input type="checkbox" name="clickthrough_tracking" id="clickthrough_tracking"  value="1" <!-- tmpl_if list_settings.clickthrough_tracking -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="clickthrough_tracking"> 
     Enable Clickthrough Tracking
    </label> 
   </p>





	<table <!-- tmpl_unless can_use_auto_redirect_tag -->class="disabled"<!--/tmpl_unless-->>	 <tr> 
	  <td> 
  	<input type="checkbox" id="tracker_auto_parse_links" name="tracker_auto_parse_links"  value="1" <!-- tmpl_if list_settings.tracker_auto_parse_links -->checked="checked"<!--/tmpl_if -->/>
	  </td> 
	  <td> 
		
		<p>
		 <label for="tracker_auto_parse_links">Clickthrough Track All Message Links</label> 
		 <br /> 
		 All message links will be parsed into redirect links and tracked. 
		</p> 
		
		<!-- tmpl_unless can_use_auto_redirect_tag -->
			<p class="error"> 
				Disabled. You must have the HTML::LinkExtor and URI::Find CPAN modules installed. 
			</p>
		<!-- /tmpl_unless --> 
	  </td> 
	</tr> 
	
	</table>


  </td>
  </tr> 

   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_open_msg_logging" id="enable_open_msg_logging"  value="1" <!-- tmpl_if list_settings.enable_open_msg_logging -->checked="checked"<!--/tmpl_if --> 
   </p>	
  </td> 
  <td> 
   <p>
    <label for="enable_open_msg_logging"> 
     Enable Open Messages Logging
    </label> 
   </p>
  </td>
  </tr> 

 <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_subscriber_count_logging" id="enable_subscriber_count_logging"  value="1" <!-- tmpl_if list_settings.enable_subscriber_count_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_subscriber_count_logging"> 
     Enable Subscriber Count Logging
    </label> 
   </p>
  </td>
  </tr> 


   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_forward_to_a_friend_logging" id="enable_forward_to_a_friend_logging"  value="1" <!-- tmpl_if list_settings.enable_forward_to_a_friend_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_forward_to_a_friend_logging"> 
     Enable &quot;Forward to a Friend&quot; Logging
    </label> 
   </p>
  </td>
  </tr>

   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_view_archive_logging" id="enable_view_archive_logging"  value="1" <!-- tmpl_if list_settings.enable_view_archive_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_view_archive_logging"> 
     Enable Archive Views Logging
    </label> 
   </p>
  </td>
  </tr>




  
   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_bounce_logging" id="enable_bounce_logging"  value="1" <!-- tmpl_if list_settings.enable_bounce_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_bounce_logging"> 
     Enable Bounce Logging
    </label> 
   </p>
  </td>
  </tr>
  
 <tr> 
  <td> 
   <p>
	&nbsp;
   </p>
  </td> 
  <td> 
   <p>
     View: <!-- tmpl_var tracker_record_view_count_widget --> Records at once. 
<br /><em>(More entries = a slower interface)</em>
   </p>
  </td>
  </tr>

   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="tracker_clean_up_reports" id="tracker_clean_up_reports"  value="1" <!-- tmpl_if list_settings.tracker_clean_up_reports -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="tracker_clean_up_reports"> 
    Clean Up Tracker Reports
    </label> 
   </p>
  </td>
  </tr>

   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="tracker_show_message_reports_in_mailing_monitor" id="tracker_show_message_reports_in_mailing_monitor"  value="1" <!-- tmpl_if list_settings.tracker_show_message_reports_in_mailing_monitor -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="tracker_show_message_reports_in_mailing_monitor"> 
    Show Message Reports in Mailing Monitor
    </label> 
   </p>
  </td>
  </tr>


  
</table> 





<div class="buttonfloat">   
 <input type="submit" class="processing" value="Save Tracker Preferences" /> 
 </div>
<div class="floatclear"></div>
</form> 
</fieldset> 



<fieldset> 
<legend>Tracker Help</legend> 
<p>
 Clickthrough logging works for URLs in mailing list
 messages when the URLs are placed in the  <code>&lt;?dada redirect url=&quot;...&quot; ?&gt;</code> comment. 
</p>

<p>For example:</p> 
<p><code>
&lt;?dada redirect url=&quot;http://example.com&quot; ?&gt;
</code></p>
<p>Replace, <code>http://example.com</code> with the URL you would like to track clickthroughs. 
</fieldset> 

};

	return $tmpl;

}



sub default {
	
	my $tracker_record_view_count_widget = $q->popup_menu(
			-name    => 'tracker_record_view_count',
			-values  => [qw(5 10 15 20 25 50 100)],
			-default => $ls->param('tracker_record_view_count'), 
		);			
	eval { 
		require URI::Find; 
		require HTML::LinkExtor;
	};
	my $can_use_auto_redirect_tag  = 1; 
	if($@){ 
		$can_use_auto_redirect_tag = 0; 
	}	
		 	 
    my $tmpl = default_tmpl();
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $ls->param('list'),
            },
            -vars => {
                done                             => $q->param('done') || 0,
				Plugin_URL                       => $Plugin_Config->{Plugin_URL}, 
				tracker_record_view_count_widget => $tracker_record_view_count_widget, 
				can_use_auto_redirect_tag        => $can_use_auto_redirect_tag, 

            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    e_print($scrn);

}




sub domain_breakdown_img_tmpl { 
	
return q{ 
	<p> 
	 <img src="<!-- tmpl_var domain_breakdown_chart_url -->" width="640" height="300" style="border:1px solid black" />
	</p>
};	
	
}	
sub domain_breakdown_img { 

	require DADA::MailingList::Subscribers; 
	my $lh       = DADA::MailingList::Subscribers->new({-list => $list});
	my $stats    = $lh->domain_stats(15); 
	my $num_subs = $lh->num_subscribers;
	
	my @values = (); 
	my @labels = (); 
	foreach(keys %$stats){ 
		push(@values, $stats->{$_}), 
		push(@labels, $_ . ' ' . percent($stats->{$_}, $num_subs) .  '% (' . $stats->{$_} . ')' ); 	
	}
	
	require URI::GoogleChart; 
	my $chart = URI::GoogleChart->new("pie", 640, 300,
	    data => [@values],
	    rotate => -90,
	    label => [@labels],
	    encoding => "s",
	    background => "white",
		margin => [150, 150, 10, 10],
		title => 'Total Subscribers: ' . commify($num_subs),
	);
	
	use HTML::Entities;
	my $enc_chart = encode_entities($chart);

  	my $tmpl = domain_breakdown_img_tmpl();
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -data           => \$tmpl,
            -vars => {
				domain_breakdown_chart_url => $enc_chart,
            },
        }
    );
	print $q->header(); 
    e_print($scrn);

	
}

sub percent { 
	my ($num, $total) = @_; 
	
	my $percent = ($total ? $num/$total : undef);
	   $percent = $percent * 100;
	   $percent = sprintf("%.2f", $percent);
	return $percent; 
}
sub subscriber_history_img_tmpl { 
	return q{ 
		<!-- tmpl_if has_entries --> 
			<p>
			 <img src="<!-- tmpl_var num_subscribers_chart_url -->" width="720" height="400" style="border:1px solid black" /> 
			</p>
		<!-- tmpl_else --> 
			<!-- ... --> 
		<!-- /tmpl_if --> 
	};
}



sub subscriber_history_img { 
	
	my $page = $q->param('page') || 1; 
	my ($total, $msg_ids) = $rd->get_all_mids(
		{ 
			-page    => $page, 
			-entries => $ls->param('tracker_record_view_count'),  
			
		}
	);
	
 	my $report_by_message_index = $rd->report_by_message_index({-all_mids => $msg_ids}) || [];
	
	# Needs potentially less data points 
	# and labels for start/end of chart. 
	my $num_subscribers = []; 
	my $opens           = [];
	my $clickthroughs   = [];
	my $soft_bounces    = [];
	my $hard_bounces    = [];
	my $first_date      = undef;
	my $last_date       = undef; 

	for(reverse @$report_by_message_index){ 
		if($rd->verified_mid($_->{mid})){
			
			if($ls->param('tracker_clean_up_reports') == 1){ 
				next unless exists($_->{num_subscribers}) && $_->{num_subscribers} =~ m/^\d+$/
			}
		
			push(@$num_subscribers, $_->{num_subscribers});
			if(defined($_->{open})){ 
				push(@$opens,    $_->{open});	
			}
			else { 
				push(@$opens,  0);
			}					
			
			if(defined($_->{count})){ 
				push(@$clickthroughs,    $_->{count});	
			}
			else { 
				push(@$clickthroughs,  0);
			}					
			
			if(defined($_->{soft_bounce})){ 
				push(@$soft_bounces,    $_->{soft_bounce});	
			}
			else { 
				push(@$soft_bounces,  0);
			}
			if(defined($_->{hard_bounce})){ 
				push(@$hard_bounces,    $_->{hard_bounce});	
			}
			else { 
				push(@$hard_bounces,  0);
			}
			if(!defined($first_date	)){ 
				$first_date = DADA::App::Guts::date_this( -Packed_Date => $_->{mid});
			}
			$last_date = DADA::App::Guts::date_this( -Packed_Date => $_->{mid});				
		}
	} 

	require     URI::GoogleChart; 
	my $chart = URI::GoogleChart->new("lines", 720, 400,
    data => [
 		{ range => "a", v => $num_subscribers },
 		{ range => "a", v => $opens },
 		{ range => "a", v => $clickthroughs },
 		{ range => "a", v => $soft_bounces },
 		{ range => "a", v => $hard_bounces },

  	],
 	range => {
		a => { round => 0, show => "left" },
	},	
	color => [qw(green blue aqua ffcc00 red)],
	label => ["Subscribers", "Opens", "Clickthroughs", "Soft Bounces", "Hard Bounces"],
	chxt => 'x',
	chxl => '0:|' . $first_date . '|' . $last_date, 

	);
	
	use HTML::Entities;
	my $enc_chart = encode_entities($chart);

  	my $tmpl = subscriber_history_img_tmpl();
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -data           => \$tmpl,
            -vars => {
              #  report_by_message_index   => $rd->report_by_message_index,
				num_subscribers_chart_url => $enc_chart,
				Plugin_URL                => $Plugin_Config->{Plugin_URL}, 
				has_entries               => scalar @$report_by_message_index, 
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
	print $q->header(); 
    e_print($scrn);
}



sub every_nth { 
	my $array_ref = shift; 
	my $nth       = shift || 10; 
	
	if($nth < 0){ 
		return $array_ref; 
	}
	if(scalar(@$array_ref) < $nth){ 
		return $array_ref; 
	}
	
	my $index =  int(scalar(@$array_ref) / $nth);
	my $count = 0; 
	my @group = (); 
	for(@$array_ref){ 
	
		unless($count % $index ){ 
			push(@group, $_); 
		}
		$count++; 
	}

	return [@group];
}


sub data_ot_img_tmpl { 
	
return q{ 
	<!-- tmpl_if data_ot_img_url --> 
	<p> 
	 <img src="<!-- tmpl_var data_ot_img_url -->" width="720" height="250" style="border:1px solid black" />
	</p>
	<!-- tmpl_else --> 
		<p class="alert">Nothing to Report.</p> 
	<!-- /tmpl_if --> 
	
};	
	
}

sub data_ot_img { 
	
	my $msg_id = $q->param('mid'); 
	my $type   = $q->param('type'); 
	
	my $ct_ot = $rd->data_over_time(
		{
			-msg_id => $msg_id,
			-type   => $type, 
		}
	); 
	my $range = [];
	my $chxl  = [];
	
	foreach(@$ct_ot){ 
		push(@$chxl, $_->{mdy}); 
		push(@$range, $_->{count}); 
		
	}
	
	$chxl = every_nth($chxl, 5); 
	
	require     URI::GoogleChart; 
	my $chart = URI::GoogleChart->new("lines", 720, 250,
    data => [
 		{ range => "a", v => $range },
  	],
 	range => {
		a => { round => 0, show => "left" },
	},	
	color => ['blue'],
	label => ["# " . ucfirst($type)],
	chxt => 'x',
	chm  => 'B,99ccff,0,0,0',
	chg  => '0,10',
	chxl => '0:|' . join('|', @$chxl), 
	);
	
	use HTML::Entities;
	my $enc_chart = encode_entities($chart);
	
	if(!exists($ct_ot->[0])) { 
		$enc_chart = undef; 
	}
	my $tmpl = data_ot_img_tmpl();
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -data           => \$tmpl,
            -vars => {
				data_ot_img_url => $enc_chart,
				
            },
        }
    );
	print $q->header(); 
    e_print($scrn);		
}




sub clickthrough_table_tmpl { 
	
	return q{ 

	<!-- tmpl_if report_by_message_index --> 
		
		
		<table class="stripedtable">
		 <tr> 
		<td width="33%" align="left"> 

		<strong><a href="javascript:turn_page(<!-- tmpl_var first_page -->);">First</a></strong>

		</td> 
	
		<td width="33%" align="center"> 
		<p>
	
		<!-- tmpl_if previous_page --> 
			<strong><a href="javascript:turn_page(<!-- tmpl_var previous_page -->);">Previous</a></strong>
		<!-- tmpl_else --> 
		<!-- /tmpl_if -->
		&nbsp;&nbsp;&nbsp;&nbsp;
			<!-- tmpl_loop pages_in_set --> 
				<!-- tmpl_if on_current_page --> 
					<strong> 
					 <!-- tmpl_var page --> 
					</strong> 
				<!-- tmpl_else --> 
					<a href="javascript:turn_page(<!-- tmpl_var page -->);">
					 <!-- tmpl_var page --> 
					</a>
				<!-- /tmpl_if --> 

			<!-- /tmpl_loop --> 
			&nbsp;&nbsp;&nbsp;&nbsp;
			<!-- tmpl_if next_page -->
			<strong><a href="javascript:turn_page(<!-- tmpl_var next_page -->);">Next</a></strong>
			<!-- tmpl_else --> 
			<!-- /tmpl_if --> 
			</p>
		</td> 
	
		<td width="33%" align="right"> 

		<strong><a href="javascript:turn_page(<!-- tmpl_var last_page -->);">Last</a></strong>

		</td>
	
		</tr> 
		</table>
	
		<div> 
			<div style="max-height: 300px; overflow: auto; border:1px solid black">

			  <table class="stripedtable">
			   <tr> 
			    <td> 
				 <p>
				  <strong> 
					Subject
				  </strong> 
				 </p>
				</td> 
			    <td> 
				 <p>
				  <strong> 
					Sent
				  </strong> 
				 </p>
				</td>
			    <td> 
				 <p>
				  <strong> 
					Subscribers
				  </strong> 
				 </p>
				</td>
			    <td> 
				 <p>
				  <strong> 
					Clickthroughs
				  </strong> 
				 </p>
				</td>
			    <td> 
				 <p>
				  <strong> 
					Opens
				  </strong> 
				 </p>
				</td>
			    <td> 
				 <p>
				  <strong> 
					Bounces (soft/hard)
				  </strong> 
				 </p>
				</td>
				</tr> 

				<!-- tmpl_loop report_by_message_index --> 
				<tr <!-- tmpl_if __odd__>class="alt"<!-- /tmpl_if -->> 
				 <td> 
		          <p>
		          
					<!-- tmpl_if message_subject -->
					 	 <strong>
						<a href="<!-- tmpl_var Plugin_URL" -->?f=m&mid=<!-- tmpl_var mid -->">
						<!-- tmpl_var message_subject escape="HTML" -->
						</a> 
						
						<a href="<!-- tmpl_var S_PROGRAM_URL -->?f=view_archive&list=<!-- tmpl_var list -->&id=<!-- tmpl_var mid -->">
						 </strong>
							(View) 
						</a> 
					<!-- tmpl_else --> 
						 <strong>
						<a href="<!-- tmpl_var Plugin_URL" -->?f=m&mid=<!-- tmpl_var mid -->">
						#<!-- tmpl_var mid --> (unarchived message)
						</a>
						 </strong>
					<!-- /tmpl_if --> 
		 		   
				  </p>
				 </td> 
				 <td> 
				  <p>
					<!-- tmpl_var date --> 
			      </p> 
			     </td> 
			     <td> 
			      <p>
			       <a href="<!-- tmpl_var Plugin_URL" -->?f=m&mid=<!-- tmpl_var mid -->">
				    <!-- tmpl_var num_subscribers  --> 
				   </a> 
			      </p>
				 </td> 
			     <td> 
			      <p>
			       <a href="<!-- tmpl_var Plugin_URL" -->?f=m&mid=<!-- tmpl_var mid -->">
				    <!-- tmpl_var count   --> 
				   </a> 
			      </p>
				 </td> 
			     <td> 
			      <p>
			       <a href="<!-- tmpl_var Plugin_URL" -->?f=m&mid=<!-- tmpl_var mid -->">
				    <!-- tmpl_var open   --> 
				   </a> 
			      </p>
				 </td> 
			     <td> 
			      <p>
			       <a href="<!-- tmpl_var Plugin_URL -->?f=m&mid=<!-- tmpl_var mid -->">
				    <!-- tmpl_var soft_bounce  default="-" --> /<!-- tmpl_var hard_bounce default="-" --> 
				   </a> 
			      </p>
				 </td> 
			  </tr> 

			<!-- /tmpl_loop --> 

		     </table> 
		</div>		
	
		</div> 
		<!-- tmpl_if comment --> 
		
		<fieldset> 
			<pre>
			<!-- tmpl_var report_by_message_id_dump escape="HTML" --> 
			</pre> 
		</fieldset> 
		<!-- /tmpl_if --> 
		
	<!-- tmpl_else --> 
		<p class="alert">
		  No logs to report.
	    </p>
	<!-- /tmpl_if --> 
	
	};
	
	
}
sub clickthrough_table { 
	
	my $page = $q->param('page') || 1; 
	require DADA::Template::Widgets;
	
  	my $tmpl = clickthrough_table_tmpl();

	my ($total, $msg_ids) = $rd->get_all_mids(
		{ 
			-page    => $page, 
			-entries => $ls->param('tracker_record_view_count'),  
		}
	);


	require Data::Pageset;
	my $page_info = Data::Pageset->new(
		{
		'total_entries'       => $total, 
		'entries_per_page'    => $ls->param('tracker_record_view_count'), # needs to be tweakable...  
		'current_page'        => $page,
		'mode'                => 'slide', # default fixed
 		}
	);

	my $pages_in_set = [];
	foreach my $page_num (@{$page_info->pages_in_set()}) {
		if($page_num == $page_info->current_page()) {
			push(@$pages_in_set, {page => $page_num, on_current_page => 1});
		}
		else { 
			push(@$pages_in_set, {page => $page_num, on_current_page => undef});
		}
	}

	my $report_by_message_id = $rd->report_by_message_index({-all_mids => $msg_ids}) || []; 
#	require Data::Dumper; 
#	my $report_by_message_id_dump = Data::Dumper::Dumper($report_by_message_id); 
    require    DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -data           => \$tmpl,
            -vars => {
                report_by_message_index   => $report_by_message_id,
#				report_by_message_id_dump => $report_by_message_id_dump, 
				first_page                => $page_info->first_page(), 
				last_page                 => $page_info->last_page(), 
				next_page                 => $page_info->next_page(), 
				previous_page             => $page_info->previous_page(), 
				pages_in_set              => $pages_in_set,  		
				Plugin_URL                => $Plugin_Config->{Plugin_URL}, 
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
	print $q->header(); 
    e_print($scrn);

}




sub download_logs {

	my $type = xss_filter($q->param('log_type')); 
	if($type ne 'clickthrough' && $type ne 'activity'){ 
		$type = 'clickthrough'; 
	}
	
	my $header  = 'Content-disposition: attachement; filename=' . $list . '-' . $type . '.csv' .  "\n"; 
	   $header .= 'Content-type: text/csv' . "\n\n";
    print $header;

    $rd->export_logs(
		{
			-type => $type, 
			-fh   => \*STDOUT
		}
	);
}




sub download_clickthrough_logs { 
	my $mid = xss_filter($q->param('mid')); 
	my $header  = 'Content-disposition: attachement; filename=' . $list . '-clickthrough-' . $mid . '.csv' .  "\n"; 
	   $header .= 'Content-type: text/csv' . "\n\n";
    print $header;
    $rd->export_logs(
		{
			-type => 'clickthrough', 
			-mid  => $mid, 
			-fh   => \*STDOUT
		}
	);

}




sub download_activity_logs { 
	my $mid = xss_filter($q->param('mid')); 
	my $header  = 'Content-disposition: attachement; filename=' . $list . '-activity-' . $mid . '.csv' .  "\n"; 
	   $header .= 'Content-type: text/csv' . "\n\n";
    print $header;
    $rd->export_logs(
		{
			-type => 'activity', 
			-mid  => $mid, 
			-fh   => \*STDOUT
		}
	);

}




sub ajax_delete_log {
	$rd->purge_log; 
	print $q->header(); 
}




sub edit_prefs {

    $ls->save_w_params(
        {
            -associate => $q,
            -settings  => {
                clickthrough_tracking                           => 0,
                enable_open_msg_logging                         => 0,
                enable_subscriber_count_logging                 => 0,
				enable_forward_to_a_friend_logging              => 0, 
				enable_view_archive_logging                     => 0,
                enable_bounce_logging                           => 0,
				tracker_record_view_count                       => 0,
				tracker_clean_up_reports                        => 0, 
				tracker_auto_parse_links                        => 0, 
				tracker_show_message_reports_in_mailing_monitor => 0, 
            }
        }
    );

    print $q->redirect( -uri => $Plugin_Config->{Plugin_URL} . '?done=1' );
}




sub message_report_tmpl {
    
my $tmpl = q{ 
	
	<!-- tmpl_unless chrome --> 
		<html> 
		 <head>
		   <link rel="stylesheet" href="<!-- tmpl_var S_PROGRAM_URL -->/css/default.css" type="text/css" media="screen" />
		  <script src="<!-- tmpl_var S_PROGRAM_URL -->/js/dada_mail_admin_js.js" type="text/javascript"></script>
		  <script src="<!-- tmpl_var S_PROGRAM_URL -->/js/prototype.js" type="text/javascript"></script>
		  <script src="<!-- tmpl_var S_PROGRAM_URL -->/js/scriptaculous.js?load=effects" type="text/javascript"></script>
		 </head> 
		<body style="background:#fff"> 
		
	<!-- /tmpl_unless -->
	
	
	<!-- tmpl_if chrome --> 
		<!-- tmpl_set name="title" value="Tracker &#187; Message Report" --> 
		<div id="screentitle"> 
			<div id="screentitlepadding">
				<!-- tmpl_var title --> 
			</div>
			<!-- tmpl_include help_link_widget.tmpl -->
		</div>
	<!-- /tmpl_if --> 
	
		<script type="text/javascript">
	    //<![CDATA[
	
			
			
		Event.observe(window, 'load', function() {
	

		  <!-- tmpl_if can_use_country_geoip_data --> 
			country_geoip_chart_clickthroughs();	
			country_geoip_chart_opens();
			country_geoip_chart_forwards();
			country_geoip_chart_view_archive(); 
			
		  <!-- /tmpl_if --> 
	
		ct_ot_img(); 
		opens_ot_img();
		forwards_ot_img(); 
		view_archive_ot_img(); 

		});
		
		function country_geoip_chart_clickthroughs(){ 
			new Ajax.Updater(
				'country_geoip_chart_clickthroughs', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'country_geoip_chart',
						mid:     '<!-- tmpl_var mid -->',
						type:    'clickthroughs'
					},
				onCreate: 	 function() {
					$('country_geoip_chart_clickthroughs_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('country_geoip_chart_clickthroughs_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('country_geoip_chart_clickthroughs');
				}	
				});
		}
		
		function country_geoip_chart_opens(){ 
			new Ajax.Updater(
				'country_geoip_chart_opens', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'country_geoip_chart',
						mid:     '<!-- tmpl_var mid -->',
						type:    'opens'
					},
				onCreate: 	 function() {
					$('country_geoip_chart_opens_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('country_geoip_chart_opens_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('country_geoip_chart_opens');
				}	
				});
		}
		
		function country_geoip_chart_forwards(){ 
			new Ajax.Updater(
				'country_geoip_chart_forwards', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'country_geoip_chart',
						mid:     '<!-- tmpl_var mid -->',
						type:    'forward_to_a_friend'
					},
				onCreate: 	 function() {
					$('country_geoip_chart_forwards_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('country_geoip_chart_forwards_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('country_geoip_chart_forwards');
				}	
			});
		}
		
		
		
		function country_geoip_chart_view_archive(){ 
			new Ajax.Updater(
				'country_geoip_chart_view_archive', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'country_geoip_chart',
						mid:     '<!-- tmpl_var mid -->',
						type:    'view_archive'
					},
				onCreate: 	 function() {
					$('country_geoip_chart_view_archive_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('country_geoip_chart_view_archive_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('country_geoip_chart_view_archive');
				}	
			});
		}
		
		
		
		function ct_ot_img(){ 
			new Ajax.Updater(
				'ct_ot_img', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'data_ot_img',
						mid:     '<!-- tmpl_var mid -->',
						type:    'clickthroughs'
					},
				onCreate: 	 function() {
					$('ct_ot_img_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('ct_ot_img_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('ct_ot_img');
				}	
				});
		}
		function opens_ot_img(){ 
			new Ajax.Updater(
				'opens_ot_img', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'data_ot_img',
						mid:     '<!-- tmpl_var mid -->',
						type:    'opens'
					},
				onCreate: 	 function() {
					$('opens_ot_img_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('opens_ot_img_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('opens_ot_img');
				}	
				});
		}
		function forwards_ot_img(){ 
			new Ajax.Updater(
				'forwards_ot_img', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'data_ot_img',
						mid:     '<!-- tmpl_var mid -->',
						type:    'forward_to_a_friend'
					},
				onCreate: 	 function() {
					$('forwards_ot_img_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('forwards_ot_img_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('forwards_ot_img');
				}	
			});
		}	
		
		
		function view_archive_ot_img(){ 
			new Ajax.Updater(
				'view_archive_ot_img', '<!-- tmpl_var Plugin_URL -->', 
				{ 
				    method: 'post', 
					parameters: {
						f:       'data_ot_img',
						mid:     '<!-- tmpl_var mid -->',
						type:    'view_archive'
					},
				onCreate: 	 function() {
					$('view_archive_ot_img_loading').update('<p class="alert">Loading...</p>');
				},
				onComplete: 	 function() {
					$('view_archive_ot_img_loading').update('<p class="alert">&nbsp;</p>');
					Effect.BlindDown('view_archive_ot_img');
				}	
			});
		}
		
			
	    //]]>
	</script>
	<!-- tmpl_if chrome --> 
		
		  <p id="breadcrumbs">
	        <a href="<!-- tmpl_var Plugin_URL -->">
			 <!-- tmpl_var Plugin_Name -->
		</a> &#187; <!-- tmpl_var subject escape="HTML" --> 
	   </p>

	<!-- /tmpl_if --> 
	
	<!-- tmpl_if chrome --> 
		
		<h1>Tracking Info For: 
		 <!-- tmpl_var subject escape="HTML" --> 
		</h1> 
	
	<!-- /tmpl_if --> 


	<fieldset> 
	<legend>The Basics</legend> 

	<div style=" border: 1px solid black;">
 	<table class="stripedtable">
		<tr style="background:#fff">
	<tr> 
	<td>
	<p>
	 <strong> 
	  Subscribers 
     </strong> 
    </p>
	</td> 
	<td> 
	 </p> 
	<!-- tmpl_if num_subscribers --> 
		<!-- tmpl_var num_subscribers -->
	<!-- tmpl_else --> 
		???
	<!-- /tmpl_if -->
	</p> 
	</td>
	</tr> 



	<tr class="alt">
	<td> 
	 <p>
	  <strong>
	    Clickthroughs
	  </strong> 
	 </p> 
	 </td> 
	 <td> 
	 <p>
	  <!-- tmpl_var clickthroughs -->
	 </p>
	</td> 
	</tr>
		
	
	<tr style="background:#fff">
	<td> 
	 <p>
	  <strong>
	   	 Opens
	  </strong> 
	 </p> 
	 </td> 
	 <td> 
	 <p>
	  <!-- tmpl_var opens --> 
	 </p>
	</td> 
	</tr>
	
	
	<tr class="alt">
	<td> 
	 <p>
	  <strong>
	   Archive Views
	  </strong> 
	 </p> 
	 </td> 
	 <td> 
	 <p>
	  <!-- tmpl_var view_archive --> 
	 </p>
	</td> 
	</tr>
	
	
	
	<tr>
	<td> 
	 <p>
	  <strong>
	   Forwards
	  </strong> 
	 </p> 
	 </td> 
	 <td> 
	 <p>
	  <!-- tmpl_var forward_to_a_friend --> 
	 </p>
	</td> 
	</tr>
	
	
	<tr class="alt">
	<td> 
	 <p>
	  <strong>
	   Bounces (soft/hard)
	  </strong> 
	 </p> 
	 </td> 
	 <td> 
	 <p>
	  <!-- tmpl_var soft_bounce default="0" -->/<!-- tmpl_var hard_bounce -->
	 </p>
	</td> 
	</tr>	
	
	</table> 
	


	</fieldset>
		
	<fieldset> 
	<legend> 
		Clickthroughs by URL
	</legend> 
	
	<!-- tmpl_if url_report --> 
	
	
	<div style="max-height: 200px; overflow: auto; border: 1px solid black;">
 	<table class="stripedtable">
	
		<tr style="background:#fff"> 
		<td> 
			<p><strong>URL</strong></p> 
		</td> 
		<td> 
			<p><strong># Clickthroughs</strong></p>
		</td> 
		</tr> 
		
		
		
			<!-- tmpl_loop url_report --> 
			<tr <!-- tmpl_if __odd__>class="alt"<!-- /tmpl_if -->> 
			 <td> 
			 <p> 
	

	<!-- tmpl_if comment --> 
			    <a href="<!-- tmpl_var Plugin_URL -->?f=url&mid=<!-- tmpl_var mid -->&url=<!-- tmpl_var url escape="HTML" -->"> 
	<!-- /tmpl_if --> 

					<a href="<!-- tmpl_var url -->" target="_blank"> 
					<!-- tmpl_var url escape="HTML" -->
					</a> 
					<!-- tmpl_if comment --> 
					</a> 
					<!-- /tmpl_if --> 
						
			</p> 
			</td> 
			<td> 
			 <p>
				<!-- tmpl_var count --> 
			 </p> 
			</td> 
			</tr> 
		
	    <!-- /tmpl_loop --> 

	
	</table> 
	</div> 
	<!-- tmpl_else -> 
	
		<p class="alert">Nothing to report.</p> 
		
	<!-- /tmpl_if --> 
	
	
</fieldset> 

<!-- tmpl_if can_use_country_geoip_data --> 


<fieldset> 
<legend> 
	Clickthroughs by Country
</legend>

<div id="country_geoip_chart_clickthroughs_loading"> 
</div> 
<div id="country_geoip_chart_clickthroughs"> 
</div>


</fieldset> 

<!-- /tmpl_if --> 





<fieldset> 
<legend>Clickthroughs Over Time</Legend> 
<div id="ct_ot_img_loading"> 
</div> 
<div id="ct_ot_img"> 
</div> 
</fieldset>


<!-- tmpl_if can_use_country_geoip_data --> 
<fieldset> 
<legend> 
	Message Opens by Country
</legend>
	<div id="country_geoip_chart_opens_loading"> 
	</div> 
	<div id="country_geoip_chart_opens"> 
	</div>
</fieldset>
<!-- /tmpl_if --> 

<fieldset> 
<legend>Message Opens Over Time</Legend> 
<div id="opens_ot_img_loading"> 
</div> 
<div id="opens_ot_img"> 
</div> 
</fieldset>



<!-- tmpl_if can_use_country_geoip_data --> 
<fieldset> 
<legend> 
	Archive Views by Country
</legend>

<div id="country_geoip_chart_view_archive_loading"> 
</div> 
<div id="country_geoip_chart_view_archive"> 
</div> 
</fieldset>
<!-- /tmpl_if --> 


<fieldset> 
<legend>Archive Views Over Time</Legend> 
<div id="view_archive_ot_img_loading"> 
</div> 
<div id="view_archive_ot_img"> 
</div> 
</fieldset>




<!-- tmpl_if can_use_country_geoip_data --> 
<fieldset> 
<legend> 
	&quot;Forward to a Friend&quot; by Country
</legend>

<div id="country_geoip_chart_forwards_loading"> 
</div> 
<div id="country_geoip_chart_forwards"> 
</div> 
</fieldset>
<!-- /tmpl_if --> 


<fieldset> 
<legend>&quot;Forward to a Friend&quot; Over Time</Legend> 
<div id="forwards_ot_img_loading"> 
</div> 
<div id="forwards_ot_img"> 
</div> 
</fieldset>






<fieldset> 
<legend>Bounces</legend> 
<!-- tmpl_if soft_bounce_report --> 
<fieldset> 
<legend>Soft Bounces</legend> 

 
<div> 
	<div style="max-height: 300px; overflow: auto; border:1px solid black;width:500px">
	
	<table style="background-color: rgb(255, 255, 255);" border="0" cellpadding="2" cellspacing="0"  width="500">
	 <tr> 
	  <td> 
	   <strong>Date</strong>
	  </td> 
	  <td> 
	   <strong>Email Address</strong>
	  </td> 
	 </tr> 
	
	<!-- tmpl_loop soft_bounce_report --> 
	<tr <!-- tmpl_if __odd__>class="alt"<!-- /tmpl_if -->> 
	  <td> 
	   <!-- tmpl_var timestamp --> 
	  </td> 
	  <td> 
	   <a href="./dada_bounce_handler.pl?flavor=cgi_bounce_score_search&query=<!-- tmpl_var email escape="URL" -->">
		<!-- tmpl_var email --> 
	  </td> 
	 </tr> 
	
	
	<!-- /tmpl_loop --> 
	</table> 
		<p style="text-align:right"><strong>Total:</strong> <!-- tmpl_var soft_bounce -->&nbsp;</p> 
	</div> 

	</div> 
	<p>
	<img src="<!-- tmpl_var soft_bounce_image -->" style="border:1px solid black" /> 
	<p>
	
	</fieldset> 
<!-- tmpl_else --> 
<p class="alert">No soft bounces to report.</p> 
<!-- /tmpl_if --> 

<!-- tmpl_if hard_bounce_report --> 
<fieldset> 
<legend>Hard Bounces</legend>
<div> 
	<div style="max-height: 300px; overflow: auto; border:1px solid black; width:500px">
		<table style="background-color: rgb(255, 255, 255);" border="0" cellpadding="2" cellspacing="0" width="500">
	 <tr> 
	  <td> 
	   <strong>Date</strong>
	  </td> 
	  <td> 
	   <strong>Email Address</strong>
	  </td> 
	 </tr> 
	
	<!-- tmpl_loop hard_bounce_report --> 
	<tr <!-- tmpl_if __odd__>class="alt"<!-- /tmpl_if -->> 
	  <td> 
	   <!-- tmpl_var timestamp --> 
	  </td> 
	  <td> 
	   <a href="./dada_bounce_handler.pl?flavor=cgi_bounce_score_search&query=<!-- tmpl_var email escape="HTML" -->">
		<!-- tmpl_var email --> 
	  </td> 
	 </tr> 
	
	
	<!-- /tmpl_loop --> 
	</table> 
	<p style="text-align:right"><strong>Total:</strong> <!-- tmpl_var hard_bounce -->&nbsp;</p> 
	
	
	</div> 
	</div> 
	
	<p>
	<img src="<!-- tmpl_var hard_bounce_image -->" style="border:1px solid black" /> 
	<p>
	
	</fieldset> 
	<!-- tmpl_else --> 
	<p class="alert">No hard bounces to report.</p>	
<!-- /tmpl_if -->
</legend> 
</fieldset> 




<!-- tmpl_if chrome -->

	<fieldset> 
	<legend>Export Message Logs</legend> 

	<div class="buttonfloat">
	<form action="<!-- tmpl_var PluginURL -->" method="post"> 
	<input type="hidden" name="f" value="download_activity_logs" /> 
	<input type="hidden" name="mid" value="<!-- tmpl_var mid -->" />
	 <input type="submit" class="processing" name="process" value="Download Raw Activity Logs (.csv)" />
	</form> 
	</div>


	<div class="buttonfloat">
	<form action="<!-- tmpl_var PluginURL -->" method="post"> 
	<input type="hidden" name="f" value="download_clickthrough_logs" /> 
	<input type="hidden" name="mid" value="<!-- tmpl_var mid -->" />
	 <input type="submit" class="processing" name="process" value="Download Raw Clickthrough Logs (.csv)" />
	</form> 
	</div>
	<div class="floatclear"></div>
	</fieldset> 

<!-- /tmpl_if chrome -->

};

}

sub message_report {

	my $mid = $q->param('mid'); 
	$mid =~ s/\.(.*?)$//;
	$q->param('mid', $mid); 
	
	my $chrome = 1; 
	if(defined($q->param('chrome'))){ 
		$chrome = $q->param('chrome') || 0; 
	}
	my $Plugin_Url = $Plugin_Config->{Plugin_URL}; 
	if(defined($q->param('tracker_url'))){ 
		$Plugin_Url = $q->param('tracker_url');
	}
	
#	die '$Plugin_Url ' . $Plugin_Url; 
	
	
    my $m_report = $rd->report_by_message( $q->param('mid') );

	# This is strange, as we have to first break it out of the data structure, 
	# and stick it back in: 
	
	my $u_url_report = {}; 
	foreach(@{$m_report->{url_report}}){ 
		$u_url_report->{$_->{url}} = $_->{count}; 
	}
	my $s_url_report = []; 
	foreach my $v (sort {$u_url_report->{$b} <=> $u_url_report->{$a} }
	           keys %$u_url_report)
	{
		 push(@$s_url_report, {url => $v, count => $u_url_report->{$v}}); 
	}
	
	my ($soft_bounce_image, $hard_bounce_image) = bounces_by_domain($m_report); 
	
	
	my %tmpl_vars = (
		mid                        => $q->param('mid')                            || '',
        subject                    => find_message_subject( $q->param('mid') )    || '',
        url_report                 => $s_url_report                               || [],
        num_subscribers            => commify($m_report->{num_subscribers})       || 0,
        opens                      => commify($m_report->{'open'})                || 0, 
        clickthroughs              => commify($m_report->{'clickthroughs'})       || 0, 
		soft_bounce                => commify($m_report->{'soft_bounce'})         || 0,
        hard_bounce                => commify($m_report->{'hard_bounce'})         || 0,
		view_archive               => commify($m_report->{'view_archive'})        || 0, 
		forward_to_a_friend        => commify($m_report->{'forward_to_a_friend'}) || 0,
		soft_bounce_report         => $m_report->{'soft_bounce_report'}           || [],
		hard_bounce_report         => $m_report->{'hard_bounce_report'}           || [],
		soft_bounce_image          => $soft_bounce_image, 
		hard_bounce_image          => $hard_bounce_image, 
		can_use_country_geoip_data => $rd->can_use_country_geoip_data, 
		Plugin_URL                 => $Plugin_Url,
		Plugin_Name                => $Plugin_Config->{Plugin_Name},
		chrome                     => $chrome, 
	); 
	my $tmpl = message_report_tmpl();
	my $scrn = ''; 
	require DADA::Template::Widgets;
    	
	if($chrome == 0){ 
		print $q->header();
	    $scrn = DADA::Template::Widgets::screen(
	        {
	            -data           => \$tmpl,
	            -vars => {
					%tmpl_vars, 
	            },
	        },
	    );
	}
	else { 
		 $scrn = DADA::Template::Widgets::wrap_screen(
		        {
		            -data           => \$tmpl,
		            -with           => 'admin',
		            -wrapper_params => {
		                -Root_Login => $root_login,
		                -List       => $ls->param('list'),
		            },
		            -vars => {
						%tmpl_vars, 
		            },
		        },
		    );		
	}
    e_print($scrn);

}


sub bounces_by_domain { 

	my $m_report = shift; 
		 
	return (
		by_domain_img(
			$m_report->{'soft_bounce_report'}
		), 
		by_domain_img(
			$m_report->{'hard_bounce_report'}
		)
	); 
}

sub by_domain_img { 
	my $domains = shift; 
	my $count   = shift || 15; 
	
	my $data = {};
	
	for my $bounce_report(@$domains ){ 

		my $email = $bounce_report->{email};

		my ($name, $domain) = split('@', $email); 
		if(!exists($data->{$domain})){ 
			$data->{$domain} = 0;
		}
		$data->{$domain} = $data->{$domain} + 1; 	
	}
	# Sorted Index
	my @index = sort { $data->{$b} <=> $data->{$a} } keys %$data; 
	
	# Top n
	my @top = splice(@index,0,($count-1));
	
	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $data->{$_};
	}
	my $final = {};
	foreach(@top){ 
		$final->{$_} = $data->{$_};
	}
	if($other > 0){ 
		$final->{other} = $other;
	}
	my @values = (); 
	my @labels = (); 
	foreach(keys %$final){ 
		push(@values, $final->{$_}), 
		push(@labels, $_ . ' - ' . $final->{$_} ); 	
	}
	
	require URI::GoogleChart; 
	my $chart = URI::GoogleChart->new("pie", 480, 300,
	    data => [@values],
	    rotate => -90,
	    label => [@labels],
	    encoding => "s",
	    background => "white",
		margin => [150, 150, 10, 10],
		title => '',
	);
	
	use HTML::Entities;
	my $enc_chart = encode_entities($chart);
	
	
}

sub country_geoip_chart_tmpl{ 
	return q{ 
		<!-- tmpl_if c_geo_ip_report --> 
			<table cellpadding="5" cellspacing="0" border="0"> 
			<tr> 
			<td> 
			
			<div> 
				<div style="max-height: 225px; overflow: auto; border:1px solid black">
			 	<table style="background-color: rgb(255, 255, 255);" border="0" cellpadding="2" cellspacing="0">
			<tr style="background:#fff"> 
			<td> 
			<p><strong>Country</strong></p> 
			</td> 
			<td>
			<p><strong><!-- tmpl_var type --></strong></p> 
			</td> 
			</tr> 

			<!-- tmpl_loop c_geo_ip_report --> 
			<tr <!-- tmpl_if __odd__> class="alt"<!-- /tmpl_if -->> 
			<td>
			<!-- tmpl_var country --> 
			</td> 
			<td align="right"> 
			<!-- tmpl_var count --> 
			</td> 
			</tr> 
			<!-- /tmpl_loop --> 
			</table> 
			</div> 
			</div> 

			</td> 
			<td> 
			<p>
			 <img src="<!-- tmpl_var c_geo_ip_img -->" style="border:1px solid black" />
			</p> 
			</td> 
			</table>
		<!-- tmpl_else --> 
			<p class="alert">Nothing to report.</p> 
		<!-- /tmpl_if --> 
		
			<!-- tmpl_unless chrome --> 
				</body> 
				</html> 
				
			<!-- /tmpl_unless -->
	};
}
sub country_geoip_chart {
		my $mid  = $q->param('mid')   || undef; 
		my $type = $q->param('type') || undef; 

		my ($c_geo_ip_report, $c_geo_ip_img) = country_geoip_data(
				{ 
					-mid  => $mid, 
					-type => $type, 
				}
			); 
			
		my $tmpl = country_geoip_chart_tmpl(); 
		
	    require DADA::Template::Widgets;
	    my $scrn = DADA::Template::Widgets::screen(
	        {
	            -data           => \$tmpl,
				-vars => { 
					c_geo_ip_report => $c_geo_ip_report, 
					c_geo_ip_img    => $c_geo_ip_img,
					type            => ucfirst($type),
				}
	        }
	    );
		print $q->header(); 
	    e_print($scrn);
	
}

sub country_geoip_data {
	 
	my ($args) = @_;
	
	$args->{-db} = $Plugin_Config->{Geo_IP_Db}; 
	
	my $report = $rd->country_geoip_data($args); 

	my @country = (); 
	my @number  = (); 
	foreach(keys %$report){ 
		next if $_ eq 'unknown'; 
		push(@country, $_); 
	 	push(@number , $report->{$_}); 
	}
	my $chld = join('', @country);
	require URI::GoogleChart;
	my $chart = URI::GoogleChart->new("world", 440, 220,
	    color => ["white", "white", "red"],
	    background => "EAF7FE", # water blue
	    chld => $chld,
	    data => [@number],
	);
	use HTML::Entities;
	my $enc_chart = encode_entities($chart);
	
	require Geography::Countries; 
	my $ht_report = [];
	for ( sort { $report->{$b} <=> $report->{$a} } keys %$report ) {
		
		my $country_name =  Geography::Countries::country($_);
		if(!defined($country_name)){ 
			$country_name = $_; 
		}
		push(@$ht_report, {country_code => $_, country => $country_name, count => $report->{$_}});
	}
	return ($ht_report, $enc_chart); 
	
}



sub url_report_tmpl { 
	
	my $tmpl = q{ 		
		<p>
		 <strong> 
		  Clickthrough Message Summary for: <!-- tmpl_var subject -->
		  for URL: <!-- tmpl_var url --> 
		 </strong> 
	    </p> 

	  <p>
	   <strong> 
	    Clickthrough Time:
	   </strong> 
	 </p> 
	<hr /> 
	
	<table cellpadding="5"> 
	 <!-- tmpl_loop url_report --> 
		<tr>
		 <td> 
		  <p> 
		   <!-- tmpl_var url --> 
		  </p>
		 </td> 
		</tr> 
	 <!-- /tmpl_loop --> 
	</table> 
			
};

}
sub url_report {

	my $tmpl = url_report_tmpl(); 
	
    my $m_report = $rd->report_by_url( $q->param('mid'), $q->param('url') );
	my $url_report = []; 	
    for ( sort { $a <=> $b } @$m_report ) {
		push (@$url_report, {url => $_});
    }
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $ls->param('list'),
            },
			-vars => { 
				mid        => $q->param('mid'), 
				subject    => find_message_subject( $q->param('mid') ), 
				url        => $q->param('url'),
				url_report => $url_report,
			}
        }
    );
    e_print($scrn);

}




sub find_message_subject {
    my $mid = shift;
    if ( $mja->check_if_entry_exists($mid) ) {
        return $mja->get_archive_subject($mid) || '#' . $mid;
    }
    else {
        return '#' . $mid;
    }
}

sub commify {
    local $_  = shift;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}



=pod

=head1 Tracker - tracker.cgi

The Tracker plugin creates fancy reports of  activity and link 
clickthroughs from your mass mailing messages. 

You can think of a mass mailing being a "campaign" if you'd like. 

The activities that are logged and reported include: 

=over

=item * # subscribers when a mass mailing was sent out

=item * # of recorded clickthroughs 

=item * # of recorded opens/views

=item * # bounces, both soft and hard

=back

=head2 Birds-Eye View

These fancy reports include the above information in tabular data, as well 
as in a line graph, for past mass mailings to help you spot general trends. 
This information can also be exported into .csv files, giving you more flexibility, 
specific to your needs. 

The Tracker also displays a pie chart showing the breakdown of your 
current subscribers based on their domain. 

=head2 Individual Messages/Campaigns

Along with the birds-eye view of seeing data of many messages at once, each mass mailing/campaign
can also be explored.

=over

=item * Clickthroughs are broken down per # of clicks per link

=item * Clickthroughs are also broken down by country of origin, displayed in both a 
table and map. 

=item * Message opens are also broken down by country of origin and displayed both in 
a table and map. 

=item * Bounces, both soft and hard bounces are listed by date and email address of the bouncee. 
Clicking on the email address will allow you to view the data about the bounced message itself
in the bounce handler plugin. 

I<(No bounces will be recorded, unless you've separately set up and 
installed the bounce handler plugin that comes with Dada Mail 
called Mystery Girl/dada_bounce_handler.pl)> 

If you suddenly get a ton of bounced messages for a mailing from addresses you know 
look legitimate, there's a good chance that something seriously went wrong in the 
delivery part of a mass mailing. The reports that the Tracker plugin links to 
may help in resolving this problem. 

=back

All this message-specific data can also be exported via .csv files that may be downloaded. 

=head1 Screencasts

=head2 Part 1 

=for html <object width="640" height="510"><param name="movie" value="http://www.youtube.com/v/CKEclo_URW0?fs=1&amp;hl=en_US&amp;rel=0&amp;hd=1"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/CKEclo_URW0?fs=1&amp;hl=en_US&amp;rel=0&amp;hd=1" type="application/x-shockwave-flash" width="640" height="510" allowscriptaccess="always" allowfullscreen="true"></embed></object>

=head2 Part 2

=for html <object width="640" height="510"><param name="movie" value="http://www.youtube.com/v/fGr-0qxcpZ4?fs=1&amp;hl=en_US&amp;rel=0&amp;hd=1"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/fGr-0qxcpZ4?fs=1&amp;hl=en_US&amp;rel=0&amp;hd=1" type="application/x-shockwave-flash" width="640" height="510" allowscriptaccess="always" allowfullscreen="true"></embed></object>

=head1 Installing tracker.cgi

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin manually.

The tracker.cgi plugin comes with Dada Mail. You'll find it in the, I<dada/plugins> directory with the file name, I<tracker.cgi> 

Change its permission to, C<755>. 

=head2 List Control Panel Menu

Now, edit your C<.dada_config> file, so that it shows the Tracker in the left-hand menu, under the, B<Plugins> heading: 

First, see if the following lines are present in your C<.dada_config> file: 

 # start cut for list control panel menu
 =cut

 =cut
 # end cut for list control panel menu

If they are, remove them. 

Then, find these lines: 

 #					{
 #					-Title      => 'Tracker',
 #					-Title_URL  => $PLUGIN_URL."/tracker.cgi",
 #					-Function   => 'tracker',
 #					-Activated  => 1,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{
 					-Title      => 'Tracker',
 					-Title_URL  => $PLUGIN_URL."/tracker.cgi",
 					-Function   => 'tracker',
 					-Activated  => 1,
 					},

Save your C<.dada_config> file.

=head1 Using tracker.cgi

For the most part, the Tracker plugin simply reports data that's collected about your mass mailings. 

=head2 Preferences

You may enabled/disable any of the items Tracker track independently in the plugin's Preferences.

=head3 Enable Clickthrough Tracking

When enabled, allows you to use the Redirect Tags to track links that are clicked on 
in your mass mailing message. 

=head4 Clickthrough Track All Message Links 

When enabled, ALL links found in an email message will be tracked by converting them into 
redirect tags and then clickthrough-tracked links.

=head3 Enable Open Messages Logging

When enabled, allows you to track open/viewing of messages. Will only work with HTML 
messages and only if your subscribers individualy allow images to be shown in email 
messages they receive. 

=head3 Enable Subscriber Count Logging

When enabled, tracks how many subscribers are on your mailing list when each mass
mailing goes out

=head3 Enable "Forward to a Friend" Logging 

When enabled, use of the "Forward to a Friend" function for each message will be counted.  

B<More Information>:
L<http://dadamailproject.com/d/features_forward_to_a_friend.pod.html>

=head3 Enable Archive Views Logging 

When enabled, allows you to track every time a visitor views an archived message. 

=head3 Enable Bounce Logging

When enabled, any bounces, both soft or hard, are tallied up. You will need to have the 
bounce handler installed for this to work. 

=head3 Clean Up Tracker Reports

When enabled, tries to get rid of a lot of the, "line noise" that could be present in 
your logs, because of weird logging behaviour. 

This will also remove opens/clickthroughs and even 
bounces from I<test> messages, so if you are sending a test message and you
want to test out if the clickthrough URLs are working, etc, disable this preference, 
send your test messages and enable it, after you're done. 

=head2 Clickthroughs

Clickthroughs are tracked by creating a "Redirect" tag, that holds the URL you want to track. 

Sounds difficult, so let's break it down. 

If you have a PlainText message you want to send and you want to track who clicks on a specific link, say, 

 http://example.com

You would write this URL inside a redirect tag, like this: 

 <?dada redirect url="http://example.com" ?>

Replace, "http://example.com" with whatever URL you would like to track.

This redirect tag will be replaced by Dada Mail with a URL that, when clicked, will record 
the click and redirect your user to the URL you specified within the tag. 

In an HTML message, you would craft the redirect tag the same way, except that the redirect tag goes
within the, "href" paramater of the, "a" tag. Again, this sounds difficult, but for example: 

If you have a link created like this: 

	<a href="http://example.com">
	 Go to my Example site!
	</a> 

You would simply, like before replace, 

 http://example.com

 with the redirect tag, 

 <?dada redirect url="http://example.com" ?>

and put this inside the href parameter, like this: 

<a href="<?dada redirect url="http://example.com" ?>">
 Go to my Example site!
</a>

If you have messages where you want to track many, many links and the above 
sounds tedious and easy to mess up, or your authoring workflow doesn't 
play nice with these redirect tags, there is an option in the preferences labeled,

B<Clickthrough Track All Message Links> 

Which will do all this for you, automatically. Any links that you have manually 
added a redirect tag to will be untouched, just in case. 

=head3 Backwards Compatibility with the [redirect=] tag

Past versions of Dada Mail (before v4.5.0) used a different syntax for redirect URLs. 
The syntax looked like this: 

 [redirect=http://example.com]

This tag format is still supported, but consider it deprecated. 

=head3 Clickthrough Tags and WYSIWYG editors (FCKeditor/CKeditor) 

In-browser WYSIWYG editors, like FCKeditor and CKeditor have a hard time working with Dada Mail's redirect tags, 
and will corrupt the tags by turning many of the characters into their entities, like this: 

	<a href="&lt;?dada redirect url=&quot;http://example.com&quot; ?&gt;">
	 Go to my Example site!
	</a>

If you use FCKeditor or CKeditor with Dada Mail, we suggest using the, B<Clickthrough 
Track All Message Links> option in Dada Mail, or disable FCKeditor/CKeditor.  

Copying and pasting HTML from a separate program which does not corrupt the tag 
(like Dreamweaver),  will still be affected, if you simply paste the HTML into FCKeditor/CKeditor, 
even if you do it into the HTML Source. 

For most other Desktop-based WYSIWYG editors, including Dreamweaver, 
double-check that the editor does not corrupt the redirect tag. 

=head3 Limitations of Redirect tags

One thing that you cannot do with the redirect tags, is embedd other Dada Mail Template Tags within the redirect tag.

This will not work: 

 <?dada redirect url="http://example.com/index.html?email=<!-- tmpl_var subscriber.email -->" ?>

=head3 Capturing Additional Paramaters with Redirect Tags

It is possible to capture and log additional paramaters in the redirect tags, besides the 
URL clicked on. For example, you can craft a redirect tag, like this: 

 <?dada redirect url="http://example.com" custom_param="some value" ?>

Where, C<custom_param> is the additional paramater you'd like to capture and, C<some value> is the value you'd like
to save. The value can be different for different links, in different messages, across different messages, etc. 

B<Treat this feature as experimental.> The Tracker plugin will not display additional paramater data, 
but the data can be found in the downloadable .csv files created by the Tracker Plugin. 

Before using your additional paramaters, make sure both the C<dada_clickthrough_urls> 
and C<dada_clickthrough_url_log> tables both hold a column named the same as this paramater as the last column. 

In our above example, the following SQL will do the job: 

	ALTER TABLE dada_clickthrough_urls    ADD custom_param TEXT;
	ALTER TABLE dada_clickthrough_url_log ADD custom_param TEXT;

You may add as many different params as you would like. 

=head2 Open Message Logging 

Open Message Logging allows you to keep count of how many times a message is viewed
by your subscribers. 

=head3 Limitations of Open Message Logging

Open Message Logging will only work with HTML messages, since the Open Message logger works simply 
by embedding a small image within your message and counting how many times this images is 
requested. 

Open Message Logging will also only work if your subscribers allow images to be displayed within 
an HTML message. 

Because of this, one should never look at the logged open messages and the subscriber count 
and make a I<precise> observation over the "impact" of your message (how many people are looking at it) 
but simply gleam a general trend of your messages: are they reaching people, is the general 
amount of logged opens increasing, decreasing or staying the same? That sort of thing. 

=head2 Subscriber Count Logging 

Subscriber Count Logging simply records how many subscribers are on your mailing list, 
at the time a mass mailing goes out. 

Subscriber Count Logging does not work by tallying up all individual subscribers/unsubscribes, 
so the graph created will tend to look fairly normalized. 

=head1 Specific Plugin Config Variables

These variables have defaults saved in this plugin itself, but encourage you to 
reset the defaults to the values you may want, instead in your C<.dada_config> file, 
in the, C<$PLUGIN_CONFIGS> variable, under the, C<Tracker> entry

=head2 Plugin_Name

The name of this plugin 

=head2 Plugin_URL

The URL of this plugin. This is usually found by default, but sometimes the default
doesn't work correctly. If this happens to you, fill it out in this variable

=head2 Geo_IP_Db

This variable holds the file path to the location ofthe GeoIP database. The GeoIP 
database is a IP Address -> Location lookup table, to quickly and easily figure out 
the location based on the IP Address. 

This database is updated monthly and new copies can be obtained at: 

L<http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz> 

The database is licensed under the LGPL, so it's OK to ship Dada Mail with a copy of 
this database. 

If you find it necessary, you may keep a copy of this database outside of Dada Mail and 
update it regularly and tell this plugin where to find the database to use. 

For more information, see:  

http://search.cpan.org/~borisz/Geo-IP-PurePerl-1.25/lib/Geo/IP/PurePerl.pm

I<This product includes GeoLite data created by MaxMind, available L<from http://www.maxmind.com/>>

=head1 Getting the Most Out of the Tracker Plugin

=head2 Turn On Archiving

Having messages archived allows you to see the message the reports are generated for. Without it, you'll 
just have a long list of dates/numbers to remember about your mass mailings/campaigns. 

You can have archiving enabled, but not show your archives publically. This is a better 
option than disabling archiving completely. 

=head2 Install the Bounce Handler

The bounces that are logged and shown with the Tracker plugin only work if you have the bounce handler installed,
It's installation is a little more trickier than the Tracker plugin, but it's well worth it for data it generates

=head2 Send HTML Messages if you want Message Open logging

Logging of message opens only works when sending HTML messages. If this type of data
is important to you, you'll def. need to send an HTML message. HTML messages need not to be 
overly complicated with formatting, included images, etc. Some small flourishes of formatting 
goes a long way. 

=head2 Try tracking all links in a message

It's interesting to track one or a view links using the redirect tags to track clickthroughs, but another
trend to follow would be how all links in an email message fare against each other. 

=head3 Discussion Lists and Clickthrough Tracking

Discussion Lists may not benefit as much from clickthrough tracking and tracking all lists in a message, since 
the list owner gives up control over the content of a message. Rather, the members of a list create the content and 
having clickthrough URLs in place of the actual URLs written can get in the way of discussions. There's also a chance that 
nefarious URLs can be hidden within a clickthrough URL - not something you want. 

=head2 Sending a Test Message? 

Test message will not be shown in the Tracker's reports. 

=head1 Compatibility with clickthrough_tracking.cgi

The previous iteration of this plugin (tracker.cgi) was called, B<clickthrough_tracker.cgi>. Do not 
use this old plugin with anything newer than v4.5.0 of Dada Mail. It will not work correctly. 

=head2 Upgrade Notes

The below is information for people who have used the B<clickthrough_tracking.cgi> script in past
versions of Dada Mail (before v4.5.0) and want to take advantage of the new Tracker plugin 
and also want to move over the old logged data.

=head3 $ADMIN_MENU

Most likely, you will need to update your C<$ADMIN_MENU> and change over the Clickthrough 
Tracker entry with the new Tracker entry. The piece of code to look for, within the C<$ADMIN_MENU>
variable looks like this: 

					{-Title      => 'Clickthrough Tracking',
					 -Title_URL  => $PLUGIN_URL."/clickthrough_tracking.cgi",
					 -Function   => 'clickthrough_tracking',
					 -Activated  => 1,
					},

You will want to change it to: 

					{-Title      => 'Tracker',
					 -Title_URL  => $PLUGIN_URL."/tracker.cgi",
					 -Function   => 'tracker',
					 -Activated  => 1,
					},

So as not to break everyone's current installations when upgrading and cause less of 
a hassle, a simple  compatibility script called, B<clickthrough_tracking.cgi> 
is currently included with this  distribution so the old C<$ADMIN_MENU> entry 
will continue to work. 

The B<tracker.cgi> plugin comes with support for all the backends of Dada Mail: 
PlainText, MySQL, PostgreSQL and SQLite. The B<clickthrough_tracking.cgi> plugin 
only supported the PlainText backend for all the logs. 

If you run Dada Mail with the Default backend of Dada Mail, are wanting to 
upgrade, there's really nothing you have to do, as the PlainText log formats 
of B<clickthrough_tracking.cgi> and B<tracker.cgi> are exactly the same. 

One notable difference between the PlainText and SQL backends is that no IP
 address data is saved in the PlainText backend. 

If you run Dada Mail with one of the SQL backends, the required additional SQL tables 
will be created automatically for you upon your first run of Dada Mail - no upgrade scripts 
will be needed. If you want to create these tables manually, do so before upgrading. 
The tables to create are called, C<dada_mass_mailing_event_log> and, C<dada_clickthrough_url_log>. 

See the appropriate schema files in, I<dada/extras/SQL> for the exact SQL query to use. 

=head4 Importing Old Clickthrough Logs 

Data saved within the older, PlainText clickthrough logs would have to 
be moved over, 

There is a script called, I<dada_clickthrough_plaintext2sql.pl> located in the, 
I<dada/extras/scripts> directory that will do this conversion. Move it into your, 
I<dada> directory, change its permissions to, C<755> and run it I<once> in your 
web browser. It may take a few minutes to run to completion. 


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


