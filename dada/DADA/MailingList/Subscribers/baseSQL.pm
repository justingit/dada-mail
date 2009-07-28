package DADA::MailingList::Subscribers::baseSQL;

use strict;

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib);

use Carp qw(croak carp confess);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

#my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};

my $t = 1; 

use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB
);

sub inexact_match {

    my $self = shift;
    my ($args) = @_;
    my $email = cased( $args->{ -email } );
    my ( $name, $domain ) = split ( '@', $email );

    my $query .= 'SELECT COUNT(*) ';

    $query .= ' FROM ' . $self->{sql_params}->{subscriber_table} . ' WHERE ';
    $query .= ' list_type = ? AND';
    $query .= ' list_status = 1';
    if (   $args->{ -against } eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {

        # ...
    }
    else {
        $query .= ' AND list = ?';
    }
    $query .= ' AND (email = ? OR email LIKE ? OR email LIKE ?)';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    if (   $args->{ -against } eq 'black_list'
        && $DADA::Config::GLOBAL_BLACK_LIST == 1 )
    {
        $sth->execute(
            $args->{ -against },
            $email,
            $name . '@%',
            '%@' . $domain,
          )
          or croak "cannot do statment (inexact_match)! $DBI::errstr\n";

    }
    else {
        $sth->execute(
            $args->{ -against },
            $self->{list},
            $email,
            $name . '@%',
            '%@' . $domain,

          )
          or croak "cannot do statment (inexact_match)! $DBI::errstr\n";
    }

    my @row = $sth->fetchrow_array();
    $sth->finish;

    if ( $row[0] >= 1 ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub search_list {

    my $self = shift;

    my ($args) = @_;

    if ( !exists( $args->{ -start } ) ) {
        $args->{ -start } = 1;
    }
    if ( !exists( $args->{'-length'} ) ) {
        $args->{'-length'} = 100;
    }

    my $r = [];

    my $partial_listing = {};

    my $fields = $self->subscriber_fields;
    foreach (@$fields) {
        $partial_listing->{$_} = { like => $args->{ -query } };
    }

    # Do I have to do this, explicitly?
    $partial_listing->{email} = { like => $args->{ -query } };

    my $query = $self->SQL_subscriber_profile_join_statement(
        {
            -type            => $args->{ -type },
            -partial_listing => $partial_listing,
            -search_type     => 'any',
        }
    );

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statment (for search_list)! $DBI::errstr\n";

    my $row   = {};
    my $count = 0;

    while ( $row = $sth->fetchrow_hashref ) {

        $count++;
        next if $count < $args->{ -start };
        last if $count > ( $args->{ -start } + $args->{'-length'} );

        my $info = {};
        $info->{email}     = $row->{email};
        $info->{list_type} = $args->{ -type };    # Whazza?!

        delete( $row->{email} );
        $info->{fields} = [];

        #    foreach(keys %$row){
        foreach (@$fields) {
            push ( @{ $info->{fields} }, { name => $_, value => $row->{$_} } );
        }

        push ( @$r, $info );

    }

    $sth->finish();

    return $r;

}

sub SQL_subscriber_profile_join_statement {

    my $self = shift;
    my ($args) = @_;

    # Args
    # -partial_listing
    # -type
    # -search_type (any/all)
    # -list
    #

    # init vars:

    # type list black_List, white_listed, etc
    if ( !$args->{ -type } ) {
        $args->{ -type } = 'list';
    }

    # Sanity Check.
    if ( !exists( $self->allowed_list_types()->{ $args->{ -type } } ) ) {
        croak '"' . $args->{ -type } . '" is not a valid list type! ';
    }

# Right now, we can either have an any/all boolean type of thing. "OR" is used for
# searches, I'm not sure if this would be helpful for the Partial List Sending stuff.

    my $query_type = 'AND';
    if ( !$args->{ -search_type } ) {
        $args->{ -search_type } = 'all';
    }
    if ( $args->{ -search_type } !~ /any|all/ ) {
        $args->{ -search_type } = 'all';
    }
    if ( $args->{ -search_type } eq 'any' ) {
        $query_type = 'OR';
    }

    my $subscriber_table     = $self->{sql_params}->{subscriber_table};
    my $profile_fields_table = $self->{sql_params}->{profile_fields_table};

    # This is to select which profile fields to return with our query
    my @merge_fields      = @{ $self->subscriber_fields };
    my $merge_field_query = '';
    foreach (@merge_fields) {
        $merge_field_query .= ', ' . $profile_fields_table . '.' . $_;
    }

    #/ This is to select which profile fields to return with our query

    # We need the email and list from $subscriber_table
    my $query;
    $query =
      'SELECT ' . $subscriber_table . '.email, ' . $subscriber_table . '.list';
    $query .= $merge_field_query;

# And we need to match this with the info in $profile_fields_table - this fast/slow?
    $query .= ' FROM '
      . $subscriber_table
      . ' LEFT OUTER JOIN '
      . $profile_fields_table . ' ON ';
    $query .= ' '
      . $subscriber_table
      . '.email' . ' = '
      . $profile_fields_table
      . '.email';

    # Global Black List (we're still using this?) spans across all lists.
    $query .= ' WHERE  ';
    if (   $DADA::Config::GLOBAL_BLACK_LIST
        && $args->{ -type } eq 'black_list' )
    {

        #... Nothin'
    }
    else {

        $query .=
          $subscriber_table . '.list = ' . $self->{dbh}->quote( $self->{list} );

    }

    # list_status is almost always 1
    $query .= ' AND '
      . $subscriber_table
      . '.list_type = '
      . $self->{dbh}->quote( $args->{ -type } );
    $query .=
      ' AND ' . $subscriber_table . '.list_status = ' . $self->{dbh}->quote(1);

    # This is all to query the $dada_profile_fields_table
    # The main thing, is that we only want the SQL statement to hold
    # fields that we're actually looking for.

    if ( keys %{ $args->{ -partial_listing } } ) {

        # This *really* needs its own method, as well...
        # It's somewhat strange, as this relies on the email address in the
        # profile (I think?) to work, if we're looking for email addresses...

        my @add_q = ();
        foreach ( keys %{ $args->{ -partial_listing } } ) {

            # This is to make sure we're always using the email from the
            # subscriber table - this stops us from not seeing an email
            # address that doesn't have a profile...
            my $table = $profile_fields_table;
            if ( $_ eq 'email' ) {
                $table = $subscriber_table;
            }

            # /

            if ( exists( $args->{ -partial_listing }->{$_}->{equal_to} ) ) {
                if (
                    length( $args->{ -partial_listing }->{$_}->{equal_to} ) >
                    0 )
                {
                    push (
                        @add_q,
                        $table . '.' . $_ . ' = '
                          . $self->{dbh}->quote(
                            $args->{ -partial_listing }->{$_}->{equal_to}
                          )
                    );
                }
            }
            elsif ( exists( $args->{ -partial_listing }->{$_}->{like} ) ) {
                if ( length( $args->{ -partial_listing }->{$_}->{like} ) > 0 ) {
                    push (
                        @add_q,
                        $table . '.' . $_ . ' LIKE '
                          . $self->{dbh}->quote(
                            '%'
                              . $args->{ -partial_listing }->{$_}->{like} . '%'
                          )
                    );
                }
            }
        }
        my $query_pl;
        if ( $add_q[0] ) {
            $query_pl =
              ' AND ( ' . join ( ' ' . $query_type . ' ', @add_q ) . ') ';
            $query .= $query_pl;
        }
    }

   # -exclude_from is to return results from subscribers who *aren't* subscribed
   # to another list.

    if ( exists( $args->{ -exclude_from } ) ) {
        if ( $args->{ -exclude_from }->[0] ) {
            my @excludes = ();
            foreach my $ex_list ( @{ $args->{ -exclude_from } } ) {
                push ( @excludes,
                    $subscriber_table
                      . '.list = '
                      . $self->{dbh}->quote($ex_list) );
            }
            my $ex_from_query = ' AND '
              . $subscriber_table
              . '.email NOT IN (SELECT '
              . $subscriber_table
              . '.email FROM '
              . $subscriber_table
              . ' WHERE '
              . join ( ' OR ', @excludes ) . ' ) ';
            $query .= $ex_from_query;
        }
    }

    # /

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
        $query .= ' ORDER BY '
          . $subscriber_table
          . '.email, '
          . $subscriber_table . '.list';
    }

    warn 'QUERY: ' . $query
      if $t;

    return $query;
}


sub fancy_print_out_list {

    my $count = 0;

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -type } ) ) {
        croak
'you must supply the type of list we are looking at in, the "-type" paramater';
    }

    if ( !exists( $args->{ -FH } ) ) {
        $args->{ -FH } = \*STDOUT;
    }
    my $fh = $args->{ -FH };

    if ( !exists( $args->{ -partial_listing } ) ) {
        $args->{ -partial_listing } = {};
    }

    my $subscribers = $self->subscription_list($args);
    foreach (@$subscribers) {
        $_->{no_email_links} = 1;
        $_->{no_checkboxes}  = 1;
    }

    my $field_names = [];
    foreach ( @{ $self->subscriber_fields } ) {
        push ( @$field_names, { name => $_ } );
    }

    require DADA::Template::Widgets;
    print $fh DADA::Template::Widgets::screen(
        {
            -screen => 'fancy_print_out_list_widget.tmpl',
            -vars   => {
                field_names    => $field_names,
                subscribers    => $subscribers,
                no_checkboxes  => 1,
                no_email_links => 1,
                count          => scalar @{$subscribers},
            }
        }
    );

    return scalar @{$subscribers};

}

