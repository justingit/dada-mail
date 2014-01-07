package DADA::Logging::Clickthrough; 


use lib qw(../../ ../../perllib);
use strict; 
use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts;
my $type;  


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


use Fcntl qw(LOCK_SH);
use Carp qw(croak carp); 

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Logging_Clickthrough};

sub _init { 
	my $self   = shift; 
	
	my ($args) = @_; 

    if($self->{-new_list} != 1){ 
    	croak('BAD List name "' . $args->{-list} . '" ' . $!) if $self->_list_name_check($args->{-list}) == 0; 
	}else{ 
		$self->{name} = $args->{-list}; 
	}	
	
    
	if(! defined($args->{-ls}) ){ 
	    
	    require DADA::MailingList::Settings; 
	    $self->{ls} = DADA::MailingList::Settings->new({-list => $self->{name}}); 
	}
	else { 
		$self->{ls} = $args->{-ls}; 
	}	
		
	return $self;

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

	if($args->{-as_ref} == 1){ 
		return { %final }; 
	}
	else { 
	    return %final;
	}
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

           	my $type = 'PlainText'; 
			
			if( $args->{ -entity }->head->mime_type eq 'text/plain' ){ 
				$type = 'PlainText'; 
			}
			elsif( $args->{ -entity }->head->mime_type eq 'text/html' ){ 
				$type = 'HTML' 
			}
	      
	
            $content = $self->parse_string( $args->{ -mid }, $content, $type );
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
		croak "you must pass a string in the, -str parameter!"; 
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
    my $str  = shift;
	my $type = shift || 'PlainText'; 

	warn '$str before: ' . $str
	 if $t; 
	
	if($self->{ls}->param('tracker_auto_parse_links') == 1){ 
		warn 'auto redirecting tags.'
			if $t;
		$str = $self->auto_redirect_tag($str, $type); 
		warn '$str after auto redirect: ' . $str
			if $t; 
	}
	else { 
		# ...
	}

    my $pat = $self->redirect_regex();
    $str =~ s/($pat)/&redirect_encode($self, $mid, $1)/ge;

	warn '$str final: ' . $str
	 if $t;
	
    return $str;
}



