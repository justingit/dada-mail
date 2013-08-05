$(document).ready(function() {

	// Installer 
	if ($("#install_or_upgrade").length) {
		$("body").on("click", '.installer_changeDisplayStateDivs', function(event) {
			changeDisplayState($(this).attr("data-target"), $(this).attr("data-state"));
		});
	
		$("#install_or_upgrade_form").validate({
			rules: {
				current_dada_files_parent_location: { 
					required: true,
					minlength: 5
				}
			}
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
		$("body").on("click", '.test_user_template', function(event) {
			test_user_template();
		});

		$("body").on("click", '.test_amazon_ses_configuration', function(event) {
			test_amazon_ses_configuration();
		});

		jQuery.validator.addMethod("alphanumericunderscore", function(value, element) {
	    return this.optional(element) || value == value.match(/^[-a-zA-Z0-9_]+$/);
	    }, "Only letters, Numbers and Underscores Allowed.");
		jQuery.validator.addMethod("alphanumeric", function(value, element) {
	    return this.optional(element) || value == value.match(/^[-a-zA-Z0-9]+$/);
	    }, "Only letters and Numbers Allowed.");

		
		$("#installform").validate({
			rules: {
				program_url: { 
					required: true,
					url: true	
				}, 
				support_files_dir_path: { 
					required: true,					
				},
				support_files_dir_url: { 
						required: true,
						url: true	
				},
				dada_root_pass: {
					required: true,
					minlength: 8
				},
				dada_root_pass_again: {
					required: true,
					minlength: 8,
					equalTo: "#dada_root_pass"
				},
				bounce_handler_address: {
					required: false,
					email: true
				},
				template_options_USER_TEMPLATE: {
					required: "#configure_user_template:checked"
				},
				security_ADMIN_FLAVOR_NAME: { 
					required: false, 
					alphanumericunderscore: true
				},
				security_SIGN_IN_FLAVOR_NAME: { 
					required: false, 
					alphanumericunderscore: true
				},
				amazon_ses_AWSAccessKeyId: { 
					required: false, 
				},
				amazon_ses_AWSSecretKey: { 
					required: false, 
				}
			}, 
			messages: {
				dada_root_pass: {
					required: "Please provide a Root Password",
					minlength: "Your password must be at least 8 characters long"
				},
				dada_root_pass_again: {
					required: "Please provide a Root Password",
					minlength: "Your password must be at least 8 characters long",
					equalTo: "Please enter the same Root Password as above"
				}
			}					
		});

		$("body").on('click', "#install_wysiwyg_editors", function(event) {
			installer_checkbox_toggle_option_groups('install_wysiwyg_editors', 'install_wysiwyg_editors_options');
		});
		$("body").on('click', "#configure_amazon_ses", function(event) {
			installer_checkbox_toggle_option_groups('configure_amazon_ses', 'amazon_ses_options'); 
		});

		$("body").on('click', "#configure_profiles", function(event) {
			installer_checkbox_toggle_option_groups('configure_profiles', 'profiles_options');
		});
		$("body").on('click', "#configure_templates", function(event) {
			installer_checkbox_toggle_option_groups('configure_templates', 'template_options');
		});

		$("body").on('click', "#configure_cache", function(event) {
			installer_checkbox_toggle_option_groups('configure_cache', 'cache_options');
		});
		
		
		$("body").on('click', "#configure_security", function(event) {
			installer_checkbox_toggle_option_groups('configure_security', 'security_options'); 
		});

		$("body").on('click', "#configure_mass_mailing", function(event) {
			installer_checkbox_toggle_option_groups('configure_mass_mailing', 'mass_mailing_options');
		});

		installer_dada_root_pass_options();
		installer_toggleSQL_options();
		installer_toggle_dada_files_dirOptions();
	
		installer_checkbox_toggle_option_groups('install_bridge', 'bridge_configuration');  
		installer_checkbox_toggle_option_groups('install_bounce_handler', 'bounce_handler_configuration');  
		installer_checkbox_toggle_option_groups('install_wysiwyg_editors', 'install_wysiwyg_editors_options');
		installer_checkbox_toggle_option_groups('configure_amazon_ses', 'amazon_ses_options'); 
		installer_checkbox_toggle_option_groups('configure_profiles', 'profiles_options');
		installer_checkbox_toggle_option_groups('configure_templates', 'template_options');
		installer_checkbox_toggle_option_groups('configure_security', 'security_options');
		installer_checkbox_toggle_option_groups('configure_mass_mailing', 'mass_mailing_options');
		installer_checkbox_toggle_option_groups('configure_cache', 'cache_options');


		$("#dada_files_help").hide();
		$("#program_url_help").hide();
		$("#root_pass_help").hide();
		$("#support_files_help").hide();
		$("#backend_help").hide();
		$("#plugins_extensions_help").hide();
		$("#bounce_handler_configuration_help").hide();
		$("#additional_bounce_handler_configuration").hide();
		$("#wysiwyg_editor_help").hide();
		$("#test_sql_connection_results").hide();
		$("#test_bounce_handler_pop3_connection_results").hide();
		$("#test_user_template_results").hide(); 
		$("#test_amazon_ses_configuration_results").hide();

	}
	if ($("#installer_install_dada_mail").length) {
		$("body").on("click", '#move_installer_dir', function(event) {
			event.preventDefault();
			installer_move_installer_dir();
		});
	}

}); 

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

	var bounce_handler_USESSL = 0; 
	if($("#bounce_handler_USESSL").prop("checked") === true){ 
		bounce_handler_USESSL = 1; 
	}
	var request = $.ajax({
		url: $("#self_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'cgi_test_pop3_connection',
			bounce_handler_server:    $("#bounce_handler_server").val(),
			bounce_handler_username:  $("#bounce_handler_username").val(),
			bounce_handler_password:  $("#bounce_handler_password").val(),
			bounce_handler_USESSL:    bounce_handler_USESSL,
			bounce_handler_AUTH_MODE: $("#bounce_handler_AUTH_MODE").val()
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
			amazon_ses_AWSSecretKey: $("#amazon_ses_AWSSecretKey").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#" + target_div).html(content);
	});
}

function test_user_template() {
	var target_div = 'test_user_template_results';
	$("#" + target_div).html('<p class="alert">Loading...</p>');
	if ($("#" + target_div).is(':hidden')) {
		$("#" + target_div).show();
	}

	var request = $.ajax({
		url: $("#self_url").val(),
		type: "POST",
		cache: false,
		data: {
			f: 'cgi_test_user_template',
			template_options_USER_TEMPLATE: $("#template_options_USER_TEMPLATE").val()
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#" + target_div).html(content);
	});
}

function installer_checkbox_toggle_option_groups(checkbox_id, target_id){ 
	if ($("#" + checkbox_id).length) {	
		if ($("#" + checkbox_id).prop("checked") === true) {
			if ($('#' + target_id).is(':hidden')) {
				$('#' + target_id).show('blind');
			}
		} else {
			if ($('#' + checkbox_id).is(':visible')) {
				$('#' + target_id).hide('blind');
			}
		}
	}
}

function installer_dada_root_pass_options() {
	if ($("#dada_pass_use_orig").prop("checked") === true) {
		if ($('#dada_root_pass_fields').is(':visible')) {
			$('#dada_root_pass_fields').hide('blind');
		}
	}
	if ($("#dada_pass_use_orig").prop("checked") === false) {
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

	if ($("#dada_files_dir_setup_auto").prop("checked") === true) {
		if ($('#manual_dada_files_dir_setup').is(':visible')) {
			$('#manual_dada_files_dir_setup').hide('blind');
		}
	}
	if ($("#dada_files_dir_setup_manual").prop("checked") === true) {
		if ($('#manual_dada_files_dir_setup').is(':hidden')) {
			$('#manual_dada_files_dir_setup').show('blind');
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