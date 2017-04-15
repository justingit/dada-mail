package Mail::DeliveryStatus::BounceParser;

=head1 NAME

Mail::DeliveryStatus::BounceParser - Perl extension to analyze bounce messages

=head1 SYNOPSIS

  use Mail::DeliveryStatus::BounceParser;

  # $message is \*io or $fh or "entire\nmessage" or \@lines
  my $bounce = eval { Mail::DeliveryStatus::BounceParser->new($message); };

  if ($@) {
    # couldn't parse.
  }

  my @addresses       = $bounce->addresses;       # email address strings
  my @reports         = $bounce->reports;         # Mail::Header objects
  my $orig_message_id = $bounce->orig_message_id; # <ABCD.1234@mx.example.com>
  my $orig_message    = $bounce->orig_message;    # Mail::Internet object

=head1 ABSTRACT

Mail::DeliveryStatus::BounceParser analyzes RFC822 bounce messages and returns
a structured description of the addresses that bounced and the reason they
bounced; it also returns information about the original returned message
including the Message-ID.  It works best with RFC1892 delivery reports, but
will gamely attempt to understand any bounce message no matter what MTA
generated it.

=head1 DESCRIPTION

Meng Wong wrote this for the Listbox v2 project; good mailing list managers
handle bounce messages so listowners don't have to.  The best mailing list
managers figure out exactly what is going on with each subscriber so the
appropriate action can be taken.

=cut

use 5.006;
use strict;
use warnings;

our $VERSION = '1.527';
$VERSION = eval $VERSION;

use MIME::Parser;
use Mail::DeliveryStatus::Report;
use vars qw($EMAIL_ADDR_REGEX);

$EMAIL_ADDR_REGEX = qr{
# Avoid using something like Email::Valid
# Full rfc(2)822 compliance isn't exactly what we want, and this seems to work
# for most real world cases
(?:<|^|\s)            # Space, or the start of a string
([^\s\/<]+            # some non-space, non-/ characters; none are <
\@                    # at sign (duh)
(?:[-\w]+\.)+[-\w]+)  # word characters or hypens organized into
                      # at least two dot-separated words
(?:$|\s|>)            # then the end
}sx;

my $Not_An_Error = qr/
    \b delayed \b
  | \b warning \b
  | transient.{0,20}\serror
  | Your \s message .{0,100} was \s delivered \s to \s the \s following \s recipient
/six;

# added "permanent fatal errors" - fix for bug #41874
my $Really_An_Error = qr/this is a permanent error|permanent fatal errors/i;

my $Returned_Message_Below = qr/(
    (?:original|returned) \s message \s (?:follows|below)
  | (?: this \s is \s a \s copy \s of
      | below \s this \s line \s is \s a \s copy
    ) .{0,100} \s message\.?
  | message \s header \s follows
  | ^ (?:return-path|received|from):
)\s+/sixm;

my @Preprocessors = qw(
  p_ims
  p_aol_senderblock
  p_novell_groupwise
  p_plain_smtp_transcript
  p_xdelivery_status
);

=head2 parse

  my $bounce = Mail::DeliveryStatus::BounceParser->parse($message, \%arg);

OPTIONS.  If you pass BounceParser->new(..., {log=>sub { ... }}) That will be
used as a logging callback.

NON-BOUNCES.  If the message is recognizably a vacation autoresponse, or is a
report of a transient nonfatal error, or a spam or virus autoresponse, you'll
still get back a C<$bounce>, but its C<< $bounce->is_bounce() >> will return
false.

It is possible that some bounces are not really bounces; such as
anything that apears to have a 2XX status code.  To include such
non-bounces in the reports, pass the option {report_non_bounces=>1}.

For historical reasons, C<new> is an alias for the C<parse> method.

=cut

