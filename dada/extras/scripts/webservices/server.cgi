#!/usr/bin/perl 
use strict; 

my $s_public_key  = 'VRDFTUJJXOYEYWMUEOK5';                         #20
my $s_private_key = 'yEDiEv8oTGi4St2iOiQoI5jkp6QPW8Bt657H2p5j1';    #40

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/DADA/perllib";
use JSON;
use DADA::Config; 
use DADA::MailingList::Subscribers;

BEGIN {
    my $b__dir = ( getpwuid($>) )[7] . '/perl';
    push @INC, $b__dir . '5/lib/perl5',
      $b__dir . '5/lib/perl5/x86_64-linux-thread-multi', $b__dir . 'lib',
      map { $b__dir . $_ } @INC;
}

#---------------------------------------------------------------------#
use CGI (qw/:oldstyle_urls/);
use CGI::Carp qw(fatalsToBrowser);
use Carp qw(carp croak);
my $q  = CGI->new;

my $list; 
my $flavor; 
my $public_key; 
my $digest; 
my $og_digest; 

if ( $ENV{PATH_INFO} ) {
    my $dp = $q->url;
    $dp =~ s/^(http:\/\/|https:\/\/)(.*?)\//\//;
    my $info = $ENV{PATH_INFO};
    $info =~ s/^$dp//;

    # script name should be something like:
    # /cgi-bin/dada/mail.cgi
    $info =~ s/^$ENV{SCRIPT_NAME}//i;
    $info =~ s/(^\/|\/$)//g;            #get rid of fore and aft slashes
	($list, $flavor, $public_key, $digest) = split('/', $info, 4); 
}

my ( $status, $errors ) = check_request($q);
my $r = {}; 

if($status == 1){ 
	if($flavor eq 'validate_subscription'){
		$r->{results} = validate_subscription($q);
		$r->{status}  = 1; 
	}
	elsif($flavor eq 'subscription'){
		$r->{results} = subscription($q);
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
		og_path_info  => $ENV{PATH_INFO},
		og_query      => $q->query_string(),
		og_digest     => $digest, 
		og_addressses => $q->param('addresses'), 
		og_digest     => $og_digest, 
	};
}
print $q->header(
    -type            => 'application/json',
    '-Cache-Control' => 'no-cache, must-revalidate',
    -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
);

my $json      = JSON->new->allow_nonref;
my $data_back = $json->pretty->encode($r);
print $data_back; 

sub validate_subscription { 
	
	my $cgi_obj           = shift; 
	my $addresses         = $q->param('addresses');
	my $lh                = DADA::MailingList::Subscribers->new({-list => $list}); 
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
	
	my $cgi_obj           = shift; 
	my $addresses         = $q->param('addresses');
	my $lh                = DADA::MailingList::Subscribers->new({-list => $list}); 
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
    my $cgi_obj = shift;
    my $status  = 1;
    my $errors  = {};

    if ( check_timestamp($q->param('timestamp')) == 0 ) {
        $status = 0;
        $errors->{invalid_timestamp} = 1;
    }
    if ( check_public_key() == 0 ) {
        $status = 0;
        $errors->{invalid_public_key} = 1;
    }
    if ( check_digest($cgi_obj) == 0 ) {
        $status = 0;
        $errors->{invalid_digest} = 1;
    }

    return ($status, $errors);
}

sub check_timestamp {
    my $ts = shift || return 0;
    if ( ( int($ts) + ( 60 * 5 ) ) < int(time) ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub check_public_key {
    if ( $public_key ne $s_public_key ) {
		return 0; 
    }
	else { 
		return 1; 
	}
}

sub check_digest {
    my $addresses   = $q->param('addresses');
    
	my $qq = CGI->new();
	   $qq->delete_all(); 
	
	
    $qq->param('addresses', $q->param('addresses'));
    $qq->param('timestamp', $q->param('timestamp'));

    my $n_digest = digest( $s_private_key, $qq->query_string() );
	$og_digest = $n_digest; #debug; 
	
    if ( $digest ne $n_digest ) {
        return 0;
    }
	else { 
		return 1;
	}
}

sub digest {

    my $private_key = shift;
    my $message     = shift;

    use Digest::SHA qw(hmac_sha256_base64);
    my $n_digest = hmac_sha256_base64( $message, $private_key );

    while ( length($n_digest) % 4 ) {
        $n_digest .= '=';
    }
    return $n_digest;
}
