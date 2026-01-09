extends RefCounted
class_name HighSchoolGenerator

const DEFAULT_CONFIG_KEY := "world/high_schools"

func generate(seed: int, config_key: String = DEFAULT_CONFIG_KEY) -> Dictionary:
	var cfg := Config.get_config(config_key)
	if cfg.is_empty():
		push_error("HighSchoolGenerator: missing config '%s'." % config_key)
		return {"schools": [], "config": {}}
	if not _validate_config(cfg):
		return {"schools": [], "config": cfg}

	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	var school_count := int(cfg.get("school_count", 0))
	var name_format := String(cfg.get("name_format", "HS %04d"))
	var default_capacity := int(cfg.get("default_capacity", 0))

	var regions: Array = cfg.get("regions", []) as Array
	var tiers: Array = cfg.get("eliteness_tiers", []) as Array
	var region_weights := _weights_for(regions)
	var tier_weights := _weights_for(tiers)

	var schools: Array = []
	schools.resize(school_count)
	for i in range(school_count):
		var region: Dictionary = _weighted_pick(regions, region_weights, rng)
		var tier: Dictionary = _weighted_pick(tiers, tier_weights, rng)
		var eliteness := rng.randf_range(float(tier.get("min", 0.0)), float(tier.get("max", 100.0)))

		var school_id := "hs_%04d" % (i + 1)
		var school := {
			"id": school_id,
			"name": name_format % (i + 1),
			"region": String(region.get("id", "")),
			"eliteness": eliteness,
			"tier": String(tier.get("id", ""))
		}
		if default_capacity > 0:
			school["capacity"] = default_capacity
		schools[i] = school

	return {"schools": schools, "config": cfg}

func _validate_config(cfg: Dictionary) -> bool:
	var school_count := int(cfg.get("school_count", 0))
	if school_count <= 0:
		push_error("HighSchoolGenerator: 'school_count' must be > 0.")
		return false

	var regions: Array = cfg.get("regions", []) as Array
	if regions.is_empty():
		push_error("HighSchoolGenerator: config must include non-empty 'regions'.")
		return false

	var region_ids := {}
	var region_weight_total := 0.0
	for region in regions:
		var region_dict: Dictionary = region
		var region_id := String(region_dict.get("id", ""))
		var weight := float(region_dict.get("weight", 0.0))
		if region_id == "":
			push_error("HighSchoolGenerator: region missing 'id'.")
			return false
		if region_ids.has(region_id):
			push_error("HighSchoolGenerator: duplicate region id '%s'." % region_id)
			return false
		if weight <= 0.0:
			push_error("HighSchoolGenerator: region '%s' has non-positive weight." % region_id)
			return false
		region_ids[region_id] = true
		region_weight_total += weight

	if region_weight_total <= 0.0:
		push_error("HighSchoolGenerator: region weights must sum > 0.")
		return false
	if abs(region_weight_total - 1.0) > 0.01:
		push_error("HighSchoolGenerator: region weights must sum to 1.0 (got %.3f)." % region_weight_total)
		return false

	var tiers: Array = cfg.get("eliteness_tiers", []) as Array
	if tiers.is_empty():
		push_error("HighSchoolGenerator: config must include non-empty 'eliteness_tiers'.")
		return false

	var tier_weight_total := 0.0
	var tier_ranges: Array = []
	for tier in tiers:
		var tier_dict: Dictionary = tier
		var tier_id := String(tier_dict.get("id", ""))
		if tier_id == "":
			push_error("HighSchoolGenerator: tier missing 'id'.")
			return false
		var min_val := float(tier_dict.get("min", 0.0))
		var max_val := float(tier_dict.get("max", 0.0))
		var weight := float(tier_dict.get("weight", 0.0))
		if max_val <= min_val:
			push_error("HighSchoolGenerator: tier '%s' has invalid min/max." % tier_id)
			return false
		if min_val < 0.0 or max_val > 100.0:
			push_error("HighSchoolGenerator: tier '%s' out of 0-100 range." % tier_id)
			return false
		if weight <= 0.0:
			push_error("HighSchoolGenerator: tier '%s' has non-positive weight." % tier_id)
			return false
		tier_ranges.append({"min": min_val, "max": max_val, "id": tier_id})
		tier_weight_total += weight

	if tier_weight_total <= 0.0:
		push_error("HighSchoolGenerator: tier weights must sum > 0.")
		return false
	if abs(tier_weight_total - 1.0) > 0.01:
		push_error("HighSchoolGenerator: tier weights must sum to 1.0 (got %.3f)." % tier_weight_total)
		return false

	tier_ranges.sort_custom(func(a, b):
		return float((a as Dictionary).min) < float((b as Dictionary).min)
	)
	for i in range(1, tier_ranges.size()):
		var prev: Dictionary = tier_ranges[i - 1]
		var curr: Dictionary = tier_ranges[i]
		if float(prev.max) > float(curr.min):
			push_error("HighSchoolGenerator: tier ranges overlap (%s, %s)." % [prev.id, curr.id])
			return false

	return true

func _weights_for(items: Array) -> Array:
	var weights: Array = []
	weights.resize(items.size())
	for i in range(items.size()):
		weights[i] = float((items[i] as Dictionary).get("weight", 0.0))
	return weights

func _weighted_pick(items: Array, weights: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return items[0] as Dictionary

	var roll := rng.randf() * total
	var running := 0.0
	for i in range(items.size()):
		running += float(weights[i])
		if roll <= running:
			return items[i] as Dictionary

	return items[items.size() - 1] as Dictionary
