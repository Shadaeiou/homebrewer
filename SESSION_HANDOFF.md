# Session handoff — 2026-05-10

This is a context dump from the prior Claude session, written for a fresh Claude inheriting the Homebrewer project after an environment refresh. **Read this before doing anything else.** Then read [`HANDOFF.md`](HANDOFF.md), [`DESIGN.md`](DESIGN.md), and [`CLAUDE.md`](CLAUDE.md) — those remain canonical for project state, design, and rules.

This file is throwaway: once you've absorbed it (or rolled relevant pieces into `HANDOFF.md`), delete it.

---

## TL;DR — first move in the new env

1. **Verify the new env actually works.** Run:
   ```bash
   command -v sudo xvfb-run jq java adb emulator
   sudo apt-get update && echo "sudo OK"
   ls /dev/kvm && groups | grep -q kvm && echo "kvm group OK"
   ```
2. **Confirm `git rev-list --count HEAD` and the latest release.** Last release should be `v0.2.89+89` (the rollback). Main HEAD should be commit `a092800` "Revert v0.2.88 — Android startup crash; back to v0.2.86 baseline."
3. **Run `scripts/dev-check.sh` end-to-end.** With xvfb in the new env this should now pass cleanly including the screenshot harness. Expected: 133/133 GUT tests, 13 screenshot captures, exit 0.
4. **Then propose to the user:** add Firebase Crashlytics + a small re-attempt at the Godot 4.6 bump split into safe slices (plan in §"Recommended next moves" below).

**Do not push anything to `main` until you've confirmed an APK actually launches on Android.** That's the lesson from this session — see §"Lessons" for the painful version.

---

## Where things stand right now

**Git state:**
- HEAD on `main`: `a092800` (Revert v0.2.88 — Android startup crash; back to v0.2.86 baseline)
- `git rev-list --count HEAD`: `89`
- Last successful APK release: `v0.2.89+89` — this is functionally the same code as `v0.2.86` because `a092800` reverts both of my session's commits (`df24a81` "Foundation cleanup" and `93e067e` "Fix Godot 4.6.2 export").

**What's running on the user's phone:** v0.2.89 (the rollback). They were going to install it after I shipped — confirm with them whether it's actually installed and working before doing anything else.

**What's broken / unresolved:**
- The actual Godot 4.6 + Android startup crash is **NOT diagnosed**. v0.2.88 force-closed at launch on the user's phone. We never got logs because the user is hands-off on Android (no adb) and we had no on-device crash reporting.
- The CI workflow is back on Godot 4.3-stable. Tests claim "133/133 passing" but actually — see "lessons" — that hides 6 silent failures because GUT 9.6.0 (in the repo) requires Godot 4.6+. On the rollback baseline, the GUT addon's parse errors get swallowed and the test run lies.

**What I shipped this session that landed and stuck:** nothing. The work all got reverted. The repo state is identical to commit `1a5da37` from before my session (plus the rollback commit on top).

---

## The active problem: Godot 4.6 + Android startup crash

### What we know

- v0.2.88 (Godot 4.6.2 build, min_sdk 24) installed cleanly on the user's phone but force-closed at launch.
- Symptoms reported: "even after uninstall reinstall it just force closes." Cold start, fresh install, no save migration involvement.
- v0.2.86 (Godot 4.3 build, min_sdk 21) works fine.
- CI for v0.2.88 was green: import OK, 139/139 GUT tests passing, screenshot harness rendered all scenes successfully.
- The export step initially failed with two issues I fixed in `93e067e`:
  - "Min SDK cannot be lower than 24, which is the version needed by the Godot library" → bumped `gradle_build/min_sdk` from 21 to 24.
  - "Template installed: 4.6.stable / Requested version: 4.6.2.stable" → set `GODOT_VERSION` to `"4.6.2"` (was `"4.6"`) so the templates path matched.
  - Both fixes were correct AT THE EXPORT LEVEL — APK built, signed, released. The runtime crash is downstream of all that.

### What we don't know

- **The actual stack trace.** No Crashlytics. User won't run adb. The crash dialog on Android may have shown something but the user didn't capture it.

### Hypotheses ranked by likelihood

