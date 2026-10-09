# Daily, Ask, typography and saved profiles — build 142

User-approved scope: AST-191, AST-192, AST-193 and AST-194. Normal Android package `in.innovfix.jyotara`, version 1.0.2/code142. This release changes the existing app rather than creating a testing flavor.

## Implemented behavior

- Daily retains the existing Bronze Eclipse palette, lotus, current-city picker, Today/Tomorrow and other reading content. The compact timing entry opens the exact approved eight-second celestial animation, followed by the selected provider timings on separate 24-hour focus/caution lanes, an actual Now marker, conditional overlap explanation and up to three concise source-reading statements. No new scores or invented timing windows. Early skip/reduced motion waits for city restoration and selected reading/calendar requests before capturing data. Includes muted playback, background pause/resume, decoder/stall fallback, disposal and native image sharing.
- Ask uses local Soft Bronze colours, compact existing circular portraits, names, language labels and Chat actions. No experience years, Tarot or reconnect prompts were added. There is no verified public review source, so cards show localized “No ratings yet”, without copying illustrative demo scores. Existing remote availability, identity mapping, filters and history remain active. Conversation colouring stays local; receipt/context, accepted-price consent, provider calls, reply pacing, Back and End Chat behavior remain unchanged.
- Inter supplies app text, including the historical editorial alias. Roboto supplies conversation text, header, controls and composer. Noto Sans Tamil supplies bundled Tamil fallback. Real static weights400/500/600/700 and all three SIL OFL licenses are bundled for offline rendering.
- Saved people have explicit named Delete person actions in Matching pickers and selected cards, Ask's profile picker and the saved-profile library. English/Tamil confirmation targets one saved person. The primary profile, account/coins and other people are protected. Existing authoritative KundliLibrary.remove handles server/local deletion and retry. Matching also removes legacy locally saved people. Loaded account namespaces are pinned, stale lists/selections cleared on account changes, active requests protected and pending deletion blocks matching. A local enrichment barrier prevents a background Rasi write from restoring a removed person.

## Validation

Focused suites passed: 23 Daily tests; 16 Daily/Home checks before the final loading patch; 17 Ask/chat/navigation tests plus4 native visual tests;8 typography/onboarding tests;19 Ask/library/profile deletion tests;13 Matching/deletion/server-session tests plus4 wallet regressions. These suites overlap and are not a combined unique test count. Read-only integration review found loading, chart alignment and deletion concurrency defects; the final scoped patches and regression tests resolve them. Narrow analyzers report no new issues; discovery_screens.dart retains the existing unused _ReadingCard warning.

Normal build flags retain real phone authentication, real-SMS-only, live wallet, public chat and the existing private Singular configuration. No testing login/OTP flavor or new model was enabled. No backend source/deployment or Google Play submission is included. Existing timed-billing decisions remain outside this visual/profile update; this release does not activate them.

The master animation is portrait2160×3840/24fps. The bundled mobile rendition is1080×1920/24fps, eight seconds, H264, silent, preserving the approved frames/aspect and native letterboxing for smooth phone playback. The original4K master and generation provenance are retained in Startup/source/design/daily192.

## Delivery evidence

Final shareable APK: `/Users/apple/Documents/Startup/Jyotara-1.0.2-build142-daily-ask-fonts.apk` (174,452,202 bytes), SHA256 `361fe94c1f81bcde712950c22773f4dada58ec436deaa1b7305024900495e2d8`. Signature matches the existing upload certificate; ZIP integrity, package/version, all 14 new font/media assets and compiled loading/deletion patches were verified. All 79 prior image/video assets remain byte-identical to build141.

Samsung SM_M076B, serial R9ZL50RRRLY: replacement install succeeded without uninstalling. SHA256 read from the installed base.apk exactly matches the final shareable APK above. The final Home capture shows the existing signed-in account and wallet; no data reset was used. Earlier physical checks exercised the approved Daily video through automatic completion, actual provider timing lanes/overlap, the compact Ask roster and native sharing chooser. The chooser was canceled without sending. Chat rendering/navigation and saved-person deletion were tested with regression fixtures; the attempted live chat screen check was interrupted, so it is not claimed as a live provider validation.

No actual customer profile deletion, paid answer, real SMS OTP or real recharge was performed by this validation. Private phone captures and the installed-artifact record remain under docs/qa/2026-10-09/daily-ask142 and are excluded from any source commit. No Google Play upload was performed.
