extends GdUnitTestSuite
class_name TestInjuryFunctions

const InjuryFunctions = preload("res://scripts/core/transformations/InjuryFunctions.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

# ============================================================================
# SETUP
# ============================================================================

func create_test_configs() -> Dictionary:
	return {
		"main": {
			"injury": {
				"base_chance": 0.12,
				"proneness_slope": 0.15,
				"position_multipliers": {
					"QB": 0.8,
					"RB": 1.3,
					"WR": 1.0
				},
				"durability_trait_modifiers": {
					"injury_prone": 1.5,
					"durable": 0.7,
					"iron_man": 0.4
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
						"long_term_cap": 0.95,
						"long_term_decline_mult": 1.05
					},
					{
						"type": "acl_tear",
						"weight": 10.0,
						"severity_min": 3.0,
						"severity_max": 5.0,
						"recovery_years_min": 1,
						"recovery_years_max": 2,
						"affected_stats": ["speed", "agility", "jumping"],
						"career_ending_chance": 0.05,
						"long_term_cap": 0.85,
						"long_term_decline_mult": 1.2
					}
				]
			}
		}
	}


func create_test_player(proneness: float = 50.0) -> Dictionary:
	return {
		"position": "RB",
		"stats": {
			"injury_proneness": proneness,
			"speed": 80.0,
			"agility": 75.0
		},
		"hidden_traits": [],
		"injuries": []
	}


# ============================================================================
# SIMULATE INJURIES TESTS
# ============================================================================

func test_simulate_injuries_returns_player_and_report() -> void:
	var player := create_test_player()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := InjuryFunctions.simulate_injuries(player, configs, rng)

	# Should return dict with player and report
	assert_dict(result).contains_keys(["player", "report"])


func test_simulate_injuries_is_deterministic() -> void:
	var injury_sim := func(rng_instance: RandomNumberGenerator) -> Dictionary:
		var player := create_test_player()
		var configs := create_test_configs()
		return InjuryFunctions.simulate_injuries(player, configs, rng_instance)

	TestHelpersGdUnit4.assert_deterministic(
		self,
		injury_sim,
		42,
		"injury simulation is deterministic with same seed"
	)


func test_simulate_injuries_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var _result := InjuryFunctions.simulate_injuries(player, configs, rng)

	# Original player should be unchanged
	assert_that(player).is_equal(player_copy)


func test_simulate_injuries_report_contains_expected_fields() -> void:
	var player := create_test_player()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := InjuryFunctions.simulate_injuries(player, configs, rng)
	var report: Dictionary = result["report"]

	TestHelpersGdUnit4.assert_schema(self, report, [
		"base_chance",
		"proneness",
		"proneness_slope",
		"position_mult",
		"trait_mult",
		"final_chance",
		"roll",
		"injured"
	], "injury simulation report")


