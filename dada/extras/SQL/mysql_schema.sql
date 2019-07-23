CREATE TABLE IF NOT EXISTS dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
) CHARACTER SET utf8 COLLATE utf8_bin;


CREATE TABLE IF NOT EXISTS dada_subscribers (
email_id                        int not null primary key auto_increment,
email                            varchar(80),
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1),
timestamp                       TIMESTAMP DEFAULT NOW()
) CHARACTER SET utf8 COLLATE utf8_bin;


CREATE TABLE IF NOT EXISTS dada_confirmation_tokens ( 
id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
timestamp TIMESTAMP DEFAULT NOW(),
token varchar(255),
email varchar(80),
data text,
UNIQUE (token)
);


CREATE TABLE IF NOT EXISTS dada_profiles ( 
profile_id int not null primary key auto_increment,
email                        varchar(80) not null,
password                     text(16),
auth_code                    varchar(64),
update_email_auth_code       varchar(64),
update_email                 varchar(80),
activated                    char(1), 
CONSTRAINT UNIQUE (email)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_fields (
fields_id int not null primary key auto_increment,
email varchar(80) not null,
CONSTRAINT UNIQUE (email)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes (
attribute_id int not null primary key auto_increment,
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
id int not null primary key auto_increment,
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
 
 
CREATE TABLE IF NOT EXISTS dada_bounce_scores (
id                            int not null primary key auto_increment,
email                         text, 
list                          varchar(16),
score                         int
);

CREATE TABLE IF NOT EXISTS dada_sessions (
     id CHAR(32) NOT NULL PRIMARY KEY,
     a_session TEXT NOT NULL
);
 
CREATE TABLE IF NOT EXISTS dada_clickthrough_urls (
url_id  int not null primary key auto_increment, 
redirect_id varchar(16), 
msg_id text, 
url text
); 


CREATE TABLE IF NOT EXISTS dada_mass_mailing_event_log (
id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
timestamp TIMESTAMP DEFAULT NOW(),
remote_addr varchar(255), 
msg_id varchar(255), 
event varchar(255),
details varchar(255),
email varchar(80), 
user_agent varchar(255)
); 

CREATE TABLE IF NOT EXISTS dada_clickthrough_url_log (
id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
timestamp TIMESTAMP DEFAULT NOW(),
remote_addr varchar(255),
msg_id text, 
url text,
email varchar(80),
user_agent varchar(255)
);

CREATE TABLE IF NOT EXISTS dada_password_protect_directories (
id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
name text,
url text,
path text,
use_custom_error_page char(1),
custom_error_page text,
default_password text
);

CREATE TABLE IF NOT EXISTS dada_message_drafts (
id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
last_modified_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
name varchar(80), 
screen varchar(80),
role varchar(80),
draft mediumtext
);


CREATE TABLE IF NOT EXISTS dada_rate_limit_hits ( 
user_id VARCHAR(225) NOT NULL,
action VARCHAR(225) NOT NULL, 
timestamp INT UNSIGNED NOT NULL
);

CREATE TABLE IF NOT EXISTS dada_email_message_previews (
id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
list varchar(16),
created_timestamp TIMESTAMP DEFAULT NOW(),
vars text,
plaintext mediumtext,
html mediumtext
);

CREATE TABLE IF NOT EXISTS dada_privacy_policies (
    privacy_policy_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	timestamp         TIMESTAMP DEFAULT NOW(),
	list              varchar(16),
	privacy_policy    mediumtext
);

CREATE TABLE IF NOT EXISTS dada_consents (
    consent_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	timestamp         TIMESTAMP DEFAULT NOW(),
	list              varchar(16),
	consent               mediumtext
);

CREATE TABLE IF NOT EXISTS dada_consent_activity (	
	consent_activity_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
	remote_addr           varchar(255), 
	timestamp             TIMESTAMP DEFAULT NOW(),
	email                 varchar(80),
	list                  varchar(16),
	action                varchar(80),
	source                varchar(225),
	source_location       varchar(225),
	list_type             varchar(64),
	consent_session_token varchar(255),
	consent_id            int,
	privacy_policy_id     int,
	FOREIGN KEY(consent_id)        REFERENCES dada_consents(consent_id), 
	FOREIGN KEY(privacy_policy_id) REFERENCES dada_privacy_policies(privacy_policy_id)	
);





CREATE INDEX dada_settings_list_index ON dada_settings (list);

CREATE INDEX dada_subscribers_all_index ON dada_subscribers (email(80), list, list_type, list_status, timestamp);

CREATE INDEX dada_confirmation_tokens_index ON dada_confirmation_tokens (id, timestamp, token(80), email(80));

CREATE INDEX dada_archives_list_archive_id_index ON dada_archives (list, archive_id);

CREATE INDEX dada_mass_mailing_event_log_index ON dada_mass_mailing_event_log (list,remote_addr(80), msg_id(80), event(80), timestamp);

CREATE INDEX dada_rate_limit_hits_all_index ON dada_rate_limit_hits (user_id, action(80), timestamp);

CREATE INDEX dada_consent_activity_index ON dada_consent_activity (email, list, action);
