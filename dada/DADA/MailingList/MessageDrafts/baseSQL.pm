package DADA::MailingList::MessageDrafts::baseSQL; 

    use strict;

use lib qw(
  ../../../
  ../../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts; 
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

    my $self   = shift;
    my ($args) = @_;

#    require Data::Dumper; 
#    warn 'save $args:' . Data::Dumper::Dumper($args); 
    
    if ( !exists( $args->{-cgi_obj} ) ) {
        croak "You MUST pass a, '-cgi_obj' parameter!";
    }

    if ( !exists( $args->{-screen} ) ) {
        croak "You MUST pass a, '-screen' parameter! (send_email, send_url_email)";
    }
    
    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }
    
    if ( !exists( $args->{-save_role} ) ) {
        $args->{-save_role} = $args->{-role};
    }


#    warn '$args->{-role}'      . $args->{-role}; 
#    warn '$args->{-save_role}' . $args->{-save_role}; 

    my $id = undef;
    if ( exists( $args->{-id} ) ) {
        $id = $args->{-id};
    }

    #if($t == 1){ 
    #    require Data::Dumper; 
    #    warn 'save() args:' . "\n" . Data::Dumper::Dumper($args); 
    #}
    #	warn '$id:' . $id;
    my $q = $args->{-cgi_obj}; 
       $q = $self->fill_in_schedule_options($q); 
    my $draft = $self->stringify_cgi_params( 
        { 
            -cgi_obj => $q, 
            -screen  => $args->{-screen} 
        } 
    );

    if ( !defined($id) ) {

        warn 'id undefined.'
          if $t;

          my $query; 
        if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {
            $query =
                'INSERT INTO '
              . $self->{sql_params}->{message_drafts_table}
              . ' (list, screen, role, draft, last_modified_timestamp) VALUES (?,?,?,?, CURRENT_TIMESTAMP)';
        }
        else { 

            $query =
                'INSERT INTO '
              . $self->{sql_params}->{message_drafts_table}
              . ' (list, screen, role, draft, last_modified_timestamp) VALUES (?,?,?,?, NOW())';
        }
        
        # Uh, it's gotta be a little different.
        if ( $self->{sql_params}->{dbtype} eq 'SQLite' ) {
            $query =~ s/NOW\(\)/CURRENT_TIMESTAMP/;
        }

        warn 'QUERY: ' . $query
          if $t;

        my $sth = $self->{dbh}->prepare($query);
        if($t == 1) { 
            require Data::Dumper; 
            warn 'execute params: ' . Data::Dumper::Dumper([$self->{list}, $args->{-screen}, $args->{-save_role}, $draft]); 
        }
        $sth->execute( $self->{list}, $args->{-screen}, $args->{-save_role}, $draft )
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

        # Trying to figure out what else this would be... 
        if(
               ($args->{-role} eq 'draft'      && $args->{-save_role} eq 'draft')
               
            || ($args->{-role} eq 'draft'      && $args->{-save_role} eq 'stationery')
            
            || ($args->{-role} eq 'draft'      && $args->{-save_role} eq 'schedule')
            
            || ($args->{-role} eq 'schedule'   && $args->{-save_role} eq 'schedule')
            
            || ($args->{-role} eq 'stationery' && $args->{-save_role} eq 'stationery')
        ) {

#            warn "Saving Regularly!"; 
            
            my $query; 
            if ( $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {
                $query =
                    'UPDATE '
                  . $self->{sql_params}->{message_drafts_table}
                  . ' SET screen = ?, role = ?, draft = ?, last_modified_timestamp = CURRENT_TIMESTAMP WHERE list = ? AND id = ?';
            }
            else { 
                $query =
                    'UPDATE '
                  . $self->{sql_params}->{message_drafts_table}
                  . ' SET screen = ?, role = ?, draft = ?, last_modified_timestamp = NOW() WHERE list = ? AND id = ?';

            }
        
            warn 'QUERY: ' . $query
              if $t;
            warn '$draft ' . $draft
             if $t; 
            
            my $sth = $self->{dbh}->prepare($query);
               $sth->execute( 
                   $args->{-screen}, 
                   $args->{-save_role}, 
                   $draft, 
                   $self->{list}, 
                   $args->{-id} 
              )
              or croak "cannot do statement '$query'! $DBI::errstr\n";
            $sth->finish;
            return $id;
        }
        elsif($args->{-role} eq 'stationery' && $args->{-save_role} eq 'draft') {
            
            # warn 'Draft from Stationery!'; 
             
            # All we need to do, is save this as stationery first, then - 
            $self->save({
                    %$args, 
                    -role      => 'stationery',
                    -save_role => 'stationery', # So, we save the stationery.  
            }); 
            warn 'saved.'
                if $t;
            warn '# Then this makes the copy.'
                if $t; 
            my $saved_id = $self->create_from_stationery(
                    {
                        -id     => $args->{-id},
                        -screen => $args->{-screen},
                    }
                ); 
            # warn 'created from stationery!'; 
            # warn 'Stationery ID: ' . $id; 
            # warn 'Returning  ID: ' . $saved_id ; 
            return $saved_id;             
        }
        else { 
            # warn 'don\'t.... know what to save!'; 
            return $id; 
        }
    }
}

