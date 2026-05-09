extends GutTest

## Pins Grader.max_grade_for_level table + compose_final + ceiling_for_relevant_skills
## per DESIGN.md 3.4.

func test_max_grade_for_level_table() -> void:
	# Per 3.4: 0→C, 5→B, 10→A-, 15→A, 20→A+
	assert_eq(Grader.max_grade_for_level(0),  "C")
	assert_eq(Grader.max_grade_for_level(4),  "C")
	assert_eq(Grader.max_grade_for_level(5),  "B")
	assert_eq(Grader.max_grade_for_level(9),  "B")
	assert_eq(Grader.max_grade_for_level(10), "A-")
	assert_eq(Grader.max_grade_for_level(14), "A-")
	assert_eq(Grader.max_grade_for_level(15), "A")
	assert_eq(Grader.max_grade_for_level(19), "A")
	assert_eq(Grader.max_grade_for_level(20), "A+")
	assert_eq(Grader.max_grade_for_level(30), "A+")

func test_compose_final_takes_worse_of_drift_and_ceiling() -> void:
	assert_eq(Grader.compose_final("A+", "C"), "C", "ceiling caps drift")
	assert_eq(Grader.compose_final("D", "A+"), "D", "drift caps ceiling")
	assert_eq(Grader.compose_final("B",  "B"),  "B")

func test_min_grade_picks_lower_index() -> void:
	assert_eq(Grader.min_grade("A+", "F"), "F")
	assert_eq(Grader.min_grade("A-", "B"), "B")
	assert_eq(Grader.min_grade("A",  "A"), "A")

func test_ceiling_takes_worst_across_snapshots_and_axes() -> void:
	# Snapshot A: sanitation=20 (A+), temp_control=10 (A-)
	# Snapshot B: sanitation=15 (A),  temp_control=5  (B)
	# Relevant axes: sanitation + temp_control
	# Worst = B (temp_control in snapshot B)
	var snapshots := [
		{"sanitation": 20, "temp_control": 10, "timing": 0, "process": 0, "palate": 0, "water_chem": 0},
		{"sanitation": 15, "temp_control": 5,  "timing": 0, "process": 0, "palate": 0, "water_chem": 0},
	]
	var ceiling := Grader.ceiling_for_relevant_skills(snapshots, ["sanitation", "temp_control"])
	assert_eq(ceiling, "B")

func test_ceiling_ignores_irrelevant_axes() -> void:
	# All relevant axes are A+; an irrelevant axis at level 0 (C) must be ignored.
	var snapshots := [{"sanitation": 20, "temp_control": 20, "timing": 20, "process": 20, "palate": 0, "water_chem": 0}]
	var ceiling := Grader.ceiling_for_relevant_skills(snapshots, ["sanitation", "temp_control", "timing", "process"])
	assert_eq(ceiling, "A+")

func test_ceiling_empty_inputs_default_to_top() -> void:
	assert_eq(Grader.ceiling_for_relevant_skills([], ["sanitation"]), "A+")
	assert_eq(Grader.ceiling_for_relevant_skills([{"sanitation": 0}], []), "A+")

func test_grade_from_drift_error_buckets() -> void:
	assert_eq(Grader.grade_from_drift_error(0.00), "A+")
	assert_eq(Grader.grade_from_drift_error(0.05), "A+")
	assert_eq(Grader.grade_from_drift_error(0.08), "A")
	assert_eq(Grader.grade_from_drift_error(0.12), "A-")
	assert_eq(Grader.grade_from_drift_error(0.20), "B")
	assert_eq(Grader.grade_from_drift_error(0.35), "C")
	assert_eq(Grader.grade_from_drift_error(0.50), "D")
	assert_eq(Grader.grade_from_drift_error(0.99), "F")
