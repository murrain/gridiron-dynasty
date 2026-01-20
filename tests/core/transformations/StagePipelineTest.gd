class_name StagePipelineTest
extends GdUnitTestSuite

## GdUnit4 test suite for StagePipeline.gd
## Tests pure functional pipeline for player lifecycle transformations.
##
## Test Categories:
## 1. Immutability - Verify input dictionaries are NOT modified
## 2. Determinism - Same seed produces identical results
## 3. Functionality - Verify correct behavior
## 4. Edge Cases - Null inputs, empty data, boundary values

const StagePipeline = preload("res://scripts/core/transformations/StagePipeline.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# SETUP & TEARDOWN
# ============================================================================

func before_test() -> void:
	# Called before each test
	pass

func after_test() -> void:
	# Called after each test
	pass

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player(age: int = 22) -> Dictionary:
	"""Create a minimal player dictionary for testing."""
	return {
		"id": "test_player_123",
		"age": age,
		"position": "QB",
		"stage": Player.PlayerStage.COLLEGE,
		"stats": {
			"speed": 70.0,
			"strength": 75.0,
			"awareness": 65.0,
			"throwing_power": 80.0,
			"throwing_accuracy": 78.0
		},
		"potential": {
			"speed": 85.0,
			"strength": 90.0,
			"awareness": 82.0,
			"throwing_power": 95.0,
			"throwing_accuracy": 92.0
		},
		"injuries": [],
		"hidden_traits": [],
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		}
	}

func _create_test_context() -> Dictionary:
	"""Create a minimal development context for testing."""
	return {
		"program_quality": 1.0,
		"coach_specialization": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"rehab_quality": 1.0
	}

