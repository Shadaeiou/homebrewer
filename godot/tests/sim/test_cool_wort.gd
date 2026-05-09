extends GutTest

const SCENE := preload("res://scenes/minigames/cool_wort.tscn")

func _mount() -> Control:
	GameState.reset_to_new_career()
	var s: Control = SCENE.instantiate()
	add_child_autofree(s)
	return s

func _emit(s: Control) -> Dictionary:
	var captured := [null]
	s.minigame_completed.connect(func(o): captured[0] = o)
	s._on_confirm_pressed()
	await wait_frames(1)
	return captured[0]

func _select_path(s: Control, path: String) -> void:
	var btn: CheckBox = s._path_radios[path]
	btn.button_pressed = true
	s._on_path_toggled(path, btn, true)

func _check_options(s: Control, ids: Array) -> void:
	for id in ids:
		if s._option_toggles.has(id) and not s._option_toggles[id].disabled:
			s._option_toggles[id].button_pressed = true

func test_default_path_is_ice_bath() -> void:
	var s := _mount()
	assert_eq(s._selected_path, "ice_bath")

func test_ice_bath_with_full_care_lands_low_temp_low_risk() -> void:
	var s := _mount()
	_select_path(s, "ice_bath")
	_check_options(s, ["ice", "stir", "monitor"])
	var out: Dictionary = await _emit(s)
	assert_eq(String(out["actual"]["path"]), "ice_bath")
	# Full care → exact 70°F target.
	assert_almost_eq(float(out["actual"]["final_temp_f"]), 70.0, 1e-6)
	assert_eq(Dictionary(out["risk_deltas"]).size(), 0,
		"ice + stir + monitor should leave no infection risk")

func test_ice_bath_skipping_protections_adds_infection_risk() -> void:
	var s := _mount()
	_select_path(s, "ice_bath")
	# Take only "ice" — no stir, no monitor.
	_check_options(s, ["ice"])
	var out: Dictionary = await _emit(s)
	assert_gt(float(out["risk_deltas"].get("infection", 0.0)), 0.0)

func test_top_off_without_protection_adds_infection_risk() -> void:
	var s := _mount()
	_select_path(s, "top_off")
	# Don't boil, don't use bottled.
	var out: Dictionary = await _emit(s)
	assert_eq(String(out["actual"]["path"]), "top_off")
	assert_gt(float(out["risk_deltas"].get("infection", 0.0)), 1.0,
		"raw tap water onto hot wort should be a real risk")

func test_top_off_with_boiled_water_is_safe() -> void:
	var s := _mount()
	_select_path(s, "top_off")
	_check_options(s, ["boil_topoff"])
	var out: Dictionary = await _emit(s)
	# Boiled top-off water removes the sanitation gamble. Final temp may
	# still be high enough for off_flavor_temp depending on care, but the
	# raw-infection bullet should be gone.
	assert_false(out["risk_deltas"].has("infection"))

func test_top_off_warm_temp_adds_off_flavor_risk() -> void:
	var s := _mount()
	_select_path(s, "top_off")
	# No options taken → low care → final temp drifts up past 78°F.
	var out: Dictionary = await _emit(s)
	assert_true(out["risk_deltas"].has("off_flavor_temp"),
		"top-off path with no care lands ≥78°F → pitch-temp off-flavor risk")

func test_outcome_satisfies_universal_contract() -> void:
	var s := _mount()
	_check_options(s, ["ice", "stir", "monitor"])
	var out: Dictionary = await _emit(s)
	assert_eq(Outcome.lint(out).size(), 0)
