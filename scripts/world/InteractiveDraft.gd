## InteractiveDraft - Draft system with user participation
##
## This extends the NflDraft system to support a human user controlling
## one team's picks. The draft proceeds pick-by-pick, pausing when
## it's the user's turn to make a selection.
##
## Usage:
##   var draft = InteractiveDraft.new()
##   draft.initialize(world_state, year, seed, user_team_id, configs)
##   draft.start()
##
##   # When user's turn:
##   draft.user_pick_requested.connect(_on_user_pick)
##   # In handler:
##   draft.make_user_pick(player_id)
##
extends RefCounted
class_name InteractiveDraft

const Rand = preload("res://autoloads/Rand.gd")
const SimLogger = preload("res://autoloads/SimLogger.gd")
const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const RecruitingScoreCache = preload("res://scripts/core/scouting/RecruitingScoreCache.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")
const NflDraft = preload("res://scripts/world/NflDraft.gd")
const PlayerShortlist = preload("res://scripts/core/models/PlayerShortlist.gd")
const DraftTradeEngine = preload("res://scripts/world/DraftTradeEngine.gd")
const DraftStateManager = preload("res://scripts/core/state/DraftStateManager.gd")

## Emitted when the user needs to make a pick
## Parameters: pick_number, round_number, available_players, recommendations
signal user_pick_requested(pick_number: int, round_number: int, available_players: Array, recommendations: Array)

## Emitted after each pick (AI or user)
signal pick_made(pick_info: Dictionary)

## Emitted when draft completes
signal draft_completed(results: Dictionary)

## Emitted for draft ticker updates
signal draft_ticker_update(pick_number: int, team_id: String, player_name: String, position: String)

## Emitted when round changes
signal round_changed(round_number: int)

## Emitted when a shortlisted player is drafted
signal shortlisted_player_drafted(player_id: String, player_name: String, position: String, team_id: String, pick_number: int)

## Emitted when shortlist changes
signal shortlist_changed()

## Emitted when trade proposals are available for user to review
signal trade_proposals_available(proposals: Array)

## Emitted when a trade is executed
signal trade_executed(trade_record: Dictionary)

## Emitted when an AI team proposes a trade to the user
signal trade_offer_received(offer: Dictionary, offering_team: String)

## Draft state
enum DraftState { NOT_STARTED, RUNNING, WAITING_FOR_USER, COMPLETED, TRADE_WINDOW }

## Board sort modes for BPA vs Need toggle
enum BoardSortMode { BPA, NEED, SCHEME_FIT }

var _state: DraftState = DraftState.NOT_STARTED
var _world_state: Dictionary = {}
var _year: int = 0
var _seed: int = 0
var _user_team_id: String = ""

## Config references
var _league_cfg: Dictionary = {}
var _positions_cfg: Dictionary = {}
var _stats_cfg: Dictionary = {}
var _scouts_cfg: Dictionary = {}
var _main_cfg: Dictionary = {}

## Draft tracking
var _current_pick: int = 0
var _current_round: int = 1
var _picks_made: Array = []
var _remaining_pool: Array = []
var _teams: Array = []
var _rosters: Dictionary = {}
var _team_scouts: Dictionary = {}
var _team_index: Dictionary = {}

## RNGs
var _scout_rng: RandomNumberGenerator
var _pick_rng: RandomNumberGenerator
var _contract_rng: RandomNumberGenerator

## Caches
var _score_cache: RecruitingScoreCache
var _team_quality: Dictionary = {}

## Draft structure
var _rounds: int = 7
var _picks_per_round: int = 32
var _draft_order: Array = []  # Array of pick assignments for all rounds

## Pre-computed draft boards for fast AI picks
## _team_boards[team_id] = Array of {player_id: String, score: float}
## Boards are sorted by score descending - AI just picks top available
var _team_boards: Dictionary = {}

## Set of player IDs that have been drafted (for fast lookup)
var _drafted_players: Dictionary = {}

## Player lookup by ID for O(1) access
var _player_by_id: Dictionary = {}

## Track which round boards were last precomputed for
## Used to detect round changes and invalidate boards for position need recalculation
var _last_precomputed_round: int = 0

## User's player shortlist/watchlist
var _shortlist: PlayerShortlist = null

## Current board sort mode for user display
var _board_sort_mode: BoardSortMode = BoardSortMode.BPA

## Trading state (DRAFT-001 integration)
var _trade_history: Array = []
var _pending_trade_offers: Array = []
var _trades_this_draft: int = 0

## Trading configuration
var _trading_enabled: bool = true
var _max_trades_per_draft: int = 30  # Cap for realism (NFL averages 15-25)


