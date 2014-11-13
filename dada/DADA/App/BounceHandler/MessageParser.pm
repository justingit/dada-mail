package DADA::App::BounceHandler::MessageParser;

use strict;
use lib qw(../../../ ../../../DADA/perllib);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use 5.008_001;
use Mail::Verp;
use Try::Tiny; 

use Carp qw(croak carp);
use vars qw($AUTOLOAD);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_BounceHandler};

if($t == 1){ 
	require Data::Dumper;
}
my %allowed = ();

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my %args = (@_);
    $self->_init( \%args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {

    my $self = shift;
    my $args = shift;
}

sub run_all_parses {

    my $self        = shift;
    my ($entity)    = shift;
    my $email       = '';
    my $list        = '';
    my $diagnostics = {};

    $email = $self->find_verp($entity);

	# Amazon SES is sort of special, since it's very, very easy to understand if
	# It's coming from it: 
	if($self->bounce_from_ses($entity)){ 
		warn "bounce_from_ses"
			if $t; 
			
		  my ( $ses_list, $ses_email, $ses_diagnostics ) =
	          $self->parse_for_amazon_ses($entity);
	        $list  ||= $ses_list;
	        $email ||= $ses_email;
			
			warn "list: $list" 
				if $t; 
			warn "email: $email" 
				if $t; 	
			warn "diagnostics: \n" . Data::Dumper::Dumper($ses_diagnostics)
				if $t; 
			
			$diagnostics = $self->_fold_in_diagnostics($diagnostics, $ses_diagnostics); 
		}
	elsif($self->bounce_is_amazon_ses_abuse_report($entity)){ 
	    
        warn "bounce_is_amazon_ses_abuse_report"
			if $t; 
		  my ( $sesa_list, $sesa_email, $sesa_diagnostics ) =
  	          $self->parse_for_ses_abuse_report($entity);
  	        
  	          $list  ||= $sesa_list;
              $email ||= $sesa_email;
              
  	          $diagnostics = $self->_fold_in_diagnostics($diagnostics, $sesa_diagnostics); 
  	          
    }
	elsif($self->isa_rfc6522_bounce($entity)) { 
		warn "isa_rfc6522_bounce"
			if $t; 
			
	  my ( $rfc6522_list, $rfc6522_email, $rfc6522_diagnostics ) =
          $self->parse_for_rfc6522($entity);
        $list  ||= $rfc6522_list;
        $email ||= $rfc6522_email;

		warn "list: $rfc6522_list" 
			if $t; 
		warn "email: $rfc6522_email" 
			if $t; 
		warn "diagnostics: \n" . Data::Dumper::Dumper($rfc6522_diagnostics)
			if $t; 
			
          $diagnostics = $self->_fold_in_diagnostics($diagnostics, $rfc6522_diagnostics); 
          
	} 
	else { 
	    
	}
	
	if(defined($email) && length($email) < 1) { undef($email); }
    if(defined($list) && length($list) < 1) { undef($list);}
    
    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {

		warn "bounce_from_secureserver_dot_net"
			if $t; 


		  my ( $ss_list, $ss_email, $ss_diagnostics ) =
	          $self->parse_for_secureserver_dot_net($entity);

			warn "list: $ss_list" 
				if $t; 
			warn "email: $ss_email" 
				if $t; 
			warn "diagnostics: \n" . Data::Dumper::Dumper($ss_diagnostics)
				if $t; 

	        $list  ||= $ss_list;
	        $email ||= $ss_email;

	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $ss_diagnostics); 

	
	if(defined($email) && length($email) < 1) { undef($email); }
    if(defined($list) && length($list) < 1) { undef($list);}
    
    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {

		warn "generic_parse"
			if $t; 
		
	    my ( $gp_list, $gp_email, $gp_diagnostics ) = $self->generic_parse($entity);
	
		warn "list: $gp_list" 
			if $t; 
		warn "email: $gp_email" 
			if $t; 
		warn "diagnostics: \n" . Data::Dumper::Dumper($gp_diagnostics)
			if $t; 

		if(!$list) { 
	    	$list = $gp_list;
		}
		if(!$email){ 
	    	$email = $gp_email;
	    }
	    
	    $diagnostics = $self->_fold_in_diagnostics($diagnostics, $gp_diagnostics); 

		# This should really do the same thing, first look for tell-tale signs
		# that the bounce is a qmail-like bounce, before parsing it out. 
		# (and along down the line...)
    
    }
        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
		
			warn "parse_for_qmail"
				if $t; 
		
	        my ( $qmail_list, $qmail_email, $qmail_diagnostics ) =
	          $self->parse_for_qmail($entity);
	
			warn "list: $qmail_list" 
				if $t; 
			warn "email: $qmail_email" 
				if $t; 
			warn "diagnostics: \n" . Data::Dumper::Dumper($qmail_diagnostics)
				if $t; 
	
	        $list  ||= $qmail_list;
	        $email ||= $qmail_email;
	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $qmail_diagnostics); 
	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
	    
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
	        
			warn "parse_for_exim"
				if $t; 

			my ( $exim_list, $exim_email, $exim_diagnostics ) =
	          $self->parse_for_exim($entity);

			warn "list: $exim_list" 
				if $t; 
			warn "email: $exim_email" 
				if $t; 
			warn "diagnostics: \n" . Data::Dumper::Dumper($exim_diagnostics)
				if $t; 
				
				$list  ||= $exim_list;
	        	$email ||= $exim_email;				
	        	
			$diagnostics = $self->_fold_in_diagnostics($diagnostics, $exim_diagnostics); 

	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
        
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
			warn "parse_for_f__king_exchange"
				if $t; 
				
	        my ( $ms_list, $ms_email, $ms_diagnostics ) =
	          $self->parse_for_f__king_exchange($entity);
	
			warn "list: $ms_list" 
				if $t; 
			warn "email: $ms_email" 
				if $t; 
			warn "diagnostics: \n" . Data::Dumper::Dumper($ms_diagnostics)
				if $t; 
	
	        $list  ||= $ms_list;
	        $email ||= $ms_email;
	        
	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $ms_diagnostics); 
			
	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
			warn "parse_for_novell"
				if $t; 
				
	        my ( $nv_list, $nv_email, $nv_diagnostics ) =
	          $self->parse_for_novell($entity);
	
			warn "list: $nv_list" 
				if $t; 
			warn "email: $nv_email" 
				if $t; 
			warn "diagnostics: \n" . Data::Dumper::Dumper($nv_diagnostics)
				if $t; 
	
	
	        $list  ||= $nv_list;
	        $email ||= $nv_email;
            $diagnostics = $self->_fold_in_diagnostics($diagnostics, $nv_diagnostics); 
  	        
  	        
	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
        
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
	        
	        my ( $g_list, $g_email, $g_diagnostics ) =
	          $self->parse_for_gordano($entity);
	        $list  ||= $g_list;
	        $email ||= $g_email;
	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $g_diagnostics); 
              
              
	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
        
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
	        
	        my ( $y_list, $y_email, $y_diagnostics ) =
	          $self->parse_for_overquota_yahoo($entity);
	        $list  ||= $y_list;
	        $email ||= $y_email;

	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $y_diagnostics); 
  	        
	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
        
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {
	        my ( $el_list, $el_email, $el_diagnostics ) =
	          $self->parse_for_earthlink($entity);
	        $list  ||= $el_list;
	        $email ||= $el_email;
	        
	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $el_diagnostics); 

	    }

        if(defined($email) && length($email) < 1) { undef($email); }
        if(defined($list) && length($list) < 1) { undef($list);}
        
	    if ( ( !defined($list) ) || ( !defined($email) ) || !keys %{$diagnostics} ) {	        my ( $wl_list, $wl_email, $wl_diagnostics ) =
	          $self->parse_for_windows_live($entity);

	        $list  ||= $wl_list;
	        $email ||= $wl_email;
	        
	        $diagnostics = $self->_fold_in_diagnostics($diagnostics, $wl_diagnostics); 

	    }

	    # This is a special case - since this outside module adds pseudo diagonistic
	    # reports, we'll say, add them if they're NOT already there:
