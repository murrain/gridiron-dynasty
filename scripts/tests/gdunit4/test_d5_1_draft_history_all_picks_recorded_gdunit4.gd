## GdUnit4 test suite for D5.1: Draft History - All Picks Recorded
##
## Verifies that draft_history[year] contains all draft picks for the given year.
## Tests:
##   1. All 224 picks recorded (7 rounds x 32 teams)
##   2. Each pick has required fields
##   3. Draft history persists across multiple years
##   4. Deterministic: same seed produces identical draft history
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


func test_all_picks_recorded() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2025, 12345, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_cfg: Dictionary = _league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(_league_cfg.get("team_count", 32))
	var expected_picks := rounds * teams_count

	assert_bool(world_state.has("draft_history")).is_true()

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	assert_bool(draft_history.has(2025)).is_true()

	var picks_2025: Array = draft_history.get(2025, []) as Array
	assert_int(picks_2025.size()).is_equal(expected_picks)


func test_required_fields_present() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2026, 54321, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks_2026: Array = draft_history.get(2026, []) as Array

	assert_int(picks_2026.size()).is_greater(0)

	# Check first and last picks for required fields
	for pick in [picks_2026[0], picks_2026[picks_2026.size() - 1]]:
		var p: Dictionary = pick as Dictionary

		assert_bool(p.has("pick_number")).is_true()
		assert_bool(p.has("round")).is_true()
		assert_bool(p.has("team_id")).is_true()
		assert_bool(p.has("player_id")).is_true()
		assert_bool(p.has("position")).is_true()
		assert_bool(p.has("college")).is_true()
		assert_bool(p.has("traded")).is_true()
		assert_bool(p.has("original_team_id")).is_true()

		# Verify types
		assert_bool(p.get("pick_number") is int).is_true()
		assert_bool(p.get("round") is int).is_true()
		assert_bool(p.get("team_id") is String).is_true()
		assert_bool(p.get("player_id") is String).is_true()
		assert_bool(p.get("position") is String).is_true()
		assert_bool(p.get("college") is String).is_true()
		assert_bool(p.get("traded") is bool).is_true()

		# Verify values are sensible
		assert_int(int(p.get("pick_number", 0))).is_greater(0)
		assert_int(int(p.get("round", 0))).is_greater_equal(1)
		assert_str(String(p.get("team_id", ""))).is_not_empty()
		assert_str(String(p.get("player_id", ""))).is_not_empty()
		assert_str(String(p.get("position", ""))).is_not_empty()


func test_multi_year_persistence() -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()

	# Run drafts for 3 consecutive years
	var _result_2025 := draft.run(world_state, 2025, 11111, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	# Need to reset draft pool for next year
	world_state["draft_pool"][2026] = _make_fresh_draft_pool(300, 2026)
	var _result_2026 := draft.run(world_state, 2026, 22222, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	world_state["draft_pool"][2027] = _make_fresh_draft_pool(300, 2027)
	var _result_2027 := draft.run(world_state, 2027, 33333, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary

	# Verify all 3 years present
	assert_bool(draft_history.has(2025)).is_true()
	assert_bool(draft_history.has(2026)).is_true()
	assert_bool(draft_history.has(2027)).is_true()

	var draft_cfg: Dictionary = _league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(_league_cfg.get("team_count", 32))
	var expected_picks := rounds * teams_count

	# Verify each year has full draft
	var picks_2025: Array = draft_history.get(2025, []) as Array
	var picks_2026: Array = draft_history.get(2026, []) as Array
	var picks_2027: Array = draft_history.get(2027, []) as Array

	assert_int(picks_2025.size()).is_equal(expected_picks)
	assert_int(picks_2026.size()).is_equal(expected_picks)
	assert_int(picks_2027.size()).is_equal(expected_picks)

	# Verify picks are different across years (different seeds = different players)
	var first_pick_2025: Dictionary = picks_2025[0] as Dictionary
	var first_pick_2026: Dictionary = picks_2026[0] as Dictionary
	assert_str(String(first_pick_2025.get("player_id", ""))).is_not_equal(
		String(first_pick_2026.get("player_id", "")))


func test_draft_history_determinism() -> void:
	var world_state_a := _make_world_state_with_draft_pool(200)
	var world_state_b := _make_world_state_with_draft_pool(200)
	var draft_a := NflDraft.new()
	var draft_b := NflDraft.new()

	var seed := 99999
	var _result_a := draft_a.run(world_state_a, 2030, seed, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)
	var _result_b := draft_b.run(world_state_b, 2030, seed, _league_cfg, _positions_cfg, _stats_cfg, _scouts_cfg, _main_cfg)

	var draft_history_a: Dictionary = world_state_a.get("draft_history", {}) as Dictionary
	var draft_history_b: Dictionary = world_state_b.get("draft_history", {}) as Dictionary

	var picks_a: Array = draft_history_a.get(2030, []) as Array
	var picks_b: Array = draft_history_b.get(2030, []) as Array

	assert_int(picks_a.size()).is_equal(picks_b.size())

	# Verify all picks are identical
	for i in range(min(picks_a.size(), picks_b.size())):
		var pa: Dictionary = picks_a[i] as Dictionary
		var pb: Dictionary = picks_b[i] as Dictionary

		assert_int(int(pa.get("pick_number", 0))).is_equal(int(pb.get("pick_number", 0)))
		assert_int(int(pa.get("round", 0))).is_equal(int(pb.get("round", 0)))
		assert_str(String(pa.get("team_id", ""))).is_equal(String(pb.get("team_id", "")))
		assert_str(String(pa.get("player_id", ""))).is_equal(String(pb.get("player_id", "")))
		assert_str(String(pa.get("position", ""))).is_equal(String(pb.get("position", "")))
		assert_str(String(pa.get("college", ""))).is_equal(String(pb.get("college", "")))
		assert_bool(bool(pa.get("traded", true))).is_equal(bool(pb.get("traded", true)))


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

	var draft_pool: Array = _make_fresh_draft_pool(pool_size, 2025)

	return {
		"nfl_teams": teams,
		"nfl_rosters": {},
		"draft_pool": {2025: draft_pool}
	}


func _make_fresh_draft_pool(pool_size: int, year: int) -> Array:
	var draft_pool: Array = []
	var positions: Array[String] = ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
	var pool_rng := RandomNumberGenerator.new()
	pool_rng.seed = 55555 + year
	for i in range(pool_size):
		var pos: String = positions[i % positions.size()]
		draft_pool.append(_make_draft_player("dp_%d_%04d" % [year, i + 1], pos, 70.0 + pool_rng.randf() * 20.0, year))
	return draft_pool


func _make_draft_player(player_id: String, pos: String, rating: float, year: int) -> Dictionary:
	var college_num: int = (hash(player_id) % 130) + 1
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"age": 22,
		"draft_eligible": true,
		"draft_year": year,
		"college_team_id": "college_%03d" % college_num,
		"stats": {"speed": rating, "acceleration": rating - 5.0, "agility": rating - 3.0},
		"potential": {"speed": rating + 5.0, "acceleration": rating, "agility": rating + 2.0},
		"composite_score": rating
	}
