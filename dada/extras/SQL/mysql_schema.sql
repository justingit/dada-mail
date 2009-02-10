CREATE TABLE dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
);

CREATE INDEX dada_settings_list_index ON dada_settings (list);

CREATE TABLE dada_subscribers (
email_id			            int4 not null primary key auto_increment,
email                            text(320),
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1)
);

-- In very old versions of MySQL (around 4.0), making this table will cause an error, try replacing the line: 
-- email                            text(320),
-- with just: 
-- email                            text,

CREATE INDEX dada_subscribers_all_index ON dada_subscribers (email(320), list, list_type, list_status);

-- Same problem, in very old version of MySQL, this INDEX doesn't seem to work...

CREATE TABLE dada_subscriber_fields (
	fields_id			         int4 not null primary key auto_increment,
	email                        varchar(320) not null,
	CONSTRAINT UNIQUE (email)
);

CREATE TABLE dada_subscriber_profile (
	fields_id			         int4 not null primary key auto_increment,
	email                        varchar(320) not null,
	password                     text(16),
	CONSTRAINT UNIQUE (email)
);


	
	
	











CREATE TABLE dada_archives (
list                          varchar(32),
archive_id                    varchar(32),
subject                       text,
message                       mediumtext,
format                        text,
raw_msg                       mediumtext
);

CREATE INDEX dada_archives_list_archive_id_index ON dada_archives (list, archive_id);


CREATE TABLE dada_bounce_scores (
id                            int4 not null primary key auto_increment,
email                         text, 
list                          varchar(16),
score                         int4
); 




CREATE TABLE dada_sessions (
     id CHAR(32) NOT NULL PRIMARY KEY,
     a_session TEXT NOT NULL
  );
