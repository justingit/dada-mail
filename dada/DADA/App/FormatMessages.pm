package DADA::App::FormatMessages;

use strict;
use lib qw(
  ../../
  ../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);

use Encode qw(encode decode);
use MIME::Parser;
use MIME::Entity;
use DADA::App::Guts;
use Try::Tiny;
use Carp qw(croak carp);

# $Carp::Verbose = 1;
use vars qw($AUTOLOAD);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_FormatMessages};

=pod

=head1 NAME

DADA::App::FormatMessages

=head1 SYNOPSIS

 my $fm = DADA::App::FormatMessages->new(-List => $list); 
 
 # The subject of the message is...  
   $fm->Subject('This is the subject!'); 
   
 # Use information you find in the headers 
  $fm->use_header_info(1);

 # Use the email template.
   $fm->use_email_templates(1);  
 
 my ($header_str, $body_str) = $fm->format_headers_and_body({-entity => $entity});
 
 # (... later on... 
 
 use DADA::MAilingList::Settings; 
 use DADA::Mail::Send; 
 
 my $ls = DADA::MailingList::Settings->new({-list => $list}); 
 my $mh = DADA::Mail::Send->new({-list => $list}); 
 
 $mh->send(
           $mh->return_headers($header_str), 
		   Body => $body_str,
		  ); 

=head1 DESCRIPTION

DADA::App::FormatMessages is used to get a email message ready for sending to your 
mailing list. Most of its magic is behind the scenes, and isn't something you have
to worry about, but we'll go through some detail. 

=head1 METHODS

=cut

my %allowed = (
    Subject                      => undef,
    use_html_email_template      => 1,
    use_plaintext_email_template => 1,
    use_header_info              => 0,

    #orig_entity                   => undef,

    originating_message_url => undef,

    reset_from_header   => 1,
    mass_mailing        => 0,
    list_type           => 'list',
    no_list             => 0,

    override_validation_type => undef,
);

# list_type: # list, invitelist, just_subscribed, just_unsubscribed...

=pod

=head2 new

 my $fm = DADA::App::FormatMessages->new(-List => $list); 


=cut

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my %args = (
        -List         => undef,
        -yeah_no_list => 0,
        @_
    );

    if ( !exists( $args{-List} ) && $args{-yeah_no_list} == 0 ) {

        die "no list!" if !$args{-List};
    }

    $self->_init( \%args );
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    return if ( substr( $AUTOLOAD, -7 ) eq 'DESTROY' );

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

    my $parser = new MIME::Parser;
    $parser = optimize_mime_parser($parser);

    $self->{parser} = $parser;
    $self->{ls}     = undef;
    $self->{list}   = undef;

    if ( exists( $args->{-List} ) && $args->{-yeah_no_list} == 0 ) {
        if ( exists( $args->{-ls_obj} ) ) {
            $self->{ls} = $args->{-ls_obj};
        }
        else {

            require DADA::MailingList::Settings;
            my $ls = DADA::MailingList::Settings->new(
                {
                    -list => $args->{-List}
                }
            );

            $self->{ls} = $ls;
        }

        $self->{list} = $args->{-List};

        $self->Subject( $self->{ls}->param('list_name') );
    }
    else {
        $self->no_list(1);
    }

    $self->use_email_templates(1);

}

sub use_email_templates {

    my $self = shift;
    my $v    = shift;

    if ( $v == 1 || $v == 0 ) {

        $self->use_html_email_template($v);
        $self->use_plaintext_email_template($v);
        $self->{use_email_templates} = $v;

        return $self->{use_email_templates};

    }
    else {
        return $self->{use_email_templates};
    }

}

sub format_message {

    my $self = shift;

    my ($args) = @_;

    if ( exists( $args->{-msg} ) ) {

        # warn 'args -msg';
        my ( $h, $b ) = $self->format_headers_and_body($args);
        return $h . "\n" . $b;
    }
    elsif ( exists( $args->{-entity} ) ) {

        # warn 'args -entity';
        return $self->format_headers_and_body($args);
    }
    else {
        die "you must pass either a -msg or an -entity";
    }
}

=pod

=head2 format_headers_and_body

 my ($header_str, $body_str) = $fm->format_headers_and_body(-msg => $msg);

Given a string, $msg, returns two variables; $header_str, which will have all 
the headers and $body_str, that holds the body of your message. 

=head1 ACCESSORS

=head2 Subject

Set the subject of a message

=head2 use_email_templates

If set to a true value, will apply your email templates to the HTML/PlainText parts 
of your message. 

=head2 use_header_info

If set to a true value, will inspect the headers of a message (for example, the From: line) 
to work with

=cut

sub format_headers_and_body {

    my $self = shift;

    my ($args) = @_;

    my $entity;

    if ( exists( $args->{-msg} ) ) {
        $entity = $self->{parser}->parse_data( safely_encode( $args->{-msg} ) );
    }
    elsif ( exists( $args->{-entity} ) ) {
        $entity = $args->{-entity};
    }
    else {
        die "you must pass either a -msg or an -entity";
    }
	
	# This is a bugfix to bad MIME creators, 
	# to stop horrible things from happening: 
	# "type" should not be an attribute in "Content-Type"
	if($entity->head->mime_type eq 'multipart/related'){ 
		if($entity->head->mime_attr("Content-Type.type") eq "text/html"){ 
			$entity->head->mime_attr("Content-Type.type" => undef);
		}
	}
	
	
	

    if ( !exists( $args->{-format_body} ) ) {
        $args->{-format_body} = 1;
    }
    if ( $args->{-convert_charset} == 1 ) {
        try {
            $entity = $self->change_charset( { -entity => $entity } );
        }
        catch {
            carp "changing charset didn't work!: $_";
        };
    }

    if ( $entity->head->get( 'Subject', 0 ) ) {
        $self->Subject( $entity->head->get( 'Subject', 0 ) );
    }
    else {
        if ( $self->Subject ) {
            $entity->head->add(
				 'Subject', 
				 $self->_encode_header(
				 	'Subject', 
					$self->Subject
				) 
			);
        }
    }

    $entity = $self->_format_headers($entity);    #  Bridge stuff.

    if ( defined( $self->{list} ) ) {
        $entity = $self->_make_multipart_alternative($entity);
    }
    if ( $args->{-format_body} == 1 ) {
        $entity = $self->_format_body(
            $entity,
            {
                -format_mlm => $args->{-format_mlm}
            }
        );
    }

    # yeah, don't know why you have to do it
    # RIGHT BEFORE you make it a string...
    $entity->head->delete('X-Mailer')
      if $entity->head->get( 'X-Mailer', 0 );

    # or how about, count?

    if ( exists( $args->{-entity} ) ) {
        return $entity;
    }
    elsif ( exists( $args->{-msg} ) ) {

        my $has = $entity->head->as_string;
        my $bas = $entity->body_as_string;
        $entity->purge;
        undef($entity);
        return ( safely_decode($has), safely_decode($bas) );
    }
    else {
        return undef;
    }

}

sub format_phrase_address {

    my $self    = shift;
    my $phrase  = shift;
    my $address = shift;

    $phrase =~ s/\@/\\\@/g;
    require Email::Address;
    return Email::Address->new( $phrase, $address )->format;

}

