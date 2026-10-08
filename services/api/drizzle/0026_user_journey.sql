CREATE TABLE `user_journey_events` (
  `account_id` text NOT NULL REFERENCES `phone_accounts`(`id`) ON DELETE CASCADE,
  `event_id` text NOT NULL,
  `app_session_id` text NOT NULL,
  `sequence` integer NOT NULL,
  `event_name` text NOT NULL,
  `screen` text NOT NULL,
  `occurred_at` integer NOT NULL,
  `received_at` integer NOT NULL,
  `server_sequence` integer NOT NULL,
  `metadata_json` text NOT NULL,
  PRIMARY KEY (`account_id`, `event_id`)
);
CREATE INDEX `user_journey_account_time_idx` ON `user_journey_events` (`account_id`, `received_at`, `app_session_id`, `sequence`);
CREATE INDEX `user_journey_retention_idx` ON `user_journey_events` (`received_at`);
CREATE UNIQUE INDEX `user_journey_server_sequence_idx` ON `user_journey_events` (`account_id`, `server_sequence`);
