extends RefCounted

const Scout = preload("res://scripts/core/models/Scout.gd")

func run(t) -> void:
	var stats_cfg := {
		"stats": [
			{"name": "speed", "measurement_difficulty": 0.2},
			{"name": "throw_accuracy", "measurement_difficulty": 0.3}
		]
	}
	var positions_data := {
		"QB": {
			"core_stats": ["throw_accuracy"],
			"distributions": {"speed": {"role": "secondary"}}
		}
	}
	var class_rules := {"recruiting": {"athletic_keys": ["speed"], "mental_keys": []}}

	var scout: Scout = Scout.new()
	scout.base_skill = 0.6
	scout.bucket_weights = {"athletic": 0.5, "core": 0.3, "secondary": 0.1, "mentals": 0.1}
	scout.stat_skill = {"speed": 0.7, "throw_accuracy": 0.7}
	scout.setup(stats_cfg, {}, _rng_for(99))

	var player: Dictionary = {
		"position": "QB",
		"stats": {"speed": 70.0, "throw_accuracy": 78.0},
		"potential": {"speed": 75.0, "throw_accuracy": 85.0}
	}

	var rng_a: RandomNumberGenerator = _rng_for(123)
	var score_a: float = scout.score_player(player, positions_data, stats_cfg, class_rules, rng_a)

	var rng_b: RandomNumberGenerator = _rng_for(123)
	var score_b: float = scout.score_player(player, positions_data, stats_cfg, class_rules, rng_b)

	t.assert_approx(score_a, score_b, 0.0001, "Scout score is deterministic per seed")
	t.assert_between(score_a, 30.0, 95.0, "Scout score respects board bounds")

func _rng_for(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
