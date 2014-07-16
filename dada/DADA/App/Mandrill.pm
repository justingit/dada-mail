package DADA::App::Mandrill; 

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



sub get_stats {
    my $self = shift;
	my ($args) = @_; 
	
	if(! exists($args->{api_key})) { 
		$args = $DADA::Config::MANDRILL_OPTIONS, 
	}
	
	 
	my $man_obj  = undef; 
	my $status   = undef; 
	my $SentLast24Hours = undef; 
	my $Max24HourSend = undef; 
	my $MaxSendRate = undef; 
	
	try { 
        ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate) = $self->_get_raw_stats($args); 
	}
	catch { 
		return (undef, undef, undef, undef); 
	};
	
	if($status != 200) { 
		return ($status, undef, undef, undef); 
	}
	else { 
	    return ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
	}
}


sub _get_raw_stats {
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{api_key} ) ) {
        $args = $DADA::Config::MANDRILL_OPTIONS;
    }
    for(qw(api_url)){ 
        if(!exists($args->{$_})){ 
            $args->{$_} = $DADA::Config::MANDRILL_OPTIONS->{$_}; 
        }
    }
    require LWP::UserAgent;
    require URI::Escape;
    require JSON;
    my $json = JSON->new->allow_nonref;
    my $ua   = LWP::UserAgent->new(
        timeout  => 5,
        agent    => "Mozilla/5.0 (compatible;)",
        ssl_opts => { verify_hostname => 0, SSL_verify_mode => 0x00 }
    );

    # Create a request
    my $req = HTTP::Request->new( POST => $args->{api_url} );
    $req->content_type('application/json');
    $req->content( $json->encode( { key => $args->{api_key} } ) );

    my $res = $ua->request($req);

    if ( $res->is_success ) {
        my $post_data = $res->content;
        $data = $json->decode($post_data) or warn "that didn't work.";

        
        #use Data::Dumper;
        #warn Dumper($data);

        if ( !exists( $data->{today}->{sent} ) ) {
            $data->{today}->{sent} = 0;
        }

        #use Data::Dumper;
        #warn Dumper([200, $data->{today}->{sent}, ( int( $data->{hourly_quota} ) * 24 ), 5 ]);
#        if($data->{status} eq 'error'){ 
#            return (0, undef, undef, undef); 
#        }
#        else { 
            # I made up, "2"
            return ( 200, $data->{today}->{sent}, ( int( $data->{hourly_quota} ) * 24 ), 2 );
 #       }
    }
    else {
        #warn 'no!';
        warn $res->status_line;
        warn $res->content;
        return ( 0, undef, undef, undef );
    }

}


sub allowed_sending_quota_percentage {
    my $self = shift; 
    return int($DADA::Config::MANDRILL_OPTIONS->{Allowed_Sending_Quota_Percentage}); 
}


sub _saved_man_stats_fn { 
    my $self = shift; 
    require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;
    return make_safer( $dc->cache_dir . '/man_stats.txt' );
}
sub _should_get_saved_man_stats { 

    my $self = shift; 
    my $stats_file = $self->_saved_man_stats_fn; 
    
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
sub _get_saved_man_stats { 
   my $self = shift; 
   my $stats_file = $self->_saved_man_stats_fn; 

   my $contents = slurp( $stats_file ); 
   my  ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate ) = split(',', $contents); 
   return ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate );
}
sub _save_man_stats { 
    my $self = shift; 
    my ($status, $SentLast24Hours, $Max24HourSend, $MaxSendRate) = @_; 
    my $stats_file = $self->_saved_man_stats_fn; 
    
    open my $fh, '>', $stats_file or die $! . ' - ' . $stats_file;
    print $fh join(',', $status, $SentLast24Hours, $Max24HourSend, $MaxSendRate); 
    close $fh or die $!; 
}
1;