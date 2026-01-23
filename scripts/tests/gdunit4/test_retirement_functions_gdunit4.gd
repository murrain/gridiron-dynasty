extends GdUnitTestSuite
class_name TestRetirementFunctions

const RetirementFunctions = preload("res://scripts/core/transformations/RetirementFunctions.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

# ============================================================================
# SETUP
# ============================================================================

func create_test_configs() -> Dictionary:
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
				"core_stats": ["accuracy", "decision", "awareness"]
			},
			"RB": {
				"core_stats": ["speed", "strength", "stamina"]
			}
		}
	}


func create_test_player(age: int = 30, position: String = "QB") -> Dictionary:
	return {
		"age": age,
		"position": position,
		"stats": {
			"accuracy": 75.0,
			"decision": 70.0,
			"awareness": 80.0,
			"speed": 70.0,
			"strength": 75.0,
			"stamina": 80.0
		},
		"injuries": []
	}


# ============================================================================
# SHOULD RETIRE TESTS
# ============================================================================

func test_should_retire_below_min_age() -> void:
	var player := create_test_player(25)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Below min_age should never retire
	assert_bool(should_retire).is_false()


func test_should_retire_at_max_age() -> void:
	var player := create_test_player(40)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# At max_age should always retire
	assert_bool(should_retire).is_true()


func test_should_retire_above_max_age() -> void:
	var player := create_test_player(42)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Above max_age should always retire
	assert_bool(should_retire).is_true()


func test_should_retire_career_ending_injury() -> void:
	var player := create_test_player(30)
	player["injuries"] = [
		{"type": "knee", "career_ending": true}
	]
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Career-ending injury should force retirement
	assert_bool(should_retire).is_true()


func test_should_retire_is_deterministic() -> void:
	var retirement_check := func(rng_instance: RandomNumberGenerator) -> bool:
		var player := create_test_player(35)
		var configs := create_test_configs()
		return RetirementFunctions.should_retire(player, configs, rng_instance)

	TestHelpersGdUnit4.assert_deterministic(
		self,
		retirement_check,
		999,
		"retirement decision is deterministic with same seed"
	)


func test_should_retire_probabilistic_in_range() -> void:
	var player := create_test_player(35)
	var configs := create_test_configs()

	var retire_count := 0
	var trials := 100

	for i in range(trials):
		var rng := TestHelpersGdUnit4.create_seeded_rng(12345 + i)
		if RetirementFunctions.should_retire(player, configs, rng):
			retire_count += 1

	# Should retire some but not all (probabilistic)
	assert_int(retire_count).is_greater(0)
	assert_int(retire_count).is_less(trials)


# ============================================================================
# CALCULATE RETIREMENT PROBABILITY TESTS
# ============================================================================

func test_calculate_retirement_probability_below_min_age() -> void:
	var player := create_test_player(25)
	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_float(prob).is_equal(0.0)


func test_calculate_retirement_probability_at_max_age() -> void:
	var player := create_test_player(40)
	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	assert_float(prob).is_equal(1.0)


func test_calculate_retirement_probability_at_soft_cap() -> void:
	var player := create_test_player(33)
	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# At soft cap, should be base_chance only
	assert_float(prob).is_equal(0.02)


func test_calculate_retirement_probability_above_soft_cap() -> void:
	var player := create_test_player(35)  # 2 years past soft cap
	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be base_chance + (2 * age_chance_per_year)
	# 0.02 + (2 * 0.04) = 0.10
	assert_float(prob).is_equal(0.10)


func test_calculate_retirement_probability_low_rating_boost() -> void:
	var player := create_test_player(33, "QB")
	# Set stats low to make core rating < 55
	player["stats"]["accuracy"] = 40.0
	player["stats"]["decision"] = 40.0
	player["stats"]["awareness"] = 40.0

	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be base_chance + low_rating_boost
	# 0.02 + 0.08 = 0.10
	assert_float(prob).is_equal(0.10)


func test_calculate_retirement_probability_combined_factors() -> void:
	var player := create_test_player(35, "QB")  # 2 years past soft cap
	# Set stats low
	player["stats"]["accuracy"] = 40.0
	player["stats"]["decision"] = 40.0
	player["stats"]["awareness"] = 40.0

	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be base_chance + age_slope + low_rating_boost
	# 0.02 + (2 * 0.04) + 0.08 = 0.18
	assert_float(prob).is_equal(0.18)


