var loading_str = '<p class="label info">Loading...</p>';
var spinner_opts = {
	  lines: 13 // The number of lines to draw
	, length: 28 // The length of each line
	, width: 14 // The line thickness
	, radius: 42 // The radius of the inner circle
	, scale: 1 // Scales overall size of the spinner
	, corners: 1 // Corner roundness (0..1)
	, color: '#000' // #rgb or #rrggbb or array of colors
	, opacity: 0.125 // Opacity of the lines
	, rotate: 0 // The rotation offset
	, direction: 1 // 1: clockwise, -1: counterclockwise
	, speed: 1 // Rounds per second
	, trail: 60 // Afterglow percentage
	, fps: 20 // Frames per second when using setTimeout() as a fallback for CSS
	, zIndex: 2e9 // The z-index (defaults to 2000000000)
	, className: 'spinner' // The CSS class to assign to the spinner
	, top: '50%' // Top position relative to parent
	, left: '50%' // Left position relative to parent
	, shadow: false // Whether to render a shadow
	, hwaccel: false // Whether to use hardware acceleration
	, position: 'absolute' // Element positioning
}
jQuery(document).ready(function($){

	/*
	if($("#footer").length) {
		$(window).bind("load", function () {
		    var footer = $("#footer");
		    var pos = footer.position();
		    var height = $(window).height();
		    height = height - pos.top;
		    height = height - footer.height();
		    if (height > 0) {
		        footer.css({
		            'margin-top': height + 'px'
		        });
		    }
		});
	}
	*/
	
	// Bounce Handler, Mostly. 
	$('body').on('click', 'a.modalbox', function(event){
		event.preventDefault();
		var responsive_options = {
			width: '95%',
			height: '95%',
			maxWidth: '640px',
			maxHeight: '480px'

		};
		$.colorbox({
			top: 0,
			fixed: true,
			initialHeight: 50,
			opacity: 0.50,
			href: $(this).attr("href"),
			maxWidth: '640px',
			maxHeight: '480px',
			width: '95%',
			height: '95%'
		});
		$(window).resize(function(){
		    $.colorbox.resize({
		      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
		      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
		    });		
		});
	});

	// Admin Menu

	if ($("#navcontainer").length) {

		var admin_menu_callbacks = $.Callbacks();
		admin_menu_callbacks.add(admin_menu_drafts_notification());
		admin_menu_callbacks.add(admin_menu_sending_monitor_notification());
		admin_menu_callbacks.add(admin_menu_subscriber_count_notification());
		admin_menu_callbacks.add(admin_menu_archive_count_notification());
		admin_menu_callbacks.add(admin_menu_mail_sending_options_notification());
		admin_menu_callbacks.add(admin_menu_mailing_sending_mass_mailing_options_notification());
		admin_menu_callbacks.add(admin_menu_bounce_handler_notification());
		admin_menu_callbacks.add(admin_menu_tracker_notification());
		admin_menu_callbacks.add(admin_menu_bridge_notification());
		admin_menu_callbacks.fire();

		if($("#screen_meta").length) {
			var highlight_scrn = $("#screen_meta").attr("data-menu_highlight");
			$( ".admin_menu_" + highlight_scrn ).addClass( "active" );
			
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
        
		var stickyHeader = $('#buttons').offset().top;
        $(window).scroll(function(){
            if( $(window).scrollTop() > stickyHeader && $('#buttons').width() >= 640) {
                    //$('#buttons').css({position: 'fixed', top: '0px'});	
					$('#buttons').addClass('floating_panel');				
            } else {
                    //$('#buttons').css({position: 'static', top: '0px'});
					$('#buttons').removeClass('floating_panel');
            }
        });
		if($("#additional_email_headers").length){
			$("#additional_email_headers").hide();
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

		var send_email_callbacks = $.Callbacks();
		send_email_callbacks.add(setup_attachment_fields());
		send_email_callbacks.add(setup_schedule_fields());
		send_email_callbacks.add(toggle_schedule_options());
		send_email_callbacks.add(datetimesetupstuff());
		send_email_callbacks.add(ChangeMassMailingButtonLabel(1));
		send_email_callbacks.add(mass_mailing_schedules_preview());
		send_email_callbacks.fire();

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


		$("body").on("click", ".scheduled_type", function(event) {
			toggle_schedule_options();
		});
		$("body").on("change", ".schedule_field", function(event) {
			mass_mailing_schedules_preview();
		});
		$("body").on("click", ".manually_run_all_scheduled_mass_mailings", function(event) {
			var mrasmm = $.Callbacks();
				mrasmm.add(save_msg(false));
				mrasmm.add(manually_run_all_scheduled_mass_mailings());
				mrasmm.fire();
		});

		$("body").on("click", ".remove_attachment", function(event) {
			if(confirm("Remove Attachment?")) {
				$("#" + $(this).attr("data-attachment")).val('');
				$("#" + $(this).attr("data-attachment") + "_button").text('Select a File...');
				$(this).hide();
			}
		});
		
		$("body").on("click", ".toggle_send_url_options", function(event) {
			send_url_options_setup();
		}); 
		send_url_options_setup();
		
		
		
		$("body").on("submit", "#mass_mailing", function(event) {
			event.preventDefault();
		});

		if ($("#send_email_screen").length || $("#send_url_email").length) {
			auto_save_as_draft();

			$("body").on("click", ".save_msg", function(event) {
				console.log('.save_msg');
				$("#button_action_notice").html('Working...');

				$("#save_draft_role").val($(this).attr("data-save_draft_role"));

				var ds = save_msg(false);
				window.location.replace(
					$("#s_program_url").val()
					+ '?flavor='   + $("#flavor").val()
					+ '&draft_id=' + $("#draft_id").val() +
					'&restore_from_draft=true&draft_role=' + $("#save_draft_role").val() + '&done=1'
				);
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
					save_msg(false);
					admin_menu_drafts_notification();
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

		$("body").on("click", ".ChangeMassMailingButtonLabel", function(event) {
			ChangeMassMailingButtonLabel();
		});

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
			save_msg(false)

			var confirm_msg = '';
			if($("#draft_role").val() == 'stationery') {
				confirm_msg = "Delete Stationery Message?";
			}
			else if($("#draft_role").val() == 'schedule') {
				confirm_msg = "Remove Schedule?";
			}
			else {
				confirm_msg = "Delete Draft Message?";
			}
			if (confirm(confirm_msg)) {
				window.location.replace($("#s_program_url").val() + '?flavor=delete_drafts&draft_ids=' + $("#draft_id").val());
			 }
			else {
				$("#button_action_notice").html('&nbsp;');

			}
		});

		$("body").on("click", "#keep_working_on_draft", function(event) {
			$.colorbox.close();
		});
		$("body").on("click", "#create_a_new_mass_mailing", function(event) {
		 	window.location.replace($("#s_program_url").val() + '?flavor=' + $("#f").val() + '&restore_from_draft=false');
		});
		$("body").on("click", "#show_all_drafts", function(event) {
		 	window.location.replace($("#s_program_url").val() + '?flavor=drafts');
		});
	}

	if ($("#drafts_screen").length) {

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
		refreshpage(60, $("#s_program_url").val() + "?flavor=sending_monitor");
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
			$("#s_program_url").val(), $("#message_id").val(), 'tracker_reports_container');
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

		if ($("#mailing_list_history").length) {
			mailing_list_history();
			$('body').on('click', '.radio_toggle_membership_history', function(){
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
		$('body').on('click', '.show_customize_invite_message', function(event){
			event.preventDefault();
			show_customize_invite_message();
		});
	}
	// Mail Sending >> Sending Options
	if ($("#mail_sending_options").length) {

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



		$("body").on("click", ".test_mail_sending_options", function(event) {
			event.preventDefault();
			test_mail_sending_options();
			admin_menu_notification('admin_menu_mail_sending_options_notification', 'admin_menu_mail_sending_options');
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

	
	if ($("#edit_template").length) {
		
		$("body").on("click", ".change_template", function(event) {		
			document.edit_template_form.target = "_self";
			document.edit_template_form.process.value = "true";
			$('#edit_template_form').submit();
		});
				
		$("body").on("click", ".preview_template", function(event) {		
			document.edit_template_form.target = "_blank";
			document.edit_template_form.process.value = "preview template";
			$('#edit_template_form').submit();
		});
		
		$("body").on("click", ".set_to_default", function(event) {		
			document.edit_template_form.target = "_self";
			var default_template = document.edit_template_form.default_template.value;
			document.edit_template_form.template_info.value = default_template;
			$('#edit_template_form').submit();
		});
		
	}
	
	
	if($("#transform_to_pro").length){ 
		
		$("body").on("click", ".verify_pro_dada", function(event) {				
			var responsive_options = {
			  width: '95%',
			  height: '95%',
			  maxWidth: '640px',
			  maxHeight: '480px'
			};
			$.colorbox({
			    href: $("#s_program_url").val(),
				data: {
					flavor: 'transform_to_pro',
					process: 'verify',
					pro_dada_username: $("#pro_dada_username").val(), 
					pro_dada_password: $("#pro_dada_password").val()

				},
				opacity: 0.50,
				maxWidth: '640px',
				maxHeight: '480px',
				width: '95%',
				height: '95%'				
			});
			$(window).resize(function(){
			    $.colorbox.resize({
			      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
			      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
			    });		
			});
		}); 
	}

	// Your Mailing List >> Options
	if ($("#list_options").length) {
		toggle_anyone_can_subscribe();
		toggle_closed_list();
		toggle_private_list();

		$('body').on('click', '#anyone_can_subscribe', function(event){
			toggle_anyone_can_subscribe();
		});

		$('body').on('click', '#closed_list', function(event){
			toggle_closed_list();
		});


		$('body').on('click', '#private_list_no', function(event){
			toggle_private_list();
		});
		$('body').on('click', '#private_list', function(event){
			toggle_private_list();
		});

		validator = $("#list_options_form").validate({
			debug: false,
			rules: {
				alt_send_subscription_notice_to: {
					email:    true,
					required: {
						depends:  function(element) {
							if($("#send_subscription_notice_to option:selected").val() == "alt" ){
								return true;
							}
							else {
								return false;
							}
						}
					}
				},
				alt_send_unsubscription_notice_to: {
					email:    true,
					required: {
						depends:  function(element) {
							if($("#send_unsubscription_notice_to option:selected").val() == "alt" ){
								return true;
							}
							else {
								return false;
							}
						}
					}
				},
				alt_send_admin_unsubscription_notice_to: {
					email:    true,
					required: {
						depends:  function(element) {
							if($("#send_admin_unsubscription_notice_to option:selected").val() == "alt" ){
								return true;
							}
							else {
								return false;
							}
						}
					}
				}

			}
		});
		toggle_sub_notice_to();
		toggle_unsub_notice_to();
		toggle_admin_unsub_notice_to();

		$("#send_subscription_notice_to").on("change", function(event) {
			validator.resetForm();
			toggle_sub_notice_to();
		});
		$("#send_unsubscription_notice_to").on("change", function(event) {
			validator.resetForm();
			toggle_unsub_notice_to();
		});
		$("#send_admin_unsubscription_notice_to").on("change", function(event) {
			validator.resetForm();
			toggle_admin_unsub_notice_to();
		});



	}
	
	if ($("#web_services").length) {
 	   $("body")
        .on("copy", ".zclip", function(/* ClipboardEvent */ e) {
		  var target_id = $(this).data("zclip-target-id"); 
          e.clipboardData.clearData();
          e.clipboardData.setData("text/plain", $("#" + target_id).val());
          e.preventDefault();
        });
	}

	function toggle_sub_notice_to(){
		if($("#send_subscription_notice_to option:selected").val() == "alt"){
			if($("#alt_send_subscription_notice_to").is(':hidden')) {
				$("#alt_send_subscription_notice_to").show();
			}
		}
		else {
			if($("#alt_send_subscription_notice_to").is(':visible')) {
				$("#alt_send_subscription_notice_to").hide();
			}
		}
	}
	function toggle_unsub_notice_to(){
		if($("#send_unsubscription_notice_to option:selected").val() == "alt"){
			if($("#alt_send_unsubscription_notice_to").is(':hidden')) {
				$("#alt_send_unsubscription_notice_to").show();
			}
		}
		else {
			if($("#alt_send_unsubscription_notice_to").is(':visible')) {
				$("#alt_send_unsubscription_notice_to").hide();
			}
		}
	}
	function toggle_admin_unsub_notice_to(){
		if($("#send_admin_unsubscription_notice_to option:selected").val() == "alt"){
			if($("#alt_send_admin_unsubscription_notice_to").is(':hidden')) {
				$("#alt_send_admin_unsubscription_notice_to").show();
			}
		}
		else {
			if($("#alt_send_admin_unsubscription_notice_to").is(':visible')) {
				$("#alt_send_admin_unsubscription_notice_to").hide();
			}
		}
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

	if ($("#delete_list_screen").length) {
		$("body").on("submit", "#delete_list_form", function(event) {
			if (confirm('Delete Mailing List? This cannot be undone.')) {
				return true;
			}
			else {
				alert("Cancelled.");
				return false;
			}
		});
	}

	// Mail Sending >> Mass Mailing Options
	if ($("#mailing_sending_mass_mailing_options").length) {
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
 	   $("body")
        .on("copy", ".zclip", function(/* ClipboardEvent */ e) {
		  var target_id = $(this).data("zclip-target-id"); 
          e.clipboardData.clearData();
          e.clipboardData.setData("text/plain", $("#" + target_id).val());
          e.preventDefault();
        });
	}


	// Membership >> View List

	$('body').on('click', '.change_type', function(event){
		change_type($(this).attr("data-type"));
		event.preventDefault();
	});
	$('body').on('click', '.turn_page', function(event){
		turn_page($(this).attr("data-page"));
		event.preventDefault();
	});

	$('body').on('click', '.change_order', function(event){
		change_order($(this).attr("data-by"), $(this).attr("data-dir"));
		event.preventDefault();
	});
	
	
	$("body").on("click", ".unsubscribeAllSubscribers", function(event) {

		event.preventDefault();
		
 	 	var type = $(this).data("type"); 
		var confirm_msg = '';
		if (type == 'Subscribers') {
			confirm_msg = "Are you sure you want to unsubscribe ALL Subscribers? ";
		} else {
			confirm_msg = "Are you sure you want to remove ALL " + type + "?";
		}

		if (!confirm(confirm_msg)) {
			if (type == 'Subscribers') {
				alert("Subscribers not unsubscribed.");
			} else {
				alert("'" + type + "' not removed.");
			}
			return false;
		} else {
			window.location.href = $("#s_program_url").val() + '?flavor=remove_all_subscribers&type=' + type;
			return true;
		}
	});
	
	
	$('body').on('click', '.search_list', function(event){
		search_list();
		event.preventDefault();
	});

	$('body').on('click', '.show_advanced_search_list', function(event){
		//alert('Calling show_advanced_search_list()');
		show_advanced_search_list();
		event.preventDefault();
	});
	$('body').on('click', '.advanced_search_list', function(event){
		advanced_search_list();
		event.preventDefault();
	});

	$('body').on('click', '.close_advanced_search_list', function(event){
		close_advanced_search_list();
		event.preventDefault();
	});


	$('body').on('submit', '#search_form', function(event){
		search_list();
		event.preventDefault();
	});
	$('body').on('click', '.clear_search', function(event){
		clear_search();
		event.preventDefault();
	});

	$('body').on('click', '.clear_advanced_search_list', function(event){
		clear_advanced_search();
		event.preventDefault();
	});

	$('body').on('keydown', '#search_query', function(event){
		$("#search_query").autocomplete({
			source: function(request, response) {
				$.ajax({
					url: $("#s_program_url").val(),
					type: "POST",
					dataType: "json",
					data: {
						flavor: 'search_list_auto_complete',
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
	$('body').on('click', '.change_profile_password', function(event){
		show_change_profile_password_form();
		event.preventDefault();
	});

	$('body').on('click', '.cancel_change_profile_password', function(event){
		cancel_change_profile_password();
		event.preventDefault();
	});

	// Mail Sending >> Mass Mailing Options
	$('body').on('click', '.previewBatchSendingSpeed', function(event){
		previewBatchSendingSpeed();
	});

	$('body').on('click', '#amazon_ses_auto_batch_settings', function(event){
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
	$('body').on('click', '#check_version', function(event){
		event.preventDefault();
		check_newest_version($('#check_version').attr("data-ver"));
	});


	if($("#scheduled_jobs").length) {
 	   $("body")
        .on("copy", ".zclip", function(/* ClipboardEvent */ e) {
		  var target_id = $(this).data("zclip-target-id"); 
          e.clipboardData.clearData();
          e.clipboardData.setData("text/plain", $("#" + target_id).val());
          e.preventDefault();
        });
		
	$("body").on("click", ".manually_run_scheduled_jobs", function(event) {
			
			var responsive_options = {
			  width: '95%',
			  height: '95%',
			  maxWidth: '640px',
			  maxHeight: '480px'
			};
			$.colorbox({
			    href: $("#s_program_url").val(),
				data: {
					flavor: $("#sched_flavor").val(),
					list: '_all',
					schedule: '_all',
					output_mode: '_verbose',
					for_colorbox: 1
				},
				opacity: 0.50,
				maxWidth: '640px',
				maxHeight: '480px',
				width: '95%',
				height: '95%'				
			});
			$(window).resize(function(){
			    $.colorbox.resize({
			      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
			      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
			    });		
			});
		});
	}


	// Plugins/Extensions >> Bounce Handler
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

	// Plugins/Extensions >> Beatitude
	if ($("#plugins_beatitude_schedule_form").length) {
		datetimesetupstuff();
	}

	// Plugins/Extensions >> Bridge
	if ($("#plugins_bridge_default").length) {

		$("body").on("click", ".plugins_bridge_test_pop3", function(event) {
			event.preventDefault();
			plugins_bridge_test_pop3();
		});
		
		$('body').on('click', '.change_pop3_password', function(event){
			plugins_bridge_show_change_pop3_password_form();
			event.preventDefault();
		});

		$('body').on('click', '.cancel_change_pop3_password', function(event){
			plugins_bridge_hide_change_pop3_password_form();
			event.preventDefault();
		});


 	   $("body")
        .on("copy", ".zclip", function(/* ClipboardEvent */ e) {
		  var target_id = $(this).data("zclip-target-id"); 
          e.clipboardData.clearData();
          e.clipboardData.setData("text/plain", $("#" + target_id).val());
          e.preventDefault();
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
			window.location.href = $("#s_program_url").val() + '?flavor=view_list&type=authorized_senders';
		});
		$("body").on("click", ".add_authorized_senders", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?flavor=add&type=authorized_senders';
		});
		$("body").on("click", ".view_moderators", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?flavor=view_list&type=moderators';
		});
		$("body").on("click", ".add_moderators", function(event) {
			event.preventDefault();
			window.location.href = $("#s_program_url").val() + '?flavor=add&type=moderators';
		});




		bridge_setup_list_email_type_params();

	}

	// Plugins/Extensions >> Change List Shortname
	if ($("#plugins_change_list_shortname").length) {
		$("body").on("click", "#verify_button", function(event) {

			var responsive_options = {
			  width: '95%',
			  height: '95%',
			  maxWidth: '640px',
			  maxHeight: '480px'
			};
			$.colorbox({
			    href: $("#s_program_url").val(),
				data: {
					flavor: 'plugins',
					plugin: 'change_list_shortname',
					prm: $('#prm').val(),
					new_name: $('#new_name').val()
				},
				opacity: 0.50,
				maxWidth: '640px',
				maxHeight: '480px',
				width: '95%',
				height: '95%'				
			});
			$(window).resize(function(){
			    $.colorbox.resize({
			      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
			      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
			    });		
			});
			
			
			
		});
	}

	// Plugins/Extensions >> Mailing Monitor
	if ($("#plugins_mailing_monitor_default").length) {

		plugins_mailing_monitor();
		$('body').on('click', '#mailing_monitor_button', function(event){
			event.preventDefault();
			plugins_mailing_monitor();
		});

	}



	// Plugins/Extensions >> Beatitude
	if ($("#plugins_beatitude_schedule_form").length) {
		$("body").on("click", ".preview_message_receivers", function(event) {
			event.preventDefault();
			preview_message_receivers();
		});
	}

	// do not like globals...
	var trackerc = new Array(); 
	// Plugins/Extensions >> Tracker
	if ($("#plugins_tracker_message_report").length) {
		window.onresize = function(){
			var arrayLength = trackerc.length;
			for (var i = 0; i < arrayLength; i++) {
				
				var new_width  =  $("#" + trackerc[i].chart_options['target_div']).width();
				var new_height = (new_width/1.68).toFixed(0);
				
				//if(new_height > new_width){ 
				//	alert("new_height: " + new_height + "new_width:" + new_width); 
				//	}
				
				trackerc[i].chart_options['width']  = new_width;
				trackerc[i].chart_options['height'] = new_height;
				
				// I'm guessing this isn't doing the Thing I want it to do. 
				$("#" + trackerc[i].chart_options['target_div']).height(new_height);
				
				trackerc[i].chart_obj.draw(trackerc[i].chart_data, trackerc[i].chart_options);		
			}
		};
	
		update_plugins_tracker_message_report();
	}


	if ($("#plugins_tracker_default").length) {
		tracker_parse_links_setup();
		tracker_toggle_tracker_track_email_options();

		message_history_html(1);
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


		$("body").on("change", '#subscriber_history_type', function(event) {
			message_history_html();
		});



		$("body").on("click", '.tracker_parse_links_setup', function(event) {
			tracker_parse_links_setup();
		});

		$("body").on("click", '#tracker_track_email', function(event) {
			tracker_toggle_tracker_track_email_options();
		});


		$("body").on("click", '.tracker_delete_msg_id_data', function(event) {
			mid = $(this).attr("data-mid");
			tracker_delete_msg_id_data(mid);
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
	// Plugins/Extensions >> Password Protect Directories
	if ($("#plugins_password_protect_directories_default").length) {
		$('body').on('click', '#change_password_button', function(event){
			password_protect_directories_show_change_password_form();
		});
	}

	// Plugins/Extensions >> Log Viewer
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
	
	$('body').on('click', '.also_save_for', function(event){
		// alert("also_save_for");
		// alert("$(this).closest(\"form\").prop('id') " + $(this).closest("form").prop('id') );
		
		var responsive_options = {
		  width: '95%',
		  height: '95%',
		  maxWidth: '640px',
		  maxHeight: '480px'
		};
		$.colorbox({
			top: 0,
			fixed: true,
			initialHeight: 50,
			width: '95%',
			height: '95%',
			maxWidth: '640px',
			maxHeight: '480px',
			opacity: 0.50,
			href: $("#s_program_url").val(),
			data: {
				flavor: 'also_save_for_settings', 
				form_id: $(this).closest("form").prop('id')  
			},
		});
		$(window).resize(function(){
		    $.colorbox.resize({
		      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
		      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
		    });		
		});
	}); 
	
	$('body').on('click', '.set_also_save_for_lists', function(event){
		var also_save_for = new Array(); 
		$("input:checkbox[name=also_save]:checked").each(function(){
		    also_save_for.push($(this).val());
		});
		$("#also_save_for_list").val(also_save_for.join(',')); 
		$("#also_save_for").val(1);
		
		var form_id = $("#form_id").val();
		$("#" + form_id).submit(); 
	}); 

	$('body').on('click', '.clear_field', function(event){
		event.preventDefault();
		$("#" + $(this).attr("data-target")).val('');
	});

	$('body').on('click', '.previous', function(event){
		event.preventDefault();
		history.back();
	});

	$('body').on('click', '.fade_me', function(event){
		$('#alertbox').effect('fade');
		event.preventDefault();
	});

	$('body').on('click', '.toggleCheckboxes', function(event){
		toggleCheckboxes(
		$(this).prop("checked"), $(this).attr("data-target_class"));
	});
	$('body').on('click', '.linkToggleCheckboxes', function(event){
		event.preventDefault();
		var state = true;
		if ($(this).attr("data-state") == "false") {
			state = false;
		}
		toggleCheckboxes(
		state, $(this).attr("data-target_class"));
	});

	$('body').on('click', '.toggleDivs', function(event){
		event.preventDefault();
		toggleDisplay($(this).attr("data-target"));
	});
	$('body').on('click', '.radio_toggleDivs', function(event){
		toggleDisplay($(this).attr("data-target"));
	});

	$("body").on("click", ".amazon_verify_email_in_warning", function(event) {
		event.preventDefault();
		amazon_verify_email($(this).attr("data-email"));
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

function admin_menu_mail_sending_options_notification() {
	admin_menu_notification('admin_menu_mail_sending_options_notification', 'admin_menu_mail_sending_options');
}

function admin_menu_mailing_sending_mass_mailing_options_notification() {
	admin_menu_notification('admin_menu_mailing_sending_mass_mailing_options_notification', 'admin_menu_mailing_sending_mass_mailing_options');
}

function admin_menu_bounce_handler_notification() {
	admin_menu_notification('admin_menu_bounce_handler_notification', 'admin_menu_bounce_handler');
}
function admin_menu_tracker_notification() {
	admin_menu_notification('admin_menu_tracker_notification', 'admin_menu_tracker');
}
function admin_menu_bridge_notification() { 
	admin_menu_notification('admin_menu_bridge_notification', 'admin_menu_bridge');
}



function admin_menu_notification(sflavor, target_class) {
	var r = 60 * 5 * 1000; // Every 5 minutes.
	var refresh_loop = function(no_loop) {

			var request = $.ajax({
				url: $('#navcontainer').attr("data-s_program_url"),
				type: "POST",
				cache: false,
				data: {
					flavor: sflavor
				},
				dataType: "html"
			});
			request.done(function(content) {
				if ($('.' + target_class + '_notification').length) {
					$('.' + target_class + '_notification').remove();
				}

				if(content.length) {
					//console.log('update! ' + target_class);
					$('.' + target_class + ' a').append('<span class="' + target_class + '_notification round alert label"> ' + content + '</span>');
				}
			});
			if (no_loop != 1) {
				setTimeout(
				refresh_loop, r);
			}
		}
		setTimeout(refresh_loop, r);
		refresh_loop(1);
}

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

function setup_schedule_fields() {
	if($('#schedule_single_displaydatetime').length) {
		$('#schedule_single_displaydatetime').datetimepicker(
			{
				minDate: 0,
				//minTime: 0,
				inline:false,
				format:'Y-m-d H:i:s',
				onChangeDateTime:function(dp,$input){
				   mass_mailing_schedules_preview();
				}
			}
		);
	}
	// Recurring
	if($('#schedule_recurring_display_hms').length) {
		$('#schedule_recurring_display_hms').datetimepicker(
			{
		  		format:'H:i:s',
		  		datepicker:false,
		  		onShow:function( ct ){},
				onChangeDateTime:function(dp,$input){
				   mass_mailing_schedules_preview();
				}
		 	}
		);
	}
	if($('#schedule_recurring_displaydatetime_start').length) {
		 $('#schedule_recurring_displaydatetime_start').datetimepicker({
		  format:'Y-m-d',
		  timepicker:false,
		  onShow:function( ct ){
		   this.setOptions({
		    maxDate:$('#schedule_recurring_displaydatetime_end').val()?$('#schedule_recurring_displaydatetime_end').val():false
		   })
		  },
		onChangeDateTime:function(dp,$input){
			mass_mailing_schedules_preview();
		}
		});
	}
	if($('#schedule_recurring_displaydatetime_end').length) {
		 $('#schedule_recurring_displaydatetime_end').datetimepicker(
			{
				format:'Y-m-d',
				timepicker:false,
				onShow:function( ct ){
					this.setOptions({
		    			minDate:$('#schedule_recurring_displaydatetime_start').val()?$('#schedule_recurring_displaydatetime_start').val():false
		   			})
		  		},
				onChangeDateTime:function(dp,$input){
				 	mass_mailing_schedules_preview();
				}

		 	}
		);
	}
}

function toggle_schedule_options() {
	if ($("#schedule_type_single").prop("checked") === true) {
		if ($('#schedule_type_single_options').is(':hidden')) {
			$('#schedule_type_single_options').show('blind');
		}
		if ($('#schedule_type_recurring_options').is(':visible')) {
			$('#schedule_type_recurring_options').hide('blind');
		}
	}

	if ($("#schedule_type_recurring").prop("checked") === true) {
		if ($('#schedule_type_recurring_options').is(':hidden')) {
			$('#schedule_type_recurring_options').show('blind');
		}
		if ($('#schedule_type_single_options').is(':visible')) {
			$('#schedule_type_single_options').hide('blind');
		}
	}
}



var mmsp = '';
function mass_mailing_schedules_preview(skip_stale_check) {
	var new_mmsp = $('.schedule_field').serialize();
    
	var target_id = 'mass_mailing_schedules_preview_results'; 
	
	if(skip_stale_check !== 1) {
		if(mmsp == new_mmsp){
			return false;
		}
		else {
			mmsp = new_mmsp;
		}
	}
	var target  = document.getElementById('view_list_viewport');
	var spinner = new Spinner(spinner_opts).spin(target);
	var request = $.ajax({
		url: $("#s_program_url").val(),
		data: $('.schedule_field').serialize() + '&flavor=mass_mailing_schedules_preview',
		cache: false,
		dataType: "html",
		async: true,
		success: function(content) {
			$("#" + target_id).fadeTo(200, 0, function() {		
				$("#" + target_id).html(content)
				$("#" + target_id).fadeTo(200, 1);
				spinner.stop();
			});
		}
	});
}

function manually_run_all_scheduled_mass_mailings() {
	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px',
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor:         $("#sched_flavor").val(),
			list:           $("#list").val(),
			schedule:       'scheduled_mass_mailings',
			output_mode:    '_verbose',
			for_colorbox:   1
		},
		onComplete: function(){
			mass_mailing_schedules_preview(1);
			update_scheduled_mass_mailings_options();
		}
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});
}

function update_scheduled_mass_mailings_options() {
	$.ajax({
		url: $("#s_program_url").val(),
		data: {
			flavor:        'draft_message_values',
			draft_id:     $("#draft_id").val(),
			draft_role:   $("#draft_role").val(),
			draft_screen: $("#flavor").val()
		},
		dataType: "json",
		async: true,
		success: function(content) {

			$("#schedule_html_body_checksum").val(content.schedule_html_body_checksum);

			if(content.schedule_activated == "1"){
				if ($("#schedule_activated").prop("checked") === false) {
					$('#schedule_activated').prop('checked', true);
				}
			}
			else if(content.schedule_activated == "0"){
				if ($("#schedule_activated").prop("checked") === true) {
					$('#schedule_activated').prop('checked', false);
				}
			}
		}
	});

}


function save_msg(async) {

	//alert('save draft called!');

	var r = false;

	//	console.log(
	//	$("#mass_mailing").serialize()
	//	 + '&process=save_as_draft'
	//	);

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

		$('#draft_notice .alert').text('auto-saving...');

		var request = $.ajax({
			url:       $("#s_program_url").val(),
			type:      "POST",
			dataType: "json",
			cache:     false,
			async:     async,
			data: $("#mass_mailing").serialize() + '&process=save_as_draft&json=1',
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

function auto_save_as_draft() {
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


	$("#save_draft_role").val($("#draft_role").val());

	var r = 60 * 1000; // Every 1 minute.
	//var r = 10 * 1000; // Every 10 seconds
	var refresh_loop = function(no_loop) {
		$('#draft_notice .alert').text('auto-saving...');
		var request = $.ajax({
			url: $("#s_program_url").val(),
			type: "POST",
			dataType: "json",
			cache: false,
			data: $("#mass_mailing").serialize() + '&process=save_as_draft&json=1',
			success: function(content) {
				$('#draft_notice .alert').text('Last auto-save: ' + new Date().format("yyyy-MM-dd h:mm:ss"));
				console.log('Saving Draft Successful - content.id: ' + content.id);
				console.log('$("#draft_role").val(): '               + $("#draft_role").val());
				console.log('$("#save_draft_role").val(): '          + $("#save_draft_role").val());



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
					flavor: 'sending_monitor',
					id: message_id,
					type: type,
					process: 'ajax'
				},
				dataType: "html"
			});
			request.done(function(content) {
				$("#" + target_id).html(content);
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
				flavor: 'plugins',
				plugin: 'tracker',
				prm: "m",
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




/* Membership >> View List */

function view_list_viewport(initial) {
	//alert('$("#advanced_search").val() ' + $("#advanced_search").val());
	//alert(' $("#advanced_query").val() ' +  $("#advanced_query").val());


	if (initial == 1) {
		$("#view_list_viewport").height(480); 
	}

	var target = document.getElementById('view_list_viewport');
	var spinner = new Spinner(spinner_opts).spin(target);

	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'view_list',
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
		spinner.stop();

		if (initial == 1) {
			$("#view_list_viewport").fadeTo( 0, 0);
			$("#view_list_viewport").html(content);
			$("#view_list_viewport").fadeTo(200, 1);
			
			if($("#advanced_search").val() == 1){
				console.log('not hiding advanced search form');
			}
			else {
				console.log('Hiding advanced search form');
				$("#advanced_list_search").hide();
			}

			// $("#view_list_viewport").fadeTo(200, 1);
		} else {
			//$("#view_list_viewport").fadeTo(200, 0); 
			//$("#view_list_viewport").fadeTo(200, 1, function() {
				$("#view_list_viewport").html(content);
				if($("#advanced_search").val() != 1){
					$("#advanced_list_search").hide();
				}
			//});
		}

		//$("#view_list_viewport_loading").html('<p>&nbsp;</p>');

		datetimesetupstuff();
		set_up_advanced_search_form();

		console.log('#advanced_search ' + $("#advanced_search").val()) ;

		if($("#advanced_search").val() == 1){ // === is not working, here.
			$("#domain_break_down").fadeTo(200, 0);
		}
		else {
			$("#domain_break_down").fadeTo(200, 1);
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

	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
		inline:true,
		href:$form,
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxWidth: '640px',
		maxHeight: '480px',
		width: '95%',
		height: '95%',		
		opacity: 0.50,
		onComplete: function(){
			//alert("fill it in!" + $("#advanced_query").val());
			$("#mass_update_advanced_query").val($("#advanced_query").val());
		}
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
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

	$("#domain_break_down").hide('fade');
	$("#advanced_search").val(1);
	$("#advanced_list_search").show('fade');
}

function advanced_search_list(){
	//alert($("#advanced_list_search_form").serialize())
	$("#page").val(1);
	$("#advanced_search").val(1);
	$("#advanced_query").val($("#advanced_list_search_form").serialize());
	view_list_viewport();
}
function close_advanced_search_list(){

	$("#advanced_list_search").hide('fade');

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
	$("#domain_break_down_chart_loading").html(loading_str);
	$.ajax({
		url: $("#s_program_url").val(),
		dataType: "json",
		data: {
			flavor: 'domain_breakdown_json',
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
				pieSliceTextStyle: {
					color: '#FFFFFF'
				},
				colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
				is3D: true
			};

			options['width']  = $('#domain_break_down_chart').width();
			options['height'] = $('#domain_break_down_chart').width();
			domain_breakdown_chart.draw(domain_breakdown_chart_data, options);

			window.onresize = function(){
			   options['width']  = $('#domain_break_down_chart').width();
			   options['height'] = $('#domain_break_down_chart').width();
			   domain_breakdown_chart.draw(domain_breakdown_chart_data, options);
			};
			$("#domain_break_down_chart_loading").html('<p>&nbsp;</p>');
			google.visualization.events.addListener(domain_breakdown_chart, 'select', selectHandler);
		}
	});
}


function user_agent_chart(type, target_div) {
	console.log('user_agent_chart! type: ' + type + ';target_div:' + target_div);

	$("#" + target_div + "_loading").html(loading_str);
	$.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'user_agent_json',
			mid: $('#tracker_message_id').val(),
			type: type
		},
		dataType: "json",
		cache: false,
		async: true,
		success: function(jsonData) {
			// Create our data table out of JSON data loaded from server.
			var options = {
				chartArea: {
					left: 20,
					top: 20,
					width: "90%",
					height: "90%"
				},
				pieSliceTextStyle: {
					color: '#FFFFFF'
				},
				colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
				is3D: true,
				width: $("#" + target_div).width(),
				height: ($("#" + target_div).width()/1.68).toFixed(0),
				target_div: target_div
			};
			var data = new google.visualization.DataTable(jsonData);
			var chart = new google.visualization.PieChart(document.getElementById(target_div));

			$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
			$("#" + target_div).hide("fade", function() {
				chart.draw(data, options);
				trackerc.push({chart_obj: chart, chart_data: data, chart_options: options});
				$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
				$("#" + target_div).show('fade');
			});
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
		height: 720,
		chartArea: {
			left: 60,
			top: 20,
			width: '90%',
			height: '90%',

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

		$("#sub_unsub_trends_loading").html(loading_str);
		$.ajax({
			url: $("#s_program_url").val(),
			data: {
				flavor: 'sub_unsub_trends_json',
				days: $("#amount option:selected").val()
			},
			dataType: "json",
			async: true,
			success: function(jsonData) {
				data = new google.visualization.DataTable(jsonData);

				var options = {
					chartArea: {
						left: 60,
						top: 20,
						width: "70%",
						height: "70%"
					},
				};
				 options['width']  = $('#sub_unsub_trends').width();
				 options['height'] = $('#sub_unsub_trends').width();


				sub_unsub_trend_c.draw(data, options);
				window.onresize = function(){
				   options['width']  = $('#sub_unsub_trends').width();
				   options['height'] = $('#sub_unsub_trends').width();
					sub_unsub_trend_c.draw(data, options);
				};
				$("#sub_unsub_trends_loading").html('<p>&nbsp;</p>');
			}
		});
	}

	draw_sub_unsub_trend_chart();
}



// Membership >> user@example.com

function mailing_list_history() {
	$("#mailing_list_history_loading").html(loading_str);

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
			flavor: 'mailing_list_history',
			email: $("#email").val(),
			membership_history: scope
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#mailing_list_history").hide().html(content).show('fade');

		$("#mailing_list_history_loading").html('<p>&nbsp;</p>');
	});
}

function membership_activity() {
	$("#membership_activity_loading").html(loading_str);
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'membership_activity',
			email: $("#email").val(),
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#membership_activity").hide().html(content).show('fade');

		$("#membership_activity_loading").html('<p>&nbsp;</p>');
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
			flavor: 'also_member_of',
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
	
	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		maxWidth: '640px',
		maxHeight: '480px',
		width: '95%',
		height: '95%',		
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor:         'add',
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
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});
}

function validate_update_email(is_for_all_lists) {
	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px',
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor: 'validate_update_email',
			updated_email: $("#updated_email").val(),
			email:         $("#original_email").val(),
			for_all_lists: is_for_all_lists
		}
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});
}

function validate_remove_email(for_multiple_lists) {

	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px',
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor:             'validate_remove_email',
			email:              $("#email").val(),
			type:               $("#type_remove option:selected").val(),
			for_multiple_lists: for_multiple_lists
		}
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});
}

function membership_bouncing_address_information() {

	$("#membership_bouncing_address_information").hide().html(loading_str).show('fade');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor:          'view_bounce_history',
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

function send_url_options_setup() {

	var hidden = [];
	var visible = [];

	if ($("#content_from_url").prop("checked") === true) {
		hidden = ['HTML_content_from_textarea_widget'];
		visible = ['HTML_content_from_url_widget', 'HTML_content_advanced_options'];
	}
	if ($("#content_from_textarea").prop("checked") === true) {
		hidden = ['HTML_content_from_url_widget'];
		visible = ['HTML_content_from_textarea_widget', 'HTML_content_advanced_options'];
	}
	if ($("#content_from_none").prop("checked") === true) {
		hidden = ['HTML_content_from_url_widget', 'HTML_content_from_textarea_widget', 'HTML_content_advanced_options'];
		visible = [];
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
	send_url_options_PlainText_setup();
}


function send_url_options_PlainText_setup() {

	var pthidden = [];
	var ptvisible = [];
	
	if ($("#plaintext_content_from_url").prop("checked") === true) {
		pthidden  = ['PlainText_content_from_text_widget']; 
		ptvisible = ['PlainText_content_from_url_widget']; 
	}
	if ($("#plaintext_content_from_text").prop("checked") === true) {
		pthidden  = ['PlainText_content_from_url_widget']; 
		ptvisible = ['PlainText_content_from_text_widget']; 
	}
	if ($("#plaintext_content_from_auto").prop("checked") === true) {
		pthidden = ['PlainText_content_from_url_widget', 'PlainText_content_from_text_widget'];
	}

	var i;
	for (i = 0; i < pthidden.length; i += 1) {
		//if ($('#' + pthidden[i]).is(':visible')) {
			$('#' + pthidden[i]).hide('blind');
		//}
	}
	i = 0;
	for (i = 0; i < ptvisible.length; i += 1) {
		if ($('#' + ptvisible[i]).is(':hidden')) {
			$('#' + ptvisible[i]).show('blind');
		}
	}
	
}



function test_mail_sending_options() {


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

	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px',
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor: 'mail_sending_options_test',
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
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});
}





function amazon_verify_email(email) {

	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px',
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor: 'amazon_ses_verify_email',
			amazon_ses_verify_email: email
		}
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});

}


// Mail Sending >> Mass Mailing Options

function previewBatchSendingSpeed() {
	$("#previewBatchSendingSpeed_loading").hide().html(loading_str).show('fade');


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
			flavor: 'previewBatchSendingSpeed',
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
	$("#amazon_ses_get_stats_loading").hide().html(loading_str).show('fade');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'amazon_ses_get_stats'
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









// Plugins/Extensions >> Bounce Bounce Handler

function bounce_handler_show_scorecard() {
	$("#bounce_scorecard_loading").html(loading_str);
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'bounce_handler',
			prm: 'cgi_scorecard',
			page: $('#bounce_handler_page').val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#bounce_scorecard").hide('fade', function() {
			$("#bounce_scorecard").html(content);
			$("#bounce_scorecard").show('fade');
			$("#bounce_scorecard_loading").html('<p>&nbsp;</p>');
		});


	});
}


function bounce_handler_turn_page(page_to_turn_to) {
	$("#bounce_handler_page").val(page_to_turn_to);
	bounce_handler_show_scorecard();
}

function bounce_handler_parse_bounces() {
	$("#parse_bounce_results_loading").html('<p class="label info">Loading</p>');
	$("#parse_bounces_button").val('Parsing...');

	var isa_test = 0;
	if($("#test").prop("checked") === true) {
		isa_test = 'bounces';
	}
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor:      'plugins',
			plugin:      'bounce_handler',
			prm:         'ajax_parse_bounces_results',
			parse_amount: $('#parse_amount').val(),
			test:         isa_test
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#parse_bounce_results").html(content);
		$("#parse_bounces_button").val('Parse Bounces');
		$("#parse_bounce_results_loading").html('<p>&nbsp;</p>');

	});
}

function ajax_parse_bounces_results() {

	var isa_test = 0;
	if($("#test").prop("checked") === true) {
		isa_test = 'bounces';
	}

	var responsive_options = {
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px'
	};
	$.colorbox({
		top: 0,
		fixed: true,
		initialHeight: 50,
		width: '95%',
		height: '95%',
		maxWidth: '640px',
		maxHeight: '480px',
		opacity: 0.50,
		href: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'bounce_handler',
			prm: 'ajax_parse_bounces_results',
			parse_amount: $('#parse_amount').val(),
			test:         isa_test
		},
		onComplete:function(){
			bounce_handler_show_scorecard();
		}
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});
}

function bounce_handler_manually_enter_bounces() {
	var target_id = 'manually_enter_bounces_results';
	$("#" + target_id + "_loading").html('<p class="label info">Loading</p>');
	$("#" + target_id).html('');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'bounce_handler',
			prm: 'manually_enter_bounces',
			process: $('#process').val(),
			msg: $('#msg').val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#" + target_id).html(content);
		$("#" + target_id + "_loading").html('<p>&nbsp;</p>');

	});

}


// Plugins/Extensions >> Bridge

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
	
	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
	    href: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'bridge',
			prm: 'cgi_test_pop3_ajax',
			server: $("#discussion_pop_server").val(),
			username: $("#discussion_pop_username").val(),
			password: $("#discussion_pop_password").val(),
			auth_mode: $("#discussion_pop_auth_mode option:selected").val(),
			use_ssl: use_ssl
		},
		opacity: 0.50,
		maxWidth: '640px',
		maxHeight: '480px',
		width: '95%',
		height: '95%'				
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});	
}

function plugins_bridge_manually_check_messages() {
	
	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
	    href: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'bridge',
			prm:    'admin_cgi_manual_start_ajax'
		},
		opacity: 0.50,
		maxWidth: '640px',
		maxHeight: '480px',
		width: '95%',
		height: '95%'				
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
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

// Plugins/Extensions >> Tracker

function update_plugins_tracker_message_report() {
	
	
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

	google.setOnLoadCallback(user_agent_chart('opens',                 'user_agent_opens_chart'));
	google.setOnLoadCallback(user_agent_chart('clickthroughs', 'user_agent_clickthroughs_chart'));

	tracker_message_report_callback.add(message_email_report_table('unsubscribe',    'unsubscribe_table'));
	tracker_message_report_callback.add(message_email_report_table('soft_bounce',    'soft_bounce_table'));
	tracker_message_report_callback.add(message_email_report_table('hard_bounce',    'hard_bounce_table'));
	tracker_message_report_callback.add(message_email_report_table('errors_sending_to', 'errors_sending_to_table'));
	tracker_message_report_callback.add(message_email_report_table('abuse_report', 'abuse_report_table'));

	tracker_message_report_callback.fire();


}

function country_geoip_table(type, label, target_div) {

	$("#" + target_div + "_loading").html(loading_str);
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'country_geoip_table',
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

		$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
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

	$("#" + target_div + "_loading").html(loading_str);
	
	var target  = document.getElementById(target_div);
	var spinner = new Spinner(spinner_opts).spin(target);
	
	$.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'country_geoip_json',
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
				keepAspectRatio: true,
				backgroundColor: "#FFFFFF",
				colorAxis: {
					colors: ['#e5f2ff', '#ff0066']
				},
				width: $("#" + target_div).width(),
				height: ($("#" + target_div).width()/1.68).toFixed(0),
				target_div: target_div
			};
			var chart = new google.visualization.GeoChart(document.getElementById(target_div));


			$("#" + target_div).fadeTo(200, 0, function() {
				chart.draw(data, options);
				trackerc.push({chart_obj: chart, chart_data: data, chart_options: options});
				$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
				$("#" + target_div).fadeTo(200, 1);
				spinner.stop(); 
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
	$("#" + target_div + "_loading").html(loading_str);
	$.ajax({
		url: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'message_individual_email_activity_report_table',
			mid: $('#tracker_message_id').val(),
			email: email
		},
		dataType: "html",
		async: true,
		success: function(content) {
			$("#" + target_div).hide("fade", function() {
				$("#" + target_div).html(content);
				$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
				$("#" + target_div).show('fade');
			});
		}
	});

}

function individual_country_geoip_map(type, country, target_div) {
	
	var target  = document.getElementById(target_div);
	var spinner = new Spinner(spinner_opts).spin(target);
	
	$("#" + target_div + "_loading").html(loading_str);
	$.ajax({
		url: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'individual_country_geoip_json',
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
				colorAxis: {
					colors: ['#3399ff', '#ff0066']
				},
				width: $("#" + target_div).width(),
				height: ($("#" + target_div).width()/1.68).toFixed(0),
				target_div: target_div
			};
			var chart = new google.visualization.GeoChart(document.getElementById(target_div));


			$("#" + target_div).fadeTo(200, 0, function() {
				chart.draw(data, options);
				trackerc.push({chart_obj: chart, chart_data: data, chart_options: options});
				$("#" + target_div + "_loading").html('<p class="label secondary"><a href="#" data-type="' + type + '" class="back_to_geoip_map">&lt; &lt;Back to World Map</a> | <a href="#"  data-type="' + type + '" data-country="' + country + '" class="individual_country_cumulative_geoip_table">Table View</a></p>');
				$("#" + target_div).fadeTo(200, 1);
				spinner.stop();
			});
			
		}
	});
}

function individual_country_cumulative_geoip_table(type, country, target_div) {
	$("#" + target_div + "_loading").html(loading_str);
	var target  = document.getElementById(target_div);
	var spinner = new Spinner(spinner_opts).spin(target);
	$.ajax({
		url: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'individual_country_geoip_report_table',
			mid: $('#tracker_message_id').val(),
			type: 'ALL',
			country: country
		},
		dataType: "html",
		async: true,
		success: function(content) {
			$("#" + target_div).fadeTo(200, 0, function() {
				$("#" + target_div).html(content);
				$("#" + target_div + "_loading").html('<p class="label secondary"><a href="#" data-type="' + type + '" data-country="' + country + '"  class="individual_country_geoip">&lt; &lt; Back to Country Map</a></p>');
				$("#" + target_div).fadeTo(200, 1);
				spinner.stop(); 
			});
		}
	});

}

