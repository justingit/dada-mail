package DADA::Logging::Clickthrough::Db;

use lib qw(../../../ ../../../DADA/perllib); 


use base "DADA::App::GenericDBFile";
 

use strict; 



use AnyDBM_File; 
use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT 
O_CREAT 
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB); 
use Carp qw(croak carp); 


use DADA::Config qw(!:DEFAULT);  
use DADA::App::Guts;  # For now, my dear. 

sub new {

	my $class = shift;
	
	my ($args) = @_; 
	
					     
    my $self = SUPER::new $class (
    							  function => 'clickthrough',
    							 );  
         
       $self->{new_list} = $args->{-new_list};
	   $self->_init($args); 
	   
	   return $self;
}




sub add { 
	
    my $self    = shift; 
    my $mid     = shift; 
   	die 'no mid! ' if ! defined $mid; 
	my $url     = shift; 
	my $key     = $self->random_key(); 
	 
	require Text::CSV; 
	 my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	
	my $value = $self->encode_value($mid, $url);

	if($value){ 
		$self->_open_db; 
	    $self->{DB_HASH}->{$key} = $value;
	    $self->_close_db;	
	}

    return $key; 
	
}



sub parse_email { 
	
	
	my $self = shift; 
	my ($args) = @_; 

# Actually, I think they want dada-style args. Damn them!	
#	if(!exists($args->{-entity})){ 
#		croak "you MUST pass an -entity!"; 
#	}
	if(!exists($args->{-mid})){ 
		croak "you MUST pass an -mid!"; 
	}	
	
	# Massaging:
	$args->{-mid} =~ s/\<|\>//g;
	$args->{-mid} =~ s/\.(.*)//; #greedy
	
	
	# This here, is pretty weird: 
	
	require DADA::App::FormatMessages; 
    my $fm = DADA::App::FormatMessages->new(-yeah_no_list => 1);
	
	my $entity = $fm->entity_from_dada_style_args($args); 
	
	$entity = $self->parse_entity(
						{
							-entity => $entity,
							-mid    => $args->{-mid},
						}
					); 
	
	my $msg = $entity->as_string; 
   	
  	my ($h, $b) = split("\n\n", $msg, 2); 

	my %final = (
        $self->return_headers($h), 
        Body => $b,
    ); 

    return %final;

}


sub return_headers { 

	my $self = shift; 

	#get the blob
	my $header_blob = shift || "";

	#init a new %hash
	my %new_header;

	# split.. logically
	my @logical_lines = split /\n(?!\s)/, $header_blob;
 
	    # make the hash
	    foreach my $line(@logical_lines) {
	          my ($label, $value) = split(/:\s*/, $line, 2);
	          $new_header{$label} = $value;
	        }
	return %new_header; 

}



sub parse_entity { 

	my $self   = shift; 
	my ($args) = @_; 
	
    if(! exists($args->{-entity})){ 
	    croak 'did not pass an entity in, "-entity"!'; 
	}
    if(! exists($args->{-mid})){ 
	    croak 'did not pass a mid in, "-mid"!'; 
	}
		
	my @parts  = $args->{-entity}->parts;
	
	if(@parts){
		
		#print "we gotta parts?!\n";
		 
		my $i; 
		foreach $i (0 .. $#parts) {
			$parts[$i]= $self->parse_entity({%{$args}, -entity => $parts[$i] });
		}	
		
	}

	$args->{-entity}->sync_headers('Length'      =>  'COMPUTE',
						            'Nonstandard' =>  'ERASE');

	my $is_att = 0; 
	
	if (defined($args->{-entity}->head->mime_attr('content-disposition'))) { 
	    if ($args->{-entity}->head->mime_attr('content-disposition') =~ m/attachment/){
	       	$is_att = 1; 
			#print "is attachment?\n"; 
	    }
	}

	if(
	    (
	    ($args->{-entity}->head->mime_type eq 'text/plain') ||
		($args->{-entity}->head->mime_type eq 'text/html')
	  	) 
	    && 
	    ($is_att != 1)
	 ) {

		my $body    = $args->{-entity}->bodyhandle;
		my $content = $body->as_string;

		if($content){
			#print "Bang!\n"; 
			# Bang! We do the stuff here!
			$content = $self->parse_string($args->{-mid}, $content); 
		}
		else { 
			#print "no content to parse?!"; 
		}

		my $io = $body->open('w');
           $io->print( $content );
	       $io->close;
	}
	else { 

		#print "missed the block?!\n";
	}
  
	$args->{-entity}->sync_headers(
					  		'Length'      =>  'COMPUTE',
		  				    'Nonstandard' =>  'ERASE'
					  );


	return $args->{-entity};
		
}

	


