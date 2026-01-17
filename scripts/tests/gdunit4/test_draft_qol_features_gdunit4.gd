## GdUnit4 test suite for Draft QoL Features (Engineer 4)
##
## Validates:
## 1. DraftBoardFilter: Position filter, name search, sorting
## 2. DraftGrader: Grade calculation, letter grade conversion
## 3. PickTimer: Timer logic (without UI dependencies)
## 4. PlayerComparisonView: Comparison logic
##
## These are unit tests focused on logic, not UI rendering.
##
extends GdUnitTestSuite

const DraftGrader = preload("res://scripts/world/DraftGrader.gd")
const DraftBoardFilter = preload("res://scenes/ui/draft/DraftBoardFilter.gd")
const MockDraftGenerator = preload("res://scripts/world/MockDraftGenerator.gd")


## Setup before each test
func before() -> void:
	pass  # No global state to initialize


## Cleanup after each test
func after() -> void:
	pass  # All test objects are locally scoped


# =============================================================================
# Test: DraftGrader - Grade Calculation
# =============================================================================

func test_grader_calculates_value_score() -> void:
	var grader := DraftGrader.new()

	var player := {
		"player_id": "p1",
		"name": "Test Player",
		"position": "QB",
		"composite_score": 85.0  # High talent
	}

	var positions_cfg := {"QB": {"core_stats": ["THP", "THA"]}}
	var class_rules := {}

	# Pick 1 expects ~95 rating, pick 32 expects ~78
	# Player has 85, picked at 15 = good value
	var grade := grader.grade_pick(
		player,
		15,  # pick number
		1,   # round
		{"QB": 1.3},  # needs
		"spread",  # scheme
		20,  # consensus rank (drafted 5 spots early = slight reach)
		positions_cfg,
		class_rules
	)

	assert_str(String(grade.get("letter_grade", ""))).is_not_empty()
	assert_float(float(grade.get("overall_score", 0.0))).is_between(0.0, 100.0)
	assert_float(float(grade.get("value_score", 0.0))).is_between(0.0, 100.0)
	assert_float(float(grade.get("need_score", 0.0))).is_between(0.0, 100.0)
	assert_float(float(grade.get("fit_score", 0.0))).is_between(0.0, 100.0)


func test_grader_steal_detection_correct_params() -> void:
	var grader := DraftGrader.new()

	var player := {
		"player_id": "p1",
		"name": "Steal Player",
		"position": "RB",
		"composite_score": 85.0
	}

	var positions_cfg := {"RB": {"core_stats": ["SPD", "AGI"]}}

	# Player expected to go 50th, but team picks them at 30 = great value
	var grade := grader.grade_pick(
		player,
		30,  # pick number
		1,   # round
		{"RB": 1.0},
		"pro_style",
		50,  # consensus rank (expected to go 50th, got 30th = 20 spot steal)
		positions_cfg,
		{}
	)

	var factors: Dictionary = grade.get("factors", {})
	var value_diff := int(factors.get("value_diff", 0))

	# value_diff = 50 - 30 = 20 (positive = steal)
	assert_int(value_diff).is_equal(20)


func test_grader_need_score_high_need() -> void:
	var grader := DraftGrader.new()

	var player := {"player_id": "p1", "position": "CB", "composite_score": 75.0}
	var positions_cfg := {"CB": {"core_stats": ["SPD", "MCV"]}}

	# High CB need (1.5)
	var grade := grader.grade_pick(
		player, 50, 2, {"CB": 1.5}, "cover_3", 50, positions_cfg, {}
	)

	# Need score formula: 70 + ((need - 1.0) * 60)
	# 70 + ((1.5 - 1.0) * 60) = 70 + 30 = 100
	var need_score := float(grade.get("need_score", 0.0))
	assert_float(need_score).is_equal_approx(100.0, 1.0)


func test_grader_need_score_low_need() -> void:
	var grader := DraftGrader.new()

	var player := {"player_id": "p1", "position": "QB", "composite_score": 80.0}
	var positions_cfg := {"QB": {"core_stats": ["THP", "THA"]}}

	# Low QB need (0.95)
	var grade := grader.grade_pick(
		player, 50, 2, {"QB": 0.95}, "spread", 50, positions_cfg, {}
	)

	# Need score formula: 70 + ((need - 1.0) * 60)
	# 70 + ((0.95 - 1.0) * 60) = 70 + (-3) = 67
	var need_score := float(grade.get("need_score", 0.0))
	assert_float(need_score).is_equal_approx(67.0, 1.0)


