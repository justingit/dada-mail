package DADA::MailingList::Subscribers::baseSQL;

use strict;

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib);

use Carp qw(croak carp confess);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};

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

    my $st     = $self->{sql_params}->{subscriber_table};
    my $sft    = $self->{sql_params}->{profile_fields_table};
    my $fields = $self->subscriber_fields;
    my $select_fields = '';
    foreach (@$fields) {
        $select_fields .= ', ' . $sft . '.' . $_;
    }

    my $query;
    $query .= 'SELECT ' . $st . '.email';
    $query .= $select_fields;
    $query .= ' FROM ';
    $query .= $st . ' LEFT JOIN ' . $sft;
    $query .= ' ON ';
    $query .= $st . '.email' . ' = ' . $sft . '.email';
    $query .= ' WHERE   ' . $st
      . '.list_type = ? AND '
      . $st
      . '.list_status = 1 AND '
      . $st
      . '.list = ? ';

    if ( $fields->[0] ) {
        $query .= ' AND (' . $st . '.email like ?';
        foreach (@$fields) {
            $query .= ' OR ' . $sft . '.' . $_ . ' LIKE ? ';
        }
        $query .= ')';
    }
    else {
        $query .= ' AND (' . $st . '.email like ?)';
    }

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
        $query .= ' ORDER BY ' . $st . '.email';
    }

    warn 'query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    my @extra_params = ();
    foreach (@$fields) {
        push ( @extra_params, '%' . $args->{ -query } . '%' );
    }
	#/
	
    $sth->execute(
        $args->{ -type },              $self->{list},
        '%' . $args->{ -query } . '%', @extra_params,
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




sub SQL_subscriber_profile_join_statement { 
	
	my $self   = shift; 
	my ($args) = @_; 
	# Args 
	# -partial_listing
	# -type - perhaps? 
	
	# init vars
	if(!$args->{ -type }){ 
		$args->{ -type } = 'list'; 
	}
	
    my $subscriber_table     = $self->{sql_params}->{subscriber_table};
    my $profile_fields_table = $self->{sql_params}->{profile_fields_table};
	
	# This is to select which profile fields to return with our query
	my @merge_fields = @{ $self->subscriber_fields };
      my $merge_field_query;
      foreach (@merge_fields) {
          $merge_field_query .=
            ', ' . $profile_fields_table . '.' . $_;
      }
	#/ This is to select which profile fields to return with our query
	
	my $query;
	$query = 'SELECT ' . $subscriber_table . '.email, ' . $subscriber_table . '.list';
	$query .= $merge_field_query;
	$query .= ' FROM ' . $subscriber_table . ' LEFT OUTER JOIN ' . $profile_fields_table . ' ON ';
	$query .= ' ' . $subscriber_table . '.email' . ' = ' . $profile_fields_table . '.email';
	$query .= ' WHERE  ';
	if (   $DADA::Config::GLOBAL_BLACK_LIST
	       && $args->{ -type } eq 'black_list' )
	   {
	       #... Nothin'
	   }
	   else {
	    $query .= $subscriber_table . '.list = ?';
	   }
	
      $query .= ' AND ' . $subscriber_table . '.list_type = ?';
      $query .= ' AND ' . $subscriber_table . '.list_status = 1';

      if ( keys %{ $args->{ -partial_listing } } ) {
	
		  # This *really* needs its own method, as well... 
          foreach ( keys %{ $args->{ -partial_listing } } ) {
              if ( $args->{ -partial_listing }->{$_}->{equal_to} ) {
                  $query .= ' AND ' . $profile_fields_table . '.' . $_ . ' = \''
                    . $args->{ -partial_listing }->{$_}->{equal_to} . '\'';
              }
              elsif ( $args->{ -partial_listing }->{$_}->{like} ) {

                  $query .= ' AND ' . $profile_fields_table . '.' . $_
                    . ' LIKE \'%'
                    . $args->{ -partial_listing }->{$_}->{like} . '%\'';
              }
          }
	  	# This *really* needs its own method, as well... 	
      }

	#if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
		$query .= ' ORDER BY ' . $subscriber_table . '.email';
    #}

	warn 'QUERY: ' . $query;
	#	if $t;
	return $query; 
}




sub fancy_print_out_list {

    # DEV: This subroutine is very very messy. Very messy.

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

    my $fields = $self->subscriber_fields;

    print $fh
' <div style="max-height: 250px; overflow: auto; border:1px solid black;background:#fff">';

    print $fh
      '<table width="100%"><tr><td><p><strong>Email Address</strong></p></td>';
    foreach (@$fields) {
        print $fh '<td><p><strong>' . $_ . '</strong></p></td>';

    }

    print $fh '</tr>';

    my $count         = 0;

	my $query = $self->SQL_subscriber_profile_join_statement(
		{ 
			-type            => $args->{ -type }, 
			-partial_listing => $args->{ -partial_listing },
		}
	);
 
    my $sth = $self->{dbh}->prepare($query);

    if (   $DADA::Config::GLOBAL_BLACK_LIST
        && $args->{ -type } eq 'black_list' )
    {
        $sth->execute( $args->{ -type } )
          or croak "cannot do statment (for print out list)! $DBI::errstr\n";
    }
    else {

        $sth->execute( $args->{ -type }, $self->{list} )
          or croak "cannot do statment (for print out list)! $DBI::errstr\n";
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
    print $fh '<p style="text-align:right">Total Subscribers: <strong>' . $count
      . '</strong></p>';

    return $count;

}



sub print_out_list {

    my $self = shift;

    my %args = (
        -FH => \*STDOUT,
        @_
    );
    my $fh = $args{ -FH };

    my $count;

	my $query = $self->SQL_subscriber_profile_join_statement(
		{ 
			-type            => $args{ -Type }, 
		}
	);
	
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

    my $st  = $self->{sql_params}->{subscriber_table};
    my $sft = $self->{sql_params}->{profile_fields_table};

 	my $fields        = $self->subscriber_fields;
    my $select_fields = '';

    foreach (@$fields) {
        $select_fields .= ', ' . $sft . '.' . $_;
    }

	#my $query .= 'SELECT ' . $st . '.email';
    my $query .= 'SELECT ' . $st . '.*';

    $query .= $select_fields;
    $query .= ' FROM ' . $st;
    $query .= ' LEFT JOIN ' . $sft . ' ON ';
    $query .= ' ' . $st . '.email' . ' = ' . $sft . '.email';
    $query .= ' WHERE ' . $st . '.list_type = ? AND ' . $st . '.list_status = 1';
    $query .= ' AND ' . $st . '.list = ?';

    if ( $DADA::Config::LIST_IN_ORDER == 1 ) {
        $query .= ' ORDER BY ' . $st . '.email';
    }

	warn 'query: ' . $query
	 if $t; 


    my $sth = $self->{dbh}->prepare($query); 
	
    $sth->execute( $args{ -Type }, $self->{list} )
      or croak "cannot do statment (for subscription_list)! $DBI::errstr\n";

	
    my $hashref;
    my %mf_lt        = ();

    foreach (@$fields) {
        $mf_lt{$_} = 1;
    }

    while ( $hashref = $sth->fetchrow_hashref ) {
		#require Data::Dumper; 
		#die Data::Dumper::Dumper($hashref); 
		
        $count++;
        next if $count < $args{ -start };
        last if $count > ( $args{ -start } + $args{'-length'} );

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
#        warn '$remove  for '
#          . $self->{list} . ', '
#          . $args{ -Type }
#          . ', $sub'
#          . $sub . ' :'
#          . $remove;
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
     chmod($SENDINGFILE, $DADA::Config::FILE_CHMOD );
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
	my @lo = ( 
				$first_email,
				$lo_e_name, 
				$lo_e_domain, 
				$to_pin, 
				$self->{list},
				$list_names{$self->{list}},
				$n_msg_id,
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

=cut
		#########
        my @merge_fields = @{ $self->subscriber_fields };
        my $merge_field_query;
        foreach (@merge_fields) {
            $merge_field_query .=
              ', ' . $self->{sql_params}->{profile_fields_table} . '.' . $_;
        }

        my $st  = $self->{sql_params}->{subscriber_table};
        my $sft = $self->{sql_params}->{profile_fields_table};

        my $query;
        $query = 'SELECT ' . $st . '.email, ' . $st . '.list';
        $query .= $merge_field_query;
        $query .= ' FROM ' . $st . ' LEFT OUTER JOIN ' . $sft . ' ON ';
        $query .= ' ' . $st . '.email' . ' = ' . $sft . '.email';
        $query .= ' WHERE  ';
        $query .= $st . '.list = ?';
        $query .= ' AND ' . $st . '.list_type = ?';
        $query .= ' AND ' . $st . '.list_status = 1';

        if ( keys %{ $args{ -partial_sending } } ) {
            foreach ( keys %{ $args{ -partial_sending } } ) {
                if ( $args{ -partial_sending }->{$_}->{equal_to} ) {
                    $query .= ' AND ' . $sft . '.' . $_ . ' = \''
                      . $args{ -partial_sending }->{$_}->{equal_to} . '\'';
                }
                elsif ( $args{ -partial_sending }->{$_}->{like} ) {

                    $query .= ' AND ' . $sft . '.' . $_
                      . ' LIKE \'%'
                      . $args{ -partial_sending }->{$_}->{like} . '%\'';
                }
            }

        }
        $query .= ' ORDER BY ' . $st . '.email';

       # warn 'QUERY: ' . $query
       #   if $t;
	
		###################
=cut

		my $query = $self->SQL_subscriber_profile_join_statement(
			{ 
				-type            => $args{ -Type }, 
				-partial_listing => $args{ -partial_sending },
			}
		);
			
		
		#warn 'QUERY1: ' . $query;
		#warn 'QUERY2: ' . $query2;	
		#die; 
		
        my $sth = $self->{dbh}->prepare($query);
        $sth->execute( $self->{list}, $args{ -Type } )
          or croak
          "cannot do statement (at create mass_sending_file)! $DBI::errstr\n";

        my $field_ref;

        while ( $field_ref = $sth->fetchrow_hashref ) {

            chomp $field_ref->{email};    #new..

            unless ( exists( $banned_list{ $field_ref->{email} } ) ) {

				my @sub = (
					$field_ref->{email},
					( split ( '@', $field_ref->{email} ) ), 
					make_pin( -Email => $field_ref->{email}, -List => $self->{list} ),
					$field_ref->{list},
					$list_names{ $field_ref->{list} },
					$n_msg_id,
				);
#                foreach (@merge_fields) {
				foreach(@{ $self->subscriber_fields }) { 
                    if ( defined( $field_ref->{$_} ) ) {
                        chomp $field_ref->{$_};
                        $field_ref->{$_} =~ s/\n|\r/ /g;
                    }
                    else {
                        $field_ref->{$_} = '';
                    }

                    push(@sub, $field_ref->{$_}); 

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

