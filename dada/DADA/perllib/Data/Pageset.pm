package Data::Pageset;

use strict;
use Carp;

use Data::Page;

use vars qw(@ISA $VERSION);

@ISA = qw(Data::Page);

$VERSION = '1.06';

=head1 NAME

Data::Pageset - Page numbering and page sets

=head1 SYNOPSIS

  use Data::Pageset;
  my $page_info = Data::Pageset->new({
    'total_entries'       => $total_entries, 
    'entries_per_page'    => $entries_per_page, 
    # Optional, will use defaults otherwise.
    'current_page'        => $current_page,
    'pages_per_set'       => $pages_per_set,
    'mode'                => 'fixed', # default, or 'slide'
  });

  # General page information
  print "         First page: ", $page_info->first_page, "\n";
  print "          Last page: ", $page_info->last_page, "\n";
  print "          Next page: ", $page_info->next_page, "\n";
  print "      Previous page: ", $page_info->previous_page, "\n";

  # Results on current page
  print "First entry on page: ", $page_info->first, "\n";
  print " Last entry on page: ", $page_info->last, "\n";

  # Can add in the pages per set after the object is created
  $page_info->pages_per_set($pages_per_set);
  
  # Page set information
  print "First page of previous page set: ",  $page_info->previous_set, "\n";
  print "    First page of next page set: ",  $page_info->next_set, "\n";
  
  # Print the page numbers of the current set
  foreach my $page (@{$page_info->pages_in_set()}) {
    if($page == $page_info->current_page()) {
      print "<b>$page</b> ";
    } else {
      print "$page ";
    }
  }

=head1 DESCRIPTION

The object produced by Data::Pageset can be used to create page
navigation, it inherits from Data::Page and has access to all 
methods from this object.

In addition it also provides methods for dealing with set of pages,
so that if there are too many pages you can easily break them
into chunks for the user to browse through.

You can even choose to view page numbers in your set in a 'sliding'
fassion.

The object can easily be passed to a templating system
such as Template Toolkit or be used within a script.

=head1 METHODS

=head2 new()

  use Data::Pageset;
  my $page_info = Data::Pageset->new({
    'total_entries'       => $total_entries, 
    'entries_per_page'    => $entries_per_page, 
    # Optional, will use defaults otherwise.
    'current_page'        => $current_page,
    'pages_per_set'       => $pages_per_set,
    'mode'                => 'slide', # default fixed
  });

This is the constructor of the object, it requires an anonymous
hash containing the 'total_entries', how many data units you have,
and the number of 'entries_per_page' to display. Optionally
the 'current_page' (defaults to page 1) and pages_per_set (how
many pages to display, defaults to 10) can be added. 

The mode (which defaults to 'fixed') determins how the paging
will work, for example with 10 pages_per_set and the current_page
set to 18 you will get the following results:

=head3 Fixed:

=over 4

=item Pages in set:

11,12,13,14,15,16,17,18,19,20

=item Previous page set:  

1

=item Next page set:

21

=back 4

=head3 Slide:

=over 4

=item Pages in set:

14,15,16,17,18,19,20,21,22,23

=item Previous page set:  

9

=item Next page set:

24

=back 4

You can not change modes once the object is created.

=cut

sub new {
    my ( $class, $conf ) = @_;
    my $self = {};

    croak "total_entries and entries_per_page must be supplied"
        unless defined $conf->{'total_entries'}
            && defined $conf->{'entries_per_page'};

    $conf->{'current_page'} = 1 unless defined $conf->{'current_page'};
    $conf->{pages_per_set} = 10 unless defined $conf->{'pages_per_set'};
    if ( defined $conf->{'mode'} && $conf->{'mode'} eq 'slide' ) {
        $self->{mode} = 'slide';
    } else {
        $self->{mode} = 'fixed';
    }
    bless( $self, $class );

    $self->total_entries( $conf->{'total_entries'} );
    $self->entries_per_page( $conf->{'entries_per_page'} );
    $self->current_page( $conf->{'current_page'} );

    $self->pages_per_set( $conf->{'pages_per_set'} );

    return $self;
}

=head2 current_page()

  $page_info->current_page($page_num);

This method sets the current_page to the argument supplied, it can also be 
set in the constructor, but you may want to reuse the object if printing out
multiple pages. It will then return the page number once set. 

If this method is called without any arguments it returns the current page number.

=cut

sub current_page {
    my $self = shift;

    if (@_) {

        # Set current page
        $self->_current_page_accessor(@_);

        # Redo calculations, using current pages_per_set value
        $self->pages_per_set( $self->pages_per_set() );
    }

    # Not sure if there is some cleaver way of calling SUPER here,
    # think it would have to be wrapped in an eval
    return $self->first_page
        if $self->_current_page_accessor < $self->first_page;
    return $self->last_page
        if $self->_current_page_accessor > $self->last_page;
    return $self->_current_page_accessor();
}

=head2 pages_per_set()

  $page_info->pages_per_set($number_of_pages_per_set);

Calling this method initalises the calculations required to use
the paging methods below. The value can also be passed into
the constructor method new().

If called without any arguments it will return the current
number of pages per set.

=cut