## Initialize the draft with world state and configs
func initialize(
	world_state: Dictionary,
	year: int,
	seed: int,
	user_team_id: String,
	league_cfg: Dictionary,
	positions_cfg: Dictionary,
	stats_cfg: Dictionary,
	scouts_cfg: Dictionary,
	main_cfg: Dictionary
) -> void:
	_world_state = world_state
	_year = year
	_seed = seed
	_user_team_id = user_team_id
	_league_cfg = league_cfg
	_positions_cfg = positions_cfg
	_stats_cfg = stats_cfg
	_scouts_cfg = scouts_cfg
	_main_cfg = main_cfg

	# Initialize RNGs
	_scout_rng = RandomNumberGenerator.new()
	_scout_rng.seed = Rand.splitmix64(seed ^ 0xD4AF7001)
	_pick_rng = RandomNumberGenerator.new()
	_pick_rng.seed = Rand.splitmix64(seed ^ 0xD4AF7002)
	_contract_rng = RandomNumberGenerator.new()
	_contract_rng.seed = Rand.splitmix64(seed ^ 0xD4AF7003)

	# Extract draft pool
	var draft_pool_all: Dictionary = world_state.get("draft_pool", {})
	_remaining_pool = (draft_pool_all.get(year, []) as Array).duplicate()

	# Normalize field names
	for player in _remaining_pool:
		var p: Dictionary = player
		if p.has("player_id") and not p.has("id"):
			p["id"] = p["player_id"]

	# Extract teams and rosters
	_teams = world_state.get("nfl_teams", [])

	# CRITICAL: Make _rosters a deep copy, not a reference to world_state
	# This prevents accidental direct mutations of world_state during draft execution
	# Rosters will be synced back via DraftStateManager.execute_pick() after each pick
	var world_rosters: Dictionary = world_state.get("nfl_rosters", {})
	_rosters = {}
	for team_id in world_rosters.keys():
		_rosters[team_id] = (world_rosters[team_id] as Dictionary).duplicate(true)

	# Build team index
	_team_index = _build_team_index(_teams)

	# Initialize rosters for teams without them
	for team in _teams:
		var team_id := String((team as Dictionary).get("id", ""))
		if not _rosters.has(team_id):
			_rosters[team_id] = {"players": [], "by_position": {}}

	# Get draft config
	var draft_cfg: Dictionary = _league_cfg.get("draft", {})
	_rounds = int(draft_cfg.get("rounds", 7))
	_picks_per_round = int(draft_cfg.get("picks_per_round", _teams.size()))

	# Initialize draft structures using DraftStateManager
	# This handles: pick ownership allocation, scouting quality generation, state machine setup
	# Only runs once per year if not already initialized
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})
	if not world_state.has("draft_pick_ownership") or not world_state.has("nfl_scouting_quality"):
		var init_result := DraftStateManager.initialize_draft(
			world_state,
			_teams,
			year,
			_league_cfg,
			class_rules,
			seed
		)
		if init_result.get("scouting_initialized", false):
			print("[InteractiveDraft] Initialized scouting quality for %d teams" % _teams.size())

	_team_quality = world_state.get("nfl_scouting_quality", {})

	# Generate scouts for each team
	_team_scouts = _generate_team_scouts()

	# Pre-sort pool by talent
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})
	_remaining_pool.sort_custom(func(a, b):
		var a_rating := PlayerRatingCalculator.calculate_overall_rating(
			a as Dictionary, _positions_cfg, class_rules
		)
		var b_rating := PlayerRatingCalculator.calculate_overall_rating(
			b as Dictionary, _positions_cfg, class_rules
		)
		return a_rating > b_rating
	)

	# Initialize score cache
	_score_cache = RecruitingScoreCache.new(year)

	# Build player lookup index for O(1) access
	_build_player_index()

	# Build complete draft order
	_build_draft_order()

	# Pre-compute draft boards for all teams (this is the key optimization)
	print("[InteractiveDraft] Pre-computing draft boards for %d teams..." % _teams.size())
	var board_start := Time.get_ticks_usec()
	_precompute_team_boards()
	var board_elapsed := (Time.get_ticks_usec() - board_start) / 1000.0
	print("[InteractiveDraft] Draft boards computed in %.1fms" % board_elapsed)

	# Track that we've precomputed for round 1
	_last_precomputed_round = 1

	# Initialize user's shortlist
	_shortlist = PlayerShortlist.new()
	_shortlist.initialize(user_team_id)
	_shortlist.shortlisted_player_drafted.connect(_on_shortlisted_player_drafted)
	_shortlist.shortlist_changed.connect(_on_shortlist_changed)

	_state = DraftState.NOT_STARTED


## Build player lookup index for O(1) access by player_id
func _build_player_index() -> void:
	_player_by_id.clear()
	for player in _remaining_pool:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", p.get("id", "")))
		if not player_id.is_empty():
			_player_by_id[player_id] = p


## Pre-compute draft boards for all teams
## Each team gets a sorted list of players by their evaluation score
## This is done once at draft start, then we just mark players as taken
##
## OPTIMIZATION: Only evaluate relevant players:
## - Top 15 players by raw talent (BPA candidates)
## - Top 4 players at each position of need
## This reduces evaluations from ~250 per team to ~40-50
func _precompute_team_boards() -> void:
	_team_boards.clear()
	_drafted_players.clear()

	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	# Pre-group players by position for fast lookup
	var players_by_position: Dictionary = {}
	for player in _remaining_pool:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		if not players_by_position.has(position):
			players_by_position[position] = []
		players_by_position[position].append(p)

	# _remaining_pool is already sorted by talent, so top 15 is just first 15
	var top_talent_count := 15
	var top_by_position_count := 4

	for team in _teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id.is_empty():
			continue

		var roster: Dictionary = _rosters.get(team_id, {})
		var scout: Dictionary = _team_scouts.get(team_id, {})

		# Calculate initial position needs
		var needs := _calculate_position_needs(roster)

		# Build set of players to evaluate
		var players_to_evaluate: Dictionary = {}  # player_id -> player

		# Add top 15 by talent (BPA candidates)
		for i in range(min(top_talent_count, _remaining_pool.size())):
			var p: Dictionary = _remaining_pool[i]
			var player_id := String(p.get("player_id", p.get("id", "")))
			players_to_evaluate[player_id] = p

		# Add top 4 at each position of need
		for position in needs.keys():
			var need_mult := float(needs.get(position, 1.0))
			if need_mult < 1.0:  # Position is filled, skip
				continue

			var pos_players: Array = players_by_position.get(position, [])
			for i in range(min(top_by_position_count, pos_players.size())):
				var p: Dictionary = pos_players[i]
				var player_id := String(p.get("player_id", p.get("id", "")))
				players_to_evaluate[player_id] = p

		# Score only the relevant players
		var scored: Array = []
		for player_id in players_to_evaluate.keys():
			var player: Dictionary = players_to_evaluate[player_id]
			var position := String(player.get("position", ""))

			# Get base score from cache or compute
			var base_score := _score_cache.get_or_compute(
				player,
				scout,
				team_id,
				"draft_board",
				_positions_cfg,
				_stats_cfg,
				class_rules,
				_seed
			)

			# Apply need multiplier
			var need_mult := float(needs.get(position, 1.0))
			var weighted_score := base_score * need_mult

			scored.append({
				"player_id": player_id,
				"score": weighted_score,
				"position": position
			})

		# Sort by score descending
		scored.sort_custom(func(a, b):
			return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
		)

		_team_boards[team_id] = scored


