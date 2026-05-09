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
const BREWING_DAY_SCENE     := preload("res://scenes/brewing_day.tscn")
const BOTTLING_SCENE         := preload("res://scenes/minigames/bottling.tscn")
const TASTING_SCENE          := preload("res://scenes/minigames/tasting.tscn")
const JOURNAL_SCENE          := preload("res://scenes/journal.tscn")
const PHONE_OVERLAY_SCENE    := preload("res://scenes/phone/phone_overlay.tscn")
const CHECK_FERMENTER_MODAL  := preload("res://scenes/modals/check_fermenter.tscn")
const STATION_PICKER_MODAL   := preload("res://scenes/modals/station_picker.tscn")

## Pseudo-station-ID used internally by the journal hotspot. Negative so
## it can't collide with a real Apartment2D station enum value.
const JOURNAL_STATION_ID: int = -100

const STARTER_RECIPE_ID := "apartment_pale_ale"
const PAN_THRESHOLD: float = 8.0  # Pixels of motion before we treat the press as a pan, not a tap.

@onready var _viewport: Control = %ApartmentViewport
@onready var _day_label: Label = %DayLabel
@onready var _money_row: Label = %MoneyRow
@onready var _morning_summary: Label = %MorningSummary
@onready var _action_prompt: Label = %ActionPrompt
@onready var _phone_button: Button = %PhoneButton
@onready var _rest_button: Button = %RestButton
@onready var _version_label: Label = %VersionLabel
@onready var _update_banner: PanelContainer = %UpdateBanner
@onready var _update_label: Label = %UpdateLabel
@onready var _update_button: Button = %UpdateButton
@onready var _dev_reset_button: Button = %DevResetButton
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
	_rest_button.pressed.connect(_on_rest_pressed)
	_dev_reset_button.pressed.connect(func(): _reset_confirm_dialog.popup_centered())
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
	# Journal sits on the bottling table — its own hotspot, takes
	# priority over the bottling-table hotspot since it overlaps.
	var jr: Rect2 = _apartment.journal_rect_world()
	_station_rects[JOURNAL_STATION_ID] = jr.grow(8.0)

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

# ---- Per-station behavior ----

func _on_sink_tapped() -> void:
	# Resume an in-flight brew without prompting — that's the natural
	# direct continuation. Otherwise open the inventory picker so the
	# player chooses what to put in the basin.
	var resumable: Dictionary = _find_brew_in_stage(BrewState.STAGE_BREWING_DAY)
	if not resumable.is_empty():
		_open_brewing_day(String(resumable.get("brew_id", "")))
		return
	var issues: Array = GameState.start_brewing_issues(STARTER_RECIPE_ID)
	if not issues.is_empty():
		# Don't even open the picker — the player can't act yet.
		_render_action_prompt()
		return
	_open_picker_for(Apartment2D.STATION_SINK, "What goes in the sink?",
		_on_sink_item_picked)

func _on_sink_item_picked(equipment_id: String) -> void:
	if equipment_id == "kettle_5gal":
		_start_new_brew()

func _start_new_brew() -> void:
	var recipe: RecipeDef = load("res://data/recipes/%s.tres" % STARTER_RECIPE_ID)
	var brew_id: String = GameState.make_brew_id()
	var seed: int = int(GameState.data.get("rng_state", {}).get("next_brew_seed", 0))
	var brew := BrewState.make_new(
		brew_id, STARTER_RECIPE_ID, recipe.to_snapshot(),
		TimeService.day_clock, seed,
	)
	GameState.data["brews_in_flight"].append(brew)
	GameState.data["rng_state"]["next_brew_seed"] = randi()
	_open_brewing_day(brew_id)

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
		_action_prompt.text = "Closet's empty."
		return
	var brew_id: String = String(brew.get("brew_id", ""))
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_modal"):
		main.push_modal(CHECK_FERMENTER_MODAL, func(inst): inst.brew_id = brew_id)

func _on_stove_tapped() -> void:
	var resumable: Dictionary = _find_brew_in_stage(BrewState.STAGE_BREWING_DAY)
	if not resumable.is_empty():
		_open_brewing_day(String(resumable.get("brew_id", "")))
		return
	_action_prompt.text = "Stove's cold. Start a brew at the kettle first."

func _on_journal_tapped() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(JOURNAL_SCENE)

func _on_bottling_table_tapped() -> void:
	# v1: bottling happens through the closet's "Check fermenter" modal
	# once a brew is ready. Hint at it.
	var ready_brew: Dictionary = {}
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == BrewState.STAGE_FERMENTING:
			var snap: Dictionary = b.get("recipe_snapshot", {})
			var elapsed: int = int(b.get("days_elapsed_in_stage", 0))
			if elapsed >= int(snap.get("fermentation_days", 5)):
				ready_brew = b
				break
	if not ready_brew.is_empty():
		_action_prompt.text = "Bottle the %s — tap the closet to start." % _brew_name(ready_brew)
	else:
		_action_prompt.text = "Bottling table — clean and waiting."