function data_over_time_graph(type, label, target_div) {
	$("#" + target_div + "_loading").html(loading_str);
	var request = $.ajax({
		url: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'data_over_time_json',
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
					width: "75%",
					height: "75%"
				},
				backgroundColor: {
					stroke: '#FFFFFF',
					strokeWidth: 0
				},
				hAxis: {
					slantedText: true
				},
				width: $("#" + target_div).width(),
				height: ($("#" + target_div).width()/1.68).toFixed(0),
				target_div: target_div
			};
			var chart = new google.visualization.AreaChart(document.getElementById(target_div));
			chart.draw(data, options);
			trackerc.push({chart_obj: chart, chart_data: data, chart_options: options});
			$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
		}
	});
}

function message_email_report_table(type, target_div) {

	console.log('type:' + type + ' target_div:' + target_div);

	$("#" + target_div + "_loading").html(loading_str);
	var request = $.ajax({
		url: $("#s_program").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'message_email_report_table',
			mid: $('#tracker_message_id').val(),
			type: type
		},
		dataType: "html"
	});
	request.done(function(content) {

		$("#" + target_div).hide();
		$("#" + target_div).html(content);
		$("#" + target_div).show('fade');

		$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
		//  $("#sortable_table_" + type).tablesorter();
	});
}

