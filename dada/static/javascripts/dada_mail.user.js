$(document).ready(function() {
	if ($("#subscription_form").length) {
		$("#subscription_form").validate({
			debug: true, 
			
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
						required : true,
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

