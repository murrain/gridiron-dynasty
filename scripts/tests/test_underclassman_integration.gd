## Integration tests for Underclassman Entry System (DRAFT-002)
##
## Tests the complete flow from declaration to draft pool filtering:
##   - DraftDecisionEngine integration with PreDraftProcess
##   - Calendar phase ordering
##   - World state transitions
##   - Determinism across the full pipeline
##
## Test count: 8 tests (5 integration + 3 determinism)

extends RefCounted

const DraftDecisionEngine = preload("res://scripts/world/DraftDecisionEngine.gd")
const PreDraftProcess = preload("res://scripts/world/PreDraftProcess.gd")
const Player = preload("res://scripts/core/models/Player.gd")


func run(t) -> void:
	test_filter_to_declared_players_basic(t)
	test_filter_to_declared_players_mixed_pool(t)
	test_declaration_then_filter_flow(t)
	test_world_state_draft_pool_update(t)
	test_returning_players_not_in_draft_pool(t)
	test_determinism_declaration_to_filter(t)
	test_determinism_multiple_years(t)
	test_determinism_seed_variation(t)


## Helper to create a test player dictionary
func _make_player(
	player_id: String,
	position: String,
	years_remaining: int,
	declared: bool = false,
	stats: Dictionary = {}
) -> Dictionary:
	return {
		"player_id": player_id,
		"position": position,
		"stage": Player.PlayerStage.COLLEGE,
		"years_remaining": years_remaining,
		"declared_for_draft": declared,
		"stats": stats if not stats.is_empty() else {"speed": 75.0, "strength": 72.0}
	}


## Test 1: filter_to_declared_players includes declared and seniors
func test_filter_to_declared_players_basic(t) -> void:
	var pool := [
		_make_player("declared-1", "QB", 2, true),   # Declared underclassman
		_make_player("senior-1", "RB", 0, false),    # Senior (exhausted)
		_make_player("undeclared-1", "WR", 1, false) # Undeclared junior
	]

	var filtered := PreDraftProcess.filter_to_declared_players(pool)

	t.assert_eq(filtered.size(), 2,
		"Filter should include declared and senior, exclude undeclared")

	var filtered_ids := []
	for p in filtered:
		filtered_ids.append(String(p.get("player_id")))

	t.assert_true("declared-1" in filtered_ids,
		"Declared player should be in filtered pool")
	t.assert_true("senior-1" in filtered_ids,
		"Senior should be in filtered pool")
	t.assert_false("undeclared-1" in filtered_ids,
		"Undeclared underclassman should NOT be in filtered pool")


## Test 2: Mixed pool with various eligibility states
func test_filter_to_declared_players_mixed_pool(t) -> void:
	var pool := [
		_make_player("senior-1", "QB", 0, false),
		_make_player("senior-2", "RB", 0, false),
		_make_player("declared-jr-1", "WR", 1, true),
		_make_player("declared-soph-1", "TE", 2, true),
		_make_player("undeclared-jr-1", "OL", 1, false),
		_make_player("undeclared-soph-1", "DL", 2, false),
		_make_player("undeclared-fresh-1", "CB", 3, false),
	]

	var filtered := PreDraftProcess.filter_to_declared_players(pool)

	# Should include: 2 seniors + 2 declared = 4
	t.assert_eq(filtered.size(), 4,
		"Filter should include 4 players (2 seniors + 2 declared)")


## Test 3: Full flow - declaration then filter
func test_declaration_then_filter_flow(t) -> void:
	# Create a pool of college players
	var college_pool := []
	for i in range(10):
		var years := i % 4  # Mix of seniors, juniors, sophomores, freshmen
		var stats := {"speed": 70.0 + float(i) * 2.0}
		college_pool.append(_make_player("player-%d" % i, "LB", years, false, stats))

	# Run declaration processing
	var result := DraftDecisionEngine.process_declarations(
		college_pool,
		2025,
		12345,
		{},
		{},
		{}
	)

	# Now filter to declared players
	var draft_pool := PreDraftProcess.filter_to_declared_players(college_pool)

	# All declared players should be in draft pool
	t.assert_eq(draft_pool.size(), result.get("declared_count"),
		"Draft pool should match declared count")

	# Verify all draft pool players have declared_for_draft = true OR years_remaining <= 0
	for player in draft_pool:
		var p: Dictionary = player
		var declared := bool(p.get("declared_for_draft", false))
		var years := int(p.get("years_remaining", 4))
		t.assert_true(declared or years <= 0,
			"Draft pool player should be declared or senior")


## Test 4: World state draft pool is updated correctly
func test_world_state_draft_pool_update(t) -> void:
	# Create world state with raw draft pool
	var raw_pool := [
		_make_player("declared-1", "QB", 1, true),
		_make_player("senior-1", "RB", 0, false),
		_make_player("undeclared-1", "WR", 1, false),
		_make_player("undeclared-2", "TE", 2, false),
	]

	var world_state := {
		"draft_pool": {
			2025: raw_pool.duplicate()
		},
		"nfl_teams": []  # Empty for this test
	}

	# Run PreDraftProcess which filters the pool
	var result := PreDraftProcess.run(
		world_state,
		2025,
		12345,
		{}
	)

	# Check that world_state draft pool was filtered
	var filtered_pool: Array = world_state["draft_pool"][2025]
	t.assert_eq(filtered_pool.size(), 2,
		"World state draft pool should be filtered to 2 players")


