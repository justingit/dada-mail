package DADA::App::Messages; 

use lib qw(../../ ../../perllib); 
use Carp qw(croak carp cluck); 

use DADA::Config qw(!:DEFAULT); 
use DADA::App::Guts; 



require Exporter; 
@ISA = qw(Exporter); 

@EXPORT = qw(
  send_generic_email
  send_confirmation_message
  send_unsubscribed_message
  send_subscribed_message
  send_unsubscribe_request_message
  send_owner_happenings
  send_newest_archive
  send_you_are_already_subscribed_message
  
  send_abuse_report
  
  
);


use strict; 
use vars qw(@EXPORT); 



sub send_generic_email {
    my ($args) = @_;

    if ( !exists( $args->{-test} ) ) {
        $args->{-test} = 0;
    }

    my $ls = undef;

    if( exists( $args->{-list})){ 
        if(! defined($args->{-list})){ 
            delete($args->{-list}); 
        }
    }
    if ( exists( $args->{-list} ) ) {
        if ( !exists( $args->{-ls_obj} ) ) {
            require DADA::MailingList::Settings;
            $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );
        }
        else {
            $ls = $args->{-ls_obj};
        }
    }

    # We'll use this, later
	# DEV: strange - passing the -list param should probably be requird... 
    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
        {
            ( exists( $args->{-list} ) )
            ? (
                -list   => $args->{-list},
                -ls_obj => $ls,
              )
            : (),
        }
    );

    # /We'll use this, later

    my $expr = 1;    # Default it to 1, if there's no list.
    if ( exists( $args->{-list} ) ) {
        if ( $ls->param('enable_email_template_expr') == 1 ) {
            $expr = 1;
        }
        else {
            $expr = 0;
        }
    }

    if ( !exists( $args->{-headers} ) ) {
        $args->{-headers} = {};
    }
    if ( !exists( $args->{-headers}->{To} ) ) {
        $args->{-headers}->{To} = $args->{-email};
    }

    if ( !exists( $args->{-tmpl_params} ) ) {
        if ( exists( $args->{-list} ) ) {

            $args->{-tmpl_params} =
              { -list_settings_vars_param => { -list => $args->{-list} } },    # Dev: Probably could just pass $ls?
        }
        else {
            $args->{-tmpl_params} = {};
        }
    }

    my $data = {
          ( exists( $args->{-list} ) )
        ? ( $mh->list_headers, )
        : (), %{ $args->{-headers} }, Body => $args->{-body},
    };

    while ( my ( $key, $value ) = each %{$data} ) {
        $data->{$key} = safely_encode($value);
    }

    require DADA::App::FormatMessages;
    my $fm = undef;

    if ( exists( $args->{-list} ) ) {
        $fm = DADA::App::FormatMessages->new( -List => $args->{-list} );
    }
    else {
        $fm = DADA::App::FormatMessages->new( -yeah_no_list => 1 );
    }
    $fm->use_header_info(1);
    $fm->use_email_templates(0);

    # Some templates always uses HTML::Template::Expr, example, the sending
    # preferences. This makes sure that the correct templating system is validated
    # correctly.
    # As far as I know, this really is only needed for the sending prefs test.
    #
    if ( $args->{-tmpl_params}->{-expr} == 1 ) {
        $fm->override_validation_type('expr');
    }
    my ($email_str) = $fm->format_message( 
		-msg => $fm->string_from_dada_style_args( { -fields => $data, } ), 
	);

    $email_str = safely_decode($email_str);

    my $entity = $fm->email_template(
        {
            -entity => $fm->get_entity( { -data => safely_encode($email_str), } ),
            -expr   => $expr,
            %{ $args->{-tmpl_params} },    # note: this may have -expr param.
			
        }
    );
    my $msg = $entity->as_string;
    my ( $header_str, $body_str ) = split( "\n\n", $msg, 2 );

    my $header_str = safely_decode( $entity->head->as_string );
    my $body_str   = safely_decode( $entity->body_as_string );

    if ( $args->{-test} == 1 ) {
        $mh->test(1);
    }

    $mh->send( $mh->return_headers($header_str), Body => $body_str, );

}


sub send_multipart_email {
	
	# Confirmaiton link still not showig up correctly in email message? 
	
	
    my ($args) = @_;

    if ( !exists( $args->{-test} ) ) {
        $args->{-test} = 0;
    }

    my $ls = $args->{-ls_obj};
	my $list = $ls->param('list');
	
    require DADA::Mail::Send;
    my $mh = DADA::Mail::Send->new(
        {
                -list   => $list,
                -ls_obj => $ls,
        }
    );

    my $expr = 1; 
    if ( $ls->param('enable_email_template_expr') == 1 ) {
        $expr = 1;
    }
    else {
        $expr = 0;
    }

    $args->{-headers} = {}
		if !exists( $args->{-headers} );
	

	#$args->{-tmpl_params} = { -list_settings_vars_param => { -list => $list } },   
	
			
  #  try { 
 	  require  DADA::App::MyMIMELiteHTML; 
      my $mailHTML = new DADA::App::MyMIMELiteHTML(
        #  remove_jscript                   => $remove_javascript,
          'IncludeType'                    => 'cid',
          'TextCharset'                    => scalar $ls->param('charset_value'),
          'HTMLCharset'                    => scalar $ls->param('charset_value'),
          HTMLEncoding                     => scalar $ls->param('html_encoding'),
          TextEncoding                     => scalar $ls->param('plaintext_encoding'),
          (
                ( $DADA::Config::CPAN_DEBUG_SETTINGS{MIME_LITE_HTML} == 1 )
              ? ( Debug => 1, )
              : ()
          ),
          %{$args->{-headers}},
      );
	  
	 my ($status, $errors, $MIMELiteObj, $md5) = $mailHTML->parse(
	 	safely_encode($args->{-html_body}), 
		safely_encode($args->{-plaintext_body})
	);

    use MIME::Parser;
    my $parser = new MIME::Parser;
       $parser = optimize_mime_parser($parser);
	
	my $entity = $parser->parse_data($MIMELiteObj->as_string);
	
	my %lh = $mh->list_headers; 
	for my $h(keys %lh){ 
		$entity->head->add(   $h, safely_encode($lh{$h}));
	}
	
	
	
    my $fm = DADA::App::FormatMessages->new( -List => $list );
    $fm->use_header_info(1);
    $fm->use_email_templates(0);
	

    if ( $args->{-tmpl_params}->{-expr} == 1 ) {
        $fm->override_validation_type('expr');
    }
	
    $entity = $fm->format_message( 
		-entity => $entity,
	);
	
	    $entity = $fm->email_template(
        {
            -entity => $entity,
            -expr   => $expr,
            %{ $args->{-tmpl_params} },    # note: this may have -expr param.
        }
    );
	
    my $msg = $entity->as_string;
    my ( $header_str, $body_str ) = split( "\n\n", $msg, 2 );
	# Time for DADA::Mail::Send to just have a, "Here's th entity!" argument, 
	# rather than always passing this crap back and forth. 
    my $header_str = safely_decode( $entity->head->as_string );
    my $body_str   = safely_decode( $entity->body_as_string );
    if ( $args->{-test} == 1 ) {
        $mh->test(1);
    }
    $mh->send( $mh->return_headers($header_str), Body => $body_str, );

}