func test_calculate_retirement_probability_capped_at_95_percent() -> void:
	var player := create_test_player(39, "QB")  # Very old
	# Set stats low
	player["stats"]["accuracy"] = 30.0
	player["stats"]["decision"] = 30.0
	player["stats"]["awareness"] = 30.0

	var configs := create_test_configs()

	var prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be capped at 0.95
	assert_float(prob).is_less_equal(0.95)


func test_calculate_retirement_probability_is_pure() -> void:
	var player := create_test_player(35)
	var player_copy := player.duplicate(true)
	var configs := create_test_configs()

	var _prob := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Player should be unchanged
	assert_that(player).is_equal(player_copy)


func test_calculate_retirement_probability_consistent() -> void:
	var player := create_test_player(35)
	var configs := create_test_configs()

	# Call multiple times
	var prob1 := RetirementFunctions.calculate_retirement_probability(player, configs)
	var prob2 := RetirementFunctions.calculate_retirement_probability(player, configs)
	var prob3 := RetirementFunctions.calculate_retirement_probability(player, configs)

	# Should be identical (deterministic calculation)
	assert_float(prob1).is_equal(prob2)
	assert_float(prob2).is_equal(prob3)


# ============================================================================
# APPLY RETIREMENT TESTS
# ============================================================================

func test_apply_retirement_sets_stage() -> void:
	var player := create_test_player(35)
	var retired := RetirementFunctions.apply_retirement(player)

	# Should set stage to RETIRED (6)
	assert_int(retired["stage"]).is_equal(6)


func test_apply_retirement_is_pure() -> void:
	var player := create_test_player(35)
	var player_copy := player.duplicate(true)

	var _retired := RetirementFunctions.apply_retirement(player)

	# Original player should be unchanged
	assert_that(player).is_equal(player_copy)


func test_apply_retirement_preserves_other_fields() -> void:
	var player := create_test_player(35)
	player["name"] = "Test Player"
	player["position"] = "QB"

	var retired := RetirementFunctions.apply_retirement(player)

	assert_str(retired["name"]).is_equal("Test Player")
	assert_str(retired["position"]).is_equal("QB")
	assert_int(retired["age"]).is_equal(35)


# ============================================================================
# CORE RATING TESTS
# ============================================================================

func test_core_rating_uses_core_stats() -> void:
	var player := create_test_player(30, "QB")
	player["stats"]["accuracy"] = 80.0
	player["stats"]["decision"] = 70.0
	player["stats"]["awareness"] = 60.0
	player["stats"]["speed"] = 50.0  # Not a core stat for QB

	var configs := create_test_configs()
	var positions_cfg: Dictionary = configs["positions"]

	var rating := RetirementFunctions._core_rating(player, positions_cfg)

	# Should average accuracy, decision, awareness (80 + 70 + 60) / 3 = 70
	assert_float(rating).is_equal(70.0)


func test_core_rating_ignores_non_core_stats() -> void:
	var player := create_test_player(30, "RB")
	player["stats"]["speed"] = 80.0
	player["stats"]["strength"] = 70.0
	player["stats"]["stamina"] = 60.0
	player["stats"]["accuracy"] = 100.0  # Not a core stat for RB

	var configs := create_test_configs()
	var positions_cfg: Dictionary = configs["positions"]

	var rating := RetirementFunctions._core_rating(player, positions_cfg)

	# Should average speed, strength, stamina (80 + 70 + 60) / 3 = 70
	# Should NOT include accuracy
	assert_float(rating).is_equal(70.0)


func test_core_rating_fallback_to_all_stats() -> void:
	var player := create_test_player(30, "TE")  # TE not in configs
	player["stats"]["speed"] = 80.0
	player["stats"]["strength"] = 60.0

	var configs := create_test_configs()
	var positions_cfg: Dictionary = configs["positions"]

	var rating := RetirementFunctions._core_rating(player, positions_cfg)

	# Should average all stats (80 + 60) / 2 = 70
	assert_float(rating).is_equal(70.0)


func test_core_rating_empty_stats() -> void:
	var player := create_test_player(30, "QB")
	player["stats"] = {}

	var configs := create_test_configs()
	var positions_cfg: Dictionary = configs["positions"]

	var rating := RetirementFunctions._core_rating(player, positions_cfg)

	# Should return 0.0 for empty stats
	assert_float(rating).is_equal(0.0)


# ============================================================================
# MEAN OF STATS TESTS
# ============================================================================

func test_mean_of_stats_basic() -> void:
	var stats := {
		"speed": 80.0,
		"strength": 60.0,
		"stamina": 70.0
	}

	var mean := RetirementFunctions._mean_of_stats(stats)

	# (80 + 60 + 70) / 3 = 70
	assert_float(mean).is_equal(70.0)


