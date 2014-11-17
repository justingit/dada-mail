#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 


use DADA::Config; 
use DADA::Template::Widgets; 
use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::App::Guts; 
use utf8; 


BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
my $list = dada_test_config::create_test_list;
my $ls   = DADA::MailingList::Settings->new({-list => $list}); 
my $li   = $ls->get; 


use DADA::Template::Widgets; 

### screen


# Variables to be used in the template can be passed using the, C<-vars> parameter, which maps to the, 
# B<H::T> parameter, C<param>. C<-vars> should hold a reference to a hash: 
# 
#  my $scalar = 'I wanted to say: <!-- tmpl_var var1 -->'; 
#  print DADA::Template::Widgets::screen(
#     {
#         -data => \$scalar,
#         -vars   => {var1 => "This!"}, 
#     }
#  );
# 
# This will print:
# 
#  I wanted to say: This!

my $scalar = 'I wanted to say: <!-- tmpl_var var1 -->'; 
my $r = DADA::Template::Widgets::screen(
          {
              -data   => \$scalar,
              -vars   => {var1 => "This!"}, 
          }
     );
ok($r eq 'I wanted to say: This!'); 
undef $r;
undef $scalar; 


# My suggestion is to try not to mix the two dialects and note that we'll I<probably> be moving to 
# using the B<H::T> default template conventions, so as to make geeks and nerds more comfortable with 
# the program. Saying that, you I<can> mix the two dialects and everything should work. This may be 
# interesting in a pinch, where you want to say something like: 
# 
#  Welcome to <!-- tmpl_var boring_name -->
#  
#  <!-- tmpl_if boring_description --> 
#   Mription --> y boring description: 
#   
#     <!-- tmpl_var boring_description -->
#     
#  <!--/tmpl_if--> 
#  


$scalar = q{
Welcome to <!-- tmpl_var boring_name -->

<!-- tmpl_if boring_description --> 
    My boring description: 
 
   <!-- tmpl_var boring_description -->
   
<!--/tmpl_if--> 

}; 
   $r = DADA::Template::Widgets::screen(
   {
       -data                   => \$scalar,
       -vars                   => {boring_name => "Site Name", boring_description => 'Site Descripton'}, 
       -dada_pseudo_tag_filter => 1, 
   }
);

like($r, qr/Welcome to Site Name/); 
like($r, qr/Site Descripton/); 

undef $r; 
undef $scalar; 

# To tell C<screen> to use a specific subscriber information, you have two different methods. 
# 
# The first is to give the parameters to *which* subscriber to use, via the C<-subscriber_vars_param>: 
# 
#  print DADA::Template::Widgets::screen(
#     {
#     -subscriber_vars_param => 
#         {
#             -list  => 'listshortname', 
#             -email => 'this@example.com', 
#             -type  => 'list',
#         }
#     }
#  );
# 
# 
my $lh = DADA::MailingList::Subscribers->new({-list => $list}); 

   $lh->add_subscriber(
       { 
             -email         => 'this@example.com',
             -type          => 'list', 
             -fields        =>  {},
        }
    );
    
#my ($sv, $slv) = DADA::Template::Widgets::subscriber_vars(
#    { 
#        -subscriber_vars_param  => 
#            {
#                -list  => $list, 
#                -email => 'this@example.com', 
#                -type  => 'list',
#            },
#    }
#);
#use Data::Dumper; 
#diag "kaboom!"; 
#diag(Dumper($sv)); 
#diag(Dumper($slv));    

my $d = q{ 

Subscriber Address: <!-- tmpl_var subscriber.email -->
Subscriber Name: <!-- tmpl_var subscriber.email_name -->
Subscriber Domain: <!-- tmpl_var subscriber.email_domain -->

}; 


$r =  DADA::Template::Widgets::screen(
   {
   -data                   => \$d,
   -subscriber_vars_param  => 
       {
           -list  => $list, 
           -email => 'this@example.com', 
           -type  => 'list',
       },
    -dada_pseudo_tag_filter => 1, 
   }
   
);

