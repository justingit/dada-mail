package DADA::App::BounceHandler::MessageParser;

use strict;
use lib qw(../../../ ../../../DADA/perllib);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use 5.008_001;

use Carp qw(croak carp);
use vars qw($AUTOLOAD);

my %allowed = ();

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my %args = (@_);
    $self->_init( \%args );
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
    my $args = shift;
}

sub run_all_parses {

    my $self        = shift;
    my ($entity)    = shift;
    my $email       = '';
    my $list        = '';
    my $diagnostics = {};

    $email = find_verp($entity);

    my ( $gp_list, $gp_email, $gp_diagnostics ) = $self->generic_parse($entity);

    $list = $gp_list if $gp_list;
    $email ||= $gp_email;
    $diagnostics = $gp_diagnostics
      if $gp_diagnostics;

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {
        my ( $qmail_list, $qmail_email, $qmail_diagnostics ) =
          $self->parse_for_qmail($entity);
        $list  ||= $qmail_list;
        $email ||= $qmail_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$qmail_diagnostics} )
          if $qmail_diagnostics;
    }

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {

        my ( $exim_list, $exim_email, $exim_diagnostics ) =
          $self->parse_for_exim($entity);
        $list  ||= $exim_list;
        $email ||= $exim_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$exim_diagnostics} )
          if $exim_diagnostics;
    }

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {

        my ( $ms_list, $ms_email, $ms_diagnostics ) =
          $self->parse_for_f__king_exchange($entity);
        $list  ||= $ms_list;
        $email ||= $ms_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$ms_diagnostics} )
          if $ms_diagnostics;
    }
    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {

        my ( $nv_list, $nv_email, $nv_diagnostics ) =
          $self->parse_for_novell($entity);
        $list  ||= $nv_list;
        $email ||= $nv_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$nv_diagnostics} )
          if $nv_diagnostics;
    }

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {

        my ( $g_list, $g_email, $g_diagnostics ) =
          $self->parse_for_gordano($entity);
        $list  ||= $g_list;
        $email ||= $g_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$g_diagnostics} )
          if $g_diagnostics;
    }

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {

        my ( $y_list, $y_email, $y_diagnostics ) =
          $self->parse_for_overquota_yahoo($entity);
        $list  ||= $y_list;
        $email ||= $y_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$y_diagnostics} )
          if $y_diagnostics;
    }

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {

        my ( $el_list, $el_email, $el_diagnostics ) =
          $self->parse_for_earthlink($entity);
        $list  ||= $el_list;
        $email ||= $el_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$el_diagnostics} )
          if $el_diagnostics;
    }

    if ( ( !$list ) || ( !$email ) || !keys %{$diagnostics} ) {
        my ( $wl_list, $wl_email, $wl_diagnostics ) =
          $self->parse_for_windows_live($entity);

        $list  ||= $wl_list;
        $email ||= $wl_email;
        %{$diagnostics} = ( %{$diagnostics}, %{$wl_diagnostics} )
          if $wl_diagnostics;
    }

    # This is a special case - since this outside module adds pseudo diagonistic
    # reports, we'll say, add them if they're NOT already there:

    my ( $bp_list, $bp_email, $bp_diagnostics ) =
      $self->parse_using_m_ds_bp($entity);

    # There's no test for these in the module itself, so we
    # won't even look for them.
    #$list  ||= $bp_list;
    #$email ||= $bp_email;

    %{$diagnostics} = ( %{$bp_diagnostics}, %{$diagnostics} )
      if $bp_diagnostics;

    chomp($email) if $email;

    #small hack, turns, %2 into, '-'
    $list =~ s/\%2d/\-/g;

    $list = $self->strip($list);

    if ( !$diagnostics->{'Message-Id'} ) {
        $diagnostics->{'Message-Id'} =
          $self->find_message_id_in_headers($entity);
        if ( !$diagnostics->{'Message-Id'} ) {
            $diagnostics->{'Message-Id'} =
              $self->find_message_id_in_body($entity);
        }
    }

    if ( $diagnostics->{'Message-Id'} ) {
        $diagnostics->{'Simplified-Message-Id'} = $diagnostics->{'Message-Id'};
        $diagnostics->{'Simplified-Message-Id'} =~ s/\<|\>//g;
        $diagnostics->{'Simplified-Message-Id'} =~ s/\.(.*)//;    #greedy
        $diagnostics->{'Simplified-Message-Id'} =
          strip( $diagnostics->{'Simplified-Message-Id'} );
    }

    return ( $email, $list, $diagnostics );
}

