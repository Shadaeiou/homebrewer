extends Node

## Active-brew orchestrator. One brew at a time for now. Persists across
## scene changes (autoload), so the home → brew_flow → mini-game → brew_flow
## navigation keeps state.
##
## A brew progresses through a fixed sequence of stages. Each stage either:
##   - has a real mini-game scene (currently only "prepare" → fill_kettle), or
##   - is a placeholder that completes with an "ideal" outcome on a tap.
##
## When the player completes a stage, the outcome (a Dictionary) lands in
## `outcomes[stage_id]`. After all stages, Grading.compute() turns those
## outcomes + the recipe into a final A+/A/B/C/D/F grade.

signal stage_changed(new_stage_index: int)
signal brew_completed(grade: String)

const STAGES: Array[Dictionary] = [
	{
		"id": "prepare",
		"label": "Measure & boil water",
		"description": "Fill the kettle with strike water for the mash.",
		"minigame": "res://scenes/minigames/fill_kettle.tscn",
	},
	{
		"id": "mash",
		"label": "Mash the grain",
		"description": "Hold the wet grain at ~65 °C for 60 minutes so enzymes convert starch to sugar.",
		"minigame": "",
	},
	{
		"id": "boil",
		"label": "Boil with hops",
		"description": "Boil the wort for 60 minutes. Hop additions at 60, 15, and 5 minutes remaining.",
		"minigame": "",
	},
	{
		"id": "cool",
		"label": "Cool the wort",
		"description": "Chill from near-boiling down to about 20 °C as fast as you can — slow chilling lets bugs in.",
		"minigame": "",
	},
	{
		"id": "pitch",
		"label": "Pitch the yeast",
		"description": "Aerate the cooled wort and pitch the yeast. Sealed fermentor from here on.",
		"minigame": "",
	},
	{
		"id": "ferment",
		"label": "Fermentation",
		"description": "Hold around 19 °C for ~10 days. Watch the airlock.",
		"minigame": "",
	},
	{
		"id": "bottle",
		"label": "Bottle the beer",
		"description": "Transfer to bottles with a touch of priming sugar, cap each one.",
		"minigame": "",
	},
	{
		"id": "condition",
		"label": "Conditioning",
		"description": "Two weeks of patience while the bottles carbonate and the flavor settles.",
		"minigame": "",
	},
	{
		"id": "taste",
		"label": "Tasting",
		"description": "Pour. Smell. Drink. Final grade.",
		"minigame": "",
	},
]

var active: bool = false
var recipe: Dictionary = {}
var outcomes: Dictionary = {}        # stage_id -> Dictionary
var stage_index: int = -1
var final_grade: String = ""
var final_summary: String = ""

func start(recipe_dict: Dictionary) -> void:
	active = true
	recipe = recipe_dict.duplicate(true)
	outcomes = {}
	stage_index = 0
	final_grade = ""
	final_summary = ""
	stage_changed.emit(stage_index)

func reset() -> void:
	active = false
	recipe = {}
	outcomes = {}
	stage_index = -1
	final_grade = ""
	final_summary = ""

func current_stage() -> Dictionary:
	if stage_index < 0 or stage_index >= STAGES.size():
		return {}
	return STAGES[stage_index]

func current_stage_id() -> String:
	var s := current_stage()
	return s.get("id", "")

func current_minigame_path() -> String:
	var s := current_stage()
	return s.get("minigame", "")

func is_complete() -> bool:
	return active and stage_index >= STAGES.size()

func record_stage_outcome(outcome: Dictionary) -> void:
	## Mini-game (or placeholder) reports its result. Stores it under the
	## current stage id and advances. Emits brew_completed when all stages
	## are done.
	if not active:
		push_warning("BrewSession.record_stage_outcome called with no active brew")
		return
	var sid := current_stage_id()
	if sid == "":
		return
	outcomes[sid] = outcome.duplicate(true)
	stage_index += 1
	if stage_index >= STAGES.size():
		_finalize()
	else:
		stage_changed.emit(stage_index)

func record_ideal_outcome() -> void:
	## Placeholder for stages without mini-games yet. Records a "B-grade"
	## outcome so the flow ends in a believable middle-of-the-road brew
	## rather than perfection.
	var sid := current_stage_id()
	var ideal := _ideal_outcome_for(sid)
	record_stage_outcome(ideal)

func _ideal_outcome_for(stage_id: String) -> Dictionary:
	## Returns a "did it adequately" outcome for placeholder stages. Real
	## mini-games will replace these with actual measured results.
	match stage_id:
		"prepare":
			return {"water_l": recipe.get("target_volume_l", 4.0), "grade": "B"}
		"mash":
			return {
				"temp_held_c": recipe.get("mash_temp_c", 65.0),
				"minutes_held": recipe.get("mash_minutes", 60.0),
				"efficiency": 0.72,
				"grade": "B",
			}
		"boil":
			return {
				"boiled_minutes": recipe.get("boil_minutes", 60.0),
				"hops_on_schedule": true,
				"boil_over": false,
				"grade": "B",
			}
		"cool":
			return {
				"end_temp_c": recipe.get("pitch_temp_c", 20.0),
				"minutes": 25.0,
				"infection_risk_added": 0.05,
				"grade": "B",
			}
		"pitch":
			return {
				"aeration": 0.8,
				"sanitation": 0.85,
				"infection_risk_added": 0.03,
				"grade": "B",
			}
		"ferment":
			return {
				"days": recipe.get("ferment_days", 10.0),
				"avg_temp_c": recipe.get("ferment_temp_c", 19.0),
				"infection_risk_added": 0.02,
				"grade": "B",
			}
		"bottle":
			return {
				"bottles_filled": 12,
				"sanitation": 0.9,
				"priming_sugar_g": 90.0,
				"grade": "B",
			}
		"condition":
			return {"days": recipe.get("condition_days", 14.0), "grade": "B"}
		"taste":
			return {"grade": ""}  # Filled in by Grading
		_:
			return {"grade": "B"}

func _finalize() -> void:
	var result: Dictionary = Grading.compute(self)
	final_grade = result.get("grade", "F")
	final_summary = result.get("summary", "")
	brew_completed.emit(final_grade)