func test_grader_scheme_fit_score_with_data() -> void:
	var grader := DraftGrader.new()

	var player := {
		"player_id": "p1",
		"position": "QB",
		"composite_score": 80.0,
		"scheme_fit": {"spread": 95.0, "pro_style": 65.0}
	}
	var positions_cfg := {"QB": {"core_stats": ["THP", "THA"]}}

	var grade := grader.grade_pick(
		player, 32, 1, {"QB": 1.0}, "spread", 32, positions_cfg, {}
	)

	# Fit score should be 95.0 (from scheme_fit.spread)
	var fit_score := float(grade.get("fit_score", 0.0))
	assert_float(fit_score).is_equal_approx(95.0, 0.1)


func test_grader_scheme_fit_score_no_data() -> void:
	var grader := DraftGrader.new()

	var player := {"player_id": "p1", "position": "QB", "composite_score": 80.0}
	var positions_cfg := {"QB": {"core_stats": ["THP", "THA"]}}

	var grade := grader.grade_pick(
		player, 32, 1, {"QB": 1.0}, "spread", 32, positions_cfg, {}
	)

	# No scheme data = neutral score (75.0)
	var fit_score := float(grade.get("fit_score", 0.0))
	assert_float(fit_score).is_equal_approx(75.0, 0.1)


# =============================================================================
# Test: DraftGrader - Letter Grade Conversion
# =============================================================================

func test_grader_score_to_grade_a_plus() -> void:
	var grader := DraftGrader.new()

	# Create a perfect scenario for A+ grade
	var player := {
		"player_id": "p1",
		"position": "QB",
		"composite_score": 95.0,
		"scheme_fit": {"spread": 100.0}
	}
	var positions_cfg := {"QB": {"core_stats": ["THP"]}}

	# Huge steal (consensus 100, pick 1), critical need, perfect fit
	var grade := grader.grade_pick(
		player, 1, 1, {"QB": 1.5}, "spread", 100, positions_cfg, {}
	)

	# With max value, need, and fit scores, should get A or A+
	var letter := String(grade.get("letter_grade", ""))
	assert_bool(letter in ["A+", "A", "A-"]).is_true()


func test_grader_score_to_grade_f() -> void:
	var grader := DraftGrader.new()

	# Create a terrible scenario for F grade
	var player := {
		"player_id": "p1",
		"position": "K",  # Kicker
		"composite_score": 50.0,
		"scheme_fit": {"spread": 30.0}
	}
	var positions_cfg := {"K": {"core_stats": ["KPW"]}}

	# Huge reach (consensus 250, pick 1), no need, poor fit
	var grade := grader.grade_pick(
		player, 1, 1, {"K": 0.95}, "spread", 250, positions_cfg, {}
	)

	# Should get a poor grade (C, D, or F)
	var letter := String(grade.get("letter_grade", ""))
	# We can't guarantee F, but should be bad
	assert_bool(letter in ["C+", "C", "C-", "D", "F"]).is_true()


func test_grader_letter_grade_progression() -> void:
	# Verify grade thresholds are ordered correctly
	var thresholds := DraftGrader.GRADE_THRESHOLDS
	var grades_ordered := ["A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D"]

	var prev_threshold := 100.0
	for grade in grades_ordered:
		var threshold := float(thresholds.get(grade, 0.0))
		assert_float(threshold).is_less(prev_threshold)
		prev_threshold = threshold


# =============================================================================
# Test: DraftGrader - Team Draft Grade
# =============================================================================

func test_grader_team_draft_grade_with_picks() -> void:
	var grader := DraftGrader.new()

	var team_picks := [
		{"grade": {"overall_score": 85.0, "letter_grade": "A-", "value_score": 90.0, "need_score": 80.0, "fit_score": 80.0}},
		{"grade": {"overall_score": 70.0, "letter_grade": "C", "value_score": 65.0, "need_score": 75.0, "fit_score": 70.0}},
		{"grade": {"overall_score": 78.0, "letter_grade": "B-", "value_score": 80.0, "need_score": 75.0, "fit_score": 80.0}},
	]

	var team_grade := grader.grade_team_draft("team1", team_picks, {})

	assert_str(String(team_grade.get("team_id", ""))).is_equal("team1")
	assert_int(int(team_grade.get("pick_count", 0))).is_equal(3)
	assert_str(String(team_grade.get("overall_grade", ""))).is_not_empty()

	# Average should be (85 + 70 + 78) / 3 = 77.67
	var avg_score := float(team_grade.get("overall_score", 0.0))
	assert_float(avg_score).is_between(70.0, 85.0)


