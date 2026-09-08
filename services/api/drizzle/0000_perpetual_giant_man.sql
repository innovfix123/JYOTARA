CREATE TABLE `pilot_events` (
	`id` text PRIMARY KEY NOT NULL,
	`session_id` text NOT NULL,
	`event_type` text NOT NULL,
	`category` text,
	`language` text,
	`tradition` text,
	`helpful` integer,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `idx_pilot_events_session` ON `pilot_events` (`session_id`);--> statement-breakpoint
CREATE INDEX `idx_pilot_events_type_created` ON `pilot_events` (`event_type`,`created_at`);