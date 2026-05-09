class_name RiskProfile
extends RefCounted

## Six-axis hidden risk accumulator per DESIGN.md 3.5.
##
## Each brew carries a RiskProfile that fills up during active stages. Players
## see qualitative warnings during play (gated by skill/equipment) and the full
## numerics in the journal post-mortem (3.5 reveal model).

const AXES := [
	"infection",
	"oxidation",
	"off_flavor_temp",
	"boil_over",
	"recipe_drift",
	"measurement_uncertainty",
]

static func make_zero() -> Dictionary:
	var d: Dictionary = {}
	for axis in AXES:
		d[axis] = 0.0
	return d

static func add_deltas(profile: Dictionary, deltas: Dictionary) -> Dictionary:
	## Returns a new dict with `profile + deltas` per axis. Doesn't mutate input.
	var out := profile.duplicate(true)
	for axis in AXES:
		var current: float = float(out.get(axis, 0.0))
		var delta: float = float(deltas.get(axis, 0.0))
		out[axis] = clampf(current + delta, 0.0, 10.0)
	return out

static func is_critical(profile: Dictionary, axis: String, threshold: float = 7.0) -> bool:
	return float(profile.get(axis, 0.0)) >= threshold
