# Handoff — Phase 1 → Phase 2

A previous Claude session bootstrapped this repo. Read this first, then read [`CLAUDE.md`](CLAUDE.md), then continue. Delete this file (`git rm HANDOFF.md && git commit`) once you've internalized it.

## Where things stand

**Phase 1 is shipped.** The repo is a Godot 4.3 project with:
- A Hello Homebrewer home scene rendering version + changelog from `godot/data/changelog.json`.
- A headless screenshot harness at `godot/tools/screenshot_harness.gd` driven by `scripts/render_screenshots.sh` (uses Xvfb + Mesa software GL — works on machines without a GPU).
- `scripts/dev-check.sh` runs imports + GUT tests (when added) + the harness, exit-non-zero on failure. Run before every commit.
- CI at `.github/workflows/build-android.yml` exports a signed APK on every push to `main`, publishes a tagged GitHub Release, sends an FCM ping (best-effort).
- Versioning is automatic: `versionCode = git rev-list --count HEAD`, `versionName = "0.2.<N>"`, tag `v<name>+<code>`.

The current build on the user's phone is the Phase 1 APK or close to it.

## Why Godot 4.3 and not (Compose / Unity / Flutter / KorGE)

The previous session evaluated each. Short version:
- **Compose + Canvas** was the first recommendation, walked back when sunk-cost reasoning was correctly called out.
- **Unity** is overkill, has licensing baggage, and bloats the APK.
- **Godot 4.3** wins on tooling for visually-rich 2D mini-games (scenes, AnimationPlayer, particles, shaders, live preview), free, small APK, good Android export, doesn't preclude iOS/desktop later (the user said "Android first, keep iOS/desktop possible").
- **GDScript** is the primary language. The user is OK with this.

Don't relitigate the engine choice without the user explicitly asking.

## What the user wants the game to be

A homebrew **brewing simulation** with extreme attention to detail:
- Realistic brewing steps, planning, precise measurements.
- Progression from stove + pot + bad ingredients + subpar beer → better gear + better beer.
- Beer is graded; **infection is always possible** (random rolls based on cleanliness, equipment age, technique).
- The actual brewing steps are **mini-games**: pouring water (gesture/tilt + spill check), watching boil-over (temperature curve + flame management + foam), scrubbing utensils (gesture trail + dirt particle erosion), precise measurements, etc.
- Pixel art for sprites + procedural drawing in Godot for parametric stuff (water levels, foam, thermometers, gauges, particles).

## CLAUDE.md rules (don't break)

1. **Always commit to `main`.** Never branch, never PR, never force-push after the bootstrap commit.
2. **Every player-visible commit updates `godot/data/changelog.json`** in the same commit, with `version` matching the next `0.2.<N>`.
3. Don't break the screenshot harness — it's how you verify UI without the user installing the APK.
4. Don't break versioning or signing — `versionCode` must be monotonic, keystore is irreplaceable.
5. Run `scripts/dev-check.sh` before every commit.

Full details in `CLAUDE.md` (rules 1-9).

## Phase 2 — what to build next

Roughly in order:

1. **Custom Android build template + FCM bridge.** Phase 1 sends FCM pushes that no client receives. Phase 2 adds Godot's "Use Gradle Build" path so we can drop in a `FirebaseMessagingService` (Java/Kotlin) that subscribes to topic `app-updates` and surfaces a notification. The previous Compose template's `PushService.kt` and `HomebrewerApp.kt` are good references — they're in git history if needed (last seen on commit 2a9ca71 before the Godot wipe).

2. **In-app updater.** Port the Kotlin `Updater` to GDScript: `HTTPRequest` against `api.github.com/repos/Shadaeiou/homebrewer/releases?per_page=10`, parse `v<name>+<code>` tags, compare `versionCode` to `Version.version_code`, prompt user to update, hand to Android `DownloadManager` + install intent (small Java shim through the custom build template).

