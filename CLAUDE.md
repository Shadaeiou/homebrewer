# CLAUDE.md — rules for this repo

These rules are not suggestions. Every change to Homebrewer must follow them. If a rule conflicts with a user instruction, surface the conflict before acting.

## 1. Always commit to `main`

- **Branch policy:** all work lands on `main`. No feature branches, no PRs, no merges. Push directly to `origin/main`.
- The release pipeline (`.github/workflows/build-android.yml`) only fires on `push` to `main` and on `v*` tags. A commit on any other branch produces no APK and no release.
- If the user explicitly tells you to use a different branch for one specific task, do it for that task only and then return to `main` for everything else.
- Never force-push `main`. Never rewrite published history. If you need to undo a commit, add a new commit that reverts it.

## 2. Every commit ships a release — bump the changelog accordingly

Versioning is automatic: `versionCode = git rev-list --count HEAD`, `versionName = "0.1.<commitCount>"`. **Every push to `main` produces a new GitHub Release tagged `v0.1.<N>+<N>`.** That means the in-app **Settings → What's new** screen must always reflect what shipped.

### The rule

**Every commit to `main` that produces a user-visible change must also update [`android/app/src/main/java/com/shadaeiou/homebrewer/data/Changelog.kt`](android/app/src/main/java/com/shadaeiou/homebrewer/data/Changelog.kt) in the same commit.**

User-visible = anything a player would notice: gameplay, UI, content, balance, copy, fixed bugs, performance, new permissions, new screens.

Internal-only = does NOT require a Changelog entry: refactors with no behavior change, comment edits, build-script tweaks that don't change the artifact, dependency bumps with no observable effect, CI/workflow edits, formatting.

When in doubt, add an entry. An over-documented changelog is fine; a stale one is not.

### How to update the changelog

`Changelog.kt` is the single source of truth — there is no separate `CHANGELOG.md`, no GitHub Release notes authoring, nothing else. The list is rendered top-down inside the app.

The version string in each `ReleaseNote` must match the `versionName` that this commit will produce. Compute it before committing:

```bash
echo "0.1.$(($(git rev-list --count HEAD) + 1))"   # versionName the next commit will ship as
```

If the new entry's version equals the previous entry's version, you have a duplicate — collapse the bullets into the existing top entry instead of adding a second `ReleaseNote` with the same version.

`date` is the UTC date of the commit, in `YYYY-MM-DD`.

`bullets` are short, player-facing, present tense: "Added X", "Fixed Y", "Rebalanced Z". No issue numbers, no commit hashes, no internal jargon.

Add new entries to the **top** of the list, never the bottom. The first entry renders expanded; older entries hide behind "Show all updates".

### Example

Before — last shipped commit count was 6, so the live build is `0.1.6`:

```kotlin
val CHANGELOG: List<ReleaseNote> = listOf(
    ReleaseNote(
        version = "0.1.6",
        date = "2026-05-12",
        bullets = listOf("Added crafting bench"),
    ),
    // ...
)
```

You're about to commit a fix. After this commit there will be 7 commits, so this commit ships as `0.1.7`. Update the file:

```kotlin
val CHANGELOG: List<ReleaseNote> = listOf(
    ReleaseNote(
        version = "0.1.7",
        date = "2026-05-13",
        bullets = listOf("Fixed crash when opening the crafting bench with an empty inventory"),
    ),
    ReleaseNote(
        version = "0.1.6",
        date = "2026-05-12",
        bullets = listOf("Added crafting bench"),
    ),
    // ...
)
```

…then `git add Changelog.kt <other files> && git commit && git push origin main`. Single commit, app and changelog stay in lockstep.

### If you forgot

If a commit landed on `main` without its changelog entry:

1. Make a new commit that adds the missing entry.
2. The new commit's version is the next `0.1.N`, NOT the one you forgot. The forgotten release is gone — don't try to retroactively edit history. Note the missed change in the new entry's bullets ("(catch-up) Fixed X from build 0.1.N").

Do **not** amend or rebase to splice the entry into the prior commit once it is pushed.

## 3. Never break the updater

The updater parses release tags of the form `v<versionName>+<versionCode>`. The CI workflow generates these tags from `versionName` and `versionCode` derived from git history. Do not:

- Change the tag format in `.github/workflows/build-android.yml` without simultaneously updating `parseTag` in `Updater.kt`.
- Change `versionName` or `versionCode` derivation in `android/app/build.gradle.kts` to something non-monotonic. The updater compares `versionCode` numerically — if it doesn't increase per release, clients stop pulling updates.
- Rename or move the APK asset away from `app-release.apk`. The updater picks the first asset whose name ends in `.apk`.
- Change the FCM topic from `app-updates` in one place without changing it in all of: `HomebrewerApp.kt` (subscription), `PushService.kt` (handling), `scripts/send_fcm_update_push.py` (publishing).

## 4. Never break signing

Android refuses to install an APK signed by a different key over an existing install. There is no recovery path.

- Never regenerate the keystore. The keystore lives only as the `KEYSTORE_BASE64` GitHub Actions secret + a backup the user holds offline.
- Never commit `*.jks`, `release.jks.base64`, `keystore.properties`, or any file containing a keystore password. `.gitignore` covers the obvious filenames; double-check `git status` before pushing.
- If a build fails because the keystore secret is missing, **stop and ask** — do not "fix" it by removing the signing config or falling back to debug signing on `main`.

## 5. Firebase / FCM

- `android/app/google-services.json` ships with a `REPLACE_ME` placeholder so the build works without Firebase. The `com.google.gms.google-services` plugin only applies if the file is present and does not contain `REPLACE_ME` — see `android/app/build.gradle.kts`. Do not change that gating logic.
- `FCM_SERVICE_ACCOUNT_JSON` is optional. The push step in CI is a no-op when it is unset; do not make CI fail on its absence.
- Do not commit a real `google-services.json` or any service-account JSON. Real values live in GitHub Actions secrets.

## 6. Package + naming

- Package: `com.shadaeiou.homebrewer`. Do not rename without a coordinated update across `build.gradle.kts` (namespace + applicationId), every `package` statement, and the source directory layout.
- App display name: edit [`android/app/src/main/res/values/strings.xml`](android/app/src/main/res/values/strings.xml) `app_name` only.
- `applicationId` must never change post-launch. Changing it makes the app look like a different app to Android — existing installs cannot upgrade.

## 7. Pre-commit checklist

Before `git commit` on any user-visible change:

- [ ] `Changelog.kt` has a new top entry, with `version` matching the `versionName` this commit will ship as (`0.1.$(($(git rev-list --count HEAD) + 1))`).
- [ ] `git status` shows no `*.jks`, `*.keystore`, `*.base64`, real `google-services.json`, or service-account JSON.
- [ ] `cd android && ./gradlew :app:assembleDebug` succeeds locally (or the user has explicitly waived this for a docs-only / config-only change).
- [ ] You are pushing to `main`.

## 8. Things to ask before doing

Surface a question to the user — do not silently proceed — for any of:

- Changing the keystore, signing config, or anything that could invalidate existing installs.
- Changing `applicationId`, package name, or the GitHub repo owner/name in `Updater.kt`.
- Changing the version scheme (`versionCode` / `versionName` derivation).
- Adding a new dangerous permission to `AndroidManifest.xml`.
- Removing entries from `Changelog.kt`.
- Force-pushing or rewriting history on `main`.
