extends Node

## Single source of truth for the in-app changelog.
##
## Loads `res://data/changelog.json` once at startup. CLAUDE.md rule 2:
## every commit on `main` that changes player-visible behavior must add a
## new top entry whose `version` matches the next versionName.

const SOURCE_PATH := "res://data/changelog.json"

var entries: Array = []

func _ready() -> void:
	entries = _load()

func _load() -> Array:
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	if file == null:
		push_error("Changelog source missing at %s" % SOURCE_PATH)
		return []
	var raw := file.get_as_text()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Changelog JSON did not parse to an Array")
		return []
	return parsed

func latest() -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[0]

func older() -> Array:
	if entries.size() <= 1:
		return []
	return entries.slice(1)
