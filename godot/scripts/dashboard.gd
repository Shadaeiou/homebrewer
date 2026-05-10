extends Control

## Dashboard — the apartment IS the home screen. The kitchen panorama
## fills the viewport; the player swipes left/right to pan across the
## room and taps interactive stations to act on the world.
##
## Tappable stations (per Apartment2D layout):
##   sink (kettle)         — start brewing / resume brewing
##   stove                  — TBD: place kettle, light burner (graphify next)
##   bottling table         — TBD: bottling flow when conditioning ready
##   closet                  — check fermenter / conditioning rack
##   window/decor           — flavor: weather / mood line
##
## Input model:
##   Press → record start
##   Drag (>8px horizontal) → pan camera, suppress tap on release
##   Release without drag → hit-test against station rects, fire action
## This sits on the viewport so child Buttons (the faucet handle, etc.)
## still receive their taps when the dashboard's camera mode is off
## (e.g. inside the brewing-day scene). Dashboard owns the gesture.

const APARTMENT_SCENE := preload("res://scenes/lib/apartment_2d.tscn")
const BOTTLING_SCENE         := preload("res://scenes/minigames/bottling.tscn")
const TASTING_SCENE          := preload("res://scenes/minigames/tasting.tscn")
const JOURNAL_SCENE          := preload("res://scenes/journal.tscn")
const PHONE_OVERLAY_SCENE    := preload("res://scenes/phone/phone_overlay.tscn")
const CHECK_FERMENTER_MODAL  := preload("res://scenes/modals/check_fermenter.tscn")
const STATION_PICKER_MODAL   := preload("res://scenes/modals/station_picker.tscn")
const BREW_DETAILS_MODAL     := preload("res://scenes/modals/brew_details.tscn")

## Mini-game scene per brewing-day step. Tapping a station mounts ONE
## of these directly — there is no wizard / step-by-step wrapper. Each
## scene emits minigame_completed(outcome) when done; the dashboard
## records the outcome on the active brew, advances its step, and
## returns to the apartment view. The player drives advancement by
## tapping the next station themselves.
const MINIGAME_SCENES: Dictionary = {
	"sanitize":       preload("res://scenes/minigames/sanitize.tscn"),
	"fill_kettle":    preload("res://scenes/minigames/fill_kettle.tscn"),
	"heat":           preload("res://scenes/minigames/heat.tscn"),
	"add_lme":        preload("res://scenes/minigames/add_lme.tscn"),
	"boil_with_hops": preload("res://scenes/minigames/boil_with_hops.tscn"),
	"cool_wort":      preload("res://scenes/minigames/cool_wort.tscn"),
	"transfer_pitch": preload("res://scenes/minigames/transfer_pitch.tscn"),
}

## Which station is responsible for which brewing-day step.
const STATION_STEPS: Dictionary = {
	Apartment2D.STATION_SINK: ["sanitize", "fill_kettle", "cool_wort"],
	Apartment2D.STATION_STOVE: ["heat", "add_lme", "boil_with_hops"],
	Apartment2D.STATION_BOTTLING_TABLE: ["transfer_pitch"],
}

## Brewing-day step list (extract method). The brew advances through
## these in order; current step = first one without an outcome on the
## brew dict.
const EXTRACT_STEPS: Array = [
	"sanitize", "fill_kettle", "heat", "add_lme",
	"boil_with_hops", "cool_wort", "transfer_pitch",
]

## Pseudo-station-ID used internally by the journal hotspot. Negative so
## it can't collide with a real Apartment2D station enum value.
const JOURNAL_STATION_ID: int = -100

const PAN_THRESHOLD: float = 8.0  # Pixels of motion before we treat the press as a pan, not a tap.

@onready var _viewport: Control = %ApartmentViewport
@onready var _day_label: Label = %DayLabel
@onready var _brew_list: VBoxContainer = %BrewList
@onready var _phone_button: Button = %PhoneButton
@onready var _version_label: Label = %VersionLabel
@onready var _update_banner: PanelContainer = %UpdateBanner
@onready var _update_label: Label = %UpdateLabel
@onready var _update_button: Button = %UpdateButton
@onready var _reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog

var _apartment: Apartment2D = null
var _kettle: Kettle2D = null

