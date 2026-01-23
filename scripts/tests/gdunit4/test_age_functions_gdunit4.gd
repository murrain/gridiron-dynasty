extends GdUnitTestSuite
class_name TestAgeFunctions

const AgeFunctions = preload("res://scripts/core/transformations/AgeFunctions.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

# ============================================================================
# INCREMENT AGE TESTS
# ============================================================================

func test_increment_age_basic() -> void:
	var player := {"age": 22, "name": "John"}
	var updated := AgeFunctions.increment_age(player)

	# Original should be unchanged (purity)
	assert_int(player["age"]).is_equal(22)

	# Updated should have age + 1
	assert_int(updated["age"]).is_equal(23)


func test_increment_age_preserves_other_fields() -> void:
	var player := {
		"age": 20,
		"name": "Jane",
		"position": "QB",
		"stats": {"speed": 80.0}
	}
	var updated := AgeFunctions.increment_age(player)

	assert_int(updated["age"]).is_equal(21)
	assert_str(updated["name"]).is_equal("Jane")
	assert_str(updated["position"]).is_equal("QB")
	assert_dict(updated["stats"]).contains_key("speed")


func test_increment_age_default_for_missing() -> void:
	var player := {"name": "NoAge"}
	var updated := AgeFunctions.increment_age(player)

	# Default age is 18, so should become 19
	assert_int(updated["age"]).is_equal(19)


func test_increment_age_capped_at_99() -> void:
	var player := {"age": 99}
	var updated := AgeFunctions.increment_age(player)

	# Should stay at 99 (max cap)
	assert_int(updated["age"]).is_equal(99)


func test_increment_age_near_cap() -> void:
	var player := {"age": 98}
	var updated := AgeFunctions.increment_age(player)

	assert_int(updated["age"]).is_equal(99)


# ============================================================================
# GET AGE MODIFIER TESTS
# ============================================================================

func test_get_age_modifier_growth_phase() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Age 22, peak at 28, should be in growth phase
	var modifier := AgeFunctions.get_age_modifier(22, "QB", configs)

	# Growth phase: should be > 1.0 (growth bonus)
	assert_float(modifier).is_greater(1.0)


func test_get_age_modifier_prime_phase() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Age 30 (between 28 and 33) should be in prime phase
	var modifier := AgeFunctions.get_age_modifier(30, "QB", configs)

	# Prime phase: should be exactly 1.0
	assert_float(modifier).is_equal(1.0)


func test_get_age_modifier_decline_phase() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Age 35 (past 33) should be in decline phase
	var modifier := AgeFunctions.get_age_modifier(35, "QB", configs)

	# Decline phase: should be < 1.0 (decline penalty)
	assert_float(modifier).is_less(1.0)


func test_get_age_modifier_at_peak() -> void:
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"peak_age": 26,
					"decline_start": 30
				}
			}
		}
	}

	# At exact peak age
	var modifier := AgeFunctions.get_age_modifier(26, "RB", configs)

	# Should be 1.0 (no bonus or penalty)
	assert_float(modifier).is_equal(1.0)


func test_get_age_modifier_at_decline_start() -> void:
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"peak_age": 26,
					"decline_start": 30
				}
			}
		}
	}

	# At exact decline start age
	var modifier := AgeFunctions.get_age_modifier(30, "RB", configs)

	# Should be 1.0 (just entering decline, no penalty yet)
	assert_float(modifier).is_equal(1.0)


func test_get_age_modifier_clamped_min() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Very old age should be clamped at 0.4 minimum
	var modifier := AgeFunctions.get_age_modifier(45, "QB", configs)

	assert_float(modifier).is_greater_equal(0.4)


func test_get_age_modifier_clamped_max() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Very young age should be clamped at 1.4 maximum
	var modifier := AgeFunctions.get_age_modifier(18, "QB", configs)

	assert_float(modifier).is_less_equal(1.4)


func test_get_age_modifier_missing_config_uses_defaults() -> void:
	var configs := {"positions": {}}

	# Should use default peak_age=26, decline_start=30
	var modifier := AgeFunctions.get_age_modifier(28, "QB", configs)

	# Should work without crashing
	assert_float(modifier).is_not_null()


# ============================================================================
# YEARS TO PEAK TESTS
# ============================================================================

func test_years_to_peak_before_peak() -> void:
	var configs := {
		"positions": {
			"WR": {
				"development": {
					"peak_age": 27
				}
			}
		}
	}

	var years := AgeFunctions.years_to_peak(22, "WR", configs)

	assert_int(years).is_equal(5)


func test_years_to_peak_at_peak() -> void:
	var configs := {
		"positions": {
			"WR": {
				"development": {
					"peak_age": 27
				}
			}
		}
	}

	var years := AgeFunctions.years_to_peak(27, "WR", configs)

	assert_int(years).is_equal(0)


func test_years_to_peak_past_peak() -> void:
	var configs := {
		"positions": {
			"WR": {
				"development": {
					"peak_age": 27
				}
			}
		}
	}

	var years := AgeFunctions.years_to_peak(30, "WR", configs)

	# Should be negative (past peak)
	assert_int(years).is_equal(-3)


func test_years_to_peak_missing_config() -> void:
	var configs := {"positions": {}}

	# Should use default peak_age=26
	var years := AgeFunctions.years_to_peak(22, "QB", configs)

	assert_int(years).is_equal(4)