func _open_brewing_day(brew_id: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(BREWING_DAY_SCENE, func(inst): inst.brew_id = brew_id)

# ---- HUD render ----

func _render_state() -> void:
	if GameState.data.is_empty():
		_day_label.text = "Day 0"
		_money_row.text = "$ —"
		_action_prompt.text = ""
		return
	_day_label.text = "Day %d" % TimeService.day_clock
	var cash: int = int(GameState.data.get("cash", {}).get("balance", 0))
	var inv: Dictionary = GameState.data.get("inventory", {})
	var bottles: Dictionary = inv.get("bottles", {})
	var bottles_avail: int = int(bottles.get("available", 0))
	var bottles_in_use: int = int(bottles.get("in_use", 0))
	if bottles_in_use > 0:
		_money_row.text = "$%d · %d bottles (%d capping)" % [cash, bottles_avail, bottles_in_use]
	else:
		_money_row.text = "$%d · %d bottles" % [cash, bottles_avail]
	_render_morning_summary()
	_render_action_prompt()

func _render_morning_summary() -> void:
	var brews: Array = GameState.data.get("brews_in_flight", [])
	var day: int = TimeService.day_clock
	var lines: Array = []
	if day == 0 and brews.is_empty():
		lines = [
			"First day in the apartment.",
			"Stockpot's on the counter. Bucket's in the closet.",
		]
	elif brews.is_empty():
		lines = [
			"Quiet morning. Closet's empty.",
			"Empty fermenter. Empty kettle.",
			"Calm day. The supplies are clean.",
		]
	else:
		var any_ready := false
		var any_fermenting := false
		var any_conditioning := false
		for b in brews:
			var stage: String = String(b.get("stage", ""))
			var elapsed: int = int(b.get("days_elapsed_in_stage", 0))
			var snap: Dictionary = b.get("recipe_snapshot", {})
			if stage == BrewState.STAGE_FERMENTING:
				any_fermenting = true
				if elapsed >= int(snap.get("fermentation_days", 5)):
					any_ready = true
			elif stage == BrewState.STAGE_BOTTLED_CONDITIONING:
				any_conditioning = true
				if elapsed >= int(snap.get("condition_days", 14)):
					any_ready = true
		if any_ready:
			lines = ["Something's ready for you."]
		elif any_fermenting:
			lines = ["Faint yeast smell from the closet.", "Closet's quiet."]
		elif any_conditioning:
			lines = ["Bottles in the rack are settling."]
	if lines.is_empty():
		_morning_summary.text = ""
	else:
		_morning_summary.text = String(lines[day % lines.size()])

func _render_action_prompt() -> void:
	var resumable: Dictionary = _find_brew_in_stage(BrewState.STAGE_BREWING_DAY)
	var fermenting: Dictionary = _find_brew_in_stage(BrewState.STAGE_FERMENTING)
	var conditioning: Dictionary = _find_brew_in_stage(BrewState.STAGE_BOTTLED_CONDITIONING)
	if not resumable.is_empty():
		_action_prompt.text = "Tap the kettle to resume — %s" % _brew_name(resumable)
		return
	if not fermenting.is_empty():
		var snap: Dictionary = fermenting.get("recipe_snapshot", {})
		var elapsed: int = int(fermenting.get("days_elapsed_in_stage", 0))
		var ferm: int = int(snap.get("fermentation_days", 5))
		_action_prompt.text = "Closet — %s, day %d/%d" % [_brew_name(fermenting), elapsed, ferm]
		return
	if not conditioning.is_empty():
		var snap2: Dictionary = conditioning.get("recipe_snapshot", {})
		var elapsed2: int = int(conditioning.get("days_elapsed_in_stage", 0))
		var cond: int = int(snap2.get("condition_days", 14))
		_action_prompt.text = "Closet — %s, conditioning %d/%d" % [_brew_name(conditioning), elapsed2, cond]
		return
	var issues: Array = GameState.start_brewing_issues(STARTER_RECIPE_ID)
	if issues.is_empty():
		_action_prompt.text = "Tap the kettle to start a brew"
	elif _missing_ingredient_count(issues) > 0:
		_action_prompt.text = "Need ingredients. Tap the phone to shop."
	else:
		_action_prompt.text = String(issues[0])

func _missing_ingredient_count(issues: Array) -> int:
	var n: int = 0
	for s in issues:
		if String(s).begins_with("Need "):
			n += 1
	return n

func _find_brew_in_stage(stage: String) -> Dictionary:
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == stage:
			return b
	return {}

func _brew_name(brew: Dictionary) -> String:
	var snap: Dictionary = brew.get("recipe_snapshot", {})
	return String(snap.get("display_name", brew.get("recipe_id", "Brew")))

# ---- HUD button handlers ----

func _on_rest_pressed() -> void:
	TimeService.advance_day()

func _on_phone_pressed() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_phone"):
		main.push_phone(PHONE_OVERLAY_SCENE)

func _on_update_available(latest_name: String, latest_code: int, _release_url: String) -> void:
	_update_label.text = "Update available: v%s (build %d)" % [latest_name, latest_code]
	_update_banner.visible = true
