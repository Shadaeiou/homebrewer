extends Control

## Dashboard — the apartment IS the home screen. No landing page, no
## menu. The kitchen fills the viewport; players act on the world by
## tapping objects (kettle → start/resume brew, closet → check fermenter).
##
## A small HUD overlays:
##   - Top-left: day chip + cash/bottles + ambient morning line
##   - Top-right: Phone / Journal / Rest icons
##   - Bottom-center: floating ActionPrompt (what tapping the highlighted
##                     object would do, or what's blocking it)
##   - Top-center (conditional): update banner
##   - Bottom corners: tiny version label + dev reset
##
## State → in-world tappable affordances:
##   No brew yet                      → kettle: "Start brewing"
##   brew in BREWING_DAY              → kettle: "Resume brewing — <name>"
##   brew in FERMENTING               → closet: "Check fermenter — d N/M"
##   brew in BOTTLED_CONDITIONING     → closet: "Check conditioning — d N/M"
##   blocked (no recipe / fermenter)  → kettle prompt explains why

const APARTMENT_SCENE := preload("res://scenes/lib/apartment_2d.tscn")
const BREWING_DAY_SCENE     := preload("res://scenes/brewing_day.tscn")
const BOTTLING_SCENE         := preload("res://scenes/minigames/bottling.tscn")
const TASTING_SCENE          := preload("res://scenes/minigames/tasting.tscn")
const JOURNAL_SCENE          := preload("res://scenes/journal.tscn")
const PHONE_OVERLAY_SCENE    := preload("res://scenes/phone/phone_overlay.tscn")
const CHECK_FERMENTER_MODAL  := preload("res://scenes/modals/check_fermenter.tscn")

const STARTER_RECIPE_ID := "apartment_pale_ale"

@onready var _viewport: Control = %ApartmentViewport
@onready var _day_label: Label = %DayLabel
@onready var _money_row: Label = %MoneyRow
@onready var _morning_summary: Label = %MorningSummary
@onready var _action_prompt: Label = %ActionPrompt
@onready var _phone_button: Button = %PhoneButton
@onready var _journal_button: Button = %JournalButton
@onready var _rest_button: Button = %RestButton
@onready var _version_label: Label = %VersionLabel
@onready var _update_banner: PanelContainer = %UpdateBanner
@onready var _update_label: Label = %UpdateLabel
@onready var _update_button: Button = %UpdateButton
@onready var _dev_reset_button: Button = %DevResetButton
@onready var _reset_confirm_dialog: ConfirmationDialog = %ResetConfirmDialog

var _apartment: Apartment2D = null
var _kettle: Kettle2D = null
var _kettle_hotspot: Button = null
var _closet_hotspot: Button = null

func _ready() -> void:
	_version_label.text = Version.full()
	_phone_button.pressed.connect(_on_phone_pressed)
	_journal_button.pressed.connect(_on_journal_pressed)
	_rest_button.pressed.connect(_on_rest_pressed)
	_dev_reset_button.pressed.connect(func(): _reset_confirm_dialog.popup_centered())
	_reset_confirm_dialog.confirmed.connect(func(): SaveService.wipe_and_reset())
	_update_button.pressed.connect(Updater.install_update)
	Updater.update_available.connect(_on_update_available)
	GameState.state_loaded.connect(_render_state)
	GameState.day_advanced.connect(func(_d): _render_state())
	_mount_apartment()
	_render_state()

func _mount_apartment() -> void:
	_apartment = APARTMENT_SCENE.instantiate()
	_viewport.add_child(_apartment)
	await get_tree().process_frame
	_recenter()
	# Persistent kettle on the counter — the home view always shows the
	# kitchen with the pot already there. Brewing-day mounts its own
	# apartment on top of this one and re-uses the same world drawing,
	# so this kettle is hidden under that scene during a brew.
	const KETTLE_W: float = 244.0
	var sink: Vector2 = _apartment.station_anchor(Apartment2D.STATION_SINK)
	_kettle = Kettle2D.new()
	_kettle.name = "Kettle"
	_kettle.position = Vector2(sink.x - KETTLE_W * 0.5, sink.y - 228)
	_apartment.add_child(_kettle)
	# Tappable areas overlaid on the kettle and the closet door.
	_kettle_hotspot = _make_hotspot(
		Vector2(sink.x, sink.y - 114), Vector2(180, 240), "kettle_hotspot")
	_kettle_hotspot.pressed.connect(_on_kettle_tapped)
	var closet: Vector2 = _apartment.station_anchor(Apartment2D.STATION_CLOSET)
	_closet_hotspot = _make_hotspot(
		Vector2(closet.x, closet.y - 130), Vector2(170, 360), "closet_hotspot")
	_closet_hotspot.pressed.connect(_on_closet_tapped)
	_viewport.resized.connect(_recenter)

