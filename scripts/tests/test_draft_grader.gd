## Test suite for DraftGrader
##
## Tests grade calculation, factor weighting, team aggregation, and
## steal/reach identification. All tests verify determinism (no RNG).
##
## Coverage: 12 tests
##   - Grade calculation: 4 tests
##   - Factor weighting: 3 tests
##   - Team grades: 2 tests
##   - Steal/reach identification: 2 tests
##   - Determinism verification: 1 test
##
extends RefCounted

const DraftGrader = preload("res://scripts/world/DraftGrader.gd")


func run(t) -> void:
	# Grade calculation tests
	_test_grade_returns_all_components(t)
	_test_score_to_letter_thresholds(t)
	_test_high_value_pick_gets_good_grade(t)
	_test_reach_pick_gets_lower_grade(t)

	# Factor weighting tests
	_test_value_is_primary_factor(t)
	_test_need_affects_grade(t)
	_test_fit_affects_grade(t)

	# Team grades tests
	_test_team_grade_aggregates_picks(t)
	_test_team_grade_identifies_best_worst(t)

	# Steal/reach identification tests
	_test_identify_steals(t)
	_test_identify_reaches(t)

	# Determinism test
	_test_determinism_same_inputs_same_outputs(t)


## Test: grade_pick returns all expected components
func _test_grade_returns_all_components(t) -> void:
	var grader := DraftGrader.new()

	var player := _make_test_player("QB", 85.0)
	var needs := {"QB": 1.3}

	var grade := grader.grade_pick(
		player,
		5,      # pick_number
		1,      # round_number
		needs,
		"west_coast",
		3,      # consensus_rank (better than pick 5)
		{},     # positions_cfg
		{}      # class_rules
	)

	t.assert_true(grade.has("letter_grade"), "Grade should have letter_grade")
	t.assert_true(grade.has("overall_score"), "Grade should have overall_score")
	t.assert_true(grade.has("value_score"), "Grade should have value_score")
	t.assert_true(grade.has("need_score"), "Grade should have need_score")
	t.assert_true(grade.has("fit_score"), "Grade should have fit_score")
	t.assert_true(grade.has("factors"), "Grade should have factors")
	t.assert_true(grade.has("analysis"), "Grade should have analysis text")


## Test: score_to_letter respects thresholds
func _test_score_to_letter_thresholds(t) -> void:
	var grader := DraftGrader.new()

	# Test various scores
	var player_96 := _make_test_player("QB", 99.0)
	var player_80 := _make_test_player("QB", 75.0)
	var player_55 := _make_test_player("QB", 50.0)

	var grade_high := grader.grade_pick(
		player_96, 1, 1, {"QB": 1.5}, "", 1, {}, {}
	)
	var grade_mid := grader.grade_pick(
		player_80, 50, 2, {"QB": 1.0}, "", 50, {}, {}
	)
	var grade_low := grader.grade_pick(
		player_55, 200, 6, {"QB": 0.95}, "", 250, {}, {}
	)

	# Verify letter grades make sense relative to each other
	var high_letter := String(grade_high.get("letter_grade", ""))
	var mid_letter := String(grade_mid.get("letter_grade", ""))
	var low_letter := String(grade_low.get("letter_grade", ""))

	t.assert_true(
		high_letter.begins_with("A") or high_letter.begins_with("B"),
		"High talent + high need should get A or B grade"
	)
	t.assert_true(
		low_letter == "D" or low_letter == "F" or low_letter.begins_with("C"),
		"Low talent late round reach should get C/D/F grade"
	)


## Test: High value pick (talent > pick slot) gets good grade
func _test_high_value_pick_gets_good_grade(t) -> void:
	var grader := DraftGrader.new()

	# Elite player falling to mid first round (steal scenario)
	var player := _make_test_player("EDGE", 92.0)
	var needs := {"EDGE": 1.4}  # High need

	var grade := grader.grade_pick(
		player,
		15,     # pick_number
		1,      # round_number
		needs,
		"4_3_under",
		3,      # consensus_rank (should be top 5, fell to 15)
		{},
		{}
	)

	var overall := float(grade.get("overall_score", 0.0))
	var letter := String(grade.get("letter_grade", ""))

	t.assert_gt(overall, 80.0, "Steal pick should have high overall score")
	t.assert_true(
		letter.begins_with("A") or letter.begins_with("B"),
		"Steal pick should get A or B grade: got %s" % letter
	)


