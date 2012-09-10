<!-- begin js/dada_mail_admin.tmpl -->


$(document).ready(function() {
	
//	$(window).load(function() {
		
		// Membership >> View List	
		if($("#view_list_viewport").length) { 
			view_list_viewport();
		}
		
		// Membership >> user@example.com
		if($("#mailing_list_history").length) { 
			mailing_list_history();
		}
		
		// Membership >> Invite/Add
		if($("#add_screen").length) { 
			$("#add_one").hide(); 
			$("#show_progress").hide(); 
			$("#fileupload").live("submit", function(event) {
				check_status();
			});
		}
		
		// Membership >> Invite
		if($("#list_invite_screen").length){ 
			$("#customize_invite_message_form").hide(); 
			$('.show_customize_invite_message').live("click", function(event) { 
				event.preventDefault();
				show_customize_invite_message(); 
			});
		}
		// Mail Sending >> Sending Preferences 
		if($("#sending_preferences").length) { 
			if($("#has_needed_cpan_modules").length){ 
				event.preventDefault();
				amazon_ses_get_stats();
			}
		}
		
		// Mail Sending >> Mass Mailing Preferences 
		if($("#mass_mailing_preferences").length){ 
			if($("#amazon_ses_get_stats").length) { 
				amazon_ses_get_stats(); 
			}
			else { 
				// amazon_ses_get_stats does a previewBatchSendingSpeed(), 
				// so no need to do it, twice. 
				previewBatchSendingSpeed();
			}
			toggleManualBatchSettings(); 
		}
	
//	}); 


	
	// Membership >> View List
	$(".change_type").live("click", function(event){
		change_type($(this).attr("data-type"));
		event.preventDefault();
	});
	$(".turn_page").live("click", function(event){
		turn_page($(this).attr("data-page"));
		event.preventDefault();
	});
	$(".change_order").live("click", function(event){
		change_order($(this).attr("data-by"), $(this).attr("data-dir"));
		event.preventDefault();
	});
	$(".search_list").live("click", function(event){			
		search_list();
		event.preventDefault();
	});
	$("#search_form").live("submit", function(event) {
    	search_list();
		event.preventDefault();
	});
	$(".clear_search").live("click", function(event){
		clear_search();
		event.preventDefault();
	});
	$('#search_query').live('keydown', function(){	
		$( "#search_query" ).autocomplete({
			source: function( request, response ) {
				$.ajax({
					url: "<!-- tmpl_var S_PROGRAM_URL -->",
					type: "POST",
					dataType: "json",
					data: {
						f: 'search_list_auto_complete',
						length: 10,
						type: $("#type").val(),
						query: request.term
					},
					success: function( data ) {
						response( $.map( data, function( item ) {
							return {
								value: item.email,
							}
						}));
					},
					error: function(){ 
						alert('something is wrong');
					},
				});
			},
			minLength: 3,
			open: function() {
				$( this ).removeClass( "ui-corner-all" ).addClass( "ui-corner-top" );
			},
			close: function() {
				$( this ).removeClass( "ui-corner-top" ).addClass( "ui-corner-all" );
			}
		});
	});
	

	
	
	
	// Membership >> user@example.com
	$(".change_profile_password").live("click", function(event){
		show_change_profile_password_form();
		event.preventDefault();
	});
	
	// Mail Sending >> Sending Preferences 
    $(".test_sending_preferences").live("click", function(event){ 
		event.preventDefault();
		test_sending_preferences();
	});

    $(".amazon_verify_email").live("click", function(event){ 
		event.preventDefault();
		amazon_verify_email();
	});
	
	
	
	// Mail Sending >> Mass Mailing Preferences 
	$(".previewBatchSendingSpeed").live("change", function(event){ 
		previewBatchSendingSpeed();
	});

	$("#amazon_ses_auto_batch_settings").live("click", function(event){ 
		toggleManualBatchSettings();
	});
	
	

	/* Global */ 
	$(".fade_me").live("click", function(event){
		$('#alertbox').effect( 'fade' );
		event.preventDefault();
	});

	$('.toggleCheckboxes').live("click", function(event){	
		toggleCheckboxes(
			$(this).prop("checked"), 
			$(this).attr("data-target_class")
		);
	});
	
	$('.toggleDivs').live("click", function(event){ 
		toggleDisplay($(this).attr("data-target")); 
		event.preventDefault();
	}); 
	
	$( "#dialog-modal" ).dialog({				
		autoOpen: false,
		width: 640,
		minHeight: 0,
		modal: true,
		position: "top",
		show: "blind",
		hide: "blind",
		title: "Loading...",
		draggable: false,
		open: function(){
	            jQuery('.ui-widget-overlay').bind('click',function(){
	                jQuery('#dialog-modal').dialog('close');
	            })
	        }
	});


});

