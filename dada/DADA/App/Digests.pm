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

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Digests};

my %allowed = ( test => 0, );

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
    my ($args) = @_;
    $self->{list}   = $args->{-list};
    $self->{ls_obj} = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    $self->{a_obj}  = DADA::MailingList::Archives->new( { -list => $self->{list} } );

    if ( !exists( $args->{'-time'} ) ) {
        $self->{time} = time;
    }
}

=cut
sub archive_id_time_lt_table { 
   my $self = shift;
   my $keys       = $self->{a_obj}->get_archive_entries('normal');
   $lt = {}; 
   for(@$keys
}
=cut

sub should_send_digests { 
    my $self = shift; 
    
    my $keys       = $self->{a_obj}->get_archive_entries('normal');
    
    my $digest_last_archive_id_sent = $self->{ls_obj}->param('digest_last_archive_id_sent') || undef; 
    
    # no archives available? no digest.   
    if(scalar(@{$keys}) == 0) { 
        return 0; 
    }
    
    # Well, is the last archive id we sent the newest archive? 
    # (or the an archive newer was deleted?)
    # Basically are there archives availabel but beyond our scope, in the future? 
    if($self->{ls_obj}->param('digest_last_archive_id_sent') >= $keys->[0]){ 
        return 0; 
    }
    
    # in our scope: 
    # Now: 
    my $top_margin = $self->ctime_2_archive_time($self->{-time});
    if($keys->[0] < $top_margin && $keys->[0] > $self->{ls_obj}->param('digest_last_archive_id_sent')){ 
        return 1; 
    }
    else { 
        return 0; 
    }        
}
sub send_digests {
    my $self = shift;
    my $r = "sending out digests! Here we go!\n";

    if($self->should_send_digests){ 
        $r .= "woo! digests to send!"; 
    }
    else { 
        $r .= "whoa! No digests should be sent out!"; 
    }
    return $r; 
}

sub time_limit {
    my $self  = shift;
    my $limit = int($self->{time}) - int( $self->{ls_object}->param('digest_schedule') );
    return $limit;
}

sub archive_ids_for_digest {
    my $self = shift;
    my ($args) = @_;

    my $time_limit = $self->time_limit();
    my $keys       = $self->{a_obj}->get_archive_entries('normal');
    my @digest_keys;
    
    foreach my $a_key (@$keys) {
        my $c_time = archive_time_2_ctime($a_key );
        if ( $c_time > $time_limit ) {
            push(@digest_keys);
        }
        else {
            last;
        }
    }
    return \@digest_keys;
}

sub archive_time_2_ctime {

    my $self  = shift;
    
    my $p_num = shift;

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
    my $self = shift;
    my ($args) = @_; 
    return message_id($args->{-ctime}); 
}

1;
