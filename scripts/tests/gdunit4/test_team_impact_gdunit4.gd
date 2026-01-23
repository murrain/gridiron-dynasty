extends GdUnitTestSuite
class_name TestTeamImpactGdUnit4

const TeamImpact = preload("res://scripts/core/valuation/TeamImpact.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

## Test starter with no backup gets leverage multiplier
func test_starter_no_backup_leverage() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var roster := [player]  # Only this player at QB

	var result := TeamImpact.compute_team_value(player, roster, config)

	assert_float(result["leverage_multiplier"]).is_equal(1.4)
	assert_int(result["depth"]).is_equal(0)

## Test starter with one backup gets thin depth multiplier
func test_starter_with_one_backup() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var backup := {"id": "QB2", "position": "QB", "eval_score": 60.0}
	var roster := [player, backup]

	var result := TeamImpact.compute_team_value(player, roster, config)

	assert_float(result["leverage_multiplier"]).is_equal(1.15)
	assert_int(result["depth"]).is_equal(1)

## Test starter with deep depth gets no leverage multiplier
func test_starter_with_deep_depth() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var backup1 := {"id": "QB2", "position": "QB", "eval_score": 60.0}
	var backup2 := {"id": "QB3", "position": "QB", "eval_score": 58.0}
	var roster := [player, backup1, backup2]

	var result := TeamImpact.compute_team_value(player, roster, config)

	assert_float(result["leverage_multiplier"]).is_equal(1.0)
	assert_int(result["depth"]).is_equal(2)

## Test raw impact calculation
func test_raw_impact_calculation() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var backup := {"id": "QB2", "position": "QB", "eval_score": 60.0}
	var roster := [player, backup]

	var result := TeamImpact.compute_team_value(player, roster, config)

	# Impact = player_score - best_replacement_score
	# 80 - 60 = 20
	assert_float(result["raw_impact"]).is_equal(20.0)

## Test impact when backup is better than replacement level
func test_impact_with_quality_backup() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 85.0}
	var backup := {"id": "QB2", "position": "QB", "eval_score": 70.0}
	var roster := [player, backup]

	var result := TeamImpact.compute_team_value(player, roster, config)

	# Impact uses best backup (70) not replacement level (55)
	assert_float(result["raw_impact"]).is_equal(15.0)
	assert_float(result["replacement_score"]).is_equal(70.0)

## Test impact when no backup uses replacement level
func test_impact_no_backup_uses_replacement() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var roster := [player]

	var result := TeamImpact.compute_team_value(player, roster, config)

	# Impact uses replacement level since no backup
	assert_float(result["raw_impact"]).is_equal(25.0)  # 80 - 55
	assert_float(result["replacement_score"]).is_equal(55.0)

## Test position importance affects team value
func test_position_importance() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0, "RB": 62.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {
				"QB": 2.5,
				"RB": 0.8
			}
		}
	}

	var qb := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var rb := {"id": "RB1", "position": "RB", "eval_score": 80.0}

	var qb_result := TeamImpact.compute_team_value(qb, [qb], config)
	var rb_result := TeamImpact.compute_team_value(rb, [rb], config)

	# QB has higher position importance (2.5 vs 0.8)
	assert_float(qb_result["position_importance"]).is_equal(2.5)
	assert_float(rb_result["position_importance"]).is_equal(0.8)
	assert_float(qb_result["team_value"]).is_greater(rb_result["team_value"])

## Test team value calculation
func test_team_value_calculation() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var roster := [player]

	var result := TeamImpact.compute_team_value(player, roster, config)

	# team_value = raw_impact * leverage_mult * position_importance
	# = 25.0 * 1.4 * 2.5 = 87.5
	var expected := 25.0 * 1.4 * 2.5
	assert_float(result["team_value"]).is_equal(expected)

## Test backup player has lower team value
func test_backup_player_lower_value() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var starter := {"id": "QB1", "position": "QB", "eval_score": 85.0}
	var backup := {"id": "QB2", "position": "QB", "eval_score": 65.0}
	var roster := [starter, backup]

	var starter_result := TeamImpact.compute_team_value(starter, roster, config)
	var backup_result := TeamImpact.compute_team_value(backup, roster, config)

	# Starter has much higher team value
	assert_float(starter_result["team_value"]).is_greater(backup_result["team_value"])

