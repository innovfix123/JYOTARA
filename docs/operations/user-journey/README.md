# First-party user activity timeline

Implemented for AST-190 item 15 on 9 October 2026. This records fixed action/outcome metadata; it is not conversation replay or marketing attribution.

## Deploy with the combined app update

- Apply API migration `0026_user_journey.sql` through the normal checked migration runner before restarting the API.
- Build/restart the API with authenticated `POST /api/user-journey` registered. It is exempt from chart ownership and astrology calculation admission, but not phone authentication. The handler independently checks the bearer token, tester identity and expiry.
- Deploy dashboard `server.mjs`, `index.html`, `user-journey.mjs` and `user-journey.html` together, then restart the existing dashboard service. They use the existing protected `DATABASE_URL`, dashboard auth database and host validation. No new credentials or public access are introduced.
- The existing owner login opens `/dashboard/user-journey`. Ordinary dashboard viewers cannot use its page or APIs. User lists show opaque account IDs and the account's existing last four phone digits; no full phone number or hash is exposed.
- Keep the API's hourly retention cleanup: `DELETE FROM user_journey_events WHERE received_at < $1`, with a cutoff 90 days before server time.
- Release the matching privacy page with the collection change. Optional Singular, Meta and Firebase switches and event sets remain independent and unchanged.

## Mobile integration

Initialize the shared `userJourney` service with HTTPS base URL and functions returning the current account, valid token and tester code. Wrap the existing MaterialApp child with `UserJourneyBoundary`, install `userJourney.navigatorObserver`, name navigated routes or call `screen()` when opening feature screens, and call `event()` or `tap()` for meaningful actions and outcomes.

The boundary captures taps and user scroll starts without coordinates, field values, accessibility labels or widget text. Semantic hooks distinguish authentication, profile, feature, chat and payment outcomes. Screen IDs and event names are closed vocabularies. Metadata permits fixed outcome/feature/control/language/error/source values plus bounded status, duration and count fields. Unexpected values are stripped on the client and rejected on the server.

The device queue is persisted locally, bounded to 500 metadata-only events and batched in groups of 50. Network errors keep exact event IDs for idempotent retry. Anonymous entry/onboarding activity is associated only after verified sign-in. Unsent events owned by another account are never relabelled on account switch; logout/account deletion clears the departing account's unsent queue. No typed account/profile/reading values or credential payloads are sent to this endpoint.

## Ordering and limits

The server serializes per-account ingestion and assigns an increasing server sequence. Retries do not create duplicate rows or spend the new-event hourly allowance. Each account is limited to 6,000 newly inserted events per hour. Server receipt time and sequence are authoritative; device timestamps are included solely as diagnostics because phone clocks may be wrong. Offline events arrive later and retain device/session sequence information.

The account foreign key uses `ON DELETE CASCADE`. Account deletion removes the active timeline. Retention is based on server receipt time. App background/detach hooks are best effort: Android killing a process without a callback cannot guarantee a final exit record. Offline history beyond the bounded queue is not reconstructed.

## Validation

- API tests: closed metadata, forged account fields, bad clock handling, phone-session ownership, tester/expiry, quota, retry acknowledgement and cascade/index schema.
- Dashboard tests: owner-only access, limited account identity, bound queries, sequence pagination and text-only rendering.
- Mobile tests: privacy allowlist, retry ID stability, anonymous-to-login association, logout/account switch separation, expired-login queue preservation and tap boundary privacy.
- A guarded PostgreSQL concurrency test is in `runtime/user-journey.integration.test.ts`. Run only against a disposable database whose URL includes `jyotara_qa_journey_141`, with `QA_MIGRATIONS` set to the repository migration directory. It must never run against production.
