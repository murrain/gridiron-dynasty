# res://scripts/core/trades/PickValueCurve.gd
extends RefCounted
class_name PickValueCurve

const DEFAULT_PATH: String = "res://configs/trades/pick_value_curve.json"

var round_defaults: Dictionary = {}
var slot_values: Dictionary = {}

func _init(config_path: String = DEFAULT_PATH) -> void:
	load_from_path(config_path)

func load_from_path(path: String) -> void:
	round_defaults.clear()
	slot_values.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("PickValueCurve: missing config at " + path)
		return

	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("PickValueCurve: invalid config at " + path)
		return

	var data := parsed as Dictionary
	round_defaults = (data.get("round_defaults", {}) as Dictionary).duplicate(true)
	slot_values = (data.get("slot_values", {}) as Dictionary).duplicate(true)

func get_value(round: int, slot: int) -> float:
	var round_key := str(round)
	var slot_key := str(slot)
	if slot_values.has(round_key):
		var round_map := slot_values[round_key] as Dictionary
		if round_map.has(slot_key):
			return float(round_map[slot_key])
	if round_defaults.has(round_key):
		return float(round_defaults[round_key])
	return 0.0
