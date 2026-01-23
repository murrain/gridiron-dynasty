extends GdUnitTestSuite
class_name TestGrowthFunctions

const GrowthFunctions = preload("res://scripts/core/transformations/GrowthFunctions.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

# ============================================================================
# SETUP
# ============================================================================

func create_test_configs() -> Dictionary:
	return {
		"main": {
			"annual_base_progress_min": 1.0,
			"annual_base_progress_max": 4.0,
			"annual_progress_cap": 6.0,
			"development": {
				"prime_growth_min": 0.2,
				"prime_growth_max": 0.8,
				"decline_min": 0.4,
				"decline_max": 1.6,
				"curve_multipliers": {
					"mid": {
						"growth": 1.0,
						"prime": 0.35,
						"decline": 1.0
					}
				}
			},
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
					"decline_start": 33,
					"curve": "mid"
				}
			},
			"RB": {
				"development": {
					"peak_age": 25,
					"decline_start": 29,
					"curve": "mid"
				}
			}
		},
		"stats": {
			"stats": [
				{"name": "speed", "type": "base"},
				{"name": "strength", "type": "base"},
				{"name": "awareness", "type": "base"},
				{"name": "overall", "type": "derived"}
			]
		}
	}


func create_test_player(age: int = 22, position: String = "QB") -> Dictionary:
	return {
		"age": age,
		"position": position,
		"stats": {
			"speed": 70.0,
			"strength": 75.0,
			"awareness": 65.0
		},
		"potential": {
			"speed": 85.0,
			"strength": 90.0,
			"awareness": 80.0
		},
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		}
	}


func create_test_context() -> Dictionary:
	return {
		"program_quality": 1.0,
		"coach_specialization": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}


# ============================================================================
# APPLY DEVELOPMENT TESTS
# ============================================================================

func test_apply_development_returns_new_player() -> void:
	var player := create_test_player()
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Should return dictionary with player and report
	assert_dict(result).contains_keys(["player", "report"])

	# Original player should be unchanged (purity)
	assert_float(player["stats"]["speed"]).is_equal(70.0)

	# New player should have different values
	assert_object(result["player"]).is_not_same(player)


func test_apply_development_growth_phase_increases_stats() -> void:
	var player := create_test_player(22, "QB")  # Growth phase
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var new_player: Dictionary = result["player"]

	# In growth phase, at least some stats should increase
	var speed_increased := new_player["stats"]["speed"] > player["stats"]["speed"]
	var strength_increased := new_player["stats"]["strength"] > player["stats"]["strength"]
	var awareness_increased := new_player["stats"]["awareness"] > player["stats"]["awareness"]

	# At least one stat should have increased
	assert_bool(speed_increased or strength_increased or awareness_increased).is_true()


func test_apply_development_respects_potential() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 84.0  # Near potential
	player["potential"]["speed"] = 85.0  # Very close to potential

	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var new_player: Dictionary = result["player"]

	# Should not exceed potential
	assert_float(new_player["stats"]["speed"]).is_less_equal(85.0)


func test_apply_development_is_deterministic() -> void:
	var create_dev_call := func(rng_instance: RandomNumberGenerator) -> Dictionary:
		var player := create_test_player()
		var context := create_test_context()
		var configs := create_test_configs()
		return GrowthFunctions.apply_development(player, context, configs, rng_instance)

	TestHelpersGdUnit4.assert_deterministic(
		self,
		create_dev_call,
		42,
		"apply_development with same seed produces same results"
	)


func test_apply_development_report_contains_expected_fields() -> void:
	var player := create_test_player()
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]

	# Report should have expected fields
	TestHelpersGdUnit4.assert_schema(self, report, [
		"age",
		"phase",
		"stat_entries",
		"decline_multiplier",
		"context_multiplier"
	], "development report")

	assert_str(report["phase"]).is_equal("growth")
	assert_int(report["age"]).is_equal(22)


func test_apply_development_stat_entries_have_details() -> void:
	var player := create_test_player()
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]
	var stat_entries: Array = report["stat_entries"]

	# Should have entries for base stats
	assert_array(stat_entries).is_not_empty()

	# Check first entry has expected fields
	if stat_entries.size() > 0:
		var entry: Dictionary = stat_entries[0]
		TestHelpersGdUnit4.assert_schema(self, entry, [
			"stat",
			"before",
			"potential",
			"raw_draw",
			"multiplier",
			"delta",
			"after"
		], "stat entry")


func test_apply_development_handles_missing_stats() -> void:
	var player := {"age": 22, "position": "QB"}  # No stats
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]

	# Should handle gracefully
	assert_array(report["stat_entries"]).is_empty()


# ============================================================================
# CONTEXT MULTIPLIER TESTS
# ============================================================================

