package DADA::MailingList::SchedulesDeprecated; 
use strict; 

use lib qw(./ ../ ../../ ../../DADA ../perllib); 


use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 
use DADA::MailingList::Settings;
use base "DADA::MailingList::SchedulesDeprecated::MLDb";

use Carp qw(croak carp);
use Encode; 


use strict;
#use vars qw(@EXPORT);


=pod

=head1 NAME DADA::MailingList::SchedulesDeprecated

=head1 Synopsis

 my $mss = DADA::MailingList::SchedulesDeprecated->new({-list => 'listshortname'}); 

=head1 Description

This module holds shared methods used for the Beatitude scheduled 
mailer. The rest of the methods are located in DADA::MailingList::SchedulesDeprecated::MLDb.

=head1 Public Methods

=cut


=pod

=head2 run_schedules

 my $report = $mss->run_schedules(-test => 0);

Returns a nicely formatted report of the schedules that were run. 

If the B<-test> argument is passed with a value of 1, the schedules 
will go until actual mailing. 

=cut

sub schedule_schema { 

	
	my %d_form_vals = (
			message_name           => 'scheduled mailing', 
			active                  => 0, 
			mailing_date            => time, 
			repeat_times            => 1, 
			repeat_label            => 'days',
			repeat_mailing          => 0,
			only_send_to_list_owner => 0,
			archive_mailings        => 0,
			only_send_if_diff       => 0,
			self_destruct           => 0, 

			headers       => 

				{ 

					'Reply-To'        => undef, 
					'Return-Path'     => undef,
					'X-Priority'    => undef, 
					Subject         => undef,

				},

			PlainText_ver => {
							   source                    => 'from_text',
							   use_email_template        => 1,
							   only_send_if_defined      => 0,
							   grab_headers_from_message => 0, 

							 }, 
			HTML_ver      => { 				 
							   source                    => 'from_text',
							   use_email_template        => 1,
							   only_send_if_defined      => 0,
							   grab_headers_from_message => 0, 

							   url_options               => 'extern', 
							   url_username              => '', 
							   url_password              => '', 
	                           proxy                     => '', 						

							 },
			attachments            => [],
			partial_sending_params => [], 
		);
		
		return %d_form_vals; 
		
			
}




