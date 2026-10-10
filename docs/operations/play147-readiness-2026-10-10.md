# Play release 147 preparation and submission — 10 October 2026

Current status at approximately 19:19 IST: the user reaffirmed submission with Razorpay retained as the only payment flow. Version 1.0.2 (147) and the corrected Data Safety declaration were submitted using `saran@innovfix.in`. Console displayed **Changes in review** and **2 changes sent for review**, with automated quick checks still running; Google review is queued until those checks succeed. This is not approval or a completed rollout. Version107 remains available on Google Play. Managed publishing remains off, so an approved release is scheduled for full rollout without another manual publishing step.

The checks and unresolved findings below remain applicable. No billing integration, app/backend change, APK rebuild, merchant setup or program enrollment was performed in this submission. The current Razorpay-only digital-coin flow has no verified applicable exemption; the user was informed before submission that approval could not be promised. Submission capability is separate from payment-policy compliance.

## Artifact and release checks

- Bundle: `/Users/apple/Documents/Startup/Jyotara-1.0.2-build147.aab`, 172,732,847 bytes; SHA256 `63e508422754a391f8ebd9010fd552a1da4a0fa51ea7e8f8d197f193327ab186`.
- Original upload certificate: SHA256 `27b72556a1835686a1c66e64dfdc5c0167a88e1fd11b3500b1f2ef29b8ce68bf`.
- ZIP integrity and signatures verified. All 96 product artwork/video/font assets and all three ABI app libraries match the approved normal APK147. This is an app-bundle build of the existing product source, with no additional app/backend implementation.
- Play accepted the bundle: version code147, name1.0.2, package `in.innovfix.jyotara`, minSDK24, targetSDK36, three ABIs. Preview showed no validation errors, one download-size warning:119MB, +53.2MB versus107, estimated1m7s download. No loss of supported devices was shown. Validation is not policy approval or a reliability guarantee.
- Draft name: `1.0.2 (147) – Chat trial and launch packs`. English notes describe the one-time trial, 40-coin started paid-minute billing excluding answer waiting/idle reading,15-coin new Matching results,5-coin personal Explore and free Daily, optional reminders and profile/chat improvements.
- Samsung USB checks confirm normal APK147 is already installed. No reinstall, account reset, real OTP, payment or paid-chat test was performed during this release preparation.

## Backend and security checks

Active release remains `launch-packs147-20261010`, compiled SHA256 `783c69f540d0940eeab07940e3f984eca7f978ca84536b99f6945d00ab8cbcc2`. Local/public health and privacy, Terms and deletion pages returned200 over HTTPS. App configuration enables chat, purchases, Daily, Matching and Explore with no maintenance restriction; the approved dynamic launch catalog is active for147. No server deployment/configuration or customer ledger change was made in this preparation.

The session's38 focused authentication, payment verification, chart-access, idempotency and journey tests passed. Thirteen known protected POST endpoints returned401 to unsigned requests. Initial wrong-method/path probes that returned404 are not counted as authenticated-access checks. Earlier284 unit and15 isolated PostgreSQL tests for the latest catalog are recorded separately in `launch-coin-packs-2026-10-10.md`; counts overlap and are not additional unique coverage. Provider configuration presence and a small successful usage sample do not establish credit sufficiency, load capacity or future reliability.

Unresolved findings from AST-197 were rechecked:

1. Public OTP still has a shared200/day quota and phone cooldowns, without per-source protection. The read-only18:38IST snapshot showed2 used. Marketing traffic or abuse can exhaust that quota. A bounded authentication fix is backend-only; quota policy and provider capacity need review.
2. Refunded failed-guidance retries are rejected for minute billing and personal Explore, but the older per-answer path is not covered by that guard. A retry edge case for older clients remains. This is a backend finding; no cancelled payment-recovery/reliability implementation was resumed.
3. Rendered couple-share PNG/MP4 files with names/captions are kept in app-private cache; old files are removed at a subsequent share, rather than at account deletion. The native deletion/purge correction requires app code and a new combined APK. Clearing a single test phone does not fix other installations.

