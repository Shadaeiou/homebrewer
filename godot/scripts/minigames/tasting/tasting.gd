extends Control

## Pour & taste — mini-game #12 per DESIGN.md 3.9 + 4.3. Closes the brew:
## computes actual OG/FG/IBU/ABV from the brew's recorded outcomes,
## composes self-grade (vs recipe targets) and external-grade (vs style
## profile), writes a journal entry via SaveService.append_journal_entry,
## removes the brew from brews_in_flight, and frees the in-use bottles.
##
## v1 reveals the math directly. The intended end-state is a Palate-skill-
## gated reveal where low Palate reads "tastes like beer" and high Palate
## reads detailed notes; that swap is additive on top of this baseline.

signal tasting_completed(brew_id: String)

@onready var _stage_title: Label = %StageTitle
@onready var _targets_label: Label = %TargetsLabel
@onready var _actual_label: Label = %ActualLabel
@onready var _self_grade_label: Label = %SelfGradeLabel
@onready var _external_grade_label: Label = %ExternalGradeLabel
@onready var _drink_button: Button = %DrinkButton
@onready var _close_button: Button = %CloseButton

var brew_id: String = ""

var _brew: Dictionary = {}
var _recipe: RecipeDef = null
var _style: StyleProfile = null
var _actuals: Dictionary = {}
var _self_grade: String = ""
var _external_grade: String = ""