## Build the complete draft order for all rounds
func _build_draft_order() -> void:
	_draft_order.clear()

	var sorted_teams := _sort_by_draft_order(_teams, _world_state, _year)
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})

	for round_num in range(1, _rounds + 1):
		var round_picks := NflDraft.resolve_draft_order_with_ownership(
			sorted_teams, ownership, _year, round_num
		)

		for pick_assignment in round_picks:
			var assignment: Dictionary = pick_assignment
			assignment["round"] = round_num
			assignment["overall_pick"] = _draft_order.size() + 1
			_draft_order.append(assignment)


## Start the draft - runs until user's pick or completion
func start() -> void:
	if _state != DraftState.NOT_STARTED:
		push_error("[InteractiveDraft] Draft already started or completed")
		return

	_state = DraftState.RUNNING
	_current_pick = 0
	_current_round = 1

	round_changed.emit(_current_round)
	_advance_draft()


## Advance the draft - makes AI picks until user's turn or end
func _advance_draft() -> void:
	while _state == DraftState.RUNNING and _current_pick < _draft_order.size():
		var pick_assignment: Dictionary = _draft_order[_current_pick]
		var picking_team_id := String(pick_assignment.get("current_owner_id", ""))
		var round_num := int(pick_assignment.get("round", 1))

		# Check for round change
		if round_num != _current_round:
			_current_round = round_num
			round_changed.emit(_current_round)

		# Check if it's user's pick
		if picking_team_id == _user_team_id:
			_state = DraftState.WAITING_FOR_USER
			_request_user_pick()
			return

		# AI makes pick
		_make_ai_pick(pick_assignment)
		_current_pick += 1

	# Draft completed
	if _current_pick >= _draft_order.size():
		_finalize_draft()


## Request user to make a pick
func _request_user_pick() -> void:
	var pick_assignment: Dictionary = _draft_order[_current_pick]
	var overall_pick := int(pick_assignment.get("overall_pick", _current_pick + 1))
	var round_num := int(pick_assignment.get("round", 1))

	# Get recommendations from assistant coach
	var recommendations := _generate_recommendations(3)

	# Build available players list with ratings
	var available := _get_available_players_with_ratings()

	user_pick_requested.emit(overall_pick, round_num, available, recommendations)


## Make a user pick
func make_user_pick(player_id: String) -> bool:
	if _state != DraftState.WAITING_FOR_USER:
		push_error("[InteractiveDraft] Not waiting for user pick")
		return false

	# Find player in pool
	var player: Dictionary = {}
	var player_index := -1
	for i in range(_remaining_pool.size()):
		var p: Dictionary = _remaining_pool[i]
		if String(p.get("player_id", p.get("id", ""))) == player_id:
			player = p
			player_index = i
			break

	if player_index < 0:
		push_error("[InteractiveDraft] Player not found in draft pool: %s" % player_id)
		return false

	# Make the pick
	var pick_assignment: Dictionary = _draft_order[_current_pick]
	_execute_pick(pick_assignment, player, player_index)

	_current_pick += 1
	_state = DraftState.RUNNING

	# Continue draft
	_advance_draft()
	return true


## Make an AI pick - uses pre-computed board for fast selection
##
## If boards were invalidated (e.g., after a trade), this will lazily
## recompute them before making the pick.
##
## CRITICAL FIX: Boards are also invalidated at the start of each new round
## to ensure teams re-evaluate position needs based on players already drafted.
func _make_ai_pick(pick_assignment: Dictionary) -> void:
	var team_id := String(pick_assignment.get("current_owner_id", ""))
	var round_num := int(pick_assignment.get("round", 1))

	if _remaining_pool.is_empty():
		return

	# Check if we've started a new round since last precomputation
	# If so, invalidate boards to force recalculation with updated rosters
	if round_num != _last_precomputed_round:
		print("[InteractiveDraft] New round %d detected - invalidating boards for position need recalculation" % round_num)
		_invalidate_draft_boards()
		_last_precomputed_round = round_num

	# Lazy recomputation: If boards were invalidated, recompute them
	if _team_boards.is_empty():
		print("[InteractiveDraft] Lazy recomputing draft boards after invalidation...")
		var board_start := Time.get_ticks_usec()
		_precompute_team_boards()
		var board_elapsed := (Time.get_ticks_usec() - board_start) / 1000.0
		print("[InteractiveDraft] Draft boards recomputed in %.1fms" % board_elapsed)

	# Get team's pre-computed board
	var board: Array = _team_boards.get(team_id, [])

	# Find first available player on the board (not yet drafted)
	var selected_player_id := ""
	for entry in board:
		var e: Dictionary = entry
		var player_id := String(e.get("player_id", ""))
		if not _drafted_players.has(player_id):
			selected_player_id = player_id
			break

	if selected_player_id.is_empty():
		return

	# Get player from index
	var player: Dictionary = _player_by_id.get(selected_player_id, {})
	if player.is_empty():
		return

	# Find index in remaining pool
	var player_index := -1
	for i in range(_remaining_pool.size()):
		var p: Dictionary = _remaining_pool[i]
		if String(p.get("player_id", p.get("id", ""))) == selected_player_id:
			player_index = i
			break

	if player_index >= 0:
		_execute_pick(pick_assignment, player, player_index)


