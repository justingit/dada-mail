package DADA::App::WebServices;
use strict;

use lib qw(
  ../../
  ../../DADA/perllib
);

use Carp qw(carp croak);
    $Carp::Verbose = 1;


use DADA::Config qw(!:DEFAULT);
use JSON;
use DADA::Config;
use DADA::App::Guts;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use Digest::SHA qw(hmac_sha256_base64);

use CGI (qw/:oldstyle_urls/);
my $calculated_digest = undef;


use vars qw($AUTOLOAD);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_WebServices};

my %allowed = ( test => 0, );

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
    $self->{q} = CGI->new;
}

sub request {
    my $self   = shift;
    my $status = 1;
    my $errors = {};
    my ($args) = @_;
    for ( '-list', '-service', '-public_key', '-digest', '-cgi_obj' ) {

        my $param = $_;
        $param =~ s/^\-//;

        if ( !exists( $args->{$_} ) ) {

            #croak "You MUST pass the, '" . $_ . "' paramater!";
            $status = 0;
            $errors->{ 'missing_' . $param };
        }
        else {
            $self->{$param} = $args->{$_};
        }
    }

    if ( $self->check_list() == 0 ) {
        $status = 0;
        $errors->{'invalid_list'};
    }

    if ( $status == 1 ) {
        $self->{ls} = DADA::MailingList::Settings->new( { -list => $self->{list} } );
        ( $status, $errors ) = $self->check_request();
    }

    my $r = {};

    if ( $status == 1 ) {

        if ( $self->{service} eq 'validate_subscription' ) {
            $r->{results} = $self->validate_subscription();
            $r->{status}  = 1;
        }
        elsif ( $self->{service} eq 'subscription' ) {
            $r->{results} = $self->subscription();
            $r->{status}  = 1;
        }
        elsif ( $self->{service} eq 'mass_email' ) {
            $r->{results} = $self->mass_email();
            $r->{status}  = 1;
        }
        else {
            $r = {
                status => 0,
                errors => { invalid_request => 1 }
            };
        }
    }
    else {
        $r = {
            status => 0,
            errors => $errors,

            #og_path_info  => $ENV{PATH_INFO},
            #og_service        => $self->{service},
            #og_query          => $self->{cgi_obj}->query_string(),
            #og_digest         => $self->{digest},
            #calculated_digest => $calculated_digest,
            #public_api_key    => $self->{ls}->param('public_api_key'),
            #private_api_key    => $self->{ls}->param('private_api_key'),
        };
        
        #if ( exists( $self->{ls} ) ) {
        #    $r->{public_api_key}  = $self->{ls}->param('public_api_key');
        #    $r->{private_api_key} = $self->{ls}->param('private_api_key');
        #}
    }

    my $d = $self->{q}->header(
        -type            => 'application/json',
        '-Cache-Control' => 'no-cache, must-revalidate',
        -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
    );

    my $json = JSON->new->allow_nonref;
    $d .= $json->pretty->encode($r);
    return $d;

}

sub validate_subscription {
    my $self      = shift;
    my $addresses = $self->{cgi_obj}->param('addresses');

    my $lh                = DADA::MailingList::Subscribers->new( { -list => $self->{list} } );
    my $json              = JSON->new;
    my $decoded_addresses = $json->decode($addresses);

    my $f_addresses = $lh->filter_subscribers_w_meta(
        {
            -emails => $decoded_addresses,
            -type   => 'list',
        }
    );
    
    for(@$f_addresses){ 
        # We don't need these: 
        delete($_->{csv_str}); 
    }
    return $f_addresses;
}

sub subscription {

    my $self                = shift;
    my $addresses           = $self->{cgi_obj}->param('addresses');
    my $lh                  = DADA::MailingList::Subscribers->new( { -list => $self->{list} } );
    my $json                = JSON->new;
    my $decoded_addresses   = $json->decode($addresses);
    my $new_email_count     = 0; 
    my $skipped_email_count = 0; 
         

    my $not_members_fields_options_mode = 'preserve_if_defined';

    my $f_addresses = $lh->filter_subscribers_w_meta(
        {
            -emails => $decoded_addresses,
            -type   => 'list',
        }
    );
    
    my $subscribe_these = [];
    my $filtered_out    = 0;

    for (@$f_addresses) {
        if ( $_->{status} == 1 ) {
            push( @$subscribe_these, $_ );
        }
        else {
            $filtered_out++;
        }
    }
    
    if(scalar(@$subscribe_these) > 0){     
        ( $new_email_count, $skipped_email_count ) = $lh->add_subscribers(
            {
                -addresses => $subscribe_these,
                -type      => 'list',
            }
        );
    }
    
    #-fields_options_mode => undef,
    $skipped_email_count = $skipped_email_count + $filtered_out;
    

    return {
        subscribed_addresses     => $new_email_count,
        skipped_addresses        => $skipped_email_count,
      };

}