func test_context_multiplier_neutral() -> void:
	var context := {
		"program_quality": 1.0,
		"coach_specialization": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}

	var multiplier := GrowthFunctions._compute_context_multiplier(context)

	# All neutral factors should give 1.0
	assert_float(multiplier).is_equal(1.0)


func test_context_multiplier_good_program() -> void:
	var context := {
		"program_quality": 1.2,
		"coach_specialization": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}

	var multiplier := GrowthFunctions._compute_context_multiplier(context)

	# Good program should increase multiplier
	assert_float(multiplier).is_greater(1.0)


func test_context_multiplier_poor_program() -> void:
	var context := {
		"program_quality": 0.8,
		"coach_specialization": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}

	var multiplier := GrowthFunctions._compute_context_multiplier(context)

	# Poor program should decrease multiplier
	assert_float(multiplier).is_less(1.0)


func test_context_multiplier_clamped_min() -> void:
	var context := {
		"program_quality": 0.5,
		"coach_specialization": 0.5,
		"usage": 0.5,
		"competition_tier": 0.5,
		"rehab_quality": 0.5
	}

	var multiplier := GrowthFunctions._compute_context_multiplier(context)

	# Should be clamped at 0.7 minimum
	assert_float(multiplier).is_greater_equal(0.7)


func test_context_multiplier_clamped_max() -> void:
	var context := {
		"program_quality": 1.5,
		"coach_specialization": 1.5,
		"usage": 1.5,
		"competition_tier": 1.5,
		"rehab_quality": 1.5
	}

	var multiplier := GrowthFunctions._compute_context_multiplier(context)

	# Should be clamped at 1.4 maximum
	assert_float(multiplier).is_less_equal(1.4)


func test_context_multiplier_additive_not_multiplicative() -> void:
	# Test that the system uses additive deviations
	var context1 := {
		"program_quality": 0.8,  # -0.2 deviation
		"coach_specialization": 0.8,  # -0.2 deviation
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}

	var multiplier := GrowthFunctions._compute_context_multiplier(context1)

	# Two -0.2 deviations should sum to -0.4
	# Final multiplier: 1.0 + (-0.4) = 0.6, but clamped to 0.7
	assert_float(multiplier).is_equal(0.7)


func test_context_multiplier_empty_context() -> void:
	var context := {}

	var multiplier := GrowthFunctions._compute_context_multiplier(context)

	# Should default to 1.0
	assert_float(multiplier).is_equal(1.0)


# ============================================================================
# WEAR MULTIPLIER TESTS
# ============================================================================

func test_wear_multiplier_no_wear() -> void:
	var player := create_test_player()
	player["wear"] = {
		"snaps": 0,
		"collisions": 0,
		"injury_count": 0
	}
	var configs := create_test_configs()

	var wear_mult := GrowthFunctions._compute_wear_multiplier(player, configs)

	# No wear should give 1.0
	assert_float(wear_mult).is_equal(1.0)


func test_wear_multiplier_high_snaps() -> void:
	var player := create_test_player()
	player["wear"] = {
		"snaps": 16000,  # 2x scale
		"collisions": 0,
		"injury_count": 0
	}
	var configs := create_test_configs()

	var wear_mult := GrowthFunctions._compute_wear_multiplier(player, configs)

	# High snaps should increase decline multiplier
	assert_float(wear_mult).is_greater(1.0)


func test_wear_multiplier_high_collisions() -> void:
	var player := create_test_player()
	player["wear"] = {
		"snaps": 0,
		"collisions": 5200,  # 2x scale
		"injury_count": 0
	}
	var configs := create_test_configs()

	var wear_mult := GrowthFunctions._compute_wear_multiplier(player, configs)

	# High collisions should increase decline multiplier
	assert_float(wear_mult).is_greater(1.0)


func test_wear_multiplier_high_injuries() -> void:
	var player := create_test_player()
	player["wear"] = {
		"snaps": 0,
		"collisions": 0,
		"injury_count": 6  # 1x scale
	}
	var configs := create_test_configs()

	var wear_mult := GrowthFunctions._compute_wear_multiplier(player, configs)

	# High injuries should increase decline multiplier
	assert_float(wear_mult).is_greater(1.0)


func test_wear_multiplier_clamped_max() -> void:
	var player := create_test_player()
	player["wear"] = {
		"snaps": 100000,
		"collisions": 50000,
		"injury_count": 100
	}
	var configs := create_test_configs()

	var wear_mult := GrowthFunctions._compute_wear_multiplier(player, configs)

	# Should be clamped at 1.6 maximum
	assert_float(wear_mult).is_less_equal(1.6)


func test_wear_multiplier_clamped_min() -> void:
	var player := create_test_player()
	player["wear"] = {
		"snaps": 0,
		"collisions": 0,
		"injury_count": 0
	}
	var configs := create_test_configs()

	var wear_mult := GrowthFunctions._compute_wear_multiplier(player, configs)

	# Should be clamped at 1.0 minimum
	assert_float(wear_mult).is_greater_equal(1.0)


