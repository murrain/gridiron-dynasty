# res://helpers/DeAger.gd
extends Node
class_name DeAger

## De-age a player's stats using a category-based stochastic scaler.
## - Stats with "default" in stats_cfg are preserved at that default (not scaled).
## - Category multipliers are sampled per-stat:
##     pct ~ Uniform([pct_min, pct_max]) then jittered by Normal(0, var)
##     final = val * pct; then additive noise ∈ [noise_min, noise_max]; then clamp to [floor, ceil]
## - If only_base_stats is true, skips non-base / derived stats.
## - If keep_existing_defaults is true, will not *force-set* default; it will just skip scaling those stats.
##
## deage_cfg example:
## {
##   "core_stats": ["speed","strength","acceleration","agility","balance","stamina"],
##   "secondary_stats": ["awareness","reaction_time","route_running","coverage"],
##   "core_pct_min": 0.60, "core_pct_max": 0.75, "core_var": 0.10,
##   "secondary_pct_min": 0.50, "secondary_pct_max": 0.70, "secondary_var": 0.15,
##   "other_pct_min": 0.40, "other_pct_max": 0.65, "other_var": 0.20,
##   "noise_min": -3.0, "noise_max": 3.0,
##   "floor": 20.0, "ceil": 100.0,
##   "only_base_stats": true,         # optional (default: false)
##   "keep_existing_defaults": true,  # optional (default: true)
##   "target_age": 18                 # optional
## }
static func de_age(
	player: Dictionary,
	positions: Dictionary,
	deage_cfg: Dictionary,
	stats_cfg: Dictionary
) -> Dictionary:
	var new_player := player.duplicate(true)

	# ---- Build sets for category lookups ----
	var core_set := _to_name_set(deage_cfg.get("core_stats", []))
	var sec_set  := _to_name_set(deage_cfg.get("secondary_stats", []))

	# ---- Pull defaults and (optionally) base/derived classification from stats_cfg ----
	var defaults := {}              # name -> default value
	var base_stat_set := {}         # names where type == "base"
	if stats_cfg.has("stats"):
		for s in stats_cfg["stats"]:
			if s is Dictionary and s.has("name"):
				var n := String(s["name"])
				if s.has("default"):
					defaults[n] = s["default"]
				if s.get("type","") == "base":
					base_stat_set[n] = true

	# ---- Settings ----
	var only_base := bool(deage_cfg.get("only_base_stats", false))
	var keep_existing_defaults := bool(deage_cfg.get("keep_existing_defaults", true))
	var floor_v := float(deage_cfg.get("floor", 0.0))
	var ceil_v  := float(deage_cfg.get("ceil", 100.0))
	var noise_min := float(deage_cfg.get("noise_min", 0.0))
	var noise_max := float(deage_cfg.get("noise_max", 0.0))

	# pct ranges & jitter (std-dev) per category
	var core_rng := Vector2(float(deage_cfg.get("core_pct_min", 0.6)), float(deage_cfg.get("core_pct_max", 0.75)))
	var sec_rng  := Vector2(float(deage_cfg.get("secondary_pct_min", 0.5)), float(deage_cfg.get("secondary_pct_max", 0.7)))
	var oth_rng  := Vector2(float(deage_cfg.get("other_pct_min", 0.4)), float(deage_cfg.get("other_pct_max", 0.65)))

	var core_var := float(deage_cfg.get("core_var", 0.10))
	var sec_var  := float(deage_cfg.get("secondary_var", 0.15))
	var oth_var  := float(deage_cfg.get("other_var", 0.20))

	# RNG
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# ---- Scale stats ----
	if new_player.has("stats"):
		for name in new_player["stats"].keys():
			var stat_name := String(name)

			# Respect defaults from stats_cfg
			if defaults.has(stat_name):
				if keep_existing_defaults:
					# Do not change; it keeps its current (or previously applied) default
					continue
				else:
					# Force to default
					new_player["stats"][stat_name] = defaults[stat_name]
					continue

			# Optionally skip non-base stats
			if only_base and not base_stat_set.has(stat_name):
				continue

			var val = new_player["stats"][stat_name]
			if typeof(val) != TYPE_INT and typeof(val) != TYPE_FLOAT:
				continue

			# Choose category params
			var pct_rng := oth_rng
			var pct_var := oth_var
			if core_set.has(stat_name):
				pct_rng = core_rng
				pct_var = core_var
			elif sec_set.has(stat_name):
				pct_rng = sec_rng
				pct_var = sec_var

			# Sample a base percentage and jitter it
			var base_pct := rng.randf_range(pct_rng.x, pct_rng.y)
			# Normal jitter around 1.0 with std-dev pct_var, then multiply
			var jitter := 1.0 + rng.randfn(0.0, pct_var)
			var pct : float = clamp(base_pct * jitter, 0.0, 1.5)

			# Apply scaling
			var scaled := float(val) * pct

			# Add uniform noise
			if noise_max != 0.0 or noise_min != 0.0:
				scaled += rng.randf_range(noise_min, noise_max)

			# Clamp to configured range
			scaled = clamp(scaled, floor_v, ceil_v)

			new_player["stats"][stat_name] = scaled

	# ---- Optional age change ----
	if deage_cfg.has("target_age"):
		new_player["age"] = int(deage_cfg["target_age"])

	return new_player


static func _to_name_set(arr: Array) -> Dictionary:
	var set := {}
	for v in arr:
		set[String(v)] = true
	return set