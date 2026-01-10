extends RefCounted
class_name NamesHelper
## NamesHelper
## - random_full(names_cfg) -> "First Last"
## Supports a few common shapes of names config.

static func _pick_any(arr: Array, fallback: String, rng: RandomNumberGenerator) -> String:
	if arr.is_empty():
		return fallback
	var idx: int = int(rng.randi() % arr.size())
	return String(arr[idx])

static func random_full(names_cfg: Dictionary, rng: RandomNumberGenerator) -> String:
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

	var f := _pick_any(firsts, "Alex", rng)
	var l := _pick_any(lasts,  "Taylor", rng)
	return f + " " + l
