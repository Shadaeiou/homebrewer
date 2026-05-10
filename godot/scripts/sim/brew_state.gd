class_name BrewState
extends RefCounted

## BrewState shape factory + helpers per DESIGN.md 8.6 (entity #7).
##
## Pure-data: a brew-in-flight is a Dictionary that lives in
## GameState.data["brews_in_flight"]. This class produces well-formed shapes
## and exposes a few convenience helpers; it never holds reference to the
## actual brew (no ownership).

const STAGE_BREWING_DAY := "brewing_day"
const STAGE_FERMENTING := "fermenting"
const STAGE_BOTTLED_CONDITIONING := "bottled_conditioning"

const STAGES_ORDERED := [
	STAGE_BREWING_DAY,
	STAGE_FERMENTING,
	STAGE_BOTTLED_CONDITIONING,
]

static func make_new(brew_id: String, recipe_id: String, recipe_snapshot: Dictionary, day_started: int, rng_seed: int) -> Dictionary:
	# rng_state is the brew's deterministic seed for outcome computation.
	# It's set once at creation (from GameState.rng_state.next_brew_seed)
	# and intentionally never mutated thereafter — the contract is that
	# given the same brew and the same player actions, drift / outcome
	# computations produce the same result every time. Per-brew variance
	# comes from the seed itself being randomized at creation.
	return {
		"brew_id": brew_id,
		"recipe_id": recipe_id,
		"recipe_snapshot": recipe_snapshot.duplicate(true),
		"stage": STAGE_BREWING_DAY,
		"stage_started_day": day_started,
		"days_elapsed_in_stage": 0,
		"outcomes": {},
		"risk_profile": RiskProfile.make_zero(),
		"equipment_used": [],
		"anomalies": [],
		"rng_state": rng_seed,
	}

static func record_outcome(brew: Dictionary, stage_id: String, outcome: Dictionary) -> Dictionary:
	## Returns a new brew dict with `outcome` recorded under `stage_id` and
	## risk profile updated with the outcome's `risk_deltas`. Doesn't mutate input.
	var out := brew.duplicate(true)
	var outcomes: Dictionary = out.get("outcomes", {})
	outcomes[stage_id] = outcome.duplicate(true)
	out["outcomes"] = outcomes
	var deltas: Dictionary = outcome.get("risk_deltas", {})
	out["risk_profile"] = RiskProfile.add_deltas(out.get("risk_profile", RiskProfile.make_zero()), deltas)
	return out

static func advance_stage(brew: Dictionary, new_stage: String, on_day: int) -> Dictionary:
	var out := brew.duplicate(true)
	out["stage"] = new_stage
	out["stage_started_day"] = on_day
	out["days_elapsed_in_stage"] = 0
	return out

static func skill_snapshots_so_far(brew: Dictionary) -> Array:
	## Returns the list of per-interaction skill_snapshot dicts collected
	## across all completed outcomes — input to Grader.ceiling_for_relevant_skills.
	var snaps: Array = []
	for stage_id in brew.get("outcomes", {}):
		var outcome: Dictionary = brew["outcomes"][stage_id]
		var snap: Dictionary = outcome.get("skill_snapshot", {})
		if not snap.is_empty():
			snaps.append(snap)
	return snaps
