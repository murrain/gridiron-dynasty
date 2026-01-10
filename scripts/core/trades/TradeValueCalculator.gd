# res://scripts/core/trades/TradeValueCalculator.gd
extends RefCounted
class_name TradeValueCalculator

var pick_curve: PickValueCurve

func _init(p_pick_curve: PickValueCurve = null) -> void:
	pick_curve = p_pick_curve if p_pick_curve != null else PickValueCurve.new()

## Sums player values and pick values. RNG is intentionally not used.
func value_offer(offer: TradeOffer, player_values: Dictionary) -> Dictionary:
	return {
		"send": value_bundle(offer.get_bundle(true), player_values),
		"receive": value_bundle(offer.get_bundle(false), player_values)
	}

func value_bundle(bundle: Dictionary, player_values: Dictionary) -> float:
	var total := 0.0
	total += value_players(bundle.get("player_ids", []), player_values)
	total += value_picks(bundle.get("picks", []))
	return total

func value_players(player_ids: Array, player_values: Dictionary) -> float:
	var total := 0.0
	for player_id in player_ids:
		if player_values.has(player_id):
			total += float(player_values[player_id])
	return total

func value_picks(picks: Array) -> float:
	if pick_curve == null:
		return 0.0
	var total := 0.0
	for pick in picks:
		total += pick_curve.get_value_for_pick(pick)
	return total
