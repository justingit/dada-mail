package HTML::Template::MyExpr;

use strict;
use vars qw($VERSION);

$VERSION = '0.07';

use HTML::Template 2.4;
use Carp qw(croak confess carp);
use Parse::RecDescent;

use base 'HTML::Template';

use vars qw($GRAMMAR);
$GRAMMAR = <<'END';
expression : paren /^$/  { $return = $item[1] } 

paren         : '(' binary_op ')'     { $item[2] }
              | '(' subexpression ')' { $item[2] }
              | subexpression         { $item[1] }
              | '(' paren ')'         { $item[2] }

subexpression : function_call
              | var
              | literal
              | <error>

binary_op     : paren (op paren { [ $item[2], $item[1] ] })(s)
              { $return = [ 'SUB_EXPR', $item[1], map { @$_ } @{$item[2]} ] }

op            : />=?|<=?|!=|==/      { [ 'BIN_OP',  $item[1] ] }
              | /le|ge|eq|ne|lt|gt/  { [ 'BIN_OP',  $item[1] ] }
              | /\|\||or|&&|and/     { [ 'BIN_OP',  $item[1] ] }
              | /[-+*\/%]/           { [ 'BIN_OP',  $item[1] ] }

function_call : function_name '(' args ')'  
                { [ 'FUNCTION_CALL', $item[1], $item[3] ] }
              | function_name ...'(' paren
                { [ 'FUNCTION_CALL', $item[1], [ $item[3] ] ] }
              | function_name '(' ')'
                { [ 'FUNCTION_CALL', $item[1] ] }

function_name : /[A-Za-z_][A-Za-z0-9_]*/

args          : <leftop: paren ',' paren>

var           : /[A-Za-z_][A-Za-z0-9_.]*/ { [ 'VAR', $item[1] ] }
	
literal       : /-?\d*\.\d+/             { [ 'LITERAL', $item[1] ] }
              | /-?\d+/                  { [ 'LITERAL', $item[1] ] }
              | <perl_quotelike>         { [ 'LITERAL', $item[1][2] ] }

END


# create global parser
use vars qw($PARSER);
$PARSER = Parse::RecDescent->new($GRAMMAR);

# initialize preset function table
use vars qw(%FUNC);
%FUNC = 
  (
   'sprintf' => sub { sprintf(shift, @_); },
   'substr'  => sub { 
     return substr($_[0], $_[1]) if @_ == 2; 
     return substr($_[0], $_[1], $_[2]);
   },
   'lc'      => sub { lc($_[0]); },
   'lcfirst' => sub { lcfirst($_[0]); },
   'uc'      => sub { uc($_[0]); },
   'ucfirst' => sub { ucfirst($_[0]); },
   'length'  => sub { length($_[0]); },
   'defined' => sub { defined($_[0]); },
   'abs'     => sub { abs($_[0]); },
   'atan2'   => sub { atan2($_[0], $_[1]); },
   'cos'     => sub { cos($_[0]); },
   'exp'     => sub { exp($_[0]); },
   'hex'     => sub { hex($_[0]); },
   'int'     => sub { int($_[0]); },
   'log'     => sub { log($_[0]); },
   'oct'     => sub { oct($_[0]); },
   'rand'    => sub { rand($_[0]); },
   'sin'     => sub { sin($_[0]); },
   'sqrt'    => sub { sqrt($_[0]); },
   'srand'   => sub { srand($_[0]); },
  );

