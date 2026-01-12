extends RefCounted

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")

## Test configuration replicating production valuation.json
func _get_test_config() -> Dictionary:
	return {
		"value_curve": {
			"curve_type": "tiered_exponential",
			"base_value": 1.0,
			"tiers": [
				{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
				{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
				{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
				{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
				{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
			],
			"elite_threshold": 92,
			"elite_multiplier_boost": 1.5
		},
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
		"scarcity": {
			"scarcity_min": 0.7,
			"scarcity_max": 1.5
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
				"P": 0.4
			}
		},
		"age_multipliers": [
			{"min": 18, "max": 20, "mult": 1.12},
			{"min": 21, "max": 24, "mult": 1.05},
			{"min": 25, "max": 27, "mult": 1.00},
			{"min": 28, "max": 30, "mult": 0.90},
			{"min": 31, "max": 34, "mult": 0.80},
			{"min": 35, "max": 50, "mult": 0.65}
		],
		"range_spread_pct": 0.18,
		"market": {
			"range_spread_pct": 0.18
		}
	}


func run(t) -> void:
	_test_all_components_integrate(t)
	_test_vor_calculation(t)
	_test_replacement_level_players(t)
	_test_contract_range_variance(t)
	_test_complete_valuation_structure(t)


## Test that all valuation components integrate correctly
func _test_all_components_integrate(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var context := {
		"position_supply": {
			"QB": 40  # Moderate supply
		}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	# Verify all expected fields exist
	t.assert_true(result.has("player_id"), "Result has player_id")
	t.assert_true(result.has("position"), "Result has position")
	t.assert_true(result.has("age"), "Result has age")
	t.assert_true(result.has("eval_score"), "Result has eval_score")
	t.assert_true(result.has("vor"), "Result has vor")
	t.assert_true(result.has("curved_value"), "Result has curved_value")
	t.assert_true(result.has("scarcity_multiplier"), "Result has scarcity_multiplier")
	t.assert_true(result.has("age_multiplier"), "Result has age_multiplier")
	t.assert_true(result.has("market_value"), "Result has market_value")
	t.assert_true(result.has("team_value"), "Result has team_value")
	t.assert_true(result.has("team_premium"), "Result has team_premium")
	t.assert_true(result.has("range_min"), "Result has range_min")
	t.assert_true(result.has("range_max"), "Result has range_max")
	t.assert_true(result.has("components"), "Result has components")

	# Verify VOR is positive for above-replacement player
	# QB with 85 score, replacement is 55 -> VOR = 30
	t.assert_approx(result.vor, 30.0, 0.001, "VOR calculated correctly")

	# Verify age multiplier for 25-year-old (prime age)
	t.assert_approx(result.age_multiplier, 1.0, 0.001, "Age multiplier correct for prime age")

	# Verify scarcity multiplier is reasonable
	t.assert_between(result.scarcity_multiplier, 0.7, 1.5, "Scarcity multiplier in valid range")

	# Verify market value is positive
	t.assert_true(result.market_value > 0.0, "Market value is positive")


## Test VOR calculation across different positions
func _test_vor_calculation(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# QB with 80 score, replacement is 55 -> VOR = 25
	var qb := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 80.0
	}

	# RB with 80 score, replacement is 62 -> VOR = 18
	var rb := {
		"id": "rb_1",
		"position": "RB",
		"age": 25,
		"eval_score": 80.0
	}

	# K with 80 score, replacement is 65 -> VOR = 15
	var k := {
		"id": "k_1",
		"position": "K",
		"age": 25,
		"eval_score": 80.0
	}

	var context := {
		"position_supply": {"QB": 32, "RB": 32, "K": 32}
	}

	var qb_result := PlayerValue.calculate(qb, context, config, rng)
	var rb_result := PlayerValue.calculate(rb, context, config, rng)
	var k_result := PlayerValue.calculate(k, context, config, rng)

	# Verify VOR calculations
	t.assert_approx(qb_result.vor, 25.0, 0.001, "QB VOR calculated correctly")
	t.assert_approx(rb_result.vor, 18.0, 0.001, "RB VOR calculated correctly")
	t.assert_approx(k_result.vor, 15.0, 0.001, "K VOR calculated correctly")

	# QB should have higher VOR despite same eval_score
	t.assert_true(qb_result.vor > rb_result.vor,
		"QB should have higher VOR than RB at same eval_score")
	t.assert_true(rb_result.vor > k_result.vor,
		"RB should have higher VOR than K at same eval_score")


## Test that replacement-level players have near-zero value
func _test_replacement_level_players(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# QB at replacement level (55.0)
	var replacement_qb := {
		"id": "qb_replacement",
		"position": "QB",
		"age": 25,
		"eval_score": 55.0
	}

	# QB below replacement level
	var below_replacement_qb := {
		"id": "qb_below",
		"position": "QB",
		"age": 25,
		"eval_score": 50.0
	}

	var context := {
		"position_supply": {"QB": 32}
	}

	var replacement_result := PlayerValue.calculate(replacement_qb, context, config, rng)
	var below_result := PlayerValue.calculate(below_replacement_qb, context, config, rng)

	# VOR should be zero
	t.assert_approx(replacement_result.vor, 0.0, 0.001,
		"Replacement-level player has VOR of 0")
	t.assert_approx(below_result.vor, 0.0, 0.001,
		"Below-replacement player has VOR of 0")

	# Market value should be very low (near zero after curve applied to VOR=0)
	t.assert_true(replacement_result.market_value < 5.0,
		"Replacement-level player has near-zero market value")
	t.assert_true(below_result.market_value < 5.0,
		"Below-replacement player has near-zero market value")


## Test that range_min and range_max provide reasonable variance
func _test_contract_range_variance(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var context := {
		"position_supply": {"QB": 32}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	# Range should be symmetric around market_value
	var spread: float = config.range_spread_pct
	var expected_min: float = result.market_value * (1.0 - spread)
	var expected_max: float = result.market_value * (1.0 + spread)

	t.assert_approx(result.range_min, expected_min, 0.001,
		"Range min calculated correctly")
	t.assert_approx(result.range_max, expected_max, 0.001,
		"Range max calculated correctly")

	# Verify range is reasonable
	t.assert_true(result.range_min < result.market_value,
		"Range min should be below market value")
	t.assert_true(result.range_max > result.market_value,
		"Range max should be above market value")

	# Verify spread matches config (18%)
	var actual_spread: float = (result.range_max - result.range_min) / (2.0 * result.market_value)
	t.assert_approx(actual_spread, 0.18, 0.001,
		"Actual spread matches config (18%)")


## Test that result contains complete valuation structure
func _test_complete_valuation_structure(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var context := {
		"team_roster": [
			{"id": "player_001", "position": "QB", "eval_score": 85.0},
			{"id": "qb_2", "position": "QB", "eval_score": 70.0}
		],
		"position_supply": {"QB": 32}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	# Verify components structure
	t.assert_true(result.components.has("vor"), "Components has VOR")
	t.assert_true(result.components.has("curve_output"), "Components has curve_output")
	t.assert_true(result.components.has("scarcity"), "Components has scarcity")
	t.assert_true(result.components.has("age"), "Components has age")
	t.assert_true(result.components.has("team_impact"), "Components has team_impact")

	# Verify team_impact structure
	var team_impact: Dictionary = result.components.team_impact
	t.assert_true(team_impact.has("player_id"), "Team impact has player_id")
	t.assert_true(team_impact.has("position"), "Team impact has position")
	t.assert_true(team_impact.has("raw_impact"), "Team impact has raw_impact")
	t.assert_true(team_impact.has("depth"), "Team impact has depth")
	t.assert_true(team_impact.has("leverage_multiplier"), "Team impact has leverage_multiplier")
	t.assert_true(team_impact.has("position_importance"), "Team impact has position_importance")
	t.assert_true(team_impact.has("team_value"), "Team impact has team_value")

	# Verify depth is correct (1 backup QB)
	t.assert_eq(team_impact.depth, 1, "Team impact depth is correct")

	# Verify leverage multiplier for thin depth (1 backup)
	t.assert_approx(team_impact.leverage_multiplier, 1.15, 0.001,
		"Thin depth multiplier is 1.15")
