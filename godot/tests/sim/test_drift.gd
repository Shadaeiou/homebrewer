extends GutTest

## Pins Drift.compute_actual + skill_factor_from_level per DESIGN.md 3.1.

func test_skill_factor_clamps_at_low_level() -> void:
	assert_eq(Drift.skill_factor_from_level(0), Drift.SKILL_FACTOR_MIN)
	assert_eq(Drift.skill_factor_from_level(-5), Drift.SKILL_FACTOR_MIN)

func test_skill_factor_clamps_at_high_level() -> void:
	assert_eq(Drift.skill_factor_from_level(20), Drift.SKILL_FACTOR_MAX)
	assert_eq(Drift.skill_factor_from_level(30), Drift.SKILL_FACTOR_MAX)
	assert_eq(Drift.skill_factor_from_level(100), Drift.SKILL_FACTOR_MAX)

func test_skill_factor_linear_midpoint() -> void:
	# Level 10 is halfway from 0 -> 20, so factor halfway from 0.4 -> 1.0 = 0.7
	assert_almost_eq(Drift.skill_factor_from_level(10), 0.7, 1e-6)

func test_compute_actual_within_3sigma_for_seeded_rng() -> void:
	# With every factor at 1.0, stddev = base_drift. Sample many draws and
	# assert: mean is near target, every draw is within 5σ, ~99.7% within 3σ.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var target := 65.0
	var base_drift := 0.5
	var n := 1000
	var sum := 0.0
	var max_dev := 0.0
	var within_3sigma := 0
	for i in range(n):
		var actual: float = Drift.compute_actual(target, base_drift, 1.0, 1.0, 1.0, rng)
		var dev := absf(actual - target)
		sum += actual
		max_dev = maxf(max_dev, dev)
		if dev <= 3.0 * base_drift:
			within_3sigma += 1
	var mean := sum / float(n)
	assert_almost_eq(mean, target, 0.1, "mean should converge near target")
	assert_lt(max_dev, 5.0 * base_drift, "no draw should exceed 5σ")
	assert_gt(within_3sigma, 980, "≥98%% of draws should be within 3σ")

func test_compute_actual_factors_reduce_stddev() -> void:
	# Higher skill/equip/care → smaller spread. We compare two seeded runs.
	var n := 500
	var target := 10.0
	var base_drift := 1.0

	var rng_low := RandomNumberGenerator.new()
	rng_low.seed = 42
	var var_low := 0.0
	for i in range(n):
		var a: float = Drift.compute_actual(target, base_drift, 0.4, 0.3, 0.6, rng_low)
		var_low += (a - target) * (a - target)
	var_low /= float(n)

	var rng_high := RandomNumberGenerator.new()
	rng_high.seed = 42
	var var_high := 0.0
	for i in range(n):
		var a: float = Drift.compute_actual(target, base_drift, 1.0, 1.0, 1.0, rng_high)
		var_high += (a - target) * (a - target)
	var_high /= float(n)

	assert_lt(var_high, var_low, "mastery+precision+care must tighten the distribution")
