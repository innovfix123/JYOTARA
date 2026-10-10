# Launch coin packs — 10 October 2026

The owner approved the six launch packs and explicitly confirmed ₹49 for 200 coins. This is a backend-only catalog change for clients requesting wallet catalog 2, including normal APK147. The app renders the server-supplied pack quantities. Reopen the coin wallet to refresh an already-open screen. No APK/AAB rebuild, Samsung installation or Play publication was performed. Older catalog-1 clients retain their supported per-answer packs until updated.

## Activated new-purchase catalog

- ₹25: 100 coins, previously 40. Ask-only: two paid windows with 20 coins left.
- ₹49: 200 coins, previously 80. Ask-only: five paid windows.
- ₹99: 440 coins, previously 170. Ask-only: eleven paid windows.
- ₹199: 920 coins, previously 360. Ask-only: twenty-three paid windows.
- ₹499: 2,400 coins, previously 960. Ask-only: sixty paid windows.
- ₹999: 5,000 coins, previously 2,000. Ask-only: one hundred twenty-five paid windows.

All packs retain their existing IDs and rupee prices. Ask remains 40 coins per question-started paid minute. Provider waiting is excluded, and idle reading alone does not start another charge. Matching remains 15 coins for a new result; personal Explore remains 5; Daily remains free. Using coins on another feature reduces the Ask-only count. No extra Matching/Explore entitlement, coin grant or trial recovery was added.

Existing orders snapshot price and coin quantity; capture, retry and refund use these stored values. Previous balances are not increased or reduced. No live pending minute-catalog order existed at the deployment check. An old pending order can still settle for its original quantity; the existing app rejects a resumed checkout whose stored quantity differs from a newly displayed pack. This change does not alter that client safeguard or implement the cancelled payment-recovery work.

## Verification

All 284 API unit tests passed, along with TypeScript, production server build and whitespace checks. Fifteen isolated PostgreSQL integration checks passed: two new launch catalog tests and thirteen existing wallet, minute billing, notifications and trial checks. The new tests exercise both live/test wallet code with synthetic gateway transport: six purchase contracts, ignored client coin/amount tampering, exact-amount validation, duplicate captures, refunds, unauthenticated access, legacy catalog isolation, old paid balances and old pending-order retry/capture. No real payment, OTP/SMS, Divine/OpenRouter generation or customer data mutation was used for testing.

The trial migration regression initially lacked its required pre-migration historical fixtures. Its private runner was corrected to seed historical trial/purchase states before migration 0032, and all eight trial checks then passed. No trial product code changed. Disposable QA databases were removed.

Deployment confirmed local/public health, unchanged environment/app configuration/Terms, 32 verified migrations, no disabled packs, the active compiled six-pack values and anonymous wallet rejection with HTTP401. These checks do not establish a complete real-payment or Samsung UI test.

## Release and rollback

Active release: `/opt/jyotara/releases/launch-packs147-20261010`.
Server SHA256: `783c69f540d0940eeab07940e3f984eca7f978ca84536b99f6945d00ab8cbcc2`.
Previous release: `/opt/jyotara/releases/phone-trial147-20261010`.
Activated: 10 October 2026, 12:52:49 UTC / 18:22:49 IST.
Protected backup: `/var/backups/jyotara/launch-packs147-20261010`.

The guarded deployment preserved a validated database dump and prior code/configuration/policy copies. No schema/configuration/policy change was needed. Roll back the code symlink and restart the service if required; do not restore a database over later customer transactions. Orders created under the launch catalog retain their original purchased values after a code rollback.

Review actual consumption and retained amounts next sprint. The earlier ₹7.26 per paid Ask minute is an illustrative contribution after selected costs at the entry-pack value, not guaranteed profit. Discounts change the effective paid-minute price by pack; marketing/other costs and volume assumptions matter. The financial canvas preserves these assumptions and alternatives. No marketing automation was scheduled by this change.

Play publication remains on hold. Previously recorded billing-program, Data Safety and security requirements remain separate. Cancelled AST-196 dashboard/reliability/payment-recovery work remains cancelled.