sub send_abuse_report {
    
    my ($args) = @_;

    #    -list                 => $list,
    #    -email                => $email,
    #    -abuse_report_details => $abuse_report_details,
    #     -mid => $diagnostics->{'Simplified-Message-Id'},
    
    my $abuse_report_details = $args->{-abuse_report_details}; 
    
	require DADA::MailingList::Settings; 
	my $ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
	
	require DADA::App::FormatMessages; 
    my $fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
    

	require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('list_abuse_report_message.eml'); 

    if(!exists($args->{-mid})){ 
        $args->{-mid} = '00000000000000'; 
    }
    
    require  DADA::MailingList::Subscribers;
    my $lh = DADA::MailingList::Subscribers->new( { -list => $args->{-list} } );
    
    my $worked = $lh->add_subscriber(
        {
            -email      => $args->{-email},
            -list       => $args->{-list},
            -type       => 'unsub_request_list',
            -dupe_check => {
                -enable  => 1,
                -on_dupe => 'ignore_add',
            },
        }
    );
    
    require DADA::App::Subscriptions::ConfirmationTokens;
    my $ct = DADA::App::Subscriptions::ConfirmationTokens->new();
    my $approve_token = $ct->save(
        {
            -email => $args->{-email},
            -data  => {
                list        => $args->{-list},
                type        => 'list',
                mid         => $args->{-mid}, 
                flavor      => 'unsub_request_approve',
                remote_addr => $ENV{REMOTE_ADDR},
            },
            -remove_previous => 0,
        }
    );    
    
    send_generic_email(
        {
            -list    => $args->{-list},
            -headers => {
                To      => $fm->format_phrase_address($msg_data->{to_phrase}, $ls->param('list_owner_email')),
                From    => $fm->format_phrase_address($msg_data->{to_phrase}, $ls->param('list_owner_email')),
# Amazon SES doesn't like that: 
#                From    => '"' . $msg_data->{from_phrase} . '" <' . $args->{-email} . '>',

                Subject => $msg_data->{subject},
            },

            -body => $msg_data->{plaintext_body},
            -tmpl_params => {
                -list_settings_vars_param => { -list => $args->{-list} },
                -subscriber_vars_param    => {
					-list  => $args->{-list}, 
					-email => $args->{-email}, 
					-type  => 'list'
                },
                -vars => {
                    abuse_report_details                  => $abuse_report_details, 
                    list_unsubscribe_request_approve_link => $DADA::Config::S_PROGRAM_URL . '/t/' . $approve_token . '/',
                    
                },
            },
            -test => $args->{-test},
        }
    );

}




