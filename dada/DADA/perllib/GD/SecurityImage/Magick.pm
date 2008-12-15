package GD::SecurityImage::Magick;
# GD method emulation class for Image::Magick
use strict;
use vars qw[$VERSION];

use constant X_PPEM       => 0; # character width 
use constant Y_PPEM       => 1; # character height
use constant ASCENDER     => 2; # ascender
use constant DESCENDER    => 3; # descender
use constant WIDTH        => 4; # text width
use constant HEIGHT       => 5; # text height
use constant MAX_ADVANCE  => 6; # maximum horizontal advance

use constant ANGLE        => -2;
use constant CHAR         => -1;

use constant MAX_COMPRESS => 100;

use Image::Magick;

$VERSION = '1.36';

sub init {
   # Create the image object
   my $self = shift;
   my $bg   = $self->cconvert($self->{bgcolor}); 
      $self->{image} = Image::Magick->new;
      $self->{image}->Set(size=> "$self->{width}x$self->{height}");
      $self->{image}->Read('null:' . $bg);
      $self->{image}->Set(background => $bg);
      $self->{MAGICK} = {strokewidth => 0.6};
      $self->setThickness($self->{thickness}) if $self->{thickness};
}

sub out {
   my $self = shift;
   my %opt  = scalar @_ % 2 ? () : (@_);
   my $type = 'gif'; # default format
   if ($opt{force}) {
      my %g = map {$_, 1} $self->{image}->QueryFormat;
      $type = $opt{force} if exists $g{$opt{force}};
   }
   $self->{image}->Set(magick => $type);
   if ($opt{'compress'} and $type =~ m[^(png|jpeg)$]) {
      if($type eq 'png') {
         $opt{'compress'} = MAX_COMPRESS;
         $self->{image}->Set(compression => 'Zip');
      }
      $self->{image}->Set(quality => $opt{'compress'});
   }
   return $self->{image}->ImageToBlob, $type, $self->{_RANDOM_NUMBER_};
}

sub insert_text {
   # Draw text using Image::Magick
   my $self   = shift;
   my $method = shift; # not needed with Image::Magick (always use ttf)
   my $key    = $self->{_RANDOM_NUMBER_}; # random string
   my $info   = sub {$self->{image}->QueryFontMetrics(font => $self->{font}, text => shift, pointsize => $self->{ptsize})};
   my %same   = (font      => $self->{font},
                 encoding  => 'UTF-8',
                 pointsize => $self->{ptsize},
                 fill      => $self->cconvert($self->{_COLOR_}{text}),
   );
   if ($self->{scramble}) {
      my $space = [$info->(' '), 0, ' ']; # get " " parameters
      my @randomy;
      my $sy = $space->[ASCENDER] || 1;
      push(@randomy,  $_, - $_) foreach $sy/2, $sy/4, $sy/8;
      my @char;
      foreach (split //, $key) {
         push @char, [$info->($_), $self->random_angle, $_], $space, $space, $space;
      }
      my $total = 0;
         $total += $_->[WIDTH] foreach @char;
      foreach my $magick (@char) {
         $total -= $magick->[WIDTH] * 2;
         $self->{image}->Annotate(text   => $magick->[CHAR],
                                  x      =>  ($self->{width}  - $total - $magick->[WIDTH]   ) / 2,
                                  y      => (($self->{height}          + $magick->[ASCENDER]) / 2) + $randomy[int rand @randomy],
                                  rotate => $magick->[ANGLE],
                                  %same);
      }
   } else {
      my @metric = $info->($key);
      my($x, $y);
      my $tl = $self->{_TEXT_LOCATION_};
      if ($tl->{_place_}) {
         # put the text to one of the four corners in the image
         $x = $tl->{x} eq 'left' ? 2                   : $self->{width}-$metric[WIDTH]-2;
         $y = $tl->{y} eq 'up'   ? $metric[ASCENDER]+1 : $self->{height}-2;
         $self->add_strip($x, $y, $metric[WIDTH], $metric[ASCENDER]) if $tl->{strip};
      } else {
         $x = ($self->{width}  - $metric[WIDTH]   ) / 2;
         $y = ($self->{height} + $metric[ASCENDER]) / 2;
      }
      $self->{image}->Annotate(%same,
         text   => $key, 
         x      => $x, 
         y      => $y,
         rotate => $self->{angle} ? 360 - $self->{angle} : 0,
      );
   }
}

sub setPixel {
   my $self = shift;
   my($x, $y, $color) = @_;
   $self->{image}->Set("pixel[$x,$y]" => $self->cconvert($color) );
}

sub line {
   my $self = shift;
   my($x1, $y1, $x2, $y2, $color) = @_;
      $self->{image}->Draw(
         primitive   => "line",
         points      => "$x1,$y1 $x2,$y2",
         stroke      => $self->cconvert($color),
         strokewidth => $self->{MAGICK}{strokewidth},
      );
}

sub rectangle {
   my $self = shift;
   my($x1,$y1,$x2,$y2,$color) = @_;
      $self->{image}->Draw(
         primitive   => "rectangle",
         points      => "$x1,$y1 $x2,$y2",
         stroke      => $self->cconvert($color),
         strokewidth => $self->{MAGICK}{strokewidth},
      );
}

sub filledRectangle {
   my $self = shift;
   my($x1,$y1,$x2,$y2,$color) = @_;
      $self->{image}->Draw(
         primitive   => "rectangle",
         points      => "$x1,$y1 $x2,$y2",
         fill        => $self->cconvert($color),
         stroke      => $self->cconvert($color),
         strokewidth => 0,
      );
}

sub ellipse {
   my $self = shift;
   my($cx,$cy,$width,$height,$color) = @_;
      $self->{image}->Draw(
         primitive   => "ellipse",
         points      => "$cx,$cy $width,$height 0,360",
         stroke      => $self->cconvert($color),
         strokewidth => $self->{MAGICK}{strokewidth},
      );
}

sub arc {
   my $self = shift;
   my($cx,$cy,$width,$height,$start,$end,$color) = @_;
      $self->{image}->Draw(
         primitive   => "ellipse", # I couldn't do that with "arc" primitive. patches are welcome, but this seems to work :)
         points      => "$cx,$cy $width,$height $start,$end",
         stroke      => $self->cconvert($color),
         strokewidth => $self->{MAGICK}{strokewidth},
      );
}

sub setThickness {
   my $self = shift;
   my $thickness = shift;
   $self->{MAGICK}{strokewidth} = $thickness * $self->{MAGICK}{strokewidth} if $thickness;
}

1;

__END__

=head1 NAME

GD::SecurityImage::Magick -  Image::Magick backend for GD::SecurityImage.

=head1 SYNOPSIS

See L<GD::SecurityImage>.

=head1 DESCRIPTION

Includes GD method emulations for Image::Magick.

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
