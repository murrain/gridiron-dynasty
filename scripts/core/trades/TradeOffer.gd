@icon("res://icon.svg")
# res://scripts/core/trades/TradeOffer.gd
extends Resource
class_name TradeOffer

## Trade offer with explicit send/receive bundles.
## Pick descriptors are dictionaries with keys: year, round, slot.
@export var send_player_ids: Array[String] = []
@export var send_picks: Array[Dictionary] = []
@export var receive_player_ids: Array[String] = []
@export var receive_picks: Array[Dictionary] = []

func get_bundle(is_send: bool) -> Dictionary:
	if is_send:
		return {
			"player_ids": send_player_ids.duplicate(),
			"picks": send_picks.duplicate(true)
		}
	return {
		"player_ids": receive_player_ids.duplicate(),
		"picks": receive_picks.duplicate(true)
	}
