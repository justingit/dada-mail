#!/usr/bin/perl
use strict; 
$ENV{PATH} = "/bin:/usr/bin"; 
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};


# make sure the DADA lib is in the lib paths!
use lib qw(../ ../DADA/perllib ../../../../perl ../../../../perllib); 

use CGI::Carp "fatalsToBrowser"; 


# use some of those Modules
use DADA::Config 3.0.0 qw(!:DEFAULT);
use DADA::Template::HTML; 
use DADA::App::Guts;
use DADA::MailingList::Settings; 
use DADA::Logging::Clickthrough; 
use DADA::MailingList::Archives; 


$|++;

# we need this for cookies things
use CGI; 
my $q = new CGI; 
   $q->charset($DADA::Config::HTML_CHARSET);
   $q = decode_cgi_obj($q);

my $URL = $q->url; 



my %Global_Template_Options = (
		#debug             => 1, 		
		path              => [$DADA::Config::TEMPLATES],
		die_on_bad_params => 0,									
);



my ($admin_list, $root_login) = check_list_security(-cgi_obj  => $q,  
                                                    -Function => 'clickthrough_tracking');
my $list = $admin_list; 

my $ls = DADA::MailingList::Settings->new({-list => $list}); 
my $li = $ls->get; 

my $rd  = DADA::Logging::Clickthrough->new({-list => $list});
my $mja = DADA::MailingList::Archives->new({-list => $list}); 



my $f = $q->param('f') || undef; 

my %Mode = ( 
'default'  => \&default, 
'm'        => \&message_report, 
'url'      => \&url_report, 
'edit_prefs' => \&edit_prefs,
'raw'      => \&raw, 
'purge'    => \&purge, 

); 

if($f){ 
	if(exists($Mode{$f})) { 
		$Mode{$f}->();  #call the correct subroutine 
	}else{
		&default;
	}
}else{ 
	&default;
}
                              
