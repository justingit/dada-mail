package GD::SecurityImage;
use strict;
use warnings;
use vars qw[@ISA $VERSION $BACKEND];
use GD::SecurityImage::Styles;
use Carp qw(croak);
use constant RGB_WHITE   => ( 255, 255, 255 );
use constant RGB_BLACK   => ( 0, 0, 0 );
use constant RANDOM_DATA => ( 0..9 );
use constant FULL_CIRCLE => 360;
use constant DEFAULT_ANGLES => (0,5,8,15,22,26,29,33,35,36,40,43,45,53,56);

use constant DEFAULT_WIDTH  => 80;
use constant DEFAULT_HEIGHT => 30;
use constant DEFAULT_PTSIZE => 20;
use constant DEFAULT_LINES  => 10;

use constant MAX_RGB_VALUE  => 255;
use constant PARTICLE_MULTIPLIER => 20;
use constant MAX_RGB_PARAMS => 3;

$VERSION = '1.72';

sub import {
   my($class, @args) = @_;
   my %opt     = @args % 2 ? () : @args;
   # init/reset globals
   $BACKEND    = q{}; # name of the back-end
   @ISA        = (); ## no critic (ClassHierarchies::ProhibitExplicitISA)
   # load the drawing interface
   if ( exists $opt{use_magick} && $opt{use_magick} ) {
      require GD::SecurityImage::Magick;
      $BACKEND = 'Magick';
   }
   elsif ( exists $opt{backend} && $opt{backend} ) {
      my $be  = __PACKAGE__.q{::}.$opt{backend};
      my $eok = eval "require $be";
      croak "Unable to locate the $class back-end $be: $@" if $@;
      $BACKEND = $opt{backend} eq 'AC' ? 'GD' : $opt{backend};
   }
   else {
      require GD::SecurityImage::GD;
      $BACKEND = 'GD';
   }
   push @ISA, 'GD::SecurityImage::' . $BACKEND, ## no critic (ClassHierarchies::ProhibitExplicitISA)
              qw(GD::SecurityImage::Styles); # load styles
   return;
}

sub new {
   my($class, @args) = @_;
      $BACKEND || croak "You didn't import $class!";
   my %opt   = @args % 2 ? () : @args;

   my $self  = {
      IS_MAGICK       => $BACKEND eq 'Magick',
      IS_GD           => $BACKEND eq 'GD',
      IS_CORE         => $BACKEND eq 'GD' || $BACKEND eq 'Magick',
      DISABLED        => {}, # list of methods that a backend (or some older version of backend) can't do
      MAGICK          => {}, # Image::Magick configuration options
      GDBOX_EMPTY     => 0,  # GD::SecurityImage::GD::insert_text() failed?
      _RANDOM_NUMBER_ => q{}, # random security code
      _RNDMAX_        => 6,  # maximum number of characters in a random string.
      _COLOR_         => {}, # text and line colors
      _CREATECALLED_  => 0,  # create() called? (check for particle())
      _TEXT_LOCATION_ => {}, # see info_text
   };
   bless $self, $class;

   my %options = $self->_new_options( %opt );

   if ( $opt{text_location}
      && ref $opt{text_location}
      && ref $opt{text_location} eq 'HASH' ) {
      $self->{_TEXT_LOCATION_} = { %{$opt{text_location}}, _place_ => 1 };
   }
   else {
      $self->{_TEXT_LOCATION_}{_place_} = 0;
   }

   $self->{_RNDMAX_} = $options{rndmax};

   $self->{$_} = $options{$_} foreach keys %options;

   if ( $self->{angle} ) { # validate angle
      $self->{angle} = FULL_CIRCLE + $self->{angle} if $self->{angle} < 0;
      if ( $self->{angle} > FULL_CIRCLE ) {
         croak 'Angle parameter can take values in the range -360..360';
      }
   }

   if ( $self->{scramble} ) {
      if ( $self->{angle} ) {
         # Does the user want a fixed angle?
         push @{ $self->{_ANGLES_} }, $self->{angle};
      }
      else {
         # Generate angle range. The reason for hardcoding these is; 
         # it'll be less random for 0..60 range
         push @{ $self->{_ANGLES_} }, DEFAULT_ANGLES;
         # push negatives
         push @{ $self->{_ANGLES_} },
              map {FULL_CIRCLE - $_} @{ $self->{_ANGLES_} };
      }
   }

   $self->init;
   return $self;
}

sub _new_options {
   my($self, %opt) = @_;
   my %options = (
      width      => $opt{width}               || DEFAULT_WIDTH,
      height     => $opt{height}              || DEFAULT_HEIGHT,
      ptsize     => $opt{ptsize}              || DEFAULT_PTSIZE,
      lines      => $opt{lines}               || DEFAULT_LINES,
      rndmax     => $opt{rndmax}              || $self->{_RNDMAX_},
      rnd_data   => $opt{rnd_data}            || [ RANDOM_DATA ],
      font       => $opt{font}                || q{},
      gd_font    => $self->gdf($opt{gd_font}) || q{},
      bgcolor    => $opt{bgcolor}             || [ RGB_WHITE ],
      send_ctobg => $opt{send_ctobg}          || 0,
      frame      => defined($opt{frame}) ? $opt{frame} : 1,
      scramble   => $opt{scramble}            || 0,
      angle      => $opt{angle}               || 0,
      thickness  => $opt{thickness}           || 0,
      _ANGLES_   => [], # angle list for scrambled images
   );
   return %options;
}

