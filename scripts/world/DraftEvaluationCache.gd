## DraftEvaluationCache - Pre-computed draft boards for fast AI picks
##
## Optimizes draft simulation by pre-computing all 32 team draft boards at
## draft start. Each board is a sorted list of player evaluations that can
## be quickly traversed to find the best available player.
##
## Performance Targets:
## - <100ms per AI pick (vs ~500ms without cache)
## - <10s full draft simulation (vs ~30s without cache)
## - Memory usage <50MB for cache (~1.2MB for 32 teams x 38KB boards)
##
## Cache Invalidation:
## - Call invalidate_cache() after any trade to recompute affected boards
## - Call invalidate_team_board(team_id) to recompute a single team's board
## - Invalidation is O(n) where n = players in pool (must re-sort)
##
## Determinism Guarantee:
## - Cache keys incorporate team_id, year, and seed
## - Same seed always produces identical cached evaluations
## - RNG state is preserved across cache hits/misses
##
## RNG Usage Pattern:
## - Board computation consumes RNG during scout evaluations
## - Each team's board uses a sub-seeded RNG: seed ^ team_id_hash
## - RNG is NOT consumed on cache hits (pure lookup)
##
## Usage:
##   var cache := DraftEvaluationCache.new()
##   cache.initialize(teams, rosters, draft_pool, year, seed, configs)
##   cache.precompute_all_boards()  # Call once at draft start
##
##   # During draft:
##   var board := cache.get_team_board(team_id)
##   for entry in board:
##       if not is_drafted(entry.player_id):
##           return entry  # Best available player for this team
##
extends RefCounted
class_name DraftEvaluationCache

const Rand = preload("res://autoloads/Rand.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")
const EvaluationContext = preload("res://scripts/core/evaluation/EvaluationContext.gd")
const EvaluationModifierStack = preload("res://scripts/core/evaluation/EvaluationModifierStack.gd")
const SchemeFitCalculator = preload("res://scripts/core/scouting/SchemeFitCalculator.gd")

## Board entry structure for type documentation
## {
##   "player_id": String,
##   "score": float,           # Final weighted score
##   "base_score": float,      # Raw scout evaluation
##   "position": String,
##   "overall_rating": float,  # True player rating
##   "scheme_fit_mult": float, # Scheme fit multiplier
##   "need_mult": float        # Position need multiplier
## }

## Cached boards: team_id -> Array of board entries (sorted by score desc)
var _cached_boards: Dictionary = {}

## Whether cache has been computed
var _cache_valid: bool = false

## Cache metadata for debugging/validation
var _cache_stats: Dictionary = {
	"compute_time_ms": 0.0,
	"total_evaluations": 0,
	"teams_cached": 0,
	"players_per_board": 0,
	"last_invalidation_reason": ""
}

## Input data references (stored for recomputation on invalidation)
var _teams: Array = []
var _rosters: Dictionary = {}
var _draft_pool: Array = []
var _team_scouts: Dictionary = {}
var _year: int = 0
var _seed: int = 0

## Config references
var _positions_cfg: Dictionary = {}
var _stats_cfg: Dictionary = {}
var _class_rules: Dictionary = {}
var _schemes_cfg: Dictionary = {}
var _ovr_cfg: Dictionary = {}

## Team index for O(1) lookup
var _team_index: Dictionary = {}

## Player index for O(1) lookup by player_id
var _player_index: Dictionary = {}

## Maximum players to evaluate per team (optimization)
## Top N by raw talent + top M per position of need
const MAX_BPA_CANDIDATES := 20
const MAX_PER_POSITION_NEED := 5


