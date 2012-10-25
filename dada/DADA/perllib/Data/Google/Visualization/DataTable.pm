package Data::Google::Visualization::DataTable;
BEGIN {
  $Data::Google::Visualization::DataTable::VERSION = '0.09';
}

use strict;
use warnings;

use Carp qw(croak carp);
use Storable qw(dclone);
use JSON;
use Time::Local;

=head1 NAME

Data::Google::Visualization::DataTable - Easily create Google DataTable objects

=head1 VERSION

version 0.09

=head1 DESCRIPTION

Easily create Google DataTable objects without worrying too much about typed
data

=head1 OVERVIEW

Google's excellent Visualization suite requires you to format your Javascript
data very carefully. It's entirely possible to do this by hand, especially with
the help of the most excellent L<JSON::XS> but it's a bit fiddly, largely
because Perl doesn't natively support data types and Google's API accepts a
super-set of JSON - see L<JSON vs Javascript> below.

This module is attempts to hide the gory details of preparing your data before
sending it to a JSON serializer - more specifically, hiding some of the hoops
that have to be jump through for making sure your data serializes to the right
data types.

More about the
L<Google Visualization API|http://code.google.com/apis/visualization/documentation/reference.html#dataparam>.

Every effort has been made to keep naming conventions as close as possible to
those in the API itself.

B<To use this module, a reasonable knowledge of Perl is assumed. You should be
familiar with L<Perl references|perlreftut> and L<Perl objects|perlboot>.>

=head1 SYNOPSIS

 use Data::Google::Visualization::DataTable;

 my $datatable = Data::Google::Visualization::DataTable->new();

 $datatable->add_columns(
	{ id => 'date',     label => "A Date",        type => 'date', p => {}},
	{ id => 'datetime', label => "A Datetime",    type => 'datetime' },
	{ id => 'timeofday',label => "A Time of Day", type => 'timeofday' },
	{ id => 'bool',     label => "True or False", type => 'boolean' },
	{ id => 'number',   label => "Number",        type => 'number' },
	{ id => 'string',   label => "Some String",   type => 'string' },
 );

 $datatable->add_rows(

 # Add as array-refs
	[
		{ v => DateTime->new() },
		{ v => Time::Piece->new(), f => "Right now!" },
		{ v => [6, 12, 1], f => '06:12:01' },
		{ v => 1, f => 'YES' },
		15.6, # If you're getting lazy
		{ v => 'foobar', f => 'Foo Bar', p => { display => 'none' } },
	],

 # And/or as hash-refs (but only if you defined id's for each of your columns)
	{
		date      => DateTime->new(),
		datetime  => { v => Time::Piece->new(), f => "Right now!" },
		timeofday => [6, 12, 1],
		bool      => 1,
		number    => 15.6,
		string    => { v => 'foobar', f => 'Foo Bar' },
	},

 );

 # Get the data...

 # Fancy-pants
 my $output = $datatable->output_javascript(
	columns => ['date','number','string' ],
	pretty  => 1,
 );

 # Vanilla
 my $output = $datatable->output_javascript();

=head1 COLUMNS, ROWS AND CELLS

We've tried as far as possible to stay as close as possible to the underlying
API, so make sure you've had a good read of:
L<Google Visualization API|http://code.google.com/apis/visualization/documentation/reference.html#dataparam>.

=head2 Columns

I<Columns> are specified using a hashref, and follow exactly the format of the
underlying API itself. All of C<type>, C<id>, C<label>, C<pattern>, and C<p> are
supported. The contents of C<p> will be passed directly to L<JSON::XS> to
serialize as a whole.

=head2 Rows

A row is either a hash-ref where the keys are column IDs and the values are
I<cells>, or an array-ref where the values are I<cells>.

=head2 Cells

I<Cells> can be specified in several ways, but the best way is using a hash-ref
that exactly conforms to the API. C<v> is NOT checked against your data type -
but we will attempt to convert it. If you pass in an undefined value, it will
return a JS 'null', regardless of the data type. C<f> needs to be a string if
you provide it. C<p> will be bassed directly to L<JSON::XS>.

