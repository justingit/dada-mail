package DADA::MailingList::MessageDrafts::baseSQL; 

    use strict;

use lib qw(
  ../../../
  ../../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_MessageDrafts};

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

    $self->{list} = $args->{-list};

    $self->_sql_init();

}

sub _sql_init {

    my $self = shift;
    my ($args) = @_;

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

    if ( !keys %{ $self->{sql_params} } ) {
        croak "sql params not filled out?!";
    }
    else {
    }

    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub id_exists {

    warn 'id_exists'
      if $t;

    my $self = shift;
    my $id   = shift;

    if ( !defined($id) || $id eq '' ) {
        return 0;
    }
    my $query = 'SELECT COUNT(*) FROM ' . $self->{sql_params}->{message_drafts_table} . ' WHERE list = ? AND id = ?';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list}, $id )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    warn 'QUERY: ' . $query
      if $t;

    my $count = $sth->fetchrow_array;
    warn '$count:' . $count
      if $t;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }

}

sub save {

    warn 'save'
      if $t;

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-cgi_obj} ) ) {
        croak "You MUST pass a, '-cgi_obj' parameter!";
    }

    if ( !exists( $args->{-screen} ) ) {
        croak "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }
    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }
    my $id = undef;
    if ( exists( $args->{-id} ) ) {
        $id = $args->{-id};
    }

    #	warn '$id:' . $id;

    my $draft = $self->stringify_cgi_params( { -cgi_obj => $args->{-cgi_obj}, -screen => $args->{-screen} } );

    if ( !defined($id) ) {

        warn 'id undefined.'
          if $t;

        my $query =
            'INSERT INTO '
          . $self->{sql_params}->{message_drafts_table}
          . ' (list, screen, role, draft, last_modified_timestamp) VALUES (?,?,?,?, NOW())';

        # Uh, it's gotta be a little different.
        if ( $self->{sql_params}->{dbtype} eq 'SQLite' ) {
            $query =~ s/NOW\(\)/CURRENT_TIMESTAMP/;
        }

        warn 'QUERY: ' . $query
          if $t;

        my $sth = $self->{dbh}->prepare($query);
        if($t == 1) { 
            require Data::Dumper; 
            warn 'execute params: ' . Data::Dumper::Dumper([$self->{list}, $args->{-screen}, $args->{-role}, $draft]); 
        }
        $sth->execute( $self->{list}, $args->{-screen}, $args->{-role}, $draft )
          or croak "cannot do statement '$query'! $DBI::errstr\n";

        $sth->finish;

        #return $sth->{mysql_insertid};
        if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql' ) {
            return $sth->{mysql_insertid};
        }
        else {
            my $last_insert_id =
              $self->{dbh}->last_insert_id( undef, undef, $self->{sql_params}->{message_drafts_table}, undef );
            warn '$last_insert_id:' . $last_insert_id
              if $t;

            return $last_insert_id;
        }
    }
    else {

        if ( !$self->id_exists($id) ) {
            croak "id, '$id' doesn't exist!";
        }

        warn 'id defined.'
          if $t;

        my $query =
            'UPDATE '
          . $self->{sql_params}->{message_drafts_table}
          . ' SET screen = ?, role = ?, draft = ?, last_modified_timestamp = NOW() WHERE list = ? AND id = ?';

        warn 'QUERY: ' . $query
          if $t;

        my $sth = $self->{dbh}->prepare($query);
        $sth->execute( $args->{-screen}, $args->{-role}, $draft, $self->{list}, $args->{-id} )
          or croak "cannot do statement '$query'! $DBI::errstr\n";
        $sth->finish;
        return $id;
    }
}

sub has_draft {

    warn 'has_draft'
      if $t;

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }
    if ( !exists( $args->{-screen} ) ) {
        croak "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }

    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{message_drafts_table}
      . ' WHERE list = ? AND screen = ? AND role = ?';

    warn 'QUERY: ' . $query
      if $t;

    #    use Data::Dumper;
    #    warn 'params' . Dumper([$self->{list}, $args->{-screen}, $args->{-role}]);

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list}, $args->{-screen}, $args->{-role} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

    #    warn '$count ' . $count;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
}

sub latest_draft_id {
    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }
    if ( !exists( $args->{-screen} ) ) {
        croak "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }

    my $query =
        'SELECT id FROM '
      . $self->{sql_params}->{message_drafts_table}
      . ' WHERE list = ? AND screen = ? AND role = ? ORDER BY last_modified_timestamp DESC';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{list}, $args->{-screen}, $args->{-role} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";
    my $hashref;

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        return $hashref->{id};
    }
}

