extends GdUnitTestSuite
class_name TestPickValueCurveGdUnit4

const PickValueCurve = preload("res://scripts/core/trades/PickValueCurve.gd")
const Pick = preload("res://scripts/core/trades/Pick.gd")

## Test loading default config
func test_load_default_config() -> void:
	var curve := PickValueCurve.new()

	# Should have loaded round defaults
	assert_that(curve.round_defaults).is_not_empty()
	# Should have loaded slot values
	assert_that(curve.slot_values).is_not_empty()

## Test get_value with round default
func test_get_value_round_default() -> void:
	var curve := PickValueCurve.new()

	# Round 2, slot not specifically defined (should use round default)
	var value := curve.get_value(2, 20)

	# Should return round 2 default (600 based on config)
	assert_float(value).is_equal(600.0)

## Test get_value with specific slot value
func test_get_value_specific_slot() -> void:
	var curve := PickValueCurve.new()

	# Round 1, slot 1 has specific value in config (1000)
	var value := curve.get_value(1, 1)

	assert_float(value).is_equal(1000.0)

## Test first overall pick has highest value
func test_first_overall_highest_value() -> void:
	var curve := PickValueCurve.new()

	var pick_1 := curve.get_value(1, 1)
	var pick_16 := curve.get_value(1, 16)
	var pick_32 := curve.get_value(1, 32)

	assert_float(pick_1).is_greater(pick_16)
	assert_float(pick_16).is_greater(pick_32)

## Test values decrease across rounds
func test_values_decrease_across_rounds() -> void:
	var curve := PickValueCurve.new()

	var round_1 := curve.get_value(1, 1)
	var round_2 := curve.get_value(2, 1)
	var round_3 := curve.get_value(3, 1)
	var round_4 := curve.get_value(4, 1)

	assert_float(round_1).is_greater(round_2)
	assert_float(round_2).is_greater(round_3)
	assert_float(round_3).is_greater(round_4)

## Test get_value_for_pick with Pick resource
func test_get_value_for_pick_resource() -> void:
	var curve := PickValueCurve.new()

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 1

	var value := curve.get_value_for_pick(pick)

	assert_float(value).is_equal(1000.0)

## Test get_value_for_pick with dictionary
func test_get_value_for_pick_dict() -> void:
	var curve := PickValueCurve.new()

	var pick_dict := {
		"round": 2,
		"slot": 1
	}

	var value := curve.get_value_for_pick(pick_dict)

	assert_float(value).is_equal(600.0)

## Test get_value_for_pick with null returns zero
func test_get_value_for_pick_null() -> void:
	var curve := PickValueCurve.new()

	var value := curve.get_value_for_pick(null)

	assert_float(value).is_equal(0.0)

## Test get_value with invalid round
func test_get_value_invalid_round() -> void:
	var curve := PickValueCurve.new()

	var value := curve.get_value(99, 1)

	# Should return 0.0 for undefined round
	assert_float(value).is_equal(0.0)

## Test get_value with zero slot uses round default
func test_get_value_zero_slot() -> void:
	var curve := PickValueCurve.new()

	var value := curve.get_value(3, 0)

	# Should return round 3 default (400)
	assert_float(value).is_equal(400.0)

## Test round defaults for all rounds
func test_round_defaults() -> void:
	var curve := PickValueCurve.new()

	# Based on config file
	assert_float(curve.get_value(1, 99)).is_equal(1000.0)
	assert_float(curve.get_value(2, 99)).is_equal(600.0)
	assert_float(curve.get_value(3, 99)).is_equal(400.0)
	assert_float(curve.get_value(4, 99)).is_equal(250.0)
	assert_float(curve.get_value(5, 99)).is_equal(150.0)
	assert_float(curve.get_value(6, 99)).is_equal(90.0)
	assert_float(curve.get_value(7, 99)).is_equal(50.0)

## Test specific slot values for round 1
func test_round_1_slot_values() -> void:
	var curve := PickValueCurve.new()

	# Based on config file
	assert_float(curve.get_value(1, 1)).is_equal(1000.0)
	assert_float(curve.get_value(1, 16)).is_equal(900.0)
	assert_float(curve.get_value(1, 32)).is_equal(800.0)

