#!/usr/bin/perl
use strict;

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib
);

BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }

use dada_test_config;
use DADA::Logging::Clickthrough;
use DADA::App::Guts;
use DADA::MailingList::Settings;

my $list = dada_test_config::create_test_list;

# Make sure everything is on: 
my $ls = DADA::MailingList::Settings->new( { -list => $list } );
   $ls->save(
	{ 
		tracker_auto_parse_links                            => 1, 
		tracker_track_opens_method                          => 'directly', 

		tracker_record_view_count                           => 10, 
		tracker_clean_up_reports                            => 1, 
		tracker_auto_parse_links                            => 1, 
	    tracker_auto_parse_mailto_links                     => 0, 
		tracker_show_message_reports_in_mailing_monitor     => 0,
	}
); 


my $key; 

my $lc = DADA::Logging::Clickthrough->new( { -list => $list } );
ok( $lc->isa('DADA::Logging::Clickthrough') );

my @redirect_urls = (

'[redirect=http://example.com]',
'[redirect url="http://example.com"]',
'<!-- redirect url="http://example.com" -->',
'<?dada redirect url="http://example.com" ?>',
'<?dada redirect url="http://www.youtube.com/watch?v=AWvBbqpD2Y8" ?>',


'[redirect=mailto:user@example.com]',
'[redirect url="mailto:user@example.com"]',
'<!-- redirect url="mailto:user@example.com" -->',
'<?dada redirect url="mailto:user@example.com" ?>',

); 

foreach(@redirect_urls){ 
	my $pat = $lc->redirect_regex(); 
	ok($_ =~ m/$pat/, "redirect URL looks like one! ($_)"); 
	my $redirect_tag = $1; 
	my $redirect_atts = $lc->get_redirect_tag_atts($redirect_tag); 
	my $url = $redirect_atts->{url}; 
	ok($lc->can_be_redirected($url), "And URL looks redirectable! ($url)");
}




my $test_mid = DADA::App::Guts::message_id();
my $test_url = 'http://example.com/page.html?foo=bar&baz=bing';

my $ran_key = $lc->random_key();
ok( $ran_key > 0 );
ok( length($ran_key) == 12 );

$key = $lc->add( $test_mid, $test_url );

ok( $key > 0, "key > 0!" );
ok( length($key) == 12, "length is 12!" );

my $reuse = $lc->reuse_key( $test_mid, $test_url );

ok( $reuse == $key, "reusing the key!");

my $reuse2 = $lc->reuse_key( 12345678901234, 'http://someotherurl.com' );

ok( $reuse2 eq undef, 'reuse_key is undef.' );

#diag '$test_url:'. $test_url; 
#diag '$test_mid:' . $test_mid; 
my $coded = $lc->redirect_encode( $test_mid, $lc->redirect_tagify($test_url) );
my $looks_like = $DADA::Config::PROGRAM_URL . '/r/' . $list . '/' . $key . '/<!-- tmpl_var subscriber.email_name -->/<!-- tmpl_var subscriber.email_domain -->/';
warn '$coded:'.$coded;
warn '$looks_like;' . $looks_like; 

ok( $coded eq $looks_like, "coded '$coded' looks like: '$looks_like'");

my $coded2 = $lc->redirect_encode( $test_mid, $lc->redirect_tagify('http://someotherurl2.com') );

ok( $coded ne $coded2 );

my $existing  = {};
my $test_url2 = 'http://test.example.com/';




# Make sure we never make the URL twice...
my $i = 0;
for ( $i = 0 ; $i < 50 ; $i++ ) {
    my $l_test_url = $test_url2 . $i;
    my $test_r_url = $lc->redirect_encode( $test_mid, $lc->redirect_tagify($l_test_url) );
    ok( !exists( $existing->{$test_r_url} ) );
    $existing->{$test_r_url} = 1;
}

#diag '$test_url ' . $test_url; 

my $s = '[redirect=' . $test_url . ']';

my $ps = $lc->parse_string( $test_mid, $s );

#diag '$ps ' . $ps;
#diag '$coded ' . $coded; 

# It's the same as before, you see?
ok( $ps eq $coded, "same as before?" );



################################################
# Zee Plain Text!

my $pt_email = <<EOF
From: me\@example.com
To: you\@example.com
Subject: Heya

Blah blah blah Zoink!

$s

Yadda yadda

EOF
  ;

my %dsa = gimme_dada_style_args($pt_email);

my %fields = $lc->parse_email(
    {
        -fields => {%dsa},
        -mid    => $test_mid,
    }
);
my $r_email = string_from_dada_style_args( { -fields => {%fields}, } );

