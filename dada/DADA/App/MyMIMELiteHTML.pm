package DADA::App::MyMIMELiteHTML;


#package MIME::Lite::HTMLForked;

# module MIME::Lite::HTMLForked : Provide routine to transform a HTML page in
# a MIME::Lite mail
# Copyright 2001 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: HTML.pm,v $
# Revision 1.23  2008/10/14 11:27:42  alian
#
# Revision 1.23  2008/10/14 11:27:42  alian
# - Fix rt#36006: cid has no effect on background images
# - Fix rt#36005: include_javascript does not remove closing tag "</SCRIPT>"
# - Fix rt#29033: eliminate nested subs

# Revision 1.22  2006/09/06 14:46:42  alian
# - Fix rt#19656: unknown URI schemes cause rewrite to fail
# - Fix rt#17385: make test semi-panics
# - Fix rt#7841:  Text-Only Encoding Ignored
# - Fix rt#21339: no license or copyright information provided
# - Fix rt#19655: include_css is far too aggressive
#
# Revision 1.21  2004/04/15 22:59:33  alian
# fix for 1.20 and bad ref for tests
#
# Revision 1.20  2004/04/14 21:26:51  alian
# - fix error on last version
#
# Revision 1.19  2004/03/16 15:18:57  alian
# - Add Url param in new for direct call of parse & send
# - Correct a problem in parsing of html elem background
# - Re-indent some methods
#
# Revision 1.18  2003/08/08 09:37:42  alian
# Fix test case and cid method
#
# Revision 1.17  2003/08/07 16:55:08  alian
# - Fix test case (hostname)
# - Update POD documentation
#
# Revision 1.16  2003/08/07 00:07:57  alian
# - Use pack for include type == cid: RFC says no '/'.
# Tks to Cláudio Valente for report.
# - Add a __END__ statement before POD documentation.
#
# Revision 1.15  2002/10/19 17:54:32  alian
# - Correct bug with relative anchor '/'. Tks to Keith D. Zimmerman for
# report.
#
# See Changes files for older changes
use lib qw(../../); 

use DADA::App::Guts; 

use HTML::LinkExtor;
use URI::URL;
use MIME::Entity;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Carp qw(carp croak);
use Try::Tiny; 
use MIME::Parser;

require Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw();
$VERSION = ( '$Revision: 1.23 $ ' =~ /(\d+\.\d+)/ )[0];

my $LOGINDETAILS;


#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    my %param = @_;

    # remove javascript code or no ?
    if ( $param{'remove_jscript'} ) {
        $self->{_remove_jscript} = 1;
    }
    else { $self->{_remove_jscript} = 0; }

    # Set debug level
    #if ( $param{'Debug'} ) {
        $self->{_DEBUG} = 1;
		
		warn 'debug is on babe.';
		
    #    delete $param{'Debug'};
    #}

    # Set Login information
    if ( $param{'LoginDetails'} ) {
        $LOGINDETAILS = $param{'LoginDetails'};
        delete $param{'LoginDetails'};
    }
    
	my $parser = new MIME::Parser;
	   $parser = optimize_mime_parser($parser);
	  $self->{parser} = $parser; 
	   
	# These are here, but I don't see them doing anything. 
    for (qw(
            crop_html_content 
            crop_html_content_selector_type 
            crop_html_content_selector_label
        )){ 
        if(exists($param{$_})) { 
            $self->{$_} = $param{$_};
        }
        else { 
            $self->{$_} = undef;
            
        }
    }
    

    # Set type of include to do
    if ( $param{'IncludeType'} ) {
        die "IncludeType must be in 'extern', 'cid' or 'location'\n"
          if (  ( $param{'IncludeType'} ne 'extern' )
            and ( $param{'IncludeType'} ne 'cid' )
            and ( $param{'IncludeType'} ne 'location' ) );
        $self->{_include} = $param{'IncludeType'};
        delete $param{'IncludeType'};
    }    # Defaut type: use a Content-Location field
    else { $self->{_include} = 'location'; }

    ## Added by Michalis@linuxmail.org to manipulate non-us mails
    if ( $param{'TextCharset'} ) {
        $self->{_textcharset} = $param{'TextCharset'};
        delete $param{'TextCharset'};
    }
    else { $self->{_textcharset} = 'iso-8859-1'; }
    if ( $param{'HTMLCharset'} ) {
        $self->{_htmlcharset} = $param{'HTMLCharset'};
        delete $param{'HTMLCharset'};
    }
    else { $self->{_htmlcharset} = 'iso-8859-1'; }
    if ( $param{'TextEncoding'} ) {
        $self->{_textencoding} = $param{'TextEncoding'};
        delete $param{'TextEncoding'};
    }
    else { $self->{_textencoding} = '7bit'; }
    if ( $param{'HTMLEncoding'} ) {
        $self->{_htmlencoding} = $param{'HTMLEncoding'};
        delete $param{'HTMLEncoding'};
    }
    else { $self->{_htmlencoding} = 'quoted-printable'; }
    ## End. Default values remain as they were initially set.
    ## No need to change existing scripts if you send US-ASCII.
    ## If you DON't send us-ascii, you wouldn't be able to use
    ## MIME::Lite::HTMLForked anyway :-)

#    # Set proxy to use to get file
#    if ( $param{'Proxy'} ) {
#        $self->{_AGENT}->proxy( 'http', $param{'Proxy'} );
#        print "Set proxy for http : ", $param{'Proxy'}, "\n"
#          if ( $self->{_DEBUG} );
#        delete $param{'Proxy'};
#    }

    # Set hash to use with template
    if ( $param{'HashTemplate'} ) {
        $param{'HashTemplate'} =
          ref( $param{'HashTemplate'} ) eq "HASH" ? $param{'HashTemplate'} : %{ $param{'HashTemplate'} };
        $self->{_HASH_TEMPLATE} = $param{'HashTemplate'};
        delete $param{'HashTemplate'};
    }

    # Ok I hope I known what I do ;-)
    # MIME::Lite->quiet(1);

    # direct call of new parse & send
    my $url;
    if ( $param{'Url'} ) {
        $url = $param{'Url'};
        delete $param{'Url'};
    }
    $self->{_param} = \%param;
    if ($url) {
		warn 'Somehow, I am here.';
        my $m = $self->parse($url);
        $m->send;
    }

    return $self;
}

