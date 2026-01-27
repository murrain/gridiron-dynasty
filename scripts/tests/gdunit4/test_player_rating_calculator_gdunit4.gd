extends GdUnitTestSuite
class_name TestPlayerRatingCalculatorGdUnit4

## Tests for PlayerRatingCalculator - Overall rating calculations
##
## Validates:
## - Weighted OVR calculation (three-tier system)
## - Legacy calculation methods (deprecated)
## - Visibility-based ratings (scouting)
## - Weight inheritance (base → side → position)
## - Config validation
## - Determinism (no RNG)

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# WEIGHTED OVR CALCULATION TESTS
# =============================================================================

func test_weighted_ovr_uses_position_weights() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.4,
			"strength": 0.3,
			"awareness": 0.3
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {}  # Uses base weights
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)

	# (80 * 0.4) + (70 * 0.3) + (75 * 0.3) = 32 + 21 + 22.5 = 75.5
	assert_float(result).is_equal_approx(75.5, 0.1)


func test_weighted_ovr_position_weights_override_base_weights() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.4,
			"strength": 0.3,
			"awareness": 0.3
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {
					"speed": 0.6  # Override base weight for speed
				}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)

	# (80 * 0.6) + (70 * 0.3) + (75 * 0.3) = 48 + 21 + 22.5 = 91.5
	# But weights sum to 1.2, so normalize: 91.5 / 1.2 = 76.25
	assert_float(result).is_equal_approx(76.25, 0.1)


func test_weighted_ovr_side_of_ball_weights_layer_over_base() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"tackling": 65.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.4,
			"strength": 0.3,
			"tackling": 0.3
		},
		"side_of_ball_weights": {
			"defensive": {
				"tackling": 0.4  # Defensive side values tackling more
			}
		},
		"position_weights": {
			"CB": {
				"side_of_ball": "defensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "CB", ovr_config)

	# Base: speed=0.4, strength=0.3, tackling=0.3
	# Side (defensive): tackling=0.4 (overrides base)
	# Final: speed=0.4, strength=0.3, tackling=0.4
	# (80 * 0.4) + (70 * 0.3) + (65 * 0.4) = 32 + 21 + 26 = 79
	# Weights sum to 1.1, normalize: 79 / 1.1 = 71.8
	assert_float(result).is_equal_approx(71.8, 0.2)


func test_weighted_ovr_normalizes_when_weights_dont_sum_to_one() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.7,  # Weights sum to 1.2 (intentional)
			"strength": 0.5
		},
		"position_weights": {
			"ATH": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "ATH", ovr_config)

	# (80 * 0.7) + (70 * 0.5) = 56 + 35 = 91
	# Weights sum to 1.2, normalize: 91 / 1.2 = 75.83
	assert_float(result).is_equal_approx(75.83, 0.1)


func test_weighted_ovr_uses_neutral_value_for_missing_stats() -> void:
	var player := {
		"stats": {
			"speed": 80.0
			# Missing: strength, awareness
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.4,
			"strength": 0.3,
			"awareness": 0.3
		},
		"position_weights": {
			"ATH": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "ATH", ovr_config)

	# (80 * 0.4) + (50 * 0.3) + (50 * 0.3) = 32 + 15 + 15 = 62
	assert_float(result).is_equal_approx(62.0, 0.1)


func test_weighted_ovr_handles_nested_stats_dictionary() -> void:
	var player := {
		"stats": {
			"speed": 85.0,
			"strength": 75.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.5,
			"strength": 0.5
		},
		"position_weights": {
			"ATH": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "ATH", ovr_config)

	# (85 * 0.5) + (75 * 0.5) = 42.5 + 37.5 = 80
	assert_float(result).is_equal_approx(80.0, 0.1)


func test_weighted_ovr_handles_top_level_stats() -> void:
	var player := {
		# Stats at top level (no nested "stats" dict)
		"speed": 85.0,
		"strength": 75.0
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.5,
			"strength": 0.5
		},
		"position_weights": {
			"ATH": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "ATH", ovr_config)

	# (85 * 0.5) + (75 * 0.5) = 42.5 + 37.5 = 80
	assert_float(result).is_equal_approx(80.0, 0.1)


# =============================================================================
# WEIGHT INHERITANCE TESTS
# =============================================================================

func test_weight_inheritance_priority_order() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 60.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.2,
			"strength": 0.2,
			"awareness": 0.6
		},
		"side_of_ball_weights": {
			"offensive": {
				"speed": 0.4  # Override base
			}
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"override_base": {
					"strength": 0.3  # Override base for this position
				},
				"weights": {
					"awareness": 0.3  # Highest priority override
				}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)

	# Final weights after inheritance:
	# - speed: 0.4 (from side_of_ball_weights)
	# - strength: 0.3 (from override_base)
	# - awareness: 0.3 (from position weights)
	# (80 * 0.4) + (70 * 0.3) + (60 * 0.3) = 32 + 21 + 18 = 71
	assert_float(result).is_equal_approx(71.0, 0.1)


func test_override_side_replaces_side_of_ball_weights() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.3,
			"strength": 0.7
		},
		"side_of_ball_weights": {
			"offensive": {
				"speed": 0.6  # This would normally apply
			}
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"override_side": {
					"speed": 0.8  # But this overrides the side weight
				}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)

	# Final weights:
	# - speed: 0.8 (from override_side)
	# - strength: 0.7 (from base)
	# (80 * 0.8) + (70 * 0.7) = 64 + 49 = 113
	# Weights sum to 1.5, normalize: 113 / 1.5 = 75.33
	assert_float(result).is_equal_approx(75.33, 0.1)


# =============================================================================
# FALLBACK CALCULATION TESTS
# =============================================================================

func test_fallback_uses_core_avg_when_available() -> void:
	var player := {
		"core_avg": 82.5,
		"stats": {
			"speed": 70.0,  # Different from core_avg
			"strength": 60.0
		}
	}

	var ovr_config := {}  # No position weights

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "UNKNOWN_POS", ovr_config)

	# Should use core_avg fallback
	assert_float(result).is_equal(82.5)