# Hit-test rects in apartment-LOCAL coords. Computed once after mount.
var _station_rects: Dictionary = {}  # int -> Rect2

# Pan state
var _pressed: bool = false
var _press_start: Vector2 = Vector2.ZERO
var _press_apt_x: float = 0.0
var _did_pan: bool = false

func _ready() -> void:
	_version_label.text = Version.full()
	_phone_button.pressed.connect(_on_phone_pressed)
	_reset_confirm_dialog.confirmed.connect(func(): SaveService.wipe_and_reset())
	_update_button.pressed.connect(Updater.install_update)
	Updater.update_available.connect(_on_update_available)
	GameState.state_loaded.connect(_render_state)
	GameState.day_advanced.connect(func(_d): _render_state())
	# The viewport captures all gestures (pan + tap routing). Faucet etc.
	# are inside the apartment but the dashboard's home view doesn't
	# consume their interactivity — every world tap routes through us.
	_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.gui_input.connect(_on_viewport_gui_input)
	_viewport.resized.connect(_recenter)
	_mount_apartment()
	_render_state()

func _mount_apartment() -> void:
	_apartment = APARTMENT_SCENE.instantiate()
	_viewport.add_child(_apartment)
	await get_tree().process_frame
	_recenter()
	# Home view shows the empty room — no equipment auto-placed. Tap a
	# station to bring its inventory item into view (kettle into the
	# basin, fermenter into the closet, etc.). Equipment placement is
	# inventory-driven, not built into the room.
	_compute_station_rects()

func _compute_station_rects() -> void:
	# Roughly the visible silhouette of each interactive object/area in
	# apartment-local coordinates. Tuned to be generous (mobile fingers).
	var sink: Vector2 = _apartment.station_anchor(Apartment2D.STATION_SINK)
	var stove: Vector2 = _apartment.station_anchor(Apartment2D.STATION_STOVE)
	var closet: Vector2 = _apartment.station_anchor(Apartment2D.STATION_CLOSET)
	var bottling: Vector2 = _apartment.station_anchor(Apartment2D.STATION_BOTTLING_TABLE)
	# Sink/kettle area: covers basin + faucet + kettle rest spot.
	_station_rects[Apartment2D.STATION_SINK] = Rect2(
		sink.x - 50, sink.y - 110, 160, 130,
	)
	# Stove (range): 30"w × 36"h footprint + a bit above for the hood.
	_station_rects[Apartment2D.STATION_STOVE] = Rect2(
		stove.x - 60, stove.y - 30, 120, 144,
	)
	# Closet door: 30"w × 80"h.
	_station_rects[Apartment2D.STATION_CLOSET] = Rect2(
		closet.x - 60, closet.y - 280, 120, 320,
	)
	# Bottling table: 60"w × 30"h.
	_station_rects[Apartment2D.STATION_BOTTLING_TABLE] = Rect2(
		bottling.x - 120, bottling.y - 80, 240, 160,
	)
	# Bed footprint (mattress + frame + headboard tower).
	_station_rects[Apartment2D.STATION_BED] = _apartment.bed_rect_world().grow(8.0)
	# Front door (way out of the apartment).
	var fd: Vector2 = _apartment.station_anchor(Apartment2D.STATION_FRONT_DOOR)
	_station_rects[Apartment2D.STATION_FRONT_DOOR] = Rect2(
		fd.x - 70, fd.y - 320, 140, 340,
	)
	# Journal sits on a wall shelf above the bottling table — its own
	# hotspot, takes priority over the bottling-table hotspot.
	var jr: Rect2 = _apartment.journal_rect_world()
	_station_rects[JOURNAL_STATION_ID] = jr.grow(10.0)

# ---- Camera placement & pan ----

func _x_bounds() -> Vector2:
	# Returns (x_min, x_max) for apartment.position.x.
	var vp_w: float = _viewport.size.x
	if vp_w >= Apartment2D.PANORAMA_W:
		# Center it; no panning room.
		var x: float = (vp_w - Apartment2D.PANORAMA_W) * 0.5
		return Vector2(x, x)
	return Vector2(vp_w - Apartment2D.PANORAMA_W, 0.0)