sub save_from_params { 

	my $self = shift; 
	my ($args) = @_; 
	my $q; 
	
	if(! exists($args->{-cgi_obj}) ){ 
		croak "You must pass a -cgi_obj!"; 
	}
	else { 
		$q = $args->{-cgi_obj};
	}
	

	
	my %form_vals; 

	my $action = $q->param('action'); 
	
	 $form_vals{message_name}                 = $q->param('message_name'); 
	 $form_vals{active}         	          = $q->param('active')                  || 0; 
	 $form_vals{mailing_date}       		  = $self->mailing_date($q); 
	 $form_vals{repeat_mailing} 			  = $q->param('repeat_mailing')          || 0; 
	 $form_vals{repeat_times} 			      = $q->param('repeat_times')            || 0; 
	 $form_vals{repeat_number}        		  = $q->param('repeat_number'); 
	 $form_vals{repeat_label}        		  = $q->param('repeat_label'); 
	 $form_vals{only_send_to_list_owner}      = $q->param('only_send_to_list_owner') || 0; 
	 $form_vals{archive_mailings}        	  = $q->param('archive_mailings')        || 0; 

	my $tmp_record = {};
	if($q->param('key')){
		$tmp_record = $self->get_record($q->param('key'));
	}
		 
	$form_vals{headers} = {};
	
	if(defined($q->param('Reply-To'))){
		$form_vals{headers}->{'Reply-To'}     = $q->param('Reply-To');
	}
	if(defined($q->param('Errors-To'))){
		$form_vals{headers}->{'Errors-To'}    = $q->param('Errors-To');
	}
	if(defined($q->param('Return-Path'))){
		$form_vals{headers}->{'Return-Path'}  = $q->param('Return-Path');
	}
	if(defined($q->param('X-Priority'))){
		$form_vals{headers}->{'X-Priority'}   = $q->param('X-Priority');	
	}
	if(defined($q->param('Subject'))){	
		$form_vals{headers}->{Subject}        = $q->param('Subject');
	}
	
	if(keys %{$tmp_record->{headers}}){ 
		# That sure was ugly... 
		%{$form_vals{headers}} = (%{$tmp_record->{headers}}, %{$form_vals{headers}}); 
	}
	
	
	for my $t('PlainText', 'HTML'){ 
		$form_vals{$t.'_ver'}->{source}                    = $q->param($t.'_source'); 

#		$form_vals{$t.'_ver'}->{text}                      = $q->param($t.'_text'); 

		$form_vals{$t.'_ver'}->{url}                       = $q->param($t.'_url');
		$form_vals{$t.'_ver'}->{file}                      = $q->param($t.'_file'); 
	    $form_vals{$t.'_ver'}->{use_email_template}        = $q->param($t.'_use_email_template')        || 0; 
	    $form_vals{$t.'_ver'}->{only_send_if_defined}      = $q->param($t.'_only_send_if_defined')      || 0; 
		$form_vals{$t.'_ver'}->{only_send_if_diff}         = $q->param($t.'_only_send_if_diff')         || 0;    
	    $form_vals{$t.'_ver'}->{grab_headers_from_message} = $q->param($t.'_grab_headers_from_message') || 0; 
		$form_vals{$t.'_ver'}->{text} =~ s/\r\n/\n/g;	   # I hate browsers.
		
		$form_vals{$t.'_ver'}->{url_options}               = $q->param($t.'_url_options'); 
		$form_vals{$t.'_ver'}->{url_username}              = $q->param($t.'_url_username'); 
		$form_vals{$t.'_ver'}->{url_password}              = $q->param($t.'_url_password'); 
		$form_vals{$t.'_ver'}->{proxy}                     = $q->param($t.'_proxy'); 
		         
		
		
		if($q->param('key')){
			%{$form_vals{$t.'_ver'}} = (%{$tmp_record->{$t.'_ver'}}, %{$form_vals{$t.'_ver'}}); # so as not to whipe out things like the checksums...	
		}else{ 
			$form_vals{last_schedule_run} = time;
		}
	}
	
	# See what I did, here?
	$form_vals{'PlainText_ver'}->{text}                 = $q->param('PlainText_text'); 
	$form_vals{'HTML_ver'}->{text}                      = $q->param('html_message_body'); 
	

	$form_vals{attachments} = []; 
	
	
	my $att_i = $q->param('num_attachments') || 0; 
	my $i = 0; 
	my $ditch_num; 
	
	
	if($action =~ m/Remove Attachment /){
		$ditch_num = $action; 
		$ditch_num =~ s/Remove Attachment //;
	}
	for($i = 0; $i <= $att_i; $i++){ 
		next if(defined($ditch_num) && ($ditch_num eq $i)); 
		
		my $attachment = {}; 
		$attachment->{attachment_filename}     = $q->param('attachment_filename_'.$i); 
	    $attachment->{attachment_disposition}  = $q->param('attachment_disposition_'.$i); 
	    $attachment->{attachment_mimetype}     = $q->param('attachment_mimetype_'.$i); 	
		
		push(@{$form_vals{attachments}}, $attachment) if $q->param('attachment_filename_'.$i); 

	} 
	
	# Profile Fields
	# First, let's figure out what they may be...
	
	require DADA::MailingList::Subscribers; 
	my $lh = DADA::MailingList::Subscribers->new(
				{
					-list => $self->{name},
				}
			); 
	
	my $fields    = [];  
	my $saved_pso = []; 
	
	
	$fields = $lh->subscriber_fields; 
	push(@$fields, 'email'); 
	push(@$fields, 'subscriber.timestamp'); 
	
	for my $field(@$fields){ 
	    if($field eq 'subscriber.timestamp') { 
	        #if(defined($q->param($field . '.value'))){ 
    		    push(@$saved_pso, {
    				field_name     => $field,
    				field_rangestart  => $q->param($field . '.rangestart'), 
    				field_rangeend    => $q->param($field . '.rangeend'),  
				}); 
    		#}
	    }
	    else { 	    
    		if(defined($q->param($field . '.value'))){ 
    				push(@$saved_pso, {
        				field_name     => $field,
        				field_operator => $q->param($field . '.operator'), 
        				field_value    => $q->param($field . '.value'),  
    				}
    			); 
    		}
        }
	}
	
	$form_vals{partial_sending_params} = $saved_pso; 
	
	#use Data::Dumper; 
	# die Dumper(\%form_vals); 
	
	my $s_key = $q->param('key'); 			
	my $key = $self->save_record(
				-key   => $s_key, 
				-mode  => 'append', 
				-data  => \%form_vals
			); 
	return $key;  
}




sub mailing_date { 
	
	my $self = shift; 
	my $q    = shift; 

    my $min        = $q->param('mail_minute') || 0;
    my $hour       = $q->param('mail_hour')   || 12;
    my $mday       = $q->param('mail_day')    || 1;
    my $mon        = $q->param('mail_month')  || 0;
    my $year       = $q->param('mail_year')   || 0;
    my $mail_am_pm = $q->param('mail_am_pm')  || 'am';

    # This is a little hacky...
    if ( $mail_am_pm eq 'pm' ) {

        # But - if the hour is, "12"
        # 12 + 12 is, "24" - not, "0' and not just, "12"
        if ( $hour != 12 ) {
            $hour += 12;
        }
    }
    elsif ( $mail_am_pm eq 'am' ) {
        if ( $hour == 12 ) {
            $hour = 0;
        }
    }

    $min = int($min);
    require Time::Local;
    my $time = Time::Local::timelocal( 0, $min, $hour, $mday, $mon, $year );
    
	return $time;

}








