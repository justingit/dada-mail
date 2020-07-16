package WWW::StopForumSpam;

use 5.010;
use strict;
use warnings;
use autodie;
use Carp qw(croak);
use URI::Escape;
use Digest::MD5 qw(md5_hex);
use Socket;
use WWW::Curl::Easy;
use JSON qw(decode_json);

our $VERSION = '0.02';

sub new {
    my $class = shift;
    my $self = bless({}, $class);

    # parse params
    while(@_) {
        my $attr = shift;
        my $value = shift;
        
        if($attr eq "timeout") {
            $self->{timeout} = 0 + $value;
        } elsif($attr eq "api_key") {
            $self->{api_key} = "$value";
        } elsif($attr eq "api_url") {
            $self->{api_url} = "$value";
        } elsif($attr eq "dnsbl") {
            $self->{dnsbl} = "$value";
        } elsif($attr eq "treshold") {
            $self->{treshold} = 0 + $value;
        }
    }
    
    # validate / set defaults
    $self->{api_url} = "http://www.stopforumspam.com/api" unless exists $self->{api_url};
    $self->{dnsbl} = "sfs.dnsbl.st." unless exists $self->{dnsbl};
    $self->{timeout} = 4 unless exists $self->{timeout};
    $self->{connect_timeout} = $self->_ceil($self->{timeout} / 2);
    $self->{treshold} = 65 unless exists $self->{treshold};
    return $self;
}

sub check {
    my $self = shift;
    my @request_params = ();
     
    while(@_) {
        my $attr = shift;
        my $value = shift;
        
        if ($attr eq "ip" or $attr eq "email" or $attr eq "username") {
            push(@request_params, $attr . "=" . uri_escape($value));
        }
    }
    
    # add default params
    push(@request_params, "f=json");
    
    my ($http_code, $buffer) = $self->_query_api(join("&", @request_params));
    
    # if the api is not working, we don't want to allow potential spammers
    # signing up, so rather force the developers to check their logs...
    if (not defined $buffer) {
        return 1;
    }
    
    my $decoded_json = decode_json($buffer);
    if(not defined $decoded_json->{'success'}) {
        warn "unable to read json";
        return 1;
    } elsif($decoded_json->{'success'} == 0) {
        warn $decoded_json->{'error'};
        return 1;
    }
    
    if($self->_get_avg_confidence($decoded_json) > $self->{treshold}) {
        return 1;
    }
    
    return 0;
}

sub dns_check {
    my $self = shift;
    
    my $packed_ip;
    my $ip_address;
    
    while(@_) {
        my $attr = shift;
        my $value = shift;
        
        if ($attr eq "ip") {
            $packed_ip = gethostbyname(join('.', reverse split(/\./, $value)) . "." . $self->{dnsbl});
            if (not defined $packed_ip) {
                next;
            }
            
            $ip_address = inet_ntoa($packed_ip);
            if ($ip_address eq "127.0.0.2") {
                return 1;
            }
            
        } elsif ($attr eq "email") {
            $packed_ip = gethostbyname(md5_hex($value) . "." . $self->{dnsbl});
            if (not defined $packed_ip) {
                next;
            }
            
            $ip_address = inet_ntoa($packed_ip);
            if ($ip_address eq "127.0.0.3") {
                return 1;
            }
        }
    }
    
    return 0;
}

sub report {
    my $self = shift;
    my @request_params = ();
    
    if(not defined $self->{api_key}) {
        croak "apikey required.";
    }
    
    while(@_) {
        my $attr = shift;
        my $value = shift;
        
        if ($attr eq "username" or $attr eq "ip_addr" or $attr eq "evidence" or $attr eq "email") {
            if (length($value) > 0) {
                push(@request_params, $attr . "=" . uri_escape($value));
            }
        }
    }
    
    # add default params
    push(@request_params, "api_key=" . $self->{api_key});
    
    my ($http_code, $buffer) = $self->_query_api(join("&", @request_params), 1);
    
    if (not defined $buffer) {
        return 0;
    }
    
    if ($http_code == 200) {
        return 1;
    } else {
        warn $self->_strip_tags($buffer);
        return 0;
    }
}

