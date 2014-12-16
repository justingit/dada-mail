var plainOverlayOptions = {
		opacity: 0.1,  
		color: '#666', 
		progress: function() { 
			return $('<div class="spinner_bg"></div>'); 
		}
};

$(document).ready(function() {
				
	$("a.modalbox").live("click", function(event) {
		event.preventDefault();
		$.colorbox({
			top: 0,
			fixed: true,
			initialHeight: 50,
			maxHeight: 480,
			maxWidth: 649,
			opacity: 0.50,
			href: $(this).attr("href")
		});
	});

	// Admin Menu
	
	if ($("#change_to_list_form").length) {
		$("#change_to_list").select2();
		$("body").on("submit", "#change_to_list_form", function(event) {
			event.preventDefault();
		});
		$("body").on("click", "#submit_change_to_list", function(event) {
			$("#change_to_list").val($("#change_to_list").select2("val"));
			$("body").off('submit', '#change_to_list_form');
			return true;
		});		
	}
	
	if ($("#navcontainer").length) {
		
		var admin_menu_callbacks = $.Callbacks();
		admin_menu_callbacks.add(admin_menu_drafts_notification());
		admin_menu_callbacks.add(admin_menu_sending_monitor_notification());
		admin_menu_callbacks.add(admin_menu_subscriber_count_notification());
		admin_menu_callbacks.add(admin_menu_archive_count_notification());
		admin_menu_callbacks.add(admin_menu_sending_preferences_notification());
		admin_menu_callbacks.add(admin_menu_bounce_handler_notification());
		admin_menu_callbacks.fire();
		
		if($("#screen_meta").length) { 
			var highlight_scrn = $("#screen_meta").attr("data-menu_highlight");
			$( "#admin_menu_" + highlight_scrn ).addClass( "menu_selected" );
		}
		else { 
			/* alert("needs a highlight_scrn"); */
		}
	
		$("body").on("click", "#navcontainer", function(event) {
			$( "a" ).removeClass( "menu_selected" );
		});
		
	}
	
	

	//Mail Sending >> Send a Message 
	if ($("#send_email_screen").length || $("#send_url_email").length || $("#list_invite").length) {
		
	  var msie6 = $.browser == 'msie' && $.browser.version < 7;
	  if (!msie6) {
	    var top = $('#buttons').offset().top - parseFloat($('#buttons').css('margin-top').replace(/auto/, 0));
	    $(window).scroll(function (event) {
	      // what the y position of the scroll is
	      var y = $(this).scrollTop();

	      // whether that's below the form
	      if (y >= top) {
	        // if so, ad the fixed class
	        $('#buttons').addClass('fixed');
	      } else {
	        // otherwise remove it
	        $('#buttons').removeClass('fixed');
	      }
	    });
	  }
		
		$("body").on("click", ".kcfinder_open", function(event) {
			event.preventDefault();
			
			if($("#kcfinder_enabled").val() == 1) { 
				attachments_openKCFinder(this);
			}else if($("#core5_filemanager_enabled").val() == 1){ 
				browsecore5FileManager(this);
			}
			else { 
				alert("No File Browser set up!");
			}
		});
		
		datetimesetupstuff(); 
		
		if($('#schedule_datetime').length) { 
			$('#schedule_datetime').datetimepicker(
				{
					minDate: 0,
					minTime: 0, 
					inline:false, 
					format:'Y-m-d H:i:s'
				}
			);
		}
		
		
		
		
		if($('#backdate_datetime').length) { 
			$('#backdate_datetime').datetimepicker({maxDate: 0, format:'Y-m-d H:i:s'});
			
			if($('#backdate_datetime').val() == ""){ 
				var d       = new Date();
				var year    = d.getFullYear();
				var month   = d.getMonth() + 1;
				var day     = d.getDate();
				var hours   = d.getHours();
				var minutes = d.getMinutes();
				var seconds = d.getSeconds();
				if(month < 10) { 
						month = "0" + month; 
				}
				if(day < 10) { 
						day = "0" + day; 
				}
				if(hours < 10) { 
						hours = "0" + hours; 
				}
				if(minutes < 10) { 
						minutes = "0" + minutes; 
				}
				if(seconds < 10) { 
					seconds = "0" + seconds; 
				}
				$("#backdate_datetime").val(year + "-" + month + "-" + day + " " + hours + ":" + minutes + ":" + seconds); 
			}
		}
		
		setup_attachment_fields(); 
		$("body").on("click", ".remove_attachment", function(event) {
			if(confirm("Remove Attachment?")) { 
				$("#" + $(this).attr("data-attachment")).val(''); 
				$("#" + $(this).attr("data-attachment") + "_button").text('Select a File...'); 
				$(this).hide(); 
			}
		});
		
		//$("body").on("click", "#scheduled_mailing", function(event) {}); 
		
		$("body").on("submit", "#mass_mailing", function(event) {
			event.preventDefault();
		});
		
		if ($("#send_email_screen").length || $("#send_url_email").length) {
			if($("#draft_enabled").val() == 1){ 
				auto_save_as_draft();
			}
			else { 
			}
			
			$("body").on("click", ".start_a_schedule", function(event) {
				
				$('#popup_schedule_datetime').datetimepicker(
					{
						minDate: 0,
						minTime: 0,  
						inline:true, 
						format:'Y-m-d H:i:s'
					}
				);
				
				$.colorbox(
					{
						top: 0,
						fixed: true,
						initialHeight: 50,
						maxHeight: 480,
						maxWidth: 849,
						width: 700,
						opacity: 0.50,
						inline:true,
						href:"#start_a_schedule"
					}
				);
			}); 
			$("body").on("click", "#cancel_create_schedule", function(event) {
				$('#popup_schedule_activated').prop('checked', false);
				$("#popup_schedule_datetime").val('');
				$.colorbox.close();
			}); 
			$("body").on("click", "#create_schedule", function(event) {
				
				$("#schedule_datetime").val(
					$("#popup_schedule_datetime").val()
				);
				if($('#popup_schedule_activated').prop('checked') === true){ 
					$('#schedule_activated').val(1); // It's not a checkbox, it's a hidden field. 
				}
				$("#button_action_notice").html('Working...');
				$("#draft_role").val('schedule');
				var ds = save_draft(false); 
				admin_menu_drafts_notification();
				$("#button_action_notice").html('&nbsp;');	
				if(ds === true) { 
					window.location.replace($("#s_program_url").val() + '?f=' + $("#f").val() + '&draft_id=' + $("#draft_id").val() + '&restore_from_draft=true&draft_role=schedule&done=1');
				}
				else { 
					alert("Error Saving Schedule."); 
				}
				
			}); 
			
			
			
			$("body").on("click", ".savedraft", function(event) {
				$("#button_action_notice").html('Working...');
				var role = $(this).attr("data-role");
				$("#draft_role").val(role);
				var ds = save_draft(false); 
				admin_menu_drafts_notification();
				if($("#draft_role").val() == 'draft') { 
					if($("#save_draft_button").val() == 'Save as: Draft') { 
						$("#save_draft_button").val('Save Draft')
					}
				}
				$("#button_action_notice").html('&nbsp;');	
				if(ds === true) { 
					if($("#draft_role").val() == 'draft') {
						$.colorbox({
							top: 0,
							fixed: true,
							initialHeight: 50,
							maxHeight: 480,
							maxWidth: 849,
							width: 700,
							opacity: 0.50,
							href: $("#s_program_url").val(),
							data: {
								flavor: 'draft_saved_notification',
								'screen': $("#f").val(),
								role: role
							}
						});
					}
					else if($("#draft_role").val() == 'stationary') {
						window.location.replace($("#s_program_url").val() + '?f=' + $("#f").val() + '&draft_id=' + $("#draft_id").val() + '&restore_from_draft=true&draft_role=stationary&done=1');
					}
				}
				else if(ds === false) { 
					//alert('Error Saving Draft: '); 
				}
			});
			
			$("body").on("click", ".create_from_stationary", function(event) {
				$("#button_action_notice").html('Working...');
				var role = $(this).attr("data-role");
				$("#draft_role").val(role); // should be, "stationary", but... 
				var ds = save_draft(false); 
				if(ds === true) { 
					create_from_stationary(); 
				}
				else if(ds === false) { 
					//alert('Error Saving Draft: '); 
				}
			}); 
		}
			
			
		$("body").on("click", ".sendmassmailing", function(event) {
			
			$("#button_action_notice").html('Working...');
			
			//var fid = $(event.target).closest('form').attr('id'); 
			var fid = 'mass_mailing';

			if ($("#using_ckeditor").length) {
				if(CKEDITOR.instances['html_message_body']) { 
					CKEDITOR.instances['html_message_body'].updateElement();
				}
			}
			else if($("#using_tinymce").length) { 
				if($("#html_message_body_ifr").length) { 
					tinyMCE.triggerSave();
				}
			}
			
			var itsatest = $(this).hasClass("justatest");
			if (sendMailingListMessage(fid, itsatest) === true) {
				if($("#f").val() != 'list_invite') { 
					if($("#draft_enabled").val() == 1){ 
						save_draft(false);
						admin_menu_drafts_notification();
					}
					else { 
				
					}
				}
				if($("#f").val() == 'list_invite' && itsatest == true) { 
					// alert('now were sending out a test message!');
					var request = $.ajax({
						url: $("#s_program_url").val(),
						type: "POST",
						dataType: "html",
						cache: false,
						data: $("#mass_mailing").serialize() + '&process=Send%20Test%20Invitation',
						success: function(content) {
							alert("List Invitation Test Sent"); 
						},
						error: function(xhr, ajaxOptions, thrownError) {
							alert('Error Sending List Invitation Test: ' + thrownError); 
							console.log('status: ' + xhr.status);
							console.log('thrownError:' + thrownError);
						}, 
					});	
				}
				else { 					
					$("body").off('submit', '#' + fid);
					return true;
				}
			}
		});
		
		$("body").on("click", ".schedulemassmailing", function(event) {
			alert('schedulemassmailing'); 
/*
			$("#button_action_notice").html('Working...');
			$("#draft_role").val('schedule');
			save_draft(false);
			window.location.replace($("#s_program_url").val() + '?f=' + $("#f").val() + '&draft_id=' + $("#draft_id").val() + '&restore_from_draft=true&draft_role=schedule&done=1');
*/
		}); 
		
		$("body").on("click", ".ChangeMassMailingButtonLabel", function(event) {
			ChangeMassMailingButtonLabel();
		});

		ChangeMassMailingButtonLabel();
		$("#tabs").tabs({ heightStyle: "auto" });
		$("#tabs_mass_mailing_options").tabs({ heightStyle: "auto" });

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

		$("body").on("click", ".cancel_message", function(event) {
			$("#button_action_notice").html('Working...');
			save_draft(false)
			
			var confirm_msg = '';
			if($("#draft_role").val() == 'stationary') {
				confirm_msg = "Delete Stationary Message?";
			}
			else if($("#draft_role").val() == 'schedule') {
				confirm_msg = "Remove Schedule?";
			}	
			else {
				confirm_msg = "Delete Draft Message?";
			}
			if (confirm(confirm_msg)) {
				window.location.replace($("#s_program_url").val() + '?f=delete_draft&id=' + $("#draft_id").val());
			 }
			else { 
				$("#button_action_notice").html('&nbsp;');
				
			}
		}); 
		
		$("body").on("click", "#keep_working_on_draft", function(event) {
			$.colorbox.close(); 
		}); 
		$("body").on("click", "#create_a_new_mass_mailing", function(event) {
		 	window.location.replace($("#s_program_url").val() + '?f=' + $("#f").val() + '&restore_from_draft=false');
		}); 
		$("body").on("click", "#show_all_drafts", function(event) {
		 	window.location.replace($("#s_program_url").val() + '?f=drafts');
		}); 
	}

	if ($("#drafts_screen").length) {
		
		$("#tabs").tabs({ heightStyle: "auto" });
		
		$("body").on("click", ".restore_from_draft_link", function(event) {
			event.preventDefault();
			$("#" + $(this).attr("data-target")).submit();
		}); 
		
		$("body").on("submit", ".delete_draft_form", function(event) {
			if (confirm('Delete ' + $(this).attr('data-draft_role') + '?')) {
				return true; 
			}
			else { 
				return false;
			}
		}); 
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
			if (killMonitoredSending() === true) {
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
			if (pauseMonitoredSending() === true) {
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
		
	//	$("body").on("submit", "#mass_update_profiles", function(event) {
			//event.preventDefault();
			// fill that all in,  
			//alert($("#mass_update_advanced_query").val()); 
	//	});
		
		$("body").on("click", ".show_update_profile_form", function(event) {
			show_update_profile_form();
		});	
		
		
	}

	// Membership >> List Activity
	if ($("#list_activity").length) {
		google.setOnLoadCallback(sub_unsub_trend_chart());
	}
	// Membership >> user@example.com
	
	if($("#membership").length) {

		$("#tabs").tabs(); //{ heightStyle: "auto" }
		
		if ($("#mailing_list_history").length) {
			mailing_list_history();
			$(".radio_toggle_membership_history").live("click", function(event) {
				mailing_list_history();
			}); 		
		}

		if($("#membership_activity").length) {
			membership_activity();
		}
		
		$("body").on("submit", "#add_email_form", function(event) {
			event.preventDefault();
		});
		$("submit", "#add_email_form").bind("keypress", function (e) {
		    if (e.keyCode == 13) {
		        return false;
		    }
		});
		$("body").on("click", "#validate_add_email", function(event) {
			validate_add_email();
		});
	
		$("body").on("submit", "#update_email_form", function(event) {
			event.preventDefault();
		});
		$("submit", "#update_email_form").bind("keypress", function (e) {
		    if (e.keyCode == 13) {
		        return false;
		    }
		});

		$("body").on("submit", "#remove_email_form", function(event) {
			event.preventDefault();
		});
		$("body").on("click", "#validate_remove_email", function(event) {
			validate_remove_email();
		});
		$("body").on("click", "#validate_remove_email_multiple_lists", function(event) {
			validate_remove_email(1);
		});
		
		twiddle_validate_multiple_lists_button('validate_update_email_for_multiple_lists');
		twiddle_validate_multiple_lists_button('validate_remove_email_multiple_lists');
		
		$("body").on("click", "#validate_update_email", function(event) {
			validate_update_email();
		});	
		$("body").on("click", "#validate_update_email_for_multiple_lists", function(event) {
			validate_update_email(1);
		});	
		
		if($("#bouncing_address_information").length) {
			membership_bouncing_address_information(); 
		}

		
	}

	// Membership >> Invite/Add
	if ($("#add").length) {
		$("#show_progress").hide();
		$("#fileupload").live("submit", function(event) {
			check_status();
		});
		
	 	$("#new_emails").linedtextarea();
	}


	// Membership >> Add (step 2) 
	if ($("#add_email").length) {
		$("body").on("submit", "#confirm_add", function(event) {
			event.preventDefault();
		});
		
		$("body").on("click", ".check_all_in_div", function(event) {
			if($(this).prop("checked") === true){ 
				$("#" + $(this).attr("data-target") + " input:checkbox").prop("checked",true);
			}
			else { 
				$("#" + $(this).attr("data-target") + " input:checkbox").prop("checked",false);
			}
		}); 
		
		$("body").on("click", ".addingemail", function(event) {
			if ($(this).hasClass("warnAboutMassSubscription")) {
				if (warnAboutMassSubscription() === true) {
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
			admin_menu_notification('admin_menu_sending_preferences_notification', 'admin_menu_sending_preferences');	
		});

		$("body").on("click", ".amazon_verify_email", function(event) {
			event.preventDefault();
			amazon_verify_email($("#amazon_ses_verify_email").val());
		});
	}
	
	if ($("#view_archive").length) {
		
		$("body").on("click", ".purge_archives", function(event) {		
			var confirm_msg = "Are you sure you want to purge all your mailing list archives?";
			if (!confirm(confirm_msg)) {
				alert("Archives not purged.");
				return false;
			} else {
				return true;
			}
		}); 
	}; 
	
	
	// Your Mailing List >> Options 
	
	if ($("#list_options").length) {
		toggle_anyone_can_subscribe(); 
		toggle_closed_list(); 
		toggle_private_list(); 
		
		$('#anyone_can_subscribe').live('click', function(event) {
			toggle_anyone_can_subscribe(); 
		});
		
		$('#closed_list').live('click', function(event) {
			toggle_closed_list(); 
		});	


		$('#private_list_no').live('click', function(event) {
			toggle_private_list(); 
		});	
		$('#private_list').live('click', function(event) {
			toggle_private_list(); 
		});	
			
	}
	
	function toggle_anyone_can_subscribe() { 
		if ($("#anyone_can_subscribe").prop("checked") === true) {
			if($("#anyone_can_subscribe_options").is(':hidden')) {
				$("#anyone_can_subscribe_options").show('blind'); 
			}
			if($("#not_anyone_can_subscribe_options").is(':visible')) {
				$("#not_anyone_can_subscribe_options").hide('blind'); 
			}			
		}
		else { 
			if($("#anyone_can_subscribe_options").is(':visible')) {
				$("#anyone_can_subscribe_options").hide('blind'); 
			}
			if($("#not_anyone_can_subscribe_options").is(':hidden')) {
				$("#not_anyone_can_subscribe_options").show('blind'); 
			}
		
		}
	}
	
	function toggle_closed_list() { 
		if ($("#closed_list").prop("checked") === true) {
			if($("#closed_list_notice").is(':hidden')) {
				$("#closed_list_notice").show('blind'); 
			}
			if($("#opened_list_options").is(':visible')) {
				$("#opened_list_options").hide('blind'); 
			}			
		}
		else { 
			if($("#closed_list_notice").is(':visible')) {
				$("#closed_list_notice").hide('blind'); 
			}
			if($("#opened_list_options").is(':hidden')) {
				$("#opened_list_options").show('blind'); 
			}
		
		}
	}
	
	function toggle_private_list() { 
		if ($("#private_list").prop("checked") === true) {
			if($("#private_list_notice").is(':hidden')) {
				$("#private_list_notice").show('blind'); 
			}
		}
		else { 
			if($("#private_list_notice").is(':visible')) {
				$("#private_list_notice").hide('blind'); 
			}
		}
		
	}
	
	
	
	if ($("#change_password").length) {
		$("#change_password_form").validate({
			debug: false,
			rules: {
				new_password: {
					required: true,
					minlength: 4
				},
				again_new_password: {
					required: true,
					minlength: 4,
					equalTo: "#new_password"
				},
			}
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
	
	if ($("#html_code").length) {
		$("#tabs").tabs({ heightStyle: "auto" });
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
	$(".show_advanced_search_list").live("click", function(event) {
		//alert('Calling show_advanced_search_list()');  
		show_advanced_search_list();
		event.preventDefault();
	});
	$(".advanced_search_list").live("click", function(event) {
		advanced_search_list();
		event.preventDefault();
	});


	$(".close_advanced_search_list").live("click", function(event) {
		close_advanced_search_list();
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
	$(".clear_advanced_search_list").live("click", function(event) {
		clear_advanced_search();
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
								value: item.email
							}
						}));
					},
					error: function() {
						console.log('something is wrong with, "search_list_auto_complete"');
					}
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
	
	if($("#membership_profile_fields").length) { 
		$("#membership_profile_fields").validate();
	}
	$(".change_profile_password").live("click", function(event) {
		show_change_profile_password_form();
		event.preventDefault();
	});
	$(".cancel_change_profile_password").live("click", function(event) {
		cancel_change_profile_password();
		event.preventDefault();
	});

	// Mail Sending >> Mass Mailing Options 
	$(".previewBatchSendingSpeed").live("change", function(event) {
		previewBatchSendingSpeed();
	});

	$("#amazon_ses_auto_batch_settings").live("click", function(event) {
		toggleManualBatchSettings();
	});

	if($("#profile_fields").length) { 
		
		var no_weird_characters_regex = /[^a-z0-9_]/; 
		jQuery.validator.addMethod("no_weird_characters", function(value, element) {
	    return this.optional(element) || !(no_weird_characters_regex.test(value));
	    }, "Value can only contain lowercase alpha-numeric characters, and underscores");
		
		$("#add_edit_field").validate({
			debug: false,
			rules: {
				field: {
					required: true,
					no_weird_characters: true,
					maxlength: 64
				}
			}
		});
		
	}
	
	// Version Check 
	$('#check_version').live('click', function(event) {
		event.preventDefault();
		check_newest_version($('#check_version').attr("data-ver"));
	});


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
	
	// Plugins >> Beatitude 
	if ($("#plugins_beatitude_schedule_form").length) {
		datetimesetupstuff();
	}

	// Plugins >> Bridge
	if ($("#plugins_bridge_default").length) {

		$("body").on("click", ".plugins_bridge_test_pop3", function(event) {
			event.preventDefault();
			plugins_bridge_test_pop3();
		});

		$(".change_pop3_password").live("click", function(event) {
			plugins_bridge_show_change_pop3_password_form();
			event.preventDefault();
		});
		$(".cancel_change_pop3_password").live("click", function(event) {
			plugins_bridge_hide_change_pop3_password_form();
			event.preventDefault();
		});

		
		
		
		



		$("body").on("click", '.plugins_bridge_manually_check_messages', function(event) {
			event.preventDefault();
			plugins_bridge_manually_check_messages();
			admin_menu_notification('admin_menu_mailing_monitor_notification', 'admin_menu_sending_monitor');
		});

		$("body").on("click", '.bridge_settings', function(event) {
			bridge_setup_list_email_type_params();
		});
		
		
		$("body").on("click", ".view_authorized_senders", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?f=view_list&type=authorized_senders';
		});
		$("body").on("click", ".add_authorized_senders", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?f=add&type=authorized_senders';
		});
		$("body").on("click", ".view_moderators", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?f=view_list&type=moderators';
		});
		$("body").on("click", ".add_moderators", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?f=add&type=moderators';
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
				opacity: 0.50,
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
		tracker_toggle_tracker_track_email_options(); 
	
		message_history_html();
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
		
		$("body").on("click", '#tracker_track_email', function(event) {
			tracker_toggle_tracker_track_email_options();
		});
		
		
		var field_name_group_selected = [];
		$('div#field_name_group input[type=checkbox]').each(function() {
		   if ($(this).prop("checked") === true) {
				if ($('#' + dt).is(':hidden')) {
					$('#' + dt).show('fade');
				}
		   }
		   else {
				var dt = $(this).attr("data-target");
				if ($('#' + dt).is(':visible')) {
					$('#' + dt).hide('fade');
				}
		   }
		});
		
		$("body").on("click", '.field_checkbox', function(event) {
			var dt = $(this).attr("data-target");
			if($(this).prop("checked") === true){ 
				if ($('#' + dt).is(':hidden')) {
					$('#' + dt).show('fade');
				}
			}
			else { 
				if ($('#' + dt).is(':visible')) {
					$('#' + dt).hide('fade');
				}
			}
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
	
	$(".clear_field").live("click", function(event) {
		event.preventDefault();
		$("#" + $(this).attr("data-target")).val(''); 
	});

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
	
	$("body").on("click", ".amazon_verify_email_in_warning", function(event) {
		event.preventDefault();
		amazon_verify_email($(this).attr("data-email"));
	});

});


// Admin Menu 


function admin_menu_drafts_notification() { 
	admin_menu_notification('admin_menu_drafts_notification', 'admin_menu_drafts');
}
function admin_menu_sending_monitor_notification() {
	/* console.log('admin_menu_sending_monitor_notification'); */
	admin_menu_notification('admin_menu_mailing_monitor_notification', 'admin_menu_sending_monitor');
}

function admin_menu_subscriber_count_notification() {
	/* console.log('admin_menu_subscriber_count_notification');  */
	admin_menu_notification('admin_menu_subscriber_count_notification', 'admin_menu_view_list');
}
function admin_menu_archive_count_notification() { 
	/* console.log('admin_menu_archive_count_notification'); */
	admin_menu_notification('admin_menu_archive_count_notification', 'admin_menu_view_archive');	
}

function admin_menu_sending_preferences_notification() { 
	admin_menu_notification('admin_menu_sending_preferences_notification', 'admin_menu_sending_preferences');	
}

function admin_menu_bounce_handler_notification() { 
	admin_menu_notification('admin_menu_bounce_handler_notification', 'admin_menu_bounce_handler');	
}


function admin_menu_notification(flavor, target_class) {
	var r = 60 * 5 * 1000; // Every 5 minutes. 
	var refresh_loop = function(no_loop) {
			var request = $.ajax({
				url: $('#navcontainer').attr("data-s_program_url"),
				type: "POST",
				cache: false,
				data: {
					f: flavor
				},
				dataType: "html"
			});
			request.done(function(content) {
				if ($('.' + target_class + '_notification').length) {
					$('.' + target_class + '_notification').remove();
				}
				//console.log('update! ' + target_class); 
				$('#' + target_class).append('<span class="' + target_class + '_notification"> ' + content + '</span>');
			});
			if (no_loop != 1) {
				setTimeout(
				refresh_loop, r);
			}
		}
	setTimeout(refresh_loop, r);
	refresh_loop(1);
}

// Mass Mailing >> Send a Message 

function setup_attachment_fields() { 
	var a_nums = [1,2,3,4,5];
	for (var i = 0; i < a_nums.length; i++) {	
		if($("#attachment" + a_nums[i]).length) { 
			if($("#attachment" + a_nums[i]).val() != ""){ 
		
				$("#attachment" + a_nums[i] + "_button").html('<img src="' + $("#SUPPORT_FILES_URL").val() + '/static/images/attachment_icon.gif" />' + $("#attachment" + a_nums[i]).val());
	        }
			else { 
				$("#attachment" + a_nums[i] + "_remove_button").hide(); 					
			}
		}
	}	
}
function save_draft(async) { 
	
	var r = false; 
	
    /* alert($("#mass_mailing").serialize() + '&process=save_as_draft'); */


	if ($("#using_ckeditor").length) {
		if(CKEDITOR.instances['html_message_body']) { 
			CKEDITOR.instances['html_message_body'].updateElement();
		}
	}
	else if($("#using_tinymce").length) { 
		if($("#html_message_body_ifr").length) { 
			tinyMCE.triggerSave();
		}
	}
	var request = $.ajax({
		url:       $("#s_program_url").val(),
		type:      "POST",
		dataType: "json",
		cache:     false,
		async:     async,
		data: $("#mass_mailing").serialize() + '&process=save_as_draft',
		success: function(content) {
			//alert('content.id ' + content.id); 
			$("#draft_id").val(content.id); 
			$('#draft_notice .alert').text($("#draft_role").val() + ' saved: ' + new Date().format("yyyy-MM-dd h:mm:ss")); 
			r = true; 
		},
		error: function(xhr, ajaxOptions, thrownError) {
			alert('Error Saving ' + $("#draft_role").val() + ': ' + thrownError); 
			console.log('status: ' + xhr.status);
			console.log('thrownError:' + thrownError);
			r = false; 
		}, 
	});
	return r; 
}

function create_from_stationary() { 
	window.location.replace($("#s_program_url").val() + '?f=create_from_stationary&draft_id=' + $("#draft_id").val() + '&screen=' + $("#f").val());
}

function auto_save_as_draft() {
	if($("#draft_enabled").val() === 0){ 
		return; 
	}
	
	if ($("#using_ckeditor").length) {
		if(CKEDITOR.instances['html_message_body']) { 
			CKEDITOR.instances['html_message_body'].updateElement();
		}
	}
	else if($("#using_tinymce").length) {
		if($("#html_message_body_ifr").length) { 
			tinyMCE.triggerSave();
		}
	}
	
	var r = 60 * 1000; // Every 1 minute. 
	var refresh_loop = function(no_loop) {
		$('#draft_notice .alert').text('auto-saving...'); 
		var request = $.ajax({
			url: $("#s_program_url").val(),
			type: "POST",
			dataType: "json",
			cache: false,
			data: $("#mass_mailing").serialize() + '&process=save_as_draft',
			success: function(content) {
				$('#draft_notice .alert').text('Last auto-save: ' + new Date().format("yyyy-MM-dd h:mm:ss"));
				$("#draft_id").val(content.id);
				admin_menu_drafts_notification();
			},
			error: function(xhr, ajaxOptions, thrownError) {
				$('#draft_notice .alert').text('Problems auto-saving!'  + new Date().format("yyyy-MM-dd h:mm:ss"));
				console.log('status: ' + xhr.status);
				console.log('thrownError:' + thrownError);
			}
		});
			if (no_loop != 1) {
				setTimeout(
				refresh_loop, r);
			}
		}
	setTimeout(refresh_loop, r);
	//refresh_loop(1);
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

			if (keep_updating_status_bar === 0) {
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
	//alert('$("#advanced_search").val() ' + $("#advanced_search").val()); 
	//alert(' $("#advanced_query").val() ' +  $("#advanced_query").val()); 
	
	//$("#view_list_viewport_loading").html('<p class="alert">Loading...</p>');
	$("#view_list_viewport").plainOverlay('show', plainOverlayOptions);
	
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
			advanced_search: $("#advanced_search").val(),
			advanced_query: $("#advanced_query").val(),
			order_by: $("#order_by").val(),
			order_dir: $("#order_dir").val()
		},
		dataType: "html"
	});
	request.done(function(content) {

		if (initial == 1) {
			$("#view_list_viewport").hide()
			$("#view_list_viewport").plainOverlay('hide')
			$("#view_list_viewport").html(content);
			
			
			if($("#advanced_search").val() == 1){ 
				console.log('not hiding advanced search form'); 
			}
			else {
				console.log('Hiding advanced search form');
				$("#advanced_list_search").hide(); 
			}
			
			$("#view_list_viewport").show('fade');
		} else {
			
			$("#view_list_viewport").html(content);
			if($("#advanced_search").val() != 1){
				$("#advanced_list_search").hide(); 
			}
			$("#view_list_viewport").plainOverlay('hide')
			
		}

		//$("#view_list_viewport_loading").html('<p class="alert">&nbsp;</p>');
		
		datetimesetupstuff(); 
		set_up_advanced_search_form(); 
			
		console.log('#advanced_search ' + $("#advanced_search").val()) ; 
		
		if($("#advanced_search").val() == 1){ // === is not working, here. 
			$("#domain_break_down").hide(); 
		}
		else { 
			$("#domain_break_down").show(); 
			google.setOnLoadCallback(drawTrackerDomainBreakdownChart());
		}
	}); 

}

function set_up_advanced_search_form() { 
	
	console.log('set_up_advanced_search_form ' ); 
	console.log('advanced_query looks like: ' + $("#advanced_query").val());
	console.log('advanced_query length' + $("#advanced_query").length); 
	
	var q = $("#advanced_query").val(); 
	
	if($("#advanced_search").val() === 1 || q.length > 0) { 
		console.log("Unserializing, and filling out form:"); 
		$("#advanced_list_search_form").unserialize($("#advanced_query").val());
		
	 }
	 else { 
	console.log("No advanced search form."); 	
	}
}

function show_update_profile_form(){ 
	
	var $form = $("#mass_updates");
	
	$.colorbox({
		inline:true, 
		href:$form,
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		
		onComplete: function(){
			//alert("fill it in!" + $("#advanced_query").val()); 
			$("#mass_update_advanced_query").val($("#advanced_query").val());
		}	
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

function show_advanced_search_list(){ 
//	alert('show_advanced_search_list called.'); 
	
	$("#domain_break_down").hide('blind'); 
	$("#advanced_search").val(1); 
	$("#advanced_list_search").show('blind'); 
} 

function advanced_search_list(){ 
	//alert($("#advanced_list_search_form").serialize())
	$("#page").val(1);	
	$("#advanced_search").val(1); 
	$("#advanced_query").val($("#advanced_list_search_form").serialize());
	view_list_viewport();
}
function close_advanced_search_list(){ 

	$("#advanced_list_search").hide('blind'); 

	$("#page").val(1);	
	$("#advanced_search").val(0); 
	$("#advanced_query").val('');
	view_list_viewport(1);
}

function clear_search() {
	$("#query").val('');
	$("#page").val(1);
	view_list_viewport();
}
function clear_advanced_search() { 
	$("#advanced_query").val('');
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
			type: $("#type").val()
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
		}
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
		search_list();
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
			easing: 'out'
		}
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
			}
		});
	}

	draw_sub_unsub_trend_chart();
}



// Membership >> user@example.com

function mailing_list_history() {
	$("#mailing_list_history_loading").html('<p class="alert">Loading...</p>');

	var scope = 'this_list';
	if($("#toggle_membership_history").length){ 
		if ($("#membership_history_all_lists").prop("checked") === true) {
			scope = $("#membership_history_all_lists").val();
			//alert("SCOPE: " + scope); 
		} else if ($("#membership_history_this_list").prop("checked") === true) {	
			scope = $("#membership_history_this_list").val();
		}
	}
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'mailing_list_history',
			email: $("#email").val(),
			membership_history: scope
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#mailing_list_history").hide().html(content).show('fade');

		$("#mailing_list_history_loading").html('<p class="alert">&nbsp;</p>');
	});
}

function membership_activity() { 
	$("#membership_activity_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'membership_activity',
			email: $("#email").val(),
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#membership_activity").hide().html(content).show('fade');

		$("#membership_activity_loading").html('<p class="alert">&nbsp;</p>');
	});
	
}


