package Best;

use 5.006;

use warnings;
use strict;

our $VERSION = '0.11';

our %WHICH;

# !! is more idiomatic, but messes up vim's hilighter :(
use constant TRACE => ! ! $ENV{TRACE_BEST};
use constant DEBUG => ! ! ($ENV{DEBUG_BEST} || $ENV{TRACE_BEST});


=head1 NAME

Best - Fallbackable module loader

=head1 SYNOPSIS

    # Load the best available YAML module with default imports
    use Best qw/YAML::Syck YAML/;
    use Best [ qw/YAML::Syck YAML/ ];   # also works

    # Load a YAML module and import some symbols
    use Best [ [ qw/YAML::Syck YAML/ ], qw/DumpFile LoadFile/ ];

    # And fancier stuff...

    # Load a new enough YAML module
    use Best qw/YAML 0.58 YAML::Syck/;
    use Best [ qw/YAML 0.58 YAML::Syck/ ];
    use Best [ [ 'YAML' => { version => '0.58' },
                 'YAML::Syck' ] ];

    # Don't load too-new YAML module and import DumpFile
    use Best [ [ 'YAML' => { ok => sub { YAML->VERSION <= 0.23 } },
                 'YAML::Syck', ],
               qw/DumpFile/ ];

    # Use the best Carp module w/ different parameter lists
    use Best [ [ 'Carp::Clan' => { args => [] },
                 'Carp' ],
               qw/croak confess carp cluck/ ];

    # Choose alternate implementations
    use Best [ [ 'My::Memoize' => { if => sub { $] <= 5.006 } },
                 'Memoize' ],
               qw/memoize/ ];

    # Load a CGI module but import nothing
    use Best [ [ qw/CGI::Simple CGI/ ], [] ];      # akin to 'use CGI ()'

=head1 DESCRIPTION

Often there are several possible providers of some functionality your
program needs, but you don't know which is available at the run site. For
example, one of the modules may be implemented with XS, or not in the
core Perl distribution and thus not necessarily installed.

B<Best> attempts to load modules from a list, stopping at the first
successful load and failing only if no alternative was found.

=head1 FUNCTIONS

Most of the functionality B<Best> provides is on the C<use> line;
there is only one callable functions as such (see C<which> below)

If the arguments are either a simple list or a reference to a simple list,
the elements are taken to be module names and are loaded in order with
their default import function called. Any exported symbols are installed
in the caller package.


  use Best qw/A Simple List/;
  use Best [ qw/A Simple List/ ];

=head2 IMPORT LISTS

If the arguments are a listref with a listref as its first element,
this interior list is treated as the specification of modules to attempt
loading, in order; the rest of the arguments are treated as options to
pass on to the loaded module's import function.

  use Best [ [ qw/A Simple List/ ],
             qw/Argument list goes here/ ];
  use Best [ [ qw/A Simple List/ ],
             [ qw/Argument list goes here/ ] ];

To specify a null import (C<use Some::Module ()>), pass a zero-element
listref as the argument list. In the pathological case where you really
want to load a module and pass it C<[]> as an argument, specify C<[
[] ]> as the argument list to B<Best>.

  # use Module ();
  use Best [ [ 'Module' ], [] ];

  # use Module ( [] );
  use Best [ [ 'Module' ], [[]] ];

To customize the import list for a module, use the C<args> parameter
in a hash reference following the module's name.

  # use Carp::Clan;
  # use Carp qw/carp croak confess cluck/;
  use Best [ [ 'Carp::Clan' => { args => [] },
               'Carp' ],
             qw/carp croak confess cluck/ ];

=head2 MINIMUM VERSIONS

You can specify a minimum version for a module by following the module
name with something that looks like a number or by a hash reference
with a C<version> key.

  use Best [ [ YAML => '0.58',
               'YAML::Syck' ] ];

  use Best [ [ YAML => { version => '0.58' },
               'YAML::Syck' ] ];

=head2 PRE-VALIDATION

  use Best Module => { if => CODEREF };

You may prevent B<Best> from attempting to load a module by providing
a function as a parameter to C<if>. The module will only be loaded if
your function returns a true value.

=head2 POST-VALIDATION

  use Best Module => { ok => CODEREF };

You may prevent B<Best> from settling on a successfully loaded module
by providing a function as a parameter to C<ok>. B<Best> will follow
all of its normal rules to attempt to load your module but can be told
to continue retrying if your function returns false.

=head2 ARBITRARY CODE

A code reference may be substituted for module names. It will be
called instead of attempting to load a module. You may do anything you
wish in this code. It will be skipped if your code throws an exception
or returns false.

  use Best [ sub {
                 # Decline
                 return;
             },
             sub {
                 # Oops!
                 die 'Some error';
             },
             'Bad::Module',
             sub {
                 # Ok!
                 return 1;
             }, ];

