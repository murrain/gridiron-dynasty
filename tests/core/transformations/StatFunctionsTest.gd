class_name StatFunctionsTest
extends GdUnitTestSuite

## GdUnit4 test suite for StatFunctions.gd
## Tests pure functional stat manipulation.

const StatFunctions = preload("res://scripts/core/transformations/StatFunctions.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_player() -> Dictionary:
	return {
		"id": "test_player_123",
		"position": "QB",
		"stats": {
			"speed": 75.0,
			"strength": 80.0,
			"awareness": 70.0,
			"agility": 72.0
		},
		"potential": {
			"speed": 90.0,
			"strength": 95.0,
			"awareness": 85.0,
			"agility": 88.0
		}
	}

# ============================================================================
# IMMUTABILITY TESTS
# ============================================================================

func test_apply_stat_changes_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)
	var changes := {"speed": 85.0, "strength": 88.0}

	StatFunctions.apply_stat_changes(player, changes)

	assert_dict(player).is_equal(player_copy)

func test_cap_stats_at_potential_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	StatFunctions.cap_stats_at_potential(player)

	assert_dict(player).is_equal(player_copy)

func test_apply_stat_decay_does_not_mutate_player() -> void:
	var player := _create_test_player()
	var player_copy := player.duplicate(true)

	StatFunctions.apply_stat_decay(player, 0.95)

	assert_dict(player).is_equal(player_copy)

# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_apply_stat_changes_is_deterministic() -> void:
	var player := _create_test_player()
	var changes := {"speed": 85.0}

	var result1 := StatFunctions.apply_stat_changes(player, changes)
	var result2 := StatFunctions.apply_stat_changes(player, changes)

	assert_dict(result1["stats"]).is_equal(result2["stats"])

func test_calculate_composite_score_is_deterministic() -> void:
	var player := _create_test_player()
	var weights := {"speed": 0.4, "strength": 0.3, "agility": 0.3}

	var score1 := StatFunctions.calculate_composite_score(player, weights)
	var score2 := StatFunctions.calculate_composite_score(player, weights)

	assert_float(score1).is_equal(score2)

# ============================================================================
# FUNCTIONALITY TESTS - apply_stat_changes
# ============================================================================

func test_apply_stat_changes_updates_stats() -> void:
	var player := _create_test_player()
	var changes := {"speed": 85.0, "strength": 90.0}

	var result := StatFunctions.apply_stat_changes(player, changes)

	assert_float(result["stats"]["speed"]).is_equal(85.0)
	assert_float(result["stats"]["strength"]).is_equal(90.0)
	# Unchanged stats remain
	assert_float(result["stats"]["awareness"]).is_equal(70.0)

func test_apply_stat_changes_clamps_to_valid_range() -> void:
	var player := _create_test_player()
	var changes := {"speed": 120.0, "strength": -10.0}

	var result := StatFunctions.apply_stat_changes(player, changes)

	assert_float(result["stats"]["speed"]).is_equal(100.0)  # Capped at 100
	assert_float(result["stats"]["strength"]).is_equal(0.0)  # Clamped to 0

func test_apply_stat_changes_handles_new_stats() -> void:
	var player := _create_test_player()
	var changes := {"new_stat": 50.0}

	var result := StatFunctions.apply_stat_changes(player, changes)

	# New stat should be added
	assert_float(result["stats"]["new_stat"]).is_equal(50.0)

# ============================================================================
# FUNCTIONALITY TESTS - cap_stats_at_potential
# ============================================================================

func test_cap_stats_at_potential_caps_exceeded_stats() -> void:
	var player := _create_test_player()
	# Set a stat above its potential
	player["stats"]["speed"] = 95.0  # Potential is 90.0

	var result := StatFunctions.cap_stats_at_potential(player)

	assert_float(result["stats"]["speed"]).is_equal(90.0)  # Capped at potential

