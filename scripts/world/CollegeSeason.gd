extends RefCounted
class_name CollegeSeason

const Rand = preload("res://autoloads/Rand.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")

func run(
	world_state: Dictionary,
	year: int,
	seed: int,
	config: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	stats_cfg: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var rosters: Dictionary = world_state.get("college_rosters", {}) as Dictionary
	var colleges: Array = world_state.get("colleges", []) as Array

	if rosters.is_empty():
		return {
			"year": year,
			"rosters_updated": 0,
			"graduates": 0,
			"draft_eligible_count": 0,
			"early_declares": 0,
			"step_seeds": {}
		}

	var lifecycle_rng := RandomNumberGenerator.new()
	lifecycle_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E1)
	var context_rng := RandomNumberGenerator.new()
	context_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E2)
	var early_decl_rng := RandomNumberGenerator.new()
	early_decl_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E3)

	var early_decl_cfg: Dictionary = config.get("early_declaration", {}) as Dictionary

	var college_index := _college_index(colleges)
	var draft_pool: Dictionary = world_state.get("draft_pool", {}) as Dictionary
	var draft_eligible: Array = draft_pool.get(year, []) as Array

	# OPTIMIZATION (F6): Pre-extract config values once for all rosters
	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	var ret_config := RetirementConfig.new(main_cfg)

	# GAME SIMULATION (G1.1): Simulate season before player lifecycle
	# This generates win-loss records, championships, and strength of schedule
	var game_sim_summary := _simulate_college_season(
		world_state,
		year,
		seed,
		config,
		positions_cfg,
		main_cfg
	)

	var total_graduates := 0
	var total_early_declares := 0
	var rosters_updated := 0

	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", []) as Array
		if players.is_empty():
			continue

		var college: Dictionary = college_index.get(college_id, {}) as Dictionary
		var prepared_players := _apply_development_context(players, college, config, context_rng, year)

		# Use parallel processing for college rosters (typically 50-100 players per college)
		# For large conferences, parallel processing can provide significant speedup
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
		var active: Array = []
		var class_years := {1: [], 2: [], 3: [], 4: []}

		for i in range(updated_players.size()):
			var p: Variant = updated_players[i]
			if p == null:
				continue

			var old_year := int(p.get("college_year", 1))
			var new_year := old_year + 1
			p["college_year"] = new_year

			var new_status := _eligibility_status(new_year)
			p["college_eligibility_status"] = new_status

			var is_draft_eligible := false
			if new_year >= 4:
				# Seniors: Only declare if rating meets threshold
				# OPTIMIZATION: Draft Declaration Threshold (from BACKWARD_CLASS_SIZING.md)
				# Purpose: Reduce draft pool from ~2,900 to ~520 players (82% reduction)
				# Expected impact: Faster draft processing during bootstrap
				total_graduates += 1
				var draft_threshold_cfg: Dictionary = config.get("draft_declaration", {}) as Dictionary
				var rating_threshold := float(draft_threshold_cfg.get("rating_threshold", 65.0))
				var class_rules: Dictionary = main_cfg.get("class_rules", {}) as Dictionary
				var player_rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)
				if player_rating >= rating_threshold:
					is_draft_eligible = true
			elif new_year == 3:
				# Check for early declaration
				if _check_early_declaration(p, early_decl_cfg, early_decl_rng, positions_cfg, main_cfg):
					is_draft_eligible = true
					total_early_declares += 1

			if is_draft_eligible:
				p["draft_eligible"] = true
				p["draft_year"] = year
				draft_eligible.append(p)
			else:
				active.append(p)
				if new_year >= 1 and new_year <= 4:
					(class_years[new_year] as Array).append(String(p.get("player_id", "")))

		roster["players"] = active
		roster["class_years"] = class_years
		rosters[college_id] = roster
		rosters_updated += 1

	world_state["college_rosters"] = rosters
	draft_pool[year] = draft_eligible
	world_state["draft_pool"] = draft_pool

	return {
		"year": year,
		"rosters_updated": rosters_updated,
		"graduates": total_graduates,
		"draft_eligible_count": draft_eligible.size(),
		"early_declares": total_early_declares,
		"game_simulation": game_sim_summary,
		"step_seeds": {
			"lifecycle": lifecycle_rng.seed,
			"context": context_rng.seed,
			"early_declaration": early_decl_rng.seed,
			"game_simulation": game_sim_summary.get("sim_seed", 0)
		}
	}

