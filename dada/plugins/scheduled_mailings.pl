#!/usr/bin/perl
use strict; 

#---------------------------------------------------------------------#
# scheduled_mailings.pl (Beatitude)
# For instructions, see the pod of this file. try:
#  pod2text ./scheduled_mailings.pl | less
#
# Or try online: 
#  http://dadamailproject.com/support/documentation/scheduled_mailings.pl.html
#
#---------------------------------------------------------------------#
# Required:





$|++; 

#Change! the lib paths

use lib qw(

	../ 
	../DADA/perllib 
	../../../../perl 
	../../../../perllib
);

use CGI::Carp qw(fatalsToBrowser);


use DADA::Config 5.0.0 qw(!:DEFAULT);
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Schedules;

use CGI; 
my $q = new CGI;
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);

my $Plugin_Config = {}; 


#---------------------------------------------------------------------#
# Optional:

$Plugin_Config->{Log} = undef, # Example: $LOGS . '/schedules.txt';


# Usually, this doesn't need to be changed. 
# But, if you are having trouble saving settings 
# and are redirected to an 
# outside page, you may need to set this manually. 

$Plugin_Config->{Plugin_URL} = $q->url; 

$Plugin_Config->{Allow_Manual_Run}    = 1; 

$Plugin_Config->{Manual_Run_Passcode} = undef;

#---------------------------------------------------------------------#
# Nothing else to be configured.                                      #



$Plugin_Config->{Plugin_Name} = 'Beatitude'; 


my $App_Version          = '.6';




my $mss; 
my $list; 
my $li; 
my $Have_Log = 0; 
my $yeah_root_login = 0; 


#---------------------------------------------------------------------#
# a "few" defaults
my $f; 

my %mail_month_values = (
0  => 'January', 
1  => 'February', 
2  => 'March', 
3  => 'April', 
4  => 'May', 
5  => 'June',
6  => 'July', 
7  => 'August', 
8  => 'September', 
9  => 'October', 
10 => 'November', 
11 => 'December', 
); 



my %mail_day_values = (

1  => '1st', 
2  => '2nd', 
3  => '3rd', 
4  => '4th', 
5  => '5th',
6  => '6th', 
7  => '7th', 
8  => '8th', 
9  => '9th', 
10 => '10th', 
11 => '11th',
12 => '12th', 
13 => '13th', 
14 => '14th', 
15 => '15th', 
16 => '16th', 
17 => '17th', 
18 => '18th', 
19 => '19th', 
20 => '20th', 
21 => '21st', 
22 => '22nd', 
23 => '23rd', 
24 => '24th', 
25 => '25th', 
26 => '26th', 
27 => '27th', 
28 => '28th', 
29 => '29th', 
30 => '30th', 
31 => '31st',
); 

my %mail_minute_values = (
0 => '00',
1 => '01', 
2 => '02',
3 => '03',
4 => '04',
5 => '05',
6 => '06',
7 => '07',
8 => '08',
9 => '09',
); 

my %mail_year_values = ( 
103  => 2003,
104  => 2004, 
105  => 2005, 
106  => 2006,
107  => 2007,
108  => 2008, 
109  => 2009, 
110  => 2010,
111  => 2011,
112  => 2012, 
113  => 2013, 
114  => 2014,
115  => 2015,
116  => 2016, 
117  => 2017, 
118  => 2018,
); 

my @hours   = (1..12); 

my @minutes = (0..59); 

my %repeat_label_values = (
	minutes => 'Minute(s)',  
	hours   => 'Hour(s)', 
	days    => 'Day(s)', 
	years   => 'Year(s)'
);


my %d_form_vals = DADA::MailingList::Schedules::schedule_schema();


&init_vars(); 
&main(); 


sub init_vars { 

     while ( my $key = each %$Plugin_Config ) {
        
        if(exists($DADA::Config::PLUGIN_CONFIGS->{Beatitude}->{$key})){ 
        
            if(defined($DADA::Config::PLUGIN_CONFIGS->{Beatitude}->{$key})){ 
                    
                $Plugin_Config->{$key} = $DADA::Config::PLUGIN_CONFIGS->{Beatitude}->{$key};
        
            }
        }
     }
}



sub main { 
	if(!$ENV{GATEWAY_INTERFACE}){ 
		&cl_main(); 
	}else{ 
		&cgi_main(); 
	}
}

#---------------------------------------------------------------------#









	my $help     = 0;
	my $test; 
	my $verbose  = 0; 
	my $log; 
	my $version; 
	my $run_list; 
	
sub cl_main { 
	require Getopt::Long; 

	
	
	
	Getopt::Long::GetOptions(
		   
		   "help"       => \$help, 
		   "test"       => \$test, 
		   "log=s"      => \$log,
		   "version"    => \$version,
		   "verbose"    => \$verbose,
		   "list=s"     => \$run_list,  
		   
		   );

	$Plugin_Config->{Log}            = $log      if $log; 
	$verbose        = 1         if $test; 

	if($version){ 
		&version;
	}
	elsif($help){
		&show_help; 	
	}
	else{ 
	
        cl_run_schedules(
                      -run_list => $run_list,
                      -test     => $test, 
                      -verbose  => $verbose
                     );
	}	    
	
}




sub cl_run_schedules { 

	my %args = (-run_list => undef, 
				-test     => undef, 
				-verbose  => undef,
				@_); 
	
	
	my @lists_to_run; 
	 
	$args{-run_list} ? ($lists_to_run[0] = $args{-run_list}) : (@lists_to_run = DADA::App::Guts::available_lists()); 
	
	for(@lists_to_run){ 
		my $mss = DADA::MailingList::Schedules->new({-list => $_}); 
		   my $report = $mss->run_schedules(-test    => $args{-test});
		   					  				
	
	e_print($report)
	 	if $args{-verbose};
	
	logit($report); 

    } 
}




sub cgi_main { 

    if(keys %{$q->Vars}                        && 
       $q->param('run')                        && 
       xss_filter($q->param('run'))       == 1 &&
       $Plugin_Config->{Allow_Manual_Run} == 1
      ) { 
        cgi_manual_start();
    }
    else { 
        
        
        my ($admin_list, $root_login) = check_list_security(-cgi_obj   => $q, 
                                                            -Function  => 'scheduled_mailings');
                                                                                                                    
    
          $list = $admin_list; 
          $yeah_root_login = $root_login; 
    
          require  DADA::MailingList::Settings; 
          my $ls = DADA::MailingList::Settings->new({-list => $list}); 
             $li = $ls->get; 
          
                                      
        
        
        #---------------------------------------------------------------------#
        
        $mss = DADA::MailingList::Schedules->new({-list => $list}); 
        my $flavor = $q->param('flavor') || 'default';
        my %Mode = ( 
        'default' => \&default, 
        'edit'    => \&edit, 
        'remove'  => \&remove, 
        'run_all' => \&run_all_handler, 
        ); 
        
        if(exists($Mode{$flavor})) { 
            $Mode{$flavor}->();  #call the correct subroutine 
        }else{
            &default;
        }
    }

}




sub cgi_manual_start { 
        
        if(
            (xss_filter($q->param('passcode')) eq $Plugin_Config->{Manual_Run_Passcode}) ||             
            ($Plugin_Config->{Manual_Run_Passcode}              eq ''                  )
            
          ) {
            
            if(defined(xss_filter($q->param('verbose')))){
                $verbose = xss_filter($q->param('verbose'));
            }
            else { 
                $verbose = 1;
            }
            
            
            if(defined(xss_filter($q->param('test')))){
                $test = $q->param('test');
            }
            
            # DEV: Why is this, "$run_list" and simply not, "$list?!"
            if(defined(xss_filter($q->param('list')))){
                $run_list = $q->param('list');
            }
            
            
            
            #if(defined(xss_filter($q->param('messages')))){ 
            #    $Plugin_Config->{MessagesAtOnce} = xss_filter($q->param('messages')); 
            #}
            
            
            print $q->header();
			
        	e_print('<pre>')
        	    if $verbose; 
            cl_main();
            e_print('</pre>')
                if $verbose; 
            

        } else { 
            print $q->header(); 
            print "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Authorization Denied.";
        }
}





