extends SceneTree

const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")

func _initialize() -> void:
	print("\n=== Trade Integration Test ===\n")

	# Load configs
	var cfg_loader := ConfigLoader.new()
	var main_cfg: Dictionary = cfg_loader.get_config("main")
	var positions_cfg: Dictionary = cfg_loader.get_config("positions")
	var league_cfg: Dictionary = cfg_loader.get_config("league")
	var stats_cfg: Dictionary = cfg_loader.get_config("stats")

	# Create minimal world state for testing
	var world_state := _create_test_world_state()

	print("Running NFL season with trades enabled...")
	var season_result := NflSeason.new().run(
		world_state,
		2024,
		12345,  # seed
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{}  # options
	)

	var trades_executed := int(season_result.get("trades", 0))
	print("Trades executed: ", trades_executed)
	print("Season result keys: ", season_result.keys())

	# Check trade history was persisted
	var trade_history: Array = world_state.get("trade_history", []) as Array
	print("Trade history entries: ", trade_history.size())

	if trade_history.size() > 0:
		print("\nSample trade:")
		var trade: Dictionary = trade_history[0] as Dictionary
		print("  Year: ", trade.get("year"))
		print("  From: ", trade.get("offering_team"))
		print("  To: ", trade.get("receiving_team"))
		var offer: Dictionary = trade.get("offer", {}) as Dictionary
		print("  Sent players: ", offer.get("send_player_ids", []))
		print("  Received players: ", offer.get("receive_player_ids", []))

	# Test determinism: run again with same seed
	print("\n--- Determinism Test ---")
	var world_state_2 := _create_test_world_state()
	var season_result_2 := NflSeason.new().run(
		world_state_2,
		2024,
		12345,  # same seed
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{}
	)

	var trades_executed_2 := int(season_result_2.get("trades", 0))

	if trades_executed == trades_executed_2:
		print("[PASS] Determinism preserved: %d trades in both runs" % trades_executed)
		quit(0)
	else:
		print("[FAIL] Determinism broken: %d trades vs %d trades" % [trades_executed, trades_executed_2])
		quit(1)


func _create_test_world_state() -> Dictionary:
	# Create 4 test teams with realistic rosters
	var teams := []
	var rosters := {}

	for i in range(4):
		var team_id := "TEAM_%d" % i
		teams.append({
			"id": team_id,
			"name": "Team %d" % i,
			"abbreviation": "T%d" % i
		})

		var players: Array = []

		# Create varied roster: some teams with surpluses, some with deficits
		# Team 0: Many RBs (surplus), few QBs (deficit)
		# Team 1: Many QBs (surplus), few RBs (deficit)
		# Team 2: Balanced
		# Team 3: Balanced

		if i == 0:
			# Surplus RBs
			for j in range(6):
				players.append(_create_player("t%d_rb%d" % [i, j], "RB", 60.0 + randf() * 20.0))
			for j in range(2):
				players.append(_create_player("t%d_qb%d" % [i, j], "QB", 60.0 + randf() * 20.0))
		elif i == 1:
			# Surplus QBs
			for j in range(5):
				players.append(_create_player("t%d_qb%d" % [i, j], "QB", 60.0 + randf() * 20.0))
			for j in range(2):
				players.append(_create_player("t%d_rb%d" % [i, j], "RB", 60.0 + randf() * 20.0))
		else:
			# Balanced
			for j in range(3):
				players.append(_create_player("t%d_qb%d" % [i, j], "QB", 60.0 + randf() * 20.0))
			for j in range(4):
				players.append(_create_player("t%d_rb%d" % [i, j], "RB", 60.0 + randf() * 20.0))

		# Add other positions to meet minimum roster size
		for j in range(5):
			players.append(_create_player("t%d_wr%d" % [i, j], "WR", 60.0 + randf() * 20.0))
		for j in range(7):
			players.append(_create_player("t%d_ol%d" % [i, j], "OL", 60.0 + randf() * 20.0))
		for j in range(5):
			players.append(_create_player("t%d_dl%d" % [i, j], "DL", 60.0 + randf() * 20.0))
		for j in range(4):
			players.append(_create_player("t%d_lb%d" % [i, j], "LB", 60.0 + randf() * 20.0))
		for j in range(4):
			players.append(_create_player("t%d_cb%d" % [i, j], "CB", 60.0 + randf() * 20.0))
		for j in range(3):
			players.append(_create_player("t%d_s%d" % [i, j], "S", 60.0 + randf() * 20.0))

		# Add filler to reach 53
		while players.size() < 53:
			players.append(_create_player("t%d_fill%d" % [i, players.size()], "OL", 50.0))

		# Build by_position index
		var by_position := {}
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
		"nfl_rosters": rosters,
		"retired_players": [],
		"free_agents": {}
	}


func _create_player(player_id: String, position: String, base_rating: float) -> Dictionary:
	# Create a player with all required core stats for their position
	var stats := {}

	# Add position-specific core stats
	match position:
		"QB":
			stats["throw_power"] = base_rating
			stats["throw_accuracy"] = base_rating
			stats["awareness"] = base_rating
			stats["decision_making"] = base_rating
		"RB":
			stats["speed"] = base_rating
			stats["agility"] = base_rating
			stats["acceleration"] = base_rating
			stats["strength"] = base_rating
			stats["elusiveness"] = base_rating
		"WR":
			stats["speed"] = base_rating
			stats["catching"] = base_rating
			stats["route_running"] = base_rating
			stats["release"] = base_rating
		"OL":
			stats["strength"] = base_rating
			stats["pass_blocking"] = base_rating
			stats["run_blocking"] = base_rating
		"DL":
			stats["strength"] = base_rating
			stats["power_moves"] = base_rating
			stats["pass_rush"] = base_rating
		"LB":
			stats["speed"] = base_rating
			stats["tackle"] = base_rating
			stats["awareness"] = base_rating
		"CB":
			stats["speed"] = base_rating
			stats["man_coverage"] = base_rating
			stats["zone_coverage"] = base_rating
		"S":
			stats["speed"] = base_rating
			stats["zone_coverage"] = base_rating
			stats["tackle"] = base_rating

	return {
		"player_id": player_id,
		"position": position,
		"stats": stats,
		"age": 25,
		"contract": {
			"years_remaining": 2,
			"salary": 1000000
		},
		"nfl_status": "active"
	}