## OPTIMIZATION (F4): In-place modification for development context
## CollegeSeason processes each roster independently, so we own the players array
## and can safely modify in-place instead of copying.
##
## RNG consumption pattern (unchanged):
##   - _roll_usage: 1 RNG call per player (starter determination)
##   Total: 1 RNG call per player (deterministic)
func _apply_development_context(
	players: Array,
	college: Dictionary,
	config: Dictionary,
	rng: RandomNumberGenerator,
	year: int
) -> Array:
	var usage_cfg: Dictionary = config.get("usage_profile", {}) as Dictionary
	var competition_cfg: Dictionary = config.get("competition", {}) as Dictionary

	var college_tier := String(college.get("tier", "mid"))
	var college_eliteness := float(college.get("eliteness", 50.0))
	var program_quality := college_eliteness / 100.0
	var tier_multipliers: Dictionary = competition_cfg.get("tier_growth_multipliers", {}) as Dictionary
	var competition_tier := float(tier_multipliers.get(college_tier, 1.0))

	# OPTIMIZATION: Modify in-place instead of copying each player
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if p == null:
			continue

		# RNG CALL 1: Usage determination
		var usage := _roll_usage(usage_cfg, rng)
		var context := {
			"program_quality": program_quality,
			"competition_tier": competition_tier,
			"usage": usage,
			"season": "college",
			"year": year
		}

		# Replace development_context entirely (college context overrides previous)
		p["development_context"] = context

	return players

func _roll_usage(usage_cfg: Dictionary, rng: RandomNumberGenerator) -> float:
	var starter_chance := float(usage_cfg.get("starter_chance", 0.45))
	var starter_mult := 1.2
	var bench_mult := 0.8

	if rng.randf() < starter_chance:
		return starter_mult
	else:
		return bench_mult

func _eligibility_status(college_year: int) -> String:
	match college_year:
		1:
			return "freshman"
		2:
			return "sophomore"
		3:
			return "junior"
		4:
			return "senior"
		_:
			return "senior"

