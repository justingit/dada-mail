package DADA::App::WebServices;
use strict;

use lib qw(
  ../../
  ../../DADA/perllib
);

use Carp qw(carp croak);


use DADA::Config qw(!:DEFAULT);
use JSON;
use DADA::Config;
use DADA::App::Guts;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use Digest::SHA qw(hmac_sha256_base64);
use Try::Tiny; 

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
            $status = 0;
            $errors->{ 'missing_' . $param };
            warn 'passed param: ' . $_ . ' => ' . $param
              if $t;
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
            $r = $self->validate_subscription();
        }
        elsif ( $self->{service} eq 'subscription' ) {
            $r = $self->subscription();
        }
        elsif ( $self->{service} eq 'unsubscription' ) {
            $r = $self->unsubscription();
        }
        elsif ( $self->{service} eq 'mass_email' ) {
            $r = $self->mass_email();
        }
        elsif ( $self->{service} eq 'settings' ) {
            $r = $self->settings();
        }
        elsif( $self->{service} eq 'update_settings') { 
            $r = $self->update_settings();            
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
        };
    }

    if ($t) {
        $r->{og_path_info}      = $ENV{PATH_INFO};
        $r->{og_service}        = $self->{service};
        $r->{og_query}          = $self->{cgi_obj}->query_string();
        $r->{og_digest}         = $self->{digest};
        $r->{calculated_digest} = $calculated_digest;
        $r->{public_api_key}    = $self->{ls}->param('public_api_key');
        $r->{private_api_key}   = $self->{ls}->param('private_api_key');
        if ( exists( $self->{ls} ) ) {
            $r->{public_api_key}  = $self->{ls}->param('public_api_key');
            $r->{private_api_key} = $self->{ls}->param('private_api_key');
        }
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

    for (@$f_addresses) {

        # We don't need these:
        delete( $_->{csv_str} );
    }
    return {
        status  => 1, 
        results => $f_addresses
    }
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

    #    my $overridden_tests = {
    #        black_listed    => 0,
    #        not_whitelisted => 0,
    #        profile_fields  => 0,
    #    }

    for (@$f_addresses) {
        if ( $_->{status} == 1 ) {
            push( @$subscribe_these, $_ );

            #        }
            #        elsif(1 == 0){ # are there tests we're skippin'?
            #            push( @$subscribe_these, $_ );
        }
        else {
            $filtered_out++;
        }
    }

    if ( scalar(@$subscribe_these) > 0 ) {
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
        status  => 1,
        results =>  {
            subscribed_addresses => $new_email_count,
            skipped_addresses    => $skipped_email_count,
        }
    };

}

sub unsubscription {

    my $self                = shift;
    my $addresses           = $self->{cgi_obj}->param('addresses');
    my $lh                  = DADA::MailingList::Subscribers->new( { -list => $self->{list} } );
    my $json                = JSON->new;
    my $decoded_addresses   = $json->decode($addresses);
    my $removed_email_count = 0;
    my $skipped_email_count = 0;
    my $blacklisted_count   = 0;

    my $f_addresses = $lh->filter_subscribers_w_meta(
        {
            -emails => $decoded_addresses,
            -type   => 'list',
        }
    );

    my $unsubscribe_these = [];
    my $filtered_out      = 0;

    for (@$f_addresses) {
        if ( $_->{status} == 0 && $_->{errors}->{subscribed} == 1 ) {
            push( @$unsubscribe_these, $_->{email} );
        }
        else {
            $filtered_out++;
        }
    }

    if ( scalar(@$unsubscribe_these) > 0 ) {
        ( $removed_email_count, $blacklisted_count ) = $lh->admin_remove_subscribers(
            {
                -addresses => $unsubscribe_these,
                -type      => 'list',
            }
        );
    }

    $skipped_email_count = $skipped_email_count + $filtered_out;

    return {
        status  => 1,
        results =>  {
            unsubscribed_addresses => $removed_email_count,
            skipped_addresses      => $skipped_email_count,
        }
    };
}

