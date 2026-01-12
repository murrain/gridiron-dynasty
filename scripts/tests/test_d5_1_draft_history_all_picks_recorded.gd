extends RefCounted

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

## Test D5.1: Draft History - All Picks Recorded
##
## Verifies that draft_history[year] contains all draft picks for the given year.
## Tests:
##   1. All 250 picks recorded (7 rounds × 32 teams + compensatory picks if any)
##   2. Each pick has required fields: pick_number, round, team_id, player_id, position, college
##   3. Draft history persists across multiple years
##   4. Deterministic: same seed produces identical draft history

func run(t) -> void:
	var config := ConfigService.new()
	var league_cfg := config.get_config("world/league")
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var main_cfg := config.get_config("main")

	# Test 1: All picks recorded in draft history
	_test_all_picks_recorded(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 2: Draft history has required fields
	_test_required_fields_present(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 3: Draft history persists across multiple years
	_test_multi_year_persistence(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Test 4: Draft history is deterministic
	_test_draft_history_determinism(t, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

func _test_all_picks_recorded(
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

	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(league_cfg.get("team_count", 32))
	var expected_picks := rounds * teams_count

	# Verify draft_history exists in world_state
	t.assert_true(world_state.has("draft_history"), "world_state should have draft_history")

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	t.assert_true(draft_history.has(2025), "draft_history should have entry for year 2025")

	var picks_2025: Array = draft_history.get(2025, []) as Array
	t.assert_eq(picks_2025.size(), expected_picks,
		"draft_history[2025] should contain all %d picks" % expected_picks)

func _test_required_fields_present(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(100)
	var draft := NflDraft.new()
	var _result := draft.run(world_state, 2026, 54321, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary
	var picks_2026: Array = draft_history.get(2026, []) as Array

	t.assert_true(picks_2026.size() > 0, "should have at least one pick to test")

	# Check first and last picks for required fields
	for pick in [picks_2026[0], picks_2026[picks_2026.size() - 1]]:
		var p: Dictionary = pick as Dictionary

		t.assert_true(p.has("pick_number"), "pick should have pick_number field")
		t.assert_true(p.has("round"), "pick should have round field")
		t.assert_true(p.has("team_id"), "pick should have team_id field")
		t.assert_true(p.has("player_id"), "pick should have player_id field")
		t.assert_true(p.has("position"), "pick should have position field")
		t.assert_true(p.has("college"), "pick should have college field")
		t.assert_true(p.has("traded"), "pick should have traded field (D5.5)")
		t.assert_true(p.has("original_team_id"), "pick should have original_team_id field (D5.5)")

		# Verify types
		t.assert_true(p.get("pick_number") is int, "pick_number should be int")
		t.assert_true(p.get("round") is int, "round should be int")
		t.assert_true(p.get("team_id") is String, "team_id should be String")
		t.assert_true(p.get("player_id") is String, "player_id should be String")
		t.assert_true(p.get("position") is String, "position should be String")
		t.assert_true(p.get("college") is String, "college should be String")
		t.assert_true(p.get("traded") is bool, "traded should be bool")

		# Verify values are sensible
		t.assert_true(int(p.get("pick_number", 0)) > 0, "pick_number should be positive")
		t.assert_true(int(p.get("round", 0)) >= 1, "round should be >= 1")
		t.assert_true(String(p.get("team_id", "")) != "", "team_id should not be empty")
		t.assert_true(String(p.get("player_id", "")) != "", "player_id should not be empty")
		t.assert_true(String(p.get("position", "")) != "", "position should not be empty")

func _test_multi_year_persistence(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state := _make_world_state_with_draft_pool(300)
	var draft := NflDraft.new()

	# Run drafts for 3 consecutive years
	var _result_2025 := draft.run(world_state, 2025, 11111, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	# Need to reset draft pool for next year
	world_state["draft_pool"][2026] = _make_fresh_draft_pool(300, 2026)
	var _result_2026 := draft.run(world_state, 2026, 22222, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	world_state["draft_pool"][2027] = _make_fresh_draft_pool(300, 2027)
	var _result_2027 := draft.run(world_state, 2027, 33333, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history: Dictionary = world_state.get("draft_history", {}) as Dictionary

	# Verify all 3 years present
	t.assert_true(draft_history.has(2025), "draft_history should have 2025")
	t.assert_true(draft_history.has(2026), "draft_history should have 2026")
	t.assert_true(draft_history.has(2027), "draft_history should have 2027")

	var draft_cfg: Dictionary = league_cfg.get("draft", {}) as Dictionary
	var rounds := int(draft_cfg.get("rounds", 7))
	var teams_count := int(league_cfg.get("team_count", 32))
	var expected_picks := rounds * teams_count

	# Verify each year has full draft
	var picks_2025: Array = draft_history.get(2025, []) as Array
	var picks_2026: Array = draft_history.get(2026, []) as Array
	var picks_2027: Array = draft_history.get(2027, []) as Array

	t.assert_eq(picks_2025.size(), expected_picks, "2025 should have all picks")
	t.assert_eq(picks_2026.size(), expected_picks, "2026 should have all picks")
	t.assert_eq(picks_2027.size(), expected_picks, "2027 should have all picks")

	# Verify picks are different across years (different seeds = different players)
	var first_pick_2025: Dictionary = picks_2025[0] as Dictionary
	var first_pick_2026: Dictionary = picks_2026[0] as Dictionary
	t.assert_ne(String(first_pick_2025.get("player_id", "")),
		String(first_pick_2026.get("player_id", "")),
		"different years should draft different players (different seeds)")

func _test_draft_history_determinism(
	t,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	var world_state_a := _make_world_state_with_draft_pool(200)
	var world_state_b := _make_world_state_with_draft_pool(200)
	var draft_a := NflDraft.new()
	var draft_b := NflDraft.new()

	var seed := 99999
	var _result_a := draft_a.run(world_state_a, 2030, seed, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)
	var _result_b := draft_b.run(world_state_b, 2030, seed, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	var draft_history_a: Dictionary = world_state_a.get("draft_history", {}) as Dictionary
	var draft_history_b: Dictionary = world_state_b.get("draft_history", {}) as Dictionary

	var picks_a: Array = draft_history_a.get(2030, []) as Array
	var picks_b: Array = draft_history_b.get(2030, []) as Array

	t.assert_eq(picks_a.size(), picks_b.size(), "pick count should be deterministic")

	# Verify all picks are identical
	for i in range(min(picks_a.size(), picks_b.size())):
		var pa: Dictionary = picks_a[i] as Dictionary
		var pb: Dictionary = picks_b[i] as Dictionary

		t.assert_eq(int(pa.get("pick_number", 0)), int(pb.get("pick_number", 0)),
			"pick %d: pick_number should be deterministic" % (i + 1))
		t.assert_eq(int(pa.get("round", 0)), int(pb.get("round", 0)),
			"pick %d: round should be deterministic" % (i + 1))
		t.assert_eq(String(pa.get("team_id", "")), String(pb.get("team_id", "")),
			"pick %d: team_id should be deterministic" % (i + 1))
		t.assert_eq(String(pa.get("player_id", "")), String(pb.get("player_id", "")),
			"pick %d: player_id should be deterministic" % (i + 1))
		t.assert_eq(String(pa.get("position", "")), String(pb.get("position", "")),
			"pick %d: position should be deterministic" % (i + 1))
		t.assert_eq(String(pa.get("college", "")), String(pb.get("college", "")),
			"pick %d: college should be deterministic" % (i + 1))
		t.assert_eq(bool(pa.get("traded", true)), bool(pb.get("traded", true)),
			"pick %d: traded should be deterministic" % (i + 1))

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
	pool_rng.seed = 55555 + year  # Year-specific seed for different pools
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
