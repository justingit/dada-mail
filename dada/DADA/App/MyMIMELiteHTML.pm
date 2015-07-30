package DADA::App::MyMIMELiteHTML;

use lib "../../";
use lib "../../DADA/perllib";

use MIME::Lite::HTMLForked;
@ISA = "MIME::Lite::HTMLForked";
use strict; 

#use base "MIME::Lite::HTMLForked";

use Carp qw(croak carp);
use DADA::App::Guts;
use Try::Tiny; 

## trés bizarre!
#sub MIME::Lite::HTMLForked::absUrl($$) {
sub absUrl($$) {
    my $str  = shift;
    my $base = shift;

    # rt 19656 : unknown URI schemes cause rewrite to fail
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

# BUG: [ 2145145 ] 3.0.0 - Send a Webpage msg w/Clickthrough Links Fails
# https://sourceforge.net/tracker/index.php?func=detail&aid=2145145&group_id=13002&atid=113002
# Also:
# http://perlmonks.org/?node_id=715405
#
# DEV: For whatever reason, I can't overload, "absUrl", without bringing in this entire subroutine.
# I'm pretty sure it has to do with either the absUrl() call happening in a private subroutine,
# or, absUrl isn't overloadable? It's not actually a method and isn't exported... I can force it, but it
# looks sort of strange. Regardless - not the best design for MIME::Lite::HTMLForked, unfortunetly.

sub parse {

    my ( $self, $url_page, $url_txt, $url1 ) = @_;
    my ( $type, @mail, $html_ver, $txt_ver, $rootPage );

    my $html_md5 = undef;

    # Get content of $url_page with LWP
    if ( $url_page && $url_page =~ /^(https?|ftp|file|nntp):\/\// ) {

        print "Get ", $url_page, "\n" if $self->{_DEBUG};
        my ( $content, $res, $md5 ) = grab_url( { -url => $url_page } );
        $html_md5 = $md5;
        if ( !$res->is_success ) {
            $self->set_err( "Can't fetch $url_page (" . $res->message . ")" );
        }
        else {
            $html_ver = safely_decode($content);
            #warn q{$self->{crop_html_content}} . $self->{crop_html_content}; 
            
            if ( $self->{crop_html_content} == 1 ) {
                $html_ver = $self->crop_html($html_ver);
            }
        }
        $rootPage = $url1 || $res->base;
    }
    else {
        $html_ver = $url_page;
        if ( $self->{crop_html_content} == 1 ) {
            $html_ver = $self->crop_html($html_ver);
        }
        $rootPage = $url1;
        $html_md5 = md5_checksum( \$html_ver );

        #warn '$html_md5 ' . $html_md5;
    }

    # Get content of $url_txt with LWP if needed
    if ($url_txt) {
        if ( $url_txt =~ /^(https?|ftp|file|nntp):\/\// ) {
            print "Get ", $url_txt, "\n" if $self->{_DEBUG};

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

    # Means successful, but blank. Blank is no good for us.
    if ( !$html_ver ) {
        $self->set_err('Webpage content is blank.');
        if (wantarray) {
            return ( 0, 'Webpage content is blank.', $self->{_MAIL}, $html_md5 );
        }
        else {
            return undef;
        }
    }

    goto BUILD_MESSAGE unless $html_ver;

    if ( $self->{_remove_jscript} == 1 ) {
        $html_ver = scrub_js($html_ver); 
    }
    
    # Get all multimedia part (img, flash) for later create a MIME part
    # for each of them
    my $analyzer = HTML::LinkExtor->new;
    $analyzer->parse($html_ver);
    my @l = $analyzer->links;

    # Include external CSS files
    $html_ver = $self->include_css( $html_ver, $rootPage );

    #if ( $self->{_remove_jscript} != 1 ) {
        # Include external Javascript files
        $html_ver = $self->include_javascript( $html_ver, $rootPage );
    #}
    
    # Include form images
    ( $html_ver, @mail ) = $self->input_image( $html_ver, $rootPage );

    # Change target action for form
    $html_ver = $self->link_form( $html_ver, $rootPage );

    sub pattern_href {
        my ( $url, $balise, $sep ) = @_;
        my $b = " $balise=\"$url\"";
        $b .= $sep if ( $sep ne '"' and $sep ne "'" );
        return $b;
    }

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
            $html_ver =~ s/\s href \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
		           /pattern_href($urlAbs,"href",$1)/giemx;
            print "Replace ", $$url[2], " with ", $urlAbs, "\n"
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
            print "Replace ", $$url[2], " with ", $urlAbs, "\n"
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
                push( @mail, $self->create_image_part($urlAbs) );
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
                push( @mail, $self->create_image_part($urlAbs) );
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
                push( @mail, $self->create_image_part($urlAbs) );
            }
        }

        # For new images create part
        # Exit with extern configuration, don't include image
        elsif (( $self->{_include} ne 'extern' )
            && ( ( lc( $$url[0] ) eq 'img' ) || ( lc( $$url[0] ) eq 'src' ) )
            && ( !$images_read{$urlAbs} ) )
        {
            $images_read{$urlAbs} = 1;
            push( @mail, $self->create_image_part($urlAbs) );
        }
    }

    # Replace in HTML link with image with cid:key
    sub pattern_image_cid {
        my $sel = shift;
        return '<img ' . $_[0] . 'src="cid:' . $sel->cid( absUrl( $_[1], $_[2] ) ) . '"';
    }

    # Replace relative url for image with absolute
    sub pattern_image {
        return '<img ' . $_[0] . 'src="' . absUrl( $_[1], $_[2] ) . '"';
    }

    # If cid choice, put a cid + absolute url on each link image
    if ( $self->{_include} eq 'cid' ) {
        $html_ver =~ s/<img ([^<>]*) src\s*=\s*(["']?) ([^"'> ]* )(["']?)
	           /pattern_image_cid($self,$1,$3,$rootPage)/iegx;
    }

    # Else just make a absolute url
    else {
        $html_ver =~ s/<img ([^<>]*) src\s*=\s*(["']?)([^"'> ]*) (["']?)
	              /pattern_image($1,$3,$rootPage)/iegx;
    }

  BUILD_MESSAGE:

    # Substitue value in template if needed
    if ( scalar keys %{ $self->{_HASH_TEMPLATE} } != 0 ) {
        $html_ver = $self->fill_template( $html_ver, $self->{_HASH_TEMPLATE} )
          if ($html_ver);
        $txt_ver = $self->fill_template( $txt_ver, $self->{_HASH_TEMPLATE} );
    }

    $self->build_mime_object( $html_ver, $txt_ver || undef, \@mail );

    if (wantarray) {
        return ( 1, undef, $self->{_MAIL}, $html_md5 );
    }
    else {
        return $self->{_MAIL};
    }
}