#
#		    my ( $bp_list, $bp_email, $bp_diagnostics ) =
#		      $self->parse_using_m_ds_bp($entity);
#
#		    # There's no test for these in the module itself, so we
#		    # won't even look for them.
#		    #$list  ||= $bp_list;
#		    #$email ||= $bp_email;
#
#		    %{$diagnostics} = ( %{$diagnostics}, %{$bp_diagnostics} )
#		      if $bp_diagnostics;


	}
    chomp($email) if $email;

    #small hack, turns, %2 into, '-'
    $list =~ s/\%2d/\-/g;

    $list = strip($list);

    if ( !$diagnostics->{'Message-Id'} ) {
        $diagnostics->{'Message-Id'} =
          $self->find_message_id_in_headers($entity);
        if ( !$diagnostics->{'Message-Id'} ) {
            $diagnostics->{'Message-Id'} =
              $self->find_message_id_in_body($entity);
        }
    }

    if ( $diagnostics->{'Message-Id'} ) {
        $diagnostics->{'Simplified-Message-Id'} = $diagnostics->{'Message-Id'};
        $diagnostics->{'Simplified-Message-Id'} =~ s/\<|\>//g;
        $diagnostics->{'Simplified-Message-Id'} =~ s/\.(.*)//;    #greedy
        $diagnostics->{'Simplified-Message-Id'} =
          strip( $diagnostics->{'Simplified-Message-Id'} );
    }
	
    return ( $email, $list, $diagnostics );
}

sub _fold_in_diagnostics {
    
    my $self   = shift; 
    my $orig_d = shift || {}; 
    my $new_d  = shift || {}; 
        
    foreach my $key2 ( keys %{$new_d} )
        {
        if( exists $orig_d->{$key2} )
            {
          #  warn "Key [$key2] is in both hashes!";
            
                if(length($new_d->{$key2}) > 0){ 
                    $orig_d->{$key2} = $new_d->{$key2};
                }
                else { 
                   # warn "keeping old value."; 
                }
            }
        else
            {
            $orig_d->{$key2} = $new_d->{$key2};
            }
        }
        
    use Data::Dumper; 
    # warn 'diag now looks like this: ' . Dumper($orig_d); 
    return $orig_d; 
        
}


sub find_verp {

    my $self   = shift;
    my $entity = shift;
    my $mv     = Mail::Verp->new;
    $mv->separator($DADA::Config::MAIL_VERP_SEPARATOR);
    if ( $entity->head->count('To') > 0 ) {
        my ( $sender, $recipient ) =
          $mv->decode( $entity->head->get( 'To', 0 ) );
        return $recipient || undef;
    }
    return undef;
}

sub generic_parse {

    my $self   = shift;
    my $entity = shift;
    my ( $email, $list );
    my %return       = ();
    my $headers_diag = {};
    $headers_diag = $self->get_orig_headers($entity);
    my $diag = {};
    ( $email, $diag ) = $self->find_delivery_status($entity);

    if ( keys %$diag ) {
        %return = ( %{$diag}, %{$headers_diag} );
    }
    else {
        %return = %{$headers_diag};
    }

    $list   = $self->find_list_in_list_headers($entity);
    $list ||= $self->generic_body_parse_for_list($entity);

    $email = DADA::App::Guts::strip($email);
    $email =~ s/^\<|\>$//g if $email;
	if(!$email) { 
		$email = $self->generic_body_parse_for_email($entity); 
	}

    $list = DADA::App::Guts::strip($list) if $list;
    
    return ( $list, $email, \%return );

}

sub get_orig_headers {

    my $self   = shift;
    my $entity = shift;
    my $diag   = {};

    for ( 'From', 'To', 'Subject' ) {

        if ( $entity->head->count($_) ) {

            my $header = $entity->head->get( $_, 0 );
            chomp $header;
            $diag->{ 'Bounce_' . $_ } = $header;
        }

    }

    return $diag;

}

sub find_delivery_status {

    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;

    my $diag = {};

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'message/delivery-status' ) {
            ( $email, $diag ) = $self->generic_delivery_status_parse($entity);
            return ( $email, $diag );
        }
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $email, $diag ) = $self->find_delivery_status($part);
            if ( ($email) && ( keys %$diag ) ) {
                return ( $email, $diag );
            }
        }
    }
}

