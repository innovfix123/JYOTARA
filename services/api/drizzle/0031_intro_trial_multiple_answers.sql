-- The legacy free-answer allowance remains one per account. Minute-trial
-- answers belong to a server-owned billing session and are bounded by
-- intro_chat_trials instead; several replies may complete in that minute.
DROP INDEX wallet_trial_once;
CREATE UNIQUE INDEX wallet_trial_once ON wallet_usage(account_id)
 WHERE trial=1 AND billing_session IS NULL AND status IN ('reserved','complete');
DROP INDEX live_wallet_trial_once;
CREATE UNIQUE INDEX live_wallet_trial_once ON live_wallet_usage(account_id)
 WHERE trial=1 AND billing_session IS NULL AND status IN ('reserved','complete');
