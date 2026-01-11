extends RefCounted
class_name NflSeason

const Rand = preload("res://autoloads/Rand.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")

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
	stats_cfg: Dictionary,
	options: Dictionary = {}
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

	# OPTIMIZATION (F6): Pre-extract config values once for all teams
	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	var ret_config := RetirementConfig.new(main_cfg)

	# GAME SIMULATION (G1.1): Simulate season before player lifecycle
	# This generates win-loss records, championships, and strength of schedule
	var game_sim_summary := _simulate_nfl_season(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg
	)

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

		# Use parallel processing for NFL rosters (typically 53 players per team)
		# Since we process all 32 teams, total player count is ~1700, making parallel beneficial
		var progressed: Dictionary = PlayerLifecycle.advance_one_year_parallel(
			prepared_players,
			positions_cfg,
			main_cfg,
			stats_cfg,
			lifecycle_rng,
			{},  # development_context already merged into players
			0,  # Auto-detect thread count
			options,  # Pass through skip_reports and other options
			dev_config,  # Pre-extracted development config
			ret_config  # Pre-extracted retirement config
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
		"game_simulation": game_sim_summary,
		"step_seeds": {
			"lifecycle": lifecycle_rng.seed,
			"context": context_rng.seed,
			"retirement": retirement_rng.seed,
			"game_simulation": game_sim_summary.get("sim_seed", 0)
		}
	}


## OPTIMIZATION (F4): In-place modification for development context
## NflSeason processes each team roster independently, so we own the players array
## and can safely modify in-place instead of copying.
##
## RNG consumption pattern (unchanged):
##   - _roll_nfl_usage: 1 RNG call per player (randf_range for usage variance)
##   Total: 1 RNG call per player (deterministic)
func _apply_nfl_development_context(
	players: Array,
	rng: RandomNumberGenerator,
	year: int
) -> Array:
	# OPTIMIZATION: Modify in-place instead of copying each player
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			continue

		# RNG CALL 1: Usage determination with variance
		var usage := _roll_nfl_usage(p, rng)
		var context := {
			"program_quality": 1.0,  # NFL is top tier
			"competition_tier": 1.1,  # Highest competition level
			"usage": usage,
			"season": "nfl",
			"year": year
		}

		# Replace development_context entirely (NFL context overrides previous)
		p["development_context"] = context

	return players


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


## Updates team history tracking for all teams.
##
## Implements:
##   - H4.1: Franchise Win Totals (all_time_wins, all_time_losses, first_season, last_season)
##   - H4.2: Championship History (championship_count, championship_years)
##   - H4.3: Playoff Appearance Count (playoff_appearances, playoff_years)
##   - H4.4: Winning Streaks (longest_win_streak, longest_loss_streak, current_win/loss_streak)
##   - H4.6: Drought Tracking (years_since_championship)
##
## RNG Pattern: None (pure aggregation, no randomness)
##
## Notes:
##   - Winning/losing streaks track consecutive SEASONS with winning/losing records
##     (winning season = wins > losses)
##   - Playoff teams in Phase 1: Top 7 teams per conference (14 total)
##   - Droughts: years since last Super Bowl, -1 if never won
func _update_team_history(
	world_state: Dictionary,
	year: int,
	season_results: Dictionary,
	champion_id: String,
	teams: Array,
	regions: Array
) -> void:
	var team_history: Dictionary = world_state.get("team_history", {})

	# Determine playoff teams (H4.3)
	# Phase 1 simple version: Top 7 teams per conference
	var playoff_teams := _determine_nfl_playoff_teams(season_results, teams, regions)

	# Process each team
	for team_id in season_results.keys():
		var record: Dictionary = season_results[team_id]
		var wins := int(record.get("wins", 0))
		var losses := int(record.get("losses", 0))

		# Initialize team history if not exists
		if not team_history.has(team_id):
			team_history[team_id] = {
				"team_id": team_id,
				"all_time_wins": 0,
				"all_time_losses": 0,
				"first_season": year,
				"last_season": year,
				"championship_count": 0,
				"championship_years": [],
				"playoff_appearances": 0,
				"playoff_years": [],
				"longest_win_streak": 0,
				"longest_loss_streak": 0,
				"current_win_streak": 0,
				"current_loss_streak": 0,
				"years_since_championship": -1
			}

		var history: Dictionary = team_history[team_id]

		# H4.1: Update franchise win totals
		history["all_time_wins"] = int(history.get("all_time_wins", 0)) + wins
		history["all_time_losses"] = int(history.get("all_time_losses", 0)) + losses
		history["last_season"] = year

		# H4.2: Update championship history
		if team_id == champion_id:
			history["championship_count"] = int(history.get("championship_count", 0)) + 1
			var champ_years: Array = history.get("championship_years", [])
			champ_years.append(year)
			history["championship_years"] = champ_years

		# H4.3: Update playoff appearances
		if team_id in playoff_teams:
			history["playoff_appearances"] = int(history.get("playoff_appearances", 0)) + 1
			var playoff_years: Array = history.get("playoff_years", [])
			playoff_years.append(year)
			history["playoff_years"] = playoff_years

		# H4.4: Update winning/losing streaks
		# Streak definition: consecutive seasons with winning/losing record
		var had_winning_season := (wins > losses)
		var had_losing_season := (losses > wins)

		if had_winning_season:
			# Continue or start winning streak
			history["current_win_streak"] = int(history.get("current_win_streak", 0)) + 1
			history["current_loss_streak"] = 0

			# Update longest if exceeded
			var current_win := int(history["current_win_streak"])
			var longest_win := int(history.get("longest_win_streak", 0))
			if current_win > longest_win:
				history["longest_win_streak"] = current_win

		elif had_losing_season:
			# Continue or start losing streak
			history["current_loss_streak"] = int(history.get("current_loss_streak", 0)) + 1
			history["current_win_streak"] = 0

			# Update longest if exceeded
			var current_loss := int(history["current_loss_streak"])
			var longest_loss := int(history.get("longest_loss_streak", 0))
			if current_loss > longest_loss:
				history["longest_loss_streak"] = current_loss

		else:
			# .500 season (tied) resets both streaks
			history["current_win_streak"] = 0
			history["current_loss_streak"] = 0

		# H4.6: Update championship drought
		var champ_years: Array = history.get("championship_years", [])
		if champ_years.is_empty():
			history["years_since_championship"] = -1  # Never won
		else:
			var last_champ_year := int(champ_years[champ_years.size() - 1])
			history["years_since_championship"] = year - last_champ_year

		team_history[team_id] = history

	world_state["team_history"] = team_history


