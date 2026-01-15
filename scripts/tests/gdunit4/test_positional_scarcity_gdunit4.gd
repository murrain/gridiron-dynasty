## GdUnit4 test suite for PositionalScarcity
##
## Validates scarcity multiplier calculations for supply/demand scenarios.
## Migrated from test_positional_scarcity.gd
extends GdUnitTestSuite

const PositionalScarcity = preload("res://scripts/core/valuation/PositionalScarcity.gd")


func test_starter_slots_defined() -> void:
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

	for pos in positions:
		var slots: int = int(PositionalScarcity.STARTER_SLOTS.get(pos, -1))
		assert_int(slots).is_greater(0)

	assert_int(int(PositionalScarcity.STARTER_SLOTS["QB"])).is_equal(1)
	assert_int(int(PositionalScarcity.STARTER_SLOTS["WR"])).is_equal(3)
	assert_int(int(PositionalScarcity.STARTER_SLOTS["OL"])).is_equal(5)


func test_scarcity_perfect_balance() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 32, config)
	assert_float(mult).is_equal_approx(1.0, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("WR", 96, config)
	assert_float(mult).is_equal_approx(1.0, 0.001)


func test_scarcity_undersupply_premium() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 20, config)
	assert_float(mult).is_equal_approx(1.5, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("CB", 50, config)
	assert_float(mult).is_equal_approx(1.28, 0.001)

	assert_float(mult).is_greater(1.0)


func test_scarcity_oversupply_discount() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("RB", 50, config)
	assert_float(mult).is_equal_approx(0.7, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("WR", 120, config)
	assert_float(mult).is_equal_approx(0.8, 0.001)

	assert_float(mult).is_less(1.0)


func test_scarcity_extreme_shortage_clamped() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("EDGE", 10, config)
	assert_float(mult).is_equal_approx(1.5, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("QB", 5, config)
	assert_float(mult).is_equal_approx(1.5, 0.001)

	assert_float(mult).is_less_equal(1.5)


func test_scarcity_extreme_surplus_clamped() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("K", 200, config)
	assert_float(mult).is_equal_approx(0.7, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("RB", 100, config)
	assert_float(mult).is_equal_approx(0.7, 0.001)

	assert_float(mult).is_greater_equal(0.7)


func test_scarcity_with_custom_config() -> void:
	var config := {
		"scarcity_min": 0.5,
		"scarcity_max": 2.0
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 16, config)
	assert_float(mult).is_equal_approx(2.0, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("RB", 100, config)
	assert_float(mult).is_equal_approx(0.5, 0.001)

	mult = PositionalScarcity.compute_scarcity_multiplier("WR", 60, config)
	assert_float(mult).is_equal_approx(1.6, 0.001)


func test_scarcity_zero_supply_edge_case() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var mult := PositionalScarcity.compute_scarcity_multiplier("QB", 0, config)
	assert_float(mult).is_equal_approx(1.5, 0.001)

	assert_float(mult).is_greater(0.0)


func test_scarcity_various_positions() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5
	}

	var scenarios := [
		{"position": "QB", "supply": 40, "expected_range": [0.7, 1.0]},
		{"position": "EDGE", "supply": 50, "expected_range": [1.0, 1.5]},
		{"position": "OL", "supply": 180, "expected_range": [0.7, 1.0]},
		{"position": "RB", "supply": 60, "expected_range": [0.5, 0.7]},
		{"position": "LB", "supply": 96, "expected_range": [0.9, 1.1]},
	]

	for scenario in scenarios:
		var pos: String = scenario["position"]
		var supply: int = scenario["supply"]
		var expected_range: Array = scenario["expected_range"]

		var mult := PositionalScarcity.compute_scarcity_multiplier(pos, supply, config)
		assert_float(mult).is_between(expected_range[0], expected_range[1])
