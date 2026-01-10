extends RefCounted

const TradeValuation = preload("res://scripts/core/valuation/TradeValuation.gd")

func run(t) -> void:
	var offer := {
		"players": [
			{"name": "WR1", "est_value": 14.0}
		],
		"picks": [
			{"round": 2, "est_value": 4.0},
			{"round": 4, "est_value": 2.0}
		]
	}
	var ask := {
		"players": [
			{"name": "CB1", "est_value": 18.0}
		],
		"picks": [
			{"round": 5, "est_value": 1.0}
		]
	}

	var offer_value := TradeValuation.bundle_value(offer)
	var ask_value := TradeValuation.bundle_value(ask)

	t.assert_approx(offer_value, 20.0, 0.0001, "offer bundle value aggregates players and picks")
	t.assert_approx(ask_value, 19.0, 0.0001, "ask bundle value aggregates players and picks")
	t.assert_true(TradeValuation.is_trade_acceptable(offer, ask, 1.0), "trade accepts when offer meets ask")

	var weak_offer := {
		"players": [
			{"name": "WR2", "est_value": 10.0}
		],
		"picks": []
	}
	t.assert_true(
		not TradeValuation.is_trade_acceptable(weak_offer, ask, 1.0),
		"trade rejects when offer falls short"
	)