sub format_mlm {

    my $self = shift;
    my ($args) = shift;

	 
    if ( !exists( $args->{-content} ) ) {
        warn 'Please pass -content with the content of your message.';
        return undef;
    }
    my $content = $args->{-content};

    if ( !exists( $args->{-type} ) ) {
        $args->{-type} = 'text/html';
    }
    my $type = $args->{-type};

    if ( !exists( $args->{-rel_to_abs_options} ) ) {
        $args->{-rel_to_abs_options} = { enabled => 0, };
    }

    if ( !exists( $args->{-crop_html_options} ) ) {
        $args->{-crop_html_options} = { enabled => 0, };
    }

    if ( $type eq 'text/html' ) {

        # Relative to Absolute URL links:
        if ( $args->{-rel_to_abs_options}->{enabled} == 1 ) {
            $content =
              $self->rel_to_abs( $content, $args->{-rel_to_abs_options}->{base},
              );
        }

        # Crop HTML:
        if ( $args->{-crop_html_options}->{enabled} == 1 ) {
            $content = $self->crop_html(
                {
                    %{
                        -html => $content,
                        $args->{-crop_html_options},
                    },
                }
            );
        }


		unless ($self->layout_choice($args) eq 'none') {
	        # Body Content Only:
			
			$content = $self->body_content_only($content); 
			
		}
			
		
		unless ($self->layout_choice($args) eq 'none') {
	        try {
	            require DADA::App::FormatMessages::Filters::InjectThemeStylesheet;
	            my $its =
	              DADA::App::FormatMessages::Filters::InjectThemeStylesheet->new;
	            $content = $its->filter( 
					{ 
						-html_msg => $content, 
						-list     => $self->{list}, 
					} 
				);
	        }
	        catch {
	            carp 'Problems with filter:' . $_ if 
					$t;
	        };
		}
		
		# CSS Inlining
        try {
            require DADA::App::FormatMessages::Filters::CSSInliner;
            my $css_inliner =
              DADA::App::FormatMessages::Filters::CSSInliner->new;
            $content = $css_inliner->filter( { -html_msg => $content } );
        }
        catch {
            carp 'Problems with filter:' . $_ if 
				$t;
        };

        # Change inlined images into separate files we'll link
        # (and hopefully embed later down the chain)
        if (   $DADA::Config::FILE_BROWSER_OPTIONS->{kcfinder}->{enabled} == 1
            || $DADA::Config::FILE_BROWSER_OPTIONS->{core5_filemanager}
            ->{enabled} == 1 )
        {
            try {
                require
                  DADA::App::FormatMessages::Filters::InlineEmbeddedImages;
                my $iei =
                  DADA::App::FormatMessages::Filters::InlineEmbeddedImages->new;
                $content = $iei->filter( { -html_msg => $content } );
            }
            catch {
	            carp 'Problems with filter:' . $_ if 
					$t;
            };
        }

        # Unmuck template tags
        try {
            require DADA::App::FormatMessages::Filters::UnescapeTemplateTags;
            my $utt =
              DADA::App::FormatMessages::Filters::UnescapeTemplateTags->new;
            $content = $utt->filter( { -html_msg => $content } );
        } catch {
            carp 'Problems with filter:' . $_ if 
				$t;
        };
		
		
    }

    # This means, we've got a discussion list:
    if (   $self->no_list != 1
        && $self->mass_mailing == 1
        && $self->list_type eq 'list'
        && $self->{ls}->param('disable_discussion_sending') != 1
        && $self->{ls}->param('group_list') == 1 )
    {
        if ( $type eq 'text/html' ) {
            try {
                $content = $self->_remove_opener_image( { -data => $content } );
            }
            catch {
                carp "Problem removing existing opener images: $_";
            };
        }

        # This attempts to strip any unsubscription links in messages
        # (think: replying)
        try {
            require DADA::App::FormatMessages::Filters::RemoveTokenLinks;
            my $rul = DADA::App::FormatMessages::Filters::RemoveTokenLinks->new;
            $content = $rul->filter( { -data => $content } );
        }
        catch {
            carp 'Problems with filter:' . $_ if 
				$t;
        };

        # I am doing this, twice?
        try {
            require DADA::App::FormatMessages::Filters::UnescapeTemplateTags;
            my $utt =
              DADA::App::FormatMessages::Filters::UnescapeTemplateTags->new;
            $content = $utt->filter( { -html_msg => $content } );
        }
        catch {
            carp 'Problems with filter:' . $_ if 
				$t;
        };

        if ( $self->{ls}->param('discussion_template_defang') == 1 ) {
            try {
                $content = $self->template_defang( { -data => $content } );
            }
            catch {
                carp "Problem defanging template: $_" 
					if $t;
            };
        }

    }    #/ discussion lists
         # End filtering done before the template is applied

    # Apply our own mailing list template:
    $content = $self->_apply_template(
		{
	        -content => $content,
	        -type => $type,
			-layout => $args->{-layout},
		}
	);

    # Begin filtering done after the template is applied
    if ( $self->mass_mailing == 1 ) {
        if ( $self->list_type eq 'just_unsubscribed' ) {

            # ... well, nothing, really.
        }
        elsif ( $self->list_type eq 'invitelist' ) {
            $content =
              $self->subscription_confirmationation( { -str => $content, } );
        }
        else {
            $content = $self->unsubscriptionation(
                {
                    -str  => $content,
                    -type => $type,
                }
            );
        }
    }
	
    if ( $self->no_list != 1 ) {
        $content = $self->_expand_macro_tags(
            -data => $content,
            -type => $type,
        );		
    }

		
	if($type eq 'text/html') { 
		# Minify
		warn 'minifying'
			if $t;
	    try {
	        require DADA::App::FormatMessages::Filters::HTMLMinifier;
	        my $minifier =
	          DADA::App::FormatMessages::Filters::HTMLMinifier->new;
	        $content = $minifier->filter( { -html_msg => $content } );
	    } catch {
            carp 'Problems with filter:' . $_ if 
				$t;
	    };	
	}	
	
	
	
    # End filtering done after the template is applied

    # simple validation
    require DADA::Template::Widgets;
    my ( $valid, $errors );

    my $expr = 0;
    if ( $self->no_list == 1 ) {
        $expr = 1;
    }
    elsif ( $self->override_validation_type eq 'expr' ) {
        $expr = 1;
    }
    else {
        $expr = $self->{ls}->param('enable_email_template_expr');
    }

    ( $valid, $errors ) = DADA::Template::Widgets::validate_screen(
        {
            -data => \$content,
        }
    );
    if ( $valid == 0 ) {
        my $munge = quotemeta('/fake/path/for/non/file/template');
        $errors =~ s/$munge/line/;
        croak
          "Problems with email message! Invalid template markup: '$errors' \n"
          . '-' x 72 . "\n"
          . $content;
    }

    return $content;

}

