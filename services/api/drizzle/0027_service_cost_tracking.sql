-- Operational metadata only. Chat content is stored separately under consent.
CREATE TABLE service_requests (
 id text PRIMARY KEY,
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 client_request_id text NOT NULL, profile_id text NOT NULL, session_id text,
 feature text NOT NULL, state text NOT NULL DEFAULT 'received',
 delivery_uncertain integer NOT NULL DEFAULT 0,
 wallet_mode text, wallet_usage_id text, wallet_status text, coins integer,
 replay_count integer NOT NULL DEFAULT 0, message_count integer NOT NULL DEFAULT 0, cache_status text,
 http_status integer, error_code text,
 created_at integer NOT NULL, updated_at integer NOT NULL,
 UNIQUE(account_id,client_request_id,profile_id,feature)
);
CREATE INDEX service_request_session ON service_requests(session_id);
CREATE INDEX service_request_account_time ON service_requests(account_id,created_at);
CREATE TABLE provider_attempts (
 id text PRIMARY KEY, request_id text NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
 provider text NOT NULL, module text, model text NOT NULL DEFAULT 'unknown', returned_model text,
 attempt integer NOT NULL, retry_index integer, reason text NOT NULL, status text NOT NULL DEFAULT 'started',
 http_status integer, error_code text, validation text, generation_id text,
 reported_cost_usd numeric, charged_credits integer,
 prompt_tokens integer, completion_tokens integer, reasoning_tokens integer, cached_tokens integer,
 created_at integer NOT NULL, finished_at integer, latency_ms integer,
 UNIQUE(request_id,provider,module,attempt,reason)
);
CREATE INDEX provider_attempt_request ON provider_attempts(request_id,created_at);
-- These totals have no account, session, request or provider generation IDs.
CREATE TABLE service_cost_daily_totals (
 day_key text NOT NULL, feature text NOT NULL, provider text NOT NULL, model text NOT NULL,
 attempt_count integer NOT NULL DEFAULT 0, finished_count integer NOT NULL DEFAULT 0,
 failed_count integer NOT NULL DEFAULT 0, uncertain_count integer NOT NULL DEFAULT 0,
 known_usd_count integer NOT NULL DEFAULT 0, known_credit_count integer NOT NULL DEFAULT 0,
 reported_cost_usd numeric NOT NULL DEFAULT 0, charged_credits integer NOT NULL DEFAULT 0,
 PRIMARY KEY(day_key,feature,provider,model)
);
CREATE TABLE research_chat_content (
 request_id text PRIMARY KEY REFERENCES service_requests(id) ON DELETE CASCADE,
 consent_version text NOT NULL, ciphertext text NOT NULL, created_at integer NOT NULL, expires_at integer NOT NULL
);
CREATE INDEX research_chat_expiry ON research_chat_content(expires_at);
