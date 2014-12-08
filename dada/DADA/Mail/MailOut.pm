package DADA::Mail::MailOut;

use lib qw(../../ ../../DADA ../../perllib);

use CGI::Carp qw(croak carp);

use Fcntl qw(

  :DEFAULT
  :flock
  LOCK_SH

  O_RDONLY
  O_CREAT
  O_WRONLY
  O_TRUNC

);

my $dbi_obj;

use DADA::Config qw(!:DEFAULT);
my $t = $DADA::Config::DEBUG_TRACE->{DADA_Mail_MailOut};

use DADA::App::Guts;
use DADA::Logging::Usage;

my $log = new DADA::Logging::Usage;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(current_mailouts mailout_exists monitor_mailout);

use vars qw(@EXPORT $AUTOLOAD);

use strict;

my $file_names = {

    batchlock               => 'batchlock.txt',
    tmp_subscriber_list     => 'tmp_subscriber_list.txt',
    problem_subscriber_list => 'problem_subscriber_list.txt',
    num_sending_to          => 'num_sending_to.txt',
    counter                 => 'counter.txt',
    first_access            => 'first_access.txt',
    last_access             => 'last_access.txt',
    raw_message             => 'raw_message.txt',
    pause                   => 'paused.txt',
    pid                     => 'pid.txt',
    'log'                   => 'log.txt',

};

my %allowed = (

    message               => undef,
    _internal_message_id  => undef,
    mailout_type          => undef,
    list                  => undef,
    dir                   => undef,
    subscriber_list       => undef,
    sent_amount           => 0,
    total_sending_out_num => undef,

    #auto_pickup_status   => 0,

    use_semaphore_locking => 0,
    _cache                => {},

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

    if ( !$args->{-list} ) {

        carp "You need to supply a list ->new({-list => your_list}) in the constructor.";
        return undef;

    }

    if ( $self->_init($args) ) {
        warn 'MailOut object created successfully.'
          if $t;

        return $self;
    }
    else {
        warn 'MailOut object was NOT created successfully.'
          if $t;

        return undef;
    }
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

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

    if ( !$self->_sanity_test($args) ) {

        carp "sanity test failed - something's wrong with the parameters you passed.";
        return undef;

    }
    else {

        my $ls = undef;
        if ( exists( $args->{-ls_obj} ) ) {
            $ls = $args->{-ls_obj};
        }
        else {
            # Or... I could just *pass* $li somehow...
            require DADA::App::DBIHandle;
            $self->{dbi_handle} = DADA::App::DBIHandle->new;
            require DADA::MailingList::Settings;
            $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );

        }

        my $li = $ls->get();

        $self->list( $args->{-list} );
        $self->{ls} = $ls;

        $self->_dir_setup();

        return 1;
    }

}

sub _dir_setup {
    my $self = shift;

    # Directory?
    if ( -d $DADA::Config::TMP ) {

        # Write to it?
        if ( !-r $DADA::Config::TMP || !-w $DADA::Config::TMP || !-x $DADA::Config::TMP ) {
            carp "Can't write into, '" . $DADA::Config::TMP . "', will try to change directory permissions...";
            chmod( $DADA::Config::DIR_CHMOD, $DADA::Config::TMP );
        }
        else {
            # good.
        }
    }
}

sub _sanity_test {

    my $self = shift;
    my ($args) = @_;

    return undef if !$args;

    return $self->_list_name_check( $args->{-list} );

}