func test_simulate_injuries_high_proneness_increases_chance() -> void:
	var low_proneness_player := create_test_player(20.0)
	var high_proneness_player := create_test_player(80.0)
	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var low_result := InjuryFunctions.simulate_injuries(low_proneness_player, configs, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var high_result := InjuryFunctions.simulate_injuries(high_proneness_player, configs, rng2)

	var low_chance: float = low_result["report"]["final_chance"]
	var high_chance: float = high_result["report"]["final_chance"]

	# High proneness should have higher injury chance
	assert_float(high_chance).is_greater(low_chance)


func test_simulate_injuries_position_multiplier_affects_chance() -> void:
	var qb_player := create_test_player()
	qb_player["position"] = "QB"

	var rb_player := create_test_player()
	rb_player["position"] = "RB"

	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var qb_result := InjuryFunctions.simulate_injuries(qb_player, configs, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rb_result := InjuryFunctions.simulate_injuries(rb_player, configs, rng2)

	var qb_mult: float = qb_result["report"]["position_mult"]
	var rb_mult: float = rb_result["report"]["position_mult"]

	# QB should have 0.8, RB should have 1.3
	assert_float(qb_mult).is_equal(0.8)
	assert_float(rb_mult).is_equal(1.3)


func test_simulate_injuries_trait_modifier_affects_chance() -> void:
	var regular_player := create_test_player()

	var durable_player := create_test_player()
	durable_player["hidden_traits"] = ["durable"]

	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var regular_result := InjuryFunctions.simulate_injuries(regular_player, configs, rng1)

	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var durable_result := InjuryFunctions.simulate_injuries(durable_player, configs, rng2)

	var regular_mult: float = regular_result["report"]["trait_mult"]
	var durable_mult: float = durable_result["report"]["trait_mult"]

	# Regular should be 1.0, durable should be 0.7
	assert_float(regular_mult).is_equal(1.0)
	assert_float(durable_mult).is_equal(0.7)


func test_simulate_injuries_adds_injury_to_player() -> void:
	var player := create_test_player()
	var configs := create_test_configs()

	# Try multiple seeds to get an injury
	var found_injury := false
	for i in range(100):
		var test_rng := TestHelpersGdUnit4.create_seeded_rng(12345 + i)
		var result := InjuryFunctions.simulate_injuries(player, configs, test_rng)
		var new_player: Dictionary = result["player"]
		var injuries: Array = new_player.get("injuries", [])

		if not injuries.is_empty():
			found_injury = true
			# Check injury structure
			var injury: Dictionary = injuries[0]
			TestHelpersGdUnit4.assert_schema(self, injury, [
				"type",
				"severity",
				"affected_stats",
				"recovery_timeline",
				"long_term_penalty",
				"career_ending"
			], "injury instance")
			break

	assert_bool(found_injury).is_true()


# ============================================================================
# APPLY INJURY TESTS
# ============================================================================

func test_apply_injury_adds_injury() -> void:
	var player := create_test_player()
	var updated := InjuryFunctions.apply_injury(player, "ankle_sprain", 2.0)

	var injuries: Array = updated.get("injuries", [])
	assert_array(injuries).is_not_empty()
	assert_int(injuries.size()).is_equal(1)


func test_apply_injury_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)

	var _updated := InjuryFunctions.apply_injury(player, "ankle_sprain", 2.0)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


func test_apply_injury_clamps_severity() -> void:
	var player := create_test_player()

	# Test max clamp
	var high_severity := InjuryFunctions.apply_injury(player, "test", 10.0)
	var injury_high: Dictionary = high_severity["injuries"][0]
	assert_float(injury_high["severity"]).is_less_equal(5.0)

	# Test min clamp
	var low_severity := InjuryFunctions.apply_injury(player, "test", -5.0)
	var injury_low: Dictionary = low_severity["injuries"][0]
	assert_float(injury_low["severity"]).is_greater_equal(0.0)


# ============================================================================
# HEAL INJURIES TESTS
# ============================================================================

func test_heal_injuries_reduces_years_remaining() -> void:
	var player := create_test_player()
	player["injuries"] = [{
		"type": "ankle_sprain",
		"severity": 2.0,
		"recovery_timeline": {
			"years_total": 2,
			"years_remaining": 2,
			"status": "active"
		}
	}]

	var healed := InjuryFunctions.heal_injuries(player, 16)  # 1 season = 16 weeks

	var injury: Dictionary = healed["injuries"][0]
	var timeline: Dictionary = injury["recovery_timeline"]

	# Should reduce by 1 year
	assert_int(timeline["years_remaining"]).is_equal(1)


func test_heal_injuries_marks_recovered() -> void:
	var player := create_test_player()
	player["injuries"] = [{
		"type": "ankle_sprain",
		"severity": 2.0,
		"recovery_timeline": {
			"years_total": 1,
			"years_remaining": 1,
			"status": "active"
		}
	}]

	var healed := InjuryFunctions.heal_injuries(player, 16)

	var injury: Dictionary = healed["injuries"][0]
	var timeline: Dictionary = injury["recovery_timeline"]

	assert_int(timeline["years_remaining"]).is_equal(0)
	assert_str(timeline["status"]).is_equal("recovered")


func test_heal_injuries_is_pure() -> void:
	var player := create_test_player()
	player["injuries"] = [{
		"type": "ankle_sprain",
		"recovery_timeline": {
			"years_remaining": 2,
			"status": "active"
		}
	}]
	var player_copy := player.duplicate(true)

	var _healed := InjuryFunctions.heal_injuries(player, 16)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


func test_heal_injuries_preserves_recovered_injuries() -> void:
	var player := create_test_player()
	player["injuries"] = [{
		"type": "old_injury",
		"recovery_timeline": {
			"years_remaining": 0,
			"status": "recovered"
		}
	}]

	var healed := InjuryFunctions.heal_injuries(player, 16)

	var injury: Dictionary = healed["injuries"][0]
	assert_str(injury["recovery_timeline"]["status"]).is_equal("recovered")


func test_heal_injuries_handles_zero_weeks() -> void:
	var player := create_test_player()
	player["injuries"] = [{
		"type": "test",
		"recovery_timeline": {
			"years_remaining": 2,
			"status": "active"
		}
	}]

	var healed := InjuryFunctions.heal_injuries(player, 0)

	var injury: Dictionary = healed["injuries"][0]
	# Should not change
	assert_int(injury["recovery_timeline"]["years_remaining"]).is_equal(2)


func test_heal_injuries_handles_partial_weeks() -> void:
	var player := create_test_player()
	player["injuries"] = [{
		"type": "test",
		"recovery_timeline": {
			"years_remaining": 2,
			"status": "active"
		}
	}]

	var healed := InjuryFunctions.heal_injuries(player, 8)  # Half season

	var injury: Dictionary = healed["injuries"][0]
	# Should still advance by 1 year (any time passed)
	assert_int(injury["recovery_timeline"]["years_remaining"]).is_equal(1)


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_simulate_injuries_with_no_injury_types() -> void:
	var player := create_test_player()
	var configs := create_test_configs()
	configs["main"]["injury"]["types"] = []  # No injury types

	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)
	var result := InjuryFunctions.simulate_injuries(player, configs, rng)

	# Should not crash
	assert_dict(result).is_not_null()


