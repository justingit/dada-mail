#!/usr/bin/perl
package clickthrough_tracking; 
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
$Plugin_Config->{Plugin_URL}  = $q->url; 
$Plugin_Config->{Plugin_Name} = 'Tracker'; 


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
	    -Function => 'clickthrough_tracking'
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
					Effect.Highlight('show_table_results');
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
					Effect.Highlight('subscriber_history_img');
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
					Effect.Highlight('domain_breakdown_img');
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
							flavor: 'ajax_delete_log', 
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
	
	<div id="show_table_results">
	</div>

	<div id="show_table_results_loading">
		<p class="alert">Loading...</p>
	</div> 

	<div id="subscriber_history_img"> 
	</div> 
	<div id="subscriber_history_img_loading">
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
 Preferences
</legend> 

<form method="post"> 
<input type="hidden" name="f" value="edit_prefs" /> 
<table> 
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
  
</table> 





<div class="buttonfloat">   
 <input type="submit" class="processing" value="Save Clickthrough Preferences" /> 
 </div>
<div class="floatclear"></div>
</form> 
</fieldset> 



<fieldset> 
<legend>Tracker Help</legend> 
<p>
 Clickthrough logging works for URLs in mailing list
 messages when the URLs are placed in the  <code>&lt;!-- redirect ... --&gt;</code> comment. 
</p>

<p>For example:</p> 
<p><code>
&lt;!-- redirect url=&quot;http://example.com&quot; --&gt;
</code></p>
<p>Replace, <code>http://example.com</code> with the URL you want to track clickthroughs. 
</fieldset> 


<fieldset>
<legend> 
 Current Subscribers by Email Address Domain
</legend>  
<div id="domain_breakdown_img"> 
</div> 
<div id="domain_breakdown_img_loading">
</div>
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
	my $num_subs = $lh->num_subscribers();
	
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
		title => 'Total Subscribers: ' . $num_subs,
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
#            -list_settings_vars_param => {
#                -list   => $list,
#                -dot_it => 1,
#            },
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




