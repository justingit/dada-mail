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
#use Switch;
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64 sha256);
use URI::Escape qw (uri_escape_utf8);
use LWP 6;
use LWP::Protocol::https;
use Carp qw(croak carp);
use vars qw($AUTOLOAD);
use Encode qw(encode);
use XML::LibXML; 

#use Time::HiRes qw(gettimeofday);

my $service_version   = '2010-12-01';
my $tools_version     = '1.1';
my $signature_version = 'HTTP';
my %opts;
my %params;

our $aws_email_ns = "http://ses.amazonaws.com/doc/$service_version/";

# RFC3986 unsafe characters
my $unsafe_characters = "^A-Za-z0-9\-\._~";

my %allowed = (
    browser        => undef,
    creds          => '',
	AWSAccessKeyId => undef, 
	AWSSecretKey   => undef, 
	AWS_endpoint   => 'https://email.us-east-1.amazonaws.com/', 
    trace          => 0,
    encode_utf8    => 1,
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

    if ( exists( $args->{-trace} ) ) {
        $self->trace( $args->{-trace} );
    }

    $self->browser( $self->reset_browser );
	if(exists($args->{AWSAccessKeyId})) { 
		$self->AWSAccessKeyId($args->{AWSAccessKeyId}); 
	}
	if(exists($args->{AWSSecretKey})) { 
		$self->AWSSecretKey($args->{AWSSecretKey}); 
	}
	
	if(exists($args->{AWS_endpoint})) { 
		$self->AWS_endpoint($args->{AWS_endpoint}); 
	}


    $self->creds( $args->{-creds} );
}

sub reset_browser {
    my $self = shift;

    if ( $self->trace ) {
        carp "creating a new browser";
    }
    my $browser = LWP::UserAgent->new(
        agent      => "SES-Perl-$tools_version/$service_version",
        keep_alive => 5,
    );
    return $browser;

}


=cut 

useless. 

sub list_identities {  
    my $self   = shift; 
	my ($args) = @_; 
	
	my $params = {
	    Action       => 'ListIdentities', 
	};
	my ($response_code, $response_content) = $self->call_ses($params, {});

        use Data::Dumper; 
        print '$response_content ' . Dumper($response_content); 
        
	if ( $self->trace ) {
		print $response_code . "\n"; 
        print $response_content . "\n"; 
	}

	if($response_code eq '200') { 
		#if ( $self->trace ) {
		#	$self->print_response($response_content);
    	#}    
	#	return ($response_code, $self->get_response($response_content));
#	    return ($response_code, $response_content); 
        my $r; 
        my $parser = XML::LibXML->new();
        my $dom = $parser->parse_string($response_content);
        my $xpath = XML::LibXML::XPathContext->new($dom);
        $xpath->registerNs('ns', $aws_email_ns);

        my @nodes = $xpath->findnodes('/ns:ListIdentitiesResponse' . '/ns:ListIdentitiesResult'  . '/ns:Identities');
        my @a = (); 
        foreach my $node (@nodes) {
            my $text = $node->textContent();
        	push(@a, $text);
        }
		return ($response_code, \@a);
	}
	else { 
		return ($response_code, $response_content);
	}
}

=cut

