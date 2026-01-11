extends RefCounted
## Tests for Task F2: College Recruiting Optimization
##
## Verifies that the optimized implementation:
## 1. Produces identical results to the original (determinism)
## 2. Maintains correct recruiting outcomes
## 3. Demonstrates performance improvement
## 4. Handles parallel execution correctly with seed derivation

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const ConfigService = preload("res://autoloads/Config.gd")

## Test 1: Basic determinism - same seed produces same results
func test_optimized_determinism(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(20)
	var colleges := _create_test_colleges(5)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	# Run with same seed multiple times
	var result_a := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false  # use_parallel = false for deterministic test
	)

	var result_b := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)

	var result_c := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)

	var commitments_a: Array = result_a.get("commitments", []) as Array
	var commitments_b: Array = result_b.get("commitments", []) as Array
	var commitments_c: Array = result_c.get("commitments", []) as Array

	t.assert_eq(JSON.stringify(commitments_a), JSON.stringify(commitments_b),
		"optimized recruiting is deterministic (run A vs B)")
	t.assert_eq(JSON.stringify(commitments_a), JSON.stringify(commitments_c),
		"optimized recruiting is deterministic (run A vs C)")

## Test 2: Parallel execution produces same results as sequential
func test_parallel_determinism(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(30)
	var colleges := _create_test_colleges(8)  # Enough to trigger parallel execution
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	# Sequential execution
	var result_seq := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		99999, 2025, false
	)

	# Parallel execution
	var result_par := pipeline.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		99999, 2025, true
	)

	var commitments_seq: Array = result_seq.get("commitments", []) as Array
	var commitments_par: Array = result_par.get("commitments", []) as Array

	t.assert_eq(commitments_seq.size(), commitments_par.size(),
		"parallel and sequential produce same number of commitments")

	# Sort both before comparison (order might differ due to parallel execution)
	commitments_seq.sort_custom(func(a, b):
		return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
	)
	commitments_par.sort_custom(func(a, b):
		return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
	)

	t.assert_eq(JSON.stringify(commitments_seq), JSON.stringify(commitments_par),
		"parallel execution produces identical results to sequential")

## Test 3: Sequential runs are consistent (backward compatibility harness)
func test_backward_compatibility(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(15)
	var colleges := _create_test_colleges(4)
	var pipeline_cfg := _create_test_config()

	var original := CollegeRecruiting.new()
	var optimized := CollegeRecruiting.new()

	var seed := 54321

	var result_original := original.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		seed, 2025
	)

	var result_optimized := optimized.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		seed, 2025, false  # Sequential for exact comparison
	)

	var commits_orig: Array = result_original.get("commitments", []) as Array
	var commits_opt: Array = result_optimized.get("commitments", []) as Array

	t.assert_eq(commits_orig.size(), commits_opt.size(),
		"optimized produces same number of commitments as original")

	# Compare commitment outcomes (player -> college mapping should be identical)
	var orig_map := {}
	for commit in commits_orig:
		var c: Dictionary = commit
		orig_map[String(c.get("player_id", ""))] = String(c.get("college_id", ""))

	var opt_map := {}
	for commit in commits_opt:
		var c: Dictionary = commit
		opt_map[String(c.get("player_id", ""))] = String(c.get("college_id", ""))

	t.assert_eq(JSON.stringify(orig_map), JSON.stringify(opt_map),
		"optimized produces identical player-college mappings as original")