# ============================================================================
# PHASE-SPECIFIC TESTS
# ============================================================================

func test_growth_phase_uses_growth_multiplier() -> void:
	var player := create_test_player(22, "QB")  # Growth phase (< 28)
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]

	assert_str(report["phase"]).is_equal("growth")


func test_prime_phase_uses_prime_multiplier() -> void:
	var player := create_test_player(30, "QB")  # Prime phase (28-33)
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]

	assert_str(report["phase"]).is_equal("prime")


func test_decline_phase_uses_decline_multiplier() -> void:
	var player := create_test_player(34, "QB")  # Decline phase (>= 33)
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]

	assert_str(report["phase"]).is_equal("decline")


func test_decline_phase_can_decrease_stats() -> void:
	var player := create_test_player(35, "QB")  # Decline phase
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	# Run multiple times to ensure we get at least some decline
	var found_decrease := false
	for i in range(10):
		var test_rng := TestHelpersGdUnit4.create_seeded_rng(12345 + i)
		var result := GrowthFunctions.apply_development(player, context, configs, test_rng)
		var new_player: Dictionary = result["player"]

		if new_player["stats"]["speed"] < player["stats"]["speed"]:
			found_decrease = true
			break

	# Should find at least one case of decline
	assert_bool(found_decrease).is_true()


# ============================================================================
# POSITION-SPECIFIC TESTS
# ============================================================================

func test_rb_has_earlier_decline_than_qb() -> void:
	var configs := create_test_configs()

	# RB at 30 should be in decline (decline_start=29)
	var rb_player := create_test_player(30, "RB")
	var rb_rng := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rb_result := GrowthFunctions.apply_development(
		rb_player, create_test_context(), configs, rb_rng
	)

	# QB at 30 should be in prime (decline_start=33)
	var qb_player := create_test_player(30, "QB")
	var qb_rng := TestHelpersGdUnit4.create_seeded_rng(12345)
	var qb_result := GrowthFunctions.apply_development(
		qb_player, create_test_context(), configs, qb_rng
	)

	assert_str(rb_result["report"]["phase"]).is_equal("decline")
	assert_str(qb_result["report"]["phase"]).is_equal("prime")


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_stat_at_potential_cannot_increase() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 85.0
	player["potential"]["speed"] = 85.0  # Already at potential

	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var new_player: Dictionary = result["player"]

	# Should not exceed potential
	assert_float(new_player["stats"]["speed"]).is_less_equal(85.0)


func test_stats_clamped_to_100() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 99.0
	player["potential"]["speed"] = 150.0  # Unrealistic high potential

	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var new_player: Dictionary = result["player"]

	# Should be clamped at 100
	assert_float(new_player["stats"]["speed"]).is_less_equal(100.0)


func test_stats_clamped_to_0() -> void:
	var player := create_test_player(40, "QB")  # Very old, decline phase
	player["stats"]["speed"] = 5.0  # Very low

	var context := create_test_context()
	var configs := create_test_configs()

	# Run multiple times with different seeds to ensure decline
	for i in range(50):
		var test_rng := TestHelpersGdUnit4.create_seeded_rng(12345 + i)
		var result := GrowthFunctions.apply_development(player, context, configs, test_rng)
		var new_player: Dictionary = result["player"]

		# Should never go below 0
		assert_float(new_player["stats"]["speed"]).is_greater_equal(0.0)


func test_derived_stats_not_processed() -> void:
	var player := create_test_player()
	player["stats"]["overall"] = 75.0  # Derived stat

	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var result := GrowthFunctions.apply_development(player, context, configs, rng)
	var report: Dictionary = result["report"]
	var stat_entries: Array = report["stat_entries"]

	# Should not have entry for "overall" (derived stat)
	var has_overall := false
	for entry in stat_entries:
		if (entry as Dictionary).get("stat") == "overall":
			has_overall = true
			break

	assert_bool(has_overall).is_false()


# ============================================================================
# PURITY TESTS
# ============================================================================

func test_apply_development_does_not_modify_player() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)
	var context := create_test_context()
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var _result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Original player should be completely unchanged
	assert_that(player).is_equal(player_copy)


func test_apply_development_does_not_modify_context() -> void:
	var player := create_test_player()
	var context := create_test_context()
	var context_copy := context.duplicate(true)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var _result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Context should be unchanged
	assert_that(context).is_equal(context_copy)


func test_apply_development_does_not_modify_configs() -> void:
	var player := create_test_player()
	var context := create_test_context()
	var configs := create_test_configs()
	var configs_copy := configs.duplicate(true)
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var _result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Configs should be unchanged
	assert_that(configs).is_equal(configs_copy)
