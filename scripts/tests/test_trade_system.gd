extends SceneTree

const TradeGenerator = preload("res://scripts/world/TradeGenerator.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")

var test_count := 0
var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	print("\n=== Trade System Tests ===\n")

	# Load configs
	var cfg_loader := ConfigLoader.new()
	var main_cfg: Dictionary = cfg_loader.get_config("main")
	var positions_cfg: Dictionary = cfg_loader.get_config("positions")
	var trade_cfg: Dictionary = main_cfg.get("trades", {}) as Dictionary

	# Run test suites
	test_team_context_assessment(positions_cfg)
	test_team_needs_assessment(positions_cfg)
	test_trade_offer_generation(positions_cfg, main_cfg, trade_cfg)
	test_trade_evaluation(positions_cfg, main_cfg, trade_cfg)
	test_trade_execution(positions_cfg, main_cfg, trade_cfg)
	test_determinism(positions_cfg, main_cfg, trade_cfg)

	# Print summary
	print("\n=== Test Summary ===")
	print("Total: ", test_count)
	print("Passed: ", pass_count)
	print("Failed: ", fail_count)

	if fail_count == 0:
		print("\nAll tests passed!")
		quit(0)
	else:
		print("\nSome tests failed!")
		quit(1)


func test_team_context_assessment(positions_cfg: Dictionary) -> void:
	print("--- Test: Team Context Assessment ---")

	# Create test teams with different average ratings
	var teams := [
		{"id": "ELITE", "name": "Elite Team"},
		{"id": "GOOD", "name": "Good Team"},
		{"id": "POOR", "name": "Poor Team"}
	]

	# Create rosters with different quality levels
	# Note: Must include all core_stats for each position
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
		},
		"GOOD": {
			"players": [
				_create_test_player("p4", "QB", {
					"throw_accuracy": 70.0, "throw_power": 68.0,
					"awareness": 69.0, "decision_making": 71.0
				}),
				_create_test_player("p5", "RB", {
					"speed": 67.0, "agility": 65.0, "acceleration": 68.0,
					"strength": 63.0, "elusiveness": 66.0
				}),
				_create_test_player("p6", "WR", {
					"speed": 70.0, "catching": 72.0, "route_running": 69.0,
					"release": 68.0
				})
			],
			"by_position": {"QB": ["p4"], "RB": ["p5"], "WR": ["p6"]}
		},
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

	var contexts := TradeGenerator._assess_team_contexts(teams, rosters, positions_cfg)

	# Test 1: Elite team should be contending
	assert_test(
		contexts.get("ELITE", {}).get("mode") == "contending",
		"Elite team should be classified as contending (avg_rating: %.2f)" % contexts.get("ELITE", {}).get("avg_rating", 0.0)
	)

	# Test 2: Poor team should be rebuilding
	assert_test(
		contexts.get("POOR", {}).get("mode") == "rebuilding",
		"Poor team should be classified as rebuilding"
	)

	# Test 3: Good team should be neutral
	assert_test(
		contexts.get("GOOD", {}).get("mode") == "neutral",
		"Good team should be classified as neutral (avg_rating: %.2f)" % contexts.get("GOOD", {}).get("avg_rating", 0.0)
	)

	print("")


func test_team_needs_assessment(positions_cfg: Dictionary) -> void:
	print("--- Test: Team Needs Assessment ---")

	var teams := [
		{"id": "SURPLUS", "name": "Team with surplus"},
		{"id": "DEFICIT", "name": "Team with deficit"}
	]

	# SURPLUS team has too many RBs
	# DEFICIT team has too few RBs
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
			"by_position": {
				"RB": ["p1", "p2", "p3", "p4", "p5", "p6"]
			}
		},
		"DEFICIT": {
			"players": [
				_create_test_player("p7", "RB", {"speed": 60.0})
			],
			"by_position": {
				"RB": ["p7"]
			}
		}
	}

	var needs := TradeGenerator._assess_team_needs(teams, rosters, positions_cfg)

	# Test 1: Surplus team should have low need score for RB
	var surplus_rb_need := float(needs.get("SURPLUS", {}).get("RB", 1.0))
	assert_test(
		surplus_rb_need < 1.0,
		"Surplus team should have low RB need score (got: %.2f)" % surplus_rb_need
	)

	# Test 2: Deficit team should have high need score for RB
	var deficit_rb_need := float(needs.get("DEFICIT", {}).get("RB", 1.0))
	assert_test(
		deficit_rb_need > 1.0,
		"Deficit team should have high RB need score (got: %.2f)" % deficit_rb_need
	)

	print("")


