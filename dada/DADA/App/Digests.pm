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

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Digests};

my %allowed = ( test => 0, );

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
        warn 'passed -ctime: ' . $args->{-ctime};
        $self->{ctime} = $args->{-ctime}
          if $t;
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
                digest_last_archive_id_sent => $self->ctime_2_archive_time(
                    int( $self->{ctime} ) - int( $self->{ls_obj}->param('digest_schedule') )
                )
            }
        );
        undef( $self->{ls_obj} );
        $self->{ls_obj} = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    }

    $self->{a_obj} = DADA::MailingList::Archives->new( { -list => $self->{list} } );

}

sub should_send_digest {
    my $self = shift;
    if ( scalar @{ $self->archive_ids_for_digest } ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub archive_ids_for_digest {

    my $self = shift;
    my $keys = $self->{a_obj}->get_archive_entries('normal');
    my $ids  = [];

    my $digest_last_archive_id_sent = $self->{ls_obj}->param('digest_last_archive_id_sent') || undef;

    # no archives available? no digest.
    if ( scalar( @{$keys} ) == 0 ) {
        return [];
    }

    for (@$keys) {
        if (   $_ > $digest_last_archive_id_sent
            && $_ < $self->ctime_2_archive_time( $self->{ctime} ) )
        {
            push( @$ids, $_ );
        }
    }
    if ($t) {
        warn 'ids to make digest: ';
        for (@$ids) {
            warn "$_\n";
        }
    }
    return $ids;
}

sub send_digest {

    my $self = shift;

    my $r;

    if ( $self->should_send_digest ) {

        require DADA::App::FormatMessages;
        my $fm = DADA::App::FormatMessages->new( -List => $self->{list} );
        $fm->mass_mailing(1);

        my $entity = $self->create_digest_msg_entity();

        my $msg_as_string = ( defined($entity) ) ? $entity->as_string : undef;
        $msg_as_string = safely_decode($msg_as_string);

        my ( $final_header, $final_body );
        eval { ( $final_header, $final_body ) = $fm->format_headers_and_body( -msg => $msg_as_string ); };

        #        if ($@) {
        #            report_mass_mail_errors( $@, $list, $root_login );
        #            return;
        #        }

        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new(
            {
                -list   => $self->{list},
                -ls_obj => $self->{ls_obj},
            }
        );

        #
        #
        #
        $mh->test( $self->test );
        #
        #
        #
        my %mailing = ( $mh->return_headers($final_header), Body => $final_body, );

        my $message_id;

        $message_id = $mh->mass_send(
            {
                -msg                 => {%mailing},
                -mass_mailing_params => {
                    -delivery_preferences => 'digest',
                },

                #                    -partial_sending => $partial_sending,
                #                    ( $process =~ m/test/i )
                #                    ? (
                #                        -mass_test      => 1,
                #                        -test_recipient => $og_test_recipient,
                #                      )
                #                    : ( -mass_test => 0, )
                #
            }
        );

        # Then, reset the digest, where we left off,

        my $keys = $self->archive_ids_for_digest();

        $self->{ls_obj}->save(
            {
                digest_last_archive_id_sent => $keys->[0],
            }
        );
    }
    else {
        $r .= "\t* No new messages to create a digest message";
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

sub create_digest_msg_entity {

    my $self = shift;
    my $vars = $self->digest_ht_vars;
    require DADA::Template::Widgets;

    my $subject_tmpl = $self->{ls_obj}->param('digest_message_subject');
    my $pt_tmpl      = $self->{ls_obj}->param('digest_message');
    my $html_tmpl    = $self->{ls_obj}->param('digest_message_html');

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
    require MIME::Entity;
    my $entity = MIME::Entity->build(
        Type    => 'multipart/alternative',
        Charset => $self->{ls_obj}->param('charset_value'),
        Subject => $subject_scr,
    );
    $entity->attach(
        Type     => 'text/plain',
        Data     => $pt_scrn,
        Encoding => $self->{ls_obj}->param('plaintext_encoding'),
        Charset  => $self->{ls_obj}->param('charset_value'),
    );
    $entity->attach(
        Type     => 'text/html',
        Data     => $html_scrn,
        Encoding => $self->{ls_obj}->param('html_encoding'),
        Charset  => $self->{ls_obj}->param('charset_value'),
    );

    return $entity;

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

1;
