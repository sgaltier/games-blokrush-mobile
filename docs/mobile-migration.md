# Blokrush — Android migration plan

The plan for packaging the game as an Android app on the Play Store. Companion to
[todo.md](todo.md) (the open backlog), [done.md](done.md) (shipped findings) and
[testing.md](testing.md) (the harness this plan has to keep green). Findings raised by this work
continue the shared numbering, starting at **#108**.

Line references are written as `index.html:1085` rather than as markdown anchors, deliberately:
`test/suites/structure.js` validates `index.html#L…` links against the current file, and this plan
describes edits that will shift those line numbers.

## Context

Blokrush is one self-contained `html/index.html` (6,515 lines, 305 KB — CSS + markup + one IIFE), a
Cloudflare Pages Function (`functions/api/scores.js`) backing the global hall of fame, and a
zero-dependency Node test suite (383 tests, green; `todo.md` at 0 open findings). There are **no**
external assets anywhere in the repo — every graphic is Canvas 2D, every sound is procedural
WebAudio, every icon is a Unicode entity, and there are no image files at all.

The game is unusually well positioned for this. Touch input is already shipped and
regression-tested (#27 aim-then-launch on `touchend`, #35 second-finger guard, `touch-action: none`),
the canvas already scales from its *displayed* size with DPR capped at 2.5 (#17), the resume
snapshot already fires on `pagehide` specifically because "some in-app browser shells never fire
`visibilitychange` before teardown" (#64) — which is exactly WebView Activity teardown — and storage
already survives throwing `localStorage` (#2).

What is missing is everything around the game: the layout does not fit a phone screen (it scrolls in
portrait and badly in landscape), the API is unreachable from any origin but the Pages site, and
there is no Android project, no icon, no license, and no store listing.

### Decisions taken

| | |
|---|---|
| Offline | Fully offline from install — `index.html` ships inside the AAB |
| Packaging | Native Kotlin/Gradle WebView shell (no npm, no Capacitor, no TWA) |
| Repo | `android/` in this repo; Gradle copies `html/index.html` into assets at build time |
| Global board | Enabled — add CORS to the Pages Function |
| `index.html` | The shared file is edited; the web build gets the same fixes |
| Orientation | Portrait-only, hard-enforced — manifest lock **and** no split-screen/freeform (Phase 2) |
| Identity | `com.sebkiller.blokrush`, label "Blokrush", listings in FR (default) + EN |
| Scope | Through store-ready, including branding, privacy policy, and Play paperwork |
| Play account | None yet — see Phase 7 for the timeline this imposes |

---

## Constraints that will bite

These are enforced by tests, not convention. Violating them fails `node test/run.js`.

1. **Exactly one `<script>` and one `<style>` block** — `test/suites/structure.js:72-77`. No injected
   bridge script, no second inline stylesheet. (A `<link>` or `<script src>` would slip past the
   assertion but `test/dom-stub.js:22` extracts the *first* `<script>` block, so a `src` tag placed
   before the game's would silently instrument the wrong thing.)
2. **The script must end in a literal `})();`** — `test/dom-stub.js:53-59` injects the test seam
   there. No module conversion, no bundler.
3. **`html/index.html` must stay at that exact path** — `test/dom-stub.js:19` and
   `pages_build_output_dir` in `wrangler.jsonc` both hard-code it.
4. **Docs line anchors are asserted** — `test/suites/structure.js:121-157` checks every
   `index.html#L123-L456` in `docs/*.md` points inside the file at a non-blank line, and that the
   link label matches. **Any edit shifting line numbers in `index.html` can fail the suite via the
   docs.** Budget time for re-anchoring; this is the single most annoying friction point.
5. **The IIFE exposes nothing globally.** Kotlin cannot call `togglePause()` directly. Use synthetic
   events instead (see Phase 2) — no seam widening, no global exports.
6. **The D1 board must never be reset** (CLAUDE.md). Nothing here touches the schema.

---

## Phase 1 — Make the game fit a phone (`html/index.html`)

> **✅ Shipped 2026-08-23** as #108 (networking origin), #109 (the height-fit layout chain and touch
> targets), and #110 (viewport-fit and safe areas) — see [done.md](done.md) for the fix write-ups and
> the line numbers as they stand now. The line references below are as they were when this section
> was written, i.e. **before** the edits it describes; they are not re-anchored, the same way a
> `todo.md` entry's original write-up stays as historical record once it moves to `done.md`.

The layout is width-driven only. `.cabinet` is a flex column capped at 640px; `canvas` is
`width: 100%; height: auto` (index.html:318-324) with no height bound anywhere, so on a 400px-wide
phone the canvas alone is ~504px and the marquee + HUD + effect bars + deck push the page past
730px. It scrolls. In landscape it is far worse.

**Fit by height, not just width.** Restructure the outer chain so the canvas is bounded on both
axes:

- `body` / `.cabinet` (index.html:50-64): `height: 100dvh` on the cabinet, `overflow: hidden` on
  the body, and shrink `padding: clamp(12px, 3vw, 36px)` on small viewports.
- `.play-row` (:291) and `.screen-wrap` (:298): `flex: 1 1 auto; min-height: 0` — without
  `min-height: 0` a flex child refuses to shrink below its content and the whole scheme fails.
- `.screen` (:310): `aspect-ratio: 480 / 680; max-width: 100%; max-height: 100%; margin-inline: auto`
  so it fits by whichever axis binds.
- `canvas` (:318): change `width: 100%; height: auto` → `width: 100%; height: 100%`.

  **This last change matters and is easy to get wrong.** `fitCanvas()` (index.html:1085-1099)
  rewrites the canvas `width`/`height` *attributes* every resize. Today `height: auto` derives the
  displayed height from those attributes, so any move to `width: auto` would create a
  layout↔backing-store feedback loop. Pinning both CSS dimensions to the aspect-ratio'd parent
  breaks that coupling entirely. `fitCanvas()` and `pointerToLogical()` (:1103-1108) both read
  `getBoundingClientRect()` and need **no changes**.

**Viewport and safe areas.** index.html:5 is currently
`content="width=device-width, initial-scale=1"`. Add `viewport-fit=cover, user-scalable=no`, and
apply `env(safe-area-inset-*)` padding to `.cabinet` so the marquee clears a notch and the deck
clears the gesture bar. `structure.js:42-47` only requires `width=device-width`, so it still passes;
extend that test to also require `viewport-fit=cover`.

**Touch targets.** `.icon-btn` is 34×34px (index.html:688-690) — pause, mute, and the hold-to-slow
button, all below Android's 48dp guideline. Raise to 44px with an invisible padded hit area reaching
48px, or bump to 48px outright if the deck has room.

**Landscape.** Portrait is locked in the manifest (Phase 2), so landscape only has to be survivable
for the website. Add an `@media (orientation: landscape) and (max-height: 500px)` rule that hides
the tagline and tightens the marquee — reuse the pattern already at index.html:727-730.

**Networking origin.** `var API_URL = "/api/scores"` (index.html:2859) resolves to nothing under the
app's asset-loader origin. Minimal change, chosen so Pages *preview* deployments keep hitting their
own preview endpoint and their own preview D1 (which is the whole point of `env.preview` in
`wrangler.jsonc`) and `file://` keeps falling back to the local board:

```js
// The app WebView serves the game from WebViewAssetLoader's synthetic origin, where a
// relative URL has nothing to resolve against. Every other origin — production, a Pages
// preview, file:// — keeps the relative path, so previews stay on the preview database.
var API_ORIGIN =
  location.hostname === "appassets.androidplatform.net" ? "https://blokrush.sebkiller.com" : "";
var API_URL = API_ORIGIN + "/api/scores";
```

`apiFetch()` (:2865-2873) already collapses every failure to `null` and `activeBoard()` (:2940)
already falls back to the local board, so nothing downstream changes.

**Do not change:** the touch handlers (:3418-3445), `handleLaunchOrResume()` (:3447), the `pagehide`
snapshot (:3401), `autoPause()` (:3391), `fitCanvas()`, or the audio layer. They are already correct
for a WebView.

---

## Phase 2 — The Android project (`android/`)

> **✅ Shipped 2026-08-23.** The project skeleton, `MainActivity.kt`, manifest, and Gradle wrapper
> exist under `android/` as this section describes, with three deviations worth recording:
> - **Toolchain versions were taken from a live check, not this document's guesses**: AGP 9.3.0
>   (built-in Kotlin — no `org.jetbrains.kotlin.android` plugin needed), Gradle 9.7.1,
>   `androidx.core-ktx` 1.19.0, `androidx.activity` 1.13.0, `androidx.webkit` 1.17.0, `compileSdk`/
>   `targetSdk` 36 (Android 16 — Play requires it for new apps/updates from 2026-08-31). Re-verify all
>   of these before a release build; they will have moved on.
> - **`MainActivity` extends `androidx.activity.ComponentActivity`, not `AppCompatActivity`** — a
>   single always-dark WebView screen has no use for AppCompat/Material, so the app depends on
>   `androidx.core`/`androidx.activity` directly (for `WindowCompat/WindowInsetsControllerCompat` and
>   `OnBackPressedCallback`) plus `androidx.webkit`, rather than the "one dependency" this section
>   originally described.
> - **The launcher icon was a placeholder** (a bare vector circle) at Phase 2, just enough for the
>   manifest to resolve — see Phase 4 below for the real artwork.
>
> Verified as far as this environment allows: the wrapper downloads and checksum-verifies Gradle
> 9.7.1, `./gradlew :app:syncGame` copies `html/index.html` into assets correctly, and
> `./gradlew :app:assembleDebug` gets exactly as far as `SDK location not found` — i.e. everything
> up to the Android SDK itself is confirmed working. Actually assembling and installing an APK needs
> a real Android SDK, which this environment doesn't have — that part of Verification (below) is
> still open. The back-button's dependency on `Escape` reaching `togglePause()` is already covered by
> the existing `"Escape pauses"` test in `test/suites/state.js`, so the plan's `#111` was not needed
> as a separate test.

A plain Gradle project, no JS toolchain. Layout:

```
android/
  settings.gradle.kts  build.gradle.kts  gradle/libs.versions.toml
  gradle/wrapper/…     gradlew  gradlew.bat
  app/
    build.gradle.kts
    src/main/AndroidManifest.xml
    src/main/java/com/sebkiller/blokrush/MainActivity.kt
    src/main/res/{values,values-fr,mipmap-anydpi-v26,drawable,xml}/…
```

**`app/build.gradle.kts`** — `applicationId "com.sebkiller.blokrush"`, `minSdk 24`, `compileSdk`/
`targetSdk` at the current Play requirement (see Phase 7 — **verify the exact number in the Play
Console**, do not take it from this document). One dependency: `androidx.webkit` for
`WebViewAssetLoader`. `versionCode`/`versionName` set here; every Play upload needs a fresh
`versionCode`.

**The asset copy is a Gradle task, not a committed duplicate:**

```kotlin
val syncGame by tasks.registering(Sync::class) {
    from(rootProject.file("../html/index.html"))
    into(layout.projectDirectory.dir("src/main/assets"))
}
tasks.named("preBuild") { dependsOn(syncGame) }
```

`android/app/src/main/assets/` goes in `.gitignore`. The two copies can never drift, and there is
still exactly one source of truth for the game.

**`MainActivity.kt`** — one Activity, one WebView:

- `WebViewAssetLoader` with an `AssetsPathHandler` on `/assets/`, wired through a
  `WebViewClientCompat.shouldInterceptRequest`. Load
  `https://appassets.androidplatform.net/assets/index.html`. This gives the page a real,
  allowlist-able HTTPS origin — which is precisely what makes Phase 3's CORS rule specific rather
  than a `null`-origin free-for-all, and it is why this is preferred over `file:///android_asset/`.
- `settings`: `javaScriptEnabled = true`, `domStorageEnabled = true` (**without this all seven
  `blokrush-*` keys silently no-op — no error surfaces, progress and the local board just vanish**),
  `mediaPlaybackRequiresUserGesture = false`, zoom controls off, `allowFileAccess = false`,
  `allowContentAccess = false`.
- **System font scaling:** leave `settings.textZoom` at its default so the OS accessibility setting
  is respected, and verify the Phase 1 layout at 130% and 200%. Pin it to 100 only if the layout
  proves unfixable — the project has a whole shipped accessibility section (done.md §D) and silently
  ignoring the user's font size would undercut it.
- Edge-to-edge with `WindowCompat.setDecorFitsSystemWindows(window, false)` and
  `WindowInsetsControllerCompat` in immersive-sticky mode; the CSS safe-area work from Phase 1 is
  what keeps content clear of the cutout and gesture bar.
- `onPause()` → `webView.onPause(); webView.pauseTimers()`; `onResume()` → the reverse. This is what
  stops the unconditional `requestAnimationFrame` loop (index.html:6544 boots it and it never
  cancels, even on menus) from draining battery in the background. `pauseTimers()` is process-wide
  and is the correct lever here.
- **Back button** — the game exposes nothing globally, so drive it through the existing keyboard
  path instead of adding a bridge:
  `webView.evaluateJavascript("window.dispatchEvent(new KeyboardEvent('keydown',{code:'Escape'}))", null)`.
  index.html:3410 maps `Escape` to `togglePause()`. Register an `OnBackPressedCallback` that pauses
  on first press and finishes the Activity on a second press within a few seconds. Zero changes to
  `index.html`, no seam widening.
- No `addJavascriptInterface` anywhere — it is the classic WebView RCE surface and nothing here
  needs it.

**`AndroidManifest.xml`** — `android:screenOrientation="portrait"`,
`android:configChanges="orientation|screenSize|screenLayout|keyboardHidden|uiMode|density"` so the
soft keyboard (the hall-of-fame name field auto-focuses on entering `nameentry`, index.html:3727)
and rotation do not destroy and rebuild the WebView mid-run,
`android:windowSoftInputMode="adjustResize"`,
`<uses-permission android:name="android.permission.INTERNET"/>`,
`android:usesCleartextTraffic="false"`, and a `dataExtractionRules`/`fullBackupContent` pair that
**includes** the WebView data directory so progress survives a device migration.

**Portrait lock is not just `screenOrientation`.** That attribute alone is documented by Android as
*ignored while the activity is in multi-window mode* — a user can drag the app into split-screen or
(on a Chromebook/foldable) freeform and resize the window to a landscape shape regardless of the
manifest lock. Also set `android:resizeableActivity="false"` so the app opts out of multi-window
entirely: it cannot be launched into split-screen or freeform, so there is no window shape to resize
into landscape in the first place. This is the actual enforcement; `screenOrientation="portrait"`
alone only stops device-rotation, not window-resize.

**Large-screen caveat, flagged not fixed:** Android has been moving toward overriding fixed-orientation
and `resizeableActivity="false"` on large screens (tablets/foldables) — an app that restricts both may
be run in a compatibility mode that letterboxes it to a portrait-shaped window inside a larger
landscape display, rather than honouring the restriction outright. That still satisfies "the game only
ever renders in portrait," just via an OS-managed letterbox instead of a hard block, and which behavior
applies depends on the `targetSdk` in effect at build time (see Phase 7 — verify current enforcement in
the Play Console/Android docs rather than trusting a number here).

---

## Phase 3 — CORS on the Pages Function (`functions/api/scores.js`)

> **✅ Shipped 2026-08-23** as #111 (CORS) and #112 (the `wrangler.jsonc` name-mismatch comment) — see
> [done.md](done.md) for the write-ups and current line numbers. One addition beyond this section's
> spec: the existing `json()` helper grew a third `extraHeaders` parameter so the CORS headers could
> thread through every response uniformly, rather than each handler building its own `Response`.
> Verified live in-session (not just via the source-text regression tests, which is all `scores.js`
> has had until now) by `import()`ing the module directly and calling the exported handlers against a
> stubbed `env.DB` — confirmed the OPTIONS/GET behaviour for an allowlisted origin, a non-allowlisted
> one, and no `Origin` header at all. Verification item 5 below (`curl -i -X OPTIONS ...` against the
> live endpoint) is still open — it needs the actual Cloudflare deploy, not just this repo.

Today the file has no `Access-Control-Allow-Origin` and no `onRequestOptions`. The app's `GET` would
be unreadable and its `application/json` `POST` would preflight into a 405.

- Add an allowlist of exactly two origins: `https://appassets.androidplatform.net` (the app) and
  `https://blokrush.sebkiller.com` (harmless, and useful for local testing).
- Add `onRequestOptions` returning 204 with `Access-Control-Allow-Origin` (echoed only if the
  request's `Origin` is in the allowlist — never `*`, never a reflected arbitrary origin, never
  `null`), `Access-Control-Allow-Methods: GET, POST, OPTIONS`,
  `Access-Control-Allow-Headers: content-type`, `Access-Control-Max-Age`, and `Vary: Origin`.
- Thread the same header onto the existing `json()` helper (`scores.js:53-60`) for GET and POST.
- **Do not weaken the `content-type` check at `scores.js:244-247`.** That is #92's defence against
  drive-by form POSTs burning a visitor's rate-limit budget, and requiring JSON is exactly what
  forces the preflight the allowlist then governs. Note explicitly in the code comment that CORS is
  not a security boundary here — the endpoint is unauthenticated and reachable by `curl` anyway; the
  allowlist is hygiene, and the real defences remain the HMAC token, the `nonce` UNIQUE constraint,
  the plausibility envelope, and the per-IP limiter.
- **Carrier NAT caveat:** the limiter is 20 submissions per 10 minutes keyed on `cf-connecting-ip`
  (`scores.js:51-52, 276`). Mobile players behind CGNAT share a bucket. Leave the limits alone for
  launch, but watch for `429`s once there is real app traffic.

Also worth fixing while here: `wrangler.jsonc`'s `name` is `games-blokrush` while this repo is
`games-blokrush-mobile`. If a second Pages project is ever created from this repo it will take the
repo name, the `name` will mismatch, the D1 binding will silently vanish, and `/api/scores` will
503 — which looks like "the leaderboard is empty", not like an error. Add a comment pinning this.

---

## Phase 4 — Branding and assets

> **✅ Shipped 2026-08-23**, with one item still open: the icon, splash screen, and Play Store
> graphics are done; **screenshots are blocked** — they need an actual emulator or device, which
> this environment doesn't have (see Phase 2's own verification note). Two deviations from this
> section's original spec:
> - **The icon and Play Store graphics were generated with a PowerShell/System.Drawing script**
>   (`android/branding/render-icon.ps1`, `render-feature-graphic.ps1`), not the "throwaway HTML page
>   + browser capture" this section originally proposed. Both approaches are equally "no committed
>   image-editor project" — this one turned out easier to get pixel-exact (no browser
>   chrome/scrollbar to crop around) and its output is easy to verify programmatically (dimensions
>   checked in-session, not eyeballed). The vector XML itself was still designed and reviewed as SVG
>   in a browser first (same path-data grammar as Android's `pathData`) before being hand-transcribed
>   — see the artifact link in this session's transcript.
> - **The feature graphic's tagline is placeholder English** ("NEON ARCADE BREAKOUT"), not
>   index.html's actual localized copy — worth a second pass once the Play listing's real FR/EN copy
>   (Phase 7) exists, so the two don't drift.
>
> Re-run both render scripts if the icon's geometry or palette ever changes in
> `ic_launcher_foreground.xml` — they are not wired into any build step, so nothing regenerates them
> automatically.

The repo has zero image files. Everything is generated from the existing palette (index.html:22-40:
void `#0a0118`, panel `#17102f`, neon cyan `#2de2e6`, magenta `#ff2e88`, amber `#ffb627`, lime
`#9dff1e`) and the `BLOK`/`RUSH` wordmark treatment.

- **Adaptive launcher icon as vector XML** — `res/drawable/ic_launcher_foreground.xml` (a neon
  brick-and-ball motif) over a solid `#0a0118` background colour, referenced from
  `mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`. Pure XML, no raster, no tooling —
  it fits the repo's no-build-step ethos. Add PNG fallbacks in `mipmap-*` for API 24-25.
- **Splash** — `androidx.core.splashscreen` with the same icon on the void background, so the app
  does not flash white before the WebView paints. A white flash on a game this dark is the most
  visible polish defect a reviewer will hit.
- **Play Store graphics (raster, required):** 512×512 icon PNG and 1024×500 feature graphic. Build
  a throwaway HTML page under `android/branding/` that draws each at exact pixel size and capture it
  from a browser — this repo has no image toolchain and adding one for two files is not worth it.
- **Screenshots:** at least 2 phone screenshots (Play wants 4-8 for a good listing). Run the app in
  an emulator and `adb exec-out screencap -p > shot.png`. Capture the start screen, mid-rally with
  power-ups active, a boss fight, and the hall of fame.
- **Fonts, flagged not fixed:** `--font-display` and `--font-mono` (index.html:38-40) name Arial
  Narrow, Haettenschweiler, Segoe UI Semibold, Consolas, SFMono-Regular — **none of which exist on
  Android**. The condensed marquee and the tabular "LED digit" HUD both fall back to Roboto.
  Bundling a condensed + a mono webfont would introduce the repo's first binary asset and its first
  font licensing question. Recommend shipping on Roboto for v1 and revisiting if it looks wrong on
  device.

---

## Phase 5 — Repo hygiene

- **`.gitignore`** currently has four meaningful lines and covers nothing Android. Add `.gradle/`,
  `android/build/`, `android/app/build/`, `local.properties`, `*.apk`, `*.aab`, `*.jks`,
  `*.keystore`, `keystore.properties`, and `android/app/src/main/assets/`. **`local.properties` and
  the keystore files are exactly what must never be committed** — do this before the Android
  directory exists, not after.
- **`LICENSE`** — there is none, and there is no copyright statement anywhere in the repo. Needed
  before a store listing.
- **`README.md`** — there is none; `CLAUDE.md` is doing that job. A short public README is worth
  having once the repo backs a published app.
- **`html/privacy.html`** — bilingual privacy policy, published by Pages alongside the game at
  `blokrush.sebkiller.com/privacy.html`. Play requires a reachable policy URL for any app that
  collects data. Content: a self-chosen display name and a score are sent only when a run qualifies
  for the top ten and the player submits; the name is world-visible and permanent; the IP address is
  hashed with a secret for rate limiting and never stored raw (`scores.js:204-207`); everything else
  (progress, best score, language, mute, achievements) stays on the device in `localStorage`; no
  analytics, no ads, no third-party SDKs, no account. Add a contact address for removal requests.
- **`CLAUDE.md`** — add an Android section: the `android/` layout, the Gradle asset-sync task, the
  `appassets.androidplatform.net` origin and why the CORS allowlist names it, and the release
  procedure.

---

## Phase 6 — Tests, docs, and CI

Follow the established loop (testing.md): regression test → fix → move the finding from
[todo.md](todo.md) to [done.md](done.md) with a `✅ FIXED` note → add a
[release-notes.md](release-notes.md) entry. Numbering continues at **#108**.

New tests in `test/suites/regressions.js` (the convention is one test named for each finding):

- `#108 — the API origin switches only on the Android asset host` — boot with a stubbed
  `location.hostname` and assert `apiFetch` targets the absolute URL there and the relative one on a
  `.pages.dev` preview host. The `boot({ api })` fetch stub (`test/dom-stub.js:443-453`) already
  records `apiCalls` with parsed bodies, so this needs no new harness machinery.
- `#109 — the cabinet does not exceed the viewport height` — a static CSS assertion in
  `test/suites/structure.js` (the harness has no layout engine, so assert the rules exist:
  `100dvh` on `.cabinet`, `min-height: 0` on the flex chain, `aspect-ratio` on `.screen`).
- `#110 — the viewport meta opts into the display cutout` — extend `structure.js:42-47` to require
  `viewport-fit=cover`.
- `#111 — Escape still reaches togglePause` — pin the back-button contract, so a future refactor of
  the keydown handler cannot silently break the Android back button. `boot().key("Escape")` already
  exists.
- Mirror-assertions for the new CORS constants in `scores.js`, in the style of the existing
  `regressions.js` checks that read `functions/api/scores.js` as text (`:4080, :4136, :4160, :4172`).

**Re-anchor `docs/*.md`** after the `index.html` edits — `structure.js:121-157` will fail otherwise.

**CI** — leave `.github/workflows/test.yml` exactly as it is (a regression test at
`regressions.js:4190-4200` pins its `permissions:` block, so reformatting it fails the suite). Add a
separate `.github/workflows/android.yml`: JDK 17, Gradle cache, `./gradlew :app:assembleDebug` on
PRs touching `android/` or `html/`, plus a `workflow_dispatch` release job that builds a signed AAB
from repository secrets. Never commit the keystore.

---

## Phase 7 — Play Console

**The account is the long pole, not the code.** The three points below come from training knowledge,
not a web search, and all three must be re-verified in the Play Console because the rules change:

1. $25 one-time registration. Register as an **individual** unless you have a company with a D-U-N-S
   number.
2. New individual accounts must run a **closed test with at least 12 opted-in testers for 14
   continuous days** before applying for production access. Twelve real Google accounts that install
   and stay opted in — this is the requirement that most often surprises people. **Start recruiting
   testers on day one**, in parallel with the build, not after it.
3. Google enforces a minimum `targetSdk` for new apps that steps up every August. Read the current
   number off the Play Console rather than trusting any figure written here.

Also required: Data Safety declaration (collected: a self-chosen name and a score, transmitted,
optional, publicly visible, not linked to an identity, no deletion mechanism today — say so
honestly); the IARC content-rating questionnaire; a store listing in FR and EN; and the app category
(Games → Arcade).

**One real store-review risk to plan for:** the world-visible hall of fame is user-generated content.
Play's UGC policy expects an in-app way to report objectionable content, and the server-side
profanity filter (`scores.js:151-202`) is a preventive control, not a reporting mechanism. Cheapest
sufficient mitigation is a "Report a name" link on the hall-of-fame overlay opening a `mailto:` to a
moderation address, plus documenting the filter and the takedown path in the listing. Decide this
before submission rather than after a rejection.

---

## Verification

1. `node test/run.js` — must be 383+ passing, 0 failed, 0 `FIXED?`. Run it after every
   `index.html` edit; the docs-anchor test is the one that will catch line-number drift.
2. `cd android && ./gradlew :app:assembleDebug`, then
   `adb install -r app/build/outputs/apk/debug/app-debug.apk`.
3. **On device, airplane mode, fresh install** — the whole campaign must be playable, sound must
   work after the first tap, progress must survive force-stop and relaunch (that is the `pagehide`
   snapshot doing its job), and the hall of fame must show the local board with no error.
4. **On device, online** — the world board must populate, and a qualifying run must submit. Confirm
   from the Cloudflare side, not the UI: a misconfigured backend looks like an empty leaderboard.
5. CORS directly:
   `curl -i -X OPTIONS https://blokrush.sebkiller.com/api/scores -H "Origin: https://appassets.androidplatform.net" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type"`
   → 204 with the allow headers. Repeat with `-H "Origin: https://evil.example"` → **no**
   `Access-Control-Allow-Origin` in the response.
6. **Confirm the preview environment did not regress** — open a branch preview `.pages.dev` URL and
   check it still hits its own relative endpoint and writes to `blokrush-hof-preview`, not
   production. This is the one place the Phase 1 origin change could do real damage.
7. Layout across a matrix: a small phone (≈360×640), a tall modern phone with a cutout, and a
   tablet. Nothing may scroll; the paddle must track a finger accurately at every size (that is
   `pointerToLogical` reading the live rect); the notch and gesture bar must not overlap content.
   On the tablet specifically: physically rotate the device to landscape and confirm the app stays
   portrait (auto-rotate on and off), then from Recents try to drag the app into split-screen —
   confirm it refuses to enter multi-window at all (or, on a device where the OS overrides that per
   the large-screen caveat above, that it renders letterboxed to a portrait shape rather than
   stretching into the landscape pane).
8. Accessibility: system font size at 130% and 200%, and TalkBack on the overlay buttons.
9. Performance on a mid-range device: the canvas sets `shadowBlur` inside per-entity draw loops at
   ~12 sites (index.html:6134-6391), which is hundreds of blurred draws per frame and the most
   likely frame-rate problem. Profile a busy boss level before assuming it is fine; if it is not,
   that is a new numbered finding, not scope creep into this plan.

---

## Sequencing

Phase 1 and Phase 3 are independent and can go first — both improve the live website on their own
merits and are verifiable without any Android tooling. Phase 2 depends on Phase 1's layout. Phases
4-6 follow the working app. Phase 7's account registration and tester recruitment should start
immediately and run in parallel with all of it, because the 14-day closed test is calendar time that
cannot be compressed.
