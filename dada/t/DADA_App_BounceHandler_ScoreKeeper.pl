#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
	
	/Users/justin/Documents/DadaMail/build/bundle/perllib
	
	
	); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

#use Test::More qw(no_plan); 

use DADA::Config qw(!:DEFAULT); 

use DADA::App::Guts; 
use DADA::MailingList::Settings; 


my $list = dada_test_config::create_test_list;
my $ls  = DADA::MailingList::Settings->new({-list => $list}); 
   
require DADA::App::BounceHandler::ScoreKeeper; 
my $bsk = DADA::App::BounceHandler::ScoreKeeper->new({-list => $list}); 

ok($bsk->isa('DADA::App::BounceHandler::ScoreKeeper'));

ok($bsk->num_scorecard_rows == 0, $bsk->num_scorecard_rows . ' == 0'); 

$bsk->tally_up_scores({'test@example.com' => 3});
ok($bsk->num_scorecard_rows == 1); 

$bsk->tally_up_scores({'test@example.com' => 3});
ok($bsk->num_scorecard_rows == 1); 

$bsk->tally_up_scores({'test@example.com' => 3});
ok($bsk->num_scorecard_rows == 1);

$bsk->tally_up_scores({'test@example.com' => 3});
ok($bsk->num_scorecard_rows == 1);

# This one is different: 
$bsk->tally_up_scores({'test2@example.com' => 10});
ok($bsk->num_scorecard_rows == 2);

my $something = $bsk->raw_scorecard({-page => 1, -entries => 100}); 


#diag '$#$something ' . $#$something; 

ok($#$something == 1, '1!'); 
ok($something->[0]->{email} eq 'test2@example.com'); 
ok($something->[0]->{score} == 10); 

ok($something->[1]->{email} eq 'test@example.com'); 
ok($something->[1]->{score} == 12, $something->[1]->{score} . ' == 12');


$bsk->erase; 
ok($bsk->num_scorecard_rows == 0, $bsk->num_scorecard_rows . ' equals 0'); 


# Let's try more than one, now: 
$bsk->tally_up_scores(
	{
		'test@example.com'  => 1,
		'test2@example.com' => 1,		
		'test3@example.com' => 1,		
		}
	
	);

#diag($bsk->num_scorecard_rows); 
ok($bsk->num_scorecard_rows == 3); 

# And now, I'm going to do it again!

$bsk->tally_up_scores(
	{
		'test@example.com'  => 4,
		'test2@example.com' => 4,		
		'test3@example.com' => 4,		
		}
	
	);

#diag($bsk->num_scorecard_rows); 
ok($bsk->num_scorecard_rows == 3, $bsk->num_scorecard_rows . ' == 3');

my $rsc = $bsk->raw_scorecard({-page => 1, -entries => 100}); 

	# a hundred thingies?
ok($#$rsc == 2); 

ok($rsc->[0]->{score} == 5, ($rsc->[0]->{email} . ': ' . $rsc->[0]->{score}) . ' == 5'); 
ok($rsc->[1]->{score} == 5, ($rsc->[1]->{email} . ': ' . $rsc->[1]->{score}) . ' == 5'); 
ok($rsc->[2]->{score} == 5, ($rsc->[2]->{email} . ': ' . $rsc->[2]->{score}) . ' == 5'); 
$bsk->erase; 
ok($bsk->num_scorecard_rows == 0, $bsk->num_scorecard_rows . ' equals 0');
undef $rsc; 


$bsk->tally_up_scores(
	{
		'test@example.com'  => 5,
		'test2@example.com' => 5,		
		'test3@example.com' => 5,		
		}
	
	);
ok($bsk->num_scorecard_rows == 3, $bsk->num_scorecard_rows . ' == 3');
# Just to have a default:
$ls->save({bounce_handler_decay_score => 1}); 
$bsk->decay_scorecard;
my $rsc = $bsk->raw_scorecard({-page => 1, -entries => 100}); 
ok($rsc->[0]->{score} == 4, ($rsc->[0]->{email} . ': ' . $rsc->[0]->{score}) . ' == 4'); 
ok($rsc->[1]->{score} == 4, ($rsc->[1]->{email} . ': ' . $rsc->[1]->{score}) . ' == 4'); 
ok($rsc->[2]->{score} == 4, ($rsc->[2]->{email} . ': ' . $rsc->[2]->{score}) . ' == 4'); 
undef $rsc; 
$bsk->decay_scorecard;
my $rsc = $bsk->raw_scorecard({-page => 1, -entries => 100}); 
ok($rsc->[0]->{score} == 3, ($rsc->[0]->{email} . ': ' . $rsc->[0]->{score}) . ' == 3'); 
ok($rsc->[1]->{score} == 3, ($rsc->[1]->{email} . ': ' . $rsc->[1]->{score}) . ' == 3'); 
ok($rsc->[2]->{score} == 3, ($rsc->[2]->{email} . ': ' . $rsc->[2]->{score}) . ' == 3'); 
undef $rsc; 


$bsk->erase; 
ok($bsk->num_scorecard_rows == 0, $bsk->num_scorecard_rows . ' equals 0');


# And just to make sure it's not happening to everyone: 

$bsk->tally_up_scores(
	{
		'test@example.com'  => 1,
		'test2@example.com' => 2,		
		'test3@example.com' => 3,		
		}
	
	);
$bsk->decay_scorecard;
ok($bsk->num_scorecard_rows == 2, $bsk->num_scorecard_rows . ' equals 2');


my $rsc = $bsk->raw_scorecard({-page => 1, -entries => 100}); 
ok($rsc->[0]->{score} == 1, ($rsc->[0]->{email} . ': ' . $rsc->[0]->{score}) . ' == 1'); 
ok($rsc->[1]->{score} == 2, ($rsc->[1]->{email} . ': ' . $rsc->[1]->{score}) . ' == 2'); 
undef $rsc; 











dada_test_config::remove_test_list;
dada_test_config::wipe_out;
