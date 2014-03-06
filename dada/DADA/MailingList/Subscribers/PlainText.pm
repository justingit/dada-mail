package DADA::MailingList::Subscribers::PlainText; 

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

use strict; 



#######################################################################



=pod

=head1 NAME DADA::MailingList::PlainText

=head1 DESCRIPTION

This is the Plain Text version of Dada Mail's subscriber database.

=head1 SYNOPSIS

my $lh = List::Plaintext->new(-List => $list); 

=head2 to $lh->open_email_list(-Path => $path, -Type='list');

returns an array of all e-mail addresses for $list. It can also return only a reference 
you say -As_Ref => 1, 

this is used mostly for the black list functions, as its painfully clear that loading up 
100,000 email addreses into memory is a Bad Thing. 

=cut

# note. BAD to do on large lists. Bad Bad Bad



=pod

=head2 open_list_handle(-List => $list) 

This function will open the email list file with a handle of LIST, 
it also does a whole bunch of error checking, taint checking, etc, that I'm 
too lazy to do everytime I want a list open. 

=cut 


sub open_list_handle { 

	my $self = shift; 
	my %args = (
				-Type => 'list',
				@_,
				); 
				
	my $path_to_file = make_safer($DADA::Config::FILES . '/' . $self->{list} . '.' . $args{-Type}); 
	
	sysopen(LIST, $path_to_file, O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
	   or croak "couldn't open '$path_to_file' for reading: $!\n";
	
	   flock(LIST, LOCK_SH);
		binmode LIST, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';
}


sub search_list { 

	my $self = shift; 
	
	my ($args) = @_; 

    if(!exists($args->{-start})){ 
        $args->{-start} = 0;     
    }
    if(!exists($args->{'-length'})){ 
        $args->{'-length'} = 100;     
    }
        
	my $r         = [];
	my $email     = ''; 
	my $query = quotemeta($args->{-query}); 
    my $count   = 0;
    
    $self->open_list_handle(-Type => $args->{-type});
    while(defined($email = <LIST>)){
		chomp($email); 
        if($email =~ m/$query/i){ # case insensitive?
			$count++;
			
			# This is to still count, but not return...
	        next if $count < ( $args->{ -start } * $args->{ '-length' });
	        next if $count > ( ( $args->{ -start } * $args->{ '-length' }) + ($args->{'-length'}) );
	        
			push(
				@$r, 
				{
					email  => $email, 
					type   => $args->{-type}, 
					fields => []
				}
			);
	
        }
    }
    close(LIST); 
    

	return ($count, $r); 


}




sub domain_stats { 
	
	my $self    = shift;

	my ($args) = @_; 
	
	my $count;
	if(exists($args->{-count})) { 
		$count = $args->{-count}; 
	}
	else { 
		$count = 15; 
	}
	
	my $type = 'list'; 
	if(exists($args->{-type})){ 
		$type = $args->{-type};
	}
	
	my $domains = {};
			
	$self->open_list_handle(-Type => $type); 
	my $email = undef; 
	while(defined($email = <LIST>)){ 
		chomp($email);
		my ($name, $domain) = split('@', $email); 
		if(!exists($domains->{$domain})){ 
			$domains->{$domain} = 0;
		}
		$domains->{$domain} = $domains->{$domain} + 1; 
	}
	
	# Sorted Index
	my @index = sort { $domains->{$b} <=> $domains->{$a} } keys %$domains; 
	
	# Top n
	my @top = splice(@index,0,($count-1));
	
	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $domains->{$_};
	}
	
	my $final = [];
	foreach(@top){ 
		push(@$final, {domain => $_, number => $domains->{$_}});
	}
	if($other > 0) { 
		push(@$final, {domain => 'other', number => $other}); 
	}
	
	# Return!
	return $final;
	
	

}




