extends Node
class_name ScoutFactory

var stats_cfg: Dictionary
var scouts_cfg: Dictionary

func setup(stats_cfg_in: Dictionary, scouts_cfg_in: Dictionary) -> void:
	stats_cfg = stats_cfg_in
	scouts_cfg = scouts_cfg_in

func create_random_scout(name_hint: String = "Regional Scout") -> Resource:
	var s := Scout.new()
	s.name = name_hint
	s.years_exp = randi_range(3, 15)

	var gen := scouts_cfg.get("generation", {})
	var defs := scouts_cfg.get("defaults", {})
	var spec := defs.get("specialty", {})

	# Base traits
	s.base_skill = _rand_clip(gen.get("skill_distributions", {}).get("base_skill", {"mu":0.55,"sigma":0.12,"min":0.3,"max":0.85}))
	s.overrate_athletes = _rand_clip(gen.get("skill_distributions", {}).get("overrate_athletes", {"mu":0.0,"sigma":0.25,"min":-0.8,"max":0.8}))
	s.tape_grinder = _rand_clip(gen.get("skill_distributions", {}).get("tape_grinder", {"mu":0.3,"sigma":0.2,"min":0.0,"max":1.0}))
	s.risk_aversion = _rand_clip(gen.get("skill_distributions", {}).get("risk_aversion", {"mu":0.1,"sigma":0.1,"min":0.0,"max":0.6}))

	# Build specialty candidate pool from stats.json using thresholds
	var excl_easy_at := float(spec.get("exclude_easy_at", 0.80))
	var prefer_hard_at := float(spec.get("prefer_hard_at", 0.40))
	var alpha := float(spec.get("weight_alpha", 1.25))
	var w_floor := float(spec.get("weight_floor", 0.01))

	var meas := {} # {stat: m}
	var pool: Array = []  # [ {"name":stat, "m":m, "w":weight}, ... ]
	for sd in stats_cfg.get("stats", []):
		var d: Dictionary = sd
		var stat := String(d.get("name",""))
		var m := float(d.get("measurement_difficulty", 0.5))
		meas[stat] = m
		# exclude trivially easy stats from specialties
		if m >= excl_easy_at:
			continue
		var w := pow(max(0.0, 1.0 - m), alpha)
		if m <= prefer_hard_at:
			# Optionally give a small bump to truly hard stats
			w *= 1.25
		w = max(w, w_floor)
		pool.append({ "name": stat, "m": m, "w": w })

	# Choose number of specialties
	var nmin := int(spec.get("num_min", 2))
	var nmax := int(spec.get("num_max", 4))
	var want := randi_range(nmin, nmax)
	var chosen := _weighted_sample_no_replacement(pool, want)

	# Assign per-stat skills
	var sp_min := float(spec.get("skill_for_specialty_min", 0.80))
	var sp_max := float(spec.get("skill_for_specialty_max", 0.90))
	var ns_min := float(spec.get("skill_for_non_specialty_min", 0.45))
	var ns_max := float(spec.get("skill_for_non_specialty_max", 0.65))
	s.stat_skill = {}
	var specialty_set := {}
	for it in chosen:
		s.stat_skill[it["name"]] = randf_range(sp_min, sp_max)
		specialty_set[it["name"]] = true
	# Optionally give baseline skills to the rest
	for sd in stats_cfg.get("stats", []):
		var nm := String((sd as Dictionary).get("name",""))
		if specialty_set.has(nm): continue
		s.stat_skill[nm] = randf_range(ns_min, ns_max)

	# Set up per-stat bias envelopes from generation settings (optional)
	var bdist := gen.get("bias_distributions", {})
	var mean_mu := float(bdist.get("mean_points_mu", 0.0))
	var mean_sd := float(bdist.get("mean_points_sigma", 0.8))
	var sig_mu := float(bdist.get("sigma_points_mu", 0.8))
	var sig_sd := float(bdist.get("sigma_points_sigma", 0.4))
	var clamp_min := float(bdist.get("clamp_min", -6.0))
	var clamp_max := float(bdist.get("clamp_max", 6.0))

	s.stat_bias_mean = {}
	s.stat_bias_sigma = {}
	for it in chosen:
		var st := String(it["name"])
		# draw mild per-stat tendencies
		var mu := clamp(mean_mu + randfn(0.0, mean_sd), clamp_min, clamp_max)
		var sg := max(0.1, sig_mu + randfn(0.0, sig_sd))
		s.stat_bias_mean[st] = mu
		s.stat_bias_sigma[st] = sg

	# Initialize meas cache and context in the Scout for later use
	s.setup(stats_cfg, {"sigma_min":1.0,"sigma_max":12.0,"quality_floor":0.15,"bounded_min":0.0,"bounded_max":100.0})

	return s

# --- helpers ---

func _rand_clip(dist: Dictionary) -> float:
	var mu := float(dist.get("mu", 0.5))
	var sd := float(dist.get("sigma", 0.1))
	var mn := float(dist.get("min", 0.0))
	var mx := float(dist.get("max", 1.0))
	return clamp(mu + randfn(0.0, sd), mn, mx)

func _weighted_sample_no_replacement(items: Array, k: int) -> Array:
	var picked: Array = []
	var pool := items.duplicate()
	for i in range(min(k, pool.size())):
		var total := 0.0
		for it in pool: total += float(it["w"])
		if total <= 0.0:
			picked.append(pool.pop_back())
			continue
		var r := randf() * total
		var acc := 0.0
		var idx := 0
		for j in range(pool.size()):
			acc += float(pool[j]["w"])
			if r <= acc:
				idx = j
				break
		picked.append(pool[idx])
		pool.remove_at(idx)
	return picked