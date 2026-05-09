class_name StyleProfile
extends Resource

## StyleProfile — canonical BJCP-style guideline ranges per DESIGN.md 3.6.
##
## The *external* grading channel uses these. Customers, NPCs, and
## competition judges grade a brew's drift against the canonical style
## profile, not against the player's recipe targets. The two channels
## are independent (3.6 — a tightly-executed recipe can self-grade A+
## but external-grade B if the recipe drifted from style).
##
## Stored as .tres files under res://data/styles/.

@export var style_id: String = ""
@export var display_name: String = ""

## BJCP category text — narrative description of the style. Used in
## tasting/competition feedback strings.
@export_multiline var description: String = ""

## Numeric ranges. Lower-upper bounds bracket "in style" — drifts
## outside contribute to external-grade error.
@export var og_min: float = 0.045
@export var og_max: float = 1.060
@export var fg_min: float = 1.010
@export var fg_max: float = 1.015
@export var ibu_min: float = 30.0
@export var ibu_max: float = 50.0
@export var srm_min: float = 5.0
@export var srm_max: float = 10.0
@export var abv_min: float = 4.5
@export var abv_max: float = 6.2
