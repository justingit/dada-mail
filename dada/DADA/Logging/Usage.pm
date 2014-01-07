package DADA::Logging::Usage;

=pod

=head1 NAME 

DADA::Log 

=head1 DESCRIPTION


	my $log = new DADA::Logging::Usage;
	
	$log->mj_log($list, $action, $details); 
	$log->trace("something's happening"); 


=head1 SYNOPSIS

This simple module allows simple logging utilities to Dada Mail. It also allows you 
to 'trace' whatever you want really in Dada Mail, This is best for bug fixing and usually 
isn't good for general use.

=cut 


use lib qw(../../ ../../../ ../../perllib);
use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 
use Fcntl qw(LOCK_SH);


sub new {

	my $class = shift;
	# my ($args) = @_;
	my $self = {};			
	bless $self, $class;
		$self->open_log;
	#$self->_init($args); 
	return $self;
	
}




sub echo_to { 
	my $self = shift; 
	my $echo_file = shift; 
}




sub mj_log {
 
	my $self           = shift; 
	my $list           = shift || 'undefined'; 
	my $action         = shift || 'undefined'; 
	my $details        = shift || ""; # this isn't mandatory i guess 
	my $time           = scalar(localtime());
	my $remote_address = $ENV{'REMOTE_ADDR'} || "";
	
    # HACK: This is the default path, and it leads to much confusion. 
	return if $DADA::Config::PROGRAM_USAGE_LOG eq '/home/youraccount/dada_files/dada_usage.txt';
	
	if($DADA::Config::PROGRAM_USAGE_LOG){
		unless($self->_log_is_open){ 
			$self->open_log ;
		}
		print LOG "[$time]\t$list\t$remote_address\t$action\t$details\n";
	}	
}


sub trace { 

	my $self  = shift; 
	my $trace = shift; 
	my $time = scalar(localtime());
	if($DADA::Config::PROGRAM_USAGE_LOG){
		$self->open_log unless $self->_log_is_open;
		print LOG "[$time]\t[trace]\t$trace\n";
	}
}		


sub open_log { 
	 # HACK: This is the default path, and it leads to much confusion. 
	return if $DADA::Config::PROGRAM_USAGE_LOG eq '/home/youraccount/dada_files/dada_usage.txt';
		
	if($DADA::Config::PROGRAM_USAGE_LOG){
		my $usage_log = $DADA::Config::PROGRAM_USAGE_LOG; 
		$usage_log = DADA::App::Guts::make_safer($usage_log); 
		
		
		chmod($DADA::Config::FILE_CHMOD , $usage_log); 
		if(open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $usage_log)){ 
			flock(LOG, LOCK_SH);
		}else{ 
			 warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER - i can't open my own log at '$DADA::Config::PROGRAM_USAGE_LOG', here's some details: $!";
		}
	}
	
}




sub close_log { 

	my $self = shift; 
	if($DADA::Config::PROGRAM_USAGE_LOG){
		close LOG if $self->_log_is_open;	
	}

}


sub _log_is_open { 
	my $self = shift; 
	return (defined fileno *LOG) ? 1 : 0; 
}




sub DESTROY{ 
	my $self = shift; 
	if($DADA::Config::PROGRAM_USAGE_LOG){
		$self->close_log;
	}
	
}

1;


=pod

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



# if (defined fileno *FH) { it's open }