## Execute a pick (shared by AI and user)
##
## ARCHITECTURE: Uses DraftStateManager.execute_pick() for atomic world_state updates.
## Maintains local caches (_rosters, _remaining_pool, _drafted_players) for performance,
## but refreshes from world_state after each mutation to ensure consistency.
func _execute_pick(pick_assignment: Dictionary, player: Dictionary, player_index: int) -> void:
	var team_id := String(pick_assignment.get("current_owner_id", ""))
	var round_num := int(pick_assignment.get("round", 1))
	var overall_pick := int(pick_assignment.get("overall_pick", _current_pick + 1))
	var is_traded := bool(pick_assignment.get("traded", false))
	var original_team_id := String(pick_assignment.get("original_team_id", ""))

	var player_id := String(player.get("player_id", player.get("id", "")))

	# Create rookie contract
	var contract := _create_rookie_contract(round_num, overall_pick)

	# Prepare draft info for DraftStateManager
	var draft_info := {
		"year": _year,
		"round": round_num,
		"pick": overall_pick,
		"team_id": team_id
	}

	# Execute pick atomically via DraftStateManager
	# This handles: removing from draft pool, updating player, adding to roster, DataBus notifications
	var pick_result := DraftStateManager.execute_pick(
		_world_state,
		player_id,
		team_id,
		draft_info,
		contract,
		_year
	)

	if not pick_result.get("success", false):
		push_error("[InteractiveDraft] Failed to execute pick for player %s" % player_id)
		return

	# Refresh local roster cache from world_state after mutation
	# This ensures our local cache stays in sync with the authoritative world_state
	var updated_rosters: Dictionary = _world_state.get("nfl_rosters", {})
	_rosters[team_id] = (updated_rosters.get(team_id, {}) as Dictionary).duplicate(true)

	# Update local player reference from updated roster for signal emission
	var roster: Dictionary = _rosters.get(team_id, {})
	var roster_players: Array = roster.get("players", [])
	var drafted_player: Dictionary = {}
	for p in roster_players:
		var rp: Dictionary = p
		if String(rp.get("player_id", "")) == player_id:
			drafted_player = rp
			break

	# Mark player as drafted in local cache (for fast lookup in board iteration)
	_drafted_players[player_id] = true

	# Notify shortlist if this player was on user's watchlist
	if _shortlist and _shortlist.is_shortlisted(player_id):
		_shortlist.mark_as_drafted(player_id, team_id, overall_pick)

	# Record pick in local tracking
	var pick_record := {
		"round": round_num,
		"pick": overall_pick,
		"team_id": team_id,
		"player_id": player_id,
		"player_name": String(drafted_player.get("name", "Unknown")),
		"position": String(drafted_player.get("position", "")),
		"college": String(drafted_player.get("college_team_id", "")),
		"traded": is_traded,
		"original_team_id": original_team_id if is_traded else null,
		"is_user_pick": team_id == _user_team_id
	}
	_picks_made.append(pick_record)

	# Remove from local pool cache
	_remaining_pool.remove_at(player_index)

	# Emit signals
	pick_made.emit(pick_record)
	draft_ticker_update.emit(
		overall_pick,
		team_id,
		String(drafted_player.get("name", "Unknown")),
		String(drafted_player.get("position", ""))
	)


## Finalize the draft
##
## ARCHITECTURE: Uses DraftStateManager for atomic state updates and DataBus notifications.
## All world_state mutations go through the manager to ensure UI reactivity.
func _finalize_draft() -> void:
	_state = DraftState.COMPLETED

	# Store undrafted players using DraftStateManager
	# This ensures atomic update with DataBus notification for UI reactivity
	var undrafted_result := DraftStateManager.store_undrafted_players(
		_world_state,
		_remaining_pool,
		_year
	)
	print("[InteractiveDraft] Stored %d undrafted players" % undrafted_result.get("undrafted_count", 0))

	# Store draft history using DraftStateManager
	# This finalizes the draft and ensures DataBus notification
	# Note: Rosters are already updated via execute_pick(), so no need to write them here
	var history_result := DraftStateManager.record_draft_history(
		_world_state,
		_picks_made,
		_year
	)
	print("[InteractiveDraft] Recorded draft history (%d picks)" % history_result.get("picks_recorded", 0))

	# Build results
	var results := {
		"year": _year,
		"picks": _picks_made,
		"picks_count": _picks_made.size(),
		"undrafted_count": _remaining_pool.size(),
		"user_picks": _picks_made.filter(func(p): return p.get("is_user_pick", false))
	}

	draft_completed.emit(results)


## Get top N recommendations for current pick (PUBLIC API)
## @param count: Number of recommendations to return
## @return Array of player dictionaries sorted by fit score
func get_recommendations(count: int) -> Array:
	return _generate_recommendations(count)


## Generate assistant coach recommendations using pre-computed board (PRIVATE)
func _generate_recommendations(count: int) -> Array:
	var board: Array = _team_boards.get(_user_team_id, [])
	var recommendations: Array = []
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	var found := 0
	for entry in board:
		if found >= count:
			break

		var e: Dictionary = entry
		var player_id := String(e.get("player_id", ""))

		# Skip drafted players
		if _drafted_players.has(player_id):
			continue

		var player: Dictionary = _player_by_id.get(player_id, {})
		if player.is_empty():
			continue

		var overall := PlayerRatingCalculator.calculate_overall_rating(
			player, _positions_cfg, class_rules
		)

		found += 1
		recommendations.append({
			"player_id": player_id,
			"player_name": String(player.get("name", "Unknown")),
			"position": String(player.get("position", "")),
			"college": String(player.get("college_team_id", "")),
			"overall": overall,
			"score": float(e.get("score", 0.0)),
			"rank": found
		})

	return recommendations


