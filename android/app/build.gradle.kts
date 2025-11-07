plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")          // ← use the same id as in settings.gradle.kts
    id("dev.flutter.flutter-gradle-plugin")     // Flutter plugin must be after Android & Kotlin
    id("com.google.gms.google-services")        // ← apply Google Services here
}

android {
    namespace = "com.example.wil"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.wil"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug signing so `flutter run --release` works until you add your own keystore.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase (optional but recommended if you’ll use any Firebase SDKs)
    implementation(platform("com.google.firebase:firebase-bom:33.3.0"))
    implementation("com.google.firebase:firebase-analytics")

    // (Add any other libs you use here)
}
