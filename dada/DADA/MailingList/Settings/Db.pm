package DADA::MailingList::Settings::Db; 

use lib qw(../../.. ../../../DADA/perllib); 
use DADA::Config qw(!:DEFAULT);  
use Encode; 

use base qw(DADA::App::GenericDBFile);



=pod

=head1 NAME


DADA::MailingList::Settings::Db

=head1 SYNOPSIS 

 use DADA::MailingList::Settings; 
 my $ls = DADA::MailingList::Settings->new(
			{
				-list => 'mylist'
			}
		); 
  
 my $list_info = $ls->get; 
 
 $ls->save({key => 'value'});

=head1 DESCRIPTION

This module holds the DB File backend for list settings. 

=head1 Public Methods

=cut


use strict; 


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
use Carp qw(croak carp); 




use DADA::App::Guts;  # For now, my dear. 

=pod

=head2 new

returns the DADA::Mailinglist::Settings object.

 my $ls = DADA::MailingList::Settings->new({-list => 'listshortname'});

you can also optionally pass the B<-new_list => 1> parameter to circumvent list checks.

=cut


sub new {
	my $class = shift;
	
	my ($args) = @_; 	
	
	if(!exists($args->{-list})){ 
		croak "You Must pass a list in, -list!"; 
	}
	if(!exists($args->{-new_list})){ 
		$args->{-new_list} = 0; 
	}
						     
    my $self = SUPER::new $class (
    							  function => 'settings',
    							 );  
         
	$self->{new_list} = $args->{-new_list};
	
	$self->_init($args); 

	return $self;
}



=pod

=head2 get

 my $list_info = $ls->get;

returns a hasref of the list settings. Keys are the name of the setting, value is the 
value of the setting.

You can optionally pass the B<replaced => 1> parameter to change pseudo tags in 
html and email messages to their value.

=cut




=pod 

=head2 save

 $ls->save({settingkey => 'settingvalue'});

saves a setting. Notice that this method takes a hashref, and nothing else.

=cut




sub save { 
 	my ($self, $new_settings) = @_;

	unless($self->{new_list}){  
		if(exists($new_settings->{list})){ 
			#  DEV: Another peculiarity: 
			#  THis screws up list restoration. Probably should have a flag that says, 
			# "I'm restoring" or something, to by pass this...
			unless($self->{im_restoring} == 1){
				croak "don't pass list to save()!";
			}
		}
	}
	
	if($new_settings){  		
 	
	
 		$self->_existence_check($new_settings);

 		$self->_open_db; 
		# I'm worried %TMP_RAW_HASH is tied - we're making a copy, of the HASH, 
		# not just a reference.... right? 
		# 
		my %TMP_RAW_HASH     = %{$self->{DB_HASH}};
		my %merge_info = (); 
		if(keys %TMP_RAW_HASH) { 
			
			# Special case - DB_HASH has not been decoded, yet: 
			# decode
			while ( my ($key, $value) = each %TMP_RAW_HASH ) {
				if(defined($value)){ 
					$TMP_RAW_HASH{$key} = safely_decode($value);
				}
			}
		
			%merge_info      = (%TMP_RAW_HASH, %$new_settings); 	
		}
		else { 
			%merge_info = %$new_settings; 
		}			
		
		if($merge_info{list}){ 		
			#special cases:
			
			if(! defined($merge_info{admin_menu}) || $merge_info{admin_menu} eq ""){ 

			    require DADA::Template::Widgets::Admin_Menu; 
				$merge_info{admin_menu} = DADA::Template::Widgets::Admin_Menu::create_save_set();
			}
			
			
			if(! defined($merge_info{cipher_key}) || $merge_info{cipher_key} eq ""){ 
			
				require DADA::Security::Password; 
				$merge_info{cipher_key} = DADA::Security::Password::make_cipher_key();
			}
			
			
			#/special cases:
		}else{ 
			carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! listshortname isn't defined! list " . $self->{function} . " db possibly corrupted!"
				unless $self->{new_list}; 
		}
		
		# now, we have to re-encode it: 
		# See how we're taking the value of %merge info and copying it to the 
		# corresponding key of, DB_HASH? 

		while ( my ($key, $value) = each %merge_info ) {
			$self->{DB_HASH}->{$key} = safely_encode($value);
		}
		
		# And then, we close. That's it? 
		
		$self->_close_db; 
		
		$self->{cached_settings} = undef; 
		
		$self->backupToDir;
		
		require DADA::App::ScreenCache; 
		my $c = DADA::App::ScreenCache->new; 
	   	   $c->flush;
	   
		return 1; 
     }
     return 1;
}




sub perhapsCorrupted { 
	my $self = shift; 
	$self->_open_db;
	my %RAW_DB_HASH     = %{$self->{DB_HASH}};
	$self->_close_db; 
	$RAW_DB_HASH{list} ? return 1 : return 0; 
}







sub _raw_db_hash { 

	my $self = shift; 
	$self->_lock_db;	
	$self->_open_db; 
	my %RAW_DB_HASH = %{$self->{DB_HASH}};
	$self->{RAW_DB_HASH} = {%RAW_DB_HASH};
	
	# decode
	while ( my ($key, $value) = each %{$self->{RAW_DB_HASH}} ) {
		if(defined($value)){ 
			$self->{RAW_DB_HASH}->{$key} = safely_decode( $value);
		}
	}
	
	
	$self->_close_db;
	$self->_unlock_db; 	
}




sub _list_name_check { 

	my ($self, $n) = @_; 
		$n = $self->_trim($n);
	return 0 if !$n; 
	return 0 if $self->_list_exists($n) == 0;  
	$self->{name} = $n;
	return 1; 
}




sub _list_exists { 
	my ($self, $n)  = @_; 
	return DADA::App::Guts::check_if_list_exists(-List => $n);
}






1;



=pod

=head1 See Also

DADA::MailingList::Settings

=head1 COPYRIGHT

Copyright (c) 1999 - 2014 Justin Simoni 
http://justinsimoni.com 
All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut

