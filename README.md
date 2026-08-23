# Blokrush

A bilingual (French/English) neon-arcade Breakout clone — a 100-level campaign with a boss fight
every ten levels, power-ups, a global hall of fame, and full keyboard/mouse/touch support.

**Play it:** [blokrush.sebkiller.com](https://blokrush.sebkiller.com)

## Running it locally

The game is one self-contained file, [`html/index.html`](html/index.html): no build step, no
dependencies. Open it directly in a browser — `file://` works — or serve `html/` with any static
file server.

Without a network connection (or when the hall-of-fame API is unreachable), the game falls back to
a per-browser local leaderboard automatically. That fallback is exactly how `file://` and the whole
test suite run, so the game is always fully playable offline.

## Tests

```
node test/run.js
```

Requires Node 22+. No install step. Runs in under a second.

## Project layout

| | |
|---|---|
| [`html/index.html`](html/index.html) | The game — HTML, CSS, and JS in one file |
| [`functions/api/scores.js`](functions/api/scores.js) | Cloudflare Pages Function backing the global hall of fame |
| [`test/`](test/) | The test suite, and the DOM stub it drives the game through |
| [`android/`](android/) | The Android app (a Kotlin/Gradle WebView shell around the same `index.html`) |
| [`docs/`](docs/) | Findings backlog, release notes, testing conventions, the Android migration plan |

See [`CLAUDE.md`](CLAUDE.md) for the full architecture writeup and development conventions.

## License

See [`LICENSE`](LICENSE).
