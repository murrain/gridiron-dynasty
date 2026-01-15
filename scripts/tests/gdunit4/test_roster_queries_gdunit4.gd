## GdUnit4 test suite for RosterQueries
##
## Tests all static query functions for roster analysis:
## - Position grouping
## - Position strength calculation
## - Position depth analysis
## - Age distribution
## - Experience distribution
##
## Migrated from test_roster_queries.gd
extends GdUnitTestSuite

const RosterQueries = preload("res://scripts/ui/world_explorer/queries/RosterQueries.gd")
const StatQueries = preload("res://scripts/ui/world_explorer/queries/StatQueries.gd")


func test_position_groups_has_offense_key() -> void:
	var roster := _get_full_roster()
	var groups := RosterQueries.get_position_groups(roster)

	assert_bool(groups.has("offense")).is_true()


func test_position_groups_has_defense_key() -> void:
	var roster := _get_full_roster()
	var groups := RosterQueries.get_position_groups(roster)

	assert_bool(groups.has("defense")).is_true()


func test_position_groups_has_special_teams_key() -> void:
	var roster := _get_full_roster()
	var groups := RosterQueries.get_position_groups(roster)

	assert_bool(groups.has("special_teams")).is_true()


func test_position_groups_offense_count() -> void:
	var roster := _get_full_roster()
	var groups := RosterQueries.get_position_groups(roster)

	assert_int(groups["offense"].size()).is_equal(7)


func test_position_groups_defense_count() -> void:
	var roster := _get_full_roster()
	var groups := RosterQueries.get_position_groups(roster)

	assert_int(groups["defense"].size()).is_equal(6)


func test_position_groups_special_teams_count() -> void:
	var roster := _get_full_roster()
	var groups := RosterQueries.get_position_groups(roster)

	assert_int(groups["special_teams"].size()).is_equal(2)


func test_position_strength_qb_reasonable() -> void:
	var roster := [
		{"position": "QB", "stats": {"throw_power": 80.0, "throw_accuracy": 85.0, "speed": 70.0}},
		{"position": "QB", "stats": {"throw_power": 75.0, "throw_accuracy": 80.0, "speed": 65.0}},
		{"position": "RB", "stats": {"speed": 90.0, "agility": 88.0, "strength": 75.0}}
	]

	var qb_strength := RosterQueries.calculate_position_strength(roster, "QB")

	assert_float(qb_strength).is_between(70.0, 85.0)
	assert_float(qb_strength).is_greater(0.0)


func test_position_strength_rb_reasonable() -> void:
	var roster := [
		{"position": "QB", "stats": {"throw_power": 80.0, "throw_accuracy": 85.0, "speed": 70.0}},
		{"position": "RB", "stats": {"speed": 90.0, "agility": 88.0, "strength": 75.0}}
	]

	var rb_strength := RosterQueries.calculate_position_strength(roster, "RB")

	assert_float(rb_strength).is_between(80.0, 90.0)


func test_position_strength_missing_position_is_zero() -> void:
	var roster := [
		{"position": "QB", "stats": {"throw_power": 80.0}},
		{"position": "RB", "stats": {"speed": 90.0}}
	]

	var wr_strength := RosterQueries.calculate_position_strength(roster, "WR")

	assert_float(wr_strength).is_equal(0.0)


func test_position_depth_counts() -> void:
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

	assert_int(depth.get("QB", 0)).is_equal(3)
	assert_int(depth.get("RB", 0)).is_equal(2)
	assert_int(depth.get("WR", 0)).is_equal(5)
	assert_int(depth.get("TE", 0)).is_equal(0)


func test_age_distribution_min() -> void:
	var roster := _get_age_roster()
	var dist := RosterQueries.get_age_distribution(roster)

	assert_int(int(dist["min"])).is_equal(18)


func test_age_distribution_max() -> void:
	var roster := _get_age_roster()
	var dist := RosterQueries.get_age_distribution(roster)

	assert_int(int(dist["max"])).is_equal(25)