func test_mean_of_stats_single_stat() -> void:
	var stats := {
		"speed": 85.0
	}

	var mean := RetirementFunctions._mean_of_stats(stats)

	assert_float(mean).is_equal(85.0)


func test_mean_of_stats_empty() -> void:
	var stats := {}

	var mean := RetirementFunctions._mean_of_stats(stats)

	assert_float(mean).is_equal(0.0)


func test_mean_of_stats_filters_non_numeric() -> void:
	var stats := {
		"speed": 80.0,
		"strength": 60.0,
		"name": "test",  # String, should be ignored
		"active": true   # Bool, should be ignored
	}

	var mean := RetirementFunctions._mean_of_stats(stats)

	# Should only average speed and strength (80 + 60) / 2 = 70
	assert_float(mean).is_equal(70.0)


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_multiple_career_ending_injuries() -> void:
	var player := create_test_player(30)
	player["injuries"] = [
		{"type": "knee", "career_ending": true},
		{"type": "shoulder", "career_ending": true}
	]
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Should still force retirement
	assert_bool(should_retire).is_true()


func test_non_career_ending_injury_not_force_retire() -> void:
	var player := create_test_player(25)  # Below min age
	player["injuries"] = [
		{"type": "ankle", "career_ending": false}
	]
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Should not force retirement
	assert_bool(should_retire).is_false()


func test_missing_configs_use_defaults() -> void:
	var player := create_test_player(35)
	var configs := {}  # Empty configs
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	# Should not crash
	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Should return a valid boolean
	assert_bool(should_retire).is_not_null()


func test_zero_age_player() -> void:
	var player := create_test_player(0)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Should not retire (below min age)
	assert_bool(should_retire).is_false()


func test_negative_age_player() -> void:
	var player := create_test_player(-5)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Should not retire (below min age)
	assert_bool(should_retire).is_false()


# ============================================================================
# PURITY TESTS
# ============================================================================

func test_should_retire_does_not_modify_player() -> void:
	var player := create_test_player(35)
	var player_copy := player.duplicate(true)
	var configs := create_test_configs()
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var _should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Player should be unchanged
	assert_that(player).is_equal(player_copy)


func test_should_retire_does_not_modify_configs() -> void:
	var player := create_test_player(35)
	var configs := create_test_configs()
	var configs_copy := configs.duplicate(true)
	var rng := TestHelpersGdUnit4.create_seeded_rng(12345)

	var _should_retire := RetirementFunctions.should_retire(player, configs, rng)

	# Configs should be unchanged
	assert_that(configs).is_equal(configs_copy)


# ============================================================================
# RNG CONSUMPTION TESTS
# ============================================================================

func test_rng_not_consumed_for_career_ending_injury() -> void:
	var player := create_test_player(30)
	player["injuries"] = [{"type": "knee", "career_ending": true}]
	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)

	# First call with career-ending injury
	var _result1 := RetirementFunctions.should_retire(player, configs, rng1)

	# Get RNG state after
	var next1 := rng1.randf()

	# Second RNG should have same next value (no consumption happened)
	var next2 := rng2.randf()

	assert_float(next1).is_equal(next2)


func test_rng_not_consumed_below_min_age() -> void:
	var player := create_test_player(25)  # Below min age
	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)

	# First call below min age
	var _result1 := RetirementFunctions.should_retire(player, configs, rng1)

	# Get RNG state after
	var next1 := rng1.randf()

	# Second RNG should have same next value (no consumption happened)
	var next2 := rng2.randf()

	assert_float(next1).is_equal(next2)


func test_rng_not_consumed_at_max_age() -> void:
	var player := create_test_player(40)  # At max age
	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)

	# First call at max age
	var _result1 := RetirementFunctions.should_retire(player, configs, rng1)

	# Get RNG state after
	var next1 := rng1.randf()

	# Second RNG should have same next value (no consumption happened)
	var next2 := rng2.randf()

	assert_float(next1).is_equal(next2)


func test_rng_consumed_once_in_probabilistic_range() -> void:
	var player := create_test_player(35)  # In probabilistic range
	var configs := create_test_configs()

	var rng1 := TestHelpersGdUnit4.create_seeded_rng(12345)
	var rng2 := TestHelpersGdUnit4.create_seeded_rng(12345)

	# First call in probabilistic range
	var _result1 := RetirementFunctions.should_retire(player, configs, rng1)

	# Get RNG state after
	var next1 := rng1.randf()

	# Skip one call on second RNG to match consumption
	var _consumed := rng2.randf()
	var next2 := rng2.randf()

	# Should match (one call was consumed)
	assert_float(next1).is_equal(next2)
