extends RefCounted
class_name HighSchoolAssignment

func assign(players: Array, schools: Array, config: Dictionary, seed: int) -> Dictionary:
	var assignment_cfg: Dictionary = config.get("assignment", {}) as Dictionary
	var eliteness_weight := float(assignment_cfg.get("eliteness_weight", 0.45))
	var player_weight := float(assignment_cfg.get("player_strength_weight", 0.35))
	var proximity_weight := float(assignment_cfg.get("proximity_weight", 0.20))
	var region_match_multiplier := float(assignment_cfg.get("region_match_multiplier", 1.25))
	var outlier_chance := float(assignment_cfg.get("outlier_chance", 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)

	var ordered_schools := schools.duplicate()
	ordered_schools.sort_custom(func(a, b):
		return String((a as Dictionary).get("id", "")) < String((b as Dictionary).get("id", ""))
	)

	var assigned := 0
	var unassigned := 0
	var updated_players: Array = players.duplicate(true)

	for i in range(updated_players.size()):
		var p: Dictionary = updated_players[i]
		if p == null:
			continue
		if String(p.get("eligibility_status", "")) == "hs_grad":
			continue
		if String(p.get("hs_school_id", "")) != "":
			continue

		var pick := _choose_school(
			p,
			ordered_schools,
			eliteness_weight,
			player_weight,
			proximity_weight,
			region_match_multiplier,
			outlier_chance,
			rng
		)
		if pick.is_empty():
			unassigned += 1
			continue

		p["hs_school_id"] = String(pick.get("id", ""))
		updated_players[i] = p
		assigned += 1

		if pick.has("assigned_count"):
			pick["assigned_count"] = int(pick.get("assigned_count", 0)) + 1
		else:
			pick["assigned_count"] = 1

	return {
		"players": updated_players,
		"assigned": assigned,
		"unassigned": unassigned
	}

func _choose_school(
	player: Dictionary,
	schools: Array,
	eliteness_weight: float,
	player_weight: float,
	proximity_weight: float,
	region_match_multiplier: float,
	outlier_chance: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	if schools.is_empty():
		return {}

	if outlier_chance > 0.0 and rng.randf() < outlier_chance:
		return schools[rng.randi_range(0, schools.size() - 1)] as Dictionary

	var weights: Array = []
	weights.resize(schools.size())
	var total := 0.0
	var player_strength := _player_strength(player) / 100.0
	var home_region := String(player.get("home_region", ""))
	var proximity_bias := float(player.get("proximity_bias", 0.0))

	for i in range(schools.size()):
		var school: Dictionary = schools[i]
		var capacity := int(school.get("capacity", 0))
		var assigned_count := int(school.get("assigned_count", 0))
		if capacity > 0 and assigned_count >= capacity:
			weights[i] = 0.0
			continue

		var eliteness := float(school.get("eliteness", 0.0)) / 100.0
		var region := String(school.get("region", ""))
		var proximity_factor := 1.0
		if home_region != "" and home_region == region:
			proximity_factor = 1.0 + (region_match_multiplier - 1.0) * proximity_bias

		var weight := (eliteness * eliteness_weight)
		weight += (player_strength * player_weight)
		weight += (proximity_factor * proximity_weight)
		weight = max(weight, 0.0001)
		weights[i] = weight
		total += weight

	if total <= 0.0:
		return _first_available_school(schools)

	var roll := rng.randf() * total
	var running := 0.0
	for i in range(schools.size()):
		running += float(weights[i])
		if roll <= running:
			return schools[i] as Dictionary

	return schools[schools.size() - 1] as Dictionary

func _first_available_school(schools: Array) -> Dictionary:
	for school in schools:
		var school_dict: Dictionary = school
		var capacity := int(school_dict.get("capacity", 0))
		var assigned_count := int(school_dict.get("assigned_count", 0))
		if capacity == 0 or assigned_count < capacity:
			return school_dict
	return {}

func _player_strength(player: Dictionary) -> float:
	if player.has("composite_score"):
		return float(player.get("composite_score", 0.0))
	if player.has("core_avg"):
		return float(player.get("core_avg", 0.0))
	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var total := 0.0
	var count := 0
	for val in stats.values():
		if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
			total += float(val)
			count += 1
	return (total / float(count)) if count > 0 else 0.0