sub _query_api {
    my ($self, $data, $is_submit) = @_;
    
    if (not defined $is_submit) {
        $is_submit = 0;
    }
    
    my $buffer = "";
    my $curl = WWW::Curl::Easy->new();
    
    if ($is_submit) {
        $curl->setopt(CURLOPT_URL, "http://www.stopforumspam.com/add.php");
        $curl->setopt(CURLOPT_POST, 1);
        $curl->setopt(CURLOPT_POSTFIELDS, $data);
    } else {
        $curl->setopt(CURLOPT_URL, $self->{api_url} . "?" . $data);
    }
    
    $curl->setopt(CURLOPT_USERAGENT, "Mozilla/5.0 (compatible; WWW::StopForumSpam/0.1; +http://www.perlhipster.com/bot.html)");
    $curl->setopt(CURLOPT_ENCODING, "");
    $curl->setopt(CURLOPT_NOPROGRESS, 1);
    $curl->setopt(CURLOPT_FAILONERROR, 0);
    $curl->setopt(CURLOPT_TIMEOUT, $self->{timeout});
    $curl->setopt(CURLOPT_WRITEFUNCTION, sub {
        $buffer .= $_[0];
        return length($_[0]);
    });
    
    my $retcode = $curl->perform();
    
    if($retcode != 0) {
        warn $curl->errbuf;
        return;
    }
    
    return ($curl->getinfo(CURLINFO_HTTP_CODE), $buffer);
}

sub _get_avg_confidence {
    my ($self, $decoded_json) = @_;
    my $confidence_total = 0;
    my $confidence_num = 0;
    
    if(defined $decoded_json->{'username'}) {
        if (defined $decoded_json->{'username'}{'confidence'}) {
            $confidence_total += $decoded_json->{'username'}{'confidence'};
        }
        $confidence_num++;
    }
    if(defined $decoded_json->{'email'}) {
        if (defined $decoded_json->{'email'}{'confidence'}) {
            $confidence_total += $decoded_json->{'email'}{'confidence'};
        }
        $confidence_num++;
    }
    if(defined $decoded_json->{'ip'}) {
        if (defined $decoded_json->{'ip'}{'confidence'}) {
            $confidence_total += $decoded_json->{'ip'}{'confidence'};
        }
        $confidence_num++;
    }
    
    return $confidence_total / $confidence_num;
}

sub _ceil {
    my ($self, $num) = @_;
    return int($num) + ($num > int($num));
}

sub _strip_tags {
    my ($self, $string) = @_;
    while ($string =~ s/<\S[^<>]*(?:>|$)//gs) {};
    return $string;
}

1;
__END__

=encoding utf8

=head1 NAME

WWW::StopForumSpam - Perl extension for the StopForumSpam.com API

=head1 DESCRIPTION

StopForumSpam is a Anti Spam Database for free usage. Even though aimed towards
preventing registration of spambots on a forum, this extension can be used for
any type of website (e.g. blog) as well.

An API key is only needed for reporting a new case of spam registration.

=head1 SYNOPSIS

    use WWW::StopForumSpam;

    my $sfs = WWW::StopForumSpam->new(
        api_key => "",                  # optional
        timeout => 4,                   # cURL timeout in seconds, defaults to 4
        treshold => 65,                 # defaults to 65
    );
    
    # Returns 1 if spammer (caution: it will return 1 also on errors, this is to
    # prevent mass spam registration due to services not working properly, you 
    # should therefor always check logs)
    $sfs->check(
        ip => "127.0.0.1",              # optional, recommended
        email => "test\@test.com",      # optional, recommended
        username => "Foobar",           # optional, not recommended
    );
    
    # Alternative api call via DNSBL. Does not support usernames.
    # Unlike check() this will NOT return 1 on server fail. 
    $sfs->dns_check(
        ip => "127.0.0.1",
        email => "test\@test.com",
    );
    
    # Requires the setting of "api_key" in the constructor
    $sfs->report(
        username => "Foobar",           # required
        ip_addr => "127.0.0.1",         # required
        evidence => "",                 # optional (for example the forum-post)
        email => "test\@test.com",      # required
    );
);

=head1 SEE ALSO

API keys and more detail on StopForumSpam are available at L<http://www.stopforumspam.com>.

Github: L<https://github.com/lifeofguenter/p5-stopforumspam>

Website: L<http://www.perlhipster.com/p5-stopforumspam>

DNSBL: L<http://sfs.dnsbl.st>

=head1 AUTHOR

Günter Grodotzki, E<lt>guenter@perlhipster.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Günter Grodotzki

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