sub parse_string { 
	
	my $self   = shift; 
	my $mid    = shift; 
	
	die 'no mid! ' if ! defined $mid; 
	
	my $str    = shift; 
	#carp "here's the string before: " . $str; 
	#
	$str    =~ s/\[redirect\=(.*?)\]/&redirect_encode($self, $mid, $1)/eg; 
	#	carp "here's the string: $str"; 
	return $str; 
}




sub redirect_encode { 

	my $self = shift; 
	my $mid  = shift; 
	die 'no mid! ' 
		if ! defined $mid; 
	my $url  = shift; 
		
	my $key = $self->reuse_key($mid, $url);
	
	if(!defined($key)){  
		$key = $self->add($mid, $url); 
	}
	
 	#	carp 'here it is: ' . $DADA::Config::PROGRAM_URL . '/r/' . $self->{name} . '/' . $key . '/'; 
	return $DADA::Config::PROGRAM_URL . '/r/' . $self->{name} . '/' . $key . '/'; 
	
}




sub reuse_key { 
	
	my $self = shift; 
	my $mid  = shift;
	die 'no mid! ' if ! defined $mid; 
	my $url  = shift; 
	
	my $value = $self->encode_value($mid, $url); 
	
	$self->_open_db;
	
	 while (my ($k, $v) = each(%{$self->{DB_HASH}})){
        	if($v eq $value) {
			 	$self->_close_db; 
				return $k;
			}
        }
	
	$self->_close_db; 
	return undef; 
	
}



sub fetch { 
	
	my $self = shift; 
	my $key  = shift; 
	die "no key! " if ! defined $key; 
	
	my $mid; 
	my $url; 
	my $saved_info;
	
	$self->_open_db;
	if(exists($self->{DB_HASH}->{$key})){ 
		$saved_info = $self->{DB_HASH}->{$key};
		$self->_close_db;
	}
	else { 
		$self->_close_db;	
		warn "No saved information for: $key"; 
		return (undef, undef);
		# ... 
	}
	
	my ($r_mid, $r_url) = $self->decode_value($saved_info); 
	
	return ($r_mid, $r_url); 
}



sub encode_value { 
	
	my $self = shift; 
	my $mid  = shift;
	die 'no mid! ' if ! defined $mid; 
	my $url  = shift; 
    my $value = undef; 

	 require Text::CSV; 
	 my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	
	 if ($csv->combine($mid, $url)) {
			$value =  $csv->string;
	 } else {
		
	 	croak "combine() failed on argument: ", $csv->error_input, "\n";

	 }	

	return $value; 
	
}



sub decode_value { 

	my $self = shift; 
	my $value  = shift; 
	
	die "no saved information! " if ! defined $value; 	
	
	 require Text::CSV; 
	 my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	
	if ($csv->parse($value)) {

        my @fields = $csv->fields;
		return ($fields[0], $fields[1]); 

    } else {
        croak $DADA::Config::PROGRAM_NAME . " Error: CSV parsing error: parse() failed on argument: ". $csv->error_input() . ' ' . $csv->error_diag ();;         
		return (undef, undef);
    }
	
	
	
}





sub random_key { 

	my $self = shift; 
	require DADA::Security::Password; 
	my $checksout = 0; 
	my $key       = undef; 
	
	$self->_open_db;
	
	while($checksout == 0){ 
		$key = DADA::Security::Password::generate_rand_string(1234567890, 12); 
		if(exists($self->{DB_HASH}->{$key})){ 
			# ...
		}
		else { 
			$checksout = 1; 
			last; 
		}
	}
		
	return $key; 
		
	$self->_close_db; 
	
}




sub _raw_db_hash { 
	my $self = shift; 
	$self->_lock_db;	
	$self->_open_db; 
	my %RAW_DB_HASH = %{$self->{DB_HASH}};
	$self->{RAW_DB_HASH} = {%RAW_DB_HASH};
	$self->_close_db;
	$self->_unlock_db; 	
}




sub _list_name_check { 

	my ($self, $n) = @_; 
		$n = $self->_trim($n);
	return 0 if !$n; 
	return 0 if $self->_list_exists($n) == 0;  
	$self->{name} = $n;
	return 1; 
}




sub _list_exists { 
	my ($self, $n)  = @_; 
	return DADA::App::Guts::check_if_list_exists(-List => $n);
}


1;


=pod

=head1 NAME

DADA::MailingList::Clickthrough::Db

=head1 VERSION

Fill me in!
 
=head1 SYNOPSIS

Fill me in!

=head1 DESCRIPTION

Fill me in !
 
=head1 SUBROUTINES/METHODS 

Fill me in!

=head1 DIAGNOSTICS

Fill me in!

=head1 CONFIGURATION AND ENVIRONMENT

Fill me in!

=head1 DEPENDENCIES


Fill me in!


=head1 INCOMPATIBILITIES

Fill me in!

=head1 BUGS AND LIMITATIONS

Fill me in!

=head1 AUTHOR

Fill me in!

=head1 LICENCE AND COPYRIGHT

Fill me in!

=cut




