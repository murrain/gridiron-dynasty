## GdUnit4 test suite for OptimizedPlayerQueries
##
## Tests in-memory indexed player queries for runtime performance:
## - Index building and clearing
## - O(1) lookups (by_id, by_position, by_team, by_stage)
## - Position group queries
## - Free agent and draft eligible queries
## - Age bucket categorization
## - Team roster queries
## - Filter utilities
## - Deterministic results
##
## RNG: No RNG consumption - all queries are deterministic pure functions
extends GdUnitTestSuite

const OptimizedPlayerQueries = preload("res://scripts/queries/OptimizedPlayerQueries.gd")
const Player = preload("res://scripts/core/models/Player.gd")


# =========================
# Helper Functions
# =========================

func _create_test_player(id: String, position: String, age: int, stage: int) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"age": age,
		"stage": stage,
		"first_name": "Test",
		"last_name": "Player"
	}


func _create_world_state_with_players() -> Dictionary:
	return {
		"nfl_rosters": {
			"team_a": {
				"players": [
					_create_test_player("p1", "QB", 25, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p2", "QB", 22, Player.PlayerStage.NFL_ROOKIE),
					_create_test_player("p3", "RB", 28, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p4", "WR", 24, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p5", "OT", 30, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p6", "CB", 26, Player.PlayerStage.NFL_VETERAN),
				]
			},
			"team_b": {
				"players": [
					_create_test_player("p7", "QB", 32, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p8", "DT", 27, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p9", "LB", 29, Player.PlayerStage.NFL_VETERAN),
					_create_test_player("p10", "K", 35, Player.PlayerStage.NFL_VETERAN),
				]
			}
		},
		"college_rosters": {
			"college_x": {
				"players": [
					_create_test_player("c1", "QB", 21, Player.PlayerStage.COLLEGE),
					_create_test_player("c2", "WR", 20, Player.PlayerStage.COLLEGE),
				]
			}
		},
		"free_agents": [
			_create_test_player("fa1", "RB", 31, Player.PlayerStage.NFL_FREE_AGENT),
			_create_test_player("fa2", "TE", 29, Player.PlayerStage.NFL_FREE_AGENT),
		],
		"draft_pool": [
			_create_test_player("d1", "QB", 22, Player.PlayerStage.DRAFT_ELIGIBLE),
			_create_test_player("d2", "CB", 21, Player.PlayerStage.DRAFT_ELIGIBLE),
		]
	}


# =========================
# Index Building Tests
# =========================

func test_rebuild_indexes_clears_previous_data() -> void:
	var queries := OptimizedPlayerQueries.new()

	# Build with first world state
	var world1 := {"nfl_rosters": {"t1": {"players": [_create_test_player("p1", "QB", 25, 4)]}}}
	queries.rebuild_indexes(world1)
	assert_int(queries.count()).is_equal(1)

	# Rebuild with different world state
	var world2 := {"nfl_rosters": {"t2": {"players": [_create_test_player("p2", "RB", 26, 4)]}}}
	queries.rebuild_indexes(world2)

	# Should only have new player
	assert_int(queries.count()).is_equal(1)
	assert_object(queries.by_id("p1")).is_null()
	assert_object(queries.by_id("p2")).is_not_null()


func test_rebuild_indexes_handles_empty_world_state() -> void:
	var queries := OptimizedPlayerQueries.new()
	queries.rebuild_indexes({})

	assert_int(queries.count()).is_equal(0)
	assert_array(queries.all_players()).is_empty()


func test_rebuild_indexes_handles_nfl_rosters() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# team_a has 6 players, team_b has 4 players
	assert_int(queries.count_by_team("team_a")).is_equal(6)
	assert_int(queries.count_by_team("team_b")).is_equal(4)


func test_rebuild_indexes_handles_college_rosters() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_int(queries.count_by_team("college_x")).is_equal(2)


func test_rebuild_indexes_handles_free_agents() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_int(queries.get_free_agents().size()).is_equal(2)


func test_rebuild_indexes_handles_draft_pool() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_int(queries.get_draft_eligible().size()).is_equal(2)


func test_rebuild_indexes_handles_array_format_rosters() -> void:
	# Test that rosters can be arrays directly (not wrapped in dict with "players" key)
	var queries := OptimizedPlayerQueries.new()
	var world := {
		"nfl_rosters": {
			"team_direct": [
				_create_test_player("pd1", "QB", 25, 4),
				_create_test_player("pd2", "RB", 26, 4)
			]
		}
	}
	queries.rebuild_indexes(world)

	assert_int(queries.count_by_team("team_direct")).is_equal(2)


# =========================
# Primary Query Tests (O(1) lookups)
# =========================

func test_by_id_returns_player() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var player = queries.by_id("p1")
	assert_object(player).is_not_null()
	assert_str(player["id"]).is_equal("p1")
	assert_str(player["position"]).is_equal("QB")


func test_by_id_returns_null_for_unknown() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var player = queries.by_id("nonexistent")
	assert_object(player).is_null()


func test_by_position_returns_correct_players() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# 3 QBs in NFL (p1, p2, p7), 1 in college (c1), 1 draft eligible (d1)
	var qbs := queries.by_position("QB")
	assert_int(qbs.size()).is_equal(5)

	# Verify all are QBs
	for player in qbs:
		assert_str(player["position"]).is_equal("QB")


func test_by_position_returns_empty_for_nonexistent() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var punters := queries.by_position("P")
	assert_array(punters).is_empty()


func test_by_team_returns_correct_players() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var team_a := queries.by_team("team_a")
	assert_int(team_a.size()).is_equal(6)

	# Verify all belong to team (indirectly by checking specific known players)
	var ids := []
	for p in team_a:
		ids.append(p["id"])
	assert_array(ids).contains(["p1", "p2", "p3", "p4", "p5", "p6"])


func test_by_team_returns_empty_for_nonexistent() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var unknown := queries.by_team("unknown_team")
	assert_array(unknown).is_empty()


func test_by_stage_returns_correct_players() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var college := queries.by_stage(Player.PlayerStage.COLLEGE)
	assert_int(college.size()).is_equal(2)

	var rookies := queries.by_stage(Player.PlayerStage.NFL_ROOKIE)
	assert_int(rookies.size()).is_equal(1)

	var draft_eligible := queries.by_stage(Player.PlayerStage.DRAFT_ELIGIBLE)
	assert_int(draft_eligible.size()).is_equal(2)


# =========================
# Age Bucket Tests
# =========================

func test_age_bucket_young_classification() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var young := queries.by_age_bucket("young")
	# Age <= 24: p2(22), p4(24), c1(21), c2(20), d1(22), d2(21)
	assert_int(young.size()).is_equal(6)

	for player in young:
		assert_int(player["age"]).is_less_equal(24)


func test_age_bucket_prime_classification() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var prime := queries.by_age_bucket("prime")
	# Age 25-30: p1(25), p3(28), p6(26), p8(27), p9(29), p5(30), fa2(29)
	assert_int(prime.size()).is_equal(7)

	for player in prime:
		var age: int = player["age"]
		assert_bool(age >= 25 and age <= 30).is_true()


func test_age_bucket_veteran_classification() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var veteran := queries.by_age_bucket("veteran")
	# Age > 30: p7(32), p10(35), fa1(31)
	assert_int(veteran.size()).is_equal(3)

	for player in veteran:
		assert_int(player["age"]).is_greater(30)


# =========================
# Position Group Query Tests
# =========================

func test_get_quarterbacks() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var qbs := queries.get_quarterbacks()
	assert_int(qbs.size()).is_equal(5)


func test_get_offensive_line() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# Only p5 (OT) in our test data
	var ol := queries.get_offensive_line()
	assert_int(ol.size()).is_equal(1)
	assert_str(ol[0]["position"]).is_equal("OT")


func test_get_defensive_line() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# p8 (DT) in our test data
	var dl := queries.get_defensive_line()
	assert_int(dl.size()).is_equal(1)


func test_get_linebackers() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# p9 (LB) in our test data
	var lbs := queries.get_linebackers()
	assert_int(lbs.size()).is_equal(1)


func test_get_secondary() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# p6 (CB) and d2 (CB) in our test data
	var secondary := queries.get_secondary()
	assert_int(secondary.size()).is_equal(2)


func test_get_skill_positions() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# QB: p1,p2,p7,c1,d1 (5), RB: p3,fa1 (2), WR: p4,c2 (2), TE: fa2 (1)
	var skills := queries.get_skill_positions()
	assert_int(skills.size()).is_equal(10)


func test_get_special_teams() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# p10 (K) in our test data
	var st := queries.get_special_teams()
	assert_int(st.size()).is_equal(1)


func test_get_offense() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var offense := queries.get_offense()
	# All offensive positions combined
	# QB(5) + RB(2) + WR(2) + TE(1) + OT(1) = 11
	assert_int(offense.size()).is_equal(11)


func test_get_defense() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var defense := queries.get_defense()
	# DT(1) + LB(1) + CB(2) = 4
	assert_int(defense.size()).is_equal(4)


# =========================
# Team Roster Query Tests
# =========================

func test_get_team_roster_by_group() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var grouped := queries.get_team_roster_by_group("team_a")

	assert_bool(grouped.has("offense")).is_true()
	assert_bool(grouped.has("defense")).is_true()
	assert_bool(grouped.has("special_teams")).is_true()

	# team_a: QB(2) + RB(1) + WR(1) + OT(1) = 5 offense, CB(1) = 1 defense
	assert_int(grouped["offense"].size()).is_equal(5)
	assert_int(grouped["defense"].size()).is_equal(1)
	assert_int(grouped["special_teams"].size()).is_equal(0)


func test_get_team_position() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var team_a_qbs := queries.get_team_position("team_a", "QB")
	assert_int(team_a_qbs.size()).is_equal(2)

	var team_b_qbs := queries.get_team_position("team_b", "QB")
	assert_int(team_b_qbs.size()).is_equal(1)


# =========================
# Aggregate Method Tests
# =========================

func test_all_players_returns_all() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	# Total: 10 NFL + 2 college + 2 free agents + 2 draft = 16
	var all := queries.all_players()
	assert_int(all.size()).is_equal(16)


func test_count_returns_total() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_int(queries.count()).is_equal(16)


func test_count_by_position() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_int(queries.count_by_position("QB")).is_equal(5)
	assert_int(queries.count_by_position("RB")).is_equal(2)
	assert_int(queries.count_by_position("P")).is_equal(0)


func test_count_by_team() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_int(queries.count_by_team("team_a")).is_equal(6)
	assert_int(queries.count_by_team("team_b")).is_equal(4)
	assert_int(queries.count_by_team("unknown")).is_equal(0)


func test_get_indexed_positions() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var positions := queries.get_indexed_positions()
	assert_array(positions).contains(["QB", "RB", "WR", "OT", "CB", "DT", "LB", "K", "TE"])


func test_get_indexed_teams() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var teams := queries.get_indexed_teams()
	assert_array(teams).contains(["team_a", "team_b", "college_x"])


# =========================
# Filter Utility Tests
# =========================

func test_filter_by_min_age() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var all := queries.all_players()
	var aged_30_plus := queries.filter_by_min_age(all, 30)

	# p5(30), p7(32), p10(35), fa1(31)
	assert_int(aged_30_plus.size()).is_equal(4)
	for player in aged_30_plus:
		assert_int(player["age"]).is_greater_equal(30)


func test_filter_by_max_age() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var all := queries.all_players()
	var under_22 := queries.filter_by_max_age(all, 21)

	# c1(21), c2(20), d2(21)
	assert_int(under_22.size()).is_equal(3)
	for player in under_22:
		assert_int(player["age"]).is_less_equal(21)


func test_filter_by_age_range() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var all := queries.all_players()
	var age_25_to_28 := queries.filter_by_age_range(all, 25, 28)

	# p1(25), p3(28), p6(26), p8(27)
	assert_int(age_25_to_28.size()).is_equal(4)
	for player in age_25_to_28:
		var age: int = player["age"]
		assert_bool(age >= 25 and age <= 28).is_true()


func test_filter_by_stage() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	var all := queries.all_players()
	var college := queries.filter_by_stage(all, Player.PlayerStage.COLLEGE)

	assert_int(college.size()).is_equal(2)


# =========================
# Determinism Tests
# =========================

func test_deterministic_results_same_input() -> void:
	var world := _create_world_state_with_players()

	# Run query multiple times with same input
	var queries1 := OptimizedPlayerQueries.new()
	queries1.rebuild_indexes(world)

	var queries2 := OptimizedPlayerQueries.new()
	queries2.rebuild_indexes(world)

	var queries3 := OptimizedPlayerQueries.new()
	queries3.rebuild_indexes(world)

	# All should have same count
	assert_int(queries1.count()).is_equal(queries2.count())
	assert_int(queries2.count()).is_equal(queries3.count())

	# Same players by ID
	assert_object(queries1.by_id("p1")).is_not_null()
	assert_object(queries2.by_id("p1")).is_not_null()
	assert_object(queries3.by_id("p1")).is_not_null()

	# Same position counts
	assert_int(queries1.count_by_position("QB")).is_equal(queries2.count_by_position("QB"))
	assert_int(queries2.count_by_position("QB")).is_equal(queries3.count_by_position("QB"))


func test_indexes_rebuilt_signal_emitted() -> void:
	var queries := OptimizedPlayerQueries.new()
	var signal_emitted := false

	queries.indexes_rebuilt.connect(func(): signal_emitted = true)

	var world := _create_world_state_with_players()
	queries.rebuild_indexes(world)

	assert_bool(signal_emitted).is_true()


# =========================
# Edge Case Tests
# =========================

func test_player_with_empty_id_ignored() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := {
		"nfl_rosters": {
			"team": {
				"players": [
					{"id": "", "position": "QB", "age": 25, "stage": 4},
					{"id": "valid", "position": "QB", "age": 26, "stage": 4}
				]
			}
		}
	}
	queries.rebuild_indexes(world)

	# Only valid player should be indexed
	assert_int(queries.count()).is_equal(1)
	assert_object(queries.by_id("valid")).is_not_null()


func test_player_with_empty_position_still_indexed() -> void:
	var queries := OptimizedPlayerQueries.new()
	var world := {
		"nfl_rosters": {
			"team": {
				"players": [
					{"id": "p1", "position": "", "age": 25, "stage": 4}
				]
			}
		}
	}
	queries.rebuild_indexes(world)

	# Player should still be indexed by ID
	assert_int(queries.count()).is_equal(1)
	assert_object(queries.by_id("p1")).is_not_null()

	# But not by position
	assert_array(queries.by_position("")).is_empty()