sub run_schedules { 
	my $self           = shift; 
	
	
	my %args = (-test    => undef, 
				-verbose => undef,
					       @_); 
	my $need_to_backup = 0; 
	
	my $r = ''; 
				
	my $time        = time;
	
	$r .= "\n" . '-' x 72 . "\nRunning Schedule For: " . $self->{name} . "\n";
	$r .=  "Current time is: " . $self->printable_date($time) . "\n";

	my @record_keys = $self->record_keys(); 
	

		$r .=  "    No schedules to run.\n" if ( !@record_keys);
	for my $rec_key(@record_keys){																#for all our schedules - 
		
		my $mail_status = {};
		my $checksums   = {};
			
		my $mailing_schedule  = $self->mailing_schedule($rec_key);
		my $rec               = $self->get_record($rec_key); 
		my $run_this_schedule = 0;	
		my $never_ran_before  = 0; 
		
		$r .=  "\n    Examining Schedule: '" . $rec->{message_name} . "'\n";
		
		if($rec->{active} ==1){													 							#first things first, is this schedule even active?
		
			$r .=  "    '" . $rec->{message_name} . "' is active -  \n";
			
			if (! $rec->{last_schedule_run}){
				$rec->{last_schedule_run} = ($time - 1);							# This must be your first time, don't be nervous; tee hee!
				$never_ran_before         = 1;
			}
			
			if($rec->{last_mailing}){ 
				$r .=  "        Last mailing:              " . $self->printable_date($rec->{last_mailing}) . "\n";
			}
			    
			    if($never_ran_before == 1){ 
			    	$r .=  "        This seems to be the first time schedule has been looked at...\n";
			    }else{ 
			    	$r .=  "        Schedule last checked:     " .   $self->printable_date($rec->{last_schedule_run}) . "\n";
				}
			
			if($mailing_schedule->[0]){ 
				$r .=  "        Next mailing should be on: " . $self->printable_date($mailing_schedule->[0]) . "\n";
			}
			CHECKSCHEDULE: for my $s_time(@$mailing_schedule){
													# this should be last mailing, eh?!
													# no, since not all schedules repeat.
				if(($s_time <= $time) && ($s_time > $rec->{last_schedule_run})){								# Nothing in the future, mind.		
																			   		   							# Nothing before we need to.
																			   		   							
				# There's a bug in here. For instance, a schedule will not go out, even
				# though the scheduled mailing is in the past IF the schedule has never
				# been checked. 
				
				#	$s_time = scheduled times
				#	$time   = right now
				#	$rec->{last_schedule_run} - the last time it was run 
				
				# 	$rec->{last_schedule_run} COULD BE $time as well, 
				#   if the schedule had never run. What to do? 
				
				# we could set $rec->{last_schedule_run} to ($time - 1) if it's undefined,
				# or set the $rec->{last_schedule_run} to the time the schedule was first created...?
				# OR i guess we can do both..
				#
				# at the moment, i'm going to do both, since I can't remember if $rec->{last_schedule_run}
				# is wiped out everytime a schedule is edited. 
			
																			   		   							 
						$r .=  "            '" . $rec->{message_name} . "' scheduled to run now! \n";
						$run_this_schedule = 1;
						last CHECKSCHEDULE; 															# run only the last schedule, lest we bombard a hapless list. 						 
				}
			}
		}else{ 
			$r .=  "        '" . $rec->{message_name} . "' is inactive. \n";
		}
		
		if($run_this_schedule == 1){ 
			if($args{-test} == 1){ 		
				($mail_status, $checksums) = $self->send_scheduled_mailing(
																		   -key   => $rec_key, 
																		   -test  => 1, 
																		   -hold  => 1,
																		  ); 								
			}else{ 				
				 ($mail_status, $checksums) = $self->send_scheduled_mailing(
																			-key  => $rec_key, 
																			-test => $rec->{only_send_to_list_owner},
																			-hold => 1, 
																			); 
				if(! keys %$mail_status){ 
					$rec->{last_mailing} = $time;																# remember we sent the message at this time;  						
				}
			}			
		}
		
		
		if(! $args{-test}){ 
		     $rec->{active}            = 0 if ! $mailing_schedule->[0];
		 	 $rec->{last_schedule_run} = $time;		
		 	 
			 if(keys %$checksums){ 
			 		$rec->{PlainText_ver}->{checksum} = $checksums->{PlainText_checksum};
			 		$rec->{HTML_ver}->{checksum}      = $checksums->{HTML_checksum};			 	
			 }	
			
			# DEV: strangely, this will cause a backup to be made, each time you run the schedule. 
			# DEV: Need to make this, so it only, at the very least, saves once for all the scheds, 
			# Or things are going to get ridiculous. 
			$self->save_record(
				-key    => $rec_key, 
				-data   => $rec, 
				-mode   => 'append',
				-backup => 0, 
			); 	# save the changes we've made to the record.			
			
			$need_to_backup = 1; 
			$rec            = $self->get_record($rec_key); 
			
			
		} 
	
		if(keys %$mail_status){
			$r .=  "\n            ***    Scheduled Mailing Not Sent, Reason(s):    ***\n";
			$r .=   '                - ' .  DADA::App::Guts::pretty($_) . "\n" for keys %$mail_status;
			$r .=  "\n";
			
		}
		
		if((! $args{-test})              && 
		   (! keys %$mail_status)        && 
		   ($rec->{active}         == 0) &&
		   ($rec->{self_destruct}  == 1)
		  ){ 
		  	$r .= "\n        Schedule is set to self destruct! \n";
			$self->remove_record($rec_key); 
		}else{ 
			#print "nope!"; 
		}
		
		
	}
	
	$r .= '-' x 72 . "\n";
	
	$self->_send_held_messages; 
	
	if($need_to_backup == 1){ 
		$self->backupToDir;
	}
	return $r; 
	
	
}



