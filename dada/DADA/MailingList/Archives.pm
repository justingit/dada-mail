package DADA::MailingList::Archives; 
use strict; 
use lib qw(./ ../ ../../ ../../DADA ../perllib); 
use DADA::Config qw(!:DEFAULT); 	
use DADA::App::Guts;
use Carp qw(carp croak); 
use Try::Tiny; 


# A weird fix.
BEGIN {
   if($] > 5.008){
      require Errno;
      require Config;
   }
}

my $type;
my $backend; 

BEGIN { 
	$type = $DADA::Config::ARCHIVE_DB_TYPE;
	if($type eq 'SQL'){ 
	 	if ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){ 
			$backend = 'MySQL';
		}
		elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){ 		
			$backend = 'PostgreSQL';
		}
		elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite'){ 
		 	$backend= 'SQLite';
		}
	}
	elsif($type eq 'Db'){ 
		$backend = 'Db'; 
	}
	else { 
		die "Unknown \$ARCHIVE_DB_TYPE: '$type' Supported types: 'PlainText', 'SQL'"; 
	}
	
}
use base "DADA::MailingList::Archives::$backend";



=pod

=head1 NAME

DADA::MailingList::Archives

=head1 DESCRIPTION

This module holds the shared methods between the different archive backends

Many of these methods have to do with massaging the message for viewing; 


=pod


=head1 METHODS

=head2 get_neighbors

	my ($prev, $next) = $archive->get_neighbors();

this will tell you in the frame of reference of what message you're on, 
what the previous and next entry keys are. 

=cut

sub get_neighbors {
    my $self = shift;
    my $key  = shift;
    $key = $self->_massaged_key($key);
    my $entries = $self->get_archive_entries();

    my $i = 0;
    my %lookup_hash;

    for (@$entries) {
        $lookup_hash{$_} = $i;
        $i++;
    }

    # oh, I get it - it's in reverse chrono...
    my $index = $lookup_hash{$key};
    my $prev  = $entries->[ $index - 1 ]
      if $entries->[ $index - 1 ] != $entries->[-1];
    my $next = $entries->[ $index + 1 ]
      if $entries->[ $index + 1 ];

    # That wraparound stuff is stupid.
    #my $next  = $entries -> [$index+1] || $entries->[0];

    if ( $self->{ls}->param('sort_archives_in_reverse') ) {
        return ( $next, $prev );
    }
    else {

        return ( $prev, $next );

    }
}




=pod

=head2 check_if_entry_exists;

see if an entry exists, returns 1 when its there, 0 if it aint

=cut

sub check_if_entry_exists {

	my $self       = shift;  
	my $key        = shift; 
	   $key        = $self->_massaged_key($key);
	my $entry_list = $self->get_archive_entries(); 
	my $test       = 0; 
	
	for(@$entry_list){ 
		if($_ eq $key){ 
			$test++; 
		}
	}
	return $test; 

}




=pod

=head2 set_archive_subject();

$archive->set_archive_subject($subject);

changes the archive's subject

=cut

sub set_archive_subject { 

	# This kinda sucks, since we have now two versions of the subject, right? 
	my $self        = shift; 
	my $key         = shift; 
	my $new_subject = shift; 
	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($key); 
	$self->set_archive_info($new_subject, $message, $format, $raw_msg); 

}




=pod

=head2 set_archive_message();

	$archive->set_archive_message($message);

changes the archive's message (yo) 


=cut

sub set_archive_message { 

	my $self        = shift; 
	my $key         = shift; 
	my $new_message = shift; 
	   
	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($key); 
	$self->set_archive_info($subject, $new_message,  $format, $raw_msg); 
}




=pod

=head2 set_archive_format

	$archive -> set_archive_format($format);

changes the archive's format (yo) 


=cut

sub set_archive_format { 

	my $self       = shift; 
	my $key        = shift;
	my $new_format = shift; 
	   
	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($key); 
	$self->set_archive_info($subject, $message,  $new_format, $raw_msg); 

}




=pod

=head2 get_archive_subject

	my $format = get_archive_subject($key); 

gets the subject of the given $key

=cut

sub get_archive_subject { 

	my $self = shift; 
	my $key  = shift; 
	my ($subject, $message, $format) = $self->get_archive_info($key);
	return $subject; 

}




=pod

=head2 get_archive_format

	my $format = get_archive_format($key); 

gets the format of the given $key

=cut



sub get_archive_format { 
	
	my $self = shift; 
	my $key = shift; 
	my ($subject, $message, $format) = $self->get_archive_info($key);
	return $format; 

}




=head2 get_archive_message

	my $format = get_archive_message($key); 

gets the message of the given $key

=cut

sub get_archive_message { 
	
	my $self = shift; 
	my $key = shift; 
	my ($subject, $message, $format) = $self->get_archive_info($key);
	return $message; 

}




=pod

=head2 create_index

	my ($begin, $stop) = $archive->create_index($start);

This 'll tell you what to print on each archive index. 
something like, 'start on the 40th message and end on the 50th'

=cut

sub get_header { 
	
	my $self = shift; 
	my %args = (-header => undef, 
				-key    => undef, 
				@_, 
				); 

	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($args{-key}, 1); 
	my $entity = $self->_entity_from_raw_msg($raw_msg); 			
	my $header = $entity->head->get($args{-header}, 0); 

	# DEV: Decode Header!
	if($args{-header} =~ m/Reply\-To|To|From|Subject|Cc|Sender/){ 
		$header = $self->_decode_header($header); 
	}

	#Special Case. 
	if($args{-header} eq 'Subject'){ 
		$header = $self->strip_subjects_appended_list_name($header)
			if $self->{ls}->param('no_prefix_list_name_to_subject_in_archives') == 1; 
	}
	return $header; 
	
}

sub sender_address {

    my $self = shift; 
    my ($args) = @_; 
    my $id = $args->{-id};
    my $header = $args->{-header}; 
    
    require Email::Address;
    
    my $e = $self->get_header(
        -key    => $id,
        -header => 'Sender', 
    );
    if(!defined($e) || length($e) < 1){ 
        $e = $self->get_header(
            -key    => $id,
            -header => 'From', 
        );
    }
    my $a; 
    
    if(defined($e) && length($e) > 0){ 
        $a = ( Email::Address->parse($e) )[0]->address;
    }
    else { 
        warn 'no sender address found.'; 
    }
    return $a; 
    
}




sub strip_subjects_appended_list_name {

    my $self    = shift;
    my $subject = shift;

    $subject = ''
      if !$subject;

    my $s_list        = quotemeta( $self->{list} );
    my $s_list_name   = quotemeta( $self->{ls}->param('list_name') );
    my $tmpl_tag_list = quotemeta('<!-- tmpl_var list_settings.list -->');
    my $tmpl_tag_list_name =
      quotemeta('<!-- tmpl_var list_settings.list_name -->');

    $subject =~
      s/\[($s_list|$s_list_name|$tmpl_tag_list|$tmpl_tag_list_name)\]//g;

    return $subject;

}






sub in_reply_to_info { 

	my $self = shift; 
	my %args = (-key => undef, @_); 	
	die "no key! " if !$args{-key}; 

	my $in_reply_to = $self->get_header(-header => 'In-Reply-To', -key => $args{-key});
		
	if(!$in_reply_to){ #sigh...
		my @refs = split(' ', $self->get_header(-header => 'References', -key => $args{-key})); 
		$in_reply_to = $refs[-1];
	}
	
	return (undef, undef) if ! $in_reply_to; 
	
	$in_reply_to =~ s/^\<|\>$//g; # first and last <>
	 
	
	# model:
	# <20050807202003.02381237.dada@skazat.com>
	my ($id, $ran_string, $sender) = split(/\./, $in_reply_to);
	
	my $subject =  $self->get_header(-header => 'Subject', -key => $id); 
       $subject =~ s/\n|\r/ /g;
       $subject = strip($subject); 
       # DEV: Decode Header!

       if(!$subject){ 
            $subject = $DADA::Config::EMAIL_HEADERS{Subject}; 
       }

		# DEV: Decode Header!
		$subject = $self->_decode_header($subject); 
        
	return ($id, $subject) if $id && $subject; 
	
	
}





