<!-- begin javascripts/dada_mail_admin.tmpl -->

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

function testPOPBeforeSMTP() {

	var use_ssl_value = 0; 
	if(document.default_form.pop3_use_ssl.checked){ 
		use_ssl_value = 1; 
	}
	else{ 
		use_ssl_value = 0; 
	}
	var popcheck = '<!-- tmpl_var name="S_PROGRAM_URL" -->?f=checkpop;user='+document.default_form.pop3_username.value+';pass='+document.default_form.pop3_password.value+';server='+document.default_form.pop3_server.value+';use_ssl='+use_ssl_value+';mode='+document.default_form.pop3_auth_mode.value;
	window.open(popcheck, 'popcheck', 'width=325,height=300,top=20,left=20');

}

 
function toggleDisplay(target) {

	if (document.getElementById){
		var togglin = document.getElementById( target );
		if(togglin.style.display == ""){
			togglin.style.display = "none";
		}else{
			togglin.style.display = "";
		}
	}

}

function sendMailingListMessage(form_name, testornot) {
		
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

    confirm_msg += " If wanting to add unconfirmed email address(es), use the \"Invite Checked Subscribers\"";	
    confirm_msg += " option to allow the subscriber to confirm their own subscription.";	
	

	if(!confirm(confirm_msg)){
		alert('Subscription Stopped.');
		return false;
	}
	
	/* Do I still need this? */
	form_name.target = "_self";
}

function killMonitoredSending(form_name) { 
    
    var confirm_msg =  "Are you sure you want to KILL this mailing? ";
	    confirm_msg += " Once this mailing has been killed, it cannot ever be restarted.";
	
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

function init(){
	/* This even used anymore? */
	return false;
}
 
<!-- end javascripts/dada_mail_admin.tmpl -->