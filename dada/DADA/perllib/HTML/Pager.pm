package HTML::Pager;

=head1 NAME

HTML::Pager - Perl module to handle CGI HTML paging of arbitary data

=head1 SYNOPSIS

  use HTML::Pager;
  use CGI;

  # get CGI query object
  my $query = CGI->new();

  # create a callback subroutine to generate the data to be paged
  my $get_data_sub = sub {
     my ($offset, $rows) = @_;
     my @return_array;

     for (my $x = 0; $x < $rows; $x++) {
        push(@return_array, [ time() ]);
     }
     return \@return_array;
  }

  # create a Pager object 
  my $pager = HTML::Pager->new(
                               # required parameters
                               query => $query,
                               get_data_callback => $get_data_sub,
                               rows => 100,
                               page_size => 10,

                               # some optional parameters
                               persist_vars => ['myformvar1', 
                                                'myformvar2', 
                                                'myformvar3'],
                               cell_space_color => '#000000',    
                               cell_background_color => '#ffffff',
                               nav_background_color => '#dddddd',
                               javascript_presubmit => 'last_minute_javascript()',
                               debug => 1,
                              );




  # make it go - send the results to the browser.
  print $pager->output;
  

=head1 DESCRIPTION

This module handles the paging of data coming from an arbitrary source
and being displayed using HTML::Template and CGI.pm.  It provides
an interface to pages of data similar to many well-known sites, like
altavista.digital.com or www.google.com.

This module uses HTML::Template to do all its HTML generation.  While
it is possible to use this module without directly using
HTML::Template, it's not very useful.  Modification of the
look-and-feel as well as the functionality of the resulting HTML
should all be done through HTML::Template objects.  Take a look at
L<HTML::Template> for more info.

=cut

use strict;
use integer;
use HTML::Template;

$HTML::Pager::VERSION = '0.03';

=head1 METHODS

=head2 C<new()>

The new() method creates a new Pager object and prepares the data for
C<output()>.  

C<new()> requires several options, see above for syntax:

=over 4

=item *

query - this is the CGI.pm query object for this run.  Pager will
remove it's state-maintaining parameters from the query.  They all
begin with PAGER_, so just be careful not to use that prefix.

=item *

rows - this is the total number of rows in your dataset.  This is
needed to provide the next-button, prev-button and page-jump
functionality.

=item *

page_size - the number of rows to display at one time.

=item *

get_data_callback - this is a callback that you provide to get the
pages of data.  It is passed two arguements - the offset and the
number of rows in the page.  You return an array ref containing array
refs of row data.  For you DBI-heads, this is very similar to
selectall_arrayref() - so similar that for very simple cases you can
just pass the result through.  Example - this is a sub that returns
data from an in-memory array of hash refs.

  my @data = ( 
               { name => sam, age => 10 },
               { name => saa, age => 11 },
               { name => sad, age => 12 },
               { name => sac, age => 13 },
               { name => sab, age => 14 },
               # ...
             );

  my $get_data_sub = sub {
     my ($offset, $rows) = @_;
     my @return_array;

     for (my $x = 0; $x < $rows; $x++) {
        push(@return_array, [ $data[$offset + $x]{name}, 
                              $data[$offset + $x]{age} 
                            ]
            );
     }
     return \@return_array;
  }
          
  my $pager = HTML::Pager->new(query => $query,
                               get_data_callback => $get_data_sub,
                               rows => 100,
                               page_size => 10
                              );

You can also specify arguements to be passed to your callback function.  To do this, call new like:

  HTML::Pager->new(query => $query,
                   get_data_callback => [$get_data_sub, $arg, $arg],
                   rows => 100,
                   page_size => 10
                  );

If you want to use named, rather than numeric TMPL_VARs in your Pager
template you can return a ref to an array of hashes rather than
arrays.  This array of hashes will be passed directly to
HTML::Template to fill in the loop data for your paging area.

=back 4


C<new()> supports several optional arguements:

=over 4

=item *

debug - if set to 1, debugging information is warn()'d during the
program run.  Defaults to 0.

=item *

