package GD::SecurityImage::GD;
use strict;
use warnings;
use vars qw( $VERSION );

use constant LOWLEFTX    => 0; # Lower left  corner x
use constant LOWLEFTY    => 1; # Lower left  corner y
use constant LOWRIGHTX   => 2; # Lower right corner x
use constant LOWRIGHTY   => 3; # Lower right corner y
use constant UPRIGHTX    => 4; # Upper right corner x
use constant UPRIGHTY    => 5; # Upper right corner y
use constant UPLEFTX     => 6; # Upper left  corner x
use constant UPLEFTY     => 7; # Upper left  corner y

use constant CHX         => 0; # character-X
use constant CHY         => 1; # character-Y
use constant CHAR        => 2; # character
use constant ANGLE       => 3; # character angle

use constant MAXCOMPRESS => 9;

use constant NEWSTUFF    => qw( ellipse setThickness _png_compression );
# png is first due to various problems with gif() format
use constant FORMATS     => qw( png gif jpeg );
use constant GDFONTS     => qw( Small Large MediumBold Tiny Giant );

use constant RGB_WHITE   => (255, 255, 255);
use constant BOX_SIZE    => 7;

use constant ROTATE_NONE             =>   0;
use constant ROTATE_COUNTERCLOCKWISE =>  90;
use constant ROTATE_UPSIDEDOWN       => 180;
use constant ROTATE_CLOCKWISE        => 270;
use constant FULL_CIRCLE             => 360;

use GD;

$VERSION = '1.72';

# define the tff drawing method.
my $TTF = __PACKAGE__->_versiongt( '1.31' ) ? 'stringFT' : 'stringTTF';

sub init {
   # Create the image object
   my $self = shift;
   $self->{image} = GD::Image->new($self->{width}, $self->{height});
   $self->cconvert($self->{bgcolor}); # set background color
   $self->setThickness($self->{thickness}) if $self->{thickness};
   if ( $self->_versionlt( '2.07' ) ) {
      foreach my $prop ( NEWSTUFF ) {
         $self->{DISABLED}{$prop} = 1;
      }
   }
   return;
}

sub out {
   # return $image_data, $image_mime_type, $random_number
   my($self, @args) = @_;
   my %opt  = @args % 2 ? () : @args;
   my $i    = $self->{image};
   my $type;
   if ( $opt{force} && $i->can($opt{force}) ){
      $type = $opt{force};
   }
   else {
      # Define the output format. 
      foreach my $f ( FORMATS ) {
         if ( $i->can( $f ) ) {
            $type = $f;
            last;
         }
      }
   }

   my @iargs = ();
   if ( $opt{'compress'} ) {
      push @iargs, MAXCOMPRESS      if $type eq 'png' and not $self->{DISABLED}{_png_compression};
      push @iargs, $opt{'compress'} if $type eq 'jpeg';
   }
   return $i->$type(@iargs), $type, $self->{_RANDOM_NUMBER_};
}

sub gdbox_empty { return shift->{GDBOX_EMPTY} }

sub gdfx {
   # Sets the font for simple GD usage. 
   # Unfortunately, Image::Magick does not have a similar interface.
   my $self = shift;
   my $font = shift || return;
      $font = lc $font;
   # GD' s standard fonts
   my %f = map { lc $_ => $_ } GDFONTS;
   if ( exists $f{$font} ) {
      $font = $f{$font};
      return GD::Font->$font();
   }
}

sub _insert_text_ttf_scramble {
   my($self, $key, $ctext) = @_;
   require Math::Trig;

         my @char;
         my $anglex;
         my $total = 0;
         my $space = [ $self->ttf_info( 0, 'A' ), 0, q{  } ];
         my @randomy;
         my $sy = $space->[CHY] || 1;
         ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
         push @randomy,  $_, - $_ foreach $sy*1.2,$sy, $sy/2, $sy/4, $sy/8;
         ## use critic
         foreach (split m{}xms, $key) { # get char parameters
            $anglex = $self->random_angle;
            $total += $space->[CHX];
            push @char, [$self->ttf_info($anglex, $_), $anglex, $_], $space, $space, $space;
         }
         $total *= 2;
         my @config = ($ctext, $self->{font}, $self->{ptsize});
         my($x,$y);
         foreach my $box (reverse @char) {
            $x  = $self->{width}  / 2 + ($box->[CHX] - $total);
            $y  = $self->{height} / 2 +  $box->[CHY];
            $y += $randomy[int rand @randomy];
            $self->{image}->$TTF(@config, Math::Trig::deg2rad($box->[CHAR]), $x, $y, $box->[ANGLE]);
            $total -= $space->[CHX];
         }
   return;
}

