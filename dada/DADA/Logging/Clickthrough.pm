package DADA::Logging::Clickthrough; 


use lib qw(../../ ../../perllib);

BEGIN {
    $type = $DADA::Config::CLICKTHROUGH_DB_TYPE;
    if ( $type =~ m/sql/i ) {
        $type = 'baseSQL';
    }
    else {
        $type = 'Db';
    }
}

use base "DADA::Logging::Clickthrough::$type";

use strict; 
use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts;

use Fcntl qw(LOCK_SH);
use Carp qw(croak carp); 


sub _init { 
	
	my $self   = shift; 
	my ($args) = @_; 

    if($self->{-new_list} != 1){ 
    	croak('BAD List name "' . $args->{-list} . '" ' . $!) if $self->_list_name_check($args->{-list}) == 0; 
	}else{ 
		$self->{name} = $args->{-list}; 
	}	
	
    
	if(! defined($self->{-li}) ){ 
	    
	    require DADA::MailingList::Settings; 
        my $ls = DADA::MailingList::Settings->new({-list => $self->{name}}); 
	    $self->{-li} = $ls->get; 
	}
	
	$self->{is_redirect_on}                  = $self->redirect_config_test; 	# kinda hardcore, you know? 
	$self->{is_log_openings_on}              = $self->{-li}->{enable_open_msg_logging}; 
	$self->{is_log_bounces_on}               = $self->{-li}->{enable_bounce_logging};
	$self->{enable_subscriber_count_logging} = $self->{-li}->{enable_subscriber_count_logging},
	
	
	return $self;

}

sub redirect_config_test { 
	my $self = shift; 	
	
	return 0 if (!$self->{name}) || ($self->{name} eq ""); 
	return 0 unless DADA::App::Guts::check_if_list_exists(-List => $self->{name}) >= 1;
	return 0 if $self->{-li}->{clickthrough_tracking} != 1;
	return 1;
}

sub verified_mid { 
	my $self = shift; 
	my $mid  = shift; 
	# This could be stronger, but... 
	if ($mid =~ /^\d+$/ && length($mid) == 14) {
		return 1; 
	}
	else { 
		return 0; 
	}
}



sub report_by_url { 
	my $self      = shift; 
	my $match_mid = shift; 
	my $match_url = shift;
	
	my $report = []; 
	my $l;
	
	open(LOG, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $self->clickthrough_log_location)
	 or croak "Couldn't open file: '" . $self->clickthrough_log_location . '\'because: ' .  $!;
	while(defined($l = <LOG>)){ 
		chomp($l); 
		my ($t, $mid, $url) = split("\t", $l); 
		if($url ne 'open' && $url ne 'num_subscribers'){
			if(($match_mid == $mid) && ($match_url eq $url)){ 
				push(@$report, $t);
			}
		}
	}
	close(LOG); 
	return $report; 
}






sub clickthrough_log_location { 

	my $self = shift; 
	my $ctl  =  $DADA::Config::LOGS  . '/' . $self->{name} . '-clickthrough.log';
	   $ctl  = DADA::App::Guts::make_safer($ctl);
	   $ctl =~ /(.*)/;
	   $ctl = $1; 
	   return $ctl; 
}

##############################################################################

sub parse_email {

    my $self = shift;
    my ($args) = @_;

    # Actually, I think they want dada-style args. Damn them!
    #	if(!exists($args->{-entity})){
    #		croak "you MUST pass an -entity!";
    #	}
    if ( !exists( $args->{ -mid } ) ) {
        croak "you MUST pass an -mid!";
    }

    # Massaging:
    $args->{ -mid } =~ s/\<|\>//g;
    $args->{ -mid } =~ s/\.(.*)//;    #greedy

    # This here, is pretty weird:

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -yeah_no_list => 1 );

    my $entity = $fm->entity_from_dada_style_args($args);

    $entity = $self->parse_entity(
        {
            -entity => $entity,
            -mid    => $args->{ -mid },
        }
    );

    my $msg = $entity->as_string;
	   $msg = safely_decode($msg); 

    my ( $h, $b ) = split ( "\n\n", $msg, 2 );

    my %final = ( $self->return_headers($h), Body => $b, );

    return %final;

}