sub rel_to_abs {

    require URI::URL;
    require URI::Find;
    require HTML::LinkExtor;

    my $self = shift;
    my $str  = shift;
    my $base = shift || undef;
	
	return $str if ! defined $base; 
	return $str if length($base <= 0) ;

    my $parsed = $str;

    my @links_to_look_at = ();

    # There's a way to do differnt things, based on the tag you get...
    my $callback = sub {
        my ( $tag, %attr ) = @_;

        return
          unless $tag eq 'a' || $tag eq 'area' || $tag eq 'img';

        my $link;
        if ( $tag eq 'a' || $tag eq 'area' ) {
            $link = $attr{href};
        }
        elsif ( $tag eq 'img' ) {
            $link = $attr{src};
        }

        if ( $link =~ m/^mailto\:/ ) {
            warn "Skipping mailto: links"
              if $t;
        }
        elsif ( $link =~ m/(^(\<\!\-\-|\[|\<\?))|((\]|\-\-\>|\?\>)$)/ ) {
            warn '$link looks to contain tags? skipping.'
              if $t;
        }
        else {
            warn 'pushing: ' . $link 
				if $t;
            push( @links_to_look_at, $link );
        }

        if ( $link =~ m/\&/ ) {

            # There's some weird stuff happening in HTML::LinkExtor,
            # Which will change, "&amps;" back to, "&", probably due to
            # A well-reasoned... reason. But it still breaks shit.
            # So I look for both:

            my $ampersand_link = $link;
            $ampersand_link =~ s/\&/\&amp;/g;
            push( @links_to_look_at, $ampersand_link );

        }
    };

    my $p = HTML::LinkExtor->new($callback);
    $p->parse($str);
    undef $p;

    if ($t) {
        require Data::Dumper;
        warn 'Links Found:' . Data::Dumper::Dumper( [@links_to_look_at] );
    }

    foreach my $rel (@links_to_look_at) {
		
		next if $rel eq ''; 
		next if length($rel) <= 0; 
		
        warn '$rel: "' . $rel . '"'
          if $t;

        my $abs_link = URI::URL->new($rel)->abs( $base, 1 )->as_string;
        warn '$abs_link: ' . $abs_link
          if $t;

        my $qm_link = quotemeta($rel);

        warn '$qm_link: "' . $qm_link . '"'
          if $t;

# This line is suspect - it only works with double quotes, ONLY looks at the first (?)
# double quote and doesn't use any sort of API from HTML::LinkExtor.
#
# Also see that we don't get rid of dupes in @links_to_look_at, and this regex is not global.
# If you do one do the other,

		if($abs_link ne $rel){
	        #if($tag eq 'a' || $tag eq 'area'){
	        $parsed =~ s/(href(\s*)\=(\s*)(\"?|\'?))$qm_link/$1$abs_link/;

	        #}elsif($tag eq 'img'){
	        $parsed =~ s/(src(\s*)\=(\s*)(\"?|\'?))$qm_link/$1$abs_link/;

	        #}
		}
    }

    @links_to_look_at = ();

    return $parsed;
}

sub crop_html {

    my $self   = shift;
    my ($args) = @_;
    my $html   = $args->{-html};

    try {
        require HTML::Tree;
        require HTML::Element;
        require HTML::TreeBuilder;

        my $root = HTML::TreeBuilder->new(
            ignore_unknown      => 0,
            no_space_compacting => 1,
            store_comments      => 1,
        );

        $root->parse($html);
        $root->eof();
        $root->elementify();
        my $replace_tag = undef;
        my $crop        = undef;

        if ( $args->{crop_html_content_selector_type} eq 'id' ) {
            if (
                $replace_tag = $root->look_down(
                    "id", $args->{crop_html_content_selector_label}
                )
              )
            {
                $crop = $replace_tag->as_HTML( undef, '  ' );
            }
            else {
                warn 'cannot crop html: '
                  . 'cannot find id, '
                  . $args->{crop_html_content_selector_label}
				  	if $t;
                return $html;
            }
        }
        elsif ( $args->{crop_html_content_selector_type} eq 'class' ) {
            if (
                $replace_tag = $root->look_down(
                    "class", $args->{crop_html_content_selector_label}
                )
              )
            {
                $crop = $replace_tag->as_HTML( undef, '  ' );
            }
            else {
                warn 'cannot crop html: '
                  . 'cannot find class, '
                  . $args->{crop_html_content_selector_label}
				  	if $t;
                return $html;
            }
        }

        my $body_tag = $root->find_by_tag_name('body');
        $body_tag->delete_content();
        $body_tag->push_content(
            HTML::Element->new(
                '~literal', 'text' => $crop,
            )
        );
        return $root->as_HTML( undef, '  ' );

    }
    catch {
        warn 'cannot crop html: ' . substr($_, 0, 100) . '...';
        return $html;
    };
}



sub _format_body {

    my $self   = shift;
    my $entity = shift;
    my ($args) = @_;

    my @parts = $entity->parts;

    if (@parts) {
        my $i;
        for $i ( 0 .. $#parts ) {
            my $n_entity = undef;

            try {
                $n_entity = $self->_format_body( $parts[$i], $args );

            }
            catch {
                warn 'Formatting single entity failed!' . substr($_, 0, 100) . '...';
                next;
            };

            if ($n_entity) {
                $parts[$i] = $n_entity;
            }
            else {
                warn 'no $n_entity returned?!'
					if $t;
            }

        }

        $entity->sync_headers(
            'Length'      => 'COMPUTE',
            'Nonstandard' => 'ERASE'
        );

        return $entity;
    }
    else {

        my $changes = 0;
        my $is_att  = 0;
    
	    if ( defined( $entity->head->mime_attr('content-disposition') ) ) {
            if ( $entity->head->mime_attr('content-disposition') =~
                m/attachment/ )
            {
                $is_att = 1;
            }
        }

        my $body    = $entity->bodyhandle;
        my $content = $entity->bodyhandle->as_string;
        $content = safely_decode($content);
        if (
            (
                   ( $entity->head->mime_type eq 'text/plain' )
                || ( $entity->head->mime_type eq 'text/html' )
            )
            && ( $is_att != 1 )
          )
        {
            if ( $self->no_list != 1 ) {
                $content = $self->_expand_macro_tags(
                    -data => $content,
                    -type => $entity->head->mime_type,
                );

                if ( $args->{-format_mlm} == 1 ) {
					
					# Layout? 
                    $content = $self->format_mlm(
                        {
                            -content           => $content,
                            -type              => $entity->head->mime_type,
                            -crop_html_options => {

#enabled                          => scalar $draft_q->param('crop_html_content'),
#crop_html_content_selector_type  => scalar $draft_q->param('crop_html_content_selector_type'),
#crop_html_content_selector_label => scalar $draft_q->param('crop_html_content_selector_label'),
                            },
                            -rel_to_abs_options => {
                                enabled => 0,

                                #base    => $base,
                            }
                        }
                    );
                }
                $changes = 1;

            }
        }
        if (   ( $entity->head->mime_type eq 'text/html' )
            && ( $is_att != 1 ) )
        {

            if ( $self->no_list != 1 ) {
                if ( defined( $self->{list} ) ) {
					if($self->mass_mailing == 1) {
	                    if ( $self->{ls}->param('tracker_track_opens_method') eq
	                        'directly' && $entity->head->mime_type eq 'text/html' )
	                    {
	                        $content = $self->_add_opener_image($content);
	                        $changes = 1;
	                    }
					}
                }
            }
        }
		else	{ 
			warn 'well, no opener image for us...'
				if $t;
		}
        if ( $changes == 1 ) {
            my $io = $body->open('w');
            $content = safely_encode($content);
            $io->print($content);
            $io->close;
            $entity->sync_headers(
                'Length'      => 'COMPUTE',
                'Nonstandard' => 'ERASE'
            );
        }
        return $entity;
    }
}

=pod

=head1 PRIVATE METHODS

=head2 _make_multipart_alternative

 $entity = $self->_make_multipart_alternative($entity); 

Changes the single part, HTML entity into a multipart/alternative message, 
with an auto plaintext version. 

=cut

sub _make_multipart_alternative {

    my $self   = shift;
    my $entity = shift;
    $entity = $self->_create_multipart($entity);
    return $entity;

}

=pod

=head2 _format_text

 $entity = $self->_format_text($entity);	

Given an MIME::Entity (may be multipart) will attempt to:

=over

=item * Apply the List Template

=item * Apply the Email Template

=item * interpolate the message to change Dada Mail's template tags to their real value

=back

=cut



sub _add_opener_image {

    my $self    = shift;
    my $content = shift;
	return $content 
		if $self->no_list == 1; 
		
    my $url =
'<!-- tmpl_var PROGRAM_URL -->/spacer_image/<!-- tmpl_var list_settings.list -->/<!-- tmpl_var message_id -->/spacer.png';


    if ( $self->no_list != 1 ) {
        if ( $self->{ls}->param('tracker_track_email') == 1 ) {
            $url =
'<!-- tmpl_var PROGRAM_URL -->/spacer_image/<!-- tmpl_var list_settings.list -->/<!-- tmpl_var message_id -->/<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/spacer.png';
        }
    }

    my $img_opener_code =
        '<!--open_img--><img src="'
      . $url
      . '" width="1" height="1" alt="" /><!--/open_img-->';

    if ( $content =~ m/\<\/body(.*?)\>/i ) {
        $content =~ s/(\<\/body(.*?)\>)/$img_opener_code\n$1/i;
    }
    else {
        # No end body tag?!
        $content .= "\n" . $img_opener_code;
    }
    return $content;
}

# This would be a nice filter to re-implement for getting archives ready for viewing.
sub _remove_opener_image {
    my $self    = shift;
    my ($args)  = @_;
    my $content = $args->{-data};
    my $sm      = quotemeta('<!--open_img-->');
    my $em      = quotemeta('<!--/open_img-->');
    $content =~ s/($sm)(.*?)($em)//smg;
    return $content;
}

=pod

=head2 _create_multipart

 $entity = $self->_create_multipart($entity); 


Recursively goes through a multipart entity, changing any non-attachment
singlepart HTML message into a multipart/alternative message with an 
auto-generated PlainText version. 

=cut

sub _create_multipart {

    my $self   = shift;
    my $entity = shift;

    # Don't forget to do the pref check for plaintext...
    if (
        (
               $entity->head->mime_type eq 'text/html'
            && $entity->head->mime_attr('content-disposition') !~ m/attachment/
        )
        || (   $entity->head->mime_type eq 'text/plain'
            && $entity->head->mime_attr('content-disposition') !~ m/attachment/
            && $self->{ls}->param('mass_mailing_convert_plaintext_to_html') == 1
            && $self->mass_mailing == 1 )

      )
    {

        $entity = $self->_make_multipart($entity);
        $entity->sync_headers(
            'Length'      => 'COMPUTE',
            'Nonstandard' => 'ERASE'
        );
        return $entity;
    }
    elsif ($entity->head->mime_type eq 'multipart/mixed'
        && $entity->head->mime_attr('content-disposition') !~ m/attachment/ )
    {

        my @parts = $entity->parts();
        my $i     = 0;
        if ( !@parts ) {
            warn 'multipart/mixed with no parts?! Something is screwy....'
				if $t;
        }
        else {
            my $i;
          ALL_PARTS: for $i ( 0 .. $#parts ) {
                if (
                    (
                           $parts[$i]->head->mime_type eq 'text/html'
                        && $parts[$i]->head->mime_attr('content-disposition')
                        !~ m/attachment/
                    )
                    || (   $parts[$i]->head->mime_type eq 'text/plain'
                        && $parts[$i]->head->mime_attr('content-disposition')
                        !~ m/attachment/
                        && $self->{ls}
                        ->param('mass_mailing_convert_plaintext_to_html') == 1
                        && $self->mass_mailing == 1 )
                  )
                {
                    $parts[$i] = $self->_make_multipart( $parts[$i] );

                    # Seriously. How many could there be?
                    last ALL_PARTS;
                }
            }
            $entity->sync_headers(
                'Length'      => 'COMPUTE',
                'Nonstandard' => 'ERASE'
            );
            return $entity;

        }
    }

    # This should only be hit, if we haven't found anything to change
    return $entity;
}

=pod

=head2 _make_multipart

 $entity = $self->_make_multipart($entity); 	
 
Takes a single part entity and changes it to a multipart/alternative message, 
with an autogenerated PlainText or HTML version. 

=cut

sub _make_multipart {

    my $self   = shift;
    my $entity = shift;
    require MIME::Entity;

    my $orig_charset  = $entity->head->mime_attr('content-type.charset');
    my $orig_encoding = $entity->head->mime_encoding;
    my $orig_type     = $entity->head->mime_type;
    my $orig_content  = safely_decode( $entity->bodyhandle->as_string );

    $entity->make_multipart('alternative');

    my $new_type = undef;
    my $new_data = undef;

    if ( $orig_type eq 'text/plain' ) {
        $new_type = 'text/html';
        $new_data = plaintext_to_html( { -str => $orig_content } );

   # I kind of agree this is a strange place to put this, but H::T template tags
   # are getting clobbered:

        try {
            require DADA::App::FormatMessages::Filters::UnescapeTemplateTags;
            my $utt =
              DADA::App::FormatMessages::Filters::UnescapeTemplateTags->new;
            $new_data = $utt->filter( { -html_msg => $new_data } );
        }
        catch {
            carp 'Problems with filter:' . $_ if 
				$t;
        };

    }
    else {
        $new_type = 'text/plain';
		$new_data = $self->body_content_only($orig_content); 
		$new_data = html_to_plaintext( { -str => $orig_content } );
    }

    my $new_entity = MIME::Entity->build(
        Type     => $new_type,
        Data     => safely_encode($new_data),
        Encoding => $orig_encoding,
    );

    $new_entity->head->mime_attr( "content-type.charset" => $orig_charset, );

    if ( $orig_type eq 'text/html' ) {
        $entity->add_part( $new_entity, 0 );
    }
    else {
        # no offset - HTML part should be after plaintext part
        $entity->add_part($new_entity);
    }

    return $entity;
}

=pod

=head2 _format_headers 

 $entity = $self->_format_headers($entity)

Given an entity, will do some transformations on the headers. It will: 

=over

=item * Tack on the list name/list shortname on the Subject header for discussion lists

=item * Add the correct Reply-To header

=item * Remove any Message-ID headers

=item * Makes sure the To: header has a real name associated with it

=back

=cut

sub _format_headers {

    # so much shuffling.
    # a copy of the message should be made - at least the headers,
    # we can then modify the copy, using a r/o og copy, and not worry about
    # "hey, did I touch this, yet?"

    my $self   = shift;
    my $entity = shift;

	return $entity 
		if $self->no_list == 1;

    $entity->head->add( 'X-BeenThere',
        safely_encode( $DADA::Config::PROGRAM_URL ) );

	return $entity 
		if $self->{ls}->param('disable_discussion_sending') == 1; 
	
	
    require Email::Address;

    # DEV: this if() shouldn't really need to be here, if this is only used for
    # discussion messages
    #

    if ( $self->{ls}->param('prefix_list_name_to_subject') == 1 ) {

        # Most likely, the OG subject is encoded...
        my $new_subject;

        my $og_subject = $entity->head->get( 'Subject', 0 );

        if ( $og_subject =~ m/\=\?(.*?)\?Q\?/ ) {

            # probably not going to need to be decoded, it's 7bit ASCII
            $new_subject = $og_subject;

# This is related to the bug with the named capture in _list_name_subject
# http://stackoverflow.com/questions/10217531/whats-the-best-way-to-clear-regex-matching-variables
            "a" =~ /a/;

        }
        else {
            $new_subject = safely_decode($og_subject);
        }
        
        $entity->head->delete('Subject');
        $entity->head->add(
			'Subject', 
			$self->_list_name_subject($new_subject)
		);
    }

    # DEV:  Send mass mailings via sendmail, OTHER THAN via a discussion list,
    # still uses the -t flag - perhaps I should just go and change that?
    # I also really shouldn't have to do some of these checks twice, as
    # _format_headers should only be called for discussion lists.
    #

    if ( $self->mass_mailing == 1
        && defined( $self->{ls}->param('discussion_pop_email') ) )
    {
        if ( $entity->head->count('Cc') ) {
            $entity->head->add( 'X-Cc', $entity->head->get( 'Cc', 0 ) );
            $entity->head->delete('Cc');
        }
        if ( $entity->head->count('CC') ) {
            $entity->head->add( 'X-Cc', $entity->head->get( 'CC', 0 ) );
            $entity->head->delete('CC');
        }

        if ( $entity->head->count('Bcc') ) {
            $entity->head->delete('Bcc');
        }
        if ( $entity->head->count('BCC') ) {
            $entity->head->delete('BCC');
        }

    }

# This is weird, right? remove the original original from header, and put our own:
    if ( $entity->head->count('X-Original-From') ) {
        $entity->head->delete('X-Original-From');
    }
    $entity->head->add( 'X-Original-From', $entity->head->get( 'From', 0 ) );

    #  && $self->{ls}->param('group_list_pp_mode') == 1
	
    if (   $self->mass_mailing == 1
        && $self->{ls}->param('group_list') == 1
        && defined( $self->{ls}->param('discussion_pop_email') )
		)
    {
        if ( $entity->head->count('From') ) {
            my $og_from = $entity->head->get( 'From', 0 );
            chomp($og_from);

            $entity->head->delete('From');
			
			# This shouldn't needed to be, safely_encode()ed, 
			# as it's shuld be MimeEncoded, thus in bit... 
            $entity->head->add( 'From', safely_encode( $self->_pp($og_from) ) );

            if ( $self->{ls}->param('set_to_header_to_list_address') == 1 ) {
                if ( $entity->head->count('Reply-To') ) {
                    $entity->head->delete('Reply-To');
                }
                $entity->head->add( 'Reply-To', $og_from );
            }
        }
    }
    else {
        # "no pp mode!";
    }

    # Only Announce-Only
    if (   $self->mass_mailing == 1
        && $self->{ls}->param('group_list') == 0
        && defined( $self->{ls}->param('discussion_pop_email') ) )
    {
        if ( $t == 1 ) {
            warn q{$entity->head->get('From', 0) }
              . $entity->head->get( 'From', 0 );
            warn q{$entity->head->get('Reply-To', 0) }
              . $entity->head->get( 'Reply-To', 0 );
            warn q{$entity->head->get('Sender', 0) }
              . $entity->head->get( 'Sender', 0 );
            warn 'Only Announce-Only';
        }

        if ( $self->{ls}->param('bridge_announce_reply_to') eq 'list_owner' ) {
            if ( $entity->head->count('Reply-To') ) {
                $entity->head->delete('Reply-To');
            }
            warn
q{$entity->head->add( 'Reply-To', $self->{ls}->param('list_owner_email') );}
              if $t;
            $entity->head->add( 'Reply-To',
                $self->{ls}->param('list_owner_email') );
        }
        elsif ( $self->{ls}->param('bridge_announce_reply_to') eq 'og_sender' )
        {
            warn
q{lsif($self->{ls}->param('bridge_announce_reply_to') eq 'og_sender') }
              if $t;
            if ( $entity->head->count('Reply-To') ) {
                $entity->head->delete('Reply-To');
            }
            if ( $entity->head->count('Sender') ) {
                warn
q{ $entity->head->add( 'Reply-To',  $entity->head->get('Sender', 0) );}
                  if $t;
                $entity->head->add( 'Reply-To',
                    $entity->head->get( 'Sender', 0 ) );
            }
            else {
                warn
q{$entity->head->add( 'Reply-To',  $entity->head->get('From', 0) );}
                  if $t;
                $entity->head->add( 'Reply-To',
                    $entity->head->get( 'From', 0 ) );
            }
        }
        elsif ( $self->{ls}->param('bridge_announce_reply_to') eq 'none' ) {
            #...
        }
    }

    if ( $self->{ls}->param('group_list') == 1 ) {
        $entity->head->delete('Return-Path');
    }
    else {
        if ( $self->reset_from_header ) {
            $entity->head->delete('From');
        }
    }

    #Sender Header
    if ( $entity->head->count('Sender') ) {
        $entity->head->delete('Sender');
    }
    if ( $self->{ls}->param('group_list') == 1 ) {
        $entity->head->add( 'Sender',
            $self->{ls}->param('discussion_pop_email') );
    }
    else {
        $entity->head->add( 'Sender', $self->{ls}->param('list_owner_email') );
    }

    $entity->head->delete('Message-ID');

    # If there ain't a TO: header, add one:
    # (usually, this happens (or doesn't happen) in program

    if ( !$entity->head->get( 'To', 0 ) ) {
        $entity->head->add( 'To',
            safely_encode( $self->{ls}->param('list_owner_email') ) );
    }

    # If there's already a To: header, put a phrase in it, to make it look
    # nice...

    my $test_To = $entity->head->get( 'To', 0 );
    chomp($test_To);
    $test_To = strip($test_To);

    if ( $test_To =~ m{undisclosed\-recipients\:\;}i ) {
        warn "I'm SILENTLY IGNORING a, 'undisclosed-recipients:;' header!"
          if $t;

    }
    else {

        my @addrs = Email::Address->parse( $entity->head->get( 'To', 0 ) );

        if ( $addrs[1] ) {

            # more than 1? What's going on?!
            # who knows. Leave it at that!

        }
        else {

            my $to_addy = $addrs[0];

            if ( !$to_addy ) {

                warn
"couldn't get a valid Email::Address object? SILENTLY (*wink wink*) ignorning";

            }
            elsif ( !$to_addy->phrase ) {
                $entity->head->delete('To');
                $entity->head->add(
                    'To',
                    $self->format_phrase_address(
                        $self->{ls}->param('list_name'), $to_addy
                    )
                );

            }
        }
    }

    if ( $self->{ls}->param('discussion_pop_email') ) {
        $entity->head->add( 'X-BeenThere',
            safely_encode( $self->{ls}->param('discussion_pop_email') ) );
    }

    warn $entity->as_string
      if $t;

    return $entity;

}

sub _pp {

    my $self = shift;
    my $from = shift;

    require Email::Address;
    require MIME::EncWords;
    require DADA::Template::Widgets;

    my $a = ( Email::Address->parse($from) )[0]->address;
    my ( $e_name, $e_domain ) = split( '@', $a, 2 );

    #if ( $a eq $self->{ls}->param('list_owner_email') ) {
    #    # We don't have to "On Behalf Of" ourselves.
    #    return $from;
    #}
    #else {
    # $a =~ s/\@/ _at_ /;

    my $p = ( Email::Address->parse($from) )[0]->phrase
      || ( Email::Address->parse($from) )[0]->address;
    $p = $self->_decode_header($p);
    my $d          = $self->{ls}->param('group_list_pp_mode_from_phrase');
    my $new_phrase = DADA::Template::Widgets::screen(
        {
            -data => \$d,
            -expr => 1,
            -vars => {
                original_from_phrase      => $p,
                'subscriber.email'        => $a,
                'subscriber.email_name'   => $e_name,
                'subscriber.email_domain' => $e_name,
            },
            -list_settings_vars_param => {
                -list   => $self->{ls}->param('list'),
                -dot_it => 1,
            },
        }
    );

    my $new_from = Email::Address->new();
    $new_from->address( $self->{ls}->param('discussion_pop_email') );
    $new_from->phrase(
        MIME::EncWords::encode_mimewords(
            $new_phrase,
            Encoding => 'Q',
            Charset  => $self->{ls}->param('charset_value'),
        )
    );

    #  $new_from->comment( '(' . $a . ')' );
    return $new_from->format;

    # }
}

sub _encode_header {

    my $self  = shift;
    my $label = shift;
    my $value = shift;

    my $new_value = undef;

    require MIME::EncWords;

	my $charset = undef; 
	if($self->no_list == 1){ 
		$charset = $DADA::Config::LIST_SETUP_DEFAULTS{charset_value};
	}
	else { 
		$charset = $self->{ls}->param('charset_value');
	}


    if (   $label eq 'Subject'
        || $label eq 'List'
        || $label eq 'List-URL'
        || $label eq 'List-Owner'
        || $label eq 'List-Subscribe'
        || $label eq 'List-Unsubscribe'
        || $label eq 'just_phrase' )
    {

        # Bug: https://rt.cpan.org/Ticket/Display.html?id=84295
        my $MaxLineLen = -1;


        $new_value = MIME::EncWords::encode_mimewords(
            $value,
            Encoding   => 'Q',
            MaxLineLen => $MaxLineLen,
            Charset    => $charset
        );

    }
    else {
        require Email::Address;
        my @addresses = Email::Address->parse($value);
        for my $address (@addresses) {

            my $phrase = $address->phrase;

            $address->phrase(
                MIME::EncWords::encode_mimewords(
                    $phrase,
                    Encoding => 'Q',
                    Charset  => $charset,
                )
            );
        }
        my @new_addresses = ();
        for (@addresses) {
            push( @new_addresses, $_->format() );
        }

        $new_value = join( ', ', @new_addresses );
    }

    return $new_value;

}

sub _decode_header {
    warn 'at _decode_header'
      if $t;

    my $self   = shift;
    my $header = shift;

    warn '$header before:' . safely_encode($header)
      if $t;

    require MIME::EncWords;
    my $dec =
      MIME::EncWords::decode_mimewords( $header, Charset => '_UNICODE_' );
    $dec = safely_decode($dec);

    warn 'safely_encode($dec) after: ' . safely_encode($dec)
      if $t;
    return $dec;
}

sub _mime_charset {
    my $self   = shift;
    my $entity = shift;
    return $entity->head->mime_attr("content-type.charset")
      || $DADA::Config::HTML_CHARSET;
}

sub change_charset {
    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{-entity} ) ) {
        croak 'did not pass an entity in, "-entity"!';
    }

    my @parts = $args->{-entity}->parts;

    if (@parts) {
        warn "this part has " . $#parts . "parts."
          if $t;

        my $i;
        for $i ( 0 .. $#parts ) {
            $parts[$i] =
              $self->change_charset( { %{$args}, -entity => $parts[$i] } )
              ; # -entity should only pass the current part, but have the rest of the params passed...?
        }

        $args->{-entity}->sync_headers(
            'Length'      => 'COMPUTE',
            'Nonstandard' => 'ERASE'
        );

    }
    else {

        my $is_att = 0;
        if (
            defined( $args->{-entity}->head->mime_attr('content-disposition') )
          )
        {
            warn q{content-disposition has set to: }
              . $args->{-entity}->head->mime_attr('content-disposition')
              if $t;
            if ( $args->{-entity}->head->mime_attr('content-disposition') =~
                m/attachment/ )
            {
                warn "we have an attachment?"
                  if $t;
                $is_att = 1;
            }
        }
        else {
            warn "can't find a content-disposition"
              if $t;
        }

        if (
            (
                   ( $args->{-entity}->head->mime_type eq 'text/plain' )
                || ( $args->{-entity}->head->mime_type eq 'text/html' )
            )
            && ( $is_att != 1 )
          )
        {

            warn 'text or html, non-attachment part'
              if $t;

            my $body    = $args->{-entity}->bodyhandle;
            my $content = $args->{-entity}->bodyhandle->as_string;

            $content =
              Encode::decode( $self->_mime_charset( $args->{-entity} ),
                $content );

            if ($content) {

                # Stuff...
                $args->{-entity}
                  ->head->mime_attr( "content-type.charset", 'UTF-8' );

                my $io = $body->open('w');
                $content = safely_encode($content);
                $io->print($content);
                $io->close;
            }

            $args->{-entity}->sync_headers(
                'Length'      => 'COMPUTE',
                'Nonstandard' => 'ERASE'
            );
        }

    }

    return $args->{-entity};
}

sub change_content_transfer_encoding {

    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{-entity} ) ) {
        croak 'did not pass an entity in, "-entity"!';
    }

    my @parts = $args->{-entity}->parts;

    if (@parts) {
        warn "this part has " . $#parts . "parts."
          if $t;

        my $i;
        for $i ( 0 .. $#parts ) {
            $parts[$i] = $self->change_content_transfer_encoding(
                { %{$args}, -entity => $parts[$i] } );
        }

        $args->{-entity}->sync_headers(
            'Length'      => 'COMPUTE',
            'Nonstandard' => 'ERASE'
        );

    }
    else {

        my $is_att = 0;
        if (
            defined( $args->{-entity}->head->mime_attr('content-disposition') )
          )
        {
            warn q{content-disposition has set to: }
              . $args->{-entity}->head->mime_attr('content-disposition')
              if $t;
            if ( $args->{-entity}->head->mime_attr('content-disposition') =~
                m/attachment/ )
            {
                warn "we have an attachment?"
                  if $t;
                $is_att = 1;
            }
        }
        else {
            warn "can't find a content-disposition"
              if $t;
        }

        if (
            (
                   ( $args->{-entity}->head->mime_type eq 'text/plain' )
                || ( $args->{-entity}->head->mime_type eq 'text/html' )
            )
            && ( $is_att != 1 )
          )
        {

            $args->{-entity} =
              $self->change_content_transfer_encoding_in_body(
                $args->{-entity} );
        }
    }

    return $args->{-entity};
}