like($r, qr/Subscriber Address: this\@example.com/); 
like($r, qr/Subscriber Name: this/); 
like($r, qr/Subscriber Domain: example.com/); 

undef($r); 
undef($d);



$d = q{ 

Subscriber Address: <!-- tmpl_var subscriber.email -->
Subscriber Name: <!-- tmpl_var subscriber.email_name -->
Subscriber Domain: <!-- tmpl_var subscriber.email_domain -->
}; 


$r =  DADA::Template::Widgets::screen(
   {
   -data                   => \$d,
   -subscriber_vars_param  => 
       {
           -list  => $list, 
           -email => 'this@example.com', 
           -type  => 'list',
       },
    -dada_pseudo_tag_filter => 1, 
   }
   
);

like($r, qr/Subscriber Address: this\@example.com/); 
like($r, qr/Subscriber Name: this/); 
like($r, qr/Subscriber Domain: example.com/); 

undef($r); 
undef($d); 


# The other magical thing that will happen, is that you'll get a new variable to be used in your template
# called, B<subscriber>, which is a array ref of hashrefs with name/value pairs for all your subscriber 
# fields. So, this'll allow you to do something like this: 
# 
#  <!-- tmpl_loop subscriber --> 
#  
#   <!-- tmpl_var name -->: <!-- tmpl_value -->
#  
#  <!--/tmpl_loop-->
# 
# and this will loop over your Profile Fields. 

$d = q{ 

<!-- tmpl_loop subscriber --> 
 <!-- tmpl_var name -->: <!-- tmpl_var value -->
<!--/tmpl_loop-->
}; 


$r =  DADA::Template::Widgets::screen(
   {
   -data                   => \$d,
   -subscriber_vars_param  => 
       {
           -list  => $list, 
           -email => 'this@example.com', 
           -type  => 'list',
       },
    -dada_pseudo_tag_filter => 1, 
   }
   
);


like($r, qr/email: this\@example.com/); 
like($r, qr/email_name: this/); 
like($r, qr/email_domain: example.com/); 

undef($r); 
undef($d);


# If you'd like, you can also pass the Profile Fields information yourself - this may be useful if
# you're in some sort of recursive subroutine, or if you already have the information on hand. You may
# do so by passing the, C<-subscriber_vars> parameter, I<instead> of the C<-subscriber_vars_param>
# parameter, like so: 
# 
#  use DADA::MailingList::Subscribers; 
#  my $lh = DADA::MailingList::Subscribers->new({-list => 'listshortname'}); 
#  
#  my $subscriber = get_subscriber(
#                       {
#                          -email  => 'this@example.com', 
#                          -type   => 'list', 
#                          -dotted => 1, 
#                        }
#                    ); 
#  
#  use DADA::Template::Widgets; 
#  print DADA::Template::Widgets::screen(
#  
#            { 
#                 -subscriber_vars => $subscriber,
#            }
#        ); 
#
# The, B<subscriber> variable will still be magically created for you. 

my $subscriber = $lh->get_subscriber(
                     {
                        -email  => 'this@example.com', 
                        -type   => 'list', 
                        -dotted => 1, 
                      }
                  ); 


$d = q{ 

<!-- tmpl_loop subscriber --> 
 <!-- tmpl_var name -->: <!-- tmpl_var value -->
<!--/tmpl_loop-->
}; 


$r =  DADA::Template::Widgets::screen(
   {
   -data                   => \$d,
    -subscriber_vars        => $subscriber,
    -dada_pseudo_tag_filter => 1, 
   }
   
);

like($r, qr/email: this\@example.com/); 
like($r, qr/email_name: this/); 
like($r, qr/email_domain: example.com/); 

undef($r); 
undef($d);

# The B<-subscriber_vars> parameter is also a way to override what gets printed for the, B<subscriber.> 
# variables, since nothing is done to check the validity of what you're passing. So, keep that in mind - 
# all these are shortcuts and syntactic sugar. And we I<like> sugar. 



