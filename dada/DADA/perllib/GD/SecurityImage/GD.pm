package GD::SecurityImage::GD;
use strict;
use vars qw[$VERSION $methTTF];

use constant LOW_LEFT_X   => 0; # Lower left  corner x
use constant LOW_LEFT_Y   => 1; # Lower left  corner y
use constant LOW_RIGHT_X  => 2; # Lower right corner x
use constant LOW_RIGHT_Y  => 3; # Lower right corner y
use constant UP_RIGHT_X   => 4; # Upper right corner x
use constant UP_RIGHT_Y   => 5; # Upper right corner y
use constant UP_LEFT_X    => 6; # Upper left  corner x
use constant UP_LEFT_Y    => 7; # Upper left  corner y

use constant CH_X         => 0; # character-X
use constant CH_Y         => 1; # character-Y
use constant CHAR         => 2; # character
use constant ANGLE        => 3; # character angle

use constant MAX_COMPRESS => 9;

use GD;

$VERSION = '1.49';
$methTTF = $GD::VERSION >= 1.31 ? 'stringFT' : 'stringTTF'; # define the tff drawing method.

sub init {
   # Create the image object
   my $self = shift;
      $self->{image} = GD::Image->new($self->{width}, $self->{height});
      $self->cconvert($self->{bgcolor}); # set background color
      $self->setThickness($self->{thickness}) if $self->{thickness};
   if($GD::VERSION < 2.07) {
      $self->{DISABLED}{$_} = 1 foreach qw[ellipse setThickness _png_compression];
   }
}

sub out {
   # return $image_data, $image_mime_type, $random_number
   my $self = shift;
   my %opt  = scalar @_ % 2 ? () : (@_);
   my $type;
   if($opt{force} and $self->{image}->can($opt{force})){
      $type = $opt{force};
   } else {
      # define the output format. png is first due to various problems with gif() format
      foreach (qw( png gif jpeg )) {
         if($self->{image}->can($_)) {
            $type = $_;
            last;
         }
      }
   }
   my @args = ();
   if ($opt{'compress'}) {
      push @args, MAX_COMPRESS     if $type eq 'png' and not $self->{DISABLED}{_png_compression};
      push @args, $opt{'compress'} if $type eq 'jpeg';
   }
   return $self->{image}->$type(@args), $type, $self->{_RANDOM_NUMBER_};
}

sub gdbox_empty {shift->{GDBOX_EMPTY}}

sub gdfx {
   # Sets the font for simple GD usage. 
   # Unfortunately, Image::Magick does not have a similar interface.
   my $self = shift;
   my $font = shift || return;
      $font = lc $font;
   # GD' s standard fonts
   my %f = map { lc $_ => $_ } qw[ Small Large MediumBold Tiny Giant ];
   if (exists $f{$font}) {
      $font = $f{$font};
      return GD::Font->$font();
   }
}