sub change_content_transfer_encoding_in_body {

    my $self     = shift;
    my $entity   = shift;
    my $encoding = shift || 'quoted-printable';
    my $charset  = shift || $DADA::Config::HTML_CHARSET;

    my $body    = $entity->bodyhandle;
    my $content = $entity->bodyhandle->as_string;

    my $mime_charset =
      $entity->head->mime_attr("content-type.charset") || $charset;
    my $content_type = $entity->head->mime_attr("content-type");

    $content = Encode::decode( $mime_charset, $content );

    for ( 'Content-Transfer-Encoding', 'Content-transfer-encoding' ) {
        if ( $entity->head->count($_) > 0 ) {
            $entity->head->delete($_);
        }
    }
    $entity->head->add( 'Content-Transfer-Encoding', $encoding );
    $entity->head->mime_attr( "Content-type.charset" => $charset, );

    require MIME::Entity;

    my $n_entity = MIME::Entity->build(
        Type     => $content_type,
        Charset  => $charset,
        Encoding => $encoding,
        Data     => safely_encode($content)
    );

    my $io = $body->open('w');
    my $n_content =
      safely_encode( safely_decode( $n_entity->bodyhandle->as_string ) );
    $io->print($n_content);
    $io->close;
    $entity->sync_headers(

        #'Length'      => 'COMPUTE', #optimization
        'Length'      => 'ERASE',
        'Nonstandard' => 'ERASE'
    );

    return $entity;

}

