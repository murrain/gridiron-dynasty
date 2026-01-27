class_name WorldStateAccessorTest
extends GdUnitTestSuite

## GdUnit4 test suite for WorldStateAccessor.gd
## Tests read-only query layer for world_state.
##
## CRITICAL: All methods must return COPIES, never references.
## Tests verify immutability guarantees.

const WorldStateAccessor = preload("res://scripts/core/state/WorldStateAccessor.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_test_world_state() -> Dictionary:
	"""Create a test world_state with diverse player data."""
	return {
		"hs_players": [
			{"id": "hs_1", "age": 18, "stage": Player.PlayerStage.HIGH_SCHOOL},
			{"id": "hs_2", "age": 17, "stage": Player.PlayerStage.HIGH_SCHOOL}
		],
		"college_rosters": {
			"STANFORD": {
				"name": "Stanford",
				"players": [
					{"id": "col_1", "age": 20, "stage": Player.PlayerStage.COLLEGE},
					{"id": "col_2", "age": 21, "stage": Player.PlayerStage.COLLEGE}
				]
			},
			"USC": {
				"name": "USC",
				"players": [
					{"id": "col_3", "age": 19, "stage": Player.PlayerStage.COLLEGE}
				]
			}
		},
		"draft_pool": [
			{"id": "draft_1", "age": 22, "stage": Player.PlayerStage.DRAFT_ELIGIBLE, "composite_score": 85.5},
			{"id": "draft_2", "age": 22, "stage": Player.PlayerStage.DRAFT_ELIGIBLE, "composite_score": 92.3},
			{"id": "draft_3", "age": 23, "stage": Player.PlayerStage.DRAFT_ELIGIBLE, "composite_score": 78.9}
		],
		"nfl_rosters": {
			"SF": {
				"name": "San Francisco 49ers",
				"roster_limit": 53,
				"players": [
					{"id": "nfl_1", "age": 25, "stage": Player.PlayerStage.NFL_VETERAN},
					{"id": "nfl_2", "age": 24, "stage": Player.PlayerStage.NFL_ROOKIE}
				]
			},
			"KC": {
				"name": "Kansas City Chiefs",
				"roster_limit": 53,
				"players": [
					{"id": "nfl_3", "age": 26, "stage": Player.PlayerStage.NFL_VETERAN}
				]
			}
		},
		"free_agents": [
			{"id": "fa_1", "age": 28, "stage": Player.PlayerStage.NFL_FREE_AGENT}
		]
	}

# ============================================================================
# TESTS - get_players_by_stage
# ============================================================================

func test_get_players_by_stage_high_school() -> void:
	var world_state := _create_test_world_state()

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.HIGH_SCHOOL
	)

	assert_array(players).has_size(2)
	for player in players:
		assert_int(player["stage"]).is_equal(Player.PlayerStage.HIGH_SCHOOL)

func test_get_players_by_stage_college() -> void:
	var world_state := _create_test_world_state()

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.COLLEGE
	)

	# 2 from STANFORD + 1 from USC = 3
	assert_array(players).has_size(3)
	for player in players:
		assert_int(player["stage"]).is_equal(Player.PlayerStage.COLLEGE)

func test_get_players_by_stage_draft_eligible() -> void:
	var world_state := _create_test_world_state()

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.DRAFT_ELIGIBLE
	)

	assert_array(players).has_size(3)

func test_get_players_by_stage_nfl_veteran() -> void:
	var world_state := _create_test_world_state()

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.NFL_VETERAN
	)

	# 1 from SF + 1 from KC = 2
	assert_array(players).has_size(2)

func test_get_players_by_stage_returns_copies() -> void:
	var world_state := _create_test_world_state()

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.HIGH_SCHOOL
	)

	# Mutate the returned player
	players[0]["age"] = 999

	# Verify original is unchanged
	assert_int(world_state["hs_players"][0]["age"]).is_equal(18)

func test_get_players_by_stage_no_matches() -> void:
	var world_state := _create_test_world_state()

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.RETIRED
	)

	assert_array(players).is_empty()

# ============================================================================
# TESTS - get_player_by_id
# ============================================================================