sub send_confirmation_message { 

	my ($args) = @_; 
	my $ls;
	if(exists($args->{-ls_obj})){ 
		$ls = $args->{-ls_obj};
	}
	else {
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
	}

	my $html = q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en"><head><link rel="stylesheet" type="text/css" href="css/app.css"><meta http-equiv="Content-Type" content="text/html; charset=utf-8"><meta name="viewport" content="width=device-width"><title>Subject of Message</title></head><body style="-moz-box-sizing:border-box;-ms-text-size-adjust:100%;-webkit-box-sizing:border-box;-webkit-text-size-adjust:100%;Margin:0;box-sizing:border-box;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;min-width:100%;padding:0;text-align:left;width:100%!important"><style>@media only screen{html{min-height:100%;background:#f3f3f3}}@media only screen and (max-width:596px){.small-float-center{margin:0 auto!important;float:none!important;text-align:center!important}.small-text-center{text-align:center!important}.small-text-left{text-align:left!important}.small-text-right{text-align:right!important}}@media only screen and (max-width:596px){.hide-for-large{display:block!important;width:auto!important;overflow:visible!important;max-height:none!important;font-size:inherit!important;line-height:inherit!important}}@media only screen and (max-width:596px){table.body table.container .hide-for-large,table.body table.container .row.hide-for-large{display:table!important;width:100%!important}}@media only screen and (max-width:596px){table.body table.container .callout-inner.hide-for-large{display:table-cell!important;width:100%!important}}@media only screen and (max-width:596px){table.body table.container .show-for-large{display:none!important;width:0;mso-hide:all;overflow:hidden}}@media only screen and (max-width:596px){table.body img{width:auto;height:auto}table.body center{min-width:0!important}table.body .container{width:95%!important}table.body .column,table.body .columns{height:auto!important;-moz-box-sizing:border-box;-webkit-box-sizing:border-box;box-sizing:border-box;padding-left:16px!important;padding-right:16px!important}table.body .column .column,table.body .column .columns,table.body .columns .column,table.body .columns .columns{padding-left:0!important;padding-right:0!important}table.body .collapse .column,table.body .collapse .columns{padding-left:0!important;padding-right:0!important}td.small-1,th.small-1{display:inline-block!important;width:8.33333%!important}td.small-2,th.small-2{display:inline-block!important;width:16.66667%!important}td.small-3,th.small-3{display:inline-block!important;width:25%!important}td.small-4,th.small-4{display:inline-block!important;width:33.33333%!important}td.small-5,th.small-5{display:inline-block!important;width:41.66667%!important}td.small-6,th.small-6{display:inline-block!important;width:50%!important}td.small-7,th.small-7{display:inline-block!important;width:58.33333%!important}td.small-8,th.small-8{display:inline-block!important;width:66.66667%!important}td.small-9,th.small-9{display:inline-block!important;width:75%!important}td.small-10,th.small-10{display:inline-block!important;width:83.33333%!important}td.small-11,th.small-11{display:inline-block!important;width:91.66667%!important}td.small-12,th.small-12{display:inline-block!important;width:100%!important}.column td.small-12,.column th.small-12,.columns td.small-12,.columns th.small-12{display:block!important;width:100%!important}table.body td.small-offset-1,table.body th.small-offset-1{margin-left:8.33333%!important;Margin-left:8.33333%!important}table.body td.small-offset-2,table.body th.small-offset-2{margin-left:16.66667%!important;Margin-left:16.66667%!important}table.body td.small-offset-3,table.body th.small-offset-3{margin-left:25%!important;Margin-left:25%!important}table.body td.small-offset-4,table.body th.small-offset-4{margin-left:33.33333%!important;Margin-left:33.33333%!important}table.body td.small-offset-5,table.body th.small-offset-5{margin-left:41.66667%!important;Margin-left:41.66667%!important}table.body td.small-offset-6,table.body th.small-offset-6{margin-left:50%!important;Margin-left:50%!important}table.body td.small-offset-7,table.body th.small-offset-7{margin-left:58.33333%!important;Margin-left:58.33333%!important}table.body td.small-offset-8,table.body th.small-offset-8{margin-left:66.66667%!important;Margin-left:66.66667%!important}table.body td.small-offset-9,table.body th.small-offset-9{margin-left:75%!important;Margin-left:75%!important}table.body td.small-offset-10,table.body th.small-offset-10{margin-left:83.33333%!important;Margin-left:83.33333%!important}table.body td.small-offset-11,table.body th.small-offset-11{margin-left:91.66667%!important;Margin-left:91.66667%!important}table.body table.columns td.expander,table.body table.columns th.expander{display:none!important}table.body .right-text-pad,table.body .text-pad-right{padding-left:10px!important}table.body .left-text-pad,table.body .text-pad-left{padding-right:10px!important}table.menu{width:100%!important}table.menu td,table.menu th{width:auto!important;display:inline-block!important}table.menu.small-vertical td,table.menu.small-vertical th,table.menu.vertical td,table.menu.vertical th{display:block!important}table.menu[align=center]{width:auto!important}table.button.small-expand,table.button.small-expanded{width:100%!important}table.button.small-expand table,table.button.small-expanded table{width:100%}table.button.small-expand table a,table.button.small-expanded table a{text-align:center!important;width:100%!important;padding-left:0!important;padding-right:0!important}table.button.small-expand center,table.button.small-expanded center{min-width:0}}</style><style type="text/css">table.button.facebook table td{background:#3B5998!important;border-color:#3B5998}table.button.twitter table td{background:#1daced!important;border-color:#1daced}table.button.google table td{background:#DB4A39!important;border-color:#DB4A39}.header{background:#ccc}.header .columns{padding-bottom:0}.header p{color:#0000;margin-bottom:0}.header .wrapper-inner{padding:20px}.header .container{background:#ccc}.wrapper.secondary{background:#ccc}.banner_img{border:1px solid #000}</style><span class="preheader" style="color:#f3f3f3;display:none!important;font-size:1px;line-height:1px;max-height:0;max-width:0;mso-hide:all!important;opacity:0;overflow:hidden;visibility:hidden"></span><table class="body" style="Margin:0;background:#f3f3f3;border-collapse:collapse;border-spacing:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;height:100%;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><td class="center" align="center" valign="top" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><center data-parsed="" style="min-width:580px;width:100%"><table bgcolor="#cccccc" align="center" class="wrapper header float-center" style="Margin:0 auto;border-collapse:collapse;border-spacing:0;float:none;margin:0 auto;padding:0;text-align:center;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><td class="wrapper-inner" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><!-- <container> --><table class="row collapse" style="border-collapse:collapse;border-spacing:0;padding:0;position:relative;text-align:left;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><th class="small-6 large-6 columns first" valign="middle" style="Margin:0 auto;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:0;padding-right:0;text-align:left;width:298px"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left"><img src="http://placehold.it/200x50" class="banner_img" style="-ms-interpolation-mode:bicubic;clear:both;display:block;max-width:100%;outline:0;text-decoration:none;width:auto"></th></tr></table></th><th class="small-6 large-6 columns last" valign="middle" style="Margin:0 auto;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:0;padding-right:0;text-align:left;width:298px"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left"><p class="text-right" style="Margin:0;Margin-bottom:10px;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:right">Subject of Message</p></th></tr></table></th></tr></tbody></table><!-- </container> --></td></tr></table><table class="spacer float-center" style="Margin:0 auto;border-collapse:collapse;border-spacing:0;float:none;margin:0 auto;padding:0;text-align:center;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><td height="25px" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:25px;font-weight:400;hyphens:auto;line-height:25px;margin:0;mso-line-height-rule:exactly;padding:0;text-align:left;vertical-align:top;word-wrap:break-word">&#xA0;</td></tr></tbody></table><table align="center" class="container float-center" style="Margin:0 auto;background:#fefefe;border-collapse:collapse;border-spacing:0;float:none;margin:0 auto;padding:0;text-align:center;vertical-align:top;width:580px"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table class="row" style="border-collapse:collapse;border-spacing:0;display:table;padding:0;position:relative;text-align:left;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><th class="small-12 large-12 columns first last" style="Margin:0 auto;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:16px;padding-right:16px;text-align:left;width:564px"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left"><h1 style="Margin:0;Margin-bottom:10px;color:inherit;font-family:Helvetica,Arial,sans-serif;font-size:34px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left;word-wrap:normal">Ready to Join, My Mailing List?</h1><table align="center" class="container" style="Margin:0 auto;background:#fefefe;border-collapse:collapse;border-spacing:0;margin:0 auto;padding:0;text-align:inherit;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table class="row" style="border-collapse:collapse;border-spacing:0;display:table;padding:0;position:relative;text-align:left;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><th class="small-12 large-12 columns first last" style="Margin:0 auto;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:0!important;padding-right:0!important;text-align:left;width:100%"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left"><center data-parsed="" style="min-width:none!important;width:100%"><table class="button large radius success float-center" style="Margin:0 0 16px 0;border-collapse:collapse;border-spacing:0;float:none;margin:0 0 16px 0;padding:0;text-align:center;vertical-align:top;width:auto"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;background:#3adb76;border:0 solid #3adb76;border-collapse:collapse!important;border-radius:3px;color:#fefefe;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><a href="http://list_confirm_subscribe_link.example.com" style="Margin:0;border:0 solid #3adb76;border-radius:3px;color:#fefefe;display:inline-block;font-family:Helvetica,Arial,sans-serif;font-size:20px;font-weight:700;line-height:1.3;margin:0;padding:10px 20px 10px 20px;text-align:left;text-decoration:none">Click Here to Confirm Your Subscription </a></td></tr></table></td></tr></table></center></th><th class="expander" style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0!important;text-align:left;visibility:hidden;width:0"></th></tr></table></th></tr></tbody></table></td></tr></tbody></table><table class="callout" style="Margin-bottom:16px;border-collapse:collapse;border-spacing:0;margin-bottom:16px;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th class="callout-inner primary" style="Margin:0;background:#def0fc;border:1px solid #444;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:10px;text-align:left;width:100%"><p style="Margin:0;Margin-bottom:10px;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left">Information about my mailing list</p></th><th class="expander" style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0!important;text-align:left;visibility:hidden;width:0"></th></tr></table><table class="callout" style="Margin-bottom:16px;border-collapse:collapse;border-spacing:0;margin-bottom:16px;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th class="callout-inner warning" style="Margin:0;background:#fff3d9;border:1px solid #996800;color:#fefefe;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:10px;text-align:left;width:100%"><p style="Margin:0;Margin-bottom:10px;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left"><strong>Your privacy is important: </strong>This email is part of our <strong>Closed-Loop Opt-In </strong>system and was sent to protect the privacy of the owner of this email address (that's you!). Closed-Loop Opt-In confirmation helps guarantee that only the owner of an email address can subscribe themselves to this mailing list.</p><p style="Margin:0;Margin-bottom:10px;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left"><strong>Privacy Policy for, Mailing List Name: </strong>This is my privacy policy</p></th><th class="expander" style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0!important;text-align:left;visibility:hidden;width:0"></th></tr></table></th></tr></table></th></tr></tbody></table></td></tr></tbody></table><table class="spacer float-center" style="Margin:0 auto;border-collapse:collapse;border-spacing:0;float:none;margin:0 auto;padding:0;text-align:center;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><td height="25px" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:25px;font-weight:400;hyphens:auto;line-height:25px;margin:0;mso-line-height-rule:exactly;padding:0;text-align:left;vertical-align:top;word-wrap:break-word">&#xA0;</td></tr></tbody></table><table style="Margin:0 auto;background-color:#ccc;border-collapse:collapse;border-spacing:0;float:none;margin:0 auto;padding:0;text-align:center;vertical-align:top;width:100%" align="center" class="wrapper float-center"><tr style="padding:0;text-align:left;vertical-align:top"><td class="wrapper-inner" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table style="Margin:0 auto;background:#fefefe;background-color:#ccc;border-collapse:collapse;border-spacing:0;margin:0 auto;padding:0;text-align:inherit;vertical-align:top;width:580px" align="center" class="container"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table style="background-color:#ccc;border-collapse:collapse;border-spacing:0;display:table;padding:0;position:relative;text-align:left;vertical-align:top;width:100%" class="row collapse"><tbody><tr style="padding:0;text-align:left;vertical-align:top"><th class="small-12 large-6 columns first" style="Margin:0 auto;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:0;padding-right:0;text-align:left;width:298px"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left"><h4 style="Margin:0;Margin-bottom:10px;color:inherit;font-family:Helvetica,Arial,sans-serif;font-size:24px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left;word-wrap:normal">Contact</h4><p style="Margin:0;Margin-bottom:10px;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left"><a href="mailto:list_owner@example.com" style="Margin:0;color:#2199e8;font-family:Helvetica,Arial,sans-serif;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left;text-decoration:none">list_owner@example.com</a></p><p style="Margin:0;Margin-bottom:10px;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left">1234 Mockingbird Lane Boulder CO 80301</p></th></tr></table></th><th class="small-12 large-6 columns last" style="Margin:0 auto;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:0;padding-right:0;text-align:left;width:298px"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><th style="Margin:0;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left"><h4 style="Margin:0;Margin-bottom:10px;color:inherit;font-family:Helvetica,Arial,sans-serif;font-size:24px;font-weight:400;line-height:1.3;margin:0;margin-bottom:10px;padding:0;text-align:left;word-wrap:normal">Connect</h4><table class="button small facebook expand" style="Margin:0 0 16px 0;border-collapse:collapse;border-spacing:0;margin:0 0 16px 0;padding:0;text-align:left;vertical-align:top;width:100%!important"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;background:#2199e8;border:2px solid #2199e8;border-collapse:collapse!important;color:#fefefe;font-family:Helvetica,Arial,sans-serif;font-size:12px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:5px 10px 5px 10px;text-align:left;vertical-align:top;word-wrap:break-word"><center data-parsed="" style="min-width:0;width:100%"><a href="http://facebook.com" align="center" class="float-center" style="Margin:0;border:0 solid #2199e8;border-radius:3px;color:#fefefe;display:inline-block;font-family:Helvetica,Arial,sans-serif;font-size:12px;font-weight:700;line-height:1.3;margin:0;padding:5px 10px 5px 10px;padding-left:0;padding-right:0;text-align:center;text-decoration:none;width:100%">Facebook</a></center></td></tr></table></td><td class="expander" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0!important;text-align:left;vertical-align:top;visibility:hidden;width:0;word-wrap:break-word"></td></tr></table><table class="button small twitter expand" style="Margin:0 0 16px 0;border-collapse:collapse;border-spacing:0;margin:0 0 16px 0;padding:0;text-align:left;vertical-align:top;width:100%!important"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;background:#2199e8;border:2px solid #2199e8;border-collapse:collapse!important;color:#fefefe;font-family:Helvetica,Arial,sans-serif;font-size:12px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:5px 10px 5px 10px;text-align:left;vertical-align:top;word-wrap:break-word"><center data-parsed="" style="min-width:0;width:100%"><a href="http://twitter.com" align="center" class="float-center" style="Margin:0;border:0 solid #2199e8;border-radius:3px;color:#fefefe;display:inline-block;font-family:Helvetica,Arial,sans-serif;font-size:12px;font-weight:700;line-height:1.3;margin:0;padding:5px 10px 5px 10px;padding-left:0;padding-right:0;text-align:center;text-decoration:none;width:100%">Twitter</a></center></td></tr></table></td><td class="expander" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0!important;text-align:left;vertical-align:top;visibility:hidden;width:0;word-wrap:break-word"></td></tr></table><table class="button small google expand" style="Margin:0 0 16px 0;border-collapse:collapse;border-spacing:0;margin:0 0 16px 0;padding:0;text-align:left;vertical-align:top;width:100%!important"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word"><table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tr style="padding:0;text-align:left;vertical-align:top"><td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;background:#2199e8;border:2px solid #2199e8;border-collapse:collapse!important;color:#fefefe;font-family:Helvetica,Arial,sans-serif;font-size:12px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:5px 10px 5px 10px;text-align:left;vertical-align:top;word-wrap:break-word"><center data-parsed="" style="min-width:0;width:100%"><a href="http://plus.google.com" align="center" class="float-center" style="Margin:0;border:0 solid #2199e8;border-radius:3px;color:#fefefe;display:inline-block;font-family:Helvetica,Arial,sans-serif;font-size:12px;font-weight:700;line-height:1.3;margin:0;padding:5px 10px 5px 10px;padding-left:0;padding-right:0;text-align:center;text-decoration:none;width:100%">Google+</a></center></td></tr></table></td><td class="expander" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#0a0a0a;font-family:Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0!important;text-align:left;vertical-align:top;visibility:hidden;width:0;word-wrap:break-word"></td></tr></table></th></tr></table></th></tr></tbody></table></td></tr></tbody></table></td></tr></table></center></td></tr></table><!-- prevent Gmail on iOS font size manipulation --><div style="display:none;white-space:nowrap;font:15px courier;line-height:0">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</div></body></html>};


	
	my $confirmation_msg = $ls->param('confirmation_message'); 
	require DADA::App::FormatMessages; 
	my $fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
	   $confirmation_msg = $fm->subscription_confirmationation({-str => $confirmation_msg}); 
	   
	   send_multipart_email(
   		{
			-ls_obj => $ls, 
   			-headers => { 
   			    To              => $fm->format_phrase_address($ls->param('list_name') 
   									. ' Subscriber', $args->{-email}),
   			    Subject         => $ls->param('confirmation_message_subject'),
   			}, 
   			-plaintext_body => $confirmation_msg,
			-html_body      => $html, 
   			-tmpl_params => {
   				-list_settings_vars_param => {-list => $args->{-list}},
   	            -subscriber_vars_param    => {
   					-list  => $args->{-list}, 
   					-email => $args->{-email}, 
   					-type  => 'sub_confirm_list'
   				},
   	            -vars => {
   					'list.confirmation_token' => $args->{-token},
   				},
   			},
			
   			-test => $args->{-test},
   		}
   	); 
	   

=cut
	   
	send_generic_email(
		{
			-list    => $args->{-list}, 
			-headers => { 
			    To              => $fm->format_phrase_address($ls->param('list_name') 
									. ' Subscriber', $args->{-email}),
			    Subject         => $ls->param('confirmation_message_subject'),
			}, 
			
			-body => $confirmation_msg,
				
			-tmpl_params => {
				-list_settings_vars_param => {-list => $args->{-list}},
	            -subscriber_vars_param    => {
					-list  => $args->{-list}, 
					-email => $args->{-email}, 
					-type  => 'sub_confirm_list'
				},
	            -vars => {
					'list.confirmation_token' => $args->{-token},
				},
			},
			
			-test => $args->{-test},
		}
	); 

=cut
	   	
    require       DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;
       $log->mj_log($args->{-list}, 'Subscription Confirmation Sent for ' . $args->{-list} . '.list', $args->{-email});     

}




