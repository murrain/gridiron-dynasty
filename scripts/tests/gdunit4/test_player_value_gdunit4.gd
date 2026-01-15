## GdUnit4 test suite for PlayerValue
##
## Validates player valuation including VOR, age multipliers, scarcity, and team premium.
## Migrated from test_player_value.gd
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


func test_all_components_integrate() -> void:
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
			"QB": 40
		}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	assert_bool(result.has("player_id")).is_true()
	assert_bool(result.has("position")).is_true()
	assert_bool(result.has("age")).is_true()
	assert_bool(result.has("eval_score")).is_true()
	assert_bool(result.has("vor")).is_true()
	assert_bool(result.has("curved_value")).is_true()
	assert_bool(result.has("scarcity_multiplier")).is_true()
	assert_bool(result.has("age_multiplier")).is_true()
	assert_bool(result.has("market_value")).is_true()
	assert_bool(result.has("team_value")).is_true()
	assert_bool(result.has("team_premium")).is_true()
	assert_bool(result.has("range_min")).is_true()
	assert_bool(result.has("range_max")).is_true()
	assert_bool(result.has("components")).is_true()

	assert_float(float(result.vor)).is_equal_approx(30.0, 0.001)
	assert_float(float(result.age_multiplier)).is_equal_approx(1.0, 0.001)
	assert_float(float(result.scarcity_multiplier)).is_between(0.7, 1.5)
	assert_float(float(result.market_value)).is_greater(0.0)


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

	var context := {
		"position_supply": {
			"QB": 32
		}
	}

	var avg_result := PlayerValue.calculate(avg_player, context, config, rng)
	var elite_result := PlayerValue.calculate(elite_player, context, config, rng)

	var ratio: float = float(elite_result.market_value) / maxf(float(avg_result.market_value), 0.001)

	assert_float(ratio).is_greater_equal(5.0)
	assert_float(ratio).is_less_equal(20.0)


func test_team_premium_no_backup() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var team_roster := [
		{"id": "qb_1", "position": "QB", "eval_score": 85.0},
		{"id": "wr_1", "position": "WR", "eval_score": 75.0},
		{"id": "wr_2", "position": "WR", "eval_score": 70.0}
	]

	var context := {
		"team_roster": team_roster,
		"position_supply": {"QB": 32}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	assert_float(float(result.team_premium)).is_greater(0.0)

	var premium_ratio: float = float(result.team_value) / maxf(float(result.market_value), 0.001)
	assert_float(premium_ratio).is_greater(1.2)


func test_team_premium_with_depth() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var team_roster := [
		{"id": "qb_1", "position": "QB", "eval_score": 85.0},
		{"id": "qb_2", "position": "QB", "eval_score": 78.0},
		{"id": "qb_3", "position": "QB", "eval_score": 70.0},
		{"id": "wr_1", "position": "WR", "eval_score": 75.0}
	]

	var context := {
		"team_roster": team_roster,
		"position_supply": {"QB": 32}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	var premium_ratio: float = float(result.team_value) / maxf(float(result.market_value), 0.001)
	assert_float(premium_ratio).is_less(1.3)


func test_market_vs_team_value() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var market_context := {
		"position_supply": {"QB": 32}
	}

	var market_result := PlayerValue.calculate(player, market_context, config, rng)

	assert_float(float(market_result.team_value)).is_equal_approx(float(market_result.market_value), 0.001)
	assert_float(float(market_result.team_premium)).is_equal_approx(0.0, 0.001)

	var team_context := {
		"team_roster": [
			{"id": "player_001", "position": "QB", "eval_score": 85.0}
		],
		"position_supply": {"QB": 32}
	}

	var team_result := PlayerValue.calculate(player, team_context, config, rng)

	assert_float(float(team_result.team_value)).is_greater(float(team_result.market_value))
	assert_float(float(team_result.team_premium)).is_greater(0.0)


func test_contract_range_variance() -> void:
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

	var spread: float = config.range_spread_pct
	var expected_min: float = float(result.market_value) * (1.0 - spread)
	var expected_max: float = float(result.market_value) * (1.0 + spread)

	assert_float(float(result.range_min)).is_equal_approx(expected_min, 0.001)
	assert_float(float(result.range_max)).is_equal_approx(expected_max, 0.001)

	assert_float(float(result.range_min)).is_less(float(result.market_value))
	assert_float(float(result.range_max)).is_greater(float(result.market_value))

	var actual_spread: float = (float(result.range_max) - float(result.range_min)) / (2.0 * float(result.market_value))
	assert_float(actual_spread).is_equal_approx(0.18, 0.001)


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

	var scarce_context := {
		"position_supply": {
			"QB": 20
		}
	}

	var scarce_result := PlayerValue.calculate(player, scarce_context, config, rng)

	var abundant_context := {
		"position_supply": {
			"QB": 60
		}
	}

	var abundant_result := PlayerValue.calculate(player, abundant_context, config, rng)

	assert_float(float(scarce_result.market_value)).is_greater(float(abundant_result.market_value))
	assert_float(float(scarce_result.scarcity_multiplier)).is_greater(float(abundant_result.scarcity_multiplier))


func test_age_multiplier_impact() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young_player := {
		"id": "player_young",
		"position": "QB",
		"age": 22,
		"eval_score": 85.0
	}

	var prime_player := {
		"id": "player_prime",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var old_player := {
		"id": "player_old",
		"position": "QB",
		"age": 32,
		"eval_score": 85.0
	}

	var context := {
		"position_supply": {"QB": 32}
	}

	var young_result := PlayerValue.calculate(young_player, context, config, rng)
	var prime_result := PlayerValue.calculate(prime_player, context, config, rng)
	var old_result := PlayerValue.calculate(old_player, context, config, rng)

	assert_float(float(young_result.age_multiplier)).is_greater(float(prime_result.age_multiplier))
	assert_float(float(prime_result.age_multiplier)).is_greater(float(old_result.age_multiplier))

	assert_float(float(young_result.market_value)).is_greater(float(prime_result.market_value))
	assert_float(float(prime_result.market_value)).is_greater(float(old_result.market_value))


func test_determinism() -> void:
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
			{"id": "player_001", "position": "QB", "eval_score": 85.0}
		],
		"position_supply": {"QB": 32}
	}

	var results: Array = []
	for i in range(5):
		results.append(PlayerValue.calculate(player, context, config, rng))

	for i in range(1, results.size()):
		assert_float(float(results[i].market_value)).is_equal_approx(float(results[0].market_value), 0.0001)
		assert_float(float(results[i].team_value)).is_equal_approx(float(results[0].team_value), 0.0001)
		assert_float(float(results[i].vor)).is_equal_approx(float(results[0].vor), 0.0001)


func test_vor_calculation() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var qb := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 80.0
	}

	var rb := {
		"id": "rb_1",
		"position": "RB",
		"age": 25,
		"eval_score": 80.0
	}

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

	assert_float(float(qb_result.vor)).is_equal_approx(25.0, 0.001)
	assert_float(float(rb_result.vor)).is_equal_approx(18.0, 0.001)
	assert_float(float(k_result.vor)).is_equal_approx(15.0, 0.001)

	assert_float(float(qb_result.vor)).is_greater(float(rb_result.vor))
	assert_float(float(rb_result.vor)).is_greater(float(k_result.vor))


