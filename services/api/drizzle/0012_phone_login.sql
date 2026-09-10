CREATE TABLE IF NOT EXISTS phone_accounts (id text PRIMARY KEY, phone_hash text NOT NULL UNIQUE, last_four text NOT NULL, created_at integer NOT NULL);
CREATE TABLE IF NOT EXISTS phone_challenges (id text PRIMARY KEY, phone_hash text NOT NULL, tester_key text NOT NULL, code_hash text NOT NULL, expires_at integer NOT NULL, tries integer NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS phone_challenges_expiry ON phone_challenges(expires_at);
CREATE TABLE IF NOT EXISTS phone_login_sessions (token_hash text PRIMARY KEY, account_id text NOT NULL REFERENCES phone_accounts(id), tester_key text NOT NULL, expires_at integer NOT NULL);
CREATE TABLE IF NOT EXISTS phone_rate_limits (id text PRIMARY KEY, hits integer NOT NULL, expires_at integer NOT NULL);
CREATE TABLE IF NOT EXISTS phone_profile_owners (session_id text PRIMARY KEY, account_id text NOT NULL REFERENCES phone_accounts(id));