# header     
sub default {

    my $tmpl = '<!-- tmpl_set name="title" value="Clickthrough Tracking" -->';
    if ( $q->param('done') == 1 ) {
        $tmpl .=
          '<p class="positive">' . $DADA::Config::GOOD_JOB_MESSAGE . '</p>';
    }

    if ( -e $rd->clickthrough_log_location ) {

        $tmpl .= $q->h2('Clickthrough Message Summaries:');

        my $m_report = $rd->report_by_message_index;

        $tmpl .=
'<div style="max-height: 300px; overflow: auto; border:1px solid black">';

        $tmpl .= $q->start_table(
            {
                -cellpadding => "5",
                -cellspacing => "0",
                border       => "0",
                width        => "100%"
            }
        );
        $tmpl .= $q->Tr(
            $q->td(
                [
                    ( $q->p( $q->b('Subject') ) ),
                    ( $q->p( $q->b('Sent') ) ),

                    ( $q->p( $q->b('Subscribers') ) ),
                    ( $q->p( $q->b('Clickthroughs') ) ),

                    ( $q->p( $q->b('Opens') ) ),

                    ( $q->p( $q->b('Bounces') ) ),

                ]
            )
        );

        my $archive_entries = $mja->get_archive_entries();

        my $count = 0;
        my $bg;

        #for(@$archive_entries){

        for ( sort { $a <=> $b } keys %$m_report ) {

            if ( $count % 2 == 0 ) {
                $bg = '#ccf';
            }
            else {
                $bg = '#fff';
            }
            $count++;

            if ( !$m_report->{$_}->{message_subject} ) {
                if ( $mja->check_if_entry_exists($_) ) {
                    $m_report->{$_}->{message_subject} =
                      $mja->get_archive_subject($_);
                }
            }

            $m_report->{$_}->{count} = '-' if !$m_report->{$_}->{count};

            $m_report->{$_}->{'open'} = '-' if !$m_report->{$_}->{'open'};

            $m_report->{$_}->{'bounce'} = '-' if !$m_report->{$_}->{'bounce'};
            $m_report->{$_}->{'num_subscribers'} = '-'
              if !$m_report->{$_}->{'num_subscribers'};

            $tmpl .= $q->Tr(
                { -style => 'background: ' . $bg },
                $q->td(
                    [
                        (
                            $q->p(
                                $q->strong(

                                    (
                                        ( $m_report->{$_}->{message_subject} )
                                        ? (
                                            $q->a(
                                                {
                                                    -href =>
                                                      $DADA::Config::S_PROGRAM_URL
                                                      . '?f=view_archive&id='
                                                      . $_
                                                },
                                                $m_report->{$_}
                                                  ->{message_subject}
                                            )
                                          )
                                        : ($_)
                                    )

                                )
                            )
                        ),

                        (
                            $q->p(
                                DADA::App::Guts::date_this(
                                    -Packed_Date => $_
                                )
                            )
                        ),

                        (
                            $q->p(

                                $q->a(
                                    { -href => $URL . '?f=m&mid=' . $_ },

                                    $m_report->{$_}->{'num_subscribers'}

                                )
                            )
                        ),

                        (
                            $q->p(

                                $q->a(
                                    { -href => $URL . '?f=m&mid=' . $_ },

                                    $m_report->{$_}->{count}

                                )
                            )
                        ),

                        (
                            $q->p(

                                $q->a(
                                    { -href => $URL . '?f=m&mid=' . $_ },

                                    $m_report->{$_}->{'open'}

                                )
                            )
                        ),
                        (
                            $q->p(

                                $q->a(
                                    { -href => $URL . '?f=m&mid=' . $_ },

                                    $m_report->{$_}->{'bounce'}

                                )
                            )
                        ),

                    ]
                )
            );
        }

        $tmpl .= $q->end_table;
        $tmpl .= '</div>';

    }
    else {
        $tmpl .= $q->p( $q->strong('No logs to report.') );
    }

    $tmpl .= $q->hr;

    require HTML::Template;

    $tmpl .= prefs_form();

    $tmpl .= $q->hr;

    $tmpl .= $q->p(
        { -align => 'center' },
        $q->start_form() 
          . $q->hidden( 'f', 'raw' )
          . $q->submit(
            -name  => 'View Raw Clickthrough Logs',
            -class => 'processing'
          )
          . $q->end_form()
    );

    $tmpl .= $q->p(
        { -align => 'center' },
        $q->start_form 
          . $q->hidden( 'f', 'purge' )
          . $q->submit(
            -name  => 'Purge Clickthrough Logs',
            -class => 'alertive'
          )
          . $q->end_form()
    );

    $tmpl .= $q->hr;

    $tmpl .= $q->p(
        'Clickthrough logging works for URLs in mailing list
	             messages when the URLs are
				 placed in the [redirect] tag. For example:'
    ) . $q->p( $q->strong('<!-- tmpl_var LEFT_BRACKET -->redirect=http://yahoo.com<!-- tmpl_var RIGHT_BRACKET -->') );


	require DADA::Template::Widgets; 
	my $scrn = DADA::Template::Widgets::wrap_screen(
		{ 
			-data => \$tmpl, 
			-with => 'admin', 
			-wrapper_params => {
                -Root_Login => $root_login,
                -List       => $li->{list},
 	           },
			-vars => { 
				clickthrough_tracking           => $li->{clickthrough_tracking},
		        enable_open_msg_logging         => $li->{enable_open_msg_logging},
		        enable_subscriber_count_logging => $li->{enable_subscriber_count_logging},
		        enable_bounce_logging           => $li->{enable_bounce_logging},
	
			},
		}
	);
    e_print($scrn);

}

sub raw { 


	my $header  = 'Content-disposition: attachement; filename=' . $list . '-clickthrough.log' .  "\n"; 
	   $header .= 'Content-type: text/plain' . "\n\n"; 
	print $header; 
      $rd->print_raw_logs; 
} 


sub purge { 
	unlink($rd->clickthrough_log_location);
	print $q->redirect(-uri => $URL); 
}





