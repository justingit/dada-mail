#!/usr/bin/perl -w

package screen_cache;

use strict;

# make sure the DADA lib is in the lib paths!
use lib qw(../ ../DADA/perllib);

use CGI::Carp qw(fatalsToBrowser); 
use DADA::Config 4.0.0;
# we need this for cookies things
use CGI;
my $q = new CGI;
$q->charset($DADA::Config::HTML_CHARSET);
$q = decode_cgi_obj($q);

my $verbose = 0;

my $Plugin_Config = {};

$Plugin_Config->{Plugin_URL} = $q->url;

$Plugin_Config->{Allow_Manual_Run} = 1;

# Set a passcode that you'll have to also pass to invoke this script as
# explained above in, "$Plugin_Config->{Allow_Manual_Run}"

$Plugin_Config->{Manual_Run_Passcode} = '';




use DADA::App::ScreenCache;
my $c = DADA::App::ScreenCache->new;

# use some of those Modules
use DADA::Template::HTML;
use DADA::App::Guts;
use DADA::MailingList::Settings;




run()
  unless caller();

sub run {
    main();
}

sub main {
	my $process = $q->param('process'); 
	
    if ($process) {
        if ( $process eq 'view' ) {
            $c->show( $q->param('filename') );
        }
        elsif ( $process eq 'remove' ) {
            $c->remove( $q->param('filename') );
            view();
        }
        elsif ( $process eq 'flush' ) {
            $c->flush;
            view();
        }
    }
    else {
	    if (   keys %{ $q->Vars }
	        && $q->param('run')
	        && xss_filter( $q->param('run') ) == 1
	        && $Plugin_Config->{Allow_Manual_Run} == 1 )
	    {
	        cgi_manual_start();
	    }
		else { 
        	view();
		}	
    }
}

sub view {

    # This will take care of all out security woes
    my ( $admin_list, $root_login ) = check_list_security(
        -cgi_obj  => $q,
        -Function => 'screen_cache'
    );
    my $list = $admin_list;

    my $file_list = $c->cached_screens();
    my $scrn      = '';

    $scrn = admin_template_header(
        -Title      => "Screen Cache",
        -List       => $list,
        -Root_Login => $root_login,
        -Form       => 0,

    );

    my $app_file_list = [];

    foreach my $entry (@$file_list) {
        my $cutoff_name = $entry->{name};

        my $l    = length($cutoff_name);
        my $size = 50;
        my $take = $l < $size ? $l : $size;
        $cutoff_name = substr( $cutoff_name, 0, $take );
        $entry->{cutoff_name} = $cutoff_name;
        $entry->{dotdot} = $l < $size ? '' : '...';

        push( @$app_file_list, $entry );

    }
    require DADA::Template::Widgets;
	my $view_template = view_template();
    $scrn .= DADA::Template::Widgets::screen(
        {
			-data => \$view_template, 
            -vars   => {
				Plugin_URL    => $Plugin_Config->{Plugin_URL}, 
                file_list     => $app_file_list,
                cache_active  => $DADA::Config::SCREEN_CACHE != 0 ? 1 : 0,
            },
        }
    );

    $scrn .= admin_template_footer( -List => $list, );
    e_print($scrn);

}

sub cgi_manual_start {

    if (
        (
            xss_filter( $q->param('passcode') ) eq
            $Plugin_Config->{Manual_Run_Passcode}
        )
        || ( $Plugin_Config->{Manual_Run_Passcode} eq '' )
      )
    {

        print $q->header();

        if ( defined( xss_filter( $q->param('verbose') ) ) ) {
            $verbose = xss_filter( $q->param('verbose') );
        }
        else {
            $verbose = 1;
        }

     	$c->flush;
		print 'All cached screens have been removed.'
			if $verbose; 
    }
    else {
        print $q->header();
        print	"$DADA::Config::PROGRAM_NAME $DADA::Config::VER Authorization Denied.";
    }
}



sub view_template { 
	
return q{ 
	<!-- begin clear_screen_cache.tmpl --> 

		<p>Screen Caching is currently <strong>
	<!-- tmpl_if cache_active --> 

		enabled.

	<!-- tmpl_else --> 

		disabled.

	<!-- /tmpl_if -->
	</strong>


	<!-- tmpl_if file_list --> 

		 <div class="buttonfloat">


		<form action="<!-- tmpl_var Plugin_URL -->" method="POST"> 
			<input type="hidden" name="process" value="flush" />
			 <input type="submit" class="alertive" value="Remove All Cached Screens" />
		</form> 

		 </div>
		 <div class="floatclear"></div>


		<div style="max-height: 300px; overflow: auto; border:1px solid black">

		<table style="width:100%" cellpadding="2" cellspacing="0" border="0"> 


		<tr> 
		  <td></td> 

		  <td>Filename</td> 
		  <td>Size (kb)</td> 

		  <td></td> 

		 </tr> 





		<!-- tmpl_loop file_list --> 

			   <tr<!-- tmpl_if name="__odd__" --> style="background-color:#ccf;"<!--/tmpl_if-->>
		  <td>


		  <form action="<!-- tmpl_var Plugin_URL -->" method="POST"> 
			<input type="hidden" name="f" value="clear_screen_cache" /> 
			<input type="hidden" name="process" value="remove" />

			<input type="hidden" name="filename" value="<!-- tmpl_var name -->" --> 

			<input type="submit" class="alertive" value="[x]">
		   </form> 

		  </td> 


		  <td><span title="<!-- tmpl_var name -->"><!-- tmpl_var cutoff_name --><!-- tmpl_var dotdot --></span></td> 
		  <td><!-- tmpl_var size --></td> 

		  <td>
		   <form action="<!-- tmpl_var Plugin_URL -->" method="POST" target="preview"> 
			<input type="hidden" name="f" value="clear_screen_cache" /> 
			<input type="hidden" name="process" value="view" />

			<input type="hidden" name="filename" value="<!-- tmpl_var name -->" --> 

			<input type="submit" class="cautionary" value="View...">
		   </form> 

		  </td> 

		 </tr> 

		<!--/tmpl_loop-->




		</table> 
		</div> 


		<p> 
		 <strong>
		  Cached Screen Preview:
		 </strong> 
		</p>

		<iframe height="500" name="preview" width="100%"></iframe>

	<!-- tmpl_else --> 

		<p class="positive">
		  There are currently no cached screens.
		</p>

	<!--/tmpl_if-->

	<!-- end clear_screen_cache.tmpl --> 
};

}
