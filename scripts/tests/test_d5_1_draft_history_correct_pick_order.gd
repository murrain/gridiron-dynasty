extends RefCounted

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

## Test D5.1: Draft History - Correct Pick Order
##
## Verifies that draft history picks are stored in correct order and match draft execution.
## Tests:
##   1. Pick numbers are sequential (1, 2, 3, ...)
##   2. Rounds progress correctly (all round 1, then all round 2, etc.)
##   3. Draft history order matches actual draft pick order
##   4. Pick number, round, and team_id relationships are correct

func run(t) -> void:
	var config := ConfigService.new()
	var league_cfg := config.get_config("world/league")
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var main_cfg := config.get_config("main")

	# Test 1: Pick numbers are sequential
	_test_pick_numbers_sequential(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 2: Rounds progress correctly
	_test_rounds_progress_correctly(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 3: Draft history matches draft execution order
	_test_draft_history_matches_execution(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 4: Pick number aligns with round structure
	_test_pick_number_round_alignment(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

func _test_pick_numbers_sequential(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	t.assert_true(picks.size() > 0, "should have picks to test")

	# Verify pick numbers are 1, 2, 3, ..., N
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var expected_pick_number := i + 1
		var actual_pick_number := int(pick.get("pick_number", 0))

		t.assert_eq(actual_pick_number, expected_pick_number,
			"pick at index %d should have pick_number %d" % [i, expected_pick_number])

func _test_rounds_progress_correctly(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var teams_count := int(league_cfg.get("team_count", 32))

	t.assert_true(picks.size() > 0, "should have picks to test")

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
				t.assert_eq(picks_in_current_round, teams_count,
					"round %d should have exactly %d picks" % [current_round, teams_count])

			# Update to new round
			t.assert_eq(round, current_round + 1,
				"rounds should increment by 1 (expected %d, got %d)" % [current_round + 1, round])
			current_round = round
			picks_in_current_round = 0

		picks_in_current_round += 1

	# Verify last round had correct number of picks
	if current_round > 0:
		t.assert_eq(picks_in_current_round, teams_count,
			"final round %d should have exactly %d picks" % [current_round, teams_count])

func _test_draft_history_matches_execution(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 77777, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Get draft picks from result (execution order)
	var execution_picks: Array = result.get("picks", []) as Array

	# Get draft history from world_state
	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var history_picks: Array = draft_history.get(2025, []) as Array

	t.assert_eq(history_picks.size(), execution_picks.size(),
		"draft history should have same number of picks as execution")

	# Verify each pick matches between execution and history
	for i in range(min(execution_picks.size(), history_picks.size())):
		var exec_pick: Dictionary = execution_picks[i] as Dictionary
		var hist_pick: Dictionary = history_picks[i] as Dictionary

		t.assert_eq(int(hist_pick.get("pick_number", 0)), int(exec_pick.get("pick", 0)),
			"pick %d: pick_number should match" % (i + 1))
		t.assert_eq(int(hist_pick.get("round", 0)), int(exec_pick.get("round", 0)),
			"pick %d: round should match" % (i + 1))
		t.assert_eq(String(hist_pick.get("team_id", "")), String(exec_pick.get("team_id", "")),
			"pick %d: team_id should match" % (i + 1))
		t.assert_eq(String(hist_pick.get("player_id", "")), String(exec_pick.get("player_id", "")),
			"pick %d: player_id should match" % (i + 1))
		t.assert_eq(String(hist_pick.get("position", "")), String(exec_pick.get("position", "")),
			"pick %d: position should match" % (i + 1))

func _test_pick_number_round_alignment(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var teams_count := int(league_cfg.get("team_count", 32))

	t.assert_true(picks.size() > 0, "should have picks to test")

	# Verify pick_number corresponds correctly to round
	# Formula: pick_number = (round - 1) * teams_count + pick_in_round
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var pick_number := int(pick.get("pick_number", 0))
		var round := int(pick.get("round", 0))

		# Calculate expected round from pick_number
		var expected_round := ((pick_number - 1) / teams_count) + 1

		t.assert_eq(round, expected_round,
			"pick_number %d should be in round %d, but found round %d" % [pick_number, expected_round, round])

		# Calculate position within round (1-indexed)
		var pick_in_round := ((pick_number - 1) % teams_count) + 1
		t.assert_true(pick_in_round >= 1 and pick_in_round <= teams_count,
			"pick_number %d: pick_in_round should be 1-%d, got %d" % [pick_number, teams_count, pick_in_round])

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
	pool_rng.seed = 55555  # Fixed seed for determinism
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
