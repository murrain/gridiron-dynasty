## GdUnit4 test suite for TestHelpers enhancement validation
##
## Validates that the TestHelpers utility functions work correctly.
## This tests the legacy TestHelpers to ensure compatibility during migration.
##
## Migrated from test_testhelpers_enhancement.gd
extends GdUnitTestSuite

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")


func test_create_seeded_rng_produces_deterministic_instances() -> void:
	var t := TestHelpers.new()
	var rng1 := t.create_seeded_rng(12345)
	var rng2 := t.create_seeded_rng(12345)

	var values1: Array = []
	var values2: Array = []

	for i in range(10):
		values1.append(rng1.randf())
		values2.append(rng2.randf())

	assert_str(JSON.stringify(values1)).is_equal(JSON.stringify(values2))


func test_create_seeded_rng_different_seeds_produce_different_sequences() -> void:
	var t := TestHelpers.new()
	var rng1 := t.create_seeded_rng(12345)
	var rng3 := t.create_seeded_rng(99999)

	var values1: Array = []
	var values3: Array = []

	for i in range(10):
		values1.append(rng1.randf())
		values3.append(rng3.randf())

	assert_str(JSON.stringify(values1)).is_not_equal(JSON.stringify(values3))


func test_assert_deterministic_passes_for_deterministic_function() -> void:
	var t := TestHelpers.new()

	var deterministic_func := func(rng: RandomNumberGenerator) -> Dictionary:
		return {
			"value": rng.randf(),
			"count": rng.randi_range(1, 100)
		}

	t.assert_deterministic(deterministic_func, 42, "deterministic function")

	# Should have no failures
	assert_int(t.failures.size()).is_equal(0)


func test_assert_schema_passes_with_all_fields_present() -> void:
	var t := TestHelpers.new()
	var valid_player := {
		"player_id": "TEST001",
		"name": "Test",
		"age": 20,
		"position": "QB"
	}

	t.assert_schema(valid_player, ["player_id", "name", "age", "position"],
		"valid player has all fields")

	assert_int(t.failures.size()).is_equal(0)


func test_assert_schema_detects_missing_fields() -> void:
	var t := TestHelpers.new()
	var incomplete_player := {
		"player_id": "TEST002",
		"name": "Test2"
	}

	t.assert_schema(incomplete_player, ["player_id", "name", "age", "position"],
		"incomplete player schema")

	# Should have detected 2 missing fields (age, position)
	assert_int(t.failures.size()).is_equal(2)


func test_assert_schema_typed_passes_with_correct_types() -> void:
	var t := TestHelpers.new()
	var valid_player := {
		"player_id": "TEST001",
		"age": 20,
		"stats": {}
	}

	t.assert_schema_typed(valid_player, {
		"player_id": TYPE_STRING,
		"age": TYPE_INT,
		"stats": TYPE_DICTIONARY
	}, "valid player type schema")

	assert_int(t.failures.size()).is_equal(0)


func test_assert_schema_typed_detects_wrong_types() -> void:
	var t := TestHelpers.new()
	var wrong_type_player := {
		"player_id": "TEST002",
		"age": "twenty",  # Should be int
		"stats": {}
	}

	t.assert_schema_typed(wrong_type_player, {
		"player_id": TYPE_STRING,
		"age": TYPE_INT,
		"stats": TYPE_DICTIONARY
	}, "wrong type schema")

	# Should have detected 1 type error
	assert_int(t.failures.size()).is_equal(1)


func test_create_test_player_default_player_id() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()
	assert_str(String(player["player_id"])).is_equal("TEST001")


func test_create_test_player_default_position() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()
	assert_str(String(player["position"])).is_equal("QB")


func test_create_test_player_default_age() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()
	assert_int(int(player["age"])).is_equal(18)


func test_create_test_player_default_college_year() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()
	assert_int(int(player["college_year"])).is_equal(1)


func test_create_test_player_has_all_fields() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()

	var required_fields := [
		"player_id", "name", "position", "age", "college_year",
		"college_eligibility_status", "stats", "potential",
		"development_history", "wear"
	]

	for field in required_fields:
		assert_bool(player.has(field)).override_failure_message(
			"player should have field: %s" % field
		).is_true()


func test_create_test_player_stats_not_empty() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()
	var stats: Dictionary = player["stats"]
	assert_int(stats.size()).is_greater(0)


func test_create_test_player_potential_gte_stats() -> void:
	var t := TestHelpers.new()
	var player := t.create_test_player()
	var stats: Dictionary = player["stats"]
	var potential: Dictionary = player["potential"]

	for stat_name in stats.keys():
		if potential.has(stat_name):
			assert_float(float(potential[stat_name])).is_greater_equal(float(stats[stat_name]))


func test_create_test_player_custom_values() -> void:
	var t := TestHelpers.new()
	var rb := t.create_test_player("RB001", "RB", 21, 85.0, 4)

	assert_str(String(rb["player_id"])).is_equal("RB001")
	assert_str(String(rb["position"])).is_equal("RB")
	assert_int(int(rb["age"])).is_equal(21)
	assert_int(int(rb["college_year"])).is_equal(4)


func test_create_test_player_rb_has_catching_stat() -> void:
	var t := TestHelpers.new()
	var rb := t.create_test_player("RB001", "RB", 21, 85.0, 4)
	var stats: Dictionary = rb["stats"]
	assert_bool(stats.has("catching")).is_true()


func test_create_test_player_qb_has_accuracy_stat() -> void:
	var t := TestHelpers.new()
	var qb := t.create_test_player("QB001", "QB", 20, 80.0, 3)
	var stats: Dictionary = qb["stats"]
	assert_bool(stats.has("accuracy")).is_true()


func test_create_minimal_world_state_custom_year() -> void:
	var t := TestHelpers.new()
	var world := t.create_minimal_world_state(2026)
	assert_int(int(world["current_year"])).is_equal(2026)


func test_create_minimal_world_state_default_year() -> void:
	var t := TestHelpers.new()
	var world := t.create_minimal_world_state()
	assert_int(int(world["current_year"])).is_equal(2025)


func test_create_minimal_world_state_has_all_fields() -> void:
	var t := TestHelpers.new()
	var world := t.create_minimal_world_state()

	var required_fields := [
		"current_year", "nfl_teams", "nfl_rosters", "colleges",
		"college_rosters", "hs_schools", "hs_players", "draft_pool",
		"retired_players"
	]

	for field in required_fields:
		assert_bool(world.has(field)).override_failure_message(
			"world state should have field: %s" % field
		).is_true()


func test_create_minimal_world_state_collections_empty() -> void:
	var t := TestHelpers.new()
	var world := t.create_minimal_world_state()
	assert_int((world["nfl_teams"] as Array).size()).is_equal(0)
	assert_int((world["colleges"] as Array).size()).is_equal(0)
	assert_int((world["hs_schools"] as Array).size()).is_equal(0)


func test_assert_max_time_passes_for_fast_operation() -> void:
	var t := TestHelpers.new()

	var fast_operation := func():
		var sum := 0
		for i in range(100):
			sum += i

	t.assert_max_time(fast_operation, 100.0, "fast operation")

	assert_int(t.failures.size()).is_equal(0)


func test_assert_max_time_detects_timeout() -> void:
	var t := TestHelpers.new()

	var slow_operation := func():
		OS.delay_msec(50)

	t.assert_max_time(slow_operation, 1.0, "slow operation")

	# Should have detected 1 timeout
	assert_int(t.failures.size()).is_equal(1)
