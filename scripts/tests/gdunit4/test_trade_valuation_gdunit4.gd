## GdUnit4 test suite for TradeValuation
##
## Validates trade bundle value calculation and acceptance logic.
## Migrated from test_trade_valuation.gd
extends GdUnitTestSuite

const TradeValuation = preload("res://scripts/core/valuation/TradeValuation.gd")


func test_offer_bundle_aggregates_players_and_picks() -> void:
	var offer := {
		"players": [{"name": "WR1", "est_value": 14.0}],
		"picks": [
			{"round": 2, "est_value": 4.0},
			{"round": 4, "est_value": 2.0}
		]
	}

	var offer_value := TradeValuation.bundle_value(offer)

	assert_float(offer_value).is_equal_approx(20.0, 0.0001)


func test_ask_bundle_aggregates_players_and_picks() -> void:
	var ask := {
		"players": [{"name": "CB1", "est_value": 18.0}],
		"picks": [{"round": 5, "est_value": 1.0}]
	}

	var ask_value := TradeValuation.bundle_value(ask)

	assert_float(ask_value).is_equal_approx(19.0, 0.0001)


func test_trade_accepts_when_offer_meets_ask() -> void:
	var offer := {
		"players": [{"name": "WR1", "est_value": 14.0}],
		"picks": [
			{"round": 2, "est_value": 4.0},
			{"round": 4, "est_value": 2.0}
		]
	}
	var ask := {
		"players": [{"name": "CB1", "est_value": 18.0}],
		"picks": [{"round": 5, "est_value": 1.0}]
	}

	assert_bool(TradeValuation.is_trade_acceptable(offer, ask, 1.0)).is_true()


func test_trade_rejects_when_offer_falls_short() -> void:
	var weak_offer := {
		"players": [{"name": "WR2", "est_value": 10.0}],
		"picks": []
	}
	var ask := {
		"players": [{"name": "CB1", "est_value": 18.0}],
		"picks": [{"round": 5, "est_value": 1.0}]
	}

	assert_bool(not TradeValuation.is_trade_acceptable(weak_offer, ask, 1.0)).is_true()


func test_empty_bundle_has_zero_value() -> void:
	var empty_bundle := {"players": [], "picks": []}

	var value := TradeValuation.bundle_value(empty_bundle)

	assert_float(value).is_equal_approx(0.0, 0.0001)


func test_multiple_players_sum_values() -> void:
	var bundle := {
		"players": [
			{"name": "P1", "est_value": 10.0},
			{"name": "P2", "est_value": 8.0},
			{"name": "P3", "est_value": 6.0}
		],
		"picks": []
	}

	var value := TradeValuation.bundle_value(bundle)

	assert_float(value).is_equal_approx(24.0, 0.0001)


func test_multiple_picks_sum_values() -> void:
	var bundle := {
		"players": [],
		"picks": [
			{"round": 1, "est_value": 15.0},
			{"round": 3, "est_value": 5.0},
			{"round": 7, "est_value": 1.0}
		]
	}

	var value := TradeValuation.bundle_value(bundle)

	assert_float(value).is_equal_approx(21.0, 0.0001)
