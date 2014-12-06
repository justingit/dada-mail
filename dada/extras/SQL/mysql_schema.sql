CREATE TABLE IF NOT EXISTS dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE INDEX dada_settings_list_index ON dada_settings (list);

CREATE TABLE IF NOT EXISTS dada_subscribers (
email_id                        int4 not null primary key auto_increment,
email                            varchar(80),
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1),
timestamp                       TIMESTAMP DEFAULT NOW()
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE INDEX dada_subscribers_all_index ON dada_subscribers (email(80), list, list_type, list_status);

CREATE TABLE IF NOT EXISTS dada_confirmation_tokens ( 
id INT4 NOT NULL PRIMARY KEY AUTO_INCREMENT,
timestamp TIMESTAMP DEFAULT NOW(),
token varchar(255),
email varchar(80),
data text,
UNIQUE (token)
);


CREATE TABLE IF NOT EXISTS dada_profiles ( 
profile_id int4 not null primary key auto_increment,
email                        varchar(80) not null,
password                     text(16),
auth_code                    varchar(64),
update_email_auth_code       varchar(64),
update_email                 varchar(80),
activated                    char(1), 
CONSTRAINT UNIQUE (email)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_fields (
fields_id int4 not null primary key auto_increment,
email varchar(80) not null,
CONSTRAINT UNIQUE (email)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes (
attribute_id int4 not null primary key auto_increment,
field                       varchar(80),
label                       varchar(80),
fallback_value              text,
required                    char(1) DEFAULT 0 NOT NULL,
-- I haven't made the following, but it seems like a pretty good idea... 
-- sql_col_type              text(16),
-- default                   mediumtext,
-- html_form_widget          varchar(80),
-- public                    char(1),
    CONSTRAINT UNIQUE (field)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_settings (
id int4 not null primary key auto_increment,
email                            varchar(80),
list                             varchar(16),
setting                          varchar(64),
value                            text
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_archives (
list                          varchar(16),
archive_id                    varchar(32),
subject                       text,
message                       mediumtext,
format                        text,
raw_msg                       mediumtext
) CHARACTER SET utf8 COLLATE utf8_bin;
 
CREATE INDEX dada_archives_list_archive_id_index ON dada_archives (list, archive_id);
 
CREATE TABLE IF NOT EXISTS dada_bounce_scores (
id                            int4 not null primary key auto_increment,
email                         text, 
list                          varchar(16),
score                         int4
);

CREATE TABLE IF NOT EXISTS dada_sessions (
     id CHAR(32) NOT NULL PRIMARY KEY,
     a_session TEXT NOT NULL
);
 
CREATE TABLE IF NOT EXISTS dada_clickthrough_urls (
url_id  int4 not null primary key auto_increment, 
redirect_id varchar(16), 
msg_id text, 
url text
); 

CREATE TABLE IF NOT EXISTS dada_mass_mailing_event_log (
id INT4 NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
timestamp TIMESTAMP DEFAULT NOW(),
remote_addr text, 
msg_id text, 
event text,
details text,
email varchar(80)
); 

CREATE TABLE IF NOT EXISTS dada_clickthrough_url_log (
id INT4 NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
timestamp TIMESTAMP DEFAULT NOW(),
remote_addr text,
msg_id text, 
url text,
email varchar(80)
);

CREATE TABLE IF NOT EXISTS dada_password_protect_directories (
id INT4 NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
name text,
url text,
path text,
use_custom_error_page char(1),
custom_error_page text,
default_password text
);

CREATE TABLE IF NOT EXISTS dada_message_drafts (
id INT4 NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
created_timestamp TIMESTAMP DEFAULT NOW(),
last_modified_timestamp TIMESTAMP,
name varchar(80), 
screen varchar(80),
role varchar(80),
draft mediumtext
);


