package DADA::App::BounceScoreKeeper::baseSQL; 

use strict; 


use lib qw(
	../../../ 
	../../../perllib 
);

use DADA::Config; 
use DADA::App::Guts; 

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_BounceScoreKeeper}; 


my $dbi_obj; 

use Carp qw(croak carp); 

sub new {

	my $class = shift;
	
	my %args = (
			-List     => undef,
			@_,
	); 

	if(!exists($args{-List})){ 
		croak "You MUST pass a list in, -List!"; 
	}


	my $self = {};			
	bless $self, $class;
	
	
	$self->_init(\%args); 
	$self->_sql_init(\%args); 

	return $self;
}



sub _sql_init  { 
	
    my $self = shift; 
        
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

	if(!keys %{$self->{sql_params}}){ 
		croak "sql params not filled out?!"; 
	}
	else {
		
	}


	if(!$dbi_obj){ 
		require DADA::App::DBIHandle; 
		$dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}else{ 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}
	
}

sub tally_up_scores { 

	warn "tally_up_scores method called."
		if $t;
		
    my $self             = shift; 
    my $scores           = shift; 
    my $give_back_scores = {}; 
    
    
    foreach my $email(keys %$scores){ 
 
		my $query = 'SELECT email, score FROM ' . $self->{sql_params}->{bounce_scores_table} .' WHERE email = ? AND list = ?'; 
		
		if($t){ 
			warn '$query ' . $query; 
			warn 'email: ' . $email;  
			warn 'list: ' . $self->{name}; 
		}
	
		my $sth   = $self->{dbh}->prepare($query);
		   $sth->execute($email, $self->{name})
				or croak "cannot do statment '$query'! $DBI::errstr\n"; 

		my @score  = $sth->fetchrow_array(); 
		
		$sth->finish; 
		if($score[0] eq undef) { 
			
			warn "It doesn't look like we have a record for this address ($email) yet, so we're going to add one:"
				if $t; 
		
			my $query2 = 'INSERT INTO ' . $self->{sql_params}->{bounce_scores_table} .'(email, list, score) VALUES (?,?,?)'; 
			my $sth2  = $self->{dbh}->prepare($query2);
			   $sth2->execute($email, $self->{name}, $scores->{$email})
					or croak "cannot do statment '$query2'! $DBI::errstr\n"; 
			$give_back_scores->{$email} = $scores->{$email}; 
					
			$sth2->finish; 
		}
		else { 
		
			
			my $new_score = $score[1] + $scores->{$email}; 

			warn "Appending the score for ($email) to a total of: $new_score: via ' $score[1]' plus '$scores->{$email}'"
			 if $t; 

			my $query2 = 'UPDATE ' . $self->{sql_params}->{bounce_scores_table} .' SET score = ? WHERE email = ? AND list = ?'; 
			my $sth2   = $self->{dbh}->prepare($query2);
			   $sth2->execute($new_score, $email, $self->{name})
					or croak "cannot do statment '$query2'! $DBI::errstr\n"; 
	
			$give_back_scores->{$email} = $new_score; 
			
			$sth2->finish; 
		}
    }
    
	return $give_back_scores; 
}




sub removal_list { 

	warn "removal_list method called."
		if $t; 
		
    my $self         = shift; 
    my $threshold    = shift || 0; 
    my $removal_list = [];


	my $query = 'SELECT email, score FROM ' . $self->{sql_params}->{bounce_scores_table} .' WHERE list = ? AND score >= ?';
	warn "Query:" .  $query
	 if $t; 
	
	my $sth   = $self->{dbh}->prepare($query);
	   $sth->execute($self->{name}, $threshold)
			or croak "cannot do statment '$query'! $DBI::errstr\n";
		
			
	while(my ($email, $score) = $sth->fetchrow_array){ 
		warn "Found email, $email with score, $score"
		 if $t; 
		
		push(@$removal_list, $email);
	}
	$sth->finish;
	
    return $removal_list;

}


sub flush_old_scores { 

    my $self      = shift; 
    my $threshold = shift || 0;

	my $query = 'DELETE FROM ' . $self->{sql_params}->{bounce_scores_table} .' WHERE list = ? AND score >= ?';
	my $sth   = $self->{dbh}->prepare($query);
	   $sth->execute($self->{name}, $threshold)
			or croak "cannot do statment '$query'! $DBI::errstr\n";	
	   $sth->finish; 

}




sub raw_scorecard { 

    my $self = shift; 
    my ($offset, $rows) = @_; 
    
	my $query = 'SELECT email, score FROM ' . $self->{sql_params}->{bounce_scores_table} .' WHERE list = ? ORDER BY email'; 
	my $sth   = $self->{dbh}->prepare($query);
	   $sth->execute($self->{name})
			or croak "cannot do statment '$query'! $DBI::errstr\n";	
	
	my $all_scores = {}; 
	my @keys = (); 
	

	while( my ($email, $score) = $sth->fetchrow_array){ 
		$all_scores->{$email} = $score; 
		push(@keys, $email); 
	}
	
	$sth->finish; 
	
    my $return_array = [];
    
    
     for (my $x = 0; $x < $rows; $x++) {
        push(@$return_array, [ $keys[$offset + $x], $all_scores->{$keys[$offset + $x]}]);
     }

    return ($return_array);
	
}


sub num_scorecard_rows { 

        my $self = shift; 
    
		my $query = 'SELECT COUNT(*) FROM ' . $self->{sql_params}->{bounce_scores_table} .' WHERE list = ?'; 
		my $sth   = $self->{dbh}->prepare($query);
		   $sth->execute($self->{name})
			 	or croak "cannot do statment '$query'! $DBI::errstr\n";	
		
		  
        my $count =  $sth->fetchrow_array; 

		$sth->finish; 
		
		if($count eq undef){ 
			return 0; 
		}
		else { 	
			return $count; 
		}
}




sub erase { 

    my $self = shift; 

	my $query = 'DELETE FROM ' . $self->{sql_params}->{bounce_scores_table} .' where list = ?'; 
	my $sth   = $self->{dbh}->prepare($query);
	   $sth->execute($self->{name})
			or croak "cannot do statment '$query'! $DBI::errstr\n";	
	   $sth->finish;
	return 1; 

}

sub _list_name_check { 
	my ($self, $n) = @_; 
		$n = $self->_trim($n);
	return 0 if !$n; 
	return 0 if $self->_list_exists($n) == 0;  
	$self->{name} = $n;
	return 1; 
}

sub _trim { 
	my ($self, $s) = @_;
	return DADA::App::Guts::strip($s);
}





sub _list_exists { 
	my ($self, $n)  = @_; 
	return DADA::App::Guts::check_if_list_exists(-List => $n);
} 






=pod

=head1 COPYRIGHT 

Copyright (c) documentation/install_dada_mail.pod.html Simoni All rights reserved. 

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
