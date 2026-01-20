class_name GrowthFunctionsTest
extends GdUnitTestSuite

## GdUnit4 test suite for GrowthFunctions.gd
## Tests pure functional stat development and progression.

const GrowthFunctions = preload("res://scripts/core/transformations/GrowthFunctions.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player(age: int = 22, position: String = "QB") -> Dictionary:
	return {
		"id": "test_player_123",
		"age": age,
		"position": position,
		"stats": {
			"speed": 70.0,
			"strength": 75.0,
			"awareness": 65.0,
			"agility": 68.0,
			"throwing_power": 80.0
		},
		"potential": {
			"speed": 85.0,
			"strength": 90.0,
			"awareness": 82.0,
			"agility": 85.0,
			"throwing_power": 95.0
		},
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		}
	}

func _create_test_context() -> Dictionary:
	return {
		"program_quality": 1.0,
		"coach_specialization": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}

func _create_test_configs() -> Dictionary:
	return {
		"main": {
			"development": {
				"curve_multipliers": {
					"mid": {
						"growth": 1.0,
						"prime": 0.35,
						"decline": 1.0
					},
					"early": {
						"growth": 1.2,
						"prime": 0.3,
						"decline": 1.1
					},
					"late": {
						"growth": 0.8,
						"prime": 0.4,
						"decline": 0.9
					}
				},
				"prime_growth_min": 0.2,
				"prime_growth_max": 0.8,
				"decline_min": 0.4,
				"decline_max": 1.6
			},
			"annual_base_progress_min": 1.0,
			"annual_base_progress_max": 4.0,
			"annual_progress_cap": 6.0,
			"wear": {
				"decline_snaps_scale": 8000.0,
				"decline_collisions_scale": 2600.0,
				"decline_injuries_scale": 6.0,
				"decline_per_wear": 0.2,
				"decline_min_multiplier": 1.0,
				"decline_max_multiplier": 1.6
			}
		},
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 34,
					"curve": "mid"
				}
			},
			"RB": {
				"development": {
					"peak_age": 25,
					"decline_start": 29,
					"curve": "early"
				}
			},
			"WR": {
				"development": {
					"peak_age": 27,
					"decline_start": 31,
					"curve": "mid"
				}
			}
		},
		"stats": {
			"stats": [
				{"name": "speed", "type": "base"},
				{"name": "strength", "type": "base"},
				{"name": "awareness", "type": "base"},
				{"name": "agility", "type": "base"},
				{"name": "throwing_power", "type": "base"},
				{"name": "overall", "type": "derived"}
			]
		}
	}

# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_apply_development_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	GrowthFunctions.apply_development(player, context, configs, rng)

	assert_dict(player).is_equal(player_copy)

func test_apply_development_does_not_mutate_context() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var context_copy := context.duplicate(true)
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	GrowthFunctions.apply_development(player, context, configs, rng)

	assert_dict(context).is_equal(context_copy)

# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_apply_development_is_deterministic() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := GrowthFunctions.apply_development(player, context, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := GrowthFunctions.apply_development(player, context, configs, rng2)

	# Results should be identical
	assert_dict(result1.player["stats"]).is_equal(result2.player["stats"])
	assert_dict(result1.report).is_equal(result2.report)

