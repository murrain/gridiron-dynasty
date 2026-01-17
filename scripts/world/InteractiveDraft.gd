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
const DraftTradeEngine = preload("res://scripts/world/DraftTradeEngine.gd")

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

## Emitted when trade window opens (between picks)
signal trade_window_opened(current_pick: int, user_tradeable_picks: Array)

## Emitted when trade is executed
signal trade_executed(trade_record: Dictionary)

## Emitted when trade is rejected
signal trade_rejected(reason: String)

## Draft state
enum DraftState { NOT_STARTED, RUNNING, WAITING_FOR_USER, TRADE_WINDOW, COMPLETED }

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
	_rosters = world_state.get("nfl_rosters", {})

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

	# Initialize pick ownership if needed
	if not world_state.has("draft_pick_ownership"):
		NflDraft.initialize_pick_ownership(world_state, _teams, year, _rounds)

	# Initialize team scouting quality
	if not world_state.has("nfl_scouting_quality"):
		var class_rules: Dictionary = _main_cfg.get("class_rules", {})
		world_state["nfl_scouting_quality"] = NflDraft._generate_team_scouting_quality(
			_teams, class_rules, seed
		)
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
func _make_ai_pick(pick_assignment: Dictionary) -> void:
	var team_id := String(pick_assignment.get("current_owner_id", ""))

	if _remaining_pool.is_empty():
		return

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
func _execute_pick(pick_assignment: Dictionary, player: Dictionary, player_index: int) -> void:
	var team_id := String(pick_assignment.get("current_owner_id", ""))
	var round_num := int(pick_assignment.get("round", 1))
	var overall_pick := int(pick_assignment.get("overall_pick", _current_pick + 1))
	var is_traded := bool(pick_assignment.get("traded", false))
	var original_team_id := String(pick_assignment.get("original_team_id", ""))

	var player_id := String(player.get("player_id", player.get("id", "")))

	# Create rookie contract
	var contract := _create_rookie_contract(round_num, overall_pick)

	# Update player with NFL info
	player["nfl_team_id"] = team_id
	player["nfl_status"] = "active"
	player["contract"] = contract
	player["draft_info"] = {
		"year": _year,
		"round": round_num,
		"pick": overall_pick,
		"team_id": team_id
	}
	player["draft_year"] = _year
	var composite := float(player.get("composite_score", 50.0))
	player["eval_score"] = composite

	# Add to roster
	var roster: Dictionary = _rosters.get(team_id, {"players": [], "by_position": {}})
	var players: Array = roster.get("players", [])
	players.append(player)
	roster["players"] = players
	_update_roster_by_position(roster, player)
	_rosters[team_id] = roster

	# Mark player as drafted (for fast lookup in board iteration)
	_drafted_players[player_id] = true

	# Record pick
	var pick_record := {
		"round": round_num,
		"pick": overall_pick,
		"team_id": team_id,
		"player_id": player_id,
		"player_name": String(player.get("name", "Unknown")),
		"position": String(player.get("position", "")),
		"college": String(player.get("college_team_id", "")),
		"traded": is_traded,
		"original_team_id": original_team_id if is_traded else null,
		"is_user_pick": team_id == _user_team_id
	}
	_picks_made.append(pick_record)

	# Remove from pool
	_remaining_pool.remove_at(player_index)

	# Emit signals
	pick_made.emit(pick_record)
	draft_ticker_update.emit(
		overall_pick,
		team_id,
		String(player.get("name", "Unknown")),
		String(player.get("position", ""))
	)


## Finalize the draft
func _finalize_draft() -> void:
	_state = DraftState.COMPLETED

	# Store undrafted players
	var undrafted_pool: Dictionary = _world_state.get("undrafted_pool", {})
	undrafted_pool[_year] = _remaining_pool
	_world_state["undrafted_pool"] = undrafted_pool
	_world_state["nfl_rosters"] = _rosters

	# Store draft history
	var draft_history: Dictionary = _world_state.get("draft_history", {})
	draft_history[_year] = _picks_made
	_world_state["draft_history"] = draft_history

	# Build results
	var results := {
		"year": _year,
		"picks": _picks_made,
		"picks_count": _picks_made.size(),
		"undrafted_count": _remaining_pool.size(),
		"user_picks": _picks_made.filter(func(p): return p.get("is_user_pick", false))
	}

	draft_completed.emit(results)


## Generate assistant coach recommendations using pre-computed board
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
	var pct := clamp(max_rookie_pct * decay, min_rookie_pct, max_rookie_pct)
	var base_salary := cap_limit * pct

	var signing_bonus := base_salary * (0.8 - (float(round_num - 1) * 0.1))
	signing_bonus = max(signing_bonus, 0.1)

	var annual_value := base_salary + (signing_bonus / float(years))

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
# TRADE SYSTEM METHODS
# =============================================================================

## Enter trade window (called between picks)
## User can propose trades during this window
func enter_trade_window() -> void:
	if _state != DraftState.RUNNING:
		push_warning("[InteractiveDraft] Cannot enter trade window from state %d" % _state)
		return

	_state = DraftState.TRADE_WINDOW
	var user_picks := _get_user_tradeable_picks()
	trade_window_opened.emit(_current_pick, user_picks)


## Exit trade window and resume draft
func exit_trade_window() -> void:
	if _state != DraftState.TRADE_WINDOW:
		push_warning("[InteractiveDraft] Not in trade window")
		return

	_state = DraftState.RUNNING
	_advance_draft()


