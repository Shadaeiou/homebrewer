extends GutTest

## Pins the v1 → v2 migration that repairs stale saves: bootstrap fields
## (equipment.owned, recipe_knowledge.known, inventory.{ingredients,
## consumables, bottles, equipment, journal}) get topped up from the
## current bootstrap factories without overwriting earned content.
##
## Migration is now a pure dict-in / dict-out transform — by the time
## SaveService hands the result to GameState.adopt, every key is in the
## current schema shape and adopt fires state_loaded immediately.

func _stale_v1_data() -> Dictionary:
	## Mimics a save written before the bootstrap helpers landed:
	## empty owned/known/ingredients, version=1.
	return {
		"player_meta": {
			"save_format_version": 1,
			"prestige_count": 0,
			"current_destination_id": "home_town",
			"settings": {},
		},
		"cash": {"balance": 30, "outstanding_loans": [], "customer_advances": [], "recurring_bills": []},
		"skills": {
			"sanitation":   {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
			"temp_control": {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
			"timing":       {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
			"process":      {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
			"palate":       {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
			"water_chem":   {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": false},
		},
		"equipment": {"owned": {}},
		"inventory": {
			"ingredients": {},
			"bottles": {"available": 24, "in_use": 0},
			"consumables": {},
		},
		"recipe_knowledge": {"known": {}, "invented": [], "pinned_for_prestige": ""},
		"brews_in_flight": [],
		"npcs": {},
		"calendar": {"open_commitments": [], "closed_commitments": []},
		"phone_world": {
			"forum": {"threads_seen": [], "threads_posted": [], "threads_mentioned_in": []},
			"news": {"articles_seen": [], "current_trends": []},
			"social": {"follower_count": 0, "posts": []},
			"shop": {"last_browsed_items": [], "items_unlocked": []},
			"regional_water_profile_id": "default",
		},
		"rng_state": {"world_anomaly_seed": 1, "next_brew_seed": 2},
	}

# ---- Migration shape tests (operate on dicts; no GameState involvement) ----

func test_migration_repairs_empty_owned_equipment() -> void:
	var migrated: Dictionary = SaveService._migrate_if_needed(_stale_v1_data())
	# 10 starter archetypes (8 per Appendix A + bottling_bucket + auto_siphon).
	assert_eq(Dictionary(migrated["equipment"]["owned"]).size(), 10)
	assert_true(migrated["equipment"]["owned"].has("apartment_stockpot_1"))
	assert_true(migrated["equipment"]["owned"].has("bottling_bucket_1"))
	assert_true(migrated["equipment"]["owned"].has("auto_siphon_1"))

func test_migration_repairs_empty_known_recipes() -> void:
	var migrated: Dictionary = SaveService._migrate_if_needed(_stale_v1_data())
	assert_true(migrated["recipe_knowledge"]["known"].has("apartment_pale_ale"))

func test_migration_does_not_force_ingredients_on_empty_inventory() -> void:
	# After the Shop ships, the canonical fresh-career inventory is empty
	# of ingredients — the player has to buy them. Stale saves with empty
	# ingredients should stay empty after migration.
	var migrated: Dictionary = SaveService._migrate_if_needed(_stale_v1_data())
	assert_eq(Dictionary(migrated["inventory"]["ingredients"]).size(), 0,
		"empty ingredients should stay empty — shop is the canonical fill path")

func test_migration_preserves_existing_ingredients() -> void:
	var data := _stale_v1_data()
	data["inventory"]["ingredients"] = {
		"lme_light": {"name": "Light Malt Extract (LME)", "qty": 6.0, "unit": "lb"},
	}
	var migrated: Dictionary = SaveService._migrate_if_needed(data)
	assert_true(migrated["inventory"]["ingredients"].has("lme_light"))

func test_migration_tops_up_partial_known_dict() -> void:
	# A returning player who completed some recipe other than APA might
	# have a non-empty `known` that's still missing the starter. Migration
	# should add APA without stomping the existing entry.
	var data := _stale_v1_data()
	data["recipe_knowledge"]["known"]["west_coast_ipa"] = {"recipe_id": "west_coast_ipa", "times_brewed": 3}
	var migrated: Dictionary = SaveService._migrate_if_needed(data)
	var known: Dictionary = migrated["recipe_knowledge"]["known"]
	assert_true(known.has("west_coast_ipa"), "earned recipe must survive migration")
	assert_eq(int(known["west_coast_ipa"]["times_brewed"]), 3, "earned recipe data preserved")
	assert_true(known.has("apartment_pale_ale"), "missing starter must be added")

func test_migration_tolerates_null_known() -> void:
	# Defensive — a malformed save where `known` is null instead of {}
	# shouldn't crash the load path.
	var data := _stale_v1_data()
	data["recipe_knowledge"]["known"] = null
	var migrated: Dictionary = SaveService._migrate_if_needed(data)
	assert_true(migrated["recipe_knowledge"]["known"].has("apartment_pale_ale"))

func test_migration_bumps_save_format_version() -> void:
	var migrated: Dictionary = SaveService._migrate_if_needed(_stale_v1_data())
	assert_eq(int(migrated["player_meta"]["save_format_version"]), 2,
		"save_format_version must reflect the post-migration schema")

func test_migration_is_idempotent_on_current_version() -> void:
	# A v2 save run through migration shouldn't change.
	var data: Dictionary = _stale_v1_data()
	var first: Dictionary = SaveService._migrate_if_needed(data)
	var equipment_size_before: int = first["equipment"]["owned"].size()
	var second: Dictionary = SaveService._migrate_if_needed(first)
	assert_eq(int(second["player_meta"]["save_format_version"]), 2)
	assert_eq(second["equipment"]["owned"].size(), equipment_size_before,
		"second pass must not add duplicates")

func test_migration_leaves_future_version_alone() -> void:
	# A save claiming a newer version than this build understands should
	# load as-is rather than be silently downgraded.
	var data := _stale_v1_data()
	data["player_meta"]["save_format_version"] = 99
	var migrated: Dictionary = SaveService._migrate_if_needed(data)
	assert_eq(int(migrated["player_meta"]["save_format_version"]), 99,
		"future-version saves keep their version field; we don't downgrade")

# ---- Adopt fires state_loaded immediately (no longer split) ----

func test_adopt_fires_state_loaded_immediately() -> void:
	# Prior bug pattern: adopt was silent and a separate notify_state_loaded
	# call had to happen post-reseed, or UI rendered against unmigrated
	# state. After the migration refactor, migration is pre-adopt, so adopt
	# can — and must — fire the signal itself.
	var saw_apa_in_known: Array = [false]
	var on_loaded: Callable = func():
		saw_apa_in_known[0] = GameState.data["recipe_knowledge"]["known"].has("apartment_pale_ale")
	GameState.state_loaded.connect(on_loaded)
	var migrated: Dictionary = SaveService._migrate_if_needed(_stale_v1_data())
	GameState.adopt(migrated)
	assert_true(saw_apa_in_known[0],
		"adopt with migrated data must fire state_loaded with the new tree visible")
	GameState.state_loaded.disconnect(on_loaded)

func test_post_migration_start_brewing_blocks_on_ingredients() -> void:
	# Pins the canonical Appendix A trade-off: a fresh career with empty
	# ingredients can't start brewing until the player shops.
	var migrated: Dictionary = SaveService._migrate_if_needed(_stale_v1_data())
	GameState.adopt(migrated)
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_true(issues.size() >= 1,
		"empty ingredients should block Start brewing; got: %s" % str(issues))
	var joined: String = " ".join(issues.map(func(s): return String(s)))
	assert_string_contains(joined, "Need")
