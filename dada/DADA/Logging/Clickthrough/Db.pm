package DADA::Logging::Clickthrough::Db;
use lib qw(../../../ ../../../DADA/perllib);

sub new {

    my $class  = shift;
    my ($args) = @_;
    my $self   = {};
    bless $self, $class;
    return $self;
}

sub enabled { 
	my $self = shift; 
	return 0; 
}

1;