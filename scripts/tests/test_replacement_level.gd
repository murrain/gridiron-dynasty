extends RefCounted

const ReplacementLevel = preload("res://scripts/core/valuation/ReplacementLevel.gd")

func run(t) -> void:
	test_get_replacement_level_default(t)
	test_get_replacement_level_from_config(t)
	test_value_over_replacement_above(t)
	test_value_over_replacement_below(t)
	test_value_over_replacement_at_replacement(t)
	test_player_vor_convenience(t)
	test_position_specific_baselines(t)

## Test that default replacement levels are returned when no config is provided.
func test_get_replacement_level_default(t) -> void:
	var qb_repl := ReplacementLevel.get_replacement_level("QB")
	t.assert_approx(qb_repl, 55.0, 0.001, "QB replacement level is 55.0")

	var rb_repl := ReplacementLevel.get_replacement_level("RB")
	t.assert_approx(rb_repl, 62.0, 0.001, "RB replacement level is 62.0")

	var edge_repl := ReplacementLevel.get_replacement_level("EDGE")
	t.assert_approx(edge_repl, 52.0, 0.001, "EDGE replacement level is 52.0")

	var k_repl := ReplacementLevel.get_replacement_level("K")
	t.assert_approx(k_repl, 65.0, 0.001, "K replacement level is 65.0")

	# Unknown position should return default (55.0)
	var unknown_repl := ReplacementLevel.get_replacement_level("UNKNOWN")
	t.assert_approx(unknown_repl, 55.0, 0.001, "Unknown position returns default 55.0")

## Test that config overrides default replacement levels.
func test_get_replacement_level_from_config(t) -> void:
	var config := {
		"replacement_levels": {
			"QB": 60.0,
			"RB": 65.0,
			"WR": 55.0
		}
	}

	var qb_repl := ReplacementLevel.get_replacement_level("QB", config)
	t.assert_approx(qb_repl, 60.0, 0.001, "Config overrides QB replacement level")

	var rb_repl := ReplacementLevel.get_replacement_level("RB", config)
	t.assert_approx(rb_repl, 65.0, 0.001, "Config overrides RB replacement level")

	# Position not in config should still use default
	var edge_repl := ReplacementLevel.get_replacement_level("EDGE", config)
	t.assert_approx(edge_repl, 55.0, 0.001, "Non-config position returns default")

## Test VOR calculation for players above replacement level.
func test_value_over_replacement_above(t) -> void:
	# QB with 80 score, replacement is 55 → VOR = 25
	var vor := ReplacementLevel.value_over_replacement(80.0, "QB")
	t.assert_approx(vor, 25.0, 0.001, "VOR for QB above replacement")

	# RB with 75 score, replacement is 62 → VOR = 13
	vor = ReplacementLevel.value_over_replacement(75.0, "RB")
	t.assert_approx(vor, 13.0, 0.001, "VOR for RB above replacement")

	# EDGE with 90 score, replacement is 52 → VOR = 38
	vor = ReplacementLevel.value_over_replacement(90.0, "EDGE")
	t.assert_approx(vor, 38.0, 0.001, "VOR for EDGE above replacement")

## Test VOR calculation for players below replacement level.
func test_value_over_replacement_below(t) -> void:
	# QB with 50 score, replacement is 55 → VOR = 0 (clamped)
	var vor := ReplacementLevel.value_over_replacement(50.0, "QB")
	t.assert_approx(vor, 0.0, 0.001, "VOR for QB below replacement is 0")

	# RB with 55 score, replacement is 62 → VOR = 0 (clamped)
	vor = ReplacementLevel.value_over_replacement(55.0, "RB")
	t.assert_approx(vor, 0.0, 0.001, "VOR for RB below replacement is 0")

	# K with 60 score, replacement is 65 → VOR = 0 (clamped)
	vor = ReplacementLevel.value_over_replacement(60.0, "K")
	t.assert_approx(vor, 0.0, 0.001, "VOR for K below replacement is 0")

## Test VOR calculation for players exactly at replacement level.
func test_value_over_replacement_at_replacement(t) -> void:
	# QB with 55 score (exactly at replacement) → VOR = 0
	var vor := ReplacementLevel.value_over_replacement(55.0, "QB")
	t.assert_approx(vor, 0.0, 0.001, "VOR for QB at replacement is 0")

	# RB with 62 score (exactly at replacement) → VOR = 0
	vor = ReplacementLevel.value_over_replacement(62.0, "RB")
	t.assert_approx(vor, 0.0, 0.001, "VOR for RB at replacement is 0")

## Test the player_vor convenience method.
func test_player_vor_convenience(t) -> void:
	var player := {
		"position": "QB",
		"eval_score": 80.0
	}

	var vor := ReplacementLevel.player_vor(player)
	t.assert_approx(vor, 25.0, 0.001, "player_vor calculates correctly from dict")

	# Test with missing fields (should use defaults)
	var minimal_player := {}
	vor = ReplacementLevel.player_vor(minimal_player)
	# Position defaults to "ATH" (55.0), eval_score defaults to 50.0 → VOR = 0
	t.assert_approx(vor, 0.0, 0.001, "player_vor handles missing fields with defaults")

	# Test with custom config
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
	t.assert_approx(vor, 20.0, 0.001, "player_vor respects config overrides")

## Test that different positions have appropriate replacement levels.
func test_position_specific_baselines(t) -> void:
	# Scarce positions should have lower replacement levels
	var qb := ReplacementLevel.get_replacement_level("QB")
	var edge := ReplacementLevel.get_replacement_level("EDGE")
	var cb := ReplacementLevel.get_replacement_level("CB")

	# Abundant positions should have higher replacement levels
	var rb := ReplacementLevel.get_replacement_level("RB")
	var k := ReplacementLevel.get_replacement_level("K")
	var p := ReplacementLevel.get_replacement_level("P")

	# Verify scarcity relationships
	t.assert_true(edge < qb, "EDGE replacement level lower than QB (more scarce)")
	t.assert_true(cb < qb, "CB replacement level lower than QB (more scarce)")
	t.assert_true(qb < rb, "QB replacement level lower than RB (QB more scarce)")
	t.assert_true(rb < k, "RB replacement level lower than K (RB more valuable)")
	t.assert_true(k >= 65.0, "K replacement level is high (very replaceable)")
	t.assert_true(p >= 65.0, "P replacement level is high (very replaceable)")

	# Verify all replacement levels are in reasonable range (40-70)
	for pos in ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]:
		var repl := ReplacementLevel.get_replacement_level(pos)
		t.assert_between(repl, 40.0, 70.0, "%s replacement level is in reasonable range" % pos)