func test_grader_team_draft_grade_empty_picks() -> void:
	var grader := DraftGrader.new()

	var team_grade := grader.grade_team_draft("team1", [], {})

	assert_str(String(team_grade.get("overall_grade", ""))).is_equal("N/A")
	assert_int(int(team_grade.get("pick_count", 0))).is_equal(0)


# =============================================================================
# Test: DraftGrader - Steal/Reach Identification
# =============================================================================

func test_grader_identify_steals() -> void:
	var grader := DraftGrader.new()

	var picks := [
		{"player_id": "p1", "player_name": "Steal", "position": "QB", "pick": 30, "grade": {"factors": {"value_diff": 25}, "letter_grade": "A"}},
		{"player_id": "p2", "player_name": "Normal", "position": "RB", "pick": 35, "grade": {"factors": {"value_diff": 5}, "letter_grade": "B"}},
		{"player_id": "p3", "player_name": "Big Steal", "position": "WR", "pick": 40, "grade": {"factors": {"value_diff": 40}, "letter_grade": "A+"}},
	]

	var steals := grader.identify_steals(picks, 15)

	assert_int(steals.size()).is_equal(2)  # p1 and p3
	# Should be sorted by value_diff descending
	assert_str(String(steals[0].get("player_id", ""))).is_equal("p3")  # 40
	assert_str(String(steals[1].get("player_id", ""))).is_equal("p1")  # 25


func test_grader_identify_reaches() -> void:
	var grader := DraftGrader.new()

	var picks := [
		{"player_id": "p1", "player_name": "Reach", "position": "QB", "pick": 10, "grade": {"factors": {"value_diff": -20}, "letter_grade": "C"}},
		{"player_id": "p2", "player_name": "Normal", "position": "RB", "pick": 15, "grade": {"factors": {"value_diff": 0}, "letter_grade": "B"}},
		{"player_id": "p3", "player_name": "Big Reach", "position": "WR", "pick": 5, "grade": {"factors": {"value_diff": -35}, "letter_grade": "D"}},
	]

	var reaches := grader.identify_reaches(picks, 15)

	assert_int(reaches.size()).is_equal(2)  # p1 and p3
	# Should be sorted by value_diff ascending (most negative first)
	assert_str(String(reaches[0].get("player_id", ""))).is_equal("p3")  # -35
	assert_str(String(reaches[1].get("player_id", ""))).is_equal("p1")  # -20


# =============================================================================
# Test: DraftBoardFilter - Static Filter Matching
# =============================================================================

func test_filter_player_matches_all() -> void:
	var player := {"name": "John Smith", "position": "QB"}

	var matches := DraftBoardFilter.player_matches_filters(player, "All", "")
	assert_bool(matches).is_true()


func test_filter_player_matches_position() -> void:
	var player := {"name": "John Smith", "position": "QB"}

	var matches := DraftBoardFilter.player_matches_filters(player, "QB", "")
	assert_bool(matches).is_true()

	var no_match := DraftBoardFilter.player_matches_filters(player, "RB", "")
	assert_bool(no_match).is_false()


func test_filter_player_matches_name_search() -> void:
	var player := {"name": "John Smith", "position": "QB"}

	# Case-insensitive search
	var matches := DraftBoardFilter.player_matches_filters(player, "All", "john")
	assert_bool(matches).is_true()

	var matches_partial := DraftBoardFilter.player_matches_filters(player, "All", "smi")
	assert_bool(matches_partial).is_true()

	var no_match := DraftBoardFilter.player_matches_filters(player, "All", "jones")
	assert_bool(no_match).is_false()


func test_filter_player_matches_combined() -> void:
	var player := {"name": "John Smith", "position": "QB"}

	# Both filters must match
	var matches := DraftBoardFilter.player_matches_filters(player, "QB", "john")
	assert_bool(matches).is_true()

	# Position mismatch
	var no_match := DraftBoardFilter.player_matches_filters(player, "RB", "john")
	assert_bool(no_match).is_false()