sub parse {
  my ($class, $data, $arg) = @_;
  # my $bounce = Mail::DeliveryStatus::BounceParser->new( \*STDIN | $fh |
  # "entire\nmessage" | ["array","of","lines"] );

  my $parser = MIME::Parser->new;
     $parser->output_to_core(1);
     $parser->decode_headers(1);

  my $message;

  if (not $data) {
    print STDERR "BounceParser: expecting bounce mesage on STDIN\n" if -t STDIN;
    $message = $parser->parse(\*STDIN);
  } elsif (not ref $data)        {
    $message = $parser->parse_data($data);
  } elsif (ref $data eq "ARRAY") {
    $message = $parser->parse_data($data);
  } else {
    $message = $parser->parse($data);
  }

  my $self = bless {
    reports   => [],
    is_bounce => 1,
    log       => $arg->{log},
    parser    => $parser,
    orig_message_id => undef,
    prefer_final_recipient => $arg->{prefer_final_recipient},
  }, $class;

  $self->log(
    "received message with type "
    . (defined($message->effective_type) ? $message->effective_type : "undef")
    . ", subject "
    . (defined($message->head->get("subject")) ? $message->head->get("subject") : "CAN'T GET SUBJECT")
  );

  # before we even start to analyze the bounce, we recognize certain special
  # cases, and rewrite them to be intelligible to us
  foreach my $preprocessor (@Preprocessors) {
    if (my $newmessage = $self->$preprocessor($message)) {
      $message = $newmessage;
    }
  }

  $self->{message} = $message;

  $self->log(
    "now the message is type "
    . $message->effective_type
    . ", subject "
    . (defined($message->head->get("subject")) ? $message->head->get("subject") : "CAN'T GET SUBJECT")
  );

  my $first_part = _first_non_multi_part($message);

  # Deal with some common C/R systems like TMDA
  {
    last unless ($message->head->get("x-delivery-agent")
     and $message->head->get("X-Delivery-Agent") =~ /^TMDA/);
    $self->log("looks like a challenge/response autoresponse; ignoring.");
    $self->{type} = "Challenge / Response system autoreply";
    $self->{is_bounce} = 0;
    return $self;
  }

  {
    last unless ($message->head->get("X-Bluebottle-Request") and $first_part->stringify_body =~ /This account is protected by Bluebottle/);
    $self->log("looks like a challenge/response autoresponse; ignoring.");
    $self->{type} = "Challenge / Response system autoreply";
    $self->{is_bounce} = 0;
    return $self;
  }

  {
    last unless defined $first_part and $first_part->stringify_body =~ /Your server requires confirmation/;
    $self->log("Looks like a challenge/response autoresponse; ignoring.");
    $self->{type} = "Challenge / Response system autoreply";
    $self->{is_bounce} = 0;
    return $self;
  }

  {
    last unless defined $first_part and $first_part->stringify_body =~ /Please add yourself to my Boxbe Guest List/;
	$self->log("Looks like a challenge/response autoresponse; ignoring.");
	$self->{type} = "Challenge / Response system autoreply";
	$self->{is_bounce} = 0;
  }

  {
    last unless defined $first_part and $first_part->stringify_body =~ /This\s+is\s+a\s+one-time\s+automated\s+message\s+to\s+confirm\s+that\s+you're\s+listed\s+on\s+my\s+Boxbe\s+Guest\s+List/;
	$self->log("Looks like a challenge/response autoresponse; ignoring.");
	$self->{type} = "Challenge / Response system autoreply";
	$self->{is_bounce} = 0;
  }

  # we'll deem autoreplies to be usually less than a certain size.

  # Some vacation autoreplies are (sigh) multipart/mixed, with an additional
  # part containing a pointless disclaimer; some are multipart/alternative,
  # with a pointless HTML part saying the exact same thing.  (Messages in
  # this latter category have the decency to self-identify with things like
  # '<META NAME="Generator" CONTENT="MS Exchange Server version
  # 5.5.2653.12">', so we know to avoid such software in future.)  So look
  # at the first part of a multipart message (recursively, down the tree).

  {
    last if $message->effective_type eq 'multipart/report';
    last if !$first_part || $first_part->effective_type ne 'text/plain';
    my $string = $first_part->as_string;
    last if length($string) > 3000;
    # added return receipt (fix for bug #41870)
    last if $string !~ /auto.{0,20}(reply|response)|return receipt|vacation|(out|away|on holiday).*office/i;
    $self->log("looks like a vacation autoreply, ignoring.");
    $self->{type} = "vacation autoreply";
    $self->{is_bounce} = 0;
    return $self;
  }

  # vacation autoreply tagged in the subject
  {
    last if $message->effective_type eq 'multipart/report';
    last if !$first_part || $first_part->effective_type ne 'text/plain';
    my $subject = $message->head->get('Subject');
    last if !defined($subject);
    last if $subject !~ /^AUTO/;
    last if $subject !~ /is out of the office/;
    $self->log("looks like a vacation autoreply, ignoring.");
    $self->{type} = "vacation autoreply";
    $self->{is_bounce} = 0;
    return $self;
  }

  # Polish auto-reply
  {
    last if $message->effective_type eq 'multipart/report';
    last if !$first_part || $first_part->effective_type ne 'text/plain';
    my $subject = $message->head->get('Subject');
    last if !defined($subject);
    last if $subject !~ /Automatyczna\s+odpowied/;
    $self->log("looks like a polish autoreply, ignoring.");
    $self->{type} = "polish autoreply";
    $self->{is_bounce} = 0;
    return $self;
  }

  # "Email address changed but your message has been forwarded"
  {
    last if $message->effective_type eq 'multipart/report';
    last if !$first_part || $first_part->effective_type ne 'text/plain';
    my $string = $first_part->as_string;
    last if length($string) > 3000;
    last if $string
      !~ /(address .{0,60} changed | domain .{0,40} retired) .*
          (has\s*been|was|have|will\s*be) \s* (forwarded|delivered)/six;
    $self->log('looks like an address-change autoreply, ignoring');
    $self->{type} = 'informational address-change autoreply';
    $self->{is_bounce} = 0;
    return $self;
  }

  # Network Associates WebShield SMTP V4.5 MR1a on cpwebshield intercepted a
  # mail from <owner-aftermba@v2.listbox.com> which caused the Content Filter
  # Block extension COM to be triggered.
  if ($message->effective_type eq "text/plain"
      and (length $message->as_string) < 3000
      and $message->bodyhandle->as_string
        =~ m/norton\sassociates\swebshield|content\s+filter/ix
  ) {
    $self->log("looks like a virus/spam block, ignoring.");
    $self->{type} = "virus/spam false positive";
    $self->{is_bounce} = 0;
    return $self;
  }

  # nonfatal errors usually say they're transient

  if ($message->effective_type eq "text/plain"
    and $message->bodyhandle->as_string =~ /transient.*error/is) {
    $self->log("seems like a nonfatal error, ignoring.");
    $self->{is_bounce} = 0;
    return $self;
  }

  # nonfatal errors usually say they're transient, but sometimes they do it
  # straight out and sometimes it's wrapped in a multipart/report.
  #
  # Be careful not to examine a returned body for the transient-only signature:
  # $Not_An_Error can match the single words 'delayed' and 'warning', which
  # could quite reasonably occur in the body of the returned message.  This
  # also means it's worth additionally checking for a regex that gives a very
  # strong indication that the error was permanent.
  {
    my $part_for_maybe_transient;
    $part_for_maybe_transient = $message
      if $message->effective_type eq "text/plain";
    ($part_for_maybe_transient)
      = grep { $_->effective_type eq "text/plain" } $message->parts
        if $message->effective_type =~ /multipart/
           && $message->effective_type ne 'multipart/report';

    if ($part_for_maybe_transient) {
      my $string = $part_for_maybe_transient->bodyhandle->as_string;
      my $transient_pos = _match_position($string, $Not_An_Error);
      last unless defined $transient_pos;
      my $permanent_pos = _match_position($string, $Really_An_Error);
      my $orig_msg_pos  = _match_position($string, $Returned_Message_Below);
      last if _position_before($permanent_pos, $orig_msg_pos);
      if (_position_before($transient_pos, $orig_msg_pos)) {
        $self->log("transient error, ignoring.");
        $self->{is_bounce} = 0;
        return $self;
      }
    }
  }

  # In all cases we will read the message body to try to pull out a message-id.
  if ($message->effective_type =~ /multipart/) {
    # "Internet Mail Service" sends multipart/mixed which still has a
    # message/rfc822 in it
    if (
      my ($orig_message) =
        grep { $_->effective_type eq "message/rfc822" } $message->parts
    ) {
      # see MIME::Entity regarding REPLACE
      my $orig_message_id = $orig_message->parts(0)->head->get("message-id");
      if ($orig_message_id) {
		$orig_message_id =~ s/(\r|\n)*$//g;
        $self->log("extracted original message-id [$orig_message_id] from the original rfc822/message");
      } else {
        $self->log("Couldn't extract original message-id from the original rfc822/message");
      }
      $self->{orig_message_id} = $orig_message_id;
      $self->{orig_message} = $orig_message->parts(0);
    }

    # todo: handle pennwomen-la@v2.listbox.com/200209/19/1032468832.1444_1.frodo
    # which is a multipart/mixed containing an application/tnef instead of a
    # message/rfc822.  yow!

    if (! $self->{orig_message_id}
      and
      my ($rfc822_headers) =
         grep { lc $_->effective_type eq "text/rfc822-headers" } $message->parts
    ) {
      my $orig_head = Mail::Header->new($rfc822_headers->body);
      my $message_id = $orig_head->get("message-id");
      if ($message_id) {
        chomp ($self->{orig_message_id} = $orig_head->get("message-id"));
        $self->{orig_header} = $orig_head;
        $self->log("extracted original message-id $self->{orig_message_id} from text/rfc822-headers");
      }
    }
  }

  if (! $self->{orig_message_id}) {
    if ($message->bodyhandle and $message->bodyhandle->as_string =~ /Message-ID: (\S+)/i) {
      $self->{orig_message_id} = $1;
      $self->log("found a message-id $self->{orig_message_id} in the body.");
    }
  }

  if (! $self->{orig_message_id}) {
    $self->log("couldn't find original message id.");
  }

  #
  # try to extract email addresses to identify members.
  # we will also try to extract reasons as much as we can.
  #

  if ($message->effective_type eq "multipart/report") {
    my ($delivery_status) =
      grep { $_->effective_type eq "message/delivery-status" } $message->parts;

    my %global = ("reporting-mta" => undef, "arrival-date"  => undef);

    my ($seen_action_expanded, $seen_action_failed);

    # Some MTAs generate malformed multipart/report messages with no
    # message/delivery-status part; don't die in such cases.
    my $delivery_status_body
      = eval { $delivery_status->bodyhandle->as_string } || '';

    # Used to be \n\n, but now we allow any number of newlines between
    # individual per-recipient fields to deal with stupid bug with the IIS SMTP
    # service.  RFC1894 (2.1, 2.3) is not 100% clear about whether more than
    # one line is allowed - it just says "preceded by a blank line".  We very
    # well may put an upper bound on this in the future.
    #
    # See t/iis-multiple-bounce.t
    foreach my $para (split /\n{2,}/, $delivery_status_body) {

      # See t/surfcontrol-extra-newline.t - deal with bug #21249
      $para =~ s/\A\n+//g;
      # added the following line as part of fix for #41874
      $para =~ s/\r/ /g;

      my $report = Mail::Header->new([split /\n/, $para]);

      # Removed a $report->combine here - doesn't seem to work without a tag
      # anyway... not sure what that was for. - wby 20060823

      # Unfold so message doesn't wrap over multiple lines
      $report->unfold;

      # Some MTAs send unsought delivery-status notifications indicating
      # success; others send RFC1892/RFC3464 delivery status notifications
      # for transient failures.
      if (defined $report->get('Action') and lc $report->get('Action')) {
		my $action = lc $report->get('Action');
        $action =~ s/^\s+//;
        if ($action =~ s/^\s*([a-z]+)\b.*/$1/s) {
          # In general, assume that anything other than 'failed' is a
          # non-bounce; but 'expanded' is handled after the end of this
          # foreach loop, because it might be followed by another
          # per-recipient group that says 'failed'.
          if ($action eq 'expanded') {
            $seen_action_expanded = 1;
          } elsif ($action eq 'failed') {
            $seen_action_failed   = 1;
          } else {
            $self->log("message/delivery-status says 'Action: \L$1'");
            $self->{type} = 'delivery-status \L$1';
            $self->{is_bounce} = 0;
            return $self;
          }
        }
      }

      for my $hdr (qw(Reporting-MTA Arrival-Date)) {
        my $val = $global{$hdr} ||= $report->get($hdr);
        if (defined($val)) {
          $report->replace($hdr => $val)
        }
      }

      my $email;

      if ($self->{prefer_final_recipient}) {
        $email = $report->get("final-recipient")
              || $report->get("original-recipient");
      } else {
        $email = $report->get("original-recipient")
              || $report->get("final-recipient");
      }

      next unless $email;

      # $self->log("email = \"$email\"") if $DEBUG > 3;

      # Diagnostic-Code: smtp; 550 5.1.1 User unknown
      my $reason = $report->get("diagnostic-code");

      $email  =~ s/[^;]+;\s*//; # strip leading RFC822; or LOCAL; or system;
      if (defined $reason) {
        $reason =~ s/[^;]+;\s*//; # strip leading X-Postfix;
      }

      $email = _cleanup_email($email);

      $report->replace(email      => $email);
      if (defined $reason) {
        $report->replace(reason     => $reason);
      } else {
        $report->delete("reason");
      }

      if (my $status = $report->get('Status')) {
        # RFC 1893... prefer Status: if it exists and is something we know
        # about
        # Not 100% sure about 5.1.0...
        if ($status =~ /^5\.1\.[01]$/)  {
          $report->replace(std_reason => "user_unknown");
        } elsif ($status eq "5.1.2") {
          $report->replace(std_reason => "domain_error");
        } elsif ($status eq "5.2.2") {
          $report->replace(std_reason => "over_quota");
          # this fits my reading of RFC 3463
          # FIXME: I suspect there's something wrong with the parsing earlier
          # that this has to be a regexp rather than a straight comparison
        } elsif ($status =~ /^5\.4\.4/) {
          $report->replace(std_reason => "domain_error");
        } else {
          $report->replace(
            std_reason => _std_reason($report->get("diagnostic-code"))
          );
        }
      } else {
        $report->replace(
          std_reason => _std_reason($report->get("diagnostic-code"))
        );
      }
      my $diag_code = $report->get("diagnostic-code");

      my $host;
      if (defined $diag_code) {
        ($host) = $diag_code =~ /\bhost\s+(\S+)/;
      }

      $report->replace(host => ($host)) if $host;

      my ($code);

      if (defined $diag_code) {
        ($code) = $diag_code =~
         m/ ( ( [245] \d{2} ) \s | \s ( [245] \d{2} ) (?!\.) ) /x;
      }

      if ($code) {
        $report->replace(smtp_code => $code);
      }

      if (not $report->get("host")) {
        my $email = $report->get("email");
        if (defined $email) {
          my $host = ($email =~ /\@(.+)/)[0];
          $report->replace(host => $host) if $host;
        }
      }

      if ($report->get("smtp_code") and ($report->get("smtp_code") =~ /^2../)) {
        $self->log(
          "smtp code is "
          . $report->get("smtp_code")
          . "; no_problemo."
        );

      }

      unless ($arg->{report_non_bounces}) {
        if ($report->get("std_reason") eq "no_problemo") {
          $self->log(
            "not actually a bounce: " . $report->get("diagnostic-code")
          );
          next;
        }
      }

      push @{$self->{reports}},
        Mail::DeliveryStatus::Report->new([ split /\n/, $report->as_string ]
      );
    }

    if ($seen_action_expanded && !$seen_action_failed) {
      # We've seen at least one 'Action: expanded' DSN-field, but no
      # 'Action: failed'
      $self->log(q[message/delivery-status says 'Action: expanded']);
      $self->{type} = 'delivery-status expanded';
      $self->{is_bounce} = 0;
      return $self;
    }

  } elsif ($message->effective_type =~ /multipart/) {
    # but not a multipart/report.  look through each non-message/* section.
    # See t/corpus/exchange.unknown.msg

    my @delivery_status_parts = grep { $_->effective_type =~ m{text/plain}
      and not $_->is_multipart
    } $message->parts;

    # $self->log("error parts: @{[ map { $_->bodyhandle->as_string }
    # @delivery_status_parts ]}") if $DEBUG > 3;

    push @{$self->{reports}}, $self->_extract_reports(@delivery_status_parts);

  } elsif ($message->effective_type =~ m{text/plain}) {
    # handle plain-text responses

    # This used to just take *any* part, even if the only part wasn't a
    # text/plain part
    #
    # We may have to specifically allow some other types, but in my testing, all
    # the messages that get here and are actual bounces are text/plain
    # wby - 20060907
    
    # they usually say "returned message" somewhere, and we can split on that,
    # above and below.
    my $body_string = $message->bodyhandle->as_string || '';

    if ($body_string =~ $Returned_Message_Below) {
      my ($stuff_before, $stuff_splitted, $stuff_after) =
        split $Returned_Message_Below, $message->bodyhandle->as_string, 2;
      # $self->log("splitting on \"$stuff_splitted\", " . length($stuff_before)
      # . " vs " . length($stuff_after) . " bytes.") if $DEBUG > 3;
      push @{$self->{reports}}, $self->_extract_reports($stuff_before);
      $self->{orig_text} = $stuff_after;
    } elsif ($body_string =~ /(.+)\n\n(.+?Message-ID:.+)/is) {
      push @{$self->{reports}}, $self->_extract_reports($1);
      $self->{orig_text} = $2;
    } else {
      push @{$self->{reports}}, $self->_extract_reports($body_string);
      $self->{orig_text} = $body_string;
    }
  }
  return $self;
}

