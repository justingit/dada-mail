#!/usr/bin/perl 

use lib qw(./ ./DADA/perllib ./DADA/App/Support ../ ../DADA/perllib ../../ ../../DADA/perllib ./t); 

use dada_test_config;
dada_test_config::create_SQLite_db(); 


use Test::More qw(no_plan); 

# ------------------------

# Dada Mail Modules: 



BEGIN{ use_ok('DADA::App::BounceHandler::ScoreKeeper'); }

BEGIN{ use_ok('DADA::App::BounceHandler'); }

BEGIN{ use_ok('DADA::App::DataCache'); }

SKIP: {

eval { require DBI };
     skip "DBI not installed", 1 if $@;     
     use_ok('DADA::App::DBIHandle'); 
}



BEGIN{ use_ok('DADA::App::Digests'); }

BEGIN{ use_ok('DADA::App::Dispatch'); }

BEGIN{ use_ok('DADA::App::Error'); }

BEGIN{ use_ok('DADA::App::EmailMessagePreview'); }
BEGIN{ use_ok('DADA::App::EmailThemes'); }



BEGIN{ use_ok('DADA::App::FormatMessages'); }
BEGIN{ use_ok('DADA::App::FormatMessages::Filters::BodyContentOnly'); }


# Not used, since v5
#BEGIN{ use_ok('DADA::App::FormatMessages::Filters::CleanUpReplies'); }

BEGIN{ use_ok('DADA::App::FormatMessages::Filters::CSSInliner'); }
BEGIN{ use_ok('DADA::App::FormatMessages::Filters::HTMLMinifier'); }
BEGIN{ use_ok('DADA::App::FormatMessages::Filters::InjectThemeStylesheet'); }

# This requires HTML::Parser which is XS not PP. There is HTML::Parser::Simple, but I don't know if that'll work for us
# BEGIN{ use_ok('DADA::App::FormatMessages::Filters::InlineEmbeddedImages'); }
BEGIN{ use_ok('DADA::App::FormatMessages::Filters::RemoveTokenLinks'); }
BEGIN{ use_ok('DADA::App::FormatMessages::Filters::UnescapeTemplateTags'); }




BEGIN{ use_ok('DADA::App::GenericDBFile::Backup'); }
BEGIN{ use_ok('DADA::App::GenericDBFile'); }
BEGIN{ use_ok('DADA::App::Guts'); }
BEGIN{ use_ok('DADA::App::Licenses'); }
BEGIN{ use_ok('DADA::App::LogSearch'); }

BEGIN{ use_ok('DADA::App::Markdown'); }


BEGIN{ use_ok('DADA::App::MassSend'); }

BEGIN{ use_ok('DADA::App::Messages'); }

BEGIN{ use_ok('DADA::App::POP3Tools'); }



BEGIN{ use_ok('DADA::App::ScheduledTasks'); }

BEGIN{ use_ok('DADA::App::ScreenCache'); }
BEGIN{ use_ok('DADA::App::Session'); }

BEGIN{ use_ok('DADA::App::Subscriptions'); }
BEGIN{ use_ok('DADA::App::WebServices'); }


BEGIN{ use_ok('DADA::Config'); }

BEGIN{ use_ok('DADA::Logging::Clickthrough'); }

BEGIN{ use_ok('DADA::Logging::Usage'); }



BEGIN{ use_ok('DADA::Mail::Send'); }
BEGIN{ use_ok('DADA::Mail::MailOut'); }



SKIP: {
    eval { require DBI;};
     skip "DBI not installed", 1 if $@;
     use_ok('DADA::MailingList::Archives'); 
}




SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

     use_ok('DADA::MailingList::Archives'); 
}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

     use_ok('DADA::MailingList::Archives'); 
}


BEGIN{ use_ok('DADA::MailingList::Archives'); }


SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

     use_ok('DADA::MailingList::Settings'); 
}




SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Settings'); 

}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Settings'); 
}


BEGIN{ use_ok('DADA::MailingList::Settings'); }



SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Subscribers'); 

}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Subscribers'); 

}

SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;

    use_ok('DADA::MailingList::Subscribers');

}


BEGIN{ use_ok('DADA::MailingList::ConsentActivity'); }
BEGIN{ use_ok('DADA::MailingList::Consents'); }
BEGIN{ use_ok('DADA::MailingList::PrivacyPolicyManager'); }


BEGIN{ use_ok('DADA::MailingList::Subscribers'); }
BEGIN{ use_ok('DADA::MailingList::Subscriber'); }


BEGIN{ use_ok('DADA::MailingList'); }

# well, this may not work, since it's gotta be configured... hmmm
# BEGIN{ use_ok('require DADA::Security::AuthenCAPTCHA::Google_reCAPTCHA;'); }
# Yeah - I was right. 

BEGIN{ use_ok('DADA::Security::Password'); }
BEGIN{ use_ok('DADA::Security::SimpleAuthStringState'); }


BEGIN{ use_ok('DADA::Template::HTML'); }
BEGIN{ use_ok('DADA::Template::Widgets::Admin_Menu'); }
BEGIN{ use_ok('DADA::Template::Widgets'); }


# CPAN Perl Modules use by Dada Mail


BEGIN{ use_ok('CGI'); }

BEGIN{ use_ok('CGI::Application'); }

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
BEGIN{ use_ok('HTML::Tiny') }; 
#BEGIN{ use_ok('Captcha::reCAPTCHA') };



SKIP: {
    eval { require DBI;};

     skip "DBI not installed", 1 if $@;
     # can't wrap in BEGIN cause it'll happen before the eval..
     use_ok('DBI'); 

}  
    


BEGIN{ use_ok('HTML::TextToHTML'); }
BEGIN{ use_ok('HTML::Template'); }
#BEGIN{ use_ok('HTML::Template::Expr'); }

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

# Huh! This actually needs LWP - it may fail on a few systems...
# This too: 
BEGIN { use_ok('DADA::App::HTMLtoMIMEMessage'); }
# Since it relies on the above. 

BEGIN{ use_ok('MIME::Tools'); }
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


dada_test_config::destroy_SQLite_db();
dada_test_config::wipe_out;