func test_age_distribution_avg() -> void:
	var roster := _get_age_roster()
	var dist := RosterQueries.get_age_distribution(roster)

	assert_float(float(dist["avg"])).is_equal_approx(21.5, 0.1)


func test_age_distribution_median_even() -> void:
	var roster := _get_age_roster()
	var dist := RosterQueries.get_age_distribution(roster)

	assert_float(float(dist["median"])).is_equal_approx(21.5, 0.1)


func test_age_distribution_median_odd() -> void:
	var roster_odd := [
		{"age": 20},
		{"age": 22},
		{"age": 24}
	]
	var dist := RosterQueries.get_age_distribution(roster_odd)

	assert_float(float(dist["median"])).is_equal(22.0)


func test_experience_distribution_college() -> void:
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

	assert_int(dist.get("freshmen", 0)).is_equal(3)
	assert_int(dist.get("sophomores", 0)).is_equal(2)
	assert_int(dist.get("juniors", 0)).is_equal(2)
	assert_int(dist.get("seniors", 0)).is_equal(1)
	assert_int(dist.get("fifth_year", 0)).is_equal(1)


func test_experience_distribution_nfl() -> void:
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

	assert_int(dist.get("rookies", 0)).is_equal(2)
	assert_int(dist.get("year_2", 0)).is_equal(1)
	assert_int(dist.get("year_3", 0)).is_equal(1)
	assert_int(dist.get("year_4", 0)).is_equal(1)
	assert_int(dist.get("year_5_plus", 0)).is_equal(3)


func test_experience_distribution_hs() -> void:
	var hs_roster := [
		{"position": "QB", "hs_year": 1},
		{"position": "RB", "hs_year": 2},
		{"position": "WR", "hs_year": 2},
		{"position": "WR", "hs_year": 3},
		{"position": "TE", "hs_year": 4},
		{"position": "OL", "hs_year": 4}
	]

	var exp_dist := RosterQueries.get_experience_distribution(hs_roster, "hs")

	assert_int(exp_dist.get("year_1", 0)).is_equal(1)
	assert_int(exp_dist.get("year_2", 0)).is_equal(2)
	assert_int(exp_dist.get("year_3", 0)).is_equal(1)
	assert_int(exp_dist.get("year_4", 0)).is_equal(2)


func test_empty_roster_groups() -> void:
	var empty_roster: Array = []
	var groups := RosterQueries.get_position_groups(empty_roster)

	assert_int(groups["offense"].size()).is_equal(0)
	assert_int(groups["defense"].size()).is_equal(0)
	assert_int(groups["special_teams"].size()).is_equal(0)


func test_empty_roster_strength() -> void:
	var empty_roster: Array = []
	var strength := RosterQueries.calculate_position_strength(empty_roster, "QB")

	assert_float(strength).is_equal(0.0)


func test_empty_roster_depth() -> void:
	var empty_roster: Array = []
	var depth := RosterQueries.analyze_position_depth(empty_roster)

	assert_int(depth.size()).is_equal(0)


func test_empty_roster_age_distribution() -> void:
	var empty_roster: Array = []
	var dist := RosterQueries.get_age_distribution(empty_roster)

	assert_int(int(dist["min"])).is_equal(0)
	assert_int(int(dist["max"])).is_equal(0)


func test_empty_roster_experience_distribution() -> void:
	var empty_roster: Array = []
	var exp_dist := RosterQueries.get_experience_distribution(empty_roster, "college")

	assert_int(exp_dist.size()).is_equal(0)


# --- Helper functions ---

func _get_full_roster() -> Array:
	return [
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


func _get_age_roster() -> Array:
	return [
		{"age": 18},
		{"age": 19},
		{"age": 20},
		{"age": 21},
		{"age": 22},
		{"age": 23},
		{"age": 24},
		{"age": 25}
	]
