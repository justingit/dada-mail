package DADA::MailingList::Subscribers::baseSQL;

use strict;

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib);

use Carp qw(croak carp confess);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};

use Fcntl qw(O_WRONLY
  O_TRUNC
  O_CREAT
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB
);

sub open_email_list {

    # TODO: Remove open_email_list method from Dada Mail
    # Currently in the program, this method is ONLY used for blacklist stuff;
    # And white list stuff.

    my $self = shift;
    my %args = (
        -Type   => 'list',
        -As_Ref => 0,
        -Sorted => 1,
        @_
    );

    my $list = $self->{list} || undef;
    if ($list) {    #why wouldn't there be a list?!
        my @list = ();

        my $query =
          'SELECT email FROM '
          . $self->{sql_params}->{subscriber_table}
          . ' WHERE list_type = ? AND list_status = 1';

       # The idea is, if you have a black_list and the global black list feature
       # is enabled, then we don't care what list the subscriber is on. Hazzah!
       #
        if ( $args{ -Type } eq 'black_list' ) {

            if ($DADA::Config::GLOBAL_BLACK_LIST) {

                #...

            }
            else {

                $query .= " AND list = ?";

            }

        }
        else {
            $query .= " AND list = ?";
        }

        #
        ###

        $query .= ' ORDER BY email'
          if $DADA::Config::LIST_IN_ORDER == 1;

        my $sth = $self->{dbh}->prepare($query);

        if (   $DADA::Config::GLOBAL_BLACK_LIST
            && $args{ -Type } eq 'black_list' )
        {

  # The Global Blacklist idea just doesn't need to know what the list to use is.
  # Thus, the different execute() params.

            $sth->execute( $args{ -Type } )
              or croak
              "cannot do statement (at: open email list)! $DBI::errstr\n";

        }
        else {

            $sth->execute( $args{ -Type }, $self->{list} )
              or croak
              "cannot do statement (at: open email list)! $DBI::errstr\n";

        }

        while ( ( my $email ) = $sth->fetchrow_array ) {
            push ( @list, $email );
        }

        $sth->finish;

        if ( $args{ -As_Ref } eq "1" ) {
            return \@list;
        }
        else {
            return @list;
        }
    }
    else {
        return undef;
    }
}

sub open_list_handle { my $self = shift; }    # not needed
sub sort_email_list  { my $self = shift; }    # not needed

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

    my $fields = $self->subscriber_fields;

    my $select_fields = '';
    foreach (@$fields) {
        $select_fields .= ', ' . $_;
    }

    my $query =
      'SELECT email'
      . $select_fields
      . ' FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE ( list_type = ? AND list_status = 1 AND list = ? )';

    warn 'query: ' . $query
      if $t;

    if ( $fields->[0] ) {

        $query .= ' AND (email like ?';

        foreach (@$fields) {
            $query .= ' OR ' . $_ . ' LIKE ? ';
        }
        $query .= ')';
    }
    else {
        $query .= ' AND (email like ?)';
    }

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
        $query .= ' ORDER BY email';
    }

    my $sth = $self->{dbh}->prepare($query);

    my @extra_params = ();
    foreach (@$fields) {
        push ( @extra_params, '%' . $args->{ -query } . '%' );
    }

    $sth->execute(
        $args->{ -type },              $self->{list},
        '%' . $args->{ -query } . '%', @extra_params
      )
      or croak "cannot do statement (at: search_list)! $DBI::errstr\n";

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