For any of the date-like fields (C<date>, C<datetime>, C<timeofday>), you can
pass in 4 types of values. We accept L<DateTime> objects, L<Time::Piece>
objects, epoch seconds (as a string - converted internally using
L<localtime|perlfunc/localtime>), or an array-ref of values that will be passed
directly to the resulting Javascript Date object eg:

 Perl:
  date => [ 5, 4, 3 ]
 JS:
  new Date( 5, 4, 3 )

Remember that JS dates 0-index the month. B<Make sure you read the sections on
Dates and Times below if you want any chance of doing this right>...

For non-date fields, if you specify a cell using a string or number, rather than
a hashref, that'll be mapped to a cell with C<v> set to the string you
specified.

C<boolean>: we test the value you pass in for truth, the Perl way, although
undef values will come out as null, not 0.

=head2 Properties

Properties can be defined for the whole datatable (using C<set_properties>), for
each column (using C<p>), for each row (using C<p>) and for each cell (again
using C<p>). The documentation provided is a little unclear as to exactly
what you're allowed to put in this, so we provide you ample rope and let you
specify anything you like.

When defining properties for rows, you must use the hashref method of row
creation. If you have a column with id of C<p>, you must use C<_p> as your key
for defining properties.

=head1 METHODS

=head2 new

Constructor. Accepts a hashref of arguments:

C<p> -  a datatable-wide properties element (see C<Properties> above and the
Google docs).

C<with_timezone> - defaults to false. An experimental feature for doing dates
the right way. See: L<DATES AND TIMES> for discussion below.

=cut

sub new {
	my $class = shift;
	my $args  = shift || {};
	my $self = {
		columns              => [],
		column_mapping       => {},
		rows                 => [],
		json_xs              => JSON->new()->canonical(1)->allow_nonref,
		all_columns_have_ids => 0,
		column_count         => 0,
		pedantic             => 1,
		with_timezone        => ($args->{'with_timezone'} || 0)
	};
	$self->{'properties'} = $args->{'p'} if defined $args->{'p'};
	bless $self, $class;
	return $self;
}

=head2 add_columns

Accepts zero or more columns, in the format specified above, and adds them to
our list of columns. Returns the object. You can't call this method after you've
called C<add_rows> for the first time.

=cut

our %ACCEPTABLE_TYPES = map { $_ => 1 } qw(
	date datetime timeofday boolean number string
);

our %JAVASCRIPT_RESERVED = map { $_ => 1 } qw(
	break case catch continue default delete do else finally for function if in
	instanceof new return switch this throw try typeof var void while with
	abstract boolean byte char class const debugger double enum export extends
	final float goto implements import int interface long native package
	private protected public short static super synchronized throws transient
	volatile const export import
);

sub add_columns {
	my ($self, @columns) = @_;

	croak "You can't add columns once you've added rows"
		if @{$self->{'rows'}};

	# Add the columns to our internal store
	for my $column ( @columns ) {

		# Check the type
		my $type = $column->{'type'};
		croak "Every column must have a 'type'" unless $type;
		croak "Unknown column type '$type'" unless $ACCEPTABLE_TYPES{ $type };

		# Check label and ID are sane
		for my $key (qw( label id pattern ) ) {
			if ( $column->{$key} && ref( $column->{$key} ) ) {
				croak "'$key' needs to be a simple string";
			}
		}

		# Check the 'p' column is ok if it was provided, and convert now to JSON
		if ( defined($column->{'p'}) ) {
			eval { $self->json_xs_object->encode( $column->{'p'} ) };
			croak "Serializing 'p' failed: $@" if $@;
		}

		# ID must be unique
		if ( $column->{'id'} ) {
			my $id = $column->{'id'};
			if ( grep { $id eq $_->{'id'} } @{ $self->{'columns'} } ) {
				croak "We already have a column with the id '$id'";
			}
		}

		# Pedantic checking of that ID
		if ( $self->pedantic ) {
			if ( $column->{'id'} ) {
				if ( $column->{'id'} !~ m/^[a-zA-Z0-9_]+$/ ) {
					carp "The API recommends that t ID's should be both simple:"
						. $column->{'id'};
				} elsif ( $JAVASCRIPT_RESERVED{ $column->{'id'} } ) {
					carp "The API recommends avoiding Javascript reserved " .
						"words for IDs: " . $column->{'id'};
				}
			}
		}

		# Add that column to our collection
		push( @{ $self->{'columns'} }, $column );
	}

	# Reset column statistics
	$self->{'column_mapping'} = {};
	$self->{'column_count'  } = 0;
	$self->{'all_columns_have_ids'} = 1;

	# Map the IDs to column indexes, redo column stats, and encode the column
	# data
	my $i = 0;
	for my $column ( @{ $self->{'columns'} } ) {

		$self->{'column_count'}++;

		# Encode as JSON
		delete $column->{'json'};
		my $column_json = $self->json_xs_object->encode( $column );
		$column->{'json'} = $column_json;

		# Column mapping
		if ( $column->{'id'} ) {
			$self->{'column_mapping'}->{ $column->{'id'} } = $i;
		} else {
			$self->{'all_columns_have_ids'} = 0;
		}
		$i++;
	}

	return $self;
}