my $qm_coded = quotemeta($coded);
like( $r_email, qr/$qm_coded/ );





#
################################################

################################################
# Zee "HTML"!

my $html_email = <<EOF
From: me\@example.com
To: you\@example.com
Content-type: text/html
Subject: Heya

Blah blah blah Zoink!

<a href="$s">Click Here Please and I will take you to Somewhere!</a> 

Yadda yadda

EOF
  ;

%dsa = gimme_dada_style_args($html_email);

%fields = $lc->parse_email(
    {
        -fields => {%dsa},
        -mid    => $test_mid,
    }
);
$r_email = string_from_dada_style_args( { -fields => {%fields}, } );

$qm_coded = quotemeta($coded);
like( $r_email, qr/$qm_coded/ );

################################################



################################################
# Zee "Multipart/Alternative"!
my $mpalt_email = <<EOF
Content-Transfer-Encoding: binary
Content-Type: multipart/alternative; boundary="_----------=_119838723880110"
MIME-Version: 1.0
Date: Sun, 23 Dec 2007 05:20:38 UT
From: "From" <from\@example.com>
To: "To" <to\@example.com>
Subject: Subject

This is a multi-part message in MIME format.

--_----------=_119838723880110
Content-Disposition: inline
Content-Transfer-Encoding: binary
Content-Type: text/plain

This is the PlainText Ver:
$s

--_----------=_119838723880110
Content-Disposition: inline
Content-Transfer-Encoding: binary
Content-Type: text/html

<p>This is the HTML Ver:</p>
<a href="$s">Click Here</a>

--_----------=_119838723880110--

EOF
  ;

%dsa = gimme_dada_style_args($mpalt_email);

%fields = $lc->parse_email(
    {
        -fields => {%dsa},
        -mid    => $test_mid,
    }
);
$r_email = string_from_dada_style_args( { -fields => {%fields}, } );

$qm_coded = quotemeta($coded);
like( $r_email, qr/$qm_coded/ );

like( $r_email, qr/This is the PlainText Ver\:\n$qm_coded/ );



my $html_check = quotemeta(
    qq{<p>This is the HTML Ver:</p>
<a href="$coded">Click Here</a>}
);

like( $r_email, qr/$html_check/ );



################################################

my ( $r_mid, $r_url ) = $lc->fetch($key);
ok( $r_mid eq $test_mid );
ok( $r_url eq $test_url );


#ok( $lc->clickthrough_log_location eq $DADA::Config::LOGS . '/' . $list
#     . '-clickthrough.log' );
# if it's not on, it returns, "0";
#ok( $lc->r_log({-mid => $test_mid, -url => $test_url }) == 0 );
# This is kinda strange - we have to reinit the object:




# Now, it should do what I want it to do:
ok( $lc->r_log({-mid =>  $test_mid, -url => $test_url }) == 1 );


# purge_log

ok($lc->purge_log == 1, "purging the log returns, '1'"); 
my ($total, $mids) = $lc->get_all_mids(); 
ok($total == 0, "Reporting that we're not reporting anything!"); 
ok(!exists($mids->[0]), "Reporting that we're not reporting anything! (2)");

$test_mid = DADA::App::Guts::message_id();

my $r = $lc->num_subscribers_log(
	{ 
		-mid => $test_mid, 
		-num => 5, 
	}
); 
ok($r == 1, "num_subscribers_log returns 1!"); 

$test_mid = $test_mid + 10; 
$r = $lc->num_subscribers_log(
	{ 
		-mid => $test_mid, 
		-num => 6, 
	}
);
ok($r == 1, "num_subscribers_log returns 1!"); 
($total, $mids) = $lc->get_all_mids(); 

#diag "look!"; 
#
#sleep(60); 

diag 'total ' . $total; 
ok($total == 2, "total is now 2"); 
ok(scalar @$mids, "two logs are being reported back.");

ok($lc->purge_log == 1, "purging the log returns, '1'"); 

# First let's add a new clickthorugh url to track: 
$key = $lc->add(
	12345678901234, 
	'http://example.com'
); 
# Now let's record that we clicked on it: 
my ($mid, $url, $atts) = $lc->fetch($key);
ok($mid == 12345678901234, "message id matches"); 
ok($url eq 'http://example.com', "URL matches"); 
ok($lc->r_log(
	{ 
		-mid => $mid, 
		-url => $url, 
	}
) == 1, "recording the clickthrough was successful"); 



# Now, let's see if we can't track that clickthrough: 
my $r = $lc->num_subscribers_log(
	{ 
		-mid => 12345678901234, 
		-num => 5, 
	}
); 
ok($r == 1, "num_subscribers_log returns 1!");

