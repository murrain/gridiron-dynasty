extends RefCounted

const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")

func run(t) -> void:
	var stats_cfg := {
		"stats": [
			{"name": "throw_accuracy", "measurement_difficulty": 0.2},
			{"name": "throw_power", "measurement_difficulty": 0.2},
			{"name": "speed", "measurement_difficulty": 0.1}
		]
	}
	var positions_data := {
		"QB": {
			"core_stats": ["throw_accuracy"],
			"distributions": {"throw_power": {"role": "secondary"}}
		}
	}
	var class_rules := {
		"recruiting": {
			"athletic_keys": ["speed"],
			"mental_keys": []
		}
	}

	var scout := {
		"base_skill": 0.35,
		"tape_grinder": 0.2,
		"risk_aversion": 0.1,
		"stat_skill": {"throw_accuracy": 0.4, "throw_power": 0.35, "speed": 0.3},
		"estimation_multipliers": {},
		"valuation_multipliers": {}
	}

	var player := {
		"position": "QB",
		"stats": {"throw_accuracy": 70.0, "throw_power": 66.0, "speed": 62.0},
		"potential": {"throw_accuracy": 78.0, "throw_power": 72.0, "speed": 68.0}
	}

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var score_a := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345
	var score_b := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng_b)

	t.assert_approx(score_a, score_b, 0.0001, "ScoutRuntime scoring is deterministic per seed")
	t.assert_between(score_a, 30.0, 92.0, "ScoutRuntime score stays within composite bounds")
