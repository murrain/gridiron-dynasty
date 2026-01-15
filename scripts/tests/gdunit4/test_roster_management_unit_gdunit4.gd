## GdUnit4 test suite for RosterManagement
##
## Tests roster management logic including release candidates, cap calculations,
## and release execution.
## Migrated from test_roster_management_unit.gd
extends GdUnitTestSuite

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")


func test_identify_release_candidates_finds_correct_count() -> void:
	var players := _make_test_players()

	var candidates := RosterManagement._identify_release_candidates(
		players,
		0.15, # market_value_multiplier
		1.5,  # value_threshold
		0.02, # age_decline_factor
		2025  # current_year
	)

	# Should identify 3 candidates (excluding only the protected rookie)
	assert_int(candidates.size()).is_equal(3)


func test_identify_release_candidates_protects_rookies() -> void:
	var players := _make_test_players()

	var candidates := RosterManagement._identify_release_candidates(
		players,
		0.15,
		1.5,
		0.02,
		2025
	)

	# Check that rookie is NOT in candidates
	var has_rookie := false
	for c in candidates:
		if String(c.get("player_id", "")) == "p3":
			has_rookie = true

	assert_bool(has_rookie).is_false()


func test_calculate_team_cap_usage_sums_correctly() -> void:
	var players := [
		{"contract": {"annual_value": 10.0}},
		{"contract": {"annual_value": 15.0}},
		{"contract": {"annual_value": 5.0}},
		{"contract": {}}  # No contract
	]

	var total := RosterManagement._calculate_team_cap_usage(players)

	assert_float(total).is_equal_approx(30.0, 0.01)


func test_execute_releases_removes_player_from_roster() -> void:
	var world_state := _make_test_world_state()

	var releases := [
		{
			"player_id": "p2",
			"team_id": "team_001",
			"year": 2025,
			"reason": "cap_efficiency",
			"annual_value": 10.0,
			"dead_cap": 0.0,
			"net_savings": 10.0
		}
	]

	RosterManagement._execute_releases(world_state, "team_001", releases, 2025)

	var roster: Dictionary = world_state["nfl_rosters"]["team_001"]
	var remaining: Array = roster["players"]

	assert_int(remaining.size()).is_equal(2)


func test_execute_releases_adds_player_to_fa_pool() -> void:
	var world_state := _make_test_world_state()

	var releases := [
		{
			"player_id": "p2",
			"team_id": "team_001",
			"year": 2025,
			"reason": "cap_efficiency",
			"annual_value": 10.0,
			"dead_cap": 0.0,
			"net_savings": 10.0
		}
	]

	RosterManagement._execute_releases(world_state, "team_001", releases, 2025)

	var fa_pool: Dictionary = world_state.get("free_agents", {})
	var year_fas: Array = fa_pool.get(2025, [])

	assert_int(year_fas.size()).is_equal(1)


func test_execute_releases_correct_player_in_fa_pool() -> void:
	var world_state := _make_test_world_state()

	var releases := [
		{
			"player_id": "p2",
			"team_id": "team_001",
			"year": 2025,
			"reason": "cap_efficiency",
			"annual_value": 10.0,
			"dead_cap": 0.0,
			"net_savings": 10.0
		}
	]

	RosterManagement._execute_releases(world_state, "team_001", releases, 2025)

	var fa_pool: Dictionary = world_state.get("free_agents", {})
	var year_fas: Array = fa_pool.get(2025, [])
	var released_player: Dictionary = year_fas[0]

	assert_str(String(released_player.get("id", ""))).is_equal("p2")


func test_calculate_dead_cap_placeholder_returns_zero() -> void:
	var player := {
		"contract": {
			"annual_value": 10.0
		}
	}

	var dead_cap := RosterManagement._calculate_dead_cap(player)

	assert_float(dead_cap).is_equal(0.0)


# --- Helper functions ---

func _make_test_players() -> Array:
	return [
		{
			"id": "p1",
			"name": "High Cap Low Value",
			"position": "WR",
			"age": 32,
			"eval_score": 55.0,
			"draft_year": 2010,
			"contract": {
				"annual_value": 15.0,
				"signed_year": 2015,
				"years_remaining": 1
			}
		},
		{
			"id": "p2",
			"name": "Good Value",
			"position": "QB",
			"age": 27,
			"eval_score": 85.0,
			"draft_year": 2018,
			"contract": {
				"annual_value": 10.0,
				"signed_year": 2022,
				"years_remaining": 2
			}
		},
		{
			"id": "p3",
			"name": "Rookie",
			"position": "RB",
			"age": 22,
			"eval_score": 70.0,
			"draft_year": 2023,
			"contract": {
				"annual_value": 2.0,
				"signed_year": 2023,
				"years_remaining": 3
			}
		},
		{
			"id": "p4",
			"name": "Overpaid Vet",
			"position": "OL",
			"age": 34,
			"eval_score": 60.0,
			"draft_year": 2012,
			"contract": {
				"annual_value": 12.0,
				"signed_year": 2018,
				"years_remaining": 1
			}
		}
	]


func _make_test_world_state() -> Dictionary:
	return {
		"nfl_rosters": {
			"team_001": {
				"players": [
					{"id": "p1", "name": "Player 1", "contract": {}},
					{"id": "p2", "name": "Player 2", "contract": {}},
					{"id": "p3", "name": "Player 3", "contract": {}}
				]
			}
		},
		"free_agents": {}
	}
