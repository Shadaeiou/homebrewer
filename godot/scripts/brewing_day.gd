extends Control

## Brewing-day controller per HANDOFF.md step 5.
##
## Mounts under ActiveSceneContainer. On _ready it:
##   1. Looks up the brew-in-flight by brew_id (must be set before
##      add_child by the caller — the dashboard's "Start brewing" button
##      handles this in step 6).
##   2. Derives the stage list from the recipe's method (v1 = EXTRACT;
##      all-grain unlocks add the mash stage per 3.8).
##   3. Mounts the current stage's mini-game scene (or a placeholder)
##      into the body slot and listens for `minigame_completed(outcome)`.
##   4. On each completion: BrewState.record_outcome, advance.
##   5. After the last stage: brew transitions to fermenting,
##      Main.clear_active_scene() returns the player to the dashboard.
##
## Mini-game scenes are looked up via MINIGAME_SCENES; entries land here
## as each mini-game is built (step 7+). Until a stage has a real scene,
## PLACEHOLDER_SCENE renders a "Stage: <title> — Continue" stub that
## synthesizes a benign outcome on tap so the scaffold is testable
## end-to-end before real mini-games exist.

signal brew_completed(brew_id: String)

const PLACEHOLDER_SCENE := preload("res://scenes/minigames/placeholder_minigame.tscn")

## v1 extract stages per Appendix A's Step 1–7 + 3.9's mini-game catalog.
## All-grain prepends a mash-temp-hold stage when that method unlocks.
const EXTRACT_STAGES := [
	{"id": "sanitize",       "title": "Sanitize fermenter & tools"},
	{"id": "fill_kettle",    "title": "Fill kettle"},
	{"id": "heat",           "title": "Heat the water"},
	{"id": "add_lme",        "title": "Add malt extract"},
	{"id": "boil_with_hops", "title": "Boil with hops"},
	{"id": "cool_wort",      "title": "Cool the wort"},
	{"id": "transfer_pitch", "title": "Transfer + pitch yeast"},
]

const ALL_GRAIN_PREFIX := [
	{"id": "mash_temp_hold", "title": "Mash temp hold"},
]

## Filled in as mini-games land. Stages without a registered scene fall
## back to PLACEHOLDER_SCENE.
const MINIGAME_SCENES := {
	"sanitize":       preload("res://scenes/minigames/sanitize.tscn"),
	"fill_kettle":    preload("res://scenes/minigames/fill_kettle.tscn"),
	"add_lme":        preload("res://scenes/minigames/pour_lme.tscn"),
	"boil_with_hops": preload("res://scenes/minigames/boil_with_hops.tscn"),
	"cool_wort":      preload("res://scenes/minigames/cool_wort.tscn"),
	"transfer_pitch": preload("res://scenes/minigames/transfer_pitch.tscn"),
}

@onready var _recipe_title: Label = %RecipeTitle
@onready var _stage_list: VBoxContainer = %StageList
@onready var _stage_body: PanelContainer = %StageBody
@onready var _close_button: Button = %CloseButton

var brew_id: String = ""

## Dev/harness affordance — set before add_child to skip ahead. Real
## gameplay always starts at index 0 since the dashboard creates a
## fresh BrewState.
var initial_stage_index: int = 0

var _brew: Dictionary = {}
var _recipe: RecipeDef = null
var _stages: Array = []
var _current_stage_index: int = 0
var _mounted_minigame: Node = null

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	# Caller sets brew_id before add_child OR the harness mounts us
	# stand-alone for screenshots; in the latter case we render against
	# a synthesized demo brew.
	_resolve_brew_or_demo()
	_recipe_title.text = _recipe.display_name if _recipe else "—"
	_stages = _stages_for_method(_recipe.method if _recipe else "EXTRACT")
	_current_stage_index = clampi(initial_stage_index, 0, _stages.size() - 1)
	_render_stage_list()
	_mount_current_stage()

func _resolve_brew_or_demo() -> void:
	if brew_id != "":
		for b in GameState.data.get("brews_in_flight", []):
			if String(b.get("brew_id", "")) == brew_id:
				_brew = b
				break
	if _brew.is_empty():
		# No brew_id passed (harness or dev-preview): fall back to APA so
		# the scene renders something meaningful.
		_recipe = load("res://data/recipes/apartment_pale_ale.tres")
		return
	var recipe_id: String = _brew.get("recipe_id", "")
	_recipe = load("res://data/recipes/%s.tres" % recipe_id)

func _stages_for_method(method: String) -> Array:
	if method == "ALL_GRAIN" or method == "PARTIAL_MASH":
		var combined: Array = []
		for s in ALL_GRAIN_PREFIX:
			combined.append(s)
		for s in EXTRACT_STAGES:
			combined.append(s)
		return combined
	return EXTRACT_STAGES.duplicate()

func _render_stage_list() -> void:
	for child in _stage_list.get_children():
		child.queue_free()
	for i in range(_stages.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var marker := Label.new()
		marker.text = _stage_marker(i)
		marker.custom_minimum_size = Vector2(20, 0)
		row.add_child(marker)
		var title := Label.new()
		title.text = String(_stages[i]["title"])
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == _current_stage_index:
			title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
		elif i < _current_stage_index:
			title.modulate = Color(0.6, 0.6, 0.6)
		row.add_child(title)
		_stage_list.add_child(row)

func _stage_marker(i: int) -> String:
	if i < _current_stage_index:
		return "✓"
	if i == _current_stage_index:
		return "▶"
	return "·"

func _mount_current_stage() -> void:
	if _mounted_minigame != null:
		_mounted_minigame.queue_free()
		_mounted_minigame = null
	if _current_stage_index >= _stages.size():
		_complete_brew()
		return
	var stage: Dictionary = _stages[_current_stage_index]
	var stage_id := String(stage["id"])
	var packed: PackedScene = MINIGAME_SCENES.get(stage_id, PLACEHOLDER_SCENE)
	var instance: Node = packed.instantiate()
	if instance.has_method("set_stage_meta"):
		instance.set_stage_meta(stage)
	if instance.has_signal("minigame_completed"):
		instance.minigame_completed.connect(_on_minigame_completed)
	_stage_body.add_child(instance)
	_mounted_minigame = instance

func _on_minigame_completed(outcome: Dictionary) -> void:
	if not _brew.is_empty():
		var stage_id := String(_stages[_current_stage_index]["id"])
		_brew = BrewState.record_outcome(_brew, stage_id, outcome)
		_replace_brew_in_flight(_brew)
	_current_stage_index += 1
	_render_stage_list()
	_mount_current_stage()

func _complete_brew() -> void:
	if not _brew.is_empty():
		var on_day: int = TimeService.day_clock
		_brew = BrewState.advance_stage(_brew, BrewState.STAGE_FERMENTING, on_day)
		_replace_brew_in_flight(_brew)
	brew_completed.emit(brew_id)
	# Hand control back to the dashboard. Main.clear_active_scene also
	# stops the scene clock per 4.1.
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("clear_active_scene"):
		main.clear_active_scene()

func _replace_brew_in_flight(updated: Dictionary) -> void:
	var brews: Array = GameState.data.get("brews_in_flight", [])
	for i in range(brews.size()):
		if String(brews[i].get("brew_id", "")) == String(updated.get("brew_id", "")):
			brews[i] = updated
			return

func _on_close_pressed() -> void:
	# User-initiated bail-out. Brew stays at its current stage in
	# brews_in_flight; player can resume by tapping the brew on the
	# dashboard later (button wiring lands when step 6 + the resume
	# affordance are added).
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("clear_active_scene"):
		main.clear_active_scene()