1. **Java overlay (`godot/android/build_overlay/src/com/shadaeiou/homebrewer/`) is incompatible with Godot 4.6's Android template.**
   - `HomebrewerInit.java` is a manifest-declared `ContentProvider` that runs before the Activity, calls `FirebaseApp.initializeApp(...)`, then `FirebaseMessaging.getInstance().subscribeToTopic("app-updates")`.
   - If Godot 4.6's gradle template pulls a different androidx version that conflicts with `firebase-messaging:24.0.3` (declared in `addons/firebase_messaging/firebase_export_plugin.gd`), the ContentProvider could throw on init, killing the whole process before the app's main Activity even loads.
   - **Most likely culprit.** Easy to test once you can run the emulator: install, watch logcat, look for `AndroidRuntime` exceptions.

2. **Godot 4.6 GL ES driver issue on the user's specific device.**
   - Godot 4.6 changed some renderer defaults. `project.godot` declares `"GL Compatibility"` mode + `gl_compatibility` rendering driver, which should work — but device-specific bugs in 4.6 are possible.
   - Lower likelihood given other 4.6 Android apps work fine generally, but worth verifying.

3. **My GDScript changes' boot-time side effects.**
   - `EquipmentDefs` was refactored to reference `Apartment2D.STATION_*` constants from inside its own `const` block. GDScript class_name resolution is supposed to be fine here (the screenshot harness validated it), but Android's class registry init order could differ.
   - Lower likelihood because the screenshot harness loaded every scene including the dashboard which preloads EquipmentDefs.

4. **Schema fork removal broke something at startup.**
   - I removed `inventory.equipment` and `inventory.journal` from `_initial_inventory()`. But this was a fresh install, so migration didn't run. New careers just don't have those keys. No reader of those keys exists anywhere I could find. Very low likelihood.

### The right diagnostic path (with the new env)

1. **Set up Firebase Crashlytics** (see §"Recommended next moves") — captures all future crashes hands-off.
2. **Boot v0.2.88 in the local Android emulator.** Reproduce the crash, capture logcat. This is now possible with KVM + emulator + adb in the new env.
3. **The trace tells you which hypothesis is right.** Fix forward from there.

---

## The new env (what's now available)

The user's infra Claude is provisioning a refreshed pod with:

- `sudo` with NOPASSWD for the `node` user
- xvfb + Mesa GL libs (so screenshot harness runs locally)
- `jq`, JDK 17, Android emulator runtime libs, build tools
- `claude-code`, `wrangler`, `gh` installed system-wide
- `node` user in the `kvm` group (GID 994); `/dev/kvm` mounted from host
- Privileged container in a privileged-allowed namespace
- Memory request bumped to 1 GiB; limit 8 GiB (emulator headroom)

**What this enables that wasn't possible before:**

- Run the screenshot harness locally → visual verification of UI changes without pushing to CI
- Build APKs locally with `godot --headless --export-release` → catch export errors in seconds instead of CI cycles
- Run the Android emulator with KVM acceleration → install APKs locally, watch logcat, catch runtime crashes BEFORE pushing to main

**What you need to install / set up after first boot:**

- Godot 4.6.2 binary (the prior session had it at `/home/claude/bin/godot`; may need re-download from `https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip`)
- Godot Android export templates (~500 MB, downloadable from the same release)
- Android SDK components: `platform-tools build-tools;34.0.0 platforms;android-34 system-images;android-24;default;x86_64`
- An AVD (Android Virtual Device) configured for API 24, x86_64. The user's phone runs Android 7+ presumably (otherwise v0.2.86 wouldn't run); API 24 is the new min.
- Note: previously I downloaded Godot to `/home/claude/bin/godot`. Confirm whether that PATH and binary survived the env refresh.

---

## Recommended next moves

### Move 1 — Verify the new env (5 min)

Run the commands in §"TL;DR" above. Confirm xvfb works, KVM is accessible, `dev-check.sh` passes end-to-end including screenshots. If anything's missing or broken, the user's infra Claude needs to know.

### Move 2 — Add Firebase Crashlytics to the APK (the hands-off telemetry path)

