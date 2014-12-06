CREATE TABLE IF NOT EXISTS dada_settings (
list varchar(16),
setting varchar(64),
value text
);

CREATE TABLE IF NOT EXISTS dada_subscribers (
email_id INTEGER PRIMARY KEY AUTOINCREMENT,
email varchar(80),
list varchar(16),
list_type varchar(64),
list_status char(1),
timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dada_confirmation_tokens ( 
id INTEGER PRIMARY KEY AUTOINCREMENT,
timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
token varchar(255) UNIQUE,
email varchar(80),
data text
);


CREATE TABLE IF NOT EXISTS dada_profiles (
profile_id INTEGER PRIMARY KEY AUTOINCREMENT,
email varchar(80) not null UNIQUE,
password text(16),
auth_code varchar(64),
update_email_auth_code varchar(64),
update_email varchar(80),
activated char(1)
);

CREATE TABLE IF NOT EXISTS dada_profile_fields (
fields_id INTEGER PRIMARY KEY AUTOINCREMENT,
email varchar(80) not null UNIQUE
);

CREATE TABLE IF NOT EXISTS dada_archives (
list varchar(16),
archive_id varchar(32),
subject text,
message mediumtext,
format text,
raw_msg mediumtext
);

CREATE TABLE IF NOT EXISTS dada_profile_settings (
id INTEGER PRIMARY KEY AUTOINCREMENT,
email varchar(80),
list varchar(16),
setting varchar(64),
value text
);

CREATE TABLE IF NOT EXISTS dada_bounce_scores (
id INTEGER PRIMARY KEY AUTOINCREMENT,
email text, 
list varchar(16),
score int4
); 

CREATE TABLE IF NOT EXISTS dada_sessions (
id CHAR(32) NOT NULL PRIMARY KEY,
a_session TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes (
attribute_id INTEGER PRIMARY KEY AUTOINCREMENT,
field varchar(80) NOT NULL UNIQUE,	
label varchar(80),
fallback_value varchar(80),
required char(1) DEFAULT 0 NOT NULL
);

CREATE TABLE IF NOT EXISTS dada_clickthrough_urls (
url_id INTEGER PRIMARY KEY AUTOINCREMENT,
redirect_id varchar(16),
msg_id text,
url text
);

CREATE TABLE IF NOT EXISTS dada_mass_mailing_event_log (
id INTEGER PRIMARY KEY AUTOINCREMENT,
list varchar(16),
timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
remote_addr text, 
msg_id text,
event text,
details text,
email varchar(80)
);

CREATE TABLE IF NOT EXISTS dada_clickthrough_url_log (
id INTEGER PRIMARY KEY AUTOINCREMENT,
list varchar(16),
timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
remote_addr text, 
msg_id text,
url text,
email varchar(80)
);

CREATE TABLE IF NOT EXISTS dada_password_protect_directories (
id INTEGER PRIMARY KEY AUTOINCREMENT,
list varchar(16),
name text,
url text,
path text,
use_custom_error_page char(1),
custom_error_page text,
default_password text
);

CREATE TABLE IF NOT EXISTS dada_message_drafts (
id INTEGER PRIMARY KEY AUTOINCREMENT,
list varchar(16),
created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
last_modified_timestamp TIMESTAMP, 
name varchar(80),
screen varchar(80),
role varchar(80),
draft text
);
