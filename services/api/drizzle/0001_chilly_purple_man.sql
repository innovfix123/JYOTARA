CREATE TABLE `guide_requests` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`category` text NOT NULL,
	`language` text NOT NULL,
	`support_level` text NOT NULL,
	`answer_mode` text NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_guide_requests_session_created` ON `guide_requests` (`session_id`,`created_at`);