## Test: Reach pick (drafted above value) gets lower grade
func _test_reach_pick_gets_lower_grade(t) -> void:
	var grader := DraftGrader.new()

	# Day 3 talent taken in first round (reach scenario)
	var player := _make_test_player("K", 60.0)
	var needs := {"K": 0.95}  # No need

	var grade := grader.grade_pick(
		player,
		15,     # pick_number (first round)
		1,      # round_number
		needs,
		"",
		120,    # consensus_rank (4th round value)
		{},
		{}
	)

	var overall := float(grade.get("overall_score", 0.0))
	var letter := String(grade.get("letter_grade", ""))
	var factors: Dictionary = grade.get("factors", {})
	var value_diff := int(factors.get("value_diff", 0))

	t.assert_lt(overall, 70.0, "Reach pick should have lower overall score")
	t.assert_lt(value_diff, 0, "Reach should have negative value_diff")


## Test: Value component is the primary factor (50% weight)
func _test_value_is_primary_factor(t) -> void:
	var grader := DraftGrader.new()

	# Same player, different pick positions
	var player := _make_test_player("RB", 80.0)

	# Pick at consensus value
	var grade_fair := grader.grade_pick(
		player, 50, 2, {"RB": 1.0}, "", 50, {}, {}
	)

	# Pick as steal (consensus 100, picked at 50)
	var grade_steal := grader.grade_pick(
		player, 50, 2, {"RB": 1.0}, "", 100, {}, {}
	)

	# Pick as reach (consensus 10, picked at 50)
	var grade_reach := grader.grade_pick(
		player, 50, 2, {"RB": 1.0}, "", 10, {}, {}
	)

	var fair_value := float(grade_fair.get("value_score", 0.0))
	var steal_value := float(grade_steal.get("value_score", 0.0))
	var reach_value := float(grade_reach.get("value_score", 0.0))

	t.assert_gt(steal_value, fair_value, "Steal should have higher value score")
	t.assert_gt(fair_value, reach_value, "Fair should have higher value than reach")


## Test: Need component affects grade (30% weight)
func _test_need_affects_grade(t) -> void:
	var grader := DraftGrader.new()

	var player := _make_test_player("CB", 75.0)

	# High need
	var grade_high_need := grader.grade_pick(
		player, 30, 1, {"CB": 1.5}, "", 30, {}, {}
	)

	# Low need (already stacked at CB)
	var grade_low_need := grader.grade_pick(
		player, 30, 1, {"CB": 0.95}, "", 30, {}, {}
	)

	var high_need_score := float(grade_high_need.get("need_score", 0.0))
	var low_need_score := float(grade_low_need.get("need_score", 0.0))
	var high_overall := float(grade_high_need.get("overall_score", 0.0))
	var low_overall := float(grade_low_need.get("overall_score", 0.0))

	t.assert_gt(high_need_score, low_need_score, "High need should have higher need score")
	t.assert_gt(high_overall, low_overall, "High need should improve overall grade")


## Test: Fit component affects grade (20% weight)
func _test_fit_affects_grade(t) -> void:
	var grader := DraftGrader.new()

	# Player with scheme fit data
	var player := _make_test_player("WR", 78.0)
	player["scheme_fit"] = {
		"west_coast": 95.0,
		"air_raid": 60.0
	}

	# Good fit
	var grade_good_fit := grader.grade_pick(
		player, 40, 2, {"WR": 1.2}, "west_coast", 40, {}, {}
	)

	# Poor fit
	var grade_poor_fit := grader.grade_pick(
		player, 40, 2, {"WR": 1.2}, "air_raid", 40, {}, {}
	)

	var good_fit_score := float(grade_good_fit.get("fit_score", 0.0))
	var poor_fit_score := float(grade_poor_fit.get("fit_score", 0.0))

	t.assert_gt(good_fit_score, poor_fit_score, "Good scheme fit should have higher fit score")


## Test: Team grade aggregates all picks correctly
func _test_team_grade_aggregates_picks(t) -> void:
	var grader := DraftGrader.new()

	# Create mock pick records with grades
	var picks := [
		_make_mock_pick_with_grade("pick1", 90.0, 85.0, 80.0),  # A-
		_make_mock_pick_with_grade("pick2", 75.0, 70.0, 75.0),  # C+
		_make_mock_pick_with_grade("pick3", 80.0, 85.0, 80.0),  # B
	]

	var team_grade := grader.grade_team_draft("team1", picks, {})

	t.assert_eq(team_grade.get("team_id"), "team1", "Should include team_id")
	t.assert_eq(team_grade.get("pick_count"), 3, "Should count all picks")
	t.assert_true(team_grade.has("overall_grade"), "Should have overall letter grade")
	t.assert_true(team_grade.has("avg_value"), "Should have average value score")