BEGIN { *new = \&parse };

=head2 log

  $bounce->log($messages);

If a logging callback has been given, the message will be passed to it.

=cut

sub log {
  my ($self, @log) = @_;
  if (ref $self->{log} eq "CODE") {
    $self->{log}->(@_);
  }
  return 1;
}

sub _extract_reports {
  my $self = shift;
  # input: either a list of MIME parts, or just a chunk of text.

  if (@_ > 1) { return map { _extract_reports($_) } @_ }

  my $text = shift;

  $text = $text->bodyhandle->as_string if ref $text;

  my %by_email;

  # we'll assume that the text is made up of:
  # blah blah 0
  #             email@address 1
  # blah blah 1
  #             email@address 2
  # blah blah 2
  #

  # we'll break it up accordingly, and first try to detect a reason for email 1
  # in section 1; if there's no reason returned, we'll look in section 0.  and
  # we'll keep going that way for each address.

  return unless $text;
  my @split = split($EMAIL_ADDR_REGEX, $text);

  foreach my $i (0 .. $#split) {
    # only interested in the odd numbered elements, which are the email
    # addressess.
    next if $i % 2 == 0;

    my $email = _cleanup_email($split[$i]);

    if ($split[$i-1] =~ /they are not accepting mail from/) {
      # aol airmail sender block
      next;
    }

    if($split[$i-1] =~ /A message sent by/) {
      # sender block
      next;
    }

    my $std_reason = "unknown";
    $std_reason = _std_reason($split[$i+1]) if $#split > $i;
    $std_reason = _std_reason($split[$i-1]) if $std_reason eq "unknown";

    # todo:
    # if we can't figure out the reason, if we're in the delivery-status part,
    # go back up into the text part and try extract_report() on that.

    next if (
      exists $by_email{$email}
      and $by_email{$email}->{std_reason}
      ne "unknown" and $std_reason eq "unknown"
    );

    my $reason = $split[$i-1];
    $reason =~ s/(.*?). (Your mail to the following recipients could not be delivered)/$2/;

    $by_email{$email} = {
      email => $email,
      raw   => join ("", @split[$i-1..$i+1]),
      std_reason => $std_reason,
      reason => $reason
    };
  }

  my @toreturn;

  foreach my $email (keys %by_email) {
    my $report = Mail::DeliveryStatus::Report->new();
    $report->header_hashref($by_email{$email});
    push @toreturn, $report;
  }

  return @toreturn;
}

