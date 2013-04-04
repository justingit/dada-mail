$(document).ready(function() {

	$("a.modalbox").live("click", function(event) {
		event.preventDefault();
		$.colorbox({
			top: 0,
			fixed: true,
			initialHeight: 50,
			maxHeight: 480,
			maxWidth: 649,
			opacity: .50,
			href: $(this).attr("href")
		});
	});

	// Admin Menu 
	if ($("#navcontainer").length) {
		admin_menu_sending_monitor_notification();
		admin_menu_subscriber_count_notification();
		admin_menu_archive_count_notification();
	}

	//Mail Sending >> Send a Message 
	if ($("#send_email_screen").length || $("#send_url_email").length || $("#list_invite").length) {
		$("body").on("submit", "#mass_mailing", function(event) {
			event.preventDefault();
		});
		$("body").on("click", ".sendmassmailing", function(event) {
			//var fid = $(event.target).closest('form').attr('id'); 
			var fid = 'mass_mailing';

			if ($("#using_ckeditor").length) {
				// Strange you have to do this, but, you do: 
				CKEDITOR.instances['html_message_body'].updateElement();
			}
			var itsatest = $(this).hasClass("justatest");
			if (sendMailingListMessage(fid, itsatest) == true) {
				$("body").off('submit', '#' + fid);
				// $('#' + fid).submit();
				return true;
			} else {
				//alert("It stays off!"); 
			}
		});
		$("body").on("click", ".ChangeMassMailingButtonLabel", function(event) {
			ChangeMassMailingButtonLabel();
		});

		ChangeMassMailingButtonLabel();
		$("#tabs").tabs();
		$("#tabs_mass_mailing_options").tabs();

		$("body").on("click", ".preview_message_receivers", function(event) {
			event.preventDefault();
			preview_message_receivers();
		});

		if ($("#using_ckeditor").length) {
			$("#html_message_body").ckeditor(

			function() {}, {
				customConfig: $("#support_files_url").val() + '/ckeditor/dada_mail_config.js',
				toolbar: 'DadaMail_Admin'
			});
		}





	}


	// Mail Sending >> Mailing Monitor Index
	if ($("#sending_monitor_index").length) {
		refreshpage(60, $("#s_program_url").val() + "?f=sending_monitor");
	}

	if ($("#sending_monitor_container").length || $("#sending_monitor_index").length) {
		$('body').on('submit', '.stop_mass_mailing', function(event) {
			event.preventDefault();
		});
		$('body').on('click', '.killMonitoredSending', function(event) {
			//var fid = 'stop_mass_mailing';
			if (killMonitoredSending() == true) {
				$('body').off('submit', '.stop_mass_mailing');
				// $(event.target).closest('form').submit();
				return true;
			} else {
				// alert("It stays off!"); 
			}
		});
	}


	if ($("#sending_monitor_container").length) {

		update_sending_monitor_interface(
		$("#message_id").val(), $("#message_type").val(), $("#target_id").val(), $("#refresh_after").val());

		$('body').on('submit', '#pause_mass_mailing', function(event) {
			event.preventDefault();
		});
		$('body').on('click', '.pauseMonitoredSending', function(event) {
			//var fid = $(event.target).closest('form').attr('id'); 
			var fid = 'pause_mass_mailing';
			if (pauseMonitoredSending() == true) {
				$('body').off('submit', '#' + fid);
				//$('#' + fid).submit();
				return true;
			} else {
				// alert("It stays off!"); 
			}
		});

		if ($("#tracker_reports").length) {
			refresh_tracker_plugin(
			$("#tracker_url").val(), $("#message_id").val(), 'tracker_reports_container');
		}


	}


	// Membership >> View List	
	if ($("#view_list_viewport").length) {
		view_list_viewport(1);
	}

	// Membership >> List Activity
	if ($("#list_activity").length) {
		google.setOnLoadCallback(sub_unsub_trend_chart());
	}
	// Membership >> user@example.com
	if ($("#mailing_list_history").length) {
		mailing_list_history();
	}

	// Membership >> Invite/Add
	if ($("#add").length) {
		$("#add_one").hide();
		$("#show_progress").hide();
		$("#fileupload").live("submit", function(event) {
			check_status();
		});
	}


	// Membership >> Add (step 2) 
	if ($("#add_email").length) {
		$("body").on("submit", "#confirm_add", function(event) {
			event.preventDefault();
		});
		$("body").on("click", ".addingemail", function(event) {
			if ($(this).hasClass("warnAboutMassSubscription")) {
				if (warnAboutMassSubscription() == true) {
					$("body").off('submit', "#confirm_add");
					//$('#confirm_add').submit();
					return true;
				}
			} else {
				// Invitations.
				$("body").off('submit', "#confirm_add");
				return true;
			}
		});
	}


	// Membership >> Invite
	if ($("#list_invite").length) {
		$("#customize_invite_message_form").hide();
		$('.show_customize_invite_message').live("click", function(event) {
			event.preventDefault();
			show_customize_invite_message();
		});
	}
	// Mail Sending >> Sending Options 
	if ($("#sending_preferences").length) {

		if ($("#has_needed_cpan_modules").length) {
			amazon_ses_get_stats();
		}

		sending_prefs_setup();
		toggle_SASL_options();
		toggle_pop_before_SMTP_options();



		$("body").on("click", '#use_sasl_smtp_auth', function(event) {
			toggle_SASL_options();
		});

		$("body").on("click", '#use_pop_before_smtp', function(event) {
			toggle_pop_before_SMTP_options();
		});




		$("body").on("click", '.sending_prefs_radio', function(event) {
			sending_prefs_setup();
		});



		$("body").on("click", ".test_sending_preferences", function(event) {
			event.preventDefault();
			test_sending_preferences();
		});

		$("body").on("click", ".amazon_verify_email", function(event) {
			event.preventDefault();
			amazon_verify_email();
		});




	}

	// Mail Sending >> Advanced Options
	if ($("#adv_sending_preferences").length) {
		$("#misc_options").hide();
	}
	// Mail Sending >> Mass Mailing Options 
	if ($("#mass_mailing_preferences").length) {
		if ($("#amazon_ses_get_stats").length) {
			amazon_ses_get_stats();
		} else {
			// amazon_ses_get_stats does a previewBatchSendingSpeed(), 
			// so no need to do it, twice. 
			previewBatchSendingSpeed();
		}
		toggleManualBatchSettings();
	}


	// Membership >> View List
	$(".change_type").live("click", function(event) {
		change_type($(this).attr("data-type"));
		event.preventDefault();
	});
	$(".turn_page").live("click", function(event) {
		turn_page($(this).attr("data-page"));
		event.preventDefault();
	});
	$(".change_order").live("click", function(event) {
		change_order($(this).attr("data-by"), $(this).attr("data-dir"));
		event.preventDefault();
	});
	$(".search_list").live("click", function(event) {
		search_list();
		event.preventDefault();
	});
	$("#search_form").live("submit", function(event) {
		search_list();
		event.preventDefault();
	});
	$(".clear_search").live("click", function(event) {
		clear_search();
		event.preventDefault();
	});
	$('#search_query').live('keydown', function() {
		$("#search_query").autocomplete({
			source: function(request, response) {
				$.ajax({
					url: $("#s_program_url").val(),
					type: "POST",
					dataType: "json",
					data: {
						f: 'search_list_auto_complete',
						length: 10,
						type: $("#type").val(),
						query: request.term
					},
					success: function(data) {
						response($.map(data, function(item) {
							return {
								value: item.email,
							}
						}));
					},
					error: function() {
						console.log('something is wrong with, "search_list_auto_complete"');
					},
				});
			},
			minLength: 3,
			open: function() {
				$(this).removeClass("ui-corner-all").addClass("ui-corner-top");
			},
			close: function() {
				$(this).removeClass("ui-corner-top").addClass("ui-corner-all");
			}
		});
	});

	// Membership >> user@example.com
	$(".change_profile_password").live("click", function(event) {
		show_change_profile_password_form();
		event.preventDefault();
	});

	// Mail Sending >> Mass Mailing Options 
	$(".previewBatchSendingSpeed").live("change", function(event) {
		previewBatchSendingSpeed();
	});

	$("#amazon_ses_auto_batch_settings").live("click", function(event) {
		toggleManualBatchSettings();
	});


	// Version Check 
	$('#check_version').live('click', function(event) {
		event.preventDefault();
		check_newest_version($('#check_version').attr("data-ver"));
	});

	// Installer 
	if ($("#install_or_upgrade").length) {
		$("body").on("click", '.installer_changeDisplayStateDivs', function(event) {
			changeDisplayState($(this).attr("data-target"), $(this).attr("data-state"));
		});
	}
	if ($("#installer_configure_dada_mail").length) {
		$("body").on("change", "#backend", function(event) {
			installer_toggleSQL_options();
		});
		$("body").on("click", '.radiochangeDisplayState', function(event) {
			changeDisplayState($(this).attr("data-target"), $(this).attr("data-state"));
		});

		$("body").on("click", '.test_sql_connection', function(event) {
			installer_test_sql_connection();
		});
		$("body").on("click", '.test_bounce_handler_pop3_connection', function(event) {
			installer_test_pop3_connection();
		});
		$("body").on("click", '.test_amazon_ses_configuration', function(event) {
			test_amazon_ses_configuration();
		});
		


		$("body").on('keyup', "#dada_root_pass_again", function(event) {

			if ($("#dada_root_pass_again").val() != $("#dada_root_pass").val() && $("#dada_root_pass_again").val().length) {
				$(".dada_pass_no_match").html('<span class="error">Passwords do not match!</span>');
			} else {
				$(".dada_pass_no_match").html('');

			}
		});

		$("body").on('click', "#install_wysiwyg_editors", function(event) {
			installer_toggle_wysiwyg_editors_options()
		});
		installer_dada_root_pass_options();
		installer_toggleSQL_options();
		installer_toggle_dada_files_dirOptions();
		installer_togger_bounce_handler_config();
		installer_toggle_wysiwyg_editors_options();
		
		$("body").on('click', "#configure_amazon_ses", function(event) {
			installer_toggle_configure_amazon_ses_options();
		});
		
		

		$("#dada_files_help").hide();
		$("#program_url_help").hide();
		$("#root_pass_help").hide();
		$("#support_files_help").hide();
		$("#backend_help").hide();
		$("#plugins_extensions_help").hide();
		$("#bounce_handler_configuration_help").hide();
		$("#wysiwyg_editor_help").hide();
		$("#test_sql_connection_results").hide();
		$("#test_bounce_handler_pop3_connection_results").hide();
		$("#test_amazon_ses_configuration_results").hide();


	}
	if ($("#installer_install_dada_mail").length) {
		$("body").on("click", '#move_installer_dir', function(event) {
			event.preventDefault();
			installer_move_installer_dir();
		});
	}

	// Plugins >> Bounce Handler 
	if ($("#plugins_bounce_handler_default").length) {
		bounce_handler_show_scorecard();
		$("body").on("click", '.bounce_handler_turn_page', function(event) {
			bounce_handler_turn_page($(this).attr("data-page"));
			event.preventDefault();
		});

		$("body").on("submit", "#parse_bounces_form", function(event) {
			event.preventDefault();
		});
		$("body").on("click", "#parse_bounces_button", function(event) {
			ajax_parse_bounces_results();
		});
	}
	if ($("#plugins_bounce_handler_parse_bounce").length) {
		bounce_handler_parse_bounces();
		$("#parse_bounces_button").on("click", function(event) {
			bounce_handler_parse_bounces();
		});
	}
	if ($("#manually_enter_bounces").length) {
		$("#manually_enter_bounces_button").on("click", function(event) {
			bounce_handler_manually_enter_bounces();
		});
	}

	// Plugins >> Bridge
	if ($("#plugins_bridge_default").length) {

		$("body").on("click", ".plugins_bridge_test_pop3", function(event) {
			event.preventDefault();
			plugins_bridge_test_pop3();
		});

		$("body").on("click", '.plugins_bridge_manually_check_messages', function(event) {
			event.preventDefault();
			plugins_bridge_manually_check_messages();
		});

		$("body").on("click", '.list_email_setup', function(event) {
			bridge_setup_list_email_type_params();
		});



		bridge_setup_list_email_type_params();

	}

	// Plugins >> Change List Shortname
	if ($("#plugins_change_list_shortname").length) {
		$("body").on("submit", "#change_name_form", function(event) {
			event.preventDefault();
		});

		$("body").on("click", "#verify_button", function(event) {
			$.colorbox({
				top: 0,
				fixed: true,
				initialHeight: 50,
				maxHeight: 480,
				maxWidth: 649,
				opacity: .50,
				href: $("#plugin_url").val(),
				data: {
					flavor: $('#flavor').val(),
					new_name: $('#new_name').val()
				}
			});
		});
	}

	// Plugins >> Mailing Monitor
	if ($("#plugins_mailing_monitor_default").length) {

		plugins_mailing_monitor();
		$("#mailing_monitor_button").live("click", function(event) {
			event.preventDefault();
			plugins_mailing_monitor();
		});

	}



	// Plugins >> Beatitude
	if ($("#plugins_beatitude_schedule_form").length) {
		$("body").on("click", ".preview_message_receivers", function(event) {
			event.preventDefault();
			preview_message_receivers();
		});
	}


	// Plugins >> Tracker
	if ($("#plugins_tracker_message_report").length) {
		update_plugins_tracker_message_report();
	}

	if ($("#plugins_tracker_default").length) {
		tracker_parse_links_setup();
		message_history_html();
		google.setOnLoadCallback(drawSubscriberHistoryChart());

		$("body").on("change", '#tracker_record_view_count', function(event) {
			tracker_change_record_view();
		});

		$("body").on("click", '.tracker_turn_page', function(event) {
			tracker_turn_page($(this).attr("data-page"));
			event.preventDefault();
		});
		$("body").on("click", '.tracker_purge_log', function(event) {
			tracker_purge_log();
			event.preventDefault();
		});

		$("body").on("click", '.tracker_parse_links_setup', function(event) {
			tracker_parse_links_setup();
		});



	}
	// Plugins >> Password Protect Directories
	if ($("#plugins_password_protect_directories_default").length) {
		$("#change_password_button").live("click", function(event) {
			password_protect_directories_show_change_password_form();
		});
	}

	// Plugins >> Log Viewer
	if ($("#plugin_log_viewer_default").length) {
		view_logs_results();

		$("#log_name").on("change", function(event) {
			view_logs_results();
		});
		$("#lines").on("change", function(event) {
			view_logs_results();
		});
		$("#refresh_button").on("click", function(event) {
			view_logs_results();
		});
		$("#delete_log").on("click", function(event) {
			delete_log();
		});
	}



	/* Global */
	$(".previous").live("click", function(event) {
		event.preventDefault();
		history.back();
	});

	$(".fade_me").live("click", function(event) {
		$('#alertbox').effect('fade');
		event.preventDefault();
	});

	$('.toggleCheckboxes').live("click", function(event) {
		toggleCheckboxes(
		$(this).prop("checked"), $(this).attr("data-target_class"));
	});
	$('.linkToggleCheckboxes').live("click", function(event) {
		event.preventDefault();
		var state = true;
		if ($(this).attr("data-state") == "false") {
			state = false;
		}
		toggleCheckboxes(
		state, $(this).attr("data-target_class"));
	});

	$('.toggleDivs').live("click", function(event) {
		event.preventDefault();
		toggleDisplay($(this).attr("data-target"));
	});
	$('.radio_toggleDivs').live("click", function(event) {
		toggleDisplay($(this).attr("data-target"));
	});

});