func test_get_player_by_id_found() -> void:
	var world_state := _create_test_world_state()

	var player := WorldStateAccessor.get_player_by_id(world_state, "nfl_2")

	assert_dict(player).is_not_empty()
	assert_str(player["id"]).is_equal("nfl_2")
	assert_int(player["age"]).is_equal(24)

func test_get_player_by_id_not_found() -> void:
	var world_state := _create_test_world_state()

	var player := WorldStateAccessor.get_player_by_id(world_state, "nonexistent")

	assert_dict(player).is_empty()

func test_get_player_by_id_returns_copy() -> void:
	var world_state := _create_test_world_state()

	var player := WorldStateAccessor.get_player_by_id(world_state, "hs_1")

	# Mutate returned player
	player["age"] = 999

	# Verify original unchanged
	assert_int(world_state["hs_players"][0]["age"]).is_equal(18)

func test_get_player_by_id_in_different_collections() -> void:
	var world_state := _create_test_world_state()

	# Test finding players in each collection type
	var hs_player := WorldStateAccessor.get_player_by_id(world_state, "hs_1")
	assert_str(hs_player["id"]).is_equal("hs_1")

	var col_player := WorldStateAccessor.get_player_by_id(world_state, "col_2")
	assert_str(col_player["id"]).is_equal("col_2")

	var draft_player := WorldStateAccessor.get_player_by_id(world_state, "draft_1")
	assert_str(draft_player["id"]).is_equal("draft_1")

	var nfl_player := WorldStateAccessor.get_player_by_id(world_state, "nfl_3")
	assert_str(nfl_player["id"]).is_equal("nfl_3")

	var fa_player := WorldStateAccessor.get_player_by_id(world_state, "fa_1")
	assert_str(fa_player["id"]).is_equal("fa_1")

# ============================================================================
# TESTS - get_team_roster_counts
# ============================================================================

func test_get_team_roster_counts() -> void:
	var world_state := _create_test_world_state()

	var roster_counts := WorldStateAccessor.get_team_roster_counts(world_state)

	assert_dict(roster_counts).has_size(2)
	assert_bool(roster_counts.has("SF")).is_true()
	assert_bool(roster_counts.has("KC")).is_true()

	var sf_info: Dictionary = roster_counts["SF"]
	assert_str(sf_info["name"]).is_equal("San Francisco 49ers")
	assert_int(sf_info["roster_count"]).is_equal(2)
	assert_int(sf_info["roster_limit"]).is_equal(53)

	var kc_info: Dictionary = roster_counts["KC"]
	assert_int(kc_info["roster_count"]).is_equal(1)

func test_get_team_roster_counts_empty() -> void:
	var world_state := {"nfl_rosters": {}}

	var roster_counts := WorldStateAccessor.get_team_roster_counts(world_state)

	assert_dict(roster_counts).is_empty()

func test_get_team_roster_counts_missing_field() -> void:
	var world_state := {}

	var roster_counts := WorldStateAccessor.get_team_roster_counts(world_state)

	assert_dict(roster_counts).is_empty()

# ============================================================================
# TESTS - get_draft_eligible_players_sorted
# ============================================================================

func test_get_draft_eligible_players_sorted() -> void:
	var world_state := _create_test_world_state()

	var sorted_players := WorldStateAccessor.get_draft_eligible_players_sorted(world_state)

	assert_array(sorted_players).has_size(3)

	# Verify sorted in descending order by composite_score
	assert_str(sorted_players[0]["id"]).is_equal("draft_2")  # 92.3
	assert_str(sorted_players[1]["id"]).is_equal("draft_1")  # 85.5
	assert_str(sorted_players[2]["id"]).is_equal("draft_3")  # 78.9

func test_get_draft_eligible_players_sorted_empty() -> void:
	var world_state := {"draft_pool": []}

	var sorted_players := WorldStateAccessor.get_draft_eligible_players_sorted(world_state)

	assert_array(sorted_players).is_empty()

func test_get_draft_eligible_players_sorted_returns_copy() -> void:
	var world_state := _create_test_world_state()

	var sorted_players := WorldStateAccessor.get_draft_eligible_players_sorted(world_state)

	# Mutate returned array
	sorted_players[0]["composite_score"] = 0.0

	# Verify original unchanged
	assert_float(world_state["draft_pool"][1]["composite_score"]).is_equal(92.3)

