extends SceneTree

## Headless screenshot harness.
##
## Loads a list of scenes, advances each one N frames, captures the root
## viewport, and writes a PNG to user://screenshots/<name>.png.
##
## Usage (from repo root):
##   scripts/render_screenshots.sh
## (which wraps `godot --headless --script res://tools/screenshot_harness.gd`
## with Xvfb + opengl3 driver so we get real pixels in CI / on machines
## without a GPU.)

const SCENES := [
	{"name": "main", "path": "res://scenes/main.tscn", "frames": 5},
	{"name": "main_with_brew", "path": "res://scenes/main.tscn", "frames": 5,
		"synthetic_brew": {"stage": "fermenting", "days_elapsed_in_stage": 3}},
	{"name": "main_resume_brewing", "path": "res://scenes/main.tscn", "frames": 5,
		"synthetic_brew": {"stage": "brewing_day", "days_elapsed_in_stage": 0}},
	{"name": "main_ready_to_bottle", "path": "res://scenes/main.tscn", "frames": 5,
		"synthetic_brew": {"stage": "fermenting", "days_elapsed_in_stage": 5}},
	{"name": "main_ready_to_taste", "path": "res://scenes/main.tscn", "frames": 5,
		"synthetic_brew": {"stage": "bottled_conditioning", "days_elapsed_in_stage": 14}},
	{"name": "brewing_day", "path": "res://scenes/brewing_day.tscn", "frames": 5},
	{"name": "brewing_day_fill_kettle", "path": "res://scenes/brewing_day.tscn",
		"frames": 5, "props": {"initial_stage_index": 1}},
	{"name": "brewing_day_pour_lme", "path": "res://scenes/brewing_day.tscn",
		"frames": 5, "props": {"initial_stage_index": 3}},
	{"name": "fill_kettle", "path": "res://scenes/minigames/fill_kettle.tscn", "frames": 5},
	{"name": "pour_lme", "path": "res://scenes/minigames/pour_lme.tscn", "frames": 5},
	{"name": "sanitize", "path": "res://scenes/minigames/sanitize.tscn", "frames": 5},
	{"name": "cool_wort", "path": "res://scenes/minigames/cool_wort.tscn", "frames": 5},
	{"name": "boil_with_hops", "path": "res://scenes/minigames/boil_with_hops.tscn", "frames": 5},
	{"name": "transfer_pitch", "path": "res://scenes/minigames/transfer_pitch.tscn", "frames": 5},
	{"name": "bottling", "path": "res://scenes/minigames/bottling.tscn", "frames": 5},
	{"name": "tasting", "path": "res://scenes/minigames/tasting.tscn", "frames": 5,
		"tasting_synthetic_brew": true},
	{"name": "journal_empty", "path": "res://scenes/journal.tscn", "frames": 5,
		"journal_wipe": true},
	{"name": "journal_populated", "path": "res://scenes/journal.tscn", "frames": 5,
		"journal_synthetic_entries": true},
	{"name": "phone_overlay_grid", "path": "res://scenes/phone/phone_overlay.tscn", "frames": 5},
	{"name": "messages_app", "path": "res://scenes/phone/messages_app.tscn", "frames": 5},
	{"name": "shop_app", "path": "res://scenes/phone/shop_app.tscn", "frames": 5},
	{"name": "recipe_card", "path": "res://scenes/phone/recipe_card.tscn", "frames": 5,
		"props": {"recipe_id": "apartment_pale_ale"}},
	{"name": "check_fermenter_modal", "path": "res://scenes/modals/check_fermenter.tscn",
		"frames": 5, "synthetic_brew": {"stage": "fermenting", "days_elapsed_in_stage": 3},
		"props": {"brew_id": "synthetic_1"}},
	{"name": "check_fermenter_modal_ready", "path": "res://scenes/modals/check_fermenter.tscn",
		"frames": 5, "synthetic_brew": {"stage": "fermenting", "days_elapsed_in_stage": 5},
		"props": {"brew_id": "synthetic_1"}},
]

const OUT_DIR := "res://../screenshots"
const VIEWPORT_SIZE := Vector2i(540, 960)

func _initialize() -> void:
	# Wipe any disk state from previous test runs / captures BEFORE
	# autoloads bootstrap. Otherwise SaveService.load_now adopts a stale
	# save.json (often left by GUT tests writing during their assertions)
	# and the first scene captured renders against that leaked state
	# instead of a fresh career.
	_wipe_disk_state()

	# `--script` mode bypasses ProjectSettings autoload loading. Re-add the
	# autoloads we depend on so scripts that reference them globally don't
	# crash. Order matters when one autoload depends on another.
	_bootstrap_autoloads()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for spec in SCENES:
		await _capture(spec)
	# Clean up again at the end so a real game launch after dev-check
	# doesn't see synthetic state.
	_wipe_disk_state()
	quit()

