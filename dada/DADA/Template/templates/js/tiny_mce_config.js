
function openKCFinder(field_name, url, type, win) {
    tinyMCE.activeEditor.windowManager.open({
        file: '/kcfinder/browse.php?opener=tinymce&type=' + type,
        title: 'KCFinder',
        width: 700,
        height: 500,
        resizable: "yes",
        inline: true,
        close_previous: "no",
        popup_css: false
    }, {
        window: win,
        input: field_name
    });
    return false;
}


tinyMCE.init({
		file_browser_callback : "openKCFinder",
		theme : "advanced",
		theme_advanced_toolbar_location : "top",
		theme_advanced_toolbar_align : "left",
        mode : "specific_textareas",
        editor_selector : "html_message_body"

});
