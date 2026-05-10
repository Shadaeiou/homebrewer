extends GutTest

## Pins Pour LME's procedure-shape rubric per DESIGN.md 3.9 + Appendix A
## Step 4. The four sequence categories must produce distinct outcomes,
## and the emitted Outcome dict must satisfy the universal contract.

const SCENE := preload("res://scenes/minigames/add_lme.tscn")

func _mount() -> Control:
	GameState.reset_to_new_career()
	var s: Control = SCENE.instantiate()
	add_child_autofree(s)
	return s

func _tap_in_order(s: Control, order: Array) -> Dictionary:
	# Drives the controller without going through Godot's Button.pressed
	# signal — direct call into _on_action with the matching button.
	var captured := [null]
	s.minigame_completed.connect(func(o): captured[0] = o)
	for action_id in order:
		var btn: Button = _btn_for(s, action_id)
		s._on_action(action_id, btn)
	# Wait past the 1.5s reveal beat plus a frame.
	await wait_seconds(s.REVEAL_SECONDS + 0.1)
	return captured[0]

func _btn_for(s: Control, action_id: String) -> Button:
	match action_id:
		"burner_off": return s._burner_off_button
		"stir":       return s._stir_button
		"lme_pour":   return s._lme_pour_button
		_:            return null

func test_ideal_sequence_produces_no_risk() -> void:
	var s := _mount()
	var outcome: Dictionary = await _tap_in_order(s, ["burner_off", "stir", "lme_pour"])
	assert_eq(outcome["actual"]["result"], "IDEAL")
	assert_almost_eq(float(outcome["actual"]["lme_dissolution"]), 1.0, 1e-6)
	assert_eq(Dictionary(outcome["risk_deltas"]).size(), 0,
		"ideal pour should add zero risk")

func test_burner_off_then_lme_then_stir_is_mild_glob() -> void:
	# Burner off, but stir was after the pour — wort still, glob.
	var s := _mount()
	var outcome: Dictionary = await _tap_in_order(s, ["burner_off", "lme_pour", "stir"])
	assert_eq(outcome["actual"]["result"], "MILD_GLOB")
	# recipe_drift gets penalized; off_flavor_temp does not.
	assert_true(outcome["risk_deltas"].has("recipe_drift"))
	assert_false(outcome["risk_deltas"].has("off_flavor_temp"))

func test_stir_then_lme_with_burner_late_is_moderate_scorch() -> void:
	# Stir was first, lme poured before burner off → kettle was hot at pour.
	var s := _mount()
	var outcome: Dictionary = await _tap_in_order(s, ["stir", "lme_pour", "burner_off"])
	assert_eq(outcome["actual"]["result"], "MODERATE_SCORCH")
	assert_true(outcome["risk_deltas"].has("off_flavor_temp"))

func test_lme_first_is_catastrophic() -> void:
	# Worst case: LME hits hot kettle with neither burner off nor stir.
	var s := _mount()
	var outcome: Dictionary = await _tap_in_order(s, ["lme_pour", "burner_off", "stir"])
	assert_eq(outcome["actual"]["result"], "CATASTROPHIC_SCORCH")
	# Catastrophic should add the most off_flavor_temp risk.
	var off_flavor := float(outcome["risk_deltas"].get("off_flavor_temp", 0.0))
	assert_gt(off_flavor, 5.0,
		"catastrophic scorch should push off_flavor_temp >5.0")

func test_outcome_satisfies_universal_contract() -> void:
	var s := _mount()
	var outcome: Dictionary = await _tap_in_order(s, ["burner_off", "stir", "lme_pour"])
	var issues := Outcome.lint(outcome)
	assert_eq(issues.size(), 0, "outcome must lint clean: %s" % str(issues))

func test_optional_sub_actions_raise_care_factor() -> void:
	# breadth=2 ceiling; toggling both optionals should land care_factor at 1.0.
	# breadth=0 baseline gives care_factor=0.6.
	var s_low := _mount()
	var low: Dictionary = await _tap_in_order(s_low, ["burner_off", "stir", "lme_pour"])
	assert_almost_eq(float(low["care_factor"]), 0.6, 1e-6)

	var s_high := _mount()
	s_high._read_aloud_toggle.button_pressed = true
	s_high._pre_warm_toggle.button_pressed = true
	var high: Dictionary = await _tap_in_order(s_high, ["burner_off", "stir", "lme_pour"])
	assert_almost_eq(float(high["care_factor"]), 1.0, 1e-6)
