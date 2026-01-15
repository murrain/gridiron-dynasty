## GdUnit4 test suite for Draft History Creation
##
## Tests that draft history is correctly created and populated during the draft process.
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")


func test_draft_creates_history() -> void:
	var config_service := ConfigService.new()
	var league_cfg: Dictionary = config_service.get_config("world/league")
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var main_cfg: Dictionary = config_service.get_config("main")

	var world_state := _make_world_state_with_draft_pool(300)

	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Verify draft ran
	assert_int(result.get("picks_count", 0)).is_greater(0)

	# Verify draft_history was created
	assert_bool(world_state.has("draft_history")).is_true()


func test_draft_history_structure() -> void:
	var config_service := ConfigService.new()
	var league_cfg: Dictionary = config_service.get_config("world/league")
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var main_cfg: Dictionary = config_service.get_config("main")

	var world_state := _make_world_state_with_draft_pool(300)

	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {})
	assert_bool(draft_history.has(2025)).is_true()

	var picks_2025: Array = draft_history.get(2025, [])
	assert_int(picks_2025.size()).is_greater(0)


func test_draft_pick_contains_player_info() -> void:
	var config_service := ConfigService.new()
	var league_cfg: Dictionary = config_service.get_config("world/league")
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var main_cfg: Dictionary = config_service.get_config("main")

	var world_state := _make_world_state_with_draft_pool(300)

	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {})
	var picks_2025: Array = draft_history.get(2025, [])

	if picks_2025.size() > 0:
		var first_pick: Dictionary = picks_2025[0]
		assert_bool(first_pick.has("player") or first_pick.has("player_id")).is_true()
		assert_bool(first_pick.has("team_id")).is_true()
		assert_bool(first_pick.has("overall_pick")).is_true()


func test_draft_determinism() -> void:
	var config_service := ConfigService.new()
	var league_cfg: Dictionary = config_service.get_config("world/league")
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var main_cfg: Dictionary = config_service.get_config("main")

	# Run 1
	var world_state_1 := _make_world_state_with_draft_pool(300)
	var draft_1 := NflDraft.new()
	var result_1 := draft_1.run(world_state_1, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Run 2 with same seed
	var world_state_2 := _make_world_state_with_draft_pool(300)
	var draft_2 := NflDraft.new()
	var result_2 := draft_2.run(world_state_2, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Results should be identical
	assert_int(result_1.get("picks_count", 0)).is_equal(result_2.get("picks_count", 0))
	assert_int(result_1.get("undrafted_count", 0)).is_equal(result_2.get("undrafted_count", 0))


## Helper: Create world state with draft pool
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

	# Create draft pool with deterministic ratings
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


## Helper: Create a draft-eligible player
func _make_draft_player(player_id: String, pos: String, rating: float) -> Dictionary:
	var college_num: int = (hash(player_id) % 130) + 1
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"age": 22,
		"draft_eligible": true,
		"draft_year": 2025,
		"college_team_id": "college_%03d" % college_num,
		"stats": {"speed": rating, "acceleration": rating - 5.0, "agility": rating - 3.0},
		"potential": {"speed": rating + 5.0, "acceleration": rating, "agility": rating + 2.0},
		"composite_score": rating
	}