sub return_headers {

    my $self = shift;

    #get the blob
    my $header_blob = shift || "";

    #init a new %hash
    my %new_header;

    # split.. logically
    my @logical_lines = split /\n(?!\s)/, $header_blob;

    # make the hash
    for my $line (@logical_lines) {
        my ( $label, $value ) = split ( /:\s*/, $line, 2 );
        $new_header{$label} = $value;
    }
    return %new_header;

}

sub parse_entity {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{ -entity } ) ) {
        croak 'did not pass an entity in, "-entity"!';
    }
    if ( !exists( $args->{ -mid } ) ) {
        croak 'did not pass a mid in, "-mid"!';
    }

    my @parts = $args->{ -entity }->parts;

    if (@parts) {

        #print "we gotta parts?!\n";

        my $i;
        for $i ( 0 .. $#parts ) {
            $parts[$i] =
              $self->parse_entity( { %{$args}, -entity => $parts[$i] } );
        }

    }

    $args->{ -entity }->sync_headers(
        'Length'      => 'COMPUTE',
        'Nonstandard' => 'ERASE'
    );

    my $is_att = 0;

    if ( defined( $args->{ -entity }->head->mime_attr('content-disposition') ) )
    {
        if ( $args->{ -entity }->head->mime_attr('content-disposition') =~
            m/attachment/ )
        {
            $is_att = 1;

            #print "is attachment?\n";
        }
    }

    if (
        (
               ( $args->{ -entity }->head->mime_type eq 'text/plain' )
            || ( $args->{ -entity }->head->mime_type eq 'text/html' )
        )
        && ( $is_att != 1 )
      )
    {

        my $body    = $args->{ -entity }->bodyhandle;
        my $content = $args->{ -entity }->bodyhandle->as_string;
		   $content = safely_decode($content); 
		
        if ($content) {

            #print "Bang!\n";
            # Bang! We do the stuff here!
            $content = $self->parse_string( $args->{ -mid }, $content );
        }
        else {

            #print "no content to parse?!";
        }

        my $io = $body->open('w');
        require Encode; 
		$content = safely_encode($content);
		$io->print( $content );
        $io->close;
    }
    else {

        #print "missed the block?!\n";
    }

    $args->{ -entity }->sync_headers(
        'Length'      => 'COMPUTE',
        'Nonstandard' => 'ERASE'
    );

    return $args->{ -entity };

}

sub check_redirect_urls { 

	# Are treated as valid - this breaks this check. 
	
	my $self    = shift; 
	my ($args)  = @_; 
	if(!exists($args->{-raise_error})){ 
		$args->{-raise_error} = 0; 
	}
	if(!exists($args->{-str})){ 
		croak "you must pass a string in the, -str paramater!"; 
	}
	
	my $valid   = [];
	my $invalid = [];
	
	my $pat = $self->redirect_regex(); 
	
	while ($args->{-str} =~ m/($pat)/g) {
		my $redirect_tag = $1; 
		my $redirect_atts = $self->get_redirect_tag_atts($redirect_tag); 
		my $url = $redirect_atts->{url}; 
		if($self->can_be_redirected($url)){ 
			push(@$valid, $url); 
	
	 	}
		else { 
			push(@$invalid, $url);
		}
	}

	if($args->{-raise_error} == 1){ 
		if($invalid->[0]){ 
			my $error_msg = "The following redirect URLs do not seem like actual URLs. Redirecting will not work correctly!\n";
			   $error_msg .= '-' x 72 . "\n\n";
			foreach (@$invalid){ 
				$error_msg .= '* ' . $_ . "\n";
			}
			$error_msg .= "\n" 
			. '-' x 72
			. "\n" 
			. $args->{-str}; 
			croak $error_msg; 
		}
		else { 
			return ($valid, $invalid); 			
		}
	}
	else { 
		return ($valid, $invalid); 
	}
}



