package DADA::MailingList::Settings; 
use strict;
use lib qw(./ ../ ../../ ../../DADA ../perllib); 

use Carp qw(croak carp); 

my $type; 
my $backend; 
use DADA::Config qw(!:DEFAULT); 	
use DADA::App::Guts; 

BEGIN { 
	$type = $DADA::Config::SETTINGS_DB_TYPE;
	if($type eq 'SQL'){ 
	 	if ($DADA::Config::SQL_PARAMS{dbtype} eq 'mysql'){ 
			$backend = 'MySQL';
		}
		elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'Pg'){ 		
				$backend = 'PostgreSQL';
		}
		elsif ($DADA::Config::SQL_PARAMS{dbtype} eq 'SQLite'){ 
			$backend = 'SQLite';
		}
	}
	elsif($type eq 'Db'){ 
		$backend = 'Db'; 
	}
	else { 
		die "Unknown \$SETTINGS_DB_TYPE: '$type' Supported types: 'Db', 'SQL'"; 
	}
}
use base "DADA::MailingList::Settings::$backend";


sub _init  { 
    my $self   = shift; 
	my ($args) = @_; 

	
    if($args->{-new_list} == 1){ 
	
		$self->{name} = $args->{-list};
		# $self->{local_li} = $self->get;
		# warn 'in init: $args->{-list} ' . $args->{-list}; 	
	}else{ 
		
		if($self->_list_name_check($args->{-list}) == 0) { 
    		croak('BAD List name "' . $args->{-list} . '" ' . $!);
		}
		else { 
			#$self->{local_li} = $self->get; 
		}		
		
	}

}




sub get { 
	
	my $self = shift; 
	my %args = (
	    -Format => "raw", 
	    -dotted => 0, 
	    @_
	); 

	$self->_raw_db_hash;
	
	my $ls                   = $self->{RAW_DB_HASH}; 
	
	$ls = $self->post_process_get($ls, {%args});
	
	if($args{-dotted} == 1){ 
        my $new_ls = {}; 
        while (my ($k, $v) = each(%$ls)){
            $new_ls->{'list_settings.' . $k} = $v; 
        }
        # Will $ls undef every ref to it to?!
        #undef($ls); 
        
        return $new_ls; 

	}
	else { 
			
	    return $ls; 
    }
}




