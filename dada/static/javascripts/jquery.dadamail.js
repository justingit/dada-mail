// if (!window.L) { window.L = function () { console.log(arguments);} } // optional EZ quick logging for debugging


(function( $ ){
	var PLUGIN_NS = 'DadaMail';
    var Plugin = function ( target, options ) 
    { 
        this.$T = $(target); 
        this._init( target, options ); 
		
        /** #### OPTIONS #### */
       this.options = $.extend(
            true,               // deep extend
            {
                DEBUG: false,
				DadaMailURL: "../../../dada/mail.cgi",
				list: undefined,
				targetForm: undefined,
				modal: 1,
				mode: 'jsonp',
				LoadingMessage: '<h1>Sending Over Request...</h1><p>One second as we look over what you\'ve given us...</p>',
				LoadingError:   '<h1>Apologies,</h1><p>An error occurred while processing your request. Please try again in a few minutes.</p>'
				
			},
            options
        );
        
        /** #### PROPERTIES #### */
         this._testProp = 'testProp!';     // Private property declaration, underscore optional
		
		 this._DadaMailURL     = this.options.DadaMailURL; 
		 this._list            = this.options.list; 
		 this._targetForm      = this.options.targetForm; 
		 this._modal           = this.options.modal; 
		 this._LoadingMessage  = this.options.LoadingMessage; 
		 this._mode            = this.options.mode; 
		 this._LoadingError    = this.options.LoadingError; 
        
		return this; 
		
    }

    /** #### CONSTANTS #### */
    //Plugin.MY_CONSTANT = 'value';

    /** #### INITIALISER #### */
    Plugin.prototype._init = function ( target, options ) { };

	// targetForm, loadingMsg
    Plugin.prototype.ControlTheForm = function ()
    {	
	
		/* I do not know why this is needed */
		var copythis = this;
		
		
		/* We're in control, now: */
		$("submit", "#" + copythis._targetForm).bind("keypress", function (e) {
		    if (e.keyCode == 13) {
		        return false;
		    }
		});	
		
		
		$("body").on("submit", "#" + copythis._targetForm, function(event) {
			
			
			event.preventDefault();
					
			$.colorbox({
				html: copythis._loadingMsg,
				maxHeight: 480,
				maxWidth: 649,
				opacity: 0.50
			}); 
			
			var using_datatype     = 'json';
			var using_content_type = 'POST'; 
			var using_data; 
						
			if(copythis._mode == 'jsonp') { 
				using_datatype = 'jsonp'; 
				using_content_type = 'GET';
				
				using_data = {
					_method: "GET",  
					list:  $("#" + copythis._targetForm + " :input[name='list']").val(),
					email: $("#" + copythis._targetForm + " :input[name='email']").val(),
				};
				
				$("#" + copythis._targetForm + " :input").each(function() {
					if(this.name != 'list' && this.name != 'email' && this.name != 'f') { 
						using_data[this.name] = this.value;
					}
				}); 
			}
			else if(copythis._mode == 'json') { 

				var fields = {};
				$("#" + copythis._targetForm + " :input").each(function() {
					if(this.name != 'list' && this.name != 'email' && this.name != 'f') { 
						fields[this.name] = this.value;
					}
				}); 
								
				using_data = JSON.stringify(
					using_data = {
						list:  $("#" + copythis._targetForm + " :input[name='list']").val(),
						email: $("#" + copythis._targetForm + " :input[name='email']").val(),
						fields: fields
					}
				);
				
			} 
			else { 
				console.log('unknown mode: ' + copythis._mode); 
			}
			
						
			$.ajax({
				url: $("#" + copythis._targetForm).attr("action") + '/json/subscribe',
				type: using_content_type,
				dataType: using_datatype,
				cache: false,
				data: using_data, 
			    contentType: "application/json; charset=UTF-8",
				success: function(data) {
					console.log('data:' + JSON.stringify(data)); 
					var html = ''; 
					if(data.status === 0){
						console.log('Errors: ' + JSON.stringify(data.errors)); 
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
						html: copythis._LoadingError,
						opacity: 0.50
					});
				}
			}); 

		});		
	}
	
	
    Plugin.prototype.Modal = function ()
    {	
		this._DadaMailURL = $('#' + this.options.targetForm).attr("action"); // not really used. but... 
		this.ControlTheForm(); //this.options.targetForm, this.options.LoadingMessage
	}

    Plugin.prototype.CreateSubscribeForm = function ()
    {
		var copythis = this;
		
		var form_id = 'DM_Subscribe_Form_' + Math.random().toString(36).slice(2); 
		$.ajax({
			url: copythis._DadaMailURL,
			type: "GET",
			dataType: 'jsonp',
			data: {
				_method: 'GET', 
				flavor: 'subscription_form_html',
				list:    copythis._list,
				subscription_form_id: form_id
			},
			success: function(data) {
				
				console.log('data:' + JSON.stringify(data)); 
				
				copythis.$T.html(data.subscription_form);
				copythis._targetForm = form_id; 
				//alert(copythis._modal);
				if(copythis._modal == 1) { 
					copythis.ControlTheForm(); 	
				}				
			},
			error: function(xhr, ajaxOptions, thrownError) {
				console.log('status: ' + xhr.status);
				console.log('thrownError:' + thrownError);
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
