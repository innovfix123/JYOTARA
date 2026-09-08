ALTER TABLE `guide_requests` ADD `request_hash` text;--> statement-breakpoint
ALTER TABLE `guide_requests` ADD `response_ciphertext` text;--> statement-breakpoint
ALTER TABLE `guide_requests` ADD `response_expires_at` integer;