sub batch_params {

    my $self = shift;
    my ($args) = @_;

    # We can override things, for previewing:
    my $sending_method = $self->{ls}->param('sending_method');
    if ( exists( $args->{-sending_method} ) ) {
        $sending_method = $args->{-sending_method};
    }

    my $amazon_ses_auto_batch_settings = $self->{ls}->param('amazon_ses_auto_batch_settings');
    if ( exists( $args->{-amazon_ses_auto_batch_settings} ) ) {
        $amazon_ses_auto_batch_settings = $args->{-amazon_ses_auto_batch_settings};
    }

    my $enable_bulk_batching = $self->{ls}->param('enable_bulk_batching');
    if ( exists( $args->{-enable_bulk_batching} ) ) {
        $enable_bulk_batching = $args->{-enable_bulk_batching};
    }

    # Amazon SES:
    if (
        (
            $sending_method eq 'amazon_ses' || ( $self->{ls}->param('sending_method') eq 'smtp'
                && $self->{ls}->param('smtp_server') =~ m/amazonaws\.com/ )
        )
        && $amazon_ses_auto_batch_settings == 1
      )
    {

        if ( exists( $self->{_cache}->{batch_params} ) ) {
            if ( exists( $self->{_cache}->{batch_params}->{cached_at} ) ) {
                if ( ( int( $self->{_cache}->{batch_params}->{cached_at} ) + 600 ) < time ) {
                    carp 'batch settings (cached): Enabled: '
                      . $self->{_cache}->{batch_params}->{enable_bulk_batching}
                      . ' Batch Size: '
                      . $self->{_cache}->{batch_params}->{batch_size}
                      . ' Batch Wait: '
                      . $self->{_cache}->{batch_params}->{batch_wait}
                      if $t;

                    return (
                        $self->{_cache}->{batch_params}->{enable_bulk_batching},
                        $self->{_cache}->{batch_params}->{batch_size},
                        $self->{_cache}->{batch_params}->{batch_wait}
                    );
                }
            }
            else {
                carp 'Love to use the batch settings cache, but it\'s too old by: '
                  . int( $self->{_cache}->{batch_params}->{cached_at} ) + 600 - time
                  if $t;
            }
        }
    }

    #/ We can override things, for previewing:

    # Amazon SES:
    my $using_amazon_ses = 0;
    my $using_mandrill   = 0;

    if (
        $sending_method eq 'amazon_ses' && $amazon_ses_auto_batch_settings == 1
        || (   $self->{ls}->param('sending_method') eq 'smtp'
            && $self->{ls}->param('smtp_server') =~ m/amazonaws\.com/
            && $amazon_ses_auto_batch_settings == 1 )
      )
    {
        $using_amazon_ses = 1;
    }
    elsif ($self->{ls}->param('sending_method') eq 'smtp'
        && $self->{ls}->param('smtp_server') =~ m/smtp\.mandrillapp\.com/
        && $amazon_ses_auto_batch_settings == 1 )
    {
        $using_mandrill = 1;
    }

    require POSIX;
    my $batch_size = 0;
    my $batch_wait = 0;

    if (   $using_amazon_ses == 1
        || $using_mandrill == 1 )
    {

        my $status              = undef;
        my $SentLast24Hours     = undef;
        my $Max24HourSend       = undef;
        my $MaxSendRate         = undef;
        my $quota_Max24HourSend = undef;

        if ( $using_amazon_ses == 1 ) {
            require DADA::App::AmazonSES;
            my $ses = DADA::App::AmazonSES->new;

            # Save stats, between executions:
            ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
            if ( $ses->_should_get_saved_ses_stats == 1 ) {
                ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $ses->_get_saved_ses_stats;
            }
            else {
                ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $ses->get_stats;

                #                  0          10_000             5
                $ses->_save_ses_stats( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
            }
            $quota_Max24HourSend = ( $Max24HourSend * $ses->allowed_sending_quota_percentage ) / 100;

        }
        elsif ( $using_mandrill == 1 ) {
            require DADA::App::Mandrill;
            my $man = DADA::App::Mandrill->new;

            # Save stats, between executions:
            ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
            if ( $man->_should_get_saved_man_stats == 1 ) {
                ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $man->_get_saved_man_stats;
            }
            else {
                ( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = $man->get_stats;
            #                  0          10_000             5
                #use Data::Dumper; 
                #warn Dumper([( $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate )]); 
            
                 $man->_save_man_stats($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate);
            }    
            $quota_Max24HourSend = ($Max24HourSend * $man->allowed_sending_quota_percentage) / 100;

        }
        else {
            die "what?";
        }

        #		if($t) {
        #			 warn '$status ' . $status;
        #			 warn '$SentLast24Hours' . $SentLast24Hours;
        #			 warn '$Max24HourSend' . $Max24HourSend;
        #			 warn '$MaxSendRate' . $MaxSendRate
        #	 	}

        #		warn '$quota_Max24HourSend bef' , $quota_Max24HourSend;

        $quota_Max24HourSend = POSIX::floor($quota_Max24HourSend);

        #		warn '$quota_Max24HourSend' . $quota_Max24HourSend
        #			if $t;

        if (   $SentLast24Hours >= $Max24HourSend
            || $SentLast24Hours >= $quota_Max24HourSend )
        {
            # Yikes! We're over our limit!
            carp 'batch settings (OVER OUR LIMIT!): Enabled: '
              . $enable_bulk_batching
              . ' Batch Size: '
              . 0
              . ' Batch Wait: '
              . 300
              if $t;

            return ( $enable_bulk_batching, 0, 300, );
        }
        else {
            if ( $amazon_ses_auto_batch_settings == 1 ) {

                # dada automatically manages batch settings

                if ( $quota_Max24HourSend < 86_400 ) {
                    $batch_size = 1;
                    $batch_size = $batch_size * $MaxSendRate;    # 5

                    $batch_wait = 86_400 / $quota_Max24HourSend;          # 8.64
                    $batch_wait = $batch_wait * $MaxSendRate;             # 8.64 * 5 = 43.2
                    $batch_wait = $batch_wait + ( $batch_wait * .10 );    # 38.8
                }
                else {
                    $batch_size = $MaxSendRate;                           # 5
                    $batch_wait = $quota_Max24HourSend / 86_400;          # 100_000 / 86_400 = 1.1574...
                    $batch_wait = $batch_wait + ( $batch_wait * .10 );    # 38.8
                }

                # This slows the batch settings down, if there's > 1 mailout going on
                # at one time.
                if ( $DADA::Config::MAILOUT_AT_ONCE_LIMIT > 1 ) {
                    my (
                        $monitor_mailout_report, $total_mailouts,  $active_mailouts,
                        $paused_mailouts,        $queued_mailouts, $inactive_mailouts
                      )
                      = monitor_mailout(
                        {
                            -verbose => 0,
                            -action  => 0,
                        }
                      );

                    # If the batch size is larger than how many messages we have,
                    # better to divide that up, rather than the span between messages
                    # Round DOWN just to be on the safe side of things.
                    if ( $batch_size > $active_mailouts ) {

                        #					warn '$batch_size > $active_mailouts'
                        #						if $t;

                        if ( $active_mailouts > 1 ) {
                            if ( $active_mailouts < $DADA::Config::MAILOUT_AT_ONCE_LIMIT ) {
                                $batch_size = POSIX::floor( ( $batch_size / $active_mailouts ) );
                            }
                            else {
                                $batch_wait = POSIX::floor( ( $batch_size / $DADA::Config::MAILOUT_AT_ONCE_LIMIT ) );
                            }
                        }
                    }
                    else {
                        # else, make the wait longer
                        if ( $active_mailouts > 1 ) {
                            if ( $active_mailouts < $DADA::Config::MAILOUT_AT_ONCE_LIMIT ) {
                                $batch_wait = ( $batch_wait * $active_mailouts );
                            }
                            else {
                                $batch_wait = ( $batch_wait * $DADA::Config::MAILOUT_AT_ONCE_LIMIT );
                            }
                        }
                    }
                }
            }
            else {
                # we manage our own batch settings
                $batch_size = $self->{ls}->param('mass_send_amount');
                $batch_wait = $self->{ls}->param('bulk_sleep_amount');

                if ( $batch_size > $MaxSendRate ) {
                    $batch_size = $MaxSendRate;
                }

                if ( $batch_wait < 1 ) {
                    warn 'why is $bulk_sleep_amount < 1?!';
                    $batch_wait = 1;
                }
            }

            $batch_size = POSIX::floor($batch_size);
            $batch_wait = POSIX::ceil($batch_wait);

            $self->{_cache}->{batch_params} = {
                enable_bulk_batching => $enable_bulk_batching,
                batch_size           => $batch_size,
                batch_wait           => $batch_wait,
                cached_at            => time,
            };

            carp 'batch settings (Fresh, SES): Enabled: '
              . $enable_bulk_batching
              . ' Batch Size: '
              . $batch_size
              . ' Batch Wait: '
              . $batch_wait
              if $t;

            return ( $enable_bulk_batching, $batch_size, $batch_wait, );
        }

    }
    else {

        my $mass_send_amount  = $self->{ls}->param('mass_send_amount');
        my $bulk_sleep_amount = $self->{ls}->param('bulk_sleep_amount');

        if ( $bulk_sleep_amount < 1 ) {
            warn 'why is $bulk_sleep_amount < 1?!';
            $bulk_sleep_amount = 1;
        }

        carp 'batch settings (bulk_sleep_amount set weird): Enabled: '
          . $enable_bulk_batching
          . ' Batch Size: '
          . $mass_send_amount
          . ' Batch Wait: '
          . $bulk_sleep_amount
          if $t;

        return ( $enable_bulk_batching, $mass_send_amount, $bulk_sleep_amount, );
    }
}

sub reset_batch_params_cache {
    my $self = shift;
    $self->{_cache}->{batch_params} = undef;
    delete( $self->{_cache}->{batch_params} );
    return 1;
}

sub create {

    my $self = shift;

    my ($args) = @_;

    # = ( -fields => {}, -mh_obj => {}, -list_type => 'list', @_ );

    croak "You did not supply a list type! (list, black_list, invite_list, etc)"
      if !exists( $args->{-list_type} );

    croak "The Actual Message Fields have not been passed. "
      if !keys %{ $args->{-fields} };

    croak "The Message ID has not been passed. "
      if !exists( $args->{-fields}->{'Message-ID'} );

    croak "The DADA::Mail::Send object has not been passed "
      if !exists( $args->{-mh_obj} );

    croak "The DADA::Mail::Send object has been passed, but it's not isa DADA::Mail::Send! "
      unless $args->{-mh_obj}->isa('DADA::Mail::Send');

    # default:
    my $list_type = $args->{-list_type};

    $self->_internal_message_id( $args->{-fields}->{'Message-ID'} );

    warn '_internal_message_id set to '
      . $self->_internal_message_id
      . ' from original value: '
      . $args->{-fields}->{'Message-ID'}
      if $t;

    $self->mailout_type($list_type);
    warn 'mailout_type set to ' . $self->mailout_type . ' from original value: ' . $list_type
      if $t;

    $self->message( $args->{-fields} );

    # dir should now be set to the TMP_ directory
    $self->_create_initial_directory();

    # The Temporary Subscriber List
    $self->create_subscriber_list(
        {
            -mh_obj              => $args->{-mh_obj},
            -partial_sending     => $args->{-partial_sending},
            -exclude_from        => $args->{-exclude_from},
            -mass_mailing_params => $args->{-mass_mailing_params},
        }
    );

    #The Total Amount of Recipients Amount
    $self->create_total_sending_out_num();

    # Log File
    $self->create_log_file();

    #The Amount Sent Counter
    $self->create_counter();

    # Create "First Accessed", File
    $self->create_first_accessed_file();

    # The, "Last Accessed", File
    $self->create_last_accessed_file();

    # A Copy of the Message Being Sent Out
    $self->create_raw_message();

    # Problem List!
    $self->problem_subscriber_list_file();

    # Everything made? OK, let's change the dir name, save that name, and move on,
    my $orig_name = $self->dir;
    my $live_name = $orig_name;
    $live_name =~ s/TMP_sendout/sendout/;
    $live_name = make_safer($live_name);

    warn "moving directory from: '$orig_name', to: '$live_name'..."
      if $t;

    require File::Copy;
    File::Copy::move( $orig_name, $live_name )
      or warn "could not move file from, '$orig_name', to, '$live_name': $!";

    $self->dir($live_name);

    # I have to reset this to, as it's set in, create_subscriber_list();
    # For whatever reason.

    $self->subscriber_list( $self->dir . '/' . $file_names->{tmp_subscriber_list} );

    #well, I guess I'll return 1 for success...
    return 1;

}

sub associate {

    my $self = shift;
    my $id   = shift;
    my $type = shift;

    croak "Object already associated with: "
      . $self->_internal_message_id
      . "This can only be set once and is read-only via (_internal_message_id) after that."
      if $self->_internal_message_id;

    $id =~ s/\@/_at_/g;
    $id =~ s/\>|\<//g;

    # This kinda sucks:
    $self->_internal_message_id($id);

    if ( $self->mailout_type ) {
        croak "Why is mailout_type already set?!";
    }
    if ( !$type ) {
        croak "You didn't supply a list mailing type (list, black_list invitelist, etc)";
    }

    # BUGFIX:
    # 2219972  	 3.0.0 - Mailout.pm - associate method broken
    # https://sourceforge.net/tracker2/?func=detail&aid=2219972&group_id=13002&atid=113002

    $self->mailout_type($type);

    $self->dir( $self->mailout_directory_name );

    $self->total_sending_out_num( _poll( $self->dir . '/' . $file_names->{num_sending_to} ) );

    $self->subscriber_list( $self->dir . '/' . $file_names->{tmp_subscriber_list} );

    #/BUGFIX

    return 1;

}

sub batch_lock {

    my $self = shift;

    $self->create_batch_lock();

    warn 'created batch lock '
      if $t;

    return 1;

}

sub unlock_batch_lock {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{batchlock};
    $file = make_safer($file);

    if ( !-e $file ) {

        warn "Batch lock at '$file' doesn't exist to unlock?!"
          if $t;
    }
    else {

        my $worked = unlink($file);

        if ( $worked == 1 ) {
            warn 'Unlocking Batch Lock successfully. '
              if $t;

            return 1;

        }
        else {

            warn "Batch lock at, '$file' could not be unlinked (deleted). Reasons:" . $!
              if $t;

            if ( -e $file ) {
                carp "File exists check turns up a positive - the batch lock file is *really really* there.";
            }
            else {
                carp "Strange, unlinking didn't work, but the batch lock doesn't seem to be around anymore.";
            }

            return 0;

        }
    }
}

sub is_batch_locked {

    my $self = shift;

    if ( -e $self->dir . '/' . $file_names->{batchlock} ) {

        warn 'Returning that the batch is locked.'
          if $t;

        return 1;

    }
    else {

        warn 'Returning that the batch is NOT locked.'
          if

          return 0;
    }
}

sub _create_initial_directory {

    my $self = shift;

    my $tmp_dir_name = make_safer( $self->mailout_directory_name( { -tmp => 1 } ) );
    if ( -d $tmp_dir_name ) {
        croak "Mass Mailing directory, '" . $tmp_dir_name . "' already exists?!";
    }

    if ( !-d $tmp_dir_name ) {
        croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! Could not create, '" . $tmp_dir_name . "'- $!"
          unless mkdir( $tmp_dir_name, $DADA::Config::DIR_CHMOD );
        chmod( $DADA::Config::DIR_CHMOD, $tmp_dir_name )
          if -d $tmp_dir_name;
    }

    if ( !-d $tmp_dir_name ) {
        croak "Mass Mailing Directory never created at: '" . $tmp_dir_name . "'";
    }

    $self->dir($tmp_dir_name);

    warn 'Directory created at: ' . $tmp_dir_name . ' saved in $self->dir as: ' . $self->dir
      if $t;

    return 1;

}

sub mailout_directory_name {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-tmp} ) ) {
        $args->{-tmp} = 0;
    }
    my $tmp = $self->_internal_message_id;

    my $letter_id = $tmp;
    $letter_id =~ s/\@/_at_/g;
    $letter_id =~ s/\>|\<//g;

    $letter_id = DADA::App::Guts::strip($letter_id);

    my $prepend = '';
    if ( $args->{-tmp} == 1 ) {
        $prepend = 'TMP_';
    }

    return make_safer( $DADA::Config::TMP . '/'
          . $prepend
          . 'sendout-'
          . $self->{list} . '-'
          . $self->mailout_type . '-'
          . $letter_id );
}

sub create_subscriber_list {

    my $self = shift;

    my ($args) = @_;
    
    use Data::Dumper; 
    carp 'mass_mailing_params 2:' . Dumper($args); 
    
    unless ( $args->{-mh_obj}->isa('DADA::Mail::Send') ) {
        croak "The DADA::Mail::Send object has been passed, but it's not isa DADA::Mail::Send! ";
    }

    # That's gonna be harder....
    require DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $self->list } );

    my $file = $self->dir . '/' . $file_names->{tmp_subscriber_list};
    my $lock = $self->lock_file($file);

    my %cmf_args = (
        -ID                  => $self->_internal_message_id,
        -Type                => $self->mailout_type,
        -Save_At             => $self->dir . '/' . $file_names->{tmp_subscriber_list},
        -Bulk_Test           => $args->{-mh_obj}->{mass_test},
        -Test_Recipient      => $args->{-mh_obj}->mass_test_recipient,
        -Ban                 => $args->{-mh_obj}->{do_not_send_to},
        -Create_Tokens => ( $args->{-mh_obj}->list_type eq 'invitelist' || $args->{-mh_obj}->list_type eq 'list' )
        ? 1
        : 0,

        # -Sending_Lists   => $args->{-mh_obj}->also_send_to,
        # I'm pretty scoobied why these are passed as params, and the above are just
        # culled from the $mh object. Like, what?

        -partial_sending     => $args->{-partial_sending},
        -mass_mailing_params => $args->{-mass_mailing_params},
        
    );
    if ( $DADA::Config::MULTIPLE_LIST_SENDING == 1 ) {
        if ( $DADA::Config::MULTIPLE_LIST_SENDING_TYPE eq 'merged' ) {
            $cmf_args{-include_from} = $args->{-mh_obj}->also_send_to;
        }
        else {
            $cmf_args{-exclude_from} = $args->{-exclude_from};    # Individual
        }
    }

    my ( $path_to_list, $total_sending_out_num ) = $lh->create_mass_sending_file(%cmf_args);
    $self->unlock_file($lock);
    if ( !-e $self->dir . '/' . $file_names->{tmp_subscriber_list} ) {
        croak "Temporary Sending List was never created at: '"
          . $self->dir . '/'
          . $file_names->{tmp_subscriber_list} . "'";
    }

    $self->subscriber_list( $self->dir . '/' . $file_names->{tmp_subscriber_list} );
    $self->total_sending_out_num($total_sending_out_num);

    chmod( $DADA::Config::FILE_CHMOD, $self->subscriber_list );

    warn 'create_subscriber_list successful, subscriber_list set to: '
      . $self->dir . '/'
      . $file_names->{tmp_subscriber_list}
      . 'total sending out set to: '
      . $total_sending_out_num
      if $t;

    undef $lh;

    return 1;

}

