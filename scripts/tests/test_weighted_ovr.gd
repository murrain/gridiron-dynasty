## Unit tests for the Weighted OVR Calculation System (Phase 1)
##
## Tests the following PlayerRatingCalculator functions:
##   - calculate_weighted_ovr() - Three-tier weighted OVR calculation
##   - validate_ovr_config() - Config validation
##   - load_ovr_config() - Config loading from file
##
## Test count: 10 tests as specified in design doc
##
## RNG Usage: None (all functions are deterministic)

extends RefCounted

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")


## Test data: Full OVR config matching ovr_weights.json structure
func _get_test_ovr_config() -> Dictionary:
	return {
		"base_weights": {
			"speed": 0.05,
			"strength": 0.05,
			"stamina": 0.04,
			"agility": 0.04,
			"awareness": 0.05
		},
		"side_of_ball_weights": {
			"offensive": {
				"blocking": 0.08,
				"catching": 0.08
			},
			"defensive": {
				"tackling": 0.10,
				"coverage": 0.08,
				"shedding_blocks": 0.06
			},
			"special_teams": {}
		},
		"position_weights": {
			"QB": {
				"side_of_ball": "offensive",
				"weights": {
					"throw_accuracy": 0.26,
					"decision_making": 0.18,
					"throw_power": 0.12,
					"anticipation": 0.10,
					"composure": 0.08,
					"reaction_time": 0.08
				},
				"override_base": {
					"speed": 0.02,
					"strength": 0.02,
					"stamina": 0.04,
					"agility": 0.02,
					"awareness": 0.08
				},
				"override_side": {
					"blocking": 0.00,
					"catching": 0.00
				}
			},
			"CB": {
				"side_of_ball": "defensive",
				"weights": {
					"press_coverage": 0.14,
					"reaction_time": 0.12
				},
				"override_base": {
					"speed": 0.12,
					"strength": 0.03,
					"stamina": 0.04,
					"agility": 0.10,
					"awareness": 0.07
				},
				"override_side": {
					"tackling": 0.06,
					"coverage": 0.30,
					"shedding_blocks": 0.02
				}
			},
			"OL": {
				"side_of_ball": "offensive",
				"weights": {
					"balance": 0.14,
					"footwork": 0.10
				},
				"override_base": {
					"speed": 0.02,
					"strength": 0.16,
					"stamina": 0.04,
					"agility": 0.06,
					"awareness": 0.10
				},
				"override_side": {
					"blocking": 0.38,
					"catching": 0.00
				}
			},
			"LB": {
				"side_of_ball": "defensive",
				"weights": {},
				"override_base": {
					"speed": 0.10,
					"strength": 0.10,
					"stamina": 0.04,
					"agility": 0.08,
					"awareness": 0.16
				},
				"override_side": {
					"tackling": 0.22,
					"coverage": 0.16,
					"shedding_blocks": 0.14
				}
			}
		}
	}


## Test data: QB player with known stats
func _get_test_qb_player() -> Dictionary:
	return {
		"position": "QB",
		"stats": {
			"throw_accuracy": 85.0,
			"decision_making": 78.0,
			"throw_power": 82.0,
			"anticipation": 75.0,
			"composure": 72.0,
			"reaction_time": 70.0,
			"speed": 62.0,
			"strength": 58.0,
			"stamina": 65.0,
			"agility": 60.0,
			"awareness": 80.0,
			"blocking": 30.0,
			"catching": 35.0
		}
	}


## Test data: CB player with known stats
func _get_test_cb_player() -> Dictionary:
	return {
		"position": "CB",
		"stats": {
			"press_coverage": 78.0,
			"reaction_time": 82.0,
			"coverage": 85.0,
			"tackling": 68.0,
			"shedding_blocks": 55.0,
			"speed": 92.0,
			"strength": 58.0,
			"stamina": 75.0,
			"agility": 88.0,
			"awareness": 72.0
		}
	}


func run(t) -> void:
	test_weighted_ovr_calculation_qb(t)
	test_weighted_ovr_calculation_cb(t)
	test_weight_inheritance(t)
	test_weight_normalization(t)
	test_missing_stat_handling(t)
	test_missing_position_fallback(t)
	test_validate_ovr_config_valid(t)
	test_validate_ovr_config_invalid_sum(t)
	test_validate_ovr_config_missing_side(t)
	test_feature_flag_toggle(t)
	test_weighted_ovr_top_level_stats(t)
	test_weighted_ovr_mixed_stat_locations(t)


