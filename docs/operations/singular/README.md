# Singular integration — 7 October 2026

Jyotara Android (`in.innovfix.jyotara`) was added to the existing Singular account from the activated invitation for saran@innovfix.in. Other company apps were not modified.

## App implementation

- Flutter SDK 1.9.1 / Android SDK 12.16.1.
- Private SDK build configuration: `/Users/apple/.config/jyotara/singular/build113.json`; SDK credentials are not committed to the repository. These are the client SDK credentials, not a Reporting API key.
- Separate **Marketing measurement** consent in Account settings. Off by default, including for users who previously enabled Firebase analytics. Startup does not initialize Singular without this consent. Revocation calls stopAllTracking; re-enabling resumes tracking.
- Advertising identifiers and third-party data sharing are restricted. Android AD_ID remains removed. No names, phone numbers, email, birth details, question/answer text, Jyotara session tokens or custom account identifiers are supplied.
- SDK automatically measures sessions/install attribution after consent. Counts cover consenting updated installations; this is not the total number of Play Store downloads or registered accounts.
- `measurement_started`: technical event when the consented SDK first starts in an app process, used to verify SDK event delivery.
- `login_success`: successful real OTP sign-in, not demo or invalid OTP.
- `chat_completed`: completed wallet reading, not a replay or incomplete response. No message content or astrology categories are sent.
- `recharge_started`: live wallet order created on this installation with consent.
- `recharge_verified`: INR gross recharge revenue after the backend returns paid status for that order. Amount is converted from paise to rupees. Local journal prevents repeat dispatch. Test orders, complimentary grants, cancelled/pending payments and historical purchases are excluded.

## Revenue limits

This is client marketing measurement, not accounting. A payment captured after the user leaves the app may be reported only when the app later loads that order. Orders outside the returned recent 30 orders, device changes, consent withdrawal, data erasure and SDK/network failures can omit revenue. Persist-before-dispatch provides at-most-once dispatch, not guaranteed delivery. Refund adjustments and backend S2S revenue reconciliation are not implemented. The existing server payment ledger is authoritative.

## Release and validation

- Signed normal APK: `/Users/apple/Documents/Startup/Jyotara-1.0.2-build113-singular.apk`.
- SHA-256: d782f147ac744e86dcb9b50fd6a010e38976a5cdbb0bfb4854224767cda478d2.
- Installed with replacement/update on Samsung R9ZL50RRRLY; package versionCode 113 verified. Existing account and coins retained.
- Static analysis of changed Flutter modules: no issues.
- Singular consent/revenue unit tests and OTP tests: 10 passed.
- Wallet native callback verification test passed. Combined wallet suite has three widget failures after earlier tests; the category/pricing and switching-pack cases pass in isolation. Record the full-suite failures rather than claim all tests passed. All three failing widget cases pass individually. Full-suite test isolation still needs investigation before a Play release.
- Live privacy page updated through privacy-only release `singular-privacy113-20261007`, cloned from `profile-edit112-20261006`. Server module syntax and release health activation passed; live `/privacy` contains Singular disclosure.
- No Play Console upload or release performed.
- Samsung Marketing measurement consent was enabled by the user and its checked state verified. Registered the generated SDK identifier as Jyotara Samsung QA in the Testing Console. Live session and measurement_started events from the final shared build 113 appeared for Jyotara / in.innovfix.jyotara on 7 October 2026 at 12:19 (Singular console time). An earlier session also appeared at 12:15. Proof: docs/qa/2026-10-07/singular/live-session.png. Real recharge reception was not tested with a new payment.

## Account warning

Singular displays “Time is running out! Contact us to keep your account enabled.” Account subscription/trial continuity needs the owner or Singular account manager; no subscription or paid commitment was made.