sub find_verp {

    my $self   = shift;
    my $entity = shift;
    my $mv     = Mail::Verp->new;
    $mv->separator($DADA::Config::MAIL_VERP_SEPARATOR);
    if ( $entity->head->count('To') > 0 ) {
        my ( $sender, $recipient ) =
          $mv->decode( $entity->head->get( 'To', 0 ) );
        return $recipient || undef;
    }
    return undef;
}

sub generic_parse {

    my $self   = shift;
    my $entity = shift;
    my ( $email, $list );
    my %return       = ();
    my $headers_diag = {};
    $headers_diag = $self->get_orig_headers($entity);
    my $diag = {};
    ( $email, $diag ) = $self->find_delivery_status($entity);

    if ( keys %$diag ) {
        %return = ( %{$diag}, %{$headers_diag} );
    }
    else {
        %return = %{$headers_diag};
    }

    $list = $self->find_list_in_list_headers($entity);

    $list ||= $self->generic_body_parse_for_list($entity);

    $email = DADA::App::Guts::strip($email);
    $email =~ s/^\<|\>$//g if $email;
    $list = DADA::App::Guts::strip($list) if $list;
    return ( $list, $email, \%return );

}

sub get_orig_headers {

    my $self   = shift;
    my $entity = shift;
    my $diag   = {};

    for ( 'From', 'To', 'Subject' ) {

        if ( $entity->head->count($_) ) {

            my $header = $entity->head->get( $_, 0 );
            chomp $header;
            $diag->{ 'Bounce_' . $_ } = $header;
        }

    }

    return $diag;

}

sub find_delivery_status {

    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;

    my $diag = {};

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'message/delivery-status' ) {
            ( $email, $diag ) = $self->generic_delivery_status_parse($entity);
            return ( $email, $diag );
        }
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $email, $diag ) = $self->find_delivery_status($part);
            if ( ($email) && ( keys %$diag ) ) {
                return ( $email, $diag );
            }
        }
    }
}

sub find_mailer_bounce_headers {

    my $self   = shift;
    my $entity = shift;
    my $mailer = $entity->head->get( 'X-Mailer', 0 );
    $mailer =~ s/\n//g;
    return $mailer if $mailer;

}

sub find_list_in_list_headers {

    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $list;
    if ( $entity->head->mime_type eq 'message/rfc822' ) {
        my $orig_msg_copy = $parts[0];

        my $list_header = $orig_msg_copy->head->get( 'List', 0 );
        $list = $list_header if $list_header !~ /\:/;

        if ( !$list ) {
            my $list_id = $orig_msg_copy->head->get( 'List-ID', 0 );
            if ( $list_id =~ /\<(.*?)\./ ) {
                $list = $1 if $1 !~ /\:/;
            }
        }
        if ( !$list ) {
            my $list_sub = $orig_msg_copy->head->get( 'List-Subscribe', 0 );
            if ( $list_sub =~ /l\=(.*?)\>/ ) {
                $list = $1;
            }
        }
        chomp $list;
        return $list;
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $list = $self->find_list_in_list_headers($part);
            return $list if $list;
        }
    }
}

sub find_message_id_in_headers {

    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $m_id;
    if ( $entity->head->mime_type eq 'message/rfc822' ) {
        my $orig_msg_copy = $parts[0];
        $m_id = $orig_msg_copy->head->get( 'Message-ID', 0 );
        chomp($m_id);
        return $m_id;
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $m_id = $self->find_message_id_in_headers($part);
            return $m_id if $m_id;
        }
    }
}