## Test: Team grade identifies best and worst picks
func _test_team_grade_identifies_best_worst(t) -> void:
	var grader := DraftGrader.new()

	var picks := [
		_make_mock_pick_with_grade("best", 95.0, 95.0, 95.0),
		_make_mock_pick_with_grade("mid", 75.0, 75.0, 75.0),
		_make_mock_pick_with_grade("worst", 55.0, 55.0, 55.0),
	]

	var team_grade := grader.grade_team_draft("team1", picks, {})

	var best_pick: Dictionary = team_grade.get("best_pick", {})
	var worst_pick: Dictionary = team_grade.get("worst_pick", {})

	t.assert_eq(
		best_pick.get("player_id"),
		"best",
		"Should identify highest graded pick as best"
	)
	t.assert_eq(
		worst_pick.get("player_id"),
		"worst",
		"Should identify lowest graded pick as worst"
	)


## Test: identify_steals finds picks below consensus
func _test_identify_steals(t) -> void:
	var grader := DraftGrader.new()

	var picks := [
		_make_mock_pick_with_value_diff("steal1", 20),   # Big steal
		_make_mock_pick_with_value_diff("fair", 5),      # Not a steal
		_make_mock_pick_with_value_diff("steal2", 25),   # Bigger steal
		_make_mock_pick_with_value_diff("reach", -10),   # Reach
	]

	var steals := grader.identify_steals(picks, 15)

	t.assert_eq(steals.size(), 2, "Should identify 2 steals (diff >= 15)")

	# Verify sorted by value_diff (biggest first)
	t.assert_eq(steals[0].get("player_id"), "steal2", "Biggest steal should be first")
	t.assert_eq(steals[1].get("player_id"), "steal1", "Second steal should be second")


## Test: identify_reaches finds picks above consensus
func _test_identify_reaches(t) -> void:
	var grader := DraftGrader.new()

	var picks := [
		_make_mock_pick_with_value_diff("reach1", -20),  # Reach
		_make_mock_pick_with_value_diff("fair", -5),     # Minor reach
		_make_mock_pick_with_value_diff("reach2", -30),  # Bigger reach
		_make_mock_pick_with_value_diff("steal", 15),    # Steal
	]

	var reaches := grader.identify_reaches(picks, 15)

	t.assert_eq(reaches.size(), 2, "Should identify 2 reaches (diff <= -15)")

	# Verify sorted by value_diff (biggest reach first = most negative)
	t.assert_eq(reaches[0].get("player_id"), "reach2", "Biggest reach should be first")
	t.assert_eq(reaches[1].get("player_id"), "reach1", "Second reach should be second")


## Test: Determinism - same inputs always produce same outputs
func _test_determinism_same_inputs_same_outputs(t) -> void:
	var results := []

	for iteration in range(3):
		var grader := DraftGrader.new()

		var player := _make_test_player("LB", 77.0)
		player["scheme_fit"] = {"4_3_under": 85.0}

		var grade := grader.grade_pick(
			player,
			45,
			2,
			{"LB": 1.25},
			"4_3_under",
			50,
			{},
			{}
		)

		results.append({
			"letter": grade.get("letter_grade"),
			"overall": grade.get("overall_score"),
			"value": grade.get("value_score"),
			"need": grade.get("need_score"),
			"fit": grade.get("fit_score")
		})

	# All iterations should be identical
	t.assert_eq(
		results[0]["letter"],
		results[1]["letter"],
		"Letter grade should be deterministic"
	)
	t.assert_eq(
		results[0]["overall"],
		results[1]["overall"],
		"Overall score should be deterministic"
	)
	t.assert_eq(
		results[1]["overall"],
		results[2]["overall"],
		"Overall score should be deterministic (iter 2)"
	)
	t.assert_eq(
		results[0]["value"],
		results[1]["value"],
		"Value score should be deterministic"
	)


# =============================================================================
# Test Helpers
# =============================================================================

## Create a test player with specified position and rating
func _make_test_player(position: String, rating: float) -> Dictionary:
	return {
		"player_id": "test_player_%d" % randi(),
		"name": "Test Player",
		"position": position,
		"composite_score": rating,
		"age": 22
	}


## Create a mock pick record with grade
func _make_mock_pick_with_grade(
	player_id: String,
	value: float,
	need: float,
	fit: float
) -> Dictionary:
	var overall := (value * 0.5) + (need * 0.3) + (fit * 0.2)
	return {
		"player_id": player_id,
		"pick": 50,
		"team_id": "team1",
		"grade": {
			"letter_grade": "B",
			"overall_score": overall,
			"value_score": value,
			"need_score": need,
			"fit_score": fit,
			"factors": {"value_diff": 0}
		}
	}


## Create a mock pick record with specific value_diff
func _make_mock_pick_with_value_diff(player_id: String, value_diff: int) -> Dictionary:
	return {
		"player_id": player_id,
		"pick": 50,
		"team_id": "team1",
		"grade": {
			"letter_grade": "B" if value_diff >= 0 else "C",
			"overall_score": 75.0,
			"factors": {"value_diff": value_diff}
		}
	}
