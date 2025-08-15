extends Node
# Autoload name: Config

# ---------------------------
# Paths / defaults
# ---------------------------
const DEFAULT_BASE_DIR: String = "res://configs/sports/american_football"
const ENGINE_CFG_PATH: String  = "res://config/engine/engine.json" # project default (read-only at runtime)
const USER_ENGINE_CFG_PATH: String = "user://engine.json"           # user override (writeable)

# ---------------------------
# State
# ---------------------------
var base_dir: String = DEFAULT_BASE_DIR
var save_dir: String = ""     # e.g. "user://saves/slot_001/configs/american_football"
var recurse: bool = false
var engine: Dictionary = {}   # last loaded engine cfg (default+user merge)

# Caches: keyed by "<base>|<save>|<recurse>"
var _cache_all: Dictionary = {}    # { key: { filename => merged_dict } }
var _cache_one: Dictionary = {}    # { key + "|" + name: merged_dict }
var _engine_cache: Dictionary = {} # parsed (default ⊕ user) engine.json cached once

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
	_engine_cache.clear()

# ---------------------------
# Public API (game configs)
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

## Convenience: fetch several configs at once
func require(names: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for n in names:
		var cfg := get_config(n)
		if cfg.is_empty():
			push_error("Config: required config '" + n + "' not found in base/save.")
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
# Engine helpers (threading, etc.)
# ---------------------------

## Read engine config (default + user override) once and cache it.
func engine_cfg() -> Dictionary:
	if not _engine_cache.is_empty():
		return _engine_cache

	# project default
	var def: Dictionary = _load_json_safe(ENGINE_CFG_PATH)

	# user overrides (if present)
	var usr: Dictionary = _load_json_safe(USER_ENGINE_CFG_PATH)

	# user wins
	_engine_cache = (_deep_merge(def, usr) as Dictionary)
	return _engine_cache

## Force-reload engine config from disk (both default and user).
func reload_engine_cfg() -> void:
	_engine_cache.clear()
	engine = engine_cfg()

## Number of worker threads to use. Defaults to 1/core up to 8 when <= 0.
func threads_count() -> int:
	var eg := engine_cfg()
	var val := 0
	if eg.has("threads"):
		val = int(eg["threads"])
	if val <= 0:
		var cores: int = max(1, OS.get_processor_count())
		val = min(cores, 8)
	return val

## Update threads in-memory (runtime only). Call save_engine_threads() to persist.
func set_threads_runtime(n: int) -> void:
	var eg := engine_cfg().duplicate(true)
	eg["threads"] = clamp(n, 1, min(OS.get_processor_count(), 8))
	_engine_cache = eg
	engine = eg

## Persist thread count to user://engine.json and refresh cache.
func save_engine_threads(n: int) -> void:
	var eg := engine_cfg().duplicate(true)
	eg["threads"] = clamp(n, 1, min(OS.get_processor_count(), 8))

	var f := FileAccess.open(USER_ENGINE_CFG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(eg, "\t"))
		f.flush()

	# Refresh live state
	_engine_cache = eg
	engine = eg

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
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	match typeof(parsed):
		TYPE_DICTIONARY:
			return parsed as Dictionary
		TYPE_ARRAY:
			return {"_": parsed}
		_:
			if typeof(parsed) == TYPE_NIL:
				push_warning("Config: JSON parse returned null for " + path)
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
	return b

func _join(base: String, leaf: String) -> String:
	return base + leaf if base.ends_with("/") else base + "/" + leaf

func _ready() -> void:
	# Preload engine config so Config.engine is immediately available
	engine = engine_cfg()
