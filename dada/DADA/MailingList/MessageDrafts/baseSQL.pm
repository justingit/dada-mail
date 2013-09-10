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

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'draft';
    }
    if ( !exists( $args->{-cgi_obj} ) ) {
        croak "You MUST pass a, '-cgi_obj' paramater!";
    }

    my $draft =
      $self->stringify_cgi_params( { -cgi_obj => $args->{-cgi_obj} } );

    my $query = 'INSERT INTO dada_message_drafts (list, screen, role, draft) VALUES (?,?,?,?)';

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{list}, 'send_email', $args->{-role}, $draft )
      or croak "cannot do statment '$query'! $DBI::errstr\n";

    $sth->finish;

}




sub has_draft { 
	my $self = shift; 

    my $query =
        'SELECT COUNT(*) FROM '
      . 'dada_message_drafts'
      . ' WHERE list = ?';
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $self->{list} )
      or croak "cannot do statment '$query'! $DBI::errstr\n";

    my $count = $sth->fetchrow_array;

    $sth->finish;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
    
	
}


sub fetch { 
	my $self = shift; 
	
	my $query = 'SELECT list, screen, role, draft FROM dada_message_drafts WHERE list = ? AND screen = ? AND role = ?';
	my $sth = $self->{dbh}->prepare($query);

	my $saved = ''; 
	
    $sth->execute( $self->{list}, 'send_email', 'draft')
      or croak "cannot do statment '$query'! $DBI::errstr\n";
	my $hashref; 
	
	FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
		$sth->finish;
		$saved = $hashref->{draft};
	}
    
	open  my $fh, '<', \$saved || die $!;

	require CGI; 
	my $q = CGI->new($fh); 
	
	return $q; 
	
}

sub stringify_cgi_params {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-cgi_obj} ) ) {
        croak "You MUST pass a, '-cgi_obj' paramater!";
    }

    my $q = $args->{-cgi_obj};
    $q = $self->remove_unwanted_params( { -cgi_obj => $args->{-cgi_obj} } );

    my $buffer = "";
    open my $fh, ">", \$buffer or die 'blarg!' . $!;
    $q->save($fh);
	return $buffer; 
}

sub remove_unwanted_params {
    my $self   = shift;
    my ($args) = @_;
    my $q      = $args->{-cgi_obj};

    require CGI;
    my $new_q          = CGI->new($q);
    my $params_to_save = $self->params_to_save;

    for ( $new_q->param ) {
        unless ( exists( $params_to_save->{$_} ) ) {
            $new_q->delete($_);
        }
    }

    return $new_q;

}

sub params_to_save {

    my $self = shift;

    return {
	
		'Reply-To' => 1, 
		'X-Priority' => 1, 
		
		archive_message     => 1, 
		archive_no_send     => 1, 
		back_date           => 1, 
		backdate_month      => 1, 
		backdate_day        => 1, 
		backdate_year       => 1, 
		backdate_hour       => 1, 
		backdate_minute     => 1, 
		backdate_second     => 1, 
		backdate_hour_label => 1, 
		
		# Profile Fields Stuff... 
		
		
		# This should be dynamic, as well... 
		attachment1 => 1, 
		attachment2 => 2, 
		attachment3 => 3, 
		
		im_sure     => 1, 
		new_win     => 1, 
		test_recipient => 1, 
		
        Subject           => 1,
        html_message_body => 1,
        text_message_body => 1,
    };
}


1;