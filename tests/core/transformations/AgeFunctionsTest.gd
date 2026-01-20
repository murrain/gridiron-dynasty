class_name AgeFunctionsTest
extends GdUnitTestSuite

## GdUnit4 test suite for AgeFunctions.gd
## Tests pure functional age transformations.

const AgeFunctions = preload("res://scripts/core/transformations/AgeFunctions.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player(age: int = 22) -> Dictionary:
	return {
		"id": "test_player_123",
		"age": age,
		"position": "QB",
		"name": "Test Player"
	}

func _create_test_configs() -> Dictionary:
	return {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 34
				}
			},
			"RB": {
				"development": {
					"peak_age": 25,
					"decline_start": 29
				}
			},
			"WR": {
				"development": {
					"peak_age": 27,
					"decline_start": 31
				}
			}
		}
	}

# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_increment_age_does_not_mutate_input() -> void:
	var player := _create_test_player(22)
	var player_copy := player.duplicate(true)

	AgeFunctions.increment_age(player)

	assert_dict(player).is_equal(player_copy)

# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_increment_age_is_deterministic() -> void:
	var player := _create_test_player(22)

	var result1 := AgeFunctions.increment_age(player)
	var result2 := AgeFunctions.increment_age(player)

	# Same input should produce same output
	assert_int(result1["age"]).is_equal(result2["age"])

func test_get_age_modifier_is_deterministic() -> void:
	var configs := _create_test_configs()

	var mod1 := AgeFunctions.get_age_modifier(24, "QB", configs)
	var mod2 := AgeFunctions.get_age_modifier(24, "QB", configs)

	assert_float(mod1).is_equal(mod2)

# ============================================================================
# FUNCTIONALITY TESTS - increment_age
# ============================================================================

func test_increment_age_adds_one() -> void:
	var player := _create_test_player(22)
	var result := AgeFunctions.increment_age(player)

	assert_int(result["age"]).is_equal(23)

func test_increment_age_from_zero() -> void:
	var player := _create_test_player(0)
	var result := AgeFunctions.increment_age(player)

	assert_int(result["age"]).is_equal(1)

func test_increment_age_preserves_other_fields() -> void:
	var player := _create_test_player(22)
	var result := AgeFunctions.increment_age(player)

	assert_str(result["id"]).is_equal("test_player_123")
	assert_str(result["position"]).is_equal("QB")
	assert_str(result["name"]).is_equal("Test Player")

func test_increment_age_caps_at_99() -> void:
	var player := _create_test_player(99)
	var result := AgeFunctions.increment_age(player)

	# Age should be capped at 99
	assert_int(result["age"]).is_equal(99)

func test_increment_age_near_max() -> void:
	var player := _create_test_player(98)
	var result := AgeFunctions.increment_age(player)

	assert_int(result["age"]).is_equal(99)

# ============================================================================
# FUNCTIONALITY TESTS - get_age_modifier
# ============================================================================

func test_get_age_modifier_growth_phase() -> void:
	var configs := _create_test_configs()

	# QB peak_age is 28, so 24 is in growth phase
	var modifier := AgeFunctions.get_age_modifier(24, "QB", configs)

	# Should be >= 1.0 in growth phase
	assert_float(modifier).is_greater_equal(1.0)

func test_get_age_modifier_prime_phase() -> void:
	var configs := _create_test_configs()

	# QB peak_age is 28, decline_start is 34
	# Age 30 is in prime phase
	var modifier := AgeFunctions.get_age_modifier(30, "QB", configs)

	# Should be exactly 1.0 in prime phase
	assert_float(modifier).is_equal(1.0)

func test_get_age_modifier_decline_phase() -> void:
	var configs := _create_test_configs()

	# QB decline_start is 34, so 35 is in decline phase
	var modifier := AgeFunctions.get_age_modifier(35, "QB", configs)

	# Should be < 1.0 in decline phase
	assert_float(modifier).is_less(1.0)

