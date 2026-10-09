CREATE TABLE minute_chat_sessions (
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 mode text NOT NULL CHECK(mode IN ('live','test')),
 id text NOT NULL,
 binding_hash text NOT NULL,
 window_until integer NOT NULL DEFAULT 0,
 pending_usage text,
 ended integer NOT NULL DEFAULT 0,
 created_at integer NOT NULL,
 updated_at integer NOT NULL,
 PRIMARY KEY(account_id,mode,id)
);
ALTER TABLE wallet_usage ADD COLUMN billing_session text;
ALTER TABLE live_wallet_usage ADD COLUMN billing_session text;
