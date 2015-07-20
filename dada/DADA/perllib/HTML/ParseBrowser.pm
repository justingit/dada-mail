package HTML::ParseBrowser;
$HTML::ParseBrowser::VERSION = '1.10';
use 5.006;
use strict;
use warnings;

use vars qw($AUTOLOAD);

my %lang =
(
    'en' => 'English',
    'de' => 'German',
    'fr' => 'French',
    'es' => 'Spanish',
    'it' => 'Italian',
    'da' => 'Danish',
    'ja' => 'Japanese',
    'ru' => 'Russian',
);
my $langRE = join('|', keys %lang);

my %name_map =
(
    'Mozilla'   => 'Netscape',
    'Gecko'     => 'Mozilla',
    'Netscape6' => 'Netscape',
    'MSIE'      => 'Internet Explorer',
);

sub new {
    my $class   = shift;
    my $browser = {};
    bless $browser, ref $class || $class;
    $browser->Parse(shift);
    return $browser;
}

sub Parse {
    my $browser   = shift;
    my $ua_string = shift;
    my $useragent = $ua_string;
    my $version;
    delete $browser->{$_} for keys %{$browser};
    return undef unless $useragent;
    return undef if $useragent eq '-';
    $browser->{user_agent} = $useragent;
    $useragent =~ s/Opera (?=\d)/Opera\//i;

    while ($useragent =~ s/\[(\w+)\]//) {
        push @{$browser->{languages}}, $lang{$1} || $1;
        push @{$browser->{langs}}, $1;
    }

    while ($useragent =~ /\((.*?)\)/) {
        $browser->{detail} .= '; ' if defined($browser->{detail});
        $browser->{detail} .= $1;
        $useragent =~ s/\((.*?)\)//;
    }
    if (defined($browser->{detail})) {
        $browser->{properties} = [split /;\s+/, $browser->{detail}];
    }

    $browser->{useragents} = [grep /\//, split /\s+/, $useragent];

    if ($ua_string =~ /(iPhone|iPad|iPod).*?OS\s+(\d_\d(_\d)?)/) {
        $browser->{name} = 'Safari';
        $browser->{os} = $browser->{ostype} = 'iOS';
        ($browser->{osvers} = $2) =~ s/_/./g;
        if ($useragent =~ m!(Version|CriOS)/((\d+)(\.(\d+)[\.0-9]*)?)!) {
            if ($1 eq 'CriOS') {
                $browser->{name} = 'Chrome';
            }
            $browser->{version}->{v}     = $2;
            $browser->{version}->{major} = $3;
            $browser->{version}->{minor} = $5 if defined($5) && $5 ne '';
        }
    }
    elsif ($ua_string =~ m!\((BlackBerry|BB10).*Version/([0-9\.]+)!) {
        my $version_string = $2;
        $browser->{name} = $browser->{ostype} = 'BlackBerry';
        $browser->{version}->{v} = $version_string;
        if ($version_string =~ m!^([0-9]+)(\.([0-9]+).*)?!) {
            $browser->{version}->{major} = $browser->{osvers} = $1;
            $browser->{os}               = "BlackBerry $1";
            $browser->{version}->{minor} = $3 if defined($3) && $3 ne '';
        }
    }
    elsif ($ua_string =~ m!Mozilla/5.0 \(.*?Windows.*?; rv:((\d+)\.(\d+))\) like Gecko!) {
        $browser->{name} = 'MSIE';
        $browser->{version}->{v} = $1;
        $browser->{version}->{major} = $2;
        $browser->{version}->{minor} = $3;
    } elsif ($useragent =~ m!OPR/((\d+)\.(\d+)\.\d+\.\d+)!) {
        $browser->{name}             = 'Opera';
        $browser->{version}->{v}     = $1;
        $browser->{version}->{major} = $2;
        $browser->{version}->{minor} = $3;
    } elsif ($useragent =~ m!\bVersion/((\d+)\.(\d+)\S*) Safari/!) {
        $browser->{name}             = 'Safari';
        $browser->{version}->{v}     = $1;
        $browser->{version}->{major} = $2;
        $browser->{version}->{minor} = $3;
    } elsif ($useragent =~ m!Opera/.*Version/((\d+)\.(\d+)\S*)$!) {
        $browser->{name}             = 'Opera';
        $browser->{version}->{v}     = $1;
        $browser->{version}->{major} = $2;
        $browser->{version}->{minor} = $3;
    } else {
        for (@{$browser->{useragents}}) {
            my ($br, $ver) = split /\//;
            $br = 'Chrome' if $br eq 'CriOS';
            $browser->{name} = $br;
            $browser->{version}->{v} = $ver;
            if ($ver =~ m!^v?(\d+)\.(\d+)!) {
                ($browser->{version}->{major}, $browser->{version}->{minor}) = ($1, $2);
            }
            last if lc($br) eq 'iron';
            last if lc($br) eq 'lynx';
            last if lc($br) eq 'chrome';
            last if lc($br) eq 'opera';
        }
    }

    for (@{$browser->{properties}}) {
        /compatible/i and next;

        unless (defined($browser->{name}) && (lc($browser->{name}) eq 'webtv' || lc($browser->{name}) eq 'opera')) {
            /^MSIE (.*)$/ and do {
                $browser->{name} = 'MSIE';
                $browser->{version}->{v} = $1;
                ($browser->{version}->{major},
                $browser->{version}->{minor}) = split /\./, $1, 2;
            };
        }

        if (m!^AOL ([0-9].*)!) {
            $browser->{name} = 'AOL';
            $browser->{version}->{v} = $1;
            ($browser->{version}->{major}, $browser->{version}->{minor}) = split /\./, $browser->{version}->{v};
        }

        /^Konqueror\/([-0-9.a-z]+)/ and do {
            $browser->{name} = 'Konqueror';
            $browser->{version}->{v} = $1;
            ($browser->{version}->{major}, $browser->{version}->{minor}) = split /\./, $browser->{version}->{v};
        };

        /\bCamino\/([0-9.]+)/ and do {
            $browser->{name} = 'Camino';
            $browser->{version}->{v} = $1;
            ($browser->{version}->{major}, $browser->{version}->{minor}) = split /\./, $browser->{version}->{v}, 2;
        } and last;

        if (m!^Opera Mini/([0-9.]+)!) {
            $browser->{name} = 'Opera Mini';
            $browser->{version}->{v} = $1;
            ($browser->{version}->{major}, $browser->{version}->{minor}) = split /\./, $browser->{version}->{v};
        }

        if (/^Win/) {
            $browser->{os} = $_;
            $browser->{ostype} = 'Windows';
            if (/Windows NT\s*((\d+)(\.\d+)?)/ || /^WinNT((\d+)(\.\d+)?)/) {
                $browser->{ostype} = 'Windows NT';
                $version = $1;
                if ($version >= 6.3) {
                    $browser->{osvers} = '8.1';
                } elsif ($version >= 6.2) {
                    $browser->{osvers} = '8';
                } elsif ($version >= 6.1) {
                    $browser->{osvers} = '7';
                } elsif ($version >= 6.06) {
                    $browser->{osvers} = 'Server 2008';
                } elsif ($version >= 6.0) {
                    $browser->{osvers} = 'Vista';
                } elsif ($version >= 5.1) {
                    $browser->{osvers} = 'XP';
                } elsif ($version >= 5.0) {
                    $browser->{osvers} = '2000';
                } else {
                    $browser->{osvers} = $version;
                }
            }
            elsif (/Windows (\d+(\.\d+)?)/) {
                $browser->{osvers} = $1;
            } elsif (/Win(\w\w)/i) {
                $browser->{osvers} = $1;
            }
        }

        if (/^Mac/) {
            $browser->{os} = $_;
            $browser->{ostype} = 'Macintosh';
            (undef, $browser->{osvers}) = split /[ _]/, $_, 2;
        }

        if (/^PPC$/) {
            $browser->{osarc} = 'PPC';
        }

        # TODO: parsing of version and osarc doesn't always get it right. See Danish Opera test
        if (/Android\s([\.0-9]+)/) {
            $browser->{os}     = 'Android';
            $browser->{ostype} = 'Linux';
            $browser->{osvers} = $1;
        } elsif (/^Linux/) {
            my $lstr = $_;
            $browser->{os}     = 'Linux';
            $browser->{ostype} = 'Linux';
            if ($lstr =~ s/(i386|mips|amd64|sparc64|ppc|i686|i586|armv51|x86|x86-64|x86_64|ppc64|x64|x64_64)\b//) {
                $browser->{osarc} = $1;
            }
            if ($lstr =~ / (\d+\.\S+)/) {
                $browser->{osvers} = $1;
            }
        }

        if (/^(SunOS|Solaris)/i) {
            $browser->{os} = $_;
            $browser->{ostype} = 'Solaris';
            if (/(sun4[a-z]|i86pc)/) {
                $browser->{osarc} = $1;
            }
            if (/^SunOS\s*([0-9\.]+)/) {
                $browser->{osvers} = $1;
            }
        }

        if (/^($langRE)-/ || /^($langRE)$/) {
            my $langCode = $1;
            push(@{$browser->{languages}}, $lang{$langCode});
            push(@{$browser->{langs}}, $langCode);
        }
    }

    if (defined($browser->{name}) && exists $name_map{ $browser->{name} }) {
        $browser->{name} = $name_map{ $browser->{name} };
    }

    $browser->{name} ||= $useragent;

    if ($browser->{name} eq 'Konqueror') {
        $browser->{ostype} ||= 'Linux';
    }

    my %langs_in;

    for (@{$browser->{langs}}) {
        $langs_in{$_}++;
    }

    if (int(keys %langs_in) > 0) {
        ($browser->{lang}) = sort {$langs_in{$a} <=> $langs_in{$b}} keys %langs_in;
        $browser->{language} = $lang{$browser->{lang}} || $browser->{lang};
        # delete $browser->{language} unless $browser->{language};
    }
    return $browser;
}

sub DESTROY {
}

sub AUTOLOAD {
    my $self   = shift;
    my $method = lc($AUTOLOAD);
    $method =~ s/^.*\:\://;

    if (exists($self->{$method})) {
        return $self->{$method};
    } elsif (exists($self->{version}->{$method})) {
        return $self->{version}->{$method};
    }

    return undef;
}

__END__

=head1 NAME

HTML::ParseBrowser - Simple interface for User-Agent string parsing

=head1 SYNOPSIS

  use HTML::ParseBrowser;
  
  # Opera 6 on Windows 98, French
  my $uastring = 'Mozilla/4.0 (compatible; MSIE 5.0; Windows 98) Opera 6.0  [fr]';
  
  my $ua = HTML::ParseBrowser->new($uastring);
  print "Browser  : ", $ua->name, "\n";
  print "Version  : ", $ua->v, "\n";
  print "OS       : ", $ua->os, "\n";
  print "Language : ", $ua->language, "\n";

=head1 DESCRIPTION

HTML::ParseBrowser is a module for parsing a User-Agent string, and providing access to
parts of the string, such as browser name, version, and operating system.
Some of the returned values are exactly as they appeared in the User-Agent string,
and others are interpreted; for example Internet Explorer identifies itself as B<MSIE>,
but the B<name> method will return B<Internet Explorer>.

It provides the following methods:

=over 4

=item new() (constructor method)

Accepts an optional User Agent string as an argument. If present, the string
will be parsed and the object populated. Either way the base object will be
created.

=item Parse()

Intended to be given a User Agent string as an argument. If present, it will be
parsed and the object repopulated.

If called without a true argument or with the argument '-' Parse() will simply
depopulate the object and return undef. (This is useful for parsing logs, which
often fill in a '-' for a null value.)

=item Access methods

The following methods are used to access different parts of the User-Agent string.

If the particular piece of information wasn't included in the User-Agent string
provided, or it couldn't be parsed, then the relevant method will return undef.

Also, not that some browsers let the user change the User-Agent string,
as do many libraries. So there is no guarantee that a User-Agent string you
find in a logfile is valid, or makes sense.

=back

=over 4

=item user_agent()

The original User-Agent string you passed to Parse() or new().

=item languages()

Returns an arrayref of all languages recognised by placement and context in the
User-Agent string. Uses English names of languages encountered where
comprehended, or the ISO two-letter language code otherwise.

=item language()

Returns the language of the browser, interpreted as an English language name if
possible, as above. If more than one language are uncovered in the string,
chooses the one most repeated or the first encountered on any tie.

=item langs()

Like languages() above, except uses ISO standard language codes always.

=item lang()

Like language() above, but only containing the ISO language code.

=item detail()

The stuff inside any parentheses encountered. If the User-Agent string contains
more than one set of parentheses, this method will return the result of concatenating
all of the. This seems sub-optimal, but works for the moment.

=item useragents()

Returns an arrayref of all intelligible standard User Agent engine/version
pairs, and Opera's, to, if applicable. (Please note that this is despiute the
fact that Opera's is I<not> intelligible.)

=item properties()

Returns an arrayref of the stuff in details() broken up by /;\s+/

=item name()

The I<interpreted> name of the browser. This value may not actually appear
anywhere inside the string you handed it. For example, Internet Explorer identifies
itself in the User-Agent string as B<MSIE>,
but this method will return B<Internet Explorer>.

=item version()

Returns a hashref containing v, major, and minor, as explained below and keyed as such.

=item v()

The full version of the useragent (i.e. '5.6.0').

=item major()

The Major version number. For Safari 5.1 this method would return 5.

=item minor()

The Minor version number. For Opera 9.0.1, this method would return 0.

=item os()

The Operating System the browser is running on.

=item ostype()

The I<interpreted> type of the Operating System.
For instance, 'Windows' rather than 'Windows 9x 4.90'
For 'Android', C<os()> returns 'Android' and C<ostype()> returns 'Linux'.

=item osvers()

The I<interpreted> version of the Operating System. For instance, 'ME' rather than '9x 4.90'

Note: Windows NT versions below 5 will show up with ostype 'Windows NT' and
osvers as appropriate. Windows NT version 5 will show up as ostype
'Windows NT' and osvers '2000'. Windows NT 5.1+ will show up as osvers 'XP',
until it gets to 6, where it will become Vista, until 6.06 which will be reported
as 'Server 2008'.

=item osarc()

While rarely defined, some User-Agent strings happily announce some detail or
another about the Architecture they are running under. If this happens, it will
be reflected here. Linux ('i686') and Mac ('PPC') are more likely than Windows
to do this, strangely.

Apparently, Firefox 3 reports the wrong OS version on Vista,
so it's impossible to tell FF3 on Vista from FF3 on XP.

=back

=head1 SEE ALSO

I have done a review of all CPAN modules for parsing the User-Agent string.
If you have a specific need, it may be worth reading the review, to find
the best match:

http://blogs.perl.org/users/neilb/2011/10/cpan-modules-for-parsing-user-agent-strings.html

In brief, the following modules are worth considering.

L<Parse::HTTP::UserAgent> has best overall coverage of different browsers
and other user agents.

L<HTTP::DetectUserAgent> doesn't have as good coverage,
but handles modern browsers well, and is the
fastest module, so if you're processing large logfiles, this might
be the best choice.

L<HTTP::UserAgentString::Parser> is by far the fastest, and has good
coverage of modern browsers.

L<Woothee> is available for a number of programming languages, not just Perl.
It is faster than most of the modules, and has good coverage of the most
popular browsers, but not as good overall coverage.

L<HTTP::BrowserDetect> has poorest coverage of the modules listed here,
and doesn't do well at
recognising version numbers. It's the best module for detecting whether
a given agent is a robot/crawler though.


=head1 REPOSITORY

L<https://github.com/neilbowers/HTML-ParseBrowser>
 
=head1 AUTHOR

Dodger (aka Sean Cannon)

Recent changes by Neil Bowers.

=head1 COPYRIGHT AND LICENSE

The HTML::ParseBrowser module and code therein is
Copyright (c) 2001-2008 Sean Cannon

Changes in 1.01 and later are Copyright (C) 2012-2014, Neil Bowers.

All rights reserved. All rights reversed.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
