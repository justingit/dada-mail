package DADA::App::LogSearch; 

use strict; 
use lib qw(../../  ../../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 
use DADA::MailingList::Settings;

# Sorry - global!
my $List_Names = {};
foreach my $l( available_lists() ){
	my $ls = DADA::MailingList::Settings->new({-list => $l}); 
		$List_Names->{$l} = $ls->param('list_name');				
}

use Carp qw(croak carp);
use Fcntl qw(	O_WRONLY	O_TRUNC		O_CREAT		);

use vars qw($AUTOLOAD); 

my %allowed = (); 

sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my %args = (@_); 
		
   $self->_init(\%args); 
   return $self;
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init { 

	my $self = shift; 
		
}


sub search { 

    my $self = shift; 
    
    my ($args) = @_;

    croak "A query has not been passed. "
        if !exists( $args->{-query});

    croak "A List of Files to search have not been passed. "
        if !exists( $args->{-files});
        
    my @terms = split(' ', $args->{-query}); 
    for(@terms){ 
        $_ = quotemeta(DADA::App::Guts::xss_filter($_)); 
    }
    
    my $file_names = $self->_validate_files($args->{-files}); 
    
    my $results = {};
    
    # Just to start out...
    for my $f(@$file_names){ 
        $results->{$f} = []; 
    }
    
    for my $file(@$file_names){ 
    
        open my $LOG_FILE, '<', $file
        or die "Cannot read log at: '" . $file
        . "' because: "
        . $!;
        
        while(my $l = <$LOG_FILE>){ 
        chomp($l); 
        
            for my $term(@terms){ 
            
                if($l =~ m/$term/i){ 
                    push(@{$results->{$file}}, $l); 
                }
  
            }
        }
        close $LOG_FILE; 
    
    }


    return $results; 

}



sub subscription_search {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-email} ) ) {
        croak "you MUST pass the, '-email' parameter!";
    }

    if ( exists( $args->{-list} ) ) {
        #warn 'args list exists!';
    }
    else {
        #warn 'args list does not exist!';

    }

    #    if ( !exists( $args->{-list} ) ) {
    #        croak "you MUST pass the, '-list' parameter!";
    #    }

    my $results = [];

    my $file = $DADA::Config::PROGRAM_USAGE_LOG;

    open my $LOG_FILE, '<', $file
      or die "Cannot read log at: '" . $file . "' because: " . $!;

		my $lines = 0; 

	
    LOGFILE: while ( my $l = <$LOG_FILE> ) {
        chomp($l);
		$lines++; 
# Looking for entries like,
# [Mon Jan 30 22:56:41 2012]	list	174.16.92.159	Subscribed to list.list	example209@example.com
        my $llr = {};
        if ( exists( $args->{-list} ) ) {

            $llr = $self->log_line_report(
                {
                    -email => $args->{-email},
                    -line  => $l,
                    -list  => $args->{-list}
                }
            );
        }
        else {
            $llr = $self->log_line_report(
                {
                    -email => $args->{-email},
                    -line  => $l,
                }
            );

        }
        if(!keys %$llr) { 
			# warn 'no keys!'; 
			next LOGFILE; 
		}
        if ( exists( $args->{-list} ) ) {

            if (
                $llr->{list} eq $args->{-list}
                && (   $llr->{email} eq $args->{-email}
                    || $llr->{updated_email} eq $args->{-email} )
              )
            {
                push( @$results, $llr );
            }
        }
        else {

            if (

                $llr->{email} eq $args->{-email}
                || $llr->{updated_email} eq $args->{-email}

              )
            {

                push( @$results, $llr );
            }
        }

    }
    close $LOG_FILE;

	# warn 'lines: ' . $lines; 
    return $results;

}

