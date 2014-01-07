package DADA::MailingList::Archives::Db; 

use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 

use Encode; 

use base DADA::App::GenericDBFile;

=pod

=head1 NAME

DADA::MailingList::Archives


=head1 SYNOPSIS

use DADA::MailingList::Archives;

	my $archive = DADA::MailingList::Archives->new({-list => 'mylist'}); 

=head1 DESCRIPTION

Archive interface to a simple tied hash archiving system for messages saved in Dada Mail 

=cut

#This Module is used for archives of Dada Mail, if you
# didn't get the jist from the name there buddy.



use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 

use strict; 
use vars qw($AUTOLOAD); 
use Carp qw(carp croak); 
use Fcntl;
use AnyDBM_File; 

my $opened_archive; 
my $dbi_obj; 


=pod

=head1 SUBROUTINES 

=head2 new

	my $archive = DADA::MailingList::Archives->new({-list => 'mylist'}); 

this wil tie the db hash and get you going with this whole gosh darn thing
if it has a valid list, it will open up the archive and get to work on it.
  
=cut



sub new { 

	# the "new" function, wee
	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = SUPER::new $class (
								  function => 'archives',
								 );  
									 
	my ($args) = @_; 
	
	if(!exists($args->{-list})){
		croak "You MUST pass a list in, -list!"; 
	}
	
	 	
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$self->{ls} = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else {
		$self->{ls} = $args->{-ls_obj};
	}
	unless($self->{ls}->isa('DADA::MailingList::Settings')){ 
		croak 'DADA::MailingList::Settings object is not!';
	}
	
	$self->{name}                 = $args->{-list};	
	$self->{list}                 = $args->{-list};	
	
	
	$self->{ignore_open_db_error} = $args->{-ignore_open_db_error}; 

	$self->init();
	
	return $self; 

}

sub init { 
	my $self = shift; 
	$self->_open_db; 
}

sub can_display_attachments { 
	
	my $self = shift; 
	return 0; 

}

sub can_display_message_source { 
	
	my $self = shift; 
	return 0; 

}



sub num_archives {

    my $self   = shift;
    my ($args) = @_; 
	return scalar( keys %{$self->{DB_HASH}});
	

}



sub print_message_source { 

	my $self = shift; 
	
	croak "archive backend does not support viewing message source!" 
	 	unless can_display_message_source; 
}




sub get { 
	my $self = shift;
	return $self->{DB_HASH}; 
}




# No idea where this is used. Is it used?
sub save { 
	
	my $self     = shift; 
	my $new_vals = shift || {}; 
	

	$self->_close_db;
	
	# encode
	while ( my ($key, $value) = each %$new_vals ) {
		$new_vals->{$key} = safely_encode($value);
	}
	
	# hack. fix later. 
	my %tmp; 
	chmod($DADA::Config::FILE_CHMOD , $self->_db_filename)
		if -e $self->_db_filename; 
	tie %tmp, "AnyDBM_File", $self->_db_filename,  O_RDWR|O_CREAT, $DADA::Config::FILE_CHMOD   
	or croak 'couldn\'t tie '. $self->_db_filename . ' for reading: ' . $! .  '; If your server recently upgraded software or moved your lists to a different server, you may need to restore your list ' . $self->{function} . '. Visit ' . 
			$DADA::Config::PROGRAM_URL . '?f=restore_lists '; 
	%tmp = %$new_vals; 
	untie %tmp; 
	$self->_open_db;
}

=pod


=head2 get_archive_entries 

	my $entries = $archive -> get_archive_entries(); 

this will give you a reference to an array that has the keys to your entries there. 

=cut 



sub get_archive_entries { 
	
	my $self  = shift;
	my $order = shift || 'normal';

	my $h = $self->get; 
	
	my @keys = keys %{$self->{DB_HASH}};
	   @keys = sort { $a <=> $b  } @keys;
	
	my $in_reverse = $self->{ls}->param('sort_archives_in_reverse') || 0;
	
	if($order eq 'reverse' || $in_reverse == 1){ 
		@keys = reverse @keys;
	}	
	return \@keys;

}



=pod

=head2 get_archive_message

	my $message = get_archive_message($key);

gets the message of the given $key

=head2 get_archive_subject

	my $subject = get_archive_subject($key);

gets the subject of the given $key

=cut











=pod

=head2 get_archive_subject($key); 

my $subject, $message, $format = $archive -> get_archive_subject($key); 


gets the subject of the given $key

=cut


