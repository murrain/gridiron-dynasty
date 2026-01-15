## GdUnit4 test suite for college eligibility filtering
##
## Validates college eligibility filter logic including rating calculations,
## thresholds, and determinism.
## Migrated from test_college_eligibility_filter.gd
extends GdUnitTestSuite

const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")


func test_calculate_overall_rating_uses_composite_score() -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["speed", "awareness", "throw_power"]},
		"RB": {"core_stats": ["speed", "agility", "strength"]}
	}
	var class_rules := {}

	var player := {
		"composite_score": 85.0,
		"core_avg": 70.0,
		"stats": {"speed": 60.0}
	}

	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
	assert_float(rating).is_equal(85.0)


func test_calculate_overall_rating_uses_core_avg_fallback() -> void:
	var positions_cfg := {}
	var class_rules := {}

	var player := {
		"core_avg": 75.0,
		"stats": {"speed": 60.0}
	}

	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
	assert_float(rating).is_equal(75.0)


func test_calculate_overall_rating_computes_core_stats_avg() -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["speed", "awareness", "throw_power"]}
	}
	var class_rules := {}

	var player := {
		"position": "QB",
		"stats": {
			"speed": 70.0,
			"awareness": 80.0,
			"throw_power": 75.0,
			"other_stat": 50.0
		}
	}

	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
	var expected := (70.0 + 80.0 + 75.0) / 3.0
	assert_float(rating).is_equal(expected)


func test_calculate_overall_rating_unknown_position_fallback() -> void:
	var positions_cfg := {}
	var class_rules := {}

	var player := {
		"position": "UNKNOWN",
		"stats": {
			"speed": 60.0,
			"strength": 80.0
		}
	}

	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
	var expected := (60.0 + 80.0) / 2.0
	assert_float(rating).is_equal(expected)


func test_calculate_overall_rating_empty_stats() -> void:
	var positions_cfg := {}
	var class_rules := {}

	var player := {
		"position": "UNKNOWN",
		"stats": {}
	}

	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
	assert_float(rating).is_equal(0.0)


func test_filter_college_eligible_with_composite_score() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 40.0}}

	var graduates := [
		{"player_id": "p1", "composite_score": 50.0},
		{"player_id": "p2", "composite_score": 35.0},
		{"player_id": "p3", "composite_score": 40.0},
		{"player_id": "p4", "composite_score": 65.0},
		{"player_id": "p5", "composite_score": 25.0}
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	assert_int(eligible.size()).is_equal(3)


func test_filter_college_eligible_with_core_avg() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 50.0}}

	var graduates := [
		{"player_id": "p1", "core_avg": 55.0},
		{"player_id": "p2", "core_avg": 45.0},
		{"player_id": "p3", "core_avg": 50.0}
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	assert_int(eligible.size()).is_equal(2)


func test_filter_college_eligible_threshold_30() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 30.0}}

	var graduates := []
	for i in range(100):
		graduates.append({"player_id": "p%d" % i, "composite_score": float(i)})

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	assert_int(eligible.size()).is_equal(70)


func test_filter_college_eligible_threshold_50() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 50.0}}

	var graduates := []
	for i in range(100):
		graduates.append({"player_id": "p%d" % i, "composite_score": float(i)})

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	assert_int(eligible.size()).is_equal(50)


func test_filter_all_pass_threshold_zero() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 0.0}}

	var graduates := [
		{"player_id": "p1", "composite_score": 10.0},
		{"player_id": "p2", "composite_score": 20.0},
		{"player_id": "p3", "composite_score": 30.0}
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	assert_int(eligible.size()).is_equal(3)


func test_filter_none_pass_threshold_high() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 100.0}}

	var graduates := [
		{"player_id": "p1", "composite_score": 85.0},
		{"player_id": "p2", "composite_score": 90.0},
		{"player_id": "p3", "composite_score": 95.0}
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	assert_int(eligible.size()).is_equal(0)


func test_filter_determinism() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 45.0}}

	var graduates := [
		{"player_id": "p1", "composite_score": 50.0},
		{"player_id": "p2", "composite_score": 40.0},
		{"player_id": "p3", "composite_score": 60.0},
		{"player_id": "p4", "composite_score": 30.0},
		{"player_id": "p5", "composite_score": 45.0}
	]

	var eligible_1 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	var eligible_2 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	var eligible_3 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	assert_int(eligible_1.size()).is_equal(eligible_2.size())
	assert_int(eligible_2.size()).is_equal(eligible_3.size())
	assert_int(eligible_1.size()).is_equal(3)


func test_filter_preserves_player_data() -> void:
	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 40.0}}

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

	assert_int(eligible.size()).is_equal(1)

	var player: Dictionary = eligible[0]
	assert_str(String(player.get("player_id", ""))).is_equal("p1")
	assert_str(String(player.get("name", ""))).is_equal("John Doe")
	assert_str(String(player.get("position", ""))).is_equal("QB")
	assert_float(float(player.get("composite_score", 0.0))).is_equal(50.0)
	assert_str(String(player.get("home_region", ""))).is_equal("south")

	var stats: Dictionary = player.get("stats", {})
	assert_float(float(stats.get("speed", 0.0))).is_equal(70.0)


func test_filter_with_mixed_ratings() -> void:
	var positions_cfg := {"QB": {"core_stats": ["speed", "awareness"]}}
	var main_cfg := {}
	var hs_cfg := {"recruiting": {"college_eligibility_threshold": 50.0}}

	var graduates := [
		{"player_id": "p1", "composite_score": 60.0},
		{"player_id": "p2", "core_avg": 55.0},
		{"player_id": "p3", "position": "QB", "stats": {"speed": 50.0, "awareness": 50.0}},
		{"player_id": "p4", "composite_score": 45.0},
		{"player_id": "p5", "core_avg": 40.0}
	]

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	assert_int(eligible.size()).is_equal(3)
