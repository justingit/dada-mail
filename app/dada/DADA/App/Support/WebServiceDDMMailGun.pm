package DADA::App::Support::WebServiceDDMMailGun;


use 5.008001;
use strict;
use warnings;

#use Furl;
use JSON;
use URI;
use Try::Tiny;
use Carp;
use HTTP::Request::Common;
use File::Temp;


our $VERSION = "0.15";
our $API_BASE = 'api.mailgun.net/v3';
our $API_BASE_EU = 'api.eu.mailgun.net/v3';

use Class::Accessor::Lite (
    new => 1,
    rw  => [qw(api_key domain RaiseError region)],
    ro  => [qw(error error_status)],
);

sub decode_response {
    my ($self, $res) = @_;

    if ($res->is_success) {
        return decode_json $res->content;
    } else {
        my $json;
        try {
            $json = decode_json $res->content;
        } catch {
            $json = { message => $res->content };
        };
        $self->{error} = $json->{message};
        $self->{error_status} = $res->status_line;
        if ($self->RaiseError) {
            carp $self->error;
            croak $self->error_status;
        } else {
            return;
        }
    }
}

sub recursive {
    my ($self, $method, $query, $key, $api_uri) = @_;

    $query //= {};
    $key //= 'items';
    my @result;
    my $previous;
    unless($api_uri) {
        $api_uri = URI->new($self->api_url($method));
        $api_uri->query_form($query);
    }

    while (1) {
        my $res = $self->client->get($api_uri->as_string);
        my $json = $self->decode_response($res);
        unless($json && scalar @{$json->{$key}}) {
            try {
                $previous = URI->new($json->{paging}->{previous});
                $previous->userinfo('api:'.$self->api_key);
            } catch {};
            last;
        }
        push @result, @{$json->{$key}};
        $api_uri = URI->new($json->{paging}->{next});
        $api_uri->userinfo('api:'.$self->api_key);
    }

    return \@result, $previous;
}

sub client {
    my $self = shift;
	use DADA::App::Guts; 
	my $agent = make_ua(); 
	
	$self->{_client} //= $agent;
	
    #$self->{_client} //= Furl->new(
    #    agent => __PACKAGE__ . '/' . $VERSION,
    #);
}

sub api_base {
    my ($self) = @_;

    if ($self->region) {
        if (lc($self->region) eq "eu") {
            return $API_BASE_EU;
        } elsif (lc($self->region) ne "us") {
            die "unsupported region '" . $self->region ."'";
        }
    }
    return $API_BASE;
}

sub api_url {
    my ($self, $method) = @_;

    sprintf 'https://api:%s@%s/%s',
        $self->api_key, $self->api_base, $method;
}

sub domain_api_url {
    my ($self, $method) = @_;

    sprintf 'https://api:%s@%s/%s/%s',
        $self->api_key, $self->api_base, $self->domain, $method;
}

sub message {
    my ($self, $args) = @_;

    my @content;
    if (ref($args) eq 'HASH') {
        @content = %$args;
    }
    elsif (ref($args) eq 'ARRAY') {
        @content = @$args;
    }
    else {
        die 'unsupport argument. message() need HashRef or ArrayRef.';    
	}

    my $req = POST $self->domain_api_url('messages'), Content_type => 'form-data', Content => \@content;

    my $res = $self->client->request($req);
    $self->decode_response($res);
}



sub mime { 
		
    my ($self, $args) = @_;

    if (ref($args) eq 'HASH') {
        # Well, good!
    }
    else {
        die 'unsupport argument. mime() needs a hash ref.';
    }
	
	
	my $tmp = undef; 

	if(exists($args->{message})){
		$tmp = File::Temp->new();
		
		if(ref $args->{message} eq 'SCALAR'){ 
			# save from a ref
			print $tmp ${$args->{message}};
			seek $tmp, 0, 0;
		}
		else {
			# Save from a string
			print $tmp $args->{message};
			seek $tmp, 0, 0;
		}
		$args->{message} = [$tmp->filename];
	}
	elsif(exists($args->{file})){ 
		if(-f $args->{file}){ 
			$args->{message} =  [$args->{file}];
			delete $args->{file}; 
		}
		else { 
			die "cannot find file, " . $args->{file}; 
		}
	}
	
	# Put it back together: 
	my @content = %$args;

    my $req = POST $self->domain_api_url('messages.mime'), 
		Content_Type => 'form-data', 
		Content => \@content;
		
    my $res = $self->client->request($req);
	
	undef $tmp; 
	
    $self->decode_response($res);

}