sub new { 
  my $pkg = shift;
  my $self;

  # check hashworthyness
  croak("HTML::Template::MyExpr->new() called with odd number of option parameters - should be of the form option => value")
    if (@_ % 2);
  my %options = @_;

  # check for unsupported options file_cache and shared_cache
  croak("HTML::Template::MyExpr->new() : sorry, this module won't work with file_cache or shared_cache modes.  This will hopefully be fixed in an upcoming version.")
    if ($options{file_cache} or $options{shared_cache});

  # push on our filter, one way or another.  Why did I allow so many
  # different ways to say the same thing?  Was I smoking crack?
  my @expr;
  if (exists $options{filter}) {
    # CODE => ARRAY
    $options{filter} = [ { 'sub'    => $options{filter},
                           'format' => 'scalar'         } ]
      if ref($options{filter}) eq 'CODE';

    # HASH => ARRAY
    $options{filter} = [ $options{filter} ]
      if ref($options{filter}) eq 'HASH';

    # push onto ARRAY
    if (ref($options{filter}) eq 'ARRAY') {
      push(@{$options{filter}}, { 'sub'    => sub { _expr_filter(\@expr, @_); },
                                  'format' => 'scalar' });
    } else {
      # unrecognized
      croak("HTML::Template::MyExpr->new() : bad format for filter argument.  Please check the HTML::Template docs for the allowed forms.");      
    }
  } else {
    # new filter
    $options{filter} = [ { 'sub'    => sub { _expr_filter(\@expr, @_) },
                           'format' => 'scalar'                    
                         } ];
  }  

  # force global_vars on
  $options{global_vars} = 1;

  # create an HTML::Template object, catch the results to keep error
  # message line-numbers helpful.
  eval {
    $self = $pkg->SUPER::new(%options, 
			     expr => \@expr, 
			     expr_func => $options{functions} || {});
  };
  croak("HTML::Template::MyExpr->new() : Error creating HTML::Template object : $@") if $@;

  return $self;
}

sub _expr_filter {
  my $expr = shift;
  my $text = shift;

  # find expressions and create parse trees
  my ($ref, $tree, $before_expr, $expr_text, $after_expr, $vars, $which, $out);
  $$text =~ s/
               <(?:!--\s*)?
               [Tt][Mm][Pp][Ll]_
               ([Ii][Ff]|[Uu][Nn][Ll][Ee][Ss][Ss]|[Vv][Aa][Rr]) # $1 => which tag
               (\s+[^<]+)?                                      # $2 => before expr
               \s+[Ee][Xx][Pp][Rr]=
               "([^"]*)"                                        # $3 => the actual expr
               (\s+[^>-]+)?                                     # $4 => after expr
               \s*(?:--)?>
             /
               $which       = $1;
               $before_expr = $2 || '';
               $expr_text   = $3;  
               $after_expr  = $4 || '';

               # add enclosing parens to keep grammar simple
               $expr_text = "($expr_text)";

               # parse the expression
               eval {
                 $tree = $PARSER->expression($expr_text);
               };
               croak("HTML::Template::MyExpr : Unable to parse expression: $expr_text")
                  if $@ or not $tree;

               # stub out variables needed by the expression
               $out = "<tmpl_if __expr_unused__>";
               foreach my $var (_expr_vars($tree)) {
                 next unless defined $var;
                 $out .= "<tmpl_var name=\"$var\">";
               }

               # save parse tree for later
               push(@$expr, $tree);
               
               # add the expression placeholder and replace
               $out . "<\/tmpl_if><tmpl_$which ${before_expr}__expr_" . $#{$expr} . "__$after_expr>";
             /xeg;
  # stupid emacs - /

  return;
}

# find all variables in a parse tree
sub _expr_vars {
    my $tree = shift;
    my %vars;

    # hunt for VAR nodes in the tree
    my @stack = @$tree;
    while (@stack) {
        my $node = shift @stack;
        if (ref $node and ref $node eq 'ARRAY') {
            if ($node->[0] eq 'VAR') {
                $vars{$node->[1]} = 1;
            } else {
                push @stack, @$node;
            }
        }
    }
    return keys %vars;
}

# allow loops to stay as HTML::Template objects, we don't need to
# override output for them
sub _new_from_loop {
    my ($pkg, @args) = @_;
    return HTML::Template->_new_from_loop(@args);
}