=head2 is_bounce

  if ($bounce->is_bounce) { ... }

This method returns true if the bounce parser thought the message was a bounce,
and false otherwise.

=cut

sub is_bounce { return shift->{is_bounce}; }

=head2 reports

Each $report returned by $bounce->reports() is basically a Mail::Header object
with a few modifications.  It includes the email address bouncing, and the
reason for the bounce.

Consider an RFC1892 error report of the form

 Reporting-MTA: dns; hydrant.pobox.com
 Arrival-Date: Fri,  4 Oct 2002 16:49:32 -0400 (EDT)

 Final-Recipient: rfc822; bogus3@dumbo.pobox.com
 Action: failed
 Status: 5.0.0
 Diagnostic-Code: X-Postfix; host dumbo.pobox.com[208.210.125.24] said: 550
  <bogus3@dumbo.pobox.com>: Nonexistent Mailbox

Each "header" above is available through the usual get() mechanism.

  print $report->get('reporting_mta');   # 'some.host.com'
  print $report->get('arrival-date');    # 'Fri,  4 Oct 2002 16:49:32 -0400 (EDT)'
  print $report->get('final-recipient'); # 'rfc822; bogus3@dumbo.pobox.com'
  print $report->get('action');          # "failed"
  print $report->get('status');          # "5.0.0"
  print $report->get('diagnostic-code'); # X-Postfix; ...

  # BounceParser also inserts a few interpretations of its own:
  print $report->get('email');           # 'bogus3@dumbo.pobox.com'
  print $report->get('std_reason');      # 'user_unknown'
  print $report->get('reason');          # host [199.248.185.2] said: 550 5.1.1 unknown or illegal user: somebody@uss.com
  print $report->get('host');            # dumbo.pobox.com
  print $report->get('smtp_code');       # 550

  print $report->get('raw') ||           # the original unstructured text
        $report->as_string;              # the original   structured text