=pod

=head2 mailing_schedule

 my $mailing_schedule = $mss->mailing_schedule($key);

returns a reference to an array of times that a schedule saved in $key has to be sent out.

=cut


sub mailing_schedule {
    my $self     = shift;
    my $key      = shift;
    my $today_is = time;

    if ( !defined($key) ) {
        croak "no key $!";
    }

    my $r             = $self->get_record($key);
    my $sched_mailing = $r->{mailing_date};

    if ( $r->{repeat_mailing} != 1 ) {

        # not right now, when we last try to run the schedule.
        if ( $r->{mailing_date} > $r->{last_schedule_run} ) {
            return [ $r->{mailing_date} ];
        }
        else {
            return [];
        }
    }
    else {
        if ( $r->{repeat_times} < 1 ) {
            return [ $r->{mailing_date} ];
        }
        else {

            my $timespan = 0;
            $timespan = 60                 if $r->{repeat_label} eq 'minutes';
            $timespan = 60 * 60            if $r->{repeat_label} eq 'hours';
            $timespan = 60 * 60 * 24       if $r->{repeat_label} eq 'days';
            $timespan = 60 * 60 * 24 * 30  if $r->{repeat_label} eq 'months';
            $timespan = 60 * 60 * 24 * 365 if $r->{repeat_label} eq 'years';

            if ( $r->{repeat_times} ) {
                $timespan = ( $timespan * $r->{repeat_times} );
            }

            my $i = 0;
            my @mailing_times;    # = ($r->{mailing_date});
            if ( $r->{mailing_date} > $r->{last_schedule_run} ) {
                @mailing_times = ( $r->{mailing_date} );
            }

#Fucker. $r->{repeat_number}     = 1000      if $r->{repeat_number} eq 'indefinite';

            if ( !$r->{last_schedule_run} ) {
                $r->{last_schedule_run} = $today_is;
            }
            if ( !$r->{repeat_number} ) {
                $r->{repeat_number} = 0;
            }

            if ( $r->{repeat_number} eq 'indefinite' ) {

                # yeah, we *could* find each and every time a mailing should
                # go out, until... inifinity, but come now.
                # This will just find the next time a mailing should go out.

                my $i = 1;
                while ( $i == 1 ) {
                    $sched_mailing = ( $sched_mailing + $timespan );
                    if ( $sched_mailing > $r->{last_schedule_run} )
                    {    # should /this/ be $r->{last_mailing}?
                            # It doesn't matter, since only one schedule is
                            # passed to the scheduled runner.
                        push ( @mailing_times, $sched_mailing );
                        $i = 0;
                    }
                }

            }
            else {
                for ( $i = 0 ; $i <= $r->{repeat_number} ; $i++ ) {
                    $sched_mailing = ( $sched_mailing + $timespan );
                    push ( @mailing_times, $sched_mailing )
                      if $sched_mailing > $r->{last_schedule_run};
                }
            }

            return \@mailing_times;
        }

    }
}





=pod

=head2 printable_date

 $mss->printable_date($form_vals->{last_mailing})

returns a date that's pretty to look at, when given a number of seconds since epoch.

=cut


sub printable_date { 
	
	# DEV: Tests are needed for this and actually, a better method should be 
	# used to create this... 
	my $self = shift; 
	my $date = shift; 
 	return scalar localtime($date); 


} 


=pod

=head2 send_scheduled_mailing

 my ($mail_status, $checksums) 
 	= $self->_send_scheduled_mailing(
									-key   => $rec_key, 
									-test  => 0, 
									-hold  => 1,
									);

Sends an individual schedule, as defined by the information 
in B<-key>. if B<-hold> is set to 1, mailing will be queued until all 
schedules are run. (should be set to 1). If B<-test> is set to 1, 
only a test mailing (message to the list owner) will be run. 

=cut

sub send_scheduled_mailing { 
	
	my $self = shift; 
	
	my %args = (-key            => undef, 
				-test           => 0,
				-hold           => 0,
				-test_recipient => undef,   
				@_); 
				
	croak "no key!" if ! $args{-key}; 
	
	my ($send_flags, $checksums, $message) = $self->_build_email(-key => $args{-key});
	
	
	if(! keys %$send_flags){ 
	
		my $ls = DADA::MailingList::Settings->new({-list => $self->{name}}); 

		
		require DADA::Mail::Send; 
		my $mh = DADA::Mail::Send->new(
					{
						-list   => $self->{name}, 
						-ls_obj => $ls, 
					}
				); 		   
				
		   $mh->ignore_schedule_bulk_mailings(1);
		   if($args{-test} == 1){ 
		   		$mh->mass_test(1);
		  		if(defined($args{-test_recipient})){ 
					$mh->mass_test_recipient($args{-test_recipient});
				}
  		 	}

		### Partial Sending Stuff... 
		### This is very much... busy, to say the least... 
		# Probably should put this in its own method... 
		# What's funny to me, is that it works.... 
		
				my $record                 = $self->get_record($args{-key});
				my $partial_sending_params = $record->{partial_sending_params}; 
				my $partial_sending = {}; 
    			
				for my $field(@$partial_sending_params){ 
				    if($field->{field_name} eq 'subscriber.timestamp') { 
				        $partial_sending->{$field->{field_name}} = {
                            -rangestart  => $field->{field_rangestart}, 
            				-rangeend    => $field->{field_rangeend}, 
    				    };
				    }
				    else { 
    					$partial_sending->{$field->{field_name}} = {
    					    -operator => $field->{field_operator},
    					    -value    => $field->{field_value},
    				    };
                    }
				} 
				if(keys %$partial_sending){ 
					$mh->partial_sending($partial_sending); 
				}

		###/ Partial Sending Stuff... 


		   
		   if($args{-hold} == 1){ 
		   		push(@{$self->{held_mailings}}, {-key => $args{-key}, -test => $args{-test}, -obj => $mh, -message => $message}); 
		   }else{ 
		   		my $message_id = $mh->mass_send(%$message);
		   		if ($args{-test} != 1){
		   			$self->_archive_message(-key => $args{-key}, -message => $message, -mid => $message_id); 
	   	   		}
	   	   }
	}   
	   return ($send_flags, $checksums); 
	   
}







