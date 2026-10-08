CREATE TABLE wallet_orders (
 id text PRIMARY KEY, account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 request_id text NOT NULL, pack_id text NOT NULL, amount integer NOT NULL CHECK(amount>0), coins integer NOT NULL CHECK(coins>0),
 remaining integer NOT NULL DEFAULT 0 CHECK(remaining>=0), provider_order text UNIQUE, provider_payment text UNIQUE,
 status text NOT NULL DEFAULT 'creating', refund_review integer NOT NULL DEFAULT 0,
 created_at integer NOT NULL, updated_at integer NOT NULL, UNIQUE(account_id,request_id), CHECK(remaining<=coins)
);
CREATE TABLE wallet_usage (
 id text PRIMARY KEY, account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 request_id text NOT NULL, payload_hash text NOT NULL, action text NOT NULL, category text NOT NULL,
 depth text NOT NULL, cost integer NOT NULL CHECK(cost>=0), trial integer NOT NULL DEFAULT 0,
 upgrade_from text, binding_hash text NOT NULL, status text NOT NULL DEFAULT 'reserved',
 allocations text NOT NULL DEFAULT '[]', result_ciphertext text, created_at integer NOT NULL, updated_at integer NOT NULL,
 UNIQUE(account_id,request_id)
);
CREATE UNIQUE INDEX wallet_upgrade_once ON wallet_usage(upgrade_from) WHERE upgrade_from IS NOT NULL AND status IN ('reserved','complete');
CREATE UNIQUE INDEX wallet_trial_once ON wallet_usage(account_id) WHERE trial=1 AND status IN ('reserved','complete');
CREATE INDEX wallet_order_account ON wallet_orders(account_id,created_at);
CREATE INDEX wallet_usage_account ON wallet_usage(account_id,created_at);