sub backends {
   my $self  = shift;
   my $class = ref($self) || $self;
   my(@list, @dir_list);
   require Symbol;
   foreach my $inc (@INC) {
      my $dir = "$inc/GD/SecurityImage";
      next unless -d $dir;
      my $DIR = Symbol::gensym();
      opendir $DIR, $dir or croak "opendir($dir) failed: $!";
      my @dir = readdir $DIR;
      closedir $DIR;
      push @dir_list, $dir;
      foreach my $file (@dir) {
         next if -d $file;
         next if $file =~ m{ \A [.] }xms;
         next if $file =~ m{ \A (Styles|AC|Handler)[.]pm \z}xms;
         $file =~ s{ [.]pm \z}{}xms;
         push @list, $file;
      }
   }

   return @list if defined wantarray;

   my $report = "Available back-ends in $class v$VERSION are:\n\t"
               . join("\n\t", @list)
               . "\n\n"
               . "Search directories:\n\t"
               . join "\n\t", @dir_list;
   print $report or croak "Unable to print to STDOUT: $!";
   return;
}

sub gdf {
   my($self, @args) = @_;
   return if not $self->{IS_GD};
   return $self->gdfx( @args );
}

sub random_angle {
   my $self   = shift;
   my @angles = @{ $self->{_ANGLES_} };
   my @r;
   push @r, $angles[int rand @angles] for 0..$#angles;
   return $r[int rand @r];
}

sub random_str { return shift->{_RANDOM_NUMBER_} }

sub random {
   my $self = shift;
   my $user = shift;
   if($user and length($user) >= $self->{_RNDMAX_}) {
      $self->{_RANDOM_NUMBER_} = $user;
   }
   else {
      my @keys = @{ $self->{rnd_data} };
      my $lk   = scalar @keys;
      my $random;
         $random .= $keys[int rand $lk] for 1..$self->{rndmax};
         $self->{_RANDOM_NUMBER_} = $random;
   }
   return defined wantarray ? $self : undef;
}

sub cconvert { # convert color codes
   # GD           : return color index number
   # Image::Magick: return hex color code
   my $self   = shift;
   my $data   = shift || croak 'Empty parameter passed to cconvert';
   return $self->backend_cconvert($data) if not $self->{IS_CORE};

   my $is_hex    = $self->is_hex($data);
   my $magick_ok = $self->{IS_MAGICK} && $data && $is_hex;
   # data is a hex color code and Image::Magick has hex support
   return $data if $magick_ok;
   my $color_code = $data                 &&
                    ! $is_hex             &&
                    ! ref($data)          &&
                    $data !~ m{[^0-9]}xms &&
                    $data >= 0;

   if( $color_code ) {
      if ( $self->{IS_MAGICK} ) {
         croak "The number '$data' can not be transformed to a color code!";
      }
      # data is a GD color index number ...
      # ... or it is any number! since there is no way to determine this. 
      # GD object' s rgb() method returns 0,0,0 upon failure...
      return $data;
   }

   my @rgb = $self->h2r($data);
   return @rgb && $self->{IS_MAGICK}
         ? $data
         : $self->_cconvert_new( $data, @rgb );
}

sub _cconvert_new {
   my($self, $data, @rgb) = @_;
   $data = [@rgb] if @rgb;
   # initialize if not valid
   if(! $data || ! ref $data || ref $data ne 'ARRAY' || $#{$data} != 2) {
      $data = [0, 0, 0];
   }
   foreach my $i (0..$#{$data}) { # check for bad values
      if ( $data->[$i] > MAX_RGB_VALUE || $data->[$i] < 0 ) {
         $data->[$i] = 0;
      }
   }

   return $self->{IS_MAGICK} ? $self->r2h(@{$data}) # convert to hex
                             : $self->{image}->colorAllocate(@{$data});
}

sub create {
   my $self   = shift;
   my $method = shift || 'normal';  # ttf or normal
   my $style  = shift || 'default'; # default or rect or box
   my $col1   = shift || [ 0, 0, 0]; # text color
   my $col2   = shift || [ 0, 0, 0]; # line/box color

   $self->{send_ctobg} = 0 if $style eq 'box'; # disable for that style
   $self->{_COLOR_}    = { # set the color hash
        text  => $self->cconvert($col1),
        lines => $self->cconvert($col2),
   };

   # be a smart module and auto-disable ttf if we are under a prehistoric GD
   if ( not $self->{IS_MAGICK} ) {
      $method = 'normal' if $self->_versionlt( '1.20' );
   }

   if ( $method eq 'normal' && ! $self->{gd_font} ) {
      $self->{gd_font} = $self->gdf('giant');
   }

   $style = $self->can('style_'.$style) ? 'style_'.$style : 'style_default';

   $self->$style() if not $self->{send_ctobg};
   $self->insert_text($method);
   $self->$style() if     $self->{send_ctobg};

   if ( $self->{frame} ) {
      # put a frame around the image
      my $w = $self->{width}  - 1;
      my $h = $self->{height} - 1;
      $self->rectangle( 0, 0, $w, $h, $self->{_COLOR_}{lines} );
   }

   $self->{_CREATECALLED_}++;
   return defined wantarray ? $self : undef;
}

sub particle {
   # Create random dots. They'll cover all over the surface
   my $self = shift;
   croak q{particle() must be called 'after' create()} if !$self->{_CREATECALLED_};
   my $big  = $self->{height} > $self->{width} ? $self->{height} : $self->{width};
   my $f    = shift || $big * PARTICLE_MULTIPLIER; # particle density
   my $dots = shift || 1; # number of multiple dots
   my $int  = int $big / PARTICLE_MULTIPLIER;

   if ( ! $int ) { # RT#33629
      warn "particle(): image dimension is so small to add particles\n";
      return;
   }

   my @random;
   for (my $x = $int; $x <= $big; $x += $int) { ## no critic (ControlStructures::ProhibitCStyleForLoops)
      push @random, $x;
   }

   my $tc  = $self->{_COLOR_}{text};
   my $len = @random;
   my $r   = sub { $random[ int rand $len ] };

   for ( 1..$f ) {
      my $x = int rand $self->{width};
      my $y = int rand $self->{height};
      foreach my $z (1..$dots) {
         $self->setPixel($x + $z         , $y + $z         , $tc);
         $self->setPixel($x + $z + $r->(), $y + $z + $r->(), $tc);
      }
   }
   undef @random;
   undef $r;

   return defined wantarray ? $self : undef;
}