$d = q{ 

<!-- tmpl_loop subscriber --> 
 <!-- tmpl_var name -->: <!-- tmpl_var value -->
<!--/tmpl_loop-->
}; 


$r =  DADA::Template::Widgets::screen(
   {
   -data                   => \$d,
   -subscriber_vars        => {foo => 'bar', ping => 'pong'},
   
   }
   
);

like($r, qr/foo: bar/); 
like($r, qr/ping: pong/); 

undef($r); 
undef($d);



# A similar thing can be used to retrieve the list settings of a particular list: 
# 
#  print DADA::Template::Widgets::screen(
#     {
#     -list_settings_vars_param => 
#         {
#             -list  => 'listshortname', 
#         }
#     }
#  );
#  

$d = q{ 
list: <!-- tmpl_var list_settings.list -->
list name: <!-- tmpl_var list_settings.list_name -->
list owner: <!-- tmpl_var list_settings.list_owner_email -->
info: <!-- tmpl_var list_settings.info -->
}; 

$r =  DADA::Template::Widgets::screen(
   {
   -data                     => \$d, 
   -list_settings_vars_param => 
       {
           -list  => $list, 
       },
   -dada_pseudo_tag_filter => 1, 
   }
);

like($r, qr/list: $list/); 
like($r, qr/list name: $li->{list_name}/); 
like($r, qr/list owner: $li->{list_owner_email}/); 
like($r, qr/info: $li->{info}/); 

undef($r); 
undef($d);



# or:
# 
#  use DADA::MailingList::Settings; 
#  my $ls = DADA::MailingList::Settings->new({-list => 'listshortname'}); 
#  
#  my $list_settings = $ls->get(
#                          -dotted => 1, 
#                      ); 
#  
#  use DADA::Template::Widgets; 
#  print DADA::Template::Widgets::screen(
#  
#            { 
#                 -list_settings_vars => $list_settings,
#            }
#        ); 
#        


$d = q{ 
list: <!-- tmpl_var list_settings.list -->
list name: <!-- tmpl_var list_settings.list_name -->
list owner: <!-- tmpl_var list_settings.list_owner_email -->
info: <!-- tmpl_var list_settings.info -->
}; 

my $list_settings = $ls->get(
                        -dotted => 1, 
                    ); 



$r =  DADA::Template::Widgets::screen(
   {
   -data                     => \$d, 
   -list_settings_vars       => $list_settings, 
   -dada_pseudo_tag_filter   => 1, 
   }
);

like($r, qr/list: $list/); 
like($r, qr/list name: $li->{list_name}/); 
like($r, qr/list owner: $li->{list_owner_email}/); 
like($r, qr/info: $li->{info}/); 

undef($r); 
undef($d);


# This will even work, as well in a template: 
# 
#  <!-- tmpl_loop list_settings --> 
#  
#     <!-- tmpl_var name -->: <!-- tmpl_var value -->
#  
#  <!-- /tmpl_loop -->

$d = q{ 
<!-- tmpl_loop list_settings --> 
    <!-- tmpl_var name -->: <!-- tmpl_var value -->
<!-- /tmpl_loop -->
}; 


$r =  DADA::Template::Widgets::screen(
   {
   -data                     => \$d, 
   -list_settings_vars_param => {-list => $list}, 
   }
);

like($r, qr/list: $list/); 
like($r, qr/list_name: $li->{list_name}/); 
like($r, qr/list_owner_email: $li->{list_owner_email}/); 
like($r, qr/info: $li->{info}/); 

undef($r); 
undef($d);

###/ screen

#
#
# validate_screen