sub insert_text {
   # Draw text using GD
   my $self   = shift;
   my $method = shift;
   my $key    = $self->{_RANDOM_NUMBER_}; # random string
   if ($method eq 'ttf') {
      require Math::Trig;
      # don' t draw. we just need info...
      my $info = sub {
         my $txt = shift;
         my $ang = shift || 0;
            $ang = Math::Trig::deg2rad($ang) if $ang;
         my @box = GD::Image->$methTTF($self->{_COLOR_}{text},$self->{font},$self->{ptsize},$ang,0,0,$txt);
         unless (@box) { # use fake values instead of die-ing
            $self->{GDBOX_EMPTY} = 1; # set this for error checking.
            $#box    = 7;
            # lets initialize to silence the warnings
            $box[$_] = 1 for 0..$#box;
         }
         return @box;
      };
      if ($self->{scramble}) {
         my @char;
         my $anglex;
         my $total = 0;
         my $space = [$self->ttf_info(0, 'A'),0,'  '];
         my @randomy;
         my $sy = $space->[CH_Y] || 1;
         push(@randomy,  $_, - $_) foreach $sy*1.2,$sy, $sy/2, $sy/4, $sy/8;
         foreach (split //, $key) { # get char parameters
            $anglex = $self->random_angle;
            $total += $space->[CH_X];
            push @char, [$self->ttf_info($anglex, $_), $anglex, $_], $space, $space, $space;
         }
         $total *= 2;
         my @config = ($self->{_COLOR_}{text}, $self->{font}, $self->{ptsize});
         my($x,$y);
         foreach my $box (reverse @char) {
            $x  = $self->{width}  / 2 + ($box->[CH_X] - $total);
            $y  = $self->{height} / 2 +  $box->[CH_Y];
            $y += $randomy[int rand @randomy];
            $self->{image}->$methTTF(@config, Math::Trig::deg2rad($box->[CHAR]), $x, $y, $box->[ANGLE]);
            $total -= $space->[CH_X];
         }
      } else {
         my(@box,$x,$y);
         my $tl = $self->{_TEXT_LOCATION_};
         if ($tl->{_place_}) {
            # put the text to one of the four corners in the image
            my $white = $self->cconvert([255,255,255]);
            my $black = $self->cconvert($self->{_COLOR_}{text});
            if ($tl->{gd}) { # draw with standard gd fonts
               $self->place_gd($key, $tl->{x}, $tl->{y});
               return; # by-pass ttf method call...
            } else {
               @box = $info->($key);
               $x   = $tl->{x} eq 'left'? 0                                    : ($self->{width}  - ($box[LOW_RIGHT_X] - $box[LOW_LEFT_X]));
               $y   = $tl->{y} eq 'up'  ? ($box[LOW_LEFT_Y] - $box[UP_LEFT_Y]) :  $self->{height}-2;
               if ($tl->{strip}) {
                  $self->add_strip($x, $y, $box[LOW_RIGHT_X] - $box[LOW_LEFT_X], $box[LOW_LEFT_Y] - $box[UP_LEFT_Y]);
               }
            }
         } else {
            @box = $info->($key);
            $x = ($self->{width}  - ($box[LOW_RIGHT_X] - $box[LOW_LEFT_X])) / 2;
            $y = ($self->{height} - ($box[UP_LEFT_Y]   - $box[LOW_LEFT_Y])) / 2;
         }
         # this needs a fix. adjust x,y
         if ($self->{angle}) {
            require Math::Trig;
            $self->{angle} = Math::Trig::deg2rad($self->{angle});
         } else {
            $self->{angle} = 0;
         }
         $self->{image}->$methTTF($self->{_COLOR_}{text}, $self->{font}, $self->{ptsize}, $self->{angle}, $x, $y, $key);
      }
   } else {
      if ($self->{scramble}) {
         # without ttf, we can only have 0 and 90 degrees.
         my @char;
         my @styles = qw(string stringUp);
         my $style  = $styles[int rand @styles];
         foreach (split //, $key) { # get char parameters
            push @char, [$_, $style], [' ','string'];
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
            $self->{image}->$m($self->{gd_font}, $x, $y, $c->[0], $self->{_COLOR_}{text});
         }
      } else {
         my $sw = $self->{gd_font}->width * length($key);
         my $sh = $self->{gd_font}->height;
         my $x  = ($self->{width}  - $sw) / 2;
         my $y  = ($self->{height} - $sh) / 2;
         $self->{image}->string($self->{gd_font}, $x, $y, $key, $self->{_COLOR_}{text});
      }
   }
}

sub place_gd {
   my $self  = shift;
   my($key, $tX, $tY) = @_;
   my $tl    = $self->{_TEXT_LOCATION_};
   my $black = $self->cconvert($self->{_COLOR_}{text});
   my $white = $self->cconvert($tl->{scolor});
   my $font  = GD::Font->Tiny;
   my $fx    = (length($key)+1)*$font->width;
   my $x1    = $self->{width} - $fx;
   my $y1    = $tY eq 'up' ? 0 : $self->{height} - $font->height;
   if ($tY eq 'up') {
      if($tX eq 'left') {
         $self->filledRectangle(0, $y1  , $fx  , $font->height+2, $black);
         $self->filledRectangle(1, $y1+1, $fx-1, $font->height+1, $white);
      } else {
         $self->filledRectangle($x1-$font->width - 1, $y1  , $self->{width}  , $font->height+2, $black);
         $self->filledRectangle($x1-$font->width    , $y1+1, $self->{width}-2, $font->height+1, $white);
      }
   } else {
      if($tX eq 'left') {
         $self->filledRectangle(0, $y1-2, $fx  , $self->{height}  , $black);
         $self->filledRectangle(1    , $y1-1, $fx-1, $self->{height}-2, $white);
      } else {
         $self->filledRectangle($x1-$font->width - 1, $y1-2, $self->{width}  , $self->{height}  , $black);
         $self->filledRectangle($x1-$font->width    , $y1-1, $self->{width}-2, $self->{height}-2, $white);
      }
   }
   $self->{image}->string($font, $tX eq 'left' ? 2 : $x1, $tY eq 'up' ? $y1+1 : $y1-1, $key, $self->{_COLOR_}{text});
}