sub sender_verified { 

    my $self  = shift; 
    my $email = shift; 
    
    my ($name, $domain) = split('@', $email, 2); 
	my $params = {
	    Action                   => 'GetIdentityVerificationAttributes', 
	    'Identities.member.1'    => $email, 
        'Identities.member.2'    => $domain, 
	};
	my ($response_code, $response_content) = $self->call_ses($params, {});
	if ( $self->trace ) {
		print $response_code . "\n"; 
        print $response_content . "\n"; 
	}

	if($response_code eq '200') { 
	    
	    #return ($response_code, $response_content); 

        my $r; 
        my $parser = XML::LibXML->new();
        my $dom = $parser->parse_string($response_content);
        my $xpath = XML::LibXML::XPathContext->new($dom);
        $xpath->registerNs('ns', $aws_email_ns);
        my @nodes = $xpath->findnodes(
            '/ns:GetIdentityVerificationAttributesResponse' . 
            '/ns:GetIdentityVerificationAttributesResult' .
            '/ns:VerificationAttributes' . 
            '/ns:entry' . 
            '/ns:value' . 
            '/ns:VerificationStatus'
            );
        my @a = (); 
       # print scalar(@nodes) . 'nodes!' ; 
        foreach my $node (@nodes) {
            my $text = $node->textContent();
        	push(@a, $text);
        }
        sleep(1); 
        if($a[0] eq 'Success' || $a[1] eq 'Success'){ 
            $r = 'Success'; 
        }

		return ($response_code, $r);
	}
	else { 
		return ($response_code, $response_content);
	}
}
sub verify_sender { 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-email})) { 
		croak "You MUST pass the, '-email' paramater!"; 
	}
	
	my $params = {
		EmailAddress =>  $args->{-email},
	    Action       => 'VerifyEmailAddress', 
	};
	my ($response_code, $response_content) = $self->call_ses($params, {});

	if ( $self->trace ) {
		print $response_code . "\n"; 
        print $response_content . "\n"; 
	}


	if($response_code eq '200') { 
		if ( $self->trace ) {
			$self->print_response($response_content);
    	}    
		return ($response_code, $self->get_response($response_content));
	}
	else { 
		return ($response_code, $response_content);
	}
	
=cut
	switch ($response_code) {
	    case '200' {              # OK
			if ( $self->trace ) {
				print $response_code . "\n"; 
		        print $response_content . "\n"; 
		        $self->print_response($response_content);
			}
			return 0;
	    }
	    case '400' { return  1; }   # BAD_INPUT
	    case '403' { return 31; }   # SERVICE_ACCESS_ERROR
	    case '500' { return 32; }   # SERVICE_EXECUTION_ERROR
	    case '503' { return 30; }   # SERVICE_ERROR
	    else       { return -1; }
	}
=cut

}

sub get_stats { 
	my $self = shift; 
	my ($args) = @_; 
	
	
	my $params = {
        Action => 'GetSendQuota', 
	};

	my ($response_code, $response_content) = $self->call_ses($params, {});
		if ( $self->trace ) {
			print $response_code . "\n"; 
	        print $response_content . "\n"; 
		}	
	
	
	if($response_code eq '200') { 
		return ($response_code, $self->get_stats_response($response_content));
	}
	else { 
		return ($response_code, $response_content);
	}

=cut	
	switch ($response_code) {
	    case '200' {              # OK
		
			if ( $self->trace ) {
		        print $self->get_stats_response($response_content);
			}	
	        return  0;
	    }
	    case '400' { return  1; }   # BAD_INPUT
	    case '403' { return 31; }   # SERVICE_ACCESS_ERROR
	    case '500' { return 32; }   # SERVICE_EXECUTION_ERROR
	    case '503' { return 30; }   # SERVICE_ERROR
	    else       { return -1; }
	}	
=cut

}
# Calculates the optimal number of tabs per column for best display style.
sub compute_tabs {
    my @nodes = @{shift()};
    my $xpath = shift;
    my $tab_size = shift;

    my @headers = map {$_->nodeName()} $xpath->findnodes('ns:*', $nodes[0]);
    my @tabs = ();

    for (my $i = 0; $i < @headers; $i++) {
        $tabs[$i] = int(length($headers[$i]) / $tab_size) + 1;
    }

    foreach my $n (@nodes) {
        my @columns = map {$_->textContent()} $xpath->findnodes('ns:*', $n);
        for (my $i = 0; $i < @columns; $i++) {
            my $t = int(length($columns[$i]) / $tab_size) + 1;
            if ($t > $tabs[$i]) {
                $tabs[$i] = $t;
            }
        }
    }

    return @tabs;
}