sub find_mailer_bounce_headers {

    my $self   = shift;
    my $entity = shift;
    my $mailer = $entity->head->get( 'X-Mailer', 0 );
    $mailer =~ s/\n//g;
    return $mailer if $mailer;

}

sub find_list_in_list_headers {

    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $list;
	my $orig_msg_copy = undef; 
	
    if ( $entity->head->mime_type eq 'message/rfc822') {
        $orig_msg_copy = $parts[0];
		$list = $self->list_in_list_headers($orig_msg_copy);      
    }
	elsif($entity->head->mime_type eq 'text/rfc822-headers'){ 

	    require MIME::Parser;
	    my $parser = new MIME::Parser;
	    $parser = optimize_mime_parser($parser);

	    eval {
	        $orig_msg_copy = $parser->parse_data( $entity->bodyhandle->as_string );
	    };
	    if ($@) {
	        warn "Trouble parsing text/rfc822-headers message. $@";
	    }
	    else {
	    }
		$list = $self->list_in_list_headers($orig_msg_copy);
	}
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $list = $self->find_list_in_list_headers($part);
            return $list if $list;
        }
    }
}


sub list_in_list_headers {
    my $self   = shift;
    my $entity = shift;
    my $list   = undef;	
    my $list_header = $entity->head->get( 'List', 0 ) || undef;
    
    if(defined($list_header)){ 
		if($list_header !~ /\:/) { 
			$list = $list_header;
		}
	}
	
    if ( !$list ) {
        $list_header = $entity->head->get( 'X-List', 0 );
        $list = $list_header if $list_header !~ /\:/;
    }
    if ( !$list ) {
        my $list_id = $entity->head->get( 'List-ID', 0 );
        if ( $list_id =~ /\<(.*?)\./ ) {
            $list = $1 if $1 !~ /\:/;
        }
    }
    if ( !$list ) {
        my $list_sub = $entity->head->get( 'List-Subscribe', 0 );
        if ( $list_sub =~ /l\=(.*?)\>/ ) {
            $list = $1;
        }
    }
    chomp $list;
    return $list;
}


sub find_message_id_in_headers {

    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $mid;
    
    if ( $entity->head->mime_type eq 'message/rfc822' || $entity->head->mime_type eq 'text/rfc822-headers') {
        my $orig_msg_copy = ''; 
		require MIME::Parser;
        my $parser = new MIME::Parser;
        $parser = optimize_mime_parser($parser);

		if($entity->head->mime_type eq 'text/rfc822-headers') { 			
			eval { $orig_msg_copy = $parser->parse_data($entity->bodyhandle->as_string) };
			if ( $@ ) {
				warn "Trouble parsing text/rfc822-headers message. $@"; 
			}
			else { 
			}
		}
		else { 
            
		   $orig_msg_copy = $parts[0]; 
           my $munge = $orig_msg_copy->as_string; 
           if($munge =~ m/^\n/) { # you've got to be kidding me...
                $munge =~ s/^\n//; 
                $orig_msg_copy = $parser->parse_data($munge);
            }
            
            undef $munge; 
		}
		
	
		# Amazon SES finds this in the, "X-Message-ID" header: 
		# Amazon SES will also set its own Message-ID. Maddening!
        
		if($orig_msg_copy->head->get( 'X-Message-ID', 0 )){ 		    
			$mid = $orig_msg_copy->head->get( 'X-Message-ID', 0 );
		}
		else { 
        	$mid = $orig_msg_copy->head->get( 'Message-ID', 0 );
        }
        
		$mid = strip($mid);
        chomp($mid);
        return $mid;
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $mid = $self->find_message_id_in_headers($part);
            return $mid if $mid;
        }
    }
}

sub find_message_id_in_body {

    my $self   = shift;
    my $entity = shift;
    my $m_id;

    my @parts = $entity->parts;

    # for singlepart stuff only.
    if ( !@parts ) {

        my $body = $entity->bodyhandle;
        my $IO;

        return undef if !defined($body);

        if ( $IO = $body->open("r") ) {    # "r" for reading.
            while ( defined( $_ = $IO->getline ) ) {
                chomp($_);
                if ( $_ =~ m/^Message\-Id\:(.*?)$/ig ) {

                    #yeah, sometimes the headers are in the body of
                    #an attached message. Go figure.
                    $m_id = $1;
                }
            }
        }

        $IO->close;
        $m_id = strip($m_id);
        return $m_id;
    }
    else {
        return undef;
    }
}

sub generic_delivery_status_parse {

    my $self   = shift;
    my $entity = shift;
    my $diag   = {};
    my $email;

    # sanity check
    #if($delivery_status_entity->head->mime_type eq 'message/delivery-status'){
    my $body = $entity->bodyhandle;
    my @lines;
    my $IO;
    my %bodyfields;
    if ( $IO = $body->open("r") ) {    # "r" for reading.
        while ( defined( $_ = $IO->getline ) ) {
            if ( $_ =~ m/\:/ ) {
                my ( $k, $v ) = split( ':', $_ );
                chomp($v);

                #$bodyfields{$k} = $v;
                $diag->{$k} = $v;
            }
        }
        $IO->close;
    }

    if ( $diag->{'Diagnostic-Code'} =~ /X\-Postfix/ ) {
        $diag->{Guessed_MTA} = 'Postfix';
    }

	my $rfc    = undef; 
	my $remail = undef; 
	if(exists($diag->{'Original-Recipient'})){ 
		( $rfc, $remail ) = split( ';', $diag->{'Original-Recipient'} );
	}
	elsif(exists($diag->{'Final-Recipient'})){ 
		( $rfc, $remail ) = split( ';', $diag->{'Final-Recipient'} );	
		if ( $remail eq '<>' ) {    #example: Final-Recipient: LOCAL;<>
	    	$remail = undef; 
		}
	}
	elsif(exists($diag->{'Original-Rcpt-To'})){ 
	    $remail = $diag->{'Original-Rcpt-To'}; 
	}
	# Seeeeeriously:
	elsif(exists($diag->{'Original-Rcpt-to'})){ 
	    $remail = $diag->{'Original-Rcpt-to'}; 
	}

    $email = $remail;

    #
	# Or, use Email::Address
	if($email =~ m/(.*?)\<(.*?)\>/) { 
		$email = $2; 
	}

    for ( keys %$diag ) {
        $diag->{$_} = strip( $diag->{$_} );
    }
	chomp ($email);
	$email =~ s/\n$//g;
	$email =~ s/\r$//g;
	
    return ( $email, $diag );
}

