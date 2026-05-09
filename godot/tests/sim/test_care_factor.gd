extends GutTest

## Pins CareFactor.from_breadth per DESIGN.md 3.3.

func test_zero_taken_returns_floor() -> void:
	assert_almost_eq(CareFactor.from_breadth(0, 4), 0.6, 1e-6)

func test_all_taken_returns_ceiling() -> void:
	assert_almost_eq(CareFactor.from_breadth(4, 4), 1.0, 1e-6)

func test_midpoint_is_linear() -> void:
	# 2/4 → halfway from 0.6 to 1.0 = 0.8
	assert_almost_eq(CareFactor.from_breadth(2, 4), 0.8, 1e-6)
	# 1/4 → 0.6 + 0.25 * 0.4 = 0.7
	assert_almost_eq(CareFactor.from_breadth(1, 4), 0.7, 1e-6)
	# 3/4 → 0.6 + 0.75 * 0.4 = 0.9
	assert_almost_eq(CareFactor.from_breadth(3, 4), 0.9, 1e-6)

func test_zero_available_returns_ceiling() -> void:
	# No optional sub-actions to take → no penalty.
	assert_almost_eq(CareFactor.from_breadth(0, 0), 1.0, 1e-6)

func test_taken_clamps_above_available() -> void:
	# Player can't earn extra credit by exceeding actions_available.
	assert_almost_eq(CareFactor.from_breadth(10, 4), 1.0, 1e-6)