template - this is an HTML::Template object to use instead of the
auto-generated HTML::Template used in Pager output.  It must define
the following TMPL_LOOPs and TMPL_VARs.  Here's what the default
template looks like, to give you an idea of how to change it to suite
your purposes:

  <TMPL_VAR NAME="PAGER_JAVASCRIPT">
  <FORM>
  <TABLE BORDER=0 BGCOLOR=#000000 WIDTH=100%>
  <TR><TD><TABLE BORDER=0 WIDTH=100%>
  <TMPL_LOOP NAME="PAGER_DATA_LIST">
    <TR>
      <TD BGCOLOR=#ffffff><TMPL_VAR NAME="PAGER_DATA_COL_0"></TD>
      <TD BGCOLOR=#ffffff><TMPL_VAR NAME="PAGER_DATA_COL_1"></TD>
      <TD BGCOLOR=#ffffff><TMPL_VAR NAME="PAGER_DATA_COL_2"></TD>
      <!--- depends on number of rows in data - so should your replacement! -->
    </TR>
  </TMPL_LOOP>
  <TR><TD BGCOLOR=#DDDDDD COLSPAN=3 ALIGN=CENTER>
    <TMPL_VAR NAME="PAGER_PREV">
    <TMPL_VAR NAME="PAGER_JUMP">
    <TMPL_VAR NAME="PAGER_NEXT">
  </TD></TR>
  </TABLE>
  </TABLE>
  <TMPL_VAR NAME="PAGER_HIDDEN">
  </FORM>

Make sure you include all the TMPL_LOOPs and TMPL_VARs included above.
If you get HTML::Template errors about trying to set bad param
'PAGER_BLAH', that probably means you didn't put the 'PAGER_BLAH'
variable in your template.  You can put extra state-maintaining
<INPUT> fields in the paging form - in fact, I think that this is
probably required for most real-world uses.

Optionally you can use named parameters inside PAGER_DATA_LIST, and
return an array of hashes to fill them in from get_data_callback.  If
you did that your template might look like:

  ...
  <TMPL_LOOP NAME="PAGER_DATA_LIST">
    <TR>
      <TD BGCOLOR=#ffffff><TMPL_VAR NAME="NUMBER"></TD>
      <TD BGCOLOR=#ffffff><TMPL_VAR NAME="FIRST_NAME"></TD>
      <TD BGCOLOR=#ffffff><TMPL_VAR NAME="LAST_NAME"></TD>
    </TR>
  </TMPL_LOOP>
  ...

=item * 

persist_vars - Pass a ref to an array of the names of the CGI form
parameters you want to store into this fuction, and they will be
included in the hidden form data of the pager form.

This method allows you to have hidden form variables which persist
from page to page.  This is useful when connecting your pager to some 
other function (such as a search form) which needs to keep some data 
around for later use.

The old $pager->persist_vars() syntax still works but is deprecated.

=item *

column_names - should be set to an array ref containing the names of
the columns - this will be used to create column headers.  Without
this arguement, the columns will have no headers.  This option is only
useful in very simple cases where all the data is actually in use as
columns.  Example:

   my $pager = HTML::Pager->new( column_names => [ 'one', 'two' ]);


=item *

cell_space_color - this specifies the color of the lines separating
the cells.  If the default template is mostly OK, except for the color
scheme, this will provide a middle ground between the necessity of
creating your own Pager template and suffering with bad colors.
Example:

   my $pager = HTML::Pager->new( cell_space_color => '#222244' );


=item *

cell_background_color - this specifies the background color of each
data cell.  If the default template is mostly OK, except for the color
scheme, this will provide a middle ground between the necessity of
creating your own Pager template and suffering with bad colors.
Example:

   my $pager = HTML::Pager->new( cell_background_color => '#000000' );



=item *

nav_background_color - this specifies the background color of the
bottom navigation bar.  If the default template is mostly OK, except
for the color scheme, this will provide a middle ground between the
necessity of creating your own Pager template and suffering with bad
colors.  Example:

   my $pager = HTML::Pager->new( nav_background_color => '#222244' );


=item *

javascript_presubmit - this optional parameter allows you to specify a
Javascript function which will be called when a user clicks on one of
the Pager navigation buttons, prior to submitting the form.  Only if
this function returns 'true' will the form be submitted.

The Pager navigation calls its 'PAGER_set_offset_and_submit()'
javascript function when a user clicks the "Next", "Previous" or other
page buttons.  This normally precludes calling your own javascript
submit functions to perform some task.

Through this hook, you can perform client-side functions, such as form
validation, which can modify the form or actually prevent the user
from going to the next page.  This is particularly useful for enabling
some kind of work-flow involving form validation.

 Constructor Example:

    my $pager = HTML::Pager->new( 
                   javascript_presubmit => 'last_minute_javascript()' 
                );


 HTML Example:

    <script language=Javascript>
        function last_minute_javascript() {
            return confirm("Are you sure you want to leave this page?");
        }
    </script>

=back 4

=cut
  

