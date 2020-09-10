package DADA::MailingList::Schedules;
use strict;

use lib qw(
  ../../
  ../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_Schedules};

use DADA::MailingList::MessageDrafts;
use DADA::MailingList::Settings; 
use DADA::App::MassSend; 
use DADA::App::Guts; 
use Try::Tiny; 

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;

    $self->_init($args);
    return $self;

}




sub _init {

    my $self = shift;
    my ($args) = @_;

    $self->{list}   = $args->{-list};
    
    $self->{ms_obj} = DADA::App::MassSend->new({-list => $self->{list}}); 
    $self->{d_obj} = DADA::MailingList::MessageDrafts->new( { -list => $self->{list} } );
    
    
    $self->{ls_obj} =  DADA::MailingList::Settings->new( { -list => $self->{list}  } );
    if(!defined($self->{ls_obj}->param('schedule_last_checked_time')) 
    || $self->{ls_obj}->param('schedule_last_checked_time') <= 0){ 
        $self->{ls_obj}->save(
			{
				-settings  => {
					schedule_last_checked_time => time
				}
			}
		);
        undef($self->{ls_obj}); 
        $self->{ls_obj} =  DADA::MailingList::Settings->new( { -list => $self->{list}  } );
    }
    
    
}




sub run_schedules {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{-verbose} ) ) {
        $args->{-verbose} = 0;
    }
    my $time = time;

    my $r =
        "Running Schedules for, "
      . $self->{ls_obj}->param('list_name') . " ("
      . $self->{list} . ")\n";
    $r .= '-' x 72 . "\n";
    $r .=
      "Current Server Time:              " . scalar( localtime($time) ) . "\n";
    $r .=
      "Scheduled Mass Mailings Last Ran: "
      . scalar(
        localtime( $self->{ls_obj}->param('schedule_last_checked_time') ) );
    $r .= " ("
      . formatted_runtime(
        $time - $self->{ls_obj}->param('schedule_last_checked_time') )
      . " ago)\n";

    my $count = $self->{d_obj}->count( { -role => 'schedule' } );

    if ( $count <= 0 ) {
        $r .= "* No Schedules currently saved\n";
    }
    else {
        $r .= "* $count Schedule(s)\n";
    }
    my $index = $self->{d_obj}->draft_index( { -role => 'schedule' } );

    my $rb = '';
	SCHEDULES: for my $sched (@$index) {

        #$rb .= "Raw Paramaters:\n";
        #require Data::Dumper;
        #$rb .= Data::Dumper::Dumper($sched);

        $rb .= "\t* Subject: " . $sched->{Subject} . "\n";

        if ( $sched->{schedule_activated} != 1 ) {
            $rb .= "\t* Schedule is NOT Activated.\n";
            next SCHEDULES;
        }
        else {
            $rb .= "\t* Schedule is Activated!\n";
        }

        my $schedule_times = [];

        my $can_use_datetime = DADA::App::Guts::can_use_datetime();

        if ( $sched->{schedule_type} eq 'recurring' && $can_use_datetime == 0 )
        {
            $rb .=
"Recurring schedule set, but the DateTime CPAN Perl module will need to be installed.\n";
            next SCHEDULES;
        }
        elsif ($sched->{schedule_type} eq 'recurring'
            && $can_use_datetime == 1 )
        {
			
			
            # This is weird validation buuuuuuut
            if (   length( $sched->{schedule_recurring_ctime_start} ) == 0
                || length( $sched->{schedule_recurring_ctime_end} ) == 0
                || length( $sched->{schedule_recurring_display_hms} ) == 0
                || length( $sched->{schedule_recurring_days} ) == 0 )
            {
                $rb .=
                  "\t*DateTime information is missing from this schedule\n";
                $rb .= "SKIPPING...\n";

                $self->send_schedule_notification(
                    {
                        -type    => 'failure',
                        -details => $rb,
                        -sched   => $sched,
                    }
                );

                next SCHEDULES;
            }

            my $d_lt = {
                7 => 'Sunday',
                1 => 'Monday',
                2 => 'Tuesday',
                3 => 'Wednesday',
                4 => 'Thursday',
                5 => 'Friday',
                6 => 'Saturday',
            };
           
            # use Data::Dumper;
            # die Dumper($sched->{schedule_recurring_days});
			
			my $days_str = 'every day of the week';
			if(scalar(@{$sched->{schedule_recurring_days}}) < 7){ 
				my @day_vals = (); 
	            for ( @{ $sched->{schedule_recurring_days} } ) {
	               push(@day_vals, $d_lt->{$_});
	            }
				$days_str = join(', ', @day_vals);
			}
			
            my $w_lt = {
                1 => 'First',
                2 => 'Second',
                3 => 'Third',
                4 => 'Fourth',
                5 => 'Fifth',
            };
			my $week_str = 'every';
			if(scalar(@{$sched->{schedule_recurring_weeks}}) < 5){ 
				my @weeks_vals = (); 
	            for ( @{ $sched->{schedule_recurring_weeks} } ) {
	                push(@weeks_vals, $w_lt->{$_} ); 
	            }
				$week_str = join(', ', @weeks_vals);
			}

            $rb .=
                "\t* This is a *Recurring* mass mailing,\n"
              . "\t\t* sending between: "
              . $sched->{schedule_recurring_displaydatetime_start} . " "
              . " and: "
              . $sched->{schedule_recurring_displaydatetime_end} . "\n"
              . "\t\t* on: "
			  . $week_str . " week of the month\n"
              . "\t\t* on: "
              . $days_str . "\n"
              . "\t\t* at: "
              . $sched->{schedule_recurring_display_hms} . "\n";
			
			  # this should never happen, but it happens: 
			if($sched->{schedule_recurring_ctime_start} > $sched->{schedule_recurring_ctime_end}){ 
				
				$rb .= "\t\t\t * Problem: Cannot have a start time that's older than the end time.\n";
				$rb .= "Deactivating Schedule...\n";
				$self->send_schedule_notification(
					{
						-type    => 'failure',
						-details =>  $rb ,
						-sched   => $sched,
					}
				);

				$self->deactivate_schedule(
					{
						-id     => $sched->{id},
						-role   => $sched->{role},
						-screen => $sched->{screen},
					}
				);
				next SCHEDULES;

			}
		
			
            my ( $status, $errors, $recurring_scheds ) =
              $self->recurring_schedule_times(
                {
                    -recurring_time => $sched->{schedule_recurring_display_hms},
					-weeks          => $sched->{schedule_recurring_weeks},
                    -days           => $sched->{schedule_recurring_days},
                    -start          => $sched->{schedule_recurring_ctime_start},
                    -end            => $sched->{schedule_recurring_ctime_end},
                }
              );
            if ( $status == 0 ) {
                $rb .= "Problems calculating recurring schedules - skipping schedule: "
                  . $errors . "\n";

                #$r  .= $rb;
                # Send a failure notification

                $self->send_schedule_notification(
                    {
                        -type    => 'failure',
                        -details => $rb,
                        -sched   => $sched,
                    }
                );

                next SCHEDULES;
            }


            # require Data::Dumper;
            # $r .=   Data::Dumper::Dumper($recurring_scheds);

            for (@$recurring_scheds) {
                if (   $_->{ctime} >= ( $time - ( 604_800 * 2 ) )
                    && $_->{ctime} <= ( $time + ( 604_800 * 2 ) ) )
                {
                    push( @$schedule_times, $_->{ctime} );
                }
            }


            if ( scalar @$schedule_times <= 0 ) {
                $rb .= "\t* No Scheduled Mailing needs to be sent out.\n";

                #$r .= $rb;
                next SCHEDULES;
            }
            else {
                #$r .= "\t\t* Approaching/Past Schedule Times:\n";
                #for(@$schedule_times) {
                #    $r .= "\t\t\t* " . scalar localtime($_) . "\n";
                #}
            }
        }
        else {
            $rb .= "\t* Schedule Type: One-Time\n";
            push( @$schedule_times, $sched->{schedule_single_ctime} );
        }


        my $rc = '';
		
		SPECIFIC_SCHEDULES: for my $specific_time (@$schedule_times) {
			
			
            my $end_time;

            # This is sort of awkwardly placed validation...
            if ( $sched->{schedule_type} eq 'recurring' ) {
                $end_time = $sched->{schedule_recurring_ctime_end};
            }
            else {
                if ( length($specific_time) == 0 ) {
                    $rc .= "\t* Date and Time is blank for this schedule\n";
                    $rc .= "SKIPPING\n";
					next SPECIFIC_SCHEDULES;
                }
                else {
                    $end_time = $specific_time;
                }
            }

            # was this supposed to be sent a day ago?
            if ( $end_time < ( $time - 86400 ) ) {
                $rc .= "\t* Schedule is too late to run - should have ran "
                  . formatted_runtime( $time - $end_time ) . ' ago.' . "\n";
                $rc .= "Deactivating Schedule...\n";
                $self->send_schedule_notification(
                    {
                        -type    => 'failure',
                        -details => ( $rb . $rc ),
                        -sched   => $sched,
                    }
                );

                $self->deactivate_schedule(
                    {
                        -id     => $sched->{id},
                        -role   => $sched->{role},
                        -screen => $sched->{screen},
                    }
                );
                next SPECIFIC_SCHEDULES;
            }
            else {
				$rc .= "\t* Schedule runs at: "
                  . scalar localtime($specific_time) . "\n";
            }
			
			
            my $last_checked =
              $self->{ls_obj}->param('schedule_last_checked_time');

			  
            if ( $specific_time > $time ) {
               			   
			    $rc .= "\t\t(" . formatted_runtime( $specific_time - $time );
                if ( $sched->{schedule_type} eq 'recurring' ) {
                    $rc .= " from now";
                }
                $rc .= ")\n";

                next SPECIFIC_SCHEDULES;
            }
            else {
				# ... 
            }

			
			if ( $specific_time >=
                $self->{ls_obj}->param('schedule_last_checked_time') )
            {
                if (   $sched->{schedule_type} eq 'recurring'
                    && $sched
                    ->{schedule_recurring_only_mass_mail_if_primary_diff} == 1 )
                {
                    $rc .= "\t* Checking message content...\n";
                    my $c_r = $self->{ms_obj}->construct_and_send(
                        {
                            -draft_id => $sched->{id},
                            -screen   => $sched->{screen},
                            -role     => $sched->{role},
                            
                            -process => 1,
                            -dry_run => 1,
                        }
                    );

                    my $is_feed = 0;

                    if (   $sched->{screen} eq 'send_url_email'
                        && $sched->{content_from} eq 'feed_url' )
                    {

                        $is_feed = 1;
                    }

#warn '$sched->{screen}'                     . $sched->{screen};
#warn '$sched->{content_from}'               . $sched->{content_from};
#warn '$sched->{feed_url_most_recent_entry}' . $sched->{feed_url_most_recent_entry};
#warn '$c_r->{vars}->{most_recent_entry}'    . $c_r->{vars}->{most_recent_entry};
#warn '$is_feed' . $is_feed;


                    if ( $is_feed == 1 ) {

                        $rc .=
                          "* \t\tMessage is created from an RSS/Atom Feed.\n";
                        $rc .=
"* \t\tLooking for entries in the feed that are newer than was previously sent,\n";
                        $rc .= "  \t\trather than comparing checksums.\n\n";

                        if (
                            length( $sched->{feed_url_most_recent_entry} ) >= 1
                            && $sched->{feed_url_most_recent_entry} >=
                            $c_r->{vars}->{most_recent_entry} )
                        {
                            $rc .=
"\t\t* No newer feed entries available, most recent entry sent published on, "
                              . scalar
                              localtime( $sched->{feed_url_most_recent_entry} )
                              . ".\n";

# this won't work, as any entries old than feed_url_most_recent_entry won't actually be reported!
# . "\nNewest entry in feed published on, "
# .  scalar localtime($c_r->{vars}->{most_recent_entry})

                            warn
"No newer feed entries available, most recent entry sent published on, "
                              . scalar
                              localtime( $sched->{feed_url_most_recent_entry} )
                              if $t;
                            undef($c_r);
							next SPECIFIC_SCHEDULES;

                        }
                        else {
                            $rc .=
                              "\t* Primary content's most recent entry ("
                              . scalar
                              localtime( $c_r->{vars}->{most_recent_entry} )
                              . ")  is newer  than the last message that has been sent ("
                              . scalar
                              localtime( $sched->{feed_url_most_recent_entry} )
                              . ")\n";
                            undef($c_r);
                        }
                    }

                    if ( $is_feed != 1 ) {
                        if (
                               defined( $c_r->{md5} )
                            && defined( $sched->{schedule_html_body_checksum} )
                            && $c_r->{md5} eq
                            $sched->{schedule_html_body_checksum}

                          )
                        {
                            $rc .=
"\t\t* Primary Content same as previously sent scheduled mass mailing.\n";
                            $rc .=
"\t\t* Skipping sending scheduled mass mailing.\n\n";
                            undef($c_r);
							
                            next SPECIFIC_SCHEDULES;
                        
						}
                        else {
                            $rc .=
"\t* Looks good! Primary content is different than last scheduled mass mailing (checksum check).\n";
                            undef($c_r);
                        }
                    }
                    undef($c_r);
					
                }				
                $rc .= "\t\t* Running schedule now!\n";
                my $c_r = {};

                if ( $sched->{schedule_test_mode} == 1 ) {
                    $rc .= "\t\t* TEST MODE enabled.\n";

                    my $test_list_type_label =
                      $self->create_tmp_test_list(
					  { 
                              -id     => $sched->{id},
                              -role   => $sched->{role},
                              -screen => $sched->{screen},		
                      }
					);

                    #$rc .=
                    #    "\t\t* "
                    #  . '$test_list_type_label: '
                    #  . $test_list_type_label . "\n";

                   $c_r = $self->{ms_obj}->construct_and_send(
                       {
                           -draft_id => $sched->{id},
                           -screen   => $sched->{screen},
                           -role     => $sched->{role},
                   
                           # Very important for test sending
                           -list_type => $test_list_type_label,
                           -process   => 'test',
                   
                       }
                   );

                }
                else {
                   $c_r = $self->{ms_obj}->construct_and_send(
                       {
                           -draft_id => $sched->{id},
                           -screen   => $sched->{screen},
                           -role     => $sched->{role},
                   
                           -process => 1,
                   
                       }
                   );
                }
                if ( $sched->{schedule_type} eq 'recurring' ) {
				   $rc .= $self->update_schedule(
                       {
                           -id     => $sched->{id},
                           -role   => $sched->{role},
                           -screen => $sched->{screen},
                           -vars   => {
                               schedule_html_body_checksum => $c_r->{md5},
                               feed_url_most_recent_entry =>
                                 $c_r->{vars}->{most_recent_entry},
                           },
                       }
                   );
                }
				
                # oh, there it is.
                
				if ( $c_r->{status} == 1 ) {

					my $escaped_mid = $c_r->{mid};
                    $escaped_mid =~ s/\>|\<//g;
                    $rc .= "\t\t* Scheduled Mass Mailing added to the queue, Message ID: $escaped_mid\n";

                   $self->send_schedule_notification(
                       {
                           -type    => 'success',
                           -mid     => $escaped_mid,
                           -details => ( $rb . $rc ),
                           -sched   => $sched,
                       }
                   );
                }
                else {					
					
                    # Send a failure notification
                    $rc .= "\t\t* Scheduled Mass Mailing not sent, reasons:\n"
                      . $c_r->{errors} . "\n";
                    warn "Scheduled Mass Mailing not sent, reasons:\n"
                      . $c_r->{errors} . "\n";

                    $self->send_schedule_notification(
                        {
                            -type    => 'failure',
                            -details => ( $rb . $rc ),
                            -sched   => $sched,
                        }
                    );

                }
								
                if ( $sched->{schedule_type} ne 'recurring' ) {
                    
					$rc .= "\t* Deactivating Schedule...\n";
                    $self->deactivate_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                        }
                    );
                }
				
                # Don't want to have this sent more than once, right?
                if (   $c_r->{status} == 1
                    && $sched->{schedule_type} eq 'recurring' )
                {
					
					#$rb .= $rc; 
					#undef($rc);
                    #next SCHEDULES;
					last SPECIFIC_SCHEDULES; 
                }

				
            }
            else {
                # $rc .= "\nfell in this hole\n";
            }

            if ( $sched->{schedule_type} ne 'recurring' ) {
                if ( $specific_time <
                    $self->{ls_obj}->param('schedule_last_checked_time') )
                {
                    $rc .= "\t* Schedule SHOULD have been sent, but wasn't\n";
            
			        $rc .= "\t* Deactivating Schedule...\n";

                    $rc .= $self->deactivate_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                        }
                    );

                    $self->send_schedule_notification(
                        {
                            -type    => 'failure',
                            -details => ( $rb . $rc ),
                            -sched   => $sched,
                        }
                    );

                }
            }
			else { 
				# ...
			}

        }
		
		$rb  .= $rc; 

    }
    $r .= $rb;

    $self->{ls_obj}->save(
        {
            -settings => {
                schedule_last_checked_time => time
            }
        }
    );

    $r .= "\n";

    if ( $args->{-verbose} == 1 ) {
        print $r;
    }
    return $r;

}