func _check_early_declaration(
	player: Dictionary,
	early_decl_cfg: Dictionary,
	rng: RandomNumberGenerator,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> bool:
	var min_year := int(early_decl_cfg.get("min_year", 3))
	var rating_threshold := float(early_decl_cfg.get("rating_threshold", 85.0))
	var base_chance := float(early_decl_cfg.get("base_chance", 0.15))
	var rating_bonus_per_point := float(early_decl_cfg.get("rating_bonus_per_point", 0.01))

	var college_year := int(player.get("college_year", 1))
	if college_year < min_year:
		return false

	var class_rules: Dictionary = main_cfg.get("class_rules", {}) as Dictionary
	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
	if rating < rating_threshold:
		return false

	var chance := base_chance + (rating - rating_threshold) * rating_bonus_per_point
	chance = clamp(chance, 0.0, 0.95)

	return rng.randf() < chance


func _college_index(colleges: Array) -> Dictionary:
	var out := {}
	for college in colleges:
		var c: Dictionary = college
		var cid := String(c.get("id", ""))
		if cid != "":
			out[cid] = c
	return out


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
##   - Playoff teams in Phase 1: Top 4 teams by record (college)
##   - Droughts: years since last championship, -1 if never won
func _update_team_history(
	world_state: Dictionary,
	year: int,
	season_results: Dictionary,
	champion_id: String
) -> void:
	var team_history: Dictionary = world_state.get("team_history", {})

	# Determine playoff teams (H4.3)
	# Phase 1 simple version: Top 4 teams by win count
	var playoff_teams := _determine_college_playoff_teams(season_results)

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


## Determines which teams make the playoff (college).
##
## Phase 1 simple version: Top 4 teams by win count.
## Phase 2 will implement proper CFP selection with conference champions, committee rankings, etc.
##
## RNG Pattern: None (deterministic selection by record)
##
## Returns: Array of team_ids that made the playoff
func _determine_college_playoff_teams(season_results: Dictionary) -> Array:
	# Build array of [team_id, wins, losses] for sorting
	var teams := []
	for team_id in season_results.keys():
		var record: Dictionary = season_results[team_id]
		teams.append({
			"team_id": team_id,
			"wins": int(record.get("wins", 0)),
			"losses": int(record.get("losses", 0))
		})

	# Sort by wins descending, then losses ascending (tiebreaker)
	teams.sort_custom(func(a, b):
		var a_wins := int(a["wins"])
		var b_wins := int(b["wins"])
		if a_wins != b_wins:
			return a_wins > b_wins
		# Tiebreaker: fewer losses
		return int(a["losses"]) < int(b["losses"])
	)

	# Select top 4
	var playoff_teams := []
	var playoff_size := 4
	for i in range(min(playoff_size, teams.size())):
		playoff_teams.append(String(teams[i]["team_id"]))

	return playoff_teams


## Simulates college football season games and stores results.
##
## Implements G1.1 (Game Simulation), G1.2 (Season W-L Records), G1.5 (Championships), G1.8 (SOS)
##
## RNG Pattern:
##   - Simulation seed: Rand.splitmix64(seed ^ 0xC011E6E4)
##   - Expected consumption: 1 randf() per game + schedule shuffle
##   - Sequential simulation per week for determinism
##
## Stores in world_state:
##   - world_state["season_records"][year][team_id] -> SeasonRecord
##   - world_state["championships"]["college"]["national_champions"][year] -> team_id
##
## Returns summary dict with game count, upset count, champion
func _simulate_college_season(
	world_state: Dictionary,
	year: int,
	seed: int,
	config: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var game_sim_cfg: Dictionary = config.get("game_simulation", {})

	# Check feature flag
	if not bool(game_sim_cfg.get("enabled", false)):
		return {
			"enabled": false,
			"games_simulated": 0
		}

	# Load data
	var colleges: Array = world_state.get("colleges", [])
	var rosters: Dictionary = world_state.get("college_rosters", {})

	# Derive simulation seed (unique salt for game simulation)
	var sim_seed := Rand.splitmix64(seed ^ 0xC011E6E4)

	# Calculate team strengths (cache for all games)
	# Expected RNG consumption: None (pure calculation)
	var team_strengths := {}
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c.get("id", ""))
		if rosters.has(college_id):
			var roster: Dictionary = rosters[college_id]
			var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
			team_strengths[college_id] = strength

	# Generate schedule
	# Expected RNG consumption: N swaps for shuffle (N = college count)
	var weeks := int(game_sim_cfg.get("regular_season_weeks", 12))
	var schedule := GameSimulator.generate_college_schedule(colleges, year, weeks, sim_seed)

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
	var college_ids := []
	for college in colleges:
		var c: Dictionary = college
		college_ids.append(String(c.get("id", "")))

	var season_results := GameSimulator.aggregate_season_results(all_results, college_ids)

	# Store season records in world_state (G1.2)
	var season_records: Dictionary = world_state.get("season_records", {})
	if not season_records.has(year):
		season_records[year] = {}
	for team_id in season_results.keys():
		season_records[year][team_id] = season_results[team_id]
	world_state["season_records"] = season_records

	# Determine national champion (G1.5: Championship Tracking)
	# Phase 1: Best record wins (simple version, playoffs in Phase 2)
	var best_record := {"team_id": "", "wins": -1}
	for team_id in season_results.keys():
		var record: Dictionary = season_results[team_id]
		var wins := int(record.get("wins", 0))
		if wins > int(best_record["wins"]):
			best_record = {"team_id": team_id, "wins": wins}

	# Store championship (G1.5)
	var championships: Dictionary = world_state.get("championships", {})
	if not championships.has("college"):
		championships["college"] = {"national_champions": {}}
	if not championships["college"].has("national_champions"):
		championships["college"]["national_champions"] = {}
	championships["college"]["national_champions"][year] = String(best_record["team_id"])
	world_state["championships"] = championships

	# Update team history (H4.1-H4.6: Franchise stats, championships, streaks, droughts)
	# Expected RNG consumption: None (pure aggregation)
	_update_team_history(world_state, year, season_results, String(best_record["team_id"]))

	# Return summary
	return {
		"enabled": true,
		"games_simulated": all_results.size(),
		"upsets": upset_count,
		"national_champion": String(best_record["team_id"]),
		"champion_record": "%d-%d" % [int(best_record["wins"]),
									  int(season_results[best_record["team_id"]].get("losses", 0))],
		"sim_seed": sim_seed
	}
