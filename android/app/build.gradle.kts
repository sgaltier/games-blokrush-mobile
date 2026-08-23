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

    buildTypes {
        release {
            isMinifyEnabled = false
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