func test_trade_offer_generation(
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	trade_cfg: Dictionary
) -> void:
	print("--- Test: Trade Offer Generation ---")

	var teams := [
		{"id": "TEAM_A", "name": "Team A"},
		{"id": "TEAM_B", "name": "Team B"}
	]

	# Team A has surplus RBs, Team B needs RBs
	var rosters := {
		"TEAM_A": {
			"players": [
				_create_test_player("p1", "RB", {"speed": 70.0}),
				_create_test_player("p2", "RB", {"speed": 68.0}),
				_create_test_player("p3", "RB", {"speed": 72.0}),
				_create_test_player("p4", "RB", {"speed": 65.0}),
				_create_test_player("p5", "RB", {"speed": 67.0}),
				_create_test_player("p6", "QB", {"throw_accuracy": 75.0}),
				_create_test_player("p7", "QB", {"throw_accuracy": 73.0}),
				_create_test_player("p8", "QB", {"throw_accuracy": 71.0}),
				_create_test_player("p9", "WR", {"speed": 70.0}),
			] + _fill_roster_to_minimum(50),
			"by_position": {
				"RB": ["p1", "p2", "p3", "p4", "p5"],
				"QB": ["p6", "p7", "p8"],
				"WR": ["p9"]
			}
		},
		"TEAM_B": {
			"players": [
				_create_test_player("p10", "RB", {"speed": 60.0}),
				_create_test_player("p11", "QB", {"throw_accuracy": 70.0}),
				_create_test_player("p12", "WR", {"speed": 68.0})
			] + _fill_roster_to_minimum(50),
			"by_position": {
				"RB": ["p10"],
				"QB": ["p11"],
				"WR": ["p12"]
			}
		}
	}

	var team_contexts := TradeGenerator._assess_team_contexts(teams, rosters, positions_cfg)
	var team_needs := TradeGenerator._assess_team_needs(teams, rosters, positions_cfg)
	var player_values := TradeGenerator._build_player_value_index(rosters, positions_cfg, main_cfg)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var offer: Variant = TradeGenerator._generate_offer(
		teams[0], teams[1],
		rosters, team_needs, team_contexts,
		player_values, positions_cfg, trade_cfg, rng
	)

	# Test 1: Offer should be generated (not null)
	assert_test(
		offer != null,
		"Trade offer should be generated for surplus/deficit scenario"
	)

	# Test 2: Offer should contain a player being sent
	if offer != null:
		var send_players: Array = offer.get("send_player_ids", []) as Array
		assert_test(
			send_players.size() > 0,
			"Offer should include at least one player being sent"
		)

	print("")


func test_trade_evaluation(
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	trade_cfg: Dictionary
) -> void:
	print("--- Test: Trade Evaluation ---")

	var teams := [
		{"id": "TEAM_A", "name": "Team A"}
	]

	var rosters := {
		"TEAM_A": {
			"players": [
				_create_test_player("p1", "RB", {"speed": 70.0})
			],
			"by_position": {"RB": ["p1"]}
		}
	}

	var player_values := TradeGenerator._build_player_value_index(rosters, positions_cfg, main_cfg)
	var team_needs := {}

	# Test 1: Free acquisition (receive something for nothing) should be accepted
	var offer_free := {
		"send_player_ids": [],
		"receive_player_ids": ["p1"],
		"from_team": "TEAM_B",
		"to_team": "TEAM_A"
	}

	var decision_free := TradeGenerator._evaluate_offer(
		offer_free, teams[0], player_values, team_needs, trade_cfg
	)

	assert_test(
		decision_free.get("accept", false),
		"Trade evaluation should accept free acquisitions"
	)

	# Test 2: Fair trade with threshold should work
	var offer_fair := {
		"send_player_ids": [],
		"receive_player_ids": ["p1"],
		"from_team": "TEAM_B",
		"to_team": "TEAM_A"
	}

	var decision_fair := TradeGenerator._evaluate_offer(
		offer_fair, teams[0], player_values, team_needs, trade_cfg
	)

	assert_test(
		decision_fair.has("incoming_value") and decision_fair.has("outgoing_value"),
		"Trade evaluation should return value calculations"
	)

	print("")


