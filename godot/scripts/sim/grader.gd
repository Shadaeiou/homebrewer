class_name Grader
extends RefCounted

## Grader per DESIGN.md 3.4 + 3.6.
##
## Two grading channels:
##   - SELF: drift between actual outcomes and the player's recipe targets
##           (journal post-mortem grade — "did I make what I intended?")
##   - EXTERNAL: drift between actual outcomes and the canonical style profile
##           (customer ratings, NPC tasting, competition scoring)
##
## Both channels are then capped by a per-axis grade ceiling derived from the
## relevant skill levels at the time of each interaction. A lucky tight roll
## cannot push a zero-skill brew past C; the ceiling is a separate function on
## top of drift, not a property of drift.

# Grade indices: higher is better. F=0 ... A+=6.
const GRADE_INDEX := {
	"F":  0,
	"D":  1,
	"C":  2,
	"B":  3,
	"A-": 4,
	"A":  5,
	"A+": 6,
}

const GRADE_LIST := ["F", "D", "C", "B", "A-", "A", "A+"]

# Per 3.4: skill level → max grade contributed.
const SKILL_LEVEL_TO_MAX_GRADE := [
	{"min_level":  0, "grade": "C"},
	{"min_level":  5, "grade": "B"},
	{"min_level": 10, "grade": "A-"},
	{"min_level": 15, "grade": "A"},
	{"min_level": 20, "grade": "A+"},
]

# Drift-to-grade buckets by total weighted error (lower is better).
# Mirrors the prior proof-of-concept Grader bands; tuned per playtest.
const DRIFT_GRADE_BUCKETS := [
	{"max_error": 0.05, "grade": "A+"},
	{"max_error": 0.10, "grade": "A"},
	{"max_error": 0.15, "grade": "A-"},
	{"max_error": 0.25, "grade": "B"},
	{"max_error": 0.40, "grade": "C"},
	{"max_error": 0.60, "grade": "D"},
]

static func grade_index(grade: String) -> int:
	return int(GRADE_INDEX.get(grade, 0))

static func grade_from_index(idx: int) -> String:
	var i: int = clampi(idx, 0, GRADE_LIST.size() - 1)
	return String(GRADE_LIST[i])

static func min_grade(a: String, b: String) -> String:
	## Returns the worse of two grades (lower index).
	if grade_index(a) <= grade_index(b):
		return a
	return b

static func max_grade_for_level(level: int) -> String:
	var best := "C"
	for entry in SKILL_LEVEL_TO_MAX_GRADE:
		if level >= int(entry["min_level"]):
			best = String(entry["grade"])
	return best

static func ceiling_for_relevant_skills(snapshots: Array, relevant_axes: Array) -> String:
	## Returns the worst max-grade across all `relevant_axes` looked up in
	## `snapshots` (a list of per-interaction skill snapshots — see 7.6).
	## Per 3.4: the brew's overall grade ceiling = min across the relevant
	## skill axes for that recipe.
	if snapshots.is_empty() or relevant_axes.is_empty():
		return "A+"
	var worst := "A+"
	for snap in snapshots:
		for axis in relevant_axes:
			var level: int = int(snap.get(axis, 0))
			var ceiling := max_grade_for_level(level)
			worst = min_grade(worst, ceiling)
	return worst

static func grade_from_drift_error(total_error: float) -> String:
	## Bucket a total weighted error to a drift-derived grade. Lower is better.
	for bucket in DRIFT_GRADE_BUCKETS:
		if total_error <= float(bucket["max_error"]):
			return String(bucket["grade"])
	return "F"

static func compose_final(drift_grade: String, ceiling_grade: String) -> String:
	## Final brew grade per 3.4: min(drift_derived_grade, brew_grade_ceiling).
	return min_grade(drift_grade, ceiling_grade)
