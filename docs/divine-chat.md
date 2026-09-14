# Tester chat provider configuration

`JYOTARA_CHAT_PROVIDER=divine` routes ordinary chart questions through Divine's hosted Vedic chatbot, followed by an OpenRouter language edit. `OPENROUTER_MODEL=google/gemini-2.5-flash` is the approved tester model. A later model change is server configuration only; GPT is not enabled by this change. Keep all credentials in the server environment, never in the APK.

Birth datetime and coordinates must match the authenticated chart ticket (or its encrypted original receipt for legacy tickets). Confirmed time and a saved male/female report profile are required by the current provider contract. Unknown-time profiles receive a request to confirm their details; no noon time is invented. Initial chart overview and sensitive safety responses retain their existing paths. Kundli calculation, matching and daily horoscope continue using the existing calculation integration.

Each accepted question has an isolated external session. Recent dialogue from the selected chat is included for continuity. An existing request receipt is replayed without either paid call. Ambiguous failures never trigger an automatic paid retry. The API records returned credits and model cost in the encrypted response receipt. User payments remain disabled.

The editor receives only the reading and question, writes short English/Tamil/Tanglish text, and must return matching source excerpts. Structural/script and new-number checks reject malformed edits. These checks are not a proof of predictive accuracy or complete semantic equivalence.

Run migration 0013 before activation. External conversations are immediately requested for deletion. Failed deletions remain in `divine_cleanup` (opaque IDs only) and a runtime hourly worker retries due records, backing failures off for a day. On 14 September the documented deletion API returned 401 for this account, including with its access token. Do not claim external erasure is confirmed until the provider resolves this. The app's processing/deletion wording reflects this limitation.

Timeout budget: reading42s + editor18s + cleanup4s; mobile75s, reverse proxy90s. A timeout receipt prevents duplicate paid calls but may require a genuinely new question. Roll back using the previous server release and saved environment together; retain the additive cleanup table.

Validation: API tests include actual route replay, birth-data mismatch, isolated sessions, transport ambiguity and editor validation. Live candidate tests and device evidence are stored outside the repository under source/jyotara-release-20260914. This is an invited tester integration, not approval for public launch.
