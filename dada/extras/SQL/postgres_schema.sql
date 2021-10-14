-- no indexes?

CREATE TABLE dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
);

CREATE TABLE dada_subscribers (
email_id                         serial,
email                            varchar(80),
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1),
timestamp TIMESTAMP DEFAULT NOW()
);

CREATE TABLE dada_confirmation_tokens ( 
id serial,
timestamp TIMESTAMP DEFAULT NOW(),
token varchar(255) UNIQUE,
email varchar(80),
data text
);

CREATE TABLE dada_profiles (
	profile_id                   serial,
	email                        varchar(80) not null UNIQUE,
	password                     text,
	auth_code                    varchar(64),
	update_email_auth_code       varchar(64),
	update_email                 varchar(80),
	activated                    char(1)
);

CREATE TABLE dada_profile_fields (
	fields_id			         serial,
	email                        varchar(80) not null UNIQUE
);


CREATE TABLE dada_profile_fields_attributes ( 

attribute_id                serial,
field                       varchar(80) UNIQUE,
label                       varchar(80),
fallback_value              text,
required char(1) DEFAULT 0 NOT NULL

-- I haven't made the following, but it seems like a pretty good idea... 
-- sql_col_type              text(16),
-- default                   mediumtext,
-- html_form_widget          varchar(320),
-- public                    char(1),
);


CREATE TABLE dada_profile_settings (
id                               serial,
email                            varchar(80),
list                             varchar(16),
setting                          varchar(64),
value                            text
);



	

CREATE TABLE dada_archives (
list                          varchar(16),
archive_id                    varchar(32),
subject                       text,
message                       text,
format                        text,
raw_msg                       text
);

CREATE TABLE dada_bounce_scores (
id                            serial, 
email                         varchar(80),
list                          varchar(16),
score                         int4 
);


CREATE TABLE dada_sessions (
    id CHAR(32) NOT NULL PRIMARY KEY,
    a_session BYTEA NOT NULL
);


CREATE TABLE dada_clickthrough_urls (
url_id  serial,
redirect_id varchar(16), 
msg_id text, 
url text
);

CREATE TABLE dada_mass_mailing_event_log (
id serial,
list varchar(16),
timestamp TIMESTAMP DEFAULT NOW(),
remote_addr text, 
msg_id text, 
event text,
details text,
email varchar(80),
user_agent varchar(255)
); 

CREATE TABLE dada_clickthrough_url_log (
id serial,
list varchar(16),
timestamp TIMESTAMP DEFAULT NOW(),
remote_addr text,
msg_id text, 
url text,
email varchar(80),
user_agent varchar(255)
);

CREATE TABLE dada_password_protect_directories (
id serial,
list varchar(16),
name text,
url text,
path text,
use_custom_error_page char(1),
custom_error_page text,
default_password text,
always_use_default_password char(1)
);

CREATE TABLE dada_message_drafts (
id serial not null UNIQUE,
list varchar(16),
created_timestamp TIMESTAMP DEFAULT NOW(),
last_modified_timestamp TIMESTAMP DEFAULT NOW(),
name varchar(80), 
screen  varchar(80),
role varchar(80),
draft text
);

CREATE TABLE dada_rate_limit_hits ( 
user_id VARCHAR(225) NOT NULL,
action VARCHAR(225) NOT NULL, 
timestamp INT NOT NULL
);

CREATE TABLE dada_email_message_previews (
id serial not null UNIQUE,
list varchar(16),
created_timestamp TIMESTAMP DEFAULT NOW(),
vars text,
plaintext text,
html text
);

CREATE TABLE dada_privacy_policies (
    privacy_policy_id serial not null UNIQUE PRIMARY KEY,
	timestamp TIMESTAMP DEFAULT NOW(),
	list varchar(16),
	privacy_policy text
);

CREATE TABLE dada_consents (
    consent_id serial not null UNIQUE PRIMARY KEY,
	timestamp             TIMESTAMP DEFAULT NOW(),
	list                  varchar(16),
	consent               text
);

CREATE TABLE dada_consent_activity (	
	consent_activity_id   serial not null UNIQUE PRIMARY KEY,
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
