class_name SkillXP
extends RefCounted

## Skill XP curve + level-up + snapshot helpers per DESIGN.md 3.4.
##
## Level curve: early levels are fast (XP_to_next = 100); late levels are
## slow (XP_to_next ~10000+). The curve makes early progress feel responsive
## and late mastery feel earned.
##
## XP earned by a mini-game interaction is awarded *after* the outcome is
## computed, so an interaction never benefits from the XP it just produced
## (per 3.4 skill snapshots).

const SKILL_AXES := [
	"sanitation",
	"temp_control",
	"timing",
	"process",
	"palate",
	"water_chem",
]

static func xp_to_next_for_level(level: int) -> int:
	## Quadratic-ish curve: level 0 needs 100, level 10 needs ~1000,
	## level 20 needs ~4100, level 30 needs ~9100.
	if level < 0:
		return 100
	return 100 + level * level * 10

static func add_xp(skill: Dictionary, amount: int) -> Dictionary:
	## Returns a new skill dict with `amount` XP added. Levels up as many
	## times as the accumulated XP allows. Doesn't mutate input.
	var out := skill.duplicate(true)
	var level: int = int(out.get("level", 0))
	var xp: int = int(out.get("xp", 0)) + amount
	var to_next: int = int(out.get("xp_to_next", xp_to_next_for_level(level)))
	while xp >= to_next:
		xp -= to_next
		level += 1
		to_next = xp_to_next_for_level(level)
	out["level"] = level
	out["xp"] = xp
	out["xp_to_next"] = to_next
	return out

static func snapshot(skills: Dictionary) -> Dictionary:
	## Per 3.4: each mini-game interaction snapshots relevant skill levels
	## at the moment it executes. Returns {axis: level} for all six axes.
	var out: Dictionary = {}
	for axis in SKILL_AXES:
		var s: Dictionary = skills.get(axis, {})
		out[axis] = int(s.get("level", 0))
	return out

static func apply_prestige_penalty(skills: Dictionary) -> Dictionary:
	## 20% of current levels per axis, rounded down, floor 0. Per 2.4 + 8.8.
	## XP within the new level is reset to 0 (player is at the floor of the
	## new level, not partway through).
	var out: Dictionary = {}
	for axis in SKILL_AXES:
		var s: Dictionary = skills.get(axis, {}).duplicate(true)
		var old_level: int = int(s.get("level", 0))
		var new_level: int = max(0, int(floor(float(old_level) * 0.8)))
		s["level"] = new_level
		s["xp"] = 0
		s["xp_to_next"] = xp_to_next_for_level(new_level)
		out[axis] = s
	return out