sub default {

    my $scrn = '';
    $scrn .= admin_template_header(
        -Title      => "Scheduled Mailings",
        -List       => $list,
        -Form       => 0,
        -Root_Login => $yeah_root_login,

	);

    $scrn .= schedule_index();

    $scrn .= admin_template_footer(
          -Form => 0,
          -List => $li->{list},
    );
    e_print($scrn);

}





sub edit  { 
		
	if($q->param('role') =~ m/remove|delete/i){ 
		remove();
		exit; # DEV: Exit... wah?
	}
	
	
	my $key; 	
	my $message; 
	my $schedule_form; 
	
	
	if($q->param('process') eq 'true'){ 
		if($q->param('role') =~ m/test/i){ 
			$key = $mss->save_from_params({-cgi_obj => $q });
			my $status = test_handler(
				-key => $key,
				-test_recipient => $q->param('test_recipient'), 
			 );
			if(! keys %$status){ 
				$message = '<p class="positive">Your test message has been sent.</p>';
			}else{ 
				$message  = '<p class="error">!!! Message not sent, details:</p>';
				$message .= '<p class="error">!!! '.  DADA::App::Guts::pretty($_)  .'</p>' for keys %$status;
			}
		}else{ 
			$message = '<p class="positive">Your changes have been saved successfully!</p>';
			$key = $mss->save_from_params({-cgi_obj => $q });
			
		}
		$schedule_form = schedule_form($key, $message);
	} elsif($q->param('key')){ 
		$schedule_form = schedule_form($q->param('key'), $message);
	}else{ 
		$schedule_form =  schedule_form(undef,$message);
	}
	

	
	my $scrn = ''; 
	
	$scrn .=  admin_template_header(
						-Title      => "Scheduled Mailings - Edit",
						-List       => $li->{list},
						-Form       => 0,
						-Root_Login => $yeah_root_login,
						-vars => { 
							load_wysiwyg_editor => 1, 
						}
						);

	$scrn .= '<p><a href="' . $Plugin_Config->{Plugin_URL} . '">' . $Plugin_Config->{Plugin_Name} . '</a> &#187 Add/Edit</p>';


	$scrn .=  $schedule_form; 
	$scrn .=  admin_template_footer(-Form    => 0, 
						    -List    => $li->{list},
						); 
						
	e_print($scrn); 
						    
}




sub test_handler { 
	my %args = (
			-key => '', 
			@_
		); 
	if (! $args{-key}){
		die "no key! $!"; 
	}
	
	my ($status, $cs) = $mss->send_scheduled_mailing(
							-key  => $args{-key}, 
							-test => 1,
							-test_recipient => $args{-test_recipient}, 
						);
	return $status; 
}




sub run_all_handler {

    my $scrn = '';
    $scrn .= admin_template_header(
        -Title      => "Manually Running Schedules",
        -List       => $li->{list},
        -Form       => 0,
        -Root_Login => $yeah_root_login
      ); 

      $scrn .=
        '<p><a href="'
      . $Plugin_Config->{Plugin_URL} . '">'
      . $Plugin_Config->{Plugin_Name}
      . '</a> &#187 Manually Running Schedules</p>';

    $scrn .= '<pre>';
    e_print($scrn)
      if $verbose = 1;
    $run_list = $list;

    cl_main();
    my $scrn = '';

    $scrn .= '</pre>';
    $scrn .= '<p><a href="javascript:history.back()">Back...</a></p>';

    $scrn .= admin_template_footer(
          -Form => 0,
          -List => $li->{list},
    );
    print $scrn;
}




sub remove { 


	my $key = $q->param('key'); 
	die "no key!" if ! $key; 
	$mss->remove_record($key);

	print $q->redirect(-uri => $Plugin_Config->{Plugin_URL}.'?message=r'); 	
}




sub schedule_index { 
	
	
	my $r;
	   
    	$r .= '<p><a href="' . $Plugin_Config->{Plugin_URL} . '">' . $Plugin_Config->{Plugin_Name} . '</a></p>';
	
	
	   $r .= "<p class=error>Scheduled Mailing Removed.</p>" if $q->param('message') eq 'r'; 
	   $r .= q{ 
		<fieldset> 
		<legend>Your Schedules</legend>
		
		};
	   
	   
	   $r .= "<table style=\"border: 1px solid black;background:#fff\">\n <tr>"; 
	   $r .= qq{ 
	   	<tr  style="border-bottom:1px solid black"> 
	   		<td><p><strong>Name</strong></p></td>
	   		<td><p><b>Next Mailing</b></p></td>
	   		<td><p>&nbsp;</p></td>
	   	</tr>
	   
	   }; 
	   
	
	my %sched_rows = (); 

	for($mss->record_keys){ 
		my $next_mailing = $mss->mailing_schedule($_)->[0];

		if(!exists($sched_rows{$next_mailing})){ 
			$sched_rows{$next_mailing} = schedule_row($_);
		}
		else { 
			$sched_rows{$next_mailing . '.' . time} = schedule_row($_);
			sleep(1); #dumb; 
		}
	}
	#for(keys)
	for(sort keys %sched_rows){ 
		$r .= $sched_rows{$_}; 
	}	 


	   $r .= '</table>';
	   
	$r .= ($q->p({-align => 'right'}, '<div class="buttonfloat">', 
	
		  $q->startform(-action => $Plugin_Config->{Plugin_URL}, -method => 'GET'), 
		  $q->hidden('flavor', 'edit'), 
		  $q->submit(-class => 'processing', -value => "Add Scheduled Mailing... "), 
		  $q->endform() , '</div>' 
		  )); 
		  
$r .= '</fieldset>'; 


my $manually_run_tmpl = q{ 
	
	<fieldset> 
	 <legend>Manually Run <!-- tmpl_var Plugin_Name --></legend> 
			
	<form action="<!-- tmpl_var Plugin_URL -->">
	<input type="hidden" name="flavor" value="run_all" /> 	
	<div class="buttonfloat"> 
	<input type="submit" class="cautionary" value="Manually Run All Schedules" />
	</div> 
	<div class="floatclear"></div> 
	</form>

	<p>
	 <label for="cronjob_url">Manual Run URL:</label><br /> 
	<input type="text" class="full" id="cronjob_url" value="<!-- tmpl_var Plugin_URL -->?run=1&passcode=<!-- tmpl_var Manual_Run_Passcode -->" />
	</p>

	<!-- tmpl_if curl_location --> 
	<p> <label for="cronjob_command">curl command example (for a cronjob):</label><br /> 
	<input type="text" class="full" id="cronjob_command" value="<!-- tmpl_var curl_location -->  -s --get --data run=1\;passcode=<!-- tmpl_var Manual_Run_Passcode -->\;verbose=0  --url <!-- tmpl_var Plugin_URL -->" />
	<!-- /tmpl_if --> 

	<!-- tmpl_unless Allow_Manual_Run --> 
	    <span class="error">(Currently disabled)</a>
	<!-- /tmpl_unless --> 

	</p>
	</li>
	</ul> 
	</fieldset>
};

my $curl_location = `which curl`; 
   $curl_location = make_safer($curl_location);

$r .= DADA::Template::Widgets::screen(
		{
			-data => \$manually_run_tmpl, 
			-vars => { 
				Plugin_Name        => $Plugin_Config->{Plugin_Name},  
				Plugin_URL          => $Plugin_Config->{Plugin_URL}, 
				Manual_Run_Passcode => $Plugin_Config->{Manual_Run_Passcode}, 
				Allow_Manual_Run    => $Plugin_Config->{Allow_Manual_Run}, 
				curl_location       => $curl_location, 
				
			},
			
			
		}
	); 


	$r .= DADA::Template::Widgets::screen(
			{
				-screen  => 'help_link_widget.tmpl', 
				-vars => { 
					screen => 'scheduled_mailings',
					title  => 'Beatitude User Guide', 
				},


			}
		); 


	return $r; 
}




