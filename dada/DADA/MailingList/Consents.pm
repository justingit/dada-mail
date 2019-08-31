package DADA::MailingList::Consents;

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

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_Consents};

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

    if ( !exists( $args->{-consent} ) ) {
        croak '-consent is required!';
    }
	elsif(length($args->{-consent}) < 16) { 
		croak "You need to pass a longer list content!";
	}

    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{consents_table}
      . '(list, consent) VALUES (?, ?)';

    carp 'QUERY: ' . $query;
#      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-list}, $args->{-consent} )
      or croak "cannot do statement (at add)! $DBI::errstr\n";
    $sth->finish;

    # last row id:
    undef($query);
    undef($sth);

    my $query = 'SELECT consent_id FROM ' 
	. $DADA::Config::SQL_PARAMS{consents_table} 
	. ' WHERE list = ? ORDER BY consent_id DESC LIMIT 1';

	my $sth = $self->{dbh}->prepare($query);


    $sth->execute( $args->{-list} )
      or croak "cannot do statement (at add)! $DBI::errstr\n";
	  


    my $new_id = $sth->fetchrow_array;
    $sth->finish;
    return $new_id;
}

sub thawish_for_reading { 
	my $self = shift; 
	my $setting = shift; 
	
	require YAML::Tiny; 
	my $yaml = YAML::Tiny->read_string($setting);
	
	if($yaml->[0]){ 
		return $yaml->[0]->{consent_ids};	
	}
	else { 
		return []; 
	}
} 


sub freezish_for_saving { 
	my $self = shift; 
	my $arrayref = shift; 
	
	my $config = {
	  consent_ids => $arrayref
	};
	
	
	require YAML::Tiny; 
	my $yaml = YAML::Tiny->new( $config);
	
  	return $yaml->write_string; 
}

sub give_me_all_consents { 
	my $self = shift; 
	my $ls   = shift;
	
	my $consent_ids = $ls->param('list_consent_ids');
	
	my $ids = $self->thawish_for_reading($consent_ids);
	
	my $consent_data = [];
	
	foreach my $id(@$ids){ 
		my $query = 'SELECT consent_id, consent FROM ' 
		. $DADA::Config::SQL_PARAMS{consents_table}
		. ' WHERE list = ? AND consent_id = ?'; 
		
		my $sth = $self->{dbh}->prepare($query);

	    $sth->execute($ls->param('list'), $id )
	      or croak "cannot do statement (at add)! $DBI::errstr\n";

	    my $d = $sth->fetchrow_hashref;
	  	  push(@$consent_data, {id => $d->{consent_id}, consent => $d->{consent}});
		$sth->finish; 
	}
	

	return $consent_data; 
	 
}


1;