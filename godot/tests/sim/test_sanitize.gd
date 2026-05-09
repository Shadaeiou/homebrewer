extends GutTest

## Pins Sanitize per DESIGN.md 3.3 + Appendix A Step 1.

const SCENE := preload("res://scenes/minigames/sanitize.tscn")

func _mount() -> Control:
	GameState.reset_to_new_career()
	var s: Control = SCENE.instantiate()
	add_child_autofree(s)
	return s

func _check(s: Control, ids: Array) -> void:
	for id in ids:
		s._toggles[String(id)].button_pressed = true

func _emit_outcome(s: Control) -> Dictionary:
	var captured := [null]
	s.minigame_completed.connect(func(o): captured[0] = o)
	s._on_done_pressed()
	await wait_frames(1)
	return captured[0]

func test_skipping_everything_leaves_bucket_used_and_high_infection_risk() -> void:
	var s := _mount()
	var out: Dictionary = await _emit_outcome(s)
	assert_eq(out["actual"]["resulting_fermenter_state"], "USED")
	assert_gt(float(out["risk_deltas"].get("infection", 0.0)), 3.0,
		"USED bucket adds significant infection risk")

func test_rinse_only_yields_serviceable() -> void:
	var s := _mount()
	_check(s, ["rinse"])
	var out: Dictionary = await _emit_outcome(s)
	assert_eq(out["actual"]["resulting_fermenter_state"], "SERVICEABLE")

func test_rinse_plus_soap_yields_clean() -> void:
	var s := _mount()
	_check(s, ["rinse", "soap"])
	var out: Dictionary = await _emit_outcome(s)
	assert_eq(out["actual"]["resulting_fermenter_state"], "CLEAN")
	# CLEAN is much better than USED for infection risk.
	assert_lt(float(out["risk_deltas"].get("infection", 0.0)), 1.0)

func test_star_san_disabled_when_not_owned() -> void:
	# Fresh career doesn't include Star San (canonical Appendix A skip).
	var s := _mount()
	assert_true(s._toggles["star_san"].disabled,
		"Star San must be greyed out when not owned")

func test_care_factor_excludes_disabled_actions_from_breadth_pool() -> void:
	# Three available actions (no Star San); taking all three should hit
	# care_factor = 1.0, not 3/4 = 0.9.
	var s := _mount()
	_check(s, ["rinse", "soap", "drip_dry"])
	var out: Dictionary = await _emit_outcome(s)
	assert_almost_eq(float(out["care_factor"]), 1.0, 1e-6,
		"breadth pool must exclude actions the player can't take")

func test_outcome_satisfies_universal_contract() -> void:
	var s := _mount()
	_check(s, ["rinse"])
	var out: Dictionary = await _emit_outcome(s)
	assert_eq(Outcome.lint(out).size(), 0)

func test_persistent_fermenter_state_updates() -> void:
	# After Done, equipment.owned[bucket].state should reflect the result —
	# carries forward as 3.2 says: "starting_state ... decays with use."
	var s := _mount()
	_check(s, ["rinse", "soap"])
	await _emit_outcome(s)
	var owned: Dictionary = GameState.data["equipment"]["owned"]
	assert_eq(owned["plastic_bucket_fermenter_1"]["state"], "CLEAN")