sub _insert_text_ttf_normal {
   my($self, $key, $ctext) = @_;
   require Math::Trig;
   # don' t draw. we just need info...
   my $info = sub {
      my $txt = shift;
      my $ang = shift || 0;
         $ang = Math::Trig::deg2rad($ang) if $ang;
      my @box = GD::Image->$TTF(
                  $ctext, $self->{font}, $self->{ptsize}, $ang, 0, 0, $txt
               );
      if ( not @box ) { # use fake values instead of die-ing
         $self->{GDBOX_EMPTY} = 1; # set this for error checking.
         $#box = BOX_SIZE;
         # lets initialize to silence the warnings
         $box[$_] = 1 for 0..$#box;
      }
      return @box;
   };

   my(@box, $x, $y);
   my $tl = $self->{_TEXT_LOCATION_};
   if ( $tl->{_place_} ) {
      # put the text to one of the four corners in the image
      my $white = $self->cconvert( [ RGB_WHITE ] );
      my $black = $self->cconvert($ctext);
      if ( $tl->{gd} ) { # draw with standard gd fonts
         $self->place_gd($key, $tl->{x}, $tl->{y});
         return; # by-pass ttf method call...
      }
      else {
         @box = $info->($key);
         $x   = $tl->{x} eq 'left'
               ? 0
               : ( $self->{width} - ($box[LOWRIGHTX] - $box[LOWLEFTX]) )
               ;
         $y   = $tl->{y} eq 'up'
               ? ( $box[LOWLEFTY] - $box[UPLEFTY] )
               :  $self->{height} - 2
               ;
         if ($tl->{strip}) {
            $self->add_strip(
               $x, $y, $box[LOWRIGHTX] - $box[LOWLEFTX], $box[LOWLEFTY] - $box[UPLEFTY]
            );
         }
      }
   }
   else {
      @box = $info->($key);
      $x   = ($self->{width}  - ($box[LOWRIGHTX] - $box[LOWLEFTX])) / 2;
      $y   = ($self->{height} - ($box[UPLEFTY]   - $box[LOWLEFTY])) / 2;
   }

   # this needs a fix. adjust x,y
   $self->{angle} = $self->{angle} ? Math::Trig::deg2rad($self->{angle}) : 0;
   $self->{image}->$TTF( $ctext, $self->{font}, $self->{ptsize}, $self->{angle}, $x, $y, $key );
   return;
}

sub _insert_text_gd_scramble {
   my($self, $key, $ctext) = @_;
   # without ttf, we can only have 0 and 90 degrees.
   my @char;
   my @styles = qw(string stringUp);
   my $style  = $styles[int rand @styles];
   foreach (split m{}xms, $key) { # get char parameters
      push @char, [ $_, $style ], [ q{ }, 'string' ];
      $style = $style eq 'string' ? 'stringUp' : 'string';
   }
   my $sw = $self->{gd_font}->width;
   my $sh = $self->{gd_font}->height;
   my($x, $y, $m);
   my $total = $sw * @char;
   foreach my $c (@char) {
      $m = $c->[1];
      $x = ($self->{width}  - $total) / 2;
      $y = $self->{height}/2 + ($m eq 'string' ? -$sh : $sh/2) / 2;
      $total -= $sw * 2;
      $self->{image}->$m($self->{gd_font}, $x, $y, $c->[0], $ctext);
   }
   return;
}

sub _insert_text_gd_normal {
   my($self, $key, $ctext) = @_;
   my $sw = $self->{gd_font}->width * length $key;
   my $sh = $self->{gd_font}->height;
   my $x  = ($self->{width}  - $sw) / 2;
   my $y  = ($self->{height} - $sh) / 2;
   $self->{image}->string($self->{gd_font}, $x, $y, $key, $ctext);
   return;
}

