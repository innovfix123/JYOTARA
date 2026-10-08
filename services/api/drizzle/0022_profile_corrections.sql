-- Preserve every metering/recovery row. One paid attempt per distinct set of
-- birth details, rather than blocking all profile corrections for the day.
DROP INDEX `idx_profile_generations_session_day`;
CREATE UNIQUE INDEX `idx_profile_generations_session_day_hash`
ON `profile_generations` (`session_id`,`day_key`,COALESCE(`request_hash`,''));
