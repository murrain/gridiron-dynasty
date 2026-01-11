extends RefCounted

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")
const Config = preload("res://autoloads/Config.gd")

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
	_test_team_premium_no_backup(t)
	_test_team_premium_with_depth(t)
	_test_market_vs_team_value(t)
	_test_determinism(t)
	_test_config_validation(t)
	_test_production_config_validation(t)


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

	# Team roster with only this QB (no backup)
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

	# Team value should be higher than market value (positive premium)
	t.assert_true(result.team_premium > 0.0,
		"Team premium should be positive when no backup exists")

	# No backup multiplier is 1.4, so team value should be significantly higher
	# The premium should reflect the leverage of having no backup
	var premium_ratio: float = result.team_value / maxf(result.market_value, 0.001)
	t.assert_true(premium_ratio > 1.2,
		"Team value should be >1.2x market value with no backup, got %.2fx" % premium_ratio)


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

	# Team roster with multiple QBs (good backup)
	var team_roster := [
		{"id": "qb_1", "position": "QB", "eval_score": 85.0},
		{"id": "qb_2", "position": "QB", "eval_score": 78.0},  # Good backup
		{"id": "qb_3", "position": "QB", "eval_score": 70.0},  # Third string
		{"id": "wr_1", "position": "WR", "eval_score": 75.0}
	]

	var context := {
		"team_roster": team_roster,
		"position_supply": {"QB": 32}
	}

	var result := PlayerValue.calculate(player, context, config, rng)

	# Team premium should be lower when good backup exists
	# Premium might even be negative if the backup is nearly as good
	var premium_ratio: float = result.team_value / maxf(result.market_value, 0.001)

	# With good depth, team value should be closer to market value
	# (less leverage compared to no backup scenario)
	t.assert_true(premium_ratio < 1.3,
		"Team value should be <1.3x market value with good depth, got %.2fx" % premium_ratio)


## Test that market_value and team_value are distinct and correct
func _test_market_vs_team_value(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Context 1: No team roster (market value only)
	var market_context := {
		"position_supply": {"QB": 32}
	}

	var market_result := PlayerValue.calculate(player, market_context, config, rng)

	# Without team roster, team_value should equal market_value
	t.assert_approx(market_result.team_value, market_result.market_value, 0.001,
		"Without team roster, team_value equals market_value")
	t.assert_approx(market_result.team_premium, 0.0, 0.001,
		"Without team roster, team_premium is zero")

	# Context 2: With team roster (no backup)
	var team_context := {
		"team_roster": [
			{"id": "player_001", "position": "QB", "eval_score": 85.0}
		],
		"position_supply": {"QB": 32}
	}

	var team_result := PlayerValue.calculate(player, team_context, config, rng)

	# With no backup, team_value should exceed market_value
	t.assert_true(team_result.team_value > team_result.market_value,
		"With no backup, team_value should exceed market_value")
	t.assert_true(team_result.team_premium > 0.0,
		"With no backup, team_premium should be positive")


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

	# Run calculation multiple times
	var results: Array = []
	for i in range(5):
		results.append(PlayerValue.calculate(player, context, config, rng))

	# All results should be identical
	for i in range(1, results.size()):
		t.assert_approx(results[i].market_value, results[0].market_value, 0.0001,
			"Market value is deterministic (run %d)" % i)
		t.assert_approx(results[i].team_value, results[0].team_value, 0.0001,
			"Team value is deterministic (run %d)" % i)
		t.assert_approx(results[i].vor, results[0].vor, 0.0001,
			"VOR is deterministic (run %d)" % i)


func _test_config_validation(t) -> void:
	# Test that validate_config accepts valid config
	var config := _get_test_config()
	var errors := PlayerValue.validate_config(config)
	t.assert_true(errors.is_empty(),
		"Valid config should pass validation, got errors: %s" % str(errors))

	# Test missing section
	var bad_config1 := {"value_curve": {}}
	var errors1 := PlayerValue.validate_config(bad_config1)
	t.assert_true(errors1.size() > 0, "Missing sections should fail validation")
	t.assert_true(_contains_error(errors1, "Missing config section"),
		"Should report missing sections")

	# Test missing tiers
	var bad_config2 := {
		"value_curve": {"tiers": []},
		"replacement_levels": {},
		"scarcity": {},
		"team_impact": {}
	}
	var errors2 := PlayerValue.validate_config(bad_config2)
	t.assert_true(_contains_error(errors2, "tiers must have at least one tier"),
		"Should report missing tiers")

	# Test missing positions
	var bad_config3 := {
		"value_curve": {"tiers": [{"min": 0, "max": 100}]},
		"replacement_levels": {"QB": 55.0},  # Missing other positions
		"scarcity": {"scarcity_min": 0.7, "scarcity_max": 1.5, "starter_slots": {}},
		"team_impact": {"no_backup_multiplier": 1.4, "thin_depth_multiplier": 1.15, "position_win_impacts": {}}
	}
	var errors3 := PlayerValue.validate_config(bad_config3)
	t.assert_true(_contains_error(errors3, "Missing replacement_level for position"),
		"Should report missing positions")

func _test_production_config_validation(t) -> void:
	# Test that production valuation.json passes validation
	var config_service = Config.new()
	var config := config_service.get_config("valuation")
	var errors := PlayerValue.validate_config(config)
	t.assert_true(errors.is_empty(),
		"Production valuation.json should be valid, got errors: %s" % str(errors))

	# Verify expected sections exist
	t.assert_true(config.has("value_curve"), "Config has value_curve section")
	t.assert_true(config.has("replacement_levels"), "Config has replacement_levels section")
	t.assert_true(config.has("scarcity"), "Config has scarcity section")
	t.assert_true(config.has("team_impact"), "Config has team_impact section")
	t.assert_true(config.has("market"), "Config has market section")

	# Verify version
	t.assert_eq(config.get("version", 0), 1, "Config version is 1")

func _contains_error(errors: Array, substring: String) -> bool:
	for error in errors:
		if String(error).contains(substring):
			return true
	return false