function twiddle_validate_multiple_lists_button(button_id) { 
	if($('#' + button_id).length < 1) { 
		return; 
	}
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "GET",
		data: {
			f: 'also_member_of',
			email: $("#email").val(),
			type:  $("#type_remove option:selected").val()
		},
		dataType: "json",
		success: function(data) {
			if(data.also_member_of == 1){ 
				 //alert("showing..."); 
				if ($('#' + button_id).hasClass('disabled')) {
					$('#' + button_id).removeClass('disabled');
				}
				if($('#' + button_id).prop('disabled',true)) { 
					$('#' + button_id).prop('disabled',false)
				}				
			}
			else { 
				 //alert("hiding..."); 
				if ($('#' + button_id).hasClass('disabled')) {
					/* ... */
				}
				else { 
					$('#' + button_id).addClass('disabled');
				}
				if($('#' + button_id).prop('disabled',false)) { 
					$('#' + button_id).prop('disabled',true)
				}
				
			}
		},
		error: function(xhr, ajaxOptions, thrownError) {
			console.log('status: ' + xhr.status);
			console.log('thrownError:' + thrownError);
			return undef; 
		}
	});
	
}

function validate_add_email() { 
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			f:              'add',
			chrome:         0, 
			email:          $("#add_email").val(),
			type:           $("#type_add").val(),
			process:        $("#add_process").val(),  
			rand_string:    $("#add_rand_string").val(), 
			method:         $("#add_method").val(), 
			return_to:      $("#add_return_to").val(), 
			return_address: $("#add_return_address").val(), 
		}
	});
}