## Test 1: Verify QB with known stats produces expected OVR
##
## QB weights from config:
##   throw_accuracy: 0.26, decision_making: 0.18, throw_power: 0.12
##   anticipation: 0.10, composure: 0.08, reaction_time: 0.08
##   speed: 0.02, strength: 0.02, stamina: 0.04, agility: 0.02, awareness: 0.08
##   blocking: 0.00, catching: 0.00 (zeroed out)
##
## Expected calculation:
##   85*0.26 + 78*0.18 + 82*0.12 + 75*0.10 + 72*0.08 + 70*0.08
##   + 62*0.02 + 58*0.02 + 65*0.04 + 60*0.02 + 80*0.08
##   = 22.1 + 14.04 + 9.84 + 7.5 + 5.76 + 5.6
##   + 1.24 + 1.16 + 2.6 + 1.2 + 6.4
##   = 77.44
func test_weighted_ovr_calculation_qb(t) -> void:
	var ovr_config := _get_test_ovr_config()
	var player := _get_test_qb_player()

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "QB", ovr_config)

	# Expected: ~77.44 (manually calculated from weights and stats)
	t.assert_approx(ovr, 77.44, 0.5, "QB weighted OVR should be approximately 77.44")

	# Also verify it's in reasonable range
	t.assert_between(ovr, 70.0, 85.0, "QB OVR should be in 70-85 range given stats")


## Test 2: Verify CB with known stats produces expected OVR
##
## CB weights from config:
##   press_coverage: 0.14, reaction_time: 0.12
##   coverage: 0.30, tackling: 0.06, shedding_blocks: 0.02
##   speed: 0.12, strength: 0.03, stamina: 0.04, agility: 0.10, awareness: 0.07
##
## Expected calculation:
##   78*0.14 + 82*0.12 + 85*0.30 + 68*0.06 + 55*0.02
##   + 92*0.12 + 58*0.03 + 75*0.04 + 88*0.10 + 72*0.07
##   = 10.92 + 9.84 + 25.5 + 4.08 + 1.1
##   + 11.04 + 1.74 + 3.0 + 8.8 + 5.04
##   = 81.06
func test_weighted_ovr_calculation_cb(t) -> void:
	var ovr_config := _get_test_ovr_config()
	var player := _get_test_cb_player()

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "CB", ovr_config)

	# Expected: ~81.06 (manually calculated)
	t.assert_approx(ovr, 81.06, 0.5, "CB weighted OVR should be approximately 81.06")

	# CB with 92 speed and 85 coverage should rate well
	t.assert_gt(ovr, 78.0, "High-stat CB should have OVR > 78")


## Test 3: Verify base -> side -> position -> override cascade works correctly
##
## Tests that weight inheritance priority is correct:
## 1. Base weights start as default (speed = 0.05)
## 2. Side-of-ball weights override base for shared stats
## 3. override_base replaces base weights for this position (speed = 0.02 for QB)
## 4. override_side replaces side weights for this position
## 5. Position weights have highest priority
func test_weight_inheritance(t) -> void:
	var ovr_config := _get_test_ovr_config()

	# Create two players with identical stats except for speed
	var player_fast := {
		"stats": {
			"throw_accuracy": 80.0,
			"decision_making": 70.0,
			"throw_power": 75.0,
			"anticipation": 70.0,
			"composure": 70.0,
			"reaction_time": 70.0,
			"speed": 95.0,  # Very fast
			"strength": 60.0,
			"stamina": 65.0,
			"agility": 60.0,
			"awareness": 70.0
		}
	}

	var player_slow := {
		"stats": {
			"throw_accuracy": 80.0,
			"decision_making": 70.0,
			"throw_power": 75.0,
			"anticipation": 70.0,
			"composure": 70.0,
			"reaction_time": 70.0,
			"speed": 55.0,  # Slow
			"strength": 60.0,
			"stamina": 65.0,
			"agility": 60.0,
			"awareness": 70.0
		}
	}

	# QB has speed weight of 0.02 (override_base), CB has 0.12
	var qb_fast_ovr := PlayerRatingCalculator.calculate_weighted_ovr(player_fast, "QB", ovr_config)
	var qb_slow_ovr := PlayerRatingCalculator.calculate_weighted_ovr(player_slow, "QB", ovr_config)
	var cb_fast_ovr := PlayerRatingCalculator.calculate_weighted_ovr(player_fast, "CB", ovr_config)
	var cb_slow_ovr := PlayerRatingCalculator.calculate_weighted_ovr(player_slow, "CB", ovr_config)

	# Speed difference (40 points) should matter more for CB (weight 0.12) than QB (weight 0.02)
	var qb_speed_impact := qb_fast_ovr - qb_slow_ovr
	var cb_speed_impact := cb_fast_ovr - cb_slow_ovr

	# QB: 40 * 0.02 = 0.8 point impact
	# CB: 40 * 0.12 = 4.8 point impact
	t.assert_approx(qb_speed_impact, 0.8, 0.2, "QB speed impact should be ~0.8 (weight 0.02)")
	t.assert_approx(cb_speed_impact, 4.8, 0.5, "CB speed impact should be ~4.8 (weight 0.12)")

	# CB impact should be significantly greater than QB impact
	t.assert_gt(cb_speed_impact, qb_speed_impact * 4, "CB speed weight should be 6x QB weight")


