package DADA::MailingList::Settings::baseSQL; 

use strict; 

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts;  # For now, my dear. 

my $t = 0; 


my $dbi_obj = undef; 

use Carp qw(croak carp); 


sub new {
	
	my $class = shift;
	
	my ($args) = @_; 
	
	my $self = {};			
	bless $self, $class;

	if(!exists($args->{-list})){ 
		croak "You MUST pass a list in, -list!"; 
	}
	
	if(!exists($args->{-new_list})){ 
		$args->{-new_list} = 0;
	}
	
	$self->{new_list} = $args->{-new_list};
	$self->_init($args); 
	$self->_sql_init(); 
	

	return $self;
}




sub _sql_init  { 
	
    my $self = shift; 
    
    $self->{function} = 'settings sql'; # seriously, wha?
    
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

	if(!keys %{$self->{sql_params}}){ 
		croak "sql params not filled out?!"; 
	}
	else {
		
	}


#	if(!$dbi_obj){ 
		#warn "We don't have the dbi_obj"; 
		require DADA::App::DBIHandle; 
		$dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
#	}else{ 
#		#warn "We HAVE the dbi_obj!"; 
#		$self->{dbh} = $dbi_obj->dbh_obj; #
#	}
	
}




sub save { 
 	my ($self, $new_settings) = @_;

    if($t == 1){ 
        require Data::Dumper; 
        warn '$new_settings: ' . Data::Dumper::Dumper($new_settings); 
    }
	unless($self->{new_list}){  
		if(exists($new_settings->{list})){ 
			croak "don't pass list to save()!";
		}
	}


	my $d_query = 'DELETE FROM ' . $self->{sql_params}->{settings_table} .' where list = ? and setting = ?'; 
	my $a_query = 'INSERT INTO ' . $self->{sql_params}->{settings_table} .' values(?,?,?)';
    
    warn '$d_query ' . $d_query if $t;; 
    warn '$a_query ' . $a_query if $t; 
    if(! $self->{RAW_DB_HASH}){
        $self->_raw_db_hash;
    }
    
	if($new_settings){  

 		$self->_existence_check($new_settings); 	    

  		for my $setting(keys %$new_settings){ 

 		    my $sth_d = $self->{dbh}->prepare($d_query); 
 			   $sth_d->execute($self->{name}, $setting)
 			   	or die "cannot do statement $DBI::errstr\n";   
				$sth_d->finish;
				
 			my $sth_a = $self->{dbh}->prepare($a_query);
 			   $sth_a->execute($self->{name}, $setting, $new_settings->{$setting})
 			   	or die "cannot do statement $DBI::errstr\n"; 
  			   $sth_a->finish;
 		}
		
		# This should give you a brand new copy of the hashref, 
		# So when we run the following tests...
		
		$self->{RAW_DB_HASH} = undef; 
		$self->_raw_db_hash;
		
		if($self->{RAW_DB_HASH}->{list} || $self->{new_list} == 1){ 		
			
			#special cases:
			
			if(! defined($self->{RAW_DB_HASH}->{admin_menu}) || $self->{RAW_DB_HASH}->{admin_menu} eq ""){ 

			    require DADA::Template::Widgets::Admin_Menu; 
				
				my $sth_am = $self->{dbh}->prepare($a_query);
				   $sth_am->execute($self->{name}, 'admin_menu', DADA::Template::Widgets::Admin_Menu::create_save_set())
 			   	   		or die "cannot do statement $DBI::errstr\n";   

			}
			
			if(! defined($self->{RAW_DB_HASH}->{cipher_key}) || $self->{RAW_DB_HASH}->{cipher_key} eq ""){ 

                require DADA::Security::Password; 
				
 			    my $new_cipher_key = DADA::Security::Password::make_cipher_key(); 
 				my $sth_ck = $self->{dbh}->prepare($a_query);
				   $sth_ck->execute($self->{name}, 'cipher_key', $new_cipher_key)
 			   	   		or die "cannot do statement $DBI::errstr\n";   
 			   	   		
 			}
			#/special cases:
		}else{ 
			carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! listshortname isn't defined! list " . $self->{function} . " db possibly corrupted!"
				unless $self->{new_list}; 
		}
		
		$self->{cached_settings} = undef; 
		
		require DADA::App::ScreenCache; 
		my $c = DADA::App::ScreenCache->new; 
	   	   $c->flush;
	   	
	   	$self->{RAW_DB_HASH} = undef; 
	   
		return 1; 
     }
     return 1;
}




sub perhapsCorrupted { 
	my $self = shift; 
	return 1; 
}







sub _raw_db_hash { 

	my $self     = shift; 
	my $settings = {};

	# This is sincerely stupid. 
	
	# um, caching? 
	return 
	    if $self->{RAW_DB_HASH}; 
	    
	
	# Need $self->{RAW_DB_HASH} as a hash ref of settings - easy enough...
	
	my $query = 'SELECT setting, value from ' . $self->{sql_params}->{settings_table} .' where list = ?';
	
	my $sth = $self->{dbh}->prepare($query); 
	   $sth->execute($self->{name})
            or croak "cannot do statement! (at: _raw_db_hash) $DBI::errstr\n";   

	
	while((my @stuff) = $sth->fetchrow_array){		
		$settings->{$stuff[0]} = $stuff[1]; 
	}
	
	$sth->finish; 

	$self->{RAW_DB_HASH} = $settings; 	
	

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
	if(!defined($dbi_obj)){ 
	#	croak "Why?"; 
	}
	return DADA::App::Guts::check_if_list_exists(
				-List       => $n, 
	);
}







sub removeAllBackups {}
sub uses_backupDirs {	return 0;	}




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