sub edit_prefs {

    $ls->save_w_params(
        {
            -associate => $q,
            -settings  => {
                clickthrough_tracking           => 0,
                enable_open_msg_logging         => 0,
                enable_subscriber_count_logging => 0,
                enable_bounce_logging           => 0,
            }
        }
    );

    print $q->redirect( -uri => $URL . '?done=1' );
}


sub message_report {

    my $tmpl =
'<!-- tmpl_set name="title" value="Clickthrough Tracking - Message Report" -->';

    $tmpl .= $q->p(
        $q->strong('Clickthrough Message Summary for: ')
          . $q->a(
            {
                    -href => $DADA::Config::S_PROGRAM_URL
                  . '?flavor=view_archive&id='
                  . $q->param('mid')
            },
            find_message_subject( $q->param('mid') )
          )
    );

    my $m_report = $rd->report_by_message( $q->param('mid') );

    $tmpl .= $q->start_table( { -cellpadding => 5 } );
    for ( sort keys %$m_report ) {

        next
          if ( $_ eq 'open'
            || $_ eq 'num_subscribers'
            || $_ eq 'bounce'
            || $_ eq undef );

        $tmpl .= $q->Tr(
            $q->td(
                [
                    (
                        $q->p(
                            $q->b(
                                $q->a(
                                    {
                                            -href => $URL
                                          . '?f=url&mid='
                                          . $q->param('mid') . '&url='
                                          . uriescape($_)
                                    },
                                    $_
                                )
                            )
                        )
                    ),
                    ( $m_report->{$_}->{count} ),

                ]
            )
        );
    }

    $tmpl .= $q->end_table;

    if ( $m_report->{num_subscribers} ) {
        $tmpl .=
          $q->p($q->strong("Number of Subscribers:")
              . $m_report->{num_subscribers} );
    }

    if ( $m_report->{'open'} ) {
        $tmpl .=
          $q->p(
            $q->strong("Number of Recorded Opens: ") . $m_report->{'open'} );
    }

    if ( $m_report->{bounce} ) {
        $tmpl .=
          $q->p( $q->strong("Number of Recorded Bounces: ")
              . ( $#{ $m_report->{bounce} } + 1 ) );

        my $count = 0;
        my $bg;

        $tmpl .=
'<div style="max-height: 200px; overflow: auto; border:1px solid black">';

        $tmpl .= $q->start_table(
            {
                -cellpadding => "5",
                -cellspacing => "0",
                border       => "0",
                width        => "100%"
            }
        );

        for ( @{ $m_report->{bounce} } ) {

            if ( $count % 2 == 0 ) {
                $bg = '#ccf';
            }
            else {
                $bg = '#fff';
            }
            $count++;

            $tmpl .= $q->Tr( { -style => 'background: ' . $bg },
                $q->td( [ $q->p($_) ] ) );

        }
        $tmpl .= $q->end_table;

    }
    $tmpl .= '</div>';

    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $li->{list},
            },

        }
    );
 	e_print($scrn);

}


sub url_report {

    my $tmpl =
'<!-- tmpl_set name="title" value="Clickthrough Tracking - URL Report" -->';

    $tmpl .= $q->p(
        $q->b(
                'Clickthrough Message Summary for: '
              . find_message_subject( $q->param('mid') )
              . ', for URL: '
              . $q->param('url')
        )
    );

    my $m_report = $rd->report_by_url( $q->param('mid'), $q->param('url') );

    $tmpl .= $q->p( $q->b('Clickthrough Time:') ) . $q->hr;

    $tmpl .= $q->start_table( { -cellpadding => 5 } );
    for ( sort { $a <=> $b } @$m_report ) {
        $tmpl .= $q->Tr( $q->td( $q->p( $q->b($_) ) ) );
    }

    $tmpl .= $q->end_table;
    require DADA::Template::Widgets;
    my $scrn = DADA::Template::Widgets::wrap_screen(
        {
            -data           => \$tmpl,
            -with           => 'admin',
            -wrapper_params => {
                -Root_Login => $root_login,
                -List       => $li->{list},
            },

        }
    );

    e_print($scrn);

}


