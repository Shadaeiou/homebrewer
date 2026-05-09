extends Control

## Fill Kettle (real, v4) — Mini-game #1 per DESIGN.md 3.9 + Appendix A Step 2.
##
## Camera focuses on the apartment's sink station. Kettle is placed on the
## counter under the brass faucet. Tap the faucet handle to start water;
## tap again to stop. Where you stopped becomes intended_volume; drift
## rolls actual on top per Process skill, faucet eyeball precision, and
## care factor.
##
## Per the apartment-as-world design: this scene EMBEDS Apartment2D rather
## than drawing its own kitchen. Other mini-games (Pour LME, Cool Wort,
## etc.) reuse the same apartment scrolled to their respective stations.

signal minigame_completed(outcome: Dictionary)

const APARTMENT_SCENE: PackedScene = preload("res://scenes/lib/apartment_2d.tscn")

const TARGET_GAL: float = 2.5
const MAX_GAL: float = 5.0
const BASE_DRIFT_GAL: float = 0.5
const FAUCET_PRECISION: float = 0.40
const FILL_RATE_GAL_PER_SEC: float = 0.85
const OPTIONAL_ACTIONS_TOTAL: int = 2
const XP_AWARD: Dictionary = {"process": 8}

@onready var _stage_title: Label = %StageTitle
@onready var _readout: Label = %Readout
@onready var _viewport: Control = %ApartmentViewport
@onready var _slow_toggle: CheckBox = %SlowToggle
@onready var _verify_toggle: CheckBox = %VerifyToggle
@onready var _confirm_button: Button = %ConfirmButton

var _apartment: Apartment2D = null
var _kettle: Kettle2D = null
var _stage_meta: Dictionary = {}
var _filled_gal: float = 0.0
var _flow_starts: int = 0
var _resolved: bool = false

func _ready() -> void:
	set_process(true)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_apply_stage_meta()
	_mount_apartment()
	_update_readout()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title:
		_stage_title.text = String(_stage_meta.get("title", "Fill kettle"))

func _mount_apartment() -> void:
	_apartment = APARTMENT_SCENE.instantiate()
	_viewport.add_child(_apartment)
	# Wait one frame so the apartment's _ready spawns the faucet, then
	# wire interactions and place the kettle.
	await get_tree().process_frame
	# Snap camera to sink station immediately (no animation on first mount).
	_apartment.position = _apartment.camera_offset_for(
		Apartment2D.STATION_SINK, _viewport.size.x,
	)
	# Drop a kettle on the counter at the sink station.
	_kettle = Kettle2D.new()
	_kettle.name = "Kettle"
	# Kettle's draw box has rim_y_local = 8 and bottom at HEIGHT+8.
	# Place its bottom on the counter at sink_x.
	const KETTLE_W: float = 244.0
	const KETTLE_H: float = 232.0
	var sink: Vector2 = _apartment.station_anchor(Apartment2D.STATION_SINK)
	_kettle.position = Vector2(sink.x - KETTLE_W * 0.5, sink.y - 228)
	_kettle.target_fraction = TARGET_GAL / MAX_GAL
	_kettle.target_band_width = 36.0
	_kettle.target_color = Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.42)
	_apartment.add_child(_kettle)
	# Connect faucet input.
	if _apartment.faucet != null:
		_apartment.faucet.toggled.connect(_on_faucet_toggled)

func _process(delta: float) -> void:
	if _resolved or _apartment == null or _apartment.faucet == null:
		return
	if _apartment.faucet.is_on:
		_filled_gal = min(_filled_gal + FILL_RATE_GAL_PER_SEC * delta, MAX_GAL)
		if _kettle != null:
			_kettle.set_fill(_filled_gal / MAX_GAL)
		_update_readout()
		if _filled_gal >= MAX_GAL:
			_apartment.faucet.set_on(false)

func _on_faucet_toggled(is_on: bool) -> void:
	if is_on:
		_flow_starts += 1
	_update_readout()

func _update_readout() -> void:
	if _readout == null:
		return
	_readout.text = "%.2f / %.1f gal" % [_filled_gal, TARGET_GAL]
	var err: float = abs(_filled_gal - TARGET_GAL)
	if err < 0.10:
		_readout.add_theme_color_override("font_color", Palette.GRADE_A)
	elif err < 0.25:
		_readout.add_theme_color_override("font_color", Palette.GRADE_B)
	elif err < 0.50:
		_readout.add_theme_color_override("font_color", Palette.GRADE_C)
	else:
		_readout.add_theme_color_override("font_color", Palette.GRADE_D)

func _optional_actions_taken() -> int:
	var n: int = 0
	if _slow_toggle.button_pressed:
		n += 1
	if _verify_toggle.button_pressed:
		n += 1
	return n

func _on_confirm_pressed() -> void:
	if _resolved:
		return
	if _apartment != null and _apartment.faucet != null and _apartment.faucet.is_on:
		_apartment.faucet.set_on(false)
	_resolved = true

	var skills: Dictionary = GameState.data.get("skills", {})
	var process_level: int = int(skills.get("process", {}).get("level", 0))
	var skill_factor: float = Drift.skill_factor_from_level(process_level)
	var care_factor: float = CareFactor.from_breadth(_optional_actions_taken(), OPTIONAL_ACTIONS_TOTAL)

	var rng := RandomNumberGenerator.new()
	rng.seed = _brew_rng_seed()

	var stopped_at: float = _filled_gal
	var actual_gal: float = Drift.compute_actual(
		stopped_at,
		BASE_DRIFT_GAL,
		skill_factor,
		FAUCET_PRECISION,
		care_factor,
		rng,
	)
	actual_gal = clampf(actual_gal, 0.0, MAX_GAL)

	var notes: Array = ["Filled to ~%.2f gal (target %.1f) from the faucet." % [actual_gal, TARGET_GAL]]
	if _slow_toggle.button_pressed:
		notes.append("Took your time on the pour.")
	if _verify_toggle.button_pressed:
		notes.append("Stopped to double-check before topping off.")
	if _flow_starts >= 3:
		notes.append("Stopped and started the tap a few times — careful work.")

	var outcome: Dictionary = {
		"actual": {
			"water_volume_gal":  actual_gal,
			"water_source":       "tap",
			"method":              "faucet",
			"player_stopped_at":  stopped_at,
			"flow_starts":         _flow_starts,
		},
		"care_factor":   care_factor,
		"risk_deltas":   {},
		"xp_gained":     XP_AWARD,
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _brew_rng_seed() -> int:
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == BrewState.STAGE_BREWING_DAY:
			return int(b.get("rng_state", 0)) ^ Time.get_ticks_msec()
	return randi()