## Test player below replacement level has zero impact
func test_player_below_replacement_zero_impact() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 50.0}
	var roster := [player]

	var result := TeamImpact.compute_team_value(player, roster, config)

	# Below replacement level = 0 impact
	assert_float(result["raw_impact"]).is_equal(0.0)
	assert_float(result["team_value"]).is_equal(0.0)

## Test position importance defaults
func test_position_importance_defaults() -> void:
	var config := {
		"replacement_levels": {},
		"team_impact": {}
	}

	var qb := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var rb := {"id": "RB1", "position": "RB", "eval_score": 80.0}
	var edge := {"id": "EDGE1", "position": "EDGE", "eval_score": 80.0}

	var qb_result := TeamImpact.compute_team_value(qb, [qb], config)
	var rb_result := TeamImpact.compute_team_value(rb, [rb], config)
	var edge_result := TeamImpact.compute_team_value(edge, [edge], config)

	# QB should have highest default importance
	assert_float(qb_result["position_importance"]).is_equal(2.5)
	# EDGE should have higher importance than RB
	assert_float(edge_result["position_importance"]).is_greater(rb_result["position_importance"])

## Test different positions at same position
func test_multiple_players_same_position() -> void:
	var config := {
		"replacement_levels": {"WR": 58.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"WR": 1.2}
		}
	}

	var wr1 := {"id": "WR1", "position": "WR", "eval_score": 85.0}
	var wr2 := {"id": "WR2", "position": "WR", "eval_score": 78.0}
	var wr3 := {"id": "WR3", "position": "WR", "eval_score": 70.0}
	var roster := [wr1, wr2, wr3]

	var wr1_result := TeamImpact.compute_team_value(wr1, roster, config)
	var wr2_result := TeamImpact.compute_team_value(wr2, roster, config)
	var wr3_result := TeamImpact.compute_team_value(wr3, roster, config)

	# WR1 is best, impact vs WR2 (78)
	assert_float(wr1_result["raw_impact"]).is_equal(7.0)  # 85 - 78

	# WR2 is 2nd best, impact vs WR3 (70)
	assert_float(wr2_result["raw_impact"]).is_equal(8.0)  # 78 - 70

	# WR3 is worst, impact vs replacement (58)
	assert_float(wr3_result["raw_impact"]).is_equal(12.0)  # 70 - 58

## Test result dictionary has all expected fields
func test_result_has_expected_fields() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var roster := [player]

	var result := TeamImpact.compute_team_value(player, roster, config)

	assert_that(result).contains_key("player_id")
	assert_that(result).contains_key("position")
	assert_that(result).contains_key("player_score")
	assert_that(result).contains_key("replacement_score")
	assert_that(result).contains_key("raw_impact")
	assert_that(result).contains_key("depth")
	assert_that(result).contains_key("leverage_multiplier")
	assert_that(result).contains_key("position_importance")
	assert_that(result).contains_key("team_value")

## Test roster with players from different positions
func test_roster_mixed_positions() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0, "RB": 62.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5, "RB": 0.8}
		}
	}

	var qb := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var rb1 := {"id": "RB1", "position": "RB", "eval_score": 75.0}
	var rb2 := {"id": "RB2", "position": "RB", "eval_score": 68.0}
	var roster := [qb, rb1, rb2]

	var qb_result := TeamImpact.compute_team_value(qb, roster, config)

	# QB should only see depth at QB position (0 other QBs)
	assert_int(qb_result["depth"]).is_equal(0)

## Test calculation is deterministic
func test_calculation_deterministic() -> void:
	var config := {
		"replacement_levels": {"QB": 55.0},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		}
	}

	var player := {"id": "QB1", "position": "QB", "eval_score": 80.0}
	var roster := [player]

	var result1 := TeamImpact.compute_team_value(player, roster, config)
	var result2 := TeamImpact.compute_team_value(player, roster, config)
	var result3 := TeamImpact.compute_team_value(player, roster, config)

	assert_float(result1["team_value"]).is_equal(result2["team_value"])
	assert_float(result2["team_value"]).is_equal(result3["team_value"])
