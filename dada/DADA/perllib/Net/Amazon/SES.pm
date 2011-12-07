# Copyright 2010 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not 
# use this file except in compliance with the License. A copy of the License 
# is located at
#
#        http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE" file accompanying this file. This file is distributed 
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
# express or implied. See the License for the specific language governing 
# permissions and limitations under the License.

# This is a code sample showing how to use the Amazon Simple Email Service from the
# command line.  To learn more about this code sample, see the AWS Simple Email
# Service Developer Guide. 

package Net::Amazon::SES;

use strict;
use warnings;
our $VERSION = '1.00';
use base 'Exporter';
our @EXPORT = qw();
use Switch;
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64 sha256);
use URI::Escape qw (uri_escape_utf8);
use LWP 6;
use LWP::Protocol::https;
use Carp qw(croak carp); 
use vars qw($AUTOLOAD); 
use Encode qw(encode); 

#use Time::HiRes qw(gettimeofday); 


my $endpoint = 'https://email.us-east-1.amazonaws.com/';
my $service_version = '2010-12-01';
my $tools_version = '1.1';
my $signature_version = 'HTTP';
my %opts;
my %params;
my $aws_access_key_id;
my $aws_secret_access_key;

our $aws_email_ns = "http://ses.amazonaws.com/doc/$service_version/";

# RFC3986 unsafe characters
my $unsafe_characters = "^A-Za-z0-9\-\._~";






my %allowed = (
		browser     => undef, 
		creds       => '', 
		trace       => 0, 
		encode_utf8 => 1,
		
);
sub new {

	my $that = shift; 
	my $class = ref($that) || $that; 
	
	my $self = {
		_permitted => \%allowed, 
		%allowed,
	};
	
	bless $self, $class;
	
	my ($args) = @_; 
   $self->_init($args); 
   return $self;
}




sub AUTOLOAD { 
    my $self = shift; 
    my $type = ref($self) 
    	or croak "$self is not an object"; 
    	
    my $name = $AUTOLOAD;
       $name =~ s/.*://; #strip fully qualifies portion 
    
    unless (exists  $self -> {_permitted} -> {$name}) { 
    	croak "Can't access '$name' field in object of class $type"; 
    }    
    if(@_) { 
        return $self->{$name} = shift; 
    } else { 
        return $self->{$name}; 
    }
}




sub _init  {

	my $self    = shift; 
	my $args    = shift;

	if(exists($args->{-trace})){ 
		$self->trace($args->{-trace}); 
	}
	
	$self->browser($self->reset_browser); 
	$self->creds($args->{-creds}); 
	

	
}

sub reset_browser { 
	my $self = shift; 
	
	if($self->trace){ 
		carp "creating a new browser"; 
	}	
	my $browser = LWP::UserAgent->new(
		agent => "SES-Perl-$tools_version/$service_version",
		keep_alive => 5, 
	);
	return $browser; 
    
}


sub send_msg { 
	my $self = shift; 
	my ($args) = @_; 
	my $msg; 
	if(exists($args->{-msg})){ 
		$msg = $args->{-msg};
	}
	else { 
		croak "you MUST pass a message in, '-msg!'"; 
	}
	
	if($self->encode_utf8) { 
		$msg = encode('UTF-8', $msg);  
	}
	require MIME::Base64;
	my $params = {
		'RawMessage.Data'                                 => MIME::Base64::encode_base64($msg), 
		'Action'                                          => 'SendRawEmail'
	}; 
	
	return $self->call_ses(
		$params, {}
	); 	
		
}





# Read the credentials from $AWS_CREDENTIALS_FILE file.
sub read_credentials {
	
	my $self = shift; 
    my $file;
    if (defined($self->creds)) {
        $file = $self->creds;
    } else {
        $file = $ENV{'AWS_CREDENTIALS_FILE'};
    }
    die "Unspecified AWS credentials file." unless defined($file);
    open (FILE, '<:utf8', $file) or die "Cannot open credentials file <$file>.";
    while (my $line = <FILE>) {
        $line =~ /^\s*(.*?)=(.*?)\s*$/ or die "Cannot parse credentials entry <$line> in <$file>.";
        my ($key, $value) = ($1, $2);
        switch ($key) {
            case 'AWSAccessKeyId' { $aws_access_key_id     = $value; }
            case 'AWSSecretKey'   { $aws_secret_access_key = $value; }
            else                  { die "Unrecognized credential <$key> in <$file>."; }
        }
    }
    close (FILE);
}


# Prepares AWS-specific service call parameters.
sub prepare_aws_params {
	my $self = shift; 
	
    $params{'AWSAccessKeyId'}   = $aws_access_key_id;
    $params{'Timestamp'}        = sprintf(
	                                "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
	                                sub {($_[5]+1900,$_[4]+1,$_[3],$_[2],$_[1],$_[0])}
	                                    ->(gmtime(time))
	                            );
    $params{'Version'}          = $service_version;
}


# Compute the V1 AWS request signature.
# (see http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928#HTTP)
sub get_signature_v1 {
	
	my $self = shift; 
	
    $params{'SignatureMethod'}  = 'HmacSHA1';
    $params{'SignatureVersion'} = '1';

    my $data = '';
    for my $key (sort {lc($a) cmp lc($b)} keys %params) {
        my $value = $params{$key};
        $data .= $key . $value;
    }

    return hmac_sha1_base64($data, $aws_secret_access_key) . '=';
}


