## GdUnit4 test suite for player value scenarios
##
## Tests elite player premium, positional scarcity, and age multipliers.
extends GdUnitTestSuite

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")


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
			"QB": 55.0, "RB": 62.0, "WR": 58.0, "TE": 56.0, "OL": 54.0,
			"DL": 57.0, "EDGE": 52.0, "LB": 58.0, "CB": 53.0, "S": 57.0,
			"K": 65.0, "P": 65.0, "ATH": 55.0
		},
		"scarcity": {"scarcity_min": 0.7, "scarcity_max": 1.5},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {
				"QB": 2.5, "EDGE": 1.4, "CB": 1.3, "WR": 1.2, "OL": 1.1,
				"DL": 1.1, "LB": 1.0, "S": 0.95, "TE": 0.9, "RB": 0.8,
				"K": 0.5, "P": 0.4
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
		"market": {"range_spread_pct": 0.18}
	}


func test_elite_player_premium() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var avg_player := {
		"id": "player_avg",
		"position": "QB",
		"age": 25,
		"eval_score": 75.0
	}

	var elite_player := {
		"id": "player_elite",
		"position": "QB",
		"age": 25,
		"eval_score": 98.0
	}

	var context := {"position_supply": {"QB": 32}}

	var avg_result := PlayerValue.calculate(avg_player, context, config, rng)
	var elite_result := PlayerValue.calculate(elite_player, context, config, rng)

	var ratio: float = elite_result.market_value / maxf(avg_result.market_value, 0.001)

	assert_float(ratio).is_greater_equal(5.0)
	assert_float(ratio).is_less_equal(20.0)


func test_positional_scarcity_impact() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var scarce_context := {"position_supply": {"QB": 20}}
	var abundant_context := {"position_supply": {"QB": 60}}

	var scarce_result := PlayerValue.calculate(player, scarce_context, config, rng)
	var abundant_result := PlayerValue.calculate(player, abundant_context, config, rng)

	assert_float(scarce_result.market_value).is_greater(abundant_result.market_value)
	assert_float(scarce_result.scarcity_multiplier).is_greater(abundant_result.scarcity_multiplier)


func test_age_multiplier_impact() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young_player := {"id": "player_young", "position": "QB", "age": 22, "eval_score": 85.0}
	var prime_player := {"id": "player_prime", "position": "QB", "age": 25, "eval_score": 85.0}
	var old_player := {"id": "player_old", "position": "QB", "age": 32, "eval_score": 85.0}

	var context := {"position_supply": {"QB": 32}}

	var young_result := PlayerValue.calculate(young_player, context, config, rng)
	var prime_result := PlayerValue.calculate(prime_player, context, config, rng)
	var old_result := PlayerValue.calculate(old_player, context, config, rng)

	assert_float(young_result.age_multiplier).is_greater(prime_result.age_multiplier)
	assert_float(prime_result.age_multiplier).is_greater(old_result.age_multiplier)

	assert_float(young_result.market_value).is_greater(prime_result.market_value)
	assert_float(prime_result.market_value).is_greater(old_result.market_value)


func test_young_vs_old_players() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young := {"id": "young", "position": "QB", "age": 22, "eval_score": 82.0}
	var old := {"id": "old", "position": "QB", "age": 33, "eval_score": 88.0}

	var context := {"position_supply": {"QB": 32}}

	var young_result := PlayerValue.calculate(young, context, config, rng)
	var old_result := PlayerValue.calculate(old, context, config, rng)

	assert_float(young_result.age_multiplier).is_equal_approx(1.05, 0.001)
	assert_float(old_result.age_multiplier).is_equal_approx(0.80, 0.001)

	var young_value_without_age: float = young_result.market_value / young_result.age_multiplier
	var old_value_without_age: float = old_result.market_value / old_result.age_multiplier

	assert_float(old_value_without_age).is_greater(young_value_without_age)
