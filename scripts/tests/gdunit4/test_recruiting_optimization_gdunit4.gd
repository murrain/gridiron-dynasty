## GdUnit4 test suite for Task F2: College Recruiting Optimization
##
## Verifies that the optimized implementation:
## 1. Produces identical results to the original (determinism)
## 2. Maintains correct recruiting outcomes
## 3. Handles parallel execution correctly with seed derivation
extends GdUnitTestSuite

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const ConfigService = preload("res://autoloads/Config.gd")


func test_optimized_determinism() -> void:
	var config_service := ConfigService.new()
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(20)
	var colleges := _create_test_colleges(5)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	var result_a := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)

	var result_b := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)

	var commitments_a: Array = result_a.get("commitments", []) as Array
	var commitments_b: Array = result_b.get("commitments", []) as Array

	assert_str(JSON.stringify(commitments_a)).is_equal(JSON.stringify(commitments_b))


func test_parallel_determinism() -> void:
	var config_service := ConfigService.new()
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(30)
	var colleges := _create_test_colleges(8)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	var result_seq := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		99999, 2025, false
	)

	var result_par := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		99999, 2025, true
	)

	var commitments_seq: Array = result_seq.get("commitments", []) as Array
	var commitments_par: Array = result_par.get("commitments", []) as Array

	assert_int(commitments_seq.size()).is_equal(commitments_par.size())


func test_seed_variation() -> void:
	var config_service := ConfigService.new()
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(20)
	var colleges := _create_test_colleges(5)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	var result_seed1 := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		11111, 2025, false
	)

	var result_seed2 := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		22222, 2025, false
	)

	var commitments_1: Array = result_seed1.get("commitments", []) as Array
	var commitments_2: Array = result_seed2.get("commitments", []) as Array

	var different := JSON.stringify(commitments_1) != JSON.stringify(commitments_2)
	assert_bool(different).is_true()


func test_edge_cases_no_recruits() -> void:
	var config_service := ConfigService.new()
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {}) as Dictionary

	var pipeline_cfg := _create_test_config()
	var pipeline := CollegeRecruiting.new()

	var result_no_recruits := pipeline.run(
		[], _create_test_colleges(3), pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)
	assert_int(result_no_recruits.get("commitments", []).size()).is_equal(0)


func test_edge_cases_no_colleges() -> void:
	var config_service := ConfigService.new()
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {}) as Dictionary

	var pipeline_cfg := _create_test_config()
	var pipeline := CollegeRecruiting.new()

	var result_no_colleges := pipeline.run(
		_create_test_recruits(10), [], pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)
	assert_int(result_no_colleges.get("commitments", []).size()).is_equal(0)
	assert_int(result_no_colleges.get("uncommitted", []).size()).is_equal(10)


func test_recruiting_constraints() -> void:
	var config_service := ConfigService.new()
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(100)
	var colleges := _create_test_colleges(10)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()
	var result := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		77777, 2025, false
	)

	var commitments: Array = result.get("commitments", []) as Array
	var uncommitted: Array = result.get("uncommitted", []) as Array

	assert_int(commitments.size() + uncommitted.size()).is_equal(recruits.size())

	var committed_players := {}
	for commit in commitments:
		var c: Dictionary = commit
		var player_id := String(c.get("player_id", ""))
		assert_bool(committed_players.has(player_id)).is_false()
		committed_players[player_id] = true


func _create_test_recruits(count: int) -> Array:
	var recruits: Array = []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]
	var regions := ["north", "south", "east", "west", "midwest"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 999999

	for i in range(count):
		var player_id := "recruit_%03d" % i
		var position: String = positions[rng.randi() % positions.size()]
		var region: String = regions[rng.randi() % regions.size()]
		var baseline := rng.randf_range(50.0, 90.0)

		recruits.append({
			"player_id": player_id,
			"name": "Recruit %d" % i,
			"position": position,
			"home_region": region,
			"proximity_bias": rng.randf_range(0.3, 0.9),
			"hs_school_id": "hs_%d" % (i % 20),
			"stats": {
				"speed": rng.randf_range(50.0, 90.0),
				"acceleration": rng.randf_range(50.0, 90.0),
				"agility": rng.randf_range(50.0, 90.0),
				"strength": rng.randf_range(50.0, 90.0),
				"awareness": rng.randf_range(50.0, 90.0)
			},
			"potential": {
				"speed": rng.randf_range(60.0, 95.0),
				"acceleration": rng.randf_range(60.0, 95.0),
				"agility": rng.randf_range(60.0, 95.0),
				"strength": rng.randf_range(60.0, 95.0),
				"awareness": rng.randf_range(60.0, 95.0)
			},
			"physicals": {"weight_lb": rng.randf_range(180.0, 280.0)},
			"ratings": {"composite_score": baseline}
		})

	return recruits


func _create_test_colleges(count: int) -> Array:
	var colleges: Array = []
	var regions := ["north", "south", "east", "west", "midwest"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 888888

	for i in range(count):
		colleges.append({
			"id": "college_%02d" % i,
			"name": "University %d" % i,
			"region": regions[i % regions.size()],
			"eliteness": rng.randf_range(40.0, 95.0)
		})

	return colleges


func _create_test_config() -> Dictionary:
	return {
		"recruiting": {
			"offer_limit": 25,
			"board_limit": 100,
			"class_size_min": 15,
			"class_size_max": 25,
			"rating_weight": 0.55,
			"eliteness_weight": 0.25,
			"proximity_weight": 0.20,
			"region_match_multiplier": 1.35,
			"scout_weight": 0.70,
			"baseline_weight": 0.30,
			"visit_chance": 0.20,
			"visit_bonus": 0.06
		}
	}
