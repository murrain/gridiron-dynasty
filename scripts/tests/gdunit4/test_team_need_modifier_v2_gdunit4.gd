## GdUnit4 test suite for TeamNeedModifierV2
##
## Validates:
## 1. Need level assessment (critical, high, moderate, low, none)
## 2. Round scaling behavior (early rounds vs late rounds)
## 3. Position importance multipliers
## 4. Reach prevention floors
## 5. Determinism (no RNG usage)
## 6. Edge cases (empty rosters, overstocked positions)
extends GdUnitTestSuite

const TeamNeedModifierV2 = preload("res://scripts/core/evaluation/modifiers/TeamNeedModifierV2.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")


# =============================================================================
# SETUP & TEARDOWN
# =============================================================================

func before_test() -> void:
	# Clear config cache before each test to ensure fresh config
	TeamNeedModifierV2.clear_cache()


func after_test() -> void:
	TeamNeedModifierV2.clear_cache()


# =============================================================================
# FIXTURE HELPERS
# =============================================================================

## Create minimal test context with configurable parameters
func _create_test_context(
	position: String = "WR",
	round_num: int = 1,
	player_rating: float = 75.0,
	roster_by_position: Dictionary = {}
) -> EvaluationContext:
	var player := {
		"player_id": "test_player_001",
		"position": position,
		"hype": 50.0
	}

	var team := {
		"id": "test_team",
		"offensive_scheme": "pro_style",
		"defensive_scheme": "cover_2"
	}

	# Build roster from by_position
	var players: Array = []
	for pos in roster_by_position.keys():
		var pos_players: Array = roster_by_position[pos]
		for p in pos_players:
			players.append(p)

	var roster := {
		"players": players,
		"by_position": roster_by_position
	}

	var positions_cfg := {
		"QB": {"starters": 1, "core_stats": ["accuracy"]},
		"RB": {"starters": 2, "core_stats": ["speed"]},
		"WR": {"starters": 3, "core_stats": ["speed"]},
		"TE": {"starters": 1, "core_stats": ["blocking"]},
		"OL": {"starters": 5, "core_stats": ["strength"]},
		"DL": {"starters": 4, "core_stats": ["strength"]},
		"EDGE": {"starters": 2, "core_stats": ["speed"]},
		"LB": {"starters": 3, "core_stats": ["tackling"]},
		"CB": {"starters": 2, "core_stats": ["coverage"]},
		"S": {"starters": 2, "core_stats": ["coverage"]},
		"K": {"starters": 1, "core_stats": ["kick_power"]},
		"P": {"starters": 1, "core_stats": ["kick_power"]}
	}

	var class_rules := {}
	var draft_strategy := {}

	var ctx := EvaluationContext.for_draft(
		player, team, roster, round_num, 2025,
		positions_cfg, {}, class_rules, draft_strategy
	)
	ctx.base_rating = player_rating
	return ctx


## Create a mock player with a given rating
func _create_mock_player(player_id: String, position: String, rating: float) -> Dictionary:
	return {
		"player_id": player_id,
		"id": player_id,
		"position": position,
		"composite_score": rating,
		"overall": rating,
		"stats": {
			"accuracy": rating,
			"speed": rating,
			"strength": rating
		}
	}


# =============================================================================
# TEST CASES - NEED LEVEL ASSESSMENT
# =============================================================================

func test_critical_need_no_players() -> void:
	# Critical: 0 players at position
	var modifier := TeamNeedModifierV2.new()
	var ctx := _create_test_context("QB", 5, 75.0, {})  # Empty roster

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("need_level", "")).is_equal("critical")
	assert_float(result.additive_bonus).is_greater(0.0)
	print("[TEST] Critical need (no QB): +%.1f OVR" % result.additive_bonus)


func test_high_need_single_player() -> void:
	# High: Only 1 player at position
	var modifier := TeamNeedModifierV2.new()
	var roster_by_position := {
		"QB": ["qb1"]
	}
	var players := [_create_mock_player("qb1", "QB", 70.0)]
	var ctx := _create_test_context("QB", 5, 75.0, {"QB": ["qb1"]})
	ctx.roster["players"] = players

	var result := modifier.calculate(ctx)

	# With only 1 QB, should be HIGH need
	assert_str(result.details.get("need_level", "")).is_equal("high")
	print("[TEST] High need (1 QB): +%.1f OVR" % result.additive_bonus)


