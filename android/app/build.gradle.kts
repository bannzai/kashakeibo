import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // google-services.json は src/debug/ (kashakeibo-dev) を google-services plugin が
    // 優先採用し、release / profile は app/ 直下 (kashakeibo-prod) にフォールバックする。
    id("com.google.gms.google-services")
}

// リリース署名情報。CI では key.properties / keystore を GitHub Secrets から復元して配置する。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.bannzai.kashakeibo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bannzai.kashakeibo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 鍵が無い環境で release signingConfig を定義すると storeFile 未設定でビルドが落ちるため、
        // key.properties がある時だけ生成する。
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            // debug ビルドは applicationId を .dev に分離し、dev / prod を同一端末に共存させる。
            // namespace (= R class package) は据え置き、applicationId のみ変える。
            applicationIdSuffix = ".dev"
        }
        release {
            // key.properties があれば Google Play 配布用の署名、無ければ debug 署名へフォールバックし、
            // 鍵を持たないローカル環境でも `flutter run --release` / `flutter build apk` が通るようにする。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