sub can_be_redirected { 
	my $self = shift; 
	my $url  = shift; 
	if(isa_url($url)){ 
		return 1; 
	}
	elsif($self->isa_mailto($url)){ 
		return 1; 
	}
	else { 
		return 0; 
	}	
}

sub isa_mailto { 
	my $self = shift; 
	my $url  = shift; 
	if($url =~ m/^mailto\:(.*?)$/){
		my ($mailto, $address) = split(':', $url); 
		if(check_for_valid_email($address) == 0){ 
			return 1; 
		} 
		else { 
			return 0; 
		}
	}
	else { 
		return 0; 
	}
}	


sub parse_string {

    my $self = shift;
    my $mid  = shift;

    croak 'no mid! ' if !defined $mid;

    my $str = shift;

    my $pat = $self->redirect_regex(); 
	
    $str =~ s/$pat/&redirect_encode($self, $mid, $1)/eg;

    #	carp "here's the string: $str";
    return $str;
}

sub _list_name_check {

    my ( $self, $n ) = @_;
    $n = $self->_trim($n);
    return 0 if !$n;
    return 0 if $self->_list_exists($n) == 0;
    $self->{name} = $n;
    return 1;
}

sub _list_exists {
    my ( $self, $n ) = @_;
    return DADA::App::Guts::check_if_list_exists( -List => $n );
}

sub _trim { 
	my ($self, $s) = @_;
	return DADA::App::Guts::strip($s);
}

sub random_key {

    my $self = shift;
    require DADA::Security::Password;
    my $checksout = 0;
    my $key       = undef;

    while ( $checksout == 0 ) {
        $key = DADA::Security::Password::generate_rand_string( 1234567890, 12 );
        if ( $self->key_exists({ -key => $key }) ) {
            # ...
        }
        else {
            $checksout = 1;
            last;
        }
    }

    return $key;

}



sub redirect_regex { 
	
	my $self = shift; 
	# <!-- redirect url="http://yahoo.com" --> 
	# [redirect url="http://yahoo.com"]
	# [redirect=yahoo.com]	
	return qr/((\<\!\-\-(\s+)redirect|\[redirect\s+|\[redirect\=)(.*?)(\]|\-\-\>))/; 

}

sub get_redirect_tag_atts { 

	my $self = shift; 
	my $redirect_tag = shift; 
	
	my $atts = {}; 

	# Old Style
	# [redirect=http://yahoo.com]	
	if($redirect_tag =~ m/\[redirect=(.*?)\]/){ 
		$atts->{url} = $1;
	}
	
	# [redirect url="http://yahoo.com"]
	# <!-- redirect url="http://yahoo.com" --> 
	
	else {
		
		# This is very simple. 
		$redirect_tag =~ s/((^\[redirect(\s*)|\<\!\-\-(\s*)redirect(\s*))|(\]$|\-\-\>$))//g;
		my $pat = qr/(\w+)\s*=\s*"([^"]*)"/;

		while ($redirect_tag=~/$pat/g ) { 
			$atts->{$1} = $2; 
		} 
	}
#	use Data::Dumper; 
#	die Data::Dumper::Dumper($atts); 
	return $atts; 
	
}




sub redirect_encode {

    my $self = shift;
    my $mid  = shift;
    croak 'no mid! '
      if !defined $mid;
    my $redirect_tag = shift;
	#die $redirect_tag; 

	# get the brackets out of the way

	
	my $atts = $self->get_redirect_tag_atts($redirect_tag); 

	my $url = $atts->{url}; 
	delete($atts->{url}); 
	
	if($self->can_be_redirected($url)){ 
				
	    my $key = $self->reuse_key( $mid, $url, $atts );
		
	    if ( !defined($key) ) {
	        $key = $self->add( $mid, $url, $atts);
	    }
	    return $DADA::Config::PROGRAM_URL . '/r/'
	      . $self->{name} . '/'
	      . $key . '/';
	}
	else { 
		carp "Given an invalid email to create a redirect from, '$url' - skipping!";
		return $url; 
	}

}

sub redirect_tagify { 
	my $self = shift; 
	my $url  = shift; 
	return '<!-- redirect url="' . $url . '" -->'; 
}









1;


=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2011 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut

