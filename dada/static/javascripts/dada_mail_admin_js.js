$jq(document).ready(function() {
			
		//Mail Sending >> Send a Message 
		if($jq("#send_email_screen").length || $jq("#send_url_email").length || $jq("#list_invite").length){ 
			
			$jq("#mass_mailing").on("submit", function(event){ 
				event.preventDefault();
			});
			$jq(".sendmassmailing").on("click", function(event){ 
				//var fid = $jq(event.target).closest('form').attr('id'); 
				var fid = 'mass_mailing';
				
				var itsatest = $jq(this).hasClass("justatest");
				var submit_it = sendMailingListMessage(fid, itsatest);
				if(submit_it == true) { 
					$jq('#' + fid).off('submit');
					$jq('#' + fid).submit();
				}
				else { 
					//alert("It stays off!"); 
				}
			});	
			$jq(".ChangeMassMailingButtonLabel").on("click", function(event){ 
				ChangeMassMailingButtonLabel();	
			}); 

			ChangeMassMailingButtonLabel();
			$jq( "#tabs" ).tabs();
		}

		if($jq("#send_email_screen").length){ 

			
			if($jq("#using_ckeditor").length){ 
				$jq(".html_message_body" ).ckeditor(
					function() {}, 
					{
						customConfig : '../ckeditor/dada_mail_config.js',	
						toolbar :      'DadaMail_Admin'
					}
				);
			}
			
		}
		// Mail Sending >> Send a Webpage
		if($jq("#send_url_email").length){ 

			
			if($jq("#using_ckeditor").length){ 
				$jq(".html_message_body" ).ckeditor(
					function() {}, 
					{
						customConfig : '../ckeditor/dada_mail_config.js',	
						toolbar :      'DadaMail_Admin'
					}
				);
			}
			
			
			
		}
		
		// Mail Sending >> Mailing Monitor Index
		if($jq("#sending_monitor_index").length){ 
			refreshpage(60,  $jq("#s_program_url").val() + "?f=sending_monitor"); 
		}
		
		if($jq("#sending_monitor_container").length || $jq("#sending_monitor_index").length){
			$jq('body').on('submit','.stop_mass_mailing', function(event) {
				event.preventDefault();
			});
			$jq('body').on('click', '.killMonitoredSending',  function(event){ 
				//var fid = 'stop_mass_mailing';
				var submit_it = killMonitoredSending();
				if(submit_it == true) { 
					$jq('body').off('submit', '.stop_mass_mailing');
					$jq(event.target).closest('form').submit(); 
				}
				else { 
					// alert("It stays off!"); 
				}
			});
		} 


		if($jq("#sending_monitor_container").length){ 

			update_sending_monitor_interface(
				$jq("#message_id").val(), 
				$jq("#message_type").val(), 
				$jq("#target_id").val(),
				$jq("#refresh_after").val()
			);
			
			$jq('body').on('submit','#pause_mass_mailing', function(event) {
				event.preventDefault();
			});			
			$jq('body').on('click', '.pauseMonitoredSending',  function(event){ 
				//var fid = $jq(event.target).closest('form').attr('id'); 
				var fid = 'pause_mass_mailing';
				var submit_it = pauseMonitoredSending();
				if(submit_it == true) { 
					$jq('body').off('submit', '#pause_mass_mailing');
					$jq('#' + fid).submit();
				}
				else { 
					// alert("It stays off!"); 
				}
			});
			
			if($jq("#tracker_reports").length){ 
				refresh_tracker_plugin(
					$jq("#tracker_url").val(),
					$jq("#message_id").val(), 
					'tracker_reports_container'
				); 
			}
			
			
		}
		
		
		// Membership >> View List	
		if($jq("#view_list_viewport").length) { 
			view_list_viewport(1);	
		}
		
		// Membership >> List Activity
		if($jq("#list_activity").length){ 
			google.setOnLoadCallback(sub_unsub_trend_chart());
		}
		// Membership >> user@example.com
		if($jq("#mailing_list_history").length) { 
			mailing_list_history();
		}
		
		// Membership >> Invite/Add
		if($jq("#add").length) { 
			$jq("#add_one").hide(); 
			$jq("#show_progress").hide(); 
			$jq("#fileupload").live("submit", function(event) {
				check_status();
			});
		}
		
		// Membership >> Add (step 2) 
		if($jq("#add_email").length) { 			
			$jq("#confirm_add").on("submit", function(event){ 
				event.preventDefault();
			});
			$jq(".addingemail").on("click", function(event) { 
				var go = 1; 
				if($jq(this).hasClass("warnAboutMassSubscription")){ 
					go = warnAboutMassSubscription(); 
				}
				if(go == true){ 
					$jq('#confirm_add').off('submit');
					$jq('#confirm_add').submit();
				}
			});
		}
		
				
		// Membership >> Invite
		if($jq("#list_invite").length){ 
			$jq("#customize_invite_message_form").hide(); 
			$jq('.show_customize_invite_message').live("click", function(event) { 
				event.preventDefault();
				show_customize_invite_message(); 
			});
		}
		// Mail Sending >> Sending Preferences 
		if($jq("#sending_preferences").length) { 
			if($jq("#has_needed_cpan_modules").length){ 
				amazon_ses_get_stats();
			}
		}
		
		// Mail Sending >> Adv Sending Preferences
		if($jq("#adv_sending_preferences").length) { 
			$jq("#misc_options").hide(); 
		}
		// Mail Sending >> Mass Mailing Preferences 
		if($jq("#mass_mailing_preferences").length){ 
			if($jq("#amazon_ses_get_stats").length) { 
				amazon_ses_get_stats(); 
			}
			else { 
				// amazon_ses_get_stats does a previewBatchSendingSpeed(), 
				// so no need to do it, twice. 
				previewBatchSendingSpeed();
			}
			toggleManualBatchSettings(); 
		}
		
	
	// Membership >> View List
	$jq(".change_type").live("click", function(event){
		change_type($jq(this).attr("data-type"));
		event.preventDefault();
	});
	$jq(".turn_page").live("click", function(event){
		turn_page($jq(this).attr("data-page"));
		event.preventDefault();
	});
	$jq(".change_order").live("click", function(event){
		change_order($jq(this).attr("data-by"), $jq(this).attr("data-dir"));
		event.preventDefault();
	});
	$jq(".search_list").live("click", function(event){			
		search_list();
		event.preventDefault();
	});
	$jq("#search_form").live("submit", function(event) {
    	search_list();
		event.preventDefault();
	});
	$jq(".clear_search").live("click", function(event){
		clear_search();
		event.preventDefault();
	});
	$jq('#search_query').live('keydown', function(){	
		$jq( "#search_query" ).autocomplete({
			source: function( request, response ) {
				$jq.ajax({
					url: $jq("#s_program_url").val(),
					type: "POST",
					dataType: "json",
					data: {
						f: 'search_list_auto_complete',
						length: 10,
						type: $jq("#type").val(),
						query: request.term
					},
					success: function( data ) {
						response( $jq.map( data, function( item ) {
							return {
								value: item.email,
							}
						}));
					},
					error: function(){ 
						alert('something is wrong');
					},
				});
			},
			minLength: 3,
			open: function() {
				$jq( this ).removeClass( "ui-corner-all" ).addClass( "ui-corner-top" );
			},
			close: function() {
				$jq( this ).removeClass( "ui-corner-top" ).addClass( "ui-corner-all" );
			}
		});
	});
	
	// Membership >> user@example.com
	$jq(".change_profile_password").live("click", function(event){
		show_change_profile_password_form();
		event.preventDefault();
	});
	
	// Mail Sending >> Sending Preferences 
    $jq(".test_sending_preferences").live("click", function(event){ 
		event.preventDefault();
		test_sending_preferences();
	});

    $jq(".amazon_verify_email").live("click", function(event){ 
		event.preventDefault();
		amazon_verify_email();
	});
	
	
	
	// Mail Sending >> Mass Mailing Preferences 
	$jq(".previewBatchSendingSpeed").live("change", function(event){ 
		previewBatchSendingSpeed();
	});

	$jq("#amazon_ses_auto_batch_settings").live("click", function(event){ 
		toggleManualBatchSettings();
	});
	
	
	// Version Check 
	$jq('#check_version').live('click',  function(event){ 
		event.preventDefault();
		check_newest_version($jq('#check_version').attr("data-ver")); 
	}); 
	
	// Installer 

	if($jq("#install_or_upgrade").length){ 
		$jq('.installer_changeDisplayStateDivs').live("click", function(event){ 
			changeDisplayState($jq(this).attr("data-target"), $jq(this).attr("data-state")); 
		});
	}
	if($jq("#installer_configure_dada_mail").length){ 
		$jq("#backend").on("change", function(event){ 
			installer_toggleSQL_options();	
		});
		$jq('.radiochangeDisplayState').live("click",  function(event){ 
			changeDisplayState($jq(this).attr("data-target"), $jq(this).attr("data-state")); 
		});
		
		installer_toggleSQL_options();
	}
	if($jq("#installer_install_dada_mail").length){ 
		$jq('#move_installer_dir').live("click",  function(event){ 
			event.preventDefault();
			installer_move_installer_dir(); 
		});	
	}

	// Plugins >> Bounce Handler 
	if($jq("#plugins_bounce_handler_default").length) { 
		bounce_handler_show_scorecard();
		  $jq("body").on("click", '.bounce_handler_turn_page', function(event){
			bounce_handler_turn_page($jq(this).attr("data-page"));
			event.preventDefault();
		});		
	}
	if($jq("#plugins_bounce_handler_parse_bounce").length){ 
		bounce_handler_parse_bounces(); 
		$jq("#parse_bounces_button").on("click", function(event){ 
			bounce_handler_parse_bounces(); 
		}); 
	}
	
	// Plugins >> Dada Bridge
	if($jq("#plugins_bridge_default").length) { 
		
		$jq(".plugins_bridge_test_pop3").live("click", function(event){ 
			event.preventDefault();
			plugins_bridge_test_pop3();
		});
		
		
		$jq(".plugins_bridge_manually_check_messages").live("click", function(event){ 
			event.preventDefault();
			plugins_bridge_manually_check_messages();
		});
		
		
		
		
	    
	}
	
	// Plugins >> Mailing Monitor
	if($jq("#plugins_mailing_monitor_default").length){ 
		
		plugins_mailing_monitor();
		$jq("#mailing_monitor_button").live("click", function(event){ 
			event.preventDefault();
			plugins_mailing_monitor();
		});	

	}
	
	// Plugins >> Tracker
	if($jq("#plugins_tracker_message_report").length) { 
		update_plugins_tracker_message_report(); 
	}
	if($jq("#plugins_tracker_default").length) { 
		  tracker_show_table();	
		  google.setOnLoadCallback(drawSubscriberHistoryChart());
		
		  $jq("body").on("click", '.tracker_turn_page', function(event){
			tracker_turn_page($jq(this).attr("data-page"));
			event.preventDefault();
		});
		$jq("body").on("click", '.tracker_purge_log', function(event){ 
			tracker_purge_log();
			event.preventDefault();
		});	
	}
	// Plugins >> Password Protect Directories
	if($jq("#plugins_password_protect_directories_default").length) { 
		$jq("#change_password_button").live("click", function(event){ 
			password_protect_directories_show_change_password_form();
		});
	}
	
	// Plugins >> Log Viewer
	if($jq("#plugin_log_viewer_default").length){ 
		view_logs_results();
		
		$jq("#log_name").on("change", function(event){ 
			view_logs_results();		
	    });	
		$jq("#lines").on("change", function(event){ 
			view_logs_results();		
	    });
		$jq("#refresh_button").on("click", function(event){ 
			view_logs_results();		
	    });
		$jq("#delete_log").on("click", function(event){ 
			delete_log();
		}); 
		
	
	
	
	
		
		
		
	}



	/* Global */ 
	$jq(".previous").live("click", function(event){
		event.preventDefault();
		history.back();
	}); 
	
	$jq(".fade_me").live("click", function(event){
		$jq('#alertbox').effect( 'fade' );
		event.preventDefault();
	});

	$jq('.toggleCheckboxes').live("click", function(event){	
		toggleCheckboxes(
			$jq(this).prop("checked"), 
			$jq(this).attr("data-target_class")
		);
	});
	$jq('.linkToggleCheckboxes').live("click", function(event){	
		event.preventDefault();
		var state = true; 
		if($jq(this).attr("data-state") == "false"){ 
			state = false; 
		}
		toggleCheckboxes(
			state,
			$jq(this).attr("data-target_class")
		);
	}); 
	
	$jq('.toggleDivs').live("click", function(event){ 
		event.preventDefault();
		toggleDisplay($jq(this).attr("data-target")); 
	}); 
	$jq('.radio_toggleDivs').live("click", function(event){ 
		toggleDisplay($jq(this).attr("data-target")); 
	});

	
});