func _recenter() -> void:
	if _apartment == null:
		return
	var vp: Vector2 = _viewport.size
	# Default to sink station centered (kettle is the v1 focal point).
	var preferred: Vector2 = _apartment.camera_offset_for(Apartment2D.STATION_SINK, vp.x)
	var bounds: Vector2 = _x_bounds()
	preferred.x = clampf(preferred.x, bounds.x, bounds.y)
	preferred.y = (vp.y - Apartment2D.PANORAMA_H) * 0.5
	_apartment.position = preferred

func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressed = true
			_press_start = mb.position
			_press_apt_x = _apartment.position.x
			_did_pan = false
		else:
			if _pressed and not _did_pan:
				_handle_tap(mb.position)
			_pressed = false
			_did_pan = false
	elif event is InputEventMouseMotion:
		if not _pressed:
			return
		var mm: InputEventMouseMotion = event
		var dx: float = mm.position.x - _press_start.x
		if not _did_pan and absf(dx) > PAN_THRESHOLD:
			_did_pan = true
		if _did_pan:
			var bounds: Vector2 = _x_bounds()
			var new_x: float = clampf(_press_apt_x + dx, bounds.x, bounds.y)
			_apartment.position.x = new_x

func _handle_tap(viewport_pos: Vector2) -> void:
	# Convert viewport coord to apartment-local coord, hit-test stations.
	# Check the journal first since it overlaps the bottling-table rect.
	var local: Vector2 = viewport_pos - _apartment.position
	if _station_rects.has(JOURNAL_STATION_ID) and _station_rects[JOURNAL_STATION_ID].has_point(local):
		_on_journal_tapped()
		return
	for station in _station_rects.keys():
		if int(station) == JOURNAL_STATION_ID:
			continue
		var rect: Rect2 = _station_rects[station]
		if rect.has_point(local):
			_on_station_tapped(int(station))
			return

func _on_station_tapped(station: int) -> void:
	match station:
		Apartment2D.STATION_SINK:
			_on_sink_tapped()
		Apartment2D.STATION_CLOSET:
			_on_closet_tapped()
		Apartment2D.STATION_STOVE:
			_on_stove_tapped()
		Apartment2D.STATION_BOTTLING_TABLE:
			_on_bottling_table_tapped()
		Apartment2D.STATION_BED:
			_on_bed_tapped()
		Apartment2D.STATION_FRONT_DOOR:
			_on_front_door_tapped()

# ---- Per-station behavior ----

func _on_sink_tapped() -> void:
	_handle_station_tap(Apartment2D.STATION_SINK)

func _handle_station_tap(station: int) -> void:
	# 1. If there's an active brew in BREWING_DAY, find its current step.
	# 2. If that step belongs to this station, mount the mini-game directly.
	# 3. Otherwise (no brew, or this isn't the step's station), open the
	#    inventory picker so the player chooses what to do here.
	var brew: Dictionary = _find_brew_in_stage(BrewState.STAGE_BREWING_DAY)
	if not brew.is_empty():
		var step_id: String = _current_brew_step(brew)
		if step_id != "" and step_id in STATION_STEPS.get(station, []):
			_mount_minigame_for_step(brew, step_id)
			return
		# This station isn't where the next step happens — silent ignore.
		return
	# No active brew. Sink is the only station that can START a brew
	# (player picks the empty kettle to fill it). Other stations are
	# silent until a brew is in flight.
	if station != Apartment2D.STATION_SINK:
		return
	_open_picker_for(station, "What goes in the sink?", _on_sink_item_picked)

func _on_sink_item_picked(equipment_id: String) -> void:
	# The picker shows archetype IDs (per DESIGN.md §8.6's equipment schema).
	# A starter career owns the apartment_stockpot kettle; tapping it kicks
	# off a fresh brew. Future kettles (marked_brew_kettle, stainless, ...)
	# enter the same flow once they're added as picker-eligible archetypes.
	#
	# Recipe selection is intentionally a sink-tap shortcut for v1 (one
	# recipe known by default). Once HANDOFF #1 lands (recipe-from-journal
	# flow), the journal becomes the recipe-selection surface and the
	# sink stops auto-picking — it just opens the kettle.
	if equipment_id != "apartment_stockpot":
		return
	var recipe_id: String = _first_known_recipe_id()
	if recipe_id == "":
		return
	var issues: Array = GameState.start_brewing_issues(recipe_id)
	if issues.is_empty():
		_start_new_brew_and_open_first_step(recipe_id)