=cut

# See if dereferencing it throws an error. This is meant to allow
# overloaded things to pretend to be array/hashes/coderefs. It also
# allows blessed array/hashes/coderefs to pass.
use overload ();

sub does_arrayref {
    my($thing) = @_;
    return if not defined $thing;
    
    # This does not share the void context hash dereferencing bug
    # (see C<does_hashref>) but I'm being consistent about the
    # style of returning a value.
    no warnings;
    return eval { return 1 + @{ $thing } };
}

sub does_hashref {
    my($thing) = @_;
    return if not defined $thing;
    
    # There is a bug in 5.8 where void context %{...} doesn't
    # evaluate. This was originally coded to check $@ but given the
    # bug, it's not reliable. The fix is to use the value of the
    # dereference.
    no warnings;
    return eval { return 1 + %{ $thing } };
}

sub does_coderef {
    my($thing) = @_;
    return overload::Method($thing, '&{}') ||
        overload::StrVal($thing) =~ /CODE\(0x[\da-f]+\)\z/;
}

sub looks_like_version {
    my($version) = @_;
    
    return defined $version &&
        $version =~ /\Av?\d+(?:\.[\d_]+)?\z/;
}

sub assert {
    # We'll pretend to be Carp::Assert here.
    return 1 if shift @_;

    require Carp;
    Carp::confess(@_ ? @_ : "Something's wrong!");
}

sub diag {
    # This output is safe to inline for Test::Harness.
    my($msg) = join '', @_;
    my ($package, $file, $line) = caller;
    $msg =~ s/^/# /gm;
    $msg =~ s/(?<!\n)\z/\n/;
    print "# $file on line $line\n$msg";
    return 1;
}

BEGIN {
    TRACE and do {
        require Data::Dumper;
        Data::Dumper->import('Dumper');
    };
}

sub import {
    my $caller = caller;
    shift @_; # "Best"
    return unless @_;

    # Unflatten the module list.
    #
    # @_ = [ module arrayref, args arrayref ];
    TRACE and diag(Dumper(@_));
    if (not does_arrayref($_[0])) {
        # use Best  qw/a b/;
        TRACE and diag('Totally flattened module list');
        @_ = [[@_]];
    }
    elsif (not does_arrayref($_[0][0])) {
        # use Best [qw/a b/];
        TRACE and diag('Semi-flattened module list');
        @_ = [@_];
    }
    else {
        TRACE and diag('Unflattened module list');
    }
    
    # Unflatten the import list.
    #
    TRACE and diag(Dumper(@{$_[0]}));
    DEBUG and assert(@{$_[0]} > 0);
    if (@{$_[0]} == 1) {
        # [ module-arrayref, undef ]
        $_[0][1] = undef;
    }
    elsif (@{$_[0]} == 2 && does_arrayref($_[0][1])) {
        # [ module-arrayref, args-arrayref ]
    }
    else {
        # [ module-arrayref, LIST ] -> [ module-arrayref, args-arrayref ]
        $_[0][1] = [ splice @{$_[0]}, 1 ];
    }
    
    TRACE and diag(Dumper(@_));
    DEBUG and assert(does_arrayref($_[0]));
    my @params = @{ shift @_ };
    DEBUG and assert(0 == @_);

    
    # Promote sugared and param-less modules to have specs:
    #      Module|Code
    #   or Module|Code => VERSION
    #   or Module|Code => HASHREF
    #
    #   becomes:
    #   [ Module|Code => HASHREF ]
    DEBUG and assert(does_arrayref($params[0]));
    my @modules = @{ shift @params };
    DEBUG and assert(1 == @params);
    for (my $i = 0; $i <= $#modules; ++$i) {
        my ($module, $param) = @modules[ $i, 1+$i ];
        
        if (looks_like_version($param)) {
            $param = { version => $param };
            splice @modules, 1+$i, 1;
        }
        elsif (does_hashref($param)) {
            splice @modules, 1+$i, 1;
        }
        else {
            $param = {};
        }

        DEBUG and assert(does_hashref($param));
        $modules[$i] = [ $module, $param ];
    }

    do { require Carp; Carp::croak('What modules shall I load?') }
        unless @modules;


    # Unpack the import arguments.
    my ($has_args, @args, $no_import);
    TRACE and diag(Dumper(@params));
    DEBUG and do {
        assert(1 == @params);
        assert(!defined $params[0] ||
                   does_arrayref($params[0]));
    };
    if (not does_arrayref($params[0])) {
        TRACE and diag('no import');
        DEBUG and assert(!defined, $params[0]);
        shift @params;
    }
    else {
        $has_args  = 1;
        @args      = @{ shift @params };
        # valid only if $has_args
        DEBUG and diag("has_args => $has_args, \@args => [@args]");
        $no_import = !@args ||
                @args == 1 && does_arrayref($args[0]) && @{ $args[0] } == 0; # use Mod ()
    }

    #::YY({mod=>$modules,has=>$has_args, arg=>\@args, noimport=>$no_import});

    # If we do not assume the loaded modules use Exporter, the only
    # alternative to eval-"" here is to enter a dummy package here and then
    # scan it and rexport symbols found in it. That is not necessarily
    # better, because the callee may be picky about its caller. We are in
    # compile time, and we do need to trust our caller anyway, so what the
    # hell, let's eval away.
    my @errors;
    my $first_module = $modules[0][0];
  MODULE:
    for my $thing_to_try (@modules) {
        my ($mod, $spec) = @$thing_to_try;
        if (my $precondition = $spec->{if}) {
            next MODULE unless $precondition->();
        }
        my $version = defined $spec->{version} ? $spec->{version} : '';
        my $loadargs = $no_import        ? '()'               :
                           $spec->{args} ? '@{$spec->{args}}' :
                           $has_args     ? '@args'            :
                                           '';

    # Load the module/code
        TRACE and diag("Trying $mod");
        my $retval;
        if (does_coderef($mod)) {
            $retval = $mod->();
            eval { die "$mod returned false" if not $retval };
        }
        else {
            my $src = qq{
                    package $caller;
                    use $mod $version $loadargs;
                };
            TRACE and diag($src);
            $retval = eval $src;
        }

        if ($@) {
            push @errors, $@;
            next MODULE;
        }
        elsif (my $postcondition = $spec->{ok}) {
            next MODULE unless $postcondition->();
        }
        
        TRACE and diag( "Loaded $mod\n" );
        $WHICH{$caller}{$first_module} =
            $WHICH{__latest}{$first_module} = $mod;
        return $retval;
    }
    require Carp;
    Carp::croak('No viable module found: ' . map { "$_\n" } @errors);
}

