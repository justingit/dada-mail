#!/usr/bin/perl 

use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ./t); 

use dada_test_config;


use Test::More qw(no_plan); 

# ------------------------

# Dada Mail Modules: 



BEGIN{ use_ok('DADA::App::BounceHandler::ScoreKeeper'); }
BEGIN{ use_ok('DADA::App::BounceHandler::ScoreKeeper::Db'); }

SKIP: {

eval { require DBI };
     skip "DBI not installed", 1 if $@;     
     use_ok('DADA::App::BounceHandler::ScoreKeeper::baseSQL'); 
}



SKIP: {

eval { require DBI };
     skip "DBI not installed", 1 if $@;     
     use_ok('DADA::App::DBIHandle'); 
}




BEGIN{ use_ok('DADA::App::Error'); }
BEGIN{ use_ok('DADA::App::FormatMessages'); }
BEGIN{ use_ok('DADA::App::GenericDBFile::Backup'); }
BEGIN{ use_ok('DADA::App::GenericDBFile'); }
BEGIN{ use_ok('DADA::App::Guts'); }
BEGIN{ use_ok('DADA::App::Licenses'); }
BEGIN{ use_ok('DADA::App::LogSearch'); }

BEGIN{ use_ok('DADA::App::MassSend'); }

BEGIN{ use_ok('DADA::App::Messages'); }

BEGIN{ use_ok('DADA::App::POP3Tools'); }


BEGIN{ use_ok('DADA::App::ScreenCache'); }
BEGIN{ use_ok('DADA::App::Session'); }

BEGIN{ use_ok('DADA::App::Subscriptions'); }


BEGIN{ use_ok('DADA::Config'); }

BEGIN{ use_ok('DADA::Logging::Clickthrough'); }
BEGIN{ use_ok('DADA::Logging::Clickthrough::Db'); }

BEGIN{ use_ok('DADA::Logging::Usage'); }



BEGIN{ use_ok('DADA::Mail::Send'); }
BEGIN{ use_ok('DADA::Mail::MailOut'); }

SKIP: {
    eval { require DBI;};
     skip "DBI not installed", 1 if $@;
     use_ok('DADA::MailingList::Archives::baseSQL'); 
}



BEGIN{ use_ok('DADA::MailingList::Archives::Db'); }

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

     use_ok('DADA::MailingList::Archives::MySQL'); 
}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

     use_ok('DADA::MailingList::Archives::PostgreSQL'); 
}


BEGIN{ use_ok('DADA::MailingList::Archives'); }
BEGIN{ use_ok('DADA::MailingList::SchedulesDeprecated::MLDb'); }


BEGIN{ use_ok('DADA::MailingList::SchedulesDeprecated'); }


SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

     use_ok('DADA::MailingList::Settings::baseSQL'); 
}



BEGIN{ use_ok('DADA::MailingList::Settings::Db'); }


SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Settings::MySQL'); 

}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Settings::PostgreSQL'); 
}


BEGIN{ use_ok('DADA::MailingList::Settings'); }



SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Subscribers::baseSQL'); 

}


BEGIN{ use_ok('DADA::MailingList::Subscribers::PlainText'); }


SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Subscribers::MySQL'); 

}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Subscribers::PostgreSQL');

}


BEGIN{ use_ok('DADA::MailingList::Subscribers'); }
BEGIN{ use_ok('DADA::MailingList::Subscriber'); }


BEGIN{ use_ok('DADA::MailingList'); }

# well, this may not work, since it's gotta be configured... hmmm
# BEGIN{ use_ok('DADA::Security::AuthenCAPTCHA'); }
# Yeah - I was right. 

BEGIN{ use_ok('DADA::Security::Password'); }
BEGIN{ use_ok('DADA::Security::SimpleAuthStringState'); }


BEGIN{ use_ok('DADA::Template::HTML'); }
BEGIN{ use_ok('DADA::Template::Widgets::Admin_Menu'); }
BEGIN{ use_ok('DADA::Template::Widgets'); }


# CPAN Perl Modules use by Dada Mail


BEGIN{ use_ok('CGI'); }


BEGIN{ use_ok('CGI::Session'); }
BEGIN{ use_ok('CGI::Session::ExpireSessions'); }

