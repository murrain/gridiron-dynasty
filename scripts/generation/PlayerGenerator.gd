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
## - generate_class(count, gaussian_share)  -> Array[Dictionary]
##   Uses App.threads_count() inside and parallelizes per-player creation.
##
## Example:
## [codeblock]
## var gen := PlayerGenerator.new()
## gen.positions_data = App.cfg("football/positions")
## gen.stats_cfg = App.cfg("football/stats")
## var players := gen.generate_class(2000, 0.75)
## [/codeblock]
extends RefCounted
class_name PlayerGenerator

var main_cfg: Dictionary
var positions_data: Dictionary
var stats_cfg: Dictionary
var names_cfg: Dictionary
var class_rules: Dictionary
var combine_tests: Dictionary
var combine_tuning: Dictionary

## Generate a full class of `count` players, threading per-player creation.
func generate_class(count: int, gaussian_share: float) -> Array:
	var threads :int = App.threads_count()
	var seeds: Array = []
	seeds.resize(count)
	for i in count:
		# deterministic seeds per index prevents RNG contention
		seeds[i] = randi() ^ (i * 0x9E3779B1)

	var result := ThreadPool.map(
		seeds,
		func(seed_val):
			seed(int(seed_val))
			return _make_single_player(gaussian_share),
		threads
	)

	# Calculate combine numbers (can be done in parallel too)
	var combine_callable := func(p):
		p["combine"] = CombineCalculator.compute_all(p, combine_tuning, combine_tests)
		return p
	result = ThreadPool.map(result, combine_callable, threads)
	return result

## Creates one player (pure function w.r.t. shared state).
## Fill in your existing logic (position pick, stats, tags, etc.).
func _make_single_player(gaussian_share: float) -> Dictionary:
	var p: Dictionary = {}
	# … your existing player creation steps …
	# Required skeleton fields:
	p["name"] = NamesHelper.random_full(names_cfg)
	p["position"] = PositionHelper.pick_position(positions_data, class_rules)
	p["physicals"] = PhysicalsHelper.roll_for_position(p["position"], positions_data)
	p["stats"] = StatsHelper.roll_all(stats_cfg, p["position"], positions_data, gaussian_share)
	p["tags"] = []
	return p

## De-age a class to HS year 1 (threaded wrapper).
func de_age_players(players: Array, positions: Dictionary, deage_cfg: Dictionary) -> void:
	var threads := App.threads_count()
	var deaged := ThreadPool.map(players, func(p):
		return DeAger.de_age(p, positions, deage_cfg)
	, threads)
	for i in players.size():
		players[i] = deaged[i]

# Add somewhere in PlayerGenerator.gd (e.g., below generate_class)
# Selects up to `max_freaks` athletes in a percentile band and gives them a small athletic bump + tag.
func assign_dynamic_freaks(players: Array, max_freaks: int, pct_min: float, pct_max: float) -> void:
	if players.is_empty() or max_freaks <= 0:
		return

	# Conservative guardrails
	pct_min = clamp(pct_min, 0.0, 1.0)
	pct_max = clamp(pct_max, 0.0, 1.0)
	if pct_max < pct_min:
		var t := pct_min
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
		var s := 0.0
		var n := 0
		for k in ATH_KEYS:
			if stats.has(k):
				s += float(stats[k])
				n += 1
		var score := (s / float(n)) if n > 0 else 0.0
		scores[i] = {"idx": i, "score": score}

	# 2) Sort and compute percentile band
	scores.sort_custom(func(a, b):
		return float((a as Dictionary).score) < float((b as Dictionary).score) # ascending
	)

	var n := scores.size()
	if n == 0:
		return

	var lo_i := int(floor(pct_min * float(max(0, n - 1))))
	var hi_i := int(floor(pct_max * float(max(0, n - 1))))
	hi_i = max(lo_i, hi_i)

	# 3) Collect candidates in [lo_i .. hi_i]
	var cand: Array = []
	for j in range(lo_i, hi_i + 1):
		cand.append(scores[j])

	# Prefer non-specialists (skip K/P)
	cand = cand.filter(func(e):
		var p: Dictionary = players[int((e as Dictionary).idx)]
		var pos := String(p.get("position",""))
		return pos != "K" and pos != "P"
	)

	# 4) Shuffle and take up to max_freaks
	cand.shuffle()
	var take : int = min(max_freaks, cand.size())

	# 5) Apply small athletic “freak” bump + tag
	for k in range(take):
		var idx := int((cand[k] as Dictionary).idx)
		var pl: Dictionary = players[idx]
		var st: Dictionary = pl.get("stats", {}) as Dictionary

		# Gentle, believable bump (3–7 pts) with a bit less for strength by default
		for ak in ATH_KEYS:
			if st.has(ak):
				var add := randf_range(3.0, 7.0)
				if ak == "strength":
					add = randf_range(2.0, 5.0)
				st[ak] = clamp(float(st[ak]) + add, 0.0, 100.0)

		# Flag it
		if not pl.has("tags"):
			pl["tags"] = []
		var tags := pl["tags"] as Array
		if not tags.has("PotentialSuperstar"):
			tags.append("PotentialSuperstar")

		pl["stats"] = st
		players[idx] = pl

## Save to JSON on disk (single-threaded I/O).
func save_to_json(path: String, players: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(players, "\t"))
	f.close()
