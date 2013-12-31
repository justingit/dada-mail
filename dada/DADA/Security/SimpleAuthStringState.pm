package DADA::Security::SimpleAuthStringState; 

use strict; 


use lib qw(../../ ../../DADA ../perllib ./ ../ ../perllib ../../ ../../perllib); 

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
LOCK_NB); 


use base qw(DADA::App::GenericDBFile);

sub new {
	my $class = shift;
	
	my %args = (-List => undef,
				-new_list => 0,  
					@_); 
					     
    my $self = SUPER::new $class (
    							  function => 'simple_auth_string_state',
    							 );  
	   
	   $self->_init; 
	   return $self;
}

sub _init { 
    
    my $self = shift; 
    $self->_can_use_md5;


}

sub make_state { 

    my $self = shift; 
    my $str = $self->_create_auth_string; 
    $self->_open_db; 
        $self->{DB_HASH}->{$str} = 1;
    $self->_close_db; 
    
    return $str;
    
}

sub remove_state { 

    my $self  = shift; 
    my $state = shift; 
    
    $self->_open_db; 
    $self->{DB_HASH}->{$state} = undef;
    delete($self->{DB_HASH}->{$state});
    $self->_close_db; 
}

sub check_state {

    my $self  = shift; 
    my $state = shift;
    my $auth  = 0; 
    $self->_open_db; 
    
    if(exists($self->{DB_HASH}->{$state})){ 
        if($self->{DB_HASH}->{$state} == 1){ 
        
             $self->_close_db; 
             $self->remove_state($state); 
             
             return 1; 

        } else { 
             
             $self->_close_db; 
             $self->remove_state($state); 

            return 0; 
        }
    
    } else { 
        return 0; 
    }
 
   

}




sub _can_use_md5 { 


    my $self = shift; 
    	
	my $can_use_md5 = 0; 	
	
	
    eval {require Digest::MD5}; # hey, just in case, right?
    if(!$@){
        $self->{can_use_md5} = 1; 
    }	
}


sub _create_auth_string { 

	my $self = shift; 
	require    DADA::Security::Password; 
	my $str  = DADA::Security::Password::generate_rand_string(undef, 64);
	
	if($self->{_can_use_md5}){
	
	    require Digest::MD5; # Reminder: Ship with Digest::Perl::MD5....
        
        if($] >= 5.008){
            require Encode;
            my $cs = Digest::MD5::md5_hex(safely_encode($$str));
            return $cs;
        }else{ 			
            my $cs = Digest::MD5::md5_hex($$str);
            return $cs;
        }
   } else { 
    # Guess we're faking it...
      return $str; 
   }

} 





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
