package DADA::MailingList;

use lib qw(./ ../ ../DADA ../perllib);

use Carp qw(croak carp);

use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(Create Remove);

use strict;
use vars qw(@EXPORT);




sub Create {

	# Init.
    my ($args) = @_;

    if ( !exists( $args->{ -list } )) {
        croak("You must supply a list name in the '-list' parameter.");
    }

    if ( !exists( $args->{ -settings } )) {
        croak("You must supply settings in the '-settings' parameter.");
    }

	if( ! exists($args->{-test})) { 
		$args->{-test} = 1;
	}

    if ( 
		check_if_list_exists( -List => $args->{ -list } ) == 1 
		)
    {
        croak 'The list, ' . $args->{ -list } . ' already exists! ';
    }
	
	# One last check.... 
	if(($args->{-test} == 1)) {	
		my ($errors, $flags) = check_list_setup(
			-fields => 
			{
				%{$args->{-settings}},
				list            => $args->{-list}, 
				retype_password => $args->{-settings}->{'password'},
			}
		); 
		if($errors >= 1){
			my $e = '';
			for(%$flags){ 
				$e .= $_ . ', ' if $flags->{$_} == 1; 
			}
			croak "Problems creating list: " . $e; 
		} 
	}
	# /One last check.... 	

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new(
        {
            -list     => $args->{ -list },
            -new_list => 1,
        }
    );

    unless ( $ls->isa('DADA::MailingList::Settings') ) {
        croak
'DADA::MailingList::Settings did not give back the right kind of object!';
    }

	my $consent = undef; 
	if(defined($args->{ -settings }->{consent})) { 
		$consent = $args->{ -settings }->{consent};
		$consent = strip($consent);
	}
	delete( $args->{ -settings }->{consent} );

    $args->{ -settings }->{list} = $args->{ -list };

    if ( exists( $args->{ -clone } ) ) {
        my $clone_ls =
          DADA::MailingList::Settings->new( { -list => $args->{ -clone }, } );
        my %to_clone = %{ $clone_ls->params };
        for (@DADA::Config::LIST_SETUP_DONT_CLONE) {
            if ( exists( $to_clone{$_} ) ) {
                delete( $to_clone{$_} );
            }
        }
		for(keys %to_clone){
			 if(! exists($DADA::Config::LIST_SETUP_DEFAULTS{$_})){ 
				warn "Skipping setting: $_ in clone."; 
                delete( $to_clone{$_} );
			}
		}
        %{ $args->{ -settings } } = ( %to_clone, %{ $args->{ -settings } } );
    }

    $ls->save({ -settings => $args->{ -settings } });
	
    available_lists( -clear_cache => 1 );
	
	
	#undef $ls; 
	#my $ls = DADA::MailingList::Settings->new({-list => $args->{ -list }});
	
	if(
		  defined($consent) 
		&& length($consent) > 16
	) {
		# Consent!
		require DADA::MailingList::Consents; 
		my $dmlc = DADA::MailingList::Consents->new; 
		my $consent_id = $dmlc->add({ 
			-list    => $args->{ -list }, 
			-consent => $consent, 
		});
		my $frozen_consent = $dmlc->freezish_for_saving([$consent_id]); 
	    $ls->save({ 
			-settings => {
				list_consent_ids => $frozen_consent,
			}
		});
		#/Consent!
	}
	
	# Privacy Policy! 
	require DADA::MailingList::PrivacyPolicyManager; 
	my $ppm = DADA::MailingList::PrivacyPolicyManager->new; 
	$ppm->add(
				{ 
					-list           => $args->{-list}, 
					-privacy_policy => $args->{ -settings }->{privacy_policy},
				}
			); 
	
    available_lists( -clear_cache => 1 );

    return $ls;

}




