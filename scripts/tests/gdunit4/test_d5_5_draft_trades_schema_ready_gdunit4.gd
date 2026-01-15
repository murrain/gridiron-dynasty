## GdUnit4 test suite for D5.5: Draft Pick Trades Schema Ready
##
## Verifies that draft history includes trade tracking fields for future trade system.
## Tests:
##   1. All picks have 'traded' field (boolean)
##   2. All picks have 'original_team_id' field (nullable)
##   3. Phase 1: traded is always false (no trade system yet)
##   4. Phase 1: original_team_id is always null (no trade system yet)
##   5. Schema is forward-compatible for future trade implementation
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


func test_trade_fields_present() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	assert_int(picks.size()).is_greater(0)

	# Verify all picks have trade fields
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary

		assert_bool(pick.has("traded")).is_true()
		assert_bool(pick.has("original_team_id")).is_true()

		# Verify types
		assert_bool(pick.get("traded") is bool).is_true()
		# original_team_id can be null or String
		var orig_team: Variant = pick.get("original_team_id")
		assert_bool(orig_team == null or orig_team is String).is_true()


func test_phase1_traded_always_false() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	assert_int(picks.size()).is_greater(0)

	# Verify all picks have traded = false in Phase 1
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var traded: bool = bool(pick.get("traded", true))

		assert_bool(traded).is_false()


func test_phase1_original_team_id_null() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	assert_int(picks.size()).is_greater(0)

	# Verify all picks have original_team_id = null in Phase 1
	for i in range(picks.size()):
		var pick: Dictionary = picks[i] as Dictionary
		var orig_team: Variant = pick.get("original_team_id")

		assert_that(orig_team).is_null()


func test_schema_compatibility() -> void:
	# This test validates the schema is ready for future trade implementation
	var world_state := _make_world_state_with_draft_pool(100)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks: Array = draft_history.get(2025, []) as Array

	assert_int(picks.size()).is_greater(0)

	# Simulate what future trade system would do
	# Take first pick and mark it as traded
	var first_pick: Dictionary = picks[0] as Dictionary
	var original_team: String = String(first_pick.get("team_id", ""))

	# This is what future trade system would write:
	first_pick["traded"] = true
	first_pick["original_team_id"] = original_team
	first_pick["team_id"] = "nfl_999"

	# Verify the schema can represent a traded pick
	assert_bool(bool(first_pick.get("traded", false))).is_true()
	assert_str(String(first_pick.get("original_team_id", ""))).is_equal(original_team)
	assert_str(String(first_pick.get("team_id", ""))).is_equal("nfl_999")

	# Verify schema validation would work
	_validate_traded_pick_schema(first_pick)

	# Restore for next test (don't mutate world_state)
	first_pick["traded"] = false
	first_pick["original_team_id"] = null
	first_pick["team_id"] = original_team


func _validate_traded_pick_schema(pick: Dictionary) -> void:
	var traded: bool = bool(pick.get("traded", false))
	var original_team_id: Variant = pick.get("original_team_id")

	if traded:
		# Traded picks should have original_team_id set
		assert_bool(original_team_id != null and original_team_id is String).is_true()
		assert_str(String(original_team_id)).is_not_empty()
	else:
		# Non-traded picks should have original_team_id = null
		assert_that(original_team_id).is_null()


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