sub find_message_subject { 
	my $mid = shift; 
	if($mja->check_if_entry_exists($mid)){ 
	    return  $mja->get_archive_subject($mid) || '#' . $mid;
	} else { 
	    return '#' . $mid;
	}
}



sub prefs_form { 

return qq{ 


<form method="get"> 
<input type="hidden" name="f" value="edit_prefs" /> 
<table> 
 <tr> 
  <td> 
   <p>
    <input type="checkbox" name="clickthrough_tracking" id="clickthrough_tracking"  value="1" <!-- tmpl_if clickthrough_tracking -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="clickthrough_tracking"> 
     Enable Clickthrough Tracking
    </label> 
   </p>
  </td>
  </tr> 
  
  
   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_open_msg_logging" id="enable_open_msg_logging"  value="1" <!-- tmpl_if enable_open_msg_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_open_msg_logging"> 
     Enable Open Messages Logging
    </label> 
   </p>
  </td>
  </tr> 


 <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_subscriber_count_logging" id="enable_subscriber_count_logging"  value="1" <!-- tmpl_if enable_subscriber_count_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_subscriber_count_logging"> 
     Enable Subscriber Count Logging
    </label> 
   </p>
  </td>
  </tr> 
  
  
   <tr> 
  <td> 
   <p>
    <input type="checkbox" name="enable_bounce_logging" id="enable_bounce_logging"  value="1" <!-- tmpl_if enable_bounce_logging -->checked="checked"<!--/tmpl_if --> 
   </p>
  </td> 
  <td> 
   <p>
    <label for="enable_bounce_logging"> 
     Enable Bounce Logging
    </label> 
   </p>
  </td>
  </tr>
  
  
 </table> 
   <div class="buttonfloat">
   
 <input type="submit" class="processing" value="Save Clickthrough Preferences" /> 
 </div>
	 <div class="floatclear"></div>

</form> 

}; 

}

=pod

=head1 Clickthrough Tracking - clickthrough_tracking.cgi

clickthrough_tracking.cgi gives you the ability to track:

=over

=item * How many times certain urls are clicked on in your list messages

=item * How many times a message is opened

=item * How many subscribers are present every time a message is sent

=item * "Hard" email Bounces

=back

=head1 Obtaining The Program

The Click Through Tracking plugin can be found in the Magicbook distribution in the, B<plugins> 
directory. 

=head1 Installing clickthrough_tracking.cgi

clickthrough_tracking.cgi should be installed into your dada/plugins directory. Upload the script and change it's permissions to 755. 

Add this entry to the $ADMIN_MENU array ref:

	 {-Title          => 'Clickthrough Tracking', 
	  -Title_URL      => $PLUGIN_URL."/clickthrough_tracking.cgi",
	  -Function       => 'clickthrough_tracking',
	  -Activated      => 1, 
	  },

It's possible that this has already been added to $ADMIN_MENU and all
you would need to do is uncomment this entry.


=head1 Using clickthrough_tracking.cgi

=head2 Creating clickthrough tracking links

Clickthrough tracking works by passing the URL you want to track to a script that keeps track of what URL gets clicked when, then redirecting the user to the real URL. 

To use the clickthrough tracking capabilities, first visit clickthrough_tracking.cgi in your web browser and check, B<Enable Clickthrough Tracking > 

When you write a list message use the special [redirect] tag, instead of just a URL: 

B<Instead of:>

	http://yahoo.com