#------------------------------------------------------------------------------
# include_css
#------------------------------------------------------------------------------
sub include_css(\%$$) {
    my ( $self, $tmpl, $root ) = @_;

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
        print "Include CSS file $ur\n" if $self->{_DEBUG};
        my ( $content, $res, $md5 ) = grab_url( { -url => $ur } );
        if ( $res->is_success ) {
            print "Ok file downloaded\n" if $self->{_DEBUG};
            return '<style type="text/css">' . "\n" . '<!--' . "\n" . safely_decode($content) . "\n-->\n</style>\n";
        }
        else {
            my $err =
              "Looking for css to include:, '" . $ur . "' was not successful - removing from message and ignoring";
            $self->set_err($err);
            carp $err;

            # DEV: so, why was this returning an open <style> tag?
            # Because that's dumb.
            return '';    #<style type="text/css">';
        }
    }
    $tmpl =~ s/<link ([^<>]*?)
                href\s*=\s*"?([^\" ]*)"?([^>]*)>
    /$self->pattern_css($2,$1,$3,$root)/iegmx;

    print "Done CSS\n" if ( $self->{_DEBUG} );
    return $tmpl;
}

#------------------------------------------------------------------------------
# include_javascript
#------------------------------------------------------------------------------

sub pattern_js {
    my ( $self, $url, $milieu, $fin, $root ) = @_;

    my $ur = URI::URL->new( $url, $root )->abs;

    if ( $self->{_remove_jscript} == 1 ) {

        # Why should I even try to get the files, if I'm just going to remove them?
        print "Removed Javascript file $ur\n" if $self->{_DEBUG};
        return '<!-- Removed Javascript: ' . $ur . ' -->';
    }
    else {
        print "Include Javascript file $ur\n"
          if $self->{_DEBUG};

          my ( $content, $res, $md5 ) = grab_url( { -url => $ur } );
        if ( $res->is_success ) {
            print "Ok file downloaded\n"
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

sub include_javascript(\%$$) {
    my ( $self, $tmpl, $root ) = @_;

    # Ouch. My brain. Ouch.
    $tmpl =~ s/<script([^>]*)src\s*=\s*"?([^\" ]*js)"?([^>]*)>[^<]*<\/script>/$self->pattern_js($2,$1,$3,$root)/iegmx;
    if ( $self->{_remove_jscript} == 1 ) {

        # Old!
        # $tmpl=~s/<script([^>]*)>[^<]*<\/script>//iegmx;
        # New!
        $tmpl =~ s/<script([^>]*)>[\s\S]*?<\/script>//iegmx;
    }
    print "Done Javascript\n"
      if $self->{_DEBUG};
    return $tmpl;
}

#
sub cid (\%$) {
    my ( $self, $url ) = @_;

    require URI;

    my $filename = DADA::App::Guts::uriescape( ( URI->new($url)->path_segments )[-1] );

    # rfc say: don't use '/'. So I do a pack on it.
    # but as string can get long, I need to revert it to have
    # difference at begin of url to avoid max size of cid
    # I remove scheme always same in a document.
    $url = reverse( substr( $url, 7 ) );
    return reverse( split( "", unpack( "h" . length($url), $url ) ) ) . $filename;
}

sub build_mime_object {
    my ( $self, $html, $txt, $ref_mail ) = @_;

    my ( $txt_part, $part, $mail );

    # Create part for HTML if needed
    if ($html) {
        my $ref = ( $txt || @$ref_mail ) ? {} : $self->{_param};
        $part = new MIME::Lite(
            %$ref,
            'Type'     => 'TEXT',
            'Encoding' => $self->{_htmlencoding},
            'Data'     => safely_encode($html)
        );
        $part->attr( "content-type" => "text/html; charset=" . $self->{_htmlcharset} );

        # Remove some header for Eudora client in HTML and related part
        $part->replace( "MIME-Version"        => "" );
        $part->replace( 'X-Mailer'            => "" );
        $part->replace( 'Content-Disposition' => "" );

        # only html, no images & no txt
        $mail = $part unless ( $txt || @$ref_mail );
    }

    # Create part for text if needed
    if ($txt) {
        my $ref = ( $html ? {} : $self->{_param} );
        $txt_part = new MIME::Lite(
            %$ref,
            'Type'     => 'TEXT',
            'Data'     => safely_encode($txt),
            'Encoding' => $self->{_textencoding}
        );
        $txt_part->attr( "content-type" => "text/plain; charset=" . $self->{_textcharset} );

        # Remove some header for Eudora client
        $txt_part->replace( "MIME-Version"        => "" );
        $txt_part->replace( "X-Mailer"            => "" );
        $txt_part->replace( "Content-Disposition" => "" );

        # only text, no html

        $mail = $txt_part unless $html;    # unless html?

    }

    # If images and html and no text, multipart/related
    if ( @$ref_mail and !$txt ) {
        my $ref = $self->{_param};
        $$ref{'Type'} = "multipart/related";
        $mail = new MIME::Lite(%$ref);

        # Attach HTML part to related part
        $mail->attach($part);

        # Attach each image to related part
        foreach (@$ref_mail) { $mail->attach($_); }    # Attach list of part
        $mail->replace( "Content-Disposition" => "" );
    }

    # Else if html and text and no images, multipart/alternative
    elsif ( $txt and !@$ref_mail ) {
        my $ref = $self->{_param};
        $$ref{'Type'} = "multipart/alternative";
        $mail = new MIME::Lite(%$ref);
        $mail->attach($txt_part);                      # Attach text part
        $mail->attach($part);                          # Attach HTML part
    }

    # Else (html, txt and images) mutilpart/alternative
    elsif ( $txt && @$ref_mail ) {
        my $ref = $self->{_param};
        $$ref{'Type'} = "multipart/alternative";
        $mail = new MIME::Lite(%$ref);

        # Create related part
        my $rel = new MIME::Lite( 'Type' => 'multipart/related' );
        $rel->replace( "Content-transfer-encoding" => "" );
        $rel->replace( "MIME-Version"              => "" );
        $rel->replace( "X-Mailer"                  => "" );

        # Attach text part to alternative part
        $mail->attach($txt_part);

        # Attach HTML part to related part
        $rel->attach($part);

        # Attach each image to related part
        foreach (@$ref_mail) { $rel->attach($_); }

        # Attach related part to alternative part
        $mail->attach($rel);
    }

    #  $mail->replace('X-Mailer',"MIME::Lite::HTMLForked $VERSION");

    $self->{_MAIL} = $mail;

}

sub crop_html {
    
    
    my $self = shift;
    my $html = shift;

  #  warn 'crop_html'; 
  #  warn q{$self->{crop_html_content_selector_type}} . $self->{crop_html_content_selector_type}; 
  #  warn q{$self->{crop_html_content_selector_label}} . $self->{crop_html_content_selector_label}; 
  #  warn q{$self->{crop_html_content}} . $self->{crop_html_content}; 

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
        if ( $self->{crop_html_content_selector_type} eq 'id' ) {
            if ( $replace_tag = $root->look_down( "id", $self->{crop_html_content_selector_label} ) ) {
                $crop = $replace_tag->as_HTML( undef, '  ' );
            }
            else {
                warn 'cannot crop html: ' . 'cannot find id, ' . $self->{crop_html_content_selector_label};
                return $html;
            }
        }
        elsif ( $self->{crop_html_content_selector_type} eq 'class' ) {
            if ( $replace_tag = $root->look_down( "class", $self->{crop_html_content_selector_label} ) ) {
                $crop = $replace_tag->as_HTML( undef, '  ' );
            }
            else {
                warn 'cannot crop html: ' . 'cannot find class, ' . $self->{crop_html_content_selector_label};
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
        warn 'cannot crop html: ' . $_;
        return $html;
    };
}

1;

=pod

=head1 NAME

DADA::App::MyMIMELiteHTML

=head1 DESCRIPTION

This is a small small module that inherits almost everything from the CPAN, C<MIME::Lite::HTMLForked> module, but
overrides the method, C<absUrl> so it may work well with Dada Mail's Clickthrough Tracker's redirect tags, which look like this: 

 [redirect=http://yahoo.com]

=head1 More Information

The inheritence is done exactly as outlined in C<perltoot> 

http://perldoc.perl.org/perltoot.html#Inheritance

C<MIME::Lite::HTMLForked> can be found here: 

http://search.cpan.org/~alian/MIME-Lite-HTML/

Copyright (c) 1999 - 2015 Justin Simoni All rights reserved. 

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
