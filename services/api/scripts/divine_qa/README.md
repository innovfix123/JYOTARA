# Divine hosted-chat candidate checks

This is an offline evaluation tool. It does not change Jyotara's provider or
production routes, and it does not use OpenRouter. Use fictional data only.

Run from services/api/scripts/divine_qa:

    python3 -m unittest test_client.py
    python3 conversation.py --output /absolute/private/output-directory

The tool reads ~/.config/jyotara/divine.env. Never commit this file or put the
key into the APK. The supplied scenario uses fictional Kavin, 12 June 2001,
06:20 IST, Chennai. Each language has a separate provider session. Birth details
are sent only on its first turn. Corrections use the same conversation.

## Findings and limits

Direct JSON responses previously included mid-sentence answers despite
`grounding: ok`. In three subsequent `length_cap: full` probes, the reported
output-token count was exactly 400 in every language. English was substantially
longer than Tamil. This is evidence of an output allowance, not proof of the
provider's internal truncation algorithm. Full length with concise language
instructions is a candidate workaround, not a provider bug fix.

The client rejects missing answers, obvious unfinished endings, unclosed curly
quotations, language-script mismatches, and answers over 100 words. It permits
one explicit correction after a rejected response. Both charged responses are
retained in the results. It never automatically retries transport failures:
a timeout does not tell us whether a request was billed or saved.

`structurally_valid_needs_review` does NOT certify relevance, completeness of
meaning, chart accuracy, or truth of a prediction. Punctuation is not a semantic
evaluator. All returned answers require human review before a provider switch.
No raw streamed output is displayed. The client does not set confidence or
sensitivity overrides. Native provider rules continue to apply.

The 10-turn scenario tests night-shift corrections, no-money clarification,
family opposition, dasha explanation, simplification, an already completed
conversation, a two-month waiting agreement, and final memory recall.

## Release gate

Keep this candidate disabled until incomplete output, repetition, localization,
profile separation, semantic correctness, account deletion/provider retention,
and billing/timeout behavior are acceptable. A provider session includes stored
birth details and messages; production deletion must propagate to the provider.
Reusing the QA repair prompts as hidden production user messages is not an
approved production design.

## 13 September 2026 replay

30 final responses passed structural checks after 32 calls (two recoveries).
All three final turns recalled family opposition and the two-month agreement.
Repeated placements and formulaic uncertainty remain. Some relationship
interpretations are not independently verified. Three full-length diagnostics
plus the replay cost 1,050 chatbot credits; final reported balance was 2,960.
No release activation was performed. Results remain outside the repository.