sub clickthrough_table_tmpl { 
	
	return q{ 

	<!-- tmpl_if report_by_message_index --> 
		
		<table width="100%">
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

			  <table cellpadding="5" cellspacing="0" border="0" width="100%"> 
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
				<tr <!-- tmpl_if __odd__>style="background:#fff"<!-- tmpl_else -->style="background:#ccf"<!-- /tmpl_if -->> 
				 <td> 
		          <p>
		           <strong>
					<!-- tmpl_if message_subject --> 
						<a href="<!-- tmpl_var S_PROGRAM_URL -->?f=view_archive&list=<!-- tmpl_var list -->&id=<!-- tmpl_var mid -->">
							<!-- tmpl_var message_subject escape="HTML" --> 
						</a> 
					<!-- tmpl_else --> 
						#<!-- tmpl_var mid --> (unarchived message)
					<!-- /tmpl_if --> 
		 		   </strong> 
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

    require    DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::screen(
        {
            -data           => \$tmpl,
            -vars => {
                report_by_message_index   => $rd->report_by_message_index({-all_mids => $msg_ids}) || [],
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
                clickthrough_tracking           => 0,
                enable_open_msg_logging         => 0,
                enable_subscriber_count_logging => 0,
                enable_bounce_logging           => 0,
				tracker_record_view_count       => 0,
				tracker_clean_up_reports        => 0, 
            }
        }
    );

    print $q->redirect( -uri => $Plugin_Config->{Plugin_URL} . '?done=1' );
}




sub message_report_tmpl {
    
my $tmpl = q{ 
	
	<!-- tmpl_set name="title" value="Tracker - Message Report" -->
	
	  <p id="breadcrumbs">
        <a href="<!-- tmpl_var Plugin_URL -->">
		 <!-- tmpl_var Plugin_Name -->
	</a> &#187; <!-- tmpl_var subject escape="HTML" --> 
   </p>

	
	<h1>Tracking Info For: 
	 <!-- tmpl_var subject escape="HTML" --> 
	</h1> 
	
	<fieldset> 
	<legend> 
		Clickthroughs
	</legend> 
	
	<div style="max-height: 200px; overflow: auto; border: 1px solid black;">
 	<table style="background-color: rgb(255, 255, 255);" border="0" cellpadding="2" cellspacing="0" width="100%">
	
		<tr style="background:#fff"> 
		<td> 
			<p><strong>URL</strong></p> 
		</td> 
		<td> 
			<p><strong># Clickthroughs</strong></p>
		</td> 
		</tr> 
		
		<!-- tmpl_if url_report --> 
		
			<!-- tmpl_loop url_report --> 
			<tr <!-- tmpl_if __odd__>style="background:#ccf"<!-- tmpl_else -->style="background:#fff"<!-- /tmpl_if -->> 
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
	<!-- /tmpl_if --> 
	
	</table> 
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


<fieldset> 
<legend>Activity</legend> 

	<!-- tmpl_if num_subscribers --> 
		<p>
		 <strong>
		  Number of Subscribers:<!-- tmpl_var num_subscribers -->
		 </strong> 
		</p> 
	<!-- /tmpl_if --> 

		<p> 
		 <strong>
		  Number of Recorded Opens: <!-- tmpl_var opens default="0" --> 
	     </strong> 
	    </p>
	
		<p>
		 <strong>
		  Number of Recorded Soft Bounces: <!-- tmpl_var soft_bounce -->
		 </strong> 
		</p> 
		<!-- tmpl_if soft_bounce_report --> 
			<table cellpadding="5" cellspacing="0"> 
			 <tr> 
			  <td> 
			   <strong>Date</strong>
			  </td> 
			  <td> 
			   <strong>Email Address</strong>
			  </td> 
			 </tr> 
			
			<!-- tmpl_loop soft_bounce_report --> 
			 <tr> 
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
		<!-- /tmpl_if --> 

		<p>
		 <strong>
		  Number of Recorded Hard Bounces: <!-- tmpl_var hard_bounce -->
		 </strong> 
		</p> 
		
		<!-- tmpl_if hard_bounce_report --> 
			<table cellpadding="5" cellspacing="0"> 
			 <tr> 
			  <td> 
			   <strong>Date</strong>
			  </td> 
			  <td> 
			   <strong>Email Address</strong>
			  </td> 
			 </tr> 
			
			<!-- tmpl_loop hard_bounce_report --> 
			 <tr> 
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
		<!-- /tmpl_if -->

		<div class="buttonfloat">
		<form action="<!-- tmpl_var PluginURL -->" method="post"> 
		<input type="hidden" name="f" value="download_activity_logs" /> 
		<input type="hidden" name="mid" value="<!-- tmpl_var mid -->" />
		 <input type="submit" class="processing" name="process" value="Download Raw Activity Logs (.csv)" />
		</form> 
		</div>
		<div class="floatclear"></div>
		
</fieldset> 

	
};

}

sub message_report {

    my $m_report = $rd->report_by_message( $q->param('mid') );

    my $tmpl = message_report_tmpl();
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
                mid        => $q->param('mid')                         || '',
                subject    => find_message_subject( $q->param('mid') ) || '',
                url_report => $m_report->{url_report}                  || [],
                num_subscribers => $m_report->{num_subscribers} || '',
                opens           => $m_report->{'open'} || 0, 
                soft_bounce     => $m_report->{'soft_bounce'}   || 0,
                hard_bounce     => $m_report->{'hard_bounce'}   || 0,
				soft_bounce_report => $m_report->{'soft_bounce_report'}   || [],
				hard_bounce_report => $m_report->{'hard_bounce_report'}   || [],
				Plugin_URL         => $Plugin_Config->{Plugin_URL},
				Plugin_Name        => $Plugin_Config->{Plugin_Name},	
            },
        },
    );
    e_print($scrn);

}



