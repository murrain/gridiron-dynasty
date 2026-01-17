## PlayerGenerator: builds a recruiting class with multi-threaded fan-out.
##
## Public fields expected to be set by caller:
## - main_cfg: Dictionary
## - positions_data: Dictionary
## - stats_cfg: Dictionary
## - names_cfg: Dictionary
## - class_rules: Dictionary
## - combine_tests: Dictionary
## - combine_tuning: Dictionary
##
## Key methods:
## - generate_class(count, gaussian_share, rng)  -> Array[Dictionary]
##   Uses App.threads_count() inside and parallelizes per-player creation.
##
## Example:
## [codeblock]
## var gen = PlayerGenerator.new()
## gen.positions_data = App.cfg("football/positions")
## gen.stats_cfg = App.cfg("football/stats")
## var rng = RandomNumberGenerator.new()
## rng.seed = 1234
## var players = gen.generate_class(2000, 0.75, rng)
## [/codeblock]
extends RefCounted
class_name PlayerGenerator

const Rand = preload("res://autoloads/Rand.gd")
const ThreadPool = preload("res://autoloads/ThreadPool.gd")
const CombineCalculator = preload("res://scripts/core/rating/CombineCalculator.gd")
const DeAger = preload("res://scripts/generation/helpers/DeAger.gd")
const NamesHelper = preload("res://scripts/generation/helpers/NamesHelper.gd")
const PositionHelper = preload("res://scripts/generation/helpers/PositionHelper.gd")
const PhysicalsHelper = preload("res://scripts/generation/helpers/PhysicalsHelper.gd")
const StatsHelper = preload("res://scripts/generation/helpers/StatsHelper.gd")

var main_cfg: Dictionary
var positions_data: Dictionary
var stats_cfg: Dictionary
var names_cfg: Dictionary
var class_rules: Dictionary
var combine_tests: Dictionary
var combine_tuning: Dictionary

## Generate a full class of `count` players, threading per-player creation.
func generate_class(count: int, gaussian_share: float, rng: RandomNumberGenerator) -> Array:
	var threads :int = _threads_count()
	var seeds = _derive_seeds(count, rng, 0x9E3779B1)

	var result = ThreadPool.map(
		seeds,
		func(seed_val):
			var local_rng = RandomNumberGenerator.new()
			local_rng.seed = int(seed_val)
			return _make_single_player(gaussian_share, local_rng),
		threads
	)

	# Calculate combine numbers (can be done in parallel too)
	var combine_seeds = _derive_seeds(result.size(), rng, 0x85EBCA6B)

	var combine_items: Array = []
	combine_items.resize(result.size())
	for i in result.size():
		combine_items[i] = {"player": result[i], "seed": combine_seeds[i]}

	var combine_callable = func(item):
		var p: Dictionary = item["player"]
		var local_rng = RandomNumberGenerator.new()
		local_rng.seed = int(item["seed"])
		p["combine"] = CombineCalculator.compute_all(p, combine_tuning, combine_tests, local_rng)
		return p
	result = ThreadPool.map(combine_items, combine_callable, threads)
	return result

## Creates one player (pure function w.r.t. shared state).
## Implements 80/20 split: 80% templated (position-first), 20% chaos (stats-first).
##
## RNG CONSUMPTION PATTERN:
##   - 1 randf() call to determine generation mode
##   - 1 call for name generation
##   - Then either:
##     - TEMPLATED: position pick -> physicals -> stats (position-guided distributions)
##     - CHAOS: uniform stats -> best-fit position -> viability check -> physicals
##
## This creates diverse player pools with predictable archetypes (80%) and
## occasional emergent oddballs (20%) who may excel in unexpected ways.
const CHAOS_GENERATION_PROBABILITY = 0.20

func _make_single_player(gaussian_share: float, rng: RandomNumberGenerator) -> Dictionary:
	var p: Dictionary = {}

	# RNG: 1 call to determine generation mode (consumed before branching)
	var generation_mode_roll = rng.randf()
	var use_chaos = generation_mode_roll < CHAOS_GENERATION_PROBABILITY

	# Name is generated the same way regardless of mode
	p["name"] = NamesHelper.random_full(names_cfg, rng)

	if use_chaos:
		# CHAOS MODE: Generate stats first with uniform distribution,
		# then find best-fit position based on core stat scores.
		var all_stats = _get_all_stat_names()
		var result = StatsHelper.generate_chaos_player(all_stats, positions_data, rng)
		p["position"] = result["position"]
		p["stats"] = result["stats"]
		p["generation_mode"] = "chaos"
		# Generate physicals for the determined position
		p["physicals"] = PhysicalsHelper.roll_for_position(p["position"], positions_data, rng)
	else:
		# TEMPLATED MODE: Position first, then stats guided by position distributions.
		p["position"] = PositionHelper.pick_position(positions_data, class_rules, rng)
		p["physicals"] = PhysicalsHelper.roll_for_position(p["position"], positions_data, rng)
		p["stats"] = StatsHelper.roll_all(stats_cfg, p["position"], positions_data, gaussian_share, rng)
		p["generation_mode"] = "templated"

	StatsHelper.apply_defaults(p["stats"], stats_cfg, true)
	p["tags"] = []
	p["wear"] = {"snaps": 0, "collisions": 0, "injury_count": 0}
	p["development_report"] = []
	return p