// Admin Menu 


function admin_menu_sending_monitor_notification() {
	admin_menu_notification('admin_menu_mailing_monitor_notification', 'admin_menu_sending_monitor');
}

function admin_menu_subscriber_count_notification() {
	admin_menu_notification('admin_menu_subscriber_count_notification', 'admin_menu_view_list');
}
function admin_menu_archive_count_notification() { 
	admin_menu_notification('admin_menu_archive_count_notification', 'admin_menu_view_archive');	
}

function admin_menu_notification(flavor, target_class) {
	var r = 60 * 5 * 1000; // Every 5 minutes. 
	var refresh_loop = function(no_loop) {
			var request = $.ajax({
				url: $('#navcontainer').attr("data-s_program_url"),
				type: "POST",
				cache: false,
				data: {
					f: flavor,
				},
				dataType: "html"
			});
			request.done(function(content) {
				if ($('.' + target_class + '_notification').length) {
					$('.' + target_class + '_notification').remove();
				}
				//console.log('update! ' + target_class); 
				$('.' + target_class).append('<span class="' + target_class + '_notification"> ' + content + '</span>');
			});
			if (no_loop != 1) {
				setTimeout(
				refresh_loop, r);
			}
		}
	setTimeout(refresh_loop, r);
	refresh_loop(1);
}