sub create_index { 

	my $self    = shift; 
	my $here    = shift || 0; 
	my $amount  = $self->{ls}->param('archive_index_count') || 10;
	my $entries = $self->get_archive_entries() || undef; 
	
	if($entries){ 

		my ($start, $stop);    
		
		$start = $here;
		$stop  = ($start + $amount)-1; 
		return ($start, $stop);
	}
}




=pod

=head2 newest_entry

returns the the key/id of the most recent archive message

=cut

sub newest_entry {
 
	my $self = shift; 
	my $entries = $self->get_archive_entries(); 
	
	
	@$entries = sort { $a <=> $b } @$entries;
	#if($entries->[0]){ 
	#	if($entries->[1]){ 
			return $entries->[-1];
	#	}
	#	else { 
	#		return $entries->[0];
	#	}
	
	#}
	#else { 
	#	return undef; 
	#}
}




=pod

=head2 oldest_entry

returns the key/of the first archive message

=cut

sub oldest_entry { 

	my $self    = shift; 
	my $entries = $self->get_archive_entries(); 
	@$entries   = sort { $a <=> $b  } @$entries;
	return $entries->[0];

}






=pod

=head2 create_index_nav

	print $archive->create_index_nav($stopped_at);

creates a HTML table that looks like this: 


            <<Prev                      Next >>

at the bottom of each archive index

=cut 


# This looks like it creates navigation for lists of archives, rather than for individual archives...
# One day, this should be replaced with Data::Pageset

sub create_index_nav {

    my $self       = shift;
    my $stopped_at = shift;
    my $admin      = shift || 0;

    my $iterate = $self->{ls}->param('archive_index_count') || 10;
    my $entries = $self->get_archive_entries();
    my $forward = $stopped_at;
    my $back;

    # let see if we're at some weird halfway between point

    my $mod_check = $stopped_at % $iterate;
    my $fixer;

    my $full_stop = $stopped_at;

    my $url = $DADA::Config::PROGRAM_URL;
    if($admin == 1){ 
        $url = $DADA::Config::S_PROGRAM_URL;
    }
    
    if ( $mod_check > 0 ) {

        # substract it from the iterate
        $fixer = $iterate - $mod_check;
        $full_stop += $fixer;
    }

    $back = ( $full_stop - ( $iterate * 2 ) );

    my $prev_link = '';
    my $next_link = '';

    my $af;

    if ( $admin == 1 ) {
        $af  = 'view_archive';
        $url = $DADA::Config::S_PROGRAM_URL;
    }
    else {
        $af = 'archive';
    }

    my $prev_link_start;
    my $next_link_start;

    if ( $self->{ls}->param('sort_archives_in_reverse') ) {
        if ( $back >= 0 ) {
            $next_link_start = $back;
        }
        if ( ( $forward - 1 ) < $#{$entries} ) {
            $prev_link_start = $forward;
        }
    }
    else {
        if ( $back >= 0 ) {
            $prev_link_start = $back;
        }

        if ( ( $forward - 1 ) < $#{$entries} ) {
            $next_link_start = $forward;
        }
    }
    

    require DADA::Template::Widgets;
    return DADA::Template::Widgets::screen(
        {
            -screen => 'archive_index_nav_table_widget.tmpl',
            -list   => $self->{name},
            -expr   => 1, 
            -vars   => {
                url             => $url,
                flavor_label    => $af,
                prev_link_start => $prev_link_start,
                next_link_start => $next_link_start,
            },
            -list_settings_vars       => $self->{ls}->params,
            -list_settings_vars_param => { -dot_it => 1 },

        }
    );
}




=pod

=head2 make_nav_table, 

	print $archive -> make_nav_table(-Id => $id, -List => $list_info{list}); 

this will make a HTML table that has the previous message, the index and the next message 
like this: 


<< My Previous Message    |Archive Index|      My Next Message 


=cut

sub make_nav_table {

    my $self = shift;

    my %args = (
        -List     => undef,
        -Id       => undef,
        -Function => 'visitor',
        @_
    );

    my $id = $args{-Id};

    # ?!?!?!
    my $list     = $args{-List};
    my $function = $args{-Function};
    my $flavor_label;

    if ( $function eq "admin" ) {
        $flavor_label = "view_archive";
    }
    else {
        $flavor_label = "archive";
    }

    my ( $prev, $next );
    ( $prev, $next ) = $self->get_neighbors($id);

    my $prev_subject;
    my $next_subject;

    if ($prev) {
        $prev_subject = $self->_parse_in_list_info(
            -data => $self->get_archive_subject($prev) );
    }
    if ($next) {
        $next_subject = $self->_parse_in_list_info(
            -data => $self->get_archive_subject($next) );
    }

    require DADA::Template::Widgets;
    return DADA::Template::Widgets::screen(
        {
            -screen => 'archive_nav_table_widget.tmpl',
            -list   => $list,
            -vars   => {
                prev         => $prev,
                next         => $next,
                prev_subject => $prev_subject,
                next_subject => $next_subject,
                flavor_label => $flavor_label,
            },
            -list_settings_vars       => $self->{ls}->params,
            -list_settings_vars_param => { -dot_it => 1 },

        }
    );
}





=pod

=head2 make_search_form

	print $archive -> make_search_form(); 

this prints out the correct HTML form to make for your archives. 

=cut


sub make_search_form { 
	
	my $self = shift; 
	
	# ?!?!
	my $list = shift; 
				
	require DADA::Template::Widgets; 
	return  DADA::Template::Widgets::screen(
	            {
	                -screen => 'archive_search_form.tmpl', 
					-list   => $list
			    }
			);
}



sub _neuter_confirmation_token_links { 
	my $self = shift; 
	my $body = shift; 
	
	try {
		require DADA::App::FormatMessages::Filters::RemoveTokenLinks; 
		my $rul = DADA::App::FormatMessages::Filters::RemoveTokenLinks->new; 
		$body = $rul->filter({-data => $body});
	} catch {
		carp "Problems with filter: $_";
	};
	return $body; 
	
}

sub _scrub_js { 

	my $self = shift; 
	my $body = shift; 

	try {  
		require HTML::Scrubber;
		my $scrubber = HTML::Scrubber->new(
	    	%{$DADA::Config::HTML_SCRUBBER_OPTIONS}
	    );
		$body = $scrubber->scrub($body); 
	} catch { 
		carp "Cannot use HTML::Scrubber: $_"; 
	};
	
	return $body;	
}