func test_trade_execution(
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	trade_cfg: Dictionary
) -> void:
	print("--- Test: Trade Execution ---")

	# Create initial rosters
	var rosters := {
		"TEAM_A": {
			"players": [
				_create_test_player("p1", "RB", {"speed": 70.0}),
				_create_test_player("p2", "QB", {"throw_accuracy": 75.0})
			],
			"by_position": {
				"RB": ["p1"],
				"QB": ["p2"]
			}
		},
		"TEAM_B": {
			"players": [
				_create_test_player("p3", "WR", {"speed": 72.0})
			],
			"by_position": {
				"WR": ["p3"]
			}
		}
	}

	var initial_a_size := (rosters["TEAM_A"]["players"] as Array).size()
	var initial_b_size := (rosters["TEAM_B"]["players"] as Array).size()

	# Execute trade: Team A sends p1 to Team B
	var offer := {
		"send_player_ids": ["p1"],
		"receive_player_ids": [],
		"from_team": "TEAM_A",
		"to_team": "TEAM_B"
	}

	TradeGenerator._execute_trade(offer, rosters)

	var final_a_size := (rosters["TEAM_A"]["players"] as Array).size()
	var final_b_size := (rosters["TEAM_B"]["players"] as Array).size()

	# Test 1: Team A should have one fewer player
	assert_test(
		final_a_size == initial_a_size - 1,
		"Team A should have one fewer player after trade (had: %d, now: %d)" % [initial_a_size, final_a_size]
	)

	# Test 2: Team B should have one more player
	assert_test(
		final_b_size == initial_b_size + 1,
		"Team B should have one more player after trade (had: %d, now: %d)" % [initial_b_size, final_b_size]
	)

	# Test 3: Player p1 should be on Team B
	var team_b_players: Array = rosters["TEAM_B"]["players"] as Array
	var found_p1 := false
	for player in team_b_players:
		var p: Dictionary = player
		if p.get("player_id") == "p1":
			found_p1 = true
			break

	assert_test(
		found_p1,
		"Player p1 should be on Team B after trade"
	)

	# Test 4: by_position index should be updated
	var team_b_by_pos: Dictionary = rosters["TEAM_B"]["by_position"] as Dictionary
	var team_b_rbs: Array = team_b_by_pos.get("RB", []) as Array
	assert_test(
		team_b_rbs.has("p1"),
		"Team B's by_position index should include p1 at RB"
	)

	print("")


func test_determinism(
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	trade_cfg: Dictionary
) -> void:
	print("--- Test: Determinism ---")

	# Create identical world states
	var world_state_1 := _create_test_world_state()
	var world_state_2 := _create_test_world_state()

	var seed := 42
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed

	# Run trade generation with same seed
	var result1 := TradeGenerator.generate_trades(
		world_state_1,
		2024,
		rng1,
		positions_cfg,
		main_cfg,
		trade_cfg,
		{"max_trades_per_year": 5}
	)

	var result2 := TradeGenerator.generate_trades(
		world_state_2,
		2024,
		rng2,
		positions_cfg,
		main_cfg,
		trade_cfg,
		{"max_trades_per_year": 5}
	)

	# Test 1: Same number of executed trades
	assert_test(
		result1.get("executed", 0) == result2.get("executed", 0),
		"Same seed should produce same number of trades (run1: %d, run2: %d)" % [
			result1.get("executed", 0),
			result2.get("executed", 0)
		]
	)

	# Test 2: Same number of attempts
	assert_test(
		result1.get("attempts", 0) == result2.get("attempts", 0),
		"Same seed should produce same number of attempts (run1: %d, run2: %d)" % [
			result1.get("attempts", 0),
			result2.get("attempts", 0)
		]
	)

	print("")


# Helper functions

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

	# Create 4 teams with varied rosters
	for i in range(4):
		var team_id := "TEAM_%d" % i
		teams.append({"id": team_id, "name": "Team %d" % i})

		var players: Array = []
		var by_position := {}

		# Create varied roster with some surpluses and deficits
		var rb_count := 2 + i  # Team 0: 2, Team 1: 3, Team 2: 4, Team 3: 5
		var qb_count := 4 - i  # Team 0: 4, Team 1: 3, Team 2: 2, Team 3: 1

		for j in range(rb_count):
			players.append(_create_test_player(
				"t%d_rb%d" % [i, j],
				"RB",
				{"speed": 60.0 + randf() * 20.0}
			))

		for j in range(qb_count):
			players.append(_create_test_player(
				"t%d_qb%d" % [i, j],
				"QB",
				{"throw_accuracy": 60.0 + randf() * 20.0}
			))

		# Fill to minimum roster size
		players.append_array(_fill_roster_to_minimum(50 - players.size()))

		# Build by_position index
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


func assert_test(condition: bool, message: String) -> void:
	test_count += 1
	if condition:
		print("[PASS] ", message)
		pass_count += 1
	else:
		print("[FAIL] ", message)
		fail_count += 1
