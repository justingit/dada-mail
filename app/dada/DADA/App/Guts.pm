package DADA::App::Guts; 

use lib "../../";
use lib "../../DADA/perllib";
use lib "../../DADA/App/Support";
use lib './';
use lib './DADA/perllib';
use lib './DADA/App/Support';

use Carp qw(carp croak);
use DADA::Config qw(!:DEFAULT);  

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_Guts};

use Encode qw(encode decode);
use Try::Tiny; 

use Fcntl qw(
O_WRONLY 
O_TRUNC 
O_CREAT
O_RDWR
O_RDONLY
LOCK_EX
LOCK_SH 
LOCK_NB); 

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
  check_for_valid_email
  strip
  pretty
  ping_test
  partial_sending_query_to_params
  make_pin
  check_email_pin
  make_template
  delete_list_template
  delete_list_info
  check_if_list_exists
  available_lists
  num_file_lines
  fisher_yates_shuffle
  archive_message
  js_enc
  setup_list
  date_this
  html_to_plaintext
  convert_to_ascii
  e_print
  decode_he
  uriescape
  uriunescape
  lc_email
  make_safer
  encode_html_entities
  plaintext_to_html
  markdown_to_html
  
  check_list_setup
  
  message_id
  check_list_security
  user_error
  install_dir_around
  check_setup
  SQL_check_setup
  cased
  root_password_verification
  xss_filter
  isa_ip_address
  isa_url
  escape_for_sending
  entity_protected_str
  spam_me_not_encode
  break_encode
  anonystar_address_encode
  optimize_mime_parser
  gravatar_img_url
  perl_dehex
  csv_parse
  decode_cgi_obj
  safely_decode
  safely_encode
  slurp
  make_ua
  grab_url
  scrub_js
  md5_checksum
  can_use_LWP_Simple
  can_use_LWP_Protocol_https
  
  can_use_Google_reCAPTCHA
  can_use_Google_reCAPTCHA_v2
  can_use_Google_reCAPTCHA_v3
  
  can_use_Gravatar_URL
  
  validate_recaptcha
  can_use_XML_FeedPP
  can_use_JSON
  can_use_DateTime
  can_use_DateTime_Event_Recurrence
  can_use_HTML_Tree
  can_use_net_curl
  can_use_mozilla_ca
  can_use_Amazon_SES
  can_use_WebService_Mailgun
  can_use_StopForumSpam
  can_use_Image_Scale
  can_use_Image_Resize
  can_use_Image_Magick
  formatted_runtime
  pad_str
  commify
  generate_rand_string_md5
  
  ctime_to_localtime
  ctime_to_displaytime
  displaytime_to_ctime
  hms_to_dislay_hms
  display_hms_to_hms
  
  naive_csv_split
  
  ip_address_logging_filter
  anonymize_ip
  
  Email_Address_parse
  
  human_readable_filesize
	
   create_dir
	filename_from_url
	path_and_file
	simple_printout_file
  new_image_file_path
  
  can_use_www_engine
  
  
);



use strict; 
use vars qw(@EXPORT);


my $can_use_cache = {}; 


# evaluate these once at compile time
use constant HAS_URI_ESCAPE_XS => eval { require URI::Escape::XS; 1; }; # Much faster, but requires C compiler.
use constant HAS_URI_ESCAPE    => eval { require URI::Escape; 1; };

#use constant HAS_EMAIL_ADDRESS_XS => eval { require Email::Address::XS; 1; };
#use constant HAS_EMAIL_ADDRESS    => eval { require Email::Address; 1; };

=pod

=head1 NAME


DADA::App::Guts

=head1 SYNOPSIS 

 use DADA::App::Guts; 

=head1 DESCRIPTION 

This module holds commonly used subroutines for the variety of other modules
in Dada Mail. This module is slowly fading away, in favor of having much of
Dada Mail Object Oriented. There are some subroutines that are, in reality, 
just wrappers around the new, Object Oriented ways of doing things. They are
noted here.

=head1 SUBROUTINES

=cut









 



=pod

=head2 check_for_valid_email

	$e_test = check_for_valid_email($email_address); 

returns 1 if the email is invalid. 

But will return 0 if an email is invalid if you
specify that addres in the B<@DADA::Config::EMAIL_EXCEPTIONS> array in the Config file. Good for testing. 


=cut


sub check_for_valid_email {

    my $email = shift or undef;
    my $email_check = 0;
    if (   $email =~ m/\@/
        && $email !~ m/\r|\n/
        && $email !~ m/\s/ )
    {    # This is to weed out the obvious...
            # /BUGFIX
        require Email::Valid;
        if (
            defined(
                Email::Valid->address(
                    -address => $email,
                    -fudge   => 0,
                    -mxcheck => 0,
                )
            )
          )
        {
            $email_check = 0;
        }
        else {

            $email_check = 1;
        }
    }
    else {
        $email_check = 1;
    }

    my %exceptions;
    for (@DADA::Config::EMAIL_EXCEPTIONS) {
        $exceptions{$_}++;
    }
    $email_check = 0 if exists( $exceptions{$email} );
    return $email_check;

}

=pod

=head2 strip

	my $str = strip($str);  
  
a simple subroutine to take off leading and trailing white spaces

=cut

sub strip {
    my $string = shift;
    if (defined($string)) {
        $string =~ s/^\s+//o;
        $string =~ s/\s+$//o;
        return $string;
    }
    else {
        return undef;
    }
}


=pod

=head2 pretty

	$str = pretty($str); 

a simple subroutine to turn underscores to whitespace

=cut

sub pretty { 
	my $string = shift ||undef; 

	if($string){ 
		$string =~ s/_/ /gio; 
		return $string; 
	}else{ 
		return undef;
	}

}


sub ping_test { 
	
	my $host = shift; 
	my $port = shift; 
	
	my $status = 1; 
	try {
		require Net::Ping;
	} catch { 
		$status = 0; 
		return (1, "Net::Ping not available.");
	};
	
	my $timeout = 60;
	my $p = Net::Ping->new("tcp");
	   $p->port_number($port);

	# perform the ping
	if( $p->ping($host, $timeout) )
	{
		$p->close();
	    return(1, "Host $host successfully pinged at port $port.");
	}
	else {
		$p->close();
        return(0, "Host $host could not be  pinged at port $port. Outbound port may be blocked, or host is down at specified port");
	}

}





sub partial_sending_query_to_params {
    my $q               = shift;
    my $fields          = shift || undef;
    my $partial_sending = {};

    if ( !defined($fields) ) {
        require DADA::ProfileFieldsManager;
        $fields = DADA::ProfileFieldsManager->new->fields;
    }
    unshift( @$fields, 'email' );

    for my $field (@$fields) {
        my $op = $q->param( $field . '.operator' );
        my $v  = $q->param( $field . '.value' );
        my $n  = $field;
        if ( $op =~ m/^(\=|\!\=|LIKE|NOT LIKE)$/ ) {
            $partial_sending->{$n} = {
                -operator => $op,
                -value    => $v,
            };
        }
    }

    if ( defined( $q->param('subscriber.timestamp.rangestart') ) 
      || defined ($q->param('subscriber.timestamp.rangeend') ) ) {
        if ( $q->param('subscriber.timestamp.rangestart') ne '' ) {
            my $s  = $q->param('subscriber.timestamp.rangestart');
            my $e  = $q->param('subscriber.timestamp.rangeend');
            # if(yup, looks like a date, to me!) { 
                $partial_sending->{'subscriber.timestamp'} = {
                    -rangestart  => $s,
                    -rangeend    => $e,
                    -value       => 'dummy value', 
                };
            #}
        }
    }
    
    return $partial_sending;
}




=pod

=head2 make_pin 

	$pin = make_pin(-Email => $email); 

Returns a pin number to validate subscriptions 

You can change how the pin number is generated a few ways;

There are two variables in the Config.pm file called the $DADA::Config::PIN_WORD  and the $DADA::Config::PIN_NUM , 
they'll change the outcome of $pin, The algorithym to make a pin number isn't 
that sophisticated, I'm not trying to keep a nuclear submarine from launching its missles, 
although if you create your own $DADA::Config::PIN_NUM  and $DADA::Config::PIN_WORD , it'll be pretty hard to decipher 
6230 from justin@example.com 

=cut




sub make_pin {
	my %args = ( 
	-Email      => undef, 
	-List       => undef, 
	-crypt      => 1, 
	@_
	); 
	
	
	my $email = $args{-Email} || undef;
	my $list  = $args{-List}  || undef; 
	my $pin = 0; 
	
	if($email){ 
	
		$email = cased($email); 
		
		# theres probably a better way to do this, but a mathematician 
		# I am not. 
		
		# make a pin by getting the ASCII values of the string? 
		# I forget exactly how this works, and I'm sick, but 
		# It gives me a bunch of numbers and does it the same each time, 
		# Like Isaid, I aint no mathemagician. 
		$pin = unpack("%32C*", $email);
		
		# do the same with some word you pick 
		my $pin_helper = unpack("%32C*", ($DADA::Config::PIN_WORD . $list) );
		 
		# make the pin by adding the $pin and $DADA::Config::PIN_NUM ber together, 
		# multiplying by a number you can pick 
		# and subtract that number by the $pin helper. 
		
		$pin = ((($pin + $pin_helper) * $DADA::Config::PIN_NUM ) - $pin_helper); 
				
		if($args{'-crypt'} == 1){ 
			require DADA::Security::Password; 

			
			# DEV: 
			# This gets slashed out of the an encrypted pin. 
			# Kind of messy. Better to do it, another way. 

			my $looks_good = 0; 
			my $limit      = 100; 
			my $enc        = undef;
				
			while($looks_good == 0){ 
				$enc =  DADA::Security::Password::encrypt_passwd($pin); 
				# Slash! Period!
				if($enc =~ m/\/|\./){ 
					# If the salt is the same, the new encrypted password
					# will *also* be the same. Not good! 
					# Change that up: 
					my @C=('a'..'z', 'A'..'Z', '0'..'9','.');
					$DADA::Config::SALT=$C[rand(@C)].$C[rand(@C)];
					$limit --; 
					if($limit <= 0){ 
						die "I couldn't figure it out. Sorry, man."; 
					}
					# ... 
				}
				else { 
					$looks_good = 1; 
				}
			}
			return $enc; 
		}
		else { 
			return $pin;
		}
	}else{ 
	
		return undef;
	
	}
}

=pod

=head2 check_email_pin

	my $check = check_email_pin(-Email=>$email, -Pin=> $pin);  

checks a given e-mail with the given pin, 
returns 0 on when the pin is VALID (Weird, yes?), 1 on FAILURE. 

=cut

sub check_email_pin {

    my %args = (
        -Email => undef,
        -List  => undef,
        -Pin   => undef,
        @_
    );

    my $email = $args{ -Email } || undef;
    my $list  = $args{ -List }  || undef;
    my $pin   = $args{ -Pin }   || undef;
    my $check = 0;

	require DADA::Security::Password; 
	
    if (   defined($pin)
        && defined($email) )
    {
		my $unencrypted_pin = make_pin( 
			-Email => $email, 
			-List  => $list, 
			-crypt => 0,
		 );
		
        if ( DADA::Security::Password::check_password($pin, $unencrypted_pin) == 1) {
            return 1;
        }
        else {
            return 0;
        }
    }	
	else {
    	return 0;
    }
}



=pod

=head2 make_template


	make_template({ 
	              -List     => $list, 
	              -Template => $template
	             });

takes where you want the template to be saved, 
the list that this template belongs to and the actual data to be saved in the 
template and saved this to a file. Usually, a template file is made when a 
list is created, using either the default Dada Mail template. 

Templates are stored in the $DADA::Config::TEMPLATES  directory (which is usually set the same as $DADA::Config::FILES)
under the name $listname.template, where $listname is the List's shortname.

=cut

sub make_template { 

    my ($args) = @_;

    if ( !$args->{-List} ) {
        carp
            "You need to supply a List make_template({-List => your_list}) in the parameters.";
        return undef;
    }
    
    if ( !$args->{-Template} ) {
        carp
            "You need to supply a Template make_template({-Template => your_list}) in the parameters.";
        return undef;
    }

	
	#get the variable
	my $print_template = $args->{-Template};
	my $list_path = $DADA::Config::TEMPLATES;
	my $list_template = $args->{-List} || undef; 
	
	
	if($list_template){ 
		#untaint 
		$list_template = make_safer($list_template); 
		$list_template =~ /(.*)/; 
		$list_template = $1; 
	
	
		open(TEMPLATE, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $list_path .'/' . $list_template . '.' . 'template') or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't write new template at '$list_path/$list_template.template': $!"; 
	
		flock(TEMPLATE, LOCK_EX) or 
			croak "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: can't lock to write new template at '$list_path/$list_template.template': $!" ; 
		
		print TEMPLATE $print_template;
		
		close(TEMPLATE); 
	
	    chmod($DADA::Config::FILE_CHMOD , "$list_path/$list_template.template"); 

	}else{ 	
			carp('$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: no list name was given to save new template');
			return undef;
	}
}



=pod

=head2 delete_list_template

	delete_list_template({ -List => $list }); 