func _make_hotspot(center: Vector2, size: Vector2, name: String) -> Button:
	var b := Button.new()
	b.name = name
	b.flat = true
	b.modulate = Color(1, 1, 1, 0)  # invisible — pure click area
	b.size = size
	b.position = Vector2(center.x - size.x * 0.5, center.y - size.y * 0.5)
	b.focus_mode = Control.FOCUS_NONE
	_apartment.add_child(b)
	return b

func _recenter() -> void:
	if _apartment == null:
		return
	var vp: Vector2 = _viewport.size
	var offset: Vector2 = _apartment.camera_offset_for(Apartment2D.STATION_SINK, vp.x)
	offset.y = (vp.y - Apartment2D.PANORAMA_H) * 0.5
	_apartment.position = offset

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
	# What does tapping the highlighted object do right now? The prompt
	# names the action; the player taps the object to do it. If
	# "start brewing" is blocked, the prompt explains why.
	var resumable_brew: Dictionary = _find_brew_in_stage(BrewState.STAGE_BREWING_DAY)
	var fermenting_brew: Dictionary = _find_brew_in_stage(BrewState.STAGE_FERMENTING)
	var conditioning_brew: Dictionary = _find_brew_in_stage(BrewState.STAGE_BOTTLED_CONDITIONING)

	if not resumable_brew.is_empty():
		var name := _brew_name(resumable_brew)
		_action_prompt.text = "Tap the kettle to resume brewing — %s" % name
		return
	if not fermenting_brew.is_empty():
		var snap: Dictionary = fermenting_brew.get("recipe_snapshot", {})
		var elapsed: int = int(fermenting_brew.get("days_elapsed_in_stage", 0))
		var ferm: int = int(snap.get("fermentation_days", 5))
		_action_prompt.text = "Closet — %s, day %d/%d" % [_brew_name(fermenting_brew), elapsed, ferm]
		return
	if not conditioning_brew.is_empty():
		var snap2: Dictionary = conditioning_brew.get("recipe_snapshot", {})
		var elapsed2: int = int(conditioning_brew.get("days_elapsed_in_stage", 0))
		var cond: int = int(snap2.get("condition_days", 14))
		_action_prompt.text = "Closet — %s, conditioning %d/%d" % [_brew_name(conditioning_brew), elapsed2, cond]
		return
	# No active brew. Either offer a fresh brew or nudge toward fixing
	# the block. The nudge stays one short line — the player taps the
	# phone if they want to know what's missing.
	var issues: Array = GameState.start_brewing_issues(STARTER_RECIPE_ID)
	if issues.is_empty():
		_action_prompt.text = "Tap the kettle to start a brew"
	elif _missing_ingredient_count(issues) > 0:
		_action_prompt.text = "Need ingredients. Tap the phone to shop."
	else:
		# Non-ingredient block (e.g. fermenter occupied) — show the first.
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

# ---- Tap handlers ----

func _on_kettle_tapped() -> void:
	# Resume an in-flight brew if any; otherwise start a fresh one if not blocked.
	var resumable: Dictionary = _find_brew_in_stage(BrewState.STAGE_BREWING_DAY)
	if not resumable.is_empty():
		_open_brewing_day(String(resumable.get("brew_id", "")))
		return
	var issues: Array = GameState.start_brewing_issues(STARTER_RECIPE_ID)
	if not issues.is_empty():
		# Re-render the prompt so the player sees what's blocking.
		_render_action_prompt()
		return
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

func _open_brewing_day(brew_id: String) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(BREWING_DAY_SCENE, func(inst): inst.brew_id = brew_id)

func _on_rest_pressed() -> void:
	TimeService.advance_day()

func _on_journal_pressed() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("mount_active_scene"):
		main.mount_active_scene(JOURNAL_SCENE)

func _on_phone_pressed() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("push_phone"):
		main.push_phone(PHONE_OVERLAY_SCENE)

func _on_update_available(latest_name: String, latest_code: int, _release_url: String) -> void:
	_update_label.text = "Update available: v%s (build %d)" % [latest_name, latest_code]
	_update_banner.visible = true