sub post_process_get {

    my $self = shift;
    my $li   = shift;
    my $args = shift;

    carp "$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! List "
      . $self->{function}
      . " db empty!  List setting DB Possibly corrupted!"
      unless keys %$li;

    carp
"$DADA::Config::PROGRAM_NAME $DADA::Config::VER warning! no listshortname saved in list "
      . $self->{function}
      . " db! List "
      . $self->{function}
      . " DB Possibly corrupted!"
      if !$li->{list};

    carp "listshortname in db, '"
      . $self->{name}
      . "' does not match saved list shortname: '"
      . $li->{list} . "'"
      if $self->{name} ne $li->{list};

    if ( $args->{-Format} ne 'unmunged' ) {
        $li->{charset_value} = $self->_munge_charset($li);
        $li = $self->_munge_for_deprecated($li);

        if ( !exists( $li->{list_info} ) ) {
            $li->{list_info} = $li->{info};
        }

        # sasl_smtp_password
        # pop3_password

        # If we don't need to load, DADA::Security::Password, let's not.

        my $d_password_check = 0;
        for ( 'sasl_smtp_password', 'pop3_password',
            'discussion_pop_password' )
        {
            if (   exists( $DADA::Config::LIST_SETUP_DEFAULTS{$_} )
                || exists( $DADA::Config::LIST_SETUP_OVERRIDES{$_} ) )
            {
                $d_password_check = 1;
                require DADA::Security::Password;
                last;
            }
        }

        for ( 'sasl_smtp_password', 'pop3_password',
            'discussion_pop_password' )
        {

            if ( $DADA::Config::LIST_SETUP_OVERRIDES{$_} ) {

                $self->{orig}->{LIST_SETUP_OVERRIDES}->{$_} =
                  $DADA::Config::LIST_SETUP_OVERRIDES{$_};
                $DADA::Config::LIST_SETUP_OVERRIDES{$_} =
                  DADA::Security::Password::cipher_encrypt( $li->{cipher_key},
                    $DADA::Config::LIST_SETUP_OVERRIDES{$_} );
                next;
            }

            if ( $DADA::Config::LIST_SETUP_DEFAULTS{$_} ) {
                if ( !$li->{$_} ) {
                    $self->{orig}->{LIST_SETUP_DEFAULTS}->{$_} =
                      $DADA::Config::LIST_SETUP_DEFAULTS{$_};
                    $DADA::Config::LIST_SETUP_DEFAULTS{$_} =
                      DADA::Security::Password::cipher_encrypt(
                        $li->{cipher_key},
                        $DADA::Config::LIST_SETUP_DEFAULTS{$_} );
                }
            }
        }

        for ( keys %$li ) {
            if ( exists( $li->{$_} ) ) {

                if ( !defined( $li->{$_} ) ) {

                    delete( $li->{$_} );
                }
            }
        }

        for ( keys %DADA::Config::LIST_SETUP_DEFAULTS ) {

            if ( !exists( $li->{$_} ) || length( $li->{$_} ) == 0 ) {
                $li->{$_} = $DADA::Config::LIST_SETUP_DEFAULTS{$_};
            }
        }

        $DADA::Config::SUBSCRIPTION_QUOTA ||= undef;

        if (   $DADA::Config::SUBSCRIPTION_QUOTA
            && $li->{subscription_quota}
            && ( $li->{subscription_quota} > $DADA::Config::SUBSCRIPTION_QUOTA )
          )
        {
            $li->{subscription_quota} = $DADA::Config::SUBSCRIPTION_QUOTA;
        }

        for ( 'sasl_smtp_password', 'pop3_password',
            'discussion_pop_password' )
        {
            if ( $DADA::Config::LIST_SETUP_OVERRIDES{$_} ) {
                $DADA::Config::LIST_SETUP_OVERRIDES{$_} =
                  $self->{orig}->{LIST_SETUP_OVERRIDES}->{$_};
            }

            if ( $DADA::Config::LIST_SETUP_DEFAULTS{$_} ) {
                $DADA::Config::LIST_SETUP_DEFAULTS{$_} =
                  $self->{orig}->{LIST_SETUP_DEFAULTS}->{$_};
            }
        }
    }

    # And then, there's this:
    # DEV: Strange, that it's been left out? Did it get removed?
    for ( keys %DADA::Config::LIST_SETUP_OVERRIDES ) {
        next if $_ eq 'sasl_smtp_password';
        next if $_ eq 'pop3_password';
        next if $_ eq 'discussion_pop_password';
        $li->{$_} = $DADA::Config::LIST_SETUP_OVERRIDES{$_};
    }

    if ( !exists( $li->{admin_email} ) ) {
        $li->{admin_email} = $li->{list_owner_email};
    }
    elsif ( $li->{admin_email} eq undef ) {
        $li->{admin_email} = $li->{list_owner_email};
    }

    if ( $DADA::Config::ENFORCE_CLOSED_LOOP_OPT_IN != 1 ) {
		# ... 
    }
	else { 
	    $li->{enable_closed_loop_opt_in}            = 1;
        $li->{enable_mass_subscribe}                = 0;
		$li->{allow_admin_to_subscribe_blacklisted} = 0; 
		$li->{skip_sub_confirm_if_logged_in}        = 0;	
	}
    return $li;

}




sub params { 
	
	my $self = shift; 
	
	if(keys %{$self->{local_li}}){ 
		#... 
	}
	else { 
		$self->{local_li} = $self->get; 
	}
	
	return $self->{local_li};
	
}



sub param { 
	
	my $self  = shift; 
	my $name  = shift  || undef; 
	my $value = shift;
	
	if(!defined($name)){ 
		croak "You MUST pass a name as the first argument!"; 
	}
	
	if(keys %{$self->{local_li}}){ 
		#warn "$name is cached, using cached stuff." ;
		#... 
	}
	else { 
		#warn "$name is NOT cached, fetching new stuff" ;
		$self->{local_li} = $self->get; 
	}
	
	if(defined($value)){ 
		
		if(!exists($DADA::Config::LIST_SETUP_DEFAULTS{$name})){ 
			croak "Cannot call param() on unknown setting, '$name'"; 
		}
		else { 
				
			$self->save({$name => $value});
			$self->{local_li} = {};
			return $value; # or... what should I return?
		}
	}
	else { 
	
		# Why wasn't this here before?
		#
		if(!exists($DADA::Config::LIST_SETUP_DEFAULTS{$name})){ 
			croak "Cannot call param() on unknown setting, '$name'"; 
		}
	
		return $self->{local_li}->{$name};
		
	}
	
	
}

