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
					control_the_form('jquery_subscription_form'); 
									
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

	function control_the_form(targetForm) { 
		/* We're in control, now: */
		$("body").on("submit", "#" + targetForm, function(event) {
			event.preventDefault();
		});
		$("submit", "#" + targetForm).bind("keypress", function (e) {
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
				url: $("#" + targetForm).attr("action") + '/json/subscribe',
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
						var already_sent_sub_confirmation = 0; 
												
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
					
					if(typeof data.redirect_required === 'undefined') {
						if(data.redirect.using === 1) {
							if(data.redirect.using_with_query === 1){ 
								window.location.href = data.redirect.url + '?' + data.redirect.query; 
							}
							else { 
								window.location.href = data.redirect.url;
							}
						}
						else { 
							$.colorbox({
								html: html,
								maxHeight: 480,
								maxWidth: 649,
								opacity: 0.50
							}); 
						}
					}
					else { 
						/* Success, or Error: it may not be something we can work with: */
						//alert(data.redirect_required); 
						window.location.href = data.redirect.url;
					}
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

	function debug($obj) {
		if (window.console && window.console.log) {
			/* window.console.log("Yadda Yadda"); */
		}
	};
	
})(jQuery);

