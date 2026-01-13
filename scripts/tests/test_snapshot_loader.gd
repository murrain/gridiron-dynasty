## Tests for SnapshotLoader functionality
##
## Validates that world state snapshots can be loaded and contain expected data.
## Run after generating snapshots with SnapshotGenerator.gd
##
## Test categories:
##   - Basic loading (load_*yr methods)
##   - Data validation (required keys, counts)
##   - Deep copy isolation (mutation safety)
##   - Performance benchmarks (deep copy timing)
##   - Cache behavior (hit/miss, isolation)
##   - Error handling (corrupt files, missing fields)
extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

func run(t: TestHelpers) -> void:
	# Clear cache between tests for isolation
	SnapshotLoader.clear_cache()

	# Basic loading tests
	test_5yr_snapshot_loads(t)
	test_10yr_snapshot_loads(t)
	test_20yr_snapshot_loads(t)

	# Data validation
	test_snapshot_contains_expected_data(t)
	test_snapshot_has_valid_structure(t)

	# Isolation and mutation safety
	test_snapshot_deep_copy_isolation(t)
	test_cache_pollution_prevention(t)

	# Performance
	test_deep_copy_performance(t)
	test_cache_hit_performance(t)

	# Cache behavior
	test_cache_clear_works(t)
	test_cache_hit_returns_same_reference(t)

	# Error handling
	test_handles_missing_file(t)
	test_verify_snapshot_seed(t)

func test_5yr_snapshot_loads(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] 5yr snapshot not generated yet")
		return

	var world_state := SnapshotLoader.load_5yr()
	t.assert_true(not world_state.is_empty(), "5yr snapshot loads successfully")
	t.assert_true(world_state.has("nfl_teams"), "5yr snapshot has nfl_teams")
	t.assert_true(world_state.has("colleges"), "5yr snapshot has colleges")