## Initialize cache with required data
## Does NOT compute boards - call precompute_all_boards() separately
func initialize(
	teams: Array,
	rosters: Dictionary,
	draft_pool: Array,
	team_scouts: Dictionary,
	year: int,
	seed: int,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	class_rules: Dictionary
) -> void:
	_teams = teams
	_rosters = rosters
	_draft_pool = draft_pool
	_team_scouts = team_scouts
	_year = year
	_seed = seed
	_positions_cfg = positions_cfg
	_stats_cfg = stats_cfg
	_class_rules = class_rules

	# Build indices
	_build_team_index()
	_build_player_index()

	# Load schemes and OVR weights configs once
	_schemes_cfg = SchemeFitCalculator.load_schemes_config()
	const OVR_WEIGHTS_PATH := "res://configs/sports/american_football/ovr_weights.json"
	_ovr_cfg = PlayerRatingCalculator.load_ovr_config(OVR_WEIGHTS_PATH)

	_cache_valid = false
	_cached_boards.clear()


## Pre-compute draft boards for all teams
## This is the key optimization - compute once, query many times
##
## RNG Consumption:
## - Creates deterministic sub-RNG per team: seed ^ team_id_hash
## - Each team's board computation is independent
##
## Returns: Time taken in milliseconds
func precompute_all_boards() -> float:
	var start_time := Time.get_ticks_usec()

	_cached_boards.clear()
	var total_evaluations := 0

	# Pre-sort draft pool by talent (needed for BPA candidate selection)
	var sorted_pool := _draft_pool.duplicate()
	var use_weighted := not _ovr_cfg.is_empty()
	sorted_pool.sort_custom(func(a, b):
		var a_rating: float
		var b_rating: float
		if use_weighted:
			var a_pos := String((a as Dictionary).get("position", ""))
			var b_pos := String((b as Dictionary).get("position", ""))
			a_rating = PlayerRatingCalculator.calculate_weighted_ovr(a as Dictionary, a_pos, _ovr_cfg)
			b_rating = PlayerRatingCalculator.calculate_weighted_ovr(b as Dictionary, b_pos, _ovr_cfg)
		else:
			a_rating = PlayerRatingCalculator.calculate_overall_rating(
				a as Dictionary, _positions_cfg, _class_rules
			)
			b_rating = PlayerRatingCalculator.calculate_overall_rating(
				b as Dictionary, _positions_cfg, _class_rules
			)
		return a_rating > b_rating
	)

	# Pre-group players by position for fast lookup
	var players_by_position := _group_players_by_position(sorted_pool)

	# Compute board for each team
	for team in _teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id.is_empty():
			continue

		var board := _compute_team_board(
			team_id,
			sorted_pool,
			players_by_position
		)

		_cached_boards[team_id] = board
		total_evaluations += board.size()

	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000.0

	# Update stats
	_cache_stats = {
		"compute_time_ms": elapsed_ms,
		"total_evaluations": total_evaluations,
		"teams_cached": _cached_boards.size(),
		"players_per_board": total_evaluations / max(_cached_boards.size(), 1),
		"last_invalidation_reason": ""
	}

	_cache_valid = true
	return elapsed_ms


## Get cached board for a team
## Returns empty array if cache is invalid or team not found
func get_team_board(team_id: String) -> Array:
	if not _cache_valid:
		push_warning("[DraftEvaluationCache] Cache is invalid - call precompute_all_boards() first")
		return []

	return _cached_boards.get(team_id, [])


## Check if cache is valid
func is_cache_valid() -> bool:
	return _cache_valid


## Invalidate entire cache (e.g., after a trade)
## Must call precompute_all_boards() again to rebuild
func invalidate_cache(reason: String = "manual") -> void:
	_cache_valid = false
	_cached_boards.clear()
	_cache_stats["last_invalidation_reason"] = reason


