extends RefCounted

const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

func run(t) -> void:
	test_calculate_overall_rating(t)
	test_filter_college_eligible_with_composite_score(t)
	test_filter_college_eligible_with_core_avg(t)
	test_filter_college_eligible_various_thresholds(t)
	test_filter_all_pass_threshold_zero(t)
	test_filter_none_pass_threshold_high(t)
	test_filter_determinism(t)
	test_filter_preserves_player_data(t)
	test_filter_with_mixed_ratings(t)

func test_calculate_overall_rating(t) -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["speed", "awareness", "throw_power"]},
		"RB": {"core_stats": ["speed", "agility", "strength"]}
	}
	var class_rules := {}

	# Test with composite_score (highest priority)
	var player_composite := {
		"composite_score": 85.0,
		"core_avg": 70.0,
		"stats": {"speed": 60.0}
	}
	var rating := PlayerRatingCalculator.calculate_overall_rating(player_composite, positions_cfg, class_rules)
	t.assert_eq(rating, 85.0, "calculate_overall_rating uses composite_score when available")

	# Test with core_avg (fallback)
	var player_core_avg := {
		"core_avg": 75.0,
		"stats": {"speed": 60.0}
	}
	rating = PlayerRatingCalculator.calculate_overall_rating(player_core_avg, positions_cfg, class_rules)
	t.assert_eq(rating, 75.0, "calculate_overall_rating uses core_avg when composite_score missing")

	# Test with position-specific core stats calculation
	var player_stats := {
		"position": "QB",
		"stats": {
			"speed": 70.0,
			"awareness": 80.0,
			"throw_power": 75.0,
			"other_stat": 50.0
		}
	}
	rating = PlayerRatingCalculator.calculate_overall_rating(player_stats, positions_cfg, class_rules)
	var expected := (70.0 + 80.0 + 75.0) / 3.0
	t.assert_eq(rating, expected, "calculate_overall_rating computes core stats average for position")

	# Test fallback to simple stats average when no position config
	var player_no_position := {
		"position": "UNKNOWN",
		"stats": {
			"speed": 60.0,
			"strength": 80.0
		}
	}
	rating = PlayerRatingCalculator.calculate_overall_rating(player_no_position, positions_cfg, class_rules)
	expected = (60.0 + 80.0) / 2.0
	t.assert_eq(rating, expected, "calculate_overall_rating falls back to simple average when position unknown")

	# Test empty stats returns 0
	var player_empty := {
		"position": "UNKNOWN",
		"stats": {}
	}
	rating = PlayerRatingCalculator.calculate_overall_rating(player_empty, positions_cfg, class_rules)
	t.assert_eq(rating, 0.0, "calculate_overall_rating returns 0 for empty stats")

func test_filter_college_eligible_with_composite_score(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 40.0
		}
	}

	var graduates := [
		{"player_id": "p1", "composite_score": 50.0},  # Pass
		{"player_id": "p2", "composite_score": 35.0},  # Fail
		{"player_id": "p3", "composite_score": 40.0},  # Pass (exactly at threshold)
		{"player_id": "p4", "composite_score": 65.0},  # Pass
		{"player_id": "p5", "composite_score": 25.0},  # Fail
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	t.assert_eq(eligible.size(), 3, "filter_college_eligible correctly filters by threshold 40.0")

	var ids := []
	for p in eligible:
		var player: Dictionary = p
		ids.append(player.get("player_id", ""))

	t.assert_true("p1" in ids, "player with rating 50 is eligible")
	t.assert_true("p3" in ids, "player with rating 40 (exact threshold) is eligible")
	t.assert_true("p4" in ids, "player with rating 65 is eligible")
	t.assert_true(not ("p2" in ids), "player with rating 35 is not eligible")
	t.assert_true(not ("p5" in ids), "player with rating 25 is not eligible")

func test_filter_college_eligible_with_core_avg(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 50.0
		}
	}

	var graduates := [
		{"player_id": "p1", "core_avg": 55.0},  # Pass
		{"player_id": "p2", "core_avg": 45.0},  # Fail
		{"player_id": "p3", "core_avg": 50.0},  # Pass
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	t.assert_eq(eligible.size(), 2, "filter uses core_avg when composite_score missing")

func test_filter_college_eligible_various_thresholds(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}

	var graduates := []
	# Create 100 players with ratings from 0 to 99
	for i in range(100):
		graduates.append({"player_id": "p%d" % i, "composite_score": float(i)})

	# Test threshold 30 (expect players 30-99 = 70 players)
	var hs_cfg_30 := {"recruiting": {"college_eligibility_threshold": 30.0}}
	var eligible_30 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg_30)
	t.assert_eq(eligible_30.size(), 70, "threshold 30 passes 70 players")

	# Test threshold 40 (expect players 40-99 = 60 players)
	var hs_cfg_40 := {"recruiting": {"college_eligibility_threshold": 40.0}}
	var eligible_40 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg_40)
	t.assert_eq(eligible_40.size(), 60, "threshold 40 passes 60 players")

	# Test threshold 50 (expect players 50-99 = 50 players)
	var hs_cfg_50 := {"recruiting": {"college_eligibility_threshold": 50.0}}
	var eligible_50 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg_50)
	t.assert_eq(eligible_50.size(), 50, "threshold 50 passes 50 players")

	# Test threshold 65 (expect players 65-99 = 35 players)
	var hs_cfg_65 := {"recruiting": {"college_eligibility_threshold": 65.0}}
	var eligible_65 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg_65)
	t.assert_eq(eligible_65.size(), 35, "threshold 65 passes 35 players")

