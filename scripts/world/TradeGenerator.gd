extends RefCounted
class_name TradeGenerator

const TradeOffer = preload("res://scripts/core/trades/TradeOffer.gd")
const TradeDecision = preload("res://scripts/core/trades/TradeDecision.gd")
const TradeValueCalculator = preload("res://scripts/core/trades/TradeValueCalculator.gd")
const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")

## Generates trade offers for NFL teams based on team context and needs.
##
## Algorithm:
##   1. Assess team contexts (contending vs rebuilding)
##   2. Assess team needs (surplus vs deficit positions)
##   3. Generate offers from teams with surplus to teams with deficits
##   4. Evaluate with TradeDecision
##   5. Execute accepted trades
##
## Determinism:
##   - All RNG consumption explicit via passed rng parameter
##   - Same seed produces identical trades
##
## RNG consumption:
##   - 2 calls per team pair attempt (team selection)
##   - Total: ~(max_attempts * 2) calls per season
static func generate_trades(
	world_state: Dictionary,
	year: int,
	rng: RandomNumberGenerator,
	positions_cfg: Dictionary,
	main_cfg: Dictionary,
	trade_cfg: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var teams: Array = world_state.get("nfl_teams", []) as Array
	var rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary

	if teams.size() < 2:
		return {
			"executed_trades": [],
			"rejected_trades": [],
			"executed": 0,
			"rejected": 0
		}

	# Assess team contexts (contending vs rebuilding)
	# RNG CALL PATTERN: No RNG calls (deterministic calculation)
	var team_contexts := _assess_team_contexts(teams, rosters, positions_cfg)

	# Assess positional needs for all teams
	# RNG CALL PATTERN: No RNG calls (deterministic calculation)
	var team_needs := _assess_team_needs(teams, rosters, positions_cfg)

	# Build player value index for valuation
	# RNG CALL PATTERN: No RNG calls (deterministic calculation)
	var player_values := _build_player_value_index(rosters, positions_cfg, main_cfg)

	# Generate trade opportunities
	var max_trades_per_year := int(options.get("max_trades_per_year", trade_cfg.get("max_trades_per_year", 15)))
	var executed_trades: Array = []
	var rejected_trades: Array = []
	var attempts := 0
	var max_attempts := max_trades_per_year * 10  # Allow multiple attempts

	# Track which teams have already traded to avoid excessive activity
	var teams_traded: Dictionary = {}

	while executed_trades.size() < max_trades_per_year and attempts < max_attempts:
		attempts += 1

		# RNG CALL 1: Select random offering team
		var team_a_idx := rng.randi() % teams.size()
		# RNG CALL 2: Select random receiving team
		var team_b_idx := rng.randi() % teams.size()

		if team_a_idx == team_b_idx:
			continue

		var team_a: Dictionary = teams[team_a_idx]
		var team_b: Dictionary = teams[team_b_idx]
		var team_a_id := String(team_a.get("id", ""))
		var team_b_id := String(team_b.get("id", ""))

		# Limit trades per team (max 3 per year)
		if teams_traded.get(team_a_id, 0) >= 3 or teams_traded.get(team_b_id, 0) >= 3:
			continue

		# Generate offer from team_a to team_b
		var offer: Variant = _generate_offer(
			team_a, team_b,
			rosters, team_needs, team_contexts,
			player_values, positions_cfg, trade_cfg, rng
		)

		if offer == null:
			continue

		# Evaluate offer
		var decision := _evaluate_offer(
			offer, team_b,
			player_values, team_needs,
			trade_cfg
		)

		if decision.get("accept", false):
			# Execute trade
			_execute_trade(offer, rosters)
			executed_trades.append({
				"offer": offer,
				"year": year,
				"offering_team": team_a_id,
				"receiving_team": team_b_id,
				"valuation": decision
			})

			# Track trades
			teams_traded[team_a_id] = teams_traded.get(team_a_id, 0) + 1
			teams_traded[team_b_id] = teams_traded.get(team_b_id, 0) + 1

			# Recalculate needs after trade execution
			team_needs = _assess_team_needs(teams, rosters, positions_cfg)
			player_values = _build_player_value_index(rosters, positions_cfg, main_cfg)
		else:
			rejected_trades.append({
				"offer": offer,
				"offering_team": team_a_id,
				"receiving_team": team_b_id,
				"reason": decision.get("reason", "value_insufficient")
			})

	return {
		"executed_trades": executed_trades,
		"rejected_trades": rejected_trades,
		"executed": executed_trades.size(),
		"rejected": rejected_trades.size(),
		"attempts": attempts
	}


## Assess team contexts (contending vs rebuilding vs neutral).
##
## Uses average player rating across core positions to classify teams.
## Deterministic: no RNG calls.
static func _assess_team_contexts(
	teams: Array,
	rosters: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var contexts := {}

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
		var players: Array = roster.get("players", []) as Array

		if players.is_empty():
			contexts[team_id] = {
				"mode": "neutral",
				"avg_rating": 50.0,
				"roster_size": 0
			}
			continue

		# Simple heuristic: average player rating
		var total_rating := 0.0
		var count := 0

		for player in players:
			var p: Dictionary = player
			var position := String(p.get("position", ""))
			var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
			var core_stats: Array = pos_cfg.get("core_stats", []) as Array
			var stats: Dictionary = p.get("stats", {}) as Dictionary

			if core_stats.is_empty():
				continue

			var player_rating := 0.0
			for stat_name in core_stats:
				player_rating += float(stats.get(stat_name, 0.0))
			player_rating /= float(core_stats.size())

			total_rating += player_rating
			count += 1

		var avg_rating := (total_rating / float(count)) if count > 0 else 50.0

		# Categorize team
		var mode := "neutral"
		if avg_rating >= 70.0:
			mode = "contending"
		elif avg_rating <= 55.0:
			mode = "rebuilding"

		contexts[team_id] = {
			"mode": mode,
			"avg_rating": avg_rating,
			"roster_size": players.size()
		}

	return contexts


## Assess team needs based on depth at each position.
##
## Returns a dictionary mapping team_id -> {position: need_score}
## need_score: 0.5 (surplus) to 2.0 (desperate need)
##
## Deterministic: no RNG calls.
static func _assess_team_needs(
	teams: Array,
	rosters: Dictionary,
	positions_cfg: Dictionary
) -> Dictionary:
	var needs := {}

	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", ""))
		var roster: Dictionary = rosters.get(team_id, {}) as Dictionary
		var by_position: Dictionary = roster.get("by_position", {}) as Dictionary

		var position_needs := {}
		for position in positions_cfg.keys():
			var position_players: Array = by_position.get(position, []) as Array
			var ideal_depth := _ideal_depth_for_position(position)
			var current_depth := position_players.size()

			# Need score: 0.5 (surplus) to 2.0 (desperate need)
			var need_score := 1.0
			if current_depth < ideal_depth:
				# Deficit: score increases above 1.0
				var deficit_ratio := float(ideal_depth - current_depth) / float(ideal_depth)
				need_score = 1.0 + deficit_ratio
			elif current_depth > ideal_depth:
				# Surplus: score decreases below 1.0
				var surplus_ratio := float(current_depth - ideal_depth) / float(max(ideal_depth, 1))
				need_score = 1.0 - (surplus_ratio * 0.5)

			position_needs[position] = clamp(need_score, 0.5, 2.0)

		needs[team_id] = position_needs

	return needs


## Ideal depth for each position (NFL standard depth chart).
static func _ideal_depth_for_position(position: String) -> int:
	var depths := {
		"QB": 3,
		"RB": 4,
		"WR": 6,
		"TE": 3,
		"OL": 8,
		"DL": 6,
		"EDGE": 4,
		"LB": 6,
		"CB": 5,
		"S": 4,
		"K": 1,
		"P": 1
	}
	return int(depths.get(position, 3))


## Generate a trade offer from offering_team to receiving_team.
##
## Strategy:
##   1. Find positions where offering_team has surplus (need_score < 1.0)
##   2. Find positions where receiving_team has deficit (need_score > 1.0)
##   3. If overlap exists, propose 1-for-1 player trade
##   4. Validate salary cap compliance
##
## RNG consumption:
##   - 1 call for position selection (weighted by need difference)
##   - 1 call for player selection within position
##   Total: 2 RNG calls per offer generation attempt
static func _generate_offer(
	offering_team: Dictionary,
	receiving_team: Dictionary,
	rosters: Dictionary,
	team_needs: Dictionary,
	team_contexts: Dictionary,
	player_values: Dictionary,
	positions_cfg: Dictionary,
	trade_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Variant:
	var offering_team_id := String(offering_team.get("id", ""))
	var receiving_team_id := String(receiving_team.get("id", ""))

	var offering_needs: Dictionary = team_needs.get(offering_team_id, {}) as Dictionary
	var receiving_needs: Dictionary = team_needs.get(receiving_team_id, {}) as Dictionary

	var offering_roster: Dictionary = rosters.get(offering_team_id, {}) as Dictionary
	var receiving_roster: Dictionary = rosters.get(receiving_team_id, {}) as Dictionary

	var offering_by_pos: Dictionary = offering_roster.get("by_position", {}) as Dictionary
	var receiving_by_pos: Dictionary = receiving_roster.get("by_position", {}) as Dictionary

	# Find positions where offering team has surplus and receiving team has deficit
	var viable_positions: Array = []
	for position in positions_cfg.keys():
		var offering_need := float(offering_needs.get(position, 1.0))
		var receiving_need := float(receiving_needs.get(position, 1.0))

		# Offering team has surplus (< 1.0) and receiving team has deficit (> 1.0)
		if offering_need < 1.0 and receiving_need > 1.0:
			var need_difference := receiving_need - offering_need
			viable_positions.append({
				"position": position,
				"weight": need_difference
			})

	if viable_positions.is_empty():
		return null

	# RNG CALL 1: Select position weighted by need difference
	var total_weight := 0.0
	for pos_entry in viable_positions:
		total_weight += float((pos_entry as Dictionary).get("weight", 0.0))

	var roll := rng.randf() * total_weight
	var accumulated := 0.0
	var selected_position := ""

	for pos_entry in viable_positions:
		var entry: Dictionary = pos_entry as Dictionary
		accumulated += float(entry.get("weight", 0.0))
		if roll <= accumulated:
			selected_position = String(entry.get("position", ""))
			break

	if selected_position == "":
		return null

	# Get players at selected position
	var offering_players_ids: Array = offering_by_pos.get(selected_position, []) as Array
	if offering_players_ids.is_empty():
		return null

	# RNG CALL 2: Select random player from offering team
	var player_to_trade_id := String(offering_players_ids[rng.randi() % offering_players_ids.size()])

	# Find the actual player dictionary
	var player_to_trade: Dictionary = {}
	var offering_players: Array = offering_roster.get("players", []) as Array
	for player in offering_players:
		var p: Dictionary = player
		if String(p.get("player_id", "")) == player_to_trade_id:
			player_to_trade = p
			break

	if player_to_trade.is_empty():
		return null

	# Validate minimum roster size after trade
	var min_roster_size := int(trade_cfg.get("min_roster_size_after_trade", 45))
	if offering_players.size() - 1 < min_roster_size:
		return null

	# Create simple 1-for-1 trade offer (player-for-player)
	# For now, we're doing player-for-nothing (team gives away surplus)
	# In advanced version, we'd find a matching player from receiving team
	return {
		"send_player_ids": [player_to_trade_id],
		"receive_player_ids": [],
		"send_picks": [],
		"receive_picks": [],
		"from_team": offering_team_id,
		"to_team": receiving_team_id
	}


## Build player value index for all players across all rosters.
##
## Returns dictionary mapping player_id -> value_score
## Deterministic: no RNG calls.
static func _build_player_value_index(
	rosters: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var values := {}

	for team_id in rosters.keys():
		var roster: Dictionary = rosters[team_id]
		var players: Array = roster.get("players", []) as Array

		for player in players:
			var p: Dictionary = player
			var player_id := String(p.get("player_id", ""))
			var position := String(p.get("position", ""))
			var stats: Dictionary = p.get("stats", {}) as Dictionary
			var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
			var core_stats: Array = pos_cfg.get("core_stats", []) as Array

			if core_stats.is_empty():
				values[player_id] = 50.0
				continue

			# Simple valuation: average of core stats
			var avg := 0.0
			for stat_name in core_stats:
				avg += float(stats.get(stat_name, 0.0))
			avg /= float(core_stats.size())

			# Scale to value points (0-100 stat range -> 0-1000 value points)
			values[player_id] = avg * 10.0

	return values


## Evaluate a trade offer using TradeDecision logic.
##
## Returns:
##   - accept: bool (whether to accept)
##   - incoming_value: float (value of what team receives)
##   - outgoing_value: float (value of what team gives up)
##   - reason: string (explanation)
##
## Deterministic: no RNG calls.
static func _evaluate_offer(
	offer: Dictionary,
	receiving_team: Dictionary,
	player_values: Dictionary,
	team_needs: Dictionary,
	trade_cfg: Dictionary
) -> Dictionary:
	var receiving_team_id := String(receiving_team.get("id", ""))

	# Calculate values
	var incoming_player_ids: Array = offer.get("receive_player_ids", []) as Array
	var outgoing_player_ids: Array = offer.get("send_player_ids", []) as Array

	var incoming_value := 0.0
	for player_id in incoming_player_ids:
		incoming_value += float(player_values.get(player_id, 0.0))

	var outgoing_value := 0.0
	for player_id in outgoing_player_ids:
		outgoing_value += float(player_values.get(player_id, 0.0))

	# Use TradeDecision to evaluate
	var decision := TradeDecision.new()
	var threshold := float(trade_cfg.get("acceptance_threshold", 1.05))
	var accept := decision.should_accept(incoming_value, outgoing_value, threshold)

	var reason := "value_sufficient" if accept else "value_insufficient"

	# Special case: if outgoing is 0 (we give up nothing), always accept incoming
	if outgoing_value == 0.0 and incoming_value > 0.0:
		accept = true
		reason = "free_acquisition"

	return {
		"accept": accept,
		"incoming_value": incoming_value,
		"outgoing_value": outgoing_value,
		"reason": reason,
		"threshold": threshold
	}


## Execute a trade by moving players between rosters.
##
## Updates:
##   - Removes sent players from offering team
##   - Adds received players to offering team
##   - Updates by_position indices
##
## Deterministic: no RNG calls.
static func _execute_trade(offer: Dictionary, rosters: Dictionary) -> void:
	var from_team := String(offer.get("from_team", ""))
	var to_team := String(offer.get("to_team", ""))
	var send_player_ids: Array = offer.get("send_player_ids", []) as Array
	var receive_player_ids: Array = offer.get("receive_player_ids", []) as Array

	var from_roster: Dictionary = rosters.get(from_team, {}) as Dictionary
	var to_roster: Dictionary = rosters.get(to_team, {}) as Dictionary

	var from_players: Array = from_roster.get("players", []) as Array
	var to_players: Array = to_roster.get("players", []) as Array

	# Collect players to move
	var players_to_send: Array = []
	var players_to_receive: Array = []

	# Find and remove sent players from offering team
	for player_id in send_player_ids:
		for i in range(from_players.size() - 1, -1, -1):
			var p: Dictionary = from_players[i]
			if String(p.get("player_id", "")) == player_id:
				players_to_send.append(p)
				from_players.remove_at(i)
				break

	# Find and remove received players from receiving team
	for player_id in receive_player_ids:
		for i in range(to_players.size() - 1, -1, -1):
			var p: Dictionary = to_players[i]
			if String(p.get("player_id", "")) == player_id:
				players_to_receive.append(p)
				to_players.remove_at(i)
				break

	# Add players to new teams
	to_players.append_array(players_to_send)
	from_players.append_array(players_to_receive)

	# Update rosters
	from_roster["players"] = from_players
	to_roster["players"] = to_players

	# Rebuild by_position indices
	_rebuild_roster_by_position(from_roster)
	_rebuild_roster_by_position(to_roster)

	rosters[from_team] = from_roster
	rosters[to_team] = to_roster


## Rebuild the by_position index for a roster.
##
## Deterministic: no RNG calls.
static func _rebuild_roster_by_position(roster: Dictionary) -> void:
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
