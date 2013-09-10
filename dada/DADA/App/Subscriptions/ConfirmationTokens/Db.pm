package DADA::App::Subscriptions::ConfirmationTokens::Db;
use lib qw(
  ../../../../
  ../../../../perllib
);

use Carp qw(croak carp);
use base qw(DADA::App::GenericDBFile);

sub new {
	my $class = shift;
	
	my ($args) = @_; 	

    my $self = SUPER::new $class (
    							  function => 'confirmation_tokens',
    							 );  
	
	$self->_init($args); 

	return $self;
}

sub _init { 
	my $self   = shift; 
	my ($args) = @_;
	 
	$self->_open_db;
}

sub _backend_specific_save { 

	my $self   = shift; 
	my $token  = shift;
	my $email  = shift; # not used.  
	my $frozen = shift; 
	
#	$self->_open_db; 
        $self->{DB_HASH}->{$token} = $frozen;
#    $self->_close_db; 
}


sub fetch {
    my $self  = shift;
    my $token = shift;

#	$self->_open_db; 
    my $frozen_data = $self->{DB_HASH}->{$token};
#    $self->_close_db; 

    my $data = $self->_thaw($frozen_data);

    return $data;

}



sub remove_by_token {

    my $self  = shift;
    my $token = shift;

#	$self->_open_db; 
    delete($self->{DB_HASH}->{$token});

	$self->_close_db; 
	$self->_open_db;
	
#    $self->_close_db; 

    return 1;

}
sub remove_by_metadata {
		
    my $self = shift;
    my ($args) = @_;

    my $email    = $args->{-email};
    my $metadata = $args->{-metadata};
    my $tokens   = [];
    my $row      = {};

#	$self->_open_db; 
    foreach my $r (keys %{$self->{DB_HASH}}) { 
		
        my $frozen_data = $self->{DB_HASH}->{$r};
        my $data        = $self->_thaw($frozen_data);

	#	use Data::Dumper; 
	#print Dumper($data);
		
		next if $data->{email} ne $email;
		
        #		warn '$data:'    . Dumper($data);
        #		warn '$metadata' . Dumper($metadata);

        if (
			   $data->{data}->{list}   eq $metadata->{list}
            && $data->{data}->{type}   eq $metadata->{type}
			&& $data->{data}->{flavor} eq $metadata->{flavor}
		)
        {
            push( @$tokens, $r );
        }
    }
#	$self->_close_db;
		
    foreach my $token (@$tokens) {
        $self->remove_by_token($token);
	#	delete($self->{DB_HASH}->{$token});
    }


		
    return scalar(@$tokens);
}


sub num_tokens { 
	
	my $self = shift; 
#	$self->_open_db;
	return scalar(keys %{$self->{DB_HASH}}); 
#	$self->_close_db; 

}

sub tokens { 
	my $self = shift; 
	my @k = keys %{$self->{DB_HASH}};
	return [@k];
}

sub exists {
    my $self  = shift;
    my $token = shift;
	my $r = 0; 
	
#	$self->_open_db; 
    if(exists($self->{DB_HASH}->{$token})) { 
		# print "exists! " . $self->{DB_HASH}->{$token} . "\n";
		$r = 1; 
	}
#    $self->_close_db; 
    return $r;
	
}

sub reset_timestamp_by_metadata { 
	return undef; 
}

sub remove_all_tokens {
	my $self = shift; 
	foreach(keys %{$self->{DB_HASH}}) { 
		delete($self->{DB_HASH}->{$_}); 
	}	
}


sub _remove_expired_tokens {
	return 1; 
}


DESTROY {
	my $self = shift; 
	$self->_close_db;
}


1;