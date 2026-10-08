# Jyotara remote settings

Implemented 25 September 2026; mobile build 93. Read-only public endpoint: `https://api.jyotara.in/api/app-config`. This endpoint contains public settings only, never credentials. Mobile refreshes on app start/resume and tab changes, throttled to 30 seconds; server caches for 5 seconds. Saved validated settings remain available after fetch failure. A new installation uses built-in defaults. No executable code is downloaded.

## Supported controls

- Enable/disable chat, Daily, matching, Explore and new coin purchases.
- Disable Detailed (default), selected guides, languages and existing coin packs.
- Change per-answer and matching coin charges; future quotes enforce server prices.
- Change guide descriptions, chat welcome copy per language, an announcement, support email and additional Explore text cards.
- Maintenance pauses new supported calculation/payment creation requests. Existing payment callbacks, verification and recovery remain available.

The current release does not remotely replace arbitrary layouts, native SDKs, app icons, permissions or animations. Existing coin-pack prices/quantities remain server definitions; the JSON control hides packs. Provider credentials remain server secrets. Hiding an option does not erase previously saved answers.

## Operator update

Use authenticated SSH. Read `/opt/jyotara/config/app-config.json`, edit only supported fields, and increment `revision`. Upload the candidate JSON, then run:

```
/opt/jyotara-node/bin/node /opt/jyotara/current/scripts/app-config-admin.mjs INPUT.json /opt/jyotara/config/app-config.json
```

The strict validator rejects malformed/oversized data and invalid coin charges. Application is atomic. Directory is root:jyotara mode2750; settings are mode640, readable by the service. Do not place secrets here. The preceding settings are saved as `app-config.json.previous`. To roll back settings, copy previous content to a candidate with a new higher revision and apply through the same command. Confirm the public response and app behavior. No API restart is needed for a settings-only change.

Server code rollback: `server.before-remote-config-20260925.mjs` and `/etc/jyotara/api.env.before-remote-config` preserve pre-deployment state. Rollback code through SSH with an integrity check and restart `jyotara-api`. Do not replace unrelated later changes.

## Release verification and remaining work

184 API tests pass, including maintenance/payment recovery and old-client feature enforcement. 13 targeted mobile tests pass, including native checkout verification and absence of Detailed. Flutter analysis of six changed modules is clean. Live configuration HTTP200 confirms revision1 with Detailed false; service is active and can read its configuration.

Security review confirms local-only PostgreSQL/API listener, restricted service user, root-only credential files, signed Razorpay webhooks and server-side payment verification. This is a targeted review, not a guarantee or a complete penetration test. No new real payment was initiated in this change.

Before public Google Play launch:

- Resolve Play digital-purchase billing requirements or applicable alternative-billing enrollment/integration. Working Razorpay checkout alone is insufficient evidence of compliance.
- Remove the office access dependency from the public release and enable/test public backend admission. Build93 retains current office access configuration, real SMS-only login and live Razorpay; it is not a final public release.
- Review host/cloud firewall rules: UFW is inactive; cloud firewall was not verified.
- Complete and exercise outage/payment alert delivery to the selected email/Slack destinations. Remote feature controls are not monitoring.
- Run end-to-end release checks for real SMS, successful/cancelled payment, wallet credit idempotency, each language, matching, deletion, privacy/Data Safety declarations and Play app bundle packaging.

Google policy references: https://support.google.com/googleplay/android-developer/answer/9858738 and https://support.google.com/googleplay/android-developer/answer/13306652

## Build94 public admission update (25 September 2026)

The office restriction listed above is resolved for build94. `apps/mobile/config/public-release.json` excludes office credentials and disables tester access while requiring real phone OTP. Backend public access/chat are enabled. Public wallets always select live mode and public paid actions enforce coin quotes. Legacy office builds remain compatible. No database account/balance migration was needed; returning users may need SMS sign-in again. Code/env rollback snapshots: `server.before-public94.mjs` and `/etc/jyotara/api.env.before-public94`.

184 API tests plus disposable-database HTTP integration passed. Public auth configuration returns200; anonymous wallet/chat/matching return401 phone_auth_required. Signed version94 APK verified. Remaining Play billing, alerting, language-reply investigation and release checks still apply. Samsung installation was unavailable because no device was connected.
