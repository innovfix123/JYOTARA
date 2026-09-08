CREATE TABLE `birth_chart_snapshots` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_id` text NOT NULL,
	`profile_id` text NOT NULL,
	`facts_json` text NOT NULL,
	`birth_time_known` integer NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_birth_chart_snapshots_owner_profile` ON `birth_chart_snapshots` (`owner_id`,`profile_id`);