sub fetch {
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }
    if ( !exists( $args->{-screen} ) ) {
        die "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }
    my $id = undef;
    if ( exists( $args->{-id} ) ) {
        $id = $args->{-id};
    }

    my $query;
    if ( !$id ) {
        $query =
            'SELECT id, list, screen, role, draft FROM '
          . $self->{sql_params}->{message_drafts_table}
          . ' WHERE list = ? AND screen = ? AND role = ? ORDER BY id DESC';
    }
    else {

        if ( !$self->id_exists($id) ) {
            croak "id, '$id' doesn't exist!";
        }

        $query =
            'SELECT id, list, screen, role, draft FROM '
          . $self->{sql_params}->{message_drafts_table}
          . ' WHERE list = ? AND screen = ? AND role = ? AND id = ? ORDER BY id DESC';

    }

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    my $saved = '';

    if ( !$id ) {

        #use Data::Dumper;
        #warn 'params (no id)' . Dumper([$self->{list}, $args->{-screen}, $args->{-role}]);

        $sth->execute( $self->{list}, $args->{-screen}, $args->{-role} )
          or croak "cannot do statement '$query'! $DBI::errstr\n";
    }
    else {

        #use Data::Dumper;
        #warn 'params (id!)' . Dumper([$self->{list}, $args->{-screen}, $args->{-role}]);

        $sth->execute( $self->{list}, $args->{-screen}, $args->{-role}, $id )
          or croak "cannot do statement '$query'! $DBI::errstr\n";
    }
    my $hashref;

    while ( $hashref = $sth->fetchrow_hashref ) {
        $saved = $hashref->{draft};
        $sth->finish;
        last;
    }

    my $q = $self->decode_draft($saved);

    return $q;

}

sub create_from_stationary {
    my $self    = shift;
    my ($args)  = @_;
    my $q_draft = $self->fetch(
        {
            -id     => $args->{-id},
            -screen => $args->{-screen},
            -role   => 'stationary',
        }
    );

    my $saved_draft_id = $self->save(
        {
            -cgi_obj => $q_draft,
            -role    => 'draft',
            -screen  => $args->{-screen},
        }
    );
    return ($saved_draft_id);
}

sub count {
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }

    my @row;
    my $query = 'SELECT COUNT(*) FROM ' . $self->{sql_params}->{message_drafts_table} . ' WHERE list = ? AND role = ?';

    warn 'QUERY: ' . $query
      if $t;

    my $count = $self->{dbh}->selectrow_array( $query, undef, $self->{list}, $args->{-role} );
    return $count;
}

sub remove {
    my $self = shift;
    my $id   = shift;

    if ( !$self->id_exists($id) ) {
        carp "id, '$id' doesn't exist! in remove()";
        return -1;
    }

    my $query = 'DELETE FROM ' . $self->{sql_params}->{message_drafts_table} . ' WHERE id = ? AND list = ?';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    my $rows = $sth->execute( $id, $self->{list} );
    $sth->finish;
    return $rows;
}

sub decode_draft {
    my $self  = shift;
    my $saved = shift;
    open my $fh, '<', \$saved || die $!;
    require CGI;
    my $q = CGI->new($fh);
    return $q;
}

sub draft_index {
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }

    my $r = [];

    my $query;

    $query =
        'SELECT * FROM '
      . $self->{sql_params}->{message_drafts_table}
      . ' WHERE list = ? AND role = ? ORDER BY last_modified_timestamp DESC';

    if ( $args->{-role} eq 'draft' ) {    # a little backwards compat.
        $query =
            'SELECT * FROM '
          . $self->{sql_params}->{message_drafts_table}
          . ' WHERE list = ? AND (role = ? OR role IS NULL) ORDER BY last_modified_timestamp DESC';
    }

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{list}, $args->{-role} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";
    my $hashref;

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        my $q = $self->decode_draft( $hashref->{draft} );
        my $params = {
            id                      => $hashref->{id},
            list                    => $hashref->{list},
            created_timestamp       => $hashref->{created_timestamp},
            last_modified_timestamp => $hashref->{last_modified_timestamp},
            screen                  => $hashref->{screen},
            role                    => $hashref->{role},
            Subject                 => $q->param('Subject'),
            schedule_datetime       => $q->param('schedule_datetime'),
            schedule_activated      => $q->param('schedule_activated'),
        };

        if (   $args->{-role} eq 'schedule'
            && length( $params->{schedule_datetime} ) > 0
            && $params->{schedule_datetime} > 0 )
        {
            $params->{schedule_localtime} = $self->datetime_to_localtime( $q->param('schedule_datetime') );
            $params->{schedule_time}      = $self->datetime_to_ctime(     $q->param('schedule_datetime') );
        }
        push( @$r, $params );        
    }
    $sth->finish;
    
    if($args->{-role} eq 'schedule'){ 
        $r = $self->sort_by_schedule($r); 
    }
    
    
    return $r;
}