sub raw { return shift->{image} } # raw image object

sub info_text { # set text location
   # x      => 'left|right',  # text-X
   # y      => 'up|low|down', # text-Y
   # strip  => 1|0,           # add strip?
   # gd     => 1|0,           # use default GD font?
   # ptsize => 10,            # point size
   # color  => '#000000',     # text color
   # scolor => '#FFFFFF',     # strip color
   # text   => 'blah',        # modifies random code
   my($self, @args) = @_;
   croak q{info_text() must be called 'after' create()} if ! $self->{_CREATECALLED_};
   my %o = @args % 2 ? () : ( qw/ x right y up strip 1 /, @args );
   return if not %o;

   $self->{_TEXT_LOCATION_}{_place_} = 1;
   $o{scolor}                        = $self->cconvert($o{scolor})       if $o{scolor};

   my %restore = (
      random   => $self->{_RANDOM_NUMBER_},
      color    => $self->{_COLOR_}{text},
      ptsize   => $self->{ptsize},
      scramble => $self->{scramble},
      angle    => $self->{angle},
   );

   $self->{_RANDOM_NUMBER_}    = delete $o{text}                   if $o{text};
   $self->{_COLOR_}{text}      = $self->cconvert(delete $o{color}) if $o{color};
   $self->{ptsize}             = delete $o{ptsize}                 if $o{ptsize};
   $self->{scramble}           = 0; # disable. we need a straight text
   $self->{angle}              = 0; # disable. RT:14618

   $self->{_TEXT_LOCATION_}->{$_} = $o{$_} foreach keys %o;
   $self->insert_text('ttf');

   # restore
   $self->{_RANDOM_NUMBER_}    = $restore{random};
   $self->{_COLOR_}{text}      = $restore{color};
   $self->{ptsize}             = $restore{ptsize};
   $self->{scramble}           = $restore{scramble};
   $self->{angle}              = $restore{angle};

   return $self;
}

#--------------------[ PRIVATE ]--------------------#

sub add_strip { # adds a strip to the background of the text
   my($self, $x, $y, $box_w, $box_h) = @_;
   my $tl    = $self->{_TEXT_LOCATION_};
   my $c     = $self->{_COLOR_} || {};
   my $black = $self->cconvert( $c->{text}    ? $c->{text}    : [ RGB_BLACK ] );
   my $white = $self->cconvert( $tl->{scolor} ? $tl->{scolor} : [ RGB_WHITE ] );
   my $x2    = $tl->{x} eq 'left' ? $box_w : $self->{width};
   my $y2    = $self->{height} - $box_h;
   my $i     = $self->{IS_MAGICK} ? $self  : $self->{image};
   my $up    = $tl->{y} eq 'up';
   my $h     = $self->{height};
   $i->filledRectangle($up ? ($x-1, 0, $x2, $y+1) : ($x-1, $y2-1, $x2  , $h  ), $black);
   $i->filledRectangle($up ? ($x  , 1, $x2-2, $y) : ($x  , $y2  , $x2-2, $h-2), $white);
   return;
}