function validate_update_email(is_for_all_lists) {		
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			f: 'validate_update_email',
			updated_email: $("#updated_email").val(),
			email:         $("#original_email").val(),
			for_all_lists: is_for_all_lists	
		}
	});
}

function validate_remove_email(for_multiple_lists) { 
	
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			f:                  'validate_remove_email',
			email:              $("#email").val(),
			type:               $("#type_remove option:selected").val(),
			for_multiple_lists: for_multiple_lists	
		}
	});
	
}

function membership_bouncing_address_information() { 
	
	$("#membership_bouncing_address_information").hide().html('<p class="alert">Loading...</p>').show('fade');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			f:               'view_bounce_history',
			email:           $("#email").val(),
			return_to:       'membership',
			return_address:  $("#email").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#membership_bouncing_address_information").hide("fade", function() {
			$("#membership_bouncing_address_information").html(content);
			$("#membership_bouncing_address_information_loading").html('');
			$("#membership_bouncing_address_information").show('fade');
		});
	});



	
}

function show_change_profile_password_form() {
	$("#change_profile_password_button").hide('blind');
	$("#change_profile_password_form").show('blind');
}
function cancel_change_profile_password() {
	$("#change_profile_password_form").hide('blind');
	$("#change_profile_password_button").show('blind');
}