sub print_out_list {

    my $self = shift;

    my %args = (
        -FH => \*STDOUT,
        @_
    );
    my $fh = $args{ -FH };

    my $count;

    my $query =
      $self->SQL_subscriber_profile_join_statement(
        { -type => $args{ -Type }, } );

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statment (for print out list)! $DBI::errstr\n";

    my $fields = $self->subscriber_fields;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    my $hashref = {};

    my @header = ('email');
    foreach (@$fields) {
        push ( @header, $_ );
    }

    if ( $csv->combine(@header) ) {

        my $hstring = $csv->string;
        print $fh $hstring, "\n";

    }
    else {

        my $err = $csv->error_input;
        carp "combine() failed on argument: ", $err, "\n";

    }

    while ( $hashref = $sth->fetchrow_hashref ) {

        my @info = ( $hashref->{email} );

        foreach (@$fields) {

# DEV: Do we remove newlines here? Huh?
# BUG: [ 2147102 ] 3.0.0 - "Open List in New Window" has unwanted linebreak?
# https://sourceforge.net/tracker/index.php?func=detail&aid=2147102&group_id=13002&atid=113002
            $hashref->{$_} =~ s/\n|\r/ /gi;
            push ( @info, $hashref->{$_} );

        }

        if ( $csv->combine(@info) ) {
            my $string = $csv->string;
            print $fh $string, "\n";
        }
        else {
            my $err = $csv->error_input;

            # carp "combine() failed on argument: ", $err, "\n";

            carp "combine() failed on argument: "
              . $csv->error_input
              . " attempting to encode values and try again...";
            require CGI;

            my @new_info = ();
            foreach my $chunk (@info) {
                push ( @new_info, CGI::escapeHTML($chunk) );
            }
            if ( $csv->combine(@new_info) ) {
                my $hstring2 = $csv->string;
                print $fh $hstring2, "\n";
                carp "that worked.";
            }
            else {
                carp "nope, that didn't work - combine() failed on argument: "
                  . $csv->error_input;

            }

        }

        $count++;
    }

    $sth->finish;
    return $count;

}

