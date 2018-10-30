package DADA::App::Digests;
use strict;

use lib qw(
  ../../
  ../../DADA/perllib
);

use Carp qw(carp croak);

use DADA::Config qw(!:DEFAULT);
use DADA::Config;
use DADA::App::Guts;

use DADA::MailingList::Archives;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;

use Time::Local;

use Try::Tiny;

use vars qw($AUTOLOAD);

my $t =  $DADA::Config::DEBUG_TRACE->{DADA_App_Digests};

my %allowed = ( 
	test     => 0, 
	mock_run => 0, 
);

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;

    $self->_init($args);
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

	return if(substr($AUTOLOAD, -7) eq 'DESTROY');

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {
    my $self = shift;
    my ($args) = @_;
    $self->{list} = $args->{-list};
    $self->{ls_obj} = DADA::MailingList::Settings->new( { -list => $self->{list} } );

    if ( exists( $args->{-ctime} ) ) {
        warn 'passed -ctime: ' . $args->{-ctime}
            if $t;
        $self->{ctime} = $args->{-ctime};
    }
    else {
        warn 'no passed -ctime'
          if $t;
        $self->{ctime} = time;
    }
    warn 'ctime set to, ' . $self->{ctime}
      if $t;

    if ( !defined( $self->{ls_obj}->param('digest_last_archive_id_sent') )
        || $self->{ls_obj}->param('digest_last_archive_id_sent') <= 0 )
    {
        warn 'no current digest_last_archive_id_sent'
          if $t;
        warn q{$self->{ctime}:} . $self->{ctime}
          if $t;
        warn q{$self->{ls_obj}->param('digest_schedule'):} . $self->{ls_obj}->param('digest_schedule')
          if $t;
        warn 'ctime_2_archive_time:'
          . $self->ctime_2_archive_time( int( $self->{ctime} ) - int( $self->{ls_obj}->param('digest_schedule') ) )
          if $t;

        $self->{ls_obj}->save(
			{
            	-settings  => {
	                digest_last_archive_id_sent => $self->ctime_2_archive_time(int( $self->{ctime} ) - int( $self->{ls_obj}->param('digest_schedule') ))
          	   }
			}
        );
		
        undef( $self->{ls_obj} );
        $self->{ls_obj} = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    }

    $self->{a_obj} = DADA::MailingList::Archives->new( { -list => $self->{list} } );

}

sub should_send_digest {
    my $self = shift;
	
	if($self->mock_run() == 1){
		my $keys = $self->{a_obj}->get_archive_entries('normal');
		if ( scalar( @{$keys} ) == 0 ) {
			return 0; 
		}
		else { 
			return 1;
		}
	}
	else {
	    if ( scalar @{ $self->archive_ids_for_digest } ) {
	        return 1;
	    }
	    else {
	        return 0;
	    }
	}
}

sub archive_ids_for_digest {

    my $self = shift;
    my $keys = $self->{a_obj}->get_archive_entries('normal');
    my $ids  = [];
    my $digest_last_archive_id_sent = $self->{ls_obj}->param('digest_last_archive_id_sent') || undef;
 
    if ( scalar( @{$keys} ) == 0 ) {
		return [];
    }
	elsif($self->mock_run() == 1){ 
		my $c = 4;
		 
		for(@$keys){ 
			$c--;
			push(@$ids, $_);
			last if $c == 0; 
		}
	}	
    else { 
        if(
            ($self->archive_time_2_ctime($digest_last_archive_id_sent) + int($self->{ls_obj}->param('digest_schedule'))) > $self->{ctime}){ 
                # not the time to send out a digest!
                #....           
				return [];
	    }
		else {
	        for (@$keys) {            
	            if (   
	                # after our last one was sent out (redundant?)
	                $self->archive_time_2_ctime($_) > $self->archive_time_2_ctime($digest_last_archive_id_sent) 
                
	                &&
	                # Is within the digest_schedule
	                $self->archive_time_2_ctime($_) >  $self->{ctime}  - (int($self->{ls_obj}->param('digest_schedule')))
                
	                # BUT less than right now 
	                && $self->archive_time_2_ctime($_) < $self->{ctime} 
	            ) 
	            {
	                push( @$ids, $_ );
	            }
	        }
	    }
	}
	
    if ($t) {
        warn 'ids to make digest: ';
        for (@$ids) {
            warn "$_\n";
        }
    }	
    @$ids = reverse(@$ids); 
    return $ids;
	
	
}

sub send_digest {

    my $self = shift;
    my $r;

	if($self->mock_run() == 1){ 
		$r .= "MOCK RUN!\n";
	}
	
	if($self->mock_run() != 1){ 
	    my $digest_last_archive_id_sent = $self->{ls_obj}->param('digest_last_archive_id_sent') || undef;
	     if(defined($digest_last_archive_id_sent)){ 
	         $r .= "\t* " . 'Last Archived Message ID Sent: ' . $digest_last_archive_id_sent
	         . ' (' . scalar(localtime($self->archive_time_2_ctime($self->{ls_obj}->param('digest_last_archive_id_sent')))) .')' . "\n";
	     }
	     else { 
	         $r .= "\t * No archived messages sent as a digest.\n"; 
	     }

	     if(defined($digest_last_archive_id_sent)){ 
	         my $time_since_last_digest_sent = $self->{ctime} - $self->archive_time_2_ctime($digest_last_archive_id_sent);
	         $r .= "\t* Digests sent every: " .      formatted_runtime($self->{ls_obj}->param('digest_schedule')) . "\n"; 
	         $r .= "\t* Last digest message sent: " . formatted_runtime($time_since_last_digest_sent) . " ago.\n"; 
	     }
	}
     
	
    if ( $self->should_send_digest ) {

		$r .=  "\tSending Digest.\n";
        $self->send_out_digest();
		my $keys = $self->archive_ids_for_digest();

#		use Data::Dumper; 
#		$r .= Dumper($keys);

		if($self->mock_run() != 1){
			# $r .= "\nsaving:" . $keys->[-1] . "\n";
	        $self->{ls_obj}->save(
				{
					-settings  => {
	              	  digest_last_archive_id_sent => $keys->[-1], 
	            	}
				}
	        );
		}
    }
    else {
        $r .= "\t* No new messages to create a digest message\n";
    }
    return $r;
}