sub search_email_list {

    my $self = shift;

    my %args = (
        -Keyword   => undef,
        -Method    => undef,
        -Type      => 'list',
        -as_string => 0,
        @_
    );
    my @matches;
    my $domain_regex = "(.*)\@(.*)";
    my $found        = 0;

    my $r = '';

    my $method = $args{ -Method } || "standard";
    my $keyword = $args{ -Keyword };
    $keyword = quotemeta($keyword);

    my $type = $args{ -Type };

    my $query =
      "SELECT email FROM "
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = ? AND list_status = 1";

    if ( $DADA::Config::GLOBAL_BLACK_LIST && $args{ -Type } eq 'black_list' ) {

        # ...nothin'
    }
    else {
        $query .= " AND list = ?";
    }

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {

        $query .= ' ORDER BY email';

    }

    my $sth = $self->{dbh}->prepare($query);

    if ( $DADA::Config::GLOBAL_BLACK_LIST && $args{ -Type } eq 'black_list' ) {

        $sth->execute( $args{ -Type } )
          or croak "cannot do statment (for search_email_list)! $DBI::errstr\n";

    }
    else {
        $sth->execute( $args{ -Type }, $self->{list} )
          or croak "cannot do statment (for search_email_list)! $DBI::errstr\n";
    }

    if ( defined($keyword) && $keyword ne "" ) {
        if ( $method eq "domain" ) {
            while ( ( my $email ) = $sth->fetchrow_array ) {
                if ( $email =~ m/$domain_regex$keyword$/i ) {
                    my $str =
"<input type=\"checkbox\" name=\"address\" value=\"$email\" />&nbsp;&nbsp; <a href=\"$DADA::Config::S_PROGRAM_URL?f=edit_subscriber&amp;email=$email&amp;type=$type\">$email</a><br />\n";

                    if ( $args{ -as_string } == 1 ) {
                        $r .= $str;
                    }
                    else {
                        print $found;
                    }

                    $found++;
                }
            }
        }
        elsif ( $method eq "service" ) {
            while ( ( my $email ) = $sth->fetchrow_array ) {

                if ( $email =~ m/\@$keyword$/i ) {
                    my $str =
"<input type=\"checkbox\" name=\"address\" value=\"$email\" />&nbsp;&nbsp; <a href=\"$DADA::Config::S_PROGRAM_URL?f=edit_subscriber&amp;email=$email&amp;type=$type\">$email</a><br />\n";

                    if ( $args{ -as_string } == 1 ) {
                        $r .= $str;
                    }
                    else {
                        print $found;
                    }

                    $found++;
                }
            }
        }
        else {
            while ( ( my $email ) = $sth->fetchrow_array ) {
                if ( $email =~ m/$keyword/i ) {
                    my $str =
"<input type=\"checkbox\" name=\"address\" value=\"$email\" />&nbsp;&nbsp; <a href=\"$DADA::Config::S_PROGRAM_URL?f=edit_subscriber&amp;email=$email&amp;type=$type\">$email</a><br />\n";

                    if ( $args{ -as_string } == 1 ) {
                        $r .= $str;
                    }
                    else {
                        print $found;
                    }

                    $found++;
                }
            }
        }
    }
    $sth->finish;

    if ( $args{ -as_string } == 1 ) {
        return ( $found, $r );
    }
    else {
        return ($found);

    }
}

sub get_black_list_match {
    my $self = shift;
    my @got_black;
    my @got_white;
    my $black_list = shift;
    my $try_this   = shift;
    if ( $black_list and $try_this ) {
        my $black;
        foreach $black (@$black_list) {
            $black = quotemeta($black);
            my $try;
            foreach $try (@$try_this) {
                my $qm_try = $try;

                next if !$black || $black eq '';

                if ( $qm_try =~ m/$black/i ) {
                    push ( @got_black, $try );
                }
            }
        }
        return ( \@got_black );
    }
    else {
        return 0;
    }
}

sub fancy_print_out_list {

    # DEV: This subroutine is very very messy. Very messy.

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -type } ) ) {
        croak
'you must supply the type of list we are looking at in, the "list" paramater';
    }

    if ( !exists( $args->{ -FH } ) ) {
        $args->{ -FH } = \*STDOUT;
    }

    if ( !exists( $args->{ -partial_listing } ) ) {
        $args->{ -partial_listing } = {};
    }

    my $fields = $self->subscriber_fields;
    my $fh     = $args->{ -FH };

    print $fh