sub send_subscribed_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	require DADA::App::Subscriptions::Unsub; 
	my $dasu = DADA::App::Subscriptions::Unsub->new({-list => $args->{-list}});
	my $unsub_link = $dasu->unsub_link({-email => $args->{-email}, -mid => '00000000000000'}); 
	$args->{-vars}->{list_unsubscribe_link} = $unsub_link; 


	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
					Subject => $ls->param('subscribed_message_subject'),
			}, 
			-body         => $ls->param('subscribed_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				-vars => $args->{-vars}, 
			},
			-test         => $args->{-test}, 
		}
	); 
	
	# Logging?
	
}



sub send_subscription_request_approved_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	require DADA::App::Subscriptions::Unsub; 
	my $dasu = DADA::App::Subscriptions::Unsub->new({-list => $args->{-list}});
	my $unsub_link = $dasu->unsub_link({-email => $args->{-email}, -mid => '00000000000000'}); 
	$args->{-vars}->{list_unsubscribe_link} = $unsub_link; 

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('subscription_request_approved_message_subject'),
			}, 
			-body         => $ls->param('subscription_request_approved_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				-vars => $args->{-vars}, 
			},
			-test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}




sub send_subscription_request_denied_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('subscription_request_denied_message_subject'),
			}, 
			-body         => $ls->param('subscription_request_denied_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				#-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				#-profile_vars_param       => {-email => $args->{-email}},
				#-vars => $args->{-vars}, 
				-vars => { 
					'subscriber.email' => $args->{-email}, 
					%{$args->{-vars}},
				}
			},
			-test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}



