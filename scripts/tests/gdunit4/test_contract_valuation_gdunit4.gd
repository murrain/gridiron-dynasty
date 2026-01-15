## GdUnit4 test suite for ContractValuation
##
## Validates contract valuation logic including market value, team value,
## and various calculation components.
## Migrated from test_contract_valuation.gd
extends GdUnitTestSuite

const ContractValuation = preload("res://scripts/core/valuation/ContractValuation.gd")


var _config: Dictionary


func before() -> void:
	_config = _get_test_config()


func test_backwards_compatibility_no_context() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng)

	assert_bool(result is Dictionary).is_true()
	assert_bool(result.has("apy")).is_true()
	assert_bool(result.has("market_value")).is_true()
	assert_float(float(result.get("apy", 0.0))).is_greater(0.0)


func test_market_value_without_context() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng, {})

	# Without context, team_value should equal market_value
	assert_float(float(result.get("team_value"))).is_equal_approx(float(result.get("market_value")), 0.001)
	assert_float(float(result.get("team_premium"))).is_equal_approx(0.0, 0.001)
	assert_float(float(result.get("market_value"))).is_greater(0.0)


func test_team_value_with_context_exceeds_market_value() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("qb_1", "QB", 25, 85.0)
	var context := {
		"team_roster": [
			{"id": "qb_1", "position": "QB", "eval_score": 85.0},
			{"id": "wr_1", "position": "WR", "eval_score": 75.0}
		],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, _config, rng, context)

	assert_float(float(result.get("team_value"))).is_greater(float(result.get("market_value")))
	assert_float(float(result.get("team_premium"))).is_greater(0.0)


func test_team_premium_no_backup() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("qb_1", "QB", 25, 85.0)
	var context := {
		"team_roster": [{"id": "qb_1", "position": "QB", "eval_score": 85.0}],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, _config, rng, context)

	var premium_ratio: float = float(result.get("team_value")) / maxf(float(result.get("market_value")), 0.001)
	assert_float(premium_ratio).is_greater(1.2)


func test_team_premium_with_depth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("qb_1", "QB", 25, 85.0)
	var context := {
		"team_roster": [
			{"id": "qb_1", "position": "QB", "eval_score": 85.0},
			{"id": "qb_2", "position": "QB", "eval_score": 78.0},
			{"id": "qb_3", "position": "QB", "eval_score": 70.0}
		],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, _config, rng, context)

	var premium_ratio: float = float(result.get("team_value")) / maxf(float(result.get("market_value")), 0.001)
	assert_float(premium_ratio).is_less(1.3)


func test_all_fields_present() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng, {})

	# Legacy fields
	assert_bool(result.has("apy")).is_true()
	assert_bool(result.has("total")).is_true()
	assert_bool(result.has("years")).is_true()

	# New PlayerValue fields
	assert_bool(result.has("market_value")).is_true()
	assert_bool(result.has("team_value")).is_true()
	assert_bool(result.has("team_premium")).is_true()
	assert_bool(result.has("vor")).is_true()
	assert_bool(result.has("range_min")).is_true()
	assert_bool(result.has("range_max")).is_true()
	assert_bool(result.has("components")).is_true()

	# Metadata fields
	assert_bool(result.has("valuation_version")).is_true()
	assert_bool(result.has("player_id")).is_true()


func test_contract_years_by_age() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young := _make_test_player("young", "QB", 22, 85.0)
	var prime := _make_test_player("prime", "QB", 27, 85.0)
	var old := _make_test_player("old", "QB", 34, 85.0)

	var young_result := ContractValuation.estimate_value(young, _config, rng, {})
	var prime_result := ContractValuation.estimate_value(prime, _config, rng, {})
	var old_result := ContractValuation.estimate_value(old, _config, rng, {})

	assert_int(int(young_result.get("years"))).is_equal(5)
	assert_int(int(prime_result.get("years"))).is_equal(4)
	assert_int(int(old_result.get("years"))).is_equal(1)


func test_total_equals_apy_times_years() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young := _make_test_player("young", "QB", 22, 85.0)
	var result := ContractValuation.estimate_value(young, _config, rng, {})

	assert_float(float(result.get("total"))).is_equal_approx(float(result.get("apy")) * 5.0, 0.001)


func test_range_min_max_present() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng, {})

	assert_bool(result.has("range_min")).is_true()
	assert_bool(result.has("range_max")).is_true()
	assert_float(float(result.get("range_min"))).is_less(float(result.get("market_value")))
	assert_float(float(result.get("range_max"))).is_greater(float(result.get("market_value")))


func test_range_spread_correct() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng, {})

	var expected_min: float = float(result.get("market_value")) * 0.85
	var expected_max: float = float(result.get("market_value")) * 1.15

	assert_float(float(result.get("range_min"))).is_equal_approx(expected_min, 0.001)
	assert_float(float(result.get("range_max"))).is_equal_approx(expected_max, 0.001)