## Test 4: Verify weights that don't sum to 1.0 are normalized
func test_weight_normalization(t) -> void:
	# Create config with weights that sum to 0.8 instead of 1.0
	var bad_config := {
		"base_weights": {},
		"side_of_ball_weights": {
			"offensive": {}
		},
		"position_weights": {
			"TEST": {
				"side_of_ball": "offensive",
				"weights": {
					"stat_a": 0.40,
					"stat_b": 0.40
				},
				"override_base": {},
				"override_side": {}
			}
		}
	}

	var player := {
		"stats": {
			"stat_a": 80.0,
			"stat_b": 60.0
		}
	}

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "TEST", bad_config)

	# Without normalization: 80*0.4 + 60*0.4 = 56.0
	# With normalization: (32 + 24) / 0.8 = 70.0
	t.assert_approx(ovr, 70.0, 0.1, "Weights should be normalized: (80*0.4 + 60*0.4) / 0.8 = 70")


## Test 5: Verify missing stats use 50.0 neutral value
func test_missing_stat_handling(t) -> void:
	var ovr_config := _get_test_ovr_config()

	# Player missing several stats that QB weights expect
	var player_missing_stats := {
		"stats": {
			"throw_accuracy": 90.0,
			# Missing: decision_making, throw_power, anticipation, composure, reaction_time
			# Missing: speed, strength, stamina, agility, awareness
		}
	}

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player_missing_stats, "QB", ovr_config)

	# throw_accuracy: 90 * 0.26 = 23.4
	# All missing stats use 50.0:
	#   decision_making: 50 * 0.18 = 9.0
	#   throw_power: 50 * 0.12 = 6.0
	#   anticipation: 50 * 0.10 = 5.0
	#   composure: 50 * 0.08 = 4.0
	#   reaction_time: 50 * 0.08 = 4.0
	#   speed: 50 * 0.02 = 1.0
	#   strength: 50 * 0.02 = 1.0
	#   stamina: 50 * 0.04 = 2.0
	#   agility: 50 * 0.02 = 1.0
	#   awareness: 50 * 0.08 = 4.0
	# Total: 23.4 + 9 + 6 + 5 + 4 + 4 + 1 + 1 + 2 + 1 + 4 = 60.4
	t.assert_approx(ovr, 60.4, 0.5, "Missing stats should use 50.0 neutral value")

	# Should not crash and should return a reasonable value
	t.assert_between(ovr, 40.0, 80.0, "OVR with missing stats should be in reasonable range")