=pod

=head1 Private Methods

=head2 _send_held_messages

 $self->_send_held_messages; 

messages are queued up before being sent. Calling this method will send 
these queued messages. 

=cut


sub _send_held_messages { 

	my $self = shift; 
	for my $held(@{$self->{held_mailings}}){ 
		my $obj     = $held->{-obj}; 
		my $message = $held->{-message}; 
		my $key     = $held->{-key}; 
		my $test    = $held->{-test};
		my $message_id = $obj->mass_send(%$message); 
		if ($held->{-test} != 1){
			$self->_archive_message(-key => $key, -message => $message, -mid => $message_id); 
		}		   		
	}
} 








=pod

=head2 _build_email

 my ($send_flags, $checksums, $message) = $self->_build_email(-key => $key);

Creates an email message ($message) that can then be sent with DADA::Mail::Send. It also 
returns the hashref, $send_flags that will denote any problems with message building, 
as well as a MD5 checksum of the message itself. 

=cut

sub _build_email { 

	my $self = shift; 
	my %args = (-key => undef, 
				@_); 
				
	croak "no key!" if ! $args{-key}; 				

	my $record = $self->get_record($args{-key});
	
	require MIME::Lite; 
	MIME::Lite->quiet(1);
	
	my $send_flags = {}; 
	
	# Hmm - we can have this happen, to get the checksum stuff and then *redo* it for the URL stuff, if needed? 
	# Because - well, the checksum is probably even more accurate, before we bring the data into MIME::Lite::HTML - 
	# As it says right in the docs the MIME creation stuff is desctruction. Ok? OK.
	# Then, if we do pull data from a URL, we just throw the info from $HTML_ver away, remake it, via 
	# MIME::Lite::HTML and call it good. 
	my ($pt_flags,   $pt_checksum,   $pt_headers,   $PlainText_ver) = $self->_create_text_ver(-record => $record, -type => 'PlainText'); 
	my ($html_flags, $html_checksum, $html_headers, $HTML_ver)      = $self->_create_text_ver(-record => $record, -type => 'HTML'); 
		
	#use Data::Dumper; 
	#die Data::Dumper::Dumper($HTML_ver); 
	
	# So. Right here? 
	require DADA::App::FormatMessages; 
	($PlainText_ver, $HTML_ver) = DADA::App::FormatMessages::pre_process_msg_strings($PlainText_ver, $HTML_ver); 
	
	$send_flags->{PlainText_ver_undefined}  = 1 if (! $PlainText_ver)	&&	($record->{PlainText_ver}->{only_send_if_defined}) == 1;
	$send_flags->{HTML_ver_undefined}       = 1 if (! $HTML_ver)	    &&	($record->{HTML_ver}     ->{only_send_if_defined}) == 1;
	
	
	%$send_flags = (%$send_flags, %$pt_flags, %$html_flags); 
	
	# Wait, so EVEN if there's flags that should stop the mailing - we *MAKE* the mailing (just to have it not be sent?) 
	# I thin it's there, so you can send a test message out to yourself. 
	#
	
	
	my $ls = DADA::MailingList::Settings->new({-list => $self->{name}}); 
	# So... then we have to first check if we have an HTML ver *AND* we need to pull it from a URL
	# (Actually, first I have to figure out how to add attachments to a MIME::Lite::HTML thingy...) 

	# Well, wait, I guess this'll be done for *every* type of HTML email? 
	# This'll be a weird if() statement - 
	
	my $entity; 
	
	require MIME::Entity; 
	if($HTML_ver){
		
		require DADA::App::MyMIMELiteHTML; 
		
		 my $login_details = undef; 
		if(defined($record->{HTML_ver}->{url_username}) && defined($record->{HTML_ver}->{url_password})){ 
             $login_details =  $record->{HTML_ver}->{url_username} . ':' . $record->{HTML_ver}->{url_password}
         }


		 my $mailHTML = new DADA::App::MyMIMELiteHTML(
		
							'IncludeType' => 'cid', 
							'IncludeType' => $record->{HTML_ver}->{url_options}, 
							
							# This has to be changed to actually be a changeable var
							'TextCharset' => $ls->param('charset_value'),
							'HTMLCharset' => $ls->param('charset_value'), 

							HTMLEncoding  => $ls->param('html_encoding'),
							TextEncoding  => $ls->param('plaintext_encoding'),

							# Drrrrr, we're just using a string - these are useless
							# Ah! I've placed them in the right places - it all should work, YEAH!
							# (($record->{HTML_ver}->{proxy}) ? (Proxy => $record->{HTML_ver}->{proxy},) :  ()),
							# (($login_details) ? (LoginDetails => $login_details,) :  ()),

							(
							($DADA::Config::CPAN_DEBUG_SETTINGS{MIME_LITE_HTML} == 1) ? 
							(Debug => 1, ) :
							()
							), 
						 ); 

		
		# Have to add the auto-plaintext stuff here... although this should 
		# *really* be done automatically by Dada::App:FormatMessages...
		# 
		my $plaintext_alt = undef; 
		
		if($PlainText_ver){ 
				$plaintext_alt = $PlainText_ver;  
        }
    	else { 
			    $plaintext_alt = html_to_plaintext({-str => $HTML_ver });
		}
        $plaintext_alt = safely_encode($plaintext_alt); 
		$HTML_ver      = safely_encode($HTML_ver); 

		my $MIMELiteObj; 
		if($record->{'HTML_ver'}->{source} eq 'from_url'){
			$MIMELiteObj = $mailHTML->parse($HTML_ver, $plaintext_alt, $record->{'HTML_ver'}->{url});
		}
		else { 
			$MIMELiteObj = $mailHTML->parse($HTML_ver, $plaintext_alt);
		}
		
		# Error Handling... well, add later...
		my $html_msg = ''; 
		eval { 
				$html_msg = $MIMELiteObj->as_string;
				$html_msg = safely_decode($html_msg);
			}; 		
		if($@){ 
			# error message...
		}
		else {
			require MIME::Parser; 
			my $parser = new MIME::Parser; 
			   $parser = optimize_mime_parser($parser);
			$entity = $parser->parse_data(
				$html_msg = safely_encode($html_msg)
			); 
			 
			if(! $record->{attachments}->[0]) { 
				# well, nothin'
			}
			else { 
				

				my $new_entity = MIME::Entity->build(Type => 'multipart/mixed'); 
				$new_entity->add_part($entity);
				for my $att(@{$record->{attachments}}){ 
				   $new_entity->attach(
						Type        => $self->_find_mime_type($att), 
						Path        => $att->{attachment_filename}, 
						Disposition => $att->{attachment_disposition}
				   );
				}
				$entity = $new_entity; 
				
			}
			
			for(keys %$pt_headers) { 
				if($entity->head->get($_, 0)){ 
					$entity->head->delete($_);
					$entity->head->add($_, $pt_headers->{$_});
				}
			}
			for(keys %$html_headers) { 
				if($entity->head->get($_, 0)){ 
					$entity->head->delete($_);
					$entity->head->add($_, $html_headers->{$_});
				}
			}			
			
		}
	
		
	}
	else { 
		if($PlainText_ver){ 
			
			$PlainText_ver = safely_encode($PlainText_ver); 
			$entity = MIME::Entity->build(
						Type      =>'text/plain',
						Encoding  => $ls->param('plaintext_encoding'), 
						Data      => $PlainText_ver,
				  	  );	
			
			for(keys %$pt_headers) { 
				if($entity->head->get($_, 0)){ 
					$entity->head->delete($_);
					$entity->head->add($_, $pt_headers->{$_});
				}
			}
						
		}
		else{ 
	
			$entity = MIME::Entity->build(
						Type      =>'multipart/mixed',
				  	  ); 
		}
		
		# Attachments...
		for my $att(@{$record->{attachments}}){ 
		   $entity->attach(
				Type        => $self->_find_mime_type($att), 
				Path        => $att->{attachment_filename}, 
				Disposition => $att->{attachment_disposition}
		   );
		
		
		}
	
	}
	
	 
	require DADA::App::FormatMessages; 
	my $fm = DADA::App::FormatMessages->new(-List => $self->{name}); 
	   $fm->mass_mailing(1); 
	   # What?
	   # I think this is only for our return value?
	   $record->{headers}->{Subject} = $pt_headers->{Subject} if $pt_headers->{Subject};
	   $record->{headers}->{Subject} = $html_headers->{Subject} if $html_headers->{Subject};
	 
	   if(exists($record->{headers}->{Subject})){ 
	   		$fm->Subject($record->{headers}->{Subject}) 
	   }	
	
	# OK, we at least have to populate so these get hit?
	# Maybe just set these to, "1" or some other type of true value?	
	if($PlainText_ver && $HTML_ver){ 
	
		$fm->use_plaintext_email_template($record->{PlainText_ver}->{use_email_template});
		$fm->use_html_email_template(     $record->{HTML_ver}->{use_email_template});
	
	}elsif($PlainText_ver){ 
	
		$fm->use_plaintext_email_template($record->{PlainText_ver}->{use_email_template});
		$fm->use_html_email_template(     $record->{PlainText_ver}->{use_email_template});
		
	}elsif($HTML_ver){
	
		$fm->use_plaintext_email_template($record->{HTML_ver}->{use_email_template});
		$fm->use_html_email_template(     $record->{HTML_ver}->{use_email_template});
		
	}
		
	   $fm->use_header_info(1);
	    
    my $stringify = $entity->stringify; 
	   $stringify = safely_decode($stringify);
	
	my ($final_header, $final_body) = $fm->format_headers_and_body(-msg => $stringify);
	
	require DADA::Mail::Send; 
	my $mh = DADA::Mail::Send->new(
				{ 
					-list   => $self->{name}, 
					-ls_obj => $ls, 
				}
			); 
	my %headers = $mh->clean_headers($mh->return_headers($final_header));	
		
	my $return = {};
	
	   $return = { 
			     # In this case, I don't want to overwrite %headers, 
	   			  %{$record->{headers}},
				  %headers, 
			      Body      => $final_body,
			   }; 
						  
	# Awww, shit - checksums?!
	# I guess for the attachment one... - do an "as_string" on the body? And then, insert it in? 
	# This is getting a little messy... hmm... 
	#
	return ($send_flags, {PlainText_checksum => $pt_checksum, HTML_checksum => $html_checksum}, $return); 

}




