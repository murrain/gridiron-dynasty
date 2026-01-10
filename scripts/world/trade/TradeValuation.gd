# res://scripts/world/trade/TradeValuation.gd
extends RefCounted

const DEFAULT_RULES_PATH := "res://configs/trades/trade_rules.json"
const DEFAULT_THRESHOLD := 1.05

## Evaluates a trade offer using explicit, deterministic context inputs.
##
## offer format:
## {
##   "incoming": {"players": [{"id": "p1", "position": "QB"}], "picks": [{"round": 1, "slot": 1}]},
##   "outgoing": {"players": [...], "picks": [...]}
## }
##
## context format:
## {
##   "player_values": {"p1": 1200.0},
##   "pick_value_curve": {"1/1": 1000.0, "2/1": 600.0},
##   "team_needs": {"QB": 1.2, "WR": 1.0},
##   "cap_context": {"max_increase": 15.0}, # optional
##   "threshold": 1.05 # optional override of config
## }
static func evaluate_offer(offer: Dictionary, context: Dictionary) -> Dictionary:
	var incoming_bundle := offer.get("incoming", {}) as Dictionary
	var outgoing_bundle := offer.get("outgoing", {}) as Dictionary
	var threshold := _resolve_threshold(context)
	var incoming_value := _bundle_value(incoming_bundle, context)
	var outgoing_value := _bundle_value(outgoing_bundle, context)
	var accept := _should_accept(incoming_value, outgoing_value, threshold)

	return {
		"incoming_value": incoming_value,
		"outgoing_value": outgoing_value,
		"threshold": threshold,
		"accept": accept
	}

static func _bundle_value(bundle: Dictionary, context: Dictionary) -> float:
	var player_values := context.get("player_values", {}) as Dictionary
	var team_needs := context.get("team_needs", {}) as Dictionary
	var pick_curve := context.get("pick_value_curve", {}) as Dictionary
	var total := 0.0

	for player in bundle.get("players", []) as Array:
		total += _player_value(player, player_values, team_needs)
	for pick in bundle.get("picks", []) as Array:
		total += _pick_value(pick, pick_curve)

	return total

static func _player_value(player: Variant, player_values: Dictionary, team_needs: Dictionary) -> float:
	var player_id := ""
	var position := ""
	if typeof(player) == TYPE_DICTIONARY:
		var player_dict := player as Dictionary
		player_id = str(player_dict.get("id", ""))
		position = str(player_dict.get("position", ""))
	else:
		player_id = str(player)

	var base_value := float(player_values.get(player_id, 0.0))
	var weight := float(team_needs.get(position, 1.0))
	return base_value * weight

static func _pick_value(pick: Variant, pick_curve: Dictionary) -> float:
	if typeof(pick) != TYPE_DICTIONARY:
		return 0.0
	var pick_dict := pick as Dictionary
	var round := int(pick_dict.get("round", 0))
	var slot := int(pick_dict.get("slot", 0))
	var key := str(round) + "/" + str(slot)

	if pick_curve.has(key):
		return float(pick_curve[key])

	var round_key := str(round)
	var slot_key := str(slot)
	if pick_curve.has(round_key):
		var round_map := pick_curve[round_key]
		if typeof(round_map) == TYPE_DICTIONARY:
			var round_dict := round_map as Dictionary
			if round_dict.has(slot_key):
				return float(round_dict[slot_key])

	if pick_curve.has("slot_values"):
		var slot_values := pick_curve["slot_values"]
		if typeof(slot_values) == TYPE_DICTIONARY:
			var slot_dict := slot_values as Dictionary
			if slot_dict.has(round_key):
				var round_slots := slot_dict[round_key]
				if typeof(round_slots) == TYPE_DICTIONARY:
					var round_slots_dict := round_slots as Dictionary
					if round_slots_dict.has(slot_key):
						return float(round_slots_dict[slot_key])

	if pick_curve.has("round_defaults"):
		var defaults := pick_curve["round_defaults"]
		if typeof(defaults) == TYPE_DICTIONARY:
			var defaults_dict := defaults as Dictionary
			if defaults_dict.has(round_key):
				return float(defaults_dict[round_key])

	return 0.0

static func _resolve_threshold(context: Dictionary) -> float:
	if context.has("threshold"):
		return float(context["threshold"])
	return _load_threshold(DEFAULT_RULES_PATH)

static func _load_threshold(path: String) -> float:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("TradeValuation: missing config at " + path)
		return DEFAULT_THRESHOLD

	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("TradeValuation: invalid config at " + path)
		return DEFAULT_THRESHOLD

	var data := parsed as Dictionary
	return float(data.get("accept_threshold", DEFAULT_THRESHOLD))

static func _should_accept(incoming_value: float, outgoing_value: float, threshold: float) -> bool:
	if outgoing_value <= 0.0:
		return incoming_value >= 0.0
	return incoming_value >= outgoing_value * threshold
