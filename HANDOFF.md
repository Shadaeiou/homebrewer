# Handoff — implementation pickup

This file is the current working state. Read this first, then [`DESIGN.md`](DESIGN.md), then [`CLAUDE.md`](CLAUDE.md), then continue.

## Status (2026-05-09, post-0.2.68)

The full apartment-pale-ale **gameplay loop is reachable end-to-end** in form-style placeholder UIs. Steps 1–9 of the original build sequence are landed; Step 10 is partially landed; Step 11 is parked. The current priority is **Step 12 — real mini-games with graphics** (added below).

**What's playable now:**
- Phone overlay → Shop → buy ingredients with $30 against $51 list (canonical Appendix A trade-off).
- Dashboard → Today checklist + morning summary; tap brew row → Check fermenter modal.
- Start brewing → walk seven brewing-day stages (sanitize, fill kettle, heat placeholder, add LME, boil with hops, cool wort, transfer + pitch) → fermenting → bottle (24-bottle hard-block) → conditioning → pour & taste → grades + journal entry.
- Brewery journal viewer.
- Phone Messages with the Marcus cold-open thread + recipe card.
- Save migration v1→v2; day_clock persists; dev "Reset save" button on the dashboard.
- 133 GUT tests / 383 asserts green. 13 screenshot captures verified.

**What's NOT real yet:**
- Every brewing-day mini-game is a **form**, not a real mini-game. Radio buttons + checkboxes that satisfy the math contract (`Outcome` dict — actual / care / risk / xp / journal_notes / skill_snapshot) but not the gestures, timing, or visuals from DESIGN.md 3.9. **This is what Step 12 fixes.**
- No anomalies / cleanliness state machine / equipment scheduling (Step 11).
- No Forum / News / Calendar phone apps (Step 10 leftover).
- No commitments (Marcus's party deadline, Mom's stout, etc).
- No inventory consumption — one Shop trip carries arbitrarily many brews.
- Only one recipe (Apartment Pale Ale). West Coast IPA + Dry Stout per 3.8 are unbuilt; the recipe-driven prereq walker (0.2.68) is ready to handle them.

## Verification status

`scripts/dev-check.sh` exits clean (Godot 4.6.2 import + 133/133 GUT tests + 13 screenshot captures). Run on Windows via the `godot` shim in `~/bin`; the Linux/CI path wraps in Xvfb. Screenshots in `screenshots/` reflect current state of every scene that matters.

## Build sequence

In order. Don't skip; each step builds on the previous.

### 1. Validate the skeleton

```bash
scripts/dev-check.sh
```

Expected: import succeeds with no `SCRIPT ERROR` or `ERROR:` in the log; harness writes `screenshots/main.png` showing the dashboard (title "Homebrewer", "Day 0", "$30", "Bottles: 24 available · 0 in use", "Get some rest →" button, version label, changelog).

If anything errors, fix in place. The most likely problems are GDScript 4.x syntax issues in the new autoload/sim files or the `@onready var` resolution in `dashboard.gd`.

### 2. Vendor GUT and write the first sim tests

```bash
cd godot
git clone https://github.com/bitwes/Gut.git addons/gut
```

Then write tests under `godot/tests/sim/` (pure-domain, no scene tree):

- `test_drift.gd` — `Drift.compute_actual()` returns within ~3σ of target for a known seed; `skill_factor_from_level()` clamps correctly at 0 and 30.
- `test_skill_xp.gd` — `add_xp` levels up correctly; `apply_prestige_penalty` rounds 30 → 24, 7 → 5, 0 → 0.
- `test_grader.gd` — `max_grade_for_level(0..30)` matches the table in 3.4; `compose_final("A+", "C")` returns "C"; `ceiling_for_relevant_skills` takes the worst across snapshots.
- `test_care_factor.gd` — 0/N → 0.6; N/N → 1.0; midpoint linear.
- `test_risk_profile.gd` — `add_deltas` clamps at 10; `is_critical` threshold check.

These tests pin the math. Don't proceed to mini-games without them green.

### 3. Define static-content Resource classes

Create GDScript `Resource` subclasses with `@export` properties (these are the static content from DESIGN.md 8.10):