' <div style="max-height: 250px; overflow: auto; border:1px solid black;background:#fff">';

    print $fh
      '<table width="100%"><tr><td><p><strong>Email Address</strong></p></td>';
    foreach (@$fields) {
        print $fh '<td><p><strong>' . $_ . '</strong></p></td>';

    }

    print $fh '</tr>';

    my $count = 0;
    if ( $self->{list} ) {
        my $query = "SELECT ";

        # Do I want to do this kludge anymore?
        #
        # $query .= "DISTINCT "
        #	if $args->{-type} eq 'black_list'; # slight kludge.

        $query .= "*  FROM "
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list_type = ? AND list_status = 1";

        if (   $DADA::Config::GLOBAL_BLACK_LIST
            && $args->{ -type } eq 'black_list' )
        {

            #... Nothin'
        }
        else {
            $query .= " AND list = ?";
        }

        if ( keys %{ $args->{ -partial_listing } } ) {

            foreach ( keys %{ $args->{ -partial_listing } } ) {
                if ( $args->{ -partial_listing }->{$_}->{equal_to} ) {

                    $query .= ' AND ' . $_ . ' = \''
                      . $args->{ -partial_listing }->{$_}->{equal_to} . '\'';

                }
                elsif ( $args->{ -partial_listing }->{$_}->{like} ) {

                    $query .= ' AND ' . $_
                      . ' LIKE \'%'
                      . $args->{ -partial_listing }->{$_}->{like} . '%\'';

                }
            }

        }

        $query .= ' ORDER BY email'
          if $DADA::Config::LIST_IN_ORDER == 1;

        my $sth = $self->{dbh}->prepare($query);

        if (   $DADA::Config::GLOBAL_BLACK_LIST
            && $args->{ -type } eq 'black_list' )
        {

            $sth->execute( $args->{ -type } )
              or croak
              "cannot do statment (for print out list)! $DBI::errstr\n";

        }
        else {

            $sth->execute( $args->{ -type }, $self->{list} )
              or croak
              "cannot do statment (for print out list)! $DBI::errstr\n";

        }

        my $row;
        while ( $row = $sth->fetchrow_hashref ) {

            my $style = '';
            if ( $count % 2 == 0 ) {
                $style = ' style="background-color:#ccf;"';
            }
            print $fh '<tr' . $style . '>';

            print $fh '<td><p>' . $row->{email} . '</p></td>';

            foreach (@$fields) {

                print $fh '<td><p>' . $row->{$_} . '</p></td>';

            }
            print $fh '</tr>';

            $count++;
        }
        $sth->finish;

        print $fh '</table>';
        print $fh '</div>';
        print $fh '<p style="text-align:right">Total Subscribers: <strong>'
          . $count
          . '</strong></p>';

        return $count;
    }
}

sub print_out_list {

    my $self = shift;

    my %args = (
        -FH => \*STDOUT,
        @_
    );
    my $fh = $args{ -FH };

    my $count;

    my $query = "SELECT ";

    # DEV: Do I want to do this kludge anymore?
    #
    # $query .= "DISTINCT "
    #	if $args{-Type} eq 'black_list'; # slight kludge.

    $query .= " *  FROM "
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = ? AND list_status = 1";

    if (   $DADA::Config::GLOBAL_BLACK_LIST
        && $args{ -Type } eq 'black_list' )
    {

        # ...nothin'
    }
    else {
        $query .= " AND list = ?";
    }

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
        $query .= ' ORDER BY email';
    }

    my $sth = $self->{dbh}->prepare($query);

    if (   $DADA::Config::GLOBAL_BLACK_LIST
        && $args{ -Type } eq 'black_list' )
    {

        $sth->execute( $args{ -Type } )
          or croak "cannot do statment (for print out list)! $DBI::errstr\n";

    }
    else {

        $sth->execute( $args{ -Type }, $self->{list} )
          or croak "cannot do statment (for print out list)! $DBI::errstr\n";

    }

    my $fields = $self->subscriber_fields;

    require Text::CSV;

