package DADA::MailingList::Subscribers::MySQL; 
use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 
#use strict; 

use base qw(DADA::MailingList::Subscribers::baseSQL); 
use DADA::App::Guts;
use DADA::Config qw(!:DEFAULT); 
use Carp qw(croak carp); 


sub add_to_email_list { 

	my $self = shift; 
	
	my %args = (-Email_Ref => undef, 
				-Type      => "list",
				-Mode      => 'append',
				@_);
	
	my $address     = $args{-Email_Ref} || undef;
	my $email_count = 0;
	my $ending      = $args{-Type}; 
	my $write_list  = $self->{list}    || undef;  	
			
	if($write_list and $address){
		
		
		
		if($self->{ls}->param('hard_remove') == 1){ 
		
			foreach(@$address){
				chomp($_);
				$_ = strip($_); 
			
				my $query = "INSERT INTO "
				            .  $self->{sql_params}->{subscriber_table} . 
				            "(email,list,list_type,list_status) VALUES (?,?,?,?)";
				
				
				my $sth = $self->{dbh}->prepare($query);    
				
				
				   $sth->execute(
				   				 $_, 
				   				 $write_list, 
				   				 $args{-Type}, 
				   				 1
				   				 ) or die "cannot do statement! $DBI::errstr\n";   
				   $sth->finish;
					$email_count++;
					$self->{'log'}->mj_log($write_list,"Subscribed to $write_list.$ending", $_) 
						if (($DADA::Config::LOG{subscriptions}) && ($args{-Mode} ne 'writeover')); 
			}
		
		
		}else{ 
		
			foreach(@$address){
				chomp($_);
				$_ = strip($_);
				
				if($self->check_for_double_email(-Email => $_, -Type => $args{-Type}, -Status => 0)){ 
					my $sth = $self->{dbh}->prepare("UPDATE " .  $self->{sql_params}->{subscriber_table} .  " SET list_status   = 1 WHERE email = ? AND list = ? AND list_type = ?");    
			   		$sth->execute($_, $write_list, $args{-Type}) or die "cannot do statement! $DBI::errstr\n";   
			   		$sth->finish;
				}else{ 
			
					 my $sth = $self->{dbh}->prepare("INSERT INTO " .  $self->{sql_params}->{subscriber_table} . "(email,list,list_type,list_status)  VALUES (?,?,?,?)");    
					 
					   $sth->execute($_, $write_list, $args{-Type}, 1) or die "cannot do statement! $DBI::errstr\n";   
					   $sth->finish;
						$email_count++;
						$self->{'log'}->mj_log($write_list,"Subscribed to $write_list.$ending", $_) 
							if (($DADA::Config::LOG{subscriptions}) && ($args{-Mode} ne 'writeover')); 	
				}
			}
		}

		return $email_count; 
	}else{ 
		warn('Dada Mail Error: No list, or list ref was given in add_email_list()');
		return undef;
	}
}





sub make_table { 

	my $self = shift; 
	
	my $query = 'CREATE TABLE dada_subscribers (email_id int4 not null primary key auto_increment, email text, list text, list_type text, list_status char(1));';
	my $sth   = $self->{dbh}->prepare($query); 
	   $sth->execute()
	   		or die "cannot do statement! $DBI::errstr\n";   
}






1;


=pod

=head1 COPYRIGHT 

Copyright (c) 1999-2008 Justin Simoni All rights reserved. 

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

