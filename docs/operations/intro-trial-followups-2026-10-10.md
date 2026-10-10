# Introductory trial follow-up failure — backend correction

On 10 October the user reported a key-related error during Samsung's APK147 trial. Diagnosis found a successful first zero-coin answer through Divine and OpenRouter, followed by HTTP409 before any second provider dispatch. The original minute expired normally afterwards. Provider credentials worked; no key rotation or model change was needed.

## Cause and correction

The legacy `wallet_trial_once` / `live_wallet_trial_once` unique indexes allowed only one reserved/completed free-answer row per account. A minute-long introductory chat marked every successful trial answer as a free trial, so inserting its second answer violated that older one-answer constraint.

Migration0031 retains the unique allowance for legacy rows without a billing session. Server-owned minute trials remain limited by account/session/guide ownership and expiry. The wallet now writes the verified billing session in the initial reservation INSERT; writing it in a later UPDATE would still hit the legacy index first. The same correction covers live and sandbox wallets. Request hashes, quote validation, payment verification, paid prices and retry/ownership rules remain in force.

This is backend-only. The existing APK147 supports the corrected contract. No mobile change, new APK, AAB, model/key change or Play upload is part of this fix.

## Verification and test correction

The strengthened trial test first reproduced HTTP409 with the exact legacy unique-index error in an isolated database using the old 30-migration schema. The earlier trial test did not assert the follow-up response status, and its handler assertions were never reached on this failure. Its remaining-time assertion could therefore pass without a completed second answer. Each normal helper response now must return HTTP200; the follow-up handler must run exactly once.

After migration0031 and the reservation fix, eight isolated PostgreSQL integration scenarios pass, including multiple trial answers, English/Tanglish/Tamil switching, profile correction, expiry, zero deductions, legacy uniqueness, ownership, paid billing/recovery and notification rules. All277 API unit tests, TypeScript checking and server build pass. No customer database was used for synthetic cases.

## Live deployment

Active release: `/opt/jyotara/releases/intro147-followups-20261010`.
Server SHA256: `43793c672fee56cc0527c5eb8a648ba28157deb5b3d936cc69567429f69a3e32`.
Protected backup: `/var/backups/jyotara/intro147-followups-20261010`; pg_dump validated before applying31 verified migrations. Stable dependencies point to the shared office-access release, not through `current`.

Local and public health pass. Environment, app configuration, prices and public Terms hashes are unchanged. Code rollback may retain migration0031, but the old reservation code would still fail trial follow-ups. Do not restore a database over later customer transactions or blindly recreate the old unique index over multiple legitimate trial rows.

The affected Samsung test account received a narrowly recorded trial recovery so the failed scenario could be tested without a recharge or new account deletion. No coins were added and no payment was made. General trial eligibility was not changed. A private support/QA audit records the recovery; its identifiers and phone evidence are excluded from GitHub.

## Samsung verification

The first live verification reply completed free. The follow-up draft was not dispatched before the countdown ended because of keyboard/tap transition timing, so no second-provider success was claimed for that attempt. The ordinary trial expiry opened packages. The account-specific QA allowance was restaged, and the phone automation was changed to read the actual Send button after the keyboard transition.

The next controlled Samsung check sent two distinct questions through the normal APK147 UI. Both completed successfully in the same active trial, each with a completed zero-coin trial receipt. Divine and OpenRouter returned HTTP200 for both answers; a further OpenRouter formatting attempt also completed. No duplicate-key failure or paid debit occurred. These are real provider responses, separate from synthetic integration checks.

After the smoke test, the same narrowly scoped test account was left with an active allowance whose timer starts at its next useful answer, so the user can try it themselves. No new account deletion, OTP, wallet credit or payment was needed. The existing APK147 was retained. Store publication remains deferred and its separate billing/Data Safety/security work remains pending.