sub insert_text {
   # Draw text using GD
   my $self   = shift;
   my $method = shift;
   my $key    = $self->{_RANDOM_NUMBER_};
   my $ctext  = $self->{_COLOR_}{text};
   if ($method eq 'ttf') {
      $self->{scramble} ? $self->_insert_text_ttf_scramble( $key, $ctext )
                        : $self->_insert_text_ttf_normal(   $key, $ctext )
                        ;
   }
   else {
      $self->{scramble} ? $self->_insert_text_gd_scramble( $key, $ctext )
                        : $self->_insert_text_gd_normal(   $key, $ctext )
                        ;
   }
   return;
}

sub place_gd {
   my($self, $key, $tx, $ty) = @_;
   my $tl    = $self->{_TEXT_LOCATION_};
   my $black = $self->cconvert($self->{_COLOR_}{text});
   my $white = $self->cconvert($tl->{scolor});
   my $font  = GD::Font->Tiny;
   my $fx    = (length($key)+1)*$font->width;
   my $x1    = $self->{width} - $fx;
   my $y1    = $ty eq 'up' ? 0 : $self->{height} - $font->height;
   if ($ty eq 'up') {
      if($tx eq 'left') {
         $self->filledRectangle(0, $y1  , $fx  , $font->height+2, $black);
         $self->filledRectangle(1, $y1+1, $fx-1, $font->height+1, $white);
      }
      else {
         $self->filledRectangle($x1-$font->width - 1, $y1  , $self->{width}  , $font->height+2, $black);
         $self->filledRectangle($x1-$font->width    , $y1+1, $self->{width}-2, $font->height+1, $white);
      }
   }
   else {
      if($tx eq 'left') {
         $self->filledRectangle(0, $y1-2, $fx  , $self->{height}  , $black);
         $self->filledRectangle(1    , $y1-1, $fx-1, $self->{height}-2, $white);
      }
      else {
         $self->filledRectangle($x1-$font->width - 1, $y1-2, $self->{width}  , $self->{height}  , $black);
         $self->filledRectangle($x1-$font->width    , $y1-1, $self->{width}-2, $self->{height}-2, $white);
      }
   }
   return $self->{image}->string(
            $font,
            $tx eq 'left' ? 2     : $x1,
            $ty eq 'up'   ? $y1+1 : $y1-1,
            $key,
            $self->{_COLOR_}{text}
         );
}

sub ttf_info {
   my $self  = shift;
   my $angle = shift || 0;
   my $text  = shift;
   require Math::Trig;
   my @box = GD::Image->$TTF(
               $self->{_COLOR_}{text},
               $self->{font},
               $self->{ptsize},
               Math::Trig::deg2rad($angle),
               0,
               0,
               $text
            );
   if ( not @box ) { # use fake values instead of die-ing
      $self->{GDBOX_EMPTY} = 1; # set this for error checking.
      $#box = BOX_SIZE;
      # lets initialize to silence the warnings
      $box[$_] = 1 for 0..$#box;
   }

   return $self->_ttf_info_xy( $angle, \@box );
}

sub _ttf_info_xy {
   my($self, $angle, $box) = @_;
   my $rnone = ROTATE_NONE;
   my $rccw  = ROTATE_COUNTERCLOCKWISE;
   my $rusd  = ROTATE_UPSIDEDOWN;
   my $rcw   = ROTATE_CLOCKWISE;
   my $fc    = FULL_CIRCLE;

   my $x     = 0;
   my $y     = 0;

   my($bx, $by) = $self->_ttf_info_box_xy( $angle, $box );

     $angle == $rnone                   ? do { $x += $bx/2; $y -= $by/2; }
   : $angle >  $rnone && $angle < $rccw ? do { $x += $bx/2; $y -= $by/2; }
   : $angle == $rccw                    ? do { $x -= $bx/2; $y += $by/2; }
   : $angle >  $rccw  && $angle < $rusd ? do { $x -= $bx/2; $y += $by/2; }
   : $angle == $rusd                    ? do { $x += $bx/2; $y -= $by/2; }
   : $angle >  $rusd  && $angle < $rcw  ? do { $x += $bx/2; $y += $by/2; }
   : $angle == $rcw                     ? do { $x -= $bx/2; $y += $by/2; }
   : $angle >  $rcw   && $angle < $fc   ? do { $x += $bx/2; $y += $by/2; }
   : $angle == $fc                      ? do { $x += $bx/2; $y -= $by/2; }
   :                                      do {}
   ;
   return $x, $y;
}