func test_high_need_weak_starter() -> void:
	# High: Starter below threshold (< 65 OVR)
	var modifier := TeamNeedModifierV2.new()
	var players := [
		_create_mock_player("qb1", "QB", 55.0),  # Weak starter
		_create_mock_player("qb2", "QB", 50.0)   # Backup
	]
	var ctx := _create_test_context("QB", 5, 75.0, {"QB": ["qb1", "qb2"]})
	ctx.roster["players"] = players

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("need_level", "")).is_equal("high")
	print("[TEST] High need (weak starter): +%.1f OVR" % result.additive_bonus)


func test_moderate_need_below_ideal_depth() -> void:
	# Moderate: Below ideal depth
	var modifier := TeamNeedModifierV2.new()
	# WR ideal depth is 6, create only 4
	var players := [
		_create_mock_player("wr1", "WR", 78.0),
		_create_mock_player("wr2", "WR", 72.0),
		_create_mock_player("wr3", "WR", 68.0),
		_create_mock_player("wr4", "WR", 60.0)
	]
	var ctx := _create_test_context("WR", 5, 70.0, {"WR": ["wr1", "wr2", "wr3", "wr4"]})
	ctx.roster["players"] = players

	var result := modifier.calculate(ctx)

	# 4 WRs (ideal is 6) = moderate need
	assert_str(result.details.get("need_level", "")).is_equal("moderate")
	print("[TEST] Moderate need (below ideal depth): +%.1f OVR" % result.additive_bonus)


func test_low_need_weak_backups() -> void:
	# Low: Good starter but weak backups
	var modifier := TeamNeedModifierV2.new()
	# QB ideal depth is 3, starter is good but backups weak
	var players := [
		_create_mock_player("qb1", "QB", 82.0),  # Elite starter
		_create_mock_player("qb2", "QB", 50.0),  # Weak backup
		_create_mock_player("qb3", "QB", 48.0)   # Very weak backup
	]
	var ctx := _create_test_context("QB", 5, 70.0, {"QB": ["qb1", "qb2", "qb3"]})
	ctx.roster["players"] = players

	var result := modifier.calculate(ctx)

	# Good starter + weak backups = low need
	assert_str(result.details.get("need_level", "")).is_equal("low")
	print("[TEST] Low need (weak backups): +%.1f OVR" % result.additive_bonus)


func test_no_need_well_stocked() -> void:
	# None: Position well-stocked with quality depth
	var modifier := TeamNeedModifierV2.new()
	# QB ideal depth is 3, all are good quality
	var players := [
		_create_mock_player("qb1", "QB", 85.0),
		_create_mock_player("qb2", "QB", 72.0),
		_create_mock_player("qb3", "QB", 65.0)
	]
	var ctx := _create_test_context("QB", 5, 70.0, {"QB": ["qb1", "qb2", "qb3"]})
	ctx.roster["players"] = players

	var result := modifier.calculate(ctx)

	assert_str(result.details.get("need_level", "")).is_equal("none")
	assert_float(result.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] No need (well-stocked): +%.1f OVR" % result.additive_bonus)


# =============================================================================
# TEST CASES - ROUND SCALING
# =============================================================================

func test_round_1_scaling_reduced_bonus() -> void:
	# Round 1 should have reduced bonus (60% for critical)
	var modifier := TeamNeedModifierV2.new()
	var ctx_r1 := _create_test_context("QB", 1, 75.0, {})  # Empty roster, R1
	var ctx_r5 := _create_test_context("QB", 5, 75.0, {})  # Empty roster, R5

	var result_r1 := modifier.calculate(ctx_r1)
	var result_r5 := modifier.calculate(ctx_r5)

	# R1 bonus should be less than R5 bonus for same need
	assert_float(result_r1.additive_bonus).is_less(result_r5.additive_bonus)
	print("[TEST] Round scaling - R1: +%.1f, R5: +%.1f" % [
		result_r1.additive_bonus, result_r5.additive_bonus
	])


func test_round_2_scaling() -> void:
	var modifier := TeamNeedModifierV2.new()
	var ctx_r2 := _create_test_context("EDGE", 2, 70.0, {})
	var ctx_r5 := _create_test_context("EDGE", 5, 70.0, {})

	var result_r2 := modifier.calculate(ctx_r2)
	var result_r5 := modifier.calculate(ctx_r5)

	# R2 should be between R1 and R5
	assert_float(result_r2.additive_bonus).is_less(result_r5.additive_bonus)
	print("[TEST] Round 2 scaling: +%.1f (R5: +%.1f)" % [
		result_r2.additive_bonus, result_r5.additive_bonus
	])