=pod

=head2 _create_text_ver

my ($flags,   $checksum,   $headers,  $message) = $self->_create_text_ver(-record => $record, -type => 'PlainText'); 

Creates the text part of an email, using the information saved in the 
$record record. Returns any problemswith building the message in 
$flags ($hashref), a checksum in $checksum, headers (hashref) in 
$headers and the actual message in $message. B<-type> needs to 
be either B<PlaintText> or B<HTML>.

=cut




sub _create_text_ver { 
	
	my $self = shift; 
	
	my %args = (-record => {},
				-type   => undef,  
				@_); 
				
	croak "no record! $!"		unless keys %{$args{-record}}; 
	croak "no type!   $!"		unless $args{-type}; 	

	my $record       = $args{-record}; 
	my $type         = $args{-type};
	my $headers      = {};
	my $data         = undef;
	my $create_flags = {}; 
	 
	#use Data::Dumper; 
	#die Dumper($record); 
	
	if($record->{$type . '_ver'}->{source} eq 'from_file'){ 
		$data = $self->_from_file($record->{$type . '_ver'}->{file});
	}elsif($record->{$type . '_ver'}->{source} eq 'from_url'){ 
		$data = $self->_from_url($record->{$type . '_ver'}->{url}, $type . '_ver', $record); 
	}elsif($record->{$type . '_ver'}->{source} eq 'from_text'){ 
		$data = $record->{$type . '_ver'}->{text}; 
	}
		
	if($data){ 
		
		my $we_gotta_virgin = $self->_virgin_check($record->{$type . '_ver'}->{checksum}, \$data); 
		
		my $checksum = $self->_create_checksum(\$data);
		
		unless($we_gotta_virgin){  #mmmm, virgin...
			if($record->{$type . '_ver'}->{only_send_if_diff} == 1){ # hmmmm different...
				$create_flags->{$type . '_ver_same_as_last_mailing'} = 1; 
			}
		} 
		
		$data = DADA::App::Guts::strip($data); 
		if ($record->{$type . '_ver'}->{grab_headers_from_message} == 1) { 
			
			($headers, $data) = $self->_grab_headers($data);
		#	use Data::Dumper; 
		#die Data::Dumper::Dumper([$headers, $data]); 
		}
			
		return ($create_flags, $checksum, $headers, $data); 
	
	}else{  
		return ({},{}, undef), 	
	}	
	
}