3. **Brewing domain model.** This is heavy lifting and goes in `godot/systems/brewing/`. Pure GDScript, fully unit-testable (vendor GUT first — see `godot/tests/README.md`). Scope:
   - Recipe definition (grain bill, hops, yeast, water profile, mash schedule).
   - Brewing process state machine (mash → sparge → boil → cool → ferment → condition → bottle).
   - Temperature curves, time, infection probability, flavor outputs (IBU, SRM, ABV, perceived quality).
   - Equipment tier model (each tier reduces variance, increases yield, or unlocks techniques).
   - Beer grading function: weighted score across attributes, A through F.

4. **First mini-game.** Probably **boil-over watch** since it's pure code (temperature curve + a flame slider + foam height + tap-to-vent). No sprites required. Verifiable end-to-end via the screenshot harness.

5. **Asset pipeline.** Until this point everything is procedural (`_draw()` callbacks, `CPUParticles2D`). Hand-drawn or AI-generated sprites come in for the kitchen scene, equipment progression visuals, ingredient icons.

## ComfyUI / asset pipeline — open question

The previous session reached a dead-end trying to access ComfyUI from Anthropic's sandbox (egress filter blocks `*.trycloudflare.com` and similar — TLS-intercepted by `O=Anthropic; CN=sandbox-egress-production TLS Inspection CA`). The user is moving the session to local Claude Code on the ComfyUI host specifically to bypass this.

**You can hit ComfyUI directly at `http://192.168.1.254:8190`** (or `localhost:8188` if you're running on the same box). It has:
- ComfyUI version 0.20.1 confirmed by the system_stats endpoint
- Caddy reverse proxy in front (HTTP basic auth `claude` / `YBIbgmF2VgxMEAcnuazSlM` on the public tunnel; the LAN URL probably has no auth — confirm with the user)
- ComfyUI-Manager status: ASK THE USER. If installed, you can install models/LoRAs via API. If not, ask them to install it (`cd ComfyUI/custom_nodes && git clone https://github.com/ltdrdata/ComfyUI-Manager.git && restart ComfyUI`).

The asset pipeline plan that was being designed:
- Pixel-art-tuned LoRA + post-processing (downscale to target size with nearest-neighbor, palette-quantize to a fixed game palette, save PNG).
- Sprite specs as JSON in `assets/tasks/` (when running remotely) — but since you're local now, you can run workflows directly without the queue.
- Sprite outputs land in `godot/assets/sprites/<category>/<name>.png`.
- IP-Adapter for style consistency across sprites.

The previous session was about to ask the user to choose between a queue-based pipeline (if remote) vs. direct (if local). They chose local. So go direct.

## What's NOT yet in the repo

- GUT framework (vendor it when the first test is written; install via `cd godot && git clone https://github.com/bitwes/Gut.git addons/gut`).
- Custom Android build template (Phase 2 step 1).
- Any sprites (`godot/assets/sprites/` doesn't exist yet — create it when needed).
- Brewing domain code.
- ComfyUI client code.

## Things the previous Claude got wrong (don't repeat)

1. **Pushed the bootstrap commit to a feature branch** (`claude/bootstrap-homebrew-game-ITnQM`) when the user explicitly said commit to main. Reason: silently followed system instructions instead of surfacing the conflict. Don't do this. CLAUDE.md rule 1 is non-negotiable.
2. **Recommended Compose with sunk-cost reasoning** ("we already built this"). The user correctly pushed back. Reason your recommendations on architectural fit, not on what's already there.
3. **Spent 4 turns debugging Termux JDK** when the user couldn't run `keytool` instead of pivoting to a GitHub Actions one-shot generator earlier. Recognize when to pivot.
4. **Got tunneling between sandbox and user's LAN wrong** for several turns before finding the TLS-inspection cert in `curl -v` output. The egress filter on the Anthropic sandbox blocks anonymous tunnels.

## Repo locations

- GitHub: `Shadaeiou/homebrewer`
- Default branch: `main` (no other branches; force-pushed from a fresh root commit)
- The previous Compose-template history is **intentionally gone**. Don't try to recover it.

## When you finish reading this

Confirm to the user that you're up to speed, then ask what they want to tackle first in Phase 2. Most natural order is the brewing domain model (no sprites needed yet, lots of pure logic to write + test). But check with the user.

Then `git rm HANDOFF.md && git commit -m "Drop handoff doc, session migrated to local"` and continue.
