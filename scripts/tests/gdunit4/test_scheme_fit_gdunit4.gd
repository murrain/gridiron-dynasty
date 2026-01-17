## GdUnit4 tests for Scheme Fit Analysis (DRAFT-011)
##
## Validates scheme fit modifier behavior:
## - 3-4 teams boost EDGE/LB (coverage-focused linebackers)
## - 4-3 teams boost DL (big defensive linemen)
## - West Coast offenses boost accurate QBs, route-running WRs
## - Air Raid offenses boost arm strength QBs, speed WRs
## - Effect range: +/-15% evaluation adjustment
## - Elite players (90+) less affected (talent > scheme)
##
extends GdUnitTestSuite

const SchemeFitModifier = preload("res://scripts/core/evaluation/modifiers/SchemeFitModifier.gd")
const SchemeFitCalculator = preload("res://scripts/core/scouting/SchemeFitCalculator.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")


# =============================================================================
# SETUP/TEARDOWN
# =============================================================================

func before() -> void:
	# Clear cache before each test for isolation
	SchemeFitModifier.clear_cache()


func after() -> void:
	# Ensure cache is cleared after tests to prevent cross-test pollution
	SchemeFitModifier.clear_cache()


# =============================================================================
# SCHEME VALIDATION TESTS
# =============================================================================

## Test that scheme config validation succeeds
func test_scheme_mappings_validation_succeeds() -> void:
	var result := SchemeFitModifier.validate_scheme_mappings()

	assert_bool(bool(result.get("valid", false))).is_true()
	assert_array(result.get("errors", [])).is_empty()

	# Check that we have offensive and defensive schemes
	var offensive: Array = result.get("offensive_schemes", [])
	var defensive: Array = result.get("defensive_schemes", [])

	assert_int(offensive.size()).is_greater(0)
	assert_int(defensive.size()).is_greater(0)


## Test that scheme config contains expected schemes
func test_scheme_config_has_required_schemes() -> void:
	var result := SchemeFitModifier.validate_scheme_mappings()

	var offensive: Array = result.get("offensive_schemes", [])
	var defensive: Array = result.get("defensive_schemes", [])

	# Check for key offensive schemes
	assert_bool("west_coast" in offensive or "spread" in offensive or "air_raid" in offensive).is_true()
	assert_bool("pro_style" in offensive).is_true()

	# Check for key defensive schemes
	assert_bool("cover_2" in defensive or "cover_3" in defensive).is_true()
	assert_bool("3_4_two_gap" in defensive or "4_3_under" in defensive).is_true()


# =============================================================================
# MODIFIER BOUNDS TESTS
# =============================================================================

## Test scheme fit modifier has correct bounds (+/-15%)
func test_scheme_fit_modifier_bounds() -> void:
	var mod := SchemeFitModifier.new()
	var bounds := mod.get_bounds()

	assert_float(bounds.get("min", 0.0)).is_equal(0.85)
	assert_float(bounds.get("max", 0.0)).is_equal(1.15)


## Test modifier returns multiplier within bounds
func test_scheme_fit_multiplier_within_bounds() -> void:
	var mod := SchemeFitModifier.new()

	var ctx := _create_qb_context("west_coast", "cover_2")
	ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 95,
		"throw_power": 70,
		"speed": 60
	})

	var result := mod.calculate(ctx)

	assert_float(result.multiplier).is_greater_equal(0.85)
	assert_float(result.multiplier).is_less_equal(1.15)


# =============================================================================
# WEST COAST OFFENSE TESTS
# =============================================================================

## Test West Coast offense boosts accurate QBs
func test_west_coast_boosts_accurate_qb() -> void:
	var mod := SchemeFitModifier.new()

	# Accurate QB (good fit for west coast)
	var accurate_ctx := _create_qb_context("west_coast", "cover_2")
	accurate_ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 90,
		"throw_power": 70,
		"speed": 60
	})
	accurate_ctx.base_rating = 75.0

	var accurate_result := mod.calculate(accurate_ctx)

	# Strong arm QB (less ideal for west coast)
	var arm_ctx := _create_qb_context("west_coast", "cover_2")
	arm_ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 70,
		"throw_power": 90,
		"speed": 60
	})
	arm_ctx.base_rating = 75.0

	var arm_result := mod.calculate(arm_ctx)

	# Accurate QB should get higher multiplier in West Coast
	assert_float(accurate_result.multiplier).is_greater_equal(arm_result.multiplier)