func test_get_age_modifier_younger_has_higher_bonus() -> void:
	var configs := _create_test_configs()

	var modifier_22 := AgeFunctions.get_age_modifier(22, "QB", configs)
	var modifier_26 := AgeFunctions.get_age_modifier(26, "QB", configs)

	# Younger players should have higher growth modifier
	assert_float(modifier_22).is_greater(modifier_26)

func test_get_age_modifier_older_has_steeper_decline() -> void:
	var configs := _create_test_configs()

	var modifier_35 := AgeFunctions.get_age_modifier(35, "QB", configs)
	var modifier_38 := AgeFunctions.get_age_modifier(38, "QB", configs)

	# Older players should have lower modifier (steeper decline)
	assert_float(modifier_38).is_less(modifier_35)

func test_get_age_modifier_different_positions() -> void:
	var configs := _create_test_configs()

	# RB peaks earlier than QB
	var qb_modifier := AgeFunctions.get_age_modifier(25, "QB", configs)
	var rb_modifier := AgeFunctions.get_age_modifier(25, "RB", configs)

	# At age 25, QB is still growing (peak 28), RB is at peak (peak 25)
	# QB should have growth bonus, RB should be at 1.0
	assert_float(qb_modifier).is_greater(1.0)
	assert_float(rb_modifier).is_equal(1.0)

func test_get_age_modifier_clamped_to_valid_range() -> void:
	var configs := _create_test_configs()

	# Test very young (should cap at ~1.4)
	var very_young := AgeFunctions.get_age_modifier(18, "QB", configs)
	assert_float(very_young).is_less_equal(1.4)

	# Test very old (should cap at 0.4)
	var very_old := AgeFunctions.get_age_modifier(45, "QB", configs)
	assert_float(very_old).is_greater_equal(0.4)

# ============================================================================
# FUNCTIONALITY TESTS - years_to_peak
# ============================================================================

func test_years_to_peak_before_peak() -> void:
	var configs := _create_test_configs()

	# QB peak_age is 28, currently 24
	var years := AgeFunctions.years_to_peak(24, "QB", configs)

	assert_int(years).is_equal(4)

func test_years_to_peak_at_peak() -> void:
	var configs := _create_test_configs()

	var years := AgeFunctions.years_to_peak(28, "QB", configs)

	assert_int(years).is_equal(0)

func test_years_to_peak_after_peak() -> void:
	var configs := _create_test_configs()

	var years := AgeFunctions.years_to_peak(30, "QB", configs)

	# Returns negative value when past peak
	assert_int(years).is_equal(-2)

func test_years_to_peak_different_positions() -> void:
	var configs := _create_test_configs()

	var qb_years := AgeFunctions.years_to_peak(24, "QB", configs)
	var rb_years := AgeFunctions.years_to_peak(24, "RB", configs)

	# QB peaks at 28, RB peaks at 25
	assert_int(qb_years).is_equal(4)
	assert_int(rb_years).is_equal(1)

# ============================================================================
# FUNCTIONALITY TESTS - years_until_decline
# ============================================================================

func test_years_until_decline_before_decline() -> void:
	var configs := _create_test_configs()

	# QB decline_start is 34, currently 30
	var years := AgeFunctions.years_until_decline(30, "QB", configs)

	assert_int(years).is_equal(4)

func test_years_until_decline_at_decline_start() -> void:
	var configs := _create_test_configs()

	var years := AgeFunctions.years_until_decline(34, "QB", configs)

	assert_int(years).is_equal(0)

func test_years_until_decline_after_decline_start() -> void:
	var configs := _create_test_configs()

	var years := AgeFunctions.years_until_decline(36, "QB", configs)

	# Should return 0 (not negative) when already in decline
	assert_int(years).is_equal(0)

