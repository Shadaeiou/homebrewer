extends GutTest

## Pins RiskProfile per DESIGN.md 3.5.

func test_make_zero_has_all_axes() -> void:
	var p := RiskProfile.make_zero()
	for axis in RiskProfile.AXES:
		assert_eq(p[axis], 0.0)

func test_add_deltas_accumulates() -> void:
	var p := RiskProfile.make_zero()
	p = RiskProfile.add_deltas(p, {"infection": 2.5})
	p = RiskProfile.add_deltas(p, {"infection": 1.0, "oxidation": 0.5})
	assert_almost_eq(p["infection"], 3.5, 1e-6)
	assert_almost_eq(p["oxidation"], 0.5, 1e-6)
	assert_almost_eq(p["off_flavor_temp"], 0.0, 1e-6)

func test_add_deltas_clamps_at_10() -> void:
	var p := RiskProfile.make_zero()
	p = RiskProfile.add_deltas(p, {"infection": 8.0})
	p = RiskProfile.add_deltas(p, {"infection": 5.0})
	assert_almost_eq(p["infection"], 10.0, 1e-6)

func test_add_deltas_clamps_negative_at_0() -> void:
	var p := RiskProfile.make_zero()
	p = RiskProfile.add_deltas(p, {"infection": -1.0})
	assert_almost_eq(p["infection"], 0.0, 1e-6)

func test_add_deltas_does_not_mutate_input() -> void:
	var p := RiskProfile.make_zero()
	var snapshot := p.duplicate(true)
	RiskProfile.add_deltas(p, {"infection": 4.0})
	assert_eq(p, snapshot, "add_deltas must be pure")

func test_is_critical_threshold_default() -> void:
	var p := RiskProfile.make_zero()
	p = RiskProfile.add_deltas(p, {"infection": 6.99})
	assert_false(RiskProfile.is_critical(p, "infection"))
	p = RiskProfile.add_deltas(p, {"infection": 0.02})
	assert_true(RiskProfile.is_critical(p, "infection"))

func test_is_critical_custom_threshold() -> void:
	var p := RiskProfile.make_zero()
	p = RiskProfile.add_deltas(p, {"oxidation": 4.0})
	assert_true(RiskProfile.is_critical(p, "oxidation", 3.0))
	assert_false(RiskProfile.is_critical(p, "oxidation", 5.0))