// Membership >> Invite 

function show_customize_invite_message() {
	$('#customize_invite_message_button').hide('blind');
	$('#customize_invite_message_form').show('blind');
}

// Mail Sending >> Sending Options

function sending_prefs_setup() {

	var hidden = [];
	var visible = [];

	if ($("#sending_method_sendmail").prop("checked") === true) {
		hidden = ['smtp_preferences', 'amazon_ses_preferences'];
		visible = ['sendmail_options'];
	}
	if ($("#sending_method_smtp").prop("checked") === true) {
		hidden = ['sendmail_options', 'amazon_ses_preferences'];
		visible = ['smtp_preferences'];
	}
	if ($("#sending_method_amazon_ses").prop("checked") === true) {
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
	if ($("#use_sasl_smtp_auth").prop("checked") === true) {
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
	if ($("#use_pop_before_smtp").prop("checked") === true) {
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
	if ($('#set_smtp_sender').prop('checked') === true) {
		set_smtp_sender = 1;
	}
	var pop3_use_ssl = 0; 
	if ($('#pop3_use_ssl').prop('checked') === true) {
		pop3_use_ssl = 1;
	}
	var use_pop_before_smtp = 0; 
	if ($('#use_pop_before_smtp').prop('checked') === true) {
		use_pop_before_smtp = 1;
	}	
	var use_sasl_smtp_auth = 0; 
	if ($('#use_sasl_smtp_auth').prop('checked') === true) {
		use_sasl_smtp_auth = 1;
	}	
	var use_smtp_ssl = 0; 
	if ($('#use_smtp_ssl').prop('checked') === true) {
		use_smtp_ssl = 1;
	}
	var add_sendmail_f_flag = 0; 
	if ($('#add_sendmail_f_flag').prop('checked') === true) {
		add_sendmail_f_flag = 1;
	}	
	
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
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





function amazon_verify_email(email) {
	
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			f: 'amazon_ses_verify_email',
			amazon_ses_verify_email: email
		}
	});
	
}


// Mail Sending >> Mass Mailing Options 

function previewBatchSendingSpeed() {
	$("#previewBatchSendingSpeed_loading").hide().html('<p class="alert">Loading...</p>').show('fade');


	var enable_bulk_batching = 0;
	if ($('#enable_bulk_batching').prop('checked') === true) {
		enable_bulk_batching = 1;
	}
	var amazon_ses_auto_batch_settings = 0;
	if ($("#amazon_ses_get_stats").length) {
		if ($('#amazon_ses_auto_batch_settings').prop('checked') === true) {
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
			f: 'amazon_ses_get_stats'
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
	if ($("#amazon_ses_auto_batch_settings").prop("checked") === true) {
		$("#manual_batch_settings").hide('fade');
	} else {
		if ($('#manual_batch_settings').is(":hidden")) {
			$("#manual_batch_settings").show('fade');
		}
	}
	previewBatchSendingSpeed();
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
			page: $('#bounce_handler_page').val()
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
	if($("#test").prop("checked") === true) { 
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
	if($("#test").prop("checked") === true) { 
		isa_test = 'bounces';
	}
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		href: $("#plugin_url").val(),
		data: {
			flavor: 'ajax_parse_bounces_results',
			parse_amount: $('#parse_amount').val(),
			test:         isa_test
		},
		onComplete:function(){
			bounce_handler_show_scorecard();
		}
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
			msg: $('#msg').val()
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
	if ($("#mail_forward_pipe").prop("checked") === true) {
		if ($('#bridge_mail_forward_pipe_params').is(':hidden')) {
			$('#bridge_mail_forward_pipe_params').show('blind');
		}
		if ($('#bridge_pop3_account_params').is(':visible')) {
			$('#bridge_pop3_account_params').hide('blind');
		}
	}
	if ($("#pop3_account").prop("checked") === true) {
		if ($('#bridge_pop3_account_params').is(':hidden')) {
			$('#bridge_pop3_account_params').show('blind');
		}
		if ($('#bridge_mail_forward_pipe_params').is(':visible')) {
			$('#bridge_mail_forward_pipe_params').hide('blind');
		}
	}
	
	if ($("#group_list_no").prop("checked") === true) {
		if ($('#announce_list_params').is(':hidden')) {
			$('#announce_list_params').show('blind');
		}
		if ($('#discussion_list_params').is(':visible')) {
			$('#discussion_list_params').hide('blind');
		}
	}
	if ($("#group_list_yes").prop("checked") === true) {
		if ($('#announce_list_params').is(':visible')) {
			$('#announce_list_params').hide('blind');
		}
		if ($('#discussion_list_params').is(':hidden')) {
			$('#discussion_list_params').show('blind');
		}
	}
	if ($("#enable_moderation").prop("checked") === true) {
		if ($('#moderaton_params').is(':hidden')) {
			$('#moderaton_params').show('blind');
		}
 	}
	else if ($('#enable_moderation').prop("checked") !== true) {
		if ($('#moderaton_params').is(':visible')) {
			$('#moderaton_params').hide('blind');
		}
	}


}

function plugins_bridge_test_pop3() {
	
	var use_ssl = 0;
	if($("#discussion_pop_use_ssl").prop("checked") === true){ 
		use_ssl = 1; 
	}
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 649,
		opacity: 0.50,
		href: $("#plugin_url").val(),
		data: {
			flavor: 'cgi_test_pop3_ajax',
			server: $("#discussion_pop_server").val(),
			username: $("#discussion_pop_username").val(),
			password: $("#discussion_pop_password").val(),
			auth_mode: $("#discussion_pop_auth_mode option:selected").val(),
			use_ssl: use_ssl
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
		opacity: 0.50,
		href: $("#plugin_url").val(),
		data: {
			flavor: 'admin_cgi_manual_start_ajax'
		}
	});
}

function plugins_bridge_show_change_pop3_password_form() {
	$("#change_pop3_password_button").hide('blind');
	$("#change_pop3_password_field").show('blind');
}

function plugins_bridge_hide_change_pop3_password_form() {
	$("#discussion_pop_password").val('');
	$("#change_pop3_password_field").hide('blind');
	$("#change_pop3_password_button").show('blind');
	
}




// Plugins >> Mailing Monitor 

function plugins_mailing_monitor() {
	$("#mailing_monitor_results_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'mailing_monitor_results'
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

	var $tabs = $("#tabs").tabs({ heightStyle: "auto" });

	$('body').on('click', '.to_subscriber_activity', function(event) {
		$tabs.tabs('select', 0); return false;
	});
	$('body').on('click', '.to_opens', function(event) {
		$tabs.tabs('select', 1); return false;
	});
	$('body').on('click', '.to_clickthroughs', function(event) {
		$tabs.tabs('select', 2); return false;
	});
	$('body').on('click', '.to_unsubscribes', function(event) {
		$tabs.tabs('select', 3); return false;
	});
	$('body').on('click', '.to_bounces', function(event) {
		$tabs.tabs('select', 4); return false;
	});
	
	$('body').on('click', '.to_sending_errors', function(event) {
		$tabs.tabs('select', 5); return false;
	});
	
	$('body').on('click', '.to_archive_views', function(event) {
		$tabs.tabs('select', 6); return false;
	});
	$('body').on('click', '.to_forwards', function(event) {
		$tabs.tabs('select', 7); return false;
	});
	$('body').on('click', '.to_abuse_reports', function(event) {
		$tabs.tabs('select', 8); return false;
	});

	$("body").on("click", '.message_individual_email_activity', function(event) {
		event.preventDefault();
		message_individual_email_activity_table($(this).attr("data-email"), "message_individual_email_activity_report_table");
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
	

	var tracker_message_report_callback = $.Callbacks();
	
	if ($("#can_use_country_geoip_data").val() == 1) {

		tracker_message_report_callback.add(tracker_message_email_activity_listing_table('message_email_activity_listing_table'));


		tracker_message_report_callback.add(country_geoip_table('clickthroughs', 'Clickthroughs', 'country_geoip_clickthroughs_table'));
		tracker_message_report_callback.add(country_geoip_table('opens', 'Opens', 'country_geoip_opens_table'));
		tracker_message_report_callback.add(country_geoip_table('view_archive', 'Archive Views', 'country_geoip_view_archive_table'));
		tracker_message_report_callback.add(country_geoip_table('forward_to_a_friend', 'Forwards', 'country_geoip_forwards_table'));


		google.setOnLoadCallback(country_geoip_map('clickthroughs', 'country_geoip_clickthroughs_map'));
		google.setOnLoadCallback(country_geoip_map('opens', 'country_geoip_opens_map'));
		google.setOnLoadCallback(country_geoip_map('view_archive', 'country_geoip_view_archive_map'));
		google.setOnLoadCallback(country_geoip_map('forward_to_a_friend', 'country_geoip_forwards_map'));

	}

	google.setOnLoadCallback(tracker_the_basics_piechart('opens', 'Opens', 'the_basics_opens')); 
	google.setOnLoadCallback(tracker_the_basics_piechart('unsubscribes', 'Unsubscribes', 'the_basics_unsubscribes')); 
	google.setOnLoadCallback(tracker_the_basics_piechart('bounces', 'Bounces', 'the_basics_bounces')); 


	google.setOnLoadCallback(data_over_time_graph('clickthroughs', 'Clickthroughs', 'over_time_clickthroughs_graph'));
	google.setOnLoadCallback(data_over_time_graph('unsubscribes', 'Unsubscribes', 'over_time_unsubscribe_graph'));
	google.setOnLoadCallback(data_over_time_graph('opens', 'Opens', 'over_time_opens_graph'));
	google.setOnLoadCallback(data_over_time_graph('view_archive', 'Archive Views', 'over_time_view_archive_graph'));
	google.setOnLoadCallback(data_over_time_graph('forward_to_a_friend', 'Forwards', 'over_time_forwards_graph'));
	google.setOnLoadCallback(data_over_time_graph('abuse_report', 'Abuse Reports', 'over_time_abuse_report_graph'));


	google.setOnLoadCallback(email_breakdown_chart('unsubscribe', 'Unsubscribes', 'unsubscribe_graph'));
	google.setOnLoadCallback(email_breakdown_chart('soft_bounce', 'Soft Bounces', 'soft_bounce_graph'));
	google.setOnLoadCallback(email_breakdown_chart('hard_bounce', 'Hard Bounces', 'hard_bounce_graph'));
	google.setOnLoadCallback(email_breakdown_chart('errors_sending_to', 'Sending Errors', 'errors_sending_to_graph'));
	google.setOnLoadCallback(email_breakdown_chart('abuse_report', 'Abuse reports', 'abuse_report_graph'));

	tracker_message_report_callback.add(message_email_report_table('unsubscribe',    'unsubscribe_table'));
	tracker_message_report_callback.add(message_email_report_table('soft_bounce',    'soft_bounce_table'));
	tracker_message_report_callback.add(message_email_report_table('hard_bounce',    'hard_bounce_table'));
	tracker_message_report_callback.add(message_email_report_table('errors_sending_to', 'errors_sending_to_table'));

	tracker_message_report_callback.add(message_email_report_table('abuse_report', 'abuse_report_table'));



	tracker_message_report_callback.fire(); 
	
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
			label: label
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
		chart: ''
	},
	opens: {
		type: 'opens',
		data: '',
		chart: ''
	},
	view_archive: {
		type: 'view_archive',
		data: '',
		chart: ''
	},
	forward_to_a_friend: {
		type: 'forward_to_a_friend',
		data: '',
		chart: ''
	}
};

function country_geoip_map(type, target_div) {

	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		data: {
			f: 'country_geoip_json',
			mid: $('#tracker_message_id').val(),
			type: type
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

function message_individual_email_activity_table(email, target_div) { 
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		data: {
			f: 'message_individual_email_activity_report_table',
			mid: $('#tracker_message_id').val(),
			email: email
		},
		dataType: "html",
		async: true,
		success: function(content) {
			$("#" + target_div).hide("fade", function() {
				$("#" + target_div).html(content);
				$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
				$("#" + target_div).show('fade');
			});
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
			label: label
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
		}
	});
}

function message_email_report_table(type, target_div) {

	console.log('type:' + type + ' target_div:' + target_div); 
	
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'message_email_report_table',
			mid: $('#tracker_message_id').val(),
			type: type
		},
		dataType: "html"
	});
	request.done(function(content) {

		$("#" + target_div).hide();
		$("#" + target_div).html(content);
		$("#" + target_div).show('fade');

		$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
		//  $("#sortable_table_" + type).tablesorter(); 
	});
}

function tracker_message_email_activity_listing_table(target_div) { 
	console.log('target_div:' + target_div); 

	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'message_email_activity_listing_table',
			mid: $('#tracker_message_id').val()
		},
		dataType: "html"
	});
	request.done(function(content) {

		$("#" + target_div).hide();
		$("#" + target_div).html(content);
		$("#" + target_div).show('fade');

		$("#" + target_div + "_loading").html('<p class="alert">&nbsp;</p>');
		//$("#sortable_table_" + type).tablesorter();
		if ($('#first_for_message_email_activity_listing_table').length) {
			message_individual_email_activity_table($('#first_for_message_email_activity_listing_table').html(), 'message_individual_email_activity_report_table'); 
		}		


		// alert("This: " + $('#first_for_message_email_activity_listing_table').html()); 
		
	});
}

