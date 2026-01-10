extends Node
class_name ScoutFactory

var stats_cfg: Dictionary
var scouts_cfg: Dictionary
const _MULT_MIN: float = 0.5
const _MULT_MAX: float = 1.5

func setup(stats_cfg_in: Dictionary, scouts_cfg_in: Dictionary) -> void:
	stats_cfg = stats_cfg_in
	scouts_cfg = scouts_cfg_in

func create_random_scout(name_hint: String, rng: RandomNumberGenerator) -> Resource:
	var s := Scout.new()
	s.name = name_hint
	s.years_exp = rng.randi_range(3, 15)

	var gen := scouts_cfg.get("generation", {})
	var defs := scouts_cfg.get("defaults", {})
	var spec := defs.get("specialty", {})

	# Base traits
	s.base_skill = _rand_clip(gen.get("skill_distributions", {}).get("base_skill", {"mu":0.55,"sigma":0.12,"min":0.3,"max":0.85}), rng)
	s.overrate_athletes = _rand_clip(gen.get("skill_distributions", {}).get("overrate_athletes", {"mu":0.0,"sigma":0.25,"min":-0.8,"max":0.8}), rng)
	s.tape_grinder = _rand_clip(gen.get("skill_distributions", {}).get("tape_grinder", {"mu":0.3,"sigma":0.2,"min":0.0,"max":1.0}), rng)
	s.risk_aversion = _rand_clip(gen.get("skill_distributions", {}).get("risk_aversion", {"mu":0.1,"sigma":0.1,"min":0.0,"max":0.6}), rng)

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
	var want := rng.randi_range(nmin, nmax)
	var chosen := _weighted_sample_no_replacement(pool, want, rng)

	# Assign per-stat skills
	var sp_min := float(spec.get("skill_for_specialty_min", 0.80))
	var sp_max := float(spec.get("skill_for_specialty_max", 0.90))
	var ns_min := float(spec.get("skill_for_non_specialty_min", 0.45))
	var ns_max := float(spec.get("skill_for_non_specialty_max", 0.65))
	s.stat_skill = {}
	var specialty_set := {}
	for it in chosen:
		s.stat_skill[it["name"]] = rng.randf_range(sp_min, sp_max)
		specialty_set[it["name"]] = true
	# Optionally give baseline skills to the rest
	for sd in stats_cfg.get("stats", []):
		var nm := String((sd as Dictionary).get("name",""))
		if specialty_set.has(nm): continue
		s.stat_skill[nm] = rng.randf_range(ns_min, ns_max)

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
		var mu := clamp(mean_mu + rng.randfn(0.0, mean_sd), clamp_min, clamp_max)
		var sg := max(0.1, sig_mu + rng.randfn(0.0, sig_sd))
		s.stat_bias_mean[st] = mu
		s.stat_bias_sigma[st] = sg

	# Initialize meas cache and context in the Scout for later use
	s.setup(stats_cfg, {"sigma_min":1.0,"sigma_max":12.0,"quality_floor":0.15,"bounded_min":0.0,"bounded_max":100.0}, rng)

	return s

func create_team_scouts(team_name: String, count: int = 3, rng: RandomNumberGenerator = null) -> Array:
	var scouts: Array = []
	if rng == null:
		push_error("ScoutFactory: create_team_scouts requires an RNG.")
		return scouts

	var defaults: Dictionary = scouts_cfg.get("defaults", {}) as Dictionary
	var templates: Array = scouts_cfg.get("national_scouts", []) as Array
	var archetypes: Array = scouts_cfg.get("team_archetypes", []) as Array

	for i in range(count):
		var template: Dictionary = templates[rng.randi_range(0, templates.size() - 1)] if not templates.is_empty() else {}
		var scout := Scout.new()
		apply_scout_dict(scout, template)
		scout.role = "Team"
		if scout.name == "Scout":
			scout.name = "%s Scout %d" % [team_name, i + 1]
		else:
			scout.name = "%s - %s" % [team_name, scout.name]

		if not archetypes.is_empty():
			var archetype: Dictionary = archetypes[rng.randi_range(0, archetypes.size() - 1)] as Dictionary
			_apply_archetype(scout, archetype)

		_jitter_multipliers(scout.valuation_multipliers, rng)
		_jitter_multipliers(scout.estimation_multipliers, rng)
		_normalize_bucket_weights(scout.bucket_weights)

		scout.setup(stats_cfg, defaults, rng)
		scouts.append(scout)

	return scouts