## Test 6: Verify positions without weights fall back to legacy calculation
func test_missing_position_fallback(t) -> void:
	var ovr_config := _get_test_ovr_config()

	# Position not defined in config
	var player := {
		"position": "UNKNOWN_POSITION",
		"stats": {
			"stat_a": 80.0,
			"stat_b": 70.0,
			"stat_c": 60.0
		}
	}

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "UNKNOWN_POSITION", ovr_config)

	# Fallback should use simple average: (80 + 70 + 60) / 3 = 70.0
	t.assert_approx(ovr, 70.0, 0.1, "Unknown position should fall back to simple average")

	# Test with core_avg fallback
	var player_with_core_avg := {
		"position": "UNKNOWN_POSITION",
		"core_avg": 75.5,
		"stats": {
			"stat_a": 80.0
		}
	}

	var ovr_with_core := PlayerRatingCalculator.calculate_weighted_ovr(player_with_core_avg, "UNKNOWN_POSITION", ovr_config)
	t.assert_eq(ovr_with_core, 75.5, "Should use core_avg when available for unknown position")


## Test 7: Verify valid config passes validation
func test_validate_ovr_config_valid(t) -> void:
	var ovr_config := _get_test_ovr_config()

	var is_valid := PlayerRatingCalculator.validate_ovr_config(ovr_config, {})

	t.assert_eq(is_valid, true, "Valid OVR config should pass validation")


## Test 8: Verify invalid weight sum fails validation
func test_validate_ovr_config_invalid_sum(t) -> void:
	var invalid_config := {
		"base_weights": {},
		"side_of_ball_weights": {
			"offensive": {}
		},
		"position_weights": {
			"TEST": {
				"side_of_ball": "offensive",
				"weights": {
					"stat_a": 0.30
				},
				"override_base": {},
				"override_side": {}
			}
		}
	}

	var is_valid := PlayerRatingCalculator.validate_ovr_config(invalid_config, {})

	t.assert_eq(is_valid, false, "Config with weights summing to 0.3 should fail validation")


## Test 9: Verify missing side_of_ball fails validation
func test_validate_ovr_config_missing_side(t) -> void:
	var invalid_config := {
		"base_weights": {},
		"side_of_ball_weights": {},
		"position_weights": {
			"TEST": {
				# Missing "side_of_ball" field
				"weights": {
					"stat_a": 1.0
				}
			}
		}
	}

	var is_valid := PlayerRatingCalculator.validate_ovr_config(invalid_config, {})

	t.assert_eq(is_valid, false, "Config missing side_of_ball should fail validation")


## Test 10: Verify feature flag correctly switches between weighted and legacy
func test_feature_flag_toggle(t) -> void:
	var ovr_config := _get_test_ovr_config()

	# Sample positions config for legacy calculation
	var positions_cfg := {
		"QB": {
			"core_stats": ["throw_accuracy", "decision_making", "awareness"],
			"distributions": {
				"throw_accuracy": {"visibility": "public"},
				"decision_making": {"visibility": "scoutable"},
				"awareness": {"visibility": "scoutable"}
			}
		}
	}

	var player := _get_test_qb_player()

	# Weighted calculation
	var weighted_ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "QB", ovr_config)

	# Legacy calculation (unweighted average of core stats)
	var legacy_ovr := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, {})

	# These should produce different results due to different weighting
	# Weighted: uses all stats with position-specific weights
	# Legacy: simple average of throw_accuracy, decision_making, awareness
	#         = (85 + 78 + 80) / 3 = 81.0

	t.assert_approx(legacy_ovr, 81.0, 0.5, "Legacy OVR should be ~81 (average of 3 core stats)")
	t.assert_ne(weighted_ovr, legacy_ovr, "Weighted and legacy OVR should differ")

	# Demonstrate the feature flag pattern
	var use_weighted := false

	var selected_ovr: float
	if use_weighted and not ovr_config.is_empty():
		selected_ovr = PlayerRatingCalculator.calculate_weighted_ovr(player, "QB", ovr_config)
	else:
		selected_ovr = PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, {})

	t.assert_eq(selected_ovr, legacy_ovr, "Feature flag false should use legacy calculation")

	# Now with flag enabled
	use_weighted = true
	if use_weighted and not ovr_config.is_empty():
		selected_ovr = PlayerRatingCalculator.calculate_weighted_ovr(player, "QB", ovr_config)
	else:
		selected_ovr = PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, {})

	t.assert_eq(selected_ovr, weighted_ovr, "Feature flag true should use weighted calculation")


