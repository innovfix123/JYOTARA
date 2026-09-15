CREATE TABLE IF NOT EXISTS answer_reports (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES phone_accounts(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  content_ciphertext TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  reviewed_at INTEGER
);
CREATE INDEX IF NOT EXISTS answer_reports_account_created ON answer_reports(account_id,created_at);
