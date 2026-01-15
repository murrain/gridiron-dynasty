## GdUnit4 test suite for NflSeason
##
## Validates NFL season progression, retirement, and contracts.
## Migrated from test_nfl_season.gd
extends GdUnitTestSuite

const NflSeason = preload("res://scripts/world/NflSeason.gd")
const ConfigService = preload("res://autoloads/Config.gd")


var _league_cfg: Dictionary
var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _stats_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_league_cfg = config.get_config("world/league")
	_positions_cfg = config.get_config("positions")
	_main_cfg = config.get_config("main")
	_stats_cfg = config.get_config("stats")


func test_roster_advancement() -> void:
	var world_state := _make_world_state_with_rosters()
	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	assert_bool(not rosters.is_empty()).is_true()


func test_age_increases_by_one() -> void:
	var world_state := _make_world_state_with_rosters()
	var original_ages := _collect_player_ages(world_state)

	var season := NflSeason.new()
	var _result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			var player_id := String(p.get("player_id", ""))
			if original_ages.has(player_id):
				var new_age := int(p.get("age", 0))
				var old_age := int(original_ages[player_id])
				assert_int(new_age).is_equal(old_age + 1)


func test_old_players_retire() -> void:
	var world_state := _make_world_state_with_old_players()
	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var retirements := int(result.get("retirements", 0))
	assert_int(retirements).is_greater(0)


func test_retired_players_array_matches_count() -> void:
	var world_state := _make_world_state_with_old_players()
	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var retirements := int(result.get("retirements", 0))
	var retired: Array = world_state.get("retired_players", []) as Array
	assert_int(retired.size()).is_equal(retirements)


func test_retired_player_has_retirement_year() -> void:
	var world_state := _make_world_state_with_old_players()
	var season := NflSeason.new()
	var _result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var retired: Array = world_state.get("retired_players", []) as Array
	for player in retired:
		var p: Dictionary = player
		assert_int(int(p.get("retirement_year", 0))).is_equal(2025)


func test_expiring_contracts_create_free_agents() -> void:
	var world_state := _make_world_state_with_expiring_contracts()
	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var free_agents_count := int(result.get("free_agents", 0))
	assert_int(free_agents_count).is_greater(0)


func test_free_agent_status_set_correctly() -> void:
	var world_state := _make_world_state_with_expiring_contracts()
	var season := NflSeason.new()
	var _result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var free_agents: Dictionary = world_state.get("free_agents", {}) as Dictionary
	var fa_list: Array = free_agents.get(2025, []) as Array

	for player in fa_list:
		var p: Dictionary = player
		assert_str(String(p.get("nfl_status", ""))).is_equal("free_agent")


func test_determinism() -> void:
	var world_state_a := _make_world_state_with_rosters()
	var world_state_b := _make_world_state_with_rosters()
	var season_a := NflSeason.new()
	var season_b := NflSeason.new()

	var result_a := season_a.run(world_state_a, 2025, 99999, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)
	var result_b := season_b.run(world_state_b, 2025, 99999, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	assert_int(int(result_a.get("retirements", 0))).is_equal(int(result_b.get("retirements", 0)))
	assert_int(int(result_a.get("free_agents", 0))).is_equal(int(result_b.get("free_agents", 0)))
	assert_int(int(result_a.get("total_players", 0))).is_equal(int(result_b.get("total_players", 0)))


func test_empty_roster_handling() -> void:
	var world_state := {
		"nfl_teams": [{"id": "nfl_001", "name": "Team 001"}],
		"nfl_rosters": {"nfl_001": {"players": []}},
		"retired_players": []
	}

	var season := NflSeason.new()
	var result := season.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	assert_int(int(result.get("total_players", 0))).is_equal(0)
	assert_int(int(result.get("retirements", 0))).is_equal(0)


# --- Helper functions ---

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
			"players": [_make_player("p3", "RB", 25, 4)],
			"by_position": {"RB": ["p3"]}
		}
	}

	return {"nfl_teams": teams, "nfl_rosters": rosters, "retired_players": []}


func _make_world_state_with_old_players() -> Dictionary:
	var teams := [{"id": "nfl_001", "name": "Team 001"}]

	var rosters := {
		"nfl_001": {
			"players": [
				_make_player("p1", "QB", 39, 2),
				_make_player("p2", "WR", 40, 1),
				_make_player("p3", "RB", 24, 4)
			],
			"by_position": {"QB": ["p1"], "WR": ["p2"], "RB": ["p3"]}
		}
	}

	return {"nfl_teams": teams, "nfl_rosters": rosters, "retired_players": []}


func _make_world_state_with_expiring_contracts() -> Dictionary:
	var teams := [{"id": "nfl_001", "name": "Team 001"}]

	var rosters := {
		"nfl_001": {
			"players": [
				_make_player("p1", "QB", 26, 1),
				_make_player("p2", "WR", 24, 3)
			],
			"by_position": {"QB": ["p1"], "WR": ["p2"]}
		}
	}

	return {"nfl_teams": teams, "nfl_rosters": rosters, "retired_players": []}


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