my @expr_tmpls = qw(
	expr1.tmpl	
); 
for(@expr_tmpls){ 
	my $d = dada_test_config::slurp('t/corpus/templates/' . $_); 
	my ($status, $errors) = DADA::Template::Widgets::validate_screen(
		{ 
			-data => \$d, 
			-expr => 1, 
		}
	); 
	ok($status == 1); 
	ok($errors eq undef); 
}
for(@expr_tmpls){ 
	my $d = dada_test_config::slurp('t/corpus/templates/' . $_); 
	my ($status, $errors) = DADA::Template::Widgets::validate_screen(
		{ 
			-data => \$d, 
			-expr => 0,
			-pro  => 0,  
		}
	); 
	# These will fail, if you have HTML::Template::Pro, since it can 
	# Handle -expr stuff, no problemo, OR it doesn't die if it fails. Ugh!
	ok($status == 0); 
	ok(defined($errors)); 
}
# /validate_screen


# Bug: <!-- tmpl_var  2460735  --> 3.0.1 - simple <!-- tmpl_var tmpl_if ... --> usage breaks sending
# https://sourceforge.net/tracker/index.php?func=detail&atid=113002&aid=2460735&group_id=13002

$d = q{ 
	

	<!-- tmpl_if subscriber.first_name -->

	Dear <!-- tmpl_var subscriber.first_name -->

	<!-- tmpl_else -->

	Dear <!-- tmpl_var subscriber.email -->

	<!-- /tmpl_if -->

};

my $f = $d; 

DADA::Template::Widgets::dada_pseudo_tag_filter(\$f); 

like($f, qr/\<\!\-\- tmpl_if subscriber\.first_name \-\-\>/, "Looks like the transformation was successful!"); 
#diag $f; 
eval { 
	$r =  DADA::Template::Widgets::screen(
	   {
	   -data                     => \$d, 
	   -list_settings_vars_param => 
	       {
	           -list  => $list, 
	       },
	   -dada_pseudo_tag_filter => 1, 
	   }
	); 
	#diag $r; 
	
};

if($@){ 
	diag ($@);
}
else { 
	
}
ok(!$@, "Good! The simple doc example doesn't give back and error!"); 
like($r, qr/Dear/); 




SKIP: {

		    skip "Profile Fields is not supported with this current backend." 
		        if $lh->can_have_subscriber_fields == 0; 

			require DADA::ProfileFieldsManager;
			my $pfm = DADA::ProfileFieldsManager->new;
				 	$pfm->add_field(
						{
							-field          => 'field1', 
							-fallback_value => 'fallback value for field 1',
							-label          => 'Field 1!', 
						}
					);
			
			# This test makes sure fallback fields are used, 
			# if nothing else is given (not even a subscriber) 
			$scalar = '<!-- tmpl_var subscriber.field1 -->';
		    $r = DADA::Template::Widgets::screen(
				{ 
					-data => \$scalar, 
					-subscriber_vars_param    => {
						-list                 => $list, 
						-use_fallback_vars     => 1
					},
				}
			); 
			ok($r eq 'fallback value for field 1', 'fallback field stuff is working!');
			undef $scalar; 
			undef $r;
	
			# This test makes sure there fallback fields are used, 
			# even if there is a subscriber (but no field value) 
	
			#
			# I'm curious: 
			# What happens if we give this a email address that isn't subscribed?
			$scalar = '<!-- tmpl_var subscriber.field1 -->';
		    $r = DADA::Template::Widgets::screen(
				{ 
					-data => \$scalar, 
					-subscriber_vars_param => {
						-list              => $list, 
						-use_fallback_vars => 1,
			            -email             => 'made up', 
			            -type              => 'list',
					},
				}
			); 
			ok($r eq 'fallback value for field 1', 'fallback field stuff is working!');
			undef $scalar; 
			undef $r;
	
	
	
	
			# This test makes sure there fallback fields are used, 
			# even if there is a subscriber (but no field value) 
			my $email = 'fallbackfieldtest@example.com'; 
			$lh->add_subscriber(
		       { 
		             -email         => $email,
		             -type          => 'list', 
		             -fields        =>  {}, # no values for this. 
		        }
		    );
			$scalar = '<!-- tmpl_var subscriber.field1 -->';
		    $r = DADA::Template::Widgets::screen(
				{ 
					-data => \$scalar, 
					-subscriber_vars_param => {
						-list              => $list, 
						-use_fallback_vars => 1,
			            -email             => $email, 
			            -type              => 'list',
					},
				}
			); 
			ok($r eq 'fallback value for field 1', 'fallback field stuff is working!');
			undef $scalar; 
			undef $r;
			undef $email; 
	
	

	
	
			# This test makes sure there fallback fields aren't used, 
			# if there is a subscriber, with value in the field. 
			$email = 'fallbackfieldtest2@example.com'; 
			my $field1_value = 'fallbackfieldtest2 field value!'; 
			$lh->add_subscriber(
		       { 
		             -email         => $email,
		             -type          => 'list', 
		             -fields        =>  {
						field1      => $field1_value, 
					}, 
		        }
		    );
			$scalar = '<!-- tmpl_var subscriber.field1 -->';
		    $r = DADA::Template::Widgets::screen(
				{ 
					-data => \$scalar, 
					-subscriber_vars_param => {
					   -list              => $list, 
			           -email             => $email, 
			           -type              => 'list',
		 			   -use_fallback_vars => 1,
					},
				}
			); 
			diag $r; 
			ok($r eq $field1_value, 'fallback field was not used');
			undef $scalar; 
			undef $r;
			undef $email; 
		
};






