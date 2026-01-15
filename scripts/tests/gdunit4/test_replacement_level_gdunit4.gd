## GdUnit4 test suite for ReplacementLevel
##
## Validates replacement level calculations and VOR computation.
## Migrated from test_replacement_level.gd
extends GdUnitTestSuite

const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")


func test_get_replacement_level_default() -> void:
	var qb_repl := ReplacementLevel.get_replacement_level("QB")
	assert_float(qb_repl).is_equal_approx(55.0, 0.001)

	var rb_repl := ReplacementLevel.get_replacement_level("RB")
	assert_float(rb_repl).is_equal_approx(62.0, 0.001)

	var edge_repl := ReplacementLevel.get_replacement_level("EDGE")
	assert_float(edge_repl).is_equal_approx(52.0, 0.001)

	var k_repl := ReplacementLevel.get_replacement_level("K")
	assert_float(k_repl).is_equal_approx(65.0, 0.001)

	var unknown_repl := ReplacementLevel.get_replacement_level("UNKNOWN")
	assert_float(unknown_repl).is_equal_approx(55.0, 0.001)


func test_get_replacement_level_from_config() -> void:
	var config := {
		"replacement_levels": {
			"QB": 60.0,
			"RB": 65.0,
			"WR": 55.0
		}
	}

	var qb_repl := ReplacementLevel.get_replacement_level("QB", config)
	assert_float(qb_repl).is_equal_approx(60.0, 0.001)

	var rb_repl := ReplacementLevel.get_replacement_level("RB", config)
	assert_float(rb_repl).is_equal_approx(65.0, 0.001)

	var edge_repl := ReplacementLevel.get_replacement_level("EDGE", config)
	assert_float(edge_repl).is_equal_approx(55.0, 0.001)


func test_value_over_replacement_above() -> void:
	var vor := ReplacementLevel.value_over_replacement(80.0, "QB")
	assert_float(vor).is_equal_approx(25.0, 0.001)

	vor = ReplacementLevel.value_over_replacement(75.0, "RB")
	assert_float(vor).is_equal_approx(13.0, 0.001)

	vor = ReplacementLevel.value_over_replacement(90.0, "EDGE")
	assert_float(vor).is_equal_approx(38.0, 0.001)


func test_value_over_replacement_below() -> void:
	var vor := ReplacementLevel.value_over_replacement(50.0, "QB")
	assert_float(vor).is_equal_approx(0.0, 0.001)

	vor = ReplacementLevel.value_over_replacement(55.0, "RB")
	assert_float(vor).is_equal_approx(0.0, 0.001)

	vor = ReplacementLevel.value_over_replacement(60.0, "K")
	assert_float(vor).is_equal_approx(0.0, 0.001)


func test_value_over_replacement_at_replacement() -> void:
	var vor := ReplacementLevel.value_over_replacement(55.0, "QB")
	assert_float(vor).is_equal_approx(0.0, 0.001)

	vor = ReplacementLevel.value_over_replacement(62.0, "RB")
	assert_float(vor).is_equal_approx(0.0, 0.001)


func test_player_vor_convenience() -> void:
	var player := {
		"position": "QB",
		"eval_score": 80.0
	}

	var vor := ReplacementLevel.player_vor(player)
	assert_float(vor).is_equal_approx(25.0, 0.001)

	var minimal_player := {}
	vor = ReplacementLevel.player_vor(minimal_player)
	assert_float(vor).is_equal_approx(0.0, 0.001)

	var config := {
		"replacement_levels": {
			"WR": 50.0
		}
	}
	var wr_player := {
		"position": "WR",
		"eval_score": 70.0
	}
	vor = ReplacementLevel.player_vor(wr_player, config)
	assert_float(vor).is_equal_approx(20.0, 0.001)


func test_position_specific_baselines() -> void:
	var qb := ReplacementLevel.get_replacement_level("QB")
	var edge := ReplacementLevel.get_replacement_level("EDGE")
	var cb := ReplacementLevel.get_replacement_level("CB")

	var rb := ReplacementLevel.get_replacement_level("RB")
	var k := ReplacementLevel.get_replacement_level("K")
	var p := ReplacementLevel.get_replacement_level("P")

	assert_float(edge).is_less(qb)
	assert_float(cb).is_less(qb)
	assert_float(qb).is_less(rb)
	assert_float(rb).is_less(k)
	assert_float(k).is_greater_equal(65.0)
	assert_float(p).is_greater_equal(65.0)

	for pos in ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]:
		var repl := ReplacementLevel.get_replacement_level(pos)
		assert_float(repl).is_between(40.0, 70.0)
