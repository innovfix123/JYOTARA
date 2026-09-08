CREATE TABLE `current_context_cache` (
	`id` text PRIMARY KEY NOT NULL,
	`day_key` text NOT NULL,
	`status` text NOT NULL,
	`payload_json` text,
	`calculated_at` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_current_context_day` ON `current_context_cache` (`day_key`);--> statement-breakpoint
CREATE INDEX `idx_current_context_expiry` ON `current_context_cache` (`expires_at`);