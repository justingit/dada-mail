package DADA::Logging::Clickthrough; 


use lib qw(../../ ../../perllib

./
./DADA/perllib

);
use strict; 

use Try::Tiny; 
use Fcntl qw(LOCK_SH);
use Carp qw(croak carp); 

use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts;

use JSON; 
my $json_object = JSON->new->allow_nonref;
my $t = $DADA::Config::DEBUG_TRACE->{DADA_Logging_Clickthrough};

sub new {

    my $class  = shift;
    my ($args) = @_;
    my $self   = {};
    bless $self, $class;
    $self->_init($args);
    $self->_sql_init($args);
    return $self;
}
#sub enabled { 
#	my $self = shift; 
#	return 1; 
#}



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

	require DADA::MailingList::Archives; 
	$self->{ah} = DADA::MailingList::Archives->new({-list => $self->{name}}); 

		
	return $self;

}


sub _sql_init {

    my $self = shift;
    require DADA::App::DBIHandle;
    my $dbi_obj = DADA::App::DBIHandle->new;
    $self->{dbh} = $dbi_obj->dbh_obj;
	
	$self->{sql_params} = {%DADA::Config::SQL_PARAMS};

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
	my $need_to_return = 0; 
	try { 
		require URI::Find; 
		require HTML::LinkExtor;
	} catch { 
		warn "Cannot auto redirect links. Missing perl module? $_"; 
		$need_to_return = 1; 
	};
	if($need_to_return == 1){ 
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
	
		if(
			   $DADA::Config::PII_OPTIONS->{allow_logging_emails_in_analytics} == 1
			&& $self->{ls}->param('tracker_track_email') == 1
		) { 
			$redirect_url .= '<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/'; 
		}
		elsif($self->{ls}->param('tracker_track_anonymously') == 1){ 
			$redirect_url .= '<!-- tmpl_var hashed_uid -->/'; 
		}

		warn '$redirect_url: ' . $redirect_url
			if $t; 
		
		return $redirect_url; 
		
	}
	else { 
		carp "Given an invalid email to create a redirect from, '$url' - skipping!"
			if $t; 
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
    if ( !exists( $args->{-page} ) ) {
        $page = 1;
    }
    else {
        $page = $args->{-page};
    }
    if ( !exists( $args->{-printout} ) ) {
        $args->{-printout} = 0;
    }
    my $cached_data = undef;
    if ( exists( $args->{-report_by_message_index_data} ) ) {

      # warn 'getting $cached_data from $args->{-report_by_message_index_data}';
        $cached_data = $args->{-report_by_message_index_data};
    }
    else {
        # warn 'no $cached_data passed.';
    }

    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'number';
    }

    my $json;

    require DADA::App::DataCache;
    my $dc = DADA::App::DataCache->new;

    $json = $dc->retrieve(
        {
            -list    => $self->{name},
            -name    => 'message_history_json.' . $args->{-type},
            -page    => $page,
            -entries => $self->{ls}->param('tracker_record_view_count'),
        }
    );

    #if( defined($json)){
    #	# warn 'But! json data cached in file.';
    #}

    if ( !defined($json) ) {
        my $total;
        my $msg_ids;

        # We can pass the data we make in $report_by_message_index
        # and save us this step.
        my $report_by_message_index;
        if ( !$cached_data ) {
            ( $total, $msg_ids ) = $self->get_all_mids(
                {
                    -page    => $page,
                    -entries => $self->{ls}->param('tracker_record_view_count'),
                }
            );
            $report_by_message_index =
              $self->report_by_message_index( { -all_mids => $msg_ids } ) || [];
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

		require JSON; 
		my $json_object = JSON->new->allow_nonref;

        require Data::Google::Visualization::DataTable;
        my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );

        if ( $args->{-type} eq 'number' ) {

            $datatable->add_columns(
                { id => 'date', label => 'Date', type => 'string' },
                {
                    id    => 'delivered_to',
                    label => "Recipients",
                    type  => 'number'
                },

    #{ id => 'received',         label => "Received",         type => 'number'},
                { id => 'opens', label => "Opens", type => 'number' },
                {
                    id    => 'clickthroughs',
                    label => "Clickthroughs",
                    type  => 'number'
                },

       #   { id => 'soft_bounces',  label => "Soft Bounces",  type => 'number'},
       #   { id => 'hard_bounces',  label => "Hard Bounces",  type => 'number'},
       #  { id => 'bounces',  label => "Bounces",  type => 'number'},
       #  { id => 'errors_sending_to', label => "Errors", type => 'number'},

                {
                    id    => 'delivery_issues',
                    label => "Delivery Issues",
                    type  => 'number'
                },
                {
                    id    => 'unsubscriptions',
                    label => "Unsubscriptions",
                    type  => 'number'
                },

            );

           
            for ( reverse @$report_by_message_index ) {
                if ( $self->verified_mid( $_->{mid} ) ) {

                    if ( $self->{ls}->param('tracker_clean_up_reports') == 1 ) {
                        next
                          unless exists( $_->{num_subscribers} )
                          && $_->{num_subscribers} =~ m/^\d+$/;
                    }

                    my $date;
                    my $delivered_to =
                      $_->{delivered_to};    # and that's that I guess.
                    my $opens = 0;

                    #my $errors          = 0;
                    my $clickthroughs = 0;

                    #my $soft_bounces    = 0;
                    #my $hard_bounces    = 0;
                    #my $bounces = 0;
                    my $delivery_issues = 0;
                    my $unsubscriptions    = 0;

                    if ( defined( $_->{open} ) ) {

                        #if($_->{unique_open} > 2){ # set to "2" to fudge
                        $opens = $_->{unique_open};

                        #}
                        #else {
                        #	$opens = $_->{open};
                        #}
                    }

                    #if(defined($_->{errors_sending_to})){
                    #	$errors = $_->{errors_sending_to};
                    #}

                    if ( defined( $_->{count} ) ) {

                      #if($_->{unique_clickthroughs} > 2){ # set to "2" to fudge
                        $clickthroughs = $_->{unique_clickthroughs};

                        #}
                        #else {
                        #	$clickthroughs = $_->{count};
                        #}
                    }

                    #if(defined($_->{soft_bounce})){
                    #	$soft_bounces = $_->{soft_bounce};
                    #}
                    #if(defined($_->{hard_bounce})){
                    #	$hard_bounces = $_->{hard_bounce};
                    #}

                    if ( defined( $_->{unsubscribe} ) ) {
                        $unsubscriptions = $_->{unsubscribe};
                    }
                    if ( defined( $_->{delivery_issues} ) ) {
                        $delivery_issues = $_->{delivery_issues};
                    }

					if(!defined($_->{message_subject_snipped})){ 
						$_->{message_subject_snipped} = '(subject not saved)';
					}
                    $datatable->add_rows(
                        {
                            date => {
                                v => $_->{mid},
                                f => $_->{message_subject_snipped},
                            },

                            delivered_to  => $delivered_to,
                            opens         => $opens,
                            clickthroughs => $clickthroughs,

                            #soft_bounces      => $soft_bounces,
                            #hard_bounces      => $hard_bounces,
                            #bounces            => $bounces,
                            #errors_sending_to => $errors,
                            delivery_issues => $delivery_issues,
                            unsubscriptions    => $unsubscriptions,
                        }
                    );
                }
            }

        }
        elsif ( $args->{-type} eq 'rate' ) {

            $datatable->add_columns(
                { id => 'date', label => 'Date', type => 'string' },

         # { id => 'subscribers',   label => "Subscribers",   type => 'number'},
                { id => 'received', label => "% Receive", type => 'number' },

#                   { id => 'errors_sending_to', label => "Errors", type => 'number'},
                { id => 'opens', label => "% Opened", type => 'number' },
                {
                    id    => 'clickthroughs',
                    label => "% Clickthrough",
                    type  => 'number'
                },

                {
                    id    => 'delivery_issues',
                    label => "% Delivery Issue",
                    type  => 'number'
                },

                {
                    id    => 'unsubscriptions',
                    label => "% Unsubscriptions",
                    type  => 'number'
                },

       #   { id => 'soft_bounces',  label => "Soft Bounces",  type => 'number'},
       #   { id => 'hard_bounces',  label => "Hard Bounces",  type => 'number'},
       #			   { id => 'bounces',  label => "Bounces",  type => 'number'},

            );

            for ( reverse @$report_by_message_index ) {
                if ( $self->verified_mid( $_->{mid} ) ) {

                    if ( $self->{ls}->param('tracker_clean_up_reports') == 1 ) {
                        next
                          unless exists( $_->{num_subscribers} )
                          && $_->{num_subscribers} =~ m/^\d+$/;
                    }

					if(!defined($_->{message_subject_snipped})){ 
						$_->{message_subject_snipped} = '(subject not saved)';
					}
					
                    $datatable->add_rows(
                        {
                            date => {
                                v => $_->{mid},
                                f => $_->{message_subject_snipped},

                            },
                            received        => $_->{received_percent},
                            opens           => $_->{unique_opens_percent},
                            clickthroughs   => $_->{unique_clickthroughs_percent},
                            delivery_issues => $_->{delivery_issues_percent},
                            unsubscriptions => $_->{unique_unsubscribes_percent},

                            #  subscribers   => $num_subscribers ,

#soft_bounces  => $_->{unique_soft_bounces_percent},
#hard_bounces  => $_->{unique_hard_bounces_percent},
#bounces        => ($_->{unique_soft_bounces_percent} + $_->{unique_hard_bounces_percent})

                        }
                    );

                }
            }

        }

        $json = $datatable->output_javascript( pretty => 1, );
        $dc->cache(
            {
                -list    => $self->{name},
                -name    => 'message_history_json.' . $args->{-type},
                -page    => $page,
                -entries => $self->{ls}->param('tracker_record_view_count'),
                -data    => \$json,
            }
        );

    }
    my $headers = {
        '-Cache-Control' => 'no-cache, must-revalidate',
        -expires         => 'Mon, 26 Jul 1997 05:00:00 GMT',
        -type            => 'application/json',

    };

    if ( $args->{-printout} == 1 ) {
        require CGI;
        my $q = CGI->new;
        print $q->header(%$headers);
        print $json;
    }
    else {
        return ( $headers, $json );
    }
}



sub percentage { 
	my $self = shift; 
	my $num  = shift; 
	my $total = shift; 
	my $p     = 0; 

	$num = $num + 0; 
	$total = $total + 0; 
	
	return 0 unless $total > 0; 
	try { 
		$p =  $num/$total * 100; 
	} catch { 
		carp "problems finding percentage: $_"; 
	};

	return sprintf ("%.1f", $p); 
	
	#return $p; 
}


sub custom_fields {
    my $self = shift;
    my $cols = $self->_columns;

    my %omit_fields = (
        url_id      => 1,
        redirect_id => 1,
        msg_id      => 1,
        url         => 1,
    );

    my $custom = [];
    for (@$cols) {
        if ( !exists( $omit_fields{$_} ) ) {
            push( @$custom, $_ );
        }
    }
    return $custom;
}

sub _columns {

    my $self = shift;
    my @cols;

    if ( exists( $self->{cache}->{columns} ) ) {
        return $self->{cache}->{columns};
    }
    else {
        my $query =
            "SELECT * FROM "
          . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
          . " WHERE (1 = 0)";
        warn 'Query: ' . $query
          if $t;

        my $sth = $self->{dbh}->prepare($query);

        $sth->execute()
          or croak "cannot do statement (at: columns)! " . $self->{dbh}->errstr;
        my $i;
        for ( $i = 1 ; $i <= $sth->{NUM_OF_FIELDS} ; $i++ ) {
            push( @cols, $sth->{NAME}->[ $i - 1 ] );
        }
        $sth->finish;
        $self->{cache}->{columns} = \@cols;
    }
    return \@cols;
}

sub add {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url    = shift;
    my $fields = shift;

    my $key = $self->random_key();

    my $sql_str             = '';
    my $place_holder_string = '';
    my @order               = @{ $self->custom_fields };
    my @values;
    if ( $order[0] ) {
        for my $field (@order) {
            $sql_str .= ',' . $field;
            $place_holder_string .= ',?';
            push( @values, $fields->{$field} );
        }
    }
    $sql_str =~ s/,$//;

    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . '(redirect_id, msg_id, url'
      . $sql_str
      . ') values(?,?,?'
      . $place_holder_string . ')';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $key, $mid, $url, @values )
      or croak "cannot do statement! (at: add) " . $self->{dbh}->errstr;
    return $key;

}

sub reuse_key {

    my $self = shift;
    my $mid  = shift;
    die 'no mid! ' if !defined $mid;
    my $url    = shift;
    my $fields = shift;

    my $custom_fields = $self->custom_fields;
    my %cust_fields   = ();
    foreach (@$custom_fields) {
        $cust_fields{$_} = 1;
    }
    my $place_holder_string = '';
    my @values              = ();

    foreach my $field ( keys %$fields ) {
        if ( exists( $cust_fields{$field} ) ) {
            push( @values, $fields->{$field} );
            $place_holder_string .= ' AND ' . $field . ' = ?';
        }
    }
    my $query =
        'SELECT * FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE msg_id = ? AND url = ? '
      . $place_holder_string;

    warn 'QUERY: ' . $query
 		if $t;
    my $sth = $self->{dbh}->prepare($query);
    $sth->execute( $mid, $url, @values )
      or croak "cannot do statement! (at: reuse_key) " . $self->{dbh}->errstr;
    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        return $hashref->{redirect_id};
    }

    return undef;

}