func test_fallback_calculates_average_when_no_config() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 90.0
		}
	}

	var ovr_config := {}  # No position weights

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "UNKNOWN_POS", ovr_config)

	# Should calculate simple average: (80 + 70 + 90) / 3 = 80
	assert_float(result).is_equal_approx(80.0, 0.1)


# =============================================================================
# CONFIG VALIDATION TESTS
# =============================================================================

func test_validate_ovr_config_accepts_valid_config() -> void:
	var ovr_config := {
		"base_weights": {
			"speed": 0.5,
			"strength": 0.5
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var is_valid := PlayerRatingCalculator.validate_ovr_config(ovr_config, {})

	assert_bool(is_valid).is_true()


func test_validate_ovr_config_rejects_missing_side_of_ball() -> void:
	var ovr_config := {
		"base_weights": {
			"speed": 0.5,
			"strength": 0.5
		},
		"position_weights": {
			"RB": {
				# Missing "side_of_ball"
				"weights": {}
			}
		}
	}

	var is_valid := PlayerRatingCalculator.validate_ovr_config(ovr_config, {})

	assert_bool(is_valid).is_false()


func test_validate_ovr_config_rejects_weights_not_summing_to_one() -> void:
	var ovr_config := {
		"base_weights": {
			"speed": 0.3,  # Sum = 0.5, not 1.0
			"strength": 0.2
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var is_valid := PlayerRatingCalculator.validate_ovr_config(ovr_config, {})

	# Should reject due to weights not summing to ~1.0
	assert_bool(is_valid).is_false()


func test_validate_ovr_config_accepts_tolerance_in_weight_sum() -> void:
	var ovr_config := {
		"base_weights": {
			"speed": 0.501,  # Sum = 1.002, within tolerance
			"strength": 0.501
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var is_valid := PlayerRatingCalculator.validate_ovr_config(ovr_config, {})

	# Should accept due to being within tolerance
	assert_bool(is_valid).is_true()


# =============================================================================
# STAT VISIBILITY TESTS (Scouting)
# =============================================================================

func test_get_stat_visibility_returns_correct_tier() -> void:
	var positions_cfg := {
		"QB": {
			"distributions": {
				"accuracy": {"visibility": "public"},
				"decision": {"visibility": "scoutable"},
				"intangibles": {"visibility": "hidden"}
			}
		}
	}

	assert_string(PlayerRatingCalculator.get_stat_visibility("accuracy", "QB", positions_cfg)).is_equal("public")
	assert_string(PlayerRatingCalculator.get_stat_visibility("decision", "QB", positions_cfg)).is_equal("scoutable")
	assert_string(PlayerRatingCalculator.get_stat_visibility("intangibles", "QB", positions_cfg)).is_equal("hidden")


func test_get_stat_visibility_returns_empty_for_undefined_stat() -> void:
	var positions_cfg := {
		"QB": {
			"distributions": {}
		}
	}

	assert_string(PlayerRatingCalculator.get_stat_visibility("unknown_stat", "QB", positions_cfg)).is_empty()


func test_calculate_displayed_rating_includes_public_and_scouted_stats() -> void:
	var player := {
		"stats": {
			"accuracy": 85.0,      # public
			"decision": 75.0,      # scoutable
			"intangibles": 90.0    # hidden
		}
	}

	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy", "decision", "intangibles"],
			"distributions": {
				"accuracy": {"visibility": "public"},
				"decision": {"visibility": "scoutable"},
				"intangibles": {"visibility": "hidden"}
			}
		}
	}

	var scouting_data := {
		"revealed_stats": {
			"decision": 77.0  # Scouted value (with noise)
		}
	}

	var result := PlayerRatingCalculator.calculate_displayed_rating(player, "QB", positions_cfg, scouting_data)

	# Should average: accuracy (85) + decision_scouted (77) = 162 / 2 = 81
	# Hidden stat (intangibles) excluded
	assert_float(result).is_equal_approx(81.0, 0.1)


func test_calculate_displayed_rating_excludes_unscouted_scoutable_stats() -> void:
	var player := {
		"stats": {
			"accuracy": 85.0,      # public
			"decision": 75.0,      # scoutable but NOT scouted
			"intangibles": 90.0    # hidden
		}
	}

	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy", "decision", "intangibles"],
			"distributions": {
				"accuracy": {"visibility": "public"},
				"decision": {"visibility": "scoutable"},
				"intangibles": {"visibility": "hidden"}
			}
		}
	}

	var scouting_data := {
		"revealed_stats": {}  # Nothing scouted
	}

	var result := PlayerRatingCalculator.calculate_displayed_rating(player, "QB", positions_cfg, scouting_data)

	# Should only use public stat: accuracy (85)
	assert_float(result).is_equal(85.0)


func test_calculate_true_rating_includes_all_public_and_scoutable_stats() -> void:
	var player := {
		"stats": {
			"accuracy": 85.0,      # public
			"decision": 75.0,      # scoutable
			"intangibles": 90.0    # hidden
		}
	}

	var positions_cfg := {
		"QB": {
			"core_stats": ["accuracy", "decision", "intangibles"],
			"distributions": {
				"accuracy": {"visibility": "public"},
				"decision": {"visibility": "scoutable"},
				"intangibles": {"visibility": "hidden"}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_true_rating(player, "QB", positions_cfg)

	# Should average: accuracy (85) + decision (75) = 160 / 2 = 80
	# Hidden stat excluded
	assert_float(result).is_equal_approx(80.0, 0.1)


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_weighted_ovr_is_deterministic() -> void:
	var player := {
		"stats": {
			"speed": 82.0,
			"strength": 78.0,
			"awareness": 80.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.4,
			"strength": 0.3,
			"awareness": 0.3
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {"speed": 0.5}
			}
		}
	}

	var result1 := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)
	var result2 := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)

	# Should produce identical results
	assert_float(result1).is_equal(result2)


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_zero_weight_stats_excluded_from_calculation() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 100.0  # High value but zero weight
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.6,
			"strength": 0.4,
			"awareness": 0.0  # Zero weight
		},
		"position_weights": {
			"RB": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "RB", ovr_config)

	# Only speed and strength should contribute: (80 * 0.6) + (70 * 0.4) = 48 + 28 = 76
	assert_float(result).is_equal_approx(76.0, 0.1)


func test_empty_stats_dict_returns_neutral_value() -> void:
	var player := {
		"stats": {}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.5,
			"strength": 0.5
		},
		"position_weights": {
			"ATH": {
				"side_of_ball": "offensive",
				"weights": {}
			}
		}
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "ATH", ovr_config)

	# All stats missing, should use neutral value (50)
	assert_float(result).is_equal(50.0)


func test_position_with_no_weights_falls_back_gracefully() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0
		}
	}

	var ovr_config := {
		"base_weights": {
			"speed": 0.5,
			"strength": 0.5
		},
		"position_weights": {}  # No position weights
	}

	var result := PlayerRatingCalculator.calculate_weighted_ovr(player, "UNKNOWN", ovr_config)

	# Should fall back to simple average
	assert_float(result).is_greater(0.0)