# this is used when the token system is whack, and you request to unsub, uh, "manually"
sub send_unsubscribe_request_message { 
	
	my ($args) = @_;
	
	####
		my $ls;
		if(exists($args->{-ls_obj})){ 
			$ls = $args->{-ls_obj};
		}
		else {
			require DADA::MailingList::Settings; 
			$ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
		}
	####
	
	require DADA::App::ReadEmailMessages; 
    my $rm = DADA::App::ReadEmailMessages->new; 
    my $msg_data = $rm->read_message('unsubscription_request_message.eml'); 
	
	
	my $unsubscription_request_message = $msg_data->{plaintext_body};
	require DADA::App::FormatMessages; 
	my $fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
	   $unsubscription_request_message = $fm->unsubscription_confirmationation({-str => $unsubscription_request_message}); 
	
	require DADA::App::Subscriptions::Unsub; 
	my $dasu = DADA::App::Subscriptions::Unsub->new({-list => $args->{-list}});
	my $unsub_link = $dasu->unsub_link({-email => $args->{-email}, -mid => '00000000000000'}); 
	
	
	send_generic_email(
		{	
		-list        => $args->{-list},
		-ls_obj      => $ls,   
		-headers     => 
			{
					 To      =>  '"'. escape_for_sending($ls->param('list_name')) .' Subscriber"  <' . $args->{-email} . '>',
					 Subject =>  $msg_data->{subject}, 
			},
				
	    -body        => $unsubscription_request_message, 
		-tmpl_params => {
			-list_settings_vars_param => {
				-list => $args->{-list}
			},
            -subscriber_vars_param    => {
				-list  => $args->{-list}, 
				-email => $args->{-email}, 
				-type  => 'list'
			},
            -vars                     => {
#				'list.confirmation_token' => $args->{-token},
				list_unsubscribe_link => $unsub_link,
			},
			},
			-test         => $args->{-test},
		}
	); 
	
    require DADA::Logging::Usage;
    my $log = new DADA::Logging::Usage;
       $log->mj_log($args->{-list}, 'Unsubscription Confirmation Sent for ' . $args->{-list} . '.list', $args->{-email});     
 
}

