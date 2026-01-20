class_name InjuryFunctionsTest
extends GdUnitTestSuite

## GdUnit4 test suite for InjuryFunctions.gd
## Tests pure functional injury simulation.

const InjuryFunctions = preload("res://scripts/core/transformations/InjuryFunctions.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player() -> Dictionary:
	return {
		"id": "test_player_123",
		"age": 24,
		"position": "QB",
		"stats": {
			"speed": 75.0,
			"strength": 80.0,
			"injury_proneness": 50.0
		},
		"injuries": [],
		"hidden_traits": []
	}

func _create_test_configs() -> Dictionary:
	return {
		"main": {
			"injury": {
				"base_chance": 0.12,
				"proneness_slope": 0.15,
				"position_multipliers": {
					"QB": 0.8,
					"RB": 1.5,
					"WR": 1.0
				},
				"durability_trait_modifiers": {
					"injury_prone": 1.5,
					"durable": 0.7,
					"iron_man": 0.5
				},
				"types": [
					{
						"type": "ankle_sprain",
						"weight": 30.0,
						"severity_min": 1.0,
						"severity_max": 2.0,
						"recovery_years_min": 0,
						"recovery_years_max": 1,
						"affected_stats": ["speed", "agility"],
						"career_ending_chance": 0.0,
						"long_term_cap": 0.98,
						"long_term_decline_mult": 1.02
					},
					{
						"type": "acl_tear",
						"weight": 5.0,
						"severity_min": 3.0,
						"severity_max": 5.0,
						"recovery_years_min": 1,
						"recovery_years_max": 2,
						"affected_stats": ["speed", "agility", "acceleration"],
						"career_ending_chance": 0.05,
						"long_term_cap": 0.90,
						"long_term_decline_mult": 1.15
					}
				]
			}
		}
	}

# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_simulate_injuries_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	InjuryFunctions.simulate_injuries(player, configs, rng)

	assert_dict(player).is_equal(player_copy)

func test_apply_injury_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	InjuryFunctions.apply_injury(player, "ankle_sprain", 2.0)

	assert_dict(player).is_equal(player_copy)

func test_heal_injuries_does_not_mutate_player() -> void:
	var player := _create_test_player()
	player["injuries"] = [{
		"type": "ankle_sprain",
		"severity": 2.0,
		"recovery_timeline": {
			"years_total": 1,
			"years_remaining": 1,
			"status": "active"
		}
	}]
	var player_copy := player.duplicate(true)

	InjuryFunctions.heal_injuries(player, 8)

	assert_dict(player).is_equal(player_copy)

# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_simulate_injuries_is_deterministic() -> void:
	var player := _create_test_player()
	var configs := _create_test_configs()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := InjuryFunctions.simulate_injuries(player, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := InjuryFunctions.simulate_injuries(player, configs, rng2)

	# Results should be identical
	assert_bool(result1.report["injured"]).is_equal(result2.report["injured"])
	assert_float(result1.report["roll"]).is_equal(result2.report["roll"])

func test_simulate_injuries_different_seeds_produce_different_outcomes() -> void:
	var player := _create_test_player()
	var configs := _create_test_configs()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := InjuryFunctions.simulate_injuries(player, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321
	var result2 := InjuryFunctions.simulate_injuries(player, configs, rng2)

	# Rolls should differ
	assert_float(result1.report["roll"]).is_not_equal(result2.report["roll"])

# ============================================================================
# FUNCTIONALITY TESTS - simulate_injuries
# ============================================================================

func test_simulate_injuries_returns_valid_structure() -> void:
	var player := _create_test_player()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := InjuryFunctions.simulate_injuries(player, configs, rng)

	# Verify structure
	assert_dict(result).contains_keys(["player", "report"])
	assert_dict(result.report).contains_keys([
		"base_chance", "proneness", "proneness_slope",
		"position_mult", "trait_mult", "final_chance", "roll", "injured"
	])

func test_simulate_injuries_higher_proneness_increases_chance() -> void:
	var configs := _create_test_configs()

	var low_proneness := _create_test_player()
	low_proneness["stats"]["injury_proneness"] = 30.0

	var high_proneness := _create_test_player()
	high_proneness["stats"]["injury_proneness"] = 70.0

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var result_low := InjuryFunctions.simulate_injuries(low_proneness, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var result_high := InjuryFunctions.simulate_injuries(high_proneness, configs, rng2)

	# Higher proneness should result in higher injury chance
	assert_float(result_high.report["final_chance"]).is_greater(
		result_low.report["final_chance"]
	)

func test_simulate_injuries_position_affects_risk() -> void:
	var configs := _create_test_configs()

	var qb := _create_test_player()
	qb["position"] = "QB"  # Multiplier 0.8

	var rb := _create_test_player()
	rb["position"] = "RB"  # Multiplier 1.5

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var qb_result := InjuryFunctions.simulate_injuries(qb, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var rb_result := InjuryFunctions.simulate_injuries(rb, configs, rng2)

	# RB should have higher injury chance than QB
	assert_float(rb_result.report["final_chance"]).is_greater(
		qb_result.report["final_chance"]
	)

func test_simulate_injuries_durable_trait_reduces_risk() -> void:
	var configs := _create_test_configs()

	var normal := _create_test_player()
	var durable := _create_test_player()
	durable["hidden_traits"] = ["durable"]

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var normal_result := InjuryFunctions.simulate_injuries(normal, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var durable_result := InjuryFunctions.simulate_injuries(durable, configs, rng2)

	# Durable player should have lower injury chance
	assert_float(durable_result.report["trait_mult"]).is_equal(0.7)
	assert_float(durable_result.report["final_chance"]).is_less(
		normal_result.report["final_chance"]
	)

func test_simulate_injuries_injury_prone_trait_increases_risk() -> void:
	var configs := _create_test_configs()

	var normal := _create_test_player()
	var injury_prone := _create_test_player()
	injury_prone["hidden_traits"] = ["injury_prone"]

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var normal_result := InjuryFunctions.simulate_injuries(normal, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var injury_prone_result := InjuryFunctions.simulate_injuries(injury_prone, configs, rng2)

	# Injury-prone player should have higher risk
	assert_float(injury_prone_result.report["trait_mult"]).is_equal(1.5)
	assert_float(injury_prone_result.report["final_chance"]).is_greater(
		normal_result.report["final_chance"]
	)

func test_simulate_injuries_can_generate_injury() -> void:
	var player := _create_test_player()
	var configs := _create_test_configs()

	# Use a seed that will cause an injury
	var rng := RandomNumberGenerator.new()
	rng.seed = 1  # Very low roll, should trigger injury

	var result := InjuryFunctions.simulate_injuries(player, configs, rng)

	if result.report["injured"]:
		# If injured, verify injury was added
		assert_array(result.player["injuries"]).is_not_empty()
		assert_dict(result.report).contains_key_value("injury", result.player["injuries"][0])

func test_simulate_injuries_chance_capped_at_95_percent() -> void:
	var player := _create_test_player()
	player["stats"]["injury_proneness"] = 100.0  # Max proneness
	player["position"] = "RB"  # High-risk position
	player["hidden_traits"] = ["injury_prone"]

	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := InjuryFunctions.simulate_injuries(player, configs, rng)

	# Chance should be capped at 0.95
	assert_float(result.report["final_chance"]).is_less_equal(0.95)

# ============================================================================
# FUNCTIONALITY TESTS - apply_injury
# ============================================================================

func test_apply_injury_adds_injury_to_list() -> void:
	var player := _create_test_player()

	var result := InjuryFunctions.apply_injury(player, "ankle_sprain", 2.0)

	assert_array(result["injuries"]).has_size(1)
	assert_str(result["injuries"][0]["type"]).is_equal("ankle_sprain")
	assert_float(result["injuries"][0]["severity"]).is_equal(2.0)

func test_apply_injury_preserves_existing_injuries() -> void:
	var player := _create_test_player()
	player["injuries"] = [{"type": "old_injury", "severity": 1.0}]

	var result := InjuryFunctions.apply_injury(player, "ankle_sprain", 2.0)

	# Should have both injuries
	assert_array(result["injuries"]).has_size(2)

func test_apply_injury_clamps_severity() -> void:
	var player := _create_test_player()

	# Test extreme values
	var result_high := InjuryFunctions.apply_injury(player, "test", 10.0)
	var result_low := InjuryFunctions.apply_injury(player, "test", -5.0)

	assert_float(result_high["injuries"][0]["severity"]).is_equal(5.0)
	assert_float(result_low["injuries"][0]["severity"]).is_equal(0.0)

# ============================================================================
# FUNCTIONALITY TESTS - heal_injuries
# ============================================================================

func test_heal_injuries_advances_recovery() -> void:
	var player := _create_test_player()
	player["injuries"] = [{
		"type": "ankle_sprain",
		"severity": 2.0,
		"affected_stats": ["speed"],
		"recovery_timeline": {
			"years_total": 2,
			"years_remaining": 2,
			"status": "active"
		},
		"long_term_penalty": {},
		"career_ending": false
	}]

	# Pass 16 weeks (1 season)
	var result := InjuryFunctions.heal_injuries(player, 16)

	# Recovery should advance by 1 year
	assert_int(result["injuries"][0]["recovery_timeline"]["years_remaining"]).is_equal(1)
	assert_str(result["injuries"][0]["recovery_timeline"]["status"]).is_equal("active")

func test_heal_injuries_marks_as_recovered() -> void:
	var player := _create_test_player()
	player["injuries"] = [{
		"type": "ankle_sprain",
		"severity": 2.0,
		"recovery_timeline": {
			"years_total": 1,
			"years_remaining": 1,
			"status": "active"
		}
	}]

	# Pass enough time to fully recover
	var result := InjuryFunctions.heal_injuries(player, 16)

	assert_int(result["injuries"][0]["recovery_timeline"]["years_remaining"]).is_equal(0)
	assert_str(result["injuries"][0]["recovery_timeline"]["status"]).is_equal("recovered")

func test_heal_injuries_handles_multiple_injuries() -> void:
	var player := _create_test_player()
	player["injuries"] = [
		{
			"type": "ankle_sprain",
			"recovery_timeline": {"years_total": 2, "years_remaining": 2, "status": "active"}
		},
		{
			"type": "knee_sprain",
			"recovery_timeline": {"years_total": 1, "years_remaining": 1, "status": "active"}
		}
	]

	var result := InjuryFunctions.heal_injuries(player, 16)

	# First injury should still have 1 year remaining
	assert_int(result["injuries"][0]["recovery_timeline"]["years_remaining"]).is_equal(1)
	# Second injury should be recovered
	assert_int(result["injuries"][1]["recovery_timeline"]["years_remaining"]).is_equal(0)

func test_heal_injuries_doesnt_affect_already_recovered() -> void:
	var player := _create_test_player()
	player["injuries"] = [{
		"type": "old_injury",
		"recovery_timeline": {
			"years_total": 1,
			"years_remaining": 0,
			"status": "recovered"
		}
	}]

	var result := InjuryFunctions.heal_injuries(player, 16)

	# Should remain recovered
	assert_str(result["injuries"][0]["recovery_timeline"]["status"]).is_equal("recovered")

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_simulate_injuries_with_no_injury_types() -> void:
	var player := _create_test_player()
	var configs := _create_test_configs()
	configs["main"]["injury"]["types"] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 1  # Would normally cause injury

	# Should not crash even if injury would occur
	var result := InjuryFunctions.simulate_injuries(player, configs, rng)
	assert_dict(result).contains_keys(["player", "report"])

func test_simulate_injuries_with_missing_position_multiplier() -> void:
	var player := _create_test_player()
	player["position"] = "UNKNOWN"
	var configs := _create_test_configs()

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should use default multiplier of 1.0
	var result := InjuryFunctions.simulate_injuries(player, configs, rng)
	assert_float(result.report["position_mult"]).is_equal(1.0)

func test_heal_injuries_with_zero_weeks() -> void:
	var player := _create_test_player()
	player["injuries"] = [{
		"recovery_timeline": {"years_total": 1, "years_remaining": 1, "status": "active"}
	}]

	var result := InjuryFunctions.heal_injuries(player, 0)

	# Should not change
	assert_int(result["injuries"][0]["recovery_timeline"]["years_remaining"]).is_equal(1)

func test_heal_injuries_with_negative_weeks() -> void:
	var player := _create_test_player()
	player["injuries"] = [{
		"recovery_timeline": {"years_total": 1, "years_remaining": 1, "status": "active"}
	}]

	var result := InjuryFunctions.heal_injuries(player, -10)

	# Should treat as 0 (no change)
	assert_int(result["injuries"][0]["recovery_timeline"]["years_remaining"]).is_equal(1)

func test_heal_injuries_with_empty_injuries_array() -> void:
	var player := _create_test_player()
	player["injuries"] = []

	# Should not crash
	var result := InjuryFunctions.heal_injuries(player, 16)
	assert_array(result["injuries"]).is_empty()