=head2 add_rows

Accepts zero or more rows, either as a list of hash-refs or a list of
array-refs. If you've provided hash-refs, we'll map the key name to the column
via its ID (you must have given every column an ID if you want to do this, or
it'll cause a fatal error).

If you've provided array-refs, we'll assume each cell belongs in subsequent
columns - your array-ref must have the same number of members as you have set
columns.

=cut

sub add_rows {
	my ( $self, @rows_to_add ) = @_;

	# Loop over our input rows
	for my $row (@rows_to_add) {

		my @columns;
		my $properties;

		# Map hash-refs to columns
		if ( ref( $row ) eq 'HASH' ) {

			# Grab the properties, if they exist
			if ( exists $self->{'column_mapping'}->{'p'} ) {
				$properties = delete $row->{'_p'};
			} else {
				$properties = delete $row->{'p'};
			}

			# We can't be going forward unless they specified IDs for each of
			# their columns
			croak "All your columns must have IDs if you want to add hashrefs" .
				" as rows" unless $self->{'all_columns_have_ids'};

			# Loop through the keys, populating @columns
			for my $key ( keys %$row ) {
				# Get the relevant column index for the key, or handle 'p'
				# properly
				unless ( exists $self->{'column_mapping'}->{ $key } ) {
					croak "Couldn't find a column with id '$key'";
				}
				my $index = $self->{'column_mapping'}->{ $key };

				# Populate @columns with the data-type and value
				$columns[ $index ] = [
					$self->{'columns'}->[ $index ]->{'type'},
					$row->{ $key }
				];

			}

		# Map array-refs to columns
		} elsif ( ref( $row ) eq 'ARRAY' ) {

			# Populate @columns with the data-type and value
			my $i = 0;
			for my $col (@$row) {
				$columns[ $i ] = [
					$self->{'columns'}->[ $i ]->{'type'},
					$col
				];
				$i++;
			}

		# Rows must be array-refs or hash-refs
		} else {
			croak "Rows must be array-refs or hash-refs: $row";
		}

		# Force the length of columns to be the same as actual columns, to
		# handle undef values better.
		$columns[ $self->{'column_count'} - 1 ] = undef
			unless defined $columns[ $self->{'column_count'} - 1 ];

		# Convert each cell in to the long cell format
		my @formatted_columns;
		for ( @columns ) {
			if ( $_ ) {
				my ($type, $column) = @$_;

				if ( ref( $column ) eq 'HASH' ) {
					# Check f is a simple string if defined
					if ( defined($column->{'f'}) && ref( $column->{'f'} ) ) {
						croak "Cell's 'f' values must be strings: " .
							$column->{'f'};
					}
					# If p is defined, check it serializes
					if ( defined($column->{'p'}) ) {
						croak "'p' must be a reference"
							unless ref( $column->{'p'} );
						eval { $self->json_xs_object->encode( $column->{'p'} ) };
						croak "Serializing 'p' failed: $@" if $@;
					}
					# Complain about any unauthorized keys
					if ( $self->pedantic ) {
						for my $key ( keys %$column ) {
							carp "'$key' is not a recognized key"
								unless $key =~ m/^[fvp]$/;
						}
					}
					push( @formatted_columns, [ $type, $column ] );
				} else {
					push( @formatted_columns, [ $type, { v => $column } ] );
				}
			# Undefined that become nulls
			} else {
				push( @formatted_columns, [ 'null', { v => undef } ] );
			}
		}

		# Serialize each cell
		my @cells;
		for (@formatted_columns) {
			my ($type, $cell) = @$_;

			# Force 'f' to be a string
			if ( defined( $cell->{'f'} ) ) {
				$cell->{'f'} .= '';
			}

			# Handle null/undef
			if ( ! defined($cell->{'v'}) ) {
				push(@cells, $self->json_xs_object->encode( $cell ) );

			# Convert boolean
			} elsif ( $type eq 'boolean' ) {
				$cell->{'v'} = $cell->{'v'} ? \1 : \0;
				push(@cells, $self->json_xs_object->encode( $cell ) );

			# Convert number
			} elsif ( $type eq 'number' ) {
				$cell->{'v'} = 0 unless $cell->{'v'}; # Force false values to 0
				$cell->{'v'} += 0; # Force numeric for JSON encoding
				push(@cells, $self->json_xs_object->encode( $cell ) );

			# Convert string
			} elsif ( $type eq 'string' ) {
				$cell->{'v'} .= '';
				push(@cells, $self->json_xs_object->encode( $cell ) );

			# It's a date!
			} else {
				my @date_digits;

				# Date digits specified manually
				if ( ref( $cell->{'v'} ) eq 'ARRAY' ) {
					@date_digits = @{ $cell->{'v'} };
				# We're going to have to retrieve them ourselves
				} else {
					my @initial_date_digits;

					# Epoch timestamp
					if (! ref( $cell->{'v'} ) ) {
						my ($sec,$min,$hour,$mday,$mon,$year) =
							localtime( $cell->{'v'} );
						$year += 1900;
						@initial_date_digits =
							( $year, $mon, $mday, $hour, $min, $sec );

					} elsif ( $cell->{'v'}->isa('DateTime') ) {
						my $dt = $cell->{'v'};
						@initial_date_digits = (
							$dt->year, ( $dt->mon - 1 ), $dt->day,
							$dt->hour, $dt->min, $dt->sec
						);

					} elsif ( $cell->{'v'}->isa('Time::Piece') ) {
						my $tp = $cell->{'v'};
						@initial_date_digits = (
							$tp->year, $tp->_mon, $tp->mday,
							$tp->hour, $tp->min, $tp->sec
						);

					} else {
						croak "Unknown date format";
					}

					if ( $type eq 'date' ) {
						@date_digits = @initial_date_digits[ 0 .. 2 ];
					} elsif ( $type eq 'datetime' ) {
						@date_digits = @initial_date_digits[ 0 .. 5 ];
					} else { # Time of day
						@date_digits = @initial_date_digits[ 3 .. 5 ];
					}
				}

				my $json_date = join ', ', @date_digits;
				if ( $type eq 'timeofday' ) {
					$json_date = '[' . $json_date . ']';
				} else {
					$json_date = 'new Date( ' . $json_date . ' )';
				}

				# Actually, having done all this, timezone hack date...
				if (
					$self->{'with_timezone'} &&
					ref ( $cell->{'v'} )     &&
					ref ( $cell->{'v'} ) ne 'ARRAY' &&
					$cell->{'v'}->isa('DateTime') &&
					( $type eq 'date' || $type eq 'datetime' )
				) {
					$json_date = 'new Date("' .
						$cell->{'v'}->strftime('%a, %d %b %Y %H:%M:%S GMT%z') .
						'")';
				}

				my $placeholder = '%%%PLEHLDER%%%';
				$cell->{'v'} = $placeholder;
				my $json_string = $self->json_xs_object->encode( $cell );
				$json_string =~ s/"$placeholder"/$json_date/;
				push(@cells, $json_string );
			}
		}

		my %data = ( cells => \@cells );
		$data{'properties'} = $properties if defined $properties;

		push( @{ $self->{'rows'} }, \%data );
	}

	return $self;
}

=head2 pedantic

We do some data checking for sanity, and we'll issue warnings about things the
API considers bad data practice - using reserved words or fancy characters and
IDs so far. If you don't want that, simple say:

 $object->pedantic(0);

Defaults to true.

=cut

sub pedantic {
	my ($self, $arg) = @_;
	$self->{'pedantic'} = $arg if defined $arg;
	return $self->{'pedantic'};
}

=head2 set_properties

Sets the datatable-wide properties value. See the Google docs.

=cut

sub set_properties {
	my ( $self, $arg ) = @_;
	$self->{'properties'} = $arg;
	return $self->{'properties'};
}

=head2 json_xs_object

You may want to configure your L<JSON::XS> object in some magical way. This is
a read/write accessor to it. If you didn't understand that, or why you'd want
to do that, you can ignore this method.

=cut

sub json_xs_object {
	my ($self, $arg) = @_;
	$self->{'json_xs'} = $arg if defined $arg;
	return $self->{'json_xs'};
}

=head2 output_javascript

Returns a Javascript serialization of your object. You can optionally specify two
parameters:

C<pretty> - I<bool> - defaults to false - that specifies if you'd like your Javascript
spread-apart with whitespace. Useful for debugging.

C<columns> - I<array-ref of strings> - pick out certain columns only (and in the
order you specify). If you don't provide an argument here, we'll use them all
and in the order set in C<add_columns>.

=head2 output_json

An alias to C<output_javascript> above, with a very misleading name, as it outputs
Javascript, not JSON - see L<JSON vs Javascript> below.

=cut

sub output_json { my ( $self, %params ) = @_; $self->output_javascript( %params ) }

sub output_javascript {
	my ($self, %params) = @_;

	my ($columns, $rows) = $self->_select_data( %params );

	my ($t, $s, $n) = ('','','');
	if ( $params{'pretty'} ) {
		$t = "    ";
		$s = " ";
		$n = "\n";
	}

	# Columns
	my $columns_string = join ',' .$n.$t.$t, @$columns;

	# Rows
	my @rows = map {
		my $tt = $t x 3;
		# Turn the cells in to constituent values
		my $individual_row_string = join ',' .$n.$tt.$t, @{$_->{'cells'}};
		# Put together the output itself
		my $output =
			'{' .$n.
			$tt. '"c":[' .$n.
			$tt.$t. $individual_row_string .$n.
			$tt.']';

		# Add properties
		if ( $_->{'properties'} ) {
			my $properties = $self->_encode_properties( $_->{'properties'} );
			$output .= ',' .$n.$tt.'"p":' . $properties;
		}

		$output .= $n.$t.$t.'}';
		$output;
	} @$rows;
	my $rows_string = join ',' . $n . $t . $t, @rows;

	my $return =
		'{' .$n.
		$t.     '"cols": [' .$n.
		$t.     $t.    $columns_string .$n.
		$t.     '],' .$n.
		$t.     '"rows": [' .$n.
		$t.     $t.    $rows_string .$n.
		$t.     ']';

	if ( defined $self->{'properties'} ) {
		my $properties = $self->_encode_properties( $self->{'properties'} );
		$return .= ',' .$n.$t.'"p":' . $properties;
	}

	$return .= $n.'}';
	return $return;
}

sub _select_data {
	my ($self, %params) = @_;

	my $rows    = dclone $self->{'rows'};
	my $columns = [map { $_->{'json'} } @{$self->{'columns'}}];

	# Select certain columns by id only
	if ( $params{'columns'} && @{ $params{'columns'} } ) {
		my @column_spec;

		# Get the name of each column
		for my $column ( @{$params{'columns'}} ) {

		# And push it's place in the array in to our specification
			my $index = $self->{'column_mapping'}->{ $column };
			croak "Couldn't find a column named '$column'" unless
				defined $index;
			push(@column_spec, $index);
		}

		# Grab the column selection
		my @new_columns;
		for my $index (@column_spec) {
			my $column = splice( @{$columns}, $index, 1, '' );
			push(@new_columns, $column);
		}

		# Grab the row selection
		my @new_rows;
		for my $original_row (@$rows) {
			my @new_cells;
			for my $index (@column_spec) {
				my $column = splice( @{$original_row->{'cells'}}, $index, 1, '' );
				push(@new_cells, $column);
			}
			my $new_row = $original_row;
			$new_row->{'cells'} = \@new_cells;

			push(@new_rows, $new_row);
		}

		$rows = \@new_rows;
		$columns = \@new_columns;
	}

	return ( $columns, $rows );
}

sub _encode_properties {
	my ( $self, $properties ) = @_;
	return $self->json_xs_object->encode( $properties );
}

=head1 JSON vs Javascript

Please note this module outputs Javascript, and not JSON. JSON is a subset of Javascript,
and Google's API requires a similar - but different - subset of Javascript. Specifically
some values need to be set to native Javascript objects, such as (and currently limited to)
the Date object. That means we output code like:

 {"v":new Date( 2011, 2, 21, 2, 6, 25 )}

which is valid Javascript, but not valid JSON.

=head1 DATES AND TIMES

Dates are one of the reasons this module is needed at all - Google's API in
theory accepts Date objects, rather than a JSON equivalent of it. However,
given:

 new Date( 2011, 2, 21, 2, 6, 25 )

in Javascript, what timezone is that? If you guessed UTC because that would be
The Right Thing To Do, sadly you guessed wrong - it's actually set in the
timezone of the client. And as you don't know what the client's timezone is,
if you're going to actually use this data for anything other than display to
that user, you're a little screwed.

Even if we don't attempt to rescue that, if you pass in an Epoch timestamp, I
have no idea which timezone you want me to use to convert that in to the above.
We started off using C<localtime>, which shows I hadn't really thought about it,
and will continue to use it for backwards compatibility, but:

B<Don't pass this module epoch time stamps>. Either do the conversion in your
code using C<localtime> or C<gmtime>, or pass in a L<DateTime> object whose
C<<->hour>> and friends return the right thing.

We accept four types of date input, and this is how we handle each one:

=head2 epoch seconds

We use C<localtime>, and then drop the returned fields straight in to a call to
C<new Date()> in JS.

=head2 DateTime and Time::Piece

We use whatever's being returned by C<hour>, C<min> and C<sec>. Timezone messin'
in the object itself to get the output you want is left to you.

=head2 Raw values

We stick it straight in as you specified it.

=head2 ... and one more thing

So it is actually possible - although a PITA - to create a Date object in
Javascript using C<Date.parse()> which has an offset. In theory, all browsers
should support dates in L<RFC 2822's format|http://tools.ietf.org/html/rfc2822#page-14>:

 Thu, 01 Jan 1970 00:00:00 GMT-0400

If you're thinking L<trolololo|http://www.youtube.com/watch?v=32UGD0fV45g> at
this point, you're on the right track...

So here's the deal: B<IF> you specify C<with_timezone> to this module's C<new>
AND you pass in a L<DateTime> object, you'll get dates like:

 new Date("Thu, 01 Jan 1970 00:00:00 GMT-0400")

in your output.

=head1 BUG BOUNTY

Find a reproducible bug, file a bug report, and I (Peter Sergeant) will donate
$10 to The Perl Foundation (or Wikipedia). Feature Requests are not bugs :-)
Offer subject to author's discretion...

$20 donated 31Dec2010 to TPF re L<properties handling bug|https://rt.cpan.org/Ticket/Display.html?id=64356>

$10 donated 11Nov2010 to TPF re L<null display bug|https://rt.cpan.org/Ticket/Display.html?id=62899>

=head1 SUPPORT

If you find a bug, please use
L<this modules page on the CPAN bug tracker|https://rt.cpan.org/Ticket/Create.html?Queue=Data-Google-Visualization-DataTable>
to raise it, or I might never see.

=head1 AUTHOR

Peter Sergeant C<pete@clueball.com> on behalf of
L<Investor Dynamics|http://www.investor-dynamics.com/> - I<Letting you know what
your market is thinking>.

=head1 SEE ALSO

L<Python library that does the same thing|http://code.google.com/p/google-visualization-python/>

L<JSON::XS> - The underlying module

L<Google Visualization API|http://code.google.com/apis/visualization/documentation/reference.html#dataparam>.

L<Github Page for this code|https://github.com/sheriff/data-google-visualization-datatable-perl>

=head1 COPYRIGHT

Copyright 2010 Investor Dynamics Ltd, some rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;