sub _email_protect { 
	
	my $self   = shift; 
	my $entity = shift; 
	my $body   = shift || undef; 
	
	warn "no body? " if ! $body; 
	
	# stray tags...
	$body =~ s/\[pin\]/1234/g;
	$body =~ s/\[email\]/example\@example.com/g; 
	
	# SPAM proof email addresses...
	for(
		($self->{ls}->param('list_owner_email')), 
	    ($self->{ls}->param('admin_email')),
	    ($self->{ls}->param('discussion_pop_email')),
	    
	    $entity->head->get('To',0), 
	    $entity->head->get('From',0),
	    $entity->head->get('Reply-To',0),
	    'example@example.com'
	){  
		
		next if ! $_; 

		my $look_e      = quotemeta($_);
		
		
		if($self->{ls}->param('archive_protect_email') eq 'recaptcha_mailhide'){ 
            my $protected_e = mailhide_encode($_); 

			# This isn't going to cover everything, but a lot of things: 
			my $entire_mail_link = quotemeta('<a href="mailto:'.$_.'">'.$_.'</a>'); 
 			$body                =~ s/$entire_mail_link/$protected_e/g; 
			
			
            $body =~ s/$look_e/$protected_e/g;
		}
		elsif($self->{ls}->param('archive_protect_email') eq 'spam_me_not'){ 				
            my $protected_e = spam_me_not_encode($_); 
            $body =~ s/$look_e/$protected_e/g;
   
        }
   }
   
    # strange module - API based on File::Find I guess.
	require Email::Find;
 	my $found_addresses = []; 
   
	my $finder = Email::Find->new(sub {
									my($email, $orig_email) = @_;
									push(@$found_addresses, $orig_email); 
									return $orig_email; 
								});
	$finder->find(\$body); 
	
	for my $fa (@$found_addresses){ 
			
		# https://github.com/justingit/dada-mail/issues/231
		# https://github.com/justingit/dada-mail/issues/247
		#
		# Not sure how, "cid:" turns into, "cid=" (equals sign), but it seems to do that. 
		# *really* not sure how Email::Find thinks either is a valid email address.
		# 
		if(
			$fa =~ m/\@MIME\-Lite\-HTML/
		||  $fa =~ m/cid(\=|\:)(.*?)\@/
		||  $fa =~ m/image(\d+)\.(gif|jpg|png)\@(\w+)\.(\w{5,})/i # things like: "image001.jpg@01CCD3E9.92E76260" (Microsoft Outlook 14.0)
		){ 
			# Good work Email::Find, that's not *even* an email address!
			next; 
		}
		
		if($self->{ls}->param('archive_protect_email') eq 'recaptcha_mailhide'){ 
            my $pe = mailhide_encode($fa);
            my $le = quotemeta($fa); 
            $body =~ s/$le/$pe/g;
            
		}
		elsif($self->{ls}->param('archive_protect_email') eq 'spam_me_not'){ 		
            my $pe = spam_me_not_encode($fa);
            my $le = quotemeta($fa); 
            $body =~ s/$le/$pe/g;
        }
	}
 
	
   return $body; 

}





=pod


=head2 _zap_sig_plaintext 

I<(Private Method)>

 my $msg = $self->_zap_sig_plaintext($msg); 

Given a string, $msg, returns the message without the opening or signature. 

In a PlainText message, the opening is terminated using the (Dada Mail specific): 

__ 

Which is: 

 [newline][underscore][underscore][space][newline]

The signature is begun with: 

--

Which is: 

 [newline][dash][dash][space][newline]

=cut


sub _zap_sig_plaintext { 

	my $self        = shift; 
	my $message     = shift; 
	my @msg_lines   = split(/\n/, $message);

	my $new_message = undef; 
	
	my $start       = 0; 
	
	STRIP: while ($start == 0){ 
		 for my $line(@msg_lines){
			
		 # This gets mucked up in the archive editor... 
		 $line =~ s/\r/\n/g; 
		 chomp($line); 
			if($line =~ m/^__ $/){ 
			#	die $line;
				$start = 1;
				next; 
			}
			next if ! $start; 
			last if $line =~ m/^-- $/; 
			$new_message .= "$line\n";
		}		
		# redo it if they're not using my, '__'?
		if(! $new_message){ 
			$start = 1; 
			redo STRIP; 
		}
	}
	return $new_message; 
}




=pod

=head2 _zap_sig_html

I<(Private Method)>

 $msg = $self->_zap_sig_html($msg);

Given a string $msg, returns a string that does not have the information 
located between the opening and signature comments. 

The opening comments look like this: 

 <!--opening-->
 <!--/opening-->

The signature comments look like this: 

 <!--signature-->
 <!--/signature--> 

These are both very Dada Mail-specific.

=cut

sub _zap_sig_html { 

	my $self        = shift; 
	my $message     = shift; 
	
		
	my $opening_open  = quotemeta('<!--opening-->');
	my $opening_close = quotemeta('<!--/opening-->'); 
	
	my $sig_open      = quotemeta('<!--signature-->'); 
	my $sig_close     = quotemeta('<!--/signature-->'); 
	
	
	# HACK (ish)
	# HTML isn't newline-sensitive right? 
	# This stops us from chopping off anything that's also on the same line 
	# as the opening/sig comments. Tricky. 
	
	$message =~ s/($opening_open|$opening_close|$sig_open|$sig_close)/\n$1\n/g;
	
	
	
	my @msg_lines   = split(/\n/, $message);
	my $new_message = undef; 
	
	my $switch = 1; 
	
    for my $line(@msg_lines){ 
		if($line =~ m/$opening_open/ || $line =~ m/$sig_open/){  
			$switch = 0;
			next; 
		}
		
		if($line =~ m/$opening_close/ || $line =~ m/$sig_close/){  
    		$switch = 1;
    		next;
   
    	}
    	
    	next 
    		if $switch == 0; 
    	
    	$new_message .= $line . "\n"; 
    
	}
	
	if(! $new_message){ 
		return $message;
	}else{ 
		return $new_message; 
	}
}




sub _highlight_quoted_text { 


	my $self        = shift; 
	my $message     = shift; 
	my @msg_lines   = split(/\n/, $message);
	my $new_message = undef; 
	
	for my $line(@msg_lines){
		
		my $br_at_end = 0; 
		
		chomp($line); 
		# line begins with a, ">"
		if($line =~ m/^\&gt;/){
			$line =~ s/^\&gt;//; 
			
			if($line =~ m/\<BR\>$/i){ 
				$br_at_end = 1; 
				$line =~ s/\<BR\>$//i;
			}
			
			$line = '<span class="quoted_reply">&gt;' . $line . '</span>';
			$line .= '<br />'
				if $br_at_end == 1; 
		}
		$new_message .= $line . "\n";
	
	}
	return $new_message; 
}



sub _entity_from_raw_msg { 

	my $self    = shift; 
	my $raw_msg = shift; 
	
	if( ! $self->{parser}){  
		require MIME::Parser; 
		$self->{parser} = new MIME::Parser;
		$self->{parser} = optimize_mime_parser($self->{parser}); 
	}

	my $entity; 
	eval { $entity = $self->{parser}->parse_data(
			safely_encode( 
				$raw_msg 
			)
		) };
	if($@){ 
		croak "Problems creating entity: $@"; 
	}
	
	if(!$entity){
		carp "Couldn't create an entity from this raw_msg:\n$raw_msg";
		return undef;
	}
	
	return $entity; 
}




sub _remove_opener_image { 
	my $self    = shift; 
	my $content = shift; 
	my $sm = quotemeta('<!--open_img-->'); 
	my $em = quotemeta('<!--/open_img-->'); 
	$content =~ s/($sm)(.*?)($em)//smg; 
    return $content;
}


sub attachment_list { 

	my $self = shift; 
	my $key  = shift || die "no key!"; 
	
	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($key, 1); 
	
	if(! $raw_msg){ 
		return []; 
	}
	
	my $entity      = $self->_entity_from_raw_msg($raw_msg);
	my $attachments = $self->find_attachment_list($entity, $key); 

	return $attachments; 
}




sub find_attachment_list { 

	# TODO: 
	# at the moment, Dada Mail will list all message attachments, 
	# even ones for images that are inline. 
	# it may be worth it? To not show attachments that have a cid: header in them
	# since that's a clue that the attachment is for an attached image...
	
	my $self            = shift; 
	my $entity          = shift; 
	my $id              = shift; 
	my $attachment_list = shift || []; 
	
	my @parts = $entity->parts; 
	
	if(@parts){ 
	
		my $i; 
		for $i (0 .. $#parts) {
			my $part = $parts[$i];
			$attachment_list = $self->find_attachment_list($part, $id, $attachment_list);  
		}
	}else{ 
		my $c_type = $entity->head->get('content-type');
			chomp($c_type);
			
		if($c_type =~ 'text/plain' || $c_type =~ 'text/html'){
			if($entity->head->get('content-disposition') !~ m/attach/i){ 
				# we probably hit on an actual message!
				return $attachment_list; 
			}
		}
		
		my $name = $entity->head->mime_attr("content-type.name") || 
				   $entity->head->mime_attr("content-disposition.filename");
		
		if($name){ 			
			push(@$attachment_list, {name => $name, list => $self->{name}, id => $id, PROGRAM_URL => $DADA::Config::PROGRAM_URL });
		}else{ 
			#warn "no name?!"; 
		}	
	}
	return $attachment_list; 
}




