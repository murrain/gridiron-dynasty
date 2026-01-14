## Tests for SnapshotLoader functionality
##
## Validates that world state snapshots can be loaded and contain expected data.
## Run after generating snapshots with SnapshotGenerator.gd
##
## Test categories:
##   - Basic loading via setup_world()
##   - Data validation (required keys, counts)
##   - Deep copy isolation (mutation safety)
##   - Performance benchmarks (deep copy timing)
##   - Cache behavior (hit/miss, isolation)
##   - Config-driven snapshot discovery
extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

const TEST_SEED := 0xTEST001

func run(t: TestHelpers) -> void:
	# Clear cache between tests for isolation
	SnapshotLoader.clear_cache()

	# Config loading tests
	test_config_loads(t)
	test_available_years(t)

	# Basic loading tests via setup_world()
	test_5yr_snapshot_loads(t)
	test_10yr_snapshot_loads(t)
	test_20yr_snapshot_loads(t)

	# Data validation
	test_snapshot_contains_expected_data(t)
	test_snapshot_has_valid_structure(t)

	# Isolation and mutation safety
	test_setup_world_returns_isolated_copy(t)
	test_multiple_calls_return_independent_copies(t)

	# Performance
	test_setup_world_performance(t)
	test_cache_hit_performance(t)

	# Cache behavior
	test_cache_clear_works(t)

	# Error handling
	test_handles_missing_file(t)
	test_handles_invalid_base_year(t)
	test_requires_nonzero_seed(t)

func test_config_loads(t: TestHelpers) -> void:
	# Test that config file loads and has expected structure
	var years := SnapshotLoader.get_available_years()
	t.assert_true(years.size() > 0, "config loads with available years")

	# Should have at least 5, 10, 20 year snapshots defined
	t.assert_true(years.has(5), "config has 5-year snapshot defined")
	t.assert_true(years.has(10), "config has 10-year snapshot defined")
	t.assert_true(years.has(20), "config has 20-year snapshot defined")

func test_available_years(t: TestHelpers) -> void:
	var years := SnapshotLoader.get_available_years()
	t.assert_true(years.is_sorted(), "available years are sorted")

	# Test that years are integers
	for year in years:
		t.assert_true(year is int, "year is integer")

func test_5yr_snapshot_loads(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] 5yr snapshot not generated yet")
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	t.assert_true(not world_state.is_empty(), "5yr snapshot loads successfully")
	t.assert_true(world_state.has("nfl_teams"), "5yr snapshot has nfl_teams")
	t.assert_true(world_state.has("colleges"), "5yr snapshot has colleges")

func test_10yr_snapshot_loads(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_10yr.json"):
		print("  [SKIP] 10yr snapshot not generated yet")
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, TEST_SEED)
	t.assert_true(not world_state.is_empty(), "10yr snapshot loads successfully")
	t.assert_true(world_state.has("nfl_teams"), "10yr snapshot has nfl_teams")
	t.assert_true(world_state.has("retired_players"), "10yr snapshot has retired_players")

func test_20yr_snapshot_loads(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_20yr.json"):
		print("  [SKIP] 20yr snapshot not generated yet")
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_20, 0, TEST_SEED)
	t.assert_true(not world_state.is_empty(), "20yr snapshot loads successfully")
	t.assert_true(world_state.has("nfl_teams"), "20yr snapshot has nfl_teams")

	# 20yr should have substantial retired player pool
	var retired: Array = world_state.get("retired_players", [])
	t.assert_true(retired.size() > 100, "20yr snapshot has 100+ retired players (got %d)" % retired.size())

