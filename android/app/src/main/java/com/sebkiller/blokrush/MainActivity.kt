package com.sebkiller.blokrush

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.webkit.WebViewAssetLoader
import androidx.webkit.WebViewClientCompat

/**
 * One Activity, one WebView. The game is entirely self-contained in
 * html/index.html (synced into assets at build time by the `syncGame` Gradle
 * task — see app/build.gradle.kts) and exposes nothing globally from its
 * IIFE (see CLAUDE.md), so this shell only ever talks to it through
 * synthetic DOM events, never `addJavascriptInterface`.
 */
class MainActivity : ComponentActivity() {

    private lateinit var webView: WebView

    // A second back-press within BACK_PRESS_RESET_MS finishes the Activity;
    // the first only pauses the game, the way losing focus already does
    // (#18) rather than exiting on a single accidental tap.
    private var backPressedOnce = false

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        // Must come before super.onCreate() — see themes.xml's
        // Theme.Blokrush.Starting for the theme half of this (Phase 4).
        installSplashScreen()
        super.onCreate(savedInstanceState)

        // Edge-to-edge, immersive-sticky: system bars hide and reappear only
        // on a swipe. The Phase 1 CSS safe-area padding is what keeps
        // content clear of the cutout and gesture bar once they're gone.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        // A real, allowlist-able HTTPS origin instead of file:///android_asset/
        // — see docs/mobile-migration.md Phase 2/3 for why this is what lets
        // Phase 3's CORS rule be a specific allowlist entry rather than a
        // null-origin free-for-all.
        val assetLoader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        webView = WebView(this).apply {
            // The actual fix for the white-flash Phase 4 flags: WebView's own
            // default background is opaque white until index.html's first
            // paint, regardless of the splash screen or the Activity theme —
            // it draws in a separate surface. Matching it to the void
            // background is what closes the gap between the splash screen
            // dismissing and the game's own dark canvas appearing.
            setBackgroundColor(ContextCompat.getColor(this@MainActivity, R.color.void_bg))
            settings.javaScriptEnabled = true
            // Without this all seven blokrush-* localStorage keys silently
            // no-op — no error surfaces, progress and the local board just
            // vanish (index.html:2625-2631).
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.setSupportZoom(false)
            settings.builtInZoomControls = false
            settings.displayZoomControls = false
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            // textZoom is deliberately left at its default so the OS
            // accessibility text-size setting is respected — pin it to 100
            // only if the Phase 1 layout proves unfixable at 130%/200%.

            webViewClient = object : WebViewClientCompat() {
                override fun shouldInterceptRequest(
                    view: WebView,
                    request: WebResourceRequest
                ): WebResourceResponse? = assetLoader.shouldInterceptRequest(request.url)
            }

            loadUrl("https://appassets.androidplatform.net/assets/index.html")
        }
        setContentView(webView)

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (backPressedOnce) {
                    finish()
                    return
                }
                backPressedOnce = true
                // index.html:3410 maps Escape to togglePause() — driving the
                // existing keyboard path is zero changes to index.html and no
                // seam widening, versus adding a JS bridge for one key.
                webView.evaluateJavascript(
                    "window.dispatchEvent(new KeyboardEvent('keydown',{code:'Escape'}));",
                    null
                )
                webView.postDelayed({ backPressedOnce = false }, BACK_PRESS_RESET_MS)
            }
        })
    }

    // Stops the unconditional requestAnimationFrame loop (index.html:6544
    // boots it and it never cancels, even on menus) from draining battery in
    // the background. pauseTimers() is process-wide and is the correct lever
    // here, not just onPause().
    override fun onPause() {
        webView.onPause()
        webView.pauseTimers()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        webView.resumeTimers()
        webView.onResume()
    }

    private companion object {
        const val BACK_PRESS_RESET_MS = 2000L
    }
}