sub subscription_list {

    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{ -start } ) ) {
        $args->{ -start } = 1;
    }

    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }

    my $email;
    my $count  = 0;
    my $list   = [];
    my $fields = $self->subscriber_fields;

    if ( !exists( $args->{ -partial_listing } ) ) {
        $args->{ -partial_listing } = {};
    }

    my $query = $self->SQL_subscriber_profile_join_statement($args);
    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statment (for subscription_list)! $DBI::errstr\n";

    my $hashref;
    my %mf_lt = ();
    foreach (@$fields) {
        $mf_lt{$_} = 1;
    }

    while ( $hashref = $sth->fetchrow_hashref ) {

        $count++;

        next if $count < $args->{ -start };

        if ( exists( $args->{'-length}'} ) ) {

            last if $count > ( $args->{ -start } + $args->{'-length'} );

        }

		# Probably, just add it here? 
		$hashref->{type} = $args->{-type}; 

        $hashref->{fields} = [];

        foreach (@$fields) {

            if ( exists( $mf_lt{$_} ) ) {
                push (
                    @{ $hashref->{fields} },
                    {
                        name  => $_,
                        value => $hashref->{$_}
                    }
                );
                delete( $hashref->{$_} );
            }

        }

        push ( @$list, $hashref );

    }

    return $list;

}