=pod

=head2 _list_name_subject

 my $subject = $self->_list_name_subject($list_name, $subject));

Appends, B<$list_name> onto subject. 


=cut

sub _list_name_subject {

	# This method expects the subject to be raw -  MIMEWords encoded
	# It will return a raw, MIMEWords encoded subject back

    my $self         = shift;
    my $subject = shift;
    $subject = $self->_decode_header($subject);

    my $list      = $self->{ls}->param('list');
    my $list_name = $self->{ls}->param('list_name');
	my $qm_list = quotemeta($list);
	my $qm_list_name = quotemeta($list_name);
	
	if($subject =~ m/^\[($qm_list|$qm_list_name)\]/){ 
		# And, we're done!
		$subject = $self->_encode_header( 'Subject', $subject );
		return $subject;
	}
	elsif($subject =~ m/^(RE:|AW:|FW:|WG:)\s*\[($qm_list|$qm_list_name)\]/i){ 
		# And, we're done!
		  $subject = $self->_encode_header( 'Subject', $subject );
		  return $subject;
	}
	else { 
		if($self->{ls}->param('prefix_discussion_list_subjects_with') eq "list_name"){ 
			$subject = '[' . $list_name . '] ' . $subject; 
		}
		elsif($self->{ls}->param('prefix_discussion_list_subjects_with') eq "list_shortname"){ 
			$subject = '[' . $list . '] ' . $subject; 
		}
	}
	
    $subject = $self->_encode_header( 'Subject', $subject );

    return $subject;

}

=pod

=head2 _expand_macro_tags

 $data = $self->_expand_macro_tags(-data => $data, 
                                    -type => (PlainText/HTML), 
                                   );
								        
Given a string, changes Dada Mail's template tag into what they represent. 

B<-type> can be either PlainText or HTML

=cut

sub _expand_macro_tags {

    my $self = shift;

    my %args = (
        -data => undef,
        -type => undef,
        @_
    );

    croak "no data! $!" if !$args{-data};

    my $data = $args{-data};
    if ( $self->no_list == 1 ) {
        return $data;
    }

#### Not completely happy with the below --v

    my $s_link  = $self->_macro_tags( -type => 'subscribe' );
    my $us_link = $self->_macro_tags( -type => 'unsubscribe' );

### this is messy.

    $data =~ s/\<\!\-\- tmpl_var plain_list_subscribe_link \-\-\>/$s_link/g;
    $data =~ s/\<\!\-\- tmpl_var plain_list_unsubscribe_link \-\-\>/$us_link/g;

    $data =~ s/\<\!\-\- tmpl_var list_subscribe_link \-\-\>/$s_link/g;

    #	$data =~ s/\<\!\-\- tmpl_var list_unsubscribe_link \-\-\>/$us_link/g;

    # confirmations.

    my $cs_link  = $self->_macro_tags( -type => 'confirm_subscribe' );
    my $cus_link = $self->_macro_tags( -type => 'confirm_unsubscribe' );

    $data =~ s/\<\!\-\- tmpl_var list_confirm_subscribe_link \-\-\>/$cs_link/g;
    $data =~
      s/\<\!\-\- tmpl_var list_confirm_unsubscribe_link \-\-\>/$cus_link/g;

    my $f_to_a_f_l = quotemeta('<!-- tmpl_var forward_to_a_friend_link -->');
    my $f_to_a_f_l_expanded =
'<!-- tmpl_var PROGRAM_URL -->/archive/<!-- tmpl_var list_settings.list -->/<!-- tmpl_var message_id -->/#forward_to_a_friend';

    $data =~ s/$f_to_a_f_l/$f_to_a_f_l_expanded/g;

    # This is kinda out of place...
    if ( $self->originating_message_url ) {
        my $omu = $self->originating_message_url;

        $data =~ s/\<\!\-\- tmpl_var originating_message_url \-\-\>/$omu/g;
    }

    return $data;

}

