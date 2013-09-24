// if (!window.L) { window.L = function () { console.log(arguments);} } // optional EZ quick logging for debugging


(function( $ ){
	var PLUGIN_NS = 'DadaMail';
    var Plugin = function ( target, options ) 
    { 
        this.$T = $(target); 
        this._init( target, options ); 
		
        /** #### OPTIONS #### */
       this.options= $.extend(
            true,               // deep extend
            {
                DEBUG: false,
				DadaMailURL: "../../../dada/mail.cgi",
				list: undefined,
				targetForm: undefined,
				modal: 1
            },
            options
        );
        
        /** #### PROPERTIES #### */
        // this._testProp = 'testProp!';     // Private property declaration, underscore optional
		
        return this; 
		
    }

    /** #### CONSTANTS #### */
    //Plugin.MY_CONSTANT = 'value';

    /** #### INITIALISER #### */
    Plugin.prototype._init = function ( target, options ) { };

    Plugin.prototype.ControlTheForm = function (targetForm)
    {	
	
			
		/* We're in control, now: */
		$("submit", "#" + targetForm).bind("keypress", function (e) {
		    if (e.keyCode == 13) {
		        return false;
		    }
		});	
		
		
		$("body").on("submit", "#" + targetForm, function(event) {
			
			
			event.preventDefault();
			var fields = {};

			$(targetForm + " :input").each(function() {
				fields[this.name] = this.value;
			}); 
							
			$.ajax({
				url: $("#" + targetForm).attr("action") + '/json/subscribe',
				type: "POST",
				dataType: "jsonp",
				cache: false,
				data: JSON.stringify(
					{ 
						list:  $("#" + targetForm + " :input[name='list']").val(),
						email: $("#" + targetForm + " :input[name='email']").val(),
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
	
	
    Plugin.prototype.Modal = function ()
    {	
		this.options.DadaMailURL = $('#' + this.options.targetForm).attr("action"); // not really used. but... 
		this.ControlTheForm(this.options.targetForm);
	}

    Plugin.prototype.CreateSubscribeForm = function ()
    {
		var thisCopy = this;
		var form_id = 'DM_Subscribe_Form_' + Math.random().toString(36).slice(2); 
		$.ajax({
			url: thisCopy.options.DadaMailURL,
			type: "POST",
			dataType: "html",
			data: {
				flavor: 'subscription_form_html',
				list:    thisCopy.options.list,
				subscription_form_id: form_id
			},
			success: function(data) {
				thisCopy.$T.html(data);	
				//alert(thisCopy.options.Modal);
				if(thisCopy.options.modal == 1) { 
					thisCopy.ControlTheForm(form_id); 	
				}				
			},
			error: function() {
				console.log('something is wrong with, "CreateSubscribeForm"');
			}
		});
       // return this.$T;        // support jQuery chaining
    }
	

    /**
     * EZ Logging/Warning (technically private but saving an '_' is worth it imo)
     */    
    Plugin.prototype.DLOG = function () 
    {
        if (!this.DEBUG) return;
        for (var i in arguments) {
            console.log( PLUGIN_NS + ': ', arguments[i] );    
        }
    }
    Plugin.prototype.DWARN = function () 
    {
        this.DEBUG && console.warn( arguments );    
    }
 
    $.fn[ PLUGIN_NS ] = function( methodOrOptions ) 
    {
        if (!$(this).length) {
            return $(this);
        }
        var instance = $(this).data(PLUGIN_NS);
            
        // CASE: action method (public method on PLUGIN class)        
        if ( instance 
                && methodOrOptions.indexOf('_') != 0 
                && instance[ methodOrOptions ] 
                && typeof( instance[ methodOrOptions ] ) == 'function' ) {
            
            return instance[ methodOrOptions ]( Array.prototype.slice.call( arguments, 1 ) ); 
                
                
        // CASE: argument is options object or empty = initialise            
        } else if ( typeof methodOrOptions === 'object' || ! methodOrOptions ) {

            instance = new Plugin( $(this), methodOrOptions );    // ok to overwrite if this is a re-init
            $(this).data( PLUGIN_NS, instance );
            return $(this);
        
        // CASE: method called before init
        } else if ( !instance ) {
            $.error( 'Plugin must be initialised before using method: ' + methodOrOptions );
        
        // CASE: invalid method
        } else if ( methodOrOptions.indexOf('_') == 0 ) {
            $.error( 'Method ' +  methodOrOptions + ' is private!' );
        } else {
            $.error( 'Method ' +  methodOrOptions + ' does not exist.' );
        }
    };

})(jQuery);
