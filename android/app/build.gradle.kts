import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeys = Properties()
val releaseKeyFile = rootProject.file("key.properties")
if (releaseKeyFile.exists()) releaseKeyFile.inputStream().use { releaseKeys.load(it) }
val developmentSigning = System.getenv("RUNPROGRAM_DEVELOPMENT_SIGNING") == "1"


android {
    namespace = "com.joggingapp.runprogram"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.joggingapp.runprogram"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeyFile.exists()) {
            create("production") {
                storeFile = rootProject.file(requireNotNull(releaseKeys.getProperty("storeFile")))
                storePassword = requireNotNull(releaseKeys.getProperty("storePassword"))
                keyAlias = requireNotNull(releaseKeys.getProperty("keyAlias"))
                keyPassword = requireNotNull(releaseKeys.getProperty("keyPassword"))
            }
        }
    }
    buildTypes {
        release {
            signingConfig = when {
                releaseKeyFile.exists() -> signingConfigs.getByName("production")
                developmentSigning -> signingConfigs.getByName("debug")
                else -> null
            }
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

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}

// A production-looking build must never silently use the development certificate.
gradle.taskGraph.whenReady {
    if (!releaseKeyFile.exists() && !developmentSigning && allTasks.any { it.project == project && (it.name.startsWith("assemble") || it.name.startsWith("bundle")) && it.name.contains("Release") }) {
        throw GradleException("Configure android/key.properties for production signing, or explicitly set RUNPROGRAM_DEVELOPMENT_SIGNING=1 for a local test artifact.")
    }
}
