(function( $ ) {
  "use strict";
 
  $(function() {

  	if ($("#list_unsubscribe").length) {
		if(
			$("#one_click_unsubscribe").val() != 1 
		 || $("#auto_attempted").val() == 1){
			 // ... 
		}
		else {
			
			$("#unsubscription_form").hide();
			$("#automatic_attempt_message").show();
			
			// sometimes, this takes a little while... 
			var request = $.ajax({
				url: $("#program_url").val(),
				type: "POST",
				dataType: "json",
				cache: false,
				data: { 
					flavor: 'unsubscribe_email_lookup',
					token: $('#token').val()
				},
				success: function(data) {
					if(data.status === 1 && data.email.length > 0){ 
						var url = $("#program_url").val() 
							+ "?flavor=unsubscribe&token="
							+ encodeURIComponent($('#token').val())
							+ "&email="
							+ encodeURIComponent(data.email)
							+ '&process=1'
							+ "&auto_attempted=1";
							
							window.location.href = url; 
							// window.location.replace(url); 
					}
					else { 
						$("#unsubscription_form").show();
						$("#automatic_attempt_message").hide();
					}
				},
				error: function(xhr, ajaxOptions, thrownError) {
					console.log('status: ' + xhr.status);
					console.log('thrownError:' + thrownError);					
					/* Well, if there's an error in the look, let us do this: */
					$("#unsubscription_form").show();
					$("#automatic_attempt_message").hide();
					
				},
			});
		}
	}


	if ($("#subscription_form").length) {
		
		$("#subscription_form").validate({
		   ignore: ".ignore",
			debug: false,
			rules: {
				email: {
					required: true,
					email: true
				},
				"captcha_check": {
				     required: function() {
						 // is this field even there? 
						 if($('#captcha_check').length <= 0){ 
							 return false; 
						 }
						 else {
							 // I don't necessarily like explicitly naming the field here, 
							 // so this may change in the future. 
							 alert('$("#subscription_form_gr").attr("recaptcha_id"): ' + $("#subscription_form_gr").attr("data-recaptcha_id"));
							 if (grecaptcha.getResponse($("#subscription_form_gr").attr("data-recaptcha_id")) == '') {
								 return true;
					         } else {
					             return false;
					         }
							
						 }
				     }
				}
			},
			messages: {
				email: {
					required: "Please type in your email address",
					email:    "Please make sure the email address you have typed is valid."
				},
				captcha_check: { 
					required: "Please solve the CAPTCHA",
				}
			}
		});
	}
	
	if ($("#unsubscription_form").length) {
				
		$("#unsubscription_form").validate({
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
	
	
	if($("#modal_subscribe_form").length) { 
		$('#modal_subscribe_form').DadaMail({targetForm: 'subscription_form', mode: 'jsonp'});
		$('#modal_subscribe_form').DadaMail('Modal');
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
		
		$("#tabs").tabs(
			{ 
			heightStyle: "auto"
		}
	);
		
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

	if ($("#membership_profile_fields").length) {
		$("#membership_profile_fields").validate(); 
	}
	
	if ($("#profile_home").length) {
		/* the beforeLoad stops the tabs from loading a url via ajax,
		   which happens if the screen has a base href tag */
		
		$("#tabs").tabs(
			{ 
				heightStyle: "auto",
				beforeLoad: function(event, ui) {
			        // if the target panel is empty, return true
			        return ui.panel.html() == "";
			    }
			    
			}
		);
	}
	
  });
 
}(jQuery));


