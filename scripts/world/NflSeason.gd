extends RefCounted
class_name NflSeason

const Rand = preload("res://autoloads/Rand.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

## Runs the NFL season simulation for a given year.
##
## Advances all NFL players by one year, handling:
## - Development/regression via PlayerLifecycle
## - Retirement decisions
## - Contract expiration tracking
## - Free agency pool management
##
## Returns:
##   - roster_counts: Player counts per team after season
##   - retirements: Number of players who retired
##   - free_agents: Number of players entering free agency
##   - step_seeds: Dictionary of seeds used for determinism tracking
func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary
) -> Dictionary:
	var teams: Array = world_state.get("nfl_teams", []) as Array
	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	var retired: Array = world_state.get("retired_players", []) as Array

	if teams.is_empty():
		return {
			"year": year,
			"roster_counts": {},
			"retirements": 0,
			"free_agents": 0,
			"step_seeds": {}
		}

	# Initialize RNGs for different phases
	var lifecycle_rng := RandomNumberGenerator.new()
	lifecycle_rng.seed = Rand.splitmix64(seed ^ 0x5EA50001)
	var context_rng := RandomNumberGenerator.new()
	context_rng.seed = Rand.splitmix64(seed ^ 0x5EA50002)
	var retirement_rng := RandomNumberGenerator.new()
	retirement_rng.seed = Rand.splitmix64(seed ^ 0x5EA50003)

	var total_retirements := 0
	var total_free_agents := 0
	var roster_counts := {}
	var new_free_agents: Array = []
	var new_retirees: Array = []

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id == "":
			continue

		var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
		var players: Array = roster.get("players", []) as Array

		if players.is_empty():
			roster_counts[team_id] = 0
			continue

		# Apply development context for NFL level
		var prepared_players := _apply_nfl_development_context(
			players,
			context_rng,
			year
		)

		# Advance all players one year
		var progressed: Dictionary = PlayerLifecycle.advance_one_year(
			prepared_players,
			positions_cfg,
			main_cfg,
			stats_cfg,
			lifecycle_rng
		)

		var updated_players: Array = progressed.get("players", []) as Array
		var lifecycle_retired: Array = progressed.get("retired", []) as Array

		# Process each player for contract expiration and additional retirement checks
		var active_players: Array = []
		for i in range(updated_players.size()):
			var raw_player = updated_players[i]
			if raw_player == null or not (raw_player is Dictionary):
				continue
			var p: Dictionary = raw_player

			# Update contract years
			var contract_result := _update_contract(p)

			# Check for additional retirement (beyond PlayerLifecycle)
			if _check_nfl_retirement(p, positions_cfg, main_cfg, retirement_rng):
				p["retirement_year"] = year
				p["retirement_team"] = team_id
				new_retirees.append(p)
				total_retirements += 1
				continue

			# Check for free agency (contract expired)
			if contract_result.get("expired", false):
				p["free_agent_year"] = year
				p["last_team_id"] = team_id
				p["nfl_status"] = "free_agent"
				new_free_agents.append(p)
				total_free_agents += 1
				continue

			# Player remains active on roster
			active_players.append(p)

		# Handle players retired by PlayerLifecycle
		for lc_retired in lifecycle_retired:
			var p: Dictionary = lc_retired
			p["retirement_year"] = year
			p["retirement_team"] = team_id
			new_retirees.append(p)
			total_retirements += 1

		# Update roster
		roster["players"] = active_players
		_rebuild_roster_by_position(roster)
		rosters[team_id] = roster
		roster_counts[team_id] = active_players.size()

	# Update world state
	world_state["nfl_rosters"] = rosters
	retired.append_array(new_retirees)
	world_state["retired_players"] = retired

	var free_agents: Dictionary = world_state.get("free_agents", {}) as Dictionary
	free_agents[year] = new_free_agents
	world_state["free_agents"] = free_agents

	return {
		"year": year,
		"roster_counts": roster_counts,
		"total_players": _sum_roster_counts(roster_counts),
		"retirements": total_retirements,
		"free_agents": total_free_agents,
		"step_seeds": {
			"lifecycle": lifecycle_rng.seed,
			"context": context_rng.seed,
			"retirement": retirement_rng.seed
		}
	}