Why: makes future Android-runtime issues self-diagnosing. The user has stated explicitly they will not run adb / dev tools (saved in memory `feedback_homebrewer_workflow.md`). The only way to debug Android crashes hands-off is on-device crash reporting that uploads to a backend you can read.

What to do:

- Add `com.google.firebase:firebase-crashlytics:<latest>` to `addons/firebase_messaging/firebase_export_plugin.gd`'s `_get_android_dependencies` (or split out a new `addons/firebase_crashlytics/` plugin if you want clean separation).
- Add the Crashlytics gradle plugin (`com.google.firebase.crashlytics`) — Godot's gradle template may need an overlay for the plugin block. Check.
- Initialize Crashlytics in `HomebrewerInit.java` (the existing ContentProvider) right after `FirebaseApp.initializeApp(...)`. Crashlytics auto-installs an UncaughtExceptionHandler.
- Have user enable Crashlytics in the Firebase console (one click).
- Optional but recommended: enable BigQuery export from Firebase → Crashlytics. Then I can query crash data via `bq` (gcloud) using the same `FCM_SERVICE_ACCOUNT_JSON` secret CI already has. Fully hands-off.

This commit can ship to main on its own. It doesn't change the Godot version or anything else risky. Verify it locally on the emulator first.

### Move 3 — Re-attempt the Godot 4.6 bump in safe slices

Once Crashlytics is live, the user's next install of a broken APK gives me actionable telemetry. Then:

1. **Slice A — workflow only.** Bump `GODOT_VERSION` to `4.6.2` and `GODOT_RELEASE` to `4.6.2-stable` in `.github/workflows/build-android.yml`. Bump `gradle_build/min_sdk` to 24 in `godot/export_presets.cfg`. Bump `config/features` to `"4.6"` in `project.godot`. **Do NOT touch GDScript or schema.** Build local emulator APK first, verify it boots; then push.
2. **Slice B — dev-check + GUT enforcement.** Add the dev-check.sh CI step + xvfb install. Tighten dev-check.sh's GUT step to fail on "Failed to load script" / "Ignoring script" (silent test rot caught in this session — see §"Findings"). Don't bundle code changes here.
3. **Slice C — migration registry refactor.** From the prior session's `df24a81`, isolate just the SaveService + GameState migration changes. Tests should still pass. Verify on emulator.
4. **Slice D — schema fork.** Remove `inventory.equipment`, add `bottling_bucket.tres` + `auto_siphon.tres`, refactor EquipmentDefs. Player-visible — picker labels change. Verify on emulator.
5. **Slice E — versioning hook + dashboard de-hardcode.** Independent small wins.

Each slice = one commit + one phone-install verification. If anything breaks, only that slice gets reverted.

The big mistake I made was bundling A+B+C+D+E into one commit. When v0.2.88 crashed, I had no way to know which slice was responsible without diagnostic data.

### Move 4 — Then resume HANDOFF.md's open items

After all the above, the open feature work picks up. From `HANDOFF.md` "Build sequence — what's left":

1. Recipe-from-journal flow
2. Sanitize as a real mini-game (low priority)
3. Front-door interactions
4. Forum / News / Calendar phone apps
5. Inventory consumption
6. More recipes (West Coast IPA, Dry Stout)
7. Anomalies / cleanliness state machine
8. Bottling close-up rewrite
9. Tasting close-up rewrite

The user has not committed to a specific next item. Ask them when you're at this stage.

---

## Critical user preferences (in memory)

Two memory files were saved this session — read them via the memory system before responding:

- `feedback_ownership.md` — User wants ownership and challenge, not deference. They explicitly said "this is yours now and I want you to challenge any decisions including my own, don't be a yes man but also don't argue for the sake of arguing." When you see spec rot, schema drift, dead code, version mismatches — surface it, don't quietly leave it.

- `feedback_homebrewer_workflow.md` — Hands-off Android verification. User does NOT run adb. They install the APK and report works/doesn't-work. Diagnostics for Android-runtime issues must be captured on-device automatically (Crashlytics is the durable solution). Don't ask them for adb logcat — it's a sign you haven't built the right infrastructure.

---

## Findings I surfaced this session that are still open

These are real issues from a code review of the project. Some were fixed and reverted; some weren't fixed at all. Listed in priority order; pick them up when relevant.

