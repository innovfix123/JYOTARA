# Profile correction incident — 6 October 2026

Symptom: users correcting saved birth details saw `profile_attempt_exists` / an existing-session message. Unknown-time chat also repeated long time limitations.

First checks: identify the active backend release, confirm migration 0022 and the profile index include `request_hash`, and check reservation plus encrypted recovery use the same hash. Do not rotate account cookies or delete user profiles to bypass a duplicate. Different corrected details must get a new reservation; an identical retry must recover its matching receipt.

Release: `profile-edit112-20261006`; APK 1.0.2+112. Changed birth details still require the provider to respond successfully. Failed/uncertain retries and budget limits remain guarded. Metadata-only edits bypass unnecessary chat renewal in build 112. General guidance remains available for unknown time without fabricated precise chart claims.
