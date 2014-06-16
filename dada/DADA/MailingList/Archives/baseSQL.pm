package DADA::MailingList::Archives::baseSQL; 

use lib qw(../../../ ../../../DADA/perllib); 

use strict; 
use DADA::Config qw(!:DEFAULT);  
use DADA::MailingList::Settings; 
use DADA::App::Guts;

use Carp qw(carp croak); 

my $database         = $DADA::Config::SQL_PARAMS{database};
my $dbserver         = $DADA::Config::SQL_PARAMS{dbserver};    	  
my $port             = $DADA::Config::SQL_PARAMS{port};     	  
my $user             = $DADA::Config::SQL_PARAMS{user};         
my $pass             = $DADA::Config::SQL_PARAMS{pass};
my $dbtype           = $DADA::Config::SQL_PARAMS{dbtype};

use DBI;
use Fcntl qw(O_WRONLY 
             O_TRUNC 
             O_CREAT 
             O_CREAT 
             O_RDWR
             O_RDONLY
             LOCK_EX
             LOCK_SH 
             LOCK_NB
            ); 

my $dbi_obj = undef; 


my %fields; 


sub new {

	my $class = shift;

	
	my $self = {};		   		
	bless $self, $class;


	my ($args) = @_; 
	
	if(!exists($args->{-list})){ 
		croak "You MUST pass a list in -list!";
	}
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$self->{ls} = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else {
		$self->{ls} = $args->{-ls_obj};
	}

	$self->{name} = $args->{-list};
	$self->{list} = $args->{-list};	
		
	$self->_init($args);  

		
	return $self; 
}

sub _init  { 

    my $self   = shift; 
    my ($args) = @_; 
  
	$self->{ignore_open_db_error} = 0;
	if(exists($args->{-ignore_open_db_error})){ 
		
		$self->{ignore_open_db_error} = $args->{-ignore_open_db_error};
	}
  	
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
    $self->{msg_cache} = {};
       
   if(!$dbi_obj){ 
		require DADA::App::DBIHandle; 
		$dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}else{ 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}
	
	
	if(exists($args->{-parser})){ 
		$self->{parser} = $args->{-parser};
	}
}




sub can_display_attachments { 
	
	my $self = shift; 
	return 1; 

}

sub can_display_message_source { 
	
	my $self = shift; 
	return 1; 

}


sub num_archives {

    my $self   = shift;
    my ($args) = @_; 
	
    my @row;
    my $query = 'SELECT COUNT(*)  FROM ' .  $self->{sql_params}->{archives_table} . ' WHERE list = ?';

	my $sth = $self->{dbh}->prepare('SELECT * FROM ' . $self->{sql_params}->{archives_table});
    my $count = $self->{dbh}->selectrow_array($query, undef,  $self->{list}); 
	return $count;

}




sub print_message_source { 

	my $self = shift; 
	my $fh   = shift; 
	my $id   = shift; 
	
	croak "no id!" if ! $id; 
	croak "no fh!" if ! $fh; 
	
	croak "archive backend does not support viewing message source!" 
	 	unless can_display_message_source; 
	 	
	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($id); 
	
	require Encode; 
	if(length($raw_msg) > 0){ 
		print $fh safely_encode( $raw_msg );
	}
	else { 
		print $fh "No raw source available."; 
	}
}

=pod


=head2 get_archive_entries

	my $entries = $archive -> get_archive_entries(); 

this will give you a refernce to an array that has the keys to your entries there. 

=cut 



sub get_archive_entries { 
	
	my $self  = shift;
	my $order = shift || 'normal';
	my @keys; 
	my $in_reverse = $self->{ls}->param('sort_archives_in_reverse') || 0; #yeah, like what?
		
	my $query  = 'SELECT archive_id FROM '. $self->{sql_params}->{archives_table} . 
	             ' WHERE list = ? ORDER BY archive_id ASC';
		
	my $sth = $self->{dbh}->prepare($query); 
	   $sth->execute($self->{name});
	
	while((my $archives_id) = $sth->fetchrow_array){
		push(@keys, $archives_id); 
	}
	
    $sth->finish;
    
    if($order eq 'reverse' || $in_reverse == 1){ 
		@keys = reverse @keys;
	}	
	return \@keys;
}



sub get_archive_info { 

	my $self  = shift; 
	my $key   = shift; 
	   $key   = $self->_massaged_key($key); 
	my $cache = shift || 0; 
	
	if($self->{msg_cache}->{$key}){ 
		# warn "i'm cached!"; 
		return ($self->{msg_cache}->{$key}->[0], $self->{msg_cache}->{$key}->[1], $self->{msg_cache}->{$key}->[2], $self->{msg_cache}->{$key}->[3]); 
		
	}else{ 
	
		my $query = 'SELECT * FROM ' . 
					 $self->{sql_params}->{archives_table} . 
					 ' WHERE archive_id = ? AND list = ?';
	
		my $sth = $self->{dbh}->prepare($query); 
		   $sth->execute($key, $self->{name});
		my $a_entry = $sth->fetchrow_hashref(); 
		   $sth->finish;  
		   
		   
		if($cache){ 
		
		    # warn "I'm caching!"; 
			$self->{msg_cache}->{$key} = [$a_entry->{subject}, $a_entry->{message},$a_entry->{'format'}, $a_entry->{raw_msg}]; 
		}
		
		$a_entry->{subject} = $self->_decode_header($a_entry->{subject}); 
		# $a_entry->{subject} = safely_decode($a_entry->{subject}); 
		
		$a_entry->{subject} = $self->strip_subjects_appended_list_name($a_entry->{subject})
			if $self->{ls}->param('no_prefix_list_name_to_subject_in_archives') == 1; 

        if(! strip($a_entry->{subject})){ 
		    $a_entry->{subject} = $DADA::Config::EMAIL_HEADERS{Subject}; 
		}
		
		return ($a_entry->{subject}, $a_entry->{message},$a_entry->{'format'}, $a_entry->{raw_msg}); 

	}
}





