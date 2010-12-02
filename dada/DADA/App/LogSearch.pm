package DADA::App::LogSearch; 

use strict; 
use lib qw(./ ../  ../DADA ../DADA/perllib); 

use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts; 

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

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006 - 2009 Justin Justin Simoni All rights reserved. 

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


