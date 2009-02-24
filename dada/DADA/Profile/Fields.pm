package DADA::Profile::Fields; 
use lib qw(../../ ../../DADA ../../perllib);
use Carp qw(carp croak);
my $type; 
use DADA::Config qw(!:DEFAULT); 	
BEGIN { 
	$type = $DADA::Config::SUBSCRIBER_DB_TYPE;
	if($type =~ m/sql/i){ 
		if ($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite'){ 
			$type = 'SQLite'; 
		}
		else { 		
			$type = 'baseSQL';
		}
	}
}
use base "DADA::Profile::Fields::$type";
use strict; 


use DADA::Logging::Usage;
my $log = new DADA::Logging::Usage;



use strict; 


use DADA::App::Guts;
		
	
my $email_id  = $DADA::Config::SQL_PARAMS{id_column} || 'email_id';

$DADA::Config::SQL_PARAMS{id_column} ||= 'email_id';


my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_baseSQL}; 


use Fcntl qw(
			O_WRONLY  
             O_TRUNC 
             O_CREAT 
             O_RDWR
             O_RDONLY
             LOCK_EX
             LOCK_SH 
             LOCK_NB
            ); 

my %fields; 

my $dbi_obj; 



sub new {

	my $class  = shift;
	my ($args) = @_; 

	my $self = {};			
	bless $self, $class;
	$self->_init($args); 
	return $self;

}





sub _init  { 

    my $self = shift; 

	my ($args) = @_; 	
    
    $self->{'log'}      = new DADA::Logging::Usage;
  
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS};
	

	if($DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/){ 
		require DADA::App::DBIHandle; 
		$dbi_obj = DADA::App::DBIHandle->new; 
		$self->{dbh} = $dbi_obj->dbh_obj; 
	}
	
	
}




sub get_fallback_field_values { 

    my $self = shift; 
    my $v    = {}; 
    
    return $v if  $self->can_have_subscriber_fields == 0; 
    require  DADA::MailingList::Settings; 
	my @lists = DADA::App::Guts::available_lists(); 
    my $ls = DADA::MailingList::Settings->new({-list => $lists[0]});
    my $li = $ls->get;   
    my @fallback_fields = split("\n", $li->{fallback_field_values}); 
    foreach(@fallback_fields){ 
        my ($n, $val) = split(':', $_); 
        $v->{$n} = $val; 
    }
    
    return $v; 
}




1; 

