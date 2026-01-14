extends RefCounted
class_name TestHelpers

var failures: Array = []

# ============================================================================
# BASIC ASSERTIONS
# ============================================================================

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func assert_ne(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		failures.append("%s (unexpected %s)" % [message, str(actual)])

## Alias for assert_true - some tests use this name
func assert_false(condition: bool, message: String) -> void:
	if condition:
		failures.append(message)

## Alias for assert_eq - some tests use this name
func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	assert_eq(actual, expected, message)

## Alias for assert_ne - some tests use this name
func assert_not_equal(actual: Variant, expected: Variant, message: String) -> void:
	assert_ne(actual, expected, message)

func assert_approx(actual: float, expected: float, epsilon: float, message: String) -> void:
	if abs(actual - expected) > epsilon:
		failures.append("%s (expected %.4f±%.4f, got %.4f)" % [message, expected, epsilon, actual])

func assert_between(actual: float, lo: float, hi: float, message: String) -> void:
	if actual < lo or actual > hi:
		failures.append("%s (expected between %.4f and %.4f, got %.4f)" % [message, lo, hi, actual])

func assert_gt(actual: Variant, threshold: Variant, message: String) -> void:
	var actual_num := float(actual) if actual is float or actual is int else 0.0
	var threshold_num := float(threshold) if threshold is float or threshold is int else 0.0
	if not (actual_num > threshold_num):
		failures.append("%s (expected > %s, got %s)" % [message, str(threshold), str(actual)])

func assert_gte(actual: Variant, threshold: Variant, message: String) -> void:
	var actual_num := float(actual) if actual is float or actual is int else 0.0
	var threshold_num := float(threshold) if threshold is float or threshold is int else 0.0
	if not (actual_num >= threshold_num):
		failures.append("%s (expected >= %s, got %s)" % [message, str(threshold), str(actual)])

func assert_lt(actual: Variant, threshold: Variant, message: String) -> void:
	var actual_num := float(actual) if actual is float or actual is int else 0.0
	var threshold_num := float(threshold) if threshold is float or threshold is int else 0.0
	if not (actual_num < threshold_num):
		failures.append("%s (expected < %s, got %s)" % [message, str(threshold), str(actual)])

func assert_lte(actual: Variant, threshold: Variant, message: String) -> void:
	var actual_num := float(actual) if actual is float or actual is int else 0.0
	var threshold_num := float(threshold) if threshold is float or threshold is int else 0.0
	if not (actual_num <= threshold_num):
		failures.append("%s (expected <= %s, got %s)" % [message, str(threshold), str(actual)])

# ============================================================================
# DETERMINISM TESTING
# ============================================================================

## Verify a function is deterministic with a given seed.
##
## This helper consolidates the common pattern of running a function twice with the same
## seed and verifying the results are identical. It eliminates ~200 LOC of duplication
## across 37+ test files.
##
## Usage:
##   assert_deterministic(
##       func(r): PlayerLifecycle.advance_one_year(players, cfg, r),
##       12345,
##       "PlayerLifecycle.advance_one_year is deterministic"
##   )
##
## RNG Consumption Pattern:
##   - Creates two independent RNG instances with the same seed
##   - Passes each to the callable exactly once
##   - Expects the callable to consume RNG deterministically
##
## @param callable: Function that accepts an RNG as its last parameter and returns a result
## @param seed: Integer seed for deterministic RNG initialization
## @param message: Description of what is being tested
func assert_deterministic(callable: Callable, seed: int, message: String) -> void:
	var rng1 := create_seeded_rng(seed)
	var result1 = callable.call(rng1)

	var rng2 := create_seeded_rng(seed)
	var result2 = callable.call(rng2)

	# Use JSON serialization for deep equality comparison
	var json1 := JSON.stringify(result1)
	var json2 := JSON.stringify(result2)

	assert_eq(json1, json2, "Determinism: " + message)

## Create a seeded RNG instance.
##
## This standardizes RNG creation across all tests, ensuring consistent seed initialization.
## Always use this instead of creating RandomNumberGenerator instances manually.
##
## RNG Lifecycle:
##   - Each call creates a fresh, independent RNG instance
##   - The instance is seeded with the provided value
##   - No global state is modified
##
## @param seed: Integer seed for deterministic RNG initialization
## @return: Seeded RandomNumberGenerator instance ready for use
func create_seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng

# ============================================================================
# SCHEMA VALIDATION
# ============================================================================

## Assert a dictionary has all required fields.
##
## Validates that an object (typically a player, team, or game state dictionary)
## contains all expected fields. This catches API contract violations early.
##
## Usage:
##   assert_schema(player, ["player_id", "name", "age", "position"], "player structure")
##
## @param obj: Dictionary to validate
## @param required_fields: Array of field names (strings) that must be present
## @param message: Description of what structure is being validated
func assert_schema(obj: Dictionary, required_fields: Array, message: String) -> void:
	for field in required_fields:
		assert_true(obj.has(field), "%s: missing field '%s'" % [message, field])

## Assert a dictionary has fields with specific types.
##
## Validates both field presence and type correctness. More strict than assert_schema.
##
## Usage:
##   assert_schema_typed(player, {
##       "player_id": TYPE_STRING,
##       "age": TYPE_INT,
##       "stats": TYPE_DICTIONARY
##   }, "player structure with types")
##
## @param obj: Dictionary to validate
## @param schema: Dictionary mapping field names to expected Godot TYPE_* constants
## @param message: Description of what structure is being validated
func assert_schema_typed(obj: Dictionary, schema: Dictionary, message: String) -> void:
	for field_name in schema.keys():
		var expected_type = schema[field_name]
		assert_true(obj.has(field_name),
			"%s: missing field '%s'" % [message, field_name])

		if obj.has(field_name):
			var actual_value = obj[field_name]
			var actual_type = typeof(actual_value)
			assert_true(actual_type == expected_type,
				"%s: field '%s' has wrong type (expected %s, got %s)" %
				[message, field_name, _type_to_string(expected_type), _type_to_string(actual_type)])

# ============================================================================
# PERFORMANCE ASSERTIONS
# ============================================================================

## Assert an operation completes within a time limit.
##
## Converts informational performance prints into actual test assertions. This prevents
## silent performance regressions from entering the codebase.
##
## Usage:
##   assert_max_time(func(): pipeline.run_heavy_operation(), 5000.0,
##       "Recruiting pipeline completes within 5s")
##
## @param callable: Function to measure (should take no parameters)
## @param max_ms: Maximum allowed execution time in milliseconds
## @param message: Description of the performance requirement
func assert_max_time(callable: Callable, max_ms: float, message: String) -> void:
	var start_usec := Time.get_ticks_usec()
	callable.call()
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var elapsed_ms := elapsed_usec / 1000.0

	assert_true(elapsed_ms <= max_ms,
		"%s (took %.2fms, max %.2fms)" % [message, elapsed_ms, max_ms])

# ============================================================================
# TEST DATA CREATION
# ============================================================================

## Create a test player with sensible defaults.
##
## This consolidates 15+ custom _create_test_player() implementations across the test suite.
## All parameters are optional with reasonable defaults.
##
## Usage:
##   var qb = create_test_player("QB001", "QB", 18, 75.0)
##   var senior_rb = create_test_player("RB001", "RB", 21, 80.0, 4)
##
## @param player_id: Unique identifier (default: "TEST001")
## @param position: Player position (default: "QB")
## @param age: Player age in years (default: 18)
## @param rating: Overall rating 0-100 (default: 75.0)
## @param college_year: College year 1-4 (default: 1)
## @return: Dictionary representing a valid player for testing
func create_test_player(
	player_id: String = "TEST001",
	position: String = "QB",
	age: int = 18,
	rating: float = 75.0,
	college_year: int = 1
) -> Dictionary:
	# Generate position-appropriate stats based on rating
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
## Provides a baseline world state structure that satisfies API contracts without
## requiring full world generation. Useful for testing individual components in isolation.
##
## Usage:
##   var world = create_minimal_world_state(2025)
##   world["nfl_rosters"]["KC"] = {"players": [...]}
##
## @param year: Current simulation year (default: 2025)
## @return: Dictionary with minimal world state structure
func create_minimal_world_state(year: int = 2025) -> Dictionary:
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

## Generate stats dictionary for a given position and rating.
##
## Creates realistic stat distributions based on position and overall rating.
## Values vary slightly around the rating to simulate attribute variance.
##
## RNG Note: This uses a deterministic pseudo-random approach (hash-based) rather
## than consuming from the test's RNG, since this is test data setup, not simulation.
##
## @param position: Player position (QB, RB, WR, etc.)
## @param rating: Base rating 0-100
## @return: Dictionary of stat name -> value
func _generate_stats_for_position(position: String, rating: float) -> Dictionary:
	# Use position hash for deterministic variance without consuming test RNG
	var position_hash := position.hash()
	var variance_seed := position_hash % 100
	var variance := (variance_seed % 11) - 5  # Range: -5 to +5

	# Position-agnostic base stats
	var base_stats := {
		"speed": rating + variance,
		"strength": rating + variance,
		"awareness": rating + variance,
		"stamina": rating
	}

	# Add position-specific stats
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

## Generate potential dictionary based on current stats and rating.
##
## Potential is typically 5-15 points higher than current stats, representing
## the player's ceiling with development.
##
## @param stats: Current stats dictionary
## @param rating: Base rating (used to determine growth ceiling)
## @return: Dictionary of stat name -> potential value
func _generate_potential_for_rating(stats: Dictionary, rating: float) -> Dictionary:
	var potential: Dictionary = {}
	var growth_room: float = clamp(100.0 - rating, 5.0, 15.0)  # Higher rated players have less room

	for stat_name in stats.keys():
		var current_value: float = float(stats[stat_name])
		potential[stat_name] = min(100.0, current_value + growth_room)

	return potential

## Convert college year number to eligibility status string.
##
## @param year: College year (1-4)
## @return: Status string (freshman, sophomore, junior, senior)
func _year_to_status(year: int) -> String:
	match year:
		1: return "freshman"
		2: return "sophomore"
		3: return "junior"
		4: return "senior"
		_: return "senior"

## Convert Godot TYPE_* constant to readable string.
##
## @param type: Godot TYPE_* constant
## @return: Human-readable type name
func _type_to_string(type: int) -> String:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "string"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "dictionary"
		_: return "unknown[%d]" % type