func test_cap_stats_at_potential_preserves_valid_stats() -> void:
	var player := _create_test_player()

	var result := StatFunctions.cap_stats_at_potential(player)

	# All stats should remain unchanged (none exceed potential)
	assert_float(result["stats"]["speed"]).is_equal(75.0)
	assert_float(result["stats"]["strength"]).is_equal(80.0)

func test_cap_stats_at_potential_handles_missing_potential() -> void:
	var player := _create_test_player()
	player.erase("potential")

	var result := StatFunctions.cap_stats_at_potential(player)

	# Should use current stats as ceiling (no change)
	assert_float(result["stats"]["speed"]).is_equal(75.0)

# ============================================================================
# FUNCTIONALITY TESTS - calculate_composite_score
# ============================================================================

func test_calculate_composite_score_weighted_average() -> void:
	var player := _create_test_player()
	# speed=75, strength=80, agility=72
	var weights := {"speed": 0.5, "strength": 0.3, "agility": 0.2}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# Expected: (75*0.5 + 80*0.3 + 72*0.2) / 1.0 = 37.5 + 24 + 14.4 = 75.9
	assert_float(score).is_equal_approx(75.9, 0.01)

func test_calculate_composite_score_equal_weights() -> void:
	var player := _create_test_player()
	var weights := {"speed": 1.0, "strength": 1.0, "awareness": 1.0}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# Should be arithmetic mean: (75 + 80 + 70) / 3 = 75
	assert_float(score).is_equal_approx(75.0, 0.01)

func test_calculate_composite_score_empty_weights() -> void:
	var player := _create_test_player()
	var weights := {}

	var score := StatFunctions.calculate_composite_score(player, weights)

	assert_float(score).is_equal(0.0)

func test_calculate_composite_score_missing_stats() -> void:
	var player := _create_test_player()
	var weights := {"nonexistent_stat": 1.0, "speed": 1.0}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# Should use 0.0 for missing stats: (0 * 1.0 + 75 * 1.0) / 2.0 = 37.5
	assert_float(score).is_equal_approx(37.5, 0.01)

# ============================================================================
# FUNCTIONALITY TESTS - apply_stat_decay
# ============================================================================

func test_apply_stat_decay_reduces_stats() -> void:
	var player := _create_test_player()
	var decay_rate := 0.9  # 10% reduction

	var result := StatFunctions.apply_stat_decay(player, decay_rate)

	# speed: 75 * 0.9 = 67.5
	assert_float(result["stats"]["speed"]).is_equal_approx(67.5, 0.01)
	# strength: 80 * 0.9 = 72.0
	assert_float(result["stats"]["strength"]).is_equal_approx(72.0, 0.01)

func test_apply_stat_decay_with_growth_rate() -> void:
	var player := _create_test_player()
	var growth_rate := 1.1  # 10% increase

	var result := StatFunctions.apply_stat_decay(player, growth_rate)

	# speed: 75 * 1.1 = 82.5
	assert_float(result["stats"]["speed"]).is_equal_approx(82.5, 0.01)

func test_apply_stat_decay_clamps_to_valid_range() -> void:
	var player := _create_test_player()
	player["stats"]["speed"] = 95.0
	var growth_rate := 1.2  # Would exceed 100

	var result := StatFunctions.apply_stat_decay(player, growth_rate)

	# 95 * 1.2 = 114, clamped to 100
	assert_float(result["stats"]["speed"]).is_equal(100.0)

# ============================================================================
# FUNCTIONALITY TESTS - apply_stat_deltas
# ============================================================================

func test_apply_stat_deltas_adds_positive_deltas() -> void:
	var player := _create_test_player()
	var deltas := {"speed": 5.0, "strength": 3.0}

	var result := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(result["stats"]["speed"]).is_equal(80.0)  # 75 + 5
	assert_float(result["stats"]["strength"]).is_equal(83.0)  # 80 + 3

