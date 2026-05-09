extends GutTest

## Pins the persistence contract: reset_to_new_career → serialize → parse →
## adopt produces an equivalent tree. Exercises the JSON path SaveService
## takes (8.5), without touching real disk paths.

func _serialize() -> String:
	return JSON.stringify(GameState.data, "\t")

func _parse(s: String) -> Dictionary:
	var v: Variant = JSON.parse_string(s)
	assert_true(v is Dictionary, "save must parse to a Dictionary")
	return v

func before_each() -> void:
	GameState.reset_to_new_career()

func test_fresh_career_seeds_8_starter_equipment() -> void:
	# Per Appendix A: stove + stockpot + bucket + spoon + thermometer +
	# capper + pitcher + funnel = 8 archetypes.
	var owned: Dictionary = GameState.data["equipment"]["owned"]
	assert_eq(owned.size(), 8, "8 starter equipment instances")
	for instance_id in owned.keys():
		var inst: Dictionary = owned[instance_id]
		assert_true(inst.has("archetype_id"))
		assert_true(inst.has("state"))
		assert_eq(String(inst["instance_id"]), String(instance_id))

func test_fresh_career_seeds_apartment_pale_ale_recipe() -> void:
	var known: Dictionary = GameState.data["recipe_knowledge"]["known"]
	assert_true(known.has("apartment_pale_ale"), "APA recipe must be unlocked")
	assert_eq(int(known["apartment_pale_ale"]["times_brewed"]), 0)

func test_stockpot_starts_in_used_state() -> void:
	# Per 3.2: "you've cooked pasta in it" — starting_state = USED.
	var owned: Dictionary = GameState.data["equipment"]["owned"]
	assert_true(owned.has("apartment_stockpot_1"))
	assert_eq(owned["apartment_stockpot_1"]["state"], "USED")

func test_save_round_trip_preserves_top_level_groups() -> void:
	var s := _serialize()
	var loaded := _parse(s)
	# Twelve entity groups per 8.1 (eleven here; journal lives on disk).
	for key in ["player_meta", "cash", "skills", "equipment", "inventory",
				"recipe_knowledge", "brews_in_flight", "npcs", "calendar",
				"phone_world", "rng_state"]:
		assert_true(loaded.has(key), "%s missing after round trip" % key)

func test_save_round_trip_preserves_starter_equipment_ids() -> void:
	var loaded := _parse(_serialize())
	var owned: Dictionary = loaded["equipment"]["owned"]
	assert_eq(owned.size(), 8)
	for expected_id in ["apartment_stove_1", "apartment_stockpot_1",
						"plastic_bucket_fermenter_1", "long_plastic_spoon_1",
						"bi_metal_thermometer_1", "wing_capper_1",
						"measuring_pitcher_1", "funnel_1"]:
		assert_true(owned.has(expected_id), "missing %s after round trip" % expected_id)

func test_save_round_trip_preserves_recipe_knowledge() -> void:
	var loaded := _parse(_serialize())
	assert_true(loaded["recipe_knowledge"]["known"].has("apartment_pale_ale"))

func test_save_round_trip_preserves_starter_cash() -> void:
	var loaded := _parse(_serialize())
	assert_eq(int(loaded["cash"]["balance"]), 30)

func test_save_round_trip_is_idempotent() -> void:
	# serialize → parse → adopt → serialize → parse: the two parsed dicts
	# must be deep-equal. (JSON.stringify is order-sensitive across parse
	# cycles, so we compare structured data, not raw strings.)
	var first_dict := _parse(_serialize())
	GameState.adopt(first_dict)
	var second_dict := _parse(_serialize())
	assert_eq(first_dict, second_dict, "round-trip must be a fixed point")

func test_day_clock_persists_through_round_trip() -> void:
	# Get-some-rest taps must not vanish on relaunch. The day clock now
	# rides on data["player_meta"]["day_clock"]; advance_day mirrors the
	# runtime clock into it so save_now picks it up.
	for _i in range(7):
		TimeService.advance_day()
	var loaded := _parse(_serialize())
	assert_eq(int(loaded["player_meta"]["day_clock"]), 7)
	# Round trip into a fresh state — adopt() should restore TimeService.
	GameState.adopt(loaded)
	assert_eq(TimeService.day_clock, 7,
		"adopt() must restore TimeService.day_clock from player_meta")

func test_adopt_defaults_missing_day_clock_to_zero() -> void:
	# A pre-day_clock save (no field at all) shouldn't crash; default 0.
	var stale := {"player_meta": {"save_format_version": 2}}
	GameState.adopt(stale)
	assert_eq(TimeService.day_clock, 0)

func test_save_round_trip_preserves_six_skill_axes() -> void:
	var loaded := _parse(_serialize())
	for axis in ["sanitation", "temp_control", "timing", "process", "palate", "water_chem"]:
		assert_true(loaded["skills"].has(axis))
		assert_eq(int(loaded["skills"][axis]["level"]), 0)
	# water_chem stays locked at career start per 3.4.
	assert_eq(loaded["skills"]["water_chem"]["unlocked"], false)