Probably the two most useful fields are "email" and "std_reason", the
standardized reason.  At this time BounceParser returns the following
standardized reasons:

  user_unknown
  over_quota
  domain_error
  spam
  message_too_large
  unknown
  no_problemo

The "spam" standard reason indicates that the message bounced because
the recipient considered it spam.

(no_problemo will only appear if you set {report_non_bounces=>1})

If the bounce message is not structured according to RFC1892,
BounceParser will still try to return as much information as it can;
in particular, you can count on "email" and "std_reason" to be
present.

=cut

sub reports { return @{shift->{reports}} }

=head2 addresses

Returns a list of the addresses which appear to be bouncing.  Each member of
the list is an email address string of the form 'foo@bar.com'.

=cut

sub addresses { return map { $_->get("email") } shift->reports; }

=head2 orig_message_id

If possible, returns the message-id of the original message as a string.

=cut

sub orig_message_id { return shift->{orig_message_id}; }

=head2 orig_message

If the original message was included in the bounce, it'll be available here as
a message/rfc822 MIME entity.

  my $orig_message    = $bounce->orig_message;

=cut

sub orig_message { return shift->{orig_message} }

=head2 orig_header

If only the original headers were returned in the text/rfc822-headers chunk,
they'll be available here as a Mail::Header entity.

=cut

sub orig_header { return shift->{orig_header} }

=head2 orig_text

If the bounce message was poorly structured, the above two methods won't return
anything --- instead, you get back a block of text that may or may not
approximate the original message.  No guarantees.  Good luck.

=cut

sub orig_text { return shift->{orig_text} }

=head1 CAVEATS

Bounce messages are generally meant to be read by humans, not computers.  A
poorly formatted bounce message may fool BounceParser into spreading its net
too widely and returning email addresses that didn't actually bounce.  Before
you do anything with the email addresses you get back, confirm that it makes
sense that they might be bouncing --- for example, it doesn't make sense for
the sender of the original message to show up in the addresses list, but it
could if the bounce message is sufficiently misformatted.

Still, please report all bugs!

=head1 FREE-FLOATING ANXIETY

Some bizarre MTAs construct bounce messages using the original headers of the
original message.  If your application relies on the assumption that all
Message-IDs are unique, you need to watch out for these MTAs and program
defensively; before doing anything with the Message-ID of a bounce message,
first confirm that you haven't already seen it; if you have, change it to
something else that you make up on the spot, such as
"<antibogus-TIMESTAMP-PID-COUNT@LOCALHOST>".

=head1 BUGS

BounceParser assumes a sanely constructed bounce message.  Input from the real
world may cause BounceParser to barf and die horribly when we violate one of
MIME::Entity's assumptions; this is why you should always call it inside an
eval { }.

=head2 TODO

Provide some translation of the SMTP and DSN error codes into English.  Review
RFC1891 and RFC1893.

=head1 KNOWN TO WORK WITH

We understand bounce messages generated by the following MTAs / organizations:

 Postfix
 Sendmail
 Exim
 AOL
 Yahoo
 Hotmail
 AOL's AirMail sender-blocking
 Microsoft Exchange*
 Qmail*
 Novell Groupwise*

 * Items marked with an asterisk currently may return incomplete information.

=head1 SEE ALSO

  Used by http://listbox.com/ --- if you like BounceParser and you know it,
  consider Listbox for your mailing list needs!

  SVN repository and email list information at:
  http://emailproject.perl.org/

  RFC1892 and RFC1894

=head1 RANDOM OBSERVATION

Schwern's modules have the Alexandre Dumas property.

=head1 AUTHOR

Original author: Meng Weng Wong, E<lt>mengwong+bounceparser@pobox.comE<gt>

Current maintainer: Ricardo SIGNES, E<lt>rjbs@cpan.orgE<gt>

Massive contributions to the 1.5xx series were made by William Yardley and
Michael Stevens.  Ricardo mostly just helped out and managed releases.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2003-2006, IC Group, Inc.
  pobox.com permanent email forwarding with spam filtering
  listbox.com mailing list services for announcements and discussion

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 WITH A SHOUT OUT TO

  coraline, Fletch, TorgoX, mjd, a-mused, Masque, gbarr,
  sungo, dngor, and all the other hoopy froods on #perl

=cut