sub auto_redirect_tag { 
	
	my $self = shift; 
	my $s    = shift; 
	my $type = shift; 
	
	eval { 
		require URI::Find; 
		require HTML::LinkExtor;
	};
	if($@){ 
		warn "Cannot auto redirect links. Missing perl module? $@"; 
		return $s; 
	}
	
	my @a;
	if($type eq 'HTML'){ 
		$s =  $self->HTML_auto_redirect_w_link_ext($s); 		
		
		# This won't work, as it'll escape out the redirect tag. DOH!
		# $s =  $self->HTML_auto_redirect_w_HTML_TokeParser($s); 
		
	}
	else { 
		
		# Find me the URLs in this string!
		my @uris;
		my $finder = URI::Find->new(sub {
		    my($uri) = shift;
			push(@uris, $uri->as_string);
			warn '$uri: ' . $uri
			 if $t;
			return $uri; 
		});
		$finder->find(\$s);
		
		require DADA::Security::Password; 
		
		my $links = [];
		
		# Get only unique URLS: 
		my %seen;
		my @unique_uris = grep { ! $seen{$_}++ } @uris;
		# Sort by longest, to shortest: 
		@unique_uris = sort {length $b <=> length $a} @unique_uris;
		
		for my $specific_url(@unique_uris){ 
			
			# This is probably a job for Parse::RecDescent, but I'm a dumb, dumb, person
			# Whoa, let's hide any URLs that already have redirect tags around them!
			
			# A few cases we'll look for... 
			
			
			# Old School! 
			push(@$links,
					{ 
						str   => '[redirect='.$specific_url.']', 
						regex => quotemeta('[redirect='.$specific_url.']')
					},
				); 
			push(@$links,
					{ 
						str   => '<?dada redirect url="' . $specific_url . '" ?>', 
						regex => '\<\?dada(\s+)redirect(\s+)url\=(\"?)' . quotemeta($specific_url) . '(\"?)(\s+)\?\>',
					},
				); 
			
			# Annoying URI::Find Behavior: 
			# Changes the URL sometimes and adds a, "/" at the end. Whazzah?
			my $other_specific_url = $specific_url; 
			   $other_specific_url =~ s/\/$//;
			# Old School! 
			push(@$links,
					{ 
						str   => '[redirect='.$other_specific_url.']', 
						regex => quotemeta('[redirect='.$other_specific_url.']')
					},
				); 
			push(@$links,
					{ 
						str   => '<?dada redirect url="' . $other_specific_url . '" ?>', 
						regex => '\<\?dada(\s+)redirect(\s+)url\=(\"?)' . quotemeta($other_specific_url) . '(\"?)(\s+)\?\>',
					},
				);
			
		}
		
		# Switch 'em out so my regex is...somewhat simple: 
		my %out_of_the_way; 
		for my $l(@$links){ 
			my $key = '_CLICKTHROUGH_TMP_' . DADA::Security::Password::generate_rand_string('1234567890abcdefghijklmnopqestuvwxyz', 16) . '_CLICKTHROUGH_TMP_'; 
			$out_of_the_way{$key} = $l; 
			my $qm_l = $l->{regex}; 
			$s =~ s/$qm_l/$key/g; 
		}
	
		
		for my $specific_url(@unique_uris){ 
			warn '$specific_url ' . $specific_url
				if $t; 
			if(
				$specific_url =~ m/mailto\:/ && 
				$self->{ls}->param('tracker_auto_parse_mailto_links') == 0
			){
			    warn "skipping: $specific_url"
			        if $t;
			    # ... nothing.  
			}
			elsif($self->_ignore_this_url($specific_url) == 1) { 
			    warn "skipping: $specific_url"
			        if $t;
			    # ... nothing.  
			}
			else { 
				my $qm_link    = quotemeta($specific_url); 
				my $redirected = $self->redirect_tagify($specific_url);
				warn '$redirected ' . $redirected
					if $t;
				# (somewhat simple regex) 
				$s =~ s/([^redirect\=\"])($qm_link)/$1$redirected/g;
			}
		}
		
		# Now, put 'em back!
		for (keys %out_of_the_way){ 
			my $str = $out_of_the_way{$_}->{str}; 
			$s =~ s/$_/$str/g; 
		}
		return $s; 
	}
}




sub _ignore_this_url { 
    my $self = shift; 
    my $url  = shift; 
    
#	warn '_ignore_this_url:' . $url; 
   if($url =~ m/$DADA::Config::PROGRAM_URL\/t\/([a-zA-Z0-9_]*?)/){ 
        # We don't wanna redirect a token link. Too much! 
        return 1; 
    }
    else { 
        return 0; 
    }
}



# sub HTML_auto_redirect_w_HTML_TokeParser { 
# 	
# #	print 'HTML_auto_redirect_w_HTML_TokeParser'; 
# 	
# 	my $self = shift; 
# 	my $s    = shift;
# 	
# 	require HTML::TokeParser::Simple;
# 
# 	my $parser = HTML::TokeParser::Simple->new(\$s);
# 	my $html; 
# 	
# 	while ( my $token = $parser->get_token ) {
# 	    if ($token->is_start_tag('a')) {
# 	        my $link = $token->get_attr('href');
# 	        if (defined $link) {
# 				warn '$link: ' . $link
# 				 if $t; 
# 
# 				# Skip links that are already tagged up!
# 				if($link =~ m/(^(\<\!\-\-|\[|\<\?))|((\]|\-\-\>|\?\>)$)/){ 
# 					warn '$link looks to contain tags? skipping.'
# 					 if $t; 
# 					 $html .= $token->as_is;	
# 				}
# 				else { 
# 					# ... 
# 				}
# 
# 				my $redirected_link = $self->redirect_tagify($link); 
# 				warn '$redirected_link: ' . $redirected_link
# 				 if $t; 
# 
# 				my $qm_link         = quotemeta($link);
# 				warn '$link: "' . $link . '"'
# 					if $t; 
# 				warn '$qm_link: "' . $qm_link . '"'
# 					if $t; 
# 
# 				warn '$redirected_link: "' . $redirected_link . '"' 
# 					if $t;
# 				$token->set_attr('href', $redirected_link);
# 				$html .= $token->as_is;
# 	        }
# 	    }
# 		else { 
# 	    	$html .= $token->as_is;	
# 		}
# 	}
# 	
# #	die '$html :' . $html; 
# 	
# 	return $html; 
# 	
# 	
# 		
# }
#

sub HTML_auto_redirect_w_link_ext { 
	
	my $self = shift; 
	my $s    = shift; 	
	my $og      = $s; 
	my @links_to_look_at = (); 
	my $callback = sub {
	     my($tag, %attr) = @_;     
		# Supported: <a href=""> and <aread href=""> 
		return 
			unless $tag eq 'a' || $tag eq 'area'; 
			
		 my $link =  $attr{href}; 
		
		if($link =~ m/^mailto\:/ && $self->{ls}->param('tracker_auto_parse_mailto_links') == 0) { 
			warn "Skipping mailto: link, as settings dictate."
				if $t;
		}
		elsif($link =~ m/(^(\<\!\-\-|\[|\<\?))|((\]|\-\-\>|\?\>)$)/){ 
			warn '$link looks to contain tags? skipping.'
			 if $t; 
		}
		elsif($self->_ignore_this_url($link) == 1) { 
		    warn "skipping: $link"
		        if $t;
		    # ... nothing.  
		}
		else { 
			warn 'pushing: ' . $link if $t; 
			push(@links_to_look_at, $link);	
		}
		
		if($link =~ m/\&/){ 
			# There's some weird stuff happening in HTML::LinkExtor, 
			# Which will change, "&amps;" back to, "&", probably due to 
			# A well-reasoned... reason. But it still breaks shit. 
			# So I look for both: 

			my $ampersand_link = $link; 
			   $ampersand_link =~ s/\&/\&amp;/g;
			push(@links_to_look_at, $ampersand_link); 

		}
	};

    my $p = HTML::LinkExtor->new( $callback );
       $p->parse($s);
	undef $p; 

	if($t) { 
		require Data::Dumper; 
		warn 'Links Found:' . Data::Dumper::Dumper([@links_to_look_at]); 
	}
	
	foreach my $single_link(@links_to_look_at){ 
		my $redirected_link = $self->redirect_tagify($single_link); 
		warn '$redirected_link: ' . $redirected_link
		 if $t; 
	
		my $qm_link         = quotemeta($single_link);
		warn '$single_link: "' . $single_link . '"'
			if $t; 
		warn '$qm_link: "' . $qm_link . '"'
			if $t; 
		
		# This line is suspect - it only works with double quotes, ONLY looks at the first (?) 
		# double quote and doesn't use any sort of API from HTML::LinkExtor. 
		# 
		# Also see that we don't get rid of dupes in @links_to_look_at, and this regex is not global. 
		# If you do one do the other, 
		$og =~ s/(href(\s*)\=(\s*)(\"?|\'?))$qm_link/$1$redirected_link/;
		
	}

    $s  = $og;

	@links_to_look_at = (); 
	$og = undef; 
	
	return $s; 
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
#	return qr/(((\<\!\-\-|\<\?dada)(\s+)redirect|\[redirect\s+|\[redirect\=)(.*?)(\]|\-\-\>|\?\>))/; 
	return qr/
		(
			\<\!\-\-(\s+)redirect(\s+)url\=(.*?)(\s+)\-\-\> 
			|
			\[redirect(\s+)url\=(.*?)\]
			|
			\[redirect\=(.*?)\]
			|
			\<\?dada(\s+)redirect(\s+)url\=(.*?)(\s+)\?\> 
		)
	/x; 
}

sub get_redirect_tag_atts { 

	my $self = shift; 
	my $redirect_tag = shift; 
	
	my $atts = {}; 

	# Old Style
	# [redirect=http://yahoo.com]	
	if($redirect_tag =~ m/\[redirect\=(.*?)\]/){ 
		$atts->{url} = $1;
	}
	
	# [redirect url="http://yahoo.com"]
	# <!-- redirect url="http://yahoo.com" --> 
	
	else {
		
		# This is very simple. 
		$redirect_tag =~ s/
		(
			(
				^\[redirect(\s*)
				|
				\<\!\-\-(\s*)redirect(\s*)
				|
				^\<dada\?(\s*)redirect(\s*)
			)
			|
			(
				\]$
				|
				\-\-\>$
				|
				\?\>$
			)
		)
		//xg;
		
		my $pat = qr/(\w+)\s*=\s*"([^"]*)"/;

		while ($redirect_tag=~/$pat/g ) { 
			$atts->{$1} = $2; 
		} 
	}
	
	if($t){ 
		warn 'found tag atts:'; 
		require Data::Dumper; 
		warn Data::Dumper::Dumper($atts); 
	}
	return $atts; 
	
}




sub redirect_encode {

    my $self = shift;
    my $mid  = shift;
    croak 'no mid! '
      if !defined $mid;
    my $redirect_tag = shift;
	warn '$redirect_tag: ' . $redirect_tag
		if $t; 
		
	# get the brackets out of the way

	
	my $atts = $self->get_redirect_tag_atts($redirect_tag); 

	my $url = $atts->{url}; 
	delete($atts->{url}); 
		
	warn '$url: ' . $url
		if $t; 
	
	if($self->can_be_redirected($url)){ 
		warn 'can_be_redirected returned true.'
			if $t; 
			
	    my $key = $self->reuse_key( $mid, $url, $atts );
		
	    if ( !defined($key) ) {
	        $key = $self->add( $mid, $url, $atts);
	    }
	    my $redirect_url =  
			$DADA::Config::PROGRAM_URL . '/r/'
	      . $self->{name} 
		  . '/'
	      . $key 
	      . '/';
	
		if($self->{ls}->param('tracker_track_email') == 1) { 
			$redirect_url .= '<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/'; 
		}

		warn '$redirect_url: ' . $redirect_url
			if $t; 
		
		return $redirect_url; 
		
	}
	else { 
		carp "Given an invalid email to create a redirect from, '$url' - skipping!";
		return $url; 
	}

}




sub redirect_tagify { 
	my $self = shift; 
	my $url  = shift; 
	   $url  =~ s/\n|\r//g;
	return '<?dada redirect url="' . $url . '" ?>'; 
}




sub message_history_json {
	
	# warn 'message_history_json'; 
	
	my $self = shift; 
	my ($args) = @_; 
	
	my $page; 
	if(!exists($args->{-page})){ 
		$page = 1; 
	}
	else { 
		$page = $args->{-page};
	}
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0;
	}
	my $cached_data = undef; 
	if(exists($args->{-report_by_message_index_data})) { 
		# warn 'getting $cached_data from $args->{-report_by_message_index_data}';
		$cached_data = $args->{-report_by_message_index_data};
	}
	else { 
		# warn 'no $cached_data passed.';
	}
	
	
	
	
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 
	
	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_history_json', 
			-page    => $page, 
			-entries => $self->{ls}->param('tracker_record_view_count'), 
		}
	);
	
	#if( defined($json)){ 
	#	# warn 'But! json data cached in file.'; 
	#}
	
	if(! defined($json)){ 
		my $total; 
		my $msg_ids; 
		
		# We can pass the data we make in $report_by_message_index
		# and save us this step. 
		my $report_by_message_index; 
		if(!$cached_data) { 
			($total, $msg_ids) = $self->get_all_mids(
				{ 
					-page    => $page, 
					-entries => $self->{ls}->param('tracker_record_view_count'),  
				}
			);
		 	$report_by_message_index = $self->report_by_message_index({-all_mids => $msg_ids}) || [];		
		}
		else { 
			$report_by_message_index = $cached_data;
		}
		#######
		
		my $num_subscribers = []; 
		my $opens           = [];
		my $clickthroughs   = [];
		my $soft_bounces    = [];
		my $hard_bounces    = [];
		my $first_date      = undef;
		my $last_date       = undef; 

		require         Data::Google::Visualization::DataTable;
		my $datatable = Data::Google::Visualization::DataTable->new();

		$datatable->add_columns(
			   { id => 'date',          label => 'Date',          type => 'string'}, 
		       { id => 'subscribers',   label => "Subscribers",   type => 'number'},
		       { id => 'opens',         label => "Opens",         type => 'number'},
		       { id => 'clickthroughs', label => "Clickthroughs", type => 'number'},
		       { id => 'unsubscribes',  label => "Unsubscribes",  type => 'number'},
		       { id => 'soft_bounces',  label => "Soft Bounces",  type => 'number'},
		       { id => 'hard_bounces',  label => "Hard Bounces",  type => 'number'},
		);
	
	
		for(reverse @$report_by_message_index){ 
			if($self->verified_mid($_->{mid})){
			
				if($self->{ls}->param('tracker_clean_up_reports') == 1){ 
					next unless exists($_->{num_subscribers}) && $_->{num_subscribers} =~ m/^\d+$/
				}
		
				my $date; 
				my $num_subscribers = $_->{num_subscribers}; 
				my $opens           = 0;
				my $clickthroughs   = 0;
				my $unsubscribes    = 0;
				my $soft_bounces    = 0;
				my $hard_bounces    = 0;  
			
				if(defined($_->{open})){ 
					$opens = $_->{open};	
				}
				if(defined($_->{count})){ 
					$clickthroughs = $_->{count};	
				}
				
				if(defined($_->{unsubscribe})){ 
					$unsubscribes = $_->{unsubscribe};	
				}
				
				if(defined($_->{soft_bounce})){ 
					$soft_bounces = $_->{soft_bounce};	
				}
				if(defined($_->{hard_bounce})){ 
					$hard_bounces = $_->{hard_bounce};	
				}
			
				$datatable->add_rows(
					{
				        date          =>  { 
											v => $_->{mid}, 
											f => DADA::App::Guts::date_this( -Packed_Date => $_->{mid}) 
											},
		                subscribers   => $num_subscribers ,
		                opens         => $opens ,
		                clickthroughs => $clickthroughs,
		                unsubscribes  => $unsubscribes,
		                soft_bounces  => $soft_bounces, 
		                hard_bounces  => $hard_bounces ,
					}
				); 				
			}
		} 


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_history_json', 
				-page    => $page, 
				-entries => $self->{ls}->param('tracker_record_view_count'), 
				-data    => \$json, 
			}
		);
	
	}

	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(
			'-Cache-Control' => 'no-cache, must-revalidate',
			-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
			-type            =>  'application/json',
		);
		print $json; 
	}
	else { 
		return $json; 
	}
}


1;


=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

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