## Get available players with ratings
func _get_available_players_with_ratings() -> Array:
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})
	var result: Array = []

	for player in _remaining_pool:
		var p: Dictionary = player
		var overall := PlayerRatingCalculator.calculate_overall_rating(
			p, _positions_cfg, class_rules
		)

		result.append({
			"player_id": String(p.get("player_id", p.get("id", ""))),
			"name": String(p.get("name", "Unknown")),
			"position": String(p.get("position", "")),
			"college": String(p.get("college_team_id", "")),
			"overall": overall,
			"age": int(p.get("age", 22)),
			"height": String(p.get("height", "")),
			"weight": int(p.get("weight", 0)),
		})

	return result


## Score players for a specific team
func _score_players_for_team(team_id: String) -> Array:
	var roster: Dictionary = _rosters.get(team_id, {})
	var scout: Dictionary = _team_scouts.get(team_id, {})
	var team_data: Dictionary = _team_index.get(team_id, {})
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	var team_offensive_scheme := String(team_data.get("offensive_scheme", "pro_style"))
	var team_defensive_scheme := String(team_data.get("defensive_scheme", "cover_2"))
	var coach: Dictionary = team_data.get("coach", {})

	# Calculate position needs
	var needs := _calculate_position_needs(roster)

	# Score top candidates
	var scored: Array = []
	var max_candidates := 20

	for i in range(min(max_candidates, _remaining_pool.size())):
		var player: Dictionary = _remaining_pool[i]
		var position := String(player.get("position", ""))

		var base_score := _score_cache.get_or_compute(
			player,
			scout,
			team_id,
			"draft_round_%d" % _current_round,
			_positions_cfg,
			_stats_cfg,
			class_rules,
			_seed
		)

		var need_mult := float(needs.get(position, 1.0))
		var weighted_score := base_score * need_mult

		scored.append({
			"player": player,
			"score": weighted_score,
			"base_score": base_score,
			"need_mult": need_mult,
			"position": position
		})

	# Sort by score
	scored.sort_custom(func(a, b):
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	return scored


## Calculate position needs for a team
func _calculate_position_needs(roster: Dictionary) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {})
	var needs := {}

	for pos in _positions_cfg.keys():
		var current_count := (by_position.get(pos, []) as Array).size()
		var ideal := RosterComposition.get_ideal_depth(pos)

		if current_count == 0:
			needs[pos] = 1.5
		elif current_count < ideal:
			var deficit := ideal - current_count
			needs[pos] = 1.0 + (float(deficit) / float(ideal)) * 0.3
		else:
			needs[pos] = 0.95

	return needs


## Generate team scouts
func _generate_team_scouts() -> Dictionary:
	var team_scouts := {}
	var national_scouts: Array = _scouts_cfg.get("national_scouts", [])

	for team in _teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id == "":
			continue

		var base_scout: Dictionary
		if national_scouts.is_empty():
			base_scout = {"base_skill": 0.55, "board_noise_sigma": 1.8}
		else:
			var scout_idx := _scout_rng.randi_range(0, national_scouts.size() - 1)
			base_scout = (national_scouts[scout_idx] as Dictionary).duplicate(true)

		var base_skill := float(base_scout.get("base_skill", 0.55))
		base_scout["base_skill"] = clamp(base_skill + _scout_rng.randf_range(-0.05, 0.05), 0.3, 0.9)

		var quality: Dictionary = _team_quality.get(team_id, {})
		if not quality.is_empty():
			NflDraft._apply_team_quality_to_scout(base_scout, quality, _scout_rng)

		team_scouts[team_id] = base_scout

	return team_scouts


## Create rookie contract
func _create_rookie_contract(round_num: int, overall_pick: int) -> Dictionary:
	var years := 4
	var has_fifth_year_option := (round_num == 1)

	var cap_limit := float(_league_cfg.get("cap_limit", 200.0))
	var max_rookie_pct := 0.05
	var min_rookie_pct := 0.002
	var decay := pow(0.97, float(overall_pick - 1))
	var pct: float = clamp(max_rookie_pct * decay, min_rookie_pct, max_rookie_pct)
	var base_salary: float = cap_limit * pct

	var signing_bonus: float = base_salary * (0.8 - (float(round_num - 1) * 0.1))
	signing_bonus = max(signing_bonus, 0.1)

	var annual_value: float = base_salary + (signing_bonus / float(years))

	return {
		"type": "rookie",
		"years_total": years,
		"years_remaining": years,
		"base_salary": base_salary,
		"signing_bonus": signing_bonus,
		"annual_value": annual_value,
		"fifth_year_option": has_fifth_year_option,
		"gtd_remaining": signing_bonus,
		"signed_year": _year
	}


## Update roster by_position index
func _update_roster_by_position(roster: Dictionary, player: Dictionary) -> void:
	var by_position: Dictionary = roster.get("by_position", {})
	var position := String(player.get("position", ""))
	var player_id := String(player.get("player_id", player.get("id", "")))

	if position == "":
		return

	if not by_position.has(position):
		by_position[position] = []

	(by_position[position] as Array).append(player_id)
	roster["by_position"] = by_position


## Build team index
func _build_team_index(teams: Array) -> Dictionary:
	var index := {}
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		if team_id != "":
			index[team_id] = t
	return index


## Sort teams by draft order
func _sort_by_draft_order(teams: Array, world_state: Dictionary, year: int) -> Array:
	var sorted := teams.duplicate()
	sorted.sort_custom(func(a, b):
		return int((a as Dictionary).get("draft_order", 999)) < int((b as Dictionary).get("draft_order", 999))
	)
	return sorted


## Get current draft state
func get_state() -> DraftState:
	return _state


## Get current pick number
func get_current_pick() -> int:
	return _current_pick + 1


## Get current round
func get_current_round() -> int:
	return _current_round


## Get all picks made so far
func get_picks_made() -> Array:
	return _picks_made


## Get remaining pool size
func get_remaining_pool_size() -> int:
	return _remaining_pool.size()


## Check if it's user's turn
func is_user_turn() -> bool:
	return _state == DraftState.WAITING_FOR_USER


## Get total picks in draft
func get_total_picks() -> int:
	return _draft_order.size()