sub fetch {

    my $self = shift;
    my $key  = shift;
    die "no key! " if !defined $key;

    my $sql_snippet = '';
    my $fields      = $self->custom_fields;
    foreach (@$fields) {
        $sql_snippet .= ', ' . $_;
    }

    my $query =
        'SELECT msg_id, url'
      . $sql_snippet
      . ' FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE  redirect_id = ?';
    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($key)
      or croak "cannot do statement! (at: fetch) " . $self->{dbh}->errstr;
    my $hashref;
  FETCH: while ( $hashref = $sth->fetchrow_hashref ) {
        $sth->finish;
        my $msg_id = $hashref->{msg_id};
        my $url    = $hashref->{url};
        delete( $hashref->{msg_id} );
        delete( $hashref->{url} );
        return ( $msg_id, $url, $hashref );
    }

    return ( undef, undef, {} );
}

sub key_exists {

    my $self = shift;
    my ($args) = @_;

    my $query =
        'SELECT COUNT(*) FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_urls_table}
      . ' WHERE redirect_id = ? ';

    warn 'QUERY: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $args->{-key} )
      or croak "cannot do statement (at key_exists)! " . $self->{dbh}->errstr;
    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];

}

sub r_log {

    my $self      = shift;
    my ($args)    = @_;

    my $timestamp = undef;
    if ( exists( $args->{-timestamp} ) ) {
        $timestamp = $args->{-timestamp};
    }
    my $atts = {};
    if ( exists( $args->{-atts} ) ) {
        $atts = $args->{-atts};
    }

    my $remote_address = undef;
    if ( !exists( $args->{-remote_addr} ) ) {
        $remote_address = $self->remote_addr;
        $args->{-remote_addr} = $remote_address;
    }
    else {
        $remote_address = ip_address_logging_filter($args->{-remote_addr});
    }

    if ( !exists( $args->{-email} ) ) {
        $args->{-email} = '';
    }
	else { 
		$args->{-email} = cased($args->{-email});
	}

    if(!exists($args->{-update_fields} )) { 
        $args->{-update_fields}; 
    }
    
    if(!exists($args->{-ua})){ 
        $args->{-ua} = $ENV{HTTP_USER_AGENT},
    }
#    warn q{$args->{-ua}} . $args->{-ua}; 
    
    my $recorded_open_recently = 1;
    try {
        $recorded_open_recently = $self->_recorded_open_recently($args);
    }
    catch {
        carp "Couldn't execute, '_recorded_open_recently', : $_";
    };
    if ( $recorded_open_recently <= 0 ) {
        $self->open_log(
            {
                %$args, 
                # -ua => $args->{-ua} . ' *'
            }
        );
    }

    my $place_holder_string = '';
    my $sql_snippet         = '';

    my @values    = ();
    my $fields    = $self->custom_fields;
    my $lt_fields = {};
    foreach (@$fields) {
        $lt_fields->{$_} = 1;
    }

    foreach ( keys %$atts ) {
        if ( exists( $lt_fields->{$_} ) ) {
            push( @values, $atts->{$_} );
            $place_holder_string .= ' ,?';
            $sql_snippet .= ' ,' . $_;
        }
    }
    my $ts_snippet = '';
    if ( defined($timestamp) ) {
        $ts_snippet = 'timestamp,';
        $place_holder_string .= ' ,?';
    }
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}
      . '(list,'
      . $ts_snippet
      . 'remote_addr, msg_id, url, email, user_agent'
      . $sql_snippet
      . ') VALUES (?, ?, ?, ?, ?, ?'
      . $place_holder_string . ')';

    my $sth = $self->{dbh}->prepare($query);
    if ( defined($timestamp) ) {
        $sth->execute( 
            $self->{name}, 
            $timestamp, 
            $remote_address,
            $args->{-mid}, 
            $args->{-url}, 
            $args->{-email},
            $args->{-ua}, 
            @values
        );
    }
    else {
        $sth->execute(
            $self->{name}, 
            $remote_address, 
            $args->{-mid},
            $args->{-url}, 
            $args->{-email},
            $args->{-ua}, 
            @values
        );
    }
    $sth->finish;
    
    if(
		   $DADA::Config::PII_OPTIONS->{allow_logging_emails_in_analytics} == 1
		&& $self->{ls}->param('tracker_track_email') == 1 
   	    && $self->{ls}->param('tracker_update_profiles_w_geo_ip_data') == 1
        && $args->{-email} ne ''
	) { 
        try { 
            warn '$args->{-email}' . $args->{-email} 
                if $t; 
            warn '$remote_address'  . $remote_address 
                if $t; 
            $self->_update_profile_fields(
                {
                    -email      => $args->{-email},
				   -ip_address => ip_address_logging_filter($remote_address),
				   
				   
				   
                }
            ); 
        } catch { 
            carp "problems updating fields with geo ip data: $_"; 
        };
    }
    return 1;
}



sub _update_profile_fields {
    
    warn '_update_profile_fields' 
        if $t; 
        
    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-email} ) ) {
        warn 'need to pass an -email!';
        return undef;
    } 
    else { 
		$args->{-email} = cased(
			$args->{-email}
		);
        if ( DADA::App::Guts::check_for_valid_email($args->{-email}) == 0 ) {
    
        }
        else { 
            warn 'invalid email: ' . $args->{-email}; 
            return undef; 
        }
    }
    if (! exists( $args->{-ip_address} ) ) {
        warn 'need to pass an -ip_address!';
        return undef;
    }

    my $geoip_db        = undef;
    my @loc_of_geoip_db = (
        '../../../../data/GeoLiteCity.dat', '../../../data/GeoLiteCity.dat',
        '../../data/GeoLiteCity.dat',       '../data/GeoLiteCity.dat',
        './data/GeoLiteCity.dat',
    );

    for (@loc_of_geoip_db) {
        if ( -e $_ ) {
            $geoip_db = $_;
            last;
        }
    }
    if ( !defined($geoip_db) ) {
        croak "Can not find GEO IP DN! at any of these locations: " . join( ', ', @loc_of_geoip_db );
    }
    else { 
        warn '$geoip_db at: ' . $geoip_db
            if $t;
    }

    my $thawed_gip = $self->{ls}->_dd_thaw( $self->{ls}->param('tracker_update_profile_fields_ip_dada_meta') );
    #warn '$thawed_gip:' . $thawed_gip; 
    
	
	# <a href="https://www.miyuru.lk/geoiplegacy">Geolocation database of [provider] converted by Miyuru Sankalpa</a> 
    require Geo::IP::PurePerl;
    my $gi = Geo::IP::PurePerl->new($geoip_db);
    my (
        $country_code, $country_code3, $country_name, $region,     $city,
        $postal_code,  $latitude,      $longitude,    $metro_code, $area_code
    ) = $gi->get_city_record( $args->{-ip_address} );

	my $uts = time; 
    my $named_vals = {
        ip_address      => $args->{-ip_address},
        country_code    => $country_code,
        country_code3   => $country_code3,
        country_name    => $country_name,
        region          => $region,
        city            => $city,
        postal_code     => $postal_code,
        latitude        => $latitude,
        longitude       => $longitude,
        metro_code      => $metro_code,
        area_code       => $area_code,
		unix_time_stamp => $uts, 
    };

    require DADA::ProfileFieldsManager;
    my $dpfm = DADA::ProfileFieldsManager->new;

    require DADA::Profile;
    my $prof = DADA::Profile->new( { -email => $args->{-email} } );
    if ($prof) {
        if ( !$prof->exists ) {
            warn 'no $prof.'
                if $t; 
            # create a new one.
            $prof->insert(
                {
                    -password  => $prof->_rand_str(8),
                    -activated => 1,
                }
            );
        }
        else { 
            warn '$prof exists.'
                if $t; 
        }
        # done with $prof.
        undef($prof);

        my $new_vals = {};
        my $old_vals = {};

        require DADA::Profile::Fields;
        my $dpf = DADA::Profile::Fields->new( { -email => $args->{-email} } );
        if ( $dpf->exists( { -email => $args->{-email} } ) ) {
            $old_vals = $dpf->get;
            delete( $old_vals->{email} );
            delete( $old_vals->{email_name} );
            delete( $old_vals->{email_domain} );
        }
        for my $uf ( @{ $dpfm->fields( { -show_hidden_fields => 1 } ) } ) {
            if ( $thawed_gip->{$uf}->{enabled} == 1 ) {
                $new_vals->{$uf} = $named_vals->{ $thawed_gip->{$uf}->{geoip_data_type} };
            }
            else {
                if(defined($old_vals->{$uf})) { 
                    $new_vals->{$uf} = $old_vals->{$uf};
                }
                else {
                    $new_vals->{$uf} = ''; 
                }
            }
        }
        if($t){ 
            require Data::Dumper; 
            warn 'inserting: ' . Data::Dumper::Dumper($new_vals); 
        }
        $dpf->insert( { -fields => $new_vals, } );
    }
    return 1;

}


sub logged_subscriber_count {
    my $self = shift;
    my ($args) = @_;
    my $query =
        'SELECT COUNT(*) from '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . ' WHERE list = ? AND msg_id = ? AND event = ?';

    warn 'Query: ' . $query
      if $t;

    my $sth = $self->{dbh}->prepare($query);
       $sth->execute( $self->{name}, $args->{-mid}, 'num_subscribers')
      	or carp "cannot do statement! " . $self->{dbh}->errstr;

    my $count = $sth->fetchrow_array;

    $sth->finish;

    warn '$count is ' . $count
      if $t;

    if ( $count eq undef ) {
        return 0;
    }
    else {
        return $count;
    }
}

sub open_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; # Well, yeah
    $args->{-event}          = 'open'; 
    $args->{-update_fields}  = 1; 
    return $self->mass_mailing_event_log($args); 
}
sub num_subscribers_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'num_subscribers'; 
    $args->{-details}        = $args->{-num};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub sent_analytics_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'sent_analytics'; 
    $args->{-details}        = 0;
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}

sub total_recipients_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'total_recipients'; 
    $args->{-details}        = $args->{-num};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub start_time_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'start_time'; 
    $args->{-details}        = $args->{-details};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub finish_time_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'finish_time'; 
    $args->{-details}        = $args->{-details};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub msg_size_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'msg_size'; 
    $args->{-details}        = $args->{-msg_size};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub sending_method_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'sending_method'; 
    $args->{-details}        = $args->{-details};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub subject_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'original_subject'; 
    $args->{-details}        = $args->{-subject};
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}

