class_name EquipmentArchetype
extends Resource

## EquipmentArchetype — static equipment template per DESIGN.md 3.2.
##
## Equipment is "never tier 1 or tier 2" — it's a typed dictionary of
## properties. Each archetype defines the shape; instances live in
## GameState.data["equipment"]["owned"][uuid] with their per-instance
## state (cleanliness, sanitized_at, ...).
##
## `properties` is a flexible Dictionary because each category (kettle,
## fermenter, capper, ...) carries different fields per 3.2's example
## set. Mini-game scenes read it directly: e.g. `properties["has_thermometer"]`.

@export var archetype_id: String = ""
@export var display_name: String = ""

## "kettle" | "fermenter" | "thermometer" | "capper" | "stove" | "spoon" |
## "pitcher" | "funnel" | "hydrometer" — used to look up archetypes by role.
@export var category: String = ""

## Free-form property bag. See DESIGN.md 3.2 for the per-category schema.
@export var properties: Dictionary = {}

## Default starting state for a new instance: "USED" | "CLEAN" | "SANITIZED" |
## "DIRTY". Per 3.2, the apartment stockpot starts USED ("you've cooked pasta in it").
@export var starting_state: String = "CLEAN"

## Display blurb shown on shop / inventory cards. Optional.
@export_multiline var description: String = ""
