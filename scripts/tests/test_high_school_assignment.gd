extends RefCounted

func run(t: TestHelpers) -> void:
	var players := [
		{"player_id": "p1", "stats": {"speed": 80.0}, "home_region": "north", "proximity_bias": 1.0},
		{"player_id": "p2", "stats": {"speed": 60.0}, "home_region": "south", "proximity_bias": 0.5}
	]
	var schools := [
		{"id": "s1", "region": "north", "eliteness": 80.0, "capacity": 1},
		{"id": "s2", "region": "south", "eliteness": 60.0, "capacity": 1}
	]
	var config := {
		"assignment": {
			"eliteness_weight": 0.4,
			"player_strength_weight": 0.4,
			"proximity_weight": 0.2,
			"region_match_multiplier": 1.5,
			"outlier_chance": 0.0
		}
	}

	var assigner := HighSchoolAssignment.new()
	var result := assigner.assign(players, schools, config, 123)
	t.assert_eq(result.get("assigned"), 2, "assignment should assign both")
	var updated := result.get("players", []) as Array
	t.assert_true(updated[0].has("hs_school_id"), "assigned player has school id")
	t.assert_true(updated[1].has("hs_school_id"), "assigned player has school id")

	schools[0]["assigned_count"] = 1
	schools[1]["assigned_count"] = 1
	var result_full := assigner.assign(players, schools, config, 456)
	t.assert_eq(result_full.get("unassigned"), 2, "assignment should respect capacity")
