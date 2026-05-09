extends Control

## Fill Kettle (v2) — Mini-game #1 per DESIGN.md 3.9 + Appendix A Step 2.
##
## Shape: decision (volume target — but expressed via source + method choice
## rather than a numeric dial; the player picks affordances, the system
## resolves the drift).
##
## Sub-actions:
##   Required:
##     - Choose source (tap / bottled spring water)
##     - Choose method (faucet | funnel | pitcher | jug-pour, conditional on source)
##   Optional (count toward care_factor breadth):
##     - "Pour slowly" toggle      → +1 care
##     - "Double-check before pour" → +1 care
##
## Outcome shape per 3.9's universal scaffolding:
##   { actual, care_factor, risk_deltas, xp_gained, journal_notes,
##     skill_snapshot }
##
## Visual layout is intentionally minimal — physical kettle + faucet art
## comes from the render pipeline; this controller only knows the form.

signal minigame_completed(outcome: Dictionary)

const TARGET_GAL := 2.5            # Per Appendix A: partial-boil recipe.
const BASE_DRIFT_GAL := 0.5        # Per 3.1's worked example.
const OPTIONAL_ACTIONS_TOTAL := 2  # ["pour_slowly", "double_check"]
const XP_AWARD := {"process": 8, "temp_control": 0, "sanitation": 0}

# Method → equipment_precision per 3.1 + Appendix A's Step 2 table.
const METHOD_PRECISION := {
	"faucet":  0.40,   # eyeball pour, no markings
	"funnel":  0.45,   # cleaner pour, similar precision
	"pitcher": 0.85,   # 1L stamped pitcher, ~10 pours
	"jug":     0.95,   # bottled spring jug, marked
}

@onready var _stage_title: Label = %StageTitle
@onready var _source_group: VBoxContainer = %SourceGroup
@onready var _method_group: VBoxContainer = %MethodGroup
@onready var _slow_toggle: CheckBox = %SlowToggle
@onready var _verify_toggle: CheckBox = %VerifyToggle
@onready var _pour_button: Button = %PourButton
@onready var _readout: Label = %Readout

var _stage_meta: Dictionary = {}
var _selected_source: String = "tap"
var _selected_method: String = "faucet"

func _ready() -> void:
	_pour_button.pressed.connect(_on_pour_pressed)
	_render_method_options()
	_apply_stage_meta()
	_update_readout()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title != null:
		_stage_title.text = String(_stage_meta.get("title", "Fill kettle"))

func _render_method_options() -> void:
	# Source radios
	for child in _source_group.get_children():
		child.queue_free()
	_add_radio(_source_group, "Tap water",     "tap",    true)
	_add_radio(_source_group, "Bottled jug",   "spring", false)

	_render_method_group()

func _render_method_group() -> void:
	for child in _method_group.get_children():
		child.queue_free()
	if _selected_source == "tap":
		_add_radio(_method_group, "Faucet (eyeball)",       "faucet",  true)
		_add_radio(_method_group, "Funnel",                  "funnel",  false)
		_add_radio(_method_group, "1L pitcher (accurate)",   "pitcher", false)
	else:
		_add_radio(_method_group, "Marked jug (exact)",      "jug",     true)
	_selected_method = _default_method_for_source(_selected_source)
	_update_readout()

func _default_method_for_source(source: String) -> String:
	return "faucet" if source == "tap" else "jug"

func _add_radio(parent: VBoxContainer, label: String, value: String, is_default: bool) -> void:
	var btn := CheckBox.new()
	btn.text = label
	btn.button_pressed = is_default
	btn.set_meta("value", value)
	btn.set_meta("group", parent.name)
	btn.toggled.connect(_on_radio_toggled.bind(btn))
	parent.add_child(btn)

func _on_radio_toggled(pressed: bool, btn: CheckBox) -> void:
	if not pressed:
		# Don't allow deselecting all in a radio group.
		btn.button_pressed = true
		return
	# Uncheck siblings.
	var parent: Node = btn.get_parent()
	for sib in parent.get_children():
		if sib is CheckBox and sib != btn:
			(sib as CheckBox).set_pressed_no_signal(false)
	var value: String = String(btn.get_meta("value"))
	if String(btn.get_meta("group")) == _source_group.name:
		_selected_source = value
		_render_method_group()
	else:
		_selected_method = value
		_update_readout()

func _update_readout() -> void:
	if _readout == null:
		return
	var precision: float = float(METHOD_PRECISION.get(_selected_method, 0.4))
	_readout.text = "Method precision: %.2f · target: %.1f gal" % [precision, TARGET_GAL]

func _optional_actions_taken() -> int:
	var n := 0
	if _slow_toggle != null and _slow_toggle.button_pressed:
		n += 1
	if _verify_toggle != null and _verify_toggle.button_pressed:
		n += 1
	return n

func _on_pour_pressed() -> void:
	# Skill factor from process level. Process is the relevant axis for
	# fill_kettle per 3.4's "two skills worth calling out" callout —
	# Process is the apartment-scale technique skill.
	var skills: Dictionary = GameState.data.get("skills", {})
	var process_level: int = int(skills.get("process", {}).get("level", 0))
	var skill_factor: float = Drift.skill_factor_from_level(process_level)
	var equipment_precision: float = float(METHOD_PRECISION.get(_selected_method, 0.4))
	var care_factor: float = CareFactor.from_breadth(_optional_actions_taken(), OPTIONAL_ACTIONS_TOTAL)

	var rng := RandomNumberGenerator.new()
	# Use the brew's seeded rng_state if we can find it; else random.
	rng.seed = _brew_rng_seed()

	var actual_gal: float = Drift.compute_actual(
		TARGET_GAL,
		BASE_DRIFT_GAL,
		skill_factor,
		equipment_precision,
		care_factor,
		rng,
	)

	var notes: Array = []
	notes.append("Filled kettle to ~%.2f gal (target %.1f) via %s%s." % [
		actual_gal,
		TARGET_GAL,
		_method_label(_selected_method),
		_source_suffix(_selected_source),
	])
	if _slow_toggle != null and _slow_toggle.button_pressed:
		notes.append("Took your time on the pour.")
	if _verify_toggle != null and _verify_toggle.button_pressed:
		notes.append("Double-checked the volume before stopping.")

	var outcome := {
		"actual": {
			"water_volume_gal": actual_gal,
			"water_source": _selected_source,
			"method": _selected_method,
		},
		"care_factor": care_factor,
		"risk_deltas": {},  # fill_kettle doesn't directly add infection / oxidation; that's downstream
		"xp_gained": XP_AWARD,
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _brew_rng_seed() -> int:
	# Walk brews_in_flight for a brewing-day brew; use its rng_state as the
	# seed source so determinism per Section 8.4 holds. Fall back to a
	# random seed if no brew is in flight (demo-mode preview).
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("stage", "")) == BrewState.STAGE_BREWING_DAY:
			return int(b.get("rng_state", 0)) ^ Time.get_ticks_msec()
	return randi()

func _method_label(method: String) -> String:
	match method:
		"faucet":  return "the faucet"
		"funnel":  return "a funnel"
		"pitcher": return "the 1L pitcher"
		"jug":     return "the jug"
		_:         return method

func _source_suffix(source: String) -> String:
	return "" if source == "tap" else " (spring water)"
