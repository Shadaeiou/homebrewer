extends Control

## Cool the wort (mini-game #4 in 3.9's catalog) — decision shape per
## DESIGN.md 3.9 + Appendix A Step 7.
##
## Two paths with real trade-offs:
##   A. Ice bath  — slower, costs ice, but lower final temp + tighter
##                  infection window if you stir + monitor.
##   B. Top-off cooling (recipe-suggested) — faster, free, but final
##                  temp is higher (~80°F) and the cold water itself
##                  is a sanitation gamble depending on source.
##
## Outcome.actual.final_temp_f drives pitch-temp viability downstream
## (Mini-game #6 Pitch yeast cares about this); risk_deltas.infection
## carries the cooling-window sanitation cost forward.

signal minigame_completed(outcome: Dictionary)

const PATH_ICE_BATH := "ice_bath"
const PATH_TOP_OFF := "top_off"

@onready var _stage_title: Label = %StageTitle
@onready var _path_group: VBoxContainer = %PathGroup
@onready var _options_group: VBoxContainer = %OptionsGroup
@onready var _readout: Label = %Readout
@onready var _confirm_button: Button = %ConfirmButton

var _stage_meta: Dictionary = {}
var _selected_path: String = PATH_ICE_BATH
var _option_toggles: Dictionary = {}  # option_id → CheckBox
var _path_radios: Dictionary = {}     # path_id → CheckBox

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_render_path_options()
	_render_options_for_path()
	_apply_stage_meta()
	_update_readout()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title != null:
		_stage_title.text = String(_stage_meta.get("title", "Cool the wort"))

func _render_path_options() -> void:
	for child in _path_group.get_children():
		child.queue_free()
	_path_radios.clear()
	_add_path(PATH_ICE_BATH, "Ice bath (slower, lower temp)", true)
	_add_path(PATH_TOP_OFF, "Top-off cooling (faster, warmer)", false)

func _add_path(id: String, label: String, default: bool) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = default
	box.toggled.connect(func(pressed): _on_path_toggled(id, box, pressed))
	_path_group.add_child(box)
	_path_radios[id] = box

func _on_path_toggled(id: String, btn: CheckBox, pressed: bool) -> void:
	if not pressed:
		btn.button_pressed = true   # don't allow deselecting all
		return
	for sib_id in _path_radios:
		if sib_id != id:
			_path_radios[sib_id].set_pressed_no_signal(false)
	_selected_path = id
	_render_options_for_path()
	_update_readout()

func _render_options_for_path() -> void:
	for child in _options_group.get_children():
		child.queue_free()
	_option_toggles.clear()
	if _selected_path == PATH_ICE_BATH:
		_add_option("ice", "Buy ice ($2)", true)            # only relevant if not owned; v1 always-buy
		_add_option("stir", "Stir occasionally", true)
		_add_option("monitor", "Monitor temp with thermometer", true)
	else:  # PATH_TOP_OFF
		_add_option("boil_topoff", "Boil top-off water first", true)
		_add_option("bottled_topoff", "Use bottled water", _has_bottled_water())

func _add_option(id: String, label: String, owned: bool) -> void:
	var box := CheckBox.new()
	box.text = label
	if not owned:
		box.text += " (need to buy)"
		box.disabled = true
	box.toggled.connect(func(_b): _update_readout())
	_options_group.add_child(box)
	_option_toggles[id] = box

func _has_bottled_water() -> bool:
	var ing: Dictionary = GameState.data.get("inventory", {}).get("ingredients", {})
	# v1 pre-seed only includes tap_water; bottled spring becomes available
	# once the phone shop ships.
	return ing.has("water_spring") or ing.has("water_bottled")

func _update_readout() -> void:
	if _readout == null:
		return
	var available: int = _available_options()
	var taken: int = _taken_options()
	var care := CareFactor.from_breadth(taken, max(1, available))
	var temp := _projected_final_temp(care)
	_readout.text = "Projected final temp: ~%d°F · care factor: %.2f" % [int(round(temp)), care]

func _available_options() -> int:
	var n := 0
	for id in _option_toggles:
		if not _option_toggles[id].disabled:
			n += 1
	return n

func _taken_options() -> int:
	var n := 0
	for id in _option_toggles:
		var box: CheckBox = _option_toggles[id]
		if box.button_pressed and not box.disabled:
			n += 1
	return n

func _projected_final_temp(care: float) -> float:
	# Path A targets 70°F, Path B targets ~80°F. Care nudges down.
	var base: float = 70.0 if _selected_path == PATH_ICE_BATH else 80.0
	# Higher care → tighter convergence to base; low care → drifts up.
	var slop: float = (1.0 - care) * 6.0
	return base + slop

func _on_confirm_pressed() -> void:
	var available: int = _available_options()
	var taken_ids: Array = []
	for id in _option_toggles:
		var box: CheckBox = _option_toggles[id]
		if box.button_pressed and not box.disabled:
			taken_ids.append(id)
	var care: float = CareFactor.from_breadth(taken_ids.size(), max(1, available))
	var final_temp: float = _projected_final_temp(care)

	var risk: Dictionary = {}
	if _selected_path == PATH_ICE_BATH:
		# Cooling window infection risk: ice + stir + monitor → close to 0.
		# Skip stir or monitor → noticeable risk from prolonged cooling.
		var missed_protection: int = 3 - taken_ids.size()
		if missed_protection > 0:
			risk["infection"] = float(missed_protection) * 0.7
	else:  # PATH_TOP_OFF
		# Top-off path has a sanitation gamble on the cold water itself.
		var protection_taken: bool = taken_ids.has("boil_topoff") or taken_ids.has("bottled_topoff")
		if not protection_taken:
			risk["infection"] = 2.5  # raw tap water onto hot wort
		# Higher final temp than Path A → off_flavor risk if pitch happens warm.
		if final_temp >= 78.0:
			risk["off_flavor_temp"] = 1.0

	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(taken_ids, final_temp)]
	var outcome := {
		"actual": {
			"path": _selected_path,
			"actions_taken": taken_ids,
			"final_temp_f": final_temp,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {
			"temp_control": _xp_temp(),
			"sanitation": 3 if _selected_path == PATH_ICE_BATH else 2,
		},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _xp_temp() -> int:
	# Ice bath rewards more temp_control practice (active monitoring); top-off
	# is mostly hands-off.
	return 8 if _selected_path == PATH_ICE_BATH else 4

func _journal_summary(taken: Array, final_temp: float) -> String:
	var path_label: String = "ice bath" if _selected_path == PATH_ICE_BATH else "top-off cooling"
	if taken.is_empty():
		return "Cooled via %s with no extra care. Final temp ~%d°F." % [path_label, int(round(final_temp))]
	return "Cooled via %s (%s). Final temp ~%d°F." % [path_label, ", ".join(taken), int(round(final_temp))]
