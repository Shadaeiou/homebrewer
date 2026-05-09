extends GutTest

const SCENE := preload("res://scenes/minigames/bottling.tscn")

func _make_fermenting_brew() -> String:
	GameState.reset_to_new_career()
	var b := BrewState.make_new("brew_bottle_test", "apartment_pale_ale", {}, 0, 1)
	b["stage"] = BrewState.STAGE_FERMENTING
	b["days_elapsed_in_stage"] = 5
	GameState.data["brews_in_flight"].append(b)
	return "brew_bottle_test"

func _mount(brew_id: String) -> Control:
	var s: Control = SCENE.instantiate()
	s.brew_id = brew_id
	add_child_autofree(s)
	return s

func test_confirm_advances_brew_to_conditioning() -> void:
	var brew_id := _make_fermenting_brew()
	var s := _mount(brew_id)
	await wait_frames(1)
	s._on_confirm_pressed()
	await wait_frames(1)
	var brew: Dictionary = GameState.data["brews_in_flight"][0]
	assert_eq(String(brew["stage"]), BrewState.STAGE_BOTTLED_CONDITIONING)
	assert_eq(int(brew["days_elapsed_in_stage"]), 0,
		"days_elapsed resets when stage advances")
	assert_true(brew["outcomes"].has("bottle"),
		"the bottling outcome should be recorded under 'bottle'")

func test_confirm_moves_bottles_into_in_use() -> void:
	var brew_id := _make_fermenting_brew()
	var s := _mount(brew_id)
	await wait_frames(1)
	s._on_confirm_pressed()
	await wait_frames(1)
	var bottles: Dictionary = GameState.data["inventory"]["bottles"]
	assert_eq(int(bottles["available"]), 0)
	assert_eq(int(bottles["in_use"]), 24)

func test_splashy_fill_adds_oxidation() -> void:
	var brew_id := _make_fermenting_brew()
	var s := _mount(brew_id)
	await wait_frames(1)
	s._selected_fill = "splashy"
	s._on_confirm_pressed()
	await wait_frames(1)
	var brew: Dictionary = GameState.data["brews_in_flight"][0]
	var risk: Dictionary = brew["outcomes"]["bottle"]["risk_deltas"]
	assert_gt(float(risk.get("oxidation", 0.0)), 2.0)

func test_skip_priming_zeroes_carbonation() -> void:
	var brew_id := _make_fermenting_brew()
	var s := _mount(brew_id)
	await wait_frames(1)
	s._selected_priming = "skip"
	s._on_confirm_pressed()
	await wait_frames(1)
	var brew: Dictionary = GameState.data["brews_in_flight"][0]
	assert_almost_eq(float(brew["outcomes"]["bottle"]["actual"]["carbonation_factor"]), 0.0, 1e-6)

func test_outcome_satisfies_universal_contract() -> void:
	var brew_id := _make_fermenting_brew()
	var s := _mount(brew_id)
	await wait_frames(1)
	s._on_confirm_pressed()
	await wait_frames(1)
	var outcome: Dictionary = GameState.data["brews_in_flight"][0]["outcomes"]["bottle"]
	assert_eq(Outcome.lint(outcome).size(), 0)
