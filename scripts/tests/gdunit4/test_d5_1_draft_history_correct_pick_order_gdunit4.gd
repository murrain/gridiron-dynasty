## GdUnit4 test suite for D5.1: Draft History - Correct Pick Order
##
## Verifies that draft history picks are stored in correct order and match draft execution.
## Tests:
##   1. Pick numbers are sequential (1, 2, 3, ...)
##   2. Rounds progress correctly (all round 1, then all round 2, etc.)
##   3. Draft history order matches actual draft pick order
##   4. Pick number, round, and team_id relationships are correct
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _league_cfg: Dictionary
var _positions_cfg: Dictionary
var _stats_cfg: Dictionary
var _scouts_cfg: Dictionary
var _main_cfg: Dictionary


func before() -> void:
	var config_service := ConfigService.new()
	_league_cfg = config_service.get_config("world/league")
	_positions_cfg = config_service.get_config("positions")
	_stats_cfg = config_service.get_config("stats")
	_scouts_cfg = config_service.get_config("scouts")
	_main_cfg = config_service.get_config("main")


func test_pick_numbers_sequential() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	assert_int(picks.size()).is_greater(0)

	# Verify pick numbers are 1, 2, 3, ..., N
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var expected_pick_number := i + 1
		var actual_pick_number := int(pick.get("pick_number", 0))

		assert_int(actual_pick_number).is_equal(expected_pick_number)


func test_rounds_progress_correctly() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	var teams_count := int(_league_cfg.get("team_count", 32))

	assert_int(picks.size()).is_greater(0)

	# Track rounds and verify structure
	var current_round := 0
	var picks_in_current_round := 0

	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var round := int(pick.get("round", 0))

		# Check if we've moved to a new round
		if round != current_round:
			# If not the first round, verify previous round had correct number of picks
			if current_round > 0:
				assert_int(picks_in_current_round).is_equal(teams_count)

			# Update to new round
			assert_int(round).is_equal(current_round + 1)
			current_round = round
			picks_in_current_round = 0

		picks_in_current_round += 1

	# Verify last round had correct number of picks
	if current_round > 0:
		assert_int(picks_in_current_round).is_equal(teams_count)


func test_draft_history_matches_execution() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 77777, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	# Get draft picks from result (execution order)
	var execution_picks: Array = result.get("picks", []) as Array

	# Get draft history from world_state
	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var history_picks: Array = draft_history.get(2025, []) as Array

	assert_int(history_picks.size()).is_equal(execution_picks.size())

	# Verify each pick matches between execution and history
	for i in range(min(execution_picks.size(), history_picks.size())):
		var exec_pick: Dictionary = execution_picks[i] as Dictionary
		var hist_pick: Dictionary = history_picks[i] as Dictionary

		assert_int(int(hist_pick.get("pick_number", 0))).is_equal(int(exec_pick.get("pick", 0)))
		assert_int(int(hist_pick.get("round", 0))).is_equal(int(exec_pick.get("round", 0)))
		assert_str(String(hist_pick.get("team_id", ""))).is_equal(String(exec_pick.get("team_id", "")))
		assert_str(String(hist_pick.get("player_id", ""))).is_equal(String(exec_pick.get("player_id", "")))
		assert_str(String(hist_pick.get("position", ""))).is_equal(String(exec_pick.get("position", "")))


func test_pick_number_round_alignment() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	var teams_count := int(_league_cfg.get("team_count", 32))

	assert_int(picks.size()).is_greater(0)

	# Verify pick_number corresponds correctly to round
	# Formula: pick_number = (round - 1) * teams_count + pick_in_round
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var pick_number := int(pick.get("pick_number", 0))
		var round := int(pick.get("round", 0))

		# Calculate expected round from pick_number
		var expected_round := ((pick_number - 1) / teams_count) + 1

		assert_int(round).is_equal(expected_round)

		# Calculate position within round (1-indexed)
		var pick_in_round := ((pick_number - 1) % teams_count) + 1
		assert_bool(pick_in_round >= 1 and pick_in_round <= teams_count).is_true()


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