## Propose trade (user-initiated)
## Returns true if trade was accepted and executed
func propose_trade(offer: Dictionary) -> bool:
	if _state != DraftState.TRADE_WINDOW:
		push_error("[InteractiveDraft] Trades only allowed in trade window")
		return false

	# Validate trade
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var validation := DraftTradeEngine.validate_trade(
		offer,
		ownership,
		_year,
		_current_pick
	)

	if not validation.get("valid", false):
		trade_rejected.emit(String(validation.get("reason", "Invalid trade")))
		return false

	# Evaluate acceptance (AI decision)
	var receiving_team_id := String(offer.get("receiving_team_id", ""))
	var receiving_roster: Dictionary = _rosters.get(receiving_team_id, {})
	var receiving_needs := _calculate_position_needs(receiving_roster)

	var accepted := DraftTradeEngine.should_accept_trade(
		offer,
		receiving_team_id,
		receiving_roster,
		receiving_needs,
		_year,
		_current_pick,
		_seed,
		_league_cfg
	)

	if not accepted:
		trade_rejected.emit("Trade declined by %s" % receiving_team_id)
		return false

	# Execute trade
	_execute_trade(offer)
	return true


## Execute trade (internal helper)
func _execute_trade(offer: Dictionary) -> void:
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})

	# Use engine to update ownership and create record
	var trade_record := DraftTradeEngine.execute_trade(
		offer, ownership, _year, _current_pick
	)

	# Update world state
	_world_state["draft_pick_ownership"] = ownership

	# Add to trade history
	if not _world_state.has("draft_trades"):
		_world_state["draft_trades"] = {}
	var trade_history: Dictionary = _world_state["draft_trades"]
	if not trade_history.has(_year):
		trade_history[_year] = []
	(trade_history[_year] as Array).append(trade_record)

	# Emit signal
	trade_executed.emit(trade_record)

	# Rebuild draft order (ownership changed)
	_build_draft_order()


## Get user's tradeable picks (picks not yet used)
func _get_user_tradeable_picks() -> Array:
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var user_picks: Array = []

	var year_ownership: Dictionary = ownership.get(_year, {}) as Dictionary

	for round_num in range(_current_round, _rounds + 1):
		var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary

		for orig_team_id in round_ownership.keys():
			var current_owner := String(round_ownership.get(orig_team_id, ""))
			if current_owner == _user_team_id:
				# Determine pick_in_round from original team's draft order
				var pick_in_round := _get_pick_in_round_for_team(orig_team_id, round_num)
				var overall := (round_num - 1) * _picks_per_round + pick_in_round

				# Only tradeable if not yet used
				if overall > _current_pick:
					user_picks.append({
						"year": _year,
						"round": round_num,
						"pick_in_round": pick_in_round,
						"overall": overall,
						"original_team_id": orig_team_id,
						"pick_id": "%d_%d_%d" % [_year, round_num, pick_in_round]
					})

	return user_picks


## Get pick_in_round for a team's original pick
func _get_pick_in_round_for_team(team_id: String, round_num: int) -> int:
	var team: Dictionary = _team_index.get(team_id, {})
	var draft_order := int(team.get("draft_order", 16))
	return draft_order


## Process AI-initiated trade opportunities (called during _advance_draft)
func _process_ai_trade_opportunities() -> void:
	# Only process trades occasionally (every 5th pick or so)
	if _current_pick % 5 != 0:
		return

	# Generate AI trade proposals for current pick
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var proposals := DraftTradeEngine.generate_ai_trade_proposals(
		_current_pick,
		_teams,
		_rosters,
		ownership,
		_remaining_pool,
		_year,
		_seed,
		_league_cfg
	)

	# Execute first accepted trade (if any)
	for proposal in proposals:
		var p: Dictionary = proposal
		var receiving_team_id := String(p.get("receiving_team_id", ""))
		var receiving_roster: Dictionary = _rosters.get(receiving_team_id, {})
		var receiving_needs := _calculate_position_needs(receiving_roster)

		var accepted := DraftTradeEngine.should_accept_trade(
			p,
			receiving_team_id,
			receiving_roster,
			receiving_needs,
			_year,
			_current_pick,
			_seed,
			_league_cfg
		)

		if accepted:
			_execute_trade(p)
			break  # Only execute one trade per pick


## Check if trade window is available (between picks, not on user's turn)
func can_open_trade_window() -> bool:
	return _state == DraftState.RUNNING


## Get all teams available for trading (excludes user team)
func get_trade_partner_teams() -> Array:
	var partners: Array = []
	for team in _teams:
		var t: Dictionary = team
		if String(t.get("id", "")) != _user_team_id:
			partners.append(t)
	return partners


## Get picks owned by a specific team
func get_team_picks(team_id: String) -> Array:
	var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
	var year_ownership: Dictionary = ownership.get(_year, {}) as Dictionary
	var picks: Array = []

	for round_num in range(1, _rounds + 1):
		var round_ownership: Dictionary = year_ownership.get(round_num, {}) as Dictionary

		for orig_team_id in round_ownership.keys():
			var owner := String(round_ownership.get(orig_team_id, ""))
			if owner == team_id:
				var pick_in_round := _get_pick_in_round_for_team(orig_team_id, round_num)
				var overall := (round_num - 1) * _picks_per_round + pick_in_round

				if overall > _current_pick:
					picks.append({
						"year": _year,
						"round": round_num,
						"pick_in_round": pick_in_round,
						"overall": overall,
						"original_team_id": orig_team_id,
						"pick_id": "%d_%d_%d" % [_year, round_num, pick_in_round]
					})

	return picks


## Check if we're in trade window state
func is_in_trade_window() -> bool:
	return _state == DraftState.TRADE_WINDOW
