class_name Grading
extends RefCounted

## Turns a finished BrewSession into an A+/A/B/C/D/F grade plus a short
## summary line describing why.
##
## The model is intentionally simple right now: take five core metrics
## (volume, OG, IBU, ABV, infection), score each as a relative error
## against the recipe target, weight them, and bucket the total.
##
## When real mini-games replace placeholders, the inputs change but this
## function doesn't — outcomes flow in via `session.outcomes`.

const WEIGHTS := {
	"volume": 0.15,
	"og": 0.25,
	"ibu": 0.20,
	"abv": 0.20,
	"infection": 0.20,
}

# Total weighted error -> grade. Lower is better.
const GRADE_BUCKETS := [
	{"grade": "A+", "max_error": 0.05},
	{"grade": "A",  "max_error": 0.10},
	{"grade": "B",  "max_error": 0.20},
	{"grade": "C",  "max_error": 0.35},
	{"grade": "D",  "max_error": 0.55},
]

static func compute(session) -> Dictionary:
	var recipe: Dictionary = session.recipe
	var outcomes: Dictionary = session.outcomes

	var prepare: Dictionary = outcomes.get("prepare", {})
	var mash: Dictionary = outcomes.get("mash", {})
	var boil: Dictionary = outcomes.get("boil", {})
	var cool: Dictionary = outcomes.get("cool", {})
	var pitch: Dictionary = outcomes.get("pitch", {})
	var ferment: Dictionary = outcomes.get("ferment", {})
	var bottle: Dictionary = outcomes.get("bottle", {})
	var condition: Dictionary = outcomes.get("condition", {})

	# ----- Volume -----
	var actual_volume_l: float = float(prepare.get("water_l", 0.0))
	var target_volume_l: float = float(recipe.get("target_volume_l", 4.0))
	var volume_error: float = _relative_error(actual_volume_l, target_volume_l)

	# ----- Original gravity (rough model) -----
	# Assume base OG comes from recipe, modulated by mash efficiency and
	# actual water volume (more water -> lower OG; less efficient mash -> lower OG).
	var efficiency: float = float(mash.get("efficiency", 0.72))
	var efficiency_factor: float = efficiency / 0.72
	var volume_factor: float = target_volume_l / max(actual_volume_l, 0.1)
	var og: float = 1.0 + (recipe.get("target_og", 1.050) - 1.0) * efficiency_factor * volume_factor
	var og_error: float = _relative_error(og, recipe.get("target_og", 1.050))

	# ----- IBU -----
	# If hops were on schedule and boil was full duration, IBU lands near
	# target. Otherwise scale linearly.
	var hops_on_schedule: bool = bool(boil.get("hops_on_schedule", true))
	var boiled_minutes: float = float(boil.get("boiled_minutes", recipe.get("boil_minutes", 60.0)))
	var boil_minutes_target: float = float(recipe.get("boil_minutes", 60.0))
	var ibu_factor: float = (boiled_minutes / boil_minutes_target) * (1.0 if hops_on_schedule else 0.7)
	var ibu: float = float(recipe.get("target_ibu", 35.0)) * ibu_factor
	var ibu_error: float = _relative_error(ibu, recipe.get("target_ibu", 35.0))

	# ----- ABV (from OG and yeast attenuation) -----
	var attenuation: float = float(recipe.get("yeast_attenuation", 0.75))
	# Attenuation is degraded by off-target fermentation temps
	var ferment_temp_c: float = float(ferment.get("avg_temp_c", recipe.get("ferment_temp_c", 19.0)))
	var ferment_temp_target: float = float(recipe.get("ferment_temp_c", 19.0))
	var temp_deviation: float = abs(ferment_temp_c - ferment_temp_target)
	var attenuation_actual: float = max(attenuation - temp_deviation * 0.02, 0.4)
	var fg: float = og - (og - 1.0) * attenuation_actual
	var abv: float = (og - fg) * 131.25  # standard homebrew formula
	var abv_error: float = _relative_error(abv, recipe.get("target_abv", 5.0))

	# ----- Infection -----
	var infection_risk: float = 0.0
	for stage_outcome in [cool, pitch, ferment, bottle, condition]:
		infection_risk += float(stage_outcome.get("infection_risk_added", 0.0))
	var contaminated: bool = infection_risk > 0.85

	# ----- Weighted total -----
	var infection_error: float = clampf(infection_risk, 0.0, 1.0)
	var total_error: float = (
		volume_error * WEIGHTS.volume
		+ og_error * WEIGHTS.og
		+ ibu_error * WEIGHTS.ibu
		+ abv_error * WEIGHTS.abv
		+ infection_error * WEIGHTS.infection
	)

	var grade: String = "F" if contaminated else _grade_for_error(total_error)
	var summary: String = _summary_text(
		grade, og, ibu, abv, actual_volume_l, infection_risk, contaminated
	)

	return {
		"grade": grade,
		"summary": summary,
		"og": og,
		"fg": fg,
		"ibu": ibu,
		"abv": abv,
		"volume_l": actual_volume_l,
		"infection_risk": infection_risk,
		"contaminated": contaminated,
	}

static func _relative_error(actual: float, target: float) -> float:
	if absf(target) < 0.0001:
		return 0.0 if absf(actual) < 0.0001 else 1.0
	return absf(actual - target) / absf(target)

static func _grade_for_error(e: float) -> String:
	for bucket in GRADE_BUCKETS:
		if e <= bucket.max_error:
			return bucket.grade
	return "F"

static func _summary_text(
	grade: String,
	og: float,
	ibu: float,
	abv: float,
	volume_l: float,
	infection_risk: float,
	contaminated: bool,
) -> String:
	if contaminated:
		return "Infected. Down the drain."
	var parts := PackedStringArray()
	parts.append("OG %.3f" % og)
	parts.append("IBU %.0f" % ibu)
	parts.append("ABV %.1f%%" % abv)
	parts.append("%.1f L" % volume_l)
	if infection_risk > 0.4:
		parts.append("(funky finish)")
	return " · ".join(parts)