sub filter_list_through_blacklist {

    my $self = shift;
    my $list = [];

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = 'black_list' AND list_status = 1";

    if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

        # Nothin'
    }
    else {
        $query .= ' AND list = ?';
    }

    my $sth = $self->{dbh}->prepare($query);

    if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

        $sth->execute()
          or croak
          "cannot do statment (filter_list_through_blacklist)! $DBI::errstr\n";

    }
    else {

        $sth->execute( $self->{list} )
          or croak
          "cannot do statment (filter_list_through_blacklist)! $DBI::errstr\n";
    }

    my $hashref;
    my $hashref2;

    # Hmm. This seems a little... expensive.

    while ( $hashref = $sth->fetchrow_hashref ) {

        my $query2 =
          'SELECT * from '
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list_type   = 'list' 
		               AND   list_status =   1 
		               AND   list        =   ? 
		               AND   email      LIKE ?";

        my $sth2 = $self->{dbh}->prepare($query2);
        $sth2->execute( $self->{list}, '%' . $hashref->{email} . '%' )
          or croak
          "cannot do statment (filter_list_through_blacklist)! $DBI::errstr\n";

        while ( $hashref2 = $sth2->fetchrow_hashref ) {
            push ( @$list, $hashref2 );
        }

    }

    return $list;

}

# DEV: This is in need of a rewrite.
# Too bad it works *as is*
# but, it's messy stuff.

