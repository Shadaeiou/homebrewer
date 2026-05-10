# Homebrewer

A homebrew brewing simulation game for Android. Sideload-only, signed APKs published to GitHub Releases on every push to `main`.

Built with **Godot 4.3**. Pixel art generated via ComfyUI (Phase 2+) mixed with procedural rendering.

## Layout

```
homebrewer/
├── .github/workflows/build-android.yml   # CI: Godot export → sign → release → FCM ping
├── godot/                                 # Godot project root
│   ├── project.godot
│   ├── export_presets.cfg                 # signing keystore values are placeholders; CI sed-injects
│   ├── scenes/                            # .tscn (one per screen / mini-game)
│   ├── scripts/                           # GDScript controllers
│   ├── systems/                           # autoloaded singletons (Changelog, Version, …)
│   ├── data/                              # changelog.json, future recipe defs, etc.
│   ├── assets/                            # sprites + icon
│   ├── tools/                             # screenshot_harness.gd (headless visual verification)
│   └── tests/                             # GUT tests
├── scripts/
│   ├── dev-check.sh                       # static check pipeline (run before every commit)
│   ├── render_screenshots.sh              # runs the harness through Xvfb
│   └── send_fcm_update_push.py            # CI-only; FCM client receiver lands in Phase 2
└── screenshots/                           # harness output (gitignored)
```

## Local development

Once-off setup on Linux:

```bash
sudo apt-get install -y openjdk-17-jdk xvfb libgl1-mesa-dri libglx-mesa0 libegl1 mesa-utils
# Install Godot 4.3 binary somewhere on PATH (https://godotengine.org/download)
```

Then:

```bash
scripts/dev-check.sh        # imports + tests + renders screenshots
```

Open the project in the editor with:

```bash
cd godot && godot --editor .
```

Or play headless with:

```bash
cd godot && godot --rendering-driver opengl3   # uses your real display
```

## Release flow

```
git push main
    │
    ▼
GitHub Actions: build-android.yml
    │  install Godot 4.3 + export templates
    │  setup JDK + Android SDK
    │  decode keystore from KEYSTORE_BASE64
    │  inject version + signing values into project
    │  godot --headless --export-release "Android" build/homebrewer.apk
    ▼
GitHub Release v0.2.<N>+<N> with homebrewer.apk attached
    │
    ▼
scripts/send_fcm_update_push.py (best-effort)
    │  POST fcm.googleapis.com/v1/projects/<id>/messages:send (topic "app-updates")
    ▼
[Phase 2] Godot APK with custom Android build template + FirebaseMessagingService
    │  receives push → notification → tap to update
```

Phase 1 (current) ships the APK and posts the FCM message. The Godot APK does not yet receive FCM messages — Phase 2 adds the custom build template and the Java-side service. Until then, "Check for updates" inside the app opens the GitHub Releases page.

## Required GitHub Actions secrets

| Secret | Purpose |
|---|---|
| `KEYSTORE_BASE64` | base64-encoded release keystore |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_ALIAS` | key alias (e.g. `release`) |
| `KEY_PASSWORD` | key password |
| `FCM_SERVICE_ACCOUNT_JSON` | (optional) Firebase service-account JSON for the post-release ping |

If `FCM_SERVICE_ACCOUNT_JSON` is unset, the FCM step prints a notice and exits 0; the rest of the pipeline still works.

## Visual verification

`scripts/render_screenshots.sh` runs the headless screenshot harness (`godot/tools/screenshot_harness.gd`) with Xvfb + software OpenGL, producing PNGs in `screenshots/`. Used during development to verify UI changes without installing the APK on a phone.

To add a new scene to the rendered set, edit the `SCENES` array in `screenshot_harness.gd`.

## Versioning

- `versionCode` = `git rev-list --count HEAD` (integer, monotonic; required by Android).
- `versionName` = `0.2.<versionCode>` (the `0.2` prefix marks the Godot era; `0.1` was the Compose template).
- Tag = `v<versionName>+<versionCode>`.

See [`CLAUDE.md`](CLAUDE.md) for the rule that every player-visible commit must update [`godot/data/changelog.json`](godot/data/changelog.json) in the same commit.

## Stack

- Godot 4.3 (GDScript)
- compileSdk 34 (via Godot's Android export templates)
- minSdk 24, targetSdk 34
- Java 17

## Caveats

- **Sideload only.** Google Play forbids self-updating apps.
- **`REQUEST_INSTALL_PACKAGES` requires a one-time user grant** on Phase 2's in-app updater. Manual install is fine until then.
- **FCM topic pushes are global** — every install subscribed to `app-updates` receives every release notification. Phased rollouts would need a backend; Homebrewer doesn't have one and won't.
