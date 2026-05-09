extends Control

## Pour LME (mini-game #4) — canonical procedure shape per DESIGN.md 3.9 +
## Appendix A Step 4. The order is the load-bearing thing: turn off burner
## FIRST, start stirring, THEN pour LME. Wrong order produces a discrete
## catastrophic event (SCORCH) regardless of how careful the actual pour
## was. Care_factor still rides on top via optional sub-actions.
##
## Three required actions in tap order, plus two optional breadth-care
## toggles. After the third required tap the result resolves and a 1.5s
## reveal beat plays before minigame_completed emits — gives the player a
## moment to read whether they scorched before brewing_day swaps stages.

signal minigame_completed(outcome: Dictionary)

const RESULT_TEXT := {
	"IDEAL":               "Ideal — clean dissolve, no scorch.",
	"MILD_GLOB":           "Mild glob — LME pooled at the bottom; some stayed undissolved.",
	"MODERATE_SCORCH":     "Moderate scorch — burner came off late; caramel smell, darker tone.",
	"CATASTROPHIC_SCORCH": "SCORCH — LME hit a hot kettle with no stirring. Hard scorch.",
}

const RESULT_DISSOLUTION := {
	"IDEAL": 1.0, "MILD_GLOB": 0.7, "MODERATE_SCORCH": 0.85, "CATASTROPHIC_SCORCH": 0.5,
}

const RESULT_RISK := {
	"IDEAL": {},
	"MILD_GLOB": {"recipe_drift": 1.0},
	"MODERATE_SCORCH": {"off_flavor_temp": 3.0, "recipe_drift": 1.5},
	"CATASTROPHIC_SCORCH": {"off_flavor_temp": 6.5, "recipe_drift": 4.0},
}

const RESULT_XP := {
	"IDEAL":               {"process": 12, "temp_control": 8},
	"MILD_GLOB":           {"process": 8,  "temp_control": 5},
	"MODERATE_SCORCH":     {"process": 5,  "temp_control": 5},
	"CATASTROPHIC_SCORCH": {"process": 3,  "temp_control": 3},
}

const REVEAL_SECONDS := 1.5

@onready var _stage_title: Label = %StageTitle
@onready var _burner_off_button: Button = %BurnerOffButton
@onready var _stir_button: Button = %StirButton
@onready var _lme_pour_button: Button = %LmePourButton
@onready var _read_aloud_toggle: CheckBox = %ReadAloudToggle
@onready var _pre_warm_toggle: CheckBox = %PreWarmToggle
@onready var _result_label: Label = %ResultLabel

var _stage_meta: Dictionary = {}
var _action_order: Array = []
var _resolved: bool = false
var _pending_outcome: Dictionary = {}

func _ready() -> void:
	_burner_off_button.pressed.connect(_on_action.bind("burner_off", _burner_off_button))
	_stir_button.pressed.connect(_on_action.bind("stir", _stir_button))
	_lme_pour_button.pressed.connect(_on_action.bind("lme_pour", _lme_pour_button))
	_apply_stage_meta()
	_result_label.text = ""

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title != null:
		_stage_title.text = String(_stage_meta.get("title", "Heat & add malt extract"))

func _on_action(action_id: String, btn: Button) -> void:
	if _resolved or _action_order.has(action_id):
		return
	_action_order.append(action_id)
	btn.disabled = true
	btn.text = "%s · step %d" % [_action_label(action_id), _action_order.size()]
	if _action_order.size() == 3:
		_resolve()

func _resolve() -> void:
	_resolved = true
	var burner_idx: int = _action_order.find("burner_off")
	var stir_idx: int = _action_order.find("stir")
	var lme_idx: int = _action_order.find("lme_pour")
	var burner_off_before_lme: bool = burner_idx < lme_idx
	var stir_before_lme: bool = stir_idx < lme_idx

	var result_id: String
	if burner_off_before_lme and stir_before_lme:
		result_id = "IDEAL"
	elif burner_off_before_lme:
		result_id = "MILD_GLOB"
	elif stir_before_lme:
		result_id = "MODERATE_SCORCH"
	else:
		result_id = "CATASTROPHIC_SCORCH"

	var skills: Dictionary = GameState.data.get("skills", {})
	var care := CareFactor.from_breadth(_optional_taken(), 2)
	var notes: Array = [String(RESULT_TEXT[result_id])]
	if _read_aloud_toggle.button_pressed:
		notes.append("Read the recipe step aloud first.")
	if _pre_warm_toggle.button_pressed:
		notes.append("Pre-warmed the LME tin in hot tap water — softer pour.")

	_pending_outcome = {
		"actual": {
			"sequence": _action_order.duplicate(),
			"result": result_id,
			"lme_dissolution": float(RESULT_DISSOLUTION[result_id]),
		},
		"care_factor": care,
		"risk_deltas": Dictionary(RESULT_RISK[result_id]).duplicate(true),
		"xp_gained": Dictionary(RESULT_XP[result_id]).duplicate(true),
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}

	# Reveal beat: show what happened before swapping stages.
	_result_label.text = String(RESULT_TEXT[result_id])
	_result_label.modulate = _result_color(result_id)
	var reveal := get_tree().create_timer(REVEAL_SECONDS)
	reveal.timeout.connect(_emit_pending_outcome)

func _emit_pending_outcome() -> void:
	minigame_completed.emit(_pending_outcome)

func _optional_taken() -> int:
	var n := 0
	if _read_aloud_toggle.button_pressed:
		n += 1
	if _pre_warm_toggle.button_pressed:
		n += 1
	return n

func _action_label(action_id: String) -> String:
	match action_id:
		"burner_off": return "Burner off"
		"stir":       return "Stirring"
		"lme_pour":   return "LME poured"
		_:            return action_id

func _result_color(result_id: String) -> Color:
	match result_id:
		"IDEAL":               return Color(0.55, 0.90, 0.55, 1)  # green
		"MILD_GLOB":           return Color(0.95, 0.85, 0.50, 1)  # yellow
		"MODERATE_SCORCH":     return Color(0.95, 0.55, 0.30, 1)  # orange
		"CATASTROPHIC_SCORCH": return Color(0.95, 0.35, 0.30, 1)  # red
		_:                     return Color(1, 1, 1, 1)