// Mass Mailings >> Monitor Your Mailings 

function update_sending_monitor_interface(message_id, type, target_id, refresh_after) {
	var r = refresh_after * 1000;
	var refresh_loop = function(no_loop) {
			var request = $.ajax({
				url: $("#s_program_url").val(),
				type: "POST",
				cache: false,
				data: {
					f: 'sending_monitor',
					id: message_id,
					type: type,
					process: 'ajax'
				},
				dataType: "html"
			});
			request.done(function(content) {
				$("#" + target_id).html(content);
				$("#progressbar").progressbar({
					value: ($("#progressbar_percent").val() / 1)
				});
			});
			if (no_loop != 1) {
				setTimeout(
				refresh_loop, r);
			}
		}
	setTimeout(
	refresh_loop, r);
	refresh_loop(1);
}

function refresh_tracker_plugin(tracker_url, message_id, target_id) {
	var tracker_refresh_loop = function(no_loop) {
			$("#tracker_reports_container").load(tracker_url, {
				chrome: 0,
				f: "m",
				mid: message_id
			}, function() {
				update_plugins_tracker_message_report();
			});
			if (no_loop != 1) {
				setTimeout(
				tracker_refresh_loop, 180000);
			}
		}
	setTimeout(
	tracker_refresh_loop, 180000);
	tracker_refresh_loop(1);
}



// Membership >> Invite/Add

function check_status() {
	$("#show_progress").show();
	keep_updating_status_bar = 1;
	update_status_bar();
}

var keep_updating_status_bar = 0;

function update_status_bar() {

	var update_status_bar_loop = function(no_loop) {

			if (keep_updating_status_bar == 0) {
				return;
			}
			// console.log('update_status_bar_loop called'); 
			var request = $.ajax({
				url: $("#s_program_url").val(),
				type: "GET",
				data: {
					f: 'check_status',
					new_email_file: $('#new_email_file').val(),
					rand_string: $('#rand_string').val()
				},
				dataType: "json",
				success: function(data) {
					//console.log('data.percent:"' + data.percent +  '"'); 
					//$.each(data, function(key, val) {
					//		console.log(key + ' => ' + val); 
					//});
					if (data.percent > 0) {
						$("#progressbar").progressbar({
							value: data.percent
						});
						$('#upload_status').html('<p>Uploading File: ' + data.percent + '%</p>');
						if (data.percent == 100) {
							keep_updating_status_bar = 0;
							no_loop = 1;
							$('#upload_status').html('<p>Upload Complete! Processing...</p>');
						}
						//console.log('done?'); 
					}
				},
				error: function(xhr, ajaxOptions, thrownError) {
					console.log('status: ' + xhr.status);
					console.log('thrownError:' + thrownError);
				}
			});
			if (no_loop != 1) {
				setTimeout(
				update_status_bar_loop, 1000);
			}
		}
	setTimeout(
	update_status_bar_loop, 1000);
}



/* Membership >> View List */

function view_list_viewport(initial) {
	$("#view_list_viewport_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'view_list',
			mode: 'viewport',
			type: $("#type").val(),
			page: $("#page").val(),
			query: $("#query").val(),
			order_by: $("#order_by").val(),
			order_dir: $("#order_dir").val()
		},
		dataType: "html"
	});
	request.done(function(content) {

		if (initial == 1) {
			$("#view_list_viewport").hide();
			$("#view_list_viewport").html(content);
			$("#view_list_viewport").show('fade');
		} else {
			$("#view_list_viewport").html(content);
		}

		$("#view_list_viewport_loading").html('<p class="alert">&nbsp;</p>');

		google.setOnLoadCallback(drawTrackerDomainBreakdownChart());
	});
}

function turn_page(page_to_turn_to) {
	$("#page").val(page_to_turn_to);
	view_list_viewport();
}

function change_type(type_to_go_to) {
	$("#type").val(type_to_go_to);
	$("#page").val(1);
	view_list_viewport();
}

function search_list() {
	$("#page").val(1);
	$("#query").val($("#search_query").val());
	view_list_viewport();
}

function clear_search() {
	$("#query").val('');
	$("#page").val(1);
	view_list_viewport();
}

function change_order(order_by, order_dir) {
	$("#order_by").val(order_by);
	$("#order_dir").val(order_dir);
	$("#page").val(1);
	view_list_viewport();
}

var domain_breakdown_chart; // you've got to be serious... 
var domain_breakdown_chart_data;

function drawTrackerDomainBreakdownChart() {
	$("#domain_break_down_chart_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#s_program_url").val(),
		dataType: "json",
		data: {
			f: 'domain_breakdown_json',
			type: $("#type").val(),
		},
		async: true,
		success: function(jsonData) {
			domain_breakdown_chart_data = new google.visualization.DataTable(jsonData);
			domain_breakdown_chart = new google.visualization.PieChart(document.getElementById('domain_break_down_chart'));

			var options = {
				chartArea: {
					left: 20,
					top: 20,
					width: "90%",
					height: "90%"
				},
				width: $('#domain_break_down_chart').attr("data-width"),
				height: $('#domain_break_down_chart').attr("data-height"),
				pieSliceTextStyle: {
					color: '#FFFFFF'
				},
				colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
				is3D: true
			};
			domain_breakdown_chart.draw(domain_breakdown_chart_data, options);
			$("#domain_break_down_chart_loading").html('<p class="alert">&nbsp;</p>');
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
	if (str != 'other') {
		$("#query").val($("#search_query").val("@" + str));
		$("#page").val(1);
		search_list()
	}
}


// Membership >> List Activity

function sub_unsub_trend_chart() {
	$("#amount").on("change", function(event) {
		draw_sub_unsub_trend_chart();
	});

/* 
backgroundColor: { 
	stroke: '#000000',
	strokeWidth: 1,
},
*/

	var options = {
		width: 720,
		height: 480,
		chartArea: {
			left: 60,
			top: 20,
			width: "70%",
			height: "70%"
		},

		colors: ['blue', 'red', 'green', 'orange'],
		title: "Subscription Trends",
		animation: {
			duration: 1000,
			easing: 'out',
		},
	};
	var data;
	var sub_unsub_trend_c = new google.visualization.AreaChart(document.getElementById('sub_unsub_trends'));

	function draw_sub_unsub_trend_chart() {
		$("#amount").prop('disabled', true);
		google.visualization.events.addListener(sub_unsub_trend_c, 'ready', function() {
			$("#amount").prop('disabled', false);
		});

		$("#sub_unsub_trends_loading").html('<p class="alert">Loading...</p>');
		$.ajax({
			url: $("#s_program_url").val(),
			data: {
				f: 'sub_unsub_trends_json',
				days: $("#amount option:selected").val()
			},
			dataType: "json",
			async: true,
			success: function(jsonData) {
				data = new google.visualization.DataTable(jsonData);
				sub_unsub_trend_c.draw(data, options);
				$("#sub_unsub_trends_loading").html('<p class="alert">&nbsp;</p>');
			},
		});
	}

	draw_sub_unsub_trend_chart();
}



// Membership >> user@example.com

function mailing_list_history() {
	$("#mailing_list_history_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'mailing_list_history',
			email: $("#email").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#mailing_list_history").hide().html(content).show('fade');

		$("#mailing_list_history_loading").html('<p class="alert">&nbsp;</p>');
	});
}