function email_breakdown_chart(type, label, target_div) {
	
	console.log('type:' + type + ' label: ' + label + ' target_div:' + target_div); 
	
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		dataType: "json",
		data: {
			f: 'email_stats_json',
			mid: $('#tracker_message_id').val(),
			type: type,
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
		}
	});
}

function tracker_the_basics_piechart(type, label, target_div) {
	
	console.log('type:' + type + ' label: ' + label + ' target_div:' + target_div); 
	
	$("#" + target_div + "_loading").html('<p class="alert">Loading...</p>');
	$.ajax({
		url: $("#plugin_url").val(),
		dataType: "json",
		data: {
			f: 'the_basics_piechart_json',
			mid: $('#tracker_message_id').val(),
			type: type,
			label: label
		},
		async: true,
		success: function(jsonData) {
			var data = new google.visualization.DataTable(jsonData);
			var chart = new google.visualization.PieChart(document.getElementById(target_div));
			var options = {
				chartArea: {
					left: 10,
					top: 10,
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
		}
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
	});

}

function tracker_turn_page(page_to_turn_to) {
	$("#tracker_page").val(page_to_turn_to);
	message_history_html();
}

function tracker_parse_links_setup() {
	if ($("#tracker_auto_parse_links").prop("checked") === true) {
		if ($('#tracker_auto_parse_links_info').is(':hidden')) {
			$('#tracker_auto_parse_links_info').show('blind');
		}
		if ($('#tracker_noauto_parse_links_info').is(':visible')) {
			$('#tracker_noauto_parse_links_info').hide('blind');
		}
	}
	if ($("#tracker_noauto_parse_links").prop("checked") === true) {
		if ($('#tracker_noauto_parse_links_info').is(':hidden')) {
			$('#tracker_noauto_parse_links_info').show('blind');
		}
		if ($('#tracker_auto_parse_links_info').is(':visible')) {
			$('#tracker_auto_parse_links_info').hide('blind');
		}
	}
}

function tracker_toggle_tracker_track_email_options() { 
	if ($("#tracker_track_email").prop("checked") === true) {
		if ($('#tracker_track_email_options').is(':hidden')) {
			$('#tracker_track_email_options').show('blind');
		}
	}
	else { 
		if ($('#tracker_track_email_options').is(':visible')) {
			$('#tracker_track_email_options').hide('blind');
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
				log_name: $('#log_name').val()
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

	//console.log('running message_history_html'); 

	$("#show_table_results_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'message_history_html',
			page: $("#tracker_page").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#show_table_results").hide('fade', function() {
			$("#show_table_results").html(content);
			$("#show_table_results").show('fade');
			$("#show_table_results_loading").html('<p class="alert">&nbsp;</p>');
		});
		
		google.setOnLoadCallback(drawSubscriberHistoryChart());  

	});
}

var SubscriberHistoryChart;

function drawSubscriberHistoryChart() {
	
	//console.log('runnning drawSubscriberHistoryChart'); 
	
	$("#subscriber_history_chart_loading").html('<p class="alert">Loading...</p>');
	var request = $.ajax({
		url: $("#plugin_url").val(),
		data: {
			f: 'message_history_json',
			page: $("#tracker_page").val()
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

		}
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
				f: 'ajax_delete_log'
			},
			dataType: "html"
		});
		request.done(function(content) {
			message_history_html();
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

	var al = [];
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
	$('#multi_list_send_no_dupes').val() == 1 && $("#multi_list_send_no_dupes").prop("checked") === true) {
		multi_list_send_no_dupes = 1;
	}

	f_params.f                       = 'preview_message_receivers';
	f_params.alternative_lists       = alternative_lists;
	f_params.multi_list_send_no_dupe = multi_list_send_no_dupes;

	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxHeight: 480,
		maxWidth: 700,
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: f_params
	});

}

