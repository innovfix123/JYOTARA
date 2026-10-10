# One introductory trial per verified phone number — 10 October 2026

The user approved preventing repeat introductory trials for the same number. This replaces AST-201's account-only eligibility rule. The change is backend-only: normal APK147 already understands available/unavailable trial status, resumes an active session and handles a rejected start. No new APK/AAB, Samsung account reset, coin grant or Play action was required.

## Behavior

A verified phone number can activate the introductory Ask allowance once. Logout, reinstall, another phone or account deletion followed by registration again cannot grant another allowance after activation. Returning to an active account resumes its original session and remaining time; it does not restart the trial. A failed provider answer can still be retried under that original trial. The existing timer starts with the first useful completed answer and excludes provider waiting. Concurrent starts return the same activated session.

Merely viewing or skipping the offer does not consume a number's allowance. Existing account-level skip behavior remains. Previous Ask users and paid buyers remain outside the new-user offer; deletion cannot reset those exclusions. The older one-free-answer route uses the same phone marker, so an older installed app cannot reclaim a free allowance after account recreation. Ordinary verified users use the live wallet; restricted office demo identities have a separate sandbox namespace.

The trial activation and its marker are written in the same database transaction. The unique `(mode, phone_hash)` primary key protects against simultaneous claims across requests/processes. The marker is not account-linked and has no cascading account foreign key. An offered account cannot start again if its number has already been claimed.

## Data and notices

Additive migration 0032 creates `phone_trial_claims` with only mode, the existing server-keyed phone hash and the first eligibility timestamp. It stores no full number, last-four digits, account/device identifier, name, birth details or conversation. It is a protected, linkable eligibility record, not an assertion of anonymous data. The table is not sent to advertising/analytics services. The normal account erasure flow preserves this eligibility exclusion and still removes account-linked profiles, sessions, chats, wallet and trial state.

The migration backfills active/ended trial holders, prior reserved/completed Ask users and paid buyers whose current phone account records remain. Account deletion retains the same exclusions for later users. Records for accounts already deleted before this deployment cannot be reconstructed from the current database; those historical numbers may not be recognised on their next registration. No private backups were mined to rebuild historical deleted identities. Future deletion/re-registration is covered from this deployment.

Public Terms 1.3, Privacy and account-deletion pages disclose the retained eligibility identifier and its purpose. The static Nginx Terms file matches the API page. Retain markers while the introductory offer remains available; pausing chat or the offer is not programme retirement. When the owner permanently retires the introductory programme, operations must disable its claim paths and delete these markers, consistent with the notice. Privacy requests require ownership verification and applicable review. Do not casually rotate the phone-auth HMAC key: current account identity and retained markers depend on it, so rotation requires a compatible migration. Ordinary provider API-key rotation does not change this identifier.

## Verification

All 284 API unit tests passed. TypeScript, production server build and whitespace checks passed. All 13 isolated PostgreSQL integration scenarios passed, including 5 new scenarios for migration backfill, real OTP-auth code with synthetic SMS transport in live/sandbox wallets, eight concurrent starts, same-number login and original-trial resumption, normal erasure and re-registration, legacy free-answer exclusion, paid-only erasure, another unused number and unused/skipped offers. Existing trial expiry/retry/latency/ownership, wallet/payment capture/refund and paid-minute billing regressions remained green.

Tests used a disposable QA database and generated synthetic phone identities. No real OTP/SMS, payment, Divine/OpenRouter request, customer deletion, Samsung trial recovery or additional allowance was performed. The QA database was removed after validation. No additional Samsung UI test was performed for this backend-only change; compatibility is verified against the existing 147 contract.

Live read-only checks confirmed the new bundle and 32 migrations, the table's three retained columns and lack of account foreign keys, coverage of all currently active/ended trial holders, public health/Terms/Privacy/deletion HTTP 200 and rejection of anonymous trial requests with 401. These checks are scoped regression evidence, not a universal security or bug-free guarantee.

## Release and rollback

Active release: `/opt/jyotara/releases/phone-trial147-20261010`.
Server SHA256: `005b919dc556950a93ffc1962703f1aead224a6a67f945ff04a1c52d6950f261`.
Previous release: `/opt/jyotara/releases/compact-chat147-20261010`.
Protected rollback backup: `/var/backups/jyotara/phone-trial147-20261010`.
Public Terms SHA256: `bb570604ea6701d4687fcfee875a1530882588c40fc8f0aa59bd16e5f3e0f7e1`.

Deployment validated prior/candidate hashes, stable dependencies and a protected database dump, applied migration 0032 atomically with checksum verification, activated the release and updated static Terms. Environment and app configuration hashes remained unchanged. The compact reply formatter, provider keys/model, prices, packs, paid-minute rules and tracking remain as before.

If rollback is required, restore the prior code link and backed-up static Terms, then verify service health. Keep the additive schema/markers; do not restore a database backup over subsequent customer transactions. The prior code ignores the new marker, so code rollback temporarily removes this repeat-trial protection. Repair and reapply promptly rather than dropping customer evidence.

The user's Play publication hold and separate billing-program/integration, Data Safety and previously recorded security work remain pending. Cancelled AST-196 work remains cancelled. Private QA scripts/output stay out of source commits.