=pod

=head2 set_archive_info

	$archive -> set_archive_info($subject, $message, $format, $raw_msg);

changes the archive's info (yo) 


=cut





sub set_archive_info { 

	my $self = shift; 
	
	my $key = shift; 
	   $key = $self->_massaged_key($key); 
	
	if($key){ 
		
		my $ping = 1; 
		
		if($self->check_if_entry_exists($key)){ 
			$self->delete_archive($key); 
			$ping = 0; 
		}
		
		my $new_subject = shift; 
		my $new_message = shift;
		my $new_format  = shift;
		my $raw_msg     = shift; 
		
		
		if((!$raw_msg) && ($new_message)){ 
		    # This is some seriously silly hackery: 
		    $raw_msg =  'Content-type: '; 
			if($new_format =~ m/html/i){ 
				$raw_msg .= 'text/html'; 
			}
			else { 
				 $raw_msg .= 'text/plain'; 
			}
		    $raw_msg .= "\n"; 
		    $raw_msg .= 'Subject: ' . $new_subject; 
		    $raw_msg .= "\n"; 
		    $raw_msg .= "\n"; 
		    $raw_msg .= $new_message; 
		}
		elsif((!$new_message) && ($raw_msg)){ 
			($new_message, $new_format) = $self->_faked_oldstyle_message($raw_msg);
		}
		
		# remove opener image! 
		if($new_format !~ /plain/){ 
			$new_message = $self->_remove_opener_image($new_message);
			$raw_msg     = $self->_remove_opener_image($raw_msg);
		}
		
		my $query = 'INSERT INTO '. $self->{sql_params}->{archives_table} .' VALUES (?,?,?,?,?,?)';
		
		my $sth   = $self->{dbh}->prepare($query); 
		   $sth->execute($self->{name}, $key, $new_subject, $new_message, $new_format, $raw_msg); #shouldn't key and list be reversed in the table?
		   $sth->finish;
		require DADA::App::ScreenCache; 
		my $c = DADA::App::ScreenCache->new; 
	       $c->flush;
	
		$self->send_pings()
			if $ping == 1; 
	
		return 1; 
	
	}else{ 
	
		carp "no key passed!"; 
		return undef; 		
	
	}
	
}




=pod

=head2 search_entries

 my $search_results = $archive->search_entries($keyword); 

Given a $keyword, will return a array ref of archive key/ids that contain the 
keyword. 

=cut

sub search_entries { 

	my $self    = shift; 
	my $keyword = shift; 
	my @results; 

	my $query  = 'SELECT archive_id FROM '. $self->{sql_params}->{archives_table} . 
			     ' WHERE list = ? AND (raw_msg LIKE ? OR message LIKE ? OR subject LIKE ?) ORDER BY archive_id DESC';

	my $sth = $self->{dbh}->prepare($query); 
	   $sth->execute($self->{name}, '%'.$keyword.'%', '%'.$keyword.'%', '%'.$keyword.'%')
			or croak "cannot do statement! $DBI::errstr";
	while((my $archives_id) = $sth->fetchrow_array){		
		push(@results, $archives_id); 
	}
	$sth->finish;
	
	return \@results;
}



=pod

=head2 delete_archive

	delete_archive($key);

deletes the archive entry. 

=cut


sub delete_archive { 

	my $self      = shift;
	my @deep_six  = @_;
	my @good_list = (); 
	
	carp "no key passed to remove entries!"
		if !$deep_six[0];
	
	for(@deep_six){ 
		$_ = $self->_massaged_key($_);  
		if($self->check_if_entry_exists($_)){ 
			push(@good_list, $_);
		}else{ 
			carp "error removing entry, '$_' doesn't exist?";  
		}
	}
	
	for(@good_list){ 
	
		my $key = $_; 	
		my $query =  'DELETE FROM ' . $self->{sql_params}->{archives_table} . ' WHERE archive_id = ? AND list = ?';
		
		my $sth = $self->{dbh}->prepare($query); 
		
		$sth->execute($key, $self->{name}); 
		$sth->finish;
    
    }
	
	require DADA::App::ScreenCache; 
	my $c = DADA::App::ScreenCache->new; 
	   $c->flush;
	   
    
}




sub delete_all_archive_entries {
    
	my $self  = shift; 
	my $query =  'DELETE FROM ' . $self->{sql_params}->{archives_table} . ' WHERE list = ?';
	
	my $sth   = $self->{dbh}->prepare($query); 
    
    $sth->execute($self->{name}) 
        or croak "cannot do statement! $DBI::errstr\n";   
    $sth->finish;

	require DADA::App::ScreenCache; 
	my $c = DADA::App::ScreenCache->new; 
       $c->flush;

	return 1;	

}



sub removeAllBackups {
	# no backups are created, 
	# so no backups to remove - all right!
}




sub make_table { 

	my $self = shift; 
	
	my $query = 'CREATE TABLE dada_archives (list varchar(32), archive_id varchar(32), subject text, message text, format text, raw_msg text);';
	my $sth   = $self->{dbh}->prepare($query); 
	   $sth->execute()
	   		or croak "cannot do statement! $DBI::errstr\n";   
	   $sth->finish;
}




sub uses_backupDirs { 
	my $self = shift; 
	return 0; 
}




sub DESTROY { 
	my $self = shift; 
	
   $self->{parser}->filer->purge
	if $self->{parser};


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


