extends GdUnitTestSuite
class_name TestPositionalScarcityGdUnit4

const PositionalScarcity = preload("res://scripts/core/valuation/PositionalScarcity.gd")

## Test scarcity multiplier when supply equals demand
func test_scarcity_supply_equals_demand() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# 32 QBs needed (1 per team * 32 teams), 32 available
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 32, config)
	assert_float(multiplier).is_equal(1.0)

## Test scarcity multiplier when supply exceeds demand
func test_scarcity_supply_exceeds_demand() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# 32 QBs needed, 64 available (abundant supply)
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 64, config)
	assert_float(multiplier).is_less(1.0)
	assert_float(multiplier).is_greater_equal(0.7)  # Clamped to min

## Test scarcity multiplier when demand exceeds supply
func test_scarcity_demand_exceeds_supply() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# 32 QBs needed, only 20 available (scarce)
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 20, config)
	assert_float(multiplier).is_greater(1.0)
	assert_float(multiplier).is_less_equal(1.5)  # Clamped to max

## Test scarcity clamping at minimum
func test_scarcity_clamped_at_min() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# Very abundant supply (200 QBs for 32 slots)
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 200, config)
	assert_float(multiplier).is_equal(0.7)

## Test scarcity clamping at maximum
func test_scarcity_clamped_at_max() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# Very scarce supply (5 QBs for 32 slots)
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 5, config)
	assert_float(multiplier).is_equal(1.5)

## Test different positions with different starter slots
func test_different_positions() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {
			"QB": 1,   # 32 total slots
			"WR": 3,   # 96 total slots
			"OL": 5    # 160 total slots
		}
	}

	# Same supply for all positions, different demand
	var qb_mult := PositionalScarcity.compute_scarcity_multiplier("QB", 50, config)
	var wr_mult := PositionalScarcity.compute_scarcity_multiplier("WR", 50, config)
	var ol_mult := PositionalScarcity.compute_scarcity_multiplier("OL", 50, config)

	# QB has lowest demand (32), so with 50 supply it's least scarce
	# OL has highest demand (160), so with 50 supply it's most scarce
	assert_float(qb_mult).is_less(wr_mult)
	assert_float(wr_mult).is_less(ol_mult)

## Test unknown position uses hardcoded default
func test_unknown_position_uses_default() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {}
	}

	# Unknown position should use hardcoded STARTER_SLOTS
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 32, config)
	assert_float(multiplier).is_equal(1.0)

## Test zero supply edge case
func test_zero_supply() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# Zero supply should clamp to max multiplier
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 0, config)
	assert_float(multiplier).is_equal(1.5)

## Test WR position with typical supply
func test_wr_typical_supply() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"WR": 3}
	}

	# 96 WR slots needed (3 * 32), 120 available (typical)
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("WR", 120, config)
	assert_float(multiplier).is_between(0.7, 1.0)

## Test OL position with typical supply
func test_ol_typical_supply() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"OL": 5}
	}

	# 160 OL slots needed (5 * 32), 180 available (slightly above demand)
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("OL", 180, config)
	assert_float(multiplier).is_between(0.7, 1.0)

## Test that scarcity calculation is deterministic
func test_scarcity_deterministic() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	var mult1 := PositionalScarcity.compute_scarcity_multiplier("QB", 40, config)
	var mult2 := PositionalScarcity.compute_scarcity_multiplier("QB", 40, config)
	var mult3 := PositionalScarcity.compute_scarcity_multiplier("QB", 40, config)

	assert_float(mult1).is_equal(mult2)
	assert_float(mult2).is_equal(mult3)

## Test hardcoded starter slots are sensible
func test_hardcoded_starter_slots() -> void:
	# Verify the hardcoded STARTER_SLOTS make sense
	assert_int(PositionalScarcity.STARTER_SLOTS["QB"]).is_equal(1)
	assert_int(PositionalScarcity.STARTER_SLOTS["WR"]).is_equal(3)
	assert_int(PositionalScarcity.STARTER_SLOTS["OL"]).is_equal(5)
	assert_int(PositionalScarcity.STARTER_SLOTS["LB"]).is_equal(3)
	assert_int(PositionalScarcity.STARTER_SLOTS["K"]).is_equal(1)

## Test realistic NFL scenario - scarce QBs
func test_realistic_scarce_qbs() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"QB": 1}
	}

	# Realistic: Only 24 quality starting QBs in the league
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("QB", 24, config)
	assert_float(multiplier).is_greater(1.0)
	# 32 / 24 = 1.33, should be within bounds
	assert_float(multiplier).is_between(1.0, 1.5)

## Test realistic NFL scenario - abundant RBs
func test_realistic_abundant_rbs() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"RB": 1}
	}

	# Realistic: 50+ quality RBs available in the league
	var multiplier := PositionalScarcity.compute_scarcity_multiplier("RB", 50, config)
	assert_float(multiplier).is_less(1.0)
	# 32 / 50 = 0.64, should clamp to min 0.7
	assert_float(multiplier).is_equal(0.7)

## Test K and P positions (most replaceable)
func test_kickers_punters_low_scarcity() -> void:
	var config := {
		"scarcity_min": 0.7,
		"scarcity_max": 1.5,
		"starter_slots": {"K": 1, "P": 1}
	}

	# Abundant supply of kickers and punters
	var k_mult := PositionalScarcity.compute_scarcity_multiplier("K", 100, config)
	var p_mult := PositionalScarcity.compute_scarcity_multiplier("P", 100, config)

	# Should both clamp to minimum
	assert_float(k_mult).is_equal(0.7)
	assert_float(p_mult).is_equal(0.7)
