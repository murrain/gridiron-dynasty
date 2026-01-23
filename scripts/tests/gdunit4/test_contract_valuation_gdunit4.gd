extends GdUnitTestSuite
class_name TestContractValuationGdUnit4

const ContractValuation = preload("res://scripts/core/valuation/ContractValuation.gd")
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
		"replacement_levels": {"QB": 55.0, "RB": 62.0},
		"scarcity": {
			"scarcity_min": 0.7,
			"scarcity_max": 1.5,
			"starter_slots": {"QB": 1}
		},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {"QB": 2.5}
		},
		"age_multipliers": [
			{"min": 18, "max": 24, "mult": 1.05},
			{"min": 25, "max": 30, "mult": 1.00},
			{"min": 31, "max": 50, "mult": 0.80}
		],
		"market": {
			"range_spread_pct": 0.15
		},
		"jitter_sigma_pct": 0.0
	}

## Test basic contract valuation
func test_basic_contract_valuation() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	assert_that(result).contains_key("apy")
	assert_that(result).contains_key("total")
	assert_that(result).contains_key("years")
	assert_that(result).contains_key("market_value")
	assert_that(result).contains_key("team_value")

## Test contract years based on age
func test_contract_years_by_age() -> void:
	var config := _create_minimal_config()

	var young := {"id": "P1", "position": "QB", "age": 22, "eval_score": 75.0}
	var prime := {"id": "P2", "position": "QB", "age": 27, "eval_score": 75.0}
	var aging := {"id": "P3", "position": "QB", "age": 32, "eval_score": 75.0}
	var veteran := {"id": "P4", "position": "QB", "age": 37, "eval_score": 75.0}

	var result_young := ContractValuation.estimate_value(young, config, null, {})
	var result_prime := ContractValuation.estimate_value(prime, config, null, {})
	var result_aging := ContractValuation.estimate_value(aging, config, null, {})
	var result_veteran := ContractValuation.estimate_value(veteran, config, null, {})

	# Young players get longer contracts
	assert_int(result_young["years"]).is_equal(5)
	assert_int(result_prime["years"]).is_equal(4)
	assert_int(result_aging["years"]).is_equal(2)
	assert_int(result_veteran["years"]).is_equal(1)

## Test total contract value calculation
func test_total_contract_value() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	# Total should equal APY * years
	var expected_total := result["apy"] * result["years"]
	assert_float(result["total"]).is_equal(expected_total)

## Test jitter affects valuation when enabled
func test_jitter_affects_valuation() -> void:
	var config := _create_minimal_config()
	config["jitter_sigma_pct"] = 0.05

	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result1 := ContractValuation.estimate_value(player, config, rng, {})

	rng = TestHelpersGdUnit4.create_seeded_rng(54321)
	var result2 := ContractValuation.estimate_value(player, config, rng, {})

	# Different seeds should produce different values
	assert_float(result1["apy"]).is_not_equal(result2["apy"])

## Test jitter is deterministic with same seed
func test_jitter_deterministic_with_seed() -> void:
	var config := _create_minimal_config()
	config["jitter_sigma_pct"] = 0.05

	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var result1 := ContractValuation.estimate_value(player, config, rng1, {})

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var result2 := ContractValuation.estimate_value(player, config, rng2, {})

	# Same seed should produce same values
	assert_float(result1["apy"]).is_equal(result2["apy"])

## Test valuation without jitter is deterministic
func test_no_jitter_deterministic() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result1 := ContractValuation.estimate_value(player, config, null, {})
	var result2 := ContractValuation.estimate_value(player, config, null, {})
	var result3 := ContractValuation.estimate_value(player, config, null, {})

	assert_float(result1["market_value"]).is_equal(result2["market_value"])
	assert_float(result2["market_value"]).is_equal(result3["market_value"])

## Test team context affects team_value
func test_team_context_affects_team_value() -> void:
	var config := _create_minimal_config()
	var player := {"id": "QB1", "position": "QB", "age": 25, "eval_score": 80.0}

	# No team context
	var result_no_context := ContractValuation.estimate_value(player, config, null, {})

	# With team context (no backup)
	var context := {"team_roster": [player]}
	var result_with_context := ContractValuation.estimate_value(player, config, null, context)

	# Team value should be higher with no backup
	assert_float(result_with_context["team_value"]).is_greater(result_no_context["team_value"])

## Test range_min and range_max
func test_contract_range() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	assert_that(result).contains_key("range_min")
	assert_that(result).contains_key("range_max")
	assert_float(result["range_min"]).is_less(result["market_value"])
	assert_float(result["range_max"]).is_greater(result["market_value"])