# ============================================================================
# TESTS - get_collection
# ============================================================================

func test_get_collection_flat_array() -> void:
	var world_state := _create_test_world_state()

	var collection := WorldStateAccessor.get_collection(world_state, "hs_players")

	assert_array(collection).has_size(2)
	assert_str(collection[0]["id"]).is_equal("hs_1")

func test_get_collection_nested_rosters() -> void:
	var world_state := _create_test_world_state()

	var collection := WorldStateAccessor.get_collection(world_state, "nfl_rosters")

	# Should get all NFL players across all teams (2 from SF + 1 from KC = 3)
	assert_array(collection).has_size(3)

func test_get_collection_nonexistent() -> void:
	var world_state := _create_test_world_state()

	var collection := WorldStateAccessor.get_collection(world_state, "nonexistent")

	assert_array(collection).is_empty()

func test_get_collection_returns_copy() -> void:
	var world_state := _create_test_world_state()

	var collection := WorldStateAccessor.get_collection(world_state, "hs_players")

	# Mutate returned collection
	collection[0]["age"] = 999

	# Verify original unchanged
	assert_int(world_state["hs_players"][0]["age"]).is_equal(18)

# ============================================================================
# TESTS - get_team_roster
# ============================================================================

func test_get_team_roster() -> void:
	var world_state := _create_test_world_state()

	var roster := WorldStateAccessor.get_team_roster(world_state, "nfl_rosters", "SF")

	assert_array(roster).has_size(2)
	assert_str(roster[0]["id"]).is_equal("nfl_1")

func test_get_team_roster_nonexistent_team() -> void:
	var world_state := _create_test_world_state()

	var roster := WorldStateAccessor.get_team_roster(world_state, "nfl_rosters", "NONEXISTENT")

	assert_array(roster).is_empty()

func test_get_team_roster_returns_copy() -> void:
	var world_state := _create_test_world_state()

	var roster := WorldStateAccessor.get_team_roster(world_state, "nfl_rosters", "SF")

	# Mutate returned roster
	roster[0]["age"] = 999

	# Verify original unchanged
	assert_int(world_state["nfl_rosters"]["SF"]["players"][0]["age"]).is_equal(25)

func test_get_team_roster_college() -> void:
	var world_state := _create_test_world_state()

	var roster := WorldStateAccessor.get_team_roster(world_state, "college_rosters", "STANFORD")

	assert_array(roster).has_size(2)
	assert_str(roster[0]["id"]).is_equal("col_1")

# ============================================================================
# TESTS - get_player_counts
# ============================================================================

func test_get_player_counts() -> void:
	var world_state := _create_test_world_state()

	var counts := WorldStateAccessor.get_player_counts(world_state)

	assert_dict(counts).contains_keys(["total", "by_stage"])

	# Total: 2 HS + 3 college + 3 draft + 3 NFL + 1 FA = 12
	assert_int(counts["total"]).is_equal(12)

	var by_stage: Dictionary = counts["by_stage"]
	assert_int(by_stage[Player.PlayerStage.HIGH_SCHOOL]).is_equal(2)
	assert_int(by_stage[Player.PlayerStage.COLLEGE]).is_equal(3)
	assert_int(by_stage[Player.PlayerStage.DRAFT_ELIGIBLE]).is_equal(3)
	assert_int(by_stage[Player.PlayerStage.NFL_VETERAN]).is_equal(2)
	assert_int(by_stage[Player.PlayerStage.NFL_ROOKIE]).is_equal(1)
	assert_int(by_stage[Player.PlayerStage.NFL_FREE_AGENT]).is_equal(1)

func test_get_player_counts_empty() -> void:
	var world_state := {
		"hs_players": [],
		"college_rosters": {},
		"draft_pool": [],
		"nfl_rosters": {},
		"free_agents": []
	}

	var counts := WorldStateAccessor.get_player_counts(world_state)

	assert_int(counts["total"]).is_equal(0)

