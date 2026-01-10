# res://scripts/core/trades/TradeDecision.gd
extends RefCounted
class_name TradeDecision

const DEFAULT_PATH: String = "res://configs/trades/trade_rules.json"

var accept_threshold: float = 1.05

func _init(config_path: String = DEFAULT_PATH) -> void:
	load_from_path(config_path)

func load_from_path(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("TradeDecision: missing config at " + path)
		return

	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("TradeDecision: invalid config at " + path)
		return

	var data := parsed as Dictionary
	accept_threshold = float(data.get("accept_threshold", accept_threshold))

## Stub rule: accept if incoming value meets threshold of outgoing value.
func should_accept(incoming_value: float, outgoing_value: float, threshold: float = -1.0) -> bool:
	var use_threshold := threshold
	if use_threshold < 0.0:
		use_threshold = accept_threshold
	if outgoing_value <= 0.0:
		return incoming_value >= 0.0
	return incoming_value >= outgoing_value * use_threshold
