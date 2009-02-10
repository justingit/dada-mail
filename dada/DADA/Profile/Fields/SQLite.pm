package DADA::Profile::Fields::SQLite; 
use lib qw(./ ../ ../../ ../../../ ./../../DADA ../../perllib); 

use Carp qw(carp croak confess);
use DADA::App::Guts;
use base "DADA::Profile::Fields::baseSQL"; 
use strict; 

sub remove_subscriber_field { 

	warn "here in remove_subscriber_field for SQLite"; 
	
    my $self = shift; 
    
    my ($args) = @_;
    if(! exists($args->{-field})){ 
        croak "You must pass a field name in, -field!"; 
    }
    $args->{-field} = lc($args->{-field}); 
    
    $self->validate_remove_subscriber_field_name(
        {
        -field      => $args->{-field}, 
        -die_for_me => 1, 
        }
    ); 
   
       
    ###
    
    my %omit_fields = (
					 email       => 1,
                   );	
                   
        
    my @no_homers = (); 
    foreach(@{$self->subscriber_fields}){ 
        if($_ ne $args->{-field}){ 
            push(@no_homers, $_); 
        }      
    }
    my @keep_these_colums = @no_homers;
    my $keep_these_str = 'email, '; 
	my $make_these_str = ','; 
    foreach(@keep_these_colums){ 
        $keep_these_str .= $_ . ', ';
	}
    $keep_these_str =~ s/\, $//; 

	foreach(@no_homers){ 
		$make_these_str.= $_ . ' text, '; 
	}
	$make_these_str =~ s/\, $|,$//; 

#    CREATE TEMPORARY TABLE t1_backup(a,b);
#    INSERT INTO t1_backup SELECT a,b FROM t1;
#    DROP TABLE t1;
#    CREATE TABLE t1(a,b);
#    INSERT INTO t1 SELECT a,b FROM t1_backup;
#    DROP TABLE t1_backup;






    $self->{dbh}->do('BEGIN TRANSACTION')
 		or croak "cannot do statement $DBI::errstr\n";
    
	my $q2 = 'CREATE TEMPORARY TABLE ' . $self->{sql_params}->{profile_fields_table} . '_backup(fields_id INTEGER, email varchar(320) ' . $make_these_str .')';
	warn '$q2 ' . $q2;
	$self->{dbh}->do($q2)
		or croak "cannot do statement $DBI::errstr\n";

                            
    my $q3 = 'INSERT INTO ' . $self->{sql_params}->{profile_fields_table} .'_backup SELECT fields_id, ' . $keep_these_str .' FROM '   . $self->{sql_params}->{profile_fields_table};
    warn '$q3 ' . $q3;
	$self->{dbh}->do($q3)
		or croak "cannot do statement $DBI::errstr\n";
		
    $self->{dbh}->do('DROP TABLE ' . $self->{sql_params}->{profile_fields_table})
	 	or croak "cannot do statement $DBI::errstr\n";

    $self->make_table(); 
    
    foreach(@no_homers){ 
        $self->add_subscriber_field(
            {
                -field => $_, 
            }
        );
    }
 

    $self->{dbh}->do('INSERT INTO ' . $self->{sql_params}->{profile_fields_table} . ' SELECT fields_id, ' .  $keep_these_str . ' FROM ' .  $self->{sql_params}->{profile_fields_table} . '_backup')
		or croak "cannot do statement $DBI::errstr\n";

    $self->{dbh}->do('DROP TABLE '. $self->{sql_params}->{profile_fields_table} . '_backup')
 		or croak "cannot do statement $DBI::errstr\n";
    
    $self->{dbh}->do('COMMIT')
		or croak "cannot do statement $DBI::errstr\n";
    
    ###
    

	$self->_remove_fallback_value({-field => $args->{-field}}); 
	
	return 1; 
	
}



sub make_table { 

    my $self = shift; 
    
    $self->{dbh}->do(
	'CREATE TABLE ' . $self->{sql_params}->{profile_fields_table} . '( 
	fields_id			         INTEGER PRIMARY KEY AUTOINCREMENT,
	email                        varchar(320) not null UNIQUE)' 
	 )
		or croak "cannot do statement (at: make_table)! $DBI::errstr\n";      

}




1;
