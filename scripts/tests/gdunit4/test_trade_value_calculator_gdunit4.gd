extends GdUnitTestSuite
class_name TestTradeValueCalculatorGdUnit4

const TradeValueCalculator = preload("res://scripts/core/trades/TradeValueCalculator.gd")
const TradeOffer = preload("res://scripts/core/trades/TradeOffer.gd")
const PickValueCurve = preload("res://scripts/core/trades/PickValueCurve.gd")
const Pick = preload("res://scripts/core/trades/Pick.gd")

## Test creating calculator with default curve
func test_create_calculator_default() -> void:
	var calc := TradeValueCalculator.new()

	assert_object(calc.pick_curve).is_not_null()

## Test creating calculator with custom curve
func test_create_calculator_custom_curve() -> void:
	var custom_curve := PickValueCurve.new()
	var calc := TradeValueCalculator.new(custom_curve)

	assert_object(calc.pick_curve).is_equal(custom_curve)

## Test value_offer with empty trade
func test_value_offer_empty() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()
	var player_values := {}

	var result := calc.value_offer(offer, player_values)

	assert_that(result).contains_key("send")
	assert_that(result).contains_key("receive")
	assert_float(result["send"]).is_equal(0.0)
	assert_float(result["receive"]).is_equal(0.0)

## Test value_offer with players only
func test_value_offer_players_only() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["P1", "P2"]
	offer.receive_player_ids = ["P3"]

	var player_values := {
		"P1": 500.0,
		"P2": 300.0,
		"P3": 750.0
	}

	var result := calc.value_offer(offer, player_values)

	assert_float(result["send"]).is_equal(800.0)  # 500 + 300
	assert_float(result["receive"]).is_equal(750.0)

## Test value_offer with picks only
func test_value_offer_picks_only() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	var send_pick := Pick.new()
	send_pick.round = 1
	send_pick.slot = 10

	var recv_pick := Pick.new()
	recv_pick.round = 2
	recv_pick.slot = 5

	offer.send_picks = [send_pick]
	offer.receive_picks = [recv_pick]

	var result := calc.value_offer(offer, {})

	# Should use pick curve values
	assert_float(result["send"]).is_greater(0.0)
	assert_float(result["receive"]).is_greater(0.0)

## Test value_offer with players and picks
func test_value_offer_mixed() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["P1"]

	var send_pick := Pick.new()
	send_pick.round = 3
	send_pick.slot = 15
	offer.send_picks = [send_pick]

	offer.receive_player_ids = ["P2"]

	var recv_pick := Pick.new()
	recv_pick.round = 1
	recv_pick.slot = 20
	offer.receive_picks = [recv_pick]

	var player_values := {
		"P1": 400.0,
		"P2": 800.0
	}

	var result := calc.value_offer(offer, player_values)

	# Send: 400 + pick value
	# Receive: 800 + pick value
	assert_float(result["send"]).is_greater(400.0)
	assert_float(result["receive"]).is_greater(800.0)

## Test value_players with valid IDs
func test_value_players() -> void:
	var calc := TradeValueCalculator.new()

	var player_ids := ["P1", "P2", "P3"]
	var player_values := {
		"P1": 100.0,
		"P2": 200.0,
		"P3": 150.0
	}

	var total := calc.value_players(player_ids, player_values)

	assert_float(total).is_equal(450.0)

## Test value_players with missing IDs
func test_value_players_missing_ids() -> void:
	var calc := TradeValueCalculator.new()

	var player_ids := ["P1", "P2", "P3"]
	var player_values := {
		"P1": 100.0,
		"P3": 150.0
		# P2 missing
	}

	var total := calc.value_players(player_ids, player_values)

	# Should skip P2 and count as 0
	assert_float(total).is_equal(250.0)

## Test value_players with empty array
func test_value_players_empty() -> void:
	var calc := TradeValueCalculator.new()

	var total := calc.value_players([], {})

	assert_float(total).is_equal(0.0)

## Test value_picks with valid picks
func test_value_picks() -> void:
	var calc := TradeValueCalculator.new()

	var pick1 := Pick.new()
	pick1.round = 1
	pick1.slot = 1

	var pick2 := Pick.new()
	pick2.round = 2
	pick2.slot = 1

	var picks := [pick1, pick2]

	var total := calc.value_picks(picks)

	# Should use curve values (1000 + 600 from config)
	assert_float(total).is_equal(1600.0)