# =============================================================================
# SHORTLIST MANAGEMENT (DRAFT-009)
# =============================================================================

## Add a player to the user's shortlist
func add_to_shortlist(player_id: String, priority: int = PlayerShortlist.Priority.MEDIUM) -> bool:
	if _shortlist == null:
		return false

	var player: Dictionary = _player_by_id.get(player_id, {})
	if player.is_empty():
		return false

	return _shortlist.add_player(
		player_id,
		String(player.get("name", "Unknown")),
		String(player.get("position", "")),
		String(player.get("college_team_id", "")),
		priority
	)


## Remove a player from the user's shortlist
func remove_from_shortlist(player_id: String) -> bool:
	if _shortlist == null:
		return false
	return _shortlist.remove_player(player_id)


## Check if a player is on the shortlist
func is_on_shortlist(player_id: String) -> bool:
	if _shortlist == null:
		return false
	return _shortlist.is_shortlisted(player_id)


## Get all shortlist entries
func get_shortlist() -> Array:
	if _shortlist == null:
		return []
	return _shortlist.get_all_entries()


## Get available shortlist entries (not yet drafted)
func get_available_shortlist() -> Array:
	if _shortlist == null:
		return []
	return _shortlist.get_available_entries()


## Set shortlist priority for a player
func set_shortlist_priority(player_id: String, priority: int) -> bool:
	if _shortlist == null:
		return false
	return _shortlist.set_priority(player_id, priority)


## Get the shortlist model for direct access
func get_shortlist_model() -> PlayerShortlist:
	return _shortlist


## Load shortlist from save data
func load_shortlist_data(data: Dictionary) -> void:
	if _shortlist == null:
		_shortlist = PlayerShortlist.new()
	_shortlist.from_dict(data)
	_shortlist.shortlisted_player_drafted.connect(_on_shortlisted_player_drafted)
	_shortlist.shortlist_changed.connect(_on_shortlist_changed)


## Get shortlist data for saving
func get_shortlist_data() -> Dictionary:
	if _shortlist == null:
		return {}
	return _shortlist.to_dict()


## Signal handler for shortlist player drafted notification
func _on_shortlisted_player_drafted(player_id: String, player_name: String, position: String, team_id: String, pick_number: int) -> void:
	shortlisted_player_drafted.emit(player_id, player_name, position, team_id, pick_number)


## Signal handler for shortlist changed notification
func _on_shortlist_changed() -> void:
	shortlist_changed.emit()


# =============================================================================
# BOARD SORT MODE (DRAFT-015: BPA vs Need Toggle)
# =============================================================================

## Set the board sort mode
func set_board_sort_mode(mode: BoardSortMode) -> void:
	assert(mode in [BoardSortMode.BPA, BoardSortMode.NEED, BoardSortMode.SCHEME_FIT],
		"Invalid board sort mode: %d" % mode)
	_board_sort_mode = mode


## Get the current board sort mode
func get_board_sort_mode() -> BoardSortMode:
	return _board_sort_mode


## Get available players sorted by current mode
## This is a client-side sort that does not modify underlying data
## Performance target: <50ms for 250 players
## NOTE: Does NOT include shortlist state - UI must query separately via is_on_shortlist()
func get_sorted_available_players() -> Array:
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})
	var result: Array = []

	# Build list with all needed data (excluding shortlist state for separation of concerns)
	for player in _remaining_pool:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", p.get("id", "")))

		var overall := PlayerRatingCalculator.calculate_overall_rating(
			p, _positions_cfg, class_rules
		)

		result.append({
			"player_id": player_id,
			"name": String(p.get("name", "Unknown")),
			"position": String(p.get("position", "")),
			"college": String(p.get("college_team_id", "")),
			"overall": overall,
			"age": int(p.get("age", 22)),
			"height": String(p.get("height", "")),
			"weight": int(p.get("weight", 0)),
		})

	# Sort based on current mode
	match _board_sort_mode:
		BoardSortMode.BPA:
			_sort_by_bpa(result)
		BoardSortMode.NEED:
			_sort_by_need(result)
		BoardSortMode.SCHEME_FIT:
			_sort_by_scheme_fit(result)

	return result


## Get sorted available players WITH shortlist state included
## @param sort_mode: "overall", "scheme_fit", "position_need" (optional, uses current mode if not specified)
## @return Array of Dictionaries with "_is_shortlisted" field added
##
## PERFORMANCE: O(n) - adds shortlist state in single pass instead of O(n²) UI queries.
## This method eliminates the need for UI to call is_on_shortlist() for each player.
func get_sorted_with_shortlist(sort_mode: String = "") -> Array:
	# If sort_mode specified, temporarily switch mode
	var original_mode: BoardSortMode = _board_sort_mode
	if not sort_mode.is_empty():
		match sort_mode:
			"overall":
				_board_sort_mode = BoardSortMode.BPA
			"scheme_fit":
				_board_sort_mode = BoardSortMode.SCHEME_FIT
			"position_need":
				_board_sort_mode = BoardSortMode.NEED

	# Get sorted players using standard method
	var sorted_players := get_sorted_available_players()

	# Restore original mode if we changed it
	if not sort_mode.is_empty():
		_board_sort_mode = original_mode

	# Add shortlist state in O(n) instead of O(n²)
	for player in sorted_players:
		var player_id := String(player.get("player_id", ""))
		player["_is_shortlisted"] = is_on_shortlist(player_id)

	return sorted_players


## Sort by Best Player Available (pure overall rating)
func _sort_by_bpa(players: Array) -> void:
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("overall", 0.0)) > float(b.get("overall", 0.0))
	)