## Test specific slot values for round 2
func test_round_2_slot_values() -> void:
	var curve := PickValueCurve.new()

	assert_float(curve.get_value(2, 1)).is_equal(600.0)
	assert_float(curve.get_value(2, 16)).is_equal(520.0)
	assert_float(curve.get_value(2, 32)).is_equal(450.0)

## Test specific slot values for round 3
func test_round_3_slot_values() -> void:
	var curve := PickValueCurve.new()

	assert_float(curve.get_value(3, 1)).is_equal(400.0)
	assert_float(curve.get_value(3, 16)).is_equal(350.0)
	assert_float(curve.get_value(3, 32)).is_equal(300.0)

## Test value curve is monotonically decreasing within round
func test_monotonic_decrease_within_round() -> void:
	var curve := PickValueCurve.new()

	# Round 1 specific slots
	var slot_1 := curve.get_value(1, 1)
	var slot_16 := curve.get_value(1, 16)
	var slot_32 := curve.get_value(1, 32)

	assert_float(slot_1).is_greater(slot_16)
	assert_float(slot_16).is_greater(slot_32)

## Test late round picks have low value
func test_late_round_low_value() -> void:
	var curve := PickValueCurve.new()

	var round_7 := curve.get_value(7, 1)

	# Round 7 should be worth much less than round 1
	var round_1 := curve.get_value(1, 1)

	assert_float(round_7).is_less(round_1 * 0.1)  # Less than 10% of round 1

## Test realistic trade scenarios
func test_realistic_trade_values() -> void:
	var curve := PickValueCurve.new()

	# Trading up: Two 2nd round picks for a late 1st
	var pick_1_32 := curve.get_value(1, 32)
	var pick_2_1 := curve.get_value(2, 1)
	var pick_2_32 := curve.get_value(2, 32)

	# Two 2nd rounders should be roughly equal to a late 1st
	var two_seconds := pick_2_1 + pick_2_32
	assert_float(two_seconds).is_greater(pick_1_32 * 0.8)
	assert_float(two_seconds).is_less(pick_1_32 * 1.3)

## Test get_value_for_pick with missing fields
func test_get_value_for_pick_missing_fields() -> void:
	var curve := PickValueCurve.new()

	var pick_dict := {}

	var value := curve.get_value_for_pick(pick_dict)

	# Missing round/slot defaults to 0, which should return 0
	assert_float(value).is_equal(0.0)

## Test multiple PickValueCurve instances are independent
func test_multiple_instances_independent() -> void:
	var curve1 := PickValueCurve.new()
	var curve2 := PickValueCurve.new()

	var value1 := curve1.get_value(1, 1)
	var value2 := curve2.get_value(1, 1)

	# Both should load the same config
	assert_float(value1).is_equal(value2)

## Test value calculation is deterministic
func test_value_deterministic() -> void:
	var curve := PickValueCurve.new()

	var value1 := curve.get_value(1, 1)
	var value2 := curve.get_value(1, 1)
	var value3 := curve.get_value(1, 1)

	assert_float(value1).is_equal(value2)
	assert_float(value2).is_equal(value3)

## Test compensatory pick value
func test_compensatory_pick() -> void:
	var curve := PickValueCurve.new()

	# Compensatory picks (round 3-7) use round defaults
	var comp_pick := curve.get_value(3, 33)

	# Should use round 3 default
	assert_float(comp_pick).is_equal(400.0)

## Test get_value_for_pick with Pick resource multiple rounds
func test_get_value_for_pick_multiple_rounds() -> void:
	var curve := PickValueCurve.new()

	var picks: Array = []
	for round in range(1, 8):
		var pick := Pick.new()
		pick.round = round
		pick.slot = 1
		picks.append(pick)

	# Get values for all rounds
	var values: Array = []
	for pick in picks:
		values.append(curve.get_value_for_pick(pick))

	# Values should decrease across rounds
	for i in range(values.size() - 1):
		assert_float(values[i]).is_greater(values[i + 1])