## Determines which teams make the playoff (NFL).
##
## Phase 1 simple version: Top 7 teams per conference by win count.
## Phase 2 will implement proper seeding with division winners, wild cards, etc.
##
## RNG Pattern: None (deterministic selection by record)
##
## Returns: Array of team_ids that made the playoff
func _determine_nfl_playoff_teams(
	season_results: Dictionary,
	teams: Array,
	regions: Array
) -> Array:
	# Build team-to-conference mapping
	var team_to_conference := {}
	for region in regions:
		var r: Dictionary = region
		var conf_name := String(r.get("name", ""))
		var divisions: Array = r.get("divisions", [])
		for division in divisions:
			var d: Dictionary = division
			var team_ids: Array = d.get("team_ids", [])
			for team_id in team_ids:
				team_to_conference[String(team_id)] = conf_name

	# Build conference standings
	var conference_standings := {}
	for team_id in season_results.keys():
		var record: Dictionary = season_results[team_id]
		var conf := team_to_conference.get(team_id, "Unknown")
		if not conference_standings.has(conf):
			conference_standings[conf] = []

		(conference_standings[conf] as Array).append({
			"team_id": team_id,
			"wins": int(record.get("wins", 0)),
			"losses": int(record.get("losses", 0))
		})

	# Sort each conference by wins descending, then losses ascending
	for conf in conference_standings.keys():
		var teams_in_conf: Array = conference_standings[conf]
		teams_in_conf.sort_custom(func(a, b):
			var a_wins := int(a["wins"])
			var b_wins := int(b["wins"])
			if a_wins != b_wins:
				return a_wins > b_wins
			# Tiebreaker: fewer losses
			return int(a["losses"]) < int(b["losses"])
		)

	# Select top 7 from each conference
	var playoff_teams := []
	var playoff_size_per_conference := 7

	for conf in conference_standings.keys():
		var teams_in_conf: Array = conference_standings[conf]
		for i in range(min(playoff_size_per_conference, teams_in_conf.size())):
			playoff_teams.append(String(teams_in_conf[i]["team_id"]))

	return playoff_teams


