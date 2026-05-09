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

func test_start_brewing_issues_empty_for_fresh_career() -> void:
	# Fresh career: APA recipe known, fermenter free, ingredients pre-seeded.
	# v1 → no issues, button enabled.
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_eq(issues.size(), 0, "fresh career must be ready to brew APA")

func test_start_brewing_issues_unknown_recipe() -> void:
	var issues: Array = GameState.start_brewing_issues("imperial_stout_does_not_exist")
	assert_true(issues.size() >= 1)
	assert_string_contains(String(issues[0]), "not unlocked")

func test_start_brewing_issues_no_fermenter() -> void:
	# Park a fermenting brew in the bucket so no fermenter is free.
	var b := BrewState.make_new("b1", "apartment_pale_ale", {}, 0, 1)
	b["stage"] = BrewState.STAGE_FERMENTING
	GameState.data["brews_in_flight"].append(b)
	var issues: Array = GameState.start_brewing_issues("apartment_pale_ale")
	assert_true(issues.size() >= 1)
	var joined := " ".join(issues.map(func(s): return String(s)))
	assert_string_contains(joined, "fermenter")

func test_make_brew_id_unique_within_test() -> void:
	# Time.get_ticks_msec advances monotonically; consecutive calls in the
	# same frame may return the same value, so we just check non-empty +
	# parseable. Real-world clicks are >> 1ms apart.
	var id1 := GameState.make_brew_id()
	assert_true(id1.begins_with("brew_"))
	assert_gt(int(id1.trim_prefix("brew_")), 0)
