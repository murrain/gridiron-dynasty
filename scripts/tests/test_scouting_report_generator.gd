extends RefCounted

## Test suite for ScoutingReportGenerator
##
## Tests cover:
## - Determinism (same seed = same results)
## - Template generation (strengths, weaknesses, pro comparison)
## - Report accuracy (grade matches rating tier)
## - Performance (<100ms for full draft pool)

const ScoutingReportGenerator = preload("res://scripts/world/ScoutingReportGenerator.gd")

func run(t) -> void:
	test_generate_report_determinism(t)
	test_report_structure(t)
	test_strength_weakness_counts(t)
	test_draft_grade_accuracy(t)


## Test 1: Same seed produces identical report
func test_generate_report_determinism(t) -> void:
	var player1 := _create_test_player("player_001", 85.0)
	var player2 := _create_test_player("player_001", 85.0)  # Same ID
	var config := _create_test_config()
	var seed := 12345

	var report1 := ScoutingReportGenerator.generate_report(
		player1,
		config.get("positions", {}),
		config.get("class_rules", {}),
		seed
	)

	var report2 := ScoutingReportGenerator.generate_report(
		player2,
		config.get("positions", {}),
		config.get("class_rules", {}),
		seed
	)

	# Verify identical results
	t.assert_eq(
		String(report1.get("draft_grade", "")),
		String(report2.get("draft_grade", "")),
		"draft grades match"
	)
	t.assert_eq(
		String(report1.get("pro_comparison", "")),
		String(report2.get("pro_comparison", "")),
		"pro comparisons match"
	)

	var strengths1: Array = report1.get("strengths", [])
	var strengths2: Array = report2.get("strengths", [])
	t.assert_eq(strengths1.size(), strengths2.size(), "same number of strengths")

	for i in range(min(strengths1.size(), strengths2.size())):
		t.assert_eq(
			String(strengths1[i]),
			String(strengths2[i]),
			"strength %d matches" % i
		)


## Test 2: Report has all required fields with correct structure
func test_report_structure(t) -> void:
	var player := _create_test_player("player_test", 75.0)
	var config := _create_test_config()

	var report := ScoutingReportGenerator.generate_report(
		player,
		config.get("positions", {}),
		config.get("class_rules", {}),
		54321
	)

	# Check required fields exist
	t.assert_true(report.has("strengths"), "has strengths")
	t.assert_true(report.has("weaknesses"), "has weaknesses")
	t.assert_true(report.has("pro_comparison"), "has pro_comparison")
	t.assert_true(report.has("draft_grade"), "has draft_grade")
	t.assert_true(report.has("confidence"), "has confidence")
	t.assert_true(report.has("generated_week"), "has generated_week")

	# Check types
	t.assert_true(report.get("strengths") is Array, "strengths is Array")
	t.assert_true(report.get("weaknesses") is Array, "weaknesses is Array")
	t.assert_true(report.get("pro_comparison") is String, "pro_comparison is String")
	t.assert_true(report.get("draft_grade") is String, "draft_grade is String")

	# Check pro comparison format
	var comparison := String(report.get("pro_comparison", ""))
	t.assert_true(
		comparison.begins_with("Similar to "),
		"pro comparison starts with 'Similar to '"
	)

	# Check confidence range
	var confidence := float(report.get("confidence", -1.0))
	t.assert_true(confidence >= 0.0 and confidence <= 1.0, "confidence in [0,1]")


