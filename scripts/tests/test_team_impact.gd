extends RefCounted

const TeamImpact = preload("res://scripts/core/valuation/TeamImpact.gd")
const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")

func run(t) -> void:
	test_compute_team_value_basic(t)
	test_no_backup_leverage(t)
	test_thin_depth_leverage(t)
	test_deep_depth_no_leverage(t)
	test_replacement_uses_best_teammate(t)
	test_position_importance_weighting(t)
	test_team_value_calculation(t)
	test_below_replacement_player(t)
	test_config_overrides(t)

## Test basic team value computation with a simple roster.
func test_compute_team_value_basic(t) -> void:
	var config := _default_config()

	var player := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 85.0
	}

	var roster := [player]  # Only this player, no backups

	var result := TeamImpact.compute_team_value(player, roster, config)

	t.assert_eq(result["player_id"], "qb1", "Player ID matches")
	t.assert_eq(result["position"], "QB", "Position matches")
	t.assert_approx(result["player_score"], 85.0, 0.001, "Player score matches")
	t.assert_approx(result["replacement_score"], 55.0, 0.001, "Uses replacement level baseline")
	t.assert_approx(result["raw_impact"], 30.0, 0.001, "Impact = player_score - replacement")
	t.assert_eq(result["depth"], 0, "No other players at position")
	t.assert_approx(result["leverage_multiplier"], 1.4, 0.001, "No backup = 1.4x leverage")
	t.assert_approx(result["position_importance"], 2.5, 0.001, "QB importance = 2.5")

	# team_value = impact * leverage * importance = 30 * 1.4 * 2.5 = 105
	t.assert_approx(result["team_value"], 105.0, 0.001, "Team value calculated correctly")

## Test that having no backup increases leverage multiplier.
func test_no_backup_leverage(t) -> void:
	var config := _default_config()

	var qb1 := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 85.0
	}

	var roster_no_backup := [qb1]

	var result := TeamImpact.compute_team_value(qb1, roster_no_backup, config)
	t.assert_approx(result["leverage_multiplier"], 1.4, 0.001, "No backup → 1.4x leverage")
	t.assert_eq(result["depth"], 0, "Depth = 0 when no backup")

## Test that having one backup gives thin depth leverage.
func test_thin_depth_leverage(t) -> void:
	var config := _default_config()

	var qb1 := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 85.0
	}

	var qb2 := {
		"id": "qb2",
		"position": "QB",
		"eval_score": 70.0
	}

	var roster_thin := [qb1, qb2]

	var result := TeamImpact.compute_team_value(qb1, roster_thin, config)
	t.assert_approx(result["leverage_multiplier"], 1.15, 0.001, "One backup → 1.15x leverage")
	t.assert_eq(result["depth"], 1, "Depth = 1 when one backup")

## Test that having multiple backups gives no leverage bonus.
func test_deep_depth_no_leverage(t) -> void:
	var config := _default_config()

	var qb1 := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 85.0
	}

	var qb2 := {
		"id": "qb2",
		"position": "QB",
		"eval_score": 70.0
	}

	var qb3 := {
		"id": "qb3",
		"position": "QB",
		"eval_score": 65.0
	}

	var roster_deep := [qb1, qb2, qb3]

	var result := TeamImpact.compute_team_value(qb1, roster_deep, config)
	t.assert_approx(result["leverage_multiplier"], 1.0, 0.001, "Multiple backups → 1.0x leverage")
	t.assert_eq(result["depth"], 2, "Depth = 2 when two backups")

## Test that replacement score uses best available teammate.
func test_replacement_uses_best_teammate(t) -> void:
	var config := _default_config()

	var qb1 := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 90.0
	}

	var qb2 := {
		"id": "qb2",
		"position": "QB",
		"eval_score": 75.0  # Better than replacement level (55)
	}

	var qb3 := {
		"id": "qb3",
		"position": "QB",
		"eval_score": 70.0
	}

	var roster := [qb1, qb2, qb3]

	var result := TeamImpact.compute_team_value(qb1, roster, config)

	# Replacement should be qb2 (75.0), not default replacement level (55.0)
	t.assert_approx(result["replacement_score"], 75.0, 0.001, "Uses best teammate as replacement")
	t.assert_approx(result["raw_impact"], 15.0, 0.001, "Impact = 90 - 75 = 15")