# Print an XML node.
sub return_node {
    my $node = shift;
    my $xpath = shift;
    my $is_header = shift;
    my @tabs = @{shift()};
    my $first_column = shift;
    my $tab_size = shift;

	my $r; 

    my @children = $xpath->findnodes('ns:*', $node);

    if ($first_column) {
        my $index = -1;
        for (my $i = 0; $i < @children; $i++) {
            if ($first_column eq $children[$i]->nodeName()) {
                $index = $i;
                last;
            }
        }
        if ($index != -1) {
            unshift(@children, splice(@children, $index, 1));
            unshift(@tabs, splice(@tabs, $index, 1));
        }
    }

    for (my $i = 0; $i < @children; $i++) {
        my $text = $is_header ? $children[$i]->nodeName() : $children[$i]->textContent();

	# format number nodes without trailing zeroes after the decimal point
	if ($text =~ /(\d+)\.0+/) {
		$text = $1;
	}

        $r .= sprintf("%-" . ($tab_size * $tabs[$i]) . "s", $text);
    }
    $r .= "\n";
	return $r; 

}


# Prints the data returned by the service call.
sub get_stats_response {
	my $self = shift; 
    my $response_content = shift;
	my $r; 

    my $parser = XML::LibXML->new();
    my $dom = $parser->parse_string($response_content);
    my $xpath = XML::LibXML::XPathContext->new($dom);
    $xpath->registerNs('ns', $aws_email_ns);

    my $first_column;
    my @nodes;

=cut
    if ($opts{'s'}) {
        @nodes = $xpath->findnodes('/ns:GetSendStatisticsResponse' .
                                   '/ns:GetSendStatisticsResult' .
                                   '/ns:SendDataPoints' .
                                   '/ns:member');
        @nodes = sort {
            my ($x) = $a->getChildrenByLocalName('Timestamp');
            my ($y) = $b->getChildrenByLocalName('Timestamp');
            $x->textContent() cmp $y->textContent();
        } @nodes;
	$first_column = 'Timestamp';
    } elsif ($opts{'q'}) {
=cut

        @nodes = $xpath->findnodes('/ns:GetSendQuotaResponse' .
                                   '/ns:GetSendQuotaResult');

=cut
    }
=cut
    if ($#nodes != -1) {
        my $tab_size = 8;
        my @tabs = compute_tabs(\@nodes, $xpath, $tab_size);
        $r .= return_node($nodes[0], $xpath, 1, \@tabs, $first_column, $tab_size);
        foreach my $node (@nodes) {
            $r .= return_node($node, $xpath, 0, \@tabs, $first_column, $tab_size);
        }
    }

	return $r; 
}





sub send_msg {
    my $self = shift;
    my ($args) = @_;
    my $msg;
    if ( exists( $args->{-msg} ) ) {
        $msg = $args->{-msg};
    }
    else {
        croak "you MUST pass a message in, '-msg!'";
    }

    if ( $self->encode_utf8 ) {
        $msg = encode( 'UTF-8', $msg );
    }
    require MIME::Base64;
    my $params = {
        'RawMessage.Data' => MIME::Base64::encode_base64($msg),
        'Action'          => 'SendRawEmail'
    };

	my ($response_code, $response_content) = $self->call_ses($params, {});
		if ( $self->trace ) {
			print $response_code . "\n"; 
			print $response_content . "\n"; 
		}	

	return ($response_code, $response_content);

#	if($response_code eq '200') { 
#		return ($response_code, $self->get_send_response($response_content));
#	}
#	else { 
#		return ($response_code, $response_content);
#	}
}

