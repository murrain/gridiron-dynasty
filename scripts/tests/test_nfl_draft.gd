extends RefCounted

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run(t) -> void:
	var config := ConfigService.new()
	var league_cfg := config.get_config("world/league")
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var main_cfg := config.get_config("main")

	# Test 1: Verify all picks made (rounds × teams)
	_test_all_picks_made(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 2: Verify players assigned to correct rosters
	_test_roster_assignment(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 3: Verify undrafted pool contains remaining players
	_test_undrafted_pool(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 4: Assert determinism with fixed seed
	_test_determinism(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 5: Verify rookie contracts
	_test_rookie_contracts(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

func _test_all_picks_made(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(league_cfg.get("team_count", 32))
	var expected_picks := rounds * teams_count

	var picks: Array = result.get("picks", []) as Array
	t.assert_eq(picks.size(), expected_picks, "all %d picks should be made" % expected_picks)

func _test_roster_assignment(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	var total_players := 0

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id] as Dictionary
		var players: Array = roster.get("players", []) as Array
		total_players += players.size()

		for player in players:
			var p: Dictionary = player
			t.assert_eq(String(p.get("nfl_team_id", "")), team_id, "player assigned to correct team")
			t.assert_true(p.has("contract"), "player should have contract")
			t.assert_true(p.has("draft_info"), "player should have draft info")

	t.assert_true(total_players > 0, "players should be assigned to rosters")

func _test_undrafted_pool(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	# Create more players than draft picks
	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(league_cfg.get("team_count", 32))
	var total_picks := rounds * teams_count
	var pool_size := total_picks + 100

	var world_state := _make_world_state_with_draft_pool(pool_size)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var undrafted_count := int(result.get("undrafted_count", 0))
	t.assert_eq(undrafted_count, pool_size - total_picks, "undrafted pool should contain remaining players")

	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {}) as Dictionary
	var undrafted: Array = undrafted_pool.get(2025, []) as Array
	t.assert_eq(undrafted.size(), undrafted_count, "undrafted pool array size matches count")

func _test_determinism(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state_a := _make_world_state_with_draft_pool(100)
	var world_state_b := _make_world_state_with_draft_pool(100)
	var draft_a := NflDraft.new()
	var draft_b := NflDraft.new()

	var result_a := draft_a.run(world_state_a, 2025, 99999, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)
	var result_b := draft_b.run(world_state_b, 2025, 99999, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var picks_a: Array = result_a.get("picks", []) as Array
	var picks_b: Array = result_b.get("picks", []) as Array

	t.assert_eq(picks_a.size(), picks_b.size(), "pick count is deterministic")

	for i in range(min(picks_a.size(), picks_b.size())):
		var pa: Dictionary = picks_a[i]
		var pb: Dictionary = picks_b[i]
		t.assert_eq(String(pa.get("player_id", "")), String(pb.get("player_id", "")),
			"pick %d player_id is deterministic" % (i + 1))
		t.assert_eq(String(pa.get("team_id", "")), String(pb.get("team_id", "")),
			"pick %d team_id is deterministic" % (i + 1))

func _test_rookie_contracts(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(50)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var picks: Array = result.get("picks", []) as Array
	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	# Check first round pick has fifth year option
	var first_pick := picks[0] as Dictionary
	var team_id := String(first_pick.get("team_id", ""))
	var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
	var players: Array = roster.get("players", []) as Array

	for p in players:
		var player: Dictionary = p
		var draft_info: Dictionary = player.get("draft_info", {}) as Dictionary
		var contract: Dictionary = player.get("contract", {}) as Dictionary

		if int(draft_info.get("round", 0)) == 1:
			t.assert_true(bool(contract.get("fifth_year_option", false)),
				"first round pick should have fifth year option")

		t.assert_eq(String(contract.get("type", "")), "rookie", "contract type should be rookie")
		t.assert_eq(int(contract.get("years_total", 0)), 4, "rookie contract should be 4 years")

func _make_world_state_with_draft_pool(pool_size: int) -> Dictionary:
	# Create NFL teams
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

	# Create draft pool
	var draft_pool: Array = []
	var positions: Array = ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
	for i in range(pool_size):
		var pos := String(positions[i % positions.size()])
		draft_pool.append(_make_draft_player("dp_%04d" % (i + 1), pos, 70.0 + randf() * 20.0))

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
