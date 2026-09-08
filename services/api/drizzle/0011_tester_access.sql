CREATE TABLE tester_sessions (
  session_id text PRIMARY KEY NOT NULL,
  tester_key text NOT NULL,
  created_at integer NOT NULL
);
CREATE TABLE tester_daily_usage (
  id text PRIMARY KEY NOT NULL,
  day_key text NOT NULL,
  requests integer NOT NULL
);
CREATE INDEX idx_tester_daily_usage_day ON tester_daily_usage(day_key);
