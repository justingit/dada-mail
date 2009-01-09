package DADA::MailingList::Subscriber::PlainText; 

use lib qw (../../../ ../../../DADA/perllib); 
 
use DADA::Config qw(!:DEFAULT);  

use Carp qw(croak carp); 

my $dbi_obj; 

use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT 
O_CREAT 
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB); 

use DADA::App::Guts;
use DADA::Logging::Usage;

my $log = new DADA::Logging::Usage;


use strict; 

sub new {
	my $class = shift;
	
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
		$self->{ls} = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$self->{ls} = $args->{-ls_obj};
	}
	
	$self->{list} = $args->{-list}; 
	
	my $lh = DADA::MailingList::Subscribers->new({-list => $args->{-list}}); 
	$self->{lh} = $lh;
	

}




sub add { 	
	my $self = shift; 
    
    my ($args) = @_;
 
	if(length(strip($args->{-email})) <= 0){ 
        croak("You MUST supply an email address in the -email paramater!"); 		
	}
	        
     $self->{lh}->add_to_email_list(
     
        -Email_Ref => [($args->{-email})], 
	    -Type      => $args->{-type}, 
     
     );
}




sub get { 

    my $self = shift; 
    my ($args) = @_;
    
    if(! exists $args->{-email}){ 
        croak "You must pass a email in the -email paramater!"; 
    }
    if(! exists $args->{-type}){ 
        $args->{-type} = 'list';
    }
    if(! exists $args->{-dotted}){ 
        $args->{-dotted} = 0;
    }    
    
    my ($n, $d) = split('@', $args->{-email}, 2);
        
    if($args->{-dotted} == 1){     
        return {'subscriber.email' => $args->{-email}, 'subscriber.email_name' => $n, 'subscriber.email_domain' => $d}; 
    } else { 
        return {email => $args->{-email, email_name => $n, email_domain => $d}}; 
    
    }
}




sub move { 
    
    my $self   = shift; 
    
    my ($args) = @_;
    
    if(! exists $args->{-to}){ 
        croak "You must pass a value in the -to paramater!"; 
    }
    if(! exists $args->{-from}){ 
        croak "You must pass a value in the -from paramater!"; 
    }    
    if(! exists $args->{-email}){ 
        croak "You must pass a value in the -email paramater!"; 
    }
    
    if($self->{lh}->allowed_list_types->{$args->{-to}} != 1){ 
        croak "list_type passed in, -to is not valid"; 
    }

    if($self->{lh}->allowed_list_types->{$args->{-from}} != 1){ 
        croak "list_type passed in, -from is not valid"; 
    }
    
     if(DADA::App::Guts::check_for_valid_email($args->{-email}) == 1){ 
        croak "email passed in, -email is not valid"; 
    }
    
    
    my $moved_from_checks_out = 0; 
    if(! exists($args->{-moved_from_check})){ 
        $args->{-moved_from_check} = 1; 
    }
    
    if($self->{lh}->check_for_double_email(-Email => $args->{-email}, -Type => $args->{-from}) == 0){ 
        
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


	if(!exists($args->{-mode})){ 
		$args->{-mode} = 'writeover_check'; 
	}
		
	if($args->{-mode} eq 'writeover'){ 
		if($self->{lh}->check_for_double_email(-Email => $args->{-email}, -Type => $args->{-to}) == 1){ 
			$self->remove(
				{ 
					-email => $args->{-email},
					-type  => $args->{-to}, 
				}
			); 
		}
	}
	else { 
	    if($self->{lh}->check_for_double_email(-Email => $args->{-email}, -Type => $args->{-to}) == 1){ 
	        croak "email passed in, -email ( $args->{-email}) is already subscribed to list passed in, '-to' ($args->{-to})"; 
	    }
	}

   
   
   if($moved_from_checks_out){ 
   
        $self->{lh}->remove_from_list(
            -Email_List =>[$args->{-email}], 
            -Type       => $args->{-from}
        );   
   
    }
    
    $self->add(
        { 
            -email => $args->{-email}, 
            -type  => $args->{-to}, 
        }
    ); 
    
    if ($DADA::Config::LOG{subscriptions}) { 
        $log->mj_log(
            $self->{list}, 
            'Moved from:  ' . $self->{list} . '.' . $args->{-from} . ' to: ' . $self->{list} . '.' . $args->{-to}, 
            $args->{-email}, 
        );
    }


	return 1; 

}




1;