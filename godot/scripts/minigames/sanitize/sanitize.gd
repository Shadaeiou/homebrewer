extends Control

## Sanitize fermenter & tools (mini-game #11) — job-execution shape per
## DESIGN.md 3.9 + Appendix A Step 1. Each sub-action is optional; the
## breadth taken determines (a) the care_factor for THIS interaction and
## (b) the resulting fermenter cleanliness state, which carries forward
## into the next brew's infection_risk_baseline.
##
## Star San is gated on consumable inventory — if the player didn't buy
## it during shopping (a real Appendix A trade-off, surfaced once the
## phone shop ships), the toggle is disabled and care_factor caps at
## 0.85, state caps at CLEAN. Per the design's "real consequences."

signal minigame_completed(outcome: Dictionary)

## Each row: id, label, consumable_id (or empty), state_floor (the lowest
## state this action leaves the bucket in if taken in isolation).
const SUB_ACTIONS := [
	{"id": "rinse",       "label": "Rinse with water",        "consumable": "",          "state_after": "SERVICEABLE"},
	{"id": "soap",        "label": "Soap-wash with sponge",   "consumable": "dish_soap", "state_after": "CLEAN"},
	{"id": "star_san",    "label": "Sanitize with Star San",  "consumable": "star_san",  "state_after": "SANITIZED"},
	{"id": "drip_dry",    "label": "Drip-dry on rack",        "consumable": "",          "state_after": ""},
]

const STATE_RANK := {
	"USED": 0, "DIRTY": 0, "SERVICEABLE": 1, "CLEAN": 2, "SANITIZED": 3,
}

# Risk deltas keyed by the resulting state. Worst-state-after-this-cleaning
# carries the infection-risk baseline forward.
const STATE_RISK_DELTAS := {
	"USED":        {"infection": 4.0},
	"SERVICEABLE": {"infection": 2.0},
	"CLEAN":       {"infection": 0.5},
	"SANITIZED":   {},
}

@onready var _stage_title: Label = %StageTitle
@onready var _toggle_container: VBoxContainer = %ToggleContainer
@onready var _hint_label: Label = %HintLabel
@onready var _done_button: Button = %DoneButton

var _stage_meta: Dictionary = {}
var _toggles: Dictionary = {}  # id → CheckBox

func _ready() -> void:
	_done_button.pressed.connect(_on_done_pressed)
	_apply_stage_meta()
	_render_toggles()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title != null:
		_stage_title.text = String(_stage_meta.get("title", "Sanitize fermenter & tools"))

func _render_toggles() -> void:
	for child in _toggle_container.get_children():
		child.queue_free()
	_toggles.clear()
	var consumables: Dictionary = GameState.data.get("inventory", {}).get("consumables", {})
	for spec in SUB_ACTIONS:
		var id: String = String(spec["id"])
		var consumable: String = String(spec["consumable"])
		var owned: bool = consumable.is_empty() or consumables.has(consumable)
		var box := CheckBox.new()
		box.text = String(spec["label"])
		if not owned:
			box.text += " (need to buy)"
			box.disabled = true
		_toggle_container.add_child(box)
		_toggles[id] = box

func _resulting_state(taken_ids: Array) -> String:
	# The state ranks up with each progressively-stronger action taken.
	# Skip everything → USED (bucket starts that way per 3.2). Rinse →
	# SERVICEABLE. Soap → CLEAN. Star San → SANITIZED. Drip-dry doesn't
	# move the state but counts toward care breadth.
	if taken_ids.is_empty():
		return "USED"
	var best: String = "USED"
	for spec in SUB_ACTIONS:
		var id: String = String(spec["id"])
		if not taken_ids.has(id):
			continue
		var sa: String = String(spec.get("state_after", ""))
		if sa.is_empty():
			continue
		if int(STATE_RANK.get(sa, 0)) > int(STATE_RANK.get(best, 0)):
			best = sa
	return best

func _on_done_pressed() -> void:
	var taken: Array = []
	for id in _toggles:
		var box: CheckBox = _toggles[id]
		if box.button_pressed and not box.disabled:
			taken.append(id)
	# Available pool excludes any disabled (un-owned) action — the player
	# can't be penalized for breadth they were never offered.
	var available: int = 0
	for spec in SUB_ACTIONS:
		var box: CheckBox = _toggles[String(spec["id"])]
		if not box.disabled:
			available += 1
	var resulting_state := _resulting_state(taken)
	var care: float = CareFactor.from_breadth(taken.size(), max(1, available))
	var risk: Dictionary = Dictionary(STATE_RISK_DELTAS.get(resulting_state, {})).duplicate(true)
	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(taken, resulting_state)]

	# Side-effect: update the fermenter instance's persistent state per 3.2.
	var owned: Dictionary = GameState.data.get("equipment", {}).get("owned", {})
	if owned.has("plastic_bucket_fermenter_1"):
		owned["plastic_bucket_fermenter_1"]["state"] = resulting_state
		owned["plastic_bucket_fermenter_1"]["sanitized_at_day"] = TimeService.day_clock if resulting_state == "SANITIZED" else -1

	var outcome := {
		"actual": {
			"actions_taken": taken,
			"resulting_fermenter_state": resulting_state,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {"sanitation": _xp_for_state(resulting_state)},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _xp_for_state(state: String) -> int:
	match state:
		"SANITIZED":   return 12
		"CLEAN":       return 8
		"SERVICEABLE": return 5
		_:             return 2  # skipped — you still learned something about doing it badly

func _journal_summary(taken: Array, state: String) -> String:
	if taken.is_empty():
		return "Skipped cleaning — bucket left as-is. Infection risk is real."
	var labels: Array = []
	for spec in SUB_ACTIONS:
		if taken.has(String(spec["id"])):
			labels.append(String(spec["label"]).to_lower())
	return "Cleaned the fermenter: %s. Final state: %s." % [", ".join(labels), state]
