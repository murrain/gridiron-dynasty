## GdUnit4 test suite for HighSchoolAssignment
##
## Validates player assignment to high schools based on weighted scoring.
## Migrated from test_high_school_assignment.gd
extends GdUnitTestSuite

const HighSchoolAssignment = preload("res://scripts/world/HighSchoolAssignment.gd")


func _get_test_players() -> Array:
	return [
		{"player_id": "p1", "stats": {"speed": 80.0}, "home_region": "north", "proximity_bias": 1.0},
		{"player_id": "p2", "stats": {"speed": 60.0}, "home_region": "south", "proximity_bias": 0.5}
	]


func _get_test_schools() -> Array:
	return [
		{"id": "s1", "region": "north", "eliteness": 80.0, "capacity": 1},
		{"id": "s2", "region": "south", "eliteness": 60.0, "capacity": 1}
	]


func _get_test_config() -> Dictionary:
	return {
		"assignment": {
			"eliteness_weight": 0.4,
			"player_strength_weight": 0.4,
			"proximity_weight": 0.2,
			"region_match_multiplier": 1.5,
			"outlier_chance": 0.0
		}
	}


func test_assigns_both_players() -> void:
	var assigner := HighSchoolAssignment.new()
	var result := assigner.assign(_get_test_players(), _get_test_schools(), _get_test_config(), 123)

	assert_int(int(result.get("assigned", 0))).is_equal(2)


func test_assigned_players_have_school_id() -> void:
	var assigner := HighSchoolAssignment.new()
	var result := assigner.assign(_get_test_players(), _get_test_schools(), _get_test_config(), 123)
	var updated := result.get("players", []) as Array

	assert_bool((updated[0] as Dictionary).has("hs_school_id")).is_true()
	assert_bool((updated[1] as Dictionary).has("hs_school_id")).is_true()


func test_respects_school_capacity() -> void:
	var players := _get_test_players()
	var schools := _get_test_schools()
	schools[0]["assigned_count"] = 1
	schools[1]["assigned_count"] = 1

	var assigner := HighSchoolAssignment.new()
	var result := assigner.assign(players, schools, _get_test_config(), 456)

	assert_int(int(result.get("unassigned", 0))).is_equal(2)


func test_determinism() -> void:
	var assigner := HighSchoolAssignment.new()
	var result1 := assigner.assign(_get_test_players(), _get_test_schools(), _get_test_config(), 789)
	var result2 := assigner.assign(_get_test_players(), _get_test_schools(), _get_test_config(), 789)

	var players1 := result1.get("players", []) as Array
	var players2 := result2.get("players", []) as Array

	for i in range(players1.size()):
		var p1 := players1[i] as Dictionary
		var p2 := players2[i] as Dictionary
		assert_that(p1.get("hs_school_id")).is_equal(p2.get("hs_school_id"))


func test_region_matching_affects_assignment() -> void:
	var players := [
		{"player_id": "p1", "stats": {"speed": 70.0}, "home_region": "north", "proximity_bias": 1.0}
	]
	var schools := [
		{"id": "s1", "region": "north", "eliteness": 60.0, "capacity": 1},
		{"id": "s2", "region": "south", "eliteness": 80.0, "capacity": 1}
	]
	var config := {
		"assignment": {
			"eliteness_weight": 0.3,
			"player_strength_weight": 0.2,
			"proximity_weight": 0.5,
			"region_match_multiplier": 2.0,
			"outlier_chance": 0.0
		}
	}

	var assigner := HighSchoolAssignment.new()
	var result := assigner.assign(players, schools, config, 111)
	var updated := result.get("players", []) as Array
	var assigned_school := String((updated[0] as Dictionary).get("hs_school_id", ""))

	# With high proximity weight and region match multiplier, north player should prefer north school
	assert_str(assigned_school).is_equal("s1")
