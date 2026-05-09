extends Control

## Boil + hops — combined Bring-to-Boil (mini-game #5) and 60-min Boil
## with hop schedule (mini-game #3) per DESIGN.md 3.9 + Appendix A
## Steps 5-6.
##
## v1 ships a form-shape placeholder for this stage. The intended
## end-state per 3.9 is a real-time mini-game with timed hop-drop prompts,
## hot-break recognition, and a boil-over response window — that
## experience requires the kitchen render-pipeline art (which the user
## flagged is supplied separately) and real-time scene_clock wiring.
## Until those land, the form captures the same decision space:
##
##   - Burner heat dial (HIGH / MED / LOW)
##   - Hot-break recognition (Watch closely toggle)
##   - Hop schedule (Drop on schedule toggle)
##   - Boil-over response (Lower heat / Blow / Skim / Ignore)
##   - Flameout response (Turn off promptly toggle)
##
## The Outcome contract (ibu_actual, volume_loss_gal, risk_deltas) stays
## the same; only the input affordance changes when the real-time UI ships.

signal minigame_completed(outcome: Dictionary)

@onready var _stage_title: Label = %StageTitle
@onready var _heat_group: VBoxContainer = %HeatGroup
@onready var _attention_toggle: CheckBox = %AttentionToggle
@onready var _hops_toggle: CheckBox = %HopsToggle
@onready var _boilover_group: VBoxContainer = %BoilOverGroup
@onready var _flameout_toggle: CheckBox = %FlameoutToggle
@onready var _confirm_button: Button = %ConfirmButton

var _stage_meta: Dictionary = {}
var _heat: String = "HIGH"
var _boilover: String = "lower_heat"
var _heat_radios: Dictionary = {}
var _boilover_radios: Dictionary = {}

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_render_heat_radios()
	_render_boilover_radios()
	_apply_stage_meta()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title != null:
		_stage_title.text = String(_stage_meta.get("title", "Boil with hops"))

func _render_heat_radios() -> void:
	for child in _heat_group.get_children():
		child.queue_free()
	_heat_radios.clear()
	_add_radio(_heat_group, _heat_radios, "HIGH", "HIGH (fast, may overshoot)", true,
		func(id): _heat = id)
	_add_radio(_heat_group, _heat_radios, "MED", "MED (moderate)", false,
		func(id): _heat = id)
	_add_radio(_heat_group, _heat_radios, "LOW", "LOW (slow, may not reach rolling boil)", false,
		func(id): _heat = id)

func _render_boilover_radios() -> void:
	for child in _boilover_group.get_children():
		child.queue_free()
	_boilover_radios.clear()
	_add_radio(_boilover_group, _boilover_radios, "lower_heat", "Lower the heat (effective)", true,
		func(id): _boilover = id)
	_add_radio(_boilover_group, _boilover_radios, "blow", "Blow on the foam (small effect)", false,
		func(id): _boilover = id)
	_add_radio(_boilover_group, _boilover_radios, "skim", "Skim the foam (tiny, risky)", false,
		func(id): _boilover = id)
	_add_radio(_boilover_group, _boilover_radios, "ignore", "Ignore (full boil-over)", false,
		func(id): _boilover = id)

func _add_radio(parent: VBoxContainer, group: Dictionary, id: String, label: String, default: bool, on_select: Callable) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = default
	box.toggled.connect(func(pressed):
		if not pressed:
			box.button_pressed = true
			return
		for sib_id in group:
			if sib_id != id:
				group[sib_id].set_pressed_no_signal(false)
		on_select.call(id)
	)
	parent.add_child(box)
	group[id] = box

func _on_confirm_pressed() -> void:
	# IBU drift per 3.9.5: boil_recognition_offset + hop_utilization scale.
	var ibu_factor: float = 1.0
	if _heat == "LOW":
		ibu_factor *= 0.85   # didn't reach a true rolling boil
	if not _attention_toggle.button_pressed:
		ibu_factor *= 0.94   # ±60s window without watching → ~6% IBU drift
	if not _hops_toggle.button_pressed:
		ibu_factor *= 0.85   # hops dropped late → utilization down

	# Volume loss from boil-over and over-boil.
	var volume_loss: float = 0.0
	var risk: Dictionary = {}
	match _boilover:
		"ignore":
			volume_loss += 0.65
			risk["boil_over"] = 5.0
		"skim":
			volume_loss += 0.20
			risk["boil_over"] = 1.5
		"blow":
			volume_loss += 0.40
			risk["boil_over"] = 2.5
		"lower_heat":
			pass  # ideal response

	if not _flameout_toggle.button_pressed:
		# Forgot flameout → over-boil. IBU rises, volume drops.
		ibu_factor *= 1.08
		volume_loss += 0.30
		risk["recipe_drift"] = float(risk.get("recipe_drift", 0.0)) + 1.0

	# Care factor — breadth across the two cheap optional toggles.
	var taken: int = 0
	if _attention_toggle.button_pressed:
		taken += 1
	if _flameout_toggle.button_pressed:
		taken += 1
	var care: float = CareFactor.from_breadth(taken, 2)

	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(ibu_factor, volume_loss)]
	var outcome := {
		"actual": {
			"heat":              _heat,
			"watched_for_break": _attention_toggle.button_pressed,
			"hops_on_schedule":  _hops_toggle.button_pressed,
			"boilover_response": _boilover,
			"prompt_flameout":   _flameout_toggle.button_pressed,
			"ibu_factor":        ibu_factor,
			"volume_loss_gal":   volume_loss,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {"timing": 8, "temp_control": 5, "process": 3},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _journal_summary(ibu_factor: float, volume_loss: float) -> String:
	var bits: Array = []
	bits.append("Burner %s." % _heat)
	bits.append("IBU factor %.2f." % ibu_factor)
	if volume_loss > 0.05:
		bits.append("Volume loss ~%.2f gal." % volume_loss)
	if _boilover == "ignore":
		bits.append("Boil-over went unmanaged.")
	if not _flameout_toggle.button_pressed:
		bits.append("Forgot flameout — let it over-boil.")
	return " ".join(bits)