sub subscription_approval_request_message { 
	
	my ($args) = @_;
	my $ls = $args->{-ls_obj}; 
	send_generic_email(
        {
            -list    => $ls->param('list'),
            -headers => {
                To => '"'
                  . escape_for_sending( $ls->param('list_name') )
                  . '" <'
                  . $ls->param('list_owner_email') . '>',
                Subject => $ls->param(
                    'subscription_approval_request_message_subject'),
            },
            -body =>
              $ls->param('subscription_approval_request_message'),
            -tmpl_params => {
                -list_settings_vars_param =>
                  { -list => $ls->param('list') },
                -subscriber_vars_param => {
                    -list  => $ls->param('list'),
                    -email => $args->{-email},
                    -type  => 'sub_request_list'
                },
                -vars => {
					%{$args->{-vars}},
				},
            },
            -test => $args->{-test},
        }
    );
}

sub unsubscription_approval_request_message { 

	my ($args) = @_;
	my $ls = $args->{-ls_obj}; 
	
	send_generic_email(
     {
         -list    => $ls->param('list'),
         -headers => {
             To => '"'
               . escape_for_sending( $ls->param('list_name') )
               . '" <'
               . $ls->param('list_owner_email') . '>',
             Subject => $ls->param(
                 'unsubscription_approval_request_message_subject'),
         },
         -body =>
           $ls->param('unsubscription_approval_request_message'),
         -tmpl_params => {
             -list_settings_vars_param =>
               { -list => $ls->param('list') },
             -subscriber_vars_param => {
                 -list  => $ls->param('list'),
                 -email => $args->{-email},
                 -type  => 'unsub_request_list'
             },
             -vars => {
				%{$args->{-vars}},
			},
         },
         -test => $args->{-test},
     }
 );
}






sub send_unsubscribed_message { 
	
	my ($args) = @_; 
	
	if(!exists($args->{-test})){ 
		$args->{-test} = 0; 
	}
	
	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
	
	
	# This is a hack - if the subscriber has recently been removed, you 
	# won't be able to get the subscriber fields - since there's no way to 
	# get fields of a removed subscriber. 
	# So! We'll go and grab the profile info, instead. 
	my $prof_fields  = {};
	my $unsub_fields = {};
		$unsub_fields->{ 'subscriber.email'} = $args->{-email};
		(
			$unsub_fields->{ 'subscriber.email_name'},
			$unsub_fields->{ 'subscriber.email_domain'}
		) = split(
			'@', 
			$args->{-email},
			2
		);
		require DADA::Profile; 
		my $prof = DADA::Profile->new({-email => $args->{-email}});
		if($prof){ 
			if($prof->exists){ 
				$prof_fields = $prof->{fields}->get;
				for ( keys %$prof_fields ) {
		            $unsub_fields->{ 'subscriber.' . $_ } = $prof_fields->{$_};
		        } 					
			}
		}
	#/This is a hack - if the subscriber has recently been removed, you
	
	require DADA::App::FormatMessages; 
    my $fm = DADA::App::FormatMessages->new(-List => $args->{-list}); 
	
	
	send_generic_email(
		{

			-list        => $args->{-list},
			-ls_obj      => $ls,
			-email       => $args->{-email}, 
			-headers => { 	
				To           => $fm->format_phrase_address($ls->param('list_name'), $args->{-email}),
				Subject      => $ls->param('unsubscribed_message_subject'), 
			},
			-body    => $ls->param('unsubscribed_message'),

			-test         => $args->{-test}, 
			
			-tmpl_params  => {	
				-list_settings_vars_param => 
					{
                        -list => $ls->param('list'),
						-dot_it => 1, 
					}, 
				#-subscriber_vars => {'subscriber.email' => $args->{-email}}, # DEV: This line right?
				-subscriber_vars          => $unsub_fields,
			},
		}
	); 
	
	# DEV: Logging?
}