# Read the credentials from $AWS_CREDENTIALS_FILE file.
sub read_credentials {

    my $self = shift;
    my $file;
    if ( defined( $self->creds ) ) {
        $file = $self->creds;
    }
    else {
        $file = $ENV{'AWS_CREDENTIALS_FILE'};
    }
    die "Unspecified AWS credentials file." unless defined($file);
    open( FILE, '<:utf8', $file )
      or die "Cannot open credentials file <$file>.";
    while ( my $line = <FILE> ) {
        $line =~ /^\s*(.*?)=(.*?)\s*$/
          or die "Cannot parse credentials entry <$line> in <$file>.";
        my ( $key, $value ) = ( $1, $2 );
        if ($key eq 'AWSAccessKeyId') {
            $self->AWSAccessKeyId($value);
        }
        elsif($key eq 'AWSSecretKey') { 
            $self->AWSSecretKey($value) 
        }
        else { 
            die "Unrecognized credential <$key> in <$file>."; 
        }

    }
    close(FILE);
}

# Prepares AWS-specific service call parameters.
sub prepare_aws_params {
    my $self = shift;

    $params{'AWSAccessKeyId'} = $self->AWSAccessKeyId; #dumb. 
    $params{'Timestamp'}      = sprintf(
        "%04d-%02d-%02dT%02d:%02d:%02d.000Z",
        sub { ( $_[5] + 1900, $_[4] + 1, $_[3], $_[2], $_[1], $_[0] ) }
          ->( gmtime(time) )
    );
    $params{'Version'} = $service_version;
}

# Compute the V1 AWS request signature.
# (see http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928#HTTP)
sub get_signature_v1 {

    my $self = shift;

    $params{'SignatureMethod'}  = 'HmacSHA1';
    $params{'SignatureVersion'} = '1';

    my $data = '';
    for my $key ( sort { lc($a) cmp lc($b) } keys %params ) {
        my $value = $params{$key};
        $data .= $key . $value;
    }

    return hmac_sha1_base64( $data, $self->AWSSecretKey ) . '=';
}

# Compute the V2 AWS request signature.
# (see http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928#HTTP)
sub get_signature_v2 {

    my $self = shift;

    $params{'SignatureMethod'}  = 'HmacSHA256';
    $params{'SignatureVersion'} = '2';

    my $endpoint_name = $self->AWS_endpoint;
    $endpoint_name =~ s!^https?://(.*?)/?$!$1!;

    my $data = '';
    $data .= 'POST';
    $data .= "\n";
    $data .= $endpoint_name;
    $data .= "\n";
    $data .= '/';
    $data .= "\n";

    my @params = ();
    for my $key ( sort keys %params ) {
        my $evalue = uri_escape_utf8( $params{$key}, $unsafe_characters );
        push @params, "$key=$evalue";
    }
    my $query_string = join '&', @params;
    $data .= $query_string;

    return hmac_sha256_base64( $data, $self->AWSSecretKey ) . '=';
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

    my $self    = shift;
    my $request = shift;

    my $data = '';
    $data .= 'POST';
    $data .= "\n";
    $data .= '/';
    $data .= "\n";
    $data .= $request->content();
    $data .= "\n";
    $data .= 'date:' . $request->header('Date');
    $data .= "\n";
    $data .= 'host:' . $request->header('Host');
    $data .= "\n";
    $data .= "\n";

    my $sig = hmac_sha256_base64( sha256($data), $self->AWSSecretKey ) . '=';

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

    my $sig = hmac_sha256_base64( $data, $self->AWSSecretKey ) . '=';

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

    my $endpoint_name = $self->AWS_endpoint;
    $endpoint_name =~ s!^https?://(.*?)/?$!$1!;

    $request->date(time);
    $request->header( 'Host', $endpoint_name );

    my $signature;
    my $use_https = $self->AWS_endpoint =~ m!^https://!;
    if ($use_https) {
        $signature = $self->sign_https_request($request);
    }
    else {
        $signature = $self->sign_http_request($request);
    }

    $request->header( 'x-amzn-authorization', $signature );
}

