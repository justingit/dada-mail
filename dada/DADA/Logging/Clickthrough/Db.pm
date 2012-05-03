package DADA::Logging::Clickthrough::Db;

use lib qw(../../../ ../../../DADA/perllib);

use base "DADA::App::GenericDBFile";

use strict;

use AnyDBM_File;
use Fcntl qw(
  O_WRONLY
  O_TRUNC
  O_CREAT
  O_RDWR
  O_RDONLY
  LOCK_EX
  LOCK_SH
  LOCK_NB);
use Carp qw(croak carp);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;    # For now, my dear.

sub new {

    my $class = shift;

    my ($args) = @_;

    my $self = SUPER::new $class ( function => 'clickthrough', );

    $self->{new_list} = $args->{ -new_list };
    $self->_init($args);

    return $self;
}

sub add {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url = shift;
    my $key = $self->random_key();

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    my $value = $self->encode_value( $mid, $url );

    if ($value) {
        $self->_open_db;
        $self->{DB_HASH}->{$key} = $value;
        $self->_close_db;
    }
    return $key;

}


sub encode_value {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url   = shift;
    my $value = undef;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    if ( $csv->combine( $mid, $url ) ) {
        $value = $csv->string;
    }
    else {

        croak "combine() failed on argument: ", $csv->error_input, "\n";

    }

    return $value;

}

sub decode_value {

    my $self  = shift;
    my $value = shift;

    die "no saved information! " if !defined $value;

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    if ( $csv->parse($value) ) {
        my @fields = $csv->fields;
        return ( $fields[0], $fields[1] );

    }
    else {
        croak $DADA::Config::PROGRAM_NAME
          . " Error: CSV parsing error: parse() failed on argument: "
          . $csv->error_input() . ' '
          . $csv->error_diag();
        return ( undef, undef );
    }
}


sub reuse_key {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url = shift;

    my $value = $self->encode_value( $mid, $url );

    $self->_open_db;

    while ( my ( $k, $v ) = each( %{ $self->{DB_HASH} } ) ) {
        if ( $v eq $value ) {
            $self->_close_db;
            return $k;
        }
    }

    $self->_close_db;
    return undef;

}

sub fetch {

    my $self = shift;
    my $key  = shift;
    die "no key! " if !defined $key;

    my $mid;
    my $url;
    my $saved_info;

    $self->_open_db;
    if ( exists( $self->{DB_HASH}->{$key} ) ) {
        $saved_info = $self->{DB_HASH}->{$key};
        $self->_close_db;
    }
    else {
        $self->_close_db;
        warn "No saved information for: $key";
        return ( undef, undef );

        # ...
    }

    my ( $r_mid, $r_url ) = $self->decode_value($saved_info);

    return ( $r_mid, $r_url, {} );
}


sub key_exists { 
		
	my $self = shift; 
	my ($args) = @_; 
	my $key = $args->{ -key }; 
	
	$self->_open_db;
    if(exists($self->{DB_HASH}->{$key})){ 
		$self->_close_db;
		return 1; 
	}
	else { 
		$self->_close_db;
		return 0; 
	}

}

sub _raw_db_hash {
    my $self = shift;
    $self->_lock_db;
    $self->_open_db;
    my %RAW_DB_HASH = %{ $self->{DB_HASH} };
    $self->{RAW_DB_HASH} = {%RAW_DB_HASH};
    $self->_close_db;
    $self->_unlock_db;
}



sub r_log { 
	
    my $self      = shift; 
    my ($args)    = @_;

	if($self->{ls}->param('clickthrough_tracking') == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location) 
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG scalar(localtime()) . "\t" . $args->{-mid} . "\t" . $args->{-url} . "\n"  or warn "Couldn't write to file: " . $self->clickthrough_log_location . 'because: ' .  $!; 
		close (LOG)  or warn "Couldn't close file: " . $self->clickthrough_log_location . 'because: ' .  $!;
		return 1; 
	}else{ 
		return 0;
	}
}