sub create_total_sending_out_num {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{num_sending_to};
    $file = make_safer($file);

    my $lock = $self->lock_file($file);

    sysopen( COUNTER, $file, O_WRONLY | O_TRUNC | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "Couldn't create the counter of how many subscribers I need to send to at: '$file' because: $!";
    print COUNTER $self->total_sending_out_num
      or croak "Couldn't write to: '" . $file . "' because: " . $!;
    close(COUNTER)
      or croak "'" . $file . "' didn't close poperly because: " . $!;

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'num_sending_to file created at ' . $file . ' and given value of: ' . $self->total_sending_out_num
      if $t;

    return 1;

}

sub create_log_file {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{'log'};
    $file = make_safer($file);

    open( LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or croak "Couldn't create the log file at: '" . $file . " 'because: " . $!;

    close(LOG)
      or croak " didn't close '$file' poperly because: " . $!;
    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'log file created at ' . $file
      if $t;

    return 1;

}

sub problem_subscriber_list_file {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{'problem_subscriber_list'};
    $file = make_safer($file);

    open( LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or croak "Couldn't create the problem_subscriber_list file at: '" . $file . " 'because: " . $!;

    close(LOG)
      or croak " didn't close '$file' poperly because: " . $!;
    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'problem_subscriber_list file created at ' . $file
      if $t;

    return 1;

}

sub create_counter {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{counter};
    $file = make_safer($file);

    my $lock = $self->lock_file($file);

    sysopen( COUNTER, $file, O_WRONLY | O_TRUNC | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "couldn't open counter at: '$file' because: $!";
    print COUNTER '0';
    close(COUNTER)
      or croak "couldn't close counter at: '$file' because: $!";

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'counter created at ' . $file
      if $t;

    return 1;

}

sub create_first_accessed_file {

    my $self = shift;
    my $file = $self->dir . '/' . $file_names->{first_access};
    $file = make_safer($file);

    my $lock = $self->lock_file($file);

    sysopen( ACCESS, $file, O_WRONLY | O_TRUNC | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "Couldn't open '$file' because: " . $!;
    print ACCESS time;
    close(ACCESS)
      or croak "Couldn't close '$file' because: " . $!;

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'create_first_accessed_file created at ' . $file
      if $t;

}

sub create_last_accessed_file {

    my $self = shift;
    my $file = $self->dir . '/' . $file_names->{last_access};
    $file = make_safer($file);

    my $lock = $self->lock_file($file);

    sysopen( ACCESS, $file, O_WRONLY | O_TRUNC | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "Couldn't open '$file' because: " . $!;
    print ACCESS time;
    close(ACCESS)
      or croak "Couldn't close '$file' because: " . $!;

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'create_last_accessed_file created at ' . $file
      if $t;
    return 1;
}

sub create_batch_lock {

    my $self = shift;
    my $file = $self->dir . '/' . $file_names->{batchlock};
    $file = make_safer($file);

    my $lock = $self->lock_file($file);

    sysopen( BATCHLOCK, $file, O_WRONLY | O_TRUNC | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "Couldn't open, '$file' because: " . $!;
    print BATCHLOCK time;
    close(BATCHLOCK)
      or croak "Couldn't close, '$file' because: " . $!;

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );
    warn 'create_batch_lock created at ' . $file
      if $t;
    return 1;

}

sub countsubscriber {

    # DEV:
    # It would be nice to be able to check to make sure the number we just added is the number, +1,
    # Somehow. Somewhere.

    my $self = shift;
    my $num  = _poll( $self->dir . '/' . $file_names->{counter} );
    my $file = make_safer( $self->dir . '/' . $file_names->{counter} );
    my $lock = $self->lock_file($file);

    sysopen( FH, $file, O_RDWR | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "can't open '$file' because: $!";

    if ( $^O =~ /solaris/g ) {
        flock( FH, LOCK_SH )
          or croak "can't flock '$file' because: $!";
    }
    else {
        flock( FH, LOCK_EX )
          or croak "can't flock '$file' because: $!";
    }

    seek( FH, 0, 0 ) or croak "can't rewind counter: $!";
    truncate( FH, 0 ) or croak "can't truncate counter: $!";

    my $new_count = int($num) + 1;

    print FH $new_count, "\n" or croak "can't write counter: $!";
    close FH or croak "can't close counter: $!";

    $self->unlock_file($lock);
    $self->update_last_access();

    return $new_count;

}

sub update_last_access {

    warn "update_last_access"
      if $t;

    my $self = shift;

    my $file = make_safer( $self->dir . '/' . $file_names->{last_access} );

    my $lock = $self->lock_file($file);

    sysopen( FH, $file, O_RDWR | O_CREAT, $DADA::Config::FILE_CHMOD ) or croak "can't open '$file' because: $!";

    flock( FH, LOCK_EX )
      or croak "can't flock '$file'  because: $!";

    seek( FH, 0, 0 ) or croak "can't rewind counter: $!";
    truncate( FH, 0 ) or croak "can't truncate counter: $!";
    ( print FH time, "\n" ) or croak "can't write counter: $!";
    close FH or croak "can't close counter: $!";

    $self->unlock_file($lock);

}

sub pause {

    my $self = shift;
    my $set  = shift;

    if ( $self->paused ) {
        carp "Mass Mailing is already paused.";

        return undef;
    }
    else {
        my $file = $self->dir . '/' . $file_names->{pause};

        my $lock = $self->lock_file($file);

        sysopen( FH, $file, O_RDWR | O_CREAT, $DADA::Config::FILE_CHMOD ) or croak "can't open '$file' because: $!";

        if ( $^O =~ /solaris/g ) {
            flock( FH, LOCK_SH )
              or croak "can't flock '$file' because: $!";
        }
        else {
            flock( FH, LOCK_EX )
              or croak "can't flock '$file' because: $!";
        }

        seek( FH, 0, 0 ) or croak "can't rewind pause: $!";
        truncate( FH, 0 ) or croak "can't truncate pause: $!";
        ( print FH time, "\n" ) or croak "can't write pause: $!";
        close FH;

        $self->unlock_file($lock);

        chmod( $DADA::Config::FILE_CHMOD, $file );

        $self->log('Mailing Paused.');

        warn 'successfully paused mailout.'
          if $t;

        return 1;

    }
}

sub set_controlling_pid {

    my $self = shift;
    my $pid = shift || die "You MUST pass the current pid!";

    my $file = make_safer( $self->dir . '/' . $file_names->{pid} );

    my $old_pid = undef;

    if ( -e $self->dir . '/' . $file_names->{pid} ) {
        $old_pid = _poll($file);
    }
    else {
        #	carp "No pid file, yet";
    }

    my $lock = $self->lock_file($file);

    warn "Switching controlling pid from: $old_pid to: $pid"
      if $t;

    open my $pid_fh, '>', $file
      or croak "can't open '$file' because: $!";

    if ( $^O !~ /solaris/g ) {    # as far as I can, shared locks are probably pretty useless, anyways...
        flock( $pid_fh, LOCK_SH )
          or croak "can't flock '$file' because: $!";
    }

    print $pid_fh $pid;
    close $pid_fh
      or croak "can't close file '$file' because $!";

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );

    return $pid;

}

sub resume {

    my $self = shift;

    warn 'Attempting to resume mailing...'
      if $t;

    if ( -e $self->dir . '/' . $file_names->{pause} ) {

        warn $self->dir . '/' . $file_names->{pause} . "exists."
          if $t;

        my $r = unlink( $self->dir . '/' . $file_names->{pause} );
        if ( $r != 1 ) {
            carp("Problem resuming mailing!");
            return undef;
        }
        else {

            # I wanna say I have to do this:
            #if($self->batch_lock){
            #     $self->unlock_batch_lock();
            #}
            # I also want to say I want to do... this!
            # $self->reload();

            # carp "no problems removing that file...";
            warn 'no problems reloading?'
              if $t;

            $self->log('Mailing Resumed.');

            return 1;
        }

    }
    else {

        carp "mailing WAS NOT paused...?";
        undef;

    }

}

sub paused {

    my $self = shift;

    if ( -e $self->dir . '/' . $file_names->{pause} ) {

        return _poll( $self->dir . '/' . $file_names->{pause} );
    }
    else {
        return 0;
    }
}

sub create_raw_message {

    my $self   = shift;
    my $fields = $self->message;

    my $file = $self->dir . '/' . $file_names->{raw_message};
    $file = make_safer($file);

    my $msg;

    my $lock = $self->lock_file($file);

    open( MESSAGE, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or croak "couldn't open: '$file' because: $!";

    for (@DADA::Config::EMAIL_HEADERS_ORDER) {
        next if $_ eq 'Body';
        next if $_ eq 'Message';    # Do I need this?!
        print MESSAGE $_ . ': ' . safely_encode( $fields->{$_} ) . "\n"
          if ( ( defined $fields->{$_} ) && ( $fields->{$_} ne "" ) );
    }

    print MESSAGE "\n" . $fields->{Body};

    close MESSAGE
      or die "Couldn't close: " . $file . "because: " . $!;

    $self->unlock_file($lock);

    chmod( $DADA::Config::FILE_CHMOD, $file );

    warn 'create_raw_message  at ' . $file
      if $t;

    return 1;

}

sub _integrity_check {

    my $self = shift;

    if ( !$self->mailout_type ) {

        carp "Integrity warning: no list_type set? How is that?";
        return undef;

    }

    for my $file_check ( keys %$file_names ) {

        next if $file_check eq 'batchlock';    # batchlock can come and go, I guess...
        next if $file_check eq 'pause';
        next if $file_check eq 'pid';
        if ( !-e $self->dir . '/' . $file_names->{$file_check} ) {

            carp "Integrity warning: "
              . $self->dir . '/'
              . $file_names->{$file_check}
              . " ($file_check) is not present!";
            return undef;
        }

    }

    # Special Case: If the counter is returning... well, NOT a number, we're in trouble...
    my $test_counter = _poll( $self->dir . '/' . $file_names->{counter} );
    if (
        !defined($test_counter)

        #		!defined($test_counter) ||
        #	$test_counter eq undef  ||
        #		$test_counter eq ''
      )
    {
        carp "Polling, '" . $self->dir . '/' . $file_names->{counter} . "' gave back an undefined value!.";
        return undef;
    }

    return 1;

}

sub status {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-mail_fields} ) ) {
        $args->{-mail_fields} = 1;
    }

    my $lock = $self->lock_file( $self->mailout_directory_name );

    warn 'Checking status '
      if $t;

    $self->dir( $self->mailout_directory_name );

    my $status = {};

    # DEV: For some reason, I want this explicitly set... so as not to cause any confusion...
    $status->{should_be_restarted} = 0;

    #	warn 'should_be_restarted set to, 0'
    #	    if $t;

    $status->{id} = $self->_internal_message_id;

    if ( !defined( $self->_integrity_check ) ) {
        $status->{integrity_check} = 0;

        # Note: DO NOT RESTART A MAILING THAT DOES NOT PASS THE INTEGRITY CHECK - OK COWBOY?!
        # return $status;
    }
    else {
        $status->{integrity_check} = 1;
    }

    $status->{total_sending_out_num} =
      _poll( $self->dir . '/' . $file_names->{num_sending_to} );

    $status->{total_sent_out} =
      _poll( $self->dir . '/' . $file_names->{counter} );

    $status->{last_access} =
      _poll( $self->dir . '/' . $file_names->{last_access} );
    $status->{last_access_formatted} =
      scalar( localtime( $status->{last_access} ) );

    $status->{last_sent} = ( stat( $self->dir . '/' . $file_names->{counter} ) )[9];
    $status->{last_sent_formatted} =
      scalar( localtime( $status->{last_sent} ) );

    $status->{first_access} =
      _poll( $self->dir . '/' . $file_names->{first_access} );
    $status->{first_access_formatted} =
      scalar( localtime( $status->{first_access} ) );

    $status->{mailing_time} =
      $status->{last_access} - $status->{first_access};
    $status->{mailing_time_formatted} =
      _formatted_runtime( $status->{mailing_time} );

    if ( $args->{-mail_fields} == 1 ) {
        $status->{email_fields} = $self->mail_fields_from_raw_message();
    }
    else {
        $status->{email_fields} = {};
    }

    $status->{type} = $self->mailout_type;

    $status->{is_batch_locked} = ( $self->is_batch_locked == 1 ) ? 1 : 0;

    $status->{paused} = $self->paused();

    if ( -e $self->dir . '/' . $file_names->{pid} ) {
        $status->{controlling_pid} =
          _poll( $self->dir . '/' . $file_names->{pid} );
    }
    else {
        $status->{controlling_pid} = '';
    }

    warn '>>>> MAILOUT_AT_ONCE_LIMIT set to: ' . $DADA::Config::MAILOUT_AT_ONCE_LIMIT
      if $t;

    if ( $DADA::Config::MAILOUT_AT_ONCE_LIMIT > 0 ) {

        $status->{queue} = 1;
        my ( $place, $total ) = $self->line_in_queue;

        warn '>>>> >>>> Line in queue: ' . $place . ' in a total of: ' . $total
          if $t;

        $status->{queue_place} = $place;
        $status->{queue_total} = $total;

        # $place starts at, "0" ,
        # $DADA::Config::MAILOUT_AT_ONCE_LIMIT starts at, "1".

#        carp '$place: ' . $place . ', $DADA::Config::MAILOUT_AT_ONCE_LIMIT - 1 ' . $DADA::Config::MAILOUT_AT_ONCE_LIMIT - 1;

        if ( $place > ( $DADA::Config::MAILOUT_AT_ONCE_LIMIT - 1 ) ) {

            warn '>>>> >>>> >>>> Place in queue higher than MAILOUT_AT_ONCE_LIMIT'
              if $t;

            warn '>>>> >>>> >>>> should_be_restarted set to, 0'
              if $t;

            # No, a queued mailing should not have to be restarted. Duh.
            $status->{should_be_restarted} = 0;
            warn '>>>> >>>> >>>> should_be_restarted set to, 0'
              if $t;

            # This keeps the logic in here, and I don't have to repeat the
            # above, "if..." line a billion times...

            $status->{queued_mailout} = 1;

            warn '>>>> >>>> >>>> queued_mailout set to, 1'
              if $t;

        }
        else {

            # Meaning, we ARE, in fact, queueing, but this mailout is
            # inside how many mailouts are allowed at one time.

            $status->{should_be_restarted} = $self->should_be_restarted;
            warn '>>>> >>>> >>>> $status->{should_be_restarted} set to: ' . $status->{should_be_restarted}
              if $t;

            $status->{queued_mailout} = 0;
            warn '>>>> >>>> >>>> queued_mailout set to, 0'
              if $t;
        }

    }
    else {

        $status->{queue}       = 0;
        $status->{queue_place} = undef;
        $status->{queue_total} = undef;

        # Meaning, we're not queueing, so tell me if we need to restart
        # using this expensive method...

        $status->{should_be_restarted} = $self->should_be_restarted;
        warn '>>>> >>>> should_be_restarted set to ' . $status->{should_be_restarted}
          if $t;

        $status->{queued_mailout} = 0;
        warn '>>>> >>>> queued_mailout set to, 0'
          if $t;
    }

    # should be like a + .05 somewhere in here...
    if ( $status->{total_sent_out} > 0 ) {

        eval {

            $status->{percent_done} =
              int( int( $status->{total_sent_out} ) / int( $status->{total_sending_out_num} ) * 100 );
        };

        if ($@) {
            $status->{percent_done} = 0;
        }
    }
    else {
        $status->{percent_done} = 0;
    }

    # NOTE:
    # should_be_restarted
    # and,
    # process_has_stalled
    # Are fairly similar, probably best to use,
    #
    # should_be_restarted
    #
    # instead of the other...

    # I've put this above, so as not to call, "status()" twice...
    # $status->{should_be_restarted} = $self->should_be_restarted;

    my $process_has_stalled = $self->process_has_stalled;

    $status->{process_has_stalled} = $process_has_stalled;
    warn '>>>> process_has_stalled set to, ' . $status->{process_has_stalled}
      if $t;

    # Test for a stalled process -
    # DEV: I'm weirded out at the reason why status() is doing something like
    # thing. Huh?!
    if ( $process_has_stalled == 1 ) {

        if ( $self->is_batch_locked == 1 ) {
            warn "Process has stalled. Unlocking batchlock, so it may start again!"
              if $t;
        }
        else {
            warn "Process has stalled. Batch is not locked."
              if $t;
        }

        if ( $status->{total_sent_out} == $status->{total_sending_out_num} ) {
            warn
"Well, wait, the amount to send out equals the number we have to send out - I think we're done, will unlock anyways, to get around niggly stuff, but expect warnings..."
              if $t;

            warn '$status->{total_sent_out} == $status->{total_sending_out_num} ?!?!'
              if $t;
        }

        $self->unlock_batch_lock();
        $status->{is_batch_locked} = 0;

    }

    # A stale mailout means that the time since the last email sent is more
    # than some sort of number.
    # A stale mailout isn't something you want to restart automatically,
    # since it may be something *too* old to really bother with...

    if (   $status->{last_access} > 0
        && $status->{should_be_restarted} =~ m/1|0/ )
    {
        $status->{mailout_stale} = $self->is_mailout_stale(
            $status->{last_access},

            #$status->{should_be_restarted}
        );
    }
    else {
        #warn "Skipping stale check?"
        #	if $t;
        $status->{mailout_stale} = undef;
    }

    $self->unlock_file($lock);

    return $status;

}

sub is_mailout_stale {

    my $self = shift;
    my $last_access = shift || croak "at the moment, you have to pass the, last_access time manually (hey sorry!)";

    if ( ( int(time) - $last_access ) > $DADA::Config::MAILOUT_STALE_AFTER ) {
        return 1;
    }
    else {
        return 0;
    }

    # 86,400 seconds in an hour.
}

sub should_be_restarted {

    warn 'Start test of, "should_be_restarted"'
      if $t;

    my $self = shift;

    if ( $self->paused ) {

        warn '>>>>mailing is paused, should not be restarted.'
          if $t;

        # mailing is paused - no need to see if it needs to be restarted quite yet...
        return 0;

    }
    else {

        my $last_access = _poll( $self->dir . '/' . $file_names->{last_access} );

        if ( $self->{ls}->param('restart_mailings_after_each_batch') == 1 ) {

            # Basically, if the sending process isn't locked, we wait the amount
            # of time we'd usually sleep() and if we're over that time, it's time
            # to send again!

            warn '>>>>restart_mailings_after_each_batch set to, "1"'
              if $t;

            my $sleep_amount = $self->{ls}->param('bulk_sleep_amount');

            if ( ( $last_access + $sleep_amount ) <= time ) {

                warn '>>>> >>>>Looks like we\'ve overslept. (($last_access + $sleep_amount ) <= time)'
                  if $t;

                # last access is in the past,
                # sleep amount is in seconds.
                # if *now* is more than the last access time,
                # plus we're supposed to sleep for,
                # we've overslept...

                # Time to restart, as long as the lock isn't there...

                if ( $self->is_batch_locked ) {

                    warn '>>>> >>>> >>>> batch is locked.'
                      if $t;

                    # Well, OK, it's there,
                    # but I mean, is it a *stale* lock?!

                    if ( $self->process_has_stalled ) {

                        warn '>>>> >>>> >>>> >>>>process has stalled.'
                          if $t;

                        # Process has stalled
                        # And it's time to restart?
                        # let's do it:

                        warn '>>>> >>>> >>>> >>>>Yes. The mailing SHOULD be restarted. (' . $$ . ')'
                          if $t;

                        return 1;

                    }
                    else {

                        # Let's wager on the side of being conservative
                        # and wait till the lock is officially stale
                        # Before we do anything *rash*

                        warn '>>>> >>>> >>>> >>>>process has NOT stalled.'
                          if $t;

                        warn '>>>> >>>> >>>> >>>>No. The mailing SHOULD NOT be restarted. (' . $$ . ')'
                          if $t;

                        return 0;
                    }

                }
                else {

                    # Sending process is *not* locked?
                    # And it's time to restart, let's do it.

                    warn '>>>> >>>> >>>> batch is NOT locked.'
                      if $t;

                    warn '>>>> >>>> >>>> Yes. The mailing SHOULD be restarted. (' . $$ . ')'
                      if $t;

                    return 1;

                }

            }
            else {

                warn '>>>> >>>>Mailing is either sleeping or hasn\'t been inactive for enough time.'
                  if $t;

                warn '>>>> >>>>No. The mailing SHOULD NOT be restarted. (' . $$ . ')'
                  if $t;

                # not time yet...
                return 0;
            }

        }
        else {

            warn '>>>>restart_mailings_after_each_batch set to, "0"'
              if $t;

            if ( $self->is_batch_locked ) {
                warn '>>>> >>>> batch is locked.'
                  if $t;

                # Batch is locked.
                # Is the batch stale?

                if ( $self->process_has_stalled ) {
                    warn '>>>> >>>> >>>> process has stalled.'
                      if $t;

                    warn '>>>> >>>> >>>> Yes. The mailing SHOULD be restarted. (' . $$ . ')'
                      if $t;

                    # Yes? Let's restart.

                    return 1;
                }
                else {
                    warn '>>>> >>>> >>>> process has NOT stalled.'
                      if $t;

                    # No? Hold off.

                    return 0;
                }
            }
            else {

                warn '>>>> >>>> batch is NOT locked.'
                  if $t;

                if ( $self->process_has_stalled ) {

                    warn '>>>> >>>> >>>> process has stalled.'
                      if $t;

                    warn '>>>> >>>> >>>> Yes. The mailing SHOULD be restarted. (' . $$ . ')'
                      if $t;

                    # carp "Batch ain't locked. process is stalled.";

                    # batch ain't locked, huh? Restart!
                    return 1;

                }
                else {
                    warn '>>>> >>>> >>>> process has NOT stalled.'
                      if $t;
                    warn '>>>> >>>> >>>> No. The mailing SHOULD Not be restarted. (' . $$ . ')'
                      if $t;
                    return 0;

                }
            }
        }

    }
}

sub process_has_stalled {

    my $self = shift;

    warn 'Checking process_has_stalled'
      if $t;

    #    carp '$self->process_stalled_after ' . $self->process_stalled_after;

    if ( $self->process_stalled_after <= 0 ) {

        warn '>>>> process_stalled_after <= 0'
          if $t;
        warn '>>>> reporting that process_has_stalled = 1'
          if $t;

        return 1;
    }
    else {

        warn '>>>> process_stalled_after > 1'
          if $t;
        warn '>>>> reporting that process_has_stalled = 0'
          if $t;

        return 0;
    }
}

sub process_stalled_after {

    my $self = shift;

    warn 'Checking process_stalled_after.'
      if $t;

    my $last_access = _poll( $self->dir . '/' . $file_names->{last_access} );

    warn '>>>> $last_access: ' . $last_access
      if $t;

    my ( $e, $batch_size, $batch_wait ) = $self->batch_params;

    warn '>>>> $batch_wait: ' . $batch_wait
      if $t;

    # I'm thinking it's really dangerous to have a countdown < 60,
    # Since we just may have a slow SMTP server on our hands...

    my $tardy_threshold = ( $batch_wait * 3 );
    if ( $tardy_threshold < 60 ) {
        $tardy_threshold = 60;
    }

    my $countdown = $tardy_threshold - ( time - $last_access );

    warn '>>>> $tardy_threshold ' . $tardy_threshold
      if $t;

    warn '>>>> ( time - $last_access ) ' . ( time - $last_access )
      if $t;

    warn '>>>> $countdown ' . $countdown
      if $t;

    return $countdown;

}

sub still_around {

    my $self = shift;

    if ( !-e $self->dir ) {
        carp '['
          . $self->list
          . ']   Mass Mailing:"'
          . $self->_internal_message_id
          . ' attempting to send a mass mailing that doesn\'t exist anymore? Failed "still_around" test ';
        return undef;
    }
    else {
        return 1;
    }

}

sub mail_fields_from_raw_message {
    my $self = shift;

    my $raw_msg = $self->message_for_mail_send;

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $self->{list} );

    my ( $raw_header, $raw_body ) = split( /\n\n/, $raw_msg, 2 );
    my $headers = {};
    my @logical_lines = split /\n(?!\s)/, $raw_header;

    # make the hash
    for my $line (@logical_lines) {
        my ( $label, $value ) = split( /:\s*/, $line, 2 );
        $value = $fm->_decode_header($value);
        $headers->{$label} = $value;
    }
    undef $fm;
    return $headers;
}

sub _decode_header {

    my $self   = shift;
    my $header = shift;

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $self->{list} );
    return $fm->_decode_header($header);

}

sub _poll {

    my $file = shift;

    croak "No file passed to poll."
      if !$file;

    $file = make_safer($file);

    # Question: What happens if the file does not exist?

    if ( !-e $file ) {
        carp "The file, '" . $file . "'does not exist to poll.";
        return undef;
    }

    sysopen( FH, $file, O_RDWR | O_CREAT, $DADA::Config::FILE_CHMOD )
      or die "can't open counter: $!";
    flock( FH, LOCK_SH )
      or die "can't flock counter: $!";

    #my $num = <FH>;
    # readline alone is 10x faster?!
    my $num = readline(*FH);

    #chomp($num);

    close FH
      or die "can't close counter: $!";
    chmod( $DADA::Config::FILE_CHMOD, $file );

    # chomp() is not necessary with these guys.
    $num =~ s/^\s+//o;
    $num =~ s/\s+$//o;

    return $num;
}

sub reload {

    warn "reload called ($$)"
      if $t;

    my $self = shift;

    my $lock = $self->lock_file( $self->mailout_directory_name );

    # Note: I'm not sure why either pause() or the queueing stuff doesn't make an appearance here...
    # hmm...
    # It really should....?

    my @args = @_;
    croak "reload() takes no arguments"
      if $args[0];

    # This is also listed in associate - why?
    $self->dir( $self->mailout_directory_name() );

    $self->total_sending_out_num( _poll( $self->dir . '/' . $file_names->{num_sending_to} ) );

    $self->subscriber_list( $self->dir . '/' . $file_names->{tmp_subscriber_list} );

    if ( $self->is_batch_locked ) {

        # DEV: Well, if there error message says, "Hey, you have to call
        # status() if the batch lock is still around, and you're calling reload
        # why don't I do that for myself, if the process seems stalled. Huh. Huh?!
        #
        #
        # The only other thing I can think of doing is checking the pid to make
        # sure it's myself - but not here - perhaps in DADA::Mail::Send?
        #

        if ( $self->process_stalled_after < 0 ) {
            $self->status;
            carp "Reloading message... ($$)";
        }
        else {

            my $msg =
                "Cannot reload! Sending process is locked! Another process may"
              . " be underway, or, the lock is stale. If so, will remove"
              . " the stale lock in:  "
              . $self->process_stalled_after
              . "  seconds"
              . "( Call status() to remove the stale lock.)";
            croak($msg);
        }
    }
    else {

        carp "Reloading message... ($$)";

    }

    $self->unlock_file($lock);

    return $self->message_for_mail_send;

}

sub counter_at {
    my $self  = shift;
    my $count = _poll( $self->dir . '/' . $file_names->{counter} );

    croak(  "counter is more than the total number that we're sending out!\n counter: "
          . $count
          . "\n total:"
          . $self->total_sending_out_num )
      if $count > $self->total_sending_out_num;

    warn 'counter at: ' . $count
      if $t;

    return $count;
}

sub message_for_mail_send {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{raw_message};

    if ( !-e $file ) {
        warn "Raw Message that should be saved at: " . $file . "isn't there.";
        return undef;
    }

    open my $MSG_FILE, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file
      or die "Cannot read saved raw message at: '" . $file . "' because: " . $!;

    my $msg = do { local $/; <$MSG_FILE> };
    close $MSG_FILE
      or die "Didn't close: '" . $file . "'properly because: " . $!;

    if ( !$msg ) {
        carp "message is blank.";
    }

    warn 'Mail message saved at: ' . $file
      if $t;

    return $msg;
}

sub clean_up {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-force} ) ) {
        $args->{-force} = 1;
    }
    warn 'clean_up called '
      if $t;

    croak "Make sure to call, 'associate' before calling cleanup!"
      if !$self->dir;

    require File::Copy;

    ##########################################################################
    # Save that log:
    #
    if ( $self->{ls}->param('mass_mailing_save_logs') == 1 ) {
        my $orig_log_file = $self->dir . '/' . $file_names->{log};
        $orig_log_file = make_safer($orig_log_file);

        my $letter_id = $self->_internal_message_id;
        $letter_id =~ s/\@/_at_/g;
        $letter_id =~ s/\>|\<//g;

        my $save_log_file =
          make_safer( $DADA::Config::LOGS . '/'
              . 'sendout-'
              . $self->list . '-'
              . $self->mailout_type . '-'
              . $letter_id . '-'
              . $file_names->{log} );
        File::Copy::copy( $orig_log_file, $save_log_file )
          or warn "could not move file from, '$orig_log_file', to, '$save_log_file': $!";
    }
    #
    ##########################################################################

    my $orig_name = $self->dir;

    # so, we rename things, to get them out of the way, right away:
    my $tmp_name = $orig_name;
    $tmp_name =~ s/sendout/TMP_sendout/;

    File::Copy::move( $orig_name, $tmp_name )
      or warn "could not move director from, '$orig_name', to, '$tmp_name': $!";

    # return 1; warn 'change back when shipping!';
    $self->dir($tmp_name);

    my $lock = $self->lock_file( $self->mailout_directory_name( { -tmp => 1 } ) );

    my @deep_six_list;

    for my $fn ( keys %$file_names ) {

        # basically, iterate through the type of files that, *may* be in there...
        if ( -e make_safer( $self->dir . '/' . $file_names->{$fn} ) ) {
            push( @deep_six_list, make_safer( $self->dir . '/' . $file_names->{$fn} ) );
        }
        else {
            # most annoying error...
            # carp "not attempting removing: " . $self->dir . '/' . $file_names->{$fn} . '. Reason: not present.(?)';
        }

        # And, lock files:
        if ( -e make_safer( $self->dir . '/' . $file_names->{$fn} . '.lock' ) ) {
            push( @deep_six_list, make_safer( $self->dir . '/' . $file_names->{$fn} . '.lock' ) );
        }

    }

    my $d6_count = unlink(@deep_six_list);

    unless ( $d6_count == $#deep_six_list + 1 ) {
        carp "something didn't get removed! ($d6_count)";
        return 0;
    }

    if ( rmdir( make_safer( $self->dir ) ) ) {

        # good to go.
        $self->unlock_file($lock);
        unlink( $self->mailout_directory_name( { -tmp => 1 } ) . '.lock' );

    }
    else {
        if ( $args->{-force} == 1 ) {
            eval {
                require File::Path;
                File::Path::remove_tree( $self->dir );
            };
            if ($@) {

                # I'm not fooling around...
                system( 'rm', '-r', '-f', $self->dir );
            }
            if ( -e $self->dir ) {
                carp "couldn't remove the sending directory! at " . $self->dir;
                return 0;
            }
        }
        else {
            carp "couldn't remove the sending directory! at " . $self->dir;
            return 0;
        }

    }

    warn 'clean_up seemed successful. '
      if $t;

    return 1;

}

