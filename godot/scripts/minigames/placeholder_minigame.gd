extends Control

## Placeholder mini-game per HANDOFF.md step 5.
##
## Renders the stage title + a "Continue" button that synthesizes a benign
## Outcome dict and emits `minigame_completed`. Used by brewing_day.gd
## when no real mini-game scene is registered for a stage. Replaced
## per-stage as real mini-games land (step 7+).
##
## Outcome shape mirrors the universal mini-game scaffolding (3.9):
##   { actual, care_factor, risk_deltas, xp_gained, journal_notes,
##     skill_snapshot }
## All fields here are zero/empty stubs. The Outcome shape lint test
## (planned for step 7) will verify real mini-games match this contract.

signal minigame_completed(outcome: Dictionary)

@onready var _title: Label = %StageTitle
@onready var _continue: Button = %ContinueButton

var _stage: Dictionary = {}

func _ready() -> void:
	_continue.pressed.connect(_on_continue_pressed)
	_apply_stage_meta()

func set_stage_meta(stage: Dictionary) -> void:
	_stage = stage
	if is_inside_tree():
		_apply_stage_meta()

func _apply_stage_meta() -> void:
	var t := String(_stage.get("title", "Stage"))
	_title.text = t

func _on_continue_pressed() -> void:
	var outcome := {
		"actual": {},
		"care_factor": 1.0,
		"risk_deltas": {},
		"xp_gained": {},
		"journal_notes": ["(placeholder stage — no real outcome recorded)"],
		"skill_snapshot": SkillXP.snapshot(GameState.data.get("skills", {})),
	}
	minigame_completed.emit(outcome)
