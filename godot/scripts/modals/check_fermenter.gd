extends Control

## Check fermenter modal — perception placeholder per DESIGN.md 3.7 + 4.3.
##
## v1 surfaces brew status + a vague airlock-activity observation.
## The full design has the perception panel listing equipment-gated
## methods (visual via thermotape, taste via tester bottle, etc.) and
## skill-gated legibility ("feels cool" → "feels mid-60s" with Process).
## That layering is additive on top of this baseline once anomalies +
## the cleanliness state machine land in step 11.
##
## The modal hosts the action button (Bottle this brew / Pour & taste)
## when the brew has reached its ready beat — that affordance moved off
## the dashboard's checklist row when this modal landed.

const BOTTLING_SCENE := preload("res://scenes/minigames/bottling.tscn")
const TASTING_SCENE  := preload("res://scenes/minigames/tasting.tscn")

@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _observation_label: Label = %ObservationLabel
@onready var _action_button: Button = %ActionButton
@onready var _close_button: Button = %CloseButton
@onready var _backdrop: ColorRect = %Backdrop

var brew_id: String = ""
var _brew: Dictionary = {}
var _action_kind: String = ""  # "bottle" | "taste" | ""

func _ready() -> void:
	# Modal must process while tree is paused so close + action work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(_on_close_pressed)
	_action_button.pressed.connect(_on_action_pressed)
	_backdrop.gui_input.connect(_on_backdrop_input)
	_resolve_brew()
	_render()

func _resolve_brew() -> void:
	if brew_id == "":
		return
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("brew_id", "")) == brew_id:
			_brew = b
			return

func _render() -> void:
	if _brew.is_empty():
		_title_label.text = "No brew here"
		_status_label.text = ""
		_observation_label.text = ""
		_action_button.visible = false
		return
	var snapshot: Dictionary = _brew.get("recipe_snapshot", {})
	var name: String = String(snapshot.get("display_name", _brew.get("recipe_id", "Brew")))
	var stage: String = String(_brew.get("stage", ""))
	var elapsed: int = int(_brew.get("days_elapsed_in_stage", 0))

	_title_label.text = name

	match stage:
		BrewState.STAGE_FERMENTING:
			var ferm_days: int = int(snapshot.get("fermentation_days", 5))
			_status_label.text = "Fermenting · day %d of %d" % [elapsed, ferm_days]
			_observation_label.text = _airlock_observation(elapsed, ferm_days)
			if elapsed >= ferm_days:
				_action_kind = "bottle"
				_action_button.text = "Bottle this brew"
				_action_button.visible = true
				# Bottle availability is a hard-block per 4.2. Surface
				# the reason inline so the player isn't left guessing.
				var issues: Array = GameState.bottling_issues(brew_id)
				if not issues.is_empty():
					_action_button.disabled = true
					_observation_label.text += "\n\n%s" % " ".join(
						issues.map(func(s): return String(s)))
				else:
					_action_button.disabled = false
			else:
				_action_button.visible = false
		BrewState.STAGE_BOTTLED_CONDITIONING:
			var cond_days: int = int(snapshot.get("condition_days", 14))
			_status_label.text = "Conditioning · day %d of %d" % [elapsed, cond_days]
			_observation_label.text = _conditioning_observation(elapsed, cond_days)
			if elapsed >= cond_days:
				_action_kind = "taste"
				_action_button.text = "Pour & taste"
				_action_button.visible = true
			else:
				_action_button.visible = false
		_:
			_status_label.text = stage
			_observation_label.text = ""
			_action_button.visible = false

func _airlock_observation(elapsed: int, total: int) -> String:
	# Vague observation, the way 3.7 describes pre-skill perception. Real
	# legibility (numbers, precision) gates on Palate / equipment per the
	# design; this is a placeholder.
	if elapsed <= 0:
		return "The airlock just sealed up. Quiet for now."
	var pct: float = float(elapsed) / float(max(total, 1))
	if pct < 0.45:
		return "Airlock bubbling actively — yeast is going."
	if pct < 0.70:
		return "Bubbles are slowing. Wort smells like beer instead of bread now."
	if pct < 0.95:
		return "Airlock barely moves. Sediment thick on the bottom."
	return "Airlock is still. Looks done."

func _conditioning_observation(elapsed: int, total: int) -> String:
	if elapsed <= 1:
		return "Bottles in the rack. Quiet for the next two weeks."
	if elapsed < total:
		return "Bottles look settled. Sediment dropping cleanly."
	return "Bottles look ready. Time to crack one."

func _on_close_pressed() -> void:
	_dismiss()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss()

func _dismiss() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("pop_modal"):
		main.pop_modal()

func _on_action_pressed() -> void:
	# Pop the modal first so the active scene mount happens against an
	# unpaused tree.
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	if main.has_method("pop_modal"):
		main.pop_modal()
	if not main.has_method("mount_active_scene"):
		return
	match _action_kind:
		"bottle":
			var bid := brew_id
			main.mount_active_scene(BOTTLING_SCENE, func(inst): inst.brew_id = bid)
		"taste":
			var bid := brew_id
			main.mount_active_scene(TASTING_SCENE, func(inst): inst.brew_id = bid)