=cut

$scalar = "<!-- tmpl_strftime %a, %d %b %Y -->

Something, 

<!-- tmpl_strftime  %b %Y %a, %d -->

Something more...

<!-- tmpl_strftime  %Y %Y %b  %a, %d -->

Again something else. 

";
   $r = DADA::Template::Widgets::screen(
	{ 
		-data => \$scalar, 
	}
);

diag "time piece!" . $r; 

=cut



# wrap_screen
my $regex = ''; 

eval { 
  $r = DADA::Template::Widgets::wrap_screen(
		{ 
		}
	);	
};
ok($@, "calling 'wrap_screen' without a '-with' parameter causes an error' $@");
$regex = quotemeta("you must pass the, '-with' parameter"); 
like($@, qr/$regex/); 


eval { 
  $r = DADA::Template::Widgets::wrap_screen(
		{ 
			-with => 'invalid', 
		}
	);	
};
ok($@, "calling 'wrap_screen' with an incorrect, '-with parameter causes an error' $@");
$regex = quotemeta("'-with' parameter must be either, 'list' or, 'admin'"); 
like($@, qr/$regex/);



# https://github.com/justingit/dada-mail/issues/245
$d = q{ 
	
	Blah blah blah
	
	<!-- tmpl_set name="somename" value="some value" -->

	blah blah blah

}; 

my $p = {};
($r, $p)  =  DADA::Template::Widgets::screen(
   {
   -data                     => \$d, 
   -return_params            => 1,
   }
);
ok($p->{somename} eq 'some value', "got 'some value'!"); 

undef($r); 
undef($d);
undef($p);




# <!-- tmpl_strftime [...] --> 
#           Fri Jan 25 01:22:15 2013
my $time = '1359102135';

$scalar = '<!-- tmpl_strftime %a, %d %b %Y -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq 'Fri, 25 Jan 2013'); 

# %U 	Week number of the given year, starting with the first Sunday as the first week 
# 13 (for the 13th full week of the year)

$scalar = '<!-- tmpl_strftime %U -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '03');

# %V ISO-8601:1988 week number of the given year, starting with the first week of the year with at least 4 weekdays, 
# with Monday being the start of the week 
# 01 through 53 (where 53 accounts for an overlapping week)
$scalar = '<!-- tmpl_strftime %V -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '04');

# %W 	A numeric representation of the week of the year, starting with the first Monday as the first week 
# 46 (for the 46th week of the year beginning with a Monday)
$scalar = '<!-- tmpl_strftime %W -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '03');