sub lock_file {

    # DEV: TODO:
    # It would be nice to extend the API for this method to allow you to
    # spec the, "Highlander" mode, as well as how many seconds before croak'ing
    # And/OR if you croak, or it just gives back and warning and an undef (or
    # something like that)
    my $i = 0;

    my $self = shift;

    if ( $self->use_semaphore_locking == 0 ) {
        return undef;
    }

    my $file      = shift || croak "You must pass a file to lock!";
    my $countdown = shift || 0;

    my $lockfile = make_safer( $file . '.lock' );

    open my $fh, ">", $lockfile
      or croak "Can't open semaphore file '$lockfile' because: $!";

    chmod $DADA::Config::FILE_CHMOD, $lockfile;

    {

        # Two potentially non-obvious but traditional flock semantics are that it
        # waits indefinitely until the lock is granted, and that its locks merely
        # advisory.
        # DEV: Ah, NB: Non blocking - that's what we need...

        my $count = 0;
        {

            flock $fh, LOCK_EX | LOCK_NB and last;

            sleep 1;
            redo if ++$count < $countdown;

            croak
"Couldn't lock semaphore file '$lockfile' for '$file' because: '$!', exiting with error to avoid file corruption!";

        }
    }

    return $fh;

}

sub unlock_file {

    my $self = shift;

    if ( $self->use_semaphore_locking == 0 ) {
        return 1;
    }

    my $file = shift || croak "You must pass a filehandle to unlock!";
    close($file) or croak q{Couldn't unlock semaphore file for, } . $file . ' ' . $!;

    return 1;

}

sub current_mailouts {

    my ($args) = @_;
    my $default_list = undef;

    if ( exists( $args->{-list} ) ) {
        $default_list = $args->{-list};
    }

    if ( !exists( $args->{-order_by} ) ) {
        $args->{-order_by} = 'sending_queue';    # creation?
    }

    my @mailouts = ();

    my $dir;    # DEV: why is the variable called, "$file", yet we're looking for directories?!?!?!

    if ( !-e $DADA::Config::TMP ) {
        croak '$DADA::Config::TMP (' . $DADA::Config::TMP . ') doesn\'t exist?!';
    }
    opendir( FILES, $DADA::Config::TMP )
      or croak
      "$DADA::Config::PROGRAM_NAME $DADA::Config::VER error, can't open '$DADA::Config::TMP'  to read because: $!";

    while ( defined( $dir = readdir FILES ) ) {

        #don't read '.' or '..'
        next if $dir =~ /^\.\.?$/;

        # Why is this commented out?
        # Right? This thing has to be a directory, no?
        #next if ! -d $dir;
        # Answer: Tests sort of freak out - I don't know why...

        $dir =~ s(^.*/)();

        # ends in, ".lock" - that means this is actually a lock file and not our
        # actual mailout.

        next if $dir =~ /\.lock$/;

        if ($default_list) {
            my $s_default_list = quotemeta($default_list);
            next if $dir !~ /^sendout\-$s_default_list\-.*$/;
        }
        else {
            # Hope that's enough to match...
            next if $dir !~ /^sendout\-.*$/;
        }

        my ( $junk, $list, $listtype, $id ) = split( '-', $dir, 4 );    #limit of, "4"

        # Need to sort by, "Date"
        # Date is embedded in message-id
        # Message-ID has all sorts of crud in it.
        # $gh{'Message-ID'} = '<' .  DADA::App::Guts::message_id() . '.'. $ran_number . '@' . $From_obj->host . '>';
        # This is what the file looks like:
        # sendout-j-list-20070320181623.91081883_at_skazat.com
        #  $junk   $list $listtype $id
        #
        #So, I got this:
        #   20070320181623.91081883_at_skazat.com
        # So just
        #

        if ( DADA::App::Guts::check_if_list_exists( -List => $list, -Dont_Die => 1 ) == 0 ) {
            carp "There's a mailout from a list that doesn't exist ($list)";
            next;
        }
        my $expanded_time = $id;

        # all I want is the string before the first dot.
        $expanded_time =~ s/\.(.*)$//;
        push(
            @mailouts,
            {
                list          => $list,
                type          => $listtype,
                id            => $id,
                expanded_time => $expanded_time,
                sendout_dir   => $dir
            }
        );
    }

    closedir(FILES);

    # Now, we have to sort them, based on the expanded time.

    @mailouts = map { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map { [ $_->{expanded_time}, $_ ] } @mailouts;

    if ( $args->{-order_by} eq 'sending_queue' ) {

       # And now, we have to split THAT up, so that unpaused messages are at the TOP, paused messages are at the bottom:

        my @unpaused = ();
        my @paused   = ();
        my @stale    = ();

        for my $test_m (@mailouts) {

            # croak 'sendout_dir ' . $test_m->{sendout_dir};
            # This is an optimization - we just look to see if the paused file exists - if so, we say it's paused,
            # this makes it so we don't have to call, "status", since that's pretty resource-intensive

            if ( -e $DADA::Config::TMP . '/' . $test_m->{sendout_dir} . '/' . $file_names->{pause} ) {
                push( @paused, $test_m );
            }
            else {

                # DEV: 2203220  	 3.0.0 - Stale Mass Mailing can still clog up mail queue
                # https://sourceforge.net/tracker2/?func=detail&aid=2203220&group_id=13002&atid=113002
                # The trick is just to move stale mailouts to the bottom of the queue
                # The other option is to pause stale mailouts, which isn't the worst thing,
                # But I then have to re-check if a stale mailout is paused, every time we call, status(), right?
                my $last_access_file =
                  $DADA::Config::TMP . '/' . $test_m->{sendout_dir} . '/' . $file_names->{last_access};
                if ( -e $last_access_file ) {

                    my $last_access = _poll($last_access_file);

                    if ( ( int(time) - $last_access ) >= $DADA::Config::MAILOUT_STALE_AFTER ) {
                        push( @stale, $test_m );
                    }
                    else {
                        push( @unpaused, $test_m );
                    }
                }
                else {
                    push( @unpaused, $test_m );
                }
            }
        }

        # Now, put it back together:
        # @mailouts = (@unpaused, @paused, @stale);
        @mailouts = ( @unpaused, @paused, @stale );
    }

    # And done.

    return @mailouts;

}

sub mailout_exists {

    my $list = shift;
    my $id   = shift;
    my $type = shift;

    $id =~ s/\@/_at_/g;
    $id =~ s/\>|\<//g;

    croak "You did not supply a list!"
      if !$list;
    croak "You did not supply an id! "
      if !$id;
    croak "You did not supply a type!"
      if !$type;

    my @mailouts = current_mailouts( { -list => $list } );

    for my $mo (@mailouts) {

        if ( $mo->{id} eq $id && $mo->{type} eq $type && $mo->{list} eq $list ) {

            return 1;

        }
    }

    return 0;

}

sub log {

    my $self = shift;
    my $log  = shift;
    my $time = scalar( localtime() );

    my $file = $self->dir . '/' . $file_names->{log};
    $file = make_safer($file);

    open( MO_LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or carp $!;
    flock( MO_LOG, LOCK_SH );
    print MO_LOG "[$time]\t$log\n";
    close(MO_LOG);

}

sub log_problem_address {

    my $self = shift;
    my ($args) = @_;

    my $file = $self->dir . '/' . $file_names->{problem_subscriber_list};
    $file = make_safer($file);

    open( PROBLEMS, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or carp $!;
    flock( PROBLEMS, LOCK_SH );
    print PROBLEMS $args->{-address} . "\n";
    close(PROBLEMS);

}

sub isa_problem_address {

    my $self = shift;
    my ($args) = @_;

    my $file = $self->dir . '/' . $file_names->{problem_subscriber_list};
    $file = make_safer($file);

    sysopen( LIST, $file, O_RDWR | O_CREAT, $DADA::Config::FILE_CHMOD )
      or croak "couldn't open '$file' for reading: $!\n";

    flock( LIST, LOCK_SH );
    binmode LIST, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';

    my $check_this = undef;
    my $in_list    = 0;

    while ( defined( $check_this = <LIST> ) ) {

        chomp($check_this);

        if ( cased($check_this) eq cased( $args->{-address} ) ) {
            $in_list = 1;
            last;
        }
    }

    close(LIST);

    return $in_list;

}

sub print_log {

    my $self = shift;

    my $file = $self->dir . '/' . $file_names->{log};
    $file = make_safer($file);

    open( MO_LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      or carp $!;

    while (<MO_LOG>) {
        print $_;
    }

    close(MO_LOG);
    return 1;

}

sub line_in_queue {

    my $self = shift;

    my $internal_id = $self->_internal_message_id;

    my @mailouts = current_mailouts();

    my $counter = 0;             # start with 0;
    my $total   = $#mailouts;    # Starts with 0, too!

    for my $mailout (@mailouts) {

        my $check_id = $mailout->{id};

        # carp '$check_id ' . $check_id;
        # carp '$internal_id ' . $internal_id;

        # These transformations happen for the internal ID too.
        # They really need their own method, since this is
        # getting messy...

        $check_id =~ s/\@/_at_/g;
        $check_id =~ s/\>|\<//g;

        # and hell, do it for our internal id, since i don't trust it...
        $internal_id =~ s/\@/_at_/g;
        $internal_id =~ s/\>|\<//g;

        # carp '$check_id after transformation ' . $check_id;
        # carp '$internal_id after transformation ' . $internal_id;

        if ( $check_id eq $internal_id ) {

            # carp ("returning $counter and $total");

            return ( $counter, $total );
        }
        else {
            $counter++;
        }
    }

    carp("Could not find mailout in the current queue?!");
    return ( undef, undef );

}

sub _list_name_check {

    my ( $self, $n ) = @_;
    $n = strip($n);
    return 0 if !$n;
    return 0 if $self->_list_exists($n) == 0;
    return 1;
}

sub _list_exists {
    my ( $self, $n ) = @_;
    return DADA::App::Guts::check_if_list_exists( -List => $n );
}

sub monitor_mailout {

    my ($args) = @_;

    my $v = 0;
    if ( exists( $args->{-verbose} ) ) {
        $v = $args->{-verbose};
    }
    my $d_list = undef;
    if ( exists( $args->{-list} ) ) {
        $d_list = $args->{-list};
    }

    if ( !exists( $args->{-action} ) ) {
        $args->{-action} = 1;
    }

    my $r = '';

    my @available_lists = DADA::App::Guts::available_lists();

    require DADA::Mail::Send;
    require DADA::MailingList::Settings;

    # CHANGES -
    # I need to basically call status() on every single mailout first (cache for later, of course)

    my $active_mailouts   = 0;
    my $inactive_mailouts = 0;
    my $paused_mailouts   = 0;
    my $queued_mailouts   = 0;
    my $total_mailouts    = 0;

    # Note! Not cached, now, is it?!
    my @mailouts = current_mailouts();

    my $mailout_obj_cache    = {};
    my $mailout_status_cache = {};
    for my $mailing (@mailouts) {

        if ( DADA::App::Guts::check_if_list_exists( -List => $mailing->{list} ) == 0 ) {
            carp "Attempting to monitor a mailout for a list (" . $mailing->{list} . ") that does not exist!";
            next;
        }

        # *Would(* there be a reason, $mailing->{list} would be blank!?

        if ( $mailing->{list} ) {

            my $mailout = DADA::Mail::MailOut->new( { -list => $mailing->{list} } );
            $mailout->associate( $mailing->{id}, $mailing->{type} );

            $mailout_obj_cache->{ $mailing->{list} }->{ $mailing->{id} }->{ $mailing->{type} } = $mailout;

            my $status = $mailout->status();

            $mailout_status_cache->{ $mailing->{list} }->{ $mailing->{id} }->{ $mailing->{type} } = $status;

            # Well, if it's not currently cached, we don't have to save it .
            # push(@mailouts, $status);
            # Hmm. Wonder why the above is commented out?

            # and then make a list of:
            # Current *Active* mailouts
            # Current *Inactive* mailouts
            # Current *paused* mailouts
            # and then (and only then)

            if (   $status->{paused}
                || $status->{queued_mailout} == 1 )
            {

                if ( $status->{paused} ) {
                    $paused_mailouts++;
                }
                elsif ( $status->{queued_mailout} ) {
                    $queued_mailouts++;
                }
            }
            elsif ( $status->{should_be_restarted} == 1 ) {
                $inactive_mailouts++;    # renamed to... hmmm
            }
            else {
                $active_mailouts++;
            }

            $total_mailouts++;
        }
        else {

            # Again, not sure how we'd end up here...
            my $weird_report = '';
            for ( keys %$mailing ) {
                $weird_report .= $_ . ' => ' . $mailing->{$_} . ",\t";
            }
            carp "Mass Mailing malformed? $weird_report";

        }
    }

    $r .= 'Server Time: ' . scalar(localtime(time)) . "\n";
    $r .=
"Total Mass Mailings: $total_mailouts, Active Mass Mailings: $active_mailouts, Paused Mass Mailings: $paused_mailouts, Queued Mass Mailings: $queued_mailouts, Inactive Mass Mailings: $inactive_mailouts\n\n";

    my $active_mailouts_num = $active_mailouts;

    if ( $args->{-action} == 0 ) {
        return ( $r, $total_mailouts, $active_mailouts, $paused_mailouts, $queued_mailouts, $inactive_mailouts );
    }

    # DEV: This subroutine needs to be split. RIGHT HERE
    for my $list (@available_lists) {

        if (   ($d_list)
            && ( $d_list ne $list ) )
        {
            next;
        }

        $r .= "\nList: " . $list . "\n";

        my @mailouts = current_mailouts(
            {
                -list => $list
            }
        );

        if ( !$mailouts[0] ) {
            $r .= "\t*No current mailouts for $list\n";

        }
        for my $mailing (@mailouts) {

            $r .= "\n\tmailout: " . $mailing->{id} . "\n";

            $r .= "\ttype:    " . $mailing->{type} . "\n";

            my $mailout = undef;
            my $status  = undef;

            if ( exists( $mailout_obj_cache->{$list}->{ $mailing->{id} }->{ $mailing->{type} } ) ) {

                # Some optimization via caching...
                warn "Using a cached DADA::Mail::mailout obj and status return"
                  if $t;
                $mailout = $mailout_obj_cache->{$list}->{ $mailing->{id} }->{ $mailing->{type} };
                $status  = $mailout_status_cache->{$list}->{ $mailing->{id} }->{ $mailing->{type} };
            }
            else {
                $mailout = DADA::Mail::MailOut->new( { -list => $list } );
                $mailout->associate( $mailing->{id}, $mailing->{type} );
                $status = $mailout->status();
            }

            $r .= "\n\t\tStatus:\n\n";

            for ( sort keys %$status ) {
                if ( $_ eq 'email_fields' ) {
                    $r .= "\t\t" . _pad_str('* Subject: ') . $status->{$_}->{Subject} . "\n";

                }
                else {

                    $r .= "\t\t" . _pad_str( '* ' . $_ . ' ' ) . $status->{$_} . "\n";

                }
            }

            $r .= "\t\t\n";

            # Kind of a pre-check:
            if ( $status->{integrity_check} == 0 ) {
                $r .=
"\t\t\tWARNING! Integrity Check is returning 0! Something may be wrong with this mailing! Pausing and exiting.\n";

                if ( $status->{paused} != 1 ) {
                    $mailout->pause;
                }
                $status = $mailout->status;

                #print $r
                #		if $v == 1;
                #return $r;
            }
            else {
                $r .= "\t\t\tMass Mailing appears to be in good health.\n";
            }

            if (   exists( $status->{total_sent_out} )
                && exists( $status->{total_sending_out_num} )
                && ( $status->{total_sent_out} < $status->{total_sending_out_num} ) )
            {
                my $ls = DADA::MailingList::Settings->new( { -list => $list } );

                my $li = $ls->get;

                $r .= "\t\t\tMass Mailing is not finished...\n";

                if ( $status->{should_be_restarted} == 1 ) {

                    $r .= "\t\t\t\tMass Mailing looks like it should be restarted...\n";

                    if ( $li->{auto_pickup_dropped_mailings} == 1 ) {

                        $r .= "\t\t\t\t\tauto pickup is ON\n";

                        if ( $status->{mailout_stale} ) {

                            $r .=
"\t\t\t\t\tMass Mailing seems too stale to automatically be reloaded - Not restarting automatically.\n";
                            $r .= "\t\t\t\t\tTo restart, visit this mailout's individual sending monitor screen.\n";

                        }
                        else {

                     # restart a mailout if there isn't too many *active* mailouts (system wide) already
                     # That *should* solve my, "mailouts start that shouldn't" problem
                     # the only thing is, will this be whacky with the queueing/pausing features that are already there?
                     # Probably not, since the queue knows about paused messages.

                            if ( $active_mailouts_num >= $DADA::Config::MAILOUT_AT_ONCE_LIMIT ) {

                                $r .=
"\t\t\t\t\tCan't restart mailing, since the amount of current, active mailouts ($active_mailouts_num) is more than, or equal to the set limit ( "
                                  . $DADA::Config::MAILOUT_AT_ONCE_LIMIT . ")\n";

                            }
                            else {

                                # This check may never get tripped, if we keep pausing broken mailouts...
                                if ( $status->{integrity_check} == 1 ) {

                                    $r .= "\t\t\t\t\tRestarting mailing NOW!\n";
                                    my $mh = DADA::Mail::Send->new(
                                        {
                                            -list   => $list,
                                            -ls_obj => $ls,
                                        }
                                    );
                                    $mh->restart_mass_send( $mailing->{id}, $mailing->{type} );

                                    $active_mailouts_num++;
                                    $r .= "\t\t\t\t\tMailing Restarted Successfully.\n";

       # DEV: Why would I exit, after restarting (and after checking if I can restart) when there may be other things to
       # report? That makes no sense:

             # print $r
             #	if $v == 1;
             #   return ($r, $total_mailouts, $active_mailouts, $paused_mailouts, $queued_mailouts, $inactive_mailouts);
                                }
                                else {

                                    $r .= "\t\t\t\t\tCan\'t restart Mass Mailing - integrity check is returning 0!\n";
                                    $r .=
                                      "\t\t\t\t\tMass Mailing is most likely broken and should be manually removed.\n";

                                }

                            }

                        }

                    }
                    else {

                        $r .= "\t\t\t\tauto pickup is OFF - not restarting Mass Mailing.\n";

                    }
                }
                else {
                    $r .= "\t\t\tMass Mailing appears to be still going...\n";
                }

                if ( $status->{paused} ) {
                    $r .= "\t\t\tMass Mailing has been paused.\n";

                }

                if ( $status->{queued_mailout} ) {
                    $r .= "\t\t\tMass Mailing is queued for future sending.\n";

                    $r .=
                        "\t\t\tMass Mailing is #"
                      . ( $status->{queue_place} + 1 ) . " of: "
                      . ( $status->{queue_total} + 1 )
                      . " Mass Mailingss.\n";

                }

            }
            elsif ( $status->{integrity_check} == 0 ) {

                $r .= "\t\t*Problems with the Mass Mailing* - Integrity check is returning, '0'\n";

            }
            else {
                $r .= "\t\tMass Mailing is finished.\n";
            }
        }
    }

    print $r if $v == 1;

    return ( $r, $total_mailouts, $active_mailouts, $paused_mailouts, $queued_mailouts, $inactive_mailouts );

}

sub _pad_str {

    # DEV: I'd had to rewrite this type of sub, since it's going to be buggy,
    # and there's a million different ones, but, here goes:

    my $str = shift;
    my $padding = shift || 25;

    if ( length($str) > 0 && length($str) < 25 ) {
        $padding = $padding - length($str);
        return $str . ' ' x $padding;
    }
    else {
        return $str;
    }
}

sub _formatted_runtime {

    my $d = shift || 0;

    my @int = (
        [ 'second', 1 ],
        [ 'minute', 60 ],
        [ 'hour',   60 * 60 ],
        [ 'day',    60 * 60 * 24 ],
        [ 'week',   60 * 60 * 24 * 7 ],
        [ 'month',  60 * 60 * 24 * 30.5 ],
        [ 'year',   60 * 60 * 24 * 30.5 * 12 ]
    );
    my $i = $#int;
    my @r;
    while ( ( $i >= 0 ) && ($d) ) {
        if ( $d / $int[$i]->[1] >= 1 ) {
            push @r, sprintf "%d %s%s", $d / $int[$i]->[1],
              $int[$i]->[0], ( sprintf "%d", $d / $int[$i]->[1] ) > 1
              ? 's'
              : '';
        }
        $d %= $int[$i]->[1];
        $i--;
    }

    my $runtime;
    if (@r) {
        $runtime = join ", ", @r;
    }
    else {
        $runtime = '0 seconds';
    }

    return $runtime;
}

sub DESTROY {

    my $self = shift;

}

1;

=pod

=head1 NAME

DADA::Mail::MailOut - Helps Monitor a Mass Mailings


=head1 VERSION

Refer to the version of Dada Mail that this module comes in. 

=head1 SYNOPSIS

    # A few subroutines, exported by default: 
    
    my @mailouts  = DADA::Mail::MailOut::current_mailouts({-list => $list });  
 
    my $exists    = DADA::Mail::MailOut::mailout_exists($list, $id, $type); 
    
    my    $report    = DADA::Mail::MailOut::monitor_mailout({--verbose => 0, --list => $list});
    print $report;
     
    # Create a new DADA::Mail::MailOut object: 
    my $mailout = DADA::Mail::MailOut->new({-list => $list}); 
    
    # Make a new Mass Mailing: 
    $mailout->create(
                    -fields   => {%fields},
                    -list_type => 'list',
                    -mh_obj    => $mh_obj,  
               ); 
    
    # how's that mailout doin'?
    my $status = $mailout->status; 
    
    # Let's pause the mailing! 
    $mailout->pause; 
    
    # Ok, let's start it back up again, where it left off: 
    $mailout->resume; 
    
    # do I need to reload the mailout? 
    my $yes_restart = $mailout->should_be_restarted; 
    
    # if so, let's do that: 
    if($yes_restart){ 
        $mailout->reload();  
    }

=head1 DESCRIPTION

This module does a few things, all of which happen to deal with setting up a
mass mailing and then monitoring its status.

Mass Mailings do take a while and the CGI environment that Dada Mail is (usually) run
in, isn't the best thing to be in during a long-running process, like mail
sending to a few thousand of your closest friends.

Because of that, this module attempts to keep close track of how the mailing
is doing and give an option to reload a mailing at the time it stopped.
Mailings usually stop because the mailing process itself can be killed by the server
itself.

The create() method does most of the magic in getting a mailing setup. When
called correctly, it will make a temporary directory (usually in B<$TMP > that
holds within it the following files:

=over

=item * The Temporary Subscriber List

To keep the main subscriber list free for adding/editing/removing/viewing
(especially with the Plaintext Backend), a temporary subscriber list is
created for each mailing.

This subscriber list does not just hold the email address of a subscriber, but
other meta information, like the B<pin> associated with the subscriber,
amongst other things.

See the DADA::MailingList::Subscribers::[..]::create_mass_sending_file()

http://dadamailproject.com/support/documentation/MailingList_Subscribers_PlainText.pm.html

method for exactly how this is made.

=item * The Total Amount of Recipients Amount

This file simply holds the total amount of recipients of a given mailing. This
will be different than the amount of subscribers on a list, as the list owner
also will receive a copy of a mailout. There are also some other fringe
reasons for discrepencies, which I won't go into right here.

=item * The Amount Sent Counter

This file will be +1'd everytime an address has been sent to. Note! That this
counter will be added to, regardless of whether the individual email sent was successful.

=item * The, "First Accessed", File

This file just basically holds the time() that a mailout started. 

=item * The, "Last Accessed", File

This file will be updated with what's returned by the time() perl builtin,
every time countsubscriber() is called.

This file is basically used to make sure that a mailing process is still going
on. If the time saved in this file becomes too long, a mailing may become ripe
for a reload().

=item * A Copy of the Message Being Sent Out

A copy of the actual email message source is saved. The message headers can
later be accessed for reporting purposes and the entire message source can be
used if the message has to be reload()ed.

=item * The, "pause button"

This is basically a file that, if present, means that the mailing should be, "paused" - 
mailing should be stopped until it is, "resumed". The file itself will hold the time that 
the mailing was put on pause. 

=back

and a few others, I haven't documented yet. 

=head3 Safeguarding Duplicate Mailings

This all gets quite complicated, fast, but I'm going to highlight just one part of DADA::Mail::MailOut's job, and that is to stop a mailing self-duplicating itself, and sending out two (or more!) copies of the message, to the subscriber, which is bad news. There are a few safety measures: 

=over

=item * The Batch Lock File

The Batch Lock File is somewhat of a semaphore file, I<except> that it doesn't work by having Dada Mail C<flock> the file, it merely works be being B<present>

If the Batch Lock File is B<present>, it tells Dada Mail something is happening. 

=item * The Last Accessed File

The problem with this approach is that, the lock can get stale, so there's another file called the, "Last Access File", which gets update with the last time something happened (usually, done by DADA::Mail::Send while sending out a mass mailing) 

If the Batch Lock file is present, but the Last Access File says that the last time something happened is a while ago, the Batch Lock File gets removed, thus, "unlocking" the mailing, for the mailing to be restarted. 

=item * The PID File

It's a simple system, but it's hard to break - you'd have to manually remove the Batch Lock (which, I can see someone attempting to do) and manually rewind the, "Last Accessed File", to some time in the past. 

If this happens, say because of some bizarre bug in Dada Mail, a  mailing will be reloaded and ther eis a chance that duplicate messages would be sent, 

if not for the PID File. 

The PID file holds the process that, "In Control" of the mass mailing. In Dada ::Mail::Send, when we enter the loop that goes through all the subscribers to mail out a mass, the, "Controlling PID" is set and checked, every time a subscriber is mailed to. If the Controlling PID doesn't match the process that's sending out, the process stops, as another process has taken over.

That above scenario should NEVER HAPPEN, but, if it does, there are safeguards against it. 




=back


=head1 METHODS

=head2 new

Takes one argument - the list shortname, ala: 

    my $mailout = DADA::Mail::MailOut->new({-list => 'listshortname'}); 

All there is to it. 

B<Note!> that a MailOut object is pretty useless, until you call the, B<create()> method. 

=head2 create

Used to setup, or, "create" a mailout. Makes all the temporary files and directories need. Needs a few things passed - do pay attention, since what it needs is slightly odd: 


 $mailout->create(
                    -fields   => {%fields},
                    -list_type => 'list',
                    -mh_obj    => $mh_obj,  
               ); 

=over

=item * -fields

B<-fields> is your actual mailing list message - the fields themselves are the headers of your message. The Body of the message itself is saved in the, B<Body> key/value. 

This is a fairly odd format to have everything in, but it's sort of native to DADA::Mail::Send and that's the module most likely to be calling B<create()>. 

=item * -list_type

List Type holds which subscription sublist you're sending to. Most likely, this is going to be, B<list>. There are times where it may be, B<black_list>, or, B<invitelist>, etc. 

=item * -mh_obj

B<-mh_obj> should actually be a DADA::Mail::Send object - again, very strange thing to pass to this module, but again, B<create> is usually called within DADA::Mail::Send, so that module basically gives a copy of itself to use. 

=back

You'll most likely never call create() yourself, but that's the jist of it. 


=head2 associate

 $mailout->associate($id, $type); 


C<associate> associates an already existing mailing with the object you have on hand - similar to create, but doesn't create anything - it just allows you to work with something you already have. 

It takes two arguments - both of which are B<required>.  Not passing them will cause your program to C<croak>. 

Returns B<1> on success. 

=head2 batch_lock

    $mailout->batch_lock;

Locks a mailout. The presence of a lock prohibits a different process from reloading a mailout that looks as if it is stopped. 

You shouldn't really ever remove a batch lock (although I know this is tempting), as doing so won't explicitly make a mailing restart right away - there are a few things that come in play when it is decided a mailout should be restarted. 

The batch lock itself is just a plain text file. Its contents are the unix C<time> of when the batch was locked. 

Returns, B<1> on success. 

=head2 unlock_batch_lock

    $mailout->unlock_batch_lock;

C<unlinks> (removes) a batch lock. Will return B<1> on success and B<0> upon failure. 

There's a few reasons why this may fail: 

=over

=item * The batch lock was never there

=item * Unlinking the batch lock wasn't successful


=back

=head2 is_batch_locked

    $mailout->is_batch_locked

Looks and see if the batch lock is present. Returns B<1> if it is, B<0> if it isn't. This method does not see if the batch is stale. 


=head2 create_directory

=head2 mailout_directory_name

=head2 create_subscriber_list

=head2 create_total_sending_out_num

=head2 create_counter

=head2 create_first_accessed_file

=head2 create_last_accessed_file

=head2 create_batch_lock

=head2 countsubscriber

=head2 create_raw_message

=head2 _integrity_check


=head2 status

Although you may never call B<create>, calling B<status> may be much more commonplace.

 my $status = $mailout->status; 

or even: 

for(keys %{$mailout->status}){ 
    print $_; # or... something...
}

B<status> returns a hashref of various information about your mailout. Best not to call this too many times at once, as it does query all those temporary files we've created. I'll go over what you're most likely going to use:

=over

=item * id

The internal id of your mailout. This will also be, "similar" to the Message-ID of your mailing, the id of your archived message, etc. 

=item * total_sending_out_num

How many messages you're supposed to be sending out. 

=item * total_sent_out

How many messages you've proported to have sent out. 

=item * last_access

The last time basically, "total_sent_out" was last accessed.

=item * first_access

Basically the time() when we create()d the mailout. 

=item * email_fields

Itself holds a hashref of the actual message you're sending out. Good for making reports. 

=item * type

The type of message you're sending (list, black_list, invitelist, etc)

=item * is_batch_locked

Will tell you if basically, the mailout is active and you shouldn't clobber the mail sending by calling reload(). If you B<do> call reload() when this is set to, "1", the module will croak. So... don't. 

=item * percent_done

Just takes a percentage based on how many message you've sent out, with how many message are still left to send out, rounded to the nearest whole number. Again, good for reports, but don't use to know exactly where you are in your mailing. 

=item * process_has_stalled

Let's you know if it's been a while since something has happened - but DO NOT USE to figure out if you should call reload, use B<should_be_restarted> instead. 

=item * should_be_restarted

Will let you know if a mailout should be reloaded. Basically you can do one of these: 

 my $status = $mailout->status; 
 if($status->{should_be_restarted} == 1){ 
 
    $mailout->reload(); 
 }

=back

=head2 should_be_restarted

=head2 process_has_stalled

=head2 process_stalled_after

=head2 mail_fields_from_raw_message

=head2 _poll

=head2 reload

=head2 counter_at

=head2 message_for_mail_send

=head2 clean_up

=head2 _list_name_check

=head2 _list_exists

=head2 pause

 $mailout->pause; 

Pauses a mailing. Most likely, a mailing will be paused after the current mailing batch is completed, or 
if the mailing has been dropped, the very next time it's attempted to be reloaded. 

When called, a, "pause button" file will be created. 

Returns the time() when it was called for success,

Returns undef if there was some sort of problem pausing a mailing - usually this problem will be because the mailing is already paused. 

=head2 resume

 $mailout->resume; 

The opposite of pause. Removes the, "pause button" file, which will allow the mailout, next time it's checked, to resume mailing. 

Take no arguments. 

Returns 1 on success. 

Return undef if there is some sort of error.

=head1 EXPORTED SUBROUTINES

A few subroutines are exported by default: 

=head2 current_mailouts

 my @mailouts  = DADA::Mail::MailOut::current_mailouts({-list => $list});  

Returns an array of hashrefs that reflect the current mailouts. It can take one parameter, a listshortname. If passed, it will only return mailouts pertaining to that particular list. 

=head2 mailout_exists

 my $exists    = DADA::Mail::MailOut::mailout_exists($list, $id, $type); 

Returns B<1> if a mailout exists, B<0> if it doesn't. The three parameters are B<required>. 

=head2 monitor_mailout

When called, monitor_mailout() will check up on all your mailouts and, if needed, will restart any mailouts that need to be reloaded. 

Returns a string that contains a report of the activity of all the mailouts. 

This subroutine can take a few options, like so: 


 my $report = monitor_mailout({ -list => $list, -verbose => 0}); 

If you pass a listshortname in the, B<-list> parameter, only that specific list's mailouts will be checked. 

If you set the, B<-verbose> parameter to a true value, the subroutine will print the report, as well as pass the report as its return value.


=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS


Please report problems to the author of this module

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2006 - 2011 Justin Simoni All rights reserved. 

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

