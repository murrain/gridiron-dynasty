extends RefCounted
class_name StatGenerator

## Player Stat Generation Engine
##
## Generates realistic position-specific statistics for players during game simulation.
## All functions are static and pure (except where explicit RNG is passed).
##
## Phase 1 Implementation:
## - Position-specific stat generation (QB, RB, WR, TE, OL, DL, EDGE, LB, CB, S)
## - Rating-based stat scaling (higher rating = better stats)
## - Win/loss context influences performance
## - Games played/started tracking
## - Deterministic generation with explicit RNG
##
## RNG Pattern: All probabilistic functions accept RandomNumberGenerator as explicit parameter.
## Never creates new RNG instances internally - caller controls seeding for determinism.
##
## Data Model:
## player_career_stats[player_id][year] = {
##   "year": int,
##   "team_id": string,
##   "games_played": int,
##   "games_started": int,
##   "position": string,
##   ... position-specific stats ...
## }

const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Position-specific stat weights for determining starters
## Higher weight = more important for starting determination
const STARTER_POSITION_THRESHOLDS := {
	# Offense
	"QB": 1,      # 1 starter
	"RB": 2,      # 2 starting RBs
	"WR": 3,      # 3 starting WRs
	"TE": 1,      # 1 starting TE
	"OL": 5,      # 5 starting OL
	"OT": 2,      # 2 starting OTs (if separate from OL)
	"OG": 2,      # 2 starting OGs (if separate from OL)
	"C": 1,       # 1 starting C (if separate from OL)

	# Defense
	"DL": 4,      # 4 starting DL
	"EDGE": 2,    # 2 starting EDGE
	"DT": 2,      # 2 starting DTs (if separate from DL)
	"DE": 2,      # 2 starting DEs (if separate from DL)
	"LB": 3,      # 3 starting LBs
	"CB": 2,      # 2 starting CBs
	"S": 2,       # 2 starting Safeties

	# Special Teams
	"K": 1,       # 1 starting Kicker
	"P": 1        # 1 starting Punter
}