sub log_line_report {
	
    my $self = shift;
    my ($args) = @_; 
	
    my ( $date, $list, $ip, $action, $email ) = split( /\t/, $args->{-line}, 5 );

 my %list_types = (
        list               => 'Subscribers',
        black_list         => 'Black Listed',
        authorized_senders => 'Authorized Senders',
        moderators         => 'Moderators',
        white_list         => 'White Listed',
        sub_request_list   => 'Subscription Requests',
        unsub_request_list => 'Unsubscription Requests',
        bounced_list       => 'Bouncing Addresses',
		invitelist         => 'List Invitations', 
    );

#	if(exists($args->{-list})) { 
#		warn "log_line_report: args list exists."; 
#	}
#	else { 
#		warn "log_line_report: args list DOES NOT exist."; 
#		
#	}
	
	# An attempt at optimization
		
	if(exists($args->{-list})){ 	
		if($list ne $args->{-list}) { 
			#warn 'here.' . $args->{-line}; 
			return {};
		} 
	}
	if(exists($args->{-email}) && exists($args->{-list})){ 
		
		my ($e, $ue) = ''; 		
		if($email =~ m/\:/){ 
			($e, $ue) = split(':', $email);
			
		}
		else { 
			$e  = $email; 
			$ue = $email; 
		}
		
		 if(($e ne $args->{-email} && $ue ne $args->{-email}) && $list ne $args->{-list}) { 

		#	warn 'e: "' . $e . '"'; 
		#	warn 'ue: "' . $ue . '"'; 
		#	warn '$args->{-email} "' . $args->{-email} . '"';

		#	warn 'here.' . $args->{-line}; 
			
			return {};
		}
	}
	elsif(exists($args->{-email})){ 
		my ($e, $ue) = '';
		if($email =~ m/\:/){ 
			($e, $ue) = split(':', $email); 
		}
		else { 
			$e  = $email; 
			$ue = $email; 
		}
		
		if($e ne $args->{-email} && $ue ne $args->{-email}) {
			#warn 'e: "' . $e . '"'; 
			#warn 'ue: "' . $ue . '"'; 
			#warn '$args->{-email} "' . $args->{-email} . '"';
			#
			#warn 'here.' . $args->{-line}; 	 
			return {};
		}
		
	}

    my $sublist     = undef;
    my $base_action = undef;
	my $new_email = undef; 

    # Subscribed to announce.sub_confirm_list	nillajess@yahoo.com

    if ( $action =~ m/Subscribed to/ ) {
        $action =~ m/^Subscribed to $list\.(.*?)$/;
        $base_action = 'subscribed';
        $sublist     = $1;
    }
    elsif ( $action =~ m/Unsubscribed from/ ) {
        $action =~ m/Unsubscribed from $list\.(.*?)$/;
        $base_action = 'unsubscribed';
        $sublist     = $1;
    }
    elsif ( $action =~ m/Subscription Confirmation Sent/ ) {
        $action =~ m/Subscription Confirmation Sent for $list\.(.*?)$/;
        $base_action = 'confirmation_sent';
        $sublist     = $1;
    }

    elsif ( $action =~ m/Updated Subscription for/ ) {
		# Updated Subscription for choir.    love@love.com:new@new.com
		
        $action =~ m/Updated Subscription for $list\.(.*?)$/;
        $base_action = 'subscription_updated';
        $sublist     = $1;
		($email, $new_email) = split(':', $email)
    }

    $date =~ s/(\[|\])//g;

    return {
        date           => $date,
        list           => $list,
		list_name      => $List_Names->{$list}, 
        ip             => $ip,
        email          => $email,
        type           => $sublist,
        type_title     => $list_types{$sublist},
        action         => $base_action,
		updated_email  => $new_email, # used for subscription updates
    };

}