func test_apply_stat_deltas_adds_negative_deltas() -> void:
	var player := _create_test_player()
	var deltas := {"speed": -10.0, "strength": -5.0}

	var result := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(result["stats"]["speed"]).is_equal(65.0)  # 75 - 10
	assert_float(result["stats"]["strength"]).is_equal(75.0)  # 80 - 5

func test_apply_stat_deltas_clamps_to_range() -> void:
	var player := _create_test_player()
	var deltas := {"speed": 50.0, "strength": -100.0}

	var result := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(result["stats"]["speed"]).is_equal(100.0)  # Capped at 100
	assert_float(result["stats"]["strength"]).is_equal(0.0)  # Clamped to 0

# ============================================================================
# FUNCTIONALITY TESTS - scale_stats
# ============================================================================

func test_scale_stats_applies_multipliers() -> void:
	var player := _create_test_player()
	var multipliers := {"speed": 1.2, "strength": 0.9}

	var result := StatFunctions.scale_stats(player, multipliers)

	# speed: 75 * 1.2 = 90
	assert_float(result["stats"]["speed"]).is_equal(90.0)
	# strength: 80 * 0.9 = 72
	assert_float(result["stats"]["strength"]).is_equal(72.0)
	# awareness: unchanged
	assert_float(result["stats"]["awareness"]).is_equal(70.0)

func test_scale_stats_clamps_to_valid_range() -> void:
	var player := _create_test_player()
	player["stats"]["speed"] = 90.0
	var multipliers := {"speed": 1.5}  # Would exceed 100

	var result := StatFunctions.scale_stats(player, multipliers)

	assert_float(result["stats"]["speed"]).is_equal(100.0)

func test_scale_stats_ignores_nonexistent_stats() -> void:
	var player := _create_test_player()
	var multipliers := {"nonexistent_stat": 2.0, "speed": 1.1}

	var result := StatFunctions.scale_stats(player, multipliers)

	# nonexistent_stat should not be added
	assert_bool(result["stats"].has("nonexistent_stat")).is_false()
	# speed should be scaled
	assert_float(result["stats"]["speed"]).is_equal_approx(82.5, 0.01)

# ============================================================================
# FUNCTIONALITY TESTS - get/set stat
# ============================================================================

func test_get_stat_returns_value() -> void:
	var player := _create_test_player()

	var speed := StatFunctions.get_stat(player, "speed")

	assert_float(speed).is_equal(75.0)

func test_get_stat_returns_default_for_missing() -> void:
	var player := _create_test_player()

	var nonexistent := StatFunctions.get_stat(player, "nonexistent", 50.0)

	assert_float(nonexistent).is_equal(50.0)

func test_set_stat_updates_value() -> void:
	var player := _create_test_player()

	var result := StatFunctions.set_stat(player, "speed", 85.0)

	# Original unchanged
	assert_float(player["stats"]["speed"]).is_equal(75.0)
	# New player updated
	assert_float(result["stats"]["speed"]).is_equal(85.0)

func test_set_stat_clamps_to_range() -> void:
	var player := _create_test_player()

	var result_high := StatFunctions.set_stat(player, "speed", 120.0)
	var result_low := StatFunctions.set_stat(player, "strength", -10.0)

	assert_float(result_high["stats"]["speed"]).is_equal(100.0)
	assert_float(result_low["stats"]["strength"]).is_equal(0.0)

# ============================================================================
# FUNCTIONALITY TESTS - calculate means
# ============================================================================

func test_calculate_mean_stat_all_stats() -> void:
	var player := _create_test_player()
	# stats: speed=75, strength=80, awareness=70, agility=72
	# mean = (75+80+70+72) / 4 = 297/4 = 74.25

	var mean := StatFunctions.calculate_mean_stat(player)

	assert_float(mean).is_equal_approx(74.25, 0.01)

