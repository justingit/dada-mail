package HTML::FillInForm::Lite::Compat;

use strict;
use warnings;

our $VERSION = '1.13';

use HTML::FillInForm::Lite;
our @ISA = qw(HTML::FillInForm::Lite);

$INC{'HTML/FillInForm.pm'} ||= __FILE__;
push @HTML::FillInForm::ISA, __PACKAGE__
	unless HTML::FillInForm->isa(__PACKAGE__);

my %known_keys = (
	scalarref	=> 1,
	arrayref	=> 1,
	fdat		=> 1,
	fobject		=> 1,
	file		=> 1,
	target	 	=> 1,
	fill_password	=> 1,
	ignore_fields	=> 1,
	disable_fields	=> 1,
);

my %extended_keys = (
	escape        => 1,
	decode_entity => 1,
	layer         => 1,
);

@known_keys{keys %extended_keys} = ();

BEGIN{
	*fill_file      = \&fill;
	*fill_arrayref  = \&fill;
	*fill_scalarref = \&fill;
}

sub new{
	my $class = shift;

	if(@_){
		warnings::warnif(portable =>
			 qq{$class->new() accepts no options, }
			. q{use HTML::FillInForm::Lite->new(...) instead});
	}

	return $class->SUPER::new();
}

sub fill{
	my $self = shift;

	my $source;
	my $data;

	if (defined $_[0] and not exists $known_keys{ $_[0] }){
		$source = shift;
	}

	if (defined $_[0] and not exists $known_keys{ $_[0] }){
		$data = shift;
	}

	my %option = @_;

	foreach my $key(keys %option){
		if(exists $extended_keys{$key}){
			warnings::warnif(portable => qq{HTML::FillInForm::Lite-specific option "$key" supplied});
		}
	}

	$source ||= $option{file} || $option{scalarref} || $option{arrayref};
	$data   ||= $option{fdat} || $option{fobject};

	# ensure to delete all sources and data
	delete @option{qw(scalarref arrayref file fdat fobject)};

	$option{fill_password} = 1
		unless defined $option{fill_password};
	$option{decode_entity} = 1
		unless defined $option{decode_entity};

	$option{ignore_fields} = [ $option{ignore_fields} ]
		if defined $option{ignore_fields}
		   and ref $option{ignore_fields} ne 'ARRAY';

	return $self->SUPER::fill($source, $data, %option);
}

1;

__END__

=encoding UTF-8

=head1 NAME

HTML::FillInForm::Lite::Compat - HTML::FillInForm compatibility layer

=head1 SYNOPSIS

	use HTML::FillInForm::Lite::Compat;

	use HTML::FillInForm; # doesn't require HTML::FillInForm

	my $fif = HTML::FillInForm->new();
	$fif->isa('HTML::FillInForm::Lite'); # => yes

	# or

	perl -MHTML::FillInForm::Lite::Compat script_using_fillinform.pl

=head1 DESCRIPTION

This module provides an interface compatible with C<HTML::FillInForm>.

It B<takes over> the C<use HTML::FillInForm> directive to use
C<HTML::FillInForm::Lite> instead, so that scripts and modules
that depend on C<HTML::FillInForm> go without it.

=head1 METHODS

The following is compatible with those of C<HTML::FillInForm>.

=over 4

=item new()

It accepts no options as C<HTML::FillInForm> does.

=item fill(...)

=item fill_file(file, ...)

=item fill_scalarref(scalarref, ...)

=item fill_arrayref(arrayref, ...)

=back

=head1 SEE ALSO

L<HTML::FillInForm>.

L<HTML::FillInForm::Lite>.

=head1 AUTHOR

Goro Fuji (藤 吾郎) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008-2010 Goro Fuji, Some rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
