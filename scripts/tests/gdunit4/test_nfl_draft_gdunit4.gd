## GdUnit4 test suite for NflDraft
##
## Validates NFL draft execution, pick ordering, roster assignment, and contracts.
## Migrated from test_nfl_draft.gd
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")


var _league_cfg: Dictionary
var _positions_cfg: Dictionary
var _stats_cfg: Dictionary
var _scouts_cfg: Dictionary
var _main_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_league_cfg = config.get_config("world/league")
	_positions_cfg = config.get_config("positions")
	_stats_cfg = config.get_config("stats")
	_scouts_cfg = config.get_config("scouts")
	_main_cfg = config.get_config("main")


func test_all_picks_made() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_cfg: Dictionary = _league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(_league_cfg.get("team_count", 32))
	var expected_picks := rounds * teams_count

	var picks: Array = result.get("picks", []) as Array
	assert_int(picks.size()).is_equal(expected_picks)


func test_players_assigned_to_correct_teams() -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id] as Dictionary
		var players: Array = roster.get("players", []) as Array

		for player in players:
			var p: Dictionary = player
			assert_str(String(p.get("nfl_team_id", ""))).is_equal(team_id)


func test_drafted_players_have_contracts() -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id] as Dictionary
		var players: Array = roster.get("players", []) as Array

		for player in players:
			var p: Dictionary = player
			assert_bool(p.has("contract")).is_true()


func test_drafted_players_have_draft_info() -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id] as Dictionary
		var players: Array = roster.get("players", []) as Array

		for player in players:
			var p: Dictionary = player
			assert_bool(p.has("draft_info")).is_true()


func test_undrafted_pool_contains_remaining_players() -> void:
	var draft_cfg: Dictionary = _league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(_league_cfg.get("team_count", 32))
	var total_picks := rounds * teams_count
	var pool_size := total_picks + 100

	var world_state := _make_world_state_with_draft_pool(pool_size)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var undrafted_count := int(result.get("undrafted_count", 0))
	assert_int(undrafted_count).is_equal(pool_size - total_picks)


func test_undrafted_pool_array_size_matches_count() -> void:
	var draft_cfg: Dictionary = _league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(_league_cfg.get("team_count", 32))
	var total_picks := rounds * teams_count
	var pool_size := total_picks + 100

	var world_state := _make_world_state_with_draft_pool(pool_size)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var undrafted_count := int(result.get("undrafted_count", 0))
	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {}) as Dictionary
	var undrafted: Array = undrafted_pool.get(2025, []) as Array
	assert_int(undrafted.size()).is_equal(undrafted_count)


func test_draft_is_deterministic() -> void:
	var world_state_a := _make_world_state_with_draft_pool(100)
	var world_state_b := _make_world_state_with_draft_pool(100)
	var draft_a := NflDraft.new()
	var draft_b := NflDraft.new()

	var result_a := draft_a.run(world_state_a, 2025, 99999, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)
	var result_b := draft_b.run(world_state_b, 2025, 99999, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var picks_a: Array = result_a.get("picks", []) as Array
	var picks_b: Array = result_b.get("picks", []) as Array

	assert_int(picks_a.size()).is_equal(picks_b.size())

	for i in range(min(picks_a.size(), picks_b.size())):
		var pa: Dictionary = picks_a[i]
		var pb: Dictionary = picks_b[i]
		assert_str(String(pa.get("player_id", ""))).is_equal(String(pb.get("player_id", "")))
		assert_str(String(pa.get("team_id", ""))).is_equal(String(pb.get("team_id", "")))


func test_first_round_pick_has_fifth_year_option() -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var picks: Array = result.get("picks", []) as Array
	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	var first_pick := picks[0] as Dictionary
	var team_id := String(first_pick.get("team_id", ""))
	var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
	var players: Array = roster.get("players", []) as Array

	for p in players:
		var player: Dictionary = p
		var draft_info: Dictionary = player.get("draft_info", {}) as Dictionary
		var contract: Dictionary = player.get("contract", {}) as Dictionary

		if int(draft_info.get("round", 0)) == 1:
			assert_bool(bool(contract.get("fifth_year_option", false))).is_true()


func test_rookie_contract_type() -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id] as Dictionary
		var players: Array = roster.get("players", []) as Array

		for player in players:
			var p: Dictionary = player
			var contract: Dictionary = p.get("contract", {}) as Dictionary
			assert_str(String(contract.get("type", ""))).is_equal("rookie")


func test_rookie_contract_four_years() -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id] as Dictionary
		var players: Array = roster.get("players", []) as Array

		for player in players:
			var p: Dictionary = player
			var contract: Dictionary = p.get("contract", {}) as Dictionary
			assert_int(int(contract.get("years_total", 0))).is_equal(4)


# --- Helper functions ---

func _make_world_state_with_draft_pool(pool_size: int) -> Dictionary:
	var teams: Array = []
	for i in range(32):
		teams.append({
			"id": "nfl_%03d" % (i + 1),
			"name": "Team %03d" % (i + 1),
			"region": "afc_east",
			"cap_space": 200.0,
			"roster": [],
			"draft_order": i + 1
		})

	var draft_pool: Array = []
	var positions: Array[String] = ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
	var pool_rng := RandomNumberGenerator.new()
	pool_rng.seed = 55555
	for i in range(pool_size):
		var pos: String = positions[i % positions.size()]
		draft_pool.append(_make_draft_player("dp_%04d" % (i + 1), pos, 70.0 + pool_rng.randf() * 20.0))

	return {
		"nfl_teams": teams,
		"nfl_rosters": {},
		"draft_pool": {2025: draft_pool}
	}


func _make_draft_player(player_id: String, pos: String, rating: float) -> Dictionary:
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"age": 22,
		"draft_eligible": true,
		"draft_year": 2025,
		"stats": {"speed": rating, "acceleration": rating - 5.0, "agility": rating - 3.0},
		"potential": {"speed": rating + 5.0, "acceleration": rating, "agility": rating + 2.0},
		"composite_score": rating
	}
