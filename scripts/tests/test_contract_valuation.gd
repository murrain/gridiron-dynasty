extends RefCounted

const ContractValuation = preload("res://scripts/core/valuation/ContractValuation.gd")

## Test configuration replicating production valuation.json
func _get_test_config() -> Dictionary:
	return {
		"version": 1,
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
			"scarcity_max": 1.5,
			"starter_slots": {
				"QB": 1,
				"RB": 1,
				"WR": 3,
				"TE": 1,
				"OL": 5,
				"DL": 2,
				"EDGE": 2,
				"LB": 3,
				"CB": 2,
				"S": 2,
				"K": 1,
				"P": 1
			}
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
		"market": {
			"range_spread_pct": 0.15
		},
		"jitter_sigma_pct": 0.0  # Disable jitter for deterministic tests
	}


func run(t) -> void:
	_test_backwards_compatibility_no_context(t)
	_test_market_value_without_context(t)
	_test_team_value_with_context(t)
	_test_team_premium_no_backup(t)
	_test_team_premium_with_depth(t)
	_test_all_fields_present(t)
	_test_contract_years_by_age(t)
	_test_range_min_max_present(t)
	_test_vor_included(t)
	_test_components_present(t)
	_test_determinism(t)
	_test_elite_player_valuation(t)
	_test_replacement_level_player(t)
	_test_positional_scarcity_impact(t)
	_test_age_multiplier_impact(t)
	_test_jitter_when_enabled(t)
	_test_version_field(t)


