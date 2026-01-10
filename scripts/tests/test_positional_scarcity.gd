extends RefCounted

const PositionalScarcity = preload("res://scripts/core/valuation/PositionalScarcity.gd")

func run(t) -> void:
	test_starter_slots_defined(t)
	test_scarcity_perfect_balance(t)
	test_scarcity_undersupply_premium(t)
	test_scarcity_oversupply_discount(t)
	test_scarcity_extreme_shortage_clamped(t)
	test_scarcity_extreme_surplus_clamped(t)
	test_scarcity_with_custom_config(t)
	test_scarcity_zero_supply_edge_case(t)
	test_scarcity_various_positions(t)

## Test that STARTER_SLOTS dictionary is properly defined for all positions.
func test_starter_slots_defined(t) -> void:
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

	for pos in positions:
		var slots := PositionalScarcity.STARTER_SLOTS.get(pos, -1)
		t.assert_true(slots > 0, "%s has defined starter slots" % pos)

	# Verify some specific values
	t.assert_equal(PositionalScarcity.STARTER_SLOTS["QB"], 1, "QB requires 1 starter")
	t.assert_equal(PositionalScarcity.STARTER_SLOTS["WR"], 3, "WR requires 3 starters")
	t.assert_equal(PositionalScarcity.STARTER_SLOTS["OL"], 5, "OL requires 5 starters")

## Test scarcity when supply exactly matches demand (32 teams).
func test_scarcity_perfect_balance(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# QB: 1 slot × 32 teams = 32 demand, 32 supply → ratio = 1.0
	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 32, config)
	t.assert_approx(mult, 1.0, 0.001, "Perfect supply/demand balance yields 1.0 multiplier")

	# WR: 3 slots × 32 teams = 96 demand, 96 supply → ratio = 1.0
	mult = PositionalScarcity.compute_scarcity_multiplier("WR", 96, config)
	t.assert_approx(mult, 1.0, 0.001, "Perfect WR supply/demand balance yields 1.0")

## Test scarcity premium when supply < demand.
func test_scarcity_undersupply_premium(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# QB: 32 needed, only 20 available → ratio = 32/20 = 1.6 (clamped to 1.5)
	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 20, config)
	t.assert_approx(mult, 1.5, 0.001, "QB shortage creates premium (clamped to max)")

	# CB: 64 needed, 50 available → ratio = 64/50 = 1.28
	mult = PositionalScarcity.compute_scarcity_multiplier("CB", 50, config)
	t.assert_approx(mult, 1.28, 0.001, "CB shortage creates moderate premium")

	# All undersupply should have multiplier > 1.0
	t.assert_true(mult > 1.0, "Undersupply creates premium")

## Test scarcity discount when supply > demand.
func test_scarcity_oversupply_discount(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# RB: 32 needed, 50 available → ratio = 32/50 = 0.64 (clamped to 0.7)
	var mult := PositionalScarcity.compute_scarcity_multiplier("RB", 50, config)
	t.assert_approx(mult, 0.7, 0.001, "RB surplus creates discount (clamped to min)")

	# WR: 96 needed, 120 available → ratio = 96/120 = 0.8
	mult = PositionalScarcity.compute_scarcity_multiplier("WR", 120, config)
	t.assert_approx(mult, 0.8, 0.001, "WR surplus creates moderate discount")

	# All oversupply should have multiplier < 1.0
	t.assert_true(mult < 1.0, "Oversupply creates discount")

## Test that extreme shortage is clamped to max multiplier.
func test_scarcity_extreme_shortage_clamped(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# EDGE: 64 needed, only 10 available → ratio = 6.4 (should clamp to 1.5)
	var mult := PositionalScarcity.compute_scarcity_multiplier("EDGE", 10, config)
	t.assert_approx(mult, 1.5, 0.001, "Extreme EDGE shortage clamped to max")

	# QB: 32 needed, only 5 available → ratio = 6.4 (should clamp to 1.5)
	mult = PositionalScarcity.compute_scarcity_multiplier("QB", 5, config)
	t.assert_approx(mult, 1.5, 0.001, "Extreme QB shortage clamped to max")

	# Verify clamping prevents runaway multipliers
	t.assert_true(mult <= 1.5, "Multiplier never exceeds max")

## Test that extreme surplus is clamped to min multiplier.
func test_scarcity_extreme_surplus_clamped(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# K: 32 needed, 200 available → ratio = 0.16 (should clamp to 0.7)
	var mult := PositionalScarcity.compute_scarcity_multiplier("K", 200, config)
	t.assert_approx(mult, 0.7, 0.001, "Extreme K surplus clamped to min")

	# RB: 32 needed, 100 available → ratio = 0.32 (should clamp to 0.7)
	mult = PositionalScarcity.compute_scarcity_multiplier("RB", 100, config)
	t.assert_approx(mult, 0.7, 0.001, "Extreme RB surplus clamped to min")

	# Verify clamping prevents excessive discounts
	t.assert_true(mult >= 0.7, "Multiplier never below min")

## Test scarcity calculation with custom config values.
func test_scarcity_with_custom_config(t) -> void:
	var config := {
		"scarcity_min": 0.5,
		"scarcity_max": 2.0
	}

	# QB: 32 needed, 16 available → ratio = 2.0 (should clamp to custom max)
	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 16, config)
	t.assert_approx(mult, 2.0, 0.001, "Custom max clamp respected")

	# RB: 32 needed, 100 available → ratio = 0.32 (should clamp to custom min)
	mult = PositionalScarcity.compute_scarcity_multiplier("RB", 100, config)
	t.assert_approx(mult, 0.5, 0.001, "Custom min clamp respected")

	# WR: 96 needed, 60 available → ratio = 1.6 (within custom range)
	mult = PositionalScarcity.compute_scarcity_multiplier("WR", 60, config)
	t.assert_approx(mult, 1.6, 0.001, "Multiplier within custom range")

## Test edge case where supply is zero.
func test_scarcity_zero_supply_edge_case(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# QB: 32 needed, 0 available → ratio = 32/1 = 32 (protected by max(supply, 1.0))
	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 0, config)
	t.assert_approx(mult, 1.5, 0.001, "Zero supply clamped to max (protected by max(supply, 1.0))")

	# Verify no division by zero error occurs
	t.assert_true(mult > 0.0, "Multiplier is positive even with zero supply")

## Test scarcity across various positions with realistic scenarios.
func test_scarcity_various_positions(t) -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	# Scenario: Realistic league-wide supply
	var scenarios := [
		{"position": "QB", "supply": 40, "expected_range": [0.7, 1.0]},    # Slight surplus
		{"position": "EDGE", "supply": 50, "expected_range": [1.0, 1.5]},  # Slight shortage
		{"position": "OL", "supply": 180, "expected_range": [0.7, 1.0]},   # Slight surplus
		{"position": "RB", "supply": 60, "expected_range": [0.5, 0.7]},    # Large surplus (clamped)
		{"position": "LB", "supply": 96, "expected_range": [0.9, 1.1]},    # Near balance
	]

	for scenario in scenarios:
		var pos: String = scenario["position"]
		var supply: int = scenario["supply"]
		var expected_range: Array = scenario["expected_range"]

		var mult := PositionalScarcity.compute_scarcity_multiplier(pos, supply, config)
		t.assert_between(mult, expected_range[0], expected_range[1],
			"%s scarcity multiplier with %d supply is within expected range" % [pos, supply])
