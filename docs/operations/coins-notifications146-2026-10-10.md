# Coins, Ask minutes and engagement notifications — build 146

Approved scope: one combined normal APK and AAB, server deployment and GitHub source update. Matching 15 coins; personal Explore 5 coins; Daily remains free. Prices are versioned so existing APKs retain a compatible catalog and receipt contract until updated.

## Behavior

- New coin packs: ₹25/40 coins, ₹49/80, ₹99/170, ₹199/360, ₹499/960, ₹999/2000. Existing balances and original pending order amounts are retained. Whole paid chat minutes use 40 coins; residual coins remain available for Matching or Explore.
- Ask reserves 40 coins on a substantive question. Its first useful answer starts 60 seconds of server-measured paid time. Questions begun within that window cost no additional minute; provider waiting time extends the window. Expiry alone never debits: another question starts the next paid minute. Confirmed failed answers refund a new reservation; ambiguous transport outcomes recover the original saved request. Ending chat does not round idle time into another charge.
- New Matching uses catalog 2 and costs 15 coins. Older APKs require 20 and remain on their displayed supported rate. Names/language/presentation do not create a new paid comparison; saved results reopen free. The client rejects a quote that differs from its displayed current rate before calling the provider.
- Personal generated Explore readings cost 5 coins in the new catalog. Know Myself includes a generated personality/strength reading; basic calculated facts remain available. Limited unknown-time general guidance stays free. Daily horoscope is unchanged and free.
- Notifications require optional app choice and Android permission. Account/login-bound encrypted FCM token registration, language and app build enable backend targeting. New/returning inactive users can receive a reminder after five minutes; other reminders prioritize less-used Daily/Matching/Ask features. At most two engagement campaigns per account/day, including the inactivity reminder; quiet hours 21:00–09:00 IST. Active feature use suppresses the inactivity reminder. Sign-out/disable invalidates the device registration. Campaign acceptance, client receipt and opening are distinct outcomes; FCM acceptance does not prove delivery.
- Journey metadata records fixed action names and outcomes, excluding typed private values. Notification content contains no birth details or chat text. Optional research-sharing consent governs chat content separately. Retention remains 90 days for account-linked diagnostics/campaign outcomes; account deletion cascades the new session/device/campaign tables.

## Server and rollback

Initial release `/opt/jyotara/releases/billing146-20261010` applied additive migrations 0028 and 0029 (29 total). Protected database/env backup: `/var/backups/jyotara/billing146-20261010`.
Final active release `/opt/jyotara/releases/billing146-prices-20261010`; bundle SHA256 `bd2ac3829d6e107c0533d9f6a668386d3a89b83b632ee5d63ec48bd454b4ebf9`. App-config revision 3 adds matchingV2=15 and explore=5 while retaining matching=20 for older clients. Config/rollback snapshot `/var/backups/jyotara/billing146-prices-20261010`. Healthy running process retains Ask Gemini 3.8 Flash and engagement enabled. Credential stays server-side, with restricted service-readable permissions.
Rollback code/config only; additive migrations remain. Never restore an earlier database over subsequent customer payments or balances.

## Verification

277 API tests pass; TypeScript and server build pass. Five isolated real-Postgres suites pass using disposable synthetic accounts and no provider credentials: old test/live payment wallets; new test/live minute, Explore and Matching charges; notification targeting/encryption/ownership/disable/deletion. Includes concurrent captures, retries, failed answer refund, no unbilled retry of refunded readings, old orders, idle-time no debit and lower new-version Matching price.
Eight focused mobile Matching/dispatch checks pass with live-wallet/minute flags; eight retry/context/Explore checks pass; minute consent rate/owner check passes. Flutter analysis has no errors, with an existing unused ReadingCard warning and nine style infos. A combined legacy wallet-widget fixture has a cross-test async-state issue; individual wallet checks were used, not a claimed full mobile suite pass.

## Release limitations and required Play work

Play production remains version 1.0.2/code 107. Read-only Monetisation setup shows no alternative-billing enrollment, billing profile or billing-choice enrollment. Razorpay digital coin sales in a Play-distributed APK require the applicable Google Play billing program, owner setup and required SDK/transaction-reporting integration. Do not submit or roll out this draft until that gap is resolved. Merely accepting enrollment does not implement the missing app/server integration. Primary policy: https://support.google.com/googleplay/android-developer/answer/13306652?hl=en .
A 70% profit target is not guaranteed; measured API usage, payment fees, taxes, Play fees, hosting, OTP and marketing remain actual costs. No real purchase or OTP test is claimed for this update. Existing Play crash report for code107 (FlutterSecureStorage initialization) observed; not reproduced or fixed by this pricing scope. Existing cancelled AST-196 reliability/payment-recovery/dashboard work remains cancelled.

## Delivered artifacts and device proof

Normal APK `/Users/apple/Documents/Startup/Jyotara-1.0.2-build146-coins-notifications.apk`, SHA256 `311d1fee6ee2bf37303b2b7b6b3f0bd55baf88476d7835b2ffc51ec014538b22`. AAB `/Users/apple/Documents/Startup/Jyotara-1.0.2-build146.aab`, SHA256 `d690a8cab53bbfc768d87dfac5d28a421f9094a8ebd083b7f986e5dbf40a23a1`. Package `in.innovfix.jyotara`, version1.0.2/code146, target36/min24, three ABIs, release build. Original upload signing certificate SHA256 `27b72556a1835686a1c66e64dfdc5c0167a88e1fd11b3500b1f2ef29b8ce68bf`. ZIP integrity and all96 product artwork/video asset bytes match145.

Installed on Samsung SM_M076B using replacement install, with no uninstall or data reset. Installed base.apk SHA256 exactly matches delivered APK. Existing1955-coin balance retained; six new packs visible in wallet, personal Explore buttons show5coins, and Daily opens without a debit. Optional reminder prompt and Android notification permission accepted for this explicitly authorized phone test. Backend confirms one account-bound enabled build146 device. One manual Samsung-only QA campaign arrived and opening it navigated to Daily; the protected server campaign records opened=true. Background delivery did not claim a foreground received timestamp. This manual authorized test occurred during quiet hours; the automatic worker was not changed or run with a fake clock. The test counts toward the same daily cap. The first private test helper failed before dispatch because it used only the newer secret variable name; the helper was corrected to use the existing alias and the same campaign resumed, avoiding a second campaign/debit. No app/server credential or signing change.

The personal Explore confirmation showed 5 coins on Samsung and was cancelled before submission. Returning to Explore retained the same 1955-coin balance; no paid reading/provider request was made for this quote check.

## Play upload

AAB146 uploaded and processed in production draft6, named `1.0.2 (146) – Coins and reminders`. Release notes saved, Draft status verified in Production/Releases. No send-for-review, final release Save, rollout or publication performed. Production107 remains available on Play. Preview has one download-size warning:119MB device download,53.2MB increase compared with107; device support unchanged. Existing approved images/videos retained rather than introducing an unapproved asset change. Draft proof: `docs/qa/2026-10-10/billing146/play-draft.jpg` (private). Monetisation setup remains open for owner handoff; billing integration is still required after enrollment.

The source and focused tests are included with this operation record. The confirmed GitHub commit/push is recorded in the cumulative IDEA-LOG.md outside this repository. Private QA screenshots, test helpers, credentials, finance and design artifacts are excluded.
