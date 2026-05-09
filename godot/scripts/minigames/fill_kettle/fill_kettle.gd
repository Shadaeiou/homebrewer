extends Control

## Fill Kettle (real, v3) — Mini-game #1 per DESIGN.md 3.9 + Appendix A Step 2.
##
## Real visuals: apartment kitchen scene with the stockpot on the counter,
## brass faucet hanging above the sink. Tap the faucet handle to start
## water flowing — water level rises in the kettle in real time. Tap again
## to stop. Wherever you stopped becomes your actual_volume_gal, with a
## drift roll on top per skill / equipment_precision / care_factor.
##
## The "Pour slowly" + "Verify amount" toggles still feed CareFactor; the
## care factor compresses drift around the level you stopped at. Faucet
## eyeball method has equipment_precision 0.40 (per 3.1's worked example),
## so even a perfect timer-stop wobbles around target.
##
## v3 ships only the faucet/tap method visually. Pitcher / jug / spring
## variants land later as their own gestures (drag jug to kettle, repeat
## fills with the pitcher) — they're the same Outcome shape with different
## input affordances.

signal minigame_completed(outcome: Dictionary)

const TARGET_GAL: float = 2.5            # Per Appendix A: partial-boil recipe.
const MAX_GAL: float = 5.0               # Pot capacity per data/equipment/apartment_stockpot.
const BASE_DRIFT_GAL: float = 0.5
const FAUCET_PRECISION: float = 0.40     # Per 3.1 — eyeball pour, no markings.
const FILL_RATE_GAL_PER_SEC: float = 0.85
const OPTIONAL_ACTIONS_TOTAL: int = 2
const XP_AWARD: Dictionary = {"process": 8, "temp_control": 0, "sanitation": 0}

@onready var _stage_title: Label = %StageTitle
@onready var _readout: Label = %Readout
@onready var _hint: Label = %Hint
@onready var _kitchen: KitchenScene = %KitchenScene
@onready var _kettle: Kettle2D = %Kettle
@onready var _faucet: Faucet2D = %Faucet
@onready var _slow_toggle: CheckBox = %SlowToggle
@onready var _verify_toggle: CheckBox = %VerifyToggle
@onready var _confirm_button: Button = %ConfirmButton

var _stage_meta: Dictionary = {}
var _filled_gal: float = 0.0
var _flow_starts: int = 0  # tap toggles; "double-check" if player paused & resumed
var _resolved: bool = false

func _ready() -> void:
	set_process(true)
	_faucet.toggled.connect(_on_faucet_toggled)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	# Kettle draws a target band at the 2.5gal mark; band width reflects
	# faucet eyeball precision (wide). Target fraction = TARGET / MAX.
	_kettle.target_fraction = TARGET_GAL / MAX_GAL
	_kettle.target_band_width = 36.0
	_kettle.target_color = Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.42)
	_apply_stage_meta()
	_update_readout()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title:
		_stage_title.text = String(_stage_meta.get("title", "Fill kettle"))

func _process(delta: float) -> void:
	if _resolved or _faucet == null:
		return
	if _faucet.is_on:
		_filled_gal = min(_filled_gal + FILL_RATE_GAL_PER_SEC * delta, MAX_GAL)
		_kettle.set_fill(_filled_gal / MAX_GAL)
		_update_readout()
		# Auto-stop at the brim — let players overflow visually but cap the var.
		if _filled_gal >= MAX_GAL:
			_faucet.set_on(false)

func _on_faucet_toggled(is_on: bool) -> void:
	if is_on:
		_flow_starts += 1
	_update_readout()

func _update_readout() -> void:
	if _readout == null:
		return
	_readout.text = "%.2f / %.1f gal" % [_filled_gal, TARGET_GAL]
	# Color the readout by how close we are to target.
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
	if _faucet.is_on:
		_faucet.set_on(false)
	_resolved = true

	# Skill factor from the player's process axis.
	var skills: Dictionary = GameState.data.get("skills", {})
	var process_level: int = int(skills.get("process", {}).get("level", 0))
	var skill_factor: float = Drift.skill_factor_from_level(process_level)
	var care_factor: float = CareFactor.from_breadth(_optional_actions_taken(), OPTIONAL_ACTIONS_TOTAL)

	# Pull a deterministic seed off the brew if we can find one.
	var rng := RandomNumberGenerator.new()
	rng.seed = _brew_rng_seed()

	# The visible level is the player's intended volume; drift is what
	# *actually* ended up in the pot once you account for spillage,
	# meniscus mis-read, and the 2.5gal mark being eyeballed.
	var stopped_at: float = _filled_gal
	var actual_gal: float = Drift.compute_actual(
		stopped_at,
		BASE_DRIFT_GAL,
		skill_factor,
		FAUCET_PRECISION,
		care_factor,
		rng,
	)
	# Clamp to the physical pot size — wort can't exceed kettle capacity.
	actual_gal = clampf(actual_gal, 0.0, MAX_GAL)

	var notes: Array = []
	notes.append("Filled to ~%.2f gal (target %.1f) from the faucet." % [actual_gal, TARGET_GAL])
	if _slow_toggle.button_pressed:
		notes.append("Took your time on the pour.")
	if _verify_toggle.button_pressed:
		notes.append("Stopped to double-check before topping off.")
	if _flow_starts >= 3:
		notes.append("Stopped and started the tap a few times — careful work.")

	var outcome: Dictionary = {
		"actual": {
			"water_volume_gal": actual_gal,
			"water_source":     "tap",
			"method":            "faucet",
			"player_stopped_at": stopped_at,
			"flow_starts":        _flow_starts,
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