sub schedule_row {
    my $key = shift;
    my $r;

    my $record           = $mss->get_record($key);
    my $status           = "";
    my $mailing_schedule = $mss->mailing_schedule($key);

    my $row_style;
    if (
        $record->{active} == 0
        || ( ( $mailing_schedule->[-1] < int(time) )
            && $record->{repeat_number} ne 'indefinite' )
      )
    {

        $row_style = 'background-color:#fff';
    }
    else {
        $row_style = 'background-color:#cfc';
    }

    if ( $mailing_schedule->[-1] > int(time) ) {
        if ( $record->{active} == 0 ) {
            $status = $q->p( { -class => 'smallred' },
                $q->i("This schedule is inactive.") );
        }
        else {
            $status = $q->p( { -class => 'smallblack' },
                $q->i( $mss->printable_date( $mailing_schedule->[0] ) ) );
        }
    }
    elsif ($record->{repeat_mailing} == 1
        && $record->{repeat_number} eq 'indefinite' )
    {
        $status = $q->p( { -class => 'smallblack' },
            $q->i( $mss->printable_date( $mailing_schedule->[0] ) ) );
    }
    else {
        $status = $q->p( { -class => 'smallred' },
            $q->i('This scheduled mailing has ended.') );
    }

    $r =
      "<tr style=\"$row_style\"><td><p><strong>"
      . edit_schedule_href( $key, $record )
      . "</strong></p></td><td>$status</td><td>"
      . remove_schedule_form( -key => $key, -label => '[x]' )
      . "</td></tr>";
    return $r;
}





sub edit_schedule_href { 

	my ($key, $record) = @_; 
	$record->{message_name} = 'unnamed scheduled mailing' if ! $record->{message_name};
	return $q->a({-href => $Plugin_Config->{Plugin_URL} . '?flavor=edit&key='.$key}, $record->{message_name}); 

} 




sub schedule_form { 

	my $key     = shift; 
	my $message = shift;; 
	my %form_vals; 



	
	
	if(!$key){ 
		%form_vals = %d_form_vals; 	
	}else{ 
		my $form_vals  = $mss->get_record($key); 
		%form_vals = %$form_vals; 
	}

	my $f; 
	$f .= $message; 
	
	
	$f .= q{

	<fieldset> 
 	<legend>Scheduling Options</legend>

	};
	
	
	$f .= $q->p({-class => "positive"}, 'Server time is: ' . $mss->printable_date(time));
	
		
	$f .= $q->start_form(-action => $Plugin_Config->{Plugin_URL});
	$f .= (
		   $q->p($q->b('Scheduled Message Name:'), 
		   $q->textfield(
		   			     -name => 'message_name', 
		                 -value => $form_vals{message_name}, 
		                 -style => 'width: 300px',
		                ))
		   ); 	
	
	$f .= (
			$q->p(
			$q->checkbox(
						 -name    => 'active', 
						 -id      => 'active', 
						 -value   => 1, 
							  (($form_vals{active} == 1) ? 
							  (-checked => 'checked',) :
							  (-checked => '',)),
						 -label   => '',
						), 
					 $q->label({'for' => 'active'}, 'Active'))
		  );
		  
	
	
	$f .= date_widget(\%form_vals); 
	$f .= repeat_widget(\%form_vals, $key); 
	
$f .= q{

</fieldset> 

	
};


# Message Headers

require DADA::Template::Widgets; 
$f .= DADA::Template::Widgets::screen(
	{
		-screen                        => 'message_headers_fieldset_widget.tmpl', 
		-vars                          => 
			{ 
				priority_popup_menu    => DADA::Template::Widgets::priority_popup_menu($li,    $form_vals{headers}->{'X-Priority'}),
				'Reply-To'             => $form_vals{headers}->{'Reply-To'}, 
				'Errors-To'			   => $form_vals{headers}->{'Errors-To'},
				'Return-Path'          => $form_vals{headers}->{'Return-Path'},
				Subject                => $form_vals{headers}->{Subject}, 
			},
		-list_settings_vars       => $li, # Uh, ok - $li is global. That's stupid. 
		-list_settings_vars_param => 
			{
					-dot_it => 1, 
			},
	}
); 

	   
$f .= q{	
	<fieldset> 
	<legend>Message Body</legend>
};

	
	$f .= message_widget(-type => 'PlainText', -form_vals => \%form_vals); 
	$f .= message_widget(-type => 'HTML', -form_vals => \%form_vals); 

$f.= q{ 

</fieldset> 
	
};

	$f .= attachment_widget(\%form_vals);

	
	
	$f .= qq{ 
		<fieldset> 
		<legend>
		       <a href="#" onclick="toggleDisplay('advanced_options');return false;">
		      +/- 
		     </a>Advanced Options
		</legend>
		
		<div id="advanced_options" style="display:none">
		
		
	};
	
	if($mss->can_archive){ 
	
	
	
	$f .= (
		$q->p(
		$q->checkbox(
					 -name    => 'archive_mailings', 
					 -value   => 1, 
						  (($form_vals{archive_mailings} == 1) ? 
						  (-checked => 'checked',) :

						  (-checked => '',)),
					 -label   => '',
					), 
				 'Archive Mailings')	 
		);    
	}
		
	$f .= (
		$q->p(
		$q->checkbox(
					 -name    => 'only_send_to_list_owner', 
					 -value   => 1, 
						  (($form_vals{only_send_to_list_owner} == 1) ? 
						  (-checked => 'checked',) :
						  (-checked => '',)),
					 -label   => '',
					), 
				 'Only send this schedule to the List Owner')	 
		);  

$f .= '			</div> </fieldset> '; 

require DADA::MailingList::Subscribers; 
my $lh = DADA::MailingList::Subscribers->new({-list => $list }); 


my $fields = [];  
# Extra, special one... 
push(@$fields, {name => 'subscriber.email'}); 
for my $field(@{$lh->subscriber_fields({-dotted => 1})}){ 
     push(@$fields, {name => $field});
 }

my $undotted_fields = [];  
# Extra, special one... 
push(@$undotted_fields, {name => 'email', label => 'Email Address'});
require DADA::ProfileFieldsManager; 
my $pfm = DADA::ProfileFieldsManager->new;
my $fields_attr = $pfm->get_all_field_attributes;
 for my $undotted_field(@{$lh->subscriber_fields({-dotted => 0})}){ 
      push(@$undotted_fields, {name => $undotted_field, label => $fields_attr->{$undotted_field}->{label}});
 }   



my $partial_saved = $form_vals{partial_sending_params};
my $edited_fields = []; 

for my $p_field(@$undotted_fields){ 
	for my $partial_saved_entry(@$partial_saved){ 
		# Did you catch that?
		if($partial_saved_entry->{field_name} eq $p_field->{name}){ 	
			$p_field->{field_comparison_type} = $partial_saved_entry->{field_comparison_type};
			$p_field->{field_value}           = $partial_saved_entry->{field_value};
			 
		}
	}
	
	push(@$edited_fields, $p_field); 

}



require DADA::Template::Widgets; 
$f .= DADA::Template::Widgets::screen({
	-screen => 'partial_sending_options_widget.tmpl',
	-vars => { 	                                                                  
	    fields                      => $edited_fields,
		undotted_fields 			=> $undotted_fields, 
	    can_have_subscriber_fields  => $lh->can_have_subscriber_fields, 
    
	}, 
	}
); 

$f .= $q->hidden('key', $key);	
$f .= $q->hidden('process', 'true');
$f .= $q->hidden('flavor', 'edit');	 

$f .= submit_widget($key); 

$f .= $q->end_form(); 


$f .= $q->p('&nbsp;') . $q->p($q->a({-href => $Plugin_Config->{Plugin_URL}}, '<- Schedule Index...')); 	

$f .= DADA::Template::Widgets::screen(
		{
			-screen  => 'help_link_widget.tmpl', 
			-vars => { 
				screen => 'scheduled_mailings',
				title  => 'Beatitude User Guide', 
			},
			
			
		}
	); 





if($q->param('debug')){ 
	require Data::Dumper; 
	$f .= $q->hr . '<pre>' . Data::Dumper::Dumper(%form_vals) . '</pre>'; 
}





	return $f; 
    	
}





