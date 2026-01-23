extends GdUnitTestSuite
class_name TestPlayerValueGdUnit4

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

## Helper to create minimal config
func _create_minimal_config() -> Dictionary:
	return {
		"value_curve": {
			"curve_type": "exponential",
			"base_value": 1.0,
			"exponent": 2.0,
			"elite_threshold": 92.0,
			"elite_multiplier_boost": 1.5
		},
		"replacement_levels": {
			"QB": 55.0,
			"RB": 62.0,
			"WR": 58.0,
			"EDGE": 52.0
		},
		"scarcity": {
			"scarcity_min": 0.7,
			"scarcity_max": 1.5,
			"starter_slots": {"QB": 1, "RB": 1, "WR": 3}
		},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5, "RB": 0.8, "WR": 1.2}
		},
		"age_multipliers": [
			{"min": 18, "max": 24, "mult": 1.05},
			{"min": 25, "max": 30, "mult": 1.00},
			{"min": 31, "max": 50, "mult": 0.80}
		],
		"market": {
			"range_spread_pct": 0.15
		}
	}

## Test basic player valuation
func test_basic_player_valuation() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	assert_that(result).contains_key("player_id")
	assert_that(result).contains_key("market_value")
	assert_that(result).contains_key("team_value")
	assert_that(result).contains_key("vor")
	assert_that(result).contains_key("curved_value")

## Test VOR calculation in player valuation
func test_vor_calculation() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	# QB replacement is 55.0, so VOR = 75 - 55 = 20
	assert_float(result["vor"]).is_equal(20.0)

## Test market value increases with score
func test_market_value_increases_with_score() -> void:
	var config := _create_minimal_config()
	var context := {}

	var player_70 := {"id": "P1", "position": "QB", "age": 25, "eval_score": 70.0}
	var player_80 := {"id": "P2", "position": "QB", "age": 25, "eval_score": 80.0}
	var player_90 := {"id": "P3", "position": "QB", "age": 25, "eval_score": 90.0}

	var result_70 := PlayerValue.calculate(player_70, context, config, null)
	var result_80 := PlayerValue.calculate(player_80, context, config, null)
	var result_90 := PlayerValue.calculate(player_90, context, config, null)

	assert_float(result_80["market_value"]).is_greater(result_70["market_value"])
	assert_float(result_90["market_value"]).is_greater(result_80["market_value"])

## Test scarcity multiplier affects market value
func test_scarcity_multiplier() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	# Scarce supply
	var context_scarce := {"position_supply": {"QB": 20}}
	var result_scarce := PlayerValue.calculate(player, context_scarce, config, null)

	# Abundant supply
	var context_abundant := {"position_supply": {"QB": 64}}
	var result_abundant := PlayerValue.calculate(player, context_abundant, config, null)

	# Scarce supply should increase market value
	assert_float(result_scarce["market_value"]).is_greater(result_abundant["market_value"])
	assert_float(result_scarce["scarcity_multiplier"]).is_greater(result_abundant["scarcity_multiplier"])

## Test age multiplier affects market value
func test_age_multiplier() -> void:
	var config := _create_minimal_config()
	var context := {}

	var young_player := {"id": "P1", "position": "QB", "age": 22, "eval_score": 75.0}
	var prime_player := {"id": "P2", "position": "QB", "age": 27, "eval_score": 75.0}
	var old_player := {"id": "P3", "position": "QB", "age": 35, "eval_score": 75.0}

	var result_young := PlayerValue.calculate(young_player, context, config, null)
	var result_prime := PlayerValue.calculate(prime_player, context, config, null)
	var result_old := PlayerValue.calculate(old_player, context, config, null)

	# Younger players should have higher market value
	assert_float(result_young["market_value"]).is_greater_equal(result_prime["market_value"])
	assert_float(result_prime["market_value"]).is_greater(result_old["market_value"])

## Test team value with roster context
func test_team_value_with_roster() -> void:
	var config := _create_minimal_config()
	var player := {"id": "QB1", "position": "QB", "age": 25, "eval_score": 80.0}
	var backup := {"id": "QB2", "position": "QB", "age": 27, "eval_score": 60.0}

	var context := {"team_roster": [player, backup]}

	var result := PlayerValue.calculate(player, context, config, null)

	# Should have team value calculated
	assert_that(result).contains_key("team_value")
	assert_that(result).contains_key("team_premium")

## Test team premium for no backup
func test_team_premium_no_backup() -> void:
	var config := _create_minimal_config()
	var player := {"id": "QB1", "position": "QB", "age": 25, "eval_score": 80.0}

	var context := {"team_roster": [player]}

	var result := PlayerValue.calculate(player, context, config, null)

	# No backup should give positive team premium
	assert_float(result["team_premium"]).is_greater(0.0)

