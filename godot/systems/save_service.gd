extends Node

## SaveService — load + save per DESIGN.md 8.5.
##
## Layout:
##   user://save.json       — main save: 11 of 12 entity groups (everything except journal)
##   user://journal.jsonl   — append-only journal of completed brews
##
## Atomic writes: write to .tmp, fsync, rename to final.
## Auto-save on:
##   - TimeService.day_advanced (the day-clock advance is a natural commit point)
##   - Active scene end (scene_clock pauses cleanly per 4.1)
##   - App backgrounded (NOTIFICATION_WM_GO_BACK_REQUEST / WM_CLOSE_REQUEST)

signal save_completed(success: bool)
signal load_completed(was_existing_save: bool)

const SAVE_PATH := "user://save.json"
const SAVE_TMP_PATH := "user://save.json.tmp"
const JOURNAL_PATH := "user://journal.jsonl"

# Migration target = the schema version GameState stamps when reset_to_new_career
# initializes player_meta. The two values must agree — read through to GameState
# rather than holding a parallel constant that can silently drift.

func _ready() -> void:
	# Wire auto-save triggers.
	TimeService.day_advanced.connect(_on_day_advanced)
	TimeService.scene_ended.connect(_on_scene_ended)
	# Load on boot. _ready order: GameState resets to fresh in its own _ready,
	# then we either replace that with disk state or keep the fresh one.
	call_deferred("load_now")

func load_now() -> void:
	## Called once at boot. If save.json exists, load + migrate + adopt it.
	## Else GameState stays at its post-_ready fresh state, and we initialize
	## a new career.
	if not FileAccess.file_exists(SAVE_PATH):
		GameState.reset_to_new_career()
		load_completed.emit(false)
		return

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[SaveService] could not open save.json for reading")
		GameState.reset_to_new_career()
		load_completed.emit(false)
		return

	var raw := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_error("[SaveService] save.json did not parse to a Dictionary; starting fresh")
		GameState.reset_to_new_career()
		load_completed.emit(false)
		return

	# Migration is a pure dict-in / dict-out transform — by the time we hand
	# the result to GameState.adopt, every key is in its current-schema shape.
	# adopt() then fires state_loaded, so UI consumers always render against
	# fully-migrated state.
	var save_dict: Dictionary = _migrate_if_needed(parsed)
	GameState.adopt(save_dict)
	load_completed.emit(true)

func save_now() -> void:
	## Atomic write: tmp -> rename. Per 8.5.
	var serialized := JSON.stringify(GameState.data, "\t")

	var tmp := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("[SaveService] could not open save.json.tmp for writing")
		save_completed.emit(false)
		return
	tmp.store_string(serialized)
	tmp.close()

	# Rename. Godot's DirAccess.rename is the atomic-on-POSIX path.
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("[SaveService] could not open user:// for rename")
		save_completed.emit(false)
		return

	var err: int = dir.rename(SAVE_TMP_PATH.trim_prefix("user://"), SAVE_PATH.trim_prefix("user://"))
	if err != OK:
		push_error("[SaveService] rename failed: %s" % err)
		save_completed.emit(false)
		return

	save_completed.emit(true)

func append_journal_entry(record: Dictionary) -> void:
	## Append-only journal write per 8.7. One JSON object per line, terminated
	## by `\n`. Power-loss mid-write truncates the partial line; next load
	## drops anything after the last well-formed `\n`-terminated record.
	var line := JSON.stringify(record) + "\n"
	var f := FileAccess.open(JOURNAL_PATH, FileAccess.READ_WRITE)
	if f == null:
		# File doesn't exist yet — create it.
		f = FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
		if f == null:
			push_error("[SaveService] could not create journal.jsonl")
			return
		f.store_string(line)
		f.close()
		return
	f.seek_end()
	f.store_string(line)
	f.close()

func read_journal() -> Array:
	## Streams the journal file line by line, parsing each as JSON. Drops
	## malformed lines (e.g., truncated tail from a power loss). Returns
	## the records in append order.
	var out: Array = []
	if not FileAccess.file_exists(JOURNAL_PATH):
		return out
	var f := FileAccess.open(JOURNAL_PATH, FileAccess.READ)
	if f == null:
		push_error("[SaveService] could not open journal.jsonl for reading")
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
		# else: silently drop a malformed/truncated line
	f.close()
	return out

func flush_now() -> void:
	## Explicit save point — for prestige, settings change, or any critical
	## moment. Same effect as save_now() today; named separately so callers
	## can express intent.
	save_now()

func wipe_and_reset() -> void:
	## Dev affordance: delete the save + journal and re-bootstrap from a
	## fresh career. UI surfaces this behind a "Reset save (dev)" button
	## while the v1 mini-games are still landing — players hit stuck states
	## (e.g., a brew stranded in FERMENTING with no bottling flow yet) and
	## need to reach a clean baseline. Removed before launch.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(SAVE_TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TMP_PATH))
	if FileAccess.file_exists(JOURNAL_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(JOURNAL_PATH))
	GameState.reset_to_new_career()

