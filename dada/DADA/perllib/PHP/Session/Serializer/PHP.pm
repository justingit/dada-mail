package PHP::Session::Serializer::PHP;

use strict;
use vars qw($VERSION);
$VERSION = 0.26;

sub _croak { require Carp; Carp::croak(@_) }

sub new {
    my $class = shift;
    bless {
	buffer => undef,
	data   => {},
	state  => undef,
	stack  => [],
	array  => [],		# array-ref of hash-ref
    }, $class;
}

# encoder starts here

sub encode {
    my($self, $data) = @_;
    my $body;
    for my $key (keys %$data) {
	if (defined $data->{$key}) {
	    $body .= "$key|" . $self->do_encode($data->{$key});
	} else {
	    $body .= "!$key|";
    	}
    }
    return $body;
}

sub do_encode {
    my($self, $value) = @_;
    if (! defined $value) {
	return $self->encode_null($value);
    }
    elsif (! ref $value) {
	if (is_int($value)) {
	    return $self->encode_int($value);
	}
	elsif (is_float($value)) {
	    return $self->encode_double($value);
	}
	else {
	    return $self->encode_string($value);
	}
    }
    elsif (ref $value eq 'HASH') {
	return $self->encode_array($value);
    }
    elsif (ref $value eq 'ARRAY') {
	return $self->encode_array($value);
    }
    elsif (ref $value eq 'PHP::Session::Object') {
	return $self->encode_object($value);
    }
    else {
	_croak("Can't encode ", ref($value));
    }
}

sub encode_null {
    my($self, $value) = @_;
    return 'N;';
}

sub encode_int {
    my($self, $value) = @_;
    return sprintf 'i:%d;', $value;
}

sub encode_double {
    my($self, $value) = @_;
    return sprintf "d:%s;", $value; # XXX hack
}

sub encode_string {
    my($self, $value) = @_;
    return sprintf 's:%d:"%s";', length($value), $value;
}

sub encode_array {
    my($self, $value) = @_;
    my %array = ref $value eq 'HASH' ? %$value : map { $_ => $value->[$_] } 0..$#{$value};
    return sprintf 'a:%d:{%s}', scalar(keys %array), join('', map $self->do_encode($_), %array);
}

sub encode_object {
    my($self, $value) = @_;
    my %impl = %$value;
    my $class = delete $impl{_class};
    return sprintf 'O:%d:"%s":%d:{%s}', length($class), $class, scalar(keys %impl),
	join('', map $self->do_encode($_), %impl);
}

sub is_int {
    local $_ = shift;
    /^-?(0|[1-9]\d{0,8})$/;
}

sub is_float {
    local $_ = shift;
    /^-?(0|[1-9]\d{0,8})\.\d+$/;
}

# decoder starts here

sub decode {
    my($self, $data) = @_;
    $self->{buffer} = $data;
    $self->change_state('VarName');
    while (defined $self->{buffer} && length $self->{buffer}) {
	$self->{state}->parse($self);
    }
    return $self->{data};
}

sub change_state {
    my($self, $state) = @_;
    $self->{state} = "PHP::Session::Serializer::PHP::State::$state"; # optimization
#    $self->{state} = PHP::Session::Serializer::PHP::State->new($state);

}

sub set {
    my($self, $key, $value) = @_;
    $self->{data}->{$key} = $value;
}

sub push_stack {
    my($self, $stuff) = @_;
    push @{$self->{stack}}, $stuff;
}

sub pop_stack {
    my $self = shift;
    pop @{$self->{stack}};
}

sub extract_stack {
    my($self, $num) = @_;
    return $num ? splice(@{$self->{stack}}, -$num) : ();
}

# array: [ [ $length, $consuming, $class ], [ $length, $consuming, $class ]  .. ]

sub start_array {
    my($self, $length, $class) = @_;
    unshift @{$self->{array}}, [ $length, 0, $class ];
}

sub in_array {
    my $self = shift;
    return scalar @{$self->{array}};
}

sub consume_array {
    my $self = shift;
    $self->{array}->[0]->[1]++;
}

sub finished_array {
    my $self = shift;
    return $self->{array}->[0]->[0] * 2 == $self->{array}->[0]->[1];
}

sub elements_count {
    my $self = shift;
    return $self->{array}->[0]->[0];
}

