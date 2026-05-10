# Handoff — implementation pickup

This file is the current working state. Read this first, then [`DESIGN.md`](DESIGN.md), then [`CLAUDE.md`](CLAUDE.md), then continue.

## Status (2026-05-09, post-0.2.85)

The game has been **substantially rebuilt** since the original handoff. The form-style placeholders, brewing-day wizard wrapper, and dashboard landing page are all gone. Every brewing-day step is now a real interactive close-up scene. The home screen IS the apartment, with swipe-to-pan navigation across a 1620 px panorama and tap-to-act stations.

**What's playable now (end-to-end real interactions):**

- **Apartment as home view.** Pan left/right across one continuous panorama: front door (left) → bottling table (with shelf + journal + calendar) → kitchen counter (sink with brass gooseneck faucet, basin) → stove (with range hood) → bed under the bedroom window → closet (right). Real-world scale rule of 4 px = 1 inch is applied to every wall object.
- **Tap stations to act.** Tap the sink with the kettle in inventory → fill kettle close-up. Tap the stove → heat the kettle. Tap the bottling table → transfer + pitch. Tap the bed → advance the day. Tap the closet → check fermenter. Tap the journal on the wall shelf → journal scene. Tap the front door → (placeholder; deliveries / bar / festivals coming).
- **Inventory-driven station picker.** Tap a station with no active brew step → bottom-anchored modal lists items in your inventory that fit there.
- **Active-brews HUD.** Sidebar list on the left shows every brew in flight with name + stage. Tap a card → BrewDetails modal shows ingredient list (green / red), step list (sanitize → fill → heat → add LME → boil → cool → transfer/pitch → ferment → bottle → condition → taste) with checkmarks + care-factor scores per completed step.
- **Phone is the financial / settings surface.** Phone home shows bank balance in big gold type + bottle count. Apps grid: Messages, Shop, Settings. Settings holds the changelog scroll + Reset Save flow. (Forum, News, Calendar still placeholders.)
- **Real interactive mini-games for every brewing-day step:**
  - **Fill kettle** — cross-section close-up with cutaway side wall. Tap brass gooseneck faucet handle to toggle. Water enters the kettle with surface waves (sum-of-sines), splash particles at impact point, slosh decay after the tap shuts off. No target band — eyeball the level.
  - **Heat** — stove with kettle on burner (cross-section), round dial cycling OFF/LOW/MED/HIGH. Flame size scales with dial; steam rises as it heats; bubbles when boiling. Vertical thermometer with target band highlighted at 160-170°F. Hold-the-target meter at top fills as you stay in band. Scorch tracked above 200°F.
  - **Pour LME** — stove + kettle + spoon + LME tin as four hotspots. Tap dial → flame disappears. Tap spoon → kettle surface swirls. Tap LME tin → brown stream into kettle, tin empties, water turns wort-brown. Order matters (burner-off → stir → pour for ideal; wrong order = mild glob / scorch / catastrophic scorch).
  - **Boil with hops** — real-time 28 s compressed boil. Brown wort + bubbles + foam. Three hop bags glow at their drop windows (60/15/0 min); tap each in window → animated bag falls into kettle. Boil-over event mid-boil: foam climbs, BOIL OVER warning, tap dial to lower heat. Flameout at end: tap dial to OFF.
  - **Cool wort** — kettle in sink basin (cross-section). Tap faucet → cold water flows in basin + visible stream. Tap ice bags (3 available) → animated ice falls into kettle, instant temp drop. Press-and-hold spoon → stir, surface swirls, cooling rate boost. Thermometer drops from 210°F → 70°F target. Auto-resolves at target.
  - **Transfer + pitch** — kettle (left) + fermenter bucket (right) + auto-siphon arch + funnel + yeast packet. Tap funnel to sanitize. Tap siphon → wort drops in kettle, rises in fermenter, brown wort visible flowing through tube. Yeast packet glows when transfer done; tap to pitch (yeast cloud appears on wort surface).
