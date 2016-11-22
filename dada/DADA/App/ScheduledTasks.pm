package DADA::App::ScheduledTasks; 

use strict; 

use lib qw(
  ../../
  ../../DADA/perllib
);

use Carp qw(carp croak);


use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts; 


use vars qw($AUTOLOAD); 

use Fcntl qw(
  :DEFAULT
  :flock
  LOCK_SH
  O_RDONLY
  O_CREAT
  O_WRONLY
  O_TRUNC
);

my %allowed = (
    lockfile  => undef,
);



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
		
	return if(substr($AUTOLOAD, -7) eq 'DESTROY');
    	
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
    $self->lockfile( make_safer( $DADA::Config::TMP . '/_scheduled_tasks.lock' ) );
}


sub mass_mailing_monitor { 
   my $self = shift; 
   my $list = shift; 
   
   my $r = undef; 
   
   require DADA::Mail::MailOut; 
   my @r;
   if($list ne '_all') { 
       @r = DADA::Mail::MailOut::monitor_mailout( { -verbose => 0, -list => $list } );
   }
   else { 
       @r = DADA::Mail::MailOut::monitor_mailout( { -verbose => 0 } ); 
   }       
   return $r[0]; 
}

sub scheduled_mass_mailings {
    my $self = shift; 
    my $list = shift; 
    my $r; 
    
    my @lists = (); 
    if($list eq '_all') { 
        @lists = available_lists(-In_Random_Order => 1)
    }
    else { 
        push(@lists, $list); 
    }
    
    require DADA::MailingList::Schedules; 
    foreach my $l (@lists){ 			    
        my $sched = DADA::MailingList::Schedules->new({-list => $l});
#        if($sched->enabled) {
            $r .= $sched->run_schedules();  
#       }
        undef($sched); 
    }
    return $r; 
}

sub expire_rate_limit_checks {
    my $self = shift; 
	my $tbl = $DADA::Config::SQL_PARAMS{rate_limit_hits_table}; 
	my $yesterday = (time - 86400); 
	
	require DADA::App::DBIHandle; 
	my $dbi_handle = DADA::App::DBIHandle->new; 
	my $dbh = $dbi_handle->dbh_obj; 
	
	my $query = 'DELETE FROM ' . $tbl . ' WHERE timestamp <= ?'; 
	$dbh->do($query, {}, ($yesterday))
		or die "cannot do statement $DBI::errstr\n"; 
		
	return " Done!\n";
}

sub clean_out_mime_cache { 
	my $self = shift;
	
	if($DADA::Config::MIME_TOOLS_PARAMS->{tmp_to_core} != 1){ 	
		require   DADA::App::MIMECache; 
		my $dam = DADA::App::MIMECache->new; 
		$dam->clean_out; 
		undef $dam; 
		return " Done!\n";
	}
	else { 
		return "MIME files written in core, skipping!\n";
	}

}

sub lock_file {

    my $self = shift;

    my $i = 0;

    my $countdown = shift || 10;

	if(-f $self->lockfile){ 
		if(-M $self->lockfile > 1){ 
			$self->remove_lockfile(); 
		}
	}
	
    if ( open my $fh, ">", $self->lockfile ) {
        chmod $DADA::Config::FILE_CHMOD, $self->lockfile;
        {
            my $count = 0;
            {
                flock $fh, LOCK_EX | LOCK_NB and last;

                sleep 1;
				$count++;
                redo if $count < $countdown;

                carp "Couldn't lock semaphore file '"
                  . $self->lockfile
                  . "' because: '$!', exiting.";
                return undef;
            }
        }
		return $fh;
    }
    else {
        carp "Can't open semaphore file " . $self->lockfile . " because: $!";
		return undef;
    }
}

sub remove_lockfile { 
	my $self = shift; 
	
    my $unlink_check = unlink($self->lockfile);
    if ( $unlink_check != 1 ) {
        carp "deleting," . $self->lockfile . " failed: " . $!;
    	return 0; 
	}
	else { 
		return 1;
	}
}

sub unlock_file {

    my $self = shift;
    my $fh = shift || croak "You must pass a filehandle to unlock!";
    if(close($fh)){ 
		$self->remove_lockfile();
	    return 1;
	}
	else { 
		carp q{Couldn't unlock semaphore file for, } . $fh . ' ' . $!;
		return 0; 
	}
}


sub DESTORY {}
sub END {}

1;