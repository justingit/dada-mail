How to use the example_dada_config.txt

The, "example_dada_config.txt" is an example of a .dada_config file, with many 
of the commonly used items already inside, including setting up Dada Mail
for an SQL backend, setting up Dada Mail for the bounce handler, various plugins and extensions, as well as tweaking the admin control panel left hand menu. 

You'll want to either copy/paste the contents of the, "example_dada_config.txt"
file into your own .dada_config file, OR, copy this file rename it, ".dada_config"

The only two variables you'll most likely have to change are the, $DIR and, 
$PROGRAM_URL variables. 

To use any of the variables after the $DADA_ROOT_PASSWORD variable, be sure to 
"uncut them", by removing the special, "=cut" strings, that are located before 
and after the group of variables. For example, you'll see a few lines to 
override any default list settings for new lists (I've tabbed these out for 
readability): 

	# uncut for changing the default list settings
	=cut

	%LIST_SETUP_INCLUDE = (
		set_smtp_sender              => 1, # For SMTP   
		add_sendmail_f_flag          => 1, # For Sendmail Command
		admin_email                  => 'bounces@example.com',
	);

	=cut

To have these setting take effect, remove the, "=cut" strings, like so: 

	# uncut for changing the default list settings


	%LIST_SETUP_INCLUDE = (
		set_smtp_sender              => 1, # For SMTP   
		add_sendmail_f_flag          => 1, # For Sendmail Command
		admin_email                  => 'bounces@example.com',
	);


And that's all there is to it. 