## Test range_min and range_max
func test_contract_range() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	var market_value := result["market_value"]
	var range_min := result["range_min"]
	var range_max := result["range_max"]

	# Range should be around market value
	assert_float(range_min).is_less(market_value)
	assert_float(range_max).is_greater(market_value)

	# Range spread is 15% (0.15)
	var expected_min := market_value * 0.85
	var expected_max := market_value * 1.15
	assert_float(range_min).is_equal(expected_min)
	assert_float(range_max).is_equal(expected_max)

## Test components dictionary
func test_components_dictionary() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	assert_that(result).contains_key("components")
	var components: Dictionary = result["components"]

	assert_that(components).contains_key("vor")
	assert_that(components).contains_key("curve_output")
	assert_that(components).contains_key("scarcity")
	assert_that(components).contains_key("age")
	assert_that(components).contains_key("team_impact")

## Test elite player gets premium value
func test_elite_player_premium() -> void:
	var config := _create_minimal_config()
	var context := {}

	var good_player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 88.0}
	var elite_player := {"id": "P2", "position": "QB", "age": 25, "eval_score": 95.0}

	var result_good := PlayerValue.calculate(good_player, context, config, null)
	var result_elite := PlayerValue.calculate(elite_player, context, config, null)

	# Elite player (92+) should be worth significantly more
	var value_ratio := result_elite["market_value"] / result_good["market_value"]
	assert_float(value_ratio).is_greater(1.5)

## Test player below replacement has low value
func test_below_replacement_low_value() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 50.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	# VOR should be 0
	assert_float(result["vor"]).is_equal(0.0)
	# Market value should be very low or zero
	assert_float(result["market_value"]).is_less_equal(1.0)

## Test config validation - valid config
func test_config_validation_valid() -> void:
	var config := _create_minimal_config()
	var errors := PlayerValue.validate_config(config)
	assert_that(errors).is_empty()

## Test config validation - missing sections
func test_config_validation_missing_sections() -> void:
	var config := {
		"value_curve": {}
	}

	var errors := PlayerValue.validate_config(config)
	assert_int(errors.size()).is_greater(0)

## Test config validation - missing value curve tiers
func test_config_validation_missing_tiers() -> void:
	var config := {
		"value_curve": {
			"tiers": []
		},
		"replacement_levels": {},
		"scarcity": {},
		"team_impact": {}
	}

	var errors := PlayerValue.validate_config(config)
	assert_bool(errors.size() > 0).is_true()

## Test different positions have different values
func test_different_positions_different_values() -> void:
	var config := _create_minimal_config()
	var context := {}

	var qb := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var rb := {"id": "P2", "position": "RB", "age": 25, "eval_score": 75.0}
	var edge := {"id": "P3", "position": "EDGE", "age": 25, "eval_score": 75.0}

	var result_qb := PlayerValue.calculate(qb, context, config, null)
	var result_rb := PlayerValue.calculate(rb, context, config, null)
	var result_edge := PlayerValue.calculate(edge, context, config, null)

	# Different replacement levels lead to different VORs
	assert_float(result_qb["vor"]).is_not_equal(result_rb["vor"])
	assert_float(result_rb["vor"]).is_not_equal(result_edge["vor"])

## Test calculation is deterministic
func test_calculation_deterministic() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var context := {}

	var result1 := PlayerValue.calculate(player, context, config, null)
	var result2 := PlayerValue.calculate(player, context, config, null)
	var result3 := PlayerValue.calculate(player, context, config, null)

	assert_float(result1["market_value"]).is_equal(result2["market_value"])
	assert_float(result2["market_value"]).is_equal(result3["market_value"])
	assert_float(result1["team_value"]).is_equal(result2["team_value"])

## Test missing player fields use defaults
func test_missing_player_fields() -> void:
	var config := _create_minimal_config()
	var player := {}  # Empty player
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	# Should use defaults: position "ATH", age 22, eval_score 50.0
	assert_string(result["position"]).is_equal("ATH")
	assert_int(result["age"]).is_equal(22)
	assert_float(result["eval_score"]).is_equal(50.0)

## Test zero eval_score
func test_zero_eval_score() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 0.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	# VOR should be 0 (below replacement)
	assert_float(result["vor"]).is_equal(0.0)
	assert_float(result["market_value"]).is_less_equal(1.0)

## Test maximum eval_score
func test_maximum_eval_score() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 100.0}
	var context := {}

	var result := PlayerValue.calculate(player, context, config, null)

	# Should have very high VOR and market value
	assert_float(result["vor"]).is_equal(45.0)  # 100 - 55
	assert_float(result["market_value"]).is_greater(50.0)