// Mass Mailings >> Monitor Your Mailings 

function update_sending_monitor_interface(message_id, type, target_id, refresh_after) { 	 
	var r = refresh_after * 1000;
	var refresh_loop = function(no_loop) { 
		var request = $jq.ajax({
		  url: 	$jq("#s_program_url").val(),
		  type: "POST",
		  cache: false,
		  data: {
			f:    'sending_monitor',
			id:   message_id, 
			type: type,
			process:      'ajax'
		  },
		  dataType: "html"
		});
		request.done(function(content) {
		  $jq("#" + target_id).html(content);
	 	  $jq( "#progressbar" ).progressbar({value: ($jq("#progressbar_percent").val()/1)});
		});
		if(no_loop != 1){ 
			setTimeout(
				refresh_loop,
				r
			);
		}
	}
	setTimeout(
		refresh_loop,
		r
	);
	refresh_loop(1);
}
function refresh_tracker_plugin(tracker_url, message_id, target_id) { 	
	var tracker_refresh_loop = function(no_loop) { 
		$jq("#tracker_reports_container").load(tracker_url, 
			{
				chrome: 0, 
				f:     "m", 
				mid:    message_id
			}, 
			function() {
				update_plugins_tracker_message_report();
			}
		);
		if(no_loop != 1){ 
			setTimeout(
				tracker_refresh_loop,
				180000
			);
		}
	}
	setTimeout(
		tracker_refresh_loop,
		180000
	);
	tracker_refresh_loop(1);
}