- `godot/data/recipe_def.gd` — class_name `RecipeDef extends Resource`. @export every field from 3.6's recipe schema (style, method, batch_size_gal, target_og, target_fg, target_ibu, target_srm, target_abv, fermentables array, hop_schedule array, yeast dict, ferment_temp_c, ferment_days, condition_days, priming_sugar_oz).
- `godot/data/equipment_archetype.gd` — class_name `EquipmentArchetype extends Resource`. @export the property bag fields per 3.2.
- `godot/data/style_profile.gd` — class_name `StyleProfile extends Resource`. @export BJCP-style guideline ranges (target_og_min/max, etc.) for use by `Grader` external evaluation per 3.6.

Then create the first content files:

- `godot/data/recipes/apartment_pale_ale.tres` (per 3.8 + Appendix A recipe card)
- `godot/data/equipment/apartment_stockpot.tres` (per 3.2 example + Appendix A equipment table)
- `godot/data/equipment/plastic_bucket_fermenter.tres`
- `godot/data/equipment/bi_metal_thermometer.tres`
- `godot/data/equipment/wing_capper.tres`
- `godot/data/styles/american_pale_ale.tres`

Add `tests/sim/test_recipe_def.gd` to confirm the .tres files load and have the expected fields.

### 4. Recipe-bootstrap the GameState

`GameState.reset_to_new_career()` currently leaves equipment + recipe_knowledge empty. Update it to load Appendix A's starter equipment from the .tres files and seed `recipe_knowledge.known["apartment_pale_ale"]` as unlocked.

Add `tests/scene/test_save_round_trip.gd` that calls `reset_to_new_career()`, has `SaveService` write to a temp save file, loads it back into a fresh `GameState`, asserts equality. This pins the persistence contract.

### 5. Brewing-day scene scaffold

Create `godot/scenes/brewing_day.tscn` + `godot/scripts/brewing_day.gd`. Lives under `ActiveSceneContainer` (per 7.2). On mount:

- Take `brew_id` and look up the brew from `GameState.data["brews_in_flight"]`.
- Render the recipe's stage list as a sidebar (mash/boil/cool/...).
- Slot for the current stage's mini-game scene to mount inside.
- Listen for `minigame_completed(outcome)` signal from child mini-games; call `BrewState.record_outcome()` and advance to the next stage.
- When all stages complete: transition the brew to "fermenting", call `Main.clear_active_scene()`, return to dashboard.

### 6. Dashboard "Start brewing" button

Add a button to `dashboard.gd` that:

- Validates: at least one fermenter is free (per 4.2 brewing-day-start rule); ingredients in inventory; cash for any consumables.
- Creates a fresh `BrewState` via `BrewState.make_new(...)` and pushes it onto `GameState.data["brews_in_flight"]`.
- Calls `Main.mount_active_scene(BREWING_DAY_SCENE)`.

Test: the button is disabled until conditions met; tapping it loads the brewing-day scene; closing the brewing-day scene returns to dashboard with the brew in flight.

### 7. Fill Kettle mini-game v2 (the first concrete mini-game)

Reimplement the prior proof-of-concept against the new contract per DESIGN.md 3.9 Mini-game #1:

- Sub-actions per the spec (source choice + method choice + optional verify).
- Outputs `Outcome` dict matching the universal scaffolding (`actual`, `care_factor`, `risk_deltas`, `xp_gained`, `journal_notes`, `skill_snapshot`).
- Care factor from `CareFactor.from_breadth(actions_taken, actions_available)`.
- Drift from `Drift.compute_actual(target=2.5, base_drift=0.5, ...)`.
- Skill snapshot from `SkillXP.snapshot(GameState.data["skills"])`.

The user already has good visual code for the kettle (the deleted `fill_kettle/kettle.gd` etc.). Pull the rendering / water-body / faucet visuals out of git history (look at SHA `4fa4a71` or earlier — pre-skeleton) for the pixel art and procedural drawing; rewrite the controller against the new mini-game contract.

Add `tests/sim/test_outcome_shape.gd` to lint the Outcome dict shape.

### 8. Stage placeholders → real mini-games

Implement the rest of Mini-games #2-12 from DESIGN.md 3.9 in this order:

- #4 Pour LME (the canonical procedure mini-game per 3.9 — implement procedure as a 4th interaction shape)
- #5 Bring to Boil (recognition + dial)
- #3 Boil + hops (mixed timing + decision)
- #6 Pitch yeast
- #5 Transfer to fermenter
- #4 Cool wort
- #11 Sanitize equipment
- #10 Clean equipment (closes the cleanliness state machine — needs Section 4 rest-of-section to land first)
- #8 Bottle fill
- #9 Cap bottles
- #12 Pour & taste
- #2 Mash temp hold (deferred until all-grain unlocks; v1 starts extract-only per 3.8)

Each mini-game gets its own subdirectory under `godot/scripts/minigames/<name>/` with a controller + visuals.

### 9. Bottling day + tasting scenes

Once Mini-game #5 (bottling) and #12 (tasting) land, add the bottling-day and tasting active scenes that orchestrate them. Tasting writes the completed `BrewState` as a journal entry via `SaveService.append_journal_entry()`.

### 10. Fermentation day rhythm + Phone overlay

The dashboard needs to handle Appendix B's day-by-day rhythm:

- Daily checklist computed from active brews + pending commitments + maintenance state.
- Morning summary card.
- Phone overlay (`PhoneLayer`) with Messages, Forum, News, Calendar, Shop apps. Each is its own subscene under `scenes/phone/`.
- Modal panels (`ModalLayer`) for "Check fermenter" perception, anomaly mitigation, decision dialogs.

This is when DESIGN.md 5 (Economy) and 6 (UX/UI) start needing real numbers and layouts. Talk to the user before locking either.

### 11. Rest of Section 4 (equipment scheduling + cleanliness state machine + anomalies)

The cleanliness state machine and anomaly generation are gating later mini-games (the cold-spot day from Appendix B Day 2 needs `ContentPool` + anomaly seeds wired to the calendar). Spec these out *before* implementing the fermentation rhythm in step 10.

### 12. Real mini-games — replace the form-style placeholders

**Highest current priority.** The form-style mini-games shipped 0.2.32–0.2.67 satisfy the `Outcome` math contract but are nothing like the four shapes from DESIGN.md 3.9 — they're radio buttons and checkboxes. Each form has a real-graphics commit pending. The Outcome contract stays unchanged across the swap; only the input affordance + visuals change.

**The "render pipeline" is Claude.** Per the `homebrewer_assets.md` memory: physical-scene art (kitchen, kettle, fermenter, faucet, water, foam, scorch, krausen) is built procedurally in Godot — `Polygon2D` + `Line2D` + `_draw()` overrides + `Tween` / `AnimationPlayer` + shaders. The kept POC files are reference: `scripts/lib/draw_helpers.gd`, `scripts/icons/procedural_*.gd`, `systems/palette.gd`, `systems/lighting.gd`, `scenes/components/post_process.tscn`, `shaders/post_process.gdshader`. Sprite PNGs under `assets/sprites/` are **icons only** — never use them for scene-scale art.

**Order to graphify** (one mini-game per commit; ship + playtest each before moving on):

1. **Fill Kettle** (skill: `process`, shape: skill challenge). Kitchen counter scene with stockpot + faucet (or jug placement). Tap faucet → water stream animation, kettle fills procedurally, water level rises with line marks if pitcher chosen. "Stop" commits actual_volume_gal; quality of stop timing → care factor. Deliverable: visible water in a visible kettle.
2. **Pour LME** (skill: `process` + `temp_control`, shape: procedure). Stove + kettle on burner. Drag stove dial OFF, drag spoon → kettle (autonomous stir loop kicks in), drag LME tin → kettle (controlled-pour gesture). The spoon stirring loop is the canonical single-touch demo per 3.9. SCORCH visual when player gets the order wrong (kettle darkens, smoke effect).
3. **Sanitize** (skill: `sanitation`, shape: job execution). Bucket fermenter on the counter. Drag sponge / sanitizer / drip-rack onto the bucket; visible state shifts (USED → SERVICEABLE → CLEAN → SANITIZED rendered as bucket cleanliness sheen).
4. **Cool Wort** (skill: `temp_control`, shape: decision + skill). Sink with kettle in ice OR fermenter top-off. Real-time temp gauge falls; stir gesture maintains circulation.
5. **Transfer + Pitch** (skill: `process` + `sanitation`, shape: skill). Drag-pour gesture from kettle to fermenter; pour smoothness scored. Yeast packet sprinkle gesture or rehydrate flow.
6. **Boil + Hops** (skill: `timing`, shape: mixed timing + decision). The most ambitious — real-time scene over ~30 compressed seconds. Heat dial + visible foam climb + hot break recognition tap + hop drops at scheduled prompts + boil-over response window + flameout. Hooks into TimeService.start_scene + event_pending.
7. **Bottling**. Priming sugar add → siphon flow → cap-by-cap visual.
8. **Pour & taste**. Glass pour visual, color/clarity check based on actuals, head retention from carbonation.