sub template_defang {

    my $self   = shift;
    my ($args) = @_;
    my $str    = $args->{-data};

    my $b1 = quotemeta('<!--');
    my $e1 = quotemeta('-->');

    my $b2 = quotemeta('<');
    my $e2 = quotemeta('>');

    my $b3 = quotemeta('[');
    my $e3 = quotemeta(']');

# The other option is to parse ALL "<", ">" and, "[", "]" and deal with all that, later,

    $str =~
s{$b1(\s*tmpl_(.*?)\s*)($e1|$e2)}{\<!-- tmpl_var LT_CHAR -->!-- tmpl_$2 \-\-\<!-- tmpl_var GT_CHAR -->}gi;
    $str =~
s{$b2(\s*tmpl_(.*?)\s*)($e1|$e2)}{\<!-- tmpl_var LT_CHAR -->tmpl_$2<!-- tmpl_var GT_CHAR -->}gi;

    $str =~
s{$b1(\s*/tmpl_(.*?)\s*)($e1|$e2)}{\<!-- tmpl_var LT_CHAR -->!-- /tmpl_$2\-\-\<!-- tmpl_var GT_CHAR -->}gi;
    $str =~
s{$b2(\s*/tmpl_(.*?)\s*)($e1|$e2)}{\<!-- tmpl_var LT_CHAR -->/tmpl_$2<!-- tmpl_var GT_CHAR -->}gi;

    return $str;

}

=pod

=head2 _macro_tags

 my $s_link   = $self->_macro_tags(-type => 'subscribe'  ); 
 my $us_link  = $self->_macro_tags(-type => 'unsubscribe');

Explode the various B<link> pseudo tags into a form that will later be interpolated. 

B<-type> can be: 

=over

=item * subscribe

=item * unsubscribe

=item * confirm_subscribe

=item * confirm_unsubscribe

=back


=cut

sub _macro_tags {

    my $self = shift;

    my %args = (
        -url         => '<!-- tmpl_var PROGRAM_URL -->',    # Really.
        -email       => undef,
        -list        => $self->{list},
        -escape_list => 1,
        -escape_all  => 0,
        @_
    );

    my $type;

    if ( $args{-type} eq 'confirm_subscribe' ) {

        my $link =
'<!-- tmpl_var PROGRAM_URL -->/t/<!-- tmpl_var list.confirmation_token -->/';
        return $link;

    }
    elsif ( $args{-type} eq 'subscribe' ) {

        $type = 's';

    }
    elsif ($args{-type} eq 'unsubscribe'
        || $args{-type} eq 'confirm_unsubscribe' )
    {

        return '<!-- tmpl_var list_unsubscripton_link -->';

    }

    my $link = $args{-url} . '/';

    if ( $args{-escape_all} == 1 ) {
        for ( $args{-email}, $type, $args{-list} ) {
            $_ = uriescape($_);
        }

    }
    elsif ( $args{-escape_list} == 1 ) {
        $args{-list} = uriescape( $args{-list} );
    }

    if ( $args{-email} ) {

        my $tmp_email = $args{-email};

        $tmp_email =~ s/\@/\//g;    # snarky. Replace, "@" with, "/"
        $tmp_email =~ s/\+/_p2Bp_/g;

        $args{-email} = $tmp_email;
    }
    else {
        $args{-email} =
'<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->';
    }

    my @qs;
    push( @qs, $type )                                  if $type;
    push( @qs, '<!-- tmpl_var list_settings.list -->' ) if $args{-list};
    push( @qs, $args{-email} )                          if $args{-email};

    $link .= join '/', @qs;

    return $link . '/';

}

=pod

=head2 _apply_template

$content = $self->_apply_template({-content => $content, 
								  -type => $entity->head->mime_type, 
								 });

Given a string in B<-data>, applies the correct email mailing list template, 
depending on what B<-type> is passed, this will be either the PlainText or
HTML version.							 	

=cut

sub _apply_template {

    my $self = shift;

    my ($args) = @_; 
#	 (
#        -content => undef,
#        -type => undef,
#        -layout
#        @_,
#    );

    croak 'No -content passed for type: ' . $args->{-type}
      if !exists($args->{-content});
    croak "no type! $!" if !exists($args->{-type});

    my $content = $args->{-content};
	
    my $template;
    my $template_out = 0;

    if ( $args->{-type} eq 'text/plain' ) {
        $template_out = $self->use_plaintext_email_template;
    }
    elsif ( $args->{-type} eq 'text/html' ) {
        $template_out = $self->use_html_email_template;
    }

#	warn '$template_out' . $template_out; 
#	warn '$self->layout_choice($args)' . $self->layout_choice($args); 
	
    if ($template_out) { # we're using a template in other words 
	
        require DADA::App::EmailThemes;
        my $em = DADA::App::EmailThemes->new(
            {
                -list      => $self->{list},
            }
        );
        my $etp = {
        	plaintext => '<!-- tmpl_var message_body -->', 
			html      => '<!-- tmpl_var message_body -->', 
        };
		my $layout = $self->layout_choice($args);
		if($layout ne 'none'){ 
			$etp = $em->fetch($layout);
		}
		
        if ( $args->{-type} eq 'text/plain' ) {
            $template = $etp->{plaintext} || '<!-- tmpl_var message_body -->';
        }
        else {
            $template = $etp->{html} || '<!-- tmpl_var message_body -->';
        }

        # if(some-user-set-setting) {
        if (   $self->no_list != 1
            && $self->mass_mailing == 1
            && $self->list_type eq 'list'
            && $self->{ls}->param('disable_discussion_sending') != 1
            && $self->{ls}->param('group_list') == 1 )
        {
            $template = $self->_depersonalize_mlm_template(
                {
                    -msg => $template,
                }
            );
        }
		
		#warn '$template' . $template; 

        # / depersonalize

        # This adds a message body tag, if you haven't done that, already.
        $template = $self->message_body_tagged(
            {
                -str  => $template,
                -type => $args->{-type},
            }
        );
		#warn '$template' . $template; 

        if ( $args->{-type} eq 'text/html' ) {

            # code below replaces code above - any problems?
            # as long as the message dada is valid HTML...
            
			unless ($self->layout_choice($args) eq 'none') {
		        # Body Content Only:
		        $content = $self->body_content_only($content);
			}

            if ($content) { # shouldn't this be if ($template?)

				my $qm_message_body_tag = quotemeta('<!-- tmpl_var message_body -->');
				$template =~ s/$qm_message_body_tag/$content/;
				#warn '$template' . $template;
          
            }
            else {
				#warn 'no content?';
                $template =~ s/\<\!\-\- tmpl_var message_body \-\-\>/$content/;
            }

        }
        else {
            $template =~ s/\<\!\-\- tmpl_var message_body \-\-\>/$content/;
        }
    }
    else {
        $template = $content;
    }

    $template = $self->_expand_macro_tags(
        -data => $template,
        -type => $args->{-type},
    );

	unless ($self->layout_choice($args) eq 'none') {
	    #dude. If there ain't no body...
	    if ( $args->{-type} eq 'text/html' ) {
	        if ( $template !~ /\<body(.*?)\>/i ) {

				warn 'no <body> tag?!'
					if $t;
			
	            my $title = $self->Subject || 'Mailing List Message';

	            $template = qq{ 
					<html> 
						<head>
							<title>$title</title>
						</head> 
						<body> 
							$template
						</body> 
					</html> 
				};
	        }
	    }
	}
	
	#warn '$template' . $template; 
	
    return $template;

}

sub layout_choice { 
	my $self   = shift; 
	my ($args) = @_; 
	my $layout = undef; 
	
	if(exists($args->{-layout})){ 
		if(!defined($args->{-layout})){ 
			delete($args->{-layout}); 
		}
		else { 
			warn 'Passed: $args->{-layout}' . $args->{-layout}
				if $t; 
		}
	}
	
	if(exists($args->{-layout})){
		if($args->{-layout} eq 'none'){ 
			return 'none';
		}
		else {
			# init. sort of. 
			$layout = 'mailing_list_message';
			if($args->{-layout} ne 'default'){
				$layout .= '-' . $args->{-layout};
			}
		}
	}
	else {
		
		my $mass_mailing_default_layout = $self->{ls}->param('mass_mailing_default_layout') || undef; 
		if(defined($mass_mailing_default_layout)) {
			#warn 'defined $mass_mailing_default_layout';
			$layout = 'mailing_list_message';
			if($mass_mailing_default_layout ne 'default'){
				$layout .= '-' . $mass_mailing_default_layout;
			}
			#warn '$layout' . $layout; 
		}
		else {
			if (   $self->no_list != 1
				&& $self->mass_mailing == 1
				&& $self->list_type eq 'list'
				&& $self->{ls}->param('disable_discussion_sending') != 1
				&& $self->{ls}->param('group_list') == 1 )
			{			
				$layout = 'mailing_list_message-discussion';
			}
			else { 
				$layout = 'mailing_list_message';
			}
		}
	}
	#warn 'returning $layout ' . $layout; 
	return $layout; 
}

#dumb.
sub _depersonalize_mlm_template {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-msg} ) ) {
        croak "you MUST pass the, '-msg' parameter!";
    }

    my $tags = [
        {
            og => '<!-- tmpl_var list_subscribe_link -->',
            re =>
'<!-- tmpl_var PROGRAM_URL -->/s/<!-- tmpl_var list_settings.list -->',
        },
    ];
    for my $tag (@$tags) {
        my $og = quotemeta( $tag->{og} );
        my $re = $tag->{re};
        $args->{-msg} =~ s/$og/$re/smg;
    }

    $args->{-msg};
}

sub can_find_sub_confirm_link {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-str} ) ) {
        die "You MUST pass the, '-str' parameter!";
    }

    my @sub_confirm_urls = (
'<!-- tmpl_var PROGRAM_URL -->/t/<!-- tmpl_var list.confirmation_token -->',
        '<!-- tmpl_var list_confirm_subscribe_link -->',
    );

    for my $url (@sub_confirm_urls) {
        $url = quotemeta($url);
        if ( $args->{-str} =~ m/$url/ ) {
            return 1;
        }
    }

    return 0;
}

