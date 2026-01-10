extends RefCounted
class_name NflTeamGenerator

const ConfigService = preload("res://autoloads/Config.gd")

const DEFAULT_CONFIG_KEY := "world/league"

var _config: Node = null

func _get_config_service() -> Node:
	if _config == null:
		_config = ConfigService.new()
	return _config

func generate(seed: int, config_key: String = DEFAULT_CONFIG_KEY) -> Dictionary:
	var cfg: Dictionary = _get_config_service().get_config(config_key)
	if cfg.is_empty():
		push_error("NflTeamGenerator: missing config '%s'." % config_key)
		return {"teams": [], "config": {}}
	if not _validate_config(cfg):
		return {"teams": [], "config": cfg}

	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	var team_count := int(cfg.get("team_count", 0))
	var name_format := String(cfg.get("name_format", "Team %03d"))
	var cap_limit := float(cfg.get("cap_limit", 0.0))

	var regions: Array = cfg.get("regions", []) as Array
	var region_weights := _weights_for(regions)

	var teams: Array = []
	teams.resize(team_count)
	for i in range(team_count):
		var region: Dictionary = _weighted_pick(regions, region_weights, rng)
		var team_id := "nfl_%03d" % (i + 1)
		var team := {
			"id": team_id,
			"name": name_format % (i + 1),
			"region": String(region.get("id", "")),
			"cap_space": cap_limit,
			"roster": [],
			"draft_order": i + 1
		}
		teams[i] = team

	return {"teams": teams, "config": cfg}

func _validate_config(cfg: Dictionary) -> bool:
	var team_count := int(cfg.get("team_count", 0))
	if team_count <= 0:
		push_error("NflTeamGenerator: 'team_count' must be > 0.")
		return false

	var regions: Array = cfg.get("regions", []) as Array
	if regions.is_empty():
		push_error("NflTeamGenerator: config must include non-empty 'regions'.")
		return false

	var region_ids := {}
	var region_weight_total := 0.0
	for region in regions:
		var region_dict: Dictionary = region
		var region_id := String(region_dict.get("id", ""))
		var weight := float(region_dict.get("weight", 0.0))
		if region_id == "":
			push_error("NflTeamGenerator: region missing 'id'.")
			return false
		if region_ids.has(region_id):
			push_error("NflTeamGenerator: duplicate region id '%s'." % region_id)
			return false
		if weight <= 0.0:
			push_error("NflTeamGenerator: region '%s' has non-positive weight." % region_id)
			return false
		region_ids[region_id] = true
		region_weight_total += weight

	if region_weight_total <= 0.0:
		push_error("NflTeamGenerator: region weights must sum > 0.")
		return false
	if abs(region_weight_total - 1.0) > 0.01:
		push_error("NflTeamGenerator: region weights must sum to 1.0 (got %.3f)." % region_weight_total)
		return false

	var roster_limits: Dictionary = cfg.get("roster_limits", {}) as Dictionary
	if not roster_limits.is_empty():
		var active := int(roster_limits.get("active", 0))
		if active <= 0:
			push_error("NflTeamGenerator: 'roster_limits.active' must be > 0.")
			return false

	var draft: Dictionary = cfg.get("draft", {}) as Dictionary
	if not draft.is_empty():
		var rounds := int(draft.get("rounds", 0))
		var picks_per_round := int(draft.get("picks_per_round", 0))
		if rounds <= 0:
			push_error("NflTeamGenerator: 'draft.rounds' must be > 0.")
			return false
		if picks_per_round <= 0:
			push_error("NflTeamGenerator: 'draft.picks_per_round' must be > 0.")
			return false

	return true

func _weights_for(items: Array) -> Array:
	var weights: Array = []
	weights.resize(items.size())
	for i in range(items.size()):
		weights[i] = float((items[i] as Dictionary).get("weight", 0.0))
	return weights

func _weighted_pick(items: Array, weights: Array, rng: RandomNumberGenerator) -> Dictionary:
	if items.is_empty():
		return {}
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