func test_snapshot_contains_expected_data(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	# Check required top-level keys
	var required_keys := [
		"nfl_teams", "nfl_rosters", "colleges", "college_rosters",
		"hs_schools", "hs_players", "draft_pool", "retired_players"
	]

	for key in required_keys:
		t.assert_true(world_state.has(key), "snapshot has required key: %s" % key)

	# Check NFL teams structure
	var nfl_teams: Array = world_state.get("nfl_teams", [])
	t.assert_true(nfl_teams.size() == 32, "snapshot has 32 NFL teams (got %d)" % nfl_teams.size())

	# Check college count
	var colleges: Array = world_state.get("colleges", [])
	t.assert_true(colleges.size() > 0, "snapshot has colleges (got %d)" % colleges.size())

func test_snapshot_has_valid_structure(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	# Verify NFL rosters have expected structure
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	t.assert_true(nfl_rosters.size() == 32, "32 NFL roster entries (got %d)" % nfl_rosters.size())

	# Check at least one roster has players
	var has_players := false
	for team_id in nfl_rosters.keys():
		var roster = nfl_rosters[team_id]
		if roster is Dictionary:
			var players: Array = roster.get("players", [])
			if players.size() > 0:
				has_players = true
				break
		elif roster is Array:
			if (roster as Array).size() > 0:
				has_players = true
				break

	t.assert_true(has_players, "at least one roster has players")

func test_setup_world_returns_isolated_copy(t: TestHelpers) -> void:
	## Verifies that setup_world() always returns an isolated copy safe to mutate
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# Get first copy and mutate it
	var copy1 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var teams1: Array = copy1.get("nfl_teams", [])
	var original_count := teams1.size()

	# Mutate the copy
	teams1.append({"id": "TEST_TEAM", "name": "Test Team"})

	# Get second copy - should be unaffected by mutation
	var copy2 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var teams2: Array = copy2.get("nfl_teams", [])

	t.assert_eq(teams2.size(), original_count,
		"second copy unaffected by first mutation (got %d, expected %d)" % [teams2.size(), original_count])

func test_multiple_calls_return_independent_copies(t: TestHelpers) -> void:
	## Comprehensive test for mutation isolation across multiple scenarios
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	var copy1 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var copy2 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	var teams1: Array = copy1.get("nfl_teams", [])
	var teams2: Array = copy2.get("nfl_teams", [])

	if teams1.size() > 0 and teams2.size() > 0:
		# Test 1: Modify existing value
		var team1: Dictionary = teams1[0]
		var original_id := team1.get("id", "")
		team1["id"] = "MODIFIED_ID_12345"

		var team2: Dictionary = teams2[0]
		t.assert_eq(team2.get("id", ""), original_id,
			"modifying copy1 doesn't affect copy2")

		# Test 2: Add new key
		team1["_test_key"] = "added"
		t.assert_true(not team2.has("_test_key"),
			"new key in copy1 doesn't appear in copy2")

	# Test 3: Nested mutation
	var rosters1: Dictionary = copy1.get("nfl_rosters", {})
	var rosters2: Dictionary = copy2.get("nfl_rosters", {})

	if not rosters1.is_empty():
		var first_key: String = rosters1.keys()[0]
		var roster1 = rosters1[first_key]
		if roster1 is Dictionary:
			roster1["_nested_test"] = "modified"

			var roster2 = rosters2.get(first_key, {})
			if roster2 is Dictionary:
				t.assert_true(not roster2.has("_nested_test"),
					"nested modification in copy1 doesn't affect copy2")

func test_setup_world_performance(t: TestHelpers) -> void:
	## Benchmark setup_world to ensure it's acceptably fast
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# Warm up the cache first
	var _ := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	# Time a second call (includes deep copy but cache is warm)
	var start := Time.get_ticks_usec()
	var copy := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0

	print("  setup_world (5yr, cached): %.2f ms" % elapsed_ms)

	# Should complete in < 500ms for 5yr snapshot
	t.assert_true(elapsed_ms < 500.0, "setup_world completes in < 500ms (took %.2fms)" % elapsed_ms)
	t.assert_true(not copy.is_empty(), "setup_world produces non-empty result")

func test_cache_hit_performance(t: TestHelpers) -> void:
	## Verify internal cache makes subsequent loads faster
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# First load (cache miss - parses JSON)
	var start1 := Time.get_ticks_usec()
	var _ := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var miss_time := (Time.get_ticks_usec() - start1) / 1000.0

	# Second load (cache hit - skips JSON parsing)
	var start2 := Time.get_ticks_usec()
	var _ = SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var hit_time := (Time.get_ticks_usec() - start2) / 1000.0

	print("  Cache miss: %.2f ms, Cache hit: %.2f ms" % [miss_time, hit_time])

	# Cache hit should be reasonably fast (under 500ms including deep copy)
	t.assert_true(hit_time < 500.0, "cache hit is fast (< 500ms, got %.2fms)" % hit_time)

func test_cache_clear_works(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	# Load to populate cache
	var _ := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	# Clear cache
	SnapshotLoader.clear_cache()

	# Verify we can still load after clear
	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	t.assert_true(not world_state.is_empty(), "cache clear allows fresh load")

func test_handles_missing_file(t: TestHelpers) -> void:
	## Verify graceful handling of missing snapshot files
	SnapshotLoader.clear_cache()

	# This should not crash, just return empty and log error
	var result := SnapshotLoader._load_snapshot("nonexistent_snapshot.json")
	t.assert_true(result.is_empty(), "missing file returns empty dictionary")

func test_handles_invalid_base_year(t: TestHelpers) -> void:
	## Verify graceful handling of invalid base year
	SnapshotLoader.clear_cache()

	# Try to load a year that doesn't exist in config
	var result := SnapshotLoader.setup_world(999, 0, TEST_SEED)
	t.assert_true(result.is_empty(), "invalid base year returns empty dictionary")

func test_requires_nonzero_seed(t: TestHelpers) -> void:
	## Verify seed validation
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	# Seed of 0 should fail
	var result := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, 0)
	t.assert_true(result.is_empty(), "seed=0 returns empty dictionary")
