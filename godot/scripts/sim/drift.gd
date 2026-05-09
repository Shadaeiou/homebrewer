class_name Drift
extends RefCounted

## Drift formula per DESIGN.md 3.1.
##
##   actual = target + drift
##   drift  = base_drift / (skill_factor × equipment_precision × care_factor) × randn(1.0)
##
## Multiplicative factors mean: tools, skill, and attention substitute for
## each other. Mastery + good gear + care converges on perfection.
##
## Pure-data, no Node dependencies. Caller passes a seeded RandomNumberGenerator
## so the same brew is replayable for the same save (per 8.4 deterministic
## replay).

const SKILL_FACTOR_MIN := 0.4   # zero skill
const SKILL_FACTOR_MAX := 1.0   # mastery
const EQUIP_PRECISION_MIN := 0.3
const EQUIP_PRECISION_MAX := 1.0
const CARE_FACTOR_MIN := 0.6
const CARE_FACTOR_MAX := 1.0

static func compute_actual(
	target: float,
	base_drift: float,
	skill_factor: float,
	equipment_precision: float,
	care_factor: float,
	rng: RandomNumberGenerator,
) -> float:
	var sf := clampf(skill_factor, SKILL_FACTOR_MIN, SKILL_FACTOR_MAX)
	var ep := clampf(equipment_precision, EQUIP_PRECISION_MIN, EQUIP_PRECISION_MAX)
	var cf := clampf(care_factor, CARE_FACTOR_MIN, CARE_FACTOR_MAX)
	var stddev := base_drift / (sf * ep * cf)
	return target + stddev * rng.randfn()

static func skill_factor_from_level(level: int) -> float:
	## Maps a skill level (0..30+) to a 0.4..1.0 drift factor.
	## Level 0  -> 0.4
	## Level 20+ -> 1.0
	## Linear in between. Per 3.1 + 3.4.
	var t := clampf(float(level) / 20.0, 0.0, 1.0)
	return SKILL_FACTOR_MIN + t * (SKILL_FACTOR_MAX - SKILL_FACTOR_MIN)
