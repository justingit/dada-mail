package DADA::App::AmazonSES; 

use lib qw(
	../../ 
	../../DADA/perllib
);

use DADA::App::Guts; 

use vars qw($AUTOLOAD); 
use Carp qw(croak carp);
use Try::Tiny; 

my %allowed = (); 

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my %args = (@_); 
		
   $self->_init(\%args); 
   return $self;
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init { 

	my $self = shift; 
		
}

sub verify_sender { 
	my $self = shift; 
	my ($args) = @_; 
	
	my $status = undef; 
	my $result = undef; 
	
	try { 
		require Net::Amazon::SES; 
		my $ses_obj = Net::Amazon::SES->new( $DADA::Config::AMAZON_SES_OPTIONS ); 
		($status, $result) = $ses_obj->verify_sender($args);
	}
	catch { 
		carp $_; 
	};
	return ($status, $result);
}




sub sender_verified { 
    	my $self  = shift; 
    	my $email = shift; 

    	my $status = undef; 
    	my $result = undef; 

    	try { 
    		require Net::Amazon::SES; 
    		my $ses_obj = Net::Amazon::SES->new( $DADA::Config::AMAZON_SES_OPTIONS ); 
    		($status, $result) = $ses_obj->sender_verified($email);
    	}
    	catch { 
    		carp $_; 
    	};
        if($result eq 'Success'){ 
            return 1; 
        }
        else { 
            return 0; 
        }
    }




sub get_stats {
    my $self = shift;
	my ($args) = @_; 
	
	if(! exists($args->{AWSAccessKeyId}) || ! exists($args->{AWSSecretKey})) { 
		$args = $DADA::Config::AMAZON_SES_OPTIONS, 
	}
	
	 
	my $ses_obj  = undef; 
	my $status   = undef; 
	my $result   = undef; 
	try { 
		require Net::Amazon::SES; 
		$ses_obj = Net::Amazon::SES->new( $args ); 
		($status, $result) = $ses_obj->get_stats();
	}
	catch { 
		die $_; 
		return (undef, undef, undef, undef); 
	};
	
	if($status != 200) { 
		return ($status, undef, undef, undef); 
	}
	else { 
	    my ( $label, $data ) = split( "\n", $result );
	    my ( $SentLast24Hours, $Max24HourSend, $MaxSendRate ) =
	      split( /\s+/, $data );

	    return ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
	}
}


sub allowed_sending_quota_percentage {
    my $self = shift; 
    return int($DADA::Config::AMAZON_SES_OPTIONS->{Allowed_Sending_Quota_Percentage}); 
}


sub _saved_ses_stats_fn { 
    my $self = shift; 
    require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;
    return make_safer( $dc->cache_dir . '/ses_stats.txt' );
}
sub _should_get_saved_ses_stats { 

    my $self = shift; 
    my $stats_file = $self->_saved_ses_stats_fn; 
    
    if(! -e $stats_file || ! -r _){ 
        return 0; 
    }
    else { 
        my (
            $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
            $size, $atime, $mtime, $ctime, $blksize, $blocks
        ) = stat( $stats_file );
        
        if((int($mtime) + (60 * 5)) < time){ 
            return 0; 
        }
        else { 
            return 1; 
        }
    }
}
sub _get_saved_ses_stats { 
   my $self = shift; 
   my $stats_file = $self->_saved_ses_stats_fn; 

   my $contents = slurp( $stats_file ); 
   my  ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = split(',', $contents); 
   return ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
}
sub _save_ses_stats { 
    my $self = shift; 
    my ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate) = @_; 
    my $stats_file = $self->_saved_ses_stats_fn; 
    
    open my $fh, '>', $stats_file or die $! . ' - ' . $stats_file;
    print $fh join(',', $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate); 
    close $fh or die $!; 
}
1;