func _first_known_recipe_id() -> String:
	# Returns the first unlocked recipe in the player's collection (insertion
	# order, which mirrors STARTER_RECIPE_PATHS for the starter set). Empty
	# string if the player owns no recipes — the sink just no-ops then.
	var known: Dictionary = GameState.data.get("recipe_knowledge", {}).get("known", {})
	for recipe_id in known:
		return String(recipe_id)
	return ""

func _current_brew_step(brew: Dictionary) -> String:
	# Returns the first brewing-day step that hasn't been completed.
	var outcomes: Dictionary = brew.get("outcomes", {})
	for step_id in EXTRACT_STEPS:
		if not outcomes.has(step_id):
			return step_id
	return ""

func _mount_minigame_for_step(brew: Dictionary, step_id: String) -> void:
	var scene: PackedScene = MINIGAME_SCENES.get(step_id)
	if scene == null:
		return  # Step not implemented yet — silent ignore.
	var brew_id: String = String(brew.get("brew_id", ""))
	var main := get_tree().root.get_node_or_null("Main")
	if main == null or not main.has_method("mount_active_scene"):
		return
	main.mount_active_scene(scene, func(inst):
		var stage_meta: Dictionary = {"id": step_id, "title": step_id}
		if inst.has_method("set_stage_meta"):
			inst.set_stage_meta(stage_meta)
		if inst.has_signal("minigame_completed"):
			inst.minigame_completed.connect(
				func(outcome): _on_minigame_completed(brew_id, step_id, outcome),
			)
	)

func _on_minigame_completed(brew_id: String, step_id: String, outcome: Dictionary) -> void:
	# Record the outcome on the active brew and advance its step. Return
	# to the apartment view — the player chooses the next station.
	var brews: Array = GameState.data.get("brews_in_flight", [])
	for i in range(brews.size()):
		if String(brews[i].get("brew_id", "")) == brew_id:
			brews[i] = BrewState.record_outcome(brews[i], step_id, outcome)
			# If all brewing-day steps are done, advance brew to FERMENTING.
			if _all_brewing_day_steps_done(brews[i]):
				brews[i] = BrewState.advance_stage(
					brews[i], BrewState.STAGE_FERMENTING, TimeService.day_clock,
				)
			break
	GameState.notify_state_loaded()
	SaveService.flush_now()
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("clear_active_scene"):
		main.clear_active_scene()

func _all_brewing_day_steps_done(brew: Dictionary) -> bool:
	var outcomes: Dictionary = brew.get("outcomes", {})
	for step_id in EXTRACT_STEPS:
		if not outcomes.has(step_id):
			return false
	return true

func _start_new_brew_and_open_first_step(recipe_id: String) -> void:
	var recipe: RecipeDef = load("res://data/recipes/%s.tres" % recipe_id)
	if recipe == null:
		return
	var brew_id: String = GameState.make_brew_id()
	var seed: int = int(GameState.data.get("rng_state", {}).get("next_brew_seed", 0))
	var brew := BrewState.make_new(
		brew_id, recipe_id, recipe.to_snapshot(),
		TimeService.day_clock, seed,
	)
	GameState.data["brews_in_flight"].append(brew)
	GameState.data["rng_state"]["next_brew_seed"] = randi()
	# The brew's first step is "sanitize" — but for now we let the player
	# go straight to fill_kettle since they tapped the sink with a kettle.
	# Auto-complete sanitize with a default outcome so the brew proceeds.
	var sanitize_outcome: Dictionary = {
		"actual": {},
		"care_factor": 0.7,
		"risk_deltas": {},
		"xp_gained": {},
		"journal_notes": ["Wiped down the gear before pulling out the kettle."],
		"skill_snapshot": SkillXP.snapshot(GameState.data.get("skills", {})),
	}
	brew = BrewState.record_outcome(brew, "sanitize", sanitize_outcome)
	# Replace the brew in the array.
	for i in range(GameState.data["brews_in_flight"].size()):
		if String(GameState.data["brews_in_flight"][i].get("brew_id", "")) == brew_id:
			GameState.data["brews_in_flight"][i] = brew
			break
	# Mount fill_kettle directly.
	_mount_minigame_for_step(brew, "fill_kettle")

