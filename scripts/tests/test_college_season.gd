extends RefCounted

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run(t) -> void:
	var config := ConfigService.new()
	var colleges_cfg := config.get_config("world/colleges")
	var positions_cfg := config.get_config("positions")
	var main_cfg := config.get_config("main")
	var stats_cfg := config.get_config("stats")

	# Test 1: Verify roster advancement (year 1→2→3→4)
	_test_roster_advancement(t, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 2: Verify eligibility transitions
	_test_eligibility_transitions(t, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 3: Verify draft pool output includes seniors + early declares
	_test_draft_pool_output(t, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	# Test 4: Assert determinism with fixed seed
	_test_determinism(t, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

func _test_roster_advancement(t, colleges_cfg: Dictionary, positions_cfg: Dictionary, main_cfg: Dictionary, stats_cfg: Dictionary) -> void:
	var world_state := _make_world_state_with_rosters()
	var season := CollegeSeason.new()
	var result := season.run(world_state, 2025, 12345, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	t.assert_eq(result.get("rosters_updated", 0), 2, "both rosters updated")

	var rosters: Dictionary = world_state.get("college_rosters", {})
	var c1_roster: Dictionary = rosters.get("c1", {})
	var c1_players: Array = c1_roster.get("players", [])

	# Freshman becomes sophomore
	var found_sophomore := false
	for p in c1_players:
		var player: Dictionary = p
		if String(player.get("player_id", "")) == "p1":
			t.assert_eq(player.get("college_year", 0), 2, "p1 advanced from year 1 to 2")
			found_sophomore = true
	t.assert_true(found_sophomore, "found advanced player in roster")

func _test_eligibility_transitions(t, colleges_cfg: Dictionary, positions_cfg: Dictionary, main_cfg: Dictionary, stats_cfg: Dictionary) -> void:
	var world_state := _make_world_state_with_rosters()
	var season := CollegeSeason.new()
	var _result := season.run(world_state, 2025, 12345, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	var rosters: Dictionary = world_state.get("college_rosters", {})
	var c1_roster: Dictionary = rosters.get("c1", {})
	var c1_players: Array = c1_roster.get("players", [])

	for p in c1_players:
		var player: Dictionary = p
		var player_id := String(player.get("player_id", ""))
		var college_year := int(player.get("college_year", 0))
		var status := String(player.get("college_eligibility_status", ""))

		match college_year:
			2:
				t.assert_eq(status, "sophomore", "%s should be sophomore" % player_id)
			3:
				t.assert_eq(status, "junior", "%s should be junior" % player_id)
			4:
				# Seniors should be in draft pool, not roster
				t.fail("senior %s should not be in active roster" % player_id)

func _test_draft_pool_output(t, colleges_cfg: Dictionary, positions_cfg: Dictionary, main_cfg: Dictionary, stats_cfg: Dictionary) -> void:
	var world_state := _make_world_state_with_seniors()
	var season := CollegeSeason.new()
	var result := season.run(world_state, 2025, 12345, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	var graduates := int(result.get("graduates", 0))
	t.assert_true(graduates > 0, "seniors graduated to draft pool")

	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var draft_eligible: Array = draft_pool.get(2025, [])
	t.assert_true(draft_eligible.size() > 0, "draft pool contains eligible players")

	for p in draft_eligible:
		var player: Dictionary = p
		t.assert_true(player.get("draft_eligible", false), "player marked as draft eligible")
		t.assert_eq(player.get("draft_year", 0), 2025, "draft year set correctly")

func _test_determinism(t, colleges_cfg: Dictionary, positions_cfg: Dictionary, main_cfg: Dictionary, stats_cfg: Dictionary) -> void:
	var world_state_a := _make_world_state_with_rosters()
	var world_state_b := _make_world_state_with_rosters()
	var season_a := CollegeSeason.new()
	var season_b := CollegeSeason.new()

	var result_a := season_a.run(world_state_a, 2025, 99999, colleges_cfg, positions_cfg, main_cfg, stats_cfg)
	var result_b := season_b.run(world_state_b, 2025, 99999, colleges_cfg, positions_cfg, main_cfg, stats_cfg)

	t.assert_eq(result_a.get("graduates", 0), result_b.get("graduates", 0), "graduate count is deterministic")
	t.assert_eq(result_a.get("draft_eligible_count", 0), result_b.get("draft_eligible_count", 0), "draft eligible count is deterministic")

	var rosters_a: Dictionary = world_state_a.get("college_rosters", {})
	var rosters_b: Dictionary = world_state_b.get("college_rosters", {})
	var c1_players_a: Array = (rosters_a.get("c1", {}) as Dictionary).get("players", [])
	var c1_players_b: Array = (rosters_b.get("c1", {}) as Dictionary).get("players", [])

	t.assert_eq(c1_players_a.size(), c1_players_b.size(), "roster sizes match deterministically")

func _make_world_state_with_rosters() -> Dictionary:
	var colleges := [
		{"id": "c1", "name": "College 1", "tier": "elite", "eliteness": 90.0, "region": "north"},
		{"id": "c2", "name": "College 2", "tier": "mid", "eliteness": 65.0, "region": "south"}
	]

	var rosters := {
		"c1": {
			"players": [
				_make_player("p1", "QB", 1, "freshman", 75.0),
				_make_player("p2", "WR", 2, "sophomore", 72.0)
			],
			"class_years": {
				1: ["p1"],
				2: ["p2"],
				3: [],
				4: []
			}
		},
		"c2": {
			"players": [
				_make_player("p3", "RB", 1, "freshman", 68.0)
			],
			"class_years": {
				1: ["p3"],
				2: [],
				3: [],
				4: []
			}
		}
	}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}

func _make_world_state_with_seniors() -> Dictionary:
	var colleges := [
		{"id": "c1", "name": "College 1", "tier": "elite", "eliteness": 90.0, "region": "north"}
	]

	var rosters := {
		"c1": {
			"players": [
				_make_player("p1", "QB", 3, "junior", 88.0),  # Will become senior
				_make_player("p2", "WR", 2, "sophomore", 72.0)
			],
			"class_years": {
				1: [],
				2: ["p2"],
				3: ["p1"],
				4: []
			}
		}
	}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}

func _make_player(player_id: String, pos: String, college_year: int, status: String, rating: float) -> Dictionary:
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"age": 18 + college_year,
		"college_id": "c1",
		"college_year": college_year,
		"college_eligibility_status": status,
		"stats": {"speed": rating, "acceleration": rating - 5.0, "agility": rating - 3.0},
		"potential": {"speed": rating + 5.0, "acceleration": rating, "agility": rating + 2.0},
		"composite_score": rating
	}
