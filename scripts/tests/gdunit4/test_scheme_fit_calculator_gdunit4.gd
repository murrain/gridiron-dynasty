extends GdUnitTestSuite
class_name TestSchemeFitCalculatorGdUnit4

## Tests for SchemeFitCalculator - Scheme fit scoring system
##
## Validates:
## - Scheme-weighted rating calculations
## - Elite player dampening
## - Scheme type detection (offensive vs defensive)
## - Team-based calculations
## - Determinism (no RNG)

const SchemeFitCalculator = preload("res://scripts/core/scouting/SchemeFitCalculator.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# SCHEME TYPE DETECTION TESTS
# =============================================================================

func test_get_scheme_type_for_offensive_positions() -> void:
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]

	for pos in offensive_positions:
		var scheme_type := SchemeFitCalculator.get_scheme_type_for_position(pos)
		assert_string(scheme_type).override_failure_message(
			"Position %s should map to offensive_schemes" % pos
		).is_equal("offensive_schemes")


func test_get_scheme_type_for_defensive_positions() -> void:
	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	for pos in defensive_positions:
		var scheme_type := SchemeFitCalculator.get_scheme_type_for_position(pos)
		assert_string(scheme_type).override_failure_message(
			"Position %s should map to defensive_schemes" % pos
		).is_equal("defensive_schemes")


func test_get_scheme_type_for_special_teams_returns_empty() -> void:
	var special_teams := ["K", "P"]

	for pos in special_teams:
		var scheme_type := SchemeFitCalculator.get_scheme_type_for_position(pos)
		assert_string(scheme_type).override_failure_message(
			"Special teams position %s should return empty string" % pos
		).is_empty()


# =============================================================================
# SCHEME RATING CALCULATION TESTS
# =============================================================================

func test_calculate_scheme_rating_with_neutral_weights() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	# All weights = 1.0 (neutral)
	var scheme_weights := {
		"speed": 1.0,
		"strength": 1.0,
		"awareness": 1.0
	}

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# Weighted average: (80*1 + 70*1 + 75*1) / 3 = 75
	assert_float(result).is_equal_approx(75.0, 0.1)


func test_calculate_scheme_rating_with_boosted_weights() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	# Boost speed weight
	var scheme_weights := {
		"speed": 1.3,     # Boosted
		"strength": 1.0,
		"awareness": 1.0
	}

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# Weighted average: (80*1.3 + 70*1 + 75*1) / 3.3 = 249 / 3.3 = 75.45
	assert_float(result).is_equal_approx(75.45, 0.1)


func test_calculate_scheme_rating_with_penalized_weights() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	# Penalize speed weight
	var scheme_weights := {
		"speed": 0.7,     # Penalized
		"strength": 1.0,
		"awareness": 1.0
	}

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# Weighted average: (80*0.7 + 70*1 + 75*1) / 2.7 = 201 / 2.7 = 74.44
	assert_float(result).is_equal_approx(74.44, 0.1)


func test_calculate_scheme_rating_unmapped_stats_default_to_neutral() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"unknown_stat": 90.0  # Not in scheme weights
		}
	}

	var scheme_weights := {
		"speed": 1.2,
		"strength": 0.8
		# unknown_stat not mapped
	}

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# (80*1.2 + 70*0.8 + 90*1.0) / 3.0 = (96 + 56 + 90) / 3 = 242 / 3 = 80.67
	assert_float(result).is_equal_approx(80.67, 0.1)


func test_calculate_scheme_rating_empty_stats_returns_neutral() -> void:
	var player := {
		"stats": {}
	}

	var scheme_weights := {
		"speed": 1.2,
		"strength": 0.8
	}

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# No stats available, should return neutral value
	assert_float(result).is_equal(50.0)


# =============================================================================
# ELITE DAMPENING TESTS
# =============================================================================

func test_calculate_elite_dampening_for_elite_players() -> void:
	var elite_ratings := [90.0, 92.0, 95.0, 99.0]

	for rating in elite_ratings:
		var dampening := SchemeFitCalculator.calculate_elite_dampening(rating)
		# Elite players (90+) should have dampening of 0.2 (20% scheme impact)
		assert_float(dampening).override_failure_message(
			"Elite player (%.1f OVR) should have 0.2 dampening" % rating
		).is_equal(0.2)


func test_calculate_elite_dampening_for_average_players() -> void:
	var average_rating := 70.0

	var dampening := SchemeFitCalculator.calculate_elite_dampening(average_rating)

	# Average players should have full dampening (1.0)
	assert_float(dampening).is_equal(1.0)


func test_calculate_elite_dampening_for_below_average_players() -> void:
	var below_average_ratings := [60.0, 50.0, 40.0]

	for rating in below_average_ratings:
		var dampening := SchemeFitCalculator.calculate_elite_dampening(rating)
		# Below average should have full dampening (1.0)
		assert_float(dampening).is_equal(1.0)