sub send_owner_happenings {

    my ($args) = @_;

    my $ls;
    if ( !exists( $args->{-ls_obj} ) ) {
        require DADA::MailingList::Settings;
        $ls = DADA::MailingList::Settings->new( { -list => $args->{-list} } );
    }
    else {
        $ls = $args->{-ls_obj};
    }

    if ( !exists( $args->{-role} ) ) {
        $args->{-role} = 'subscribed';
    }
    my $status = $args->{-role};

    if ( !exists( $args->{-note} ) ) {
        $args->{-note} = '';
    }

    if ( $status eq "subscribed" ) {
        if ( $ls->param('get_sub_notice') == 0 ) {
            return;
        }
    }
    elsif ( $status eq "unsubscribed" ) {
        if ( $ls->param('get_unsub_notice') == 0 ) {
            return;
        }
    }

    my $lh;
    if ( $args->{-lh_obj} ) {
        $lh = $args->{-lh_obj};
    }
    else {
        $lh =
          DADA::MailingList::Subscribers->new( { -list => $args->{-list} } );
    }
    my $num_subscribers = $lh->num_subscribers;

    # This is a hack - if the subscriber has recently been removed, you
    # won't be able to get the subscriber fields - since there's no way to
    # get fields of a removed subscriber.
    # So! We'll go and grab the profile info, instead.
    my $prof_fields  = {};
    my $unsub_fields = {};
    if ( $status eq "unsubscribed" ) {
        $unsub_fields->{'subscriber.email'} = $args->{-email};
        (
            $unsub_fields->{'subscriber.email_name'},
            $unsub_fields->{'subscriber.email_domain'}
        ) = split( '@', $args->{-email}, 2 );

        require DADA::Profile;
        my $prof = DADA::Profile->new( { -email => $args->{-email} } );
        if ($prof) {
            if ( $prof->exists ) {
                $prof_fields = $prof->{fields}->get;
                for ( keys %$prof_fields ) {
                    $unsub_fields->{ 'subscriber.' . $_ } = $prof_fields->{$_};
                }
            }
        }
    }

    my $msg_template = {
        subject => '',
        msg     => '',
    };
    if ( $status eq "subscribed" ) {
        $msg_template->{subject} =
          $ls->param('admin_subscription_notice_message_subject');
        $msg_template->{msg} = $ls->param('admin_subscription_notice_message');
    }
    elsif ( $status eq "unsubscribed" ) {
        $msg_template->{subject} =
          $ls->param('admin_unsubscription_notice_message_subject');
        $msg_template->{msg} =
          $ls->param('admin_unsubscription_notice_message');
    }

    require DADA::Template::Widgets;
    for (qw(subject msg)) {
        my $tmpl    = $msg_template->{$_};
        my $content = DADA::Template::Widgets::screen(
            {
                -data => \$tmpl,
                -vars => {
                    num_subscribers => $num_subscribers,
                    status          => $status,
                    note            => $args->{-note},
                    REMOTE_ADDR     => $ENV{REMOTE_ADDR},

                },
                -list_settings_vars_param => { -list => $args->{-list} },
                ( $status eq "subscribed" )
                ? (
                    -subscriber_vars_param => {
                        -list  => $args->{-list},
                        -email => $args->{-email},
                        -type  => 'list'
                    },
                  )
                : ( -subscriber_vars => $unsub_fields, )
            }
        );
        $msg_template->{$_} = $content;

    }

    require DADA::App::FormatMessages;
    my $fm = DADA::App::FormatMessages->new( -List => $args->{-list} );
    $fm->use_email_templates(0);

    my $send_to = 'list_owner';
    if ( $status eq "subscribed" ) {
        $send_to = $ls->param('send_subscription_notice_to');
    }
    else {
        $send_to = $ls->param('send_unsubscription_notice_to');
    }
    
    my $from_address = $ls->param('list_owner_email');
    my $formatted_from = $fm->_encode_header(
        'From',
        $fm->format_phrase_address(
            $ls->param('list_name'),
            $from_address,
        )
    );
    
    
    if ( $send_to eq 'list') {
        $fm->mass_mailing(1);
        require DADA::Mail::Send;
        my $mh = DADA::Mail::Send->new( { -list => $args->{-list} } );
        $mh->list_type('list');
        my $message_id = $mh->mass_send(
            {
                -msg => {
                    From    => $formatted_from,
                    Subject => $msg_template->{subject},
                    Body    => $msg_template->{msg},
                },
            }
        );

    }
    elsif($send_to eq 'list_owner' || $send_to eq 'alt') {  
        my $to = $formatted_from;
        if($send_to eq 'alt' && $status eq "subscribed" && check_for_valid_email($ls->param('alt_send_subscription_notice_to')) == 0) { 
            $to = $ls->param('alt_send_subscription_notice_to'); 
        }
        if($send_to eq 'alt' && $status eq "unsubscribed" && check_for_valid_email($ls->param('alt_send_unsubscription_notice_to')) == 0) { 
            $to = $ls->param('alt_send_unsubscription_notice_to'); 
        } 
        send_generic_email(
            {
                -list    => $args->{-list},
                -headers => {
                    To      => $to,
                    From    => $formatted_from,
                    Subject => $msg_template->{subject},
                },
                -body => $msg_template->{msg},
                -test => $args->{-test},
            }

        );
    }
    else { 
        die "who am I sending to?!"; 
    }   
}


sub send_you_are_already_subscribed_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
		
	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
        
		-headers => { 
			To           => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
			Subject      => $ls->param('you_are_already_subscribed_message_subject'), 
		},
		
		-body         => $ls->param('you_are_already_subscribed_message'), 
		
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $ls->param('list'),},
			-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
		},
		
		-test         => $args->{-test}, 
		}
	);
	
}




sub send_not_subscribed_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}
		
	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
        
		-headers => { 
			To           => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
			Subject      => $ls->param('you_are_not_subscribed_message_subject'), 
		},
		
		-body         => $ls->param('you_are_not_subscribed_message'), 
		
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $ls->param('list'),},
			-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
		},
		-test         => $args->{-test}, 
		}
	);
	
}