sub new {
  my $pkg = shift;
  my %hash;
  for (my $x = 0; $x <= $#_; $x += 2) {
    $hash{lc($_[$x])} = $_[($x + 1)];
  }
  my $self = bless(\%hash, $pkg);
  
  # check required parameters
  die("Called $pkg->new() called without a query parameter.")
    unless exists($self->{query});
  die ("Called $pkg->new() called with a query parameter that does not appear to be a valid CGI object.")
    unless (ref($self->{query}) eq 'CGI');

  die ("Called $pkg->new() called with a persist_vars parameter that does not appear to be an array ref.")
    if (exists($self->{persist_vars})
        and ref($self->{persist_vars}) ne 'ARRAY');
  
  die("Called $pkg->new() called without a rows parameter.") 
    unless exists($self->{rows});
  die("Called $pkg->new() called with and invalid rows parameter.")
    if ($self->{rows} < 0);

  die("Called $pkg->new() called without a page_size parameter.")
    unless exists($self->{page_size});
  die("Called $pkg->new() called with and invalid page_size parameter.")
    if ($self->{page_size} <= 0);

  die("Called $pkg->new() called without a get_data_callback parameter.")
    unless exists($self->{get_data_callback});
  die ("Called $pkg->new() with a get_data_callback parameter that does not appear to be a valid subroutine reference.")
    if (!ref($self->{get_data_callback}) || !((ref($self->{get_data_callback}) ne 'CODE') || (ref($self->{get_data_callback}) ne 'ARRAY')));

  # set default parameters
  $self->{debug} = 0 unless exists($self->{debug});
  $self->{column_names} = undef unless exists($self->{column_names});
  $self->{persist_vars} = [] unless exists($self->{persist_vars});   
  $self->{javascript_presubmit} = '' unless exists($self->{javascript_presubmit});   

  # Default colors
  $self->{cell_space_color} = '#000000' unless(exists($self->{cell_space_color}));
  $self->{cell_background_color} = '#ffffff' unless(exists($self->{cell_background_color}));
  $self->{nav_background_color} = '#DDDDDD' unless(exists($self->{nav_background_color}));

  
  # pull out the query data
  $self->_parse_query;
  
  # fills in the paging template, generating one if necessary.
  $self->_fill_template;
  
  return $self;
}


# parses out the query data needed to maintain state - just
# PAGER_offset for now.
sub _parse_query {
  my $self = shift;
  my $query = $self->{query};
  
  if (defined($query->param('PAGER_offset'))) {
    $self->{offset} = $query->param('PAGER_offset');
  } else {
    $self->{offset} = 0;
  }
  
  ($self->{debug}) && (warn("offset set to $self->{offset}"));
}


