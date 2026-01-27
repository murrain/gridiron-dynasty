extends GdUnitTestSuite
class_name TestTradeDecisionGdUnit4

const TradeDecision = preload("res://scripts/core/trades/TradeDecision.gd")

## Test creating TradeDecision with default config
func test_create_trade_decision() -> void:
	var decision := TradeDecision.new()

	# Default threshold should be 1.05
	assert_float(decision.accept_threshold).is_equal(1.05)

## Test should_accept when incoming meets threshold
func test_should_accept_meets_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.0

	var result := decision.should_accept(100.0, 100.0)

	assert_bool(result).is_true()

## Test should_accept when incoming exceeds threshold
func test_should_accept_exceeds_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.0

	var result := decision.should_accept(110.0, 100.0)

	assert_bool(result).is_true()

## Test should_not_accept when incoming below threshold
func test_should_not_accept_below_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# 100 < 100 * 1.05 (105)
	var result := decision.should_accept(100.0, 100.0)

	assert_bool(result).is_false()

## Test should_accept with 5% threshold
func test_should_accept_5_percent_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Need 105 to accept 100
	assert_bool(decision.should_accept(105.0, 100.0)).is_true()
	assert_bool(decision.should_accept(104.9, 100.0)).is_false()

## Test should_accept with custom threshold parameter
func test_should_accept_custom_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05  # Default

	# Override with custom threshold
	var result := decision.should_accept(102.0, 100.0, 1.02)

	assert_bool(result).is_true()

## Test should_accept with zero outgoing value
func test_should_accept_zero_outgoing() -> void:
	var decision := TradeDecision.new()

	# Any positive incoming is acceptable when outgoing is zero
	var result := decision.should_accept(10.0, 0.0)

	assert_bool(result).is_true()

## Test should_accept with zero incoming and zero outgoing
func test_should_accept_both_zero() -> void:
	var decision := TradeDecision.new()

	var result := decision.should_accept(0.0, 0.0)

	assert_bool(result).is_true()

## Test should_not_accept with zero incoming and positive outgoing
func test_should_not_accept_zero_incoming() -> void:
	var decision := TradeDecision.new()

	var result := decision.should_accept(0.0, 100.0)

	assert_bool(result).is_false()

## Test realistic scenario - fair trade
func test_realistic_fair_trade() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Receiving 1050 for 1000 (5% gain)
	var result := decision.should_accept(1050.0, 1000.0)

	assert_bool(result).is_true()

## Test realistic scenario - slightly unfair trade
func test_realistic_slightly_unfair_trade() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Receiving 1040 for 1000 (4% gain, below 5% threshold)
	var result := decision.should_accept(1040.0, 1000.0)

	assert_bool(result).is_false()

## Test realistic scenario - very unfair trade
func test_realistic_very_unfair_trade() -> void:
	var decision := TradeDecision.new()

	# Receiving 500 for 1000 (losing value)
	var result := decision.should_accept(500.0, 1000.0)

	assert_bool(result).is_false()

## Test realistic scenario - lopsided win
func test_realistic_lopsided_win() -> void:
	var decision := TradeDecision.new()

	# Receiving 2000 for 1000 (doubling value)
	var result := decision.should_accept(2000.0, 1000.0)

	assert_bool(result).is_true()

## Test threshold of exactly 1.0 (no markup required)
func test_threshold_1_point_0() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.0

	# Receiving exactly outgoing value
	assert_bool(decision.should_accept(100.0, 100.0)).is_true()

	# Receiving slightly less
	assert_bool(decision.should_accept(99.9, 100.0)).is_false()

## Test threshold of 1.1 (10% markup required)
func test_threshold_1_point_1() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.1

	# Need 110 to accept 100
	assert_bool(decision.should_accept(110.0, 100.0)).is_true()
	assert_bool(decision.should_accept(109.9, 100.0)).is_false()

## Test negative threshold uses default
func test_negative_threshold_uses_default() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Pass -1 to use default threshold
	var result := decision.should_accept(105.0, 100.0, -1.0)

	assert_bool(result).is_true()

## Test large value trade
func test_large_value_trade() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Trading superstar for picks (large values)
	var result := decision.should_accept(15750.0, 15000.0)

	assert_bool(result).is_true()

## Test small value trade
func test_small_value_trade() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Trading late round picks (small values)
	var result := decision.should_accept(105.0, 100.0)

	assert_bool(result).is_true()

## Test decision is deterministic
func test_decision_deterministic() -> void:
	var decision := TradeDecision.new()

	var result1 := decision.should_accept(105.0, 100.0)
	var result2 := decision.should_accept(105.0, 100.0)
	var result3 := decision.should_accept(105.0, 100.0)

	assert_bool(result1).is_equal(result2)
	assert_bool(result2).is_equal(result3)

## Test boundary condition - exactly at threshold
func test_boundary_exactly_at_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Exactly 5% more
	var result := decision.should_accept(105.0, 100.0)

	assert_bool(result).is_true()

## Test boundary condition - just below threshold
func test_boundary_just_below_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Just below 5% more
	var result := decision.should_accept(104.999, 100.0)

	assert_bool(result).is_false()

## Test boundary condition - just above threshold
func test_boundary_just_above_threshold() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Just above 5% more
	var result := decision.should_accept(105.001, 100.0)

	assert_bool(result).is_true()

## Test very small values with threshold
func test_very_small_values() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	# Trading very low value assets (late round picks)
	var result := decision.should_accept(52.5, 50.0)

	assert_bool(result).is_true()

## Test fractional values
func test_fractional_values() -> void:
	var decision := TradeDecision.new()
	decision.accept_threshold = 1.05

	var result := decision.should_accept(157.5, 150.0)

	assert_bool(result).is_true()
