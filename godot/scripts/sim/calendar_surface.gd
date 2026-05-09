class_name CalendarSurface
extends RefCounted

## CalendarSurface — per-day surfacing helper per DESIGN.md 4.7 + 7.5.
##
## The calendar lives in GameState.data["calendar"]. This helper computes:
##   - which open commitments to mention in the morning summary (T-3 days)
##   - which to promote to checklist line items (T-1 days)
##   - which to flag as top-level dashboard prompts (T-0)
## And processes missed commitments (deadline passed, no action) into
## consequence records the caller applies.
##
## Pure-data, no Node dependencies.

const T_MINUS_MORNING := 3
const T_MINUS_CHECKLIST := 1
const T_DEADLINE := 0

static func surfacing_for_day(day: int, calendar: Dictionary) -> Dictionary:
	var morning_mentions: Array = []
	var checklist_items: Array = []
	var dashboard_prompt: Dictionary = {}
	for c in calendar.get("open_commitments", []):
		var deadline: int = int(c.get("deadline_day", 0))
		var until: int = deadline - day
		if until == T_DEADLINE:
			# T-0 takes precedence; surface as dashboard top prompt.
			if dashboard_prompt.is_empty():
				dashboard_prompt = c
		elif until == T_MINUS_CHECKLIST:
			checklist_items.append(c)
		elif until == T_MINUS_MORNING:
			morning_mentions.append(c)
	return {
		"morning_mentions": morning_mentions,
		"checklist_items": checklist_items,
		"dashboard_prompt": dashboard_prompt,
	}

static func process_missed_commitments(day: int, calendar: Dictionary) -> Array:
	## Returns the list of consequence records for any commitments whose
	## deadline_day < `day` and which are still open. Caller is responsible
	## for applying these (mutating calendar.open_commitments → closed_commitments,
	## adjusting cash, relationships, reputation per type).
	var consequences: Array = []
	for c in calendar.get("open_commitments", []):
		if int(c.get("deadline_day", 0)) >= day:
			continue
		consequences.append(_consequence_for(c))
	return consequences

static func _consequence_for(commitment: Dictionary) -> Dictionary:
	## Per 4.7's five commitment types. Numbers are TBD per playtest.
	var type_id: String = String(commitment.get("type", ""))
	var counterparty: String = String(commitment.get("counterparty_npc_id", ""))
	var cash_delta: int = 0
	var relationship_delta: float = 0.0
	var reputation_delta: float = 0.0
	var description := ""
	match type_id:
		"social":
			relationship_delta = -0.05
			description = "skipped %s's event" % counterparty
		"friend_order":
			# Cash forgone = the would-be sale. Tunable in Section 5.
			cash_delta = 0
			relationship_delta = -0.10
			description = "missed %s's order delivery" % counterparty
		"customer_advance":
			cash_delta = -int(commitment.get("amount_advance", 0))  # clawback
			relationship_delta = -0.15
			reputation_delta = -0.05
			description = "missed customer-advance delivery"
		"bar_account":
			cash_delta = -int(commitment.get("amount_advance", 0))
			relationship_delta = -0.20
			reputation_delta = -0.15
			description = "missed bar-account delivery (account at risk)"
		"competition_entry":
			# Entry fee already paid; just a forfeit, no further loss.
			description = "competition entry forfeited"
		_:
			description = "unknown commitment type missed: %s" % type_id
	return {
		"commitment_id": commitment.get("commitment_id", ""),
		"type": type_id,
		"cash_delta": cash_delta,
		"relationship_delta": relationship_delta,
		"reputation_delta": reputation_delta,
		"description": description,
	}
