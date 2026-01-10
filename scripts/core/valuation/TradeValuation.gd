extends RefCounted
class_name TradeValuation

static func bundle_value(bundle: Dictionary) -> float:
	var total := 0.0
	for player in bundle.get("players", []) as Array:
		var row: Dictionary = player as Dictionary
		total += float(row.get("est_value", 0.0))
	for pick in bundle.get("picks", []) as Array:
		var pick_row: Dictionary = pick as Dictionary
		total += float(pick_row.get("est_value", 0.0))
	return total

static func is_trade_acceptable(offer: Dictionary, ask: Dictionary, min_ratio: float = 1.0) -> bool:
	var offer_value := bundle_value(offer)
	var ask_value := bundle_value(ask)
	if ask_value <= 0.0:
		return offer_value >= 0.0
	return offer_value >= ask_value * min_ratio