sub x_message_body_content { 
	my $self = shift; 
	my $type = shift || undef; 
	die '$type cannot be undef!' 
		if $type eq undef;  
	my $param_name = ''; 
	if($type =~ m/html/i){ 
		$param_name = 'default_html_message_content'
	}
	else { 
		$param_name = 'default_plaintext_message_content'; 
	}
	
	my $str = '';
	if($self->param($param_name . '_src') eq 'url_or_path'){ 
		if(isa_url($self->param($param_name . '_src_url_or_path'))){ 
			grab_url($self->param($param_name . '_src_url_or_path'));
		}
		elsif(-e $self->param($param_name . '_src_url_or_path')){ 
			my $fn = make_safer($self->param($param_name . '_src_url_or_path')); 
			my $d = undef; 
			eval { $d  = slurp($fn); }; 
			if($@){ 
				carp $@;
				return '';  
			}
			else { 
				return $d; 
			}
		}
		else { # 'default'
			return ''; 
		}
	}
	else { 
		my $fn; 
		if($type =~ m/html/i){ 
			$fn = $DADA::Config::TEMPLATES . '/' . $param_name . '-' . $self->{name} . '.html'; 
		}
		else { 
			$fn = $DADA::Config::TEMPLATES . '/' . $param_name . '-' . $self->{name} . '.txt'; 
		}
		$fn = make_safer($fn);  
		if(-e $fn){
			eval { $str = slurp($fn); }; 
			if($@){ 
				carp $@;
				return '';  
			}
			else { 
				return $str; 
			}
		} 
		return $str
	}

}
sub plaintext_message_body_content { 
	my $self = shift; 
	return $self->x_message_body_content('plaintext');
}
sub html_message_body_content { 
	my $self = shift; 
	return $self->x_message_body_content('html');
}


sub save_w_params {

    my $self      = shift;
    my ($args)    = @_;
    my $associate = undef;
    my $settings  = {};

    if ( !exists( $args->{-associate} ) ) {
        croak(
'you\'ll need to pass a Perl object with a compatible, param() method in "-associate"'
        );
    }
    if ( !exists( $args->{-settings} ) ) {
        croak(
'you\'ll need to pass what you want to save in the, "-settings" param as a hashref'
        );
    }

    $associate = $args->{-associate};
    $settings  = $args->{-settings};

    my $saved_settings = {};

    for my $setting (keys %$settings) {

        # is it here?
        if ( defined( $associate->param($setting) ) ) {
			if($associate->param($setting) ne '') { 
            	$saved_settings->{$setting} = $associate->param($setting);
			}
			else { 
            	$saved_settings->{$setting} = $settings->{$setting};				
			}
        }
        else {

            # fallback
			# not checking for defined-ness here, since the value could be, "undef"
            $saved_settings->{$setting} = $settings->{$setting};
        }

        # This is probably a good place to check that the variable is actually
        # a valid value.
    }

#	use Data::Dumper; 
#	croak Data::Dumper::Dumper($saved_settings); 

    return $self->save($saved_settings);
	
}





sub _existence_check { 

    my $self = shift; 
    my $li   = shift; 
    
    for(keys %$li){ 
        #next if $_ eq 'list';
        
        if(!exists($DADA::Config::LIST_SETUP_DEFAULTS{$_})){ 
        
            croak("Attempt to save a unregistered setting - $_"); 
        
        }
           
    }



}




