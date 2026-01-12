extends SceneTree

## Unit tests for RosterQueries utility class
##
## Tests all static query functions for roster analysis:
## - Position grouping
## - Position strength calculation
## - Position depth analysis
## - Age distribution
## - Experience distribution

const RosterQueries = preload("res://scripts/ui/world_explorer/queries/RosterQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")
const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

var test_helpers: TestHelpers

func _init() -> void:
	test_helpers = TestHelpers.new()

	print("=" .repeat(80))
	print("RosterQueries Tests")
	print("=" .repeat(80))

	test_position_groups()
	test_position_strength()
	test_position_depth()
	test_age_distribution()
	test_experience_distribution_college()
	test_experience_distribution_nfl()
	test_experience_distribution_hs()
	test_empty_roster_handling()

	# Report results
	print("=" .repeat(80))
	if test_helpers.failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("FAILURES:")
		for failure in test_helpers.failures:
			print("  - ", failure)
		quit(1)

## Test position group categorization
func test_position_groups() -> void:
	print("\n[TEST] Position Groups")

	var roster := [
		{"position": "QB", "id": "qb1"},
		{"position": "QB", "id": "qb2"},
		{"position": "RB", "id": "rb1"},
		{"position": "WR", "id": "wr1"},
		{"position": "WR", "id": "wr2"},
		{"position": "TE", "id": "te1"},
		{"position": "OL", "id": "ol1"},
		{"position": "DL", "id": "dl1"},
		{"position": "EDGE", "id": "edge1"},
		{"position": "LB", "id": "lb1"},
		{"position": "CB", "id": "cb1"},
		{"position": "CB", "id": "cb2"},
		{"position": "S", "id": "s1"},
		{"position": "K", "id": "k1"},
		{"position": "P", "id": "p1"}
	]

	var groups := RosterQueries.get_position_groups(roster)

	# Verify structure
	test_helpers.assert_true(groups.has("offense"), "Groups should have 'offense' key")
	test_helpers.assert_true(groups.has("defense"), "Groups should have 'defense' key")
	test_helpers.assert_true(groups.has("special_teams"), "Groups should have 'special_teams' key")

	# Verify counts
	test_helpers.assert_eq(groups["offense"].size(), 7, "Offense should have 7 players")
	test_helpers.assert_eq(groups["defense"].size(), 6, "Defense should have 6 players")
	test_helpers.assert_eq(groups["special_teams"].size(), 2, "Special teams should have 2 players")

	print("  ✓ Position groups categorized correctly")

## Test position strength calculation
func test_position_strength() -> void:
	print("\n[TEST] Position Strength")

	var roster := [
		{"position": "QB", "stats": {"throw_power": 80.0, "throw_accuracy": 85.0, "speed": 70.0}},
		{"position": "QB", "stats": {"throw_power": 75.0, "throw_accuracy": 80.0, "speed": 65.0}},
		{"position": "RB", "stats": {"speed": 90.0, "agility": 88.0, "strength": 75.0}}
	]

	var qb_strength := RosterQueries.calculate_position_strength(roster, "QB")
	var rb_strength := RosterQueries.calculate_position_strength(roster, "RB")
	var wr_strength := RosterQueries.calculate_position_strength(roster, "WR")

	# QB average should be around 77.5 (average of two QBs)
	test_helpers.assert_between(qb_strength, 70.0, 85.0, "QB strength should be reasonable")
	test_helpers.assert_true(qb_strength > 0.0, "QB strength should be positive")

	# RB average should be around 84.3
	test_helpers.assert_between(rb_strength, 80.0, 90.0, "RB strength should be reasonable")

	# WR should be 0 (no WRs on roster)
	test_helpers.assert_eq(wr_strength, 0.0, "WR strength should be 0 for missing position")

	print("  ✓ Position strength calculated correctly")

## Test position depth counting
func test_position_depth() -> void:
	print("\n[TEST] Position Depth")

	var roster := [
		{"position": "QB"},
		{"position": "QB"},
		{"position": "QB"},
		{"position": "RB"},
		{"position": "RB"},
		{"position": "WR"},
		{"position": "WR"},
		{"position": "WR"},
		{"position": "WR"},
		{"position": "WR"}
	]

	var depth := RosterQueries.analyze_position_depth(roster)

	test_helpers.assert_eq(depth.get("QB", 0), 3, "Should have 3 QBs")
	test_helpers.assert_eq(depth.get("RB", 0), 2, "Should have 2 RBs")
	test_helpers.assert_eq(depth.get("WR", 0), 5, "Should have 5 WRs")
	test_helpers.assert_eq(depth.get("TE", 0), 0, "Should have 0 TEs")

	print("  ✓ Position depth counted correctly")

