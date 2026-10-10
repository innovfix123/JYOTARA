-- No account foreign key: this minimal eligibility marker survives erasure.
-- Live and sandbox offers are separate; public verified accounts use live.
CREATE TABLE phone_trial_claims (
 mode text NOT NULL CHECK(mode IN ('live','test')),
 phone_hash text NOT NULL,
 claimed_at integer NOT NULL,
 PRIMARY KEY(mode,phone_hash)
);

-- Retain the current eligibility exclusions, including prior Ask/purchases.
INSERT INTO phone_trial_claims(mode,phone_hash,claimed_at)
SELECT used.mode,a.phone_hash,MIN(used.created_at)
FROM phone_accounts a JOIN (
 SELECT account_id,mode,created_at FROM intro_chat_trials WHERE state IN ('active','ended')
 UNION ALL SELECT account_id,'live',created_at FROM live_wallet_usage WHERE action='guidance' AND status IN ('reserved','complete')
 UNION ALL SELECT account_id,'test',created_at FROM wallet_usage WHERE action='guidance' AND status IN ('reserved','complete')
 UNION ALL SELECT account_id,'live',created_at FROM live_wallet_orders WHERE status='paid'
 UNION ALL SELECT account_id,'test',created_at FROM wallet_orders WHERE status='paid'
) used ON used.account_id=a.id
GROUP BY used.mode,a.phone_hash;
