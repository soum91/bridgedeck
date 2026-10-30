plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.soum91.bridgedeck.tv"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.soum91.bridgedeck.tv"
        minSdk = 26
        targetSdk = 35
        versionCode = (project.findProperty("BRIDGEDECK_BUILD_NUMBER") as String?)?.toIntOrNull() ?: 1
        versionName = "0.1.0.$versionCode"
    }
    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
