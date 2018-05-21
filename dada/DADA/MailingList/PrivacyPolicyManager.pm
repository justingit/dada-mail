package DADA::MailingList::PrivacyPolicyManager;

use lib qw(./ ../DADA ../ ../../ ../../DADA ../perllib); 

use Carp qw(carp croak);
use Try::Tiny; 

use DADA::Config;
use DADA::App::Guts;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();
use strict;
use vars qw(@EXPORT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_PrivacyPolicyManager};

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
	
	return $self; 
}


sub _init {
	my $self = shift; 
	$self->{sql_params} = {%DADA::Config::SQL_PARAMS};
	my $dbi_obj = undef;
    require DADA::App::DBIHandle;
    $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;	
}




sub add {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-list} ) ) {
        croak '-list is required!';
    }

    if ( !exists( $args->{-privacy_policy} ) ) {
        carp 'privacy_policy is required!';
		return undef; 
    }

    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{privacy_policies_table}
      . '(list, privacy_policy) VALUES (?, ?)';

    carp 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-list}, $args->{-privacy_policy} )
      or croak "cannot do statement (at add)! $DBI::errstr\n";
    $sth->finish;

    # last row id:
    undef($query);
    undef($sth);

    my $query = 'SELECT privacy_policy_id FROM ' 
	. $DADA::Config::SQL_PARAMS{privacy_policies_table} 
	. ' WHERE list = ? ORDER BY privacy_policy_id DESC LIMIT 1';

	my $sth = $self->{dbh}->prepare($query);


    $sth->execute( $args->{-list} )
      or croak "cannot do statement (at add)! $DBI::errstr\n";
	  
    my $new_id = $sth->fetchrow_array;
    $sth->finish;
    return $new_id;
}

sub latest_privacy_policy { 
	my $self = shift; 
	my ($args) = @_; 
	
    my $query = 'SELECT privacy_policy_id, timestamp, privacy_policy FROM ' 
	. $DADA::Config::SQL_PARAMS{privacy_policies_table} 
	. ' WHERE list = ? ORDER BY privacy_policy_id DESC LIMIT 1';

	my $sth = $self->{dbh}->prepare($query);


    $sth->execute( $args->{-list} )
      or croak "cannot do statement (at add)! $DBI::errstr\n";
	  
    my $data = $sth->fetchrow_hashref;
    $sth->finish;
    return $data;

}


1;