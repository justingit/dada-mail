Dada Mail TAP Tests

This directory holds TAP-compatible tests for Dada Mail. They're run using the, 
"prove" command, like so: 

(cd into the, "dada" directory) 

 prompt>prove -r

The Dada Mail testing suite is constantly evolving. Currently, there is no 
automated testing done before installation, because there's no automated 
installation of Dada Mail! But, running the prove command should do what you 
think it should do. 

If you do not want this directory, you may remove it, without impacting Dada 
Mail's behavior.  

You may, at your leisure, run these tests manually, using the, "prove"
command before an installation. Doing so does not require you to first 
configure Dada Mail (a rational and temporary configuration environment 
will automatically be created). You may also run these tests with a Dada Mail
that has already been configured without fear that your current installation 
will be impacted. 

Dada Mail has the ability to use various backends, by default, the PlainText/Db
and SQLite (if available) backends are tested, but you may also test the MySQL 
and Postgres backend. 

To do so, change the configurations set in the, "__Test_Config_Vars.pm" file 
in this directory. You may also need to tweak the SQL settings. You do not 
need to create the tables needed, but do make sure the, "extras/SQL" directory
and its contents have not been removed. 

SEE ALSO:

http://search.cpan.org/~andya/Test-Harness/bin/prove

http://search.cpan.org/~mschwern/Test-Simple/lib/Test/More.pm

http://testanything.org/wiki/index.php/Main_Page