## Simulates NFL season games and stores results.
##
## Implements G1.1 (Game Simulation), G1.2 (Season W-L Records), G1.5 (Championships), G1.8 (SOS)
##
## RNG Pattern:
##   - Simulation seed: Rand.splitmix64(seed ^ 0x5EA50004)
##   - Expected consumption: 1 randf() per game + schedule shuffle
##   - Sequential simulation per week for determinism
##
## Stores in world_state:
##   - world_state["season_records"][year][team_id] -> SeasonRecord
##   - world_state["championships"]["nfl"]["super_bowl_winners"][year] -> team_id
##
## Returns summary dict with game count, upset count, Super Bowl winner
func _simulate_nfl_season(
	world_state: Dictionary,
	year: int,
	seed: int,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var game_sim_cfg: Dictionary = league_cfg.get("game_simulation", {})

	# Check feature flag
	if not bool(game_sim_cfg.get("enabled", false)):
		return {
			"enabled": false,
			"games_simulated": 0
		}

	# Load data
	var teams: Array = world_state.get("nfl_teams", [])
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var regions: Array = league_cfg.get("regions", [])

	# Derive simulation seed (unique salt for game simulation)
	var sim_seed := Rand.splitmix64(seed ^ 0x5EA50004)

	# Calculate team strengths (cache for all games)
	# Expected RNG consumption: None (pure calculation)
	var team_strengths := {}
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if rosters.has(team_id):
			var roster: Dictionary = rosters[team_id]
			var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
			team_strengths[team_id] = strength

	# Generate schedule
	# Expected RNG consumption: N swaps for shuffle operations
	var schedule := GameSimulator.generate_nfl_schedule(teams, regions, year, sim_seed)

	# Simulate games (sequential for determinism)
	# Expected RNG consumption: 1 randf() per game + stats generation per player
	var rng := RandomNumberGenerator.new()
	rng.seed = sim_seed
	var all_results: Array = []
	var upset_count := 0

	for matchup in schedule:
		var result := GameSimulator.determine_winner(matchup, team_strengths, rng, game_sim_cfg)
		all_results.append(result)
		if bool(result.get("upset", false)):
			upset_count += 1

		# Accumulate player stats for this game (S2.1)
		# Expected RNG consumption: Variable per player (see StatGenerator documentation)
		var home_id := String(result.get("home_team_id", ""))
		var away_id := String(result.get("away_team_id", ""))
		var home_roster := rosters.get(home_id, {})
		var away_roster := rosters.get(away_id, {})

		if not home_roster.is_empty() and not away_roster.is_empty():
			GameSimulator.accumulate_player_stats(
				world_state,
				result,
				home_roster,
				away_roster,
				positions_cfg,
				main_cfg,
				rng
			)

	# Aggregate results (G1.2: Season W-L Records, G1.8: Strength of Schedule)
	# Expected RNG consumption: None (pure aggregation)
	var team_ids := []
	for team in teams:
		var t: Dictionary = team
		team_ids.append(String(t.get("id", "")))

	var season_results := GameSimulator.aggregate_season_results(all_results, team_ids)

	# Store season records in world_state (G1.2)
	var season_records: Dictionary = world_state.get("season_records", {})
	if not season_records.has(year):
		season_records[year] = {}
	for team_id in season_results.keys():
		season_records[year][team_id] = season_results[team_id]
	world_state["season_records"] = season_records

	# Determine Super Bowl winner (G1.5: Championship Tracking)
	# Phase 1: Best record wins (simple version, playoffs in Phase 2)
	var best_record := {"team_id": "", "wins": -1}
	for team_id in season_results.keys():
		var record: Dictionary = season_results[team_id]
		var wins := int(record.get("wins", 0))
		if wins > int(best_record["wins"]):
			best_record = {"team_id": team_id, "wins": wins}

	# Store championship (G1.5)
	var championships: Dictionary = world_state.get("championships", {})
	if not championships.has("nfl"):
		championships["nfl"] = {"super_bowl_winners": {}}
	if not championships["nfl"].has("super_bowl_winners"):
		championships["nfl"]["super_bowl_winners"] = {}
	championships["nfl"]["super_bowl_winners"][year] = String(best_record["team_id"])
	world_state["championships"] = championships

	# Update team history (H4.1-H4.6: Franchise stats, championships, streaks, droughts)
	# Expected RNG consumption: None (pure aggregation)
	_update_team_history(world_state, year, season_results, String(best_record["team_id"]), teams, regions)

	# Return summary
	return {
		"enabled": true,
		"games_simulated": all_results.size(),
		"upsets": upset_count,
		"super_bowl_winner": String(best_record["team_id"]),
		"champion_record": "%d-%d" % [int(best_record["wins"]),
									  int(season_results[best_record["team_id"]].get("losses", 0))],
		"sim_seed": sim_seed
	}