**Each mini-game commit ships:**
- The new scene with procedural art (no sprite assets).
- Replace the form scene in `MINIGAME_SCENES` registry (or in `dashboard.gd` for bottling/tasting).
- Tests for the visual scene's gesture → outcome path.
- A standalone screenshot capture in the harness.
- A `brewing_day_<stage>.png` composite if the stage lives in brewing-day.
- Changelog entry — player-visible.

**Scaffolding to land first** (one prep commit before mini-games start):
- A `kitchen_scene.gd` shared visual root that draws the apartment kitchen background (counter, stove, sink, shelf) procedurally. Each brewing-stage mini-game mounts equipment over this background.
- A small gesture-quality helper: smoothness + speed + arc scoring for drag inputs. Reusable across pour-style mini-games.
- A `palette.gd` audit — the kept palette is the source of truth for color choices.

## Open questions punted to playtest

These have placeholder numbers in DESIGN.md and the code; tune in playtest, don't lock in:

- Prestige skill penalty: 20% in 2.4. May need to be 10% or 30%.
- $30 starter capital + Marcus loan terms (2.6, 2.7) — exact numbers.
- Commitment consequence scale (4.7 — relationship_delta values in `CalendarSurface`).
- XP curve constants in `SkillXP.xp_to_next_for_level` (currently `100 + level² × 10`).
- `RiskProfile.is_critical` threshold (currently 7.0/10).
- Skill-level → grade-ceiling table in `Grader` (currently 0→C, 5→B, 10→A-, 15→A, 20→A+).
- `Drift` factors min/max bounds.

## Repo rules (don't break)

Per `CLAUDE.md`:

1. Always commit to `main`. No feature branches, no PRs.
2. Every player-visible commit updates `godot/data/changelog.json` in the same commit.
3. Run `scripts/dev-check.sh` before every commit.
4. Don't break versioning (`versionCode = git rev-list --count HEAD`, monotonic).
5. Don't break signing (keystore is irreplaceable).
6. Don't break the screenshot harness.

## Pushing to main

Local Claude on the user's physical PC pushes directly with `git push origin main`. No proxy / no MCP fallback needed in that environment. (Cloud / sandbox sessions may have a 403 proxy issue with `CCR_TEST_GITPROXY=1`; if you hit that, fall back to `mcp__github__push_files` per file.)

## Things a fresh Claude should NOT do

- Try to recover the proof-of-concept brew flow from before commit `f03e105`. It was intentionally removed because it didn't conform to the new contract; rebuild against Sections 7 + 8 instead.
- Add `BrewSession` or `Recipes` autoloads back. They're replaced by `GameState` + Resource files.
- Push to feature branches. Use `main` only.
- Touch the keystore or signing config without an explicit user instruction.
- Decide design questions that are deferred in DESIGN.md without asking the user. The design has been hard-fought; respect what's locked.
- Delete or "clean up" the four kept proof-of-concept files: `palette.gd`, `lighting.gd`, `scripts/icons/*`, `scripts/lib/draw_helpers.gd`, `scenes/components/post_process.tscn`, and the FCM/updater stack. These survived the architecture rebuild on purpose.

## When you finish reading this

Confirm to the user that you're up to speed, then continue on Step 12 (real mini-games). Steps 1–11 are either landed or deprioritized; the priority now is replacing form-style placeholders with real procedural-graphics + gesture mini-games per Step 12's order. Don't start writing new code until `dev-check.sh` is green.
