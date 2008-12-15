package GD::SecurityImage;
use strict;
use vars qw[@ISA $AUTOLOAD $VERSION $BACKEND];
use GD::SecurityImage::Styles;

$VERSION = '1.61';

sub import {
   my $class   = shift;
   my %opt     = scalar(@_) % 2 ? () : (@_);
   # init/reset globals
   $BACKEND    = ''; # name of the back-end
   @ISA        = ();
   # load the drawing interface
   if (exists $opt{use_magick} && $opt{use_magick}) {
      require GD::SecurityImage::Magick;
      $BACKEND = 'Magick';
   } elsif (exists $opt{backend} && $opt{backend}) {
      my $be = __PACKAGE__.'::'.$opt{backend};
      eval "require $be";
      die "Unable to locate the $class back-end $be: $@" if $@;
      $BACKEND = $opt{backend} eq 'AC' ? 'GD' : $opt{backend};
   } else {
      require GD::SecurityImage::GD;
      $BACKEND = 'GD';
   }
   push @ISA, 'GD::SecurityImage::' . $BACKEND;
   push @ISA, qw(GD::SecurityImage::Styles); # load styles
}

sub new {
   my $class = shift;
      $BACKEND || die "You didn't import $class!";
   my %opt   = scalar @_ % 2 ? () : (@_);
   my $self  = {
      IS_MAGICK       => $BACKEND eq 'Magick',
      IS_GD           => $BACKEND eq 'GD',
      IS_CORE         => $BACKEND eq 'GD' || $BACKEND eq 'Magick',
      DISABLED        => {}, # list of methods that a backend (or some older version of backend) can't do
      MAGICK          => {}, # Image::Magick configuration options
      GDBOX_EMPTY     => 0,  # GD::SecurityImage::GD::insert_text() failed?
      _RANDOM_NUMBER_ => '', # random security code
      _RNDMAX_        => 6,  # maximum number of characters in a random string.
      _COLOR_         => {}, # text and line colors
      _CREATECALLED_  => 0,  # create() called? (check for particle())
      _TEXT_LOCATION_ => {}, # see info_text
   };
   bless $self, $class;
   my %options = (
      width      => $opt{width}               || 80,
      height     => $opt{height}              || 30,
      ptsize     => $opt{ptsize}              || 20,
      lines      => $opt{lines}               || 10,
      rndmax     => $opt{rndmax}              || $self->{_RNDMAX_},
      rnd_data   => $opt{rnd_data}            || [0..9],
      font       => $opt{font}                || '',
      gd_font    => $self->gdf($opt{gd_font}) || '',
      bgcolor    => $opt{bgcolor}             || [255, 255, 255],
      send_ctobg => $opt{send_ctobg}          || 0,
      frame      => defined($opt{frame}) ? $opt{frame} : 1,
      scramble   => $opt{scramble}            || 0,
      angle      => $opt{angle}               || 0,
      thickness  => $opt{thickness}           || 0,
      _ANGLES_   => [], # angle list for scrambled images
   );
   if($opt{text_location} && ref $opt{text_location} && ref $opt{text_location} eq 'HASH') {
      $self->{_TEXT_LOCATION_} = { %{$opt{text_location}}, _place_ => 1 };
   } else {
      $self->{_TEXT_LOCATION_}{_place_} = 0;
   }
   $self->{_RNDMAX_} = $options{rndmax}; 

   $self->{$_} = $options{$_} foreach keys %options;
   if($self->{angle}) { # validate angle
      $self->{angle} = 360 + $self->{angle} if $self->{angle} < 0;
      if($self->{angle} > 360) {
         die "Angle parameter can take values in the range -360..360";
      }
   }

   if ($self->{scramble}) {
      if ($self->{angle}) {
         # Does the user want a fixed angle?
         push @{ $self->{_ANGLES_} }, $self->{angle};
      } else {
         # Generate angle range. The reason for hardcoding these is; 
         # it'll be less random for 0..60 range
         push @{ $self->{_ANGLES_} }, (0,5,8,15,22,26,29,33,35,36,40,43,45,53,56);
         push @{ $self->{_ANGLES_} }, map {360 - $_} @{ $self->{_ANGLES_} }; # push negatives
      }
   }
   $self->init;
   return $self;
}

sub backends {
   my $self  = shift;
   my $class = ref($self) || $self;
   my(@list, @dir_list);
   foreach my $inc (@INC) {
      my $dir = "$inc/GD/SecurityImage";
      next unless -d $dir;
      local  *DIR;
      opendir DIR, $dir or die "opendir($dir) failed: $!";
      my @dir = readdir DIR;
      closedir DIR;
      push @dir_list, $dir;
      foreach my $file (@dir) {
         next if -d $file;
         next if $file =~ m[^\.];
         next if $file =~ m[^(Styles|AC|Handler)\.pm$];
         $file =~ s[\.pm$][];
         push @list, $file;
      }
   }
   if (defined wantarray) {
      return @list;
   } else {
      print "Available back-ends in $class v$VERSION are:\n\t"
            .join("\n\t", @list)
            ."\n\n"
            ."Search directories:\n\t"
            .join("\n\t", @dir_list);
   }
}

