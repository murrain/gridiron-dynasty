## RosterMoveModifier - Penalizes acquisitions requiring cutting valuable players
##
## If drafting/trading for a player requires cutting someone valuable,
## factor that loss into the evaluation.
##
## Penalty scales with quality of player who would be cut:
## - Cutting starter-quality (75+): Heavy penalty (0.3-0.5x)
## - Cutting backup-quality (65-74): Moderate penalty (0.6-0.8x)
## - Cutting marginal player (<65): Light penalty (0.9x)
## - No cut required: Neutral (1.0x)
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")


func get_id() -> String:
	return "roster_move"


func get_display_name() -> String:
	return "Roster Move Penalty"


func get_description() -> String:
	return "Penalizes acquisitions requiring cutting valuable players"


func get_priority() -> int:
	return 70


func get_bounds() -> Dictionary:
	return {"min": 0.3, "max": 1.0}


func get_tags() -> Array:
	return ["roster", "draft", "trade"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Only applies in draft and trade phases
	if ctx.phase not in ["draft", "trade"]:
		return false

	return not ctx.roster.is_empty()


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var roster: Dictionary = ctx.roster
	var position := ctx.position
	var incoming_rating := ctx.base_rating

	# Check if position is at cap
	if not RosterComposition.is_position_at_cap(roster, position):
		# No cut required - neutral
		return ModifierResult.new(1.0, "No roster move required", {})

	# Find weakest player at position who would be cut
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var position_players: Array = by_position.get(position, []) as Array

	if position_players.is_empty():
		return ModifierResult.new(1.0, "No existing players to cut", {})

	# Get all players at position with ratings
	var players_with_ratings: Array = []
	var all_players: Dictionary = roster.get("players", {}) as Dictionary

	for player_id in position_players:
		var player: Dictionary = all_players.get(String(player_id), {}) as Dictionary
		var rating := float(player.get("overall", 50.0))
		players_with_ratings.append({"id": player_id, "rating": rating})

	# Sort by rating (ascending) to find weakest
	players_with_ratings.sort_custom(func(a, b): return a.rating < b.rating)

	var cut_player_rating := float(players_with_ratings[0].rating)

	# Calculate penalty based on cut player quality
	var multiplier := 1.0
	var reason := ""

	if cut_player_rating >= 75.0:
		# Cutting starter-quality player - heavy penalty
		multiplier = 0.4
		reason = "Would cut starter-quality %s (%.0f OVR)" % [position, cut_player_rating]
	elif cut_player_rating >= 65.0:
		# Cutting backup-quality - moderate penalty
		multiplier = 0.7
		reason = "Would cut backup-quality %s (%.0f OVR)" % [position, cut_player_rating]
	elif cut_player_rating >= 55.0:
		# Cutting marginal player - light penalty
		multiplier = 0.9
		reason = "Would cut marginal %s (%.0f OVR)" % [position, cut_player_rating]
	else:
		# Cutting low-quality player - minimal penalty
		multiplier = 0.95
		reason = "Would cut low-quality %s (%.0f OVR)" % [position, cut_player_rating]

	return ModifierResult.new(multiplier, reason, {
		"cut_player_rating": cut_player_rating,
		"incoming_rating": incoming_rating,
		"net_upgrade": incoming_rating - cut_player_rating
	})