function updateEmail() {
	var is_for_all_lists = 0;
	if (
	$('#for_all_mailing_lists').val() == 1 && $("#for_all_mailing_lists").prop("checked") == true) {
		is_for_all_lists = 1;
	}
	$("#update_email_results_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'update_email_results',
			updated_email: $("#updated_email").val(),
			email: $("#original_email").val(),
			for_all_lists: is_for_all_lists
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#update_email_results").html(content);
		$("#update_email_results_loading").html('<p class="alert">&nbsp;</p>');
		$("#update_email_results").show('blind');
	});
}

function show_change_profile_password_form() {
	$("#change_profile_password_button").hide('blind');
	$("#change_profile_password_form").show('blind');
}

// Membership >> Invite 

function show_customize_invite_message() {
	$('#customize_invite_message_button').hide('blind');
	$('#customize_invite_message_form').show('blind');
}

// Mail Sending >> Sending Options

function sending_prefs_setup() {

	var hidden = new Array();
	var visible = new Array();

	if ($("#sending_method_sendmail").prop("checked") == true) {
		hidden = ['smtp_preferences', 'amazon_ses_preferences'];
		visible = ['sendmail_options'];
	}
	if ($("#sending_method_smtp").prop("checked") == true) {
		hidden = ['sendmail_options', 'amazon_ses_preferences'];
		visible = ['smtp_preferences'];
	}
	if ($("#sending_method_amazon_ses").prop("checked") == true) {
		hidden = ['sendmail_options', 'smtp_preferences'];
		visible = ['amazon_ses_preferences'];
	}

	var i;
	for (i = 0; i < hidden.length; i += 1) {
		if ($('#' + hidden[i]).is(':visible')) {
			$('#' + hidden[i]).hide('blind');
		}
	}
	i = 0;
	for (i = 0; i < visible.length; i += 1) {
		if ($('#' + visible[i]).is(':hidden')) {
			$('#' + visible[i]).show('blind');
		}
	}
}

function toggle_SASL_options() {
	if ($("#use_sasl_smtp_auth").prop("checked") == true) {
		if ($('#SASL_options').is(':hidden')) {
			$('#SASL_options').show('blind');
		}
	} else {
		if ($('#SASL_options').is(':visible')) {
			$('#SASL_options').hide('blind');
		}
	}
}

function toggle_pop_before_SMTP_options() {
	if ($("#use_pop_before_smtp").prop("checked") == true) {
		if ($('#pop_before_smtp_options').is(':hidden')) {
			$('#pop_before_smtp_options').show('blind');
		}
	} else {
		if ($('#pop_before_smtp_options').is(':visible')) {
			$('#pop_before_smtp_options').hide('blind');
		}
	}
}

function test_sending_preferences() {


	var set_smtp_sender = 0;
	if ($('#set_smtp_sender').prop('checked') == true) {
		set_smtp_sender = 1;
	}
	var pop3_use_ssl = 0; 
	if ($('#pop3_use_ssl').prop('checked') == true) {
		pop3_use_ssl = 1;
	}
	var use_pop_before_smtp = 0; 
	if ($('#use_pop_before_smtp').prop('checked') == true) {
		use_pop_before_smtp = 1;
	}	
	var use_sasl_smtp_auth = 0; 
	if ($('#use_sasl_smtp_auth').prop('checked') == true) {
		use_sasl_smtp_auth = 1;
	}	
	var use_smtp_ssl = 0; 
	if ($('#use_smtp_ssl').prop('checked') == true) {
		use_smtp_ssl = 1;
	}
	var add_sendmail_f_flag = 0; 
	if ($('#add_sendmail_f_flag').prop('checked') == true) {
		add_sendmail_f_flag = 1;
	}	
	
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: .50,
		href: $("#s_program_url").val(),
		data: {
			f: 'sending_preferences_test',
			sending_method: $('input[name=sending_method]:checked').val(),
			add_sendmail_f_flag: add_sendmail_f_flag,
			smtp_server: $('#smtp_server').val(),
			smtp_port: $('#smtp_port').val(),
			use_smtp_ssl: use_smtp_ssl,
			use_sasl_smtp_auth: use_sasl_smtp_auth,
			sasl_auth_mechanism: $('#sasl_auth_mechanism').val(),
			sasl_smtp_username: $('#sasl_smtp_username').val(),
			sasl_smtp_password: $('#sasl_smtp_password').val(),
			use_pop_before_smtp: use_pop_before_smtp,
			pop3_server: $('#pop3_server').val(),
			pop3_username: $('#pop3_username').val(),
			pop3_password: $('#pop3_password').val(),
			pop3_use_ssl: pop3_use_ssl,
			set_smtp_sender: set_smtp_sender,
			process: $('#process').val()
		}
	});
}





function amazon_verify_email() {
	
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: .50,
		href: $("#s_program_url").val(),
		data: {
			f: 'amazon_ses_verify_email',
			amazon_ses_verify_email: $("#amazon_ses_verify_email").val()
		}
	});
	
}


// Mail Sending >> Mass Mailing Options 

function previewBatchSendingSpeed() {
	$("#previewBatchSendingSpeed_loading").hide().html('<p class="alert">Loading...</p>').show('fade');


	var enable_bulk_batching = 0;
	if ($('#enable_bulk_batching').prop('checked') == true) {
		enable_bulk_batching = 1;
	}
	var amazon_ses_auto_batch_settings = 0;
	if ($("#amazon_ses_get_stats").length) {
		if ($('#amazon_ses_auto_batch_settings').prop('checked') == true) {
			amazon_ses_auto_batch_settings = 1;
		}
	}

	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'previewBatchSendingSpeed',
			enable_bulk_batching: enable_bulk_batching,
			mass_send_amount: $('#mass_send_amount').val(),
			bulk_sleep_amount: $('#bulk_sleep_amount').val(),
			amazon_ses_auto_batch_settings: amazon_ses_auto_batch_settings
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#previewBatchSendingSpeed").hide("fade", function() {
			$("#previewBatchSendingSpeed").html(content);
			$("#previewBatchSendingSpeed_loading").html('');
			$("#previewBatchSendingSpeed").show('fade');
		});
	});


}

