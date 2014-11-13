package DADA::App::BounceHandler::Rules;

use strict;
use lib qw(
  ../../../
  ../../../DADA/perllib
);

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;
use 5.008_001;
use Mail::Verp;

use Carp qw(croak carp);
use vars qw($AUTOLOAD);

my %allowed = ();

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;
    $self->_init($args);
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {

    my $self = shift;
    my ($args) = @_;

}

sub find_rule_to_use {

    my $self  = shift;
    my $Rules = [];
    $Rules = $self->rules;

    my ( $list, $email, $diagnostics ) = @_;

    my $ir = 0;

  RULES: for ( $ir = 0 ; $ir <= $#$Rules ; $ir++ ) {
        my $rule  = $Rules->[$ir];
        my $title = ( keys %$rule )[0];

        next if $title eq 'default';
        my $match   = {};
        my $examine = $Rules->[$ir]->{$title}->{Examine};

        my $message_fields = $examine->{Message_Fields};
        my %ThingsToMatch;

        for my $m_field ( keys %$message_fields ) {
            my $is_regex   = 0;
            my $real_field = $m_field;
            $ThingsToMatch{$m_field} = 0;

            if ( $m_field =~ m/_regex$/ ) {
                $is_regex   = 1;
                $real_field = $m_field;
                $real_field =~ s/_regex$//;
            }

          MESSAGEFIELD:
            for my $pos_match ( @{ $message_fields->{$m_field} } ) {
                if ( $is_regex == 1 ) {
					if(exists($diagnostics->{$real_field})){ 
	                    if ( $diagnostics->{$real_field} =~ m/$pos_match/ ) {
	                        $ThingsToMatch{$m_field} = 1;
	                        next MESSAGEFIELD;
	                    }
					}
                }
                else {
					if(exists($diagnostics->{$real_field})){ 		
	                    if ( $diagnostics->{$real_field} eq $pos_match ) {
	                        $ThingsToMatch{$m_field} = 1;
	                        next MESSAGEFIELD;
	                    }
					}

                }
            }

        }

        # If we miss one, the rule doesn't work,
        # All or nothin', just like life.

        for ( keys %ThingsToMatch ) {
            if ( $ThingsToMatch{$_} == 0 ) {
                next RULES;
            }
        }

        if ( keys %{ $examine->{Data} } ) {
            if ( $examine->{Data}->{Email} ) {
                my $valid_email = 0;
                my $email_match;
                if ( DADA::App::Guts::check_for_valid_email($email) == 0 ) {
                    $valid_email = 1;
                }
                if (
                    (
                           ( $examine->{Data}->{Email} eq 'is_valid' )
                        && ( $valid_email == 1 )
                    )
                    || (   ( $examine->{Data}->{Email} eq 'is_invalid' )
                        && ( $valid_email == 0 ) )
                  )
                {
                    $email_match = 1;
                }
                else {
                    next RULES;
                }
            }

            if ( $examine->{Data}->{List} ) {
                my $valid_list = 0;
                my $list_match;
                if ( DADA::App::Guts::check_if_list_exists( -List => $list ) !=
                    0 )
                {
                    $valid_list = 1;
                }
                if (
                    (
                           ( $examine->{Data}->{List} eq 'is_valid' )
                        && ( $valid_list == 1 )
                    )
                    ||

                    (
                           ( $examine->{Data}->{List} eq 'is_invalid' )
                        && ( $valid_list == 0 )
                    )
                  )
                {
                    $list_match = 1;
                }
                else {
                    next RULES;
                }
            }
        }
        return $title;
    }
    return 'default';
}

sub rules {

    my $self = shift;
	my $actual_rules_loc = undef; 
	my @loc_for_rules = (
	# Custom Ruleset
	$DADA::Config::DIR . '/.configs/bounce_handler_rules.pl',

	# From the module, itself
	'../../../data/bounce_handler_rules.pl',
	
	# From the plugin
 	'../data/bounce_handler_rules.pl',
	
	'./data/bounce_handler_rules.pl',
	);
	
	for(@loc_for_rules) { 
		if(-e $_){ 
			$actual_rules_loc = $_;
			last; 
		}
	}
	if(! defined($actual_rules_loc)){ 
		croak "Can not find Bounce Handler Rules at any of these locations: " . join(', ', @loc_for_rules); 
	}
	
#    For whatever reason, this was fairly, hard. 
#	open(BOUNCE_RULES, '<:encoding(UTF-8)',  $actual_rules_loc) 
    open(BOUNCE_RULES, '<',  $actual_rules_loc) 
		or croak "could not open Bounce Rules: $!"; 
	my $rules;
	   $rules = do{ local $/; <BOUNCE_RULES> }; 

	# shooting again, 
	$rules =~ m/(.*)/ms;
	$rules = $1;	

	my $Rules; 
	eval  $rules;
	
    return $Rules;

}

sub rule { 
	
	# Awful code. 
	my $self  = shift; 
	my $rt   = shift; 
	my $Rules = $self->rules; 
	
    
	my $ir; 
  	RULES: for ( $ir = 0 ; $ir <= $#$Rules ; $ir++ ) {
		my $rule  = $Rules->[$ir];
	    my $title = ( keys %$rule )[0];
		if($title eq $rt){
			return $Rules->[$ir];
		}
	}
	
	return {};
}

sub DESTROY { }

1;