sub forward_to_a_friend_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'forward_to_a_friend'; 
    $args->{-update_fields}  = 0; # I guess we could...  
    return $self->mass_mailing_event_log($args); 
}
sub view_archive_log {
    my $self                 = shift;
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-update_fields}  = 0;
    $args->{-event}          = 'view_archive'; 
    return $self->mass_mailing_event_log($args); 
}
sub bounce_log {
    my $self                 = shift;
    my ($args)               = @_;
    my $bounce_type          = '';
    if ( $args->{-type} eq 'hard' ) {
        $bounce_type = 'hard_bounce';
    }
    else {
        $bounce_type = 'soft_bounce';
    }
    $args->{-record_as_open} = 0; 
    $args->{-event}          = $bounce_type; 
    $args->{-details}        = $args->{-email}; # I know, it's weird. 
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub error_sending_to_log {
    my $self                 = shift; 
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'errors_sending_to'; 
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub unsubscribe_log { 
	my $self                 = shift; 
    my ($args)               = @_;
    $args->{-record_as_open} = 1; 
    $args->{-event}          = 'unsubscribe'; 
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}
sub abuse_log { 
	my $self                 = shift; 
    my ($args)               = @_;
    $args->{-record_as_open} = 0; 
    $args->{-event}          = 'abuse_report';
    $args->{-update_fields}  = 0; 
    return $self->mass_mailing_event_log($args); 
}




sub mass_mailing_event_log {
    my $self      = shift;
    my ($args)    = @_;
    

    if ( $t == 1 ) {
        warn 'sent over Vars:';
        require Data::Dumper;
		warn '$args:' . Data::Dumper::Dumper($args);
	}
	
    # timestamp
    my $timestamp = undef;
    if ( exists( $args->{-timestamp} ) ) {
        $timestamp = $args->{-timestamp};
    }
    
    # remote address
    my $remote_address = undef;
    if ( !exists( $args->{-remote_addr} ) ) {
        $remote_address = $self->remote_addr;
    }
    else {
		$args->{-remote_addr} = ip_address_logging_filter($args->{-remote_addr}); 
        $remote_address = $args->{-remote_addr};
    }
    
    # email
    if ( !exists( $args->{-email} ) ) {
        $args->{-email} = '';
    }
	else { 
		$args->{-email} = cased($args->{-email});
	}
    
    #event
    if ( !exists( $args->{-event} ) ) {
        croak "You need to pass an, '-event'"; 
    }
    my $event = $args->{-event};
    
    # details
    if ( !exists( $args->{-details} ) ) {
        $args->{-details} = undef; 
    }
    my $details = $args->{-details};
    
    
    if(!exists($args->{-ua})){ 
        $args->{-ua} = $ENV{HTTP_USER_AGENT},        
    }
#    warn '$ENV{HTTP_USER_AGENT}' . $ENV{HTTP_USER_AGENT}; 
    my $ua = $args->{-ua};
    
    
    # Record this as an open? 
    if ( !exists( $args->{-record_as_open} ) ) {
        $args->{-record_as_open} = 0; 
    }
    if($args->{-record_as_open} == 1) {    
        my $recorded_open_recently = 1;
        try {
            $recorded_open_recently = $self->_recorded_open_recently($args);
        }
        catch {
            carp "Couldn't execute, '_recorded_open_recently', : $_";
        };
        if($t == 1){ 
            if(defined($args->{-mid})) { 
                warn 'mid is defined - we\'ll count this'; 
            }
            else { 
                warn 'mid is NOT defined - we\'re not counting this open'; 
            }
        }
        if ( $recorded_open_recently <= 0 && defined($args->{-mid})) {
            $self->open_log(
                {
                    %$args, 
                    # -ua => $args->{-ua} . ' *'
                }    
            );
        }
    }
	if($event eq 'open') { 
	    if(
			   $DADA::Config::PII_OPTIONS->{allow_logging_emails_in_analytics} == 1
			&& $self->{ls}->param('tracker_track_email') == 1 
		    && $self->{ls}->param('tracker_update_profiles_w_geo_ip_data') == 1
		    && $args->{-email} ne '') { 
			warn 'updating profile fields..'
				if $t; 
	        try { 
	            warn '$args->{-email}' . $args->{-email} 
	                if $t; 
	            warn '$remote_address'  . $remote_address 
	                if $t; 
	            $self->_update_profile_fields(
	                {
	                    -email      => $args->{-email},
	                    #-ip_address => $remote_address, 
						-ip_address => ip_address_logging_filter($remote_address), 
	                }
	            ); 
	        } catch { 
	            carp "problems updating fields with geo ip data: $_"; 
	        };
	    }
	}
    
    my $ts_snippet          = '';
    my $place_holder_string = '';
    
    if ( defined($timestamp) ) {
        $ts_snippet = 'timestamp,';
        $place_holder_string .= ' ,?';
    }
    
    my $query =
        'INSERT INTO '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . '(list, '
      . $ts_snippet
      . 'remote_addr, msg_id, event, email, user_agent, details) VALUES (?, ?, ?, ?, ?, ?, ?'
      . $place_holder_string . ')';

	  warn '$query:' . $query
	    if $t;
	  
    my $sth = $self->{dbh}->prepare($query);
    
	my @execute_args = (); 
    if ( defined($timestamp) ) {
		warn 'timestamp!'
		    if $t; 
		@execute_args = (
		    $self->{name}, 
		    $timestamp, 
		    $remote_address, 
		    $args->{-mid}, 
		    $event, 
		    $args->{-email}, 
		    $ua, 
		    $details
		);
        $sth->execute(@execute_args);
    }
    else {
		@execute_args = (
		    $self->{name},
		    $remote_address, 
		    $args->{-mid}, 
		    $event, 
		    $args->{-email}, 
		    $ua, 
		    $details
		);
        $sth->execute(@execute_args);
    	warn 'no timestamp' 
    	    if $t; 
	}
    if ( $t == 1 ) {
        require Data::Dumper;
		warn 'excute_args:' . Data::Dumper::Dumper([@execute_args]);
	}
	
	$sth->finish;
    return 1;
}




sub _recorded_open_recently {
    my $self = shift;
    my ($args) = @_;

    my $query;

	if ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){ 
		    if ( $args->{-timestamp} ) {
		        $query =
		            'SELECT COUNT(*) from '
		          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
		          . ' where list = ? msg_id = ? AND event = ? AND timestamp >= DATE_SUB('
		          . $args->{timestamp}
		          . ', INTERVAL 1 HOUR)';
		    }
		    else {
		        $query =
		            'SELECT COUNT(*) from '
		          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
		          . ' where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)';
		        if($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite'){ 
      				$query =~ s/NOW\(\)/CURRENT_TIMESTAMP/;
      			}				
		    }
		    
			
			
	}
	elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){
		
		if ( $args->{-timestamp} ) {
	        $query =
	            'SELECT COUNT(*) from '
	          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
	          . " where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= ' . $args->{timestamp} . ' - INTERVAL '1 HOUR'"; 
	    }
	    else {
	        $query =
	            'SELECT COUNT(*) from '
	          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
	          . " where list = ? AND remote_addr = ? AND msg_id = ? AND event = ? AND timestamp >= NOW() - INTERVAL '1 HOUR'";
	    }
		
	}
	elsif($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite') { 
		warn 'method not supported in SQLite';
		return 1; 
	}
	

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{name}, $args->{-remote_addr}, $args->{-mid}, 'open' )
      or croak "cannot do statement '$query'! " . $self->{dbh}->errstr;

    my @row = $sth->fetchrow_array();
    $sth->finish;
    return $row[0];
}




sub unique_and_dupe {
    my $self  = shift;
    my $array = shift;

    my @unique = ();
    my %seen   = ();

    foreach my $elem (@$array) {
        next if $seen{$elem}++;
        push @unique, $elem;
    }
    return [@unique];

}


sub get_all_mids {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-page} ) ) {
        $args->{-page} = 1;
    }
    if ( !exists( $args->{-entries} ) ) {
        $args->{-entries} = 10;
    }

    if ( !exists( $args->{-for_analytics_email} ) ) {
        $args->{-for_analytics_email} = 0;
    }

# postgres: $query .= ' SELECT DISTINCT ON(' . $subscriber_table . '.email) ';
# This query could probably be made into one, if I could simple use a join, or something
# DEV: There's also this idea:
# SELECT * FROM table ORDER BY rec_date LIMIT ?, ?} #
#     q{SELECT * FROM table ORDER BY rec_date LIMIT ?, ?}

    my $query = '';

    if ( $args->{-for_analytics_email} == 1 ) {

        # I also want the msg_id to be between 2 and 3 days
        my $epoch                 = time;
        my $two_days_ago          = time - int( 86400 * 2 );
        my $three_days_ago        = time - int( 86400 * 3 );
        my $two_days_ago_msg_id   = message_id($two_days_ago);
        my $three_days_ago_msg_id = message_id($three_days_ago);

        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? '
          . ' AND event = '
          . $self->{dbh}->quote('sent_analytics')
          . ' AND details = '
          . $self->{dbh}->quote('0')
          . ' AND msg_id < '
          . $self->{dbh}->quote($two_days_ago_msg_id)
          . ' AND msg_id > '
          . $self->{dbh}->quote($three_days_ago_msg_id)
          . ' GROUP BY msg_id ORDER BY msg_id DESC;';

    }
    elsif ( $self->{ls}->param('tracker_clean_up_reports') == 1 ) {
        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? AND event = \'num_subscribers\' GROUP BY msg_id ORDER BY msg_id DESC;';
    }
    else {

        $query =
            'SELECT msg_id FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? GROUP BY msg_id ORDER BY msg_id DESC;';
    }

    my $msg_id1 =
      $self->{dbh}->selectcol_arrayref( $query, {}, ( $self->{name} ) );

    warn 'Query: ' . $query
      if $t;

    my $total = 0;
    $total = scalar @$msg_id1;
    if ( $total == 0 ) {
        return ( $total, [] );
    }

    # DEV: LIMIT, OFFSET - HELLO?!
    my $begin = ( $args->{-entries} - 1 ) * ( $args->{-page} - 1 );
    my $end = $begin + ( $args->{-entries} - 1 );

    if ( $end > $total - 1 ) {
        $end = $total - 1;
    }

    @$msg_id1 = @$msg_id1[ $begin .. $end ];

    return ( $total, $msg_id1 );

}


sub update_sent_analytics { 
	
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-msg_id})){ 
		die "need a msg_id";
	}
	if(!exists($args->{-val})){ 
		$args->{-val} = 1; 
	}
	
    my $query = 'UPDATE '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} 
      . ' SET details    = ? '
      . ' WHERE event    = ? '
	  . ' AND msg_id   = ? '
	  . ' AND list     = ? '; 	  
	  
	my $sth = $self->{dbh}->prepare($query);
	$sth->execute( 
		$args->{-val}, 
		'sent_analytics', 
		$args->{-msg_id},
		$self->{name},
	) 
	or croak "cannot do statement '$query'! " . $self->{dbh}->errstr;
    
	$sth->finish;	
}





sub report_by_message_index {


    my $self          = shift;
	my ($args)        = @_; 

	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	my $sorted_report = [];
	    my $report        = {};
	    my $l;
	
	
		my $total   = undef; 
		my $msg_id1 = []; 
	
		if(exists($args->{-all_mids})){ 
			$msg_id1 = $args->{-all_mids};
		}
		else { 
			# Not using total, right now... 
			($total, $msg_id1) = $self->get_all_mids(); # no vars? 
		}
		if(!exists($args->{-page})){ 
			$args->{-page} = 1; 
		}
		if(!exists($args->{-fake})){ 
			$args->{-fake} = 0; 
		}

		my $real = 0; 

		    for my $msg_id (@$msg_id1) {
				next 
					unless defined $msg_id;

				$report->{$msg_id}->{msg_id} = $msg_id;

				# Clickthroughs
				my $clickthrough_count_query = 'SELECT COUNT(msg_id) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} .' WHERE list = ?  AND msg_id = ?';
				$report->{$msg_id}->{count} =
				$self->{dbh}
				->selectcol_arrayref( $clickthrough_count_query, {}, $self->{name}, $msg_id )->[0];

				if($args->{-fake} == 1) { 
					$report->{$msg_id}  = {};
				}
				else { 
					my $basic_event_counts = $self->msg_basic_event_count($msg_id); 
					for(keys %$basic_event_counts) { 
						$report->{$msg_id}->{$_} = $basic_event_counts->{$_};
					}
				}
				
				$report->{$msg_id}->{message_subject} = $self->fetch_message_subject($msg_id); 	
				if ( $self->{ah}->check_if_entry_exists($msg_id) ) {
					$report->{$msg_id}->{archived_msg} = 1;
				}
				if(length($report->{$msg_id}->{message_subject}) >= 50){ 
					$report->{$msg_id}->{message_subject_snipped} =  substr( $report->{$msg_id}->{message_subject}, 0, 49 ) . '...' 
				} 
				else { 
					$report->{$msg_id}->{message_subject_snipped} = $report->{$msg_id}->{message_subject};
				}
				
				
	    }

	    # Now, sorted:
	    for ( sort { $b <=> $a } keys %$report ) {
	        $report->{$_}->{mid}           = $_;    # this again.
	        $report->{$_}->{date}          = DADA::App::Guts::date_this( -Packed_Date => $_, );
			$report->{$_}->{S_PROGRAM_URL} = $DADA::Config::S_PROGRAM_URL; 
			$report->{$_}->{list}          = $self->{name}; 
	        
	        push( @$sorted_report, $report->{$_} );
	    }
		
		# dum, I guess this does the thing: 
		for my $this_id(@$sorted_report){ 				
			for my $inid(keys %{$this_id}){
				next if $inid =~ m/percent/; 
				$this_id->{$inid . '_commified'}
					= commify($this_id->{$inid}); 
			}
		}
		
		if($args->{-fake} != 1) {
			# The idea is if we've already calculated all this, no 
			# reason to do it twice, if the table and graph are shown together. 
			if(! $dc->cached(
				{
				-list    => $self->{name}, 
				-name    => 'message_history_json', 
				-page    => $args->{-page}, 
				-entries => $self->{ls}->param('tracker_record_view_count')
				}
			)){
				# warn 'creating message_history_json JSON from report_by_message_index'; 
				$self->message_history_json(
					{
						-report_by_message_index_data => $sorted_report,
						-page                         => $args->{-page}, 
						-printout                     => 0,	
					}
				);
			}
		}
	
    return $sorted_report;
}


sub fetch_message_subject {
    my $self    = shift;
    my $msg_id  = shift;
    my $subject = undef;

    if ( $self->{ah}->check_if_entry_exists($msg_id) ) {

        $subject = $self->{ah}->get_archive_subject($msg_id);
    }
    else {

        # This grabs the message subject from our activity table:
        my $original_subject_query =
            'SELECT details FROM '
          . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
          . ' WHERE list = ? AND msg_id = ? AND event = ?';

        $subject = $self->{dbh}->selectcol_arrayref(
            $original_subject_query,
            {
                MaxRows => 1
            },
            $self->{name},
            $msg_id,
            'original_subject'
        )->[0];
    }


    require DADA::App::FormatMessages;
    my $dfm = DADA::App::FormatMessages->new( -List => $self->{name} );
	$subject = $dfm->_decode_header($subject);
	
	
    if ( !defined($subject) ) {
        $subject = DADA::App::Guts::date_this( -Packed_Date => $msg_id );
    }

    return $subject;

}



