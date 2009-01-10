package DADA::MailingList::SubscriberFields::PlainText; 

use strict; 

use lib qw(../../ ../../../ ../../../perllib ../../ ../perllib);

use DADA::Logging::Usage; 

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

	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings;
		 
		$self->{ls} = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$self->{ls} = $args->{-ls_obj};
	}
	
    
    $self->{'log'}      = new DADA::Logging::Usage;
    $self->{list}       = $args->{-list};

    	
}


1; 

