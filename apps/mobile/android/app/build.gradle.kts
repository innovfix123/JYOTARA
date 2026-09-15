import java.util.Properties

plugins {
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
val playRelease = System.getenv("JYOTARA_PLAY_RELEASE") == "true"
if (playRelease && uploadProperties.isEmpty) {
    throw GradleException("Play releases require JYOTARA_UPLOAD_PROPERTIES")
}

android {
    namespace = "in.innovfix.jyotara"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Retained for installed-app update and saved-data compatibility.
        applicationId = "in.innovfix.nirayana"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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