B<Write:>

    [redirect=http://yahoo.com]

If you're are writing an HTML message, 

B<Instead of:>

	<a href="http://yahoo.com">http://yahoo.com</a>

B<Write:>

	<a href="[redirect=http://yahoo.com]">http://yahoo.com</a>

Make sure: 

=over

=item * You do not put quotes around the URL in the [redirect] tag: 

B<NO!>

 [redirect="http://yahoo.com"]

B<Yes!>

 [redirect=http://yahoo.com]

=item * You do not forget the I<http://> part of the URL:

B<NO!>

 [redirect=yahoo.com]

B<Yes!> 

  [redirect=http://yahoo.com]

If you want, you can use any protocal you want, be it http, ftp, ical, etc.

=back


=head2 Using Open Messages Logging

Be sure to check, B<Enable Open Messages Logging>

Please understand what this feature does - and does not do. 

When this option is checked, Dada Mail will track each time an email message is opened by a mail reader as long as: 

=over

=item * The message is formatted in HTML

PlainText messages cannot be tracked.

=item * The mail reader being used to view your list message has not disabled image viewing 

=back

Even if all these conditions are met, opens may not be logged correctly. Saying all this, you B<should not> use this feature as a hard statistical number, but rather as a sort of barometer of how many people I<may> be reading your message. 

Viewing the message in Dada Mail's own archives will not be tracked. 

The Open Message Logger only logs: 

=over

=item * The list the message was sent from 

=item * The, "Message-ID" of the message itself

=item * The time the message was opened. 

=back

The Open Message Logger DOES NOT log: 

=over

=item * The email address associated with the opening

=item * The IP address associated with the opening

=item * Any other information that can be used to associate a open with a specific subscriber of your list

=back

We find the B<extremely important> that no personal information is tracked. It's not something we'd personally want tracked if we were to be a subscriber to a mailing list.

To clarify how the message opener works, Dada Mail inserts a small image into the source of your HTML message. It looks something like this: 

 <!--open_img-->
 <img src="example.com/cgi-bin/dada/mail.cgi/spacer_image/listshortname/1234/spacer.png" />
 <!--/open_img-->

Where, B<listshortname> is your List Short Name and, B<1234> is the Message-ID.

In our testing using SpamAssassin, this does not raise any flags with its mail filters, but please run your own tests to make sure that your subscribers will still receive your messages.

=head2 Using Subscriber Count Logging

Check, B<Enable Subscriber Count Logging> 

That's it! Nothing more has to be done. 

=head2 Using "Hard" email Bounces Logging

If you have the, Mystery Girl Bounce Handler installed, just check, 

B<Enable Bounce Logging> 

To clarify what this tells you - a brief tutorial on how messages are bounced: 

There are roughly two different types of bounced messages: "soft" bounces - bounces that happen because a mailbox is full, or there's some sort of problem with mail delivery and, "hard" bounces - bounces because the subscriber's mail box just doesn't exist. 

In the context of this tracker, only bounce emails that cause the Mystery Girl bounce handler to remove the address from the subscription list are counted. 

This means, you may receive 100 bounces from your list, but only 10 that will be unsubscribed. Ten bounces will be shown to you when you view the logs. 




=head1 Viewing Clickthrough Information

After a mailing list message has been sent out, the reports may be viewed by visiting clickthrough_tracking.cgi in your browser. 

=head1 FAQ

=over

=item * Does the clickthrough log save which subscriber (email address) clicks on which link?

B<No.> Email addresses aren't saved in the clickthrough logs. The clickthrough tracking is not meant to track individual users, but to get a general idea on what, if any, links people follow from email messages. 

Although the power of being able to track individual subscribers is great, it's also important to remember about people's privacy.

=item * Why are some of my message subjects in the reports a string of numbers? 

If you have deleted the archive entry associated with the message, or don't have archiving turned on, The tracking reports will use the message id associated with the mailing list message you're looking at. 

=item * Where are the clickthrough logs being written? 

Clickthrough logs are named B<listshortname-clickthrough.log>, where I<listshortname> is the list's shortname. 

These files are written in whatever directory you set the $LOGS variable to. If you haven't set the $LOGS variable, they'll get written wherever the $FILES variable is set to. 

=item * What else can I do with the logs? 

You can also fetch the raw clickthrough logs and open them up in a spreadsheet application, such as Excel and create your own reports from them.


=back


=head1 COPYRIGHT 

Copyright (c) 1999 - 2008 

Justin Simoni

http://justinsimoni.com

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


