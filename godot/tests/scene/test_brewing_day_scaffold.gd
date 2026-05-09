extends GutTest

## Pins the brewing-day scaffold per HANDOFF.md step 5: stage list derived
## from recipe.method, current stage advances on `minigame_completed`,
## brew transitions to FERMENTING after the last stage.

const SCENE := preload("res://scenes/brewing_day.tscn")

func _make_demo_brew() -> Dictionary:
	# Mirrors what step 6's "Start brewing" button will do.
	GameState.reset_to_new_career()
	var brew := BrewState.make_new(
		"brew_test_1",
		"apartment_pale_ale",
		{},
		TimeService.day_clock,
		12345,
	)
	GameState.data["brews_in_flight"].append(brew)
	return brew

func _mount_with_brew(brew_id: String) -> Control:
	var instance: Control = SCENE.instantiate()
	instance.brew_id = brew_id
	add_child_autofree(instance)
	return instance

func test_extract_recipe_gets_seven_stages() -> void:
	_make_demo_brew()
	var s := _mount_with_brew("brew_test_1")
	await wait_frames(1)
	assert_eq(s._stages.size(), 7, "Apartment Pale Ale (EXTRACT) → 7 stages")
	assert_eq(String(s._stages[0]["id"]), "sanitize")
	assert_eq(String(s._stages[6]["id"]), "transfer_pitch")
	assert_eq(s._current_stage_index, 0)

func test_minigame_completed_advances_stage() -> void:
	_make_demo_brew()
	var s := _mount_with_brew("brew_test_1")
	await wait_frames(1)
	assert_eq(s._current_stage_index, 0)
	# Synthesize an outcome the way placeholder_minigame does.
	var fake_outcome := {
		"actual": {},
		"care_factor": 1.0,
		"risk_deltas": {},
		"xp_gained": {},
		"journal_notes": [],
		"skill_snapshot": SkillXP.snapshot(GameState.data.get("skills", {})),
	}
	s._on_minigame_completed(fake_outcome)
	await wait_frames(1)
	assert_eq(s._current_stage_index, 1)
	# The brew now has the first stage's outcome recorded.
	var brews: Array = GameState.data["brews_in_flight"]
	var brew: Dictionary = brews[0]
	assert_true(brew["outcomes"].has("sanitize"))

func test_completing_all_stages_transitions_to_fermenting() -> void:
	_make_demo_brew()
	var s := _mount_with_brew("brew_test_1")
	await wait_frames(1)
	# GDScript lambdas capture by value; box `completed` in an Array so the
	# closure can mutate it.
	var completed := [false]
	s.brew_completed.connect(func(_id): completed[0] = true)
	for _i in range(s._stages.size()):
		s._on_minigame_completed({
			"actual": {}, "care_factor": 1.0, "risk_deltas": {},
			"xp_gained": {}, "journal_notes": [],
			"skill_snapshot": {},
		})
	await wait_frames(1)
	assert_true(completed[0], "brew_completed must fire after the last stage")
	# BrewState.advance_stage should have flipped the brew to FERMENTING.
	var brews: Array = GameState.data["brews_in_flight"]
	assert_eq(String(brews[0]["stage"]), BrewState.STAGE_FERMENTING)

func test_resumes_at_first_stage_without_outcome() -> void:
	# Player completed sanitize + fill_kettle, then hit Close. Re-mounting
	# the scene with the same brew_id should pick up at "heat" (the third
	# stage, index 2 in EXTRACT_STAGES).
	GameState.reset_to_new_career()
	var brew := BrewState.make_new("brew_resume_1", "apartment_pale_ale", {}, 0, 1)
	brew["outcomes"] = {
		"sanitize":    {"actual": {}, "care_factor": 1.0, "risk_deltas": {},
			"xp_gained": {}, "journal_notes": [], "skill_snapshot": {}},
		"fill_kettle": {"actual": {}, "care_factor": 1.0, "risk_deltas": {},
			"xp_gained": {}, "journal_notes": [], "skill_snapshot": {}},
	}
	GameState.data["brews_in_flight"].append(brew)
	var s := _mount_with_brew("brew_resume_1")
	await wait_frames(1)
	# heat is index 2 (sanitize=0, fill_kettle=1, heat=2).
	assert_eq(s._current_stage_index, 2)

func test_demo_mode_renders_when_no_brew_id_passed() -> void:
	# Harness mounts the scene without a brew_id; it should fall back to
	# APA so the screenshot has something to show.
	GameState.reset_to_new_career()
	var instance: Control = SCENE.instantiate()
	# Don't set brew_id.
	add_child_autofree(instance)
	await wait_frames(1)
	assert_not_null(instance._recipe, "demo recipe should load")
	assert_eq(instance._recipe.recipe_id, "apartment_pale_ale")
	assert_eq(instance._stages.size(), 7)