// Membership >> Invite/Add

function check_status(){ 
		$jq("#show_progress").show();
		keep_updating_status_bar = 1; 
		update_status_bar();
}

var keep_updating_status_bar = 0; 
function update_status_bar(){ 
	
	var update_status_bar_loop = function(no_loop) { 
		
		if(keep_updating_status_bar == 0){ 
			return; 
		}
		// console.log('update_status_bar_loop called'); 
		var request = $jq.ajax({
			url: $jq("#s_program_url").val(),
			type: "GET",
				data: {
					f : 'check_status',
					new_email_file: $jq('#new_email_file').val(),
					rand_string: $jq('#rand_string').val()
				},
			dataType: "json",
			success: function( data ) {
				//console.log('data.percent:"' + data.percent +  '"'); 
				 //$jq.each(data, function(key, val) {
				//		console.log(key + ' => ' + val); 
				//});
				if(data.percent > 0) { 
					$jq("#progressbar").progressbar({ value: data.percent});
					$jq('#upload_status').html('<p>Uploading File: ' + data.percent + '%</p>');
					if(data.percent == 100) { 
						keep_updating_status_bar = 0;
						no_loop = 1;
						$jq('#upload_status').html('<p>Upload Complete! Processing...</p>');
					}
				//console.log('done?'); 
				}
			},				
			error: function (xhr, ajaxOptions, thrownError) {
			     	 console.log('status: ' + xhr.status);
			    	console.log('thrownError:' + thrownError);
			}
		});
		if(no_loop != 1){ 
			setTimeout(
				update_status_bar_loop,
				1000
			);
		}
	}
	setTimeout(
		update_status_bar_loop,
		1000
	);
}



/* Membership >> View List */
function view_list_viewport(initial){ 	
	$jq("#view_list_viewport_loading").html( '<p class="alert">Loading...</p>' );
	var request = $jq.ajax({
	  url: $jq("#s_program_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
		f:         'view_list',
		mode:      'viewport', 
		type:      $jq("#type").val(),
		page:      $jq("#page").val(),
		query:     $jq("#query").val(),
		order_by:  $jq("#order_by").val(),
		order_dir: $jq("#order_dir").val()
	  },
	  dataType: "html"
	});
	request.done(function(content) {
		
		if(initial == 1){ 
			$jq("#view_list_viewport").hide();
			$jq("#view_list_viewport").html( content );
			$jq("#view_list_viewport").show('fade');
		}
		else { 
			$jq("#view_list_viewport").html( content );
		}
		
		$jq("#view_list_viewport_loading").html( '<p class="alert">&nbsp;</p>' );
	
			google.setOnLoadCallback(drawTrackerDomainBreakdownChart());
	});
}
function turn_page(page_to_turn_to) { 
	$jq("#page").val(page_to_turn_to);
	view_list_viewport();
}
function change_type(type_to_go_to) { 
	$jq("#type").val(type_to_go_to);
	$jq("#page").val(1); 
	view_list_viewport();
}
function search_list(){ 
	$jq("#page").val(1); 
	$jq("#query").val($jq("#search_query").val()); 
	view_list_viewport();
}
function clear_search(){ 
	$jq("#query").val(''); 
	$jq("#page").val(1); 
	view_list_viewport(); 
}
function change_order(order_by, order_dir) { 
	$jq("#order_by").val(order_by); 
	$jq("#order_dir").val(order_dir); 
	$jq("#page").val(1); 
	view_list_viewport();	 
}

