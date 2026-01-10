# res://scripts/core/trades/TradeValueCalculator.gd
extends RefCounted
class_name TradeValueCalculator

var pick_curve: PickValueCurve

func _init(p_pick_curve: PickValueCurve = null) -> void:
	pick_curve = p_pick_curve if p_pick_curve != null else PickValueCurve.new()

## Sums player values and pick values. RNG is intentionally not used.
func value_offer(
	offer: Dictionary,
	player_values: Dictionary,
	pick_data_by_id: Dictionary = {}
) -> Dictionary:
	var send_bundle: Dictionary = offer.get("send", {}) as Dictionary
	var receive_bundle: Dictionary = offer.get("receive", {}) as Dictionary
	return {
		"send": value_bundle(send_bundle, player_values, pick_data_by_id),
		"receive": value_bundle(receive_bundle, player_values, pick_data_by_id)
	}

func value_bundle(
	bundle: Dictionary,
	player_values: Dictionary,
	pick_data_by_id: Dictionary
) -> float:
	var total := 0.0
	total += value_players(bundle.get("players", []), player_values)
	total += value_picks(bundle.get("picks", []), pick_data_by_id)
	return total

func value_players(player_ids: Array, player_values: Dictionary) -> float:
	var total := 0.0
	for player_id in player_ids:
		if player_values.has(player_id):
			total += float(player_values[player_id])
	return total

func value_picks(picks: Array, pick_data_by_id: Dictionary) -> float:
	if pick_curve == null:
		return 0.0
	var total := 0.0
	for pick in picks:
		var pick_dict: Dictionary = {}
		if pick is Dictionary:
			pick_dict = pick as Dictionary
		else:
			var pick_id := String(pick)
			if pick_data_by_id.has(pick_id):
				pick_dict = pick_data_by_id[pick_id] as Dictionary
		var round := int(pick_dict.get("round", 0))
		var slot := int(pick_dict.get("slot", 0))
		total += pick_curve.get_value(round, slot)
	return total
