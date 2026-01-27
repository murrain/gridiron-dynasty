extends GdUnitTestSuite
class_name TestStatFunctions

const StatFunctions = preload("res://scripts/core/transformations/StatFunctions.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

# ============================================================================
# SETUP
# ============================================================================

func create_test_player() -> Dictionary:
	return {
		"name": "Test Player",
		"position": "QB",
		"stats": {
			"speed": 70.0,
			"strength": 80.0,
			"awareness": 75.0
		},
		"potential": {
			"speed": 85.0,
			"strength": 90.0,
			"awareness": 85.0
		}
	}


# ============================================================================
# APPLY STAT CHANGES TESTS
# ============================================================================

func test_apply_stat_changes_updates_stats() -> void:
	var player := create_test_player()
	var changes := {
		"speed": 85.0,
		"strength": 90.0
	}

	var updated := StatFunctions.apply_stat_changes(player, changes)

	assert_float(updated["stats"]["speed"]).is_equal(85.0)
	assert_float(updated["stats"]["strength"]).is_equal(90.0)
	# Unchanged stat should remain the same
	assert_float(updated["stats"]["awareness"]).is_equal(75.0)


func test_apply_stat_changes_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)
	var changes := {"speed": 85.0}

	var _updated := StatFunctions.apply_stat_changes(player, changes)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


func test_apply_stat_changes_clamps_to_100() -> void:
	var player := create_test_player()
	var changes := {"speed": 150.0}

	var updated := StatFunctions.apply_stat_changes(player, changes)

	# Should be clamped at 100
	assert_float(updated["stats"]["speed"]).is_equal(100.0)


func test_apply_stat_changes_clamps_to_0() -> void:
	var player := create_test_player()
	var changes := {"speed": -50.0}

	var updated := StatFunctions.apply_stat_changes(player, changes)

	# Should be clamped at 0
	assert_float(updated["stats"]["speed"]).is_equal(0.0)


func test_apply_stat_changes_creates_stats_if_missing() -> void:
	var player := {"name": "Test"}  # No stats
	var changes := {"speed": 75.0}

	var updated := StatFunctions.apply_stat_changes(player, changes)

	assert_dict(updated).contains_key("stats")
	assert_float(updated["stats"]["speed"]).is_equal(75.0)


func test_apply_stat_changes_empty_changes() -> void:
	var player := create_test_player()
	var changes := {}

	var updated := StatFunctions.apply_stat_changes(player, changes)

	# Stats should be unchanged
	assert_float(updated["stats"]["speed"]).is_equal(70.0)


# ============================================================================
# CAP STATS AT POTENTIAL TESTS
# ============================================================================

func test_cap_stats_at_potential_basic() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 90.0  # Above potential (85)

	var capped := StatFunctions.cap_stats_at_potential(player)

	assert_float(capped["stats"]["speed"]).is_equal(85.0)


func test_cap_stats_at_potential_below_potential() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 80.0  # Below potential (85)

	var capped := StatFunctions.cap_stats_at_potential(player)

	# Should remain unchanged
	assert_float(capped["stats"]["speed"]).is_equal(80.0)


func test_cap_stats_at_potential_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)

	var _capped := StatFunctions.cap_stats_at_potential(player)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


func test_cap_stats_at_potential_missing_potential_uses_current() -> void:
	var player := create_test_player()
	player["stats"]["new_stat"] = 95.0
	# new_stat not in potential

	var capped := StatFunctions.cap_stats_at_potential(player)

	# Should use current value as potential
	assert_float(capped["stats"]["new_stat"]).is_equal(95.0)


# ============================================================================
# CALCULATE COMPOSITE SCORE TESTS
# ============================================================================

func test_calculate_composite_score_basic() -> void:
	var player := create_test_player()
	var weights := {
		"speed": 0.5,
		"strength": 0.3,
		"awareness": 0.2
	}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# (70 * 0.5) + (80 * 0.3) + (75 * 0.2) = 35 + 24 + 15 = 74
	assert_float(score).is_equal(74.0)


func test_calculate_composite_score_equal_weights() -> void:
	var player := create_test_player()
	var weights := {
		"speed": 1.0,
		"strength": 1.0,
		"awareness": 1.0
	}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# Should be simple average: (70 + 80 + 75) / 3 = 75
	assert_float(score).is_equal(75.0)


