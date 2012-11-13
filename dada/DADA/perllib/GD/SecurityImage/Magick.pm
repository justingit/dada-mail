package GD::SecurityImage::Magick;
# GD method emulation class for Image::Magick
use strict;
use warnings;
use vars qw($VERSION);
# Magick related
use constant XPPEM        => 0; # character width 
use constant YPPEM        => 1; # character height
use constant ASCENDER     => 2; # ascender
use constant DESCENDER    => 3; # descender
use constant WIDTH        => 4; # text width
use constant HEIGHT       => 5; # text height
use constant MAXADVANCE   => 6; # maximum horizontal advance
# object
use constant ANGLE        => -2;
use constant CHAR         => -1;
# image data
use constant MAX_COMPRESS => 100;
use constant FULL_CIRCLE  => 360;

use Image::Magick;

$VERSION = '1.72';

sub init {
   # Create the image object
   my $self        = shift;
   my $bg          = $self->cconvert( $self->{bgcolor} );
   $self->{image}  = Image::Magick->new;
   $self->{image}->Set(  size=> "$self->{width}x$self->{height}" );
   $self->{image}->Read( 'null:' . $bg );
   $self->{image}->Set(  background => $bg );
   $self->{MAGICK} = { strokewidth => 0.6 };
   $self->setThickness( $self->{thickness} ) if $self->{thickness};
   return;
}

sub out {
   my($self, @args) = @_;
   my %opt  = @args % 2 ? () : @args;
   my $type = 'gif'; # default format
   if ($opt{force}) {
      my %g = map { $_ => 1 } $self->{image}->QueryFormat;
      $type = $opt{force} if exists $g{$opt{force}};
   }
   $self->{image}->Set( magick => $type );
   if ( $opt{'compress'} && ( $type eq 'png' || $type eq 'jpeg' ) ) {
      if($type eq 'png') {
         $opt{'compress'} = MAX_COMPRESS;
         $self->{image}->Set( compression => 'Zip' );
      }
      $self->{image}->Set( quality => $opt{'compress'} );
   }
   return $self->{image}->ImageToBlob, $type, $self->{_RANDOM_NUMBER_};
}

sub insert_text {
   # Draw text using Image::Magick
   my $self   = shift;
   my $method = shift; # not needed with Image::Magick (always use ttf)
   my $key    = $self->{_RANDOM_NUMBER_}; # random string
   my $info   = sub {
      $self->{image}->QueryFontMetrics(
         font      => $self->{font},
         text      => shift,
         pointsize => $self->{ptsize},
      )
   };
   my %same   = (
      font      => $self->{font},
      encoding  => 'UTF-8',
      pointsize => $self->{ptsize},
      fill      => $self->cconvert( $self->{_COLOR_}{text} ),
   );

   if ($self->{scramble}) {
      my $space = [$info->(q{ }), 0, q{ }]; # get " " parameters
      my @randomy;
      my $sy    = $space->[ASCENDER] || 1;
      ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
      push @randomy,  $_, - $_ foreach $sy/2, $sy/4, $sy/8;
      ## use critic
      my @char;
      foreach ( split m{}xms, $key ) {
         push @char, [$info->($_), $self->random_angle, $_], $space, $space, $space;
      }
      my $total = 0;
         $total += $_->[WIDTH] foreach @char;
      foreach my $magick (@char) {
         $total -= $magick->[WIDTH] * 2;
         $self->{image}->Annotate(
            text   => $magick->[CHAR],
            x      =>  ($self->{width}  - $total - $magick->[WIDTH]   ) / 2,
            y      => (($self->{height}          + $magick->[ASCENDER]) / 2) + $randomy[int rand @randomy],
            rotate => $magick->[ANGLE],
            %same,
         );
      }
   }
   else {
      my @metric = $info->($key);
      my($x, $y);
      my $tl = $self->{_TEXT_LOCATION_};
      if ($tl->{_place_}) {
         # put the text to one of the four corners in the image
         $x = $tl->{x} eq 'left' ? 2                   : $self->{width}-$metric[WIDTH] - 2;
         $y = $tl->{y} eq 'up'   ? $metric[ASCENDER]+1 : $self->{height}-2;
         $self->add_strip($x, $y, $metric[WIDTH], $metric[ASCENDER]) if $tl->{strip};
      }
      else {
         $x = ($self->{width}  - $metric[WIDTH]   ) / 2;
         $y = ($self->{height} + $metric[ASCENDER]) / 2;
      }
      $self->{image}->Annotate(
         text   => $key,
         x      => $x,
         y      => $y,
         rotate => $self->{angle} ? FULL_CIRCLE - $self->{angle} : 0,
         %same,
      );
   }
   return;
}

