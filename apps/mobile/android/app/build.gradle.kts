import java.util.Properties

plugins {
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play upload credentials live outside the repository.
val uploadProperties = Properties()
val uploadPropertiesPath = System.getenv("JYOTARA_UPLOAD_PROPERTIES")
if (!uploadPropertiesPath.isNullOrBlank()) {
    file(uploadPropertiesPath).inputStream().use { uploadProperties.load(it) }
}
val samsungTest = System.getenv("JYOTARA_SAMSUNG_TEST") == "true"
val playRelease = System.getenv("JYOTARA_PLAY_RELEASE") == "true"
if (samsungTest && playRelease) {
    throw GradleException("Samsung test builds must never be signed as Play releases")
}
if (playRelease && uploadProperties.isEmpty) {
    throw GradleException("Play releases require JYOTARA_UPLOAD_PROPERTIES")
}

android {
    buildFeatures { resValues = true }
    namespace = "in.innovfix.jyotara"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Public release identity; legacy tester installations remain separate.
        applicationId = if (samsungTest) "in.innovfix.jyotara.samsungtest" else "in.innovfix.jyotara"
        manifestPlaceholders["jyotaraLabel"] = if (samsungTest) "Jyotara Test" else "Jyotara"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        resValue("string", "jyotara_meta_app_id", System.getenv("JYOTARA_META_APP_ID") ?: "")
        resValue("string", "jyotara_meta_client_token", System.getenv("JYOTARA_META_CLIENT_TOKEN") ?: "")
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!uploadProperties.isEmpty) {
            create("upload") {
                storeFile = file(requireNotNull(uploadProperties.getProperty("storeFile")))
                storePassword = requireNotNull(uploadProperties.getProperty("storePassword"))
                keyAlias = requireNotNull(uploadProperties.getProperty("keyAlias"))
                keyPassword = requireNotNull(uploadProperties.getProperty("keyPassword"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (playRelease) "upload" else "debug"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Temporary UI/chat QA can run while its separate Firebase app is registered.
// This switch is forbidden for the production application.
val testFirebasePending = System.getenv("JYOTARA_SAMSUNG_TEST_FIREBASE_PENDING") == "true"
if (testFirebasePending && !samsungTest) {
    throw GradleException("Only Samsung test builds may omit Firebase configuration")
}
if (testFirebasePending) {
    tasks.configureEach {
        if (name.endsWith("GoogleServices") || name.contains("Crashlytics")) enabled = false
    }
}

dependencies {
    implementation("com.facebook.android:facebook-core:18.3.0")
    implementation("com.google.android.gms:play-services-auth-api-phone:18.3.1")
}