var domain_breakdown_chart; // you've got to be serious... 
var domain_breakdown_chart_data; 
function drawTrackerDomainBreakdownChart() { 
	$jq("#domain_break_down_chart_loading").html( '<p class="alert">Loading...</p>' );
    $jq.ajax({
		  url: $jq("#s_program_url").val(),
          dataType:"json",
			data: {
				f:      'domain_breakdown_json',
				type:    $jq("#type").val(),
			},
          async: true,
		success: function( jsonData ) {
		      domain_breakdown_chart_data = new google.visualization.DataTable(jsonData);
		      domain_breakdown_chart = new google.visualization.PieChart(document.getElementById('domain_break_down_chart'));
/*			 title:  $jq('#domain_break_down_chart').attr("data-title"),
backgroundColor:{
	stroke: '#000000',
    strokeWidth: 1, 
	
},
*/

		      var options = {
			chartArea:{
				left:20,
				top:20,
				width:"90%",
				height:"90%"
				},
		       	width:  $jq('#domain_break_down_chart').attr("data-width"),
				height: $jq('#domain_break_down_chart').attr("data-height"),
				pieSliceTextStyle: {color: '#FFFFFF'},
					colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
					is3D: true
		      };
		      domain_breakdown_chart.draw(domain_breakdown_chart_data, options);
			$jq("#domain_break_down_chart_loading").html( '<p class="alert">&nbsp;</p>' );
			google.visualization.events.addListener(domain_breakdown_chart, 'select', selectHandler);
			
		},
       });	
}
function selectHandler(event) {	
	var selection = domain_breakdown_chart.getSelection();
    var message = '';
     var item = selection[0];
     var str = domain_breakdown_chart_data.getFormattedValue(item.row, 0);
  // alert(str); 
  if(str != 'other') { 
	  $jq("#query").val($jq("#search_query").val("@" + str)); 
	  $jq("#page").val(1); 
	   search_list()
	}
}


// Membership >> List Activity
function sub_unsub_trend_chart() {
	$jq("#amount").on("change", function(event){ 
		draw_sub_unsub_trend_chart();		
    });

/* 
backgroundColor: { 
	stroke: '#000000',
	strokeWidth: 1,
},
*/

    var options = {
		width:  720, 
		height: 480, 
		chartArea:{
			left:60,
			top:20,
			width:"70%",
			height:"70%"
			},
		
		colors: ['blue', 'red', 'green', 'orange'], 
		title: "Subscription Trends",
		animation:{
			duration: 1000,
			easing: 'out',
		},
    };
    var data;
    var sub_unsub_trend_c = new google.visualization.AreaChart(document.getElementById('sub_unsub_trends'));

	function draw_sub_unsub_trend_chart() {
		$jq("#amount").prop('disabled', true);
		google.visualization.events.addListener(sub_unsub_trend_c, 'ready', function() {
			$jq("#amount").prop('disabled', false);	
		});

		$jq("#sub_unsub_trends_loading").html( '<p class="alert">Loading...</p>' );
		$jq.ajax({
			url: $jq("#s_program_url").val(),
			data: {
				f:    'sub_unsub_trends_json', 
				days: $jq("#amount option:selected").val()
			},
			dataType:"json",
			async: true,
			success: function( jsonData ) {
				data = new google.visualization.DataTable(jsonData);
				sub_unsub_trend_c.draw(data, options);
				$jq("#sub_unsub_trends_loading").html( '<p class="alert">&nbsp;</p>' );			
			},
		});
	}
	
	draw_sub_unsub_trend_chart();
  }



