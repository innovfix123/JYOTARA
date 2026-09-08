CREATE TABLE `profile_generations` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`day_key` text NOT NULL,
	`status` text NOT NULL,
	`credits` integer DEFAULT 0 NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_profile_generations_day_status` ON `profile_generations` (`day_key`,`status`);--> statement-breakpoint
CREATE UNIQUE INDEX `idx_profile_generations_session_day` ON `profile_generations` (`session_id`,`day_key`);