sub check_for_double_email {

    my $self = shift;
    my %args = (
        -Email      => undef,
        -Type       => 'list',
        -Status     => 1,
        -Match_Type => 'sublist_centric',
        @_
    );
    my @list;

    if ( $self->{list} and $args{ -Email } ) {

        $args{ -Email } = strip( $args{ -Email } );
        $args{ -Email } = cased( $args{ -Email } );

        if (   $args{ -Type } eq 'black_list'
            && $args{ -Match_Type } eq 'sublist_centric' )
        {

            my $query =
              "SELECT email FROM "
              . $self->{sql_params}->{subscriber_table}
              . " WHERE list_type = ? AND list_status = ?";

            if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

                # ... nothin'
            }
            else {

                $query .= ' AND list = ?';
            }

            my $sth = $self->{dbh}->prepare($query);

            if ( $DADA::Config::GLOBAL_BLACK_LIST == 1 ) {

                $sth->execute( $args{ -Type }, $args{ -Status } )
                  or croak
"cannot do statment (for check for double email)! $DBI::errstr\n";

            }
            else {

                $sth->execute( $args{ -Type }, $args{ -Status }, $self->{list} )
                  or croak
"cannot do statment (for check for double email)! $DBI::errstr\n";

            }

            while ( ( my $email ) = $sth->fetchrow_array ) {

                $email = quotemeta($email);

                next if !$email || $email eq '';

                if ( DADA::App::Guts::cased( $args{ -Email } ) =~ m/$email/i ) {
                    return 1;
                }
            }
            return 0;

        }

        elsif ($args{ -Type } eq 'white_list'
            && $args{ -Match_Type } eq 'sublist_centric' )
        {

            my $query =
              "SELECT email FROM "
              . $self->{sql_params}->{subscriber_table}
              . " WHERE list_type = ? AND list_status = ?";
            $query .= " AND list = ?";

            my $sth = $self->{dbh}->prepare($query);

            $sth->execute( $args{ -Type }, $args{ -Status }, $self->{list} )
              or croak
              "cannot do statment (for check for double email)! $DBI::errstr\n";

            while ( ( my $email ) = $sth->fetchrow_array ) {

                $email = quotemeta($email);

                next if !$email || $email eq '';

                if ( DADA::App::Guts::cased( $args{ -Email } ) =~ m/$email/i ) {
                    return 1;
                }
            }
            return 0;

        }
        else {
            my $sth =
              $self->{dbh}->prepare( "SELECT email FROM "
                  . $self->{sql_params}->{subscriber_table}
                  . " WHERE list = ? AND list_type = ? AND email= ? AND list_status = ?"
              );

            $sth->execute(
                $self->{list},
                $args{ -Type },
                $args{ -Email },
                $args{ -Status }
              )
              or croak
              "cannot do statment (for check for double email)! $DBI::errstr\n";
            while ( ( my $email ) = $sth->fetchrow_array ) {
                push ( @list, $email );
            }
            my $in_list = 0;
            if ( $list[0] ) {
                $in_list = 1;
            }
            $sth->finish;
            return $in_list;
        }
    }
    else {
        return 0;
    }
}

sub num_subscribers {

    my $self = shift;
    my %args = (
        -Type => 'list',
        @_
    );
    my @row;

    my $query = '';

    $query .= 'SELECT COUNT(*) ';
    $query .= ' FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE list_type = ? AND list_status = 1 ';

    $query .= ' AND list = ?';

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $args{ -Type }, $self->{list} )
      or croak "cannot do statment (num_subscribers)! $DBI::errstr\n";
    @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];
}

sub remove_from_list {

    my $self = shift;

    carp
"This method (DADA::MailingList::Subscribers::baseSQL::remove_from_list) is deprecated. Please use, remove_subscriber() instead.";

    my %args = (
        -Email_List => [],
        -Type       => "list",
        @_
    );
    my $addresses = $args{ -Email_List };

    my $count = 0;
    require DADA::MailingList::Subscriber;
    foreach my $sub (@$addresses) {
        chomp($sub);    #?
        my $s = DADA::MailingList::Subscriber->new(
            {
                -list  => $self->{list},
                -email => $sub,
                -type  => $args{ -Type },
            }
        );

        my $remove = $s->remove;

        if ( $remove == 1 ) {
            $count = $count + 1;
        }
    }
    return $count;
}

sub remove_all_subscribers {

    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{ -type } ) {
        $args->{ -type } = 'list';
    }

    my $query =
      'SELECT email FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = '"
      . $args->{ -type } . "' 
                  AND list_status =      1  
                  AND list = '" . $self->{list} . "'";

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak
      "cannot do statement (at remove_all_subscribers)! $DBI::errstr\n";

    my $count = 0;
    while ( ( my $email ) = $sth->fetchrow_array ) {
        $self->remove_subscriber(
            {
                -email => $email,
                -type  => $args->{ -type },
            }
        );
        $count++;
    }

    return $count;
}

