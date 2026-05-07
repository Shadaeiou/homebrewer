# CLAUDE.md — rules for this repo

These rules are not suggestions. Every change to Homebrewer must follow them. If a rule conflicts with a user instruction, surface the conflict before acting.

## 1. Always commit to `main`

- **Branch policy:** all work lands on `main`. No feature branches, no PRs, no merges. Push directly to `origin/main`.
- The release pipeline (`.github/workflows/build-android.yml`) only fires on `push` to `main` and on `v*` tags. Commits on any other branch produce no APK and no release.
- If the user explicitly tells you to use a different branch for one specific task, do it for that task only and then return to `main` for everything else.
- Never force-push `main` after the bootstrap commit. Never rewrite published history. To undo a commit, add a new commit that reverts it.

## 2. Every commit ships a release — bump the changelog accordingly

Versioning is automatic. CI computes:

- `versionCode = git rev-list --count HEAD` (integer, monotonic)
- `versionName = "0.2.<versionCode>"` (the `0.2` prefix marks the Godot era; bump to `0.3` only on a major shape change)

Every push to `main` produces a GitHub Release tagged `v0.2.<N>+<N>` with the signed APK attached. The in-app **What's new** screen MUST reflect what shipped.

### The rule

**Every commit to `main` that produces a player-visible change must also update [`godot/data/changelog.json`](godot/data/changelog.json) in the same commit.**

Player-visible = anything a player would notice: gameplay, UI, content, balance, copy, fixed bugs, performance, new permissions, new screens.

Internal-only (no entry needed): refactors with no behavior change, comment edits, build-script tweaks that don't change the artifact, dependency bumps with no observable effect, CI/workflow edits, formatting, screenshot harness changes, test changes.

When in doubt, add an entry. An over-documented changelog is fine; a stale one is not.

### How to update the changelog

`changelog.json` is the single source of truth — there is no separate `CHANGELOG.md`, no GitHub Release notes authoring, nothing else. The `Changelog` autoload (`godot/systems/changelog.gd`) loads it once at startup and the main scene renders it.

Each entry is:

```json
{
  "version": "0.2.<N>",
  "date": "YYYY-MM-DD",
  "bullets": ["Short, present-tense, player-facing line."]
}
```

`version` must equal the `versionName` THIS commit will produce. Compute it before committing:

```bash
echo "0.2.$(($(git rev-list --count HEAD) + 1))"   # versionName the next commit will ship as
```

If the new entry's version equals the previous entry's version, you have a duplicate — fold the bullets into the existing top entry instead of adding a duplicate.

`date` is the UTC date of the commit, in `YYYY-MM-DD`.

`bullets` are short, player-facing, present tense: "Added X", "Fixed Y", "Rebalanced Z". No issue numbers, no commit hashes, no internal jargon.

Add new entries to the **top** of the array, never the bottom. The first entry renders expanded; older entries are listed below.

## 3. Pre-commit checklist

Before `git commit` on any player-visible change:

- [ ] `changelog.json` has a new top entry whose `version` equals `0.2.$(($(git rev-list --count HEAD) + 1))`.
- [ ] `scripts/dev-check.sh` exits 0 (imports clean, GDScript parses, GUT tests pass, screenshot harness produces a PNG without errors).
- [ ] You looked at the freshly-rendered `screenshots/main.png` (and any other affected screenshot) — visual layout still looks right.
- [ ] `git status` shows no `*.jks`, `*.keystore`, `*.base64`, real `google-services.json`, or service-account JSON.
- [ ] You are pushing to `main`.

## 4. Project layout — where things live

| Path | Purpose |
|---|---|
| `godot/project.godot` | Engine config. `application/config/version` is rewritten by CI per build. |
| `godot/scenes/` | `.tscn` scenes (one per screen / mini-game). |
| `godot/scripts/` | GDScript controllers attached to scenes. |
| `godot/systems/` | Cross-cutting singletons (autoloads): `Changelog`, `Version`, future brewing simulation. |
| `godot/data/` | Player-facing data: `changelog.json`, recipe definitions, equipment tiers, etc. Source of truth lives here, not in scripts. |
| `godot/assets/sprites/` | Imported pixel-art PNGs. Each sprite has an Aseprite-or-equivalent source somewhere; the PNG is what ships. |
| `godot/tools/` | Editor/headless utilities. `screenshot_harness.gd` is the most important one — the visual verification path runs through it. |
| `godot/tests/` | GUT test files. Pure-domain tests in `tests/sim/`, scene-shaped tests in `tests/scene/`. |
| `godot/export_presets.cfg` | Export config. Keystore values are placeholders; CI sed-injects real values from secrets at build time. |
| `scripts/dev-check.sh` | Runs every static check. Run before every commit. |
| `scripts/render_screenshots.sh` | Wraps the harness with Xvfb so software-GL works on machines without a GPU. |
| `scripts/send_fcm_update_push.py` | CI-only. Sends the post-release FCM ping. |
| `screenshots/` | Output of the harness. Gitignored. |

## 5. Never break the visual verification loop

The screenshot harness is how Claude verifies UI changes without the user installing the APK. Don't break it. Specifically:

- Don't remove `xvfb` or `mesa-utils` from the dev environment.
- If you add a scene that's hard to render headlessly (real-time particles that spawn from input, gesture-driven mini-games), add a "rest pose" entry point so the harness still produces a meaningful frame.
- Add new scenes to the `SCENES` list in `godot/tools/screenshot_harness.gd` when they're worth visually verifying.
- The harness runs on every `dev-check.sh`. If it starts failing, fix it — don't just delete the failing scene from the list.

## 6. Never break versioning / the updater

The release tags follow `v<versionName>+<versionCode>`. The `versionCode` must be monotonically increasing — Android's package manager refuses to install an APK whose `versionCode` is not greater than the installed one. Do not:

- Change `versionCode` derivation away from `git rev-list --count HEAD`.
- Change the version prefix without bumping the major (`0.2` → `0.3` on a major shape change; never go backwards).
- Rename the APK away from `homebrewer.apk` without simultaneously updating CI and the in-app updater (Phase 2).
- Change the FCM topic from `app-updates` in one place without changing it in all the others.

## 7. Never break signing

Android refuses to install an APK signed by a different key over an existing install. There is no recovery path.

- Never regenerate the keystore. The keystore lives only as the `KEYSTORE_BASE64` GitHub Actions secret + a backup the user holds offline.
- Never commit `*.jks`, `release.jks.base64`, `keystore.properties`, or any file containing a keystore password.
- Never commit a real `google-services.json` with FCM service-account credentials inside it (the Android-side `google-services.json` is fine; the service account JSON for sending pushes is NOT).
- If a build fails because the keystore secret is missing, **stop and ask** — do not "fix" it by removing the signing config.

## 8. Package + naming

- Package: `com.shadaeiou.homebrewer`. Lives in `godot/export_presets.cfg` as `package/unique_name`. Do not change post-launch — would orphan every existing install.
- Display name: `package/name="Homebrewer"` in the same file.

## 9. Things to ask before doing

Surface a question to the user — do not silently proceed — for any of:

- Changing the keystore, signing config, or anything that could invalidate existing installs.
- Changing `package/unique_name` (applicationId).
- Changing the version scheme (`versionCode` / `versionName` derivation, version prefix).
- Adding a new dangerous Android permission.
- Removing entries from `changelog.json`.
- Force-pushing or rewriting history on `main`.
- Migrating to a different game engine (we already did this once).
