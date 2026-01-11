extends RefCounted

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

## Test D5.5: Draft Pick Trades Schema Ready
##
## Verifies that draft history includes trade tracking fields for future trade system.
## Tests:
##   1. All picks have 'traded' field (boolean)
##   2. All picks have 'original_team_id' field (nullable)
##   3. Phase 1: traded is always false (no trade system yet)
##   4. Phase 1: original_team_id is always null (no trade system yet)
##   5. Schema is forward-compatible for future trade implementation

func run(t) -> void:
	var config := ConfigService.new()
	var league_cfg := config.get_config("world/league")
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var main_cfg := config.get_config("main")

	# Test 1: Trade fields present in all picks
	_test_trade_fields_present(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 2: Phase 1 - traded always false
	_test_phase1_traded_always_false(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 3: Phase 1 - original_team_id always null
	_test_phase1_original_team_id_null(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 4: Schema compatibility for future trades
	_test_schema_compatibility(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

func _test_trade_fields_present(
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

	# Verify all picks have trade fields
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary

		t.assert_true(pick.has("traded"),
			"pick %d should have 'traded' field" % (i + 1))
		t.assert_true(pick.has("original_team_id"),
			"pick %d should have 'original_team_id' field" % (i + 1))

		# Verify types
		t.assert_true(pick.get("traded") is bool,
			"pick %d: 'traded' should be bool type" % (i + 1))
		# original_team_id can be null or String
		var orig_team: Variant = pick.get("original_team_id")
		t.assert_true(orig_team == null or orig_team is String,
			"pick %d: 'original_team_id' should be null or String type" % (i + 1))

func _test_phase1_traded_always_false(
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

	# Verify all picks have traded = false in Phase 1
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var traded: bool = bool(pick.get("traded", true))

		t.assert_true(not traded,
			"pick %d: 'traded' should be false in Phase 1 (no trade system)" % (i + 1))

func _test_phase1_original_team_id_null(
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

	# Verify all picks have original_team_id = null in Phase 1
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var orig_team: Variant = pick.get("original_team_id")

		t.assert_eq(orig_team, null,
			"pick %d: 'original_team_id' should be null in Phase 1 (no trade system)" % (i + 1))

func _test_schema_compatibility(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	# This test validates the schema is ready for future trade implementation
	# When trades are implemented, the system should be able to:
	# 1. Set traded = true for traded picks
	# 2. Set original_team_id to the team that originally owned the pick
	# 3. Maintain backward compatibility with existing draft history

	var world_state := _make_world_state_with_draft_pool(100)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	t.assert_true(picks.size() > 0, "should have picks to test")

	# Simulate what future trade system would do
	# Take first pick and mark it as traded
	var first_pick: Dictionary = picks[0] as Dictionary
	var original_team: String = String(first_pick.get("team_id", ""))

	# This is what future trade system would write:
	first_pick["traded"] = true
	first_pick["original_team_id"] = original_team
	first_pick["team_id"] = "nfl_999"  # New team that received pick

	# Verify the schema can represent a traded pick
	t.assert_true(bool(first_pick.get("traded", false)),
		"schema should support setting traded = true")
	t.assert_eq(String(first_pick.get("original_team_id", "")), original_team,
		"schema should support storing original_team_id")
	t.assert_eq(String(first_pick.get("team_id", "")), "nfl_999",
		"schema should support updating team_id for traded picks")

	# Verify schema validation would work
	_validate_traded_pick_schema(t, first_pick)

	# Restore for next test (don't mutate world_state)
	first_pick["traded"] = false
	first_pick["original_team_id"] = null
	first_pick["team_id"] = original_team

func _validate_traded_pick_schema(t, pick: Dictionary) -> void:
	# Future trade system validation logic
	# Validates that traded picks have consistent data

	var traded: bool = bool(pick.get("traded", false))
	var original_team_id: Variant = pick.get("original_team_id")
	var team_id: String = String(pick.get("team_id", ""))

	if traded:
		# Traded picks should have original_team_id set
		t.assert_true(original_team_id != null and original_team_id is String,
			"traded pick should have non-null original_team_id")
		t.assert_true(String(original_team_id) != "",
			"traded pick should have non-empty original_team_id")

		# team_id and original_team_id should be different
		# (unless traded back to original team, edge case)
		# We won't enforce this in Phase 1, but schema allows it

	else:
		# Non-traded picks should have original_team_id = null
		t.assert_eq(original_team_id, null,
			"non-traded pick should have null original_team_id")

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
