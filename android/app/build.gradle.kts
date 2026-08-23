plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.sebkiller.blokrush"
    // Target/compile SDK per Google Play's API-level policy in effect at the
    // time this was written (new apps/updates must target Android 16 / API 36
    // starting 2026-08-31) — re-verify in the Play Console before a release
    // build rather than trusting this number; see docs/mobile-migration.md
    // Phase 7.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.sebkiller.blokrush"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Populated from environment variables rather than a committed
    // keystore.properties, so the release job in .github/workflows/android.yml
    // can drive it straight from repository secrets — see that file for the
    // four secret names required. Reads ANDROID_KEYSTORE_PATH rather than
    // decoding the keystore itself here, so the decoded file (and its
    // cleanup) stays entirely the CI job's responsibility, not the build's.
    // Left unset for every local/debug build: signingConfig below is only
    // attached when the path is actually present.
    val releaseKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
    signingConfigs {
        if (releaseKeystorePath != null) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (releaseKeystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            // Without a signingConfig (every local build, and CI's plain
            // `build` job) this produces an unsigned AAB/APK — buildable, not
            // installable/uploadable. That's fine for "does it still
            // compile"; only the release job needs a real signature.
        }
    }
}

// The game is edited at html/index.html, one directory up from this project —
// this task copies it into the app's assets at build time rather than a
// second, committed copy that could drift. android/app/src/main/assets/ is
// gitignored. See docs/mobile-migration.md Phase 2 and CLAUDE.md's
// single-source-of-truth constraint on html/index.html.
val syncGame = tasks.register<Sync>("syncGame") {
    from(rootProject.file("../html/index.html"))
    into(layout.projectDirectory.dir("src/main/assets"))
}
tasks.named("preBuild") {
    dependsOn(syncGame)
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity)
    // WebViewAssetLoader — serves the synced index.html from a real,
    // allowlist-able HTTPS origin instead of file:///android_asset/.
    implementation(libs.androidx.webkit)
    // Phase 4: keeps the launch frame on the void background instead of a
    // white flash before the WebView paints — the most visible polish defect
    // a reviewer would hit on a game this dark.
    implementation(libs.androidx.core.splashscreen)
}
