#!/usr/bin/perl 

use CGI::Carp qw(fatalsToBrowser); 

use strict; 

use lib qw(
		./ 
		./DADA/perllib 
		../../ 
		../../DADA/perllib
	); 

use DADA::Config; 
use DADA::App::DBIHandle; 

my $dbi_obj = DADA::App::DBIHandle->new; 
my $dbh  = $dbi_obj->dbh_obj;

use CGI qw(:standard); 

use Data::Dumper; 

print header(); 

# Still have to see if this table exists, yet and if so - let's throw a warning up, 
#if there's any entries...

THREEOHCOMPAT::create_profile_tables();

# So, basically, since I now have the right schema, I can use my stuff: 

require DADA::ProfileFieldsManager; 
my $dpfm = DADA::ProfileFieldsManager->new; 

foreach(@{THREEOHCOMPAT::threeoh_subscriber_fields()}){ 
	$dpfm->add_field({-field => $_});
}
  
THREEOHCOMPAT::move_profile_info_over();


package THREEOHCOMPAT;
use CGI qw(:standard); 
use Carp qw(croak confess carp);

# ALl I need is the name of the fields I'm moving: 


sub create_profile_tables { 
	print pre("Yup! I have to do that one, still!"); 
}


sub move_profile_info_over { 

	my $query = 'INSERT INTO dada_profile_fields (email, ' . join(', ', @{threeoh_subscriber_fields()}) . ' )
	SELECT dada_subscribers.email,  '. join(', ', @{threeoh_subscriber_fields()}) .
	' FROM dada_subscribers GROUP BY dada_subscribers.email';
	my $sth = $dbh->prepare($query);
	$sth->execute() or croak $DBI::errstr; 
	$sth->dump_results; 


}


sub threeoh_columns { 
#	my $self = shift; 
	my $sth = $dbh->prepare("SELECT * FROM " . $DADA::Config::SQL_PARAMS{subscriber_table} ." where (1 = 0)");    
	$sth->execute() or confess "cannot do statement (at: columns)! $DBI::errstr\n";  
	my $i; 
	my @cols;
	for($i = 1; $i <= $sth->{NUM_OF_FIELDS}; $i++){ 
		push(@cols, $sth->{NAME}->[$i-1]);
	} 
	$sth->finish;
	return \@cols;
}




sub threeoh_subscriber_fields { 

   #my $self = shift;
    my ($args) = @_; 
    
	my $l = [] ;
	
	#if(exists( $self->{cache}->{subscriber_fields} ) ) { 
	#	$l = $self->{cache}->{subscriber_fields};
	#} 
	#else { 
    	# I'm assuming, "columns" always returns the columns in the same order... 
	    #$l = $self->columns;
	 $l = threeoh_columns();
	 #   $self->{cache}->{subscriber_fields} = $l; 
    #}


    if(! exists($args->{-show_hidden_fields})){ 
        $args->{-show_hidden_fields} = 1; 
    }
    if(! exists($args->{-dotted})){ 
        $args->{-dotted} = 0; 
    }
    
    
    # We just want the fields *other* than what's usually there...
    my %omit_fields = (
        email_id    => 1,
        email       => 1,
        list        => 1,
        list_type   => 1,
        list_status => 1
    );

    
    my @r;
    foreach(@$l){ 
    
        if(! exists($omit_fields{$_})){
    
            if($args->{-show_hidden_fields} == 1){ 
                if($args->{-dotted} == 1){ 
                    push(@r, 'subscriber.' . $_);
                }
                else { 
                    push(@r, $_);
                }
             }
             elsif($DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX eq undef){ 
                if($args->{-dotted} == 1){ 
                    push(@r, 'subscriber.' . $_);
                }
                else { 
                
                    push(@r, $_);
                }
             }  
             else { 
             
                if($_ !~ m/^$DADA::Config::HIDDEN_SUBSCRIBER_FIELDS_PREFIX/ && $args->{-show_hidden_fields} == 0){ 
                    if($args->{-dotted} == 1){ 
                        push(@r, 'subscriber.' . $_);
                    }
                    else { 
                
                        push(@r, $_);
                    }
                }
                else { 
                
                    # ... 
                }
            }
        }
    }
    
    return \@r;
}


sub threeoh_remove_subscriber_field { 

    #my $self = shift; 
    
	
    my ($args) = @_;
    if(! exists($args->{-field})){ 
        croak "You MUST pass a field name in, -field!"; 
    }
    $args->{-field} = lc($args->{-field}); 
    
    #$self->validate_remove_subscriber_field_name(
    #    {
    #    -field      => $args->{-field}, 
    #    -die_for_me => 1, 
    #    }
    #); 
   
        
    my $query =  'ALTER TABLE '  . $DADA::Config::SQL_PARAMS{subscriber_table} . 
                ' DROP COLUMN ' . $args->{-field}; 
    
    my $sth = $dbh->prepare($query);    
    
    my $rv = $sth->execute() 
        or croak "cannot do statement! (at: remove_subscriber_field) $DBI::errstr\n";   
 	
	# I don't know if I *really* want this to be done, 
	# $self->_remove_fallback_value({-field => $args->{-field}}); 
	
	return 1; 
	
}


