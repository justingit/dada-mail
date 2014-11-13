package DADA::MailingList::Subscriber;
use lib qw(./ ../ ../../ ../../DADA ../../perllib);

use DADA::Config qw(!:DEFAULT);

BEGIN {
    $type = $DADA::Config::SUBSCRIBER_DB_TYPE;
    if ( $type =~ m/sql/i ) {
        $type = 'baseSQL';
    }
    else {
        $type = 'PlainText';
    }
}
use base "DADA::MailingList::Subscriber::$type";
use Carp qw(carp croak);
# $Carp::Verbose = 1; 
use strict;

use Carp qw(croak carp confess);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use DADA::Logging::Usage;

# Gah...
use DADA::MailingList::Subscribers;

my $email_id = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';
$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList};

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

my %fields; #?

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


 ##############################################################################
# This is the new stuff, I guess: 

	if(exists($args->{-type})) { 
		$self->{type} = $args->{ -type };
	}
	else { 
		carp "no -type passed in new() -type is an option parameter, but my cause problems for methods that do need it."
			if $t; 
	}

	if ( !exists $args->{ -email } ) {
	    croak("You MUST supply an email address in the -email parameter!");
	}
	if ( length( strip( $args->{ -email } ) ) <= 0 ) {
	    croak("You MUST supply an email address in the -email parameter!");
	}
	if( !exists($args->{-validation_check})){ 
		$args->{-validation_check} = 1; 
	}
	if(
		exists($args->{-type})         &&
		$args->{-type} ne 'black_list' &&
		$args->{-type} ne 'white_list' 
	){ 
		if($args->{-validation_check} == 1) { 		
		    if(DADA::App::Guts::check_for_valid_email($args->{-email}) == 1){ 
		        croak "email, '" . $args->{-email} ."' passed in, -email is not valid, type: " . $args->{-type}; 
		    }
		}
	}
	$self->{email} = $args->{-email};
	
#/This is the new stuff, I guess: 
##############################################################################

    if ( !exists( $args->{ -ls_obj } ) ) {
        require DADA::MailingList::Settings;
        $self->{ls} =
          DADA::MailingList::Settings->new( { -list => $args->{ -list } } );
    }
    else {
        $self->{ls} = $args->{ -ls_obj };
    }

    $self->{'log'} = new DADA::Logging::Usage;
    $self->{list} = $args->{ -list };

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

    if ( $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/sql/i ) {
        require DADA::App::DBIHandle;
        my $dbi_obj = DADA::App::DBIHandle->new;
        $self->{dbh} = $dbi_obj->dbh_obj;
    }

    my $lh = undef; 

	if(exists($args->{-dpfm_obj})){ 
    	$lh = DADA::MailingList::Subscribers->new( 
			{ 
				-list     => $args->{ -list },
				-dpfm_obj => $args->{-dpfm_obj},
			} 
		);	
	}
	else { 
    	$lh = DADA::MailingList::Subscribers->new( { -list => $args->{ -list } } );
	}
	
	$self->{lh} = $lh;


	if(exists($args->{-type})){ 
		if($self->{lh}->allowed_list_types($args->{-type}) != 1){ 
	        croak "list_type passed in, -type (" . $args->{ -type } . ") is not valid 3";
	    }	
	}

}
# This is a weird one, since it's not going to be filled with anything, when you 
# call new(). Fill it out when you call, new() or not use it (use get, in other words) 

sub fields { 
	my $self = shift; 
	return $self->get;
}
sub type { 
	my $self = shift; 
	if(!exists($self->{type})){ 
		return undef; 
	}
	else { 
		return $self->{type};
	}
}
sub email { 
	my $self = shift; 
	return $self->{email};
}



sub edit {

    my $self = shift;
    
	if(! defined($self->type)){ 
		croak("'type' needs to be defined!"); 
	}

	my ($args) = @_;
	
	
    if ( !exists $args->{ -fields } ) {
        $args->{ -fields } = {};
    }


    if ( !exists $args->{ -mode } ) {
        $args->{ -mode } = 'update';
    }

    if ( $args->{ -mode } !~ /update|writeover/ ) {
        croak
"The -mode parameter must be set to, 'update', 'writeover' or left undefined!";
    }

    my $orig_values = {};

    if ( $args->{ -mode } eq 'update' ) {
		$orig_values = $self->get; 
    }
	my $orig_email = $self->email; 
	my $orig_type  = $self->type; 
	
    $self->remove;

    for ( keys %{ $args->{ -fields } } ) {
        $orig_values->{$_} = $args->{ -fields }->{$_};
    }

	
    $self = DADA::MailingList::Subscriber->add(
        {
			-list   => $self->{list},
            -email  => $orig_email,
            -type   => $orig_type,
            -fields => $orig_values,
        }
    );

    return 1;

}




sub copy { 
	
	my $self   = shift; 

	if(! defined($self->type)){ 
		croak("'type' needs to be defined!"); 
	}


    my ($args) = @_;

    if(! exists $args->{-to}){ 
        croak "You must pass a value in the -to parameter!"; 
    }

    if($self->{lh}->allowed_list_types($args->{-to}) != 1){ 
        croak "list type passed in, -to (" . $args->{ -to } . ") is not valid";
    }

    my $moved_from_checks_out = 0; 
    if(! exists($args->{-moved_from_check})){ 
        $args->{-moved_from_check} = 1; 
    }

	# This probably won't happen, since we do this check it, "new", but, whatever (for now)
    if($self->{lh}->check_for_double_email(-Email => $self->email, -Type => $self->type) == 0){ 

        if($args->{-moved_from_check} == 1){ 
            croak "email passed in, -email is not subscribed to list passed in, '-from'";     
        }
        else { 
            $moved_from_checks_out = 0; 
        }
    }
    else { 
        $moved_from_checks_out = 1; 
    }


    if($self->{lh}->check_for_double_email(-Email => $self->email, -Type => $args->{-to}) == 1){ 
        croak "email passed in, -email ( $args->{-email}) is already subscribed to list passed in, '-to' ($args->{-to})"; 
    }
		
    my $copy = DADA::MailingList::Subscriber->add(
        { 
			-list   => $self->{list},
            -email  => $self->email, 
            -type   => $args->{-to}, 
        }
    ); 

    if ($DADA::Config::LOG{subscriptions}) { 
        $self->{'log'}->mj_log(
            $self->{list}, 
            'Copy from:  ' . $self->{list} . '.' . $self->type . ' to: ' . $self->{list} . '.' . $args->{-to}, 
            $args->{-email}, 
        );
    }


	return 1;

}









1; 
