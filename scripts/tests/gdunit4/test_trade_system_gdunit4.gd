## GdUnit4 test suite for Trade System
##
## Validates trade generation, evaluation, and execution.
## Migrated from test_trade_system.gd
extends GdUnitTestSuite

const TradeGenerator = preload("res://scripts/world/TradeGenerator.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _trade_cfg: Dictionary


func before() -> void:
	var config_service := ConfigService.new()
	_positions_cfg = config_service.get_config("positions")
	_main_cfg = config_service.get_config("main")
	_trade_cfg = _main_cfg.get("trades", {}) as Dictionary


func _create_test_player(player_id: String, position: String, stats: Dictionary) -> Dictionary:
	return {
		"player_id": player_id,
		"position": position,
		"stats": stats,
		"age": 25,
		"contract": {"years_remaining": 2}
	}


func _fill_roster_to_minimum(min_size: int) -> Array:
	var filler: Array = []
	for i in range(min_size):
		filler.append(_create_test_player("filler_%d" % i, "OL", {"strength": 60.0}))
	return filler


func _create_test_world_state() -> Dictionary:
	var teams := []
	var rosters := {}

	for i in range(4):
		var team_id := "TEAM_%d" % i
		teams.append({"id": team_id, "name": "Team %d" % i})

		var players: Array = []
		var by_position := {}

		var rb_count := 2 + i
		var qb_count := 4 - i

		for j in range(rb_count):
			players.append(_create_test_player(
				"t%d_rb%d" % [i, j],
				"RB",
				{"speed": 60.0 + j * 5.0}
			))

		for j in range(qb_count):
			players.append(_create_test_player(
				"t%d_qb%d" % [i, j],
				"QB",
				{"throw_accuracy": 60.0 + j * 5.0}
			))

		players.append_array(_fill_roster_to_minimum(50 - players.size()))

		for player in players:
			var p: Dictionary = player
			var pos := String(p.get("position", ""))
			var pid := String(p.get("player_id", ""))
			if not by_position.has(pos):
				by_position[pos] = []
			(by_position[pos] as Array).append(pid)

		rosters[team_id] = {
			"players": players,
			"by_position": by_position
		}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters
	}


func test_elite_team_classified_as_contending() -> void:
	var teams := [{"id": "ELITE", "name": "Elite Team"}]
	var rosters := {
		"ELITE": {
			"players": [
				_create_test_player("p1", "QB", {
					"throw_accuracy": 88.0, "throw_power": 90.0,
					"awareness": 87.0, "decision_making": 89.0
				}),
				_create_test_player("p2", "RB", {
					"speed": 85.0, "agility": 83.0, "acceleration": 86.0,
					"strength": 81.0, "elusiveness": 84.0
				}),
				_create_test_player("p3", "WR", {
					"speed": 88.0, "catching": 90.0, "route_running": 87.0,
					"release": 86.0
				})
			],
			"by_position": {"QB": ["p1"], "RB": ["p2"], "WR": ["p3"]}
		}
	}

	var contexts := TradeGenerator._assess_team_contexts(teams, rosters, _positions_cfg)
	assert_str(String(contexts.get("ELITE", {}).get("mode", ""))).is_equal("contending")


func test_poor_team_classified_as_rebuilding() -> void:
	var teams := [{"id": "POOR", "name": "Poor Team"}]
	var rosters := {
		"POOR": {
			"players": [
				_create_test_player("p7", "QB", {
					"throw_accuracy": 48.0, "throw_power": 45.0,
					"awareness": 46.0, "decision_making": 47.0
				}),
				_create_test_player("p8", "RB", {
					"speed": 50.0, "agility": 47.0, "acceleration": 49.0,
					"strength": 48.0, "elusiveness": 46.0
				}),
				_create_test_player("p9", "WR", {
					"speed": 52.0, "catching": 49.0, "route_running": 48.0,
					"release": 47.0
				})
			],
			"by_position": {"QB": ["p7"], "RB": ["p8"], "WR": ["p9"]}
		}
	}

	var contexts := TradeGenerator._assess_team_contexts(teams, rosters, _positions_cfg)
	assert_str(String(contexts.get("POOR", {}).get("mode", ""))).is_equal("rebuilding")


func test_surplus_team_has_low_need_score() -> void:
	var teams := [{"id": "SURPLUS", "name": "Team with surplus"}]
	var rosters := {
		"SURPLUS": {
			"players": [
				_create_test_player("p1", "RB", {"speed": 70.0}),
				_create_test_player("p2", "RB", {"speed": 68.0}),
				_create_test_player("p3", "RB", {"speed": 72.0}),
				_create_test_player("p4", "RB", {"speed": 65.0}),
				_create_test_player("p5", "RB", {"speed": 67.0}),
				_create_test_player("p6", "RB", {"speed": 69.0})
			],
			"by_position": {"RB": ["p1", "p2", "p3", "p4", "p5", "p6"]}
		}
	}

	var needs := TradeGenerator._assess_team_needs(teams, rosters, _positions_cfg)
	var surplus_rb_need := float(needs.get("SURPLUS", {}).get("RB", 1.0))

	assert_float(surplus_rb_need).is_less(1.0)


