## GdUnit4 test suite for CollegeRecruiting
##
## Validates recruiting determinism, commitment outcomes, and data structure.
## Migrated from test_college_recruiting.gd
extends GdUnitTestSuite

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const ConfigService = preload("res://autoloads/Config.gd")


var _positions_cfg: Dictionary
var _stats_cfg: Dictionary
var _scouts_cfg: Dictionary
var _class_rules: Dictionary
var _pipeline_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_positions_cfg = config.get_config("positions")
	_stats_cfg = config.get_config("stats")
	_scouts_cfg = config.get_config("scouts")
	_class_rules = config.get_config("main").get("class_rules", {}) as Dictionary

	_pipeline_cfg = {
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


func test_commitments_do_not_exceed_recruits() -> void:
	var recruits := _make_test_recruits()
	var colleges := _make_test_colleges()
	var pipeline := CollegeRecruiting.new()

	var result := pipeline.run(
		recruits, colleges, _pipeline_cfg,
		_positions_cfg, _stats_cfg, _class_rules, _scouts_cfg, 1234, 2025
	)

	var commitments: Array = result.get("commitments", []) as Array
	assert_int(commitments.size()).is_less_equal(recruits.size())


func test_recruit_outcomes_cover_entire_class() -> void:
	var recruits := _make_test_recruits()
	var colleges := _make_test_colleges()
	var pipeline := CollegeRecruiting.new()

	var result := pipeline.run(
		recruits, colleges, _pipeline_cfg,
		_positions_cfg, _stats_cfg, _class_rules, _scouts_cfg, 1234, 2025
	)

	var commitments: Array = result.get("commitments", []) as Array
	var uncommitted: Array = result.get("uncommitted", []) as Array
	assert_int(commitments.size() + uncommitted.size()).is_equal(recruits.size())


func test_recruiting_is_deterministic() -> void:
	var recruits := _make_test_recruits()
	var colleges := _make_test_colleges()
	var pipeline := CollegeRecruiting.new()

	var result_a := pipeline.run(
		recruits, colleges, _pipeline_cfg,
		_positions_cfg, _stats_cfg, _class_rules, _scouts_cfg, 1234, 2025
	)
	var result_b := pipeline.run(
		recruits, colleges, _pipeline_cfg,
		_positions_cfg, _stats_cfg, _class_rules, _scouts_cfg, 1234, 2025
	)

	var commitments_a: Array = result_a.get("commitments", []) as Array
	var commitments_b: Array = result_b.get("commitments", []) as Array

	assert_str(JSON.stringify(commitments_a)).is_equal(JSON.stringify(commitments_b))


func test_commitment_includes_player_id() -> void:
	var recruits := _make_test_recruits()
	var colleges := _make_test_colleges()
	var pipeline := CollegeRecruiting.new()

	var result := pipeline.run(
		recruits, colleges, _pipeline_cfg,
		_positions_cfg, _stats_cfg, _class_rules, _scouts_cfg, 1234, 2025
	)

	var commitments: Array = result.get("commitments", []) as Array
	for commit in commitments:
		var entry: Dictionary = commit
		assert_bool(entry.has("player_id")).is_true()


func test_commitment_includes_college_id() -> void:
	var recruits := _make_test_recruits()
	var colleges := _make_test_colleges()
	var pipeline := CollegeRecruiting.new()

	var result := pipeline.run(
		recruits, colleges, _pipeline_cfg,
		_positions_cfg, _stats_cfg, _class_rules, _scouts_cfg, 1234, 2025
	)

	var commitments: Array = result.get("commitments", []) as Array
	for commit in commitments:
		var entry: Dictionary = commit
		assert_bool(entry.has("college_id")).is_true()


# --- Helper functions ---

func _make_test_recruits() -> Array:
	return [
		_make_recruit("p1", "QB", "north", 0.8, 88.0),
		_make_recruit("p2", "WR", "south", 0.5, 82.0),
		_make_recruit("p3", "LB", "north", 0.6, 76.0),
		_make_recruit("p4", "CB", "west", 0.4, 70.0)
	]


func _make_test_colleges() -> Array:
	return [
		{"id": "c1", "name": "North Tech", "region": "north", "eliteness": 80.0},
		{"id": "c2", "name": "South State", "region": "south", "eliteness": 65.0}
	]


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
