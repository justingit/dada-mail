package HTML::Menu::Select;
use 5.004;
use strict;
use Carp 'carp';

our $VERSION = '1.01';

require Exporter;
our @ISA = qw( Exporter );

our @EXPORT_OK = qw(
 options menu popup_menu
 );

our %EXPORT_TAGS = ( all => \@EXPORT_OK );

our @KNOWN_KEYS = qw( 
  name value values default defaults labels attributes size multiple override );


sub popup_menu { &menu };

sub menu {
  my %arg  = (ref $_[0]) ? %{$_[0]} : @_;
  my $html = '';
  
  $arg{name} = '' if not exists $arg{name};
  
  $html = sprintf '<select name="%s"', _escapeHTML( $arg{name} );
  
  for my $key (keys %arg) {
    if (! grep {$key eq $_} @KNOWN_KEYS) {
      $html .= sprintf ' %s="%s"', $key, _escapeHTML( $arg{$key} );
    }
  }
  
  $html .= ">\n";
  $html .= options(%arg);
  $html .= "</select>\n";
  
  return $html;
}


sub options {
  my %arg  = (ref $_[0]) ? %{$_[0]} : @_;
  my $html  = '';
  
  # aliases
  for (qw/ value default /) {
    $arg{$_} = $arg{"${_}s"} 
      if exists $arg{"${_}s"};
    
    $arg{$_} = [$arg{$_}]
      if exists $arg{$_} && ! ref $arg{$_};
  }
  
  # don't support CGI.pm's 'override' argument
  if (exists $arg{override}) {
    carp "CGI.pm's 'override' argument is not supported by HTML::Menu::Select";
  }
  
  for my $option (@{ $arg{value} }) {
    $html .= '<option ';
    
    for my $default (@{ $arg{default} }) {
      if ($option eq $default) {
        $html .= 'selected="selected" ';
      }
    }
    
    for my $att (keys %{ $arg{attributes} }) {
      if ($att eq $option) {
        for (keys %{ $arg{attributes}{$att} }) {
          $html .= sprintf '%s="%s" ', 
                           $_, 
                           _escapeHTML( $arg{attributes}{$att}{$_} );
        }
      }
    }
    
    $html .= sprintf 'value="%s">', _escapeHTML( $option );
    
    if (exists $arg{labels} && exists $arg{labels}{$option}) {
      $html .= _escapeHTML( $arg{labels}{$option} );
    }
    else {
      $html .= _escapeHTML( $option );
    }
    
    $html .= '</option>';
    $html .= "\n";
  }
  
  return $html;
}


sub _escapeHTML {
  my ($escape) = (@_);
  
  return unless defined $escape;
  
  if (exists $::INC{'CGI.pm'}) {
    return CGI::escapeHTML( $escape );
  }
  elsif (exists $::INC{'CGI/Simple/Util.pm'}) {
    return CGI::Simple::Util::escapeHTML( $escape );
  }
  elsif (exists $::INC{'HTML/Entities.pm'}) {
    return HTML::Entities::encode_entities( $escape );
  }
  elsif (exists $::INC{'Apache/Util.pm'}) {
    return Apache::Util::escape_html( $escape );
  }
  
  # looks like nothing's already loaded to do it for us
  $escape =~ s/&/&amp;/gs;
  $escape =~ s/</&lt;/gs;
  $escape =~ s/>/&gt;/gs;
  $escape =~ s/"/&quot;/gs;
  
  return $escape;
}

1;

__END__

=head1 NAME

HTML::Menu::Select - Create HTML for select menus to simplify your templates.

=head1 SYNOPSIS

  use HTML::Menu::Select qw( menu options );
  
  my $html = menu(
    name   => 'myMenu',
    values => [ 'yes', 'no' ],
  );
  
  $tmpl->param( select_menu => $html );
  

=head1 DESCRIPTION

This modules creates HTML for form C<select> items.

Traditionally, if you wanted to dynamically generate a list of options 
in a C<select> menu, you would either have to use CGI's HTML 
generation routines, or use a complicated template such as this:

  <select name="day">
  <TMPL_LOOP day>
	  <option value="<TMPL_VAR value>" <TMPL_VAR selected>>
	    <TMPL_VAR label>
	  </option>
	</TMPL_LOOP>
  </select>

This module allows you to quickly prototype a page, allowing the CGI 
to completely generate the HTML, while allowing you at a later stage 
to easily change how much HTML it generates.

=head1 INSTALLATION

To install this module, run the following commands:

  perl Makefile.PL
  make
  make test
  make install

Alternatively, to install with Module::Build, you can use the following 
commands:

  perl Build.PL
  ./Build
  ./Build test
  ./Build install

=head1 METHODS

=head2 menu()

Use C<menu()> to generate the entire HTML for a select menu.

