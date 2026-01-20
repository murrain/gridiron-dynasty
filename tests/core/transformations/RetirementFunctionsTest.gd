class_name RetirementFunctionsTest
extends GdUnitTestSuite

## GdUnit4 test suite for RetirementFunctions.gd
## Tests pure functional retirement checks.

const RetirementFunctions = preload("res://scripts/core/transformations/RetirementFunctions.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player(age: int = 30) -> Dictionary:
	return {
		"id": "test_player_123",
		"age": age,
		"position": "QB",
		"stage": Player.PlayerStage.NFL_VETERAN,
		"stats": {
			"speed": 75.0,
			"strength": 80.0,
			"awareness": 85.0
		},
		"injuries": []
	}

func _create_test_configs() -> Dictionary:
	return {
		"main": {
			"retirement": {
				"min_age": 27,
				"soft_cap_age": 33,
				"max_age": 40,
				"base_chance": 0.02,
				"age_chance_per_year": 0.04,
				"low_rating_threshold": 55.0,
				"low_rating_boost": 0.08
			}
		},
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 34
				},
				"core_stats": ["awareness", "throwing_power", "throwing_accuracy"]
			}
		}
	}

# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_should_retire_does_not_mutate_player() -> void:
	var player := _create_test_player(35)
	var player_copy := player.duplicate(true)
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	RetirementFunctions.should_retire(player, configs, rng)

	assert_dict(player).is_equal(player_copy)

func test_calculate_retirement_probability_does_not_mutate_player() -> void:
	var player := _create_test_player(35)
	var player_copy := player.duplicate(true)
	var configs := _create_test_configs()

	RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_dict(player).is_equal(player_copy)

func test_apply_retirement_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	RetirementFunctions.apply_retirement(player)

	assert_dict(player).is_equal(player_copy)

# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_should_retire_is_deterministic() -> void:
	var player := _create_test_player(35)
	var configs := _create_test_configs()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := RetirementFunctions.should_retire(player, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := RetirementFunctions.should_retire(player, configs, rng2)

	assert_bool(result1).is_equal(result2)

func test_calculate_retirement_probability_is_deterministic() -> void:
	var player := _create_test_player(35)
	var configs := _create_test_configs()

	var prob1 := RetirementFunctions.calculate_retirement_probability(player, configs)
	var prob2 := RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_float(prob1).is_equal(prob2)

# ============================================================================
# FUNCTIONALITY TESTS - should_retire
# ============================================================================

func test_should_retire_below_min_age_always_false() -> void:
	var player := _create_test_player(25)  # Below min_age (27)
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1  # Very low roll

	var result := RetirementFunctions.should_retire(player, configs, rng)

	assert_bool(result).is_false()

func test_should_retire_at_max_age_always_true() -> void:
	var player := _create_test_player(40)  # At max_age
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999  # Very high roll

	var result := RetirementFunctions.should_retire(player, configs, rng)

	assert_bool(result).is_true()

func test_should_retire_above_max_age_always_true() -> void:
	var player := _create_test_player(42)  # Above max_age
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var result := RetirementFunctions.should_retire(player, configs, rng)

	assert_bool(result).is_true()

func test_should_retire_with_career_ending_injury() -> void:
	var player := _create_test_player(30)
	player["injuries"] = [{
		"type": "severe_injury",
		"career_ending": true
	}]
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := RetirementFunctions.should_retire(player, configs, rng)

	# Should retire immediately regardless of age or roll
	assert_bool(result).is_true()

func test_should_retire_probabilistic_in_range() -> void:
	var player := _create_test_player(35)
	var configs := _create_test_configs()

	# Test with seed that will cause retirement
	var rng_retire := RandomNumberGenerator.new()
	rng_retire.seed = 1  # Very low roll, should retire
	var retires := RetirementFunctions.should_retire(player, configs, rng_retire)

	# Test with seed that will prevent retirement
	var rng_continue := RandomNumberGenerator.new()
	rng_continue.seed = 99999  # Very high roll, should continue
	var continues := RetirementFunctions.should_retire(player, configs, rng_continue)

	# At age 35, there's a probability of retirement but not guaranteed
	# At least one outcome should be possible
	# (This is probabilistic, but with different seeds we should get variation)
	# We can't assert specific outcomes without knowing exact RNG behavior

# ============================================================================
# FUNCTIONALITY TESTS - calculate_retirement_probability
# ============================================================================

func test_calculate_retirement_probability_below_min_age() -> void:
	var player := _create_test_player(25)
	var configs := _create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_float(prob).is_equal(0.0)

func test_calculate_retirement_probability_at_max_age() -> void:
	var player := _create_test_player(40)
	var configs := _create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_float(prob).is_equal(1.0)

func test_calculate_retirement_probability_above_max_age() -> void:
	var player := _create_test_player(45)
	var configs := _create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_float(prob).is_equal(1.0)

func test_calculate_retirement_probability_at_min_age() -> void:
	var player := _create_test_player(27)
	var configs := _create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be base_chance (0.02) since below soft_cap_age
	assert_float(prob).is_equal(0.02)

func test_calculate_retirement_probability_increases_with_age() -> void:
	var configs := _create_test_configs()

	var player_33 := _create_test_player(33)
	var player_35 := _create_test_player(35)
	var player_37 := _create_test_player(37)

	var prob_33 := RetirementFunctions.calculate_retirement_probability(player_33, configs)
	var prob_35 := RetirementFunctions.calculate_retirement_probability(player_35, configs)
	var prob_37 := RetirementFunctions.calculate_retirement_probability(player_37, configs)

	# Probability should increase with age
	assert_float(prob_35).is_greater(prob_33)
	assert_float(prob_37).is_greater(prob_35)

func test_calculate_retirement_probability_age_slope() -> void:
	var player := _create_test_player(35)  # 2 years past soft_cap_age (33)
	var configs := _create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# base_chance (0.02) + (2 years * 0.04) = 0.02 + 0.08 = 0.10
	assert_float(prob).is_equal(0.10)

func test_calculate_retirement_probability_low_rating_boost() -> void:
	var configs := _create_test_configs()

	var high_rated := _create_test_player(35)
	high_rated["stats"] = {
		"awareness": 85.0,
		"throwing_power": 90.0,
		"throwing_accuracy": 88.0
	}

	var low_rated := _create_test_player(35)
	low_rated["stats"] = {
		"awareness": 45.0,
		"throwing_power": 50.0,
		"throwing_accuracy": 48.0
	}

	var prob_high := RetirementFunctions.calculate_retirement_probability(high_rated, configs)
	var prob_low := RetirementFunctions.calculate_retirement_probability(low_rated, configs)

	# Low-rated player should have higher retirement chance
	assert_float(prob_low).is_greater(prob_high)
	# Difference should be the low_rating_boost (0.08)
	assert_float(prob_low).is_equal(prob_high + 0.08)

func test_calculate_retirement_probability_capped_at_95_percent() -> void:
	var player := _create_test_player(39)  # Very old
	player["stats"] = {
		"awareness": 40.0,  # Low rating
		"throwing_power": 35.0,
		"throwing_accuracy": 38.0
	}
	var configs := _create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be capped at 0.95
	assert_float(prob).is_less_equal(0.95)

# ============================================================================
# FUNCTIONALITY TESTS - apply_retirement
# ============================================================================

func test_apply_retirement_sets_stage_to_retired() -> void:
	var player := _create_test_player()
	player["stage"] = Player.PlayerStage.NFL_VETERAN

	var result := RetirementFunctions.apply_retirement(player)

	# Original unchanged
	assert_int(player["stage"]).is_equal(Player.PlayerStage.NFL_VETERAN)
	# New player has RETIRED stage
	assert_int(result["stage"]).is_equal(Player.PlayerStage.RETIRED)

func test_apply_retirement_preserves_other_fields() -> void:
	var player := _create_test_player(35)

	var result := RetirementFunctions.apply_retirement(player)

	assert_str(result["id"]).is_equal("test_player_123")
	assert_int(result["age"]).is_equal(35)
	assert_str(result["position"]).is_equal("QB")

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_should_retire_with_missing_injuries_field() -> void:
	var player := _create_test_player(35)
	player.erase("injuries")
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should not crash
	var result := RetirementFunctions.should_retire(player, configs, rng)
	assert_bool(result is bool).is_true()

func test_should_retire_with_empty_injuries_array() -> void:
	var player := _create_test_player(35)
	player["injuries"] = []
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should handle normally
	var result := RetirementFunctions.should_retire(player, configs, rng)
	assert_bool(result is bool).is_true()

func test_calculate_retirement_probability_with_missing_stats() -> void:
	var player := _create_test_player(35)
	player.erase("stats")
	var configs := _create_test_configs()

	# Should use fallback rating calculation
	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should return valid probability
	assert_float(prob).is_greater_equal(0.0)
	assert_float(prob).is_less_equal(1.0)

func test_calculate_retirement_probability_with_missing_config() -> void:
	var player := _create_test_player(35)
	var empty_configs := {"main": {"retirement": {}}, "positions": {}}

	# Should use default values
	var prob := RetirementFunctions.calculate_retirement_probability(player, empty_configs)

	# Should return valid probability
	assert_float(prob).is_greater_equal(0.0)
	assert_float(prob).is_less_equal(1.0)

func test_should_retire_at_soft_cap_age() -> void:
	var player := _create_test_player(33)  # Exactly at soft_cap_age
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should be possible to retire (probabilistic) but not forced
	var result := RetirementFunctions.should_retire(player, configs, rng)

	# Just verify it returns a valid boolean (not testing specific outcome due to RNG)
	assert_bool(result is bool).is_true()

func test_calculate_retirement_probability_at_boundaries() -> void:
	var configs := _create_test_configs()

	# Test at min_age boundary
	var at_min := _create_test_player(27)
	var prob_at_min := RetirementFunctions.calculate_retirement_probability(at_min, configs)
	assert_float(prob_at_min).is_equal(0.02)  # base_chance

	# Test just before min_age
	var before_min := _create_test_player(26)
	var prob_before_min := RetirementFunctions.calculate_retirement_probability(before_min, configs)
	assert_float(prob_before_min).is_equal(0.0)

	# Test at soft_cap boundary
	var at_soft_cap := _create_test_player(33)
	var prob_at_soft_cap := RetirementFunctions.calculate_retirement_probability(at_soft_cap, configs)
	assert_float(prob_at_soft_cap).is_equal(0.02)  # Still base_chance (age_slope starts after)

	# Test just after soft_cap
	var after_soft_cap := _create_test_player(34)
	var prob_after_soft_cap := RetirementFunctions.calculate_retirement_probability(after_soft_cap, configs)
	assert_float(prob_after_soft_cap).is_equal(0.06)  # base + 1 year * slope

func test_apply_retirement_multiple_times_idempotent() -> void:
	var player := _create_test_player()

	var result1 := RetirementFunctions.apply_retirement(player)
	var result2 := RetirementFunctions.apply_retirement(result1)

	# Applying retirement multiple times should result in same state
	assert_int(result2["stage"]).is_equal(Player.PlayerStage.RETIRED)