sub create_mass_sending_file {

    my $self = shift;

    my %args = (
        -Type            => 'list',
        -Pin             => 1,
        -ID              => undef,
        -Ban             => undef,
        -Bulk_Test       => 0,
        -Save_At         => undef,
        -Test_Recipient  => undef,
        -partial_sending => {},
        -exclude_from    => [],
        @_
    );

    my $list = $self->{list};
    my $type = $args{ -Type };

    my @f_a_lists = available_lists();
    my %list_names;
    foreach (@f_a_lists) {
        my $als = DADA::MailingList::Settings->new( { -list => $_ } );
        my $ali = $als->get;
        $list_names{$_} = $ali->{list_name};
    }

    $list =~ s/ /_/g;    # really...

    my ( $sec, $min, $hour, $day, $month, $year ) =
      (localtime)[ 0, 1, 2, 3, 4, 5 ];
    my $message_id = sprintf(
        "%02d%02d%02d%02d%02d%02d",
        $year + 1900,
        $month + 1, $day, $hour, $min, $sec
    );

    #use the message ID, If we have one.
    my $letter_id = $args{'-ID'} || $message_id;
    $letter_id =~ s/\@/_at_/g;
    $letter_id =~ s/\>|\<//g;

    my $n_msg_id = $args{'-ID'} || $message_id;
    $n_msg_id =~ s/\<|\>//g;
    $n_msg_id =~ s/\.(.*)//;    #greedy

    my %banned_list;

    if ( $args{ -Ban } ) {
        my $banned_list = $args{ -Ban };
        $banned_list{$_} = 1 foreach (@$banned_list);
    }

    my $list_file =
      make_safer( $DADA::Config::FILES . '/' . $list . '.' . $type );
    my $sending_file = make_safer( $args{ -Save_At } )
      || make_safer(
        $DADA::Config::TMP . '/msg-' . $list . '-' . $type . '-' . $letter_id );

    #open one file, write to the other.
    my $email;

    open my $SENDINGFILE, '>', $sending_file
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Cannot create temporary email list file for sending out bulk message: $!";
    chmod( $SENDINGFILE, $DADA::Config::FILE_CHMOD );
    flock( $SENDINGFILE, LOCK_EX );

    my $first_email = $self->{ls}->param('list_owner_email');
    if ( $args{'-Bulk_Test'} == 1 && $args{ -Test_Recipient } ) {
        $first_email = $args{ -Test_Recipient };
    }

    my $to_pin = make_pin( -Email => $first_email, -List => $self->{list} );

    my ( $lo_e_name, $lo_e_domain ) = split ( '@', $first_email );

    my $total = 0;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
    my @lo  = (
        $first_email, $lo_e_name, $lo_e_domain, $to_pin, $self->{list},
        $list_names{ $self->{list} }, $n_msg_id,
    );
    if ( $csv->combine(@lo) ) {
        my $hstring = $csv->string;
        print $SENDINGFILE $hstring, "\n";
    }
    else {
        my $err = $csv->error_input;
        carp "combine() failed on argument: ", $err, "\n";
    }
    $total++;

    # TODO: these three lines need to be one
    # And tell me why I have to chomp, "bulk test"
    my $test_test = $args{'-Bulk_Test'};
    chomp($test_test);    #Why Chomp?!
    unless ( $test_test == 1 ) {

        my $query = $self->SQL_subscriber_profile_join_statement(
            {
                -type            => $args{ -Type },
                -partial_listing => $args{ -partial_sending },
                -exclude_from    => $args{ -exclude_from },
            }
        );

        my $sth = $self->{dbh}->prepare($query);

        $sth->execute()
          or croak "cannot do statement (at create mass_sending_file)! $DBI::errstr\n";

        my $field_ref;

        while ( $field_ref = $sth->fetchrow_hashref ) {

            chomp $field_ref->{email};    #new..

            unless ( exists( $banned_list{ $field_ref->{email} } ) ) {

                my @sub = (
                    $field_ref->{email},
                    ( split ( '@', $field_ref->{email} ) ),
                    make_pin(
                        -Email => $field_ref->{email},
                        -List  => $self->{list}
                    ),
                    $field_ref->{list},
                    $list_names{ $field_ref->{list} },
                    $n_msg_id,
                );

                foreach ( @{ $self->subscriber_fields } ) {
                    if ( defined( $field_ref->{$_} ) ) {
                        chomp $field_ref->{$_};
                        $field_ref->{$_} =~ s/\n|\r/ /g;
                    }
                    else {
                        $field_ref->{$_} = '';
                    }

                    push ( @sub, $field_ref->{$_} );

                }
                if ( $csv->combine(@sub) ) {
                    my $hstring = $csv->string;
                    print $SENDINGFILE $hstring, "\n";
                }
                else {
                    my $err = $csv->error_input;
                    carp "combine() failed on argument: ", $err, "\n";
                }
                $total++;
            }

        }

        $sth->finish;
    }

    close($SENDINGFILE)
      or croak(
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - could not close temporary sending  file '$sending_file' successfully"
      );

    return ( $sending_file, $total );

}