// Membership >> user@example.com
function mailing_list_history(){ 
	$jq("#mailing_list_history_loading").html( '<p class="alert">Loading...</p>' );
	var request = $jq.ajax({
		url: $jq("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f:       'mailing_list_history',
			email:   $jq("#email").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$jq("#mailing_list_history").hide()
		.html( content )
		.show( 'fade' );
		
		$jq("#mailing_list_history_loading").html( '<p class="alert">&nbsp;</p>' );
	});
}
function updateEmail(){ 
	var is_for_all_lists = 0; 
	if(
		$jq('#for_all_mailing_lists').val() == 1 && 
		$jq("#for_all_mailing_lists").prop("checked") == true
	) { 
		is_for_all_lists = 1;
	}
	$jq("#update_email_results_loading").html( '<p class="alert">Loading...</p>' );
	var request = $jq.ajax({
		url: $jq("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
				f: 'update_email_results',
				updated_email: $jq("#updated_email").val(),
				email:         $jq("#original_email").val(),
				for_all_lists: is_for_all_lists
		},
		dataType: "html"
	});
	request.done(function(content) {
		$jq("#update_email_results").html( content );
		$jq("#update_email_results_loading").html( '<p class="alert">&nbsp;</p>' );
		$jq("#update_email_results" ).show( 'blind' );
	});
}
function show_change_profile_password_form(){
	$jq("#change_profile_password_button" ).hide( 'blind' );
	$jq("#change_profile_password_form" ).show( 'blind' );
}

// Membership >> Invite 
function show_customize_invite_message(){ 
	$jq('#customize_invite_message_button').hide('blind');
	$jq('#customize_invite_message_form').show('blind');	
}

function test_sending_preferences() { 
	Modalbox.show(
		$jq("#s_program_url").val(), {
		title: 'Testing Sending Preferences...', 
		width: 640, height: 480,
		method: 'post', 
		params: {
			f:                         'sending_preferences_test',
			add_sendmail_f_flag:       $jq('#add_sendmail_f_flag').val(), 
			smtp_server:               $jq('#smtp_server').val(), 
			smtp_port:                 $jq('#smtp_port').val(),
			use_smtp_ssl:              $jq('#use_smtp_ssl').val(),			
			use_sasl_smtp_auth:        $jq('#use_sasl_smtp_auth').val(), 
			sasl_auth_mechanism:       $jq('#sasl_auth_mechanism').val(), 
			sasl_smtp_username:        $jq('#sasl_smtp_username').val(), 
			sasl_smtp_password:        $jq('#sasl_smtp_password').val(), 
			use_pop_before_smtp:       $jq('#use_pop_before_smtp').val(), 
			pop3_server:               $jq('#pop3_server').val(), 
			pop3_username:             $jq('#pop3_username').val(), 
			pop3_password:             $jq('#pop3_password').val(), 
			pop3_use_ssl:              $jq('#pop3_use_ssl').val(), 
			set_smtp_sender:           $jq('#set_smtp_sender').val(),
			process:                   $jq('#process').val(),
			sending_method:             $jq('input[name=sending_method]:checked').val()
			},		
		});	
}




function amazon_verify_email() { 
	$jq("#amazon_ses_verify_email_results").hide('fade');
	$jq("#amazon_ses_verify_email_loading").html( '<p class="alert">Loading...</p>' );
	var request = $jq.ajax({
	  url: $jq("#s_program_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
			f: 'amazon_ses_verify_email',
			amazon_ses_verify_email: $jq("#amazon_ses_verify_email").val()
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $jq("#amazon_ses_verify_email_results")
		.html( content )
		.show('fade');
	  $jq("#amazon_ses_verify_email_loading").html( '<p class="alert">&nbsp;</p>' );
	});
}


// Mail Sending >> Mass Mailing Preferences 
function previewBatchSendingSpeed(){ 	
	$jq("#previewBatchSendingSpeed_loading").hide()
	.html( '<p class="alert">Loading...</p>' )
	.show('fade');
	
	
	var enable_bulk_batching = 0; 
	if($jq('#enable_bulk_batching').prop('checked') == true){ 
		enable_bulk_batching = 1; 
	}
	var amazon_ses_auto_batch_settings = 0; 
	if($jq("#amazon_ses_get_stats").length) { 	
		if($jq('#amazon_ses_auto_batch_settings').prop('checked') == true){ 
			amazon_ses_auto_batch_settings = 1; 
		}
	}
	
	var request = $jq.ajax({
		url: $jq("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f:                              'previewBatchSendingSpeed', 
			enable_bulk_batching:           enable_bulk_batching,
			mass_send_amount:               $jq('#mass_send_amount').val(), 
			bulk_sleep_amount:              $jq('#bulk_sleep_amount').val(),
			amazon_ses_auto_batch_settings: amazon_ses_auto_batch_settings
		},
		dataType: "html"
	});
	request.done(function(content) {
		$jq("#previewBatchSendingSpeed").hide("fade", function(){ 
			$jq("#previewBatchSendingSpeed").html( content );
			$jq("#previewBatchSendingSpeed_loading").html( '' );
			$jq("#previewBatchSendingSpeed" ).show( 'fade' );
		}); 
	});
	

}

function amazon_ses_get_stats(){ 
	$jq("#amazon_ses_get_stats_loading").hide()
	.html( '<p class="alert">Loading...</p>' )
	.show('fade'); 
	var request = $jq.ajax({
		url: $jq("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f:                    'amazon_ses_get_stats', 
		},
		dataType: "html"
	});
	request.done(function(content) {
		$jq("#amazon_ses_get_stats").hide("fade", function(){ 
			$jq("#amazon_ses_get_stats").html( content );
			$jq("#amazon_ses_get_stats_loading").html( '' );
			$jq("#amazon_ses_get_stats" ).show( 'fade' );
		}); 
	});
}
function toggleManualBatchSettings() { 
	if($jq("#amazon_ses_auto_batch_settings").prop("checked") == true){ 
		$jq("#manual_batch_settings" ).hide( 'fade' );
	}
	else { 
		if( $jq('#manual_batch_settings').is(":hidden") ) {
			$jq("#manual_batch_settings" ).show( 'fade' );
		}
	}
	previewBatchSendingSpeed(); 
}

// Installer 


	function installer_toggleSQL_options() { 
		
		//var sql_picker = document.getElementById('backend');
		//var selected  = sql_picker.options[sql_picker.selectedIndex].value;
		var selected = $jq("#backend option:selected").val();
		if(selected == 'mysql' || selected == 'Pg'){ 
		
			if($jq('#sql_info').is(':hidden')){ 
				$jq('#sql_info').show('blind');
			}
		}
		else { 
			if($jq('#sql_info').is(':visible')){ 
				$jq('#sql_info').hide('blind');
			}
		}
	}	
	
	function installer_move_installer_dir(){ 

		 $jq("#move_results").hide();
		var request = $jq.ajax({
		  url: $jq("#self_url").val(),
		  type: "POST",
		  cache: false,
		  data: {
				f:       'move_installer_dir_ajax',
		  },
		  dataType: "html"
		});
		request.done(function(content) {
		  $jq("#move_results").html( content );
		  $jq("#move_results").show( 'blind' );
		});
	}
	
	
	






// Plugins >> Bounce Bounce Handler

function bounce_handler_show_scorecard() { 
	$jq("#bounce_scorecard_loading").html( '<p class="alert">Loading...</p>' );	
	var request = $jq.ajax({
	  url: $jq("#plugin_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
			flavor:       'cgi_scorecard',
			page:     	  $jq('#bounce_handler_page').val(),
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $jq("#bounce_scorecard").html( content );
	  $jq("#bounce_scorecard_loading").html( '<p class="alert">&nbsp;</p>' );
	});
}
function bounce_handler_turn_page(page_to_turn_to) {
	$jq("#bounce_handler_page").val(page_to_turn_to); 
	bounce_handler_show_scorecard();
}
function bounce_handler_parse_bounces() { 
	$jq("#parse_bounce_results_loading").html( '<p class="alert">Loading</p>' );
	$jq("#parse_bounces_button").val( 'Parsing...' );	
	var request = $jq.ajax({
	  url: $jq("#plugin_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
			flavor:       'ajax_parse_bounces_results',
			parse_amount: $jq('#parse_amount').val(),
			bounce_test:  $jq('#bounce_test').val()
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $jq("#parse_bounce_results").html( content );
	  $jq("#parse_bounces_button").val( 'Parse Bounces' );	
	  $jq("#parse_bounce_results_loading").html( '<p class="alert">&nbsp;</p>' );
	
	});
}

// Plugins >> Dada Bridge 

function plugins_bridge_test_pop3() { 
	Modalbox.show(
		$jq("#plugin_url").val(), {
		title: 'Test Results...', 
		width: 640, height: 480,
		method: 'post', 
		params: {
			flavor: 'cgi_test_pop3_ajax',
		},
	});
}
function plugins_bridge_manually_check_messages() { 
	Modalbox.show(
		$jq("#plugin_url").val(), {
		title: 'Test Results...', 
		width: 640, height: 480,
		method: 'post', 
		params: {
			flavor: 'admin_cgi_manual_start_ajax',
		},
	});	
}

// Plugins >> Mailing Monitor 
function plugins_mailing_monitor(){ 
	$jq("#mailing_monitor_results_loading").html( '<p class="alert">Loading...</p>' );	
	var request = $jq.ajax({
	  url: $jq("#plugin_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
			flavor:       'mailing_monitor_results',
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $jq("#mailing_monitor_results").html( content );
	  $jq("#mailing_monitor_results_loading").html( '<p class="alert">&nbsp;</p>' );
	});
	
}
// Plugins >> Tracker
	function update_plugins_tracker_message_report(){ 
		
		$jq( "#tabs" ).tabs();
		
		if($jq("#can_use_country_geoip_data").val() == 1){ 
			
			country_geoip_table('clickthroughs',       'Clickthroughs', 'country_geoip_clickthroughs_table');	
			country_geoip_table('opens',               'Opens',         'country_geoip_opens_table');	
			country_geoip_table('view_archive',        'Archive Views', 'country_geoip_view_archive_table');
			country_geoip_table('forward_to_a_friend', 'Forwards',      'country_geoip_forwards_table');	
				
			
			google.setOnLoadCallback(country_geoip_map('clickthroughs',       'Clickthroughs', 'country_geoip_clickthroughs_map'));	
			google.setOnLoadCallback(country_geoip_map('opens',               'Opens',         'country_geoip_opens_map'));	
			google.setOnLoadCallback(country_geoip_map('view_archive',        'Archive Views', 'country_geoip_view_archive_map'));	
			google.setOnLoadCallback(country_geoip_map('forward_to_a_friend', 'Forwards',      'country_geoip_forwards_map'));	
			
		}
		
		google.setOnLoadCallback(data_over_time_graph('clickthroughs',       'Clickthroughs', 'over_time_clickthroughs_graph'));
		google.setOnLoadCallback(data_over_time_graph('opens',               'Opens',         'over_time_opens_graph'));
		google.setOnLoadCallback(data_over_time_graph('view_archive',        'Archive Views', 'over_time_view_archive_graph'));
		google.setOnLoadCallback(data_over_time_graph('forward_to_a_friend', 'Forwards',      'over_time_forwards_graph'));

		google.setOnLoadCallback(bounce_breakdown_chart('soft', 'Soft Bounces', 'soft_bounce_graph'));
		google.setOnLoadCallback(bounce_breakdown_chart('hard', 'Hard Bounces', 'hard_bounce_graph'));
		
	}
			
	function country_geoip_table(type, label, target_div){ 
		
		$jq("#" + target_div + "_loading").html( '<p class="alert">Loading...</p>' );
		var request = $jq.ajax({
		  url: $jq("#plugin_url").val(),
		  type: "POST",
		  cache: false,
		  data: {
			f:       'country_geoip_table',
			mid:     $jq('#tracker_message_id').val(),
			type:    type,
			label:   label, 
		  },
		  dataType: "html"
		});
		request.done(function(content) {

			$jq("#" + target_div).hide();
			$jq("#" + target_div).html( content );
			$jq("#" + target_div).show('fade');
						
		  $jq("#" + target_div + "_loading").html( '<p class="alert">&nbsp;</p>' );
		  $jq("#sortable_table_" + type).tablesorter(); 
		});
	}
	function country_geoip_map(type, label, target_div){ 
		$jq("#" + target_div + "_loading").html( '<p class="alert">Loading...</p>' );
		$jq.ajax({
			url: $jq("#plugin_url").val(),
			type: "POST",
			data: {
				f:       'country_geoip_json',
				mid:     $jq('#tracker_message_id').val(),
				type:    type, 
				label:   label
			},
			dataType:"json",
			cache: false,
			async: true,
			success: function( jsonData ) {
				// Create our data table out of JSON data loaded from server.
				var data = new google.visualization.DataTable(jsonData);
				var options = {
					region: 'world', 
					width:  $jq('#' + target_div).attr("data-width"),
					height: $jq('#' + target_div).attr("data-height"),
					keepAspectRatio: true, 
					backgroundColor: "#FFFFFF"
				};
				var chart = new google.visualization.GeoChart(document.getElementById(target_div));
				chart.draw(data, options);
				$jq("#" + target_div + "_loading").html( '<p class="alert">&nbsp;</p>' );
			}				
		});


    
	}
	
	function data_over_time_graph(type, label, target_div){ 
	  	$jq("#" + target_div + "_loading").html( '<p class="alert">Loading...</p>' );
		 var request = $jq.ajax({
	          url: $jq("#plugin_url").val(),
			  data: {
				f:       'data_over_time_json',
				mid:     $jq("#tracker_message_id").val(),
				type: 	 type, 
				label:   label, 
			  },
			  cache: false, 
	          dataType:"json",
	          async: true,
			success: function(jsonData) {
				var data = new google.visualization.DataTable(jsonData);
			    var options = {
					chartArea:{
						left:60,
						top:20,
						width:"70%",
						height:"70%"
						},
						width:  $jq('#' + target_div).attr("data-width"),
						height: $jq('#' + target_div).attr("data-height"),
					backgroundColor:{
						stroke: '#FFFFFF',
				        strokeWidth: 0
					}, 
					hAxis: { 
						slantedText: true
					}
				};
			    var chart = new google.visualization.AreaChart(document.getElementById(target_div));
			    chart.draw(data, options);
				$jq("#" + target_div + "_loading").html( '<p class="alert">&nbsp;</p>' );
			},
			});	
	}
	function bounce_breakdown_chart(type, label, target_div) { 
		$jq("#" + target_div + "_loading").html( '<p class="alert">Loading...</p>' );
	    $jq.ajax({
			  url: $jq("#plugin_url").val(),
	          dataType:"json",
				data: {
					f:          'bounce_stats_json',
					mid:         $jq('#tracker_message_id').val(),
					bounce_type: type, 
					label:       label
				},
	          async: true,
			success: function( jsonData ) {
			      var data = new google.visualization.DataTable(jsonData);
			      var chart = new google.visualization.PieChart(document.getElementById(target_div));
			      var options = {
					chartArea:{
						left:20,
						top:20,
						width:"90%",
						height:"90%"
						},
						title:  $jq('#' + target_div).attr("data-title"),
						width:  $jq('#' + target_div).attr("data-width"),
						height: $jq('#' + target_div).attr("data-height"),
				
					pieSliceTextStyle: {color: '#FFFFFF'},
						colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
						is3D: true
			      };
			      chart.draw(data, options);
				  $jq("#" + target_div + "_loading").html( '<p class="alert">&nbsp;</p>' );
			},
	       });
	}	


// Plugins >> Tracker
function tracker_turn_page(page_to_turn_to) { 
	$jq("#tracker_page").val(page_to_turn_to); 
	tracker_show_table();
	google.setOnLoadCallback(drawSubscriberHistoryChart());
	
}

// Plugins >> Log Viewer
function view_logs_results() { 
	$jq("#refresh_button").val( 'Loading....' );
	var request = $jq.ajax({
	  url: $jq("#plugin_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
			flavor:       'ajax_view_logs_results',
			log_name:     $jq('#log_name').val(),
			lines:        $jq('#lines').val()
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $jq("#view_logs_results").html( content );
	  $jq("#refresh_button").val( 'Refresh' );
	});
}
function delete_log() { 
	var confirm_msg =  "Are you sure you want to delete this log? ";
	    confirm_msg += "There is no way to undo this deletion.";
	if(confirm(confirm_msg)){
		var request = $jq.ajax({
		  url: $jq("#plugin_url").val(),
		  type: "POST",
		  cache: false,
		  data: {
				flavor:       'ajax_delete_log',
				log_name:     $jq('#log_name').val(),
		  },
		  dataType: "html"
		});
		request.done(function(content) {
			view_logs_results();
		});	
	}
	else { 
		alert('Log deletion canceled.'); 
	}
}





function tracker_show_table(){ 
		
	$jq("#show_table_results_loading").html( '<p class="alert">Loading...</p>' );
	var request = $jq.ajax({
	  url: $jq("#plugin_url").val(),
	  type: "POST",
	  cache: false,
	  data: {
		f:       'clickthrough_table',
		page:   $jq("#tracker_page").val(),
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $jq("#show_table_results")
		.hide('fade', function(){ 
			$jq("#show_table_results").html( content );
			$jq("#show_table_results").show('fade'); 
		    $jq("#show_table_results_loading").html( '<p class="alert">&nbsp;</p>' );
		}
	  ); 

	});
}

var SubscriberHistoryChart; 
 function drawSubscriberHistoryChart() {
  	$jq("#subscriber_history_chart_loading").html( '<p class="alert">Loading...</p>' );
	 var request = $jq.ajax({
          url: $jq("#plugin_url").val(),
		  data: {
			f:       'subscriber_history_json',
			page:   $jq("#tracker_page").val(),
			
		  },
		  cache: false, 
          dataType:"json",
          async: true,
		success: function(jsonData) {
			var data = new google.visualization.DataTable(jsonData);
		    var options = {
				chartArea:{
					left:60,
					top:20,
					width:"70%",
					height:"70%"
					},
				width:  720, 
				height: 400,
				backgroundColor:{
					stroke: '#000000',
			        strokeWidth: 1
				}		
			};
		    var SubscriberHistoryChart = new google.visualization.LineChart(document.getElementById('subscriber_history_chart'));
			$jq("#subscriber_history_chart").hide('fade'); 
			   SubscriberHistoryChart.draw(data, options);
			$jq("#subscriber_history_chart").show('fade'); 
			$jq("#subscriber_history_chart_loading").html( '<p class="alert">&nbsp;</p>' );

		},
		}
		);
  }


function tracker_purge_log(){ 	
	var confirm_msg =  "Are you sure you want to delete this log? ";
	    confirm_msg += "There is no way to undo this deletion.";
	if(confirm(confirm_msg)){
		var request = $jq.ajax({
		  url: $jq("#plugin_url").val(),
		  type: "POST",
		  cache: false,
		  data: {
			f:       'ajax_delete_log',
		  },
		  dataType: "html"
		});
		request.done(function(content) {
		 	tracker_show_table();
		    google.setOnLoadCallback(drawSubscriberHistoryChart());
		});		
		// something like request.error(function () { ... });
		//onFailure: function() { 
		//	alert('Warning! Something went wrong when attempting to remove the log file.'); 
		//	}
	}
	else { 
		alert('Log deletion canceled.'); 
		return false; 
	}
}

// Plugins >> Password Protect Directories
function password_protect_directories_show_change_password_form(){
	$jq("#change_default_password_button" ).hide( 'blind' );
	$jq("#change_default_password_form" ).show( 'blind' );
}










/* Global */
function toggleCheckboxes(status, target_class) {
	$jq('.' + target_class).each( function() {
		$jq(this).prop("checked",status);
	});
}

function toggleDisplay(target) {
	$jq('#' + target).toggle('blind');
}
function changeDisplayState(target, state) {
	if(state == 'show'){ 
		if($jq('#' + target).is(':hidden')){ 
			$jq('#' + target).show('blind');
		}
	}
	else { 
		if($jq('#' + target).is(':visible')){ 
			$jq('#' + target).hide('blind');
		}
	}
}



var refreshLocation = ''; 
function preview() {
	var new_window = window.open("", "preview", "top=100,left=100,resizable,scrollbars,width=400,height=200");
}

function SetChecked(val) {

	dml=document.email_form;
	len = dml.elements.length;
	var i = 0;
	for( i = 0; i < len; i++) {
		if (dml.elements[i].name=='address') {
			dml.elements[i].checked=val;
		}
	}
}

function SetListChecked(val) {

	dml=document.send_email;
	len = dml.elements.length;
	var i=0;
	for( i=0 ; i < len ; i++) {
		if (dml.elements[i].name=='alternative_list') {
			dml.elements[i].checked=val;
		}
	}
}

function set_to_default() {
	
	document.the_form.target="_self"; 
	default_template = document.the_form.default_template.value;
	document.the_form.template_info.value = default_template;
}


function list_message_status(thing) {
	document.the_form.process.value = thing;
}


function preview_template() {

	document.the_form.target="_blank";
	document.the_form.process.value="preview template";

}

function change_template() {

	document.the_form.target="_self";
	document.the_form.process.value="true";
}

function check_newest_version(ver) {

	var check = "http://dadamailproject.com/cgi-bin/support/version.cgi?version=" + ver;
	window.open(check, 'version', 'width=325,height=300,top=20,left=20');
}
function just_test_message() {

	document.the_form.process.value="just_test_message";

}


function real_message() {

	document.the_form.process.value="true";

}






function toggleTwo(targetOpen, targetClose) { 
	Effect.BlindUp($jq(targetClose));
	Effect.BlindDown($jq(targetOpen));	
}



function ChangeMassMailingButtonLabel() { 
	if($jq("#archive_message").prop("checked") == true && $jq("#archive_no_send").prop("checked") == true) { 
		$jq("#submit_mass_mailing").prop('value', 'Archive Message');
		$jq('#submit_test_mailing').hide('fade');	
		$jq('#send_test_messages_to').hide('fade');
	}
	else { 
		$jq("#submit_mass_mailing").prop('value', $jq("#default_mass_mailing_button_label").val());
		$jq('#submit_test_mailing').show();
		$jq('#send_test_messages_to').show();
	}	
}

    
function sendMailingListMessage(fid, itsatest) {
	/* This is for the Send a Webpage - did they fill in a URL? */
	if($jq("#f").val() == 'send_url_email'){ 
		if($jq('input[name=sending_method]:checked').val() == 'url'){ 
			if(
				$jq("#url").val() == 'http://' 
			||  $jq("#url").val().length <= 0
			){ 
				alert('You have not filled in a URL! Mass Mailing Stopped.'); 
				return false;
			}
		}
	}
	
	var itsatest_label = '';
	if(itsatest == true){ 
		itsatest_label = "*test*"
	}
	
	var confirm_msg =  "Are you sure you want this ";
	    confirm_msg +=  itsatest_label;
	    confirm_msg += " mailing to be sent?";
	    confirm_msg += " Mailing list sending cannot be easily stopped.";
	
	if($jq("#Subject").val().length <= 0){ 
	    var no_subject_msg = "The Subject: header of this message has been left blank. Send anyways?"; 
	    if(!confirm(no_subject_msg)){
			alert('Mass Mailing canceled.');
			return false;
		}
	}
	if($jq("#im_sure").prop("checked") == false){
		if(!confirm(confirm_msg)){
			alert('Mass Mailing canceled.');
			return false;
		}
	}
	if($jq("#new_win").prop("checked") == true){ 
		$jq("#" + fid).attr("target", "_blank");
	}
	else { 
		$jq("#" + fid).attr("target", "_self");
	}
	return true; 
}

function warnAboutMassSubscription() { 
	
	var confirm_msg =  "Are you sure you want to subscribe the selected email address(es) to your list? ";
    confirm_msg += "\n\n";

    confirm_msg += "Subscription of unconfirmed email address(es) should always be avoided. ";
    confirm_msg += "\n\n";

    confirm_msg += " If wanting to add unconfirmed email address(es), use the \"Send Invitation... >>\"";	
    confirm_msg += " option to allow the subscriber to confirm their own subscription.";	
	
	if(!confirm(confirm_msg)){
		alert('Mass Subscription Stopped.');
		return false;
	}
	else { 
	}	return true; 
}


function unsubscribeAllSubscribers(form_name, type) { 
    
	var confirm_msg = '';
	if(type == 'Subscribers'){ 
		confirm_msg = "Are you sure you want to unsubscribe all Subscribers? ";	
	}
	else { 
		confirm_msg = "Are you sure you want to remove all " + type + "?";			
	}
	
	if(!confirm(confirm_msg)){
		if(type == 'Subscribers'){ 	
			alert("Subscribers not unsubscribed.");        	
        }
		else { 
			alert("'" + type + "' not removed.");
        	
		}
		return false;
    }
	else { 
		return true; 
	}
    
}

function removeAllArchives(form_name) { 
    
    var confirm_msg =  "Are you sure you want to purge all your mailing list archives?";	
    if(!confirm(confirm_msg)){
        alert("Archives not purged.");
        return false;
    }
	else { 
		return true; 
	}
    
}

function revertEditType(form_name) { 
    
    var confirm_msg =  "Are you sure you want to revert to the default for ALL email messages?";	
    if(!confirm(confirm_msg)){
        alert("Messages not reverted to default.");
        return false;
    }
	else { 
		return true; 
	}
    
}






function killMonitoredSending() { 
	
    var confirm_msg =  "Are you sure you want to STOP this Mass Mailing?";
	    confirm_msg += " Once this mailing has been stopped, it cannot be restarted.";
    if(!confirm(confirm_msg)){
        alert('Continuing...');
        return false;
    }
	else { 
		return true; 
	}
    
}

function pauseMonitoredSending() { 
    
    var confirm_msg =  "Are you sure you want to PAUSE this mailing? ";
	    confirm_msg += " Email sending will be stopped immediately after this current batch has completed. Email sending may be resumed at any time.";
    if(!confirm(confirm_msg)){
        alert('Continuing...');
        return false;
    }
	else { 
		return true; 
	}
    
}

var refreshTimerId = 0;
var refreshLoc     = ''; 
var refreshTime    = ''; 
function refreshpage(sec, url){ 
    var refreshAfter = sec/1 * 1000; 
		refreshTime = refreshAfter/1000; 
   if(url){ 
    	refreshLocation = url; 
		refreshLoc      = refreshLocation;  
    	refreshTimerId = setInterval("doRefresh(refreshLocation);",refreshAfter);
    }

}
function doRefresh(loc) { 
	window.location.replace(loc); 
}
function removeSubscriberField(form_name) {
		
	var confirm_msg =  "Are you sure you want to ";
	    confirm_msg += " permanently remove this field?";
	    confirm_msg += " All saved informaton in the field for all subscribers will be lost.";

    if(!confirm(confirm_msg)){
        alert('Subscriber field removal has been canceled.');
        return false;
    }

    form_name.target = "_self";
    
}
