package DADA::App::Subscriptions::ConfirmationTokens;

use lib qw(
	../../../ 
	../../../perllib
);

use DADA::Config qw(!:DEFAULT);
my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Subscriptions}; 

use Carp qw(croak carp); 
use Try::Tiny; 


BEGIN { 
	my $type = $DADA::Config::BACKEND_DB_TYPE;
	if($type eq 'SQL'){ 
			$backend = 'baseSQL';
	}
	elsif($type eq 'Default'){ 
		$backend = 'Db'; 
	}
	else { 
		die "Unknown \$BACKEND_DB_TYPE: '$type' Supported types: 'SQL', 'Default'"; 
	}
}
use base "DADA::App::Subscriptions::ConfirmationTokens::$backend";

sub token { 
	my $self = shift; 
	
	require DADA::Security::Password; 
	my $str = DADA::Security::Password::generate_rand_string(undef, 40);
	try { 
		# Entirely unneeded: 
		require Digest::SHA1;
		$str = Digest::SHA1->new->add('blob '.length($str)."\0".$str)->hexdigest(), "\n";
	}
	return $str; 
}

sub save {

    my $self = shift;
    my $args = shift;

    if ( !exists( $args->{-email} ) ) {
        croak "no -email!";
    }
    if ( !exists( $args->{-data} ) ) {
        croak "no -data!";
    }

	my $remove_previous = 0; 	
    if ( exists( $args->{-remove_previous} ) ) {
        $remove_previous = $args->{-remove_previous};
    }
	my $reset_previous_timestamp = 0; 	
    if ( exists( $args->{-reset_previous_timestamp} ) ) {
        $reset_previous_timestamp = $args->{-reset_previous_timestamp};
    }


    my $data = {
        email => $args->{-email},
        data  => $args->{-data},
    };

    my $frozen = $self->_freeze($data);
    my $token  = $self->token;

	if($remove_previous == 1){ 
		$self->remove_by_metadata(
			{ 
				-email    => $args->{-email},
				-metadata => $args->{-data}, 
			}
		); 
	}
	if($reset_previous_timestamp == 1){ 
		#warn 'calling reset_timestamp_by_metadata'; 
		my $prev_token = $self->reset_timestamp_by_metadata(
				{ 
					-email    => $args->{-email},
					-metadata => $args->{-data}, 
				}
			);
		if(defined($prev_token)) { 
			return $prev_token; 
		}
		else { 
			# We didn't find one
			#warn 'making a new one.'; 
			$self->_backend_specific_save($token, $args->{-email}, $frozen); 
			return $token; 
		}
		
	}
	else { 
		$self->_backend_specific_save($token, $args->{-email}, $frozen); 
		return $token;
	}
	

}

sub _freeze {
    my $self = shift;
    my $data = shift;

    require Data::Dumper;
    my $d = new Data::Dumper( [$data], ["D"] );
    $d->Indent(0);
    $d->Purity(1);
    $d->Useqq(0);
    $d->Deepcopy(0);
    $d->Quotekeys(1);
    $d->Terse(0);

    # ;$D added to make certain we get our data structure back when we thaw
    return $d->Dump() . ';$D';

}

sub _thaw {

    my $self = shift;
    my $data = shift;

    # To make -T happy
    my ($safe_string) = $data =~ m/^(.*)$/s;
    my $rv = eval($safe_string);
    if ($@) {
        croak "couldn't thaw data!";
    }
    return $rv;
}




1; 