## Sort by Need (weight position scarcity + team depth)
func _sort_by_need(players: Array) -> void:
	var roster: Dictionary = _rosters.get(_user_team_id, {})
	var needs := _calculate_position_needs(roster)

	# Calculate need-weighted score for each player
	for player in players:
		var p: Dictionary = player
		var position := String(p.get("position", ""))
		var overall := float(p.get("overall", 50.0))
		var need_mult := float(needs.get(position, 1.0))

		# Need score: overall * need multiplier
		# Higher need positions get higher scores
		p["need_score"] = overall * need_mult

	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("need_score", 0.0)) > float(b.get("need_score", 0.0))
	)


## Sort by Scheme Fit (weight scheme compatibility scores)
func _sort_by_scheme_fit(players: Array) -> void:
	var team_data: Dictionary = _team_index.get(_user_team_id, {})
	var offensive_scheme := String(team_data.get("offensive_scheme", "pro_style"))
	var defensive_scheme := String(team_data.get("defensive_scheme", "cover_2"))

	# Calculate scheme fit score for each player
	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		var position := String(p.get("position", ""))
		var overall := float(p.get("overall", 50.0))

		# Get player data for scheme fit
		var player_data: Dictionary = _player_by_id.get(player_id, {})
		var scheme_fit: Dictionary = player_data.get("scheme_fit", {})

		# Determine which scheme to check based on position
		var scheme_to_check := offensive_scheme
		var defensive_positions := ["DL", "EDGE", "LB", "CB", "S"]
		if position in defensive_positions:
			scheme_to_check = defensive_scheme

		# Get fit rating (default to 75 if not specified)
		var fit_rating := float(scheme_fit.get(scheme_to_check, 75.0))

		# Scheme score: weighted combination of overall and fit
		# 60% overall + 40% scheme fit (normalized to 0-100)
		p["scheme_score"] = (overall * 0.6) + (fit_rating * 0.4)

	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("scheme_score", 0.0)) > float(b.get("scheme_score", 0.0))
	)


## Get player data by ID (for UI lookups)
func get_player_by_id(player_id: String) -> Dictionary:
	return _player_by_id.get(player_id, {})


# =============================================================================
# DRAFT TRADING SYSTEM (DRAFT-001)
# =============================================================================

## Enable or disable trading during the draft
func set_trading_enabled(enabled: bool) -> void:
	_trading_enabled = enabled


## Check if trading is enabled
func is_trading_enabled() -> bool:
	return _trading_enabled


## Get AI trade proposals for current pick
##
## Called before each pick to check if any AI teams want to trade.
## Returns proposals that the user can accept or reject.
##
## RNG: Uses DraftTradeEngine.generate_trade_proposals() which is seeded
func get_trade_proposals() -> Array:
	if not _trading_enabled or _trades_this_draft >= _max_trades_per_draft:
		return []

	if _draft_order.is_empty() or _current_pick >= _draft_order.size():
		return []

	var pick_assignment: Dictionary = _draft_order[_current_pick]
	var picking_team := String(pick_assignment.get("current_owner_id", ""))
	var overall_pick := int(pick_assignment.get("overall_pick", _current_pick + 1))

	# Build draft context for trade engine
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	var draft_context := {
		"year": _year,
		"teams": _teams,
		"rosters": _rosters,
		"ownership": ownership,
		"league_cfg": _league_cfg,
		"positions_cfg": _positions_cfg,
		"class_rules": class_rules,
		"current_pick": overall_pick
	}

	# Generate proposals using DraftTradeEngine
	var proposals := DraftTradeEngine.generate_trade_proposals(
		draft_context,
		overall_pick,
		picking_team,
		_remaining_pool,
		_seed
	)

	return proposals


## Check for AI trade offers to the user when it's user's pick
##
## Called when user is on the clock - AI teams may offer trades TO the user.
## User can accept (trade pick) or decline (make pick normally).
func check_for_incoming_trade_offers() -> Array:
	if not _trading_enabled or _trades_this_draft >= _max_trades_per_draft:
		return []

	if _state != DraftState.WAITING_FOR_USER:
		return []

	var pick_assignment: Dictionary = _draft_order[_current_pick]
	var overall_pick := int(pick_assignment.get("overall_pick", _current_pick + 1))

	# Build draft context
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})

	var draft_context := {
		"year": _year,
		"teams": _teams,
		"rosters": _rosters,
		"ownership": ownership,
		"league_cfg": _league_cfg,
		"positions_cfg": _positions_cfg,
		"class_rules": class_rules,
		"current_pick": overall_pick
	}

	# Generate proposals where user is the receiving team
	var proposals := DraftTradeEngine.generate_trade_proposals(
		draft_context,
		overall_pick,
		_user_team_id,
		_remaining_pool,
		_seed
	)

	# Filter to only offers TO the user
	var incoming_offers: Array = []
	for proposal in proposals:
		var p: Dictionary = proposal
		if String(p.get("receiving_team_id", "")) == _user_team_id:
			incoming_offers.append(p)

	_pending_trade_offers = incoming_offers

	if not incoming_offers.is_empty():
		for offer in incoming_offers:
			var offering_team := String((offer as Dictionary).get("offering_team_id", ""))
			trade_offer_received.emit(offer, offering_team)

	return incoming_offers


