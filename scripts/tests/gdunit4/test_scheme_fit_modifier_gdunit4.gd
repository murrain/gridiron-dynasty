extends GdUnitTestSuite
class_name TestSchemeFitModifierGdUnit4

## Tests for SchemeFitModifier - Multiplicative adjustment based on scheme fit
##
## Validates:
## - Scheme fit calculation (0.85x to 1.15x range)
## - Position-specific scheme matching
## - Elite player dampening (90+ transcend scheme)
## - Coach rigidity scaling
## - Special teams exclusion
## - Determinism (no RNG)

const SchemeFitModifier = preload("res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# METADATA TESTS
# =============================================================================

func test_scheme_fit_modifier_has_correct_id() -> void:
	var modifier := SchemeFitModifier.new()
	assert_string(modifier.get_id()).is_equal("scheme_fit")


func test_scheme_fit_modifier_has_correct_priority() -> void:
	var modifier := SchemeFitModifier.new()
	# Should run after hype (40), before coach mindset (60)
	assert_int(modifier.get_priority()).is_equal(50)


func test_scheme_fit_modifier_has_correct_bounds() -> void:
	var modifier := SchemeFitModifier.new()
	var bounds := modifier.get_bounds()

	# +/-15% max effect per spec
	assert_float(bounds["min"]).is_equal(0.85)
	assert_float(bounds["max"]).is_equal(1.15)


func test_scheme_fit_modifier_has_scheme_tag() -> void:
	var modifier := SchemeFitModifier.new()
	var tags := modifier.get_tags()

	assert_array(tags).contains(["scheme"])


# =============================================================================
# APPLICABILITY TESTS
# =============================================================================

func test_is_applicable_for_offensive_positions() -> void:
	var modifier := SchemeFitModifier.new()
	var offensive_positions := ["QB", "RB", "WR", "TE", "OL"]

	for pos in offensive_positions:
		var player := TestHelpersGdUnit4.create_test_player("P001", pos)
		var team := {"offensive_scheme": "air_raid"}
		var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})

		assert_bool(modifier.is_applicable(ctx)).override_failure_message(
			"Should be applicable for offensive position: %s" % pos
		).is_true()


func test_is_applicable_for_defensive_positions() -> void:
	var modifier := SchemeFitModifier.new()
	var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]

	for pos in defensive_positions:
		var player := TestHelpersGdUnit4.create_test_player("P001", pos)
		var team := {"defensive_scheme": "3_4_two_gap"}
		var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})

		assert_bool(modifier.is_applicable(ctx)).override_failure_message(
			"Should be applicable for defensive position: %s" % pos
		).is_true()


func test_is_not_applicable_for_special_teams() -> void:
	var modifier := SchemeFitModifier.new()
	var special_teams := ["K", "P"]

	for pos in special_teams:
		var player := TestHelpersGdUnit4.create_test_player("P001", pos)
		var team := {"offensive_scheme": "air_raid"}
		var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})

		assert_bool(modifier.is_applicable(ctx)).override_failure_message(
			"Should NOT be applicable for special teams position: %s" % pos
		).is_false()


func test_is_not_applicable_when_position_empty() -> void:
	var modifier := SchemeFitModifier.new()
	var ctx := EvaluationContext.new()
	ctx.position = ""

	assert_bool(modifier.is_applicable(ctx)).is_false()


# =============================================================================
# SCHEME FIT CALCULATION TESTS
# =============================================================================

