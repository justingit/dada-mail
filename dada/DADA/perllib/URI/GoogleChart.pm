package URI::GoogleChart;

use strict;

our $VERSION = "1.02";

use URI;
use Carp qw(croak carp);

my $BASE = "http://chart.apis.google.com/chart";

our %TYPE_ALIAS = (
    "lines" => "lc",
    "sparklines" => "ls",
    "xy-lines" => "lxy",

    "horizontal-stacked-bars" => "bhs",
    "vertical-stacked-bars" => "bvs",
    "horizontal-grouped-bars" => "bhg",
    "vertical-grouped-bars" => "bvg",

    "pie" => "p",
    "pie-3d" => "p3",
    "3d-pie" => "p3",
    "concentric-pie" => "pc",

    "venn" => "v",
    "scatter-plot" => "s",
    "radar" => "r",
    "radar-splines" => "rs",
    "google-o-meter" => "gom",

    "africa" => "t",
    "asia" => "t",
    "europe" => "t",
    "middle_east" => "t",
    "south_america" => "t",
    "usa" => "t",
    "world" => "t",
);

our %COLOR_ALIAS = (
    "red"     => "FF0000",
    "lime"    => "00FF00",
    "blue"    => "0000FF",

    "green"   => "008000",
    "navy"    => "000080",

    "yellow"  => "FFFF00",
    "aqua"    => "00FFFF",
    "fuchsia" => "FF00FF",
    "maroon"  => "800000",
    "purple"  => "800080",
    "olive"   => "808000",
    "teal"    => "008080",

    "white"   => "FFFFFF",
    "silver"  => "C0C0C0",
    "gray"    => "808080",
    "black"   => "000000",

    "transparent" => "00000000",
);

our %AXIS_ALIAS = (
    "left"   => "y",
    "right"  => "r",
    "top"    => "t",
    "bottom" => "x",
);

our %ENCODING_ALIAS = (
    "text"     => "t",
    "simple"   => "s",
    "extended" => "e",
);

# constants for data encoding
my @C = ("A" .. "Z", "a" .. "z", 0 .. 9, "-", ".");
my $STR_s = join("", @C[0 .. 61]);
my $STR_e = do {
    my @v;
    for my $x (@C) {
	for my $y (@C) {
	    push(@v, "$x$y");
	}
    }
    join("", @v);
};
die unless length($STR_s) == 62;
die unless length($STR_e) == 4096 * 2;


sub new {
    my($class, $type, $width, $height, %opt) = @_;

    croak("Chart type not provided") unless $type;
    croak("Chart size not provided") unless $width && $height;

    my %param = (
	cht => $TYPE_ALIAS{$type} || $type,
	chs => join("x", $width, $height),
    );
    $param{chtm} = $type if $param{cht} eq "t" && $type ne "t";  # maps

    my %handle = (
	data => \&_data,
	range => 1,
	min => 1,
	max => 1,
	range_round => 1,
	range_show => 1,
	encoding => 1,

	color => sub {
	    my $v = shift;
	    $v = [$v] unless ref($v);
	    $param{chco} = join(",", map _color($_), @$v);
	},
	background => sub {
	    $param{chf} = "bg,s," . _color(shift);
	},
	title => sub {
	    my $title = shift; 
	    ($title, my($color, $size)) = @$title if ref($title) eq "ARRAY";
	    $title =~ s/\n+\z//;
	    $title =~ s/\n/|/g;
	    $param{chtt} = $title;
	    if (defined($color) || defined($size)) {
		$color = defined($color) ? _color($color) : "";
		$size = "" unless defined $size;
		$param{chts} = "$color,$size";
	    }
	},
	label => sub {
	    my $lab = shift;
	    $lab = [$lab] unless ref($lab) eq "ARRAY";
	    my $k = $param{cht} =~ /^p|^gom$/ ? "chl" : "chdl";
	    $param{$k} = join("|", @$lab);
	},
	rotate => sub {
	    my $p = shift;
	    $p += 360 while $p < 0;
	    $p /= 180 / 3.1416;  # convert to radians
	    $param{chp} = sprintf "%.2f", $p;
	},
	margin => sub {
	    my $m = shift;
	    $m = [($m) x 4] unless ref($m);
	    $param{chma} = join(",", @$m);
	}
    );

    my $data = delete $opt{data};  # need to be processed last
    for my $k (keys %opt) {
	if (my $h = $handle{$k}) {
	    $h->($opt{$k}, \%param, \%opt) if ref($h) eq "CODE";
	}
	else {
	    $param{$k} = $opt{$k};
	    carp("Unrecognized parameter '$k' embedded in GoogleChart URI")
		unless $k =~ /^ch/;
	}
    }
    _data($data, \%param, \%opt) if $data;

    # generate URI
    my $uri = URI->new($BASE);
    $uri->query_form(map { $_ => $param{$_} } _sort_chart_keys(keys %param));
    for ($uri->query) {
	s/%3A/:/g;
	s/%2C/,/g;
	s/%7C/|/g; # XXX doesn't work (it ends up encoded anyways)
	$uri->query($_);
    }
    return $uri;
}