func test_calculate_composite_score_missing_stat() -> void:
	var player := create_test_player()
	var weights := {
		"speed": 0.5,
		"nonexistent": 0.5
	}

	var score := StatFunctions.calculate_composite_score(player, weights)

	# nonexistent defaults to 0, so: (70 * 0.5) + (0 * 0.5) = 35
	assert_float(score).is_equal(35.0)


func test_calculate_composite_score_empty_weights() -> void:
	var player := create_test_player()
	var weights := {}

	var score := StatFunctions.calculate_composite_score(player, weights)

	assert_float(score).is_equal(0.0)


func test_calculate_composite_score_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)
	var weights := {"speed": 1.0}

	var _score := StatFunctions.calculate_composite_score(player, weights)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


# ============================================================================
# APPLY STAT DECAY TESTS
# ============================================================================

func test_apply_stat_decay_basic() -> void:
	var player := create_test_player()
	var decayed := StatFunctions.apply_stat_decay(player, 0.9)  # 10% decay

	# speed 70 * 0.9 = 63
	assert_float(decayed["stats"]["speed"]).is_equal(63.0)

	# strength 80 * 0.9 = 72
	assert_float(decayed["stats"]["strength"]).is_equal(72.0)


func test_apply_stat_decay_no_change() -> void:
	var player := create_test_player()
	var decayed := StatFunctions.apply_stat_decay(player, 1.0)  # No decay

	assert_float(decayed["stats"]["speed"]).is_equal(70.0)
	assert_float(decayed["stats"]["strength"]).is_equal(80.0)


func test_apply_stat_decay_growth() -> void:
	var player := create_test_player()
	var grown := StatFunctions.apply_stat_decay(player, 1.1)  # 10% growth

	# speed 70 * 1.1 = 77
	assert_float(grown["stats"]["speed"]).is_equal(77.0)


func test_apply_stat_decay_clamps_to_100() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 95.0

	var grown := StatFunctions.apply_stat_decay(player, 1.2)  # Would be 114

	# Should be clamped at 100
	assert_float(grown["stats"]["speed"]).is_equal(100.0)


func test_apply_stat_decay_clamps_to_0() -> void:
	var player := create_test_player()
	player["stats"]["speed"] = 5.0

	var decayed := StatFunctions.apply_stat_decay(player, 0.0)  # Total decay

	# Should be clamped at 0
	assert_float(decayed["stats"]["speed"]).is_equal(0.0)


func test_apply_stat_decay_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)

	var _decayed := StatFunctions.apply_stat_decay(player, 0.9)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


# ============================================================================
# APPLY STAT DELTAS TESTS
# ============================================================================

func test_apply_stat_deltas_positive() -> void:
	var player := create_test_player()
	var deltas := {"speed": 5.0, "strength": 3.0}

	var updated := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(updated["stats"]["speed"]).is_equal(75.0)  # 70 + 5
	assert_float(updated["stats"]["strength"]).is_equal(83.0)  # 80 + 3


func test_apply_stat_deltas_negative() -> void:
	var player := create_test_player()
	var deltas := {"speed": -10.0}

	var updated := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(updated["stats"]["speed"]).is_equal(60.0)  # 70 - 10


func test_apply_stat_deltas_mixed() -> void:
	var player := create_test_player()
	var deltas := {"speed": 5.0, "strength": -5.0}

	var updated := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(updated["stats"]["speed"]).is_equal(75.0)
	assert_float(updated["stats"]["strength"]).is_equal(75.0)


func test_apply_stat_deltas_clamps_to_100() -> void:
	var player := create_test_player()
	var deltas := {"speed": 50.0}  # Would be 120

	var updated := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(updated["stats"]["speed"]).is_equal(100.0)


func test_apply_stat_deltas_clamps_to_0() -> void:
	var player := create_test_player()
	var deltas := {"speed": -100.0}  # Would be -30

	var updated := StatFunctions.apply_stat_deltas(player, deltas)

	assert_float(updated["stats"]["speed"]).is_equal(0.0)


func test_apply_stat_deltas_new_stat_defaults_to_0() -> void:
	var player := create_test_player()
	var deltas := {"new_stat": 50.0}

	var updated := StatFunctions.apply_stat_deltas(player, deltas)

	# 0 + 50 = 50
	assert_float(updated["stats"]["new_stat"]).is_equal(50.0)