sub view_file_attachment { 
	
	my $self = shift;

	my %args = (
		-id       => undef, 
		-filename => undef, 
		-mode     => 'attachment', 
		@_, 
	); 
	
	
	my $id       = $args{-id}; 
	my $filename = $args{-filename}; 
	
	chomp($filename); 
	
	die "archive $id does not exist!"
		unless $self->check_if_entry_exists($id); 
	
	my $r; 
	
	require CGI; 
	my $q = CGI->new; 
	   $q->charset($DADA::Config::HTML_CHARSET);
	   $q = decode_cgi_obj($q);
	
	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($id, 1); 
	
	if(! $raw_msg){ 
		$r.= return $q->header('text/plain') . "can not find the attachment in question."; 
	}
	
	my $entity   = $self->_entity_from_raw_msg($raw_msg);
	
	# I don't like how this is called thrice.... but, oh well...
	my $a_entity = undef;
	
	
	$a_entity = $self->_find_filename_attachment_entity(
		-filename => $filename, 
		-entity   => $entity
	); 	
	if(! defined( $a_entity )){ 
		$filename =~ s/ /+/g;		
		$a_entity = $self->_find_filename_attachment_entity(
			-filename => $filename, 
			-entity   => $entity
		);		
	}
	# We sort of undo what we just did! 
	if(! defined( $a_entity )){ 
		$filename =~ s/\+/\%20/g;
		$a_entity = $self->_find_filename_attachment_entity(
			-filename => $filename, 
			-entity   => $entity
		);		
	}
	if(! defined( $a_entity )){ 
		return $q->header('text/plain') . 'Error: Cannot view attachment!'; 
	}
	else { 
	my $body     = $a_entity->bodyhandle;
	
	if($args{-mode} eq 'inline'){ 
		$r .= $q->header($a_entity->head->mime_type); 
	}else{ 
	
			$r .=  "Content-disposition: attachement; filename=\"$filename\"\n";
	   		$r .=  "Content-type: application/octet-stream\n\n";
	
		}
	
		# encoded. Yes or no?
		$r .=  $body->as_string; 
	
		return $r; 	
	}

}




sub _find_filename_attachment_entity { 

	my $self = shift; 
	my %args = (-filename => undef, 
				-entity   => undef, 
				@_
				); 
				
	my $entity    = $args{-entity}; 
	my $filename  = $args{-filename};


	my @parts = $entity->parts; 
	
	if(@parts){ 
			my $i; 
			for $i (0 .. $#parts) {
				my $part = $parts[$i];
				my $s_entity = $self->_find_filename_attachment_entity(
					-entity   => $part, 
					-filename => $filename
				); 
				return $s_entity 
					if $s_entity; 
			}
	}else{ 
		my $name = $entity->head->mime_attr("content-type.name") || 
			       $entity->head->mime_attr("content-disposition.filename");
	
		if($name){ 
			if($name eq $filename ){ 
				return $entity; 
			}
		}
	}
	
	# If we get here, it means we weren't able to find the attachment, sadly. 
	return undef; 
}