sub create_tmp_test_list { 
	
	# This needs it's own method... somewhere, as the below is copypasta from DADA::App::MassSend... 
	# Maybe that's what I should REALLY do... 
	
	my $self  = shift;  
	my ($args) = @_; 
	
	
	
	
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen => $args->{-screen},  
        }
    ); 
		
	# Make up the test list, if this is a test: 
    require DADA::Security::Password;
    my $ran_number = uc( substr( DADA::App::Guts::generate_rand_string_md5(), 0, 16 ) );
	my $test_list_type_label = '_tmp_test_list_' . $ran_number;
	
	require DADA::MailingList::Subscribers; 
	my $lh = DADA::MailingList::Subscribers->new({-list => $self->{ls_obj}->param('list')});
	
    require DADA::App::MassSend;
    my $ms = DADA::App::MassSend->new( { -list => $self->{ls_obj}->param('list') } );
	
	if($local_q->param('test_recipient_type') eq 'from_test_list'){	
        $lh->copy_all_subscribers(
            {
                -from => 'test_list',
                -to   => $test_list_type_label,
            }
        );
	}
	else {	
		
		my @recipients = $ms->_find_email_addresses($local_q->param('test_recipients')); 
		for (@recipients){ 	
			warn 'adding, '  . $_ . 'to: ' . $test_list_type_label
				if $t; 
	        my $dmls = $lh->add_subscriber(
	            {
	                -email      => $_,
	                -type       => $test_list_type_label,
	                -dupe_check => {
	                    -enable  => 1,
	                    -on_dupe => 'ignore_add',
	                },
	            }
	        );
	    }				
	}
	
	# Well, we have to send a test message to SOMEONE: 
	if($self->{ls_obj}->param('mass_mailing_send_to_list_owner') == 0) {
		if($lh->num_subscribers( { -type => $test_list_type_label } ) == 0){ 
	        $lh->add_subscriber(
	            {
	                -email      => $self->{ls_obj}->param('list_owner_email'),
	                -type       => $test_list_type_label,
	                -dupe_check => {
	                    -enable  => 1,
	                    -on_dupe => 'ignore_add',
	                },
	            }
	        );	
		}
	}
	
	return $test_list_type_label; 
	
}

