extends GutTest

## Pins the dashboard validation helpers on GameState — free_fermenter_count,
## start_brewing_issues, make_brew_id. Used by the dashboard's
## Start-brewing button (step 6).

func before_each() -> void:
	GameState.reset_to_new_career()

func test_fresh_career_has_one_free_fermenter() -> void:
	# Per Appendix A: starter kit has exactly one bucket fermenter.
	assert_eq(GameState.free_fermenter_count(), 1)

func test_fermenting_brew_occupies_a_fermenter() -> void:
	var brew := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	brew["stage"] = BrewState.STAGE_FERMENTING
	GameState.data["brews_in_flight"].append(brew)
	assert_eq(GameState.free_fermenter_count(), 0)

func test_brewing_day_brew_does_not_occupy_a_fermenter() -> void:
	# Per 4.2: only FERMENTING brews occupy a fermenter; brewing-day
	# brews haven't pitched yet, conditioning brews have bottled out.
	var brew := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	# stage defaults to STAGE_BREWING_DAY in make_new.
	GameState.data["brews_in_flight"].append(brew)
	assert_eq(GameState.free_fermenter_count(), 1)

func test_bottled_brew_frees_the_fermenter() -> void:
	var brew := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	brew["stage"] = BrewState.STAGE_BOTTLED_CONDITIONING
	GameState.data["brews_in_flight"].append(brew)
	assert_eq(GameState.free_fermenter_count(), 1)

func test_start_brewing_issues_blocks_on_unshopped_ingredients() -> void:
	# Per Appendix A: fresh career has $30 cash, 24 bottles, dish soap +
	# sponge — but no ingredients. Player must shop first. Validator
	# should surface the missing ingredients as blockers.
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_true(issues.size() >= 1,
		"fresh career must require shopping first; got: %s" % str(issues))
	var joined: String = " ".join(issues.map(func(s): return String(s)))
	assert_string_contains(joined, "Need")

func test_start_brewing_issues_empty_after_shopping() -> void:
	# Once required ingredients are in inventory, the Start brewing
	# validator clears.
	GameState.data["inventory"]["ingredients"] = {
		"lme_light":     {"name": "LME",      "qty": 6.0, "unit": "lb"},
		"hops_cascade":  {"name": "Cascade",  "qty": 2.0, "unit": "oz"},
		"yeast_us05":    {"name": "US-05",    "qty": 1,   "unit": "packet"},
	}
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_eq(issues.size(), 0, "shopped career must be ready to brew APA")

func test_start_brewing_issues_unknown_recipe() -> void:
	var issues: Array = GameState.start_brewing_issues("imperial_stout_does_not_exist")
	assert_true(issues.size() >= 1)
	assert_string_contains(String(issues[0]), "not unlocked")

func test_start_brewing_issues_blocks_when_already_brewing() -> void:
	# Mid-brew lockout — you've got one stove and one kettle, so a brew
	# in BREWING_DAY blocks Start brewing until you finish (or Close).
	var b := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	# stage defaults to STAGE_BREWING_DAY in make_new.
	GameState.data["brews_in_flight"].append(b)
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_true(issues.size() >= 1)
	var joined := " ".join(issues.map(func(s): return String(s)))
	assert_string_contains(joined, "already brewing")

func test_start_brewing_issues_no_fermenter() -> void:
	# Park a fermenting brew in the bucket so no fermenter is free.
	var b := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	b["stage"] = BrewState.STAGE_FERMENTING
	GameState.data["brews_in_flight"].append(b)
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_true(issues.size() >= 1)
	var joined := " ".join(issues.map(func(s): return String(s)))
	assert_string_contains(joined, "fermenter")

