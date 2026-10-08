# Ask: first checks during an incident

Updated 2026-10-08. Applies to subsequent Jyotara Ask failures; diagnose rather than assume the same cause.

1. Capture approximate time, selected language/depth, app build, and exact error. Distinguish local renewal errors from reading_unavailable responses.
2. Check public /healthz, jyotara-api service, server NTP status and recent logs. Health success alone does not prove OTP, payments or chat providers work.
3. Inspect recent guide_requests outcome and only providerUsage metadata from encrypted receipts. Do not dump questions, birth details, replies, secrets or session tokens.
4. For Divine 401, check the current documentation and request format before rotating keys. Chat now requires BOTH Authorization: Bearer <access token> and x-api-key headers. API key in JSON alone is obsolete. Official reference: https://developers.divineapi.com/astro-chatbot/chat.
5. Validate authentication with the current usage endpoint (POST /usage with both headers was HTTP200 on October 3). Inspect dashboard subscription/access if authentication fails. Do not equate a valid paid subscription with successful Chatbot authorization.
6. For time-check errors, inspect renewal metadata and device automatic time. Backend compatibility window accommodates modest skew; mobile tolerance change remains pending a release. Do not weaken signed-ticket expiry, ownership or deletion checks.
7. For provider/editor failures, distinguish status codes, transport uncertainty, invalid source, truncated output and validation rejection. Keep numeric provenance and language validation; fix prompts/contracts rather than remove safeguards. Never automatically repeat an uncertain paid request.
8. Check wallet outcome and coin charges independently. Do not infer refunds only from a displayed error. Reconcile payment captures with wallet credits, not just checkout opening.
9. After a fix, run focused regressions, back up deployed code/config, verify deployed checksum and health. Use bounded synthetic language/depth probes where needed; record provider credit cost. Confirm on the affected phone before claiming full recovery.

## October 8: quote rejected for unknown birth time

- Build 139 on Samsung showed “The coin quote changed or expired.” This failure happened before guidance reservation/provider work, separately from earlier provider authentication incidents.
- The installed wallet client sends phone authentication and the chart ticket, but no chart-session cookie. Quoting therefore treated unknown-time guidance as paid; the later Ask request included the cookie and correctly priced it at zero. Strict quote comparison rejected the mismatch.
- Quote pricing now reads only signed, fresh ticket flags and verifies account ownership and deletion status when the cookie is absent. Normal guidance still requires its session-bound ticket. Tampering, expiry, account isolation, exact price checks and replay protection remain enforced.
- 15 focused tests plus both PostgreSQL wallet integration suites passed. These include quotes without a cookie, free general guidance, other-account/deleted-profile checks, spending, refunds and retries.
- Live release: `ask-quote139-20261008`; SHA256 `c67680dbe9c263d3847dc01869127b23dd4d162304b16bcc760bd6314af39662`. Rollback: `daily-copy129b-20261007`. No configuration or database migration changes; no new APK or Play submission.
- Same Samsung question retried successfully in Tanglish/Standard at 17:37 IST. Receipt: `limited_guidance`, editor completed, wallet complete with zero coins. One editor call cost $0.0002325; no Divine call. Unknown-time users receive general guidance rather than fabricated chart predictions.
- Evidence: `docs/qa/2026-10-08/ask-quote/`. If this specific error returns, check signed quote versus verified price before rotating provider keys. Health alone does not establish chat availability.

## October 3 recovery evidence

- Provider changed authentication to two headers; deployment migrated and regenerated credentials installed in protected server environment.
- 14 consultation/idempotency tests passed.
- Live synthetic Tamil Detailed succeeded in about 11.8 seconds. Tanglish initially failed numeric provenance; clarified spelled-out-number translation and next test succeeded in about 11.3 seconds.
- User explicitly confirmed the app is working.
- Incident details: chat-clock-incident-2026-10-03.md.
- Still separate follow-ups: verify the provider's changed session-deletion endpoint; ship mobile clock tolerance in a future APK. No ongoing monitor/alert schedule is established by this runbook.

## October 3, 12:38 Standard rejection and build 108

- Receipt showed Divine and OpenRouter completed but the final edit failed validation. Original failure has no per-rule diagnostic, so exact rejected rule is unknown.
- Added JSON response format, text-free validation reason metadata for all depths, and at most one editor-only repair using the same source. No repeat Divine purchase; no retry after ambiguous transport failure; unchanged language, exact-quote and numeric checks.
- Total editing deadline 65 seconds leaves room before the installed app's 75-second timeout.
- 22 backend tests and 9 mobile tests passed. Synthetic English/Tamil/Tanglish Standard exam questions passed in 8–9 seconds (90 Divine credits, no user wallet charge). This is bounded evidence, not a guarantee of all future answers.
- Backend deployed with rollback /opt/jyotara/server.before-chat-repair108.mjs. Build 108 packages current mobile changes; this backend repair benefits prior app versions as well. Samsung verification still pending.
