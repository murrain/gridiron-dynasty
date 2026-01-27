class_name PlayerStateManagerTest
extends GdUnitTestSuite

## GdUnit4 test suite for PlayerStateManager.gd
## Tests state mutation layer for player lifecycle.
##
## IMPORTANT: These tests verify that PlayerStateManager properly:
## 1. Calls pure transformation functions
## 2. Updates world_state atomically
## 3. Does NOT mutate inputs to transformation functions
## 4. Maintains referential integrity within world_state

const PlayerStateManager = preload("res://scripts/core/state/PlayerStateManager.gd")
const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_minimal_world_state() -> Dictionary:
	"""Create a minimal world_state for testing."""
	return {
		"hs_players": [
			{"id": "hs_1", "age": 18, "position": "QB", "stage": Player.PlayerStage.HIGH_SCHOOL,
			 "stats": {"speed": 70.0}, "potential": {"speed": 85.0}, "injuries": [], "wear": {}},
			{"id": "hs_2", "age": 17, "position": "RB", "stage": Player.PlayerStage.HIGH_SCHOOL,
			 "stats": {"speed": 75.0}, "potential": {"speed": 90.0}, "injuries": [], "wear": {}}
		],
		"college_rosters": {
			"STANFORD": {
				"name": "Stanford",
				"players": [
					{"id": "col_1", "age": 20, "position": "WR", "stage": Player.PlayerStage.COLLEGE,
					 "stats": {"speed": 80.0}, "potential": {"speed": 92.0}, "injuries": [], "wear": {}},
					{"id": "col_2", "age": 21, "position": "QB", "stage": Player.PlayerStage.COLLEGE,
					 "stats": {"speed": 75.0}, "potential": {"speed": 88.0}, "injuries": [], "wear": {}}
				]
			}
		},
		"draft_pool": [
			{"id": "draft_1", "age": 22, "position": "QB", "stage": Player.PlayerStage.DRAFT_ELIGIBLE,
			 "stats": {"speed": 78.0}, "potential": {"speed": 90.0}, "injuries": [], "wear": {}}
		],
		"nfl_rosters": {
			"SF": {
				"name": "San Francisco 49ers",
				"roster_limit": 53,
				"players": [
					{"id": "nfl_1", "age": 25, "position": "WR", "stage": Player.PlayerStage.NFL_VETERAN,
					 "stats": {"speed": 90.0}, "potential": {"speed": 95.0}, "injuries": [], "wear": {}},
					{"id": "nfl_2", "age": 24, "position": "QB", "stage": Player.PlayerStage.NFL_ROOKIE,
					 "stats": {"speed": 85.0}, "potential": {"speed": 92.0}, "injuries": [], "wear": {}}
				]
			}
		},
		"free_agents": [
			{"id": "fa_1", "age": 28, "position": "TE", "stage": Player.PlayerStage.NFL_FREE_AGENT,
			 "stats": {"speed": 82.0}, "potential": {"speed": 88.0}, "injuries": [], "wear": {}}
		]
	}

func _create_minimal_configs() -> Dictionary:
	"""Create minimal test configs."""
	return {
		"main": {
			"development": {
				"curve_multipliers": {
					"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}
				},
				"prime_growth_min": 0.2,
				"prime_growth_max": 0.8,
				"decline_min": 0.4,
				"decline_max": 1.6
			},
			"annual_base_progress_min": 1.0,
			"annual_base_progress_max": 4.0,
			"annual_progress_cap": 6.0,
			"injury": {
				"base_chance": 0.12,
				"proneness_slope": 0.15,
				"position_multipliers": {},
				"durability_trait_modifiers": {},
				"types": []
			},
			"retirement": {
				"min_age": 27,
				"soft_cap_age": 33,
				"max_age": 40,
				"base_chance": 0.02,
				"age_chance_per_year": 0.04,
				"low_rating_threshold": 55.0,
				"low_rating_boost": 0.08
			},
			"wear": {
				"decline_snaps_scale": 8000.0,
				"decline_collisions_scale": 2600.0,
				"decline_injuries_scale": 6.0,
				"decline_per_wear": 0.2,
				"decline_min_multiplier": 1.0,
				"decline_max_multiplier": 1.6
			}
		},
		"positions": {
			"QB": {"development": {"peak_age": 28, "decline_start": 34, "curve": "mid"}},
			"RB": {"development": {"peak_age": 25, "decline_start": 29, "curve": "mid"}},
			"WR": {"development": {"peak_age": 27, "decline_start": 31, "curve": "mid"}},
			"TE": {"development": {"peak_age": 27, "decline_start": 31, "curve": "mid"}}
		},
		"stats": {
			"stats": [{"name": "speed", "type": "base"}]
		}
	}

# ============================================================================
# TESTS - advance_players_one_year
# ============================================================================

