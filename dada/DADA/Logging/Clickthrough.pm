package DADA::Logging::Clickthrough; 
use strict; 

use lib qw(../../ ../../perllib);

use base qw(DADA::Logging::Clickthrough::Db);


use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts;

use Fcntl qw(LOCK_SH);
use Carp qw(croak carp); 


sub _init { 
	
	my $self   = shift; 
	my ($args) = @_; 

    if($self->{-new_list} != 1){ 
    	croak('BAD List name "' . $args->{-list} . '" ' . $!) if $self->_list_name_check($args->{-list}) == 0; 
	}else{ 
		$self->{name} = $args->{-list}; 
	}	
	
    
	if(! defined($self->{-li}) ){ 
	    
	    require DADA::MailingList::Settings; 
        my $ls = DADA::MailingList::Settings->new({-list => $self->{name}}); 
	    $self->{-li} = $ls->get; 
	}
	
	$self->{is_redirect_on}                  = $self->redirect_config_test; 	# kinda hardcore, you know? 
	$self->{is_log_openings_on}              = $self->{-li}->{enable_open_msg_logging}; 
	$self->{is_log_bounces_on}               = $self->{-li}->{enable_bounce_logging};
	$self->{enable_subscriber_count_logging} = $self->{-li}->{enable_subscriber_count_logging},
	
	
	return $self;

}

sub redirect_config_test { 
	my $self = shift; 	
	
	return 0 if (!$self->{name}) || ($self->{name} eq ""); 
	return 0 unless DADA::App::Guts::check_if_list_exists(-List => $self->{name}) >= 1;
	return 0 if $self->{-li}->{clickthrough_tracking} != 1;
	return 1;
}




sub r_log { 
	my ($self, $mid, $url) = @_;
	if($self->{is_redirect_on} == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, ">>" . $self->clickthrough_log_location) 
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG scalar(localtime()) . "\t" . $mid . "\t" . $url . "\n"  or warn "Couldn't write to file: " . $self->clickthrough_log_location . 'because: ' .  $!; 
		close (LOG)  or warn "Couldn't close file: " . $self->clickthrough_log_location . 'because: ' .  $!;
		return 1; 
	}else{ 
		return 0;
	}
}




sub o_log { 
	my ($self, $mid) = @_;
	if($self->{is_log_openings_on} == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, ">>" . $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG scalar(localtime()) . "\t" . $mid . "\t" . 'open' . "\n";
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}




sub sc_log { 
	my ($self, $mid, $sc) = @_;
	if($self->{enable_subscriber_count_logging} == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, ">>" . $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG scalar(localtime()) . "\t" . $mid . "\t" . 'num_subscribers' . "\t" . $sc . "\n";
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}




sub bounce_log { 
	my ($self, $mid, $email) = @_;
	if($self->{is_log_bounces_on} == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, ">>" . $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG scalar(localtime()) . "\t" . $mid . "\t" . 'bounce' . "\t" . $email . "\n";
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}




sub report_by_message_index { 
	my $self   = shift; 
	my $report = {}; 
	my $l;
	
	# DEV: I would sor to of like to make some validation that the info
	# we're using to count is actually correct - like if it's a message_id - it's all numerical, etc
	# I'd also like to make some sort of pagination scheme, so that we only have a few message_id's 
	# we're interested in. That shouldn't be too difficult. 
	
	if(-e $self->clickthrough_log_location){ 
		open(LOG, $self->clickthrough_log_location)
			or die "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		while(defined($l = <LOG>)){ 
			chomp($l); 
			my ($t, $mid, $url, $extra) = split("\t", $l); 
				
				$t     = strip($t); 
				$mid   = strip($mid); 
				$url   = strip($url); 
				$extra = strip($extra); 
				
			if($url ne 'open' && $url ne 'num_subscribers' && $url ne 'bounce' && $url ne undef){
				
				$report->{$mid}->{count}++;		
			
			}elsif($url eq 'open'){ 	
			
				$report->{$mid}->{'open'}++;
		
			}elsif($url eq 'bounce'){ 	
			
				$report->{$mid}->{'bounce'}++;
								
			}elsif($url eq 'num_subscribers'){ 
			
				$report->{$mid}->{'num_subscribers'} = $extra;	
			
			}
		}
		close(LOG);		
		
		require DADA::MailingList::Archives; 
		my $mja = DADA::MailingList::Archives->new({-list => $self->{name}}); 
		
		foreach(sort keys %$report){ 
		
		    if($mja->check_if_entry_exists($_)){ 
		    
			$report->{$_}->{message_subject} = $mja->get_archive_subject($_) || $_;
			
			} else { 
			
			  # $report->{$_}->{message_subject} = $_; 
			   
			}
		}
		return $report;
	} 	
}



sub report_by_message {
	 
	my $self      = shift; 
	my $match_mid = shift; 
	
	my $report = {}; 
	my $l;
	open(LOG, $self->clickthrough_log_location)
		or die "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
	while(defined($l = <LOG>)){ 
		chomp($l); 
		
		my ($t, $mid, $url, $extra) = split("\t", $l); 
			
		$t     = strip($t); 
		$mid   = strip($mid); 
		$url   = strip($url); 
		$extra = strip($extra); 
					
		if($match_mid eq $mid){ 
		
			if($url ne 'open' && $url ne 'num_subscribers' && $url ne 'bounce' && $url ne undef){
				$report->{$url}->{count}++;		
			}elsif($url eq 'open'){ 	
			
				$report->{'open'}++;
				
			}elsif($url eq 'num_subscribers'){ 
			
				$report->{'num_subscribers'} = $extra;	
				
			}elsif($url eq 'bounce'){ 	
			
				push(@{$report->{'bounce'}}, $extra);
			}	
		}		
	}
	close(LOG); 
	return $report; 
}




sub report_by_url { 
	my $self      = shift; 
	my $match_mid = shift; 
	my $match_url = shift;
	
	my $report = []; 
	my $l;
	
	open(LOG, $self->clickthrough_log_location)
	 or die "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
	while(defined($l = <LOG>)){ 
		chomp($l); 
		my ($t, $mid, $url) = split("\t", $l); 
		if($url ne 'open' && $url ne 'num_subscribers'){
			if(($match_mid == $mid) && ($match_url eq $url)){ 
				push(@$report, $t);
			}
		}
	}
	close(LOG); 
	return $report; 
}


sub print_raw_logs { 

	my $self = shift; 
	my $l; 
	
	unless(-e $self->clickthrough_log_location){ 
		print '';
		return; 
	}
	
	open(LOG, $self->clickthrough_log_location)
		or die "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
	while(defined($l = <LOG>)){ 
		chomp($l); 
		print $l . "\n";
	}

}




sub clickthrough_log_location { 

	my $self = shift; 
	my $ctl  =  $DADA::Config::LOGS  . '/' . $self->{name} . '-clickthrough.log';
	   $ctl  = DADA::App::Guts::make_safer($ctl);
	   $ctl =~ /(.*)/;
	   $ctl = $1; 
	   return $ctl; 
}

1;


=pod

=head1 COPYRIGHT

Copyright (c) 1999-2008 Justin Simoni
 
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

