# Compact Ask replies — 10 October 2026

The user reported that long paragraphs were overwhelming and asked for a short, useful answer followed by one relevant question. This approved style replaces the earlier ordinary 120-word and requested-detail 220-word limits.

## Behavior and compatibility

This is backend-only. Normal APK147 already splits decoded blank lines into whole-thought bubbles with its existing pacing. No mobile contract, APK/AAB build, installation or Play action is required for the formatter change. Historical saved replies are retained; newly generated conversational replies use the revised limits.

Divine remains the reading source and OpenRouter remains the language editor. The existing Gemini 3.8 Flash selection is unchanged. Ordinary answers target 25–50 words total, at most 65, across at most three messages with at most 32 words per message. A current explicit request for detail allows at most 110 words, four messages and 45 words per message. Old history cannot automatically expand replies. Brief acknowledgements need no padding. Legacy Standard/Detailed and non-conversational readings retain their existing behavior.

An ordinary guidance turn should answer directly, explain one useful finding or condition when necessary, and end with one short relevant question. The prompt uses the latest correction and earlier user statements, avoids re-asking known details, and forbids withholding a known answer or adding pressure to stay/spend. No question is forced on thanks, goodbye, a complete single-fact answer, urgent safety guidance or an explicit request for no questions. No generic “anything else?” hook. The existing limited-birth-time adapter shares these concise prompts and bounds without inventing chart evidence.

Timing comes from the supplied reading; uncertainty and material conditions remain. Exact-source quotations, numeric grounding, language/completion and uncertainty checks remain. Long total output or an oversized single bubble is rejected, with one bounded formatting repair from the same source; the paid Divine reading is not repeated. No sentence truncation is introduced. These checks are not a semantic or astrological accuracy guarantee; follow-up relevance is instructed and sample-reviewed, not mechanically proven for every future reply.

## Validation

All 284 API unit tests pass, including seven new compact-conversation regression cases. TypeScript, the server build and Git whitespace checks pass. Tests cover a paragraph below the total cap exceeding the bubble cap, three languages with a preserved timing window and one closing question, a repair without another Divine call, context/known-detail handling, and bounded explicitly requested detail. Existing billing, ownership, retry, uncertainty and acknowledgement tests also remain green.

Seven real OpenRouter synthetic editor/unknown-time checks passed. Ordinary edited samples contained 30–54 words, retained supplied timing/uncertainty, and ended with a question. Three additional real full Divine-to-OpenRouter synthetic checks passed in English, Tamil and Tanglish, each with three short messages and one terminal question. Two initial edits needed one formatting repair each; each full-flow case made exactly one Divine read. Full-flow sample latency was 10–15 seconds, not a production-average promise. Total synthetic provider usage: 90 Divine credits and 12 OpenRouter attempts with reported$0.02422875 USD; no customer coin debit, OTP, payment, account deletion or trial reset. Private answers/provider receipts stay under docs/qa/2026-10-10/compact-chat, excluded from GitHub. No new live Samsung question was submitted in this change; compatibility is verified against the installed147 client code.

## Deployment and rollback

Active release `/opt/jyotara/releases/compact-chat147-20261010`.
Server SHA256 `e0edeafb2a7f8e3823d43d6fbc67e49807732b2e44b62335c9789d3d5e955fa2`.
Previous release `/opt/jyotara/releases/intro147-followups-20261010`.
Protected rollback/database backup `/var/backups/jyotara/compact-chat147-20261010`.

Guarded activation verified the prior and candidate hashes, stable dependency link, protected backup and local/public health. No database migration changed; 31 existing migrations remain. Environment, app configuration and public Terms hashes are unchanged. Models, provider keys, prices, packs, trial eligibility, payment verification, chat pacing and tracking remain unchanged. Code rollback restores the prior release link and service; do not restore the database over later customer transactions.

The user's Play publication hold and separate billing/Data Safety/security work remain pending. Cancelled AST-196 work stays cancelled.