($total, $mids) = $lc->get_all_mids(); 
ok($total == 1, "total equals 1 ($total)"); 



ok(scalar @$mids == 1); 
ok($mids->[0] == 12345678901234); 
my $report = $lc->report_by_message_index; 
ok($report->[0]->{count} == 1); # that's our click. 

# Don't believe me? 
for(1 .. 100){ 
	$lc->r_log(
	{ 
		-mid => $mid, 
		-url => $url, 
	}); 
}

# See? 101 clicks. 
my $report = $lc->report_by_message_index; 
ok($report->[0]->{count} == 101); # that's our click. um, clicks. 
ok($lc->purge_log == 1, "purging the log returns, '1'"); 

# bounce_log
$lc->bounce_log(
	{ 
	-type  => 'hard', 
	-mid   => 12345678901234,
	-email => 'hardboing@example.com', 
	}
);
# Now, let's see if we can't track that clickthrough: 
my $r = $lc->num_subscribers_log(
	{ 
		-mid => 12345678901234, 
		-num => 5, 
	}
); 
ok($r == 1, "num_subscribers_log returns 1!");
$report = $lc->report_by_message_index; 
ok($report->[0]->{hard_bounce} == 1); 

# bounce_log
$lc->bounce_log(
	{ 
	-type  => 'soft', 
	-mid   => 12345678901234,
	-email => 'softboing@example.com', 
	}
);
$report = $lc->report_by_message_index; 
ok($report->[0]->{hard_bounce} == 1); 
ok($report->[0]->{soft_bounce} == 1); 

# o_log

$lc->open_log(
	{ 
		-mid => 12345678901234,
	}
);
$report = $lc->report_by_message_index; 
ok($report->[0]->{open} == 1);

# Don't believe me? 
for(1 .. 100){ 
	$lc->open_log(
		{ 
			-mid => $mid, 
		}
	); 
}

$report = $lc->report_by_message_index; 
ok($report->[0]->{open} == 101);

# Let's add some clickthroughs, 
ok($lc->r_log(
	{ 
		-mid => 12345678901234, 
		-url => 'http://one.example.com', 
	}
) == 1, "recording the clickthrough was successful");
# Twice
ok($lc->r_log(
	{ 
		-mid => 12345678901234, 
		-url => 'http://two.example.com', 
	}
) == 1, "recording the clickthrough was successful");
ok($lc->r_log(
	{ 
		-mid => 12345678901234, 
		-url => 'http://two.example.com', 
	}
) == 1, "recording the clickthrough was successful");
ok($lc->r_log(
	{ 
		-mid => 12345678901234, 
		-url => 'http://three.example.com', 
	}
) == 1, "recording the clickthrough was successful");
# Thrice? 
ok($lc->r_log(
	{ 
		-mid => 12345678901234, 
		-url => 'http://three.example.com', 
	}
) == 1, "recording the clickthrough was successful");
ok($lc->r_log(
	{ 
		-mid => 12345678901234, 
		-url => 'http://three.example.com', 
	}
) == 1, "recording the clickthrough was successful");
# Let's keep going on this... 

my $m_report = $lc->report_by_message( 12345678901234 );
# These aren't reported, anymore. 
#ok($m_report->{hard_bounce_report}->[0]->{email} eq 'hardboing@example.com');
ok($m_report->{hard_bounce} == 1); 

# These aren't reported, anymore. 
#ok($m_report->{soft_bounce_report}->[0]->{email} eq 'softboing@example.com');

ok($m_report->{soft_bounce} == 1); 
ok($m_report->{open} == 101); 
ok($m_report->{num_subscribers} == 5); 
ok(scalar @{$m_report->{url_report}} == 3); 

# Forward to a Friend: 
$lc->forward_to_a_friend_log(
	{ 
		-mid => 12345678901234,
	}
);
$report = $lc->report_by_message_index; 
ok($report->[0]->{forward_to_a_friend} == 1, "forward to a friend");


ok($lc->report_by_message( 12345678901234 )->{forward_to_a_friend} == 1, "forward_to_a_friend 2");


# View Archive 
$lc->view_archive_log(
	{ 
		-mid => 12345678901234,
	}
);
$report = $lc->report_by_message_index; 
ok($report->[0]->{view_archive} == 1, "view archive");
ok($lc->report_by_message( 12345678901234 )->{view_archive} == 1, "view_archive 2");




# auto_redirect_tag

