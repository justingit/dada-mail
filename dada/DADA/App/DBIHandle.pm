package DADA::App::DBIHandle;   

use lib qw( ../../ ../../perllib

/sw/lib/perl5/5.8.6/darwin-thread-multi-2level
/sw/lib/perl5

);

#my $i = 1; 
my $connect_n = 0; 
use DADA::Config;  


my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_DBIHandle}; 


use Carp qw(carp croak); 


# We usin' this at all?
if(
   $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/i || 
   $DADA::Config::ARCHIVE_DB_TYPE    =~ m/SQL/i || 
   $DADA::Config::SETTINGS_DB_TYPE   =~ m/SQL/i ||
   $DADA::Config::SESSION_DB_TYPE    =~ m/SQL/i

){
	
	require DBI; 
	# require WhackaWhack; 
};

	

if($DADA::Config::CPAN_DEBUG_SETTINGS{DBI} > 0){  
    DBI->trace($DADA::Config::CPAN_DEBUG_SETTINGS{DBI}, $PROGRAM_ERROR_LOG);
}

my $database  = $DADA::Config::SQL_PARAMS{database};
my $dbserver  = $DADA::Config::SQL_PARAMS{dbserver};    	  
my $port      = $DADA::Config::SQL_PARAMS{port};     	  
my $user      = $DADA::Config::SQL_PARAMS{user};         
my $pass      = $DADA::Config::SQL_PARAMS{pass};
my $email_id  = $DADA::Config::SQL_PARAMS{id_column} || 'email_id'; # DEV: This isn't set in the Config.pm (?!?!)
my $dbtype    = $DADA::Config::SQL_PARAMS{dbtype};




sub new {

	carp "Creating DBIHandle Object"
		if $t; 
		
	my $class = shift;
	my %args = (@_); 
	   my $self = {};			
       bless $self, $class;
	   $self->_init(%args); 
	   return $self;
}




sub _init  { 

	carp "Initializing DBIHandle Object"
		if $t; 
		
    my $self = shift; 
    my %args = @_; 
    $self->{sql_params} = {%DADA::Config::SQL_PARAMS}; 
    
	# We usin' this at all?
    if(
	   $DADA::Config::SUBSCRIBER_DB_TYPE =~ m/SQL/i || 
	   $DADA::Config::ARCHIVE_DB_TYPE    =~ m/SQL/i || 
	   $DADA::Config::SETTINGS_DB_TYPE   =~ m/SQL/i ||
	   $DADA::Config::SESSION_DB_TYPE    =~ m/SQL/i
	
	){ 
		carp "DBI support enabled"
			if $t; 
			
    	$self->{enabled} = 1; 
    } 
	else { 
    	$self->{enabled} = undef; 

		carp "DBI support is disabled"
			if $t;
			
	}
   
    $self->{is_connected}  = 0; 

}




sub dbh_obj {

    my $self = shift;
    carp "dbh_obj called."
      if $t;

    return undef 
		unless $self->{enabled};
	return $self->connectdb;
	
}



sub connectdb {

    my $self = shift;

    return undef unless $self->{enabled};

    carp "Connecting to DB..."
      if $t;

    my $dbh;
    my $data_source;

    if ( $dbtype eq 'SQLite' ) {

        $data_source =
          'dbi:' . $dbtype . ':' . $DADA::Config::FILES . '/' . $database;

        if ( $DADA::Config::DBI_PARAMS->{dada_connection_method} eq 'connect' )
        {
            $dbh = DBI->connect( "$data_source", "", "" )
              || croak("can't connect to db: $!");
        }
        elsif ( $DADA::Config::DBI_PARAMS->{dada_connection_method} eq
            'connect_cached' )
        {

            $dbh =
              DBI->connect_cached( "$data_source", "", "",
                { dada_private_via_process => $$ } )
              || croak("can't connect to db: $!");
        }
        else {
            croak "Incorrect dada_connection_method passed.";
        }

        for ( keys %{$DADA::Config::DBI_PARAMS} ) {
            next if $_ =~ m/dada/;

            #$self->{dbh}->{$_} = $DADA::Config::DBI_PARAMS->{$_};
            $dbh->{$_} = $DADA::Config::DBI_PARAMS->{$_};
        }


    }
    else {

        $data_source = "dbi:$dbtype:dbname=$database;host=$dbserver;port=$port";

        if ( $DADA::Config::DBI_PARAMS->{dada_connection_method} eq 'connect' )
        {

            #$self->{dbh} =
            $dbh = DBI->connect( "$data_source", $user, $pass )
              || croak("can't connect to db: $!");
        }
        elsif ( $DADA::Config::DBI_PARAMS->{dada_connection_method} eq
            'connect_cached' )
        {

            #$self->{dbh} =
            $dbh =
              DBI->connect_cached( "$data_source", $user, $pass,
                { dada_private_via_process => $$ } )
              || croak("can't connect to db: $!");
        }
        else {
            croak "Incorrect dada_connection_method passed.";
        }

        for ( keys %{$DADA::Config::DBI_PARAMS} ) {
            next if $_ =~ m/dada/;

            #$self->{dbh}->{$_} = $DADA::Config::DBI_PARAMS->{$_};
            $dbh->{$_} = $DADA::Config::DBI_PARAMS->{$_};
        }

        carp "Connected."
          if $t;

        $self->{is_connected} = 1;

    }

    return $dbh;

}





sub disconnectdb {
    my $self = shift;
    return undef unless $self->{enabled};

    carp "Disconnecting from DB..."
      if $t;

    $self->{dbh}->disconnect;
    $self->{is_connected} = 0;

    carp "Disconnected."
      if $t;

}





sub DESTROY { 


	my $self = shift;
		return undef unless $self->{enabled}; 

	carp "Destroying DADA::App::DBIHandle object..."
		if $t;

	if($self->{dbh}){ 
		$self->disconnectdb ; 
	}
	else{ 
	}
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
