CREATE TABLE provider_usage (
 id text PRIMARY KEY NOT NULL,
 request_id text,
 session_id text,
 module text NOT NULL,
 status text NOT NULL,
 http_status integer,
 expected_credits integer NOT NULL,
 actual_credits integer,
 created_at integer NOT NULL
);
CREATE INDEX provider_usage_request ON provider_usage(request_id);
CREATE TABLE provider_reports (
 id text PRIMARY KEY NOT NULL,
 session_id text NOT NULL,
 profile_id text NOT NULL,
 day_key text NOT NULL,
 status text NOT NULL,
 response_ciphertext text,
 expires_at integer NOT NULL
);
CREATE INDEX provider_reports_session ON provider_reports(session_id);