sub _color {
    local $_ = shift;
    return $COLOR_ALIAS{$_} ||
	(/^[\da-fA-F]{3}\z/ ? join("", map "$_$_", split(//, $_)) : $_);
}

sub _sort_chart_keys {
    my %o = ( cht => 1, chtm => 2, chs => 3, chd => 100 );
    return sort { ($o{$a}||=99) <=> ($o{$b}||=99) || $a cmp $b } @_;
}

sub _default_minmax {
    my $param = shift;
    my $t = $param->{cht};
    return 0, undef if $t =~ /^p/;  # pie chart
    return 0, undef if $t eq "v";   # venn
    return 0, undef if $t =~ /^r/;  # radar chart
    return 0, undef if $t =~ /^b/;  # bar chart
    return 0, 100   if $t eq "gom"; # meter
    return;
}

sub _data {
    my($data, $param, $opt) = @_;

    # various shortcuts
    $data = _deep_copy($data);  # want to modify it
    if (ref($data) eq "ARRAY") {
	$data = [$data] unless ref($data->[0]);
    }
    elsif (ref($data) eq "HASH") {
	$data = [$data];
    }
    else {
	$data = [[$data]];
    }

    my $range = _deep_copy($opt->{range});
    for (qw(min max range_round range_show)) {
	(my $r = $_) =~ s/^range_//;
	$range->{""}{$r} = $opt->{$_} if exists $opt->{$_};
    }

    my $vcount = 0;
    for my $set (@$data) {
	$set = { v => $set } if ref($set) eq "ARRAY";
	my $v = $set->{v};
	my $r = $set->{range} ||= "";
	my $rh = $range->{$r} ||= {};

	my($min, $max) = _default_minmax($param);
	my $i = 0;
	for (@$v) {
	    next unless defined;
	    $min = $_ if !defined($min) || $_ < $min;
	    $max = $_ if !defined($max) || $_ > $max;
	    if ($param->{cht} =~ /^b.s\z/) {
		# stacked stuff
		$rh->{stacked}{min}[$i] ||= 0;
		$rh->{stacked}{max}[$i] ||= 0;
		$rh->{stacked}{$_ < 0 ? "min" : "max"}[$i] += $_;
	    }
	}
	continue {
	    $i++;
	}
	$vcount += @$v;

	if ($rh->{stacked}) {
	    # XXX we really only need to this after we have processed
	    # the last dataset, the other rounds it's wasted effort
	    ($min, $max) = (0, 0);
	    for (qw(min max)) {
		for my $v (@{$rh->{stacked}{$_}}) {
		    next unless defined $v;
		    if ($_ eq "min") {
			$min = $v if $v < $min;
		    }
		    else {
			$max = $v if $v > $max;
		    }
		}
	    }
	}

	if (defined $min) {
	    my %h = (min => $min, max => $max);
	    for my $k (keys %h) {
		if (defined $set->{$k}) {
		    $h{$k} = $set->{$k};
		}
		else {
		    $set->{$k} = $h{$k};
		}

		my $rv = $rh->{$k};
		if (!defined($rv) ||
		    ($k eq "min" && $h{$k} < $rv) ||
		    ($k eq "max" && $h{$k} > $rv)
		   )
		{
		    $rh->{$k} = $h{$k};
		}
	    }
	}
    }

    # should we round any of the ranges
    for my $r (values %$range) {
	next unless $r->{round};

	use POSIX qw(floor ceil);
	sub log10 { log(shift) / log(10) }

	my($min, $max) = @$r{"min", "max"};
	my $range = $max - $min;
	next if $range == 0;
	die "Assert" if $range < 0; 

	my $step = 10 ** int(log10($range));
	$step /= 10 if $step / $range >= 0.1;
	$step *= 5 if $step / $range < 0.05;

	$min = floor($min / $step - 0.2) * $step;
	$max = ceil($max / $step + 0.2) * $step;

	# zero based minimum is usually a good thing so make it more likely
	$min = 0 if $min > 0 && $min/$range < 0.4;

	@$r{"min", "max"} = ($min, $max);
    }

    #use Data::Dump; dd $data;
    #use Data::Dump; dd $range;

    # encode data
    my $e = $ENCODING_ALIAS{$opt->{encoding} || ""} || $opt->{encoding};
    unless ($e) {
	# try to me a little smart about selecting a suitable encoding based
	# on the number of data points we're plotting and the resolution of
	# the generated image
	my @s = ($param->{chs} =~ /(\d+)/g);
	my $res = $s[0] * $s[1];
	if ($vcount < 20) {
	    $e = "t";
	}
	elsif ($vcount > 256 || $res < 300*200) {
	    $e = "s";
	}
	else {
	    $e = "e";
	}
    }

    my %enc = (
	t => {
	    null => -1,
	    sep1 => ",",
	    sep2 => "|",
	    fmt => sub {
		my $v = 100 * shift;
		$v = sprintf "%.1f", $v if $v ne int($v);
		$v;
	    },
	},
	s => {
	    null => "_",
	    sep1 => "",
	    sep2 => ",",
	    fmt => sub {
		return substr($STR_s, $_[0] * length($STR_s) - 0.5, 1);
	    },
	},
	e => {
	    null => "__",
	    sep1 => "",
	    sep2 => ",",
	    fmt => sub {
		return substr($STR_e, int($_[0] * length($STR_e) / 2 - 0.5) * 2, 2);
	    },
	}
    );
    my $enc = $enc{$e} || croak("unsupported encoding $e");
    my @res;
    for my $set (@$data) {
        my($min, $max) = @{$range->{$set->{range}}}{"min", "max"};
	my $v = $set->{v};
	for (@$v) {
	    if (defined($_) && $_ >= $min && $_ <= $max && $min != $max) {
		$_ = $enc->{fmt}(($_ - $min) / ($max - $min));
	    }
	    else {
		$_ = $enc->{null};
	    }
	}
	push(@res, join($enc->{sep1}, @$v));
    }
    $param->{chd} = "$e:" . join($enc->{sep2}, @res);

    # handle bar chart zero line if we charted negative data
    if ($param->{cht} =~ /^b/) {
        my($min, $max) = @{$range->{""}}{"min", "max"};
	if ($min < 0) {
	    $param->{chp} = $max < 0 ? 1 : sprintf "%.2f", -$min / ($max - $min);
	}
    }

    # enable axis labels?
    for (sort keys %$range) {
	my $r = $range->{$_};
	my @chxt = split(/,/, $param->{chxt} || "");
	my @chxr = split(/\|/, $param->{chxr} || "");
	if (my $rshow = $r->{show}) {
	    my($min, $max) = @$r{"min", "max"};
	    for ($min, $max) {
		$_ = sprintf "%.2g", $_;
	    }
	    push(@chxt, $AXIS_ALIAS{$rshow} || $rshow);
	    my $i = $#chxt;
	    push(@chxr, "$i,$min,$max");
	}
	if (@chxt) {
	    $param->{chxt} = join(",", @chxt);
	    $param->{chxr} = join("|", @chxr);
	}
    }
}

sub _deep_copy {
    my $o = shift;
    return $o unless ref($o);
    return [map _deep_copy($_), @$o] if ref($o) eq "ARRAY";
    return {map { $_ => _deep_copy($o->{$_}) } keys %$o} if ref($o) eq "HASH";
    die "Can't copy " . ref($o);
}

1;

__END__

=head1 NAME

URI::GoogleChart - Generate Google Chart URIs

=head1 SYNOPSIS

 use URI::GoogleChart;
 my $chart = URI::GoogleChart->new("lines", 300, 100,
     data => [45, 80, 55, 68],
     range_show => "left",
     range_round => 1,
 );

 # save chart to a file
 use LWP::Simple qw(getstore);
 getstore($chart, "chart.png");

 # or embed chart in an HTML file
 use HTML::Entities;
 my $enc_chart = encode_entities($chart);

 open(my $fh, ">", "chart.html") || die;
 print $fh qq(
     <h1>My Chart</h1>
     <p><img src="$enc_chart"></p>
 );
 close($fh) || die;

=head1 DESCRIPTION

This module provide a constructor method for Google Chart URLs.  When
dereferenced Google will serve back PNG images of charts based on the
provided parameters.

The Google Chart service is described at L<http://code.google.com/apis/chart/>
and these pages also define the Web API in terms of the parameters these URLs
take.  This module make it easier to generate URLs that conform to this API as
it automatically takes care of data encoding and scaling, as well as hiding
most of the cryptic parameter names that the API uses in order to generate
shorter URLs.

The following constructor method is provided:

=over

=item $uri = URI::GoogleChart->new( $type, $width, $height, %opt )

The constructor method's first 3 arguments are mandatory and they define the
type of chart to generate and the dimension of the image in pixels.
Additional arguments are provided as key/value pairs.  The return value
is an HTTP L<URI> object, which can also be treated as a string.

The $type argument can either be one of the type code documented at the Google
Charts page or one of the following more readable aliases:

    lines
    sparklines
    xy-lines

    horizontal-stacked-bars
    vertical-stacked-bars
    horizontal-grouped-bars
    vertical-grouped-bars

    pie
    pie-3d
    concentric-pie

    venn
    scatter-plot
    radar
    radar-splines
    google-o-meter

    world
    africa
    asia
    europe
    middle_east
    south_america
    usa

The additional arguments in the form of key/value pairs can either be one of
the C<chXXX> parameters documented on the Google Chart pages or one of the
following:

=over

=item data => [{ v => [$v1, $v2,...], %opt }, ...]

=item data => [[$v1, $v2,...], [$v1, $v2,...], ...]

=item data => [$v1, $v2,...]

=item data => $v1

The data to be charted is provided as an array of data series.  In the most
general form each series is defined by a hash with the "v" element being an
array of data points (numbers) in the series.  Missing data points should be
provided as C<undef>.  Other hash elements can be provided to define various
properties of the series.  These are described below.

As a short hand when you don't need to define other properties besides the data
points you can provide an array of numbers instead of the series hash.

As a short hand when you only have a single data series, you can provide a
single array of numbers, and finally if you only have a single number you can
provide it without wrapping it in an array.

Data series belong to ranges.  A range is defined by a minimum and a maximum
value.  Data points are scaled so that they are plotted relative to the range
they belong to.  For example if the range is (5 .. 10) then a data point value
of 7.5 is plotted in the middle of the chart area.  Ranges are automatically
calculated based on the data provided, but you can also force certain minimum
and maximum values to apply.

The following data series properties can be provided in addition to "v"
described above:

The "range" property can be used to group data series together that belong to
the same range.  The value of the "range" property is a range name.  Data
series without a "range" property belong to the default range.

=item min => $num

=item max => $num

Defines the default minimum and maximum value for the default range.  If not
provided the minimum and maximum is calculated from the data points belonging
to this range.

The specified minimum or maximum are ignored if some of data values provided
are outside this range.

Chart types that plot relative values (like bar charts or venn diagrams) should
use 0 as the minimum, as this make the relative size of the data points stay
the same after scaling.  Because of this the default default minimum for these
charts is 0, so you don't actually need to specify it.

=item range_round => $bool

Extend the default range so that the min/max values are nice
multiples of 1, 5, 10, 50, 100,... and such numbers.  This gives the chart more
"air" and look better if you display the range of values with "range_show".

=item range_show => "left"

=item range_show => "right"

=item range_show => "top"

=item range_show => "bottom"

Makes the given axis show the range of values charted for the default range.

=item range => { $name => \%opt, ...},

Define parameters for named data series ranges.  The range named "" is the
default range.

The option values that can be set are "min", "max", "round", "show".  See the
description of the corresponding entry for the default range above.

=item encoding => "t"

=item encoding => "s"

=item encoding => "e"

Select what kind of data encoding you want to be used.   They differ in the
resolution they provide and in their readability and verbosity.  Resolution
matters if you generate big charts.  Verbosity matters as some web client might
refuse to dereference URLs that are too long.

The "t" (or "text") encoding is the most readable and verbose.  It might
consume up to 5 bytes per data point. It provide a resolution of 1/1000.

The "s" (or "simple") encoding is the most compact; only consuming 1 byte per
data point.  It provide a resolution of 1/62.

The "e" (or "extended") encoding provides the most resolution and it consumes 2
bytes per data point.  It provide a resolution of 1/4096.

The default encoding is  automatically selected based on the resolution of the
chart and the number of data points provided.

=item color => $color

=item color => [$color1, $color2, ...]

Sets the colors to use for charting the data series.  The canonical form for
$color is hexstrings either of "RRGGBB" or "RRGGBBAA" form.  When you use this
interface you might also use "RGB" form as well as some comon names like "red",
"blue", "green", "white", "black",... which are expanded to the canonical form
in the URL.

The built in colors are the 16 colors of the HTML specification
(see L<http://en.wikipedia.org/wiki/HTML_color_names>).
If you want to use additional color names you can assign your mapping to
the %URI::GoogleChart::COLOR_ALIAS hash before start creating charts.  Example:

    local $URI::GoogleChart::COLOR_ALIAS{"gold"} = "FFD700";


=item background => $color

Sets the color for the chart background.  See description for color above for
how to specify color values.  The color value "transparent" gives you a fully
transparent background.

=item title => $str

=item title => [ $str, $color, $fontsize ]

Sets the title for the chart; optionally changing the color and fontsize used
for the title.

=item label = $str

=item label = [ $str, $str,... ]

Labels the data (or data series) of the chart.

=item rotate => $degrees

Rotate the orientation of a pie chart (clockwise).

The first slice starts at the right side of the pie (at 3 o'clock).  If you
rotate the pie 90 degrees the first slice starts at the bottom.  If you rotate
-90 degrees (or 270) the first slices starts at the top of the pie. 

=item margin => $num

=item margin => [ $left, $right, $top, $bottom ]

Sets the chart margins in pixels.  If a single number is provided then all
the margins are set to this number of pixels.

=back

=back

=head1 SEE ALSO

L<http://cpansearch.perl.org/src/GAAS/URI-GoogleChart-1.02/examples.html>

L<http://code.google.com/apis/chart/>

L<URI>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Gisle Aas.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