func test_round_3_4_scaling() -> void:
	var modifier := TeamNeedModifierV2.new()
	var ctx_r3 := _create_test_context("CB", 3, 68.0, {})
	var ctx_r4 := _create_test_context("CB", 4, 68.0, {})

	var result_r3 := modifier.calculate(ctx_r3)
	var result_r4 := modifier.calculate(ctx_r4)

	# R3 and R4 should have similar scaling
	assert_float(result_r3.additive_bonus).is_equal_approx(result_r4.additive_bonus, 1.0)
	print("[TEST] Round 3-4 scaling: R3: +%.1f, R4: +%.1f" % [
		result_r3.additive_bonus, result_r4.additive_bonus
	])


# =============================================================================
# TEST CASES - POSITION IMPORTANCE
# =============================================================================

func test_qb_highest_importance() -> void:
	# QB should have highest position importance multiplier (1.5x)
	var modifier := TeamNeedModifierV2.new()
	var ctx_qb := _create_test_context("QB", 5, 70.0, {})
	var ctx_rb := _create_test_context("RB", 5, 70.0, {})

	var result_qb := modifier.calculate(ctx_qb)
	var result_rb := modifier.calculate(ctx_rb)

	# QB bonus should be significantly higher than RB
	assert_float(result_qb.additive_bonus).is_greater(result_rb.additive_bonus)
	print("[TEST] Position importance - QB: +%.1f, RB: +%.1f" % [
		result_qb.additive_bonus, result_rb.additive_bonus
	])


func test_edge_cb_importance() -> void:
	# EDGE (1.2x) and CB (1.1x) should have higher importance than RB (0.7x)
	var modifier := TeamNeedModifierV2.new()
	var ctx_edge := _create_test_context("EDGE", 5, 70.0, {})
	var ctx_cb := _create_test_context("CB", 5, 70.0, {})
	var ctx_rb := _create_test_context("RB", 5, 70.0, {})

	var result_edge := modifier.calculate(ctx_edge)
	var result_cb := modifier.calculate(ctx_cb)
	var result_rb := modifier.calculate(ctx_rb)

	assert_float(result_edge.additive_bonus).is_greater(result_rb.additive_bonus)
	assert_float(result_cb.additive_bonus).is_greater(result_rb.additive_bonus)
	print("[TEST] Premium positions - EDGE: +%.1f, CB: +%.1f, RB: +%.1f" % [
		result_edge.additive_bonus, result_cb.additive_bonus, result_rb.additive_bonus
	])


func test_specialist_low_importance() -> void:
	# K and P should have very low importance multiplier (0.3x)
	var modifier := TeamNeedModifierV2.new()
	var ctx_k := _create_test_context("K", 5, 70.0, {})
	var ctx_qb := _create_test_context("QB", 5, 70.0, {})

	var result_k := modifier.calculate(ctx_k)
	var result_qb := modifier.calculate(ctx_qb)

	# K bonus should be much lower than QB
	assert_float(result_k.additive_bonus).is_less(result_qb.additive_bonus * 0.5)
	print("[TEST] Specialist importance - K: +%.1f, QB: +%.1f" % [
		result_k.additive_bonus, result_qb.additive_bonus
	])


# =============================================================================
# TEST CASES - REACH PREVENTION
# =============================================================================

func test_reach_prevention_round_1() -> void:
	# Round 1: Player must be 70+ OVR to receive bonus
	var modifier := TeamNeedModifierV2.new()
	var ctx_good := _create_test_context("QB", 1, 75.0, {})  # Above floor
	var ctx_bad := _create_test_context("QB", 1, 65.0, {})   # Below floor

	var result_good := modifier.calculate(ctx_good)
	var result_bad := modifier.calculate(ctx_bad)

	# Good player should get bonus
	assert_float(result_good.additive_bonus).is_greater(0.0)
	# Bad player should be blocked
	assert_float(result_bad.additive_bonus).is_equal_approx(0.0, 0.01)
	assert_bool(result_bad.details.get("blocked_by_reach_prevention", false)).is_true()
	print("[TEST] Reach prevention R1 - 75 OVR: +%.1f, 65 OVR: +%.1f" % [
		result_good.additive_bonus, result_bad.additive_bonus
	])


func test_reach_prevention_round_2() -> void:
	# Round 2: Player must be 65+ OVR
	var modifier := TeamNeedModifierV2.new()
	var ctx_good := _create_test_context("WR", 2, 68.0, {})  # Above floor
	var ctx_bad := _create_test_context("WR", 2, 60.0, {})   # Below floor

	var result_good := modifier.calculate(ctx_good)
	var result_bad := modifier.calculate(ctx_bad)

	assert_float(result_good.additive_bonus).is_greater(0.0)
	assert_float(result_bad.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Reach prevention R2 - 68 OVR: +%.1f, 60 OVR: +%.1f" % [
		result_good.additive_bonus, result_bad.additive_bonus
	])