sub send_schedule_notification { 
	my $self = shift; 
	my ($args) = @_; 
	
	# -mid        => $escaped_mid, 
    # -details    => $rb, 
	# -sched      => $sched, 
	
	my $sched = $args->{-sched};
	my $type  = $args->{-type};

	# Do we need to do this?
	if($type eq 'failure' &&  $sched->{schedule_send_email_notification_on_failure} != 1){ 
		return; 
	}
	elsif($type eq 'success' &&  $sched->{schedule_send_email_notification_on_failure} != 1){ 
		return; 
	}
		
	my $template_name = 'schedule_success';
	if($type eq 'failure'){ 
		$template_name = 'schedule_failure'; 
	} 
	require DADA::App::Messages;
    my $dap = DADA::App::Messages->new(
		{
			-list => $self->{ls_obj}->param('list'),
		}
	);
	$dap->send_out_message(
		{
			-message => $template_name,
			-email   => $self->{ls_obj}->param('list_owner_email'), 
            -tmpl_params => {
                -list_settings_vars       => $self->{ls_obj}->params,
                -list_settings_vars_param => {
					-dot_it => 1, 
				},
                -vars                     => {
					details                    => $args->{-details},
					html_details               => plaintext_to_html({-str => $args->{-details}}), # conversion_override_args => {} # Not implemented. 
					mid                   => $args->{-mid},
					draft_id              => $sched->{id},
					mass_mailing_subject  => $sched->{Subject},
                }
            }
		}	
	);
}