#------------------------------------------------------------------------------
# absUrl
#------------------------------------------------------------------------------
sub absUrl($$) {
    my $str  = shift;
    my $base = shift;

    # rt 19656 : unknown URI schemes cause rewrite to fail
	# I don't know why this is commented out - perhaps it's not an issue anymore? 
	# Are these template tags figured out, before we run it through this module? 
	# Tests?!
	#
    #	if($str =~ m/\[redirect\=(.*?)\]/){
    #		return $str;
    #	}
    #	elsif($str =~ m/\<\!\-\-(.*?)redirect/){
    #			return $str;
    #	}
    #	elsif($str =~ m/\<\!\-\- tmpl_(.*?)\-\-\>|\[list_unsubscribe_link\]/){ #?
    #			return $str;
    #	}
    #	else {

	    my $rep = eval { URI::WithBase->new( $str, $base )->abs; };
	    return ( $rep ? $rep : $str );

    #	}
}


sub pattern_image_cid {
	warn 'pattern_image_cid';
    my $sel = shift;
	warn '$_[0]:' . $_[0]; 
	warn '$_[1]:' . $_[1];
	warn '$_[2]:' . $_[2]; 
	warn '$_[3]:' . $_[3]; 	
	my $image_part_added = $_[3]; 
	my $r; 
	if(exists($image_part_added->{$_[1]})){ 
		warn 'it exists!';
		if($image_part_added->{$_[1]} == 1){ 
			warn "It worked!";
			$r = '<img ' . $_[0] . 'src="cid:' . $sel->cid( absUrl( $_[1], $_[2] ) ) . '"';
		}
		else { 
			warn "it didn't work!";
			# same as pattern_image... 
			 $r = '<img ' . $_[0] . 'src="' . absUrl( $_[1], $_[2] ) . '"';
		}
	}
	else { 
		warn 'it didnt exist!'; 
		# welp, guess it's OK:
		$r = '<img ' . $_[0] . 'src="cid:' . $sel->cid( absUrl( $_[1], $_[2] ) ) . '"';
	}
	warn '$r: ' . $r; 
	return $r; 
}


# Replace relative url for image with absolute
sub pattern_image {
    return '<img ' . $_[0] . 'src="' . absUrl( $_[1], $_[2] ) . '"';
}

sub pattern_href {
    my ( $url, $balise, $sep ) = @_;
    my $b = " $balise=\"$url\"";
    $b .= $sep if ( $sep ne '"' and $sep ne "'" );
    return $b;
}

