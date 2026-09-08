ALTER TABLE `profile_generations` ADD `request_hash` text;--> statement-breakpoint
ALTER TABLE `profile_generations` ADD `response_ciphertext` text;--> statement-breakpoint
ALTER TABLE `profile_generations` ADD `response_expires_at` integer;