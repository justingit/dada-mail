# Copyrights 1999,2001-2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.03.
package MIME::Type;
use vars '$VERSION';
$VERSION = '1.23';

use strict;

use Carp 'croak';


#-------------------------------------------


use overload '""' => 'type'
           ,  cmp => 'equals'
           ;

#-------------------------------------------


sub new(@) { (bless {}, shift)->init( {@_} ) }

sub init($)
{   my ($self, $args) = @_;

    $self->{MT_type}       = $args->{type}
       or croak "ERROR: Type parameter is obligatory.";

    $self->{MT_simplified} = $args->{simplified}
       || ref($self)->simplified($args->{type});

    $self->{MT_extensions} = $args->{extensions} || [];

    $self->{MT_encoding}
       = $args->{encoding}          ? $args->{encoding}
       : $self->mediaType eq 'text' ? 'quoted-printable'
       :                              'base64';

    $self->{MT_system}     = $args->{system}
       if defined $args->{system};

    $self;
}

#-------------------------------------------


sub type() {shift->{MT_type}}

#-------------------------------------------


sub simplified(;$)
{   my $thing = shift;
    return $thing->{MT_simplified} unless @_;

    my $mime  = shift;

      $mime =~ m!^\s*(?:x\-)?([\w.+-]+)/(?:x\-)?([\w.+-]+)\s*$!i ? lc "$1/$2"
    : $mime =~ m!text! ? "text/plain"         # some silly mailers...
    : undef;
}

#-------------------------------------------


sub extensions() { @{shift->{MT_extensions}} }

#-------------------------------------------


sub encoding() {shift->{MT_encoding}}

#-------------------------------------------


sub system() {shift->{MT_system}}

#-------------------------------------------


sub mediaType() {shift->{MT_simplified} =~ m!^([\w-]+)/! ? $1 : undef}

sub mainType()  {shift->mediaType} # Backwards compatibility

#-------------------------------------------


sub subType() {shift->{MT_simplified} =~ m!/([\w-]+)$! ? $1 : undef}

#-------------------------------------------


sub isRegistered()
{   local $_ = shift->{MT_type};
    not (m/^[xX]\-/ || m!/[xX]\-!);
}


#-------------------------------------------


sub isBinary() { shift->{MT_encoding} eq 'base64' }

#-------------------------------------------


sub isAscii() { shift->{MT_encoding} ne 'base64' }

#-------------------------------------------


# simplified names only!
my %sigs = map { ($_ => 1) }
  qw(application/pgp-keys application/pgp application/pgp-signature
     application/pkcs10 application/pkcs7-mime application/pkcs7-signature
     text/vCard);

sub isSignature() { $sigs{shift->{MT_simplified}} }

#-------------------------------------------


sub equals($)
{   my ($self, $other) = @_;

    my $type = ref $other
      ? $other->simplified
      : (ref $self)->simplified($other);

    $self->simplified cmp $type;
}

1;