sub generic_body_parse_for_list {

    my $self   = shift;
    my $entity = shift;
    my $list;

    my @parts = $entity->parts;
    if ( !@parts ) {
        $list = $self->find_list_from_unsub_link($entity);
        return $list if $list;
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $list = $self->generic_body_parse_for_list($part);
            if ($list) {
                return $list;
            }
        }
    }
}

sub generic_body_parse_for_email {

    my $self   = shift;
    my $entity = shift;
    my $email;

    my @parts = $entity->parts;
    if ( !@parts ) {

	    my $body = $entity->bodyhandle;
	    my $IO;
		
	    return undef if !defined($body);

        
	    if ( $IO = $body->open("r") ) {    # "r" for reading.
	        while ( defined( $_ = $IO->getline ) ) {	            
	            chomp($_);
				if($_ =~ m/Your message to \<(.*?)\> was automatically rejected/){ 
					return $1; 
				}
				elsif($_ =~ m/Recipient a(d{1,2})ress\: (.*?)$/i) {    
                    my $email = $2; 
                    $email =~ s/\=20$//; 
				    return $email; 
				}
			}
		}
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            $email = $self->generic_body_parse_for_email($part);
            if ($email) {
                return $email;
            }
        }
    }
}




sub find_list_from_unsub_link {

    my $self   = shift;
    my $entity = shift;
    my $list;

    my $body = $entity->bodyhandle;
    my $IO;

    return undef if !defined($body);

    if ( $IO = $body->open("r") ) {    # "r" for reading.
        while ( defined( $_ = $IO->getline ) ) {
            chomp($_);

# DEV: BUGFIX:
# 2351425 - 3.0.0 - find_list_from_unsub_list sub out-of-date
# https://sourceforge.net/tracker2/?func=detail&aid=2351425&group_id=13002&atid=113002
            if ( $_ =~ m/$DADA::Config::PROGRAM_URL\/(u|list)\/(.*?)\// ) {
                $list = $2;
				if($list =~ m/\"\>/){ # We've picked up a screwy link in HTML.
					undef $list;
				}
            }

            # /DEV: BUGFIX
            elsif ( $_ =~ m/^List\:(.*?)$/ ) {

                #yeah, sometimes the headers are in the body of
                #an attached message. Go figure.
                $list = $1;
            }
            elsif ( $_ =~ m/(.*?)\?l\=(.*?)\&f\=u\&e\=/ ) {
                $list = $2;
            }
            elsif ( $_ =~ m/(.*?)\?f\=u\&l\=(.*?)\&e\=/ ) {
                $list = $2;
            }
        }
    }

    $IO->close;
    return $list;
}

sub bounce_from_ses { 
	my $self = shift; 
	my $entity = shift; 
	# As far as I know, it's all from: 
	my $amazon_ses_from1 = 'MAILER-DAEMON@email-bounces.amazonses.com'; 
	my $qm_ses1 = quotemeta($amazon_ses_from1); 
	
	my $amazon_ses_from2 = 'MAILER-DAEMON@amazonses.com'; 
	my $qm_ses2 = quotemeta($amazon_ses_from2); 

	if($entity->head->get( 'From', 0 ) =~ m/$qm_ses1|$qm_ses2/){ 
		return 1; 
	}
	else { 
		return 0; 
	}
}

sub bounce_is_amazon_ses_abuse_report { 
    my $self = shift; 
	my $entity = shift; 
	# As far as I know, it's all from: 
	my $amazon_ses_from1 = 'complaints@email-abuse.amazonses.com'; 
	my $qm_ses1 = quotemeta($amazon_ses_from1); 
	
	if($entity->head->get( 'From', 0 ) =~ m/$qm_ses1/){ 
		return 1; 
	}
	else { 
		return 0; 
	}
}

sub isa_rfc6522_bounce {
    my $self   = shift;
    my $entity = shift;
#	print '$entity->effective_type ' . $entity->effective_type . "\n"; 
#	print '$entity->head->mime_attr(\'content-type.report-type\'); ' . $entity->head->mime_attr('content-type.report-type') . "\n"; 
	
    if (   $entity->effective_type eq 'multipart/report'
        && $entity->head->mime_attr('content-type.report-type') eq 'delivery-status' )
    {
        return 1;
    }
    else {
        return 0;
    }
}


sub bounce_from_secureserver_dot_net { 
	my $self = shift; 
	my $entity = shift; 
	# As far as I know, it's all from: 
	my $secure_server_from_fragment = 'secureserver.net'; 
	my $qm = quotemeta($secure_server_from_fragment); 
	
	if($entity->head->get( 'From', 0 ) =~ m/$qm/){ 
		return 1; 
	}
	else { 
		return 0; 
	}
}



sub parse_for_amazon_ses { 
	my $self = shift; 
	my $entity = shift; 
	my ( $list, $email, $diag ) = $self->parse_for_rfc6522($entity);
	$diag->{Guessed_MTA} = 'Amazon_SES'; 
	return ( $list, $email, $diag );
}