## Pre-computes starters for a team based on roster and ratings.
##
## This function should be called once per team per season to cache starters,
## avoiding repeated O(n log n) sorts for every game (Phase A Optimization A1).
##
## RNG Consumption: None (pure calculation)
## Performance: O(n log n) where n = roster size
##
## Parameters:
##   roster: Dictionary with "players" array
##   positions_cfg: Position configuration
##   main_cfg: Main configuration
##
## Returns:
##   Dictionary: Set of starter player_ids (player_id -> true)
static func compute_starters(
	roster: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var players: Array = roster.get("players", [])
	if players.is_empty():
		return {}

	return _determine_starters(players, positions_cfg, main_cfg)


## Generates stat lines for all active players on both teams.
##
## RNG Consumption: Variable based on position-specific algorithms (documented per function)
## Performance: O(n) where n = total players (~50-100 players per game)
##
## Algorithm:
##   1. Determine starters for each team based on ratings (or use cached starters)
##   2. Generate position-specific stats for each player
##   3. Track games_played and games_started
##   4. Return dictionary mapping player_id -> stat_line
##
## Parameters:
##   home_roster: Dictionary with "players" array
##   away_roster: Dictionary with "players" array
##   game_result: GameResult dictionary from GameSimulator
##   positions_cfg: Position configuration
##   main_cfg: Main configuration
##   rng: RandomNumberGenerator (explicit, caller-controlled)
##   cached_home_starters: Optional pre-computed starters for home team (optimization)
##   cached_away_starters: Optional pre-computed starters for away team (optimization)
##
## Returns:
##   Dictionary: {player_id: stat_line_dict}
##
## Edge Cases:
##   - Empty roster: Returns empty dict
##   - Missing position: Returns basic games_played/started only
##   - Invalid ratings: Defaults to 50.0
##
## Optimization Note (A1):
##   When cached_home_starters and cached_away_starters are provided, this function
##   skips the O(n log n) starter determination per team, reducing from O(games × teams × n log n)
##   to O(teams × n log n) complexity for an entire season.
static func generate_game_stats(
	home_roster: Dictionary,
	away_roster: Dictionary,
	game_result: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator,
	cached_home_starters: Dictionary = {},
	cached_away_starters: Dictionary = {}
) -> Dictionary:
	var all_stats := {}

	# Process home team
	# RNG consumption: Variable per player (documented in _generate_player_stats)
	var home_stats := _generate_team_game_stats(
		home_roster,
		game_result,
		true,  # is_home
		positions_cfg,
		main_cfg,
		rng,
		cached_home_starters
	)
	for player_id in home_stats.keys():
		all_stats[player_id] = home_stats[player_id]

	# Process away team
	# RNG consumption: Variable per player (documented in _generate_player_stats)
	var away_stats := _generate_team_game_stats(
		away_roster,
		game_result,
		false,  # is_home
		positions_cfg,
		main_cfg,
		rng,
		cached_away_starters
	)
	for player_id in away_stats.keys():
		all_stats[player_id] = away_stats[player_id]

	return all_stats


## Generates stats for all players on a single team.
##
## RNG Consumption: Variable per player (documented in _generate_player_stats)
##
## Algorithm:
##   1. Determine starters by position and rating (or use cached starters)
##   2. Generate stats for each player
##   3. Mark starters vs bench players
##
## Parameters:
##   cached_starters: Optional pre-computed starters (optimization A1)
##
## Returns:
##   Dictionary: {player_id: stat_line_dict}
static func _generate_team_game_stats(
	roster: Dictionary,
	game_result: Dictionary,
	is_home: bool,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator,
	cached_starters: Dictionary = {}
) -> Dictionary:
	var players: Array = roster.get("players", [])
	if players.is_empty():
		return {}

	var team_id := String(game_result.get("home_team_id" if is_home else "away_team_id", ""))
	var won := _determine_team_won(game_result, team_id)

	# Determine starters by position (use cache if available, otherwise compute)
	# RNG consumption: None (pure sorting/selection)
	var starters: Dictionary
	if not cached_starters.is_empty():
		# Use cached starters (A1 optimization - avoids O(n log n) sort)
		starters = cached_starters
	else:
		# Fallback: Compute starters on-the-fly (legacy behavior)
		starters = _determine_starters(players, positions_cfg, main_cfg)

	# Generate stats for each player
	var team_stats := {}
	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		if player_id == "":
			continue

		var is_starter := starters.has(player_id)

		# RNG consumption: Variable per position (see _generate_player_stats)
		var stat_line := _generate_player_stats(
			p,
			game_result,
			is_home,
			won,
			is_starter,
			positions_cfg,
			main_cfg,
			rng
		)

		team_stats[player_id] = stat_line

	return team_stats


## Determines which players are starters based on position and rating.
##
## RNG Consumption: None (pure calculation)
## Performance: O(n log n) where n = roster size
##
## Algorithm:
##   1. Group players by position
##   2. Sort each position group by overall rating (descending)
##   3. Select top N players per position based on STARTER_POSITION_THRESHOLDS
##
## Returns:
##   Dictionary: Set of starter player_ids
static func _determine_starters(
	players: Array,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var starters := {}
	var by_position := {}

	var class_rules: Dictionary = main_cfg.get("class_rules", {})

	# Group players by position with their ratings
	# Expected RNG consumption: None (pure grouping)
	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		if position == "":
			continue

		var rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)

		if not by_position.has(position):
			by_position[position] = []

		(by_position[position] as Array).append({
			"player_id": String(p.get("player_id", "")),
			"rating": rating
		})

	# Select top N players per position
	# Expected RNG consumption: None (pure sorting/selection)
	for position in by_position.keys():
		var position_players: Array = by_position[position]
		var threshold := int(STARTER_POSITION_THRESHOLDS.get(position, 1))

		# Sort by rating (descending)
		position_players.sort_custom(func(a, b): return a["rating"] > b["rating"])

		# Select top N as starters
		for i in range(min(threshold, position_players.size())):
			var entry: Dictionary = position_players[i]
			starters[entry["player_id"]] = true

	return starters


## Determines if a team won the game.
##
## RNG Consumption: None (pure lookup)
static func _determine_team_won(game_result: Dictionary, team_id: String) -> bool:
	return String(game_result.get("winner_id", "")) == team_id


## Generates stat line for a single player.
##
## RNG Consumption: Variable based on position (0-5 calls per player)
## Performance: O(1) per player
##
## Algorithm:
##   1. Base stats on player rating and position
##   2. Apply win/loss modifier
##   3. Apply starter/bench modifier
##   4. Add variance using RNG
##   5. Return complete stat line
##
## Parameters:
##   player: Player dictionary
##   game_result: GameResult dictionary
##   is_home: Is player on home team
##   won: Did player's team win
##   is_starter: Is player a starter
##   positions_cfg: Position configuration
##   main_cfg: Main configuration
##   rng: RandomNumberGenerator
##
## Returns:
##   Dictionary: Complete stat line for player
static func _generate_player_stats(
	player: Dictionary,
	game_result: Dictionary,
	is_home: bool,
	won: bool,
	is_starter: bool,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var position := String(player.get("position", ""))
	var class_rules: Dictionary = main_cfg.get("class_rules", {})
	var rating := PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)

	var team_id := String(game_result.get("home_team_id" if is_home else "away_team_id", ""))
	var year := int(game_result.get("year", 0))

	# Base stat line (all positions get this)
	var stats := {
		"year": year,
		"team_id": team_id,
		"games_played": 1,
		"games_started": 1 if is_starter else 0,
		"position": position
	}

	# Generate position-specific stats
	# RNG consumption varies by position (documented in each function)
	match position:
		"QB":
			stats.merge(_generate_qb_stats(rating, won, is_starter, rng))
		"RB":
			stats.merge(_generate_rb_stats(rating, won, is_starter, rng))
		"WR":
			stats.merge(_generate_wr_stats(rating, won, is_starter, rng))
		"TE":
			stats.merge(_generate_te_stats(rating, won, is_starter, rng))
		"DL", "DT", "DE":
			stats.merge(_generate_dl_stats(rating, won, is_starter, rng))
		"EDGE":
			stats.merge(_generate_edge_stats(rating, won, is_starter, rng))
		"LB":
			stats.merge(_generate_lb_stats(rating, won, is_starter, rng))
		"CB":
			stats.merge(_generate_cb_stats(rating, won, is_starter, rng))
		"S":
			stats.merge(_generate_s_stats(rating, won, is_starter, rng))
		"K":
			stats.merge(_generate_k_stats(rating, won, is_starter, rng))
		"P":
			stats.merge(_generate_p_stats(rating, won, is_starter, rng))
		_:
			# Unknown position - just games played/started
			pass

	return stats


## Generates QB statistics.
##
## RNG Consumption: 5 calls (pass_attempts variance, completions variance, yards variance, TDs roll, INTs roll)
##
## Base Formula:
##   - pass_attempts = 25 + (rating - 50) * 0.5 + variance
##   - completions = attempts * (0.55 + rating/200) + variance
##   - yards = completions * (10 + rating/10) + variance
##   - TDs = base(rating/20) + win_bonus + variance
##   - INTs = max(0, (100-rating)/15) + variance
##
## Modifiers:
##   - Win: +1 TD, -0.5 INTs
##   - Starter: 100% stats, Bench: 20% stats
static func _generate_qb_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.2

	# Pass attempts: 25-50 depending on rating
	# RNG CALL 1: Variance for attempts
	var base_attempts := 25.0 + (rating - 50.0) * 0.5
	var attempts := int(base_attempts * base_mult + rng.randf_range(-2.0, 2.0))
	attempts = max(1, attempts)

	# Completion percentage: 55-70% depending on rating
	# RNG CALL 2: Variance for completions
	var completion_pct := 0.55 + rating / 200.0
	var completions := int(float(attempts) * completion_pct * base_mult + rng.randf_range(-2.0, 2.0))
	completions = clamp(completions, 0, attempts)

	# Yards per completion: 10-20 depending on rating
	# RNG CALL 3: Variance for yards
	var yards_per_comp := 10.0 + rating / 10.0
	var yards := int(float(completions) * yards_per_comp + rng.randf_range(-20.0, 20.0))
	yards = max(0, yards)

	# Touchdowns: 1-3 per game for good QBs
	# RNG CALL 4: Variance for TDs
	var base_tds := rating / 20.0
	if won:
		base_tds += 1.0
	var tds := int(base_tds * base_mult + rng.randf_range(-0.5, 0.5))
	tds = max(0, tds)

	# Interceptions: 0-2 per game (fewer for better QBs)
	# RNG CALL 5: Variance for INTs
	var base_ints := (100.0 - rating) / 15.0
	if won:
		base_ints -= 0.5
	var ints := int(base_ints * base_mult + rng.randf_range(-0.3, 0.3))
	ints = max(0, ints)

	return {
		"pass_attempts": attempts,
		"pass_completions": completions,
		"pass_yards": yards,
		"pass_tds": tds,
		"interceptions": ints,
		"sacks_taken": int(attempts * 0.05 * base_mult)  # ~5% sack rate
	}


## Generates RB statistics.
##
## RNG Consumption: 4 calls (attempts variance, yards variance, TDs roll, receptions variance)
##
## Base Formula:
##   - rush_attempts = 15 + (rating - 50) * 0.3 + variance
##   - rush_yards = attempts * (3 + rating/25) + variance
##   - rush_tds = base(rating/30) + win_bonus + variance
##   - receptions = base(rating/20) + variance
static func _generate_rb_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.3

	# Rush attempts: 15-30 depending on rating
	# RNG CALL 1: Variance for attempts
	var base_attempts := 15.0 + (rating - 50.0) * 0.3
	var attempts := int(base_attempts * base_mult + rng.randf_range(-2.0, 2.0))
	attempts = max(1, attempts)

	# Yards per carry: 3-7 depending on rating
	# RNG CALL 2: Variance for yards
	var yards_per_carry := 3.0 + rating / 25.0
	var yards := int(float(attempts) * yards_per_carry + rng.randf_range(-10.0, 10.0))
	yards = max(0, yards)

	# Touchdowns: 0-2 per game
	# RNG CALL 3: Variance for TDs
	var base_tds := rating / 30.0
	if won:
		base_tds += 0.5
	var tds := int(base_tds * base_mult + rng.randf_range(-0.3, 0.3))
	tds = max(0, tds)

	# Receptions: 2-6 per game (modern RBs catch passes)
	# RNG CALL 4: Variance for receptions
	var base_rec := rating / 20.0
	var receptions := int(base_rec * base_mult + rng.randf_range(-1.0, 1.0))
	receptions = max(0, receptions)

	var rec_yards := int(float(receptions) * 7.0)  # ~7 yards per reception

	return {
		"rush_attempts": attempts,
		"rush_yards": yards,
		"rush_tds": tds,
		"receptions": receptions,
		"receiving_yards": rec_yards,
		"receiving_tds": 0,  # Rare for RBs in Phase 1
		"fumbles": int(attempts * 0.02 * base_mult)  # ~2% fumble rate
	}


## Generates WR statistics.
##
## RNG Consumption: 4 calls (targets variance, receptions variance, yards variance, TDs roll)
##
## Base Formula:
##   - targets = 8 + (rating - 50) * 0.2 + variance
##   - receptions = targets * 0.6 + variance
##   - yards = receptions * (12 + rating/8) + variance
##   - tds = base(rating/40) + win_bonus + variance
static func _generate_wr_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.4

	# Targets: 8-18 depending on rating
	# RNG CALL 1: Variance for targets
	var base_targets := 8.0 + (rating - 50.0) * 0.2
	var targets := int(base_targets * base_mult + rng.randf_range(-2.0, 2.0))
	targets = max(1, targets)

	# Catch rate: ~60% base
	# RNG CALL 2: Variance for receptions
	var catch_rate := 0.6 + rating / 300.0
	var receptions := int(float(targets) * catch_rate + rng.randf_range(-1.0, 1.0))
	receptions = clamp(receptions, 0, targets)

	# Yards per reception: 12-25 depending on rating
	# RNG CALL 3: Variance for yards
	var yards_per_rec := 12.0 + rating / 8.0
	var yards := int(float(receptions) * yards_per_rec + rng.randf_range(-15.0, 15.0))
	yards = max(0, yards)

	# Touchdowns: 0-2 per game
	# RNG CALL 4: Variance for TDs
	var base_tds := rating / 40.0
	if won:
		base_tds += 0.3
	var tds := int(base_tds * base_mult + rng.randf_range(-0.2, 0.2))
	tds = max(0, tds)

	return {
		"targets": targets,
		"receptions": receptions,
		"receiving_yards": yards,
		"receiving_tds": tds,
		"drops": int(targets * 0.1 * base_mult),  # ~10% drop rate
		"fumbles": int(receptions * 0.01 * base_mult)  # ~1% fumble rate
	}


## Generates TE statistics.
##
## RNG Consumption: 4 calls (targets variance, receptions variance, yards variance, TDs roll)
##
## Similar to WR but lower volume
static func _generate_te_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.4

	# Targets: 5-12 depending on rating (less than WR)
	# RNG CALL 1: Variance for targets
	var base_targets := 5.0 + (rating - 50.0) * 0.15
	var targets := int(base_targets * base_mult + rng.randf_range(-1.5, 1.5))
	targets = max(1, targets)

	# Catch rate: ~65% base (TEs more reliable)
	# RNG CALL 2: Variance for receptions
	var catch_rate := 0.65 + rating / 350.0
	var receptions := int(float(targets) * catch_rate + rng.randf_range(-1.0, 1.0))
	receptions = clamp(receptions, 0, targets)

	# Yards per reception: 10-18 depending on rating
	# RNG CALL 3: Variance for yards
	var yards_per_rec := 10.0 + rating / 12.0
	var yards := int(float(receptions) * yards_per_rec + rng.randf_range(-10.0, 10.0))
	yards = max(0, yards)

	# Touchdowns: 0-1 per game
	# RNG CALL 4: Variance for TDs
	var base_tds := rating / 50.0
	if won:
		base_tds += 0.2
	var tds := int(base_tds * base_mult + rng.randf_range(-0.2, 0.2))
	tds = max(0, tds)

	return {
		"targets": targets,
		"receptions": receptions,
		"receiving_yards": yards,
		"receiving_tds": tds,
		"drops": int(targets * 0.08 * base_mult),  # ~8% drop rate (better than WR)
		"blocks": int(10.0 * base_mult)  # TE blocking contribution
	}


## Generates DL statistics.
##
## RNG Consumption: 3 calls (tackles variance, sacks variance, TFL variance)
static func _generate_dl_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.3

	# Tackles: 3-8 per game
	# RNG CALL 1: Variance for tackles
	var base_tackles := 3.0 + (rating - 50.0) * 0.1
	var tackles := int(base_tackles * base_mult + rng.randf_range(-1.0, 1.0))
	tackles = max(0, tackles)

	# Sacks: 0-2 per game
	# RNG CALL 2: Variance for sacks
	var base_sacks := rating / 35.0
	if won:
		base_sacks += 0.3
	var sacks := int(base_sacks * base_mult + rng.randf_range(-0.3, 0.3))
	sacks = max(0, sacks)

	# Tackles for loss: 0-3 per game
	# RNG CALL 3: Variance for TFL
	var base_tfl := rating / 30.0
	var tfl := int(base_tfl * base_mult + rng.randf_range(-0.5, 0.5))
	tfl = max(0, tfl)

	return {
		"tackles": tackles,
		"assists": int(float(tackles) * 0.5),
		"sacks": sacks,
		"tackles_for_loss": tfl,
		"qb_hits": int(float(sacks) * 1.5),
		"pressures": int(rating / 10.0 * base_mult)
	}


## Generates EDGE statistics.
##
## RNG Consumption: 3 calls (tackles variance, sacks variance, TFL variance)
##
## Similar to DL but higher sack potential
static func _generate_edge_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.3

	# Tackles: 4-9 per game (more than DL)
	# RNG CALL 1: Variance for tackles
	var base_tackles := 4.0 + (rating - 50.0) * 0.1
	var tackles := int(base_tackles * base_mult + rng.randf_range(-1.0, 1.0))
	tackles = max(0, tackles)

	# Sacks: 0-3 per game (higher than DL)
	# RNG CALL 2: Variance for sacks
	var base_sacks := rating / 30.0
	if won:
		base_sacks += 0.4
	var sacks := int(base_sacks * base_mult + rng.randf_range(-0.4, 0.4))
	sacks = max(0, sacks)

	# Tackles for loss: 1-4 per game
	# RNG CALL 3: Variance for TFL
	var base_tfl := rating / 25.0
	var tfl := int(base_tfl * base_mult + rng.randf_range(-0.5, 0.5))
	tfl = max(0, tfl)

	return {
		"tackles": tackles,
		"assists": int(float(tackles) * 0.5),
		"sacks": sacks,
		"tackles_for_loss": tfl,
		"qb_hits": int(float(sacks) * 2.0),
		"pressures": int(rating / 8.0 * base_mult),
		"forced_fumbles": int(tackles * 0.05 * base_mult)
	}


## Generates LB statistics.
##
## RNG Consumption: 3 calls (tackles variance, TFL variance, pass defense variance)
static func _generate_lb_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.3

	# Tackles: 6-12 per game (most tackles of any position)
	# RNG CALL 1: Variance for tackles
	var base_tackles := 6.0 + (rating - 50.0) * 0.12
	var tackles := int(base_tackles * base_mult + rng.randf_range(-1.5, 1.5))
	tackles = max(0, tackles)

	# Tackles for loss: 0-2 per game
	# RNG CALL 2: Variance for TFL
	var base_tfl := rating / 35.0
	var tfl := int(base_tfl * base_mult + rng.randf_range(-0.4, 0.4))
	tfl = max(0, tfl)

	# Pass defense (pass breakups): 0-2 per game
	# RNG CALL 3: Variance for pass defense
	var base_pd := rating / 40.0
	var pd := int(base_pd * base_mult + rng.randf_range(-0.3, 0.3))
	pd = max(0, pd)

	return {
		"tackles": tackles,
		"assists": int(float(tackles) * 0.6),
		"tackles_for_loss": tfl,
		"sacks": int(rating / 50.0 * base_mult),  # LBs get some sacks
		"pass_breakups": pd,
		"interceptions": int(pd * 0.15),  # ~15% of PBUs become INTs
		"forced_fumbles": int(tackles * 0.03 * base_mult)
	}


## Generates CB statistics.
##
## RNG Consumption: 3 calls (tackles variance, pass defense variance, interceptions roll)
static func _generate_cb_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.3

	# Tackles: 3-7 per game
	# RNG CALL 1: Variance for tackles
	var base_tackles := 3.0 + (rating - 50.0) * 0.08
	var tackles := int(base_tackles * base_mult + rng.randf_range(-1.0, 1.0))
	tackles = max(0, tackles)

	# Pass breakups: 1-4 per game (primary role)
	# RNG CALL 2: Variance for pass defense
	var base_pd := 1.0 + rating / 30.0
	var pd := int(base_pd * base_mult + rng.randf_range(-0.5, 0.5))
	pd = max(0, pd)

	# Interceptions: 0-1 per game (rare)
	# RNG CALL 3: Roll for interceptions
	var base_ints := rating / 60.0
	if won:
		base_ints += 0.2
	var ints := int(base_ints * base_mult + rng.randf_range(-0.2, 0.2))
	ints = max(0, ints)

	return {
		"tackles": tackles,
		"assists": int(float(tackles) * 0.4),
		"pass_breakups": pd,
		"interceptions": ints,
		"interception_yards": int(float(ints) * 15.0),  # Avg ~15 yards per INT
		"targets_allowed": int(6.0 * base_mult),
		"completions_allowed": int(4.0 * base_mult)
	}


## Generates S statistics.
##
## RNG Consumption: 3 calls (tackles variance, pass defense variance, interceptions roll)
##
## Similar to CB but more tackles, fewer pass breakups
static func _generate_s_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.3

	# Tackles: 5-10 per game (more than CB)
	# RNG CALL 1: Variance for tackles
	var base_tackles := 5.0 + (rating - 50.0) * 0.1
	var tackles := int(base_tackles * base_mult + rng.randf_range(-1.0, 1.0))
	tackles = max(0, tackles)

	# Pass breakups: 0-2 per game (less than CB)
	# RNG CALL 2: Variance for pass defense
	var base_pd := rating / 40.0
	var pd := int(base_pd * base_mult + rng.randf_range(-0.4, 0.4))
	pd = max(0, pd)

	# Interceptions: 0-1 per game
	# RNG CALL 3: Roll for interceptions
	var base_ints := rating / 50.0
	if won:
		base_ints += 0.25
	var ints := int(base_ints * base_mult + rng.randf_range(-0.2, 0.2))
	ints = max(0, ints)

	return {
		"tackles": tackles,
		"assists": int(float(tackles) * 0.5),
		"pass_breakups": pd,
		"interceptions": ints,
		"interception_yards": int(float(ints) * 20.0),  # Avg ~20 yards per INT (more space)
		"forced_fumbles": int(tackles * 0.04 * base_mult),
		"fumble_recoveries": int(rating / 100.0 * base_mult)
	}


## Generates K statistics.
##
## RNG Consumption: 2 calls (FG attempts variance, accuracy roll)
static func _generate_k_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.0  # Only starters kick

	# Field goal attempts: 1-4 per game
	# RNG CALL 1: Variance for FG attempts
	var base_fga := 1.5 + rating / 40.0
	var fga := int(base_fga * base_mult + rng.randf_range(-0.5, 0.5))
	fga = max(0, fga)

	# Field goal percentage: 70-95% depending on rating
	# RNG CALL 2: Accuracy roll
	var fg_pct := 0.7 + rating / 333.0
	var fgm := int(float(fga) * fg_pct + rng.randf_range(-0.3, 0.3))
	fgm = clamp(fgm, 0, fga)

	# Extra points: ~2-5 per game
	var xpa := int(3.0 * base_mult)
	var xpm := int(float(xpa) * 0.95)  # 95% conversion

	return {
		"field_goals_attempted": fga,
		"field_goals_made": fgm,
		"extra_points_attempted": xpa,
		"extra_points_made": xpm,
		"longest_field_goal": int(40.0 + rating / 3.0) if fgm > 0 else 0
	}


## Generates P statistics.
##
## RNG Consumption: 2 calls (punts variance, average variance)
static func _generate_p_stats(rating: float, won: bool, is_starter: bool, rng: RandomNumberGenerator) -> Dictionary:
	var base_mult := 1.0 if is_starter else 0.0  # Only starters punt

	# Punts: 3-7 per game (more if losing)
	# RNG CALL 1: Variance for punts
	var base_punts := 4.0 + (100.0 - rating) / 20.0
	if not won:
		base_punts += 1.0  # Losing teams punt more
	var punts := int(base_punts * base_mult + rng.randf_range(-1.0, 1.0))
	punts = max(0, punts)

	# Punt average: 35-50 yards depending on rating
	# RNG CALL 2: Variance for average
	var base_avg := 35.0 + rating / 6.7
	var punt_avg := base_avg + rng.randf_range(-3.0, 3.0)
	punt_avg = clamp(punt_avg, 30.0, 60.0)

	var total_yards := int(float(punts) * punt_avg)

	return {
		"punts": punts,
		"punt_yards": total_yards,
		"punt_average": punt_avg,
		"punts_inside_20": int(float(punts) * 0.3),  # ~30% inside 20
		"touchbacks": int(float(punts) * 0.1)  # ~10% touchbacks
	}