=pod

=head2 _from_file

 my $data = $self->_from_file($filename); 

Grabs the contents of a file, returns contents.

=cut


sub  _from_file { 

	my $self = shift; 
	my $fn   = shift; 	
	croak "no filename!" if ! $fn; 
	
	open(FH, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $fn) or return undef; 
	my $data = undef; 
       $data = do{ local $/; <FH> };
	 
	close(FH); 
	return $data; 
}





=pod

=head2 _from_url

	my $data = $self->_from_url($url); 

returns the $data fetched from a URL

=cut


sub _from_url { 

	my $self    = shift; 
	my $url     = shift; 
	my $type    = shift; 
	my $record  = shift; 
 
	# Create a user agent object
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	   $ua->agent('Mozilla/5.0 (compatible; ' . $DADA::CONFIG::PROGRAM_NAME . ')'); 
       # http://stackoverflow.com/questions/1285305/how-can-i-accept-gzip-compressed-content-using-lwpuseragent
       
	if(defined($record->{$type . '_ver'}->{proxy})){ 
		$ua->proxy(
			['http', 'ftp'], 
			$record->{$type . '_ver'}->{proxy}
		); 
	}
	
	# Create a request
	my $req = HTTP::Request->new(
				GET => $url
			);
			
			#my $can_accept = HTTP::Message::decodable();
        	#my $res = $ua->get($url, 
        	#    'Accept-Encoding' => $can_accept,
        	#);
        	
        	
	# Pass request to the user agent and get a response back
	my $res = $ua->request($req);
	if(
	  defined($record->{$type . '_ver'}->{url_username}) && 
	  defined($record->{$type . '_ver'}->{url_password})
	){ 
	   $res->authorization_basic(
			$record->{$type . '_ver'}->{url_username}, 
			$record->{$type . '_ver'}->{url_password}
		);
	}
	# Check the outcome of the response
	if ($res->is_success) {
	    # return $res->decoded_content; #things should be already decoded, here. 
	    return safely_decode($res->content);
	}
	else {
	    carp "Problem fetching webpage, '$url':" . $res->status_line;
		return undef; 
	}
}






