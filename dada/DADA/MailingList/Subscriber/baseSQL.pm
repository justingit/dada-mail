package DADA::MailingList::Subscriber::baseSQL;

use strict;
use lib qw( ../../../../ ../../../../DADA ../../../perllib);
use Carp qw(carp croak);
use DADA::Config;
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL};

sub add {

    my $class = shift;

    my ($args) = @_;
    my $lh =
      DADA::MailingList::Subscribers->new( { -list => $args->{ -list } } );

    if ( !exists $args->{ -type } ) {
        $args->{ -type } = 'list';
    }
    if ( !exists $args->{ -email } ) {
        croak("You MUST supply an email address in the -email paramater!");
    }
    if ( length( strip( $args->{ -email } ) ) <= 0 ) {
        croak("You MUST supply an email address in the -email paramater!");
    }

    if ( !exists $args->{ -fields } ) {
        $args->{ -fields } = {};
    }

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $lh->subscriber_fields };
    my @values;

    # DEV: This is strange - you should actually get the order and what fields
    # are valid via the $lh->subscriber_fields method and croak if any
    # fields are trying to be passed that aren't actually available. You know?
    # Maybe not croak - perhaps just, "forget"?

    if ( $order[0] ) {
        foreach my $field (@order) {

            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            push ( @values, $args->{ -fields }->{$field} );
        }
    }
    $sql_str =~ s/,$//;
    my $query =
      'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{subscriber_table}
      . '(email,list,list_type,list_status'
      . $sql_str . ') 
                VALUES (?,?,?,?' . $place_holder_string . ')';

    warn 'Query: ' . $query
      if $t;

    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    my $dbh     = $dbi_obj->dbh_obj;
    my $sth     = $dbh->prepare($query);

    $sth->execute(
        $args->{ -email },
        $args->{ -list },
        $args->{ -type },
        1, @values
      )
      or croak "cannot do statement (at add_subscriber)! $DBI::errstr\n";

    # And then, basically, make the subscriber field stuff...

    $sth->finish;

    my $added = DADA::MailingList::Subscriber->new(
        {
            -list  => $args->{ -list },
            -email => $args->{ -email },
            -type  => $args->{ -type },
        }
    );

    if ( $DADA::Config::LOG{subscriptions} == 1 ) {
        $added->{'log'}->mj_log( $added->{list},
            'Subscribed to ' . $added->{list} . '.' . $added->type,
            $added->email );
    }
    return $added;

}

sub get {

    my $self = shift;
    my ($args) = @_;
    my $sub_fields = $self->{lh}->subscriber_fields;

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = '"
      . $self->type . "' 
                  AND list_status =      1 
                  AND email = '" . $self->email . "' 
                 AND list = '" . $self->{list} . "'";

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute()
      or croak "cannot do statement (at get_subscriber)! $DBI::errstr\n";

    # DEV: this is sort of weird: We use a while() loop to get ONE row. Hmm...
    # Can we do, $sth->fetchrow_hashref[0] or something?!

    my $hashref   = {};
    my $n_hashref = {};

  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        foreach ( @{$sub_fields} ) {
            $n_hashref->{$_} = $hashref->{$_};
        }
        $n_hashref->{email} = $hashref->{email};

        my ( $n, $d ) = split ( '@', $hashref->{email}, 2 );
        $n_hashref->{email_name}   = $n;
        $n_hashref->{email_domain} = $d;

        last FETCH;
    }

    if ( $args->{ -dotted } == 1 ) {
        my $dotted = {};
        foreach ( keys %$n_hashref ) {
            $dotted->{ 'subscriber.' . $_ } = $n_hashref->{$_};
        }
        return $dotted;
    }
    else {
        return $n_hashref;
    }

    carp "Didn't fetch the subscriber?!";
    return undef;

}