No high-traffic load test or new real gateway transaction was run here. These checks do not prove perfect security or an app without bugs.

## Console declarations saved as a draft

The existing declaration already includes account/birth information, phone authentication, messages, purchases, diagnostics and usage events. A bounded correction was saved using **Save as draft**, then reloaded and verified:

- Added Other actions for retained custom feature events: collected, not ephemeral, required first-party collection; Analytics and Advertising/marketing purposes. Sharing covers optional Meta custom events with Analytics and Advertising/marketing purposes.
- App interactions: retained existing collection choices/purposes; added marketing purpose and sharing for optional Meta app events.
- Device/other IDs: retained optional collection/functionality/analytics/developer communications; added marketing purpose and optional SDK sharing for analytics/marketing.
- Purchase history: retained collected-only, optional, non-ephemeral, functionality/fraud purposes; added analytics and marketing for consented Singular verified revenue events. No Meta purchase event is sent by current first-party code, and Singular runs with restricted data sharing. Unverified partner postbacks are not assumed.

The whole declaration was not certified as a complete new third-party audit. Existing conservative personal/message disclosures remain. Account deletion and privacy URLs remain unchanged. No policy submission, backend privacy-page rewrite or app consent change was performed. Optional Meta/Singular measurement remains off until the user enables it; no phone, birth details or chat text is passed to these first-party event calls.

## Billing access and integration blocker

The existing Innovfix developer-account owner shown in Console is `jp@innovfix.in`. Saran has Admin/all permissions and can upload releases, but Alternative billing setup returned **You need permission**. These are distinct permissions. `jyotara29@gmail.com` was already signed in; the user explicitly authorized accepting its Play Console Terms and acceptance completed. That account led to developer signup, without access to the existing account. No new developer account, two-step verification setup, role change or payment profile was created.

During preparation, owner sign-in was opened with the email entered and password/verification left for the human. No owner authentication was completed. Owner login is necessary for this setup but not sufficient to complete payment compliance.

Current app code uses Razorpay only and has no Google Play Billing/user-choice integration. Console shows no applicable alternative-billing enrollment or merchant billing profile. The app sells digital coins for AI readings; an earlier release approval does not establish compliance for this payment flow. A supported billing path requires enrollment/configuration and implementation. The initial preparation held submission on this finding; the user subsequently reaffirmed proceeding with Razorpay only, and the release was sent for review without describing that flow as compliant. If using automated alternative billing, app choice-flow and backend transaction-reporting work are required; India's official documentation also describes manual reporting for qualifying non-automated participation, which must not be presumed approved. The current Razorpay-only flow does not offer Google Play Billing alongside it. Billing integration requires coordinated app/backend work and one combined release; owner enrollment alone does not solve missing code. No enrollment fees, merchant agreement or program terms were accepted by this work.

Primary references checked10October:

- [Google's India alternative-billing requirements](https://support.google.com/googleplay/android-developer/answer/13306652?hl=en).
- [Billing choice enrollment](https://support.google.com/googleplay/android-developer/answer/17161464) — region-specific; do not apply its AU/EEA/JP/UK fee table to India.
- [Data Safety requirements](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).
- [Singular Data Safety guide](https://support.singular.net/hc/en-us/articles/5755762951835-Submitting-the-Google-Play-Data-Safety-Section-Form).

Private evidence is under `docs/qa/2026-10-10/play147/`, including bundle verification, readiness/probe aggregates and Console screenshots. `submitted-for-review.jpg` shows release147 and Data Safety under Changes in review; `data-safety-saved-for-review.jpg` records the final declaration preview. Credentials, customer identities and private QA are excluded from Git publication. Remaining requirements are successful automated checks, Google's review decision and any requested corrections; payment compliance, outstanding security findings and release verification remain unresolved. The cancelled AST-196 dashboard/reliability/payment-recovery implementation remains cancelled.
