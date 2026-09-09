import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "org.auraplatform.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "org.auraplatform.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }

        // CERTIFICATION BUILD — INSTALLS ALONGSIDE PRODUCTION, NEVER OVER IT.
        //
        // Certifying the identity branch on a real device needs the branch
        // BACKEND: /users/me/personal-details and /users/me/verification do not
        // exist in production, so a build pointed at production could only 404
        // on the surfaces under test.
        //
        // The suffix is what makes that safe. The debug build gets its own
        // applicationId, so Android treats it as a DIFFERENT APPLICATION: it
        // installs next to the shipped app instead of replacing it, and the
        // production package keeps its data and its signed-in session. No
        // uninstall, no wipe, nothing to restore afterwards.
        //
        // Paired with src/debug/ overrides that cannot reach a release build:
        // a network security config permitting cleartext ONLY to the local
        // certification backend, and a placeholder google-services.json,
        // required because the Google Services plugin resolves its client by
        // applicationId and would otherwise fail the build.
        debug {
            applicationIdSuffix = ".certification"
            versionNameSuffix = "-certification"
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Pinned explicitly, not inherited: NotificationCompat.CallStyle — the
    // API that lets an incoming call present as a call rather than as a
    // notification — landed in androidx.core 1.9.0. Relying on whatever
    // version the Flutter embedding happened to pull in transitively would
    // make incoming-call presentation depend on an unrelated upgrade.
    implementation("androidx.core:core-ktx:1.13.1")

    // TRACK C — NATIVE CALL LIFECYCLE.
    //
    // Jetpack Core-Telecom. Audited before adoption rather than after: it is a
    // stable 1.0.0, its manifest declares minSdkVersion 21 so Aura's 24 does
    // not move, it ships and registers its own JetpackConnectionService so
    // Aura writes none, and its whole cost in the shipped manifest is ONE
    // permission — MANAGE_OWN_CALLS — established by generating the merged
    // manifest with and without it and differencing the permission sets.
    //
    // MANAGE_OWN_CALLS is the ordinary permission a self-managed VoIP app
    // needs for CallsManager.addCall(). It is NOT one of Play's specially
    // restricted Call Log permissions — READ_CALL_LOG, WRITE_CALL_LOG and
    // PROCESS_OUTGOING_CALLS — and Aura requests none of those. Aura does not
    // write call-log rows; system call history is whatever Android chooses to
    // record for a call it is managing, and nothing here manufactures it.
    implementation("androidx.core:core-telecom:1.0.0")

    // The Android main dispatcher. Core-Telecom's addCall is a suspend
    // function that stays suspended for the life of the call, so the
    // integration is coroutine-shaped whether or not it wants to be. Pinned
    // for the same reason core-ktx is: a call lifecycle should not depend on
    // whichever version something unrelated happened to pull in.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // NO androidx.security HERE, DELIBERATELY.
    //
    // EncryptedSharedPreferences would store the session tokens in fewer
    // lines, and it arrives only via security-crypto, whose sole release
    // carrying it is an ALPHA — and the class is deprecated upstream. The
    // most security-sensitive bytes in the product must not depend on an
    // alpha artifact its own maintainers are moving away from.
    //
    // SecureStore.kt uses the platform Keystore APIs underneath it
    // directly: AES-256-GCM under a key that never enters this process.
}

flutter {
    source = "../.."
}