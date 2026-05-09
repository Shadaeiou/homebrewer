class_name RecipeDef
extends Resource

## RecipeDef — static recipe definition per DESIGN.md 3.6.
##
## Recipes are the *truth* the player's self-grade compares against.
## The canonical style profile (in StyleProfile) is what external
## graders use; the two channels are independent (per 3.6).
##
## Stored as .tres files under res://data/recipes/.

@export var recipe_id: String = ""
@export var display_name: String = ""

## BJCP-ish style identifier (matches a StyleProfile.style_id).
@export var style: String = ""

## "EXTRACT" | "PARTIAL_MASH" | "ALL_GRAIN" — per 3.8.
@export var method: String = "EXTRACT"

@export var batch_size_gal: float = 5.0
@export var boil_volume_gal: float = 2.5
@export var boil_minutes: int = 60

## Targets (single values; ranges live on StyleProfile).
@export var target_og: float = 1.045
@export var target_fg: float = 1.012
@export var target_ibu: float = 30.0
@export var target_srm: float = 8.0
@export var target_abv: float = 4.5

## fermentables: [{ item: String, weight_lb: float }, ...]
@export var fermentables: Array[Dictionary] = []

## hop_schedule: [{ item: String, weight_oz: float, minutes_remaining: int }, ...]
@export var hop_schedule: Array[Dictionary] = []

## yeast: { item: String, attenuation: float, pitch_temp_c: float }
@export var yeast: Dictionary = {}

@export var fermentation_temp_c: float = 19.0
@export var fermentation_days: int = 5
@export var condition_days: int = 14
@export var priming_sugar_oz: float = 5.0

func to_snapshot() -> Dictionary:
	## Frozen copy of the recipe for BrewState.recipe_snapshot — per 8.6,
	## brews carry their own snapshot so later edits to the .tres can't
	## retroactively change in-flight brew targets.
	return {
		"recipe_id": recipe_id,
		"display_name": display_name,
		"style": style,
		"method": method,
		"batch_size_gal": batch_size_gal,
		"boil_volume_gal": boil_volume_gal,
		"boil_minutes": boil_minutes,
		"target_og": target_og,
		"target_fg": target_fg,
		"target_ibu": target_ibu,
		"target_srm": target_srm,
		"target_abv": target_abv,
		"fermentables": fermentables.duplicate(true),
		"hop_schedule": hop_schedule.duplicate(true),
		"yeast": yeast.duplicate(true),
		"fermentation_temp_c": fermentation_temp_c,
		"fermentation_days": fermentation_days,
		"condition_days": condition_days,
		"priming_sugar_oz": priming_sugar_oz,
	}
