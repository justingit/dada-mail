package PHP::Session;

use strict;
use vars qw($VERSION);
$VERSION = '0.27';

use vars qw(%SerialImpl);
%SerialImpl = (
    php => 'PHP::Session::Serializer::PHP',
);

use Fcntl qw(:flock);
use FileHandle;
use File::Spec;
use UNIVERSAL::require;

sub _croak { require Carp; Carp::croak(@_) }
sub _carp  { require Carp; Carp::carp(@_) }

sub new {
    my($class, $sid, $opt) = @_;
    my %default = (
	save_path         => '/tmp',
	serialize_handler => 'php',
	create            => 0,
	auto_save         => 0,
    );
    $opt ||= {};
    my $self = bless {
	%default,
	%$opt,
	_sid  => $sid,
	_data => {},
	_changed => 0,
    }, $class;
    $self->_validate_sid;
    $self->_parse_session;
    return $self;
}

# accessors, public methods

sub id { shift->{_sid} }

sub get {
    my($self, $key) = @_;
    return $self->{_data}->{$key};
}

sub set {
    my($self, $key, $value) = @_;
    $self->{_changed}++;
    $self->{_data}->{$key} = $value;
}

sub unregister {
    my($self, $key) = @_;
    delete $self->{_data}->{$key};
}

sub unset {
    my $self = shift;
    $self->{_data} = {};
}

sub is_registered {
    my($self, $key) = @_;
    return exists $self->{_data}->{$key};
}

sub decode {
    my($self, $data) = @_;
    $self->serializer->decode($data);
}

sub encode {
    my($self, $data) = @_;
    $self->serializer->encode($data);
}

sub save {
    my $self = shift;
    my $handle = FileHandle->new("> " . $self->_file_path)
	or _croak("can't write session file: $!");
    flock $handle, LOCK_EX;
    $handle->print($self->encode($self->{_data}));
    $handle->close;
    $self->{_changed} = 0;	# init
}

sub destroy {
    my $self = shift;
    unlink $self->_file_path;
}

sub DESTROY {
    my $self = shift;
    if ($self->{_changed}) {
	if ($self->{auto_save}) {
	    $self->save;
	} else {
	    _carp("PHP::Session: some keys are changed but not saved.") if $^W;
	}
    }
}

# private methods

sub _validate_sid {
    my $self = shift;
    my($id) = $self->id =~ /^([0-9a-zA-Z]*)$/; # untaint
    defined $id or _croak("Invalid session id: ", $self->id);
    $self->{_sid} = $id;
}

sub _parse_session {
    my $self = shift;
    my $cont = $self->_slurp_content;
    if (!$cont && !$self->{create}) {
	_croak($self->_file_path, ": $!");
    }
    $self->{_data} = $self->decode($cont);
}

sub serializer {
    my $self = shift;
    my $impl = $SerialImpl{$self->{serialize_handler}};
    $impl->require;
    return $impl->new;
}

sub _file_path {
    my $self = shift;
    return File::Spec->catfile($self->{save_path}, 'sess_' . $self->id);
}

sub _slurp_content {
    my $self = shift;

    my $handle = FileHandle->new($self->_file_path) or return;
    binmode $handle;
    flock $handle, LOCK_SH;
    local $/ = undef;
    my $data = <$handle>;
    $handle->close;

    return $data;
}

1;
__END__

=head1 NAME

PHP::Session - read / write PHP session files

=head1 SYNOPSIS

  use PHP::Session;

  my $session = PHP::Session->new($id);

  # session id
  my $id = $session->id;

  # get/set session data
  my $foo = $session->get('foo');
  $session->set(bar => $bar);

  # remove session data
  $session->unregister('foo');

  # remove all session data
  $session->unset;

  # check if data is registered
  $session->is_registered('bar');

  # save session data
  $session->save;

  # destroy session
  $session->destroy;

  # create session file, if not existent
  $session = PHP::Session->new($new_sid, { create => 1 });

=head1 DESCRIPTION

PHP::Session provides a way to read / write PHP4 session files, with
which you can make your Perl application session shared with PHP4.

If you like Apache::Session interface for session management, there is
a glue for Apache::Session of this module, Apache::Session::PHP.

=head1 OPTIONS

Constructor C<new> takes some options as hashref.

=over 4

=item save_path

path to directory where session files are stored. default: C</tmp>.

=item serialize_handler

type of serialization handler. Currently only PHP default
serialization is supported.

=item create

whether to create session file, if it's not existent yet. default: 0

=item auto_save

whether to save modification to session file automatically. default: 0

Consider cases like this:

  my $session = PHP::Session->new($sid, { auto_save => 1 });
  $session->set(foo => 'bar');

  # Oops, you forgot save() method!

If you set C<auto_save> to true value and when you forget to call
C<save> method after parameter modification, this module would save
session file automatically when session object goes out of scope.

If you set it to 0 (default) and turn warnings on, this module would
give you a warning like:

  PHP::Session: some keys are changed but not modified.

=back

=head1 EXAMPLE

  use strict;
  use PHP::Session;
  use CGI::Lite;
  my $session_name = 'PHPSESSID'; # change this if needed

  print "Content-type: text/plain\n\n";
  
  my $cgi = new CGI::Lite;
  
  my $cookies = $cgi->parse_cookies;
  if ($cookies->{$session_name}) {
     my $session = PHP::Session->new($cookies->{$session_name});
     # now, try to print uid variable from PHP session
     print "uid:",Dumper($session->get('uid'));
  } else {
     print "can't find session cookie $session_name";
  }


=head1 NOTES

=over 4

=item *

Array in PHP is hash in Perl.

=item *

Objects in PHP are restored as objects blessed into
PHP::Session::Object (Null class) and original class name is stored in
C<_class> key.

=item *

Locking when save()ing data is acquired via exclusive C<flock>, same as
PHP implementation.

=item *

Not tested so much, thus there may be some bugs in
(des|s)erialization code. If you find any, tell me via email.

=back

=head1 TODO

=over 4

=item *

WDDX support, using WDDX.pm

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Apache::Session::PHP>, L<WDDX>, L<Apache::Session>, L<CGI::kSession>

=cut