sub _rearrange_cid_img_tags { 

	my $self = shift; 
	my %args = (
	             -key  => undef, 
	             -body => undef, 
	             @_
	           );
	my @cids; 
	
	my $body = $args{-body}; 	
	
	my $body_copy = $body; 
	
	# that should get all the tabs on one line... 
	# A copy if made to rearrange, but we 
	# then change the original body of the message, 
	# so not to screw up EVERYTHING. 
	
	$body_copy =~ s/\r|\n//g;
	$body_copy =~ s/\>/\>\n/g;
	$body_copy =~ s/\</\n\</g;
	
	if($self->can_display_attachments){ 
		my @lines = split("\n", $body_copy); 
		for my $line(@lines){ 
			
			
			if($line =~ m/\"(cid\:(.*?))\"/){ 
				push(@cids, $1); 
			}
		}
		
	
		for my $this_cid(@cids){
		
		
			my $img_url = $DADA::Config::PROGRAM_URL . '?f=show_img&l=' . $self->{list} . '&id=' . $args{-key} . '&cid=' . $this_cid;  
	
			my $link_wo_cid = $img_url; 
			   $link_wo_cid =~ s/cid\://; 
			
				
			my $qm_this_cid = quotemeta($this_cid); 
			
			$body =~ s/$qm_this_cid/$link_wo_cid/g;
		}
		
	 	return $body; 
	 	
	}else{ 
	
		$body =~ s/\<img(.*?)(src=|src=\")(cid\:)(.*?)\>/<img$1$2$4>/g; #basically, just get rid of 'em and call it a day.
		return $body; 	
	}

}



# TODO - 
# Stress test - 
# Does this open up any weird 
# security issues?

sub view_inline_attachment { 

	my $self = shift; 
	my %args = (
	         -id  => undef, 
	         -cid => undef, 
	         @_,
	        ); 

	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($args{-id}, 1);
	
	if(! $raw_msg){ 
		return undef; 
	}
	
	my $entity = $self->_entity_from_raw_msg($raw_msg);
	
	my $body; 
	
	my $a_entity = $self->_find_inline_attachment_entity(-cid => $args{-cid}, -entity => $entity); 
	
	
	require CGI; 
	my $q = CGI->new; 
	   $q->charset($DADA::Config::HTML_CHARSET);
	   $q = decode_cgi_obj($q);
	
	my $c_type;
	
	if(!$a_entity){ 
		$c_type = 'INVALID';
	}else{ 
		$c_type = $a_entity->head->get('content-type');
		chomp($c_type); 
		$body    = $a_entity->bodyhandle;
	}
	
	require MIME::Base64; 
	
	my $r; 
	
	if($c_type =~ m/image\/gif/){ 
		$r .= $q->header('image/gif');
	}elsif($c_type =~ m/image\/jpg|image\/jpeg/){ 
		$r .= $q->header('image/jpg');
	}elsif($c_type =~ m/image\/png/){ 
		$r .= $q->header('image/png');
	}elsif($c_type =~ m/application\/octet\-stream/){ # dude, this could be anything...
		if($a_entity->head->mime_attr("content-type.name") =~ m/\.png$/i){
			$r .= $q->header('image/png'); 
		}elsif($a_entity->head->mime_attr("content-type.name") =~ m/\.jpg$|\.jpeg/i){
			$r .= $q->header('image/jpg'); 
		}elsif($a_entity->head->mime_attr("content-type.name") =~ m/\.gif$/i){
			$r .= $q->header('image/gif'); 
		}
	}else{ 
		warn "unsupported content type! " .  $c_type; 

		$r .= $q->header('image/png');
		# a simple, 1px png image. 
		my $str = <<EOF
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAABGdBTUEAANbY1E9YMgAAABl0RVh0
U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAGUExURf///wAAAFXC034AAAABdFJOUwBA
5thmAAAADElEQVR42mJgAAgwAAACAAFPbVnhAAAAAElFTkSuQmCC
EOF
;
		$r .= MIME::Base64::decode_base64($str);
		return $r; 
		
	}
	
	   #Encoded. Yes or no?
	   $r .=  $body->as_string; 
	  
	   return $r; 	
}



sub _find_inline_attachment_entity { 

	my $self = shift; 
	
	my %args = (
		-cid    => undef, 
		-entity => undef,  
	@_
	); 
	
	my $entity = $args{-entity}; 
	my $cid    = $args{-cid};
	
	my @parts = $entity->parts; 
	
	if(@parts){ 
			my $i; 
			for $i (0 .. $#parts) {
				my $part = $parts[$i];
				my $s_entity = $self->_find_inline_attachment_entity(-entity => $part, -cid => $cid); 
				return $s_entity 
					if $s_entity; 
			}
	}else{ 
		my $m_cid = $entity->head->get('content-id'); 
		   $m_cid =~ s/^\<|\>$//g;
		   $cid = quotemeta($cid); 
		   
		if($m_cid =~ m/$cid/){ 

			return $entity; 
		}else{ 
						
			return undef; 
		}
		
	}
}



=pod

=head2 massage

=cut

sub massage { 

	my $self = shift; 
	
	# Change the redirect tags

	my $s    = shift; 
	   $s    =~ s/\[redirect\=\"(.*?)\"(.*?)\]/$1/eg; 
	   $s    =~ s/\[redirect\=(.*?)\]/$1/eg; 
	   $s    =~ s/\[redirect(.*?)url\=\"(.*?)\"(.*?)\]/$2/eg; 
	   $s    =~ s/\<\?dada(.*?)redirect(.*?)url\=\"(.*?)\"(.*?)\?\>/$3/eg; 	
		
	# DEV: desensitize any current subscribe/unsubscribe urls: 
	# Still, this has the potential of breaking, if the URL is wrapped and split in multi-lines. Ugh! 
	$s =~ s{$DADA::Config::PROGRAM_URL/u/$self->{list}/(.*?)/(.*?)/}{$DADA::Config::PROGRAM_URL/u/$self->{list}/user/example.com/}g;
	$s =~ s{$DADA::Config::PROGRAM_URL/s/$self->{list}/(.*?)/(.*?)/}{$DADA::Config::PROGRAM_URL/s/$self->{list}/user/example.com/}g;
	
	return $s; 
	
}




=pod

=head2 make_search_summary

 my $summaries = $archive->make_search_summary($keyword, $search_results); 

Given a $keyword (string) and $search_results (array ref of archive keys/ids) 
will return a hashref of each line the keyword appears in. 

=cut

sub make_search_summary { 

	my $self    = shift; 
	my $keyword = shift;
	my $matches = shift;  
	
	my $message_summary; 
	my %search_summary;
	
	my $key;
	for $key(@$matches){ 
	
		my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($key);
		
		if (! $message){ 
			$message = $raw_msg;
			$message = $self->massaged_msg_for_display(
			    { 
			        -key        => $key, 
					-plain_text => 1,
				}
			);
		}else{ 
			$message = html_to_plaintext({-str => $message}); 
		}

		my @message_lines = split("\n", $message);
		my $line;
		
		for $line(@message_lines){ 
			if($line =~ m/$keyword/io){ 
				$line =~ s{$keyword}{<em class="highlighted">$keyword</em>}gi;
				$line = $self->massage($line); 
				$search_summary{$key} .= "... $line ... <br />";
			}
		} 
	}
	
	return \%search_summary;

}




=pod

=head2 _faked_oldstyle_message

I<Private Method> 

 ($new_message, $new_format) = $self->_faked_oldstyle_message($raw_msg);

B<background:>

Before version 2.9, Dada Mail did not save the complete email message, including
the headers, in its archive. Beginning with 2.9, if you're using one of the SQL 
backends, it will - but for backwards compatability, the old style, message-only
sort of method is still used. 

=cut

sub _faked_oldstyle_message { 

	my $self = shift; 
	my $raw_msg = shift; 
	
	my $entity = $self->_entity_from_raw_msg($raw_msg);
	
	if(!$entity){
		warn "Something's wrong $!"; 
		return ('', ''); 	
	}else{ 
		$entity = $self->_get_body_entity($entity); 
		
		# UnEncoded. YES. 
		return ($entity->bodyhandle->as_string, $entity->head->mime_type); 
	}
}




=pod

=head2 message_blurb

 print $archives->message_blurb(-key  => $key,
                                -size => 256, 
                               ),  

Given a key/id of an archived message, returns a plaintext snippet of 
the archived message. -size will change who large the archive blurb is. B<NOTE:> 
that this is the maximum size. If the message is smaller, the blurb will reflect 
that. 

=cut

sub message_blurb { 

	my $self = shift; 
	my %args = (-key       => undef,
			 	-size      => 525, 
			    @_); 
	
	$args{-key} = $self->newest_entry
		if !$args{-key};
		
	return undef
		if !$args{-key}; 
		
	my $msg = $self->massaged_msg_for_display(
	    {
    		-key        => $args{-key}, 
    		-plain_text => 1,
    	}	
	);
					
	# We'll want to, actually, escape out the entities - I don't know
	# why this isn't done in, massaged_msg_for_display  
	# I should... add that... 

	
	$msg =~ s/\n|\r/ /g; 
	$msg = DADA::App::Guts::encode_html_entities($msg, "\200-\377"); 
	
	my $l    = length($msg); 
	my $size = $args{-size}; 
	my $take = $l < $size ? $l : $size; 
	
	# xss_filter is one way to do this, the other is
	# going through the _scrub_js
	# xss_filter is a LOT faster, and should do the job...
	# anyways, it probably already is going through _scrub_js
	# if it's also going through: massaged_msg_for_display
	#return substr($msg, 0, $take); 
	return xss_filter(substr($msg, 0, $take));
}




=pod

=head2 massage_msg_for_resending

 print $archive->massage_msg_for_resending(-key => $entry),

given a -key - a key/id of an archived message, will return a copy of that 
archived message formatted to be resent. Basically, this means that the email 
message template has been stripped from the saved message. 

=cut

sub massage_msg_for_resending { 

	my $self = shift; 
	my %args = (-key        => undef, 
				'-split'     => 0,  
				@_); 

	my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($args{-key}, 1);

	
	if(! $raw_msg){ 
		$raw_msg = $self->_bs_raw_msg($subject, $message, $format); 
	}					
	
	
	
	my $entity = $self->_entity_from_raw_msg($raw_msg); 
	   $entity = $self->_take_off_sigs($entity); 
	
	# These may be out of date, so let's get rid of them.
	for my $header(
		'From', 
		'To', 
		'Reply-To', 
		'List', 
		'List-URL', 
		'List-Owner', 
		'List-Subscribe', 
		'List-Unsubscribe'
		){ 
	    if($entity->head->count($header)){ 
			$entity->head->delete($header);
		}
	}
		
	if($args{'-split'} == 1){ 
		# Not sure about this one - probably want it unencoded, so that we can resend it? Meh?
		
		return (
			 safely_decode($entity->head->as_string),
		   	 safely_decode($entity->body_as_string), 
		) ;
	}else{
		my $str =  safely_decode($entity->as_string);
		$str = $self->massage($str); 
		return $str; 
	}
}





=pod

=head2 _take_off_sigs

 $entity = $self->_take_off_sigs($entity); 

($entity is a MIME::Entity object)

Returns a copy of the entity without the email message template 
apply (attempts to, anyways)


=cut

sub _take_off_sigs { 

	my $self   = shift; 
	my $entity = shift; 

	my @parts = $entity->parts(); 
	if(!@parts){ 
		if(
		  ($entity->head->mime_type eq 'text/plain') || 
		  ($entity->head->mime_type eq 'text/html') ){ 
			my $body    = $entity->bodyhandle;
			my $content = $entity->bodyhandle->as_string;
			
			if($content){ 
				if($entity->head->mime_type eq 'text/html'){ 
					$content = $self->_zap_sig_html($content);
				}else{ 
					$content = $self->_zap_sig_plaintext($content);
				}
				
				require Encode; 
				my $io = $body->open('w');
				   $io->print( safely_encode( $content ) );
				   $io->close;
				$entity->sync_headers('Length'      =>  'COMPUTE',
									  'Nonstandard' =>  'ERASE');

			}
		}
		return $entity; 
	}else{ 
		my $i = 0; 
		for $i (0 .. $#parts) {
			$parts[$i] = $self->_take_off_sigs($parts[$i]);
			$entity->sync_headers('Length'      =>  'COMPUTE',
						  	      'Nonstandard' =>  'ERASE');
		}
	}
	
	return $entity; 
}




=pod

=head2 massaged_msg_for_display

 $message = $self->massaged_msg_for_display(-key => $key);

returns a string, given a -key - an id/key of an archived message. 

Can have many parameters passed to it: 

=over

=item * -plain_text

will give back a plaintext formatted message. 

=item * -body_only

Will return a message formatted in HTML, but will not be a complete HTML 
document. 

=back

=cut

sub massaged_msg_for_display {

    my $self = shift;
    my ($args) = @_;
    
    if(!exists($args->{-body_only})){ 
        $args->{-body_only} = 0;         
    } 
    if(!exists($args->{-plain_text})){ 
        $args->{-plain_text} = 0;         
    } 
    if(!exists($args->{-entity_protect})){ 
        $args->{-entity_protect} = 1;         
    } 

    my $content_type = 'text/html';

    my ( $subject, $message, $format, $raw_msg ) =
      $self->get_archive_info( $args->{-key} );

    if ( !$raw_msg ) {
        $raw_msg = $self->_bs_raw_msg( $subject, $message, $format );
    }

	# encoding is done in this method... 
    my $entity = $self->_entity_from_raw_msg(
		$raw_msg
	);
	
    if ( !$entity ) {
        carp "Couldn't create entity: " . $@;
    }

    my $body;

    my $b_entity;
    if ( $entity->parts ) {
        $b_entity = $self->_get_body_entity($entity);
    }
    else {
        $b_entity = $entity;
    }

    # text?! I dunno - set wrong?
    if (   $b_entity->head->mime_type eq 'text/plain'
        || $b_entity->head->mime_type eq 'text' )
    {

        # If you want the I<unencoded> body, and you are dealing with a
        # singlepart message (like a "text/plain"), use C<bodyhandle()> instead:

        $body = $b_entity->bodyhandle->as_string;
		$body = safely_decode($body);
		 
		
        if ( $self->{ls}->param('stop_message_at_sig') == 1 ) {
            $body = $self->_zap_sig_plaintext($body);
        }

        $body = $self->massage($body);
        $body = $self->_parse_in_list_info(
            -data => $body,
            (
                  ( $args->{-plain_text} == 1 )
                ? ( -type => 'text/plain' )
                : ( -type => 'text/html' )
            ),
        );

        if ( $args->{-plain_text} == 1 ) {

            # ...
        }
        else {
			$body = plaintext_to_html({-str => $body});
        }

        if ( $self->{ls}->param('style_quoted_archive_text') == 1 ) {
            $body = $self->_highlight_quoted_text($body)
              unless $args->{-plain_text} == 1;
        }
        $content_type = 'text/plain';

    }
    elsif ( $b_entity->head->mime_type eq 'text/html' ) {

        $body = $b_entity->bodyhandle->as_string;
		$body = safely_decode($body); 
		
        $body = $self->_rearrange_cid_img_tags(
            -key  => $args->{-key},
            -body => $body,
        );		
        if ( $self->{ls}->param('stop_message_at_sig') == 1 ) {
            $body = $self->_zap_sig_html($body);
        }

        $body = $self->massage($body);
        $body = $self->_parse_in_list_info(
            -data => $body,
            (
                  ( $args->{-plain_text} == 1 )
                ? ( -type => 'text/plain' )
                : ( -type => 'text/html' )
            ),
        );
    }
    else {
        warn "I don't know how to work with what I have! mime_type: "
          . $b_entity->head->mime_type
          . ', key: '
          . $args->{-key}
          . ', list: '
          . $self->{list_info}->{list};
    }

	$body = $self->_neuter_confirmation_token_links($body);

    $body = $self->_scrub_js($body)
      if $self->{ls}->param('disable_archive_js') == 1;

    $body = $self->_email_protect( $b_entity, $body )
      if $args->{-entity_protect};

    if ( $args->{-body_only} == 1 ) {
        $body = $self->_chomp_off_body($body);
    }
    else {
        if ( $args->{-plain_text} == 1 ) {

            # ...
        }
        else {
            $body = $self->_add_a_body_if_needed($body);
        }
    }

    if ( $args->{-plain_text} == 1 ) {
		# happens when you have a HTML body and need it back in plaintext
		# From what I can figure out, this'll only happen in the 
		# message blurbs?
        $body = $self->_chomp_out_head_styles($body);
        $body = html_to_plaintext( { -str => $body } );
		# Total hack: 
		# I don't want to double-process the $body - perhaps 
		# that won't do anything weird, but perhaps... it would? 
		my $opening = quotemeta('<!-- tmpl_var LEFT_BRACKET -->'); 
		my $closing = quotemeta('<!-- tmpl_var RIGHT_BRACKET -->');
		$body       =~ s/$opening/\[/g; 
		$body       =~ s/$closing/\]/g; 
		
    }

    return wantarray ? ( $body, $content_type ) : $body;
}


sub _parse_in_list_info { 

	my $self = shift; 
	
	my %args = (
	    -data => undef, 
		-type => undef, 
					@_,
	        ); 

    require DADA::Template::Widgets; 
    return  DADA::Template::Widgets::screen(
        {
            -data                     => \$args{-data},
			-expr => 1, 
            -vars                     => $self->{ls}->params,
            -list_settings_vars       => $self->{ls}->params,
            -list_settings_vars_param => {-dot_it => 1},
			-subscriber_vars_param    => {-list => $self->{list}, -use_fallback_vars => 1},
            -dada_pseudo_tag_filter   => 1, 

        }, 

    )
    
 }
 







sub _chomp_out_head_styles { 

	my $self  = shift; 
	my $str   = shift; 
		
	my $n_str = '';
	
	# body tags will now be on their own line, regardless.
	$str =~ s/(\<style.*?\>|<\/style\>)/\n$1\n/gi; 
	

	my @lines = split("\n", $str); 
		for (@lines){ 
			if(/\<style(.*?)\>/i .. /\<\/style\>/i)	{
				#next if /\<style(.*?)\>/i || /\<\/style\>/i;
				#$n_str .= $_ . "\n";
			}
			else { 
				$n_str .= $_ . "\n";
			}
		}
	if(!$n_str){ 
		return $str; 
	}else{ 
		return $n_str;
	}
}
=pod

=head2 _chomp_off_body

I<Private Method>

 $body = $self->_chomp_off_body($body); 

Give a string, will return the contents of the string that were found 
between HTML <body> tags. If no content was found, will return the 
entire string back, unchanged. 

=cut

sub _chomp_off_body { 
	
	my $self  = shift; 
	my $str   = shift;
	my $n_str = $str;
	
	# code below replaces code above - any problems?
	# yeah, it doesn't fucking work.
	
	if($n_str =~ m/\<body.*?\>|<\/body\>/i){ 

		$n_str =~ m/\<body.*?\>([\s\S]*?)\<\/body\>/i;  
		$n_str = $1; 
		
		if($n_str =~ m/\<body.*?\>|<\/body\>/i){ 
			$n_str = $self->_chomp_off_body_thats_being_difficult($n_str); 		
		}		
	}
		
	if(!$n_str){
		
		return $str; 
	}else{ 
		return $n_str;
	}
}




 # yeah, the title's a joke. I'm bitter right now :) 
sub _chomp_off_body_thats_being_difficult { 

	my $self  = shift; 
	my $str   = shift; 
	my $n_str = '';
	
	# body tags will now be on their own line, regardless.
	$str =~ s/(\<body.*?\>|<\/body\>)/\n$1\n/gi; 
	

	my @lines = split("\n", $str); 
		for (@lines){ 
			if(/\<body(.*?)\>/i .. /\<\/body\>/i)	{
				next if /\<body(.*?)\>/i || /\<\/body\>/i;
				$n_str .= $_ . "\n";
			}
		}
	if(!$n_str){ 
		return $str; 
	}else{ 
		return $n_str;
	}
}



=pod $body = $self->_add_a_body_if_needed($body)

=head2 _add_a_body_if_needed

I<Private Method>

 $body = $self->_add_a_body_if_needed($body)

Given a string, looks if the string is a complete HTML document, and, if 
it's not, wraps one around it. 

Used for showing archived messages. 

=cut

sub _add_a_body_if_needed { 

	my $self = shift; 
	my $body = shift; 
	
	if ($body =~ m/\<body(.*?)\>/i){  
		my $base_tag = '<base target="_parent" />';
		$body =~ s/<\/head>/$base_tag \n <\/head>/g;
		return $body
		
	}else{ 
	
		require DADA::Template::Widgets; 
		return  DADA::Template::Widgets::screen(
		            {
		                -screen => 'iframed_archive_screen.tmpl', 
						-vars   => {
                                    body => $body, 
                                   }, 
                            }
                        ); 
	}
}




=pod

=head2 _get_body_entity

I<Private Methid>

 $entity = $self->_get_body_entity($entity); 

Given an entity, attempts to find the main message - will default to HTML for
multipart/alternative messages. 

=cut

sub _get_body_entity { 

	my $self   = shift; 
	my $entity = shift; 

	my @parts = $entity->parts; 
	
	if(@parts){ 
	    # This list is sort of stupid, since it's not all inclusive - there's bound to be a multipart type
	    # that's not in here...
		if (
		    ($entity->head->mime_type eq 'multipart/mixed') 	  ||
		    ($entity->head->mime_type eq 'multipart/alternative') ||
		    ($entity->head->mime_type eq 'multipart/related')     ||
		    ($entity->head->mime_type eq 'multipart/signed')          # Apple .Mac accounts, S/MIME
		    ){ 
		   
			# shortcut
			# multipart/alternative - give back the HTML version. 
			if(($#parts == 1) && ($entity->head->mime_type eq 'multipart/alternative')){ 
				if(($parts[0]->head->mime_type eq 'text/plain') && ($parts[1]->head->mime_type eq 'text/html')){ 
					return $parts[1];
				}elsif(($parts[0]->head->mime_type eq 'text/plain') && ($parts[1]->head->mime_type eq 'multipart/related')){ 
					my @deep_entities = $parts[1]->parts; 
					if($deep_entities[0]->head->mime_type eq 'text/html'){ 
						return $deep_entities[0]; 
					}
				}
			}
			
			my $i; 
			for $i (0 .. $#parts) {
				my $s_entity = $self->_get_body_entity($parts[$i]); 
				return $s_entity if $s_entity; 
			}
			
		}else{ 
			warn "nothing we can use here? " . $entity->head->mime_type;
		}
	}else{ 
		# singlepart. 
		if(($entity->head->mime_type eq 'text/html') || ($entity->head->mime_type eq 'text/plain')){ 
			#ha! done. 
				return $entity; 
		} 
	}
}




=pod

=head2 _bs_raw_msg

 $raw_msg = $self->_bs_raw_msg($subject, $message, $format); 

Tries to munge a complete MIME-compliant message, given a Subject, the body 
of a message and a format (text/plain, text/html)

=cut

sub _bs_raw_msg { 

	my $self = shift; 
	my ($subject, $message, $format) = @_; 
	
	require MIME::Lite; 

	if(!$message){ 
		warn "message is blank!?"; 
		$message .= " "; 
	}
	
	# look, if we have to bs this thing, the only thing that'll work would be text/plain, or text/html, anything else,
	# will screw us up!
	
	#unless($format =~ m/text|plain|html/i){ 
	#	$format = 'text/plain';
	#}
	#
	#if($format =~ m/html/i){ 
	#	$format = 'text/html'; 
	#}
	
	# The above caused an edge case, if the format was something odd - like, 
	#perhaps some weird corruption in the db. This'll just say, "hey, anything 
	#that doesn't look like HTML is plain text. This'll also stop errors from 
	# cropping up; 
	
	if($format =~ m/html/i){ 
		$format = 'text/html'; 
	}
	else { 
		$format = 'text/plain'; 	
	}
	
	my $msg = MIME::Lite->new(
	Subject   => $subject, 
	Type      => $format, 
	# This should be this way, or the reverse?
	#Data      => Encode::encode($DADA::Config::HTML_CHARSET, $message), 
#	Data      => $message, 
	Data      => safely_encode($message), 
	Datestamp => 0, 
	);
	#
	#return $msg->as_string;
	return safely_decode($msg->as_string); 
}





=pod

=head2 W3CDTF

 print $self->W3CDTF($key); 

Given a key/id of an archived message, which is created from the date the message 
was sent, returns a string in the W3CDTF format.

More information: 

http://www.w3.org/TR/NOTE-datetime

This is used for the Atom Feed. 

=cut

sub W3CDTF {

	my $self     = shift; 
	#2005 04 24 01 18 39
	my $raw_date = shift; 
	   $raw_date = $self->_massaged_key($raw_date); 
	
	my $year   = substr($raw_date, 0,  4); 
	my $month  = substr($raw_date, 4,  2); 
	my $day    = substr($raw_date, 6,  2); 
	my $hour   = substr($raw_date, 8,  2); 
	my $minute = substr($raw_date, 10, 2); 
	my $second = substr($raw_date, 12, 2); 

	return $year . '-' . $month . '-' . $day . 'T' . $hour . ':' . $minute . ':' . $second . 'Z'; 
	

}

sub _generate_now_w3cdtf {

	my $self = shift; 
	
	# stole this from XML::Atom::SimpleFeed
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) = gmtime;
    $year += 1900;
    $mon++;
    my $timestring = sprintf( "%4d-%02d-%02dT%02d:%02d:%02dZ",
        $year, $mon, $mday, $hour, $min, $sec );
    return ($timestring);
}



sub _generate_atom_entry_id {

    # Generate a UUID for a feed based on Mark Pilgrim's method at
    # http://diveintomark.org/archives/2004/05/28/howto-atom-id 
	
    my ( $self, $link, $modified ) = @_;

    $link =~ s#^.*?://(.*)#$1#;
    $link =~ s|#|/|g;

    $modified =~ /^(\d+-\d+-\d+)/;
    my $datestring = $1;

    $link =~ s#^(.*?)/(.*)$#tag:$1,$datestring:/$2#;
    $link =~ s#/#%2F#g;

    return ($link);
}





sub RFC822date  {

  my $self = shift; 
  
  my $raw_date = shift;
  
  my $year   = substr($raw_date, 0,  4); 
     $year   = $year - 1900; 
     
  my $month  = substr($raw_date, 4,  2); 
     $month  = int($month) - 1; 
 
  my $day    = substr($raw_date, 6,  2); 
  my $hour   = substr($raw_date, 8,  2); 
  my $minute = substr($raw_date, 10, 2); 
  my $second = substr($raw_date, 12, 2); 
	
  require Time::Local; 
  
  my $unixtime = Time::Local::timelocal($second,$minute,$hour,$day,$month,$year);
  
  my $c_time = gmtime($unixtime);

  my($dw,$mo,$da,$ti,$yr) = 
      ( $c_time =~ /(\w{3}) +(\w{3}) +(\d{1,2}) +(\d{2}:\d{2}):\d{2} +(\d{4})$/ );
  $da = sprintf("%02d", $da);
  
  return $dw.", ".$da." ".$mo." ".$yr." ".$ti.":00 GMT";

}


=pod

=head2 atom_index

 print $archive->atom_index();

returns a string representing the Atom Feed. More on Atom: 

http://www.atomenabled.org/

See Also: 

http://search.cpan.org/~minter/XML-Atom-SimpleFeed-0.5/lib/XML/Atom/SimpleFeed.pm

=cut

sub atom_index { 

	my $self = shift; 


    require HTML::Entities::Numbered; 
    
	my $atom_entries = [];
	   	
	my $entries = $self->get_archive_entries();
	my $amount  = $self->{ls}->param('archive_index_count') || 0; 
       $amount  = $#$entries if $#$entries < $amount; 
	my $i = 0;
	
	require DADA::Template::Widgets; 

	my $feed_subscription_form; 
	
	if($self->{ls}->param('add_subscribe_form_to_feeds')){ 

		$feed_subscription_form = DADA::Template::Widgets::subscription_form({-list => $self->{list}});
			
		$feed_subscription_form =~ s/&/\&amp;/g;  
		$feed_subscription_form =~ s/>/\&gt;/g;
		$feed_subscription_form =~ s/</\&lt;/g;	  				
		$feed_subscription_form =~ s/\"/\&quot;/g;	
		
											   
	}else{ 
		$feed_subscription_form = ''; 
	}
	
	for($i = 0; $i <= $amount; $i++){ 

		my ($subject, $message, $format) = $self->get_archive_info($entries->[$i]);
		
		$message = $self->massaged_msg_for_display(
		    { 
		        -key       => $entries->[$i], 
				-body_only => 1,
			}
		);
        
        $message = HTML::Entities::Numbered::name2decimal($message); 
        
	#	my $feed_subscription_form = 'foo'; 
		
		# These are very weird things (there's probably many more...): 
		$message =~ s/\&eacute;/\&#233;/g; 

		$message =~ s/&/\&amp;/g;  
		$message =~ s/>/\&gt;/g;
		$message =~ s/</\&lt;/g;	  				
		$message =~ s/\"/\&quot;/g;	
		
		
        $subject = $self->_parse_in_list_info(-data => $subject);
		$subject =~ s/&/\&amp;/g;  
		$subject =~ s/>/\&gt;/g;
		$subject =~ s/</\&lt;/g;	  				
		$subject =~ s/\"/\&quot;/g;	
	    $subject = HTML::Entities::Numbered::name2decimal($subject); 
		
	
		my $link = $DADA::Config::PROGRAM_URL .'/archive/'.$self->{list} . '/' .$entries->[$i] . '/'; 

		my $atom_id = $self->_generate_atom_entry_id($link, $self->W3CDTF($entries->[$i])); 
		push(@$atom_entries,
		
			{
		
			atom_id   => $atom_id, 
			subject   => $subject, 
			'link'    => $link, 
			updated   => $self->W3CDTF($entries->[$i]),
			summary   => $self->message_blurb(-key => $entries->[$i]),
			message   => $message, 
			feed_subscription_form => $feed_subscription_form, 
			
		    }
		    ); 


	}
	
	
	
	return  DADA::Template::Widgets::screen({-screen => 'atom-1_0.tmpl',  
											-vars   => { 
											             title                    => $self->{ls}->param('list_name'),
														 list                     => $self->{list}, 
														 list_name                => $self->{ls}->param('list_name'),
														 list_owner_email         => $self->{ls}->param('list_owner_email'),
														 list_owner_email_encoded => spam_me_not_encode($self->{ls}->param('list_owner_email')), 
														 description              => $self->{ls}->param('info'),
														 'link'                   => $DADA::Config::PROGRAM_URL.'/list/'.$self->{list} . '/',														 
														 now                      => $self->_generate_now_w3cdtf,  
														 atom_entries             => $atom_entries,
													   },
										   });	
}




=pod

=head2 rss_index

 print $archive->rss_index();

returns a string representing the Rss Feed. More on Atom: 

=cut


sub rss_index { 

	my $self = shift; 
	
    require HTML::Entities::Numbered;
     
	my $rss_entries = [];
	   	
	my $entries = $self->get_archive_entries();
	my $amount  = $self->{ls}->param('archive_index_count') || 0; 
       $amount  = $#$entries if $#$entries < $amount; 
	
	my $description = $self->{ls}->param('info'); 
	   $description =~ s/&/\&amp;/g;  
	   $description =~ s/>/\&gt;/g;
	   $description =~ s/</\&lt;/g;	  				
	   $description =~ s/\"/\&quot;/g;	
	   #$description = HTML::Entities::Numbered::name2decimal($description); 

	   

	my $feed_subscription_form; 
	
	require DADA::Template::Widgets; 


	if($self->{ls}->param('add_subscribe_form_to_feeds')){ 

        $feed_subscription_form = DADA::Template::Widgets::subscription_form({-list => $self->{list}});    
		$feed_subscription_form =~ s/&/\&amp;/g;  
		$feed_subscription_form =~ s/>/\&gt;/g;
		$feed_subscription_form =~ s/</\&lt;/g;	  				
		$feed_subscription_form =~ s/\"/\&quot;/g;	
		
											   
	}else{ 
		$feed_subscription_form = ''; 
	}



	my $i = 0;
	for($i = 0; $i <= $amount; $i++){ 
		
		my ($subject, $message, $format, $raw_msg) = $self->get_archive_info($entries->[$i]);
		
			$message = $self->massaged_msg_for_display(
			    {
			        -key       => $entries->[$i], 
					-body_only => 1
				}
			);	
			   
			$message =~ s/&/\&amp;/g;  
			$message =~ s/>/\&gt;/g;
			$message =~ s/</\&lt;/g;	  				
			$message =~ s/\"/\&quot;/g;	
		    $message = HTML::Entities::Numbered::name2decimal($message); 

            $subject = $self->_parse_in_list_info(-data => $subject);        
			$subject =~ s/&/\&amp;/g;  
			$subject =~ s/>/\&gt;/g;
			$subject =~ s/</\&lt;/g;	  				

			$subject =~ s/\"/\&quot;/g;	
			
			
		    $subject = HTML::Entities::Numbered::name2decimal($subject); 



		my $link        = $DADA::Config::PROGRAM_URL .'/archive/'.$self->{list} . '/' .$entries->[$i] . '/';
		my $description = $self->message_blurb(-key => $entries->[$i]); 
		my $pub_date    = $self->RFC822date($entries->[$i]); 
		
		push(@$rss_entries, {
			entry_title       => $subject, 
			entry_link        => $link, 
			entry_description => $message, 
			pub_date          => $pub_date,
			feed_subscription_form => $feed_subscription_form, 
			
		}); 
	
	}	
		return  DADA::Template::Widgets::screen({-screen => 'rss-2_0.tmpl',  
												-vars   => { title          => $self->{ls}->param('list_name'),,
												             description    => $description,
												             'link'         => $DADA::Config::PROGRAM_URL.'/list/'.$self->{list} . '/',
												             lastBuildDate  => $self->RFC822date(DADA::App::Guts::message_id()), 
												             
												             rss_entries    => $rss_entries,
												           },
											   });
}




=pod

=head2 send_pings

 $self->send_pings();

Sends a notice to updating services, telling them that they should check out the 
new Syndication Feeds. More information: 

http://www.xmlrpc.com/weblogsCom

=cut

sub send_pings {

	my $self = shift; 
	
	if($self->{ls}->param('show_archives')        && 
	   $self->{ls}->param('publish_archives_rss') && 
	   $self->{ls}->param('ping_archives_rss')
	  ){ 
	
		eval { require XMLRPC::Lite };
		if(! $@ ) { 
			return map {
				eval { XMLRPC::Lite->proxy($_, timeout => 5)
				->call('weblogUpdates.ping', $self->{ls}->param('list_name') , $DADA::Config::PROGRAM_URL . '/list/' . $self->{list} . '/')
				->result };
			warn "$DADA::Config::PROGRAM_NAME Warning: problems pinging $_ : $!" if $@; 
			} @DADA::Config::PING_URLS ;
		}	
	}	
}




=pod

=head2 _massaged_key

I<Private Method> 

Attempts to cleanse a key given to this object that contains weird things. Usually used to massage
the id created from the Message-ID header of a email message. 

=cut

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




sub _decode_header { 
	my $self       = shift; 	 
	my $header     = shift;
	my $new_header = undef; 
	
	if($self->{ls}->param('mime_encode_words_in_headers') == 1){ 
		eval{ 
			require MIME::EncWords;
		};
#
		if($@){ 
			carp "MIME::EncWords is returning with an error: $@"; 		
			return $header;
		}
		else  {


			#if($header eq MIME::EncWords::decode_mimewords($header)){ 
				# No? Well, nothing to do; 
				#...
			#}
			#else { 
				# Yes? Let's decode!
				$new_header = MIME::EncWords::decode_mimewords($header, Charset => '_UNICODE_'); 
				return $new_header;
		}
		
	}
	else { 
		return $header; 
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
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 