func test_calculate_elite_dampening_interpolates_for_good_players() -> void:
	# Good players (80-90) should have interpolated dampening
	var rating_80 := SchemeFitCalculator.calculate_elite_dampening(80.0)
	var rating_85 := SchemeFitCalculator.calculate_elite_dampening(85.0)
	var rating_89 := SchemeFitCalculator.calculate_elite_dampening(89.0)

	# Should interpolate: 80->0.5, 85->0.35, 90->0.2
	assert_float(rating_80).is_equal_approx(0.5, 0.01)
	assert_float(rating_85).is_equal_approx(0.35, 0.01)
	assert_float(rating_89).is_greater(0.2)
	assert_float(rating_89).is_less(0.5)


func test_calculate_elite_dampening_interpolates_for_solid_players() -> void:
	# Solid players (70-80) should have interpolated dampening
	var rating_70 := SchemeFitCalculator.calculate_elite_dampening(70.0)
	var rating_75 := SchemeFitCalculator.calculate_elite_dampening(75.0)
	var rating_79 := SchemeFitCalculator.calculate_elite_dampening(79.0)

	# Should interpolate: 70->1.0, 75->0.75, 80->0.5
	assert_float(rating_70).is_equal_approx(1.0, 0.01)
	assert_float(rating_75).is_equal_approx(0.75, 0.01)
	assert_float(rating_79).is_greater(0.5)
	assert_float(rating_79).is_less(1.0)


# =============================================================================
# SCHEME-ADJUSTED RATING TESTS
# =============================================================================

func test_calculate_scheme_adjusted_rating_with_good_fit() -> void:
	var player := {
		"stats": {
			"speed": 90.0,      # High speed
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var scheme_weights := {
		"speed": 1.3,      # Scheme values speed
		"strength": 1.0,
		"awareness": 1.0
	}

	var base_rating := 78.0
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, coach_rigidity
	)

	# Good fit (high speed valued by scheme) should boost rating
	assert_float(result).is_greater(base_rating)


func test_calculate_scheme_adjusted_rating_with_poor_fit() -> void:
	var player := {
		"stats": {
			"speed": 60.0,      # Low speed
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var scheme_weights := {
		"speed": 1.3,      # Scheme values speed
		"strength": 1.0,
		"awareness": 1.0
	}

	var base_rating := 68.0
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, coach_rigidity
	)

	# Poor fit (low speed, scheme values it) should lower or maintain rating
	assert_float(result).is_less_equal(base_rating + 1.0)


func test_calculate_scheme_adjusted_rating_elite_player_less_affected() -> void:
	var elite_player := {
		"stats": {
			"speed": 60.0,      # Low speed (poor fit)
			"strength": 95.0,
			"awareness": 90.0
		}
	}

	var average_player := {
		"stats": {
			"speed": 60.0,      # Same low speed
			"strength": 70.0,
			"awareness": 65.0
		}
	}

	var scheme_weights := {
		"speed": 1.3,      # Scheme highly values speed
		"strength": 1.0,
		"awareness": 1.0
	}

	var elite_base := 92.0
	var average_base := 65.0
	var coach_rigidity := 1.0

	var elite_result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		elite_player, "RB", scheme_weights, elite_base, coach_rigidity
	)

	var average_result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		average_player, "RB", scheme_weights, average_base, coach_rigidity
	)

	# Elite player should be less penalized (closer to base) than average player
	var elite_penalty := (elite_base - elite_result) / elite_base
	var average_penalty := (average_base - average_result) / average_base

	assert_float(elite_penalty).is_less_equal(average_penalty + 0.05)


func test_calculate_scheme_adjusted_rating_coach_rigidity_amplifies_effect() -> void:
	var player := {
		"stats": {
			"speed": 90.0,      # High speed
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var scheme_weights := {
		"speed": 1.3,      # Scheme values speed
		"strength": 1.0,
		"awareness": 1.0
	}

	var base_rating := 78.0

	# Flexible coach (low rigidity)
	var flexible_result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, 0.5
	)

	# Rigid coach (high rigidity)
	var rigid_result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, 1.5
	)

	# Rigid coach should have stronger effect (more boost for good fit)
	var flexible_boost := flexible_result - base_rating
	var rigid_boost := rigid_result - base_rating

	assert_float(rigid_boost).is_greater_equal(flexible_boost)


# =============================================================================
# TEAM-BASED CALCULATION TESTS (Integration)
# =============================================================================

func test_calculate_for_team_offensive_position() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 80.0)
	player["stats"]["speed"] = 75.0
	player["stats"]["awareness"] = 85.0

	var base_rating := 80.0
	var offensive_scheme := "air_raid"
	var defensive_scheme := "cover_2"
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_for_team(
		player, "QB", base_rating, offensive_scheme, defensive_scheme, coach_rigidity
	)

	# Should use offensive scheme for QB
	# Result should be a valid rating
	assert_float(result).is_greater(0.0)
	assert_float(result).is_less_equal(100.0)