- **Post-brew flow** still works (fermenting → bottling → conditioning → tasting → journal entry).
- **Save migration** backfills `equipment` + `journal` keys for pre-equipment careers.

**What's NOT real yet:**

- **Sanitize step** is auto-completed when you start a brew (default care factor 0.7) — there's no dedicated mini-game for it. The wipe-down step felt too thin to be its own scene; re-add later if it earns its place.
- **Front door** has a hotspot but tapping does nothing yet. Hooks for deliveries / going out to the bar / beer festivals (research) come later.
- **No Forum / News / Calendar phone apps.**
- **No commitments** (Marcus's party deadline, Mom's stout, etc.).
- **No inventory consumption** — one Shop trip carries arbitrarily many brews.
- **Only one recipe** (Apartment Pale Ale). West Coast IPA + Dry Stout per DESIGN.md 3.8 are unbuilt.
- **No anomalies / cleanliness state machine / equipment scheduling** (Step 11 in the original sequence — still parked).

## What changed since the original handoff (high-level)

| Was | Now |
|---|---|
| Dashboard with "Today" checklist + Get-some-rest button + start-brewing button + changelog scroll | Apartment IS the dashboard. Day chip + Phone icon on HUD; everything else on the phone or in-world. |
| Form-style mini-games (radio buttons, check toggles, "Confirm" CTA) | Real interactive close-ups for every brewing-day step. No wizard chrome. |
| Brewing-day scene mounts each mini-game inside a "Step N of 7" wrapper | Brewing-day wizard is gone. Each station tap mounts ONE mini-game directly; player drives advancement by tapping the next station. |
| Kettle tap → start brew → wizard runs through stages | Tap sink → picker → pick kettle → fill_kettle. After completion, return to apartment. Tap stove → heat. Etc. |
| One small panorama with stations as separate scenes | Single 1620 px panorama (closet / bottling / sink / stove / bed / window / front door). Swipe to pan across; clamp at edges. |
| HUD: title + day + cash + bottles + morning-summary + checklist + start-brewing + rest + journal + phone + dev-reset + changelog scroll | HUD: Day chip + Phone icon. That's it. |
| Phone: Messages + Shop only | Phone home shows bank balance prominently. Adds Settings app (changelog + reset save). |
| Journal accessed via HUD button | Journal is a physical green leather notebook on the wall shelf above the bottling table. Tap it. |
| Equipment hardcoded on the canvas (kettle always on counter) | Equipment is inventory-driven. Tap sink → station picker → choose what to put there from your inventory. |
| Faucet drawn as a wall-mounted bracket with no visible mount | Counter-mounted brass gooseneck: base flange + riser + arch + downturn-spout + side lever. |
| Cabinet faces drawn with generic 24" doors all the way across | Real sink-base double-door under the basin (knobs facing inward, below the basin recess); over-sink upper cabinet matches the lower double width; alternating-side knobs for adjacent doors. |
| Wall: empty | Wall clock between stove and window; wall calendar above bottling table (below the journal shelf); range hood above stove; baseboard along visible wall gaps. |

## Verification status

`scripts/dev-check.sh` exits clean (Godot 4.6.2 import + 133/133 GUT tests + 13 screenshot captures). Run on Windows via the `godot` shim in `~/bin`; the Linux/CI path wraps in Xvfb. Screenshots in `screenshots/` reflect current state of every scene that matters.

All sim tests for the brewing-day mini-games still pass — when the close-ups were rewritten, internal field contracts (`_heat`, `_selected_path`, `_option_toggles`, `_selected_pour`, `_selected_pitch`, etc.) were preserved so the unit tests that drive the controllers via private fields continue to work. The interactive UIs just drive those fields via taps now instead of radio buttons.

## File map (what lives where)

