extends Control

## Brew details panel — opened by tapping a brew card in the
## active-brews HUD list. Shows ingredients (green if owned, red if
## missing) and the stage list with completion status.

@onready var _title: Label = %Title
@onready var _stage_line: Label = %StageLine
@onready var _ingredients_list: VBoxContainer = %IngredientsList
@onready var _steps_list: VBoxContainer = %StepsList
@onready var _close_button: Button = %CloseButton

var brew_id: String = ""

const STAGE_LABELS: Dictionary = {
	"sanitize":       "Sanitize",
	"fill_kettle":    "Fill kettle",
	"heat":           "Heat water",
	"add_lme":        "Add malt extract",
	"boil_with_hops": "Boil with hops",
	"cool_wort":      "Cool the wort",
	"transfer_pitch": "Transfer + pitch yeast",
	"mash_temp_hold": "Mash temp hold",
}

const EXTRACT_STEPS: Array = [
	"sanitize", "fill_kettle", "heat", "add_lme",
	"boil_with_hops", "cool_wort", "transfer_pitch",
]

const COLOR_HAVE: Color = Color(0.45, 0.78, 0.42, 1)
const COLOR_MISSING: Color = Color(0.92, 0.45, 0.38, 1)
const COLOR_DONE: Color = Color(0.45, 0.78, 0.42, 1)
const COLOR_PENDING: Color = Color(0.65, 0.62, 0.58, 1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(_close)
	var brew: Dictionary = _find_brew()
	if brew.is_empty():
		_title.text = "Brew not found"
		return
	_render(brew)

func _find_brew() -> Dictionary:
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("brew_id", "")) == brew_id:
			return b
	return {}

func _render(brew: Dictionary) -> void:
	var snap: Dictionary = brew.get("recipe_snapshot", {})
	_title.text = String(snap.get("display_name", brew.get("recipe_id", "Brew")))
	_stage_line.text = _stage_blurb(brew)
	_render_ingredients(brew)
	_render_steps(brew)

func _stage_blurb(brew: Dictionary) -> String:
	var stage: String = String(brew.get("stage", ""))
	var snap: Dictionary = brew.get("recipe_snapshot", {})
	var elapsed: int = int(brew.get("days_elapsed_in_stage", 0))
	match stage:
		BrewState.STAGE_BREWING_DAY:
			return "Brewing day in progress"
		BrewState.STAGE_FERMENTING:
			var ferm: int = int(snap.get("fermentation_days", 5))
			return "Fermenting · day %d / %d" % [elapsed, ferm]
		BrewState.STAGE_BOTTLED_CONDITIONING:
			var cond: int = int(snap.get("condition_days", 14))
			return "Conditioning · day %d / %d" % [elapsed, cond]
		_:
			return stage

func _render_ingredients(brew: Dictionary) -> void:
	for child in _ingredients_list.get_children():
		child.queue_free()
	var snap: Dictionary = brew.get("recipe_snapshot", {})
	var inv_ingredients: Dictionary = GameState.data.get("inventory", {}).get("ingredients", {})
	# Walk fermentables, hop_schedule, yeast.
	var rows: Array = []
	for f in snap.get("fermentables", []):
		rows.append({"id": String(f.get("id", "")), "label": _ingredient_label(f), "qty_needed": f.get("amount_lb", 0)})
	for h in snap.get("hop_schedule", []):
		rows.append({"id": String(h.get("id", "")), "label": _ingredient_label(h), "qty_needed": h.get("amount_oz", 0)})
	for y in snap.get("yeast", []):
		rows.append({"id": String(y.get("id", "")), "label": _ingredient_label(y), "qty_needed": 1})
	# Priming sugar (always required).
	rows.append({"id": "priming_sugar", "label": "Priming sugar", "qty_needed": 1})
	for row in rows:
		_ingredients_list.add_child(_ingredient_row(row, inv_ingredients))

func _ingredient_label(d: Dictionary) -> String:
	var name: String = String(d.get("display_name", d.get("id", "")))
	if d.has("amount_lb"):
		return "%s · %.1f lb" % [name, float(d["amount_lb"])]
	if d.has("amount_oz"):
		return "%s · %.1f oz" % [name, float(d["amount_oz"])]
	return name

func _ingredient_row(row: Dictionary, inv_ingredients: Dictionary) -> Control:
	var have: bool = inv_ingredients.has(String(row["id"]))
	var label := Label.new()
	label.text = "%s  %s" % ["✓" if have else "✗", String(row["label"])]
	label.add_theme_color_override("font_color", COLOR_HAVE if have else COLOR_MISSING)
	label.add_theme_font_size_override("font_size", 12)
	return label

func _render_steps(brew: Dictionary) -> void:
	for child in _steps_list.get_children():
		child.queue_free()
	var stage: String = String(brew.get("stage", ""))
	var outcomes: Dictionary = brew.get("outcomes", {})
	# Brewing-day steps + the post-brew stages.
	var steps: Array = []
	for sid in EXTRACT_STEPS:
		steps.append({"id": sid, "label": STAGE_LABELS.get(sid, sid)})
	steps.append({"id": "ferment", "label": "Ferment"})
	steps.append({"id": "bottle", "label": "Bottle"})
	steps.append({"id": "condition", "label": "Condition"})
	steps.append({"id": "taste", "label": "Taste"})
	for step in steps:
		_steps_list.add_child(_step_row(step, brew, stage, outcomes))

func _step_row(step: Dictionary, brew: Dictionary, current_stage: String, outcomes: Dictionary) -> Control:
	var step_id: String = String(step["id"])
	var label_text: String = String(step["label"])
	var done: bool = false
	var score_text: String = ""
	# Brewing-day mini-game outcomes.
	if outcomes.has(step_id):
		done = true
		var oc: Dictionary = outcomes[step_id]
		var care: float = float(oc.get("care_factor", 0.0))
		score_text = " · %d%%" % int(round(care * 100))
	# Post-brew stages flagged by current stage.
	if step_id == "ferment" and current_stage in [BrewState.STAGE_FERMENTING, BrewState.STAGE_BOTTLED_CONDITIONING]:
		done = current_stage != BrewState.STAGE_FERMENTING
	if step_id == "bottle" and current_stage == BrewState.STAGE_BOTTLED_CONDITIONING:
		done = true
	var label := Label.new()
	label.text = "%s %s%s" % ["✓" if done else "·", label_text, score_text]
	label.add_theme_color_override("font_color", COLOR_DONE if done else COLOR_PENDING)
	label.add_theme_font_size_override("font_size", 12)
	return label

func _close() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("pop_modal"):
		main.pop_modal()
	else:
		queue_free()
