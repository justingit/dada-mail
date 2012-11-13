package GD::SecurityImage::Styles;
use strict;
use warnings;
use vars qw[$VERSION];
use constant ARC_END_DEGREES => 360;

$VERSION = '1.72';

sub style_default {
   return shift->_drcommon(' \\ lines will be drawn ');
}

sub style_rect {
   return shift->_drcommon;
}

sub style_box {
   my $self = shift;
   my $n    = $self->{lines};
   my $ct   = $self->{_COLOR_}{text};
   my $cl   = $self->{_COLOR_}{lines};
   my $w    = $self->{width};
   my $h    = $self->{height};
   $self->filledRectangle(  0,  0, $w         , $h         , $ct );
   $self->filledRectangle( $n, $n, $w - $n - 1, $h - $n - 1, $cl );
   return;
}

sub style_circle {
   my $self  = shift;
   my $cx    = $self->{width}  / 2;
   my $cy    = $self->{height} / 2;
   my $n     = $self->{lines};
   my $cl    = $self->{_COLOR_}{lines};
   my $max   = int $self->{width} / $n;
      $max++;

   for my $i ( 1..$n ) {
      my $mi = $max * $i;
      $self->arc( $cx, $cy, $mi, $mi, 0, ARC_END_DEGREES, $cl );
   }
   return;
}

sub style_ellipse {
   my $self  = shift;
   return $self->style_default if $self->{DISABLED}{ellipse}; # GD < 2.07
   my $cx    = $self->{width}  / 2;
   my $cy    = $self->{height} / 2;
   my $n     = $self->{lines};
   my $cl    = $self->{_COLOR_}{lines};
   my $max   = int $self->{width} / $n;
      $max++;

   for my $i ( 1..$n ) {
      my $mi = $max * $i;
      $self->ellipse( $cx, $cy, $mi * 2, $mi, $cl );
   }
   return;
}

sub style_ec {
   my($self, @args) = @_;
   $self->style_ellipse(@args) if ! $self->{DISABLED}{ellipse}; # GD < 2.07
   $self->style_circle(@args);
   return;
}

sub style_blank {}

sub _drcommon {
   my $self  = shift;
   my $drawx = shift || 0;
   my $w     = $self->{width};
   my $h     = $self->{height};
   my $max   = $self->{lines};
   my $fx    = $w / $max;
   my $fy    = $h / $max;
   my $cl    = $self->{_COLOR_}{lines};

   my( $ifx );
   for my $i ( 0..$max ) {
      $ifx = $i * $fx;
      $self->line( $ifx, 0, $ifx      , $h, $cl ); # | line
      next if not $drawx;
      $self->line( $ifx, 0, $ifx + $fx, $h, $cl ); # \ line
   }

   my( $ify );
   for my $i ( 1..$max ) {
      $ify = $i * $fy;
      $self->line( 0, $ify, $w, $ify, $cl ); # - line
   }
   return;
}

1;

__END__

=head1 NAME

GD::SecurityImage::Styles - Drawing styles for GD::SecurityImage.

=head1 SYNOPSIS

See L<GD::SecurityImage>.

=head1 DESCRIPTION

This document describes version C<1.72> of C<GD::SecurityImage::Styles>
released on C<27 August 2012>.

This module contains the styles used in the security image.

Used internally by L<GD::SecurityImage>. Nothing public here.

=head1 METHODS

=head2 style_blank

=head2 style_box

=head2 style_circle

=head2 style_default

=head2 style_ec

=head2 style_ellipse

=head2 style_rect

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
