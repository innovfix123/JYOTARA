CREATE TABLE intro_chat_trials (
 account_id text NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
 mode text NOT NULL CHECK(mode IN ('live','test')),
 state text NOT NULL CHECK(state IN ('offered','active','ended','skipped')),
 billing_session text,
 guide text,
 created_at integer NOT NULL,
 updated_at integer NOT NULL,
 PRIMARY KEY(account_id,mode)
);
CREATE INDEX intro_chat_trial_session ON intro_chat_trials(account_id,mode,billing_session);