function ChangeMassMailingButtonLabel() {
/*	
	if($("#scheduled_mailing").prop("checked")){ 
		// This should work, as you can't set this, while as a stationary. 
		$('#submit_mass_mailing').hide('fade');
		$('#save_draft_button').val('Save Schedule');
		$("#save_draft_button").attr("data-role", 'schedule'); 
	
		$('#save_as_stationary_button').hide('fade');
	}
	else { 
*/		
		$('#submit_mass_mailing').show();
		$('#save_draft_button').show();
		$('#save_as_stationary_button').show();
		
		$('#save_draft_button').val($("#default_save_draft_button_label").val());
		
		
		$("#save_draft_button").attr("data-role", 'draft'); 

		
		if ($("#archive_message").prop("checked") === true && $("#archive_no_send").prop("checked") === true) {
			$("#submit_mass_mailing").prop('value', 'Archive Message');
		} else {
			$("#submit_mass_mailing").prop('value', $("#default_mass_mailing_button_label").val());
		}
/*
	}
*/

}


function sendMailingListMessage(fid, itsatest) { /* This is for the Send a Webpage - did they fill in a URL? */
	if ($("#f").val() == 'send_url_email') {
		if($("#content_from_url").prop("checked") === true) { 
			if (
			$("#url").val() == 'http://' || $("#url").val().length <= 0) {
				alert('Please fill in a valid URL under, "Grab content from this webpage address (URL):" (Mass Mailing Stopped.)');
				return false;
			}
		}
	}

	if ($("#send_email_screen").length) {
		var has_html = 1; 
		var has_text = 1; 
		if($("#html_message_body").val() == ""){ has_html = 0;}
		if($("#text_message_body").val() == ""){ has_text = 0;}
		if(has_html === 0 && has_text === 0){ 
			alert("Please write an HTML and/or PlainText message."); 
			return false;
		} 
	}
	
	if ($("#Subject").val().length <= 0) {
		var no_subject_msg = "The Subject: header of this message has been left blank. Send anyways?";
		if (!confirm(no_subject_msg)) {
			alert('Mass Mailing canceled.');
			return false;
		}
	}
	else if(itsatest === false) { 
		if ($("#archive_no_send").prop("checked") === true) {
			if (!confirm('Archive Message?')) {
				return false;
			}				
		}
		else { 
			if (!confirm('Send Mass Mailing?')) {
				return false;
			}		
		}
	}
	return true;
}


