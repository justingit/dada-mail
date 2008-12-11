CREATE TABLE dada_settings (
list                             varchar(16),
setting                          varchar(64),
value                            text
);

CREATE TABLE dada_subscribers (
email_id                         INTEGER PRIMARY KEY AUTOINCREMENT,
email                            text(320),
list                             varchar(16),
list_type                        varchar(64),
list_status                      char(1)
);


CREATE TABLE dada_archives (
list                          varchar(32),
archive_id                    varchar(32),
subject                       text,
message                       mediumtext,
format                        text,
raw_msg                       mediumtext
);


CREATE TABLE dada_bounce_scores (
id                            INTEGER PRIMARY KEY AUTOINCREMENT,
email                         text, 
list                          varchar(16),
score                         int4
); 





CREATE TABLE dada_sessions (
     id CHAR(32) NOT NULL PRIMARY KEY,
     a_session TEXT NOT NULL
  );