sub msg_basic_event_count { 

	warn 'at msg_basic_event_count' 
		if $t; 
	
	my $self    = shift; 
	my $msg_id = shift; 
	my $basic_events = {};
    my %ok_events = (
        open                => 1,
        soft_bounce         => 1,
        hard_bounce         => 1,
        forward_to_a_friend => 1,
        view_archive        => 1,
		unsubscribe         => 1,
		errors_sending_to   => 1,
		abuse_report        => 1,
		#clickthroughs       => 1,
    );
    
    for(keys %ok_events){ 
        if(!exists($basic_events->{$_})){ 
            $basic_events->{$_} = 0; 
        }
        
    }
    
	my $basic_count_query = 'SELECT msg_id, event, COUNT(*) FROM ' 
		. $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} 
		. ' WHERE list = ? AND msg_id = ? GROUP BY msg_id, event';
	my $sth              = $self->{dbh}->prepare($basic_count_query);
       $sth->execute( $self->{name}, $msg_id);
    while ( my ( $m, $e, $c ) = $sth->fetchrow_array ) {
		if($ok_events{$e}){ 
			
			#warn '$e: ' . $e; 
			#warn '$c: ' . $c; 
			
			$basic_events->{$e} = $c; 
		}
	}
	$sth->finish; 
	undef $sth; 
	
	# num subscribers
 	my $num_sub_query = 'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';
	$basic_events->{num_subscribers} = $self->{dbh}->selectcol_arrayref( $num_sub_query, { MaxRows => 1 }, $self->{name}, $msg_id, 'num_subscribers' )->[0];

	# total recipients
	my $total_recipients_query = 'SELECT details FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} .' WHERE list = ? AND msg_id = ? AND event = ?';
	$basic_events->{total_recipients} = $self->{dbh}->selectcol_arrayref( $total_recipients_query, { MaxRows => 1 }, $self->{name}, $msg_id, 'total_recipients' )->[0];

	# total recipients
	if(! defined($basic_events->{total_recipients}) || $basic_events->{total_recipients} eq ''){ 
		$basic_events->{total_recipients} = $basic_events->{num_subscribers};
	}
	
	# start_time finish_time sending_method msg_size
	for my $misc_events(qw(msg_size start_time finish_time sending_method)){
		my $misc_events_query = 
			'SELECT details FROM ' 
			. $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} 
			.' WHERE list = ? AND msg_id = ? AND event = ?';
		$basic_events->{$misc_events} 
			= $self->{dbh}->selectcol_arrayref( 
				$num_sub_query, 
				{ MaxRows => 1 }, 
				$self->{name}, 
				$msg_id, 
				$misc_events 
			)->[0];
	}
	if(defined($basic_events->{msg_size})){ 
		
		$basic_events->{msg_size_formatted} = human_readable_filesize($basic_events->{msg_size});
	}
	if(defined($basic_events->{start_time}) && defined($basic_events->{finish_time})){
		$basic_events->{sending_time} = int($basic_events->{finish_time}) - int($basic_events->{start_time});	
		$basic_events->{sending_time_formatted} = formatted_runtime($basic_events->{sending_time}); 
		
		my $total_sending_time = $basic_events->{sending_time};
		if($total_sending_time <= 0){
			$total_sending_time = .1; 
		}
		
		my $hourly_sending = ($basic_events->{total_recipients} / $total_sending_time ) * 60 * 60; 
		$basic_events->{sending_speed_formatted} = commify(int($hourly_sending + .5));
		
	} 
	if(defined($basic_events->{start_time})){ 
		$basic_events->{start_time_formatted} = ctime_to_localtime($basic_events->{start_time}); 
	}
	if(defined($basic_events->{finish_time})){ 
		$basic_events->{finish_time_formatted} = ctime_to_localtime($basic_events->{finish_time}); 
	}
		
	# Received: 
	# total_recipients - soft_bounce - hard_bounce - errors_sending_to
	$basic_events->{received} = 
	  $basic_events->{total_recipients}
	- $basic_events->{soft_bounce}
	- $basic_events->{hard_bounce}
    - $basic_events->{errors_sending_to};

	# Delivered to (sent successfully, could bounce back) 
	# total_recipients - errors_sending_to
	$basic_events->{delivered_to} = 
	  $basic_events->{total_recipients}
    - $basic_events->{errors_sending_to};	
	
	
	# Unique Opens
	my $uo_query = 'SELECT msg_id, event, email, COUNT(*) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? and event = \'open\' GROUP BY msg_id, event, email'; 
	warn '$uo_query: ' . $uo_query
		if $t; 
	my $uo_count  = 0; 
	my $sth      = $self->{dbh}->prepare($uo_query);
       $sth->execute( $self->{name}, $msg_id);
	# Just counting what gets returned. 
	while ( my ( $m, $e, $c ) = $sth->fetchrow_array ) {
		$uo_count++; 
	}
	warn '$uo_count: ' . $uo_count
		if $t; 
	
	$basic_events->{unique_open} = $uo_count; 
	warn '$basic_events->{unique_open} ' . $basic_events->{unique_open}
		if $t; 
	
	
	$sth->finish; 
	# /Unique Opens
	
	# Unique Opens Percent
	$basic_events->{unique_opens_percent}          
		= $self->percentage(
			$basic_events->{unique_open}, 
			$basic_events->{received}
	);
	# /Unique Opens Percent
	
	# warn '$basic_events->{unique_opens_percent}: ' . $basic_events->{unique_opens_percent} ; 
	
	# Unique Clickthroughs
	my $uc_query = 
		'SELECT msg_id, email, url, COUNT(*) FROM ' 
	   . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} 
	   . ' WHERE list = ? AND msg_id = ?  GROUP BY url, msg_id, email'; 
	   
	my $uc_count       = 0; 
	my $total_ct_count = 0; 
	my $sth      = $self->{dbh}->prepare($uc_query);
       $sth->execute( $self->{name}, $msg_id);
	# Just counting what gets returned. 
	while ( my ( $m, $e, $c, $tcount ) = $sth->fetchrow_array ) {
	    #$basic_events->{clickthroughs} += $c; 
		$uc_count++; 
		$total_ct_count += $tcount; 
		#use Data::Dumper; 
		#warn '$m, $e, $c, $tcount' . Dumper([$m, $e, $c, $tcount]);
		
	}
	$basic_events->{unique_clickthroughs} = $uc_count; 
	$sth->finish; 
	# /Unique Clickthroughs
	
	# Unique Clickthroughs Percent
	$basic_events->{unique_clickthroughs_percent}          
		= $self->percentage(
			$basic_events->{unique_clickthroughs}, 
			# Should be total things clickthroughed, huh?
			$total_ct_count, 
	);
	# /Unique Clickthroughs Percent
	
	# Unsubscriptions 
	$basic_events->{unique_unsubscribes_percent} = 
		$self->percentage(
			$basic_events->{unsubscribe}, 
			$basic_events->{delivered_to}
		); 
	
    # ...Bounces
	$basic_events->{unique_soft_bounces_percent} = 
		$self->percentage(
			$basic_events->{soft_bounce}, 
			$basic_events->{delivered_to}
		); 

	$basic_events->{unique_hard_bounces_percent} = 
		$self->percentage(
			$basic_events->{hard_bounce}, 
			$basic_events->{delivered_to}
		); 
	
	$basic_events->{unique_bounces_percent} = 
		$basic_events->{unique_soft_bounces_percent} 
	  + $basic_events->{unique_hard_bounces_percent};
	
	# Received Percent
	$basic_events->{received_percent} = 
		$self->percentage(
			$basic_events->{received}, 
			$basic_events->{total_recipients}
	); 
	
	# Errors Sending To
	$basic_events->{errors_sending_to_percent} = 
		$self->percentage(
			$basic_events->{errors_sending_to}, 
			$basic_events->{total_recipients}
	); 
	
	$basic_events->{delivery_issues} =
		int($basic_events->{soft_bounce})
		+ int($basic_events->{hard_bounce})
		+ int($basic_events->{errors_sending_to}) 
		+ int($basic_events->{abuse_report}); 
	
	$basic_events->{delivery_issues_percent} = 
		$self->percentage(
			$basic_events->{delivery_issues},
			$basic_events->{total_recipients}
	);
		
	
#	# 
#	$basic_events->{abuse_report_percent} = 
#		$self->percentage(
#			$basic_events->{abuse_report}, 
#			$basic_events->{total_recipients}
#	); 

	return $basic_events;

}




sub msg_basic_event_count_json { 
	
    my $self          = shift;
	my ($args)        = @_;
	
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0;
	}
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'msg_basic_event_count_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	

	if(! defined($json)){ 

		my $report = $self->msg_basic_event_count($args->{-mid});	

		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );

		$datatable->add_columns(
		       { id => 'category',   label => "Category",      type => 'string',},
		       { id => 'number',     label => "Number",        type => 'number',},
		);


		if($args->{-type} eq 'opens') { 
			$datatable->add_rows(
		        [
		               { v => 'Unique Opens' },
		               { v => $report->{unique_opens_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Unopened' },
		               { v => (100 - $report->{unique_opens_percent}) },
		       ],
			);
			
			
		}
		elsif($args->{-type} eq 'unsubscribes') { 
			$datatable->add_rows(
		        [
		               { v => 'Unsubscriptions' },
		               { v => $report->{unique_unsubscribes_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Still Subscribed' },
		               { v => (100 - $report->{unique_unsubscribes_percent}) },
		       ],
			);
			
			
		}
		elsif($args->{-type} eq 'bounces') {
			$datatable->add_rows(
		        [
		               { v => 'Soft Bounces' },
		               { v => $report->{unique_soft_bounces_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Hard Bounces' },
		               { v => $report->{unique_hard_bounces_percent} },
		       ],
			);
			$datatable->add_rows(
		        [
		               { v => 'Received' },
		               { v => $report->{received_percent} },
		       ],
			);		
			$datatable->add_rows(
		        [
		               { v => 'Sending Errors' },
		               { v => $report->{errors_sending_to_percent} },
		       ],
			);		


		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'msg_basic_event_count_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
				-data    => \$json, 
			}
		);
		
	}
	
	my $headers = {
	    '-Cache-Control' => 'no-cache, must-revalidate',
	    -expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
	    -type            =>  'application/json',
    }; 

	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(%$headers);
		print $json; 
	}
	else { 
		return ($headers, $json); 
	}
	
	
}


sub report_by_message {

    my $self   = shift;
    my $mid    = shift;

	my $m_report = {};
    my $report   = {};
    my $l;
		
	my $basic_event_counts = $self->msg_basic_event_count($mid); 
	for(keys %$basic_event_counts) { 
		$report->{$_} = $basic_event_counts->{$_};
	}

    my $url_clickthroughs_query =
        'SELECT url, COUNT(url) AS count FROM '
      . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}
      . ' where list = ? AND msg_id = ? GROUP BY url ORDER by count DESC';
    my $sth = $self->{dbh}->prepare($url_clickthroughs_query);
    $sth->execute( $self->{name}, $mid );
    my $url_report = [];
    my $row        = undef;
    $report->{clickthroughs} = 0;
    while ( $row = $sth->fetchrow_hashref ) {	
		my $snippet = $row->{url}; 
		if(length($snippet) >= 100){ 
			$snippet = substr( $snippet, 0, 97 ) . '...';
		}
        push( 
			@$url_report, 
				{ 
					url         => $row->{url},
					url_snipped => $snippet,
					count       => $row->{count} 
				} 
			);
        $report->{clickthroughs} = $report->{clickthroughs} + $row->{count};
    }
    $sth->finish;
    undef $sth;
    $report->{url_report} = $url_report;
	$report->{total_bounce} = int($report->{'soft_bounce'}) + int($report->{'hard_bounce'}); 
	
	$m_report = $report; 
	
	for my $this_id(keys %{$m_report}){ 
		next if $this_id =~ m/percent/; 
		$m_report->{$this_id . '_commified'}
			= commify($m_report->{$this_id}); 
	}
	

	
	$report->{message_subject} = $self->fetch_message_subject($mid); 	
	if ( $self->{ah}->check_if_entry_exists($mid) ) {
		$report->{archived_msg} = 1;
	}
	if(length($report->{message_subject}) >= 50){ 
		$report->{message_subject_snipped} =  substr( $report->{message_subject}, 0, 49 ) . '...' 
	} 
	else { 
		$report->{message_subject_snipped} = $report->{message_subject};
	}
	
    return $m_report;
}

sub export_logs {

    my $self   = shift;
	my ($args) = @_; 
    
    my $r = undef; 
    
	#if(!exists($args->{-fh})){ 
	#	$args->{-fh} = \*STDOUT;
	#}
	#my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthrough';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	
    my $query = '';
    if ( $args->{-type} eq 'clickthrough' ) {

		my $custom_fields = $self->custom_fields; 
		my $sql_snippet = ''; 
		if(exists($custom_fields->[0])){ 
			$sql_snippet = join(', ', @$custom_fields);
			$sql_snippet = ', ' . $sql_snippet; 
		}
		
		#my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id url, email), @$custom_fields]);
		#print $fh "\n";
		
		my $title_status = $csv->combine(qw(timestamp remote_addr user_agent msg_id url email)); # combine columns into a string
        $r              .= $csv->string();   # get the combined string
    	$r              .= "\n";
        $query = 'SELECT timestamp, remote_addr, user_agent, msg_id, url, email'. $sql_snippet .' FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
    }
    elsif ( $args->{-type} eq 'activity' ) {
	
		#my $title_status = $csv->print ($fh, [qw(timestamp remote_addr msg_id activity details email)]);
		#print $fh "\n";
		my $title_status = $csv->combine(qw(timestamp remote_addr user_agent msg_id activity details email)); # combine columns into a string
        $r              .= $csv->string();   # get the combined string
    	$r              .= "\n";
		
		# timestamp list message_id activity details
        $query = 'SELECT timestamp, remote_addr, user_agent, msg_id, event, details, email FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?';
    }
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id = ?'; 
	}
	
    my $sth = $self->{dbh}->prepare($query);
	
	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
    }
	else { 
		$sth->execute($self->{name});
	}

 	while ( my $fields = $sth->fetchrow_arrayref ) {
        #my $status = $csv->print( $fh, $fields );
        #print $fh "\n";
        my $status = $csv->combine(@$fields); # combine columns into a string
        $r        .= $csv->string();   # get the combined string
    	$r        .= "\n";
    }
    return $r; 
}