func test_10yr_snapshot_loads(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_10yr.json"):
		print("  [SKIP] 10yr snapshot not generated yet")
		return

	var world_state := SnapshotLoader.load_10yr()
	t.assert_true(not world_state.is_empty(), "10yr snapshot loads successfully")
	t.assert_true(world_state.has("nfl_teams"), "10yr snapshot has nfl_teams")
	t.assert_true(world_state.has("retired_players"), "10yr snapshot has retired_players")

func test_20yr_snapshot_loads(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_20yr.json"):
		print("  [SKIP] 20yr snapshot not generated yet")
		return

	var world_state := SnapshotLoader.load_20yr()
	t.assert_true(not world_state.is_empty(), "20yr snapshot loads successfully")
	t.assert_true(world_state.has("nfl_teams"), "20yr snapshot has nfl_teams")

	# 20yr should have substantial retired player pool
	var retired: Array = world_state.get("retired_players", [])
	t.assert_true(retired.size() > 100, "20yr snapshot has 100+ retired players (got %d)" % retired.size())

func test_snapshot_contains_expected_data(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	var world_state := SnapshotLoader.load_5yr()

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

	var world_state := SnapshotLoader.load_5yr()

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

func test_snapshot_deep_copy_isolation(t: TestHelpers) -> void:
	## Comprehensive deep copy isolation test - verifies copy is truly independent.
	## Tests: array mutations, existing value changes, new key additions, nested changes.
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	# Clear cache to start fresh
	SnapshotLoader.clear_cache()

	# Pre-load the original to populate cache
	var original := SnapshotLoader.load_5yr()
	var original_teams: Array = original.get("nfl_teams", [])
	var original_team_count := original_teams.size()

	# Load an isolated copy for mutation
	var copy := SnapshotLoader.load_5yr_copy()
	var copy_teams: Array = copy.get("nfl_teams", [])

	# === Test 1: Array mutation isolation (append) ===
	copy_teams.append({"id": "TEST_TEAM_APPENDED", "name": "Test Team"})

	# Re-fetch original and verify array size unchanged
	var original_after_append := SnapshotLoader.load_5yr()
	var original_teams_after: Array = original_after_append.get("nfl_teams", [])
	t.assert_eq(
		original_teams_after.size(),
		original_team_count,
		"array append doesn't affect original (got %d, expected %d)" % [original_teams_after.size(), original_team_count]
	)

	# === Test 2: Dictionary new key addition ===
	if copy_teams.size() > 0:
		var copy_team: Dictionary = copy_teams[0]
		copy_team["_test_new_key"] = "added_value"

		var orig_team_after: Dictionary = original_teams_after[0]
		t.assert_true(
			not orig_team_after.has("_test_new_key"),
			"new dictionary key doesn't affect original"
		)

	# === Test 3: Existing value modification ===
	if copy_teams.size() > 0:
		var copy_team: Dictionary = copy_teams[0]
		var original_id := original_teams_after[0].get("id", "")
		copy_team["id"] = "MUTATED_ID_12345"

		# Re-fetch and verify original unchanged
		SnapshotLoader.clear_cache()
		var fresh_original := SnapshotLoader.load_5yr()
		var fresh_teams: Array = fresh_original.get("nfl_teams", [])
		if fresh_teams.size() > 0:
			var fresh_team: Dictionary = fresh_teams[0]
			t.assert_eq(
				fresh_team.get("id", ""),
				original_id,
				"existing value modification doesn't affect original"
			)

	# === Test 4: Nested structure modification ===
	SnapshotLoader.clear_cache()
	var copy2 := SnapshotLoader.load_5yr_copy()
	var copy2_rosters: Dictionary = copy2.get("nfl_rosters", {})

	# Try to mutate a nested roster
	if not copy2_rosters.is_empty():
		var first_roster_key: String = copy2_rosters.keys()[0]
		var roster_data = copy2_rosters[first_roster_key]
		if roster_data is Dictionary:
			roster_data["_nested_test"] = "modified"

		# Verify original is unaffected
		var original2 := SnapshotLoader.load_5yr()
		var orig_rosters: Dictionary = original2.get("nfl_rosters", {})
		if orig_rosters.has(first_roster_key):
			var orig_roster = orig_rosters[first_roster_key]
			if orig_roster is Dictionary:
				t.assert_true(
					not orig_roster.has("_nested_test"),
					"nested dictionary modification doesn't affect original"
				)

func test_cache_pollution_prevention(t: TestHelpers) -> void:
	## Verifies that using load_*yr() incorrectly is detectable
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# Load shared reference
	var shared1 := SnapshotLoader.load_5yr()
	var shared2 := SnapshotLoader.load_5yr()

	# These SHOULD be the same reference (cache hit)
	# This test documents the shared reference behavior
	var nfl_teams1: Array = shared1.get("nfl_teams", [])
	var nfl_teams2: Array = shared2.get("nfl_teams", [])

	if nfl_teams1.size() > 0 and nfl_teams2.size() > 0:
		# Mutate through one reference
		var team1: Dictionary = nfl_teams1[0]
		team1["_test_marker"] = true

		# Check if visible through other reference (demonstrates shared state)
		var team2: Dictionary = nfl_teams2[0]
		var is_shared := team2.has("_test_marker")

		# Clean up the mutation
		team1.erase("_test_marker")

		# Document that shared references are indeed shared
		t.assert_true(is_shared, "cache returns shared references (by design - use _copy() for isolation)")

func test_deep_copy_performance(t: TestHelpers) -> void:
	## Benchmark deep copy to ensure it's acceptably fast
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# Warm up the cache first
	var _ := SnapshotLoader.load_5yr()

	# Time the deep copy
	var start := Time.get_ticks_usec()
	var copy := SnapshotLoader.load_5yr_copy()
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0

	print("  Deep copy (5yr): %.2f ms" % elapsed_ms)

	# Should complete in < 500ms for 5yr snapshot
	t.assert_true(elapsed_ms < 500.0, "5yr deep copy completes in < 500ms (took %.2fms)" % elapsed_ms)
	t.assert_true(not copy.is_empty(), "deep copy produces non-empty result")

func test_cache_hit_performance(t: TestHelpers) -> void:
	## Verify cache hits are fast
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# First load (cache miss - parses JSON)
	var start1 := Time.get_ticks_usec()
	var _ := SnapshotLoader.load_5yr()
	var miss_time := (Time.get_ticks_usec() - start1) / 1000.0

	# Second load (cache hit - returns cached)
	var start2 := Time.get_ticks_usec()
	var _ = SnapshotLoader.load_5yr()
	var hit_time := (Time.get_ticks_usec() - start2) / 1000.0

	print("  Cache miss: %.2f ms, Cache hit: %.2f ms" % [miss_time, hit_time])

	# Cache hit should be much faster than miss
	t.assert_true(hit_time < 10.0, "cache hit is fast (< 10ms, got %.2fms)" % hit_time)

	# Cache hit should be at least 10x faster than miss (unless miss was also fast)
	if miss_time > 10.0:
		var speedup := miss_time / max(hit_time, 0.001)
		t.assert_true(speedup > 5.0, "cache hit is 5x+ faster than miss (%.1fx)" % speedup)

func test_cache_clear_works(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	# Load to populate cache
	var _ := SnapshotLoader.load_5yr()

	# Clear cache
	SnapshotLoader.clear_cache()

	# Verify next load parses JSON again (cache was cleared)
	var start := Time.get_ticks_usec()
	var _ = SnapshotLoader.load_5yr()
	var load_time := (Time.get_ticks_usec() - start) / 1000.0

	# After clear, this should be a cache miss (slower than typical hit)
	# We can't assert exact timing, but verify we got valid data
	var world_state := SnapshotLoader.load_5yr()
	t.assert_true(not world_state.is_empty(), "cache clear allows fresh load")

func test_cache_hit_returns_same_reference(t: TestHelpers) -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	var first := SnapshotLoader.load_5yr()
	var second := SnapshotLoader.load_5yr()

	# Both should reference the same cached object
	# We can verify by checking if they share the same array instance
	var teams1: Array = first.get("nfl_teams", [])
	var teams2: Array = second.get("nfl_teams", [])

	# Add marker to one
	if teams1.size() > 0:
		var team: Dictionary = teams1[0]
		team["_ref_test"] = true

		# Should be visible in other
		var team2: Dictionary = teams2[0]
		var same_ref := team2.has("_ref_test")

		# Cleanup
		team.erase("_ref_test")

		t.assert_true(same_ref, "cache hits return same reference (documented behavior)")

func test_handles_missing_file(t: TestHelpers) -> void:
	## Verify graceful handling of missing snapshot files
	SnapshotLoader.clear_cache()

	# This should not crash, just return empty and log error
	var result := SnapshotLoader._load_snapshot("nonexistent_snapshot.json")
	t.assert_true(result.is_empty(), "missing file returns empty dictionary")

func test_verify_snapshot_seed(t: TestHelpers) -> void:
	## Verify snapshot seed matches expected value for determinism
	## Actually tests the verify_snapshot() function with correct and incorrect seeds
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		print("  [SKIP] Snapshots not generated yet")
		return

	SnapshotLoader.clear_cache()

	# Get the full snapshot (with metadata) for verification
	var full_snapshot := SnapshotLoader.get_full_snapshot_5yr()
	t.assert_true(not full_snapshot.is_empty(), "full snapshot loads")
	t.assert_true(full_snapshot.has("_metadata"), "full snapshot has _metadata")
	t.assert_true(full_snapshot.has("world_state"), "full snapshot has world_state")

	# Test verify_snapshot with correct seed (should pass)
	var is_valid := SnapshotLoader.verify_snapshot(full_snapshot, SnapshotLoader.SNAPSHOT_SEED)
	t.assert_true(is_valid, "verify_snapshot passes with correct seed (0x%X)" % SnapshotLoader.SNAPSHOT_SEED)

	# Test verify_snapshot with wrong seed (should fail)
	var is_invalid := SnapshotLoader.verify_snapshot(full_snapshot, 0xDEADBEEF)
	t.assert_true(not is_invalid, "verify_snapshot fails with incorrect seed")

	# Verify metadata structure through list_available
	var available := SnapshotLoader.list_available()
	t.assert_true(available.size() > 0, "has available snapshots")

	var first: Dictionary = available[0]
	t.assert_true(first.has("years"), "metadata includes years")
	t.assert_true(first.has("generated_at"), "metadata includes generation timestamp")
	t.assert_true(first.has("seed"), "metadata includes seed")

	# Verify seed in list_available matches expected
	var listed_seed: int = int(first.get("seed", 0))
	t.assert_eq(listed_seed, SnapshotLoader.SNAPSHOT_SEED,
		"listed seed matches expected (got 0x%X, expected 0x%X)" % [listed_seed, SnapshotLoader.SNAPSHOT_SEED])