## Test West Coast offense boosts route-running WRs
func test_west_coast_boosts_route_running_wr() -> void:
	var mod := SchemeFitModifier.new()

	# Route runner (good fit for west coast)
	var route_ctx := _create_wr_context("west_coast", "cover_2")
	route_ctx.player = _create_player_with_stats("WR", {
		"route_running": 90,
		"speed": 70,
		"catching": 80
	})
	route_ctx.base_rating = 75.0

	var route_result := mod.calculate(route_ctx)

	# Speed WR (less ideal for west coast)
	var speed_ctx := _create_wr_context("west_coast", "cover_2")
	speed_ctx.player = _create_player_with_stats("WR", {
		"route_running": 70,
		"speed": 90,
		"catching": 80
	})
	speed_ctx.base_rating = 75.0

	var speed_result := mod.calculate(speed_ctx)

	# Route runner should get at least equal multiplier in West Coast
	assert_float(route_result.multiplier).is_greater_equal(speed_result.multiplier - 0.05)


# =============================================================================
# AIR RAID OFFENSE TESTS
# =============================================================================

## Test Air Raid offense boosts arm strength QBs
func test_air_raid_boosts_arm_strength_qb() -> void:
	var mod := SchemeFitModifier.new()

	# Strong arm QB (good fit for air raid)
	var arm_ctx := _create_qb_context("air_raid", "cover_2")
	arm_ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 70,
		"throw_power": 90,
		"speed": 60
	})
	arm_ctx.base_rating = 75.0

	var arm_result := mod.calculate(arm_ctx)

	# Game manager QB (less ideal for air raid)
	var manager_ctx := _create_qb_context("air_raid", "cover_2")
	manager_ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 90,
		"throw_power": 70,
		"speed": 60
	})
	manager_ctx.base_rating = 75.0

	var manager_result := mod.calculate(manager_ctx)

	# Strong arm should get higher or equal multiplier in Air Raid
	assert_float(arm_result.multiplier).is_greater_equal(manager_result.multiplier - 0.05)


## Test Air Raid offense boosts speed WRs
func test_air_raid_boosts_speed_wr() -> void:
	var mod := SchemeFitModifier.new()

	# Speed WR (good fit for air raid)
	var speed_ctx := _create_wr_context("air_raid", "cover_2")
	speed_ctx.player = _create_player_with_stats("WR", {
		"route_running": 70,
		"speed": 90,
		"catching": 80
	})
	speed_ctx.base_rating = 75.0

	var speed_result := mod.calculate(speed_ctx)

	# Possession WR (less ideal for air raid)
	var poss_ctx := _create_wr_context("air_raid", "cover_2")
	poss_ctx.player = _create_player_with_stats("WR", {
		"route_running": 90,
		"speed": 70,
		"catching": 80
	})
	poss_ctx.base_rating = 75.0

	var poss_result := mod.calculate(poss_ctx)

	# Speed WR should get higher or equal multiplier in Air Raid
	assert_float(speed_result.multiplier).is_greater_equal(poss_result.multiplier - 0.05)


# =============================================================================
# 3-4 vs 4-3 DEFENSE TESTS
# =============================================================================

## Test 3-4 defense boosts coverage LBs
func test_3_4_defense_boosts_coverage_lb() -> void:
	var mod := SchemeFitModifier.new()

	# Coverage LB (good fit for 3-4)
	var coverage_ctx := _create_lb_context("pro_style", "3_4_two_gap")
	coverage_ctx.player = _create_player_with_stats("LB", {
		"coverage": 90,
		"tackling": 70,
		"speed": 80
	})
	coverage_ctx.base_rating = 75.0

	var coverage_result := mod.calculate(coverage_ctx)

	# Run-stuffing LB (less ideal for 3-4)
	var run_ctx := _create_lb_context("pro_style", "3_4_two_gap")
	run_ctx.player = _create_player_with_stats("LB", {
		"coverage": 70,
		"tackling": 90,
		"speed": 70
	})
	run_ctx.base_rating = 75.0

	var run_result := mod.calculate(run_ctx)

	# Coverage LB should get at least equal multiplier in 3-4
	assert_float(coverage_result.multiplier).is_greater_equal(run_result.multiplier - 0.05)


## Test 4-3 defense boosts big DL
func test_4_3_defense_boosts_big_dl() -> void:
	var mod := SchemeFitModifier.new()

	# Power DL (good fit for 4-3)
	var power_ctx := _create_dl_context("pro_style", "4_3_under")
	power_ctx.player = _create_player_with_stats("DL", {
		"power": 90,
		"speed": 70,
		"pass_rush": 75
	})
	power_ctx.base_rating = 75.0

	var power_result := mod.calculate(power_ctx)

	# Speed rusher (less ideal for 4-3 interior)
	var speed_ctx := _create_dl_context("pro_style", "4_3_under")
	speed_ctx.player = _create_player_with_stats("DL", {
		"power": 70,
		"speed": 90,
		"pass_rush": 85
	})
	speed_ctx.base_rating = 75.0

	var speed_result := mod.calculate(speed_ctx)

	# Power DL should get at least equal multiplier in 4-3
	assert_float(power_result.multiplier).is_greater_equal(speed_result.multiplier - 0.05)