func test_heal_injuries_empty_injuries_list() -> void:
	var player := create_test_player()
	player["injuries"] = []

	var healed := InjuryFunctions.heal_injuries(player, 16)

	# Should handle gracefully
	assert_array(healed["injuries"]).is_empty()


func test_heal_injuries_missing_injuries_field() -> void:
	var player := create_test_player()
	player.erase("injuries")

	var healed := InjuryFunctions.heal_injuries(player, 16)

	# Should handle gracefully
	assert_dict(healed).is_not_null()


func test_injury_chance_clamped_at_95_percent() -> void:
	var player := create_test_player(100.0)  # Very high proneness
	player["position"] = "RB"  # High contact
	player["hidden_traits"] = ["injury_prone"]

	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := InjuryFunctions.simulate_injuries(player, configs, rng)
	var chance: float = result["report"]["final_chance"]

	# Should be clamped at 0.95
	assert_float(chance).is_less_equal(0.95)


# ============================================================================
# RNG CONSUMPTION TESTS
# ============================================================================

func test_rng_consumed_exactly_once_for_no_injury() -> void:
	var player := create_test_player(0.0)  # Very low proneness
	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)

	# Simulate injury (likely no injury)
	var _result := InjuryFunctions.simulate_injuries(player, configs, rng1)

	# Get next values
	var next1 := rng1.randf()

	# Skip one call on rng2 (injury roll)
	var _skip := rng2.randf()
	var next2 := rng2.randf()

	# Should match (1 call was consumed)
	assert_float(next1).is_equal(next2)


# ============================================================================
# INJURY GENERATION TESTS
# ============================================================================

func test_injury_has_valid_type_from_config() -> void:
	var player := create_test_player()
	var configs := create_test_configs()

	# Try multiple seeds to get an injury
	for i in range(100):
		var test_rng := TestHelpersGdUnit4.create_seeded_rng(12345 + i)
		var result := InjuryFunctions.simulate_injuries(player, configs, test_rng)
		var new_player: Dictionary = result["player"]
		var injuries: Array = new_player.get("injuries", [])

		if not injuries.is_empty():
			var injury: Dictionary = injuries[0]
			var injury_type: String = injury["type"]

			# Should be one of the configured types
			assert_bool(
				injury_type == "ankle_sprain" or injury_type == "acl_tear"
			).is_true()
			break


func test_injury_severity_in_range() -> void:
	var player := create_test_player()
	var configs := create_test_configs()

	# Try multiple seeds to get an injury
	for i in range(100):
		var test_rng := TestHelpersGdUnit4.create_seeded_rng(12345 + i)
		var result := InjuryFunctions.simulate_injuries(player, configs, test_rng)
		var new_player: Dictionary = result["player"]
		var injuries: Array = new_player.get("injuries", [])

		if not injuries.is_empty():
			var injury: Dictionary = injuries[0]
			var severity: float = injury["severity"]

			# Should be between 0 and 5 (max of all injury types)
			assert_float(severity).is_greater_equal(0.0)
			assert_float(severity).is_less_equal(5.0)
			break