This allows you to have a very simple template tag, such as:

  <TMPL_VAR select_menu>

C<menu()> accepts the following parameters:

=over

=item name

This is used in the C<select> tag's C<name=""> attribute.

The name value will be run through escapeHTML(), see L<"HTML escaping">.

=item values

This is an array-ref of values used for each of the C<option> tags.

The values will be run through escapeHTML, see L<"HTML escaping">.

=item default

This selects which (if any) C<option> tag should have a 
C<selected="selected"> attribute.

=item labels

This is a hash-ref of values to provide different values for the 
user-visible label of each C<option> tag. Each key should match a 
value provided by the C<values> parameter.

If this parameter is not provided, or for any C<value> which doesn't 
have a matching key here, the user-visible label will be the 
C<option>'s C<value>.

  print menu(
    values => [1, 2],
    labels => {
      1 => 'one'},
      2 => 'two'},
    },
  );
  
  # will output
  
  <select name="">
  <option name="1">one</option>
  <option name="2">two</option>
  </select>

The labels will be run through escapeHTML, see L<"HTML escaping">.

=item attributes

This is a hash-ref of values to provide extra HTML attributes for the 
C<option> tags. Like the C<labels> parameter, the keys should match 
a value provided by the c<values> parameter.

Each value of this hash-ref should be a hash-ref representing the name 
and value of a HTML attribute.

  print menu(
    values     => ['one', 'two'],
    attributes => {
      one => {onSubmit => 'do(this);'},
      two => {style => 'color: #000;'},
    },
  );
  
  # will output
  
  <select name="">
  <option onSubmit="do(this);" name="one">one</option>
  <option style="color: #000;" name="two">two</option>
  </select>

All attribute values (but not the attribute name) will be run through 
escapeHTML, see L<"HTML escaping">.

=item value

An alias for C<value>.

=item defaults

An alias for C<default>.

=back

All parameters are optional, though it doesn't make much sense to not 
provide anything for C<values>.

Any unrecognised parameters will be used to provide extra HTML 
attributes for the C<select> tag. For example:

  print menu(
    id       => 'myID',
    values   => ['one'],
    onChange => 'do(this);',
  );
  
  # will output
  
  <select name="" id="myID" onChange="do(this);">
  <option name="one">one</option>
  </select>

All attribute values (but not the attribute name) will be run through 
escapeHTML, see L<"HTML escaping">.

=head2 options()

Use C<options()> to generate the HTML for only the C<option> tags, 
allowing you to keep the outer C<select> tag in the template, so that, 
for example, a designer can easily make changes to the CSS or 
JavaScript handlers.

You would have something like the following in your template:

  <select name="day">
    <TMPL_VAR menu_options>
  </select>

C<options()> accepts the same parameters as L<"menu()">, but the C<name> 
parameter is ignored.

=head2 popup_menu()

C<popup_menu()> is an alias for L<"menu()"> for those familiar with 
CGI.

=head1 HTML escaping

If any of the following modules are already loaded into memory, their own 
escapeHTML (or equivalent) method will be used

=over

=item CGI

=item CGI::Simple

=item HTML::Entities

=item Apache::Util

=back

Otherwise the following characters will be escaped

  & < > "

=head1 CGI.pm COMPATABILITY

=over

=item Arguments may be passed as a hash-reference, rather than a hash.

This allows compile time checking, rather than runtime.

  popup_menu( name => $name );
  
  # OR
  popup_menu( {name => $name} );

=back

Arguments to the L<"menu()">, L<"options()"> and L<"popup_menu()"> functions 
are similar to CGI.pm's, excepting the following differences.

=over

=item Named arguments should not have a leading dash

  popup_menu( name => $name );
  
  # NOT
  # popup_menu( -name => $name );

=item Positional arguments are not supported

  popup_menu( name => $name, labels => \@labels );
  
  # NOT
  # popup_menu( $name, \@labels );

=item Attribute names not lowercased

An argument to CGI.pm's popup_menu such as C<-onChange => 'check()'> will 
output the HTML C<onchange="check()">.

This module will retain the case, outputting C<onChange="check()">.

=item The C<optgroup> function is not yet supported

=back

=head1 SUPPORT / BUGS

Please log bugs, feature requests and patch submissions at 
L<http://sourceforge.net/projects/html-menu>.

Support mailing list: html-menu-users@lists.sourceforge.net

=head1 SEE ALSO

HTML::Menu::DateTime, HTML::Template, Template, Template::Magic, 
DateTime::Locale.

=head1 AUTHOR

Carl Franks <cpan@fireartist.com>

=head1 CREDITS

  Ron Savage

=head1 COPYRIGHT AND LICENSE

Copyright 2005, Carl Franks.  All rights reserved.  

This library is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself.

Licenses are in the files "Artistic" and "Copying" in this distribution.

=cut