sub setPixel { ## no critic (NamingConventions::Capitalization)
   my($self, $x, $y, $color) = @_;
   return $self->{image}->Set( "pixel[$x,$y]" => $self->cconvert($color) );
}

sub line {
   my($self, $x1, $y1, $x2, $y2, $color) = @_;
   return $self->{image}->Draw(
      primitive   => 'line',
      points      => "$x1,$y1 $x2,$y2",
      stroke      => $self->cconvert($color),
      strokewidth => $self->{MAGICK}{strokewidth},
   );
}

sub rectangle {
   my($self, $x1,$y1,$x2,$y2,$color) = @_;
   return $self->{image}->Draw(
      primitive   => 'rectangle',
      points      => "$x1,$y1 $x2,$y2",
      stroke      => $self->cconvert($color),
      strokewidth => $self->{MAGICK}{strokewidth},
      fill        => 'transparent',
   );
}

sub filledRectangle { ## no critic (NamingConventions::Capitalization)
   my($self, $x1, $y1, $x2, $y2, $color) = @_;
   return $self->{image}->Draw(
      primitive   => 'rectangle',
      points      => "$x1,$y1 $x2,$y2",
      fill        => $self->cconvert($color),
      stroke      => $self->cconvert($color),
      strokewidth => 0,
   );
}

sub ellipse {
   my($self, $cx, $cy, $width, $height, $color) = @_;
   return $self->{image}->Draw(
      primitive   => 'ellipse',
      points      => "$cx,$cy $width,$height 0,360",
      stroke      => $self->cconvert($color),
      strokewidth => $self->{MAGICK}{strokewidth},
      fill        => 'transparent',
   );
}

sub arc {
   my($self, $cx, $cy, $width, $height, $start, $end, $color) = @_;
   # I couldn't do that with "arc" primitive. 
   # Patches are welcome, but this seems to work :)
   return $self->{image}->Draw(
      primitive   => 'ellipse',
      points      => "$cx,$cy $width,$height $start,$end",
      stroke      => $self->cconvert($color),
      strokewidth => $self->{MAGICK}{strokewidth},
      fill        => 'transparent',
   );
}

sub setThickness { ## no critic (NamingConventions::Capitalization)
   my $self = shift;
   my $thickness = shift || return;
   $self->{MAGICK}{strokewidth} *= $thickness;
   return;
}

sub _versiongt {
   my $self  = shift;
   my $check = $self->_tovstr(shift);
   my $gt    = $Image::Magick::VERSION gt $check;
   my $eq    = $Image::Magick::VERSION eq $check;
   my $ok    = $gt || $eq;
   return $ok ? 1 : 0;
}

sub _versionlt {
   my $self   = shift;
   my $check  = $self->_tovstr(shift);
   my $lt = $Image::Magick::VERSION lt $check ? 1 : 0;
   return $lt;
}

sub _tovstr {
   my $self  = shift;
   my $thing = shift || return '0.0.0';
   my @j     = split m{[.]}xms, $thing;
   my $rv    = join q{.},
                    shift(@j) || 0,
                    shift(@j) || 0,
                    shift(@j) || 0,
                    @j ? (@j) : ();
   return $rv;
}

sub gdbox_empty { return 0 }

1;

__END__

=head1 NAME

GD::SecurityImage::Magick -  Image::Magick backend for GD::SecurityImage.

=head1 SYNOPSIS

See L<GD::SecurityImage>.

=head1 DESCRIPTION

This document describes version C<1.72> of C<GD::SecurityImage::Magick>
released on C<27 August 2012>.

Includes GD method emulations for Image::Magick.

Used internally by L<GD::SecurityImage>. Nothing public here.

=head1 METHODS

=head2 arc

=head2 ellipse

=head2 filledRectangle

=head2 init

=head2 insert_text

=head2 line

=head2 out

=head2 rectangle

=head2 setPixel

=head2 setThickness

=head2 gdbox_empty

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
