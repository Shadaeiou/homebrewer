# Homebrewer

A homebrew Android game, distributed sideload-only via signed APKs on GitHub Releases.

Bootstrapped from [`Shadaeiou/android-template`](https://github.com/Shadaeiou/android-template) — every push to `main` builds a signed APK, publishes a GitHub Release, and pushes an FCM notification so installed clients can self-update.

## How a release flows

```
git push main
    │
    ▼
GitHub Actions: build-android.yml
    │  decode keystore → gradle assembleRelease → upload artifact
    ▼
GitHub Release (tag v0.1.<N>+<N>, app-release.apk attached)
    │
    ▼
scripts/send_fcm_update_push.py
    │  POST fcm.googleapis.com/v1/projects/<id>/messages:send
    ▼
PushService.onMessageReceived()  →  "App update available" notification
    │
    ▼ (user taps)
Updater.checkForUpdate → startDownload → launchInstall
```

## Project layout

| Piece | File |
|---|---|
| Auto versioning | [`android/app/build.gradle.kts`](android/app/build.gradle.kts) — `versionCode = git rev-list --count HEAD`, `versionName = "0.1.$gitCommits"` |
| In-app updater | [`data/Updater.kt`](android/app/src/main/java/com/shadaeiou/homebrewer/data/Updater.kt) |
| Update UI | [`ui/SettingsScreen.kt`](android/app/src/main/java/com/shadaeiou/homebrewer/ui/SettingsScreen.kt) |
| Push receiver | [`service/PushService.kt`](android/app/src/main/java/com/shadaeiou/homebrewer/service/PushService.kt) |
| Changelog | [`data/Changelog.kt`](android/app/src/main/java/com/shadaeiou/homebrewer/data/Changelog.kt) — single source of truth, rendered in Settings |
| Build pipeline | [`.github/workflows/build-android.yml`](.github/workflows/build-android.yml) |
| FCM publisher | [`scripts/send_fcm_update_push.py`](scripts/send_fcm_update_push.py) |

## Required GitHub Actions secrets

Add these under **Settings → Secrets and variables → Actions** before pushing to `main`:

| Secret | Purpose |
|---|---|
| `KEYSTORE_BASE64` | base64-encoded contents of your release keystore |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_ALIAS` | key alias (e.g. `release`) |
| `KEY_PASSWORD` | key password |
| `FCM_SERVICE_ACCOUNT_JSON` | (optional) Firebase service-account JSON for the update push |

Without `FCM_SERVICE_ACCOUNT_JSON` the push step is a no-op; the in-app **Settings → Check for updates** path still works.

## Generating the release keystore

**Do this once and back it up.** Android refuses to install an APK signed by a different key over an existing install — there is no recovery path.

```bash
keytool -genkey -v \
  -keystore release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release
```

Then base64-encode it for the `KEYSTORE_BASE64` secret:

```bash
base64 -w0 release.jks > release.jks.base64   # macOS: base64 -i release.jks -o release.jks.base64
```

`.gitignore` excludes both `*.jks` and `release.jks.base64` — verify with `git status` before committing anything.

## Local development

```bash
cd android
./gradlew :app:assembleDebug      # debug-signed, no keystore needed
./gradlew :app:installDebug       # install on a connected device
```

For a real signed local build:

```bash
export RELEASE_KEYSTORE_PATH=$PWD/../release.jks
export RELEASE_KEYSTORE_PASSWORD='...'
export RELEASE_KEY_ALIAS=release
export RELEASE_KEY_PASSWORD='...'
./gradlew :app:assembleRelease
```

If `RELEASE_KEYSTORE_PATH` is unset or missing, the release build falls back to the debug signing config — the build still succeeds, but the resulting APK can't update an install signed by your real keystore.

## Stack

- Kotlin 2.0.21, Jetpack Compose (BOM 2024.10.01), Material 3
- AGP 8.7.3, Gradle 8.10.2, Java 17
- compileSdk 35, minSdk 26, targetSdk 35
- OkHttp 4.12, kotlinx.serialization 1.7.3, kotlinx.coroutines 1.8.1
- Firebase BoM 33.7.0 (`firebase-messaging-ktx`)

## Caveats

- **Sideload only.** Google Play forbids self-updating apps. This pipeline will never be Play-store-eligible without gutting the updater.
- **`REQUEST_INSTALL_PACKAGES` requires a one-time user grant.** The first call to `launchInstall` routes the user to that screen.
- **FCM topic pushes are global.** Every install subscribed to `app-updates` receives every release notification.
- **Pre-releases are included.** `Updater` hits `/releases?per_page=10`, not `/releases/latest`.