sub inexact_match {

	# DEV: The only thing weird is that there's really no locking going on. Important?
	
    my $self = shift;
    my ($args) = @_;
    my $email = cased( $args->{ -email } );
    my ( $name, $domain ) = split ( '@', $email );

	$name = $name . '@'; 
	$domain = '@' . $domain;
	
    $self->open_list_handle( -Type => $args->{ -against } );

    my $found = 0;

    my $sub = undef;
    while ( defined( $sub = <LIST> ) ) {
        chomp($sub);
		if (   
			$email eq $sub
            || $sub eq $name
            || $sub eq $domain )
        {		
            $found = 1;
            last;
        }
    }
    close(LIST);
    return $found;
}


=pod


=head2 my $count = print_out_list(-List => $list);

This function will print out a list. 
Thats it. 


=cut

=pod

=head2 get_black_list_match(\@black_list, \@list); 


zooms through the black list and does regex matches on email addresses to see 
of they match. 




=cut

sub print_out_list { 

	my $self = shift;
	 	
	my %args = (-Type => 'list',
				-FH  => \*STDOUT,
				@_); 
	
	my $fh = $args{-FH};
	my $email; 
	my $count; 
	if($self->{list}){ 
		$self->open_list_handle(-Type => $args{-Type}); 
		while(defined($email = <LIST>)){ 
			# DEV: Do we remove newlines here? Huh? 
			# BUG: [ 2147102 ] 3.0.0 - "Open List in New Window" has unwanted linebreak?
			# https://sourceforge.net/tracker/index.php?func=detail&aid=2147102&group_id=13002&atid=113002
			$email =~ s/\n|\r/ /gi;
			
			# And... then... get rid of the last space? 
			$email =~ s/ $//gi;
			
			
			#	chomp($email);
			print $fh $email; 
			
			# And then, and then, put the newline back? 
			print "\n"; 
			$count++; 
			
		}
		close (LIST);            
		return $count; 
	}

}



sub clone { 
	my $self = shift; 
	my ($args) = @_; 
	if ( !exists( $args->{ -from } ) ) {
       croak "Need to pass the, '-from' (list type) parameter!"; 
    }
	if ( !exists( $args->{ -to } ) ) {
       croak "Need to pass the, '-from' (list type) parameter!"; 
    }
	if($self->allowed_list_types($args->{ -from }) == 0){ 
		croak $args->{ -from } . " is not a valid list type!"; 
	}
	if($self->allowed_list_types($args->{ -to }) == 0){ 
		croak $args->{ -to } . " is not a valid list type!"; 
	}

	# First we see if there's ANY current members in this list; 
	if($self->num_subscribers({-type => $args->{-to}})  > 0){ 
		carp "CANNOT clone a list subtype to another list subtype that already exists!";
		return undef; 
	}
	else { 
		require File::Copy; 
		File::Copy::copy(
			make_safer($DADA::Config::FILES . '/' . $self->{list} . '.' . $args->{ -from }),
			make_safer($DADA::Config::FILES . '/' . $self->{list} . '.' . $args->{ -to }),
		); 
		return 1; 
	}
	
}




sub subscription_list { 
	
    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{ -start } ) ) {
        $args->{ -start } = 0;
    }
    if ( !exists( $args->{ -type } ) ) {
        $args->{ -type } = 'list';
    }
             
	my $count = 0; 
	my $list = []; 
	my $email; 
	
	$self->open_list_handle(-Type => $args->{-type}); 
	while(defined($email = <LIST>)){ 
			if($count < ( $args->{ -start } * $args->{ '-length' })) { 
				$count++;
				next; 
			}
	        if ( exists( $args->{'-length'} ) ) {
				$count++;
	            last if $count > ( ( $args->{ -start } * $args->{ '-length' }) + ($args->{'-length'}) );
	        }
			else { 
			}
			chomp($email); 
			push(
				@$list, 
				{
					email => $email, 
					type  => $args->{-type}
				}
			);  
					
		}
		close (LIST);            
		return $list; 
}