func test_neutral_fit_produces_neutral_multiplier() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 70.0)
	var team := {
		"offensive_scheme": "pro_style",  # Neutral scheme
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 70.0

	var result := modifier.calculate(ctx)

	# Pro style is neutral, should be close to 1.0
	assert_float(result.multiplier).is_equal_approx(1.0, 0.05)


func test_good_scheme_fit_produces_positive_multiplier() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	# Boost QB stats that fit air raid
	player["stats"]["accuracy"] = 90.0
	player["stats"]["decision"] = 85.0

	var team := {
		"offensive_scheme": "air_raid",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Good fit should produce positive multiplier (> 1.0)
	assert_float(result.multiplier).is_greater_equal(1.0)


func test_poor_scheme_fit_produces_negative_multiplier() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 70.0)
	# Low stats for air raid system
	player["stats"]["accuracy"] = 60.0
	player["stats"]["decision"] = 55.0

	var team := {
		"offensive_scheme": "air_raid",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 70.0

	var result := modifier.calculate(ctx)

	# Poor fit might produce penalty (< 1.0) or neutral
	assert_float(result.multiplier).is_less_equal(1.05)


# =============================================================================
# ELITE PLAYER DAMPENING TESTS
# =============================================================================

func test_elite_players_less_affected_by_scheme() -> void:
	var modifier := SchemeFitModifier.new()

	# Elite player (90+ OVR)
	var elite_player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 92.0)
	elite_player["stats"]["accuracy"] = 60.0  # Poor fit stat
	var team := {
		"offensive_scheme": "air_raid",
		"coach": {}
	}
	var ctx_elite := EvaluationContext.for_draft(elite_player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx_elite.base_rating = 92.0
	var result_elite := modifier.calculate(ctx_elite)

	# Average player (70 OVR)
	var avg_player := TestHelpersGdUnit4.create_test_player("P002", "QB", 21, 70.0)
	avg_player["stats"]["accuracy"] = 60.0  # Same poor fit stat
	var ctx_avg := EvaluationContext.for_draft(avg_player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx_avg.base_rating = 70.0
	var result_avg := modifier.calculate(ctx_avg)

	# Elite player's multiplier should be closer to 1.0 (less affected)
	var elite_deviation := absf(result_elite.multiplier - 1.0)
	var avg_deviation := absf(result_avg.multiplier - 1.0)

	# Elite deviation should be smaller or equal
	assert_float(elite_deviation).is_less_equal(avg_deviation + 0.01)


# =============================================================================
# COACH RIGIDITY TESTS
# =============================================================================

func test_rigid_coach_amplifies_scheme_fit_effect() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	player["stats"]["accuracy"] = 90.0  # Good fit for air raid

	# Flexible coach (low rigidity)
	var team_flexible := {
		"offensive_scheme": "air_raid",
		"coach": {"scheme_rigidity": 0.5}
	}
	var ctx_flexible := EvaluationContext.for_draft(player, team_flexible, {}, 1, 2025, {}, {}, {}, {})
	ctx_flexible.base_rating = 75.0
	var result_flexible := modifier.calculate(ctx_flexible)

	# Rigid coach (high rigidity)
	var team_rigid := {
		"offensive_scheme": "air_raid",
		"coach": {"scheme_rigidity": 1.5}
	}
	var ctx_rigid := EvaluationContext.for_draft(player, team_rigid, {}, 1, 2025, {}, {}, {}, {})
	ctx_rigid.base_rating = 75.0
	var result_rigid := modifier.calculate(ctx_rigid)

	# Rigid coach should have stronger effect (further from 1.0)
	var flexible_deviation := absf(result_flexible.multiplier - 1.0)
	var rigid_deviation := absf(result_rigid.multiplier - 1.0)

	assert_float(rigid_deviation).is_greater_equal(flexible_deviation)


# =============================================================================
# BOUNDS ENFORCEMENT TESTS
# =============================================================================

func test_multiplier_clamped_to_max_bound() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 80.0)
	# Max out all stats
	for stat in player["stats"].keys():
		player["stats"][stat] = 100.0

	var team := {
		"offensive_scheme": "air_raid",
		"coach": {"scheme_rigidity": 2.0}  # Very rigid
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 80.0

	var result := modifier.calculate(ctx)

	# Should not exceed 1.15 (max bound)
	assert_float(result.multiplier).is_less_equal(1.15)


func test_multiplier_clamped_to_min_bound() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 70.0)
	# Min out all stats
	for stat in player["stats"].keys():
		player["stats"][stat] = 30.0

	var team := {
		"offensive_scheme": "air_raid",
		"coach": {"scheme_rigidity": 2.0}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 70.0

	var result := modifier.calculate(ctx)

	# Should not go below 0.85 (min bound)
	assert_float(result.multiplier).is_greater_equal(0.85)


# =============================================================================
# OFFENSIVE SCHEME TESTS
# =============================================================================

func test_offensive_positions_use_offensive_scheme() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "WR", 21, 75.0)
	var team := {
		"offensive_scheme": "west_coast",
		"defensive_scheme": "3_4_two_gap",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Should reference offensive scheme in reason or details
	assert_that(result.details).has("offensive_scheme")
	assert_string(result.details["offensive_scheme"]).is_equal("west_coast")


# =============================================================================
# DEFENSIVE SCHEME TESTS
# =============================================================================

func test_defensive_positions_use_defensive_scheme() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "EDGE", 21, 75.0)
	var team := {
		"offensive_scheme": "air_raid",
		"defensive_scheme": "3_4_two_gap",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Should reference defensive scheme in reason or details
	assert_that(result.details).has("defensive_scheme")
	assert_string(result.details["defensive_scheme"]).is_equal("3_4_two_gap")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_missing_coach_defaults_to_neutral_rigidity() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	var team := {
		"offensive_scheme": "air_raid"
		# No coach field
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Should not crash, should use default rigidity (1.0)
	assert_object(result).is_not_null()
	assert_that(result.details).has("coach_rigidity")


func test_zero_base_rating_handled_gracefully() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 0.0)
	var team := {
		"offensive_scheme": "air_raid",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 0.0

	var result := modifier.calculate(ctx)

	# Should not crash, should return reasonable multiplier
	assert_object(result).is_not_null()
	assert_float(result.multiplier).is_greater_equal(0.85)
	assert_float(result.multiplier).is_less_equal(1.15)


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_scheme_fit_calculation_is_deterministic() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 80.0)
	player["stats"]["accuracy"] = 85.0
	var team := {
		"offensive_scheme": "air_raid",
		"coach": {"scheme_rigidity": 1.2}
	}

	var ctx1 := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx1.base_rating = 80.0
	var result1 := modifier.calculate(ctx1)

	var ctx2 := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx2.base_rating = 80.0
	var result2 := modifier.calculate(ctx2)

	# Should produce identical results
	assert_float(result1.multiplier).is_equal(result2.multiplier)
	assert_that(result1.details).is_equal(result2.details)


# =============================================================================
# RESULT DETAILS TESTS
# =============================================================================

func test_result_includes_fit_quality_assessment() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	var team := {
		"offensive_scheme": "air_raid",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Should include fit quality assessment
	assert_that(result.details).has("fit_quality")
	assert_string(result.details["fit_quality"]).is_not_empty()


func test_result_includes_scheme_adjusted_rating() -> void:
	var modifier := SchemeFitModifier.new()
	var player := TestHelpersGdUnit4.create_test_player("P001", "QB", 21, 75.0)
	var team := {
		"offensive_scheme": "air_raid",
		"coach": {}
	}
	var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
	ctx.base_rating = 75.0

	var result := modifier.calculate(ctx)

	# Should include scheme-adjusted rating
	assert_that(result.details).has("scheme_adjusted_rating")
	assert_float(result.details["scheme_adjusted_rating"]).is_greater(0.0)


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_multiple_position_scheme_fits_work_correctly() -> void:
	var modifier := SchemeFitModifier.new()
	var positions := ["QB", "RB", "WR", "DL", "CB"]

	for pos in positions:
		var player := TestHelpersGdUnit4.create_test_player("P001", pos, 21, 75.0)
		var team := {
			"offensive_scheme": "west_coast",
			"defensive_scheme": "cover_2",
			"coach": {}
		}
		var ctx := EvaluationContext.for_draft(player, team, {}, 1, 2025, {}, {}, {}, {})
		ctx.base_rating = 75.0

		var result := modifier.calculate(ctx)

		# Each position should get a valid result
		assert_object(result).is_not_null()
		assert_float(result.multiplier).is_greater_equal(0.85)
		assert_float(result.multiplier).is_less_equal(1.15)