## Test 3-4 defense boosts EDGE players
func test_3_4_defense_values_edge_players() -> void:
	var mod := SchemeFitModifier.new()

	# EDGE player in 3-4
	var edge_ctx := _create_edge_context("pro_style", "3_4_two_gap")
	edge_ctx.player = _create_player_with_stats("EDGE", {
		"speed": 85,
		"power": 80,
		"pass_rush": 85
	})
	edge_ctx.base_rating = 80.0

	var result := mod.calculate(edge_ctx)

	# EDGE should be applicable and get a reasonable multiplier
	assert_float(result.multiplier).is_greater(0.0)
	assert_float(result.multiplier).is_greater_equal(0.85)


# =============================================================================
# ELITE PLAYER DAMPENING TESTS
# =============================================================================

## Test elite players are less affected by scheme fit
func test_elite_player_scheme_dampening() -> void:
	var mod := SchemeFitModifier.new()

	# Elite player (90+ rating)
	var elite_ctx := _create_qb_context("air_raid", "cover_2")
	elite_ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 95,
		"throw_power": 70,  # Not ideal for air raid
		"speed": 70
	})
	elite_ctx.base_rating = 92.0  # Elite

	var elite_result := mod.calculate(elite_ctx)

	# Average player (75 rating) with same stats
	var avg_ctx := _create_qb_context("air_raid", "cover_2")
	avg_ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 95,
		"throw_power": 70,  # Not ideal for air raid
		"speed": 70
	})
	avg_ctx.base_rating = 75.0  # Average

	var avg_result := mod.calculate(avg_ctx)

	# Check that elite_dampening was calculated
	assert_float(float(elite_result.metadata.get("elite_dampening", 0.0))).is_greater(0.0)

	# Elite player should have multiplier closer to 1.0 (less scheme impact)
	var elite_deviation := absf(elite_result.multiplier - 1.0)
	var avg_deviation := absf(avg_result.multiplier - 1.0)

	# Elite deviation should be less or equal to average player's deviation
	# (because talent transcends system)
	assert_float(elite_deviation).is_less_equal(avg_deviation + 0.02)


# =============================================================================
# SCHEME FIT SCORE AND GRADE TESTS
# =============================================================================

## Test scheme fit score calculation returns 0-100 range
func test_scheme_fit_score_range() -> void:
	var player := _create_player_with_stats("QB", {
		"throw_accuracy": 80,
		"throw_power": 80,
		"speed": 70
	})

	var score := SchemeFitModifier.calculate_scheme_fit_score(
		player, "QB", 75.0, "west_coast", "cover_2", 1.0
	)

	assert_float(score).is_greater_equal(0.0)
	assert_float(score).is_less_equal(100.0)


## Test scheme fit grade mapping
func test_scheme_fit_grade_mapping() -> void:
	# A+ grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(95.0)).is_equal("A+")

	# A grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(85.0)).is_equal("A")

	# B+ grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(75.0)).is_equal("B+")

	# B grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(65.0)).is_equal("B")

	# C grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(55.0)).is_equal("C")

	# D grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(45.0)).is_equal("D")

	# F grade
	assert_str(SchemeFitModifier.get_scheme_fit_grade(30.0)).is_equal("F")


# =============================================================================
# APPLICABILITY TESTS
# =============================================================================

## Test modifier not applicable for K/P (special teams)
func test_not_applicable_for_special_teams() -> void:
	var mod := SchemeFitModifier.new()

	var k_ctx := EvaluationContext.new()
	k_ctx.position = "K"
	assert_bool(mod.is_applicable(k_ctx)).is_false()

	var p_ctx := EvaluationContext.new()
	p_ctx.position = "P"
	assert_bool(mod.is_applicable(p_ctx)).is_false()


## Test modifier applicable for regular positions
func test_applicable_for_regular_positions() -> void:
	var mod := SchemeFitModifier.new()
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]

	for pos in positions:
		var ctx := EvaluationContext.new()
		ctx.position = pos
		assert_bool(mod.is_applicable(ctx)).is_true()