sub lists {
    my $self = shift;

    return $self->recursive('lists/pages');
}

sub add_list {
    my ($self, $args) = @_;

    my $res = $self->client->post($self->api_url("lists"), [], $args);
    $self->decode_response($res);
}

sub list {
    my ($self, $address) = @_;

    my $res = $self->client->get($self->api_url("lists/$address"));
    my $json = $self->decode_response($res) or return;
    return $json->{list};
}

sub update_list {
    my ($self, $address, $args) = @_;

    my $res = $self->client->put($self->api_url("lists/$address"), [], $args);
    $self->decode_response($res);
}

sub delete_list {
    my ($self, $address) = @_;

    my $res = $self->client->delete($self->api_url("lists/$address"));
    $self->decode_response($res);
}

sub list_members {
    my ($self, $address) = @_;

    return $self->recursive("lists/$address/members/pages");
}

sub add_list_member {
    my ($self, $address, $args) = @_;

    my $res = $self->client->post(
        $self->api_url("lists/$address/members"), [], $args);
    $self->decode_response($res);
}

sub add_list_members {
    my ($self, $address, $args) = @_;

    my $res = $self->client->post(
        $self->api_url("lists/$address/members.json"), [], $args);
    $self->decode_response($res);
}

sub list_member {
    my ($self, $address, $member) = @_;

    my $res = $self->client->get($self->api_url("lists/$address/members/$member"));
    my $json = $self->decode_response($res) or return;
    return $json->{member};
}

sub update_list_member {
    my ($self, $address, $member, $args) = @_;

    my $res = $self->client->put(
        $self->api_url("lists/$address/members/$member"), [], $args);
    $self->decode_response($res);
}

sub delete_list_member {
    my ($self, $address, $member) = @_;

    my $res = $self->client->delete(
        $self->api_url("lists/$address/members/$member"));
    $self->decode_response($res);
}

sub event {
    my ($self, $query) = @_;

    my $api_url = URI->new($self->domain_api_url("events"));
    $api_url->query_form($query);
    return $self->recursive("events", {}, "items", $api_url);
}

sub get_message_from_event {
    my ($self, $event) = @_;

    die "invalid event! this method need 'stored' event only." if $event->{event} ne 'stored';
    my $uri = URI->new($event->{storage}->{url});
    $uri->userinfo('api:'.$self->api_key);

    my $res = $self->client->get($uri->as_string);
    $self->decode_response($res);
}

sub delete_templates {
    my ($self) = @_;

    my $res = $self->client->delete($self->domain_api_url("templates"));
    $self->decode_response($res);
}

sub delete_template {
    my ($self, $name) = @_;

    my $res = $self->client->delete(
        $self->domain_api_url("templates/$name"));
    $self->decode_response($res);
}

sub add_template {
    my ($self, $args) = @_;

    my @content;
    if (ref($args) eq 'HASH') {
        @content = %$args;
    }
    elsif (ref($args) eq 'ARRAY') {
        @content = @$args;
    }
    else {
        die 'unsupport argument. add_template() need HashRef or ArrayRef.';
    }

    my $req = POST $self->domain_api_url('templates'), Content_type => 'form-data', Content => \@content;

    my $res = $self->client->request($req);
    $self->decode_response($res);
}

1;
__END__

=encoding utf-8

=head1 NAME