# Build the service call payload.
sub build_payload {

    my $self   = shift;
    my @params = ();
    my $payload;
    for my $key ( sort keys %params ) {
        my $value = $params{$key};
        my ( $ekey, $evalue ) = (
            uri_escape_utf8( $key,   $unsafe_characters ),
            uri_escape_utf8( $value, $unsafe_characters )
        );
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
    my $opts   = shift;

    %opts   = %$opts;
    %params = %$params;
    
    if(defined( $opts{'e'} )) { 
         $self->AWS_endpoint($opts{'e'});
    }
        
    my $endpoint_name = $self->AWS_endpoint;
    $endpoint_name =~ s!^https?://(.*?)(:\d+)?/?$!$1!;
	
	if(! defined($self->AWSAccessKeyId ) || ! defined($self->AWSSecretKey)) { 
		$self->read_credentials;
	}
	
    $self->prepare_aws_params;

    if($signature_version eq 'V1') {
         $self->sign_v1; 
    }elsif($signature_version eq 'V2') { 
        $self->sign_v2; 
    }elsif($signature_version eq 'HTTP') { 
        # ... 
    }
    else {
        die "Unrecognized signature version <$signature_version>.";
    }

    my $payload = $self->build_payload;

    my $browser = $self->browser;
    if ( !defined($browser) ) {
        if ( $self->trace ) {
            carp "browser is not defined?";
        }
        $self->browser( $self->reset_browser );
        $browser = $self->browser;
    }

    my $request = new HTTP::Request 'POST', $self->AWS_endpoint;
    $request->header( "If-SSL-Cert-Subject" => "/CN=$endpoint_name" );
    $request->content($payload);
    $request->content_type('application/x-www-form-urlencoded');
    if ( $signature_version eq 'HTTP' ) {
        $self->sign_http($request);
    }
    my $response = $browser->request($request);

    if ( $self->trace ) {
        #	carp $response->content;
    }

    my $status = $response->is_success;
    if ( !$status ) {
        my $content = $response->content;
        my $errmsg  = $content;
        if ( $content =~ /<Message>(.*?)<\/Message>/s ) {
            $errmsg = $1;
        }
        print STDERR $errmsg, "\n";
    }
    if ( $self->trace ) {
        carp $response->status_line();
    }

    #my $t1 = gettimeofday();
    #carp "mailing time: " . ($t1 - $t0);
	
	return ($response->code, $response->content);
}

# Gets response sent by amazon
sub get_send_response {
	my $self = shift;
    my $response_content = shift;

    my $parser = XML::LibXML->new();
    my $dom = $parser->parse_string($response_content);
    my $xpath = XML::LibXML::XPathContext->new($dom);
    $xpath->registerNs('ns', $aws_email_ns);
	
    my $messageId = $xpath->find('/ns:SendRawEmailResponse' .
	                             '/ns:SendRawEmailResult' .
								 '/ns:MessageId');

    my $requestId = $xpath->find('/ns:SendRawEmailResponse' .
	                             '/ns:ResponseMetadata' .
	                             '/ns:RequestId');

	return $messageId . "\n" . $requestId;
}

# Prints tha data returned by the service call.
sub get_response {
	
	my $self = shift;
    my $response_content = shift;
	my $r = ''; 

    my $parser = XML::LibXML->new();
    my $dom = $parser->parse_string($response_content);
    my $xpath = XML::LibXML::XPathContext->new($dom);
    $xpath->registerNs('ns', $aws_email_ns);

    my @nodes = $xpath->findnodes('/ns:ListVerifiedEmailAddressesResponse' .
                                  '/ns:ListVerifiedEmailAddressesResult' .
                                  '/ns:VerifiedEmailAddresses' .
                                  '/ns:member');

    foreach my $node (@nodes) {
        my $text = $node->textContent();
        $r .= "$text\n";
    }

	return $r;
}



sub DESTORY {
    my $self = shift;
}

1;
