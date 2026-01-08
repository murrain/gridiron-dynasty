extends RefCounted
class_name NamesHelper
## NamesHelper
## - random_full(names_cfg) -> "First Last"
## Supports a few common shapes of names config.

static func _pick_any(arr: Array, fallback: String) -> String:
	return String(arr[randi() % max(1, arr.size())]) if not arr.is_empty() else fallback

static func random_full(names_cfg: Dictionary) -> String:
	var firsts: Array = []
	var lasts: Array = []
	# Try several common keys
	if names_cfg.has("first_names"):
		firsts = names_cfg["first_names"]
	elif names_cfg.has("first"):
		firsts = names_cfg["first"]
	elif names_cfg.has("male_first_names"):
		firsts = names_cfg["male_first_names"]
	elif names_cfg.has("female_first_names"):
		firsts = names_cfg["female_first_names"]

	if names_cfg.has("last_names"):
		lasts = names_cfg["last_names"]
	elif names_cfg.has("last"):
		lasts = names_cfg["last"]

	var f := _pick_any(firsts, "Alex")
	var l := _pick_any(lasts,  "Taylor")
	return f + " " + l