sub remove_schedule_form { 
	my %args = (-key => undef, 
				-label => 'remove', 
				@_); 
	die "no key!" if ! $args{-key}; 

	my $r = ( $q->start_form(-action => $Plugin_Config->{Plugin_URL}) .
			  $q->hidden('key', $args{-key}) .
			  $q->hidden('flavor', 'remove') .
			  $q->submit(-value => $args{-label}, -class => 'alertive') . 
			  $q->end_form()
			); 
			
	return $r; 

}




sub date_widget { 

	#my %args = (-date => time, @_); 
	
	my $form_vals = shift; 
	
	my $date = $form_vals->{mailing_date};		

	#die $date; 
	
	#  0    1    2     3     4    5     6     7     8
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
		= localtime($date);
	
	my $default_mail_day    = $mday; # 20 
	my $default_mail_month  = $mon;  # 3 
	my $default_mail_year   = $year; # 103 
	my $default_mail_hour   = $hour; # 6 
	my $default_mail_minute = $min;  # 31 
	my $default_mail_am_pm  = 'am'; 
	# Why 12 is in the pm, no? 
	
	# Hour for 12 am would be, "0" 
	
	if( $default_mail_hour > 12 ){ 
		$default_mail_hour -= 12 ;
		# And if so, 12 - 12 = 0. So, we have to have it show, "1" and not, "0"
		$default_mail_am_pm = 'pm'; 
	}
	elsif($default_mail_hour == 0){ 
		$default_mail_hour = '12'; 
	}

	my $r = '<div style="width:600px">';
	
	$r .= ( 
		
		
		$q->p('Schedule mailing for: ', 
		$q->popup_menu(
					-name      => 'mail_month', 
				    -labels    => {%mail_month_values}, 
				    '-values'  => [sort { $a <=> $b } keys %mail_month_values],
				    -default   => $default_mail_month,
				   ), ' ', 
        $q->popup_menu(
					-name     => 'mail_day', 
				   '-values'  => [1..31], 
				    -default  => $default_mail_day,
				    -labels   => {%mail_day_values}
				   ), ' ', 
        $q->popup_menu(
					-name     => 'mail_year', 
				   '-values'  => [sort { $a <=> $b } keys %mail_year_values], 
				    -default  => $default_mail_year, 
				    -labels   => {%mail_year_values}, 
				   ), ' - ', 
       $q->popup_menu(
					-name     => 'mail_hour', 
				   '-values'  => [@hours], 
				    #-labels   => {%hours_labels},
				    -default  => $default_mail_hour,
				   ), ':', 				   						   
       $q->popup_menu(
					-name     => 'mail_minute', 
				   '-values'  => [@minutes], 
				   -labels    => {%mail_minute_values}, 
				    -default  => $default_mail_minute,
				   ),
       $q->popup_menu(
					-name     => 'mail_am_pm', 
				   '-values'  => ['am', 'pm'], 
				    -default  => $default_mail_am_pm,
				   ),				   				   
				   ), 
		
  	  ); 
		$r .= '</div>'; 

	return $r; 
}




sub repeat_widget { 

	my $form_vals = shift;
	my $key        = shift; 
	
	my $r = ($q->p(
			$q->checkbox(
						-name    => 'repeat_mailing', 
						-id      => 'repeat_mailing',

						(($form_vals->{repeat_mailing} == 1) ? 
							  (-checked => 'checked',) :
							  (-checked => '',)),
							  
						-value => 1, 	  
							  
						-label => ''
					 ), 
			$q->label({'for' => 'repeat_mailing'},' Repeat') , ' schedule every: ', 
			
			$q->popup_menu(
							-name     => 'repeat_times', 
						   '-values'  => [1..100], 
							-default  => $form_vals->{repeat_times},
							
							
			   ),	
			
			$q->popup_menu(
							-name     => 'repeat_label', 
						   '-values'  => ['minutes', 'hours', 'days', 'years'], 
						   -labels    => {%repeat_label_values},
							-default  => $form_vals->{repeat_label},
			   			  ), ' ',			 	  		
			
			$q->popup_menu(
							-name     => 'repeat_number', 
						   '-values'  => ['indefinite', 1..100,], 
						  
							-default  => $form_vals->{repeat_number},
			   ), 'time(s)',
			   
	));
	
	
	
	
	if($form_vals->{last_mailing}){ 
		$r .= $q->p({-class => 'positive'},$q->i('Last mailing was on: ' . $mss->printable_date($form_vals->{last_mailing}))); 
	}
	
	if($key){ 
		my $mailing_schedule = $mss->mailing_schedule($key);
		if(
			(($mailing_schedule->[-1] > int(time)) || ($form_vals->{repeat_number} eq 'indefinite')) &&
			($form_vals->{repeat_mailing} == 1)   &&
			($form_vals->{active}         == 1)  
		   ){ 
			 
			$r .= $q->p({-class => 'positive'},
				   $q->i("Next mailing will be on: " . $mss->printable_date($mailing_schedule->[0]))); 
		}
		
		
		if(($mailing_schedule->[-1] < int(time)) && (($form_vals->{repeat_number} ne 'indefinite')) ){ 
			$r .= $q->p({-class => 'smallred'},$q->i('This scheduled mailing has ended.')); 
		}
	
	}	
	
	return $r;

} 




sub message_widget { 

	my %args = (-type      => 'PlainText', 
				-form_vals => {}, 
				@_); 
	
	my $type = $args{-type}; 
	my %form_vals;
	my $form_vals = $args{-form_vals}; 
	%form_vals = %$form_vals; 
	my $r; 
	
	
	$r .= '<fieldset style="background:#e6e6e6">';
$r .= qq { 	
	 <legend>
      <a href="#" onclick="toggleDisplay('$type\_message');return false;">+   /-</a> $type Version
     </legend>
};

	$r .= qq{<div id="$type\_message">};





	
$r .= '<table width="90%">'; 
		
	$r .=  	from_text_widget($type, $form_vals);
		 
	$r .=  from_url_widget($type, $form_vals);
	
	$r .=  from_file_widget($type, $form_vals);

$r .= qq{		 
	
	</table> 
	
	<p>
	  <strong>
	   <a href="#" onclick="toggleDisplay('$type\_advanced_options');return false;">
		+/- Advanced Options...
	   </a>
	  </strong>
	
	
	<div id="$type\_advanced_options" style="display:none">
	
	<table width="90%">
	
};
	
	

	
	$r .=  	use_email_template_widget($type, $form_vals);
		
	$r .=  grab_headers_from_message_widget($type, $form_vals);
	
	$r .=  only_send_if_defined_widget($type, $form_vals);
	
	$r .=  only_send_if_different_widget($type, $form_vals);			
	$r .= qq{ 
	
	</table> 

		
	};

if($type !~ m/plain/i){ 	
my $url_options .= qq{
	<table class="simplebox">
	  <tr>
	   <td>
		<p>
		 <strong>
		  Images in this Webpage Should:
		 </strong>
		</p>
	   </td>
	   <td>
		<p>
		 <input type="radio" name="HTML_url_options" id="extern" value="extern" <!-- tmpl_if url_options_extern -->checked="checked"<!-- /tmpl_if --> />
		  <label for="extern">
		   have their URLs changed to absolute
		 </label> 
		 
		 
		 <!-- DEV as far as I can tell, this option doesn't work!
		 -js
		 
		 <br />
		 <input type="radio" name="HTML_url_options" value="location" />
		 be embedded in the message itself, using the 'Content-Location' header
		 
		 --> 
		 
		 
		 <br />
		 <input type="radio" name="HTML_url_options" value="cid" id="cid" <!-- tmpl_if url_options_cid -->checked="checked"<!-- /tmpl_if --> />
		  <label for="cid">
		   be embedded in the message itself. 
		 </label>
		 
	<!-- tmpl_unless can_display_attachments --> 
			 
			 <br />
			 <p class="error"> 
			  Warning: your current Archive backend does not support archiving messages with embedded images.
			  When viewed, these archived messages may be missing images or formatted incorrectly.
			 </p>
			 
	<!--/tmpl_unless--> 
		 
		</p>
	   </td>
	  </tr>
	  <tr>
	   <td colspan="2">
		<table align="center" class="simplebox">
		 <tr>
		  <td>
		   <p>
			<strong>
			 Restricted URL Information
			</strong>
			   </p>
			  </td>
			  <td>
		   <p>
			(
			<em>
			 optional
			</em>
			)
		   </p>
		  </td>
		 </tr>
		 <tr>
		  <td>
		   <p align="right">
			<strong>
			 username:
			</strong>
		   </p>
		  </td>
		  <td>
		   <p>
			<input type="text" name="HTML_url_username" value="<!-- tmpl_var url_username -->" />
		   </p>
		  </td>
		 </tr>
		 <tr>
		  <td>
		   <p align="right">
			<strong>
			 password:
			</strong>
		   </p>
		  </td>
		  <td>
		   <p>
			<input type="password" name="HTML_url_password" value="<!-- tmpl_var url_password -->" />
		   </p>
		  </td>
		 </tr>
		 <tr>
		  <td>
		   <p align="right">
			<strong>
			 proxy:
			</strong>
		   </p>
		  </td>
		  <td>
		   <p>
			<input type="password" name="HTML_proxy" value="<!-- tmpl_var proxy -->" />
		   </p>
		  </td>
		 </tr>
		</table>
	   </td>
	  </tr>
	 </table>
		
};

require DADA::MailingList::Archives; 

my $la = DADA::MailingList::Archives->new({-list => $list});   

$r .= DADA::Template::Widgets::screen(
		{
			-data => \$url_options, 
			-vars => { 
				can_display_attachments => $la->can_display_attachments, 
				url_options_extern      => ($form_vals->{$type.'_ver'}->{url_options} eq 'extern') ? 1 : 0, 
				url_options_cid         => ($form_vals->{$type.'_ver'}->{url_options} eq 'cid')    ? 1 : 0, 

				url_username            => $form_vals->{$type.'_ver'}->{url_username}, 
				url_password            => $form_vals->{$type.'_ver'}->{url_password}, 
				proxy                   => $form_vals->{$type.'_ver'}->{proxy}, 
			},
			
			
		}
	); 



$r .= '	</div> '; 
}




		$r .= "</div></fieldset>";
				
	return $r; 
			
}