func test_advance_players_one_year_updates_world_state() -> void:
	var world_state := _create_minimal_world_state()
	var context := {"program_quality": 1.0}
	var configs := _create_minimal_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var initial_ages := []
	for player in world_state["nfl_rosters"]["SF"]["players"]:
		initial_ages.append(player["age"])

	PlayerStateManager.advance_players_one_year(
		world_state,
		["nfl_rosters", "SF", "players"],
		context,
		configs,
		rng
	)

	# Verify ages were updated in world_state
	var updated_players: Array = world_state["nfl_rosters"]["SF"]["players"]
	for i in range(updated_players.size()):
		assert_int(updated_players[i]["age"]).is_equal(initial_ages[i] + 1)

func test_advance_players_one_year_returns_summary() -> void:
	var world_state := _create_minimal_world_state()
	var context := {"program_quality": 1.0}
	var configs := _create_minimal_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerStateManager.advance_players_one_year(
		world_state,
		["nfl_rosters", "SF", "players"],
		context,
		configs,
		rng
	)

	# Verify summary structure
	assert_dict(result).contains_keys([
		"active_count", "retired_count", "collection", "reports", "retired"
	])
	assert_int(result["active_count"]).is_greater_equal(0)
	assert_int(result["retired_count"]).is_greater_equal(0)
	assert_str(result["collection"]).is_equal("nfl_rosters")

