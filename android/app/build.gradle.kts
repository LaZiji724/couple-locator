import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 签名配置：android/key.properties（不要提交到仓库，见 docs/BUILD.md）
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.couple.couple_locator"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.couple.couple_locator"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // Android 8.0
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 高德 Android Key：-PAMAP_ANDROID_KEY=xxx 或环境变量 AMAP_ANDROID_KEY
        val amapKey = (project.findProperty("AMAP_ANDROID_KEY") as String?) ?: System.getenv("AMAP_ANDROID_KEY") ?: "YOUR_AMAP_ANDROID_KEY"
        manifestPlaceholders["AMAP_ANDROID_KEY"] = amapKey
    }

    signingConfigs {
        create("release") {
            if (keyProps.containsKey("storeFile")) {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            } else {
                // 回退：仓库内固定的“个人侧载”密钥（用户已同意提交），使 SHA1 稳定（高德 Key 需绑定）。
                // 正式发布请用 scripts/gen_keystore.sh 生成自己的密钥并配置 key.properties。
                storeFile = file("fixed-signing.jks")
                storePassword = "543eeabe2c6ef7710bf1a90c"
                keyAlias = "couple"
                keyPassword = "543eeabe2c6ef7710bf1a90c"
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties 用正式 keystore，否则用仓库内固定密钥
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true // R8
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
