## GdUnit4 test suite for Scout Potential Evaluation
##
## Tests Phase 3: Potential-Based Evaluation in Scout System.
## Verifies scouts correctly apply potential bonuses based on:
## 1. Age-adjusted projection (younger = more runway)
## 2. Tape grinder bonus (tape grinders weight potential more)
## 3. Growth trajectory bonus (players with strong development history)
##
## Migrated from test_scout_potential_evaluation.gd
extends GdUnitTestSuite

const Scout = preload("res://scripts/core/models/Scout.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")


func _get_stats_cfg() -> Dictionary:
	return {
		"stats": [
			{"name": "speed", "measurement_difficulty": 0.2},
			{"name": "route_running", "measurement_difficulty": 0.3},
			{"name": "catching", "measurement_difficulty": 0.25},
			{"name": "awareness", "measurement_difficulty": 0.5},
			{"name": "work_ethic", "measurement_difficulty": 0.6}
		]
	}


func _get_positions_data() -> Dictionary:
	return {
		"WR": {
			"core_stats": ["route_running", "catching"],
			"distributions": {
				"speed": {"role": "athletic"},
				"awareness": {"role": "secondary"},
				"work_ethic": {"role": "secondary"}
			}
		}
	}


func _get_class_rules() -> Dictionary:
	return {
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
	scout.board_noise_sigma = 1.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	scout.setup(stats_cfg, {}, rng)
	return scout


func _rng_for(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


func test_tape_grinder_scores_high_potential_players_higher() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()

	var scout_regular := _create_scout(stats_cfg, 0.2)
	var scout_tape := _create_scout(stats_cfg, 0.75)

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

	assert_float(score_tape).is_greater(score_regular)


func test_younger_players_receive_higher_bonus() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
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

	assert_float(score_21).is_greater(score_24)


func test_strong_growth_trajectory_scores_higher() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
	var scout := _create_scout(stats_cfg, 0.5)

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

	assert_float(score_high_growth).is_greater(score_avg_growth)


func test_feature_can_be_toggled_off() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
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

	var rules_enabled: Dictionary = class_rules.duplicate(true)
	rules_enabled["draft_potential_weighting"]["enabled"] = true

	var rules_disabled: Dictionary = class_rules.duplicate(true)
	rules_disabled["draft_potential_weighting"]["enabled"] = false

	var rng_1 := _rng_for(999)
	var rng_2 := _rng_for(999)

	var score_enabled := scout.score_player(player, positions_data, stats_cfg, rules_enabled, rng_1)
	var score_disabled := scout.score_player(player, positions_data, stats_cfg, rules_disabled, rng_2)

	assert_float(score_enabled).is_greater(score_disabled)


func test_potential_evaluation_is_deterministic() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()
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

	assert_float(score_1).is_equal_approx(score_2, 0.0001)


func test_scenario_marvin_harrison_tape_grinder_bonus() -> void:
	var stats_cfg := _get_stats_cfg()
	var positions_data := _get_positions_data()
	var class_rules := _get_class_rules()

	var scout_ravens := _create_scout(stats_cfg, 0.75)
	var scout_regular := _create_scout(stats_cfg, 0.3)

	var player := {
		"position": "WR",
		"age": 21,
		"stats": {"speed": 70.0, "route_running": 75.0, "catching": 72.0, "awareness": 68.0, "work_ethic": 75.0},
		"potential": {"speed": 78.0, "route_running": 82.0, "catching": 80.0, "awareness": 75.0, "work_ethic": 82.0},
		"development_report": []
	}

	var rng_1 := _rng_for(54321)
	var rng_2 := _rng_for(54321)

	var score_ravens := scout_ravens.score_player(player, positions_data, stats_cfg, class_rules, rng_1)
	var score_regular := scout_regular.score_player(player, positions_data, stats_cfg, class_rules, rng_2)

	assert_float(score_ravens).is_greater(score_regular)
	assert_float(score_ravens - score_regular).is_between(0.0, 2.0)