function tracker_message_email_activity_listing_table(target_div) {
	console.log('target_div:' + target_div);

	$("#" + target_div + "_loading").html(loading_str);
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'message_email_activity_listing_table',
			mid: $('#tracker_message_id').val()
		},
		dataType: "html"
	});
	request.done(function(content) {

		$("#" + target_div).hide();
		$("#" + target_div).html(content);
		$("#" + target_div).show('fade');

		$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
		//$("#sortable_table_" + type).tablesorter();
		if ($('#first_for_message_email_activity_listing_table').length) {
			message_individual_email_activity_table($('#first_for_message_email_activity_listing_table').html(), 'message_individual_email_activity_report_table');
		}


		// alert("This: " + $('#first_for_message_email_activity_listing_table').html());

	});
}

function email_breakdown_chart(type, label, target_div) {

	console.log('type:' + type + ' label: ' + label + ' target_div:' + target_div);

	$("#" + target_div + "_loading").html(loading_str);
	$.ajax({
		url: $("#s_program_url").val(),
		dataType: "json",
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'email_stats_json',
			mid: $('#tracker_message_id').val(),
			type: type,
			label: label
		},
		async: true,
		success: function(jsonData) {
			var data = new google.visualization.DataTable(jsonData);
			var chart = new google.visualization.PieChart(document.getElementById(target_div));
			var options = {
				width: $("#" + target_div).width(),
				height: ($("#" + target_div).width()/1.68).toFixed(0),
				chartArea: {
					left: 20,
					top: 20,
					width: "90%",
					height: "90%"
				},
				pieSliceTextStyle: {
					color: '#FFFFFF'
				},
				colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
				is3D: true
			};
			chart.draw(data, options);
			trackerc.push({chart_obj: chart, chart_data: data, chart_options: options});
			
			$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
		}
	});
}



