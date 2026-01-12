extends RefCounted

const Scout = preload("res://scripts/core/models/Scout.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")

## Tests Phase 3: Potential-Based Evaluation in Scout System
##
## Verifies that scouts correctly apply potential bonuses based on:
## 1. Age-adjusted projection (younger = more runway)
## 2. Tape grinder bonus (tape grinders weight potential more)
## 3. Growth trajectory bonus (players with strong development history)

func run(t) -> void:
	# Test configuration mirrors real game config
	var stats_cfg := {
		"stats": [
			{"name": "speed", "measurement_difficulty": 0.2},
			{"name": "route_running", "measurement_difficulty": 0.3},
			{"name": "catching", "measurement_difficulty": 0.25},
			{"name": "awareness", "measurement_difficulty": 0.5},
			{"name": "work_ethic", "measurement_difficulty": 0.6}
		]
	}

	var positions_data := {
		"WR": {
			"core_stats": ["route_running", "catching"],
			"distributions": {
				"speed": {"role": "athletic"},
				"awareness": {"role": "secondary"},
				"work_ethic": {"role": "secondary"}
			}
		}
	}

	var class_rules := {
		"recruiting": {
			"athletic_keys": ["speed"],
			"mental_keys": ["awareness", "work_ethic"],
			"composite_weights": {
				"athletic": 0.40,
				"core": 0.30,
				"secondary": 0.20,
				"mentals": 0.10
			}
		},
		"draft_potential_weighting": {
			"enabled": true,
			"age_projection_bonus": {
				"age_21": 0.08,
				"age_22": 0.05,
				"age_23": 0.02,
				"age_24": 0.0,
				"age_25": -0.03
			},
			"growth_trajectory_weight": 0.15,
			"tape_grinder_bonus": 0.12
		}
	}

	_test_tape_grinder_bonus(t, stats_cfg, positions_data, class_rules)
	_test_age_projection_bonus(t, stats_cfg, positions_data, class_rules)
	_test_growth_trajectory_bonus(t, stats_cfg, positions_data, class_rules)
	_test_feature_toggle(t, stats_cfg, positions_data, class_rules)
	_test_determinism(t, stats_cfg, positions_data, class_rules)
	_test_scenario_marvin_harrison(t, stats_cfg, positions_data, class_rules)

## Test that tape grinders apply larger potential bonuses
func _test_tape_grinder_bonus(t, stats_cfg, positions_data, class_rules) -> void:
	# Regular scout (low tape_grinder)
	var scout_regular := _create_scout(stats_cfg, 0.2)

	# Tape grinder scout (high tape_grinder)
	var scout_tape := _create_scout(stats_cfg, 0.75)

	# Player with high potential gap
	var player := {
		"position": "WR",
		"age": 22,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": []
	}

	var rng_1 := _rng_for(42)
	var rng_2 := _rng_for(42)

	var score_regular := scout_regular.score_player(player, positions_data, stats_cfg, class_rules, rng_1)
	var score_tape := scout_tape.score_player(player, positions_data, stats_cfg, class_rules, rng_2)

	t.assert_gt(score_tape, score_regular, "Tape grinder should score high-potential players higher")

## Test that younger players receive higher bonuses
func _test_age_projection_bonus(t, stats_cfg, positions_data, class_rules) -> void:
	var scout := _create_scout(stats_cfg, 0.6)

	var player_21 := {
		"position": "WR",
		"age": 21,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": []
	}

	var player_24 := {
		"position": "WR",
		"age": 24,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": []
	}

	var rng_1 := _rng_for(555)
	var rng_2 := _rng_for(555)

	var score_21 := scout.score_player(player_21, positions_data, stats_cfg, class_rules, rng_1)
	var score_24 := scout.score_player(player_24, positions_data, stats_cfg, class_rules, rng_2)

	t.assert_gt(score_21, score_24, "21-year-old should score higher than 24-year-old with same stats")

## Test that players with strong growth history receive bonus
func _test_growth_trajectory_bonus(t, stats_cfg, positions_data, class_rules) -> void:
	var scout := _create_scout(stats_cfg, 0.5)

	# Player with strong growth trajectory (>4.0 pts/year)
	var player_high_growth := {
		"position": "WR",
		"age": 22,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": [
			{"stat_delta": 5.2},
			{"stat_delta": 4.8},
			{"stat_delta": 5.5}
		]
	}

	# Player with average growth trajectory
	var player_avg_growth := {
		"position": "WR",
		"age": 22,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": [
			{"stat_delta": 2.2},
			{"stat_delta": 1.8},
			{"stat_delta": 2.5}
		]
	}

	var rng_1 := _rng_for(777)
	var rng_2 := _rng_for(777)

	var score_high_growth := scout.score_player(player_high_growth, positions_data, stats_cfg, class_rules, rng_1)
	var score_avg_growth := scout.score_player(player_avg_growth, positions_data, stats_cfg, class_rules, rng_2)

	t.assert_gt(score_high_growth, score_avg_growth, "Player with strong growth trajectory should score higher")

