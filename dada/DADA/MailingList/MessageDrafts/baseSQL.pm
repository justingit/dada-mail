package DADA::MailingList::MessageDrafts::baseSQL;
use strict; 

use lib qw(
  ../../../
  ../../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_MessageDrafts}; 

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
    my ($args) = @_;
    
 	$self->{list} = $args->{-list}; 

	$self->_sql_init();

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

    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
}

sub save { 
	my $self = shift; 
	my ($args) = @_; 

	if(!exists($args->{-role})){ 
		$args->{-role} = 'draft'; 
	}
	if(!exists($args->{-cgi_obj})){ 
		croak "You MUST pass a, '-cgi_obj' paramater!"; 
	}
	
	my $draft = $self->stringify_cgi_params({-cgi_obj => $args->{-cgi_obj}}); 
	
	my $query = 'INSERT INTO dada_message_drafts (list, role draft) VALUES (?,?,?)';

	my $sth = $self->{dbh}->prepare($query);

	my $sth->execute( $self->{list}, $args->{-role}, $draft )
      or croak "cannot do statment '$query'! $DBI::errstr\n";

    $sth->finish;

}

sub stringify_cgi_params { 
	
	my $self = shift; 
	my ($args) = @_; 

	if(!exists($args->{-cgi_obj})){ 
		croak "You MUST pass a, '-cgi_obj' paramater!"; 
	}
	
	my $q = $args->{-cgi_obj};
	   $q = $self->remove_unwanted_params({-cgi_obj => $q});
	
	my $buffer = "";
	open my $fh, ">", \$buffer or die $!;
	$q->save($fh);  
	 
}


sub remove_unwanted_params { 
	my $self   = shift; 
	my ($args) = @_; 
	my $q = $args->{-cgi_obj}; 
	
	require CGI; 
	my $new_q = CGI->new($q); 
	my $params_to_save = $self->params_to_save; 
	
	for($new_q->param) { 
		unless(exists($params_to_save->{$_})){ 
			$new_q->delete($_); 
		}
	}
	
	return $new_q; 
	
}
sub params_to_save { 
	
	my $self = shift; 
	
	return { 
		Subject => 1,
		html_message_body => 1,
		text_message_body => 1,
	}; 
}
