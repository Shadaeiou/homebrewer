extends Object
class_name EquipmentDefs

## Maps equipment categories to the apartment stations where they fit, and
## holds the one-line picker hint shown when listing them. Display names
## come from the EquipmentArchetype itself (`display_name`) so the picker
## says "Apartment Stockpot" instead of a generic "5 gal kettle" — the
## label is tied to the specific instance, the fit logic stays per-category.
##
## Single source of truth: `equipment.owned[uuid]` per DESIGN.md §8.6.
## There is no parallel `inventory.equipment` mirror anymore.
##
## Categories not listed in CATEGORY_FITS_STATIONS are filtered out of every
## picker — that's how fixed infrastructure (stove) and small tools (spoon,
## thermometer, pitcher, funnel) stay owned but unselectable.

const CATEGORY_FITS_STATIONS: Dictionary = {
	"kettle":          [Apartment2D.STATION_SINK, Apartment2D.STATION_STOVE],
	"fermenter":       [Apartment2D.STATION_SINK, Apartment2D.STATION_CLOSET],
	"bottling_bucket": [Apartment2D.STATION_BOTTLING_TABLE],
	"capper":          [Apartment2D.STATION_BOTTLING_TABLE],
	"auto_siphon":     [Apartment2D.STATION_BOTTLING_TABLE, Apartment2D.STATION_CLOSET],
}

const CATEGORY_HINT: Dictionary = {
	"kettle":          "Fill it, boil in it, brew in it.",
	"fermenter":       "Pitches yeast and sits in the closet.",
	"bottling_bucket": "Used on bottling day.",
	"capper":          "Crimps caps on day-of.",
	"auto_siphon":     "Transfers wort/beer between vessels.",
}

static func owned_at_station(station: int) -> Array:
	## Returns archetype_ids of every owned equipment archetype whose category
	## fits the station. Deduped — even if the player owns two instances of
	## the same archetype, the picker shows one row.
	var owned: Dictionary = GameState.data.get("equipment", {}).get("owned", {})
	var result: Array = []
	var seen: Dictionary = {}
	for instance_id in owned:
		var archetype_id: String = String(owned[instance_id].get("archetype_id", ""))
		if archetype_id == "" or seen.has(archetype_id):
			continue
		var arche: EquipmentArchetype = _load(archetype_id)
		if arche == null:
			continue
		var stations: Array = CATEGORY_FITS_STATIONS.get(arche.category, [])
		if station in stations:
			result.append(archetype_id)
			seen[archetype_id] = true
	return result

static func display(archetype_id: String) -> String:
	var arche: EquipmentArchetype = _load(archetype_id)
	return arche.display_name if arche != null else archetype_id

static func hint(archetype_id: String) -> String:
	var arche: EquipmentArchetype = _load(archetype_id)
	if arche == null:
		return ""
	return String(CATEGORY_HINT.get(arche.category, ""))

static func _load(archetype_id: String) -> EquipmentArchetype:
	return load("res://data/equipment/%s.tres" % archetype_id)