function amazon_ses_get_stats() {
	$("#amazon_ses_get_stats_loading").hide().html('<p class="alert">Loading...</p>').show('fade');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'amazon_ses_get_stats',
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#amazon_ses_get_stats").hide("fade", function() {
			$("#amazon_ses_get_stats").html(content);
			$("#amazon_ses_get_stats_loading").html('');
			$("#amazon_ses_get_stats").show('fade');
		});
	});
}

function toggleManualBatchSettings() {
	if ($("#amazon_ses_auto_batch_settings").prop("checked") == true) {
		$("#manual_batch_settings").hide('fade');
	} else {
		if ($('#manual_batch_settings').is(":hidden")) {
			$("#manual_batch_settings").show('fade');
		}
	}
	previewBatchSendingSpeed();
}

// Installer 

function installer_test_sql_connection() {
	var target_div = 'test_sql_connection_results';
	$("#" + target_div).html('<p class="alert">Loading...</p>');
	if ($("#" + target_div).is(':hidden')) {
		$("#" + target_div).show();
	}

	var request = $.ajax({
		url: $("#self_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'cgi_test_sql_connection',
			backend: $("#backend").val(),
			sql_server: $("#sql_server").val(),
			sql_port: $("#sql_port").val(),
			sql_database: $("#sql_database").val(),
			sql_username: $("#sql_username").val(),
			sql_password: $("#sql_password").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		//$("#" + target_div).hide('fade');
		$("#" + target_div).html(content);
		//$("#" + target_div).show('fade');
	});

}

function installer_test_pop3_connection() {
	var target_div = 'test_bounce_handler_pop3_connection_results';
	$("#" + target_div).html('<p class="alert">Loading...</p>');
	if ($("#" + target_div).is(':hidden')) {
		$("#" + target_div).show();
	}

	var request = $.ajax({
		url: $("#self_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'cgi_test_pop3_connection',
			bounce_handler_server: $("#bounce_handler_server").val(),
			bounce_handler_username: $("#bounce_handler_username").val(),
			bounce_handler_password: $("#bounce_handler_password").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		//$("#" + target_div).hide('fade');
		$("#" + target_div).html(content);
		//$("#" + target_div).show('fade');
	});
}



function test_amazon_ses_configuration() {
	var target_div = 'test_amazon_ses_configuration_results';
	$("#" + target_div).html('<p class="alert">Loading...</p>');
	if ($("#" + target_div).is(':hidden')) {
		$("#" + target_div).show();
	}

	var request = $.ajax({
		url: $("#self_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'cgi_test_amazon_ses_configuration',
			amazon_ses_AWSAccessKeyId: $("#amazon_ses_AWSAccessKeyId").val(), 
			amazon_ses_AWSSecretKey: $("#amazon_ses_AWSSecretKey").val(), 	
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#" + target_div).html(content);
	});
}



function installer_dada_root_pass_options() {
	if ($("#dada_pass_use_orig").prop("checked") == true) {
		if ($('#dada_root_pass_fields').is(':visible')) {
			$('#dada_root_pass_fields').hide('blind');
		}
	}
	if ($("#dada_pass_use_orig").prop("checked") == false) {
		if ($('#dada_root_pass_fields').is(':hidden')) {
			$('#dada_root_pass_fields').show('blind');
		}
	}

}

function installer_toggleSQL_options() {

	var selected = $("#backend option:selected").val();
	if (selected == 'mysql' || selected == 'Pg') {
		if ($('#sql_info').is(':hidden')) {
			$('#sql_info').show('blind');
		}
	} else {
		if ($('#sql_info').is(':visible')) {
			$('#sql_info').hide('blind');
		}
	}
}

function installer_toggle_dada_files_dirOptions() {

	if ($("#dada_files_dir_setup_auto").prop("checked") == true) {
		if ($('#manual_dada_files_dir_setup').is(':visible')) {
			$('#manual_dada_files_dir_setup').hide('blind');
		}
	}
	if ($("#dada_files_dir_setup_manual").prop("checked") == true) {
		if ($('#manual_dada_files_dir_setup').is(':hidden')) {
			$('#manual_dada_files_dir_setup').show('blind');
		}
	}
}

function installer_togger_bounce_handler_config() {
	if ($("#install_bounce_handler").prop("checked") == true) {
		if ($('#additional_bounce_handler_configuration').is(':hidden')) {
			$('#additional_bounce_handler_configuration').show('blind');
		}
	} else {
		if ($('#additional_bounce_handler_configuration').is(':visible')) {
			$('#additional_bounce_handler_configuration').hide('blind');
		}
	}
}

function installer_toggle_wysiwyg_editors_options() {
	if ($("#install_wysiwyg_editors").prop("checked") == true) {
		if ($('#install_wysiwyg_editors_options').is(':hidden')) {
			$('#install_wysiwyg_editors_options').show('blind');
		}
	} else {
		if ($('#install_wysiwyg_editors_options').is(':visible')) {
			$('#install_wysiwyg_editors_options').hide('blind');
		}
	}
}

function installer_toggle_configure_amazon_ses_options() { 
	if ($("#configure_amazon_ses").prop("checked") == true) {
		if ($('#amazon_ses_options').is(':hidden')) {
			$('#amazon_ses_options').show('blind');
		}
	} else {
		if ($('#amazon_ses_options').is(':visible')) {
			$('#amazon_ses_options').hide('blind');
		}
	}	
}

function installer_move_installer_dir() {

	$("#move_results").hide();
	var request = $.ajax({
		url: $("#self_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'move_installer_dir_ajax',
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#move_results").html(content);
		$("#move_results").show('blind');
	});
}









// Plugins >> Bounce Bounce Handler

function bounce_handler_show_scorecard() {
	$("#bounce_scorecard_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'cgi_scorecard',
			page: $('#bounce_handler_page').val(),
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#bounce_scorecard").hide('fade', function() {
			$("#bounce_scorecard").html(content);
			$("#bounce_scorecard").show('fade');
			$("#bounce_scorecard_loading").html('<p class="alert">&nbsp;</p>');
		});


	});
}


function bounce_handler_turn_page(page_to_turn_to) {
	$("#bounce_handler_page").val(page_to_turn_to);
	bounce_handler_show_scorecard();
}

function bounce_handler_parse_bounces() {
	$("#parse_bounce_results_loading").html('<p class="alert">Loading</p>');
	$("#parse_bounces_button").val('Parsing...');
	
	var isa_test = 0; 
	if($("#test").prop("checked") == true) { 
		isa_test = 'bounces';
	}
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor:       'ajax_parse_bounces_results',
			parse_amount: $('#parse_amount').val(),
			test:         isa_test
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#parse_bounce_results").html(content);
		$("#parse_bounces_button").val('Parse Bounces');
		$("#parse_bounce_results_loading").html('<p class="alert">&nbsp;</p>');

	});
}

function ajax_parse_bounces_results() {
	
	var isa_test = 0; 
	if($("#test").prop("checked") == true) { 
		isa_test = 'bounces';
	}
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: .50,
		href: $("#plugin_url").val(),
		data: {
			flavor: 'ajax_parse_bounces_results',
			parse_amount: $('#parse_amount').val(),
			test:         isa_test
		},
		onComplete:function(){
			bounce_handler_show_scorecard();
		},
	});
}

function bounce_handler_manually_enter_bounces() {
	var target_id = 'manually_enter_bounces_results';
	$("#" + target_id + "_loading").html('<p class="alert">Loading</p>');
	$("#" + target_id).html('');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'manually_enter_bounces',
			process: $('#process').val(),
			msg: $('#msg').val(),
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#" + target_id).html(content);
		$("#" + target_id + "_loading").html('<p class="alert">&nbsp;</p>');

	});

}


// Plugins >> Bridge 

