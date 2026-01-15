## GdUnit4 test suite for CollegeSeason
##
## Validates college season progression, eligibility, and draft pool output.
## Migrated from test_college_season.gd
extends GdUnitTestSuite

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const ConfigService = preload("res://autoloads/Config.gd")


var _colleges_cfg: Dictionary
var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _stats_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_colleges_cfg = config.get_config("world/colleges")
	_positions_cfg = config.get_config("positions")
	_main_cfg = config.get_config("main")
	_stats_cfg = config.get_config("stats")


func test_roster_advancement() -> void:
	var world_state := _make_world_state_with_rosters()
	var season := CollegeSeason.new()
	var result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	assert_int(int(result.get("rosters_updated", 0))).is_equal(2)


func test_player_advances_from_year_1_to_2() -> void:
	var world_state := _make_world_state_with_rosters()
	var season := CollegeSeason.new()
	var _result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var rosters: Dictionary = world_state.get("college_rosters", {})
	var c1_roster: Dictionary = rosters.get("c1", {})
	var c1_players: Array = c1_roster.get("players", [])

	var found_advanced := false
	for p in c1_players:
		var player: Dictionary = p
		if String(player.get("player_id", "")) == "p1":
			assert_int(int(player.get("college_year", 0))).is_equal(2)
			found_advanced = true

	assert_bool(found_advanced).is_true()


func test_eligibility_status_sophomore() -> void:
	var world_state := _make_world_state_with_rosters()
	var season := CollegeSeason.new()
	var _result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var rosters: Dictionary = world_state.get("college_rosters", {})
	var c1_roster: Dictionary = rosters.get("c1", {})
	var c1_players: Array = c1_roster.get("players", [])

	for p in c1_players:
		var player: Dictionary = p
		var college_year := int(player.get("college_year", 0))
		var status := String(player.get("college_eligibility_status", ""))
		if college_year == 2:
			assert_str(status).is_equal("sophomore")


func test_seniors_graduate_to_draft_pool() -> void:
	var world_state := _make_world_state_with_seniors()
	var season := CollegeSeason.new()
	var result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var graduates := int(result.get("graduates", 0))
	assert_int(graduates).is_greater(0)


func test_draft_pool_contains_eligible_players() -> void:
	var world_state := _make_world_state_with_seniors()
	var season := CollegeSeason.new()
	var _result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var draft_eligible: Array = draft_pool.get(2025, [])
	assert_int(draft_eligible.size()).is_greater(0)


func test_draft_eligible_players_marked_correctly() -> void:
	var world_state := _make_world_state_with_seniors()
	var season := CollegeSeason.new()
	var _result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var draft_eligible: Array = draft_pool.get(2025, [])

	for p in draft_eligible:
		var player: Dictionary = p
		assert_bool(player.get("draft_eligible", false)).is_true()
		assert_int(int(player.get("draft_year", 0))).is_equal(2025)


func test_determinism() -> void:
	var world_state_a := _make_world_state_with_rosters()
	var world_state_b := _make_world_state_with_rosters()
	var season_a := CollegeSeason.new()
	var season_b := CollegeSeason.new()

	var result_a := season_a.run(world_state_a, 2025, 99999, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)
	var result_b := season_b.run(world_state_b, 2025, 99999, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	assert_int(int(result_a.get("graduates", 0))).is_equal(int(result_b.get("graduates", 0)))
	assert_int(int(result_a.get("draft_eligible_count", 0))).is_equal(int(result_b.get("draft_eligible_count", 0)))


func test_draft_threshold_filters_low_rated() -> void:
	var world_state := _make_world_state_with_varied_seniors()
	var season := CollegeSeason.new()
	var _result := season.run(world_state, 2025, 12345, _colleges_cfg, _positions_cfg, _main_cfg, _stats_cfg)

	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var draft_eligible: Array = draft_pool.get(2025, [])

	# Only players with rating >= 65 should be in draft pool
	assert_int(draft_eligible.size()).is_equal(2)


# --- Helper functions ---

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
			"class_years": {1: ["p1"], 2: ["p2"], 3: [], 4: []}
		},
		"c2": {
			"players": [_make_player("p3", "RB", 1, "freshman", 68.0)],
			"class_years": {1: ["p3"], 2: [], 3: [], 4: []}
		}
	}

	return {"colleges": colleges, "college_rosters": rosters, "draft_pool": {}}


func _make_world_state_with_seniors() -> Dictionary:
	var colleges := [{"id": "c1", "name": "College 1", "tier": "elite", "eliteness": 90.0, "region": "north"}]

	var rosters := {
		"c1": {
			"players": [
				_make_player("p1", "QB", 3, "junior", 88.0),
				_make_player("p2", "WR", 2, "sophomore", 72.0)
			],
			"class_years": {1: [], 2: ["p2"], 3: ["p1"], 4: []}
		}
	}

	return {"colleges": colleges, "college_rosters": rosters, "draft_pool": {}}


func _make_world_state_with_varied_seniors() -> Dictionary:
	var colleges := [{"id": "c1", "name": "College 1", "tier": "elite", "eliteness": 90.0, "region": "north"}]

	var rosters := {
		"c1": {
			"players": [
				_make_player("p_high", "QB", 3, "junior", 88.0),
				_make_player("p_mid", "WR", 3, "junior", 65.0),
				_make_player("p_low", "RB", 3, "junior", 60.0),
				_make_player("p_very_low", "TE", 3, "junior", 50.0)
			],
			"class_years": {1: [], 2: [], 3: ["p_high", "p_mid", "p_low", "p_very_low"], 4: []}
		}
	}

	return {"colleges": colleges, "college_rosters": rosters, "draft_pool": {}}


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