#my $csv = Text::CSV->new; # Why not the params that are set in DADA::App::Guts?
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

    my %args = (
        -start    => 1,
        '-length' => 100,
        -Type     => 'list',
        @_
    );

    my $email;
    my $count = 0;
    my $list  = [];

    my $query = 'SELECT ';
    $query .= ' * FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE list_type = ? AND list_status = 1';
    $query .= ' AND list = ?';

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
        $query .= ' ORDER BY email';
    }

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args{ -Type }, $self->{list} )
      or croak "cannot do statment (for subscription_list 1)! $DBI::errstr\n";

    my $hashref;
    my $merge_fields = $self->subscriber_fields;
    my %mf_lt        = ();

    foreach (@$merge_fields) {
        $mf_lt{$_} = 1;
    }

    while ( $hashref = $sth->fetchrow_hashref ) {
        $count++;
        next if $count < $args{ -start };
        last if $count > ( $args{ -start } + $args{'-length'} );

        $hashref->{fields} = [];

        foreach (@$merge_fields) {

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

    # if($args{-Type} eq 'black_list'){  # slight kludge.
    #	$query .= 'SELECT COUNT(DISTINCT email) ';
    # }else{
    $query .= 'SELECT COUNT(*) ';

    #}

    $query .= ' FROM '
      . $self->{sql_params}->{subscriber_table}
      . ' WHERE list_type = ? AND list_status = 1 ';

    $query .= ' AND list = ?';

#   	unless $DADA::Config::GLOBAL_BLACK_LIST  == 1 && $args{-Type} eq 'black_list';

    my $sth = $self->{dbh}->prepare($query);

    #if($DADA::Config::GLOBAL_BLACK_LIST  == 1 && $args{-Type} eq 'black_list'){
    #	$sth->execute($args{-Type})
    #		or croak "cannot do statment (num_subscribers)! $DBI::errstr\n";
    #}else{
    $sth->execute( $args{ -Type }, $self->{list} )
      or croak "cannot do statment (num_subscribers)! $DBI::errstr\n";

    #}

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
        $s->remove;
        $count++;
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

sub list_option_form {

    my $self = shift;

    my %args = (
        -Type     => 'list',
        -In_Order => 0,
        @_,
    );

    if ( defined( $self->{list} ) ) {

        #make the 'Show Domains' Hash
        my %domains;
        foreach (@DADA::Config::DOMAINS) { $domains{$_} = 0; }
        $domains{Other} = 0;

        #make the 'Show Services' Hash
        my %SERVICES;
        foreach (@DADA::Config::SERVICES) { $SERVICES{$_} = 0; }

        my $email;
        my $count = 0;

        my $test = 0;
        $test =
          $DADA::Config::SHOW_DOMAIN_TABLE + $DADA::Config::SHOW_SERVICES_TABLE;

        unless ( $test == 0 ) {

            #this is a stupid, dumb, idiotic idea, but, people want it.
            if ( $args{ -In_Order } == 1 ) {
                $self->sort_email_list(%args);
            }

            my $query =
              'SELECT email FROM '
              . $self->{sql_params}->{subscriber_table}
              . ' WHERE list = ? AND list_type = ? AND list_status = 1';
            $query .= ' ORDER BY email' if $DADA::Config::LIST_IN_ORDER == 1;

            my $sth = $self->{dbh}->prepare($query);

            $sth->execute( $self->{list}, $args{ -Type } )
              or croak "cannot do statement! $DBI::errstr\n";
            while ( ( my $email ) = $sth->fetchrow_array ) {
                chomp($email);

                # this is the 'Show Domains' Hash Generator

                if ( $DADA::Config::SHOW_DOMAIN_TABLE == 1 ) {
                    my $domain_email = $email;

                    #delete everything before the first . after the @.
                    $domain_email =~ s/^(.*)@//;

                    #lowercase the ending..
                    $domain_email = lc($domain_email);

                    #strip everything before the last .
                    $domain_email =~ s/^(.*?)\.//;

                    # hey, if it matches, recorde it.
                    if ( exists( $domains{$domain_email} ) ) {
                        $domains{$domain_email}++;
                    }
                    else {
                        $domains{Other}++;
                    }
                }

                # Here be the 'Show Services' Hash Generator;
                if ( $DADA::Config::SHOW_SERVICES_TABLE == 1 ) {
                    my $services_email = $email;

                    #delete everything before the first . after the @.
                    $services_email =~ s/(^.*)@//;

                    #lowercase the ending..
                    $services_email = lc($services_email);

                    # hey, if it matches, record it.
                    if ( exists( $SERVICES{$services_email} ) ) {
                        $SERVICES{$services_email}++;
                    }
                    else {
                        $SERVICES{Other}++;
                    }
                }
                $count++;

            }
            $sth->finish;
        }
        return ( $count, \%domains, \%SERVICES );

    }
    else {
        return undef;
    }

}

sub create_mass_sending_file {

    my $self = shift;

    my %args = (
        -Type      => 'list',
        -Pin       => 1,
        -ID        => undef,
        -Ban       => undef,
        -Bulk_Test => 0,

        # Disabled, atm
        # -Sending_Lists    => [],

        -Save_At => undef,

        -Test_Recipient => undef,

        -partial_sending => {},
        @_
    );

    my $list = $self->{list};
    my $type = $args{ -Type };

    #my $also_send_to = $args{-Sending_Lists};
    #my $clean_also_send_to = [];

    #foreach(@$also_send_to){
    #	next if $_ eq $self->{list};
    #	push(@$clean_also_send_to, $_);
    #}

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

    sysopen( SENDINGFILE, "$sending_file", O_RDWR | O_CREAT,
        $DADA::Config::FILE_CHMOD )
      or croak
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Cannot create temporary email list file for sending out bulk message: $!";
    flock( SENDINGFILE, LOCK_EX );

    my $first_email = $self->{ls}->param('list_owner_email');
    if ( $args{'-Bulk_Test'} == 1 && $args{ -Test_Recipient } ) {
        $first_email = $args{ -Test_Recipient };
    }

    my $to_pin = make_pin( -Email => $first_email );

    my ( $lo_e_name, $lo_e_domain ) = split ( '@', $first_email );

    my $total = 0;

    print SENDINGFILE join ( '::',
        $first_email, $lo_e_name, $lo_e_domain, $to_pin, $self->{list},
        $list_names{ $self->{list} }, $n_msg_id, );

    $total++;

    # TODO: these three lines need to be one
    my $test_test = $args{'-Bulk_Test'};
    chomp($test_test);    #Why Chomp?!
    unless ( $test_test == 1 ) {

        my @merge_fields = @{ $self->subscriber_fields };
        my $merge_field_query;
        foreach (@merge_fields) {
            $merge_field_query .= ', ' . $_;
        }

        my $query;
        $query = "SELECT email, list";
        $query .= $merge_field_query
          ;  # $merge_field_query is going to be a bunch of commas, (?, ?, ?...)
        $query .= " FROM "
          . $self->{sql_params}->{subscriber_table}
          . " WHERE list    = ? 
                         AND list_type = ?
                         AND list_status= 1";

        if ( keys %{ $args{ -partial_sending } } ) {

            foreach ( keys %{ $args{ -partial_sending } } ) {
                if ( $args{ -partial_sending }->{$_}->{equal_to} ) {

                    $query .= ' AND ' . $_ . ' = \''
                      . $args{ -partial_sending }->{$_}->{equal_to} . '\'';

                    #carp 'QUERY: ' . $query;

                }
                elsif ( $args{ -partial_sending }->{$_}->{like} ) {

                    $query .= ' AND ' . $_
                      . ' LIKE \'%'
                      . $args{ -partial_sending }->{$_}->{like} . '%\'';

                }
            }

        }

        #

        $query .= ' ORDER BY email'
          if $DADA::Config::LIST_IN_ORDER == 1;

        my $sth = $self->{dbh}->prepare($query);
        $sth->execute( $self->{list}, $args{ -Type } )
          or croak
          "cannot do statement (at create mass_sending_file)! $DBI::errstr\n";

        my $field_ref;
        while ( $field_ref = $sth->fetchrow_hashref ) {

            chomp $field_ref->{email};    #new..

            unless ( exists( $banned_list{ $field_ref->{email} } ) ) {

                my $pin = make_pin( -Email => $field_ref->{email} );

                my ( $e_name, $e_domain ) = split ( '@', $field_ref->{email} );

                print SENDINGFILE "\n" . join (
                    '::', $field_ref->{email},
                    $e_name,
                    $e_domain,
                    $pin,
                    $field_ref->{list},
                    $list_names{ $field_ref->{list} },
                    $n_msg_id,

                );

                foreach (@merge_fields) {

                    if ( defined( $field_ref->{$_} ) ) {

                        chomp $field_ref->{$_};

                   # DEV: This really needs to be figured out a little better...

                        $field_ref->{$_} =~ s/\n|\r/ /g;
                        $field_ref->{$_} =~ s/::/:\:/g;
                    }
                    else {
                        $field_ref->{$_} = '';
                    }

                    print SENDINGFILE '::' . $field_ref->{$_};

                }

                $total++;
            }

        }

        $sth->finish;
    }

    close(SENDINGFILE)
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

        #again, harmony is restored to the force.
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

Copyright (c) 1999-2008 Justin Simoni All rights reserved. 

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