sub o_log { 

	my $self      = shift; 
    my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	else { 
		$timestamp = scalar(localtime()); 
	}
	
	if($self->{ls}->param('enable_open_msg_logging') == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')' ,  $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG $timestamp . "\t" . $args->{-mid} . "\t" . 'open' . "\n";
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}




sub sc_log { 
	my $self      = shift; 
    my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	else { 
		$timestamp = scalar(localtime()); 
	}
	
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		print LOG $timestamp . "\t" . $args->{-mid} . "\t" . 'num_subscribers' . "\t" . $args->{-num} . "\n";
		close (LOG);
}
sub logged_sc {
	return 1; 
}




sub forward_to_a_friend_log {
	
	
	my $self      = shift; 
	my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	else { 
		$timestamp = scalar(localtime()); 
	}
	
    if ( $self->{ls}->param('enable_view_archive_logging') == 1 ) {
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		
		print LOG $timestamp . "\t" . $args->{-mid} . "\t" . 'forward_to_a_friend'  . "\n";
	
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
	
}




sub view_archive_log { 
	
	my $self      = shift; 
	my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	else { 
		$timestamp = scalar(localtime()); 
	}
	
    if ( $self->{ls}->param('enable_view_archive_logging') == 1 ) {
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		
		print LOG $timestamp . "\t" . $args->{-mid} . "\t" . 'view_archive' . "\n";
	
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}




sub bounce_log { 

	my $self      = shift; 
	my ($args)    = @_;
	my $timestamp = undef; 
	if(exists($args->{-timestamp})){ 
		$timestamp = $args->{-timestamp};
	}
	else { 
		$timestamp = scalar(localtime()); 
	}
	
	if($self->{ls}->param('enable_bounce_logging') == 1){ 
	    chmod($DADA::Config::FILE_CHMOD , $self->clickthrough_log_location)
	    	if -e $self->clickthrough_log_location; 
		open(LOG, '>>:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $self->clickthrough_log_location)
			or warn "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
		flock(LOG, LOCK_SH);
		
		if($args->{-type} eq 'hard'){ 
			print LOG $timestamp . "\t" . $args->{-mid} . "\t" . 'hard_bounce' . "\t" . $args->{-email} . "\n";
		}
		else { 
			print LOG $timestamp . "\t" . $args->{-mid} . "\t" . 'soft_bounce' . "\t" . $args->{-email} . "\n";
		}
	
		close (LOG);
		return 1; 
	}else{ 
		return 0;
	}
}

sub get_all_mids { 

	my $self = shift; 
	my ($args) = @_;
	
	if(!exists($args->{-page})){ 
		$args->{-page} = 1; 
	}
	if(!exists($args->{-entries})){ 
		$args->{-entries} = 10; 
	}
	
	my $mids     = {};
	my @all_mids = ();
	my $l        = undef;
	if ( -e $self->clickthrough_log_location ) {
        open( LOG,
            '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',
            $self->clickthrough_log_location
          )
          or croak "Couldn't open file: '"
          . $self->clickthrough_log_location
          . '\'because: '
          . $!;
        while ( defined( $l = <LOG> ) ) {
            chomp($l);
    		
			my ( $t, $mid, $url, $extra ) = split( "\t", $l, 4 );

            $t     = strip($t);
            $mid   = strip($mid);
            $url   = strip($url);
            $extra = strip($extra);
			
			next if ! $mid;  
			next unless($self->verified_mid($mid)); 
			if($self->{ls}->param('tracker_clean_up_reports') == 1){
				next if $url ne 'num_subscribers';
			}
			$mids->{$mid} = 1;  
		}
	}
#	my @all_mids = sort { $a <=> $b } keys %$mids;
    # @s = sort {$b cmp $a} @a;


	my @all_mids = reverse sort keys %$mids;
	
	my $total = scalar @all_mids;
	
	if($total == 0){ 
		return ($total, []);
	}
		
	my $begin = ($args->{-entries} - 1) * ($args->{-page} - 1);
	my $end   = $begin + ($args->{-entries} - 1);
	if($end > $total - 1){ 
		$end = $total -1; 
	}
	
	
	
	#@all_mids = reverse @all_mids; 
	@all_mids = @all_mids[$begin..$end];
	#require Data::Dumper; 
	#die Data::Dumper::Dumper([@all_mids]); 
	
	
#	require Data::Dumper; 
#	die Data::Dumper::Dumper([@all_mids]);
	
	
	return ($total, [@all_mids]);
}


sub report_by_message_index {

	my $self          = shift;
	my ($args)        = @_; 

	my $sorted_report = [];
	my $report        = {};
	my $l;

	my $total   = undef; 
	my $msg_ids = []; 

	if(exists($args->{-all_mids})){ 
		$msg_ids = $args->{-all_mids};
	}
	else { 
		# Not using total, right now... 
		($total, $msg_ids) = $self->get_all_mids();
	}

	# These are the msg_ids we want reports for: 
	my %return_msg_ids_for = (); 
	foreach(@$msg_ids){ 
		$return_msg_ids_for{$_} = 1; 
	}
	# / lookup table

    if ( -e $self->clickthrough_log_location ) {
        open( LOG,
            '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',
            $self->clickthrough_log_location
          )
          or croak "Couldn't open file: '"
          . $self->clickthrough_log_location
          . '\'because: '
          . $!;
        while ( defined( $l = <LOG> ) ) {
            chomp($l);
    		
			my ( $t, $mid, $url, $extra ) = split( "\t", $l, 4 );

            $t     = strip($t);
            $mid   = strip($mid);
            $url   = strip($url);
            $extra = strip($extra);
			
			next 
				if ! $mid;  
			next 
				unless($self->verified_mid($mid)); 
			
			# Looking for it? 
			next 
				unless exists $return_msg_ids_for{$mid};

			
            if (   $url ne 'open'
                && $url ne 'num_subscribers'
                && $url ne 'bounce'
                && $url ne 'hard_bounce'
                && $url ne 'soft_bounce'
				&& $url ne 'forward_to_a_friend'
				&& $url ne 'view_archive'
                && $url ne undef )
            {
                $report->{$mid}->{count}++;
            }
            elsif ( $url eq 'open' ) {
                $report->{$mid}->{open}++;
            }
            elsif ( $url eq 'soft_bounce' ) {
                $report->{$mid}->{soft_bounce}++;
            }
            elsif ( $url eq 'hard_bounce' || $url eq 'bounce') {

                $report->{$mid}->{hard_bounce}++;

            }
            elsif ( $url eq 'num_subscribers' ) {				
                $report->{$mid}->{num_subscribers} = $extra;
            }
            elsif ( $url eq 'forward_to_a_friend' ) {				
                $report->{$mid}->{forward_to_a_friend}++;
            }
            elsif ( $url eq 'view_archive' ) {				
                $report->{$mid}->{view_archive}++;
            }
			else { 
				# warn "What? url:'$url', extra:$extra";
			}
        }
        close(LOG);

        require DADA::MailingList::Archives;
        my $mja =
          DADA::MailingList::Archives->new( { -list => $self->{name} } );

        # Now, sorted:
        for ( sort { $b <=> $a } keys %$report ) {
            $report->{$_}->{mid} = $_;
            $report->{$_}->{date} = DADA::App::Guts::date_this( -Packed_Date => $_, );
            $report->{$_}->{S_PROGRAM_URL} = $DADA::Config::S_PROGRAM_URL; 
            $report->{$_}->{list} = $self->{name}; 

              if ( $mja->check_if_entry_exists($_) ) {
                $report->{$_}->{message_subject} = $mja->get_archive_subject($_)
                  || $_;
            }
            else {
            }


            push( @$sorted_report, $report->{$_} );
        }

        return $sorted_report;
    }
}


sub report_by_message {
	 
	my $self      = shift; 
	my $match_mid = shift; 
	
	my $report = {}; 
	my $l;
	
	my $url_report = {};
	
	$report->{clickthroughs} = 0; 
	
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
		or croak "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
	while(defined($l = <LOG>)){ 
		chomp($l); 
		
		my ($t, $mid, $url, $extra) = split("\t", $l, 4); 
			
		$t     = strip($t); 
		$mid   = strip($mid); 
		$url   = strip($url); 
		$extra = strip($extra); 
		
		
		
		if($match_mid eq $mid){ 
		
			if($url ne 'open'                && 
			   $url ne 'num_subscribers'     && 
			   $url ne 'bounce'              && 
			   $url ne 'soft_bounce'         && 
			   $url ne 'hard_bounce'         && 
			   $url ne 'forward_to_a_friend' && 
			   $url ne 'view_archive'        &&
			   $url ne undef
			){
				
			   $report->{clickthroughs}++;
			
				if(!exists($url_report->{$url})){ 
					$url_report->{$url} = 0; 
				}
			
				$url_report->{$url}++; 
			
			}elsif($url eq 'open'){ 	
			
				$report->{'open'}++;
				
			}elsif($url eq 'num_subscribers'){ 
			
				$report->{'num_subscribers'} = $extra;	
				
			}elsif($url eq 'soft_bounce'){ 	

				if(!exists($report->{soft_bounce})){ 
					$report->{soft_bounce} = 0; 
				}
				$report->{soft_bounce}++;
				push(@{$report->{'soft_bounce_report'}}, {email => $extra, timestamp => $t});

			}elsif($url eq 'hard_bounce'){ 	
					if(!exists($report->{hard_bounce})){ 
						$report->{hard_bounce} = 0; 
					}
				$report->{hard_bounce}++; 
				push(@{$report->{'hard_bounce_report'}}, {email => $extra, timestamp => $t});
			}elsif($url eq 'forward_to_a_friend'){ 	
					if(!exists($report->{forward_to_a_friend})){ 
						$report->{forward_to_a_friend} = 0; 
					}
				$report->{forward_to_a_friend}++;
			}elsif($url eq 'view_archive'){ 	
					if(!exists($report->{view_archive})){ 
						$report->{view_archive} = 0; 
					}
				$report->{view_archive}++;
					
			}	
		}		
	}
	close(LOG); 
	
	
	$report->{url_report} = [];
	foreach(keys %$url_report){ 
		push(@{$report->{url_report}}, {url => $_, count => $url_report->{$_}}); 
	}
	
	return $report; 
}


sub export_logs { 

	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthrough';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}
	
	
	my $l; 
	unless(-e $self->clickthrough_log_location){ 
		print '';
		return; 
	}
	
	require   Text::CSV; 
	my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	
	if($args->{-type} eq 'clickthrough'){ 
		my $title_status = $csv->print ($fh, [qw(timestamp message_id url)]);
		print $fh "\n";
	}
	elsif($args->{-type} eq 'activity'){ 
		my $title_status = $csv->print ($fh, [qw(timestamp message_id activity details)]);
		print $fh "\n";
	}	
	
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
		or croak "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
	while(defined($l = <LOG>)){ 
		chomp($l);
		my @fields = split(/\t/, $l);
		my ( $t, $mid, $url, $extra ) = split( "\t", $l, 4 );

		$t     = strip($t);
		$mid   = strip($mid);
		$url   = strip($url);
		$extra = strip($extra);

		
		my $log_line_type = 'activity'; 
		
		if (   $url ne 'open'
            && $url ne 'num_subscribers'
            && $url ne 'bounce'
            && $url ne 'hard_bounce'
            && $url ne 'soft_bounce'
            && $url ne undef ){
		
				$log_line_type = 'clickthrough'; 
		
		}
		
		if(defined($args->{-mid})){ 
			unless($args->{-mid} == $mid){ 
				next;
			}
		}
		
		if($args->{-type} eq 'clickthrough' && $log_line_type eq 'clickthrough'){ 
			
			my $status = $csv->print ($fh, [@fields]);
			print $fh "\n";
		}
		elsif($args->{-type} eq 'activity' && $log_line_type eq 'activity' ) { 
			
			my $status = $csv->print ($fh, [@fields]);
			print $fh "\n";
		}
	}
}



sub report_by_url { 
	my $self      = shift; 
	my $match_mid = shift; 
	my $match_url = shift;
	
	my $report = []; 
	my $l;
	
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
	 or croak "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
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




sub data_over_time {

    my $self   = shift;
    my ($args) = @_;
    my $msg_id = undef;
    my $data   = {};
    my $order  = [];
    my $r      = [];

    if ( exists( $args->{-msg_id} ) ) {
        $msg_id = $args->{-msg_id};
    }
    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'clickthroughs';
    }

    my $type = undef;
    if ( $args->{-type} eq 'clickthroughs' ) {
        $type = 'clickthroughs';
    }
    elsif ( $args->{-type} eq 'opens' ) {
        $type = 'open';
    }
    elsif ( $args->{-type} eq 'forward_to_a_friend' ) {
        $type = 'forward_to_a_friend';
    }
    elsif ( $args->{-type} eq 'view_archive' ) {
        $type = 'view_archive';
    }

    my $l = undef;
    open( LOG,
        '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',
        $self->clickthrough_log_location
      )
      or croak "Couldn't open file: '"
      . $self->clickthrough_log_location
      . '\'because: '
      . $!;
    while ( defined( $l = <LOG> ) ) {

        chomp($l);
        my ( $t, $mid, $url, $extra ) = split( "\t", $l, 4 );

        my $need = 0;

		if ( $type ne 'clickthroughs' ) {
	        if ( $url eq $type ) {
	            $need = 1;
	        }
		}
		else { 
        # then its a clickthrough its a clickthrough:
			if ( $type eq 'clickthroughs' ) {
            	if (   $url ne 'open'
 	               && $url ne 'num_subscribers'
	                && $url ne 'bounce'
	                && $url ne 'hard_bounce'
	                && $url ne 'soft_bounce'
	                && $url ne 'forward_to_a_friend'
	                && $url ne 'view_archive'
	                && $url ne undef )
	            {
					$need = 1;
	            }
			}
        }

        if ( $need == 1 ) {

            if ( defined($msg_id) ) {
                if ( $msg_id ne $mid ) {
                    next;
                }
            }

            my ( $named_day, $month, $day, $time, $year ) =
              split( ' ', $t );    #Sat Feb 12 21:43:00 2011
            my $mdy = "$month $day $year";
            if ( !exists( $data->{$mdy} ) ) {
                $data->{$mdy} = 0;
                push( @$order, $mdy );
            }
            $data->{$mdy}++;
        }

    }

    foreach (@$order) {
        push( @$r, { mdy => $_, count => $data->{$_} } );
    }

    return $r;

}




sub purge_log { 
	my $self = shift; 
	unlink($self->clickthrough_log_location); 
	# probably better to, return unlink(...);
	return 1; 
}




sub clickthrough_log_location { 

	my $self = shift; 
	my $ctl  =  $DADA::Config::LOGS  . '/' . $self->{name} . '-clickthrough.log';
	   $ctl  = DADA::App::Guts::make_safer($ctl);
	   $ctl =~ /(.*)/;
	   $ctl = $1; 
	   return $ctl; 
}

sub can_use_country_geoip_data { 
	return 0; 
}







1;

=pod

=head1 NAME

DADA::MailingList::Clickthrough::Db

=head1 VERSION

Fill me in!
 
=head1 SYNOPSIS

Fill me in!

=head1 DESCRIPTION

Fill me in !
 
=head1 SUBROUTINES/METHODS 

Fill me in!

=head1 DIAGNOSTICS

Fill me in!

=head1 CONFIGURATION AND ENVIRONMENT

Fill me in!

=head1 DEPENDENCIES


Fill me in!


=head1 INCOMPATIBILITIES

Fill me in!

=head1 BUGS AND LIMITATIONS

Fill me in!

=head1 AUTHOR

Fill me in!

=head1 LICENCE AND COPYRIGHT

Fill me in!

=cut

