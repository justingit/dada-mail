#!/usr/bin/perl 

use lib
  qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib );
BEGIN { $ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1 }
use dada_test_config;

use strict;

use Carp;

# This doesn't work, if we're eval()ing it.
# use Test::More qw(no_plan);

my $list = dada_test_config::create_test_list();

use DADA::MailingList::MessageDrafts;

my $d = DADA::MailingList::MessageDrafts->new( { -list => $list } );

ok( $d->enabled == 1, 'Should be enabled' );

ok( $d->count == 0, 'No drafts, yet' );

ok( $d->id_exists == 0, 'Empty ID? 0' );

ok( $d->id_exists(1234) == 0, 'This ID shouldn\'t exist' );

ok( $d->has_draft( { -screen => 'send_email' } ) == 0, 'No saved drafts, so,' );
ok( $d->has_draft( { -screen => 'send_url_email' } ) == 0,
    'No saved drafts, so,' );

ok( $d->latest_draft_id( { -screen => 'send_email' } ) eq undef,
    'Again, haven\'t MADE anything, yet.' );

ok( $d->remove(1234) == -1, 'Removing an id that doesn\'t exist? return -1' );

# OK, let's actually do something,
use CGI;
my $q    = CGI->new;
my $vals = {
    Subject           => 'My Subject!',
    html_message_body => '<h1>HTML Message</h1>',
    text_message_body => 'Text Message!',
    ignored_param     => 'do not save!',
};

# Pull 'em in:
for ( keys %$vals ) { $q->param( $_, $vals->{$_} ); }

my $s_id = $d->save(
    {
        -cgi_obj => $q,
        -screen  => 'send_email',
    }
);
ok( $s_id > 0 );

ok( $d->count == 1, ' One draft, hah hah hah' );

# So, if you don't pass an id, you get the most recent one:
my $new_q = $d->fetch( { -screen => 'send_email' } );
ok( $new_q->param('Subject')           eq $vals->{'Subject'} );
ok( $new_q->param('html_message_body') eq $vals->{'html_message_body'} );
ok( $new_q->param('text_message_body') eq $vals->{'text_message_body'} );

ok(
    $new_q->param('ignored_param') eq undef,
    'ignored_param isn\'t something I actually save.'
);
undef($new_q);

my $vals2 = {
    Subject           => 'My Subject Two!',
    html_message_body => '<h1>HTML Message Two</h1>',
    text_message_body => 'Text Message Two!',
    ignored_param     => 'do not save! Two',
};
my $q2 = CGI->new;
for ( keys %$vals2 ) { $q2->param( $_, $vals2->{$_} ); }

# Ugh. Hacky.
sleep(1);
my $s_id2 = $d->save(
    {
        -cgi_obj => $q2,
        -screen  => 'send_email',
    }
);

ok( $d->count == 2, 'Two drafts, hah hah hah' );

ok( $d->latest_draft_id( { -screen => 'send_email' } ) eq $s_id2,
    ' This should be the latest!' );

# So, if you don't pass an id, you get the most recent one:
my $new_q = $d->fetch( { -screen => 'send_email' } );
ok( $new_q->param('Subject')           eq $vals2->{'Subject'} );
ok( $new_q->param('html_message_body') eq $vals2->{'html_message_body'} );
ok( $new_q->param('text_message_body') eq $vals2->{'text_message_body'} );
ok(
    $new_q->param('ignored_param') eq undef,
    'ignored_param isn\'t something I actually save.'
);
undef($new_q);

my $di = $d->draft_index;
ok( $di->[0]->{Subject}  eq $vals2->{Subject} );
ok( $di->[0]->{'screen'} eq 'send_email' );
ok( $di->[0]->{'id'} == 2 );
ok( $di->[0]->{'role'} eq 'draft' );
ok( $di->[0]->{'list'} eq $list );

ok( $di->[1]->{Subject}  eq $vals->{Subject} );
ok( $di->[1]->{'screen'} eq 'send_email' );
ok( $di->[1]->{'id'} == 1 );
ok( $di->[1]->{'role'} eq 'draft' );
ok( $di->[1]->{'list'} eq $list );

ok( $d->remove( $di->[1]->{'id'} ) == 1 );
ok( $d->count == 1 );
ok( $d->latest_draft_id( { -screen => 'send_email' } ) eq $s_id2 );
ok( $d->remove( $di->[0]->{'id'} ) == 1 );
ok( $d->count == 0 );

dada_test_config::remove_test_list;
dada_test_config::wipe_out;
