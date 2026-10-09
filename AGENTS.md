# Jyotara change and release communication

Before implementing a change, tell the user whether it is backend-only, app/frontend-only, or both, and whether existing installed APKs support it or a new APK is required. Explain any app/server contract dependency. Documentation and read-only checks do not require an APK.

Prefer supported backend changes without APK rebuilds. Combine approved app changes into one release rather than making a separate APK for each fix. Distinguish APK from API; clarify ambiguous wording before changing either when the difference changes the work.

The backend reliability/payment-recovery/dashboard implementation cancelled by the user on 9 October 2026 remains cancelled unless explicitly reauthorized. A security review does not authorize resuming those abandoned changes. Keep unrelated private QA, design, finance and credential files out of source commits.

Before a Play release, check authentication, account/profile ownership, payment and coin verification, sensitive-data handling and release configuration. Report concrete verified findings, test limitations and remaining material risks. State backend/frontend and APK impact before fixing a finding. Never claim that tests prove perfect security or an app without bugs.

The cumulative product decision record is `/Users/apple/Documents/Startup/IDEA-LOG.md`; read it before recalling or changing product direction. Preserve decisions and cancelled work rather than treating a later task as permission to resume them.
