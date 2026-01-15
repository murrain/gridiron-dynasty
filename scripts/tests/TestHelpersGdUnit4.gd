## GdUnit4-compatible test helpers providing custom assertions.
##
## This utility class provides assertion methods that work with GdUnit4's fluent API
## while maintaining determinism guarantees and test infrastructure patterns.
##
## Usage:
##   TestHelpersGdUnit4.assert_deterministic(self, callable, seed, "operation is deterministic")
##   TestHelpersGdUnit4.assert_schema(self, obj, ["field1", "field2"], "object structure")
##   TestHelpersGdUnit4.assert_max_time(self, callable, 500.0, "operation completes in 500ms")
##
## All methods are static to avoid state and ensure thread-safety.
extends RefCounted
class_name TestHelpersGdUnit4


## Verify a function is deterministic with a given seed.
##
## This helper consolidates the common pattern of running a function twice with the same
## seed and verifying the results are identical. It uses GdUnit4's deep equality
## instead of JSON stringification to handle dictionary key ordering correctly.
##
## RNG Consumption Pattern:
##   - Creates two independent RNG instances with the same seed
##   - Passes each to the callable exactly once
##   - Expects the callable to consume RNG deterministically
##
## @param suite: The GdUnitTestSuite instance (pass `self` from test)
## @param callable: Function that accepts an RNG as its parameter and returns a result
## @param seed_value: Integer seed for deterministic RNG initialization
## @param message: Description of what is being tested
static func assert_deterministic(suite: Object, callable: Callable, seed_value: int, message: String) -> void:
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed_value
	var result1 = callable.call(rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_value
	var result2 = callable.call(rng2)

	# Use GdUnit4's deep equality - handles dictionaries, arrays, nested structures
	# GdUnit4's assert_that performs deep comparison correctly
	suite.assert_that(result1).override_failure_message(
		"Determinism: %s\nFirst run and second run produced different results with same seed %d" % [message, seed_value]
	).is_equal(result2)


## Assert a dictionary has all required fields.
##
## Validates that an object (typically a player, team, or game state dictionary)
## contains all expected fields. This catches API contract violations early.
##
## @param suite: The GdUnitTestSuite instance (pass `self` from test)
## @param obj: Dictionary to validate
## @param required_fields: Array of field names (strings) that must be present
## @param message: Description of what structure is being validated
static func assert_schema(suite: Object, obj: Dictionary, required_fields: Array, message: String) -> void:
	for field in required_fields:
		var field_str := String(field)
		suite.assert_bool(obj.has(field_str)).override_failure_message(
			"%s: missing required field '%s'" % [message, field_str]
		).is_true()


## Assert a dictionary has fields with specific types.
##
## Validates both field presence and type correctness. More strict than assert_schema.
##
## @param suite: The GdUnitTestSuite instance (pass `self` from test)
## @param obj: Dictionary to validate
## @param schema: Dictionary mapping field names to expected Godot TYPE_* constants
## @param message: Description of what structure is being validated
static func assert_schema_typed(suite: Object, obj: Dictionary, schema: Dictionary, message: String) -> void:
	for field_name in schema.keys():
		var field_str := String(field_name)
		var expected_type: int = int(schema[field_name])

		suite.assert_bool(obj.has(field_str)).override_failure_message(
			"%s: missing field '%s'" % [message, field_str]
		).is_true()

		if obj.has(field_str):
			var actual_value = obj[field_str]
			var actual_type := typeof(actual_value)
			suite.assert_int(actual_type).override_failure_message(
				"%s: field '%s' has wrong type (expected %s, got %s)" %
				[message, field_str, _type_to_string(expected_type), _type_to_string(actual_type)]
			).is_equal(expected_type)


## Assert an operation completes within a time limit.
##
## Converts informational performance prints into actual test assertions. This prevents
## silent performance regressions from entering the codebase.
##
## @param suite: The GdUnitTestSuite instance (pass `self` from test)
## @param callable: Function to measure (should take no parameters)
## @param max_ms: Maximum allowed execution time in milliseconds
## @param message: Description of the performance requirement
static func assert_max_time(suite: Object, callable: Callable, max_ms: float, message: String) -> void:
	var start_usec := Time.get_ticks_usec()
	callable.call()
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var elapsed_ms := elapsed_usec / 1000.0

	suite.assert_float(elapsed_ms).override_failure_message(
		"%s (took %.2fms, max %.2fms)" % [message, elapsed_ms, max_ms]
	).is_less_equal(max_ms)


## Create a seeded RNG instance.
##
## This standardizes RNG creation across all tests, ensuring consistent seed initialization.
## Always use this instead of creating RandomNumberGenerator instances manually.
##
## @param seed_value: Integer seed for deterministic RNG initialization
## @return: Seeded RandomNumberGenerator instance ready for use
static func create_seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Create a test player with sensible defaults for GdUnit4 tests.
##
## All parameters are optional with reasonable defaults.
##
## @param player_id: Unique identifier (default: "TEST001")
## @param position: Player position (default: "QB")
## @param age: Player age in years (default: 18)
## @param rating: Overall rating 0-100 (default: 75.0)
## @param college_year: College year 1-4 (default: 1)
## @return: Dictionary representing a valid player for testing
static func create_test_player(
	player_id: String = "TEST001",
	position: String = "QB",
	age: int = 18,
	rating: float = 75.0,
	college_year: int = 1
) -> Dictionary:
	var stats := _generate_stats_for_position(position, rating)
	var potential := _generate_potential_for_rating(stats, rating)

	return {
		"player_id": player_id,
		"name": "Test Player %s" % player_id,
		"position": position,
		"age": age,
		"college_year": college_year,
		"college_eligibility_status": _year_to_status(college_year),
		"stats": stats,
		"potential": potential,
		"development_history": [],
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injuries": 0
		}
	}