sub process_value {
    my($self, $value, $empty_skip) = @_;
    if ($self->in_array()) {
	unless ($empty_skip) {
	    $self->push_stack($value);
	    $self->consume_array();
	}
	if ($self->finished_array()) {
	    # just finished array
	    my $array  = shift @{$self->{array}}; # shift it
	    my @values = $self->extract_stack($array->[0] * 2);
	    my $class  = $array->[2];
	    if (defined $class) {
		# object
		my $real_value = bless {
		    _class => $class,
		    @values,
		}, 'PHP::Session::Object';
		$self->process_value($real_value);
	    } else {
		# array is hash
		$self->process_value({ @values });
	    }
	    $self->change_state('ArrayEnd');
	    $self->{state}->parse($self);
	} else {
	    # not yet finished
	    $self->change_state('VarType');
	}
    }
    else {
	# not in array
	my $varname = $self->pop_stack;
	$self->set($varname => $value);
	$self->change_state('VarName');
    }
}

sub weird {
    my $self = shift;
    _croak("weird data: $self->{buffer}");
}

package PHP::Session::Serializer::PHP::State::VarName;

sub parse {
    my($self, $decoder) = @_;
    $decoder->{buffer} =~ s/^(!?)(.*?)\|// or $decoder->weird;
    if ($1) {
	$decoder->set($2 => undef);
    } else {
	$decoder->push_stack($2);
	$decoder->change_state('VarType');
    }
}

package PHP::Session::Serializer::PHP::State::VarType;

my @re = (
    's:(\d+):',			# string
    'i:(-?\d+);',		# integer
    'd:(-?\d+(?:\.\d+)?);',	# double
    'a:(\d+):',			# array
    'O:(\d+):',			# object
    '(N);',			# null
    'b:([01]);',		# boolean
    '[Rr]:(\d+);',              # reference count? 
);

sub parse {
    my($self, $decoder) = @_;
    my $re = join "|", @re;
    $decoder->{buffer} =~ s/^(?:$re)// or $decoder->weird;
    if (defined $1) {		# string
	$decoder->push_stack($1);
	$decoder->change_state('String');
    }
    elsif (defined $2) {	# integer
	$decoder->process_value($2);
    }
    elsif (defined $3) {	# double
	$decoder->process_value($3);
    }
    elsif (defined $4) {	# array
	$decoder->start_array($4);
	$decoder->change_state('ArrayStart');
    }
    elsif (defined $5) {	# object
	$decoder->push_stack($5);
	$decoder->change_state('ClassName');
    }
    elsif (defined $6) {	# null
	$decoder->process_value(undef);
    }
    elsif (defined $7) {	# boolean
	$decoder->process_value($7);
    }
    elsif (defined $8) {        # reference
        $decoder->process_value($8);
    }
}

package PHP::Session::Serializer::PHP::State::String;

sub parse {
    my($self, $decoder) = @_;
    my $length = $decoder->pop_stack();

    # .{$length} has a limit on length
    # $decoder->{buffer} =~ s/^"(.{$length})";//s or $decoder->weird;
    my $value = substr($decoder->{buffer}, 0, $length + 3, "");
    $value =~ s/^"// and $value =~ s/";$// or $decoder->weird;
    $decoder->process_value($value);
}

package PHP::Session::Serializer::PHP::State::ArrayStart;

sub parse {
    my($self, $decoder) = @_;
    $decoder->{buffer} =~ s/^{// or $decoder->weird;
    if ($decoder->elements_count) {
	$decoder->change_state('VarType');
    } else {
	$decoder->process_value(undef, 1);
    }
}

package PHP::Session::Serializer::PHP::State::ArrayEnd;

sub parse {
    my($self, $decoder) = @_;
    $decoder->{buffer} =~ s/^}// or $decoder->weird;
    my $next_state = $decoder->in_array() ? 'VarType' : 'VarName';
    $decoder->change_state($next_state);
}

package PHP::Session::Serializer::PHP::State::ClassName;

sub parse {
    my($self, $decoder) = @_;
    my $length = $decoder->pop_stack();
#    $decoder->{buffer} =~ s/^"(.{$length})":(\d+):// or $decoder->weird;
    my $value = substr($decoder->{buffer}, 0, $length + 3, "");
    $value =~ s/^"// and $value =~ s/":$// or $decoder->weird;
    $decoder->{buffer} =~ s/^(\d+):// or $decoder->weird;
    $decoder->start_array($1, $value); # $length, $class
    $decoder->change_state('ArrayStart');
}


1;
__END__

=head1 NAME

PHP::Session::Serializer::PHP - serialize / deserialize PHP session data

=head1 SYNOPSIS

  use PHP::Session::Serializer::PHP;

  $serializer = PHP::Session::Serializer::PHP->new;

  $enc     = $serializer->encode(\%data);
  $hashref = $serializer->decode($enc);

=head1 TODO

=over 4

=item *

Add option to restore PHP object as is.

=item *

Get back PHP array as Perl array?

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<PHP::Session>

=cut