function warnAboutMassSubscription() {

	var confirm_msg = "Are you sure you want to subscribe the selected email address(es) to your list? ";
	confirm_msg += "\n\n";

	confirm_msg += "Subscription of unconfirmed email address(es) should always be avoided. ";
	confirm_msg += "\n\n";

	confirm_msg += " If wanting to add unconfirmed email address(es), use the \"Send Invitation...\"";
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

function attachments_openKCFinder(field) {
    window.KCFinder = {
    	callBack: function(url) {
			var kcfinder_upload_url = escapeRegExp($("#kcfinder_upload_url").val() + '/'); 			
			var re = new RegExp(kcfinder_upload_url,'g');
			var new_val = url.replace(re, ''); 
	        $(field).html('<img src="' + $("#SUPPORT_FILES_URL").val() + '/static/images/attachment_icon.gif" />' + new_val);			
			$("#" + $(field).attr("data-attachment")).val(new_val); 
			$("#" + $(field).attr("data-attachment") + '_remove_button').show(); 			
			window.KCFinder = null;
		}
    };
    window.open($("#kcfinder_url").val() + '/browse.php?type=files&opener=custom', 'kcfinder_single',
        'status=0, toolbar=0, location=0, menubar=0, directories=0, ' +
        'resizable=1, scrollbars=0, width=800, height=600'
    );
}
function escapeRegExp(str) {
  return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&");
}



/* core5 FileManager */
var urlobj;

function browsecore5FileManager(obj) {
	urlobj = obj;
	var core5_filemanager_url = $("#core5_filemanager_url").val() + '/index.html';
	opencore5FileManager(
	core5_filemanager_url, screen.width * 0.7, screen.height * 0.7);
}

var oWindow;

function opencore5FileManager(url, width, height) {
	var iLeft = (screen.width - width) / 2;
	var iTop = (screen.height - height) / 2;
	var sOptions = "toolbar=no,status=no,resizable=yes,dependent=yes";
	sOptions += ",width=" + width;
	sOptions += ",height=" + height;
	sOptions += ",left=" + iLeft;
	sOptions += ",top=" + iTop;
	oWindow = window.open(url + '?custom_function=SetAttachmentUrl', "BrowseWindow", sOptions);
}

/* Seems like with the new ver of core5 FileManager, this needs to be called, SetUrl. Aww, well? 
function SetAttachmentUrl(url, width, height, alt) {
	var core5_filemanager_upload_url = escapeRegExp($("#core5_filemanager_upload_url").val() + '/');
	core5_filemanager_upload_url + '/';
	var re = new RegExp(core5_filemanager_upload_url, 'g');
	var new_val = url.replace(re, '');
	// console.log('new_val: ' + new_val);
	var field = urlobj;

	$(field).html('<img src="' + $("#SUPPORT_FILES_URL").val() + '/static/images/attachment_icon.gif" />' + new_val);
	$("#" + $(field).attr("data-attachment")).val(new_val);
	$("#" + $(field).attr("data-attachment") + '_remove_button').show();
	oWindow = null;
}
*/


function SetUrl(url, width, height, alt) {
	var core5_filemanager_upload_url = escapeRegExp($("#core5_filemanager_upload_url").val() + '/');
	core5_filemanager_upload_url + '/';
	var re = new RegExp(core5_filemanager_upload_url, 'g');
	var new_val = url.replace(re, '');
	// console.log('new_val: ' + new_val);
	var field = urlobj;

	$(field).html('<img src="' + $("#SUPPORT_FILES_URL").val() + '/static/images/attachment_icon.gif" />' + new_val);
	$("#" + $(field).attr("data-attachment")).val(new_val);
	$("#" + $(field).attr("data-attachment") + '_remove_button').show();
	oWindow = null;
}




Date.prototype.format = function(format) //author: meizz
{
  var o = {
    "M+" : this.getMonth()+1, //month
    "d+" : this.getDate(),    //day
    "h+" : this.getHours(),   //hour
    "m+" : this.getMinutes(), //minute
    "s+" : this.getSeconds(), //second
    "q+" : Math.floor((this.getMonth()+3)/3),  //quarter
    "S" : this.getMilliseconds() //millisecond
  }

  if(/(y+)/.test(format)) format=format.replace(RegExp.$1,
    (this.getFullYear()+"").substr(4 - RegExp.$1.length));
  for(var k in o)if(new RegExp("("+ k +")").test(format))
    format = format.replace(RegExp.$1,
      RegExp.$1.length==1 ? o[k] :
        ("00"+ o[k]).substr((""+ o[k]).length));
  return format;
}



function datetimesetupstuff() {
	// console.log('datetimesetupstuff'); 
	if($('#subscriber_timestamp_rangestart').length) { 
	 $('#subscriber_timestamp_rangestart').datetimepicker({
	  format:'Y-m-d H:i:s',
	  onShow:function( ct ){
	   this.setOptions({
	    maxDate:$('#subscriber_timestamp_rangeend').val()?$('#subscriber_timestamp.rangeend').val():false
	   })
	  }
	 });
	}

	if($('#subscriber_timestamp_rangeend').length) { 
	 $('#subscriber_timestamp_rangeend').datetimepicker({
	  format:'Y-m-d H:i:s',
	  onShow:function( ct ){
	   this.setOptions({
	    minDate:$('#subscriber_timestamp_rangestart').val()?$('#subscriber_timestamp_rangestart').val():false
	   })
	  }
	 });
	}
}