func test_deficit_team_has_high_need_score() -> void:
	var teams := [{"id": "DEFICIT", "name": "Team with deficit"}]
	var rosters := {
		"DEFICIT": {
			"players": [_create_test_player("p7", "RB", {"speed": 60.0})],
			"by_position": {"RB": ["p7"]}
		}
	}

	var needs := TradeGenerator._assess_team_needs(teams, rosters, _positions_cfg)
	var deficit_rb_need := float(needs.get("DEFICIT", {}).get("RB", 1.0))

	assert_float(deficit_rb_need).is_greater(1.0)


func test_trade_evaluation_returns_value_calculations() -> void:
	var teams := [{"id": "TEAM_A", "name": "Team A"}]
	var rosters := {
		"TEAM_A": {
			"players": [_create_test_player("p1", "RB", {"speed": 70.0})],
			"by_position": {"RB": ["p1"]}
		}
	}

	var player_values := TradeGenerator._build_player_value_index(rosters, _positions_cfg, _main_cfg)
	var team_needs := {}

	var offer := {
		"send_player_ids": [],
		"receive_player_ids": ["p1"],
		"from_team": "TEAM_B",
		"to_team": "TEAM_A"
	}

	var decision := TradeGenerator._evaluate_offer(offer, teams[0], player_values, team_needs, _trade_cfg)

	assert_bool(decision.has("incoming_value")).is_true()
	assert_bool(decision.has("outgoing_value")).is_true()


func test_trade_execution_updates_roster_sizes() -> void:
	var rosters := {
		"TEAM_A": {
			"players": [
				_create_test_player("p1", "RB", {"speed": 70.0}),
				_create_test_player("p2", "QB", {"throw_accuracy": 75.0})
			],
			"by_position": {"RB": ["p1"], "QB": ["p2"]}
		},
		"TEAM_B": {
			"players": [_create_test_player("p3", "WR", {"speed": 72.0})],
			"by_position": {"WR": ["p3"]}
		}
	}

	var initial_a_size := (rosters["TEAM_A"]["players"] as Array).size()
	var initial_b_size := (rosters["TEAM_B"]["players"] as Array).size()

	var offer := {
		"send_player_ids": ["p1"],
		"receive_player_ids": [],
		"from_team": "TEAM_A",
		"to_team": "TEAM_B"
	}

	TradeGenerator._execute_trade(offer, rosters)

	var final_a_size := (rosters["TEAM_A"]["players"] as Array).size()
	var final_b_size := (rosters["TEAM_B"]["players"] as Array).size()

	assert_int(final_a_size).is_equal(initial_a_size - 1)
	assert_int(final_b_size).is_equal(initial_b_size + 1)


func test_trade_execution_moves_player_to_new_team() -> void:
	var rosters := {
		"TEAM_A": {
			"players": [_create_test_player("p1", "RB", {"speed": 70.0})],
			"by_position": {"RB": ["p1"]}
		},
		"TEAM_B": {
			"players": [],
			"by_position": {}
		}
	}

	var offer := {
		"send_player_ids": ["p1"],
		"receive_player_ids": [],
		"from_team": "TEAM_A",
		"to_team": "TEAM_B"
	}

	TradeGenerator._execute_trade(offer, rosters)

	var team_b_players: Array = rosters["TEAM_B"]["players"] as Array
	var found_p1 := false
	for player in team_b_players:
		if (player as Dictionary).get("player_id") == "p1":
			found_p1 = true
			break

	assert_bool(found_p1).is_true()


func test_trade_execution_updates_by_position_index() -> void:
	var rosters := {
		"TEAM_A": {
			"players": [_create_test_player("p1", "RB", {"speed": 70.0})],
			"by_position": {"RB": ["p1"]}
		},
		"TEAM_B": {
			"players": [],
			"by_position": {}
		}
	}

	var offer := {
		"send_player_ids": ["p1"],
		"receive_player_ids": [],
		"from_team": "TEAM_A",
		"to_team": "TEAM_B"
	}

	TradeGenerator._execute_trade(offer, rosters)

	var team_b_by_pos: Dictionary = rosters["TEAM_B"]["by_position"] as Dictionary
	var team_b_rbs: Array = team_b_by_pos.get("RB", []) as Array

	assert_bool(team_b_rbs.has("p1")).is_true()


func test_trade_generation_determinism() -> void:
	var world_state_1 := _create_test_world_state()
	var world_state_2 := _create_test_world_state()

	var seed_val := 42
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed_val
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_val

	var result1 := TradeGenerator.generate_trades(
		world_state_1, 2024, rng1, _positions_cfg, _main_cfg, _trade_cfg,
		{"max_trades_per_year": 5}
	)

	var result2 := TradeGenerator.generate_trades(
		world_state_2, 2024, rng2, _positions_cfg, _main_cfg, _trade_cfg,
		{"max_trades_per_year": 5}
	)

	assert_int(int(result1.get("executed", 0))).is_equal(int(result2.get("executed", 0)))
	assert_int(int(result1.get("attempts", 0))).is_equal(int(result2.get("attempts", 0)))
