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

package DADA::App::Support::Net::Amazon::SES;



use lib "../../";
use lib "../../DADA/perllib";
use lib './';
use lib './DADA/perllib';

use strict;
use warnings;
our $VERSION = '1.00';
use base 'Exporter';
our @EXPORT = qw();
#use Switch;
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64 sha256);
use URI::Escape qw (uri_escape_utf8);
use LWP;
# I don't know if you need this - although it would throw an error if it's not found (I may remove)
use LWP::Protocol::https;
use Carp qw(croak carp);
use vars qw($AUTOLOAD);
use Encode qw(encode);
use XML::LibXML; 
use AWS::Signature4;


use DADA::App::Guts; 


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
    
	# don't do any work if we are being called for DESTROY
    return if(substr($AUTOLOAD, -7) eq 'DESTROY');
	
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

	return make_ua(
		{
			-keep_alive => 5,
		}
	);
}



sub sender_verified { 

    my $self  = shift; 
    my $email = shift; 
	
    my ($name, $domain) = split('@', $email, 2); 
	
	# This is very limited and contrived
	# See: https://metacpan.org/pod/Domain::PublicSuffix
	if($domain =~ m/\.(com|net|org|edu|gov)$/){
		#subdomain? 
		my $count = ($domain =~ tr/\.//);
		if($count > 1){ 
			my @p = split(/\./, $domain);
			$domain = $p[-2] . '.' . $p[-1];
		}
	}
	
	
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

    @nodes = $xpath->findnodes('/ns:GetSendQuotaResponse' .
                                   '/ns:GetSendQuotaResult');

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
   # $request->header( "If-SSL-Cert-Subject" => "/CN=$endpoint_name" );
    $request->content($payload);
    $request->content_type('application/x-www-form-urlencoded');
  
     my $signer = AWS::Signature4->new(-access_key => $self->AWSAccessKeyId,
                                       -secret_key => $self->AWSSecretKey);
 	    $signer->sign($request);

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
        carp $errmsg;
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



sub DESTORY {}
	

1;

__END__