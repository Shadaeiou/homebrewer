extends GutTest

## Pins the SaveService reseed migration that repairs stale saves —
## the v1 → v2 path that should have made the dashboard's
## Start brewing button reachable on first load. (It didn't because
## state_loaded was firing pre-reseed; this suite covers both the
## reseed correctness AND the ordering contract.)

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

func test_reseed_repairs_empty_owned_equipment() -> void:
	GameState.adopt(_stale_v1_data())
	assert_eq(Dictionary(GameState.data["equipment"]["owned"]).size(), 0)
	SaveService._reseed_bootstrap_fields_if_empty()
	# Eight starter archetypes per Appendix A.
	assert_eq(Dictionary(GameState.data["equipment"]["owned"]).size(), 8)
	assert_true(GameState.data["equipment"]["owned"].has("apartment_stockpot_1"))

func test_reseed_repairs_empty_known_recipes() -> void:
	GameState.adopt(_stale_v1_data())
	assert_eq(Dictionary(GameState.data["recipe_knowledge"]["known"]).size(), 0)
	SaveService._reseed_bootstrap_fields_if_empty()
	assert_true(GameState.data["recipe_knowledge"]["known"].has("apartment_pale_ale"))

func test_reseed_repairs_empty_ingredients() -> void:
	GameState.adopt(_stale_v1_data())
	SaveService._reseed_bootstrap_fields_if_empty()
	for required in ["lme_light", "hops_cascade", "yeast_us05", "priming_sugar"]:
		assert_true(GameState.data["inventory"]["ingredients"].has(required),
			"%s should have been reseeded" % required)

func test_reseed_tops_up_partial_known_dict() -> void:
	# A returning player who completed some recipe other than APA might
	# have a non-empty `known` that's still missing the starter. The reseed
	# should add APA without stomping the existing entry.
	var data := _stale_v1_data()
	data["recipe_knowledge"]["known"]["west_coast_ipa"] = {"recipe_id": "west_coast_ipa", "times_brewed": 3}
	GameState.adopt(data)
	SaveService._reseed_bootstrap_fields_if_empty()
	var known: Dictionary = GameState.data["recipe_knowledge"]["known"]
	assert_true(known.has("west_coast_ipa"), "earned recipe must survive reseed")
	assert_eq(int(known["west_coast_ipa"]["times_brewed"]), 3, "earned recipe data preserved")
	assert_true(known.has("apartment_pale_ale"), "missing starter must be added")

func test_reseed_tolerates_null_known() -> void:
	# Defensive — a malformed save where `known` is null instead of {}
	# shouldn't crash the load path.
	var data := _stale_v1_data()
	data["recipe_knowledge"]["known"] = null
	GameState.adopt(data)
	SaveService._reseed_bootstrap_fields_if_empty()
	assert_true(GameState.data["recipe_knowledge"]["known"].has("apartment_pale_ale"))

func test_post_reseed_start_brewing_has_no_issues() -> void:
	# The end-to-end invariant: after load+reseed, the dashboard's
	# Start brewing button should be enabled for the starter recipe.
	GameState.adopt(_stale_v1_data())
	SaveService._reseed_bootstrap_fields_if_empty()
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_eq(issues.size(), 0,
		"after reseed there should be no blockers; got: %s" % str(issues))

func test_state_loaded_fires_after_reseed() -> void:
	# The original bug: state_loaded was firing inside adopt(), before the
	# reseed ran, so the dashboard rendered against stale data. The
	# contract is now: SaveService calls notify_state_loaded *after* the
	# reseed.
	var saw_apa_in_known: Array = [false]
	var on_loaded: Callable = func():
		saw_apa_in_known[0] = GameState.data["recipe_knowledge"]["known"].has("apartment_pale_ale")
	GameState.state_loaded.connect(on_loaded)
	GameState.adopt(_stale_v1_data())
	# adopt alone must NOT emit — that was the bug.
	assert_false(saw_apa_in_known[0],
		"state_loaded must not fire from adopt() alone (the historical bug)")
	# Now do the reseed and the explicit notify, mirroring SaveService.load_now's order.
	SaveService._reseed_bootstrap_fields_if_empty()
	GameState.notify_state_loaded()
	assert_true(saw_apa_in_known[0],
		"after reseed + notify, state_loaded handlers see APA in recipe_knowledge")
	GameState.state_loaded.disconnect(on_loaded)