## Test that feature can be toggled off
func _test_feature_toggle(t, stats_cfg, positions_data, class_rules) -> void:
	var scout := _create_scout(stats_cfg, 0.8)

	var player := {
		"position": "WR",
		"age": 21,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": [
			{"stat_delta": 5.2},
			{"stat_delta": 4.8},
			{"stat_delta": 5.5}
		]
	}

	# Enabled config
	var rules_enabled: Dictionary = class_rules.duplicate(true)
	rules_enabled["draft_potential_weighting"]["enabled"] = true

	# Disabled config
	var rules_disabled: Dictionary = class_rules.duplicate(true)
	rules_disabled["draft_potential_weighting"]["enabled"] = false

	var rng_1 := _rng_for(999)
	var rng_2 := _rng_for(999)

	var score_enabled := scout.score_player(player, positions_data, stats_cfg, rules_enabled, rng_1)
	var score_disabled := scout.score_player(player, positions_data, stats_cfg, rules_disabled, rng_2)

	t.assert_gt(score_enabled, score_disabled, "Enabled feature should produce higher scores for high-potential players")

## Test determinism: same seed produces same results
func _test_determinism(t, stats_cfg, positions_data, class_rules) -> void:
	var scout := _create_scout(stats_cfg, 0.75)

	var player := {
		"position": "WR",
		"age": 21,
		"stats": {"speed": 75.0, "route_running": 70.0, "catching": 68.0, "awareness": 65.0, "work_ethic": 70.0},
		"potential": {"speed": 82.0, "route_running": 78.0, "catching": 76.0, "awareness": 70.0, "work_ethic": 75.0},
		"development_report": [
			{"stat_delta": 5.2},
			{"stat_delta": 4.8}
		]
	}

	var rng_1 := _rng_for(12345)
	var rng_2 := _rng_for(12345)

	var score_1 := scout.score_player(player, positions_data, stats_cfg, class_rules, rng_1)
	var score_2 := scout.score_player(player, positions_data, stats_cfg, class_rules, rng_2)

	t.assert_approx(score_1, score_2, 0.0001, "Potential evaluation must be deterministic")

## Test realistic scenario: Marvin Harrison Jr. (WR, age 21)
func _test_scenario_marvin_harrison(t, stats_cfg, positions_data, class_rules) -> void:
	# Simulate Ravens scout with tape_grinder = 0.75
	var scout_ravens := _create_scout(stats_cfg, 0.75)

	# Marvin Harrison Jr.: current 72.3, potential 80.0
	var player := {
		"position": "WR",
		"age": 21,
		"stats": {"speed": 70.0, "route_running": 75.0, "catching": 72.0, "awareness": 68.0, "work_ethic": 75.0},
		"potential": {"speed": 78.0, "route_running": 82.0, "catching": 80.0, "awareness": 75.0, "work_ethic": 82.0},
		"development_report": []
	}

	# Regular scout for comparison
	var scout_regular := _create_scout(stats_cfg, 0.3)

	var rng_1 := _rng_for(54321)
	var rng_2 := _rng_for(54321)

	var score_ravens := scout_ravens.score_player(player, positions_data, stats_cfg, class_rules, rng_1)
	var score_regular := scout_regular.score_player(player, positions_data, stats_cfg, class_rules, rng_2)

	# Expected: tape grinder bonus + age bonus should boost score significantly
	# potential_gap ~7.7, tape bonus: 7.7 * 0.12 * 0.75 = 0.69
	# age bonus: 0.08 * 7.7 * 0.08 = 0.05
	# Total expected boost: ~0.74 points
	var expected_diff := 0.5  # Conservative estimate

	t.assert_gt(score_ravens, score_regular, "Ravens tape grinder should value Harrison higher")
	t.assert_between(score_ravens - score_regular, 0.0, 2.0, "Bonus should be conservative (< 2 pts)")

## Helper: Create scout with specific tape_grinder value
func _create_scout(stats_cfg: Dictionary, tape_grinder_val: float) -> Scout:
	var scout := Scout.new()
	scout.base_skill = 0.65
	scout.tape_grinder = tape_grinder_val
	scout.bucket_weights = {"athletic": 0.40, "core": 0.30, "secondary": 0.20, "mentals": 0.10}
	scout.stat_skill = {
		"speed": 0.7,
		"route_running": 0.7,
		"catching": 0.7,
		"awareness": 0.6,
		"work_ethic": 0.6
	}
	scout.board_noise_sigma = 1.5  # Reduced noise for clearer test signal
	scout.setup(stats_cfg, {}, _rng_for(999))
	return scout

## Helper: Create RNG with seed
func _rng_for(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