sub gdf {
   my $self = shift;
   return if not $self->{IS_GD};
   return $self->gdfx(@_);
}

sub random_angle {
   my $self   = shift;
   my @angles = @{ $self->{_ANGLES_} };
   my @r;
   push @r, $angles[int rand @angles] for 0..$#angles;
   return $r[int rand @r];
}

sub random_str { shift->{_RANDOM_NUMBER_} }

sub random {
   my $self = shift;
   my $user = shift;
   if($user and length($user) >= $self->{_RNDMAX_}) {
      $self->{_RANDOM_NUMBER_} = $user;
   } else {
      my @keys = @{ $self->{rnd_data} };
      my $lk   = scalar @keys;
      my $random;
         $random .= $keys[int rand $lk] for 1..$self->{rndmax};
         $self->{_RANDOM_NUMBER_} = $random;
   }
   return $self if defined wantarray;
}

sub cconvert { # convert color codes
   # GD           : return color index number
   # Image::Magick: return hex color code
   my $self   = shift;
   my $data   = shift || die "Empty parameter passed to cconvert!";
   unless($self->{IS_CORE}) {
      return $self->backend_cconvert($data);
   }
   my $is_hex = $self->is_hex($data);
   if($data && $self->{IS_MAGICK} && $is_hex) {
      return $data; # data is a hex color code and Image::Magick has hex support
   }
   if(  $data              &&
      ! $is_hex            &&
      ! ref($data)         &&
      $data !~ m{[^0-9]}   &&
      $data >= 0
      ) {
      if ($self->{IS_MAGICK}) {
         die "The number '$data' can not be transformed to a color code!";
      } else {
         # data is a GD color index number ...
         # ... or it is any number! since there is no way to determine this. 
         # GD object' s rgb() method returns 0,0,0 upon failure...
         return $data;
      }
   }
   my @rgb = $self->h2r($data);
   if(@rgb and $self->{IS_MAGICK}) {
      return $data;
   } else {
      $data = [@rgb] if @rgb;
      # initialize if not valid
      if(not $data || not ref $data || ref $data ne 'ARRAY' || $#{$data} != 2) {
         $data = [0, 0, 0];
      }
      foreach my $i (0..$#{$data}) { # check for bad values
         $data->[$i] = 0 if $data->[$i] > 255 or $data->[$i] < 0;
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
   $self->{_COLOR_} = { # set the color hash
        text  => $self->cconvert($col1),
        lines => $self->cconvert($col2),
   };

   # be a smart module and auto-disable ttf if we are under a prehistoric GD
   unless ($self->{IS_MAGICK}) {
      $method = 'normal' if defined $GD::VERSION and $GD::VERSION < 1.20;
   }

   if($method eq 'normal' and not $self->{gd_font}) {
      $self->{gd_font} = $self->gdf('giant');
   }

   $style = $self->can('style_'.$style) ? 'style_'.$style : 'style_default';
   $self->$style() unless $self->{send_ctobg};
   $self->insert_text($method);
   $self->$style() if     $self->{send_ctobg};
   $self->rectangle(0,0,$self->{width}-1,$self->{height}-1, $self->{_COLOR_}{lines})
      if $self->{frame}; # put a frame around the image
   $self->{_CREATECALLED_}++;
   return $self if defined wantarray;
}

sub particle {
   # Create random dots. They'll cover all over the surface
   my $self = shift;
   die "particle() must be called 'after' create()!" unless $self->{_CREATECALLED_};
   my $big  = $self->{height} > $self->{width} ? $self->{height} : $self->{width};
   my $f    = shift || $big * 20; # particle density
   my $dots = shift || 1; # number of multiple dots
   my $int  = int $big / 20;
   my @random;
   for (my $x = $int; $x <= $big; $x += $int) {
      push @random, $x;
   }
   my($x, $y, $z);
   for (1..$f) {
      $x = int rand $self->{width};
      $y = int rand $self->{height};
      foreach $z (1..$dots) {
         $self->setPixel($x + $z                            , $y + $z                            , $self->{_COLOR_}{text});
         $self->setPixel($x + $z + $random[int rand @random], $y + $z + $random[int rand @random], $self->{_COLOR_}{text});
      }
   }
   return $self if defined wantarray;
}

sub raw {shift->{image}} # raw image object

sub info_text { # set text location
   # x      => 'left|right',  # text-X
   # y      => 'up|low|down', # text-Y
   # strip  => 1|0,           # add strip?
   # gd     => 1|0,           # use default GD font?
   # ptsize => 10,            # point size
   # color  => '#000000',     # text color
   # scolor => '#FFFFFF',     # strip color
   # text   => 'blah',        # modifies random code
   my $self = shift;
   die "info_text() must be called 'after' create()!" unless $self->{_CREATECALLED_};
   my %o = scalar(@_) % 2 ? () : (qw/x right y up strip 1/, @_);
   return unless %o;

   $o{scolor} = $self->cconvert($o{scolor}) if $o{scolor};
   $self->{_TEXT_LOCATION_}->{_place_} = 1;
   local $self->{_RANDOM_NUMBER_} = delete $o{text} if $o{text};
   local $self->{_COLOR_}{text}   = $self->cconvert(delete $o{color}) if $o{color};
   local $self->{ptsize}          = delete $o{ptsize} if $o{ptsize};

   local $self->{scramble} = 0; # disable. we need a straight text
   local $self->{angle}    = 0; # disable. RT:14618

   $self->{_TEXT_LOCATION_}->{$_} = $o{$_} foreach keys %o;
   $self->insert_text('ttf');
   $self;
}

#--------------------[ PRIVATE ]--------------------#

sub add_strip { # adds a strip to the background of the text
   my $self = shift;
   my($x, $y, $box_w, $box_h) = @_;
   my $tl    = $self->{_TEXT_LOCATION_};
   my $black = $self->cconvert($self->{_COLOR_}{text} ? $self->{_COLOR_}{text} : [0,0,0]);
   my $white = $self->cconvert($tl->{scolor}          ? $tl->{scolor}          : [255,255,255]);
   my $x2    = $tl->{x} eq 'left' ? $box_w : $self->{width};
   my $y2    = $self->{height} - $box_h;
   my $i     = $self->{IS_MAGICK} ? $self : $self->{image};
   my $up    = $tl->{y} eq 'up';
   $i->filledRectangle($up ? ($x-1, 0, $x2, $y+1) : ($x-1, $y2-1, $x2  , $self->{height}  ), $black);
   $i->filledRectangle($up ? ($x  , 1, $x2-2, $y) : ($x  , $y2  , $x2-2, $self->{height}-2), $white);
}

sub r2h {
   # Convert RGB to Hex
   my $self = shift;
   @_ == 3 || return;
   my $color  = '#';
      $color .= sprintf("%02x", $_) foreach @_;
      $color;
}

sub h2r {
   # Convert Hex to RGB
   my $self  = shift;
   my $color = shift;
   return if ref $color;
   my @rgb   = $color =~ m[^#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})$]i;
   return @rgb ? map { hex $_ } @rgb : undef;
}

sub is_hex {
   my $self = shift;
   my $data = shift;
   return $data =~ m[^#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})$]i;
}

sub AUTOLOAD {
   my $self = shift;
   (my $name = $AUTOLOAD) =~ s,.*:,,;
   if ($name eq 'gdbox_empty') { # fake method for GD compatibility. only GD has this
      return 0;
   }
   die "Unknown ".ref($self)." method '$name'!";
}

sub DESTROY {}

1;

__END__

=head1 NAME

GD::SecurityImage - Security image (captcha) generator.

=head1 SYNOPSIS

   use GD::SecurityImage;

   # Create a normal image
   my $image = GD::SecurityImage->new(width   => 80,
                                      height  => 30,
                                      lines   => 10,
                                      gd_font => 'giant');
      $image->random($your_random_str);
      $image->create(normal => 'rect');
   my($image_data, $mime_type, $random_number) = $image->out;

or

   # use external ttf font
   my $image = GD::SecurityImage->new(width    => 100,
                                      height   => 40,
                                      lines    => 10,
                                      font     => "/absolute/path/to/your.ttf",
                                      scramble => 1);
      $image->random($your_random_str);
      $image->create(ttf => 'default');
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
taste.

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

If you want to use the default interface, set this paramater. The 
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
But, if you want to use letters also, you can set this paramater.
This paramater takes an array reference as the value.

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
informations can be an example for that. 

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
TTF font paramter can not be set with C<info_text()>. The value passed
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

Can be usefull, if you want to modify the graphic yourself. If you 
want to get an I<image type> see the C<force> option in C<out>.

=head2 gdbox_empty

See L</"path bug"> in L</"GD bug"> for usage and other information 
on this method.

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

and

   backend_cconvert	for HEX & RGB color handling

See GD::SecurityImage::Magick for the first part of methods and see 
cconvert() method in GD::SecurityImage to define such a method. Your 
backend_cconvert() method must be capable of handling both HEX and RGB 
values. The parametes passed to drawing methods (like line()) are 
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

Contact the author if you find any bugs. You can also send requests.

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

=over 4

=item *

L<GD>, L<Image::Magick>, L<ImagePwd>, L<Authen::Captcha>.

=item *

L<GD::SecurityImage::AC>: C<Authen::Captcha> drop-in replacement module.

=item *

C<ImageCode> Perl Module (commercial): L<http://www.progland.com/ImageCode.html>.

=item *

The CAPTCHA project: L<http://www.captcha.net/>.

=item *

A definition of CAPTCHA (From Wikipedia, the free encyclopedia):
L<http://en.wikipedia.org/wiki/Captcha>.

=back

=head1 AUTHOR

Burak Gürsoy, E<lt>burakE<64>cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2004-2006 Burak Gürsoy. All rights reserved.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself, either Perl version 5.8.7 or, 
at your option, any later version of Perl 5 you may have available.

=cut