sub find_message_id_in_body {

    my $self   = shift;
    my $entity = shift;
    my $m_id;

    my @parts = $entity->parts;

    # for singlepart stuff only.
    if ( !@parts ) {

        my $body = $entity->bodyhandle;
        my $IO;

        return undef if !defined($body);

        if ( $IO = $body->open("r") ) {    # "r" for reading.
            while ( defined( $_ = $IO->getline ) ) {
                chomp($_);
                if ( $_ =~ m/^Message\-Id\:(.*?)$/ig ) {

                    #yeah, sometimes the headers are in the body of
                    #an attached message. Go figure.
                    $m_id = $1;
                }
            }
        }

        $IO->close;
        return $m_id;
    }
    else {
        return undef;
    }
}

sub generic_delivery_status_parse {

    my $entity = shift;
    my $diag   = {};
    my $email;

    # sanity check
    #if($delivery_status_entity->head->mime_type eq 'message/delivery-status'){
    my $body = $entity->bodyhandle;
    my @lines;
    my $IO;
    my %bodyfields;
    if ( $IO = $body->open("r") ) {    # "r" for reading.
        while ( defined( $_ = $IO->getline ) ) {
            if ( $_ =~ m/\:/ ) {
                my ( $k, $v ) = split( ':', $_ );
                chomp($v);

                #$bodyfields{$k} = $v;
                $diag->{$k} = $v;
            }
        }
        $IO->close;
    }

    if ( $diag->{'Diagnostic-Code'} =~ /X\-Postfix/ ) {
        $diag->{Guessed_MTA} = 'Postfix';
    }

    my ( $rfc, $remail ) = split( ';', $diag->{'Final-Recipient'} );
    if ( $remail eq '<>' ) {    #example: Final-Recipient: LOCAL;<>
        ( $rfc, $remail ) = split( ';', $diag->{'Original-Recipient'} );
    }
    $email = $remail;

    for ( keys %$diag ) {
        $diag->{$_} = strip( $diag->{$_} );
    }

    return ( $email, $diag );
}

sub generic_body_parse_for_list {

    my $self   = shift;
    my $entity = shift;
    my $list;

    my @parts = $entity->parts;
    if ( !@parts ) {
        $list = $self->find_list_from_unsub_list($entity);
        return $list if $list;
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $list = $self->generic_body_parse_for_list($part);
            if ($list) {
                return $list;
            }
        }
    }
}

sub find_list_from_unsub_list {

    my $entity = shift;
    my $list;

    my $body = $entity->bodyhandle;
    my $IO;

    return undef if !defined($body);

    if ( $IO = $body->open("r") ) {    # "r" for reading.
        while ( defined( $_ = $IO->getline ) ) {
            chomp($_);

# DEV: BUGFIX:
# 2351425 - 3.0.0 - find_list_from_unsub_list sub out-of-date
# https://sourceforge.net/tracker2/?func=detail&aid=2351425&group_id=13002&atid=113002
            if ( $_ =~ m/$DADA::Config::PROGRAM_URL\/(u|list)\/(.*?)\// ) {
                $list = $2;
            }

            # /DEV: BUGFIX
            elsif ( $_ =~ m/^List\:(.*?)$/ ) {

                #yeah, sometimes the headers are in the body of
                #an attached message. Go figure.
                $list = $1;
            }
            elsif ( $_ =~ m/(.*?)\?l\=(.*?)\&f\=u\&e\=/ ) {
                $list = $2;
            }
            elsif ( $_ =~ m/(.*?)\?f\=u\&l\=(.*?)\&e\=/ ) {
                $list = $2;
            }
        }
    }

    $IO->close;
    return $list;
}