sub parse_for_rfc6522 { 
	
	my $self   = shift; 
	my $entity = shift; 
	
	my $diag = {};
	my $email; 
	my $list; 
	
	my @parts = $entity->parts; 
	
	# Human readable 
	my $notification = ''; 
	if($parts[0]){ 
		 $notification = $self->generic_human_readable_parse($parts[0]);
	}
	if($parts[1]){ 
		my $mds_entity = $parts[1];
		
		if ( $mds_entity->head->mime_type eq 'message/delivery-status' ) {
	    	( $email, $diag ) = $self->generic_delivery_status_parse($mds_entity);
		}
	}
	if($parts[2]){ 
		my $orig_msg_entity = $parts[2];
		if ( $orig_msg_entity->head->mime_type eq 'message/rfc822'
		||  $orig_msg_entity->head->mime_type eq 'text/rfc822-headers'
		 ) {
			$list = $self->find_list_in_list_headers($orig_msg_entity);	
			$diag->{'Message-Id'} = $self->find_message_id_in_headers($orig_msg_entity);
		}
	}
	$diag->{'Notification'} = $notification
		if defined $notification;
	
	$diag->{parsed_by} .= 'parse_for_rfc6522'; 
    $email =~ s/\<|\>//g; 
	$email = strip($email); 
	return ( $list, $email, $diag );
	
}


sub parse_for_ses_abuse_report { 

	my $self   = shift; 
	my $entity = shift; 
	
	my $diag = {};
	my $email; 
	my $list; 
	
	my @parts = $entity->parts; 
	
	# Human readable 
	my $notification = ''; 
	if($parts[0]){ 
		 $notification = $self->generic_human_readable_parse($parts[0]);
	}
	if($parts[1]){ 
		my $mds_entity = $parts[1];
		if ( $mds_entity->head->mime_type eq 'message/feedback-report' ) {
	    	( $email, $diag ) = $self->generic_delivery_status_parse($mds_entity);
		}
	}

# This is NOT working correctly: 
    if($parts[2]){ 
		my $orig_msg_entity = $parts[2];
        $diag->{'Message-Id'} = $self->find_message_id_in_headers($orig_msg_entity);
        


#		if ( $orig_msg_entity->head->mime_type eq 'message/rfc822'
#		||  $orig_msg_entity->head->mime_type eq 'text/rfc822-headers'
#		 ) {		    
#   	    $list = $self->find_list_in_list_headers($orig_msg_entity);	
#			$diag->{'Message-Id'} = $self->find_message_id_in_headers($orig_msg_entity);
#		    warn 'checking if these do anythig...'; 
#		    warn '$list ' . $list; 
#		    warn q|$diag->{'Message-Id'} | . $diag->{'Message-Id'}; 
#		    
#		}
	}
	$diag->{Notification} = $notification
		if defined $notification;
	$diag->{parsed_by} .= 'parse_for_ses_abuse_report'; 
    $email =~ s/\<|\>//g; 
	$email = strip($email); 
	return ( $list, $email, $diag );

}


sub generic_human_readable_parse { 
	my $self   = shift;
	my $entity = shift; 
	my $msg; 
	try {
		$msg =  $entity->bodyhandle->as_string; 
	} catch { 
		carp "Problems creating generic_human_readable_parse: '$_'";
	};
	return $msg; 
}


sub parse_for_secureserver_dot_net { 
	
	# This seems to be qmail. Sometimes. 
	
	warn 'parse_for_secureserver_dot_net ' 
	    if $t; 
	    
	my $self   = shift; 
	my $entity = shift; 
	
	my $diag = {};
	my $email; 
	my $list;	
	
	# <subscriber@example.com>:
	# child status 100...The e-mail message could not be delivered because the user's mailfolder is full.
	

	my @parts = $entity->parts; 
	if(scalar @parts == 0){ 
		my $body =  $entity->bodyhandle; 
		# Your mail message to the following address(es) could not be delivered. This
		# is a permanent error. Please verify the addresses and try again. If you are
		# still having difficulty sending mail to these addresses, please contact
		# Customer Support at 480-624-2500.
		
		# tell me why I'm not using the range operator? 
		my $begin   = quotemeta('Your mail message to the following address(es) could not be delivered'); 
		my $begin1  = quotemeta('Customer Support at 480-624-2500.');
 		my $begin2  = quotemeta("This is a permanent error; I've given up. Sorry it didn't work out.");

		my $end = quotemeta('--- Below this line is a copy of the message.');
		my $stuff = ''; 
		my $state = 0; 
		
		my $IO;
        if ( $IO = $body->open("r") ) {    # "r" for reading.
            while ( defined( $_ = $IO->getline ) ) {
   				my $data = $_;
                if($data =~ /$begin|$begin1|$begin2/) { 
					$state = 1;
                	#next;
					# print "state == 1\n"; 
				}
				if($data =~ /$end/){ 
					$state = 0;
					last; 
				}
				if ( $state == 1 ) {
					# print "adding stuff!\n";
                	$stuff .= $data; 
				}

			}
		}
		# print "all the stuff:\n$stuff\n"; 
		$diag->{'Notification'} = $stuff
		 if defined $stuff;
		$stuff =~ m/\<(.*?)\>\:(.*)/ms; 
	 	$email =  $1;
		$email = strip($email); 
		$diag->{'Diagnostic-Code'} = $2; 
		$diag->{'Diagnostic-Code'} = strip($diag->{'Diagnostic-Code'}); 

		undef $IO; 
		undef $stuff; 
		undef $state;
		
		#$list = $self->generic_body_parse_for_list($entity); 
		
		# Right now, I only have rules for, mailbox full kin of stuff so if it's not one of those , 
	    # I'd rather this be parsed with the Qmail stuff, 
		# Looks like invalid mailboxes are handled by the local mail server ala: 
		# SMTP error from remote mail server after RCPT TO:<bouncedaddress@example.org>:
		#   host mail.example.org [...]: 550 sorry, no mailbox here by that name. (#5.7.17)
		if($diag->{'Diagnostic-Code'} =~ m/mailfolder is full|Mail quota exceeded/){ 
			$diag->{Guessed_MTA} = 'secureserver_dot_net'; 
		}
		
		# This is strange, as the "orginal" message is embedded within the error report - after, 
		# --- Below this line is a copy of the message.
		# Which is stupid: 
		
		my $stuff = ''; 
		my $state = 0;
		
		my $IO;
        if ( $IO = $body->open("r") ) {    # "r" for reading.
            while ( defined( $_ = $IO->getline ) ) {
   				my $data = $_;
                if($data =~ /$end/) { # End is just a new beginning... 
					$state = 1;
                	next;
				}
				if ( $state == 1 ) {
                	$stuff .= $data; 
				}
				# And this just goes to the end of the message. 

			}
		}
		undef $IO; 
		# And then, just do a generic parse on the original message: 
		require MIME::Parser;
	    my $parser = new MIME::Parser;
	    $parser = optimize_mime_parser($parser);
	    
	   	my $copy_entity;
		$stuff =~ s/^(\n|\r)//ms; 
       eval { $copy_entity = $parser->parse_data($stuff) };
		if($@){ 
			carp "problems with parsing entity: $@";
		}

	
#		my ( $gp_list, $gp_email, $gp_diagnostics ) = $self->generic_parse($copy_entity);

		my $gp_list   = $self->list_in_list_headers($copy_entity);
        # warn '$gp_list ' . $gp_list; 

	    $list  ||= $gp_list;
#		$email ||= $gp_email; 
#		%{$diag} = ( %{$diag}, %{$gp_diagnostics} )
#			if $gp_diagnostics;
	} 
	return ( $list, $email, $diag );
	
}




