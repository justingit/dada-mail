package DADA::App::BounceScoreKeeper::Db; 

use lib qw(
	../../../ 
	../../../perllib 
);

use DADA::Config; 

use Carp qw(croak carp); 

# Why was this commented out?!
use AnyDBM_File; 

use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT 
O_CREAT 
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB
); 


use base qw(DADA::App::GenericDBFile);

sub new {
	my $class = shift;
	
	my %args = (-List     => undef,
				-new_list => 0,  
					@_); 
					     
    my $self = SUPER::new $class (
    							  function => 'bounces',
    							 );  

       $self->{new_list} = $args{-new_list};
	   $self->_init(\%args); 
	   
	   return $self;
}



sub tally_up_scores { 

    my $self   = shift; 
    my $scores = shift; 
    my $give_back_scores = {}; 
    
    $self->_open_db; 
		    
    for(keys %$scores){ 
		#warn '$_ ' . $_; 
		#warn '$self->{DB_HASH}->{$_} ' . $self->{DB_HASH}->{$_}; 
		#warn '$scores->{$_} ' . $scores->{$_}; 
		
		my $old_score = $self->{DB_HASH}->{$_}; 
		my $new_score = $old_score + $scores->{$_}; 
		
		delete($self->{DB_HASH}->{$_}); 
 	
		$self->{DB_HASH}->{$_} = $new_score; 

	#	print 'new score is: ' . $new_score; 
		
       #warn "$_ has a score of " . $self->{DB_HASH}->{$_}; 
       $give_back_scores->{$_} = $new_score; 
    }
    $self->_close_db; 
    
    return $give_back_scores; 
}




sub removal_list { 

    my $self         = shift; 
    my $threshold    = shift || 0; 
    my $removal_list = [];

    $self->_open_db; 
    
    for(keys %{$self->{DB_HASH}}){
    
          if($self->{DB_HASH}->{$_} >= $threshold){
            #warn "Adding $_ to removal list.";
            push(@$removal_list, $_);
        }

    }
    
    $self->_close_db; 
    
    return $removal_list

}


sub flush_old_scores { 

    my $self = shift; 
    my $threshold = shift || 0;

    $self->_open_db; 
      
	while ( my ($key, $value) = each %{$self->{DB_HASH}} ) {
	
        if($value >= $threshold){
           # print "Removing $_ "  . $self->{DB_HASH}->{$_} . "from score card.";
            $self->{DB_HASH}->{$key} = undef; # for whatever reason that it doesn't get removed...
            delete($self->{DB_HASH}->{$key});
        }

   }
    
    $self->_close_db; 


    # Flushing - shouldn't be needed? 
	$self->_open_db; 
	$self->_close_db;

}

sub raw_scorecard { 

    my $self = shift; 
	my ($args) = @_;
	
	if(!exists($args->{-page})){ 
		$args->{-page} = 1; 
	}
	if(!exists($args->{-entries})){ 
		$args->{-entries} = 100; 
	}    
    
    $self->_open_db;
    my $scorecard = [];

	foreach(sort keys %{$self->{DB_HASH}}){ 
	   	push(@$scorecard, {
			email => $_,
			score => $self->{DB_HASH}->{$_}, 
		});
	}

    $self->_close_db;
    
	my $total = 0; 
	   $total = $self->num_scorecard_rows; 
	
	my $begin = ($args->{-entries} - 1) * ($args->{-page} - 1);
	my $end   = $begin + ($args->{-entries} - 1);

	if($end > $total - 1){ 
		$end = $total -1; 
	}

	@$scorecard = @$scorecard[$begin..$end];
	
    return ($scorecard);
	
}


sub num_scorecard_rows { 

        my $self = shift; 
        $self->_open_db; 
	
    my $rows = 0; 
  
	#$rows = keys %{$self->{DB_HASH}}; 
  	while ( my ($key, $value) = each %{$self->{DB_HASH}} ) {
    	$rows++;
    }
  
        $self->_close_db;
        
        return $rows; 

}




sub erase { 

    my $self = shift; 
    

	
	if(-e $self->_db_filename){ 
		my $c = unlink($self->_db_filename);
		unless($c == 1){ 
			croak "Didn't delete '$self->_db_filename'"; 
		} 
	}
	else { 
		carp "Didn't find: '$self->_db_filename'";
		
		
		$self->_open_db; 

	   while ( my ($key, $value) = each %{$self->{DB_HASH}} ) {
	   	delete $self->{DB_HASH}->{$key};
	    }
		
	    $self->{DB_HASH} = {}; 
	    $self->_close_db; 

	    # Flushing - shouldn't be needed? 
		$self->_open_db; 
		while ( my ($key, $value) = each %{$self->{DB_HASH}} ) {
			warn "\nSTILL HAVE '$key' : '$value'\n";
		}
		$self->_close_db;
		
		
		
		 
	}
	
	return 1; 

}




=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2011 Justin Simoni All rights reserved. 

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



1;
