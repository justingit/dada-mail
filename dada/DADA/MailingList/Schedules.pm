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
       $r .= "\t* Schedules Last Run: " . scalar(localtime($self->{ls_obj}->param('schedule_last_checked_time'))) . "\n"; 

    my $count = $self->{d_obj}->count({-role => 'schedule'});

    if($count <= 0){ 
        $r .= "\t* No Schedules currently saved\n";
    }     
    else { 
        $r .= "\t* $count Schedules\n";
    }
    my $index = $self->{d_obj}->draft_index({-role => 'schedule'});
    SCHEDULES: for my $sched(@$index){ 
        
        #$r .= "Raw Paramaters:\n"; 
        #require Data::Dumper; 
        #$r .= Data::Dumper::Dumper($sched);
        
        $r .= "\n*\t\t Subject: " . $sched->{Subject} . "\n"; 
        
        if($sched->{schedule_activated} != 1){ 
            $r .= "\t\t* Schedule is NOT Activated.\n"; 
            next SCHEDULES; 
            $r .= "\t\t* Schedule is Activated!\n"; 
        }
        
        if($sched->{schedule_type} eq 'recurring'){ 
            
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
            for(@{$sched->{schedule_recurring_days}}){ 
                $days_str .= $d_lt->{$_} . ', '; 
            }
            $r .= "\t\t* Schedule Type: Recurring\n"; 
            $r .= 'This is a *Recurring* mass mailing, between ' . "\n" . 
            $sched->{schedule_recurring_localtime_start} . 
            ' and ' . 
            $sched->{schedule_recurring_localtime_end} .  "\n" .
            ' on: ' . 
            $days_str ."\n" .
            ' at: '  . $sched->{schedule_recurring_time} . "\n\n"; 
            
            my ($s_t_r, $r_sched_t)  = $self->recurring_schedule_times(
                {
                    -recurring_time => $sched->{schedule_recurring_time},
                    -days           => $sched->{schedule_recurring_days}, 
                    -start          => $sched->{schedule_recurring_time_start}, 
                    -end            => $sched->{schedule_recurring_time_end}, 
                }
            ); 
            $r .= "\n\n\$s_t_r: $s_t_r\n\n"; 
            
            #require Data::Dumper; 
            #$r .=   Data::Dumper::Dumper($r_sched_t); 
            
            my $recent_t = []; 
            for(@$r_sched_t){ 
                if(
                       $_->{ctime} > ($t - 86400) 
                    &&   $_->{ctime} < ($t + 86400) 
                ){ 
                    push(@$recent_t, $_->{ctime}); 
                }
            }
            if(scalar @$recent_t > 0){ 
                $r .= "Approaching Times:\n";
                for(@$recent_t) { 
                    $r .= scalar localtime($_) . "\n"; 
                }
            }
            else { 
                $r .= "No Scheduled Mailing needs to be sent out.\n"; 
            }
            #$r .= '$s_t_r: ' . $s_t_r; 
            
           # require Data::Dumper; 
           #$r .= Data::Dumper::Dumper($schedule_times); 
        
        }
        else { 
            $r .= "\t\t* Schedule Type: One-Time\n"; 
        }
=cut

        if($sched->{schedule_time} < ($t - 86400)) { # was this supposed to be sent a day ago? 
            $r .= "\t\t* Schedule is too late to run - should have ran " . formatted_runtime($t - $sched->{schedule_time}) . ' ago.' . "\n"; 
            $r .= "Deactivating Schedule...\n"; 
            $self->deactivate_schedule(
                {
                    -id     => $sched->{id},
                    -role   => $sched->{role},
                    -screen => $sched->{screen},
                }
            );
            next SCHEDULES;
        }
        else {     
            $r .= "\t\t* Schedule to run at: " . $sched->{schedule_localtime} . "\n"; 
        }
        
        
        my $last_checked = $self->{ls_obj}->param('schedule_last_checked_time'); 
                
        if($sched->{schedule_time} > $t){ 
            $r .= "\t\t* Schedule will run " . formatted_runtime($sched->{schedule_time} - $t)   ." from now\n";
            next SCHEDULES; 
        }
        
        if($sched->{schedule_time} >= $self->{ls_obj}->param('schedule_last_checked_time')){ 
            $r .= "\t\t\t* Schedule running now!\n";
            
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
            $r .= "\t\t* Deactivating Schedule...\n"; 
            $self->deactivate_schedule(
                {
                    -id     => $sched->{id},
                    -role   => $sched->{role},
                    -screen => $sched->{screen},
                }
            );
             
        }
        if($sched->{schedule_time} < $self->{ls_obj}->param('schedule_last_checked_time')){ 
            $r .= "\t\t* Schedule SHOULD have been sent, but wasn't\n";
            $r .= "\t\t* Deactivating Schedule...\n"; 
             
            $self->deactivate_schedule(
                {
                    -id     => $sched->{id},
                    -role   => $sched->{role},
                    -screen => $sched->{screen},
                }
            );
        }
=cut

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
    
    require Data::Dumper; 
    $r .= "args:" . Data::Dumper::Dumper($args); 
    
    my $recurring_time = $args->{-recurring_time};
    my $days           = $args->{-days};
    my $start          = $args->{-start};
    my $end            = $args->{-end};

    my $times = [];

    try {

        require DateTime;
        require DateTime::Event::Recurrence;
        
        my $start_dt = DateTime->from_epoch( epoch => $start );
        my $end_dt   = DateTime->from_epoch( epoch => $end );

        my ( $hours, $minutes, $seconds ) = split( ':', $recurring_time );

        $r .= '$start_dt ' . $start_dt->epoch . "\n"; 
        $r .= '$end_dt '   . $end_dt->epoch   . "\n";
        $r .= '$recurring_time ' . $recurring_time  . "\n";
        $r .= '$hours ' . $hours  . "\n";
        $r .= '$minutes ' . $minutes . "\n";
        $r .= '$seconds  '  . $seconds . "\n";
        

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
                    date  => $dt->datetime,
                    #ctime => $dt->epoch,
                    #'localtime' => scalar localtime($dt->epoch),
                    localtime => scalar localtime($self->T_datetime_to_ctime($dt->datetime)),
                   # 'datetime_to_ctime' => $self->T_datetime_to_ctime($dt->datetime), 
                    ctime => $self->T_datetime_to_ctime($dt->datetime), 
                }
            );
        }

    } catch {
        warn $_;
        $r .= 'PROBLEMS: ' . $_; 
    };

    return ($r, $times);
}

sub T_datetime_to_ctime {
    my $self = shift; 
    my $datetime = shift;
    warn '$datetime ' . $datetime; 
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
    
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen =>  $args->{-screen},  
        }
    ); 
    
    # deactivate.
    $local_q->param('schedule_activated', 0); 
    
    $self->{d_obj}->save(
        {
            -cgi_obj => $local_q,
            -id      => $args->{-id}, 
            -role    => $args->{-role},  
            -screen  =>  $args->{-screen},  
        }
    ); 

    return 1; 
}

sub DESTROY {}
    
1;