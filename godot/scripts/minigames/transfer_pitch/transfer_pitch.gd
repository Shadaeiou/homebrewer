extends Control

## Transfer + Pitch — combined mini-games #5 (Transfer to fermenter) and #6
## (Pitch yeast) per DESIGN.md 3.9 + Appendix A Steps 8-10. Decision +
## small skill shape — pour gesture quality matters, pitch method matters,
## optional sub-actions tighten care.
##
## Combined into one stage scene because the player is at the fermenter
## continuously through transfer → top-off → pitch. Splitting them into
## separate stage swaps would feel like stage-list churn for no UX benefit.

signal minigame_completed(outcome: Dictionary)

@onready var _stage_title: Label = %StageTitle
@onready var _pour_group: VBoxContainer = %PourGroup
@onready var _pitch_group: VBoxContainer = %PitchGroup
@onready var _options_group: VBoxContainer = %OptionsGroup
@onready var _confirm_button: Button = %ConfirmButton

var _stage_meta: Dictionary = {}
var _pour_radios: Dictionary = {}
var _pitch_radios: Dictionary = {}
var _options: Dictionary = {}
var _selected_pour: String = "gentle"
var _selected_pitch: String = "sprinkle"

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_render_pour_radios()
	_render_pitch_radios()
	_render_options()
	_apply_stage_meta()

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	if _stage_title != null:
		_stage_title.text = String(_stage_meta.get("title", "Transfer + pitch yeast"))

func _render_pour_radios() -> void:
	for child in _pour_group.get_children():
		child.queue_free()
	_pour_radios.clear()
	_add_radio(_pour_group, _pour_radios, "gentle", "Pour gently (smooth tilt)", true,
		func(id): _selected_pour = id)
	_add_radio(_pour_group, _pour_radios, "fast", "Pour fast (splashy)", false,
		func(id): _selected_pour = id)

func _render_pitch_radios() -> void:
	for child in _pitch_group.get_children():
		child.queue_free()
	_pitch_radios.clear()
	_add_radio(_pitch_group, _pitch_radios, "sprinkle", "Sprinkle dry yeast on top", true,
		func(id): _selected_pitch = id)
	_add_radio(_pitch_group, _pitch_radios, "rehydrate", "Rehydrate first (+15 in-game min)", false,
		func(id): _selected_pitch = id)

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

func _render_options() -> void:
	for child in _options_group.get_children():
		child.queue_free()
	_options.clear()
	_add_option("even_sprinkle", "Even sprinkle (don't dump in one spot)")
	_add_option("stir_once", "Stir the wort once before pitch")
	_add_option("sanitize_funnel", "Sanitize the funnel between transfers")

func _add_option(id: String, label: String) -> void:
	var box := CheckBox.new()
	box.text = label
	_options_group.add_child(box)
	_options[id] = box

func _on_confirm_pressed() -> void:
	var taken: Array = []
	for id in _options:
		if _options[id].button_pressed:
			taken.append(id)
	# breadth pool always 3 (no consumable gating yet on these options).
	var care: float = CareFactor.from_breadth(taken.size(), _options.size())

	var risk: Dictionary = {}
	if _selected_pour == "fast":
		risk["oxidation"] = 2.0  # splashy pour drives O2 in
	if _selected_pitch == "sprinkle" and not taken.has("even_sprinkle"):
		# Lazy sprinkle: yeast clumps, slow start, infection competition wins more often.
		risk["infection"] = 1.0
	if not taken.has("sanitize_funnel"):
		# Untouched plastic funnel from the kitchen drawer is a real
		# infection vector — small bump.
		risk["infection"] = float(risk.get("infection", 0.0)) + 0.5

	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(taken)]
	var outcome := {
		"actual": {
			"pour_quality": _selected_pour,
			"pitch_method": _selected_pitch,
			"actions_taken": taken,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {
			"sanitation": 6 if taken.has("sanitize_funnel") else 3,
			"process":    8 if _selected_pitch == "rehydrate" else 5,
		},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _journal_summary(taken: Array) -> String:
	var pour_label := "smooth" if _selected_pour == "gentle" else "splashy"
	var pitch_label := "sprinkled dry yeast" if _selected_pitch == "sprinkle" else "rehydrated yeast first"
	var extras := ""
	if not taken.is_empty():
		extras = " (also: %s)" % ", ".join(taken)
	return "Transferred with a %s pour, %s%s." % [pour_label, pitch_label, extras]