func test_get_player_counts_partial_data() -> void:
	var world_state := {
		"hs_players": [{"id": "hs_1", "stage": Player.PlayerStage.HIGH_SCHOOL}]
	}

	var counts := WorldStateAccessor.get_player_counts(world_state)

	assert_int(counts["total"]).is_equal(1)

# ============================================================================
# TESTS - has_player
# ============================================================================

func test_has_player_exists() -> void:
	var world_state := _create_test_world_state()

	assert_bool(WorldStateAccessor.has_player(world_state, "nfl_1")).is_true()

func test_has_player_does_not_exist() -> void:
	var world_state := _create_test_world_state()

	assert_bool(WorldStateAccessor.has_player(world_state, "nonexistent")).is_false()

func test_has_player_in_different_collections() -> void:
	var world_state := _create_test_world_state()

	# Test presence in each collection type
	assert_bool(WorldStateAccessor.has_player(world_state, "hs_1")).is_true()
	assert_bool(WorldStateAccessor.has_player(world_state, "col_2")).is_true()
	assert_bool(WorldStateAccessor.has_player(world_state, "draft_1")).is_true()
	assert_bool(WorldStateAccessor.has_player(world_state, "nfl_3")).is_true()
	assert_bool(WorldStateAccessor.has_player(world_state, "fa_1")).is_true()

# ============================================================================
# TESTS - get_player_location
# ============================================================================

func test_get_player_location_flat_collection() -> void:
	var world_state := _create_test_world_state()

	var location := WorldStateAccessor.get_player_location(world_state, "hs_1")

	assert_dict(location).is_not_empty()
	assert_str(location["collection_type"]).is_equal("hs_players")
	assert_str(location["team_id"]).is_equal("")
	assert_int(location["index"]).is_equal(0)

func test_get_player_location_nested_collection() -> void:
	var world_state := _create_test_world_state()

	var location := WorldStateAccessor.get_player_location(world_state, "nfl_2")

	assert_dict(location).is_not_empty()
	assert_str(location["collection_type"]).is_equal("nfl_rosters")
	assert_str(location["team_id"]).is_equal("SF")
	assert_int(location["index"]).is_equal(1)

func test_get_player_location_not_found() -> void:
	var world_state := _create_test_world_state()

	var location := WorldStateAccessor.get_player_location(world_state, "nonexistent")

	assert_dict(location).is_empty()

func test_get_player_location_college_roster() -> void:
	var world_state := _create_test_world_state()

	var location := WorldStateAccessor.get_player_location(world_state, "col_3")

	assert_str(location["collection_type"]).is_equal("college_rosters")
	assert_str(location["team_id"]).is_equal("USC")
	assert_int(location["index"]).is_equal(0)

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

func test_get_players_by_stage_with_missing_collections() -> void:
	var world_state := {}

	var players := WorldStateAccessor.get_players_by_stage(
		world_state,
		Player.PlayerStage.HIGH_SCHOOL
	)

	assert_array(players).is_empty()

func test_get_player_by_id_with_empty_world_state() -> void:
	var world_state := {}

	var player := WorldStateAccessor.get_player_by_id(world_state, "any_id")

	assert_dict(player).is_empty()

func test_get_collection_with_null_value() -> void:
	var world_state := {"test_collection": null}

	var collection := WorldStateAccessor.get_collection(world_state, "test_collection")

	assert_array(collection).is_empty()

func test_get_team_roster_with_empty_roster() -> void:
	var world_state := {
		"nfl_rosters": {
			"EMPTY": {
				"name": "Empty Team",
				"players": []
			}
		}
	}

	var roster := WorldStateAccessor.get_team_roster(world_state, "nfl_rosters", "EMPTY")

	assert_array(roster).is_empty()

func test_get_player_counts_handles_missing_stage_field() -> void:
	var world_state := {
		"hs_players": [
			{"id": "hs_1"},  # Missing stage field
			{"id": "hs_2", "stage": Player.PlayerStage.HIGH_SCHOOL}
		]
	}

	var counts := WorldStateAccessor.get_player_counts(world_state)

	# Should still count all players
	assert_int(counts["total"]).is_greater_equal(1)