func _wipe_disk_state() -> void:
	for path in ["user://save.json", "user://save.json.tmp", "user://journal.jsonl"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _inject_synthetic_brew(spec: Dictionary) -> void:
	# Make sure GameState is reset to a fresh career so the recipe knowledge
	# + equipment seeds are present, then push a synthetic brew with the
	# requested stage / elapsed values.
	var GameStateNode = root.get_node_or_null("GameState")
	if GameStateNode == null:
		return
	GameStateNode.reset_to_new_career()
	var brew := {
		"brew_id": "synthetic_1",
		"recipe_id": "apartment_pale_ale",
		"recipe_snapshot": load("res://data/recipes/apartment_pale_ale.tres").to_snapshot(),
		"stage": String(spec.get("stage", "fermenting")),
		"stage_started_day": 0,
		"days_elapsed_in_stage": int(spec.get("days_elapsed_in_stage", 0)),
		"outcomes": {},
		"risk_profile": {},
		"equipment_used": [],
		"anomalies": [],
		"rng_state": 1,
	}
	GameStateNode.data["brews_in_flight"].append(brew)

func _wipe_journal() -> void:
	if FileAccess.file_exists("user://journal.jsonl"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://journal.jsonl"))

func _inject_synthetic_journal_entries() -> void:
	# Write a few brew_completed entries directly to user://journal.jsonl
	# via SaveService.append_journal_entry so the journal scene reads them
	# the way it would in real gameplay.
	_wipe_journal()
	var SaveServiceNode = root.get_node_or_null("SaveService")
	if SaveServiceNode == null:
		return
	var entries := [
		{
			"type": "brew_completed",
			"day_completed": 24,
			"brew_id": "demo_1",
			"recipe_id": "apartment_pale_ale",
			"recipe_display_name": "Apartment Pale Ale",
			"actuals": {"og": 1.045, "fg": 1.012, "ibu": 30.0, "abv": 4.3, "carbonation": 1.0},
			"self_grade": "A",
			"external_grade": "A-",
			"outcomes": {},
			"risk_profile": {},
		},
		{
			"type": "brew_completed",
			"day_completed": 49,
			"brew_id": "demo_2",
			"recipe_id": "apartment_pale_ale",
			"recipe_display_name": "Apartment Pale Ale",
			"actuals": {"og": 1.041, "fg": 1.012, "ibu": 26.0, "abv": 3.8, "carbonation": 0.85},
			"self_grade": "B",
			"external_grade": "C",
			"outcomes": {},
			"risk_profile": {},
		},
		{
			"type": "brew_completed",
			"day_completed": 75,
			"brew_id": "demo_3",
			"recipe_id": "apartment_pale_ale",
			"recipe_display_name": "Apartment Pale Ale",
			"actuals": {"og": 1.038, "fg": 1.014, "ibu": 22.0, "abv": 3.2, "carbonation": 0.0},
			"self_grade": "D",
			"external_grade": "F",
			"outcomes": {},
			"risk_profile": {},
		},
	]
	for e in entries:
		SaveServiceNode.append_journal_entry(e)

func _inject_completed_brew_for_tasting() -> String:
	# A fully-played-out APA brew with ideal outcomes so tasting renders
	# meaningful targets/actuals/grades. Skill snapshots are at level 25
	# so the grade ceiling doesn't drag the visible grade down to C.
	var GameStateNode = root.get_node_or_null("GameState")
	if GameStateNode == null:
		return ""
	GameStateNode.reset_to_new_career()
	var skills: Dictionary = GameStateNode.data["skills"]
	for axis in ["sanitation", "process", "timing", "temp_control"]:
		skills[axis]["level"] = 25
	var snap := SkillXP.snapshot(skills)
	var recipe = load("res://data/recipes/apartment_pale_ale.tres")
	var b := {
		"brew_id": "synthetic_taste_1",
		"recipe_id": "apartment_pale_ale",
		"recipe_snapshot": recipe.to_snapshot(),
		"stage": "bottled_conditioning",
		"stage_started_day": 0,
		"days_elapsed_in_stage": 14,
		"outcomes": {
			"sanitize":       {"actual": {}, "care_factor": 1.0, "risk_deltas": {},
				"xp_gained": {}, "journal_notes": [], "skill_snapshot": snap},
			"fill_kettle":    {"actual": {"water_volume_gal": 2.5, "water_source": "tap",
				"method": "pitcher"}, "care_factor": 1.0, "risk_deltas": {},
				"xp_gained": {}, "journal_notes": [], "skill_snapshot": snap},
			"add_lme":        {"actual": {"sequence": ["burner_off", "stir", "lme_pour"],
				"result": "IDEAL", "lme_dissolution": 1.0}, "care_factor": 1.0,
				"risk_deltas": {}, "xp_gained": {}, "journal_notes": [], "skill_snapshot": snap},
			"boil_with_hops": {"actual": {"ibu_factor": 1.0, "volume_loss_gal": 0.0},
				"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
				"journal_notes": [], "skill_snapshot": snap},
			"cool_wort":      {"actual": {"path": "ice_bath", "final_temp_f": 70.0},
				"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
				"journal_notes": [], "skill_snapshot": snap},
			"transfer_pitch": {"actual": {"pour_quality": "gentle", "pitch_method": "rehydrate"},
				"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
				"journal_notes": [], "skill_snapshot": snap},
			"bottle":         {"actual": {"priming_method": "bulk", "fill_method": "funnel",
				"carbonation_factor": 1.0}, "care_factor": 1.0, "risk_deltas": {},
				"xp_gained": {}, "journal_notes": [], "skill_snapshot": snap},
		},
		"risk_profile": {},
		"equipment_used": [],
		"anomalies": [],
		"rng_state": 1,
	}
	GameStateNode.data["brews_in_flight"].append(b)
	GameStateNode.data["inventory"]["bottles"] = {"available": 0, "in_use": 24}
	return b["brew_id"]

func _bootstrap_autoloads() -> void:
	var autoloads := [
		["Palette", "res://systems/palette.gd"],
		["Lighting", "res://systems/lighting.gd"],
		["Changelog", "res://systems/changelog.gd"],
		["Version", "res://systems/version.gd"],
		["Updater", "res://systems/updater.gd"],
		["TimeService", "res://systems/time_service.gd"],
		["GameState", "res://systems/game_state.gd"],
		["SaveService", "res://systems/save_service.gd"],
	]
	for entry in autoloads:
		var alias_name: String = entry[0]
		var path: String = entry[1]
		if root.has_node(alias_name):
			continue
		var script: Script = load(path)
		var instance: Node = script.new()
		instance.name = alias_name
		root.add_child(instance)

func _capture(spec: Dictionary) -> void:
	var scene_name: String = spec.get("name", "unnamed")
	var path: String = spec.get("path", "")
	var frames: int = int(spec.get("frames", 3))

	var packed := load(path)
	if packed == null:
		push_error("Could not load scene: %s" % path)
		return

	# Reset GameState to a fresh career before each capture so state from
	# the previous scene doesn't bleed in. The synthetic-brew injectors
	# call reset themselves; doing it here unconditionally is the simpler
	# invariant.
	var GameStateNode = root.get_node_or_null("GameState")
	if GameStateNode != null:
		GameStateNode.reset_to_new_career()

	# Pre-mount: optionally inject a synthetic brew into GameState so the
	# dashboard "Brews in flight" section has something to render.
	var synthetic: Dictionary = spec.get("synthetic_brew", {})
	if not synthetic.is_empty():
		_inject_synthetic_brew(synthetic)
	var injected_brew_id := ""
	if bool(spec.get("tasting_synthetic_brew", false)):
		injected_brew_id = _inject_completed_brew_for_tasting()
	if bool(spec.get("journal_wipe", false)):
		_wipe_journal()
	if bool(spec.get("journal_synthetic_entries", false)):
		_inject_synthetic_journal_entries()

	var instance: Node = packed.instantiate()
	# Apply pre-_ready props so the scene wakes up with the harness's setup.
	var props: Dictionary = spec.get("props", {})
	for k in props:
		instance.set(String(k), props[k])
	if injected_brew_id != "":
		instance.set("brew_id", injected_brew_id)
	root.add_child(instance)
	root.content_scale_size = VIEWPORT_SIZE

	# Wait one frame for _ready() so @onready vars resolve before we poke at state.
	await process_frame

	for _i in frames:
		await process_frame

	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("get_image() returned null for %s" % scene_name)
		instance.queue_free()
		return

	var out_path := "%s/%s.png" % [OUT_DIR, scene_name]
	var globalized := ProjectSettings.globalize_path(out_path)
	var err := image.save_png(globalized)
	if err != OK:
		push_error("save_png failed for %s: %s" % [scene_name, err])
	else:
		print("[harness] wrote %s" % globalized)

	instance.queue_free()