=pod

=head2 _create_checksum

 my $cmp_cs = $self->_create_checksum($data_ref);	

Returns an md5 checksum of the reference to a scalar being passed.

=cut


sub _create_checksum { 

	my $self = shift; 
	my $data = shift; 

	use Digest::MD5 qw(md5_hex); # Reminder: Ship with Digest::Perl::MD5....
	
	if($] >= 5.008){
		require Encode;
		my $cs = md5_hex(safely_encode($$data));
		return $cs;
	}else{ 			
		my $cs = md5_hex($$data);
		return $cs;
	}
} 





=pod

=head2 _virgin_check

 my $we_gotta_virgin = $self->_virgin_check($record->{$type . '_ver'}->{checksum}, \$data); 
	
Figures if a copy of a message has previously been sent, using the previous checksum value.

=cut



sub _virgin_check { 

	my $self = shift; 
	my $cs   = shift; 
	
	my $data_ref = shift;
	
	
	my $cmp_cs = $self->_create_checksum($data_ref);

	#	carp 'comparing: ' . $cmp_cs . ' with: ' . $cs; 
	
	return 1 if ! $cs; 
	(($cmp_cs eq $cs) ? (return 0) : (return 1)); 
	
}





=pod

=head2 _grab_headers

 ($headers, $data) = $self->_grab_headers($data) if $record->{$type . '_ver'}->{grab_headers_from_message} == 1;
	
Splits the message in $data into headers and a body. 

=cut

sub _grab_headers { 

	my $self = shift; 
	my $data = shift; 

	$data =~ m/(.*?)\n\n(.*)/s; 
	
	my $headers = $1; 
	my $body    = $2;

	#init a new %hash
	my %headers;
	
	# split.. logically
	my @logical_lines = split /\n(?!\s)/, $headers;
	 
		# make the hash
		for my $line(@logical_lines) {
			  my ($label, $value) = split(/:\s*/, $line, 2);
			  $headers{$label} = $value;
			  
			 # carp '$label ' . $label; 
			 # carp '$value ' . $value; 
			}
	
	if(keys %headers){ 
		return (\%headers, $body);
	}else{ 
		return ({}, $data);
	} 
}




sub _archive_message { 
	my $self = shift; 
	my %args = (
				-key     => undef, 
				-message => {}, 
				-mid     => undef, 				
				@_,
			 ); 
	croak "no -key!"      if !$args{-key}; 
	croak "no -message!"  if !keys %{$args{-message}};
	croak "no -mid!"      if ! $args{-mid}; 
	
	my $rec = $self->get_record($args{-key}); 
	
	if($rec->{archive_mailings} != 1){ 
		return; 
	}

	require DADA::MailingList::Archives; 		
	my $ls        = DADA::MailingList::Settings->new({-list => $self->{name}}); 

	my $la = DADA::MailingList::Archives->new({-list => $self->{name}});  
		
	my $raw_msg; 
	
	for(keys %{$args{-message}}){ 
		next if $_ eq 'Body';
		$raw_msg .= $_ . ': ' . $args{-message}->{$_} . "\n";
	}
	$raw_msg .= "\n\n" . $args{-message}->{Body}; 


	$la->set_archive_info(
						  $args{-mid}, 
						  $args{-message}->{Subject}, 
						  undef, 
						  undef,
						  $raw_msg,
						 );
	
}



# deprecated.
sub can_archive { 
	return 1; 
}







=pod

=head2 _find_mime_type

 my $type = $self->_find_mime_type('filename.txt'); 

Attempts to figure out the MIME type of a filename.

=cut


sub _find_mime_type { 
	my $self = shift; 
	my $att  = shift; 
	
	croak "no attachment! $! " if ! $att; 
		
	my $mime_type = 'AUTO'; 
	
	if ($att->{attachment_mimetype} =~ m/auto/){ 
		my $file_ending = $att->{attachment_filename};
		
		require MIME::Types; 
		require MIME::Type;
	
		if(($MIME::Types::VERSION >= 1.005) && ($MIME::Type::VERSION >= 1.005)){ 
			$file_ending =~ s/^\.//; 
			my $mimetypes = MIME::Types->new;
			my MIME::Type $attachment_type  = $mimetypes->mimeTypeOf($file_ending);
			$mime_type = $attachment_type;
		}else{ 
			# Alright, we're going to have to figure this one ourselves...
			if(exists($DADA::Config::MIME_TYPES {'.'.lc($file_ending)})) {  
				$mime_type = $DADA::Config::MIME_TYPES {'.'.lc($file_ending)};
			}else{ 
				# Drat! all hope is lost! Abandom ship!
				$mime_type = $DADA::Config::DEFAULT_MIME_TYPE; 
			}
		}
	}else{ 
		$mime_type = $att->{attachment_mimetype};
	}		

	$mime_type = 'AUTO' if(! $mime_type); 
	
	return $mime_type; 
}

1;


=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

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

