CREATE TABLE divine_cleanup (
 id text PRIMARY KEY NOT NULL,
 created_at integer NOT NULL,
 next_attempt_at integer NOT NULL
);
CREATE INDEX divine_cleanup_due ON divine_cleanup(next_attempt_at);