sub from_text_widget_tmpl { 
	return q{ 
		
		<tr> 
		 <td> 
			<input type="radio" name="<!-- tmpl_var type -->_source" id="<!-- tmpl_var type -->_source" value="from_text" <!-- tmpl_if expr="(source eq 'from_text')" -->checked="checked"<!-- /tmpl_if --> />
		</td> 
		<td>
			<p>Use the below message:</p> 
		</td> 
		</tr> 
		<tr> 
		<td>&nbsp;</td>
		<td>
		<!-- tmpl_if expr="(type eq 'HTML')" --> 
			<!-- tmpl_include html_message_form_field_widget.tmpl --> 
		<!-- tmpl_else --> 
			<textarea name="<!-- tmpl_var type -->_text" cols="80" rows="30" id="<!-- tmpl_var type -->_text"><!-- tmpl_var default_text ESCAPE="HTML" --></textarea>
		<!-- /tmpl_if --> 
		</td> 	
		</tr> 
		
		
	}; 	
}
sub from_text_widget { 

	my $type      = shift; 
	my $form_vals = shift; 
	my %form_vals = %$form_vals; 	
	my $t = from_text_widget_tmpl(); 
	my $r;

	my %wysiwyg_vars = DADA::Template::Widgets::make_wysiwyg_vars($list);  


	my $r = DADA::Template::Widgets::screen(
			{
				-data => \$t, 
				-vars => { 
					#default_text => $form_vals{$type.'_ver'}->{text},
					
					html_message_body_content            => $form_vals{$type.'_ver'}->{text},
					html_message_body_content_js_escaped => js_enc($form_vals{$type.'_ver'}->{text}),
					
					source       => $form_vals{$type.'_ver'}->{source}, 
					type         => $type, 
					
					%wysiwyg_vars,
				},
				-expr => 1, 
				-list_settings_vars       => $li, # Uh, ok - $li is global. That's stupid. 
				-list_settings_vars_param => 
					{
							-dot_it => 1, 
					},
			},
		);
		
	return $r; 
}




sub from_url_widget {
 
	my $type      = shift; 
	my $form_vals = shift; 
	my %form_vals = %$form_vals; 	
	my $r; 
	
	
	eval { 
		require LWP::Simple; 
	};
	
	return '' if @$; 
	
	$r = (

		   $q->Tr(
		   $q->td([ 
		   
		   (
		   $q->p(
		   $q->radio_group(
						  -name  => "$type\_source", 
						  -value => 'from_url',
						  
							   
							   (($form_vals{$type.'_ver'}->{source} eq 'from_url') ? 
							   (-default => 'from_url',) :
							   (-default => '-',)),
						  
						  -labels => {'from_url' => ''}),
			) # p
			), 
			(
			$q->p('Fetch message from this URL:'), 
			), 
			]), #td
			) .  #tr
			$q->Tr(
			$q->td([
			(
			$q->p('&nbsp;')
			), 
			(
			
			$q->p(
			$q->textfield(
					-name => "$type\_url", 
					-value => $form_vals{$type.'_ver'}->{url},
					-class => 'full', 
				   )  
			   . ' ' . 
				
				(
				 ($form_vals{$type.'_ver'}->{url}) ? 
				 ($q->a({-href => $form_vals{$type.'_ver'}->{url}, -target =>'new'}, ' View....')) : 
				 ()
				 ) . 
				  
				
				url_test($form_vals{$type.'_ver'}->{url}))
				
				
				
			 ), 
			 ]) #td
			 ) #tr
			 
			 ); 
	return $r; 

} 



sub from_file_widget { 

	my $type      = shift; 
	my $form_vals = shift; 
	my %form_vals = %$form_vals; 	
	my $r; 
	
	$r = (
		$q->Tr(
		$q->td([
		(
			$q->p(
		    $q->radio_group(-name  => "$type\_source", 
					        -value => 'from_file', 		   
						   (($form_vals{$type.'_ver'}->{source} eq 'from_file') ? 
						   (-default => 'from_file',) :
						   (-default => '-',)),			   
						   -labels => {'from_file' => ''}), 
			)
		), 
		(	           
	 		$q->p('Fetch message from this file:')
		), 
		]), #td
		 ) #tr
		 
		 
		 . 
		 
		$q->Tr(
		$q->td([
		(
			$q->p('&nbsp;')
		), 
		(
			$q->p($q->textfield(-name  => "$type\_file", 
							    -value => $form_vals{$type.'_ver'}->{file},
							    -class => 'full',
							   ), 
			file_test($form_vals{$type.'_ver'}->{file}),)
		) 
		]) #td
		)); #tr

	return $r; 
	
} 


sub use_email_template_widget { 

	my $type      = shift; 
	my $form_vals = shift; 
	my %form_vals = %$form_vals; 	
	my $r; 
	
	$r = ($q->Tr(
		  $q->td([
		  (
		  	$q->p(
		  	$q->checkbox(-name => $type .'_use_email_template', -value => 1, -id => $type .'_use_email_template',
		  	
		  	(
		  	 ($form_vals{$type.'_ver'}->{use_email_template} ==1) ? 
		  	 (-checked => 'checked',) :
		  	 (-checked => '')
		  	), 
		  	
		  	-label => '')
		  	)
		  ), 
		  (
		  $q->label({for => $type .'_use_email_template'}, 'Apply the ' . $type . ' Email template to this message')
		  )
		  ])
		  )
		  );
	return $r; 
		
} 


sub grab_headers_from_message_widget { 
	my $type      = shift; 
	my $form_vals = shift; 
	my %form_vals = %$form_vals; 
	
	
	my $r; 



	$r = (
  		  $q->Tr(
		  $q->td([
		  (
		  	$q->p(
		  	$q->checkbox(-name => $type .'_grab_headers_from_message', -value => 1, id => $type .'_grab_headers_from_message', 
		  	
		  	(
		  	 ($form_vals{$type.'_ver'}->{grab_headers_from_message} ==1) ? 
		  	 (-checked => 'checked',) :
		  	 (-checked => '')
		  	), 
		  	
		  	-label => '')
		  	)
		  ), 
		  (
		  $q->label({for => $type .'_grab_headers_from_message'}, 'Grab headers from  ' . $type . ' message')
		  )
		  ])
		  )
	);
	
	return $r; 
	
		  


} 





