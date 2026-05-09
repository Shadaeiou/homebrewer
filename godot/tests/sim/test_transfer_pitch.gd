extends GutTest

const SCENE := preload("res://scenes/minigames/transfer_pitch.tscn")

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

func _select(group: Dictionary, id: String, on_select: Callable) -> void:
	# Mirror the radio-toggle path used by the controller.
	for sib_id in group:
		group[sib_id].set_pressed_no_signal(false)
	group[id].button_pressed = true
	on_select.call(id)

func test_default_choices_are_gentle_and_sprinkle() -> void:
	var s := _mount()
	assert_eq(s._selected_pour, "gentle")
	assert_eq(s._selected_pitch, "sprinkle")

func test_fast_pour_adds_oxidation_risk() -> void:
	var s := _mount()
	s._selected_pour = "fast"
	var out: Dictionary = await _emit(s)
	assert_almost_eq(float(out["risk_deltas"].get("oxidation", 0.0)), 2.0, 1e-6)

func test_lazy_sprinkle_adds_infection() -> void:
	# Default sprinkle without "even_sprinkle" optional.
	var s := _mount()
	var out: Dictionary = await _emit(s)
	assert_gt(float(out["risk_deltas"].get("infection", 0.0)), 0.0,
		"sprinkle pitch without even-sprinkle hygiene drives infection")

func test_even_sprinkle_optional_eliminates_lazy_sprinkle_penalty() -> void:
	var s := _mount()
	s._options["even_sprinkle"].button_pressed = true
	s._options["sanitize_funnel"].button_pressed = true  # remove funnel infection too
	var out: Dictionary = await _emit(s)
	assert_eq(Dictionary(out["risk_deltas"]).size(), 0,
		"even-sprinkle + sanitized funnel + gentle pour should leave zero risk")

func test_rehydrate_yields_more_process_xp() -> void:
	var sprinkle := _mount()
	var sprinkle_out: Dictionary = await _emit(sprinkle)
	var rehydrate := _mount()
	rehydrate._selected_pitch = "rehydrate"
	var rehydrate_out: Dictionary = await _emit(rehydrate)
	assert_gt(int(rehydrate_out["xp_gained"]["process"]),
		int(sprinkle_out["xp_gained"]["process"]),
		"rehydration is the higher-skill pitch path")

func test_outcome_satisfies_universal_contract() -> void:
	var s := _mount()
	s._options["even_sprinkle"].button_pressed = true
	s._options["sanitize_funnel"].button_pressed = true
	var out: Dictionary = await _emit(s)
	assert_eq(Outcome.lint(out).size(), 0)