function tracker_the_basics_piechart(type, label, target_div) {

	console.log('type:' + type + ' label: ' + label + ' target_div:' + target_div);

	$("#" + target_div + "_loading").html(loading_str);
	$.ajax({
		url: $("#s_program_url").val(),
		dataType: "json",
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'the_basics_piechart_json',
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
				pieSliceTextStyle: {
					color: '#FFFFFF'
				},
				colors: ["ffabab", "ffabff", "a1a1f0", "abffff", "abffab", "ffffab"],
				is3D: true, 
				width: $("#" + target_div).width(),
				height: ($("#" + target_div).width()/1.68).toFixed(0),
				target_div: target_div
			};
			
			chart.draw(data, options);
			trackerc.push({chart_obj: chart, chart_data: data, chart_options: options});
			
			$("#" + target_div + "_loading").html('<p>&nbsp;</p>');
			
		}
	});
}



// Plugins/Extensions >> Tracker

function tracker_change_record_view() {

	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'save_view_count_prefs',
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


function tracker_delete_msg_id_data(message_id){
	var confirm_msg = "Are you sure you want to delete data for this mass mailing? ";
	if (confirm(confirm_msg)) {
		var request = $.ajax({
			url: $("#s_program_url").val(),
			type: "POST",
			cache: false,
			data: {
				flavor: 'plugins',
				plugin: 'tracker',
				prm: 'delete_msg_id_data',
				mid: message_id
			},
			dataType: "html"
		});
		request.done(function(content) {
			message_history_html();
		});
	} else {
		alert('Deletion cancelled.');
	}

}


// Plugins/Extensions >> Log Viewer

function view_logs_results() {
	$("#refresh_button").val('Loading....');
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'log_viewer',
			prm: 'ajax_view_logs_results',
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
			url: $("#s_program_url").val(),
			type: "POST",
			cache: false,
			data: {
				flavor: 'plugins',
				plugin: 'log_viewer',
				prm: 'ajax_delete_log',
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





function message_history_html(initial) {

	//console.log('running message_history_html');

    if(initial == 1) { 
		$("#show_table_results").height(480);
	}	
		// put in all info, except the stuff that takes forever to load. 
		var request = $.ajax({
			url: $("#s_program_url").val(),
			type: "POST",
			cache: false,
			data: {
				flavor: 'plugins',
				plugin: 'tracker',
				prm: 'message_history_html',
				page: $("#tracker_page").val(),
				fake: 1
			},
			dataType: "html"
		});
		request.done(function(content) {
			$("#show_table_results").html(content);
		}); 

	
	var target = document.getElementById('show_table_results');	
	var spinner = new Spinner(spinner_opts).spin(target);	
		
	var request = $.ajax({
		url: $("#s_program_url").val(),
		type: "POST",
		cache: false,
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'message_history_html',
			page: $("#tracker_page").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		//$("#show_table_results").fadeTo(200, 0); 
		//$("#show_table_results").fadeTo(200, 1,function() {
			$("#show_table_results").html(content);
					spinner.stop(); 	
		//});
		google.setOnLoadCallback(drawSubscriberHistoryChart());
	});
}

var SubscriberHistoryChart;

function drawSubscriberHistoryChart(initial) {

	//console.log('runnning drawSubscriberHistoryChart');

	if(initial == 1){ 
		$('#subscriber_history_chart').height(480);
	}
	
	var target = document.getElementById('subscriber_history_chart');
	var spinner = new Spinner(spinner_opts).spin(target);
	
	if($("#subscriber_history_type").length) {
		history_type = $("#subscriber_history_type option:selected").val();
	}
	else {
		history_type = 'number';
	}
	var request = $.ajax({
		url: $("#s_program_url").val(),
		data: {
			flavor: 'plugins',
			plugin: 'tracker',
			prm: 'message_history_json',
			page: $("#tracker_page").val(),
			type: history_type
		},
		cache: false,
		dataType: "json",
		async: true,
		success: function(jsonData) {
			spinner.stop(); 
			var data = new google.visualization.DataTable(jsonData);
			var options = {
				chartArea: {
					left: 60,
					top: 20,
					width: "70%",
					height: "70%"
				},
			};
			options['width']  = $('#subscriber_history_chart').width();
			options['height'] = $('#subscriber_history_chart').width();
			$('#subscriber_history_chart').height($('#subscriber_history_chart').width());
					
			var SubscriberHistoryChart = new google.visualization.LineChart(document.getElementById('subscriber_history_chart'));
			//$("#subscriber_history_chart").hide('fade');
			SubscriberHistoryChart.draw(data, options);
			//$("#subscriber_history_chart").show('fade');
			
			window.onresize = function(){
				options['width']  = $('#subscriber_history_chart').width();
				options['height'] = $('#subscriber_history_chart').width();
				$('#subscriber_history_chart').height($('#subscriber_history_chart').width());
				SubscriberHistoryChart.draw(data, options);
			};
		}
	});
}


function tracker_purge_log() {
	var confirm_msg = "Are you sure you want to delete this log? ";
	confirm_msg += "There is no way to undo this deletion.";
	if (confirm(confirm_msg)) {
		var request = $.ajax({
			url: $("#s_program_url").val(),
			type: "POST",
			cache: false,
			data: {
				flavor: 'plugins',
				plugin: 'tracker',
				prm: 'ajax_delete_log'
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

// Plugins/Extensions >> Password Protect Directories

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

function check_newest_version(ver) {
	var check = "http://dadamailproject.com/cgi-bin/support/version.cgi?version=" + ver;
	window.open(check, 'version', 'width=325,height=300,top=20,left=20');
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

	f_params.flavor                  = 'preview_message_receivers';
	f_params.alternative_lists       = alternative_lists;
	f_params.multi_list_send_no_dupe = multi_list_send_no_dupes;

	var responsive_options = {
	  width: '95%',
	  height: '95%',
	  maxWidth: '640px',
	  maxHeight: '480px'
	};
	$.colorbox({
	    href: $("#s_program_url").val(),
		data: f_params,
		opacity: 0.50,
		maxWidth: '640px',
		maxHeight: '480px',
		width: '95%',
		height: '95%'				
	});
	$(window).resize(function(){
	    $.colorbox.resize({
	      width: window.innerWidth > parseInt(responsive_options.maxWidth) ? responsive_options.maxWidth : responsive_options.width,
	      height: window.innerHeight > parseInt(responsive_options.maxHeight) ? responsive_options.maxHeight : responsive_options.height
	    });		
	});

}

var cmmbl = '';
function ChangeMassMailingButtonLabel(first_run) {

	var new_cmmbl = $('.ChangeMassMailingButtonLabel').serialize();
	if(first_run !== 1) {
		if(cmmbl == new_cmmbl){
			return false;
		}
		else {
			cmmbl = new_cmmbl;
		}
	}
	var archive_no_send = 0;
	if ($("#archive_no_send").prop("checked") === true && $("#archive_message").prop("checked") === true) {
		archive_no_send = 1;
	}
	$(".button_toolbar")
		.fadeTo(200, 0)
		.html('<input type="button" class="small button" value="Loading...">')
		.fadeTo(200,1);

	var request = $.ajax({
		url:       $("#s_program_url").val(),
		type:      "POST",
		cache:     false,
		async:     true,
		data: {
			flavor: 'send_email_button_widget',
			draft_role: $("#draft_role").val(),
			archive_no_send: archive_no_send,
		},
		success: function(content) {
			$(".button_toolbar").fadeTo(200, 0, function() {
				$(".button_toolbar").html(content);
				$(".button_toolbar").fadeTo(200, 1);
			});
		},
		error: function(xhr, ajaxOptions, thrownError) {
			console.log('status: ' + xhr.status);
			console.log('thrownError:' + thrownError);
		},
	});


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


});


function attachments_openKCFinder(field) {
    window.KCFinder = {
    	callBack: function(url) {
			var kcfinder_upload_url = escapeRegExp(jQuery("#kcfinder_upload_url").val() + '/');
			var re = new RegExp(kcfinder_upload_url,'g');
			var new_val = url.replace(re, '');
	        jQuery(field).html('<img src="' + jQuery("#SUPPORT_FILES_URL").val() + '/static/images/attachment_icon.gif" />' + new_val);
			jQuery("#" + jQuery(field).attr("data-attachment")).val(new_val);
			jQuery("#" + jQuery(field).attr("data-attachment") + '_remove_button').show();
			window.KCFinder = null;
		}
    };
    window.open(jQuery("#kcfinder_url").val() + '/browse.php?type=files&opener=custom', 'kcfinder_single',
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
	var core5_filemanager_url = jQuery("#core5_filemanager_url").val() + '/index.html';
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




function SetUrl(url, width, height, alt) {
	var core5_filemanager_upload_url = escapeRegExp(jQuery("#core5_filemanager_upload_url").val() + '/');
	    core5_filemanager_upload_url + '/';
		
	
	var re = new RegExp(core5_filemanager_upload_url, 'g');

	var path_wo_url_re = escapeRegExp('/dada_mail_support_files/file_uploads/'); 	
	var re2 = new RegExp(path_wo_url_re, 'g');

	var new_val = url.replace(re, '');
	
	    new_val = new_val.replace(re2, '');
	
	// console.log('new_val: ' + new_val);
	var field = urlobj;

	jQuery(field).html('<img src="' + jQuery("#SUPPORT_FILES_URL").val() + '/static/images/attachment_icon.gif" />' + new_val);
	jQuery("#" + jQuery(field).attr("data-attachment")).val(new_val);
	jQuery("#" + jQuery(field).attr("data-attachment") + '_remove_button').show();
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