sub send_newest_archive { 

	# Gonna leave this as it is for now...
	my ($args) = @_; 
	
	die "no list!"         if ! exists($args->{-list}); 
	die "no email!"        if ! exists($args->{-email}); 

	
	if(! exists($args->{-test})){ 
		$args->{-test} = 0;
	}
		


	####
		my $ls;
		if(exists($args->{-ls_obj})){ 
			$ls = $args->{-ls_obj};
		}
		else {
			require DADA::MailingList::Settings; 
			$ls = DADA::MailingList::Settings->new({-list => $args->{-list}});
		}
	####

	####
		my $la;
		if(exists($args->{-la_obj})){ 
			$la = $args->{-la_obj};
		}
		else {
			require DADA::MailingList::Archives; 
			$la = DADA::MailingList::Archives->new(
					{
						-list => $args->{-list}
					}
				);
		}
	
	####




    my $newest_entry = $la->newest_entry; 

	
	if(
		defined($newest_entry) && 
		$newest_entry      > 1
	){ 
		
		my ($head, $body) = $la->massage_msg_for_resending(
								-key     => $newest_entry, 
								'-split' => 1,
							);
							
		require DADA::Mail::Send; 
		my $mh = DADA::Mail::Send->new(
					{
						-list   => $args->{-list}, 
						-ls_obj => $ls,
					}
				);
		
		if($args->{-test} == 1){ 
			$mh->test(1);	
		}
		

		
		
		send_generic_email(
			{
	    	-list         => $args->{-list}, 
	        -email        => $args->{-email}, 
	        -ls_obj       => $ls, 

			-headers => { 
						 $mh->return_headers($head),  
					  	 To             => '"'. escape_for_sending($ls->param('list_name')) .' Subscriber" <'. $args->{-email} .'>',
			},

			-body         => $body, 

			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
			},

			-test         => $args->{-test}, 
			}
		);
		
	
		return 1;
	}
	else { 
		return 0; 
	}
}



# This one's weird, since it's a part of Bridge 

sub send_not_allowed_to_post_msg { 
	
	my ($args) = @_; 

	require MIME::Entity; 
	
	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

#        	my $attachment;
#        	if(!exists($args->{-attachment})){ 
#        		croak "I need an attachment in, -attachment!"; 
#        	}
#        	else { 
#        		$attachment = $args->{-attachment}; 
#        	}
	

	my $reply = MIME::Entity->build(Type 	=> "multipart/mixed", 
									Subject => $ls->param('not_allowed_to_post_msg_subject'),
									%{$args->{-headers}},
									To           => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
									);
									
	$reply->attach(
				   Type     => 'text/plain', 
				   Encoding => $ls->param('plaintext_encoding'),
				   Data     => $ls->param('not_allowed_to_post_msg'),
				  ); 
				
#	$reply->attach( Type        => 'message/rfc822', 
#					Disposition  => "attachment",
#					Data         => $attachment,
#					); 


	# This is weird. I sorta want to do this myself, but maybe I'll just let, 
	# send_generic_email sort it all out...
	
	my $msg_str = $reply->as_string; 
	my ($headers, $body) = split("\n\n", $msg_str, 2);
	my %headers = _mime_headers_from_string($headers);  

	# well, I guess three lines ain't that bad; 


	send_generic_email(
		{
    	-list         => $args->{-list}, 
        -email        => $args->{-email}, 
        -ls_obj       => $ls, 
		-headers => { 
			%headers, 
		},
		-body         => $body, 
		-tmpl_params  => {		
			-list_settings_vars_param => {-list => $args->{-list}},
			#-subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
			-subscriber_vars => 
				{
					'subscriber.email' => $args->{-email}
				},
			-vars => { 
			   original_subject => $args->{-original_subject},  
			}, 
		},

		-test         => $args->{-test}, 
		}
	);

}

sub send_unsubscription_request_approved_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('unsubscription_request_approved_message_subject'),
			}, 
			-body         => $ls->param('unsubscription_request_approved_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
                -subscriber_vars => 
    				{
    					'subscriber.email' => $args->{-email}
    				},
				# -subscriber_vars_param    => {-list => $ls->param('list'), -email => $args->{-email}, -type => 'list'},
				# -profile_vars_param       => {-email => $args->{-email}},
				# -vars => $args->{-vars}, 
			},
			# -test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}




sub send_unsubscription_request_denied_message { 

	my ($args) = @_; 

	my $ls; 
	if(!exists($args->{-ls_obj})){ 
		require DADA::MailingList::Settings; 
		$ls = DADA::MailingList::Settings->new({-list => $args->{-list}}); 
	}
	else { 
		$ls = $args->{-ls_obj};
	}

	if(!exists($args->{-vars})){ 
		$args->{-vars} = {};
	}

	send_generic_email (
		{
			-list         => $args->{-list}, 
			-headers      => {
					To      => '"'. escape_for_sending($ls->param('list_name')) .'" <'. $args->{-email} .'>',
					Subject => $ls->param('unsubscription_request_denied_message_subject'),
			}, 
			-body         => $ls->param('unsubscription_request_denied_message'),
			-tmpl_params  => {		
				-list_settings_vars_param => {-list => $ls->param('list'),},
				-subscriber_vars => 
    				{
    					'subscriber.email' => $args->{-email}
    				},
				-vars => { 
					'subscriber.email' => $args->{-email}, 
					%{$args->{-vars}},
				}
			},
			# -test         => $args->{-test}, 
		}
	); 
	# Logging?
	
}





sub _mime_headers_from_string { 

	#get the blob
	my $header_blob = shift || "";


	#init a new %hash
	my %new_header;

	# split.. logically
	my @logical_lines = split /\n(?!\s)/, $header_blob;
 
	    # make the hash
	    for my $line(@logical_lines) {
	          my ($label, $value) = split(/:\s*/, $line, 2);
	          $new_header{$label} = $value;
	        }
		
	return %new_header; 

}


1;


=pod

=head1 COPYRIGHT 

Copyright (c) 1999 - 2016 Justin Simoni All rights reserved. 

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