sub ttf_info {
   my $self  = shift;
   my $angle = shift || 0;
   my $text  = shift;
   my $x     = 0;
   my $y     = 0;
   my @box   = GD::Image->$methTTF($self->{_COLOR_}{text},$self->{font}, $self->{ptsize},Math::Trig::deg2rad($angle),0,0,$text);
   unless (@box) { # use fake values instead of die-ing
      $self->{GDBOX_EMPTY} = 1; # set this for error checking.
      $#box    = 7;
      # lets initialize to silence the warnings
      $box[$_] = 1 for 0..$#box;
   }
   my $bx    = $box[LOW_LEFT_X] - $box[LOW_RIGHT_X];
   my $by    = $box[LOW_LEFT_Y] - $box[LOW_RIGHT_Y];

   if($angle == 0 or $angle == 180 or $angle == 360) {
      $by  = $box[  UP_LEFT_Y ] - $box[LOW_LEFT_Y ];
   } elsif ($angle == 90 or $angle == 270) {
      $bx  = $box[  UP_LEFT_X ] - $box[LOW_LEFT_X ];
   } elsif($angle > 270 and $angle < 360) {
      $bx  = $box[ LOW_LEFT_X ] - $box[ UP_LEFT_X ];
   } elsif ($angle > 180 and $angle < 270) {
      $by  = $box[ LOW_LEFT_Y ] - $box[LOW_RIGHT_Y];
      $bx  = $box[ LOW_RIGHT_X] - $box[ UP_RIGHT_X];
   } elsif($angle > 90 and $angle < 180) {
      $bx  = $box[ LOW_RIGHT_X] - $box[ LOW_LEFT_X];
      $by  = $box[ LOW_RIGHT_Y] - $box[ UP_RIGHT_Y];
   } elsif ($angle > 0 and $angle < 90) {
      $by  = $box[  UP_LEFT_Y ] - $box[ LOW_LEFT_Y];
   } else {}

      if ($angle ==   0                 ) { $x += $bx/2; $y -= $by/2; }
   elsif ($angle >    0 and $angle < 90 ) { $x += $bx/2; $y -= $by/2; }
   elsif ($angle ==  90                 ) { $x -= $bx/2; $y += $by/2; }
   elsif ($angle >   90 and $angle < 180) { $x -= $bx/2; $y += $by/2; }
   elsif ($angle == 180                 ) { $x += $bx/2; $y -= $by/2; }
   elsif ($angle >  180 and $angle < 270) { $x += $bx/2; $y += $by/2; }
   elsif ($angle == 270                 ) { $x -= $bx/2; $y += $by/2; }
   elsif ($angle >  270 and $angle < 360) { $x += $bx/2; $y += $by/2; }
   elsif ($angle == 360                 ) { $x += $bx/2; $y -= $by/2; }
   return $x, $y;
}

sub setPixel        {shift->{image}->setPixel(@_)       }
sub line            {shift->{image}->line(@_)           }
sub rectangle       {shift->{image}->rectangle(@_)      }
sub filledRectangle {shift->{image}->filledRectangle(@_)}
sub ellipse         {shift->{image}->ellipse(@_)        }
sub arc             {shift->{image}->arc(@_)            }

sub setThickness {
   my $self = shift;
   if($self->{image}->can('setThickness')) { # $GD::VERSION >= 2.07
      $self->{image}->setThickness(@_);
   }
}

1;

__END__

=head1 NAME

GD::SecurityImage::GD - GD backend for GD::SecurityImage.

=head1 SYNOPSIS

See L<GD::SecurityImage>.

=head1 DESCRIPTION

Used internally by L<GD::SecurityImage>. Nothing public here.

=head1 SEE ALSO

L<GD::SecurityImage>.

=head1 AUTHOR

Burak Gürsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004-2006 Burak Gürsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself, either Perl version 5.8.7 or, 
at your option, any later version of Perl 5 you may have available.

=cut