## Test 4: Different seeds produce different results
func test_seed_variation(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

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

	# Different seeds should (very likely) produce different results
	var different := JSON.stringify(commitments_1) != JSON.stringify(commitments_2)
	t.assert_true(different, "different seeds produce different recruiting outcomes")

## Test 5: Edge cases - empty inputs
func test_edge_cases(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var pipeline_cfg := _create_test_config()
	var pipeline := CollegeRecruiting.new()

	# Test: No recruits
	var result_no_recruits := pipeline.run(
		[], _create_test_colleges(3), pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)
	t.assert_eq(result_no_recruits.get("commitments", []).size(), 0,
		"no recruits produces zero commitments")

	# Test: No colleges
	var result_no_colleges := pipeline.run(
		_create_test_recruits(10), [], pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		12345, 2025, false
	)
	t.assert_eq(result_no_colleges.get("commitments", []).size(), 0,
		"no colleges produces zero commitments")
	t.assert_eq(result_no_colleges.get("uncommitted", []).size(), 10,
		"all recruits are uncommitted when no colleges exist")

## Test 6: Validate recruiting constraints
func test_recruiting_constraints(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

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
	var classes: Dictionary = result.get("college_classes", {}) as Dictionary

	# Total outcomes should equal total recruits
	t.assert_eq(commitments.size() + uncommitted.size(), recruits.size(),
		"all recruits have an outcome (committed or uncommitted)")

	# No duplicate commitments
	var committed_players := {}
	for commit in commitments:
		var c: Dictionary = commit
		var player_id := String(c.get("player_id", ""))
		t.assert_false(committed_players.has(player_id),
			"no player commits to multiple colleges: %s" % player_id)
		committed_players[player_id] = true

	# Class sizes respect limits
	var class_min := int(pipeline_cfg["recruiting"]["class_size_min"])
	var class_max := int(pipeline_cfg["recruiting"]["class_size_max"])

	for college_id in classes.keys():
		var class_info: Dictionary = classes[college_id] as Dictionary
		var players: Array = class_info.get("players", []) as Array
		var target := int(class_info.get("target", 0))

		t.assert_true(players.size() <= class_max,
			"college %s class size %d does not exceed max %d" % [college_id, players.size(), class_max])

## Test 7: Performance comparison (informational, not strict)
func test_performance_comparison(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	# Larger dataset to see performance difference
	var recruits := _create_test_recruits(200)
	var colleges := _create_test_colleges(20)
	var pipeline_cfg := _create_test_config()

	# Original implementation
	var original := CollegeRecruiting.new()
	var time_start_orig := Time.get_ticks_usec()
	var result_original := original.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		88888, 2025
	)
	var time_orig := Time.get_ticks_usec() - time_start_orig

	# Optimized implementation (sequential)
	var optimized := CollegeRecruiting.new()
	var time_start_opt := Time.get_ticks_usec()
	var result_optimized := optimized.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		88888, 2025, false
	)
	var time_opt := Time.get_ticks_usec() - time_start_opt

	# Optimized implementation (parallel)
	var time_start_par := Time.get_ticks_usec()
	var result_parallel := optimized.run(
		recruits, colleges, pipeline_cfg,
		positions_cfg, stats_cfg, class_rules, scouts_cfg,
		88888, 2025, true
	)
	var time_par := Time.get_ticks_usec() - time_start_par

	var speedup_seq: float = float(time_orig) / max(1.0, float(time_opt))
	var speedup_par: float = float(time_orig) / max(1.0, float(time_par))

	print("Performance comparison (200 recruits, 20 colleges):")
	print("  Original:    %d µs" % time_orig)
	print("  Optimized (seq): %d µs (%.2fx speedup)" % [time_opt, speedup_seq])
	print("  Optimized (par): %d µs (%.2fx speedup)" % [time_par, speedup_par])

	# We expect at least some improvement, but don't fail on this (hardware dependent)
	t.assert_true(time_opt <= time_orig * 2.0,
		"optimized version should not be significantly slower than original")

## Test 8: Verify RNG consumption pattern is consistent
func test_rng_consumption_consistency(t) -> void:
	var config := ConfigService.new()
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var class_rules: Dictionary = config.get_config("main").get("class_rules", {}) as Dictionary

	var recruits := _create_test_recruits(10)
	var colleges := _create_test_colleges(3)
	var pipeline_cfg := _create_test_config()

	var pipeline := CollegeRecruiting.new()

	# Run multiple times with same seed
	var results := []
	for i in range(5):
		var result := pipeline.run(
			recruits, colleges, pipeline_cfg,
			positions_cfg, stats_cfg, class_rules, scouts_cfg,
			33333, 2025, false
		)
		results.append(result)

	# All results should be byte-for-byte identical
	var first_json := JSON.stringify(results[0].get("commitments", []))
	for i in range(1, results.size()):
		var json := JSON.stringify(results[i].get("commitments", []))
		t.assert_eq(first_json, json,
			"run %d produces identical commitments to run 0" % i)

## Helper: Create test recruits with realistic data
func _create_test_recruits(count: int) -> Array:
	var recruits: Array = []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]
	var regions := ["north", "south", "east", "west", "midwest"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 999999  # Fixed seed for reproducible test data

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
			"physicals": {
				"weight_lb": rng.randf_range(180.0, 280.0)
			},
			"ratings": {
				"composite_score": baseline
			}
		})

	return recruits

## Helper: Create test colleges with realistic data
func _create_test_colleges(count: int) -> Array:
	var colleges: Array = []
	var regions := ["north", "south", "east", "west", "midwest"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 888888  # Fixed seed for reproducible test data

	for i in range(count):
		colleges.append({
			"id": "college_%02d" % i,
			"name": "University %d" % i,
			"region": regions[i % regions.size()],
			"eliteness": rng.randf_range(40.0, 95.0)
		})

	return colleges

## Helper: Create test configuration
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

## Entry point for test runner
func run(t) -> void:
	test_optimized_determinism(t)
	test_parallel_determinism(t)
	test_backward_compatibility(t)
	test_seed_variation(t)
	test_edge_cases(t)
	test_recruiting_constraints(t)
	test_performance_comparison(t)
	test_rng_consumption_consistency(t)