## Test position importance weighting for different positions.
func test_position_importance_weighting(t) -> void:
	var config := _default_config()

	# QB should have highest importance (2.5)
	var qb := {"id": "qb1", "position": "QB", "eval_score": 80.0}
	var qb_result := TeamImpact.compute_team_value(qb, [qb], config)
	t.assert_approx(qb_result["position_importance"], 2.5, 0.001, "QB importance = 2.5")

	# RB should have lower importance (0.8)
	var rb := {"id": "rb1", "position": "RB", "eval_score": 80.0}
	var rb_result := TeamImpact.compute_team_value(rb, [rb], config)
	t.assert_approx(rb_result["position_importance"], 0.8, 0.001, "RB importance = 0.8")

	# K should have lowest importance (0.5)
	var k := {"id": "k1", "position": "K", "eval_score": 80.0}
	var k_result := TeamImpact.compute_team_value(k, [k], config)
	t.assert_approx(k_result["position_importance"], 0.5, 0.001, "K importance = 0.5")

	# EDGE should have premium importance (1.4)
	var edge := {"id": "edge1", "position": "EDGE", "eval_score": 80.0}
	var edge_result := TeamImpact.compute_team_value(edge, [edge], config)
	t.assert_approx(edge_result["position_importance"], 1.4, 0.001, "EDGE importance = 1.4")

	# Verify QB is worth more than RB for same score and depth
	# QB: (80-55) * 1.4 * 2.5 = 25 * 1.4 * 2.5 = 87.5
	# RB: (80-62) * 1.4 * 0.8 = 18 * 1.4 * 0.8 = 20.16
	t.assert_true(
		qb_result["team_value"] > rb_result["team_value"],
		"QB team value > RB team value for same score"
	)

## Test full team value calculation with all components.
func test_team_value_calculation(t) -> void:
	var config := _default_config()

	var wr1 := {
		"id": "wr1",
		"position": "WR",
		"eval_score": 88.0
	}

	var wr2 := {
		"id": "wr2",
		"position": "WR",
		"eval_score": 72.0
	}

	var roster := [wr1, wr2]

	var result := TeamImpact.compute_team_value(wr1, roster, config)

	# WR replacement level = 58.0, but wr2 (72.0) is better
	t.assert_approx(result["replacement_score"], 72.0, 0.001, "Uses wr2 as replacement")

	# Impact = 88 - 72 = 16
	t.assert_approx(result["raw_impact"], 16.0, 0.001, "Impact calculated correctly")

	# Depth = 1 (one other WR)
	t.assert_eq(result["depth"], 1, "Depth = 1")

	# Leverage = 1.15 (thin depth)
	t.assert_approx(result["leverage_multiplier"], 1.15, 0.001, "Thin depth leverage")

	# WR importance = 1.2
	t.assert_approx(result["position_importance"], 1.2, 0.001, "WR importance")

	# Team value = 16 * 1.15 * 1.2 = 22.08
	t.assert_approx(result["team_value"], 22.08, 0.001, "Team value = impact * leverage * importance")

## Test that players below replacement level still work correctly.
func test_below_replacement_player(t) -> void:
	var config := _default_config()

	# QB with score below replacement level (55)
	var qb := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 50.0
	}

	var roster := [qb]

	var result := TeamImpact.compute_team_value(qb, roster, config)

	t.assert_approx(result["player_score"], 50.0, 0.001, "Player score = 50")
	t.assert_approx(result["replacement_score"], 55.0, 0.001, "Replacement = 55")
	t.assert_approx(result["raw_impact"], 0.0, 0.001, "Impact clamped to 0")
	t.assert_approx(result["team_value"], 0.0, 0.001, "Team value = 0 for below-replacement")

## Test that config overrides work correctly.
func test_config_overrides(t) -> void:
	var custom_config := {
		"replacement_levels": {
			"QB": 60.0  # Higher than default 55.0
		},
		"team_impact": {
			"no_backup_multiplier": 2.0,  # Higher than default 1.4
			"thin_depth_multiplier": 1.5,  # Higher than default 1.15
			"position_win_impacts": {
				"QB": 3.0  # Higher than default 2.5
			}
		}
	}

	var qb := {
		"id": "qb1",
		"position": "QB",
		"eval_score": 85.0
	}

	var roster := [qb]

	var result := TeamImpact.compute_team_value(qb, roster, custom_config)

	t.assert_approx(result["replacement_score"], 60.0, 0.001, "Uses custom replacement level")
	t.assert_approx(result["raw_impact"], 25.0, 0.001, "Impact = 85 - 60 = 25")
	t.assert_approx(result["leverage_multiplier"], 2.0, 0.001, "Uses custom no_backup_multiplier")
	t.assert_approx(result["position_importance"], 3.0, 0.001, "Uses custom QB importance")

	# Team value = 25 * 2.0 * 3.0 = 150
	t.assert_approx(result["team_value"], 150.0, 0.001, "Team value uses custom config")

## Helper to create default config matching valuation.json
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