sub url_report_tmpl { 
	
	my $tmpl = q{ 
		<!-- tmpl_set name="title" value="Tracker - URL Report" -->
		
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

=pod

=head1 Clickthrough Tracking - clickthrough_tracking.cgi

clickthrough_tracking.cgi gives you the ability to track:

=over

=item * How many times certain urls are clicked on in your list messages

=item * How many times a message is opened

=item * How many subscribers are present every time a message is sent

=item * "Hard" email Bounces

=back

=head1 Obtaining The Program

The Click Through Tracking plugin can be found in the Magicbook distribution in the, B<plugins> 
directory. 

=head1 Installing clickthrough_tracking.cgi

clickthrough_tracking.cgi should be installed into your dada/plugins directory. Upload the script and change it's permissions to 755. 

Add this entry to the $ADMIN_MENU array ref:

	 {-Title          => 'Clickthrough Tracking', 
	  -Title_URL      => $PLUGIN_URL."/clickthrough_tracking.cgi",
	  -Function       => 'clickthrough_tracking',
	  -Activated      => 1, 
	  },

It's possible that this has already been added to $ADMIN_MENU and all
you would need to do is uncomment this entry.


=head1 Using clickthrough_tracking.cgi

=head2 Creating clickthrough tracking links

Clickthrough tracking works by passing the URL you want to track to a script that keeps track of what URL gets clicked when, then redirecting the user to the real URL. 

To use the clickthrough tracking capabilities, first visit clickthrough_tracking.cgi in your web browser and check, B<Enable Clickthrough Tracking > 

When you write a list message use the special [redirect] tag, instead of just a URL: 

B<Instead of:>

	http://yahoo.com

B<Write:>

    [redirect=http://yahoo.com]

If you're are writing an HTML message, 

B<Instead of:>

	<a href="http://yahoo.com">http://yahoo.com</a>

B<Write:>

	<a href="[redirect=http://yahoo.com]">http://yahoo.com</a>

Make sure: 

=over

=item * You do not put quotes around the URL in the [redirect] tag: 

B<NO!>

 [redirect="http://yahoo.com"]

B<Yes!>

 [redirect=http://yahoo.com]

=item * You do not forget the I<http://> part of the URL:

B<NO!>

 [redirect=yahoo.com]

B<Yes!> 

  [redirect=http://yahoo.com]

If you want, you can use any protocal you want, be it http, ftp, ical, etc.

=back


=head2 Using Open Messages Logging

Be sure to check, B<Enable Open Messages Logging>

Please understand what this feature does - and does not do. 

When this option is checked, Dada Mail will track each time an email message is opened by a mail reader as long as: 

=over

=item * The message is formatted in HTML

PlainText messages cannot be tracked.

=item * The mail reader being used to view your list message has not disabled image viewing 

=back

Even if all these conditions are met, opens may not be logged correctly. Saying all this, you B<should not> use this feature as a hard statistical number, but rather as a sort of barometer of how many people I<may> be reading your message. 

Viewing the message in Dada Mail's own archives will not be tracked. 

The Open Message Logger only logs: 

=over

=item * The list the message was sent from 

=item * The, "Message-ID" of the message itself

=item * The time the message was opened. 

=back

The Open Message Logger DOES NOT log: 

=over

=item * The email address associated with the opening

=item * The IP address associated with the opening

=item * Any other information that can be used to associate a open with a specific subscriber of your list

=back

We find the B<extremely important> that no personal information is tracked. It's not something we'd personally want tracked if we were to be a subscriber to a mailing list.

To clarify how the message opener works, Dada Mail inserts a small image into the source of your HTML message. It looks something like this: 

 <!--open_img-->
 <img src="example.com/cgi-bin/dada/mail.cgi/spacer_image/listshortname/1234/spacer.png" />
 <!--/open_img-->

Where, B<listshortname> is your List Short Name and, B<1234> is the Message-ID.

In our testing using SpamAssassin, this does not raise any flags with its mail filters, but please run your own tests to make sure that your subscribers will still receive your messages.

=head2 Using Subscriber Count Logging

Check, B<Enable Subscriber Count Logging> 

That's it! Nothing more has to be done. 

=head2 Using "Hard" email Bounces Logging

If you have the, Mystery Girl Bounce Handler installed, just check, 

B<Enable Bounce Logging> 

To clarify what this tells you - a brief tutorial on how messages are bounced: 

There are roughly two different types of bounced messages: "soft" bounces - bounces that happen because a mailbox is full, or there's some sort of problem with mail delivery and, "hard" bounces - bounces because the subscriber's mail box just doesn't exist. 

In the context of this tracker, only bounce emails that cause the Mystery Girl bounce handler to remove the address from the subscription list are counted. 

This means, you may receive 100 bounces from your list, but only 10 that will be unsubscribed. Ten bounces will be shown to you when you view the logs. 




=head1 Viewing Clickthrough Information

After a mailing list message has been sent out, the reports may be viewed by visiting clickthrough_tracking.cgi in your browser. 

=head1 FAQ

=over

=item * Does the clickthrough log save which subscriber (email address) clicks on which link?

B<No.> Email addresses aren't saved in the clickthrough logs. The clickthrough tracking is not meant to track individual users, but to get a general idea on what, if any, links people follow from email messages. 

Although the power of being able to track individual subscribers is great, it's also important to remember about people's privacy.

=item * Why are some of my message subjects in the reports a string of numbers? 

If you have deleted the archive entry associated with the message, or don't have archiving turned on, The tracking reports will use the message id associated with the mailing list message you're looking at. 

=item * Where are the clickthrough logs being written? 

Clickthrough logs are named B<listshortname-clickthrough.log>, where I<listshortname> is the list's shortname. 

These files are written in whatever directory you set the $LOGS variable to. If you haven't set the $LOGS variable, they'll get written wherever the $FILES variable is set to. 

=item * What else can I do with the logs? 

You can also fetch the raw clickthrough logs and open them up in a spreadsheet application, such as Excel and create your own reports from them.


=back


=head1 COPYRIGHT 

Copyright (c) 1999 - 2008 

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

