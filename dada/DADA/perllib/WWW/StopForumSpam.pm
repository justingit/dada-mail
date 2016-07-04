package WWW::StopForumSpam;

use 5.010;
use strict;
use warnings;
use autodie;
use Carp qw(carp croak);
use URI::Escape;
use Digest::MD5 qw(md5_hex);
use Socket;

use Try::Tiny; 
use CGI qw(:oldstyle_urls);
use LWP;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Message;
use Encode qw(encode decode);


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
    
	my $query = {}; 
	
    while(@_) {
        my $attr = shift;
        my $value = shift;		
        if ($attr eq "ip" or $attr eq "email" or $attr eq "username") {
			$query->{$attr} = $value; 
        }
    }
    
    # add default params
	$query->{f} = 'json';
    
    my ($r, $res) = $self->_query_api($query);
    
    # if the api is not working, we don't want to allow potential spammers
    # signing up, so rather force the developers to check their logs...
    if (not defined $r) {
        return 1;
    }
    
	# warn '$r' . $r; 
	
    my $decoded_json = decode_json($r);
	
	#use Data::Dumper; 
	#warn Dumper($decoded_json);
	
	
	
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
	my $query = {};
	
    if(not defined $self->{api_key}) {
        croak "apikey required.";
    }
    
	
    while(@_) {
        my $attr = shift;
        my $value = shift;
        
        if ($attr eq "username" or $attr eq "ip_addr" or $attr eq "evidence" or $attr eq "email") {
            if (length($value) > 0) {
				$query->{$attr} = $value; 
            }
        }
    }
    
    # add default params
    $query->{api_key} = $self->{api_key};
	
    my ($r, $res) = $self->_query_api($query, 1);
    
    if (not defined $r) {
        return 0;
    }
    
    if ($res->status_line == 200) {
        return 1;
    } else {
        warn $self->_strip_tags($r);
        return 0;
    }
}

sub _query_api {

    my ($self, $query, $is_submit) = @_;
    
    if (not defined $is_submit) {
        $is_submit = 0;
    }

	my $url = $self->{api_url};
	
    if ($is_submit) {
		# ... 
	}
	else {
		 $url .= "?" . $self->the_query_string($query); 
	}
	 
    my $ua = LWP::UserAgent->new;
       $ua->agent( 'Mozilla/5.0 (compatible; WWW::StopForumSpam/0.1; +http://www.perlhipster.com/bot.html)');

	   # warn 'URL:' . $url; 
	   
    if ( $self->can_use_compress_zlib() == 1 ) {
        my $can_accept = HTTP::Message::decodable();
		my $res = undef; 
		
	    if ($is_submit) {
	        $res = $ua->get(
				$url, 
				'Accept-Encoding' => $can_accept);
		}
		else {
        	$res = $ua->request( 
				POST 
				$url, 
				content => $query
			);
		}
	
		if ($res->is_success) {
            if(wantarray){
                my $dc = $res->decoded_content;  
                return ($dc, $res); 
            }
            else { 
                return $res->decoded_content;
            }
    	}
    	else { 
    	    carp "Problem fetching url, '$url':" . $res->status_line;
    		if(wantarray){ 
                return (undef, $res); 
            }
            else { 
    		    return undef; 
    	    }
    	}
    }
    else {
		my $res; 
	    if ($is_submit) {
	        $res = $ua->get(
				$url, 
				); 
		}
		else {
        	$res = $ua->request( 
				POST 
				$url, 
				content => $query
			);
		}
	
        if ($res->is_success) {
            if(wantarray){ 
                my $dc = safely_decode( $res->content );      
                return ($dc, $res); 
            }
    		else { 
    		    return safely_decode( $res->content ); 
    		}
        }
    	else { 
    	    carp "Problem fetching url, '$url':" . $res->status_line;
    		if(wantarray){ 
                return (undef, $res); 
            }
            else { 
    		    return undef; 
    	    }
    	}
    }
}


sub can_use_compress_zlib { 
	my $can_use_compress_zlib = 1; 
	try { 
		require Compress::Zlib ;
	}
	catch { 
		$can_use_compress_zlib = 0; 	
	};
	return $can_use_compress_zlib;
}


sub safely_decode { 
	
	my $str   = shift; 
	my $force = shift || 0; 

	
	if(utf8::is_utf8($str) == 1 && $force == 0){ 
	#	warn 'utf8::is_utf8 is returning 1 - not decoding.'; 
	}
	else { 
		eval { 
			$str = Encode::decode('UTF-8', $str); 
		};
		
		if($@){ 
			warn 'Problems: with: (' . $str . '): '. $@; 
		} 
	}
	#warn 'decoding was safely done.';
	return $str;
}

sub the_query_string {
    my $self         = shift;
    my $query_params = shift;
    my $new_q        = CGI->new;
	$new_q->delete_all(); 
    for ( sort { lc $a cmp lc $b } ( keys %$query_params ) ) {
        $new_q->param( $_, $query_params->{$_} );
    }
    my $qs = $new_q->query_string();
    return $qs;
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