sub fill_in_schedule_options { 
    my $self = shift; 
    my $q    = shift; 
        
    if(!defined($q->param('schedule_type'))) { 
        $q->param('schedule_type', 'single'); 
    }
    
    if(!defined($q->param('schedule_single_ctime')) && defined($q->param('schedule_single_displaydatetime'))){ 
        $q->param('schedule_single_ctime', displaytime_to_ctime($q->param('schedule_single_displaydatetime')));
    }
    if(!defined($q->param('schedule_recurring_ctime_start')) && defined($q->param('schedule_recurring_displaydatetime_start'))){ 
        $q->param('schedule_recurring_ctime_start', displaytime_to_ctime($q->param('schedule_recurring_displaydatetime_start')));
    }
    if(!defined($q->param('schedule_recurring_ctime_end')) && defined($q->param('schedule_recurring_displaydatetime_end'))){ 
        $q->param('schedule_recurring_ctime_end', displaytime_to_ctime($q->param('schedule_recurring_displaydatetime_end')));
    }
    
    if(!defined($q->param('schedule_recurring_hms')) && defined($q->param('schedule_recurring_display_hms'))){ 
        $q->param('schedule_recurring_hms', display_hms_to_hms($q->param('schedule_recurring_display_hms')));
    }
    
    if(!defined($q->param('schedule_recurring_only_mass_mail_if_primary_diff'))) { 
        $q->param('schedule_recurring_only_mass_mail_if_primary_diff', 0);
    }
    
    
    
    return $q;     
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
    my $additional_schedule_params = $self->additional_schedule_params($q); 
    #use Data::Dumper; 
    #warn Dumper($additional_schedule_params); 
    
    for(%$additional_schedule_params){ 
       # warn '$_:' . $_; 
       #warn '$additional_schedule_params->{$_} ' . $additional_schedule_params->{$_}; 
        $q->param($_, $additional_schedule_params->{$_}); 
    }
    return $q;

}

sub create_from_stationery {
    my $self    = shift;
    my ($args)  = @_;
    my $q_draft = $self->fetch(
        {
            -id     => $args->{-id},
            -screen => $args->{-screen},
            -role   => 'stationery',
        }
    );

    my $saved_draft_id = $self->save(
        {
            -cgi_obj   => $q_draft,
            -role      => 'draft',
            -save_role => 'draft', 
            -screen    => $args->{-screen},
        }
    );
    warn '$saved_draft_id' . $saved_draft_id
		if $t; 
    return $saved_draft_id;
}


sub count {
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }

    my @row;
    my $query = 'SELECT COUNT(*) FROM ' . $self->{sql_params}->{message_drafts_table} . ' WHERE list = ? AND role = ?';

#    warn 'QUERY: ' . $query
#      if $t;

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
       # warn q{$q->param('schedule_single_ctime')} . $q->param('schedule_single_ctime'); 
        
#        warn q{$q->param('schedule_html_body_checksum') } . $q->param('schedule_html_body_checksum');
        my $params = {
            id                            => $hashref->{id},
            list                          => $hashref->{list},
            created_timestamp             => $hashref->{created_timestamp},
            last_modified_timestamp       => $hashref->{last_modified_timestamp},
            screen                        => $hashref->{screen},
            role                          => $hashref->{role},
			# so curious I have to do this here, but not in the ind. draft screen... 
            Subject                       => safely_decode(scalar $q->param('Subject')),

            schedule_activated             => scalar $q->param('schedule_activated'),
            schedule_type                  => scalar $q->param('schedule_type'),
            schedule_single_ctime          => scalar $q->param('schedule_single_ctime'),
            schedule_recurring_days        => [$q->multi_param('schedule_recurring_days')],
            schedule_recurring_ctime_start => scalar $q->param('schedule_recurring_ctime_start'),
            schedule_recurring_ctime_end   => scalar $q->param('schedule_recurring_ctime_end'),
            schedule_recurring_hms         => scalar $q->param('schedule_recurring_hms'),

            schedule_html_body_checksum    => scalar $q->param('schedule_html_body_checksum'), 
            
            schedule_recurring_only_mass_mail_if_primary_diff => scalar $q->param('schedule_recurring_only_mass_mail_if_primary_diff'), 
            
        };

        # This sort of gets around the problem of having subject fetched from the webpage's <title>:
        if(scalar $q->param('subject_from') eq 'title_tag') { 
            $params->{Subject} = '(from webpage title tag)';
        }

        if ( $args->{-role} eq 'schedule')
        {
            my $additional_schedule_params = $self->additional_schedule_params($q); 
            for(%$additional_schedule_params){ 
                $params->{$_} = $additional_schedule_params->{$_}; 
            }
        }
        push( @$r, $params );        
    }
    $sth->finish;
    
    if($args->{-role} eq 'schedule'){ 
        $r = $self->sort_by_schedule($r); 
    }
    
    
    return $r;
}