sub output {
  my $self = shift;
  my $parse_stack = $self->{parse_stack};
  my $options = $self->{options};
  my ($expr, $expr_func);

  # pull expr and expr_func out of the parse_stack for cache mode.
  if ($options->{cache}) {
    $expr      = pop @$parse_stack;
    $expr_func = pop @$parse_stack;
  } else {
    $expr      = $options->{expr};
    $expr_func = $options->{expr_func};
  }

  # setup expression evaluators
  my %param;
  for (my $x = 0; $x < @$expr; $x++) {
    my $node = $expr->[$x];
    $param{"__expr_" . $x . "__"} = sub { _expr_evaluate($node, @_) };
  }
  $self->param(\%param);

  # setup %FUNC 
  local %FUNC = (%FUNC, %$expr_func);

  my $result = $self->SUPER::output(@_);

  # restore cached values to their hideout in the parse_stack
  if ($options->{cache}) {
    push @$parse_stack, $expr_func;
    push @$parse_stack, $expr;
  }
  
  return $result;
}

sub _expr_evaluate {
  my ($tree, $template) = @_;
  my ($op, $lhs, $rhs, $node, $type, @stack);

  my @nodes = $tree;
  while (@nodes) {
      my $node = shift @nodes;
      my $type = $node->[0];

      if ($type eq 'LITERAL') {
          push @stack, $node->[1];
          next;
      }

      if ($type eq 'VAR') {
          push @stack, $template->param($node->[1]);
          next;
      } 

      if ($type eq 'SUB_EXPR') {
          unshift @nodes, @{$node}[1..$#{$node}];
          next;
      }

      if ($type eq 'BIN_OP') {
          $op  = $node->[1];
          $rhs = pop(@stack);
          $lhs = pop(@stack);

          # do the op
          if ($op eq '==') {push @stack, $lhs == $rhs; next; }
          if ($op eq 'eq') {push @stack, $lhs eq $rhs; next; }
          if ($op eq '>')  {push @stack, $lhs >  $rhs; next; }
          if ($op eq '<')  {push @stack, $lhs <  $rhs; next; }

          if ($op eq '!=') {push @stack, $lhs != $rhs; next; }
          if ($op eq 'ne') {push @stack, $lhs ne $rhs; next; }
          if ($op eq '>=') {push @stack, $lhs >= $rhs; next; }
          if ($op eq '<=') {push @stack, $lhs <= $rhs; next; }
          
          if ($op eq '+')  {push @stack, $lhs + $rhs;  next; }
          if ($op eq '-')  {push @stack, $lhs - $rhs;  next; }
          if ($op eq '/')  {push @stack, $lhs / $rhs;  next; }
          if ($op eq '*')  {push @stack, $lhs * $rhs;  next; }
          if ($op eq '%')  {push @stack, $lhs % $rhs;  next; }

          if ($op eq 'le') {push @stack, $lhs le $rhs; next; }
          if ($op eq 'ge') {push @stack, $lhs ge $rhs; next; }
          if ($op eq 'lt') {push @stack, $lhs lt $rhs; next; }
          if ($op eq 'gt') {push @stack, $lhs gt $rhs; next; }

          # short circuit or
          if ($op eq 'or' or $op eq '||') {
              if ($lhs) {
                  push @stack, 1;
                  next;
              }
              if ($rhs) {
                  push @stack, 1;
                  next;
              }
              push @stack, 0;
              next;
          } 

          # short circuit and
          if ($op eq '&&' or $op eq 'and') {
              unless ($lhs) {
                  push @stack, 0;
                  next;
              }
              unless ($rhs) {
                  push @stack, 0;
                  next;
              }
              push @stack, 1;
              next;
          }
    
          confess("HTML::Template::MyExpr : unknown op: $op");
      } 

      if ($type eq 'FUNCTION_CALL') {
          my $name = $node->[1];
          my $args = $node->[2];
          croak("HTML::Template::MyExpr : found unknown subroutine call ".
                ": $name.\n")
            unless exists($FUNC{$name});
          if (defined $args) {
              push @stack, 
                scalar 
                  $FUNC{$name}->(map { _expr_evaluate($_, $template) } @$args);
          } else {
              push @stack, scalar $FUNC{$name}->();
          }
          next;
      }

      confess("HTML::Template::MyExpr : unrecognized node in tree: $node");
  }

  unless (@stack == 1) {
      confess("HTML::Template::MyExpr : stack overflow!  ".
              "Please report this bug to the maintainer.");
  }

  return $stack[0];
}

sub register_function {
  my($class, $name, $sub) = @_;

  croak("HTML::Template::MyExpr : args 3 of register_function must be subroutine reference\n")
    unless ref($sub) eq 'CODE';

  $FUNC{$name} = $sub;
}


# Make caching work right by hiding our vars in the parse_stack
# between cache store and load.  This is such a hack.
sub _commit_to_cache {
  my $self = shift;
  my $parse_stack = $self->{parse_stack};

  push @$parse_stack, $self->{options}{expr_func};
  push @$parse_stack, $self->{options}{expr};

  my $result = HTML::Template::_commit_to_cache($self, @_);
}

1;
__END__
=pod

=head1 NAME

HTML::Template::MyExpr - HTML::Template extension adding expression support

=head1 SYNOPSIS

  use HTML::Template::MyExpr;

  my $template = HTML::Template::MyExpr->new(filename => 'foo.tmpl');
  $template->param(banana_count => 10);
  print $template->output();

=head1 DESCRIPTION

This module provides an extension to HTML::Template which allows
expressions in the template syntax.  This is purely an addition - all
the normal HTML::Template options, syntax and behaviors will still
work.  See L<HTML::Template> for details.

Expression support includes comparisons, math operations, string
operations and a mechanism to allow you add your own functions at
runtime.  The basic syntax is:

   <TMPL_IF EXPR="banana_count > 10">
     I've got a lot of bananas.
   </TMPL_IF>

This will output "I've got a lot of bananas" if you call:

   $template->param(banana_count => 100);

In your script.  <TMPL_VAR>s also work with expressions:

   I'd like to have <TMPL_VAR EXPR="banana_count * 2"> bananas.

This will output "I'd like to have 200 bananas." with the same param()
call as above.

=head1 MOTIVATION

Some of you may wonder if I've been replaced by a pod person.  Just
for the record, I still think this sort of thing should be avoided.
However, I realize that there are some situations where allowing the
template author some programatic leeway can be invaluable.

If you don't like it, don't use this module.  Keep using plain ol'
HTML::Template - I know I will!  However, if you find yourself needing
a little programming in your template, for whatever reason, then this
module may just save you from HTML::Mason.

=head1 BASIC SYNTAX

Variables are unquoted alphanumeric strings with the same restrictions
as variable names in HTML::Template.  Their values are set through
param(), just like normal HTML::Template variables.  For example,
these two lines are equivalent:

   <TMPL_VAR EXPR="foo">
  
   <TMPL_VAR NAME="foo">

Numbers are unquoted strings of numbers and may have a single "." to
indicate a floating point number.  For example:

   <TMPL_VAR EXPR="10 + 20.5">

String constants must be enclosed in quotes, single or double.  For example:

   <TMPL_VAR EXPR="sprintf('%d', foo)">

You can string together operators to produce complex booleans:

  <TMPL_IF EXPR="(foo || bar || baz || (bif && bing) || (bananas > 10))">
      I'm in a complex situation.
  </TMPL_IF>

The parser is pretty simple, so you may need to use parenthesis to get
the desired precedence.

=head1 COMPARISON

Here's a list of supported comparison operators:

=over 4

=item * Numeric Comparisons

=over 4

=item * E<lt>

=item * E<gt>

=item * ==

=item * !=

=item * E<gt>=

=item * E<lt>=

=item * E<lt>=E<gt>

=back 4

=item * String Comparisons

=over 4

=item * gt

=item * lt

=item * eq

=item * ne

=item * ge

=item * le

=item * cmp

=back 4

=back 4

=head1 MATHEMATICS

The basic operators are supported:

=over 4

=item * +

=item * -

=item * *

=item * /

=item * %

=back 4

There are also some mathy functions.  See the FUNCTIONS section below.

=head1 LOGIC

Boolean logic is available:

=over 4

=item * && (synonym: and)

=item * || (synonym: or)

=back 4

=head1 FUNCTIONS

The following functions are available to be used in expressions.  See
perldoc perlfunc for details.

=over 4

=item * sprintf

=item * substr (2 and 3 arg versions only)

=item * lc

=item * lcfirst

=item * uc

=item * ucfirst

=item * length

=item * defined

=item * abs

=item * atan2

=item * cos

=item * exp

=item * hex

=item * int

=item * log

=item * oct

=item * rand

=item * sin

=item * sqrt

=item * srand

=back 4

All functions must be called using full parenthesis.  For example,
this is a syntax error:

   <TMPL_IF expr="defined foo">

But this is good:

   <TMPL_IF expr="defined(foo)">

=head1 DEFINING NEW FUNCTIONS

To define a new function, pass a C<functions> option to new:

  $t = HTML::Template::MyExpr->new(filename => 'foo.tmpl',
                                 functions => 
                                   { func_name => \&func_handler });

Or, you can use C<register_function> class method to register
the function globally:

  HTML::Template::MyExpr->register_function(func_name => \&func_handler);

You provide a subroutine reference that will be called during output.
It will recieve as arguments the parameters specified in the template.
For example, here's a function that checks if a directory exists:

  sub directory_exists {
    my $dir_name = shift;
    return 1 if -d $dir_name;
    return 0;
  }

If you call HTML::Template::MyExpr->new() with a C<functions> arg:

  $t = HTML::Template::MyExpr->new(filename => 'foo.tmpl',
                                 functions => {
                                    directory_exists => \&directory_exists
                                 });

Then you can use it in your template:

  <tmpl_if expr="directory_exists('/home/sam')">

This can be abused in ways that make my teeth hurt.

=head1 MOD_PERL TIP

C<register_function> class method can be called in mod_perl's
startup.pl to define widely used common functions to
HTML::Template::MyExpr. Add something like this to your startup.pl:

  use HTML::Template::MyExpr;

  HTML::Template::MyExpr->register_function(foozicate => sub { ... });
  HTML::Template::MyExpr->register_function(barify    => sub { ... });
  HTML::Template::MyExpr->register_function(baznate   => sub { ... });

You might also want to pre-compile some commonly used templates and
cache them.  See L<HTML::Template>'s FAQ for instructions.

=head1 CAVEATS

Currently the module forces the HTML::Template global_vars option to
be set.  This will hopefully go away in a future version, so if you
need global_vars in your templates then you should set it explicitely.

The module won't work with HTML::Template's file_cache or shared_cache
modes, but normal memory caching should work.  I hope to address this
is a future version.

The module is inefficient, both in parsing and evaluation.  I'll be
working on this for future versions and patches are always welcome.

=head1 BUGS

I am aware of no bugs - if you find one, join the mailing list and
tell us about it.  You can join the HTML::Template mailing-list by
visiting:

  http://lists.sourceforge.net/lists/listinfo/html-template-users

Of course, you can still email me directly (sam@tregar.com) with bugs,
but I reserve the right to forward bug reports to the mailing list.

When submitting bug reports, be sure to include full details,
including the VERSION of the module, a test script and a test template
demonstrating the problem!

=head1 CREDITS

The following people have generously submitted bug reports, patches
and ideas:

   Peter Leonard
   Tatsuhiko Miyagawa
   Don Brodale

Thanks!

=head1 AUTHOR

Sam Tregar <sam@tregar.com>

=head1 LICENSE

HTML::Template::MyExpr : HTML::Template extension adding expression support

Copyright (C) 2001 Sam Tregar (sam@tregar.com)

This module is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version,
or

b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA

