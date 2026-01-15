## GdUnit4 test suite for TeamImpact
##
## Validates team value computation including leverage multipliers and position importance.
## Migrated from test_team_impact.gd
extends GdUnitTestSuite

const TeamImpact = preload("res://scripts/core/valuation/TeamImpact.gd")
const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")


func _default_config() -> Dictionary:
	return {
		"replacement_levels": {
			"QB": 55.0,
			"RB": 62.0,
			"WR": 58.0,
			"TE": 56.0,
			"OL": 54.0,
			"DL": 57.0,
			"EDGE": 52.0,
			"LB": 58.0,
			"CB": 53.0,
			"S": 57.0,
			"K": 65.0,
			"P": 65.0,
			"ATH": 55.0
		},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {
				"QB": 2.5,
				"EDGE": 1.4,
				"CB": 1.3,
				"WR": 1.2,
				"OL": 1.1,
				"DL": 1.1,
				"LB": 1.0,
				"S": 0.95,
				"TE": 0.9,
				"RB": 0.8,
				"K": 0.5,
				"P": 0.4,
				"ATH": 1.0
			}
		}
	}


func test_compute_team_value_basic() -> void:
	var config := _default_config()
	var player := {"id": "qb1", "position": "QB", "eval_score": 85.0}
	var roster := [player]

	var result := TeamImpact.compute_team_value(player, roster, config)

	assert_str(String(result["player_id"])).is_equal("qb1")
	assert_str(String(result["position"])).is_equal("QB")
	assert_float(float(result["player_score"])).is_equal_approx(85.0, 0.001)
	assert_float(float(result["replacement_score"])).is_equal_approx(55.0, 0.001)
	assert_float(float(result["raw_impact"])).is_equal_approx(30.0, 0.001)
	assert_int(int(result["depth"])).is_equal(0)
	assert_float(float(result["leverage_multiplier"])).is_equal_approx(1.4, 0.001)
	assert_float(float(result["position_importance"])).is_equal_approx(2.5, 0.001)
	assert_float(float(result["team_value"])).is_equal_approx(105.0, 0.001)


func test_no_backup_leverage() -> void:
	var config := _default_config()
	var qb1 := {"id": "qb1", "position": "QB", "eval_score": 85.0}
	var roster := [qb1]

	var result := TeamImpact.compute_team_value(qb1, roster, config)

	assert_float(float(result["leverage_multiplier"])).is_equal_approx(1.4, 0.001)
	assert_int(int(result["depth"])).is_equal(0)


func test_thin_depth_leverage() -> void:
	var config := _default_config()
	var qb1 := {"id": "qb1", "position": "QB", "eval_score": 85.0}
	var qb2 := {"id": "qb2", "position": "QB", "eval_score": 70.0}
	var roster := [qb1, qb2]

	var result := TeamImpact.compute_team_value(qb1, roster, config)

	assert_float(float(result["leverage_multiplier"])).is_equal_approx(1.15, 0.001)
	assert_int(int(result["depth"])).is_equal(1)


func test_deep_depth_no_leverage() -> void:
	var config := _default_config()
	var qb1 := {"id": "qb1", "position": "QB", "eval_score": 85.0}
	var qb2 := {"id": "qb2", "position": "QB", "eval_score": 70.0}
	var qb3 := {"id": "qb3", "position": "QB", "eval_score": 65.0}
	var roster := [qb1, qb2, qb3]

	var result := TeamImpact.compute_team_value(qb1, roster, config)

	assert_float(float(result["leverage_multiplier"])).is_equal_approx(1.0, 0.001)
	assert_int(int(result["depth"])).is_equal(2)


func test_replacement_uses_best_teammate() -> void:
	var config := _default_config()
	var qb1 := {"id": "qb1", "position": "QB", "eval_score": 90.0}
	var qb2 := {"id": "qb2", "position": "QB", "eval_score": 75.0}
	var qb3 := {"id": "qb3", "position": "QB", "eval_score": 70.0}
	var roster := [qb1, qb2, qb3]

	var result := TeamImpact.compute_team_value(qb1, roster, config)

	assert_float(float(result["replacement_score"])).is_equal_approx(75.0, 0.001)
	assert_float(float(result["raw_impact"])).is_equal_approx(15.0, 0.001)


