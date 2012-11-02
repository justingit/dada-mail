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
	$DADA::Config::CONFIGS . '/bounce_handler_rules.pl',

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
	
	open(BOUNCE_RULES, '<:encoding(UTF-8)',  $actual_rules_loc) 
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

sub DESTROY { }

1;

=pod

=head1 Introduction to Rules


An example Rule: 

     {
        exim_user_unknown => { 
            Examine => { 
                Message_Fields => { 
                    Status      => [qw(5.x.y)], 
                    Guessed_MTA => [qw(Exim)],  
                }, 
                Data => { 
                    Email       => 'is_valid',
                    List        => 'is_valid', 
                }
            },
                Action => { 
                     add_to_score => 'hardbounce_score',
                }, 
            }
    }, 

B<exim_user_unknown> is the title of the rule -  just a label, nothing else.

B<Examine> holds a set of parameters that the handler looks at when
trying to figure out what to do with a bounced message. This example
has a B<Message_Fields> entry and inside that, a B<Status> entry. The
B<Status> entry holds a list of status codes. The ones in shown there
all correspond to hard bounces; the mailbox probably doesn't exist. 

B<Message_Fields> also hold a, B<Guessed_MTA> entry - it's explicitly looking for a 
bounce back from the, I<Exim> mail server. 


B<Examine> also holds a B<Data> entry, which holds the B<Email> or B<List> 
entries, or both. Their values are either 'is_valid', or 'is_invalid'. 

So, to sum this all up, this rule will match a message that has B<Status:> 
B<Message Field> contaning a user unknown error code, B<(5.1.1, etc)> and also a B<Guessed_MTA> B<Message Field> containing, B<Exim>. The message
also has to be parsed to have found a valid email and list name. 

If this all matches, the B<Action> is... acted upon. In this case, the offending email address will be appended a, B<Bounce Score> of,
 whatever, B<UPDATE THIS>, which is by default, B<4>. 

If you would like to have the bounced address automatically removed, without any sort of scoring happening, change the B<action> from,

    add_to_score => 'hardbounce_score',

to: 

    unsubscribe_bounced_email => 'from_list'

Also, changing B<from_list>, to B<from_all_lists> will do the trick. 

Here's a schematic of all the different things you can do: 

 {
 rule_name => {
	 Examine => {
		Message_Fields => {
			Status               => qw([    ]), 
			Last-Attempt-Date    => qw([    ]), 
			Action               => qw([    ]), 
			Status               => qw([    ]), 
			Diagnostic-Code      => qw([    ]), 
			Final-Recipient      => qw([    ]), 
			Remote-MTA           => qw([    ]), 
			# etc, etc, etc
			
		},
		Data => { 
			Email => 'is_valid' | 'is_invalid' 
			List  => 'is_valid' | 'is_invalid' 
		}
	},
	Action => { 
	           add_to_score             =>  $x, # where, "$x" is a number
			   unsubscribe_bounced_email => 'from_list' | 'from_all_lists',
	},
 },	

Rules also support the use of regular expressions for matching any of the B<Message_Fields>. 
To tell the parser that you're using a regular expression, make the Message_Field key end in '_regex': 

 'Final-Recipient_regex' => [(qr/RFC822/)], 

=cut