func test_apply_stat_deltas_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)
	var deltas := {"speed": 5.0}

	var _updated := StatFunctions.apply_stat_deltas(player, deltas)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


# ============================================================================
# SCALE STATS TESTS
# ============================================================================

func test_scale_stats_basic() -> void:
	var player := create_test_player()
	var multipliers := {"speed": 1.1, "strength": 0.9}

	var scaled := StatFunctions.scale_stats(player, multipliers)

	# speed 70 * 1.1 = 77
	assert_float(scaled["stats"]["speed"]).is_equal(77.0)

	# strength 80 * 0.9 = 72
	assert_float(scaled["stats"]["strength"]).is_equal(72.0)

	# awareness unchanged (not in multipliers)
	assert_float(scaled["stats"]["awareness"]).is_equal(75.0)


func test_scale_stats_only_scales_existing() -> void:
	var player := create_test_player()
	var multipliers := {"nonexistent": 2.0}

	var scaled := StatFunctions.scale_stats(player, multipliers)

	# Should not add new stats
	assert_bool(scaled["stats"].has("nonexistent")).is_false()


func test_scale_stats_clamps_to_100() -> void:
	var player := create_test_player()
	var multipliers := {"strength": 2.0}  # Would be 160

	var scaled := StatFunctions.scale_stats(player, multipliers)

	assert_float(scaled["stats"]["strength"]).is_equal(100.0)


func test_scale_stats_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)
	var multipliers := {"speed": 1.1}

	var _scaled := StatFunctions.scale_stats(player, multipliers)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


# ============================================================================
# GET STAT TESTS
# ============================================================================

func test_get_stat_exists() -> void:
	var player := create_test_player()

	var speed := StatFunctions.get_stat(player, "speed")

	assert_float(speed).is_equal(70.0)


func test_get_stat_missing_uses_default() -> void:
	var player := create_test_player()

	var missing := StatFunctions.get_stat(player, "nonexistent", 99.0)

	assert_float(missing).is_equal(99.0)


func test_get_stat_missing_no_default() -> void:
	var player := create_test_player()

	var missing := StatFunctions.get_stat(player, "nonexistent")

	assert_float(missing).is_equal(0.0)


# ============================================================================
# SET STAT TESTS
# ============================================================================

func test_set_stat_basic() -> void:
	var player := create_test_player()

	var updated := StatFunctions.set_stat(player, "speed", 85.0)

	assert_float(updated["stats"]["speed"]).is_equal(85.0)


func test_set_stat_creates_new() -> void:
	var player := create_test_player()

	var updated := StatFunctions.set_stat(player, "new_stat", 75.0)

	assert_float(updated["stats"]["new_stat"]).is_equal(75.0)


func test_set_stat_clamps_to_100() -> void:
	var player := create_test_player()

	var updated := StatFunctions.set_stat(player, "speed", 150.0)

	assert_float(updated["stats"]["speed"]).is_equal(100.0)


func test_set_stat_clamps_to_0() -> void:
	var player := create_test_player()

	var updated := StatFunctions.set_stat(player, "speed", -50.0)

	assert_float(updated["stats"]["speed"]).is_equal(0.0)


func test_set_stat_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)

	var _updated := StatFunctions.set_stat(player, "speed", 85.0)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


# ============================================================================
# CALCULATE MEAN STAT TESTS
# ============================================================================

func test_calculate_mean_stat_basic() -> void:
	var player := create_test_player()

	var mean := StatFunctions.calculate_mean_stat(player)

	# (70 + 80 + 75) / 3 = 75
	assert_float(mean).is_equal(75.0)


func test_calculate_mean_stat_empty_stats() -> void:
	var player := {"stats": {}}

	var mean := StatFunctions.calculate_mean_stat(player)

	assert_float(mean).is_equal(0.0)


func test_calculate_mean_stat_filters_non_numeric() -> void:
	var player := create_test_player()
	player["stats"]["name"] = "test"  # String

	var mean := StatFunctions.calculate_mean_stat(player)

	# Should only average numeric stats: (70 + 80 + 75) / 3 = 75
	assert_float(mean).is_equal(75.0)


# ============================================================================
# CALCULATE MEAN OF STATS TESTS
# ============================================================================

func test_calculate_mean_of_stats_basic() -> void:
	var player := create_test_player()

	var mean := StatFunctions.calculate_mean_of_stats(player, ["speed", "strength"])

	# (70 + 80) / 2 = 75
	assert_float(mean).is_equal(75.0)