func test_replacement_level_players() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var replacement_qb := {
		"id": "qb_replacement",
		"position": "QB",
		"age": 25,
		"eval_score": 55.0
	}

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

	assert_float(float(replacement_result.vor)).is_equal_approx(0.0, 0.001)
	assert_float(float(below_result.vor)).is_equal_approx(0.0, 0.001)

	assert_float(float(replacement_result.market_value)).is_less(5.0)
	assert_float(float(below_result.market_value)).is_less(5.0)


func test_young_vs_old_players() -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young := {
		"id": "young",
		"position": "QB",
		"age": 22,
		"eval_score": 82.0
	}

	var old := {
		"id": "old",
		"position": "QB",
		"age": 33,
		"eval_score": 88.0
	}

	var context := {
		"position_supply": {"QB": 32}
	}

	var young_result := PlayerValue.calculate(young, context, config, rng)
	var old_result := PlayerValue.calculate(old, context, config, rng)

	assert_float(float(young_result.age_multiplier)).is_equal_approx(1.05, 0.001)
	assert_float(float(old_result.age_multiplier)).is_equal_approx(0.80, 0.001)

	var young_value_without_age: float = float(young_result.market_value) / float(young_result.age_multiplier)
	var old_value_without_age: float = float(old_result.market_value) / float(old_result.age_multiplier)

	assert_float(old_value_without_age).is_greater(young_value_without_age)


func test_complete_valuation_structure() -> void:
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

	assert_bool(result.components.has("vor")).is_true()
	assert_bool(result.components.has("curve_output")).is_true()
	assert_bool(result.components.has("scarcity")).is_true()
	assert_bool(result.components.has("age")).is_true()
	assert_bool(result.components.has("team_impact")).is_true()

	var team_impact: Dictionary = result.components.team_impact
	assert_bool(team_impact.has("player_id")).is_true()
	assert_bool(team_impact.has("position")).is_true()
	assert_bool(team_impact.has("raw_impact")).is_true()
	assert_bool(team_impact.has("depth")).is_true()
	assert_bool(team_impact.has("leverage_multiplier")).is_true()
	assert_bool(team_impact.has("position_importance")).is_true()
	assert_bool(team_impact.has("team_value")).is_true()

	assert_int(int(team_impact.depth)).is_equal(1)
	assert_float(float(team_impact.leverage_multiplier)).is_equal_approx(1.15, 0.001)
