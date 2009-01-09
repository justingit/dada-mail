package DADA::MailingList::Subscriber::baseSQL;

use strict; 
use lib qw( ../../../../ ../../../../DADA ../../../perllib); 


use Carp qw(croak carp confess); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts;
use DADA::Logging::Usage;
	
# Gah... 
use DADA::MailingList::Subscribers; 

my $email_id         = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';
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

my %fields; 

my $dbi_obj; 



sub new {

	my $class  = shift;
	my ($args) = @_; 

	my $self = {};			
	bless $self, $class;
	$self->_init($args); 
	return $self;

}





sub _init  { 

    my $self = shift; 

	my ($args) = @_; 

	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings;
		       $DADA::MaiingList::Settings::dbi_obj = $dbi_obj; 
		 
		$self->{ls} = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$self->{ls} = $args->{-ls_obj};
	}
	
    
    $self->{'log'}      = new DADA::Logging::Usage;
    $self->{list}       = $args->{-list};

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    
	if(!$dbi_obj){ 
		#warn "We don't have the dbi_obj"; 
		require DADA::App::DBIHandle; 
		$dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}else{ 
		#warn "We HAVE the dbi_obj!"; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}
	
	my $lh = DADA::MailingList::Subscribers->new({-list => $args->{-list}}); 
	$self->{lh} = $lh;
}




sub add {

    my $self = shift;
    my ($args) = @_;

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
    my @order               = @{ $self->{lh}->subscriber_fields };
    my @values;

    # DEV: This is strange - you should actually get the order and what fields
    # are valid via the $self->{lh}->subscriber_fields method and croak if any
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
      . $self->{sql_params}->{subscriber_table}
      . '(email,list,list_type,list_status'
      . $sql_str . ') 
                VALUES (?,?,?,?' . $place_holder_string . ')';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute(
        $args->{ -email },
        $self->{list}, $args->{ -type },
        1, @values
      )
      or croak "cannot do statement (at add_subscriber)! $DBI::errstr\n";

    $sth->finish;

    if ( $DADA::Config::LOG{subscriptions} == 1 ) {
        $self->{'log'}->mj_log(
            $self->{list},
            'Subscribed to ' . $self->{list} . '.' . $args->{ -type },
            $args->{ -email }
        );
    }

    return 1;

}

sub get {

    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{ -email } ) {
        croak "You must pass an email in the -email paramater!";
    }
    if ( !exists $args->{ -type } ) {
        $args->{ -type } = 'list';
    }

    if ( !exists $args->{ -dotted } ) {
        $args->{ -dotted } = 0;
    }

    my $sub_fields = $self->{lh}->subscriber_fields;

    my $query =
      'SELECT * FROM '
      . $self->{sql_params}->{subscriber_table}
      . " WHERE list_type = '"
      . $args->{ -type } . "' 
                  AND list_status =      1 
                  AND email = '" . $args->{ -email } . "' 
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
    if ( !exists $args->{ -from } ) {
        croak "You must pass a value in the -from paramater!";
    }
    if ( !exists $args->{ -email } ) {
        croak "You must pass a value in the -email paramater!";
    }

    if ( $self->{lh}->allowed_list_types->{ $args->{ -to } } != 1 ) {
        croak "list_type passed in, -to is not valid";
    }

    if ( $self->{lh}->allowed_list_types->{ $args->{ -from } } != 1 ) {
        croak "list_type passed in, -from is not valid";
    }

    if ( DADA::App::Guts::check_for_valid_email( $args->{ -email } ) == 1 ) {
        croak "email passed in, -email is not valid";
    }

    if (
        $self->{lh}->check_for_double_email(
            -Email      => $args->{ -email },
            -Type       => $args->{ -from },
            -Match_Type => 'exact'
        ) == 0
      )
    {
        croak
"email passed in, -email is not subscribed to list passed in, '-from'";
    }

    if ( !exists( $args->{ -mode } ) ) {
        $args->{ -mode } = 'writeover_check';
    }

    if ( $args->{ -mode } eq 'writeover' ) {
        if (
            $self->{lh}->check_for_double_email(
                -Email => $args->{ -email },
                -Type  => $args->{ -to }
            ) == 1
          )
        {
            $self->remove(
                {
                    -email => $args->{ -email },
                    -type  => $args->{ -to },
                }
            );
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

    my $rv = $sth->execute(
        $args->{ -to },
        $args->{ -from },
        $args->{ -email },
        $self->{list}
      )
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
              . $args->{ -from } . ' to: '
              . $self->{list} . '.'
              . $args->{ -to },
            $args->{ -email },
        );
    }

    return 1;
}

1;
