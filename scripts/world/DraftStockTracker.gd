extends RefCounted
class_name DraftStockTracker

## Draft Stock Movement Tracker
##
## Purpose: Tracks how draft rankings change throughout the pre-draft process.
##
## This service handles:
##   1. Initial draft stock ranking (pre-season baseline)
##   2. Draft stock updates after each evaluation event
##   3. Consensus ranking calculation across evaluation windows
##   4. Final movement categorization (riser/faller/steady)
##   5. Movement event timeline tracking
##
## Design Philosophy:
##   - Deterministic ranking (stable sort by rating)
##   - Event-driven updates (combine, all-star, medical, character)
##   - Historical timeline for narrative tracking
##   - Configuration-driven impact ranges
##
## RNG Pattern:
##   - Initial ranking: None (deterministic sort)
##   - Event impacts: Config-defined ranges (no RNG, use event data)
##   - Movement events: Deterministic calculation from pre-draft data
##
## Integration Points:
##   - PreDraftProcess: Trigger updates after combine, all-star games
##   - CollegeMedicalService: Medical red flags trigger stock drops
##   - CharacterService: Character issues trigger stock drops
##   - NflDraft: Use draft_stock_timeline in final evaluation

const Rand = preload("res://autoloads/Rand.gd")

## Initializes draft stock for all players in the draft pool.
##
## Establishes baseline pre-season rankings before any evaluation events.
##
## Side effects:
##   - Sets player["draft_stock_timeline"]["pre_season_rank"]
##   - Sets player["draft_stock_timeline"]["movement_events"] = []
##   - Sets player["draft_stock_timeline"]["total_movement"] = 0
##
## RNG: None (deterministic sort by rating)
##
## @param draft_pool: Array of draft-eligible players
## @param config: Draft stock movement configuration
## @param rng: RNG instance (unused but kept for consistency)
static func initialize_draft_stock(
	draft_pool: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	# Sort by rating to establish initial rankings
	var sorted_pool := draft_pool.duplicate()
	sorted_pool.sort_custom(func(a, b):
		var a_rating := _get_player_rating(a as Dictionary)
		var b_rating := _get_player_rating(b as Dictionary)
		if abs(a_rating - b_rating) < 0.01:
			# Tiebreaker: player_id for stability
			return String((a as Dictionary).get("player_id", "")) < String((b as Dictionary).get("player_id", ""))
		return a_rating > b_rating
	)

	# Assign initial rankings
	var rank := 1
	for player in sorted_pool:
		var p: Dictionary = player

		if not p.has("draft_stock_timeline"):
			p["draft_stock_timeline"] = {}

		var timeline: Dictionary = p["draft_stock_timeline"]
		timeline["pre_season_rank"] = rank
		timeline["post_season_rank"] = rank  # Initially same as pre-season
		timeline["post_combine_rank"] = rank
		timeline["final_rank"] = rank
		timeline["movement_events"] = []
		timeline["total_movement"] = 0

		rank += 1


## Updates draft stock after an evaluation event.
##
## Event types:
##   - "combine_standout": Elite combine performance
##   - "combine_disappointment": Poor combine performance
##   - "senior_bowl_star": Standout all-star game performance
##   - "medical_concern_revealed": Medical red flag discovered
##   - "character_issue_surfaced": Character concern revealed
##
## Side effects:
##   - Appends event to player["draft_stock_timeline"]["movement_events"]
##   - Updates player["draft_stock_timeline"]["total_movement"]
##
## RNG: None (deterministic impact from event data)
##
## @param player: Player dictionary
## @param event: Event type string
## @param config: Draft stock movement configuration
## @param rng: RNG instance (unused but kept for consistency)
static func update_draft_stock(
	player: Dictionary,
	event: String,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var stock_cfg: Dictionary = config.get("draft_stock_movement", {})
	var event_impacts: Dictionary = stock_cfg.get("event_impacts", {})

	# Get impact range for this event
	var impact_range: Array = event_impacts.get(event, [0, 0])
	if impact_range.is_empty():
		return

	# Calculate actual impact based on player data
	var impact := _calculate_event_impact(player, event, impact_range)

	if abs(impact) < 1:
		return  # No significant movement

	# Record movement event
	if not player.has("draft_stock_timeline"):
		player["draft_stock_timeline"] = {
			"movement_events": [],
			"total_movement": 0
		}

	var timeline: Dictionary = player["draft_stock_timeline"]
	var events: Array = timeline.get("movement_events", [])

	events.append({
		"event": event,
		"impact": impact,
		"timestamp": _get_timestamp()
	})

	timeline["movement_events"] = events
	timeline["total_movement"] = int(timeline.get("total_movement", 0)) + impact


## Calculates consensus ranking for a player across all evaluation windows.
##
## Aggregates rankings from:
##   1. Pre-season baseline
##   2. Post-season (after college season)
##   3. Post-combine (after combine/pro days)
##   4. Final (after all-star games and visits)
##
## Side effects:
##   - Updates player["draft_stock_timeline"]["post_combine_rank"]
##   - Updates player["draft_stock_timeline"]["final_rank"]
##
## RNG: None (deterministic calculation)
##
## @param player: Player dictionary
## @param world_state: World state (unused but kept for consistency)
## @return int: Consensus ranking
static func calculate_consensus_ranking(
	player: Dictionary,
	world_state: Dictionary
) -> int:
	var timeline: Dictionary = player.get("draft_stock_timeline", {})

	# Start with pre-season rank
	var base_rank := int(timeline.get("pre_season_rank", 999))

	# Apply total movement
	var movement := int(timeline.get("total_movement", 0))
	var consensus_rank := base_rank - movement  # Negative movement = drop in rank

	# Clamp to valid range
	consensus_rank = max(1, consensus_rank)

	return consensus_rank


## Finalizes draft stock for all players after all evaluation events.
##
## Calculates final rankings and movement categories.
##
## Movement categories:
##   - "riser": Moved up 15+ spots
##   - "faller": Dropped 15+ spots
##   - "steady": Moved <15 spots in either direction
##
## Side effects:
##   - Sets player["draft_stock_timeline"]["final_rank"]
##   - Sets player["draft_stock_timeline"]["movement_category"]
##
## RNG: None (deterministic calculation)
##
## @param draft_pool: Array of all draft-eligible players
static func finalize_draft_stock(draft_pool: Array) -> void:
	# Recalculate final rankings based on accumulated movement
	var ranked_players: Array = []

	for player in draft_pool:
		var p: Dictionary = player
		var timeline: Dictionary = p.get("draft_stock_timeline", {})
		var pre_rank := int(timeline.get("pre_season_rank", 999))
		var movement := int(timeline.get("total_movement", 0))
		var final_rank := max(1, pre_rank - movement)

		ranked_players.append({
			"player": p,
			"final_rank": final_rank,
			"pre_rank": pre_rank,
			"movement": movement
		})

	# Sort by final rank
	ranked_players.sort_custom(func(a, b):
		var a_rank := int((a as Dictionary).get("final_rank", 999))
		var b_rank := int((b as Dictionary).get("final_rank", 999))
		if a_rank == b_rank:
			# Tiebreaker: original pre-season rank
			var a_pre := int((a as Dictionary).get("pre_rank", 999))
			var b_pre := int((b as Dictionary).get("pre_rank", 999))
			return a_pre < b_pre
		return a_rank < b_rank
	)

	# Assign finalized ranks and categories
	var final_rank := 1
	for entry in ranked_players:
		var e: Dictionary = entry
		var player: Dictionary = e["player"]
		var timeline: Dictionary = player.get("draft_stock_timeline", {})

		timeline["final_rank"] = final_rank
		timeline["movement_category"] = categorize_movement(player, {})

		final_rank += 1


## Categorizes a player's draft stock movement.
##
## Categories:
##   - "major_riser": +25 or more spots
##   - "riser": +15 to +24 spots
##   - "slight_riser": +5 to +14 spots
##   - "steady": -4 to +4 spots
##   - "slight_faller": -5 to -14 spots
##   - "faller": -15 to -24 spots
##   - "major_faller": -25 or more spots
##
## RNG: None (deterministic lookup)
##
## @param player: Player dictionary
## @param config: Draft stock movement configuration
## @return String: Movement category
static func categorize_movement(
	player: Dictionary,
	config: Dictionary
) -> String:
	var timeline: Dictionary = player.get("draft_stock_timeline", {})
	var pre_rank := int(timeline.get("pre_season_rank", 999))
	var final_rank := int(timeline.get("final_rank", 999))

	var movement := pre_rank - final_rank  # Positive = moved up, negative = moved down

	if movement >= 25:
		return "major_riser"
	elif movement >= 15:
		return "riser"
	elif movement >= 5:
		return "slight_riser"
	elif movement <= -25:
		return "major_faller"
	elif movement <= -15:
		return "faller"
	elif movement <= -5:
		return "slight_faller"
	else:
		return "steady"


## Calculates actual impact for an event based on player data.
##
## Impact calculation:
##   - combine_standout: Use actual performance grade
##   - combine_disappointment: Use actual performance grade (negative)
##   - senior_bowl_star: Use all-star boost value
##   - medical_concern_revealed: Based on medical grade severity
##   - character_issue_surfaced: Based on character grade severity
##
## RNG: None (deterministic from player data)
##
## @param player: Player dictionary
## @param event: Event type string
## @param impact_range: [min, max] impact from config
## @return int: Actual impact in draft positions
static func _calculate_event_impact(
	player: Dictionary,
	event: String,
	impact_range: Array
) -> int:
	var min_impact := int(impact_range[0])
	var max_impact := int(impact_range[1])

	match event:
		"combine_standout":
			# Use combine performance grade
			var pre_draft: Dictionary = player.get("pre_draft_process", {})
			var combine_perf: Dictionary = pre_draft.get("combine_performance", {})
			var grade := float(combine_perf.get("overall_performance_grade", 0.0))

			# Scale grade (0.0-0.1) to impact range
			if grade > 0.0:
				var ratio := clamp(grade / 0.10, 0.0, 1.0)
				return int(min_impact + ratio * (max_impact - min_impact))

		"combine_disappointment":
			# Use combine performance grade (negative)
			var pre_draft: Dictionary = player.get("pre_draft_process", {})
			var combine_perf: Dictionary = pre_draft.get("combine_performance", {})
			var grade := float(combine_perf.get("overall_performance_grade", 0.0))

			# Scale grade (-0.1-0.0) to impact range
			if grade < 0.0:
				var ratio := clamp(abs(grade) / 0.10, 0.0, 1.0)
				return int(min_impact + ratio * (max_impact - min_impact))

		"senior_bowl_star":
			# Use all-star boost value
			var pre_draft: Dictionary = player.get("pre_draft_process", {})
			var all_star_perf: Dictionary = pre_draft.get("all_star_performance", {})
			var senior_bowl: Dictionary = all_star_perf.get("senior_bowl", {})
			var boost := float(senior_bowl.get("draft_boost", 0.0))

			# Scale boost (0.02-0.06) to impact range
			if boost > 0.0:
				var ratio := clamp((boost - 0.02) / 0.04, 0.0, 1.0)
				return int(min_impact + ratio * (max_impact - min_impact))

		"medical_concern_revealed":
			# Based on medical grade severity
			var medical_eval: Dictionary = player.get("medical_evaluation", {})
			var grade := String(medical_eval.get("grade", "clean"))

			match grade:
				"failed":
					return max_impact  # Maximum drop
				"major_concern":
					return int((min_impact + max_impact) / 2)  # Moderate drop
				"minor_concern":
					return min_impact  # Minimum drop

		"character_issue_surfaced":
			# Based on character grade severity
			var character_profile: Dictionary = player.get("character_profile", {})
			var grade := String(character_profile.get("character_grade", "clean"))

			match grade:
				"red_flag":
					return max_impact  # Maximum drop
				"concern":
					return int((min_impact + max_impact) / 2)  # Moderate drop

	return 0


## Gets player overall rating (simplified).
##
## In production, would use PlayerRatingCalculator.calculate_overall_rating().
##
## RNG: None (deterministic lookup)
##
## @param player: Player dictionary
## @return float: Overall rating (0-100)
static func _get_player_rating(player: Dictionary) -> float:
	# Simplified rating calculation
	var stats: Dictionary = player.get("stats", {})
	if stats.is_empty():
		return 50.0

	var sum := 0.0
	var count := 0
	for stat_value in stats.values():
		sum += float(stat_value)
		count += 1

	return sum / float(count) if count > 0 else 50.0


## Returns current timestamp in HH:MM:SS format
static func _get_timestamp() -> String:
	var time := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]