my $ar_str = q{ 
http://example.com/ http://example.com/

http://yahoo.com/

http://google.com/

[redirect=http://gmail.com/]

<?dada redirect url="http://yahoo.com/" ?>

http://google.com/test.html

[redirect=http://gmail.com/test.html]

<?dada redirect url="http://yahoo.com/test.html" ?>

http://google.com/blah.cgi?f=test

[redirect=http://gmail.com/blah.cgi?f=test]

<?dada redirect url="http://yahoo.com/blah.cgi?f=test" ?>

Redirect this! http://yahoo.com/

Or alone?
http://yahoo.com/

Or manually?
<?dada redirect url="http://yahoo.com/" ?>
}; 
#diag '$ar_str' . $ar_str;
$ar_str = $lc->auto_redirect_tag($ar_str, 'PlainText');
my $should_be = q{ 
<?dada redirect url="http://example.com/" ?> <?dada redirect url="http://example.com/" ?>

<?dada redirect url="http://yahoo.com/" ?>

<?dada redirect url="http://google.com/" ?>

[redirect=http://gmail.com/]

<?dada redirect url="http://yahoo.com/" ?>

<?dada redirect url="http://google.com/test.html" ?>

[redirect=http://gmail.com/test.html]

<?dada redirect url="http://yahoo.com/test.html" ?>

<?dada redirect url="http://google.com/blah.cgi?f=test" ?>

[redirect=http://gmail.com/blah.cgi?f=test]

<?dada redirect url="http://yahoo.com/blah.cgi?f=test" ?>

Redirect this! <?dada redirect url="http://yahoo.com/" ?>

Or alone?
<?dada redirect url="http://yahoo.com/" ?>

Or manually?
<?dada redirect url="http://yahoo.com/" ?>
};
#diag 'is now' . $ar_str;
#diag '$should_be' . $should_be;

ok($ar_str eq $should_be, "yeah, they match up!"); 
undef $ar_str; 
undef $should_be;


my $ar_str = q{
	<p><a href='http://example.com/'>Example</a></p>
	
	<p><a href='http://example.com/'>Example</a></p><!-- Dupe Link -->
	
	<p><a href="http://google.com">Gooooogle</a></p>
	
	<p><a href="[redirect=http://gmail.com]">Gmail!</a></p>
	
	<p><a href="<?dada redirect url="http://yahoo.com" ?>">Yahoo!</a></p>
	
	<p><a href="http://google.com/test.html">Google Test</a></p>
	
	<p><a href="[redirect=http://gmail.com/test.html]">Gmail Testl</a></p>
	
	<p><a href="<?dada redirect url="http://yahoo.com/test.html" ?>">Yahoo Test</a></p>
	
	<p><a href="http://google.com/blah.cgi?f=test">Google QS Test</a></p> 
	
	<p><a href="[redirect=http://gmail.com/blah.cgi?f=test]">Gmail QS Test</a></p>
	
	<p><a href="<?dada redirect url="http://yahoo.com/blah.cgi?f=test" ?>">Yahoo QS Test</a></p>
	
	<p><a href = "http://example.com/randomspaces.html">Huh?</a></p>
	
	<p><a href="http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi/t/AaRIC3SphmbY5hKFagDo5hUensbXXoo3jMVxjSY8/">Unsubscribe Link!</a></p>
	
	<p><a href='http://example.com/single_quotes.html'>Single Quotes!</a></p>
	
	<p><a href=http://example.com/no_quotes.html>No Quotes!</a></p>
	
	<p><a href="http://example.com/amp.html?foo&bar">ampersan query string</a></p>
	
	<p><a href="http://example.com/escaped_amp.html?foo&amp;bar">escaped ampersan query string</a></p>
	
	<map name="Map">
	  <area shape="rect" coords="526,418,624,534" href="http://www.example.com">
	  <area shape="rect" coords="625,415,666,508" href="http://www.twitter.com">
	  <area shape="rect" coords="93,105,578,417" href="http://www.facebook.com">
	</map>
	
};

my $should_be = q{
	<p><a href='<?dada redirect url="http://example.com/" ?>'>Example</a></p>
	
	<p><a href='<?dada redirect url="http://example.com/" ?>'>Example</a></p><!-- Dupe Link -->
	
	<p><a href="<?dada redirect url="http://google.com" ?>">Gooooogle</a></p>
	
	<p><a href="[redirect=http://gmail.com]">Gmail!</a></p>
	
	<p><a href="<?dada redirect url="http://yahoo.com" ?>">Yahoo!</a></p>
	
	<p><a href="<?dada redirect url="http://google.com/test.html" ?>">Google Test</a></p>
	
	<p><a href="[redirect=http://gmail.com/test.html]">Gmail Testl</a></p>
	
	<p><a href="<?dada redirect url="http://yahoo.com/test.html" ?>">Yahoo Test</a></p>
	
	<p><a href="<?dada redirect url="http://google.com/blah.cgi?f=test" ?>">Google QS Test</a></p> 
	
	<p><a href="[redirect=http://gmail.com/blah.cgi?f=test]">Gmail QS Test</a></p>
	
	<p><a href="<?dada redirect url="http://yahoo.com/blah.cgi?f=test" ?>">Yahoo QS Test</a></p>
	
	<p><a href = "<?dada redirect url="http://example.com/randomspaces.html" ?>">Huh?</a></p>
	
	<p><a href="http://www.changetoyoursite.com/cgi-bin/dada/mail.cgi/t/AaRIC3SphmbY5hKFagDo5hUensbXXoo3jMVxjSY8/">Unsubscribe Link!</a></p>
	
	<p><a href='<?dada redirect url="http://example.com/single_quotes.html" ?>'>Single Quotes!</a></p>
	
	<p><a href=<?dada redirect url="http://example.com/no_quotes.html" ?>>No Quotes!</a></p>
	
	<p><a href="<?dada redirect url="http://example.com/amp.html?foo&bar" ?>">ampersan query string</a></p>
	
	<p><a href="<?dada redirect url="http://example.com/escaped_amp.html?foo&amp;bar" ?>">escaped ampersan query string</a></p>
	
	<map name="Map">
	  <area shape="rect" coords="526,418,624,534" href="<?dada redirect url="http://www.example.com" ?>">
	  <area shape="rect" coords="625,415,666,508" href="<?dada redirect url="http://www.twitter.com" ?>">
	  <area shape="rect" coords="93,105,578,417" href="<?dada redirect url="http://www.facebook.com" ?>">
	</map>
	
};

$ar_str = $lc->auto_redirect_tag($ar_str, 'HTML');
diag 'ar_str:'     . $ar_str; 
diag 'should_be: ' . $should_be;
 
ok($ar_str eq $should_be, "yeah, they match up! (HTML)"); 
undef $ar_str; 
undef $should_be;


#mailto: links are not redirected, by default. 
my $test_email_link = '<a href="mailto:user@example.com">test</a>'; 
my $ar_str = $lc->auto_redirect_tag($test_email_link, 'HTML');
diag '$ar_str ' . $ar_str; 
ok($test_email_link eq $ar_str, 'mailto: links are NOT redirected, by default.'); 
#undef $test_email_link; 
undef $ar_str; 
 

# OK, well, what if it is: 
undef($lc); 

$ls->save({ tracker_auto_parse_mailto_links => 1 });


my $lc = DADA::Logging::Clickthrough->new( { -list => $list } );
my $test_email_link2 = '<a href="mailto:user@example.com">test</a>'; 
my $ar_str = $lc->auto_redirect_tag($test_email_link2, 'HTML');
ok( $lc->isa('DADA::Logging::Clickthrough') );

diag '$test_email_link2 ' . $test_email_link2; 
diag '$ar_str ' . $ar_str; 

ok($test_email_link2 ne $ar_str, 'mailto: links are NOT redirected, by default - but we changed the settings so that they will!.');

undef $test_email_link2; 
undef $ar_str; 



dada_test_config::remove_test_list;
dada_test_config::wipe_out;

sub gimme_dada_style_args {

    my $str = shift;

    my ( $head, $body ) = split ( "\n\n", $str, 2 );

    # don't emulate.
    my $lc2 = DADA::Logging::Clickthrough->new( { -list => $list } );
    my %headers = $lc2->return_headers($head);
    $headers{Body} = $body;

    return %headers;

}

sub string_from_dada_style_args {

    my ($args) = @_;

    my $str = '';

    if ( !exists( $args->{ -fields } ) ) {

        die 'did not pass data in, "-fields"';
    }

    # for(keys %{$args->{-fields}}){ ?!?!
    for (@DADA::Config::EMAIL_HEADERS_ORDER) {
        next if $_ eq 'Body';
        next if $_ eq 'Message';    # Do I need this?!
        $str .= $_ . ': ' . $args->{ -fields }->{$_} . "\n"
          if ( ( defined $args->{ -fields }->{$_} )
            && ( $args->{ -fields }->{$_} ne "" ) );
    }

    $str .= "\n" . $args->{ -fields }->{Body};

    return $str;

}

sub slurp {

    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || die "open $file: $!";
    @r = <F>;
    close(F) || die "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}

