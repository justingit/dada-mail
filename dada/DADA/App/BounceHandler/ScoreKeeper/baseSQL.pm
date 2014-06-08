package DADA::App::BounceHandler::ScoreKeeper::baseSQL;

use strict;

use lib qw(
  ../../../../
  ../../../../perllib
);

use DADA::Config;
use DADA::App::Guts;

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_BounceHandler};

my $dbi_obj;

use Carp qw(croak carp);

sub new {

    my $class = shift;
    my ($args) = @_;

    if ( !exists( $args->{-list} ) ) {
        croak "You MUST pass a list in, -List!";
    }

    my $self = {};
    bless $self, $class;

    $self->_init($args);
    $self->_sql_init($args);

    return $self;
}

sub _sql_init {

    my $self = shift;
    my ($args) = @_;

    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};

    if ( !keys %{ $self->{sql_params} } ) {
        croak "sql params not filled out?!";
    }
    else {

    }

    if ( !$dbi_obj ) {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $self->{dbh} = $dbi_obj->dbh_obj;
    }
    else {
        $self->{dbh} = $dbi_obj->dbh_obj;
    }

}

sub tally_up_scores {

    warn "tally_up_scores method called."
      if $t;

    my $self             = shift;
    my $scores           = shift;
    my $give_back_scores = {};

    for my $email ( keys %$scores ) {

        my $query =
            'SELECT email, score FROM '
          . $self->{sql_params}->{bounce_scores_table}
          . ' WHERE email = ? AND list = ?';

        if ($t) {
            warn '$query ' . $query;
            warn 'email: ' . $email;
            warn 'list: ' . $self->{list};
        }

        my $sth = $self->{dbh}->prepare($query);
        $sth->execute( $email, $self->{list} )
          or croak "cannot do statement '$query'! $DBI::errstr\n";

        my @score = $sth->fetchrow_array();

        $sth->finish;
        if ( $score[0] eq undef ) {

            warn
"It doesn't look like we have a record for this address ($email) yet, so we're going to add one:"
              if $t;

            my $query2 =
                'INSERT INTO '
              . $self->{sql_params}->{bounce_scores_table}
              . '(email, list, score) VALUES (?,?,?)';
            my $sth2 = $self->{dbh}->prepare($query2);
            $sth2->execute( $email, $self->{list}, $scores->{$email} )
              or croak "cannot do statement '$query2'! $DBI::errstr\n";
            $give_back_scores->{$email} = $scores->{$email};

            $sth2->finish;
        }
        else {

            my $new_score = $score[1] + $scores->{$email};

            warn
"Appending the score for ($email) to a total of: $new_score: via ' $score[1]' plus '$scores->{$email}'"
              if $t;

            my $query2 =
                'UPDATE '
              . $self->{sql_params}->{bounce_scores_table}
              . ' SET score = ? WHERE email = ? AND list = ?';
            my $sth2 = $self->{dbh}->prepare($query2);
            $sth2->execute( $new_score, $email, $self->{list} )
              or croak "cannot do statement '$query2'! $DBI::errstr\n";

            $give_back_scores->{$email} = $new_score;

            $sth2->finish;
        }
    }

    return $give_back_scores;
}



sub decay_scorecard {

    my $self = shift;

    # Decay
    require DADA::MailingList::Settings;
    my $ls = DADA::MailingList::Settings->new( { -list => $self->{list} } );
    my $decay_rate = $ls->param('bounce_handler_decay_score');
    my $query =
        "UPDATE "
      . $self->{sql_params}->{bounce_scores_table}
      . " SET score=score-"
      . $decay_rate
      . " WHERE list = ?";
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statement $DBI::errstr\n";
    $sth->finish;

    # Then remove scores <= 0
    undef $sth;
    undef $query;

    my $query =
        'DELETE FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' WHERE list = ? AND score <= ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list}, 0 )
      or croak "cannot do statement! $DBI::errstr\n";
    $sth->finish;

}


sub removal_list {

    warn "removal_list method called."
      if $t;

    my $self         = shift;
    my $removal_list = [];
    my $query =
        'SELECT email, score FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' WHERE list = ? AND score >= ?';
    warn "Query:" . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list},
        $self->{ls}->param('bounce_handler_threshold_score') )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    while ( my ( $email, $score ) = $sth->fetchrow_array ) {
        warn "Found email, $email with score, $score"
          if $t;
        push( @$removal_list, $email );
    }
    $sth->finish;

    return $removal_list;

}

sub flush_old_scores {

    my $self = shift;
    my $query =
        'DELETE FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' WHERE list = ? AND score >= ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list},
        $self->{ls}->param('bounce_handler_threshold_score') )
      or croak "cannot do statement '$query'! $DBI::errstr\n";
    $sth->finish;

}

sub raw_scorecard {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-page} ) ) {
        $args->{-page} = 1;
    }
    if ( !exists( $args->{-entries} ) ) {
        $args->{-entries} = 100;
    }

    my $query =
        'SELECT email, score FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' WHERE list = ? ORDER BY email';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my $scorecard = [];

    while ( my ( $email, $score ) = $sth->fetchrow_array ) {
        push(
            @$scorecard,
            {
                email => $email,
                score => $score,
            }
        );
    }

    $sth->finish;

    my $total = 0;
    $total = $self->num_scorecard_rows;

    my $begin = ( $args->{-entries} - 1 ) * ( $args->{-page} - 1 );
    my $end = $begin + ( $args->{-entries} - 1 );

    if ( $end > $total - 1 ) {
        $end = $total - 1;
    }

    @$scorecard = @$scorecard[ $begin .. $end ];

    return ($scorecard);

}

sub print_csv_scorecard { 
    my $self = shift;
    my ($args) = @_;

	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 

    my $query =
        'SELECT email, score FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' WHERE list = ? ORDER BY email';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my $scorecard = [];

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);


	my $title_status = $csv->print ($fh, [qw(email score)]);
	print $fh "\n";


    while ( my ( $email, $score ) = $sth->fetchrow_array ) {
        my $status = $csv->print( $fh,[$email, $score]);
        print $fh "\n";
    }

    $sth->finish;
    
}

sub num_scorecard_rows {

    my $self = shift;

    my $query =
        'SELECT COUNT(*) FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' WHERE list = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
}

sub erase {

    my $self = shift;

    my $query =
        'DELETE FROM '
      . $self->{sql_params}->{bounce_scores_table}
      . ' where list = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statement '$query'! $DBI::errstr\n";
    $sth->finish;
    return 1;

}

sub _list_name_check {
    my ( $self, $n ) = @_;
    $n = $self->_trim($n);
    return 0 if !$n;
    return 0 if $self->_list_exists($n) == 0;
    $self->{list} = $n;
    return 1;
}

sub _trim {
    my ( $self, $s ) = @_;
    return DADA::App::Guts::strip($s);
}

sub _list_exists {
    my ( $self, $n ) = @_;
    return DADA::App::Guts::check_if_list_exists( -List => $n );
}

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

1;