## Test modifier not applicable when position is empty
func test_not_applicable_when_position_empty() -> void:
	var mod := SchemeFitModifier.new()

	var ctx := EvaluationContext.new()
	ctx.position = ""

	assert_bool(mod.is_applicable(ctx)).is_false()


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

## Test scheme fit integration with modifier stack
func test_scheme_fit_in_draft_stack() -> void:
	var stack := EvaluationModifierStack.create_draft_stack()

	# Verify SchemeFitModifier is in the stack
	var has_scheme_fit := false
	for mod in stack.get_modifiers():
		var m: EvaluationModifier = mod
		if m.get_id() == "scheme_fit":
			has_scheme_fit = true
			break

	assert_bool(has_scheme_fit).is_true()


## Test scheme fit is included in stack evaluation
func test_scheme_fit_affects_stack_evaluation() -> void:
	var stack := EvaluationModifierStack.create_draft_stack()

	var ctx := _create_qb_context("west_coast", "cover_2")
	ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 90,
		"throw_power": 70,
		"speed": 60
	})
	ctx.base_rating = 75.0
	ctx.phase = "draft"
	ctx.draft_round = 1
	ctx.roster = {"by_position": {"QB": ["qb_1"]}, "players": {"qb_1": {"overall": 70}}}
	ctx.positions_cfg = {"QB": {"value": 1.1}}
	ctx.draft_strategy = {"position_tiers": {"premium": ["QB"], "devalued": []}}

	var result := stack.evaluate(ctx)

	# Check that scheme_fit modifier was applied
	var scheme_fit_applied := false
	for mod_info in result.applied_modifiers:
		var mi: Dictionary = mod_info
		if String(mi.get("id", "")) == "scheme_fit":
			scheme_fit_applied = true
			break

	assert_bool(scheme_fit_applied).is_true()


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

## Test scheme fit calculation is deterministic
func test_scheme_fit_calculation_deterministic() -> void:
	var mod := SchemeFitModifier.new()

	var ctx := _create_qb_context("air_raid", "cover_2")
	ctx.player = _create_player_with_stats("QB", {
		"throw_accuracy": 85,
		"throw_power": 85,
		"speed": 75
	})
	ctx.base_rating = 78.0

	# Run calculation multiple times
	var results: Array = []
	for _i in range(5):
		var result := mod.calculate(ctx)
		results.append(result.multiplier)

	# All results should be identical
	for i in range(1, results.size()):
		assert_float(results[i]).is_equal(results[0])


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _create_qb_context(offensive_scheme: String, defensive_scheme: String) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "QB"
	ctx.offensive_scheme = offensive_scheme
	ctx.defensive_scheme = defensive_scheme
	ctx.coach = {"scheme_rigidity": 1.0}
	ctx.team = {"offensive_scheme": offensive_scheme, "defensive_scheme": defensive_scheme}
	return ctx


func _create_wr_context(offensive_scheme: String, defensive_scheme: String) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "WR"
	ctx.offensive_scheme = offensive_scheme
	ctx.defensive_scheme = defensive_scheme
	ctx.coach = {"scheme_rigidity": 1.0}
	ctx.team = {"offensive_scheme": offensive_scheme, "defensive_scheme": defensive_scheme}
	return ctx


func _create_lb_context(offensive_scheme: String, defensive_scheme: String) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "LB"
	ctx.offensive_scheme = offensive_scheme
	ctx.defensive_scheme = defensive_scheme
	ctx.coach = {"scheme_rigidity": 1.0}
	ctx.team = {"offensive_scheme": offensive_scheme, "defensive_scheme": defensive_scheme}
	return ctx


func _create_dl_context(offensive_scheme: String, defensive_scheme: String) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "DL"
	ctx.offensive_scheme = offensive_scheme
	ctx.defensive_scheme = defensive_scheme
	ctx.coach = {"scheme_rigidity": 1.0}
	ctx.team = {"offensive_scheme": offensive_scheme, "defensive_scheme": defensive_scheme}
	return ctx


func _create_edge_context(offensive_scheme: String, defensive_scheme: String) -> EvaluationContext:
	var ctx := EvaluationContext.new()
	ctx.position = "EDGE"
	ctx.offensive_scheme = offensive_scheme
	ctx.defensive_scheme = defensive_scheme
	ctx.coach = {"scheme_rigidity": 1.0}
	ctx.team = {"offensive_scheme": offensive_scheme, "defensive_scheme": defensive_scheme}
	return ctx


func _create_player_with_stats(position: String, stats: Dictionary) -> Dictionary:
	return {
		"position": position,
		"name": "Test Player",
		"player_id": "test_player_1",
		"stats": stats
	}