## Test valuation_version is set
func test_valuation_version() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	assert_that(result).contains_key("valuation_version")
	assert_string(result["valuation_version"]).is_equal("v2")

## Test player_id is stored
func test_player_id_stored() -> void:
	var config := _create_minimal_config()
	var player := {"id": "TEST123", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	assert_string(result["player_id"]).is_equal("TEST123")

## Test components dictionary is included
func test_components_included() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	assert_that(result).contains_key("components")
	var components: Dictionary = result["components"]
	assert_that(components).contains_key("vor")

## Test team_premium is calculated
func test_team_premium_calculated() -> void:
	var config := _create_minimal_config()
	var player := {"id": "QB1", "position": "QB", "age": 25, "eval_score": 80.0}
	var context := {"team_roster": [player]}

	var result := ContractValuation.estimate_value(player, config, null, context)

	assert_that(result).contains_key("team_premium")
	# No backup should give positive premium
	assert_float(result["team_premium"]).is_greater(0.0)

## Test higher eval_score gives higher value
func test_higher_score_higher_value() -> void:
	var config := _create_minimal_config()

	var player_70 := {"id": "P1", "position": "QB", "age": 25, "eval_score": 70.0}
	var player_85 := {"id": "P2", "position": "QB", "age": 25, "eval_score": 85.0}

	var result_70 := ContractValuation.estimate_value(player_70, config, null, {})
	var result_85 := ContractValuation.estimate_value(player_85, config, null, {})

	assert_float(result_85["market_value"]).is_greater(result_70["market_value"])

## Test legacy build_payload method
func test_legacy_build_payload() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25}
	var stats_cfg := {"stats": []}
	var valuation_cfg := {
		"version": "v1",
		"position_premiums": {"QB": 1.0, "DEFAULT": 1.0},
		"age_multipliers": [{"min": 18, "max": 30, "mult": 1.0}],
		"current_vs_potential": {"current_weight": 0.7, "potential_weight": 0.3},
		"score_to_value": {"base": 0.0, "per_point": 1.0},
		"jitter_sigma_pct": 0.0,
		"range_spread_pct": 0.15
	}

	var result := ContractValuation.build_payload(75.0, player, stats_cfg, valuation_cfg, null, 12345)

	assert_that(result).contains_key("range_min")
	assert_that(result).contains_key("range_max")
	assert_that(result).contains_key("est_value")
	assert_that(result).contains_key("input_eval_score")
	assert_that(result).contains_key("valuation_seed")
	assert_that(result).contains_key("valuation_version")

## Test write_to_player_contract
func test_write_to_player_contract() -> void:
	var player := {"id": "P1"}
	var payload := {
		"range_min": 5.0,
		"range_max": 15.0,
		"est_value": 10.0,
		"input_eval_score": 75.0,
		"valuation_seed": 12345,
		"valuation_version": "v2"
	}

	ContractValuation.write_to_player_contract(player, payload)

	assert_that(player).contains_key("contract")
	assert_that(player["contract"]).contains_key("valuation")
	assert_float(player["contract"]["valuation"]["est_value"]).is_equal(10.0)

## Test typical contract years for different ages
func test_typical_contract_years() -> void:
	var config := _create_minimal_config()

	# Test boundary ages
	var age_20 := {"id": "P1", "position": "QB", "age": 20, "eval_score": 75.0}
	var age_24 := {"id": "P2", "position": "QB", "age": 24, "eval_score": 75.0}
	var age_28 := {"id": "P3", "position": "QB", "age": 28, "eval_score": 75.0}
	var age_31 := {"id": "P4", "position": "QB", "age": 31, "eval_score": 75.0}
	var age_35 := {"id": "P5", "position": "QB", "age": 35, "eval_score": 75.0}

	assert_int(ContractValuation.estimate_value(age_20, config, null, {})["years"]).is_equal(5)
	assert_int(ContractValuation.estimate_value(age_24, config, null, {})["years"]).is_equal(4)
	assert_int(ContractValuation.estimate_value(age_28, config, null, {})["years"]).is_equal(3)
	assert_int(ContractValuation.estimate_value(age_31, config, null, {})["years"]).is_equal(2)
	assert_int(ContractValuation.estimate_value(age_35, config, null, {})["years"]).is_equal(1)

## Test VOR is included in result
func test_vor_included() -> void:
	var config := _create_minimal_config()
	var player := {"id": "P1", "position": "QB", "age": 25, "eval_score": 75.0}

	var result := ContractValuation.estimate_value(player, config, null, {})

	assert_that(result).contains_key("vor")
	# QB replacement is 55, so VOR = 75 - 55 = 20
	assert_float(result["vor"]).is_equal(20.0)