sub _munge_charset { 
	my ($self, $li) = @_;
	
	
	if(!exists($li->{charset})){ 
	   $li->{charset} =  $DADA::Config::LIST_SETUP_DEFAULTS{charset};
	    
	}
	
	my $charset_info = $li->{charset};
	my @labeled_charsets = split(/\t/, $charset_info);	
	return $labeled_charsets[$#labeled_charsets];      

}



sub _munge_for_deprecated { 
	
	my ($self, $li) = @_; 
	$li->{list_owner_email} ||= $li->{mojo_email};
#    $li->{admin_email}      ||= $li->{list_owner_email}; 
  
    $li->{privacy_policy}   ||= $li->{private_policy};
  
	#we're talkin' way back here..
	
	if(!exists($li->{list_name})){ 
		$li->{list_name} = $li->{list}; 
		$li->{list_name} =~ s/_/ /g;
	}
	
	return $li; 
}




sub _trim { 
	my ($self, $s) = @_;
	return DADA::App::Guts::strip($s);
}





1; 

=head1 NAME

DADA::MailingList::Subscribers - API for the Dada Mailing List Settings

=head1 SYNOPSIS

 # Import
 use DADA::MailingList::Settings; 
 
 # Create a new object
  my $ls = DADA::MailingList::Settings->new(
           		{ 
					-list => $list, 
				}
			);
 
	# A hashref of all settings
	my $li = $ls->get; 
	print $li->{list_name}; 
 	
 
 
	# Save a setting
	$ls->save(
		{
			list_name => "my list", 
		}
	);
 
 # save a setting, from a CGI paramater, with a fallback variable: 
 $ls->save_w_params(
	-associate => $q, # our CGI object
	-settings  => { 
		list_name => 'My List', 
	}
 ); 
 
 
  # get one setting
  print $ls->param('list_name'); 
 
 
 
 #save one setting: 
 $ls->param('list_name', "My List"); 
  
 
 # Another way to get all settings
 my $li = $ls->params; 


=head1 DESCRIPTION

This module represents the API for Dada Mail's List Settings. Each DADA::MailingList::Settings object represents ONE list. 

Dada Mail's list settings are basically the saved values and preferences that 
make up the, "what" of your Dada Mail list. The settings hold things like the name of your list, the description, as well as things like email sending options.  

=head2 Mailing List Settings Model

Settings are saved in a key/value pair, as originally, the backend for all this was a dn file - and still is, for the default backend. This module basically manipulates that key/value hash. Very simple. 

=head2 Default Values of List Settings

The default value of B<ALL> list settings are saved currently in the I<Config.pm> file, in the variable, C<%LIST_SETUP_DEFAULTS>

This module will make sure you will not attempt to save an unknown list setting in the C<save> method, as well when calling C<param> with either one or two arguments. 

The error will be fatal. This may seem rash, but many bugs surface just because of trying to use a list setting that does not actually exist. 

The C<get> method is NOT guaranteed to give back valid list settings! This is a known issue and may be fixed later, after backwards-compatibility problems are assessed. 

=head1 Public Methods

Below are the list of I<Public> methods that we recommend using when manipulating the  Dada Mail List Settings: 

=head2 Initializing

=head2 new

 my $ls = DADA::MailingList::Settings->new({-list => 'mylist'}); 

C<new> requires you to pass a B<listshortname> in, C<-list>. If you don't, your script will die. 

A C<DADA::MailingList::Settings> object will be returned. 

=head2 Getting/Setting Mailing List Paramaters

=head2 get

 my $li = $ls->get; 

There are no public paramaters that we suggest passing to this method. 

This method returns a hashref that contains each and every key/value pair of settings associated with the mailing list you're working with.

This method will grab a fresh copy of the list settings from whatever backend is being used. Because of this, we suggest that instead of using this method, you use the, C<param> or C<params> method, which has caching of this information.  

=head3 Diagnostics

None, really. 

=head2 save

 $ls->save({list_name => 'my new list name'}); 

C<save> accepts a hashref as a paramater. The hashref should contain key/value pairs of list settings you'd like to change. All key/values passed will re-write any options saved. There is no validation of the information you passed. 

DO NOT pass, I<list> as one of the key/value pairs. The method will return an error. 

This method is most convenient when you have many list settings you'd like saved at one time. See the, C<param> method if all you want to do is save one list setting paramater. 

Returns B<1> on success. 


=head2 save_w_params

 $ls->save_w_params(
	-associate => $q, # our CGI object
	-settings  => { 
		list_name => 'My List', 
	}
 ); 

C<save_w_params> allows you to save list settings that are passed in a compatible Perl object (one that has a C<param> method, similar to CGI.pm's)

C<save_w_params> also allows you to pass a fallback value of the list settings you want to save. 

C<-associate> should hold a Perl Object with the compatable, C<param> method (like CGI.pm's C<param> method. B<required> 

C<-settings> should hold a hashref of the fallback values for each list setting you want to save. 

Returns, C<1> on success. 

=head3 Diagnostics

=over

=item * Attempt to save a unregistered setting - 

The actual settings you attempt to save have to actually exist. Make sure the names (keys) of your the list settings you're attempting to pass are valid. 


=back


=head2 param

 # Get a Value
 $ls->param('list_name'); 
 
 # Save a Value
 $ls->param('list_name', 'my new list name'); 

C<param> can be used to get and save  a list setting paramater. 

Call C<param> with one argument to receive the value of the name of the setting you're passing. 

Call C<param> with two arguments - the first being the name of the setting, the second being the value you'd like to save. 

C<param> is something of a wrapper around the C<get> method, but we suggest using C<param> over, C<get> as, C<param> checks the validity of the list setting B<name> that you pass, as well as caching information you've already fetched from the backend.

=head3 Diagnostics

=over

=item * You MUST pass a name as the first argument!

You cannot call, C<param> without an argument. That first argument needs to be the name of the list setting you want to get/set. 

=item * Cannot call param() on unknown setting.

If you do call C<param> with 2 arguments, the first argument has to be the name of a setting tha actual exists. 

=back

For the two argument version of calling this method, also see the, I<Diagnostics> section of the, C<save> method. 

=head2 params

	my $li = $ls->params;

Takes no arguments. 

Returns the exact same thing as the, C<get> method, except does caching of any information fetched from the backend. Because of this, it's suggested that you use C<params>, instead of, C<get> whenever you can. 

=head2 A note about param and params

The name, C<param> and, C<params> is taken from the CGI.pm module: 

Many different modules support passing paramater values to their own methods, as a sort of shortcut. We had this in mind, but we haven't used or tested how compatible this idea is. When and if we do, we'll update the documentation to reflect this. 

=head1 BUGS AND LIMITATIONS

=head1 COPYRIGHT 

Copyright (c) 1999 - 2012 Justin Simoni All rights reserved. 

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, 
Boston, MA  02111-1307, USA.

=cut 
