$(document).ready(function() {
	if ($("#subscription_form").length) {
		$("#subscription_form").validate({
			debug: false,
			rules: {
				email: {
					required: true,
					email: true
				}
			},
			messages: {
				email: {
					required: "Please type in your email address",
					email:    "Please make sure the email address you have typed is valid."
				}
			}
		});
	}
	
	if ($("#ajax_subscribe_form_demo").length) {
		
		/* We're in control, now: */
		$("body").on("submit", "#ajax_subscribe_form_demo", function(event) {
			event.preventDefault();
		});
		$("submit", "#ajax_subscribe_form_demo").bind("keypress", function (e) {
		    if (e.keyCode == 13) {
		        return false;
		    }
		});
		
		$('body').on('click', '#subscribe_button', function(event) {
			
			var fields = {};
			
			$("#subscriber_fields :input").each(function() {
				fields[this.name] = this.value;
			}); 
							
			$.ajax({
				url: $("#ajax_subscribe_form_demo").attr("action") + '/json/subscribe',
				type: "POST",
				dataType: "jsonp",
				cache: false,
				data: JSON.stringify(
					{ 
						list:  $("#list").val(),
						email: $("#email").val(),
						fields: fields
					 }
				),
			    contentType: "application/json; charset=UTF-8",
				success: function(data) {
					console.log('data:' + JSON.stringify(data)); 
					var html = ''; 
					if(data.status === 0){ 
						$.each(data.errors, function(index, value) {
							console.log(index + ': ' + value);
						});
						$.each(data.error_descriptions, function(index, value) {
							html += value;
						});
					}
					else { 
						html += data.success_message;
					}
										
					$.colorbox({
						html: html,
						maxHeight: 480,
						maxWidth: 649,
						opacity: 0.50
					});
				},
				error: function(xhr, ajaxOptions, thrownError) {
					console.log('status: ' + xhr.status);
					console.log('thrownError:' + thrownError);
					$.colorbox({
						html: '<h1>Apologies,</h1><p>An error occured while processing your request. Please try again in a few minutes.</p>',
						opacity: 0.50
					});
				}
			}); 
		}); 
	} 
	
	
	if ($("#create_new_list").length) {
		
		var nobadcharacters_regex = /(\>|\<|\")/;
		jQuery.validator.addMethod("nobadcharacters", function(value, element) {
 			return this.optional(element) || !(nobadcharacters_regex.test(value));
	    }, "Value cannot contain, &lt;'s, &gt;'s or, &quot;'s.");
		
		var no_weird_characters_regex = /[^a-zA-Z0-9_]/; 
		jQuery.validator.addMethod("no_weird_characters", function(value, element) {
	    return this.optional(element) || !(no_weird_characters_regex.test(value));
	    }, "Value can only contain alpha-numeric characters, and underscores");

		var no_reserved_words_regex = /_screen_cache/; 
		jQuery.validator.addMethod("no_reserved_words", function(value, element) {
	    return this.optional(element) || !(no_reserved_words_regex.test(value));
	    }, "Value cannot contain any reserved words");

		
		
		$("#create_new_list").validate({
			debug: false, 
			rules: {
				list_name: { 
					required: true,
					nobadcharacters: true
				},
				list: { 
					required: true,
					no_weird_characters: true,
					no_reserved_words: true,
					maxlength: 16
				},
				password: {
					required: true,
					minlength: 4
				},
				retype_password: {
					required: true,
					minlength: 4,
					equalTo: "#password"
				},
				list_owner_email: {
					required: true,
					email: true
				},
				info: { 
					required: true			
				},
				privacy_policy: {
					required: true		
				},
				physical_address: { 
					required: true			
				}
			}
		}); 
	
	
	}	
	if ($("#profile_login_registration").length) {
		if ($("#profile_login").length) {
			$("#profile_login").validate({
				debug: false, 
				rules: {
					login_email: { 
						required: true,
						email: true
					},
					login_password: { 
						required: true
					}
				},
				messages: {
					login_email: {
						required: "Please type in your email address",
						email:    "Please make sure the email address you have typed is valid."
					}
				}
			}); 
		}

		if ($("#profile_login").length) {
		
			$("#profile_register").validate({
				debug: false, 
				rules: {
					register_email : { 
						required : true,
						email : true
					},
					register_email_again : { 
						required : true,
						email : true,
						equalTo: "#register_email"
					
					},
					register_password : { 
						required : true
					}
				},
				messages: {
					register_email: {
						required: "Please type in your email address",
						email:    "Please make sure the email address you have typed is valid."
					},
					register_email_again: {
						required: "Please type in your email address",
						email:    "Please make sure the email address you have typed is valid."
					}
				}
			});
		}
	
		if ($("#profile_reset_password").length) {
	
			$("#profile_reset_password").validate({
				debug: false, 
				rules: {
					reset_email: { 
						required: true,
						email: true
					}
				},
				messages: {
					reset_email: {
						required: "Please type in your email address",
						email:    "Please make sure the email address you have typed is valid."
					}
				}
			}); 
		}
	}

});

