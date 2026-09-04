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

    // EncryptedSharedPreferences, for the session tokens. Pinned for the
    // same reason as core-ktx above: the only bytes in Aura that ARE a
    // session must not have their protection depend on what some other
    // dependency happened to pull in transitively.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}

flutter {
    source = "../.."
}