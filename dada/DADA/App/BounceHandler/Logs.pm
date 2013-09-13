package DADA::App::BounceHandler::Logs;

use strict;
use lib qw(
  ../../../
  ../../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use 5.008_001;

use Carp qw(croak carp);
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

    my ($args) = @_;
    $self->_init($args);
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {

    my $self = shift;
    my ($args) = @_;

}

sub search {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-query} ) ) {
        croak "you MUST pass the, '-query' parameter!";
    }
    if ( !exists( $args->{-list} ) ) {
        croak "you MUST pass the, '-list' parameter!";
    }
    if ( !exists( $args->{-file} ) ) {
        croak "you MUST pass the, '-file' parameter!";
    }

    my $query = $args->{-query};
    my $list  = $args->{-list};
    my $file  = $args->{-file};

    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $list } );

    require DADA::App::BounceHandler::ScoreKeeper;
    my $bsk = DADA::App::BounceHandler::ScoreKeeper->new( { -list => $list } );

    require DADA::App::LogSearch;

    my $searcher = DADA::App::LogSearch->new;
    my $results  = $searcher->search(
        {
            -query => $query,
            -files => [$file],

        }
    );

    my $search_results = [];

    if ( $results->{$file}->[0] ) {

        for my $l ( @{ $results->{$file} } ) {

            my @entries = split( "\t", $l, 5 );    # Limit of 5

            # Let us try to munge the data!

            # Give back only results from this list.
            $entries[1] = strip( $entries[1] );
            next if $entries[1] ne $list;

            # Date!
            $entries[0] =~ s/^\[|\]$//g;

            # $entries[0] = $searcher->html_highlight_line(
            #     { -query => $query, -line => $entries[0] } );
            #
            # ListShortName!
            #$entries[1] = $searcher->html_highlight_line(
            #    { -query => $query, -line => $entries[1] } );
            #
            # Action Taken!
            #$entries[2] = $searcher->html_highlight_line(
            #   { -query => $query, -line => $entries[2] } );
            #
            # Email Address!
            #           $entries[3] = $searcher->html_highlight_line(
            #              { -query => $query, -line => $entries[3] } );

            my @diags = split( ",", $entries[4] );
            my $labeled_digs = [];

            for my $diag (@diags) {
                my ( $label, $value ) = split( ":", $diag );
                my $newline = quotemeta('\n');

                # Make fake newlines, newlines:
                $value =~ s/$newline/\n/g;

				# Make fake colons, colons: 
				$value =~ s/\_\_colon\_\_/\:/g; 
                push(
                    @$labeled_digs,
                    {
                        diagnostic_label => $label,

                        #  diagnostic_label => $searcher->html_highlight_line(
                        #      { -query => $query, -line => $label }
                        #  ),
                        diagnostic_value => $value

                          # $searcher->html_highlight_line(
                          #      { -query => $query, -line => $value }
                          #  ),

                    }
                );

            }

            if ( $entries[1] eq $list ) {   # only show entries for this list...
                push(
                    @$search_results,
                    {
                        date        => $entries[0],
                        list        => $entries[1],
                        list_name   => $ls->param('list_name'),
                        action      => $entries[2],
                        email       => $entries[3],
                        diagnostics => $labeled_digs,

                    }
                );
            }

        }

        return $search_results

    }
    else {

        return [];

    }

}

1;