sub _ttf_info_box_xy {
   my($self, $angle, $box) = @_;
   my $bx    = $box->[LOWLEFTX] - $box->[LOWRIGHTX];
   my $by    = $box->[LOWLEFTY] - $box->[LOWRIGHTY];

   my $rnone = ROTATE_NONE;
   my $rccw  = ROTATE_COUNTERCLOCKWISE;
   my $rusd  = ROTATE_UPSIDEDOWN;
   my $rcw   = ROTATE_CLOCKWISE;
   my $fc    = FULL_CIRCLE;

   my $is_perp = $angle == $rnone || $angle == $rusd || $angle == $fc;

     $is_perp                             ? do { $by = $box->[  UPLEFTY ] - $box->[LOWLEFTY ]; }
   : $angle == $rccw  || $angle == $rcw   ? do { $bx = $box->[  UPLEFTX ] - $box->[LOWLEFTX ]; }
   : $angle >  $rcw   && $angle <  $fc    ? do { $bx = $box->[ LOWLEFTX ] - $box->[ UPLEFTX ]; }
   : $angle >  $rusd  && $angle <  $rcw   ? do { $bx = $box->[ LOWRIGHTX] - $box->[ UPRIGHTX]; $by = $box->[ LOWLEFTY ] - $box->[LOWRIGHTY]; }
   : $angle >  $rccw  && $angle <  $rusd  ? do { $bx = $box->[ LOWRIGHTX] - $box->[ LOWLEFTX]; $by = $box->[ LOWRIGHTY] - $box->[ UPRIGHTY]; }
   : $angle >  $rnone && $angle <  $rccw  ? do { $by = $box->[  UPLEFTY ] - $box->[ LOWLEFTY]; }
   :                                        do {}
   ;

   return $bx, $by;
}

sub setPixel { ## no critic (NamingConventions::Capitalization)
   my($self, @args) = @_;
   return $self->{image}->setPixel(@args);
}

sub line {
   my($self, @args) = @_;
   return $self->{image}->line(@args);
}

sub rectangle {
   my($self, @args) = @_;
   return $self->{image}->rectangle(@args);
}

sub filledRectangle { ## no critic (NamingConventions::Capitalization)
   my($self, @args) = @_;
   return $self->{image}->filledRectangle(@args);
}

sub ellipse {
   my($self, @args) = @_;
   return $self->{image}->ellipse(@args);
}

sub arc {
   my($self, @args) = @_;
   return $self->{image}->arc(@args);
}

sub setThickness { ## no critic (NamingConventions::Capitalization)
   my($self, @args) = @_;
   if( $self->{image}->can('setThickness') ) { # $GD::VERSION >= 2.07
      $self->{image}->setThickness( @args );
   }
   return;
}

sub _versiongt {
   my $self   = shift;
   my $check  = shift || 0;
      $check += 0;
   return $GD::VERSION >= $check ? 1 : 0;
}

sub _versionlt {
   my $self   = shift;
   my $check  = shift || 0;
      $check += 0;
   return $GD::VERSION < $check ? 1 : 0;
}

1;

__END__

=head1 NAME

GD::SecurityImage::GD - GD backend for GD::SecurityImage.

=head1 SYNOPSIS

See L<GD::SecurityImage>.

=head1 DESCRIPTION

This document describes version C<1.72> of C<GD::SecurityImage::GD>
released on C<27 August 2012>.

Used internally by L<GD::SecurityImage>. Nothing public here.

=head1 METHODS

=head2 arc

=head2 ellipse

=head2 filledRectangle

=head2 gdbox_empty

=head2 gdfx

=head2 init

=head2 insert_text

=head2 line

=head2 out

=head2 place_gd

=head2 rectangle

=head2 setPixel

=head2 setThickness

=head2 ttf_info

=head1 SEE ALSO

L<GD::SecurityImage>.

=head1 AUTHOR

Burak Gursoy <burak@cpan.org>.

=head1 COPYRIGHT

Copyright 2004 - 2012 Burak Gursoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.
=cut
