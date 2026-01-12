extends RefCounted
## Tests for TestHelpers.gd enhancement - validates new utility functions
##
## This test suite validates that the enhanced helper methods work correctly
## before we refactor 37+ test files to use them.

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

func run(t: TestHelpers) -> void:
	test_create_seeded_rng(t)
	test_assert_deterministic(t)
	test_assert_schema(t)
	test_assert_schema_typed(t)
	test_create_test_player_defaults(t)
	test_create_test_player_custom(t)
	test_create_minimal_world_state(t)
	test_assert_max_time(t)

## Test 1: Verify create_seeded_rng produces consistent RNG
func test_create_seeded_rng(t: TestHelpers) -> void:
	var rng1 := t.create_seeded_rng(12345)
	var rng2 := t.create_seeded_rng(12345)

	# Should produce identical sequences
	var values1: Array = []
	var values2: Array = []

	for i in range(10):
		values1.append(rng1.randf())
		values2.append(rng2.randf())

	t.assert_eq(JSON.stringify(values1), JSON.stringify(values2),
		"create_seeded_rng produces deterministic RNG instances")

	# Different seeds should produce different sequences
	var rng3 := t.create_seeded_rng(99999)
	var values3: Array = []
	for i in range(10):
		values3.append(rng3.randf())

	t.assert_ne(JSON.stringify(values1), JSON.stringify(values3),
		"different seeds produce different sequences")

## Test 2: Verify assert_deterministic helper
func test_assert_deterministic(t: TestHelpers) -> void:
	# Test with deterministic function
	var deterministic_func := func(rng: RandomNumberGenerator) -> Dictionary:
		return {
			"value": rng.randf(),
			"count": rng.randi_range(1, 100)
		}

	# This should pass (no assertion failure)
	t.assert_deterministic(deterministic_func, 42, "deterministic function")

	# We can't easily test failure case without modifying TestHelpers,
	# but we can verify it runs without crashing

## Test 3: Verify assert_schema validates required fields
func test_assert_schema(t: TestHelpers) -> void:
	var valid_player := {
		"player_id": "TEST001",
		"name": "Test",
		"age": 20,
		"position": "QB"
	}

	# Should pass - all fields present
	t.assert_schema(valid_player, ["player_id", "name", "age", "position"],
		"valid player has all fields")

	# Test with missing field - use a separate helper to isolate failures
	var test_helper := TestHelpers.new()
	var incomplete_player := {
		"player_id": "TEST002",
		"name": "Test2"
	}

	test_helper.assert_schema(incomplete_player, ["player_id", "name", "age", "position"],
		"incomplete player schema")

	# Should have detected 2 missing fields (age, position)
	t.assert_eq(test_helper.failures.size(), 2,
		"assert_schema detects missing fields")

## Test 4: Verify assert_schema_typed validates types
func test_assert_schema_typed(t: TestHelpers) -> void:
	var valid_player := {
		"player_id": "TEST001",
		"age": 20,
		"stats": {}
	}

	# Should pass - all types correct
	t.assert_schema_typed(valid_player, {
		"player_id": TYPE_STRING,
		"age": TYPE_INT,
		"stats": TYPE_DICTIONARY
	}, "valid player type schema")

	# Test with wrong type - use a separate helper to isolate failures
	var test_helper := TestHelpers.new()
	var wrong_type_player := {
		"player_id": "TEST002",
		"age": "twenty",  # Should be int
		"stats": {}
	}

	test_helper.assert_schema_typed(wrong_type_player, {
		"player_id": TYPE_STRING,
		"age": TYPE_INT,
		"stats": TYPE_DICTIONARY
	}, "wrong type schema")

	# Should have detected 1 type error
	t.assert_eq(test_helper.failures.size(), 1,
		"assert_schema_typed detects wrong types")

