package DADA::MailingList::Schedules;
use strict;

use lib qw(
  ../../
  ../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_MessageDrafts};

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
        $self->{ls_obj}->save({schedule_last_checked_time => time});
        undef($self->{ls_obj}); 
        $self->{ls_obj} =  DADA::MailingList::Settings->new( { -list => $self->{list}  } );
    }
    
    
}




sub run_schedules { 

    my $self   = shift; 

    my ($args) = @_; 
    
    if(!exists($args->{-verbose})){ 
        $args->{-verbose} = 0; 
    }
    my $t    = time; 
    
    my $r = "Running Schedules for, " . $self->{list} . "\n";
       $r .= '-' x 72 . "\n";
       $r .= "\t* Current Server Time: " . scalar(localtime($t)) . "\n";  
       $r .= "\t* Scheduled Mass Mailings Last Ran: " . scalar(localtime($self->{ls_obj}->param('schedule_last_checked_time'))) . "\n"; 

    my $count = $self->{d_obj}->count({-role => 'schedule'});

    if($count <= 0){ 
        $r .= "\t* No Schedules currently saved\n";
    }     
    else { 
        $r .= "\t* $count Schedule(s)\n";
    }
    my $index = $self->{d_obj}->draft_index({-role => 'schedule'});
    
    SCHEDULES: for my $sched(@$index){ 
        
        #$r .= "Raw Paramaters:\n"; 
        #require Data::Dumper; 
        #$r .= Data::Dumper::Dumper($sched);
        
        $r .= "\n\t\t* Subject: " . $sched->{Subject} . "\n\n"; 
        
        if($sched->{schedule_activated} != 1){ 
            $r .= "\t\t* Schedule is NOT Activated.\n"; 
            next SCHEDULES; 
            $r .= "\t\t* Schedule is Activated!\n"; 
        }
        
        my $schedule_times = []; 
        
        my $can_use_datetime = DADA::App::Guts::can_use_datetime(); 

        if($sched->{schedule_type} eq 'recurring' && $can_use_datetime == 0){  
            $r .= "Recurring schedule set, but the DateTime CPAN Perl module will need to be installed.\n";
            next SCHEDULES; 
        }
        elsif($sched->{schedule_type} eq 'recurring' && $can_use_datetime == 1){ 
            
            my $d_lt = {
                7 => 'Sunday',
                1 => 'Monday',
                2 => 'Tuesday',
                3 => 'Wednesday',
                4 => 'Thursday',
                5 => 'Friday',
                6 => 'Saturday',
            };
            my $days_str = undef; 
            # use Data::Dumper; 
            # die Dumper($sched->{schedule_recurring_days}); 
            for(@{$sched->{schedule_recurring_days}}){ 
                $days_str .= $d_lt->{$_} . ', '; 
            }
#            $r .= "\t\t* Schedule Type: Recurring\n"; 

            $r .= "\t\tThis is a *Recurring* mass mailing, between " . "\n\t\t" . 
            $sched->{schedule_recurring_displaydatetime_start} . 
            ' and ' . 
            $sched->{schedule_recurring_displaydatetime_end} .  "\n\t\t" .
            'on: ' . 
            $days_str ."\n\t\t" .
            'at: '  . $sched->{schedule_recurring_display_hms} . "\n\n"; 
            
            my ($status, $errors, $recurring_scheds)  = $self->recurring_schedule_times(
                {
                    -recurring_time => $sched->{schedule_recurring_display_hms},
                    -days           => $sched->{schedule_recurring_days}, 
                    -start          => $sched->{schedule_recurring_ctime_start}, 
                    -end            => $sched->{schedule_recurring_ctime_end}, 
                }
            ); 
            if($status == 0){ 
                $r .= "Problems calculating recurring schedules - skipping schedule: " . $errors; 
                next SCHEDULES; 
            }
            
            #require Data::Dumper; 
            #$r .=   Data::Dumper::Dumper($r_sched_t); 
            
            for(@$recurring_scheds){ 
                if(
                         $_->{ctime} >= ($t - 259_200) 
                    &&   $_->{ctime} <= ($t + 259_200) 
                ){ 
                    push(@$schedule_times, $_->{ctime}); 
                }
            }
            if(scalar @$schedule_times <= 0){ 
                $r .= "\t\t* No Scheduled Mailing needs to be sent out.\n";                 
            }
            else { 
                $r .= "\t\t* Approaching/Past Schedule Times:\n";
                for(@$schedule_times) { 
                    $r .= "\t\t\t* " . scalar localtime($_) . "\n"; 
                }
            }
        }
        else { 
            $r .= "\t\t* Schedule Type: One-Time\n"; 
            push(@$schedule_times, $sched->{schedule_single_ctime}); 
        }
        
        SPECIFIC_SCHEDULES: for my $specific_time(@$schedule_times) { 

            my $end_time; 
            if($sched->{schedule_type} eq 'recurring'){ 
                $end_time = $sched->{schedule_recurring_ctime_end}
            }
            else { 
                $end_time = $specific_time; 
            }
            
            if($end_time < ($t - 86400)) { # was this supposed to be sent a day ago? 
                $r .= "\t\t* Schedule is too late to run - should have ran " . formatted_runtime($t - $end_time) . ' ago.' . "\n"; 
                $r .= "Deactivating Schedule...\n"; 
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
                $r .= "\t\t* Schedule runs at: " . scalar localtime($specific_time) . "\n"; 
            }
        
            my $last_checked = $self->{ls_obj}->param('schedule_last_checked_time'); 
                
            if($specific_time > $t){ 
                $r .= "\t\t* ";
                
                if($sched->{schedule_type} eq 'recurring'){ 
                    $r .= "Next "; 
                }
                $r .= "Schedule will run " . formatted_runtime($specific_time - $t)   ." from now\n";
                next SPECIFIC_SCHEDULES; 
            }
        
            if($specific_time >= $self->{ls_obj}->param('schedule_last_checked_time')){ 
                $r .= "\t\t\t* Running schedule now!\n";
            
               my ($status, $errors, $message_id) = $self->{ms_obj}->construct_and_send(
                    {
                        -draft_id   => $sched->{id},
                        -screen     => $sched->{screen},
                        -role       => $sched->{role},,
                        -process    => 1, 
                    }
                );
                if($status == 1){ 
                    $r .= "\t\t* Scheduled Mass Mailing added to the Queue, Message ID: $message_id\n"; 
                }
                else { 
                    $r .= "\t\t* PROBLEMS with Mass Mailing:\n$errors\n"; 
                }
                if($sched->{schedule_type} ne 'recurring'){ 
                    $r .= "\t\t* Deactivating Schedule...\n"; 
                    $self->deactivate_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                        }
                    );
                }
            }
            
            if($sched->{schedule_type} ne 'recurring'){ 
                if($specific_time < $self->{ls_obj}->param('schedule_last_checked_time')){ 
                    $r .= "\t\t* Schedule SHOULD have been sent, but wasn't\n";
                    $r .= "\t\t* Deactivating Schedule...\n"; 
             
                    $r .= $self->deactivate_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                        }
                    );
                }
            }
        }
    }
    
    $self->{ls_obj}->save({schedule_last_checked_time => time});

    $r .= "\n"; 
    
    if($args->{-verbose} == 1){ 
        print $r; 
    }
    return $r; 
    
}

sub recurring_schedule_times {
    my $self = shift;
    my ($args) = @_;
    my $r = undef; 
    
    my $status = 1; 
    my $errors = undef; 
    my $times = [];
    
    # require Data::Dumper; 
    # $r .= "args:" . Data::Dumper::Dumper($args); 
    
    my $recurring_time = $args->{-recurring_time};
    my $days           = $args->{-days};
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

        $day_set = DateTime::Event::Recurrence->weekly(
            days    => $days,
            hours   => $hours,
            minutes => $minutes
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

sub DESTROY {}
    
1;