sub archive_time_2_ctime {

    my $self  = shift;
    my $p_num = shift;

    warn '$p_num: ' . $p_num
      if $t;

    my $year   = int( substr( $p_num, 0,  4 ) ) || 0;
    my $month  = int( substr( $p_num, 4,  2 ) ) || 0;
    my $day    = int( substr( $p_num, 6,  2 ) ) || 0;
    my $hour   = int( substr( $p_num, 8,  2 ) ) || 0;
    my $minute = int( substr( $p_num, 10, 2 ) ) || 0;
    my $sec    = int( substr( $p_num, 12, 2 ) ) || 0;
    $year  -= 1900;
    $month -= 1;

    my $c_time = timelocal( $sec, $minute, $hour, $day, $month, $year );

    return $c_time;

}

sub ctime_2_archive_time {
    my $self  = shift;
    my $ctime = shift;
    return message_id($ctime);
}

sub send_out_digest {

    my $self = shift;
	
    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $self->{list} );
	
	
    my $vars = $self->digest_ht_vars;
    require DADA::Template::Widgets;

	require DADA::App::EmailThemes; 
	my $dap = DADA::App::EmailThemes->new({-list => $self->{list}}); 
    my $ep = $dap->fetch('digest_message');

    my $subject_tmpl = $ep->{vars}->{subject};
    my $pt_tmpl      = $ep->{plaintext};
    my $html_tmpl    = $ep->{html};

    my $subject_scr = DADA::Template::Widgets::screen(
        {
            -data                     => \$subject_tmpl,
            -expr                     => 1,
            -vars                     => $vars,
            -list_settings_vars_param => { -list => $self->{list} },
        }
    );
    my $pt_scrn = DADA::Template::Widgets::screen(
        {
            -data                     => \$pt_tmpl,
            -expr                     => 1,
            -vars                     => $vars,
            -list_settings_vars_param => { -list => $self->{list} },
        }
    );
	
	
    my $html_scrn = DADA::Template::Widgets::screen(
        {
            -data                     => \$html_tmpl,
            -expr                     => 1,
            -vars                     => $vars,
            -list_settings_vars_param => { -list => $self->{list} },
        }
    );

	require CGI; 
    my $qq = CGI->new();
       $qq->charset($DADA::Config::HTML_CHARSET);

       $qq->delete_all();
        
        $qq->param('Subject', $subject_scr); 
        $qq->param('html_message_body', $html_scrn); 
        $qq->param('text_message_body', $pt_scrn); 
		$qq->param('f', 'send_email');
        $qq->param('draft_role', 'draft'); 
    
        require DADA::App::MassSend; 
        my $dam = DADA::App::MassSend->new({-list => $self->{list}}); 
        my $draft_id = $dam->save_as_draft(
            {
                -cgi_obj => $qq,
                -list    => $self->{list},
                -json    => 0,
            }
        );

        my $process = 'test'; 
        if($self->test() == 1){ 
            $process = 'test'; 
        }
        else { 
            $process = 1; 
        }
		
        my $c_r = $dam->construct_and_send(
            {
                -draft_id => $draft_id,
                -screen   => 'send_email',
                -role     => 'draft',
                -process  => $process,
			    -mass_mailing_params => {
					-delivery_preferences => 'digest',
            	}
			}
        );
		if($c_r->{status} == 0) { 
			warn 'problem creating digest message:' . $c_r->{errors};
		}
		$dam->delete_draft($draft_id); 
		
		return $draft_id; 
		
}




sub digest_ht_vars {

    my $self = shift;

    require DADA::Template::Widgets;

    my $ids = $self->archive_ids_for_digest;

    my $digest_messages = [];

    foreach my $id (@$ids) {
        my $pt = $self->{a_obj}->massaged_msg_for_display(
            {
                -key            => $id,
                -body_only      => 1,
                -entity_protect => 1,
                -plain_text     => 1,
            }
        );
        my $html = $self->{a_obj}->massaged_msg_for_display(
            {
                -key            => $id,
                -body_only      => 1,
                -entity_protect => 1,
                -plain_text     => 0,
            }
        );
        my $sender_address = $self->{a_obj}->sender_address(
            {
                -id => $id,
            }
        );

        my ( $subscriber_vars, $subscriber_loop_vars ) = DADA::Template::Widgets::subscriber_vars(
            {
                -subscriber_vars_param => {
                    -list              => $self->{list},
                    -email             => $sender_address,
                    -type              => 'list',
                    -use_fallback_vars => 1,
                }
            }
        );

        my %date_params = DADA::Template::Widgets::date_params( $self->archive_time_2_ctime($id) );
        my $message_blurb = $self->{a_obj}->message_blurb( -key => $id );

        push(
            @$digest_messages,
            {
                archive_id        => $id,
                message_blurb     => $message_blurb,
                plaintext_message => $pt,
                html_message      => $html,
                subject           => $self->{a_obj}->get_header( -key => $id, -header => 'Subject' ),
                subscriber        => $subscriber_loop_vars,
                %$subscriber_vars,
                %date_params,
            }
        );
    }

    return {
        num_messages    => scalar(@$ids),
        digest_messages => $digest_messages,
      }

}


sub DESTROY {}
1;