# fills in the template, generating the default one if necessary.
sub _fill_template {
  my $self = shift;
  
  # get the data
  if (ref($self->{get_data_callback}) eq 'CODE') {
    my $get_data_callback = $self->{get_data_callback};
    $self->{data} = &$get_data_callback ($self->{offset}, $self->{page_size});
    defined($self->{data}) || 
      (die("Pager: get_data_callback returned undef!"));
  } elsif (ref($self->{get_data_callback}) eq 'ARRAY') {
    my $get_data_callback = $self->{get_data_callback}[0];
    my @args;
    for (my $x = 1; $x <= $#{$self->{get_data_callback}}; $x++) { 
      push(@args, $self->{get_data_callback}[$x]);
    }
    $self->{data} = &$get_data_callback ($self->{offset}, $self->{page_size}, @args);
    defined($self->{data}) || 
      (die("Pager: get_data_callback returned undef!"));
  } else {
    die "Bad format for get_data_callback - must be a code reference or an array reference (for use with extra arguements).  See the documentation for details.";
  }

  ($self->{debug}) && (warn("Got data."));

  # check the data for the correct format, determine if we're doing
  # named or positional args
  if (ref($self->{data}) ne 'ARRAY') {
    die "get_data_callback returned something that isn't an array ref!  You must return from get_data_callback in the format [ [ \$col1, \$col2], [ \$col1, \$col2] ] or [ { NAME => value ... }, { NAME => value ...} ].";
  }

  my $args_type;
  if (defined($self->{data}[0]) 
      and (ref($self->{data}[0]) eq 'ARRAY')) {  
    $args_type = 'ARRAY';
  } else {
    $args_type = 'HASH';
  }

  foreach my $rowRef (@{$self->{data}}) {
    die "get_data_callback returned something that isn't an array ref!  You must return from get_data_callback in the format [ [ \$col1, \$col2], [ \$col1, \$col2] ] or [ { NAME => value ... }, { NAME => value ...} ]."
      unless (ref($rowRef) eq $args_type);
  }

  # create template if necessary
  if (!exists($self->{template})) { 
    # calculate cols
    $self->{cols} = 0;
    foreach my $rowRef (@{$self->{data}}) {
      if (scalar(@{$rowRef}) > $self->{cols}) {
        $self->{cols} = scalar(@{$rowRef});
      }
    }
    if (defined($self->{column_names})) {
      if (scalar(@{$self->{column_names}}) > $self->{cols}) {
        $self->{cols} = scalar(@{$self->{column_names}});
      }
    }
    
    $self->_create_default_template;
  }

  my $template = $self->{template};
  

  
  # fill in the template  
  if ($args_type eq 'ARRAY') {
    # handle array case
    my @pager_list;
    if (defined($self->{column_names})) {
      my %row;
      my $x = 0;
      foreach my $col_name (@{$self->{column_names}}) {
        $row{"PAGER_DATA_COL_$x"} = "<B>$col_name</B>";
        $x++;
      }
      push(@pager_list, \%row);
    }

    foreach my $rowRef (@{$self->{data}}) {
      my %row;
      my $x = 0;
      foreach my $value (@{$rowRef}) {
        $value = '' unless (defined($value));
        $row{"PAGER_DATA_COL_$x"} = $value;
        $x++;
      }
      if ($x) {
        push(@pager_list, \%row);
      }
    }
    $template->param('PAGER_DATA_LIST', \@pager_list);
  } else {
    # handle the hash case
    $template->param(PAGER_DATA_LIST => $self->{data});
  }  
  
  # generate next and prev
  if (($self->{offset} + $self->{page_size}) < $self->{rows}) {
    my $next_offset = $self->{offset} + $self->{page_size};
    $template->param('PAGER_NEXT', "<INPUT TYPE=BUTTON VALUE='Next Page' onClick=\"PAGER_set_offset_and_submit($next_offset);\">");
  }
  if ($self->{offset} > 0) {
    my $prev_offset = $self->{offset} - $self->{page_size};
    if ($prev_offset < 0) {
      $prev_offset = 0;
    }
    ;
    $template->param('PAGER_PREV', "<INPUT TYPE=BUTTON VALUE='Previous Page' onClick=\"PAGER_set_offset_and_submit($prev_offset);\">");
  }
  
  # generate jump zone
  my %jump_links;
  my $between_pages = 0;
  my $this_page_number = (($self->{offset} / $self->{page_size}) + 1);
  if ($this_page_number =~ /\./) {
    $this_page_number = int($this_page_number) + 1;
    $between_pages = 1;
  }
  $jump_links{0} = [$self->{offset}, $this_page_number];
  
  
  # forward jumps
  for (my $x = 1; $x <= 6; $x++) {
    my $offset = ($self->{offset} + ($self->{page_size} * $x));
    if ($offset < $self->{rows}) {
      $jump_links{$x} = [$offset, ($this_page_number + $x)];
    } else {
      last;
    }
  }
  
  # backward jumps
  for (my $x = 1; $x <= 6; $x++) {
    my $offset = ($self->{offset} - ($self->{page_size} * $x));
    if ($offset >= 0) {
      $jump_links{"-$x"} = [$offset, ($this_page_number - $x)];
    } elsif ($between_pages) {
      $jump_links{"-$x"} = [0, ($this_page_number - $x)];
      $between_pages = 0;      
    } else {
      last;
    }
  }
  
  # output the jumps
  my $jump_string = "";
  my $did_others = 0;
  if (exists $jump_links{-6}) {
    $jump_string .= "<A HREF=\"javascript:PAGER_set_offset_and_submit($jump_links{-6}[0]);\">...</A>\n";
  }
  for (my $x = -5; $x <= 5; $x++) {
    if (exists $jump_links{$x}) {
      if ($x != 0) {
        $jump_string .= "<A HREF=\"javascript:PAGER_set_offset_and_submit($jump_links{$x}[0]);\">$jump_links{$x}[1]</A>\n";
        $did_others = 1;       
      } else {
        $jump_string .= "<B>$jump_links{$x}[1]</B>\n";
      }
    }
  }
  
  if (exists $jump_links{6}) {
    $jump_string .= "<A HREF=\"javascript:PAGER_set_offset_and_submit($jump_links{6}[0]);\">...</A>\n";
  }
  
  
  if ($did_others) {
    $template->param('PAGER_JUMP', $jump_string);
  }


  # Did the user specify a javascript_presubmit?
  my $javascript_presubmit = $self->{javascript_presubmit};
  if ($javascript_presubmit) {
    $javascript_presubmit = <<EOJS;
    if (!($javascript_presubmit)) {
      return;
    }
EOJS
  } else {
    $javascript_presubmit = '    // No javascript_presubmit specified';
  }

  $template->param('PAGER_JAVASCRIPT', <<END);
<SCRIPT LANGUAGE="Javascript">
<!-- These functions are part of the HTML::Pager module -->

<!-- Begin
  // PAGER_set_offset_and_submit finds the FORM with the pager in it
  // sets the offset value and then submits the form. 
  function PAGER_set_offset_and_submit(o) {
$javascript_presubmit
    var form_index = -1;
    for (var x = 0; x < document.forms.length; x++) {
      for ( var i = 0; i < document.forms[x].elements.length; i++) {
        if (document.forms[x].elements[i].name == 'PAGER_offset') {
          form_index = x;
          break;
        }
      }
      if (form_index != -1) {
        break;
      }
    }
    if (form_index != -1) {
       document.forms[form_index].PAGER_offset.value = o;
       document.forms[form_index].submit();
    }      
  }
// End -->
</script>  
END
  
}