sub export_by_email { 
	
	my $self   = shift; 
	my ($args) = @_;
	
	my $r; 
	
	require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

	#if(!exists($args->{-fh})){ 
    #		$args->{-fh} = \*STDOUT;
	#}
	#my $fh = $args->{-fh}; 
	
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs';
	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; #really. 
	}
	
	my $query; 
	
	if ( $args->{-type} eq 'clickthroughs' ) {
	    $query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?';
	}
	elsif ( $args->{-type} eq 'opens' ) { 
		$query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . " WHERE list = ? AND event = 'open'";
	}
	elsif ( $args->{-type} eq 'abuse_reports' ) {
		$query = 'SELECT DISTINCT(email) FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . " WHERE list = ? AND event = 'abuse_report'";	
	}
	
	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id = ?'; 
	}		
	$query .= ' ORDER BY email ASC';
			
	my $sth = $self->{dbh}->prepare($query);
    
	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
    }
	else { 
		$sth->execute($self->{name});
	}
	
#	print $fh $query . "\n";
#	print $fh . '$self->{name} ' . $self->{name} . "\n"; 
#	print $fh . '$args->{-mid} ' . $args->{-mid} . "\n"; 
	
	warn $query
	 if $t; 
	
	while ( my $fields = $sth->fetchrow_arrayref ) {
        
        #my $status = $csv->print( $fh, $fields );
        my $status = $csv->combine(@$fields); # combine columns into a string
        $r              .= $csv->string();   # get the combined string
    	$r              .= "\n";
    }
    
    my $headers = {'-Content-disposition' => 'attachment; filename=' 
			                              . $self->{name} 
                        			      . '-' 
                        			      . $args->{-type} 
                        			      . '-subscribers-' 
                        			      . $args->{-mid} 
                        			      . '.csv', 
			      -type => 'text/csv', 
		        }; 
	
	return ($headers, $r); 
	
}




sub ip_data { 
	
	# Todo: add email stuff to that. 
	# Remember bounces and everything else use a different column for email address!
	my $self   = shift; 
	my ($args) = @_; 

#	if(!exists($args->{-count})){ 
#		$args->{-count} = 20; 
#	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}

#	select remote_addr from dada_clickthrough_url_log where msg_id = '20110502135133'; 
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT timestamp, remote_addr, url FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
	}
	elsif($args->{-type} eq 'opens'){ 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ?'; 	
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'ALL') {
		$query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE (event = \'open\' OR event = \'forward_to_a_friend\' OR event = \'view_archive\') AND list = ?'; 				
	} 

	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id=?'; 
	}
	my $sth = $self->{dbh}->prepare($query);

	#	die $query; 

	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
	}
	else { 
		$sth->execute($self->{name});
	}
	my $ips = []; 

	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		if($args->{-type} eq 'clickthroughs'){ 
			push(@$ips, {
				timestamp => $row->{timestamp}, 
				ip        => $row->{remote_addr}, 
				event     => 'clickthrough', 
				url       => $row->{url}, 
				
			});
		}
		else { 
			push(@$ips, {
				timestamp => $row->{timestamp}, 
				ip        => $row->{remote_addr}, 
				event     => $row->{event}, 
			});
		}
	}	
	$sth->finish; 

	if($args->{-type} eq 'ALL') {
		my $ct_ips = $self->ip_data(
			{ 
				-type => 'clickthroughs', 
				-mid  => $args->{-mid}, 
			}
		); 
		foreach(@$ct_ips){ 
			push(@$ips, $_);
		}
	}
	return $ips; 
	
}

sub user_agent_data { 
	
	# Todo: add email stuff to that. 
	# Remember bounces and everything else use a different column for email address!
	my $self   = shift; 
	my ($args) = @_; 


    # require Data::Dumper; 
    #warn 'args: ' . Data::Dumper::Dumper($args); 
    
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}

#	select remote_addr from dada_clickthrough_url_log where msg_id = '20110502135133'; 
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT user_agent FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
	}
	elsif($args->{-type} eq 'opens'){ 
		$query = 'SELECT user_agent FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ?'; 	
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT user_agent FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT user_agent FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ?'; 			
	}
	elsif($args->{-type} eq 'ALL') {
		$query = 'SELECT user_agent FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE (event = \'open\' OR event = \'forward_to_a_friend\' OR event = \'view_archive\') AND list = ?'; 				
	} 

	if(defined($args->{-mid})){ 
		$query .= ' AND msg_id=?'; 
	}
	my $sth = $self->{dbh}->prepare($query);

    #warn '$query ' . $query; 

	if(defined($args->{-mid})){ 
		$sth->execute($self->{name}, $args->{-mid});
	}
	else { 
		$sth->execute($self->{name});
	}
	my $uas = []; 

	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
	    if($row->{user_agent} eq ''){ 
	        $row->{user_agent} = 'Unknown'; 
	    }
		push(@$uas, {
			user_agent => $row->{user_agent},
		});
	}	
	$sth->finish; 


	if($args->{-type} eq 'ALL') {
		my $cuas = $self->user_agent_data(
			{ 
				-type => 'clickthroughs', 
				-mid  => $args->{-mid}, 
			}
		); 
		foreach(@$cuas){ 
			push(@$uas, $_);
		}
	}
	#return $uas; 
    my $ua_count = {}; 
    for(@$uas){ 
        if(exists($ua_count->{$_->{user_agent}})) { 
            $ua_count->{$_->{user_agent}}++; 
        }
        else { 
            $ua_count->{$_->{user_agent}} = 1;   
        }
    }
    
    # Sorted Index
	my @index = sort { $ua_count->{$b} <=> $ua_count->{$a} } keys %$ua_count; 

    my $count = 15; 
    
	# Top n
	my @top = splice(@index,0,($count-1));

	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $ua_count->{$_};
	}
	my $final = {};
	foreach(@top){ 
		$final->{$_} = $ua_count->{$_};
	}
	if($other > 0){ 
		$final->{other} = $ua_count->{$other};
	}		
	
	
	
   # require Data::Dumper; 
   # warn '$final ' . Data::Dumper::Dumper($final); 
    return $final; 

}

sub user_agent_json { 
    
    my $self   = shift; 
	my ($args) = @_; 	
	my $report = $self->user_agent_data($args);	
    
    my $json;
    
	require Data::Google::Visualization::DataTable; 
	my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );
	my $n_report  = {}; 
	
	$datatable->add_columns(
	       { id => 'user_agent', label => "User Agent",  type => 'string',},
	       { id => 'number',     label => "Number",      type => 'number',},
	);
    my $can_use_bd = 1;
    try {
        require HTTP::BrowserDetect;
    }
    catch {
        $can_use_bd = 0;
    };

	
	if($can_use_bd == 1){
		for(keys %$report){ 
			my $ua = HTTP::BrowserDetect->new($_);
			my $human_readable; 		
			if($ua->browser_string) {
				$human_readable = 
					$ua->browser_string 
					. ' ' 
					. $ua->browser_version 
					. ' on ' 
					. $ua->os_string;
			
				#$if($ua->mobile()){ 
				#	$human_readable .= ' ' . $ua->device_string() . ' (mobile)'
				#}
				#elsif($ua->table()){ 
				#	$human_readable .= ' ' . $ua->device_string() . ' (tablet)'
				#}
			}
			else { 
				$human_readable = $_; 
			}
			if(! exists($n_report->{$human_readable})){ 
				$n_report->{$human_readable} = 0; 
			}
			$n_report->{$human_readable} += $report->{$_};
		}	
	}
	else { 
		$n_report = $report; 
	}
	
	for(reverse sort { $n_report->{$a} <=> $n_report->{$b} } keys %$n_report){ 
		$datatable->add_rows(
	        [
            { v => $_ },
            { v => $n_report->{$_}},
	       ],
		);
	}
	$json = $datatable->output_javascript(
		pretty  => 1,
	);
	
	#require Data::Dumper; 
	#warn Data::Dumper::Dumper($json); 
	
	my $headers = {
		'-Cache-Control' => 'no-cache, must-revalidate',
		-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
		-type            =>  'application/json',
	};
	
	return ($headers, $json);
	
}



sub country_geoip_data { 
	
	my $self   = shift; 
	my ($args) = @_; 	
	
#	if(!exists($args->{-count})){ 
#		$args->{-count} = 20; 
#	}
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}

	my $ip_data = $self->ip_data($args); 
	my $loc = {}; 
	
	require  Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->new($args->{-db});
	my $addr_name   = {};
	my $per_country = {}; 
	foreach(@$ip_data){ 
		my $country = $gi->country_code_by_addr($_->{'ip'});
		
		# Cache the Country name by IP...
	    $addr_name->{$country} = $gi->country_name_by_addr($_->{'ip'});
		
		if(defined($country)){ 
			if(!exists($per_country->{$country})){ 
				$per_country->{$country} = 0; 
			}
			$per_country->{$country}++;
		}
		else { 
			if(!exists($per_country->{'unknown'})){ 
				$per_country->{unknown} = 0;
			}
			$per_country->{'unknown'}++;
		}
	}
	my @r = ();
	foreach(keys %$per_country){ 
		if($_ eq 'unknown'){ 
			push(@r, {
				code => $_, 
				name => 'Unknown',
				count => $per_country->{$_}, 
			});
		}
		else { 
			
			push(@r, {
				code => $_, 
				name => $addr_name->{$_},
				count => $per_country->{$_}, 
			}); 
		}
	}	
	my @sorted = map  { $_->[0] }
	          sort { $b->[1] <=> $a->[1] }
	          map  { [$_, $_->{count}] }
	               @r;

	return \@sorted;
	
	
}

sub country_geoip_json { 
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0;
	}
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'country_geoip_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	
#	require Locale::Country;

	if(! defined($json)){ 
	
		my $report = $self->country_geoip_data($args);	
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );

		$datatable->add_columns(
		       { id => 'location',  label => "Location",       type => 'string'},
		       { id => 'color',     label => $args->{-label},  type => 'number'},
			   
		       #{ id => 'country',   label => 'Country',           type => 'string'},
		);

		for(@$report){ 
			
			# "Unknown" does a GeoIP lookup in the Maps API, which is something that needs to be granted/paid-for
			next if $_->{name} =~ m/unknown/i;
			
			
			$datatable->add_rows(
		        [
		               { v => $_->{code}, f => $_->{name}},
					
					
					# { 
					#	 	f => uc(Locale::Country::country2code($_->{name})), 
					#		v => $_->{code}
					# },
					
					 
	               { 
					   	v => $_->{count} 
				   },

	
		       ],
			);
		}

		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'country_geoip_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
				-data    => \$json, 
			}
		);
		
	}
	
	my $headers = {
	    '-Cache-Control' => 'no-cache, must-revalidate',
		-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
		-type            =>  'application/json',
	}; 
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(%$headers);
		print $json; 
	}
	else { 
		return ($headers, $json); 
	}
	
}

sub individual_country_geoip { 
	 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-mid})){ 
		$args->{-mid} = undef; 
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs'; 
	}
	if(!exists($args->{-country})){ 
		$args->{-country} = 'US'; 
	}
	
	if(!exists($args->{-db})){ 
		croak "You MUST pass the path to the geo ip database in, '-db'";
	}
	
	my $report = $self->ip_data($args);
	require Geo::IP::PurePerl;
	my $gi = Geo::IP::PurePerl->open($args->{-db});
	my $d           = {};
	my $cities      = {} ;
	my $ips_by_city = {};
	my $ip_data     = $self->ip_data($args); 
	for my $i_data(@$ip_data){ 
		my ($country_code,$country_code3,$country_name,$region,
		    $city,$postal_code,$latitude,$longitude,
		    $metro_code,$area_code ) = $gi->get_city_record($i_data->{'ip'});
		
		if($country_code eq $args->{-country}){ 
			
			
			if(! $city){
				$city = 'Other'; 
			}
			if($country_code eq 'US'){ 
				$city = $city . ', ' . $self->fip_to_state_names($region);
			}
			if(!$metro_code){ 
				$metro_code = 'Unknown'; 
			}
				
			if(!exists($d->{"$city\:$metro_code"})){
				$d->{"$city\:$metro_code"} = 0; 
				$cities->{"$city\:$metro_code"} = { 
					lat   => $latitude, 
					long  => $longitude, 
				};
				$ips_by_city->{$city} = [];
			} 
			$d->{"$city\:$metro_code"}++; 
			push(@{$ips_by_city->{$city}}, $i_data);  
		}
	}
	my @r; 
	for(keys %$d){ 
		my ($city, $metro_code) = split(':', $_); 
		push(@r, 
			{ 
			lat        => $cities->{$_}->{lat}, 
			long       => $cities->{$_}->{long}, 
			city       => $city, 
			count      => $d->{$_}, 
			ip_data    => $ips_by_city->{$city},
		});
	} 
	# sort by city
	my @sorted = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->{city} ] } @r;
	return [@sorted]; 
}

sub individual_country_geoip_json {
	
	my $self   = shift; 
	my ($args) = @_; 
	
	
	my $json;
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	my $report = $self->individual_country_geoip($args);




	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'individual_country_geoip' . '.' . $args->{-mid} . '.' . $args->{-type} . '.' . $args->{-country}, 
		}
	);
	
	if(! defined($json)){
		
		my $report = $self->individual_country_geoip($args);
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );


		$datatable->add_columns(
		       { id => 'latitude',     label => "Latitude",        type => 'number',},
		       { id => 'longitude',    label => "Longitude",       type => 'number',},
			   
		     #  { id => 'marker',  label => "marker",     type => 'string',},

		       { id => 'DESCRIPTION',  label => "Description",     type => 'string',},
		       { id => 'marker_color', label => "Clickthroughs",   type => 'number',},
		);
	
	
		for my $r(@$report) { 
			$datatable->add_rows(
		        [   
		               { v => $r->{lat},   },
		               { v => $r->{long},  },
					   { v => $r->{city},  },
					   { v => $r->{count},},
		       ],
			);
		}
	
		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'individual_country_geoip' . '.' . $args->{-mid} . '.' . $args->{-type} . '.' . $args->{-country}, 
				-data    => \$json, 
			}
		);
	}
	
	my $headers = {
	    '-Cache-Control' => 'no-cache, must-revalidate',
		-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
		-type            =>  'application/json',
	}; 
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(%$headers);
		print $json; 
	}
	else { 
		return ($headers, $json); 
	}
}

sub individual_country_geoip_report { 
	my $self   = shift; 
	my ($args) = @_;  

	my %labels = (
		open                => 'Open', 
		clickthrough        => 'Clickthrough', 
		view_archive 	    => 'Archive View',
		forward_to_a_friend => 'Forward',  
	    abuse_report        => 'Abuse Report', 
	); 
	
	my $report = $self->individual_country_geoip($args);



	# This needs to be munged - count each specific IPS: 
	for my $loc(@$report) { 
		my $unique_ips = {};
		my $ip_history = {};
		for my $ipdata(@{$loc->{ip_data}}){ 
			if(!exists($unique_ips->{$ipdata->{ip}})){ 
				$unique_ips->{$ipdata->{ip}} = 0;
				$ip_history->{$ipdata->{ip}} = [];
			}
			$unique_ips->{$ipdata->{ip}}++;
			my $time = $self->timestamp_to_time($ipdata->{timestamp});

			push(@{$ip_history->{$ipdata->{ip}}}, { 
				timestamp   => $ipdata->{timestamp},
				time        => $time, 
				ctime       => scalar(localtime($time)), 
                url         => $ipdata->{url},
                event       => $ipdata->{event},
				event_label => $labels{$ipdata->{event}},
			}); 
		}
		$loc->{unique_ips} = [];
		
		# Sort ip events by date
		my $sorted_ip_history = {};
		for my $unsorted_ips(keys %$ip_history){ 
			$sorted_ip_history->{$unsorted_ips} = [];
			
			
			my $u_ip_data = $ip_history->{$unsorted_ips};
			
			my @sorted_ips = map { $_->[0] }
	          sort { $a->[1] <=> $b->[1] }
	          map { [ $_, $_->{'time'} ] } @$u_ip_data;
	
			 $sorted_ip_history->{$unsorted_ips} = [@sorted_ips]; 
		}
		undef($ip_history); # garbage collect? 
		#/ Sort ip events by date
		
		
		for my $u_ips(keys %$unique_ips){ 
			push(@{$loc->{unique_ips}}, {
				ip         => $u_ips, 
				count      => $unique_ips->{$u_ips}, 
				ip_history => $sorted_ip_history->{$u_ips},
			}); 
		}
		$loc->{unique_ip_count} = scalar(@{$loc->{unique_ips}}); 
		delete($loc->{ip_data});
	} 
	return $report;
	
	
}
sub timestamp_to_time {
	my $self = shift;  	
	my $timestamp = shift;
	
	require Time::Local; 
	 
	my ($date, $time) = split(' ', $timestamp); 
	my ($year, $month, $day) = split('-', $date); 
	my ($hour, $minute, $second) = split(':', $time); 
	$second = int($second - 0.5) ; # no idea. 
	return Time::Local::timelocal( $second, $minute, $hour, $day, $month-1, $year );
}

sub individual_country_geoip_report_table { 
	my $self   = shift; 
	my ($args) = @_;
	my $html; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'individual_country_geoip_report_table' . '.' . $args->{-mid} . '.' . $args->{-country}. '.' . $args->{-type} . '.' . $args->{-chrome},
		}
	);
	if(!defined($html)){ 
	
	
		my $report = $self->individual_country_geoip_report($args);
	
		require DADA::Template::Widgets; 
		$html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/individual_country_geoip_report_table.tmpl',
	            -vars => {
					report => $report, 
					num_bounces   => scalar(@$report), 
					title         => $args->{-type},  
					country       => $args->{-country}, 
					chrome        => $args->{-chrome}, 
					mid           => $args->{-mid}, 
					Plugin_URL    => $args->{Plugin_URL}, 
	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'individual_country_geoip_report_table' . '.' . $args->{-mid} . '.' . $args->{-country}. '.' . $args->{-type} . '.' . $args->{-chrome},
				-data    => \$html, 
			}
		);
	}
	
	if($args->{-printout} == 1){ 
    	use CGI qw(:standard); 
    	print header(); 
    	print $html; 
    }
    else { 
        return ({}, $html); 
    }
    
}


sub data_over_time {
	 
	my $self   = shift; 
	my ($args) = @_; 
	my $mid    = undef; 
	my $data   = {};
	my $order  = [];
	my $r      = [];
	
	if(exists($args->{-mid})){ 
		$mid = $args->{-mid};
	}
	if(!exists($args->{-type})){ 
		$args->{-type} = 'clickthroughs';
	}
	my $query; 
	if($args->{-type} eq 'clickthroughs'){ 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? '; 
	}
	elsif($args->{-type} eq 'opens') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'open\' AND list = ? ';
	}
	elsif($args->{-type} eq 'forward_to_a_friend') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'forward_to_a_friend\' AND list = ? ';
	}
	elsif($args->{-type} eq 'view_archive') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'view_archive\' AND list = ? ';
	}
	elsif($args->{-type} eq 'unsubscribes') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'unsubscribe\' AND list = ? ';
	}
	elsif($args->{-type} eq 'abuse_report') { 
		$query = 'SELECT timestamp FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE event = \'abuse_report\' AND list = ? ';
	}
	 
	if($mid){ 
		$query .= ' AND msg_id = ?'; 
	}
	$query .= ' ORDER BY timestamp'; 
	
	
    my $sth = $self->{dbh}->prepare($query);
	if($mid){ 		
	    $sth->execute($self->{name}, $mid)
	      or croak "cannot do statement! " . $self->{dbh}->errstr;
	}
	else { 
	    $sth->execute($self->{name})
	      or croak "cannot do statement! " . $self->{dbh}->errstr;
	}
	
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		my $date = $row->{timestamp}; 
		my ($mdy, $rest) = split(' ', $date, 2);
		if(!exists($data->{$mdy})){ 
			$data->{$mdy} = 0; 
			push(@$order, $mdy)
		}
		$data->{$mdy}++; 
      }

	foreach(@$order){ 
		push(@$r, {mdy => $_, count => $data->{$_}});
	}

	return $r; 
	
}

sub data_over_time_json { 
    
	my $self   = shift; 
	my ($args) = @_;
	
	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'data_over_time_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
		}
	);
	
	if(! defined($json)){ 
		
		my $report = $self->data_over_time($args);
	
		require Data::Google::Visualization::DataTable; 
		my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );

		$datatable->add_columns(
			   { id => 'date',          label => 'Date',           type => 'string'}, 
			   { id => 'number',         label => $args->{-label},  type => 'number',},
		);

		for(@$report){ 
			$datatable->add_rows(
		        [
		               { v => $_->{mdy}  },
		               { v => $_->{count} },
		       ],
			);
		}


		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'data_over_time_json' . '.' . $args->{-mid} . '.' . $args->{-type}, 
				-data    => \$json, 
			}
		);
	}
	
	my $headers = {
	    '-Cache-Control' => 'no-cache, must-revalidate',
		-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
		-type            =>  'application/json',
		
	}; 
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(%$headers);
		print $json; 
	}
	else { 
		return ($headers, $json); 
	}
}



sub message_email_report {

    my $self = shift;
    my ($args) = @_;

    # warn '$args->{-type} ' . $args->{-type};
    if ( !exists( $args->{-mid} ) ) {
        croak "You MUST pass the, '-mid' parameter!";
    }
    my $mid  = $args->{-mid};
    my $type = undef;

    if ( exists( $args->{-type} ) ) {
        $type = $args->{-type};
    }
    else {
        croak 'you MUST pass -type!';
    }

	my $email_col = undef; 
	
	# Guh.
	if($type =~ m/bounce/) { 
		$email_col = 'details'; 
	}
	else { 
		$email_col = 'email'; 	    
	}
	
    my $query =
        'SELECT timestamp, ' . $email_col . ' from '
      . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table}
      . ' WHERE list = ? AND msg_id = ? AND event  = ? ORDER BY ' . $email_col;

	warn 'Query: ' . $query
		if $t; 

    my $sth = $self->{dbh}->prepare($query);

    $sth->execute( $self->{name}, $mid, $type );

    my @report = ();
    while ( my $row = $sth->fetchrow_hashref ) {
        my ( $name, $domain ) = split( '@', $row->{$email_col} );
        push(
            @report,
            {
                timestamp    => $row->{timestamp},
                email        => $row->{$email_col},
                email_name   => $name,
                email_domain => $domain,
            }
        );
    }

    # sort by domain...
    my @sorted = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->{email_domain} ] } @report;
    $sth->finish;

	# use Data::Dumper; 
	# warn Dumper(\@sorted); 
	
    return [@sorted];

}
sub message_email_report_table { 
	my $self   = shift; 
	my ($args) = @_; 
	my $html; 
	
	if(! exists($args->{-type})){ 
		croak 'you MUST pass -type!'; 
	}
	
	if(! exists($args->{-vars})){ 
		$args->{-vars} = {}; 
	}
	
	if(! exists($args->{-printout})){ 
	    $args->{-printout} = 0; 
	}
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_email_report_table' . '.' . $args->{-mid} . '.' . $args->{-type} , 
		}
	);
	if(! defined($html)){ 
	
		my $title; 
		if($args->{-type} eq 'soft_bounce'){ 
			$title = 'Soft Bounces'; 
		}
		elsif($args->{-type} eq 'hard_bounce'){ 
			$title = 'Hard Bounces'; 
		}
		elsif($args->{-type} eq 'unsubscribe'){ 
			$title = 'Unsubscriptions'; 
		}
		my $report = $self->message_email_report($args);
		
#		use Data::Dumper; 
#		warn Dumper($report); 
		
		my $Bounce_Handler_URL = $args->{-vars}->{Plugin_URL};
           $Bounce_Handler_URL =~ s/tracker/bounce_handler/; 

		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_email_report_table.tmpl',
	            -vars => {
					type          => $args->{-type},
					report        => $report, 
					num           => scalar(@$report), 
					title         => $title,  
					Bounce_Handler_URL => $Bounce_Handler_URL, 
					%{$args->{-vars}}, 
	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_email_report_table' . '.' . $args->{-mid} . '.' . $args->{-type} , 
				-data    => \$html, 
			}
		);
	}
	if($args->{-printout} == 1){ 
    	require CGI; 
    	print CGI::header(); 
    	e_print($html); 
    }
    else { 
        return({}, $html); 
    }
}



sub message_email_report_export_csv {
	
	my $self   = shift; 
	my ($args) = @_; 
	
	my $r = undef;
	
	if(! exists($args->{-type})){ 
		croak 'you MUST pass -type!'; 
	}
	
	#if(!exists($args->{-fh})){ 
	#	$args->{-fh} = \*STDOUT;
	#}
	#my $fh = $args->{-fh};
	
	require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);
	my $report = []; 
	
	if($args->{-type} eq 'email_activity') { 
		$report = $self->message_email_activity_listing($args);
		
		#use Data::Dumper;
		#warn '$args: '   . Dumper($args);
		#warn '$report: ' . Dumper($report); 
	}
	else { 
		$report = $self->message_email_report($args);
	}
	
	#my $title_status = $csv->print($fh, ['email type: ' . $args->{-type}]);
	#print $fh "\n";
	
	my $title_status = $csv->combine('email type: ' . $args->{-type}); # combine columns into a string
    $r              .= $csv->string();                                 # get the combined string
	$r              .= "\n";
	
	
	for my $i_report(@$report){ 
		my $email = $i_report->{email};

		# my $status = $csv->print( $fh, [$email] );
        # print $fh "\n";
        
        my $status = $csv->combine($email);    # combine columns into a string
        $r              .= $csv->string();                   # get the combined string
    	$r              .= "\n";
	}
	
	my $headers = {
		-attachment => 'email_report-' . $self->{name} . '-' . $args->{-type} . '.' . $args->{-mid} . '.csv',
		-type       => 'text/csv', 
	};
	
	return ($headers, $r); 
}


sub email_stats { 
	
	my $self = shift; 
	my ($args) = @_; 
	my $mid = $args->{-mid};
	my $count; 
	if(!exists($args->{-count})){ 
		$count = 15; 
	}
	else { 
		$count = $args->{-count};
	}
	
	my $type = undef; 
	if(exists($args->{-type})){ 
		$type = $args->{-type};
	}
	else { 
		croak 'you MUST pass -type!'; 
	}
	
	my $report = $self->message_email_report($args);
	
	
	my $data = {};

	for my $report(@$report ){ 

		my $email = $report->{email};

		my ($name, $domain) = split('@', $email); 
		if(!exists($data->{$domain})){ 
			$data->{$domain} = 0;
		}
		$data->{$domain} = $data->{$domain} + 1; 	
	}
	# Sorted Index
	my @index = sort { $data->{$b} <=> $data->{$a} } keys %$data; 

	# Top n
	my @top = splice(@index,0,($count-1));

	# Everyone else
	my $other = 0; 
	foreach(@index){ 
		$other = $other + $data->{$_};
	}
	my $final = [];
	foreach(@top){ 
		push(@$final, {domain => $_, number => $data->{$_}});
		
		#$final->{$_} = $data->{$_};
	}
	if($other > 0){ 
	#	$final->{other} = $other;
		push(@$final, {domain => 'other', number => $other}); 
	
	}		
	
	return $final; 

}

sub email_stats_json {
     
	my $self = shift; 
	my ($args) = @_; 
	
	if(!exists($args->{-count})){ 
		$args->{-count} = 15; 
	}
	if(!exists($args->{-printout})){ 
		$args->{-printout} = 0; 
	}

	my $json; 
	
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new; 

	$json = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'email_stats_json' . '.' . $args->{-mid} . '.' . $args->{-count} . '.' . $args->{-type} , 
		}
	);
	
	if(!defined($json)){ 
		my $stats = $self->email_stats($args);
	 

		require         Data::Google::Visualization::DataTable;
		my $datatable = Data::Google::Visualization::DataTable->new(
        	{ 
				json_object => $json_object,
			}
        );

		$datatable->add_columns(
		       { id => 'domain',     label => "Domain",        type => 'string',},
		       { id => 'number',     label => "Number",        type => 'number',},
		);

		for(@$stats){ 
			$datatable->add_rows(
		        [
		               { v => $_->{domain} },
		               { v => $_->{number} },
		       ],
			);
		}

		$json = $datatable->output_javascript(
			pretty  => 1,
		);
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'email_stats_json' . '.' . $args->{-mid} . '.' . $args->{-count} . '.' . $args->{-type} , 
				-data    => \$json, 
			}
		);
	}
	
	my $headers = {
		'-Cache-Control' => 'no-cache, must-revalidate',
		-expires         =>  'Mon, 26 Jul 1997 05:00:00 GMT',
		-type            =>  'application/json',
	};
	
	if($args->{-printout} == 1){ 
		require CGI; 
		my $q = CGI->new; 
		print $q->header(%$headers); 
		print $json; 
	}
	else { 
		return ($headers, $json);
	}
	
}

sub message_email_activity_listing {
	 
	my $self   = shift; 
	my ($args) = @_; 
	
	# mass mailing event log, no bounces
	my $query = 'SELECT email, COUNT(email) as "count" FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND event != \'num_subscribers\' GROUP BY msg_id, email ORDER BY count DESC;'; 
	my $sth = $self->{dbh}->prepare($query);
	   $sth->execute( $self->{name}, $args->{-mid} )
	      	or croak "cannot do statement! " . $self->{dbh}->errstr;
	my $r; 
	my $emails_events = {}; 
	while (my $row = $sth->fetchrow_hashref ) {		
    	$emails_events->{$row->{email}} = $row->{count}
	}
	$sth->finish; 
	undef $sth; 

	# mass mailing event log, bounces
 	$query = 'SELECT details, COUNT(event) as "count" FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND (event = \'soft_bounce\' OR event = \'hard_bounce\') GROUP BY msg_id, details ORDER BY count DESC;'; 
	my $sth = $self->{dbh}->prepare($query);
	   $sth->execute( $self->{name}, $args->{-mid} )
	      	or croak "cannot do statement! " . $self->{dbh}->errstr;
	my $r; 
	my $emails_bounces = {}; 
	while (my $row = $sth->fetchrow_hashref ) {
    	$emails_bounces->{$row->{details}} = (int($row->{count}) * .5); # WEIGHTED (down)
	}
	$sth->finish; 
	undef $sth; 
	# mass mailing event log, bounces
	
	#
	# I'm going to weigh Clickthroughs more than other things... 
	#
	# clickthrough log 
	   $query = 'SELECT email, COUNT(email) as "count" FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? AND msg_id = ?  GROUP BY msg_id, email ORDER BY count DESC;'; 
	my $sth = $self->{dbh}->prepare($query);
	   $sth->execute( $self->{name}, $args->{-mid} )
	      	or croak "cannot do statement! " . $self->{dbh}->errstr;
	my $r; 
	my $emails_clicks = {}; 
	while (my $row = $sth->fetchrow_hashref ) {
    	$emails_clicks->{$row->{email}} = (int($row->{count}) * 5) # WEIGHTED!
	}
	$sth->finish; 
	undef $sth; 
	#/ clickthrough log 

	my $folded = $emails_events; 
	# now, fold 'em all up; 
	foreach(keys %$emails_bounces){ 
		if(exists($folded->{$_})){ 
			$folded->{$_} = $folded->{$_} + $emails_bounces->{$_}; 
		}
		else { 
			$folded->{$_} = $emails_bounces->{$_}; 
		}
	}
	foreach(keys %$emails_clicks){ 
		if(exists($folded->{$_})){ 
			$folded->{$_} = $folded->{$_} + $emails_clicks->{$_}; 
		}
		else { 
			$folded->{$_} = $emails_clicks->{$_}; 
		}
	}
	
	
	# Sorted Index
	my @index = sort { $folded->{$b} <=> $folded->{$a} } keys %$folded; 
	my $sorted = []; 
	foreach(@index){ 
		next if !defined($_); 
		next if $_ eq ''; 
		push(@$sorted, {
			email => $_, 
			count => $folded->{$_}, 
			});
	}
	return $sorted; 
}

sub message_email_activity_listing_table { 
	my $self   = shift; 
	my ($args) = @_; 
	
	if(! exists($args->{-vars})){ 
		$args->{-vars} = {}; 
	}
	
	my $html;
		
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;  
	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_email_activity_listing_table' . '.' . $args->{-mid}, 
		}
	);
	
	if(!defined($html)){ 
			
		my $report = $self->message_email_activity_listing($args);
		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_email_report_table.tmpl',
	            -vars => {
	#				type          => $args->{-type},
					report        => $report, 
					num           => scalar(@$report), 
					title         => 'Subscriber Activity', 
					label         => 'message_email_activity_listing_table',
					show_count    => 1, 
					%{$args->{-vars}},  
	            },
	        }
	    );	
	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_email_activity_listing_table' . '.' . $args->{-mid},
				-data    => \$html, 
			}
		);
	}
	
	return({}, $html);
	
}




sub message_individual_email_activity_csv { 
    
	my $self   = shift; 
	my ($args) = @_; 
	my $r; 
	
	if(!exists($args->{-fh})){ 
		$args->{-fh} = \*STDOUT;
	}
	my $fh = $args->{-fh}; 
	
	my $report = $self->message_individual_email_activity_report($args);

    require Text::CSV;
    my $csv = Text::CSV->new($DADA::Config::TEXT_CSV_PARAMS);

    my @title_fields = qw(
        timestamp
        remote_addr   
        event 
        url
    ); 

    my @fields = qw(
        ctime
        ip   
        event 
        url 
    ); 
    
    my $headers ={
        '-Content-disposition' => 'attachment; filename=' . $self->{name} . '-message_individual_email_activity-' .  $args->{-email} . '-' .  $args->{-mid} . '.csv', 
         -type                 =>  'text/csv'
    }; 
    
    
    #my $title_status = $csv->print($fh, [@title_fields]);
    #print $fh "\n";
    
    my $title_status = $csv->combine(@title_fields); # combine columns into a string
    $r              .= $csv->string();   # get the combined string
	$r              .= "\n";
    
    
    foreach my $ir(@$report) { 
        my $row = []; 
        foreach(@fields){ 
            push(@$row, $ir->{$_}); 
        }
        #my $status = $csv->print( $fh, $row );
        
        my $status = $csv->combine(@$row); # combine columns into a string
        $r        .= $csv->string();   # get the combined string
    	$r        .= "\n";
    }
    
    return ($headers, $r); 
    
}



sub message_individual_email_activity_report {
	my $self   = shift; 
	my ($args) = @_; 
	
	my $email = $args->{-email}; 
	my $mid   = $args->{-mid}; 
	
	my %labels = (
		open                => 'Open', 
		clickthrough        => 'Clickthrough', 
		unsubscribe         => 'Unsubcribe', 
		soft_bounce         => 'Soft Bounce', 
		hard_bounce         => 'Hard Bounce', 
		errors_sending_to   => 'Sending Error',
		abuse_report        => 'Abuse Report',  
	);
	
	my $return = []; 
	my $event_query = 'SELECT timestamp, remote_addr, event FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ? AND ((email = ?) OR (event LIKE \'%bounce\' AND details = ?)) ORDER BY timestamp DESC';
    my $click_query = 'SELECT timestamp, remote_addr, url FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ? and msg_id = ? and email = ? ORDER BY timestamp DESC';
		
	my $sth = $self->{dbh}->prepare($event_query);
	   $sth->execute($self->{name}, $mid, $email, $email);
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		my $time = $self->timestamp_to_time($row->{timestamp});
		push(
			@$return, {
			time        => $time, 
			timestamp   => $row->{timestamp}, 
			ctime       => scalar(localtime($time)), 
			ip          => $row->{remote_addr}, 
			event       => $row->{event}, 
			event_label => $labels{$row->{event}},
			}
		); 
	}
	$sth->finish;
	undef $row;  
	undef $sth; 

	my $sth = $self->{dbh}->prepare($click_query);
	   $sth->execute($self->{name}, $mid, $email);
	my $row; 
	while ( $row = $sth->fetchrow_hashref ) {
		
		my $time = $self->timestamp_to_time($row->{timestamp});
		push(
			@$return, {
			timestamp   => $row->{timestamp}, 
			time        => $time, 
			ctime       => scalar(localtime($time)), 
			ip          => $row->{remote_addr}, 
			event       => 'clickthrough', 
			event_label => $labels{clickthrough},
			url         => $row->{url},
			}
		); 
	}
	$sth->finish; 
	undef $sth;	
	
	@$return = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] }
      map { [ $_, $_->{'time'} ] } @$return;

	
	return $return;
	
}

sub message_individual_email_activity_report_table { 
	my $self   = shift; 
	my ($args) = @_;

	my $html;
		
	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;  
	$html = $dc->retrieve(
		{
			-list    => $self->{name}, 
			-name    => 'message_individual_email_activity_report' . '.' . $args->{-mid} . '.' . $args->{-email}, 
		}
	);
	
	my $Bounce_Handler_URL = $args->{-plugin_url};
       $Bounce_Handler_URL =~ s/tracker/bounce_handler/; 
    
    
	
	if(!defined($html)){ 
	
		my $report = $self->message_individual_email_activity_report($args); 
	
		require DADA::Template::Widgets; 
	    $html = DADA::Template::Widgets::screen(
	        {
	            -screen           => 'plugins/tracker/message_individual_email_activity_report_table.tmpl',
	            -vars => {
					email         => $args->{-email}, 
					mid           => $args->{-mid},
					report        => $report, 
					Plugin_URL    => $args->{-plugin_url}, 
					Bounce_Handler_URL => $Bounce_Handler_URL,

	            },
	        }
	    );	
		$dc->cache(
			{ 
				-list    => $self->{name}, 
				-name    => 'message_individual_email_activity_report' . '.' . $args->{-mid} . '.' . $args->{-email}, 
				-data    => \$html, 
			}
		);
	}
	return ({}, $html); 

}







sub purge_log { 
	
	
	my $self = shift; 
	
		
		my $query1 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table} . ' WHERE list = ?'; 
		my $query2 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ?'; 
		
		$self->{dbh}->do($query1, {}, ($self->{name})) or die "cannot do statement " . $self->{dbh}->errstr;
		$self->{dbh}->do($query2, {}, ($self->{name})) or die "cannot do statement " . $self->{dbh}->errstr;

		require DADA::App::DataCache; 
		my $dc = DADA::App::DataCache->new;
		$dc->flush(
			{
				-list => $self->{name}
			}
		);
		
	return 1; 
}


sub delete_msg_id_data { 

    my $self   = shift; 
    my ($args) = @_; 
    my $mid = $args->{-mid}; 
    
    warn 'mid: ' . $mid; 
    
	my $query1 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{clickthrough_url_log_table}   . ' WHERE list = ? AND msg_id = ?'; 
	my $query2 = 'DELETE FROM ' . $DADA::Config::SQL_PARAMS{mass_mailing_event_log_table} . ' WHERE list = ? AND msg_id = ?';

	$self->{dbh}->do($query1, {}, ($self->{name}, $mid)) or die "cannot do statement " . $self->{dbh}->errstr;
	$self->{dbh}->do($query2, {}, ($self->{name}, $mid)) or die "cannot do statement " . $self->{dbh}->errstr;

	require DADA::App::DataCache; 
	my $dc = DADA::App::DataCache->new;
	$dc->flush(
		{
			-list => $self->{name}
		}
	);
	
    return 1; 

}




sub remove_old_tracker_data {
    my $self = shift;
    my $r;
    my $total_count = 0;

    $r .=
        "Mailing List: "
      . $self->{ls}->param('list_name') . " ("
      . $self->{ls}->param('list') . ")\n"
      . '-' x 72 . "\n";

    if ( $self->{ls}->param('tracker_data_auto_remove') == 1 ) {
        if ( can_use_DateTime() ) {

            my $translation_key = {
                '1m',  => 1,
                '2m',  => 2,
                '3m',  => 3,
                '4m',  => 4,
                '5m',  => 5,
                '6m',  => 6,
                '7m',  => 7,
                '8m',  => 8,
                '9m',  => 9,
                '10m', => 10,
                '11m', => 11,
                '1y',  => 12,
                '2y',  => 24,
                '3y',  => 36,
                '4y',  => 48,
                '5y'   => 60,
            };

            my $timespan;
            if (
                exists(
                    $translation_key->{
                        $self->{ls}
                          ->param('tracker_data_auto_remove_after_timespan')
                    }
                )
              )
            {
                $timespan = $translation_key->{ $self->{ls}
                      ->param('tracker_data_auto_remove_after_timespan') };
                require DateTime;
                my $old_epoch = DateTime->today->subtract(
                    months => $translation_key->{
                        $self->{ls}
                          ->param('tracker_data_auto_remove_after_timespan')
                    }
                )->epoch;

                #$r .= "epoch: " . $old_epoch . "\n";
                #$r .= "localtime: " . scalar localtime($old_epoch) . "\n";

                my $old_msg_id = DADA::App::Guts::message_id($old_epoch);
                $r .= "\tRemoving clickthrough data that's older than, "
                  . scalar localtime($old_epoch) . "\n";

                my $query =
                    'DELETE FROM '
                  . $self->{sql_params}->{clickthrough_url_log_table}
                  . ' WHERE msg_id <= ? AND list = ?';

                my $sth = $self->{dbh}->prepare($query);
                my $c   = $sth->execute( $old_msg_id, $self->{name} )
                  or croak "cannot do statement! " . $self->{dbh}->errstr;
                $sth->finish;
                if ( $c eq '0E0' ) {
                    $c = 0;
                }

                $total_count += $c;

                $r .=
                    "\tRemoved "
                  . $c
                  . " rows(s) in "
                  . $self->{sql_params}->{clickthrough_url_log_table} . "\n";

                undef $query;
                undef $sth;
                undef $c;

                my $query =
                    'DELETE FROM '
                  . $self->{sql_params}->{mass_mailing_event_log_table}
                  . ' WHERE msg_id <= ? AND list = ?';

                my $sth = $self->{dbh}->prepare($query);
                my $c   = $sth->execute( $old_msg_id, $self->{name} )
                  or croak "cannot do statement! " . $self->{dbh}->errstr;
                $sth->finish;
                if ( $c eq '0E0' ) {
                    $c = 0;
                }

                $total_count += $c;

                $r .=
                    "\tRemoved "
                  . $c
                  . " rows(s) in "
                  . $self->{sql_params}->{mass_mailing_event_log_table} . "\n";

            }
            else {
                $r .=
                  "Unknown timespan: "
                  . $self->{ls}
                  ->param('tracker_data_auto_remove_after_timespan') . "\n";
            }
        }
        else {
            $r .= "\tDisabled. The DateTime CPAN module will need to be installed to enable this feature.\n";
        }
    }
    else {
        $r .= "\tNot enabled.\n";
    }

    return ( $r . "\n", $total_count );

}


sub optimize_tracker_data { 

	my $self = shift; 
	my $r    = ''; 
	
	$r .= "Optimizing tracker data tables...\n";
		
	if($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){
		 
		$self->{dbh}->do('OPTIMIZE TABLE ' . $self->{sql_params}->{clickthrough_url_log_table})
			or $r .= $self->{dbh}->errstr;
	
	    $r .= "\tOptimized " 
			. $self->{sql_params}->{clickthrough_url_log_table} 
			. "\n";

		$self->{dbh}->do('OPTIMIZE TABLE ' . $self->{sql_params}->{mass_mailing_event_log_table})
			or $r .= $self->{dbh}->errstr;

		$r .= 
			"\tOptimized "
			. $self->{sql_params}->{mass_mailing_event_log_table}
			. "\n";
	}
	
	return $r; 
	
}








sub remote_addr {
    if(exists($ENV{HTTP_X_FORWARDED_FOR})){ 
        # http://en.wikipedia.org/wiki/X-Forwarded-For
        my ($client, $proxies) = split(',', $ENV{HTTP_X_FORWARDED_FOR}, 2); 
        return ip_address_logging_filter($client); 
    }
    else { 
        return ip_address_logging_filter($ENV{'REMOTE_ADDR'}) || '127.0.0.1';
    }
}

sub fip_to_state_names { 

	my $self = shift; 
	my $code = shift; 
	my $lut = { 
		'01' => 'Alabama',
		'02' => 'Alaska',
		'03' => 'American Samoa',
		'04' => 'Arizona',
		'05' => 'Arkansas',
		'06' => 'California',
		'07' => 'Canal Zone',
		'08' => 'Colorado',
		'09' => 'Connecticut',
		'1' => 'Alabama',
		'2' => 'Alaska',
		'3' => 'American Samoa',
		'4' => 'Arizona',
		'5' => 'Arkansas',
		'6' => 'California',
		'7' => 'Canal Zone',
		'8' => 'Colorado',
		'9' => 'Connecticut',
		'10' => 'Delaware',
		'11' => 'District of Columbia',
		'12' => 'Florida',
		'13' => 'Georgia',
		'14' => 'Guam',
		'15' => 'Hawaii',
		'16' => 'Idaho',
		'17' => 'Illinois',
		'18' => 'Indiana',
		'19' => 'Iowa',
		'20' => 'Kansas',
		'21' => 'Kentucky',
		'22' => 'Louisiana',
		'23' => 'Maine',
		'24' => 'Maryland',
		'25' => 'Massachusetts',
		'26' => 'Michigan',
		'27' => 'Minnesota',
		'28' => 'Mississippi',
		'29' => 'Missouri',
		'30' => 'Montana',
		'31' => 'Nebraska',
		'32' => 'Nevada',
		'33' => 'New Hampshire',
		'34' => 'New Jersey',
		'35' => 'New Mexico',
		'36' => 'New York',
		'37' => 'North Carolina',
		'38' => 'North Dakota',
		'39' => 'Ohio',
		'40' => 'Oklahoma',
		'41' => 'Oregon',
		'42' => 'Pennsylvania',
		'43' => 'Puerto Rico',
		'44' => 'Rhode Island',
		'45' => 'South Carolina',
		'46' => 'South Dakota',
		'47' => 'Tennessee',
		'48' => 'Texas',
		'49' => 'Utah',
		'50' => 'Vermont',
		'51' => 'Virginia',
		'52' => 'Virgin Islands of the U.S.',
		'53' => 'Washington',
		'54' => 'West Virginia',
		'55' => 'Wisconsin',
		'56' => 'Wyoming',
		'60' => 'American Samoa',
		'64' => 'Federated States of Micronesia',
		'66' => 'Guam',
		'67' => 'Johnston Atoll',
		'68' => 'Marshall Islands',
		'69' => 'Northern Mariana Islands',
		'70' => 'Palau',
		'71' => 'Midway Islands',
		'72' => 'Puerto Rico',
		'74' => 'U.S. Minor Outlying Islands',
		'76' => 'Navassa Island',
		'78' => 'Virgin Islands of the U.S.',
		'79' => 'Wake Island',
		'81' => 'Baker Island',
		'84' => 'Howland Island',
		'86' => 'Jarvis Island',
		'89' => 'Kingman Reef',
		'95' => 'Palmyra Atoll',
	};
	if(exists($lut->{$code})){ 
		return $lut->{$code}; 
	}
	else { 
		return $code; 
	}


}

sub send_analytics_email_notification {

    my $self = shift;
	my $r    = ''; 

    $r .=
        "Mailing List: "
      . $self->{ls}->param('list_name') . " ("
      . $self->{ls}->param('list') . ")\n"
      . '-' x 72 . "\n";
	
	if($self->{ls}->param('tracker_send_analytics_email_notification') != 1){ 
		$r .= "Disabled.\n\n";
		return $r; 
	}
    my ( $total, $msg_ids ) = $self->get_all_mids(
        {
            -entries             => 10,
            -for_analytics_email => 1,
        }
    );

    if ( scalar(@$msg_ids) == 0 ) {
		$r .= "No messages to send analytics for\n\n"; 
        return $r;
    }
	
	my $msg_id_to_send; 
	for(reverse @$msg_ids){ 
		if(defined($_)){ 
			$msg_id_to_send = $_; 
			last; 
		}
	}
    my $m_report = $self->report_by_message( $msg_id_to_send );
	   
	
	
	$r .= "Sending out analytics report for: " . $m_report->{message_subject} .  " (msg_id: " . $msg_id_to_send . ")\n\n";
	
	
    require DADA::Template::Widgets;

    my $scrn = DADA::Template::Widgets::screen(
        {
            -screen => 'plugins/tracker/message_report_table.tmpl',
            -vars   => {
                a_in_t => 0,
                %$m_report,
            }
        },
        -list_settings_vars_param => {
            -list   => $self->{name},
            -dot_it => 1,
        },

    );

    require DADA::App::EmailThemes;
    my $em = DADA::App::EmailThemes->new(
        {
            -list => $self->{name},
        }
    );
	my $etp = $em->fetch('tracker_email_analytics');

    
    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $self->{name} );
	
	require DADA::App::Messages;
    my $dam = DADA::App::Messages->new( { -list => $self->{name} } );


    $dam->send_multipart_email(
        {
            -headers => {
                From => $fm->format_phrase_address(
                    $etp->{vars}->{from_phrase},
                    $self->{ls}->param('list_owner_email')
                ),
                To => $fm->format_phrase_address(
                    $etp->{vars}->{to_phrase},
					$self->{ls}->param('list_owner_email')
                ),
                Subject       => $etp->{vars}->{subject},
				
            },
            -plaintext_body => $etp->{plaintext},
            -html_body      => $etp->{html},
            -tmpl_params => {
                -list_settings_vars_param => {
                    -list => $self->{name}
                },
                -vars => {
                    mass_mailing_analytics_table => $scrn,
                    message_id                   => $msg_id_to_send,
					%$m_report, 
                },
            }
        }
    );

    $self->update_sent_analytics(
        {
            -msg_id => $msg_id_to_send,
            -val    => 1,
        }
    );
	
    # return ( {}, $scrn );
	return $r; 

}

sub DESTROY {}

1;


=pod

=head1 COPYRIGHT

Copyright (c) 1999 - 2023 Justin Simoni All rights reserved. 

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