sub sub_unsub_trends { 
	my $self = shift;
	my $type = 'list'; 
	my $time = time; 
	my ($args) = @_; 
	my $r = []; 
	require File::ReadBackwards; 
    my $bw = File::ReadBackwards->new( $DADA::Config::PROGRAM_USAGE_LOG ) or
                        die "can't read '" . $DADA::Config::PROGRAM_USAGE_LOG . "' $!" ;

	my $days = 180;
	if(exists($args->{-days})){ 
		$days = $args->{-days};
	}
	my $day_limit = scalar(localtime(past_date($time, $days)));
	my $limit_day_str = simplified_date_str($day_limit); 
		
	my $count = 0; 
	my %trends = ();
	my @dates; 
		
    READTHELOGS: while( defined(my  $log_line = $bw->readline ) ) {
		chomp($log_line); 
		my $llr = $self->log_line_report(
			{ 
				-list  => $args->{-list}, 
				-line => $log_line,
			}
		); 
		if(keys %$llr){
			if($llr->{type} eq $type && ($llr->{action} eq 'subscribed' || $llr->{action} eq 'unsubscribed')){ 
				#push(@$r, $llr);
				# Dates Looks like this: [Sat Sep 10 00:30:31 2011]
				#$count++; 
				
				# Munge the date, we just are interested in whole days. 
				my $date = $llr->{date}; 
				   $date =~ s/\[|\]//g;
				my $day_str = simplified_date_str($date); 
				
				# Init if we need to. 
				if(!exists($trends{$day_str})){ 
					$trends{$day_str} = {subscribed => 0, unsubscribed => 0};
					#push(@dates, $day_str); 
				}
				$trends{$day_str}->{$llr->{action}}++;
			
				
				if(
					($day_str eq $limit_day_str) || # We reach the date string
					(scalar(keys %trends) >= $days) # We have more entries, then days we're looking for.
					){ #count
					delete $trends{$day_str};

					last READTHELOGS;
				}
			}
		}
    }
	$bw->close;
	
	my @r_trends = (); 
	my $cum_sub = 0; 
	my $cum_unsub = 0;  


	# Fill in missing dates. 
	# Most likely, there are days nothing happened. 
	for(1 .. ($days)){ 
		my $s_date = simplified_date_str(scalar(localtime(past_date($time, $_))));
		#print '!$s_date:' . $s_date . "\n";
		if(!exists($trends{$s_date})){ 
			
			$trends{$s_date} = {subscribed => 0, unsubscribed => 0};
		}
		push(@dates, $s_date); 
	}
	
	# This will neglect any data that's out of our date range.
	for my $d(reverse @dates){ 
		$cum_sub   += $trends{$d}->{subscribed};
		$cum_unsub += $trends{$d}->{unsubscribed};
		push(@r_trends, { 
			date => $d, 
			subscribed              => $trends{$d}->{subscribed},
			unsubscribed            => $trends{$d}->{unsubscribed},
			cumulative_subscribed   => $cum_sub,
			cumulative_unsubscribed => $cum_unsub,
		}); 
	}
	return [@r_trends];
}
sub simplified_date_str { 
	my $date = shift; 
	my ($day, $month, $num_day, $time, $year) = split(' ', $date, 5);
	return join(' ', $day, $month, $num_day, $year);
	
}
sub past_date {
    my $time = shift;
    my $days = shift || 1;
	return $time if $days == 0; 
    my $now  = defined $time ? $time : time;
    my $then = $now - 60 * 60 * 24 * ($days - 1); # why, -1? 
    my $ndst = ( localtime $now )[8] > 0;
    my $tdst = ( localtime $then )[8] > 0;

    # Added '=' to avoid warning (and return)
    $then -= ( $tdst - $ndst ) * 60 * 60;
    return $then;
}

sub sub_unsub_trends_json { 
	my $self = shift; 
	my ($args) = @_; 
	if(! exists($args->{-days})){ 
		$args->{-days} = 30;
	}
	
	
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $args->{-list}, 
			-name    => 'sub_unsub_trends_json' . '.' . $args->{-days},
		}
	);
	if(!defined($json)){ 
	
		my $trends = $self->sub_unsub_trends($args);
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
			   { id => 'date',                    label => 'Date',                    type => 'string'}, 
			   { id => 'cumulative_subscribed',   label => 'Cumulative Subscriptions',   type => 'number',},
			   { id => 'cumulative_unsubscribed', label => 'Cumulative Unubscriptions', type => 'number',},
			   { id => 'subscribed',              label => 'Subscriptions',   type => 'number',},
			   { id => 'unsubscribed',            label => 'Unubscriptions', type => 'number',},
		);

		for(@$trends){ 
			$datatable->add_rows(
		        [
		               { v => $_->{date}},
		               { v => $_->{cumulative_subscribed} },
		               { v => $_->{cumulative_unsubscribed} },
		               { v => $_->{subscribed} },
		               { v => $_->{unsubscribed} },
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $args->{-list}, 
				-name    => 'sub_unsub_trends_json' . '.' . $args->{-days},
				-data    => \$json, 
			}
		);
		
	}
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json; 
	}
}