# Month 	--- 	---
# %b 	Abbreviated month name, based on the locale 	Jan through Dec
$scalar = '<!-- tmpl_strftime %b -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq 'Jan');

# %B 	Full month name, based on the locale 	January through December
$scalar = '<!-- tmpl_strftime %B -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq 'January');

# %h 	Abbreviated month name, based on the locale (an alias of %b) 	Jan through Dec
$scalar = '<!-- tmpl_strftime %h -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq 'Jan');

# %m 	Two digit representation of the month 	01 (for January) through 12 (for December)
$scalar = '<!-- tmpl_strftime %m -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01');

# Year 	--- 	---
# %C 	Two digit representation of the century (year divided by 100, truncated to an integer) 	19 for the 20th Century
$scalar = '<!-- tmpl_strftime %C -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '20');

# %g Two digit representation of the year going by ISO-8601:1988 standards (see %V) 
# Example: 09 for the week of January 6, 2009
$scalar = '<!-- tmpl_strftime %g -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '13');

# %G 	The full four-digit version of %g 	Example: 2008 for the week of January 3, 2009
$scalar = '<!-- tmpl_strftime %G -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '2013');

# %y 	Two digit representation of the year 	Example: 09 for 2009, 79 for 1979
$scalar = '<!-- tmpl_strftime %y -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '13');

# %Y 	Four digit representation for the year 	Example: 2038
$scalar = '<!-- tmpl_strftime %Y -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '2013');

# Time 	--- 	---
# %H 	Two digit representation of the hour in 24-hour format 	00 through 23
$scalar = '<!-- tmpl_strftime %H -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01');

# %k 	Two digit representation of the hour in 24-hour format, with a space preceding single digits 	0 through 23
$scalar = '<!-- tmpl_strftime %k -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq ' 1');

# %I 	Two digit representation of the hour in 12-hour format 	01 through 12
$scalar = '<!-- tmpl_strftime %I -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01');

# %l (lower-case 'L') 	Hour in 12-hour format, with a space preceding single digits 	1 through 12
$scalar = '<!-- tmpl_strftime %l -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq ' 1');

# %M 	Two digit representation of the minute 	00 through 59
$scalar = '<!-- tmpl_strftime %M -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '22');

# %p 	UPPER-CASE 'AM' or 'PM' based on the given time 	Example: AM for 00:31, PM for 22:23
$scalar = '<!-- tmpl_strftime %p -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq 'AM');

# This doesn't seem to work... 
## %P 	lower-case 'am' or 'pm' based on the given time 	Example: am for 00:31, pm for 22:23
#$scalar = '<!-- tmpl_strftime %P -->'; 
#$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
#ok($r eq 'am');

# %r 	Same as "%I:%M:%S %p" 	Example: 09:34:17 PM for 21:34:17
$scalar = '<!-- tmpl_strftime %r -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01:22:15 AM');

# %R 	Same as "%H:%M" 	Example: 00:35 for 12:35 AM, 16:44 for 4:44 PM
$scalar = '<!-- tmpl_strftime %R -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01:22');

# %S 	Two digit representation of the second 	00 through 59
$scalar = '<!-- tmpl_strftime %S -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '15');

# %T 	Same as "%H:%M:%S" 	Example: 21:34:17 for 09:34:17 PM
$scalar = '<!-- tmpl_strftime %T -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01:22:15');

# %X 	Preferred time representation based on locale, without the date 	Example: 03:59:16 or 15:59:16
$scalar = '<!-- tmpl_strftime %X -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01:22:15');

# %z 	The time zone offset. Not implemented as described on Windows. See below for more information.
# Example: -0500 for US Eastern Time
# %Z 	The time zone abbreviation. Not implemented as described on Windows. See below for more information. 	Example: EST for Eastern Time
# Time and Date Stamps 	--- 	---
# %c 	Preferred date and time stamp based on locale 	Example: Tue Feb 5 00:45:10 2009 for February 5, 2009 at 12:45:10 AM

