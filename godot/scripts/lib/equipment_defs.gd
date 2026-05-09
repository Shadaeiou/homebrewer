extends Object
class_name EquipmentDefs

## Static lookup for owned equipment: display name, short description,
## and which station(s) the player can place each piece at. Drives the
## station picker UX.
##
## The picker filters items by current station — e.g., tapping the sink
## offers anything water-going (kettle, fermenter to wash). Tapping the
## closet offers items that LIVE in storage (empty fermenter when not
## fermenting, capper, siphon).

const STATION_SINK: int = 2
const STATION_STOVE: int = 3
const STATION_CLOSET: int = 0
const STATION_BOTTLING_TABLE: int = 1

## id → { display, hint, stations: [int...] }
const DEFS: Dictionary = {
	"kettle_5gal": {
		"display": "5 gal kettle",
		"hint": "Fill it, boil in it, brew in it.",
		"stations": [STATION_SINK, STATION_STOVE],
	},
	"fermenter_bucket": {
		"display": "Fermenter bucket",
		"hint": "Pitches yeast and sits in the closet.",
		"stations": [STATION_SINK, STATION_CLOSET],
	},
	"bottling_bucket": {
		"display": "Bottling bucket",
		"hint": "Used on bottling day.",
		"stations": [STATION_BOTTLING_TABLE],
	},
	"bottle_capper": {
		"display": "Bottle capper",
		"hint": "Crimps caps on day-of.",
		"stations": [STATION_BOTTLING_TABLE],
	},
	"auto_siphon": {
		"display": "Auto-siphon",
		"hint": "Transfers wort/beer between vessels.",
		"stations": [STATION_BOTTLING_TABLE, STATION_CLOSET],
	},
}

static func display(id: String) -> String:
	return String(DEFS.get(id, {}).get("display", id))

static func hint(id: String) -> String:
	return String(DEFS.get(id, {}).get("hint", ""))

static func owned_at_station(station: int) -> Array:
	## Returns equipment IDs the player owns that are compatible with
	## the given station. Order is stable (DEFS keys order).
	var equipment: Dictionary = GameState.data.get("inventory", {}).get("equipment", {})
	var result: Array = []
	for id in DEFS.keys():
		var def: Dictionary = DEFS[id]
		var stations: Array = def.get("stations", [])
		if not (station in stations):
			continue
		var owned: Dictionary = equipment.get(id, {})
		if int(owned.get("qty", 0)) > 0:
			result.append(id)
	return result
