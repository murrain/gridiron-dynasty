extends RefCounted
class_name CollegeSeason

const Rand = preload("res://autoloads/Rand.gd")
const PlayerStateManager = preload("res://scripts/core/state/PlayerStateManager.gd")
const SeasonStateManager = preload("res://scripts/core/state/SeasonStateManager.gd")
const DevelopmentConfig = preload("res://scripts/support/config/DevelopmentConfig.gd")
const RetirementConfig = preload("res://scripts/support/config/RetirementConfig.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")
const CollegeStatsService = preload("res://scripts/world/CollegeStatsService.gd")
const ConferenceService = preload("res://scripts/world/ConferenceService.gd")
const EarlyDeclarationService = preload("res://scripts/world/EarlyDeclarationService.gd")

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
	var transfer_rng := RandomNumberGenerator.new()
	transfer_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E5)

	var early_decl_cfg: Dictionary = config.get("early_declaration", {}) as Dictionary

	var college_index := _college_index(colleges)
	var draft_pool: Dictionary = world_state.get("draft_pool", {}) as Dictionary
	var draft_eligible: Array = draft_pool.get(year, []) as Array

	# OPTIMIZATION (F6): Pre-extract config values once for all rosters
	var dev_config := DevelopmentConfig.new(positions_cfg, main_cfg)
	var ret_config := RetirementConfig.new(main_cfg)

	# Weighted OVR System integration (Alpha - always enabled)
	# Load OVR config once (cached for all players)
	# See docs/architecture/WEIGHTED_OVR_SYSTEM.md for design details
	var ovr_calculation_cfg: Dictionary = main_cfg.get("ovr_calculation", {}) as Dictionary
	var ovr_config: Dictionary = {}
	var weights_file := String(ovr_calculation_cfg.get("weights_file", ""))
	if not weights_file.is_empty():
		ovr_config = PlayerRatingCalculator.load_ovr_config(weights_file)
		# Validate config on first load (push_error on failure)
		if not ovr_config.is_empty():
			if not PlayerRatingCalculator.validate_ovr_config(ovr_config, positions_cfg):
				push_error("OVR config validation failed - check ovr_weights.json")
				ovr_config = {}

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

	# PA6.1-PA6.2: Update player morale and satisfaction after season
	# This happens BEFORE player lifecycle, so morale affects development this year
	var morale_summary := _update_all_team_morale(
		world_state,
		year,
		rosters,
		college_index
	)

	# PA6.3: Determine transfer portal entries (before lifecycle/graduation)
	var transfer_portal_entries := _process_transfer_decisions(
		world_state,
		year,
		rosters,
		transfer_rng
	)

	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", []) as Array
		if players.is_empty():
			continue

		var college: Dictionary = college_index.get(college_id, {}) as Dictionary
		var prepared_players := _apply_development_context(players, college, config, context_rng, year)

		# Update roster in world_state with context-enriched players
		# NOTE: Direct mutation here is acceptable as it's preparatory work for
		# PlayerStateManager. The development context must be in place before
		# the lifecycle simulation. This is distinct from the "roster preparation"
		# done by SeasonTransformations.prepare_roster() which adds simulation fields.
		roster["players"] = prepared_players
		rosters[college_id] = roster
		world_state["college_rosters"] = rosters

		# NEW ARCHITECTURE: Use PlayerStateManager with pure function pipeline
		# Build configs dictionary for pure functions
		var configs := {
			"positions": positions_cfg,
			"main": main_cfg,
			"stats": stats_cfg
		}

		# Call PlayerStateManager with pure function pipeline
		# RNG consumption: ~20-30 calls per player per year (deterministic)
		# Context is already embedded in each player's development_context field
		var result := PlayerStateManager.advance_players_one_year(
			world_state,
			["college_rosters", college_id, "players"],
			{},  # Empty global context - all context is per-player
			configs,
			lifecycle_rng
		)

		# Extract updated players from world_state (PlayerStateManager updates it atomically)
		roster = rosters.get(college_id, {}) as Dictionary
		var updated_players: Array = roster.get("players", []) as Array
		var active: Array = []
		var class_years := {1: [], 2: [], 3: [], 4: []}

		# Process draft eligibility for each player
		# NOTE: College draft eligibility has complex business logic (rating thresholds,
		# early declaration advisory system) that doesn't fit into the generic
		# SeasonStateManager.process_draft_eligibility() method. This logic must
		# remain inline until we have a more flexible eligibility system.
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
			var player_rating := 0.0
			var class_rules: Dictionary = main_cfg.get("class_rules", {}) as Dictionary

			if new_year >= 4:
				# Seniors: Only declare if rating meets threshold
				# OPTIMIZATION: Draft Declaration Threshold (from BACKWARD_CLASS_SIZING.md)
				# Purpose: Reduce draft pool from ~2,900 to ~520 players (82% reduction)
				# Expected impact: Faster draft processing during bootstrap
				total_graduates += 1
				var draft_threshold_cfg: Dictionary = config.get("draft_declaration", {}) as Dictionary
				var rating_threshold := float(draft_threshold_cfg.get("rating_threshold", 65.0))
				# Calculate weighted OVR for draft eligibility
				var position := String(p.get("position", ""))
				player_rating = PlayerRatingCalculator.calculate_weighted_ovr(p, position, ovr_config)
				if player_rating >= rating_threshold:
					is_draft_eligible = true
			elif new_year == 3:
				# PHASE 8: Early Declaration Advisory System
				# Replace simple check with multi-factor advisory system
				if EarlyDeclarationService.simulate_declaration_decision(
					p, year, positions_cfg, main_cfg, early_decl_cfg, early_decl_rng
				):
					is_draft_eligible = true
					total_early_declares += 1
					# Calculate weighted OVR for early declares (used for draft grade display)
					var position := String(p.get("position", ""))
					player_rating = PlayerRatingCalculator.calculate_weighted_ovr(p, position, ovr_config)

			if is_draft_eligible:
				p["draft_eligible"] = true
				p["draft_year"] = year
				# Store composite_score for UI display (draft grades, ratings, etc.)
				p["composite_score"] = player_rating
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

	# Update draft pool with newly eligible players
	# NOTE: Direct mutation of draft_pool is acceptable here as this is a
	# collection-level operation that aggregates players from multiple rosters.
	# The manager's process_draft_eligibility() is designed for per-roster operations,
	# whereas this is a global pool assembly.
	draft_pool[year] = draft_eligible
	world_state["draft_pool"] = draft_pool

	# PHASE 1: Update college stat analysis for draft evaluation
	# This computes efficiency metrics and production trajectories
	# RNG: None (pure calculation)
	if options.get("enable_stat_analysis", true):
		_update_college_stat_analysis(world_state, year, positions_cfg, config)

	return {
		"year": year,
		"rosters_updated": rosters_updated,
		"graduates": total_graduates,
		"draft_eligible_count": draft_eligible.size(),
		"early_declares": total_early_declares,
		"game_simulation": game_sim_summary,
		"morale": morale_summary,
		"transfer_portal_entries": transfer_portal_entries,
		"step_seeds": {
			"lifecycle": lifecycle_rng.seed,
			"context": context_rng.seed,
			"early_declaration": early_decl_rng.seed,
			"transfer": transfer_rng.seed,
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
		var p = players[i]  # No type annotation - array can contain nulls
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

## DEPRECATED: Use EarlyDeclarationService.simulate_declaration_decision() instead
##
## This method is preserved for backward compatibility and reference.
## Phase 8 introduced a more sophisticated advisory system with multi-factor
## decision making, agent influence, and return-to-school bonuses.
##
## See: EarlyDeclarationService for the new implementation
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

	# A2 Optimization: Pre-compute all team strengths in batch (once per season)
	# This eliminates redundant roster traversals and rating calculations
	# Expected RNG consumption: None (pure calculation)
	var college_ids := []
	for college in colleges:
		var c: Dictionary = college
		college_ids.append(String(c.get("id", "")))

	var team_strengths := GameSimulator.calculate_all_team_strengths(
		college_ids,
		rosters,
		positions_cfg,
		main_cfg
	)

	# A1 Optimization: Pre-compute starters for all teams (once per season)
	# This reduces starter determination from O(games × teams × n log n) to O(teams × n log n)
	# Expected RNG consumption: None (pure calculation)
	# Expected time savings: ~8.5 seconds over 20 years for college season
	if not world_state.has("starter_cache"):
		world_state["starter_cache"] = {}
	var starter_cache: Dictionary = world_state["starter_cache"]
	if not starter_cache.has(year):
		starter_cache[year] = {}
	var year_cache: Dictionary = starter_cache[year]

	for college_id in college_ids:
		if rosters.has(college_id):
			var roster: Dictionary = rosters[college_id]
			var starters := StatGenerator.compute_starters(roster, positions_cfg, main_cfg)
			year_cache[college_id] = starters

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
		var home_roster: Dictionary = rosters.get(home_id, {})
		var away_roster: Dictionary = rosters.get(away_id, {})

		if not home_roster.is_empty() and not away_roster.is_empty():
			# Use cached starters for performance (A1 optimization)
			var home_starters: Dictionary = year_cache.get(home_id, {})
			var away_starters: Dictionary = year_cache.get(away_id, {})

			GameSimulator.accumulate_player_stats(
				world_state,
				result,
				home_roster,
				away_roster,
				positions_cfg,
				main_cfg,
				rng,
				home_starters,
				away_starters
			)

	# Aggregate results (G1.2: Season W-L Records, G1.8: Strength of Schedule)
	# Expected RNG consumption: None (pure aggregation via SeasonStateManager)
	# Note: college_ids already computed above during strength calculation

	# Use SeasonStateManager to record all game results atomically
	# This ensures proper DataBus notifications and maintains architectural consistency
	var standings_path := ["season_records", year]
	var record_result := SeasonStateManager.record_game_results(
		world_state,
		standings_path,
		all_results
	)

	# Extract updated standings from world_state (manager updated it atomically)
	var season_records: Dictionary = world_state.get("season_records", {})
	var season_results: Dictionary = season_records.get(year, {})

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

	# PHASE 2: Calculate strength of schedule for all colleges
	# RNG: None (pure calculation)
	_update_strength_of_schedule(world_state, year, season_results, college_ids)

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


## Updates morale and satisfaction for all players across all college teams.
##
## Implements PA6.1 (Satisfaction Calculation) and PA6.2 (Morale System).
##
## RNG Pattern: None (satisfaction and morale updates are deterministic)
## Performance: O(n) where n = total players across all rosters
##
## Parameters:
##   world_state: Dictionary containing player_career_stats, awards, season_records, championships
##   year: Current season year
##   rosters: Dictionary of college_id -> roster
##   college_index: Dictionary mapping college_id -> college data
##
## Returns:
##   Dictionary with summary: {teams_processed, players_updated, avg_satisfaction, avg_morale}
##
## Side Effects:
##   Modifies each player's "satisfaction" and "morale" fields in-place
func _update_all_team_morale(
	world_state: Dictionary,
	year: int,
	rosters: Dictionary,
	college_index: Dictionary
) -> Dictionary:
	var player_career_stats: Dictionary = world_state.get("player_career_stats", {})
	var season_records: Dictionary = world_state.get("season_records", {}).get(str(year), {})
	var championships: Dictionary = world_state.get("championships", {})

	# A4 Optimization: Pre-build awards data structure once for all teams
	# This eliminates redundant lookups across 130 teams × 60 players = 7,800 players
	var awards := {
		"awards": world_state.get("awards", {}),
		"all_pro_teams": world_state.get("all_pro_teams", {}),
		"pro_bowl_rosters": world_state.get("pro_bowl_rosters", {})
	}

	# Determine playoff teams and champion
	var national_champion_id := String(championships.get("college", {}).get("national_champions", {}).get(str(year), ""))
	var playoff_teams: Array = []
	if not season_records.is_empty():
		playoff_teams = _determine_college_playoff_teams(season_records)

	var teams_processed := 0
	var total_players_updated := 0
	var total_satisfaction := 0.0
	var total_morale := 0.0

	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", [])
		if players.is_empty():
			continue

		# Build team record with playoff/champion flags
		var team_record: Dictionary = season_records.get(college_id, {}).duplicate()
		team_record["is_champion"] = (college_id == national_champion_id)
		team_record["playoff_appearance"] = (college_id in playoff_teams)

		# A4 Optimization: Pre-batch team data for efficient morale updates
		# This eliminates per-player dictionary lookups by pre-fetching all data once
		var batched_data := PlayerMorale.prepare_team_batched_data(
			players,
			year,
			player_career_stats,
			awards,
			team_record
		)

		# Update morale for entire team using batched data
		var summary := PlayerMorale.update_team_morale_batched(
			players,
			year,
			batched_data
		)

		teams_processed += 1
		total_players_updated += int(summary.get("players_updated", 0))
		total_satisfaction += float(summary.get("avg_satisfaction", 0.0)) * float(summary.get("players_updated", 0))
		total_morale += float(summary.get("avg_morale", 0.0)) * float(summary.get("players_updated", 0))

	return {
		"teams_processed": teams_processed,
		"players_updated": total_players_updated,
		"avg_satisfaction": total_satisfaction / float(total_players_updated) if total_players_updated > 0 else 0.0,
		"avg_morale": total_morale / float(total_players_updated) if total_players_updated > 0 else 0.0
	}


## Processes transfer portal decisions for all college players.
##
## Implements PA6.3 (Transfer Decisions Based on Satisfaction).
##
## RNG Pattern: Exactly 1 randf() per eligible player (non-seniors)
## Performance: O(n) where n = total players across all rosters
##
## Parameters:
##   world_state: Dictionary (will store transfer_portal data)
##   year: Current season year
##   rosters: Dictionary of college_id -> roster
##   rng: RandomNumberGenerator (explicit, caller-controlled)
##
## Returns:
##   int: Number of players who entered the transfer portal
##
## Side Effects:
##   - Stores transfer portal players in world_state["transfer_portal"][year]
##   - Does NOT remove players from rosters (they remain until next season)
func _process_transfer_decisions(
	world_state: Dictionary,
	year: int,
	rosters: Dictionary,
	rng: RandomNumberGenerator
) -> int:
	var transfer_portal: Dictionary = world_state.get("transfer_portal", {})
	if not transfer_portal.has(str(year)):
		transfer_portal[str(year)] = []

	var year_transfers: Array = transfer_portal[str(year)]
	var total_transfers := 0

	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", [])
		if players.is_empty():
			continue

		# Determine which players enter transfer portal
		var transfer_players := PlayerMorale.determine_transfers(players, rng)

		# Add to portal with metadata
		for player in transfer_players:
			var p: Dictionary = player
			var transfer_entry := p.duplicate()
			transfer_entry["transfer_year"] = year
			transfer_entry["previous_team_id"] = college_id
			year_transfers.append(transfer_entry)
			total_transfers += 1

	transfer_portal[str(year)] = year_transfers
	world_state["transfer_portal"] = transfer_portal

	return total_transfers


## Updates college stat analysis for all players with career stats.
##
## Implements Phase 1: College Performance Statistics
##   - Calculates efficiency metrics (QBR, yards per carry, etc.)
##   - Analyzes production trajectories (rising, declining, stable)
##   - Computes career totals
##
## RNG Pattern: None (pure calculation)
## Performance: O(players with stats) = ~500 draft-eligible players
##
## Parameters:
##   world_state: Dictionary containing player_career_stats
##   year: Current season year
##   positions_cfg: Position configuration
##   config: Season configuration
##
## Side Effects:
##   Stores computed analysis in world_state["college_stat_analysis"]
func _update_college_stat_analysis(
	world_state: Dictionary,
	year: int,
	positions_cfg: Dictionary,
	config: Dictionary
) -> void:
	var career_stats: Dictionary = world_state.get("player_career_stats", {})
	var analysis: Dictionary = world_state.get("college_stat_analysis", {})

	for player_id in career_stats.keys():
		var player_years: Dictionary = career_stats[player_id]
		if not player_years.has(year):
			continue

		# Calculate efficiency metrics for this season
		var efficiency := CollegeStatsService.calculate_efficiency_metrics(
			player_id, year, career_stats, positions_cfg
		)

		# Analyze production trajectory
		var trajectory := CollegeStatsService.analyze_production_trajectory(
			player_id, career_stats, positions_cfg
		)

		# Get career totals
		var totals := CollegeStatsService.get_career_totals(
			player_id, career_stats
		)

		analysis[player_id] = {
			"efficiency_metrics": efficiency,
			"trajectory": trajectory,
			"career_totals": totals
		}

	world_state["college_stat_analysis"] = analysis


## Updates strength of schedule for all colleges based on season results.
##
## Implements Phase 2: Conference/Competition Level Weighting
##   - Calculates strength of schedule based on opponents' conference tiers
##   - Stores SOS in each college's data
##
## RNG Pattern: None (pure calculation)
## Performance: O(colleges) = ~130 operations
##
## Parameters:
##   world_state: Dictionary containing colleges array
##   year: Current season year
##   season_results: Dictionary of team_id -> season record
##   college_ids: Array of all college IDs (for performance)
##
## Side Effects:
##   Updates world_state["colleges"][i]["strength_of_schedule"] in-place
func _update_strength_of_schedule(
	world_state: Dictionary,
	year: int,
	season_results: Dictionary,
	college_ids: Array
) -> void:
	var colleges: Array = world_state.get("colleges", [])

	# Build college index for fast lookups
	var college_index := {}
	for college in colleges:
		var c: Dictionary = college
		var id := String(c.get("id", ""))
		if not id.is_empty():
			college_index[id] = c

	# Calculate SOS for each college
	for college in colleges:
		var c: Dictionary = college
		var college_id := String(c.get("id", ""))

		var sos := ConferenceService.calculate_strength_of_schedule_indexed(
			college_id,
			season_results,
			college_index
		)

		c["strength_of_schedule"] = sos