sub list_activity { 
	
	my $self = shift; 
	my ($args) = @_; 
	my $r = []; 
	require File::ReadBackwards; 
    my $bw = File::ReadBackwards->new( $DADA::Config::PROGRAM_USAGE_LOG ) or
                        die "can't read '" . $DADA::Config::PROGRAM_USAGE_LOG . "' $!" ;

	my $limit = 100; 
	my $count = 0; 
    LISTACTIVITY: while( defined(my  $log_line = $bw->readline ) ) {
		chomp($log_line); 
		my $llr = $self->log_line_report(
			{ 
				-list  => $args->{-list}, 
				-line => $log_line,
			}
		); 
		if(keys %$llr){
			push(@$r, $llr);
			$count++;  
		}
		if($count >= $limit){ 
			last LISTACTIVITY; 
		}
    }
	$bw->close;
	return $r; 
	
}

sub _validate_files { 

    my $self  = shift; 
    my $files = shift; 
    my $good_files = []; 
    

    for my $filename(@$files){  
        if(-f $filename && -e $filename){ 
            push(@$good_files, $filename); 
        }else{ 
            carp "file: $filename doesn't exist - skipping searching.";
        }
    }
    
    return $good_files; 
}




sub html_highlight_line { 


   my $self = shift; 
    
    my ($args) = @_;

    croak "A query has not been passed. "
        if !exists( $args->{-query});

    croak "A line to highlight has not been passed. "
        if !exists( $args->{-line});
        
    my @terms = split(' ', $args->{-query}); 
    
    for my $term(@terms){  
        $args->{-line} =~ s{$term}{<em class="highlighted">$term</em>}mg;
    }
    
   return $args->{-line}; 


}



sub DESTROY {}
    
1;

=pod

=head1 NAME

DADA::App::LogSearch - Simple Searching of PlainText Logs for Dada Mail


=head1 VERSION

Refer to the version of Dada Mail that this module comes in. 

=head1 SYNOPSIS

 
 my $query     = 'find me'; 
 my $searcher  = DADA::App::LogSearch->new; 
 
 my $results   = $searcher->search({
        -query => $query,
        -files => ['/home/account/dada_files/logs/dada_usage.txt'], 
 
 }); 

=head1 DESCRIPTION

This module provides a very simple interface to find a term in a list of files that you supply. 

=head1 SUBROUTINES/METHODS

=head2 new

Takes no arguments. Returns a DADA::App::LogSearch object. 

=head2 search

Takes B<two> arguments - both are required. They are: 

=over

=item * -query

Its value should be a string. 

This is the search term you're looking for. If you're search term has a space in it, for example, I<search term>, this module will search for B<both> I<search> and I<term> seperately. 

=item * -files

Its value should be an array ref

This is the list of files you'd like to search in. Use absolute paths to these files, ala: 

    
 my $results   = $searcher->search({
        -query => $query,
        -files => [
                   '/home/account/dada_files/logs/dada_usage.txt',
                   '/home/account/dada_files/logs/errors.txt'
                 ], 
  
 }); 

=back

This method will return a hashref. The key of the hashref is the name of the log file that you gave. Each value of the hashref is an arrayfref that holds the lines that match your query. 

=head2 html_highlight_line

Takes two arguments - both are required - 

They are: 

=over

=item * -query

Its value should be a string. 

This is the search term you're looking for. 

=item * -line 

Its value is a string - basically, one of the results that the LogSearch object brings back. 

=back

=head1 Example

Here's an example of how this object can be used: 


  use DADA::App::LogSearch
  my $query     = 'find me'; 
  
  my $searcher  = DADA::App::LogSearch->new; 
 
  my $results   = $searcher->search({
        -query => $query,
        -files => [
                   '/home/account/dada_files/logs/dada_usage.txt',
                   '/home/account/dada_files/logs/errors.txt'
                 ], 
 
 }); 
 
 for my $file_name(keys %$results){ 
     if($results->{$file_name}->[0]){ 
         print '<h1>' . $file_name . '</h1>'; 
         for my $l(@{$results->{$file_name}}){ 
             print '<p>' . $searcher->html_highlight_line({-query =>  $query, -line => $l }) . '</p>';               
          }
      }
  }
         
 

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS


Please report problems to the author of this module

=head1 AUTHOR

Justin Simoni 

See: http://dadamailproject.com/contact

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2006 - 2011 Justin Justin Simoni All rights reserved. 

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


