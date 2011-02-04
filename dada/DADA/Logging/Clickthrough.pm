package DADA::Logging::Clickthrough; 


use lib qw(../../ ../../perllib);

BEGIN {
    $type = $DADA::Config::CLICKTHROUGH_DB_TYPE;
    if ( $type =~ m/sql/i ) {
        $type = 'baseSQL';
    }
    else {
        $type = 'Db';
    }
}

use base "DADA::Logging::Clickthrough::$type";

use strict; 
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
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location) 
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
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')' ,  $self->clickthrough_log_location)
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
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $self->clickthrough_log_location)
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
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $self->clickthrough_log_location)
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
		open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
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
		
		for(sort keys %$report){ 
		
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
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
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
	
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
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
	
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
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

##############################################################################

sub parse_email {

    my $self = shift;
    my ($args) = @_;

    # Actually, I think they want dada-style args. Damn them!
    #	if(!exists($args->{-entity})){
    #		croak "you MUST pass an -entity!";
    #	}
    if ( !exists( $args->{ -mid } ) ) {
        croak "you MUST pass an -mid!";
    }

    # Massaging:
    $args->{ -mid } =~ s/\<|\>//g;
    $args->{ -mid } =~ s/\.(.*)//;    #greedy

    # This here, is pretty weird:

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -yeah_no_list => 1 );

    my $entity = $fm->entity_from_dada_style_args($args);

    $entity = $self->parse_entity(
        {
            -entity => $entity,
            -mid    => $args->{ -mid },
        }
    );

    my $msg = $entity->as_string;
	   $msg = safely_decode($msg); 

    my ( $h, $b ) = split ( "\n\n", $msg, 2 );

    my %final = ( $self->return_headers($h), Body => $b, );

    return %final;

}

sub return_headers {

    my $self = shift;

    #get the blob
    my $header_blob = shift || "";

    #init a new %hash
    my %new_header;

    # split.. logically
    my @logical_lines = split /\n(?!\s)/, $header_blob;

    # make the hash
    for my $line (@logical_lines) {
        my ( $label, $value ) = split ( /:\s*/, $line, 2 );
        $new_header{$label} = $value;
    }
    return %new_header;

}

sub parse_entity {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -entity } ) ) {
        croak 'did not pass an entity in, "-entity"!';
    }
    if ( !exists( $args->{ -mid } ) ) {
        croak 'did not pass a mid in, "-mid"!';
    }

    my @parts = $args->{ -entity }->parts;

    if (@parts) {

        #print "we gotta parts?!\n";

        my $i;
        for $i ( 0 .. $#parts ) {
            $parts[$i] =
              $self->parse_entity( { %{$args}, -entity => $parts[$i] } );
        }

    }

    $args->{ -entity }->sync_headers(
        'Length'      => 'COMPUTE',
        'Nonstandard' => 'ERASE'
    );

    my $is_att = 0;

    if ( defined( $args->{ -entity }->head->mime_attr('content-disposition') ) )
    {
        if ( $args->{ -entity }->head->mime_attr('content-disposition') =~
            m/attachment/ )
        {
            $is_att = 1;

            #print "is attachment?\n";
        }
    }

    if (
        (
               ( $args->{ -entity }->head->mime_type eq 'text/plain' )
            || ( $args->{ -entity }->head->mime_type eq 'text/html' )
        )
        && ( $is_att != 1 )
      )
    {

        my $body    = $args->{ -entity }->bodyhandle;
        my $content = $args->{ -entity }->bodyhandle->as_string;
		   $content = safely_decode($content); 
		
        if ($content) {

            #print "Bang!\n";
            # Bang! We do the stuff here!
            $content = $self->parse_string( $args->{ -mid }, $content );
        }
        else {

            #print "no content to parse?!";
        }

        my $io = $body->open('w');
        require Encode; 
		$content = safely_encode($content);
		$io->print( $content );
        $io->close;
    }
    else {

        #print "missed the block?!\n";
    }

    $args->{ -entity }->sync_headers(
        'Length'      => 'COMPUTE',
        'Nonstandard' => 'ERASE'
    );

    return $args->{ -entity };

}

sub parse_string {

    my $self = shift;
    my $mid  = shift;

    die 'no mid! ' if !defined $mid;

    my $str = shift;

    #carp "here's the string before: " . $str;
    #
    $str =~ s/\[redirect\=(.*?)\]/&redirect_encode($self, $mid, $1)/eg;

    #	carp "here's the string: $str";
    return $str;
}

sub _list_name_check {

    my ( $self, $n ) = @_;
    $n = $self->_trim($n);
    return 0 if !$n;
    return 0 if $self->_list_exists($n) == 0;
    $self->{name} = $n;
    return 1;
}

sub _list_exists {
    my ( $self, $n ) = @_;
    return DADA::App::Guts::check_if_list_exists( -List => $n );
}

sub _trim { 
	my ($self, $s) = @_;
	return DADA::App::Guts::strip($s);
}

sub random_key {

    my $self = shift;
    require DADA::Security::Password;
    my $checksout = 0;
    my $key       = undef;

    while ( $checksout == 0 ) {
        $key = DADA::Security::Password::generate_rand_string( 1234567890, 12 );
        if ( $self->key_exists({ -key => $key }) ) {
            # ...
        }
        else {
            $checksout = 1;
            last;
        }
    }

    return $key;

}

sub redirect_encode {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! '
      if !defined $mid;
    my $url = shift;

    my $key = $self->reuse_key( $mid, $url );

    if ( !defined($key) ) {
        $key = $self->add( $mid, $url );
    }

#	carp 'here it is: ' . $DADA::Config::PROGRAM_URL . '/r/' . $self->{name} . '/' . $key . '/';
    return $DADA::Config::PROGRAM_URL . '/r/'
      . $self->{name} . '/'
      . $key . '/';

}



1;


=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2011 Justin Simoni All rights reserved. 

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