sub r2h {
   # Convert RGB to Hex
   my($self, @args) = @_;
   return if @args != MAX_RGB_PARAMS;
   my $color  = q{#};
      $color .= sprintf '%02x', $_ foreach @args;
   return $color;
}

sub h2r {
   # Convert Hex to RGB
   my $self  = shift;
   my $color = shift;
   return if ref $color;
   my @rgb   = $color =~ m/\A \#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2}) \z/xmsi;
   return @rgb ? map { hex $_ } @rgb : undef;
}

sub is_hex {
   my $self = shift;
   my $data = shift;
   return $data =~ m/ \A \#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2}) \z /xmsi;
}

1;

__END__

=head1 NAME

GD::SecurityImage - Security image (captcha) generator.

=head1 SYNOPSIS

   use GD::SecurityImage;

   # Create a normal image
   my $image = GD::SecurityImage->new(
                  width   => 80,
                  height  => 30,
                  lines   => 10,
                  gd_font => 'giant',
               );
      $image->random( $your_random_str );
      $image->create( normal => 'rect' );
   my($image_data, $mime_type, $random_number) = $image->out;

or

   # use external ttf font
   my $image = GD::SecurityImage->new(
                  width    => 100,
                  height   => 40,
                  lines    => 10,
                  font     => "/absolute/path/to/your.ttf",
                  scramble => 1,
               );
      $image->random( $your_random_str );
      $image->create( ttf => 'default' );
      $image->particle;
   my($image_data, $mime_type, $random_number) = $image->out;

or you can just say (most of the public methods can be chained)

   my($image, $type, $rnd) = GD::SecurityImage->new->random->create->particle->out;

to create a security image with the default settings. But that may not 
be useful. If you C<require> the module, you B<must> import it:

   require GD::SecurityImage;
   GD::SecurityImage->import;

The module also supports C<Image::Magick>, but the default interface 
uses the C<GD> module. To enable C<Image::Magick> support, you must 
call the module with the C<use_magick> option:

   use GD::SecurityImage use_magick => 1;

If you C<require> the module, you B<must> import it:

   require GD::SecurityImage;
   GD::SecurityImage->import(use_magick => 1);

The module does not I<export> anything actually. But C<import> loads
the necessary sub modules. If you don' t C<import>, the required 
modules will not be loaded and probably, you'll C<die()>.

=head1 DESCRIPTION

This document describes version C<1.72> of C<GD::SecurityImage>
released on C<27 August 2012>.

The (so called) I<"Security Images"> are so popular. Most internet 
software use these in their registration screens to block robot programs
(which may register tons of  fake member accounts). Security images are
basicaly, graphical B<CAPTCHA>s (B<C>ompletely B<A>utomated B<P>ublic 
B<T>uring Test to Tell B<C>omputers and B<H>umans B<A>part). This 
module gives you a basic interface to create such an image. The final 
output is the actual graphic data, the mime type of the graphic and the 
created random string. The module also has some I<"styles"> that are 
used to create the background (or foreground) of the image.

If you are an C<Authen::Captcha> user, see L<GD::SecurityImage::AC>
for migration from C<Authen::Captcha> to C<GD::SecurityImage>.

This module is B<just an image generator>. Not a I<captcha handler>.
The validation of the generated graphic is left to your programming 
taste. But there are some I<captcha handlers> for several Perl FrameWorks.
If you are an user of one of these frameworks, see  
L</"GD::SecurityImage Implementations"> in L</"SEE ALSO"> section
for information.

=head1 COLOR PARAMETERS

This module can use both RGB and HEX values as the color 
parameters. HEX values are recommended, since they are  
widely used and recognised.

   $color  = '#80C0F0';     # HEX
   $color2 = [15, 100, 75]; # RGB
   $i->create($meth, $style, $color, $color2)

   $i->create(ttf => 'box', '#80C0F0', '#0F644B')

RGB values must be passed as an array reference including the three
I<B<R>ed>, I<B<G>reen> and I<B<B>lue> values.

Color conversion is transparent to the user. You can use hex values
under both C<GD> and C<Image::Magick>. They' ll be automagically 
converted to RGB if you are under C<GD>.

=head1 METHODS

=head2 new

The constructor. C<new()> method takes several arguments. These 
arguments are listed below.

=over 4

=item width

The width of the image (in pixels).

=item height

The height of the image (in pixels).

=item ptsize

Numerical value. The point size of the ttf character. 
Only necessarry if you want to use a ttf font in the image.

=item lines

The number of lines that you' ll see in the background of the image.
The alignment of lines can be vertical, horizontal or angled or 
all of them. If you increase this parameter' s value, the image will
be more cryptic.

=item font

The absolute path to your TrueType (.ttf) font file. Be aware that 
relative font paths are not recognized due to problems in the C<libgd>
library.

If you are sure that you've set this parameter to a correct value and
you get warnings or you get an empty image, be sure that your path
does not include spaces in it. It looks like libgd also have problems
with this kind of paths (eg: '/Documents and Settings/user' under Windows).

Set this parameter if you want to use ttf in your image.

=item gd_font

If you want to use the default interface, set this parameter. The
recognized values are C<Small>, C<Large>, C<MediumBold>, C<Tiny>, C<Giant>.
The names are case-insensitive; you can pass lower-cased parameters.

=item bgcolor

The background color of the image.

=item send_ctobg

If has a true value, the random security code will be displayed in the 
background and the lines will pass over it. 
(send_ctobg = send code to background)

=item frame

If has a true value, a frame will be added around the image. This
option is enabled by default.

=item scramble

If set, the characters will be scrambled. If you enable this option,
be sure to use a wider image, since the characters will be separated 
with three spaces.

=item angle

Sets the angle for scrambled/normal characters. Beware that, if you pass
an C<angle> parameter, the characters in your random string will have
a fixed angle. If you do not set an C<angle> parameter, the angle(s)
will be random.

When the scramble option is not enabled, this parameter still controls
the angle of the text. But, since the text will be centered inside the 
image, using this parameter without scramble option will require a 
taller image. Clipping will occur with smaller height values.

Unlike the GD interface, C<angle> is in C<degree>s and can take values 
between C<0> and C<360>.

=item thickness

Sets the line drawing width. Can take numerical values. 
Default values are C<1> for GD and C<0.6> for Image:Magick.

=item rndmax

The minimum length of the random string. Default value is C<6>.

=item rnd_data

Default character set used to create the random string is C<0..9>.
But, if you want to use letters also, you can set this parameter.
This parameter takes an array reference as the value.

B<Not necessary and will not be used if you pass your own random>
B<string.>

=back

=head2 random

Creates the random security string or B<sets the random string> to 
the value you have passed. If you pass your own random string, be aware 
that it must be at least six (defined in C<rndmax>) characters 
long.

=head2 random_str

Returns the random string. Must be called after C<random()>.

=head2 create

This method creates the actual image. It takes four arguments, but
none are mandatory.

   $image->create($method, $style, $text_color, $line_color);

C<$method> can be B<C<normal>> or B<C<ttf>>.

C<$style> can be one of the following (some of the styles may not work 
if you are using a really old version of GD):

=over 4

=item B<default>

The default style. Draws horizontal, vertical and angular lines.

=item B<rect>

Draws horizontal and vertical lines

=item B<box>

Draws two filled rectangles.

The C<lines> option passed to L<new|/new>, controls the size of the inner rectangle
for this style. If you increase the C<lines>, you'll get a smaller internal 
rectangle. Using smaller values like C<5> can be better.

=item B<circle>

Draws circles.

=item B<ellipse>

Draws ellipses. 

=item B<ec>

This is the combination of ellipse and circle styles. Draws both ellipses
and circles.

=item B<blank>

Draws nothing. See L</"OTHER USES">.

=back

I<Note>: if you have a (too) old version of GD, you may not be able 
to use some of the styles.

You can use this code to get all available style names:

   my @styles = grep {s/^style_//} keys %GD::SecurityImage::Styles::;

The last two arguments (C<$text_color> and C<$line_color>) are the 
colors used in the image (text and line color -- respectively):

   $image->create($method, $style, [0,0,0], [200,200,200]);
   $image->create($method, $style, '#000000', '#c8c8c8');

=head2 particle

Must be called after L<create|/create>.

Adds random dots to the image. They'll cover all over the surface. 
Accepts two parameters; the density (number) of the particles and 
the maximum number of dots around the main dot.

   $image->particle($density, $maxdots);

Default value of C<$density> is dependent on your image' s width or 
height value. The greater value of width and height is taken and 
multiplied by twenty. So; if your width is C<200> and height is C<70>, 
C<$density> is C<200 * 20 = 4000> (unless you pass your own value).
The default value of C<$density> can be too much for smaller images.

C<$maxdots> defines the maximum number of dots near the default dot. 
Default value is C<1>. If you set it to C<4>, The selected pixel and 3 
other pixels near it will be used and colored.

The color of the particles are the same as the color of your text 
(defined in L<create|/create>).

=head2 info_text

This method must be called after L<create|/create>. If you call it
early, you'll die. C<info_text> adds an extra text to the generated 
image. You can also put a strip under the text. The purpose of this 
method is to display additional information on the image. Copyright 
information can be an example for that.

   $image->info_text(
      x      => 'right',
      y      => 'up',
      gd     => 1,
      strip  => 1,
      color  => '#000000',
      scolor => '#FFFFFF',
      text   => 'Generated by GD::SecurityImage',
   );

Options: 

=over 4

=item x

Controls the horizontal location of the information text. Can be 
either C<left> or C<right>.

=item y

Controls the vertical location of the information text. Can be 
either C<up> or C<down>.

=item strip

If has a true value, a strip will be added to the background of the
information text.

=item gd

This option can only be used under C<GD>. Has no effect under
Image::Magick. If has a true value, the standard GD font C<Tiny>
will be used for the information text.

If this option is not present or has a false value, the TTF font 
parameter passed to C<new> will be used instead.

=item ptsize

The ptsize value of the information text to be used with the TTF font.
TTF font parameter can not be set with C<info_text()>. The value passed
to C<new()> will be used instead.

=item color

The color of the information text.

=item scolor

The color of the strip.

=item text

This parameter controls the displayed text. If you want to display 
long texts, be sure to adjust the image, or clipping will occur.

=back

=head2 out

This method finally returns the created image, the mime type of the 
image and the random number(s) generated. Older versions of GD only support
C<gif> type, while new versions support C<jpeg> and C<png> 
(B<update>: beginning with v2.15, GD resumed gif support).

The returned mime type is C<png> or C<gif> or C<jpeg> for C<GD> and 
C<gif> for C<Image::Magick> (if you do not C<force> some other format).

C<out> method accepts arguments:

   @data = $image->out(%args);

=over 4

=item force

You can set the output format with the C<force> parameter:

   @data = $image->out(force => 'png');

If C<png> is supported by the interface (via C<GD> or C<Image::Magick>); 
you'll get a png image, if the interface does not support this format, 
C<out()> method will use it's default configuration.

=item compress

And with the C<compress> parameter, you can define the compression 
for C<png> and quality for C<jpeg>:

   @data = $image->out(force => 'png' , compress => 1);
   @data = $image->out(force => 'jpeg', compress => 100);

When you use C<compress> with C<png> format, the value of C<compress>
is ignored and it is only checked if it has a true value. With C<png>
the compression will always be C<9> (maximum compression). eg:

   @data = $image->out(force => 'png' , compress => 1);
   @data = $image->out(force => 'png' , compress => 3);
   @data = $image->out(force => 'png' , compress => 5);
   @data = $image->out(force => 'png' , compress => 1500);

All will default to C<9>. But this will disable compression:

   @data = $image->out(force => 'png' , compress => 0);

But the behaviour changes if the format is C<jpeg>; the value of
C<compress> will be used for C<jpeg> quality; which is in the range 
C<1..100>.

Compression and quality operations are disabled by default.

=back

=head2 raw

Depending on your usage of the module; returns the raw C<GD::Image> 
object:

   my $gd = $image->raw;
   print $gd->png;

or the raw C<Image::Magick> object:

   my $magick = $image->raw;
   $magick->Write("gif:-");

Can be useful, if you want to modify the graphic yourself. If you
want to get an I<image type> see the C<force> option in C<out>.

=head2 gdbox_empty

See L</"path bug"> in L</"GD bug"> for usage and other information 
on this method.

=head2 add_strip

=head2 cconvert

=head2 gdf

=head2 h2r

=head2 is_hex

=head2 r2h

=head2 random_angle

=head1 UTILITY METHODS

=head2 backends

Returns a list of available GD::SecurityImage back-ends.

   my @be = GD::SecurityImage->backends;

or

   my @be = $image->backends;

If called in a void context, prints a verbose list of available 
GD::SecurityImage back-ends:

   Available back-ends in GD::SecurityImage v1.55 are:
           GD
           Magick
   
   Search directories:
              /some/@INC/dir/containing/GDSI

you can see the output with this command:

   perl -MGD::SecurityImage -e 'GD::SecurityImage->backends'

or under windows:

   perl -MGD::SecurityImage -e "GD::SecurityImage->backends"

=begin BACKEND_AUTHORS

If you want to write a new back-end to GD::SecurityImage, you must define 
this mandatory methods.

   init			initializes your image object
   out			defines output format and returns the image data
   insert_text		inserts text to the image
   setPixel		sets a pixel' s color defined by it's (x,y) values
   line			draws a line
   rectangle		draws a rectangle
   filledRectangle	draws a filled rectangle
   ellipse		draws an ellipse
   arc			draws an arc
   setThickness		sets the thickness of the lines when drawing something
   _versiongt           backend version is greater or equal to supplied param?
   _versionlt           backend version is smaller than supplied param?

and

   backend_cconvert	for HEX & RGB color handling

See GD::SecurityImage::Magick for the first part of methods and see 
cconvert() method in GD::SecurityImage to define such a method. Your 
backend_cconvert() method must be capable of handling both HEX and RGB 
values. The parameters passed to drawing methods (like line()) are 
in GD format. See the L<GD> module for examples.

You can then name your distro as 'GD::SecurityImage::X' and anyone can use 
it like:

   use GD::SecurityImage backend => 'X';

=end BACKEND_AUTHORS

=head1 EXAMPLES

See the tests in the distribution. Also see the demo program 
"eg/demo.pl" for an C<Apache::Session> implementation of 
C<GD::SecurityImage>.

Download the distribution from a CPAN mirror near you, if you 
don't have the files.

=begin html

<!-- this h1 part is for search.cpan.org -->
<h1>
<a class = 'u' 
   href  = '#___top'
   title ='click to go to top of document'
   name  = "IMAGE SAMPLES"
>IMAGE SAMPLES</a>
</h1>

<p>
All TTF samples generated with the bundled font <i>StayPuft.ttf</i>,
unless stated otherwise. Most of the samples here can be generated with 
running the test suite that comes with the GD::SecurityImage distribution. 
However, images that are generated with random angles will indeed be a 
little different after you run the test suite on your system.
</p>

<p>
All random codes have a length of six (6) characters, unless stated otherwise.
So, (for example) there is no clipping in <code>ELLIPS</code>.
</p>

<table border      = "1"
       cellpadding = "4"
       cellspacing = "1"
>
   <tr>
      <td colspan="2" style="text-align:center;font-weight:bold">
         <br />
         Images generated with GD
         <br />
         <br />
      </td>
   </tr>

   <tr><td colspan="2">&#160;</td></tr>

   <tr>
      <td> Standard interface. Font: <b>gdGiantFont</b> </td>
      <td> Style: <b>rect</b>                           </td>
   </tr>
   <tr>
      <td><img border="0" src="http://img505.imageshack.us/img505/1365/gdnormal03boxvi9.png" /></td>
      <td><img border="0" src="http://img524.imageshack.us/img524/9065/gdttf02rectiz2.png"   /></td>
   </tr>

   <tr><td colspan="2">&#160;</td></tr>

   <tr>
      <td>Style: <b>rect</b>. Scrambled with random angles.</td>
      <td>Style: <b>circle</b>. Scrambled with a fixed angle.</td>
   </tr>
   <tr>
      <td><img border="0" src="http://img505.imageshack.us/img505/8893/gdttfscramble02rectma0.png" /></td>
      <td><img border="0" src="http://img512.imageshack.us/img512/8207/gdttfscramblefixed04cirwt1.png" /></td>
   </tr>

   <tr><td colspan="2">&#160;</td></tr>

   <tr>
      <td>Style: <b>default</b>. Scrambled with a fixed angle. <br />Info text at the top right.</td>
      <td>Style: <b>circle</b>. Scrambled with random angles. <br />Font is: <i>Transformers.ttf</i></td>
   </tr>
   <tr>
      <td><img border="0" src="http://img524.imageshack.us/img524/1452/gdttfscramblefixedinfotuz9.png"  /></td>
      <td><img border="0" src="http://img505.imageshack.us/img505/739/differentdz6.png" /></td>
   </tr>

</table>

<p>&nbsp;</p>

<table border      = "1"
       cellpadding = "4"
       cellspacing = "2"
>
   <tr>
      <td colspan="2" style="text-align:center;font-weight:bold">
         <br />
         Images generated with Image::Magick
         <br />
         <br />
      </td>
   </tr>

   <tr><td colspan="2">&#160;</td></tr>

   <tr>
      <td>Style: <b>circle</b>.</td>
      <td>Style: <b>box</b>. Scrambled with random angles.</td>
   </tr>
   <tr>
      <td><img border="0" src="http://img524.imageshack.us/img524/1233/magick04circleru3.png"       /></td>
      <td><img border="0" src="http://img521.imageshack.us/img521/7235/magickscramble03boxmb2.png" /></td>
   </tr>

   <tr><td colspan="2">&#160;</td></tr>
   <tr>
      <td>Style: <b>circle</b>. Scrambled with a fixed angle.</td>
      <td>Style: <b>ellipse</b>. Scrambled with a fixed angle.<br /> Info text at the top right.</td>
   </tr>

   <tr>
      <td><img border="0" src="http://img139.imageshack.us/img139/7227/magickscramblefixed04cihd4.png" /></td>
      <td><img border="0" src="http://img440.imageshack.us/img440/2647/magickscramblefixed05elnz6.png" /></td>
   </tr>

   <tr><td colspan="2">&#160;</td></tr>

   <tr>
      <td>Style: <b>ec</b>. Scrambled with random angles.<br /> Info text at the top right.</td>
      <td>Style: <b>ec</b>. Scrambled with random angles<b><sup>1</sup>.</b></td>
   </tr>
   <tr>
      <td><img border="0" src="http://img139.imageshack.us/img139/9587/magickscrambleinfotext0bz8.png" /></td>
      <td><img border="0" src="http://img505.imageshack.us/img505/347/burakrw7.gif" /></td>
   </tr>

</table>


<p>
<sup><b>1</b></sup>: This image is generated with this code:</p>
<p>
<pre>
<span style="color: #8B008B; font-weight:bold;">use</span> <span style="color: #000000;">GD::SecurityImage</span> <span style="color: #000000;">backend</span> <span style="color: #000000;">=&gt;</span> <span style="color: #CD5555;">'Magick'</span><span style="color: #000000;">;</span>
<span style="color: #8B008B; font-weight:bold;">my</span><span style="color: #000000;">(</span><span style="color: #00688B;">$data</span><span style="color: #000000;">,</span> <span style="color: #00688B;">$mime</span><span style="color: #000000;">,</span> <span style="color: #00688B;">$rnd</span><span style="color: #000000;">)</span> = <span style="color: #000000;">GD::SecurityImage</span>
<span style="color: #000000;">-&gt;new</span><span style="color: #000000;">(</span>
   <span style="color: #000000;">width</span>      <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">420</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">height</span>     <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">100</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">ptsize</span>     <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">40</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">lines</span>      <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">20</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">thickness</span>  <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">4</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">rndmax</span>     <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">5</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">scramble</span>   <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">1</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">send_ctobg</span> <span style="color: #000000;">=&gt;</span> <span style="color: #B452CD;">1</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">bgcolor</span>    <span style="color: #000000;">=&gt;</span> <span style="color: #CD5555;">'#009999'</span><span style="color: #000000;">,</span>
   <span style="color: #000000;">font</span>       <span style="color: #000000;">=&gt;</span> <span style="color: #CD5555;">'StayPuft.ttf'</span><span style="color: #000000;">,</span>
<span style="color: #000000;">)</span>
<span style="color: #00688B;">-&gt;random</span><span style="color: #000000;">(</span><span style="color: #CD5555;">'BURAK'</span><span style="color: #000000;">)</span>
<span style="color: #00688B;">-&gt;create</span><span style="color: #000000;">(</span> <span style="color: #CD5555;">qw/ ttf ec #0066CC #0066CC /</span> <span style="color: #000000;">)</span>
<span style="color: #00688B;">-&gt;particle</span><span style="color: #000000;">(</span><span style="color: #B452CD;">300</span><span style="color: #000000;">,</span> <span style="color: #B452CD;">500</span><span style="color: #000000;">)</span>
<span style="color: #00688B;">-&gt;out</span><span style="color: #000000;">;</span>

</pre>
</p>

<p>Images hosted by <a href="http://imageshack.us">ImageShack</a>.</p>

=end html

=head2 OTHER USES

C<GD::SecurityImage> drawing capabilities can also be used for 
I<counter image> generation or displaying arbitrary messages:

   use CGI qw(header);
   use GD::SecurityImage 1.64; # we need the "blank" style
   
   my $font  = "StayPuft.ttf";
   my $rnd   = "10.257"; # counter data
   
   my $image = GD::SecurityImage->new(
      width  =>   140,
      height =>    75,
      ptsize =>    30,
      rndmax =>     1, # keeping this low helps to display short strings
      frame  =>     0, # disable borders
      font   => $font,
   );
   
   $image->random( $rnd );
   # use the blank style, so that nothing will be drawn
   # to distort the image.
   $image->create( ttf => 'blank', '#CC8A00' );
   $image->info_text(
      text   => 'You are visitor number',
      ptsize => 10,
      strip  =>  0,
      color  => '#0094CC',
   );
   $image->info_text(
      text   => '( c ) 2 0 0 7   m y s i t e',
      ptsize => 10,
      strip  =>  0,
      color  => '#d7d7d7',
      y      => 'down',
   );
   
   my($data, $mime, $random) = $image->out;
   
   binmode STDOUT;
   print header -type => "image/$mime";
   print $data;

=begin html

<p>
The generated graphic will be:
<br/>
<br/>
<img src    = "http://img101.imageshack.us/img101/4770/gdsicountered2.png"
     border = "0"
     alt    = "Image Hosted by ImageShack.us" />
</p>

<p>Image hosted by <a href="http://imageshack.us">ImageShack</a>.</p>

=end html

=head1 ERROR HANDLING

C<die> is called in some methods if something fails. You may need to 
C<eval> your code to catch exceptions.

=head1 TIPS

If you look at the demo program (not just look at it, try to run it)
you'll see that the random code changes after every request (successful 
or not). If you do not change the random code after a failed request and 
display the random code inside HTML (like I<"Wrong! It must be E<lt>randomE<gt>">),
then you are doing a logical mistake, since the user (or robot) can now 
copy & paste the random code into your validator without looking at the 
security image and will pass the test. Just don't do that. Random code 
must change after every validation.

If you want to be a little more strict, you can also add a timeout key 
to the session (this feature currently does not exits in the demo) and
expire the related random code after the timeout. Since robots can call 
the image generator directly (without requiring the HTML form), they can 
examine the image for a while without changing it. A timeout implemetation
may prevent this.

=head1 BUGS

See the L</SUPPORT> section if you have a bug or 
request to report.

=head2 Image::Magick bug

There is a bug in PerlMagick' s C<QueryFontMetrics()> method. ImageMagick
versions smaller than 6.0.4 is affected. Below text is from the ImageMagick 
6.0.4 Changelog: L<http://www.imagemagick.org/www/Changelog.html>.

"2004-05-06 PerlMagick's C<QueryFontMetrics()> incorrectly reports `unrecognized 
attribute'` for the `font' attribute."

Please upgrade to ImageMagick 6.0.4 or any newer version, if your ImageMagick 
version is smaller than 6.0.4 and you want to use Image::Magick as the backend
for GD::SecurityImage.

=head2 GD bug

=head3 path bug

libgd and GD.pm don't like relative paths and paths that have spaces
in them. If you pass a font path that is not an B<exact path> or a path that
have a space in it, you may get an empty image. 

To check if the module failed to find the ttf font (when using C<GD>), a new 
method added: C<gdbox_empty()>. It must be called after C<create()>:

   $image->create;
   die "Error loading ttf font for GD: $@" if $image->gdbox_empty;

C<gdbox_empty()> always returns false, if you are using C<Image::Magick>.

=head1 COMMON ERRORS

=head2 Wrong GD installation

I got some error reports saying that GD::SecurityImage dies
with this error:

   Can't locate object method "new" via package "GD::Image" 
   (perhaps you forgot to load "GD::Image"?) at ...

This is due to a I<wrong> installation of the L<GD> module. GD
includes C<XS> code and it needs to be compiled. You can't just 
copy/paste the I<GD.pm> and expect it to work. It will not.
If you are under Windows and don't have a C compiler, you have 
to add new repositories to install I<GD>, since ActiveState' s own 
repositories don't include I<GD>. Randy Kobes and J-L Morel have 
ppm repositories for both 5.6.x and 5.8.x and they both have I<GD>:

   http://www.bribes.org/perl/ppmdir.html
   http://theoryx5.uwinnipeg.ca/

I<bribes.org> also has a I<GD::SecurityImage> ppd, so you can just 
install I<GD::SecurityImage> from that repository.

=head2 libgd errors

There are some issues related to wrong/incomplete compiling
of libgd and old/new version conflicts.

=head3 libgd without TTF support

If your libgd is compiled without TTF support, you'll get an I<empty>
image. The lines will be drawn, but there will be no text. You can 
check it with L</"gdbox_empty"> method.

=head3 GIF - Old libgd or libgd without GIF support enabled

If your GD has a C<gif> method, but you get empty images with C<gif()>
method, you have to update your libgd or compile it with GIF enabled.

You can test if C<gif> is working from the command line:

   perl -MGD -e '$_=GD::Image->new;$_->colorAllocate(0,0,0);print$_->gif'

or under windows:

   perl -MGD -e "$_=GD::Image->new;$_->colorAllocate(0,0,0);print$_->gif"

Conclusions:

=over 4

=item *

If it dies, your GD is very old. 

=item *

If it prints nothing, your libgd was compiled without GIF enabled (upgrade or re-compile). 

=item *

If it prints out a junk that starts with 'GIF87a', everything is OK.

=back

=head1 CAVEAT EMPTOR

=over 4

=item *

Using the default library C<GD> is a better choice. Since it is faster 
and does not use that much memory, while C<Image::Magick> is slower and 
uses more memory.

=item *

The internal random code generator is used B<only> for demonstration 
purposes for this module. It may not be I<effective>. You must supply 
your own random code and use this module to display it.

=item *

B<[GD] png compression>

Support for compression level argument to png() added in v2.07. If
your GD version is smaller than this, compress option to C<out()>
will be silently ignored.

=item *

B<[GD] setThickness>

setThickness implemented in GD v2.07. If your GD version is smaller
than that and you set thickness option, nothing will happen.

=item *

B<[GD] ellipse>

C<ellipse()> method added in GD 2.07. 

If your GD version is smaller than 2.07 and you use C<ellipse>, 
the C<default> style will be returned.

If your GD is smaller than 2.07 and you use C<ec>, only the circles will
be drawn.

=back

=head1 SEE ALSO

=head2 Other CAPTCHA Implementations & Perl Modules

=over 4

=item *

L<GD>, L<Image::Magick>

=item *

L<ImagePwd>, L<Authen::Captcha>.

=item *

C<ImageCode> Perl Module (commercial): L<http://www.progland.com/ImageCode.html>.

=item *

The CAPTCHA project: L<http://www.captcha.net/>.

=item *

A definition of CAPTCHA (From Wikipedia, the free encyclopedia):
L<http://en.wikipedia.org/wiki/Captcha>.

=item *

L<WebService::CaptchasDotNet>: A Perl interface to
I<http://captchas.net> free captcha service. I<captchas.net>
also offers I<audio> captchas.

=back

=head2 GD::SecurityImage Implementations

=over 4

=item *

L<GD::SecurityImage::AC>: C<Authen::Captcha> drop-in replacement module.

=item *

L<Sledge::Plugin::Captcha>

=item *

L<Catalyst::Plugin::Captcha>

=item *

L<CGI::Application::Plugin::CAPTCHA >

=item *

L<Angerwhale::Controller::Captcha>

=back

=head2 Software Using GD::SecurityImage

If your software uses C<GD::SecurityImage> for captcha generation and
want to appear in this document, contact the author.

=head1 SUPPORT

=head2 BUG REPORTS

All bug reports and wishlist items B<must> be reported via
the CPAN RT system. It is accessible at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=GD-SecurityImage>.

=head2 DISCUSSION FORUM

C<CPAN::Forum> is a place for discussing C<CPAN>
modules. It also has a C<GD::SecurityImage> section at
L<http://www.cpanforum.com/dist/GD-SecurityImage>.

=head2 RATINGS

If you like or hate or have some suggestions about
C<GD::SecurityImage>, you can comment/rate the distribution via 
the C<CPAN Ratings> system: 
L<http://cpanratings.perl.org/dist/GD-SecurityImage>.

=head1 AUTHOR

Burak Gursoy <burak@cpan.org>.

=head1 COPYRIGHT

Copyright 2004 - 2012 Burak Gursoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.
=cut
