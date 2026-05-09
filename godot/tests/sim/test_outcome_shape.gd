extends GutTest

## Pins the universal Outcome dict shape per DESIGN.md 3.9 + scripts/sim/outcome.gd.
##
## Every mini-game's `minigame_completed(outcome)` must satisfy Outcome.lint.

const FILL_KETTLE := preload("res://scenes/minigames/fill_kettle.tscn")

func _well_formed_outcome() -> Dictionary:
	return {
		"actual": {},
		"care_factor": 1.0,
		"risk_deltas": {},
		"xp_gained": {},
		"journal_notes": [],
		"skill_snapshot": {},
	}

func test_well_formed_outcome_passes_lint() -> void:
	assert_eq(Outcome.lint(_well_formed_outcome()).size(), 0)

func test_missing_key_is_flagged() -> void:
	for key in Outcome.REQUIRED_KEYS:
		var bad := _well_formed_outcome()
		bad.erase(key)
		var issues: Array = Outcome.lint(bad)
		assert_eq(issues.size(), 1, "exactly one issue when %s is missing" % key)
		assert_string_contains(String(issues[0]), key)

func test_care_factor_out_of_range_is_flagged() -> void:
	var bad := _well_formed_outcome()
	bad["care_factor"] = 0.5
	assert_true(Outcome.lint(bad).size() >= 1)
	bad["care_factor"] = 1.1
	assert_true(Outcome.lint(bad).size() >= 1)

func test_wrong_type_for_journal_notes_is_flagged() -> void:
	var bad := _well_formed_outcome()
	bad["journal_notes"] = "not an array"
	var issues: Array = Outcome.lint(bad)
	assert_true(issues.size() >= 1)
	assert_string_contains(String(issues[0]), "journal_notes")

func test_fill_kettle_emits_well_formed_outcome() -> void:
	GameState.reset_to_new_career()
	var fk: Control = FILL_KETTLE.instantiate()
	add_child_autofree(fk)
	await wait_frames(1)
	# Watcher to capture the outcome.
	var captured := [null]
	fk.minigame_completed.connect(func(o): captured[0] = o)
	fk._on_pour_pressed()
	await wait_frames(1)
	assert_not_null(captured[0], "fill_kettle should have emitted")
	var outcome: Dictionary = captured[0]
	var issues: Array = Outcome.lint(outcome)
	assert_eq(issues.size(), 0,
		"fill_kettle outcome must lint clean; got: %s" % str(issues))
	# Stage-specific assertions on the `actual` dict.
	assert_true(outcome["actual"].has("water_volume_gal"))
	assert_true(outcome["actual"].has("water_source"))
	assert_true(outcome["actual"].has("method"))
	# Skill snapshot covers all six axes.
	for axis in SkillXP.SKILL_AXES:
		assert_true(outcome["skill_snapshot"].has(axis))
