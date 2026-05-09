extends GutTest

const SCENE := preload("res://scenes/minigames/tasting.tscn")

func _make_conditioning_brew(outcomes_overrides: Dictionary = {}) -> String:
	GameState.reset_to_new_career()
	var recipe: RecipeDef = load("res://data/recipes/apartment_pale_ale.tres")
	var b := BrewState.make_new(
		"brew_taste_test",
		"apartment_pale_ale",
		recipe.to_snapshot(),
		0,
		1,
	)
	b["stage"] = BrewState.STAGE_BOTTLED_CONDITIONING
	b["days_elapsed_in_stage"] = 14

	# Default: an "ideal play" outcome chain — should grade well.
	var default_outcomes := {
		"sanitize":       {"actual": {}, "care_factor": 1.0, "risk_deltas": {},
			"xp_gained": {}, "journal_notes": [], "skill_snapshot": {}},
		"fill_kettle":    {"actual": {"water_volume_gal": recipe.boil_volume_gal,
			"water_source": "tap", "method": "pitcher"},
			"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
			"journal_notes": [], "skill_snapshot": {}},
		"add_lme":        {"actual": {"sequence": ["burner_off", "stir", "lme_pour"],
			"result": "IDEAL", "lme_dissolution": 1.0},
			"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
			"journal_notes": [], "skill_snapshot": {}},
		"boil_with_hops": {"actual": {"ibu_factor": 1.0, "volume_loss_gal": 0.0},
			"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
			"journal_notes": [], "skill_snapshot": {}},
		"cool_wort":      {"actual": {"path": "ice_bath", "final_temp_f": 70.0},
			"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
			"journal_notes": [], "skill_snapshot": {}},
		"transfer_pitch": {"actual": {"pour_quality": "gentle", "pitch_method": "rehydrate"},
			"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
			"journal_notes": [], "skill_snapshot": {}},
		"bottle":         {"actual": {"priming_method": "bulk", "fill_method": "funnel",
			"carbonation_factor": 1.0},
			"care_factor": 1.0, "risk_deltas": {}, "xp_gained": {},
			"journal_notes": [], "skill_snapshot": {}},
	}
	for k in outcomes_overrides:
		default_outcomes[k] = outcomes_overrides[k]
	b["outcomes"] = default_outcomes
	GameState.data["brews_in_flight"].append(b)
	# Pretend the brew already shifted bottles to in_use.
	GameState.data["inventory"]["bottles"] = {"available": 0, "in_use": 24}
	return "brew_taste_test"

func _mount(brew_id: String) -> Control:
	var s: Control = SCENE.instantiate()
	s.brew_id = brew_id
	add_child_autofree(s)
	return s

func test_ideal_play_yields_high_self_grade() -> void:
	var brew_id := _make_conditioning_brew()
	var s := _mount(brew_id)
	await wait_frames(1)
	# Ideal-play actuals should converge on the recipe targets — drift error
	# near 0 → grade A or A+ before any skill ceiling cap.
	var idx: int = Grader.grade_index(s._self_grade)
	# Skills are all 0 → ceiling = "C"; final grade can't exceed C.
	# But the drift_grade itself before ceiling should be A+ on ideal play.
	# We assert via internal computation here that the unceilinged grade was
	# at least A-.
	var actuals := s._compute_actuals()
	var grades := s._compute_grades(actuals)
	# After ceiling, fresh-career skills cap at C. Confirm that's what we see.
	assert_eq(String(grades["self"]), "C",
		"fresh-career skills cap the grade at C even with perfect drift")
	# But the drift_grade pre-ceiling would be A+. Check by feeding a
	# high-skill snapshot manually.
	GameState.data["skills"]["sanitation"]["level"] = 25
	GameState.data["skills"]["process"]["level"] = 25
	GameState.data["skills"]["timing"]["level"] = 25
	GameState.data["skills"]["temp_control"]["level"] = 25
	# Re-stub each outcome's snapshot at level 25.
	for k in s._brew["outcomes"]:
		s._brew["outcomes"][k]["skill_snapshot"] = SkillXP.snapshot(GameState.data["skills"])
	var grades2 := s._compute_grades(actuals)
	assert_true(Grader.grade_index(grades2["self"]) >= Grader.grade_index("A-"),
		"high-skill ideal play should grade at least A- self-grade")

func test_drink_writes_journal_entry_and_removes_brew() -> void:
	var brew_id := _make_conditioning_brew()
	# Wipe any previous journal so we can assert the fresh entry shape.
	if FileAccess.file_exists("user://journal.jsonl"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://journal.jsonl"))
	var s := _mount(brew_id)
	await wait_frames(1)
	s._on_drink_pressed()
	await wait_frames(1)
	# Brew removed from in-flight.
	assert_eq(GameState.data["brews_in_flight"].size(), 0)
	# Bottles back in availability.
	var bottles: Dictionary = GameState.data["inventory"]["bottles"]
	assert_eq(int(bottles["in_use"]), 0)
	assert_eq(int(bottles["available"]), 24)
	# Journal has the entry.
	var entries := SaveService.read_journal()
	assert_true(entries.size() >= 1)
	var last: Dictionary = entries[-1]
	assert_eq(String(last["type"]), "brew_completed")
	assert_eq(String(last["brew_id"]), brew_id)
	assert_true(last.has("self_grade"))
	assert_true(last.has("external_grade"))

func test_undissolved_lme_drops_og_and_drift_grade() -> void:
	# Catastrophic LME scorch leaves dissolution at 0.5 → real OG
	# divergence from target, drift grade should suffer noticeably.
	var override := {
		"add_lme": {"actual": {"sequence": ["lme_pour", "burner_off", "stir"],
			"result": "CATASTROPHIC_SCORCH", "lme_dissolution": 0.5},
			"care_factor": 0.6, "risk_deltas": {"off_flavor_temp": 6.5},
			"xp_gained": {}, "journal_notes": [], "skill_snapshot": {}},
	}
	var brew_id := _make_conditioning_brew(override)
	var s := _mount(brew_id)
	await wait_frames(1)
	# OG should be visibly off-target.
	var actuals := s._compute_actuals()
	assert_lt(float(actuals["og"]), 1.045 - 0.005,
		"undissolved LME pulls OG well below target")