sub check_for_double_email {

    my $self = shift;

    my %args = (
        -Email      => undef,
        -Type       => 'list',
        -Match_Type => 'sublist_centric',

        @_
    );

    if ( $self->{list} and $args{-Email} ) {

       # $self->open_list_handle( -Type => $args{-Type} );
		#my $path_to_file = make_safer($DADA::Config::FILES . '/' . $self->{list} . '.' . $args{-Type}); 
		#open my $LIST, '+>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $path_to_file or die "can't open '$path_to_file': $!"; 
		
		
		my $path_to_file = make_safer($DADA::Config::FILES . '/' . $self->{list} . '.' . $args{-Type}); 

		sysopen(LIST2, $path_to_file, O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
	   		or croak "couldn't open '$path_to_file' for reading: $!\n";

	   flock(LIST2, LOCK_SH);
		binmode LIST2, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';
			
			
        my $check_this = undef;
        my $email      = $args{-Email};
        my $in_list    = 0;

        while ( defined( $check_this = <LIST2> ) ) {

            chomp($check_this);
            if (
                (
                    $args{-Type} eq "black_list" || $args{-Type} eq "white_list"
                )
                && $args{-Match_Type} eq 'sublist_centric'
              )
            {

                if ( !$check_this || $check_this eq '' ) {
                    carp "blank line in subscription list?!";
                    next;
                }

				my ( $name, $domain ) = split ( '@', $email );
				$name = $name . '@'; 
				$domain = '@' . $domain;

					if (   
						$email eq $check_this
				        || $check_this eq $name
				        || $check_this eq $domain )
				    {		
						 $in_list = 1;
		                    last;
				    }

            }
            else {

                if ( cased($check_this) eq cased($email) ) {
                    $in_list = 1;
                    last;
                }
            }
        }

        close(LIST2);

        return $in_list;

    }
    else {

        return 0;

    }

}



sub num_subscribers { 
	my $self = shift;
	my ($args) = @_; 
	if(! exists($args->{-type})){ 
		$args->{-type} = 'list'; 
	}


	my $count = 0; 
	my $buffer; 
	$self->open_list_handle(-Type => $args->{-type});
	while (sysread LIST, $buffer, 4096) {
		$count += ($buffer =~ tr/\n//);
	}
	close LIST or die $!;
	return $count; 
}



sub copy_all_subscribers { 
	
	my $self   = shift ;
	my ($args) = @_; 
	my $total  = 0; 
	if(! exists($args->{-from})){ 
		croak "you MUST pass '-from'";
	}
	else { 
		if ( $self->allowed_list_types( $args->{-from} ) != 1 ) {
            croak '"' . $args->{ -from } . '" is not a valid list type! ';
        }
	}
	if(! exists($args->{-to})){ 
		croak "you MUST pass '-to'";
	}
	else { 
		if ( $self->allowed_list_types( $args->{-to} ) != 1 ) {
            croak '"' . $args->{ -to } . '" is not a valid list type! ';
        }	
	}
	
	
	$self->open_list_handle( -Type => $args->{ -from } );

    my $i     = 0;
    my $cache = [];
    my $email = undef;
    while ( defined( $email = <LIST> ) ) {
		chomp($email); 
		 my $n_sub = $self->add_subscriber(
			{
				-email         => $email,
				-type          => $args->{-to}, 
				-dupe_check    => {
									-enable  => 1, 
									-on_dupe => 'ignore_add',  
            					},
			}
		 );
		if(defined($n_sub)){ 
			$total++; 
		}
    }
    close(LIST);

	return $total; 
}



sub remove_all_subscribers {

    my $self = shift;
    my ($args) = @_;

    if ( !exists $args->{ -type } ) {
        $args->{ -type } = 'list';
    }
    if ( !exists $args->{ -count } ) {
        $args->{ -count } = 0;
    }

	my $num_subscribers = $self->num_subscribers({-type => $args->{-type}});
	my $count = 1000;
    if ( $count > $num_subscribers ) {
        $count = $num_subscribers;
    }

    $self->open_list_handle( -Type => $args->{ -type } );

    my $i     = 0;
    my $cache = [];
    my $email = undef;
    while ( defined( $email = <LIST> ) ) {
		chomp($email); 
        push ( @$cache, $email );
        $i++;
        if ( $i >= $count ) {
            last;
        }
    }
    close(LIST);

    $self->_remove_from_list(
        -Email_List => $cache,
        -Type       => $args->{ -type },
    );

    $args->{ -count } = $args->{ -count } + $count;
    if ( ( $num_subscribers - $count ) == 0 ) {
        return $args->{ -count };
    }
    else {
        $self->remove_all_subscribers(
            {
                -type  => $args->{ -type },
                -count => $args->{ -count },

            }
        );
    }
}




# NOTES: 
#
#This is especially the case for Solaris 9 where shared locks are the same as
#exclusive locks, AND the file MUST be writable even if you never write to
#it! If it isn't writable you get a "Bad file number" Error.#
#
#http://www.cit.gu.edu.au/~anthony/info/perl/lock.hints

sub _remove_from_list { 

	my $self = shift; 
	
	my %args = (-Email_List => undef, 
	            -Type       => 'list',
				-log_it     => 1, 
	            @_); 

	my $list     = $self->{list}; 
	my $path     = $DADA::Config::FILES; 
	 
	 
	my $type     = $args{-Type}; 
	my $deep_six = $args{-Email_List}; 
	

	if($list and $deep_six){ 
	
		# create the lookup table 
		my %lookup_table; 
		for my $going(@$deep_six){
			chomp($going);
			$going = strip($going);
			$going = cased($going);
			$lookup_table{$going} = 1;
		}


		# the lookup table holds addresses WE DON'T WANT. SO rememeber that, u.
		my $main_list = "$path/$list.$type"; 
		   $main_list = make_safer($main_list); 
		   $main_list =~ /(.*)/;
		   $main_list = $1; 
			
		my $message_id = message_id();	
		my $temp_list = "$main_list.tmp-$message_id";
		my $count; 


		########################################################################
		# this is my big hulking Masterlock that you'll need a shotgun 
		# to blow off. This is me being anal retentive.
		#sysopen(SAFETYLOCK, "$DADA::Config::FILES/$list.lock",  O_RDWR|O_CREAT, 0777); 
			
		my $lock_file = "$DADA::Config::TMP/$list.lock"; 	
		   $lock_file = make_safer($lock_file); 
		   $lock_file =~ /(.*)/;
		   $lock_file = $1; 
		# from camel book:
		# sysopen(DBLOCK,     $LCK,        O_RDONLY| O_CREAT)  	
		# from 2.8.15 :
		# sysopen(SAFETYLOCK, $lock_file,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
		# new: 
		
		 
		 sysopen(SAFETYLOCK, $lock_file,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) 
			or croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - Cannot open list lock file '$DADA::Config::TMP/$list.lock' - $!";

		 chmod($DADA::Config::FILE_CHMOD , $lock_file) 
		    if -e $lock_file; 
		    
		    {
			my $sleep_count = 0; 
				{ 
				# from camel book: 
				#flock(DBLOCK, LOCK_SH)   or croak "can't LOCK_SH $LCK: $!";
				
				# from 2.8.15 
				# flock SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
				
				# NB = non blocking
				# I don't think you can have a non blocking and an exclusing block
				# in the same breadth...?
				
				flock SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
				
				sleep 1;
				redo if ++$sleep_count < 11; 
				
				# ok, we've waited 'bout 10 seconds... 
				# nothing's happening, let's say  fuck it. 
				
				carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: Server is way too busy to unsubscribe people, waited 10 seconds to get access to the list file for $list, giving up: $!\n";
			
				return 'too busy'; 
				exit(0); 
			}

		}


		# safety lock is set. This should give us a nice big shield to do some file 
		# juggling and updating. I think there is a race condition between when the 
		# the first time the temp and list file are open, and the second time. 
		# This should stop that. wee. 
		############################################################################		

		#open the original list
		sysopen(MAIN_LIST, $main_list,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Can't open email list to sort through and make deletions at '$main_list': $!";
		flock(MAIN_LIST, LOCK_SH) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Can't create a shared lock to sort through and make deletions at '$main_list': $!";
	  
		# open a temporary list
		sysopen(TEMP_LIST, $temp_list,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't create temporary list to sort out deleted e-mails at '$temp_list': $!" ; 
		flock(TEMP_LIST, LOCK_EX) or
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't create an exculsive lock to sort out deleted e-mails at'$temp_list': $!" ; 	
			
		my $check_this; 
	
		while(defined($check_this  = <MAIN_LIST>)){ 
			 #lets see, if they pass, send em over. 
			 chomp($check_this); 
			 $check_this = strip($check_this);
			 $check_this = cased($check_this);
			 
			 # unless its in our delete list, 
			  unless(exists($lookup_table{$check_this})){ 
				  # print it into the temporary list
				  print TEMP_LIST $check_this, "\n";	
			  }else{
				  #missed the boat! 
				  $count++;
				  # js - log it
					if($args{-log_it} == 1) { 
						$self->{'log'}->mj_log(
							$self->{list},
							"Unsubscribed from $list.$type", 
							$check_this
						) if $DADA::Config::LOG{subscriptions}; 
			  		}
			}
		}
		
		close (MAIN_LIST) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - did not successfully close file '$main_list': $!"; 
			
		close (TEMP_LIST) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - did not successfully close file '$temp_list': $!";
	
		#open the new list, open the old list, copy old to new, done. 
	
	
		sysopen(TEMP_LIST, $temp_list,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD ) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Can't open temp email list '$temp_list' to copy over to the main list : $!";
		flock(TEMP_LIST, LOCK_SH) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Can't create a shared lock to copy over email addresses at  '$temp_list': $!";

		sysopen(MAIN_LIST, $main_list,  O_WRONLY|O_TRUNC|O_CREAT, $DADA::Config::FILE_CHMOD ) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't open email list to update '$main_list': $!" ; 
		flock(MAIN_LIST, LOCK_EX) or
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't create an exclusive lock to update '$main_list': $!" ; 	
			
			
		my $passed_email;	
		while(defined($passed_email  = <TEMP_LIST>)){ 
			 #lets see, if they pass, send em over. 
			 chomp($passed_email); 
			 print MAIN_LIST $passed_email, "\n";
		}
		
		close (MAIN_LIST) or 
		croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - did not sucessfully close file '$main_list': $!"; 
		
		close (TEMP_LIST) or 
		croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - did not sucessfully close file '$temp_list': $!";
		
		unlink($temp_list) or 
		carp "$DADA::Config::PROGRAM_NAME  $DADA::Config::VER Error: Could not delete temp list file '$temp_list': $!"; 
		
		close(SAFETYLOCK);
		chmod($DADA::Config::FILE_CHMOD , $lock_file);
		unlink($lock_file) or carp "couldn't delete lock file: '$lock_file' - $!";
		
		 
		return $count; 
		
	}else{ 
	
		carp('$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: No list information given at Plain_Text.pm for _remove_from_list()');
		return ('no list');
	} 			 
}





=pod

=head2 my $listpath = create_mass_sending_file(-List => $list, -ID => $message_id); 

When sending list messages to the entire list, we make a temp file called $istname.list.$listid
where $listname is the name of your list, and $list_id is an id number, usually made form the list, 
and created form the message ID if we have one.

This can easilly be feed into either the Mail::Bulkmail module or our homebrew batch system. 
after the Lists are send DADA::Mail::Send.pm should remove this file. 


This function can also pass a reference to an array of addresses that shouldn't get sent the lsit message, 
you could theoretically pass the black list, or for the  Bridge Plugin, the mail alias address you set up. 

				-Ban => [$address_on, $address_two], 
				
=cut



sub create_mass_sending_file { 

	my $self = shift; 
	
	my %args = (-Type      		  => 'list', 
				-Pin       		  =>  1,
				-ID        		  =>  undef, 
				-Ban      		  =>  undef, 
				-Bulk_Test		  =>  0,
				
				-Save_At          => undef, 
				
				-Test_Recipient   => undef, 
				@_); 
	
	my $list       = $self->{list}; 
	   $list       =~ s/ /_/g;
	my $path       = $DADA::Config::TMP ; 
	my $type       = $args{-Type}; 
	
	
	my $message_id = message_id();
	
	#use the message ID, If we have one. 
	my $letter_id = $args{'-ID'} ||  $message_id;	
	   $letter_id =~ s/\@/_at_/g; 
	   $letter_id =~ s/\>|\<//g; 
	
	my $n_msg_id = $args{'-ID'} || $message_id;
       $n_msg_id =~ s/\<|\>//g;
       $n_msg_id =~ s/\.(.*)//; #greedy
   
	   
	
	my %banned_list; 
	
	if($args{-Ban}){ 
		$banned_list{$_} = 1 for @{$args{-Ban}}; 
	}
	
	my $list_file    = make_safer($DADA::Config::FILES . '/' . $list . '.' . $type); 
	my $sending_file = make_safer($args{-Save_At}) || make_safer($DADA::Config::TMP    . '/msg-' . $list . '-' . $type . '-' . $letter_id); 
	
			
	#open one file, write to the other. 
	my $email; 
	
	require  DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $list}); 
	my $li = $ls->get; 
	
	sysopen(LISTFILE, "$list_file",  O_RDONLY|O_CREAT, $DADA::Config::FILE_CHMOD ) or 
		croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Cannot open email list for copying, in preparation to send out bulk message: $! "; 
	binmode LISTFILE, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';
	flock(LISTFILE, LOCK_SH); 
		
	open my $SENDINGFILE, '>', $sending_file or
		croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: Cannot create temporary email list file for sending out bulk message: $!"; 
	binmode $SENDINGFILE, ':encoding(' . $DADA::Config::HTML_CHARSET . ')';
	chmod($DADA::Config::FILE_CHMOD, $SENDINGFILE); 	
	flock($SENDINGFILE, LOCK_EX);	


	my $have_first_recipient = 1; 
	if(
		$args{'-Bulk_Test'} == 0 
	 && $self->{ls}->param('mass_mailing_send_to_list_owner') == 0
	){ 
		$have_first_recipient = 0; 
	}
	# Sending these types of messages to the list owner is very confusing
	if($type =~ m/_tmp\-just_subscribed\-|_tmp\-just_unsubscribed\-|_tmp\-just_subed_archive\-/){ 
		$have_first_recipient = 0; 		
	}
	
	
	require     Text::CSV;
	my $csv   = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	my $total = 0; 
	
	if($have_first_recipient == 1){ 
	
	
	    my $first_email = $li->{list_owner_email}; 
    
	    if($args{'-Bulk_Test'} == 1 && $args{-Test_Recipient}){ 
	        $first_email = $args{-Test_Recipient};
	    }
    
		my ($lo_e_name, $lo_e_domain) = split('@', $first_email); 
	
	

		my @lo = ( 
					$first_email,
					$lo_e_name, 
					$lo_e_domain, 
					$list,
	                $self->{ls}->param('list_name'), 
					$n_msg_id,
				);
		 if ( $csv->combine(@lo) ) {
		     my $hstring = $csv->string;
		     print $SENDINGFILE $hstring, "\n";
		 }
		 else {
		     my $err = $csv->error_input;
		     carp "combine() failed on argument: ", $err, "\n";
		 }
	
		$total++;
	}
	
	if($args{'-Bulk_Test'} != 1){ 
        while(defined($email  = <LISTFILE>)){ 
            chomp($email); 
            unless(exists($banned_list{$email})){
	
				my @sub = (
					$email,
					( split ( '@', $email ) ), 
					$list,
					$self->{ls}->param('list_name'),
					$n_msg_id,
				);
								
				if ( $csv->combine(@sub) ) {
				     my $hstring = $csv->string;
				     print $SENDINGFILE $hstring, "\n";
				 }
				 else {
				     my $err = $csv->error_input;
				     carp "combine() failed on argument: ", $err, "\n";
				 }
				
                $total++;
            }
		}		
	}

	# why aren't I using: flock(LISTFILE), LOCK_UN); ? I think it's because it's not needed, if close(LISTFILE) is called...
	close(LISTFILE) 
		or croak ("$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - could not close list file '$list_file'  successfully"); 
	
	close($SENDINGFILE) 
		or croak ("$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - could not close temporary sending  file '$sending_file' successfully"); 
	
	#chmod! 
	chmod($DADA::Config::FILE_CHMOD , $sending_file);	
	
	return ($sending_file, $total); 

}


=pod

=head2 my ($unique, $duplicate) = unique_and_duplicate(-New_List => \@new_list); 

This is used to mass add and remove email addresses from a list, it takes a 
array ref full of new email addresses, and see if they are already in the list. 

my ($unique_ref, $duplicate_ref) = weed_out_subscribers(-List     => $list, 
														-Path     => $DADA::Config::FILES, 
														-Type     => 'list', 
														-New_List => \@addresses, 
														);

=cut

 
sub unique_and_duplicate { 

	my $self = shift; 
	
	my %args = (-New_List      => undef, 
	            -Type          => 'list',
	            @_,
	           ); 
	
	
	# first thing we got to do is to make a lookup hash. 
	my %lookup_table; 
	my $address_ref = $args{-New_List}; 
	my $list        = $self->{list};
	
	if($list and $address_ref){
	
		for(@$address_ref){$lookup_table{$_} = 0}
		
		# easy enough, now, we'll open up the list, and 
		# keep them as 0 if they're all unique, and 
		# flag them as 1 if they're in the list. 
	
		$self->open_list_handle(-Type => $args{-Type});
						 
		my $email; 
		
		#let us go.. 
			while(defined($email = <LIST>)){ 
			chomp($email);
			$lookup_table{$email} = 1 if(exists($lookup_table{$email})); 
			#nabbed it, 
			}
			close (LIST); 
			
			
		#lets lookie and see what we gots.     
		my @unique; 
		my @double; 
		my $value; 
		
		
		
		for(keys %lookup_table){
			$value = $lookup_table{$_}; 
			if($value == 1){ 
				push(@double, $_)
			}else{ 
				push(@unique, $_) 
			}
		}
		
		#again, harmony is restored to the force.
		return(\@unique, \@double); 
	
	}else{ 
	
		carp("$DADA::Config::PROGRAM_NAME $DADA::Config::VER No list name or list reference provided!");
		return undef;
	
	}
}

sub remove_this_listtype {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-type} ) ) {
        croak('You MUST specific a list type in the "-Type" parameter');
    }
    else {
        if ( $self->allowed_list_types( $args->{-type} ) != 1 ) {
            croak '"' . $args->{-type} . '" is not a valid list type! ';
        }
    }

    my $deep_six = make_safer(
        $DADA::Config::FILES . '/' . $self->{list} . '.' . $args->{-type} );

    if ( -e $deep_six ) {
        my $n = unlink($deep_six);
        if ( $n == 0 ) {
            carp "couldn't delete '$deep_six'! " . $!;
 			return 0;
        }
        else {
            return 1;
        }
    }
    else {
        return 1;
    }

}




sub can_use_global_black_list { 

	my $self = shift; 
	return 0; 

}




sub can_use_global_unsubscribe { 

	my $self = shift; 
	return 0; 

}




sub can_filter_subscribers_through_blacklist { 
	
	my $self = shift; 
	return 0; 
}

sub can_have_subscriber_fields { 

    my $self = shift; 
    return 0; 
}





sub DESTROY {}

1;



=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 