sub unique_and_duplicate {

    my $self = shift;

    my %args = (
        -New_List => undef,
        -Type     => 'list',
        @_,
    );

    # first thing we got to do is to make a lookup hash.
    my %lookup_table;
    my $address_ref = $args{ -New_List };

    if ($address_ref) {

        foreach (@$address_ref) { $lookup_table{$_} = 0 }

        my $email;

        my $sth = $self->{dbh}->prepare(
            "SELECT email FROM "
              . $self->{sql_params}->{subscriber_table}
              . " WHERE list = ? 
	                                      AND list_type = ?
	                                      AND  list_status   = 1"
        );
        $sth->execute( $self->{list}, $args{ -Type } )
          or croak
          "cannot do statement (at unique_and_duplicate)! $DBI::errstr\n";
        while ( ( my $email ) = $sth->fetchrow_array ) {
            chomp($email);
            $lookup_table{$email} = 1 if ( exists( $lookup_table{$email} ) );

            #nabbed it,
        }
        $sth->finish;

        #lets lookie and see what we gots.
        my @unique;
        my @double;
        my $value;

        foreach ( keys %lookup_table ) {
            $value = $lookup_table{$_};
            if ( $value == 1 ) {
                push ( @double, $_ );
            }
            else {
                push ( @unique, $_ );
            }
        }
        return ( \@unique, \@double );
    }
    else {

        carp(
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: array ref provided!"
        );
        return undef;
    }

}

sub tables {
    my $self   = shift;
    my @tables = $self->{dbh}->tables();
    return \@tables;
}

sub remove_this_listtype {
    my $self = shift;
    my %args = ( -Type => undef, @_ );

    if ( !exists( $args{ -Type } ) ) {
        croak('You MUST specific a list type in the "-Type" paramater');
    }
    else {
        if ( !exists( $self->allowed_list_types()->{ $args{ -Type } } ) ) {
            croak '"' . $args{ -Type } . '" is not a valid list type! ';
        }
    }

    my $sth = $self->{dbh}->prepare(
        "DELETE FROM "
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list    = ?
		                              AND list_type = ?"
    );
    $sth->execute( $self->{list}, $args{ -Type } )
      or croak
      "cannot do statement! (at: remove_this_listttype) $DBI::errstr\n";
    $sth->finish;
}

sub can_use_global_black_list {

    my $self = shift;
    return 1;

}

sub can_use_global_unsubscribe {

    my $self = shift;
    return 1;

}

sub can_filter_subscribers_through_blacklist {

    my $self = shift;
    return 1;
}

sub can_have_subscriber_fields {

    my $self = shift;
    return 1;
}

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999-2009 Justin Simoni All rights reserved. 

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

