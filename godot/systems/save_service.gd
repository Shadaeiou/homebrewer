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

const CURRENT_SAVE_VERSION := 2

func _ready() -> void:
	# Wire auto-save triggers.
	TimeService.day_advanced.connect(_on_day_advanced)
	TimeService.scene_ended.connect(_on_scene_ended)
	# Load on boot. _ready order: GameState resets to fresh in its own _ready,
	# then we either replace that with disk state or keep the fresh one.
	call_deferred("load_now")

func load_now() -> void:
	## Called once at boot. If save.json exists, load + adopt it. Else GameState
	## stays at its post-_ready fresh state, and we initialize a new career.
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

	var save_dict: Dictionary = parsed
	save_dict = _migrate_if_needed(save_dict)
	GameState.adopt(save_dict)
	# Defensive: a migration may have left fields the bootstrap fills out
	# (equipment.owned, recipe_knowledge.known, inventory.ingredients) still
	# empty if the v1 save predated those bootstrap helpers landing. Top
	# them up from the bootstrap rather than wiping the player's progress.
	_reseed_bootstrap_fields_if_empty()
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

func _on_day_advanced(_new_day: int) -> void:
	save_now()

func _on_scene_ended() -> void:
	save_now()

func _notification(what: int) -> void:
	# Auto-save when the app is backgrounded or about to close.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()

func _migrate_if_needed(save_dict: Dictionary) -> Dictionary:
	## One-way-forward migration registry per 8.9.
	var pm: Dictionary = save_dict.get("player_meta", {})
	var current_version: int = int(pm.get("save_format_version", 0))
	while current_version < CURRENT_SAVE_VERSION:
		match current_version:
			0, 1:
				# v1 → v2: the bootstrap helpers (_initial_equipment, etc.)
				# weren't called when v1 saves were written, so equipment.owned,
				# recipe_knowledge.known, and inventory.ingredients are empty.
				# _reseed_bootstrap_fields_if_empty() (called after adopt)
				# fills them from the .tres archetypes without touching cash,
				# skills, brews-in-flight, or anything else the player earned.
				pass
		current_version += 1
	if not save_dict.has("player_meta"):
		save_dict["player_meta"] = {}
	save_dict["player_meta"]["save_format_version"] = CURRENT_SAVE_VERSION
	return save_dict

func _reseed_bootstrap_fields_if_empty() -> void:
	## Called after adopt(). For each field the v1 save may have left empty,
	## fill from the v2 bootstrap. Never overwrites non-empty fields, so a
	## player mid-career keeps their owned equipment / known recipes /
	## ingredient inventory.
	var equip: Dictionary = GameState.data.get("equipment", {})
	if Dictionary(equip.get("owned", {})).is_empty():
		equip["owned"] = GameState._initial_equipment()
		GameState.data["equipment"] = equip
	var knowledge: Dictionary = GameState.data.get("recipe_knowledge", {})
	if Dictionary(knowledge.get("known", {})).is_empty():
		knowledge["known"] = GameState._initial_recipe_knowledge()
		GameState.data["recipe_knowledge"] = knowledge
	var inv: Dictionary = GameState.data.get("inventory", {})
	if Dictionary(inv.get("ingredients", {})).is_empty():
		var seeded := GameState._initial_inventory()
		inv["ingredients"] = seeded["ingredients"]
		# Don't stomp bottles or consumables — those existed in v1.
		if not inv.has("consumables") or Dictionary(inv["consumables"]).is_empty():
			inv["consumables"] = seeded["consumables"]
		GameState.data["inventory"] = inv