deletes a template file for a list. 

=cut

sub delete_list_template { 

    my ($args) = @_;

     if ( !$args->{-List} ) {
        carp
            "You need to supply a List make_template({-List => your_list}) in the parameters.";
        return undef;
    }
    

    my $list = $args->{-List} || undef; 
    
     $list = make_safer($list); 
     $list =~ /(.*)/; 
     $list = $1;              
     my $deep_six = $DADA::Config::TEMPLATES . '/' . $list . '.template';
     
     if(-e $deep_six){ 
     
         my $n = unlink($deep_six); 
         
         if($n == 0){
            carp $deep_six . " didn't go quietly"; 
            return 0; 	
         } else { 
            return 1; 
         }
    } else {
       # It's actually "OK" if there's no template. 
       #carp 'No template at ' . $deep_six . ' to remove!'; 
        return 1; 
    }

}




=pod

=head2 delete_list_info

	delete_list_info(-List => $list); 

deletes the db file for a list. 

=cut

sub delete_list_info { 

	my %args = ( 
	-List      => undef, 
	@_);
	
	my $list  = $args{-List} || undef; 
	
	if($list){ 
	
		# DEV: This is really bad form - do not emulate!
	
		if($DADA::Config::SETTINGS_DB_TYPE =~ /SQL/i){ 
		
			require DADA::App::DBIHandle; 
	    	my $dbi_handle = DADA::App::DBIHandle->new; 
			my $dbh = $dbi_handle->dbh_obj; 
		
			my $query = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{settings_table} .' WHERE list = ?'; 
			my $sth = $dbh->prepare($query);
			   $sth->execute($list); 
		       $sth->finish; 
		       
		}else {
		
			my $deep_six;
	
	
			opendir(LISTS, $DADA::Config::FILES) or croak "can't open '$DADA::Config::FILES' to read: $!";
			while(defined($deep_six = readdir LISTS)) {
				#don't read '.' or '..'
				next if $deep_six =~ /^\.\.?$/; 
				if(($deep_six =~ m/mj-$list\.(.*)/) || ($deep_six =~ m/(mj-$list)$/)) { 
					 
					 $deep_six = make_safer($deep_six); 
					 $deep_six =~ /(.*)/; 
					 $deep_six = $1;
	
					 unlink("$DADA::Config::FILES/$deep_six"); 
				} 
			 }
		}
	}else{ 
		carp('$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error: No list name given to delete list database');
		return undef;
	}
}


=pod

=head2 check_if_list_exists

	check_if_list_exists(-List => $list, ); 

checks to see if theres a filename called $list
returns 1 for success, 0 for failure. 

=cut

sub list_exists { 
	return check_if_list_exists(@_);
}

sub check_if_list_exists { 
	
	my %args = (
				-List       => undef, 
	            -Dont_Die   => 0, 
				@_
				); 
				
	my $list_exists = 0;
	
	if(! exists($args{-List})){ 
		return 0; 
	}
	
	if(! defined($args{-List})){ 
		return 0; 
	}
	
	my @available_lists = available_lists(
			-Dont_Die   => $args{-Dont_Die},
		);
	
	my $might_be;
	for $might_be(@available_lists) {
		if ($might_be eq $args{-List}) { 
		  $list_exists = 1;
		  last; 
		}    
 	}
 	return $list_exists; 
}

=pod

=head2 available_lists

	my @lists = available_lists();

return an array containing the listshortnames of available list. 

Can take a few parameters - all are optional: 

=over

=item * -As_Ref

returns a reference to an array, instead of an array

=item * -In_Order

returns the array in alphabetic order - but B<NOTE:> not in alphabetical order based on the listshortnames, but of the actual list names. 

=item * -Dont_Die

As the name implies, the subroutine won't kill the program calling it, if there's a problem opening the directory you've set in the Config.pm B<$FILES> variable. 
 

=back

Using all these parameters at once would look something like this: 

 my $available_lists = available_lists(
                                        -As_Ref => 1, 
                                        -In_Order => 1, 
                                        -Dont_Die => 1, 
                                       );


=cut

my $cache = {};
sub available_lists {
    my %args = @_; 

	if(!exists($args{-As_Ref})){ 
		$args{-As_Ref} = 0; 
	}
	
	if(!exists($args{-In_Order})){ 
		$args{-In_Order} = 0; 
	}
	
	if(!exists($args{-In_Random_Order})){ 
		$args{-In_Random_Order} = 0; 
	}
	 
	if(!exists($args{-Dont_Die})){ 
		$args{-Dont_Die} = 0; 
	}
	
	if(!exists($args{-clear_cache})){ 
		$args{-clear_cache} = 0; 
	}
		
	
	if(!exists($args{-return_hidden_lists})){ 
		$args{-return_hidden_lists} = 1; 
	}
	
	
    my $in_order        = $args{-In_Order};
    my $want_ref        = $args{-As_Ref};
    my @dbs             = ();
    my @available_lists = ();
    my $present_list    = undef;


# BUGFIX:  2222381  	 3.0.0 - DADA::App::Guts::available_lists() needs caching
# https://sourceforge.net/tracker2/?func=detail&aid=2222381&group_id=13002&atid=113002
#
# Caching.
    if ( $args{-clear_cache} == 1 ) {

        # This is completely over the top, but...
        for ( keys %$cache ) {
            $cache->{$_} = undef;
            delete( $cache->{$_} );
        }
        $cache = undef;
        $cache = {};
    }
    
	if ( $in_order == 1 && $args{-return_hidden_lists} != 0) {
        if ( exists( $cache->{available_lists_in_order} ) ) {
            #$ic++; carp "CACHE! $ic++";
            $want_ref == "1"
              ? return $cache->{available_lists_in_order}
              : return @{ $cache->{available_lists_in_order} };
        }
    }
	elsif($args{-return_hidden_lists} == 0){ 
		# ...
	}
    else {
        if ( exists( $cache->{available_lists} ) ) {
			my $copy = $cache->{available_lists};
			if($args{-In_Random_Order} == 1) { 
				
				fisher_yates_shuffle($copy); 
				$want_ref == "1"
				? return $copy
				: return @$copy;
				
			}
			else { 
				$want_ref == "1"
				? return $cache->{available_lists}
				: return @{ $cache->{available_lists} };
			}
        }
    }

# /Caching.


    my $dbi_handle = undef;
	my $sth        = undef; 
    eval {
		require DADA::App::DBIHandle;
        $dbi_handle = DADA::App::DBIHandle->new;
        my $dbh     = $dbi_handle->dbh_obj;

        my $query = 'SELECT DISTINCT list from '
          . $DADA::Config::SQL_PARAMS{settings_table} 
		  . " WHERE list != ? AND setting = 'list'";

        if ( $in_order == 1 ) {
            $query .= ' ORDER BY list ASC';
        }
        $sth = $dbh->prepare($query);
        $sth->execute('') or croak; 
	};

	# BUGFIX:
	# 2219954  	 3.0.0 - Guts.pm sub available_lists param, -Dont_Die broken
	# https://sourceforge.net/tracker2/?func=detail&aid=2219954&group_id=13002&atid=113002
    if ($@) {
        if ( $args{-Dont_Die} == 1 ) {
            carp $DBI::errstr;
            $want_ref == "1" ? return [] : return ();
        }
        else {
            croak $DBI::errstr;
        }
    }
    else {

        while ( ( my $l ) = $sth->fetchrow_array ) {
            push( @available_lists, $l );
        }
        $sth->finish;
    }


	
	
	
	if($args{-return_hidden_lists} == 0){ 
        my @no_hidden = (); 
		for my $l (@available_lists) {
		 require DADA::MailingList::Settings; 
			my $ls = DADA::MailingList::Settings->new( { -list => $l } );
			if($ls->param('hide_list') == 0){ 
				push(@no_hidden, $l);
			}
		}
		@available_lists = @no_hidden; 
	}

    if ( $in_order == 1) {
         my $labels = {};
         for my $l (@available_lists) {
			 require DADA::MailingList::Settings; 
             my $ls =
               DADA::MailingList::Settings->new( { -list => $l } );
             my $li = $ls->get;
             $labels->{$l} = $li->{list_name};
         }
         @available_lists =
           sort { uc( $labels->{$a} ) cmp uc( $labels->{$b} ) }
           keys %$labels;
		  
		  if($args{-return_hidden_lists} != 0){
			 $cache->{available_lists_in_order} = \@available_lists;
	         $cache->{available_lists}          = \@available_lists;
	  	 }
		
		 $want_ref == "1" ? return \@available_lists : return @available_lists;
     }
	else { 
	    
		if($args{-return_hidden_lists} != 0){
			$cache->{available_lists} = \@available_lists;
		}
		if($args{-In_Random_Order} == 1) {
			my $copy = \@available_lists;
			fisher_yates_shuffle($copy); 
			$want_ref == "1" ? return $copy : return @$copy;
		}
		else { 
			$want_ref == "1" ? return \@available_lists : return @available_lists;
		}		
	}
}


sub num_file_lines { 
    my $filename = shift; 

    $filename = uriescape($filename);
    $filename =~ s/\s/%20/g;

    my $count = 0;


    open my($fh), '<:raw', make_safer($DADA::Config::TMP . '/' . $filename) or die "Can't open $filename: $!";
    while( <$fh> ) { $count++; }
    close($filename); 
    return $count; 
}




sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
	if(scalar(@$array) > 1){ 
	    for ($i = @$array; --$i; ) {
	        my $j = int rand ($i+1);
	        next if $i == $j;
	        @$array[$i,$j] = @$array[$j,$i];
	    }
	}
}


     

=pod

=head2 date_this

	my $readable_date =	date_this($packed_date)


this takes a packed date, say, the key of an archive 
entry and transforms it into an html data. 
the date is packed as

yyyymmdd

where, yyyy is the year in this form: 2000 
       mm   is the month in this form: 01 
       dd is the day in this for       31

it returns something that looks like this:

	<i>Sent January 1st, 2001</i>



=cut


sub date_this { 

	# dates look ike this: 
	# 20001209154914
	# 2000#12#09#15#49#14
	
	
	my %args = (
	 -Packed_Date   => undef,
	 -Write_Month   => 1,
	 -Write_Day     => 1,
	 -Write_Year    => 1,
	 -Write_H_And_M => 0,
	 -Write_Second  => 0,
	 -All           => 0,
	@_,
	); 



	if($args{-All} == 1){ 
		$args{-Write_Month}   = 1, 
		$args{-Write_Day}     = 1,
		$args{-Write_Yearl}   = 1, 
		$args{-Write_H_And_M} = 1,
		$args{-Write_Second}  = 1;
	} 

	my $packed_date = $args{-Packed_Date} || undef; 
	
	if($packed_date) { 
	
	
		my $year      = substr($packed_date, 0,  4)   || "";
		my $num_month = substr($packed_date, 4,  2)   || ""; 
		my $day       = substr($packed_date, 6,  2)   || "";
		my $hour      = substr($packed_date, 8,  2)   || "";
		my $minute    = substr($packed_date, 10, 2)   || ""; 
		my $second    = substr($packed_date, 12, 2)   || "";
		my $ending    = "a.m."; 
		
		
		if($hour < 10){ 
			$hour = $hour/1; 
			$hour = 12 if $hour == 0; 
		}
		if($hour > 12){ 
			$hour = $hour - 12; 
			$ending = "p.m.";
		}
		
		
		
		
		my %months = (
		'01'   => "January",
		'02'   => 	"February",
		'03'   => 	"March",
		'04'   => 	"April",
		'05'   =>	"May",
		'06'   =>	"June",
		'07'   =>	"July",
		'08'   =>	"August",
		'09'   =>	 "September",
		'10'   => 	"October",
		'11'   => 	"November",
		'12'   => 	"December"
		);
		
		
		my %end = (
		'01'   => "1st",
		'02'   => 	"2nd",
		'03'   => 	"3rd",
		'04'   => 	"4th",
		'05'   =>	"5th",
		'06'   =>	"6th",
		'07'   =>	"7th",
		'08'   =>	"8th",
		'09'   =>	"9th",
		'10'   => 	"10th",
		'11'   => 	"11th",
		'12'   => 	"12th",
		'13'   =>   "13th",
		'14'   =>   "14th", 
		'15'   =>   "15th", 
		'16'   =>   "16th", 
		'17'   =>   "17th",
		'18'   =>   "18th", 
		'19'   =>   "19th", 
		'20'   =>   "20th", 
		'21'   =>   "21st", 
		'22'   =>   "22nd", 
		'23'   =>   "23rd",
		'24'   =>   "24th", 
		'25'   =>   "25th", 
		'26'   =>   "26th", 
		'27'   =>   "27th", 
		'28'   =>   "28th", 
		'29'   =>   "29th", 
		'30'   =>   "30th", 
		'31'   =>   "31st", 
		);
		
		my $date = ""; 
		   $date .= "$months{$num_month} "   if $args{-Write_Month}   == 1; 
		   $date .= "$end{$day} "            if $args{-Write_Day}     == 1; 		
		   $date .= "$year "                 if $args{-Write_Year}    == 1; 
		   $date .= "$hour:$minute"          if $args{-Write_H_And_M} == 1; 
		   $date .= ":$second "              if $args{-Write_Second}  == 1; 
		   $date .= "$ending"              if $args{-Write_H_And_M} == 1; 
		
		return $date; 
		
	}
}