sub recurring_schedule_times {
    my $self = shift;
    my ($args) = @_;
    my $r = undef; 
    
    my $status = 1; 
    my $errors = undef; 
    my $times = [];
    
    # require Data::Dumper; 
    # warn "args:" . Data::Dumper::Dumper($args); 
    
    my $recurring_time = $args->{-recurring_time};
    my $days           = $args->{-days};
    my $weeks          = $args->{-weeks};
    my $start          = $args->{-start};
    my $end            = $args->{-end};


    try {
        
        require DateTime;
        require DateTime::Event::Recurrence;
        
        my $start_dt = DateTime->from_epoch( epoch => $start );
        my $end_dt   = DateTime->from_epoch( epoch => $end );

        my ( $hours, $minutes, $seconds ) = split( ':', $recurring_time );

        my $day_set = undef;
        my $dates   = [];

        $day_set = DateTime::Event::Recurrence->monthly(
			week_start_day => '1su',
			weeks          => $weeks,
            days           => $days,
            hours          => $hours,
            minutes        => $minutes
        );
        my $it = $day_set->iterator(
            start  => $start_dt,
            before => $end_dt,
        );

        while ( my $dt = $it->next() ) {
            push(
                @$times,
                {
                    # date        => $dt->datetime,
                    # localtime => scalar localtime($self->T_datetime_to_ctime($dt->datetime)),
                    ctime         => $self->T_datetime_to_ctime($dt->datetime), 
                }
            );
        }

    } catch {
        $status = 0; 
        $errors = $_; 
    };
    return ($status, $errors, $times);
}