BEGIN{ use_ok('Class::Accessor'); }

BEGIN{ use_ok('Date::Format'); }
BEGIN{ use_ok('Digest '); }
BEGIN{ use_ok('Digest::MD5'); }
#BEGIN{ use_ok('Digest::Perl::MD5'); }
BEGIN{ use_ok('Email::Address'); }
BEGIN{ use_ok('Email::Find'); }
BEGIN{ use_ok('Email::Valid'); }
BEGIN{ use_ok('Exporter::Lite'); }
BEGIN{ use_ok('File::Spec'); }


# This is all for the Captcha::reCAPTCHA stuff...
BEGIN{ use_ok('Best') }; 
#BEGIN{ use_ok('Crypt::Rijndael_PP'); 
BEGIN{ use_ok('HTML::Tiny') }; 
#BEGIN{ use_ok('Captcha::reCAPTCHA::MyMailhide');
BEGIN{ use_ok('Captcha::reCAPTCHA') };


SKIP: {
        eval { require GD};

         skip "GD not installed", 1 if $@;
         # can't wrap in BEGIN cause it'll happen before the eval..
         use_ok('GD::SecurityImage;'); 

    }

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;
     # can't wrap in BEGIN cause it'll happen before the eval..
     use_ok('DBI'); 

}  
    


BEGIN{ use_ok('HTML::TextToHTML'); }
BEGIN{ use_ok('HTML::Template'); }
BEGIN{ use_ok('HTML::Template::Expr'); }

# I wish I could subclass this a little nicer: 
BEGIN{ use_ok('HTML::Template::MyExpr'); }

BEGIN{ use_ok('Data::Pageset');}

BEGIN{ use_ok('Data::Google::Visualization::DataTable');}


BEGIN{ use_ok('IO::Stringy'); }



#BEGIN{ use_ok('Bundle::libnet'); }


BEGIN{ use_ok('Email::Address'); }
BEGIN{ use_ok('Mail::Cap'); }
BEGIN{ use_ok('Mail::Field'); }
BEGIN{ use_ok('Mail::Field::AddrList'); }
BEGIN{ use_ok('Mail::Field::Date'); }
BEGIN{ use_ok('Mail::Filter'); }
BEGIN{ use_ok('Mail::Header'); }
BEGIN{ use_ok('Mail::Internet '); }
BEGIN{ use_ok('Mail::Mailer'); }
BEGIN{ use_ok('Mail::Send'); }
BEGIN{ use_ok('Mail::Util'); }
BEGIN{ use_ok('Mail::Verp'); }
BEGIN{ use_ok('MD5'); }

# Both for MIME::EncWords
BEGIN{ use_ok('MIME::Charset'); }
BEGIN{ use_ok('MIME::EncWords'); }


BEGIN{ use_ok('MIME::Type'); }
BEGIN{ use_ok('MIME::Types'); }
BEGIN{ use_ok('MIME::Lite'); }

# Huh! This actually needs LWP - it may fail on a few systems...
BEGIN{ use_ok('MIME::Lite::HTML'); }
# This too: 
BEGIN { use_ok('DADA::App::MyMIMELiteHTML'); }
# Since it relies on the above. 

BEGIN{ use_ok('MIME::Tools'); }
BEGIN{ use_ok('MLDBM'); }
BEGIN{ use_ok('Net::SMTP'); }
BEGIN{ use_ok('Parse::RecDescent'); }
BEGIN{ use_ok('Text::Balanced'); }

BEGIN{ use_ok('Text::CSV'); }
BEGIN{ use_ok('Text::CSV_PP'); }


BEGIN{ use_ok('Text::Tabs'); }
BEGIN{ use_ok('Text::Wrap'); }
BEGIN{ use_ok('Time::Local'); }
BEGIN{ use_ok('URI::Escape'); }

BEGIN{ use_ok('HTML::EntitiesPurePerl'); } # This is my little thingy

BEGIN { use_ok('HTML::Entities::Numbered'); } # a module used for the XML named-instead-of-numbered problem. 


BEGIN { use_ok('version'); } # version is now required for Text::Balanced.



dada_test_config::wipe_out;