func test_apply_development_different_seeds_produce_different_results() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := GrowthFunctions.apply_development(player, context, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321
	var result2 := GrowthFunctions.apply_development(player, context, configs, rng2)

	# Results should differ
	var stats_differ := false
	for stat_name in result1.player["stats"].keys():
		if not is_equal_approx(
			result1.player["stats"][stat_name],
			result2.player["stats"][stat_name]
		):
			stats_differ = true
			break

	assert_bool(stats_differ).is_true()

# ============================================================================
# FUNCTIONALITY TESTS - apply_development
# ============================================================================

func test_apply_development_returns_valid_structure() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Verify structure
	assert_dict(result).contains_keys(["player", "report"])
	assert_dict(result.player).is_not_null()
	assert_dict(result.report).contains_keys(["age", "phase", "stat_entries"])

func test_apply_development_young_player_grows() -> void:
	var player := _create_test_player(22)  # Growth phase
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Phase should be "growth"
	assert_str(result.report["phase"]).is_equal("growth")

	# At least some stats should increase
	var some_stat_increased := false
	for stat_name in player["stats"].keys():
		if result.player["stats"][stat_name] > player["stats"][stat_name]:
			some_stat_increased = true
			break

	assert_bool(some_stat_increased).is_true()

func test_apply_development_prime_player_maintains() -> void:
	var player := _create_test_player(30)  # Prime phase for QB
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Phase should be "prime"
	assert_str(result.report["phase"]).is_equal("prime")

	# Changes should be minimal (prime multiplier is 0.35)
	var total_change := 0.0
	for stat_name in player["stats"].keys():
		var before := player["stats"][stat_name]
		var after := result.player["stats"][stat_name]
		total_change += abs(after - before)

	# Total change should be small (prime phase has limited growth)
	assert_float(total_change).is_less(20.0)

func test_apply_development_old_player_declines() -> void:
	var player := _create_test_player(35)  # Decline phase for QB
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Phase should be "decline"
	assert_str(result.report["phase"]).is_equal("decline")

	# At least some stats should decrease
	var some_stat_decreased := false
	for stat_name in player["stats"].keys():
		if result.player["stats"][stat_name] < player["stats"][stat_name]:
			some_stat_decreased = true
			break

	assert_bool(some_stat_decreased).is_true()

func test_apply_development_respects_potential_cap() -> void:
	var player := _create_test_player(22)
	# Set a stat near its potential
	player["stats"]["speed"] = 84.0
	player["potential"]["speed"] = 85.0
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Speed should not exceed potential
	assert_float(result.player["stats"]["speed"]).is_less_equal(85.0)

func test_apply_development_skips_derived_stats() -> void:
	var player := _create_test_player()
	player["stats"]["overall"] = 75.0  # Derived stat
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Overall should remain unchanged (it's a derived stat)
	assert_float(result.player["stats"]["overall"]).is_equal(75.0)

	# Verify stat_entries doesn't include derived stats
	var has_overall := false
	for entry in result.report["stat_entries"]:
		if entry["stat"] == "overall":
			has_overall = true
			break
	assert_bool(has_overall).is_false()

# ============================================================================
# FUNCTIONALITY TESTS - context modifiers
# ============================================================================

func test_apply_development_poor_program_reduces_growth() -> void:
	var player := _create_test_player(22)
	var configs := _create_test_configs()
	var rng_seed := 12345

	# Good program
	var good_context := _create_test_context()
	good_context["program_quality"] = 1.2
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = rng_seed
	var result_good := GrowthFunctions.apply_development(player, good_context, configs, rng1)

	# Poor program
	var poor_context := _create_test_context()
	poor_context["program_quality"] = 0.8
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = rng_seed
	var result_poor := GrowthFunctions.apply_development(player, poor_context, configs, rng2)

	# Good program should have higher context multiplier
	assert_float(result_good.report["context_multiplier"]).is_greater(
		result_poor.report["context_multiplier"]
	)

func test_apply_development_additive_context_multipliers() -> void:
	var player := _create_test_player(22)
	var context := _create_test_context()
	# All factors 0.8 (20% reduction each)
	context["program_quality"] = 0.8
	context["coach_specialization"] = 0.8
	context["usage"] = 0.8
	context["competition_tier"] = 0.8
	context["rehab_quality"] = 0.8
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Deviations: 5 * (-0.2) = -1.0
	# Combined: 1.0 + (-1.0) = 0.0
	# Clamped to floor: 0.7
	assert_float(result.report["context_multiplier"]).is_equal(0.7)

func test_apply_development_context_multiplier_capped() -> void:
	var player := _create_test_player(22)
	var context := _create_test_context()
	# All factors maxed out
	context["program_quality"] = 1.5
	context["coach_specialization"] = 1.5
	context["usage"] = 1.5
	context["competition_tier"] = 1.5
	context["rehab_quality"] = 1.5
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Should be capped at 1.4
	assert_float(result.report["context_multiplier"]).is_less_equal(1.4)

# ============================================================================
# FUNCTIONALITY TESTS - wear and decline
# ============================================================================

func test_apply_development_wear_accelerates_decline() -> void:
	var configs := _create_test_configs()
	var context := _create_test_context()

	# Player with no wear
	var fresh_player := _create_test_player(35)
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result_fresh := GrowthFunctions.apply_development(fresh_player, context, configs, rng1)

	# Player with high wear
	var worn_player := _create_test_player(35)
	worn_player["wear"]["snaps"] = 16000  # 2x scale
	worn_player["wear"]["collisions"] = 5200  # 2x scale
	worn_player["wear"]["injury_count"] = 12  # 2x scale
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result_worn := GrowthFunctions.apply_development(worn_player, context, configs, rng2)

	# Worn player should have higher decline multiplier
	assert_float(result_worn.report["decline_multiplier"]).is_greater(
		result_fresh.report["decline_multiplier"]
	)

func test_apply_development_wear_only_affects_decline_phase() -> void:
	var configs := _create_test_configs()
	var context := _create_test_context()

	# Young player in growth phase (wear shouldn't matter)
	var young_player := _create_test_player(22)
	young_player["wear"]["snaps"] = 16000
	young_player["wear"]["collisions"] = 5200
	young_player["wear"]["injury_count"] = 12
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result_young := GrowthFunctions.apply_development(young_player, context, configs, rng)

	# Decline multiplier should be 1.0 (not in decline phase)
	assert_float(result_young.report.get("decline_multiplier", 1.0)).is_equal(1.0)

# ============================================================================
# FUNCTIONALITY TESTS - position-specific curves
# ============================================================================

func test_apply_development_position_specific_aging() -> void:
	var context := _create_test_context()
	var configs := _create_test_configs()

	# RB at age 26 (past peak at 25, in decline phase)
	var rb := _create_test_player(26, "RB")
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result_rb := GrowthFunctions.apply_development(rb, context, configs, rng1)

	# QB at age 26 (still growing, peak at 28)
	var qb := _create_test_player(26, "QB")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result_qb := GrowthFunctions.apply_development(qb, context, configs, rng2)

	# RB should be past prime, QB still growing
	assert_str(result_rb.report["phase"]).is_equal("prime")
	assert_str(result_qb.report["phase"]).is_equal("growth")

# ============================================================================
# FUNCTIONALITY TESTS - stat report entries
# ============================================================================

func test_apply_development_report_contains_stat_entries() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Should have entry for each base stat
	assert_array(result.report["stat_entries"]).is_not_empty()

	# Each entry should have required fields
	for entry in result.report["stat_entries"]:
		var entry_dict: Dictionary = entry
		assert_dict(entry_dict).contains_keys([
			"stat", "before", "potential", "raw_draw",
			"multiplier", "delta", "after"
		])

func test_apply_development_stat_entry_shows_potential_cap() -> void:
	var player := _create_test_player(22)
	player["stats"]["speed"] = 84.5
	player["potential"]["speed"] = 85.0
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1  # Use seed that will cause growth

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Find speed entry
	var speed_entry := {}
	for entry in result.report["stat_entries"]:
		if entry["stat"] == "speed":
			speed_entry = entry
			break

	# If speed was capped, capped_by_potential should be true
	if speed_entry.has("capped_by_potential"):
		if speed_entry["capped_by_potential"]:
			assert_float(speed_entry["after"]).is_equal(85.0)

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_apply_development_with_empty_stats() -> void:
	var player := _create_test_player()
	player["stats"] = {}
	player["potential"] = {}
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Should return valid structure with empty stat_entries
	assert_dict(result).contains_keys(["player", "report"])
	assert_array(result.report["stat_entries"]).is_empty()

func test_apply_development_with_missing_stats() -> void:
	var player := _create_test_player()
	player.erase("stats")
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Should handle gracefully
	assert_dict(result).contains_keys(["player", "report"])

func test_apply_development_with_missing_position_config() -> void:
	var player := _create_test_player()
	player["position"] = "UNKNOWN"
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should use default values
	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Should still produce valid result
	assert_dict(result).contains_keys(["player", "report"])

func test_apply_development_stats_clamped_to_100() -> void:
	var player := _create_test_player(22)
	player["stats"]["speed"] = 99.0
	player["potential"]["speed"] = 100.0
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Speed should never exceed 100
	assert_float(result.player["stats"]["speed"]).is_less_equal(100.0)

func test_apply_development_stats_clamped_to_0() -> void:
	var player := _create_test_player(35)
	player["stats"]["speed"] = 2.0  # Very low
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Speed should never go below 0
	assert_float(result.player["stats"]["speed"]).is_greater_equal(0.0)

func test_apply_development_with_missing_wear() -> void:
	var player := _create_test_player(35)
	player.erase("wear")
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should use default wear values (all 0)
	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	assert_dict(result).contains_keys(["player", "report"])