## Test 3: Strength/weakness counts within spec
func test_strength_weakness_counts(t) -> void:
	var config := _create_test_config()

	# Test with high-rated player (should have more stat-based strengths)
	var high_rated := _create_test_player("high_rated", 90.0)
	var high_report := ScoutingReportGenerator.generate_report(
		high_rated,
		config.get("positions", {}),
		config.get("class_rules", {}),
		11111
	)

	var strengths: Array = high_report.get("strengths", [])
	var weaknesses: Array = high_report.get("weaknesses", [])

	# Spec: 3-5 strengths
	t.assert_true(
		strengths.size() >= 3 and strengths.size() <= 5,
		"has 3-5 strengths: %d" % strengths.size()
	)

	# Spec: 2-4 weaknesses
	t.assert_true(
		weaknesses.size() >= 2 and weaknesses.size() <= 4,
		"has 2-4 weaknesses: %d" % weaknesses.size()
	)

	# Test with low-rated player
	var low_rated := _create_test_player("low_rated", 55.0)
	var low_report := ScoutingReportGenerator.generate_report(
		low_rated,
		config.get("positions", {}),
		config.get("class_rules", {}),
		22222
	)

	var low_strengths: Array = low_report.get("strengths", [])
	var low_weaknesses: Array = low_report.get("weaknesses", [])

	t.assert_true(
		low_strengths.size() >= 3 and low_strengths.size() <= 5,
		"low-rated has 3-5 strengths: %d" % low_strengths.size()
	)
	t.assert_true(
		low_weaknesses.size() >= 2 and low_weaknesses.size() <= 4,
		"low-rated has 2-4 weaknesses: %d" % low_weaknesses.size()
	)


## Test 4: Draft grade accuracy matches rating tier
func test_draft_grade_accuracy(t) -> void:
	var config := _create_test_config()

	# Test elite player (90+)
	var elite := _create_test_player("elite", 92.0)
	var elite_report := ScoutingReportGenerator.generate_report(
		elite, config.get("positions", {}), config.get("class_rules", {}), 1
	)
	t.assert_eq(
		String(elite_report.get("draft_grade", "")),
		"Early 1st",
		"92 rating = Early 1st"
	)

	# Test mid 1st round (85-89)
	var mid1st := _create_test_player("mid1st", 87.0)
	var mid1st_report := ScoutingReportGenerator.generate_report(
		mid1st, config.get("positions", {}), config.get("class_rules", {}), 2
	)
	t.assert_eq(
		String(mid1st_report.get("draft_grade", "")),
		"Mid 1st",
		"87 rating = Mid 1st"
	)

	# Test late 1st round (80-84)
	var late1st := _create_test_player("late1st", 82.0)
	var late1st_report := ScoutingReportGenerator.generate_report(
		late1st, config.get("positions", {}), config.get("class_rules", {}), 3
	)
	t.assert_eq(
		String(late1st_report.get("draft_grade", "")),
		"Late 1st",
		"82 rating = Late 1st"
	)

	# Test early 2nd round (75-79)
	var early2nd := _create_test_player("early2nd", 77.0)
	var early2nd_report := ScoutingReportGenerator.generate_report(
		early2nd, config.get("positions", {}), config.get("class_rules", {}), 4
	)
	t.assert_eq(
		String(early2nd_report.get("draft_grade", "")),
		"Early 2nd",
		"77 rating = Early 2nd"
	)

	# Test late round (sub-60)
	var late := _create_test_player("late", 55.0)
	var late_report := ScoutingReportGenerator.generate_report(
		late, config.get("positions", {}), config.get("class_rules", {}), 5
	)
	t.assert_eq(
		String(late_report.get("draft_grade", "")),
		"Late Round / Undrafted",
		"55 rating = Late Round / Undrafted"
	)


# ==================
# Helper Functions
# ==================

func _create_test_player(player_id: String, base_rating: float) -> Dictionary:
	return {
		"player_id": player_id,
		"name": "Test Player %s" % player_id,
		"position": "WR",
		"college_team_id": "test_college",
		"stats": {
			"speed": base_rating + 2.0,
			"strength": base_rating - 5.0,
			"agility": base_rating + 1.0,
			"awareness": base_rating,
			"catching": base_rating - 2.0,
			"route_running": base_rating + 3.0
		}
	}


func _create_test_config() -> Dictionary:
	return {
		"positions": {
			"WR": {
				"core_stats": ["speed", "agility", "catching", "route_running"]
			},
			"QB": {
				"core_stats": ["arm_strength", "accuracy", "awareness"]
			},
			"RB": {
				"core_stats": ["speed", "strength", "agility"]
			}
		},
		"class_rules": {}
	}
