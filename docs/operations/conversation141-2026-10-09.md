# Conversation and activity update — build 141

Scope: AST-190, implementation authorized 9 October 2026. Preserve approved Bronze Eclipse UI, fonts and artwork.

## Delivered scope

- One conversational Ask mode; Standard/Detailed selectors and upgrades removed for new conversations. Legacy uncertain requests retain their original mode, consent, context and receipt identity.
- End Chat confirms and exits; Back keeps the conversation open. Conversation history remains available. No new timed debit is activated.
- Repeated per-answer price labels removed from message bubbles. Current actual per-answer rates disclosed once before Start Chat and frozen to the accepted schedule; changed rates require a new quote approval.
- Compact Ask header/categories, existing guide cards preserved. Complete thought bubbles with typing and readable individual pauses; no total delivery-speed budget.
- Full approved welcome animation better fills portrait screens; exact original video/art assets preserved.
- Matching adds a saved person through the shared Birth Chart form, retains calculated Rasi and supports deletion/retry with cleared deleted selections.
- Daily timing labels and explanations simplified in English and Tamil. Explore gratuitous availability-price wording removed.
- New responseMode=conversation uses full Divine source, adaptive grounded depth, latest exchange, 32 recent turns and up to 12 earlier exact user statements. Model unchanged. Unknown-time limited readings remain supported; no invented birth time.
- Private operational activity timeline: authenticated ingestion, offline bounded queue, retry deduplication, per-account ordering, 90-day retention and deletion cascade; owner dashboard /dashboard/user-journey. Metadata only, no OTPs, birth details, chat contents or payment credentials. Optional marketing consent remains independent.

## Pending scope

Items 2–3, timed billing and its backend-only billing clock, are not enabled. Rate per minute, rounding of partial minutes and timing policy must be approved before replacing live billing. The time-based final charge portion of item 4 is consequently pending. Existing prices and successful-answer-only charging remain active.

## Validation

Focused mobile and server tests cover reply pacing, End/Back navigation, accepted-price persistence, legacy uncertain delivery, guide-context isolation, Matching saved-profile operations, welcome framing, Daily copy, metadata allowlists/account isolation and wallet guards. Isolated real PostgreSQL tests verify timeline concurrency, duplicate retry and account-deletion cascade. Live synthetic English/Tamil provider checks verify full source forwarding. This is not a claim that every prior repository test or real OTP/payment was re-tested for this release.

No Play submission is part of this delivery. Samsung receives the normal package, same signing certificate, by replacement installation without uninstalling.

## Delivery evidence

Normal APK: `/Users/apple/Documents/Startup/Jyotara-1.0.2-build141-conversation-update.apk`; package `in.innovfix.jyotara`, version1.0.2/code141. SHA-256 `5e60398d6472e8831c75a0235d2f28cf9be99ffa93c0e6a65dbdad27346f58ed`. Existing upload certificate verified; all12 approved art/video assets are byte-identical to build140. Samsung replacement installation succeeded without uninstalling, account/saved profiles/1860-coin balance retained.

Samsung observed compact Ask header, no Standard/Detailed controls, hardwareBack retained chat, one Start Chat price disclosure, and a successful new Tanglish interview answer delivered in six complete thought bubbles. This practical unknown-time answer completed at0coins under the existing backend classification; no paid debit was forced. End Chat and Skip exited normally. First-party timeline recorded chat.send, chat.answer success and API HTTP200 without text or profile values.

Production API release `conversation141-20261009` is healthy;26 migrations verified after a protected database backup. Dashboard SELECT grants are restricted to the metadata timeline and existing account ID/lastfour. Activity dashboard owner query returns200; anonymous API returns401. Original provider cleanup endpoint was obsolete; corrected documented POST `/session/delete` with user/session identity and explicit deleted:true acknowledgement was verified in final fictional Tamil QA. Two earlier fictional QA sessions have unacknowledged cleanup because their capabilities were not retained; no customer session was queried or deleted during that diagnosis.

Final API suite235/235 and TypeScript checks pass. Mobile chat/navigation suite20/20, additional saved-retry/consent/guide-isolation suite6/6, peripheral suite36/36, journey/auth/marketing-consent suite20/20 and narrow analyzer pass. Journey/server/dashboard12tests and a real disposable PostgreSQL concurrency test pass. The separate broad mobile wallet test run contains three known stale/globalfixture failures, documented locally; focused consent and switching-pack isolation checks pass. No claim of full legacy test-suite success or real OTP/payment-provider retesting.

Final Daily phone review found overlapping Abhijit/Rahu ranges. A conditional EN/Tamil explanation now tells the user the actual caution interval and any remaining Focus time; original ranges and timeline remain intact. Eight new overlap tests and18 combined Daily/peripheral tests pass. Samsung also verified Matching Add new person opens the exact shared premium birth-details form; the untouched draft was cancelled, and no saved person was deleted during phone QA. Approved welcome fills the portrait screen and retains its title.