static func apply_scout_dict(s: Scout, row: Dictionary) -> void:
	if row.has("name"): s.name = String(row["name"])
	if row.has("role"): s.role = String(row["role"])
	if row.has("years_exp"): s.years_exp = int(row["years_exp"])

	if row.has("base_skill"): s.base_skill = float(row["base_skill"])
	if row.has("overrate_athletes"): s.overrate_athletes = float(row["overrate_athletes"])
	if row.has("tape_grinder"): s.tape_grinder = float(row["tape_grinder"])
	if row.has("risk_aversion"): s.risk_aversion = float(row["risk_aversion"])

	if row.has("stat_skill"): s.stat_skill = (row["stat_skill"] as Dictionary).duplicate(true)
	if row.has("valuation_multipliers"): s.valuation_multipliers = (row["valuation_multipliers"] as Dictionary).duplicate(true)
	if row.has("estimation_multipliers"): s.estimation_multipliers = (row["estimation_multipliers"] as Dictionary).duplicate(true)
	if row.has("stat_bias_mean"): s.stat_bias_mean = (row["stat_bias_mean"] as Dictionary).duplicate(true)
	if row.has("stat_bias_sigma"): s.stat_bias_sigma = (row["stat_bias_sigma"] as Dictionary).duplicate(true)
	if row.has("pos_bias_pts"): s.pos_bias_pts = (row["pos_bias_pts"] as Dictionary).duplicate(true)

	if row.has("bucket_weights"):
		s.bucket_weights = (row["bucket_weights"] as Dictionary).duplicate(true)

	if row.has("current_vs_potential"):
		var cvp: Dictionary = row["current_vs_potential"] as Dictionary
		if cvp.has("current_weight"): s.current_weight = float(cvp["current_weight"])
		if cvp.has("potential_weight"): s.potential_weight = float(cvp["potential_weight"])
		if cvp.has("jitter_sigma"): s.weight_jitter_sigma = float(cvp["jitter_sigma"])
	elif row.has("potential_weight"):
		s.potential_weight = float(row["potential_weight"])
		s.current_weight = clamp(1.0 - s.potential_weight, 0.55, 0.95)

	if row.has("grade_calibration"):
		var gc: Dictionary = row["grade_calibration"] as Dictionary
		if gc.has("offset"): s.board_offset_pts = float(gc["offset"])
		if gc.has("slope"): s.board_slope = float(gc["slope"])
		if gc.has("noise_sigma"): s.board_noise_sigma = float(gc["noise_sigma"])

	if row.has("board_offset_pts"): s.board_offset_pts = float(row["board_offset_pts"])
	if row.has("board_slope"): s.board_slope = float(row["board_slope"])
	if row.has("board_noise_sigma"): s.board_noise_sigma = float(row["board_noise_sigma"])

func _apply_archetype(scout: Scout, archetype: Dictionary) -> void:
	if archetype.has("bucket_weights"):
		scout.bucket_weights = (archetype["bucket_weights"] as Dictionary).duplicate(true)
	if archetype.has("valuation_multipliers"):
		scout.valuation_multipliers = _merge_multipliers(
			scout.valuation_multipliers,
			archetype["valuation_multipliers"] as Dictionary
		)
	if archetype.has("estimation_multipliers"):
		scout.estimation_multipliers = _merge_multipliers(
			scout.estimation_multipliers,
			archetype["estimation_multipliers"] as Dictionary
		)
	if archetype.has("pos_bias_pts"):
		scout.pos_bias_pts = (archetype["pos_bias_pts"] as Dictionary).duplicate(true)
	if archetype.has("name"):
		scout.name = "%s (%s)" % [scout.name, String(archetype["name"])]

func _merge_multipliers(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in extra.keys():
		var mult := float(extra[k])
		var curr := float(out.get(k, 1.0))
		out[k] = clamp(curr * mult, _MULT_MIN, _MULT_MAX)
	return out

func _jitter_multipliers(mults: Dictionary, rng: RandomNumberGenerator) -> void:
	for k in mults.keys():
		var curr := float(mults[k])
		var jitter := rng.randf_range(0.97, 1.03)
		mults[k] = clamp(curr * jitter, _MULT_MIN, _MULT_MAX)

func _normalize_bucket_weights(weights: Dictionary) -> void:
	var total := 0.0
	for v in weights.values():
		total += float(v)
	if total <= 0.0:
		return
	for k in weights.keys():
		weights[k] = float(weights[k]) / total

# --- helpers ---

func _rand_clip(dist: Dictionary, rng: RandomNumberGenerator) -> float:
	var mu := float(dist.get("mu", 0.5))
	var sd := float(dist.get("sigma", 0.1))
	var mn := float(dist.get("min", 0.0))
	var mx := float(dist.get("max", 1.0))
	return clamp(mu + rng.randfn(0.0, sd), mn, mx)

func _weighted_sample_no_replacement(items: Array, k: int, rng: RandomNumberGenerator) -> Array:
	var picked: Array = []
	var pool := items.duplicate()
	for i in range(min(k, pool.size())):
		var total := 0.0
		for it in pool: total += float(it["w"])
		if total <= 0.0:
			picked.append(pool.pop_back())
			continue
		var r := rng.randf() * total
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
