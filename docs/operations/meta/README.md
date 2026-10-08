# Meta Android SDK integration — 8 October 2026

Status: source integration and Android compilation verified. Activation, configured APK delivery and Meta dashboard event reception remain blocked on developer verification/app creation. No App ID or client token currently configured. No installed APK, Play upload or backend deployment performed by this change.

## Implementation

- Official com.facebook.android:facebook-core:18.3.0, pinned; native Flutter MethodChannel bridge.
- Private build environment inputs JYOTARA_META_APP_ID and JYOTARA_META_CLIENT_TOKEN. Missing configuration leaves the service unavailable and uninitialized. Never use the App Secret in the mobile app. The Install Referrer Decryption Key belongs in the MMP integration, not the APK; it is not required for this native event bridge.
- Separate Meta measurement consent, default off; prior Singular consent does not enable Meta. Tamil/English disclosures added.
- Merged manifest removes FacebookInitProvider and AD_ID. Auto initialization, automatic events, advertising-ID collection and codeless debug logging disabled.
- On explicit consent: SDK initialization, analytics/conversion-only event usage setting, manual app-open event. Successful real OTP login and completed reading hooks log allowlisted generic names without personal identifiers, amounts, birth data or message content.
- No Meta purchase events. Singular remains the existing revenue measurement path to avoid an unverified duplicate purchase reporting path.
- Revocation blocks new events from Jyotara. SDK has no complete teardown in this implementation; in-flight requests and vendor background tasks can continue, and previously received records are not deleted. Do not claim full retroactive tracking erasure.
- Optional services subtitle and Meta privacy disclosure updated in editable backend source. Publish the privacy disclosure before delivering an activated public build; current hosted policy was not changed.

## Verification

Five Flutter Meta/Singular consent/revenue tests passed. Targeted Flutter analysis passed with no issues. Gradle compileDebugKotlin and processDebugMainManifest passed. Existing Kotlin/Gradle dependency deprecation warnings remain unrelated. Merged debug manifest inspected: provider absent, four Meta switches false, advertising-ID permission absent.

## Remaining

Complete Meta developer mobile verification in the existing browser. Create Jyotara Android Meta app, obtain App ID and client token privately, register in.innovfix.jyotara and correct signing hashes, configure ad-account/partner attribution as appropriate. Obtain Install Referrer Decryption Key for Singular separately. Build and deliver a configured signed APK, verify opt-in/off behavior on Android and prove live Meta event reception. Verify Singular Meta partner setup and subscription continuity separately. No claim of live Meta advertising attribution until that evidence exists.

Sources: https://github.com/facebook/facebook-android-sdk/releases and official SDK source at tag sdk-version-18.3.0.