func _open_picker_for(station: int, title: String, on_picked: Callable) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null or not main.has_method("push_modal"):
		return
	main.push_modal(STATION_PICKER_MODAL, func(inst):
		inst.station = station
		inst.title_text = title
		inst.item_picked.connect(on_picked))

func _on_closet_tapped() -> void:
	var brew: Dictionary = _find_brew_in_stage(BrewState.STAGE_FERMENTING)
	if brew.is_empty():
		brew = _find_brew_in_stage(BrewState.STAGE_BOTTLED_CONDITIONING)
	if brew.is_empty():
		return  # Nothing in the closet — silent ignore.
	var brew_id: String = String(brew.get("brew_id", ""))
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_modal"):
		main.push_modal(CHECK_FERMENTER_MODAL, func(inst): inst.brew_id = brew_id)

func _on_stove_tapped() -> void:
	_handle_station_tap(Apartment2D.STATION_STOVE)

func _on_front_door_tapped() -> void:
	# v1: nothing to do outside yet. Once we wire deliveries / the bar /
	# beer festivals, this opens the "going out?" picker. For now, silent.
	pass

func _on_journal_tapped() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(JOURNAL_SCENE)

func _on_bed_tapped() -> void:
	# Lying down advances the day clock. Same effect as the HUD Rest
	# button, but the player acts on the world instead of a chrome
	# button.
	TimeService.advance_day()

func _on_bottling_table_tapped() -> void:
	_handle_station_tap(Apartment2D.STATION_BOTTLING_TABLE)

# ---- HUD render ----

func _render_state() -> void:
	if GameState.data.is_empty():
		_day_label.text = "Day 0"
		return
	_day_label.text = "Day %d" % TimeService.day_clock
	_render_brew_list()

func _render_brew_list() -> void:
	for child in _brew_list.get_children():
		child.queue_free()
	var brews: Array = GameState.data.get("brews_in_flight", [])
	if brews.is_empty():
		return
	for brew in brews:
		_brew_list.add_child(_make_brew_card(brew))

func _make_brew_card(brew: Dictionary) -> Control:
	var snap: Dictionary = brew.get("recipe_snapshot", {})
	var name: String = String(snap.get("display_name", brew.get("recipe_id", "Brew")))
	var stage: String = String(brew.get("stage", ""))
	var elapsed: int = int(brew.get("days_elapsed_in_stage", 0))
	var card := Button.new()
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.custom_minimum_size = Vector2(0, 44)
	card.add_theme_font_size_override("font_size", 12)
	var stage_blurb: String = stage
	match stage:
		BrewState.STAGE_BREWING_DAY:
			stage_blurb = "Brew day"
		BrewState.STAGE_FERMENTING:
			var ferm: int = int(snap.get("fermentation_days", 5))
			stage_blurb = "Fermenting %d/%d" % [elapsed, ferm]
		BrewState.STAGE_BOTTLED_CONDITIONING:
			var cond: int = int(snap.get("condition_days", 14))
			stage_blurb = "Conditioning %d/%d" % [elapsed, cond]
	card.text = "%s\n%s" % [name, stage_blurb]
	var brew_id: String = String(brew.get("brew_id", ""))
	card.pressed.connect(func(): _on_brew_card_tapped(brew_id))
	return card

func _on_brew_card_tapped(brew_id: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_modal"):
		main.push_modal(BREW_DETAILS_MODAL, func(inst): inst.brew_id = brew_id)

func _find_brew_in_stage(stage: String) -> Dictionary:
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == stage:
			return b
	return {}

func _brew_name(brew: Dictionary) -> String:
	var snap: Dictionary = brew.get("recipe_snapshot", {})
	return String(snap.get("display_name", brew.get("recipe_id", "Brew")))

# ---- HUD button handlers ----

func _on_phone_pressed() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_phone"):
		main.push_phone(PHONE_OVERLAY_SCENE)

func _on_update_available(latest_name: String, latest_code: int, _release_url: String) -> void:
	_update_label.text = "Update available: v%s (build %d)" % [latest_name, latest_code]
	_update_banner.visible = true