## Test age distribution calculation
func test_age_distribution() -> void:
	print("\n[TEST] Age Distribution")

	var roster := [
		{"age": 18},
		{"age": 19},
		{"age": 20},
		{"age": 21},
		{"age": 22},
		{"age": 23},
		{"age": 24},
		{"age": 25}
	]

	var dist := RosterQueries.get_age_distribution(roster)

	test_helpers.assert_eq(dist["min"], 18, "Min age should be 18")
	test_helpers.assert_eq(dist["max"], 25, "Max age should be 25")
	test_helpers.assert_approx(dist["avg"], 21.5, 0.1, "Average age should be 21.5")
	test_helpers.assert_approx(dist["median"], 21.5, 0.1, "Median age should be 21.5")

	# Test odd number of players (median should be middle value)
	var roster_odd := [
		{"age": 20},
		{"age": 22},
		{"age": 24}
	]

	var dist_odd := RosterQueries.get_age_distribution(roster_odd)
	test_helpers.assert_eq(dist_odd["median"], 22.0, "Median should be 22 for odd count")

	print("  ✓ Age distribution calculated correctly")

## Test experience distribution for college
func test_experience_distribution_college() -> void:
	print("\n[TEST] Experience Distribution (College)")

	var roster := [
		{"college_year": 1},
		{"college_year": 1},
		{"college_year": 1},
		{"college_year": 2},
		{"college_year": 2},
		{"college_year": 3},
		{"college_year": 3},
		{"college_year": 4},
		{"college_year": 5}
	]

	var dist := RosterQueries.get_experience_distribution(roster, "college")

	test_helpers.assert_eq(dist.get("freshmen", 0), 3, "Should have 3 freshmen")
	test_helpers.assert_eq(dist.get("sophomores", 0), 2, "Should have 2 sophomores")
	test_helpers.assert_eq(dist.get("juniors", 0), 2, "Should have 2 juniors")
	test_helpers.assert_eq(dist.get("seniors", 0), 1, "Should have 1 senior")
	test_helpers.assert_eq(dist.get("fifth_year", 0), 1, "Should have 1 fifth year")

	print("  ✓ College experience distribution calculated correctly")

## Test experience distribution for NFL
func test_experience_distribution_nfl() -> void:
	print("\n[TEST] Experience Distribution (NFL)")

	var roster := [
		{"nfl_year": 1},
		{"nfl_year": 1},
		{"nfl_year": 2},
		{"nfl_year": 3},
		{"nfl_year": 4},
		{"nfl_year": 5},
		{"nfl_year": 7},
		{"nfl_year": 10}
	]

	var dist := RosterQueries.get_experience_distribution(roster, "nfl")

	test_helpers.assert_eq(dist.get("rookies", 0), 2, "Should have 2 rookies")
	test_helpers.assert_eq(dist.get("year_2", 0), 1, "Should have 1 year 2 player")
	test_helpers.assert_eq(dist.get("year_3", 0), 1, "Should have 1 year 3 player")
	test_helpers.assert_eq(dist.get("year_4", 0), 1, "Should have 1 year 4 player")
	test_helpers.assert_eq(dist.get("year_5_plus", 0), 3, "Should have 3 year 5+ players")

	print("  ✓ NFL experience distribution calculated correctly")

## Test experience distribution for high school
func test_experience_distribution_hs() -> void:
	print("\n[TEST] Experience Distribution (High School)")

	var hs_roster = [
		{"position": "QB", "hs_year": 1},
		{"position": "RB", "hs_year": 2},
		{"position": "WR", "hs_year": 2},
		{"position": "WR", "hs_year": 3},
		{"position": "TE", "hs_year": 4},
		{"position": "OL", "hs_year": 4}
	]

	var exp_dist = RosterQueries.get_experience_distribution(hs_roster, "hs")

	test_helpers.assert_eq(exp_dist.get("year_1", 0), 1, "Should have 1 year 1 player")
	test_helpers.assert_eq(exp_dist.get("year_2", 0), 2, "Should have 2 year 2 players")
	test_helpers.assert_eq(exp_dist.get("year_3", 0), 1, "Should have 1 year 3 player")
	test_helpers.assert_eq(exp_dist.get("year_4", 0), 2, "Should have 2 year 4 players")

	print("  ✓ HS experience distribution working correctly")

## Test empty roster handling
func test_empty_roster_handling() -> void:
	print("\n[TEST] Empty Roster Handling")

	var empty_roster: Array = []

	# Test all functions with empty roster
	var groups := RosterQueries.get_position_groups(empty_roster)
	test_helpers.assert_eq(groups["offense"].size(), 0, "Empty roster should have 0 offense")
	test_helpers.assert_eq(groups["defense"].size(), 0, "Empty roster should have 0 defense")
	test_helpers.assert_eq(groups["special_teams"].size(), 0, "Empty roster should have 0 special teams")

	var strength := RosterQueries.calculate_position_strength(empty_roster, "QB")
	test_helpers.assert_eq(strength, 0.0, "Empty roster should have 0 strength")

	var depth := RosterQueries.analyze_position_depth(empty_roster)
	test_helpers.assert_eq(depth.size(), 0, "Empty roster should have empty depth map")

	var age_dist := RosterQueries.get_age_distribution(empty_roster)
	test_helpers.assert_eq(age_dist["min"], 0, "Empty roster should have min age 0")
	test_helpers.assert_eq(age_dist["max"], 0, "Empty roster should have max age 0")

	var exp_dist := RosterQueries.get_experience_distribution(empty_roster, "college")
	test_helpers.assert_eq(exp_dist.size(), 0, "Empty roster should have empty experience distribution")

	print("  ✓ Empty roster handled gracefully")
