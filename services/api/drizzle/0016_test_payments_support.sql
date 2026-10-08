CREATE TABLE IF NOT EXISTS test_payment_orders (
 id text PRIMARY KEY,
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 request_id text NOT NULL,
 provider_order text UNIQUE,
 provider_payment text UNIQUE,
 amount integer NOT NULL CHECK(amount=100),
 status text NOT NULL DEFAULT 'creating',
 created_at integer NOT NULL,
 updated_at integer NOT NULL,
 UNIQUE(account_id, request_id)
);
CREATE INDEX IF NOT EXISTS test_payment_orders_account ON test_payment_orders(account_id, created_at);
CREATE TABLE IF NOT EXISTS support_tickets (
 id text PRIMARY KEY,
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 request_id text NOT NULL,
 category text NOT NULL,
 content_ciphertext text NOT NULL,
 status text NOT NULL DEFAULT 'submitted',
 created_at integer NOT NULL,
 UNIQUE(account_id, request_id)
);