## Get all stat names from stats_cfg, sorted for deterministic iteration.
## Excludes derived stats (type == "derived") since those are calculated, not rolled.
func _get_all_stat_names() -> Array:
	var names = []
	var stats_list = stats_cfg.get("stats", []) as Array
	for stat_def in stats_list:
		if stat_def is Dictionary and stat_def.has("name"):
			# Skip derived stats - they're computed from other stats
			var stat_type = stat_def.get("type", "base")
			if stat_type != "derived":
				names.append(stat_def["name"])
	names.sort()  # CRITICAL for determinism
	return names

## De-age a class to HS year 1 (threaded wrapper).
func de_age_players(
	players: Array,
	positions: Dictionary,
	deage_cfg: Dictionary,
	stats_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var threads = _threads_count()
	var seeds = _derive_seeds(players.size(), rng, 0x6C8E9CF5)
	var items: Array = []
	items.resize(players.size())
	for i in range(players.size()):
		items[i] = {"player": players[i], "seed": seeds[i]}

	var deaged = ThreadPool.map(items, func(item):
		var rng_local = RandomNumberGenerator.new()
		rng_local.seed = int(item["seed"])
		return DeAger.de_age(item["player"], positions, deage_cfg, stats_cfg, rng_local),
		threads
	)

	for i in players.size():
		players[i] = deaged[i]

# Add somewhere in PlayerGenerator.gd (e.g., below generate_class)
# Selects up to `max_freaks` athletes in a percentile band and gives them a small athletic bump + tag.
func assign_dynamic_freaks(
	players: Array,
	max_freaks: int,
	pct_min: float,
	pct_max: float,
	rng: RandomNumberGenerator
) -> void:
	if players.is_empty() or max_freaks <= 0:
		return

	# Conservative guardrails
	pct_min = clamp(pct_min, 0.0, 1.0)
	pct_max = clamp(pct_max, 0.0, 1.0)
	if pct_max < pct_min:
		var t = pct_min
		pct_min = pct_max
		pct_max = t

	var ATH_KEYS: Array = [
		"speed","acceleration","agility","balance","vertical_jump","broad_jump","strength"
	]

	# 1) Build simple athletic score per player (avg of present keys)
	var scores: Array = []  # Array of { idx:int, score:float }
	scores.resize(players.size())
	for i in players.size():
		var p: Dictionary = players[i]
		var stats: Dictionary = p.get("stats", {}) as Dictionary
		var s = 0.0
		var n = 0
		for k in ATH_KEYS:
			if stats.has(k):
				s += float(stats[k])
				n += 1
		var score = (s / float(n)) if n > 0 else 0.0
		scores[i] = {"idx": i, "score": score}

	# 2) Sort and compute percentile band
	scores.sort_custom(func(a, b):
		return float((a as Dictionary).score) < float((b as Dictionary).score) # ascending
	)

	var n = scores.size()
	if n == 0:
		return

	var lo_i = int(floor(pct_min * float(max(0, n - 1))))
	var hi_i = int(floor(pct_max * float(max(0, n - 1))))
	hi_i = max(lo_i, hi_i)

	# 3) Collect candidates in [lo_i .. hi_i]
	var cand: Array = []
	for j in range(lo_i, hi_i + 1):
		cand.append(scores[j])

	# Prefer non-specialists (skip K/P)
	cand = cand.filter(func(e):
		var p: Dictionary = players[int((e as Dictionary).idx)]
		var pos = String(p.get("position",""))
		return pos != "K" and pos != "P"
	)

	# 4) Shuffle and take up to max_freaks
	_shuffle_in_place(cand, rng)
	var take : int = min(max_freaks, cand.size())

	# 5) Apply small athletic “freak” bump + tag
	for k in range(take):
		var idx = int((cand[k] as Dictionary).idx)
		var pl: Dictionary = players[idx]
		var st: Dictionary = pl.get("stats", {}) as Dictionary

		# Gentle, believable bump (3–7 pts) with a bit less for strength by default
		for ak in ATH_KEYS:
			if st.has(ak):
				var add = rng.randf_range(3.0, 7.0)
				if ak == "strength":
					add = rng.randf_range(2.0, 5.0)
				st[ak] = clamp(float(st[ak]) + add, 0.0, 100.0)

		# Flag it
		if not pl.has("tags"):
			pl["tags"] = []
		var tags = pl["tags"] as Array
		if not tags.has("PotentialSuperstar"):
			tags.append("PotentialSuperstar")

		pl["stats"] = st
		players[idx] = pl

func _derive_seeds(count: int, rng: RandomNumberGenerator, salt: int) -> Array:
	var seeds: Array = []
	seeds.resize(count)
	for i in count:
		# derived seeds prevent RNG contention in threaded paths
		var mixed = Rand.splitmix64(int(rng.randi()) ^ int(i * salt))
		seeds[i] = mixed
	return seeds

func _shuffle_in_place(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

func _threads_count() -> int:
	var app = _resolve_autoload("App")
	if app == null:
		return 1
	return int(app.threads_count())

func _resolve_autoload(name: String) -> Object:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var root = (main_loop as SceneTree).root
		if root.has_node(name):
			return root.get_node(name)
	return null

## Save to JSON on disk (single-threaded I/O).
func save_to_json(path: String, players: Array) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(players, "\t"))
	f.close()