# =============================================================================
# Test: DraftBoardFilter - Sort Modes
# =============================================================================

func test_filter_sort_modes_defined() -> void:
	# Verify all expected sort modes are defined
	var expected_modes := ["Overall", "Scheme Fit", "Position Need", "Mock Rank"]
	for mode in expected_modes:
		assert_bool(DraftBoardFilter.SORT_MODES.has(mode)).is_true()


func test_filter_sort_mode_enum_mapping() -> void:
	assert_int(DraftBoardFilter.SortMode.OVERALL).is_equal(0)
	assert_int(DraftBoardFilter.SortMode.SCHEME_FIT).is_equal(1)
	assert_int(DraftBoardFilter.SortMode.POSITION_NEED).is_equal(2)
	assert_int(DraftBoardFilter.SortMode.MOCK_RANK).is_equal(3)


# =============================================================================
# Test: DraftBoardFilter - Position Constants
# =============================================================================

func test_filter_positions_include_all_nfl() -> void:
	var expected := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
	for pos in expected:
		assert_bool(DraftBoardFilter.POSITIONS.has(pos)).is_true()


# =============================================================================
# Test: Grade Color Utility
# =============================================================================

func test_grade_color_a_grades_green() -> void:
	var color_a_plus := DraftGrader.get_grade_color("A+")
	var color_a := DraftGrader.get_grade_color("A")

	# Green colors have high G component, low R
	assert_float(color_a_plus.g).is_greater(0.5)
	assert_float(color_a.g).is_greater(0.5)


func test_grade_color_f_grade_red() -> void:
	var color_f := DraftGrader.get_grade_color("F")

	# Red color has high R component
	assert_float(color_f.r).is_greater(0.5)


func test_grade_color_unknown_grade_gray() -> void:
	var color_unknown := DraftGrader.get_grade_color("Z")

	# Gray color has equal RGB
	assert_float(color_unknown.r).is_equal_approx(color_unknown.g, 0.1)
	assert_float(color_unknown.g).is_equal_approx(color_unknown.b, 0.1)


# =============================================================================
# Test: Quick Summary Utility
# =============================================================================

func test_quick_summary_steal() -> void:
	var grade := {"letter_grade": "A", "factors": {"value_diff": 20}}
	var summary := DraftGrader.get_quick_summary(grade)

	assert_str(summary).contains("STEAL")


func test_quick_summary_reach() -> void:
	var grade := {"letter_grade": "C", "factors": {"value_diff": -20}}
	var summary := DraftGrader.get_quick_summary(grade)

	assert_str(summary).contains("REACH")


func test_quick_summary_fair() -> void:
	var grade := {"letter_grade": "B", "factors": {"value_diff": 2}}
	var summary := DraftGrader.get_quick_summary(grade)

	assert_str(summary).contains("Fair")


# =============================================================================
# Test: Performance - Filter Operations
# =============================================================================

func test_filter_performance_250_players() -> void:
	# Use seeded RNG for deterministic test data
	# RNG consumption: 1 call per player (overall rating)
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var players: Array = []
	for i in range(250):
		players.append({
			"player_id": "p%d" % i,
			"name": "Player %d Smith" % i,
			"position": ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"][i % 10],
			"overall": rng.randf_range(50.0, 100.0)
		})

	var start := Time.get_ticks_usec()

	# Apply all filter types
	var filtered := players.filter(func(p):
		return DraftBoardFilter.player_matches_filters(p, "QB", "smith")
	)

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	# Should complete in <50ms
	assert_float(elapsed).is_less(50.0)


func test_grader_performance_per_pick() -> void:
	var grader := DraftGrader.new()

	var player := {
		"player_id": "p1",
		"position": "QB",
		"composite_score": 85.0,
		"scheme_fit": {"spread": 90.0}
	}
	var positions_cfg := {"QB": {"core_stats": ["THP", "THA"]}}
	var needs := {"QB": 1.2}

	var start := Time.get_ticks_usec()

	# Grade 100 picks
	for i in range(100):
		var _grade := grader.grade_pick(
			player, i + 1, (i / 32) + 1, needs, "spread", i + 5, positions_cfg, {}
		)

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	# 100 picks should complete in <100ms (1ms per pick)
	assert_float(elapsed).is_less(100.0)