# ============================================================================
# YEARS UNTIL DECLINE TESTS
# ============================================================================

func test_years_until_decline_before_decline() -> void:
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"decline_start": 30
				}
			}
		}
	}

	var years := AgeFunctions.years_until_decline(28, "RB", configs)

	assert_int(years).is_equal(2)


func test_years_until_decline_at_decline() -> void:
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"decline_start": 30
				}
			}
		}
	}

	var years := AgeFunctions.years_until_decline(30, "RB", configs)

	assert_int(years).is_equal(0)


func test_years_until_decline_past_decline() -> void:
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"decline_start": 30
				}
			}
		}
	}

	var years := AgeFunctions.years_until_decline(33, "RB", configs)

	# Should be clamped at 0 (can't be negative)
	assert_int(years).is_equal(0)


func test_years_until_decline_missing_config() -> void:
	var configs := {"positions": {}}

	# Should use default decline_start=30
	var years := AgeFunctions.years_until_decline(28, "QB", configs)

	assert_int(years).is_equal(2)


# ============================================================================
# GET LIFECYCLE PHASE TESTS
# ============================================================================

func test_get_lifecycle_phase_growth() -> void:
	var configs := {
		"positions": {
			"LB": {
				"development": {
					"peak_age": 26,
					"decline_start": 30
				}
			}
		}
	}

	var phase := AgeFunctions.get_lifecycle_phase(24, "LB", configs)

	assert_str(phase).is_equal("growth")


func test_get_lifecycle_phase_prime() -> void:
	var configs := {
		"positions": {
			"LB": {
				"development": {
					"peak_age": 26,
					"decline_start": 30
				}
			}
		}
	}

	var phase := AgeFunctions.get_lifecycle_phase(28, "LB", configs)

	assert_str(phase).is_equal("prime")


func test_get_lifecycle_phase_decline() -> void:
	var configs := {
		"positions": {
			"LB": {
				"development": {
					"peak_age": 26,
					"decline_start": 30
				}
			}
		}
	}

	var phase := AgeFunctions.get_lifecycle_phase(32, "LB", configs)

	assert_str(phase).is_equal("decline")


func test_get_lifecycle_phase_at_peak() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Exactly at peak should be prime (age >= peak_age)
	var phase := AgeFunctions.get_lifecycle_phase(28, "QB", configs)

	assert_str(phase).is_equal("prime")


func test_get_lifecycle_phase_at_decline_start() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Exactly at decline start should be decline (age >= decline_start)
	var phase := AgeFunctions.get_lifecycle_phase(33, "QB", configs)

	assert_str(phase).is_equal("decline")


func test_get_lifecycle_phase_missing_config() -> void:
	var configs := {"positions": {}}

	# Should use defaults: peak_age=26, decline_start=30
	var phase := AgeFunctions.get_lifecycle_phase(24, "QB", configs)

	assert_str(phase).is_equal("growth")


# ============================================================================
# POSITION-SPECIFIC TESTS
# ============================================================================

func test_different_positions_have_different_curves() -> void:
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"peak_age": 25,
					"decline_start": 29
				}
			},
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Same age, different positions
	var rb_phase := AgeFunctions.get_lifecycle_phase(27, "RB", configs)
	var qb_phase := AgeFunctions.get_lifecycle_phase(27, "QB", configs)

	# RB at 27 should be in prime (past 25 peak, before 29 decline)
	assert_str(rb_phase).is_equal("prime")

	# QB at 27 should be in growth (before 28 peak)
	assert_str(qb_phase).is_equal("growth")


# ============================================================================
# PURITY TESTS
# ============================================================================

func test_increment_age_is_pure() -> void:
	var original := {
		"age": 25,
		"name": "Test",
		"stats": {"speed": 80.0}
	}
	var original_copy := original.duplicate(true)

	var _updated := AgeFunctions.increment_age(original)

	# Original should be completely unchanged
	assert_that(original).is_equal(original_copy)


func test_functions_do_not_modify_configs() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}
	var configs_copy := configs.duplicate(true)

	# Call all functions
	var _modifier := AgeFunctions.get_age_modifier(25, "QB", configs)
	var _years := AgeFunctions.years_to_peak(25, "QB", configs)
	var _decline_years := AgeFunctions.years_until_decline(25, "QB", configs)
	var _phase := AgeFunctions.get_lifecycle_phase(25, "QB", configs)

	# Configs should be unchanged
	assert_that(configs).is_equal(configs_copy)


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_increment_age_with_empty_dict() -> void:
	var player := {}
	var updated := AgeFunctions.increment_age(player)

	# Should default to 18, then increment to 19
	assert_int(updated["age"]).is_equal(19)


func test_get_age_modifier_with_empty_configs() -> void:
	var configs := {}
	var modifier := AgeFunctions.get_age_modifier(25, "QB", configs)

	# Should use defaults and not crash
	assert_float(modifier).is_not_null()
	assert_float(modifier).is_greater(0.0)


func test_age_modifier_consistent_across_multiple_calls() -> void:
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	# Call multiple times with same inputs
	var modifier1 := AgeFunctions.get_age_modifier(25, "QB", configs)
	var modifier2 := AgeFunctions.get_age_modifier(25, "QB", configs)
	var modifier3 := AgeFunctions.get_age_modifier(25, "QB", configs)

	# Should be identical (deterministic)
	assert_float(modifier1).is_equal(modifier2)
	assert_float(modifier2).is_equal(modifier3)