sub get_archive_info{ 

	my $self = shift; 
	my $key = shift; 
	   $key = $self->_massaged_key($key); 
	   	   
	my (
		$subject, 
		$message, 
		$format
	) = split(
			/\[::\]/, safely_decode($self->{DB_HASH}->{$key})
	); 
	$message = $self->massage($message);
	$subject = $self->strip_subjects_appended_list_name($subject)
		if $self->{ls}->param('no_prefix_list_name_to_subject_in_archives') == 1; 

    
    if(! strip($subject)){ 
        $subject = $DADA::Config::EMAIL_HEADERS{Subject}; 
    }
	
	# really, would they even be encoded, here? 
	$subject = $self->_decode_header($subject); 
		
	return ($subject, $message, $format, ''); 
}







sub set_archive_info { 
	my $self = shift; 
	
	my $key = shift; 
	   $key = $self->_massaged_key($key); 
	   
	if($key){ 
		my $new_subject = shift; 	
		my $new_message = shift;
		my $new_format  = shift;
		my $raw_msg     = shift;		

		my $ping = ($self->check_if_entry_exists($key)) ? 0 : 1;
		
		
		if((!$new_message) && ($raw_msg)){ 			
				($new_message, $new_format) = $self->_faked_oldstyle_message($raw_msg);
		}
		
		if($new_format !~ /plain/){ 
			$new_message = $self->_remove_opener_image($new_message);
		}
		
		$new_subject = safely_encode($new_subject); 
		$new_message = safely_encode($new_message);
		$new_format  = safely_encode($new_format);
		
		#print "Saving Archive....\n"; 
		$self->{DB_HASH}->{$key} = 
			join("\[::\]", 
			$new_subject, 
			$new_message,
			$new_format,			
		); 
			#print "Saved!\n"; 
		
	#	print "It says: \n" . 	$self->{DB_HASH}->{$key} . "\n";
			
		#print "backing up:\n"; 
		$self->backupToDir;
		#print "backup done!\n"; 
		
		require DADA::App::ScreenCache; 
		my $c = DADA::App::ScreenCache->new; 
	       $c->flush;
		
		$self->send_pings()
			if $ping == 1; 
		#$self->save; #?!?!
		return 1; 
	}else{ 
		#print "Gah! That did not work! Doh!"; 
		carp "no key passed!"; 
		return undef; 
	}	
}

=pod

=head2 delete_archive

	delete_archive($key);

deletes the archive entry. 

=cut

# not used?!


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
			carp "error removing entry, '$_' - doesn't exist?";  
		}
	}
	
	for(@good_list){
		# Deleting from a "tie"d hash or array may not necessarily return
        # anything.
		#undef($self->{DB_HASH}->{$_}); 
		delete($self->{DB_HASH}->{$_}); 
	}
	
	# Flushing - shouldn't be needed?
	$self->_close_db; 
	$self->_open_db; 
	
	$self->backupToDir;

	require DADA::App::ScreenCache; 
	my $c = DADA::App::ScreenCache->new; 
	   $c->flush;
	       
}

sub oldest_entry { 
	my $self = shift; 
	my $entries = $self->get_archive_entries(); 
	@$entries = sort { $a <=> $b  } @$entries;
	return $entries->[0];
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
	
	my $entries = $self->get_archive_entries(); 
		for(@$entries){ 
			my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($_);
			
			$message = $raw_msg if ! $message; 
			
			if($subject =~ m/$keyword/i || $message =~ m/$keyword/i){ 
				push(@results, $_); 
			}
		}
	return \@results;
}



=pod

=head2 DESTROY

	DESTROY ALL ASTROMEN!\

=cut

sub delete_all_archive_entries {

	my $self = shift; 
	
	my $list = $self->{name};
	
	$self->_close_db;
	
	my $deep_six;
		
	opendir(ARCHIVES, $DADA::Config::ARCHIVES )  
		or croak "can't open ' $DADA::Config::ARCHIVES ' for reading, $!"; 
		
		while(defined($deep_six = readdir ARCHIVES)) {
		
					$deep_six =~ s(^.*/)();
			next if $deep_six =~ /^\.\.?$/; 
					
					
		if(($deep_six =~ m/mj\-$list\-archive\.(.*)/) || ($deep_six =~ m/(mj\-$list\-archive)$/))  { 
			 $deep_six = make_safer($DADA::Config::ARCHIVES  . '/' . $deep_six); 
			 $deep_six =~ /(.*)/; 
			 $deep_six = $1; 
			 unlink($deep_six) 
			 	or carp "could not remove, '$deep_six' - $!"; 
		}		 
	}
	closedir(ARCHIVES);	
	
}



sub DESTROY {

	my $self = shift;  
	   $self->_close_db;
	
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


