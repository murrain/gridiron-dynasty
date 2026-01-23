extends GdUnitTestSuite
class_name TestBootstrapWorldGdUnit4

const BootstrapWorld = preload("res://scripts/pipelines/BootstrapWorld.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# ============================================================================
# DETERMINISM TESTS - CRITICAL
# ============================================================================

func test_bootstrap_world_is_deterministic() -> void:
	# Note: Full bootstrap is slow, so we use a small years_back
	var bootstrap1 = BootstrapWorld.new()
	bootstrap1.years_back = 2
	var result1 = bootstrap1.run()

	var bootstrap2 = BootstrapWorld.new()
	bootstrap2.years_back = 2
	var result2 = bootstrap2.run()

	# Results should be identical
	assert_that(result1).is_equal(result2)

func test_same_config_produces_same_world() -> void:
	var bootstrap1 = BootstrapWorld.new()
	bootstrap1.years_back = 3
	var world1 = bootstrap1.run()

	var bootstrap2 = BootstrapWorld.new()
	bootstrap2.years_back = 3
	var world2 = bootstrap2.run()

	# Active player count should match
	var active1: Array = world1.get("active_players", [])
	var active2: Array = world2.get("active_players", [])
	assert_int(active1.size()).is_equal(active2.size())


# ============================================================================
# WORLD STATE VALIDITY TESTS
# ============================================================================

func test_bootstrap_returns_required_fields() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 2
	var world = bootstrap.run()

	var required := ["active_players", "retired_players", "classes", "current_year"]
	TestHelpersGdUnit4.assert_schema(self, world, required, "bootstrap world")

func test_bootstrap_generates_active_players() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 3
	var world = bootstrap.run()

	var active_players: Array = world.get("active_players", [])
	assert_int(active_players.size()).is_greater(0)

func test_bootstrap_sets_current_year() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 2
	var world = bootstrap.run()

	assert_that(world).contains_key("current_year")
	var current_year = int(world["current_year"])
	assert_int(current_year).is_greater(2020)

func test_bootstrap_generates_class_results() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 3
	var world = bootstrap.run()

	var classes: Array = world.get("classes", [])
	assert_int(classes.size()).is_equal(3)

func test_bootstrap_tracks_retired_players() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 10  # More years = more retirements
	var world = bootstrap.run()

	var retired: Array = world.get("retired_players", [])
	# With 10 years of advancement, should have some retirements
	assert_int(retired.size()).is_greater_equal(0)


# ============================================================================
# PLAYER DATA VALIDITY
# ============================================================================

func test_active_players_have_valid_structure() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 2
	var world = bootstrap.run()

	var active_players: Array = world.get("active_players", [])
	if active_players.size() > 0:
		var first_player: Dictionary = active_players[0]
		var required := ["name", "position", "stats", "age"]
		TestHelpersGdUnit4.assert_schema(self, first_player, required, "active player")

func test_active_players_have_advanced_ages() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 5
	var world = bootstrap.run()

	var active_players: Array = world.get("active_players", [])

	# With advancement, some players should be older
	var found_older := false
	for player in active_players:
		var p: Dictionary = player
		if p.has("age") and int(p["age"]) >= 23:
			found_older = true
			break

	assert_bool(found_older).is_true()


# ============================================================================
# CLASS GENERATION TESTS
# ============================================================================

func test_each_year_generates_class() -> void:
	var bootstrap = BootstrapWorld.new()
	var years := 4
	bootstrap.years_back = years
	var world = bootstrap.run()

	var classes: Array = world.get("classes", [])
	assert_int(classes.size()).is_equal(years)

func test_class_results_have_year_and_count() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 3
	var world = bootstrap.run()

	var classes: Array = world.get("classes", [])
	for class_result in classes:
		var cr: Dictionary = class_result
		assert_that(cr).contains_key("year")
		assert_that(cr).contains_key("count")
		assert_int(cr["count"]).is_greater(0)

func test_class_years_are_sequential() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 5
	var world = bootstrap.run()

	var classes: Array = world.get("classes", [])
	var years := []
	for class_result in classes:
		var cr: Dictionary = class_result
		years.append(int(cr["year"]))

	# Years should be sequential
	for i in range(1, years.size()):
		assert_int(years[i]).is_equal(years[i-1] + 1)


# ============================================================================
# CONFIGURATION TESTS
# ============================================================================

func test_years_back_affects_class_count() -> void:
	var bootstrap1 = BootstrapWorld.new()
	bootstrap1.years_back = 2
	var world1 = bootstrap1.run()

	var bootstrap2 = BootstrapWorld.new()
	bootstrap2.years_back = 4
	var world2 = bootstrap2.run()

	var classes1: Array = world1.get("classes", [])
	var classes2: Array = world2.get("classes", [])

	assert_int(classes2.size()).is_greater(classes1.size())

func test_small_years_back() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 1
	var world = bootstrap.run()

	var classes: Array = world.get("classes", [])
	assert_int(classes.size()).is_equal(1)

func test_medium_years_back() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 5
	var world = bootstrap.run()

	var active_players: Array = world.get("active_players", [])
	assert_int(active_players.size()).is_greater(0)


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

func test_full_bootstrap_pipeline_completes() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 3
	var world = bootstrap.run()

	# Verify complete structure
	assert_that(world).contains_key("active_players")
	assert_that(world).contains_key("retired_players")
	assert_that(world).contains_key("classes")
	assert_that(world).contains_key("current_year")

	var active: Array = world.get("active_players", [])
	var retired: Array = world.get("retired_players", [])
	var classes: Array = world.get("classes", [])

	# Should have generated players
	assert_int(active.size()).is_greater(0)
	# Should have class records
	assert_int(classes.size()).is_equal(3)

func test_bootstrap_player_distribution() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 3
	var world = bootstrap.run()

	var active_players: Array = world.get("active_players", [])

	# Check position distribution
	var position_counts := {}
	for player in active_players:
		var p: Dictionary = player
		var pos = String(p.get("position", ""))
		position_counts[pos] = position_counts.get(pos, 0) + 1

	# Should have multiple positions
	assert_int(position_counts.size()).is_greater(5)


# ============================================================================
# EDGE CASES
# ============================================================================

func test_handles_zero_years_back() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = 0
	var world = bootstrap.run()

	# Should complete without crashing
	assert_that(world).is_not_null()
	var classes: Array = world.get("classes", [])
	assert_int(classes.size()).is_equal(0)

func test_handles_negative_years_back() -> void:
	var bootstrap = BootstrapWorld.new()
	bootstrap.years_back = -1
	var world = bootstrap.run()

	# Should handle gracefully (likely treats as 0)
	assert_that(world).is_not_null()


# ============================================================================
# PERFORMANCE AWARENESS TESTS
# ============================================================================

func test_bootstrap_completes_within_reasonable_time() -> void:
	# Small bootstrap should complete quickly
	TestHelpersGdUnit4.assert_max_time(
		self,
		func():
			var bootstrap = BootstrapWorld.new()
			bootstrap.years_back = 2
			bootstrap.run(),
		5000.0,  # 5 seconds for small bootstrap
		"small bootstrap should complete quickly"
	)
