extends GutTest

const SCENE := preload("res://scenes/minigames/boil_with_hops.tscn")

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

func test_default_is_clean_boil() -> void:
	# Defaults: HIGH heat, watch + on-schedule + flameout, lower-heat boil-over.
	var s := _mount()
	var out: Dictionary = await _emit(s)
	assert_almost_eq(float(out["actual"]["ibu_factor"]), 1.0, 1e-6,
		"all defaults engaged → no IBU drift")
	assert_almost_eq(float(out["actual"]["volume_loss_gal"]), 0.0, 1e-6)
	assert_eq(Dictionary(out["risk_deltas"]).size(), 0)

func test_low_heat_under_extracts_hops() -> void:
	var s := _mount()
	s._heat = "LOW"
	var out: Dictionary = await _emit(s)
	assert_lt(float(out["actual"]["ibu_factor"]), 1.0)

func test_late_hops_lowers_ibu() -> void:
	var s := _mount()
	s._hops_toggle.button_pressed = false
	var out: Dictionary = await _emit(s)
	assert_lt(float(out["actual"]["ibu_factor"]), 1.0)

func test_ignored_boilover_dumps_volume_and_risk() -> void:
	var s := _mount()
	s._boilover = "ignore"
	var out: Dictionary = await _emit(s)
	assert_gt(float(out["actual"]["volume_loss_gal"]), 0.5)
	assert_gt(float(out["risk_deltas"]["boil_over"]), 4.0)

func test_lower_heat_is_the_clean_boilover_response() -> void:
	var s := _mount()
	s._boilover = "lower_heat"
	var out: Dictionary = await _emit(s)
	assert_almost_eq(float(out["actual"]["volume_loss_gal"]), 0.0, 1e-6)
	assert_false(out["risk_deltas"].has("boil_over"))

func test_forgetting_flameout_overboils() -> void:
	var s := _mount()
	s._flameout_toggle.button_pressed = false
	var out: Dictionary = await _emit(s)
	# Late flameout: IBU rises (more bittering time), volume drops (evap).
	assert_gt(float(out["actual"]["ibu_factor"]), 1.0)
	assert_gt(float(out["actual"]["volume_loss_gal"]), 0.2)

func test_outcome_satisfies_universal_contract() -> void:
	var s := _mount()
	var out: Dictionary = await _emit(s)
	assert_eq(Outcome.lint(out).size(), 0)
