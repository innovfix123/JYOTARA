ALTER TABLE wallet_usage ADD COLUMN session_id text;
CREATE INDEX wallet_usage_session ON wallet_usage(session_id);
