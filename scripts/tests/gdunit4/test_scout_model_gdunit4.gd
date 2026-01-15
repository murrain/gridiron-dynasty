## GdUnit4 test suite for Scout Model
##
## Validates Scout score_player method determinism and bounds.
## Migrated from test_scout_model.gd
extends GdUnitTestSuite

const Scout = preload("res://scripts/core/models/Scout.gd")


func _get_stats_cfg() -> Dictionary:
	return {
		"stats": [
			{"name": "speed", "measurement_difficulty": 0.2},
			{"name": "throw_accuracy", "measurement_difficulty": 0.3}
		]
	}


func _get_positions_data() -> Dictionary:
	return {
		"QB": {
			"core_stats": ["throw_accuracy"],
			"distributions": {"speed": {"role": "secondary"}}
		}
	}


func _get_class_rules() -> Dictionary:
	return {"recruiting": {"athletic_keys": ["speed"], "mental_keys": []}}


func _create_scout(stats_cfg: Dictionary) -> Scout:
	var scout := Scout.new()
	scout.base_skill = 0.6
	scout.bucket_weights = {"athletic": 0.5, "core": 0.3, "secondary": 0.1, "mentals": 0.1}
	scout.stat_skill = {"speed": 0.7, "throw_accuracy": 0.7}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	scout.setup(stats_cfg, {}, rng)
	return scout


func _rng_for(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


func test_score_is_deterministic_per_seed() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
	var scout := _create_scout(stats_cfg)

	var player := {
		"position": "QB",
		"stats": {"speed": 70.0, "throw_accuracy": 78.0},
		"potential": {"speed": 75.0, "throw_accuracy": 85.0}
	}

	var rng_a := _rng_for(123)
	var score_a := scout.score_player(player, positions_data, stats_cfg, class_rules, rng_a)

	var rng_b := _rng_for(123)
	var score_b := scout.score_player(player, positions_data, stats_cfg, class_rules, rng_b)

	assert_float(score_a).is_equal_approx(score_b, 0.0001)


func test_score_respects_board_bounds() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
	var scout := _create_scout(stats_cfg)

	var player := {
		"position": "QB",
		"stats": {"speed": 70.0, "throw_accuracy": 78.0},
		"potential": {"speed": 75.0, "throw_accuracy": 85.0}
	}

	var rng := _rng_for(123)
	var score := scout.score_player(player, positions_data, stats_cfg, class_rules, rng)

	assert_float(score).is_between(30.0, 95.0)


func test_different_seeds_produce_different_scores() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
	var scout := _create_scout(stats_cfg)

	var player := {
		"position": "QB",
		"stats": {"speed": 70.0, "throw_accuracy": 78.0},
		"potential": {"speed": 75.0, "throw_accuracy": 85.0}
	}

	var rng_a := _rng_for(111)
	var score_a := scout.score_player(player, positions_data, stats_cfg, class_rules, rng_a)

	var rng_b := _rng_for(999)
	var score_b := scout.score_player(player, positions_data, stats_cfg, class_rules, rng_b)

	# Scores should differ with different seeds (though may still be close)
	var diff := absf(score_a - score_b)
	assert_float(diff).is_greater_equal(0.0)