function bridge_setup_list_email_type_params() {
	if ($("#mail_forward_pipe").prop("checked") == true) {
		if ($('#bridge_mail_forward_pipe_params').is(':hidden')) {
			$('#bridge_mail_forward_pipe_params').show('blind');
		}
		if ($('#bridge_pop3_account_params').is(':visible')) {
			$('#bridge_pop3_account_params').hide('blind');
		}
	}
	if ($("#pop3_account").prop("checked") == true) {
		if ($('#bridge_pop3_account_params').is(':hidden')) {
			$('#bridge_pop3_account_params').show('blind');
		}
		if ($('#bridge_mail_forward_pipe_params').is(':visible')) {
			$('#bridge_mail_forward_pipe_params').hide('blind');
		}
	}
}

function plugins_bridge_test_pop3() {
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: .50,
		href: $("#plugin_url").val(),
		data: {
			flavor: 'cgi_test_pop3_ajax',
			server: $("#discussion_pop_server").val(),
			username: $("#discussion_pop_username").val(),
			password: $("#discussion_pop_password").val(),
			auth_mode: $("#discussion_pop_auth_mode option:selected").val(),
			use_ssl: $("#discussion_pop_use_ssl").prop("checked")
		}
	});
}

function plugins_bridge_manually_check_messages() {
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: .50,
		href: $("#plugin_url").val(),
		data: {
			flavor: 'admin_cgi_manual_start_ajax',
		}
	});
}

// Plugins >> Mailing Monitor 

function plugins_mailing_monitor() {
	$("#mailing_monitor_results_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'mailing_monitor_results',
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#mailing_monitor_results").html(content);
		$("#mailing_monitor_results_loading").html('<p class="alert">&nbsp;</p>');
	});

}
// Plugins >> Tracker

function update_plugins_tracker_message_report() {

	var $tabs = $("#tabs").tabs();
	$('body').on('click', '.to_clickthroughs', function(event) {
		$tabs.tabs('select', 0);
		return false;
	});
	$('body').on('click', '.to_opens', function(event) {
		$tabs.tabs('select', 1);
		return false;
	});
	$('body').on('click', '.to_archive_views', function(event) {
		$tabs.tabs('select', 2);
		return false;
	});
	$('body').on('click', '.to_forwards', function(event) {
		$tabs.tabs('select', 3);
		return false;
	});
	$('body').on('click', '.to_bounces', function(event) {
		$tabs.tabs('select', 4);
		return false;
	});

	$("body").on("click", '.individual_country_geoip', function(event) {
		event.preventDefault();
		individual_country_geoip_map($(this).attr("data-type"), $(this).attr("data-country"), "country_geoip_" + $(this).attr("data-type") + "_map");
	});

	$("body").on("click", '.individual_country_cumulative_geoip_table', function(event) {
		event.preventDefault();
		individual_country_cumulative_geoip_table($(this).attr("data-type"), $(this).attr("data-country"), "country_geoip_" + $(this).attr("data-type") + "_map");
	});

	$("body").on("click", '.back_to_geoip_map', function(event) {
		event.preventDefault();
		country_geoip_map($(this).attr("data-type"), "country_geoip_" + $(this).attr("data-type") + "_map");
	});


	if ($("#can_use_country_geoip_data").val() == 1) {

		country_geoip_table('clickthroughs', 'Clickthroughs', 'country_geoip_clickthroughs_table');
		country_geoip_table('opens', 'Opens', 'country_geoip_opens_table');
		country_geoip_table('view_archive', 'Archive Views', 'country_geoip_view_archive_table');
		country_geoip_table('forward_to_a_friend', 'Forwards', 'country_geoip_forwards_table');


		google.setOnLoadCallback(country_geoip_map('clickthroughs', 'country_geoip_clickthroughs_map'));
		google.setOnLoadCallback(country_geoip_map('opens', 'country_geoip_opens_map'));
		google.setOnLoadCallback(country_geoip_map('view_archive', 'country_geoip_view_archive_map'));
		google.setOnLoadCallback(country_geoip_map('forward_to_a_friend', 'country_geoip_forwards_map'));

	}

	google.setOnLoadCallback(data_over_time_graph('clickthroughs', 'Clickthroughs', 'over_time_clickthroughs_graph'));
	google.setOnLoadCallback(data_over_time_graph('opens', 'Opens', 'over_time_opens_graph'));
	google.setOnLoadCallback(data_over_time_graph('view_archive', 'Archive Views', 'over_time_view_archive_graph'));
	google.setOnLoadCallback(data_over_time_graph('forward_to_a_friend', 'Forwards', 'over_time_forwards_graph'));



	google.setOnLoadCallback(bounce_breakdown_chart('soft', 'Soft Bounces', 'soft_bounce_graph'));
	google.setOnLoadCallback(bounce_breakdown_chart('hard', 'Hard Bounces', 'hard_bounce_graph'));

	message_bounce_report_table('soft', 'soft_bounce_table');
	message_bounce_report_table('hard', 'hard_bounce_table');

}

function country_geoip_table(type, label, target_div) {

	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'country_geoip_table',
			mid: $('#tracker_message_id').val(),
			type: type,
			label: label,
		},
		dataType: "html"
	});
	request.done(function(content) {

		$("#" + target_div).hide();
		$("#" + target_div).html(content);
		$("#" + target_div).show('fade');

		$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
		$("#sortable_table_" + type).tablesorter();
	});
}


var country_geoip_map_infos = {
	clickthroughs: {
		type: 'clickthroughs',
		data: '',
		chart: '',
	},
	opens: {
		type: 'opens',
		data: '',
		chart: '',
	},
	view_archive: {
		type: 'view_archive',
		data: '',
		chart: '',
	},
	forward_to_a_friend: {
		type: 'forward_to_a_friend',
		data: '',
		chart: '',
	},


};

function country_geoip_map(type, target_div) {

	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		data: {
			f: 'country_geoip_json',
			mid: $('#tracker_message_id').val(),
			type: type,
		},
		dataType: "json",
		cache: false,
		async: true,
		success: function(jsonData) {
			// Create our data table out of JSON data loaded from server.
			var data = new google.visualization.DataTable(jsonData);
			var options = {
				region: 'world',
				width: $('#' + target_div).attr("data-width"),
				height: $('#' + target_div).attr("data-height"),
				keepAspectRatio: true,
				backgroundColor: "#FFFFFF",
				colorAxis: {
					colors: ['#e5f2ff', '#ff0066']
				}
			};
			var chart = new google.visualization.GeoChart(document.getElementById(target_div));

			$("#" + target_div).hide("fade", function() {
				chart.draw(data, options);
				$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
				$("#" + target_div).show('fade');
			});

			google.visualization.events.addListener(chart, 'select', country_geoip_map_selectHandler);

			function country_geoip_map_selectHandler(event) {
				var selectedItem = chart.getSelection()[0];
				if (selectedItem) {
					var country_code = data.getValue(selectedItem.row, 0);
					individual_country_geoip_map(type, country_code, "country_geoip_" + type + "_map");
				}
			}
		}
	});

}


function individual_country_geoip_map(type, country, target_div) {
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		data: {
			f: 'individual_country_geoip_json',
			mid: $('#tracker_message_id').val(),
			type: type,
			country: country
		},
		dataType: "json",
		async: true,
		success: function(jsonData) {
			// Create our data table out of JSON data loaded from server.
			var data = new google.visualization.DataTable(jsonData);
			var options = {
				region: country,
				displayMode: 'markers',
				resolution: 'provinces',
				width: $('#' + target_div).attr("data-width"),
				height: $('#' + target_div).attr("data-height"),
				colorAxis: {
					colors: ['#3399ff', '#ff0066']
				}
			};
			var chart = new google.visualization.GeoChart(document.getElementById(target_div));

			$("#" + target_div).hide("fade", function() {
				chart.draw(data, options);
				$("#" + target_div + "_loading").html('<p class="alert"><a href="#" data-type="' + type + '" class="back_to_geoip_map">&lt; &lt;Back to World Map</a> | <a href="#"  data-type="' + type + '" data-country="' + country + '" class="individual_country_cumulative_geoip_table">Table View</a></p>');
				$("#" + target_div).show('fade');
			});
		}
	});
}

