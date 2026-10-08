# OTP autofill — 2026-10-07

Implemented in the app source; pending inclusion in the final combined APK and real SMS verification on Samsung. No APK was generated/installed or uploaded to Google Play for this change.

The previous implementation exposed only a keyboard/autofill hint. The new implementation uses Google's SMS User Consent flow through play-services-auth-api-phone 18.3.1. It starts listening before /auth/send, waits up to five minutes for one new message, and asks the user to approve that message. Only an unambiguous six-digit code crosses into Flutter; it fills the OTP field, without automatically submitting it. SMS text is not logged, stored, or sent to the backend/analytics. No READ_SMS or RECEIVE_SMS permissions were added. Google broadcasts require the Google-owned SEND permission on the registered receiver, not a permission requested by the app.

Logout, change-number, successful sign-in, widget disposal, timeout and cancelled approval invalidate the listener. Native attempt IDs and Flutter generations ignore delayed callbacks for previous attempts. A new challenge clears old OTP text. Startup failure/unavailable Play services/denied consent fall back to manual entry; waiting for native startup is bounded to two seconds. Repeated Continue taps during listener startup are guarded.

Validation: 13 focused Flutter tests passed, including current code accepted once, old/cancelled callbacks ignored, unavailable service fallback, logout/restart and existing OTP verification checks. Targeted Flutter analysis is clean. :app:compileReleaseKotlin passed against the actual Android project. This does not prove real SMS delivery/consent behaviour on Samsung yet.

Device QA after combined APK installation: sign out, enter own number, Continue, wait for fresh SMS, tap Allow in Google's message dialog; field should fill and Verify should sign in. Repeat with Change number, resend, denial and logout. Do not read or log unrelated messages; do not approve the system prompt for the user.

Fully silent SMS Retriever is not implemented in this change. Existing backend sends a fixed Authkey SID and OTP; it does not pass an app hash. Provider template content/approval was not inspected or modified. Silent retrieval needs a compatible approved template containing the correct app hash derived from the installed signing certificate; Google Play's signing certificate can differ from locally signed APKs. Do not promise silent autofill until that template and real Play-signed flow are verified.

Google reference: https://developers.google.com/identity/sms-retriever/user-consent/request