sub Remove {

    my ($args) = @_;

    if ( !$args->{-name} ) {
        croak("You must supply a list name in the '-name' parameter.");
    }
    
    if(check_if_list_exists(-List => $args->{-name}, -Dont_Die => 1) == 0){ 
        croak 'The list, ' . $args->{-name} . ' does not exists! '; 
    }

    my $list = $args->{-name};

    require DADA::MailingList::Settings;

    my $ls = DADA::MailingList::Settings->new({-list => $list});

    my $li = $ls->get;




	# We have to remove mailouts, now. 
	require DADA::Mail::MailOut; 
	my @mailouts  = DADA::Mail::MailOut::current_mailouts(
						{ 
							-list => $args->{-name},
						}
					);  
    for (@mailouts){
		my $mailout = DADA::Mail::MailOut->new({ -list => $list }); 
           $mailout->associate($_->{id}, $_->{type});
		   $mailout->clean_up; 
	}
	
    require DADA::MailingList::Archives;
    my $la = DADA::MailingList::Archives->new({-list => $list});
    require DADA::MailingList::Subscribers;



    my $lh = DADA::MailingList::Subscribers->new({-list => $list});
    	
    $ls->removeAllBackups();
    $la->removeAllBackups(1);

    #mostly for the SQL backends
	for(keys  %{$lh->get_list_types }){ 
    	$lh->remove_this_listtype({-type => $_});
	}

    $la->delete_all_archive_entries();

    # Nor this...
    delete_list_info( -List => $list );

    # Nor this...
    delete_list_template({ -List => $list });
	
	available_lists(-clear_cache => 1);
	
    require DADA::Logging::Usage;
	
	my $remote_host = exists($ENV{REMOTE_HOST}) ? $ENV{REMOTE_HOST} : ''; 
	my $remote_addr = exists($ENV{REMOTE_ADDR}) ? $ENV{REMOTE_ADDR} : ''; 

    my $log = new DADA::Logging::Usage;
    $log->mj_log( 
        $list, 
        'List Removed',
        'remote_host: ' . $remote_host . 
        ', ip_address: ' . $remote_addr,
     )
        if $DADA::Config::LOG{list_lives};

    return 1;

}

=pod

=head1 NAME

DADA::MailingList - Creates and Removes Dada Mail Mailing Lists

=head1 VERSION

=head1 SYNOPSIS

 use DADA::MailingList; 
 
 my $list = 'foo'; 
 
 
 # Create!
  my $ls = DADA::MailingList::Create(
	{ 
		-list => 'mylist',
		-settings => 
			{
			 	#...
			},
	}
	); 
 
 # $ls is now a DADA::MailingList::Settings object.
 
 # Remove!
 DADA::MailingList::Remove({ -name => 'mylist' }); 

=head1 DESCRIPTION

This module basically either creates, or removes a list. 


=head1 SUBROUTINES

=head2 Create

 my $ls = DADA::MailingList::Create(
	{ 
		-list => 'mylist', 
		-settings => {
				# a bunch of settings!
				}
	}
 );

or even, 

 my $ls = DADA::MailingList::Create(
	{ 
		-list => 'mylist', 
		-settings => {
				# a bunch of settings!
				}
		-clone => 'my_first_list',
	}
 );


Creates all the necessary files for a Dada Mailing List. 

The B<-list> parameter should hold  the 
list shortname of your mailing list - which itself should be no more than 16
characters and should only include letters/numbers.

The, B<-settings> parameter should hold a hashref with the key/values that make 
up your list settings. Only keys that are mentioned in the Config.pm's C<%LIST_SETUP_DEFAULTS>
can be passed - trying to pass keys that aren't mentioned will cause an error. 

The optional, B<-clone> variable will copy list settings from an already existing list, 
to be used in this new list. Settings mentioned in the Config.pm variable, 
C<@LIST_SETUP_DONT_CLONE> will not be copied over. 

This method returns a B<DADA::MailingList::Settings> object.

=head2 Remove

 DADA::MailingList::Remove({ -name => 'mylist'}); 

Removes a Mailing List. the B<-name> parameter is required.
=head1 AUTHOR

Justin Simoni - https://dadamailproject.com/contact

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1999 - 2023 Justin Simoni All rights reserved. 

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

1;