function individual_country_cumulative_geoip_table(type, country, target_div) {
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		data: {
			f: 'individual_country_geoip_report_table',
			mid: $('#tracker_message_id').val(),
			type: 'ALL',
			country: country
		},
		dataType: "html",
		async: true,
		success: function(content) {
			$("#" + target_div).hide("fade", function() {
				$("#" + target_div).html(content);
				$("#" + target_div + "_loading").html('<p class="alert"><a href="#" data-type="' + type + '" data-country="' + country + '"  class="individual_country_geoip">&lt; &lt; Back to Country Map</a></p>');
				$("#" + target_div).show('fade');
			});
		}
	});

}

function data_over_time_graph(type, label, target_div) {
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		data: {
			f: 'data_over_time_json',
			mid: $("#tracker_message_id").val(),
			type: type,
			label: label,
		},
		cache: false,
		dataType: "json",
		async: true,
		success: function(jsonData) {
			var data = new google.visualization.DataTable(jsonData);
			var options = {
				chartArea: {
					left: 60,
					top: 20,
					width: "70%",
					height: "70%"
				},
				width: $('#' + target_div).attr("data-width"),
				height: $('#' + target_div).attr("data-height"),
				backgroundColor: {
					stroke: '#FFFFFF',
					strokeWidth: 0
				},
				hAxis: {
					slantedText: true
				}
			};
			var chart = new google.visualization.AreaChart(document.getElementById(target_div));
			chart.draw(data, options);
			$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
		},
	});
}

function message_bounce_report_table(bounce_type, target_div) {

	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'message_bounce_report_table',
			mid: $('#tracker_message_id').val(),
			bounce_type: bounce_type
		},
		dataType: "html"
	});
	request.done(function(content) {

		$("#" + target_div).hide();
		$("#" + target_div).html(content);
		$("#" + target_div).show('fade');

		$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
		//	  $("#sortable_table_" + type).tablesorter(); 
	});
}

function bounce_breakdown_chart(type, label, target_div) {
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		dataType: "json",
		data: {
			f: 'bounce_stats_json',
			mid: $('#tracker_message_id').val(),
			bounce_type: type,
			label: label
		},
		async: true,
		success: function(jsonData) {
			var data = new google.visualization.DataTable(jsonData);
			var chart = new google.visualization.PieChart(document.getElementById(target_div));
			var options = {
				chartArea: {
					left: 20,
					top: 20,
					width: "90%",
					height: "90%"
				},
				title: $('#' + target_div).attr("data-title"),
				width: $('#' + target_div).attr("data-width"),
				height: $('#' + target_div).attr("data-height"),

				pieSliceTextStyle: {
					color: '#FFFFFF'
				},
				colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
				is3D: true
			};
			chart.draw(data, options);
			$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
		},
	});
}


// Plugins >> Tracker

function tracker_change_record_view() {
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'save_view_count_prefs',
			tracker_record_view_count: $('#tracker_record_view_count option:selected').val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		message_history_html();
		google.setOnLoadCallback(drawSubscriberHistoryChart());
	});

}

function tracker_turn_page(page_to_turn_to) {
	$("#tracker_page").val(page_to_turn_to);
	message_history_html();
	google.setOnLoadCallback(drawSubscriberHistoryChart());
}

function tracker_parse_links_setup() {
	if ($("#tracker_auto_parse_links").prop("checked") == true) {
		if ($('#tracker_auto_parse_links_info').is(':hidden')) {
			$('#tracker_auto_parse_links_info').show('blind');
		}
		if ($('#tracker_noauto_parse_links_info').is(':visible')) {
			$('#tracker_noauto_parse_links_info').hide('blind');
		}
	}
	if ($("#tracker_noauto_parse_links").prop("checked") == true) {
		if ($('#tracker_noauto_parse_links_info').is(':hidden')) {
			$('#tracker_noauto_parse_links_info').show('blind');
		}
		if ($('#tracker_auto_parse_links_info').is(':visible')) {
			$('#tracker_auto_parse_links_info').hide('blind');
		}
	}
}


// Plugins >> Log Viewer

function view_logs_results() {
	$("#refresh_button").val('Loading....');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'ajax_view_logs_results',
			log_name: $('#log_name').val(),
			lines: $('#lines').val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#view_logs_results").html(content);
		$("#refresh_button").val('Refresh');
	});
}

function delete_log() {
	var confirm_msg = "Are you sure you want to delete this log? ";
	confirm_msg += "There is no way to undo this deletion.";
	if (confirm(confirm_msg)) {
		var request = $.ajax({
			url: $("#plugin_url").val(),
			type: "POST",
			cache: false,
			data: {
				flavor: 'ajax_delete_log',
				log_name: $('#log_name').val(),
			},
			dataType: "html"
		});
		request.done(function(content) {
			view_logs_results();
		});
	} else {
		alert('Log deletion canceled.');
	}
}





function message_history_html() {

	$("#show_table_results_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'message_history_html',
			page: $("#tracker_page").val(),
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#show_table_results").hide('fade', function() {
			$("#show_table_results").html(content);
			$("#show_table_results").show('fade');
			$("#show_table_results_loading").html('<p class="alert">&nbsp;</p>');
		});

	});
}

var SubscriberHistoryChart;

function drawSubscriberHistoryChart() {
	$("#subscriber_history_chart_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		data: {
			f: 'message_history_json',
			page: $("#tracker_page").val(),

		},
		cache: false,
		dataType: "json",
		async: true,
		success: function(jsonData) {
			var data = new google.visualization.DataTable(jsonData);
			var options = {
				chartArea: {
					left: 60,
					top: 20,
					width: "70%",
					height: "70%"
				},
				width: 720,
				height: 400
			};
			var SubscriberHistoryChart = new google.visualization.LineChart(document.getElementById('subscriber_history_chart'));
			$("#subscriber_history_chart").hide('fade');
			SubscriberHistoryChart.draw(data, options);
			$("#subscriber_history_chart").show('fade');
			$("#subscriber_history_chart_loading").html('<p class="alert">&nbsp;</p>');

		},
	});
}


function tracker_purge_log() {
	var confirm_msg = "Are you sure you want to delete this log? ";
	confirm_msg += "There is no way to undo this deletion.";
	if (confirm(confirm_msg)) {
		var request = $.ajax({
			url: $("#plugin_url").val(),
			type: "POST",
			cache: false,
			data: {
				f: 'ajax_delete_log',
			},
			dataType: "html"
		});
		request.done(function(content) {
			message_history_html();
			google.setOnLoadCallback(drawSubscriberHistoryChart());
		});
		// something like request.error(function () { ... });
		//onFailure: function() { 
		//	alert('Warning! Something went wrong when attempting to remove the log file.'); 
		//	}
	} else {
		alert('Log deletion canceled.');
		return false;
	}
}

// Plugins >> Password Protect Directories

function password_protect_directories_show_change_password_form() {
	$("#change_default_password_button").hide('blind');
	$("#change_default_password_form").show('blind');
}









/* Global */

function toggleCheckboxes(status, target_class) {
	$('.' + target_class).each(function() {
		$(this).prop("checked", status);
	});
}

function toggleDisplay(target) {
	$('#' + target).toggle('blind');
}

