package DADA::App::AmazonSES; 

use lib qw(
	../../ 
	../../DADA/perllib
);

use DADA::App::Guts; 

use vars qw($AUTOLOAD); 
use Carp qw(croak carp);
use Try::Tiny; 


sub new {

	my $class = shift;
	my %args = (@_); 

	my $self = {};
	bless $self, $class;
	$self->_init(\%args); 
	return $self;
}

sub _init { 
	my $self = shift; 
}


sub has_ses_options_set {
	 
	my $self = shift; 
    my $has_ses_options = 1;

	if (
		   ! exists( $DADA::Config::AMAZON_SES_OPTIONS->{AWSAccessKeyId})
        || ! exists( $DADA::Config::AMAZON_SES_OPTIONS->{AWSSecretKey} )
		) {
    	return 0;
	}
	elsif (   length( $DADA::Config::AMAZON_SES_OPTIONS->{AWSAccessKeyId}) <= 0
        || length( $DADA::Config::AMAZON_SES_OPTIONS->{AWSSecretKey} )  <= 0) {
		return 0;
    }
	else { 
		return 1;
	}

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
		carp 'problems verifying sender: ' . substr($_, 0, 100) . '...'; 
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
		carp 'Problems with sender_verified:' . substr($_, 0, 100) . '...';; 
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
		warn "Problems wth get_stats:"  . substr($_, 0, 100) . '...';; 
		return (undef, undef, undef, undef); 
	};
	
	if($status != 200) { 
		return ($status, undef, undef, undef); 
	}
	else { 
	    # Kind of ridiculous: 
	    my ( $label, $data ) = split( "\n", $result,2 );
	    my $labeled_data = {};
	    my @labels = split(/\s+/, $label,3); 
	    my @data   = split(/\s+/, $data,3); 
	    my $n = 0; 
	    foreach(@labels){ 
	        $_ = strip($_);
	        $labeled_data->{$_} = strip($data[$n]);
	        # warn $_  . ' => ' . strip($data[$n]);
	        $n++;
	    }
	         return(
    	         $status, 
    	         $labeled_data->{SentLast24Hours}, 
    	         $labeled_data->{Max24HourSend},
    	         $labeled_data->{MaxSendRate},
	         ); 
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
	
    if ( !-d $dc->cache_dir ) {
    	if(mkdir( $dc->cache_dir, $DADA::Config::DIR_CHMOD )) { 
          if(-d $dc->cache_dir){ 
			chmod( $DADA::Config::DIR_CHMOD, $dc->cache_dir );
          }
    	}
		else { 
			
		}
	}
	
	
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

sub END {}
sub DESTROY {}
    
1;