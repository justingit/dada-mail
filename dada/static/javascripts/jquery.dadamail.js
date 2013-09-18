(function($) {

	$.fn.DadaMailSubForm = function(options) {

		var opts = $.extend({}, $.fn.DadaMailSubForm.defaults, options);

		debug( this );

		return this.each(function() {
			var $this = $(this);
			var markup = $this.html();
			$.ajax({
				url: opts.DadaMailURL,
				type: "POST",
				dataType: "html",
				data: {
					flavor: 'jquery_plugin_subscription_form',
					list:    opts.list
				},
				success: function(data) {
					$this.html(data);					
				},
				error: function() {
					console.log('something is wrong with, "SubscriptionForm"');
				}
			});
		});
	};
	$.fn.DadaMailSubForm.defaults = {
		DadaMailURL: "../../../dada/mail.cgi"
	};


	function debug($obj) {
		if (window.console && window.console.log) {
			window.console.log("Yadda Yadda");
		}
	};
	
	/* We're in control, now: */
	$("body").on("submit", "#jquery_subscription_form", function(event) {
		event.preventDefault();
	});
	$("submit", "#jquery_subscription_form").bind("keypress", function (e) {
	    if (e.keyCode == 13) {
	        return false;
	    }
	});
})(jQuery);


$(document).ready(function() {


	/* We're in control, now: */
	$("body").on("submit", "#jquery_subscription_form", function(event) {
		event.preventDefault();
	});
	$("submit", "#jquery_subscription_form").bind("keypress", function (e) {
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
			url: $("#jquery_subscription_form").attr("action") + '/json/subscribe',
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
		    contentType: "application/json; charset=utf-8",
			success: function(data) {				
				console.log('data:' + JSON.stringify(data));
				var html = ''; 
				if(data.status === 0){ 
					/* Uh uh.*/
					html += '<h1>Problems with your request:</h1>'; 
					html += '<ul>'; 
					$.each(data.errors, function(index, value) {
						console.log(index + ': ' + value);
					});
					$.each(data.error_descriptions, function(index, value) {
						html += '<li>' + value + '</li>';
					});
					html += '</ul>'; 
				}
				else { 
					html += '<h1>Request Successful!:</h1>'; 
					html += '<p>Your Subscription Request was Successful!</p>'; 
				}
	
				/* html += '<code>' + JSON.stringify(data) + '</code>' */
	
				$.colorbox({
					html: html,
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
}); 