func test_position_importance_qb() -> void:
	var config := _default_config()
	var qb := {"id": "qb1", "position": "QB", "eval_score": 80.0}

	var result := TeamImpact.compute_team_value(qb, [qb], config)

	assert_float(float(result["position_importance"])).is_equal_approx(2.5, 0.001)


func test_position_importance_rb() -> void:
	var config := _default_config()
	var rb := {"id": "rb1", "position": "RB", "eval_score": 80.0}

	var result := TeamImpact.compute_team_value(rb, [rb], config)

	assert_float(float(result["position_importance"])).is_equal_approx(0.8, 0.001)


func test_position_importance_k() -> void:
	var config := _default_config()
	var k := {"id": "k1", "position": "K", "eval_score": 80.0}

	var result := TeamImpact.compute_team_value(k, [k], config)

	assert_float(float(result["position_importance"])).is_equal_approx(0.5, 0.001)


func test_position_importance_edge() -> void:
	var config := _default_config()
	var edge := {"id": "edge1", "position": "EDGE", "eval_score": 80.0}

	var result := TeamImpact.compute_team_value(edge, [edge], config)

	assert_float(float(result["position_importance"])).is_equal_approx(1.4, 0.001)


func test_qb_worth_more_than_rb_for_same_score() -> void:
	var config := _default_config()
	var qb := {"id": "qb1", "position": "QB", "eval_score": 80.0}
	var rb := {"id": "rb1", "position": "RB", "eval_score": 80.0}

	var qb_result := TeamImpact.compute_team_value(qb, [qb], config)
	var rb_result := TeamImpact.compute_team_value(rb, [rb], config)

	assert_float(float(qb_result["team_value"])).is_greater(float(rb_result["team_value"]))


func test_team_value_calculation_wr() -> void:
	var config := _default_config()
	var wr1 := {"id": "wr1", "position": "WR", "eval_score": 88.0}
	var wr2 := {"id": "wr2", "position": "WR", "eval_score": 72.0}
	var roster := [wr1, wr2]

	var result := TeamImpact.compute_team_value(wr1, roster, config)

	assert_float(float(result["replacement_score"])).is_equal_approx(72.0, 0.001)
	assert_float(float(result["raw_impact"])).is_equal_approx(16.0, 0.001)
	assert_int(int(result["depth"])).is_equal(1)
	assert_float(float(result["leverage_multiplier"])).is_equal_approx(1.15, 0.001)
	assert_float(float(result["position_importance"])).is_equal_approx(1.2, 0.001)
	assert_float(float(result["team_value"])).is_equal_approx(22.08, 0.001)


func test_below_replacement_player() -> void:
	var config := _default_config()
	var qb := {"id": "qb1", "position": "QB", "eval_score": 50.0}
	var roster := [qb]

	var result := TeamImpact.compute_team_value(qb, roster, config)

	assert_float(float(result["player_score"])).is_equal_approx(50.0, 0.001)
	assert_float(float(result["replacement_score"])).is_equal_approx(55.0, 0.001)
	assert_float(float(result["raw_impact"])).is_equal_approx(0.0, 0.001)
	assert_float(float(result["team_value"])).is_equal_approx(0.0, 0.001)


func test_config_overrides() -> void:
	var custom_config := {
		"replacement_levels": {"QB": 60.0},
		"team_impact": {
			"no_backup_multiplier": 2.0,
			"thin_depth_multiplier": 1.5,
			"position_win_impacts": {"QB": 3.0}
		}
	}
	var qb := {"id": "qb1", "position": "QB", "eval_score": 85.0}
	var roster := [qb]

	var result := TeamImpact.compute_team_value(qb, roster, custom_config)

	assert_float(float(result["replacement_score"])).is_equal_approx(60.0, 0.001)
	assert_float(float(result["raw_impact"])).is_equal_approx(25.0, 0.001)
	assert_float(float(result["leverage_multiplier"])).is_equal_approx(2.0, 0.001)
	assert_float(float(result["position_importance"])).is_equal_approx(3.0, 0.001)
	assert_float(float(result["team_value"])).is_equal_approx(150.0, 0.001)