sub pages_per_set {
    my $self              = shift;
    my $max_pages_per_set = shift;

    # set as undef so it at least exists
    $self->{PAGE_SET_PAGES_PER_SET} = undef
        unless exists $self->{PAGE_SET_PAGES_PER_SET};

    # Not trying to set, so return current number;
    return $self->{PAGE_SET_PAGES_PER_SET} unless $max_pages_per_set;

    $self->{PAGE_SET_PAGES_PER_SET} = $max_pages_per_set;

    unless ( $max_pages_per_set > 1 ) {

        # Only have one page in the set, must be page 1
        $self->{PAGE_SET_PREVIOUS} = $self->current_page() - 1
            if $self->current_page != 1;
        $self->{PAGE_SET_PAGES} = [1];
        $self->{PAGE_SET_NEXT}  = $self->current_page() + 1
            if $self->current_page() < $self->last_page();
    } else {
        if ( $self->{mode} eq 'fixed' ) {
            my $starting_page = $self->_calc_start_page($max_pages_per_set);
            my $end_page      = $starting_page + $max_pages_per_set - 1;

            if ( $end_page < $self->last_page() ) {
                $self->{PAGE_SET_NEXT} = $end_page + 1;
            }

            if ( $starting_page > 1 ) {
                $self->{PAGE_SET_PREVIOUS}
                    = $starting_page - $max_pages_per_set;

           # I can't see a reason for this to be here!
           #$self->{PAGE_SET_PREVIOUS} =  1 if $self->{PAGE_SET_PREVIOUS} < 1;
            }

            $end_page = $self->last_page() if $self->last_page() < $end_page;
            $self->{PAGE_SET_PAGES} = [ $starting_page .. $end_page ];
        } else {

            # We're in slide mode

            # See if we have enough pages to slide
            if ( $max_pages_per_set >= $self->last_page() ) {

                # No sliding, no next/prev pageset
                $self->{PAGE_SET_PAGES} = [ '1' .. $self->last_page() ];
            } else {

       # Find the middle rounding down - we want more pages after, than before
                my $middle = int( $max_pages_per_set / 2 );

                # offset for extra value right of center on even numbered sets
                my $offset = 1;
                if ( $max_pages_per_set % 2 != 0 ) {

                    # must have been an odd number, add one
                    $middle++;
                    $offset = 0;
                }

                my $starting_page = $self->current_page() - $middle + 1;
                $starting_page = 1 if $starting_page < 1;
                my $end_page = $starting_page + $max_pages_per_set - 1;
                $end_page = $self->last_page()
                    if $self->last_page() < $end_page;

                if ( $self->current_page() <= $middle ) {

                    # near the start of the page numbers
                    $self->{PAGE_SET_NEXT}
                        = $max_pages_per_set + $middle - $offset;
                    $self->{PAGE_SET_PAGES} = [ '1' .. $max_pages_per_set ];
                } elsif ( $self->current_page()
                    > ( $self->last_page() - $middle - $offset ) )
                {

                    # near the end of the page numbers
                    $self->{PAGE_SET_PREVIOUS}
                        = $self->last_page() 
                        - $max_pages_per_set 
                        - $middle + 1;
                    $self->{PAGE_SET_PAGES}
                        = [ ( $self->last_page() - $max_pages_per_set + 1 )
                        .. $self->last_page() ];
                } else {

                    # Start scrolling baby!
                    $self->{PAGE_SET_PAGES} = [ $starting_page .. $end_page ];
                    $self->{PAGE_SET_PREVIOUS}
                        = $starting_page - $middle - $offset;
                    $self->{PAGE_SET_PREVIOUS} = 1
                        if $self->{PAGE_SET_PREVIOUS} < 1;
                    $self->{PAGE_SET_NEXT} = $end_page + $middle;
                }
            }
        }
    }

}

=head2 previous_set()

  print "Back to previous set which starts at ", $page_info->previous_set(), "\n";

This method returns the page number at the start of the previous page set.
undef is return if pages_per_set has not been set.

=cut  

sub previous_set {
    my $self = shift;
    return $self->{PAGE_SET_PREVIOUS} if defined $self->{PAGE_SET_PREVIOUS};
    return undef;
}

=head2 next_set()

  print "Next set starts at ", $page_info->next_set(), "\n";

This method returns the page number at the start of the next page set.
undef is return if pages_per_set has not been set.

=cut  

sub next_set {
    my $self = shift;
    return $self->{PAGE_SET_NEXT} if defined $self->{PAGE_SET_NEXT};
    return undef;
}

=head2 pages_in_set()

  foreach my $page_num (@{$page_info->pages_in_set()}) {
    print "Page: $page_num \n";
  }

This method returns an array ref of the the page numbers within
the current set. undef is return if pages_per_set has not been set.

=cut  

sub pages_in_set {
    my $self = shift;
    return $self->{PAGE_SET_PAGES};
}

# Calc the first page in the current set
sub _calc_start_page {
    my ( $self, $max_page_links_per_page ) = @_;
    my $start_page;

    my $current_page = $self->current_page();
    my $max_pages_per_set;

    my $current_page_set = 0;

    if ( $max_page_links_per_page > 0 ) {
        $current_page_set = int( $current_page / $max_page_links_per_page );

        if ( $current_page % $max_page_links_per_page == 0 ) {
            $current_page_set = $current_page_set - 1;
        }
    }

    $start_page = ( $current_page_set * $max_page_links_per_page ) + 1;

    return $start_page;
}

=head1 EXPORT

None by default.

=head1 AUTHOR

Leo Lapworth C<< <LLAP@cuckoo.org> >>

=head1 REPOSITORY

http://github.com/ranguard/data-pageset

=head1 CONTRIBUTORS

Ryan D Johnson C<< <ryan@innerfence.com> >>
PLOBBES

=head1 SEE ALSO

L<Data::Page>.

=head1 COPYRIGHT

Copyright (C) 2007, Leo Lapworth

This module is free software; you can redistribute it or modify it
under the same terms as Perl itself.

=cut

1;