sub additional_schedule_params { 
    my $self = shift; 
    my $q    = shift; 
    my $schedule_params = {}; 
                
    # backwards compat.
    if(
        defined($q->param('schedule_datetime'))
      &&  !defined($q->param('schedule_type'))
      ) { 
          $schedule_params->{schedule_type} = 'single';  
    }
    
    if( defined($q->param('schedule_datetime'))
    && !defined($q->param('schedule_single_ctime'))
    ){ 
        $schedule_params->{'schedule_single_ctime'} = $q->param('schedule_datetime');
    }
    
    $schedule_params->{schedule_single_displaydatetime}            = ctime_to_displaytime(  scalar $q->param('schedule_single_ctime')); 
    $schedule_params->{schedule_single_localtime}                  = ctime_to_localtime(    scalar $q->param('schedule_single_ctime')); 
    $schedule_params->{schedule_recurring_displaydatetime_start}   = ctime_to_displaytime(  (scalar $q->param('schedule_recurring_ctime_start')), 0); 
    $schedule_params->{schedule_recurring_displaydatetime_end}     = ctime_to_displaytime(  (scalar $q->param('schedule_recurring_ctime_end')),   0); 
    $schedule_params->{schedule_recurring_localtime_start}         = ctime_to_localtime(    scalar $q->param('schedule_recurring_ctime_start')); 
    $schedule_params->{schedule_recurring_localtime_end}           = ctime_to_localtime(    scalar $q->param('schedule_recurring_ctime_end')); 
    $schedule_params->{schedule_recurring_display_hms}             = hms_to_dislay_hms(     scalar $q->param('schedule_recurring_hms')); 
    
    return $schedule_params; 
}

sub sort_by_schedule { 
    my $self = shift; 
    my $r    = shift; 
    my $s    = []; 
    
    # Kinda wrong, now that we have recurring schedules. 
    foreach my $row (sort { $a->{schedule_single_ctime} <=> $b->{schedule_single_ctime} } @$r ) {
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

        local_archive_options_present  => 1, 
        archive_message                => 1,
        archive_no_send                => 1,
        back_date                      => 1,
        backdate_datetime              => 1,
        test_recipient                 => 1,
        Subject                        => 1,
        subject_from                   => 1,
		'X-Preheader'                  => 1,  
        schedule_activated             => 1,
        schedule_type                  => 1,
        
        # schedule_datetime            => 1, # No longer used, schedule_single_ctime is used instead. 
        schedule_single_ctime          => 1,
        schedule_recurring_days        => 1,
        schedule_recurring_ctime_start => 1,
        schedule_recurring_ctime_end   => 1,
        schedule_recurring_hms         => 1,
        
        schedule_html_body_checksum    => 1,
        
        schedule_recurring_only_mass_mail_if_primary_diff => 1, 
		
		layout                         => 1,
        

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
	
    $params->{attachment1} = 1;
    $params->{attachment2} = 1;
    $params->{attachment3} = 1;
    $params->{attachment4} = 1;
    $params->{attachment5} = 1;
	
    if ( $args->{-screen} eq 'send_email' ) {
		#... 
    }
    elsif ( $args->{-screen} eq 'send_url_email' ) {

        $params->{content_from}          = 1;
        $params->{url}                   = 1;
        $params->{url_options}           = 1;
        $params->{remove_javascript}     = 1;
        
        $params->{plaintext_content_from} = 1;
        $params->{plaintext_url}          = 1;
        
        # These aren't used atm. 
        #$params->{url_username}          = 1;
        #$params->{url_password}          = 1;
        #$params->{proxy}                 = 1;
        
        $params->{crop_html_content}                = 1;
        $params->{crop_html_content_selector_type}  = 1;
        $params->{crop_html_content_selector_label} = 1;
    }

    # use Data::Dumper;
    # warn 'params_to_save:' . Dumper($params);

    return $params;

}




sub enabled {
    my $self = shift; 
    return 1;
}

1;