## Test that estimate_value works without context (backwards compatibility)
func _test_backwards_compatibility_no_context(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Call without context parameter (should not error)
	var result := ContractValuation.estimate_value(player, config, rng)

	# Verify it returns a valid dictionary
	t.assert_true(result is Dictionary, "Result is a dictionary")
	t.assert_true(result.has("apy"), "Result has apy field")
	t.assert_true(result.has("market_value"), "Result has market_value field")
	t.assert_true(result.apy > 0.0, "APY is positive")


## Test market value without context matches PlayerValue calculation
func _test_market_value_without_context(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var result := ContractValuation.estimate_value(player, config, rng, {})

	# Without context, team_value should equal market_value
	t.assert_approx(result.team_value, result.market_value, 0.001,
		"Without context, team_value equals market_value")

	# Team premium should be zero
	t.assert_approx(result.team_premium, 0.0, 0.001,
		"Without context, team_premium is zero")

	# Market value should be positive for above-replacement player
	t.assert_true(result.market_value > 0.0, "Market value is positive")


## Test team value with context includes team-specific adjustments
func _test_team_value_with_context(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Team roster with only this QB (no backup)
	var context := {
		"team_roster": [
			{"id": "qb_1", "position": "QB", "eval_score": 85.0},
			{"id": "wr_1", "position": "WR", "eval_score": 75.0}
		],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, config, rng, context)

	# With no backup, team_value should exceed market_value
	t.assert_true(result.team_value > result.market_value,
		"With no backup, team_value exceeds market_value")

	# Team premium should be positive
	t.assert_true(result.team_premium > 0.0,
		"With no backup, team_premium is positive")


## Test team premium when player has no backup
func _test_team_premium_no_backup(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var context := {
		"team_roster": [
			{"id": "qb_1", "position": "QB", "eval_score": 85.0}
		],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, config, rng, context)

	# No backup multiplier is 1.4, so premium should be substantial
	var premium_ratio: float = result.team_value / maxf(result.market_value, 0.001)
	t.assert_true(premium_ratio > 1.2,
		"No backup scenario should have >1.2x team value ratio, got %.2fx" % premium_ratio)


## Test team premium when player has adequate depth
func _test_team_premium_with_depth(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "qb_1",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var context := {
		"team_roster": [
			{"id": "qb_1", "position": "QB", "eval_score": 85.0},
			{"id": "qb_2", "position": "QB", "eval_score": 78.0},  # Good backup
			{"id": "qb_3", "position": "QB", "eval_score": 70.0}   # Third string
		],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, config, rng, context)

	# With good depth, premium should be lower
	var premium_ratio: float = result.team_value / maxf(result.market_value, 0.001)
	t.assert_true(premium_ratio < 1.3,
		"Good depth scenario should have <1.3x team value ratio, got %.2fx" % premium_ratio)


## Test that all required fields are present in result
func _test_all_fields_present(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var result := ContractValuation.estimate_value(player, config, rng, {})

	# Legacy fields
	t.assert_true(result.has("apy"), "Has apy field")
	t.assert_true(result.has("total"), "Has total field")
	t.assert_true(result.has("years"), "Has years field")

	# New PlayerValue fields
	t.assert_true(result.has("market_value"), "Has market_value field")
	t.assert_true(result.has("team_value"), "Has team_value field")
	t.assert_true(result.has("team_premium"), "Has team_premium field")
	t.assert_true(result.has("vor"), "Has vor field")
	t.assert_true(result.has("range_min"), "Has range_min field")
	t.assert_true(result.has("range_max"), "Has range_max field")
	t.assert_true(result.has("components"), "Has components field")

	# Metadata fields
	t.assert_true(result.has("valuation_version"), "Has valuation_version field")
	t.assert_true(result.has("player_id"), "Has player_id field")


## Test contract years vary by age
func _test_contract_years_by_age(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Young player (22 years old)
	var young := {
		"id": "young",
		"position": "QB",
		"age": 22,
		"eval_score": 85.0
	}

	# Prime age player (27 years old)
	var prime := {
		"id": "prime",
		"position": "QB",
		"age": 27,
		"eval_score": 85.0
	}

	# Older player (34 years old)
	var old := {
		"id": "old",
		"position": "QB",
		"age": 34,
		"eval_score": 85.0
	}

	var young_result := ContractValuation.estimate_value(young, config, rng, {})
	var prime_result := ContractValuation.estimate_value(prime, config, rng, {})
	var old_result := ContractValuation.estimate_value(old, config, rng, {})

	# Young players get longer contracts
	t.assert_eq(young_result.years, 5, "Young player gets 5-year contract")
	t.assert_eq(prime_result.years, 4, "Prime age player gets 4-year contract")
	t.assert_eq(old_result.years, 1, "Old player gets 1-year contract")

	# Total should be apy * years
	t.assert_approx(young_result.total, young_result.apy * 5.0, 0.001,
		"Total equals apy * years for young player")
	t.assert_approx(prime_result.total, prime_result.apy * 4.0, 0.001,
		"Total equals apy * years for prime player")
	t.assert_approx(old_result.total, old_result.apy * 1.0, 0.001,
		"Total equals apy * years for old player")


## Test that range_min and range_max are present and reasonable
func _test_range_min_max_present(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var result := ContractValuation.estimate_value(player, config, rng, {})

	# Range fields should exist
	t.assert_true(result.has("range_min"), "Has range_min")
	t.assert_true(result.has("range_max"), "Has range_max")

	# Range should be reasonable
	t.assert_true(result.range_min < result.market_value,
		"Range min should be below market value")
	t.assert_true(result.range_max > result.market_value,
		"Range max should be above market value")

	# Spread should match config (15%)
	var expected_min: float = result.market_value * 0.85  # 1.0 - 0.15
	var expected_max: float = result.market_value * 1.15  # 1.0 + 0.15
	t.assert_approx(result.range_min, expected_min, 0.001, "Range min correct")
	t.assert_approx(result.range_max, expected_max, 0.001, "Range max correct")


## Test that VOR is included and calculated correctly
func _test_vor_included(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var result := ContractValuation.estimate_value(player, config, rng, {})

	# VOR should be present
	t.assert_true(result.has("vor"), "Has VOR field")

	# QB with 85 score, replacement is 55 -> VOR = 30
	t.assert_approx(result.vor, 30.0, 0.001, "VOR calculated correctly")


## Test that components are present and structured correctly
func _test_components_present(t) -> void:
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

	var result := ContractValuation.estimate_value(player, config, rng, context)

	# Components should exist
	t.assert_true(result.has("components"), "Has components")
	t.assert_true(result.components is Dictionary, "Components is a dictionary")

	# Verify component structure (from PlayerValue)
	t.assert_true(result.components.has("vor"), "Components has VOR")
	t.assert_true(result.components.has("curve_output"), "Components has curve_output")
	t.assert_true(result.components.has("scarcity"), "Components has scarcity")
	t.assert_true(result.components.has("age"), "Components has age")
	t.assert_true(result.components.has("team_impact"), "Components has team_impact")


## Test determinism: same inputs produce same outputs
func _test_determinism(t) -> void:
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

	# Run calculation multiple times with same seed
	var results: Array = []
	for i in range(5):
		rng.seed = 12345  # Reset seed each time
		results.append(ContractValuation.estimate_value(player, config, rng, context))

	# All results should be identical
	for i in range(1, results.size()):
		t.assert_approx(results[i].market_value, results[0].market_value, 0.0001,
			"Market value is deterministic (run %d)" % i)
		t.assert_approx(results[i].team_value, results[0].team_value, 0.0001,
			"Team value is deterministic (run %d)" % i)
		t.assert_approx(results[i].vor, results[0].vor, 0.0001,
			"VOR is deterministic (run %d)" % i)


## Test elite player valuation (high eval_score produces high value)
func _test_elite_player_valuation(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Average player
	var avg_player := {
		"id": "avg",
		"position": "QB",
		"age": 25,
		"eval_score": 75.0
	}

	# Elite player
	var elite_player := {
		"id": "elite",
		"position": "QB",
		"age": 25,
		"eval_score": 98.0
	}

	var avg_result := ContractValuation.estimate_value(avg_player, config, rng, {})
	var elite_result := ContractValuation.estimate_value(elite_player, config, rng, {})

	# Elite should be worth significantly more
	var ratio: float = elite_result.market_value / maxf(avg_result.market_value, 0.001)
	t.assert_true(ratio >= 5.0,
		"Elite player (98) should be worth at least 5x average (75), got %.2fx" % ratio)


## Test replacement-level player has near-zero value
func _test_replacement_level_player(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# QB at replacement level (55.0)
	var replacement := {
		"id": "replacement",
		"position": "QB",
		"age": 25,
		"eval_score": 55.0
	}

	var result := ContractValuation.estimate_value(replacement, config, rng, {})

	# VOR should be zero
	t.assert_approx(result.vor, 0.0, 0.001,
		"Replacement-level player has VOR of 0")

	# Market value should be very low
	t.assert_true(result.market_value < 10.0,
		"Replacement-level player has near-zero market value")


## Test positional scarcity impact
func _test_positional_scarcity_impact(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Scenario 1: High scarcity (low supply)
	var scarce_context := {
		"position_supply": {
			"QB": 20  # Only 20 QBs, need 32 starters
		}
	}

	# Scenario 2: Abundant supply
	var abundant_context := {
		"position_supply": {
			"QB": 60  # 60 QBs, only need 32
		}
	}

	var scarce_result := ContractValuation.estimate_value(player, config, rng, scarce_context)
	var abundant_result := ContractValuation.estimate_value(player, config, rng, abundant_context)

	# Scarce position should have higher market value
	t.assert_true(scarce_result.market_value > abundant_result.market_value,
		"Scarce position should have higher market value")


## Test age multiplier impact
func _test_age_multiplier_impact(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Young player (22 years old)
	var young := {
		"id": "young",
		"position": "QB",
		"age": 22,
		"eval_score": 85.0
	}

	# Prime age player (25 years old)
	var prime := {
		"id": "prime",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Older player (32 years old)
	var old := {
		"id": "old",
		"position": "QB",
		"age": 32,
		"eval_score": 85.0
	}

	var young_result := ContractValuation.estimate_value(young, config, rng, {})
	var prime_result := ContractValuation.estimate_value(prime, config, rng, {})
	var old_result := ContractValuation.estimate_value(old, config, rng, {})

	# Young player should have premium over prime age
	t.assert_true(young_result.market_value > prime_result.market_value,
		"Young player should have higher market value (age premium)")

	# Prime age should be better than older player
	t.assert_true(prime_result.market_value > old_result.market_value,
		"Prime player should have higher market value than older player")


## Test jitter when enabled (values should vary)
func _test_jitter_when_enabled(t) -> void:
	var config := _get_test_config()
	config["jitter_sigma_pct"] = 0.05  # Enable 5% jitter

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321  # Different seed

	var result1 := ContractValuation.estimate_value(player, config, rng1, {})
	var result2 := ContractValuation.estimate_value(player, config, rng2, {})

	# APY should vary due to different RNG seeds
	t.assert_true(abs(result1.apy - result2.apy) > 0.001,
		"Jitter causes APY to vary with different seeds")

	# But both should be within reasonable bounds (0.5x to 1.5x base value)
	# Market values (before jitter) should be the same
	t.assert_true(result1.apy > 0.0, "APY 1 is positive")
	t.assert_true(result2.apy > 0.0, "APY 2 is positive")


## Test valuation version field
func _test_version_field(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	var result := ContractValuation.estimate_value(player, config, rng, {})

	# Should have version field
	t.assert_true(result.has("valuation_version"), "Has valuation_version field")
	t.assert_eq(result.valuation_version, "v2", "Version is v2")

	# Should have player_id field
	t.assert_true(result.has("player_id"), "Has player_id field")
	t.assert_eq(result.player_id, "player_001", "Player ID matches")