sub _std_reason {
  local $_ = shift;

  if (!defined $_) {
    return "unknown";
  }

  if (/(?:domain|host|service)\s+(?:not\s+found|unknown|not\s+known)/i) {
    return "domain_error"
  }

  if (/sorry,\s+that\s+domain\s+isn't\s+in\s+my\s+list\s+of\s+allowed\s+rcpthosts/i) {
    return "domain_error";
  }

  if (
    /try.again.later/is or
    /mailbox\b.*\bfull/ or
    /storage/i          or
    /quota/i            or
    /\s552\s/           or
    /\s#?5\.2\.2\s/     or                                # rfc 1893
    /User\s+mailbox\s+exceeds\s+allowed\s+size/i or
    /Mailbox\s+size\s+limit\s+exceeded/i or
    /message\s+size\s+\d+\s+exceeds\s+size\s+limit\s+\d+/i or
    /max\s+message\s+size\s+exceeded/i or
	/Benutzer\s+hat\s+zuviele\s+Mails\s+auf\s+dem\s+Server/i 
  ) {
    return "over_quota";
  }

  my $user_re =
   qr'(?: mailbox  | user | recipient | address (?: ee)?
       | customer | account | e-?mail | <? $EMAIL_ADDR_REGEX >? )'ix;

  if (
    /\s \(? \#? 5\.1\.[01] \)? \s/x or                  # rfc 1893
    /$user_re\s+(?:\S+\s+)? (?:is\s+)?                  # Generic
     (?: (?: un|not\s+) (?: known | recognized )
      | [dw]oes\s?n[o']?t 
     (?: exist|found ) | disabled | expired ) /ix or
    /no\s+(?:such)\s+?$user_re/i or                     # Gmail and other (mofified for bug #41874)
    /unrouteable address/i or                           # bug #41874
    /inactive user/i or                                 # Outblaze
    /unknown local part/i or                            # Exim(?)
    /user\s+doesn't\s+have\s+a/i or                     # Yahoo!
    /account\s+has\s+been\s+(?:disabled|suspended)/i or # Yahoo!
    /$user_re\s+(?:suspended|discontinued)/i or         # everyone.net / other?
    /unknown\s+$user_re/i or                            # Generic
    /$user_re\s+(?:is\s+)?(?:inactive|unavailable)/i or # Hotmail, others?
    /(?:(?:in|not\s+a\s+)?valid|no such)\s$user_re/i or # Various
    /$user_re\s+(?:was\s+)?not\s+found/i or             # AOL, generic
    /$user_re \s+ (?:is\s+)? (?:currently\s+)?          # ATT, generic
     (?:suspended|unavailable)/ix or 
    /address is administratively disabled/i or          # Unknown
    /no $user_re\s+(?:here\s+)?by that name/i or        # Unknown
    /<?$EMAIL_ADDR_REGEX>? is invalid/i or              # Unknown
    /address.*not known here/i or                       # Unknown
    /recipient\s+(?:address\s+)?rejected/i or           # Cox, generic
    /not\s+listed\s+in\s+Domino/i or                    # Domino
    /account not activated/i or                         # usa.net
    /not\s+our\s+customer/i or                          # Comcast
    /doesn't handle mail for that user/i or             # mailfoundry
    /$user_re\s+does\s+not\s+exist/i or
    /Recipient\s+<?$EMAIL_ADDR_REGEX>?\s+does\s+not\s+exist/i or
    /recipient\s+no\s+longer\s+on\s+server/i or # me.com
    /is\s+not\s+a\s+known\s+user\s+on\s+this\s+system/i or # cam.ac.uk
    /Rcpt\s+<?$EMAIL_ADDR_REGEX>?\s+does\s+not\s+exist/i or
    /Mailbox\s+not\s+available/i or
    /No\s+mailbox\s+found/i or
    /<?$EMAIL_ADDR_REGEX>?\s+is\s+a\s+deactivated\s+mailbox/i or
    /Recipient\s+does\s+not\s+exist\s+on\s+this\s+system/i or
	/user\s+mail-box\s+not\s+found/i or
	/No\s+mail\s+box\s+available\s+for\s+this\s+user/i or
	/User\s+\[\S+\]\s+does\s+not\s+exist/i or
	/email\s+account\s+that\s+you\s+tried\s+to\s+reach\s+is\s+disabled/i or
	/not\s+an\s+active\s+address\s+at\s+this\s+host/i
  ) {
    return "user_unknown";
  }

  if (
    /domain\s+syntax/i or
    /timed\s+out/i or
    /route\s+to\s+host/i or
    /connection\s+refused/i or
    /no\s+data\s+record\s+of\s+requested\s+type/i or
    /Malformed name server reply/i or
    /as\s+a\s+relay,\s+but\s+I\s+have\s+not\s+been\s+configured\s+to\s+let/i or
    /550\s+relay\s+not\s+permitted/i or
    /550\s+relaying\s+denied/i or
    /Relay\s+access\s+denied/i or
    /Relaying\s+denied/i or
    /No\s+such\s+domain\s+at\s+this\s+location/i
  ) {
    return "domain_error";
  }

  if (
    /Blocked\s+by\s+SpamAssassin/i or
    /spam\s+rejection/i or
    /identified\s+SPAM,\s+message\s+permanently\s+rejected/i or
    /Mail\s+appears\s+to\s+be\s+unsolicited/i or
    /Message\s+rejected\s+as\s+spam\s+by\s+Content\s+Filtering/i or
    /message\s+looks\s+like\s+SPAM\s+to\s+me/i or
    /NOT\s+JUNKEMAILFILTER/i or
    /your\s+message\s+has\s+triggered\s+a\s+SPAM\s+block/i or
    /Spam\s+detected/i or
    /Message\s+looks\s+like\s+spam/i or
	/Message\s+content\s+rejected,\s+UBE/i or
	/Blocked\s+using\s+spam\s+pattern/i or
	/breaches\s+local\s+URIBL\s+policy/i or
	/Your\s+email\s+had\s+spam-like\s+header\s+contents/i or
	/detected\s+as\s+spam/i or
	/Denied\s+due\s+to\s+spam\s+list/i
  ) {
    return "spam";
  }

  if (
    /RESOLVER.RST.RecipSizeLimit/i
  ) {
    return "message_too_large";
  }

  return "unknown";
}

# ---------------------------------------------------------------------
# preprocessors
# ---------------------------------------------------------------------

sub p_ims {
  my $self    = shift;
  my $message = shift;

  # Mangle Exchange messages into a format we like better
  # see t/corpus/exchange.unknown.msg

  return
    unless ($message->head->get("X-Mailer")||'') =~ /Internet Mail Service/i;

  if ($message->is_multipart) {
    return unless my ($error_part)
      = grep { $_->effective_type eq "text/plain" } $message->parts;

    return unless my ($actual_error)
      = $error_part->as_string
        =~ /did not reach the following recipient\S+\s*(.*)/is;

    if (my $io = $error_part->open("w")) {
      $io->print($actual_error);
      $io->close;
    }

  } else {

    return unless my ($actual_error)
      = $message->bodyhandle->as_string
        =~ /did not reach the following recipient\S+\s*(.*)/is;

    my ($stuff_before, $stuff_after)
      = split /^(?=Message-ID:|Received:)/m, $message->bodyhandle->as_string;

    $stuff_before =~ s/.*did not reach the following recipient.*?$//ism;
    $self->log("rewrote IMS into plain/report.");
    return $self->new_plain_report($message, $stuff_before, $stuff_after);
  }

  return $message;
}

sub p_aol_senderblock {
  my $self    = shift;
  my $message = shift;

  return unless ($message->head->get("Mailer")||'') =~ /AirMail/i;
  return unless $message->effective_type eq "text/plain";
  return unless $message->bodyhandle->as_string =~ /Your mail to the following recipients could not be delivered because they are not accepting mail/i;

  my ($host) = $message->head->get("From") =~ /\@(\S+)>/;

  my $rejector;
  my @new_output;
  for (split /\n/, $message->bodyhandle->as_string) {

    # "Sorry luser@example.com. Your mail to the...
    # Get rid of this so that the module doesn't create a report for
    # *your* address.
    s/Sorry \S+?@\S+?\.//g;

    if (/because they are not accepting mail from (\S+?):?/i) {
      $rejector = $1;
      push @new_output, $_;
      next;
    }
    if (/^\s*(\S+)\s*$/) {
      my $recipient = $1;
      if ($recipient =~ /\@/) {
        push @new_output, $_;
        next;
      }
      s/^(\s*)(\S+)(\s*)$/$1$2\@$host$3/;
      push @new_output, $_;
      next;
    }
    push @new_output, $_;
    next;
  }

  push @new_output, ("# rewritten by BounceParser: p_aol_senderblock()", "");
  if (my $io = $message->open("w")) {
    $io->print(join "\n", @new_output);
    $io->close;
  }
  return $message;
}

sub p_novell_groupwise {

  # renamed from p_novell_groupwise_5_2 - hopefully we can deal with most / all
  # versions and create test cases / fixes when we can't
  #
  # See t/various-unknown.t and t/corpus/novell-*.msg for some recent examples.

  my $self    = shift;
  my $message = shift;

  return unless ($message->head->get("X-Mailer")||'') =~ /Novell Groupwise/i;
  return unless $message->effective_type eq "multipart/mixed";
  return unless my ($error_part)
    = grep { $_->effective_type eq "text/plain" } $message->parts;

  my ($host) = $message->head->get("From") =~ /\@(\S+)>?/;

  # A lot of times, Novell returns just the LHS; this makes it difficult /
  # impossible in many cases to guess the recipient address. MBP makes an
  # attempt here.
  my @new_output;
  for (split /\n/, $error_part->bodyhandle->as_string) {
    if (/^(\s*)(\S+)(\s+\(.*\))$/) {
      my ($space, $recipient, $reason) = ($1, $2, $3);
      if ($recipient =~ /\@/) {
        push @new_output, $_;
        next;
      }
      $_ = join "", $space, "$2\@$host", $reason;
      push @new_output, $_; next;
    }
    push @new_output, $_; next;
  }

  push @new_output,
    ("# rewritten by BounceParser: p_novell_groupwise()", "");

  if (my $io = $error_part->open("w")) {
    $io->print(join "\n", @new_output);
    $io->close;
  }
  return $message;
}

sub p_plain_smtp_transcript {
  my ($self, $message) = (shift, shift);

  # sometimes, we have a proper smtp transcript;
  # that means we have enough information to mark the message up into a proper
  # multipart/report!
  #
  # pennwomen-la@v2.listbox.com/200209/19/1032468752.1444_1.frodo
  # The original message was received at Thu, 19 Sep 2002 13:51:36 -0700 (MST)
  # from daemon@localhost
  #
  #    ----- The following addresses had permanent fatal errors -----
  # <friedman@primenet.com>
  #     (expanded from: <friedman@primenet.com>)
  #
  #    ----- Transcript of session follows -----
  # ... while talking to smtp-local.primenet.com.:
  # >>> RCPT To:<friedman@smtp-local.primenet.com>
  # <<< 550 <friedman@smtp-local.primenet.com>... User unknown
  # 550 <friedman@primenet.com>... User unknown
  #    ----- Message header follows -----
  #
  # what we'll do is mark it back up into a proper multipart/report.

  return unless $message->effective_type eq "text/plain";

  return unless $message->bodyhandle->as_string
    =~ /The following addresses had permanent fatal errors/;

  return unless $message->bodyhandle->as_string
    =~ /Transcript of session follows/;

  return unless $message->bodyhandle->as_string =~ /Message .* follows/;

  my ($stuff_before, $stuff_after)
    = split /^.*Message (?:header|body) follows.*$/im,
        $message->bodyhandle->as_string, 2;

  my %by_email = $self->_analyze_smtp_transcripts($stuff_before);

  my @paras = _construct_delivery_status_paras(\%by_email);

  my @new_output;
  my ($reporting_mta) = _cleanup_email($message->head->get("From")) =~ /\@(\S+)/;

  chomp (my $arrival_date = $message->head->get("Date"));

  push @new_output, "Reporting-MTA: $reporting_mta" if $reporting_mta;
  push @new_output, "Arrival-Date: $arrival_date" if $arrival_date;
  push @new_output, "";
  push @new_output, map { @$_, "" } @paras;

  return $self->new_multipart_report(
    $message,
    $stuff_before,
    join("\n", @new_output),
    $stuff_after
  );
}

sub _construct_delivery_status_paras {
  my %by_email = %{shift()};

  my @new_output;

  foreach my $email (sort keys %by_email) {
    # Final-Recipient: RFC822; robinbw@aol.com
    # Action: failed
    # Status: 2.0.0
    # Remote-MTA: DNS; air-xj03.mail.aol.com
    # Diagnostic-Code: SMTP; 250 OK
    # Last-Attempt-Date: Thu, 19 Sep 2002 16:53:10 -0400 (EDT)

    push @new_output, [
      "Final-Recipient: RFC822; $email",
      "Action: failed",
      "Status: 5.0.0",
      ($by_email{$email}->{host} ? ("Remote-MTA: DNS; $by_email{$email}->{host}") : ()),
      _construct_diagnostic_code(\%by_email, $email),
    ];

  }

  return @new_output;
}

sub _construct_diagnostic_code {
  my %by_email = %{shift()};
  my $email = shift;
  join (" ",
  "Diagnostic-Code: X-BounceParser;",
  ($by_email{$email}->{'host'} ? "host $by_email{$email}->{'host'} said:" : ()),
  ($by_email{$email}->{'smtp_code'}),
  (join ", ", @{ $by_email{$email}->{'errors'} }));
}

sub _analyze_smtp_transcripts {
  my $self = shift;
  my $plain_smtp_transcript = shift;

  my (%by_email, $email, $smtp_code, @error_strings, $host);

  # parse the text part for the actual SMTP transcript
  for (split /\n\n|(?=>>>)/, $plain_smtp_transcript) {
    $email = _cleanup_email($1) if /RCPT TO:\s*(\S+)/im;

    if (/The\s+following\s+addresses\s+had\s+permanent\s+fatal\s+errors\s+-----\s+\<(.*)\>/im) {
      $email = _cleanup_email($1);
    }

    $by_email{$email}->{host} = $host if $email;

    if (/while talking to (\S+)/im) {
      $host = $1;
      $host =~ s/[.:;]+$//g;
    }

    if (/<<< (\d\d\d) (.*)/m) {
      $by_email{$email}->{smtp_code} = $1;
      push @{$by_email{$email}->{errors}}, $2;
    }

    if (/^(\d\d\d)\b.*(<\S+\@\S+>)\.*\s+(.+)/m) {
      $email = _cleanup_email($2);
      $by_email{$email}->{smtp_code} = $1;
      push @{$by_email{$email}->{errors}}, $3;
    }
  }
  delete $by_email{''};
  return %by_email;
}

# ------------------------------------------------------------

sub new_plain_report {
  my ($self, $message, $error_text, $orig_message) = @_;

  $orig_message =~ s/^\s+//;

  my $newmessage = $message->dup();
  $newmessage->make_multipart("plain-report");
  $newmessage->parts([]);
  $newmessage->attach(Type => "text/plain", Data => $error_text);

  my $orig_message_mime = MIME::Entity->build(Type => "multipart/transitory");

  $orig_message_mime->add_part($self->{parser}->parse_data($orig_message));

  $orig_message_mime->head->mime_attr("content-type" => "message/rfc822");
  $newmessage->add_part($orig_message_mime);

  $self->log("created new plain-report message.");

  return $newmessage;
}

# ------------------------------------------------------------

sub new_multipart_report {
  my ($self, $message, $error_text, $delivery_status, $orig_message) = @_;

  $orig_message =~ s/^\s+//;

  my $newmessage = $message->dup();
  $newmessage->make_multipart("report");
  $newmessage->parts([]);
  $newmessage->attach(
    Type => "text/plain",
    Data => $error_text
  );
  $newmessage->attach(
    Type => "message/delivery-status",
    Data => $delivery_status
  );

  my $orig_message_mime
    = MIME::Entity->build(Type => "multipart/transitory", Top => 0);

  $orig_message_mime->add_part($self->{parser}->parse_data($orig_message));

  $orig_message_mime->head->mime_attr("content-type" => "message/rfc822");
  $newmessage->add_part($orig_message_mime);

  $self->log("created new multipart-report message.");

  return $newmessage;
}

# ------------------------------------------------------------

sub _cleanup_email {
  my $email = shift;
  for ($email) {
    chomp;
    # Get rid of parens around addresses like (luser@example.com)
    # Got rid of earlier /\(.*\)/ - not sure what that was about - wby
    tr/[()]//d;
    s/^To:\s*//i;
    s/[.:;]+$//;
    s/<(.+)>/$1/;
    # IMS hack: c=US;a= ;p=NDC;o=ORANGE;dda:SMTP=slpark@msx.ndc.mc.uci.edu; on
    # Thu, 19 Sep...
    s/.*:SMTP=//;
    s/^\s+//;
    s/\s+$//;
    # hack to get rid of stuff like "luser@example.com...User"
    s/\.{3}\S+//;
    # SMTP:foo@example.com
    s/^SMTP://;
    }
  return $email;
}

sub p_xdelivery_status {
  my ($self, $message) = @_;

  # This seems to be caused by something called "XWall v3.31", which
  # (according to Google) is a "firewall that protects your Exchange
  # server from viruses, spam mail and dangerous attachments".  Shame it
  # doesn't protect the rest of the world from gratuitously broken MIME
  # types.

  for ($message->parts_DFS) {
    $_->effective_type('message/delivery-status')
      if $_->effective_type eq 'message/xdelivery-status';
  }
}

sub _first_non_multi_part {
  my ($entity) = @_;

  my $part = $entity;
  $part = $part->parts(0) or return while $part->is_multipart;
  return $part;
}

sub _position_before {
  my ($pos_a, $pos_b) = @_;
  return 1 if defined($pos_a) && (!defined($pos_b) || $pos_a < $pos_b);
  return;
}

# Return the position in $string at which $regex first matches, or undef if
# no match.
sub _match_position {
  my ($string, $regex) = @_;
  return $string =~ $regex ? $-[0] : undef;
}

1;