sub only_send_if_defined_widget { 

	my $type      = shift; 
	my $form_vals = shift; 
	my %form_vals = %$form_vals; 
	
	
	my $r; 
	

	$r = (
		$q->Tr(
		$q->td([
		
		(
			$q->p(
		  	$q->checkbox(
		  				-name => $type .'_only_send_if_defined', -value => 1, -id => $type .'_only_send_if_defined', 
		  	
						(
						 ($form_vals{$type.'_ver'}->{only_send_if_defined} ==1) ? 
						 (-checked => 'checked',) :
						 (-checked => '')
						), 
						
						-label => '')
						)
		  ), 
		  (
		  	$q->label({for => $type .'_only_send_if_defined'}, 'Only send schedule if ' . $type . ' message has data')
		  )
		  
		  ])	#td
		  )		#Tr
		  ); 
		  
	return $r; 
}




sub only_send_if_different_widget { 
	my $type      = shift; 
	my $form_vals = shift; 
	
	eval { 
		require Digest::MD5; 
	};
	
	return '' if @$; 
	 
	my %form_vals = %$form_vals; 
	my $r; 
	
	$r = ($q->Tr(
		  $q->td([
				  (
					$q->p(
					$q->checkbox(
								 -name  => $type .'_only_send_if_diff', 
								 -value => 1, 
								 -id    => $type .'_only_send_if_diff', 
					
								(
								 ($form_vals{$type.'_ver'}->{only_send_if_diff} == 1) ? 
								 (-checked => 'checked',) :
								 (-checked => '')
								), 
								
								-label => '')
								)
				  ), 
				  (
				  $q->label({for => $type .'_only_send_if_diff'}, 'Only send schedule if ' . $type . ' message is different from last mailing')
				  )
				  ]) # td
				  )  # Tr
				  );
		return $r; 
		

} 


sub attachment_widget { 
	
	my $form_vals = shift; 
	
	my $r; 
	my $attachments = $form_vals->{attachments}; 	
	my $num = 0; 
	
	
$r .= q{ 
	<fieldset> 

	<legend>
	       <a href="#" onclick="toggleDisplay('file_attachments');return false;">
	      +/- 
	     </a>File Attachments
	</legend>
	
	<div id="file_attachments" style="display:none">
	

};

		for my $att(@$attachments){
			$r .= single_attachment_widget($att, $num);
			$num++; 
		}
	$r .= $q->hr;
	$r .= $q->p($q->b('Add an attachment:')); 
	$r .= single_attachment_widget({}, $num); 
	$r .= $q->hidden(-name => 'num_attachments', -value => $num, -force => 1); 

	$r .= q{ </div></fieldset> };
	
}




sub single_attachment_widget { 

	my $att = shift || {}; 
	my $num = shift; 
	my $r; 
	
	$r .= $q->table(
	      $q->Tr(
	      $q->td([
	      ( 
	        $q->p('Filename:')
	      ),
	      (
	      
	      $q->p($q->textfield(
	                           -name  => 'attachment_filename_'.$num, 
				               -value => $att->{attachment_filename}, 
				               -force => 1, 
							   -class => 'full', 
							), 
				               
				               file_test($att->{attachment_filename})
				 )
		   ),
		   ]) # td
		   ), #tr
		   $q->Tr(
		   $q->td([
		    
		   (
		   $q->p('Disposition:'),
		   ), 
		   (
		   $q->p(
		   $q->popup_menu(
							-name => 'attachment_disposition_'.$num, 
						   '-values' => ['attachment', 'inline'], 
							-default => $att->{attachment_disposition},
							-force => 1, )
			)
			), 
			]) #td
			), #Tr
			$q->Tr(
			$q->td([
			(
	         $q->p('MIME type'),
	         ), 
	         (
	         $q->p(
	               $q->popup_menu(-name    => 'attachment_mimetype_'.$num, 
	                             '-values' => ['find automatically', sort values %DADA::Config::MIME_TYPES], 
	                              -default => $att->{attachment_mimetype}, 
	                              -force   => 1, )
	              )
	          )
	          ]) #td
	          ), #tr
	          $q->Tr(
	          $q->td([
	          		(
	          		$q->p('&nbsp;') 
	          		), 
	                 (
	           
	           
	           (
	           (keys %$att) ? 
	       	   ($q->p($q->submit(-name => 'action', -value => 'Remove Attachment ' .$num, -class => 'alertive'))) : 
	       	   ($q->p($q->submit(-name => 'action', -value => 'Add Attachment',           -class => 'processing')))
	       	   )
	           
	           ) 
	           ]) 
	           )
	           );
	       				 
            
	return $r; 

}




sub submit_widget { 
	my $key = shift || undef; 

my $t = q{ 


<div class="buttonfloat">
<input type="submit" name="role" value="Save Schedule, Then Send Test Message" class="cautionary" /> 
<input type="submit" name="role" value="Save Schedule" class="processing" /> 
<!-- tmpl_if key --> 
	<input type="submit" name="role" value="Remove Schedule" class="alertive" /> 
<!-- /tmpl_if --> 
</div> 
<div class="floatclear"></div>

<div class="buttonfloat">
<label for="test_recipient">Send Test Messages To:</label>
 <input type="text" id="test_recipient" name="test_recipient" value="<!-- tmpl_var list_settings.list_owner_email -->" />
</div>
<div class="floatclear"></div>

};

my $r = DADA::Template::Widgets::screen(
		{
			-data => \$t, 
			-vars => { 
				key => $key,
			},
			-list_settings_vars       => $li, # Uh, ok - $li is global. That's stupid. 
			-list_settings_vars_param => 
				{
						-dot_it => 1, 
				},
		},
	);
return $r; 
} 





sub file_test { 
	my $fn = shift || undef; 
	my $r; 

	return '' if ! $fn; 
	
	$r .= $q->p({-class => 'error'}, 'Can\'t read file! ' . $fn) unless -r $fn; 
	$r .= $q->p({-class => 'error'}, 'File doesn\'t exist!' . $fn) unless -e $fn; 	
	
	return $r; 
}




sub url_test { 
	my $url = shift; 
	my $r = ''; 
	require LWP::Simple; 
	return $r if ! $url;
	eval { $LWP::Simple::ua->agent('Mozilla/5.0 (compatible; ' . $DADA::CONFIG::PROGRAM_NAME . ')'); };
	if(!LWP::Simple::get($url)){ 
		$r .= $q->p({-class => 'smallred'}, $q->i('Error fetching URL!'));
	} 
	return $r; 
	
}




sub show_help { 
	print q{ 

arguments: 
-----------------------------------------------------------	

--list			   a list's shortname
--help                 		
--verbose
--test 
--log              filename
--version
-----------------------------------------------------------
Example: To run the schedules for "mylistshortname": 

	./schedule_mailings.pl --list mylistshortname


-----------------------------------------------------------
for instructions, try:

pod2text ./schedule_mailings.pl | less

-----------------------------------------------------------

};
	exit; 
}




sub version { 

	#heh, subversion, wild. 
	print $Plugin_Config->{Plugin_Name} . " Version: $App_Version\n"; 
	print "$DADA::Config::PROGRAM_NAME Version: $DADA::Config::VER\n\n"; 
	exit; 
	
} 




sub logit { 
	my $action = shift; 
	open_log($Plugin_Config->{Log});
	log_action($action); 
	&close_log;
}




sub open_log { 
	my $log = shift; 	
	if($log){ 
		open(LOG, ">>$log") or warn "Can't open '$log' because: $!"; 
		chmod($DADA::Config::FILE_CHMOD, 	$log) 
			if $log; 
		$Have_Log = 1; 
		return 1; 
	}
}




sub log_action { 

	my ($action) = @_; 

	if($Have_Log){ 
		print LOG $action;
	} 
	
}




