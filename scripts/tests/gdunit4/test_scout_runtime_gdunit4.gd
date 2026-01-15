## GdUnit4 POC Test 3: Performance Test
##
## Validates ScoutRuntime scoring performance and determinism.
## Demonstrates GdUnit4 patterns for performance testing with assert_max_time.
## Migrated from test_scout_runtime.gd.
##
## POC Category: Performance Test
extends GdUnitTestSuite

const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


var _stats_cfg: Dictionary
var _positions_data: Dictionary
var _class_rules: Dictionary
var _scout: Dictionary
var _player: Dictionary


func before() -> void:
	# Setup test fixtures once before all tests
	_stats_cfg = {
		"stats": [
			{"name": "throw_accuracy", "measurement_difficulty": 0.2},
			{"name": "throw_power", "measurement_difficulty": 0.2},
			{"name": "speed", "measurement_difficulty": 0.1}
		]
	}

	_positions_data = {
		"QB": {
			"core_stats": ["throw_accuracy"],
			"distributions": {"throw_power": {"role": "secondary"}}
		}
	}

	_class_rules = {
		"recruiting": {
			"athletic_keys": ["speed"],
			"mental_keys": []
		}
	}

	_scout = {
		"base_skill": 0.35,
		"tape_grinder": 0.2,
		"risk_aversion": 0.1,
		"stat_skill": {"throw_accuracy": 0.4, "throw_power": 0.35, "speed": 0.3},
		"estimation_multipliers": {},
		"valuation_multipliers": {}
	}

	_player = {
		"position": "QB",
		"stats": {"throw_accuracy": 70.0, "throw_power": 66.0, "speed": 62.0},
		"potential": {"throw_accuracy": 78.0, "throw_power": 72.0, "speed": 68.0}
	}


func test_scout_runtime_scoring_is_deterministic() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var score_a := ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345
	var score_b := ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng_b)

	assert_float(score_a).is_equal_approx(score_b, 0.0001)


func test_scout_runtime_score_within_composite_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var score := ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng)

	assert_float(score).is_between(30.0, 92.0)


func test_scout_runtime_using_assert_deterministic() -> void:
	# Demonstrate the TestHelpersGdUnit4.assert_deterministic pattern
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng): return ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng),
		54321,
		"ScoutRuntime.score_player is deterministic"
	)


func test_scout_runtime_performance_single_evaluation() -> void:
	# Test that a single scout evaluation completes in reasonable time
	TestHelpersGdUnit4.assert_max_time(
		self,
		func():
			var rng := RandomNumberGenerator.new()
			rng.seed = 99999
			ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng),
		50.0,  # Should complete in under 50ms
		"Single scout evaluation completes quickly"
	)


func test_scout_runtime_performance_batch_evaluations() -> void:
	# Test that batch scout evaluations complete in acceptable time
	# This simulates evaluating a recruiting class
	var batch_size := 100

	TestHelpersGdUnit4.assert_max_time(
		self,
		func():
			var rng := RandomNumberGenerator.new()
			rng.seed = 77777
			for i in range(batch_size):
				ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng),
		500.0,  # 100 evaluations should complete in under 500ms
		"Batch of %d scout evaluations completes within performance budget" % batch_size
	)


func test_scout_score_varies_with_different_seeds() -> void:
	var scores: Array = []
	for seed_value in [111, 222, 333, 444, 555]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var score := ScoutRuntime.score_player(_scout, _player, _positions_data, _stats_cfg, _class_rules, rng)
		scores.append(score)

	# Not all scores should be identical (scout evaluation has randomness)
	var all_same := true
	for i in range(1, scores.size()):
		if abs(scores[i] - scores[0]) > 0.0001:
			all_same = false
			break

	assert_bool(all_same).is_false()


func test_different_scouts_produce_different_scores() -> void:
	var scout_low_skill := {
		"base_skill": 0.2,
		"tape_grinder": 0.1,
		"risk_aversion": 0.1,
		"stat_skill": {"throw_accuracy": 0.2, "throw_power": 0.2, "speed": 0.2},
		"estimation_multipliers": {},
		"valuation_multipliers": {}
	}

	var scout_high_skill := {
		"base_skill": 0.8,
		"tape_grinder": 0.5,
		"risk_aversion": 0.1,
		"stat_skill": {"throw_accuracy": 0.8, "throw_power": 0.8, "speed": 0.8},
		"estimation_multipliers": {},
		"valuation_multipliers": {}
	}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var score_low := ScoutRuntime.score_player(scout_low_skill, _player, _positions_data, _stats_cfg, _class_rules, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var score_high := ScoutRuntime.score_player(scout_high_skill, _player, _positions_data, _stats_cfg, _class_rules, rng2)

	# Different scouts with same seed should produce different scores
	# (due to different skill levels affecting the evaluation)
	assert_float(score_low).is_not_equal(score_high)