func test_years_until_decline_rb_declines_earlier() -> void:
	var configs := _create_test_configs()

	var qb_years := AgeFunctions.years_until_decline(28, "QB", configs)
	var rb_years := AgeFunctions.years_until_decline(28, "RB", configs)

	# QB decline_start is 34, RB is 29
	assert_int(qb_years).is_equal(6)
	assert_int(rb_years).is_equal(1)

# ============================================================================
# FUNCTIONALITY TESTS - get_lifecycle_phase
# ============================================================================

func test_get_lifecycle_phase_growth() -> void:
	var configs := _create_test_configs()

	# QB peak_age is 28, age 24 is growth phase
	var phase := AgeFunctions.get_lifecycle_phase(24, "QB", configs)

	assert_str(phase).is_equal("growth")

func test_get_lifecycle_phase_prime() -> void:
	var configs := _create_test_configs()

	# QB peak_age is 28, decline_start is 34
	# Age 30 is prime phase
	var phase := AgeFunctions.get_lifecycle_phase(30, "QB", configs)

	assert_str(phase).is_equal("prime")

func test_get_lifecycle_phase_decline() -> void:
	var configs := _create_test_configs()

	# QB decline_start is 34, so 35 is decline phase
	var phase := AgeFunctions.get_lifecycle_phase(35, "QB", configs)

	assert_str(phase).is_equal("decline")

func test_get_lifecycle_phase_at_peak_boundary() -> void:
	var configs := _create_test_configs()

	# At exactly peak_age (28), should be prime (not growth)
	var phase := AgeFunctions.get_lifecycle_phase(28, "QB", configs)

	assert_str(phase).is_equal("prime")

func test_get_lifecycle_phase_at_decline_boundary() -> void:
	var configs := _create_test_configs()

	# At exactly decline_start (34), should be decline
	var phase := AgeFunctions.get_lifecycle_phase(34, "QB", configs)

	assert_str(phase).is_equal("decline")

func test_get_lifecycle_phase_different_positions() -> void:
	var configs := _create_test_configs()

	# At age 26, QB is in prime, RB is in decline
	var qb_phase := AgeFunctions.get_lifecycle_phase(26, "QB", configs)
	var rb_phase := AgeFunctions.get_lifecycle_phase(26, "RB", configs)

	assert_str(qb_phase).is_equal("prime")
	assert_str(rb_phase).is_equal("growth")  # RB peaks at 25, so 26 is past peak

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_increment_age_with_missing_age_field() -> void:
	var player := {"id": "test", "position": "QB"}
	var result := AgeFunctions.increment_age(player)

	# Should default to 18 and increment to 19
	assert_int(result["age"]).is_equal(19)

func test_get_age_modifier_with_missing_config() -> void:
	var empty_configs := {"positions": {}}

	# Should use default values (peak_age 26, decline_start 30)
	var modifier := AgeFunctions.get_age_modifier(24, "UNKNOWN_POS", empty_configs)

	# Should still return a valid modifier
	assert_float(modifier).is_greater_equal(0.4)
	assert_float(modifier).is_less_equal(1.4)

func test_years_to_peak_with_very_young_player() -> void:
	var configs := _create_test_configs()

	var years := AgeFunctions.years_to_peak(18, "QB", configs)

	# QB peaks at 28, so 10 years away
	assert_int(years).is_equal(10)

func test_years_until_decline_with_very_old_player() -> void:
	var configs := _create_test_configs()

	var years := AgeFunctions.years_until_decline(45, "QB", configs)

	# Should return 0 (already well past decline)
	assert_int(years).is_equal(0)

func test_get_lifecycle_phase_with_extreme_ages() -> void:
	var configs := _create_test_configs()

	var very_young := AgeFunctions.get_lifecycle_phase(16, "QB", configs)
	var very_old := AgeFunctions.get_lifecycle_phase(50, "QB", configs)

	assert_str(very_young).is_equal("growth")
	assert_str(very_old).is_equal("decline")
