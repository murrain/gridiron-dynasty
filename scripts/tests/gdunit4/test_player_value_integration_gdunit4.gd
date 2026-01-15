## GdUnit4 test suite for player value integration
##
## Tests team premium, market vs team value, and config validation.
extends GdUnitTestSuite

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")
const Config = preload("res://autoloads/Config.gd")


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

	assert_float(result.team_premium).is_greater(0.0)

	var premium_ratio: float = result.team_value / maxf(result.market_value, 0.001)
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

	var premium_ratio: float = result.team_value / maxf(result.market_value, 0.001)
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

	var market_context := {"position_supply": {"QB": 32}}
	var market_result := PlayerValue.calculate(player, market_context, config, rng)

	assert_float(market_result.team_value).is_equal_approx(market_result.market_value, 0.001)
	assert_float(market_result.team_premium).is_equal_approx(0.0, 0.001)

	var team_context := {
		"team_roster": [{"id": "player_001", "position": "QB", "eval_score": 85.0}],
		"position_supply": {"QB": 32}
	}

	var team_result := PlayerValue.calculate(player, team_context, config, rng)

	assert_float(team_result.team_value).is_greater(team_result.market_value)
	assert_float(team_result.team_premium).is_greater(0.0)


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
		"team_roster": [{"id": "player_001", "position": "QB", "eval_score": 85.0}],
		"position_supply": {"QB": 32}
	}

	var results: Array = []
	for i in range(5):
		results.append(PlayerValue.calculate(player, context, config, rng))

	for i in range(1, results.size()):
		assert_float(results[i].market_value).is_equal_approx(results[0].market_value, 0.0001)
		assert_float(results[i].team_value).is_equal_approx(results[0].team_value, 0.0001)
		assert_float(results[i].vor).is_equal_approx(results[0].vor, 0.0001)


func test_config_validation() -> void:
	var config := _get_test_config()
	var errors := PlayerValue.validate_config(config)
	assert_bool(errors.is_empty()).is_true()

	var bad_config1 := {"value_curve": {}}
	var errors1 := PlayerValue.validate_config(bad_config1)
	assert_int(errors1.size()).is_greater(0)


func test_production_config_validation() -> void:
	var config_service = Config.new()
	var config := config_service.get_config("valuation")
	var errors := PlayerValue.validate_config(config)
	assert_bool(errors.is_empty()).is_true()

	assert_bool(config.has("value_curve")).is_true()
	assert_bool(config.has("replacement_levels")).is_true()
	assert_bool(config.has("scarcity")).is_true()
	assert_bool(config.has("team_impact")).is_true()
	assert_bool(config.has("market")).is_true()

	assert_int(config.get("version", 0)).is_equal(1)
