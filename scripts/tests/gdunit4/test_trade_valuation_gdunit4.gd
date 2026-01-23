extends GdUnitTestSuite
class_name TestTradeValuationGdUnit4

const TradeValuation = preload("res://scripts/core/valuation/TradeValuation.gd")

## Test bundle_value with empty bundle
func test_bundle_value_empty() -> void:
	var bundle := {"players": [], "picks": []}
	var value := TradeValuation.bundle_value(bundle)
	assert_float(value).is_equal(0.0)

## Test bundle_value with only players
func test_bundle_value_only_players() -> void:
	var bundle := {
		"players": [
			{"est_value": 10.0},
			{"est_value": 15.0},
			{"est_value": 8.0}
		],
		"picks": []
	}

	var value := TradeValuation.bundle_value(bundle)
	assert_float(value).is_equal(33.0)  # 10 + 15 + 8

## Test bundle_value with only picks
func test_bundle_value_only_picks() -> void:
	var bundle := {
		"players": [],
		"picks": [
			{"est_value": 1000.0},
			{"est_value": 600.0}
		]
	}

	var value := TradeValuation.bundle_value(bundle)
	assert_float(value).is_equal(1600.0)

## Test bundle_value with players and picks
func test_bundle_value_mixed() -> void:
	var bundle := {
		"players": [
			{"est_value": 10.0},
			{"est_value": 15.0}
		],
		"picks": [
			{"est_value": 1000.0}
		]
	}

	var value := TradeValuation.bundle_value(bundle)
	assert_float(value).is_equal(1025.0)  # 10 + 15 + 1000

## Test bundle_value with missing est_value defaults to 0
func test_bundle_value_missing_est_value() -> void:
	var bundle := {
		"players": [
			{"name": "Player1"},  # No est_value
			{"est_value": 10.0}
		],
		"picks": []
	}

	var value := TradeValuation.bundle_value(bundle)
	assert_float(value).is_equal(10.0)

## Test is_trade_acceptable when offer meets ask
func test_trade_acceptable_equal_value() -> void:
	var offer := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}
	var ask := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test is_trade_acceptable when offer exceeds ask
func test_trade_acceptable_offer_exceeds() -> void:
	var offer := {
		"players": [{"est_value": 60.0}],
		"picks": []
	}
	var ask := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test is_trade_acceptable when offer falls short
func test_trade_not_acceptable_offer_short() -> void:
	var offer := {
		"players": [{"est_value": 40.0}],
		"picks": []
	}
	var ask := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_false()

## Test is_trade_acceptable with minimum ratio
func test_trade_acceptable_with_ratio() -> void:
	var offer := {
		"players": [{"est_value": 52.0}],
		"picks": []
	}
	var ask := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}

	# 1.0 ratio: 52 >= 50 * 1.0 (true)
	assert_bool(TradeValuation.is_trade_acceptable(offer, ask, 1.0)).is_true()

	# 1.05 ratio: 52 >= 50 * 1.05 = 52.5 (false)
	assert_bool(TradeValuation.is_trade_acceptable(offer, ask, 1.05)).is_false()

	# 1.04 ratio: 52 >= 50 * 1.04 = 52.0 (true)
	assert_bool(TradeValuation.is_trade_acceptable(offer, ask, 1.04)).is_true()

## Test is_trade_acceptable with zero ask value
func test_trade_acceptable_zero_ask() -> void:
	var offer := {
		"players": [{"est_value": 10.0}],
		"picks": []
	}
	var ask := {
		"players": [],
		"picks": []
	}

	# Any positive offer is acceptable when ask is zero
	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test is_trade_acceptable with zero offer and zero ask
func test_trade_acceptable_both_zero() -> void:
	var offer := {"players": [], "picks": []}
	var ask := {"players": [], "picks": []}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test is_trade_acceptable with zero offer and positive ask
func test_trade_not_acceptable_zero_offer() -> void:
	var offer := {"players": [], "picks": []}
	var ask := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_false()

## Test realistic trade scenario - pick for player
func test_realistic_pick_for_player() -> void:
	var offer := {
		"players": [],
		"picks": [{"est_value": 1000.0}]  # 1st round pick
	}
	var ask := {
		"players": [{"est_value": 800.0}],  # Star player
		"picks": []
	}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test realistic trade scenario - multiple picks for player
func test_realistic_multiple_picks_for_player() -> void:
	var offer := {
		"players": [],
		"picks": [
			{"est_value": 600.0},  # 2nd round pick
			{"est_value": 400.0},  # 3rd round pick
			{"est_value": 250.0}   # 4th round pick
		]
	}
	var ask := {
		"players": [{"est_value": 1100.0}],
		"picks": []
	}

	# Total offer: 1250, ask: 1100
	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test realistic trade scenario - player for player
func test_realistic_player_for_player() -> void:
	var offer := {
		"players": [{"est_value": 750.0}],
		"picks": []
	}
	var ask := {
		"players": [{"est_value": 700.0}],
		"picks": []
	}

	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test realistic trade scenario - complex multi-asset trade
func test_realistic_complex_trade() -> void:
	var offer := {
		"players": [
			{"est_value": 400.0},
			{"est_value": 300.0}
		],
		"picks": [
			{"est_value": 600.0}
		]
	}
	var ask := {
		"players": [{"est_value": 1000.0}],
		"picks": [{"est_value": 250.0}]
	}

	# Offer: 400 + 300 + 600 = 1300
	# Ask: 1000 + 250 = 1250
	var acceptable := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	assert_bool(acceptable).is_true()

## Test bundle_value is deterministic
func test_bundle_value_deterministic() -> void:
	var bundle := {
		"players": [
			{"est_value": 10.0},
			{"est_value": 15.0}
		],
		"picks": [
			{"est_value": 1000.0}
		]
	}

	var value1 := TradeValuation.bundle_value(bundle)
	var value2 := TradeValuation.bundle_value(bundle)
	var value3 := TradeValuation.bundle_value(bundle)

	assert_float(value1).is_equal(value2)
	assert_float(value2).is_equal(value3)

## Test is_trade_acceptable is deterministic
func test_trade_acceptable_deterministic() -> void:
	var offer := {
		"players": [{"est_value": 50.0}],
		"picks": []
	}
	var ask := {
		"players": [{"est_value": 45.0}],
		"picks": []
	}

	var result1 := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	var result2 := TradeValuation.is_trade_acceptable(offer, ask, 1.0)
	var result3 := TradeValuation.is_trade_acceptable(offer, ask, 1.0)

	assert_bool(result1).is_equal(result2)
	assert_bool(result2).is_equal(result3)

## Test negative est_value (shouldn't happen but handle gracefully)
func test_bundle_value_negative_values() -> void:
	var bundle := {
		"players": [
			{"est_value": -10.0},
			{"est_value": 50.0}
		],
		"picks": []
	}

	var value := TradeValuation.bundle_value(bundle)
	assert_float(value).is_equal(40.0)
