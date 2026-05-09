class_name Outcome
extends RefCounted

## Outcome dict contract per DESIGN.md 3.9 "Mini-game scaffolding (universal)".
##
## Every mini-game scene must emit `minigame_completed(outcome)` where
## `outcome` is a Dictionary with exactly these keys:
##
##   actual          Dictionary  Stage-specific recorded values (e.g.
##                               {"water_volume_gal": 2.42, "method": "pitcher"}
##                               for fill_kettle).
##   care_factor     float       0.6..1.0 from CareFactor.from_breadth.
##   risk_deltas     Dictionary  Per-axis additions to the brew's
##                               risk_profile (subset of RiskProfile.AXES).
##   xp_gained       Dictionary  Per-axis XP awards keyed by SkillXP.SKILL_AXES.
##   journal_notes   Array       Strings — what the player did, written for
##                               the post-mortem journal.
##   skill_snapshot  Dictionary  SkillXP.snapshot(skills) at the moment the
##                               mini-game executed, for grade-ceiling math
##                               (Grader.ceiling_for_relevant_skills).

const REQUIRED_KEYS := [
	"actual",
	"care_factor",
	"risk_deltas",
	"xp_gained",
	"journal_notes",
	"skill_snapshot",
]

static func lint(outcome: Dictionary) -> Array:
	## Returns a list of issues with `outcome`. Empty array → contract OK.
	var issues: Array = []
	for k in REQUIRED_KEYS:
		if not outcome.has(k):
			issues.append("missing key: %s" % k)
	if outcome.has("actual") and not (outcome["actual"] is Dictionary):
		issues.append("actual must be Dictionary, got %s" % typeof(outcome["actual"]))
	if outcome.has("care_factor"):
		var cf: float = float(outcome["care_factor"])
		if cf < 0.6 - 0.001 or cf > 1.0 + 0.001:
			issues.append("care_factor out of [0.6, 1.0]: %f" % cf)
	if outcome.has("risk_deltas") and not (outcome["risk_deltas"] is Dictionary):
		issues.append("risk_deltas must be Dictionary")
	if outcome.has("xp_gained") and not (outcome["xp_gained"] is Dictionary):
		issues.append("xp_gained must be Dictionary")
	if outcome.has("journal_notes") and not (outcome["journal_notes"] is Array):
		issues.append("journal_notes must be Array")
	if outcome.has("skill_snapshot") and not (outcome["skill_snapshot"] is Dictionary):
		issues.append("skill_snapshot must be Dictionary")
	return issues