sub parse_for_qmail {

    my $self = shift;

# When I'm bored
# => http://cr.yp.to/proto/qsbmf.txt
# => http://mikoto.sapporo.iij.ad.jp/cgi-bin/cvsweb.cgi/fmlsrc/fml/lib/Mail/Bounce/Qmail.pm

    my $entity = shift;
    my ( $email, $list );
    my $diag  = {};
    my @parts = $entity->parts;

    my $state    = 0;
    my $pattern  = 'Hi. This is the';
    my $pattern2 = 'Your message has been enqueued by';

    my $end_pattern  = '--- Undelivered message follows ---';
    my $end_pattern2 = '--- Below this line is a copy of the message.';
    my $end_pattern3 = '--- Enclosed is a copy of the message.';
    my $end_pattern4 = 'Your original message headers are included below.';

    my ( $addr, $reason );

    if ( !@parts ) {
        my $body = $entity->bodyhandle;
        my $IO;
        if ($body) {
            if ( $IO = $body->open("r") ) {    # "r" for reading.
                while ( defined( $_ = $IO->getline ) ) {

                    my $data = $_;
                    $state = 1 if $data =~ /$pattern|$pattern2/;
                    $state = 0
                      if $data =~ /$end_pattern|$end_pattern2|$end_pattern3/;

                    if ( $state == 1 ) {
                        $data =~ s/\n/ /g;

                        if ( $data =~ /\t(\S+\@\S+)/ ) {
                            $email = $1;
                        }
                        elsif ( $data =~ /\<(\S+\@\S+)\>:\s*(.*)/ ) {
                            ( $addr, $reason ) = ( $1, $2 );
                            $diag->{Action} = $reason;
                            my $status = '5.x.y';
                            if ( $data =~ /\#(\d+\.\d+\.\d+)/ ) {
                                $status = $1;
                            }
                            elsif ( $data =~ /\s+(\d{3})\s+/ ) {
                                my $code = $1;
                                $status = '5.x.y' if $code =~ /^5/;
                                $status = '4.x.y' if $code =~ /^4/;

                                $diag->{Status} = $status;
                                $diag->{Action} = $code;

                            }

                            $email = $addr;
                            $diag->{Guessed_MTA} = 'Qmail';

                        }
                        elsif ( $data =~ /(.*)\s\(\#(\d+\.\d+\.\d+)\)/ )
                        { # Recipient's mailbox is full, message returned to sender. (#5.2.2)

                            $diag->{'Diagnostic-Code'} = $1;
                            $diag->{Status}            = $2;
                            $diag->{Guessed_MTA}       = 'Qmail';

                        }
                        elsif ( $data =~
/Remote host said:\s(\d{3})\s(\d+\.\d+\.\d+)\s\<(\S+\@\S+)\>(.*)/
                          )
                        { # Remote host said: 550 5.1.1 <xxx@xxx>... Account is over quota. Please try again later..[EOF]

                            $diag->{Status}            = $2;
                            $email                     = $3;
                            $diag->{'Diagnostic-Code'} = $4;
                            $diag->{Action} = 'failed'; #munging this for now...
                            $diag->{'Final-Recipient'} =
                              'rfc822';                 #munging, again.

                        }
                        elsif ( $data =~
                            /Remote host said:\s(.*?)\s(\S+\@\S+)\s(.*)/ )
                        {

                            my $status;
                            $email ||= $2;

                            $status ||= $1;
                            $diag->{Status} ||= '5.x.y' if $status =~ /^5/;
                            $diag->{Status} ||= '4.x.y' if $status =~ /^4/;
                            $diag->{'Diagnostic-Code'} = $data;
                            $diag->{Guessed_MTA} = 'Qmail';

                        }
                        elsif ( $data =~ /Remote host said:\s(\d{3}.*)/ ) {

                            $diag->{'Diagnostic-Code'} = $1;
                        }
                        elsif ( $data =~ /\d{3}(\-|\s)\d+\.\d+\.\d+/ )
                        {    #550-5.1.1 550 5.1.1
                            if ( !exists( $diag->{'Diagnostic-Code'} ) ) {
                                $diag->{'Diagnostic-Code'} = '';
                            }
                            $diag->{'Diagnostic-Code'} .= $data;
                        }
                        elsif ( $data =~ /(.*)\s\(\#(\d+\.\d+\.\d+)\)/ ) {

                            $diag->{'Diagnostic-Code'} = $1;
                            $diag->{Status} = $2;

                        }
                        elsif ( $data =~ /(No User By That Name)/ ) {

                            $diag->{'Diagnostic-Code'} = $data;
                            $diag->{Status} = '5.x.y';

                        }
                        elsif (
                            $data =~ /(This address no longer accepts mail)/ )
                        {

                            $diag->{'Diagnostic-Code'} = $data;

                        }
                        elsif ( $data =~
                            /The mail system will continue delivery attempts/ )
                        {
                            $diag->{Guessed_MTA} = 'Qmail';
                            $diag->{'Diagnostic-Code'} = $data;
                        }
                    }
                }
            }

            $list ||= $self->generic_body_parse_for_list($entity);
            return ( $list, $email, $diag );
        }
        else {

            # no body part to parse
            return ( undef, undef, {} );
        }
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_qmail($part);
            if ( ($email) && ( keys %$diag ) ) {
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_exim {

    my $self   = shift;
    my $entity = shift;
    my ( $email, $list );
    my $diag = {};

    my @parts = $entity->parts;
    if ( !@parts ) {
        if ( $entity->head->mime_type =~ /text/ ) {

            # Yeah real hard. Bring it onnnn!
            if ( $entity->head->get( 'X-Failed-Recipients', 0 ) ) {

                $email = $entity->head->get( 'X-Failed-Recipients', 0 );
                $email =~ s/\n//;
                $email          = strip($email);
                $list           = $self->generic_body_parse_for_list($entity);
                $diag->{Status} = '5.x.y';
                $diag->{Guessed_MTA} = 'Exim';
                return ( $list, $email, $diag );

            }
            else {

                my $body = $entity->bodyhandle;
                my $IO;
                if ($body) {

                    if ( $IO = $body->open("r") ) {    # "r" for reading.

                        my $pattern =
'This message was created automatically by mail delivery software (Exim).';
                        my $end_pattern =
                          '------ This is a copy of the message';
                        my $state = 0;

                        while ( defined( $_ = $IO->getline ) ) {

                            my $data = $_;

                            $state = 1 if $data =~ /\Q$pattern/;
                            $state = 0 if $data =~ /$end_pattern/;

                            if ( $state == 1 ) {

                                $diag->{Guessed_MTA} = 'Exim';

                                if ( $data =~ /(\S+\@\S+)/ ) {

                                    $email = $1;
                                    $email = strip($email);

                                }
                                elsif ( $data =~ m/unknown local-part/ ) {

                                    $diag->{'Diagnostic-Code'} =
                                      'unknown local-part';
                                    $diag->{'Status'} = '5.x.y';

                                }
                            }
                        }
                    }
                }
                return ( $list, $email, $diag );
            }
        }
        else {
            return ( undef, undef, {} );
        }
    }
    else {

        # no body part to parse
        return ( undef, undef, {} );
    }
}

sub parse_for_f__king_exchange {
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = 'Your message';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        if ( $state == 1 ) {
                            $data =~ s/\n/ /g;
                            if ( $data =~ /\s{2}To:\s{6}(\S+\@\S+)/ ) {
                                $email = $1;
                            }
                            elsif ( $data =~
                                /(MSEXCH)(.*?)(Unknown\sRecipient|Unknown|)/ )
                            {                      # I know, not perfect.
                                $diag->{Guessed_MTA} = 'Exchange';
                                $diag->{'Diagnostic-Code'} =
                                  'Unknown Recipient';
                            }
                            else {

                                #...
                                #warn "nope: " . $data;
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_f__king_exchange($part);
            if ( ($email) && ( keys %$diag ) ) {
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_novell {    #like, really...
    my $self   = shift;
    my $entity = shift;

    my @parts = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = qr/(A|The) message that you sent/;
    my $end_pattern =
      quotemeta('--- The header of the original message is following. ---');

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ m/$pattern/;
                        $state = 0 if $data =~ m/$end_pattern/;
                        if ( $state == 1 ) {

                            $data =~ s/\n/ /g;

                            if ( $data =~ /\s+(\S+\@\S+)\s\((.*?)\)/ ) {
                                $email = $1;

                                $diag->{'Diagnostic-Code'} = $2;
                            }
                            elsif ( $data =~ m/\<+(\S+\@\S+)\>+/ ) {
                                $email = $1;

                            }
                            else {

                                #...
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {

        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_novell($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_gordano {    # what... ever that is there...
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state = 0;

    my $pattern     = 'Your message to';
    my $end_pattern = 'The message headers';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        $state = 0 if $data =~ /$end_pattern/;
                        if ( $state == 1 ) {
                            $data =~ s/\n/ /g;
                            if ( $data =~ /RCPT To:\<(\S+\@\S+)\>/ )
                            {                      #    RCPT To:<xxx@usnews.com>
                                $email = $1;
                            }
                            elsif ( $data =~ /(.*?)\s(\d+\.\d+\.\d+)\s(.*)/ )
                            {    # 550 5.1.1 No such mail drop defined.
                                $diag->{Status}            = $2;
                                $diag->{'Diagnostic-Code'} = $3;
                                $diag->{'Final-Recipient'} = 'rfc822';   #munge;
                                $diag->{Action}            = 'failed';   #munge;
                            }
                            else {

                                #...
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_gordano($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_overquota_yahoo {
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = 'Message from  yahoo.com.';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        $diag->{'Remote-MTA'} = 'yahoo.com';

                        if ( $state == 1 ) {
                            $data =~ s/\n/ /g;     #what's up with that?
                            if ( $data =~ /\<(\S+\@\S+)\>\:/ ) {
                                $email = $1;
                            }
                            else {
                                if ( $data =~ m/(over quota)/ ) {
                                    $diag->{'Diagnostic-Code'} = $data;
                                }
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {

        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_overquota_yahoo($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_earthlink {
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = 'Sorry, unable to deliver your message to';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        if ( $state == 1 ) {
                            $diag->{'Remote-MTA'} = 'Earthlink';
                            $data =~ s/\n/ /g;     #what's up with that?
                            if ( $data =~ /(\d{3})\s(.*?)\s(\S+\@\S+)/ )
                            {  #  552 Quota violation for postmaster@example.com
                                $diag->{'Diagnostic-Code'} = $1 . ' ' . $2;
                                $email = $3;
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {

        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_earthlink($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_windows_live {
    my $self   = shift;
    my $entity = shift;

    #
    my $email;
    my $diag = {};
    my $list;
    my $state = 0;

    if ( defined($entity) ) {
        my @parts = $entity->parts;
        if ( $parts[0] ) {
            my @parts0 = $parts[0]->parts;
            if ( $parts0[0] ) {
                if ( $parts0[0]->head->count('X-HmXmrOriginalRecipient') ) {
                    $email =
                      $parts0[0]->head->get( 'X-HmXmrOriginalRecipient', 0 );
                    $diag->{'Remote-MTA'} = 'Windows_Live';
                    return ( $list, $email, $diag );
                }
            }
        }
    }

}

sub parse_using_m_ds_bp {

    my $self = shift;
    eval { require Mail::DeliveryStatus::BounceParser; };

    return ( undef, undef, {} ) if $@;

    # else, let's get to work;

    my $entity  = shift;
    my $message = $entity->as_string;

    my $bounce = eval { Mail::DeliveryStatus::BounceParser->new($message); };

    if ($@) {

        # couldn't parse.
        return ( undef, undef, {} ) if $@;
    }

  # examples:
  # my @addresses       = $bounce->addresses;       # email address strings
  # my @reports         = $bounce->reports;         # Mail::Header objects
  # my $orig_message_id = $bounce->orig_message_id; # <ABCD.1234@mx.example.com>
  # my $orig_message    = $bounce->orig_message;    # Mail::Internet object

    return ( undef, undef, {} )
      if $bounce->is_bounce != 1;

    my ($report) = $bounce->reports;

    return ( undef, undef, {} )
      if !defined $report;

    my $diag = {};

    $diag->{'Message-Id'} = $report->get('orig_message_id')
      if $report->get('orig_message_id');

    $diag->{Action} = $report->get('action')
      if $report->get('action');

    $diag->{Status} = $report->get('status')
      if $report->get('status');

    $diag->{'Diagnostic-Code'} = $report->get('diagnostic-code')
      if $report->get('diagnostic-code');

    $diag->{'Final-Recipient'} = $report->get('final-recipient')
      if $report->get('final-recipient');

# these aren't used particularily in Dada Mail, but let's play around with them...

    $diag->{std_reason} = $report->get('std_reason')
      if $report->get('std_reason');

    $diag->{reason} = $report->get('reason')
      if $report->get('reason');

    $diag->{host} = $report->get('host')
      if $report->get('host');

    $diag->{smtp_code} = $report->get('smtp_code')
      if $report->get('smtp_code');

    my $email = $report->get('email') || undef;

    return ( undef, $email, $diag );

}

1;
