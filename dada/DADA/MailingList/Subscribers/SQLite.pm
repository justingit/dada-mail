package DADA::MailingList::Subscribers::SQLite; 

use strict; 

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 

use DADA::Config qw(!:DEFAULT);  

use base "DADA::MailingList::Subscribers::MySQL"; 

use Carp qw(croak carp); 




sub make_table { 

    my $self = shift; 
    
    $self->{dbh}->do('CREATE TABLE ' . $self->{sql_params}->{subscriber_table} . ' (email_id INTEGER PRIMARY KEY AUTOINCREMENT, email text(320), list varchar(16), list_type varchar(64), list_status char(1))')
		 or croak "cannot do statement (at: make_table)! $DBI::errstr\n";   ;    

}

sub remove_subscriber_field { 

    my $self = shift; 
    
    my ($args) = @_;
    if(! exists($args->{-field})){ 
        croak "You must pass a field name in, -field!"; 
    }
    $args->{-field} = lc($args->{-field}); 
    
    $self->validate_remove_subscriber_field_name(
        {
        -field      => $args->{-field}, 
        -die_for_me => 1, 
        }
    ); 
   
       
    ###
    
    my %omit_fields = (
				#	email_id    => 1,
                   email       => 1,
                   list        => 1,
                   list_type   => 1,
                   list_status => 1);	
                   
        
    my @no_homers = (); 
    foreach(@{$self->subscriber_fields}){ 
        if($_ ne $args->{-field}){ 
            push(@no_homers, $_); 
        }      
    }
    my @keep_these_colums = @no_homers;
    my $keep_these_str = 'email, list, list_type, list_status, '; 
	my $make_these_str = ','; 
    foreach(@keep_these_colums){ 
        $keep_these_str .= $_ . ', ';
	}
    $keep_these_str =~ s/\, $//; 

	foreach(@no_homers){ 
		$make_these_str.= $_ . ' text, '; 
	}
	$make_these_str =~ s/\, $|,$//; 

#    CREATE TEMPORARY TABLE t1_backup(a,b);
#    INSERT INTO t1_backup SELECT a,b FROM t1;
#    DROP TABLE t1;
#    CREATE TABLE t1(a,b);
#    INSERT INTO t1 SELECT a,b FROM t1_backup;
#    DROP TABLE t1_backup;


    $self->{dbh}->do('BEGIN TRANSACTION')
 		or croak "cannot do statement $DBI::errstr\n";
    
	# Erm. am I supposed to move over the non-subscriber fields fields as well? I think so...
	# (we aren't - FYI)
	#
	#
	####
	#$self->{dbh}->do('CREATE TEMPORARY TABLE ' . $self->{sql_params}->{subscriber_table} . '_backup(' . $keep_these_str .')')
	#	or croak "cannot do statement $DBI::errstr\n";
#PRIMARY KEY AUTOINCREMENT
	$self->{dbh}->do('CREATE TEMPORARY TABLE ' . $self->{sql_params}->{subscriber_table} . '_backup(email_id INTEGER , email text(320), list varchar(16), list_type varchar(64), list_status char(1) ' . $make_these_str .')')
		or croak "cannot do statement $DBI::errstr\n";
                                                                                                                           
    $self->{dbh}->do('INSERT INTO ' . $self->{sql_params}->{subscriber_table} .'_backup SELECT email_id, ' . $keep_these_str .' FROM ' . $self->{sql_params}->{subscriber_table})
		or croak "cannot do statement $DBI::errstr\n";
    
    $self->{dbh}->do('DROP TABLE ' . $self->{sql_params}->{subscriber_table})
	 	or croak "cannot do statement $DBI::errstr\n";

    $self->make_table(); 
    
    foreach(@no_homers){ 
        $self->add_subscriber_field(
            {
                -field => $_, 
            }
        );
    }
 

    $self->{dbh}->do('INSERT INTO ' . $self->{sql_params}->{subscriber_table} . ' SELECT email_id, ' .  $keep_these_str . ' FROM ' .  $self->{sql_params}->{subscriber_table} . '_backup')
		or croak "cannot do statement $DBI::errstr\n";

    $self->{dbh}->do('DROP TABLE '. $self->{sql_params}->{subscriber_table} . '_backup')
 		or croak "cannot do statement $DBI::errstr\n";
    
    $self->{dbh}->do('COMMIT')
		or croak "cannot do statement $DBI::errstr\n";
    
    ###
    

	$self->_remove_fallback_value({-field => $args->{-field}}); 
	
	return 1; 
	
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