func test_calculate_for_team_defensive_position() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "CB", 21, 75.0)
	player["stats"]["speed"] = 85.0
	player["stats"]["coverage"] = 80.0

	var base_rating := 75.0
	var offensive_scheme := "west_coast"
	var defensive_scheme := "cover_3"
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_for_team(
		player, "CB", base_rating, offensive_scheme, defensive_scheme, coach_rigidity
	)

	# Should use defensive scheme for CB
	# Result should be a valid rating
	assert_float(result).is_greater(0.0)
	assert_float(result).is_less_equal(100.0)


func test_calculate_for_team_special_teams_returns_base_rating() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "K", 21, 70.0)

	var base_rating := 70.0
	var offensive_scheme := "air_raid"
	var defensive_scheme := "cover_2"
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_for_team(
		player, "K", base_rating, offensive_scheme, defensive_scheme, coach_rigidity
	)

	# Special teams should not be affected by scheme
	assert_float(result).is_equal(base_rating)


func test_calculate_for_team_unknown_position_returns_base_rating() -> void:
	var player := TestHelpersGdUnit4.create_test_player("P001", "UNKNOWN", 21, 75.0)

	var base_rating := 75.0
	var offensive_scheme := "pro_style"
	var defensive_scheme := "cover_2"
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_for_team(
		player, "UNKNOWN", base_rating, offensive_scheme, defensive_scheme, coach_rigidity
	)

	# Unknown position should return base rating
	assert_float(result).is_equal(base_rating)


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_scheme_rating_calculation_is_deterministic() -> void:
	var player := {
		"stats": {
			"speed": 82.0,
			"strength": 75.0,
			"awareness": 78.0
		}
	}

	var scheme_weights := {
		"speed": 1.2,
		"strength": 0.9,
		"awareness": 1.1
	}

	var result1 := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)
	var result2 := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	assert_float(result1).is_equal(result2)


func test_scheme_adjusted_rating_is_deterministic() -> void:
	var player := {
		"stats": {
			"speed": 85.0,
			"strength": 75.0,
			"awareness": 80.0
		}
	}

	var scheme_weights := {
		"speed": 1.3,
		"strength": 1.0,
		"awareness": 1.0
	}

	var base_rating := 80.0
	var coach_rigidity := 1.2

	var result1 := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, coach_rigidity
	)

	var result2 := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, coach_rigidity
	)

	assert_float(result1).is_equal(result2)


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_zero_base_rating_handled_gracefully() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0
		}
	}

	var scheme_weights := {
		"speed": 1.2,
		"strength": 1.0
	}

	var base_rating := 0.0
	var coach_rigidity := 1.0

	var result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, coach_rigidity
	)

	# Should not crash, should return scheme rating
	assert_float(result).is_greater_equal(0.0)


func test_empty_scheme_weights_treats_all_stats_neutral() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var scheme_weights := {}  # No weights specified

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# All stats default to 1.0 weight, so average: (80 + 70 + 75) / 3 = 75
	assert_float(result).is_equal_approx(75.0, 0.1)


func test_negative_coach_rigidity_handled_gracefully() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0
		}
	}

	var scheme_weights := {
		"speed": 1.2,
		"strength": 1.0
	}

	var base_rating := 75.0
	var coach_rigidity := -0.5  # Invalid but should not crash

	var result := SchemeFitCalculator.calculate_scheme_adjusted_rating(
		player, "RB", scheme_weights, base_rating, coach_rigidity
	)

	# Should handle gracefully and return a value
	assert_object(result).is_not_null()


func test_extreme_scheme_weights_produce_reasonable_results() -> void:
	var player := {
		"stats": {
			"speed": 80.0,
			"strength": 70.0,
			"awareness": 75.0
		}
	}

	var scheme_weights := {
		"speed": 5.0,      # Extreme boost
		"strength": 0.1,   # Severe penalty
		"awareness": 1.0
	}

	var result := SchemeFitCalculator.calculate_scheme_rating(player, "RB", scheme_weights)

	# (80*5 + 70*0.1 + 75*1) / 6.1 = (400 + 7 + 75) / 6.1 = 482 / 6.1 = 79.02
	assert_float(result).is_equal_approx(79.02, 0.5)


# =============================================================================
# MULTIPLE POSITION INTEGRATION TESTS
# =============================================================================

func test_all_positions_produce_valid_scheme_fits() -> void:
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]

	for pos in positions:
		var player := TestHelpersGdUnit4.create_test_player("P001", pos, 21, 75.0)
		var base_rating := 75.0
		var offensive_scheme := "west_coast"
		var defensive_scheme := "3_4_two_gap"
		var coach_rigidity := 1.0

		var result := SchemeFitCalculator.calculate_for_team(
			player, pos, base_rating, offensive_scheme, defensive_scheme, coach_rigidity
		)

		# All positions should produce valid results
		assert_float(result).override_failure_message(
			"Position %s should produce valid scheme fit result" % pos
		).is_greater(0.0)
		assert_float(result).is_less_equal(100.0)
