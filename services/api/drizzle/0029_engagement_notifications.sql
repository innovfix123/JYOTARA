CREATE TABLE notification_devices (
 token_hash text PRIMARY KEY,
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 login_hash text NOT NULL,
 token_ciphertext text NOT NULL,
 language text NOT NULL CHECK(language IN ('en','ta','tanglish')),
 build integer NOT NULL,
 enabled integer NOT NULL DEFAULT 1,
 registered_at integer NOT NULL,
 updated_at integer NOT NULL
);
CREATE INDEX notification_device_account ON notification_devices(account_id,enabled,updated_at);
CREATE TABLE notification_campaigns (
 id text PRIMARY KEY,
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 token_hash text NOT NULL,
 day text NOT NULL,
 kind text NOT NULL,
 feature text NOT NULL,
 status text NOT NULL,
 created_at integer NOT NULL,
 updated_at integer NOT NULL,
 received_at integer,
 opened_at integer,
 provider_code text,
 UNIQUE(account_id,day,kind)
);
CREATE INDEX notification_campaign_account ON notification_campaigns(account_id,created_at);
