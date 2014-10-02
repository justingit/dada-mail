package DADA::Profiles;

use lib qw (
  ../
  ../DADA/perllib
);
use Carp qw(carp croak);
use DADA::Config;
use DADA::App::Guts;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();
use strict;
use vars qw(@EXPORT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_Profile};

use DADA::Profile::Fields;
use DADA::Profile; 


sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;
    $self->_init($args);
    return $self;

}

sub _init {
    my $self = shift;
}


sub update { 
    
   my $self   = shift; 
   my ($args) = @_;

   my $addresses = $args->{-addresses}; 
   my $update_email_count = 0; 
   if(!exists($args->{-password_policy})){ 
       $args->{-password_policy} = 'preserve_if_defined'; # also: 'writeover'
   }

   for my $info (@$addresses) {
       my $dpf = DADA::Profile::Fields->new( { -email => $info->{email} } );
       $dpf->insert(
           {
               -fields => $info->{fields},
               -mode   => 'writeover',
           }
       );
       if ( defined( $info->{profile}->{password} ) && $info->{profile}->{password} ne '' ) {
           my $prof = DADA::Profile->new( { -email => $info->{email} } );
           if ($prof) {
               if ( $prof->exists ) {
                   if($args->{-password_policy} eq 'writeover') { 
                       $prof->update( { -password => $info->{profile}->{password} } );
                   }
                   elsif($args->{-password_policy} eq 'preserve_if_defined'){ 
                       #.... 
                   }
                   else { 
                       carp "unknown policy, " . $args->{-password_policy}; 
                   }
               }
               else {
                   $prof->insert(
                       {
                           -password  => $info->{profile}->{password},
                           -activated => 1,
                       }
                   );
               }
           }
           undef($prof); 
       }
       undef($dpf); 
       
       $update_email_count++;
   }
   
   return $update_email_count;
}

1;