## Create minimal world state for testing.
##
## @param year: Current simulation year (default: 2025)
## @return: Dictionary with minimal world state structure
static func create_minimal_world_state(year: int = 2025) -> Dictionary:
	return {
		"current_year": year,
		"nfl_teams": [],
		"nfl_rosters": {},
		"colleges": [],
		"college_rosters": {},
		"hs_schools": [],
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

static func _generate_stats_for_position(position: String, rating: float) -> Dictionary:
	var position_hash := position.hash()
	var variance_seed := position_hash % 100
	var variance := (variance_seed % 11) - 5

	var base_stats := {
		"speed": rating + variance,
		"strength": rating + variance,
		"awareness": rating + variance,
		"stamina": rating
	}

	match position:
		"QB":
			base_stats["accuracy"] = rating + variance
			base_stats["decision"] = rating + variance
		"RB", "WR", "TE":
			base_stats["catching"] = rating + variance
			base_stats["route_running"] = rating + variance
		"OL":
			base_stats["pass_blocking"] = rating + variance
			base_stats["run_blocking"] = rating + variance
		"DL", "LB":
			base_stats["pass_rush"] = rating + variance
			base_stats["run_defense"] = rating + variance
		"CB", "S":
			base_stats["coverage"] = rating + variance
			base_stats["tackling"] = rating + variance

	return base_stats


static func _generate_potential_for_rating(stats: Dictionary, rating: float) -> Dictionary:
	var potential: Dictionary = {}
	var growth_room: float = clamp(100.0 - rating, 5.0, 15.0)

	for stat_name in stats.keys():
		var current_value: float = float(stats[stat_name])
		potential[stat_name] = min(100.0, current_value + growth_room)

	return potential


static func _year_to_status(year: int) -> String:
	match year:
		1: return "freshman"
		2: return "sophomore"
		3: return "junior"
		4: return "senior"
		_: return "senior"


static func _type_to_string(type: int) -> String:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "string"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "dictionary"
		_: return "unknown[%d]" % type