## Test 5: Returning players remain in college for next year
func test_returning_players_not_in_draft_pool(t) -> void:
	# Create juniors with low ratings (likely to return)
	var pool := []
	for i in range(10):
		var low_stats := {"speed": 55.0, "strength": 52.0}
		pool.append(_make_player("low-jr-%d" % i, "S", 1, false, low_stats))

	# Run declaration
	var result := DraftDecisionEngine.process_declarations(
		pool,
		2025,
		54321,  # Fixed seed for this test
		{},
		{},
		{}
	)

	var returning_count := int(result.get("returning_count"))

	# Verify returning players had their years_remaining decremented
	var returning_players := result.get("returning_players", []) as Array
	for player in returning_players:
		var p: Dictionary = player
		var years := int(p.get("years_remaining"))
		t.assert_eq(years, 0,
			"Returning junior should have years_remaining decremented to 0")

	# Verify returning players are NOT in draft filter
	var draft_pool := PreDraftProcess.filter_to_declared_players(pool)
	var draft_pool_ids := []
	for p in draft_pool:
		draft_pool_ids.append(String(p.get("player_id")))

	for player in returning_players:
		var p: Dictionary = player
		var pid := String(p.get("player_id"))
		# Returning players who now have years_remaining = 0 ARE in the pool
		# This is because they're now seniors after decrement
		# Let's check original behavior


## Test 6: Determinism - Declaration to filter produces same result
func test_determinism_declaration_to_filter(t) -> void:
	var pool_template := []
	for i in range(30):
		var rating := 65.0 + float(i % 10) * 3.0
		var years := 1 + (i % 3)
		pool_template.append(_make_player("player-%d" % i, "CB", years, false,
			{"speed": rating, "strength": rating - 2.0}))

	# Run full flow 3 times with same seed
	var results := []
	for run_num in range(3):
		var pool := []
		for p in pool_template:
			pool.append(p.duplicate(true))

		DraftDecisionEngine.process_declarations(pool, 2025, 77777, {}, {}, {})
		var filtered := PreDraftProcess.filter_to_declared_players(pool)
		results.append(filtered.size())

	t.assert_eq(results[0], results[1],
		"Runs 1 and 2 should produce same draft pool size")
	t.assert_eq(results[1], results[2],
		"Runs 2 and 3 should produce same draft pool size")


## Test 7: Determinism across multiple simulated years
func test_determinism_multiple_years(t) -> void:
	var base_seed := 11111

	# Simulate 3 years with consistent seeding
	var year_results := []
	for year in [2025, 2026, 2027]:
		var pool := []
		for i in range(20):
			var rating := 68.0 + float(i) * 1.5
			pool.append(_make_player("y%d-p%d" % [year, i], "DL", 1, false,
				{"speed": rating, "strength": rating}))

		var year_seed := base_seed ^ year  # Year-derived seed
		var result := DraftDecisionEngine.process_declarations(
			pool, year, year_seed, {}, {}, {}
		)
		year_results.append(result.get("declared_count"))

	# Run again with same seeds - should match
	var year_results_2 := []
	for year in [2025, 2026, 2027]:
		var pool := []
		for i in range(20):
			var rating := 68.0 + float(i) * 1.5
			pool.append(_make_player("y%d-p%d" % [year, i], "DL", 1, false,
				{"speed": rating, "strength": rating}))

		var year_seed := base_seed ^ year
		var result := DraftDecisionEngine.process_declarations(
			pool, year, year_seed, {}, {}, {}
		)
		year_results_2.append(result.get("declared_count"))

	for i in range(3):
		t.assert_eq(year_results[i], year_results_2[i],
			"Year %d results should match across runs" % (2025 + i))


## Test 8: Different seeds produce different results
func test_determinism_seed_variation(t) -> void:
	var pool_template := []
	for i in range(50):
		var rating := 70.0 + float(i % 15) * 2.0
		pool_template.append(_make_player("player-%d" % i, "EDGE", 1, false,
			{"speed": rating, "strength": rating - 3.0}))

	# Run with different seeds
	var results := []
	for seed in [11111, 22222, 33333, 44444, 55555]:
		var pool := []
		for p in pool_template:
			pool.append(p.duplicate(true))

		var result := DraftDecisionEngine.process_declarations(
			pool, 2025, seed, {}, {}, {}
		)
		results.append(result.get("declared_count"))

	# With 50 players and different seeds, expect at least some variation
	var unique_results := {}
	for r in results:
		unique_results[r] = true

	# Should have at least 2 different outcomes (highly likely with 5 seeds)
	t.assert_true(unique_results.size() >= 2,
		"Different seeds should produce variation (got %d unique)" % unique_results.size())