sub close_log{ 
	if($Have_Log){ 
		close(LOG); 
	}
}

=pod

=head1 NAME

Beatitude - A Scheduled Mailer for Dada Mail 

=head1 Obtaining The Plugin

Beatitude is located in the, I<dada/plugins> directory of the Dada Mail distribution, under the name: I<scheduled_mailings.pl>

=head1 Description

Beatitude is a plugin for Dada Mail that allows you to compose 
email messages to be scheduled for sending in the future. 

Highly configurable, messages themselves can be in PlainText, HTML
or multipart/alternative and have an unlimited number of attachments.
The message itself can be composed in the plugin itself, fetched from a 
file or from a webpage. 

The schedules themselves can be anywhere from one minute to years 
into the future and can be repeated infinitely. Schedules also have many
safegaurds to help send only new content; for example: if a scheduled mailing 
is created to send the contents of a URL once a day, it will only send that
URL if the contents are different from the previous day.


=head1 REQUIREMENTS

=over

=item * Familiarity with setting cron jobs

If you do not know how to set up a cron job, attempting to set one up for Beatitude will result in much aggravation. Please read up on the topic before attempting!

=item * The Storable Module

If you have perl 5.8, this should already be installed. If it's not, you can grab it here: 

	http://search.cpan.org/~ams/Storable

=item * Shell Access to Your Hosting Account

Shell Access is sometimes required to set up a cronjob, using the:

 crontab -e

command. You may also be able to set up a cron tab using a web-based control panel tool, like Cpanel.

Shell access also facilitates testing of the program.

=back

=head1 Installation 

This plugin can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. The below installation instructions go through how to install the plugin manually. 

If you do install this way, note that you still have set the cronjob, which is  covered below. 

=head1 Lightning Configuration/Installation Instructions

To get to the point:

=over 