sub parse_for_qmail {

    my $self = shift;

# When I'm bored
# => http://cr.yp.to/proto/qsbmf.txt
# => http://mikoto.sapporo.iij.ad.jp/cgi-bin/cvsweb.cgi/fmlsrc/fml/lib/Mail/Bounce/Qmail.pm

    my $entity = shift;
    my ( $email, $list );
    my $diag  = {};
    my @parts = $entity->parts;

    my $state    = 0;
    my $pattern  = 'Hi. This is the';
    my $pattern2 = 'Your message has been enqueued by';
    my $pattern3 = 'Customer Support at 480-624-2500.'; # This is lame - Customer Support at 480-624-2500.
     
    my $end_pattern  = '--- Undelivered message follows ---';
    my $end_pattern2 = '--- Below this line is a copy of the message.';
    my $end_pattern3 = '--- Enclosed is a copy of the message.';
    my $end_pattern4 = 'Your original message headers are included below.';

    my ( $addr, $reason );
	
	
    if ( !@parts ) {
        my $body = $entity->bodyhandle;
        my $IO;
        if ($body) {
            if ( $IO = $body->open("r") ) {    # "r" for reading.
				my $notification = undef; 
                while ( defined( $_ = $IO->getline ) ) {

                    my $data = $_;
                    $state = 1 if $data =~ /$pattern|$pattern2|$pattern3/;
                    $state = 0
                      if $data =~ /$end_pattern|$end_pattern2|$end_pattern3/;

                    if ( $state == 1 ) {
						$notification .= $_; 
                        $data =~ s/\n/ /g;

                        if ( $data =~ /\t(\S+\@\S+)/ ) {
                            $email = $1;
                        }
                        elsif ( $data =~ /\<(\S+\@\S+)\>:\s*(.*)/ ) {
                            ( $addr, $reason ) = ( $1, $2 );
                            $diag->{Action} = $reason;
                            my $status = '5.x.y';
                            if ( $data =~ /\#(\d+\.\d+\.\d+)/ ) {
                                $status = $1;
                            }
                            elsif ( $data =~ /\s+(\d{3})\s+/ ) {
                                my $code = $1;
                                $status = '5.x.y' if $code =~ /^5/;
                                $status = '4.x.y' if $code =~ /^4/;

                                $diag->{Status} = $status;
                                $diag->{Action} = $code;

                            }

                            $email = $addr;
                            $diag->{Guessed_MTA} = 'Qmail';

                        }
                        elsif ( $data =~ /(.*)\s\(\#(\d+\.\d+\.\d+)\)/ )
                        { # Recipient's mailbox is full, message returned to sender. (#5.2.2)

                            $diag->{'Diagnostic-Code'} = $1;
                            $diag->{Status}            = $2;
                            $diag->{Guessed_MTA}       = 'Qmail';

                        }
                        elsif ( $data =~
/Remote host said:\s(\d{3})\s(\d+\.\d+\.\d+)\s\<(\S+\@\S+)\>(.*)/
                          )
                        { # Remote host said: 550 5.1.1 <xxx@xxx>... Account is over quota. Please try again later..[EOF]

                            $diag->{Status}            = $2;
                            $email                     = $3;
                            $diag->{'Diagnostic-Code'} = $4;
                            $diag->{Action} = 'failed'; #munging this for now...
                            $diag->{'Final-Recipient'} =
                              'rfc822';                 #munging, again.

                        }
                        elsif ( $data =~
                            /Remote host said:\s(.*?)\s(\S+\@\S+)\s(.*)/ )
                        {

                            my $status;
                            $email ||= $2;

                            $status ||= $1;
                            $diag->{Status} ||= '5.x.y' if $status =~ /^5/;
                            $diag->{Status} ||= '4.x.y' if $status =~ /^4/;
                            $diag->{'Diagnostic-Code'} = $data;
                            $diag->{Guessed_MTA} = 'Qmail';

                        }
                        elsif ( $data =~ /Remote host said:\s(\d{3}.*)/ ) {

                            $diag->{'Diagnostic-Code'} = $1;
                        }
                        elsif ( $data =~ /\d{3}(\-|\s)\d+\.\d+\.\d+/ )
                        {    #550-5.1.1 550 5.1.1
                            if ( !exists( $diag->{'Diagnostic-Code'} ) ) {
                                $diag->{'Diagnostic-Code'} = '';
                            }
                            $diag->{'Diagnostic-Code'} .= $data;
                        }
                        elsif ( $data =~ /(.*)\s\(\#(\d+\.\d+\.\d+)\)/ ) {

                            $diag->{'Diagnostic-Code'} = $1;
                            $diag->{Status} = $2;

                        }
                        elsif ( $data =~ /(No User By That Name)/ ) {

                            $diag->{'Diagnostic-Code'} = $data;
                            $diag->{Status} = '5.x.y';

                        }
                        elsif (
                            $data =~ /(This address no longer accepts mail)/ )
                        {

                            $diag->{'Diagnostic-Code'} = $data;

                        }
                        elsif ( $data =~
                            /The mail system will continue delivery attempts/ )
                        {
                            $diag->{Guessed_MTA} = 'Qmail';
                            $diag->{'Diagnostic-Code'} = $data;
                        }
						elsif($data =~ m/user is over quota/){ 
                            $diag->{Guessed_MTA} = 'Qmail';
                            $diag->{'Diagnostic-Code'} = $data;							
						}
                    }
                }
				
				$diag->{Notification} = $notification
					if defined $notification;
            }

# Not Good:
#			if(!defined($diag->{Action})){
#				if($diag->{'Diagnostic-Code'} =~ m/The email account that you tried to reach does not exist/){
#					$diag->{Action} = 'failed';
#				}
#			}
            $list ||= $self->generic_body_parse_for_list($entity);
            
            return ( $list, $email, $diag );
        }
        else {

            # no body part to parse
            return ( undef, undef, {} );
        }
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_qmail($part);
            if ( ($email) && ( keys %$diag ) ) {
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_exim {

    my $self   = shift;
    my $entity = shift;
    my $email;
 	my $list;
    my $diag = {};

    my $pattern      = quotemeta('This message was created automatically by mail delivery software');
    my $end_pattern  = quotemeta('------ This is a copy of the message');
    my $end_pattern2 = quotemeta('--- The header of the original message is following.');

    my @parts = $entity->parts;
    if ( !@parts ) {
        if ( $entity->head->mime_type =~ /text/ ) {
			my $data = ''; 
            my $body = $entity->bodyhandle;
            my $IO;
			

            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    my $state = 0;
                    while ( defined( $_ = $IO->getline ) ) {
						if($_ =~ m/$pattern/) { 
							$state = 1;
						}
						if($_ =~ m/$end_pattern|$end_pattern2/) { 
							$state = 0;
	                    };
                        if ( $state == 1 ) {
							$data .= $_;
                            if ( $_ =~ m/unknown local-part/ ) {
                                $diag->{'Status'} = '5.x.y';
                            }
							# This should probably be moved to the Rules...
							# And these are fairly genreal-purpose...
							elsif ($_ =~ m/This user doesn\'t have a (.*?) account|unknown user|This account has been disabled or discontinued|or discontinued \[\#102\]|User(.*?)does not exist|Invalid mailbox|mailbox unavailable|550\-5\.1\.1|550 5\.1\.1|Recipient does not exist here/) { 
                                $diag->{'Status'} = '5.x.y';
							}
                            else {
                            }
							
							
							if($_ =~ m/This user doesn't have a (.*?) account \((.*?)\)/){ 
								$email = $2; 
							}
							elsif($_ =~ m/RCPT TO\:\<(\S+\@\S+)\>\:/){ 
								$email = $1; 	
							}	
                            elsif ( $_ =~ /(\S+\@\S+)/ ) {
                                $email = $1;
                                $email = strip($email);
								if($email =~ m/\.$/){ 
									# This can be ridiculous, but you get messages like this: 
									#    The mail server could not deliver mail to user@example.com.
									$email =~ s/\.$//; 
								}
								elsif($email) { 
	                                $email =~ s/^\<|\>$//g;
								}
                            }
                        }
                    }
                }
				$IO->close;
				$diag->{'Notification'} = $data
					if defined $data;
            }
            if ( $diag->{'Diagnostic-Code'} =~ m/yahoo.com/ )
            {    # actually, I guess if the email address is from yahoo...
                $diag->{'Remote-MTA'} = 'yahoo.com';
            }

             #if ( $diag->{Guessed_MTA} eq 'Exim' ) {
			 if ( $entity->head->count( 'X-Failed-Recipients', 0 ) ) {
				$diag->{Guessed_MTA} = 'Exim';
                
                # well, looks like we got something...
                if ( $entity->head->get( 'X-Failed-Recipients', 0 ) ) {
                    $email = $entity->head->get( 'X-Failed-Recipients', 0 );
                    $email =~ s/\n//;
                    $email = strip($email);
                }
                my $body = $entity->bodyhandle;
                my $IO;
                my $data = '';
				my $copy  = '';
                my $state = 0;
                
                if ($body) {
                    if ( $IO = $body->open("r") ) {    # "r" for reading.
						
                        while ( defined( $_ = $IO->getline ) ) {
							my $data = $_;
							
                            if ( $data =~ /$end_pattern|$end_pattern2/ ) {
                                $state = 1;
                                next;
                            }
                            if ( $state == 1 ) {
                                $copy .= $data;
                            }
                        }
                    }
					$IO->close;  
                    require MIME::Parser;
                    my $parser = new MIME::Parser;
                    $parser = optimize_mime_parser($parser);
                    my $orig_entity;
					
					
					$copy =~ s/^\r|\n//; 
					$copy =~ s/^\r|\n//; 
					
                    eval { $orig_entity = $parser->parse_data($copy) };
                    if ( !$@ ) {
					$list = $self->list_in_list_headers($orig_entity); 
					}
					else { 
						# print "errors! $@\n"; 
					}
                }

            }
            return ( $list, $email, $diag );

        }
        else {
            return ( undef, undef, {} );
        }
    }
    else {

        # no body part to parse
        return ( undef, undef, {} );
    }
}


sub parse_for_f__king_exchange {
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = 'Your message';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        if ( $state == 1 ) {
                            $data =~ s/\n/ /g;
                            if ( $data =~ /\s{2}To:\s{6}(\S+\@\S+)/ ) {
                                $email = $1;
                            }
                            elsif ( $data =~
                                /(MSEXCH)(.*?)(Unknown\sRecipient|Unknown|)/ )
                            {                      # I know, not perfect.
                                $diag->{Guessed_MTA} = 'Exchange';
                                $diag->{'Diagnostic-Code'} =
                                  'Unknown Recipient';
                            }
                            else {

                                #...
                                #warn "nope: " . $data;
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_f__king_exchange($part);
            if ( ($email) && ( keys %$diag ) ) {
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_novell {    #like, really...
    my $self   = shift;
    my $entity = shift;

    my @parts = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = qr/(A|The) message that you sent/;
    my $end_pattern =
      quotemeta('--- The header of the original message is following. ---');

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ m/$pattern/;
                        $state = 0 if $data =~ m/$end_pattern/;
                        if ( $state == 1 ) {

                            $data =~ s/\n/ /g;

                            if ( $data =~ /\s+(\S+\@\S+)\s\((.*?)\)/ ) {
                                $email = $1;

                                $diag->{'Diagnostic-Code'} = $2;
                            }
                            elsif ( $data =~ m/\<+(\S+\@\S+)\>+/ ) {
                                $email = $1;

                            }
                            else {

                                #...
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {

        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_novell($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_gordano {    # what... ever that is there...
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state = 0;

    my $pattern     = 'Your message to';
    my $end_pattern = 'The message headers';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        $state = 0 if $data =~ /$end_pattern/;
                        if ( $state == 1 ) {
                            $data =~ s/\n/ /g;
                            if ( $data =~ /RCPT To:\<(\S+\@\S+)\>/ )
                            {                      #    RCPT To:<xxx@usnews.com>
                                $email = $1;
                            }
                            elsif ( $data =~ /(.*?)\s(\d+\.\d+\.\d+)\s(.*)/ )
                            {    # 550 5.1.1 No such mail drop defined.
                                $diag->{Status}            = $2;
                                $diag->{'Diagnostic-Code'} = $3;
                                $diag->{'Final-Recipient'} = 'rfc822';   #munge;
                                $diag->{Action}            = 'failed';   #munge;
                            }
                            else {

                                #...
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_gordano($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_overquota_yahoo {
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = 'Message from  yahoo.com.';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;

                        if ( $state == 1 ) {
                        	$diag->{'Remote-MTA'} = 'yahoo.com';
						}
                        if ( $state == 1 ) {
                            $data =~ s/\n/ /g;     #what's up with that?
                            if ( $data =~ /\<(\S+\@\S+)\>\:/ ) {
                                $email = $1;
                            }
                            else {
                                if ( $data =~ m/(over quota)/ ) {
                                    $diag->{'Diagnostic-Code'} = $data;
                                }
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {

        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_overquota_yahoo($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_earthlink {
    my $self   = shift;
    my $entity = shift;
    my @parts  = $entity->parts;
    my $email;
    my $diag = {};
    my $list;
    my $state   = 0;
    my $pattern = 'Sorry, unable to deliver your message to';

    if ( !@parts ) {
        if ( $entity->head->mime_type eq 'text/plain' ) {
            my $body = $entity->bodyhandle;
            my $IO;
            if ($body) {
                if ( $IO = $body->open("r") ) {    # "r" for reading.
                    while ( defined( $_ = $IO->getline ) ) {
                        my $data = $_;
                        $state = 1 if $data =~ /$pattern/;
                        if ( $state == 1 ) {
                            $diag->{'Remote-MTA'} = 'Earthlink';
                            $data =~ s/\n/ /g;     #what's up with that?
                            if ( $data =~ /(\d{3})\s(.*?)\s(\S+\@\S+)/ )
                            {  #  552 Quota violation for postmaster@example.com
                                $diag->{'Diagnostic-Code'} = $1 . ' ' . $2;
                                $email = $3;
                            }
                        }
                    }
                }
            }
        }
        return ( $list, $email, $diag );
    }
    else {

        my $i;
        for $i ( 0 .. $#parts ) {
            my $part = $parts[$i];
            ( $list, $email, $diag ) = $self->parse_for_earthlink($part);
            if ( ($email) && ( keys %$diag ) ) {
                $diag->{'X-Mailer'} =
                  $self->find_mailer_bounce_headers($entity);
                return ( $list, $email, $diag );
            }
        }
    }
}

sub parse_for_windows_live {
    my $self   = shift;
    my $entity = shift;

    #
    my $email;
    my $diag = {};
    my $list;
    my $state = 0;

    if ( defined($entity) ) {
        my @parts = $entity->parts;
        if ( $parts[0] ) {
            my @parts0 = $parts[0]->parts;
            if ( $parts0[0] ) {
                if ( $parts0[0]->head->count('X-HmXmrOriginalRecipient') ) {
                    $email =
                      $parts0[0]->head->get( 'X-HmXmrOriginalRecipient', 0 );
                    $diag->{'Remote-MTA'} = 'Windows_Live';
                    return ( $list, $email, $diag );
                }
            }
        }
    }

}

sub parse_using_m_ds_bp {

    my $self = shift;
    eval { require Mail::DeliveryStatus::BounceParser; };

    return ( undef, undef, {} ) if $@;

    # else, let's get to work;

    my $entity  = shift;
    my $message = $entity->as_string;

    my $bounce = eval { Mail::DeliveryStatus::BounceParser->new($message); };

    if ($@) {

        # couldn't parse.
        return ( undef, undef, {} ) if $@;
    }

  # examples:
  # my @addresses       = $bounce->addresses;       # email address strings
  # my @reports         = $bounce->reports;         # Mail::Header objects
  # my $orig_message_id = $bounce->orig_message_id; # <ABCD.1234@mx.example.com>
  # my $orig_message    = $bounce->orig_message;    # Mail::Internet object

    return ( undef, undef, {} )
      if $bounce->is_bounce != 1;

    my ($report) = $bounce->reports;

    return ( undef, undef, {} )
      if !defined $report;

    my $diag = {};

    $diag->{'Message-Id'} = $report->get('orig_message_id')
      if $report->get('orig_message_id');

    $diag->{Action} = $report->get('action')
      if $report->get('action');

    $diag->{Status} = $report->get('status')
      if $report->get('status');

    $diag->{'Diagnostic-Code'} = $report->get('diagnostic-code')
      if $report->get('diagnostic-code');

    $diag->{'Final-Recipient'} = $report->get('final-recipient')
      if $report->get('final-recipient');

# these aren't used particularily in Dada Mail, but let's play around with them...

    $diag->{std_reason} = $report->get('std_reason')
      if $report->get('std_reason');

    $diag->{reason} = $report->get('reason')
      if $report->get('reason');

    $diag->{host} = $report->get('host')
      if $report->get('host');

    $diag->{smtp_code} = $report->get('smtp_code')
      if $report->get('smtp_code');

    my $email = $report->get('email') || undef;

    return ( undef, $email, $diag );

}

sub DESTROY { }
1;