# dynamically generates a template for the appropriate number of
# columns.
sub _create_default_template {
  my $self = shift;
  my $cols = $self->{cols};

  my $cell_space_color = $self->{cell_space_color};  # default: '#000000'
  my $cell_background_color = $self->{cell_background_color};  # default: '#ffffff'
  my $nav_background_color = $self->{nav_background_color};  # default: '#DDDDDD'
  
  my $template_text = <<END;
<TMPL_VAR NAME="PAGER_JAVASCRIPT">
<FORM>
<TABLE BORDER=0 BGCOLOR="$cell_space_color" WIDTH=100%>
<TR><TD><TABLE BORDER=0 WIDTH=100%>
  <TMPL_LOOP NAME="PAGER_DATA_LIST">
  <TR>
END
  
  for (my $x = 0; $x < $cols; $x++) {
    $template_text .= <<END;
  <TD BGCOLOR="$cell_background_color"><TMPL_VAR NAME="PAGER_DATA_COL_$x"></TD>
END
  }
  
  $template_text .= <<END;  
  </TR>
  </TMPL_LOOP>
  <TR><TD BGCOLOR="$nav_background_color" COLSPAN=$cols ALIGN=CENTER>
  <TMPL_VAR NAME="PAGER_PREV">
  <TMPL_VAR NAME="PAGER_JUMP">
  <TMPL_VAR NAME="PAGER_NEXT">
  </TABLE>
  </TABLE>
  <TMPL_VAR NAME="PAGER_HIDDEN">
  </FORM>
END
  
  $self->{template} = HTML::Template->new(scalarref => \$template_text);
}

=head2 C<output()>

This method returns the HTML <FORM> and <TABLE> to create the paging
list-view.  If you used the template option to new() this will output
the entire template.

=cut

sub output {
  my $self = shift;
  my $query = $self->{query};
  my $template = $self->{template};

  my @hidden = ();
  push(@hidden, 
       $query->hidden('-name' =>'PAGER_offset', 
                      '-value' => $self->{offset},
                      '-override' => 1)
      );
  foreach my $var (@{$self->{persist_vars}}) {
    push(@hidden, $query->hidden('-name' => $var));
  }
  $template->param(PAGER_HIDDEN => join("\n", @hidden));

  return $template->output();
}


# deprecated equivalent to new(persist_vars => [])
sub persist_vars {
  my $self = shift;

  if ((@_ == 1) and (ref($_[0]) eq 'ARRAY')) {
    $self->{persist_vars} = [ @{$_[0]} ];
  } else {
    $self->{persist_vars} = [@_];
  }
  return (@{$self->{persist_vars}});
}


=head1 MAINTAINING PAGING STATE

Sometimes you'll want to be able to allow the user to leave your
paging list and be able to come back to where they were without
requiring that they use the Back button.  To do this all you have to
do is arrange to save the state of the PAGER_offset parameter, and
pass it back to the paging-list CGI.

=head1 CREDITS

This module was created for Vanguard Media and I'd like to thank my
boss, Jesse Erlbaum, for allowing me to release it to the public.  He
also added the persist_vars functionality, the background colors
option and the javascript_presubmit option.

=head1 AUTHOR

Sam Tregar, sam@tregar.com

=head1 LICENSE

HTML::Template : A Perl module to handle CGI HTML paging of arbitary data 
Copyright (C) 1999 Sam Tregar (sam@tregar.com)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA

=head1 SEE ALSO

L<HTML::Template>, L<CGI>

=cut
    
# YEs!    
1;