func _on_day_advanced(_new_day: int) -> void:
	save_now()

func _on_scene_ended() -> void:
	save_now()

func _notification(what: int) -> void:
	# Auto-save when the app is backgrounded or about to close.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()

func _migrate_if_needed(save_dict: Dictionary) -> Dictionary:
	## One-way-forward migration registry per DESIGN.md 8.9.
	##
	## Each migration is a function `_migrate_vN_to_vN_plus_1(save_dict) ->
	## Dictionary` that takes the dict in its v(N) shape and returns it in
	## v(N+1) shape. We walk the version chain from the save's recorded
	## version up to GameState.SAVE_FORMAT_VERSION, applying each one.
	##
	## A save newer than the current schema (player rolled back the app) is
	## loaded as-is with a warning; we don't downgrade the version field
	## because future fields would be lost silently.
	if not save_dict.has("player_meta"):
		save_dict["player_meta"] = {}
	var target_version: int = GameState.SAVE_FORMAT_VERSION
	var current_version: int = int(save_dict["player_meta"].get("save_format_version", 0))
	if current_version > target_version:
		push_warning("[SaveService] save format v%d is newer than this build (v%d); loading as-is" % [
			current_version, target_version,
		])
		return save_dict
	while current_version < target_version:
		match current_version:
			0, 1:
				save_dict = _migrate_v1_to_v2(save_dict)
			_:
				push_error("[SaveService] no migration path from v%d to v%d" % [
					current_version, current_version + 1,
				])
				return save_dict
		current_version += 1
	save_dict["player_meta"]["save_format_version"] = current_version
	return save_dict

func _migrate_v1_to_v2(save_dict: Dictionary) -> Dictionary:
	## v1 saves predate the bootstrap helpers (GameState._initial_equipment,
	## _initial_recipe_knowledge, _initial_inventory). Equipment.owned,
	## recipe_knowledge.known, and inventory keys may be empty, missing,
	## or null. Top them up from the current bootstrap WITHOUT overwriting
	## anything earned — we add missing keys, never replace.
	##
	## Defensive against `null` values where we expect a dict — players who
	## hit an old bug or hand-edited their save shouldn't be bricked.
	save_dict = _bootstrap_equipment_into(save_dict)
	save_dict = _bootstrap_recipes_into(save_dict)
	save_dict = _bootstrap_inventory_into(save_dict)
	return save_dict

func _bootstrap_equipment_into(save_dict: Dictionary) -> Dictionary:
	var equip_raw: Variant = save_dict.get("equipment", {})
	var equip: Dictionary = (equip_raw if equip_raw is Dictionary else {})
	var owned_raw: Variant = equip.get("owned", {})
	var owned: Dictionary = (owned_raw if owned_raw is Dictionary else {})
	# Each starter archetype is keyed `<archetype_id>_1` per
	# GameState._initial_equipment. If any are missing as instances,
	# top them up; never replace an existing instance.
	var bootstrap: Dictionary = GameState._initial_equipment()
	for instance_id in bootstrap:
		if not owned.has(instance_id):
			owned[instance_id] = bootstrap[instance_id]
	equip["owned"] = owned
	save_dict["equipment"] = equip
	return save_dict

func _bootstrap_recipes_into(save_dict: Dictionary) -> Dictionary:
	var knowledge_raw: Variant = save_dict.get("recipe_knowledge", {})
	var knowledge: Dictionary = (knowledge_raw if knowledge_raw is Dictionary else {})
	var known_raw: Variant = knowledge.get("known", {})
	var known: Dictionary = (known_raw if known_raw is Dictionary else {})
	var bootstrap: Dictionary = GameState._initial_recipe_knowledge()
	for recipe_id in bootstrap:
		if not known.has(recipe_id):
			known[recipe_id] = bootstrap[recipe_id]
	knowledge["known"] = known
	if not knowledge.has("invented"):
		knowledge["invented"] = []
	if not knowledge.has("pinned_for_prestige"):
		knowledge["pinned_for_prestige"] = ""
	save_dict["recipe_knowledge"] = knowledge
	return save_dict

func _bootstrap_inventory_into(save_dict: Dictionary) -> Dictionary:
	var inv_raw: Variant = save_dict.get("inventory", {})
	var inv: Dictionary = (inv_raw if inv_raw is Dictionary else {})
	var ing_raw: Variant = inv.get("ingredients", {})
	var ingredients: Dictionary = (ing_raw if ing_raw is Dictionary else {})
	var seeded: Dictionary = GameState._initial_inventory()
	for ingredient_id in seeded["ingredients"]:
		if not ingredients.has(ingredient_id):
			ingredients[ingredient_id] = seeded["ingredients"][ingredient_id]
	inv["ingredients"] = ingredients
	if not inv.has("bottles"):
		inv["bottles"] = seeded["bottles"]
	if not inv.has("consumables"):
		inv["consumables"] = seeded["consumables"]
	save_dict["inventory"] = inv
	return save_dict