### Apartment + dashboard
- `godot/scripts/lib/apartment_2d.gd` — single-file panorama draw. Holds `STATION_X` array (closet, bottling table, sink, stove, decor/window, bed, front door), `PX_PER_INCH = 4`, helpers like `place_kettle_at_station()` and `journal_rect_world()` and `bed_rect_world()`. Every wall object's draw helper is in here.
- `godot/scenes/lib/apartment_2d.tscn` — wrapper. Auto-spawns the `Faucet2D` at the sink station.
- `godot/scenes/dashboard.tscn` + `godot/scripts/dashboard.gd` — the home view. Mounts the apartment, computes hit-test rects, owns the gesture / pan / tap routing, holds the active-brews HUD, dispatches station taps to mini-games.

### Equipment (procedural, not sprites)
- `godot/scripts/lib/equipment/kettle_2d.gd` — side-view stockpot with optional water level + target band.
- `godot/scripts/lib/equipment/faucet_2d.gd` — counter-mounted brass gooseneck with toggleable water stream.

### Brewing-day mini-games (real close-ups)
- `godot/scenes/minigames/fill_kettle.tscn` + `godot/scripts/minigames/fill_kettle/fill_kettle.gd`
- `godot/scenes/minigames/heat.tscn` + `godot/scripts/minigames/heat/heat.gd`
- `godot/scenes/minigames/add_lme.tscn` + `godot/scripts/minigames/add_lme/add_lme.gd`
- `godot/scenes/minigames/boil_with_hops.tscn` + `godot/scripts/minigames/boil_with_hops/boil_with_hops.gd`
- `godot/scenes/minigames/cool_wort.tscn` + `godot/scripts/minigames/cool_wort/cool_wort.gd`
- `godot/scenes/minigames/transfer_pitch.tscn` + `godot/scripts/minigames/transfer_pitch/transfer_pitch.gd`

Each scene has: `Background ColorRect` + `StageView Control` (custom `_draw`) + invisible `Button` hotspots at specific positions over visual elements + a `HiddenForLogic` `VBoxContainer` that retains the named nodes the existing `.gd` logic reads (`StageTitle`, `_path_radios`, etc.) so sim tests still work.

### Modals
- `godot/scenes/modals/station_picker.tscn` + `godot/scripts/modals/station_picker.gd` — bottom-anchored picker. Lists owned equipment compatible with a given station (driven by `EquipmentDefs`).
- `godot/scenes/modals/brew_details.tscn` + `godot/scripts/modals/brew_details.gd` — opened from the active-brews HUD. Shows ingredient have/missing + step list with care-factor scores.
- `godot/scenes/modals/check_fermenter.tscn` — existing closet check-in modal.

### Inventory
- `godot/scripts/lib/equipment_defs.gd` — `EquipmentDefs.DEFS` dict with `display`, `hint`, `stations` per item id (kettle_5gal, fermenter_bucket, bottling_bucket, bottle_capper, auto_siphon). `owned_at_station(station)` returns the items the player owns that fit there.
- `godot/systems/game_state.gd` — `_initial_inventory()` seeds equipment + journal alongside ingredients, bottles, consumables.
- `godot/systems/save_service.gd` — `_reseed_ingredients()` backfills `equipment` and `journal` keys for pre-equipment saves so existing careers see the new stuff.

### Phone
- `godot/scenes/phone/phone_overlay.tscn` + `godot/scripts/phone/phone_overlay.gd` — apps grid + home stats panel (big bank balance + bottle count).
- `godot/scenes/phone/settings_app.tscn` + `godot/scripts/phone/settings_app.gd` — changelog scroll + reset save flow + version label.
- `godot/scenes/phone/shop_app.tscn`, `messages_app.tscn`, `recipe_card.tscn` — existing.

### Existing infrastructure (untouched)
- `godot/systems/save_service.gd`, `time_service.gd`, `updater.gd`, `palette.gd`, `lighting.gd`, `changelog.gd`, `version.gd`.
- `godot/scripts/sim/` — `brew_state.gd`, `drift.gd`, `skill_xp.gd`, `grader.gd`, `care_factor.gd`, `risk_profile.gd`, `outcome.gd`, `time_service` etc. The math contract is unchanged.
- `godot/scenes/brewing_day.tscn` + `godot/scripts/brewing_day.gd` — **deprecated but not deleted**. Scene tests (`test_brewing_day_scaffold.gd`) still reference it; dashboard no longer mounts it.