func test_calculate_mean_stat_empty_stats() -> void:
	var player := {"stats": {}}

	var mean := StatFunctions.calculate_mean_stat(player)

	assert_float(mean).is_equal(0.0)

func test_calculate_mean_of_stats_subset() -> void:
	var player := _create_test_player()
	var stat_names := ["speed", "agility"]
	# mean = (75 + 72) / 2 = 73.5

	var mean := StatFunctions.calculate_mean_of_stats(player, stat_names)

	assert_float(mean).is_equal_approx(73.5, 0.01)

func test_calculate_mean_of_stats_empty_array() -> void:
	var player := _create_test_player()

	var mean := StatFunctions.calculate_mean_of_stats(player, [])

	assert_float(mean).is_equal(0.0)

func test_calculate_mean_of_stats_missing_stats() -> void:
	var player := _create_test_player()
	var stat_names := ["speed", "nonexistent"]

	var mean := StatFunctions.calculate_mean_of_stats(player, stat_names)

	# Should only use existing stats: 75 / 1 = 75.0
	assert_float(mean).is_equal(75.0)

# ============================================================================
# FUNCTIONALITY TESTS - normalize_stats_to_mean
# ============================================================================

func test_normalize_stats_to_mean_scales_proportionally() -> void:
	var player := _create_test_player()
	# Current mean: 74.25
	# Target mean: 80.0
	# Scale factor: 80 / 74.25 ≈ 1.0774

	var result := StatFunctions.normalize_stats_to_mean(player, 80.0)

	var new_mean := StatFunctions.calculate_mean_stat(result)
	assert_float(new_mean).is_equal_approx(80.0, 0.1)

func test_normalize_stats_to_mean_preserves_relative_differences() -> void:
	var player := _create_test_player()
	# speed=75, strength=80 (strength is higher by 5)

	var result := StatFunctions.normalize_stats_to_mean(player, 80.0)

	# Relative difference should be preserved (strength still higher)
	assert_bool(result["stats"]["strength"] > result["stats"]["speed"]).is_true()

func test_normalize_stats_to_mean_with_zero_mean() -> void:
	var player := {"stats": {"speed": 0.0, "strength": 0.0}}

	var result := StatFunctions.normalize_stats_to_mean(player, 50.0)

	# Can't normalize from 0, should return unchanged
	assert_float(result["stats"]["speed"]).is_equal(0.0)

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_apply_stat_changes_with_empty_changes() -> void:
	var player := _create_test_player()

	var result := StatFunctions.apply_stat_changes(player, {})

	# Stats should remain unchanged
	assert_dict(result["stats"]).is_equal(player["stats"])

func test_apply_stat_changes_creates_stats_if_missing() -> void:
	var player := {"id": "test"}
	var changes := {"speed": 75.0}

	var result := StatFunctions.apply_stat_changes(player, changes)

	assert_dict(result["stats"]).contains_key_value("speed", 75.0)

func test_cap_stats_at_potential_with_empty_stats() -> void:
	var player := {"stats": {}, "potential": {"speed": 90.0}}

	var result := StatFunctions.cap_stats_at_potential(player)

	# Empty stats should remain empty
	assert_dict(result["stats"]).is_empty()

func test_calculate_composite_score_with_missing_stats_dict() -> void:
	var player := {"id": "test"}  # No stats
	var weights := {"speed": 1.0}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# Should use 0.0 for all missing stats
	assert_float(score).is_equal(0.0)

func test_apply_stat_decay_with_empty_stats() -> void:
	var player := {"stats": {}}

	var result := StatFunctions.apply_stat_decay(player, 0.9)

	assert_dict(result["stats"]).is_empty()

func test_scale_stats_with_empty_multipliers() -> void:
	var player := _create_test_player()

	var result := StatFunctions.scale_stats(player, {})

	# Stats should remain unchanged
	assert_dict(result["stats"]).is_equal(player["stats"])