sub mass_email {

    my $self    = shift;
    my $subject = $self->{cgi_obj}->param('subject');
    my $format  = $self->{cgi_obj}->param('format');
    my $message = $self->{cgi_obj}->param('message');
    my $test    = $self->{cgi_obj}->param('test') || 0;

    my $type = 'text/plain';
    if ( $format =~ m/html/i ) {
        $type = 'text/html';
    }
    my $qq = CGI->new();
       $qq->delete_all();
        
        $qq->param('Subject', $subject); 
        if($type eq 'text/html'){ 
            $qq->param('html_message_body', $message); 
        }
        else { 
            $qq->param('text_message_body', $message); 
        }
        $qq->param('f', 'send_email');
        $qq->param('draft_role', 'draft'); 
    
        require DADA::App::MassSend; 
        my $dam = DADA::App::MassSend->new({-list => $self->{list}}); 
        my $draft_id = $dam->save_as_draft(
            {
                -cgi_obj => $qq,
                -list    => $self->{list},
                -json    => 0,
                
            }
        );
        
        my $process; 
        if($test == 1){ 
            $process = 'test'; 
        }
        else { 
            $process = 1; 
        }
        # to fetch a draft, I need id, list and role (lame)
        my ( $status, $errors, $message_id ) = $dam->construct_and_send(
            {
                -draft_id => $draft_id,
                -screen   => 'send_email',
                -role     => 'draft',
                -process  => $process,
            }
        );
        $dam->delete_draft($draft_id); 
        
    if ( $status == 0 ) {
       return {
           status => 0,
           results =>  {
               error => $errors        
            }
         };
    }
    else { 
        return {
            status  => 1,
            results =>  {
                message_id => $self->_massaged_key($message_id), 
            }
        };
    }
}

sub settings {
    my $self = shift; 
    warn 'settings called'
      if $t;
     
      return {
          status  => 1,
          results =>  {
              settings => $self->{ls}->get()
        }
    };
}

sub update_settings { 

    my $self = shift; 


    my $json = JSON->new->allow_nonref;
    my $r = {}; 
        
    my $settings = $self->{cgi_obj}->param('settings');
       $settings = $json->decode($settings);
        
    try {
        $self->{ls}->save($settings);  
        $r = {
            status  => 1,
            results => {saved => 1},
        };
    } catch {
      $r = {
          status => 0,
          errors => $_        
        };
    };
    
    return $r; 
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

    if ($t) {
        require Data::Dumper;
        warn 'check_request: ' . Data::Dumper::Dumper( { status => $status, errors => $errors } );
    }
    return ( $status, $errors );
}

sub check_nonce {
    my $self = shift;
    my ( $timestamp, $nonce ) = split( ':', $self->{cgi_obj}->param('nonce'));
    
    my $r = 0;

    # for now, we throw away $nonce, but we should probably save it for x amount of time
    if ( ( int($timestamp) + ( 60 * 5 ) ) < int(time) ) {
        $r = 0;
    }
    else {
        $r = 1;
    }
    warn 'check_nonce: ' . $r
      if $t;
      
   return $r; 
}

sub check_public_key {

    my $self = shift;
    my $r    = 0;

    if ( $self->{ls}->param('public_api_key') ne $self->{ls}->param('public_api_key') ) {
        $r = 0;
    }
    else {
        $r = 1;
    }
    warn 'check_public_key ' . $r
      if $t;
      
     return $r; 
}

sub check_digest {

    my $self = shift;
    my $r    = 0;

    my $qq = CGI->new();
       $qq->delete_all();

    my $n_digest = undef; 


    if ( $self->{service} eq 'mass_email' ) {
        $qq->param( 'format',  $self->{cgi_obj}->param('format') );
        $qq->param( 'message', $self->{cgi_obj}->param('message') );
        $qq->param( 'nonce',   $self->{cgi_obj}->param('nonce') );
        $qq->param( 'subject', $self->{cgi_obj}->param('subject') );
        # optional
        if(defined($self->{cgi_obj}->param('test'))){ 
            $qq->param( 'test', $self->{cgi_obj}->param('test') );
        }
        $n_digest = $self->digest( $qq->query_string() );
    }
    elsif ( $self->{service} eq 'update_settings' ) {
        $qq->param( 'nonce',     $self->{cgi_obj}->param('nonce') );
        $qq->param( 'settings',  $self->{cgi_obj}->param('settings') );
        $n_digest = $self->digest( $qq->query_string() );    
    }
    elsif($self->{service} eq 'settings' ){ 
        $n_digest = $self->digest($self->{cgi_obj}->param('nonce'));
    }else {
        $qq->param( 'addresses', $self->{cgi_obj}->param('addresses') );
        $qq->param( 'nonce',     $self->{cgi_obj}->param('nonce') );
        $n_digest = $self->digest( $qq->query_string() );
        
    }
    # debug'n
    
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
    
    warn '$message ' . $message 
        if $t; 
        
    my $n_digest = hmac_sha256_base64( $message, $self->{ls}->param('private_api_key') );
    while ( length($n_digest) % 4 ) {
        $n_digest .= '=';
    }
    
    warn '$n_digest:' . $n_digest
        if $t; 
        
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