sub html_to_plaintext {

    my ($args) = @_;

	if(! exists($args->{-for_blurb})){ 
		$args->{-for_blurb} = 0; 
	}
	# warn 'in html_to_plaintext';
    #warn '$args->{-str}:' . $args->{-str}; 
	
    if ( !exists( $args->{-str} ) ) {
        croak
"You need to pass the string you want to convert in the, '-str' param!";
    }
	
	
    if ( !exists( $args->{-formatter_params} ) ) {
        $args->{-formatter_params} = {
            before_link =>  '<!-- tmpl_var LEFT_BRACKET -->%n<!-- tmpl_var RIGHT_BRACKET -->',
            footnote    => '<!-- tmpl_var LEFT_BRACKET -->%n<!-- tmpl_var RIGHT_BRACKET --> %l',
			    leftmargin => 0, rightmargin => 1000000000000
        };
    }

    # I'm not sure what sort of other arguments I want, but...

    my $formatted = undef;
    my $hftwl     = 1;

# Removing comments is a good thing, removing template tags that look like comments is a bad thing:


$args->{-str} =~ s/\<body style\=\"(.*?)\"\>/<body>\n/gi;
$args->{-str}  =~ s/\<style\>(.*?)\<\/style\>/\n/gi;


    my ( $mask_beginning_comment, $mask_ending_comment, $tmp_str ) = 
		_hide_tmpl_tags( );
		
		
    my $mask_beginning_comment_qm = quotemeta($mask_beginning_comment);
    my $mask_ending_comment_qm    = quotemeta($mask_ending_comment);
    try {

		my $f = undef; 
		if($args->{-for_blurb} == 1){ 
			
		#	try { 
		 #       require HTML::FormatText; 
		#		$f = HTML::FormatText->new( %{ $args->{-formatter_params} } );
		#		$formatted = $f->format_string($tmp_str) 
		#	} catch { 
		#		#warn $_; 
				$formatted = undef; 
		#	};
		}
		else { 
			
			try { 
				# This is a memory hog: 
		       require HTML::FormatText::WithLinks;
		   	    $f = HTML::FormatText::WithLinks->new( %{ $args->{-formatter_params} } );
				$formatted = $f->parse($tmp_str) 
			} catch { 
				#warn $_; 
				$formatted = undef; 
			};
		}
		  
        if ($formatted) {
			
			undef($f);
			
            $formatted =~ s/$mask_beginning_comment_qm/</g;
            $formatted =~ s/$mask_ending_comment_qm/>/g;

			# These are bad: 
			$formatted =~ s/(\n|\r)\s+\-\-\>/-->/gi;
			$formatted =~ s/\<\!\-\-(\n|\r)\s+/<!--/gi; 
			$formatted =~ s/tmpl_if\n(\s+)expr/tmpl_if expr/gi; 
			$formatted =~ s/\|\|\n(\s+)/||/gi; 
			
			
        } else {
			
            carp $DADA::Config::PROGRAM_NAME . ' '
              . $DADA::Config::VER
              . ' warning: Something went wrong with the HTML to PlainText conversion: '
              . $f->error;
            $formatted = convert_to_ascii( _chomp_off_body( $args->{-str} ) );
            $formatted =~ s/$mask_beginning_comment_qm/</g;
            $formatted =~ s/$mask_ending_comment_qm/>/g;
        }
    } catch {
        $hftwl = 0;
        warn 'HTML to Plaintext conversion with HTML::FormatText::WithLinks not successful - falling back to convert_to_ascii()' if $t; 
   };
	
	
	

    if ( $hftwl == 0 ) {
		
        my $pt = _chomp_off_body( $args->{-str} );
        $pt = convert_to_ascii($pt);
		$pt =~ s/$mask_beginning_comment_qm/</g;
        $pt =~ s/$mask_ending_comment_qm/>/g;
		
        return $pt;
    }
    else {
		
        return $formatted;
    }

}







sub _hide_tmpl_tags {

    my $str = shift;

    require DADA::Security::Password;

    my $ran_str = DADA::Security::Password::generate_rand_string();

    my $b1 = quotemeta('<!--');
    my $e1 = quotemeta('-->');

    my $b2 = quotemeta('<');
    my $e2 = quotemeta('>');

    my $mask_beginning_comment    = '[--' . $ran_str . 'DM_TMP';
    my $mask_beginning_comment_qm = quotemeta($mask_beginning_comment);

    my $mask_ending_comment    = 'DM_TMP' . $ran_str . '--]';
    my $mask_ending_comment_qm = quotemeta($mask_ending_comment);

    $str =~
s{$b1(\s*tmpl_(.*?)\s*)($e1|$e2)}{$mask_beginning_comment\!-- tmpl_$2 \-\-$mask_ending_comment}gi;
    $str =~
s{$b2(\s*tmpl_(.*?)\s*)($e1|$e2)}{$mask_beginning_comment\tmpl_$2$mask_ending_comment}gi;
    $str =~
s{$b1(\s*/tmpl_(.*?)\s*)($e1|$e2)}{$mask_beginning_comment\!-- /tmpl_$2\-\-$mask_ending_comment}gi;
    $str =~
s{$b2(\s*/tmpl_(.*?)\s*)($e1|$e2)}{$mask_beginning_comment/tmpl_$2$mask_ending_comment}gi;

    return ( $mask_beginning_comment, $mask_ending_comment, $str );

}




sub _chomp_off_body {
    my $str   = shift;
    my $n_str = $str;

    if ( $n_str =~ m/\<body.*?\>|<\/body\>/i ) {
        $n_str =~ m/\<body.*?\>([\s\S]*?)\<\/body\>/i;
        $n_str = $1;

        #$n_str = strip($n_str);
        if ( $n_str =~ m/\<body.*?\>/ ) {    #seriously?

            $n_str =~ s/\<body/\<x\-body/g;
            $n_str =~ s/\<\/body/\<\/x-body/g;
        }
    }

    if ( !$n_str ) {
        return $str;
    }
    else {
        return $n_str;
    }
}

=pod

=head2 convert_to_ascii

	$string = convert_to_ascii($string); 

takes a string and dumbly strips out HTML tags, 

=cut
 


sub convert_to_ascii {

    my $message_body = shift;

    # These things are sort of dumb.
    $message_body =~ s/<title>//gi;
    $message_body =~ s/<\/title>//gi;
    $message_body =~ s/<b>|<\/b>/\*/gi;
    $message_body =~ s/<i>|<\/i>/\//gi;
    $message_body =~ s/<u>|<\/u>/_/gi;
    $message_body =~ s/<li>/\[\*\]/g;
    $message_body =~ s/<\/li>/\n/g;

    $message_body = remove_html_comments($message_body);
    $message_body = remove_html_tags($message_body);

# Um! There's HTML::EntitiesPurePerl and also the Best.pm module. Let's... do something about that.
# Don't I ship with HTML::Entities?!
# HTML::EntitiesPurePerl is mine is sort of silly... grr!
# Although decode_entities is PP in HTML::Entities anyways. Sigh.

    try {
        require HTML::Entities;
        $message_body = HTML::Entities::decode_entities($message_body);
    }
    catch {
        $message_body = oldschool_decode_entities($message_body);
    };

    # And then, this?
    $message_body =~ s/\n(\s*)\n(\s*)\n/\n/gi;
    $message_body =~ s/^\s\s\s//mgi;

    return $message_body;

}





sub remove_html_comments { 
	my $s = shift; 
	$s =~ s{ <!                   # comments begin with a `<!'
	                         # followed by 0 or more comments;
	     (.*?)		# this is actually to eat up comments in non 
	 			# random places

	      (                  # not suppose to have any white space here

	                         # just a quick start;
	       --                # each comment starts with a `--'
	         .*?             # and includes all text up to and including
	       --                # the *next* occurrence of `--'
	         \s*             # and may have trailing while space
	                         #   (albeit not leading white space XXX)
	      )+                 # repetire ad libitum  XXX should be * not +
	     (.*?)		# trailing non comment text
	    > # up to a `>'
	 }{
	     if ($1 || $3) {	# this silliness for embedded comments in tags
	 	"<!$1 $3>";
	     } 
	 }gesx;                 # mutate into nada, nothing, and niente
	return $s; 
}

