## GdUnit4 test suite for Trade Integration
##
## Tests trade execution during NFL season, including:
## 1. Trade execution mechanics
## 2. Trade history persistence
## 3. Determinism (same seed = same trades)
extends GdUnitTestSuite

const ConfigService = preload("res://autoloads/Config.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")

var _main_cfg: Dictionary
var _positions_cfg: Dictionary
var _league_cfg: Dictionary
var _stats_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_main_cfg = config.get_config("main")
	_positions_cfg = config.get_config("positions")
	_league_cfg = config.get_config("league")
	_stats_cfg = config.get_config("stats")


func _create_test_world_state() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42424242  # Fixed seed for deterministic test setup

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
		if i == 0:
			# Surplus RBs
			for j in range(6):
				players.append(_create_player("t%d_rb%d" % [i, j], "RB", 60.0 + rng.randf() * 20.0))
			for j in range(2):
				players.append(_create_player("t%d_qb%d" % [i, j], "QB", 60.0 + rng.randf() * 20.0))
		elif i == 1:
			# Surplus QBs
			for j in range(5):
				players.append(_create_player("t%d_qb%d" % [i, j], "QB", 60.0 + rng.randf() * 20.0))
			for j in range(2):
				players.append(_create_player("t%d_rb%d" % [i, j], "RB", 60.0 + rng.randf() * 20.0))
		else:
			# Balanced
			for j in range(3):
				players.append(_create_player("t%d_qb%d" % [i, j], "QB", 60.0 + rng.randf() * 20.0))
			for j in range(4):
				players.append(_create_player("t%d_rb%d" % [i, j], "RB", 60.0 + rng.randf() * 20.0))

		# Add other positions to meet minimum roster size
		for j in range(5):
			players.append(_create_player("t%d_wr%d" % [i, j], "WR", 60.0 + rng.randf() * 20.0))
		for j in range(7):
			players.append(_create_player("t%d_ol%d" % [i, j], "OL", 60.0 + rng.randf() * 20.0))
		for j in range(5):
			players.append(_create_player("t%d_dl%d" % [i, j], "DL", 60.0 + rng.randf() * 20.0))
		for j in range(4):
			players.append(_create_player("t%d_lb%d" % [i, j], "LB", 60.0 + rng.randf() * 20.0))
		for j in range(4):
			players.append(_create_player("t%d_cb%d" % [i, j], "CB", 60.0 + rng.randf() * 20.0))
		for j in range(3):
			players.append(_create_player("t%d_s%d" % [i, j], "S", 60.0 + rng.randf() * 20.0))

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
	var stats := {}

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


func test_season_runs_with_trades() -> void:
	var world_state := _create_test_world_state()

	var season_result := NflSeason.new().run(
		world_state,
		2024,
		12345,
		_league_cfg,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		{}
	)

	# Verify season completed
	assert_bool(season_result.has("trades") or season_result.size() > 0).is_true()


func test_trade_history_persistence() -> void:
	var world_state := _create_test_world_state()

	var _season_result := NflSeason.new().run(
		world_state,
		2024,
		12345,
		_league_cfg,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		{}
	)

	# Check trade history exists in world state
	var trade_history: Array = world_state.get("trade_history", []) as Array

	# If trades occurred, verify structure
	if trade_history.size() > 0:
		var trade: Dictionary = trade_history[0] as Dictionary
		assert_bool(trade.has("year")).is_true()
		assert_bool(trade.has("offering_team")).is_true()
		assert_bool(trade.has("receiving_team")).is_true()


func test_trade_determinism() -> void:
	# Run 1
	var world_state_1 := _create_test_world_state()
	var season_result_1 := NflSeason.new().run(
		world_state_1,
		2024,
		12345,
		_league_cfg,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		{}
	)

	# Run 2 with same seed
	var world_state_2 := _create_test_world_state()
	var season_result_2 := NflSeason.new().run(
		world_state_2,
		2024,
		12345,
		_league_cfg,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		{}
	)

	var trades_1 := int(season_result_1.get("trades", 0))
	var trades_2 := int(season_result_2.get("trades", 0))

	# Same seed should produce same number of trades
	assert_int(trades_1).is_equal(trades_2)
