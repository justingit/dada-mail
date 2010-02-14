-- The below schema should work well for MySQL ver. 5
-- 
-- If you are using MySQL 4: 
-- 
-- use the mysql4_schema.sql instead. 
-- 
-- Dada Mail currently doesn't auto-detect what version of MySQL you're using, 
-- SO, if you are upgrading Dada Mail from 3x to 4x, you'll need to rename: 
-- mysql_schema.sql
-- to, 
-- mysql5_schema.sql
-- and rename, 
-- mysql4_schema.sql
-- to, 
-- mysql_schema.sql
-- 
-- and re-run the migration utility. 

CREATE TABLE IF NOT EXISTS dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE INDEX dada_settings_list_index ON dada_settings (list);

CREATE TABLE IF NOT EXISTS dada_subscribers (
email_id			            int4 not null primary key auto_increment,
email                            text(320),
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1)
) CHARACTER SET utf8 COLLATE utf8_bin;


CREATE INDEX dada_subscribers_all_index ON dada_subscribers (email(320), list, list_type, list_status);



CREATE TABLE IF NOT EXISTS dada_profiles ( 
profile_id int4 not null primary key auto_increment,
email                        varchar(320) not null,
password                     text(16),
auth_code                    varchar(64),
update_email_auth_code       varchar(64),
update_email                 varchar(320),
activated                    char(1), 
CONSTRAINT UNIQUE (email)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_fields (
fields_id int4 not null primary key auto_increment,
email varchar(320) not null,
CONSTRAINT UNIQUE (email)
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS dada_profile_fields_attributes (
	attribute_id int4 not null primary key auto_increment,
	field                       varchar(320),
	label                       varchar(320),
	fallback_value              varchar(320),
-- I haven't made the following, but it seems like a pretty good idea... 
-- sql_col_type              text(16),
-- default                   mediumtext,
-- html_form_widget          varchar(320),
-- required                  char(1),
-- public                    char(1),
	CONSTRAINT UNIQUE (field)
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
 
CREATE TABLE IF NOT EXISTS dada_clickthrough_urls (
url_id  int4 not null primary key auto_increment, 
redirect_id varchar(16), 
msg_id text, 
url text
); 
 
CREATE TABLE IF NOT EXISTS dada_sessions (
     id CHAR(32) NOT NULL PRIMARY KEY,
     a_session TEXT NOT NULL
);