CREATE TABLE dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
);

CREATE TABLE dada_subscribers (
email_id                         serial,
email                            text,
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1)
);


CREATE TABLE dada_profile (
	profile_id			         serial,
	email                        varchar(320) not null UNIQUE,
	password                     text,
	auth_code                    varchar(64),
	activated                    char(1)
);

CREATE TABLE dada_profile_fields (
	fields_id			         serial,
	email                        varchar(320) not null UNIQUE
);


CREATE TABLE dada_profile_fields_attributes ( 

attribute_id 				serial,
field                       varchar(320) UNIQUE,
label                       varchar(320),
fallback_value              varchar(320)
-- I haven't made the following, but it seems like a pretty good idea... 
-- sql_col_type              text(16),
-- default                   mediumtext,
-- html_form_widget          varchar(320),
-- required                  char(1),
-- public                    char(1),
);



	

CREATE TABLE dada_archives (
list                          varchar(32),
archive_id                    varchar(32),
subject                       text,
message                       text,
format                        text,
raw_msg                       text
);

CREATE TABLE dada_bounce_scores (
id                            serial, 
email                         text, 
list                          varchar(16),
score                         int4 
); 


CREATE TABLE dada_sessions (
    id CHAR(32) NOT NULL PRIMARY KEY,
    a_session BYTEA NOT NULL
);