// Membership >> Invite/Add
var interval_id; // Global. Blech.
function check_status(){ 
		interval_id = setInterval("update_status_bar();",'5000');
		$("#show_progress").show(); 
}
function update_status_bar(){ 
	var request = $.ajax({
		url: "<!-- tmpl_var S_PROGRAM_URL -->",
		type: "GET",
			data: {
				f : 'check_status',
				new_email_file: $('#new_email_file').val(),
				rand_string: $('#rand_string').val()
			},
		dataType: "json",
		success: function( data ) {
			//console.log('data.percent:"' + data.percent +  '"'); 
			 //$.each(data, function(key, val) {
			//		console.log(key + ' => ' + val); 
			//});
			if(data.percent > 0) { 
				$("#progressbar").progressbar({ value: data.percent});
				$('#upload_status').html('<p>Uploading File: ' + data.percent + '%</p>');
				if(data.percent == 100) { 
					clearInterval(interval_id); 
					check = 0;
					$('#upload_status').html('<p>Upload Complete! Processing...</p>');
				}
			//console.log('done?'); 
		}
	},				
		error: function (xhr, ajaxOptions, thrownError) {
       	 console.log('status: ' + xhr.status);
	     console.log('thrownError:' + thrownError);
      	}

	});
}



/* Membership >> View List */
function view_list_viewport(){ 	
	$("#view_list_viewport_loading").html( '<p class="alert">Loading...</p>' );
	var request = $.ajax({
	  url: "<!-- tmpl_var S_PROGRAM_URL -->",
	  type: "POST",
	  cache: false,
	  data: {
		f:         'view_list',
		mode:      'viewport', 
		type:      $("#type").val(),
		page:      $("#page").val(),
		query:     $("#query").val(),
		order_by:  $("#order_by").val(),
		order_dir: $("#order_dir").val()
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $("#view_list_viewport").html( content );
	  $("#view_list_viewport_loading").html( '<p class="alert">&nbsp;</p>' );
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
function search_list(){ 
	$("#page").val(1); 
	$("#query").val($("#search_query").val()); 
	view_list_viewport();
}
function clear_search(){ 
	$("#query").val(''); 
	$("#page").val(1); 
	view_list_viewport(); 
}
function change_order(order_by, order_dir) { 
	$("#order_by").val(order_by); 
	$("#order_dir").val(order_dir); 
	$("#page").val(1); 
	view_list_viewport();	 
}




// Membership >> user@example.com
function mailing_list_history(){ 
	$("#mailing_list_history_loading").html( '<p class="alert">Loading...</p>' );
	var request = $.ajax({
		url: "<!-- tmpl_var S_PROGRAM_URL -->",
		type: "POST",
		cache: false,
		data: {
			f:       'mailing_list_history',
			email:   '<!-- tmpl_var email -->'
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#mailing_list_history").html( content );
		$("#mailing_list_history_loading").html( '<p class="alert">&nbsp;</p>' );
		$("#mailing_list_history" ).show( 'blind' );
	});
}
function updateEmail(){ 
	var is_for_all_lists = 0; 
	if(
		$('#for_all_mailing_lists').val() == 1 && 
		$("#for_all_mailing_lists").prop("checked") == true
	) { 
		is_for_all_lists = 1;
	}
	$("#update_email_results_loading").html( '<p class="alert">Loading...</p>' );
	var request = $.ajax({
		url: "<!-- tmpl_var S_PROGRAM_URL -->",
		type: "POST",
		cache: false,
		data: {
				f: 'update_email_results',
				updated_email: $("#updated_email").val(),
				email:         $("#original_email").val(),
				for_all_lists: is_for_all_lists
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#update_email_results").html( content );
		$("#update_email_results_loading").html( '<p class="alert">&nbsp;</p>' );
		$("#update_email_results" ).show( 'blind' );
	});
}
function show_change_profile_password_form(){
	$("#change_profile_password_button" ).hide( 'blind' );
	$("#change_profile_password_form" ).show( 'blind' );
}

// Membership >> Invite 
function show_customize_invite_message(){ 
	$('#customize_invite_message_button').hide('blind');
	$('#customize_invite_message_form').show('blind');	
}



// Mailing Sending >> Sending Preferences
function test_sending_preferences(){ 	
	modalMenuAjax(
		{
		 url: "<!-- tmpl_var S_PROGRAM_URL -->",
		  type: "POST",
		  cache: false,
		  data: {
				f:                         'sending_preferences_test',
				add_sendmail_f_flag:       $('#add_sendmail_f_flag').val(), 
				smtp_server:               $('#smtp_server').val(), 
				smtp_port:                 $('#smtp_port').val(),
				use_smtp_ssl:              $('#use_smtp_ssl').val(),			
				use_sasl_smtp_auth:        $('#use_sasl_smtp_auth').val(), 
				sasl_auth_mechanism:       $('#sasl_auth_mechanism').val(), 
				sasl_smtp_username:        $('#sasl_smtp_username').val(), 
				sasl_smtp_password:        $('#sasl_smtp_password').val(), 
				use_pop_before_smtp:       $('#use_pop_before_smtp').val(), 
				pop3_server:               $('#pop3_server').val(), 
				pop3_username:             $('#pop3_username').val(), 
				pop3_password:             $('#pop3_password').val(), 
				pop3_use_ssl:              $('#pop3_use_ssl').val(), 
				set_smtp_sender:           $('#set_smtp_sender').val(),
				process:                   $('#process').val(),
				sending_method:             $('input[name=sending_method]:checked').val()
			},
			dataType: 'html', 
		}
	); 
}
function amazon_verify_email() { 
	$("#amazon_ses_verify_email_results").hide('blind');
	$("#amazon_ses_verify_email_loading").html( '<p class="alert">Loading...</p>' );
	var request = $.ajax({
	  url: "<!-- tmpl_var S_PROGRAM_URL -->",
	  type: "POST",
	  cache: false,
	  data: {
			f: 'amazon_ses_verify_email',
			amazon_ses_verify_email: $("#amazon_ses_verify_email").val()
	  },
	  dataType: "html"
	});
	request.done(function(content) {
	  $("#amazon_ses_verify_email_results").html( content ).show('blind');
	  $("#amazon_ses_verify_email_loading").html( '<p class="alert">&nbsp;</p>' );
	});
}


// Mail Sending >> Mass Mailing Preferences 
function previewBatchSendingSpeed(){ 
	$("#previewBatchSendingSpeed").hide();
	$("#previewBatchSendingSpeed_loading").show().html( '<p class="alert">Loading...</p>' );
	
	var enable_bulk_batching = 0; 
	if($('#enable_bulk_batching').prop('checked') == true){ 
		enable_bulk_batching = 1; 
	}
	var amazon_ses_auto_batch_settings = 0; 
	if($("#amazon_ses_get_stats").length) { 	
		if($('#amazon_ses_auto_batch_settings').prop('checked') == true){ 
			amazon_ses_auto_batch_settings = 1; 
		}
	}
	
	var request = $.ajax({
		url: "<!-- tmpl_var S_PROGRAM_URL -->",
		type: "POST",
		cache: false,
		data: {
			f:                              'previewBatchSendingSpeed', 
			enable_bulk_batching:           enable_bulk_batching,
			mass_send_amount:               $('#mass_send_amount').val(), 
			bulk_sleep_amount:              $('#bulk_sleep_amount').val(),
			amazon_ses_auto_batch_settings: amazon_ses_auto_batch_settings
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#previewBatchSendingSpeed_loading").hide();
		$("#previewBatchSendingSpeed").html( content ).show( 'blind' );
	});
}

function amazon_ses_get_stats(){ 
	$("#amazon_ses_get_stats_loading").html( '<p class="alert">Loading...</p>' );
	
	var request = $.ajax({
		url: "<!-- tmpl_var S_PROGRAM_URL -->",
		type: "POST",
		cache: false,
		data: {
			f:                    'amazon_ses_get_stats', 
		},
		dataType: "html"
	});
	request.done(function(content) {
		$("#amazon_ses_get_stats").html( content );
		$("#amazon_ses_get_stats_loading").html( '<p class="alert">&nbsp;</p>' );
		$("#amazon_ses_get_stats" ).show( 'blind' );
	});
}
function toggleManualBatchSettings() { 
	if($("#amazon_ses_auto_batch_settings").prop("checked") == true){ 
		$("#manual_batch_settings" ).hide( 'blind' );
	}
	else { 
		if( $('#manual_batch_settings').is(":hidden") ) {
			$("#manual_batch_settings" ).show( 'blind' );
		}
	}
	previewBatchSendingSpeed(); 
}







/* Global */
function toggleCheckboxes(status, target_class) {
	$('.' + target_class).each( function() {
		$(this).prop("checked",status);
	});
}

function toggleDisplay(target) {
	$('#' + target).toggle('blind');
}
function modalMenuAjax(params) { 
	$("#dialog-modal").html('').dialog('open');
	var request = $.ajax({
	 	 url: params.url,
		 type:  params.type,
		 cache: params.cache,
		 data:  params.data,
		 dataType: params.dataType,
		 error: function(){ 
			alert('something is wrong');
		},
		success: function(data) { 
			$('#dialog-modal').dialog('close');
			$("#dialog-modal").html(data);	
		},
		complete: function(data) {
		    $("#dialog-modal").dialog({ title: "Results" });
			$("#dialog-modal").dialog('open');
		},
	});
}














var refreshLocation = ''; 

function preview() {
	var new_window = window.open("", "preview", "top=100,left=100,resizable,scrollbars,width=400,height=200");
}

function SetChecked(val) {

	dml=document.email_form;
	len = dml.elements.length;
	var i = 0;
	for( i = 0; i < len; i++) {
		if (dml.elements[i].name=='address') {
			dml.elements[i].checked=val;
		}
	}
}

function SetListChecked(val) {

	dml=document.send_email;
	len = dml.elements.length;
	var i=0;
	for( i=0 ; i < len ; i++) {
		if (dml.elements[i].name=='alternative_list') {
			dml.elements[i].checked=val;
		}
	}
}

function set_to_default() {
	
	document.the_form.target="_self"; 
	default_template = document.the_form.default_template.value;
	document.the_form.template_info.value = default_template;
}


function list_message_status(thing) {
	document.the_form.process.value = thing;
}


function preview_template() {

	document.the_form.target="_blank";
	document.the_form.process.value="preview template";

}

function change_template() {

	document.the_form.target="_self";
	document.the_form.process.value="true";
}

function check_newest_version() {

	var check = "http://dadamailproject.com/cgi-bin/support/version.cgi?version=<!-- tmpl_var VER ESCAPE=URL -->";
	window.open(check, 'version', 'width=325,height=300,top=20,left=20');
}

function add_delete_list() {

	var address_list = document.the_form.delete_list.value;
	var Address =      document.the_form.email_list.selectedIndex;
	var new_address =  document.the_form.email_list.options[Address].value;
	var append_list =  address_list+"\\n"+new_address;
	document.the_form.delete_list.value = append_list;

}

function just_test_message() {

	document.the_form.process.value="just_test_message";

}


function real_message() {

	document.the_form.process.value="true";

}






function toggleTwo(targetOpen, targetClose) { 
	Effect.BlindUp($(targetClose));
	Effect.BlindDown($(targetOpen));	
}



function ChangeMassMailingButtonLabel() { 
	if(Form.Element.getValue('archive_message') == 1 && $('archive_no_send').checked == true){ 
		Form.Element.setValue('submit_mass_mailing', 'Archive Message');
		$('submit_test_mailing').hide();	
		$('send_test_messages_to').hide();
	}
	else { 
		Form.Element.setValue('submit_mass_mailing', $F('default_mass_mailing_button_label'));
		$('submit_test_mailing').show();
		$('send_test_messages_to').show();
			
	}	
}

    
function sendMailingListMessage(form_name, testornot) {
		
	/* This is for the Send a Webpage - did they fill in a URL? */
	if(form_name.f.value == 'send_url_email'){ 
		for (var i=0; i < form_name.content_from.length; i++) {
			if (form_name.content_from[i].checked == true) {
				if(form_name.content_from[i].value == 'url'){ 
					if((form_name.url.value == 'http://') || (form_name.url.length <= 0)){ 
						alert('You have not filled in a URL! Mass Mailing Stopped.'); 
						return false;
					}
				}
			}
		}
	}	
	
	var itsatest; 
	testornot ? itsatest = "*test*" : itsatest = "";
	
	var confirm_msg =  "Are you sure you want this ";
	    confirm_msg +=  itsatest;
	    confirm_msg += " mailing to be sent?";
	    confirm_msg += " Mailing list sending cannot be easily stopped.";
	
	if(!form_name.Subject.value){ 
	    var no_subject_msg = "The Subject: header of this message has been left blank. Send anyways?"; 
	    if(!confirm(no_subject_msg)){
			alert('Mailing safely aborted.');
			return false;
		}
	}
	
	if(!form_name.im_sure.checked){
		if(!confirm(confirm_msg)){
			alert('Mailing safely aborted.');
			return false;
		}
	}
	
	form_name.new_win.checked ? form_name.target = "_blank" : form_name.target = "_self";

}





function warnAboutMassSubscription(form_name) { 
	
	var confirm_msg =  "Are you sure you want to subscribe the selected email address(es) to your list? ";
    confirm_msg += "\n\n";

    confirm_msg += "Subscription of unconfirmed email address(es) should always be avoided. ";
    confirm_msg += "\n\n";

    confirm_msg += " If wanting to add unconfirmed email address(es), use the \"Send Invitation... >>\"";	
    confirm_msg += " option to allow the subscriber to confirm their own subscription.";	
	

	if(!confirm(confirm_msg)){
		alert('Subscription Stopped.');
		return false;
	}
	
	/* Do I still need this? */
	form_name.target = "_self";
}


function unsubscribeAllSubscribers(form_name, type) { 
    
	var confirm_msg = '';
	if(type == 'Subscribers'){ 
		confirm_msg = "Are you sure you want to unsubscribe all Subscribers? ";	
	}
	else { 
		confirm_msg = "Are you sure you want to remove all " + type + "?";			
	}
	
	if(!confirm(confirm_msg)){
		if(type == 'Subscribers'){ 	
			alert("Subscribers not unsubscribed.");        	
        }
		else { 
			alert("'" + type + "' not removed.");
        	
		}
		return false;
    }
	else { 
		return true; 
	}
    
}

function removeAllArchives(form_name) { 
    
    var confirm_msg =  "Are you sure you want to purge all your mailing list archives?";	
    if(!confirm(confirm_msg)){
        alert("Archives not purged.");
        return false;
    }
	else { 
		return true; 
	}
    
}

function revertEditType(form_name) { 
    
    var confirm_msg =  "Are you sure you want to revert to the default for ALL email messages?";	
    if(!confirm(confirm_msg)){
        alert("Messages not reverted to default.");
        return false;
    }
	else { 
		return true; 
	}
    
}






function killMonitoredSending(form_name) { 
    
    var confirm_msg =  "Are you sure you want to STOP this mass mailing? ";
	    confirm_msg += " Once this mailing has been stopped, it cannot be restarted.";
	
    if(!confirm(confirm_msg)){
        alert('Mailing saved from killing');
        return false;
    }
    
}

function pauseMonitoredSending(form_name) { 
    
    var confirm_msg =  "Are you sure you want to PAUSE this mailing? ";
	    confirm_msg += " Email sending will be stopped immediately after this current batch has completed. Email sending may be resumed at any time.";
	
    if(!confirm(confirm_msg)){
        alert('Mailing was not paused.');
        return false;
    }
    
}

var refreshTimerId = 0;
var refreshLoc     = ''; 
var refreshTime    = ''; 
function refreshpage(sec, url){ 

    var refreshAfter = sec/1 * 1000; 
		refreshTime = refreshAfter/1000; 
		
   if(url){ 
    	
    	refreshLocation = url; 
		refreshLoc      = refreshLocation;  
    	refreshTimerId = setInterval("doRefresh(refreshLocation);",refreshAfter);

    }

}

function doRefresh(loc) { 

	window.location.replace(loc); 

}

function updateRefresh(){ 

	if(document.refresh_control.refresh_on.checked){ 
		refreshpage(refreshTime, refreshLoc); 
	}
	else {
		clearInterval(refreshTimerId); 
	}

}

function removeSubscriberField(form_name) {
		
	var confirm_msg =  "Are you sure you want to ";
	    confirm_msg += " permanently remove this field?";
	    confirm_msg += " All saved informaton in the field for all subscribers will be lost.";

    if(!confirm(confirm_msg)){
        alert('Subscriber field removal has been canceled.');
        return false;
    }

    form_name.target = "_self";
    
}
<!-- end js/dada_mail_admin.tmpl -->