# Firebase integration — 17 September 2026

Android package: `in.innovfix.jyotara`; Firebase project: `jyotra-db0f4`.

Build 50 adds independently optional Analytics, Crashlytics and FCM settings in Account. All three default off. Advertising IDs and ad personalisation are disabled. Custom analytics events do not include birth details, phone numbers or chat text; Dart error reports use exception type rather than the exception message.

Verified on the connected Samsung:
- Signed upgrade from build 49 to build 50 succeeded without clearing application data.
- Firebase initialization succeeded; Analytics and Cloud Messaging V1 are enabled in Console.
- Enabled the three settings, granted Android notification permission and verified preferences persisted after restart.
- Created an explicitly synthetic FirebaseTest birth profile for navigation testing.
- A controlled `adb am crash` was received by Crashlytics: `CrashedByAdbException — shell-induced crash`, 1 crash / 1 user. This is a deliberate test, not an unexplained application crash.
- Analytics DebugView showed six events after device debug mode was enabled.
- A Console test targeted only the Samsung FCM registration token. Android displayed “Jyotara test” / “Samsung notification delivery test. No action needed.” Tapping it reopened Jyotara.
- The test-only token control is compiled only with `JYOTARA_FIREBASE_QA=true`; final build 50 omits that flag.
- `flutter analyze` passed.

Release boundaries:
- This does not verify Firebase Authentication; existing SMS login remains unchanged.
- FCM delivery is tested through Firebase Console. A backend for personalised/scheduled notifications is not implemented by this change.
- The privacy-policy source includes Firebase disclosures, but needs deployment. Play Data Safety must be updated for the Firebase SDK data collection before distributing this build publicly.
- Existing Play build 49 submission is unchanged. Build 50 is a Samsung test build, not a new Play submission.

Automated validation: full mobile suite finished with 157 passing, 1 skipped and 1 failure caused by the new Account settings pushing the Tamil birth-profile row below the viewport. Updated that existing test to scroll the row into the visible area, then reran all three UI-language tests successfully. Final non-QA APK installed successfully; device reports versionCode 50. Analytics debug mode was disabled after testing.
