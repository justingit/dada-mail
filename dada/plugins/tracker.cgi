#!/usr/bin/perl
package tracker; 
use strict;

$|++;

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";

use CGI::Carp qw(fatalsToBrowser);

use DADA::Config 5.0.0 qw(!:DEFAULT);
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


my $Plugin_Config                  = {}; 
$Plugin_Config->{Plugin_Name}      = 'Tracker'; 
$Plugin_Config->{Plugin_URL}       = $q->url; 
$Plugin_Config->{GeoIP_Db}         = '../data/GeoIP.dat'; 
$Plugin_Config->{GeoLiteCity_Db}   = '../data/GeoLiteCity.dat'; 



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
	    'default'                         => \&default,
	    'm'                               => \&message_report,
	    'edit_prefs'                      => \&edit_prefs,
	    'download_logs'                   => \&download_logs,
	    'ajax_delete_log'                 => \&ajax_delete_log,
		'message_history_html'            => \&message_history_html, 
		'message_history_json'            => \&message_history_json, 
		'download_clickthrough_logs'      => \&download_clickthrough_logs, 
		'download_activity_logs'          => \&download_activity_logs, 
		'country_geoip_table'             => \&country_geoip_table, 
		'country_geoip_json'              => \&country_geoip_json,
		'individual_country_geoip_json'   => \&individual_country_geoip_json, 
		'individual_country_geoip_report_table' => \&individual_country_geoip_report_table, 
		'data_over_time_json'             => \&data_over_time_json, 
		'message_bounce_report_table'     => \&message_bounce_report_table, 
		'bounce_stats_json'               => \&bounce_stats_json, 
		'clear_data_cache'                => \&clear_data_cache, 
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

sub default {
	
	if($DADA::Config::SUBSCRIBER_DB_TYPE !~ /SQL/i){ 
		sql_backend_only_message(); 
		return; 
	}
	
	require DADA::MailingList::Subscribers; 
	my $lh       = DADA::MailingList::Subscribers->new({-list => $list});
	
	
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
		 	 
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'plugins/tracker/default.tmpl',
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
				num_subscribers                  => commify($lh->num_subscribers), 
            },
            -list_settings_vars_param => {
                -list   => $list,
                -dot_it => 1,
            },
        }
    );
    e_print($scrn);

}



sub sql_backend_only_message { 
	
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen         => 'plugins/shared/sql_backend_only_message.tmpl',
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $ls->param('list'),
            },, 
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









sub percent { 
	my ($num, $total) = @_; 
	
	my $percent = ($total ? $num/$total : undef);
	   $percent = $percent * 100;
	   $percent = sprintf("%.2f", $percent);
	return $percent; 
}




