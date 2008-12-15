#!/usr/bin/perl -w
use strict; 


use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}


use dada_test_config; 

#dada_test_config::wipe_out;


use Test::More qw(no_plan);  

use DADA::Config;
use DADA::Logging::Clickthrough;
use DADA::App::Guts; 
use DADA::MailingList::Settings; 


my $list = dada_test_config::create_test_list;
diag '$list ' . $list; 
my $lc = DADA::Logging::Clickthrough->new({-list => $list});

ok($lc->isa('DADA::Logging::Clickthrough'));



my $test_mid = DADA::App::Guts::message_id(); 
my $test_url = 'http://example.com/page.html'; 

my $ran_key = $lc->random_key(); 
ok($ran_key           > 0); 
ok(length($ran_key) == 12);


my $v = $lc->encode_value($test_mid, $test_url);
# ie: 
ok($v eq $test_mid . ',' . $test_url); 


my $key = $lc->add($test_mid, $test_url);
#diag "Key: $key"; 
ok($key           > 0); 
ok(length($key) == 12);

my $reuse = $lc->reuse_key($test_mid, $test_url); 
#diag "Reuse: $reuse"; 

ok($reuse == $key);

my $reuse2 = $lc->reuse_key(1234, 'http://someotherurl.com'); 

ok($reuse2 eq undef); 


my $coded = $lc->redirect_encode($test_mid, $test_url); 
ok($coded eq $DADA::Config::PROGRAM_URL . '/r/' . $list . '/' . $key .'/');

my $coded2 = $lc->redirect_encode($test_mid, 'http://someotherurl2.com'); 

ok($coded ne $coded2);


my $existing = {}; 
my $test_url2 = 'http://test.example.com/'; 

# Make sure we never make the URL twice...
my $i = 0; 
for($i = 0; $i < 50; $i++){ 
	my $l_test_url = $test_url2 . $i; 
	my $test_r_url = $lc->redirect_encode($test_mid, $l_test_url); 
	#diag q{$test_r_url} . $test_r_url; 
	ok(!exists($existing->{$test_r_url})); 
	$existing->{$test_r_url} = 1;
}

my $s = '[redirect=' . $test_url . ']';

my $ps = $lc->parse_string($test_mid, $s);
 
# It's the same as before, you see? 
ok($ps eq $coded); 

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
my $r_email = string_from_dada_style_args(
					{
						-fields => {%fields}, 
					}
				);	

my $qm_coded = quotemeta($coded); 
like($r_email, qr/$qm_coded/); 

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
$r_email = string_from_dada_style_args(
					{
						-fields => {%fields}, 
					}
				);	

$qm_coded = quotemeta($coded); 
like($r_email, qr/$qm_coded/);


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
$r_email = string_from_dada_style_args(
					{
						-fields => {%fields}, 
					}
				);	

$qm_coded = quotemeta($coded); 
like($r_email, qr/$qm_coded/);

like($r_email, qr/This is the PlainText Ver\:\n$qm_coded/);

my $html_check = quotemeta(qq{<p>This is the HTML Ver:</p>
<a href="$coded">Click Here</a>});

like($r_email, qr/$html_check/);


################################################


my ($r_mid, $r_url) = $lc->fetch($key); 
ok($r_mid eq $test_mid); 
ok($r_url eq $test_url); 

diag '$lc->clickthrough_log_location ' . $lc->clickthrough_log_location; 
diag q{$DADA::Config::LOGS . '/' . $list . '-clickthrough.log' } . $DADA::Config::LOGS . '/' . $list . '-clickthrough.log'; 

ok($lc->clickthrough_log_location eq $DADA::Config::LOGS . '/' . $list . '-clickthrough.log'); 


# if it's not on, it returns, "0"; 
ok($lc->r_log($test_mid, $test_url) == 0); 


my $ls = DADA::MailingList::Settings->new({-list => $list}); 
$ls->save(
		{
			clickthrough_tracking => 1, 
		}
	); 

# This is kinda strange - we have to reinit the object: 

undef($lc);
$lc = DADA::Logging::Clickthrough->new({-list => $list});
 
# Now, it should do what I want it to do: 
ok($lc->r_log($test_mid, $test_url) == 1); 

my $log = slurp($lc->clickthrough_log_location); 

my $q_test_url = quotemeta($test_url); 
like($log, qr/$test_mid\t$q_test_url/); 


dada_test_config::remove_test_list;
dada_test_config::wipe_out;




sub gimme_dada_style_args { 
	
	my $str = shift; 
	
	my ($head, $body) = split("\n\n", $str, 2); 
	
	# don't emulate.
	my $lc2 = DADA::Logging::Clickthrough->new({-list => $list});
	my %headers = $lc2->return_headers($head);
	$headers{Body} = $body;
	
	return %headers; 
	
}




sub string_from_dada_style_args { 

    my ($args) = @_; 

    my $str = ''; 
    
    if(! exists($args->{-fields})){ 
    
        die 'did not pass data in, "-fields"' ;
    }
    
    # foreach(keys %{$args->{-fields}}){ ?!?!
    foreach (@DADA::Config::EMAIL_HEADERS_ORDER) {
        next if $_ eq 'Body';
        next if $_ eq 'Message';    # Do I need this?!
        $str .= $_ . ': ' . $args->{-fields}->{$_} . "\n"
        if ( ( defined $args->{-fields}->{$_} ) && ( $args->{-fields}->{$_} ne "" ) );
    }
    
    $str .= "\n" . $args->{-fields}->{Body};
    
    return $str;

    
}




sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, "<$file") || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}






