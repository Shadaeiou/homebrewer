extends GutTest

## Pins SkillXP curve, level-up, and prestige penalty per DESIGN.md 2.4 + 3.4 + 8.8.

func _empty_skill() -> Dictionary:
	return {"level": 0, "xp": 0, "xp_to_next": SkillXP.xp_to_next_for_level(0)}

func test_xp_to_next_curve_known_points() -> void:
	# 100 + level² × 10
	assert_eq(SkillXP.xp_to_next_for_level(0), 100)
	assert_eq(SkillXP.xp_to_next_for_level(10), 1100)
	assert_eq(SkillXP.xp_to_next_for_level(20), 4100)
	assert_eq(SkillXP.xp_to_next_for_level(30), 9100)

func test_xp_to_next_clamps_negative() -> void:
	assert_eq(SkillXP.xp_to_next_for_level(-1), 100)

func test_add_xp_no_level_up_below_threshold() -> void:
	var s := _empty_skill()
	var out := SkillXP.add_xp(s, 50)
	assert_eq(out["level"], 0)
	assert_eq(out["xp"], 50)
	assert_eq(out["xp_to_next"], 100)

func test_add_xp_levels_up_once() -> void:
	var s := _empty_skill()
	var out := SkillXP.add_xp(s, 100)
	assert_eq(out["level"], 1)
	assert_eq(out["xp"], 0)
	assert_eq(out["xp_to_next"], SkillXP.xp_to_next_for_level(1))

func test_add_xp_levels_up_multiple_times_in_one_award() -> void:
	# Level 0 needs 100, level 1 needs 110, level 2 needs 140 -> total 350 to reach level 3 with 0 leftover.
	var s := _empty_skill()
	var out := SkillXP.add_xp(s, 350)
	assert_eq(out["level"], 3)
	assert_eq(out["xp"], 0)

func test_add_xp_does_not_mutate_input() -> void:
	var s := _empty_skill()
	var snapshot := s.duplicate(true)
	SkillXP.add_xp(s, 250)
	assert_eq(s, snapshot, "add_xp must be pure")

func test_prestige_penalty_table() -> void:
	var skills := {
		"sanitation":   {"level": 30, "xp": 500, "xp_to_next": 9100},
		"temp_control": {"level": 7,  "xp": 200, "xp_to_next": 590},
		"timing":       {"level": 0,  "xp": 0,   "xp_to_next": 100},
		"process":      {"level": 5,  "xp": 50,  "xp_to_next": 350},
		"palate":       {"level": 1,  "xp": 0,   "xp_to_next": 110},
		"water_chem":   {"level": 10, "xp": 0,   "xp_to_next": 1100},
	}
	var out := SkillXP.apply_prestige_penalty(skills)
	# 20% drop, floor 0
	assert_eq(int(out["sanitation"]["level"]),   24)  # 30 -> 24
	assert_eq(int(out["temp_control"]["level"]),  5)  # 7  -> 5 (floor(5.6))
	assert_eq(int(out["timing"]["level"]),        0)  # 0  -> 0
	assert_eq(int(out["process"]["level"]),       4)  # 5  -> 4
	assert_eq(int(out["palate"]["level"]),        0)  # 1  -> 0
	assert_eq(int(out["water_chem"]["level"]),    8)  # 10 -> 8
	# XP zeroed, xp_to_next matches new level
	for axis in out.keys():
		assert_eq(int(out[axis]["xp"]), 0, "%s xp should reset" % axis)
		var lvl: int = int(out[axis]["level"])
		assert_eq(int(out[axis]["xp_to_next"]), SkillXP.xp_to_next_for_level(lvl))

func test_snapshot_returns_levels_for_all_axes() -> void:
	var skills := {
		"sanitation":   {"level": 12},
		"temp_control": {"level": 3},
		# timing, process, palate, water_chem missing -> default 0
	}
	var snap := SkillXP.snapshot(skills)
	assert_eq(snap["sanitation"], 12)
	assert_eq(snap["temp_control"], 3)
	assert_eq(snap["timing"], 0)
	assert_eq(snap["process"], 0)
	assert_eq(snap["palate"], 0)
	assert_eq(snap["water_chem"], 0)