func _create_test_configs() -> Dictionary:
	"""Create minimal test configs."""
	return {
		"main": {
			"development": {
				"curve_multipliers": {
					"mid": {
						"growth": 1.0,
						"prime": 0.35,
						"decline": 1.0
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
			"injury": {
				"base_chance": 0.12,
				"proneness_slope": 0.15,
				"position_multipliers": {
					"QB": 0.8,
					"RB": 1.5
				},
				"durability_trait_modifiers": {},
				"types": []
			},
			"retirement": {
				"min_age": 27,
				"soft_cap_age": 33,
				"max_age": 40,
				"base_chance": 0.02,
				"age_chance_per_year": 0.04,
				"low_rating_threshold": 55.0,
				"low_rating_boost": 0.08
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
					"decline_start": 34,
					"curve": "mid"
				},
				"core_stats": ["throwing_power", "throwing_accuracy", "awareness"]
			}
		},
		"stats": {
			"stats": [
				{"name": "speed", "type": "base"},
				{"name": "strength", "type": "base"},
				{"name": "awareness", "type": "base"},
				{"name": "throwing_power", "type": "base"},
				{"name": "throwing_accuracy", "type": "base"}
			]
		}
	}

# ============================================================================
# IMMUTABILITY TESTS - Verify inputs are not mutated
# ============================================================================

func test_advance_one_year_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Call the pure function
	StagePipeline.advance_one_year(player, context, configs, rng)

	# Verify original player is unchanged
	assert_dict(player).is_equal(player_copy)

func test_advance_one_year_does_not_mutate_context() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var context_copy := context.duplicate(true)
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Call the pure function
	StagePipeline.advance_one_year(player, context, configs, rng)

	# Verify context is unchanged
	assert_dict(context).is_equal(context_copy)

func test_transition_stage_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	# Call the pure function
	StagePipeline.transition_stage(player, Player.PlayerStage.DRAFT_ELIGIBLE)

	# Verify original player is unchanged
	assert_dict(player).is_equal(player_copy)

# ============================================================================
# DETERMINISM TESTS - Same seed produces identical results
# ============================================================================

func test_advance_one_year_is_deterministic() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()

	# First run with seed 12345
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := StagePipeline.advance_one_year(player, context, configs, rng1)

	# Second run with same seed
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := StagePipeline.advance_one_year(player, context, configs, rng2)

	# Verify results are identical
	assert_dict(result1.player).is_equal(result2.player)
	assert_bool(result1.retired).is_equal(result2.retired)

func test_advance_one_year_different_seeds_produce_different_results() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()

	# Run with different seeds
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := StagePipeline.advance_one_year(player, context, configs, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321
	var result2 := StagePipeline.advance_one_year(player, context, configs, rng2)

	# Results should differ (very high probability given RNG calls)
	# Check if at least one stat changed differently
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
# FUNCTIONALITY TESTS - Verify correct behavior
# ============================================================================

func test_advance_one_year_increments_age() -> void:
	var player := _create_test_player(22)
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Age should be incremented by 1
	assert_int(result.player["age"]).is_equal(23)

func test_advance_one_year_returns_valid_structure() -> void:
	var player := _create_test_player()
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Verify result structure
	assert_dict(result).contains_keys(["player", "retired", "report"])
	assert_dict(result.player).is_not_null()
	assert_bool(result.has("retired")).is_true()
	assert_dict(result.report).contains_keys(["development", "injury", "age", "phase"])

func test_advance_one_year_young_player_develops() -> void:
	var player := _create_test_player(22)  # Growth phase
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# At least some stats should increase (growth phase)
	var some_stat_increased := false
	for stat_name in player["stats"].keys():
		if result.player["stats"][stat_name] > player["stats"][stat_name]:
			some_stat_increased = true
			break

	assert_bool(some_stat_increased).is_true()

func test_advance_one_year_old_player_unlikely_to_retire() -> void:
	var player := _create_test_player(25)  # Below retirement min_age (27)
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Player below min_age should not retire
	assert_bool(result.retired).is_false()

func test_transition_stage_updates_stage_field() -> void:
	var player := _create_test_player()
	player["stage"] = Player.PlayerStage.COLLEGE

	var result := StagePipeline.transition_stage(player, Player.PlayerStage.DRAFT_ELIGIBLE)

	# Original unchanged
	assert_int(player["stage"]).is_equal(Player.PlayerStage.COLLEGE)
	# New player has updated stage
	assert_int(result["stage"]).is_equal(Player.PlayerStage.DRAFT_ELIGIBLE)

func test_compose_chains_functions() -> void:
	var player := _create_test_player(22)

	var add_one_age := func(p: Dictionary) -> Dictionary:
		var new_p := p.duplicate(true)
		new_p["age"] = int(new_p["age"]) + 1
		return new_p

	var add_ten_speed := func(p: Dictionary) -> Dictionary:
		var new_p := p.duplicate(true)
		new_p["stats"]["speed"] = float(new_p["stats"]["speed"]) + 10.0
		return new_p

	var pipeline := StagePipeline.compose([add_one_age, add_ten_speed])
	var result: Dictionary = pipeline.call(player)

	# Age should be incremented
	assert_int(result["age"]).is_equal(23)
	# Speed should be increased
	assert_float(result["stats"]["speed"]).is_equal(80.0)

# ============================================================================
# EDGE CASE TESTS - Boundary values and error handling
# ============================================================================

func test_advance_one_year_with_empty_stats() -> void:
	var player := _create_test_player()
	player["stats"] = {}
	player["potential"] = {}
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should not crash
	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Should still increment age
	assert_int(result.player["age"]).is_equal(23)

func test_advance_one_year_with_missing_stats() -> void:
	var player := _create_test_player()
	player.erase("stats")
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Should not crash
	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Should still return valid structure
	assert_dict(result).contains_keys(["player", "retired", "report"])

func test_advance_one_year_at_max_age() -> void:
	var player := _create_test_player(39)
	var context := _create_test_context()
	var configs := _create_test_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Age should increment but be capped at 99
	assert_int(result.player["age"]).is_equal(40)
	# Player should likely retire at 40 (max_age in config)
	assert_bool(result.retired).is_true()

func test_transition_stage_with_any_stage_value() -> void:
	var player := _create_test_player()

	# Test all valid stage transitions
	for stage in [
		Player.PlayerStage.HIGH_SCHOOL,
		Player.PlayerStage.COLLEGE,
		Player.PlayerStage.DRAFT_ELIGIBLE,
		Player.PlayerStage.NFL_ROOKIE,
		Player.PlayerStage.NFL_VETERAN,
		Player.PlayerStage.NFL_FREE_AGENT,
		Player.PlayerStage.RETIRED
	]:
		var result := StagePipeline.transition_stage(player, stage)
		assert_int(result["stage"]).is_equal(stage)

func test_compose_with_empty_array() -> void:
	var player := _create_test_player()
	var pipeline := StagePipeline.compose([])

	# Should return input unchanged
	var result: Dictionary = pipeline.call(player)
	assert_dict(result).is_equal(player)

func test_compose_with_single_function() -> void:
	var player := _create_test_player(22)

	var add_one := func(p: Dictionary) -> Dictionary:
		var new_p := p.duplicate(true)
		new_p["age"] = int(new_p["age"]) + 1
		return new_p

	var pipeline := StagePipeline.compose([add_one])
	var result: Dictionary = pipeline.call(player)

	assert_int(result["age"]).is_equal(23)