func _apply_nfl_development_context(
	players: Array,
	rng: RandomNumberGenerator,
	year: int
) -> Array:
	var updated: Array = []
	updated.resize(players.size())

	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			updated[i] = p
			continue

		var usage := _roll_nfl_usage(p, rng)
		var context := {
			"program_quality": 1.0,  # NFL is top tier
			"competition_tier": 1.1,  # Highest competition level
			"usage": usage,
			"season": "nfl",
			"year": year
		}

		var next := p.duplicate(true)
		next["development_context"] = context
		updated[i] = next

	return updated


func _roll_nfl_usage(player: Dictionary, rng: RandomNumberGenerator) -> float:
	# NFL usage based on depth chart position (approximated by years in league)
	var contract: Dictionary = player.get("contract", {}) as Dictionary
	var years_total := int(contract.get("years_total", 4))
	var years_remaining := int(contract.get("years_remaining", 4))
	var years_in_nfl := years_total - years_remaining

	# Rookies and younger players get less usage
	# Veterans get more usage (starter)
	var base_usage := 1.0
	if years_in_nfl == 0:
		base_usage = 0.85  # Rookie
	elif years_in_nfl == 1:
		base_usage = 0.95  # Second year
	elif years_in_nfl >= 4:
		base_usage = 1.1  # Veteran starter

	# Add some randomness
	return clamp(base_usage + rng.randf_range(-0.1, 0.1), 0.7, 1.3)


func _update_contract(player: Dictionary) -> Dictionary:
	var contract: Dictionary = player.get("contract", {}) as Dictionary
	if contract.is_empty():
		return {"expired": true}

	var years_remaining := int(contract.get("years_remaining", 0))
	years_remaining = max(0, years_remaining - 1)
	contract["years_remaining"] = years_remaining

	var expired := (years_remaining <= 0)
	if expired:
		contract["status"] = "expired"

	player["contract"] = contract
	return {"expired": expired, "years_remaining": years_remaining}


func _check_nfl_retirement(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> bool:
	var cfg: Dictionary = main_cfg.get("retirement", {}) as Dictionary
	var age := int(player.get("age", 18))
	var min_age := int(cfg.get("min_age", 27))
	var soft_cap_age := int(cfg.get("soft_cap_age", 33))
	var max_age := int(cfg.get("max_age", 40))

	# Don't retire if too young
	if age < min_age:
		return false

	# Forced retirement at max age
	if age >= max_age:
		return true

	# Calculate retirement probability
	var chance := float(cfg.get("base_chance", 0.02))
	var age_slope := float(cfg.get("age_chance_per_year", 0.04))
	chance += max(0, age - soft_cap_age) * age_slope

	# Low rating boost
	var low_rating_threshold := float(cfg.get("low_rating_threshold", 55.0))
	var low_rating_boost := float(cfg.get("low_rating_boost", 0.08))
	if _core_rating(player, positions_cfg) < low_rating_threshold:
		chance += low_rating_boost

	# Injury history increases retirement chance
	var injuries: Array = player.get("injuries", []) as Array
	if injuries.size() >= 3:
		chance += 0.05

	chance = clamp(chance, 0.0, 0.95)
	return rng.randf() < chance


func _core_rating(player: Dictionary, positions_cfg: Dictionary) -> float:
	var position := String(player.get("position", ""))
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var core_stats: Array = (pos_cfg.get("core_stats", []) as Array)
	var stats: Dictionary = player.get("stats", {}) as Dictionary

	if core_stats.is_empty():
		return _mean_of_stats(stats)

	var total := 0.0
	var count := 0
	for stat in core_stats:
		if stats.has(stat):
			total += float(stats.get(stat, 0.0))
			count += 1

	if count == 0:
		return _mean_of_stats(stats)
	return total / float(count)


func _mean_of_stats(stats: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for v in stats.values():
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			total += float(v)
			count += 1
	return (total / float(count)) if count > 0 else 0.0


func _rebuild_roster_by_position(roster: Dictionary) -> void:
	var players: Array = roster.get("players", []) as Array
	var by_position := {}

	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		var player_id := String(p.get("player_id", ""))

		if position == "" or player_id == "":
			continue

		if not by_position.has(position):
			by_position[position] = []

		(by_position[position] as Array).append(player_id)

	roster["by_position"] = by_position


func _sum_roster_counts(counts: Dictionary) -> int:
	var total := 0
	for count in counts.values():
		total += int(count)
	return total