func test_reach_prevention_late_rounds() -> void:
	# Round 5+: Player must be 50+ OVR (very low floor)
	var modifier := TeamNeedModifierV2.new()
	var ctx_good := _create_test_context("RB", 5, 55.0, {})
	var ctx_bad := _create_test_context("RB", 5, 45.0, {})

	var result_good := modifier.calculate(ctx_good)
	var result_bad := modifier.calculate(ctx_bad)

	assert_float(result_good.additive_bonus).is_greater(0.0)
	assert_float(result_bad.additive_bonus).is_equal_approx(0.0, 0.01)
	print("[TEST] Reach prevention R5 - 55 OVR: +%.1f, 45 OVR: +%.1f" % [
		result_good.additive_bonus, result_bad.additive_bonus
	])


# =============================================================================
# TEST CASES - DETERMINISM
# =============================================================================

func test_determinism_same_inputs() -> void:
	# Same inputs should always produce same output (no RNG)
	var modifier := TeamNeedModifierV2.new()
	var results: Array = []

	for i in range(10):
		var ctx := _create_test_context("QB", 3, 72.0, {})
		var result := modifier.calculate(ctx)
		results.append(result.additive_bonus)

	# All results should be identical
	var first := float(results[0])
	for bonus in results:
		assert_float(float(bonus)).is_equal_approx(first, 0.001)

	print("[TEST] Determinism verified: 10 identical calculations = %.2f" % first)


# =============================================================================
# TEST CASES - EDGE CASES
# =============================================================================

func test_not_applicable_non_draft_phase() -> void:
	# Should not apply if phase is not "draft"
	var modifier := TeamNeedModifierV2.new()
	var ctx := _create_test_context("QB", 1, 75.0, {})
	ctx.phase = "free_agency"  # Not draft

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for non-draft phase")


func test_not_applicable_invalid_round() -> void:
	# Should not apply if draft_round <= 0
	var modifier := TeamNeedModifierV2.new()
	var ctx := _create_test_context("QB", 0, 75.0, {})

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for round 0")


func test_not_applicable_empty_position() -> void:
	# Should not apply if position is empty
	var modifier := TeamNeedModifierV2.new()
	var ctx := _create_test_context("", 1, 75.0, {})

	assert_bool(modifier.is_applicable(ctx)).is_false()
	print("[TEST] Not applicable for empty position")


func test_bounds_check() -> void:
	# Verify modifier bounds are within expected range
	var modifier := TeamNeedModifierV2.new()
	var bounds := modifier.get_bounds()

	assert_float(float(bounds["min"])).is_equal_approx(0.0, 0.01)
	assert_float(float(bounds["max"])).is_equal_approx(12.0, 0.01)
	print("[TEST] Bounds: [%.1f, %.1f]" % [bounds["min"], bounds["max"]])


func test_modifier_metadata() -> void:
	# Verify modifier metadata
	var modifier := TeamNeedModifierV2.new()

	assert_str(modifier.get_id()).is_equal("team_need_v2")
	assert_str(modifier.get_display_name()).is_equal("Team Need (V2)")
	assert_int(modifier.get_priority()).is_equal(25)
	assert_bool("additive" in modifier.get_tags()).is_true()
	assert_bool("draft" in modifier.get_tags()).is_true()
	print("[TEST] Modifier metadata verified")


# =============================================================================
# TEST CASES - MAXIMUM BONUS SCENARIOS
# =============================================================================

func test_maximum_bonus_critical_qb_need() -> void:
	# Maximum bonus scenario: Critical QB need in late round
	var modifier := TeamNeedModifierV2.new()
	var ctx := _create_test_context("QB", 7, 70.0, {})  # R7, empty roster

	var result := modifier.calculate(ctx)

	# Critical (8.0) * 1.0 (R7 scale) * 1.5 (QB importance) = 12.0 OVR
	assert_float(result.additive_bonus).is_greater(10.0)
	assert_float(result.additive_bonus).is_less_equal(12.0)
	print("[TEST] Maximum bonus (critical QB R7): +%.1f OVR" % result.additive_bonus)


func test_minimum_bonus_low_need_specialist() -> void:
	# Minimum non-zero bonus: Low need for specialist
	var modifier := TeamNeedModifierV2.new()
	var players := [_create_mock_player("k1", "K", 75.0)]  # Good starter
	var ctx := _create_test_context("K", 1, 70.0, {"K": ["k1"]})
	ctx.roster["players"] = players

	var result := modifier.calculate(ctx)

	# Should have very low or no bonus
	assert_float(result.additive_bonus).is_less(1.0)
	print("[TEST] Minimum bonus (K with starter): +%.1f OVR" % result.additive_bonus)