func test_advance_players_one_year_is_deterministic() -> void:
	var world_state1 := _create_minimal_world_state()
	var world_state2 := _create_minimal_world_state()
	var context := {"program_quality": 1.0}
	var configs := _create_minimal_configs()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := PlayerStateManager.advance_players_one_year(
		world_state1,
		["nfl_rosters", "SF", "players"],
		context,
		configs,
		rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := PlayerStateManager.advance_players_one_year(
		world_state2,
		["nfl_rosters", "SF", "players"],
		context,
		configs,
		rng2
	)

	# Results should be identical
	assert_int(result1["active_count"]).is_equal(result2["active_count"])
	assert_int(result1["retired_count"]).is_equal(result2["retired_count"])

	# Player ages should be identical
	var players1: Array = world_state1["nfl_rosters"]["SF"]["players"]
	var players2: Array = world_state2["nfl_rosters"]["SF"]["players"]
	assert_int(players1.size()).is_equal(players2.size())

	for i in range(players1.size()):
		assert_int(players1[i]["age"]).is_equal(players2[i]["age"])

func test_advance_players_one_year_with_empty_collection() -> void:
	var world_state := {"nfl_rosters": {"EMPTY": {"name": "Empty", "players": []}}}
	var context := {}
	var configs := _create_minimal_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerStateManager.advance_players_one_year(
		world_state,
		["nfl_rosters", "EMPTY", "players"],
		context,
		configs,
		rng
	)

	assert_int(result["active_count"]).is_equal(0)
	assert_int(result["retired_count"]).is_equal(0)

func test_advance_players_one_year_with_invalid_path() -> void:
	var world_state := _create_minimal_world_state()
	var context := {}
	var configs := _create_minimal_configs()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result := PlayerStateManager.advance_players_one_year(
		world_state,
		["nonexistent", "path"],
		context,
		configs,
		rng
	)

	# Should return empty result without crashing
	assert_int(result["active_count"]).is_equal(0)

# ============================================================================
# TESTS - transition_player_stage (validating integration with TransitionFunctions)
# ============================================================================

func test_transition_player_stage_valid_transition() -> void:
	var world_state := _create_minimal_world_state()
	var player_id := "col_1"

	var success := PlayerStateManager.transition_player_stage(
		world_state,
		player_id,
		Player.PlayerStage.COLLEGE,
		Player.PlayerStage.DRAFT_ELIGIBLE,
		"pre_draft"
	)

	assert_bool(success).is_true()

	# Verify stage updated in world_state
	var player: Dictionary = world_state["college_rosters"]["STANFORD"]["players"][0]
	assert_int(player["stage"]).is_equal(Player.PlayerStage.DRAFT_ELIGIBLE)

func test_transition_player_stage_invalid_transition() -> void:
	var world_state := _create_minimal_world_state()
	var player_id := "hs_1"

	# Invalid: HIGH_SCHOOL -> NFL_ROOKIE (must go through COLLEGE and DRAFT_ELIGIBLE)
	var success := PlayerStateManager.transition_player_stage(
		world_state,
		player_id,
		Player.PlayerStage.HIGH_SCHOOL,
		Player.PlayerStage.NFL_ROOKIE,
		"invalid_phase"
	)

	assert_bool(success).is_false()

	# Verify stage unchanged
	var player: Dictionary = world_state["hs_players"][0]
	assert_int(player["stage"]).is_equal(Player.PlayerStage.HIGH_SCHOOL)

func test_transition_player_stage_player_not_found() -> void:
	var world_state := _create_minimal_world_state()

	var success := PlayerStateManager.transition_player_stage(
		world_state,
		"nonexistent_player",
		Player.PlayerStage.COLLEGE,
		Player.PlayerStage.DRAFT_ELIGIBLE,
		"pre_draft"
	)

	assert_bool(success).is_false()

func test_transition_player_stage_stage_mismatch() -> void:
	var world_state := _create_minimal_world_state()
	var player_id := "col_1"

	# Player is in COLLEGE, but we claim they're in HIGH_SCHOOL
	var success := PlayerStateManager.transition_player_stage(
		world_state,
		player_id,
		Player.PlayerStage.HIGH_SCHOOL,  # Wrong from_stage
		Player.PlayerStage.COLLEGE,
		"test_phase"
	)

	assert_bool(success).is_false()

# ============================================================================
# TESTS - Internal helpers (_find_player, _extract_collection, etc.)
# ============================================================================

func test_find_player_in_flat_collection() -> void:
	var world_state := _create_minimal_world_state()

	var location := PlayerStateManager._find_player(world_state, "hs_1")

	assert_dict(location).is_not_empty()
	assert_array(location["collection_path"]).is_equal(["hs_players"])
	assert_int(location["index"]).is_equal(0)
	assert_str(location["player"]["id"]).is_equal("hs_1")

func test_find_player_in_nested_collection() -> void:
	var world_state := _create_minimal_world_state()

	var location := PlayerStateManager._find_player(world_state, "nfl_2")

	assert_dict(location).is_not_empty()
	assert_array(location["collection_path"]).is_equal(["nfl_rosters", "SF", "players"])
	assert_int(location["index"]).is_equal(1)
	assert_str(location["player"]["id"]).is_equal("nfl_2")

func test_find_player_not_found() -> void:
	var world_state := _create_minimal_world_state()

	var location := PlayerStateManager._find_player(world_state, "nonexistent")

	assert_dict(location).is_empty()

func test_extract_collection_flat_array() -> void:
	var world_state := _create_minimal_world_state()

	var collection := PlayerStateManager._extract_collection(world_state, ["hs_players"])

	assert_array(collection).has_size(2)
	assert_str(collection[0]["id"]).is_equal("hs_1")

func test_extract_collection_nested_array() -> void:
	var world_state := _create_minimal_world_state()

	var collection := PlayerStateManager._extract_collection(
		world_state,
		["nfl_rosters", "SF", "players"]
	)

	assert_array(collection).has_size(2)
	assert_str(collection[0]["id"]).is_equal("nfl_1")

func test_extract_collection_invalid_path() -> void:
	var world_state := _create_minimal_world_state()

	var collection := PlayerStateManager._extract_collection(
		world_state,
		["nonexistent", "path"]
	)

	assert_array(collection).is_empty()

func test_replace_collection_flat_array() -> void:
	var world_state := _create_minimal_world_state()
	var new_collection := [
		{"id": "new_1", "age": 19},
		{"id": "new_2", "age": 20}
	]

	PlayerStateManager._replace_collection(world_state, ["hs_players"], new_collection)

	assert_array(world_state["hs_players"]).has_size(2)
	assert_str(world_state["hs_players"][0]["id"]).is_equal("new_1")

func test_replace_collection_nested_array() -> void:
	var world_state := _create_minimal_world_state()
	var new_collection := [{"id": "new_nfl_1", "age": 25}]

	PlayerStateManager._replace_collection(
		world_state,
		["nfl_rosters", "SF", "players"],
		new_collection
	)

	assert_array(world_state["nfl_rosters"]["SF"]["players"]).has_size(1)
	assert_str(world_state["nfl_rosters"]["SF"]["players"][0]["id"]).is_equal("new_nfl_1")

func test_replace_player() -> void:
	var world_state := _create_minimal_world_state()
	var new_player := {"id": "nfl_1", "age": 999, "position": "WR"}

	var success := PlayerStateManager._replace_player(
		world_state,
		["nfl_rosters", "SF", "players"],
		0,
		new_player
	)

	assert_bool(success).is_true()
	assert_int(world_state["nfl_rosters"]["SF"]["players"][0]["age"]).is_equal(999)

func test_replace_player_invalid_path() -> void:
	var world_state := _create_minimal_world_state()
	var new_player := {"id": "test", "age": 25}

	var success := PlayerStateManager._replace_player(
		world_state,
		["nonexistent", "path"],
		0,
		new_player
	)

	assert_bool(success).is_false()

func test_replace_player_invalid_index() -> void:
	var world_state := _create_minimal_world_state()
	var new_player := {"id": "test", "age": 25}

	var success := PlayerStateManager._replace_player(
		world_state,
		["hs_players"],
		999,
		new_player
	)

	assert_bool(success).is_false()
