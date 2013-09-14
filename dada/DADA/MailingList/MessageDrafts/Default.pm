package DADA::MailingList::MessageDrafts::Default;

sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;

    return $self;

}

sub enabled { 
	return 0; 
}

1;