sub subscription_confirmationation {

    my $self = shift;
    my ($args) = @_;

    die "no -str! $!" if !exists( $args->{-str} );

    #die "no type! $!" if !exists( $args->{-type} );

    if ( $self->can_find_sub_confirm_link( { -str => $args->{-str} } ) ) {

        # ...
    }
    else {

        warn "can't find sub confirm link: \n" . $args->{-str}
			if $t;

        $args->{-str} =
'To subscribe to, "<!-- tmpl_var list_settings.list_name -->", click the link below:
<!-- tmpl_var list_confirm_subscribe_link -->

' . $args->{-str};
    }
    return $args->{-str};
}

sub can_find_unsub_confirm_link {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-str} ) ) {
        die "You MUST pass the, '-str' parameter!";
    }

    my @unsub_confirm_urls = (
        '<!-- tmpl_var list_unsubscribe_link -->',
        '<!-- tmpl_var list_confirm_unsubscribe_link -->',
    );
    for my $url (@unsub_confirm_urls) {
        $url = quotemeta($url);
        if ( $args->{-str} =~ m/$url/ ) {
            return 1;
        }
    }

    return 0;
}

sub unsubscription_confirmationation {

    my $self = shift;
    my ($args) = @_;

    die "no -str! $!" if !exists( $args->{-str} );

    #die "no type! $!" if !exists( $args->{-type} );

    if ( $self->can_find_unsub_confirm_link( { -str => $args->{-str} } ) ) {

        # ...
    }
    else {
        $args->{-str} =
'To be removed from, "<!-- tmpl_var list_settings.list_name -->", click the link below:
<!-- tmpl_var list_unsubscribe_link -->

' . $args->{-str};
    }
    return $args->{-str};
}

sub can_find_message_body_tag {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-str} ) ) {
        die "You MUST pass the, '-str' parameter!";
    }

    my @message_body_tags = ( '<!-- tmpl_var message_body -->', );

    for my $message_body_tag (@message_body_tags) {
        $message_body_tag = quotemeta($message_body_tag);
        if ( $args->{-str} =~ m/$message_body_tag/ ) {
            return 1;
        }
    }

    return 0;

}

sub can_find_unsub_link {

    my $self = shift;
    my ($args) = @_;
    if ( !exists( $args->{-str} ) ) {
        die "You MUST pass the, '-str' parameter!";
    }

    my @unsub_urls = ('<!-- tmpl_var list_unsubscribe_link -->');

    for my $unsub_url (@unsub_urls) {
        $unsub_url = quotemeta($unsub_url);
        if ( $args->{-str} =~ m/$unsub_url/ ) {
            return 1;
        }
    }

    return 0;

}

sub unsubscriptionation {

    my $self = shift;

    my ($args) = @_;

    die "no -str! $!"  if !exists( $args->{-str} );
    die "no -type! $!" if !exists( $args->{-type} );

    if ( $self->{ls}->param('private_list') == 1 ) {
        return $args->{-str};
    }
    elsif ( $self->can_find_unsub_link( { -str => $args->{-str} } ) ) {

        # ...
    }
    else {

        if ( $args->{-type} eq 'text/html' ) {
            $args->{-str} = '
<p>
Unsubscribe Automatically:
<br />
<a href="<!-- tmpl_var list_unsubscribe_link -->">
<!-- tmpl_var list_unsubscribe_link -->
</a>
</p>

' . $args->{-str};
        }
        else {
            $args->{-str} = q{
Unsubscribe Automatically:
<!-- tmpl_var list_unsubscribe_link -->
}
              . $args->{-str};
        }
    }

    return $args->{-str};
}

sub message_body_tagged {
    my $self = shift;

    my ($args) = @_;

    die "no -str! $!"  if !exists( $args->{-str} );
    die "no -type! $!" if !exists( $args->{-type} );

    if ( $self->can_find_message_body_tag( { -str => $args->{-str} } ) ) {

        # ...
    }
    else {
        $args->{-str} = '<!-- tmpl_var message_body -->' . $args->{-str};
    }
    return $args->{-str};
}



sub entity_from_dada_style_args {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-fields} ) ) {

        croak 'did not pass data in, "-fields"';
    }

    if ( !exists( $args->{-parser_params} ) ) {
        $args->{-parser_params} = {};
    }
    elsif ( !exists( $args->{-parser_params}->{-input_mechanism} ) ) {
        $args->{-parser_params}->{-input_mechanism} = 'parse';
    }

    if ( $args->{-parser_params}->{-input_mechanism} eq 'parse_open' ) {

        my $filename =
          $self->file_from_dada_style_args( { -fields => $args->{-fields}, } );

        # This is going to return a Entity from a decoded message...?
        return (
            $self->get_entity(
                {
                    -data          => $filename,
                    -parser_params => { -input_mechanism => 'parse_open' },
                }
            ),
            $filename
        );

    }
    else {

        my $str = $self->string_from_dada_style_args(
            { -fields => $args->{-fields}, } );

        $str = safely_encode($str);
        my $entity = $self->get_entity( { -data => $str, } );

        return $entity;

    }
}

sub string_from_dada_style_args {

    my $self = shift;
    my ($args) = @_;

    my $str = '';

    if ( !exists( $args->{-fields} ) ) {

        croak 'did not pass data in, "-fields"';
    }

    for ( keys %{ $args->{-fields} } ) {

#for (@DADA::Config::EMAIL_HEADERS_ORDER) {
# You want the above because of tricky headers like Content-Type (or Content-type - you see?)
        next if $_ eq 'Body';
        next if $_ eq 'Message';    # Do I need this?!
        $str .= $_ . ': ' . $args->{-fields}->{$_} . "\n"
          if ( ( defined $args->{-fields}->{$_} )
            && ( $args->{-fields}->{$_} ne "" ) );
    }
    $str .= "\n" . $args->{-fields}->{Body};

    return $str;

}

sub file_from_dada_style_args {

    my $self = shift;
    my ($args) = @_;

    my $str = '';

    require DADA::Security::Password;
    my $time     = time;
    my $filename = $DADA::Config::TMP . '/' . 'tmp_msg-';
    $filename .= $time;
    $filename .= '-';
    $filename .= DADA::Security::Password::generate_rand_string();

    $filename = make_safer($filename);

    open my $MAIL, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', $filename
      or croak $!;

    #   open my $MAIL, '>', $filename or croak $!;

    if ( !exists( $args->{-fields} ) ) {
        croak 'did not pass data in, "-fields"';
    }

    for ( keys %{ $args->{-fields} } ) {

        #    for (@DADA::Config::EMAIL_HEADERS_ORDER) {
        next if $_ eq 'Body';
        next if $_ eq 'Message';    # Do I need this?!
        print $MAIL $_ . ': ' . $args->{-fields}->{$_} . "\n"
          if ( ( defined $args->{-fields}->{$_} )
            && ( $args->{-fields}->{$_} ne "" ) );
    }

    print $MAIL "\n" . $args->{-fields}->{Body};
    close $MAIL or croak $!;

    return $filename;

}

=pod

=head1 get_entity

C<get_entity> is a simple subroutine that takes a string, passed in, C<-data> and turns it into a 
B<HTML::Entities> entity: 

 my $entity = get_entity(
                  {
                      -data => $str, 
                  }
              ); 

Optionally, you may also pass the C<-parser_params> parameter, which will direct the parser on how
specifically to parse the message. Currently, there is only one param to play around with: 
C<-input_mechanism> - you can set this to either, B<parse> (which is the default), or B<parse_open>. 

If you pass, B<parse_open>, also pass a filename in B<-data> instead of a string. Right. 

my $entity = get_entity(
                  {
                      -data => $filename, 
                  }
              ); 

Make sure to delete the file when you're finished. 


=cut

sub get_entity {

    my $self = shift;
    my ($args) = @_;

    if ( !exists( $args->{-data} ) ) {
        croak 'did not pass data in, "-data"';
    }

    my $entity;

    # $self->{parser}->extract_nested_messages(0);

    if ( !exists( $args->{-parser_params} ) ) {
        $args->{-parser_params} = {};
    }
    elsif ( !exists( $args->{-parser_params}->{-input_mechanism} ) ) {
        $args->{-parser_params}->{-input_mechanism} = 'parse';
    }

    if ( !exists( $args->{-parser_params}->{-input_mechanism} ) ) {
        $args->{-parser_params}->{-input_mechanism} = 'parse_data';
    }
    if ( $args->{-parser_params}->{-input_mechanism} eq 'parse_open' ) {

# eval { $entity = $self->{parser}->parse_open($args->{-data}) };
# parse INSTREAM
#   Instance method. Takes a MIME-stream and splits it into its component entities.
#   The INSTREAM can be given as an IO::File, a globref filehandle (like \*STDIN),
#   or as any blessed object conforming to the IO:: interface (which minimally implements getline() and read()).
#   Returns the parsed MIME::Entity on success. Throws exception on failure. If the message contained too many parts (as set by max_parts), returns undef.

        eval {
#open TMPLFILE, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $args->{-data} or die $!;
            open TMPLFILE, '<', $args->{-data} or die $!;

            $entity = $self->{parser}->parse( \*TMPLFILE );
            close(TMPLFILE) or die $!;
        };
        if ($@) {
            carp $@;
        }
    }
    else {
        eval { $entity = $self->{parser}->parse_data( $args->{-data} ) };
        if ($@) {
            carp $@;
        }
    }

    if ($@) {
        carp "Problems making an entity: $@";
    }

    if ( !$entity ) {
        carp "No entity made! Gah! ";
    }

    return $entity;

}

=pod

=head1 email_template

This subroutine is extremely similar to B<DADA::Template::Widgets> C<screen> subroutine and in fact 
is basically a wrapper around it, although it also "knows" about Email Message headers and attempts
not to muck them up when you place variables in the template. 

It basically looks at the various parts of your email message and passes these parts to 
B<DADA::Template::Widgets> C<screen> subroutine to be templated out.

