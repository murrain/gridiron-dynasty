extends Node
class_name ConfigLoader

## Default sport config root (adjust if you move it)
const DEFAULT_BASE_DIR: String = "res://configs/sports/american_football"

## State
var base_dir: String = DEFAULT_BASE_DIR
var save_dir: String = ""          # e.g. "user://saves/slot_001/configs/american_football"
var recurse: bool = false

# Caches: keyed by "<base>|<save>|<recurse>"
var _cache_all: Dictionary = {}    # { key: { filename => merged_dict } }
var _cache_one: Dictionary = {}    # { key + "|" + name: merged_dict }

# ---------------------------
# Setup / control
# ---------------------------

func configure(p_base_dir: String = DEFAULT_BASE_DIR, p_save_dir: String = "", p_recurse: bool = false) -> void:
	base_dir = p_base_dir
	save_dir = p_save_dir
	recurse = p_recurse
	clear_cache()

func set_base_dir(p_base_dir: String) -> void:
	base_dir = p_base_dir
	clear_cache()

func set_save_dir(p_save_dir: String) -> void:
	save_dir = p_save_dir
	clear_cache()

func set_recurse(p_recurse: bool) -> void:
	recurse = p_recurse
	clear_cache()

func clear_cache() -> void:
	_cache_all.clear()
	_cache_one.clear()

# ---------------------------
# Public API
# ---------------------------

## Get a merged map of ALL jsons in base/save (save wins), keyed by filename without ".json"
func get_all() -> Dictionary:
	var key := _key()
	if _cache_all.has(key):
		return _cache_all[key]
	var base_map := _load_dir_as_map(base_dir, recurse)
	var merged := base_map.duplicate(true)

	if save_dir != "" and DirAccess.dir_exists_absolute(save_dir):
		var over_map := _load_dir_as_map(save_dir, recurse)
		for k in over_map.keys():
			if merged.has(k):
				merged[k] = _deep_merge(merged[k], over_map[k])
			else:
				merged[k] = over_map[k]

	_cache_all[key] = merged
	return merged

## Get a single merged config by filename (without .json), e.g. "main", "positions", "stats"
func get_config(name: String) -> Dictionary:
	var k := _key() + "|" + name
	if _cache_one.has(k):
		return _cache_one[k]

	var base_one := _load_json_safe(_join(base_dir, name + ".json"))
	var out := base_one
	if save_dir != "":
		var over_one := _load_json_safe(_join(save_dir, name + ".json"))
		if over_one.size() > 0:
			out = _deep_merge(base_one, over_one)

	_cache_one[k] = out
	return out

## Convenience: fetch several configs at once; if any are missing, logs an error and returns what’s available.
func require(names: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for n in names:
		var cfg := get_config(n)
		if cfg.is_empty():
			push_error("ConfigLoader: required config '" + n + "' not found in base/save.")
		out[n] = cfg
	return out

## List available file keys in base and save (merged list)
func list_keys() -> Array[String]:
	var all := get_all()
	var keys: Array[String] = []
	for k in all.keys():
		keys.append(String(k))
	keys.sort()
	return keys

# ---------------------------
# Internals
# ---------------------------

func _key() -> String:
	return base_dir + "|" + save_dir + "|" + str(recurse)

func _load_dir_as_map(dir_path: String, p_recurse: bool) -> Dictionary:
	var out: Dictionary = {}
	if dir_path == "" or not DirAccess.dir_exists_absolute(dir_path):
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var full := _join(dir_path, entry)
		if dir.current_is_dir():
			if p_recurse:
				var sub_map := _load_dir_as_map(full, p_recurse)
				for k in sub_map.keys():
					out[k] = sub_map[k]
		else:
			if entry.to_lower().ends_with(".json"):
				var key := entry.substr(0, entry.length() - 5) # strip ".json"
				out[key] = _load_json_safe(full)
	dir.list_dir_end()
	return out

func _load_json_safe(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text) # Explicit type annotation

	match typeof(parsed):
		TYPE_DICTIONARY:
			return parsed as Dictionary
		TYPE_ARRAY:
			# Wrap array in a dict so API stays consistent
			return {"_": parsed}
		_:
			if typeof(parsed) == TYPE_NIL:
				push_warning("ConfigLoader: JSON parse returned null for " + path)
			return {}

func _deep_merge(a: Variant, b: Variant) -> Variant:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var res := (a as Dictionary).duplicate(true)
		for k in (b as Dictionary).keys():
			if res.has(k):
				res[k] = _deep_merge(res[k], b[k])
			else:
				res[k] = b[k]
		return res
	# Policy: arrays & scalars -> b wins
	return b

func _join(base: String, leaf: String) -> String:
	if base.ends_with("/"):
		return base + leaf
	return base + "/" + leaf