# Compute the V2 AWS request signature.
# (see http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928#HTTP)
sub get_signature_v2 {
	
	my $self = shift; 
	
    $params{'SignatureMethod'}  = 'HmacSHA256';
    $params{'SignatureVersion'} = '2';

    my $endpoint_name = $endpoint;
    $endpoint_name =~ s!^https?://(.*?)/?$!$1!;

    my $data = '';
    $data .= 'POST';
    $data .= "\n";
    $data .= $endpoint_name;
    $data .= "\n";
    $data .= '/';
    $data .= "\n";

    my @params = ();
    for my $key (sort keys %params) {
        my $evalue = uri_escape_utf8($params{$key}, $unsafe_characters);
        push @params, "$key=$evalue";
    }
    my $query_string = join '&', @params;
    $data .= $query_string;

    return hmac_sha256_base64($data, $aws_secret_access_key) . '=';
}


# Add the V1 signature to service call parameters.
sub sign_v1 {
	my $self = shift; 
    $params{'Signature'} = $self->get_signature_v1;
}


# Add the V2 signature to service call parameters.
sub sign_v2 {
	my $self = shift; 
    $params{'Signature'} = $self->get_signature_v2;
}


# Compute HTTP signature.
sub sign_http_request {
	
	my $self = shift; 
    my $request = shift;

    my $data = '';
    $data .= 'POST';
    $data .= "\n";
    $data .= '/';
    $data .= "\n";
    $data .= $request->content();
    $data .= "\n";
    $data .= 'date:'.$request->header('Date');
    $data .= "\n";
    $data .= 'host:'.$request->header('Host');
    $data .= "\n";
    $data .= "\n";

    my $sig = hmac_sha256_base64(sha256($data), $aws_secret_access_key) . '=';

    my $signature = '';
    $signature .= 'AWS3 ';
    $signature .= "AWSAccessKeyId=$params{'AWSAccessKeyId'}, ";
    $signature .= "Signature=$sig, ";
    $signature .= 'Algorithm=HmacSHA256, ';
    $signature .= 'SignedHeaders=Date;Host';

    return $signature;
}


# Compute HTTPS signature.
sub sign_https_request {

	my $self = shift; 
	
    my $request = shift;

    my $data = '';
    $data .= $request->header('Date');

    my $sig = hmac_sha256_base64($data, $aws_secret_access_key) . '=';;

    my $signature = '';
    $signature .= 'AWS3-HTTPS ';
    $signature .= "AWSAccessKeyId=$params{'AWSAccessKeyId'}, ";
    $signature .= "Signature=$sig, ";
    $signature .= 'Algorithm=HmacSHA256';

    return $signature;
}


# Sign the HTTP request.
sub sign_http {
	
	my $self = shift; 
	
    my $request = shift;

    my $endpoint_name = $endpoint;
    $endpoint_name =~ s!^https?://(.*?)/?$!$1!;

    $request->date(time);
    $request->header('Host', $endpoint_name);

    my $signature;
    my $use_https = $endpoint =~ m!^https://!;
    if ($use_https) {
        $signature = $self->sign_https_request($request);
    } else {
        $signature = $self->sign_http_request($request);
    }

    $request->header('x-amzn-authorization', $signature);
}


# Build the service call payload.
sub build_payload {

	my $self = shift; 
    my @params = ();
    my $payload;
    for my $key (sort keys %params) {
        my $value = $params{$key};
        my ($ekey, $evalue) = (uri_escape_utf8($key, $unsafe_characters), 
			       uri_escape_utf8($value, $unsafe_characters));
        push @params, "$ekey=$evalue";
    }
    $payload = join '&', @params;
    return $payload;
}


# Call the service.
sub call_ses {
	
	my $self = shift; 
	
	#my $t0 = gettimeofday();
    my $params = shift;
    my $opts = shift;

    %opts = %$opts;
    %params = %$params;

    $endpoint = $opts{'e'} if defined($opts{'e'});
    my $endpoint_name = $endpoint;
    $endpoint_name =~ s!^https?://(.*?)(:\d+)?/?$!$1!;

    $self->read_credentials;
    $self->prepare_aws_params;

    switch ($signature_version) {
	case 'V1'   { $self->sign_v1; }
	case 'V2'   { $self->sign_v2; }
	case 'HTTP' { }
	else        { die "Unrecognized signature version <$signature_version>."; }
    }

    my $payload = $self->build_payload;
	
	my$browser = $self->browser; 
	if(!defined($browser)){ 
		if($self->trace){ 
			carp "browser is not defined?"; 
		}	
		$self->browser($self->reset_browser);
		$browser = $self->browser; 
	}
    


	my $request = new HTTP::Request 'POST', $endpoint;
    $request->header("If-SSL-Cert-Subject" => "/CN=$endpoint_name");
    $request->content($payload);
    $request->content_type('application/x-www-form-urlencoded');
    if ($signature_version eq 'HTTP') {
        $self->sign_http($request);
    }
    my $response = $browser->request($request);

	if ($self->trace){
    #	carp $response->content;
	}
	
    my $status = $response->is_success;
    if (!$status) {
        my $content = $response->content;
        my $errmsg = $content;
        if ($content =~ /<Message>(.*?)<\/Message>/s) {
            $errmsg = $1;
        }
        print STDERR $errmsg, "\n";
    }
	if($self->trace){ 
		carp $response->status_line( );
	}
	#my $t1 = gettimeofday();
	#carp "mailing time: " . ($t1 - $t0);
    return ($response->code, $response->content);
}

sub DESTORY {
	my $self = shift; 
}

1;