func test_filter_all_pass_threshold_zero(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 0.0
		}
	}

	var graduates := [
		{"player_id": "p1", "composite_score": 10.0},
		{"player_id": "p2", "composite_score": 20.0},
		{"player_id": "p3", "composite_score": 30.0},
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	t.assert_eq(eligible.size(), 3, "threshold 0 allows all players through (backward compatible)")

func test_filter_none_pass_threshold_high(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 100.0
		}
	}

	var graduates := [
		{"player_id": "p1", "composite_score": 85.0},
		{"player_id": "p2", "composite_score": 90.0},
		{"player_id": "p3", "composite_score": 95.0},
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	t.assert_eq(eligible.size(), 0, "threshold 100 blocks all players under 100")

func test_filter_determinism(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 45.0
		}
	}

	var graduates := [
		{"player_id": "p1", "composite_score": 50.0},
		{"player_id": "p2", "composite_score": 40.0},
		{"player_id": "p3", "composite_score": 60.0},
		{"player_id": "p4", "composite_score": 30.0},
		{"player_id": "p5", "composite_score": 45.0},
	]

	# Run filter multiple times
	var eligible_1 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	var eligible_2 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	var eligible_3 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	# All runs should produce identical results
	t.assert_eq(eligible_1.size(), eligible_2.size(), "filter is deterministic (size match 1-2)")
	t.assert_eq(eligible_2.size(), eligible_3.size(), "filter is deterministic (size match 2-3)")
	t.assert_eq(eligible_1.size(), 3, "filter produces correct count")

	# Check that the same players pass every time
	for i in range(eligible_1.size()):
		var p1: Dictionary = eligible_1[i]
		var p2: Dictionary = eligible_2[i]
		var p3: Dictionary = eligible_3[i]
		t.assert_eq(p1.get("player_id", ""), p2.get("player_id", ""), "same player at index %d run 1-2" % i)
		t.assert_eq(p2.get("player_id", ""), p3.get("player_id", ""), "same player at index %d run 2-3" % i)

func test_filter_preserves_player_data(t) -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 40.0
		}
	}

	var graduates := [
		{
			"player_id": "p1",
			"name": "John Doe",
			"position": "QB",
			"composite_score": 50.0,
			"home_region": "south",
			"stats": {"speed": 70.0}
		}
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	t.assert_eq(eligible.size(), 1, "filter passes eligible player")

	var player: Dictionary = eligible[0]
	t.assert_eq(player.get("player_id", ""), "p1", "filter preserves player_id")
	t.assert_eq(player.get("name", ""), "John Doe", "filter preserves name")
	t.assert_eq(player.get("position", ""), "QB", "filter preserves position")
	t.assert_eq(player.get("composite_score", 0.0), 50.0, "filter preserves composite_score")
	t.assert_eq(player.get("home_region", ""), "south", "filter preserves home_region")

	var stats: Dictionary = player.get("stats", {})
	t.assert_eq(stats.get("speed", 0.0), 70.0, "filter preserves nested stats")

func test_filter_with_mixed_ratings(t) -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["speed", "awareness"]}
	}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 50.0
		}
	}

	var graduates := [
		{"player_id": "p1", "composite_score": 60.0},  # Uses composite_score
		{"player_id": "p2", "core_avg": 55.0},  # Uses core_avg
		{
			"player_id": "p3",
			"position": "QB",
			"stats": {"speed": 50.0, "awareness": 50.0}  # Calculates: (50+50)/2 = 50
		},
		{"player_id": "p4", "composite_score": 45.0},  # Fails
		{"player_id": "p5", "core_avg": 40.0},  # Fails
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	t.assert_eq(eligible.size(), 3, "filter handles mixed rating types correctly")

	var ids := []
	for p in eligible:
		var player: Dictionary = p
		ids.append(player.get("player_id", ""))

	t.assert_true("p1" in ids, "player with composite_score 60 passes")
	t.assert_true("p2" in ids, "player with core_avg 55 passes")
	t.assert_true("p3" in ids, "player with calculated rating 50 passes")
	t.assert_true(not ("p4" in ids), "player with composite_score 45 fails")
	t.assert_true(not ("p5" in ids), "player with core_avg 40 fails")
