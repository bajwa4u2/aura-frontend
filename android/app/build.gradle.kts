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