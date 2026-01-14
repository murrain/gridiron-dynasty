extends RefCounted

const NflSeason = preload("res://scripts/world/NflSeason.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run(t) -> void:
	var config := ConfigService.new()
	var league_cfg := config.get_config("world/league")
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")
	var stats_cfg := config.get_config("stats")

	# Test 1: Verify roster advancement
	_test_roster_advancement(t, league_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 2: Verify retirement handling
	_test_retirement_handling(t, league_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 3: Verify contract expiration tracking
	_test_contract_expiration(t, league_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 4: Assert determinism
	_test_determinism(t, league_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 5: Verify empty roster handling
	_test_empty_roster(t, league_cfg, positions_cfg, main_cfg, stats_cfg)

func _test_roster_advancement(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_rosters()
	var original_ages := _collect_player_ages(world_state)

	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, league_cfg, positions_cfg, main_cfg, stats_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	t.assert_true(not rosters.is_empty(), "rosters should not be empty")

	var total_players := int(result.get("total_players", 0))
	t.assert_true(total_players > 0 or int(result.get("retirements", 0)) > 0,
		"should have players or retirements")

	# Check ages increased (for remaining players)
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			var player_id := String(p.get("player_id", ""))
			if original_ages.has(player_id):
				var new_age := int(p.get("age", 0))
				var old_age := int(original_ages[player_id])
				t.assert_eq(new_age, old_age + 1, "%s age should increase by 1" % player_id)

func _test_retirement_handling(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_old_players()

	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, league_cfg, positions_cfg, main_cfg, stats_cfg)

	var retirements := int(result.get("retirements", 0))
	t.assert_true(retirements > 0, "old players should retire")

	var retired: Array = world_state.get("retired_players", []) as Array
	t.assert_eq(retired.size(), retirements, "retired_players array matches count")

	for player in retired:
		var p: Dictionary = player
		t.assert_eq(int(p.get("retirement_year", 0)), 2025, "retirement year set correctly")
		t.assert_true(p.has("retirement_team"), "retirement team should be set")

func _test_contract_expiration(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_expiring_contracts()

	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, league_cfg, positions_cfg, main_cfg, stats_cfg)

	var free_agents_count := int(result.get("free_agents", 0))
	t.assert_true(free_agents_count > 0, "expiring contracts should create free agents")

	var free_agents: Dictionary = world_state.get("free_agents", {}) as Dictionary
	var fa_list: Array = free_agents.get(2025, []) as Array
	t.assert_eq(fa_list.size(), free_agents_count, "free_agents array matches count")

	for player in fa_list:
		var p: Dictionary = player
		t.assert_eq(String(p.get("nfl_status", "")), "free_agent", "player status should be free_agent")
		t.assert_eq(int(p.get("free_agent_year", 0)), 2025, "free agent year set correctly")

func _test_determinism(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> void:
	var world_state_a := _make_world_state_with_rosters()
	var world_state_b := _make_world_state_with_rosters()
	var season_a := NflSeason.new()
	var season_b := NflSeason.new()

	var result_a := season_a.run(world_state_a, 2025, 99999, league_cfg, positions_cfg, main_cfg, stats_cfg)
	var result_b := season_b.run(world_state_b, 2025, 99999, league_cfg, positions_cfg, main_cfg, stats_cfg)

	t.assert_eq(int(result_a.get("retirements", 0)), int(result_b.get("retirements", 0)),
		"retirement count is deterministic")
	t.assert_eq(int(result_a.get("free_agents", 0)), int(result_b.get("free_agents", 0)),
		"free agent count is deterministic")
	t.assert_eq(int(result_a.get("total_players", 0)), int(result_b.get("total_players", 0)),
		"total players is deterministic")

func _test_empty_roster(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> void:
	var world_state := {
		"nfl_teams": [{"id": "nfl_001", "name": "Team 001"}],
		"nfl_rosters": {"nfl_001": {"players": []}},
		"retired_players": []
	}

	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, league_cfg, positions_cfg, main_cfg, stats_cfg)

	t.assert_eq(int(result.get("total_players", 0)), 0, "empty roster should have 0 players")
	t.assert_eq(int(result.get("retirements", 0)), 0, "empty roster should have 0 retirements")

func _collect_player_ages(world_state: Dictionary) -> Dictionary:
	var ages := {}
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			var player_id := String(p.get("player_id", ""))
			ages[player_id] = int(p.get("age", 0))
	return ages

func _make_world_state_with_rosters() -> Dictionary:
	var teams := [
		{"id": "nfl_001", "name": "Team 001"},
		{"id": "nfl_002", "name": "Team 002"}
	]

	var rosters := {
		"nfl_001": {
			"players": [
				_make_player("p1", "QB", 24, 3),
				_make_player("p2", "WR", 26, 2)
			],
			"by_position": {"QB": ["p1"], "WR": ["p2"]}
		},
		"nfl_002": {
			"players": [
				_make_player("p3", "RB", 25, 4)
			],
			"by_position": {"RB": ["p3"]}
		}
	}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"retired_players": []
	}

func _make_world_state_with_old_players() -> Dictionary:
	var teams := [
		{"id": "nfl_001", "name": "Team 001"}
	]

	var rosters := {
		"nfl_001": {
			"players": [
				_make_player("p1", "QB", 39, 2),  # Near max age
				_make_player("p2", "WR", 40, 1),  # At max age - will definitely retire
				_make_player("p3", "RB", 24, 4)   # Young
			],
			"by_position": {"QB": ["p1"], "WR": ["p2"], "RB": ["p3"]}
		}
	}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"retired_players": []
	}

func _make_world_state_with_expiring_contracts() -> Dictionary:
	var teams := [
		{"id": "nfl_001", "name": "Team 001"}
	]

	var rosters := {
		"nfl_001": {
			"players": [
				_make_player_with_contract("p1", "QB", 26, 1),  # Contract expires this year
				_make_player_with_contract("p2", "WR", 24, 3)   # Contract has years remaining
			],
			"by_position": {"QB": ["p1"], "WR": ["p2"]}
		}
	}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"retired_players": []
	}

func _make_player(player_id: String, pos: String, age: int, years_remaining: int) -> Dictionary:
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"age": age,
		"nfl_team_id": "nfl_001",
		"nfl_status": "active",
		"stats": {"speed": 75.0, "acceleration": 72.0, "agility": 70.0},
		"potential": {"speed": 80.0, "acceleration": 77.0, "agility": 75.0},
		"contract": {
			"type": "veteran",
			"years_total": 4,
			"years_remaining": years_remaining,
			"base_salary": 5.0,
			"annual_value": 5.5
		}
	}

func _make_player_with_contract(player_id: String, pos: String, age: int, years_remaining: int) -> Dictionary:
	return _make_player(player_id, pos, age, years_remaining)
