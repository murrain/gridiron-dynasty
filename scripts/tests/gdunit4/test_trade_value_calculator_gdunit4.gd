## GdUnit4 test suite for TradeValueCalculator (DRAFT-012)
##
## Validates trade value calculations, fairness ratings, and performance.
## Performance target: <16ms for UI updates
##
extends GdUnitTestSuite

const TradeValueCalculator = preload("res://scenes/ui/draft_day/TradeValueCalculator.gd")
const TradeValuation = preload("res://scripts/world/trade/TradeValuation.gd")


# =============================================================================
# Test: Pick Value Display
# =============================================================================

func test_default_pick_values_initialized() -> void:
	var calc := TradeValueCalculator.new()

	# Round 1 pick should have highest value
	var r1_value := calc.get_round_value(1)
	var r7_value := calc.get_round_value(7)

	assert_float(r1_value).is_greater(0.0)
	assert_float(r7_value).is_greater(0.0)
	assert_float(r1_value).is_greater(r7_value)

	calc.free()


func test_pick_values_decrease_by_round() -> void:
	var calc := TradeValueCalculator.new()

	var r1 := calc.get_round_value(1)
	var r2 := calc.get_round_value(2)
	var r3 := calc.get_round_value(3)
	var r4 := calc.get_round_value(4)

	assert_float(r1).is_greater(r2)
	assert_float(r2).is_greater(r3)
	assert_float(r3).is_greater(r4)

	calc.free()


func test_custom_pick_value_curve() -> void:
	var calc := TradeValueCalculator.new()

	var custom_curve := {
		"round_defaults": {
			"1": 500.0,
			"2": 250.0,
			"3": 125.0
		}
	}
	calc.set_pick_value_curve(custom_curve)

	assert_float(calc.get_round_value(1)).is_equal(500.0)
	assert_float(calc.get_round_value(2)).is_equal(250.0)
	assert_float(calc.get_round_value(3)).is_equal(125.0)

	calc.free()


# =============================================================================
# Test: Live Calculation
# =============================================================================

func test_add_incoming_pick_increases_value() -> void:
	var calc := TradeValueCalculator.new()

	var summary_before := calc.get_trade_summary()
	assert_float(float(summary_before.get("incoming_value", 0.0))).is_equal(0.0)

	calc.add_incoming_pick(1, 1)

	var summary_after := calc.get_trade_summary()
	assert_float(float(summary_after.get("incoming_value", 0.0))).is_greater(0.0)

	calc.free()


func test_add_outgoing_pick_increases_outgoing_value() -> void:
	var calc := TradeValueCalculator.new()

	calc.add_outgoing_pick(2, 1)

	var summary := calc.get_trade_summary()
	assert_float(float(summary.get("outgoing_value", 0.0))).is_greater(0.0)

	calc.free()


func test_multiple_picks_accumulate() -> void:
	var calc := TradeValueCalculator.new()

	calc.add_incoming_pick(3, 1)
	var summary1 := calc.get_trade_summary()
	var first_value := float(summary1.get("incoming_value", 0.0))

	calc.add_incoming_pick(4, 1)
	var summary2 := calc.get_trade_summary()
	var second_value := float(summary2.get("incoming_value", 0.0))

	assert_float(second_value).is_greater(first_value)

	calc.free()


func test_remove_pick_decreases_value() -> void:
	var calc := TradeValueCalculator.new()

	calc.add_incoming_pick(1, 1)
	calc.add_incoming_pick(2, 1)
	var summary_with_two := calc.get_trade_summary()
	var value_with_two := float(summary_with_two.get("incoming_value", 0.0))

	calc.remove_incoming_pick(2, 1)
	var summary_with_one := calc.get_trade_summary()
	var value_with_one := float(summary_with_one.get("incoming_value", 0.0))

	assert_float(value_with_one).is_less(value_with_two)

	calc.free()


func test_clear_trade_resets_all_values() -> void:
	var calc := TradeValueCalculator.new()

	calc.add_incoming_pick(1, 1)
	calc.add_outgoing_pick(2, 1)

	calc.clear_trade()

	var summary := calc.get_trade_summary()
	assert_float(float(summary.get("incoming_value", 0.0))).is_equal(0.0)
	assert_float(float(summary.get("outgoing_value", 0.0))).is_equal(0.0)

	calc.free()


# =============================================================================
# Test: Value Differential Visualization
# =============================================================================

func test_value_differential_calculation() -> void:
	var calc := TradeValueCalculator.new()

	# Set up a trade where we receive more than we give
	calc.add_incoming_pick(1, 1)  # High value
	calc.add_outgoing_pick(3, 1)  # Lower value

	var summary := calc.get_trade_summary()
	var differential := float(summary.get("value_differential", 0.0))

	# Differential should be positive (receiving more)
	assert_float(differential).is_greater(0.0)

	calc.free()