The parts of the email message that will be templated out are any and all B<text/plain>, B<text/html> 
bodies - both of which have an B<inline> content disposition (ie: it's not an attachment) 
and the B<To>, B<From> and B<Subject> headers of a message. 

For the B<To> and B<From> headers, this subroutine will only attempt to template out the B<phrase>
part of the header and will make sure that the phrase is properly escaped out. 

One main difference between this subroutine and C<screen> is that this subroutine does not take the
template to work with in the C<-data>, or, C<-screen> parameter, but instead takes it in the, C<-entity>
parameter. The C<-entity> parameter should be populated like so: 

 use MIME::Parser;
 my $parser = new MIME::Parser; 
 my $entity = $parser->parse_data($msg);
 
 DADA::App::FormatMessages::email_template({-entity => $entity});

( Probably should elaborate...) 

=cut

sub email_template {

    warn "email_template."
      if $t;

# Tests and documentation
# OK, MORE documentation
#
#
# OK - Headers don't work, if there's a multipart/alternative message (or, a message with an attachment, etc)

    my $self = shift;

    my ($args) = @_;
    if ( !exists( $args->{-first_pass} ) ) {
        $args->{-first_pass} = 1;
    }
    if ( $args->{-first_pass} == 1 ) {

        my $screen_vars = {};
        for ( keys %{$args} ) {
            next if $_ eq '-entity';
            $screen_vars->{$_} = $args->{$_};
        }

        my $special_headers = {
            Subject       => 'email.subject',
            'X-Preheader' => 'email.preheader',
        };

        for ( keys %$special_headers ) {

            my $og_header = $args->{-entity}->head->get( $_, 0 );
            $og_header = $self->_decode_header($og_header);
            my $header = DADA::Template::Widgets::screen(
                {
                    %{$screen_vars}, -data => \$og_header,
                }
            );
            $args->{-vars}->{ $special_headers->{$_} } = $header;

        }
        undef $screen_vars;
        $args->{-first_pass} = 0;
    }

    require DADA::Template::Widgets;

    if ( !exists( $args->{-entity} ) ) {
        croak 'did not pass an entity in, "-entity"!';
    }

    my @parts = $args->{-entity}->parts;

    if (@parts) {
        warn "this part has " . $#parts . "parts."
          if $t;

        my $i;
        for $i ( 0 .. $#parts ) {
            $parts[$i] =
              $self->email_template( { %{$args}, -entity => $parts[$i] } )
              ; # -entity should only pass the current part, but have the rest of the params passed...?
        }

        $args->{-entity}->sync_headers(

            #'Length'      => 'COMPUTE', #optimization
            'Length'      => 'ERASE',
            'Nonstandard' => 'ERASE'
        );

    }
    else {

        my $is_att = 0;
        if (
            defined( $args->{-entity}->head->mime_attr('content-disposition') )
          )
        {
            warn q{content-disposition has set to: }
              . $args->{-entity}->head->mime_attr('content-disposition')
              if $t;
            if ( $args->{-entity}->head->mime_attr('content-disposition') =~
                m/attachment/ )
            {
                warn "we have an attachment?"
                  if $t;
                $is_att = 1;
            }
        }
        else {
            warn "can't find a content-disposition"
              if $t;
        }

        if (
            (
                   ( $args->{-entity}->head->mime_type eq 'text/plain' )
                || ( $args->{-entity}->head->mime_type eq 'text/html' )
            )
            && ( $is_att != 1 )
          )
        {

            warn 'text or html, non-attachment part'
              if $t;

###
            my $screen_vars = {};
            for ( keys %{$args} ) {
                next if $_ eq '-entity';
                $screen_vars->{$_} = $args->{$_};
            }

            my $body    = $args->{-entity}->bodyhandle;
            my $content = $args->{-entity}->bodyhandle->as_string;
            $content = safely_decode($content);

            if ($content) {

                $content = DADA::Template::Widgets::screen(
                    {
                        %{$screen_vars},
                        -data => \$content,
                        (
                            (
                                $args->{-entity}->head->mime_type eq 'text/html'
                            )
                            ? (
                                -webify_these => [
                                    qw(
                                      list_settings.info
                                      list_settings.privacy_policy
                                      list_settings.physical_address
                                      )
                                ],
                              )
                            : ()
                        ),

                    }
                );

                my $io = $body->open('w');
                $content = safely_encode($content);
                $io->print($content);
                $io->close;
            }

            $args->{-entity}->sync_headers(

                #'Length'      => 'COMPUTE', #optimization
                'Length'      => 'ERASE',
                'Nonstandard' => 'ERASE'
            );
        }

    }

    # ?!
    my $screen_vars = {};
    for ( keys %{$args} ) {
        next if $_ eq '-entity';
        $screen_vars->{$_} = $args->{$_};
    }

    for my $header (
        'Subject',    'X-Preheader',
        'From',       'To',
        'Reply-To',   'Return-Path',
        'List',       'List-URL',
        'List-Owner', 'List-Subscribe',
        'List-Unsubscribe'
      )
    {

        if ( $args->{-entity}->head->get( $header, 0 ) ) {
            warn "looking at header:" . $header
              if $t;

            if ( $header =~ m/From|To|Reply\-To|Return\-Path|Errors\-To/ ) {

                warn 'header is: From|To|Reply\-To|Return\-Path|Errors\-To/'
                  if $t;

                # Get
                my $header_value = $args->{-entity}->head->get( $header, 0 );

                require Email::Address;

                # Uh.... get each individual.. thingy.
                my @addresses = Email::Address->parse($header_value);

                # But then, just work with the first?
                if ( $addresses[0] ) {

                    warn 'templating out header'
                      if $t;

                    # Get (individual)

                    # This makes sense - all we want to template out
                    # Is the phrase, so,

                    # We take the phrase out,
                    my $phrase = $addresses[0]->phrase;

                    # Decode it,
                    $phrase = $self->_decode_header($phrase);

                    if ( $phrase =~ m/\[|\</ )
                    { # does it even look like we have a templated thingy? (optimization)
                            #carp "$phrase needs to be templated out!";
                            # Template it Out
                        $phrase = DADA::Template::Widgets::screen(
                            {
                                %{$screen_vars}, -data => \$phrase,
                            }
                        );

                        # Encode it
                        $phrase =
                          $self->_encode_header( 'just_phrase', $phrase );

                        # Pop it back in,
                        $addresses[0]->phrase($phrase);

                        # Save it
                        my $new_header = $addresses[0]->format;

                        # Remove the old
                        $args->{-entity}->head->delete($header);

                        # Add the new
                        $args->{-entity}->head->add( $header, $new_header );
                    }
                    else {
             # carp "Skipping: $phrase since there ain't no template in there.";
                    } #/ does it even look like we have a templated thingy? (optimization)
                }
                else {

                    warn "couldn't find the first address?"
                      if $t;
                }
            }
            else {
                warn "I think we have Subject or X-Preheader."
                  if $t;

                # Get
                my $header_value = $args->{-entity}->head->get( $header, 0 );  #

                warn 'get() returned:' . safely_encode($header_value)
                  if $t;

                # Decode EncWords
                $header_value = $self->_decode_header($header_value);
                warn '$header_value ' . safely_encode($header_value)
                  if $t;

                if ( $header_value =~ m/\[|\</ )
                {    # has a template? (optimization)
                    $header_value = DADA::Template::Widgets::screen(
                        {
                            %{$screen_vars}, -data => \$header_value,
                        }
                    );
                    warn 'Template:' . safely_encode($header_value)
                      if $t;
                }

                $header_value = $self->_encode_header( $header,
                    safely_encode($header_value) );
                warn 'encode EncWords:' . safely_encode($header_value)
                  if $t;

                # Remove the old, add the new:
                $args->{-entity}->head->delete($header);
                $args->{-entity}->head->add( $header, $header_value );

                warn 'now:' . safely_encode($header_value)
                  if $t;
            }
        }
    }
    ###/
    # I think this is where I want to change the charset...
    return $args->{-entity};
}

sub pre_process_msg_strings {
	
	my $self = shift;

    my $text_ver = shift || undef;
    my $html_ver = shift || undef;

    if ($text_ver) {
        $text_ver =~ s/\r\n/\n/g;
    }

    if ($html_ver) {
        $html_ver =~ s/\r\n/\n/g;
    }

    if ( defined($html_ver) ) {
        $html_ver =~ s/^\n+//o;
        my $orig_html_ver = $html_ver;

        $html_ver =~ s/(^\n<br \/>|^<br \/>|^<br \/>\n)//;

        # convert_to_ascii is used here to simply strip out HTML tags, to
        # see if anything is left,
        $html_ver = convert_to_ascii($html_ver);    # what? what did I miss?
        $html_ver = strip($html_ver);
        $html_ver =~ s/^\n+|\n+$//o;
        if ( length($html_ver) <= 1 ) {
            $html_ver = undef;
        }
        else {
            $html_ver = $orig_html_ver;
            undef $orig_html_ver;
        }
    }	
	
    return ( $text_ver, $html_ver );
}

sub body_content_only { 
	my $self = shift; 
	my $og_html = shift; 
	my $html;
	
    try {
        require DADA::App::FormatMessages::Filters::BodyContentOnly;
        my $bco =
          DADA::App::FormatMessages::Filters::BodyContentOnly->new;
        $html = $bco->filter( { -html_msg => $og_html } );
		
		if(length($html) <= 0){ 
			warn 'filter returned no data, trying naive...';
			$html = $bco->naive_body_only($og_html);
			if(length($html) <= 0){ 
				warn 'naive returned no data, returning original';
				$html = $og_html;
			}
		}
			undef $bco; 
    }
    catch {
        carp 'Problems with filter:' . $_ if 
			$t;
    };
		
	return $html; 
	
	
}

sub DESTROY {

    #my $self = shift;
    #$self->{parser}->filer->purge
    #	if $self->{parser};
}

1;

=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2017 Justin Simoni All rights reserved. 

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