# %D 	Same as "%m/%d/%y" 	Example: 02/05/09 for February 5, 2009
$scalar = '<!-- tmpl_strftime %D -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '01/25/13');

# %F 	Same as "%Y-%m-%d" (commonly used in database datestamps) 	Example: 2009-02-05 for February 5, 2009
$scalar = '<!-- tmpl_strftime %F -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '2013-01-25');

# %s 	Unix Epoch Time timestamp (same as the time() function) 	Example: 305815200 for September 10, 1979 08:40:00 AM
$scalar = '<!-- tmpl_strftime %s -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '1359102135');

TODO: {
    local $TODO = 'No idea why, "%x" gives "01/25/2013" and not, 01/25/13';	

	# %x 	Preferred date representation based on locale, without the time 	Example: 02/05/09 for February 5, 2009
	$scalar = '<!-- tmpl_strftime %x -->'; 
	$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
	ok($r eq '01/25/13'); #?!?!
}; 


# Miscellaneous 	--- 	---
# %n 	A newline character ("\n") 	---
$scalar = '<!-- tmpl_strftime %n -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq "\n");

# %t 	A Tab character ("\t") 	---
$scalar = '<!-- tmpl_strftime %t -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq "\t");

# %% 	A literal percentage character ("%") 	---
$scalar = '<!-- tmpl_strftime %% -->'; 
$r = DADA::Template::Widgets::screen({-data => \$scalar, -time => $time, });	
ok($r eq '%');

#/ <!-- tmpl_strftime <!-- tmpl_var ... --> -->



# UTF-8 Stuff: 
use Encode qw(encode decode);


my $no_tags = 't/corpus/templates/utf8_no_tags.tmpl'; 
my $return_should_be = 'ゴジラこんにちは！'; 


undef($r); 
$r = DADA::Template::Widgets::_slurp($no_tags); 
diag Encode::encode($DADA::Config::HTML_CHARSET, $r);
diag Encode::encode($DADA::Config::HTML_CHARSET, $return_should_be);
ok($r eq $return_should_be); 

undef($r); 
$r =  DADA::Template::Widgets::screen({
	-screen => $no_tags, 
}); 

diag Encode::encode($DADA::Config::HTML_CHARSET, $r);
diag Encode::encode($DADA::Config::HTML_CHARSET, $return_should_be);
ok($r eq $return_should_be); 

my $nothing = undef; 
#$DADA::Config::ADMIN_TEMPLATE = $return_should_be; 
# THis is just kinda weird: 
use File::Copy; 
copy('templates/admin_template.tmpl', 'templates/admin_template.tmpl-bak'); 
open my $a_t, '>:encoding(' . $DADA::Config::HTML_CHARSET . ')', 'templates/admin_template.tmpl' or croak $!; 
print $a_t $return_should_be or die; 
close($a_t) or die; 


my $admin = DADA::Template::Widgets::_raw_screen({-screen => 'admin_template.tmpl', -encoding => 1}); 
ok($admin eq $return_should_be); 
diag Encode::encode($DADA::Config::HTML_CHARSET, $admin);





undef ($admin);
require DADA::Template::HTML; 
my $admin = DADA::Template::HTML::admin_template(
	-HTML_Header => 0, 
	-List       => $list,  
	-Part       => 'full', 
); 
ok($admin eq $return_should_be); 
diag Encode::encode($DADA::Config::HTML_CHARSET, $admin);




undef($admin); 
my $admin = $r = DADA::Template::Widgets::wrap_screen(
		{
			-data    => \$nothing, 
			-with   => 'admin',  
			-wrapper_params => { 
				-HTML_Header => 0, 
				-List       => $list,  
			},

		}
	);	

ok($admin eq $return_should_be); 
diag Encode::encode($DADA::Config::HTML_CHARSET, $admin);

unlink('templates/admin_template.tmpl') or die "that didn't work."; 
move('templates/admin_template.tmpl-bak', 'templates/admin_template.tmpl'); 









dada_test_config::remove_test_list;
dada_test_config::wipe_out;