## Build sequence — what's left

The original 1–11 build sequence is mostly landed or deprioritized. Step 12 (real mini-games) is **done for the apartment-pale-ale extract path**. What's open:

1. **Recipe-from-journal flow.** The user wants to tap the journal → see recipes → pick one → it starts a brew. Right now starting a brew goes through the sink picker. Wire the journal to be the recipe-selection surface.
2. **Sanitize as a real mini-game** (low priority — currently auto-completed).
3. **Front-door interactions.** Deliveries (UPS dropping ingredients), going out to the bar (research / relationships), beer festivals (research / inspiration). Picker with "going out?" options.
4. **Forum / News / Calendar phone apps** (Step 10 leftover). News drives the trends-and-opportunities flow per DESIGN.md.
5. **Inventory consumption.** Brewing should DEDUCT ingredients from inventory. Currently doesn't.
6. **More recipes.** West Coast IPA + Dry Stout per DESIGN.md 3.8.
7. **Anomalies + cleanliness state machine + equipment scheduling** (Step 11 in the original sequence — still parked).
8. **Bottling close-up rewrite.** Bottling still uses the older (somewhat wizardy) flow. Convert to a real close-up like the brewing-day steps.
9. **Tasting close-up.** Same — convert to a real glass-pour interaction.

## Open questions punted to playtest

These have placeholder numbers in DESIGN.md and the code; tune in playtest, don't lock in:

- Prestige skill penalty: 20% in 2.4. May need to be 10% or 30%.
- $30 starter capital + Marcus loan terms (2.6, 2.7) — exact numbers.
- Commitment consequence scale (4.7 — relationship_delta values in `CalendarSurface`).
- XP curve constants in `SkillXP.xp_to_next_for_level` (currently `100 + level² × 10`).
- `RiskProfile.is_critical` threshold (currently 7.0/10).
- Skill-level → grade-ceiling table in `Grader` (currently 0→C, 5→B, 10→A-, 15→A, 20→A+).
- `Drift` factors min/max bounds.
- Care factor for auto-completed sanitize (currently 0.7 — placeholder).

## Repo rules (don't break)

Per `CLAUDE.md`:

1. Always commit to `main`. No feature branches, no PRs.
2. Every player-visible commit updates `godot/data/changelog.json` in the same commit.
3. Run `scripts/dev-check.sh` before every commit.
4. Don't break versioning (`versionCode = git rev-list --count HEAD`, monotonic).
5. Don't break signing (keystore is irreplaceable).
6. Don't break the screenshot harness.

## Pushing to main

Local Claude on the user's physical PC pushes directly with `git push origin main`. No proxy / no MCP fallback needed.

## Things a fresh Claude should NOT do

- Reintroduce the brewing-day wizard wrapper. Each station tap mounts a single mini-game directly; the player drives advancement.
- Reintroduce form-style placeholder mini-games. Every brewing-day step is now a real close-up; if you add a new step, build a real interactive close-up for it.
- Add a HUD landing page or dashboard checklist back. The apartment IS the home screen.
- Push to feature branches. Use `main` only.
- Touch the keystore or signing config without an explicit user instruction.
- Decide design questions that are deferred in DESIGN.md without asking the user. The design has been hard-fought; respect what's locked.

## When you finish reading this

Confirm to the user that you're up to speed, then ask which of the open items they want next:

1. Recipe-from-journal flow
2. Front-door interactions (deliveries / bar / festivals)
3. Forum / News / Calendar phone apps
4. Inventory consumption
5. More recipes (West Coast IPA, Dry Stout)
6. Anomalies / cleanliness state machine
7. Bottling + tasting close-up rewrites

Don't start writing code until `scripts/dev-check.sh` is green.