sub move {

    my $self = shift;

    my ($args) = @_;

    if ( !exists $args->{ -to } ) {
        croak "You must pass a value in the -to paramater!";
    }

    if ( $self->{lh}->allowed_list_types->{ $args->{ -to } } != 1 ) {
        croak "list_type passed in, -to is not valid";
    }

    # Why wasn't this in before?
    my $moved_from_checks_out = 0;
    if ( !exists( $args->{ -moved_from_check } ) ) {
        $args->{ -moved_from_check } = 1;
    }

    if (
        $self->{lh}->check_for_double_email(
            -Email => $self->email,
            -Type  => $self->type
        ) == 0
      )
    {

        if ( $args->{ -moved_from_check } == 1 ) {
            croak $self->email
              . " is not subscribed to list type, "
              . $self->type;
        }
        else {
            $moved_from_checks_out = 0;
        }
    }
    else {
        $moved_from_checks_out = 1;
    }

    # /Why wasn't this in before?

    if ( !exists( $args->{ -mode } ) ) {
        $args->{ -mode } = 'writeover_check';
    }

    if ( $args->{ -mode } eq 'writeover' ) {
        if (
            $self->{lh}->check_for_double_email(
                -Email => $self->email,
                -Type  => $args->{ -to }
            ) == 1
          )
        {
            DADA::MailingList::Subscriber->new(
                {
                    -list  => $self->{list},
                    -email => $self->email,
                    -type  => $args->{ -to },
                }
            )->remove;
        }
    }
    else {
        if (
            $self->{lh}->check_for_double_email(
                -Email => $args->{ -email },
                -Type  => $args->{ -to }
            ) == 1
          )
        {
            croak
"email passed in, -email ( $args->{-email}) is already subscribed to list passed in, '-to' ($args->{-to})";
        }
    }

    my $query = 'UPDATE '
      . $self->{sql_params}->{subscriber_table}
      . ' SET   list_type   = ? 
                      WHERE list_type   = ? 
                      AND   email       = ? 
                      AND   list        = ?';

    my $sth = $self->{dbh}->prepare($query);

    my $rv =
      $sth->execute( $args->{ -to }, $self->type, $self->email, $self->{list} )
      or croak "cannot do statement (at move_subscriber)! $DBI::errstr\n";

    if ( $rv == 1 ) {
        return 1;

        #carp "Hey, that worked!";
    }
    else {
        carp "Something's wrong. Returned $rv rows, expected 1";
    }

    if ( $DADA::Config::LOG{subscriptions} ) {
        $self->{'log'}->mj_log(
            $self->{list},
            'Moved from:  '
              . $self->{list} . '.'
              . $self->type . ' to: '
              . $self->{list} . '.'
              . $args->{ -to },
            $self->email,
        );
    }

    # Since this is a reference, this should do what I want -
    $self = DADA::MailingList::Subscriber->new(
        {
            -email => $self->email,
            -type  => $args->{ -to },
            -list  => $self->{list},
        }
    );

    return 1;
}

sub remove {

    my $self = shift;

    my $query = "DELETE FROM " . $self->{sql_params}->{subscriber_table} . " 
				 WHERE email   = ?
				 AND list_type = ?";

    if ( $self->type eq 'black_list' ) {
        if ( $DADA::Config::GLOBAL_BLACK_LIST != 1 ) {
            $query .= ' AND list      = ?';
        }
    }
    elsif ( $self->type eq 'list' ) {
        if ( $DADA::Config::GLOBAL_UNSUBSCRIBE != 1 ) {
            $query .= ' AND list      = ?';
        }
    }
    else {
        $query .= ' AND list      = ?';
    }

    my $sth = $self->{dbh}->prepare($query);
    my $rv;

    if ( ( $DADA::Config::GLOBAL_BLACK_LIST && $self->type eq 'black_list' )
        || $DADA::Config::GLOBAL_UNSUBSCRIBE && $self->type eq 'list' )
    {

        $rv = $sth->execute( $self->email, $self->type )
          or croak "cannot do statement (at: remove from list)! $DBI::errstr\n";

    }
    else {

        $rv = $sth->execute( $self->email, $self->type, $self->{list} )
          or croak "cannot do statement (at: remove from list)! $DBI::errstr\n";
    }

    $sth->finish;

    $self->{'log'}->mj_log( $self->{list},
        "Unsubscribed from "
          . $self->{list} . " - "
          . $self->type . ', '
          . $self->email )
      if $DADA::Config::LOG{subscriptions};

    undef $self;    #(although, that won't do what I want it to do....

}

1;