func test_negative_differential_when_overpaying() -> void:
	var calc := TradeValueCalculator.new()

	# Set up a trade where we give more than we receive
	calc.add_incoming_pick(4, 1)  # Lower value
	calc.add_outgoing_pick(1, 1)  # High value

	var summary := calc.get_trade_summary()
	var differential := float(summary.get("value_differential", 0.0))

	# Differential should be negative (giving more)
	assert_float(differential).is_less(0.0)

	calc.free()


# =============================================================================
# Test: Fair Trade Indicator
# =============================================================================

func test_fair_trade_when_values_balanced() -> void:
	var calc := TradeValueCalculator.new()

	# Same round picks should be roughly equal
	calc.add_incoming_pick(2, 1)
	calc.add_outgoing_pick(2, 2)

	var is_fair := calc.is_fair_trade()

	assert_bool(is_fair).is_true()

	calc.free()


func test_unfair_trade_when_heavily_unbalanced() -> void:
	var calc := TradeValueCalculator.new()

	# Giving up 1st round pick for 7th round pick
	calc.add_incoming_pick(7, 1)
	calc.add_outgoing_pick(1, 1)

	var is_fair := calc.is_fair_trade()

	assert_bool(is_fair).is_false()

	calc.free()


func test_fairness_rating_categories() -> void:
	var calc := TradeValueCalculator.new()

	# Test empty trade
	var summary_empty := calc.get_trade_summary()
	assert_str(String(summary_empty.get("fairness_rating", ""))).is_equal("EMPTY TRADE")

	# Test fair trade (similar values)
	calc.add_incoming_pick(2, 1)
	calc.add_outgoing_pick(2, 2)
	var summary_fair := calc.get_trade_summary()
	var rating := String(summary_fair.get("fairness_rating", ""))
	# Should be FAIR, GOOD, or similar
	assert_bool(rating != "TERRIBLE DEAL" and rating != "BAD DEAL").is_true()

	calc.free()


func test_steal_rating_when_heavily_winning() -> void:
	var calc := TradeValueCalculator.new()

	# Receiving 1st round for giving 5th round = steal
	calc.add_incoming_pick(1, 1)
	calc.add_outgoing_pick(5, 1)

	var summary := calc.get_trade_summary()
	var rating := String(summary.get("fairness_rating", ""))

	# Should be STEAL or GREAT DEAL
	assert_bool(rating == "STEAL" or rating == "GOOD DEAL").is_true()

	calc.free()


# =============================================================================
# Test: Performance
# =============================================================================

func test_calculation_performance_under_16ms() -> void:
	var calc := TradeValueCalculator.new()

	# Add several picks to simulate complex trade
	calc.add_incoming_pick(1, 1)
	calc.add_incoming_pick(3, 15)
	calc.add_outgoing_pick(2, 1)
	calc.add_outgoing_pick(4, 20)

	var start := Time.get_ticks_usec()

	# Perform many recalculations
	for i in range(100):
		calc.add_incoming_pick(5, i % 32 + 1)
		calc.remove_incoming_pick(5, i % 32 + 1)

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	# 100 add/remove cycles should complete in <1600ms (16ms each)
	# But we target much better: <100ms total
	assert_float(elapsed).is_less(1600.0)

	calc.free()


func test_signal_emitted_on_value_change() -> void:
	var calc := TradeValueCalculator.new()

	var signal_received := false
	var signal_data := {}

	calc.value_changed.connect(func(incoming, outgoing, diff):
		signal_received = true
		signal_data = {"incoming": incoming, "outgoing": outgoing, "diff": diff}
	)

	calc.add_incoming_pick(2, 1)

	assert_bool(signal_received).is_true()
	assert_float(float(signal_data.get("incoming", 0.0))).is_greater(0.0)

	calc.free()


# =============================================================================
# Test: Integration with TradeValuation
# =============================================================================

func test_uses_trade_valuation_for_calculations() -> void:
	# Verify that TradeValueCalculator uses TradeValuation correctly
	var pick_curve := {
		"round_defaults": {
			"1": 1000.0,
			"2": 500.0
		}
	}

	# Direct TradeValuation calculation
	var offer := {
		"incoming": {"picks": [{"round": 1, "slot": 1}], "players": []},
		"outgoing": {"picks": [], "players": []}
	}
	var context := {"pick_value_curve": pick_curve}
	var direct_result := TradeValuation.evaluate_offer(offer, context)
	var direct_value := float(direct_result.get("incoming_value", 0.0))

	# TradeValueCalculator calculation
	var calc := TradeValueCalculator.new()
	calc.set_pick_value_curve(pick_curve)
	calc.add_incoming_pick(1, 1)
	var calc_value := calc.get_pick_value(1, 1)

	# Values should match
	assert_float(calc_value).is_equal(direct_value)

	calc.free()