func test_calculate_mean_of_stats_single() -> void:
	var player := create_test_player()

	var mean := StatFunctions.calculate_mean_of_stats(player, ["speed"])

	assert_float(mean).is_equal(70.0)


func test_calculate_mean_of_stats_empty_list() -> void:
	var player := create_test_player()

	var mean := StatFunctions.calculate_mean_of_stats(player, [])

	assert_float(mean).is_equal(0.0)


func test_calculate_mean_of_stats_missing_stats() -> void:
	var player := create_test_player()

	var mean := StatFunctions.calculate_mean_of_stats(player, ["speed", "nonexistent"])

	# Should only average existing stats: 70 / 1 = 70
	assert_float(mean).is_equal(70.0)


# ============================================================================
# NORMALIZE STATS TO MEAN TESTS
# ============================================================================

func test_normalize_stats_to_mean_basic() -> void:
	var player := create_test_player()
	# Current mean: (70 + 80 + 75) / 3 = 75
	# Target mean: 90

	var normalized := StatFunctions.normalize_stats_to_mean(player, 90.0)

	# Scale factor: 90 / 75 = 1.2
	# speed: 70 * 1.2 = 84
	# strength: 80 * 1.2 = 96
	# awareness: 75 * 1.2 = 90
	assert_float(normalized["stats"]["speed"]).is_equal(84.0)
	assert_float(normalized["stats"]["strength"]).is_equal(96.0)
	assert_float(normalized["stats"]["awareness"]).is_equal(90.0)


func test_normalize_stats_to_mean_down() -> void:
	var player := create_test_player()
	# Current mean: 75, target: 60

	var normalized := StatFunctions.normalize_stats_to_mean(player, 60.0)

	# Scale factor: 60 / 75 = 0.8
	# speed: 70 * 0.8 = 56
	assert_float(normalized["stats"]["speed"]).is_equal(56.0)


func test_normalize_stats_to_mean_zero_current_mean() -> void:
	var player := {"stats": {"speed": 0.0, "strength": 0.0}}

	var normalized := StatFunctions.normalize_stats_to_mean(player, 75.0)

	# Can't normalize from 0, should return unchanged
	assert_float(normalized["stats"]["speed"]).is_equal(0.0)


func test_normalize_stats_to_mean_is_pure() -> void:
	var player := create_test_player()
	var player_copy := player.duplicate(true)

	var _normalized := StatFunctions.normalize_stats_to_mean(player, 90.0)

	# Original should be unchanged
	assert_that(player).is_equal(player_copy)


# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_functions_handle_missing_stats_dict() -> void:
	var player := {"name": "Test"}  # No stats dict

	# get_stat should handle gracefully
	var stat := StatFunctions.get_stat(player, "speed", 0.0)
	assert_float(stat).is_equal(0.0)

	# calculate_mean_stat should handle gracefully
	var mean := StatFunctions.calculate_mean_stat(player)
	assert_float(mean).is_equal(0.0)


func test_empty_deltas_preserves_stats() -> void:
	var player := create_test_player()
	var updated := StatFunctions.apply_stat_deltas(player, {})

	assert_float(updated["stats"]["speed"]).is_equal(70.0)


# ============================================================================
# PURITY VERIFICATION TESTS
# ============================================================================

func test_all_functions_are_pure() -> void:
	var player := create_test_player()
	var original := player.duplicate(true)

	# Call all functions
	var _c1 := StatFunctions.apply_stat_changes(player, {"speed": 80.0})
	var _c2 := StatFunctions.cap_stats_at_potential(player)
	var _c3 := StatFunctions.calculate_composite_score(player, {"speed": 1.0})
	var _c4 := StatFunctions.apply_stat_decay(player, 0.9)
	var _c5 := StatFunctions.apply_stat_deltas(player, {"speed": 5.0})
	var _c6 := StatFunctions.scale_stats(player, {"speed": 1.1})
	var _c7 := StatFunctions.get_stat(player, "speed")
	var _c8 := StatFunctions.set_stat(player, "speed", 85.0)
	var _c9 := StatFunctions.calculate_mean_stat(player)
	var _c10 := StatFunctions.calculate_mean_of_stats(player, ["speed"])
	var _c11 := StatFunctions.normalize_stats_to_mean(player, 80.0)

	# Player should be completely unchanged
	assert_that(player).is_equal(original)
