extends Control

## Bottling — combined mini-games #8 (Bottle fill) and #9 (Cap bottles)
## per DESIGN.md 3.9 + Appendix A bottling-day. Form-style placeholder
## following the same convention as the brewing-day stages: real
## drag-and-cap-each-bottle mechanics live behind the kitchen render
## pipeline; the Outcome contract is the same.
##
## On Confirm this scene also handles the brew-state transition (since
## bottling-day is a single-stage scene rather than a brewing_day-style
## multi-stage scaffold): record_outcome → advance to
## BOTTLED_CONDITIONING → shift bottles from available→in_use → return
## the player to the dashboard.

signal bottling_completed(brew_id: String)

@onready var _stage_title: Label = %StageTitle
@onready var _priming_group: VBoxContainer = %PrimingGroup
@onready var _fill_group: VBoxContainer = %FillGroup
@onready var _options_group: VBoxContainer = %OptionsGroup
@onready var _readout: Label = %Readout
@onready var _confirm_button: Button = %ConfirmButton
@onready var _close_button: Button = %CloseButton

var brew_id: String = ""

var _selected_priming: String = "bulk"
var _selected_fill: String = "funnel"
var _priming_radios: Dictionary = {}
var _fill_radios: Dictionary = {}
var _options: Dictionary = {}

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_render_priming_radios()
	_render_fill_radios()
	_render_options()
	_update_readout()

func _render_priming_radios() -> void:
	for child in _priming_group.get_children():
		child.queue_free()
	_priming_radios.clear()
	_add_radio(_priming_group, _priming_radios, "bulk", "Bulk-prime in the bucket (even carb)", true,
		func(id): _selected_priming = id)
	_add_radio(_priming_group, _priming_radios, "per_bottle", "Sprinkle into each bottle (uneven)", false,
		func(id): _selected_priming = id)
	_add_radio(_priming_group, _priming_radios, "skip", "Skip priming (flat beer)", false,
		func(id): _selected_priming = id)

func _render_fill_radios() -> void:
	for child in _fill_group.get_children():
		child.queue_free()
	_fill_radios.clear()
	_add_radio(_fill_group, _fill_radios, "funnel", "Pour via funnel (some oxygen)", true,
		func(id): _selected_fill = id)
	_add_radio(_fill_group, _fill_radios, "splashy", "Free pour, splashy (heavy oxidation)", false,
		func(id): _selected_fill = id)
	# Auto-siphon would land here when the player owns one — eliminates
	# oxidation entirely. Disabled until shop ships.
	var siphon := CheckBox.new()
	siphon.text = "Auto-siphon (need to buy)"
	siphon.disabled = true
	_fill_group.add_child(siphon)

func _render_options() -> void:
	for child in _options_group.get_children():
		child.queue_free()
	_options.clear()
	_add_option("sanitize_bottles", "Sanitize bottles before filling", false)
	_add_option("steady_hand",       "Fill with a steady hand (less foam loss)", false)
	_add_option("snug_caps",         "Cap with snug-but-not-crushed pressure", false)

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
		_update_readout()
	)
	parent.add_child(box)
	group[id] = box

func _add_option(id: String, label: String, default: bool) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = default
	box.toggled.connect(func(_b): _update_readout())
	_options_group.add_child(box)
	_options[id] = box

func _update_readout() -> void:
	if _readout == null:
		return
	var carb: float = _carbonation_factor()
	var taken: int = _taken_options()
	var care: float = CareFactor.from_breadth(taken, _options.size())
	_readout.text = "Carbonation factor: %.2f · care: %.2f" % [carb, care]

func _taken_options() -> int:
	var n := 0
	for id in _options:
		if _options[id].button_pressed:
			n += 1
	return n

func _carbonation_factor() -> float:
	match _selected_priming:
		"bulk":       return 1.0
		"per_bottle": return 0.85
		"skip":       return 0.0
		_:            return 1.0

func _on_confirm_pressed() -> void:
	# Defensive: the modal disables this path when bottles are short, but
	# direct route-in (or future affordances) might land here without that
	# check. Hard-abort + return to dashboard with state untouched.
	var issues: Array = GameState.bottling_issues(brew_id)
	if not issues.is_empty():
		push_warning("[bottling] aborted: %s" % str(issues))
		_return_to_dashboard()
		return

	var taken_ids: Array = []
	for id in _options:
		if _options[id].button_pressed:
			taken_ids.append(id)
	var care: float = CareFactor.from_breadth(taken_ids.size(), _options.size())

	var risk: Dictionary = {}
	if _selected_fill == "splashy":
		risk["oxidation"] = 3.0
	elif _selected_fill == "funnel":
		risk["oxidation"] = 0.5
	if not taken_ids.has("sanitize_bottles"):
		risk["infection"] = 2.0
	if not taken_ids.has("snug_caps"):
		# Loose caps = leaks; over-tight = chips.
		risk["oxidation"] = float(risk.get("oxidation", 0.0)) + 0.5

	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(taken_ids)]
	var outcome := {
		"actual": {
			"priming_method":      _selected_priming,
			"fill_method":          _selected_fill,
			"actions_taken":        taken_ids,
			"carbonation_factor":   _carbonation_factor(),
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {"process": 6, "sanitation": 4},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	_apply_brew_transition(outcome)

func _apply_brew_transition(outcome: Dictionary) -> void:
	# Update the brew: record_outcome under "bottle", advance to conditioning.
	var brews: Array = GameState.data.get("brews_in_flight", [])
	var idx: int = -1
	for i in range(brews.size()):
		if String(brews[i].get("brew_id", "")) == brew_id:
			idx = i
			break
	if idx >= 0:
		var b: Dictionary = brews[idx]
		b = BrewState.record_outcome(b, "bottle", outcome)
		b = BrewState.advance_stage(b, BrewState.STAGE_BOTTLED_CONDITIONING, TimeService.day_clock)
		brews[idx] = b
	# Bottles: a 5-gal batch + apartment starter bottle count = exactly 24.
	# Move what's available into in_use; cap at 24 in case the player
	# already had something else taking bottles.
	var inv: Dictionary = GameState.data.get("inventory", {})
	var bottles: Dictionary = inv.get("bottles", {"available": 0, "in_use": 0})
	var to_fill: int = mini(24, int(bottles.get("available", 0)))
	bottles["available"] = int(bottles.get("available", 0)) - to_fill
	bottles["in_use"] = int(bottles.get("in_use", 0)) + to_fill
	inv["bottles"] = bottles
	GameState.data["inventory"] = inv

	# Tell anyone listening (dashboard) the persisted state changed so the
	# brew row + Start-brewing validity refresh on the way back.
	GameState.notify_state_loaded()
	SaveService.flush_now()
	bottling_completed.emit(brew_id)
	_return_to_dashboard()

func _on_close_pressed() -> void:
	# User-initiated bail-out. The brew stays in FERMENTING; player can
	# resume from the dashboard later.
	_return_to_dashboard()

func _return_to_dashboard() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("clear_active_scene"):
		main.clear_active_scene()

func _journal_summary(taken: Array) -> String:
	var prime_labels := {
		"bulk": "bulk-primed", "per_bottle": "per-bottle primed", "skip": "did not prime"
	}
	var prime_label: String = String(prime_labels.get(_selected_priming, _selected_priming))
	var fill_label: String = "splashy free pour" if _selected_fill == "splashy" else "poured via funnel"
	var extras: String = ""
	if not taken.is_empty():
		extras = " (also: %s)" % ", ".join(taken)
	return "Bottled the brew — %s, %s%s." % [prime_label, fill_label, extras]