1. **Spec deviation on starter equipment.** `bottling_bucket` and `auto_siphon` are listed under DESIGN.md Appendix A "Notable absences" but the bottling-table flow currently assumes the player owns them. Two valid resolutions: update DESIGN.md to reflect the as-built reality, or gate the bottling flow on Shop purchases. (The Shop UX exists; consumption doesn't.)

2. **`brewing_day.tscn` is deprecated but not deleted.** HANDOFF.md says it's kept "because tests still reference it." There are also 3 entries for it in the screenshot harness's `SCENES` list. Code rot + screenshot rot — should be deleted along with `tests/scene/test_brewing_day_scaffold.gd` and the harness entries.

3. **`add_lme` step ID maps to `pour_lme.tscn` scene name.** Mismatch in `dashboard.gd:41`. Pick one. I'd rename the step ID to `pour_lme` (the file/scene is the visible thing).

4. **Per-brew `rng_state` is set once at brew creation and never mutated.** In `brew_state.gd:33`. Either intentional (deterministic re-grade on reload) or oversight (every drift call re-rolls the same number). Needs a design call. If intentional, a comment locks the contract.

5. **`Updater` hits api.github.com on every app launch** with no rate-limit handling. Fine sideload-only; budget a backoff if you ever ship through a store.

6. **No display-name registry for skill axes.** Every UI that wants to show "Temperature Control" instead of `"temp_control"` rolls its own mapping. One `SkillXP.DISPLAY_NAMES` const closes the door. Will be needed for the Forum / journal / phone UI.

7. **`Updater` + `Crashlytics` (when added) hit external services on every launch.** Combined with the Firebase init in `HomebrewerInit.java`, app cold-start has 3+ network calls. Consider deferring non-critical ones until after the first frame renders.

8. **Node.js 20 actions deprecation in `build-android.yml`.** GitHub will force Node 24 on June 2nd, 2026. Bump action versions when convenient (`actions/checkout`, `actions/setup-java`, `actions/setup-android`, `actions/setup-python`, `actions/upload-artifact`, `softprops/action-gh-release`).

9. **Two duplicated constants.** `SAVE_FORMAT_VERSION` in `game_state.gd:22` and `CURRENT_SAVE_VERSION` in `save_service.gd:22` must agree but nothing enforces it. One should reference the other.

10. **CLAUDE.md §2 changelog rule is enforced by manual discipline.** I built `scripts/check-changelog-version.sh` to mechanize it (catches "you bumped to wrong version" and "released APK won't match its What's-new screen"). It got reverted with the rest. Re-introduce in Slice B.

11. **GUT silently swallows test-file parse errors.** `test_tasting.gd` was failing to parse on Godot 4.6 strict typing — its 6 tests weren't running and HANDOFF.md's "133/133 GUT tests" claim was hiding lost coverage. I added a guard to dev-check.sh's GUT step to fail on "Failed to load script" and "Ignoring script". Re-introduce in Slice B. Also, fixing `test_tasting.gd`'s parse errors exposed a real test bug: the fixture used `"skill_snapshot": {}` which Grader treats as no-cap → A+, so the assertion "fresh-career skills cap at C" was never actually being checked. Both the parse fix and the fixture fix should be re-introduced.

---

## Lessons from this session (the painful ones)

1. **CI green ≠ APK works.** The screenshot harness uses Godot's headless renderer + software GL. It does NOT exercise the Android runtime path: Java overlay init, Firebase ContentProvider startup, JNI bridge, real GL ES, Android lifecycle. A change can pass every static check, render every scene perfectly in the harness, and still crash at app start on a phone. **Phone-install verification is required for any Android-target change.** Until the new env's emulator is set up, that means asking the user to install before you push, OR shipping with on-device crash reporting that fails loudly.

2. **Bundling many concerns into one commit hides which one broke things.** I shipped 5 independent changes (CI bump, migration refactor, schema fork, versioning hook, dashboard de-hardcode) as a single commit. When the APK crashed, I had no way to know which slice was responsible without telemetry I didn't have. Smaller commits + verification gates between them would have isolated the problem in minutes.

3. **The "all tests passing" number can lie.** GUT reported 133/133 in the rollback baseline, but 6 tasting tests weren't actually running because their file failed to parse on the Godot version GUT requires. The dev-check.sh GUT-step guards I built (treat "Failed to load script" and "Ignoring script" as fatal) need to be re-introduced.

4. **"Trust but verify" includes the verifier.** I trusted the screenshot harness as my verification surface for Android-target changes and didn't notice it wasn't testing what I needed it to test. The next harness should target the actual artifact: an emulator install + boot.

5. **A user saying "if you're satisfied, push" is not a license to skip phone verification on a target you can't test.** I should have responded with "I can't verify Android runtime in this env — want to install on yours and confirm before I push?" instead of pushing on CI green alone.

6. **Reverts ship as new commits.** Don't `git reset --hard` on `main` after a bad push. The rollback I did (`a092800`) is a `git revert --no-commit 93e067e df24a81 && git commit` which produces a new commit that reverses the changes. The bad commits stay in history (audit trail intact); the new commit produces a higher versionCode so the rollback APK installs over the broken one (Android requires monotonically increasing versionCode).

---

## Files I touched in `df24a81` (foundation cleanup, REVERTED)

For reference when re-introducing in slices:

- `.github/workflows/build-android.yml` — bumped Godot 4.3 → 4.6.2, added xvfb install + dev-check step
- `godot/project.godot` — `config/features` "4.3" → "4.6"
- `godot/systems/save_service.gd` — real `_migrate_v1_to_v2(save_dict)` migration, removed reseed-on-adopt
- `godot/systems/game_state.gd` — adopt now fires state_loaded; removed `inventory.equipment` + `inventory.journal` from `_initial_inventory`; added `bottling_bucket` + `auto_siphon` to `STARTER_EQUIPMENT_PATHS`
- `godot/scripts/lib/equipment_defs.gd` — full rewrite to read from `equipment.owned`, category-based station fit, display from archetype
- `godot/scripts/lib/apartment_2d.gd` — header docstring rewritten (was stale, said "1200×620 panorama" with wrong stations)
- `godot/scripts/dashboard.gd` — removed `STARTER_RECIPE_ID` hardcode, `_first_known_recipe_id()` helper
- `godot/data/equipment/auto_siphon.tres` — NEW
- `godot/data/equipment/bottling_bucket.tres` — NEW
- `godot/tests/scene/test_save_migration.gd` — exercises new migration interface
- `godot/tests/scene/test_save_round_trip.gd` — expects 10 starter equipment (was 8)
- `godot/tests/sim/test_tasting.gd` — fixed Godot 4.6 typed annotations + skill_snapshot fixture bug
- `scripts/check-changelog-version.sh` — NEW
- `scripts/dev-check.sh` — added changelog check + GUT silent-failure guards
- `DESIGN.md` — added `day_clock` to player_meta schema (was code-only)

## Files I touched in `93e067e` (build fix, REVERTED)

- `.github/workflows/build-android.yml` — `GODOT_VERSION` "4.6" → "4.6.2"
- `godot/export_presets.cfg` — `gradle_build/min_sdk` 21 → 24
- `README.md` — minSdk 21 → 24 documentation update
- `godot/data/changelog.json` — folded prior 0.2.87 entry into 0.2.88

The rollback (`a092800`) reverses all of the above, plus contains the only kept artifact: a new top changelog entry for v0.2.89 noting the rollback.

---

## Things to ask the user before assuming

- "Did v0.2.89 install cleanly and behave like v0.2.86 did?" — confirm the rollback worked end-to-end before any new work.
- "Is Crashlytics already enabled in the Firebase console for project `homebrewer-6a67c`?" — affects Slice B work.
- "Is BigQuery export from Firebase configured for crash data?" — if not, it's a one-time setup on their end.
- "Want me to set up the local emulator + AVD config now, or skip straight to Crashlytics?" — gives them control over sequencing.

---

## One-liner prompt to give the new Claude

If you want to start a fresh Claude session pointing at this:

> Read `SESSION_HANDOFF.md` at the repo root. After absorbing it, verify the new env per its "TL;DR" section, then propose your next move. Don't push to main without phone-install verification — that's the lesson from the prior session.

— end of handoff —