sub sort_by_schedule { 
    my $self = shift; 
    my $r    = shift; 
    my $s    = []; 
    
    foreach my $row (sort { $a->{schedule_datetime} <=> $b->{schedule_datetime} } @$r ) {
        push(@$s, $row);
    }
    return $s; 
}

sub stringify_cgi_params {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-cgi_obj} ) ) {
        croak "You MUST pass a, '-cgi_obj' parameter!";
    }
    if ( !exists( $args->{-screen} ) ) {
        die "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }

    my $q = $args->{-cgi_obj};
    $q = $self->remove_unwanted_params(
        {
            -cgi_obj => $args->{-cgi_obj},
            -screen  => $args->{-screen}
        }
    );

    my $buffer = "";
    open my $fh, ">", \$buffer or die 'blarg!' . $!;
    $q->save($fh);
    return $buffer;
}

sub remove_unwanted_params {
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-cgi_obj} ) ) {
        croak "You MUST pass a, '-cgi_obj' parameter!";
    }
    if ( !exists( $args->{-screen} ) ) {
        die "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }

    require CGI;
    my $q     = $args->{-cgi_obj};
    my $new_q = CGI->new($q);
    my $params_to_save =
      $self->params_to_save( { -screen => $args->{-screen} } );

    for ( $new_q->param ) {
        unless ( exists( $params_to_save->{$_} ) ) {
            $new_q->delete($_);
        }
    }

    return $new_q;

}

sub params_to_save {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-screen} ) ) {
        die "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }

    my $params = {
        'Reply-To'   => 1,
        'X-Priority' => 1,

        html_message_body => 1,
        text_message_body => 1,

        archive_message   => 1,
        archive_no_send   => 1,
        back_date         => 1,
        backdate_datetime => 1,
        test_recipient    => 1,

        Subject => 1,

        schedule_activated => 1,
        schedule_datetime  => 1,

    };

    require DADA::ProfileFieldsManager;
    my $pfm               = DADA::ProfileFieldsManager->new;
    my $subscriber_fields = $pfm->fields;
    foreach (@$subscriber_fields) {
        $params->{ $_ . '.operator' } = 1;
        $params->{ $_ . '.value' }    = 1;
    }
    for ('email') {
        $params->{ $_ . '.operator' } = 1;
        $params->{ $_ . '.value' }    = 1;
    }

    for ('subscriber.timestamp') {
        $params->{ $_ . '.rangestart' } = 1;
        $params->{ $_ . '.rangeend' }   = 1;
    }
    if ( $args->{-screen} eq 'send_email' ) {

        $params->{attachment1} = 1;
        $params->{attachment2} = 1;
        $params->{attachment3} = 1;
        $params->{attachment4} = 1;
        $params->{attachment5} = 1;
    }
    elsif ( $args->{-screen} eq 'send_url_email' ) {

        $params->{content_from}          = 1;
        $params->{url}                   = 1;
        $params->{auto_create_plaintext} = 1;
        $params->{url_options}           = 1;
        $params->{remove_javascript}     = 1;
        $params->{url_username}          = 1;
        $params->{url_password}          = 1;
        $params->{proxy}                 = 1;
    }

    #	use Data::Dumper;
    #	warn Dumper($params);

    return $params;

}

sub datetime_to_ctime {
    my $self     = shift;
    my $datetime = shift;
    warn '$datetime ' . $datetime
      if $t;
    require Time::Local;
    my ( $date, $time ) = split( ' ', $datetime );
    my ( $year, $month,  $day )    = split( '-', $date );
    my ( $hour, $minute, $second ) = split( ':', $time );
    $second = int( $second - 0.5 );    # no idea.
    my $time = Time::Local::timelocal( $second, $minute, $hour, $day, $month - 1, $year );

    return $time;
}

sub datetime_to_localtime {
    my $self     = shift;
    my $datetime = shift;

    warn '$datetime ' . $datetime
      if $t;
    if ( defined($datetime) && $datetime > 0 ) {
        my $time = $self->datetime_to_ctime($datetime);
        return scalar( localtime($time) );
    }
    else {
        warn 'something wrong with $datetime!:' . $datetime;
        return 0;
    }
}

sub enabled {
    my $self = shift; 
    return 1;
}

1;