## Accept a trade offer
##
## Executes the trade and updates ownership ledger.
## Returns true if trade was successfully executed.
func accept_trade(offer: Dictionary) -> bool:
	if not _trading_enabled:
		push_error("[InteractiveDraft] Trading is disabled")
		return false

	if _trades_this_draft >= _max_trades_per_draft:
		push_error("[InteractiveDraft] Maximum trades reached for this draft")
		return false

	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var overall_pick := _current_pick + 1

	# Validate the trade
	var validation := DraftTradeEngine.validate_trade(offer, ownership, _year, overall_pick)
	if not bool(validation.get("valid")):
		push_error("[InteractiveDraft] Invalid trade: %s" % String(validation.get("reason", "Unknown")))
		return false

	# Execute the trade (DraftTradeEngine.execute_trade is pure - returns new ownership)
	var result := DraftTradeEngine.execute_trade(offer, ownership, _year, overall_pick)
	var trade_record: Dictionary = result.get("trade_record", {})
	var updated_ownership: Dictionary = result.get("updated_ownership", {})

	# Update world state with new ownership atomically
	# Note: We can't use DraftStateManager.execute_trade() here because it handles single-pick
	# trades, while DraftTradeEngine handles complex multi-pick packages. However, we must
	# ensure DataBus notifications fire for UI reactivity.
	_world_state["draft_pick_ownership"] = updated_ownership

	# Emit DataBus notification to trigger UI refresh (WorldExplorer, etc.)
	if DataBus:
		DataBus.notify_collection_changed("draft_pick_ownership", "update")

	# Record trade in history
	_trade_history.append(trade_record)
	_trades_this_draft += 1

	# Update draft order to reflect new ownership
	_rebuild_draft_order_from_ownership()

	# CRITICAL: Invalidate cached draft boards so AI teams re-evaluate
	# This ensures AI teams don't use stale boards after trades
	_invalidate_draft_boards()

	# Log trade
	var summary := DraftTradeEngine.format_trade_summary(trade_record, _league_cfg)
	SimLogger.info(summary)

	# Emit signal
	trade_executed.emit(trade_record)

	return true


## Decline a trade offer
##
## Simply removes the offer from pending list.
func decline_trade(offer: Dictionary) -> void:
	var offering_team := String(offer.get("offering_team_id", ""))
	_pending_trade_offers = _pending_trade_offers.filter(func(o):
		return String((o as Dictionary).get("offering_team_id", "")) != offering_team
	)


## Get pending trade offers for user
func get_pending_trade_offers() -> Array:
	return _pending_trade_offers


## Get trade history for this draft
func get_trade_history() -> Array:
	return _trade_history


## Get number of trades executed this draft
func get_trades_count() -> int:
	return _trades_this_draft


## Calculate trade value for display purposes
func get_trade_value(picks: Array) -> float:
	return DraftTradeEngine.calculate_trade_value(picks, _year)


## Invalidate cached draft boards after a trade
##
## CRITICAL: Must be called after any trade execution to ensure
## AI teams re-evaluate available players with updated pick ownership.
## Without this, AI teams would use stale draft boards that don't
## reflect the changed draft landscape after trades.
##
## The boards will be lazily recomputed on the next AI pick when needed.
func _invalidate_draft_boards() -> void:
	_team_boards.clear()
	# Note: _drafted_players is NOT cleared - those players are still drafted
	# We only clear the pre-computed boards so they get rebuilt with fresh evaluations
	print("[InteractiveDraft] Draft boards invalidated - will recompute on next AI pick")


## Rebuild draft order after a trade changes ownership
func _rebuild_draft_order_from_ownership() -> void:
	_draft_order.clear()

	var sorted_teams := _sort_by_draft_order(_teams, _world_state, _year)
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})

	for round_num in range(1, _rounds + 1):
		var round_picks := NflDraft.resolve_draft_order_with_ownership(
			sorted_teams, ownership, _year, round_num
		)

		for pick_assignment in round_picks:
			var assignment: Dictionary = pick_assignment
			assignment["round"] = round_num
			assignment["overall_pick"] = _draft_order.size() + 1
			_draft_order.append(assignment)


## Propose a user-initiated trade (user offers to another team)
##
## Creates a trade offer from user to target team and evaluates acceptance.
## Returns the result of the trade attempt.
func propose_user_trade(
	target_team_id: String,
	picks_to_offer: Array,
	picks_to_request: Array
) -> Dictionary:
	if not _trading_enabled:
		return {"success": false, "reason": "Trading is disabled"}

	if _trades_this_draft >= _max_trades_per_draft:
		return {"success": false, "reason": "Maximum trades reached"}

	var offer := {
		"offering_team_id": _user_team_id,
		"receiving_team_id": target_team_id,
		"picks_offered": picks_to_offer,
		"picks_requested": picks_to_request,
		"initiated_by": "user"
	}

	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var overall_pick := _current_pick + 1

	# Validate
	var validation := DraftTradeEngine.validate_trade(offer, ownership, _year, overall_pick)
	if not bool(validation.get("valid")):
		return {"success": false, "reason": String(validation.get("reason", "Invalid trade"))}

	# Build context for acceptance evaluation
	var class_rules: Dictionary = _main_cfg.get("class_rules", {})
	var draft_context := {
		"year": _year,
		"current_pick": overall_pick,
		"rosters": _rosters,
		"league_cfg": _league_cfg,
		"positions_cfg": _positions_cfg,
		"class_rules": class_rules
	}

	# Evaluate if target team accepts
	var accepted := DraftTradeEngine.evaluate_trade_acceptance(
		offer, target_team_id, draft_context, _seed
	)

	if accepted:
		var trade_success := accept_trade(offer)
		if trade_success:
			return {"success": true, "accepted": true, "reason": "Trade accepted"}
		else:
			return {"success": false, "reason": "Trade execution failed"}
	else:
		return {"success": true, "accepted": false, "reason": "Trade declined by %s" % target_team_id}


## Get user's tradeable picks
func get_user_tradeable_picks() -> Array:
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var overall_pick := _current_pick + 1

	var picks: Array = []
	var year_ownership: Dictionary = ownership.get(_year, {}) as Dictionary

	for round_num in range(1, 8):
		var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary
		var pick_in_round := 1

		for orig_team_id in round_ownership.keys():
			var owner := String(round_ownership.get(orig_team_id, ""))
			if owner == _user_team_id:
				var overall := (round_num - 1) * 32 + pick_in_round
				if overall > overall_pick:  # Only future picks
					picks.append({
						"year": _year,
						"round": round_num,
						"pick_in_round": pick_in_round,
						"original_team_id": orig_team_id,
						"overall": overall
					})
			pick_in_round += 1

	return picks