sub message_history_json { 
	
	my $page = $q->param('page') || 1; 
	
	$rd->message_history_json(
		{
			-page     => $page, 
			-printout => 1
		}
	);


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


sub data_over_time_json { 
	my $mid    = $q->param('mid'); 
	my $type   = $q->param('type');
	my $label  = $q->param('label'); 
	
	$rd->data_over_time_json(
		{
			-mid      => $mid,
			-type     => $type, 
			-label    => $label, 
			-printout => 1
		}
	); 
	
}

sub message_bounce_report_table { 
	my $mid = $q->param('mid'); 
	my $bounce_type = $q->param('bounce_type') || 'soft'; 
	$rd->message_bounce_report_table(
		{
			-mid             => $mid,
			-bounce_type     => $bounce_type, 
			-printout        => 1
		}
	);
}
sub bounce_stats_json { 
		my $mid = $q->param('mid'); 
		my $bounce_type = $q->param('bounce_type') || 'soft'; 
		$rd->bounce_stats_json(
			{
				-mid             => $mid,
				-bounce_type     => $bounce_type, 
				-printout        => 1
			}
		);
		
}


sub clear_data_cache { 
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;
	$dc->flush(
		{
			-list => $list
		}
	); 
	print $q->redirect( -uri => $Plugin_Config->{Plugin_URL} . '?done=1' );
    
}




sub message_history_html { 
	
	my $page = $q->param('page') || 1; 
	require DADA::Template::Widgets;
	my $html; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 
	
	$html = $dc->retrieve(
		{
			-list    => $list, 
			-name    => 'message_history_html', 
			-page    => $page, 
			-entries => $ls->param('tracker_record_view_count'), 
		}
	);
	if(! defined($html)){ 
		
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
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/clickthrough_table.tmpl',
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
		$dc->cache(
			{ 
				-list    => $list, 
				-name    => 'message_history_html', 
				-page    => $page, 
				-entries => $ls->param('tracker_record_view_count'), 
				-data    => \$html, 
			}
		);
	
	}
	print $q->header(); 
    e_print($html);

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
		can_use_country_geoip_data => $rd->can_use_country_geoip_data, 
		Plugin_URL                 => $Plugin_Url,
		Plugin_Name                => $Plugin_Config->{Plugin_Name},
		chrome                     => $chrome, 
	); 
	my $scrn = ''; 
	require DADA::Template::Widgets;
    	
	if($chrome == 0){ 
		print $q->header();
	    $scrn = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_report.tmpl',
	            -vars => {
					%tmpl_vars, 
	            },
	        },
	    );
	}
	else { 
		 $scrn = DADA::Template::Widgets::wrap_screen(
		        {
		            -screen           => 'plugins/tracker/message_report.tmpl',
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



sub country_geoip_table {
	
		
		my $mid  = $q->param('mid')    || undef; 
		my $type = $q->param('type')   || undef; 
		my $label = $q->param('label') || undef; 		
		
		my $html; 

		require DADA::App::DataCache; 
		my $dc = DADA::App::DataCache->new; 

		$html = $dc->retrieve(
			{
				-list    => $list, 
				-name    => 'country_geoip_table' . '.' . $mid . '.' . $type,
			}
		);
		if(! defined($html)){
					
			my $report = $rd->country_geoip_data(
				{ 
					-mid   => $mid, 
					-type  => $type, 
					-label => $label, 
					-db     => $Plugin_Config->{GeoIP_Db},
				}
			);
			for(@$report){ 
				$_->{type} = $type; 
			}	
		    require DADA::Template::Widgets;
		    $html = DADA::Template::Widgets::screen(
		        {
		            -screen             => 'plugins/tracker/country_geoip_table.tmpl',
					-vars => { 
						c_geo_ip_report => $report, 
						type            => $type,
						label           => $label, 
					
					}
		        }
		    );
			$dc->cache(
				{ 
					-list    => $list, 
					-name    => 'country_geoip_table' . '.' . $mid . '.' . $type,
					-data    => \$html, 
				}
			);
		}
		
		print $q->header(); 
	    e_print($html);
	
}

sub country_geoip_json {
	my $mid  = $q->param('mid')    || undef; 
	my $type = $q->param('type')   || undef; 

	my $labels = { 
		clickthroughs       => 'Clickthroughs', 
		opens               => 'Opens', 
		forward_to_a_friend => 'Forwards', 
		view_archive        => 'Archive Views', 
	};
	$rd->country_geoip_json({ 
		-mid      => $mid, 
		-type     => $type, 
		-db       => $Plugin_Config->{GeoIP_Db},
		-label    => $labels->{$type}, 
		-printout => 1,
		});
}
sub individual_country_geoip_json {
	my $mid     = $q->param('mid')     || undef; 
	my $type    = $q->param('type')    || undef; 
	my $country = $q->param('country') || undef; 
	
	$rd->individual_country_geoip_json({ 
		-mid      => $mid, 
		-type     => $type, 
		-db       => $Plugin_Config->{GeoLiteCity_Db},
		-country  => $country, 
		-printout => 1,
		});
}
sub individual_country_geoip_report {
	my $mid     = $q->param('mid')     || undef; 
	my $type    = $q->param('type')    || undef; 
	my $country = $q->param('country') || undef; 
	
	$rd->individual_country_geoip_report({ 
		-mid      => $mid, 
		-type     => $type, 
		-db       => $Plugin_Config->{GeoLiteCity_Db},
		-country  => $country, 
		-printout => 1,
		});
}
sub individual_country_geoip_report_table {
	my $mid     = $q->param('mid')     || undef; 
	my $type    = $q->param('type')    || undef; 
	my $country = $q->param('country') || undef; 
	my $chrome  = $q->param('chrome')  || 0; 
	
	$rd->individual_country_geoip_report_table({ 
		-mid      => $mid, 
		-type     => $type, 
		-db       => $Plugin_Config->{GeoLiteCity_Db},
		-country  => $country, 
		-chrome   => $chrome, 
		-printout => 1,
		Plugin_URL => $Plugin_Config->{Plugin_URL}, 
		});
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
installed the Bounce Handler plugin that comes with Dada Mail)> 

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

=head3 Enable Open Message Logging

When enabled, allows you to track open/viewing of messages. Will only work with HTML 
messages and only if your subscribers individualy allow images to be shown in email 
messages they receive.

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

Replace "http://example.com" with whatever URL you would like to track.

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

=head3 Clickthrough Tags and WYSIWYG editors (CKeditor/Tiny MCE/FCKeditor) 

In-browser HTML WYSIWYG editors have a hard time working with Dada Mail's redirect tags, and will corrupt the tags by turning many of the characters into their entities, like this: 

	<a href="&lt;?dada redirect url=&quot;http://example.com&quot; ?&gt;">
	 Go to my Example site!
	</a>

If you use a WYSIWYG editor with Dada Mail, we suggest using the, B<Clickthrough Track All Message Links> option in Dada Mail, or disable the WYSIWYG Editor.

Copying and pasting HTML from a separate program which does not corrupt the tag (like Dreamweaver),  will still be affected even if you simply paste the HTML into the WYSIWYG editor and
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

=head2 GeoIP_Db

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

There is a script called, I<dada_clickthrough_plaintext_to_sql.pl> located in the, 
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