=item * Upload the scheduled_mailings.pl script into the cgi-bin/dada/plugins directory (if it's not already there) 

=item * chmod 755 the scheduled_mailings.pl script

=item * run the plugin via a web browser.

=item * Set the cronjob

=back


=head1 Manual Installation

=head2 Configuring scheduled_mailings.pl Plugin Side

=head2 Change permissions of "scheduled_mailings.pl" to 755

The, C<scheduled_mailings.pl> plugin will be located in your, I<dada/plugins> diretory. Change the script to, C<755>

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
 #					-Title      => 'Scheduled Mailings',
 #					-Title_URL  => $PLUGIN_URL."/scheduled_mailings.pl",
 #					-Function   => 'scheduled_mailings',
 #					-Activated  => 1,
 #					},

Uncomment the lines, by taking off the, "#"'s: 

 					{
 					-Title      => 'Scheduled Mailings',
 					-Title_URL  => $PLUGIN_URL."/scheduled_mailings.pl",
 					-Function   => 'scheduled_mailings',
 					-Activated  => 1,
 					},

Save your C<.dada_config> file.

=head1 Configuring the Cronjob to Automatically Run Beatitude

We're going to assume that you already know how to set up the actual cronjob, but we'll be explaining in depth on what the cronjob you need to set is.

=head2 Setting the cronjob

Generally, setting the cronjob to have Beatitude run automatically just means that you have to have a cronjob access a specific URL. The URL looks something like this:

 http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl?run=1&verbose=1

Where, I<http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl> is the URL to your copy of scheduled_mailings.pl

You'll see the specific URL used for your installation of Dada Mail in the web-based control panel for Beatitude, under the fieldset legend, Manually Run Beatitude. under the heading, Manual Run URL:

This will have Beatitude check any awaiting messages.

You may have to look through your hosting account's own FAQ, Knowledgebase and/or other docs to see exactly how you invoke a URL via a cronjob.

A Pretty Good Guess of what the entire cronjob should be set to is located in the web-based crontrol panel for Beatitude, under the fieldset legend, B<Manually Run Beatitude>, under the heading, B<curl command example (for a cronjob)>:

From my testing, this should work for most Cpanel-based hosting accounts.

Here's the entire thing explained:

In all these examples, I'll be running the script every 5 minutes ( */5 * * * * ) - tailor to your taste.

=over

=item * Using Curl:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1 --url http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl

=item * Using Curl, a few more options (we'll cover those in just a bit):

 */5 * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0\;test=0 --url http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl

=back

=head3 $Plugin_Config->{Allow_Manual_Run}

If you DO NOT want to use this way of invoking the program to check awaiting messages and send them out, make sure to change the variable, $Plugin_Config-{Allow_Manual_Run}> to, 0:

 $Plugin_Config->{Allow_Manual_Run}    = 0;

at the top of the scheduled_mailings.pl script. If this variable is not set to, 1 this method will not work.

=head2 Security Concerns and $Plugin_Config->{Manual_Run_Passcode}

Running the plugin like this is somewhat risky, as you're allowing an anonymous web browser to run the script in a way that was originally designed to only be run either after successfully logging into the list control panel, or, when invoking this script via the command line.

If you'd like, you can set up a simple Passcode, to have some semblence of security over who runs the program. Do this by setting the, C<$Plugin_Config-{Manual_Run_Passcode}> variable in the scheduled_mailings.pl source itself.

If you set the variable like so:

    $Plugin_Config->{Manual_Run_Passcode} = 'sneaky';

You'll then have to change the URL in these examples to:

 http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl?run=1&passcode=sneaky

=head3 Other options you may pass

You can control quite a few things by setting variables right in the query string:

=over

=item * passcode

As mentioned above, the C<$Plugin_Config-{Manual_Run_Passcode}> allows you to set some sort of security while running in this mode. Passing the actual password is done in the query string:

 http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl?run=1&passcode=sneaky

=item * verbose

By default, you'll receive the a report of how Beatitude is doing checking the schedules and if it does send out one. 

This is sometimes not so desired, especially in a cron environment, since all this informaiton will be emailed to you (or someone) everytime the script is run. You can run Beatitude with a cron that looks like this:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1 --url http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl >/dev/null 2>&1

The, >/dev/null 2>&1 line throws away any values returned.

Since all the information being returned from the program is done sort of indirectly, this also means that any problems actually running the program will also be thrown away.

If you set verbose to, ``0'', under normal operation, Beatitude won't show any output, but if there's a server error, you'll receive an email about it. This is probably a good thing. Example:

 * * * * * /usr/local/bin/curl -s --get --data run=1\;verbose=0 --url http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl

=item * test

Runs Beatitude in test mode by checking the messages awaiting and parsing them, but not actually carrying out any sending. 

=back 

=head3 Notes on Setting the Cronjob for curl

You may want to check your version of curl and see if there's a speific way to pass a query string. For example, this:

 */5 * * * * /usr/local/bin/curl -s http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl?run=1&passcode=sneaky

Doesn't work for me.

I have to use the --get and --data flags, like this:

 */5 * * * * /usr/local/bin/curl -s --get --data run=1\;passcode=sneaky --url http://example.com/cgi-bin/dada/plugins/scheduled_mailings.pl

my query string is this part:

 run=1\;passcode=sneaky

And also note I had to escape the, ; character. You'll probably have to do the same for the & character.

Finally, I also had to pass the actual URL of the plugin using the --url flag.

=head1 Command Line Interface

There's a slew of optional arguments you can give to this script. To use Beatitude via the command line, first change into the directory that Beatitude resides in, and issue the command:

 ./scheduled_mailings.pl --help

=head2 Command Line Interface for Cronjobs: 

One reason that the web-based way of running the cronjob is better, is that it 
doesn't involve reconfiguring the plugin, every time you upgrade. This makes 
the web-based invoking a bit more convenient. 

=head2 #1 Change the lib path

You'll need to explicitly state where both the:

=over

=item * Absolute Path to the site-wide Perl libraries

=item * Absolute Path of the local Dada Mail libraries

=back

I'm going to rush through this, since if you want to run Beatitude this way
you probably know the terminology, but: 

This script will be running in a different environment and from a different location than what you'd run it as, when you visit it in a web-browser. It's annoying, but one of the things you have to do when running a command line script via a cronjob. 

As an example: C<use lib qw()> lines probably look like: 

 use lib qw(
 
 ../ 
 ../DADA/perllib 
 ../../../../perl 
 ../../../../perllib 
 
 );


To this list, you'll want to append your site-wide Perl Libraries and the 
path to the Dada Mail libraries. 

If you don't know where your site-wide Perl libraries are, try running this via the command line:

 perl -e 'print $_ ."\n" for @INC'; 

If you do not know how to run the above command, visit your Dada Mail in a web browser, log into your list and on the left hand menu and: click, B<About Dada Mail> 

Under B<Script Information>, click the, B< +/- More Information> link and under the, B<Perl Library Locations>, select each point that begins with a, "/" and use those as your site-wide path to your perl libraries. 

=head2 #2 Set the cron job 

Cron Jobs are scheduled tasks. We're going to set a cron job to test for new messages every 5 minutes. Here's an example cron tab: 

  */5  *  *  *  * /usr/bin/perl /home/myaccount/cgi-bin/dada/plugins/scheduled_mailings.pl >/dev/null 2>&1

Where, I</home/myaccount/cgi-bin/dada/plugins/scheduled_mailings.pl> is the full path to the script we just configured.

If all this lib path changin' isn't up your alley, try this instead: 

make NO changes in the plugin regarding the perl lib paths, but change the cronjob to something like this: 

*/5 * * * * cd /home/myaccount/cgi-bin/dada/plugins; /usr/bin/perl ./scheduled_mailings.pl >/dev/null 2>&1

This should setup so the plugin is run from the, I<plugins> directory and the Dada Mail and Perl libraries can be found, automatically. A lot easier. 

=head2 Running Beatitude via the command line

Since this program is also command line tool, you can execute it via a
command line. Running Beatitude without any flags will
have it check if any schedules should be run, and mail messages that need 
to be mailed. 

 prompt>./scheduled_mailings.pl

I suggest before you do that, you test the scheduled_mailings.pl script.

=head2 Testing

You can pass the B<--test> argument to scheduled_mailings.pl to make
sure everything is workings as it should. The B<--test> argument does not
take any arguments. If everything is set up correctly, you'll get back a verbose
message of the going's on of the script: 

 prompt>./scheduled_mailings.pl --test
 
 ------------------------------------------------------------------------
 Running Schedule For: mytestlist
 Current time is: June 26th 2003 - 5:25 pm
     No schedules to run.
 ------------------------------------------------------------------------

In this example, Beatitude checked schedules to be run for the 'mytestlist' list, 
found none, and exited. If there is a schedule to run, the output my look like this: 

 ------------------------------------------------------------------------
 Running Schedule For: mytestlist
 Current time is: June 26th 2003 - 5:33 pm
 
     Examining Schedule: 'Justin's Test Schedule'
     'Justin's Test Schedule' is active -  
         Schedule last checked:     June 26th 2003 - 5:31 pm
         Next mailing should be on: June 26th 2003 - 5:33 pm
             'Justin's Test Schedule' scheduled to run now! 
 ------------------------------------------------------------------------


=head2 Optional Fun Things

There's a slew of optional arguments you can give to this script: 

=over

=item * --verbose
  
  prompt>./scheduled_mailings.pl --verbose

passing the --verbose parameter is like giving this script some 
coffee.  Similar to what you'd see if you ran the script using: 

 prompt>./scheduled_mailings.pl --test
 
But the scheduled mailings will actually get sent. 


=item * --log

If you pass a filename to the script it'll write a log entry that 
will look the same as what's outputted when you run with the 
B<--verbose> flag. 

If you don't want to pass the log each time, you can set a log in the
B<$Plugin_Config->{Log}> variable.

=item * --version

 prompt>./scheduled_mailings.pl --version

WIll print out both the version of Beatitude and also of Dada Mail. 
Good for debugging. Looks like this: 

 Beatitude version: .1
 Dada Mail version: 2.8.8

=item * --list
 
 ./scheduled_mailings.pl --list myslistshortname

If you want to run schedules for only one list, you can pass the B<--list> 
argument to scheduled_mailings.pl with a listshortname as its value. 

=back

=head1 Misc. Options

=head2 $Plugin_Config->{Plugin_URL}

Sometimes, the plugin has a hard time guessing what its own URL is. If this is happening, you can manually set the URL of the plugin in B<$Plugin_Config->{Plugin_URL}>

=head2 $Plugin_Config->{Allow_Manual_Run}

Allows you to invoke the plugin to check and send awaiting messages via a URL. See, "The Easy Way" cronjob setting up docs, above. 

=head2 $Plugin_Config->{Manual_Run_Passcode}

Allows you to set a passcode if you want to allow manually running the plugin. See, "The Easy Way" cronjob setting up docs, above. 


=head1 Debugging

Beatitude can be a bit difficult to set up, if you've never set up a similar script before. Here's a few things I do, to make sure a Beatitude install is working correctly: 

First off, I install Beatitude, using the directions above. 

Then, I'll make a test list, so if something goes wrong, no one will be affected. I won't add any subscribers, since it won't be necessary. Any test messages I send out will go to the list owner (me). 

I'll then create a new schedule to send a message, every minute and repeat that schedule, indefinitely.

Then, I'll connect to the server via ssh, and run the command to run Beatitude, exactly as I would type the command in the crontab - except perhaps I'll put that --verbose flag on there, so I can see what's happening.

It takes a minute for the first message to be sent, and after that, every minute, if I run the command, I'll get a mailing. This will let me know that the schedules are firing correctly, and that I have the correct command to run Beatitude. 

If that's working, I'll set the cronjob - and have it run every five minutes or so. I'll get some coffee.

I'll come back and if I have a few messages that I didn't send, I'll know the cronjob did its job.

=head1 FAQs

=over

=item * I keep getting, 'permission denied' errors, what's wrong?

It's very possible that Beatitude can't read your subscription database or the list settings database. This is because Dada Mail may be running under the webserver's username, usually, B<nobody>, and not what Beatitude is running under, usually your account username. 

You'll need to do a few things: 

=over

=item * Change the permissions of the list subscription and settings databases

You'll most likely need to change the permissions of these files to, '777'. PlainText subscription databases have the format of B<listshortname.list> and are usually located where you set the B<$FILES> Config file variable. .List settings Databases have the format of B<mj-listshortname> and are usually located in the same location.

=item * Change the $FILE_CHMOD variable

So you don't need to change the permissions of the list files for every new list you create, set the $FILE_CMOD Config variable to 0777:
	
	$FILE_CHMOD = 0777; 
	
Notice there are no quotes around 0777. 

=back


=item * I found a bug in this program, what do I do? 

Report it to the bug tracker: 

http://sourceforge.net/tracker/?group_id=13002&atid=113002

=item * What's up with the name, Beatitude?

B<Beatitude>, in a historical context, refers to one of the eight sayings the Christian prophet, Jesus is believed to have said on the Sermon on the Mount. Each saying starts with, "Blessed are the..." - a similar saying over and over again, much like sending a similar message again and again

It also means, "a state of supreme happiness". 

But to me, I think of B<Beatitude> as almost a shorthand for, B<Beat Attitude>; the Beat Generation being a group of writers whose inner circle included Jack 
Kerouac, Allen Ginsberg, William Bourroughs, Gregory Corso and many more. 

I<To Kerouac, "Beat" -- a shorthand term for "beatitude" and the idea that the downtrodden are saintly -- was not about politics but about spirituality and art.>
-B<Douglas Brinkley>

A modern Beatitude would be Ginsberg's I<Please Master>, found in the book, B<Fall of America>.

The Beat Generation attempted to I<communicate> the thoughts, ideas and
adventures of their normal lives. I can only hope that communication with my B<Beatitude> will be a tenth that incredible. 

My personal bookshelf is overflowing with books from the Beat Generation authors
and one reason I moved to Boulder, CO, and then Denver, CO was because of the  Denver adventures of Sal Paradise and Dean Moriarty in I<On The Road> and to be close to the B<Jack Kerouac School of Disembodied Poets> in Boulder, CO. 

=back

=head1 COPYRIGHT

Copyright (c) 1999 - 2012 Justin Simoni 
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
