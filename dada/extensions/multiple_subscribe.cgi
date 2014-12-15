#!/usr/bin/perl 

use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/../DADA/perllib";
BEGIN { 
	my $b__dir = ( getpwuid($>) )[7].'/perl';
    push @INC,$b__dir.'5/lib/perl5',$b__dir.'5/lib/perl5/x86_64-linux-thread-multi',$b__dir.'lib',map { $b__dir . $_ } @INC;
}

use CGI::Carp "fatalsToBrowser";

use strict;

# For testing, set $Debug to 1
my $Debug = 0;

use DADA::Config 7.0.0;
use DADA::App::Guts;
use DADA::MailingList::Subscribers;
use DADA::MailingList::Settings;
use DADA::Template::HTML;
use DADA::Template::Widgets;
use DADA::App::Messages;

#---------------------------------------------------------------------#

use CGI;
my $q = CGI->new();
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);


#---------------------------------------------------------------------#


my $Plugin_Config = {};

$Plugin_Config->{Plugin_Name} = 'Multiple Subscribe';

$Plugin_Config->{Plugin_URL}  = $q->url();



my $email = $q->param('email');
$email = $q->param('e') unless ($email);

my $flavor = $q->param('flavor');
$flavor = $q->param('f') unless ($flavor);

my @unfiltered_lists = $q->param('list');

my $redirect_url = $q->param('redirect_url');

my @available_lists = DADA::App::Guts::available_lists();

my $labels = {};
foreach my $alist (@available_lists) {
    my $als = DADA::MailingList::Settings->new( { -list => $alist } );
    my $ali = $als->get;
    next if $ali->{hide_list} == 1;
    $labels->{$alist} = $ali->{list_name};
}
@available_lists =
  sort { uc( $labels->{$a} ) cmp uc( $labels->{$b} ) } keys %$labels;

my %list_names;

my $ht_lists = [];

my @lists;
foreach (@unfiltered_lists) {
    next if !$_;
    next if $_ eq '';
    push( @lists, $_ );
}

foreach (@available_lists) {
    my $ls = DADA::MailingList::Settings->new( { -list => $_ } );
    my $li = $ls->get;

    if ( $li->{hide_list} ne "1" )
    {    # should we do this here, or in the template?

        my $tmpl_list_information = {};

        $list_names{$_} = $li->{list_name};

        # $l_count++;

        my $html_info = $li->{info};
        $html_info = plaintext_to_html( { -str => $html_info } );

        # Just trying this out...

        for (
            $li->{list_owner_email},
            $li->{admin_email}, $li->{discussion_pop_email},
          )
        {
            if ($_) {
                my $look_e      = quotemeta($_);
                my $protected_e = spam_me_not_encode($_);
                $html_info =~ s/$look_e/$protected_e/g;
            }
        }

        #/ end that...

        $tmpl_list_information->{uri_escaped_list} = uriescape( $li->{list} );
        $tmpl_list_information->{list_name}        = $li->{list_name};
        $tmpl_list_information->{info}             = $li->{info};
        $tmpl_list_information->{html_info}        = $html_info;

        push(
            @$ht_lists,
            {
                PROGRAM_URL => $DADA::Config::PROGRAM_URL,
                list        => $_,
                list_name   => $li->{list_name},
                info        => $li->{list_name},
                %$tmpl_list_information
            }
        );

    }

}

&init_vars; 
&main;

#---------------------------------------------------------------------#

sub init_vars {

# DEV: This NEEDS to be in its own module - perhaps DADA::App::PluginHelper or something?

    while ( my $key = each %$Plugin_Config ) {

        if ( exists( $DADA::Config::PLUGIN_CONFIGS->{multiple_subscribe}->{$key} ) ) {

            if (
                defined( $DADA::Config::PLUGIN_CONFIGS->{multiple_subscribe}->{$key} ) )
            {

                $Plugin_Config->{$key} =
                  $DADA::Config::PLUGIN_CONFIGS->{multiple_subscribe}->{$key};

            }
        }
    }
}




sub main {
    if ( $lists[0] ) {
        subscribe_emails();
    }
    else {
        subscription_form();
    }
}




sub subscription_form {

    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -screen => 'extensions/multiple_subscribe/default.tmpl',
            -with   => 'list',
            -vars   => {
                lists             => $ht_lists,
                email             => $email,
                f                 => $flavor,
                subscription_form => DADA::Template::Widgets::subscription_form(
                    {
                        -multiple_lists => 1,
                        -script_url     => $q->url(),
                        -give_props     => 0
                    }
                ),
                error_invalid_email => $q->param('invalid_email'),

            }
        }
    );
    e_print($scrn);

}