sub recurring_schedule_times_json { 
	
    my $self = shift;
    my ($args) = @_;
    my ( $status, $errors, $recurring_scheds ) =
      $self->recurring_schedule_times($args);
	require JSON; 
	my $json = JSON->new->allow_nonref;

	my $r = []; 
	require POSIX;
	foreach(@$recurring_scheds){ 
		my $to_convert = $_->{ctime};
		my $displaytime = POSIX::strftime('%Y/%-m/%-d', localtime $to_convert);
		push(@$r, 
			{
				date  => $displaytime, 
				label => 'runs at, ' . $args->{-recurring_time}
			}
		);
	}

	return $json->encode( $r );
	
}

sub T_datetime_to_ctime {
    my $self = shift; 
    my $datetime = shift;
    require Time::Local;
    my ( $date, $time ) = split( 'T', $datetime );
    my ( $year, $month,  $day )    = split( '-', $date );
    my ( $hour, $minute, $second ) = split( ':', $time );
    $second = int( $second - 0.5 );    # no idea.
    my $time = Time::Local::timelocal( $second, $minute, $hour, $day, $month - 1, $year );

    return $time;
}




sub deactivate_schedule {
    
    my $self   = shift; 
    my ($args) = @_; 
    
    require Data::Dumper;
    my $r; 
    # $r .= 'passed args:'; 
    # $r .= Data::Dumper::Dumper($args); 
    
    
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen => $args->{-screen},  
        }
    ); 
    
    # deactivate.
    $local_q->param('schedule_activated', 0); 
    
    $self->{d_obj}->save(
        {
            -cgi_obj => $local_q,
            -id      => $args->{-id}, 
            -role    => $args->{-role},  
            -screen  => $args->{-screen},  
        }
    ); 

    return $r; 
   # return 1; 
}



sub update_schedule {
    
    my $r = "\t\t* (Updating schedule metadata...)\n"; 
    
    my $self   = shift; 
    my ($args) = @_; 
    my $vars = $args->{-vars}; 
    require Data::Dumper;
     
     #$r .= 'update_schedule: passed args:'; 
     #$r .= Data::Dumper::Dumper($args); 
    
    
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen => $args->{-screen},  
        }
    ); 
    
    for(keys %$vars){ 
		if(defined($vars->{$_})){
			$r .= "\t\t\t* " . $_ . ' => ' . $vars->{$_} . "\n"; 
        	$local_q->param($_, $vars->{$_}); 
		}
    }
            
    $self->{d_obj}->save(
        {
            -cgi_obj => $local_q,
            -id      => $args->{-id}, 
            -role    => $args->{-role},  
            -screen  => $args->{-screen},  
        }
    ); 

    $r .= "\t\t* (Done!)\n"; 
    
    return $r; 

}


sub DESTROY {}
    
1;