#------------------------------------------------------------------------------
# parse
#------------------------------------------------------------------------------
sub parse {
	
	warn 'parse';

    my ( $self, $url_page, $url_txt, $url1 ) = @_;
    my ( $type, @mail, $html_ver, $txt_ver, $rootPage );

	my $image_part_added = {}; 
		
    my $html_md5 = undef;

    # Get content of $url_page with LWP
    if ( $url_page && $url_page =~ /^(https?|ftp|file|nntp):\/\// ) {

        warn "Get ", $url_page, "\n" if $self->{_DEBUG};
        my ( $content, $res, $md5 ) = grab_url( { -url => $url_page } );
        $html_md5 = $md5;
        if ( !$res->is_success ) {
			# Grab URL should fill all this in as well: 
            $self->set_err( "Can't fetch $url_page (" . $res->message . ")" );
        }
        else {
            $html_ver = safely_decode($content);
        }
        $rootPage = $url1 || $res->base;
    }
    else {
		# warn '$html_ver' . $html_ver; 
        $html_ver = $url_page;
        $rootPage = $url1;
        $html_md5 = md5_checksum( \$html_ver );
    }

    # Get content of $url_txt with LWP if needed
    if ($url_txt) {
        if ( $url_txt =~ /^(https?|ftp|file|nntp):\/\// ) {
            warn "Get ", $url_txt, "\n" if $self->{_DEBUG};

            my ( $content, $res, $md5 ) = grab_url( { -url => $url_page } );
            if ( !$res->is_success ) {
                $self->set_err( "Can't fetch $url_txt (" . $res->message . ")" );
            }
            else {
                $txt_ver = safely_decode($content);
            }
        }
        else {
            $txt_ver = $url_txt;
        }
    }

	#warn '$html_ver' . $html_ver; 
	#warn '$txt_ver'  . $txt_ver; 
	
    # Means successful, but blank. Blank is no good for us.
    if ( !$html_ver && !$txt_ver) {
        $self->set_err('Sorry, there is no content.');
        if (wantarray) {
            return ( 0, 'Sorry, there is no content.', $self->{_MAIL}, $html_md5 );
        }
        else {
            return undef;
        }
    }

    goto BUILD_MESSAGE unless $html_ver;


	
	# This is no good, as HTML::Scrubber mucks up embedded DM tags in links. (d'oh!)
    #if ( $self->{_remove_jscript} == 1 ) {
    #    $html_ver = scrub_js($html_ver); 
    #}
    	
	
    # Get all multimedia part (img, flash) for later create a MIME part
    # for each of them
    my $analyzer = HTML::LinkExtor->new;
       $analyzer->parse($html_ver);
    my @l = $analyzer->links;

    # Include external CSS files
    $html_ver = $self->include_css( $html_ver, $rootPage );
	
    $html_ver = $self->include_javascript( $html_ver, $rootPage );
    
    # Include form images
    ( $html_ver, @mail ) = $self->input_image( $html_ver, $rootPage );

    # Change target action for form
    $html_ver = $self->link_form( $html_ver, $rootPage );

    # Scan each part found by linkExtor
    my ( %images_read, %url_remplace );
    for my $url (@l) {
        my $urlAbs = absUrl( $$url[2], $rootPage );
        chomp $urlAbs;    # Sometime a strange cr/lf occur
				
        # Replace relative href found to absolute one
        if (
               ( $$url[0] eq 'a' )
            && ( $$url[1] eq 'href' )
            && ( $$url[2] )
            && (
                ( $$url[2] !~ m!^http://! ) &&    # un lien non absolu
                ( $$url[2] !~ m!^mailto:! ) &&    # pas les mailto
                ( $$url[2] !~ m!^\#! )      &&    # ni les ancres
                ( $$url[2] !~ m!^\<! )      &&    # ni les tags du "Dada Mail"
                ( $$url[2] !~ m!^\[! )
            )
            &&                                    # Hmm. meme chose.
            ( !$url_remplace{$urlAbs} )
          )                                       # ni les urls deja remplacees
        {
			
			#warn 'here!';
			#warn '$$url[2]' . $$url[2]; 
			#warn q{pattern_href($urlAbs,"href",$1)} . pattern_href($urlAbs,"href",$1); 
			
            $html_ver =~ s/\s href \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
		           /pattern_href($urlAbs,"href",$1)/giemx;
            warn "Replace ", $$url[2], " with ", $urlAbs, "\n"
              if ( $self->{_DEBUG} );
            $url_remplace{$urlAbs} = 1;
        }

        # For frame & iframe
        elsif (( lc( $$url[0] eq 'iframe' ) || lc( $$url[0] eq 'frame' ) )
            && ( lc( $$url[1] ) eq 'src' )
            && ( $$url[2] ) )
        {
            $html_ver =~ s/\s src \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
		           /pattern_href($urlAbs,"src",$1)/giemx;
            warn "Replace ", $$url[2], " with ", $urlAbs, "\n"
              if ( $self->{_DEBUG} );
            $url_remplace{$urlAbs} = 1;
        }

        # For background images
        elsif ( ( lc( $$url[1] ) eq 'background' ) && ( $$url[2] ) ) {

            # Replace relative url with absolute
            my $v = ( $self->{_include} eq 'cid' ) ? "cid:" . $self->cid($urlAbs) : $urlAbs;
            $html_ver =~ s/background \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
                       /pattern_href($v,"background",$1)/giemx;

            # Exit with extern configuration, don't include image
            # else add part to mail
            if ( ( $self->{_include} ne 'extern' ) && ( !$images_read{$urlAbs} ) ) {
                $images_read{$urlAbs} = 1;
				my $img_part = $self->create_image_part($urlAbs);
				if(defined($img_part)){
					push( @mail, $img_part)
				}
            }
        }

        # For flash part (embed)
        elsif ( lc( $$url[0] ) eq 'embed' && $$url[4] ) {

            # rebuild $urlAbs
            $urlAbs = absUrl( $$url[4], $rootPage );

            # Replace relative url with absolute
            my $v = ( $self->{_include} eq 'cid' ) ? "cid:$urlAbs" : $urlAbs;
            $html_ver =~ s/src \s = \s [\"'] \Q$$url[4]\E ([\"'>])
                        /pattern_href($v,"src",$1)/giemx;

            # Exit with extern configuration, don't include image
            if ( ( $self->{_include} ne 'extern' ) && ( !$images_read{$urlAbs} ) ) {
                $images_read{$urlAbs} = 1;
				my $img_part = $self->create_image_part($urlAbs);
				if(defined($img_part)){
					push( @mail, $img_part)
				}
			}
        }

        # For flash part (object)
        # Need to add "param" to Tagset.pm in the linkElements definition:
        # 'param' => ['name', 'value'],
        # Tks to tosh@c4.ca for that
        elsif (lc( $$url[0] ) eq 'param'
            && lc( $$url[2] ) eq 'movie'
            && $$url[4] )
        {
            # rebuild $urlAbs
            $urlAbs = absUrl( $$url[4], $rootPage );

            # Replace relative url with absolute
            my $v = ( $self->{_include} eq 'cid' ) ? "cid:" . $self->cid($urlAbs) : $urlAbs;
            $html_ver =~ s/value \s* = \s* [\"'] \Q$$url[4]\E ([\"'>])
                       /pattern_href($v,"value",$1)/giemx;

            # Exit with extern configuration, don't include image
            if ( ( $self->{_include} ne 'extern' ) && ( !$images_read{$urlAbs} ) ) {
                $images_read{$urlAbs} = 1;
				my $img_part = $self->create_image_part($urlAbs);
				if(defined($img_part)){
					push( @mail, $img_part)
				}
            }
        }

        # For new images create part
        # Exit with extern configuration, don't include image
		
		# "  && ( ( lc( $$url[0] ) eq 'img' ) || ( lc( $$url[0] ) eq 'src' ) )" <-- recently added?
        elsif (( $self->{_include} ne 'extern' )
            && ( ( lc( $$url[0] ) eq 'img' ) || ( lc( $$url[0] ) eq 'src' ) )
            && ( !$images_read{$urlAbs} ) )
        {
			
            $images_read{$urlAbs} = 1;
			
			my $img_part = $self->create_image_part($urlAbs);
			
			if(defined($img_part)){
				push( @mail, $img_part);
				$image_part_added->{$urlAbs} = 1; 
			}
			else { 
				$image_part_added->{$urlAbs} = 0; 	
			}
        }
    }

#	use Data::Dumper; 
#	warn '$image_part_added: ' . Data::Dumper::Dumper($image_part_added);
    # Replace in HTML link with image with cid:key
	
    if ( $self->{_include} eq 'cid' ) {
        $html_ver =~ s/<img ([^<>]*) src\s*=\s*(["']?) ([^"'> ]* )(["']?)
	           /pattern_image_cid($self,$1,$3,$rootPage,$image_part_added)/iegx;
    }
	 else {   # Else just make a absolute url
        $html_ver =~ s/<img ([^<>]*) src\s*=\s*(["']?)([^"'> ]*) (["']?)
	              /pattern_image($1,$3,$rootPage)/iegx;
    }

  BUILD_MESSAGE:

    # Substitue value in template if needed
    #if ( scalar keys %{ $self->{_HASH_TEMPLATE} } != 0 ) {
    #    $html_ver = $self->fill_template( $html_ver, $self->{_HASH_TEMPLATE} )
    #      if ($html_ver);
    #    $txt_ver = $self->fill_template( $txt_ver, $self->{_HASH_TEMPLATE} );
    #}

	warn 'here.';
    $self->build_mime_object( $html_ver, $txt_ver || undef, \@mail );
	warn 'here.';
	
	my $r_md5 = $html_md5; 
	if(!$html_ver && $txt_ver){
		$r_md5 = md5_checksum( \$txt_ver );
	}
	
	
    if (wantarray) {
		warn 'this one';
        return ( 1, undef, $self->{_MAIL}, $r_md5 );
    }
    else {
		warn 'that one';
        return $self->{_MAIL};
    }
}

#------------------------------------------------------------------------------
# size
#------------------------------------------------------------------------------
sub size {
    my ($self) = shift;
    return length( $self->{_MAIL}->as_string );
}

#------------------------------------------------------------------------------
# build_mime_object
#------------------------------------------------------------------------------
sub build_mime_object {
    my ( $self, $html, $txt, $ref_mail ) = @_;

	
	my $final_entity  = undef; 
	my $html_entity   = undef;
	my $text_entity   = undef; 

    # Create part for HTML if needed
    if (defined($html)) {
		
		warn 'html part';
		
		# ?!?!
		#  my $ref = ( $txt || @$ref_mail ) ? {} : $self->{_param};
 		
		$html_entity = $self->_build_html_part(
			{
				-html_str =>  $html, 
			}
		);
		
    }

	warn '$txt' . $txt; 
    # Create part for text if needed
    if (defined($txt)) {
		
		warn 'txt part';
		
		#?!?!
		# my $ref = ( $html ? {} : $self->{_param} );
	
		$text_entity = $self->_build_txt_part(
			{
				-txt_str =>  $txt, 
			}
		);
    }
	
	#use Data::Dumper; 
	#warn '$text_entity' . Dumper($text_entity); 
	#warn $text_entity->dump_skeleton(\*STDERR);

	if(
		   defined($html_entity) 
		&& defined($text_entity)
	){ 
		
		warn 'text and html';
	
		#multipart alternative with a multipart related HTML Version. 
		
		my $html_part = undef; 
		
		warn 'here.';
		
		if(scalar(@$ref_mail) > 0){		
			
			warn 'here.';
			
			# HTML part + Attachments. 	
			$html_part = MIME::Entity->build(
				Type => 'multipart/related', 			
			); 
			warn 'here.';
			$html_part->add_part($html_entity);
			warn 'here.';
	        foreach (@$ref_mail) { 
				warn 'here.';
				$html_part->add_part($_); 
				warn 'skeleton: $html_part' . $html_part->dump_skeleton(\*STDERR);
			}
		}
		else { 
			warn 'here.';
			$html_part = $html_entity; 
			warn 'here.';
		}
		warn 'here.';
		my $multipart_entity = MIME::Entity->build(
			Type => 'multipart/alternative', 			
		);
		
		warn 'dumping skeleton:';
		warn 'dump_skeleton' .  $multipart_entity->dump_skeleton(\*STDERR);
		
		
		warn 'here.';
		$multipart_entity->add_part($text_entity);


		warn 'dumping skeleton:';
		warn 'dump_skeleton' .  $multipart_entity->dump_skeleton(\*STDERR);


		warn 'here.';
		$multipart_entity->add_part($html_part);
		
		warn 'dumping skeleton:';
		warn 'dump_skeleton' .  $multipart_entity->dump_skeleton(\*STDERR);
		
		
		warn 'here.';
		#$final_entity = $self->copy_entity($multipart_entity);
		$final_entity = $multipart_entity; 
		
		warn 'dumping skeleton:';
		warn 'dump_skeleton' .  $final_entity->dump_skeleton(\*STDERR);
	}
	elsif(
		   defined($html_entity) 
		&& ! defined($text_entity)
	){ 
		
		warn 'only html';
			
		# Why. Why do this: 
		
		my $html_part = undef; 
		
		if(scalar(@$ref_mail) > 0){		
			# HTML part + Attachments. 	
			$html_part = MIME::Entity->build(
				Type => 'multipart/related', 			
			); 
			$html_part->add_part($html_entity);
	        foreach (@$ref_mail) { 
				$html_part->add_part($_); 
			}
		}
		else { 
			$html_part = $html_entity; 
		}
		
		$final_entity = $html_part;
		
	}
	elsif(
		   !defined($html_entity) 
		&&  defined($text_entity)
	){ 
	
		warn 'only text';
		my $text_part = undef; 
		
		if(scalar(@$ref_mail) > 0){		
			# HTML part + Attachments. 	
			$text_part = MIME::Entity->build(
				Type => 'multipart/related', 			
			); 
			$text_part->add_part($text_entity);
	        foreach (@$ref_mail) { 
				$text_part->add_part($_); 
			}
		}
		else { 
			$text_part = $text_entity; 
		}
		
		#$final_entity = $self->copy_entity($text_part);
		$final_entity = $text_part; 

	}
	else { 
		warn 'nothing';
		
		croak "Talk to me: What are you trying to do?";
	}
	
	warn 'about to as_string.';
	warn 'as_string' , $final_entity->as_string . 'all set!';
	
    #$self->{_MAIL} = $self->copy_entity($final_entity);
	$self->{_MAIL} = $final_entity;
	warn 'and were done, here.';
}

sub copy_entity {
    my $self      = shift;
    my $entity    = shift;
    my $entity_cp = $self->{parser}->parse_data( $entity->as_string );
    return $entity_cp;
}



sub _build_html_part { 
	
	my $self = shift; 
	my ($args) = @_; 
	if(!exists($args->{-html_str})){ 
		croak "Pass HTML String in, -html_str!";
		
	}
	
	
	my $entity = MIME::Entity->build(
        'Type'     => 'text/html',
        'Encoding' => $self->{_htmlencoding},
        'Data'     => safely_encode($args->{-html_str})
	);
    $entity->head->mime_attr( "content-type.charset" => $self->{_htmlcharset} );
	return $entity; 
	
}




sub _build_txt_part { 
	
	my $self = shift; 
	my ($args) = @_; 
	if(!exists($args->{-txt_str})){ 
		croak "Pass Text String in, -txt_str!";
	}
	
	my $entity = MIME::Entity->build(
        'Type'     => 'text/plain',
        'Encoding' => $self->{_textencoding},
        'Data'     => safely_encode($args->{-txt_str})
	);
    $entity->head->mime_attr( "content-type.charset" => $self->{_textcharset} );
	
	return $entity; 
	
}






#------------------------------------------------------------------------------
# include_css
#------------------------------------------------------------------------------
sub pattern_css {
    my ( $self, $url, $milieu, $fin, $root ) = @_;

    # if not stylesheet - rt19655
    if ( $milieu !~ /stylesheet/i && $fin !~ /stylesheet/i ) {
        return "<link" . $milieu . " href=\"$url\"" . $fin . ">";
    }

    # Don't store <LINK REL="SHORTCUT ICON"> tag. Tks to doggy@miniasp.com
    if ( $fin =~ m/shortcut/i || $milieu =~ m/shortcut/i ) {
        return "<link" . $milieu . "href='" . $url . "'" . $fin . ">";
    }

    # Complete url
    my $ur = URI::URL->new( $url, $root )->abs;
    warn "Include CSS file $ur\n" if $self->{_DEBUG};
    my ( $content, $res, $md5 ) = grab_url( { -url => $ur } );
    if ( $res->is_success ) {
        warn "Ok file downloaded\n" if $self->{_DEBUG};
        return '<style type="text/css">' . "\n" . '<!--' . "\n" . safely_decode($content) . "\n-->\n</style>\n";
    }
    else {
        my $err =
          "Looking for css to include:, '" . $ur . "' was not successful - removing from message and ignoring";
        
		  if($ur ne 'css/app.css'){
			$self->set_err($err);
            carp $err;
		}
        # DEV: so, why was this returning an open <style> tag?
        # Because that's dumb.
        return '';    #<style type="text/css">';
    }
}

sub include_css(\%$$) {
    my ( $self, $tmpl, $root ) = @_;

    $tmpl =~ s/<link ([^<>]*?)
                href\s*=\s*["']?([^\"\' ]*)["']?([^>]*)>
    /$self->pattern_css($2,$1,$3,$root)/iegmx;

    warn "Done CSS\n" if ( $self->{_DEBUG} );
    return $tmpl;
}

#------------------------------------------------------------------------------
# include_javascript
#------------------------------------------------------------------------------
sub pattern_js {
    my ( $self, $url, $milieu, $fin, $root ) = @_;

    my $ur = URI::URL->new( $url, $root )->abs;
	warn '$self->{_remove_jscript}' . $self->{_remove_jscript}; 
    if ( $self->{_remove_jscript} == 1 ) {

        # Why should I even try to get the files, if I'm just going to remove them?
        warn  "Removed Javascript file $ur\n" if $self->{_DEBUG};
        return '<!-- removed js: ' . $ur . ' -->';
    }
    else {
        warn "Include Javascript file $ur\n"
       		if $self->{_DEBUG};

        my ( $content, $res, $md5 ) = grab_url( { -url => $ur } );
       
	    if ( $res->is_success ) {
            warn "Ok file downloaded\n"
              if $self->{_DEBUG};
            return
                "\n"
              . "<!-- $ur -->\n"
              . '<script '
              . $milieu
              . $fin . ">\n" . '<!--' . "\n"
              . safely_decode($content)
              . "\n-->\n</script>\n";
        }
        else {
            my $err =
                "Looking for javascript to include:, '"
              . $ur
              . "' was not successful - removing from message and ignoring";
            $self->set_err($err);
            carp $err;
            return "<!-- Couldn't Include Javascript: $ur -->\n";
        }
    }
}

#sub include_javascript(\%$$) {
#    my ( $self, $gabarit, $root ) = @_;
#    $gabarit =~ s/<script([^>]*)src\s*=\s*"?([^\" ]*js)"?([^>]*)>[^<]*<\/script>
#    /$self->pattern_js($2,$1,$3,$root)/iegmx;
#    if ( $self->{_remove_jscript} ) {
#
#        #die "Yes.";
#        # Old!
#        # $gabarit=~s/<script([^>]*)>[^<]*<\/script>//iegmx;
#        # New!
#        $gabarit =~ s/<script([^>]*)>[\s\S]*?<\/script>//iegmx;
#    }
#    print "Done Javascript\n" if $self->{_DEBUG};
#    return $gabarit;
#}
# In this new version, we never, ever inline javascript. 
# A good thing (probably)
#
sub include_javascript(\%$$) {

    my ( $self, $tmpl, $root ) = @_;
    if ( $self->{_remove_jscript} == 1 ) {

        # Old!
        # $tmpl=~s/<script([^>]*)>[^<]*<\/script>//iegmx;
        # New!
		
        $tmpl =~ s/<script([^>]*)>[\s\S]*?<\/script>//iegmx;
    }
	
    warn "Done Javascript\n"
      if $self->{_DEBUG};
    
	return $tmpl;
}


#------------------------------------------------------------------------------
# input_image
#------------------------------------------------------------------------------
sub pattern_input_image {
    my ( $self, $deb, $url, $fin, $base, $ref_tab_mail ) = @_;
    my $ur = URI::URL->new( $url, $base )->abs;
    if ( $self->{_include} ne 'extern' ) {
	
		warn 'pattern_input_image';
		my $img_part = $self->create_image_part($ur);
		if(defined($img_part)){
			 push( @$ref_tab_mail,  $img_part); 
		 }
	 }
    if   ( $self->{_include} eq 'cid' ) { return '<input ' . $deb . ' src="cid:' . $ur . '"' . $fin; }
    else                                { return '<input ' . $deb . ' src="' . $ur . '"' . $fin; }
}

sub input_image(\%$$) {
    my ( $self, $gabarit, $root ) = @_;
    my @mail;
    $gabarit =~ s/<input([^<>]*)src\s*=\s*"?([^\"'> ]*)"?([^>]*)>
    /$self->pattern_input_image($1,$2,$3,$root,\@mail)/iegmx;
    warn "Done input image\n" if $self->{_DEBUG};
    return ( $gabarit, @mail );
}

#------------------------------------------------------------------------------
# create_image_part
#------------------------------------------------------------------------------
sub create_image_part {
	
	warn 'here.';
	
    my ( $self, $ur, $typ ) = @_;
    my ( $type, $buff1 );
	
	warn '$ur:' . $ur; 
	warn 'length($ur)' . length($ur); 
	warn 'defined($ur)' . defined($ur); 
	
	if ((length($ur) == 0) || (! defined $ur)) { 
		warn 'passed blank url'
			if $self->{_DEBUG};
		return undef ;
	} 

	# This is asolutely ridiculous. 
    # Create MIME type
    if    ($typ)                   { $type = $typ; }
    elsif ( lc($ur) =~ /\.gif$/i ) { $type = "image/gif"; }
    elsif ( lc($ur) =~ /\.jpg$/i ) { $type = "image/jpg"; }
    elsif ( lc($ur) =~ /\.jpeg$/i ) { $type = "image/jpg"; }
    elsif ( lc($ur) =~ /\.png$/i ) { $type  = "image/png"; }
    else                           { $type = "application/octet-stream"; }

    # Url is already in memory
    if ( $self->{_HASH_TEMPLATE}{$ur} ) {
        warn "Using buffer on: ", $ur, "\n" if $self->{_DEBUG};
        $buff1 =
          ref( $self->{_HASH_TEMPLATE}{$ur} ) eq "ARRAY"
          ? join "", @{ $self->{_HASH_TEMPLATE}{$ur} }
          : $self->{_HASH_TEMPLATE}{$ur};
        delete $self->{_HASH_TEMPLATE}{$ur};
    }
    else {    # Get image
        warn "Get img " . $ur 
			if $self->{_DEBUG};
        my $res2 = undef; 
		my ( $content2, $res2, $md52 ) = grab_url( { -url => $ur } );
	   
	    if (!$res2->is_success ) { 
			require Data::Dumper;
			my $e_r = { 
				url         => $ur, 
				code        => $res2->code, 
				# headers     => $res->headers, 
				status_line => $res2->status_line, 
				message     => $res2->message, 				
			};
			my $e_m = "Problem fetching URL:\n"; 
			   $e_m .= Data::Dumper::Dumper($e_r);
			   warn $e_m; 
		   
			$self->set_err("Can't get $ur\n"); 
			return undef;
		}
		else { 
			"Yeah, OK successful: ";; 
			$buff1 = $res2->decoded_content;
		}
    }

	
    # Create part
	my %entity_args = (
		Data        => $buff1, 
		Encoding    => 'base64',
		Disposition => "inline",
		Type        => $type, 	
	);
    if ( $self->{_include} eq 'cid' ) {
        $entity_args{Id} = '<' . $self->cid($ur) . '>';
	}
	else {
		# This isn't a documented thing, but why would we want Content-Location?  
		$entity_args{'Content-Location'} = $ur;
	}
	
    my $entity = new MIME::Entity->build(%entity_args);
    return $entity;
}

#------------------------------------------------------------------------------
# cid
#------------------------------------------------------------------------------
sub cid (\%$) {
    my ( $self, $url ) = @_;

	#warn 'cid $url:"' . $url . '"'; 
	
	$url = strip($url); 
	
    require URI;

    my $filename = DADA::App::Guts::uriescape( ( URI->new($url)->path_segments )[-1] );
	my $r; 
	
	# Filenames with spaces and "%" escapes make bad names for cid's, 
	# But I still want the file ending available. 
	#
	$filename =~ s/ /\-/g; 
	$filename =~ s/%20/\-/g;
	if($filename =~ m/%/){ 
		my ($ext1) = $filename =~ /((\.[^.\s]+)+)$/;
		$r = $self->md5_checksum($url) . $ext1; 
	}
	else {
		$r = $self->md5_checksum($url) . '_' . $filename; 
	}
	# warn 'returning: ' . $r;
	 return $r; 
}


sub md5_checksum {

	my $self = shift; 
    my $data = shift;

    try {
        require Digest::MD5;
    }
    catch {
        carp "Can't use Digest::MD5?" . substr($_, 0, 100) . '...';
        return undef;
    };
    return Digest::MD5::md5_hex( $data );
}



#------------------------------------------------------------------------------
# link_form
#------------------------------------------------------------------------------
sub pattern_link_form {
    my ( $self, $deb, $url, $fin, $base ) = @_;
    my $type;
    my $ur = URI::URL->new( $url, $base )->abs;
    return '<form ' . $deb . ' action="' . $ur . '"' . $fin . '>';
}

sub link_form {
    my ( $self, $gabarit, $root ) = @_;
    my @mail;
    $gabarit =~ s/<form([^<>]*)action="?([^\"'> ]*)"?([^>]*)>
                /$self->pattern_link_form($1,$2,$3,$root)/iegmx;
    warn "Done form\n" if $self->{_DEBUG};
    return $gabarit;
}

#------------------------------------------------------------------------------
# fill_template
#------------------------------------------------------------------------------
#sub fill_template {
#    my ( $self, $masque, $vars ) = @_;
#    return unless $masque;
#    my @buf = split( /\n/, $masque );
#    my $i = 0;
#    while ( my ( $n, $v ) = each(%$vars) ) {
#        if ($v) {
#            map { s/<\?\s\$$n\s\?>/$v/gm } @buf;
#        }
#        else {
#            map { s/<\?\s\$$n\s\?>//gm } @buf;
#        }
#        $i++;
#    }
#    return join( "\n", @buf );
#}

#------------------------------------------------------------------------------
# set_err
#------------------------------------------------------------------------------
sub set_err {
    my ( $self, $error ) = @_;
    warn $error, "\n" if ( $self->{_DEBUG} );
    my @array;
    if ( $self->{_ERRORS} ) {
        @array = @{ $self->{_ERRORS} };
    }
    push @array, $error;
    $self->{_ERRORS} = \@array;
    return 1;
}

#------------------------------------------------------------------------------
# errstr
#------------------------------------------------------------------------------
sub errstr {
    my ($self) = @_;
    return @{ $self->{_ERRORS} } if ( $self->{_ERRORS} );
    return ();
}

1;

__END__

#------------------------------------------------------------------------------
# POD Documentation
#------------------------------------------------------------------------------

=head1 NAME

MIME::Lite::HTMLForked - Provide routine to transform a HTML page in a MIME-Lite mail

=head1 SYNOPSIS

  perl -MMIME::Lite::HTMLForked -e '
     new MIME::Lite::HTMLForked
         From     => "MIME-Lite\@alianwebserver.com",
         To       => "alian\@cpan.org",
         Url      => "http://localhost/server-status";'

=head1 VERSION

$Revision: 1.23 $

=head1 DESCRIPTION

This module is a Perl mail client interface for sending message that 
support HTML format and build them for you..
This module provide routine to transform a HTML page in MIME::Lite mail.
So you need this module to use MIME-Lite-HTML possibilities

=head2 What's happen ?

The job done is:

=over

=item *

Get the file (LWP) if needed

=item *

Parse page to find include images (gif, jpg, flash)

=item *

Attach them to mail with adequat header if asked (default)

=item *

Include external CSS,Javascript file

=item *

Replace relative url with absolute one

=item *

Build the final MIME-Lite object with each part found

=back



=head2 Usage

Did you alread see link like "Send this page to a friend" ?. With this module,
you can do script that to this in 3 lines.

It can be used too in a HTML newsletter. You make a classic HTML page,
and give just url to MIME::Lite::HTMLForked.

=head2 Construction

MIME-Lite-HTML use a MIME-Lite object, and RFC2557 construction:

If images and text are present, construction use is:

  --> multipart/alternative
  ------> text/plain
  ------> multipart/related
  -------------> text/html
  -------------> each images

If no images but text is present, this is that:

  ---> multipart/alternative
  -------> text/plain if present
  -------> text/html

If images but no text, this is:

  ---> multipart/related
  -------> text/html
  -------> each images

If no images and no text, this is:

  ---> text/html



=head2 Documentation

Additionnal documentation can be found here:

=over

=item *

MIME-lite module

=item *

RFC 822, RFC 1521, RFC 1522 and specially RFC 2557 (MIME Encapsulation
of Aggregate Documents, such as HTML)

=back



=head2 Clients tested

HTML in mail is not full supported so this module can't work with all email
clients. If some client recognize HTML, they didn't support images include in
HTML. So in fact, they recognize multipart/relative but not multipart/related.

=over

=item Netscape Messager (Linux-Windows)

100% ok

=item Outlook Express (Windows-Mac)

100% ok. Mac work only with Content-Location header. Thx to Steve Benbow for
give mr this feedback and for his test.

=item Eudora (Windows)

If this module just send HTML and text, (without images), 100% ok.

With images, Eudora didn't recognize multipart/related part as describe in
RFC 2557 even if he can read his own HTML mail. So if images are present in 
HTML part, text and HTML part will be displayed both, text part in first. 
Two additional headers will be displayed in HTML part too in this case. 
Version 1.0 of this module correct major problem of headers displayed 
with image include in HTML part.

=item KMail (Linux)

If this module just send HTML and text, (without images), 100% ok.

In other case, Kmail didn't support image include in HTML. So if you set in 
KMail "Prefer HTML to text", it display HTML with images broken. Otherwise, 
it display text part.

=item Pegasus (Windows)

If this module just send HTML and text, (without images), 100% ok.

Pegasus didn't support images in HTML. When it find a multipart/related 
message, it ignore it, and display text part.

=back

If you find others mail client who support (or not support) MIME-Lite-HTML
module, give me some feedback ! If you want be sure that your mail can be 
read by maximum of people, (so not only OE and Netscape), don't include 
images in your mail, and use a text buffer too. If multipart/related mail 
is not recognize, multipart/alternative can be read by the most of mail client.



=head2 Install on WinX with ActiveState / PPM

Just do in DOS "shell":

  c:\ ppm
  > set repository alian http://www.alianwebserver.com/perl/CPAN
  > install MIME-Lite-HTML
  > quit



=head2 How know when next release will be ?

Subscribe on http://www.alianwebserver.com/cgi-bin/news_mlh.cgi



=head1 Public Interface

=over

=item new(%hash)

Create a new instance of MIME::Lite::HTMLForked.

The hash can have this key : [Url], [Proxy], [Debug], [IncludeType],
 [HashTemplate], [LoginDetails], [TextCharset], [HTMLCharset],
 [TextEncoding], [HTMLEncoding], [remove_jscript]

=over

=item Url

... is url to parse and send. If this param is found, call of parse routine
and send of mail is done. Else you must use parse routine of MIME::Lite::HTMLForked
and send of MIME::Lite.

=item Proxy

... is url of proxy to use.

  Eg: Proxy => 'http://192.168.100.166:8080'

=item remove_jscript

if set, remove all script code from html source

  Eg: remove_jscript => 1

=item Debug

... is trace to stdout during parsing.

  Eg: Debug => 1

=item IncludeType

... is method to use when finding images:

=over

=item location

Default method is embed them in mail whith 'Content-Location' header. 

=item cid

You use a 'Content-CID' header.

=item extern

Images are not embed, relative url are just replace with absolute, 
so images are fetch when user read mail. (Server must be reachable !)

=back

=item $hash{'HashTemplate'} 

... is a reference to a hash. If present, MIME::Lite::HTMLForked 
will substitute <? $name ?> with $hash{'HashTemplate'}{'name'} when parse url 
to send. $hash{'HashTemplate'} can be used too for include data for subelement.
Eg:

  $hash{'HashTemplate'}{'http://www.al.com/images/sommaire.gif'}=\@data;

or 

  $hash{'HashTemplate'}{'http://www.al.com/script.js'}="alert("Hello world");;

When module find the image http://www.alianwebserver.com/images/sommaire.gif 
in buffer, it don't get image with LWP but use data found in 
$hash{'HashTemplate'}. (See eg/example2.pl)

=item LoginDetails

... is the couple user:password for use with restricted url. 

  Eg: LoginDetails => 'my_user:my_password'

=item TextCharset

... is the character set to use for the text part.

  Eg: TextCharset => 'iso-8859-7'

for Greek. If none specified, the default is used (iso-8859-1).

=item HTMLCharset

... is the character set to use for the html part. 

  Eg:  HTMLCharset => 'iso-8859-7'

for Greek. If none specified, the default is used (iso-8859-1).
Take care, as that option does NOT change the character
set of the HTML page, it only changes the character set of the mime part.

=item TextEncoding 

... is the Encoding to be used for the text part (if such a part 
exists). If none specified, the default is used (7bit).

  Eg: TextEncoding => 'base64'

=item HTMLEncoding 

... is the Encoding to be used for the html part. If none specified, the 
default is used (quoted-printable).

  Eg: HTMLEncoding => 'base64'.

=back

Others keys are use with MIME::Lite constructor.

This MIME-Lite keys are: Bcc, Encrypted, Received, Sender, Cc, From,
References, Subject, Comments, Keywords, Reply-To To, Content-*,
Message-ID,Resent-*, X-*,Date, MIME-Version, Return-Path,
Organization



=item parse($html, [$url_txt], [$url_base])

Subroutine used for created HTML mail with MIME-Lite

Parameters:

=over

=item $html

Url of HTML file to send, can be a local file. If $url is not an
url (http or https or ftp or file or nntp), $url is used as a buffer.
Example : 

  http://www.alianwebserver.com
  file://c|/tmp/index.html
  <img src=toto.gif>

=item $url_txt

Url of text part to send for person who doesn't support HTML mail.
As $html, $url_txt can be a simple buffer.

=item $url_base

$url_base is used if $html is a buffer, for get element found in HTML buffer.

=back

Return the MIME::Lite part to send

=item size()

Display size of mail in characters (so octets) that will be send.
(So use it *after* parse method). Use this method for control
size of mail send, I personnaly hate receive 500k by mail.
I pay for a 33k modem :-(

=back

=head1 Private methods

=over

=item build_mime_object($html,[$txt],[@mail])

(private)

Build the final MIME-Lite object to send with each part read before

=over

=item $html

Buffer of HTML part

=item $txt

Buffer of text part

=item @mail

List of images attached to HTML part. Each item is a MIME-Lite object.

=back

See "Construction" in "Description" for know how MIME-Lite object is build.

=item create_image_part($url)

(private)

Fetch if needed $url, and create a MIME part for it.

=item include_css($gabarit,$root)

(private)

Search in HTML buffer ($gabarit) to remplace call to extern CSS file
with his content. $root is original absolute url where css file will
be found.

=item include_javascript($gabarit,$root)

(private)

Search in HTML buffer ($gabarit) to remplace call to extern javascript file
with his content. $root is original absolute url where javascript file will
be found.

=item input_image($gabarit,$root)

(private)

Search in HTML buffer ($gabarit) to remplace input form image with his cid

Return final buffer and list of MIME::Lite part

=item link_form($gabarit,$root)

(private)

Replace link to formulaire with absolute link

=item fill_template($masque,$vars)

=over

=item $masque

Path of template

=item $vars

hash ref with keys/val to substitue

=back

Give template with remplaced variables
Ex: if $$vars{age}=12, and $masque have

  J'ai <? $age ?> ans,

this function give:

  J'ai 12 ans,

=back

=head1 Error Handling

The set_err routine is used privately. You can ask for an array of all the 
errors which occured inside the parse routine by calling:

@errors = $mailHTML->errstr;

If no errors where found, it'll return undef.

=head1 CGI Example

  #!/usr/bin/perl -w 
  # A cgi program that do "Mail this page to a friend";
  # Call this script like this :
  # script.cgi?email=myfriend@isp.com&url=http://www.go.com
  use strict;
  use CGI qw/:standard/;
  use CGI::Carp qw/fatalsToBrowser/;
  use MIME::Lite::HTMLForked;
  
  my $mailHTML = new MIME::Lite::HTMLForked
     From     => 'MIME-Lite@alianwebserver.com',
     To       => param('email'),
     Subject => 'Your url: '.param('url');
  
  my $MIMEmail = $mailHTML->parse(param('url'));
  $MIMEmail->send; # or for win user : $mail->send_by_smtp('smtp.fai.com');
  print header,"Mail envoye (", param('url'), " to ", param('email'),")<br>\n";

=head1 TERMS AND CONDITIONS

  Copyright (c) 2000 by Alain BARBET alian (at) cpan.org

All rights reserved.  This program is free software; you can
redistribute it and/or modify it under the same terms as Perl
itself.

This software comes with B<NO WARRANTY> of any kind.
See the COPYING file in the distribution for details.

=head1 AUTHOR

Alain BARBET alian@cpan.org , see file Changes for helpers.

=cut