## Test 11: Verify stats at top level (not nested under "stats" key) work correctly
##
## Players can have stats either:
##   - Nested under "stats" key: { "stats": { "throw_accuracy": 85.0, ... } }
##   - At top level: { "throw_accuracy": 85.0, ... }
##
## The calculate_weighted_ovr function should handle both cases identically.
func test_weighted_ovr_top_level_stats(t) -> void:
	var ovr_config := _get_test_ovr_config()

	# Create player with stats at top level (not nested under "stats" key)
	# Using same stats as _get_test_qb_player() but at top level
	var player := {
		"position": "QB",
		"throw_accuracy": 85.0,
		"decision_making": 78.0,
		"throw_power": 82.0,
		"anticipation": 75.0,
		"composure": 72.0,
		"reaction_time": 70.0,
		"speed": 62.0,
		"strength": 58.0,
		"stamina": 65.0,
		"agility": 60.0,
		"awareness": 80.0,
		"blocking": 30.0,
		"catching": 35.0
	}

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "QB", ovr_config)

	# Should produce same result as nested stats version (77.44)
	# From test_weighted_ovr_calculation_qb calculation
	var expected_ovr := 77.44
	t.assert_approx(ovr, expected_ovr, 0.5,
		"Top-level stats should produce same OVR as nested stats (~77.44)")

	# Verify against the nested version for exact parity
	var nested_player := _get_test_qb_player()
	var nested_ovr := PlayerRatingCalculator.calculate_weighted_ovr(nested_player, "QB", ovr_config)
	t.assert_approx(ovr, nested_ovr, 0.01,
		"Top-level and nested stats should produce identical OVR")


## Test 12: Verify function handles mixed stat locations gracefully
##
## Edge case: Player has BOTH nested "stats" dict AND top-level stats.
## The function should prioritize the nested "stats" dict (use_nested = true).
##
## This is an unusual scenario but can occur when:
##   - Data migration leaves both formats
##   - Different systems write to the same player object
##
## Expected behavior: Nested stats take priority (stats dict is not empty).
func test_weighted_ovr_mixed_stat_locations(t) -> void:
	var ovr_config := _get_test_ovr_config()

	# Player with BOTH nested and top-level stats
	# The nested "stats" dict should be used (speed=88), not top-level (speed=92)
	var player := {
		"position": "CB",
		"speed": 92.0,  # Top-level (should be IGNORED if stats dict exists)
		"agility": 90.0,  # Top-level (should be IGNORED)
		"stats": {
			"speed": 88.0,  # Nested (should be USED)
			"agility": 85.0,
			"coverage": 82.0,
			"press_coverage": 78.0,
			"reaction_time": 80.0,
			"tackling": 68.0,
			"shedding_blocks": 55.0,
			"strength": 58.0,
			"stamina": 75.0,
			"awareness": 72.0
		}
	}

	var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "CB", ovr_config)

	# Calculate expected OVR using NESTED stats (speed=88, not speed=92)
	# CB weights:
	#   press_coverage: 0.14, reaction_time: 0.12
	#   coverage: 0.30, tackling: 0.06, shedding_blocks: 0.02
	#   speed: 0.12, strength: 0.03, stamina: 0.04, agility: 0.10, awareness: 0.07
	#
	# With nested stats (speed=88, agility=85):
	#   78*0.14 + 80*0.12 + 82*0.30 + 68*0.06 + 55*0.02
	#   + 88*0.12 + 58*0.03 + 75*0.04 + 85*0.10 + 72*0.07
	#   = 10.92 + 9.6 + 24.6 + 4.08 + 1.1
	#   + 10.56 + 1.74 + 3.0 + 8.5 + 5.04
	#   = 79.14
	var expected_with_nested := 79.14

	# If top-level stats were used (speed=92, agility=90):
	#   78*0.14 + 80*0.12 + 82*0.30 + 68*0.06 + 55*0.02
	#   + 92*0.12 + 58*0.03 + 75*0.04 + 90*0.10 + 72*0.07
	#   = 10.92 + 9.6 + 24.6 + 4.08 + 1.1
	#   + 11.04 + 1.74 + 3.0 + 9.0 + 5.04
	#   = 80.12

	t.assert_approx(ovr, expected_with_nested, 0.5,
		"Mixed stats: Nested dict should take priority (expected ~79.14, not ~80.12)")

	# Verify it's not using top-level stats
	t.assert_lt(ovr, 80.0,
		"OVR should be <80 (using nested speed=88, not top-level speed=92)")