sub mass_email {

    my $self    = shift;
    my $subject = $self->{cgi_obj}->param('subject');
    my $format  = $self->{cgi_obj}->param('format');
    my $message = $self->{cgi_obj}->param('message');

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $self->{list} );
    $fm->mass_mailing(1);

    my %headers = ();
    $headers{Subject} = $fm->_encode_header( 'Subject', $subject );

    my $type = 'text/plain';
    if ( $format =~ m/html/i ) {
        $type = 'text/html';
    }

    require MIME::Entity;
    my $entity = MIME::Entity->build(
        Type    => $type,
        Charset => $self->{ls}->param('charset_value'),
        Data    => safely_encode($message),
    );

    my $msg_as_string = ( defined($entity) ) ? $entity->as_string : undef;
    $msg_as_string = safely_decode($msg_as_string);

    $fm->Subject( $headers{Subject} );

    my ( $final_header, $final_body );
    eval { ( $final_header, $final_body ) = $fm->format_headers_and_body( -msg => $msg_as_string ); };
    if ($@) {
        carp "problems! " . $@;
        return;
    }
    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
        {
            -list   => $self->{list},
            -ls_obj => $self->{ls},
        }
    );

    #    $mh->test( $self->test );
    my %mailing = ( $mh->return_headers($final_header), Body => $final_body, );

    my $message_id = $mh->mass_send(
        {
            -msg => {%mailing},
        }
    );

    if ($message_id) {
        if ( $self->{ls}->param('archive_messages') == 1 ) {
            require DADA::MailingList::Archives;
            my $archive = DADA::MailingList::Archives->new( { -list => $self->{list} } );
            $archive->set_archive_info( $message_id, $headers{Subject}, undef, undef, $mh->saved_message );
        }
    }

    
    return {
        message_id => $self->_massaged_key($message_id),
    }

}

sub check_request {

    my $self = shift;

    my $status = 1;
    my $errors = {};

    if ( $self->check_nonce() == 0 ) {
        $status = 0;
        $errors->{invalid_nonce} = 1;
    }
    if ( $self->check_public_key() == 0 ) {
        $status = 0;
        $errors->{invalid_public_key} = 1;
    }
    if ( $self->check_digest() == 0 ) {
        $status = 0;
        $errors->{invalid_digest} = 1;
    }
    if ( $self->check_list() == 0 ) {
        $status = 0;
        $errors->{invalid_list} = 1;
    }

    return ( $status, $errors );
}

sub check_nonce {
    my $self = shift;
    my ( $timestamp, $nonce ) = split( ':', $self->{cgi_obj}->param('nonce') );

    # for now, we throw away $nonce, but we should probably save it for x amount of time
    if ( ( int($timestamp) + ( 60 * 5 ) ) < int(time) ) {
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

    my $self      = shift;
    my $addresses = $self->{cgi_obj}->param('addresses');

    my $qq = CGI->new();
    $qq->delete_all();

    if ( $self->{service} eq 'mass_email' ) {

        $qq->param( 'format',  $self->{cgi_obj}->param('format') );
        $qq->param( 'message', $self->{cgi_obj}->param('message') );
        $qq->param( 'nonce',   $self->{cgi_obj}->param('nonce') );
        $qq->param( 'subject', $self->{cgi_obj}->param('subject') );

    }
    else {
        $qq->param( 'addresses', $self->{cgi_obj}->param('addresses') );
        $qq->param( 'nonce',     $self->{cgi_obj}->param('nonce') );

    }
    
    my $n_digest = $self->digest( $qq->query_string() );
    $calculated_digest = $n_digest;
    if ( $self->{digest} ne $n_digest ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub digest {

    my $self     = shift;
    my $message  = shift;
    my $n_digest = hmac_sha256_base64( $message, $self->{ls}->param('private_api_key') );
    while ( length($n_digest) % 4 ) {
        $n_digest .= '=';
    }
    return $n_digest;
}

sub check_list {
    my $self = shift;
    if ( DADA::App::Guts::list_exists( -List => $self->{list} ) ) {
        return 1;
    }
    else {
        return 0;
    }

}


sub _massaged_key { 


	my $self = shift; 
	my $key  = shift; 
	$key    =~ s/^\<|\>$//g
		if $key;
		
    $key =~ s/^\%3C|\%3E$//g
        if $key;
        
	$key =~ s/^\&lt\;|\&gt\;$//g
	    if $key;
	
	$key    =~ s/\.(.*)//
		if $key; #greedy
	
	return $key; 

}


1;