## Test 5: Verify create_test_player with defaults
func test_create_test_player_defaults(t: TestHelpers) -> void:
	var player := t.create_test_player()

	# Verify default values
	t.assert_eq(player["player_id"], "TEST001", "default player_id")
	t.assert_eq(player["position"], "QB", "default position")
	t.assert_eq(player["age"], 18, "default age")
	t.assert_eq(player["college_year"], 1, "default college_year")
	t.assert_eq(player["college_eligibility_status"], "freshman", "default eligibility")

	# Verify structure
	t.assert_schema(player, [
		"player_id", "name", "position", "age", "college_year",
		"college_eligibility_status", "stats", "potential",
		"development_history", "wear"
	], "test player structure")

	# Verify stats exist and are reasonable
	t.assert_true(player.has("stats"), "player has stats")
	var stats: Dictionary = player["stats"]
	t.assert_true(stats.size() > 0, "stats not empty")
	t.assert_true(stats.has("speed"), "stats has speed")

	# Verify potential is higher than stats
	var potential: Dictionary = player["potential"]
	for stat_name in stats.keys():
		if potential.has(stat_name):
			t.assert_true(float(potential[stat_name]) >= float(stats[stat_name]),
				"potential[%s] >= stats[%s]" % [stat_name, stat_name])

## Test 6: Verify create_test_player with custom values
func test_create_test_player_custom(t: TestHelpers) -> void:
	var rb := t.create_test_player("RB001", "RB", 21, 85.0, 4)

	t.assert_eq(rb["player_id"], "RB001", "custom player_id")
	t.assert_eq(rb["position"], "RB", "custom position")
	t.assert_eq(rb["age"], 21, "custom age")
	t.assert_eq(rb["college_year"], 4, "custom college_year")
	t.assert_eq(rb["college_eligibility_status"], "senior", "senior eligibility")

	# RB should have catching stat
	var stats: Dictionary = rb["stats"]
	t.assert_true(stats.has("catching"), "RB has catching stat")

	# Different positions should have different stats
	var qb := t.create_test_player("QB001", "QB", 20, 80.0, 3)
	var qb_stats: Dictionary = qb["stats"]
	t.assert_true(qb_stats.has("accuracy"), "QB has accuracy stat")
	t.assert_true(qb_stats.has("decision"), "QB has decision stat")

## Test 7: Verify create_minimal_world_state
func test_create_minimal_world_state(t: TestHelpers) -> void:
	var world := t.create_minimal_world_state(2026)

	t.assert_eq(world["current_year"], 2026, "custom year")

	# Verify all required fields exist
	t.assert_schema(world, [
		"current_year", "nfl_teams", "nfl_rosters", "colleges",
		"college_rosters", "hs_schools", "hs_players", "draft_pool",
		"retired_players"
	], "world state structure")

	# Verify collections are empty arrays/dicts
	t.assert_eq(world["nfl_teams"].size(), 0, "nfl_teams empty")
	t.assert_eq(world["colleges"].size(), 0, "colleges empty")
	t.assert_eq(world["hs_schools"].size(), 0, "hs_schools empty")

	# Test default year
	var default_world := t.create_minimal_world_state()
	t.assert_eq(default_world["current_year"], 2025, "default year is 2025")

## Test 8: Verify assert_max_time (simplified test)
func test_assert_max_time(t: TestHelpers) -> void:
	# Test with fast operation that should pass
	var fast_operation := func():
		var sum := 0
		for i in range(100):
			sum += i

	# This should pass - 100ms limit for trivial operation
	t.assert_max_time(fast_operation, 100.0, "fast operation completes in time")

	# Test with slow operation that should fail - use a separate helper to isolate failures
	var test_helper := TestHelpers.new()
	var slow_operation := func():
		OS.delay_msec(50)  # 50ms delay

	# This should fail - 1ms limit for 50ms operation
	test_helper.assert_max_time(slow_operation, 1.0, "slow operation exceeds limit")

	# Should have detected 1 timeout
	t.assert_eq(test_helper.failures.size(), 1,
		"assert_max_time detects timeout")