sub subscribe_emails {

    my @lists_worked_on = ();
    my $debug_info      = '';

    #--- debug! --- #

    if ( DADA::App::Guts::check_for_valid_email($email) == 1 ) {
        print $q->redirect( -uri => $q->self_url . '?invalid_email=1' );
        return;
    }

    $debug_info .= "Attempting to Subscribe..."
      if $Debug == 1;

    foreach my $this_list (@lists) {
        my $lh = DADA::MailingList::Subscribers->new( { -list => $this_list } );
        my $ls = DADA::MailingList::Settings->new( { -list => $this_list } );
        my $li = $ls->get;

        my ( $status, $errors ) = $lh->subscription_check(
            {
                -email => $email,
                ( $li->{email_your_subscribed_msg} == 1 )
                ? ( -skip => ['subscribed'], )
                : (),

            },
        );

        my $error_report = [];
        foreach ( keys %$errors ) {
            push( @$error_report, { error => $_ } ) if $errors->{$_} == 1;
        }

        #--- debug! --- #
        $debug_info .=
          $q->h1( "List: '"
              . $this_list
              . "', Email: $email, Status: "
              . $q->b($status) )
          if $Debug == 1;

        if ( $status == 1 ) {

            my $local_q = new CGI;
            $local_q->delete_all();
            $local_q->param( 'list',  $this_list );
            $local_q->param( 'email', $email );
            $local_q->param( 'f',     's' );

            # Hmm. This should take care of that.
            foreach ( @{ $lh->subscriber_fields } ) {
                $local_q->param( $_, $q->param($_) );
            }

            require DADA::App::Subscriptions;
            my $das = DADA::App::Subscriptions->new;

            $das->subscribe(
                {
                    -html_output => 0,
                    -cgi_obj     => $local_q,
                }
            );
        }

        push(
            @lists_worked_on,
            {
                list        => $this_list,
                list_name   => $li->{list_name},
                status      => $status,
                errors      => $error_report,
                PROGRAM_URL => $DADA::Config::PROGRAM_URL
            }
        );

        #}else{
        #--- debug! --- #
        if ( $Debug == 1 ) {
            $debug_info .= $q->h3("Details...");
            $debug_info .= '<ul>';
            foreach my $error ( keys %$errors ) {
                $debug_info .= $q->li($error);
            }
            $debug_info .= '</ul>';
        }
        else {
            # nothing.
        }
    }

    if ($redirect_url) {
        $debug_info .= $q->redirect( -uri => $redirect_url );

        print $q->redirect( -url => $redirect_url );
        return;

    }
    else {

        my $scrn = DADA::Template::Widgets::wrap_screen(
            {
                -screen => 'extensions/multiple_subscribe/request_results.tmpl',
                -with   => 'list',
                -vars   => {
                    lists_worked_on => \@lists_worked_on,
                    email           => $email,
                    f               => $flavor,
                    debug_info      => $debug_info,
                    debug           => $Debug ? 1 : 0,

                },
            }
        );
        e_print($scrn);

    }
}

__END__


=pod

=head1 NAME Multiple Subscribe

=head1 Description

Multiple Subscribe allows a user to subscribe to multiple mailing lists, at once. 

=head1 Obtaining The Extension

Multiple Subscribe is located in the, I<dada/extensions> directory of the Dada Mail distribution, under the name: C<multiple_subscribe.cgi>

=head1 Installation 

This extension can be installed during a Dada Mail install/upgrade, using the included installer that comes with Dada Mail. Under, B<Plugins/Extensions>, check, B<Multiple Subscribe>.

=head1 Manual Installation

=head2 #1 Change the permissions of the, multiple_subscribe.cgi script to, "755"

Find the C<multiple_subscribe.cgi> script in your I<dada/extensions> directory. Change its permissions to, C<755> 

=head2 #2 Configure your outside config file (.dada_config)

You'll most likely want to edit your outside config file (C<.dada_config>)
so that it shows Multiple Subscribe in the left-hand menu, under the, B<Extensions> heading. 

First, see if the following lines are present in your C<.dada_config> file: 

 # start cut for list control panel menu
 =cut

 =cut
 # end cut for list control panel menu

If they are, remove them. 

Then, find these lines: 

	#					{
	#					-Title      => 'Multiple Subscribe',
	#					-Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
	#					-Function   => 'multiple_subscribe',
	#					-Activated  => 1,
	#					},

Uncomment the lines, by taking off the, "#"'s: 

						{
						-Title      => 'Multiple Subscribe',
						-Title_URL  => $EXT_URL."/multiple_subscribe.cgi",
						-Function   => 'multiple_subscribe',
						-Activated  => 1,
						},

Save your C<.dada_config> file. 

You can now log into your List Control Panel and under the, B<Extensions> heading you should now see a link entitled, "Multiple Subscribe". Clicking that link will take you to this extension. 


=head1 Making an HTML form

This script takes three different arguments; B<list>, B<s> and B<email>. You will have to  make an HTML form that will supply this script with these three arguments:

	<form action="http://example.com/cgi-bin/dada/extensions/multiple_subscribe.cgi" method="post"> 
	 <p>Lists:</p> 
	  <input type="checkbox" name="list" value="first_list" /> My first list<br/>
	  <input type="checkbox" name="list" value="second_list" /> My second list<br/>
	  <input type="checkbox" name="list" value="third_list" /> My third list<br/>
	 <p>Your email:<br /> 
	  <input type="text" name="email" />
	 </p>
	 <p>
	 <input type="checkbox" name="f" value="s"> Subscribe!<br /> 
	 </p>
	 <p>
	 <input type="submit" value="Subscribe Me" /> 
	 </p>
	</form> 

You can also view the source of the initial screen of C<multiple_subscribe.cgi>  and copy and paste the form it creates, then make any changes you would like to the HTML source.  

This script also takes an optional argument, B<redirect_url> that you may 
set to any URL where you'd like this script to redirect, once it's done:

	<input type='hidden' name='redirect_url' value='http://mysite.com/thanks.html'>

=head1 DEBUGGING

This script has one variable on top of the script, called B<$Debug>.
You may set this variable to '1' to gain a better insight on what exactly is
happening behind the curtains. 

=head1 COPYRIGHT 

Copyright (c) 1999 - 2014 Justin Simoni All rights reserved. 

To contact info, please see: 

L<http://dadamailproject.com/contact/>

All rights reserved. 

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
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


=cut