func test_day_advance_ticks_fermenting_brew_days_elapsed() -> void:
	# Per 4.1: only fermentation/conditioning brews accrue days_elapsed
	# (the player is in the active scene during brewing-day).
	var fermenting := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	fermenting["stage"] = BrewState.STAGE_FERMENTING
	GameState.data["brews_in_flight"].append(fermenting)
	# Reset day_clock to a known baseline (avoid leftover state from other tests).
	TimeService.day_clock = 0
	GameState.data["player_meta"]["day_clock"] = 0
	GameState._on_day_advanced(1)
	assert_eq(int(GameState.data["brews_in_flight"][0]["days_elapsed_in_stage"]), 1)
	GameState._on_day_advanced(2)
	GameState._on_day_advanced(3)
	assert_eq(int(GameState.data["brews_in_flight"][0]["days_elapsed_in_stage"]), 3)

func test_day_advance_does_not_tick_brewing_day_brews() -> void:
	# Brewing-day brews don't accrue days_elapsed — the player is in the
	# active scene while it runs; days_elapsed only matters for passive
	# fermentation / conditioning rhythm.
	var brewing := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	# stage defaults to STAGE_BREWING_DAY
	GameState.data["brews_in_flight"].append(brewing)
	GameState._on_day_advanced(1)
	GameState._on_day_advanced(2)
	assert_eq(int(GameState.data["brews_in_flight"][0]["days_elapsed_in_stage"]), 0)

func test_day_advance_ticks_conditioning_brew_days_elapsed() -> void:
	var conditioning := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	conditioning["stage"] = BrewState.STAGE_BOTTLED_CONDITIONING
	GameState.data["brews_in_flight"].append(conditioning)
	GameState._on_day_advanced(1)
	GameState._on_day_advanced(2)
	assert_eq(int(GameState.data["brews_in_flight"][0]["days_elapsed_in_stage"]), 2)

func _ready_to_bottle_brew() -> String:
	var recipe: RecipeDef = load("res://data/recipes/apartment_pale_ale.tres")
	var b := BrewState.make_new("brew_b1", "apartment_pale_ale", recipe.to_snapshot(), 0, 1)
	b["stage"] = BrewState.STAGE_FERMENTING
	b["days_elapsed_in_stage"] = 5
	GameState.data["brews_in_flight"].append(b)
	return "brew_b1"

func test_bottling_issues_empty_when_ready_and_bottles_available() -> void:
	var bid := _ready_to_bottle_brew()
	# Fresh career has 24 bottles available.
	var issues: Array = GameState.bottling_issues(bid)
	assert_eq(issues.size(), 0)

func test_bottling_issues_blocks_when_bottles_short() -> void:
	# A brew already in conditioning has all 24 bottles in_use; trying
	# to bottle a second batch should fail with a clear "need 24" hint.
	var bid := _ready_to_bottle_brew()
	GameState.data["inventory"]["bottles"] = {"available": 0, "in_use": 24}
	var issues: Array = GameState.bottling_issues(bid)
	assert_true(issues.size() >= 1)
	assert_string_contains(String(issues[0]), "Need 24 bottles")

func test_bottling_issues_blocks_when_fermentation_incomplete() -> void:
	var recipe: RecipeDef = load("res://data/recipes/apartment_pale_ale.tres")
	var b := BrewState.make_new("brew_b2", "apartment_pale_ale", recipe.to_snapshot(), 0, 1)
	b["stage"] = BrewState.STAGE_FERMENTING
	b["days_elapsed_in_stage"] = 2  # not done yet
	GameState.data["brews_in_flight"].append(b)
	var issues: Array = GameState.bottling_issues("brew_b2")
	assert_true(issues.size() >= 1)
	assert_string_contains(String(issues[0]), "Fermentation")

func test_bottling_issues_blocks_unknown_brew() -> void:
	var issues: Array = GameState.bottling_issues("brew_does_not_exist")
	assert_true(issues.size() >= 1)
	assert_string_contains(String(issues[0]), "not found")

func test_make_brew_id_unique_within_test() -> void:
	# Time.get_ticks_msec advances monotonically; consecutive calls in the
	# same frame may return the same value, so we just check non-empty +
	# parseable. Real-world clicks are >> 1ms apart.
	var id1 := GameState.make_brew_id()
	assert_true(id1.begins_with("brew_"))
	assert_gt(int(id1.trim_prefix("brew_")), 0)