func test_vor_included() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng, {})

	assert_bool(result.has("vor")).is_true()
	# QB with 85 score, replacement is 55 -> VOR = 30
	assert_float(float(result.get("vor"))).is_equal_approx(30.0, 0.001)


func test_components_present() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var context := {
		"team_roster": [
			{"id": "player_001", "position": "QB", "eval_score": 85.0},
			{"id": "qb_2", "position": "QB", "eval_score": 70.0}
		],
		"position_supply": {"QB": 32}
	}

	var result := ContractValuation.estimate_value(player, _config, rng, context)

	assert_bool(result.has("components")).is_true()
	assert_bool(result.get("components") is Dictionary).is_true()

	var components: Dictionary = result.get("components", {})
	assert_bool(components.has("vor")).is_true()
	assert_bool(components.has("curve_output")).is_true()
	assert_bool(components.has("scarcity")).is_true()
	assert_bool(components.has("age")).is_true()
	assert_bool(components.has("team_impact")).is_true()


func test_determinism() -> void:
	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var context := {
		"team_roster": [{"id": "player_001", "position": "QB", "eval_score": 85.0}],
		"position_supply": {"QB": 32}
	}

	var results: Array = []
	for i in range(5):
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		results.append(ContractValuation.estimate_value(player, _config, rng, context))

	for i in range(1, results.size()):
		assert_float(float(results[i].get("market_value"))).is_equal_approx(float(results[0].get("market_value")), 0.0001)
		assert_float(float(results[i].get("team_value"))).is_equal_approx(float(results[0].get("team_value")), 0.0001)
		assert_float(float(results[i].get("vor"))).is_equal_approx(float(results[0].get("vor")), 0.0001)


func test_elite_player_valuation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var avg_player := _make_test_player("avg", "QB", 25, 75.0)
	var elite_player := _make_test_player("elite", "QB", 25, 98.0)

	var avg_result := ContractValuation.estimate_value(avg_player, _config, rng, {})
	var elite_result := ContractValuation.estimate_value(elite_player, _config, rng, {})

	var ratio: float = float(elite_result.get("market_value")) / maxf(float(avg_result.get("market_value")), 0.001)
	assert_float(ratio).is_greater_equal(5.0)


func test_replacement_level_player() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var replacement := _make_test_player("replacement", "QB", 25, 55.0)
	var result := ContractValuation.estimate_value(replacement, _config, rng, {})

	assert_float(float(result.get("vor"))).is_equal_approx(0.0, 0.001)
	assert_float(float(result.get("market_value"))).is_less(10.0)


func test_positional_scarcity_impact() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)

	var scarce_context := {"position_supply": {"QB": 20}}
	var abundant_context := {"position_supply": {"QB": 60}}

	var scarce_result := ContractValuation.estimate_value(player, _config, rng, scarce_context)
	var abundant_result := ContractValuation.estimate_value(player, _config, rng, abundant_context)

	assert_float(float(scarce_result.get("market_value"))).is_greater(float(abundant_result.get("market_value")))


func test_age_multiplier_impact() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var young := _make_test_player("young", "QB", 22, 85.0)
	var prime := _make_test_player("prime", "QB", 25, 85.0)
	var old := _make_test_player("old", "QB", 32, 85.0)

	var young_result := ContractValuation.estimate_value(young, _config, rng, {})
	var prime_result := ContractValuation.estimate_value(prime, _config, rng, {})
	var old_result := ContractValuation.estimate_value(old, _config, rng, {})

	assert_float(float(young_result.get("market_value"))).is_greater(float(prime_result.get("market_value")))
	assert_float(float(prime_result.get("market_value"))).is_greater(float(old_result.get("market_value")))


func test_jitter_when_enabled() -> void:
	var jitter_config := _get_test_config()
	jitter_config["jitter_sigma_pct"] = 0.05

	var player := _make_test_player("player_001", "QB", 25, 85.0)

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321

	var result1 := ContractValuation.estimate_value(player, jitter_config, rng1, {})
	var result2 := ContractValuation.estimate_value(player, jitter_config, rng2, {})

	# APY should vary due to different RNG seeds
	assert_float(absf(float(result1.get("apy")) - float(result2.get("apy")))).is_greater(0.001)
	assert_float(float(result1.get("apy"))).is_greater(0.0)
	assert_float(float(result2.get("apy"))).is_greater(0.0)


func test_version_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _make_test_player("player_001", "QB", 25, 85.0)
	var result := ContractValuation.estimate_value(player, _config, rng, {})

	assert_bool(result.has("valuation_version")).is_true()
	assert_str(String(result.get("valuation_version"))).is_equal("v2")
	assert_bool(result.has("player_id")).is_true()
	assert_str(String(result.get("player_id"))).is_equal("player_001")


# --- Helper functions ---

func _make_test_player(id: String, position: String, age: int, eval_score: float) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"age": age,
		"eval_score": eval_score
	}


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
		"jitter_sigma_pct": 0.0
	}
