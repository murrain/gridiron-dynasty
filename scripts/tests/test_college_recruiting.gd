extends RefCounted

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := [
		_make_recruit("p1", "QB", "north", 0.8, 88.0),
		_make_recruit("p2", "WR", "south", 0.5, 82.0),
		_make_recruit("p3", "LB", "north", 0.6, 76.0),
		_make_recruit("p4", "CB", "west", 0.4, 70.0)
	]

	var colleges := [
		{"id": "c1", "name": "North Tech", "region": "north", "eliteness": 80.0},
		{"id": "c2", "name": "South State", "region": "south", "eliteness": 65.0}
	]

	var pipeline_cfg := {
		"recruiting": {
			"offer_limit": 3,
			"board_limit": 10,
			"class_size_min": 1,
			"class_size_max": 2,
			"rating_weight": 0.55,
			"eliteness_weight": 0.25,
			"proximity_weight": 0.20,
			"region_match_multiplier": 1.35,
			"scout_weight": 0.7,
			"baseline_weight": 0.3,
			"visit_chance": 0.0,
			"visit_bonus": 0.06
		}
	}

	var pipeline := CollegeRecruiting.new()
	var result_a := pipeline.run(
		recruits,
		colleges,
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		1234,
		2025
	)

	var result_b := pipeline.run(
		recruits,
		colleges,
		pipeline_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		1234,
		2025
	)

	var commitments_a: Array = result_a.get("commitments", []) as Array
	var commitments_b: Array = result_b.get("commitments", []) as Array
	var uncommitted_a: Array = result_a.get("uncommitted", []) as Array

	t.assert_true(commitments_a.size() <= recruits.size(), "commitments do not exceed recruits")
	t.assert_eq(commitments_a.size() + uncommitted_a.size(), recruits.size(), "recruit outcomes cover class")
	t.assert_eq(JSON.stringify(commitments_a), JSON.stringify(commitments_b), "recruiting is deterministic")

	for commit in commitments_a:
		var entry: Dictionary = commit
		t.assert_true(entry.has("player_id"), "commitment includes player_id")
		t.assert_true(entry.has("college_id"), "commitment includes college_id")

func _make_recruit(player_id: String, pos: String, region: String, bias: float, composite: float) -> Dictionary:
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"home_region": region,
		"proximity_bias": bias,
		"hs_school_id": "",
		"stats": {"speed": 70.0, "acceleration": 65.0, "agility": 68.0},
		"potential": {"speed": 75.0, "acceleration": 70.0, "agility": 72.0},
		"physicals": {"weight_lb": 205.0},
		"ratings": {"composite_score": composite}
	}