WebService::Mailgun - API client for Mailgun (L<https://mailgun.com/>)

=head1 SYNOPSIS

    use WebService::Mailgun;

    my $mailgun = WebService::Mailgun->new(
        api_key => '<YOUR_API_KEY>',
        domain => '<YOUR_MAIL_DOMAIN>',
    );

    # send mail
    my $res = $mailgun->message({
        from    => 'foo@example.com',
        to      => 'bar@example.com',
        subject => 'test',
        text    => 'text',
    });

=head1 DESCRIPTION

WebService::Mailgun is API client for Mailgun (L<https://mailgun.com/>).

=head1 METHOD

=head2 new(api_key => $api_key, domain => $domain, region => "us"|"eu", RaiseError => 0|1)

Create mailgun object.

=head3 RaiseError (default: 0)

The RaiseError attribute can be used to force errors to raise exceptions rather than simply return error codes in the normal way. It is "off" by default.

=head3 region (default: "us")

The region attribute determines what region the domain belongs to, either US or EU. Default is US.

=head2 error

return recent error message.

=head2 error_status

return recent API result status_line.

=head2 message($args)

Send email message.

    # send mail
    my $res = $mailgun->message({
        from    => 'foo@example.com',
        to      => 'bar@example.com',
        subject => 'test',
        text    => 'text',
    });

L<https://documentation.mailgun.com/en/latest/api-sending.html#sending>

=head2 mime($args)

Send a MIME message you build yourself, usually by using a library to create that MIME message. 
The C<to> parameter needs to be passed as one of the arguments. 
Either the C<file> or C<message> parameter will also need to be passed. 

The C<file> parameter should contain the path to the filename that holds the MIME message. 
The C<message> parameter should contain either a string or a reference to a string that holds the MIME message: 

    # send MIME message via a filename: 
    my $res = $mailgun->message({
    	to      => 'bar@example.com',
		file    => '/path/to/filename.mime',	
    });

    # send MIME message via a string:
	use MIME::Entity; 
	my $str = MIME::Entity->build(
		From    => 'justin@dadamailproject.com',
        To      => 'justin@dadamailproject.com',
        Subject => "Subject",
        Data    => 'Messag4')->as_string;
	
    my $res = $mailgun->message({
    	to       => 'bar@example.com',
		message  => $str,
    });

    # or send MIME message via a string ref:	
    my $res = $mailgun->message({
    	to       => 'bar@example.com',
		message  => \$str,
    });

L<https://documentation.mailgun.com/en/latest/api-sending.html#sending>


=head2 lists()

Get list of mailing lists.

    # get mailing lists
    my $lists = $mailgun->lists();
    # => ArrayRef of mailing list object.

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 add_list($args)

Add mailing list.

    # add mailing list
    my $res = $mailgun->add_list({
        address => 'ml@example.com', # Mailing list address
        name    => 'ml sample',      # Mailing list name (Optional)
        description => 'sample',     # description (Optional)
        access_level => 'members',   # readonly(default), members, everyone
    });

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 list($address)

Get detail for mailing list.

    # get mailing list detail
    my $data = $mailgun->list('ml@exmaple.com');

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 update_list($address, $args)

Update mailing list detail.

    # update mailing list
    my $res = $mailgun->update_list('ml@example.com' => {
        address => 'ml@example.com', # Mailing list address (Optional)
        name    => 'ml sample',      # Mailing list name (Optional)
        description => 'sample',     # description (Optional)
        access_level => 'members',   # readonly(default), members, everyone
    });

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 delete_list($address)

Delete mailing list.

    # delete mailing list
    my $res = $mailgun->delete_list('ml@example.com');

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 list_members($address)

Get members for mailing list.

    # get members
    my $res = $mailgun->list_members('ml@example.com');

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 add_list_member($address, $args)

Add member for mailing list.

    # add member
    my $res = $mailgun->add_list_member('ml@example.com' => {
        address => 'user@example.com', # member address
        name    => 'username',         # member name (Optional)
        vars    => '{"age": 34}',      # member params(JSON string) (Optional)
        subscribed => 'yes',           # yes(default) or no
        upsert     => 'no',            # no (default). if yes, update exists member
    });

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 add_list_members($address, $args)

Adds multiple members for mailing list.

    use JSON; # auto export 'encode_json'

    # add members
    my $res = $mailgun->add_list_members('ml@example.com' => {
        members => encode_json [
            { address => 'user1@example.com' },
            { address => 'user2@example.com' },
            { address => 'user3@example.com' },
        ],
        upsert  => 'no',            # no (default). if yes, update exists member
    });

    # too simple
    my $res = $mailgun->add_list_members('ml@example.com' => {
        members => encode_json [qw/user1@example.com user2@example.com/],
    });

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 list_member($address, $member_address)

Get member detail.

    # update member
    my $res = $mailgun->list_member('ml@example.com', 'user@example.com');

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 update_list_member($address, $member_address, $args)

Update member detail.

    # update member
    my $res = $mailgun->update_list_member('ml@example.com', 'user@example.com' => {
        address => 'user@example.com', # member address (Optional)
        name    => 'username',         # member name (Optional)
        vars    => '{"age": 34}',      # member params(JSON string) (Optional)
        subscribed => 'yes',           # yes(default) or no
    });

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 delete_list_members($address, $member_address)

Delete member for mailing list.

    # delete member
    my $res = $mailgun->delete_list_member('ml@example.com' => 'user@example.com');

L<https://documentation.mailgun.com/en/latest/api-mailinglists.html#mailing-lists>

=head2 event($args)

Get event data.

    # get event data
    my ($events, $purl) = $mailgun->event({ event => 'stored', limit => 50 });

L<Events|https://documentation.mailgun.com/en/latest/api-events.html>

=head2 get_message_from_event($event)

Get stored message.

    # get event data
    my ($events, $purl) = $mailgun->event({ event => 'stored' });
    my $msg = $mailgun->get_message_from_event($events->[0]);

L<Stored Message|https://documentation.mailgun.com/en/latest/api-sending.html#retrieving-stored-messages>

=head2 add_template($args)

Add a template

    # add template
    my $res = $mailgun->add_template({
        name        => 'welcome',     # Template name
        template    => 'Hello!',      # Template data
        engine      => 'handlebars',  # Template engine (optional)
        description => 'xyz',         # Description of template (optional)
        tag         => '2.0' ,        # Version tag (optional)
        comment     => 'Test'         # Version comment (optional)
    });

L<https://documentation.mailgun.com/en/latest/api-templates.html#templates>

=head2 delete_templates()

Delete all templates

    my $res = $mailgun->delete_templates();

L<https://documentation.mailgun.com/en/latest/api-templates.html#templates>

=head2 delete_template($name)

Delete a template

    my $res = $mailgun->delete_template($name);

L<https://documentation.mailgun.com/en/latest/api-templates.html#templates>

=head1 Event Pooling

event method return previous url. it can use for fetch event.

    # event Pooling
    my ($events, $purl) = $mailgun->event({ event => 'stored', begin => localtime->epoch() });
    // do something ...
    $events = $mailgun->event($purl);
    // ...

L<Event Polling|https://documentation.mailgun.com/en/latest/api-events.html#event-polling>    



=head1 TODO

this API not implement yet.

=over

=item * L<Domains|https://documentation.mailgun.com/en/latest/api-domains.html>

=item * L<Stats|https://documentation.mailgun.com/en/latest/api-stats.html>

=item * L<Tags|https://documentation.mailgun.com/en/latest/api-tags.html>

=item * L<Suppressions|https://documentation.mailgun.com/en/latest/api-suppressions.html>

=item * L<Routes|https://documentation.mailgun.com/en/latest/api-routes.html>

=item * L<Webhooks|https://documentation.mailgun.com/en/latest/api-webhooks.html>

=item * L<Email Validation|https://documentation.mailgun.com/en/latest/api-email-validation.html>

=item * L<Templates|https://documentation.mailgun.com/en/latest/api-templates.html> (partial)

=back

=head1 SEE ALSO

L<WWW::Mailgun>, L<https://documentation.mailgun.com/en/latest/>

=head1 LICENSE

Copyright (C) Kan Fushihara.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara@gmail.comE<gt>

=cut

