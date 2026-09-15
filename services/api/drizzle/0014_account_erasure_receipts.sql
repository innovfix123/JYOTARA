-- Opaque, short-lived retry receipts contain no phone number or account ID.
CREATE TABLE IF NOT EXISTS account_erasure_receipts (
  token_hash text PRIMARY KEY,
  tester_key text NOT NULL,
  expires_at integer NOT NULL
);
CREATE INDEX IF NOT EXISTS account_erasure_receipts_expiry ON account_erasure_receipts(expires_at);
