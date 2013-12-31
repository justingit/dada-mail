package DADA::App::MyMIMELiteHTML; 


use MIME::Lite::HTML;
@ISA = "MIME::Lite::HTML";

#use base "MIME::Lite::HTML"; 

use Carp qw(croak carp); 

## trés bizarre!
#sub MIME::Lite::HTML::absUrl($$) {
sub absUrl($$) { 	 
	my $str = shift; 
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
	
	  my $rep = eval { URI::WithBase->new($str, $base)->abs; };
	  return ($rep ? $rep : $str);
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
# looks sort of strange. Regardless - not the best design for MIME::Lite::HTML, unfortunetly. 

sub parse
  {
    my($self,$url_page,$url_txt,$url1)=@_;
    my ($type,@mail,$gabarit,$gabarit_txt,$racinePage);

    # Get content of $url_page with LWP
    if ($url_page && $url_page=~/^(https?|ftp|file|nntp):\/\//)
	{
        print "Get ", $url_page,"\n" if $self->{_DEBUG};	
        my $req = new HTTP::Request('GET' => $url_page);
        my $res = $self->{_AGENT}->request($req);
        if (!$res->is_success) 
	    {$self->set_err("Can't fetch $url_page (".$res->message.")");}
        else {$gabarit = $res->content;}
        $racinePage=$url1 || $res->base;
	}
    else {
		$gabarit=$url_page;
		$racinePage=$url1;
	}
    # Get content of $url_txt with LWP if needed
    if ($url_txt)
	{
	  if ($url_txt=~/^(https?|ftp|file|nntp):\/\//)
	    {
            print "Get ", $url_txt,"\n" if $self->{_DEBUG};
            my $req2 = new HTTP::Request('GET' => $url_txt);
            my $res3 = $self->{_AGENT}->request($req2);
            if (!$res3->is_success) 
		  {$self->set_err("Can't fetch $url_txt (".$res3->message.")");}
            else {$gabarit_txt = $res3->content;}
	    }
	  else {$gabarit_txt=$url_txt;}
          }
    goto BUILD_MESSAGE unless $gabarit;

    # Get all multimedia part (img, flash) for later create a MIME part 
    # for each of them
    my $analyseur = HTML::LinkExtor->new;
    $analyseur->parse($gabarit);
    my @l = $analyseur->links;

    # Include external CSS files
    $gabarit = $self->include_css($gabarit,$racinePage);

    # Include external Javascript files
    $gabarit = $self->include_javascript($gabarit,$racinePage);

    # Include form images
    ($gabarit,@mail) = $self->input_image($gabarit,$racinePage);

    # Change target action for form
    $gabarit = $self->link_form($gabarit,$racinePage);

    sub pattern_href {
      my ($url,$balise, $sep)=@_;
      my $b=" $balise=\"$url\"";
      $b.=$sep if ($sep ne '"' and $sep ne "'");
      return $b;
    }
    # Scan each part found by linkExtor
    my (%images_read,%url_remplace);
    for my $url (@l) {
	  my $urlAbs = absUrl($$url[2],$racinePage);
	  chomp $urlAbs; # Sometime a strange cr/lf occur

	  # Replace relative href found to absolute one
	  if ( ($$url[0] eq 'a') && ($$url[1] eq 'href') && ($$url[2]) &&
		 (($$url[2]!~m!^http://!)   && # un lien non absolu
		  ($$url[2]!~m!^mailto:!)   && # pas les mailto
		  ($$url[2]!~m!^\#!)        && # ni les ancres
		  ($$url[2]!~m!^\<!)        && # ni les tags du "Dada Mail" 
		  ($$url[2]!~m!^\[!) )      && # Hmm. meme chose. 
		 (!$url_remplace{$urlAbs}) ) # ni les urls deja remplacees
	    {
		$gabarit=~s/\s href \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
		           /pattern_href($urlAbs,"href",$1)/giemx;
		print "Replace ",$$url[2]," with ",$urlAbs,"\n" 
		  if ($self->{_DEBUG});
		$url_remplace{$urlAbs}=1;
	    }

	  # For frame & iframe
	  elsif ( (lc($$url[0] eq 'iframe') || lc($$url[0] eq 'frame')) &&
		   (lc($$url[1]) eq 'src') && ($$url[2]) )
	    {
		$gabarit=~s/\s src \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
		           /pattern_href($urlAbs,"src",$1)/giemx;
		print "Replace ",$$url[2]," with ",$urlAbs,"\n"
		  if ($self->{_DEBUG});
		$url_remplace{$urlAbs}=1;
	    }

	  # For background images
	  elsif ((lc($$url[1]) eq 'background') && ($$url[2])) {
	    # Replace relative url with absolute
	    my $v = ($self->{_include} eq 'cid') ?
	      "cid:".$self->cid($urlAbs) : $urlAbs;
	    $gabarit=~s/background \s* = \s* [\"']? \Q$$url[2]\E ([\"'>])
                       /pattern_href($v,"background",$1)/giemx;
            # Exit with extern configuration, don't include image
            # else add part to mail
	    if (($self->{_include} ne 'extern')&&(!$images_read{$urlAbs}))
		 {
		   $images_read{$urlAbs} = 1;
		   push(@mail, $self->create_image_part($urlAbs)); 
		 }
	   }

	  # For flash part (embed)
	  elsif (lc($$url[0]) eq 'embed' && $$url[4]) 
	   {
	     # rebuild $urlAbs
	     $urlAbs = absUrl($$url[4],$racinePage);
	     # Replace relative url with absolute
	     my $v = ($self->{_include} eq 'cid') ?
		 "cid:$urlAbs" : $urlAbs;
	     $gabarit=~s/src \s = \s [\"'] \Q$$url[4]\E ([\"'>])
                        /pattern_href($v,"src",$1)/giemx;
	     # Exit with extern configuration, don't include image
	     if (($self->{_include} ne 'extern')&&(!$images_read{$urlAbs}))
		 {
		   $images_read{$urlAbs}=1;
		   push(@mail, $self->create_image_part($urlAbs));
		 }
	   }

	  # For flash part (object)
	  # Need to add "param" to Tagset.pm in the linkElements definition:
	  # 'param' => ['name', 'value'],
	  # Tks to tosh@c4.ca for that
	  elsif (lc($$url[0]) eq 'param' && lc($$url[2]) eq 'movie' 
		 && $$url[4]) {
	    # rebuild $urlAbs
	    $urlAbs = absUrl($$url[4],$racinePage);
	    # Replace relative url with absolute
	    my $v = ($self->{_include} eq 'cid') ?
	      "cid:".$self->cid($urlAbs) : $urlAbs;
	    $gabarit=~s/value \s* = \s* [\"'] \Q$$url[4]\E ([\"'>])
                       /pattern_href($v,"value",$1)/giemx;
	    # Exit with extern configuration, don't include image
	    if (($self->{_include} ne 'extern')&&(!$images_read{$urlAbs}))
	      {
		$images_read{$urlAbs}=1;
		push(@mail, $self->create_image_part($urlAbs));
	      }
	  }

	  # For new images create part
	  # Exit with extern configuration, don't include image
	  elsif ( ($self->{_include} ne 'extern') &&
		    ((lc($$url[0]) eq 'img') || (lc($$url[0]) eq 'src')) &&
		    (!$images_read{$urlAbs})) {
	    $images_read{$urlAbs}=1;
	    push(@mail, $self->create_image_part($urlAbs));
	  }
	}

    # Replace in HTML link with image with cid:key
    sub pattern_image_cid {
      my $sel = shift;
      return '<img '.$_[0].'src="cid:'.$sel->cid(absUrl($_[1],$_[2])).'"';
    }
    # Replace relative url for image with absolute
    sub pattern_image {
      return '<img '.$_[0].'src="'.absUrl($_[1],$_[2]).'"';}

     # If cid choice, put a cid + absolute url on each link image
     if ($self->{_include} eq 'cid') 
       {$gabarit=~s/<img ([^<>]*) src\s*=\s*(["']?) ([^"'> ]* )(["']?)
	           /pattern_image_cid($self,$1,$3,$racinePage)/iegx;}
     # Else just make a absolute url
     else {$gabarit=~s/<img ([^<>]*) src\s*=\s*(["']?)([^"'> ]*) (["']?)
	              /pattern_image($1,$3,$racinePage)/iegx;}

   BUILD_MESSAGE:
    # Substitue value in template if needed
    if (scalar keys %{$self->{_HASH_TEMPLATE}}!=0)
	{
	  $gabarit=$self->fill_template($gabarit,$self->{_HASH_TEMPLATE}) 
	    if ($gabarit);
	  $gabarit_txt=$self->fill_template($gabarit_txt,
					    $self->{_HASH_TEMPLATE});
	}

    # Create MIME-Lite object
    $self->build_mime_object($gabarit, $gabarit_txt || undef,  \@mail);

    return $self->{_MAIL};
  }





#------------------------------------------------------------------------------
# include_css
#------------------------------------------------------------------------------
sub include_css(\%$$) {
  my ($self,$gabarit,$root)=@_;
  sub pattern_css {
    my ($self,$url,$milieu,$fin,$root)=@_;
    # if not stylesheet - rt19655
    if ($milieu!~/stylesheet/i && $fin!~/stylesheet/i) {
      return "<link".$milieu." href=\"$url\"".$fin.">";
    }
    # Don't store <LINK REL="SHORTCUT ICON"> tag. Tks to doggy@miniasp.com
    if ( $fin =~ m/shortcut/i || $milieu =~ m/shortcut/i ){ 
		return "<link" . $milieu . "href='". $url . "'" . $fin .">"; 
	}
    
	# Complete url
    my $ur = URI::URL->new($url, $root)->abs;
    print "Include CSS file $ur\n" if $self->{_DEBUG};
    my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur));
    
    if($res2->is_success()){ 
	
		print "Ok file downloaded\n" if $self->{_DEBUG};
	    return      '<style type="text/css">'."\n".
	      '<!--'."\n".$res2->content.
		"\n-->\n</style>\n";
	}
	else { 
	
		my $err = "Looking for css to include:, '" . $ur . "' was not successful - removing from message and ignoring"; 
		$self->set_err($err);
		carp $err; 
		
		# DEV: so, why was this returning an open <style> tag? 
		# Because that's dumb.
		return ''; #<style type="text/css">';	
		
	}

  }
  $gabarit=~s/<link ([^<>]*?)
                href\s*=\s*"?([^\" ]*)"?([^>]*)>
    /$self->pattern_css($2,$1,$3,$root)/iegmx;

  print "Done CSS\n" if ($self->{_DEBUG});
  return $gabarit;
}


#------------------------------------------------------------------------------
# include_javascript
#------------------------------------------------------------------------------

sub pattern_js {
   my ($self,$url,$milieu,$fin,$root)=@_;

   my $ur = URI::URL->new($url, $root)->abs;

	if($self->{_remove_jscript} == 1) { 
		# Why should I even try to get the files, if I'm just going to remove them?
		print "Removed Javascript file $ur\n" if $self->{_DEBUG};
		return '<!-- Removed Javascript: '. $ur . ' -->';
	}
	else { 
  	 	print "Include Javascript file $ur\n" 
			if $self->{_DEBUG};
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur));
		if($res2->is_success()){ 
			  my $content = $res2->content;
			    print "Ok file downloaded\n" 
					if $self->{_DEBUG};
			    return "\n"."<!-- $ur -->\n".
			      '<script '.$milieu.$fin.">\n".
				'<!--'."\n".$content.
				  "\n-->\n</script>\n";	
		}
		else { 
			my $err = "Looking for javascript to include:, '" . $ur . "' was not successful - removing from message and ignoring"; 
			$self->set_err($err);
			carp $err; 
			return "<!-- Couldn't Include Javasript: $ur -->\n";		    
		}
	}
 }

sub include_javascript(\%$$) {
	my ($self,$gabarit,$root)=@_;
	# Ouch. My brain. Ouch. 
	$gabarit=~s/<script([^>]*)src\s*=\s*"?([^\" ]*js)"?([^>]*)>[^<]*<\/script>/$self->pattern_js($2,$1,$3,$root)/iegmx;
	if ($self->{_remove_jscript} == 1) {
		# Old!
		# $gabarit=~s/<script([^>]*)>[^<]*<\/script>//iegmx;
		# New!
		$gabarit =~ s/<script([^>]*)>[\s\S]*?<\/script>//iegmx;
	}
	print "Done Javascript\n" 
		if $self->{_DEBUG};
	return $gabarit;
}


#
sub cid  (\%$) {
  my ($self, $url)=@_;

  require URI;
  require DADA::App::Guts; 

  my $filename = DADA::App::Guts::uriescape((URI->new($url)->path_segments)[-1]);

  # rfc say: don't use '/'. So I do a pack on it.
  # but as string can get long, I need to revert it to have
  # difference at begin of url to avoid max size of cid
  # I remove scheme always same in a document.
  $url = reverse(substr($url, 7));
  return reverse(split("",unpack("h".length($url),$url))) . $filename;
}








1;

=pod

=head1 NAME

DADA::App::MyMIMELiteHTML

=head1 DESCRIPTION

This is a small small module that inherits almost everything from the CPAN, C<MIME::Lite::HTML> module, but
overrides the method, C<absUrl> so it may work well with Dada Mail's Clickthrough Tracker's redirect tags, which look like this: 

 [redirect=http://yahoo.com]

=head1 More Information

The inheritence is done exactly as outlined in C<perltoot> 

http://perldoc.perl.org/perltoot.html#Inheritance

C<MIME::Lite::HTML> can be found here: 

http://search.cpan.org/~alian/MIME-Lite-HTML/

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
