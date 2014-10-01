package DADA::App::WebServices;
use strict; 

use lib qw(
  ../../
  ../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use JSON;
use DADA::Config; 
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use Digest::SHA qw(hmac_sha256_base64);
use Carp qw(carp croak);
use CGI (qw/:oldstyle_urls/);
my $calculated_digest = undef; 

# $Carp::Verbose = 1; 


use vars qw($AUTOLOAD);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_WebServices};

my %allowed = ( test => 0, );

sub new {
    warn 'hit!'; 
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
    my $self   = shift; 
    $self->{q}  = CGI->new;
}

sub request { 
    my $self   = shift; 
    my $status = 1; 
    my $errors = {};
    my ($args) = @_; 
    for(
    '-list',       
    '-service',    
    '-public_key', 
    '-digest',     
    '-cgi_obj'){ 
        
        my $param = $_; 
          $param =~ s/^\-//; 
        
        if(!exists($args->{$_})){ 
            #croak "You MUST pass the, '" . $_ . "' paramater!"; 
            $status = 0; 
            $errors->{'missing_' . $param}
        }
        else { 
            $self->{$param} = $args->{$_}; 
        }
    }

    $self->{ls} = DADA::MailingList::Settings->new({-list => $self->{list}}); 
    
    
    
    if($status == 1){ 
        ( $status, $errors ) = $self->check_request();
    }
    
    my $r = {}; 

    if($status == 1){ 
        
    	if($self->{service} eq 'validate_subscription'){
    		$r->{results} = $self->validate_subscription();
    		$r->{status}  = 1; 
    	}
    	elsif($self->{service} eq 'subscription'){
    		$r->{results} = $self->subscription();
    		$r->{status}  = 1; 
    	}
    	else { 
    		$r = {
    			status => 0, 
    			errors => {invalid_request => 1}
    		};
    	}
    }
    else { 
    	$r = {
    		status        => 0, 
    		errors        => $errors,
    		#og_path_info  => $ENV{PATH_INFO},
    		og_query      => $self->{cgi_obj}->query_string(),
    		og_digest     => $self->{digest}, 
    		calculated_digest => $calculated_digest, 
    	    public_api_key    => $self->{ls}->param('public_api_key'), 
    	    private_api_key    => $self->{ls}->param('private_api_key'), 
            
    	};
    }
    
    my $d = $self->{q}->header(
        -type            => 'application/json',
        '-Cache-Control' => 'no-cache, must-revalidate',
        -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
    );

    my $json      = JSON->new->allow_nonref;
    $d .= $json->pretty->encode($r);
    warn $d; 
    return $d;
    
}


sub validate_subscription { 
	my $self              = shift; 
	my $addresses         = $self->{cgi_obj}->param('addresses');
	my $lh                = DADA::MailingList::Subscribers->new({-list => $self->{list}}); 
	my $json              = JSON->new; 
    my $decoded_addresses = $json->decode($addresses);	
	
    my $addresses = $lh->filter_subscribers_w_meta(
    		{
    			-emails => $decoded_addresses, 
    			-type   => 'list',
    		}
    );
	return $addresses;
}


sub subscription {
	
	my $self              = shift; 
	my $addresses         = $self->{cgi_obj}->param('addresses');
	my $lh                = DADA::MailingList::Subscribers->new({-list => $self->{list}}); 
	my $json              = JSON->new; 
    my $decoded_addresses = $json->decode($addresses);	
	
	my $not_members_fields_options_mode = 'preserve_if_defined';
	
	my $new_email_count     = 0; 
	my $skipped_email_count = 0; 
	
    for my $info(@$decoded_addresses) {
		if(!exists($info->{fields})){ 
			# $info->{fields} = {};
		}
		if(!exists($info->{profile})){ 
			#$info->{profile} = {};
		}
		if(!exists($info->{profile}->{password})){ 
			#$info->{profile}->{password} = '';
		}

        my $dmls = $lh->add_subscriber(
            {
                -email             => $info->{email},
                -fields            => $info->{fields},
                -profile           => { 
                    -password => $info->{profile}->{password}, 
                    -mode     => $not_members_fields_options_mode, 
                },
                -type              => 'list', # $type,
                -fields_options    => { -mode => $not_members_fields_options_mode, },
                -dupe_check        => {
                    -enable  => 1,
                    -on_dupe => 'ignore_add',
                },
            }
        );
        if ( defined($dmls) ) {    # undef means it wasn't added.
            $new_email_count++;
        }
        else {
            $skipped_email_count++;
        }
    }
	
	return {  
		new_email_count     => $new_email_count, 
		skipped_email_count => $skipped_email_count,
	}
	
	#return $addresses;
	
}

sub check_request {

    my $self    = shift; 

    my $status  = 1;
    my $errors  = {};

    if ( $self->check_timestamp() == 0 ) {
        $status = 0;
        $errors->{invalid_timestamp} = 1;
    }
    if ( $self->check_public_key() == 0 ) {
        $status = 0;
        $errors->{invalid_public_key} = 1;
    }
    if ( $self->check_digest() == 0 ) {
        $status = 0;
        $errors->{invalid_digest} = 1;
    }

    return ($status, $errors);
}

sub check_timestamp {
    my $self = shift; 
    if ( ( int($self->{cgi_obj}->param('timestamp')) + ( 60 * 5 ) ) < int(time) ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub check_public_key {
    
    my $self = shift; 
    if ( $self->{ls}->param('public_api_key') ne $self->{ls}->param('public_api_key') ) {
		return 0; 
    }
	else { 
		return 1; 
	}
}

sub check_digest {
    
    my $self = shift; 
    my $addresses   = $self->{cgi_obj}->param('addresses');
    
	my $qq = CGI->new();
	   $qq->delete_all(); 
	
    $qq->param('addresses', $self->{cgi_obj}->param('addresses'));
    $qq->param('timestamp', $self->{cgi_obj}->param('timestamp'));

    my $n_digest = $self->digest($qq->query_string() );
	$calculated_digest = $n_digest; 
    if ( $self->{digest} ne $n_digest ) {
        return 0;
    }
	else { 
		return 1;
	}
}

sub digest {

    my $self        = shift; 
    my $message     = shift;
    my $n_digest = hmac_sha256_base64( $message, $self->{ls}->param('private_api_key') );
    while ( length($n_digest) % 4 ) {
        $n_digest .= '=';
    }
    return $n_digest;
}


1;