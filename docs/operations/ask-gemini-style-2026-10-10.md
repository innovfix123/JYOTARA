# Ask Gemini response update — 10 October 2026

The user approved deploying the prepared astrologer response style and clarified the desired Ask model as Gemini 3.8 Flash. This is a backend-only change supported by the existing mobile contract. No APK was rebuilt and nothing was submitted to Play Console.

## Result

Ask's protected model override is now `google/gemini-3.8-flash`, including its language editor and unknown-birth-time general guidance. The global `OPENROUTER_MODEL` remains `google/gemini-2.5-flash`; discovery translations and other global-model consumers are unchanged.

The editor leads with relevant indications and supplied timing windows rather than a stock inability statement. Default conversational replies target one or two complete thought messages and 35–75 words; the existing hard limits remain 120 words/three messages, or 220 words/four messages when the current user explicitly requests detail. Guide tone, conversation corrections, supported conditions and uncertainty remain part of the request. Unknown-time general help avoids repeated limitation messages and does not invent chart evidence.

Tamil date text translates month names while exact source excerpts remain unchanged in the internal provenance field. A narrowly matched, explicitly denied Tanglish guarantee no longer causes a false rejection; positive certainty claims remain rejected. The validator is a collection of syntactic checks, not proof of semantic or predictive accuracy.

This is prompt and configuration tuning, not a trained model-weight or fine-tuning job. Fictional example dates are not added as static forecasts. No customer conversations were used for model training. Timer billing, answer prices, coin packages, mobile pacing, authentication, ownership, erasure and provider-cost tracking remain unchanged. Cancelled reliability/payment-recovery/dashboard work remains cancelled.

## Verification

TypeScript validation, server bundling, diff checks and all 277 backend tests passed. Added tests cover supplied timing in English/Tamil/Tanglish, rejection and repair of an invented numeric date without another Divine charge, guarantees, separation of current source from earlier assistant claims, Tamil month rendering and the negated Tanglish certainty regression.

Seven synthetic cases exercised the actual editor request/validator or unknown-time adapter against OpenRouter. The first pass exposed two issues: untranslated month names in Tamil and a false rejection of a denied Tanglish guarantee. After correction, both failed cases completed on their first recheck. Other sampled cases included supported career timing, supported relationship timing, absence of a timing window, correction of an unsupported prior claim, pressure to invent a date and requested practical help without birth time.

There were nine OpenRouter attempts in total with reported inference cost $0.01440525. These were synthetic operator checks with no Divine calls, customer account changes or user coin charges. Synthetic language checks do not establish production average cost/latency, forecast accuracy, or a successful end-to-end customer chart reading. Real OTP/payment transactions and another Samsung chat were not run for this backend-only update. Exact local evidence remains in the private `docs/qa/2026-10-10/astrologer-style/` directory.

## Deployment

Activated at 10 October 2026, 01:14:49 IST (9 October 19:44:49 UTC).

- Active release: `/opt/jyotara/releases/astrologer145-20261010`
- Server SHA-256: `96b4acfbff9b5487f7267eb0344a4554dc86c9172aba97c897cf2f8598b16a63`
- Previous release: `/opt/jyotara/releases/chat145-20261009-ack`
- Previous environment and rollback metadata: `/var/backups/jyotara/astrologer145-20261010/`, directory mode 700, environment mode 600.

Activation validates the previous code, configuration and candidate checksum, changes only the Ask model setting, restarts the service and checks health. A failed activation restores both code and environment. No schema or database migration was performed. The running service's environment independently confirmed Ask Gemini 3.8 Flash and global Gemini 2.5 Flash. Public health returned HTTP 200; anonymous guidance-status access remained HTTP 401.

For rollback, restore the previous release symlink and its saved protected environment, restart `jyotara-api`, then verify health and model configuration. Do not restore an old database over current customer transactions.