=over 4

=item which

In some cases--for example, class methods in OO modules--you want to know
which module B<Best> has successfully loaded. Call C<< Best->which >>
with the I<first> in your list of module alternatives; the return value
is a string containing the name of the loaded module.

=back

=cut

sub which {
    my($class, $mod) = @_;
    my $caller = caller;
    return $WHICH{$caller}{$mod}  if defined $WHICH{$caller}{$mod};
    return $WHICH{__latest}{$mod} if defined $WHICH{__latest}{$mod};
    return;
}

=head1 DEPLOYMENT ISSUES

If you want to use B<Best> because you aren't sure your target machine has
some modules installed, you may wonder what might warrant the assumption
that C<Best.pm> would be available, since it isn't a core module itself.

One solution is to use L<Inline::Module> to inline C<Best.pm> in your
source code. If you don't know this module, check it out -- after you
learn what it does, you may decide you don't need B<Best> at all! (If your
fallback list includes XS modules, though, you may need to stick with us.)

C<Best.pm> is pure Perl and a single module with a convenient license, so
you can also just drop it in your project's C<lib> directory.

=head1 SEE ALSO

=over 4

=item L<Module::Load>

=item L<UNIVERSAL::require>

=item L<Inline::Module>

=back

=head1 AUTHORS

Gaal Yahas, C<< <gaal at forum2.org> >>

Joshua ben Jore, C<< <jjore at cpan.org> >> has made some significant
contributions.

=head1 DIAGNOSTICS

=over

=item What modules shall I load?

C<Best> wasn't given a list of modules to load.

=item No viable module found: %s

None of the module alternatives loaded.

=item Something's wrong!

An assertion failed. This means that either there is a bug in the data
you fed to B<Best> or a bug in B<Best>.

=back

The code is scattered with assertions and debugging output that can be
enabled by putting a true value in the environment variables
C<TRACE_BEST> and C<DEBUG_BEST>.

Enabling C<TRACE_BEST> also enables the debugging code.

=head1 BUGS

Please report any bugs or feature requests to
C<bug-template-patch at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Best>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Best

You can also contact the maintainer at the address above or look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Best/>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Best/>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Best>

=item * Search CPAN

L<http://search.cpan.org/dist/Best/>

=item * Source repository

L<http://svn.openfoundry.org/perlbest/>

=back

=head1 COPYRIGHT (The "MIT" License)

Copyright 2006 Gaal Yahas.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

# These are my favorite debugging tools. Share and enjoy.
sub ::Y  { require YAML::Syck; YAML::Syck::Dump(@_) }
sub ::YY { require Carp; Carp::confess(::Y(@_)) }

"You'll never see me"; # End of Best