## Invalidate and recompute a single team's board
## More efficient than full invalidation when only one team's needs change
##
## RNG Note: Uses same seeding as initial computation for determinism
func invalidate_team_board(team_id: String, reason: String = "team_change") -> void:
	if not _cache_valid:
		return  # Full cache rebuild needed anyway

	# Pre-sort pool (needed for board computation)
	var sorted_pool := _draft_pool.duplicate()
	var use_weighted := not _ovr_cfg.is_empty()
	sorted_pool.sort_custom(func(a, b):
		var a_rating: float
		var b_rating: float
		if use_weighted:
			var a_pos := String((a as Dictionary).get("position", ""))
			var b_pos := String((b as Dictionary).get("position", ""))
			a_rating = PlayerRatingCalculator.calculate_weighted_ovr(a as Dictionary, a_pos, _ovr_cfg)
			b_rating = PlayerRatingCalculator.calculate_weighted_ovr(b as Dictionary, b_pos, _ovr_cfg)
		else:
			a_rating = PlayerRatingCalculator.calculate_overall_rating(
				a as Dictionary, _positions_cfg, _class_rules
			)
			b_rating = PlayerRatingCalculator.calculate_overall_rating(
				b as Dictionary, _positions_cfg, _class_rules
			)
		return a_rating > b_rating
	)

	var players_by_position := _group_players_by_position(sorted_pool)

	var board := _compute_team_board(team_id, sorted_pool, players_by_position)
	_cached_boards[team_id] = board

	_cache_stats["last_invalidation_reason"] = "%s (%s)" % [reason, team_id]


## Get cache statistics for debugging/monitoring
func get_cache_stats() -> Dictionary:
	return _cache_stats.duplicate()


## Get cache memory estimate in bytes
func get_memory_estimate() -> int:
	var total := 0

	for team_id in _cached_boards.keys():
		var board: Array = _cached_boards[team_id]
		# Estimate ~200 bytes per board entry (dict with 6-8 keys)
		total += board.size() * 200

	return total


# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Compute draft board for a single team
## Returns sorted array of board entries
##
## RNG: Creates team-specific RNG: seed ^ team_id_hash
## This ensures deterministic evaluation while allowing parallel computation
func _compute_team_board(
	team_id: String,
	sorted_pool: Array,
	players_by_position: Dictionary
) -> Array:
	var team_data: Dictionary = _team_index.get(team_id, {})
	var roster: Dictionary = _rosters.get(team_id, {})
	var scout: Dictionary = _team_scouts.get(team_id, {})

	var offensive_scheme := String(team_data.get("offensive_scheme", "pro_style"))
	var defensive_scheme := String(team_data.get("defensive_scheme", "cover_2"))
	var coach: Dictionary = team_data.get("coach", {})

	# Calculate position needs
	var needs := _calculate_position_needs(roster)

	# Create team-specific RNG for deterministic evaluation
	var team_rng := RandomNumberGenerator.new()
	team_rng.seed = Rand.splitmix64(_seed ^ hash(team_id))

	# Build candidate set: top BPA + top per position of need
	var candidates: Dictionary = {}  # player_id -> player

	# Add top N by raw talent (BPA candidates)
	for i in range(min(MAX_BPA_CANDIDATES, sorted_pool.size())):
		var p: Dictionary = sorted_pool[i]
		var player_id := String(p.get("player_id", p.get("id", "")))
		candidates[player_id] = p

	# Add top M at each position of need
	for position in needs.keys():
		var need_mult := float(needs.get(position, 1.0))
		if need_mult < 0.95:  # Position is filled, skip
			continue

		var pos_players: Array = players_by_position.get(position, [])
		for i in range(min(MAX_PER_POSITION_NEED, pos_players.size())):
			var p: Dictionary = pos_players[i]
			var player_id := String(p.get("player_id", p.get("id", "")))
			candidates[player_id] = p

	# Evaluate each candidate
	var board: Array = []
	var draft_strategy: Dictionary = _class_rules.get("draft_position_strategy", {})

	for player_id in candidates.keys():
		var player: Dictionary = candidates[player_id]
		var position := String(player.get("position", ""))

		# Calculate base rating using weighted OVR if available
		var overall_rating: float
		if not _ovr_cfg.is_empty():
			overall_rating = PlayerRatingCalculator.calculate_weighted_ovr(player, position, _ovr_cfg)
		else:
			overall_rating = PlayerRatingCalculator.calculate_overall_rating(
				player, _positions_cfg, _class_rules
			)

		# Scout evaluation
		var base_score := ScoutRuntime.score_player(
			scout, player, _positions_cfg, _stats_cfg, _class_rules, team_rng
		)

		# Create evaluation context for modifiers
		var team := {
			"id": team_id,
			"offensive_scheme": offensive_scheme,
			"defensive_scheme": defensive_scheme,
			"coach": coach
		}

		var ctx := EvaluationContext.for_draft(
			player, team, roster, 1, _year,
			_positions_cfg, _stats_cfg, _class_rules, draft_strategy
		)
		ctx.base_rating = overall_rating

		# Apply evaluation modifiers
		var stack := EvaluationModifierStack.create_draft_stack()
		var eval_result := stack.evaluate(ctx)

		# Calculate final weighted score
		var weighted_score := base_score * eval_result.final_multiplier

		# Extract scheme fit and need multipliers for display
		var scheme_fit_mult := 1.0
		var need_mult := float(needs.get(position, 1.0))

		for mod_info in eval_result.applied_modifiers:
			var mi: Dictionary = mod_info
			if String(mi.get("id", "")) == "scheme_fit":
				scheme_fit_mult = float(mi.get("multiplier", 1.0))

		board.append({
			"player_id": player_id,
			"score": weighted_score,
			"base_score": base_score,
			"position": position,
			"overall_rating": overall_rating,
			"scheme_fit_mult": scheme_fit_mult,
			"need_mult": need_mult,
			"final_multiplier": eval_result.final_multiplier
		})

	# Sort by score descending
	board.sort_custom(func(a, b):
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	return board


## Build team index for O(1) lookup
func _build_team_index() -> void:
	_team_index.clear()
	for team in _teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if not team_id.is_empty():
			_team_index[team_id] = t


## Build player index for O(1) lookup
func _build_player_index() -> void:
	_player_index.clear()
	for player in _draft_pool:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", p.get("id", "")))
		if not player_id.is_empty():
			_player_index[player_id] = p


## Group players by position for fast position-based lookup
func _group_players_by_position(sorted_pool: Array) -> Dictionary:
	var by_position: Dictionary = {}

	for player in sorted_pool:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		if not by_position.has(position):
			by_position[position] = []
		by_position[position].append(p)

	return by_position


## Calculate position needs for a team
func _calculate_position_needs(roster: Dictionary) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {})
	var needs: Dictionary = {}

	for pos in _positions_cfg.keys():
		var current_count := (by_position.get(pos, []) as Array).size()
		var ideal := RosterComposition.get_ideal_depth(pos)
		var max_allowed := RosterComposition.get_max_depth(pos)

		# Hard cap check
		if current_count >= max_allowed:
			needs[pos] = 0.0
			continue

		# Overstocked check
		if current_count > ideal:
			var excess := current_count - ideal
			var slots_to_cap := max_allowed - ideal
			if slots_to_cap > 0:
				var ratio := float(excess) / float(slots_to_cap)
				needs[pos] = 0.4 - (ratio * 0.3)
			else:
				needs[pos] = 0.1
			continue

		# Calculate need multiplier
		if current_count == 0:
			needs[pos] = 1.5  # High need
		elif current_count < ideal:
			var deficit := ideal - current_count
			needs[pos] = 1.0 + (float(deficit) / float(ideal)) * 0.3
		else:
			needs[pos] = 0.95  # At ideal depth

	return needs


# =============================================================================
# STATIC HELPERS
# =============================================================================

## Create cache key for a specific evaluation (for debugging/testing)
## Format: "year_seed_team_player"
static func create_cache_key(year: int, seed: int, team_id: String, player_id: String) -> String:
	return "%d_%d_%s_%s" % [year, seed, team_id, player_id]


## Validate that two boards are identical (for determinism testing)
static func boards_are_identical(board_a: Array, board_b: Array) -> bool:
	if board_a.size() != board_b.size():
		return false

	for i in range(board_a.size()):
		var a: Dictionary = board_a[i]
		var b: Dictionary = board_b[i]

		if String(a.get("player_id", "")) != String(b.get("player_id", "")):
			return false

		if not is_equal_approx(float(a.get("score", 0.0)), float(b.get("score", 0.0))):
			return false

	return true
