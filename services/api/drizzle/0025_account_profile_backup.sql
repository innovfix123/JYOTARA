CREATE TABLE `account_profile_backups` (
  `account_id` text PRIMARY KEY REFERENCES `phone_accounts`(`id`) ON DELETE CASCADE,
  `session_id` text NOT NULL,
  `payload_ciphertext` text NOT NULL,
  `updated_at` integer NOT NULL
);