func _ready() -> void:
	_drink_button.pressed.connect(_on_drink_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_resolve_brew()
	if _brew.is_empty():
		_stage_title.text = "No brew to taste"
		_drink_button.disabled = true
		return
	_recipe = load("res://data/recipes/%s.tres" % _brew.get("recipe_id", "apartment_pale_ale"))
	if _recipe and _recipe.style:
		_style = load("res://data/styles/%s.tres" % _recipe.style)
	_actuals = _compute_actuals()
	var grades := _compute_grades(_actuals)
	_self_grade = String(grades["self"])
	_external_grade = String(grades["external"])
	_render()

func _resolve_brew() -> void:
	if brew_id == "":
		return
	for b in GameState.data.get("brews_in_flight", []):
		if String(b.get("brew_id", "")) == brew_id:
			_brew = b
			return

func _compute_actuals() -> Dictionary:
	## Derive the brew's final flavor metrics from the chain of recorded
	## outcomes. Conservative formulas — placeholder until proper sim
	## fermentation lands; tuned to make ideal play approach the recipe's
	## targets and bad play diverge visibly.
	var outcomes: Dictionary = _brew.get("outcomes", {})
	var lme_dissolution: float = float(outcomes.get("add_lme", {}).get("actual", {}).get("lme_dissolution", 1.0))
	var ibu_factor: float = float(outcomes.get("boil_with_hops", {}).get("actual", {}).get("ibu_factor", 1.0))
	var volume_loss: float = float(outcomes.get("boil_with_hops", {}).get("actual", {}).get("volume_loss_gal", 0.0))
	var carb_factor: float = float(outcomes.get("bottle", {}).get("actual", {}).get("carbonation_factor", 1.0))

	var actual_volume: float = max(2.0, _recipe.batch_size_gal - volume_loss * 0.5)
	# Less LME dissolved into solution → lower extract → lower OG.
	var actual_og: float = _recipe.target_og * lme_dissolution + 1.020 * (1.0 - lme_dissolution)
	# Volume below batch target concentrates the wort; above dilutes it.
	var volume_factor: float = _recipe.batch_size_gal / max(actual_volume, 0.1)
	actual_og += (volume_factor - 1.0) * 0.020

	var actual_fg: float = _recipe.target_fg
	var actual_ibu: float = _recipe.target_ibu * ibu_factor
	var actual_abv: float = (actual_og - actual_fg) * 131.25

	return {
		"volume_gal":   actual_volume,
		"og":           actual_og,
		"fg":           actual_fg,
		"ibu":          actual_ibu,
		"abv":          actual_abv,
		"carbonation":  carb_factor,
	}

func _compute_grades(actuals: Dictionary) -> Dictionary:
	# Self-grade: average normalized drift across OG / IBU / ABV / carbonation.
	var og_err: float    = abs(actuals["og"] - _recipe.target_og) / max(_recipe.target_og, 0.001)
	var ibu_err: float   = abs(actuals["ibu"] - _recipe.target_ibu) / max(_recipe.target_ibu, 0.001)
	var abv_err: float   = abs(actuals["abv"] - _recipe.target_abv) / max(_recipe.target_abv, 0.001)
	var carb_err: float  = abs(1.0 - actuals["carbonation"])
	var self_total: float = (og_err + ibu_err + abv_err + carb_err) / 4.0
	var self_drift: String = Grader.grade_from_drift_error(self_total)

	# External-grade: distance from BJCP-style ranges.
	var ext_total: float = 0.0
	var ext_components: int = 0
	if _style != null:
		ext_total += _range_error(actuals["og"], _style.og_min, _style.og_max, _style.og_min)
		ext_total += _range_error(actuals["ibu"], _style.ibu_min, _style.ibu_max, _style.ibu_min)
		ext_total += _range_error(actuals["abv"], _style.abv_min, _style.abv_max, _style.abv_min)
		ext_components = 3
	# Carbonation deviation reads off no matter the style.
	ext_total += carb_err
	ext_components += 1
	var ext_drift: String = Grader.grade_from_drift_error(ext_total / float(max(ext_components, 1)))

	# Ceiling from per-interaction skill snapshots.
	var snapshots: Array = BrewState.skill_snapshots_so_far(_brew)
	var ceiling: String = Grader.ceiling_for_relevant_skills(
		snapshots, ["sanitation", "process", "timing", "temp_control"])

	return {
		"self":     Grader.compose_final(self_drift, ceiling),
		"external": Grader.compose_final(ext_drift, ceiling),
	}

func _range_error(actual: float, lo: float, hi: float, scale: float) -> float:
	if actual < lo:
		return (lo - actual) / max(scale, 0.001)
	if actual > hi:
		return (actual - hi) / max(scale, 0.001)
	return 0.0

func _render() -> void:
	_stage_title.text = "Pour & taste — %s" % _recipe.display_name
	_targets_label.text = "Targets: OG %.3f · FG %.3f · IBU %.0f · ABV %.1f%%" % [
		_recipe.target_og, _recipe.target_fg, _recipe.target_ibu, _recipe.target_abv,
	]
	_actual_label.text = "Actual: OG %.3f · FG %.3f · IBU %.0f · ABV %.1f%% · carb %.0f%%" % [
		_actuals["og"], _actuals["fg"], _actuals["ibu"],
		_actuals["abv"], _actuals["carbonation"] * 100.0,
	]
	_self_grade_label.text = "Self grade (vs your recipe): %s" % _self_grade
	_self_grade_label.add_theme_color_override("font_color", _grade_color(_self_grade))
	_external_grade_label.text = "External grade (vs style): %s" % _external_grade
	_external_grade_label.add_theme_color_override("font_color", _grade_color(_external_grade))

func _grade_color(grade: String) -> Color:
	match grade:
		"A+", "A":  return Color(0.55, 0.90, 0.55)
		"A-", "B":  return Color(0.85, 0.85, 0.55)
		"C":        return Color(0.95, 0.78, 0.32)
		"D":        return Color(0.95, 0.55, 0.30)
		_:          return Color(0.95, 0.35, 0.30)

func _on_drink_pressed() -> void:
	# Journal entry: the canonical "you drank it" record. SaveService
	# appends to user://journal.jsonl per 8.7.
	var journal_entry := {
		"type":                 "brew_completed",
		"day_completed":         TimeService.day_clock,
		"brew_id":               brew_id,
		"recipe_id":             _brew.get("recipe_id", ""),
		"recipe_display_name":   _recipe.display_name if _recipe else "",
		"actuals":               _actuals,
		"self_grade":            _self_grade,
		"external_grade":        _external_grade,
		"outcomes":              _brew.get("outcomes", {}),
		"risk_profile":          _brew.get("risk_profile", {}),
	}
	SaveService.append_journal_entry(journal_entry)

	# Remove brew from in-flight. The player can revisit it via the journal later.
	var brews: Array = GameState.data.get("brews_in_flight", [])
	for i in range(brews.size()):
		if String(brews[i].get("brew_id", "")) == brew_id:
			brews.remove_at(i)
			break

	# Bottle reclamation: in-use → available. Per 4.2 the design has bottles
	# returning per-NPC-interaction over time; for v1 we just lump all 24
	# back when the brew is "drunk through" (at tasting). Simpler hand-wave;
	# bottle-by-bottle drinking lands when the brew journal lands.
	var inv: Dictionary = GameState.data.get("inventory", {})
	var bottles: Dictionary = inv.get("bottles", {"available": 0, "in_use": 0})
	bottles["available"] = int(bottles.get("available", 0)) + int(bottles.get("in_use", 0))
	bottles["in_use"] = 0
	inv["bottles"] = bottles
	GameState.data["inventory"] = inv

	GameState.notify_state_loaded()
	SaveService.flush_now()
	tasting_completed.emit(brew_id)
	_return_to_dashboard()

func _on_close_pressed() -> void:
	_return_to_dashboard()

func _return_to_dashboard() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main and main.has_method("clear_active_scene"):
		main.clear_active_scene()