function changeDisplayState(target, state) {
	if (state == 'show') {
		if ($('#' + target).is(':hidden')) {
			$('#' + target).show('blind');
		}
	} else {
		if ($('#' + target).is(':visible')) {
			$('#' + target).hide('blind');
		}
	}
}



var refreshLocation = '';

function preview() {
	var new_window = window.open("", "preview", "top=100,left=100,resizable,scrollbars,width=400,height=200");
}

function SetChecked(val) {

	dml = document.email_form;
	len = dml.elements.length;
	var i = 0;
	for (i = 0; i < len; i++) {
		if (dml.elements[i].name == 'address') {
			dml.elements[i].checked = val;
		}
	}
}

function SetListChecked(val) {

	dml = document.send_email;
	len = dml.elements.length;
	var i = 0;
	for (i = 0; i < len; i++) {
		if (dml.elements[i].name == 'alternative_list') {
			dml.elements[i].checked = val;
		}
	}
}

function set_to_default() {

	document.the_form.target = "_self";
	default_template = document.the_form.default_template.value;
	document.the_form.template_info.value = default_template;
}


function list_message_status(thing) {
	document.the_form.process.value = thing;
}


function preview_template() {

	document.the_form.target = "_blank";
	document.the_form.process.value = "preview template";

}

function change_template() {

	document.the_form.target = "_self";
	document.the_form.process.value = "true";
}

function check_newest_version(ver) {

	var check = "http://dadamailproject.com/cgi-bin/support/version.cgi?version=" + ver;
	window.open(check, 'version', 'width=325,height=300,top=20,left=20');
}

function just_test_message() {

	document.the_form.process.value = "just_test_message";

}


function real_message() {

	document.the_form.process.value = "true";

}






function toggleTwo(targetOpen, targetClose) {
	Effect.BlindUp($(targetClose));
	Effect.BlindDown($(targetOpen));
}


function preview_message_receivers() {

	var f_params = {};

	var al = new Array();
	var alternative_lists = '';
	var multi_list_send_no_dupes = 0;


	$("#field_comparisons :input").each(function() {
		f_params[this.name] = this.value;
	});
	$("input:checkbox[name=alternative_list]:checked").each(function() {
		al.push(this.value);
	});
	alternative_lists = al.join(',');
	if (
	$('#multi_list_send_no_dupes').val() == 1 && $("#multi_list_send_no_dupes").prop("checked") == true) {
		multi_list_send_no_dupes = 1;
	}

	f_params['f'] = 'preview_message_receivers';
	f_params['alternative_lists'] = alternative_lists;
	f_params['multi_list_send_no_dupe'] = multi_list_send_no_dupes;

	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: .50,
		href: $("#s_program_url").val(),
		data: f_params
	});

}

function ChangeMassMailingButtonLabel() {
	if ($("#archive_message").prop("checked") == true && $("#archive_no_send").prop("checked") == true) {
		$("#submit_mass_mailing").prop('value', 'Archive Message');
		$('#submit_test_mailing').hide('fade');
		$('#send_test_messages_to').hide('fade');
	} else {
		$("#submit_mass_mailing").prop('value', $("#default_mass_mailing_button_label").val());
		$('#submit_test_mailing').show('fade');
		$('#send_test_messages_to').show('fade');
	}
}


function sendMailingListMessage(fid, itsatest) { /* This is for the Send a Webpage - did they fill in a URL? */
	if ($("#f").val() == 'send_url_email') {
		if ($('input[name=sending_method]:checked').val() == 'url') {
			if (
			$("#url").val() == 'http://' || $("#url").val().length <= 0) {
				alert('You have not filled in a URL! Mass Mailing Stopped.');
				return false;
			}
		}
	}

	var itsatest_label = '';
	if (itsatest == true) {
		itsatest_label = "*test*"
	}

	var confirm_msg = "Are you sure you want this ";
	confirm_msg += itsatest_label;
	confirm_msg += " mailing to be sent?";
	confirm_msg += " Mailing list sending cannot be easily stopped.";

	if ($("#Subject").val().length <= 0) {
		var no_subject_msg = "The Subject: header of this message has been left blank. Send anyways?";
		if (!confirm(no_subject_msg)) {
			alert('Mass Mailing canceled.');
			return false;
		}
	}
	if ($("#im_sure").prop("checked") == false) {
		if (!confirm(confirm_msg)) {
			alert('Mass Mailing canceled.');
			return false;
		}
	}
	if ($("#new_win").prop("checked") == true) {
		$("#" + fid).attr("target", "_blank");
	} else {
		$("#" + fid).attr("target", "_self");
	}
	return true;
}


function warnAboutMassSubscription() {

	var confirm_msg = "Are you sure you want to subscribe the selected email address(es) to your list? ";
	confirm_msg += "\n\n";

	confirm_msg += "Subscription of unconfirmed email address(es) should always be avoided. ";
	confirm_msg += "\n\n";

	confirm_msg += " If wanting to add unconfirmed email address(es), use the \"Send Invitation... >>\"";
	confirm_msg += " option to allow the subscriber to confirm their own subscription.";

	if (!confirm(confirm_msg)) {
		alert('Mass Subscription Stopped.');
		return false;
	} else {}
	return true;
}


function unsubscribeAllSubscribers(form_name, type) {

	var confirm_msg = '';
	if (type == 'Subscribers') {
		confirm_msg = "Are you sure you want to unsubscribe all Subscribers? ";
	} else {
		confirm_msg = "Are you sure you want to remove all " + type + "?";
	}

	if (!confirm(confirm_msg)) {
		if (type == 'Subscribers') {
			alert("Subscribers not unsubscribed.");
		} else {
			alert("'" + type + "' not removed.");

		}
		return false;
	} else {
		return true;
	}

}

function removeAllArchives(form_name) {

	var confirm_msg = "Are you sure you want to purge all your mailing list archives?";
	if (!confirm(confirm_msg)) {
		alert("Archives not purged.");
		return false;
	} else {
		return true;
	}

}

function revertEditType(form_name) {

	var confirm_msg = "Are you sure you want to revert to the default for ALL email messages?";
	if (!confirm(confirm_msg)) {
		alert("Messages not reverted to default.");
		return false;
	} else {
		return true;
	}

}






function killMonitoredSending() {

	var confirm_msg = "Are you sure you want to STOP this Mass Mailing?";
	confirm_msg += " Once this mailing has been stopped, it cannot be restarted.";
	if (!confirm(confirm_msg)) {
		alert('Continuing...');
		return false;
	} else {
		return true;
	}

}

function pauseMonitoredSending() {

	var confirm_msg = "Are you sure you want to PAUSE this mailing? ";
	confirm_msg += " Email sending will be stopped immediately after this current batch has completed. Email sending may be resumed at any time.";
	if (!confirm(confirm_msg)) {
		alert('Continuing...');
		return false;
	} else {
		return true;
	}

}

var refreshTimerId = 0;
var refreshLoc = '';
var refreshTime = '';

function refreshpage(sec, url) {
	var refreshAfter = sec / 1 * 1000;
	refreshTime = refreshAfter / 1000;
	if (url) {
		refreshLocation = url;
		refreshLoc = refreshLocation;
		refreshTimerId = setInterval("doRefresh(refreshLocation);", refreshAfter);
	}

}

function doRefresh(loc) {
	window.location.replace(loc);
}

function removeSubscriberField(form_name) {

	var confirm_msg = "Are you sure you want to ";
	confirm_msg += " permanently remove this field?";
	confirm_msg += " All saved informaton in the field for all subscribers will be lost.";

	if (!confirm(confirm_msg)) {
		alert('Subscriber field removal has been canceled.');
		return false;
	}

	form_name.target = "_self";

}
