# Ask chat renewal incident — 2026-10-03

User reported no answers on two phones. Screenshot showed “Check the device clock before renewing chat access” with Tamil/Detailed selected. Device clock offsets have not been measured; the failure path is verified in code.

The app compared its local clock against the renewal response's server timestamp with zero tolerance. A phone slightly behind the server could reject a successful renewal before submitting a question. Server NTP synchronization was verified.

## Deployed correction

The Divine renewal response now returns compatibility metadata starting five minutes before server time, with an exact 24-hour span for installed clients. Its expiry never exceeds the server-authorized expiry, including the final renewal day. Signed tickets, account ownership, deletion checks and fixed renewal boundaries remain unchanged. No balance adjustments or paid retries were performed.

Mobile source also allows up to five minutes of negative clock skew while retaining expiry checks. This mobile change is not yet built or distributed.

15 backend tests and 5 ProfileSession tests passed. They cover clock skew, expiry boundaries, ownership, ticket tampering and guidance idempotency. Deployed bundle checksum: a8200cfdd24a2fc8d00ca91d7a173f60972ea0742d3a20551d73e80f56ec1adf. Service active and public health endpoint HTTP 200 after deployment.

Rollback bundle: /opt/jyotara/server.before-clock-fix-20261003.mjs.

## Follow-up

Retry on the two affected phones. No successful end-to-end answer on those phones has yet been observed. Large clock errors or local timestamps in the future can still require automatic device time or an updated APK. This fix does not establish provider availability for every paid chat request.

## Provider authentication migration (later October 3)

Subsequent failed request receipts showed Divine HTTP 401, separately from the clock issue. Current Divine chat documentation now requires Authorization: Bearer plus x-api-key headers; prior documented body-only authentication no longer works. User supplied regenerated credentials; installed in root-only API environment without recording secrets here. Usage authentication returned 200 with both headers. Backend chat and cleanup headers migrated; API key removed from URL/body. Deployed after 14 consultation/idempotency tests passed. Public health returned 200.

Synthetic live Detailed tests: Tamil completed in 11.8 seconds; initial Tanglish edit failed numeric provenance validation. Translation instruction clarified to retain spelled-out numbers instead of introducing digits or numbered lists. Subsequent Tanglish completed in 11.3 seconds. Three synthetic readings consumed 150 provider credits, no customer coins. This verifies provider/editor path, not an on-device production account flow. Cleanup still uses the existing DELETE session endpoint with updated headers; provider deletion endpoint compatibility needs separate verification because earlier routes returned 404. No raw birth data or answers printed in diagnostic output.