sub remove_html_tags { 
	my $s = shift; 
	$s =~ s{ < # opening angle bracket
     (?:                 # Non-backreffing grouping paren
          [^>'"] *       # 0 or more things that are neither > nor ' nor "
             |           #    or else
          ".*?"          # a section between double quotes (stingy match)
             |           #    or else
          '.*?'          # a section between single quotes (stingy match)
     ) +                 # repetire ad libitum
                         #  hm.... are null tags <> legal? XXX
    > # closing angle bracket
 }{}gsx;                 # mutate into nada, nothing, and niente
	
	return $s; 
 
}

sub oldschool_decode_entities { 
	my $s = shift; 
		# thar be old, crufty code
		 my %entity = (
	 
			 lt     => '<',     #a less-than
			 gt     => '>',     #a greater-than
			 amp    => '&',     #a nampersand
			 quot   => '"',     #a (verticle) double-quote
	 
			 nbsp   => chr(160), #no-break space
			 iexcl  => chr(161), #inverted exclamation mark
			 cent   => chr(162), #cent sign
			 pound  => chr(163), #pound sterling sign CURRENCY NOT WEIGHT
			 curren => chr(164), #general currency sign
			 yen    => chr(165), #yen sign
			 brvbar => chr(166), #broken (vertical) bar
			 sect   => chr(167), #section sign
			 uml    => chr(168), #umlaut (dieresis)
			 copy   => chr(169), #copyright sign
			 ordf   => chr(170), #ordinal indicator), feminine
			 laquo  => chr(171), #angle quotation mark), left
			 not    => chr(172), #not sign
			 shy    => chr(173), #soft hyphen
			 reg    => chr(174), #registered sign
			 macr   => chr(175), #macron
			 deg    => chr(176), #degree sign
			 plusmn => chr(177), #plus-or-minus sign
			 sup2   => chr(178), #superscript two
			 sup3   => chr(179), #superscript three
			 acute  => chr(180), #acute accent
			 micro  => chr(181), #micro sign
			 para   => chr(182), #pilcrow (paragraph sign)
			 middot => chr(183), #middle dot
			 cedil  => chr(184), #cedilla
			 sup1   => chr(185), #superscript one
			 ordm   => chr(186), #ordinal indicator), masculine
			 raquo  => chr(187), #angle quotation mark), right
			 frac14 => chr(188), #fraction one-quarter
			 frac12 => chr(189), #fraction one-half
			 frac34 => chr(190), #fraction three-quarters
			 iquest => chr(191), #inverted question mark
			 Agrave => chr(192), #capital A), grave accent
			 Aacute => chr(193), #capital A), acute accent
			 Acirc  => chr(194), #capital A), circumflex accent
			 Atilde => chr(195), #capital A), tilde
			 Auml   => chr(196), #capital A), dieresis or umlaut mark
			 Aring  => chr(197), #capital A), ring
			 AElig  => chr(198), #capital AE diphthong (ligature)
			 Ccedil => chr(199), #capital C), cedilla
			 Egrave => chr(200), #capital E), grave accent
			 Eacute => chr(201), #capital E), acute accent
			 Ecirc  => chr(202), #capital E), circumflex accent
			 Euml   => chr(203), #capital E), dieresis or umlaut mark
			 Igrave => chr(204), #capital I), grave accent
			 Iacute => chr(205), #capital I), acute accent
			 Icirc  => chr(206), #capital I), circumflex accent
			 Iuml   => chr(207), #capital I), dieresis or umlaut mark
			 ETH    => chr(208), #capital Eth), Icelandic
			 Ntilde => chr(209), #capital N), tilde
			 Ograve => chr(210), #capital O), grave accent
			 Oacute => chr(211), #capital O), acute accent
			 Ocirc  => chr(212), #capital O), circumflex accent
			 Otilde => chr(213), #capital O), tilde
			 Ouml   => chr(214), #capital O), dieresis or umlaut mark
			 times  => chr(215), #multiply sign
			 Oslash => chr(216), #capital O), slash
			 Ugrave => chr(217), #capital U), grave accent
			 Uacute => chr(218), #capital U), acute accent
			 Ucirc  => chr(219), #capital U), circumflex accent
			 Uuml   => chr(220), #capital U), dieresis or umlaut mark
			 Yacute => chr(221), #capital Y), acute accent
			 THORN  => chr(222), #capital THORN), Icelandic
			 szlig  => chr(223), #small sharp s), German (sz ligature)
			 agrave => chr(224), #small a), grave accent
			 aacute => chr(225), #small a), acute accent
			 acirc  => chr(226), #small a), circumflex accent
			 atilde => chr(227), #small a), tilde
			 auml   => chr(228), #small a), dieresis or umlaut mark
			 aring  => chr(229), #small a), ring
			 aelig  => chr(230), #small ae diphthong (ligature)
			 ccedil => chr(231), #small c), cedilla
			 egrave => chr(232), #small e), grave accent
			 eacute => chr(233), #small e), acute accent
			 ecirc  => chr(234), #small e), circumflex accent
			 euml   => chr(235), #small e), dieresis or umlaut mark
			 igrave => chr(236), #small i), grave accent
			 iacute => chr(237), #small i), acute accent
			 icirc  => chr(238), #small i), circumflex accent
			 iuml   => chr(239), #small i), dieresis or umlaut mark
			 eth    => chr(240), #small eth), Icelandic
			 ntilde => chr(241), #small n), tilde
			 ograve => chr(242), #small o), grave accent
			 oacute => chr(243), #small o), acute accent
			 ocirc  => chr(244), #small o), circumflex accent
			 otilde => chr(245), #small o), tilde
			 ouml   => chr(246), #small o), dieresis or umlaut mark
			 divide => chr(247), #divide sign
			 oslash => chr(248), #small o), slash
			 ugrave => chr(249), #small u), grave accent
			 uacute => chr(250), #small u), acute accent
			 ucirc  => chr(251), #small u), circumflex accent
			 uuml   => chr(252), #small u), dieresis or umlaut mark
			 yacute => chr(253), #small y), acute accent
			 thorn  => chr(254), #small thorn), Icelandic
			 yuml   => chr(255), #small y), dieresis or umlaut mark
		 );
		 
	 
	 $s =~ s{ (
			 & # an entity starts with a semicolon
			 ( 
			\x23\d+    # and is either a pound (#) and numbers
			 |	       #   or else
			\w+        # has alphanumunders up to a semi
		)         
			 ;?             # a semi terminates AS DOES ANYTHING ELSE (XXX)
		 )
	 } {
	 
		 $entity{$2}        # if it's a known entity use that
			 ||             #   but otherwise
			 $1             # leave what we'd found; NO WARNINGS (XXX)
	 
	 }gex;                  # execute replacement -- that's code not a string
	
	 
	 
		 ####################################################
		 # now fill in all the numbers to match themselves
		 ####################################################
		
		my $chr; 
		 for $chr ( 0 .. 255 ) { 
			 $entity{ '#' . $chr } = chr($chr);
		 }
	return $s; 
}

# This is pretty bizarre - perhaps better to put this in DADA::Template::Widgets, 
# or something, and then have an option to encode the output? 
# 
sub e_print { # be nice to prototype this. 
	#print encode($DADA::Config::HTML_CHARSET, $_[0]); 
	
	my $str = shift; 
	my $fh  = shift || \*STDOUT;  

	print $fh safely_encode($str); 
}



=pod

=head2 uriescape

	$string = uriescape($string); 
 
use to escape strings to be used as url strings.

=cut

sub uriescape {
     my $string = shift;

     if (HAS_URI_ESCAPE_XS) {
         return URI::Escape::XS::uri_escape($string);
     }elsif (HAS_URI_ESCAPE){
         return URI::Escape::uri_escape_utf8($string);
     }else {
         die "URI::Escape was expected to be found but is missing. It should be bundled with the Dada mail distribution";
     }
} 
sub uriunescape {
     my $string = shift;

     if (HAS_URI_ESCAPE_XS) {
         return URI::Escape::XS::uri_unescape($string);
     }elsif (HAS_URI_ESCAPE){
         return URI::Escape::uri_unescape($string);
     }else {
         die "URI::Escape was expected to be found but is missing. It should be bundled with the Dada mail distribution";
     }
}



sub js_enc {

	my $str = shift || '';
	my @chars = split(//,$str);
	for my $c (@chars) {
		$c = '\x' . sprintf("%x", ord($c));
	}
	my $e =  join('',@chars);

	$e =~ s/\\xa|\\xd/ /g;
	$e =~ s/\\x9/\t/g;
	return $e; 

}



   
=pod
               
=head2 lc_email

	$email = lc_email($email); 

used to lowercase the domain part of the email address 
the name part of the email address is case sensitive
although 99.99% its not thought of as. 

=cut 
   

sub lc_email { 
	
	# # utf8::upgrade before doing lc/lcfirst/uc
	
	#get the address 
	my $email = shift || undef;
   if($DADA::Config::EMAIL_CASE eq 'lc_domain'){ 
		#js - 11/25/00 
		if($email){
			#split it into the name and domain 
			my ($name, $domain) = split('@', $email);
			#lowercase the domain 
			$domain = lc($domain);
			#stick it together again 
			$email = "$name\@$domain";
			return $email; 
		}
	}else{ 
		$email = lc($email);
	}
}



=pod

=head2 make_safer

	$string = make_safer($string); 

This subroutine is used to make sure strings, such as list names, 
path to directories, critical stuff like that. 
This is in effort to make Dada Mail able to run in 
'Taint' Mode. If you need to run in taint mode, it may need still some tweakin. 

=cut


sub make_safer { 

	my $string = shift || undef; 
	
	if($string){
		$string =~ tr/\0-\037\177-\377//d;    # remove unprintables
		$string =~ s/(['\\])/\$1/g;           # escape quote, backslash
		$string =~ m/(.*)/;
	return $1; 
	}else{ 
		return 0;
	}

}
sub encode_html_entities { 
	
	my $s            = shift; 
	my $unsafe_chars = shift || undef; 
	
	eval {require HTML::Entities}; 
	if(!$@){ 
	
		$s = HTML::Entities::encode_entities($s, $unsafe_chars ); #, "\200-\377" 
		
	}else{ 
        # require HTML::EntitiesPurePerl 
        # is our own module, based on  HTML::Entities.           
    	eval {require HTML::EntitiesPurePerl}; 
    	if(!$@){ 
			
        	$s = HTML::EntitiesPurePerl::encode_entities($s, $unsafe_chars); #", \200-\377"
    	}
	}
	# These are done by the above (if there's no argument in, encode_entities - right?
	# The docs say: 
	# The default set of characters to encode are control chars, high-bit chars, and the <, &, >, ' and " characters.
	$s =~      s/& /&amp; /g;
	$s =~      s/</&lt;/g;
	$s =~      s/>/&gt;/g;
	$s =~      s/\"/&quot;/g;
		
	return $s; 
	
}


sub plaintext_to_html { 

	my ($args) = @_; 
	
	if(!exists($args->{-str})){ 
		croak "you MUST pass a string to plaintext_to_html in the, '-str' parameter!"; 
	}
	if(!exists($args->{-method})){ 
		$args->{-method} = "thorough"; 
	}
	my $r; 
	
	if($args->{-method} eq 'fast'){ 
		
		# There's a memory leak in HTML::TextToHTML 
		# so, I use the below for Text Versions of HTML messages
		
		require HTML::FromText;
		$args->{-str} = encode_html_entities($args->{-str}, "\200-\377"); 
	    $r = HTML::FromText::text2html($args->{-str}, 
			urls      => 1, 
			email     => 1,
			paras     => 1, 
			#bold      => 1, 
			#underline => 1,
			lines     => 1,
			metachars => 0, 
		);
		return $r; 
	}
	else { 
	
		my $multi_line = 0; 
		if($args->{-str} =~ m/\r|\n/){ 
			$multi_line = 1; 
		}

		$args->{-str} = encode_html_entities($args->{-str}, "\200-\377"); 
	
		require HTML::TextToHTML;
		my $conv = HTML::TextToHTML->new; 
		   $conv->args(
				%{$DADA::Config::HTML_TEXTTOHTML_OPTIONS},
		   		escape_HTML_chars => 0,
				#%{$args->{-conversion_override_args}} # Not implemented. 
			); 
		   $r = $conv->process_chunk($args->{-str}); 
		   undef $conv; 
		if($multi_line == 0){ 
			# I do not remember what this is all about.
			$r =~ s/\<p\>|\<\/p\>//g; 
		}		
	}
	return $r; 
}

sub markdown_to_html { 

	my ($args) = @_; 
	
	if(!exists($args->{-str})){ 
		croak "you MUST pass a string to markdown_to_html in the, '-str' parameter!"; 
	}
	
	require DADA::App::Markdown; 
	my     $dam = DADA::App::Markdown->new; 
	return $dam->markdown_to_html($args->{-str}); 

}


=pod

=head2 check_list_setup

check_list_setup() is used when creating and editing the core basic 
list information, like the list name, list password, list owner's email address 
and the list password. to check a new list, you'll want to do this: 

 my ($list_errors,$flags) = 
     check_list_setup(-fields => {list            => $list, 
                                   list_owner_email      => $list_owner_email, 
                                    password        => $password, 
                                    retype_password => $retype_password, 
                                    info            => $info,
                                    }); 




Its a big boy. What's happening?                                                             
this function returns two things, a reference to a hash	with any errors it 
finds, and a scalar who's value is 1 or above if it finds any errors. 
here's a small reference to what $list_errors would return, all values in the 
hash ref will be one IF they are found to have something wrong in em: 

	

list                             - no list name was given
list_exists                      - the list exists 
password                         - no password given
retype_password                  - the second password was not given
password_ne_retype_password      - the first password didn't math the second
slashes_in_name                  - slashes were found in the list name
weird_characters                 - unprintable characters were found in the list name                                                    
quotes                           - quotes were found in the list name
invalid_list_owner_email               - the email address for the list owner is invlaid
info                             - no list info was given. 

here's a better example on how to use this:

 my ($list_errors,$flags) = 
 check_list_setup(-fields => {list            => $list, 
                                list_owner_email      => $list_owner_email, 
                                password        => $password, 
                                retype_password => $retype_password, 
                                info            => $info,
                                });
	if($flags >= 1){
        print "your list name was never entered!" if $list_errors -> {list} == 1; 
 	}

Now, if you want to check the setup of a list already created (editing a list) just set the 
-new_list flag to 'no', like this: 


 my ($list_errors,$flags) = 
 check_list_setup(-fields => {list            => $list, 
                                list_owner_email      => $list_owner_email, 
                                password        => $password, 
                                retype_password => $retype_password, 
                                info            => $info,
                                },
                    -new_list => 'no'                
                                ); 	

This will stop checks on the list name (which is already set) and if the list exists (which,
hopefully it does, since we're editing it) 

=cut 



sub check_list_setup {

    my %args = (
		-fields    => undef,  
    	-new_list  => 'yes', 
    	@_
	); 
    		   
	my %new_list_errors = (); 
	my $list_errors     = 0;
    my $fields = $args{-fields}; 
 
	
	if($fields->{list} eq ""){ 
		$list_errors++;
		$new_list_errors{list} = 1;
	}else{ 
		$new_list_errors{list} = 0;
	}


	
	if($fields->{list_name} eq ""){ 
		$list_errors++;
		$new_list_errors{list_name} = 1;
	}else{ 
		$new_list_errors{list_name} = 0;
	}
	
	

	
	
	
	if($fields->{list_name} =~ m/(\>|\<|\")/){ 
		$list_errors++;
		$new_list_errors{list_name_bad_characters} = 1;
	}else{ 
		$new_list_errors{list_name_bad_characters} = 0;
	}
	

	
	

	
	if($args{-new_list} eq "yes") {
		my $list_exists = check_if_list_exists(-List => $fields->{list}); 
		if($list_exists >= 1){
			 $list_errors++; 
			 $new_list_errors{list_exists} = 1;
		}else{ 
			 $new_list_errors{list_exists} = 0;
		}	
	}



	
	if($args{-new_list} eq "yes") {
		if(!defined($fields->{password}) || $fields->{password} eq ""){	
			$list_errors++;
			$new_list_errors{password} = 1;
		}else{ 
			$new_list_errors{password} = 0;
		}
		
		
				
		# it means that the password we're using for the list, 
		# is the Dada Mail Root Password - doh!
		if(root_password_verification($fields->{password}) == 1){ 
		    $list_errors++;
		    $new_list_errors{password_is_root_password} = 1;
		}else{ 
		    $new_list_errors{password_is_root_password} = 0;		
		}
		
		
		
		if($fields->{retype_password} eq ""){
			$list_errors++;
			$new_list_errors{retype_password} = 1;
		}else{ 
			$new_list_errors{retype_password} = 0;
		}
		

		
		
		if($fields->{password} ne $fields->{retype_password}) { 
			 $list_errors++;
			 $new_list_errors{password_ne_retype_password} = 1;
		}else{ 
			 $new_list_errors{password_ne_retype_password} = 0;
		}
				
		if(length($fields->{list}) > 16){ 
			$list_errors++;
			$new_list_errors{shortname_too_long} = 1;
		}else{ 
			$new_list_errors{shortname_too_long} = 0;
		}
		
		if($fields->{list} =~ m/\/|\\/){ 
        	$list_errors++;
			$new_list_errors{slashes_in_name} = 1;
		}else{ 
			$new_list_errors{slashes_in_name} = 0;
		}

		# This is not where I want this, but this'll be where we'll be reserved stuff - 
		# for now - there really should be a , "reserved_words" error.
		my $reserved_words = { 
			_screen_cache => 1, 
		};
		
		if($fields->{list} =~ m/\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\>|\<|\-|\0-\037\177-\377/){ 
        	$list_errors++; 
       		$new_list_errors{weird_characters} = 1;
      	}else{ 
			if($fields->{list} =~ m/[^a-zA-Z0-9_]/){ 
				$list_errors++; 
				$new_list_errors{weird_characters} = 1;
			}
			# Again, we need this to be its own test. 
			elsif(exists($reserved_words->{$fields->{list}})){ 
				$list_errors++; 
				$new_list_errors{weird_characters} = 1;				
			}
			else { 
      			$new_list_errors{weird_characters} = 0;
  			}
		}
     
    	if($fields->{list} =~ m/\"|\'/){ 
        	$list_errors++; 
       		$new_list_errors{quotes} = 1;
      	}else{ 
      		$new_list_errors{quotes} = 0;
      	}
	}
	
	my $invalid_email = check_for_valid_email($fields->{list_owner_email});
	
	if($invalid_email >= 1){
		$list_errors++;
		$new_list_errors{invalid_list_owner_email} = 1;
	}else{ 
		$new_list_errors{invalid_list_owner_email} = 0;
	}
	
	if($fields->{info} eq ""){ 
		$list_errors++;
		$new_list_errors{list_info} = 1;
	}else{ 
		$new_list_errors{list_info} = 0;
	}
	
		

	
if($args{-new_list} eq "yes") {	
	if(length($fields->{privacy_policy}) == 0){ 	
		$list_errors++;
	
		$new_list_errors{privacy_policy} = 1;
	}else{ 
		$new_list_errors{privacy_policy} = 0;
	}
}
	
	if($fields->{physical_address} eq ""){ 
		$list_errors++;
		$new_list_errors{physical_address} = 1;
	}else{ 
		$new_list_errors{physical_address} = 0;
	}
	
	
	if($args{-new_list} eq "yes") {
		# optional, but if there, needs to be like, *something* 
		if(defined($fields->{consent}) &&  length($fields->{consent}) > 0){ 
			if(length($fields->{consent}) < 16){ 
				$list_errors++;
				$new_list_errors{consent} = 1;
			}else{ 
				$new_list_errors{consent} = 0;
			}
		}
		else { 
			$new_list_errors{consent} = 0;
		}
	}
	return ($list_errors, \%new_list_errors);
}


=pod

=head2 user_error 

deals with errors from a CGI interface

	user_error({-list => 'my_list', 
	           -error => 'some_error', 
	           -email => 'some@email.com'}); 


=cut


sub user_error {
	my ($args) = @_; 
	
    my $list  = $args->{-list};
    my $error = $args->{-error};
    my $email = $args->{-email};
	my $fh = undef; 
#	if(!exists($args->{-fh})){ 
#		$fh = \*STDOUT;
#	}
#	else { 
#		$fh = $args->{-fh};
#	}

#    my $fh    = $args->{-fh};
#use Data::Dumper; 
#carp Dumper($args); 

    my $test  = $args->{-test};
    my $invalid_profile_fields = {}; 
    if(exists($args->{-invalid_profile_fields})){ 
       $invalid_profile_fields =  $args->{-invalid_profile_fields};
    }
    require DADA::App::Error;
    my $error_msg = DADA::App::Error::cgi_user_error(
		{
        -list                   => $list,
        -error                  => $error,
        -email                  => $email,
		-vars                   => $args->{-vars},
		-invalid_profile_fields => $invalid_profile_fields, 
    	}
	);

    return $error_msg; 

}

 
 
 
 
 sub root_password_verification { 
	my $root_pass = shift || undef;
	
	return 0 if !$root_pass;
	 
	require DADA::Security::Password;
	if($DADA::Config::ROOT_PASS_IS_ENCRYPTED == 1){ 	
		my $root_password_check = DADA::Security::Password::check_password($DADA::Config::PROGRAM_ROOT_PASSWORD, $root_pass); 
		if($root_password_check == 1){
			return 1; 
		}else{ 
			return 0; 
		}
	}else{ 
		if($DADA::Config::PROGRAM_ROOT_PASSWORD eq $root_pass){ 
			return 1; 
		}else{ 
			return 0; 
		}
	}
}






=pod

=head2 message_id

returns an id, based on the date. 

=cut

sub message_id { 
    my $ctime = shift || time; 
	my ($sec, $min, $hour, $day, $month, $year) = (localtime($ctime))[0,1,2,3,4,5];
	my $message_id = sprintf("%02d%02d%02d%02d%02d%02d", $year+1900, $month+1, $day,  $hour, $min, $sec);
	return $message_id; 


}





sub check_list_security { 
    
    
	my %args = (-Function        => undef, 
				-cgi_obj         => undef, 
				-check_csrf      => undef, 
				@_);

    if($t == 1) { 
        warn 'in check_list_security'; 
        require Data::Dumper; 
        warn 'args:' . Data::Dumper::Dumper({%args}); 
    }


	croak 'no CGI Object (-cgi_obj)' if ! $args{-cgi_obj};

	require DADA::App::Session; 
	
	
	my $dada_session = DADA::App::Session->new();
	my ($admin_list, $root_login, $checksout, $error_msg) = $dada_session->check_session_list_security(%args); 
    
    if($checksout == 1){ 
        if (install_dir_around() == 1 ) {
                $checksout = 0; 
                $error_msg = user_error( { -error => 'install_dir_still_around' } );
                $root_login = 0; 
                $admin_list = undef; 
        }
    }
	return ($admin_list, $root_login, $checksout, $error_msg); 

}


sub install_dir_around { 	
	if(-e 'installer' && -d 'installer'){ 
		return 1; 
	}
}


=pod

=head2 check_setup

makes sure the following directories exists and can be written into: 

$DADA::Config::FILES
$DADA::Config::TEMPLATES 
$DADA::Config::TMP 

returns '1' if this is the case, 0 otherwise. 

This test is disabled is $OS is set to a windows ( ^Win|^MSWin/i )
variant. 

=cut

sub check_setup { 	
	if($DADA::Config::OS =~ /^Win|^MSWin/i){ 
		carp "directory setup test disabled for WinNT";
		return 1; 
	}else{ 	
		my @tests = ($DADA::Config::FILES, $DADA::Config::TEMPLATES , $DADA::Config::TMP );
		for my $test_dir(@tests){ 

			if(-d $test_dir && -e $test_dir){ 
			
			}else{ 
				# carp "Couldn't find: $test_dir";
				return 0;
			}
		} 	
		return 1;
	}
}


sub SQL_check_setup {

    my $dbi_obj = undef;
    my $dbh     = undef;
    try {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $dbh     = $dbi_obj->dbh_obj;
    }
    catch {
        carp "error attempting to create dbi object: $_";
        return 0;
    };

    my %tables_to_create = ();
    foreach ( keys %DADA::Config::SQL_PARAMS ) {
        if ( $_ =~ m/table/ ) {
            $tables_to_create{ $DADA::Config::SQL_PARAMS{$_} } = 0;
        }
    }

    foreach my $table_name ( keys %tables_to_create ) {
        try {
            my $query = 'SELECT * FROM ' . $table_name . ' WHERE 1 = 0';

            # * If an error is raised, the table does not exist.
            $dbh->do($query)
              or croak "cannot do statement: '$query': $DBI::errstr\n";
        }
        catch {
            $tables_to_create{$table_name} = 1;
        };
    }

    my $need_to_create = 0;
    foreach ( keys %tables_to_create ) {
        if ( $tables_to_create{$_} == 1 ) {
            $need_to_create++;
        }
    }

    if ( $need_to_create >= 1 ) {
        my $r = create_probable_missing_tables( \%tables_to_create );
        if ( $r == 0 ) {
            return 0;
        }
        else {
            # ...
        }
    }

    # v6.3.0 changed the schema of the,
    # * dada_mass_mailing_event_log
    # * dada_clickthrough_url_log
    # adding an, "email" column - let's make sure that's there.
    upgrade_tables();

    return 1;

}

sub create_probable_missing_tables {

    my ($tables_to_create) = @_;

    my $db_type = $DADA::Config::SQL_PARAMS{dbtype};

    my $sql_file = '';
    if ( $db_type eq 'mysql' ) {
        $sql_file = 'mysql_schema.sql';
    }
    elsif ( $db_type eq 'Pg' ) {
        $sql_file = 'postgres_schema.sql';
    }
    elsif ( $db_type eq 'SQLite' ) {
        $sql_file = 'sqlite_schema.sql';
    }
    my $schema = slurp( make_safer( 'extras/SQL/' . $sql_file ) );
    my @statements = split( ';', $schema );

    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    my $dbh     = $dbi_obj->dbh_obj;

    for my $create_table (@statements) {
        my $table_name = undef;
        if ( $db_type eq 'Pg' ) {
            $table_name = $create_table;
            $table_name =~ m/CREATE TABLE (\S+) +\(/;
            $table_name = $1;
        }
        else {
            $table_name = $create_table;
            $table_name =~ m/CREATE TABLE IF NOT EXISTS (\S+) +\(/;
            $table_name = $1;
			$table_name = strip($table_name);
        }

        if ( $tables_to_create->{$table_name} == 1 ) {
            warn "need to create table, '$table_name'";

            try {
                my $sth = $dbh->prepare($create_table)
                  or croak $DBI::errstr;
                $sth->execute
                  or croak "cannot do statement $DBI::errstr\n";
            }
            catch {
                carp
"Couldn't create necessary SQL table, '$table_name' with query, '$create_table' - you may have to do this, manually: $_";
            };
        }
        else {
            warn "no need to create table, '$table_name'";
        }
    }

    return 1;

}



sub upgrade_tables {
#	warn 'upgrade_tables!';
	
    my $dbi_obj = undef;
    my $dbh     = undef;

    try {
        require DADA::App::DBIHandle;
        $dbi_obj = DADA::App::DBIHandle->new;
        $dbh     = $dbi_obj->dbh_obj;
    }
    catch {
        carp "error attempting to create dbi object: $_";
        return 0;
    };

    foreach my $tablename (qw(clickthrough_url_log_table mass_mailing_event_log_table)) {

        my $table_cols = table_cols( $dbh, $tablename );
        if ( exists( $table_cols->{email} ) ) {

            # good to go.
        }
        else {
            my $query;
            if ( $tablename eq 'clickthrough_url_log_table' ) {
                $query = 'ALTER TABLE ' . $DADA::Config::SQL_PARAMS{$tablename} . ' ADD email VARCHAR(80)';
            }
            elsif ( $tablename eq 'mass_mailing_event_log_table' ) {
                $query = 'ALTER TABLE ' . $DADA::Config::SQL_PARAMS{$tablename} . ' ADD email VARCHAR(80)';
            }
            else {
                croak "unknown error!";
            }
            # warn 'Query: ' . $query;
            my $sth = $dbh->do($query)
              or croak $dbh->errstr;
            undef $query;
            undef $sth;
        }
        if ( exists( $table_cols->{user_agent} ) ) {
            # good to go.
        }
        else {
            my $query;
            if ( $tablename eq 'clickthrough_url_log_table' ) {
                $query = 'ALTER TABLE ' . $DADA::Config::SQL_PARAMS{$tablename} . ' ADD user_agent VARCHAR(255)';
            }
            elsif ( $tablename eq 'mass_mailing_event_log_table' ) {
                $query = 'ALTER TABLE ' . $DADA::Config::SQL_PARAMS{$tablename} . ' ADD user_agent VARCHAR(255)';
            }
            else {
                croak "unknown error!";
            }
            # warn 'Query: ' . $query;
            my $sth = $dbh->do($query)
              or croak $dbh->errstr;
            undef $query;
            undef $sth;
        }
    }

    # dada_profile_fields_attributes
    my $table_cols = table_cols( $dbh, 'profile_fields_attributes_table' );
    if ( exists( $table_cols->{required} ) ) {
        # good to go.
    }
    else {
        my $query =
            'ALTER TABLE '
          . $DADA::Config::SQL_PARAMS{profile_fields_attributes_table}
          . ' ADD required char(1) DEFAULT 0 NOT NULL';
        my $sth = $dbh->do($query)
          or croak $dbh->errstr;
        undef $query;
        undef $sth;
    }
#    $table_cols;

    # dada_subscribers
    my $table_cols = table_cols( $dbh, 'subscriber_table' );
    if ( exists( $table_cols->{timestamp} ) ) {

        # good to go.
    }
    else {
        my $query;
        if (   $DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'
            || $DADA::Config::SQL_PARAMS{dbtype} eq 'Pg' )
        {
            $query =
                'ALTER TABLE '
              . $DADA::Config::SQL_PARAMS{subscriber_table}
              . ' ADD timestamp TIMESTAMP DEFAULT NOW()';
        }
        elsif ( $DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite' ) {
            $query =
                'ALTER TABLE '
              . $DADA::Config::SQL_PARAMS{subscriber_table}
              . ' ADD timestamp TIMESTAMP'; # DEFAULT CURRENT_TIMESTAMP
        }
        my $sth = $dbh->do($query)
          or croak $dbh->errstr;
        undef $query;
        undef $sth;
    }
	


    # password_protect_directories_table
    my $table_cols = table_cols( $dbh, 'password_protect_directories_table' );
    if ( exists( $table_cols->{always_use_default_password} ) ) {
		
        # good to go.
    }
    else {
		
		my $query =
			'ALTER TABLE '
			. $DADA::Config::SQL_PARAMS{password_protect_directories_table}
			. ' ADD always_use_default_password char(1)';

			# warn '$query: ' . $query; 
			
        my $sth = $dbh->do($query)
          or croak $dbh->errstr;
        undef $query;
        undef $sth;
    }
	
	try {
		if($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql') {
	
			my $sth = $dbh->column_info( undef, undef, $DADA::Config::SQL_PARAMS{message_drafts_table}, '%' );
			#use Data::Dumper;
			my $m_info = $sth->fetchall_hashref('COLUMN_NAME');
		
			# created_timestamp = CURRENT_TIMESTAMP
			# last_modified_timestamp = 0000-00-00 00:00:00
				
			if(
			   $m_info->{created_timestamp}->{COLUMN_DEF} =~ m/00/
			){ 
				my $query =  'ALTER TABLE '
				. $DADA::Config::SQL_PARAMS{message_drafts_table}
				. " MODIFY COLUMN created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP";
				my $sth = $dbh->do($query)
					or croak $dbh->errstr;
				undef $query;
				undef $sth;
			}
			   
			if(
				$m_info->{last_modified_timestamp}->{COLUMN_DEF} =~ m/00/	
			) { 
				my $query =  'ALTER TABLE '
				. $DADA::Config::SQL_PARAMS{message_drafts_table}
				. " MODIFY COLUMN last_modified_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP";
				my $sth = $dbh->do($query)
					or croak $dbh->errstr;
				undef $query;
				undef $sth;	
			}
		
			else { 
				# warn "ALL SET!";
			}
		}
	} catch { 
		warn $_; 
	};

    return 1;
}



sub table_cols { 
    my $dbh   = shift; 
    my $table = shift; 
    
    my $sth = $dbh->prepare("SELECT * FROM " .  $DADA::Config::SQL_PARAMS{$table} ." WHERE 1=0");
    $sth->execute();
    my $fields = $sth->{NAME};
    $sth->finish;
	
    my $n_fields = {};
    foreach(@$fields){
    $n_fields->{$_} = 1;
    }
	
	return $n_fields; 
	
}

=pod

=head2 cased

my $email = cased('SOME@WHERE.COM'); 


cased takes a string and recases the string, depending on what 
$DADA::Config::EMAIL_CASE is set to. 

if the email address is: SOME@WHERE.com, 

it will be changed to: some@where.com if $DADA::Config::EMAIL_CASE is set to: 'lc_all'

it will be changed to: SOME@where.com if $DADA::Config::EMAIL_CASE is set to: 'lc_domain'

=cut

sub cased {
	my $str = shift; 
	
	my $name  = undef; 
	my $domain = undef; 

	if($DADA::Config::EMAIL_CASE eq 'lc_all'){ 	
		return lc($str);
	}elsif($DADA::Config::EMAIL_CASE eq 'lc_domain'){ 
		($name, $domain) = split('@', $str); 
		return $name.'@'.lc($domain);
	}else{ 
		($name, $domain) = split('@', $str); 
		return lc($name).'@'.$domain;	
	}
}




=pod

=head2 xss_filter

 $str = xss_filter($str); 

Simple subroutine that strips '<', '>' and '"', and replaces them with
HTML entities. This is used to stop text that can be interpretted as
javascript, etc code from being executed.  

=cut

sub xss_filter {
    my $t = shift;
    if ( defined($t) ) {

        #$t =~ s/[^A-Za-z0-9 ]*/ /g;
        $t =~ s/\</&lt;/g;
        $t =~ s/\>/&gt;/g;
        $t =~ s/\"/&quot;/g;
        return $t;
    }
    else {
        return undef;
    }
}



sub isa_ip_address { 

    my $ip_address = shift; 
        
    
    my $ReIpNum = qr{([01]?\d\d?|2[0-4]\d|25[0-5])};
    my $ReIpAddr = qr{^$ReIpNum\.$ReIpNum\.$ReIpNum\.$ReIpNum$};
    
 
            if ($ip_address =~ m{$ReIpAddr} == 1){
                return 1; 
            } else { 
                return 0; 
            }

}

sub isa_url { 
	
	my $str = shift;
	# DEV: This regex needs to be smarterer.  
	if($str =~ m/^(http|https|ftp|file|ical)\:\/\/(.*?)$/){
		return 1; 
	}
	else { 
		return 0; 
	}
	
}



sub escape_for_sending { 
	# i really wish I could find some docs on what
	# needs to be escaped...
	# ^- DEV: or, just use Email::Address?!
	
	my $s = shift; 	
	#$s =~ s/\./\\\./g;	
	#$s =~ s/\"/\\\"/g;	
	$s =~ s/\"/\\\"/g;	
	$s =~ s/\,/\\,/g;
	$s =~ s/:/\\:/g;
	
	
	return $s; 
} 




sub entity_protected_str { 

    my $str = shift;
    return spam_me_not_encode($str); 
}





sub spam_me_not_encode { 

	my $originalString    = shift; 
	my $mode              = shift || 3; 

	
	return $originalString
		if $mode == 4; 
		
	my $encodedString = "";
	my $nowCodeString = "";
	my $randomNumber = -1;
	my $originalLength = length($originalString);
	my $encodeMode = $mode;
	
	my $i;
	for ( $i = 0; $i < $originalLength; $i++) {
		$encodeMode = (int(rand(2)) + 1)
			if ($mode == 3);
		if($encodeMode == 1) {
			#case 1: // Decimal code 
				$nowCodeString = "&#" . ord(substr($originalString,$i)) . ";"; 
		}elsif($encodeMode == 2) {
			#case 2: // Hexadecimal code
				$nowCodeString = "&#x" . perl_dechex(ord(substr($originalString,$i))) . ";";
		}else{	
				return "ERROR: wrong encoding mode.";
		}
		$encodedString .= $nowCodeString;
	}
	return $encodedString;
}

sub break_encode { 
	my $address = shift;
	my $r; 
	
    require Email::Address;
    my $addy = undef;
	
	try {
		my @addresses = Email_Address_parse($address);
		my @n_addresses; 
		for my $addr(@addresses) { 
			my ($name, $domain) = split('@', $addr->address, 2);
			my $phrase = $addr->phrase;
			my @words = split(' ', $phrase); # sigh. 
			my @new_words; 
			foreach my $word(@words) { 
				if($word =~ m/\@/) { #... kinda looks like an email address?
					my ($w_name, $w_domain) = split('@', $word, 2);
					$word = $w_name . '@PROTECTED';
				}
				push(@new_words, $word);
			}
			my $new_address = Email::Address->new(join(' ', @new_words), $name . '@PROTECTED');
			push(@n_addresses, $new_address->format); 
			$r = join(',', @n_addresses);
		}
	} catch { 
		my ($name, $domain) = split('@', $address, 2);
		$r = $name . '@' . 'PROTECTED' 
	};

	return $r; 
}




sub anonystar_address_encode { 	
	my $str = shift; 
	my ($n, $d) = split('@', $str); 
	if(length($n) == 1){ 
		return '*@'. $d; 
	} 
	else { 
		return substr($n, 0,1) . '*' x (length($n) -1)  . '@' . $d;  
	}
}




sub gravatar_img_url {

    my ($args) = @_;
    my $url = undef;

    if ( !exists( $args->{-size} ) ) {
        $args->{-size} = 80;
    }
    if ( !exists( $args->{-default_gravatar_url} ) ) {
        $args->{-default_gravatar_url} =
          $DADA::Config::PROFILE_OPTIONS->{gravatar_options}
          ->{default_gravatar_url};
    }


	if(
		   ! exists ($args->{-email}) 
		|| ! defined($args->{-email})
		|| length($args->{-email}) <= 0
	){ 
		return undef; 
	}
	
    my $can_use_gravatar_url = can_use_Gravatar_URL(); 
	
    if ( $can_use_gravatar_url == 1 ) {
        if ( isa_url( $args->{-default_gravatar_url} ) ) {
            $url = Gravatar::URL::gravatar_url(
                email   => $args->{-email},
                default => $args->{-default_gravatar_url},
                size    => $args->{-size}
            );
        }
        else {
            $url = Gravatar::URL::gravatar_url(
                email => $args->{-email},
                size  => $args->{-size}
            );
        }
    }
    return $url;

}




sub can_use_Gravatar_URL { 
	
    my $can_use_gravatar_url = 1;
    try {
        require Gravatar::URL;
    } catch {
        $can_use_gravatar_url = 0;
    };
	return $can_use_gravatar_url; 
}





sub perl_dechex { 
	my $s = shift; 
	return sprintf("%X", $s);
}
sub perl_dehex {
    my $s    = shift;
    $s =~ s/([a-fA-F0-9][a-fA-F0-9])/chr(hex($1))/eg;
    return $s;
}




sub optimize_mime_parser { 

	my $parser = shift; 
	
	croak 'need a MIME::Parser object...' 
		if ! $parser; 
	
	if($DADA::Config::MIME_TOOLS_PARAMS->{tmp_to_core} == 1){ 
		$parser->tmp_to_core(1); 
		$parser->output_to_core(1);
	}
	else { 
		$parser->tmp_to_core(0);
		$parser->output_to_core(0);
		
		if($DADA::Config::MIME_TOOLS_PARAMS->{tmp_dir} eq 'app_default' ) {
			
		    my $dir = make_safer($DADA::Config::TMP . '/_mime_cache');
			if(! -d $dir) {
				if(mkdir( $dir, $DADA::Config::DIR_CHMOD )) { 
					# good! 
				}
				else { 
					warn "couldn't make dir, $dir";
				}
			}

			$parser->output_dir(make_safer($DADA::Config::TMP . '/_mime_cache') );
			$parser->tmp_dir(   make_safer($DADA::Config::TMP . '/_mime_cache') );
		}
		else { 
			my $Server_TMP_dir          = $ENV{TMP} // '/tmp';
			$parser->output_dir(make_safer($Server_TMP_dir) );
			$parser->tmp_dir(   make_safer($Server_TMP_dir) );			
		}
	}
		
	return $parser; 
}




sub csv_subscriber_parse {

    my $list     = shift;
    my $filename = shift;

    my $lh = DADA::MailingList::Subscribers->new( { -list => $list } );
    my $subscriber_fields = $lh->subscriber_fields;

    my $addresses = [];

    $filename = uriescape($filename);
    $filename =~ s/\s/%20/g;
    if ( length($filename) <= 0 || $filename eq '' ) {
        return [];
    }

    if ( !-r $DADA::Config::TMP || !-w $DADA::Config::TMP || !-x $DADA::Config::TMP ) {
        chmod( $DADA::Config::DIR_CHMOD, $DADA::Config::TMP );
    }
    else {
        # good.
    }

    if ( !-f $DADA::Config::TMP . '/' . $filename ) {
        return [];
    }

    # Line translation.
    # Don't like it.
    # Notes:
    # https://use.perl.org/comments.pl?sid=33475&cid=55956
    # https://search.cpan.org/~rgarcia/perl-5.10.0/lib/PerlIO.pm

    # Reading
    open my $NE, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $DADA::Config::TMP . '/' . $filename
      or die "Can't open: " . $DADA::Config::TMP . '/' . $filename . ' because: ' . $!;

    # Writing
    open my $NE2, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      make_safer( $DADA::Config::TMP . '/' . $filename . '.translated' )
      or die "Can't open: " . make_safer( $DADA::Config::TMP . '/' . $filename . '.translated' ) . ' because: ' . $!;

    my $c = 0;
    my $line;
    while ( defined( $line = <$NE> ) ) {
        $c++;

        # this line can break when weird,
        # non-utf-8 stuff is attempted to be read.
        $line =~ s{\r\n|\r}{\n}g;
        print $NE2 $line
          or warn "cannot translate line #" . $c . 'because: ' . $!;
    }

    close($NE) or die $!;
    undef($NE);

    close $NE2 or die $!;
    undef($NE2);

    # /Done line ending translation.
    undef($c);

    open my $NE3, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',
      $DADA::Config::TMP . '/' . $filename . '.translated'
      or die "Can't open: " . $DADA::Config::TMP . '/' . $filename . '.translated' . ' because: ' . $!;

    while ( defined( $line = <$NE3> ) ) {

        my $pre_info = $lh->csv_to_cds($line);

        #require Data::Dumper;
        #warn '$pre_info' . Data::Dumper::Dumper($pre_info);

        # All this is basically doing is re-designing the complex data structure for HTML::Template stuff,
        # as well as embedding the original csv stuff
        # DEV: So... are we using it for HTML::Template?
        # Erm. Kinda - still gets passed to filter_subscription_list_meta thingy.

        if ( $pre_info->{email} eq '' ) {

            # This probably means we have encountered a blank line.
        }
        else {
            push( @$addresses, { 
                email   => $pre_info->{email},
                fields  => $pre_info->{fields},
                profile => $pre_info->{profile},
            });
        }
    }

    close($NE3);

    # And all this is to simply remove the file...
    my $full_path_to_filename = $DADA::Config::TMP . '/' . $filename;

    my $chmod_check = chmod( $DADA::Config::FILE_CHMOD, make_safer($full_path_to_filename) );
    if ( $chmod_check != 1 ) {
        warn "could not chmod '$full_path_to_filename' correctly.";
    }

    my $unlink_check = unlink( make_safer($full_path_to_filename) );
    if ( $unlink_check != 1 ) {
        warn "couldn't remove tmp file: " . $full_path_to_filename;
    }

    my $unlink_check2 = unlink( make_safer( $full_path_to_filename . '.translated' ) );
    if ( $unlink_check2 != 1 ) {
        warn "couldn't remove tmp file: " . $full_path_to_filename . '.translated';
    }

    return ($addresses);

}




sub decode_cgi_obj {

    #use Data::Dumper;
    my $query = shift;
    # return $query; # debug.

    for my $name ( $query->param ) {

        # Don't decode image uploads that are binary.
        if ( $name =~ m/file|picture|attachment(.*?)$/ ) {
            next;
        }

        my @val     = $query->multi_param($name);
        my @new_val = ();

        # are we really using UTF-8 encoded *names*?!
        
        $name = safely_decode($name);

        for my $each_val (@val) {
            push( @new_val, safely_decode($each_val) );
        }

        if ( scalar @val == 1 ) {
            $query->delete($name); 
            $query->param( $name, $new_val[0] );
        }
        else {
            $query->delete($name); 
            $query->param( $name, @new_val );
        }
    }
    return $query;

}




sub safely_decode { 
	
	my $str   = shift; 
	my $force = shift || 0; 

	
	if(utf8::is_utf8($str) == 1 && $force == 0){ 
	#if ($str =~ /[^\x0-\x7f]/ && $force == 0){ 
		#	warn 'utf8::is_utf8 is returning 1 - not decoding.'; 
	}
	else { 
		eval { 
			$str = Encode::decode($DADA::Config::HTML_CHARSET, $str); 
		};
		
		if($@){ 
			warn 'Problems: with: (' . $str . '): '. $@; 
		} 
	}
	#warn 'decoding was safely done.';
	return $str;
}

sub safely_encode { 	
	if(utf8::is_utf8($_[0])){ 
		return Encode::encode($DADA::Config::HTML_CHARSET, $_[0]); 
	}
	else { 
		return $_[0];
	}	
}

sub slurp {

    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open( F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
      || croak "open $file: $!";
    @r = <F>;
    close(F) || croak "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}



sub make_ua { 
    	
	my ($args) = @_; 
	
	my ($www_engine_status, $www_engine_error) = can_use_www_engine(); 
	if($www_engine_status == 0){ 
        carp "WWW engine not set up correctly?" . $www_engine_error
			if $t; 
		return undef; 
	}
   	
	# I don't think I have to do this twice: 
	if($DADA::Config::WWW_ENGINE_OPTIONS->{www_engine} eq 'curl'){		
		require LWP::Protocol::Net::Curl;
	    LWP::Protocol::implementor($_ => 'LWP::Protocol::Net::Curl')
	    for @LWP::Protocol::Net::Curl::implements;
	}
	else { 
		require LWP;
	}
	
    require LWP::UserAgent;
	my $ua; 
	
	if(exists($args->{-keep_alive})){ 
		$ua = LWP::UserAgent->new(
			keep_alive => $args->{-keep_alive},
		);
	}
	else { 
		$ua = LWP::UserAgent->new;
	}
	
	if(defined($ua)){
		if(exists($DADA::Config::WWW_ENGINE_OPTIONS->{user_agent} )){ 
			if(length($DADA::Config::WWW_ENGINE_OPTIONS->{user_agent}) > 0){
				 $ua->agent( $DADA::Config::WWW_ENGINE_OPTIONS->{user_agent} );
			}
			else { 
				$ua->agent('');
			}
		}
		else { 
			$ua->agent('');
		}
	
		if($DADA::Config::WWW_ENGINE_OPTIONS->{verify_hostname} == 1){ 
			$ua->ssl_opts( verify_hostname => 1 ); 
		}
	 	else { 
			$ua->ssl_opts( verify_hostname => 0 ); 
		}
	}
	return $ua; 
	
}




sub grab_url {

	# DEV: time to return a hashref, I'm thinking. 
    my ($args) = @_; 
    my $url = $args->{-url}; 

    require HTTP::Message;
	
	my $ua = make_ua();
	
	if(!defined($ua)){ 
    	if(wantarray){ 
            return (undef, undef, undef, undef); 
        }
        else { 
		    return undef; 
	    }
	}

    if ( can_use_compress_zlib() == 1 ) {
        my $can_accept = HTTP::Message::decodable();
        my $res = $ua->get( $url, 
            'Accept-Encoding' => $can_accept, 
        );
        if ($res->is_success) {      
			if(wantarray){
                my $dc = $res->decoded_content;  
                return ($dc, $res, md5_checksum(\$dc), undef); 
            }
            else { 
                return $res->decoded_content;
            }
    	}
    	else { 
			require Data::Dumper;
			my $e_r = { 
				url         => $url, 
				code        => $res->code, 
				# headers     => $res->headers, 
				status_line => $res->status_line, 
				message     => $res->message, 				
			};
			my $e_m = "Problem fetching URL:\n"; 
			   $e_m .= Data::Dumper::Dumper($e_r);
			   carp $e_m; 
    		if(wantarray){ 
                return (undef, $res, undef, $e_m); 
            }
            else { 
    		    return undef; 
    	    }
    	}
    }
    else {
        my $res = $ua->get($url);
        if ($res->is_success) {
            if(wantarray){ 
                my $dc = safely_decode( $res->content );      
                return ($dc, $res, md5_checksum(\$dc), undef); 
            }
    		else { 
    		    return safely_decode( $res->content ); 
    		}
        }
    	else { 
			require Data::Dumper;
			my $e_r = { 
				url         => $url, 
				code        => $res->code, 
				# headers     => $res->headers, 
				status_line => $res->status_line, 
				message     => $res->message, 				
			};
			my $e_m = "Problem fetching URL:\n"; 
			   $e_m .= Data::Dumper::Dumper($e_r);
			   carp $e_m; 
    		if(wantarray){ 
                return (undef, $res, undef, $e_m); 
            }
            else { 
    		    return undef; 
    	    }
    	}
    }
}


sub scrub_js { 

	my $html = shift; 

	try {  
		require HTML::Scrubber;
		my $scrubber = HTML::Scrubber->new(
	    	%{$DADA::Config::HTML_SCRUBBER_OPTIONS}
	    );
	    $scrubber->style(1); # I can't figure out how to put this in the options...
		$html = $scrubber->scrub($html); 
	} catch { 
		carp "Cannot use HTML::Scrubber:" . $_
			if $t; 
	};
	
	return $html;	
}




sub md5_checksum {

    my $data = shift;

    try {
        require Digest::MD5;
    }
    catch {
        carp "Can't use Digest::MD5?" . $_
			if $t; 
        return undef;
    };
    return Digest::MD5::md5_hex( safely_encode($$data) );
}


sub can_use_compress_zlib { 
    	my $can_use_compress_zlib = 1; 
    	try { 
    		require Compress::Zlib ;
    	}
    	catch { 
    		$can_use_compress_zlib = 0; 	
    	};
    	return $can_use_compress_zlib;
}




sub can_use_DateTime { 
    my $can_use_datetime = 1; 
   	try { 
        require DateTime;
    } catch { 
        $can_use_datetime = 0; 
    };
    return $can_use_datetime; 
}




sub can_use_DateTime_Event_Recurrence { 
    my $can_use_datetime = 1; 
   	try { 
        require DateTime;
        require DateTime::Event::Recurrence;
    } catch { 
        $can_use_datetime = 0; 
    };
    # warn 'can_use_datetime ' . scalar $can_use_datetime; 
    return $can_use_datetime; 
}


sub can_use_LWP_Simple { 
	my $can_use_lwp_simple = 1; 
	try { 
		require LWP::Simple;
	}
	catch { 
		$can_use_lwp_simple = 0; 	
	};
	return $can_use_lwp_simple;
}


sub can_use_www_engine { 

	my $can_use_www_engine = 1; 
	my $error              = undef;
    try {

		if($DADA::Config::WWW_ENGINE_OPTIONS->{www_engine} eq 'curl'){
			require LWP::Protocol::Net::Curl;
		}
		else { 
			require LWP;
		}
    }
    catch {
		$can_use_www_engine = 0;
		$error              = $_;  
	};
	return ($can_use_www_engine, $error); 
}

sub can_use_Google_reCAPTCHA { 
	
	# This works, although if we do this, recaptcha shows, but the results don't matter, 
	# effectively making the captcha useless: 
	#
	#my ($can_use_www_engine, $can_use_www_engine_errors) = can_use_www_engine;
	#if($can_use_www_engine == 0){ 
	#	return 0; 
	#}
	
	
	if($DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type} eq 'v2'){
		return can_use_Google_reCAPTCHA_v2(); 
	} elsif($DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type} eq 'v3'){
		return can_use_Google_reCAPTCHA_v3(); 
	} else { 
		return 0;
	}
}

sub can_use_Google_reCAPTCHA_v2 { 
	
	
	if(exists($can_use_cache->{Google_reCAPTCHA_v2})){ 
		return $can_use_cache->{Google_reCAPTCHA_v2}; 
	}
	
	if(can_use_LWP_Protocol_https() == 0){ 
		warn 'LWP::Protocol::https needs to be installed for Google reCAPTCHA support';
		return 0; 
	}
	
	my $can_use_captcha = 1; 
	
	if($DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type} ne 'v2'){ 
		carp "Captcha not set to v2"
			if $t; 
		$can_use_captcha = 0;
	}

	if($can_use_captcha == 1){
		try {
	        require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;
	        $can_use_captcha = 1;
	    } catch {
	        carp "CAPTCHA v2 not working correctly?:" . $_
				if $t; 
	        $can_use_captcha = 0;
	    };
	}
	
	if($can_use_captcha == 1) {
		if(
			   length($DADA::Config::RECAPTCHA_PARAMS->{v2}->{public_key})  <= 0
			|| length($DADA::Config::RECAPTCHA_PARAMS->{v2}->{private_key}) <= 0
		){ 
			warn '$DADA::Config::RECAPTCHA_PARAMS are not set up correctly'
				if $t;
			
			$can_use_captcha = 0; 
		}
	}
	
	$can_use_cache->{Google_reCAPTCHA_v2} = $can_use_captcha;
	
	return $can_use_captcha;
}

sub can_use_Google_reCAPTCHA_v3 { 
	
	if(exists($can_use_cache->{Google_reCAPTCHA_v3})){ 
		return $can_use_cache->{Google_reCAPTCHA_v3}; 
	}
	
	if(can_use_LWP_Protocol_https() == 0){ 
		warn 'LWP::Protocol::https needs to be installed for Google reCAPTCHA support';
		return 0; 
	}
	
	my $can_use_captcha = 1; 
	
	if($DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type} ne 'v3'){ 
		carp "Captcha not set to v3"
		if $t; 
		$can_use_captcha = 0;
	} 
	
	if($can_use_captcha == 1){
		try {
	        require Google::reCAPTCHA::v3;
	        $can_use_captcha = 1;
	    } catch {
	        carp "CAPTCHA v3 not working correctly?:" . $_
				if $t; 
	        $can_use_captcha = 0;
	    };
	}
	
	if($can_use_captcha == 1) {
		if(
			   length($DADA::Config::RECAPTCHA_PARAMS->{v3}->{public_key})  <= 0
			|| length($DADA::Config::RECAPTCHA_PARAMS->{v3}->{private_key}) <= 0
		){ 
			warn '$DADA::Config::RECAPTCHA_PARAMS are not set up correctly'
				if $t;
			
			$can_use_captcha = 0; 
		}
	}
	
	$can_use_cache->{Google_reCAPTCHA_v3} = $can_use_captcha;
	
	return $can_use_captcha;
}

sub validate_recaptcha {

    my ($args) = @_;
    if ( !exists( $args->{-remote_addr} ) ) {
        return 0;
    }
    if ( !exists( $args->{-response} ) ) {
        return 0;
    }

    if ( $DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type} eq 'v2'
        && can_use_Google_reCAPTCHA_v2() )
    {
        require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;
        my $cap = DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA->new;
        my $result =
          $cap->check_answer( 
			  	$args->{-remote_addr}, 
				$args->{-response}, 
			);
        if ( $result->{is_valid} == 1 ) {
            return 1;
        }
        else {
            return 0;
        }
    }
    elsif ($DADA::Config::RECAPTCHA_PARAMS->{recaptcha_type} eq 'v3'
        && can_use_Google_reCAPTCHA_v3()
        && length( $DADA::Config::RECAPTCHA_PARAMS->{v3}->{score_threshold} ) > 0 )
    {
        require Google::reCAPTCHA::v3;
		my $rec = Google::reCAPTCHA::v3->new(
            {
                -secret         => $DADA::Config::RECAPTCHA_PARAMS->{v3}->{private_key},
				-user_agent_obj => make_ua(), 
            }
        );
        my $r = $rec->request(
            {
                -response => $args->{-response},
                -remoteip => $args->{-remote_addr},
            }
        );
		my $success = $r->{success}; 
		my $score   = $r->{score}; 
		
        if (   
			($success)
            && ($score >= $DADA::Config::RECAPTCHA_PARAMS->{v3}->{score_threshold})
			 )
        {
            return 1;
        }
        else {
            return 0;
        }
    }
}


sub can_use_XML_FeedPP { 
	my $can = 1; 
	try {
        require XML::FeedPP;
        $can = 1;
    }
    catch {
        carp . $_
			if $t; 
        $can = 0;
    };
	return $can;
}



sub can_use_JSON { 
	my $can_use_json = 1; 
    try {
        require JSON;
        $can_use_json = 1;
    }
    catch {
        carp "JSON not installed?:" . $_
			if $t;
        $can_use_json = 0;
    };
	return $can_use_json;
}


sub can_use_HTML_Tree {
    my $can_use_HTML_Tree = 1; 
    try { 
        require HTML::Tree;
        require HTML::Element;
        require HTML::TreeBuilder;
        
    } catch { 
        $can_use_HTML_Tree = 0;
    };
    return $can_use_HTML_Tree;
}

sub can_use_net_curl {
    my $net_curl = 1; 
    try { 
        require LWP::Protocol::Net::Curl;      
    } catch { 
		carp 'Can\'t use, LWP::Protocol::Net::Curl: ' . $_
			if $t; 
        $net_curl = 0;
    };
    return $net_curl;
}

sub can_use_mozilla_ca { 
    my $m_ca = 1; 
    try { 
        require Mozilla::CA;      
    } catch { 
		carp 'Can\'t use, Mozilla::CA: ' . $_
			if $t; 
        $m_ca = 0;
    };
    return $m_ca;
}



sub can_use_Amazon_SES {
    my $can_use_Amazon_SES = 1; 
    try { 
        require DADA::App::Support::Net::Amazon::SES;        
    } catch { 
		carp 'Amazon SES is not supported:' . $_
			if $t; 
        $can_use_Amazon_SES = 0;
    };
    return $can_use_Amazon_SES;
}

sub can_use_WebService_Mailgun { 
    my $can_use_WebService_Mailgun = 1; 
    try { 
       # require WebService::Mailgun;
		require DADA::App::Support::WebServiceDDMMailGun;         
    } catch { 
		carp 'WebService::Mailgun is not supported:' . $_
			if $t; 
        $can_use_WebService_Mailgun = 0;
    };
    return $can_use_WebService_Mailgun;

}

sub can_use_StopForumSpam { 

    my $can_use_StopForumSpam = 1; 
    try { 
        require WWW::StopForumSpam;        
    } catch { 
		warn 'WWW::StopForumSpam is not supported:' . $_
			if $t;
        $can_use_StopForumSpam = 0;
    };
    return $can_use_StopForumSpam;
}

sub can_use_Image_Scale { 
    my $can_use_Image_Scale = 1; 
    try { 
        require Image::Scale     
    } catch { 
		warn 'Image::Scale is not supported:' . $_
			if $t;
        $can_use_Image_Scale = 0;
    };
    return $can_use_Image_Scale;
}

sub can_use_Image_Resize { 
    my $can_use_Image_Resize = 1; 
    try { 
        require Image::Resize;        
    } catch { 
		warn 'Image::Resize is not supported:' . $_
			if $t;
        $can_use_Image_Resize = 0;
    };
    return $can_use_Image_Resize;
}

sub can_use_Image_Magick { 
    my $can_use_Image_Magick = 1; 
    try { 
        require Image::Magick;        
    } catch { 
		warn 'Image::Resize is not supported:' . $_
			if $t;
        $can_use_Image_Magick = 0;
    };
    return $can_use_Image_Magick;
}




sub can_use_IO_Socket_SSL { 
    my $can_use_IO_Socket_SSL = 1; 
    try { 
        require IO::Socket::SSL;        
    } catch { 
		warn 'IO::Socket::SSL is not supported:' . $_
			if $t;
        $can_use_IO_Socket_SSL = 0;
    };
    return $can_use_IO_Socket_SSL;
}

sub can_use_LWP_Protocol_https { 
    my $can_use = 1; 
    try { 
        require LWP::Protocol::https;        
    } catch { 
		warn 'IO::Socket::SSL is not supported:' . $_
			if $t;
        $can_use = 0;
    };
    return $can_use;
}


sub formatted_runtime {

    my $d = shift || 0;

    my @int = (
        [ 'second', 1 ],
        [ 'minute', 60 ],
        [ 'hour',   60 * 60 ],
        [ 'day',    60 * 60 * 24 ],
        [ 'week',   60 * 60 * 24 * 7 ],
        [ 'month',  60 * 60 * 24 * 30.5 ],
        [ 'year',   60 * 60 * 24 * 30.5 * 12 ]
    );
    my $i = $#int;
    my @r;
    while ( ( $i >= 0 ) && ($d) ) {
        if ( $d / $int[$i]->[1] >= 1 ) {
            push @r, sprintf "%d %s%s", $d / $int[$i]->[1],
              $int[$i]->[0], ( sprintf "%d", $d / $int[$i]->[1] ) > 1
              ? 's'
              : '';
        }
        $d %= $int[$i]->[1];
        $i--;
    }

    my $runtime;
    if (@r) {
        $runtime = join ", ", @r;
    }
    else {
        $runtime = '0 seconds';
    }

    return $runtime;
}



sub pad_str {

    # DEV: I'd had to rewrite this type of sub, since it's going to be buggy,
    # and there's a million different ones, but, here goes:

    my $str = shift;
    my $padding = shift || 25;

    if ( length($str) > 0 && length($str) < 25 ) {
        $padding = $padding - length($str);
        return $str . ' ' x $padding;
    }
    else {
        return $str;
    }
}



sub ctime_to_localtime { 
    my $ctime = shift; 
    return undef if $ctime eq undef; 
    return scalar localtime($ctime); 
}


sub ctime_to_displaytime { 
    my $ctime    = shift || undef; 
    my $show_hms = shift // 1;
    return undef if $ctime eq undef; 
    require POSIX;
    my $displaytime = undef; 
    if($show_hms == 1) { 
        $displaytime = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime $ctime);
    }
    else { 
        $displaytime = POSIX::strftime('%Y-%m-%d', localtime $ctime);        
    }
    
    return $displaytime;     
}
sub displaytime_to_ctime { 

    my $displaytime = shift;
    return undef if $displaytime eq undef; 
    
    require Time::Local;
    my ( $date, $time ) = split(/ |T/, $displaytime );
    my ( $year, $month,  $day )    = split( '-', $date );
    my ( $hour, $minute, $second ) = split( ':', $time );
    $second = int( $second - 0.5 );    # no idea.
    my $time = Time::Local::timelocal( $second, $minute, $hour, $day, $month - 1, $year );

    return $time;
}


sub hms_to_dislay_hms { 
   
   my $hms  = shift; 
   return undef if $hms eq undef; 


   return 
    sprintf("%02d", ($hms/(60*60))%24) . 
   ':' . 
    sprintf("%02d", ($hms/60)%60) . 
    ':' . 
    sprintf("%02d", $hms%60);
    
}

sub display_hms_to_hms { 
    
    my $display_hms = shift; 
    
    return undef if $display_hms eq undef; 
    
    
    my ($h, $m, $s) = split(':', $display_hms); 
    
    my $sec = (int($h) * 60 * 60) + (int($m) * 60) + int($s);  

    return $sec; 
}

sub naive_csv_split { 
    my $line = shift;
    my $sep = shift || ',';
    my @cells;

    return () unless $line;

    try { 
        $line =~ s/\r?\n$//;

        my $re = qr/(?:^|$sep)(?:"([^"]*)"|([^$sep]*))/;

        while($line =~ /$re/g) {
                my $value = defined $1 ? $1 : $2;
                push @cells, (defined $value ? $value : '');
        }
    } catch { 
        return (); 
    };

    return @cells;
    
}

sub ip_address_logging_filter { 
	my $ip = shift; 
		
	if($DADA::Config::PII_OPTIONS->{ip_address_logging_style} eq 'anonymized'){ 
		return anonymize_ip($ip);
	}
	else { 
		return $ip; 
	}
}
sub anonymize_ip {

	my $ip = shift; 
	
	
		if ($ip =~ m/([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) {
			$ip = $1  . '.' . $2 . '.' . '0' . '.' . '0';
		}
		elsif($ip =~ m/\:/){ 
			try {		
				require Net::IP;
				my $ipv6 = new Net::IP ($ip);
				$ip = $ipv6->ip($ip);
		
				my @parts = split(':', $ip);
				$parts[-1] = '0000'; 
				$parts[-2] = '0000';
				$parts[-3] = '0000';
				$ip = join(':', @parts);  
			} catch { 
				warn $_;
				return $ip; 
			}
		}
	return $ip; 
}



sub commify {
    my $input = shift;
    $input = reverse($input);
    $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    $input = reverse($input);
    return $input;
}

# Which is this here, and not with then other ran generator in DADA::Security::Password?
sub generate_rand_string_md5 {

    #warn "generate_rand_string";

    my $chars = shift
      || 'aAeEiIoOuUyYabcdefghijkmnopqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    my $num = shift || 1024;

    require Digest::MD5;

    my @chars = split '', $chars;
    my $ran;
    for ( 1 .. $num ) {
        $ran .= $chars[ rand @chars ];
    }
    return Digest::MD5::md5_hex($ran);
}

sub list_types { 
    return $DADA::Config::LIST_TYPES;
}


sub Email_Address_parse { 
	#if(HAS_EMAIL_ADDRESS_XS){
	#	require Email::Address::XS; 
	#	return (Email::Address::XS->parse($_[0]));
	#}
	#if(HAS_EMAIL_ADDRESS){ 
		require Email::Address; 
		return (Email::Address->parse($_[0]));	
	#}
}


sub human_readable_filesize { 
	my $fs = shift; 
	
	require Number::Bytes::Human; 
	my $human = Number::Bytes::Human->new(
		round_style => 'round', 
		precision   => 2, 
		bs          => 1024,
	);
	my $human_size = $human->format($fs);
	
	return $human_size;
}

sub create_dir { 
	
	my $dir = shift; 
	
	$dir = make_safer($dir);
	
	warn 'in create_dir'
		if $t; 
	
	warn '$dir: ' . $dir
		if $t;  
	
    if ( !-d $dir ) {
        if ( mkdir( $dir, $DADA::Config::DIR_CHMOD ) ) {
            if ( -d $dir ) {
                chmod( $DADA::Config::DIR_CHMOD, $dir );
            }
        }
    }
	
	if(-d $dir){ 
		warn '$dir exists: ' . $dir
			if $t; 
	}
	else { 
		warn '$dir DOES NOT exist: ' . $dir
			if $t;  
	}
	return 1; 	
}




sub filename_from_url {
	my $url  = shift; 
	
	warn 'in filename_from_url'
		if $t; 
	warn '$url: ' . $url
		if $t; 		
	
	my ($filename) = $url =~ /\/([^\/]*?)(?:\?|$)/;
	
	warn '$filename: ' . $filename
		if $t; 
	
	return $filename; 
	
}


sub path_and_file { 

	my $path   = shift; 
	require File::Basename; 
	
	my($filename, $directories, $suffix) = File::Basename::fileparse($path);
	
	return($directories, $filename); 
	
}


sub new_image_file_path {
	
	warn 'in new_image_file_path'
		if $t; 
	
	my $fn   = shift; 
	my $path = shift; 
	
	warn '$fn: ' . $fn
		if $t; 
	
	my $n_fp = undef; 
	
	my $found_unique = 0; 
	my $limit        = 100; 
	my $tries        = 0; 
	
	$path =~ s/\/$//;
	$fn   =~ s/^\///;
	 
	if (! -e $path . '/' . $fn ) {
		
		# It's unique already!
		return $path . '/' . $fn;
	
	} 
	else { 
	
		while($found_unique == 0){ 
		
			$tries++; 
			if($tries >= $limit){ 
				die "can't create a new file name for, $fn"; 
			}
		    my $try_n_fp = undef; 
		
			my $rand_string = generate_rand_string_md5();
	   
		    my $new_fn    = $rand_string . '-' . $fn;
		       $try_n_fp  = make_safer( 
			   	$path . '/' . $new_fn 
			);
		
			if (-e $try_n_fp ) {
				# rats. 
				next;
			}
			else { 
				$n_fp = $try_n_fp; 
				$found_unique = 1; 
				last;
			}
		}
	}
	warn '$n_fp: ' . $n_fp
		if $t; 
	
	return $n_fp; 
}


sub simple_printout_file { 
	
	warn 'in simple_printout_file'
		if $t; 

	my $fp   = shift; 
	my $ref  = shift; 
	
    open( OUTFILE, '>', $fp ) or die( "can't write to " . $fp . ": $!" );
	print OUTFILE $$ref or die $!;
	close(OUTFILE) or die $!;
    chmod( $DADA::Config::FILE_CHMOD, $fp );
	
}





=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2023 Justin Simoni 

https://justinsimoni.com 

All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut





1; 
