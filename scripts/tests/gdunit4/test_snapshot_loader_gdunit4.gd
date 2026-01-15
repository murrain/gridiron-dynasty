## GdUnit4 test suite for SnapshotLoader functionality
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
##
## Migrated from test_snapshot_loader.gd
extends GdUnitTestSuite

const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

const TEST_SEED := 0x7E57001


func after() -> void:
	# Clear cache after all tests for isolation
	SnapshotLoader.clear_cache()


func test_config_loads_with_available_years() -> void:
	var years := SnapshotLoader.get_available_years()
	assert_int(years.size()).is_greater(0)


func test_config_has_5_year_snapshot() -> void:
	var years := SnapshotLoader.get_available_years()
	assert_bool(years.has(5)).is_true()


func test_config_has_10_year_snapshot() -> void:
	var years := SnapshotLoader.get_available_years()
	assert_bool(years.has(10)).is_true()


func test_config_has_20_year_snapshot() -> void:
	var years := SnapshotLoader.get_available_years()
	assert_bool(years.has(20)).is_true()


func test_available_years_are_sorted() -> void:
	var years := SnapshotLoader.get_available_years()
	# Check if sorted (is_sorted not available in Godot 4.5)
	var is_sorted: bool = true
	for i in range(1, years.size()):
		if years[i] < years[i - 1]:
			is_sorted = false
			break
	assert_bool(is_sorted).is_true()


func test_available_years_are_integers() -> void:
	var years := SnapshotLoader.get_available_years()
	for year in years:
		assert_bool(year is int).is_true()


func test_5yr_snapshot_loads_successfully() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return  # Skip if snapshot not generated

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	assert_bool(not world_state.is_empty()).is_true()


func test_5yr_snapshot_has_nfl_teams() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	assert_bool(world_state.has("nfl_teams")).is_true()


func test_5yr_snapshot_has_colleges() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	assert_bool(world_state.has("colleges")).is_true()


func test_10yr_snapshot_loads_successfully() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_10yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, TEST_SEED)
	assert_bool(not world_state.is_empty()).is_true()


func test_10yr_snapshot_has_retired_players() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_10yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, TEST_SEED)
	assert_bool(world_state.has("retired_players")).is_true()


func test_20yr_snapshot_loads_successfully() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_20yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_20, 0, TEST_SEED)
	assert_bool(not world_state.is_empty()).is_true()


func test_20yr_snapshot_has_substantial_retired_pool() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_20yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_20, 0, TEST_SEED)
	var retired: Array = world_state.get("retired_players", [])
	assert_int(retired.size()).is_greater(100)


func test_snapshot_has_required_keys() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var required_keys := [
		"nfl_teams", "nfl_rosters", "colleges", "college_rosters",
		"hs_schools", "hs_players", "draft_pool", "retired_players"
	]

	for key in required_keys:
		assert_bool(world_state.has(key)).override_failure_message(
			"snapshot should have required key: %s" % key
		).is_true()


func test_snapshot_has_32_nfl_teams() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var nfl_teams: Array = world_state.get("nfl_teams", [])
	assert_int(nfl_teams.size()).is_equal(32)


func test_snapshot_has_colleges() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var colleges: Array = world_state.get("colleges", [])
	assert_int(colleges.size()).is_greater(0)


func test_snapshot_has_32_nfl_roster_entries() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})
	assert_int(nfl_rosters.size()).is_equal(32)


func test_at_least_one_roster_has_players() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})

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

	assert_bool(has_players).is_true()


func test_setup_world_returns_isolated_copy() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	SnapshotLoader.clear_cache()

	var copy1 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var teams1: Array = copy1.get("nfl_teams", [])
	var original_count := teams1.size()

	teams1.append({"id": "TEST_TEAM", "name": "Test Team"})

	var copy2 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var teams2: Array = copy2.get("nfl_teams", [])

	assert_int(teams2.size()).is_equal(original_count)


func test_multiple_copies_have_independent_values() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	SnapshotLoader.clear_cache()

	var copy1 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var copy2 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	var teams1: Array = copy1.get("nfl_teams", [])
	var teams2: Array = copy2.get("nfl_teams", [])

	if teams1.size() > 0 and teams2.size() > 0:
		var team1: Dictionary = teams1[0]
		var original_id: String = String(team1.get("id", ""))
		team1["id"] = "MODIFIED_ID_12345"

		var team2: Dictionary = teams2[0]
		assert_str(String(team2.get("id", ""))).is_equal(original_id)


func test_new_key_does_not_appear_in_other_copy() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	SnapshotLoader.clear_cache()

	var copy1 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var copy2 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	var teams1: Array = copy1.get("nfl_teams", [])
	var teams2: Array = copy2.get("nfl_teams", [])

	if teams1.size() > 0:
		var team1: Dictionary = teams1[0]
		team1["_test_key"] = "added"

		var team2: Dictionary = teams2[0]
		assert_bool(not team2.has("_test_key")).is_true()


func test_nested_modification_isolation() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	SnapshotLoader.clear_cache()

	var copy1 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var copy2 := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	var rosters1: Dictionary = copy1.get("nfl_rosters", {})
	var rosters2: Dictionary = copy2.get("nfl_rosters", {})

	if not rosters1.is_empty():
		var first_key: String = rosters1.keys()[0]
		var roster1 = rosters1[first_key]
		if roster1 is Dictionary:
			roster1["_nested_test"] = "modified"

			var roster2 = rosters2.get(first_key, {})
			if roster2 is Dictionary:
				assert_bool(not roster2.has("_nested_test")).is_true()


func test_setup_world_performance() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	SnapshotLoader.clear_cache()

	# Warm up cache
	var _unused := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	var start := Time.get_ticks_usec()
	var copy := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0

	assert_float(elapsed_ms).is_less(500.0)
	assert_bool(not copy.is_empty()).is_true()


func test_cache_hit_is_fast() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	SnapshotLoader.clear_cache()

	# First load (cache miss)
	var _unused := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)

	# Second load (cache hit)
	var start := Time.get_ticks_usec()
	var _unused2 = SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	var hit_time := (Time.get_ticks_usec() - start) / 1000.0

	assert_float(hit_time).is_less(500.0)


func test_cache_clear_allows_fresh_load() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var _unused := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	SnapshotLoader.clear_cache()

	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, TEST_SEED)
	assert_bool(not world_state.is_empty()).is_true()


func test_missing_file_returns_empty() -> void:
	SnapshotLoader.clear_cache()
	var result := SnapshotLoader._load_snapshot("nonexistent_snapshot.json")
	assert_bool(result.is_empty()).is_true()


func test_invalid_base_year_returns_empty() -> void:
	SnapshotLoader.clear_cache()
	var result := SnapshotLoader.setup_world(999, 0, TEST_SEED)
	assert_bool(result.is_empty()).is_true()


func test_zero_seed_returns_empty() -> void:
	if not SnapshotLoader.snapshot_exists("snapshot_5yr.json"):
		return

	var result := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, 0)
	assert_bool(result.is_empty()).is_true()
