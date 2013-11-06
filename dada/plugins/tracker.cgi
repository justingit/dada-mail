#!/usr/bin/perl
package tracker; 
use strict;

$|++;

$ENV{PATH} = "/bin:/usr/bin";
delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";
BEGIN { 
	my $b__dir = ( getpwuid($>) )[7].'/perl';
    push @INC,$b__dir.'5/lib/perl5',$b__dir.'5/lib/perl5/x86_64-linux-thread-multi',$b__dir.'lib',map { $b__dir . $_ } @INC;
}

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

use Try::Tiny; 

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
		'save_view_count_prefs'           => \&save_view_count_prefs, 
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
		'message_email_report_table'      => \&message_email_report_table, 
		'message_email_report_export_csv' => \&message_email_report_export_csv, 
		'email_stats_json'                => \&email_stats_json, 
		'clear_data_cache'                => \&clear_data_cache, 
		'clear_message_data_cache'        => \&clear_message_data_cache, 
		'export_subscribers'              => \&export_subscribers, 
		
		'message_email_activity_listing_table'  => \&message_email_activity_listing_table, 
		'message_individual_email_activity_report_table' => \&message_individual_email_activity_report_table, 
		
		'the_basics_piechart_json'       => \&the_basics_piechart_json, 
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
			-id      => 'tracker_record_view_count',
			-name    => 'tracker_record_view_count',
			-values  => [qw(5 10 15 20 25 50 75 100)],
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
			-expr => 1, 
            -vars => {
				screen                           => 'using_tracker', 
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

sub message_email_report_table { 
	my $mid = $q->param('mid'); 
	my $type = $q->param('type') || 'soft_bounce'; 
	$rd->message_email_report_table(
		{
			-mid             => $mid,
			-type            => $type, 
			-printout        => 1,
			-vars            => { 
				Plugin_URL => $Plugin_Config->{Plugin_URL}, 
				mid        => $mid, 
				type       => $type, 
			}
		}
	);
}


sub message_email_report_export_csv { 
	my $mid = $q->param('mid'); 
	my $type = $q->param('type') || 'soft_bounce';
	
	my $header = $q->header(
		-attachment => 'email_report-' . $list . '-' . $type . '.' . $mid . '.csv',
		-type       => 'text/csv', 
	);
	print $header;
	
	$rd->message_email_report_export_csv(
		{
			-mid             => $mid,
			-type            => $type, 
		}
	);
}





sub email_stats_json { 
		my $mid = $q->param('mid'); 
		my $type = $q->param('type') || 'soft_bounce'; 
		$rd->email_stats_json(
			{
				-mid             => $mid,
				-type            => $type, 
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

sub clear_message_data_cache { 
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;
	$dc->flush(
		{
			-list   => $list,
			-msg_id => xss_filter(strip($q->param('msg_id'))), 
		}
	); 
	print $q->redirect( -uri => $Plugin_Config->{Plugin_URL} . '?f=m&mid=' . xss_filter(strip($q->param('msg_id'))));
}



sub export_subscribers { 
	
	my $mid = xss_filter($q->param('mid')); 
	my $type = xss_filter($q->param('type')); 
	if($type ne 'clickthroughs' && $type ne 'opens'){ 
		$type = 'clickthroughs'; 
	}
	
	my $header  = 'Content-disposition: attachement; filename=' 
			      . $list 
			      . '-' 
			      . $type 
			      . '-subscribers-' 
			      . $mid 
			      . '.csv' 
			      .  "\n";
	
	$header .= 'Content-type: text/csv' . "\n\n";
    print $header;

   $rd->export_by_email(
		{
			-type => $type, 
			-mid  => $mid, 
			-fh   => \*STDOUT
		}
	);
	
	 
}

sub message_email_activity_listing_table { 
	
	my $mid = xss_filter($q->param('mid')); 	
   	$rd->message_email_activity_listing_table(
		{
			-mid  => $mid,
			-vars => { 
				mid  => $mid, 
				type => 'email_activity', 
			}
		}
	);
}

sub message_individual_email_activity_report_table { 

	my $mid   = xss_filter($q->param('mid')); 
	my $email = xss_filter($q->param('email')); 
	print $q->header(); 
	print $rd->message_individual_email_activity_report_table(
		{
			-mid    => $mid, 
			-email  => $email, 

		}
	);
}

sub the_basics_piechart_json { 
	my $mid   = xss_filter($q->param('mid')); 
	my $type  = xss_filter($q->param('type')); 
	my $label = xss_filter($q->param('label')); 

	$rd->msg_basic_event_count_json(
		{
			-mid      => $mid, 
			-type     => $type, 
			-label    => $label, 
			-printout => 1, 
		}
	);
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
	
	if( defined($html)){ 
		warn 'message_history_html cached in file'; 
	}
	
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

		my $report_by_message_id = $rd->report_by_message_index(
			{
				-all_mids => $msg_ids, #Strange speedup
				-page     => $page,
			}
		) || []; 

	    require    DADA::Template::Widgets;
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/clickthrough_table.tmpl',
	            -vars => {
	                report_by_message_index   => $report_by_message_id,
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



sub save_view_count_prefs { 
	$ls->save_w_params(
    	{ 
			-associate => $q, 
			-settings  => { 
				tracker_record_view_count => 0,
			}
		}
	); 
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;
	$dc->flush(
		{
			-list => $list
		}
	); 
	
	print $q->header(); 
}

sub edit_prefs {

    $ls->save_w_params(
        {
            -associate => $q,
            -settings  => {

                tracker_auto_parse_links                        => 0,
                tracker_auto_parse_mailto_links                 => 0,
                tracker_track_opens_method                      => undef,
                tracker_track_email                             => 0,
                tracker_clean_up_reports                        => 0,
                tracker_show_message_reports_in_mailing_monitor => 0,
            }
        }
    );
    require DADA::App::DataCache;
    my $dc = DADA::App::DataCache->new;
    $dc->flush( { -list => $list } );

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
		
		screen                      => 'using_tracker', 
		
		mid                         => $q->param('mid')                            || '',
        subject                     => find_message_subject( $q->param('mid') )    || '',
        url_report                  => $s_url_report                               || [],
        num_subscribers             => commify($m_report->{num_subscribers})       || 0,
        total_recipients            => commify($m_report->{total_recipients})      || 0,
        opens                       => commify($m_report->{'open'})                || 0, 
        unique_opens                => commify($m_report->{'unique_open'})         || 0, 
        unique_opens_percent        => $m_report->{'unique_opens_percent'}         || 0, 
        clickthroughs               => commify($m_report->{'clickthroughs'})       || 0, 
		unsubscribes                => commify($m_report->{'unsubscribe'})         || 0, 
		unique_unsubscribes_percent => $m_report->{'unique_unsubscribes_percent'}  || 0, 
		soft_bounce                 => commify($m_report->{'soft_bounce'})         || 0,
        hard_bounce                 => commify($m_report->{'hard_bounce'})         || 0,
  		
		errors_sending_to        => commify($m_report->{'errors_sending_to'})      || 0,
		errors_sending_to_percent => $m_report->{'errors_sending_to_percent'}      || 0, 
        received                 => commify($m_report->{'received'})               || 0,
		received_percent          => $m_report->{'received_percent'}               || 0,  
		unique_bounces_percent      => $m_report->{'unique_bounces_percent'}       || 0, 
		view_archive                => commify($m_report->{'view_archive'})        || 0, 
		forward_to_a_friend         => commify($m_report->{'forward_to_a_friend'}) || 0,
		soft_bounce_report          => $m_report->{'soft_bounce_report'}           || [],
		hard_bounce_report          => $m_report->{'hard_bounce_report'}           || [],
		can_use_country_geoip_data  => $rd->can_use_country_geoip_data, 
		Plugin_URL                  => $Plugin_Url,
		Plugin_Name                 => $Plugin_Config->{Plugin_Name},
		chrome                      => $chrome, 		
		
	); 
	my $scrn = ''; 
	require DADA::Template::Widgets;
    	
	if($chrome == 0){ 
		print $q->header();
	    $scrn = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_report.tmpl',
				-expr             => 1, 
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
					-expr             => 1, 
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

The Tracker plugin creates fancy analytic reports of activity of your mass mailings. You can think of a mass mailing being a "campaign" if you'd like. 

The activities that are logged and reported include: 

=over

=item * # subscribers when a mass mailing was sent out

=item * # of recorded clickthroughs 

=item * # of recorded opens/views

=item * # of unsubscribes

=item * # bounces, both soft and hard

=back

=head2 Birds-Eye View

These fancy reports include the above information in tabular data, as well 
as in a line graph, for past mass mailings to help you spot general trends. 
This information can also be exported into .csv files, giving you more flexibility, specific to your needs. 


=head2 Individual Messages/Campaigns

Along with the birds-eye view of seeing data of many messages at once, each mass mailing/campaign can also be explored.

=over

=item * Clickthroughs are broken down per # of clicks per link

=item * Clickthroughs are also broken down by country of origin, displayed in both a  table and map. 

=item * Message opens are also broken down by country of origin and displayed both in  a table and map. 

=item * Bounces, both soft and hard bounces are listed by date and email address of the bouncee. 

Clicking on the email address will allow you to view the data about the bounced message itself in the bounce handler plugin. 

I<(No bounces will be recorded, unless you've separately set up and 
installed the Bounce Handler plugin that comes with Dada Mail)> 

If you suddenly get a ton of bounced messages for a mailing from addresses you know  look legitimate, there's a good chance that something seriously went wrong in the  delivery part of a mass mailing. The reports that the Tracker plugin links to may help in resolving this problem. 

=back

All this message-specific data can also be exported via .csv files that may be downloaded. 

=head1 User Guide

For a guide on using Tracker, see the Dada Mail Manual: 

L<http://dadamailproject.com/pro_dada/using_tracker.html>

For more information on Pro Dada/Dada Mail Manual: 

L<http://dadamailproject.com/purchase/pro.html>


What's below will go into installing the plugin and advanced configuration.

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

=head2 GeoLiteCity_Db

Like, C<GeoIP_Db>, this variables holds the absolute file path to the City Geo IP database. Copies are obtained from, 

L<http://www.maxmind.com/download/geoip/database/GeoLiteCity.dat.xz>

=head1 Compatibility with clickthrough_tracking.cgi

The previous iteration of this plugin (tracker.cgi) was called, B<clickthrough_tracker.cgi>. Do not 
use this old plugin with anything newer than v4.5.0 of Dada Mail. It will not work correctly. 

=head2 Backwards Compatibility with the [redirect=] tag

Past versions of Dada Mail (before v4.5.0) used a different syntax for redirect URLs. 
The syntax looked like this: 

 [redirect=http://example.com]

This tag format is still supported, but consider it deprecated. 

=head2 Limitations of Redirect tags

One thing that you cannot do with the redirect tags, is embedd other Dada Mail Template Tags within the redirect tag.

This will not work: 

 <?dada redirect url="http://example.com/index.html?email=<!-- tmpl_var subscriber.email -->" ?>


=head2 Upgrade Notes

The below is information for people who have used the B<clickthrough_tracking.cgi> script in past
versions of Dada Mail (before v4.5.0) and want to take advantage of the new Tracker plugin 
and also want to move over the old logged data.

=head4 Importing Old Clickthrough Logs 

Data saved within the older, PlainText clickthrough logs would have to 
be moved over, 

There is a script called, I<dada_clickthrough_plaintext_to_sql.pl> located in the, 
I<dada/extras/scripts> directory that will do this conversion. Move it into your, 
I<dada> directory, change its permissions to, C<755> and run it I<once> in your web browser. It may take a few minutes to run to completion. 


=head1 COPYRIGHT 

Copyright (c) 1999 - 2013 Justin Simoni All rights reserved. 

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


