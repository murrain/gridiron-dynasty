extends GdUnitTestSuite
class_name TestReplacementLevelGdUnit4

const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")

## Test that default replacement levels are loaded correctly
func test_default_replacement_levels() -> void:
	assert_float(ReplacementLevel.get_replacement_level("QB")).is_equal(55.0)
	assert_float(ReplacementLevel.get_replacement_level("RB")).is_equal(62.0)
	assert_float(ReplacementLevel.get_replacement_level("EDGE")).is_equal(52.0)
	assert_float(ReplacementLevel.get_replacement_level("K")).is_equal(65.0)
	assert_float(ReplacementLevel.get_replacement_level("P")).is_equal(65.0)

## Test that custom config overrides default replacement levels
func test_custom_replacement_levels() -> void:
	var config := {
		"replacement_levels": {
			"QB": 60.0,
			"RB": 70.0
		}
	}

	assert_float(ReplacementLevel.get_replacement_level("QB", config)).is_equal(60.0)
	assert_float(ReplacementLevel.get_replacement_level("RB", config)).is_equal(70.0)

## Test that unknown positions return a sensible default
func test_unknown_position_default() -> void:
	var unknown_level := ReplacementLevel.get_replacement_level("UNKNOWN")
	assert_float(unknown_level).is_equal(55.0)

## Test VOR calculation for player above replacement level
func test_vor_above_replacement() -> void:
	var vor := ReplacementLevel.value_over_replacement(80.0, "QB")
	assert_float(vor).is_equal(25.0)  # 80 - 55 = 25

## Test VOR calculation for player at replacement level
func test_vor_at_replacement() -> void:
	var vor := ReplacementLevel.value_over_replacement(55.0, "QB")
	assert_float(vor).is_equal(0.0)

## Test VOR calculation for player below replacement level
func test_vor_below_replacement() -> void:
	var vor := ReplacementLevel.value_over_replacement(50.0, "QB")
	assert_float(vor).is_equal(0.0)  # Clamped to minimum 0

## Test VOR with different positions
func test_vor_different_positions() -> void:
	# QB replacement level is 55.0
	var qb_vor := ReplacementLevel.value_over_replacement(75.0, "QB")
	assert_float(qb_vor).is_equal(20.0)

	# RB replacement level is 62.0
	var rb_vor := ReplacementLevel.value_over_replacement(75.0, "RB")
	assert_float(rb_vor).is_equal(13.0)

	# EDGE replacement level is 52.0
	var edge_vor := ReplacementLevel.value_over_replacement(75.0, "EDGE")
	assert_float(edge_vor).is_equal(23.0)

## Test VOR calculation from player dictionary
func test_player_vor_from_dict() -> void:
	var player := {
		"position": "WR",
		"eval_score": 80.0
	}

	var vor := ReplacementLevel.player_vor(player)
	# WR replacement level is 58.0, so 80 - 58 = 22
	assert_float(vor).is_equal(22.0)

## Test player VOR with missing fields uses defaults
func test_player_vor_missing_fields() -> void:
	var player := {}

	var vor := ReplacementLevel.player_vor(player)
	# Default position "ATH" (55.0) and default eval_score 50.0
	# 50 - 55 = -5, clamped to 0
	assert_float(vor).is_equal(0.0)

## Test that replacement levels reflect position scarcity
func test_replacement_levels_reflect_scarcity() -> void:
	# Scarce positions should have lower replacement levels (harder to find quality)
	var qb_level := ReplacementLevel.get_replacement_level("QB")
	var edge_level := ReplacementLevel.get_replacement_level("EDGE")
	var cb_level := ReplacementLevel.get_replacement_level("CB")

	# Abundant positions should have higher replacement levels (easier to replace)
	var rb_level := ReplacementLevel.get_replacement_level("RB")
	var k_level := ReplacementLevel.get_replacement_level("K")

	# Scarce positions have lower levels
	assert_bool(edge_level < rb_level).is_true()
	assert_bool(qb_level < rb_level).is_true()
	assert_bool(cb_level < k_level).is_true()

## Test VOR with custom config
func test_vor_with_custom_config() -> void:
	var config := {
		"replacement_levels": {
			"QB": 70.0
		}
	}

	var vor := ReplacementLevel.value_over_replacement(75.0, "QB", config)
	assert_float(vor).is_equal(5.0)  # 75 - 70 = 5

## Test edge case: zero score
func test_vor_zero_score() -> void:
	var vor := ReplacementLevel.value_over_replacement(0.0, "QB")
	assert_float(vor).is_equal(0.0)

## Test edge case: maximum score
func test_vor_maximum_score() -> void:
	var vor := ReplacementLevel.value_over_replacement(100.0, "QB")
	assert_float(vor).is_equal(45.0)  # 100 - 55 = 45

## Test that replacement levels are consistent across calls
func test_replacement_level_consistency() -> void:
	var level1 := ReplacementLevel.get_replacement_level("QB")
	var level2 := ReplacementLevel.get_replacement_level("QB")
	var level3 := ReplacementLevel.get_replacement_level("QB")

	assert_float(level1).is_equal(level2)
	assert_float(level2).is_equal(level3)