## Test value_picks with empty array
func test_value_picks_empty() -> void:
	var calc := TradeValueCalculator.new()

	var total := calc.value_picks([])

	assert_float(total).is_equal(0.0)

## Test value_picks with dictionary picks
func test_value_picks_with_dicts() -> void:
	var calc := TradeValueCalculator.new()

	var pick_dict := {
		"round": 1,
		"slot": 1
	}

	var picks := [pick_dict]

	var total := calc.value_picks(picks)

	assert_float(total).is_equal(1000.0)

## Test value_bundle
func test_value_bundle() -> void:
	var calc := TradeValueCalculator.new()

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 1

	var bundle := {
		"player_ids": ["P1", "P2"],
		"picks": [pick]
	}

	var player_values := {
		"P1": 300.0,
		"P2": 200.0
	}

	var total := calc.value_bundle(bundle, player_values)

	# 300 + 200 + 1000 (pick value)
	assert_float(total).is_equal(1500.0)

## Test value_bundle with missing keys
func test_value_bundle_missing_keys() -> void:
	var calc := TradeValueCalculator.new()

	var bundle := {}
	var player_values := {}

	var total := calc.value_bundle(bundle, player_values)

	assert_float(total).is_equal(0.0)

## Test realistic trade - star player for multiple picks
func test_realistic_star_for_picks() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["STAR_QB"]

	var pick1 := Pick.new()
	pick1.round = 1
	pick1.slot = 5

	var pick2 := Pick.new()
	pick2.round = 2
	pick2.slot = 5

	var pick3 := Pick.new()
	pick3.round = 3
	pick3.slot = 5

	offer.receive_picks = [pick1, pick2, pick3]

	var player_values := {
		"STAR_QB": 2000.0
	}

	var result := calc.value_offer(offer, player_values)

	assert_float(result["send"]).is_equal(2000.0)
	assert_float(result["receive"]).is_greater(0.0)

## Test realistic trade - multiple players for player
func test_realistic_players_for_player() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["WR1", "RB1"]
	offer.receive_player_ids = ["QB1"]

	var player_values := {
		"WR1": 600.0,
		"RB1": 400.0,
		"QB1": 900.0
	}

	var result := calc.value_offer(offer, player_values)

	assert_float(result["send"]).is_equal(1000.0)
	assert_float(result["receive"]).is_equal(900.0)

## Test calculation is deterministic
func test_calculation_deterministic() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["P1"]
	offer.receive_player_ids = ["P2"]

	var player_values := {
		"P1": 500.0,
		"P2": 600.0
	}

	var result1 := calc.value_offer(offer, player_values)
	var result2 := calc.value_offer(offer, player_values)
	var result3 := calc.value_offer(offer, player_values)

	assert_float(result1["send"]).is_equal(result2["send"])
	assert_float(result2["send"]).is_equal(result3["send"])
	assert_float(result1["receive"]).is_equal(result2["receive"])

## Test value_offer with zero player values
func test_value_offer_zero_values() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["P1"]
	offer.receive_player_ids = ["P2"]

	var player_values := {
		"P1": 0.0,
		"P2": 0.0
	}

	var result := calc.value_offer(offer, player_values)

	assert_float(result["send"]).is_equal(0.0)
	assert_float(result["receive"]).is_equal(0.0)

## Test massive trade with many assets
func test_massive_trade() -> void:
	var calc := TradeValueCalculator.new()
	var offer := TradeOffer.new()

	offer.send_player_ids = ["P1", "P2", "P3", "P4"]

	for round in range(1, 5):
		var pick := Pick.new()
		pick.round = round
		pick.slot = 10
		offer.send_picks.append(pick)

	offer.receive_player_ids = ["P5", "P6"]

	for round in range(1, 3):
		var pick := Pick.new()
		pick.round = round
		pick.slot = 5
		offer.receive_picks.append(pick)

	var player_values := {
		"P1": 400.0,
		"P2": 350.0,
		"P3": 300.0,
		"P4": 250.0,
		"P5": 700.0,
		"P6": 600.0
	}

	var result := calc.value_offer(offer, player_values)

	# Send: 400 + 350 + 300 + 250 + pick values
	assert_float(result["send"]).is_greater(1300.0)

	# Receive: 700 + 600 + pick values
	assert_float(result["receive"]).is_greater(1300.0)

## Test null pick curve handles gracefully
func test_null_pick_curve() -> void:
	var calc := TradeValueCalculator.new(null)

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 1

	var value := calc.value_picks([pick])

	# Should return 0 when no curve available
	assert_float(value).is_equal(0.0)
