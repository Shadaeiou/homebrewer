class_name CareFactor
extends RefCounted

## Care factor — breadth, not order — per DESIGN.md 3.3.
##
## Care is a continuous factor (0.6 .. 1.0) emerging from the *breadth*
## of optional sub-actions a player took during a mini-game. Order is
## NOT policed here — that's "procedure" (a separate interaction shape;
## see 3.9 + scripts/sim/procedure_violation.gd if/when that's needed).
##
## Mini-game scenes feed in:
##   - the count of optional sub-actions the player took
##   - the count of optional sub-actions available
## We compute a 0.6..1.0 factor from breadth.

const FLOOR := 0.6   # Skip everything optional → still 0.6
const CEILING := 1.0  # Take every optional sub-action → 1.0

static func from_breadth(actions_taken: int, actions_available: int) -> float:
	## Linear ramp from FLOOR to CEILING over actions_taken / actions_available.
	## Required sub-actions are not counted on either side; they're prerequisites,
	## not breadth.
	if actions_available <= 0:
		return CEILING
	var ratio := clampf(float(actions_taken) / float(actions_available), 0.0, 1.0)
	return FLOOR + ratio * (CEILING - FLOOR)
